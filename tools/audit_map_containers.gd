extends SceneTree
## 大地图容器的摆放审计。
##
## 检查四件事，全部基于**规格表尺寸**（container_runtime 的碰撞体就是拿 spec.size
## 建的，所以它才是权威占地，模型实测包围盒偏大是因为含开门后的翻板体积）：
##   ① 容器之间有没有互相穿插
##   ② 容器有没有插进建筑（game.shell 的碰撞体）
##   ③ 容器离门洞传送点够不够远 —— nearest_portal 半径 1.25 米，
##      压到门口就会「想进楼却开了箱子」
##   ④ 仓储带两列之间还剩多宽的通道 —— 容器有碰撞体，堵死就出不去
##
## 运行：godot --headless --path . --script res://tools/audit_map_containers.gd
const PORTAL_RADIUS := 1.25
const MIN_PORTAL_GAP := 1.30

var game
var checks := 0
var failures := 0

func _initialize() -> void:
	game = load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS ", message)
	else:
		failures += 1
		push_error(message)
		print("FAIL ", message)

func run() -> void:
	await process_frame
	await process_frame
	# 强制切到大地图。**不能靠 HarborPrefs.starting_place**：那个值是持久化的，
	# 之前跑过的界面测试会把它写成 depot / coldstore，于是这个脚本量的其实是
	# 某个室内房间（第一版就测成了冷藏间，10 个容器、"通道 5.00 米"，
	# 看起来全绿，其实大地图一个都没量到）。而且给 autoload 的变量赋值也压不住 ——
	# autoload 的 _ready 在 _initialize 之后才跑，会把值读回配置文件里的旧值。
	if str(game.location_id) != "city":
		game._travel("city")
		await process_frame
		await process_frame
	if game.has_method("set_physics_process"):
		game.set_physics_process(false)
	game.set_process(false)
	if game.dialogue_controller:
		game.dialogue_controller.close()

	print("=== 大地图容器审计（当前地点：%s）===" % str(game.location_id))
	var specs := _specs()
	var boxes := _collect_containers(specs)

	check(str(game.location_id) == "city", "确实站在大地图上")
	check(boxes.size() > 0, "大地图上确实摆了容器（%d 个）" % boxes.size())

	# ① 容器互相穿插
	var self_hits: Array = []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var overlap := _volume(boxes[i].box, boxes[j].box)
			if overlap > 0.0001:
				self_hits.append("%s ↔ %s 重叠 %.3f m³" % [boxes[i].name, boxes[j].name, overlap])
	check(self_hits.is_empty(), "容器之间没有互相穿插")
	for hit in self_hits:
		print("   !! ", hit)

	# ② 容器插进建筑
	var building_hits: Array = []
	for shape in _shapes_under(game.shell):
		var world_box := _shape_box(shape)
		for entry in boxes:
			var overlap := _volume(world_box, entry.box)
			if overlap > 0.0001:
				building_hits.append("%s 插进建筑 %.3f m³" % [entry.name, overlap])
	check(building_hits.is_empty(), "没有容器插进建筑")
	for hit in building_hits:
		print("   !! ", hit)

	# ③ 离门洞传送点距离
	var too_close: Array = []
	var closest := 999.0
	for entry in boxes:
		for portal in game.portals:
			var p: Vector3 = portal.pos
			var d: float = Vector2(entry.box.position.x - p.x, entry.box.position.z - p.z).length()
			closest = minf(closest, d)
			if d < MIN_PORTAL_GAP:
				too_close.append("%s 离门洞只有 %.2f m（%s）" % [entry.name, d, str(portal.label)])
	check(too_close.is_empty(), "每个容器离门洞都 ≥ %.2f m（实测最近 %.2f m）" % [MIN_PORTAL_GAP, closest])
	for hit in too_close:
		print("   !! ", hit)

	# ④ 仓储带通道宽度
	var narrow := _corridor_report(boxes)

	# ⑤ 战利品登记
	var chests: int = game.loot.chests.size() if game.loot else 0
	var stocked := 0
	if game.loot:
		for node in game.loot.chests:
			if game.loot.stocks.has(str(node.container_id)):
				stocked += 1
	check(chests == boxes.size(), "全部容器都登记进了战利品系统（%d / %d）" % [chests, boxes.size()])
	check(stocked == chests and chests > 0, "每个容器都有库存表（%d / %d）" % [stocked, chests])

	var items := 0
	if game.loot:
		for node in game.loot.chests:
			var key := str(node.container_id)
			for id in game.loot.stocks.get(key, {}):
				items += int(game.loot.stocks[key][id])
	print("   大地图这 %d 个容器共提供 %d 件物品" % [chests, items])
	print("   仓储带最窄通道 %.2f m" % narrow)

	print("MAP CONTAINER AUDIT ", checks, " 检查 · ", checks - failures, " 通过 · ", failures, " 失败")
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- 工具

func _specs() -> Dictionary:
	var out: Dictionary = {}
	var arr = JSON.parse_string(FileAccess.get_file_as_string("res://container_specs.json"))
	for spec in arr:
		out[str(spec.id)] = spec
	return out

func _collect_containers(specs: Dictionary) -> Array:
	var out: Array = []
	for node in game.world.get_children():
		if not node.has_meta("container_type"):
			continue
		var type_id := str(node.get_meta("container_type"))
		if not specs.has(type_id):
			continue
		var size := Vector3(specs[type_id].size[0], specs[type_id].size[1], specs[type_id].size[2])
		var angle: float = deg_to_rad(float(node.rotation_degrees.y))
		var hx: float = absf(cos(angle)) * size.x * 0.5 + absf(sin(angle)) * size.z * 0.5
		var hz: float = absf(sin(angle)) * size.x * 0.5 + absf(cos(angle)) * size.z * 0.5
		var centre: Vector3 = node.position
		out.append({
			"name": "%s @ (%.1f, %.1f)" % [str(node.display_name), centre.x, centre.z],
			"box": AABB(Vector3(centre.x - hx, centre.y, centre.z - hz), Vector3(hx * 2.0, size.y, hz * 2.0)),
		})
	return out

func _shapes_under(node: Node) -> Array:
	var out: Array = []
	if node is CollisionShape3D:
		out.append(node)
	for child in node.get_children():
		out.append_array(_shapes_under(child))
	return out

func _shape_box(shape: CollisionShape3D) -> AABB:
	var box_shape := shape.shape
	if not (box_shape is BoxShape3D):
		return AABB()
	var size: Vector3 = box_shape.size
	var centre: Vector3 = shape.global_position
	return AABB(centre - size * 0.5, size)

func _volume(a: AABB, b: AABB) -> float:
	var overlap := a.intersection(b)
	if overlap.size.x <= 0.0 or overlap.size.y <= 0.0 or overlap.size.z <= 0.0:
		return 0.0
	return overlap.size.x * overlap.size.y * overlap.size.z

## 沿仓储带每 1 米量一次：在 x 52.5~57.5 这条街里，扣掉容器占掉的区间之后
## 还剩下多宽的空档。最窄处就是玩家能不能顺利走过去。
func _corridor_report(boxes: Array) -> float:
	var narrowest := 999.0
	var z := -43.0
	while z <= 43.0:
		var spans: Array = []
		for entry in boxes:
			var box: AABB = entry.box
			if z >= box.position.z and z <= box.position.z + box.size.z:
				spans.append([box.position.x, box.position.x + box.size.x])
		spans.sort_custom(func(a, b): return a[0] < b[0])
		var cursor := 52.5
		var widest := 0.0
		for span in spans:
			widest = maxf(widest, maxf(0.0, float(span[0]) - cursor))
			cursor = maxf(cursor, float(span[1]))
		widest = maxf(widest, 57.5 - cursor)
		narrowest = minf(narrowest, widest)
		z += 1.0
	return narrowest
