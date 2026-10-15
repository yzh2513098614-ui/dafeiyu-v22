extends RefCounted
## Bedding geometry stays inside the original bed footprints and colliders.
const Geo = preload("res://district/story_geometry.gd")
static var pillows: Dictionary = {}

static func build(b, bed: Node3D, guest: bool = false) -> void:
	var width: float = 3.8 if guest else 5.2
	var depth: float = 5.0 if guest else 6.3
	var blue: Color = b.LIGHT if guest else b.BLUE
	bed.set_meta("bed_model_revision", "soft_bedding_v2")
	var frame: Node3D = b._group(bed, "JoineryBedFrame")
	for side in [-1.0, 1.0]:
		b._finish_box(frame, Vector3(.18, .40, depth), Vector3(side * (width * .5 - .09), .42, 0), "ash_table")
		b._finish_box(frame, Vector3(width - .18, .40, .18), Vector3(0, .42, side * (depth * .5 - .09)), "ash_table")
		for z in [-depth * .43, depth * .43]:
			b._finish_box(frame, Vector3(.22, .53, .22), Vector3(side * (width * .5 - .32), .265, z), "cream_cabinet")
	for i in 8:
		b._finish_box(frame, Vector3(width - .22, .08, .28), Vector3(0, .53, -depth * .42 + i * depth * .12), "ash_table", "top", .015)
	var mattress: Node3D = b._group(bed, "PipedMattress")
	b._cloth(b._box(mattress, Vector3(width - .23, .54, depth - .25), Vector3(0, .82, 0), b.WHITE, 0, .20), b.WHITE)
	for y in [.61, 1.035]: _piping(mattress, Vector3(0, y, 0), Vector2(width - .22, depth - .24), .24, .014, b.LIGHT)
	_headboard(b, bed, width, depth, guest)
	var duvet: Node3D = b._group(bed, "DrapedQuilt")
	var quilt_width: float = 3.65 if guest else 5.04
	var quilt_depth: float = 3.7 if guest else 4.76
	var quilt_center := Vector3(0, 1.13, .5) if guest else Vector3(0, 1.13, .65)
	_sheet(b, duvet, quilt_center, Vector2(quilt_width, quilt_depth), blue, .35, .25, 1)
	var fold_z: float = quilt_center.z - quilt_depth * .5 + .35
	_puff(b, duvet, Vector3(0, 1.34, fold_z), Vector3(quilt_width - .10, .17, .64), b.WHITE if guest else b.LIGHT, false)
	_sheet(b, duvet, Vector3(0, 1.20, depth * .29), Vector2(quilt_width - .06, .70), b.SAKURA if guest else b.MINT, .32, 0.0, 0)
	for side in [-1.0, 1.0]:
		var point := Vector3(side * (.87 if guest else 1.24), 1.28, -1.68 if guest else -2.13)
		var size := Vector3(1.40, .36, .91) if guest else Vector3(1.85, .40, 1.08)
		_puff(b, bed, point, size, b.WHITE, true)
		if not guest: _puff(b, bed, Vector3(side * .95, 1.44, -1.35), Vector3(1.05, .28, .66), b.MINT if side < 0 else b.LIGHT, true)
	var plush: Node3D = b._group(bed, "WhaleBedsidePlush")
	b._whale(plush, Vector3(-.35 if guest else .35, 1.27, -.40 if guest else -.55), .30 if guest else .43, -18, b.BLUE if guest else b.LIGHT)

static func _headboard(b, bed: Node3D, width: float, depth: float, guest: bool) -> void:
	var outline: PackedVector2Array
	if guest:
		outline = PackedVector2Array([Vector2(-1.89,.57),Vector2(-1.89,1.35),Vector2(-1.73,1.65),Vector2(-1.3,1.80),Vector2(0,1.86),Vector2(1.3,1.80),Vector2(1.73,1.65),Vector2(1.89,1.35),Vector2(1.89,.57)])
	else:
		outline = PackedVector2Array([Vector2(-2.48,.60),Vector2(-2.48,1.26),Vector2(-2.32,1.64),Vector2(-1.98,1.95),Vector2(-1.58,2.12),Vector2(-1.24,2.08),Vector2(-.86,1.83),Vector2(0,1.64),Vector2(.86,1.83),Vector2(1.24,2.08),Vector2(1.58,2.12),Vector2(1.98,1.95),Vector2(2.32,1.64),Vector2(2.48,1.26),Vector2(2.48,.60)])
	var root: Node3D = b._group(bed, "ArchedGuestHeadboard" if guest else "WhaleTailHeadboard", Vector3(0, 0, -depth * .5 + .14))
	var wood := MeshInstance3D.new(); wood.mesh = _panel(outline, .22); wood.material_override = Geo.material(b.WOOD, 1); root.add_child(wood)
	var inner := PackedVector2Array()
	for p in outline: inner.append(Vector2(p.x * .94, .65 + (p.y - .60) * .91))
	var padded := MeshInstance3D.new(); padded.mesh = _panel(inner, .10); padded.position.z = .15
	b._cloth(padded, b.MINT if guest else b.LIGHT, 0); root.add_child(padded)
	for i in inner.size():
		var a: Vector2 = inner[i]; var next: Vector2 = inner[(i + 1) % inner.size()]
		Geo.rod(root, Vector3(a.x, a.y, .21), Vector3(next.x, next.y, .21), .018, b.WHITE)
	for x in [-width * .31, 0.0, width * .31]:
		b._sphere(root, Vector3(x, 1.35, .22), Vector3(.10, .10, .045), b.TEAL)

static func _panel(outline: PackedVector2Array, thickness: float) -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(outline)
	for i in range(0, indices.size(), 3):
		var front: Array[Vector3] = []; var back: Array[Vector3] = []
		for j in 3:
			var p: Vector2 = outline[indices[i + j]]
			front.append(Vector3(p.x, p.y, thickness * .5)); back.append(Vector3(p.x, p.y, -thickness * .5))
		Geo._face(tool, front, Vector3.BACK); Geo._face(tool, back, Vector3.FORWARD)
	for i in outline.size():
		var a: Vector2 = outline[i]; var next: Vector2 = outline[(i + 1) % outline.size()]
		var edge := next - a
		var normal := Vector3(-edge.y, edge.x, 0).normalized()
		Geo._face(tool, [Vector3(a.x,a.y,-thickness*.5),Vector3(next.x,next.y,-thickness*.5),Vector3(next.x,next.y,thickness*.5),Vector3(a.x,a.y,thickness*.5)], normal)
	return tool.commit()

static func _puff(b, parent: Node3D, point: Vector3, size: Vector3, color: Color, piped: bool) -> Node3D:
	var root: Node3D = b._group(parent, "PipedSoftPillow" if piped else "TurnedQuiltFold", point)
	var key := str(size)
	if not pillows.has(key):
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			for ring in 8:
				for i in 32:
					var a := _puff_point(size, float(ring)/8, i*TAU/32, side)
					var next := _puff_point(size, float(ring)/8, (i+1)*TAU/32, side)
					var outer := _puff_point(size, float(ring+1)/8, (i+1)*TAU/32, side)
					var last := _puff_point(size, float(ring+1)/8, i*TAU/32, side)
					if ring == 0: Geo._face(tool, [a, outer, last], Vector3.UP*side)
					else: Geo._face(tool, [a, next, outer, last], Vector3.UP*side)
		tool.index(); tool.generate_normals(); pillows[key] = tool.commit()
	var mesh := MeshInstance3D.new(); mesh.mesh = pillows[key]; b._cloth(mesh, color); root.add_child(mesh)
	if piped:
		for i in 32:
			Geo.rod(root, _puff_point(size, 1.0, i*TAU/32, 1), _puff_point(size, 1.0, (i+1)*TAU/32, 1), .010, color.darkened(.12))
	return root

static func _puff_point(size: Vector3, radius: float, angle: float, side: float) -> Vector3:
	var c := cos(angle); var s := sin(angle)
	return Vector3(signf(c)*pow(absf(c),.45)*size.x*.5*radius, side*size.y*.5*sqrt(maxf(0,1-pow(radius,3))), signf(s)*pow(absf(s),.45)*size.z*.5*radius)

static func _piping(parent: Node3D, point: Vector3, size: Vector2, radius: float, thickness: float, color: Color) -> void:
	var ring: Array[Vector3] = []
	for corner in 4:
		var sx: float = 1.0 if corner in [0,3] else -1.0
		var sz: float = 1.0 if corner in [0,1] else -1.0
		var center := Vector2(sx*(size.x*.5-radius),sz*(size.y*.5-radius))
		for i in 7:
			var a: float = corner*PI*.5 + i*PI/12.0
			ring.append(point+Vector3(center.x+cos(a)*radius,0,center.y+sin(a)*radius))
	for i in ring.size(): Geo.rod(parent, ring[i], ring[(i+1)%ring.size()], thickness, color)

static func _sheet(b, parent: Node3D, point: Vector3, size: Vector2, color: Color, side_drop: float, foot_drop: float, pattern: int) -> void:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for row in 24:
			for column in 32:
				var points: Array[Vector3] = []
				for offset in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
					var u: float = (column+offset.x)/32.0; var v: float = (row+offset.y)/24.0
					points.append(_sheet_point(point,size,u,v,side_drop,foot_drop,side<0))
				Geo._face(tool, points, Vector3.UP*side)
	for end in [0.0, 1.0]:
		for i in 32:
			var u: float = i/32.0; var next: float = (i+1)/32.0
			Geo._face(tool, [_sheet_point(point,size,u,end,side_drop,foot_drop),_sheet_point(point,size,next,end,side_drop,foot_drop),_sheet_point(point,size,next,end,side_drop,foot_drop,true),_sheet_point(point,size,u,end,side_drop,foot_drop,true)], Vector3.FORWARD if end==0 else Vector3.BACK)
		for i in 24:
			var v: float = i/24.0; var next: float = (i+1)/24.0
			Geo._face(tool, [_sheet_point(point,size,end,v,side_drop,foot_drop),_sheet_point(point,size,end,next,side_drop,foot_drop),_sheet_point(point,size,end,next,side_drop,foot_drop,true),_sheet_point(point,size,end,v,side_drop,foot_drop,true)], Vector3.LEFT if end==0 else Vector3.RIGHT)
	tool.index(); tool.generate_normals()
	var mesh := MeshInstance3D.new(); mesh.name = "SoftDrapedFabric"; mesh.mesh = tool.commit(); b._cloth(mesh, color, pattern); parent.add_child(mesh)

static func _sheet_point(point: Vector3, size: Vector2, u: float, v: float, side_drop: float, foot_drop: float, lower: bool = false) -> Vector3:
	var x: float = (u-.5)*size.x; var z: float = (v-.5)*size.y
	var y: float = .15+.022*sin(z*4.0+x)*sin(u*PI)-side_drop*pow(absf(u*2.0-1.0),10)-foot_drop*pow(smoothstep(.82,1.0,v),2)
	return point+Vector3(x,y-(.055 if lower else 0.0),z)
