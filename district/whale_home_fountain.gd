extends Node3D
## A hollow stone basin with a quiet, independently animated water circuit.
const Geo = preload("res://district/story_geometry.gd")
const WATER = preload("res://assets/whale_home/fountain_water.gdshader")
const SPRAY = preload("res://assets/whale_home/fountain_spray.gdshader")
const CREAM := Color("e8ddc6")
const IVORY := Color("f6eddc")
const SHADOW := Color("c8bfaa")
const BLUE := Color("769fb7")
const BEADS_PER_STREAM := 2
var water_time := 0.0
var pool_material: ShaderMaterial
var stream_material: ShaderMaterial
var paths: Array[PackedVector3Array] = []
var droplets: MultiMeshInstance3D

func build(builder) -> void:
	_basin(builder)
	var whale: Node3D = _sculpture(builder)
	var water := Node3D.new(); water.name = "FountainMovingWater"
	water.set_meta("home_dynamic", true); add_child(water)
	pool_material = ShaderMaterial.new(); pool_material.shader = WATER
	stream_material = ShaderMaterial.new(); stream_material.shader = SPRAY
	stream_material.render_priority = 1
	_water_disk(water, 2.045, .57, "LowerBluePool")
	_water_disk(water, .92, 1.60, "UpperCatchingBowl")
	for i in 4:
		var angle: float = i * TAU / 4.0 + .20
		var direction := Vector3(cos(angle),0,sin(angle))
		paths.append(PackedVector3Array([direction*1.02+Vector3.UP*1.63,direction*1.44+Vector3.UP*1.50,direction*1.55+Vector3.UP*.58]))
	var spout: Vector3 = whale.transform * Vector3(0,1.48,.34)
	for side: float in [-1.0,1.0]:
		paths.append(PackedVector3Array([spout,spout+Vector3(side*.40,.58,-.24),Vector3(side*.70,1.62,.10)]))
	_streams(water)
	_droplets(water)
	advance(0.0)

func _basin(builder) -> void:
	_lathe("ChamferedCircularFoot",PackedVector2Array([Vector2(0,.06),Vector2(2.70,.06),Vector2(2.78,.11),Vector2(2.78,.18),Vector2(2.67,.23),Vector2(0,.23)]),CREAM)
	_lathe("HollowStonePool",PackedVector2Array([Vector2(0,.19),Vector2(2.28,.19),Vector2(2.35,.25),Vector2(2.35,.45),Vector2(2.42,.51),Vector2(2.42,.62),Vector2(2.36,.69),Vector2(2.14,.69),Vector2(2.08,.61),Vector2(2.05,.32),Vector2(0,.32)]),IVORY)
	_lathe("BlueGlazedInnerBand",PackedVector2Array([Vector2(2.084,.605),Vector2(2.068,.43)]),BLUE)
	for i in 16:
		var angle: float = i*TAU/16.0
		var d := Vector3(cos(angle),0,sin(angle))
		Geo.rod(self,d*2.16+Vector3.UP*.697,d*2.35+Vector3.UP*.697,.006,SHADOW)
		Geo.rod(self,d*2.354+Vector3.UP*.27,d*2.354+Vector3.UP*.44,.006,SHADOW)
	_lathe("TurnedFountainPedestal",PackedVector2Array([Vector2(0,.32),Vector2(.47,.32),Vector2(.51,.44),Vector2(.48,.55),Vector2(.33,.64),Vector2(.25,.78),Vector2(.23,1.20),Vector2(.33,1.34),Vector2(.39,1.39),Vector2(0,1.39)]),CREAM)
	for i in 12:
		var angle: float = i*TAU/12.0
		var d := Vector3(cos(angle),0,sin(angle))
		Geo.rod(self,d*.252+Vector3.UP*.77,d*.235+Vector3.UP*1.20,.012,IVORY)
	_lathe("CarvedUpperBowl",PackedVector2Array([Vector2(0,1.17),Vector2(.32,1.17),Vector2(.47,1.25),Vector2(.70,1.34),Vector2(.91,1.48),Vector2(1.04,1.58),Vector2(1.04,1.67),Vector2(.96,1.69),Vector2(.91,1.57),Vector2(.69,1.43),Vector2(0,1.39)]),IVORY)
	for i in 4:
		var angle: float = i*TAU/4.0+.20
		var d := Vector3(cos(angle),0,sin(angle))
		Geo.rod(self,d*.98+Vector3.UP*1.635,d*1.06+Vector3.UP*1.635,.024,CREAM)
	_lathe("LowLeafyGardenRing",PackedVector2Array([Vector2(2.40,.23),Vector2(2.76,.23),Vector2(2.79,.30),Vector2(2.71,.42),Vector2(2.54,.43),Vector2(2.43,.35),Vector2(2.40,.23)]),Color("83a877"))
	for i in 24:
		var angle: float = i*TAU/24.0
		var point := Vector3(cos(angle)*(2.61+sin(i*1.7)*.025),.41,sin(angle)*(2.61+sin(i*1.7)*.025))
		builder.Pastel.clump(self,point,Vector3(.54,.20+float(i%3)*.025,.46),Color("88aa7b") if i%3 else Color("9bb588"))
		if i%4==0:
			for j in 3:builder._flower(self,point+Vector3((j-1)*.10,.15,cos(j*2.0)*.08),Color("e7a5bb") if j%2 else IVORY,.10+float(j%2)*.025)

func _sculpture(builder) -> Node3D:
	_lathe("SculptureWavePlinth",PackedVector2Array([Vector2(0,1.39),Vector2(.24,1.39),Vector2(.26,1.57),Vector2(.16,1.78),Vector2(0,1.78)]),CREAM)
	var whale := Node3D.new(); whale.name="IvoryLeapingWhale";whale.rotation.y=deg_to_rad(35)
	whale.scale=Vector3(.92,1.15,.92);whale.position=Vector3(sin(whale.rotation.y)*.43,1.60,cos(whale.rotation.y)*.43);add_child(whale)
	var sections: Array = [[Vector3(0,.10,-.40),Vector2(.055,.065)],[Vector3(0,.27,-.55),Vector2(.10,.10)],[Vector3(0,.62,-.47),Vector2(.19,.20)],[Vector3(0,.94,-.22),Vector2(.29,.32)],[Vector3(0,1.10,.10),Vector2(.34,.34)],[Vector3(0,1.21,.43),Vector2(.31,.27)],[Vector3(0,1.23,.70),Vector2(.23,.17)],[Vector3(0,1.23,.85),Vector2(.015,.025)]]
	_loft(whale,"CurvedCarvedWhaleBody",sections,Vector3.RIGHT)
	for side: float in [-1.0,1.0]:
		_loft(whale,"RoundedPectoralFin",[[Vector3(side*.20,1.03,-.12),Vector2(.10,.045)],[Vector3(side*.40,.99,-.06),Vector2(.15,.055)],[Vector3(side*.64,.82,.02),Vector2(.12,.045)],[Vector3(side*.76,.63,.10),Vector2(.055,.025)],[Vector3(side*.77,.54,.09),Vector2(.005,.005)]],Vector3.BACK)
		_loft(whale,"SweptTailFluke",[[Vector3(side*.015,.14,-.44),Vector2(.06,.04)],[Vector3(side*.25,.26,-.60),Vector2(.13,.045)],[Vector3(side*.52,.42,-.76),Vector2(.18,.05)],[Vector3(side*.72,.48,-.94),Vector2(.012,.012)]],Vector3.BACK)
		builder._sphere(whale,Vector3(side*.278,1.29,.55),Vector3(.04,.045,.027),Color("87979b"))
	_loft(whale,"CarvedDorsalFin",[[Vector3(0,.88,-.41),Vector2(.05,.08)],[Vector3(0,1.05,-.56),Vector2(.035,.06)],[Vector3(0,1.18,-.66),Vector2(.004,.004)]],Vector3.RIGHT)
	return whale

func _loft(parent: Node3D, label: String, sections: Array, preferred_axis: Vector3) -> void:
	var curved_sections: Array = []
	for i in sections.size()-1:
		for step in 3:
			var point: Vector3 = sections[i][0].cubic_interpolate(sections[i+1][0],sections[maxi(0,i-1)][0],sections[mini(i+2,sections.size()-1)][0],step/3.0)
			var radius: Vector2 = sections[i][1].cubic_interpolate(sections[i+1][1],sections[maxi(0,i-1)][1],sections[mini(i+2,sections.size()-1)][1],step/3.0)
			curved_sections.append([point,radius])
	curved_sections.append(sections.back());sections=curved_sections
	var rings: Array[PackedVector3Array] = []
	for i in sections.size():
		var point: Vector3 = sections[i][0]
		var tangent: Vector3 = (sections[mini(i+1,sections.size()-1)][0]-sections[maxi(0,i-1)][0]).normalized()
		var right: Vector3 = (preferred_axis-tangent*tangent.dot(preferred_axis)).normalized()
		var up: Vector3 = tangent.cross(right).normalized()
		var ring := PackedVector3Array()
		for side in 25:
			var angle: float = side*TAU/24.0
			ring.append(point+right*cos(angle)*sections[i][1].x+up*sin(angle)*sections[i][1].y)
		rings.append(ring)
	var normals: Array[PackedVector3Array] = []
	for row in rings.size():
		var ring_normals := PackedVector3Array()
		for side in 25:
			var around: Vector3 = rings[row][(side+1)%24]-rings[row][(side+23)%24]
			var along: Vector3 = rings[mini(row+1,rings.size()-1)][side]-rings[maxi(row-1,0)][side]
			var normal: Vector3 = around.cross(along).normalized()
			if normal.dot(rings[row][side]-sections[row][0])<0:normal=-normal
			ring_normals.append(normal)
		normals.append(ring_normals)
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rings.size()-1:
		for side in 24:
			var vertices: Array[Vector3] = [rings[row][side],rings[row][side+1],rings[row+1][side+1],rings[row+1][side]]
			var smooth_normals: Array[Vector3] = [normals[row][side],normals[row][side+1],normals[row+1][side+1],normals[row+1][side]]
			var indices: Array[int] = [0,1,2,0,2,3]
			if (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).dot(smooth_normals[0]+smooth_normals[2])>0:indices=[0,2,1,0,3,2]
			for index in indices:
				tool.set_normal(smooth_normals[index]);tool.set_uv(Vector2.ZERO);tool.add_vertex(vertices[index])
	for row in [0,rings.size()-1]:
		var direction: Vector3 = sections[row][0]-sections[1 if row==0 else row-1][0]
		for side in 24:Geo._face(tool,[sections[row][0],rings[row][side],rings[row][side+1]],direction.normalized())
	var body := MeshInstance3D.new();body.name=label;body.mesh=tool.commit();body.material_override=Geo.material(IVORY);parent.add_child(body)

func _lathe(label: String, profile: PackedVector2Array, color: Color) -> void:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in profile.size()-1:
		var a: Vector2 = profile[row]; var c: Vector2 = profile[row+1]
		for i in 64:
			var angle: float = i*TAU/64.0; var next: float = (i+1)*TAU/64.0
			var p := Vector3(cos(angle)*a.x,a.y,sin(angle)*a.x)
			var q := Vector3(cos(angle)*c.x,c.y,sin(angle)*c.x)
			var r := Vector3(cos(next)*c.x,c.y,sin(next)*c.x)
			var s := Vector3(cos(next)*a.x,a.y,sin(next)*a.x)
			var normal := Vector3(cos((angle+next)*.5)*(c.y-a.y),a.x-c.x,sin((angle+next)*.5)*(c.y-a.y)).normalized()
			if is_zero_approx(a.x):Geo._face(tool,[p,q,r],normal)
			elif is_zero_approx(c.x):Geo._face(tool,[p,q,s],normal)
			else:Geo._face(tool,[p,q,r,s],normal)
	var node := MeshInstance3D.new(); node.name = label; node.mesh = tool.commit()
	node.material_override = Geo.material(color); add_child(node)

func _water_disk(parent: Node3D, radius: float, y: float, label: String) -> void:
	var mesh := CylinderMesh.new(); mesh.bottom_radius=radius; mesh.top_radius=radius; mesh.height=.02; mesh.radial_segments=64
	var node := MeshInstance3D.new(); node.name=label; node.mesh=mesh; node.position.y=y-.01
	node.material_override=pool_material; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

func _curve(path: PackedVector3Array, t: float) -> Vector3:
	return path[0]*(1.0-t)*(1.0-t)+path[1]*2.0*(1.0-t)*t+path[2]*t*t

func _stream_ring(path: PackedVector3Array, t: float) -> PackedVector3Array:
	var tangent: Vector3 = ((path[1]-path[0])*(1.0-t)+(path[2]-path[1])*t).normalized()
	var right: Vector3 = (path[1]-path[0]).cross(path[2]-path[0]).normalized()
	var up: Vector3 = tangent.cross(right).normalized()
	var points := PackedVector3Array()
	for i in 7:
		var angle: float = i*TAU/6.0
		points.append(_curve(path,t)+(right*cos(angle)+up*sin(angle))*lerpf(.023,.011,t))
	return points

func _streams(parent: Node3D) -> void:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path_index in paths.size():
		var path: PackedVector3Array = paths[path_index]
		for row in 18:
			var t: float = row/18.0; var u: float = (row+1)/18.0
			var a: PackedVector3Array = _stream_ring(path,t); var c: PackedVector3Array = _stream_ring(path,u)
			for column in 6:
				var vertices: Array[Vector3] = [a[column],a[column+1],c[column+1],c[column]]
				var normals: Array[Vector3] = [(a[column]-_curve(path,t)).normalized(),(a[column+1]-_curve(path,t)).normalized(),(c[column+1]-_curve(path,u)).normalized(),(c[column]-_curve(path,u)).normalized()]
				var offset: float = path_index*.19
				var uvs: Array[Vector2] = [Vector2(column/6.0,t+offset),Vector2((column+1)/6.0,t+offset),Vector2((column+1)/6.0,u+offset),Vector2(column/6.0,u+offset)]
				for index in [0,1,2,0,2,3]:
					tool.set_normal(normals[index]);tool.set_uv(uvs[index]);tool.add_vertex(vertices[index])
	var node := MeshInstance3D.new(); node.name="CurvedSpoutsAndOverflow";node.mesh=tool.commit()
	node.material_override=stream_material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)

func _droplets(parent: Node3D) -> void:
	var sphere := SphereMesh.new(); sphere.radius=.012;sphere.height=.030;sphere.radial_segments=8;sphere.rings=4
	sphere.material=stream_material
	var multimesh := MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=sphere;multimesh.instance_count=paths.size()*BEADS_PER_STREAM
	droplets=MultiMeshInstance3D.new();droplets.name="FlowingWaterBeads";droplets.multimesh=multimesh
	droplets.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(droplets)

func advance(delta: float) -> void:
	if not is_visible_in_tree():return
	water_time += delta
	pool_material.set_shader_parameter("water_time",water_time)
	stream_material.set_shader_parameter("water_time",water_time)
	for i in paths.size()*BEADS_PER_STREAM:
		var path_index: int = i/BEADS_PER_STREAM
		var t: float = fposmod(water_time*.72+float(i%BEADS_PER_STREAM)/BEADS_PER_STREAM+path_index*.137,1.0)
		droplets.multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(1.15,1.45,1.15)),_curve(paths[path_index],t)))
