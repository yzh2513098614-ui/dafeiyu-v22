extends RefCounted
## A fully modelled blue-whale home. Coordinates are metres; the three floors
## share a real grounded player and open stairwells rather than teleport zones.
const Geo=preload("res://district/story_geometry.gd")
const Harbor=preload("res://district/harbor_terraces.gd")
const Shape=preload("res://district/space_shape.gd")
const Action=preload("res://district/whale_home_action.gd")
const SEA=preload("res://assets/whale_home/coastal_water.gdshader")
const FABRIC=preload("res://assets/whale_home/fabric.gdshader")
const MOTIF=preload("res://assets/whale_home/motif.gdshader")
const Pastel=preload("res://assets/whale_home/pastel_props.gd")
const Coastal=preload("res://assets/whale_home/coastal_props.gd")
const Ground=preload("res://assets/whale_home/garden_ground.gd")
const Furniture=preload("res://assets/whale_home/furniture_finishes.gd")
const PORCH=preload("res://models/whale_home/porch_arch.tscn")
const WINDOW=preload("res://models/whale_home/round_window.tscn")
const ROOF_TILE=preload("res://models/whale_home/curved_roof_tile.tscn")
const TALL_TREE=preload("res://models/whale_home/tree_tall_green.tscn")
const LOW_TREE=preload("res://models/whale_home/tree_low_green.tscn")
const SAKURA_TREE=preload("res://models/whale_home/tree_sakura.tscn")
const BENCH=preload("res://models/whale_home/garden_bench.tscn")
const FENCE_PANEL=preload("res://models/whale_home/picket_panel.tscn")
const PERGOLA=preload("res://models/whale_home/garden_pergola.tscn")
const FLOWER_BED=preload("res://models/whale_home/flower_bed.tscn")
const PLANTER=preload("res://models/whale_home/flower_planter.tscn")
const DOCK_POST=preload("res://models/whale_home/dock_post.tscn")
const ROWBOAT=preload("res://models/whale_home/whale_rowboat.tscn")
const HEIGHT := 5.2
const FLOOR_RECTS = [Rect2(-28,-32,56,40),Rect2(-28,-34,56,36),Rect2(-28,-38,56,36)]
const ISLAND_RECT = Rect2(-42,-45,84,70)
const SIDE_GARDEN_OFFSET := 14.0
const DOCK_RECTS = [Rect2(-3,24,6,12),Rect2(-22,24,5.5,10),Rect2(-22,28,19,3.0)]
const WHITE=Color("f3eedb")
const BLUE=Color("639cdb")
const DEEP=Color("3a71b5")
const LIGHT=Color("b3d9ef")
const WOOD=Color("c7af7d")
const GOLD=Color("ebc574")
const GREEN=Color("a6c080")
const MINT=Color("91b9ac")
const TEAL=Color("648e84")
const GRASS=Color("cddea6")
const SAKURA=Color("f3c9d4")
const STONE=Color("e6e4d1")
var game
var level: Node3D
var floors: Array[Node3D] = []
var lights: Array[OmniLight3D] = []
var zones: Array = []
var glass: StandardMaterial3D
var cloth_cache: Dictionary = {}
var sphere_mesh: SphereMesh
var plant_rim_mesh: TorusMesh
var star_mesh: ArrayMesh
var blade_cache: Dictionary = {}
var furniture_count := 0
var detail_count := 0
var batched_surfaces := 0
var facility_nodes: Array[Node3D] = []
var indexed_cache: Dictionary = {}

func _group(parent: Node3D, label: String, point: Vector3=Vector3.ZERO) -> Node3D:
	var node:=Node3D.new();node.name=label;node.position=point;parent.add_child(node);return node

func _furniture(parent: Node3D, label: String, point: Vector3, yaw: float=0.0) -> Node3D:
	var node: Node3D=_group(parent,label,point);node.rotation_degrees.y=yaw
	node.set_meta("home_furniture",label);furniture_count+=1;return node

func _model(parent: Node3D, scene: PackedScene, point: Vector3, furniture: bool=false) -> Node3D:
	var node: Node3D=scene.instantiate();node.position=point;parent.add_child(node)
	if furniture:node.set_meta("home_furniture",String(node.name));furniture_count+=1
	return node

func _box(parent: Node3D, size: Vector3, point: Vector3, color: Color=WHITE, finish: int=0, bevel: float=.035) -> MeshInstance3D:
	var node: MeshInstance3D=Geo.box(parent,size,point,color,finish,bevel)
	# Thin paving, lawn overlays and floorboards receive shadows without casting
	# a second almost-coplanar shadow onto the structural floor underneath.
	var floor_offset: float=fposmod((parent.global_transform*point).y,HEIGHT)
	if size.y<.12 and size.x>.2 and size.z>.2 and floor_offset<.15:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _finish_box(parent: Node3D, size: Vector3, point: Vector3, profile: String, part: String="body", bevel: float=.035) -> MeshInstance3D:
	var node := _box(parent,size,point,WHITE,0,bevel)
	Furniture.apply(node,size,bevel,profile,part)
	return node

func _sphere(parent: Node3D, point: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	if not sphere_mesh:
		sphere_mesh=SphereMesh.new();sphere_mesh.radius=.5;sphere_mesh.height=1.0;sphere_mesh.radial_segments=24;sphere_mesh.rings=12
	var mesh:=MeshInstance3D.new();mesh.mesh=sphere_mesh;mesh.material_override=Geo.material(color)
	mesh.position=point;mesh.scale=size;parent.add_child(mesh);return mesh

func _cloth(node: MeshInstance3D, color: Color, pattern: int=0) -> void:
	var key: String=str(color)+str(pattern)
	if not cloth_cache.has(key):
		var material:=ShaderMaterial.new();material.shader=FABRIC;material.set_shader_parameter("fabric_color",color);material.set_shader_parameter("pattern",pattern);cloth_cache[key]=material
	node.material_override=cloth_cache[key]

func _coll(parent: Node3D, size: Vector3, point: Vector3) -> void:game._collision(parent,size,point)

func _art(parent: Node3D, point: Vector3, size: Vector2, rug: bool=false) -> void:
	var floor_height: float=floorf(point.y/HEIGHT)*HEIGHT
	var frame_size: Vector3=Vector3(size.x+.18,.010,size.y+.18) if rug else Vector3(size.x+.18,size.y+.18,.10)
	var frame_point: Vector3=Vector3(point.x,floor_height+.033,point.z) if rug else point
	_box(parent,frame_size,frame_point,WOOD,1,.005 if rug else .025)
	var image:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=size;image.mesh=quad
	var material:=ShaderMaterial.new();material.shader=MOTIF;material.set_shader_parameter("motif",1 if rug else 0)
	image.material_override=material;image.position=point+Vector3(0,0,.058);image.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(image)
	if rug:
		image.rotation.x=-PI*.5;image.position=Vector3(point.x,floor_height+.040,point.z)
		var rugs: Array=level.get_meta("rug_surfaces",[]);rugs.append(image.position);level.set_meta("rug_surfaces",rugs)

func _star(parent: Node3D, point: Vector3, size: float=.4) -> void:
	if not star_mesh:
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var outline: Array[Vector2] = []
		for i in 10:
			var a: float=PI*.5+i*TAU/10.;outline.append(Vector2(cos(a),sin(a))*(.5 if i%2==0 else .235))
		for i in 10:
			var a: Vector2=outline[i];var b: Vector2=outline[(i+1)%10]
			Geo._face(tool,[Vector3(0,0,.06),Vector3(a.x,a.y,.06),Vector3(b.x,b.y,.06)],Vector3.BACK)
			Geo._face(tool,[Vector3(0,0,-.06),Vector3(b.x,b.y,-.06),Vector3(a.x,a.y,-.06)],Vector3.FORWARD)
			Geo._face(tool,[Vector3(a.x,a.y,-.06),Vector3(b.x,b.y,-.06),Vector3(b.x,b.y,.06),Vector3(a.x,a.y,.06)],Vector3(a.x+b.x,a.y+b.y,0).normalized())
		star_mesh=tool.commit()
	var node:=MeshInstance3D.new();node.mesh=star_mesh;node.position=point;node.scale=Vector3.ONE*size;node.material_override=Geo.material(GOLD);parent.add_child(node)

func _blade(outlines: Array, thickness: float, axis: Vector3) -> ArrayMesh:
	var key: String=str(outlines)+":"+str(thickness)+":"+str(axis)
	if blade_cache.has(key):return blade_cache[key]
	var U: Vector3; var V: Vector3
	if axis.is_equal_approx(Vector3.UP):
		U=Vector3.RIGHT; V=Vector3.BACK
	else:
		U=Vector3.BACK; V=Vector3.UP
	var half: float=thickness*.5
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for outline in outlines:
		var centroid:=Vector2.ZERO
		for point in outline:centroid+=point
		centroid/=float(outline.size())
		var top: Array[Vector3]=[]; var bottom: Array[Vector3]=[]
		for point in outline:
			var flat: Vector3=U*point.x+V*point.y
			top.append(flat+axis*half); bottom.append(flat-axis*half)
		Geo._face(tool,top,axis)
		Geo._face(tool,bottom,-axis)
		for i in outline.size():
			var j: int=(i+1)%outline.size()
			var edge: Vector3=(U*(outline[j].x-outline[i].x)+V*(outline[j].y-outline[i].y)).normalized()
			var normal: Vector3=edge.cross(axis).normalized()
			var mid: Vector3=(top[i]+top[j]+bottom[j]+bottom[i])*.25
			if normal.dot(mid-(U*centroid.x+V*centroid.y))<0:normal=-normal
			Geo._face(tool,[top[i],top[j],bottom[j],bottom[i]],normal)
	var mesh: ArrayMesh=tool.commit();blade_cache[key]=mesh;return mesh

func _whale(parent: Node3D, point: Vector3, scale_value: float=1.0, yaw: float=0.0, color: Color=BLUE) -> Node3D:
	var root: Node3D=_group(parent,"BlueWhale",point);root.scale=Vector3.ONE*scale_value;root.rotation_degrees.y=yaw
	_sphere(root,Vector3(0,.72,.05),Vector3(1.50,1.26,1.90),color)
	_sphere(root,Vector3(0,.42,.45),Vector3(1.10,.55,1.35),WHITE)
	var stock: MeshInstance3D=Geo.cylinder(root,.30,.55,Vector3(0,.80,-1.02),color,.11);stock.rotation.x=PI*.5
	var pectorals: Array=[]
	for side in [-1.0,1.0]:
		pectoral_outline(side,pectorals)
	var fins:=MeshInstance3D.new();fins.mesh=_blade(pectorals,.07,Vector3.UP)
	fins.material_override=Geo.material(color);fins.position=Vector3(0,.40,.25);root.add_child(fins)
	var flukes:=MeshInstance3D.new();flukes.mesh=_blade([fluke_outline()],.07,Vector3.UP)
	flukes.material_override=Geo.material(color);flukes.position=Vector3(0,.95,-1.02);root.add_child(flukes)
	var dorsal:=MeshInstance3D.new();dorsal.mesh=_blade([dorsal_outline()],.07,Vector3.RIGHT)
	dorsal.material_override=Geo.material(color);dorsal.position=Vector3(0,1.26,-.28);root.add_child(dorsal)
	for side in [-1.0,1.0]:
		_sphere(root,Vector3(side*.50,.86,.78),Vector3(.13,.15,.075),Color("243e61"))
		_sphere(root,Vector3(side*.51,.89,.82),Vector3(.044,.044,.028),Color.WHITE)
		_sphere(root,Vector3(side*.58,.64,.80),Vector3(.22,.125,.037),Color("f5aeb8"))
	return root

func pectoral_outline(side: float, into: Array) -> void:
	var outline: Array[Vector2]=[]
	for point in [Vector2(.05,.10),Vector2(.50,.02),Vector2(.88,-.22),Vector2(.78,-.40),Vector2(.38,-.34),Vector2(.10,-.16)]:
		outline.append(Vector2(point.x*side,point.y))
	into.append(outline)

func fluke_outline() -> Array[Vector2]:
	return [Vector2(-.09,.05),Vector2(-.42,-.12),Vector2(-.62,-.38),Vector2(-.24,-.30),Vector2(0,-.22),Vector2(.24,-.30),Vector2(.62,-.38),Vector2(.42,-.12),Vector2(.09,.05)]

func dorsal_outline() -> Array[Vector2]:
	return [Vector2(.16,0),Vector2(.06,.16),Vector2(-.10,.26),Vector2(-.22,.18),Vector2(-.20,.04)]

func _flower(parent: Node3D, point: Vector3, color: Color=Color("f8c6d1"), size: float=.20) -> void:
	for i in 5:
		var a: float=i*TAU/5.;_sphere(parent,point+Vector3(cos(a)*size*.40,0,sin(a)*size*.40),Vector3(size*.65,size*.22,size*.65),color)
	_sphere(parent,point+Vector3.UP*size*.1,Vector3.ONE*size*.35,GOLD)

func _plant(parent: Node3D, point: Vector3, size: float=1.0, flowers: bool=false) -> void:
	var root: Node3D=_furniture(parent,"FlowerPot" if flowers else "HousePlant",point);root.scale=Vector3.ONE*size
	Geo.cylinder(root,.27,.46,Vector3(0,.23,0),WHITE,.34)
	# A solid rim disk and the soil used to share y=.5325, causing the blue
	# triangular flicker. Use a hollow lip with the soil below its opening.
	if not plant_rim_mesh:
		plant_rim_mesh=TorusMesh.new();plant_rim_mesh.inner_radius=.30;plant_rim_mesh.outer_radius=.36;plant_rim_mesh.rings=20;plant_rim_mesh.ring_segments=8
	var rim:=MeshInstance3D.new();rim.mesh=plant_rim_mesh;rim.material_override=Geo.material(LIGHT);rim.position=Vector3(0,.49,0);root.add_child(rim)
	Geo.cylinder(root,.292,.016,Vector3(0,.493,0),Color("785c42"))
	for i in 7:
		var a: float=i*TAU/7.;var tip:=Vector3(cos(a)*.35,.88+float(i%3)*.16,sin(a)*.35)
		Geo.rod(root,Vector3(0,.5,0),tip,.018,GREEN)
		var leaf: MeshInstance3D=Pastel.leaf(root,tip,Vector3(.25,.51,.10),GREEN if i%2 else Color("8dba7e"));leaf.rotation=Vector3(.4,a,.45)
		if flowers:_flower(root,tip+Vector3.UP*.14,Color("fff5df") if i%2 else Color("efb3c6"),.23)
	_star(root,Vector3(0,.24,.283),.16)

func _vines(parent: Node3D, a: Vector3, b: Vector3, sag: float=.8) -> void:
	var last: Vector3=a
	for i in 20:
		var t: float=(i+1)/20.;var point: Vector3=a.lerp(b,t)-Vector3.UP*sin(t*PI)*sag
		Geo.rod(parent,last,point,.022,GREEN);last=point
		for side in [-1.0,1.0]:
			var leaf: MeshInstance3D=_sphere(parent,point+Vector3(side*.12,-.04,0),Vector3(.32,.14,.19),GREEN if i%2 else Color("8db570"));leaf.rotation.z=side*.4
		if i%4==0:_flower(parent,point+Vector3(0,.04,.14),Color("fff4df") if i%8==0 else Color("efb4c7"),.27)

func _cup(parent: Node3D, point: Vector3, color: Color=WHITE) -> void:
	Geo.cylinder(parent,.17,.025,point,color)
	Geo.cylinder(parent,.10,.17,point+Vector3.UP*.10,color,.12)
	Geo.cylinder(parent,.10,.008,point+Vector3.UP*.19,Color("8c6248"))
	var mesh:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.04;torus.outer_radius=.075;torus.rings=12;torus.ring_segments=8
	mesh.mesh=torus;mesh.material_override=Geo.material(color);mesh.position=point+Vector3(.13,.10,0);mesh.rotation.x=PI*.5;parent.add_child(mesh)

func _books(parent: Node3D, point: Vector3, count: int=7) -> void:
	var colors: Array[Color]=[BLUE,LIGHT,WHITE,Color("f0c58b"),Color("e9b1bd"),Color("91b69b")]
	for i in count:
		var h: float=.38+(i%3)*.07
		_box(parent,Vector3(.14,h,.35),point+Vector3(i*.16,h*.5,0),colors[i%6],0,.009)
		_box(parent,Vector3(.10,.025,.012),point+Vector3(i*.16,h*.75,.18),GOLD,0,.002)
		_box(parent,Vector3(.10,.015,.013),point+Vector3(i*.16,h*.21,.18),WHITE,0,.002)

func _fixture(parent: Node3D, point: Vector3, hanging: bool=true, star: bool=false) -> void:
	var root: Node3D=_group(parent,"StarLantern" if star else "WarmLamp",point)
	if hanging:Geo.rod(root,Vector3(0,.4,0),Vector3(0,1.35,0),.018,GOLD)
	else:
		Geo.cylinder(root,.30,.08,Vector3(0,.04,0),GOLD)
		Geo.cylinder(root,.055,.64,Vector3(0,.36,0),GOLD)
	var bulb: MeshInstance3D=_sphere(root,Vector3(0,.72 if not hanging else 0,0),Vector3(.6,.44,.6),Color("fff0bd"))
	var glow:=StandardMaterial3D.new();glow.albedo_color=Color("fff0bd");glow.emission_enabled=true;glow.emission=Color("ffd58e");glow.emission_energy_multiplier=.55;bulb.material_override=glow
	if not hanging:Geo.cylinder(root,.45,.50,Vector3(0,.81,0),WHITE,.20)
	if star:_star(root,Vector3(0,0,.34),.82)
	var lamp:=OmniLight3D.new();lamp.position=Vector3(0,.6 if not hanging else -.1,0);lamp.omni_range=6.0;lamp.light_color=Color("ffe8b9");lamp.light_energy=.30;lamp.shadow_enabled=false;lamp.set_meta("home_energy",.85);lamp.set_meta("fixture_weight",.5);lamp.set_meta("harbor_lamp",true)
	if star:lamp.set_meta("star_string",true)
	root.add_child(lamp);lights.append(lamp)

func _slab(parent: Node3D, rect: Rect2, height: float) -> void:Harbor._slab(level,parent,rect,height)

func _deck(parent: Node3D, rect: Rect2, height: float) -> void:
	var rows: int=ceili(rect.size.y/.72)
	for row in rows:
		var depth: float=minf(.715,rect.end.y-(rect.position.y+row*.72))
		if depth<=0:continue
		var columns: int=ceili(rect.size.x/3.5)
		for column in columns:
			var width: float=minf(3.49,rect.end.x-(rect.position.x+column*3.5))
			_box(parent,Vector3(width,.055,depth),Vector3(rect.position.x+column*3.5+width*.5,height+.001,rect.position.y+row*.72+depth*.5),WOOD.lightened(float((row+column)%4)*.025),1,.009)

func _rail(parent: Node3D, a: Vector3, b: Vector3, glass_panel: bool=true) -> void:
	var length: float=a.distance_to(b);var root: Node3D=_group(parent,"BalconyRailing",(a+b)*.5)
	root.rotation.y=-atan2(b.z-a.z,b.x-a.x)
	for y in [.15,1.16]:_box(root,Vector3(length,.10,.16),Vector3(0,y,0),WHITE,0,.025)
	var count: int=maxi(1,ceili(length/1.65))
	for i in count+1:
		var x: float=-length*.5+i*length/count
		_box(root,Vector3(.16,1.23,.16),Vector3(x,.615,0),WHITE,0,.028)
		_box(root,Vector3(.23,.14,.24),Vector3(x,.10,0),WHITE,0,.018)
		_box(root,Vector3(.21,.07,.22),Vector3(x,1.15,0),WHITE,0,.015)
		_sphere(root,Vector3(x,1.28,0),Vector3.ONE*.23,WHITE)
		if glass_panel and i<count:
			var pane: MeshInstance3D=_box(root,Vector3(length/count-.22,.84,.018),Vector3(x+length/count*.5,.65,0),LIGHT,0,.005);pane.material_override=glass;pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			for y in [.32,.95]:
				for edge in [-1.0,1.0]:_box(root,Vector3(.06,.07,.04),Vector3(x+length/count*.5+edge*(length/count*.5-.14),y,.018),TEAL,0,.006)
	for x in [-length*.5,length*.5]:_box(root,Vector3(.075,.13,.19),Vector3(x,1.16,0),WHITE,0,.015)
	_coll(root,Vector3(length+.10,1.39,.25),Vector3(0,.695,0))

func _curved_balcony(parent: Node3D, left: float, right: float, front: float, height: float, zone_name: String) -> void:
	var polygon: PackedVector2Array=PackedVector2Array([Vector2(left,front-.03)])
	for i in 25:
		var t: float=i/24.;polygon.append(Vector2(lerpf(left,right,t),front+sin(t*PI)*3.5))
	polygon.append(Vector2(right,front-.03))
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: PackedInt32Array=Geometry2D.triangulate_polygon(polygon)
	for i in range(0,indices.size(),3):
		var points: Array[Vector3]=[]
		for j in 3:points.append(Vector3(polygon[indices[i+j]].x,height+.026,polygon[indices[i+j]].y))
		Geo._face(tool,points,Vector3.UP)
	for i in range(1,polygon.size()-2):
		var a:=Vector3(polygon[i].x,height,polygon[i].y);var b:=Vector3(polygon[i+1].x,height,polygon[i+1].y)
		Geo._face(tool,[a,b,b-Vector3.UP*.27,a-Vector3.UP*.27],Vector3(0,0,1))
		Geo.rod(parent,a-Vector3.UP*.20,b-Vector3.UP*.20,.04,TEAL)
		_rail(parent,a,b)
	var mesh:=MeshInstance3D.new();mesh.name="CurvedBalconyDeck";mesh.mesh=tool.commit();mesh.material_override=Geo.material(WOOD,1);parent.add_child(mesh)
	var body:=StaticBody3D.new();body.name="CurvedWalkableBalcony";body.collision_layer=10;body.collision_mask=4
	var hit:=CollisionShape3D.new();var convex:=ConvexPolygonShape3D.new();var vertices:=PackedVector3Array()
	for p in polygon:vertices.append(Vector3(p.x,height+.025,p.y));vertices.append(Vector3(p.x,height-.25,p.y))
	convex.points=vertices;hit.shape=convex;body.add_child(hit);parent.add_child(body);body.set_meta("walkable_top",height+.025)
	var slabs: Array=level.get_meta("walkable_slabs");slabs.append(body);level.set_meta("walkable_slabs",slabs)
	var rect:=Rect2(left,front-.05,right-left,3.6)
	zones.append({"id":zone_name,"name":("2F" if height<HEIGHT*2 else "3F")+" · 弧形海景露台","rect":rect,"polygon":polygon,"height":height,"center":Vector3(rect.get_center().x,height,rect.get_center().y),"paths":[],"door_clear":[]})

func _wall(parent: Node3D, rect: Rect2, height: float, partition: bool=false) -> void:
	var back: Node3D=_group(parent,"BluePaneledBackWall",Vector3(rect.get_center().x,height,rect.position.y))
	_box(back,Vector3(rect.size.x,3.8,.24),Vector3(0,1.90,0),WHITE,0,.025)
	for i in ceili(rect.size.x/.70):
		var x: float=-rect.size.x*.5+(i+.5)*.70
		_box(back,Vector3(.64,1.20,.038),Vector3(x,.65,.145),MINT.lightened(.22),0,.02)
		_box(back,Vector3(.028,2.55,.02),Vector3(x+ .33,2.40,.14),Color("e9dfc7"),0,.004)
	_box(back,Vector3(rect.size.x,.11,.32),Vector3(0,1.31,.03),TEAL,0,.02)
	_box(back,Vector3(rect.size.x,.15,.34),Vector3(0,3.86,0),WOOD,1,.025)
	_box(back,Vector3(rect.size.x+.08,.11,.44),Vector3(0,3.97,.015),WHITE,0,.022)
	_box(back,Vector3(rect.size.x+.16,.08,.51),Vector3(0,4.055,.025),MINT,0,.015)
	_coll(back,Vector3(rect.size.x,3.95,.28),Vector3(0,1.95,0))
	if partition:return
	for side in [-1.0,1.0]:
		var side_wall: Node3D=_group(parent,"LowSideWall",Vector3(rect.position.x if side<0 else rect.end.x,height,rect.get_center().y))
		_box(side_wall,Vector3(.23,1.10,rect.size.y),Vector3(0,.55,0),WHITE,0,.024)
		_box(side_wall,Vector3(.32,.11,rect.size.y),Vector3(0,1.13,0),TEAL,0,.025)
		_coll(side_wall,Vector3(.25,1.2,rect.size.y),Vector3(0,.6,0))
	for x in [rect.position.x+.24,rect.end.x-.24]:
		for z in [rect.position.y+.2,rect.end.y-.18]:
			_box(parent,Vector3(.34,4.58,.34),Vector3(x,height+2.28,z),WHITE,0,.05)
			_box(parent,Vector3(.54,.18,.54),Vector3(x,height+.18,z),MINT,0,.03)
			_box(parent,Vector3(.43,.10,.43),Vector3(x,height+.32,z),WHITE,0,.022)
			_box(parent,Vector3(.45,.12,.45),Vector3(x,height+4.34,z),MINT,0,.022)
			_box(parent,Vector3(.56,.14,.56),Vector3(x,height+4.49,z),WHITE,0,.028)
			_coll(parent,Vector3(.36,4.6,.36),Vector3(x,height+2.28,z))
			_coll(parent,Vector3(.54,.30,.54),Vector3(x,height+.15,z))

func _porthole(parent: Node3D, point: Vector3, radius: float=1.15) -> void:
	var frame: Node3D=_model(parent,WINDOW,point);frame.scale=Vector3(radius,radius,1)
	for side in [-1.0,1.0]:
		var curtain: Node3D=_group(parent,"PleatedCurtain",point+Vector3(side*(radius+.27),.05,.15))
		for i in 5:
			var drape: MeshInstance3D=_box(curtain,Vector3(.16,radius*2.0,.20),Vector3((i-2)*.13,0,sin(i)*.04),BLUE,0,.055);_cloth(drape,Color("9fcbed"),1)
		Geo.rod(curtain,Vector3(-.36,-.35,.13),Vector3(.36,-.35,.13),.03,GOLD)
	Geo.rod(parent,point+Vector3(-radius-.66,radius+.25,.12),point+Vector3(radius+.66,radius+.25,.12),.025,GOLD)

func _cabinet(parent: Node3D, point: Vector3, width: float=1.75, height: float=1.06, profile: String="cabinet") -> Node3D:
	var root: Node3D=_furniture(parent,"KitchenCabinet",point)
	root.set_meta("furniture_finish",profile)
	_finish_box(root,Vector3(width,height,.92),Vector3(0,height*.5,0),profile,"body",.04)
	_finish_box(root,Vector3(width+.10,.10,1.04),Vector3(0,height+.04,0),profile,"top",.026)
	for x in [-width*.245,width*.245]:
		_finish_box(root,Vector3(width*.45,height-.18,.055),Vector3(x,height*.51,.49),profile,"back",.025)
		_finish_box(root,Vector3(width*.38,height-.30,.025),Vector3(x,height*.51,.532),profile,"body",.016)
		Geo.rod(root,Vector3(x-.13,height*.78,.565),Vector3(x+.13,height*.78,.565),.025,GOLD)
	_coll(root,Vector3(width,height+.10,1.04),Vector3(0,height*.5,0));return root

func _chair(parent: Node3D, point: Vector3, yaw: float=0.0, stool: bool=false) -> void:
	var root: Node3D=_furniture(parent,"DiningStool" if stool else "BlueDiningChair",point,yaw)
	for x in [-.28,.28]:
		for z in [-.27,.27]:Geo.rod(root,Vector3(x,.04,z),Vector3(x*.85,.65,z*.85),.038,WOOD)
	var seat: MeshInstance3D=_box(root,Vector3(.83,.16,.77),Vector3(0,.67,0),LIGHT,0,.07);_cloth(seat,LIGHT)
	if not stool:
		for x in [-.32,.32]:Geo.rod(root,Vector3(x,.68,-.31),Vector3(x,1.22,-.32),.037,WOOD)
		var back: MeshInstance3D=_box(root,Vector3(.80,.54,.12),Vector3(0,1.06,-.34),BLUE,0,.065);_cloth(back,BLUE)
		_star(root,Vector3(0,1.10,-.26),.27)
	_coll(root,Vector3(.86,.9,.83),Vector3(0,.45,0))

func _table(parent: Node3D, point: Vector3, width: float=3.8, depth: float=2.3, height: float=1.05, profile: String="ash_table") -> Node3D:
	var root: Node3D=_furniture(parent,"OakDiningTable",point)
	root.set_meta("furniture_finish",profile)
	for x in [-width*.38,width*.38]:
		for z in [-depth*.34,depth*.34]:_finish_box(root,Vector3(.16,height,.16),Vector3(x,height*.5,z),profile,"body",.025)
	_finish_box(root,Vector3(width,.14,depth),Vector3(0,height,0),profile,"top",.045)
	_finish_box(root,Vector3(width-.22,.20,.14),Vector3(0,height-.22,-depth*.34),profile,"body",.015)
	_coll(root,Vector3(width,height+.12,depth),Vector3(0,height*.5,0));return root

func _shelf(parent: Node3D, point: Vector3, width: float=4.4, height: float=2.6, profile: String="bookcase") -> Node3D:
	var root: Node3D=_furniture(parent,"DisplayBookcase",point)
	root.set_meta("furniture_finish",profile)
	_finish_box(root,Vector3(width,height,.12),Vector3(0,height*.5,-.40),profile,"back",.02)
	for x in [-width*.5,0,width*.5]:_finish_box(root,Vector3(.12,height,.94),Vector3(x,height*.5,0),profile,"body",.02)
	for row in 4:
		var y: float=.12+row*(height-.16)/3.
		_finish_box(root,Vector3(width+.15,.095,1.0),Vector3(0,y,0),profile,"top",.016)
		if row<3:
			_books(root,Vector3(-width*.5+.24,y+.06,.08),7)
			_whale(root,Vector3(.65,y+.06,.02),.28)
			_cup(root,Vector3(width*.35,y+.07,.16),BLUE)
	_plant(root,Vector3(-width*.32,height+.03,0),.55,true)
	_coll(root,Vector3(width+.12,height,1.0),Vector3(0,height*.5,0));return root

func _action(kind: String, id: String, title: String, point: Vector3, height: float) -> Action:
	var node: Action=Action.new();node.name="HomeAction_"+id;node.position=point;node.set_meta("floor_height",height);game.world.add_child(node);node.configure(game,kind,id,title)
	facility_nodes.append(node);return node

func _kitchen(parent: Node3D) -> void:
	for i in 7:
		var root: Node3D=_cabinet(parent,Vector3(-8.2+i*1.80,0,-10.90))
		if i==2:
			_box(root,Vector3(1.30,.07,.65),Vector3(0,1.16,0),Color("a7c8d3"),2,.045)
			_box(root,Vector3(.94,.05,.46),Vector3(0,1.19,0),Color("658b9b"),0,.04)
			Geo.rod(root,Vector3(.37,1.16,-.26),Vector3(.37,1.68,-.26),.038,GOLD)
			Geo.rod(root,Vector3(.37,1.68,-.26),Vector3(.12,1.68,-.06),.038,GOLD)
		elif i==4:
			_box(root,Vector3(1.40,.05,.77),Vector3(0,1.18,0),DEEP,2,.025)
			for x in [-.36,.36]:
				for z in [-.22,.22]:
					Geo.cylinder(root,.19,.035,Vector3(x,1.23,z),Color("405670"))
					Geo.rod(root,Vector3(x-.20,1.26,z),Vector3(x+.20,1.26,z),.018,GOLD)
			_box(root,Vector3(1.20,.50,.04),Vector3(0,.65,.57),Color("395e85"),0,.026)
			Geo.rod(root,Vector3(-.48,.95,.63),Vector3(.48,.95,.63),.026,GOLD)
		elif i in [0,5]:
			for j in 3:
				Geo.cylinder(root,.11,.25,Vector3(-.40+j*.27,1.25,-.10),WHITE,.09)
				Geo.cylinder(root,.115,.05,Vector3(-.40+j*.27,1.40,-.10),GOLD)
		else:_cup(root,Vector3(.15,1.14,.22),BLUE)
	var cook: Action=_action("cook","breakfast","明档厨房 · 鲸鱼早餐",Vector3(-1,0,-10.9),0)
	var pot: Node3D=_group(cook,"BreakfastPan",Vector3(.10,1.23,.1));Geo.cylinder(pot,.31,.10,Vector3.ZERO,WHITE);Geo.rod(pot,Vector3(.3,.01,0),Vector3(.7,.01,0),.035,WOOD);_sphere(pot,Vector3(0,.07,0),Vector3(.34,.035,.30),WHITE);_sphere(pot,Vector3(.02,.09,.02),Vector3(.13,.035,.13),GOLD);cook.parts.append(pot)
	for x in [-7.2,-3.3,2.2]:
		var shelf: Node3D=_furniture(parent,"KitchenWallShelf",Vector3(x,2.5,-11.55))
		_finish_box(shelf,Vector3(3.1,.12,.75),Vector3.ZERO,"display_shelf","top",.025)
		for j in 4:
			_cup(shelf,Vector3(-1.15+j*.55,.10,.05),WHITE if j%2 else BLUE)
			_star(shelf,Vector3(-1.15+j*.55,.20,.17),.08)
		_plant(shelf,Vector3(1.13,.06,.03),.5,true)
	for i in 7:
		var x: float=-7.5+i*1.45
		Geo.rod(parent,Vector3(x,2.18,-11.65),Vector3(x,1.79,-11.65),.016,GOLD)
		Geo.cylinder(parent,.12,.10,Vector3(x,1.75,-11.6),GOLD).rotation.x=PI*.5
	var fridge: Action=_action("fridge","blue_fridge","蓝鲸双层冰箱",Vector3(-11.9,0,-8.9),0)
	_box(fridge,Vector3(2.1,3.1,1.5),Vector3(0,1.55,0),BLUE,0,.16)
	_box(fridge,Vector3(1.72,2.75,.025),Vector3(0,1.58,.76),Color("eee7d3"),0,.018)
	for y in [.45,1.14,1.84,2.56]:
		_box(fridge,Vector3(1.63,.045,.98),Vector3(0,y,.29),WHITE,0,.014)
		for i in 3:
			Geo.cylinder(fridge,.12,.35,Vector3(-.53+i*.48,y+.2,.59),LIGHT if i%2 else WHITE,.09)
			Geo.cylinder(fridge,.10,.055,Vector3(-.53+i*.48,y+.40,.59),GOLD)
	for spec in [[.96,1.8],[2.52,1.10]]:
		var pivot: Node3D=_group(fridge,"FridgeDoorPivot",Vector3(-1.02,float(spec[0]),.78));fridge.parts.append(pivot)
		_box(pivot,Vector3(2.04,float(spec[1]),.14),Vector3(1.02,0,0),LIGHT,0,.08)
		Geo.rod(pivot,Vector3(1.83,-.27,.13),Vector3(1.83,.27,.13),.035,GOLD)
		_whale(pivot,Vector3(.7,-.1,.08),.19,0,DEEP)
	_coll(fridge,Vector3(2.1,3.15,1.65),Vector3(0,1.55,0));fridge.restore_pose()
	var island: Node3D=_table(parent,Vector3(-5.0,0,-5.0),4.3,2.1,1.17,"desk")
	_finish_box(island,Vector3(3.8,.83,1.52),Vector3(0,.56,0),"cabinet","back",.04)
	for x in [-1.27,0,1.27]:
		_finish_box(island,Vector3(1.12,.65,.05),Vector3(x,.59,.78),"cabinet","body",.025)
		Geo.rod(island,Vector3(x-.12,.81,.85),Vector3(x+.12,.81,.85),.022,GOLD)
	Geo.cylinder(island,.34,.10,Vector3(.4,1.30,.03),WHITE)
	for i in 6:_sphere(island,Vector3(.40+sin(i*2.1)*.20,1.40+float(i%2)*.06,cos(i*2.1)*.20),Vector3(.16,.14,.16),Color("f2bf69") if i%2 else Color("e88c83"))
	_box(island,Vector3(.8,.055,.48),Vector3(-1.12,1.28,0),WOOD,1,.04)
	_box(island,Vector3(.5,.02,.3),Vector3(-1.12,1.325,0),WHITE,0,.02)
	_chair(parent,Vector3(-6.2,0,-3.35),0,true);_chair(parent,Vector3(-3.8,0,-3.35),0,true)
	_fixture(parent,Vector3(-6.1,3.45,-5.0));_fixture(parent,Vector3(-3.6,3.45,-5.0))

func _dining(parent: Node3D) -> void:
	var table: Node3D=_table(parent,Vector3(2.0,0,1.6),4.4,2.55)
	for x in [-1.3,1.3]:
		for z in [-.73,.73]:
			Geo.cylinder(table,.35,.025,Vector3(x,1.14,z),WHITE)
			Geo.cylinder(table,.28,.014,Vector3(x,1.16,z),LIGHT)
			_cup(table,Vector3(x+.37,1.15,z),WHITE)
			Geo.rod(table,Vector3(x-.47,1.15,z-.2),Vector3(x-.47,1.15,z+.2),.012,GOLD)
	_plant(table,Vector3(0,1.13,0),.45,true)
	for x in [.7,3.3]:
		_chair(parent,Vector3(x,0,3.72),0);_chair(parent,Vector3(x,0,-.53),180)
	var tea: Action=_action("tea","dining_tea","鲸鱼茶桌 · 海盐花茶",Vector3(2,0,1.6),0)
	var teapot: Node3D=_group(tea,"Teapot",Vector3(0,1.19,.72));_sphere(teapot,Vector3(0,.16,0),Vector3(.48,.32,.42),BLUE)
	Geo.cylinder(teapot,.11,.04,Vector3(0,.34,0),GOLD);Geo.rod(teapot,Vector3(.20,.16,0),Vector3(.36,.28,0),.06,BLUE);tea.parts.append(teapot)
	_fixture(parent,Vector3(2,3.40,1.6))
	var pantry: Action=_action("cabinet","pantry","餐具收藏柜",Vector3(6.8,0,-9.6),0)
	pantry.set_meta("furniture_finish","cabinet")
	_finish_box(pantry,Vector3(2.8,2.9,1.15),Vector3(0,1.45,0),"cabinet","body",.05)
	for y in [.4,1.15,1.9,2.63]:
		_finish_box(pantry,Vector3(2.58,.065,1.06),Vector3(0,y,.10),"cabinet","back",.012)
		for x in [-.88,-.27,.34,.95]:_cup(pantry,Vector3(x,y+.06,.40),WHITE if x<0 else BLUE)
	var door: Node3D=_group(pantry,"PantryDoor",Vector3(-1.43,1.4,.64));pantry.parts.append(door)
	_finish_box(door,Vector3(2.86,2.78,.10),Vector3(1.43,0,0),"cabinet","back",.05)
	for x in [.75,2.08]:
		_finish_box(door,Vector3(1.10,2.20,.035),Vector3(x,0,.07),"cabinet","body",.028)
		_star(door,Vector3(x,.2,.10),.42)
	Geo.rod(door,Vector3(2.61,-.18,.13),Vector3(2.61,.18,.13),.028,GOLD)
	_coll(pantry,Vector3(2.85,3.0,1.30),Vector3(0,1.48,0));pantry.restore_pose()
	_art(parent,Vector3(5.3,2.25,-11.82),Vector2(1.55,1.35))

func _sofa(parent: Node3D, point: Vector3, width: float=5.0, yaw: float=0.0) -> Node3D:
	var root: Node3D=_furniture(parent,"WhaleCushionSofa",point,yaw)
	for x in [-width*.39,width*.39]:
		for z in [-.45,.45]:Geo.cylinder(root,.075,.26,Vector3(x,.13,z),WOOD)
	_box(root,Vector3(width,.33,1.80),Vector3(0,.42,0),BLUE,0,.15)
	for x in [-width*.28,0,width*.28]:
		var cushion: MeshInstance3D=_box(root,Vector3(width*.30,.31,1.46),Vector3(x,.73,.10),WHITE,0,.15);_cloth(cushion,WHITE)
		var back: MeshInstance3D=_box(root,Vector3(width*.31,1.08,.32),Vector3(x,1.15,-.72),WHITE,0,.12);_cloth(back,WHITE)
	for side in [-1.0,1.0]:_box(root,Vector3(.36,.86,1.78),Vector3(side*(width*.5-.15),.81,0),LIGHT,0,.14)
	for x in [-width*.29,width*.29]:
		var pillow: MeshInstance3D=_box(root,Vector3(.88,.83,.26),Vector3(x,1.17,-.34),BLUE,0,.15);pillow.rotation.z=x*.065;_cloth(pillow,BLUE)
		_star(root,Vector3(x,1.22,-.17),.47)
	_whale(root,Vector3(-.20,.80,.06),.55)
	_coll(root,Vector3(width,1.55,1.85),Vector3(0,.78,0));return root

func _aquarium(parent: Node3D) -> void:
	var root: Node3D=_furniture(parent,"PanoramicAquarium",Vector3(-3.1,HEIGHT,-14.78))
	_finish_box(root,Vector3(6.0,.72,1.75),Vector3(0,.36,0),"cabinet","body",.075)
	for x in [-2.0,0,2.0]:
		_finish_box(root,Vector3(1.84,.52,.06),Vector3(x,.38,.92),"cabinet","back",.02)
		Geo.rod(root,Vector3(x-.13,.50,.98),Vector3(x+.13,.50,.98),.018,GOLD)
	_box(root,Vector3(5.85,2.13,.045),Vector3(0,1.83,-.65),Color("38a8d3"),0,.015)
	for x in [-2.94,2.94]:_box(root,Vector3(.075,2.46,1.6),Vector3(x,1.88,0),WHITE,0,.02)
	for y in [.73,3.07]:_box(root,Vector3(6.04,.075,1.73),Vector3(0,y,0),WHITE,0,.02)
	var pane: MeshInstance3D=_box(root,Vector3(5.85,2.22,.020),Vector3(0,1.90,.86),LIGHT,0,.001);pane.material_override=glass;pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 17:
		var x: float=-2.65+i*.33
		_sphere(root,Vector3(x,.87,0),Vector3(.45,.15,.44),Color("e4d3ab") if i%2 else LIGHT)
		if i%3==0:
			for j in 3:Geo.rod(root,Vector3(x,.90,-.12),Vector3(x+sin(i+j)*.20,1.37+j*.15,-.12),.025,GREEN)
	var whale: Node3D=_whale(root,Vector3(-.5,1.75,-.05),.65);whale.set_meta("home_fish",whale.position);whale.set_meta("home_dynamic",true)
	for i in 10:
		var fish: Node3D=_group(root,"ReefFish",Vector3(-2.2+(i%5)*1.02,1.30+(i/5)*1.03,.32))
		fish.set_meta("home_fish",fish.position);fish.set_meta("home_dynamic",true)
		var color: Color=GOLD if i%3==0 else (WHITE if i%3==1 else Color("ecacbc"))
		_sphere(fish,Vector3.ZERO,Vector3(.40,.20,.15),color)
		_sphere(fish,Vector3(-.23,0,0),Vector3(.18,.27,.055),color)
		_sphere(fish,Vector3(.12,.035,.07),Vector3.ONE*.043,Color("243e61"))
	for i in 8:
		_sphere(root,Vector3(2.65,1.0+i*.22,.37),Vector3.ONE*(.04+(i%3)*.016),Color("bbe5ef"))
	_coll(root,Vector3(6.06,3.16,1.86),Vector3(0,1.58,0))
	_action("aquarium","aquarium_feed","全景水族箱 · 小蓝鲸和珊瑚鱼",Vector3(-3.1,HEIGHT,-13.85),HEIGHT)

func _study(parent: Node3D) -> void:
	var h: float=HEIGHT
	var desk: Node3D=_table(parent,Vector3(6.0,h,-12.8),4.7,1.52,1.06,"desk")
	_finish_box(desk,Vector3(1.1,.89,1.27),Vector3(1.55,.53,0),"cabinet","back",.035)
	for i in 3:
		_finish_box(desk,Vector3(.95,.23,.045),Vector3(1.55,.29+i*.27,.66),"cabinet","body",.02)
		Geo.rod(desk,Vector3(1.43,.32+i*.27,.73),Vector3(1.66,.32+i*.27,.73),.019,GOLD)
	var monitor: Node3D=_group(desk,"WhaleComputer",Vector3(-.14,1.15,-.1))
	_box(monitor,Vector3(.68,.045,.42),Vector3(0,.02,0),WHITE,0,.025)
	_box(monitor,Vector3(.09,.30,.10),Vector3(0,.17,-.09),GOLD,2,.01)
	_box(monitor,Vector3(1.42,.92,.10),Vector3(0,.75,-.09),BLUE,0,.05)
	_art(monitor,Vector3(0,.75,-.015),Vector2(1.26,.77))
	_box(desk,Vector3(.95,.035,.31),Vector3(-.12,1.16,.49),WHITE,0,.025)
	for i in 11:
		for j in 3:_box(desk,Vector3(.057,.010,.059),Vector3(-.51+i*.077,1.185,.41+j*.082),LIGHT,0,.003)
	_cup(desk,Vector3(-1.7,1.15,.36),BLUE);_fixture(desk,Vector3(1.76,1.16,-.33),false)
	_chair(parent,Vector3(5.8,h,-10.3),0)
	_shelf(parent,Vector3(10.8,h,-14.9),4.15,3.4)
	_porthole(parent,Vector3(5.2,h+2.8,-15.78),1.04)
	var root: Node3D=_furniture(parent,"ReadingSideboard",Vector3(5.1,h,-5.9))
	root.set_meta("furniture_finish","cream_cabinet")
	_finish_box(root,Vector3(3.7,.72,.90),Vector3(0,.36,0),"cream_cabinet","body",.07)
	for x in [-1.17,0,1.17]:
		_finish_box(root,Vector3(1.02,.47,.05),Vector3(x,.38,.48),"cream_cabinet","back",.024)
		Geo.rod(root,Vector3(x-.12,.47,.56),Vector3(x+.12,.47,.56),.018,GOLD)
	_books(root,Vector3(-1.50,.77,.03),6);_whale(root,Vector3(1.03,.78,0),.31)
	_coll(root,Vector3(3.7,.8,.92),Vector3(0,.4,0))

func _living(parent: Node3D) -> void:
	_aquarium(parent);_study(parent)
	var h: float=HEIGHT
	_art(parent,Vector3(-2.8,h+.055,-6.0),Vector2(7.7,5.2),true)
	_sofa(parent,Vector3(-3.0,h,-9.4),5.9)
	var table: Node3D=_table(parent,Vector3(-2.8,h,-5.2),3.7,1.7,.60,"tea_table")
	for x in [-1.15,0,1.15]:_cup(table,Vector3(x,.69,0),WHITE)
	Geo.cylinder(table,.35,.05,Vector3(.1,.70,.22),GOLD)
	for i in 5:_sphere(table,Vector3(-.1+i*.105,.75,.22),Vector3(.12,.035,.12),Color("eed296"))
	_box(table,Vector3(.60,.035,.38),Vector3(1.14,.70,-.20),BLUE,0,.005)
	_whale(parent,Vector3(2.5,h,-1.0),.70,28)
	_plant(parent,Vector3(-7.2,h,-10.5),1.0,true)
	_plant(parent,Vector3(7.8,h,-4.5),1.2,true)
	_fixture(parent,Vector3(-6.1,h+3.5,-8.0));_fixture(parent,Vector3(0,h+3.5,-8.0))
	for x in [-4.8,0,4.8]:
		var root: Node3D=_furniture(parent,"BalconyPlanter",Vector3(x,h,1.1))
		_box(root,Vector3(2.0,.42,.64),Vector3(0,.21,0),WHITE,0,.055)
		for i in 4:_plant(root,Vector3(-.70+i*.47,.36,0),.45,true)
		_coll(root,Vector3(2.04,.8,.70),Vector3(0,.4,0))

func _bedroom(parent: Node3D) -> void:
	var h: float=HEIGHT*2
	_art(parent,Vector3(-1.7,h+.055,-10.7),Vector2(8.0,6.7),true)
	var bed: Node3D=_furniture(parent,"WhaleDreamBed",Vector3(-2.6,h,-13.6))
	_box(bed,Vector3(5.2,.43,6.3),Vector3(0,.42,0),WOOD,1,.13)
	for x in [-2.13,2.13]:
		for z in [-2.70,2.70]:_box(bed,Vector3(.22,.55,.22),Vector3(x,.26,z),WHITE,0,.045)
	_box(bed,Vector3(4.95,.54,6.05),Vector3(0,.82,0),WHITE,0,.22)
	var duvet: MeshInstance3D=_box(bed,Vector3(5.04,.32,4.76),Vector3(0,1.11,.65),BLUE,0,.20);_cloth(duvet,BLUE,1)
	var fold: MeshInstance3D=_box(bed,Vector3(5.06,.20,.70),Vector3(0,1.30,-1.44),LIGHT,0,.095);_cloth(fold,LIGHT)
	for x in [-1.28,1.28]:
		var pillow: MeshInstance3D=_box(bed,Vector3(1.80,.34,1.05),Vector3(x,1.23,-2.13),WHITE,0,.18);_cloth(pillow,WHITE)
	_whale(bed,Vector3(0,.42,-2.43),1.72)
	_star(bed,Vector3(-1.68,1.64,-1.65),.73);_star(bed,Vector3(1.40,1.60,-1.6),.60)
	_coll(bed,Vector3(5.28,2.35,6.42),Vector3(0,1.18,0))
	_action("bed","whale_bed","柔软鲸鱼床 · 海景卧室",Vector3(-2.6,h,-9.95),h)
	for x in [-6.4,1.12]:
		# The west stair landing needs a full-width route past the bed.
		var point: Vector3=Vector3(-5.8,h,-18.15) if x<0 else Vector3(x,h,-14.4)
		var nightstand: Node3D=_cabinet(parent,point,1.18,.82,"cream_cabinet")
		_fixture(nightstand,Vector3(0,.89,-.1),false);_cup(nightstand,Vector3(.26,.9,.28))
	_porthole(parent,Vector3(-2.7,h+2.83,-19.8),1.20)
	var dresser: Node3D=_cabinet(parent,Vector3(6.0,h,-18.8),4.2,1.3,"cream_cabinet")
	_art(parent,Vector3(6.0,h+2.7,-19.82),Vector2(2.1,1.8))
	_plant(dresser,Vector3(1.34,1.4,0),.62,true)
	_whale(dresser,Vector3(-.7,1.39,0),.39)
	_shelf(parent,Vector3(11.4,h,-18.8),2.0,3.5)
	for i in 5:
		var x: float=-6.0+i*1.68
		_fixture(parent,Vector3(x,h+3.20,-18.5),true,true)
	_vines(parent,Vector3(-7.5,h+4.05,-19.4),Vector3(2.2,h+4.05,-19.4),.65)

func _telescope(parent: Node3D) -> void:
	var h: float=HEIGHT*2
	var scope: Action=_action("scope","stargazer","观星望远镜 · 灯塔与星空",Vector3(8,h,-10.5),h)
	for i in 3:
		var a: float=i*TAU/3.;Geo.rod(scope,Vector3(cos(a)*.92,.05,sin(a)*.92),Vector3(0,1.55,0),.055,WOOD)
	var axis: Node3D=_group(scope,"TelescopeAxis",Vector3(0,1.73,0));axis.rotation.y=-.2;scope.parts.append(axis)
	var tube: MeshInstance3D=Geo.cylinder(axis,.22,1.86,Vector3(0,.18,0),WHITE);tube.rotation.x=1.1
	for y in [-.83,-.62,.74]:
		var collar: MeshInstance3D=Geo.cylinder(axis,.24,.12,Vector3(0,.18+cos(1.1)*y,sin(1.1)*y),DEEP);collar.rotation.x=1.1
	var lens: MeshInstance3D=Geo.cylinder(axis,.18,.02,Vector3(0,.18+cos(1.1)*.96,sin(1.1)*.96),Color("9bdfe8"));lens.rotation.x=1.1
	Geo.rod(scope,Vector3(-.34,1.56,0),Vector3(.34,1.56,0),.045,GOLD)
	_coll(scope,Vector3(1.8,2.18,1.8),Vector3(0,1.09,0))
	_chair(parent,Vector3(6.1,h,-8.8),28,true)
	var tea: Node3D=_table(parent,Vector3(6.5,h,-5.4),2.0,1.4,.66,"tea_table");_cup(tea,Vector3(-.35,.76,0),BLUE);_books(tea,Vector3(.20,.75,-.05),3)
	_sofa(parent,Vector3(10.8,h,-4.1),2.8,-28)
	_plant(parent,Vector3(12.8,h,-8.0),1.1,true)
	_whale(parent,Vector3(2.8,h,-4.6),.44,15)
	_fixture(parent,Vector3(10.6,h+3.2,-5.2),true,true)
	_action("lamp","star_lights","星星灯串开关",Vector3(11.2,h,-5.8),h)

func _entry_details(parent: Node3D) -> void:
	var bench: Node3D=_furniture(parent,"EntryBenchAndShoeStorage",Vector3(-10.6,0,1.1))
	_box(bench,Vector3(3.8,.63,1.10),Vector3(0,.32,0),WHITE,0,.075)
	var seat: MeshInstance3D=_box(bench,Vector3(3.73,.16,1.09),Vector3(0,.71,0),BLUE,0,.08);_cloth(seat,BLUE,1)
	for x in [-1.23,0,1.23]:
		_box(bench,Vector3(1.08,.39,.055),Vector3(x,.34,.57),LIGHT,0,.018)
		Geo.rod(bench,Vector3(x-.1,.46,.63),Vector3(x+.1,.46,.63),.018,GOLD)
		_sphere(bench,Vector3(x-.18,.09,.80),Vector3(.23,.15,.46),BLUE)
		_sphere(bench,Vector3(x+.15,.09,.80),Vector3(.23,.15,.46),WHITE)
	_coll(bench,Vector3(3.8,.8,1.12),Vector3(0,.4,0))
	var rack: Node3D=_furniture(parent,"BrassCoatTree",Vector3(-12.8,0,3.1))
	Geo.cylinder(rack,.40,.09,Vector3(0,.05,0),WHITE);Geo.rod(rack,Vector3(0,.1,0),Vector3(0,2.50,0),.045,GOLD)
	for i in 4:
		var a: float=i*PI*.5;Geo.rod(rack,Vector3(0,2.15,0),Vector3(cos(a)*.44,2.35,sin(a)*.44),.03,GOLD)
	var coat: MeshInstance3D=_box(rack,Vector3(.59,1.10,.15),Vector3(.3,1.55,0),BLUE,0,.09);_cloth(coat,BLUE)
	Geo.cylinder(rack,.28,.075,Vector3(0,2.60,0),WOOD);Geo.cylinder(rack,.15,.17,Vector3(0,2.71,0),WOOD)
	_coll(rack,Vector3(.80,2.6,.8),Vector3(0,1.3,0))
	var dresser: Node3D=_cabinet(parent,Vector3(-6.2,0,5.7),2.25,.90,"cream_cabinet")
	_plant(dresser,Vector3(.62,1.02,.0),.47,true);_books(dresser,Vector3(-.82,1.02,0),4)
	_whale(dresser,Vector3(.03,.99,.13),.25)
	var baking: Node3D=_table(parent,Vector3(4.1,0,-4.6),3.6,1.7,1.14,"desk")
	_box(baking,Vector3(1.35,.07,.86),Vector3(-.55,1.25,0),WOOD,1,.03)
	for i in 5:_star(baking,Vector3(-1.03+i*.21,1.315,.09),.16)
	Geo.rod(baking,Vector3(.36,1.27,.32),Vector3(1.3,1.27,.32),.075,WOOD)
	Geo.cylinder(baking,.26,.25,Vector3(.55,1.32,-.22),WHITE,.29)
	for i in 3:Geo.cylinder(baking,.12,.25,Vector3(-.80+i*.38,.23,0),LIGHT)
	var laundry: Node3D=_furniture(parent,"WhaleLaundryStation",Vector3(-11.3,0,-3.2))
	_box(laundry,Vector3(1.55,1.53,1.28),Vector3(0,.78,0),LIGHT,0,.12)
	var drum:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.39;ring.outer_radius=.47;ring.rings=32;ring.ring_segments=12
	drum.mesh=ring;drum.material_override=Geo.material(WHITE);drum.position=Vector3(0,.74,.68);drum.rotation.x=PI*.5;laundry.add_child(drum)
	_sphere(laundry,Vector3(0,.73,.67),Vector3(.73,.73,.09),Color("74a9c7"))
	for i in 3:
		var towel: MeshInstance3D=_box(laundry,Vector3(1.15,.10,.70),Vector3(0,1.6+i*.11,0),WHITE if i%2 else BLUE,0,.035);_cloth(towel,WHITE if i%2 else BLUE,1)
	for x in [-.48,-.15,.2]:_sphere(laundry,Vector3(x,1.30,.67),Vector3.ONE*.065,GOLD)
	_coll(laundry,Vector3(1.58,1.90,1.34),Vector3(0,.95,0))

func _bathroom(parent: Node3D) -> void:
	var h: float=HEIGHT*2
	var bath: Node3D=_furniture(parent,"WhaleFootedBath",Vector3(-11.25,h,-18.40))
	for x in [-1.03,1.03]:
		for z in [-.48,.48]:_sphere(bath,Vector3(x,.23,z),Vector3(.22,.40,.22),GOLD)
	_sphere(bath,Vector3(0,.75,0),Vector3(3.40,1.06,1.72),WHITE)
	_sphere(bath,Vector3(0,1.16,0),Vector3(2.77,.19,1.20),Color("87cbdc"))
	for x in [-1.22,1.22]:_box(bath,Vector3(.23,.18,1.20),Vector3(x,1.08,0),WHITE,0,.07)
	Geo.rod(bath,Vector3(1.50,.13,-.15),Vector3(1.50,1.40,-.15),.047,GOLD)
	Geo.rod(bath,Vector3(1.50,1.40,-.15),Vector3(1.15,1.40,-.15),.047,GOLD)
	_whale(bath,Vector3(-.42,1.19,.1),.18)
	_coll(bath,Vector3(3.44,1.3,1.8),Vector3(0,.66,0))
	var vanity: Node3D=_cabinet(parent,Vector3(-7.0,h,-18.7),2.1,1.02)
	_sphere(vanity,Vector3(0,1.20,0),Vector3(1.10,.20,.72),WHITE)
	_sphere(vanity,Vector3(0,1.29,0),Vector3(.78,.045,.50),LIGHT)
	Geo.rod(vanity,Vector3(.3,1.18,-.26),Vector3(.3,1.57,-.26),.033,GOLD)
	Geo.rod(vanity,Vector3(.3,1.57,-.26),Vector3(.02,1.57,-.12),.033,GOLD)
	_porthole(parent,Vector3(-7.0,h+2.75,-19.8),.70)
	for i in 3:
		Geo.cylinder(vanity,.075,.23,Vector3(.65+i*.15,1.29,-.17),BLUE if i%2 else WHITE)
		Geo.cylinder(vanity,.08,.035,Vector3(.65+i*.15,1.425,-.17),GOLD)
	var cabinet: Node3D=_cabinet(parent,Vector3(-6.5,h,-7.1),1.55,2.15)
	for i in 3:
		var towel: MeshInstance3D=_box(cabinet,Vector3(1.25,.10,.60),Vector3(0,2.28+i*.11,0),BLUE if i%2 else WHITE,0,.03);_cloth(towel,BLUE if i%2 else WHITE,1)

func _hobby(parent: Node3D) -> void:
	var h: float=HEIGHT
	var cart: Node3D=_furniture(parent,"WhaleTeaTrolley",Vector3(1.65,h,-9.15))
	for x in [-.53,.53]:
		for z in [-.25,.25]:
			Geo.rod(cart,Vector3(x,.12,z),Vector3(x,1.05,z),.03,GOLD)
			_sphere(cart,Vector3(x,.10,z),Vector3(.17,.18,.17),DEEP)
	for y in [.24,.80]:_box(cart,Vector3(1.26,.07,.77),Vector3(0,y,0),WOOD,1,.02)
	for x in [-.38,0,.38]:_cup(cart,Vector3(x,.86,.05),BLUE)
	_books(cart,Vector3(-.39,.31,0),5)
	_coll(cart,Vector3(1.35,1.08,.82),Vector3(0,.54,0))
	var hobby: Node3D=_table(parent,Vector3(6.0,h,-2.0),3.1,1.5,.82,"craft_table")
	for i in 7:
		_box(hobby,Vector3(.40,.015,.30),Vector3(-1.15+i*.32,.92,.02),WHITE,0,.004).rotation.y=i*.12
		Geo.rod(hobby,Vector3(-1.05+i*.30,.94,-.28),Vector3(-.97+i*.30,.94,.09),.012,BLUE if i%2 else GOLD)
	Geo.cylinder(hobby,.13,.28,Vector3(1.06,1.03,-.24),LIGHT)
	for i in 5:Geo.rod(hobby,Vector3(1.02,1.08,-.24),Vector3(1.02+sin(i)*.12,1.51, -.24+cos(i)*.10),.012,Color("dd99ad") if i%2 else BLUE)
	_chair(parent,Vector3(5.6,h,-.40),0,true)
	_plant(parent,Vector3(3.50,h,-2.13),.95,true)
	var shelf: Node3D=_shelf(parent,Vector3(11.4,h,-10.8),3.2,1.9,"display_shelf")
	_art(shelf,Vector3(.6,2.64,-.25),Vector2(1.10,1.1))
	var basket: Node3D=_furniture(parent,"CushionBasket",Vector3(-7.1,h,-4.2))
	Geo.cylinder(basket,.52,.57,Vector3(0,.29,0),WOOD,.62)
	for i in 10:Geo.cylinder(basket,.53+i*.008,.025,Vector3(0,.06+i*.054,0),WHITE)
	_sphere(basket,Vector3(0,.56,0),Vector3(.72,.60,.69),BLUE)
	_star(basket,Vector3(0,.67,.41),.30)
	_coll(basket,Vector3(1.15,.78,1.15),Vector3(0,.39,0))
	var ottoman: Node3D=_furniture(parent,"StripedRoundOttoman",Vector3(.4,h,-2.3))
	var cushion: MeshInstance3D=Geo.cylinder(ottoman,.67,.45,Vector3(0,.27,0),BLUE);_cloth(cushion,BLUE,1)
	Geo.cylinder(ottoman,.65,.12,Vector3(0,.55,0),LIGHT)
	_coll(ottoman,Vector3(1.35,.64,1.35),Vector3(0,.32,0))

func _annexes() -> void:
	# Extend the house around the furnished core. All furniture keeps its native
	# dimensions, and the original stairs retain their full-height openings.
	var first: Node3D=floors[0]
	_art(first,Vector3(-21,.055,-6.4),Vector2(8.5,7.0),true)
	_sofa(first,Vector3(-21,0,-9.2),5.9)
	var tea_table: Node3D=_table(first,Vector3(-21,0,-5.8),3.8,2.1,.65,"tea_table")
	for x in [-1.1,1.1]:_cup(tea_table,Vector3(x,.75,0),BLUE)
	_chair(first,Vector3(-23.4,0,-3.1));_chair(first,Vector3(-18.6,0,-3.1))
	var tea: Action=_action("tea","annex_tea","海风会客厅 · 午后花茶",Vector3(-21,0,-5.8),0)
	var pot: Node3D=_group(tea,"AnnexTeapot",Vector3(0,.85,0))
	_sphere(pot,Vector3.ZERO,Vector3(.5,.35,.44),BLUE);Geo.cylinder(pot,.11,.05,Vector3(0,.19,0),GOLD)
	tea.parts.append(pot)
	var baking: Node3D=_table(first,Vector3(0,0,-23.3),6.4,3.0,1.05,"ash_table")
	for x in [-2.0,0.0,2.0]:
		_chair(first,Vector3(x,0,-20.8));_chair(first,Vector3(x,0,-25.8),180)
		_cup(baking,Vector3(x,1.15,.8),WHITE);_cup(baking,Vector3(x,1.15,-.8),BLUE)
	_plant(baking,Vector3(0,1.15,0),.5,true)
	for x in [-9.0,9.0]:_shelf(first,Vector3(x,0,-30.9),5.8,2.8,"display_shelf")
	var work: Node3D=_table(first,Vector3(21,0,-18.0),5.4,2.2,1.05,"craft_table")
	_books(work,Vector3(-2,1.16,0),8);_plant(work,Vector3(1.8,1.16,0),.55,true)
	for x in [19.5,22.5]:_chair(first,Vector3(x,0,-15.8),0,true)
	_shelf(first,Vector3(21,0,-30.9),5.6,3.1)
	for point in [Vector3(-21,0,-18),Vector3(21,0,-5)]:_plant(first,point,1.3,true)
	for x in [-21.0,0.0,21.0]:
		_porthole(first,Vector3(x,2.8,-31.8),1.1)
		_fixture(first,Vector3(x,3.45,-23.3))
	_zone("annex_tea","1F · 海风会客厅",Rect2(-28,-32,14,40))
	_zone("annex_craft","1F · 花艺与烘焙工坊",Rect2(14,-32,14,40))
	_zone("annex_dining","1F · 家庭长桌厅",Rect2(-14,-32,28,20))
	var second: Node3D=floors[1];var h: float=HEIGHT
	_art(second,Vector3(-21,h+.055,-18.4),Vector2(8.5,8.0),true)
	_sofa(second,Vector3(-21,h,-22.0),5.6)
	var reading: Node3D=_table(second,Vector3(-21,h,-18.0),3.7,1.8,.65,"tea_table")
	_books(reading,Vector3(-1.3,.76,0),6);_cup(reading,Vector3(1.2,.76,0),BLUE)
	for x in [-21.0,-9.0,0.0,9.0,21.0]:_shelf(second,Vector3(x,h,-32.8),5.0,3.4)
	for z in [-24.0,-12.0]:
		var desk: Node3D=_table(second,Vector3(21,h,z),4.8,1.8,1.05,"desk")
		_books(desk,Vector3(-1.8,1.16,-.2),7);_cup(desk,Vector3(1.6,1.16,.2),BLUE)
		_chair(second,Vector3(21,h,z+2.2));_fixture(desk,Vector3(1.6,1.15,-.4),false)
	var exhibit: Node3D=_furniture(second,"WhaleGalleryExhibit",Vector3(0,h,-25.0))
	_finish_box(exhibit,Vector3(4.0,.65,2.7),Vector3(0,.325,0),"cream_cabinet","top",.07)
	_whale(exhibit,Vector3(0,.72,0),1.0,20)
	_coll(exhibit,Vector3(4.0,2.1,3.5),Vector3(0,1.05,0))
	for point in [Vector3(-25,h,-5),Vector3(25,h,-4),Vector3(-12,h,-27),Vector3(12,h,-27)]:_plant(second,point,1.2,true)
	for x in [-21.0,0.0,21.0]:_fixture(second,Vector3(x,h+3.45,-25),true,true)
	_zone("annex_reading","2F · 海景阅读会客室",Rect2(-28,-34,14,36),h)
	_zone("annex_studio","2F · 双人创作书房",Rect2(14,-34,14,36),h)
	_zone("annex_library","2F · 蓝鲸藏书与展示长廊",Rect2(-14,-34,28,18),h)
	var third: Node3D=floors[2];h=HEIGHT*2
	var guest: Node3D=_furniture(third,"WhaleGuestBed",Vector3(-21,h,-29))
	_box(guest,Vector3(3.8,.45,5.0),Vector3(0,.40,0),WOOD,1,.10)
	_box(guest,Vector3(3.6,.5,4.8),Vector3(0,.82,0),WHITE,0,.18)
	var duvet: MeshInstance3D=_box(guest,Vector3(3.65,.28,3.7),Vector3(0,1.12,.5),LIGHT,0,.16);_cloth(duvet,LIGHT,1)
	for x in [-.9,.9]:
		var pillow: MeshInstance3D=_box(guest,Vector3(1.35,.30,.85),Vector3(x,1.2,-1.6),WHITE,0,.13);_cloth(pillow,WHITE)
	_box(guest,Vector3(3.9,1.7,.22),Vector3(0,1.05,-2.45),MINT,0,.08)
	_coll(guest,Vector3(3.9,1.95,5.1),Vector3(0,.98,0))
	_action("bed","guest_bed","海风客房 · 午后小憩",Vector3(-21,h,-25.7),h)
	_art(third,Vector3(-21,h+.055,-27.6),Vector2(8,9),true)
	for x in [-24.0,-18.0]:
		var nightstand: Node3D=_cabinet(third,Vector3(x,h,-30),1.3,.85,"cream_cabinet")
		_fixture(nightstand,Vector3(0,.95,0),false)
	_sofa(third,Vector3(21,h,-16),5.4)
	var rest: Node3D=_table(third,Vector3(21,h,-12.3),3.6,1.8,.65,"tea_table")
	_cup(rest,Vector3(-1,.76,0),BLUE);_books(rest,Vector3(.4,.76,0),5)
	for x in [-9.0,0.0,9.0]:
		var dresser: Node3D=_cabinet(third,Vector3(x,h,-36.8),4.2,1.1,"cream_cabinet")
		_plant(dresser,Vector3(1.3,1.22,0),.6,true);_whale(dresser,Vector3(-.8,1.2,0),.35)
		_art(third,Vector3(x,h+2.7,-37.8),Vector2(2.1,1.8))
	for x in [-21.0,21.0]:
		_porthole(third,Vector3(x,h+2.8,-37.8),1.15)
		_fixture(third,Vector3(x,h+3.45,-23),true,true)
	for point in [Vector3(-25,h,-8),Vector3(25,h,-26),Vector3(13,h,-31)]:_plant(third,point,1.2,true)
	_zone("annex_guest","3F · 海风客房",Rect2(-28,-38,14,36),h)
	_zone("annex_rest","3F · 海景休憩室",Rect2(14,-38,14,36),h)
	_zone("annex_dressing","3F · 晨光梳妆长廊",Rect2(-14,-38,28,18),h)

func _stairs(parent: Node3D, x: float, front: float, back: float, base: float, label: String) -> void:
	var width := 3.5;var run: float=front-back
	var root: Node3D=_group(parent,label,Vector3(x,base,(front+back)*.5))
	root.set_meta("home_stair",{"base":base,"top":base+HEIGHT,"front":front,"back":back,"x":x,"width":width})
	for i in 32:
		var y: float=HEIGHT*(i+1)/32.
		_box(root,Vector3(width,.17,run/32.+.012),Vector3(0,y-.06,run*.5-(i+.5)*run/32.),WOOD,1,.014)
		_box(root,Vector3(width-.06,.035,.065),Vector3(0,y+.025,run*.5-i*run/32.-.04),WHITE,0,.005)
	var body:=StaticBody3D.new();body.name="SmoothStairSupport";body.collision_layer=10;body.collision_mask=4
	var hit:=CollisionShape3D.new();var ramp:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
	for side in [-width*.5,width*.5]:
		points.append(Vector3(side,.025,run*.5));points.append(Vector3(side,HEIGHT+.025,-run*.5))
		points.append(Vector3(side,-.22,run*.5));points.append(Vector3(side,-.22,-run*.5))
	ramp.points=points;hit.shape=ramp;body.add_child(hit);root.add_child(body);body.set_meta("walkable_stair",hit);body.set_meta("walkable_top",base+HEIGHT+.025)
	var slabs: Array=level.get_meta("walkable_slabs",[]);slabs.append(body);level.set_meta("walkable_slabs",slabs)
	for side in [-1.0,1.0]:
		var first:=Vector3(side*(width*.5+.14),1.05,run*.5);var last:=Vector3(side*(width*.5+.14),HEIGHT+1.05,-run*.5)
		Geo.rod(root,first,last,.062,WHITE)
		for i in range(0,33,4):
			var p: Vector3=first.lerp(last,i/32.)
			Geo.rod(root,p-Vector3.UP*1.00,p,.040,WOOD)
			_sphere(root,p,Vector3.ONE*.12,GOLD)
		var guard:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(.13,1.28,sqrt(run*run+HEIGHT*HEIGHT));shape.shape=box
		guard.position=Vector3(side*(width*.5+.14),HEIGHT*.5+.65,0);guard.rotation.x=atan2(HEIGHT,run);guard.add_child(shape);root.add_child(guard)
		Geo.rod(root,Vector3(side*(width*.5),-.04,run*.5),Vector3(side*(width*.5),HEIGHT-.10,-run*.5),.11,BLUE)

func _roof(parent: Node3D) -> void:
	var h: float=HEIGHT*2
	# Only the back crown and ribs are roofed: the interior remains playable
	# and visible through the open dollhouse facade.
	for z in [-38.8,-37.3]:
		var last:=Vector3(-28.3,h+.9,z)
		for i in 64:
			var t: float=(i+1)/64.;var point:=Vector3(-28.3+56.6*t,h+.9+sin(t*PI)*6.5,z)
			Geo.rod(parent,last,point,.20,WHITE);last=point
	for i in 56:
		var t: float=(i+.5)/56.;var x: float=-28.3+56.6*t;var y: float=h+1.2+sin(t*PI)*6.5
		var angle: float=atan(cos(t*PI)*PI*6.5/56.6)
		for row in 4:
			var tile: MeshInstance3D=_model(parent,ROOF_TILE,Vector3(x,y,-38.84+row*.53));tile.rotation.z=angle
			tile.material_override=Geo.material(MINT if row%2 else MINT.lightened(.025))
		for z in [-39.10,-36.97]:
			var eave: MeshInstance3D=_box(parent,Vector3(1.11,.13,.14),Vector3(x,y-.07,z),TEAL,0,.025);eave.rotation.z=angle
			var soffit: MeshInstance3D=_box(parent,Vector3(1.12,.075,.27),Vector3(x,y-.16,z+.025),WHITE,0,.013);soffit.rotation.z=angle
	_vines(parent,Vector3(-22,h+4.4,-36.99),Vector3(20,h+4.8,-36.99),1.0)
	var tail: Node3D=_group(parent,"WhaleTailRoofFin",Vector3(24.3,h+6.0,-38.2))
	_sphere(tail,Vector3(0,.4,0),Vector3(1.03,3.1,.64),BLUE).rotation.z=-.35
	for side in [-1.0,1.0]:
		var fin: MeshInstance3D=_sphere(tail,Vector3(side*1.26,2.10,0),Vector3(3.4,1.13,.65),BLUE);fin.rotation.z=side*.52
	_whale(parent,Vector3(-23.6,h+4.65,-37.4),.75,25);_star(parent,Vector3(-23.7,h+6.25,-37.05),1.1)
	for i in 13:
		var x: float=-16.2+i*2.7;var y: float=h+1.45+sin((x+28.3)/56.6*PI)*5.6
		_fixture(parent,Vector3(x,y,-36.8),true,true)
	_vines(parent,Vector3(-28.4,h+1.15,-36.6),Vector3(-28.4,1.4,6.4),.4)
	_vines(parent,Vector3(28.4,h+1.15,-36.6),Vector3(28.4,.8,6.4),.4)

func _rock(parent: Node3D, point: Vector3, size: Vector3, variant: int=0) -> void:
	Coastal.reef(parent,point,size,variant,DOCK_RECTS)

func _garden(parent: Node3D) -> void:
	for side in [-1.0,1.0]:
		for i in 18:
			var z: float=-43.5+i*3.75
			_rock(parent,Vector3(side*41.5,-.75,z),Vector3(2.8,2.4,3.8),i)
			if i%2==0:
				for j in 3:
					var point:=Vector3(side*(39.8+j*.30),.05,z+(j-1)*.65)
					_sphere(parent,point+Vector3.UP*.35,Vector3(1.2,.70,1.2),GREEN)
					for f in 4:_flower(parent,point+Vector3(sin(f*2.0)*.40,.73,cos(f*2.0)*.4),WHITE if f%2 else Color("f0b5c9"),.31)
	for i in 27:
		var x: float=-41+i*3.16
		_rock(parent,Vector3(x,-.6,-45.0),Vector3(3.7,2.6,2.8),i)
		if absf(x)>5:_rock(parent,Vector3(x,-.60,24.5),Vector3(3.7,2.4,2.8),i+1)
	for side in [-1.0,1.0]:
		for i in 7:
			var p:=Vector3(side*34.5,.03,-18+i*5.8)
			Ground.path(parent,Rect2(p.x-2.5,p.z-1.8,5.0,3.6),"GardenStonePatio")
			if i%2==0:
				_model(parent,FLOWER_BED,p)
				_plant(parent,p+Vector3(side*1.20,.08,0),1.4,true)
			else:
				var table: Node3D=_table(parent,p+Vector3(-side*.4,0,0),2.1,1.4,.8,"garden_table");_cup(table,Vector3(0,.91,0),BLUE)
				_chair(parent,p+Vector3(-side*.4,0,1.7),0)
		var gazebo: Node3D=_model(parent,PERGOLA,Vector3(side*34.5,0,-12.2),true)
		for x in [-2.0,2.0]:
			for z in [-1.65,1.65]:
				_coll(gazebo,Vector3(.16,3.35,.16),Vector3(x,1.67,z))
				_coll(gazebo,Vector3(.26,.15,.26),Vector3(x,.075,z))
		var planter: Node3D=_model(gazebo,PLANTER,Vector3(1.38,0,1.24),true)
		_coll(planter,Vector3(.73,.49,.73),Vector3(0,.245,0))
		_vines(gazebo,Vector3(-2,3.18,1.70),Vector3(2,3.18,1.70),.55)
		_fixture(gazebo,Vector3(0,2.72,.1),true,true)
	for x in [-36.0,-29.0,29.0,36.0]:
		var root: Node3D=_group(parent,"HarborGardenLantern",Vector3(x,0,16.8))
		Geo.cylinder(root,.22,.12,Vector3(0,.06,0),WHITE)
		Geo.rod(root,Vector3(0,.1,0),Vector3(0,2.7,0),.055,GOLD)
		_fixture(root,Vector3(0,2.64,0),true)
		_whale(root,Vector3(0,1.52,0),.25)
	for i in 10:
		var x: float=-12.8+i*2.85
		if absf(x+9.2)<2.1:continue
		_plant(parent,Vector3(x,.06,8.6),.8,true)
	var picnic: Node3D=_table(parent,Vector3(-35.5,0,10.3),3.6,2.2,.85,"garden_table")
	for i in 4:_cup(picnic,Vector3(-1.1+i*.73,.95,.14),BLUE if i%2 else WHITE)
	_plant(picnic,Vector3(.07,.93,-.6),.4,true)
	for x in [-36.6,-34.4]:
		_chair(parent,Vector3(x,0,12.2),0);_chair(parent,Vector3(x,0,8.4),180)
	_whale(parent,Vector3(34.2,0,16.9),1.28,-25)
	_coll(parent,Vector3(3.2,1.5,2.4),Vector3(34.2,.75,16.9))
	_pastel_garden(parent)

func _picket(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var fence: Node3D=_group(parent,"CreamPicketFence",(a+b)*.5)
	var length: float=a.distance_to(b);var count: int=ceili(length/4.0);var width: float=length/count
	fence.rotation.y=-atan2(b.z-a.z,b.x-a.x)
	for i in count:
		var panel: Node3D=_model(fence,FENCE_PANEL,Vector3(-length*.5+(i+.5)*width,0,0));panel.scale.x=width/4.0
		if i>0:
			panel.get_node("EndPostLeft").free()
			panel.get_node("PointedBoard").free()
	_coll(fence,Vector3(length+.27,1.14,.25),Vector3(0,.57,-.015))

func _pastel_garden(parent: Node3D) -> void:
	# Outer lawns keep the existing side walks, pergolas and home doorway clear.
	Ground.path(parent,Rect2(-11.30,10.0,7.05,2.0),"EntryStoneWalk")
	var tree_specs: Array=[
		[Vector3(-24.0,.06,-20.2),1.6,false],[Vector3(-24.2,.06,-3.8),1.8,false],
		[Vector3(-24.2,.06,5.4),1.6,false],[Vector3(-24.0,.06,19.0),1.65,false],
		[Vector3(24.1,.06,-20.5),1.8,false],[Vector3(24.3,.06,-3.2),1.65,true],
		[Vector3(24.4,.06,8.4),1.9,true],[Vector3(23.8,.06,20.2),1.65,true],
		[Vector3(-12.0,.06,21.2),1.7,false],[Vector3(10.8,.06,21.2),1.75,true]]
	for spec: Array in tree_specs:
		var point: Vector3=spec[0]
		if absf(point.x)>14.0:point.x+=signf(point.x)*SIDE_GARDEN_OFFSET
		spec[0]=point
	tree_specs.append_array([[Vector3(-38,.06,-36),1.5,false],[Vector3(38,.06,-36),1.5,false],[Vector3(-20,.06,-40),1.4,true],[Vector3(20,.06,-40),1.4,true]])
	var ground: Dictionary=Ground.gardens(parent,tree_specs,SIDE_GARDEN_OFFSET,67.0)
	level.set_meta("ground_revision","garden_paving_lawn_v1");level.set_meta("lawn_tufts",ground.tufts);level.set_meta("lawn_patches",ground.lawns)
	var blossom_origins: Array[Vector3]=[]
	for i in tree_specs.size():
		var spec: Array=tree_specs[i]
		var form: PackedScene=SAKURA_TREE if spec[2] else (LOW_TREE if i in [1,2,8] else TALL_TREE)
		var tree: Node3D=_model(parent,form,spec[0],true);tree.scale=Vector3.ONE*float(spec[1]);tree.rotation.y=i*.47
		Ground.tree_ring(parent,spec[0])
		_coll(tree,Vector3(.42,2.65,.42),Vector3(.06,1.325,0))
		if spec[2]:blossom_origins.append(spec[0])
	for spec in [[Vector3(-34.5,.05,19.6),0.0],[Vector3(-34.5,.05,-3.4),90.0],[Vector3(34.5,.05,2.9),-90.0],[Vector3(9.0,.05,15.1),0.0]]:
		var bench: Node3D=_model(parent,BENCH,spec[0],true);bench.rotation_degrees.y=float(spec[1])
		_coll(bench,Vector3(2.2,1.24,.83),Vector3(0,.62,0))
	for side in [-1.0,1.0]:
		for i in 5:
			var point:=Vector3(side*(6.7+i*.82),.4,13.4)
			Pastel.clump(parent,point,Vector3(1.25,.78,1.15),GREEN)
			if i%2==0:_flower(parent,point+Vector3.UP*.40,SAKURA,.30)
	var mesh:=QuadMesh.new();mesh.size=Vector2(.14,.085)
	var material:=StandardMaterial3D.new();material.albedo_color=SAKURA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED
	var petals:=MultiMeshInstance3D.new();petals.name="GardenPetals";petals.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=mesh;multimesh.instance_count=36
	for i in 36:
		var origin: Vector3=blossom_origins[i%blossom_origins.size()]
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,origin+Vector3(sin(i*2.3)*2.4,1.2+float(i%9)*.52,cos(i*2.3)*2.0)))
	petals.multimesh=multimesh;petals.material_override=material;parent.add_child(petals)
	level.set_meta("garden_petals",petals);level.set_meta("blossom_origins",blossom_origins)
	level.set_meta("pastel_trees",tree_specs.size());level.set_meta("pastel_benches",4)
	level.set_meta("tree_form_counts",{"tall_green":5,"low_green":3,"sakura":6})

func _boat(parent: Node3D, point: Vector3, yaw: float=0.0) -> Node3D:
	var root: Node3D=_model(parent,ROWBOAT,point);root.rotation_degrees.y=yaw;root.set_meta("boat_origin",point);root.set_meta("home_dynamic",true)
	_whale(root,Vector3(0,.57,-1.1),.70)
	var count: int=_batch(root,false)
	level.set_meta("boat_surfaces",int(level.get_meta("boat_surfaces",0))+count)
	return root

func _dock(parent: Node3D, sea: Node3D) -> void:
	for rect in DOCK_RECTS:
		var dock: Node3D=_group(parent,"TimberDock")
		_slab(dock,rect,0)
		# Keep the original continuous collider; timber replaces the solid grey shell.
		dock.get_child(0).free()
		var cross_bridge: bool=rect.size.x>rect.size.y
		var visible_rect: Rect2=Rect2(-16.5,28,13.5,3.0) if cross_bridge else Rect2(Vector2(rect.position.x,25.0),Vector2(rect.size.x,rect.end.y-25.0))
		Coastal.dock(dock,visible_rect,cross_bridge)
	for x in [-2.6,2.6]:
		for z in [25.8,30.4,35.5]:
			Coastal.pile(parent,Vector3(x,0,z))
			if x==-2.6 and z==30.4:continue
			_model(parent,DOCK_POST,Vector3(x,0,z))
			_coll(parent,Vector3(.44,.80,.48),Vector3(x,.32,z))
	for z in [25.8,30.4,35.5]:Coastal.trestle(parent,Vector3(-2.6,0,z),Vector3(2.6,0,z))
	for z in [25.5,29.3,33.0]:
		for x in [-21.7,-16.8]:
			Coastal.pile(parent,Vector3(x,0,z))
			if x==-16.8 and z==29.3:continue
			_model(parent,DOCK_POST,Vector3(x,0,z))
			_coll(parent,Vector3(.44,.80,.48),Vector3(x,.32,z))
		Coastal.trestle(parent,Vector3(-21.7,0,z),Vector3(-16.8,0,z))
	for x in [-12.0,-7.7]:
		for z in [28.16,30.84]:Coastal.pile(parent,Vector3(x,0,z))
		Coastal.trestle(parent,Vector3(x,0,28.16),Vector3(x,0,30.84))
	for point: Vector3 in Coastal.bridge_ropes(parent):_coll(parent,Vector3(.24,.78,.24),point+Vector3(0,.35,0))
	var east_boat: Node3D=_boat(sea,Vector3(7.2,-.93,30.2),-22)
	var west_boat: Node3D=_boat(sea,Vector3(-25.0,-.93,29.6),15)
	var moorings: Array=[]
	for spec in [[east_boat,"MooringEyeLeft",Vector3(2.6,.59,30.4)],[west_boat,"MooringEyeRight",Vector3(-21.7,.40,29.3)]]:
		var line: MultiMeshInstance3D=Pastel.mooring(sea);var eye: Node3D=spec[0].get_node(spec[1])
		Pastel.update_mooring(line,spec[2],eye.global_position)
		moorings.append({"line":line,"eye":eye,"dock":spec[2]})
	level.set_meta("home_moorings",moorings)
	for side in [-1.0,1.0]:_rail(parent,Vector3(side*3.0,0,24.6),Vector3(side*3.0,0,28.0),false)
	var dock_whale: Node3D=_whale(parent,Vector3(-20.9,0,32.4),.47,25)
	_coll(dock_whale,Vector3(1.52,1.45,2.70),Vector3(0,.70,-.10))
	var sign: Node3D=_furniture(parent,"WhaleHomeWelcomeSign",Vector3(-8.7,0,18.2))
	for x in [-1.42,1.42]:_box(sign,Vector3(.14,1.7,.14),Vector3(x,.85,0),WOOD,1,.02)
	_box(sign,Vector3(3.85,.95,.18),Vector3(0,1.10,0),WOOD,1,.07)
	var label:=Label3D.new();label.text="大肥鱼之家";label.font=game._game_font();label.font_size=64;label.pixel_size=.009;label.position=Vector3(0,1.12,.11);label.modulate=WHITE;label.outline_size=0;sign.add_child(label)
	_whale(sign,Vector3(-.95,1.50,0),.35,0)
	_coll(sign,Vector3(3.9,1.5,.30),Vector3(0,.75,0))
	_action("mail","welcome_letter","家门口的漂流信",Vector3(-8.7,0,19.1),0)

func _zone(id: String, name_text: String, rect: Rect2, height: float=0.0) -> void:
	zones.append({"id":id,"name":name_text,"rect":rect,"polygon":Shape.rectangle(rect),"height":height,"center":Vector3(rect.get_center().x,height,rect.get_center().y),"paths":[],"door_clear":[]})

func _batch(parent: Node3D, count_static: bool=true) -> int:
	# Merge static surfaces by material, retaining furniture names, colliders,
	# lights and independently animated fish / cabinet doors in the scene tree.
	var buckets: Dictionary={}
	for node: MeshInstance3D in parent.find_children("*","MeshInstance3D",true,false):
		if count_static:detail_count+=1
		var dynamic := false;var ancestor: Node=node.get_parent()
		while ancestor!=parent and ancestor:
			if ancestor.has_meta("home_dynamic"):dynamic=true;break
			ancestor=ancestor.get_parent()
		if dynamic or node.material_override==glass or not node.mesh:continue
		for surface in node.mesh.get_surface_count():
			var material: Material=node.get_active_material(surface)
			if not material:continue
			var key: String=str(material.get_instance_id())+":"+str(node.cast_shadow)
			if not buckets.has(key):buckets[key]={"material":material,"shadow":node.cast_shadow,"pieces":[]}
			buckets[key].pieces.append([node,surface])
	for key in buckets:
		var bucket: Dictionary=buckets[key]
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in bucket.pieces:
			var mesh: MeshInstance3D=piece[0]
			# PrimitiveMesh is indexed; our chamfered boxes are not. Mixing them
			# directly discards the earlier unindexed triangles at commit time.
			var source_key: String=str(mesh.mesh.get_instance_id())+":"+str(piece[1])
			if not indexed_cache.has(source_key):
				var normalized:=SurfaceTool.new();normalized.create_from(mesh.mesh,int(piece[1]));normalized.index();indexed_cache[source_key]=normalized.commit()
			tool.append_from(indexed_cache[source_key],0,parent.global_transform.affine_inverse()*mesh.global_transform)
			mesh.hide()
		var combined:=MeshInstance3D.new();combined.name="HomeStaticSurface_"+str(batched_surfaces) if count_static else "BoatSurface";combined.mesh=tool.commit();combined.material_override=bucket.material;combined.cast_shadow=bucket.shadow;parent.add_child(combined)
		if count_static:batched_surfaces+=1
		for piece in bucket.pieces:
			var mesh: MeshInstance3D=piece[0]
			if is_instance_valid(mesh) and not mesh.is_queued_for_deletion():mesh.queue_free()
	return buckets.size()

func build(owner_game) -> Dictionary:
	Pastel.use_shared_materials()
	Ground.begin()
	game=owner_game;level=_group(game.world,"WhaleHome");level.set_meta("walkable_slabs",[])
	glass=StandardMaterial3D.new();glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glass.albedo_color=Color(.58,.85,.96,.12);glass.roughness=.18;glass.cull_mode=BaseMaterial3D.CULL_DISABLED
	game.shell.set_meta("layout_revision","whale_home_three_floors_v1")
	level.set_meta("visual_style","pastel_diorama_v1")
	level.set_meta("model_revision","pastel_models_v2");level.set_meta("editable_components",13)
	level.set_meta("building_revision","fourfold_floor_area_v1")
	level.set_meta("floor_footprints",FLOOR_RECTS)
	level.set_meta("building_footprint_m2",FLOOR_RECTS[0].get_area())
	level.set_meta("gross_floor_area_m2",FLOOR_RECTS[0].get_area()+FLOOR_RECTS[1].get_area()+FLOOR_RECTS[2].get_area())
	game.shell.set_meta("guide_anchor",Vector3(-5.2,.05,18.0))
	var island: Node3D=_group(level,"Island");var sea: Node3D=_group(level,"Sea");var roof: Node3D=_group(level,"Roof")
	for i in 3:
		var floor_group: Node3D=_group(level,"Floor"+str(i));floor_group.set_meta("floor_height",i*HEIGHT);floors.append(floor_group)
	var ocean:=MeshInstance3D.new();ocean.name="CoastalOcean";var plane:=PlaneMesh.new();plane.size=Vector2(180,170);plane.subdivide_width=95;plane.subdivide_depth=87;ocean.mesh=plane;ocean.position=Vector3(0,-1.1,-5);ocean.extra_cull_margin=.12
	var water:=ShaderMaterial.new();water.shader=SEA;ocean.material_override=water;ocean.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;sea.add_child(ocean);level.set_meta("sea_material",water)
	level.set_meta("coastal_revision","timber_reefs_v1")
	_slab(island,ISLAND_RECT,0)
	Ground.base(island,ISLAND_RECT)
	Ground.path(island,Rect2(-4.25,8.7,8.5,15.3),"MainStonePromenade")
	Ground.path(island,Rect2(-3,24,6,1),"MainDockStoneLanding")
	Ground.path(island,Rect2(-22,24,5.5,1),"WestDockStoneLanding")
	Ground.path(island,Rect2(-33,21.5,66,2.5),"FrontGardenConnection")
	Ground.path(island,Rect2(-33,-43,66,2.5),"RearGardenConnection")
	for side in [-1.0,1.0]:
		Ground.path(island,Rect2(side*31.0-2.0,-43,4.0,67.0),"SideStoneWalk")
		_rail(island,Vector3(side*42,0,-44.8),Vector3(side*42,0,24.8),false)
	_rail(island,Vector3(-42,0,-45),Vector3(42,0,-45),false)
	for span in [Vector2(-42,-22.3),Vector2(-16.2,-3.4),Vector2(3.4,42)]:_picket(island,Vector3(span.x,0,25),Vector3(span.y,0,25))
	_deck(floors[0],FLOOR_RECTS[0],0)
	_wall(floors[0],Rect2(-14,-12,28,20),0,true)
	# East stairwell in 2F and west stairwell in 3F remain open all the way
	# through the floor slabs, so the character's head never hits a landing.
	for rect in [Rect2(-28,-34,36.4,36),Rect2(8.4,-34,19.6,28),Rect2(14,-6,14,8)]:_slab(floors[1],rect,HEIGHT);_deck(floors[1],rect,HEIGHT)
	for rect in [Rect2(-8.4,-38,36.4,36),Rect2(-28,-38,19.6,24),Rect2(-28,-14,14,12)]:_slab(floors[2],rect,HEIGHT*2);_deck(floors[2],rect,HEIGHT*2)
	_wall(floors[1],Rect2(-14,-16,28,18),HEIGHT,true);_wall(floors[2],Rect2(-14,-20,28,18),HEIGHT*2,true)
	for i in 3:_wall(floors[i],FLOOR_RECTS[i],i*HEIGHT)
	_stairs(floors[0],10.8,6.6,-6.0,0,"SeaBreezeStairs_1F_2F")
	_stairs(floors[1],-10.8,-1.4,-14.0,HEIGHT,"StarLightStairs_2F_3F")
	_curved_balcony(floors[1],-28,8.4,2,HEIGHT,"curved_lounge_balcony")
	_rail(floors[1],Vector3(8.4,HEIGHT,-5.9),Vector3(8.4,HEIGHT,2))
	_curved_balcony(floors[2],-8.4,28,-2,HEIGHT*2,"curved_stars_balcony")
	_rail(floors[2],Vector3(-8.4,HEIGHT*2,-13.9),Vector3(-8.4,HEIGHT*2,-2))
	for i in 3:
		var h: float=i*HEIGHT;var front: float=8-i*5
		for x in [-12.8,12.8]:_plant(floors[i],Vector3(x,h,front-1.1),1.15,true)
	_kitchen(floors[0]);_dining(floors[0])
	_porthole(floors[0],Vector3(.3,2.73,-11.80),1.0)
	var entry: Node3D=_model(floors[0],PORCH,Vector3(-9.6,0,7.4),true)
	for side in [-1.0,1.0]:
		_coll(entry,Vector3(.34,2.7,.39),Vector3(side*1.3,1.35,0))
		_plant(entry,Vector3(side*1.94,0,.35),.7,true)
	_whale(entry,Vector3(0,4.0,0),.40)
	_art(floors[0],Vector3(-9.6,.06,6.4),Vector2(3.2,1.8),true)
	_entry_details(floors[0]);_living(floors[1]);_hobby(floors[1]);_bedroom(floors[2]);_bathroom(floors[2]);_telescope(floors[2]);_roof(roof)
	_annexes()
	_garden(island);_dock(island,sea)
	_zone("kitchen","1F · 海盐厨房与中岛",Rect2(-14,-12,19,9.8))
	_zone("pantry","1F · 蓝鲸餐具收藏柜",Rect2(5,-12,4,5))
	_zone("dining","1F · 鲸鱼餐厅",Rect2(-3,-2,11,9.8))
	_zone("entry","1F · 花藤门廊",Rect2(-14,-2,11,10))
	_zone("aquarium","2F · 全景水族客厅",Rect2(-8,-16,10,9.0),HEIGHT)
	_zone("study","2F · 海景书房",Rect2(2,-16,12,12),HEIGHT)
	_zone("lounge","2F · 鲸鱼茶会与玻璃露台",Rect2(-8,-7,16,9),HEIGHT)
	_zone("bedroom","3F · 鲸鱼梦境卧室",Rect2(-8.4,-20,10.6,14),HEIGHT*2)
	_zone("stars","3F · 观星与阅读露台",Rect2(2.2,-20,11.8,18),HEIGHT*2)
	_zone("west_garden","花园 · 茶点庭院",Rect2(-42,-45,14,70))
	_zone("east_garden","花园 · 蓝鲸花径",Rect2(28,-45,14,70))
	_zone("front_garden","花园 · 迎风前庭",Rect2(-28,8,56,17))
	_zone("rear_garden","花园 · 屋后环行步道",Rect2(-28,-45,56,7))
	_zone("dock","海面栈桥 · 蓝鲸小船",Rect2(-22,25,30,12))
	level.set_meta("home_lights",lights);level.set_meta("furniture_count",furniture_count);level.set_meta("zone_count",zones.size())
	for group: Node3D in [island,floors[0],floors[1],floors[2],roof]:_batch(group)
	level.set_meta("detail_meshes",detail_count);level.set_meta("static_surfaces",batched_surfaces)
	return {"level":level,"bounds":Vector2(104,108),"spawn":Vector3(-9.6,.05,11.0),"exit":Vector3(0,0,33.7),"zones":zones,"camera_size":88.0}
