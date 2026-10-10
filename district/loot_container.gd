extends Node3D
## 把素材包的 container_runtime 接到工程的战利品系统上。
##
## ── 为什么需要这一层 ──
## 两边接口本来就不同：
##   · container_runtime（素材包）：set_open_state() / toggle_open() / opened_changed 信号
##   · loot_controller（本工程）：set_open() / container_id / display_name / note
##     —— 这个契约见 meme_chest.gd，箱子必须有这几样才能被 _physics_process 认出来
## 所以做一层适配，而**不是去改素材包的文件**：包保持原样才好跟着它升级。
##
## ── 为什么 container_id 要唯一 ──
## loot_controller 按 container_id 给「这个箱子还剩什么」存档（stocks 字典）。
## 如果直接用类型名，同一种柜子在不同房间会**共用同一份库存** ——
## 在补给仓拿空一台立式装备柜，冷藏间那台也跟着空了。
## 所以外面这层的 id 带上房间与序号，真正的类型名留在 inner 上给 container_runtime 用。
@export var container_id := ""
@export var display_name := ""
@export var note := ""
var inner: Node3D
var opened := false

## 建一个可搜刮的容器。type_id 用 container_specs.json 里的 30 种 id 之一。
static func spawn(parent: Node3D, type_id: String, unique_id: String, label: String,
		pos: Vector3, angle: float, room_note: String = ""):
	var node = load("res://district/loot_container.gd").new()
	node.container_id = unique_id
	node.display_name = label
	node.note = room_note
	node.position = pos
	node.rotation_degrees.y = angle
	node.set_meta("container_type", type_id)
	parent.add_child(node)
	return node

func _ready() -> void:
	var packed: PackedScene = load("res://container_runtime.tscn")
	if packed == null:
		push_warning("LootContainer: 缺少 container_runtime.tscn")
		return
	inner = packed.instantiate()
	inner.set("container_id", str(get_meta("container_type", "field_supply_crate")))
	inner.set("opening_seconds", 1.8)
	add_child(inner)

## loot_controller 调的是这个（meme_chest 的契约）
func set_open(value: bool) -> void:
	opened = value
	if inner != null and is_instance_valid(inner):
		inner.set_open_state(value)

## 玩家按 E 时 ContainerRooms 调的是这个
func toggle_open() -> void:
	set_open(not opened)

## 这个箱子现在还剩几件 —— loot_controller 的提示文字要用
func stock_total(stocks: Dictionary) -> int:
	var total := 0
	for id in stocks.get(container_id, {}):
		total += int(stocks[container_id][id])
	return total
