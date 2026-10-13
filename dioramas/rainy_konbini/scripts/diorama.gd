@tool
extends Node3D
## 原创程序化微缩模型；所有物件均为真实 3D 网格。bake_scene.gd 可保存编辑器可编辑版本。
@export var baked := false
@export var optimize_batches := true
const TOON = preload("res://dioramas/rainy_konbini/shaders/toon.gdshader")
const OUTLINE = preload("res://dioramas/rainy_konbini/shaders/outline.gdshader")
const GLASS = preload("res://dioramas/rainy_konbini/shaders/glass_rain.gdshader")
const PUDDLE = preload("res://dioramas/rainy_konbini/shaders/puddle.gdshader")
const CAMERA_SCRIPT = preload("res://dioramas/rainy_konbini/scripts/orbit_camera.gd")
var materials: Dictionary = {}
var meshes: Dictionary = {}
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var door_left: Node3D
var door_right: Node3D
var sign_light: OmniLight3D
var ripples: Array[Node3D] = []
var drops: Array[Node3D] = []
var signal_bulbs: Array[MeshInstance3D] = []
var mint := Color("68bbb9")
var cream := Color("e9debd")
var steel := Color("43546c")
var dark := Color("243047")
var orange := Color("e99464")
var paper := Color("f3eed7")
var ink := Color("28344c")

func _ready() -> void:
	if baked:
		bind_animations()
	else:
		rng.seed = 174039
		build_environment()
		build_base()
		build_shop()
		build_interior()
		build_street()
		build_weather()
		var camera := Camera3D.new()
		camera.name = "OrbitCamera"
		camera.set_script(CAMERA_SCRIPT)
		add_child(camera)
		bind_animations()
	if optimize_batches and not Engine.is_editor_hint(): batch_repeated_geometry()
	set_process(not Engine.is_editor_hint())

func batch_repeated_geometry() -> void:
	var bins: Dictionary = {}
	for node in find_children("*","MeshInstance3D",true,false):
		if node.is_in_group("rain_ripples") or node.is_in_group("eave_drops") or node.is_in_group("signal_bulbs"): continue
		if door_left.is_ancestor_of(node) or door_right.is_ancestor_of(node): continue
		var material: Material = node.material_override
		if not material is ShaderMaterial or material.shader != TOON: continue
		var key := str(node.mesh.get_instance_id(),":",material.get_instance_id())
		if not bins.has(key): bins[key]=[]
		bins[key].append(node)
	var container := group("StaticMultiMeshBatches")
	for key in bins:
		var instances: Array = bins[key]
		if instances.size()<4: continue
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=instances[0].mesh
		mm.instance_count=instances.size()
		for i in instances.size(): mm.set_instance_transform(i,global_transform.affine_inverse()*instances[i].global_transform)
		var batch := MultiMeshInstance3D.new()
		batch.name="Batch_"+str(instances[0].name)
		batch.multimesh=mm
		batch.material_override=instances[0].material_override
		container.add_child(batch)
		for instance in instances: instance.queue_free()

func group(label: String, at := Vector3.ZERO, parent: Node = self) -> Node3D:
	var n := Node3D.new()
	n.name = label
	n.position = at
	parent.add_child(n)
	return n

func mat(c: Color, glow := 0.0, rough := 0.72, outline := false) -> ShaderMaterial:
	var key := str(c, ":", glow, ":", rough, ":", outline)
	if materials.has(key): return materials[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("ink_color", c)
	m.set_shader_parameter("glow", glow)
	m.set_shader_parameter("surface_roughness", rough)
	if outline:
		var stroke := ShaderMaterial.new()
		stroke.shader = OUTLINE
		m.next_pass = stroke
	materials[key] = m
	return m

func add_mesh(label: String, mesh: Mesh, at: Vector3, material: Material, parent: Node) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	n.position = at
	n.material_override = material
	parent.add_child(n)
	return n

func polygon(st: SurfaceTool, pts: Array[Vector3], normal: Vector3) -> void:
	if (pts[1]-pts[0]).cross(pts[2]-pts[0]).dot(normal) < 0: pts.reverse()
	# Godot front faces wind clockwise; face normal is explicitly assigned.
	for i in range(1, pts.size()-1):
		for v in [pts[0], pts[i+1], pts[i]]:
			st.set_normal(normal)
			st.set_uv(Vector2(v.x+v.z, v.y))
			st.add_vertex(v)

func bevel_mesh(dim: Vector3, b: float) -> ArrayMesh:
	var key := str(dim, b)
	if meshes.has(key): return meshes[key]
	var h := dim*0.5
	b = minf(b, minf(h.x, minf(h.y,h.z))*0.45)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in 3:
		var j := (a+1)%3
		var k := (a+2)%3
		for s in [-1.0, 1.0]:
			var pts: Array[Vector3] = []
			for p in [Vector2(-h[j]+b,-h[k]),Vector2(h[j]-b,-h[k]),Vector2(h[j],-h[k]+b),Vector2(h[j],h[k]-b),Vector2(h[j]-b,h[k]),Vector2(-h[j]+b,h[k]),Vector2(-h[j],h[k]-b),Vector2(-h[j],-h[k]+b)]:
				var v := Vector3.ZERO
				v[a]=h[a]*s
				v[j]=p.x
				v[k]=p.y
				pts.append(v)
			var norm := Vector3.ZERO
			norm[a]=s
			polygon(st,pts,norm)
	# Twelve chamfer strips.
	for axis in 3:
		var j := (axis+1)%3
		var k := (axis+2)%3
		for sj in [-1.0,1.0]:
			for sk in [-1.0,1.0]:
				var pts: Array[Vector3] = []
				for p in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var v := Vector3.ZERO
					v[axis]=p.x*(h[axis]-b)
					v[j]=(h[j]-b*p.y)*sj
					v[k]=(h[k]-b*(1.0-p.y))*sk
					pts.append(v)
				var norm := Vector3.ZERO
				norm[j]=sj
				norm[k]=sk
				polygon(st,pts,norm.normalized())
	for sx in [-1.0,1.0]:
		for sy in [-1.0,1.0]:
			for sz in [-1.0,1.0]:
				var sign_v := Vector3(sx,sy,sz)
				var pts: Array[Vector3] = []
				for axis in 3:
					var v := (h-Vector3.ONE*b)*sign_v
					v[axis]=h[axis]*sign_v[axis]
					pts.append(v)
				polygon(st,pts,sign_v.normalized())
	var result := st.commit()
	meshes[key]=result
	return result

func box(label: String, at: Vector3, dim: Vector3, c: Color, parent: Node, glow := 0.0, bevel := 0.025, outline := false) -> MeshInstance3D:
	return add_mesh(label,bevel_mesh(dim,bevel),at,mat(c,glow,0.65,outline),parent)

func cylinder(label: String, at: Vector3, radius: float, height: float, c: Color, parent: Node, top := -1.0, glow := 0.0) -> MeshInstance3D:
	var key := str("cyl",radius,height,top)
	var mesh: CylinderMesh
	if meshes.has(key): mesh=meshes[key]
	else:
		mesh=CylinderMesh.new()
		mesh.top_radius = radius if top < 0 else top
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 24
		meshes[key]=mesh
	return add_mesh(label,mesh,at,mat(c,glow),parent)

func sphere(label: String, at: Vector3, radius: float, c: Color, parent: Node, glow := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2
	mesh.radial_segments=16
	mesh.rings=8
	return add_mesh(label,mesh,at,mat(c,glow),parent)

func rod(label: String, a: Vector3, b: Vector3, radius: float, c: Color, parent: Node) -> MeshInstance3D:
	var n := cylinder(label,(a+b)*0.5,radius,a.distance_to(b),c,parent)
	var dir := (b-a).normalized()
	n.quaternion = Quaternion(Vector3.UP, dir)
	return n

func ring(label: String, at: Vector3, radius: float, thick: float, c: Color, parent: Node, glow := 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-thick
	mesh.outer_radius = radius+thick
	mesh.rings=32
	mesh.ring_segments=8
	return add_mesh(label,mesh,at,mat(c,glow),parent)

func text3d(label: String, words: String, at: Vector3, size_px: int, scale_px: float, c: Color, parent: Node) -> Label3D:
	var n := Label3D.new()
	n.name=label
	n.text=words
	n.position=at
	n.font_size=size_px
	n.pixel_size=scale_px
	n.modulate=c
	n.outline_modulate=Color(0.07,0.12,0.18,1)
	n.outline_size=2
	n.no_depth_test=false
	n.shaded=false
	parent.add_child(n)
	return n

func omni(label: String, at: Vector3, c: Color, energy: float, radius: float, parent: Node) -> OmniLight3D:
	var n := OmniLight3D.new()
	n.name=label
	n.position=at
	n.light_color=c
	n.light_energy=energy
	n.omni_range=radius
	n.omni_attenuation=1.3
	parent.add_child(n)
	return n

func glass_panel(label: String, at: Vector3, width: float, height: float, parent: Node) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.orientation=PlaneMesh.FACE_Z
	plane.size=Vector2(width,height)
	var material := ShaderMaterial.new()
	material.shader=GLASS
	var n := add_mesh(label,plane,at,material,parent)
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name="NightEnvironment"
	var env := Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("172137")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("99b6d4")
	env.ambient_light_energy=0.63
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	world.environment=env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.name="BlueMoon"
	moon.rotation_degrees=Vector3(-48,-35,0)
	moon.light_color=Color("9bb9e3")
	moon.light_energy=0.75
	moon.shadow_enabled=true
	moon.directional_shadow_max_distance=40
	add_child(moon)
	var fill := DirectionalLight3D.new()
	fill.name="LavenderFill"
	fill.rotation_degrees=Vector3(-25,145,0)
	fill.light_color=Color("b8a7cf")
	fill.light_energy=0.28
	add_child(fill)

func build_base() -> void:
	var base := group("SquareBase")
	box("SolidCollectorBase",Vector3(0,-0.38,0),Vector3(14,0.76,14),Color("273750"),base,0,0.15,true)
	box("BaseTrim",Vector3(0,-0.11,0),Vector3(13.96,0.10,13.96),Color("4c667e"),base,0,0.035)
	var roadmat := ShaderMaterial.new()
	roadmat.shader=preload("res://dioramas/rainy_konbini/shaders/wet_road.gdshader")
	var road := box("WetAsphalt",Vector3(0,0.005,0),Vector3(13.85,0.12,13.85),dark,base,0,0.08)
	road.material_override=roadmat
	box("ShopSidewalk",Vector3(-1.65,0.15,-1.90),Vector3(9.4,0.24,8.5),Color("71818b"),base,0,0.05)
	# Individual curb stones establish the two perpendicular streets.
	for x in range(19):
		box("FrontCurb",Vector3(-6.15+x*0.49,0.18,2.35),Vector3(0.465,0.30,0.22),cream.darkened(0.2),base)
	for z in range(17):
		box("SideCurb",Vector3(3.05,0.18,-5.95+z*0.49),Vector3(0.22,0.30,0.465),cream.darkened(0.2),base)
	# Paving seams are geometry, not a tiled photo texture.
	for i in range(20):
		box("PavingSeam",Vector3(-6.15+i*0.46,0.277,1.75),Vector3(0.012,0.007,1.0),Color("4d6377"),base,0,0.002)
	for z in [1.29,1.77,2.20]:
		box("PavingSeam",Vector3(-1.8,0.279,z),Vector3(8.8,0.007,0.012),Color("4d6377"),base,0,0.002)
	# Raised tactile tiles leading to the doorway.
	for z in range(9):
		box("TactileTile",Vector3(0.68,0.29,1.27+z*0.11),Vector3(0.45,0.015,0.09),Color("d7ad62"),base,0,0.005)
	for i in range(6):
		box("Crosswalk",Vector3(3.75+i*0.48,0.08,3.75),Vector3(0.28,0.018,2.5),paper.darkened(0.08),base,0,0.008)
	for x in [-5.7,-4.4,-3.1,-1.8,-0.5,0.8]:
		box("FrontLaneDash",Vector3(x,0.073,5.65),Vector3(0.60,0.012,0.09),paper.darkened(0.2),base,0,0.003)
	for z in [-5.8,-4.4,-3.0,-1.6,-0.2,1.2]:
		box("SideLaneDash",Vector3(5.85,0.074,z),Vector3(0.09,0.012,0.65),paper.darkened(0.2),base,0,0.003)
	for x in [-5.5,-3.3]:
		for sx in [-0.8,0.8]:
			box("ParkingLine",Vector3(x+sx,0.078,3.48),Vector3(0.045,0.014,1.62),paper.darkened(0.22),base,0,0.004)
		box("ParkingStopLine",Vector3(x,0.078,4.28),Vector3(1.65,0.014,0.045),paper.darkened(0.22),base,0,0.004)
		box("WheelStop",Vector3(x,0.14,2.83),Vector3(0.72,0.15,0.18),cream.darkened(0.1),base)
	# Open alley runs behind the store within the same base.
	for z in [-5.90,-5.35]:
		box("AlleyMark",Vector3(-1.0,0.28,z),Vector3(0.1,0.014,0.28),paper.darkened(0.3),base)

func build_shop() -> void:
	var store := group("KonbiniArchitecture")
	# Store bounds: x -5.2..2.8, z -4.6..1.1. Both street-facing sides have real glazing.
	box("StoreFloor",Vector3(-1.2,0.32,-1.75),Vector3(8.05,0.12,5.75),Color("d9cdaa"),store,0.22,0.03)
	box("BackWall",Vector3(-1.2,1.78,-4.56),Vector3(8.05,2.85,0.18),cream,store,0.12,0.035,true)
	box("LeftWall",Vector3(-5.16,1.78,-1.75),Vector3(0.18,2.85,5.72),cream,store,0.12,0.035,true)
	for z in [-4.1,-3.4,-2.7,-2.0,-1.3,-0.6,0.1]:
		box("WallCladdingJoint",Vector3(-5.265,1.78,z),Vector3(0.012,2.6,0.015),Color("abada5"),store)
	box("RightSill",Vector3(2.76,0.52,-1.75),Vector3(0.15,0.34,5.7),steel,store)
	box("FrontSill",Vector3(-1.2,0.52,1.08),Vector3(8.0,0.34,0.15),steel,store)
	for x in [-5.10,-3.56,-1.93,-0.30,1.0,2.72]:
		box("FrontMullion",Vector3(x,1.67,1.11),Vector3(0.065,2.31,0.085),steel,store,0,0.008)
	for y in [0.68,2.8]:
		box("FrontFrame",Vector3(-1.2,y,1.12),Vector3(8.0,0.065,0.09),steel,store,0,0.007)
	for x in [-4.33,-2.74,-1.12,1.87]:
		glass_panel("RainOnFrontGlass",Vector3(x,1.74,1.13),1.5,2.05,store)
	for z in [-4.5,-2.67,-0.79,1.03]:
		box("SideMullion",Vector3(2.8,1.7,z),Vector3(0.09,2.25,0.07),steel,store,0,0.008)
	for z in [-3.61,-1.73,0.14]:
		var glass := glass_panel("RainOnSideGlass",Vector3(2.81,1.74,z),1.75,2.05,store)
		glass.rotation.y=PI/2
	for y in [0.68,2.8]:
		box("SideFrame",Vector3(2.8,y,-1.73),Vector3(0.09,0.065,5.64),steel,store,0,0.008)
	# Separate sliding panels with aluminium frames and warning decals.
	for index in 2:
		var x := 0.06+index*0.61
		var door := group("DoorLeft" if index==0 else "DoorRight",Vector3(x,0,1.155),store)
		glass_panel("DoorGlass",Vector3(0,1.54,0),0.60,2.23,door)
		for dx in [-0.31,0.31]: box("DoorRail",Vector3(dx,1.55,0.01),Vector3(0.034,2.26,0.04),steel,door,0,0.003)
		for y in [0.41,2.69]: box("DoorRail",Vector3(0,y,0.01),Vector3(0.64,0.04,0.04),steel,door,0,0.004)
		box("DoorSafetyStripe",Vector3(0,1.24,0.026),Vector3(0.60,0.075,0.01),mint,door,0.2,0.002)
		text3d("AutoDoorDecal","自動",Vector3(0,1.8,0.03),28,0.006,paper,door)
	box("DoorSensor",Vector3(0.38,2.76,1.17),Vector3(0.18,0.05,0.04),dark,store)
	box("DoorMat",Vector3(0.38,0.289,1.70),Vector3(1.34,0.021,0.56),dark,store,0,0.015)
	for i in range(10): box("MatGroove",Vector3(-0.20+i*0.12,0.302,1.70),Vector3(0.04,0.009,0.48),steel,store,0,0.002)
	# A shallow roof maintains the miniature silhouette and storefront visibility.
	box("RoofLip",Vector3(-1.2,3.01,-1.70),Vector3(8.65,0.28,6.20),Color("344857"),store,0,0.065,true)
	box("RoofMembrane",Vector3(-1.2,3.17,-1.90),Vector3(8.27,0.06,5.53),Color("63787a"),store,0,0.022)
	for x in [-5.32,2.93]: box("RoofParapet",Vector3(x,3.28,-1.9),Vector3(0.11,0.22,5.66),Color("9aaba3"),store)
	box("BackParapet",Vector3(-1.2,3.28,-4.67),Vector3(8.3,0.22,0.11),Color("9aaba3"),store)
	for x in [-3.3,0.7]:
		box("RoofVent",Vector3(x,3.32,-3.40),Vector3(0.90,0.26,0.62),steel,store,0,0.03,true)
		for z in range(8): box("VentLouver",Vector3(x,3.458,-3.65+z*0.07),Vector3(0.78,0.015,0.027),dark,store)
	# Subtle roof seams, downpipes and shallow rooftop water break the large silhouette.
	for z in [-4.03,-3.02,-2.01,-1.0,0.01]:
		box("RoofMembraneJoint",Vector3(-1.2,3.205,z),Vector3(8.0,0.005,0.012),Color("48676c"),store,0,0.001)
	puddle(store,Vector3(-2.75,3.209,-1.64),Vector2(2.05,1.38),Color(0.45,0.64,0.68,0.16))
	puddle(store,Vector3(1.46,3.210,-3.00),Vector2(1.13,1.77),Color(0.45,0.64,0.68,0.12))
	for x in [-5.29,2.90]:
		rod("RainDownpipe",Vector3(x,0.28,-4.30),Vector3(x,3.21,-4.30),0.041,steel,store)
		for y in [0.60,1.75,2.85]: ring("PipeClamp",Vector3(x,y,-4.30),0.046,0.009,cream.darkened(0.28),store)
	box("SideLightbox",Vector3(2.885,2.98,-1.60),Vector3(0.08,0.48,4.55),paper,store,0.55)
	box("SideSignStripe",Vector3(2.932,2.79,-1.60),Vector3(0.008,0.045,4.45),mint,store,0.5)
	var side_name := text3d("SideStoreName","雨宿り  MART",Vector3(2.942,3.00,-1.60),60,0.007,Color("277e82"),store)
	side_name.rotation.y=PI/2
	box("Lightbox",Vector3(-1.2,2.96,1.45),Vector3(8.45,0.59,0.30),paper,store,0.45,0.045,true)
	for y in [2.71,3.20]: box("SignTealStripe",Vector3(-1.2,y,1.614),Vector3(8.3,0.065,0.012),mint,store,0.65,0.006)
	box("SignOrangeStripe",Vector3(-1.2,2.78,1.622),Vector3(8.3,0.04,0.013),orange,store,0.38,0.005)
	text3d("StoreName","雨宿り  MART",Vector3(-1.52,3.003,1.637),76,0.010,Color("277e82"),store)
	text3d("Hours","24h",Vector3(2.10,3.00,1.637),52,0.007,orange,store)
	box("Awning",Vector3(-1.18,2.64,1.42),Vector3(8.47,0.065,0.92),mint.darkened(0.20),store,0,0.02)
	box("AwningRim",Vector3(-1.18,2.61,1.88),Vector3(8.48,0.10,0.06),steel,store)
	for x in [-4.82,2.50]:
		rod("AwningSupport",Vector3(x,2.1,1.12),Vector3(x,2.62,1.8),0.022,steel,store)
	box("UnderAwningLamp",Vector3(-1.2,2.59,1.55),Vector3(7.9,0.024,0.08),Color("fff0c7"),store,1.2)
	omni("EntranceWarmth",Vector3(-1,2.10,1.80),Color("ffc487"),2.2,5.0,store)
	omni("SignFlicker",Vector3(-1.3,3.02,1.86),Color("a3f5e0"),1.0,4.8,store)
	# Exterior window advertisements are small enough to leave most glass clear.
	poster(store,Vector3(-4.60,1.36,1.16),Vector2(0.40,0.59),"新発売",orange)
	poster(store,Vector3(2.02,1.35,1.16),Vector2(0.40,0.55),"お弁当",mint)

func poster(parent: Node, at: Vector3, dim: Vector2, words: String, color: Color) -> void:
	var p := group("Poster",at,parent)
	box("Paper",Vector3.ZERO,Vector3(dim.x,dim.y,0.01),paper,p,0.4,0.005)
	box("Header",Vector3(0,dim.y*0.32,0.007),Vector3(dim.x*0.96,dim.y*0.2,0.004),color,p,0.4,0.002)
	text3d("PosterHeadline",words,Vector3(0,dim.y*0.31,0.012),28,dim.x/105.0,paper,p)
	var icon := cylinder("FoodIllustration",Vector3(0,-dim.y*0.02,0.025),dim.x*0.22,0.008,orange.lightened(0.2),p)
	icon.rotation.x=PI/2
	for y in [-0.27,-0.37]: box("PosterPrint",Vector3(0,dim.y*y,0.01),Vector3(dim.x*0.70,0.012,0.003),steel,p,0,0.002)

func build_interior() -> void:
	var inside := group("DetailedInterior")
	# The ceiling is implied by rim lights: tall opaque ceilings would hide the contents.
	for x in range(16):
		box("FloorGrout",Vector3(-4.95+x*0.49,0.386,-1.72),Vector3(0.009,0.005,5.40),Color("b4ad96"),inside,0.12,0.001)
	for z in range(11):
		box("FloorGrout",Vector3(-1.2,0.387,-4.25+z*0.49),Vector3(7.7,0.005,0.009),Color("b4ad96"),inside,0.12,0.001)
	for x in [-3.8,-1.0,1.7]:
		box("InteriorTube",Vector3(x,2.87,-1.82),Vector3(0.12,0.055,4.70),paper,inside,1.0)
		omni("WarmInteriorLight",Vector3(x,2.35,-1.3),Color("ffdaa0"),1.65,4.0,inside)
	# Two small ceiling advertisements add detail without blocking the shelf sightlines.
	for x in [-2.80,0.32]:
		box("InteriorHangingLightbox",Vector3(x,2.55,-2.7),Vector3(1.14,0.30,0.07),orange if x<0 else mint,inside,0.3)
		text3d("InteriorPromotion","おいしい毎日" if x<0 else "HOT COFFEE",Vector3(x,2.55,-2.655),30,0.005,paper,inside)
	# Four stocked glass-front beverage refrigerator bays at the back.
	for bay in range(4):
		var x := -3.48+bay*1.17
		var fridge := group("BeverageFridge",Vector3(x,0,-4.03),inside)
		box("FridgeBody",Vector3(0,1.58,0),Vector3(1.13,2.35,0.64),steel,fridge,0,0.035,true)
		box("LuminousInterior",Vector3(0,1.59,0.34),Vector3(1.01,2.05,0.03),Color("bde0df"),fridge,0.55)
		for shelf in range(4):
			var y := 0.67+shelf*0.48
			box("FridgeShelf",Vector3(0,y,0.40),Vector3(1.03,0.035,0.22),paper,fridge,0.3)
			for col in range(6): bottle(fridge,Vector3(-0.41+col*0.162,y+0.13,0.47),col+shelf+bay)
		glass_panel("FridgeGlass",Vector3(0,1.61,0.60),1.01,2.10,fridge)
		box("FridgeHandle",Vector3(0.44,1.58,0.63),Vector3(0.03,0.48,0.035),paper,fridge)
		box("FridgeCategory",Vector3(0,2.77,0.34),Vector3(1.12,0.21,0.06),mint,fridge,0.6)
		text3d("FridgeHeader",["DRINKS","お茶","MILK","COFFEE"][bay],Vector3(0,2.77,0.38),28,0.005,paper,fridge)
	# Low front gondolas keep the warm interior readable from outside.
	for aisle in range(2):
		var g := group("StockedGondola",Vector3(-3.78+aisle*2.10,0,-1.88),inside)
		box("ShelfBase",Vector3(0,0.47,0),Vector3(1.72,0.16,1.00),steel,g,0,0.025,true)
		box("ShelfSpine",Vector3(0,1.04,-0.20),Vector3(1.68,1.05,0.055),cream,g,0.15)
		for level in range(3):
			var y := 0.57+level*0.36
			box("DisplayShelf",Vector3(0,y,0.15),Vector3(1.74,0.042,0.66),paper,g,0.16)
			box("ShelfLip",Vector3(0,y+0.015,0.48),Vector3(1.72,0.07,0.028),mint,g,0.16)
			for col in range(9):
				var x := -0.73+col*0.18
				for depth in range(2):
					package(g,Vector3(x,y+0.145,0.06+depth*0.22),Vector3(0.14,0.24,0.10),col+level*3+aisle)
			for col in range(6): box("PriceTicket",Vector3(-0.70+col*0.27,y+0.01,0.50),Vector3(0.14,0.037,0.006),paper,g,0.4,0.002)
		text3d("AisleCategory","お菓子" if aisle==0 else "日用品",Vector3(0,1.78,-0.20),36,0.005,paper,g)
		box("AisleCategoryBoard",Vector3(0,1.78,-0.23),Vector3(0.94,0.22,0.04),orange if aisle==0 else mint,g,0.15)
	# Window-facing bento and triangular onigiri display.
	var deli := group("BentoAndOnigiri",Vector3(-3.6,0,0.39),inside)
	box("DeliBody",Vector3(0,0.77,0),Vector3(2.6,0.76,0.68),cream,deli,0.18,0.035,true)
	for y in [0.80,1.14]:
		box("DeliTray",Vector3(0,y,0.02),Vector3(2.58,0.035,0.67),steel,deli)
		for col in range(8):
			var x := -1.09+col*0.31
			box("BentoBox",Vector3(x,y+0.062,0.15),Vector3(0.26,0.065,0.24),dark,deli)
			box("Rice",Vector3(x-0.065,y+0.10,0.15),Vector3(0.10,0.017,0.19),paper,deli,0.15,0.008)
			box("BentoTopping",Vector3(x+0.057,y+0.10,0.11),Vector3(0.09,0.021,0.11),orange,deli)
			box("Greens",Vector3(x+0.055,y+0.105,0.21),Vector3(0.085,0.025,0.055),mint.darkened(0.22),deli)
		for col in range(9):
			var riceball := cylinder("Onigiri",Vector3(-1.12+col*0.28,y+0.13,-0.12),0.10,0.16,paper,deli,0.0)
			riceball.mesh=riceball.mesh.duplicate()
			riceball.mesh.radial_segments=3
			riceball.rotation.y=PI/6
			box("NoriWrap",Vector3(-1.12+col*0.28,y+0.09,-0.02),Vector3(0.07,0.11,0.014),Color("314536"),deli)
	text3d("DeliLabel","お弁当  /  おにぎり",Vector3(0,0.71,0.35),36,0.006,orange,deli)
	# Checkout, monitor, scanner, coffee machine and detailed hot-food counter.
	var till := group("CheckoutAndCoffee",Vector3(1.53,0,-0.01),inside)
	box("CheckoutCabinet",Vector3(0,0.91,0),Vector3(1.65,1.05,0.80),mint.darkened(0.1),till,0.17,0.03,true)
	box("Countertop",Vector3(0,1.47,0),Vector3(1.83,0.075,0.91),paper,till,0.22,0.02)
	var screen := box("POSMonitor",Vector3(-0.44,1.70,-0.13),Vector3(0.37,0.27,0.04),dark,till,0,0.015)
	screen.rotation.x=-0.16
	box("POSDisplay",Vector3(-0.44,1.7,-0.103),Vector3(0.31,0.20,0.008),mint,till,0.4)
	rod("POSStand",Vector3(-0.44,1.48,-0.16),Vector3(-0.44,1.65,-0.16),0.025,steel,till)
	box("RegisterKeyboard",Vector3(-0.44,1.53,0.17),Vector3(0.31,0.04,0.17),steel,till)
	box("CoffeeMachine",Vector3(0.53,1.83,-0.04),Vector3(0.44,0.67,0.44),steel,till,0,0.025,true)
	box("CoffeeControls",Vector3(0.53,2.02,0.191),Vector3(0.25,0.09,0.01),mint,till,0.5)
	box("CoffeeRecess",Vector3(0.53,1.74,0.19),Vector3(0.29,0.25,0.012),dark,till)
	cylinder("CoffeeCup",Vector3(0.53,1.64,0.23),0.065,0.10,paper,till,0.085)
	text3d("CoffeeBrand","CAFE",Vector3(0.53,1.9,0.21),22,0.004,paper,till)
	box("OdenHeater",Vector3(-0.07,1.56,0.01),Vector3(0.48,0.12,0.44),steel,till)
	box("OdenBroth",Vector3(-0.07,1.63,0.01),Vector3(0.42,0.008,0.36),Color("967647"),till,0.2)
	for i in 3:
		rod("OdenPartition",Vector3(-0.24+i*0.14,1.64,-0.16),Vector3(-0.24+i*0.14,1.64,0.18),0.008,cream,till)
		for j in 2: sphere("OdenIngredient",Vector3(-0.20+i*0.13,1.65,-0.08+j*0.16),0.044,cream.lightened(i*0.07),till)
	text3d("CheckoutNumber","レジ  01",Vector3(0,1.14,0.414),36,0.006,paper,till)
	# Side magazine rack, ice cream chest and backroom door.
	var rack := group("MagazineRack",Vector3(2.21,0,-1.48),inside)
	box("MagazineStand",Vector3(0,0.88,0),Vector3(0.54,1.05,1.21),steel,rack)
	for row in 3:
		for col in 4:
			var book := box("MagazineCover",Vector3(0.30,0.72+row*0.30,-0.43+col*0.27),Vector3(0.04,0.31,0.23),[mint,orange,cream,Color("b989ad")][col],rack,0.2,0.003)
			book.rotation.z=-0.15
	box("IceCreamFreezer",Vector3(-4.40,0.86,-3.32),Vector3(1.0,0.93,1.12),paper,inside,0.17,0.03,true)
	box("FreezerGlassLid",Vector3(-4.40,1.34,-3.32),Vector3(0.92,0.025,1.0),mint,inside,0.22)
	text3d("FreezerLabel","ICE",Vector3(-4.40,0.94,-2.749),34,0.006,orange,inside)
	box("BackroomDoor",Vector3(-4.64,1.55,-4.445),Vector3(0.63,2.17,0.035),steel,inside)
	box("BackroomHandle",Vector3(-4.41,1.39,-4.410),Vector3(0.04,0.18,0.025),cream,inside)
	text3d("StaffDoorSign","STAFF",Vector3(-4.64,1.98,-4.414),26,0.004,paper,inside)
	poster(inside,Vector3(-1.47,2.51,-4.445),Vector2(0.58,0.34),"おすすめ",orange)
	for z in [-0.7,-1.0]:
		var arrow := box("FloorGuideArrow",Vector3(0.15,0.399,z),Vector3(0.04,0.008,0.22),orange,inside)
		arrow.rotation.y=0.4 if z==-0.7 else -0.4

func bottle(parent: Node, at: Vector3, index: int) -> void:
	var colors := [mint,orange,Color("cfb564"),Color("96b573"),Color("b092af"),paper]
	cylinder("DrinkBottle",at,0.055,0.20,colors[index%6],parent,0.043,0.15)
	cylinder("BottleCap",at+Vector3(0,0.115,0),0.031,0.035,paper,parent)
	box("DrinkLabel",at+Vector3(0,0,0.057),Vector3(0.064,0.052,0.004),paper,parent,0.3,0.001)

func package(parent: Node, at: Vector3, dim: Vector3, index: int) -> void:
	var colors := [Color("d79175"),Color("91b9a5"),Color("deb969"),Color("a59fbe"),Color("8fb3cd"),paper]
	box("SnackPacket",at,dim,colors[index%6],parent,0.20,0.012)
	box("PacketLogo",at+Vector3(0,dim.y*0.20,dim.z*0.51),Vector3(dim.x*0.73,dim.y*0.15,0.004),paper,parent,0.20,0.001)
	box("PacketPicture",at+Vector3(0,-dim.y*0.08,dim.z*0.52),Vector3(dim.x*0.42,dim.y*0.32,0.004),colors[(index+2)%6],parent,0.20,0.003)

func build_street() -> void:
	var street := group("StreetProps")
	build_vending(street,Vector3(-5.86,0.27,0.54))
	build_bicycle(street,Vector3(-2.02,0.28,1.87))
	build_umbrella_rack(street,Vector3(1.56,0.28,1.71))
	for x in [-4.93,-4.40]:
		box("RecyclingBin",Vector3(x,0.77,1.80),Vector3(0.43,0.97,0.45),cream.darkened(0.1),street,0,0.04,true)
		box("BinLid",Vector3(x,1.27,1.80),Vector3(0.46,0.09,0.48),steel,street)
		var opening := cylinder("BinOpening",Vector3(x,1.09,2.033),0.095,0.007,dark,street)
		opening.rotation.x=PI/2
		text3d("WasteLabel","PET" if x < -4.7 else "CAN",Vector3(x,0.84,2.033),22,0.005,steel,street)
	# Street guardrails turn the corner without cluttering the shop entrance.
	for x in [-0.1,1.2,2.5]:
		rod("GuardPost",Vector3(x,0.26,2.22),Vector3(x,0.92,2.22),0.042,cream,street)
	for y in [0.60,0.89]: rod("FrontGuardrail",Vector3(-0.1,y,2.22),Vector3(2.50,y,2.22),0.036,cream,street)
	for z in [-2.35,-1.03,0.30]: rod("SideGuardPost",Vector3(3.0,0.25,z),Vector3(3.0,0.92,z),0.042,cream,street)
	for y in [0.60,0.89]: rod("SideGuardrail",Vector3(3.0,y,-2.35),Vector3(3.0,y,0.30),0.036,cream,street)
	for x in [-6.02,2.43]: build_lamp(street,Vector3(x,0.28,2.08))
	build_utility_pole(street,Vector3(3.35,0.1,-4.99),5.60)
	build_utility_pole(street,Vector3(-5.91,0.27,-5.70),5.15)
	for offset in [0.0,0.18,0.36]:
		wire(street,Vector3(-5.91,5.36,-5.70+offset),Vector3(3.35,5.64,-4.99+offset),0.50)
		wire(street,Vector3(3.35,5.64,-4.99+offset),Vector3(5.95,4.50,6.00+offset),0.75)
	# Drain grates and a recessed manhole.
	for x in [-5.5,-1.5,2.7]: drain(street,Vector3(x,0.075,2.60),false)
	for z in [-4.0,-1.4]: drain(street,Vector3(3.32,0.075,z),true)
	cylinder("Manhole",Vector3(4.73,0.078,0.85),0.39,0.018,steel,street)
	ring("ManholeLip",Vector3(4.73,0.092,0.85),0.365,0.014,cream.darkened(0.35),street)
	for i in range(5): box("ManholeRidge",Vector3(4.73,0.098,0.63+i*0.105),Vector3(0.5,0.012,0.012),dark,street)
	# Road sign and a small animated traffic signal.
	var signs := group("StreetSigns",Vector3(3.26,0,-0.12),street)
	rod("SignPole",Vector3(0,0.08,0),Vector3(0,3.68,0),0.043,steel,signs)
	var disc := cylinder("SpeedLimitSign",Vector3(0,3.02,0.03),0.30,0.055,orange,signs)
	disc.rotation.x=PI/2
	var inner := cylinder("SpeedWhite",Vector3(0,3.02,0.065),0.25,0.006,paper,signs)
	inner.rotation.x=PI/2
	text3d("SpeedNumber","30",Vector3(0,3.03,0.074),40,0.009,steel,signs)
	box("DirectionSign",Vector3(0,3.58,0.04),Vector3(1.08,0.28,0.055),mint.darkened(0.3),signs)
	text3d("StreetName","さくら通り →",Vector3(0,3.59,0.078),28,0.005,paper,signs)
	var traffic := group("TrafficSignal",Vector3(6.33,0,-5.60),street)
	rod("SignalPole",Vector3(0,0.05,0),Vector3(0,3.86,0),0.05,steel,traffic)
	box("TrafficHousing",Vector3(-0.33,3.64,0),Vector3(0.94,0.30,0.29),dark,traffic,0,0.04,true)
	for i in 3:
		var bulb := sphere("SignalBulb"+str(i),Vector3(-0.61+i*0.28,3.64,0.16),0.09,[mint,orange,Color("dc7b91")][i],traffic,0.1)
		bulb.add_to_group("signal_bulbs",true)
	# Alley details: condensers, meter boxes, notice board, crates and planter.
	for x in [-3.60,0.08]:
		var ac := group("ACCondenser",Vector3(x,0.27,-5.20),street)
		box("ACBody",Vector3(0,0.50,0),Vector3(1.04,0.84,0.48),cream.darkened(0.08),ac,0,0.035,true)
		for sx in [-0.38,0.38]: box("ACFoot",Vector3(sx,0.10,0),Vector3(0.10,0.17,0.58),steel,ac)
		var fan := ring("ACFanGrille",Vector3(-0.12,0.52,0.25),0.28,0.016,steel,ac)
		fan.rotation.x=PI/2
		for i in range(9): rod("FanGrilleLine",Vector3(-0.36+i*0.06,0.29,0.27),Vector3(-0.36+i*0.06,0.75,0.27),0.006,steel,ac)
		for y in range(6): box("ACVent",Vector3(0.35,0.30+y*0.07,0.25),Vector3(0.15,0.015,0.012),steel,ac)
		rod("ACPipe",Vector3(0.52,0.40,0),Vector3(0.64,0.40,-0.18),0.035,cream,ac)
	var notice := group("CommunityNoticeboard",Vector3(-5.39,0.27,-2.39),street)
	notice.rotation.y=-PI/2
	for x in [-0.52,0.52]: rod("NoticeLeg",Vector3(x,0,0),Vector3(x,2.27,0),0.035,steel,notice)
	box("NoticeFrame",Vector3(0,1.71,0),Vector3(1.25,1.08,0.12),steel,notice,0,0.02,true)
	box("NoticeCork",Vector3(0,1.71,0.069),Vector3(1.13,0.94,0.01),Color("a8aa8a"),notice)
	poster(notice,Vector3(-0.27,1.77,0.08),Vector2(0.41,0.63),"お知らせ",mint)
	poster(notice,Vector3(0.26,1.68,0.08),Vector2(0.43,0.55),"夏まつり",orange)
	box("NoticeRoof",Vector3(0,2.33,0),Vector3(1.42,0.07,0.40),mint.darkened(0.30),notice)
	for z in [-4.1,-3.1]:
		box("DeliveryCrate",Vector3(-5.85,0.50,z),Vector3(0.66,0.44,0.60),mint.darkened(0.2),street)
		for i in range(5): box("CrateSlot",Vector3(-6.187,0.51,z-0.23+i*0.115),Vector3(0.01,0.19,0.053),dark,street)
	for at in [Vector3(-6.17,0.28,1.66),Vector3(2.37,0.28,0.74),Vector3(-4.77,0.27,-5.53)]:
		cylinder("Planter",at+Vector3(0,0.16,0),0.22,0.32,orange.darkened(0.35),street,0.28)
		cylinder("PlanterSoil",at+Vector3(0,0.33,0),0.24,0.015,dark,street)
		for i in 7:
			var leaf := sphere("PlantLeaf",at+Vector3(rng.randf_range(-0.16,0.16),rng.randf_range(0.40,0.63),rng.randf_range(-0.16,0.16)),0.11,mint.darkened(0.40+rng.randf()*0.1),street)
			leaf.scale.y=1.4
	box("MeterCabinet",Vector3(-3.50,1.8,-4.72),Vector3(0.46,0.72,0.19),steel,street)
	for y in [1.64,1.93]: cylinder("PowerMeter",Vector3(-3.50,y,-4.84),0.09,0.075,cream,street)
	rod("MeterConduit",Vector3(-3.5,0.28,-4.78),Vector3(-3.5,1.46,-4.78),0.024,steel,street)

func build_vending(parent: Node, at: Vector3) -> void:
	var v := group("VendingMachine",at,parent)
	box("VendingShell",Vector3(0,1.14,0),Vector3(0.91,2.28,0.68),Color("aa7189"),v,0,0.05,true)
	box("VendingLitDisplay",Vector3(-0.07,1.50,0.35),Vector3(0.66,1.17,0.022),Color("c8dcda"),v,0.68)
	for row in 3:
		for col in 4:
			bottle(v,Vector3(-0.31+col*0.16,1.10+row*0.34,0.41),row+col)
		box("VendingShelf",Vector3(-0.07,0.97+row*0.34,0.42),Vector3(0.69,0.03,0.12),paper,v,0.4)
		for col in 4: box("SelectionButton",Vector3(-0.30+col*0.16,0.94+row*0.34,0.47),Vector3(0.11,0.04,0.009),mint,v,0.4)
	box("VendingPaymentPanel",Vector3(0.34,0.94,0.37),Vector3(0.11,0.40,0.016),dark,v)
	box("VendingCoinSlot",Vector3(0.34,1.04,0.383),Vector3(0.063,0.018,0.009),cream,v)
	box("VendingPickup",Vector3(-0.04,0.36,0.354),Vector3(0.62,0.21,0.018),dark,v)
	box("VendingHeader",Vector3(0,2.09,0.36),Vector3(0.76,0.20,0.022),paper,v,0.6)
	text3d("VendingName","DRINKS",Vector3(0,2.09,0.378),32,0.004,mint.darkened(0.35),v)
	omni("VendingGlow",Vector3(0,1.3,0.70),Color("ca9cc8"),0.7,2.5,v)

func build_bicycle(parent: Node, at: Vector3) -> void:
	var bike := group("Bicycle",at,parent)
	bike.rotation.y=-0.12
	for x in [-0.60,0.60]:
		var tire := ring("BicycleTire",Vector3(x,0.38,0),0.35,0.035,dark,bike)
		tire.rotation.x=PI/2
		var rim := ring("BicycleRim",Vector3(x,0.38,0.006),0.31,0.014,cream,bike)
		rim.rotation.x=PI/2
		for i in 12:
			var theta := TAU*i/12
			rod("WheelSpoke",Vector3(x,0.38,0.012),Vector3(x+cos(theta)*0.30,0.38+sin(theta)*0.30,0.012),0.003,steel,bike)
	var rear := Vector3(-0.60,0.38,0)
	var crank := Vector3(-0.08,0.34,0)
	var seat := Vector3(-0.24,0.89,0)
	var stem := Vector3(0.39,0.97,0)
	var front := Vector3(0.60,0.38,0)
	for pair in [[rear,crank],[crank,seat],[rear,seat],[seat,stem],[crank,stem],[stem,front]]: rod("BikeFrame",pair[0],pair[1],0.025,mint,bike)
	box("BikeSaddle",Vector3(-0.25,0.96,0),Vector3(0.28,0.08,0.15),dark,bike)
	rod("HandleStem",stem,Vector3(0.38,1.15,0),0.019,steel,bike)
	rod("Handlebar",Vector3(0.38,1.15,-0.19),Vector3(0.38,1.15,0.19),0.019,steel,bike)
	box("BikeBasketBottom",Vector3(0.57,0.96,0),Vector3(0.31,0.035,0.34),steel,bike)
	for z in [-0.17,0.17]:
		for i in 5: rod("BasketSlat",Vector3(0.43+i*0.07,0.98,z),Vector3(0.43+i*0.07,1.18,z),0.006,steel,bike)
		rod("BasketRim",Vector3(0.40,1.18,z),Vector3(0.76,1.18,z),0.011,steel,bike)
	rod("Kickstand",crank,Vector3(-0.22,0.02,0.17),0.012,steel,bike)
	rod("PedalCrank",crank,Vector3(0.03,0.24,0.08),0.014,steel,bike)
	box("BikePedal",Vector3(0.03,0.24,0.10),Vector3(0.14,0.025,0.09),dark,bike)

func build_umbrella_rack(parent: Node, at: Vector3) -> void:
	var u := group("UmbrellaRack",at,parent)
	box("UmbrellaDripTray",Vector3(0,0.07,0),Vector3(0.56,0.14,0.40),steel,u)
	for x in [-0.25,0.25]:
		for z in [-0.17,0.17]: rod("UmbrellaRackLeg",Vector3(x,0.08,z),Vector3(x,0.62,z),0.012,cream,u)
	for z in [-0.17,0.17]: rod("UmbrellaRackRail",Vector3(-0.25,0.62,z),Vector3(0.25,0.62,z),0.016,cream,u)
	for i in range(4):
		var x := -0.18+i*0.115
		var color: Color = [mint,paper,Color("b592b7"),orange][i]
		var umbrella := cylinder("FoldedUmbrella",Vector3(x,0.45,0),0.046,0.68,color,u,0.011)
		umbrella.rotation.z=-0.10+i*0.035
		rod("UmbrellaShaft",Vector3(x,0.68,0),Vector3(x,0.86,0),0.01,cream,u)
		var handle := ring("UmbrellaHook",Vector3(x+0.02,0.86,0),0.035,0.008,color,u)
		handle.rotation.x=PI/2

func build_lamp(parent: Node, at: Vector3) -> void:
	var lamp := group("StreetLamp",at,parent)
	cylinder("LampBase",Vector3(0,0.10,0),0.15,0.20,steel,lamp)
	cylinder("LampPost",Vector3(0,1.93,0),0.055,3.8,steel,lamp)
	rod("LampArm",Vector3(0,3.78,0),Vector3(0.0,3.78,0.52),0.038,steel,lamp)
	box("LampHousing",Vector3(0,3.73,0.55),Vector3(0.34,0.16,0.50),steel,lamp,0,0.035,true)
	box("LampGlass",Vector3(0,3.63,0.55),Vector3(0.26,0.032,0.42),Color("ffe1a5"),lamp,1.4)
	omni("LampPool",Vector3(0,3.48,0.56),Color("ffcc8e"),1.9,5.0,lamp)

func build_utility_pole(parent: Node, at: Vector3, height: float) -> void:
	var pole := group("UtilityPole",at,parent)
	cylinder("ConcretePole",Vector3(0,height*0.5,0),0.095,height,Color("8b909c"),pole,0.067)
	for y in [0.42,0.66,0.90]: cylinder("PoleSafetyBand",Vector3(0,y,0),0.103,0.095,orange.darkened(0.16),pole)
	box("Crossarm",Vector3(0,height-0.08,0),Vector3(0.14,0.09,1.20),steel,pole)
	for z in [-0.36,0,0.36]:
		cylinder("CeramicInsulator",Vector3(0,height+0.03,z),0.065,0.15,cream,pole)
		for j in 3: ring("InsulatorRidge",Vector3(0,height+j*0.045,z),0.067,0.012,cream,pole)
	box("PoleTransformer",Vector3(-0.16,height-0.83,0),Vector3(0.43,0.58,0.35),steel,pole)
	for i in 10: rod("PoleClimbStep",Vector3(-0.12,1.32+i*0.27,0),Vector3(0.19,1.32+i*0.27,0),0.012,steel,pole)

func wire(parent: Node, a: Vector3, b: Vector3, sag: float) -> void:
	var previous := a
	for i in range(1,25):
		var t := i/24.0
		var p := a.lerp(b,t)-Vector3(0,sin(t*PI)*sag,0)
		rod("SaggingPowerWire",previous,p,0.014,dark,parent)
		previous=p

func drain(parent: Node, at: Vector3, side: bool) -> void:
	var d := group("DrainGrate",at,parent)
	if side: d.rotation.y=PI/2
	box("DrainRecess",Vector3.ZERO,Vector3(0.77,0.016,0.20),dark,d)
	for i in range(12): box("DrainSlat",Vector3(-0.35+i*0.064,0.014,0),Vector3(0.025,0.018,0.18),steel,d,0,0.002)

func puddle(parent: Node, at: Vector3, dim: Vector2, color: Color) -> void:
	var mesh := PlaneMesh.new()
	mesh.size=dim
	var m := ShaderMaterial.new()
	m.shader=PUDDLE
	m.set_shader_parameter("light_color",color)
	m.set_shader_parameter("phase",rng.randf()*TAU)
	var n := add_mesh("WetLightReflection",mesh,at,m,parent)
	n.rotation.y=rng.randf_range(-0.15,0.15)
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func build_weather() -> void:
	var weather := group("RainAndReflections")
	# Stylized broken light reflections remain readable from every orbit angle.
	for x in [-4.3,-2.7,-1.1,0.5,2.1]:
		puddle(weather,Vector3(x,0.085,3.20),Vector2(1.0,2.0),Color(0.96,0.66,0.38,0.22))
		puddle(weather,Vector3(x+0.10,0.087,4.30),Vector2(0.70,1.3),Color(0.44,0.80,0.74,0.11))
	for z in [-3.5,-2.0,-0.5,1.0]: puddle(weather,Vector3(4.22,0.086,z),Vector2(1.3,0.78),Color(0.34,0.73,0.77,0.19))
	puddle(weather,Vector3(-5.87,0.087,3.33),Vector2(0.87,1.27),Color(0.77,0.49,0.75,0.20))
	puddle(weather,Vector3(2.7,0.09,3.83),Vector2(0.72,1.35),Color(0.96,0.77,0.43,0.21))
	# Rain is a single MultiMesh, animated in the vertex shader; no hundreds of update nodes.
	var rain_shader := Shader.new()
	rain_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
void vertex() {
    float height = INSTANCE_CUSTOM.x*6.0 + TIME*(4.0+INSTANCE_CUSTOM.y*2.5);
    float fall = 6.4-mod(height,6.4-INSTANCE_CUSTOM.z*3.12);
    VERTEX.y += fall;
    VERTEX.x -= fall*0.035;
}
void fragment() { ALBEDO=vec3(0.66,0.80,0.90); ALPHA=0.24; }
"""
	var rm := ShaderMaterial.new()
	rm.shader=rain_shader
	var drop_mesh := BoxMesh.new()
	drop_mesh.size=Vector3(0.010,0.18,0.006)
	var mm := MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_custom_data=true
	mm.mesh=drop_mesh
	# Each rain column terminates at either street level or rooftop level.
	var positions: Array[Vector3] = []
	var roof_columns: Array[bool] = []
	for i in range(1150):
		var x := rng.randf_range(-6.8,6.8)
		var z := rng.randf_range(-6.8,6.8)
		positions.append(Vector3(x,0.20,z))
		roof_columns.append(x > -5.55 and x < 3.15 and z > -4.86 and z < 1.94)
	mm.instance_count=positions.size()
	for i in positions.size():
		mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,positions[i]))
		mm.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),1.0 if roof_columns[i] else 0.0,1))
	var rain := MultiMeshInstance3D.new()
	rain.name="ContinuousRain"
	rain.multimesh=mm
	rain.material_override=rm
	rain.custom_aabb=AABB(Vector3(-7,0,-7),Vector3(14,7,14))
	rain.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weather.add_child(rain)
	# Expanding ripple rings and drops under the canopy.
	for i in 26:
		var x := rng.randf_range(-6.5,6.5)
		var z := rng.randf_range(2.7,6.3) if i < 18 else rng.randf_range(-5.8,1.0)
		if i >= 18: x=rng.randf_range(3.6,6.5)
		var ripple := ring("PuddleRipple",Vector3(x,0.091,z),0.19,0.007,Color("87bec6"),weather,0.28)
		ripple.set_meta("phase",rng.randf()*2.5)
		ripple.add_to_group("rain_ripples",true)
		ripple.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 24:
		var d := sphere("EaveDrop",Vector3(-5.18+i*0.35,2.59,1.90),0.016,Color("aad1d6"),weather,0.15)
		d.scale.y=2.3
		d.set_meta("phase",rng.randf()*2.59)
		d.add_to_group("eave_drops",true)
		d.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func bind_animations() -> void:
	door_left=find_child("DoorLeft",true,false)
	door_right=find_child("DoorRight",true,false)
	sign_light=find_child("SignFlicker",true,false)
	for n in get_tree().get_nodes_in_group("rain_ripples"):
		if is_ancestor_of(n): ripples.append(n)
	for n in get_tree().get_nodes_in_group("eave_drops"):
		if is_ancestor_of(n): drops.append(n)
	for n in get_tree().get_nodes_in_group("signal_bulbs"):
		if is_ancestor_of(n): signal_bulbs.append(n)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	elapsed += delta
	var cycle := fmod(elapsed,18.0)
	var opening := smoothstep(6.0,7.2,cycle)*(1.0-smoothstep(10.3,11.5,cycle))
	door_left.position.x=0.06-opening*0.54
	door_right.position.x=0.67+opening*0.54
	sign_light.light_energy=0.98+sin(elapsed*1.7)*0.025
	if fmod(elapsed,23.0)>22.75: sign_light.light_energy=0.77+sin(elapsed*62)*0.12
	for ripple in ripples:
		var phase := fmod(elapsed+float(ripple.get_meta("phase")),2.5)/2.5
		ripple.scale=Vector3.ONE*(0.12+phase*1.7)
		ripple.visible=phase < 0.82
	for drop in drops:
		drop.position.y=2.57-fmod(elapsed*2.25+float(drop.get_meta("phase")),2.28)
	var active := 0 if fmod(elapsed,25.0)<12.0 else (1 if fmod(elapsed,25.0)<14.0 else 2)
	for i in signal_bulbs.size():
		var colors := [mint,orange,Color("dc7b91")]
		signal_bulbs[i].material_override=mat(colors[i],0.8 if i==active else 0.02)
