extends RefCounted
const Geo = preload("res://district/story_geometry.gd")
const Soft = preload("res://assets/whale_home/beds.gd")
const Finishes = preload("res://assets/whale_home/furniture_finishes.gd")

static func sofa(b, root: Node3D, width: float) -> void:
	root.set_meta("sofa_model_revision", "piped_upholstery_v2")
	var structure: Node3D = b._group(root, "SofaWoodenUnderframe")
	for x in [-width*.38, width*.38]:
		for z in [-.54, .54]: Geo.cylinder(structure, .075, .25, Vector3(x, .125, z), b.WOOD, .055)
	b._finish_box(structure, Vector3(width-.18, .17, 1.58), Vector3(0, .30, 0), "ash_table")
	b._cloth(b._box(root, Vector3(width-.08, .25, 1.72), Vector3(0, .46, 0), b.BLUE, 0, .09), b.BLUE)
	b._cloth(b._box(root, Vector3(width-.36, .92, .22), Vector3(0, .98, -.78), b.LIGHT, 0, .07), b.LIGHT)
	var seats: int = maxi(2, roundi((width-.70)/1.7))
	var slot: float = (width-.72)/seats
	var cushions: Node3D = b._group(root, "SeparatePipedSeatCushions")
	for i in seats:
		var x: float = -(width-.72)*.5 + (i+.5)*slot
		Soft._puff(b, cushions, Vector3(x, .74, .12), Vector3(slot-.055, .33, 1.29), b.WHITE, true)
		var back: Node3D = Soft._puff(b, cushions, Vector3(x, 1.08, -.65), Vector3(slot-.055, .38, .88), b.WHITE, true)
		back.rotation.x = -PI*.5+.10
	for side in [-1.0, 1.0]:
		var arm_x: float = side*(width*.5-.18)
		b._cloth(b._box(root, Vector3(.31, .64, 1.68), Vector3(arm_x, .76, 0), b.LIGHT, 0, .06), b.LIGHT)
		Soft._puff(b, root, Vector3(arm_x, .98, 0), Vector3(.34, .36, 1.70), b.LIGHT, true)
		var pillow: Node3D = Soft._puff(b, root, Vector3(side*((width-.72)*.5-.35), 1.08, -.28), Vector3(.64, .24, .65), b.MINT if side < 0 else b.SAKURA, true)
		pillow.rotation = Vector3(-PI*.5, 0, side*.16)
	Soft._sheet(b, root, Vector3(width*.5-.50, 1.0, .1), Vector2(.65, 1.15), b.MINT, .15, .18, 1)
	var plush: Node3D = b._group(root, "SofaWhalePlush")
	b._whale(plush, Vector3(-.15, .88, .10), .30, -12, b.BLUE)

static func tea_table(b, root: Node3D, width: float, depth: float, height: float) -> void:
	root.set_meta("tea_table_model_revision", "rounded_shelf_table_v2")
	var frame: Node3D = b._group(root, "SplayedTeaTableLegs")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var leg: MeshInstance3D = b._finish_box(frame, Vector3(.13, height-.10, .13), Vector3(x*width*.34, (height-.10)*.5, z*depth*.27), "tea_table", "body", .025)
			leg.rotation = Vector3(z*.07, 0, -x*.07)
	for side in [-1.0, 1.0]:
		b._finish_box(frame, Vector3(width-.36, .14, .10), Vector3(0, height-.15, side*depth*.27), "tea_table")
	var top := MeshInstance3D.new()
	top.name = "RoundedChamferedTeaTop"; top.mesh = _table_top(Vector2(width, depth)); top.position.y = height
	top.material_override = Finishes.material("tea_table", "top"); root.add_child(top)
	var border: Array[Vector3] = _rim(Vector2(width-.18, depth-.18), minf(width,depth)*.24-.06, height+.072)
	for i in border.size(): Geo.rod(root, border[i], border[(i+1)%border.size()], .007, b.WOOD.darkened(.13))
	var shelf: Node3D = b._group(root, "LowerMagazineShelf")
	var shelf_y: float = height*.32
	for i in 5:
		b._finish_box(shelf, Vector3(width-.48, .065, depth*.10), Vector3(0, shelf_y, -depth*.25+i*depth*.125), "tea_table", "top", .012)
	for i in 2:
		b._box(shelf, Vector3(.68, .055, .46), Vector3(-width*.10, shelf_y+.065+i*.06, 0), b.LIGHT if i==0 else b.MINT, 0, .008)
		b._box(shelf, Vector3(.62, .025, .44), Vector3(-width*.10, shelf_y+.065+i*.06, .015), b.WHITE, 0, .003)

static func _rim(size: Vector2, radius: float, y: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for corner in 4:
		var sx: float = 1.0 if corner in [0,3] else -1.0
		var sz: float = 1.0 if corner in [0,1] else -1.0
		var center := Vector2(sx*(size.x*.5-radius), sz*(size.y*.5-radius))
		for i in 7:
			var angle: float = corner*PI*.5+i*PI/12.0
			points.append(Vector3(center.x+cos(angle)*radius, y, center.y+sin(angle)*radius))
	return points

static func _table_top(size: Vector2) -> ArrayMesh:
	var radius: float = minf(size.x, size.y)*.24
	var rings: Array = [_rim(size-Vector2.ONE*.06,radius-.03,.07), _rim(size,radius,.035), _rim(size,radius,-.035), _rim(size-Vector2.ONE*.06,radius-.03,-.07)]
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings[0].size():
		var next: int = (i+1)%rings[0].size()
		Geo._face(tool, [Vector3(0,.07,0),rings[0][i],rings[0][next]], Vector3.UP)
		Geo._face(tool, [Vector3(0,-.07,0),rings[3][i],rings[3][next]], Vector3.DOWN)
		for band in 3:
			var mid: Vector3 = (rings[band][i]+rings[band][next])*.5
			var normal := Vector3(mid.x, .6 if band==0 else (-.6 if band==2 else 0.0), mid.z).normalized()
			Geo._face(tool, [rings[band][i],rings[band][next],rings[band+1][next],rings[band+1][i]], normal)
	return tool.commit()
