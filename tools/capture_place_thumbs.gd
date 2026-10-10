extends SceneTree
## 给东港仓储带那批新地点生成导览卡缩略图。**用命令行单独跑**：
##   godot --path <工程目录> --script res://tools/capture_place_thumbs.gd
##
## ── 为什么必须是独立 SceneTree 脚本，不能用 MCP 的 run_script ──
## run_script 是从桥的 _process 里派发的（调用栈就是 _process → _poll_peer →
## _dispatch_command → execute），**那时这一帧还没渲染**。
## 在里面调 RenderingServer.force_draw() 再 get_texture()，
## 拍到的是没提交完/过期的缓冲区 —— 表现是地面和墙全不见、只剩零散物件悬在暗底上。
## 我为这个错误现象先后误判过三次：怪 filter、怪 camera.size、怪 UI 没藏干净。
## 决定性对照：同一个 camera.size=17.4，MCP 的 take_screenshot（走 frame_post_draw）是对的，
## 而 run_script 里 force_draw 拍出来是碎的 —— 所以问题只在取帧时机。
## 正确写法就是工程自己的 tools/capture_menu.gd：await RenderingServer.frame_post_draw。
##
## 另外：--script 模式下主场景（ui/start_menu.tscn）根本不会实例化，
## 所以不必再操心「开始菜单被拍进每一张图」那件事。
##
## ── 取景 ──
## 按房间尺寸解析计算 camera.size（下面 _frame_size 的推导）。
## 上一版用「非背景像素占画面比例」做闭环收敛是错的：该指标在画面被塞满后饱和在 1.0，
## 分不出「框得刚好」和「已经钻进墙里」，于是一路缩到 7.1（冷藏间可有 13×10）。

const OUT_DIR := "res://assets/district/places/"
const SIZE := Vector2i(384, 288)
## 要出图的房间。前 13 个是东港仓储带那批（第 14 轮补的）；
## 后 5 个是内容审计查出来的老缺口 —— gallery / music_2 / obs_2 / obs_3 / trial
## 一直没有缩略图，导览里是 5 张空白灰卡。
const PLACES: Array = ["depot", "depot_2f", "coldstore", "vault", "lab", "archive",
	"customs", "weather", "hub", "quarantine", "spares", "tidal_high", "tidal_low",
	"gallery", "music_2", "obs_2", "obs_3", "trial"]
## 正交相机俯角：_camera() 把它放在 view_center + (sin·76, 50.8, cos·76)
const CAM_UP := 50.8
const CAM_OUT := 76.0
const WALL_H := 3.2
const MARGIN := 1.12

func _initialize() -> void:
	call_deferred("run")

## 屏幕上的竖向跨度 ≈ 进深·sin(俯角) + 墙高·cos(俯角)；横向跨度 ≈ 面宽。
## 正交相机 size 是视口的**竖向**世界尺寸，所以按宽高比取较大者。
func _frame_size(bounds: Vector2) -> float:
	var elev := atan2(CAM_UP, CAM_OUT)
	var proj_h := bounds.y * sin(elev) + WALL_H * cos(elev)
	var rect: Vector2 = root.get_visible_rect().size
	var aspect: float = maxf(1.0, rect.x / maxf(1.0, rect.y))
	return clampf(maxf(proj_h, bounds.x / aspect) * MARGIN, 8.0, 200.0)

## 藏掉整个世界里的 UI。
##
## 这些 HUD（左上地点名牌、底部提示条、底部按钮行）挂在 **g 内部的 CanvasLayer** 上 ——
## 既不是根节点的直接子节点，也不在 district_canvas 里。
## 只藏 district_canvas 的话，老缩略图那种「纯房间」的效果出不来。
## 世界本身画在根 viewport 上（实测 same_as_root = true），所以藏 CanvasLayer 不会把画面藏掉。
func _hide_ui(node: Node) -> int:
	var hidden := 0
	for child in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
			hidden += 1
		hidden += _hide_ui(child)
	return hidden

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var g = load("res://district/continuous_world.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	for i in 4:
		await process_frame
	if g.dialogue_controller:
		g.dialogue_controller.close()
	await process_frame
	var hidden := _hide_ui(g)
	var canvas: Variant = g.get("district_canvas")
	if canvas != null and canvas is CanvasItem:
		(canvas as CanvasItem).visible = false
		hidden += 1
	print("[thumb] 藏掉的 UI 节点数 = %d" % hidden)
	var made := 0
	var failed: Array = []
	for raw in PLACES:
		var id: String = str(raw)
		g._travel(id)
		# 让场景稳定：物理帧 + 真实渲染帧都要走
		for i in 8:
			g._physics_process(0.05)
			await process_frame
		g.overview_mode = true
		g.view_size = float(g.overview_size)
		if g.has_method("_camera"):
			g._camera()
		# camera.size 必须直接设：_camera() 只改 view_center/位置，
		# 而 camera.size 是 _physics_process 里 lerpf 过去的（continuous_world.gd:251）
		g.camera.size = _frame_size(g.space_bounds)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if img == null:
			failed.append(id)
			continue
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		if img.save_png(ProjectSettings.globalize_path(OUT_DIR + id + ".png")) != OK:
			failed.append(id)
			continue
		made += 1
		print("[thumb] %s  bounds=%s  camera.size=%.1f" % [id, str(g.space_bounds), g.camera.size])
	print("[thumb] 完成 %d 张，失败 %s" % [made, str(failed)])
	quit()
