extends RefCounted
## Restaurant finish: shared materials, bounded reflections and static instancing.
const SURFACE=preload("res://assets/modern/shaders/restaurant_surface.gdshader")
const FLOOR=preload("res://assets/modern/shaders/restaurant_floor.gdshader")
const GRAIN_DIR="res://assets/modern/wall_surfaces/"
const BATCH_IDS=["restaurant_booth_set","restaurant_bistro_set","restaurant_kitchen_island","restaurant_pantry_shelf","restaurant_pastry_table","restaurant_service_cart","restaurant_herb_rack"]
static var materials: Dictionary={}
static var lit_shader: Shader

static func active(game: Node) -> bool:
	return str(game.get("location_id")).begins_with("restaurant_")

static func floor_material(style: String) -> ShaderMaterial:
	var key:="floor_"+style
	if materials.has(key):return materials[key]
	var result:=ShaderMaterial.new();result.shader=FLOOR;result.resource_name="restaurant_floor_"+style
	var color:=Color("c6bea9") if style=="herringbone" else Color("d4ceba")
	result.set_shader_parameter("base_color",Vector3(color.r,color.g,color.b)*.84)
	result.set_shader_parameter("diagonal",style=="herringbone")
	result.set_shader_parameter("wood_grain",load(GRAIN_DIR+"oak_fine_v1.png"))
	materials[key]=result;return result

static func surface(source: StandardMaterial3D, role: String="") -> Material:
	var name: String=role if not role.is_empty() else source.resource_name
	var key:="surface_"+name+str(source.albedo_color)+str(source.disable_receive_shadows)
	if materials.has(key):return materials[key]
	if source.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return source
	var kind:=-1
	if name in ["decor_aaa493_matte","wood","woodlight"]:kind=0
	elif name.ends_with("_fabric"):kind=1
	elif name in ["silver","decor_9aadb8_metal"]:kind=2
	if kind>=0:
		var result:=ShaderMaterial.new();result.resource_name="restaurant_"+name
		if source.disable_receive_shadows:result.shader=SURFACE
		else:
			if lit_shader==null:
				lit_shader=Shader.new();lit_shader.code=SURFACE.code.replace(", shadows_disabled","")
			result.shader=lit_shader
		var tint: Color=source.albedo_color
		if kind==2:tint=Color("b7c5c9")
		result.set_shader_parameter("base_color",Vector3(tint.r,tint.g,tint.b))
		result.set_shader_parameter("finish_type",kind)
		result.set_shader_parameter("grain_texture",load(GRAIN_DIR+("linen_bluegrey" if kind==1 else "oak_fine")+"_v1.png"))
		result.set_shader_parameter("grain_mean",.658 if kind==1 else .721)
		result.set_shader_parameter("roughness_value",.91 if kind==1 else (.31 if kind==2 else .64))
		result.set_shader_parameter("metallic_value",.72 if kind==2 else 0.)
		result.set_shader_parameter("specular_value",.13 if kind==1 else .38)
		materials[key]=result;return result
	var result: StandardMaterial3D=source.duplicate()
	if name in ["decor_d8dcd8_matte","white","ivory","cream"]:
		result.roughness=.48;result.metallic_specular=.32
	elif name.ends_with("_metal") or name in ["metal","graphite","gunmetal"]:
		# Dark powder-coated frames remain dielectric, unlike exposed steel.
		result.metallic=0.;result.roughness=.52;result.metallic_specular=.32
	materials[key]=result;return result

static func prepare_surfaces(world: Node3D) -> void:
	for mesh: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is StandardMaterial3D:
			mesh.material_override=surface(mesh.material_override)
		elif mesh.material_override==null:
			for index in mesh.mesh.get_surface_count():
				var original:=mesh.get_active_material(index)
				var authored: Material=mesh.mesh.surface_get_material(index)
				var role: String=authored.resource_name if authored else ""
				if original is StandardMaterial3D:mesh.set_surface_override_material(index,surface(original,role))

static func install(game: Node3D, atmosphere: Node3D) -> void:
	var holder:=Node3D.new();holder.name="RestaurantLighting";atmosphere.add_child(holder)
	# Camera-only contact shading must not be captured into six cubemap faces.
	var camera: Camera3D=game.get("camera")
	var contact: MeshInstance3D=camera.get_node_or_null("DirectionalContact")
	if contact:contact.layers=1<<19
	var window_count:=0
	for window in game.get("shell").find_children("*","Node3D",true,false):
		if not window.has_meta("restaurant_window"):continue
		var start: Vector3=window.get_meta("wall_start",window.position)
		var end: Vector3=window.get_meta("wall_end",window.position)
		var count: int=clampi(ceili(start.distance_to(end)/7.),1,2)
		for i in count:
			var point:=start.lerp(end,(float(i)+.5)/count)
			var inward:=Vector3.RIGHT if point.x<0 else Vector3.LEFT
			var light:=SpotLight3D.new();light.name="WindowKey_"+str(window_count)
			light.position=point+inward*.18+Vector3(0,1.15,0);holder.add_child(light)
			light.look_at(light.position+inward*4.5+Vector3(0,-1.05,0),Vector3.UP)
			light.spot_range=9.;light.spot_angle=68.;light.spot_angle_attenuation=.65;light.spot_attenuation=1.3
			light.light_color=Color("f7ead4");light.light_specular=.65
			light.light_cull_mask=1<<17
			light.set_meta("restaurant_window",true);light.set_meta("finish_tint",true);light.set_meta("fixture_weight",1.)
			window_count+=1
	# The soft window fill is restricted to glazed dining rooms. The sun and
	# practical lamps supply the real cast shadows, avoiding extra shadow maps.
	var shell: Node3D=game.get("shell")
	var zones: Array=game.get("room_zones")
	for index in zones.size():
		if str(zones[index].kind) not in ["restaurant_dining","restaurant_lounge"]:continue
		var floor_node:=shell.get_node_or_null("RoomFloor_"+str(index)) as MeshInstance3D
		if floor_node:floor_node.layers|=1<<17
		var group:=shell.get_node_or_null("RestaurantGroup_"+str(index))
		if group:
			for mesh: MeshInstance3D in group.find_children("*","MeshInstance3D",true,false):mesh.layers|=1<<17
	var probes:=0
	for kind in ["restaurant_kitchen","restaurant_dining"]:
		var choice: Dictionary={};var area:=0.
		for zone in game.get("room_zones"):
			if str(zone.kind)!=kind:continue
			var rect: Rect2=zone.rect
			if rect.get_area()>area:choice=zone;area=rect.get_area()
		if choice.is_empty():continue
		var rect: Rect2=choice.rect
		var probe:=ReflectionProbe.new();probe.name="RestaurantReflection_"+str(probes)
		probe.position=Vector3(rect.get_center().x,1.3,rect.get_center().y)
		probe.size=Vector3(rect.size.x+.4,4.,rect.size.y+.4)
		probe.box_projection=true;probe.interior=false;probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED
		probe.intensity=.75 if kind=="restaurant_kitchen" else .45
		probe.blend_distance=1.2;probe.enable_shadows=false;probe.max_distance=18.
		probe.cull_mask=(1<<19)-1
		probe.update_mode=ReflectionProbe.UPDATE_ONCE;probe.set_meta("capture_step",-1)
		holder.add_child(probe);probes+=1
	game.get("shell").set_meta("restaurant_finish",{"windows":window_count,"probes":probes,"batched_meshes":0,"batch_groups":0})

static func apply_lighting(atmosphere: Node3D, night: float, enabled: bool) -> void:
	var game: Node=atmosphere.get("game")
	var environment: Environment=atmosphere.get("environment")
	if not active(game):environment.adjustment_enabled=false;atmosphere.get("sun").light_specular=.20;return
	var sun: DirectionalLight3D=atmosphere.get("sun")
	sun.light_specular=.52
	var basement: bool=str(game.get("location_id"))=="restaurant_b1"
	if not basement:
		environment.ambient_light_energy*=.94
		environment.ambient_light_sky_contribution=lerpf(.32,.20,night)
	environment.adjustment_enabled=enabled
	environment.adjustment_brightness=lerpf(1.045,1.025,night)
	environment.adjustment_contrast=1.025;environment.adjustment_saturation=1.035
	for lamp: Light3D in atmosphere.get("lamps"):
		if lamp.has_meta("restaurant_window"):
			lamp.light_energy=.20*pow(1.-night,1.5) if enabled else 0.
			lamp.visible=enabled and night<.995;lamp.shadow_enabled=false
			continue
		var kitchen: bool=lamp.global_position.x>3 and lamp.global_position.z< -5
		if kitchen:lamp.light_color=Color("edf0eb")
		lamp.light_specular=.55
		if not basement:lamp.light_energy=lerpf(.13 if kitchen else .085,.76,night)*float(lamp.get_meta("fixture_weight",1.))
	var holder:=atmosphere.get_node_or_null("RestaurantLighting")
	if holder==null:return
	var step:=roundi(night*4.)
	for probe: ReflectionProbe in holder.find_children("*","ReflectionProbe",true,false):
		probe.visible=enabled
		if enabled and int(probe.get_meta("capture_step"))!=step:
			probe.set_meta("capture_step",step)
			# UPDATE_ONCE recaptures after a transform change, not every frame.
			probe.position.x+=.0001 if step%2==0 else -.0001

static func batch_static(game: Node3D) -> void:
	var removed:=0;var batches:=0
	for group in game.get("shell").find_children("RestaurantGroup_*","Node3D",true,false):
		var buckets: Dictionary={}
		for object in group.get_children():
			if not str(object.get_meta("decor_id","")) in BATCH_IDS:continue
			for mesh: MeshInstance3D in object.find_children("*","MeshInstance3D",true,false):
				if mesh.mesh==null or mesh.skin!=null or not mesh.visible:continue
				var key:=str(mesh.mesh.get_instance_id())+str(mesh.cast_shadow)
				key+=str(mesh.material_override.get_instance_id()) if mesh.material_override else "none"
				for surface_index in mesh.mesh.get_surface_count():
					var material:=mesh.get_active_material(surface_index)
					key+=str(material.get_instance_id()) if material else "empty"
				if not buckets.has(key):buckets[key]=[]
				buckets[key].append(mesh)
		for key in buckets:
			var originals: Array=buckets[key]
			if originals.size()<3:continue
			var first: MeshInstance3D=originals[0]
			if not first.mesh is ArrayMesh:continue
			var mesh: ArrayMesh=first.mesh.duplicate()
			for surface_index in mesh.get_surface_count():mesh.surface_set_material(surface_index,first.get_active_material(surface_index))
			var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D
			multimesh.mesh=mesh;multimesh.instance_count=originals.size()
			var bounds:=AABB();var index:=0
			for original: MeshInstance3D in originals:
				var transform: Transform3D=group.global_transform.affine_inverse()*original.global_transform
				multimesh.set_instance_transform(index,transform)
				var box: AABB=transform*original.get_aabb()
				bounds=box if index==0 else bounds.merge(box)
				original.hide();index+=1
			multimesh.custom_aabb=bounds
			var instance:=MultiMeshInstance3D.new();instance.name="StaticFurnitureBatch_"+str(batches)
			instance.multimesh=multimesh;instance.material_override=first.material_override;instance.cast_shadow=first.cast_shadow
			instance.layers=first.layers
			group.add_child(instance);removed+=originals.size()-1;batches+=1
	var report: Dictionary=game.get("shell").get_meta("restaurant_finish",{})
	report.batched_meshes=removed;report.batch_groups=batches
	game.get("shell").set_meta("restaurant_finish",report)
