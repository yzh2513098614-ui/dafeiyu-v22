extends RefCounted
## Complete exterior shell; room doors remain the real interactive entrances.
const Geo = preload("res://district/story_geometry.gd")
const WALL = Color("e6e0cc")
const TRIM = Color("f3eedb")
const BASE = Color("b8bbaa")
const FRAME = Color("849f99")
const PANE = Color("a5c1c0")
const ROOF = Color("627e83")
const WALL_HEIGHT := 5.2
const THICKNESS := .36
var b

func build(builder) -> void:
	b = builder
	var villa: Node3D = b._group(b.level, "ExteriorVilla")
	villa.set_meta("home_exterior", true)
	# Fewer, broader window groups, with uninterrupted wall between them.
	_elevation(villa, "GroundFront", -28, 28, Vector3(0, 0, 8.18), 0, [-15.5, 12.0])
	_elevation(villa, "MiddleFront", -28, 28, Vector3(0, b.HEIGHT, 2.18), 0, [-21.0, 2.5, 21.0])
	_elevation(villa, "UpperFront", -28, 28, Vector3(0, b.HEIGHT * 2, -1.82), 0, [-21.0, -8.8, 19.0])
	for i in 3:
		var rect: Rect2 = b.FLOOR_RECTS[i]
		var h: float = i * b.HEIGHT
		_elevation(villa, "WestWall" + str(i), rect.position.y, rect.end.y, Vector3(-28.18, h, 0), -PI * .5, [-22.0])
		_elevation(villa, "EastWall" + str(i), -rect.end.y, -rect.position.y, Vector3(28.18, h, 0), PI * .5, [20.0])
		_elevation(villa, "RearWall" + str(i), -28, 28, Vector3(0, h, rect.position.y - .18), PI, [0.0])
	_entry(villa)
	_roof(villa)
	b._batch(villa)
	b.level.set_meta("exterior_villa", villa)
	villa.set_meta("exterior_revision", "complete_recessed_facade_v2")

func _elevation(villa: Node3D, label: String, left: float, right: float, origin: Vector3, yaw: float, windows: Array) -> void:
	var face: Node3D = b._group(villa, label, origin)
	face.rotation.y = yaw
	var openings: Array = []
	# Project actual doors onto this face, including the seven-metre GrandGate.
	for door: Node3D in b.level.get_meta("home_room_doors"):
		var p: Vector3 = face.to_local(door.global_position)
		if absf(p.z) > .4 or absf(p.y) > .1 or p.x < left or p.x > right:
			continue
		var width: float = door.get_meta("home_opening_width", 3.6)
		var height: float = 4.84 if door.has_meta("home_custom_frame") else 3.96
		openings.append({"x": p.x, "width": width + .12, "bottom": 0.0, "top": height, "door": true})
	for x: float in windows:
		var width: float = 4.4
		var clear := true
		for opening: Dictionary in openings:
			if absf(x - opening.x) < (width + opening.width) * .5 + .35:
				clear = false
		if clear:
			openings.append({"x": x, "width": width, "bottom": 1.28, "top": 3.80, "door": false})
	openings.sort_custom(func(a: Dictionary, c: Dictionary): return a.x < c.x)
	var cursor: float = left
	for opening: Dictionary in openings:
		var start: float = opening.x - opening.width * .5
		var end: float = opening.x + opening.width * .5
		_wall_piece(face, cursor, start, 0, WALL_HEIGHT)
		_wall_piece(face, start, end, 0, opening.bottom)
		_wall_piece(face, start, end, opening.top, WALL_HEIGHT)
		if not opening.door:
			_window(face, opening)
		cursor = end
	_wall_piece(face, cursor, right, 0, WALL_HEIGHT)
	# Continuous floor bands join the storeys; the plinth stops at every doorway.
	for tier: Vector3 in [Vector3(4.82, .14, .46), Vector3(5.00, .13, .56)]:
		b._box(face, Vector3(right - left, tier.y, tier.z), Vector3((left + right) * .5, tier.x, .025), TRIM, 0, .018)
	for x in [left + .20, right - .20]:
		b._box(face, Vector3(.30, 4.64, .15), Vector3(x, 2.42, .22), TRIM, 0, .018)
		for y in [.45, 1.05, 1.65, 2.25, 2.85, 3.45, 4.05]:
			b._box(face, Vector3(.38, .025, .18), Vector3(x, y, .23), BASE, 0, .004)
	face.set_meta("facade_openings", openings)

func _wall_piece(face: Node3D, left: float, right: float, bottom: float, top: float) -> void:
	if right - left < .001 or top - bottom < .001:
		return
	var width: float = right - left
	var x: float = (left + right) * .5
	b._box(face, Vector3(width, top - bottom, THICKNESS), Vector3(x, (top + bottom) * .5, 0), WALL, 0, .015)
	if bottom == 0:
		b._box(face, Vector3(width, .42, .44), Vector3(x, .23, .035), BASE, 0, .018)
		b._box(face, Vector3(width, .07, .49), Vector3(x, .47, .05), TRIM, 0, .012)
	# Two restrained horizontal joints give the masonry actual relief.
	for y in [1.10, 4.18]:
		if y > bottom and y < top:
			b._box(face, Vector3(width, .022, .025), Vector3(x, y, .185), BASE, 0, .003)

func _window(face: Node3D, opening: Dictionary) -> void:
	var window: Node3D = b._group(face, "RecessedWindow", Vector3(opening.x, opening.bottom, 0))
	var width: float = opening.width
	var height: float = opening.top - opening.bottom
	# Glazing sits inside the wall thickness, with real jambs and a deep sill.
	b._box(window, Vector3(width - .20, height - .20, .045), Vector3(0, height * .5, -.08), PANE, 0, .008)
	for side in [-1.0, 1.0]:
		b._box(window, Vector3(.11, height, .34), Vector3(side * (width - .11) * .5, height * .5, .015), TRIM, 0, .01)
		b._box(window, Vector3(width, .11, .34), Vector3(0, .055 if side < 0 else height - .055, .015), TRIM, 0, .01)
	for x in [-width / 6.0, width / 6.0]:
		b._box(window, Vector3(.055, height - .16, .12), Vector3(x, height * .5, .035), FRAME, 0, .006)
	b._box(window, Vector3(width - .16, .055, .12), Vector3(0, height * .48, .035), TRIM, 0, .006)
	b._box(window, Vector3(width + .30, .13, .65), Vector3(0, -.07, .12), TRIM, 0, .018)
	b._box(window, Vector3(width + .20, .12, .45), Vector3(0, height + .07, .045), BASE, 0, .015)
	window.set_meta("recess_depth", .26)

func _entry(villa: Node3D) -> void:
	var gate: Node3D = b.level.get_meta("grand_gate")
	var entry: Node3D = b._group(villa, "VillaFrontEntry", gate.global_position)
	# The existing carved double doors and frame are the entrance. No fake door.
	var canopy: Node3D = b._group(entry, "EntryCanopy", Vector3(0, 4.96, 1.05))
	b._box(canopy, Vector3(9.20, .14, 2.05), Vector3.ZERO, ROOF, 0, .03)
	b._box(canopy, Vector3(9.34, .10, .16), Vector3(0, -.09, 1.0), TRIM, 0, .015)
	for side in [-1.0, 1.0]:
		Geo.rod(entry, Vector3(side * 4.10, 4.38, .26), Vector3(side * 4.10, 4.88, 1.70), .055, FRAME)
	entry.set_meta("uses_existing_grand_gate", true)

func _roof(villa: Node3D) -> void:
	# A closed hip roof replaces the old open dollhouse ribs in exterior mode.
	_hip_roof(villa, "MainHipRoof", Rect2(-28.65, -38.65, 57.30, 37.30), b.HEIGHT * 3.0, 2.65)

func _hip_roof(villa: Node3D, label: String, rect: Rect2, height: float, rise: float) -> void:
	var roof: Node3D = b._group(villa, label)
	var a := Vector3(rect.position.x, height, rect.position.y)
	var c := Vector3(rect.end.x, height, rect.position.y)
	var d := Vector3(rect.end.x, height, rect.end.y)
	var e := Vector3(rect.position.x, height, rect.end.y)
	var inset: float = minf(rect.size.x * .28, rect.size.y * .28)
	var rear := Vector3(rect.get_center().x, height + rise, rect.position.y + inset)
	var front := Vector3(rect.get_center().x, height + rise, rect.end.y - inset)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: Array in [[a, c, rear], [c, d, front], [c, front, rear], [d, e, front], [e, a, rear], [e, rear, front]]:
		for p: Vector3 in triangle:
			tool.add_vertex(p)
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "ClosedRoofPlanes"
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = ROOF
	material.roughness = .9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	roof.add_child(mesh)
	for edge: Array in [[a, c], [c, d], [d, e], [e, a]]:
		var p: Vector3 = edge[0]
		var q: Vector3 = edge[1]
		var length: float = p.distance_to(q)
		var fascia: MeshInstance3D = b._box(roof, Vector3(length, .22, .20), (p + q) * .5 - Vector3(0, .12, 0), TRIM, 0, .018)
		fascia.rotation.y = -atan2(q.z - p.z, q.x - p.x)
	for edge: Array in [[a, rear], [c, rear], [d, front], [e, front], [rear, front]]:
		Geo.rod(roof, edge[0], edge[1], .055, FRAME)
	roof.set_meta("closed_roof", true)
