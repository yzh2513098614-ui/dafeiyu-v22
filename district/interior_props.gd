extends RefCounted
## 144 件现代室内 3D 物品（interior_pack）的取用入口。
##
## ── 为什么用它，而不是素材包的 models/props/ ──
##   · props/ 是 58 件**室外**道具（棕榈、花箱、礁石、长椅…），室内是空的
##   · 这 144 件是**真实尺寸**的室内模型（保险柜 0.62×0.60×0.47 米），
##     和房间的米制尺度对得上，**不用缩放**
##   · 包装场景**自带 CollisionShape3D**（props/ 要我自己补碰撞）
##   · 44 件带活动部件（DoorHinge / Drawer0 / LidHinge…），
##     interior_pack/scripts/item_3d.gd 提供了 has_action() / interact() / set_open()，
##     开合是可逆 Tween，门类还能在打开后解开碰撞
##
## ── 为什么不自己抄一份清单 ──
## 包的 catalog.json 有 144 条完整数据（id / name / category / size / moving / scene），
## 中文名和尺寸都在里面。再抄一份表，包一升级就会和它对不上（这一路已经踩过
## 「硬编码地点白名单」的坑）。所以这里只在启动时读一次，按 id 建索引。

const CATALOG := "res://interior_pack/catalog.json"
const ITEM_DIR := "res://interior_pack/scenes/items/"

static var _by_id: Dictionary = {}
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var arr: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	if arr is Array:
		for entry in arr:
			_by_id[str(entry.get("id", ""))] = entry

## 某件物品的清单条目（没有就返回空字典）
static func info(id: String) -> Dictionary:
	_ensure()
	return _by_id.get(id, {})

## 中文名，用于提示文字
static func label(id: String) -> String:
	return str(info(id).get("name", id))

## 尺寸 [宽, 高, 深]（米）。清单里就是这三个数。
static func size_of(id: String) -> Vector3:
	var s: Variant = info(id).get("size", [1.0, 1.0, 1.0])
	if s is Array and s.size() == 3:
		return Vector3(float(s[0]), float(s[1]), float(s[2]))
	return Vector3.ONE

## 这件物品有没有可开合的活动部件
static func is_interactive(id: String) -> bool:
	var m: Variant = info(id).get("moving", [])
	return m is Array and not m.is_empty()

static func all_ids() -> Array:
	_ensure()
	return _by_id.keys()

## 摆一件室内物品。pos 是**地面坐标**（模型的 origin 就在地面上）。
## 挂到 g.world（和 _pack_in 的道具同一个父节点），因为那才是「这一屋里的东西」。
static func place(g, id: String, pos: Vector3, angle: float = 0.0):
	var packed: PackedScene = load(ITEM_DIR + id + ".tscn")
	if packed == null:
		push_warning("InteriorProps: 缺少模型 " + id)
		return null
	var node = packed.instantiate()
	node.position = pos
	node.rotation_degrees.y = angle
	g.world.add_child(node)
	return node

## 摆一排：从 start 沿方向放，每件之间留 gap，用来沿墙铺设备。
## 返回实际摆下的数量。
static func place_row(g, ids: Array, start: Vector3, step: Vector3, angle: float = 0.0) -> int:
	var placed := 0
	for i in ids.size():
		if place(g, str(ids[i]), start + step * float(i), angle) != null:
			placed += 1
	return placed
