extends RefCounted
## Adapted from godot-pastel-diorama. Colliders belong to the home map.
const Geo = preload("res://district/story_geometry.gd")
const CREAM = Color("f3eedb")
const MINT = Color("91b9ac")
const SAGE = Color("a6c080")
const PINK = Color("f3c9d4")
const WOOD = Color("c7af7d")
static var boxes: Dictionary = {}
static var leaf_mesh: ArrayMesh

static func material(color: Color) -> Material:
	return Geo.material(color)

static func group(parent: Node3D, label: String, point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = label
	root.position = point
	parent.add_child(root)
	return root

static func box(parent: Node3D, size: Vector3, point: Vector3, color: Color = CREAM) -> MeshInstance3D:
	if not boxes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		boxes[size] = mesh
	var node := MeshInstance3D.new()
	node.mesh = boxes[size]
	node.material_override = material(color)
	node.position = point
	parent.add_child(node)
	return node

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color = WOOD) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius * 0.7
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = (a + b) * 0.5
	node.material_override = material(color)
	var axis := (b - a).normalized()
	var guide := Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD
	var right := axis.cross(guide).normalized()
	node.basis = Basis(right, axis, right.cross(axis).normalized())
	parent.add_child(node)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var swap := b
		b = c
		c = swap
	for point in [a, b, c]:
		tool.set_normal(normal)
		tool.add_vertex(point)

static func clump(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> void:
	if not leaf_mesh:
		var t := (1.0 + sqrt(5.0)) * 0.5
		var vertices: Array[Vector3] = [Vector3(-1,t,0),Vector3(1,t,0),Vector3(-1,-t,0),Vector3(1,-t,0),Vector3(0,-1,t),Vector3(0,1,t),Vector3(0,-1,-t),Vector3(0,1,-t),Vector3(t,0,-1),Vector3(t,0,1),Vector3(-t,0,-1),Vector3(-t,0,1)]
		var faces: Array = [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in faces:
			var a: Vector3 = vertices[int(face[0])].normalized() * 0.5
			var b: Vector3 = vertices[int(face[1])].normalized() * 0.5
			var c: Vector3 = vertices[int(face[2])].normalized() * 0.5
			var ab := (a+b).normalized()*0.5
			var bc := (b+c).normalized()*0.5
			var ca := (c+a).normalized()*0.5
			for tri in [[a,ab,ca],[b,bc,ab],[c,ca,bc],[ab,bc,ca]]:
				var p: Vector3 = tri[0]
				var q: Vector3 = tri[1]
				var r: Vector3 = tri[2]
				_triangle(tool,p,q,r,(q-p).cross(r-p).normalized())
		leaf_mesh = tool.commit()
	var node := MeshInstance3D.new()
	node.mesh = leaf_mesh
	node.material_override = material(color)
	node.position = point
	node.scale = size
	parent.add_child(node)

static func tree(parent: Node3D, point: Vector3, scale_value: float = 1.0, sakura: bool = false) -> Node3D:
	var root := group(parent,"SakuraTree" if sakura else "SageTree",point)
	root.scale = Vector3.ONE * scale_value
	rod(root,Vector3.ZERO,Vector3(0.12,2.65,0),0.17,Color("9b946d"))
	var color := PINK if sakura else SAGE
	for i in 7:
		var a := i * TAU / 7.0
		var p := Vector3(cos(a)*0.95,2.7+float(i%3)*0.37,sin(a)*0.82)
		if i%2==0: rod(root,Vector3(0.05,1.45,0),p,0.09,Color("9b946d"))
		clump(root,p,Vector3(1.8,1.6,1.7),color.lightened(float(i%3)*0.035))
	clump(root,Vector3(0,3.5,0),Vector3(2.2,1.7,2.0),color.lightened(0.06))
	return root

static func tiled_roof(parent: Node3D, width: float, depth: float, rise: float, color: Color = MINT) -> Node3D:
	var root := group(parent,"TiledRoof",Vector3.ZERO)
	var slope := Vector2(width*0.5,rise).length()
	var angle := atan2(rise,width*0.5)
	var rows := ceili(slope/0.55)
	var columns := ceili(depth/0.60)
	for side in [-1.0,1.0]:
		box(root,Vector3(slope,0.12,depth),Vector3(side*width*0.25,rise*0.5,0),color).rotation.z = -side*angle
		box(root,Vector3(0.14,0.17,depth+0.12),Vector3(side*width*0.5,-0.02,0),color.darkened(0.08))
		for row in rows:
			var t := (row+0.5)/float(rows)
			for column in columns:
				var p := Vector3(side*width*0.5*(1-t),rise*t+0.085,-depth*0.5+(column+0.5)*depth/columns)
				box(root,Vector3(slope/rows+0.015,0.07,depth/columns-0.022),p,color.lightened(0.025 if row%2 else 0.0)).rotation.z = -side*angle
	rod(root,Vector3(0,rise+0.12,-depth*0.5-0.12),Vector3(0,rise+0.12,depth*0.5+0.12),0.13,color.darkened(0.04))
	return root

static func picket_fence(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var root := group(parent,"CreamPicketFence",(a+b)*0.5)
	var length := a.distance_to(b)
	root.rotation.y = -atan2(b.z-a.z,b.x-a.x)
	for y in [0.28,0.79]: box(root,Vector3(length,0.10,0.12),Vector3(0,y,0),CREAM)
	var count := ceili(length/0.40)
	for i in count+1:
		var x := -length*0.5+i*length/count
		box(root,Vector3(0.18,0.95,0.13),Vector3(x,0.49,0.015),CREAM)
		box(root,Vector3(0.14,0.14,0.13),Vector3(x,0.965,0.015),CREAM).rotation.z=PI*0.25
	return root

static func bench(parent: Node3D, point: Vector3) -> Node3D:
	var root := group(parent,"GardenBench",point)
	for x in [-0.8,0.8]:
		box(root,Vector3(0.11,0.65,0.72),Vector3(x,0.325,0),Color("648e84"))
		box(root,Vector3(0.10,0.92,0.10),Vector3(x,0.69,-0.28),Color("648e84"))
	for z in [-0.24,0.0,0.24]: box(root,Vector3(2.1,0.08,0.20),Vector3(0,0.65,z),WOOD)
	for y in [0.90,1.13]: box(root,Vector3(2.1,0.18,0.07),Vector3(0,y,-0.30),WOOD)
	return root

static func planter(parent: Node3D, point: Vector3) -> Node3D:
	var root := group(parent,"FlowerPlanter",point)
	box(root,Vector3(0.65,0.45,0.65),Vector3(0,0.225,0),Color("efb48d"))
	box(root,Vector3(0.71,0.08,0.71),Vector3(0,0.45,0),CREAM)
	clump(root,Vector3(0,0.62,0),Vector3(0.8,0.46,0.8),SAGE)
	for i in 4:
		var a := i*TAU/4.0
		clump(root,Vector3(cos(a)*0.22,0.81,sin(a)*0.22),Vector3.ONE*0.23,PINK if i%2 else CREAM)
	return root

static func house(parent: Node3D, point: Vector3, size: Vector3, roof_color: Color = MINT) -> Node3D:
	var root := group(parent,"PastelHouseShell",point)
	box(root,size,Vector3(0,size.y*0.5,0),CREAM)
	box(root,Vector3(size.x+0.12,0.18,size.z+0.12),Vector3(0,0.08,0),Color("d5d5bd"))
	var front := size.z*0.5+0.035
	for floor_index in 2:
		for side in [-1.0,1.0]:
			var p := Vector3(side*size.x*0.25,size.y*(0.32+floor_index*0.42),front)
			box(root,Vector3(size.x*0.28,0.95,0.10),p,CREAM.lightened(0.04))
			box(root,Vector3(size.x*0.25,0.83,0.03),p+Vector3(0,0,0.07),Color("bad6ca"))
			box(root,Vector3(0.065,0.83,0.055),p+Vector3(0,0,0.095),Color("648e84"))
			box(root,Vector3(size.x*0.25,0.065,0.055),p+Vector3(0,0,0.095),Color("648e84"))
	box(root,Vector3(0.85,1.65,0.12),Vector3(0,0.83,front+0.04),MINT)
	box(root,Vector3(1.05,0.12,0.55),Vector3(0,1.80,front+0.17),Color("648e84"))
	var rise := size.x*0.36
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0,1.0]:
		_triangle(tool,Vector3(-size.x*0.5,size.y,side*size.z*0.5),Vector3(size.x*0.5,size.y,side*size.z*0.5),Vector3(0,size.y+rise,side*size.z*0.5),Vector3(0,0,side))
	var gable := MeshInstance3D.new()
	gable.mesh=tool.commit()
	gable.material_override=material(CREAM)
	root.add_child(gable)
	var roof := tiled_roof(root,size.x+0.40,size.z+0.50,rise,roof_color)
	roof.position.y=size.y
	return root
