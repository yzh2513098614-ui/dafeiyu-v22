extends RefCounted
## Room-sized partitions with actual openings; all moving leaves use the game's
## existing guarded hinges, E interaction and visited/save state.
const Door = preload("res://district/interactive_door.gd")
const Geo = preload("res://district/story_geometry.gd")
const WALL_HEIGHT := 3.9
const LOW_HEIGHT := 1.15
const OPENING := 3.6
const DOOR_WIDTH := 3.4
const DOOR_HEIGHT := 2.9
var builder
var doors: Array[Node3D] = []
var wall_tops: Array[Node3D] = []
var partitions: Array[Node3D] = []

func build(home_builder) -> void:
	builder = home_builder
	var west_gates := [[5.0, -26.0], [0.0, -26.0], [-17.0, -35.0]]
	var east_gates := [[-8.5, -26.0], [-8.0, -26.0], [-10.0, -28.0]]
	var west_names := ["海风会客厅", "海景阅读会客室", "海风客房"]
	var east_names := ["花艺与烘焙工坊", "双人创作书房", "海景休憩室"]
	var rear_names := ["家庭长桌厅", "蓝鲸藏书长廊", "晨光梳妆长廊"]
	for i in 2:
		var floor_root: Node3D = builder.floors[i]
		var height: float = i * builder.HEIGHT
		var rect: Rect2 = builder.FLOOR_RECTS[i]
		var prefix := "floor_" + str(i + 1) + "_"
		_partition(floor_root, Vector2(-14, rect.position.y), Vector2(-14, rect.end.y), height, [
			[Vector2(-14, west_gates[i][0]), prefix + "west_front", west_names[i], i != 2],
			[Vector2(-14, west_gates[i][1]), prefix + "west_rear", west_names[i], i != 2]])
		_partition(floor_root, Vector2(14, rect.position.y), Vector2(14, rect.end.y), height, [
			[Vector2(14, east_gates[i][0]), prefix + "east_front", east_names[i], true],
			[Vector2(14, east_gates[i][1]), prefix + "east_rear", east_names[i], true]] + ([
			[Vector2(14, 5.2), "stairs_garden", "楼梯厅与花艺工坊", true]] if i == 0 else []))
		_partition(floor_root, Vector2(-28, rect.end.y), Vector2(-14, rect.end.y), height, [
			[Vector2(-21, 8), "west_garden", "会客厅与茶点花园", true]] if i == 0 else [])
		_partition(floor_root, Vector2(14, rect.end.y), Vector2(28, rect.end.y), height, [
			[Vector2(21, 8), "east_garden", "工坊与蓝鲸花径", true]] if i == 0 else [])
		var back: float = [-12.0, -16.0, -20.0][i]
		var gate: float = [11.0, 11.0, 9.8][i]
		_partition(floor_root, Vector2(-14, back), Vector2(14, back), height, [
			[Vector2(gate, back), prefix + "rear_hall", rear_names[i], true]])
	_partition(builder.floors[0], Vector2(-14, -2), Vector2(8.4, -2), 0, [
		[Vector2(-8.6, -2), "kitchen", "海盐厨房", true]])
	# Separate the two rear dining spaces and leave the front entrance undivided.
	_partition(builder.floors[0], Vector2(3.5, -32), Vector2(3.5, -12), 0, [
		[Vector2(3.5, -15), "dining", "鲸鱼餐厅", true]])
	_partition(builder.floors[1], Vector2(2.2, -16), Vector2(2.2, 2), builder.HEIGHT, [
		[Vector2(2.2, -8.1), "study", "海景书房", true]])
	_partition(builder.floors[0], Vector2(-14, 8), Vector2(-3, 8), 0, [
		[Vector2(-9.6, 8), "porch", "花藤门廊与前庭", true]])
	_partition(builder.floors[0], Vector2(-3, 8), Vector2(14, 8), 0, [
		[Vector2(3.5, 8), "dining_garden", "海风前厅与前庭", true]])
	_partition(builder.floors[1], Vector2(-14, 2), Vector2(2.2, 2), builder.HEIGHT, [
		[Vector2(-6.8, 2), "living_terrace", "水族客厅与海景露台", true]])
	_partition(builder.floors[1], Vector2(2.2, 2), Vector2(8.4, 2), builder.HEIGHT)
	builder.level.set_meta("home_room_doors", doors)
	builder.level.set_meta("home_wall_tops", wall_tops)
	builder.level.set_meta("home_partitions", partitions)
	builder.level.set_meta("room_revision", "partitions_and_hinged_doors_v1")

func _partition(parent: Node3D, a: Vector2, b: Vector2, height: float, openings: Array = []) -> void:
	var length := a.distance_to(b)
	var center := (a + b) * 0.5
	var root: Node3D = builder._group(parent, "RoomPartition", Vector3(center.x, height, center.y))
	root.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	root.set_meta("floor_height", height)
	root.set_meta("wall_length", length)
	partitions.append(root)
	var upper: Node3D = builder._group(root, "CutawayUpper")
	upper.set_meta("home_dynamic", true)
	wall_tops.append(upper)
	var cuts: Array = []
	for spec: Array in openings:
		var point: Vector2 = spec[0]
		var offset: float = root.to_local(Vector3(point.x, height, point.y)).x
		cuts.append({"offset": offset, "spec": spec})
	cuts.sort_custom(func(left, right): return left.offset < right.offset)
	var start := -length * 0.5
	for cut: Dictionary in cuts:
		_span(root, upper, start, cut.offset - OPENING * 0.5)
		var head_height := WALL_HEIGHT - DOOR_HEIGHT - 0.12
		builder._box(upper, Vector3(OPENING, head_height, 0.24), Vector3(cut.offset, WALL_HEIGHT - head_height * 0.5, 0), builder.WHITE)
		builder._coll(root, Vector3(OPENING, head_height, 0.26), Vector3(cut.offset, WALL_HEIGHT - head_height * 0.5, 0))
		_door(root, cut.offset, height, cut.spec)
		start = cut.offset + OPENING * 0.5
	_span(root, upper, start, length * 0.5)
	builder._batch(upper)

func _span(root: Node3D, upper: Node3D, start: float, end: float) -> void:
	if end <= start: return
	var length := end - start
	var x := (start + end) * 0.5
	builder._box(root, Vector3(length, LOW_HEIGHT, 0.24), Vector3(x, LOW_HEIGHT * 0.5, 0), builder.WHITE)
	for y in [0.12, 1.08]:
		builder._box(root, Vector3(length, 0.08, 0.30), Vector3(x, y, 0), builder.MINT)
	for i in ceili(length / 0.7):
		var width: float = minf(0.64, length - i * 0.7 - 0.03)
		if width <= 0: continue
		for face in [-1.0, 1.0]:
			builder._box(root, Vector3(width, 0.78, 0.025), Vector3(start + i * 0.7 + width * 0.5 + 0.015, 0.60, face * 0.135), builder.MINT.lightened(0.22), 0, 0.012)
	builder._box(upper, Vector3(length, WALL_HEIGHT - LOW_HEIGHT, 0.24), Vector3(x, (WALL_HEIGHT + LOW_HEIGHT) * 0.5, 0), builder.WHITE)
	builder._box(upper, Vector3(length, 0.12, 0.34), Vector3(x, WALL_HEIGHT, 0), builder.WOOD, 1)
	builder._coll(root, Vector3(length, WALL_HEIGHT, 0.26), Vector3(x, WALL_HEIGHT * 0.5, 0))

func _door(root: Node3D, offset: float, height: float, spec: Array) -> void:
	var door := Door.new()
	door.name = "RoomDoor_" + str(spec[1])
	door.position = Vector3(offset, 0, 0)
	door.set_meta("home_dynamic", true)
	door.set_meta("floor_height", height)
	root.add_child(door)
	var state_key: String = "whale_home:door:" + str(spec[1])
	if not builder.game.visited.has(state_key): builder.game.visited[state_key] = bool(spec[3])
	door.configure(builder.game, DOOR_WIDTH, spec[1], spec[2], DOOR_HEIGHT)
	for mesh: MeshInstance3D in door.find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = mesh.material_override
		var color: Color = material.albedo_color
		var finish := 0
		if color.is_equal_approx(Color("476274")): color = builder.TEAL
		elif color.is_equal_approx(Color("d5dfd9")): color = builder.WHITE
		elif color.is_equal_approx(Color("93b9c2")): color = builder.LIGHT
		else: color = builder.GOLD; finish = 2
		mesh.material_override = Geo.material(color, finish)
	for side in [-1.0, 1.0]:
		builder._box(root, Vector3(0.12, DOOR_HEIGHT + 0.12, 0.34), Vector3(offset + side * (OPENING * 0.5 - 0.06), (DOOR_HEIGHT + 0.12) * 0.5, 0), builder.TEAL)
		builder._coll(root, Vector3(0.12, DOOR_HEIGHT + 0.12, 0.34), Vector3(offset + side * (OPENING * 0.5 - 0.06), (DOOR_HEIGHT + 0.12) * 0.5, 0))
	builder._box(root, Vector3(OPENING, 0.12, 0.36), Vector3(offset, DOOR_HEIGHT + 0.06, 0), builder.TEAL)
	builder._box(root, Vector3(DOOR_WIDTH + 0.1, 0.50, 0.30), Vector3(offset, 3.32, 0), builder.MINT)
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = spec[2]
		label.font = builder.game._game_font()
		label.font_size = 40
		label.pixel_size = 0.007
		label.outline_size = 0
		label.modulate = builder.WHITE
		label.position = Vector3(offset, 3.32, side * 0.155)
		label.rotation.y = 0 if side > 0 else PI
		root.add_child(label)
	for pivot: Node3D in door.pivots: builder._batch(pivot, false)
	doors.append(door)
