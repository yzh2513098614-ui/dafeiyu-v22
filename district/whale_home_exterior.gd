extends RefCounted
## A continuous three-storey home articulated as a hall and two coastal wings.
const Geo = preload("res://district/story_geometry.gd")
const Castle = preload("res://district/whale_home_castle.gd")
const WALL = Color("e6ddc9")
const LINK_WALL = Color("e7deca")
const TRIM = Color("f3ead6")
const BASE = Color("b5bcb2")
const FRAME = Color("799b94")
const PANE = Color("a7c8c8")
const WOOD = Color("baa986")
const ROOF = Color("6c8db4")
const RIDGE = Color("4e6d91")
const WALL_HEIGHT := 5.2
const THICKNESS := .36
const FRONT := 8.18
var b
var entry_x: float
var masses: Array = []

func build(builder) -> void:
	b = builder
	var gate: Node3D = b.level.get_meta("grand_gate")
	entry_x = gate.global_position.x
	# The links are shallow, fully enclosed setbacks, with continuous floor bodies.
	masses = [
		{"name": "WestPavilion", "left": -28.0, "right": -14.8, "projection": .85, "color": WALL},
		{"name": "WestLink", "left": -14.8, "right": entry_x - 6.0, "projection": .12, "color": LINK_WALL},
		{"name": "EntryPavilion", "left": entry_x - 6.0, "right": entry_x + 6.0, "projection": 1.10, "color": TRIM},
		{"name": "EastLink", "left": entry_x + 6.0, "right": 18.0, "projection": .12, "color": LINK_WALL},
		{"name": "EastPavilion", "left": 18.0, "right": 28.0, "projection": .85, "color": WALL}]
	var villa: Node3D = b._group(b.level, "ExteriorVilla")
	villa.set_meta("home_exterior", true)
	for i in 2:
		var h: float = i * b.HEIGHT
		for mass: Dictionary in masses:
			_elevation(villa, str(mass.name) + str(i), mass.left, mass.right,
				Vector3(0, h, FRONT + mass.projection), 0, _front_windows(mass.name, i), mass.projection, mass.color)
		var rect: Rect2 = b.FLOOR_RECTS[i]
		_elevation(villa, "WestWall" + str(i), rect.position.y, FRONT + .85, Vector3(-28.18, h, 0), -PI * .5,
			[_window_spec(-26, 2.7, 1.0, 4.1, "paired"), _window_spec(-17, 2.7, 1.0, 4.1, "paired"), _window_spec(-8, 2.7, 1.0, 4.1, "paired"), _window_spec(1, 2.7, 1.0, 4.1, "paired")])
		_elevation(villa, "EastWall" + str(i), -FRONT - .85, -rect.position.y, Vector3(28.18, h, 0), PI * .5,
			[_window_spec(26, 2.7, 1.0, 4.1, "paired"), _window_spec(17, 2.7, 1.0, 4.1, "paired"), _window_spec(8, 2.7, 1.0, 4.1, "paired"), _window_spec(-1, 2.7, 1.0, 4.1, "paired")])
		_elevation(villa, "RearWall" + str(i), -28, 28, Vector3(0, h, rect.position.y - .18), PI,
			[_window_spec(0, 5.2, 1.25, 4.05, "wide")])
		if i > 0:
			_floor_extension(villa, i, rect.end.y)
	_vertical_members(villa)
	_facade_roof_closure(villa)
	_entry(villa, gate)
	_tower()
	b._batch(b.floors[2].get_node("MoonriseStairs_3F_4F"))
	Castle.new().build(b, self, villa)
	b._batch(villa)
	b.level.set_meta("exterior_villa", villa)
	villa.set_meta("exterior_revision", "enclosed_slate_castle_v1")
	villa.set_meta("enclosed_front", FRONT)
	villa.set_meta("principal_roofs", 1)
	villa.set_meta("facade_masses", masses)

func _window_spec(x: float, width: float, bottom: float, top: float, style: String) -> Dictionary:
	return {"x": x, "width": width, "bottom": bottom, "top": top, "style": style, "door": false}

func _front_windows(part: String, floor_index: int) -> Array:
	match part:
		"WestPavilion":
			if floor_index == 0: return [_window_spec(-25, 3.0, 1.25, 4.0, "paired")]
			return [_window_spec(-21, 4.8 if floor_index == 2 else 5.4, 1.15, 4.15, "paired" if floor_index == 2 else "wide")]
		"WestLink":
			return [_window_spec(-5.5 if floor_index == 0 else -9.6, 3.6, 1.25, 4.05, "paired")]
		"EntryPavilion":
			if floor_index == 0: return []
			return [_window_spec(entry_x, 5.2 if floor_index == 1 else 4.8, .80, 4.30, "hall")]
		"EastLink":
			if floor_index == 0: return [_window_spec(13.6, 3.5, 1.25, 4.05, "wide")]
			return [_window_spec(10.8, 1.35, .65, 4.30, "stair")]
		"EastPavilion":
			if floor_index == 0: return []
			return [_window_spec(21, 4.8, 1.15, 4.15, "paired" if floor_index == 2 else "wide")]
	return []

func _floor_extension(villa: Node3D, floor_index: int, recessed_front: float) -> void:
	var floor_body: Node3D = b._group(villa, "EnclosedFloorExtension" + str(floor_index))
	var h: float = floor_index * b.HEIGHT
	for mass: Dictionary in masses:
		var width: float = mass.right - mass.left
		var depth: float = FRONT + mass.projection - recessed_front
		b._box(floor_body, Vector3(width, .34, depth), Vector3((mass.left + mass.right) * .5, h - .22, recessed_front + depth * .5), WALL, 0, .012)
	floor_body.set_meta("enclosed_projection", Rect2(-28, recessed_front, 56, FRONT - recessed_front))

func _elevation(villa: Node3D, label: String, left: float, right: float, origin: Vector3, yaw: float, windows: Array, projection: float = 0, color: Color = WALL, wall_height: float = WALL_HEIGHT) -> void:
	var face: Node3D = b._group(villa, label, origin)
	face.rotation.y = yaw
	face.set_meta("wall_projection", projection)
	face.set_meta("wall_color", color)
	var openings: Array = []
	# The front mass grows outward around the real doors, leaving deep open reveals.
	for door: Node3D in b.level.get_meta("home_room_doors"):
		var p: Vector3 = face.to_local(door.global_position)
		if absf(p.z) > projection + .4 or absf(p.y) > .1 or p.x < left or p.x > right:
			continue
		var custom: bool = door.has_meta("home_custom_frame")
		var width: float = door.get_meta("home_opening_width", 3.6)
		openings.append({"x": p.x, "width": width + .24, "bottom": 0.0, "top": 5.08 if custom else 3.96, "door": true})
	for window: Dictionary in windows:
		var clear := true
		for opening: Dictionary in openings:
			if absf(float(window.x) - float(opening.x)) < (float(window.width) + float(opening.width)) * .5 + .25:
				clear = false
		if clear: openings.append(window)
	openings.sort_custom(func(a: Dictionary, c: Dictionary): return a.x < c.x)
	var cursor: float = left
	for opening: Dictionary in openings:
		var start: float = opening.x - opening.width * .5
		var end: float = opening.x + opening.width * .5
		_wall_piece(face, cursor, start, 0, wall_height)
		_wall_piece(face, start, end, 0, opening.bottom)
		_wall_piece(face, start, end, opening.top, wall_height)
		if not opening.door: _window(face, opening)
		cursor = end
	_wall_piece(face, cursor, right, 0, wall_height)
	# Quiet, short cornices follow each mass instead of striping the whole building.
	b._box(face, Vector3(right - left, .09, .48), Vector3((left + right) * .5, wall_height - .055, .045), TRIM, 0, .014)
	face.set_meta("facade_openings", openings)
	face.set_meta("facade_height",wall_height)

func _facade_roof_closure(villa: Node3D) -> void:
	# The facade projects past the original third-floor edge. Close its roof
	# horizontally, behind the existing cornice and outside the terrace guard.
	var root: Node3D=b._group(villa,"FacadeRoofClosure")
	for mass: Dictionary in masses:
		var end: float=FRONT+mass.projection+.28
		b._box(root,Vector3(mass.right-mass.left,.30,end-8.0),Vector3((mass.left+mass.right)*.5,10.26,(end+8.0)*.5),TRIM,0,.014)

func _wall_piece(face: Node3D, left: float, right: float, bottom: float, top: float) -> void:
	if right - left < .001 or top - bottom < .001: return
	var width: float = right - left
	var x: float = (left + right) * .5
	var projection: float = face.get_meta("wall_projection")
	var depth: float = THICKNESS + projection
	var wall: MeshInstance3D=b._box(face, Vector3(width, top - bottom, depth), Vector3(x, (top + bottom) * .5, -projection * .5), face.get_meta("wall_color"), 0, .015)
	wall.material_override=Castle.stone(face.get_meta("wall_color"))
	if bottom == 0 and face.position.y < .1:
		b._box(face, Vector3(width, .60, depth + .12), Vector3(x, .31, -projection * .5 + .03), BASE, 0, .02)
		b._box(face, Vector3(width, .075, .52), Vector3(x, .65, .07), TRIM, 0, .012)
		for y in [.24, .47]:
			b._box(face, Vector3(width, .018, .02), Vector3(x, y, .255), WALL, 0, .003)

func _window(face: Node3D, opening: Dictionary) -> void:
	var window: Node3D=b._group(face,"RecessedWindow",Vector3(opening.x,opening.bottom,0))
	var width: float=opening.width
	var height: float=opening.top-opening.bottom
	var helper:=Castle.new();helper.b=b
	var count: int=2 if opening.style in ["wide","paired"] and width>3.3 else 1
	var span: float=width/count
	for index in count:
		var cx: float=-width*.5+(index+.5)*span
		var arch: Node3D=b._group(window,"RecessedStoneArch",Vector3(cx,.12,-.10))
		var arc_width: float=span-.30
		var arc_height: float=height-.22
		helper._arch_window(arch,arc_width,arc_height)
		var radius: float=arc_width*.5
		var spring: float=arc_height-radius
		var fill:=SurfaceTool.new();fill.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 16:
			var angle: float=i*PI/16.;var next: float=(i+1)*PI/16.
			var x: float=cos(angle)*radius;var end: float=cos(next)*radius
			Geo._face(fill,[Vector3(cx+x,.12+spring+sin(angle)*radius,.01),Vector3(cx+end,.12+spring+sin(next)*radius,.01),Vector3(cx+end,height,.01),Vector3(cx+x,height,.01)],Vector3.BACK)
		var infill:=MeshInstance3D.new();infill.mesh=fill.commit();infill.material_override=Geo.material(face.get_meta("wall_color"));window.add_child(infill)
	for side in [-1.0,1.0]:
		b._box(window,Vector3(.16,height,.30),Vector3(side*(width-.15)*.5,height*.5,-.03),TRIM)
	b._box(window,Vector3(width+.35,.16,.67),Vector3(0,-.06,.10),TRIM)
	window.set_meta("recess_depth",.37);window.set_meta("window_style",opening.style)

func _vertical_members(villa: Node3D) -> void:
	var root: Node3D = b._group(villa, "FullHeightPiers")
	var height: float = 2 * b.HEIGHT
	for spec: Vector2 in [Vector2(-27.72, .85), Vector2(-15.05, .85), Vector2(entry_x - 5.72, 1.10), Vector2(entry_x + 5.72, 1.10), Vector2(18.24, .85), Vector2(27.72, .85)]:
		var point := Vector3(spec.x, 0, FRONT + spec.y + .20)
		b._box(root, Vector3(.44, height - .24, .22), point + Vector3(0, height * .5, 0), TRIM, 0, .023)
		b._box(root, Vector3(.68, .64, .44), point + Vector3(0, .33, .015), BASE, 0, .022)
		b._box(root, Vector3(.66, .20, .45), point + Vector3(0, height - .14, .015), TRIM, 0, .018)
	# Downpipes give the broad elevations a plausible edge and meet the stone base.
	for x in [-27.52, 27.52]:
		Geo.rod(root, Vector3(x, .55, FRONT + 1.20), Vector3(x, height - .3, FRONT + 1.20), .055, RIDGE)
	root.set_meta("vertical_articulation", true)

func _entry(villa: Node3D, gate: Node3D) -> void:
	var entry: Node3D = b._group(villa, "VillaFrontEntry", gate.global_position)
	# A recessed seven-metre door, framed by a twelve-metre portico.
	for side in [-1.0, 1.0]:
		var point := Vector3(side * 5.05, 0, 2.35)
		b._box(entry, Vector3(.82, .17, .82), point + Vector3(0, .12, 0), BASE, 0, .025)
		b._box(entry, Vector3(.64, .20, .64), point + Vector3(0, .30, 0), TRIM, 0, .022)
		Geo.cylinder(entry, .22, 4.50, point + Vector3(0, 2.64, 0), TRIM)
		b._box(entry, Vector3(.72, .16, .72), point + Vector3(0, 4.96, 0), TRIM, 0, .022)
		b._coll(entry, Vector3(.64, 5.05, .64), point + Vector3(0, 2.53, 0))
	b._box(entry, Vector3(11.25, .25, .54), Vector3(0, 5.14, 2.35), TRIM, 0, .025)
	_hip_roof(entry, "PorticoRoof", Rect2(-5.9, -.3, 11.8, 3.55), 5.28, .48)
	entry.set_meta("uses_existing_grand_gate", true)
	entry.set_meta("portico_width", 11.8)

func _roofs(villa: Node3D) -> void:
	var h: float = b.HEIGHT * 3.0
	var left: Node3D = _hip_roof(villa, "WestHipRoof", Rect2(-28.82, -39.02, entry_x + 23.32, FRONT + 40.62), h + .06, 2.55)
	var right: Node3D = _hip_roof(villa, "EastHipRoof", Rect2(entry_x + 5.5, -39.02, 23.32 - entry_x, FRONT + 40.62), h + .06, 2.30)
	left.set_meta("principal_roof", true)
	right.set_meta("principal_roof", true)
	var attic: Node3D = b._group(villa, "RaisedEntryAttic")
	var rear_z: float = -38.18
	var front_z: float = FRONT + 1.10
	var attic_height: float = .65 + 3.65 * (1.0 - 6.0 / 6.7)
	b._box(attic, Vector3(12, attic_height, front_z - rear_z), Vector3(entry_x, h + attic_height * .5, (front_z + rear_z) * .5), TRIM, 0, .015)
	var center: Node3D = _gable_roof(villa, Rect2(entry_x - 6.70, -39.02, 13.40, front_z + 39.72), h + .65, 3.65)
	center.set_meta("principal_roof", true)
	_gable_wall(attic, front_z + .05, h + .65, 3.65)
	_gable_wall(attic, rear_z, h + .65, 3.65)
	_round_window(attic, Vector3(entry_x, h + 2.0, front_z + .25))

func _roof_mesh(parent: Node3D, tool: SurfaceTool) -> void:
	var node := MeshInstance3D.new()
	node.name = "ClosedRoofPlanes"
	node.mesh = tool.commit()
	node.material_override = Geo.material(ROOF)
	parent.add_child(node)

func _hip_roof(parent: Node3D, label: String, rect: Rect2, height: float, rise: float) -> Node3D:
	var roof: Node3D = b._group(parent, label)
	var a := Vector3(rect.position.x, height, rect.position.y)
	var c := Vector3(rect.end.x, height, rect.position.y)
	var d := Vector3(rect.end.x, height, rect.end.y)
	var e := Vector3(rect.position.x, height, rect.end.y)
	var inset: float = minf(rect.size.x, rect.size.y) * .28
	var rear := Vector3(rect.get_center().x, height + rise, rect.position.y + inset)
	var front := Vector3(rect.get_center().x, height + rise, rect.end.y - inset)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: Array in [[a, c, rear], [c, d, front], [c, front, rear], [d, e, front], [e, a, rear], [e, rear, front]]:
		var points: Array[Vector3] = []
		points.assign(triangle)
		var normal: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
		if normal.y < 0: normal = -normal
		Geo._face(tool, points, normal)
	_roof_mesh(roof, tool)
	for edge: Array in [[a, c], [c, d], [d, e], [e, a]]:
		_fascia(roof, edge[0], edge[1])
	for edge: Array in [[a, rear], [c, rear], [d, front], [e, front], [rear, front]]:
		Geo.rod(roof, edge[0] + Vector3.UP * .025, edge[1] + Vector3.UP * .025, .065, RIDGE)
	var rows: int = maxi(1, ceili((front.z - rear.z) / 1.8))
	for i in rows + 1:
		var z: float = lerpf(rear.z, front.z, float(i) / rows)
		for x in [rect.position.x, rect.end.x]:
			Geo.rod(roof, Vector3(x, height + .025, z), Vector3(rect.get_center().x, height + rise + .025, z), .025, ROOF.lightened(.06))
	roof.set_meta("closed_roof", true)
	roof.set_meta("roof_ridge_height", height + rise)
	return roof

func _gable_roof(villa: Node3D, rect: Rect2, height: float, rise: float) -> Node3D:
	var roof: Node3D = b._group(villa, "CentralGableRoof")
	var x: float = rect.get_center().x
	var half: float = rect.size.x * .5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	Geo._face(tool, [Vector3(rect.position.x, height, rect.position.y), Vector3(x, height + rise, rect.position.y), Vector3(x, height + rise, rect.end.y), Vector3(rect.position.x, height, rect.end.y)], Vector3(-rise, half, 0).normalized())
	Geo._face(tool, [Vector3(x, height + rise, rect.position.y), Vector3(rect.end.x, height, rect.position.y), Vector3(rect.end.x, height, rect.end.y), Vector3(x, height + rise, rect.end.y)], Vector3(rise, half, 0).normalized())
	_roof_mesh(roof, tool)
	for z in [rect.position.y, rect.end.y]:
		_fascia(roof, Vector3(rect.position.x, height, z), Vector3(x, height + rise, z))
		_fascia(roof, Vector3(x, height + rise, z), Vector3(rect.end.x, height, z))
	for edge_x in [rect.position.x, rect.end.x]:
		_fascia(roof, Vector3(edge_x, height, rect.position.y), Vector3(edge_x, height, rect.end.y))
	Geo.rod(roof, Vector3(x, height + rise + .04, rect.position.y), Vector3(x, height + rise + .04, rect.end.y), .105, RIDGE)
	var rows: int = ceili(rect.size.y / 1.8)
	for i in rows + 1:
		var z: float = rect.position.y + rect.size.y * float(i) / rows
		for edge_x in [rect.position.x, rect.end.x]:
			Geo.rod(roof, Vector3(edge_x, height + .025, z), Vector3(x, height + rise + .025, z), .028, ROOF.lightened(.06))
	roof.set_meta("closed_roof", true)
	roof.set_meta("roof_ridge_height", height + rise)
	return roof

func _fascia(roof: Node3D, start: Vector3, end: Vector3) -> void:
	var direction: Vector3 = end - start
	var strip: MeshInstance3D = b._box(roof, Vector3(direction.length(), .23, .22), (start + end) * .5 - Vector3.UP * .13, TRIM, 0, .018)
	strip.rotation = Vector3(0, -atan2(direction.z, direction.x), atan2(direction.y, Vector2(direction.x, direction.z).length()))
	Geo.rod(roof, start + Vector3.UP * .015, end + Vector3.UP * .015, .045, RIDGE)

func _gable_wall(parent: Node3D, z: float, height: float, rise: float) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoulder: float = height + rise * (1.0 - 6.0 / 6.7)
	var points: Array[Vector3] = [Vector3(entry_x - 6.0, height, z), Vector3(entry_x + 6.0, height, z), Vector3(entry_x + 6.0, shoulder, z), Vector3(entry_x, height + rise, z), Vector3(entry_x - 6.0, shoulder, z)]
	var back: Array[Vector3] = []
	for p: Vector3 in points: back.append(p - Vector3.BACK * .24)
	Geo._face(tool, points, Vector3.BACK)
	Geo._face(tool, back, Vector3.FORWARD)
	for i in points.size():
		var next: int = (i + 1) % points.size()
		var edge: Vector3 = points[next] - points[i]
		Geo._face(tool, [points[i], points[next], back[next], back[i]], Vector3(edge.y, -edge.x, 0).normalized())
	var panel := MeshInstance3D.new()
	panel.name = "SolidGablePediment"
	panel.mesh = tool.commit()
	panel.material_override = Geo.material(TRIM)
	parent.add_child(panel)

func _round_window(parent: Node3D, point: Vector3) -> void:
	var root: Node3D = b._group(parent, "GableOculus", point)
	var pane := Geo.cylinder(root, .72, .045, Vector3.ZERO, PANE)
	pane.rotation.x = PI * .5
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .72
	torus.outer_radius = .92
	torus.rings = 32
	torus.ring_segments = 10
	ring.mesh = torus
	ring.rotation.x = PI * .5
	ring.material_override = Geo.material(FRAME)
	root.add_child(ring)
	b._box(root, Vector3(1.40, .06, .08), Vector3(0, 0, .05), TRIM, 0, .006)
	b._box(root, Vector3(.06, 1.40, .08), Vector3(0, 0, .05), TRIM, 0, .006)

func _tower() -> void:
	var contract=preload("res://district/whale_home_rooftop.gd")
	var tower: Node3D=b._group(b.level,"TowerExterior")
	tower.set_meta("home_dynamic",true)
	var h: float=contract.HEIGHT
	var upper_h: float=h+b.HEIGHT
	var rect: Rect2=contract.TOWER
	_tower_floor_closure(upper_h)
	_elevation(tower,"TowerWest",-30,-6,Vector3(-20.18,h,0),-PI*.5,[_window_spec(-25.5,3.8,1.25,4.05,"paired")])
	_elevation(tower,"TowerEast",6,30,Vector3(.18,h,0),PI*.5,[_window_spec(15.5,4.6,1.25,4.05,"wide"),_window_spec(26,2.8,1.6,4.05,"paired")])
	_elevation(tower,"TowerRear",0,20,Vector3(0,h,-30.18),PI,[_window_spec(16.75,3.6,1.25,4.05,"paired")])
	var front: Node3D=b._group(tower,"TowerFront",Vector3(0,h,-6))
	front.set_meta("wall_projection",0.0);front.set_meta("wall_color",WALL)
	_wall_piece(front,-20,-18.25,0,5.2)
	_wall_piece(front,-15.25,-13.5,0,5.2)
	_wall_piece(front,-8.5,0,0,5.2)
	_wall_piece(front,-18.25,-15.25,3.05,5.2)
	var top_rect: Rect2=contract.OBSERVATORY
	_elevation(tower,"ObservatoryWest",top_rect.position.y,top_rect.end.y,Vector3(top_rect.position.x-.18,upper_h,0),-PI*.5,[_window_spec(-24,2.5,.85,4.5,"paired"),_window_spec(-17.5,2.5,.85,4.5,"paired"),_window_spec(-11,2.5,.85,4.5,"paired")])
	_elevation(tower,"ObservatoryEast",-top_rect.end.y,-top_rect.position.y,Vector3(top_rect.end.x+.18,upper_h,0),PI*.5,[_window_spec(12,2.5,.85,4.5,"paired"),_window_spec(19,2.5,.85,4.5,"paired"),_window_spec(25,2.5,.85,4.5,"paired")])
	_elevation(tower,"ObservatoryRear",-top_rect.end.x,-top_rect.position.x,Vector3(0,upper_h,top_rect.position.y-.18),PI,[_window_spec(10.0,4.8,1.0,4.15,"wide")])
	var upper_front: Node3D=b._group(tower,"ObservatoryFront",Vector3(0,upper_h,top_rect.end.y+.18))
	upper_front.set_meta("wall_projection",0.0);upper_front.set_meta("wall_color",TRIM)
	_wall_piece(upper_front,top_rect.position.x,-13.0,0,5.2)
	_wall_piece(upper_front,-8.6,top_rect.end.x,0,5.2)
	_wall_piece(upper_front,-13.0,-8.6,3.0,5.2)
	for x in [-15.2,-4.8]:
		var frame: Node3D=b._group(upper_front,"ObservatoryArchedBay",Vector3(x,.85,.21))
		var details:=Castle.new();details.b=b;details._arch_window(frame,2.7,3.6)
	b._box(tower,Vector3(top_rect.size.x+1.1,.16,top_rect.size.y+1.1),Vector3(top_rect.get_center().x,upper_h+5.18,top_rect.get_center().y),TRIM)
	# The observatory uses a flat service roof. The octagonal lantern sits directly
	# on that slab so the spire reads as the building's vertical core.
	# Do not build an invisible hip roof: the static merger would resurrect it.
	var builder:=Castle.new();builder.b=b
	var crown: Node3D=builder._tower(tower,Vector3(-10.1,20.82,-22.8),2.8,3.8,7.8,true)
	crown.name="OctagonalDaylightCrown"
	var mast: Node3D=b._group(tower,"WhaleSpireMast",Vector3(-10.1,33.0,-22.8))
	Geo.rod(mast,Vector3.ZERO,Vector3(0,1.1,0),.045,b.GOLD)
	var flag: MeshInstance3D=b._box(mast,Vector3(1.15,.58,.035),Vector3(.58,.62,0),ROOF,0,.01)
	flag.rotation.z=-.12
	_observatory_roof(tower,builder)
	b._batch(tower)
	b.level.set_meta("tower_exterior",tower)

func _tower_floor_closure(height: float) -> void:
	# Bridge the 1.5 m setback to the lower walls. The central stair opening is
	# preserved; the new stone ring has the same floor support as the hall.
	var root: Node3D=b._group(b.level,"ObservatoryFloorClosure")
	var regions: Array[Rect2]=[Rect2(-20.42,-30.42,1.92,24.84),Rect2(-1.5,-30.42,1.92,24.84),Rect2(-18.5,-30.42,17,1.92),Rect2(-18.5,-7.5,5.5,1.92),Rect2(-8.6,-7.5,7.1,1.92)]
	for rect: Rect2 in regions:
		var piece: Node3D=b._group(root,"StoneSetbackSlab")
		b._slab(piece,rect,height)
		piece.get_child(0).free()
		b._box(piece,Vector3(rect.size.x,.34,rect.size.y),Vector3(rect.get_center().x,height-.14,rect.get_center().y),TRIM,0,.014)
	root.set_meta("closure_regions",regions)
	root.set_meta("closure_floor_height",height)
	b.level.set_meta("observatory_floor_closure",root)
	for point: Vector3 in [Vector3(-19.4,height,-26),Vector3(-19.4,height,-19),Vector3(-19.4,height,-11),Vector3(-17,height,-6.45),Vector3(-3.5,height,-6.45),Vector3(-.6,height,-26)]:
		var planter: Node3D=b._group(root,"SetbackFlowerPlanter",point)
		Geo.cylinder(planter,.34,.5,Vector3(0,.25,0),TRIM,.45)
		Geo.cylinder(planter,.48,.10,Vector3(0,.52,0),TRIM)
		b.Pastel.clump(planter,Vector3(0,.85,0),Vector3(1.05,.78,1.05),b.GREEN)
		for i in 3:b._flower(planter,Vector3(sin(i*2.1)*.25,1.22,cos(i*2.1)*.25),b.SAKURA if i%2 else TRIM,.25)
	b._batch(root)

func _observatory_roof(tower: Node3D, details) -> void:
	# A glazed roof gallery meets the sloping slate roof; the spire garden
	# remains open behind it. All windows share the existing stone arch details.
	var roof: Node3D=b._group(tower,"ObservatorySlateGable")
	var gallery_rect:=Rect2(-18.5,-18.4,17,10.9)
	var base: float=20.8
	var eave: float=23.45
	details._gable(roof,Rect2(-18.9,-18.4,17.8,11.5),eave,3.9)
	var windows: Array=[]
	for x: float in [-16.8,-13.4,-10.0,-6.6,-3.2]:windows.append(_window_spec(x,2.4,.55,2.40,"paired"))
	_elevation(roof,"GlazedLookoutFront",-18.5,-1.5,Vector3(0,base,-7.5),0,windows,0,WALL,eave-base)
	_elevation(roof,"GlazedLookoutWest",-18.4,-7.5,Vector3(-18.5,base,0),-PI*.5,[_window_spec(-16,1.9,.55,2.40,"paired"),_window_spec(-12.8,1.9,.55,2.40,"paired"),_window_spec(-9.6,1.9,.55,2.40,"paired")],0,WALL,eave-base)
	_elevation(roof,"GlazedLookoutEast",7.5,18.4,Vector3(-1.5,base,0),PI*.5,[_window_spec(9.6,1.9,.55,2.40,"paired"),_window_spec(12.8,1.9,.55,2.40,"paired"),_window_spec(16,1.9,.55,2.40,"paired")],0,WALL,eave-base)
	for x: float in [-18.5,-1.5]:b._box(roof,Vector3(.40,eave-base,.40),Vector3(x,(base+eave)*.5,-7.5),TRIM)
	b.level.set_meta("covered_roof_gallery",gallery_rect)
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shoulder: float=eave+3.9*(.4/8.9)
	Geo._face(tool,[Vector3(-18.5,eave,-7.5),Vector3(-1.5,eave,-7.5),Vector3(-1.5,shoulder,-7.5),Vector3(-10,eave+3.9,-7.5),Vector3(-18.5,shoulder,-7.5)],Vector3.BACK)
	var wall:=MeshInstance3D.new();wall.mesh=tool.commit();wall.material_override=Castle.stone(WALL);roof.add_child(wall)
	var arch: Node3D=b._group(roof,"LookoutGableArch",Vector3(-10,eave+.35,-7.43))
	details._arch_window(arch,2.25,2.6)
	for x: float in [-16.0,-12.0,-8.0,-4.0]:
		var flowers: Node3D=b._group(roof,"SpireGardenParapetFlowers",Vector3(x,20.8,-28.10))
		b._box(flowers,Vector3(2.55,.45,.45),Vector3(0,.55,0),TRIM)
		for i in 4:
			b.Pastel.clump(flowers,Vector3(-.9+i*.6,.94,0),Vector3(.85,.65,.70),b.GREEN)
			b._flower(flowers,Vector3(-.9+i*.6,1.29,.03),b.SAKURA,.27)
	var stair: Node3D=b.floors[2].get_node("MoonriseStairs_3F_4F")
	var stair_spec: Dictionary=stair.get_meta("home_stair")
	for child in stair.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh and child.mesh.get_aabb().size.x>3.0:
			child.material_override=Castle.stone(TRIM)
	# Stone cheeks follow the actual 3.5 m stair, including solid end caps.
	for side: float in [-1.0,1.0]:
		var x: float=stair_spec.x+side*(stair_spec.width*.5+.25)
		var panel:=SurfaceTool.new();panel.begin(Mesh.PRIMITIVE_TRIANGLES)
		var front:=Vector3(x,stair_spec.base,stair_spec.front)
		var back:=Vector3(x,stair_spec.top,stair_spec.back)
		for face: float in [-1.0,1.0]:
			var delta:=Vector3(face*.12,0,0)
			Geo._face(panel,[front+delta,back+delta,back+Vector3.UP*1.05+delta,front+Vector3.UP*1.05+delta],Vector3.RIGHT*face)
		var half:=Vector3(.12,0,0)
		Geo._face(panel,[front-half+Vector3.UP*1.05,back-half+Vector3.UP*1.05,back+half+Vector3.UP*1.05,front+half+Vector3.UP*1.05],Vector3.UP)
		Geo._face(panel,[front-half,front+half,front+half+Vector3.UP*1.05,front-half+Vector3.UP*1.05],Vector3.BACK)
		Geo._face(panel,[back-half,back+half,back+half+Vector3.UP*1.05,back-half+Vector3.UP*1.05],Vector3.FORWARD)
		var cheek:=MeshInstance3D.new();cheek.mesh=panel.commit();cheek.material_override=Castle.stone(WALL);roof.add_child(cheek)
		Geo.rod(roof,front+Vector3.UP*1.08,back+Vector3.UP*1.08,.11,TRIM)
