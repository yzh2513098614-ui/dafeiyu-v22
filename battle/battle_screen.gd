extends Node
## 回合制战斗界面（JRPG 全屏战斗画面）
##
## 只负责「显示 + 收输入 + 播演出」，所有规则判断都在 battle/battle_engine.gd 里。
## 界面本身不做任何伤害计算、不给技能定价、不判断胜负 —— 否则规则会分裂成两处。
##
## 画面结构（自下而上）：
##   · 背景    港湾广场素材，轻柔的前景色罩。
##   · 敌人    居中站成一排，脚下浮着名字牌与血条；直接点立绘选目标
##   · 战报    下方与目标情报并排展示。
##   · 指令窗  六个横向卡通按钮；技能与道具共用右侧选择窗。
##   · 状态坞  底部横贯整屏：头像 + 等级 + 状态图标 + 生命 / 体力 / AP 三条槽
##
## 素材全部复用现有资源：
##   · 边框  candy_skin.gd 的统一糖果色原生面板。
##   · 图标  assets/battle/ui/*.svg，战斗专用柔和卡通图标。
##   · 立绘  assets/monsters/*.png（与 combat_balance.json 的 texture 字段一致）
##   · 头像  assets/ui/whale_mascot.png
##
## 用法：
##   var screen = load("res://battle/battle_screen.gd").new()
##   add_child(screen)
##   screen.open(engine, {"title":"遭遇战"})
##   screen.battle_finished.connect(_on_battle_finished)

signal battle_finished(result: String)

const WhaleStyle = preload("res://battle/battle_skin.gd")
const DownloadedIcons = preload("res://ui/downloaded_icons.gd")
const PaintedMascot = preload("res://battle/painted_mascot_assets.gd")
const AttackFx = preload("res://battle/attack_fx.gd")
const PixelFrames = preload("res://dialogue/pixel_skin.gd")
const UiFit = preload("res://ui/ui_fit.gd")
const Guide = preload("res://battle/battle_guide.gd")
const LayeredPanel = preload("res://battle/layered_panel.gd")
const LayeredButton = preload("res://battle/layered_button.gd")
const BACKGROUND_PATH = "res://assets/battle/harbor_plaza_pixel_v1.png"

const MAX_FOES := 3
const STEP_SECONDS := 0.30          ## 事件逐个播放的间隔
const MAX_LOG_LINES := 3

## 版面：设计画布 1448x1086（见 ui/ui_fit.gd）。宽度会随窗口比例伸展，所以
## 横向元素一律走 pin_wide / pin_left / pin_right，纵向才是绝对像素。
const DOCK_TOP := 918.0
const DOCK_H := 144.0
const DOCK_MARGIN := 24.0
const GROUND_Y := 576.0             ## 敌人脚底所在的屏幕高度
const ENEMY_CELL_H := 398.0
const ENEMY_CELL_MAX_W := 460.0
const CMD_W := 380.0
const CMD_TOP := 794.0
const CMD_H := 108.0
const CMD_GAP := 16.0               ## 敌人活动区与指令窗之间必须留的缝
const LOG_W := 980.0
const LOG_TOP := 684.0
const LOG_H := 94.0
const CARD_INFO_TOP:=512.0
const CARD_INFO_HEIGHT:=50.0
const CARD_HAND_TOP:=582.0
const CARD_HAND_HEIGHT:=316.0
const CARD_DOCK_TOP:=922.0
const CARD_DOCK_HEIGHT:=140.0

## 背景配色：直接取潮汐试炼场的地板色，让战斗画面和玩家站的地方是同一个场地
const SKY_TOP := Color("8fb8dd")
const SKY_LOW := Color("dceaf2")
const SEA_TOP := Color("7ba7c9")
const SEA_LOW := Color("5d8bb4")
const FLOOR_FAR := Color("cfdcd6")
const FLOOR_NEAR := Color("d7e3dd")
const GRID := Color("b9cbd0")

## 背景纵深感的用色。都不是新色相，只是在同一色系里拉开明度 ——
## 引入新色相会让这块背景和试炼场的场地色脱节。
const SUN_GLOW := Color("ffe9c2")
const SUN_CORE := Color("fffdf2")
const HAZE := Color("eef5f8")
const SEA_CREST := Color("c6dff0")
const SEA_TROUGH := Color("4d7aa5")
const FOAM := Color("f6fcff")
const WET := Color("93b0ae")
const ISLAND := Color("b6cde0")
const PIER := Color("8ea7bd")
const HORIZON := Color("9db6cc")
## 敌人脚下台子的两层颜色。刻意用偏灰的场地质感，
## 不用饱和色 —— 台子是承托立绘的，抢眼就本末倒置了。
const DAIS_RIM := Color("7d968f")
const DAIS_TOP := Color("c3d3cb")
## 被选中的敌人，台子边沿转成金色
const DAIS_RIM_TARGET := Color("d9b05e")
const VIGNETTE := Color("2b3d55")

const HP_FILL := Color("ff86b2")
## 掉血残影：实心条掉下去之后，那一段「曾经有血」的浅色会慢慢收拢。
## 用偏白的暖粉而不是另一种红 —— 它要读成「刚才这里还有血」，不是「还有一层血」。
const HP_TRAIL := Color("fbc5df")
## 残影收拢速度（像素/秒）。不用 lerp：lerp 越接近越慢，尾巴会拖很久；
## 固定速度收得干脆，而且不同长度的条收拢时间都短到不影响节奏。
const TRAIL_SPEED := 220.0
const SP_FILL := Color("4ad9c5")
const AP_FILL := Color("91adff")
const AP_READY := Color("ffe071")

var engine                                  ## battle_engine.gd 实例
var context: Dictionary = {}
var layer: CanvasLayer
var root: Control
var backdrop: TextureRect
var enemy_layer: Control
var title_plate: Panel
var title_label: Label
var round_label: Label
var log_box: Panel
var log_text: RichTextLabel
var command_box: Panel
var skill_box: Panel
var skill_list: VBoxContainer
var submenu_title: Label
var submenu_scroll: ScrollContainer
var submenu_back: Button
var detail_name: Label
var detail_text: RichTextLabel
var tactics_box: Panel
var tactics_name: Label
var tactics_text: Label
var command_hint: Label
var result_details: Label
var result_rewards: HBoxContainer
var speed_button: Button
var phase_plate: Panel
var phase_label: Label
var action_list: HBoxContainer
var result_box: Panel
var result_shade: ColorRect
var result_label: Label
var link_button: Button
var skill_button: Button
var item_button: Button
var card_panel: Panel
var card_scroll: ScrollContainer
var card_row: HBoxContainer
var card_energy_label: Label
var card_counts: Label
var card_end_button: Button
var card_link_button: Button
var card_item_button: Button
var card_first_ready: Button
var card_preview: Panel
var card_preview_art: Button
var card_preview_text: Label
var continuing := false

## 指令按钮列表 + 上次的焦点位置。修「放完技能键盘就失效」用的：
## 旧实现去 command_box 的直接子节点里找 Button，而按钮全在里层 VBoxContainer 里。
var command_buttons: Array = []
var _last_command_focus := -1
## 道具那一手的等待状态：引擎确认执行后才去扣背包
var _pending_item := ""

## 演出倍速。战斗事件是逐个播的，重复刷同一场时会烦 ——
## 这里给 1/2/4 倍，外加「播放中按确认键直接跳过（事件照样全部结算）」。
const SPEEDS: Array = [1.0, 2.0, 4.0]
var speed_index := 0

## 命中反馈：飘字层 + 震屏状态。
## 震屏只作用于「世界层」（背景 + 敌人层），HUD 保持静止 —— 见 _update_shake。
const SHAKE_TIME := 0.26
var fx_layer: Control
var intro_flash: ColorRect
var _shake_left := 0.0
var _shake_power := 0.0
var _shake_phase := 0.0
var _skip_fx := false
var _vfx_epoch := 0
var _card_origin := Vector2.ZERO
var _finish_pending := false
var _display_states:Dictionary={}
var _cast_target_id:=""
## 状态图标上一次的开关状态。用来检测「变了」才播动画（见 _set_status_icon）。
var _icon_state: Dictionary = {}
var result_banner: TextureRect
var result_go: Button

# ---------------------------------------------------------------- 素材包图标
## 来自 2026-10-03 的素材包（Token大肥鱼_全部生成资源 04_UI_80），已拷进工程并导入。
## 两份尺寸各有用处：
##   combat   64x64 —— 状态坞的状态图标，按原尺寸显示（一格像素对一格屏幕像素，不缩放）
##   combat32 32x32 —— 指令按钮与三条槽的小图标（缩到 24/32 用，放大反而会失去像素感）
const ICON_DIR := "res://assets/ui/pack/combat/"
const ICON32_DIR := "res://assets/ui/pack/combat32/"
const ICON_HUD_DIR := "res://assets/ui/pack/hud/"

## 在素材包里找一个图标，返回可用路径；找不到返回空串（调用处据此跳过图标）。
## 先查 combat32 再查 hud：同一个名字（比如 intent_cast）只在其中一处存在。
func _pack_icon(name: String) -> String:
	if name == "":
		return ""
	var downloaded_path:=DownloadedIcons.path_for(name)
	if downloaded_path!="":return downloaded_path
	var refined_path: String="res://assets/battle/ui_refined_v22/"+name+".svg"
	if ResourceLoader.exists(refined_path):return refined_path
	var cute_path: String="res://assets/battle/ui/"+name+".svg"
	if ResourceLoader.exists(cute_path):return cute_path
	for dir in [ICON32_DIR, ICON_HUD_DIR]:
		var path: String = dir + name + ".png"
		if ResourceLoader.exists(path):
			return path
	return ""

var ally: Dictionary = {}
var portraits: Dictionary = {}
var dash: Dictionary = {}                   ## 状态坞各部件
var cmd_w := CMD_W                          ## 指令窗实际宽度（随画布宽度伸缩，见 _layout）
var slots: Array = []                       ## 敌人卡片
var queue: Array = []                       ## 待播放事件
var step_timer := 0.0
var log_lines: Array = []
var mode := "command"                       ## command | skill | busy | result
var _bob := 0.0
var _ap_ready := false

# ---------------------------------------------------------------- 生命周期

func open(battle_engine, open_context: Dictionary = {}) -> void:
	_vfx_epoch+=1
	engine = battle_engine
	context = open_context
	ally = engine.allies[0]
	if layer == null:
		_build()
	log_lines.clear()
	queue.clear()
	mode = "command"
	_bob = 0.0
	_ap_ready = false
	_show_command()
	_refresh_all()
	_layout()
	_append_log("遭遇 " + _foe_names(), "334475")
	# 和遭遇提示是同一个音，但这里给足音量 —— 同一个动机在两个强度上出现，
	# 听感是「它变成了正式的战斗」，而不是两段无关的音效。
	SfxDirector.play("encounter", -1.0)
	# 入场演出必须在 _layout() 之后：它记下各部件的最终位置，再从偏移处补间回来。
	# 放在 _layout() 之前的话记下的是还没排版的位置（全 0），滑入会滑到错误的终点。
	_play_intro()
	# 开场先把敌人可能先手的那段推进完，再交还控制权
	_ingest(engine.submit({}))

func close() -> void:
	_vfx_epoch+=1
	_display_states.clear()
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	layer = null
	root = null
	queue.clear()

## 战斗是否正在进行（供世界层冻结昼夜与角色输入用）
func is_active() -> bool:
	return layer != null and is_instance_valid(layer)

func _foe_names() -> String:
	var names: Array = []
	for f in engine.foes:
		names.append(str(f.name))
	return " / ".join(names)

# ---------------------------------------------------------------- 构建

func _font() -> Font:
	return WhaleStyle.body_font()

func _build() -> void:
	layer = CanvasLayer.new()
	# 必须高过项目里所有其它 UI 画布：房间 20 / 街区 40 / 对话 50 / 暂停菜单 60。
	# 留出富余，免得以后新加的界面插到战斗中界面之上。
	layer.layer = 100
	add_child(layer)

	root = Control.new()
	root.theme = WhaleStyle.theme(_font())
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	UiFit.fill(root)
	root.resized.connect(_layout)

	backdrop = TextureRect.new()
	backdrop.texture = _backdrop_texture()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	UiFit.fill(backdrop)
	var veil:=ColorRect.new()
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var veil_material:=ShaderMaterial.new()
	veil_material.shader=preload("res://battle/battle_veil.gdshader")
	veil.material=veil_material
	root.add_child(veil);UiFit.fill(veil)

	_build_title()
	_build_enemies()
	_build_log()
	_build_tactics()
	_build_command()
	_build_skill()
	if engine.card_mode: _build_card_hand()
	_build_dock()
	_build_fx()
	_build_result()
	if engine.card_mode:
		_style_card_battle()
	# 首次版面要等一帧：dock 是 pin_wide 的，size 要等容器自己算完才有值，
	# 当场算会拿到 0，三条槽就会全部挤在最小宽度上。
	call_deferred("_layout")

func _build_title() -> void:
	title_plate=WhaleStyle.panel(root,Vector2.ZERO,Vector2(1400,72),"dark")
	title_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
	UiFit.pin_wide(title_plate,24,24,24,72)
	title_label=WhaleStyle.label(title_plate,str(context.get("title","遭遇战")),Vector2(22,17),Vector2(352,38),27,Color("eaf1ff"))
	title_label.max_lines_visible=1;title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	round_label=WhaleStyle.label(title_plate,"",Vector2(384,20),Vector2(144,32),21,WhaleStyle.GOLD)
	round_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	phase_plate=WhaleStyle.panel(root,Vector2.ZERO,Vector2(340,48),"mint")
	UiFit.pin_center(phase_plate,340,36,48)
	phase_label=WhaleStyle.label(phase_plate,"",Vector2(12,7),Vector2(316,34),20,WhaleStyle.INK)
	phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_build_speed()

func _build_speed() -> void:
	if root == null:
		return
	speed_button = Button.new()
	speed_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	speed_button.add_theme_font_size_override("font_size", 20)
	WhaleStyle.card_button(speed_button, false)
	speed_button.pressed.connect(_cycle_speed)
	root.add_child(speed_button)
	UiFit.pin_right(speed_button, 150, 40, 38, 44)
	_refresh_speed_button()

func _cycle_speed() -> void:
	speed_index = (speed_index + 1) % SPEEDS.size()
	_refresh_speed_button()

func _speed() -> float:
	return float(SPEEDS[clampi(speed_index, 0, SPEEDS.size() - 1)])

func _refresh_speed_button() -> void:
	if speed_button != null and is_instance_valid(speed_button):
		speed_button.text = "演出 ×%d" % int(_speed())

## 把队列里剩下的事件一次性结算完 —— 状态和战报要一致，只是不等演出时间。
func skip_playback() -> void:
	if not is_active():
		return
	var was_busy:=mode=="busy"
	var guard := 0
	_skip_fx=true
	while not queue.is_empty() and guard < 500:
		guard += 1
		_apply_event(queue.pop_front())
	_skip_fx=false
	_vfx_epoch+=1
	for child in fx_layer.get_children():child.queue_free()
	for slot in slots:
		slot["reaction_left"]=0.0;slot["reaction_offset"]=Vector2.ZERO
		slot["attack_left"]=0.0;slot["attack_offset"]=Vector2.ZERO;slot["defeat_left"]=0.0
		if is_instance_valid(slot.art):slot.art.scale=Vector2.ONE;slot.art.self_modulate=Color.WHITE
	_shake_left=0;_shake_power=0
	backdrop.position=Vector2.ZERO;enemy_layer.position=Vector2.ZERO
	if was_busy:_finish_playback()
	else:_layout_enemies()

func _build_enemies() -> void:
	enemy_layer = Control.new()
	enemy_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(enemy_layer)
	UiFit.pin_wide(enemy_layer, 0, 0, 0, 1086)
	slots.clear()
	for i in MAX_FOES:
		slots.append(_enemy_slot(i))

## 一个敌人 = 影子 + 立绘 + 名字牌 + 血条 + 目标箭头。
## 用 Control + gui_input 而不是 Button：Button 会进入焦点导航链，
## 方向键/Tab 会跑到敌人身上，和指令窗的焦点打架。
func _enemy_slot(index: int) -> Dictionary:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_layer.add_child(holder)

	# 脚下的台子：石台边沿 + 浅色台面，原来的柔和阴影叠在最上面。
	# 只放一个椭圆阴影时，敌人像「浮在格子上」——没有落脚点，透视也读不出来。
	# 三层按添加顺序绘制（先加的在下面）：台基 → 台面 → 阴影。
	var dais_rim := Panel.new()
	dais_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dr := StyleBoxFlat.new()
	dr.bg_color = DAIS_RIM
	dr.set_corner_radius_all(999)
	dais_rim.add_theme_stylebox_override("panel", dr)
	holder.add_child(dais_rim)
	var dais_top := Panel.new()
	dais_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dt := StyleBoxFlat.new()
	dt.bg_color = DAIS_TOP
	dt.set_corner_radius_all(999)
	dais_top.add_theme_stylebox_override("panel", dt)
	holder.add_child(dais_top)
	dais_rim.hide()
	dais_top.hide()

	var shadow := Panel.new()
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(.08, .11, .15, .20)
	sb.set_corner_radius_all(999)
	shadow.add_theme_stylebox_override("panel", sb)
	holder.add_child(shadow)

	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)

	var hit := Control.new()
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(hit)
	hit.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_target(index))
	hit.mouse_entered.connect(func(): _hover_slot(index, true))
	hit.mouse_exited.connect(func(): _hover_slot(index, false))

	# 选中箭头用「金色 ▼ + 白描边」的文字字形，而不是 arrow_down.svg：
	# 那个 svg 的填充是深蓝 #40568c，而 modulate 是乘法、只能变暗不能变亮，
	# 乘上金色会得到一团近黑的橄榄色，在浅蓝天空上几乎看不出来。
	# 文字字形 + 描边才能既保证颜色，又保证压在任何背景上都读得出。
	# 注意：WhaleStyle.label() 内部已经 add_child 了，这里不能再加一次 ——
	# 重复 add_child 会报 "already has a parent"，而且每次开战都会刷一条错误日志。
	var mark := WhaleStyle.label(holder, "◆", Vector2.ZERO, Vector2(24, 30), 17, WhaleStyle.GOLD)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.add_theme_color_override("font_outline_color", Color("fff8e7"))
	mark.add_theme_constant_override("outline_size", 5)
	mark.visible = false

	var name_plate := Panel.new()
	name_plate.add_theme_stylebox_override("panel", WhaleStyle.frame("plate"))
	WhaleStyle.PaintedUi.apply(name_plate,"enemy_plate")
	name_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(name_plate)
	var name_label := WhaleStyle.label(name_plate, "", Vector2(14, 4), Vector2(150, 26), 19, Color("eaf1ff"))
	var hp_text := WhaleStyle.label(name_plate, "", Vector2(140, 5), Vector2(150, 24), 16, Color("ccf4f1"))
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var bar_back := Panel.new()
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color("edf0f2")
	bb.set_corner_radius_all(7)
	bb.border_color = Color("c4d8df")
	bb.set_border_width_all(2)
	bar_back.add_theme_stylebox_override("panel", bb)
	WhaleStyle.PaintedUi.apply(bar_back,"gauge_track")
	holder.add_child(bar_back)
	# 掉血残影：夹在底槽和实心条之间的一层浅色条。
	# **必须在 bar_fill 之前 add_child** —— 后加的画在上面，
	# 顺序反了残影会盖住实心条，看起来像血变多了。
	var bar_trail := Panel.new()
	bar_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bt := StyleBoxFlat.new()
	bt.bg_color = HP_TRAIL
	bt.set_corner_radius_all(6)
	bar_trail.add_theme_stylebox_override("panel", bt)
	bar_back.add_child(bar_trail)

	var bar_fill := Panel.new()
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bf := StyleBoxFlat.new()
	bf.bg_color = HP_FILL
	bf.set_corner_radius_all(6)
	bar_fill.add_theme_stylebox_override("panel", bf)
	WhaleStyle.PaintedUi.apply(bar_fill,"gauge_fill",bf)
	bar_back.add_child(bar_fill)
	# 血条分段刻度：不做刻度时，两条长度接近的血条很难一眼比较，
	# 也看不出「掉了多少（一格 = 25%）」。四条刻度由 _layout_one_enemy 定位。
	var ticks: Array = []
	for i in 3:
		var tick := ColorRect.new()
		tick.color = Color(0.10, 0.13, 0.20, 0.55)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_back.add_child(tick)
		ticks.append(tick)

	# 敌人状态图标：护盾 / 加速 / 束缚，横排在血条下方。
	# 引擎里敌我共用同一套状态字段（敌人的「缩壳」会给自己 shield，
	# 而护盾是减伤 50%），但屏幕上原来只有玩家一侧有图标 ——
	# 敌人套了盾玩家看不见，只会觉得「这一下怎么打得这么少」。
	# 用素材包的 32px 原尺寸，不缩放。
	var status: Array = []
	for spec in ["shield", "haste", "bind"]:
		var si := TextureRect.new()
		si.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		si.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		si.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		si.texture = load(_pack_icon(spec))
		si.size = Vector2(32, 32)
		si.mouse_filter = Control.MOUSE_FILTER_IGNORE
		si.visible = false
		holder.add_child(si)
		status.append(si)

	var block_badge:=_build_block_badge(holder,false)
	var intent_label := WhaleStyle.label(holder, "", Vector2.ZERO, Vector2(320, 32), 20, Color("fff8e7"))
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	intent_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	intent_label.add_theme_color_override("font_outline_color", Color("24314d"))
	intent_label.add_theme_constant_override("outline_size", 4)
	var intent_icon := TextureRect.new()
	intent_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	intent_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	intent_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	intent_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intent_icon.hide()
	holder.add_child(intent_icon)
	return {
		"holder": holder, "shadow": shadow, "art": art, "hit": hit, "mark": mark,
		"dais_rim": dais_rim, "dais_top": dais_top, "dais_rim_style": dr,
		"plate": name_plate, "name": name_label, "bar_back": bar_back,
		"bar_trail": bar_trail, "bar_fill": bar_fill, "bar_style": bf,
		"ticks": ticks, "trail_w": 0.0, "hp": hp_text, "foe": null,
		"status": status, "status_state": {}, "block_badge":block_badge, "intent":intent_label, "intent_icon":intent_icon,
	}

func _build_tactics() -> void:
	tactics_box = WhaleStyle.panel(root, Vector2.ZERO, Vector2(460, LOG_H), "paper")
	var target_caption:=WhaleStyle.label(tactics_box, "目标情报", Vector2(18, 10), Vector2(100, 24), 17, WhaleStyle.MUTED)
	target_caption.name="TargetCaption"
	WhaleStyle.PaintedUi.apply(tactics_box,"info")
	tactics_name = WhaleStyle.label(tactics_box, "", Vector2(125, 8), Vector2(300, 28), 21, WhaleStyle.GOLD)
	tactics_text = WhaleStyle.label(tactics_box, "", Vector2(18, 39), Vector2(424, 48), 17)

func _build_log() -> void:
	log_box = WhaleStyle.panel(root, Vector2.ZERO, Vector2(LOG_W, LOG_H), "paper")
	UiFit.pin_left(log_box, LOG_W, DOCK_MARGIN, LOG_TOP, LOG_H)
	# 标题铭牌：原来战报板就是一整块空白面板，看不出是干什么用的。
	# 压在板子上沿（y 负值）形成一个「标签页」的观感。
	var header := Panel.new()
	header.name="LogCaption"
	header.add_theme_stylebox_override("panel", WhaleStyle.frame("plate"))
	header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.position = Vector2(14, 8)
	header.size = Vector2(96, 30)
	log_box.add_child(header)
	WhaleStyle.PaintedUi.apply(header,"tag")
	WhaleStyle.PaintedUi.apply(log_box,"info")
	var header_text := WhaleStyle.label(header, "战报", Vector2(0, 3), Vector2(96, 24), 18, WhaleStyle.INK)
	header_text.name="CaptionText"
	header_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_active = false
	log_text.fit_content = false
	log_text.position = Vector2(120, 9)
	log_text.size = Vector2(LOG_W - 140, LOG_H - 16)
	log_text.add_theme_font_size_override("normal_font_size", 19)
	# 战报只有三行，默认行距下整块板子下面会空一半。拉开行距把版面填满，
	# 顺便让三行更容易分开读（战报是扫一眼看的，不是逐字读的）。
	log_text.add_theme_constant_override("line_separation", 0)
	log_text.add_theme_color_override("default_color", WhaleStyle.INK)
	log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.add_child(log_text)

func _cmd_button(parent: Node, text: String, action: Callable, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.add_theme_font_size_override("font_size", 22)
	# 图标交给 Button 自带的 icon 槽，不用自己拼 HBoxContainer。
	# expand_icon + icon_max_width 把 32px 素材压到 24px；按钮行高按
	# max(文字 24, 图标 24) + 上下内边距 10 = 34 算，留 2px 余量。
	if icon_name != "":
		var icon_path := _pack_icon(icon_name)
		if icon_path != "":
			b.icon = load(icon_path)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 32)
			b.add_theme_constant_override("h_separation", 8)
	WhaleStyle.card_button(b)
	if icon_name!="":WhaleStyle.action(b,icon_name)
	# 把上下内边距从 9 压到 4。
	# 不压的话每个按钮的真实最小高度是 ~50（17px 字号 1.4 倍行高 + 上下各 9px 内边距），
	# 6 个按钮 = 6×50 + 5×3 = 315，装不进 CMD_H-46 = 258 的列表 —— 会溢出指令窗把
	# 最后一个按钮裁掉。这个溢出在加「道具」之前就存在（5 个按钮 274 > 260），
	# 只是加了第 6 个才明显到看得见。
	# WhaleStyle.frame() 是带缓存的**共享**对象，必须先 duplicate 再改，
	# 否则会改到全工程所有按钮的内边距。
	# 注意包含 disabled：漏掉它的话，按钮一旦被禁用就会换成另一份内边距，
	# 真实高度从 36 变 43，列表跟着抖一下。「潮汐连携」正是这种
	# 平时禁用、AP 满了才启用的按钮，所以这个抖动每次集满 AP 都会出现。
	for kind in ["normal", "hover", "pressed", "disabled"]:
		var src: StyleBox = b.get_theme_stylebox(kind)
		if src != null:
			var tight: StyleBox = src.duplicate()
			tight.content_margin_top = 5
			tight.content_margin_bottom = 5
			b.add_theme_stylebox_override(kind, tight)
	b.pressed.connect(action)
	parent.add_child(b)
	# 只登记指令窗里的那 6 个按钮。结算面板的「继续」也是用这个函数建的，
	# 混进来会让 _last_command_focus 的含义从「指令窗第 N 项」变成
	# 「第 N 个用本函数建的按钮」，焦点恢复就会指错。
	if parent is BoxContainer:
		command_buttons.append(b)
		var index := command_buttons.size() - 1
		b.focus_entered.connect(func():_last_command_focus = index)
	return b

func _build_command() -> void:
	command_box = WhaleStyle.panel(root, Vector2.ZERO, Vector2(CMD_W, CMD_H))
	UiFit.pin_wide(command_box, DOCK_MARGIN, DOCK_MARGIN, CMD_TOP, CMD_H)
	WhaleStyle.label(command_box, "选择行动", Vector2(20, 8), Vector2(200, 26), 18, WhaleStyle.MUTED)
	var list := HBoxContainer.new()
	action_list=list
	# 加了「道具」之后是 6 个按钮，列表高度必须跟着算：
	# 6×37 + 5×3 = 237，装进 CMD_H-46 = 258 里。原来按 5 个按钮留的高度会把最后一个裁掉。
	list.position = Vector2(18, 34)
	list.size = Vector2(CMD_W - 36, 56)
	list.add_theme_constant_override("separation", 10)
	command_box.add_child(list)
	# 每个按钮配一个素材包图标。指令行原来只有文字，一眼扫过去要读完六个词才知道
	# 该按哪个；有了图标可以先认形状。
	# 「道具」用 heal.png（十字）—— 素材包里没有通用的背包图标，
	# 而本作道具实际都是回血回体力的，十字是当下最贴切的。
	var attack_button:=_cmd_button(list, "攻击", _on_attack, "attack")
	WhaleStyle.primary(attack_button)
	skill_button = _cmd_button(list, "技能  ▸", _on_skill_menu, "intent_cast")
	item_button = _cmd_button(list, "道具  ▸", _on_item_menu, "heal")
	link_button = _cmd_button(list, "潮汐连携", _on_link, "multihit")
	_cmd_button(list, "逃跑", _on_flee, "move")
	_cmd_button(list, "切换目标", _cycle_target, "target")
	command_hint = WhaleStyle.label(command_box, "", Vector2(230, 6), Vector2(CMD_W-250, 26), 17, WhaleStyle.MUTED)
	skill_button.grab_focus()

func _build_skill() -> void:
	skill_box = WhaleStyle.panel(root, Vector2.ZERO, Vector2(CMD_W, CMD_H), "paper")
	UiFit.pin_right(skill_box, CMD_W, DOCK_MARGIN, CMD_TOP, CMD_H)
	# 标题要在「技能」和「道具」之间切换，所以留个引用。
	# 技能列表和道具列表共用这一个窗口 —— 两套输入态并存会让「Esc 退到哪」变得含糊。
	submenu_title = WhaleStyle.label(skill_box, "技能（Esc 返回 · 灰掉的是暂时不能用的）", Vector2(18, 8), Vector2(CMD_W - 36, 24), 16, WhaleStyle.MUTED)
	submenu_title.text = "选择技能"
	submenu_back = _cmd_button(skill_box, "‹ 返回", _back_to_command)
	submenu_back.size = Vector2(96, 34)
	submenu_scroll = ScrollContainer.new()
	submenu_scroll.position = Vector2(14, 56)
	submenu_scroll.size = Vector2(CMD_W - 28, 316)
	submenu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	submenu_scroll.clip_contents = true
	skill_list = VBoxContainer.new()
	skill_list.add_theme_constant_override("separation", 6)
	skill_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	submenu_scroll.add_child(skill_list)
	skill_box.add_child(submenu_scroll)
	var detail_card := WhaleStyle.panel(skill_box, Vector2(14, 386), Vector2(CMD_W-28, 290), "sky")
	detail_card.name = "EffectCard"
	detail_name = WhaleStyle.label(detail_card, "", Vector2(16, 14), Vector2(CMD_W-60, 35), 24)
	detail_text=RichTextLabel.new()
	detail_text.add_theme_font_size_override("normal_font_size",20)
	detail_text.add_theme_color_override("default_color",WhaleStyle.INK)
	detail_text.scroll_active=true;detail_text.fit_content=false;detail_text.bbcode_enabled=false
	detail_card.add_child(detail_text)
	skill_box.hide()

func _build_card_hand() -> void:
	card_panel = WhaleStyle.panel(root, Vector2(24, 748), Vector2(1400, 162), "hand_tray")
	card_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var energy_badge := WhaleStyle.panel(card_panel, Vector2(12, 10), Vector2(176, 58), "plate")
	energy_badge.name = "CardEnergyBadge"
	WhaleStyle.PaintedUi.apply(energy_badge,"energy")
	energy_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var energy_icon := TextureRect.new()
	energy_icon.name = "CardEnergyIcon"
	energy_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	energy_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	energy_icon.texture = load(_pack_icon("energy"))
	energy_icon.position = Vector2(10, 13); energy_icon.size = Vector2(32, 32)
	energy_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_badge.add_child(energy_icon)
	var energy_caption := WhaleStyle.label(energy_badge, "能量", Vector2(40, 53), Vector2(64, 24), 17, WhaleStyle.MUTED)
	energy_caption.name = "CardEnergyCaption"
	card_energy_label = WhaleStyle.label(card_panel, "", Vector2(62, 21), Vector2(124, 34), 23, WhaleStyle.INK)
	card_energy_label.add_theme_font_override("font",WhaleStyle.numeric_font())
	card_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_counts = WhaleStyle.label(card_panel, "", Vector2(15, 79), Vector2(180, 62), 16, WhaleStyle.MUTED)
	card_item_button = _cmd_button(card_panel, "补给", _on_item_menu, "heal")
	card_item_button.position = Vector2(15, 167); card_item_button.size = Vector2(82, 42)
	card_link_button = _cmd_button(card_panel, "连携", _on_link, "multihit")
	card_link_button.position = Vector2(105, 167); card_link_button.size = Vector2(82, 42)
	for small_button in [card_item_button, card_link_button]:
		small_button.add_theme_font_size_override("font_size", 18)
		small_button.add_theme_constant_override("icon_max_width", 22)
		small_button.add_theme_constant_override("h_separation", 4)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var small_style: StyleBox = small_button.get_theme_stylebox(state).duplicate()
			small_style.content_margin_left = 8; small_style.content_margin_right = 8
			small_button.add_theme_stylebox_override(state, small_style)
	card_scroll = ScrollContainer.new()
	card_scroll.position = Vector2(202, 4)
	card_scroll.size = Vector2(982, 156)
	card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_scroll.clip_contents = true
	card_scroll.follow_focus = true
	card_panel.add_child(card_scroll)
	card_row = HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 22)
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_margin := MarginContainer.new()
	card_margin.name = "CardHoverSpace"
	card_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_margin.add_theme_constant_override("margin_top", 10)
	card_margin.add_theme_constant_override("margin_bottom", 2)
	card_margin.add_theme_constant_override("margin_left", 4)
	card_margin.add_theme_constant_override("margin_right", 8)
	card_scroll.add_child(card_margin)
	card_margin.add_child(card_row)
	card_end_button = _cmd_button(card_panel, "结束回合  ›", func():_submit_action({"kind":"end_turn"}))
	card_end_button.position = Vector2(1200, 18); card_end_button.size = Vector2(178, 64)
	WhaleStyle.primary(card_end_button)
	var play_hint := WhaleStyle.label(card_panel, "可连续打出多张牌", Vector2(1200, 90), Vector2(178, 24), 14, WhaleStyle.MUTED)
	play_hint.name = "CardPlayHint"
	play_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var target_button := _cmd_button(card_panel, "切换目标", _cycle_target, "target")
	target_button.name = "CardTargetButton"
	target_button.position = Vector2(1200, 122); target_button.size = Vector2(178, 50)
	card_panel.hide()
	card_preview = WhaleStyle.panel(root, Vector2(0, 220), Vector2(270, 416), "paper")
	card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_preview_art = load("res://battle/card_face.gd").new()
	card_preview_art.position = Vector2(14, 12)
	card_preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_preview.add_child(card_preview_art)
	card_preview_text = WhaleStyle.label(card_preview, "", Vector2(18, 383), Vector2(234, 26), 17, WhaleStyle.INK)
	card_preview.hide()

## 底部状态坞：头像 + 等级 + 状态图标 + 生命/体力/AP
func _build_dock() -> void:
	var dock := WhaleStyle.panel(root, Vector2.ZERO, Vector2(1000, DOCK_H), "status")
	UiFit.pin_wide(dock, DOCK_MARGIN, DOCK_MARGIN, DOCK_TOP, DOCK_H)
	dash["dock"] = dock

	var frame := WhaleStyle.panel(dock, Vector2(16, 16), Vector2(108, 108), "card")
	dash["portrait_frame"] = frame
	WhaleStyle.PaintedUi.apply(frame,"portrait")
	var face := TextureRect.new()
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	face.position = Vector2(8, 8)
	face.size = Vector2(92, 92)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.texture = PaintedMascot.illustration("healthy")
	frame.add_child(face)
	dash["portrait"] = face

	dash["name"] = WhaleStyle.label(dock, "", Vector2(146, 24), Vector2(270, 40), 26)
	dash["vitals"] = WhaleStyle.label(dock, "", Vector2(146, 65), Vector2(270, 26), 17, WhaleStyle.MUTED)

	# 状态图标行：护盾 / 加速 / 束缚 三个槽，用图标亮灭表示，不占文字宽度
	var icons := Control.new()
	icons.position = Vector2(146, 100)
	icons.size = Vector2(240, 32)
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(icons)
	dash["status_icons"] = icons
	dash["icons"] = {}
	# 状态图标直接用素材包里的 64x64 战斗图标（护盾 / 加速 / 束缚），按原尺寸摆放。
	# 原来用的是工程里通用的 wave / star / status 三个 svg —— 形状和语义对不上
	# （加速画的是星星、束缚画的是个通用标记），而且被压到 36px，像素细节全糊了。
	# 64px 原尺寸 + NEAREST，一格像素对一格屏幕像素，不需要任何缩放。
	#
	# 去掉了原来垫在下面的方框底板：素材图标自带粗描边和外框，
	# 再套一层底板只会显得脏，而且底板会把图标挤小。
	var specs := ["shield", "haste", "bind"]
	for i in specs.size():
		var key: String = specs[i]
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.texture = load(_pack_icon(key))
		icon.position = Vector2(i * 40, 0)
		icon.size = Vector2(32, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icons.add_child(icon)
		icon.visible = false
		dash["icons"][key] = icon

	# 三条槽：生命 / 体力 / AP。横向三栏，宽度在 _layout() 里按坞宽均分。
	# 每条带一个图标（心跳 / 水波 / 星）—— 三根同形状的条只靠文字区分，
	# 扫一眼分不出来，图标能在不读字的情况下定位。
	dash["gauges"] = []
	# 图标同样来自素材包（32px 最近邻版，按原尺寸显示）：
	# 爱心 = 生命、闪电 = 体力、水滴 = AP（本作 AP 是「潮汐连携」，水滴对应潮汐）
	for spec2 in [["生命", HP_FILL, "health"], ["体力", SP_FILL, "energy"], ["连携", AP_FILL, "mana"]]:
		dash["gauges"].append(_gauge(dock, str(spec2[0]), spec2[1], str(spec2[2])))
	dash["block_badge"]=_build_block_badge(dock)

## Block has no maximum: show its remaining amount rather than an arbitrary percentage.
func _build_block_badge(parent:Node,show_caption:bool=true)->Dictionary:
	var panel:=Panel.new()
	panel.name="BlockBadge"
	panel.size=Vector2(174,40) if show_caption else Vector2(90,40)
	panel.mouse_filter=Control.MOUSE_FILTER_PASS
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("ccf4f1")
	style.border_color=Color("383655")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color=Color(.16,.27,.33,.13)
	style.shadow_size=1;style.shadow_offset=Vector2(0,2)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var icon:=TextureRect.new()
	icon.texture=load(_pack_icon("block_counter"))
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.position=Vector2(2,0);icon.size=Vector2(40,40)
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	var caption:=WhaleStyle.label(panel,"格挡",Vector2(50,6),Vector2(50,28),20,Color("383655"))
	caption.visible=show_caption
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var value:=WhaleStyle.label(panel,"0",Vector2(112,2),Vector2(48,36),28 if show_caption else 25,Color("414a7b"))
	value.add_theme_font_override("font",WhaleStyle.numeric_font())
	value.autowrap_mode=TextServer.AUTOWRAP_OFF
	value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	value.add_theme_constant_override("outline_size",0)
	return {"panel":panel,"icon":icon,"caption":caption,"value":value,"style":style}

func _set_block_badge(badge:Dictionary,amount:float,always_visible:bool=false)->void:
	var active:=amount>0
	badge.panel.visible=active or always_visible
	badge.value.text=str(ceili(maxf(0,amount)))
	var value_font_size:int=(24 if badge.value.text.length()>3 else 28) if badge.caption.visible else 25
	badge.value.add_theme_font_size_override("font_size",value_font_size)
	var value_width:float=maxf(48 if badge.caption.visible else 36,badge.value.get_theme_font("font").get_string_size(badge.value.text,HORIZONTAL_ALIGNMENT_LEFT,-1,value_font_size).x+12)
	badge.value.size.x=value_width
	# The symbol stays square; only the number compartment grows for larger values.
	badge.value.position.x=112 if badge.caption.visible else 44
	badge.panel.size.x=badge.value.position.x+value_width+14
	badge.panel.tooltip_text="格挡：%d 点。受到伤害时先消耗格挡，再扣除生命；与按回合持续的护盾效果独立。" % ceili(maxf(0,amount))
	badge.style.bg_color=Color("ccf4f1") if active else Color("d7dff1")
	badge.style.border_color=Color("383655") if active else Color("969eba")
	badge.icon.modulate=Color.WHITE if active else Color(.78,.85,.87,.65)
	badge.caption.add_theme_color_override("font_color",Color("383655") if active else Color("696d90"))
	badge.value.add_theme_color_override("font_color",Color("414a7b") if active else Color("696d90"))

func _gauge(parent: Node, title: String, fill: Color, icon_name: String = "") -> Dictionary:
	var group := Control.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(group)
	var tile:=WhaleStyle.panel(group,Vector2(-12,12),Vector2(300,110),"paper")
	tile.name="StatusTile";tile.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_name != "":
		var icon_path: String = _pack_icon(icon_name)
		if ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path)
	group.add_child(icon)
	var title_label := WhaleStyle.label(group, title, Vector2(30, 36), Vector2(80, 30), 22)
	var value_label := WhaleStyle.label(group, "", Vector2(0, 32), Vector2(200, 32), 21)
	value_label.add_theme_font_override("font",WhaleStyle.numeric_font())
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var back := Panel.new()
	back.clip_contents = true
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("edf0f2")
	sb.set_corner_radius_all(9)
	sb.border_color = Color("c4d8df")
	sb.set_border_width_all(2)
	back.add_theme_stylebox_override("panel", sb)
	WhaleStyle.PaintedUi.apply(back,"gauge_track")
	group.add_child(back)
	var fill_node := Panel.new()
	fill_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = fill
	fs.set_corner_radius_all(8)
	fill_node.add_theme_stylebox_override("panel", fs)
	WhaleStyle.PaintedUi.apply(fill_node,"gauge_fill",fs)
	back.add_child(fill_node)
	# 高光条：贴在填充条的顶部一小条半透明白。
	# 平面纯色条看起来是「一块色块」，加一道高光才有圆柱感，成本只有一个 Panel。
	var gloss := Panel.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gs := StyleBoxFlat.new()
	gs.bg_color = Color(1, 1, 1, 0.22)
	gs.set_corner_radius_all(6)
	gloss.add_theme_stylebox_override("panel", gs)
	fill_node.add_child(gloss)
	gloss.hide()
	return {"group": group, "title": title_label, "value": value_label, "icon": icon,
		"back": back, "fill": fill_node, "gloss": gloss, "style": fs, "base_color": fill}

## 飘字层。建在状态坞之后、结算层之前：CanvasItem 按树序绘制，
## 这样伤害数字压在立绘和血条上面，但不会盖住结算面板。
func _build_fx() -> void:
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fx_layer)
	UiFit.fill(fx_layer)
	# 入场白闪。放在飘字层之后、结算层之前：压得住世界和 HUD，
	# 但不会盖住结算面板（结算时它早就淡完了，而且一直 hidden）。
	intro_flash = ColorRect.new()
	intro_flash.color = Color(1, 1, 1, 0.0)
	intro_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(intro_flash)
	UiFit.fill(intro_flash)
	intro_flash.hide()

## 入场演出：白闪 + 敌人层从下方滑入 + 状态坞推入 + 指令窗从右侧滑入。
##
## 目的不是「好看」，是把画面从上一个场景里**切出来**。
## 没有它的时候战斗界面是硬切进来的：玩家需要半秒才反应过来自己在看什么，
## 而且敌我位置、血条、指令窗是同时出现的，眼睛没有先后可以跟。
## 有了这半秒，视线会自然地从中间的敌人 → 底部的血条 → 右下角的指令窗。
func _play_intro() -> void:
	if root == null or not is_instance_valid(root):
		return
	if intro_flash != null and is_instance_valid(intro_flash):
		intro_flash.show()
		intro_flash.color = Color(1, 1, 1, 0.85)
	var t := create_tween()
	t.set_parallel(true)
	if intro_flash != null and is_instance_valid(intro_flash):
		t.tween_property(intro_flash, "color:a", 0.0, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if enemy_layer != null and is_instance_valid(enemy_layer):
		enemy_layer.position = Vector2(0.0, 56.0)
		t.tween_property(enemy_layer, "position:y", 0.0, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var dock: Variant = dash.get("dock")
	if dock != null and is_instance_valid(dock):
		var dock_node: Panel = dock
		var dock_home := dock_node.position.y
		dock_node.position.y = dock_home + 96.0
		t.tween_property(dock_node, "position:y", dock_home, 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if command_box != null and is_instance_valid(command_box):
		# 指令窗是 pin_right 的，位移只能改 offset；左右两边一起挪才是平移而不是拉伸
		var left_home := command_box.offset_left
		var right_home := command_box.offset_right
		command_box.offset_left = left_home + 280.0
		command_box.offset_right = right_home + 280.0
		t.tween_property(command_box, "offset_left", left_home, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(command_box, "offset_right", right_home, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if intro_flash != null and is_instance_valid(intro_flash):
		t.chain().tween_callback(Callable(intro_flash, "hide"))

func _build_result() -> void:
	result_shade = ColorRect.new()
	result_shade.color = Color(.05, .09, .16, .55)
	result_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(result_shade)
	UiFit.fill(result_shade)
	# Leave a separate illustration area above the summary and rewards.
	result_box = WhaleStyle.panel(root, Vector2.ZERO, Vector2(640, 580))
	UiFit.pin_center(result_box, 640, 240, 580)
	# Generated victory/recovery illustrations are displayed at their original proportions.
	result_banner = TextureRect.new()
	result_banner.texture = PaintedMascot.illustration("win")
	result_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_banner.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	result_banner.position = Vector2(80, 20)
	result_banner.size = Vector2(480, 192)
	result_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_box.add_child(result_banner)
	result_label = WhaleStyle.label(result_box, "", Vector2(24, 222), Vector2(592, 56), 36)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_details = WhaleStyle.label(result_box, "", Vector2(36, 284), Vector2(568, 85), 21)
	result_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_rewards = HBoxContainer.new()
	result_rewards.position = Vector2(36, 380); result_rewards.size = Vector2(568, 100)
	result_rewards.add_theme_constant_override("separation", 12)
	result_rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_child(result_rewards)
	result_go = _cmd_button(result_box, "继续", _on_continue)
	WhaleStyle.primary(result_go)
	result_go.position = Vector2(140, 506)
	result_go.size = Vector2(360, 50)
	result_shade.hide()
	result_box.hide()

# ---------------------------------------------------------------- 版面

## 窗口比例是 expand 的，画布宽度会变；横向排布的东西必须在每次 resized 时重算，
## 否则 16:9 下右半边会空出一大片。
func _layout() -> void:
	if root == null or not is_instance_valid(root) or root.size.x <= 1.0:
		return
	# 指令窗宽度先定：敌人区要靠它才知道右边能占到哪
	cmd_w = clampf(root.size.x * 0.38, 500.0, 600.0)
	_layout_dock()
	_layout_command()
	if engine != null and engine.card_mode: _layout_card_hand()
	_layout_enemies()
	if engine != null and not ally.is_empty():
		_refresh_ally()
		_refresh_enemies()

func _layout_enemies() -> void:
	var width := enemy_layer.size.x
	var active: Array = []
	for slot in slots:
		if slot.foe == null:
			slot.holder.hide()
		else:
			active.append(slot)
	if active.is_empty():
		return
	var left := DOCK_MARGIN
	var area := width - DOCK_MARGIN * 2.0
	if engine.card_mode:
		left = clampf(width * 0.31, 430.0, 600.0)
		area = width - left - 48.0
	var total_weight := 0.0
	for slot in active:
		total_weight += 440.0 if str(slot.foe.kind) == "gpt6" and engine.card_mode else 280.0
	var available := area - 28.0 * float(active.size() - 1)
	var cursor := left
	for slot in active:
		var weight := 440.0 if str(slot.foe.kind) == "gpt6" and engine.card_mode else 280.0
		var cell_w := available * weight / total_weight
		_layout_one_enemy(slot, cursor + cell_w * 0.5, minf(cell_w, ENEMY_CELL_MAX_W))
		cursor += cell_w + 28.0

func _layout_one_enemy(slot: Dictionary, cx: float, cell_w: float) -> void:
	var ground_y: float = 668.0 if engine.card_mode else GROUND_Y
	var height_limit: float = 250.0 if engine.card_mode else ENEMY_CELL_H
	if engine.card_mode and str(slot.foe.kind) == "gpt6":
		height_limit = 552.0
	var art_data: Dictionary = slot.get("art_data", {})
	var used: Rect2i = art_data.get("used", Rect2i())
	if used.size.x <= 0 or used.size.y <= 0:
		return
	var scale := minf(height_limit / float(used.size.y), cell_w / float(used.size.x))
	var src: Vector2i = art_data.get("size", used.size)
	slot.holder.show()
	slot.holder.position = Vector2.ZERO
	slot.holder.size = enemy_layer.size

	# 立绘：按 alpha 可见框对齐，让「可见的脚底」正好落在 ground_y 上
	var draw_w := float(src.x) * scale
	var draw_h := float(src.y) * scale
	var visible_cx := float(used.position.x + used.end.x) * 0.5 * scale
	var art: TextureRect = slot.art
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if str(slot.foe.kind) == "gpt6" else CanvasItem.TEXTURE_FILTER_NEAREST
	slot["art_home"]=Vector2(cx - visible_cx, ground_y - float(used.end.y) * scale)
	art.position = slot.art_home+slot.get("reaction_offset",Vector2.ZERO)+slot.get("attack_offset",Vector2.ZERO)
	art.size = Vector2(draw_w, draw_h)
	art.pivot_offset=art.size*Vector2(.5,.9)
	slot.intent.position = Vector2(cx - cell_w * 0.5, art.position.y - 34.0)
	slot.intent.size = Vector2(cell_w, 32.0)

	var foot_w := minf(cell_w * 0.72, draw_w * 0.78)
	# 台子：比影子宽一圈，纵向压在脚下 —— 上沿在脚线之上、下沿略低于脚线，
	# 这样读起来是「站在一个圆台上」而不是「踩着一个椭圆」。
	# 下沿必须收在 ground_y+14 以内，否则会被名字牌（ground_y+8 起）盖住。
	var rim: Panel = slot.dais_rim
	rim.position = Vector2(cx - foot_w * 0.62, ground_y - 16.0)
	rim.size = Vector2(foot_w * 1.24, 28.0)
	var top: Panel = slot.dais_top
	top.position = Vector2(cx - foot_w * 0.58, ground_y - 13.0)
	top.size = Vector2(foot_w * 1.16, 22.0)
	var shadow: Panel = slot.shadow
	shadow.position = Vector2(cx - foot_w * 0.42, ground_y - 8.0)
	shadow.size = Vector2(foot_w * 0.84, 14.0)

	var plate_w := minf(cell_w, 268.0)
	var plate: Panel = slot.plate
	plate.position = Vector2(cx - plate_w * 0.5, ground_y + 8.0)
	plate.size = Vector2(plate_w, 34.0)
	if engine.card_mode:
		plate.size.y = 66.0
	# 名字与血量数字同处一块铭牌。血量放进牌里而不是挂在血条下面 ——
	# 挂在下面时第三条信息会顶到 y≈715，正好钻进战报板（700 起）。
	slot.name.position = Vector2(14.0, 4.0)
	slot.name.size = Vector2(plate_w * 0.52, 26.0)
	slot.hp.position = Vector2(plate_w * 0.44, 5.0)
	slot.hp.size = Vector2(plate_w * 0.48, 24.0)

	var bar_w := minf(cell_w, 300.0)
	var bar_back: Panel = slot.bar_back
	bar_back.position = Vector2(cx - bar_w * 0.5, ground_y + 48.0)
	bar_back.size = Vector2(bar_w, 18.0)
	if engine.card_mode:
		bar_w = plate_w - 24.0
		bar_back.position = Vector2(cx - bar_w * 0.5, ground_y + 37.0)
		bar_back.size = Vector2(bar_w, 12.0)
		slot.intent.position = Vector2(cx - plate_w * 0.5 + 36.0, ground_y + 50.0)
		slot.intent.size = Vector2(plate_w - 48.0, 24.0)
		slot.intent_icon.position = Vector2(cx - plate_w * 0.5 + 12.0, ground_y + 53.0)
		slot.intent_icon.size = Vector2(18, 18)
	# 刻度：3 条把血条分成 4 格（25% 一档），落在填充区内侧
	var ticks: Array = slot.ticks
	var tick_inner := bar_w - 8.0
	for i in ticks.size():
		var tick: ColorRect = ticks[i]
		tick.position = Vector2(4.0 + tick_inner * float(i + 1) / 4.0 - 0.5, 3.0)
		tick.size = Vector2(1.0, bar_back.size.y - 6.0)
	var mark: Control = slot.mark
	mark.position = Vector2(cx - plate_w*.5 - 26.0,ground_y+10)
	mark.size = Vector2(24.0,30.0)

	# Centre the numeric block badge and active timed statuses as one row beneath HP.
	# Hidden status slots leave no gaps; the row remains above the battle log.
	var status: Array = slot.get("status", [])
	var active_status:Array=[]
	for si in status:
		if si.visible:active_status.append(si)
	var badge:Panel=slot.block_badge.panel
	var status_width:=float(active_status.size())*34.0
	var badge_width:=badge.size.x+8 if badge.visible else 0.0
	var status_x:=cx-(status_width+badge_width)*.5
	badge.position=Vector2(status_x,ground_y+(78 if engine.card_mode else 70))
	status_x+=badge_width
	for i in active_status.size():
		active_status[i].position=Vector2(status_x+float(i)*34,ground_y+(80 if engine.card_mode else 74))
		active_status[i].size=Vector2(24,24) if engine.card_mode else Vector2(32,32)

	var hit: Control = slot.hit
	hit.position = art.position
	hit.size = art.size

func _layout_dock() -> void:
	if engine != null and engine.card_mode:
		_layout_card_dock()
		return
	var dock: Panel = dash.get("dock")
	if dock == null:
		return
	var compact:bool = engine != null and engine.card_mode
	dash.vitals.hide()
	dash.status_icons.position=Vector2(146,118)
	for i in dash.icons.size():
		var status_icon:TextureRect=dash.icons.values()[i]
		status_icon.position.x=i*28
		status_icon.size=Vector2(20,20)
	if compact:
		UiFit.pin_wide(dock, DOCK_MARGIN, DOCK_MARGIN, CARD_DOCK_TOP, CARD_DOCK_HEIGHT)
		dash.portrait_frame.position=Vector2(20,28);dash.portrait_frame.size=Vector2(82,82)
		dash.portrait.position=Vector2(10,10);dash.portrait.size=Vector2(62,62)
		dash.name.position=Vector2(124,26);dash.name.size=Vector2(210,36)
		dash.name.add_theme_font_size_override("font_size",24)
		dash.vitals.position=Vector2(124,72);dash.vitals.size=Vector2(210,28)
		dash.status_icons.position=Vector2(124,116)
	var dock_w := dock.size.x
	var gauges: Array = dash.get("gauges", [])
	if gauges.is_empty():
		return
	var x0 := 350.0 if compact else 430.0
	var x1 := dock_w - 34.0
	var gap := 32.0 if compact else 26.0
	var gw := (x1 - x0 - gap * float(gauges.size() - 1)) / float(gauges.size())
	gw = maxf(150.0, gw)
	for i in gauges.size():
		var g: Dictionary = gauges[i]
		var group: Control = g.group
		group.position = Vector2(x0 + float(i) * (gw + gap), 0.0)
		group.size = Vector2(gw, DOCK_H)
		var tile:Panel=group.get_node("StatusTile")
		tile.size=Vector2(gw+24,110)
		var back: Panel = g.back
		back.position = Vector2(0.0, 72.0)
		back.size = Vector2(gw, 30.0)
		# 标题靠左（给图标留出 30px）、数值靠右同处一行：数字变长只会吃掉中间的留白，不会互相压住
		var icon: Variant = g.get("icon")
		if icon != null and is_instance_valid(icon):
			var ic: TextureRect = icon
			ic.position = Vector2(0.0, 26.0)
			ic.size = Vector2(32.0, 32.0)
		var title: Label = g.title
		title.position = Vector2(38.0, 28.0)
		title.size = Vector2(maxf(60.0, gw * 0.5 - 38.0), 30.0)
		var value: Label = g.value
		value.position = Vector2(gw * 0.34, 26.0)
		value.size = Vector2(gw * 0.66, 32.0)
		if compact:
			group.size.y=dock.size.y
			back.position=Vector2(0,64);back.size=Vector2(gw,24)
			if icon != null:
				icon.position=Vector2(0,20);icon.size=Vector2(32,32)
			title.position=Vector2(42,22);title.size=Vector2(76,30)
			title.add_theme_font_size_override("font_size",20)
			value.position=Vector2(gw-142,21);value.size=Vector2(142,32)
			value.add_theme_font_size_override("font_size",22)
	var block_panel:Panel=dash.block_badge.panel
	block_panel.position=Vector2(124,70) if compact else Vector2(146,72)

func _layout_command() -> void:
	if command_box != null:
		UiFit.pin_wide(command_box,DOCK_MARGIN,DOCK_MARGIN,CMD_TOP,CMD_H)
		action_list.size=Vector2(root.size.x-DOCK_MARGIN*2-36,56)
		command_hint.position=Vector2(230,6);command_hint.size=Vector2(root.size.x-DOCK_MARGIN*2-250,26)
		command_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		for b in command_buttons:
			b.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			b.focus_neighbor_left=b.get_path_to(command_buttons[posmod(command_buttons.find(b)-1,command_buttons.size())])
			b.focus_neighbor_right=b.get_path_to(command_buttons[(command_buttons.find(b)+1)%command_buttons.size()])
	var info_w: float=clampf(root.size.x*.40,500,660)
	UiFit.pin_right(tactics_box,info_w,DOCK_MARGIN,LOG_TOP,LOG_H)
	UiFit.pin_left(log_box,root.size.x-info_w-DOCK_MARGIN*2-16,DOCK_MARGIN,LOG_TOP,LOG_H)
	log_text.size=Vector2(log_box.size.x-140,LOG_H-16)
	if tactics_box != null:
		tactics_name.size.x=info_w-145;tactics_text.size.x=info_w-36
	if skill_box != null:
		UiFit.pin_right(skill_box,cmd_w,DOCK_MARGIN,174,604)
		submenu_title.size.x = cmd_w-142
		submenu_back.position = Vector2(cmd_w-114, 12)
		submenu_back.custom_minimum_size.y=36
		submenu_back.add_theme_font_size_override("font_size",18)
		submenu_scroll.position=Vector2(16,64);submenu_scroll.size=Vector2(cmd_w-32,292)
		var effect: Panel=skill_box.get_node("EffectCard")
		effect.position=Vector2(16,370);effect.size=Vector2(cmd_w-32,218)
		detail_name.position=Vector2(16,12);detail_name.size=Vector2(cmd_w-64,34)
		detail_text.position=Vector2(16,58);detail_text.size=Vector2(cmd_w-64,146)

func _card_overlay(panel: Panel, background: Color, radius: int = 16) -> void:
	panel.set_script(null)
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(0.76, 0.87, 1.0, 0.45)
	style.set_border_width_all(1 if background.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", style)

func _hud_frame(panel: Panel, background: Color, radius: int = 24, inner: bool = false) -> void:
	panel.set_script(LayeredPanel)
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color("40567d")
	style.set_border_width_all(0 if inner else 2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color("40567d", 0.0 if inner else 0.24)
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO if inner else Vector2(2, 3)
	panel.add_theme_stylebox_override("panel", style)

func _hud_text(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("31547e"))
	label.add_theme_constant_override("outline_size", 0)

func _style_card_battle() -> void:
	_card_overlay(card_panel, Color.TRANSPARENT)
	_hud_frame(dash.dock, Color("dceaff"), 20)
	_card_overlay(dash.portrait_frame, Color.TRANSPARENT)
	dash["level"] = WhaleStyle.label(dash.dock, "", Vector2(106, 56), Vector2(188, 26), 18, Color("647c99"))
	dash.level.name = "CompactLevel"
	dash["hp_max"] = WhaleStyle.label(dash.gauges[0].group, "", Vector2(184, 24), Vector2(92, 44), 18, Color("647c99"))
	dash.hp_max.name = "CompactHealthMaximum"
	dash.hp_max.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hud_frame(title_plate, Color("cedfff"), 18)
	_hud_frame(phase_plate, Color("ade4e7"), 18)
	_hud_frame(log_box, Color("e4edff"), 18)
	_hud_frame(card_panel.get_node("CardEnergyBadge"), Color("4d77c5"), 52)
	var resources := Panel.new()
	resources.name = "EnergyResourcesFrame"
	resources.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(resources)
	card_panel.move_child(resources, 0)
	_hud_frame(resources, Color("d8e5ff"), 18, true)
	var counts_frame := Panel.new()
	counts_frame.name = "DeckCountsFrame"
	counts_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resources.add_child(counts_frame)
	_hud_frame(counts_frame, Color("edf3ff"), 12, true)
	var log_caption: Panel = log_box.get_node("LogCaption")
	_hud_frame(log_caption, Color("cbdfff"), 12, true)
	log_caption.show()
	tactics_box.hide()
	_hud_text(dash.name, 24)
	_hud_text(phase_label, 20)
	_hud_text(card_counts, 18)
	_hud_text(title_label, 22)
	round_label.add_theme_color_override("font_color", Color("4973ae"))
	for action in [speed_button, card_panel.get_node("CardTargetButton"), card_item_button, card_link_button, card_end_button]:
		_style_card_action(action, action == card_end_button)
	_card_overlay(dash.block_badge.panel, Color.TRANSPARENT)
	for i in dash.gauges.size():
		var gauge: Dictionary = dash.gauges[i]
		gauge.group.get_node("StatusTile").show()
		if i == 0:
			_hud_frame(gauge.group.get_node("StatusTile"), Color("f8fbff"), 14, true)
		else:
			_card_overlay(gauge.group.get_node("StatusTile"), Color.TRANSPARENT)
		_hud_text(gauge.title, 16)
		_hud_text(gauge.value, 30 if i == 0 else 18)
		if i > 0:
			var track := StyleBoxFlat.new()
			track.bg_color = Color("eaf0f7")
			track.border_color = Color("b7c6d9")
			track.set_border_width_all(1)
			track.set_corner_radius_all(3)
			track.set_content_margin_all(0)
			gauge.back.add_theme_stylebox_override("panel", track)
			gauge.title.add_theme_color_override("font_color", Color("647c99"))
			gauge.value.add_theme_color_override("font_color", Color("647c99"))
			gauge.fill.modulate = Color(0.88, 0.92, 0.96)
	for slot in slots:
		_hud_frame(slot.plate, Color("f4f9ff"), 12)
		_hud_text(slot.name, 20)
		_hud_text(slot.hp, 16)
		_hud_text(slot.intent, 16)
		slot.intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot.intent.add_theme_color_override("font_color", Color("5b718f"))
	backdrop.z_index = -3
	root.get_child(1).z_index = -2
	var battlefield := Panel.new()
	battlefield.name = "BattlefieldFrame"
	battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield.z_index = -1
	root.add_child(battlefield)
	_hud_frame(battlefield, Color("c3dcff", 0.14), 28)
	battlefield.hide()
	var hand_frame := Panel.new()
	hand_frame.name = "HandAreaFrame"
	hand_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_frame.z_index = -1
	root.add_child(hand_frame)
	_hud_frame(hand_frame, Color("c7d9fb", 0.96), 24)
	var action_frame := Panel.new()
	action_frame.name = "ActionFrame"
	action_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_frame.add_child(action_frame)
	_hud_frame(action_frame, Color("d4e3ff"), 18, true)
	var caption := WhaleStyle.label(card_panel, "手牌", Vector2.ZERO, Vector2(100, 24), 17, Color("416ca9"))
	caption.name = "HandCaption"
	var actions_caption := WhaleStyle.label(card_panel, "回合行动", Vector2.ZERO, Vector2(168, 24), 17, Color("416ca9"))
	actions_caption.name = "ActionsCaption"

func _style_card_action(button: Button, primary: bool = false) -> void:
	button.set_script(LayeredButton)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("73c4d6") if primary else Color("f3f7fc")
		box.border_color = Color("315d77") if primary else Color("476189")
		box.set_border_width_all(2)
		box.set_corner_radius_all(14)
		box.shadow_color = Color("40567d", 0.24)
		box.shadow_offset = Vector2(1, 3)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		if state in ["hover", "focus"]:
			box.bg_color = Color("91d9df") if primary else Color("e4edf8")
			box.border_color = Color("2f729b")
		elif state in ["pressed", "hover_pressed"]:
			box.bg_color = Color("66b7ca") if primary else Color("d1e0f2")
			box.shadow_offset = Vector2(0, 1)
		elif state == "disabled":
			box.bg_color = Color("e2e8f1")
			box.border_color = Color("aab8cb")
			box.shadow_color = Color("40567d", 0.10)
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("1d537c") if primary else Color("315ca4"))
	button.add_theme_color_override("font_disabled_color", Color("7c8da4"))
	button.add_theme_constant_override("icon_max_width", 24)
	button.add_theme_constant_override("h_separation", 8)

func _layout_card_dock() -> void:
	var dock: Panel = dash.dock
	UiFit.pin_left(dock, 312, 28, 376, 390)
	dash.portrait_frame.position = Vector2(18, 18)
	dash.portrait_frame.size = Vector2(72, 72)
	dash.portrait.position = Vector2.ZERO
	dash.portrait.size = Vector2(72, 72)
	dash.name.position = Vector2(106, 20)
	dash.name.size = Vector2(188, 32)
	dash.name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dash.vitals.hide()
	dash.block_badge.panel.position = Vector2(18, 216)
	dash.status_icons.position = Vector2(210, 218)
	dash.status_icons.size = Vector2(84, 24)
	for i in dash.icons.size():
		var icon: TextureRect = dash.icons.values()[i]
		icon.position = Vector2(i * 30, 0)
		icon.size = Vector2(24, 24)
	for i in dash.gauges.size():
		var gauge: Dictionary = dash.gauges[i]
		gauge.group.position = Vector2(18, [112.0, 264.0, 316.0][i])
		gauge.group.size = Vector2(276, 96 if i == 0 else 38)
		var tile: Panel = gauge.group.get_node("StatusTile")
		tile.position = Vector2(-2, -8 if i == 0 else -4)
		tile.size = Vector2(280, 148 if i == 0 else 44)
		gauge.icon.position = Vector2(0, 0)
		gauge.icon.size = Vector2(24, 24)
		gauge.title.position = Vector2(30, -2)
		gauge.title.size = Vector2(76, 26)
		gauge.value.position = Vector2(72, 24) if i == 0 else Vector2(100, -2)
		gauge.value.size = Vector2(104, 44) if i == 0 else Vector2(176, 26)
		gauge.value.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if i == 0 else VERTICAL_ALIGNMENT_CENTER
		gauge.back.position = Vector2(0, 78 if i == 0 else 30)
		gauge.back.size = Vector2(276, 16 if i == 0 else 6)

func _layout_card_hand() -> void:
	if card_panel == null:
		return
	UiFit.pin_wide(card_panel, 24, 24, 786, 280)
	var w := card_panel.size.x
	UiFit.pin_wide(root.get_node("BattlefieldFrame"), 362, 24, 94, 678)
	var hand_frame: Panel = root.get_node("HandAreaFrame")
	UiFit.pin_wide(hand_frame, 24, 24, 786, 280)
	var action_frame: Panel = hand_frame.get_node("ActionFrame")
	action_frame.position = Vector2(w - 218, 12)
	action_frame.size = Vector2(204, 256)
	var resources: Panel = card_panel.get_node("EnergyResourcesFrame")
	resources.position = Vector2(12, 12)
	resources.size = Vector2(138, 256)
	var counts_frame: Panel = resources.get_node("DeckCountsFrame")
	counts_frame.position = Vector2(8, 174)
	counts_frame.size = Vector2(122, 66)
	card_scroll.position = Vector2(164, 26)
	card_scroll.size = Vector2(w - 398, 250)
	card_row.add_theme_constant_override("separation", 16)
	card_panel.get_node("HandCaption").position = Vector2(178, 6)
	card_panel.get_node("ActionsCaption").position = Vector2(w - 196, 16)
	var energy_badge: Panel = card_panel.get_node("CardEnergyBadge")
	energy_badge.position = Vector2(29, 44)
	energy_badge.size = Vector2(104, 104)
	var energy_icon: TextureRect = energy_badge.get_node("CardEnergyIcon")
	energy_icon.position = Vector2(40, 10)
	energy_icon.size = Vector2(24, 24)
	var caption: Label = energy_badge.get_node("CardEnergyCaption")
	caption.position = Vector2(16, 74)
	caption.size = Vector2(72, 24)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color("eaf1ff"))
	card_energy_label.position = Vector2(29, 77)
	card_energy_label.size = Vector2(104, 40)
	card_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_energy_label.add_theme_font_size_override("font_size", 30)
	card_energy_label.add_theme_color_override("font_color", Color("ffe071"))
	card_counts.position = Vector2(20, 192)
	card_counts.size = Vector2(122, 54)
	card_counts.autowrap_mode = TextServer.AUTOWRAP_OFF
	card_counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var action_x := w - 206
	var target_button: Button = card_panel.get_node("CardTargetButton")
	var actions: Array = [target_button, card_item_button, card_link_button, card_end_button]
	for i in actions.size():
		actions[i].position = Vector2(action_x, 48 + i * 50 + (10 if i == 3 else 0))
		actions[i].custom_minimum_size = Vector2.ZERO
		actions[i].size = Vector2(180, 42 if i < 3 else 58)
		actions[i].custom_minimum_size = actions[i].size
		actions[i].add_theme_font_size_override("font_size", 20 if i == 3 else 18)
	card_panel.get_node("CardPlayHint").hide()
	card_preview.position = Vector2(root.size.x - 294, 120)
	UiFit.pin_left(title_plate, 420, 24, 24, 54)
	title_label.position = Vector2(14, 8)
	title_label.size = Vector2(268, 32)
	title_label.add_theme_font_size_override("font_size", 22)
	round_label.position = Vector2(284, 8)
	round_label.size = Vector2(122, 30)
	UiFit.pin_center(phase_plate, 320, 24, 50)
	phase_label.position = Vector2(12, 6)
	phase_label.size = Vector2(296, 32)
	UiFit.pin_right(speed_button, 150, 24, 24, 44)
	UiFit.pin_left(log_box, 312, 28, 104, 118)
	var log_caption: Panel = log_box.get_node("LogCaption")
	log_caption.position = Vector2(14, 10)
	log_caption.size = Vector2(86, 28)
	log_text.position = Vector2(18, 46)
	log_text.size = Vector2(276, 62)
	log_text.add_theme_font_size_override("normal_font_size", 17)
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.mouse_filter = Control.MOUSE_FILTER_STOP

func _backdrop_texture() -> Texture2D:
	if ResourceLoader.exists(BACKGROUND_PATH):
		return load(BACKGROUND_PATH)
	var w := 192
	var h := 144
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var horizon := int(h * 0.47)
	var floor_y := int(h * 0.545)
	_sky(img, w, horizon)
	_sea(img, w, horizon, floor_y)
	_shore(img, w, floor_y)
	_floor(img, w, h, horizon, floor_y)
	_vignette(img, w, h)
	return ImageTexture.create_from_image(img)

## 天空：渐变 + 太阳暖光 + 地平线雾带。
## 太阳偏右并落在地平线下缘 —— 逆光最容易让人读出「远近」，正面平光最难。
func _sky(img: Image, w: int, horizon: int) -> void:
	var sun_x := float(w) * 0.72
	var sun_y := float(horizon) - 3.0
	for y in horizon:
		var t := float(y) / float(maxi(1, horizon))
		var base := SKY_TOP.lerp(SKY_LOW, pow(t, 0.85))
		for x in w:
			var dx := (float(x) - sun_x) / (float(w) * 0.34)
			var dy := (float(y) - sun_y) / float(maxi(1, horizon))
			var glow := clampf(1.0 - sqrt(dx * dx + dy * dy * 2.4), 0.0, 1.0)
			glow = pow(glow, 1.6) * 0.55
			img.set_pixel(x, y, base.lerp(SUN_GLOW, glow))
	_disc(img, sun_x, sun_y, 3.0, SUN_CORE)
	# 地平线雾带：海面反光把贴着地平线的天空提亮三行
	for i in 3:
		var y := horizon - 1 - i
		if y < 0:
			continue
		var mix := 0.34 - float(i) * 0.10
		for x in w:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(HAZE, mix))
	_clouds(img, w, horizon)
	# 太阳要画在云之后。第一版画在云之前，结果被远层云整片盖住 ——
	# 画面上只剩一团找不到光源的暖光，比不加光晕更奇怪。
	# 两层：外圈大而暖（光晕），内圈小而亮（本体）。
	_disc(img, sun_x, sun_y, 4.6, SUN_GLOW)
	_disc(img, sun_x, sun_y, 3.0, SUN_CORE)

## 海：按行做正弦明暗，周期与振幅都随行号变大（近大远小），
## 高浪上再撒白沫点。波浪用 sin 而不是随机 —— 随机只会得到噪点，读不出「浪」。
func _sea(img: Image, w: int, horizon: int, floor_y: int) -> void:
	for y in range(horizon, floor_y):
		var t := float(y - horizon) / float(maxi(1, floor_y - horizon))
		var row := SEA_TOP.lerp(SEA_LOW, t)
		var period := 11.0 + 16.0 * t
		var amp := 0.055 + 0.13 * t
		var phase := t * 2.6
		for x in w:
			var wave := sin((float(x) / period + phase) * TAU) * amp
			var c := row
			if wave > 0.0:
				c = row.lerp(SEA_CREST, wave)
			else:
				c = row.lerp(SEA_TROUGH, -wave)
			img.set_pixel(x, y, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717
	for y in range(horizon + 1, floor_y):
		var t := float(y - horizon) / float(maxi(1, floor_y - horizon))
		if t < 0.35:
			continue
		var period := 11.0 + 16.0 * t
		var phase := t * 2.6
		for x in w:
			if sin((float(x) / period + phase) * TAU) > 0.86 and rng.randf() < 0.32:
				img.set_pixel(x, y, FOAM)
	# 远岛与栈桥：贴着地平线的剪影，颜色介于海与天之间（大气透视）
	_island(img, float(w) * 0.17, float(horizon), 17.0, 4.0)
	_island(img, float(w) * 0.29, float(horizon), 9.0, 2.4)
	_pier(img, float(w) * 0.87, float(horizon), 15)
	# 海天分界线：只靠明度差，天空和海会在低分辨率下糊成一片，找不到地平线在哪
	for x in w:
		if horizon >= 0 and horizon < img.get_height():
			img.set_pixel(x, horizon, HORIZON)

## 岸线：泡沫线（顶边做成不齐的阶梯，直的会像贴纸）+ 下面两行湿沙压暗
func _shore(img: Image, w: int, floor_y: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9931
	for x in w:
		for i in int(rng.randf_range(0.0, 2.99)):
			var y := floor_y - 1 - i
			if y >= 0:
				img.set_pixel(x, y, FOAM)
		img.set_pixel(x, floor_y, FOAM)
	for i in 2:
		var y := floor_y + 1 + i
		if y >= img.get_height():
			continue
		for x in w:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(WET, 0.22))

## 地面：越近越亮的底色 + 透视网格。
## 横线用 pow(s,1.8) 映射行号 —— 间距随距离平方增长，这才是透视压缩；
## 竖线全部朝灭点（画面中心的地平线）收敛。
func _floor(img: Image, w: int, h: int, horizon: int, floor_y: int) -> void:
	var span := float(maxi(1, h - 1 - floor_y))
	for y in range(floor_y, h):
		var t := float(y - floor_y) / span
		var row := FLOOR_FAR.lerp(FLOOR_NEAR, pow(t, 0.7))
		for x in w:
			img.set_pixel(x, y, row)
	var vpx := float(w) * 0.5
	for k in 9:
		var s := float(k + 1) / 9.0
		var y := floor_y + int(pow(s, 1.8) * span)
		if y >= h:
			continue
		for x in w:
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(GRID, 0.55))
	for i in 13:
		var fx := (float(i) / 12.0 - 0.5) * 3.2
		for y in range(floor_y, h):
			var t := float(y - floor_y) / span
			var x := int(vpx + fx * float(w) * 0.5 * (0.18 + 0.82 * pow(t, 1.35)))
			if x >= 0 and x < w:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(GRID, 0.5))

## 四角压暗。不加这层，亮背景会把边缘的 UI 拉得看不出来，视线也没有落点。
func _vignette(img: Image, w: int, h: int) -> void:
	var c := Vector2(float(w) * 0.5, float(h) * 0.52)
	var maxd := maxf(1.0, c.length())
	for y in h:
		for x in w:
			var d := Vector2(float(x), float(y)).distance_to(c) / maxd
			var k := clampf((d - 0.55) / 0.45, 0.0, 1.0)
			if k <= 0.0:
				continue
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(VIGNETTE, k * 0.30))

## 硬边实心圆（像素风不要抗锯齿）
func _disc(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for y in range(maxi(0, int(cy - r)), mini(img.get_height(), int(cy + r) + 1)):
		for x in range(maxi(0, int(cx - r)), mini(img.get_width(), int(cx + r) + 1)):
			if Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(cx, cy)) <= r:
				img.set_pixel(x, y, color)

## 远岛：只画地平线以上的半圆，像从水里露出的山头
func _island(img: Image, cx: float, base_y: float, rx: float, ry: float) -> void:
	for y in range(maxi(0, int(base_y - ry)), int(base_y)):
		for x in range(maxi(0, int(cx - rx)), mini(img.get_width(), int(cx + rx) + 1)):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - base_y) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, ISLAND)

## 远处栈桥：一条横线加几根桩子，用来交代「这里有港口」而不是空海
func _pier(img: Image, cx: float, base_y: float, length: int) -> void:
	var y := int(base_y) - 1
	for i in length:
		var x := int(cx) - length + i
		if x < 0 or x >= img.get_width() or y < 0:
			continue
		img.set_pixel(x, y, PIER)
		if i % 3 == 0 and y - 1 >= 0:
			img.set_pixel(x, y - 1, PIER)

## 三层云：远层小而淡（贴近雾色），中层次之，近层大而白。
## 只有一层云的天空是「贴纸」，三层才读得出高度。
func _clouds(img: Image, w: int, horizon: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for layer in [[0.30, 0.62, 0.40], [0.55, 0.85, 0.66], [0.80, 1.15, 0.92]]:
		var y0 := float(horizon) * float(layer[0])
		var s := float(layer[1])
		var white := float(layer[2])
		var count := 3 + int(float(layer[0]) * 3.0)
		for i in count:
			var cx := rng.randf_range(6.0, float(w) - 6.0)
			var cy := y0 + rng.randf_range(-4.0, 4.0) * s
			var rx := rng.randf_range(7.0, 15.0) * s
			var ry := rx * rng.randf_range(0.32, 0.46)
			_blob(img, cx, cy, rx, ry, Color(1, 1, 1, white))
			_blob(img, cx + rx * 0.55, cy + ry * 0.35, rx * 0.62, ry * 0.72, Color(1, 1, 1, white * 0.92))

## 往背景图上刷一团云（椭圆）。
## 关键：只混 RGB，alpha 必须强制回 1.0。
## Color.lerp 会连 alpha 一起插值，拿它混半透明的云就会把背景自身的 alpha 也拉低
## （0.62 的云 → 整片区域 alpha 掉到 0.76），背景变成半透明，
## 下面场景的 UI 会从云里透出来 —— 看起来像层级错了，其实是这里漏了不透明度。
func _blob(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	for y in range(maxi(0, int(cy - ry) - 1), mini(img.get_height(), int(cy + ry) + 2)):
		for x in range(maxi(0, int(cx - rx) - 1), mini(img.get_width(), int(cx + rx) + 2)):
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var base := img.get_pixel(x, y)
				var blended := base.lerp(color, color.a)
				blended.a = 1.0
				img.set_pixel(x, y, blended)

# ---------------------------------------------------------------- 刷新

func _refresh_all() -> void:
	round_label.text = "第 %d 回合" % int(engine.round_no)
	_refresh_enemies()
	_refresh_ally()
	_refresh_tactics()
	if engine.card_mode: _refresh_cards()

func _refresh_cards() -> void:
	if card_panel == null or card_row == null: return
	card_energy_label.text = "%d / %d" % [int(engine.card_energy), int(engine.card_energy_max)]
	card_counts.text = "牌堆 %d\n弃牌 %d" % [engine.draw_pile.size(), engine.discard_pile.size()]
	card_end_button.disabled=mode!="command"
	card_item_button.disabled=mode!="command" or (context.get("items",[]) as Array).is_empty()
	card_panel.get_node("CardTargetButton").disabled=mode!="command"
	card_link_button.disabled = mode!="command" or not bool(engine.link_status(engine.allies[0]).ready)
	card_first_ready = null
	for child in card_row.get_children():
		card_row.remove_child(child)
		child.queue_free()
	for entry in engine.card_hand_view():
		var index := int(entry.index)
		var button = load("res://battle/card_face.gd").new()
		button.configure(entry, Vector2(182, 222))
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not bool(entry.ready) or mode != "command"
		button.mouse_entered.connect(func():_preview_card(entry))
		button.focus_entered.connect(func():_preview_card(entry))
		button.mouse_exited.connect(func():card_preview.hide())
		button.pressed.connect(func():_submit_action({"kind":"card", "index":index, "target":_selected_target()}))
		card_row.add_child(button)
		if card_first_ready == null and not button.disabled: card_first_ready = button

func _preview_card(entry: Dictionary) -> void:
	if card_preview == null or mode != "command": return
	for child in card_preview_art.get_children():
		card_preview_art.remove_child(child)
		child.queue_free()
	card_preview_art.configure(entry, Vector2(242, 360), true)
	card_preview_text.text = "作用于自身" if str(entry.get("target", "one")) == "self" else "作用于当前选中目标"
	card_preview.show()

func _target_entry() -> Dictionary:
	var pool: Array = engine.living("foe")
	return pool[clampi(int(context.get("target", 0)), 0, pool.size()-1)] if not pool.is_empty() else {}

func _refresh_tactics() -> void:
	if tactics_name == null: return
	var target := _target_entry()
	if target.is_empty(): tactics_name.text = "交战结束"; tactics_text.text = ""; return
	tactics_name.text = str(target.name)
	var states: Array[String] = []
	if int(target.shield)>0: states.append("护盾：减伤 50%% · %d 回合" % int(target.shield))
	if int(target.bind)>0: states.append("束缚：跳过行动 · %d 回合" % int(target.bind))
	if int(target.haste)>0: states.append("加速：%d 回合" % int(target.haste))
	var tip: String = {"slime":"海沫团会使用泼浪与泡沫喷射。", "crab":"珊瑚蟹会缩壳。盾亮起时伤害减半，可先补给或施加束缚。", "guardian":"守潮者擅长重击。你生命低于一半时，更容易连续承受重击。", "gpt6":"留意护盾与重击。受伤后及时治疗，或用护盾减伤。"}.get(str(target.kind), "选择目标后再决定出手方式。")
	if engine.card_mode:
		var intent: Dictionary = engine.intent_for(target)
		var planned := "普通攻击"
		if str(intent.get("kind", "")) == "skill":
			planned = str(engine.enemy_skills.get(str(intent.get("id", "")), {}).get("name", "未知行动"))
		tip = "下次：%s" % planned
	tactics_text.text = "攻击 %d · 防御 %d · %s\n%s" % [int(target.atk),int(target.def)," / ".join(states) if not states.is_empty() else "无附加状态",tip]
	if engine.card_mode:
		tactics_text.text = tip
	tactics_text.tooltip_text="攻击 %d · 防御 %d\n%s\n%s" % [int(target.atk),int(target.def)," / ".join(states) if not states.is_empty() else "无附加状态",tip]
	if command_hint != null:
		command_hint.text = "普攻：" + Guide.damage(engine, engine.allies[0], target) + "   ·   Enter 确认 / Esc 返回"

func _refresh_enemies() -> void:
	var pool: Array = engine.foes
	var alive_pool: Array = engine.living("foe")
	var ti := int(context.get("target", 0))
	if ti < 0 or ti >= alive_pool.size():
		ti = 0
		context["target"] = 0
	var target_foe: Variant = alive_pool[ti] if not alive_pool.is_empty() else null
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if i >= pool.size():
			slot.foe = null
			slot.holder.hide()
			continue
		var foe: Dictionary = pool[i]
		var visible_foe:=_display_actor(foe)
		slot.foe = foe
		var intent: Dictionary = engine.intent_for(foe) if engine.card_mode else {}
		var planned := "普通攻击"
		if str(intent.get("kind", "")) == "skill":
			planned = str(engine.enemy_skills.get(str(intent.get("id", "")), {}).get("name", "未知行动"))
		slot.intent.text = "下次 · " + planned
		slot.intent.visible = engine.card_mode and bool(visible_foe.alive)
		slot.intent_icon.visible = slot.intent.visible
		slot.intent_icon.texture = load(_pack_icon("intent_cast" if str(intent.get("kind", "")) == "skill" else "attack"))
		if slot.get("art_data", null) == null:
			var art_data := _foe_art(str(foe.kind))
			slot["art_data"] = art_data
			slot.art.texture = art_data.get("texture")
		slot.name.text = str(foe.name)
		var ratio: float = clampf(float(visible_foe.hp) / maxf(1.0, float(foe.max_hp)), 0.0, 1.0)
		# _refresh_enemies() 可能在 _layout_one_enemy() 之前被调用（窗口还没定尺寸），
		# 所以这里必须自己夹一次下限，否则会算出负的填充宽度。
		var inner := Vector2(maxf(1.0, slot.bar_back.size.x - 8.0), maxf(1.0, slot.bar_back.size.y - 8.0))
		var fill_w := inner.x * ratio
		slot.bar_fill.position = Vector2(4, 4)
		slot.bar_fill.size = Vector2(fill_w, inner.y)
		# 残影：只在「新宽度 ≥ 残影宽度」时跟上去（补血、新出现的敌人、首次排版），
		# 掉血时故意不动 —— 实心条和残影之间露出的那一段浅色，就是这一下掉了多少。
		# 收拢交给 _process 里的 _update_trails()。
		var trail_w: float = minf(float(slot.get("trail_w", 0.0)), inner.x)
		if fill_w >= trail_w:
			trail_w = fill_w
			slot["trail_w"] = trail_w
		slot.bar_trail.position = Vector2(4, 4)
		slot.bar_trail.size = Vector2(trail_w, inner.y)
		slot.hp.text = "%d / %d" % [ceili(float(visible_foe.hp)), int(foe.max_hp)]
		var down := not bool(visible_foe.alive)
		_set_block_badge(slot.block_badge,0.0 if down else float(visible_foe.get("block",0)))
		var is_target:bool=not down and ((mode=="busy" and str(foe.id)==_cast_target_id) or (target_foe!=null and foe==target_foe))
		# 被选中的敌人：台子边沿转金，和头上的箭头一起确认「这一发打谁」。
		# 每个槽有自己的一份 StyleBox 实例，改这里不会串到别人身上。
		var rim_style: StyleBoxFlat = slot.dais_rim_style
		if rim_style != null:
			rim_style.bg_color = DAIS_RIM_TARGET if is_target else DAIS_RIM
		slot.bar_style.bg_color = Color("6a7280") if down else HP_FILL
		slot.mark.visible = is_target
		slot.art.modulate = Color(1,1,1,float(slot.get("defeat_alpha",.3))) if down else Color.WHITE
		if not down:slot["defeat_alpha"]=.3
		slot.plate.modulate = Color(1, 1, 1, 0.45) if down else (Color("fff3d0") if is_target else Color.WHITE)
		slot.hit.mouse_filter = Control.MOUSE_FILTER_IGNORE if down else Control.MOUSE_FILTER_STOP
		# 敌人状态图标。倒下的敌人不显示状态 —— 一个躺着的怪物顶着「护盾」很怪。
		var st: Array = slot.get("status", [])
		var state: Dictionary = slot.get("status_state", {})
		var flags := [int(visible_foe.get("shield", 0)) > 0, int(visible_foe.get("haste", 0)) > 0, int(visible_foe.get("bind", 0)) > 0]
		var keys := ["shield", "haste", "bind"]
		for k in st.size():
			var node: TextureRect = st[k]
			var on: bool = flags[k] and not down
			var key: String = keys[k]
			if not state.has(key):
				# 第一次见到就直接摆好，不播动画（否则开战瞬间整排图标一起弹）
				state[key] = on
				node.visible = on
				node.scale = Vector2.ONE
				node.modulate.a = 1.0
			elif bool(state[key]) != on:
				state[key] = on
				_pop_status(node, on)
	_layout_enemies()

func _hover_slot(index: int, on: bool) -> void:
	if index < 0 or index >= slots.size():
		return
	var slot: Dictionary = slots[index]
	if slot.foe == null or not bool(slot.foe.alive):
		return
	slot.art.modulate = Color("fff0f2") if on else Color.WHITE

func _foe_art(kind: String) -> Dictionary:
	if portraits.has(kind):
		return portraits[kind]
	var path := str(context.get("textures", {}).get(kind, ""))
	if path == "":
		path = "res://assets/monsters/sea_slime.png"
	var out := {"texture": null, "used": Rect2i(0, 0, 1, 1), "size": Vector2i(1, 1)}
	var texture:=load(path) as Texture2D
	var img:=texture.get_image() if texture else null
	if img == null:
		portraits[kind] = out
		return out
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		used = Rect2i(0, 0, img.get_width(), img.get_height())
	var cropped:=AtlasTexture.new();cropped.atlas=texture;cropped.region=Rect2(used)
	out["texture"] = cropped
	out["used"] = Rect2i(Vector2i.ZERO,used.size)
	out["size"] = used.size
	portraits[kind] = out
	return out

func _refresh_ally() -> void:
	ally = engine.allies[0]
	var visible_ally:=_display_actor(ally)
	dash.portrait.texture=PaintedMascot.illustration("worried" if float(visible_ally.hp)/maxf(1.0,float(ally.max_hp))<=.35 else "healthy")
	dash["name"].text = "%s  ·  Lv.%d" % [str(ally.name), int(ally.level)]
	var marks: Array = []
	_set_block_badge(dash.block_badge,float(visible_ally.get("block",0)),true)
	if int(visible_ally.shield) > 0:
		marks.append("护盾 %d 回合" % int(visible_ally.shield))
	if int(visible_ally.haste) > 0:
		marks.append("加速 %d 回合" % int(visible_ally.haste))
	if int(visible_ally.bind) > 0:
		marks.append("被束缚 %d 回合" % int(visible_ally.bind))
	dash["vitals"].text = "  ·  ".join(marks) if not marks.is_empty() else "状态正常"
	dash.dock.tooltip_text="角色状态："+str(dash.vitals.text)
	for key in ["shield","haste","bind"]:
		dash.icons[key].mouse_filter=Control.MOUSE_FILTER_PASS
		dash.icons[key].tooltip_text=("护盾：%d 回合" if key=="shield" else ("加速：%d 回合" if key=="haste" else "束缚：%d 次行动")) % int(visible_ally.get(key,0))
	_set_status_icon("shield", int(visible_ally.shield) > 0)
	_set_status_icon("haste", int(visible_ally.haste) > 0)
	_set_status_icon("bind", int(visible_ally.bind) > 0)

	var gauges: Array = dash["gauges"]
	_set_gauge(gauges[0], float(visible_ally.hp), float(ally.max_hp), "%d / %d" % [ceili(float(visible_ally.hp)), int(ally.max_hp)])
	_set_gauge(gauges[1], float(visible_ally.stamina), float(ally.max_stamina), "%d / %d" % [ceili(float(visible_ally.stamina)), int(ally.max_stamina)])
	var link: Dictionary = engine.link_status(visible_ally)
	_set_gauge(gauges[2], float(link.ap), float(link.max_ap), "%d%%" % int(round(float(link.ap) / maxf(1.0, float(link.max_ap)) * 100.0)))

	var ready := bool(link.ready)
	if engine.card_mode:
		_refresh_compact_card_status(visible_ally, ready)
	if ready != _ap_ready:
		_ap_ready = ready
		gauges[2].style.bg_color = AP_READY if ready else AP_FILL
		if ready:
			_append_log("潮汐连携已就绪 — 可以发动了。", "b8860b")
	link_button.disabled = not ready
	link_button.tooltip_text = str(link.desc) if ready else str(link.reason)
	if card_link_button != null: card_link_button.disabled = not ready

func _refresh_compact_card_status(visible_ally: Dictionary, link_ready: bool) -> void:
	dash.name.text = str(ally.name)
	dash.level.text = "Lv.%d" % int(ally.level)
	var health: Dictionary = dash.gauges[0]
	health.value.text = str(ceili(float(visible_ally.hp)))
	dash.hp_max.text = "/ %d" % int(ally.max_hp)
	var low := float(visible_ally.hp) / maxf(1.0, float(ally.max_hp)) <= 0.2
	health.value.add_theme_color_override("font_color", Color("a74762") if low else Color("31547e"))
	dash.gauges[2].value.add_theme_color_override("font_color", Color("31547e") if link_ready else Color("647c99"))
	var badge: Dictionary = dash.block_badge
	badge.panel.size = Vector2(180, 28)
	badge.icon.position = Vector2.ZERO
	badge.icon.size = Vector2(24, 24)
	badge.caption.position = Vector2(32, 2)
	badge.caption.size = Vector2(42, 24)
	badge.caption.add_theme_font_size_override("font_size", 16)
	badge.value.position = Vector2(80, 0)
	badge.value.size = Vector2(80, 28)
	badge.value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.value.add_theme_font_size_override("font_size", 22)
	badge.value.add_theme_color_override("font_color", Color("31547e") if float(visible_ally.get("block", 0)) > 0 else Color("8494aa"))

## 状态图标的出现 / 消失演出。
## 直接切 visible 的话，「护盾没了」这件事几乎不会被注意到 —— 图标在视线边缘，
## 静默消失等于没发生，而它恰恰是「下回合要挨打了」的信号。
## 出现时过冲弹一下、消失时缩掉淡出，眼睛会被动作拉过去。
##
## 第一次见到某个图标时**不播动画**：否则开战瞬间三个图标会一起弹，
## 看起来像出了 bug，而不是「获得了状态」。
func _set_status_icon(key: String, on: bool) -> void:
	var box: Control = dash["icons"].get(key)
	if box == null or not is_instance_valid(box):
		return
	if not _icon_state.has(key):
		_icon_state[key] = on
		box.visible = on
		box.scale = Vector2.ONE
		box.modulate.a = 1.0
		return
	if bool(_icon_state[key]) == on:
		return
	_icon_state[key] = on
	_pop_status(box, on, key)

## 状态图标弹出 / 缩回的共用动画。状态坞和敌人铭牌两处共用同一套动作，
## 玩家在一处学会了「弹出来 = 状态生效」，在另一处同样成立。
func _pop_status(node: Control, on: bool, hide_key: String = "") -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	if on:
		node.visible = true
		node.scale = Vector2(0.35, 0.35)
		node.modulate.a = 0.0
		tw.tween_property(node, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "modulate:a", 1.0, 0.18)
	else:
		tw.tween_property(node, "scale", Vector2(0.35, 0.35), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(node, "modulate:a", 0.0, 0.20)
		if hide_key == "":
			tw.chain().tween_callback(_hide_node.bind(node))
		else:
			tw.chain().tween_callback(_hide_icon.bind(hide_key))

func _hide_node(node: Control) -> void:
	if node != null and is_instance_valid(node):
		node.visible = false

func _hide_icon(key: String) -> void:
	var box: Control = dash["icons"].get(key)
	if box != null and is_instance_valid(box):
		box.visible = false

func _set_gauge(g: Dictionary, value: float, maximum: float, text: String) -> void:
	g.value.text = text
	var back: Panel = g.back
	var inset := 2.0 if engine.card_mode and back.size.y <= 8.0 else 4.0
	var w: float = maxf(1.0, back.size.x - inset * 2.0)
	var h: float = maxf(1.0, back.size.y - inset * 2.0)
	var ratio := clampf(value / maxf(1.0, maximum), 0.0, 1.0)
	g.fill.position = Vector2(inset, inset)
	g.fill.size = Vector2(w * ratio, h)
	# 高光条是填充条的子节点，填充条一变宽就得跟着重算
	var gloss: Variant = g.get("gloss")
	if gloss != null and is_instance_valid(gloss):
		var gp: Panel = gloss
		gp.position = Vector2(0.0, 0.0)
		gp.size = Vector2(maxf(0.0, w * ratio), maxf(0.0, h * 0.42))

# ---------------------------------------------------------------- 指令

func _selected_target() -> int:
	var index := int(context.get("target", 0))
	var pool: Array = engine.living("foe")
	if pool.is_empty():
		return 0
	return clampi(index, 0, pool.size() - 1)

## 演出播放期间（busy）与结算期间（result）只让指令菜单在 command 态受理输入。
## 否则播放结束时的 _finish_playback() 会把玩家刚打开的子菜单覆盖掉。
func _can_act() -> bool:
	return mode == "command"

## 点敌人立绘选目标。传入的是 engine.foes 的下标，要换算成活着的敌人列表下标。
func _select_target(slot_index: int) -> void:
	if not _can_act() and mode != "skill":
		return
	if slot_index < 0 or slot_index >= slots.size():
		return
	var foe: Variant = slots[slot_index].foe
	if foe == null or not bool(foe.alive):
		return
	var idx: int = engine.living("foe").find(foe)
	if idx < 0:
		return
	context["target"] = idx
	_refresh_enemies()
	_refresh_tactics()

func _cycle_target() -> void:
	if not _can_act() and mode != "skill":
		return
	var pool: Array = engine.living("foe")
	if pool.size() <= 1:
		return
	context["target"] = (int(context.get("target", 0)) + 1) % pool.size()
	_refresh_all()
	_append_log("目标切换为 " + str(pool[int(context["target"])].name), "334475")

func _on_attack() -> void:
	if not _can_act():
		return
	_submit_action({"kind": "attack", "target": _selected_target()})

func _on_link() -> void:
	if not _can_act():
		return
	_submit_action({"kind": "link"})

func _on_flee() -> void:
	if not _can_act():
		return
	_submit_action({"kind": "flee"})

func _on_skill_menu() -> void:
	if not _can_act():
		return
	mode = "skill"
	command_box.hide()
	skill_box.show()
	submenu_title.text = "选择技能"
	_populate_skills()

func _on_item_menu() -> void:
	if not _can_act():
		return
	mode = "item"
	command_box.hide()
	if card_panel != null: card_panel.hide()
	if card_preview != null: card_preview.hide()
	skill_box.show()
	submenu_title.text = "使用补给"
	# 每次打开都重新问一遍控制层：可用性依赖战斗内当前生命/体力
	var provider: Variant = context.get("items_provider")
	if provider is Callable:
		context["items"] = (provider as Callable).call()
	_populate_items()

## 道具列表。条目由控制层提供（见 combat_controller.battle_items）——
## 战斗界面不该自己去读背包和 character_balance.json。
func _populate_items() -> void:
	for child in skill_list.get_children():
		skill_list.remove_child(child)
		child.queue_free()
	var items: Array = context.get("items", [])
	if items.is_empty():
		detail_name.text = "没有可用补给"
		detail_text.text = "背包中暂无战斗补给。\n\n返回后可选择攻击、技能或逃跑。"
		submenu_back.grab_focus()
		_append_log("背包里没有可以现在使用的东西。按 Esc 返回。", "9a5b5b")
		return
	for entry in items:
		var row := Button.new()
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 50)
		row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		row.add_theme_font_size_override("font_size", 17)
		WhaleStyle.card_button(row, true)
		row.add_theme_font_size_override("font_size",21)
		row.icon=load(_pack_icon("heal"));row.expand_icon=true;row.add_theme_constant_override("icon_max_width",28)
		row.text = "%s  ×%d" % [str(entry.get("name", "")), int(entry.get("count", 0))]
		row.tooltip_text = Guide.item(entry)
		var usable := bool(entry.get("usable", true))
		row.disabled = not usable
		if not usable:
			row.text += "   · " + str(entry.get("reason", "现在用不上"))
		var item_id := str(entry.get("id", ""))
		var effects: Dictionary = entry.get("effects", {})
		var label := str(entry.get("name", item_id))
		row.focus_entered.connect(func(): _describe_option(label, Guide.item(entry)))
		row.mouse_entered.connect(func(): _describe_option(label, Guide.item(entry)))
		row.pressed.connect(func():_submit_action({
			"kind": "item", "id": item_id, "label": label, "effects": effects, "target": 0,
		}))
		skill_list.add_child(row)
	var first: Button = null
	for child in skill_list.get_children():
		if child is Button and not child.disabled:
			first = child
			break
	if first != null:
		first.grab_focus()

func _populate_skills() -> void:
	for child in skill_list.get_children():
		skill_list.remove_child(child)
		child.queue_free()
	var me: Dictionary = engine.allies[0]
	for entry in engine.ally_skill_menu(me):
		var row := Button.new()
		row.clip_text = true
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 50)
		row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		row.add_theme_font_size_override("font_size", 17)
		WhaleStyle.card_button(row, bool(entry.ready))
		row.add_theme_font_size_override("font_size",21)
		var symbol: String={"damage":"attack","shield":"shield","bind":"bind","heal":"heal","haste":"haste"}.get(str(entry.kind),"mana")
		row.icon=load(_pack_icon(symbol));row.expand_icon=true;row.add_theme_constant_override("icon_max_width",28)
		var label := "%s（体力 %d）" % [str(entry.name), int(entry.cost)]
		if not bool(entry.ready):
			label += "  ·  " + str(entry.reason)
		row.text = label
		row.disabled = not bool(entry.ready)
		row.tooltip_text = Guide.skill(engine, str(entry.id), _target_entry())
		var skill_id := str(entry.id)
		row.focus_entered.connect(func(): _describe_option(str(entry.name), Guide.skill(engine, skill_id, _target_entry())))
		row.mouse_entered.connect(func(): _describe_option(str(entry.name), Guide.skill(engine, skill_id, _target_entry())))
		# 记下技能类型：默认焦点要优先落在伤害类技能上（见 _populate_skills 末尾）
		row.set_meta("skill_kind", str(entry.kind))
		row.pressed.connect(func():_submit_action({"kind":"skill","id":skill_id,"target":_selected_target()}))
		skill_list.add_child(row)
	var first: Button = null
	for child in skill_list.get_children():
		if child is Button and not child.disabled:
			first = child
			break
	# 默认焦点优先落在「伤害类」技能上。
	# 原来取第一个可用项，而列表按解锁顺序排 —— 实测 Lv.5 时第一个可用的是「泡泡束缚」，
	# 于是「一路按确认键」的玩家会开始刷束缚（一个非伤害技能）。
	# 这不是数值问题，是默认路径把人往弱的那条引。
	for child in skill_list.get_children():
		if child is Button and not child.disabled and str(child.get_meta("skill_kind", "")) == "damage":
			first = child
			break
	if first != null:
		first.grab_focus()
	else:
		detail_name.text = "暂无可用技能"
		detail_text.text = "体力不足或技能正在冷却。\n\n每回合恢复 %d 体力，可返回使用普攻或补给。" % int(engine.rules.stamina_regen_per_round)
		submenu_back.grab_focus()
		# 全不可用时也要能退回指令菜单，不能把玩家卡死
		_append_log("现在没有可用的技能。按 Esc 返回。", "9a5b5b")

func _describe_option(title: String, description: String) -> void:
	detail_name.text = title
	detail_text.text = description

func _back_to_command() -> void:
	mode = "command"
	skill_box.hide()
	if engine.card_mode:
		command_box.hide()
		card_panel.show()
		_refresh_cards()
	else:
		command_box.show()
	# 从子菜单退回也必须把焦点放回来，否则按一次 Esc 之后键盘就死了
	_restore_command_focus()

func _restore_command_focus() -> void:
	if engine.card_mode:
		if card_first_ready != null and is_instance_valid(card_first_ready): card_first_ready.grab_focus()
		elif card_end_button != null: card_end_button.grab_focus()
		return
	var target: Button = null
	if _last_command_focus >= 0 and _last_command_focus < command_buttons.size():
		target = command_buttons[_last_command_focus]
	if target == null or not is_instance_valid(target) or target.disabled:
		target = skill_button
	if target != null and is_instance_valid(target) and not target.disabled:
		target.grab_focus()

func _submit_action(action: Dictionary) -> void:
	if mode == "busy" or mode == "result":
		return
	if str(action.get("kind",""))=="card" and card_row!=null:
		var index:=int(action.get("index",-1))
		if index>=0 and index<card_row.get_child_count():
			var card:=card_row.get_child(index) as Control
			_card_origin=_fx_point(card,card.size*.5)
	_back_to_command()
	# Cards play their cast sound when the accepted card event is presented.
	var kind := str(action.get("kind", "attack"))
	_pending_item = str(action.get("id", "")) if kind == "item" else ""
	var before: Dictionary = engine.checkpoint() if kind == "item" else {}
	_capture_display_state()
	_cast_target_id=""
	var targets:Array=engine.living("foe")
	var target_index:=int(action.get("target",context.get("target",0)))
	if target_index>=0 and target_index<targets.size():_cast_target_id=str(targets[target_index].id)
	var out: Dictionary = engine.submit(action)
	# 道具：引擎只把效果算进战斗内数值，背包的扣减归控制层。
	# 只有引擎真的执行了（事件里出现 item）才去扣，被拒的指令不能白扣一个道具。
	if kind == "item":
		if _has_event(out, "item") and _pending_item != "":
			var consume: Variant = context.get("consume_item")
			if consume is Callable:
				if not bool((consume as Callable).call(_pending_item)):
					engine.restore_checkpoint(before)
					_display_states.clear()
					_pending_item = ""
					mode = "command"
					_refresh_all(); _show_command()
					_append_log("补给保存失败：道具、生命与行动均未改变，请重试。", "9a5b5b")
					return
		_pending_item = ""
	if kind=="skill" and not _has_event(out,"invalid"):SfxDirector.play("skill_cast",-2.0)
	_ingest(out)

func _has_event(out: Dictionary, kind: String) -> bool:
	for e in (out.get("events", []) as Array):
		if str((e as Dictionary).get("type", "")) == kind:
			return true
	return false

func _show_command() -> void:
	if engine.card_mode:
		command_box.hide()
		card_panel.show()
		_refresh_cards()
	else:
		command_box.show()
	skill_box.hide()
	_restore_command_focus()
	# Restoring focus after an attack should not reopen a preview over the fading hit effect.
	if card_preview!=null:card_preview.hide()

# ---------------------------------------------------------------- 事件播放

func _ingest(out: Dictionary) -> void:
	_finish_pending=false
	if card_preview != null: card_preview.hide()
	queue.append_array(out.events)
	mode = "busy"
	if card_panel != null:card_panel.show();_refresh_cards()
	if card_preview != null: card_preview.hide()
	step_timer = 0.0
	context["pending_result"] = str(out.result)

func _process(delta: float) -> void:
	# close() 之后 layer 会 queue_free，但本节点自己还挂在场上，_process 还会再跑一帧。
	# 必须在这里就断掉：否则会去读已经释放的 slot.mark / dash 部件。
	if not is_active():
		return
	if phase_label != null:
		phase_label.text="行动演出中" if mode=="busy" else ("选择技能" if mode=="skill" else ("选择补给" if mode=="item" else ("交战结束" if mode=="result" else ("你的回合 · 打出手牌" if engine.card_mode else "你的回合 · 选择行动"))))
	_bob += delta
	_update_shake(delta)
	_update_reactions(delta)
	for child in fx_layer.get_children():
		if child is AttackFx:child.playback_speed=_speed()
	_update_trails(delta)
	for slot in slots:
		if not is_instance_valid(slot.mark):
			continue
		if slot.foe != null and slot.mark.visible and is_instance_valid(slot.art):
			# 目标标记贴在名字旁，轻微闪烁，不与回合提示重叠。
			slot.mark.modulate.a=.78+.22*(.5+.5*sin(_bob*4.0))
	if _ap_ready and dash.has("gauges") and not dash["gauges"].is_empty():
		var g: Dictionary = dash["gauges"][2]
		if is_instance_valid(g.fill):
			var pulse := 0.72 + 0.28 * (0.5 + 0.5 * sin(_bob * 5.0))
			g.fill.modulate = Color(1, 1, 1, pulse)
	if queue.is_empty():
		if _finish_pending:
			step_timer-=delta
			if step_timer<=0:_finish_playback()
		return
	step_timer -= delta
	if step_timer > 0.0:
		return
	step_timer = STEP_SECONDS / maxf(0.25, _speed())
	_apply_event(queue.pop_front())
	if queue.is_empty():
		_finish_pending=true
		step_timer=maxf(step_timer,.24/_speed())

func _finish_playback() -> void:
	_finish_pending=false
	_display_states.clear()
	_cast_target_id=""
	_refresh_all()
	var result := str(context.get("pending_result", ""))
	if result == "":
		mode = "command"
		_show_command()
		return
	mode = "result"
	command_box.hide()
	skill_box.hide()
	if card_panel != null: card_panel.hide()
	if card_preview != null: card_preview.hide()
	result_label.text = {
		"win": "战斗胜利",
		"lose": "力竭倒下",
		"fled": "成功脱身",
		"timeout": "久战不下，退回港口",
	}.get(result, "战斗结束")
	var report: Dictionary = {}
	var provider: Variant = context.get("result_provider")
	if provider is Callable: report = (provider as Callable).call(result)
	result_details.text = str(report.get("summary", "生命 %d / %d · 体力 %d / %d" % [int(ally.hp),int(ally.max_hp),int(ally.stamina),int(ally.max_stamina)]))
	for child in result_rewards.get_children(): result_rewards.remove_child(child); child.queue_free()
	var reward_items: Array = report.get("items", [])
	for entry in reward_items:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(minf(176.0, (568.0 - 12.0 * maxf(0, reward_items.size()-1)) / maxf(1, reward_items.size())), 100)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var reward_style := WhaleStyle.frame("sky")
		reward_style.content_margin_top=16;reward_style.content_margin_bottom=14
		reward_style.content_margin_left=12;reward_style.content_margin_right=12
		card.add_theme_stylebox_override("panel",reward_style)
		result_rewards.add_child(card)
		WhaleStyle.PaintedUi.apply(card,"info")
		var inside := VBoxContainer.new(); inside.add_theme_constant_override("separation", 6); card.add_child(inside)
		var title := Label.new(); title.text = str(entry.get("name", "")); title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 18); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; inside.add_child(title)
		var count := Label.new(); count.text = "× %d" % int(entry.get("count", 0)); count.add_theme_font_size_override("font_size", 26)
		count.add_theme_font_override("font",WhaleStyle.numeric_font())
		count.add_theme_color_override("font_color", WhaleStyle.BLUE); count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; inside.add_child(count)
	result_go.text = "返回地图" if bool(report.get("saved", true)) else "返回地图 · 奖励待领取"
	_play_result()

## 结算演出：遮罩淡入 + 面板过冲弹出 + 标题稍晚再弹一下。
##
## 面板用 BACK 过冲，和伤害数字是同一套动作语言 —— 玩家已经在战斗里学会了
## 「弹出来 = 有结果」，结算沿用同一种，不需要重新理解。
## 标题故意延迟 0.14 秒：视线先落在面板上，再落到「赢了还是输了」，
## 同时出现的话两者会互相抢注意力。
func _play_result() -> void:
	if result_shade == null or not is_instance_valid(result_shade):
		return
	if result_box == null or not is_instance_valid(result_box):
		return
	result_shade.show()
	result_shade.color.a = 0.0
	result_box.show()
	result_box.modulate.a = 0.0
	result_box.pivot_offset = result_box.size * 0.5
	result_box.scale = Vector2(0.86, 0.86)
	# Victory and defeat each have their own art; fleeing retains the compact summary.
	if result_banner != null and is_instance_valid(result_banner):
		var result_kind := str(context.get("pending_result", ""))
		var won := result_kind == "win"
		var illustrated := result_kind in ["win","lose"]
		result_banner.texture = PaintedMascot.illustration(result_kind)
		result_banner.visible = illustrated
		var has_rewards := result_rewards.get_child_count() > 0
		var box_height := (580 if has_rewards else 480) if won else (480 if illustrated else 390)
		UiFit.pin_center(result_box,640,(1086-box_height)*.5,box_height)
		result_label.position = Vector2(24, 208) if illustrated else Vector2(24, 28)
		result_label.size.x = 592.0
		result_label.add_theme_font_size_override("font_size", 30 if illustrated else 36)
		result_details.position.y = (284.0 if won and has_rewards else 270.0) if illustrated else 112.0
		result_details.size.y = (85.0 if won and has_rewards else 120.0) if illustrated else 160.0
		result_rewards.visible = won and result_rewards.get_child_count()>0
		if result_go != null and is_instance_valid(result_go):
			result_go.position.y = (506.0 if won and has_rewards else 406.0) if illustrated else 314.0
	result_box.pivot_offset = result_box.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(result_shade, "color:a", 0.55, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(result_box, "modulate:a", 1.0, 0.20)
	tw.tween_property(result_box, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if result_label != null and is_instance_valid(result_label):
		result_label.pivot_offset = result_label.size * 0.5
		result_label.scale = Vector2(0.80, 0.80)
		tw.tween_property(result_label, "scale", Vector2.ONE, 0.30).set_delay(0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 战斗事件 → 音效。
## 集中成一个函数而不是散进下面每个 match 分支：这样「哪些事件还没配音」一眼可见，
## 也不会出现改伤害时顺手漏掉声音。事件类型以 _apply_event 的 match 为准。
func _sfx_for_event(e: Dictionary) -> void:
	if _skip_fx:return
	match str(e.type):
		"card":
			SfxDirector.play("skill_cast",-2.0)
		"damage":
			if float(e.get("amount",0))<=0:SfxDirector.play("shield",-2.0);return
			if str(e.get("actor_side", "")) == "ally":
				var crit := bool(e.get("crit", false))
				# "hit" 声道节流：多段伤害/连击时不会糊成一片
				SfxDirector.play("hit_crit" if crit else "hit_light", 0.0 if crit else -2.0, 1.0, "hit")
			else:
				SfxDirector.play("hit_take", -1.0, 1.0, "hit")
		"heal":
			SfxDirector.play("heal", -2.0)
		"status":
			SfxDirector.play("shield", -3.0)
		"bound":
			SfxDirector.play("bind", -2.0)
		"item":
			SfxDirector.play("heal", -3.0)
		"flee":
			SfxDirector.play("flee", -2.0)
		"flee_fail":
			SfxDirector.play("invalid", -3.0)
		"down":
			SfxDirector.play("enemy_down", -1.0)
		"link":
			SfxDirector.play("link_cast", 0.0)
		"ap_full":
			SfxDirector.play("link_ready", -1.0)
		"invalid":
			SfxDirector.play("invalid", -2.0)
		"timeout":
			SfxDirector.play("invalid", -5.0)
		# "round" 刻意不配音：每回合都响一声会变成节拍器

func _apply_event(e: Dictionary) -> void:
	var kind := str(e.type)
	if kind!="damage":_present_event(e)
	if kind!="damage":_sfx_for_event(e)
	match kind:
		"round":
			round_label.text = "第 %d 回合" % int(e.get("round", engine.round_no))
			_append_log(str(e.text), "9fb4d8")
		"damage":
			var crit := bool(e.get("crit", false))
			_append_log("%s → %s  %d%s" % [str(e.actor), str(e.target), _display_damage_amount(e), " 暴击!" if crit else ""], "ffb3bd" if crit else "ffd9c0")
			_play_damage_fx(e)
		"card":
			_append_log(str(e.text))
			_play_card_flight(str(e.get("card_id","")))
		"heal":
			_append_log("%s 恢复 %d" % [str(e.actor), ceili(float(e.amount))], "a8e6c0")
			_heal_number(float(e.get("amount", 0.0)))
			_spawn_fx("heal",_portrait_anchor(),_portrait_anchor(),.7)
		"status":
			_append_log(str(e.text), "bcd0f5")
			var status_kind:=str(e.get("status",""))
			var at:=_portrait_anchor() if str(e.target)==str(ally.name) else _enemy_anchor(str(e.target),str(e.get("target_id","")))
			_spawn_fx("bind" if status_kind=="bind" else ("shield" if status_kind in ["shield","block"] else "support"),at,at,.8)
		"draw","energy":
			_append_log(str(e.text))
			var badge:Control=card_panel.get_node("CardEnergyBadge")
			var at:=_fx_point(badge,badge.size*.5)
			_spawn_fx("support",at,at,.7)
		"bound":
			_append_log(str(e.text), "d8c8f0")
		"item":
			_append_log(str(e.text), "a8e6c0")
			_heal_number(float(e.get("amount", 0.0)))
		"flee":
			_append_log(str(e.text), "a8e6c0")
		"flee_fail":
			_append_log(str(e.text), "ffd9c0")
		"down":
			_append_log(str(e.text), "ff9ba7")
			_shake(3.4)
			_play_defeat(e)
		"link":
			_append_log(str(e.text), "c8a24a")
			_flash_all()
			_shake(9.0)
		"ap_full":
			_append_log(str(e.text), "b8860b")
		"invalid":
			_append_log(str(e.text), "ff9ba7")
		"timeout":
			_append_log(str(e.text), "ff9ba7")
		_:
			if str(e.text) != "":
				_append_log(str(e.text))
	_refresh_all()

## Coordinates are converted through canvas transforms, including small and wide windows.
func _state_key(actor:Dictionary)->String:
	return str(actor.get("side",""))+":"+str(actor.get("id",""))

func _capture_display_state()->void:
	_display_states.clear()
	for actor in engine.allies+engine.foes:
		_display_states[_state_key(actor)]=engine.presentation_state(actor)

func _display_actor(actor:Dictionary)->Dictionary:
	if mode!="busy" or not _display_states.has(_state_key(actor)):return actor
	var view:=actor.duplicate()
	view.merge(_display_states[_state_key(actor)],true)
	return view

func _present_event(event:Dictionary)->void:
	var states:Array=[event.get("actor_state",{}),event.get("target_state",{})]
	states.append_array(event.get("round_states",[]))
	for raw in states:
		var state:Dictionary=raw
		if state.is_empty():continue
		var key:=_state_key(state)
		var previous:Dictionary=_display_states.get(key,{})
		var view:=state.duplicate()
		if str(event.type)=="ap_full":
			view=previous.duplicate();view["ap"]=state.get("ap",0)
		elif str(event.type)=="damage" and str(state.get("side",""))=="foe":
			# A lethal hit is visible first; the following down event triggers disappearance.
			view["alive"]=previous.get("alive",true)
		_display_states[key]=view

func _matches_foe(slot:Dictionary,target:String,id:String="")->bool:
	if slot.foe==null:return false
	return str(slot.foe.id)==id if id!="" else str(slot.foe.name)==target

func _enemy_windup(event:Dictionary)->void:
	if _skip_fx:return
	for slot in slots:
		if _matches_foe(slot,str(event.actor),str(event.get("actor_id",""))):
			slot["attack_left"]=.28
			var at:=_fx_point(slot.art,slot.art.size*Vector2(.5,.45))
			_spawn_fx("windup",at,at,.75)

func _play_defeat(event:Dictionary)->void:
	if str(event.get("actor_side",""))!="foe":return
	for slot in slots:
		if _matches_foe(slot,str(event.target),str(event.get("target_id",""))):
			slot["defeat_left"]=0.0 if _skip_fx else .42
			slot["defeat_alpha"]=0.0 if _skip_fx else 1.0
			var at:=_fx_point(slot.art,slot.art.size*Vector2(.5,.55))
			_spawn_fx("defeat",at,at)

func _fx_point(node:CanvasItem,local:Vector2)->Vector2:
	return fx_layer.get_global_transform().affine_inverse()*(node.get_global_transform()*local)

func _portrait_anchor()->Vector2:
	var frame:Control=dash.portrait_frame
	return _fx_point(frame,frame.size*.5)

func _enemy_anchor(target:String,id:String="")->Vector2:
	for slot in slots:
		if _matches_foe(slot,target,id) and is_instance_valid(slot.art):
			return _fx_point(slot.art,slot.art.size*Vector2(.5,.55))
	return Vector2(root.size.x*.5,360)

func _spawn_fx(style:String,from:Vector2,to:Vector2,strength:float=1.0)->Node2D:
	if _skip_fx or not is_active() or fx_layer.get_child_count()>=32:return null
	var effect:=AttackFx.new()
	effect.name="AttackEffect_"+style
	effect.configure(style,from,to,strength,_speed())
	fx_layer.add_child(effect)
	return effect

func _play_damage_fx(event:Dictionary)->void:
	if _skip_fx:_present_event(event);return
	var from_ally:=str(event.get("actor_side",""))=="ally"
	var at:=_enemy_anchor(str(event.target),str(event.get("target_id",""))) if from_ally else _portrait_anchor()
	var from:=Vector2(root.size.x*.5,540) if from_ally else _enemy_anchor(str(event.actor),str(event.get("actor_id","")))
	if not from_ally:_enemy_windup(event)
	var profile:=AttackFx.profile(str(event.get("skill","")),str(event.actor))
	if float(event.get("amount",0))<=0:profile="shield"
	var crit:=bool(event.get("crit",false))
	_spawn_fx(profile,from,at,1.3 if crit else (1.0 if from_ally else .7))
	var epoch:=_vfx_epoch
	var tw:=create_tween().set_speed_scale(_speed())
	tw.tween_interval(.12)
	tw.tween_callback(func():
		if is_active() and epoch==_vfx_epoch and not _skip_fx:_hit_feedback(event)
	)

## Keep integer feedback consistent with the visible HP loss, including overkill.
func _display_damage_amount(event:Dictionary)->int:
	var state:Dictionary=event.get("target_state",{})
	var previous:Dictionary=_display_states.get(_state_key(state),{})
	if state.has("hp") and previous.has("hp"):
		return maxi(0,ceili(float(previous.hp))-ceili(float(state.hp)))
	return maxi(0,roundi(float(event.get("amount",0))))

func _hit_feedback(event:Dictionary)->void:
	var shown_damage:=_display_damage_amount(event)
	var target_state:Dictionary=event.get("target_state",{})
	var previous:Dictionary=_display_states.get(_state_key(target_state),{})
	var blocked:float=maxf(0,float(previous.get("block",0))-float(target_state.get("block",0))) if not target_state.is_empty() else 0.0
	_present_event(event)
	_sfx_for_event(event)
	var crit:=bool(event.get("crit",false))
	var from_ally:=str(event.get("actor_side",""))=="ally"
	var amount:=float(event.get("amount",0))
	_damage_number(str(event.target),amount,crit,from_ally,str(event.get("target_id","")),shown_damage)
	if blocked>0 and amount>0:
		var at:=_enemy_anchor(str(event.target),str(event.get("target_id",""))) if from_ally else _ally_number_anchor()+Vector2(165,0)
		_pop_number("格挡 %d" % ceili(blocked),at+Vector2(0,46 if from_ally else 10),Color("91d3e1"),23,24)
	_refresh_all()
	if amount<=0:return
	if crit:
		var at:=_enemy_anchor(str(event.target),str(event.get("target_id",""))) if from_ally else _portrait_anchor()
		_spawn_fx("critical",at,at,1.1 if from_ally else .7)
		_pop_number("暴击",at+Vector2(0,-65),Color("efbb65"),24,26)
	if from_ally:
		_flash_target(str(event.target),1.9 if crit else 1.35,str(event.get("target_id","")))
		_shake(4.8 if crit else 1.8)
		for slot in slots:
			if _matches_foe(slot,str(event.target),str(event.get("target_id",""))):
				slot["reaction_left"]=.26
				slot["reaction_power"]=1.3 if crit else 1.0
				slot["reaction_direction"]=1.0 if slot.art.position.x>root.size.x*.5 else -1.0
	else:
		_flash_dock();_shake(3.8)

func _update_reactions(delta:float)->void:
	for slot in slots:
		var left:float=float(slot.get("reaction_left",0))
		var attack_left:float=float(slot.get("attack_left",0))
		var defeat_left:float=float(slot.get("defeat_left",0))
		if left<=0 and attack_left<=0 and defeat_left<=0:continue
		left=maxf(0,left-delta*_speed());slot["reaction_left"]=left
		attack_left=maxf(0,attack_left-delta*_speed());slot["attack_left"]=attack_left
		var t:float=1.0-left/.26
		var beat:float=sin(t*PI)*pow(1-t,1.4)*float(slot.get("reaction_power",1))
		var offset:=Vector2(float(slot.get("reaction_direction",1))*beat*12,-beat*4)
		var attack_t:float=1-attack_left/.28
		var lunge:float=sin(attack_t*PI)*pow(1-attack_t,.5)
		var attack_offset:=Vector2(-12*lunge,-4*lunge)
		slot["reaction_offset"]=offset
		slot["attack_offset"]=attack_offset
		if is_instance_valid(slot.art):
			slot.art.position=slot.get("art_home",slot.art.position)+offset+attack_offset
			slot.art.scale=Vector2(1+beat*.045+lunge*.025,1-beat*.055-lunge*.02)
			if defeat_left>0:
				defeat_left=maxf(0,defeat_left-delta*_speed());slot["defeat_left"]=defeat_left
				var defeat_t:float=1-defeat_left/.42
				slot["defeat_alpha"]=pow(1-defeat_t,1.5)
				slot.art.modulate.a=slot.defeat_alpha
				slot.art.scale=Vector2(1-.12*defeat_t,1-.22*defeat_t)

func _play_card_flight(id:String)->void:
	if _skip_fx or not engine.card_catalog.has(id):return
	var face=load("res://battle/card_face.gd").new()
	face.configure(engine.card_catalog[id],Vector2(172,252))
	face.name="PlayedCard"
	face.mouse_filter=Control.MOUSE_FILTER_IGNORE;face.focus_mode=Control.FOCUS_NONE
	face.pivot_offset=face.size*.5
	face.position=(_card_origin if _card_origin!=Vector2.ZERO else Vector2(root.size.x*.5,770))-face.size*.5
	fx_layer.add_child(face)
	var destination:Vector2=Vector2(root.size.x*.5,505)-face.size*.5
	var tw:=create_tween().set_speed_scale(_speed()).set_parallel(true)
	tw.tween_property(face,"position",destination,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(face,"scale",Vector2(.48,.48),.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(face,"rotation",-.07,.22)
	tw.tween_property(face,"modulate:a",0.0,.12).set_delay(.23)
	tw.chain().tween_callback(face.queue_free)

## 残影收拢。独立成一个循环而不是塞进下面那个 mark 浮动循环：
## 那个循环开头有 `if not is_instance_valid(slot.mark): continue`，
## 把残影塞进去会被这一句连带跳过。
func _update_trails(delta: float) -> void:
	for slot in slots:
		if slot.foe == null or not is_instance_valid(slot.bar_trail):
			continue
		var trail: Panel = slot.bar_trail
		var fill_w: float = (slot.bar_fill as Panel).size.x
		var trail_w: float = float(slot.get("trail_w", 0.0))
		if trail_w <= fill_w + 0.5:
			continue
		trail_w = maxf(fill_w, trail_w - TRAIL_SPEED * delta)
		slot["trail_w"] = trail_w
		trail.size.x = trail_w

## 命中闪白。
## 用 self_modulate，不用 modulate —— 这是旧实现失效的原因：
## _refresh_enemies() 每次刷新都会重写 art.modulate（存活 / 倒下 / 被选中三种状态），
## 而 _apply_event 里紧接着就调 _refresh_all()，所以旧写法设的闪色在同一帧内就被抹掉，
## 屏幕上一次都没有真正亮过。
## self_modulate 和 modulate 是相乘关系，各管一个通道，互不覆盖。
func _flash_target(name: String, power: float = 1.6, id:String="") -> void:
	if _skip_fx:return
	for slot in slots:
		if _matches_foe(slot,name,id) and is_instance_valid(slot.art):
			var art: TextureRect = slot.art
			var previous:Tween=slot.get("flash_tween")
			if previous and previous.is_valid():previous.kill()
			art.self_modulate = Color(power, power, power)
			var tw := create_tween()
			slot["flash_tween"]=tw
			tw.set_speed_scale(_speed())
			tw.tween_property(art, "self_modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _flash_all() -> void:
	for slot in slots:
		if slot.foe != null and is_instance_valid(slot.art):
			_flash_target(str(slot.foe.name), 2.3)

## 我方挨打：把状态坞整体泛一下红。玩家挨打时视线本来就在血条上，
## 让血条自己发亮比在场景另一头做个特效有效得多。
func _flash_dock() -> void:
	if _skip_fx:return
	var dock: Panel = dash.get("dock")
	if dock == null or not is_instance_valid(dock):
		return
	dock.self_modulate = Color(1.55, 1.12, 1.12)
	var tw := create_tween()
	tw.tween_property(dock, "self_modulate", Color.WHITE, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## 震屏。只晃「世界层」（背景 + 敌人层），不晃 HUD ——
## 界面跟着晃会让人看不清血条，而受击反馈的重点恰恰是要看清血条。
func _shake(power: float) -> void:
	if _skip_fx:return
	_shake_power = maxf(_shake_power, power)
	_shake_left = maxf(_shake_left, SHAKE_TIME)

func _update_shake(delta: float) -> void:
	if backdrop == null or enemy_layer == null:
		return
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	# 二次衰减：起手猛、收尾干净。线性衰减会留下「晃半天才停」的尾巴。
	var k := _shake_left / SHAKE_TIME
	var amp := _shake_power * k * k
	_shake_phase += delta * 62.0
	var off := Vector2(sin(_shake_phase) * amp, cos(_shake_phase * 1.37) * amp * 0.7)
	backdrop.position = off
	enemy_layer.position = off
	if _shake_left <= 0.0:
		backdrop.position = Vector2.ZERO
		enemy_layer.position = Vector2.ZERO
		_shake_power = 0.0

## 飘一个伤害数字。
## at 是目标头顶的位置；数字先「弹」出来再往上飘，最后淡出。
## 暴击更大、金色、尾巴带感叹号，和普通命中的白色数字一眼能分开。
func _damage_number(target_name: String, amount: float, crit: bool, from_ally: bool, id:String="", shown_damage:int=-1) -> void:
	var count:=shown_damage if shown_damage>=0 else roundi(amount)
	var text := "格挡" if amount<=0 else (("%d!" % count) if crit else ("%d" % count))
	if from_ally:
		for slot in slots:
			if _matches_foe(slot,target_name,id) and is_instance_valid(slot.art):
				var art: TextureRect = slot.art
				_pop_number(text, _fx_point(art,art.size*Vector2(.5,.16)),
					Color("91d3e1") if amount<=0 else (Color("ffd76a") if crit else Color("fff2f4")),
					42 if crit else 33, 60.0 if crit else 46.0)
				return
	else:
		_pop_number(text, _ally_number_anchor(), Color("91d3e1") if amount<=0 else Color("ff9ba7"), 28 if amount<=0 else 34, 46.0)

## 我方数字的落点：血条上方偏左。
## 不放头像上（会和立绘挤在一起），也不放坞顶（那里是战报板的范围）——
## 血条本来就是「挨打时要看的地方」，数字落在这里，视线不用移动。
func _ally_number_anchor() -> Vector2:
	var gauges: Array = dash.get("gauges", [])
	if gauges.is_empty():
		return Vector2(88.0, DOCK_TOP + 44.0)
	var g0: Dictionary = gauges[0]
	var back: Panel = g0.back
	if back == null or not is_instance_valid(back):
		return Vector2(88.0, DOCK_TOP + 44.0)
	return _fx_point(back,Vector2(minf(128,back.size.x*.45),12))

## 治疗 / 用道具飘绿字
func _heal_number(amount: float) -> void:
	if amount <= 0.0:
		return
	_pop_number("+%d" % int(round(amount)), _ally_number_anchor(), Color("a8e6c0"), 32, 46.0)

func _pop_number(text: String, at: Vector2, color: Color, size: int = 34, rise: float = 46.0) -> void:
	if _skip_fx:return
	if fx_layer == null or not is_instance_valid(fx_layer):
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("243a54"))
	label.add_theme_constant_override("outline_size", 7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(180.0, 46.0)
	label.position = at - Vector2(90.0, 23.0)
	label.pivot_offset = Vector2(90.0, 23.0)
	label.scale = Vector2(0.55, 0.55)
	fx_layer.add_child(label)
	# 弹一下再飘：纯线性位移看起来像「标签在移动」，加个过冲才像「被打出来」。
	var tw := create_tween()
	tw.set_speed_scale(_speed())
	tw.tween_property(label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "position:y", label.position.y - rise, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.22)
	tw.tween_callback(label.queue_free)

func _append_log(text: String, color: String = "") -> void:
	if text == "":
		return
	# 左侧色条承担「这一行是什么性质」，正文统一改成深墨色。
	#
	# 改之前正文本身就是彩色（#ffd9c0 桃色、#ffb3bd 粉色、#a8e6c0 浅绿…），
	# 而这些颜色压在同样浅的纸色面板（#fffdf7）上对比度极低，几乎读不出来。
	# 那不是配色品味问题，是对比度不够 —— 颜色不该同时干「装饰」和「传达语义」两件事。
	var bar := "#7c8ba8" if color == "" else "#" + color
	var ink := "#293f52"
	var line := "[color=%s]▌[/color] [color=%s]%s[/color]" % [bar, ink, text]
	log_lines.append(line)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.pop_front()
	if log_text != null and is_instance_valid(log_text):
		log_text.text = str(log_lines.back()) if engine != null and engine.card_mode else "\n".join(log_lines)
		var tags:=RegEx.new();tags.compile("\\[/?[^\\]]+\\]")
		log_text.tooltip_text = tags.sub("\n".join(log_lines),"",true)

# ---------------------------------------------------------------- 收尾与输入

func _on_continue() -> void:
	if continuing:
		return
	continuing = true
	var result := str(context.get("pending_result", ""))
	battle_finished.emit(result)
	close()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return
	# 演出播放中按确认键 = 跳过剩下的事件（状态照常全部结算）
	if mode == "busy" and event.is_action_pressed("ui_accept"):
		skip_playback()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if mode == "skill" or mode == "item":
			_back_to_command()
			get_viewport().set_input_as_handled()
		return
	if mode != "skill" and mode != "item":
		return
	# 技能列表滚动交给容器，其它按键放行给 Godot 的焦点导航
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_back_to_command()
		get_viewport().set_input_as_handled()
