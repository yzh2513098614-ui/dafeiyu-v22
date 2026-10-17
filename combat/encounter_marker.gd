extends Node3D
## 遭遇点的世界表现：立绘 + 地面阴影 + 地面光圈 + 名字标签
##
## 这里**没有任何战斗逻辑、也没有 AI** —— 旧的即时战里怪物会追击、蓄力、判断命中，
## 那些全部删掉了。现在它只是一个「站着的遭遇点」，由 combat_controller 负责
## 判断玩家是否靠近、是否弹出 [战斗] 提示。
##
## 立绘分两张（见 assets/combat_balance.json 的 texture / map_texture）：
##   · texture      战斗界面里的全身立绘
##   · map_texture  地图上用的 Q 版立绘；缺省时退回 texture，老怪物不用改数据
##
## 朝向：用 BILLBOARD_FIXED_Y 而不是 BILLBOARD_ENABLED。
## 全部 BILLBOARD_ENABLED 会让立绘跟着 28° 俯视相机一起前后倾倒，
## 站在 3D 地面上像躺着；FIXED_Y 只绕 Y 轴转、永远保持直立，
## 和 room_3d.gd 里玩家 avatar 的朝向口径一致 —— 这就是「匹配地图坐标轴」。

const GroundShadow = preload("res://combat/ground_shadow.gd")
const Badge = preload("res://ui/design/pages/world_monster_badge.tscn")

## 立绘贴地的高度微调：让脚底刚好压在地板上，而不是浮起或陷进去。
const FOOT_LIFT := 0.04
## 光圈与阴影的贴地高度。地板顶面在 y≈0，装饰网格线在 y=.015，
## 所以阴影压在网格线之上、光圈再压在阴影之上。
## 阴影的贴地高度。
## 注意试炼场的地面不是一块平面：底座顶 -0.03、装饰网格线到 0.018、
## 内场台面顶在 0.0235（trial_ground.gd 的 box(19,.013,14) 放在 y=.017）。
## 影子必须高过 0.0235，否则会整个埋在内场台面底下、一点都看不见
## —— 相机是 33° 俯视的正交，不存在「斜着露出来」的可能。
## 0.032 比台面高 8mm：够躲开 Z-fighting，又几乎看不出悬空。
const SHADOW_Y := 0.032

var controller
var id := ""
var kind := ""
var record: Dictionary = {}
var data: Dictionary = {}
var sprite: Sprite3D
var caption: Label
var caption_status: Label
var bubble: Panel
var caption_height := 1.5
var ring: MeshInstance3D
var shadow: MeshInstance3D
var base_y := 0.0
var age := 0.0
var cooldown := 0.0
var defeated := false
var collision_body: StaticBody3D

func configure(owner_controller, spawn_record: Dictionary) -> void:
	controller = owner_controller
	record = spawn_record
	id = str(spawn_record.get("id", ""))
	kind = str(spawn_record.get("type", ""))
	data = controller.balance.monsters.get(kind, {})
	var at: Array = spawn_record.get("position", [0, 0])
	position = Vector3(float(at[0]), 0.0, float(at[1]))

	var world_height := float(data.get("height", 1.05))
	var art_path := str(data.get("map_texture", ""))
	if art_path == "":
		art_path = str(data.get("texture", ""))
	var source := Image.load_from_file(art_path)
	if source != null:
		var texture := ImageTexture.create_from_image(source)
		sprite = Sprite3D.new()
		sprite.texture = texture
		# 只绕 Y 轴面向相机：立绘永远直立，和玩家角色同一口径
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		# 立绘是高清手绘（非像素画），用线性过滤；NEAREST 会把长发放大成锯齿块
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		# shaded=false：立绘是手绘稿，不该再被 3D 灯光打一次。
		# 开着 shaded 时场景的暗环境光（energy .40 + 环境 .28）会把浅色立绘压成灰紫色，
		# 和旁边明亮的角色立绘完全不是一个观感。
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = .28
		var used := source.get_used_rect()
		# pixel_size 用「alpha 实际可见高度」换算，而不是整张画布高度 ——
		# 否则留白多的立绘会显得比数据里写的高度矮一截。
		sprite.pixel_size = world_height / maxi(1, used.size.y)
		sprite.position.y = (used.end.y - source.get_height() * .5) * sprite.pixel_size + FOOT_LIFT
		sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sprite)
		base_y = sprite.position.y
		collision_body=StaticBody3D.new();add_child(collision_body)
		var hit:=CollisionShape3D.new();var shape:=CylinderShape3D.new()
		shape.radius=maxf(.20,used.size.x*sprite.pixel_size*.5+.025)
		shape.height=world_height;hit.shape=shape;hit.position.y=world_height*.5+FOOT_LIFT
		collision_body.add_child(hit)

	# 影子跟着「立绘可见高度」走，所以换 Q 版 / 换全身图都不用再调数字
	shadow = GroundShadow.attach(self, world_height, SHADOW_Y)

	# 不再画地面光圈。原来那个大圆是旧即时战的「攻击范围」指示器（半径 = 射程 x 1.5），
	# 回合制里没有站位和射程，它已经没有任何玩法含义；而且它是个实心圆盘、盖在影子上面，
	# 会把接触阴影冲淡成一个浅蓝色的椭圆 —— 立绘看起来像浮在光斑上而不是踩在地上。
	# 「这里可以打」由名字牌上的「可战斗」和走近后的提示条表达，不需要再占一层地面。
	ring = null

	bubble = Badge.instantiate()
	controller.game.district_canvas.add_child(bubble, false, Node.INTERNAL_MODE_FRONT)
	caption = bubble.get_node("MonsterName")
	caption_status = bubble.get_node("Availability")
	caption_height = world_height + .42
	_refresh_caption()

func _refresh_caption() -> void:
	if caption == null:
		return
	caption.text = str(data.get("name", kind))
	caption_status.text = "可战斗" if cooldown <= 0.0 else "稍后再战 · %d秒" % ceili(cooldown)
	bubble.modulate.a = 1.0 if cooldown <= 0.0 else .65

func _process(delta: float) -> void:
	age += delta
	if cooldown > 0.0:
		var before := cooldown
		cooldown = maxf(0.0, cooldown - delta)
		if ceili(before) != ceili(cooldown):
			_refresh_caption()
	if is_instance_valid(bubble):
		var camera: Camera3D = controller.game.camera
		var point := global_position + Vector3(0, caption_height, 0)
		bubble.visible = not defeated and is_visible_in_tree() and controller.game.character_controller.free_world() and not camera.is_position_behind(point)
		if bubble.visible:
			bubble.position = camera.unproject_position(point) - Vector2(bubble.size.x * .5, bubble.size.y + 22)
	# 轻轻上下浮动，提示这是一个可以互动的点
	if sprite != null and is_instance_valid(sprite):
		sprite.position.y = base_y + sin(age * 1.5) * 0.035
	if ring != null and is_instance_valid(ring):
		ring.scale = Vector3.ONE * (1.0 + sin(age * 1.9) * 0.035)

func is_available() -> bool:
	return not defeated and cooldown <= 0.0

func retire() -> void:
	defeated = true
	if is_instance_valid(bubble):bubble.hide()
	if is_instance_valid(collision_body):collision_body.collision_layer=0
	if ring != null and is_instance_valid(ring):
		ring.hide()
	if shadow != null and is_instance_valid(shadow):
		shadow.hide()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(.1, .1, .1), .35)
	tween.tween_callback(queue_free)

func _exit_tree() -> void:
	if is_instance_valid(bubble):bubble.queue_free()
