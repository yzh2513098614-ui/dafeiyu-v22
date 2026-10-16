extends RefCounted
## Adapted from godot-pastel-diorama. Colliders belong to the home map.
const Geo = preload("res://district/story_geometry.gd")
const CREAM = Color("f3eedb")
const MINT = Color("91b9ac")
const SAGE = Color("a6c080")
const PINK = Color("f3c9d4")
const WOOD = Color("c7af7d")
const TEAL = Color("648e84")
const BLUE = Color("639cdb")
static var mesh_cache: Dictionary = {}
static var leaf_mesh: ArrayMesh

static func use_shared_materials() -> void:
	var palette: Resource = load("res://models/whale_home/shared_palette.tres")
	Geo.material_cache.merge(palette.get_meta("materials"),true)

static func material(color: Color) -> Material:
	return Geo.material(color)

static func group(parent: Node3D, label: String, point: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = label
	root.position = point
	parent.add_child(root)
	return root

static func box(parent: Node3D, size: Vector3, point: Vector3, color: Color = CREAM) -> MeshInstance3D:
	return Geo.box(parent,size,point,color,1 if color==WOOD else 0,.018)

static func mesh_node(parent: Node3D, mesh: Mesh, point: Vector3, color: Color, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name=label;node.mesh=mesh;node.position=point;node.material_override=material(color)
	parent.add_child(node)
	return node

static func prism(outline: PackedVector2Array, depth: float) -> ArrayMesh:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices:=Geometry2D.triangulate_polygon(outline)
	for side in [-1.0,1.0]:
		for i in range(0,indices.size(),3):
			var points: Array[Vector3]=[]
			for j in 3:
				var p: Vector2=outline[indices[i+j]]
				points.append(Vector3(p.x,p.y,depth*.5*side))
			Geo._face(tool,points,Vector3(0,0,side))
	for i in outline.size():
		var a: Vector2=outline[i];var b: Vector2=outline[(i+1)%outline.size()]
		Geo._face(tool,[Vector3(a.x,a.y,-depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(b.x,b.y,depth*.5),Vector3(a.x,a.y,depth*.5)],Vector3(b.y-a.y,a.x-b.x,0).normalized())
	return tool.commit()

static func ring_mesh(inner: float, outer: float, depth: float, half: bool=false) -> ArrayMesh:
	var key:=str(Vector3(inner,outer,depth))+str(half)
	if mesh_cache.has(key):return mesh_cache[key]
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments:=24 if half else 48
	for i in segments:
		var a:=float(i)/segments*(PI if half else TAU)
		var b:=float(i+1)/segments*(PI if half else TAU)
		var pa:=Vector2(cos(a),sin(a));var pb:=Vector2(cos(b),sin(b))
		for sign_value in [-1.0,1.0]:
			Geo._face(tool,[Vector3(pa.x*inner,pa.y*inner,sign_value*depth*.5),Vector3(pb.x*inner,pb.y*inner,sign_value*depth*.5),Vector3(pb.x*outer,pb.y*outer,sign_value*depth*.5),Vector3(pa.x*outer,pa.y*outer,sign_value*depth*.5)],Vector3(0,0,sign_value))
		for radius in [inner,outer]:
			var normal:=Vector3(pa.x+pb.x,pa.y+pb.y,0).normalized()*(1.0 if radius==outer else -1.0)
			Geo._face(tool,[Vector3(pa.x*radius,pa.y*radius,-depth*.5),Vector3(pb.x*radius,pb.y*radius,-depth*.5),Vector3(pb.x*radius,pb.y*radius,depth*.5),Vector3(pa.x*radius,pa.y*radius,depth*.5)],normal)
	if half:
		for sign_value in [-1.0,1.0]:
			Geo._face(tool,[Vector3(sign_value*inner,0,-depth*.5),Vector3(sign_value*outer,0,-depth*.5),Vector3(sign_value*outer,0,depth*.5),Vector3(sign_value*inner,0,depth*.5)],Vector3.DOWN)
	mesh_cache[key]=tool.commit()
	return mesh_cache[key]

static func porch(parent: Node3D) -> Node3D:
	var root:=group(parent,"WhaleArchedEntry",Vector3.ZERO)
	for side in [-1.0,1.0]:
		var column:=group(root,"PorchColumn",Vector3(side*1.3,0,0))
		box(column,Vector3(.23,2.7,.28),Vector3(0,1.35,0),MINT)
		box(column,Vector3(.34,.14,.37),Vector3(0,.08,0))
		box(column,Vector3(.29,.12,.32),Vector3(0,.22,0))
		box(column,Vector3(.32,.11,.36),Vector3(0,2.55,0))
		box(column,Vector3(.36,.12,.39),Vector3(0,2.67,0))
	mesh_node(root,ring_mesh(1.17,1.43,.30,true),Vector3(0,2.7,0),MINT,"ArchVoussoir")
	mesh_node(root,ring_mesh(1.17,1.22,.038,true),Vector3(0,2.7,.169),CREAM,"InnerArchTrim")
	box(root,Vector3(.22,.25,.36),Vector3(0,4.10,0))
	root.set_meta("opening_width",2.34)
	return root

static func round_window(parent: Node3D) -> Node3D:
	var root:=group(parent,"RecessedRoundWindow",Vector3.ZERO)
	var disk:=CylinderMesh.new();disk.top_radius=.995;disk.bottom_radius=.995;disk.height=.018;disk.radial_segments=48
	mesh_node(root,disk,Vector3(0,0,.016),Color("bad6ca"),"WindowPane").rotation.x=PI*.5
	mesh_node(root,ring_mesh(.99,1.15,.24),Vector3(0,0,-.026),CREAM,"WindowReveal")
	mesh_node(root,ring_mesh(.98,1.015,.033),Vector3(0,0,.092),TEAL,"SashRebate")
	for size in [Vector3(1.97,.055,.055),Vector3(.055,1.97,.055)]:box(root,size,Vector3(0,0,.074))
	box(root,Vector3(2.54,.11,.40),Vector3(0,-1.10,.09))
	for x in [-.69,.69]:box(root,Vector3(.12,.16,.22),Vector3(x,-1.22,.02),MINT)
	return root

static func curved_tile_mesh(width: float, depth: float) -> ArrayMesh:
	var key: String="tile"+str(Vector2(width,depth))
	if mesh_cache.has(key):return mesh_cache[key]
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var t0:=i/8.0;var t1:=(i+1)/8.0
		var z0:=(t0-.5)*depth;var z1:=(t1-.5)*depth
		var y0:=.015+sin(t0*PI)*.095;var y1:=.015+sin(t1*PI)*.095
		# The raised lap keeps neighbouring tiles from sharing a coplanar face.
		var lap:=.035
		var normal:=Vector3(-lap/width,1,-(y1-y0)/(z1-z0)).normalized()
		Geo._face(tool,[Vector3(-width*.5,y0,z0),Vector3(width*.5,y0+lap,z0),Vector3(width*.5,y1+lap,z1),Vector3(-width*.5,y1,z1)],normal)
		Geo._face(tool,[Vector3(-width*.5,y0-.05,z0),Vector3(width*.5,y0+lap-.05,z0),Vector3(width*.5,y1+lap-.05,z1),Vector3(-width*.5,y1-.05,z1)],-normal)
		for side in [-1.0,1.0]:
			var lift:=lap if side>0 else 0.
			Geo._face(tool,[Vector3(side*width*.5,y0+lift-.05,z0),Vector3(side*width*.5,y1+lift-.05,z1),Vector3(side*width*.5,y1+lift,z1),Vector3(side*width*.5,y0+lift,z0)],Vector3(side,0,0))
	for side in [-1.0,1.0]:
		Geo._face(tool,[Vector3(-width*.5,-.035,side*depth*.5),Vector3(width*.5,0,side*depth*.5),Vector3(width*.5,.050,side*depth*.5),Vector3(-width*.5,.015,side*depth*.5)],Vector3(0,0,side))
	mesh_cache[key]=tool.commit()
	return mesh_cache[key]

static func roof_tile(parent: Node3D, width: float, depth: float, point: Vector3, color: Color=MINT) -> MeshInstance3D:
	return mesh_node(parent,curved_tile_mesh(width,depth),point,color,"CurvedRoofTile")

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

static func clump(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
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
	return node

static func _crown_point(polar: float, azimuth: float, axes: Vector3) -> Vector3:
	var ring:=sin(polar)
	var lobe:=1.0+.085*sin(azimuth*5.0+cos(polar*3.0)*.7)*pow(ring,1.5)
	lobe+=.028*sin(azimuth*11.0+polar*4.0)*ring*ring
	var point:=Vector3(ring*cos(azimuth),cos(polar),ring*sin(azimuth))*axes*lobe
	point.x+=.12*cos(polar)
	point.z+=.08*sin(polar*2.0)
	return point

static func _crown_mesh(axes: Vector3, form: String) -> ArrayMesh:
	var key: String="crown_"+form
	if mesh_cache.has(key):return mesh_cache[key]
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:=18;var sectors:=28
	for row in rings:
		for column in sectors:
			var corners: Array[Vector3]=[
				_crown_point(PI*row/rings,TAU*column/sectors,axes),
				_crown_point(PI*(row+1)/rings,TAU*column/sectors,axes),
				_crown_point(PI*(row+1)/rings,TAU*(column+1)/sectors,axes),
				_crown_point(PI*row/rings,TAU*(column+1)/sectors,axes)]
			for tri: Array in [[corners[0],corners[1],corners[2]],[corners[0],corners[2],corners[3]]]:
				var face: Vector3=(tri[1]-tri[0]).cross(tri[2]-tri[0])
				if face.length_squared()<1e-10:continue
				var center: Vector3=(tri[0]+tri[1]+tri[2])/3.0
				var outward: Vector3=(center/(axes*axes)).normalized()
				if face.dot(outward)<0:face=-face
				face=face.normalized()
				if (tri[1]-tri[0]).cross(tri[2]-tri[0]).dot(outward)>0:tri=[tri[0],tri[2],tri[1]]
				for point: Vector3 in tri:
					var normal: Vector3=(point/(axes*axes)).normalized().lerp(face,.18).normalized()
					var tone: float=.945+.035*(point.y/axes.y)+.012*sin(point.x*5.0+point.z*3.0)
					tool.set_normal(normal)
					tool.set_color(Color(tone,tone,tone))
					tool.set_uv(Vector2(point.x/axes.x*.5+.5,point.y/axes.y*.5+.5))
					tool.add_vertex(point)
	mesh_cache[key]=tool.commit()
	return mesh_cache[key]

static func tree(parent: Node3D, point: Vector3, scale_value: float = 1.0, sakura: bool = false, low: bool = false) -> Node3D:
	var form: String="sakura" if sakura else ("low_green" if low else "tall_green")
	var root:=group(parent,"SakuraTree" if sakura else ("LowSageTree" if low else "TallSageTree"),point)
	root.scale=Vector3.ONE*scale_value
	var bark:=Color("9b946d")
	var fork:=Vector3(-.04,1.46 if low else 1.88,.03)
	rod(root,Vector3.ZERO,Vector3(.05,.70,-.02),.20,bark)
	rod(root,Vector3(.05,.66,-.02),Vector3(-.08,1.34,.04),.16,bark)
	rod(root,Vector3(-.08,1.30,.04),fork,.12,bark)
	var center:=Vector3(.04,2.55,.04) if low else Vector3(-.03,3.16 if sakura else 3.25,0)
	var axes:=Vector3(1.65,1.12,1.43) if low else (Vector3(1.86,1.32,1.63) if sakura else Vector3(1.60,1.55,1.42))
	for i in 5:
		var a: float=i*TAU/5.0+.32
		var end:=center+Vector3(cos(a)*.85,-.40+float(i%2)*.28,sin(a)*.72)
		var elbow: Vector3=fork.lerp(end,.48)+Vector3(.04,.07,0)
		rod(root,fork,elbow,.077,bark)
		rod(root,elbow,end,.045,bark)
	var crown:=mesh_node(root,_crown_mesh(axes,form),center,Color("f0c6d3") if sakura else Color("acc68c"),"ContinuousCanopy")
	crown.set_meta("continuous_tree_crown",true)
	root.set_meta("tree_form",form)
	root.set_meta("tree_model_revision","continuous_crown_directional_wind_v4")
	return root

static func leaf(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not mesh_cache.has("leaf"):
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outline: Array[Vector3]=[Vector3(0,-.5,0),Vector3(-.5,-.12,0),Vector3(-.29,.24,0),Vector3(0,.5,.025),Vector3(.29,.24,0),Vector3(.5,-.12,0)]
		for side in [-1.0,1.0]:
			var center:=Vector3(0,0,side*.15)
			for i in outline.size():
				var a: Vector3=outline[i];var b: Vector3=outline[(i+1)%outline.size()]
				_triangle(tool,center,a,b,(a-center).cross(b-center).normalized()*-side)
		mesh_cache["leaf"]=tool.commit()
	var node:=mesh_node(parent,mesh_cache["leaf"],point,color,"RidgedLeaf")
	node.scale=size
	return node

static func tiled_roof(parent: Node3D, width: float, depth: float, rise: float, color: Color = MINT) -> Node3D:
	var root := group(parent,"TiledRoof",Vector3.ZERO)
	var slope := Vector2(width*0.5,rise).length()
	var angle := atan2(rise,width*0.5)
	var rows := ceili(slope/0.55)
	var columns := ceili(depth/0.60)
	for side in [-1.0,1.0]:
		box(root,Vector3(slope,.08,depth),Vector3(side*width*.25,rise*.5-.075,0),CREAM).rotation.z=-side*angle
		box(root,Vector3(.14,.17,depth+.16),Vector3(side*width*.5,-.02,0),TEAL)
		for row in rows:
			var t := (row+0.5)/float(rows)
			for column in columns:
				var p:=Vector3(side*width*.5*(1-t),rise*t+.035,-depth*.5+(column+.5)*depth/columns)
				roof_tile(root,slope/rows+.08,depth/columns-.014,p,color.lightened(.025 if row%2 else 0.0)).rotation.z=-side*angle
		for z in [-depth*.5-.04,depth*.5+.04]:
			rod(root,Vector3(side*width*.5,-.10,z),Vector3(0,rise-.10,z),.055,CREAM)
	rod(root,Vector3(0,rise+.12,-depth*.5-.12),Vector3(0,rise+.12,depth*.5+.12),.13,color)
	for z in [-depth*.5-.13,depth*.5+.13]:
		box(root,Vector3(.27,.15,.12),Vector3(0,rise+.12,z),TEAL)
	return root

static func pergola(parent: Node3D) -> Node3D:
	var root:=group(parent,"SeaBreezeGardenPergola",Vector3.ZERO)
	for x in [-2.0,2.0]:
		for z in [-1.65,1.65]:
			box(root,Vector3(.14,3.35,.14),Vector3(x,1.675,z))
			box(root,Vector3(.26,.15,.26),Vector3(x,.075,z),MINT)
			box(root,Vector3(.24,.13,.24),Vector3(x,3.13,z),MINT)
			rod(root,Vector3(x,2.76,z),Vector3(x-signf(x)*.42,3.20,z),.055,CREAM)
			rod(root,Vector3(x,2.76,z),Vector3(x,3.20,z-signf(z)*.36),.055,CREAM)
		box(root,Vector3(.18,.18,3.65),Vector3(x,3.24,0),MINT)
	for z in [-1.65,1.65]:box(root,Vector3(4.30,.18,.18),Vector3(0,3.24,z),MINT)
	for i in 7:box(root,Vector3(4.18,.09,.09),Vector3(0,3.33,-1.45+i*.48))
	tiled_roof(root,4.55,3.85,.85).position.y=3.35
	return root

static func picket_fence(parent: Node3D, a: Vector3, b: Vector3) -> Node3D:
	var root := group(parent,"CreamPicketFence",(a+b)*0.5)
	var length := a.distance_to(b)
	root.rotation.y = -atan2(b.z-a.z,b.x-a.x)
	for y in [0.28,0.79]: box(root,Vector3(length,0.10,0.12),Vector3(0,y,0),CREAM)
	if not mesh_cache.has("picket"):
		mesh_cache["picket"]=prism(PackedVector2Array([Vector2(-.09,0),Vector2(.09,0),Vector2(.09,.83),Vector2(.065,.92),Vector2(0,1.04),Vector2(-.065,.92),Vector2(-.09,.83)]),.13)
	var count := ceili(length/0.40)
	for i in count+1:
		var x := -length*0.5+i*length/count
		mesh_node(root,mesh_cache["picket"],Vector3(x,.02,.025),CREAM,"PointedBoard")
	for x in [-length*.5,length*.5]:
		var post:=group(root,"EndPostLeft" if x<0 else "EndPostRight",Vector3(x,0,-.015))
		box(post,Vector3(.24,1.10,.18),Vector3(0,.55,0))
		box(post,Vector3(.27,.08,.19),Vector3(0,1.10,0))
		for y in [.28,.79]:box(post,Vector3(.32,.15,.15),Vector3(0,y,-.065))
	return root

static func bench(parent: Node3D, point: Vector3) -> Node3D:
	var root := group(parent,"GardenBench",point)
	for x in [-0.8,0.8]:
		for z in [-.28,.28]:box(root,Vector3(.11,.65,.11),Vector3(x,.325,z),TEAL)
		box(root,Vector3(.10,.92,.10),Vector3(x,.69,-.28),TEAL)
		box(root,Vector3(.10,.10,.71),Vector3(x,.59,0),TEAL)
		rod(root,Vector3(x,.16,.27),Vector3(x,.59,-.27),.035,TEAL)
		box(root,Vector3(.075,.30,.075),Vector3(x,.79,.25),TEAL)
		box(root,Vector3(.12,.08,.70),Vector3(x,.94,.015),WOOD)
	box(root,Vector3(1.66,.075,.085),Vector3(0,.22,-.27),TEAL)
	for z in [-.24,0.0,.24]:box(root,Vector3(2.1,.08,.20),Vector3(0,.65,z),WOOD)
	for y in [.90,1.13]:
		var slat:=box(root,Vector3(2.1,.17,.085),Vector3(0,y,-.30),WOOD)
		slat.rotation.x=-.08
	return root

static func planter(parent: Node3D, point: Vector3) -> Node3D:
	var root := group(parent,"FlowerPlanter",point)
	box(root,Vector3(.65,.06,.65),Vector3(0,.03,0),CREAM)
	for side in [-1.0,1.0]:
		box(root,Vector3(.075,.43,.65),Vector3(side*.2875,.215,0),CREAM)
		box(root,Vector3(.50,.43,.075),Vector3(0,.215,side*.2875),CREAM)
	for side in [-1.0,1.0]:
		box(root,Vector3(.73,.07,.08),Vector3(0,.45,side*.325),MINT)
		box(root,Vector3(.08,.07,.57),Vector3(side*.325,.45,0),MINT)
	box(root,Vector3(.56,.025,.56),Vector3(0,.41,0),Color("785c42"))
	clump(root,Vector3(0,0.62,0),Vector3(0.8,0.46,0.8),SAGE)
	for i in 4:
		var a := i*TAU/4.0
		clump(root,Vector3(cos(a)*0.22,0.81,sin(a)*0.22),Vector3.ONE*0.23,PINK if i%2 else CREAM)
	return root

static func flower_bed(parent: Node3D, width: float=4.3, depth: float=2.8) -> Node3D:
	var root:=group(parent,"BorderedFlowerBed",Vector3.ZERO)
	for side in [-1.0,1.0]:
		box(root,Vector3(width,.12,.15),Vector3(0,.09,side*depth*.5),CREAM)
		box(root,Vector3(.15,.12,depth-.15),Vector3(side*width*.5,.09,0),CREAM)
	box(root,Vector3(width-.23,.055,depth-.23),Vector3(0,.036,0),Color("785c42"))
	for i in 7:
		var p:=Vector3(-width*.36+(i%4)*width*.24,.28,-depth*.25+(i/4)*depth*.48)
		clump(root,p,Vector3(.83,.53,.81),SAGE if i%2 else SAGE.lightened(.035))
		for j in 3:
			var a:=j*TAU/3+i
			leaf(root,p+Vector3(cos(a)*.23,.16,sin(a)*.23),Vector3(.17,.35,.12),SAGE).rotation=Vector3(.3,a,.32)
			clump(root,p+Vector3(cos(a)*.17,.31,sin(a)*.17),Vector3(.16,.10,.16),PINK if i%2 else CREAM)
	clump(root,Vector3(width*.33,.16,depth*.26),Vector3(.54,.33,.46),MINT)
	return root

static func rowboat(parent: Node3D) -> Node3D:
	var root:=group(parent,"WhaleRowboat",Vector3.ZERO)
	var outline: Array[Vector2]=[Vector2(-1.05,-2.3),Vector2(1.05,-2.3),Vector2(1.28,-1.8),Vector2(1.35,-1.15),Vector2(1.35,.9),Vector2(1.18,1.45),Vector2(.83,1.97),Vector2(.40,2.38),Vector2(0,2.6),Vector2(-.40,2.38),Vector2(-.83,1.97),Vector2(-1.18,1.45),Vector2(-1.35,.9),Vector2(-1.35,-1.15),Vector2(-1.28,-1.8)]
	var outer:=SurfaceTool.new();outer.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner:=SurfaceTool.new();inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a: Vector2=outline[i];var b: Vector2=outline[(i+1)%outline.size()]
		var ia:=a-a.normalized()*.115;var ib:=b-b.normalized()*.115
		var a0:=Vector3(a.x*.65,-.04,a.y*.85);var b0:=Vector3(b.x*.65,-.04,b.y*.85)
		var a1:=Vector3(a.x*.94,.28,a.y*.97);var b1:=Vector3(b.x*.94,.28,b.y*.97)
		var a2:=Vector3(a.x,.75,a.y);var b2:=Vector3(b.x,.75,b.y)
		Geo._face(outer,[a0,b0,b1,a1],(a1-a0).cross(b0-a0).normalized())
		Geo._face(outer,[a1,b1,b2,a2],(a2-a1).cross(b1-a1).normalized())
		Geo._face(outer,[Vector3(0,-.04,0),b0,a0],Vector3.DOWN)
		var inner_a:=Vector3(ia.x,.73,ia.y);var inner_b:=Vector3(ib.x,.73,ib.y)
		var floor_a:=Vector3(a.x*.65,.075,a.y*.85);var floor_b:=Vector3(b.x*.65,.075,b.y*.85)
		Geo._face(inner,[inner_a,inner_b,floor_b,floor_a],(floor_a-inner_a).cross(inner_b-inner_a).normalized())
		Geo._face(inner,[Vector3(0,.075,0),floor_a,floor_b],Vector3.UP)
		Geo._face(inner,[Vector3(a.x,.75,a.y),Vector3(b.x,.75,b.y),Vector3(ib.x,.73,ib.y),Vector3(ia.x,.73,ia.y)],Vector3.UP)
		rod(root,Vector3(a.x,.78,a.y),Vector3(b.x,.78,b.y),.063,CREAM)
	mesh_node(root,outer.commit(),Vector3.ZERO,BLUE,"OuterHull")
	mesh_node(root,inner.commit(),Vector3.ZERO,CREAM,"InnerHullAndGunwale")
	for i in 7:box(root,Vector3(.23,.075,3.35),Vector3((i-3)*.248,.16,-.1),WOOD)
	for z in [-1.72,-.90,-.10,.74,1.65]:
		var width:=.85 if z>1.5 else 1.24
		box(root,Vector3(width*1.25,.075,.085),Vector3(0,.22,z),WOOD)
		for side in [-1.0,1.0]:rod(root,Vector3(side*width*.625,.22,z),Vector3(side*width,.65,z),.038,WOOD)
	for z in [-1.32,.42]:
		box(root,Vector3(2.35,.13,.47),Vector3(0,.58,z),CREAM)
		for side in [-1.0,1.0]:box(root,Vector3(.10,.31,.31),Vector3(side*.79,.365,z),WOOD)
	for side in [-1.0,1.0]:
		rod(root,Vector3(side*1.16,.91,-.3),Vector3(side*2.3,.63,1.45),.055,WOOD)
		var shape:=prism(PackedVector2Array([Vector2(-.055,-.43),Vector2(.055,-.43),Vector2(.16,-.21),Vector2(.16,.25),Vector2(.10,.39),Vector2(-.10,.39),Vector2(-.16,.25),Vector2(-.16,-.21)]),.065)
		var paddle:=mesh_node(root,shape,Vector3(side*2.2,.63,1.4),BLUE,"ShapedPaddle")
		paddle.rotation=Vector3(PI*.5,side*.47,0)
		mesh_node(root,ring_mesh(.054,.091,.035),Vector3(side*1.22,.80,-.29),TEAL,"Oarlock").rotation.x=PI*.5
		var eye:=group(root,"MooringEyeLeft" if side<0 else "MooringEyeRight",Vector3(side*1.03,.77,-1.86))
		mesh_node(eye,ring_mesh(.045,.078,.04),Vector3.ZERO,CREAM,"MooringEye")
	var buoy:=TorusMesh.new();buoy.inner_radius=.22;buoy.outer_radius=.34;buoy.rings=24;buoy.ring_segments=8
	mesh_node(root,buoy,Vector3(1.30,.45,-.25),CREAM,"Lifebuoy").rotation.z=PI*.5
	root.set_meta("hull_thickness",.115)
	return root

static func dock_post(parent: Node3D) -> Node3D:
	var root:=group(parent,"CappedDockPost",Vector3.ZERO)
	Geo.cylinder(root,.18,1.8,Vector3(0,-.28,0),WOOD)
	Geo.cylinder(root,.22,.11,Vector3(0,.64,0),CREAM)
	box(root,Vector3(.12,.08,.48),Vector3(0,.59,0),TEAL)
	for y in [.12,.19,.26]:
		var rope:=TorusMesh.new();rope.inner_radius=.185;rope.outer_radius=.22;rope.rings=16;rope.ring_segments=6
		mesh_node(root,rope,Vector3(0,y,0),Color("b99865"),"RopeCoil")
	return root

static func mooring(parent: Node3D) -> MultiMeshInstance3D:
	var root:=MultiMeshInstance3D.new();root.name="BoatMooringLine";root.set_meta("home_dynamic",true)
	var cylinder:=CylinderMesh.new();cylinder.top_radius=.028;cylinder.bottom_radius=.028;cylinder.height=1.;cylinder.radial_segments=6
	var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.mesh=cylinder;instances.instance_count=12
	root.multimesh=instances;root.material_override=material(Color("c1a47b"));parent.add_child(root)
	return root

static func update_mooring(line: MultiMeshInstance3D, start: Vector3, end: Vector3) -> void:
	for i in 12:
		var ta:=i/12.0;var tb:=(i+1)/12.0
		var a:=start.lerp(end,ta)-Vector3.UP*sin(ta*PI)*.23
		var b:=start.lerp(end,tb)-Vector3.UP*sin(tb*PI)*.23
		var axis: Vector3=(b-a).normalized()
		var guide:=Vector3.RIGHT if absf(axis.x)<.9 else Vector3.FORWARD
		var right:=axis.cross(guide).normalized()
		line.multimesh.set_instance_transform(i,Transform3D(Basis(right,axis*a.distance_to(b),right.cross(axis).normalized()),(a+b)*.5))

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
