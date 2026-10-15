extends "res://district/harbor_terraces_controller.gd"
## Three physical floors, open stairwells, and automatic upper-floor cutaways.
const Home=preload("res://district/whale_home_map.gd")
const CONTACT=preload("res://assets/whale_home/contact.gdshader")
const Props=preload("res://assets/whale_home/pastel_props.gd")
const Coastal=preload("res://assets/whale_home/coastal_props.gd")
const SeaMotion=preload("res://assets/whale_home/coastal_motion.gd")
var fish: Array[Node3D] = []
var feeding := 0.0
var extra_lights := false
var notice := ""
var notice_time := 0.0
var garden_petals: MultiMeshInstance3D
var blossom_origins: Array[Vector3]=[]
var previous_contact: Shader
var moorings: Array=[]
var sea_motion := SeaMotion.new()
var sea_surface: MeshInstance3D
var coastal_materials: Array[ShaderMaterial]=[]

func is_active() -> bool:return is_instance_valid(level) and game.location_id=="whale_home"

func build() -> Dictionary:
	var result: Dictionary=Home.new().build(game)
	level=result.level;spawn=result.spawn;cutaway=HarborPrefs.values.follow
	boats.clear();fish.clear();gulls.clear();facilities.clear();sea_clock=0.0
	for node in level.find_children("*","Node3D",true,false):
		if node.has_meta("boat_origin"):boats.append(node)
		if node.has_meta("home_fish"):fish.append(node)
	for node in game.world.get_children():
		if node.has_meta("home_action"):facilities.append(node)
	extra_lights=bool(game.visited.get("whale_home:facility:star_lights",false))
	garden_petals=level.get_meta("garden_petals");blossom_origins=level.get_meta("blossom_origins")
	moorings=level.get_meta("home_moorings")
	sea_surface=level.get_node("Sea/CoastalOcean")
	sea_motion.configure(level.get_meta("sea_material"))
	sea_surface.extra_cull_margin=float(sea_motion.settings.wave_height)*(1.0+float(sea_motion.settings.crest_sharpness)*0.5)+.04
	coastal_materials.clear()
	for material: ShaderMaterial in Coastal.wood_materials.values():coastal_materials.append(material)
	coastal_materials.append_array(Coastal.stone_materials)
	_update_sea()
	previous_contact=game.atmosphere.contact_shading.material_override.shader
	var slabs: Array=level.get_meta("walkable_slabs",[])
	game.player.set_meta("floor_slabs",slabs);game.silhouette_body.set_meta("floor_slabs",slabs)
	game.player.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED
	game.player.collision_layer=4;game.player.collision_mask=3
	game.player.floor_snap_length=.35;game.player.floor_max_angle=deg_to_rad(48)
	game.player.floor_constant_speed=true;game._configure_character_collision(true)
	return result

func leave() -> void:
	super.leave();fish.clear();garden_petals=null;blossom_origins.clear();moorings.clear()
	sea_surface=null;coastal_materials.clear()
	game.atmosphere.contact_shading.material_override.shader=previous_contact
	game.atmosphere._apply_lighting()

func overview_center() -> Vector3:return Vector3(0,4.5,-4.5)

func set_layers() -> void:
	if not is_active():return
	for i in 3:level.get_node("Floor"+str(i)).visible=not cutaway or game.player.position.y+1.0>=i*Home.HEIGHT
	level.get_node("Roof").visible=not cutaway
	for facility in facilities:facility.visible=not cutaway or game.player.position.y+1.0>=float(facility.get_meta("floor_height",0.0))

func _process(delta: float) -> void:
	if not is_active() or (game.pause_menu and game.pause_menu.active):return
	sea_clock+=delta;feeding=maxf(0.0,feeding-delta);notice_time=maxf(0.0,notice_time-delta)
	_update_sea()
	game.atmosphere.contact_shading.material_override.shader=CONTACT
	garden_petals.visible=game.atmosphere.effects
	if garden_petals.visible:
		for i in garden_petals.multimesh.instance_count:
			var phase: float=i*2.3+sea_clock*.38
			var origin: Vector3=blossom_origins[i%blossom_origins.size()]
			var point: Vector3=origin+Vector3(sin(phase)*2.4,.45+fposmod(i*.52-sea_clock*.24,5.0),cos(phase*.7)*2.0)
			var basis:=Basis.from_euler(Vector3(sin(phase)*.55,phase,cos(phase)*.45))
			garden_petals.multimesh.set_instance_transform(i,Transform3D(basis,point))
	for i in fish.size():
		var swimmer: Node3D=fish[i]
		var origin: Vector3=swimmer.get_meta("home_fish")
		var t: float=sea_clock*(.8 if feeding>0 else .3)+i*1.5
		swimmer.position=origin+Vector3(sin(t)*.70,sin(t*1.4)*.12,cos(t)*.13)
		swimmer.rotation.y=0.0 if cos(t)>0 else PI
	var hour: float=game.atmosphere.hour
	var night: float=1.0-smoothstep(6.0,8.0,hour)*(1.0-smoothstep(17.0,20.0,hour))
	var water: ShaderMaterial=level.get_meta("sea_material")
	water.set_shader_parameter("night_weight",night)
	for lamp: OmniLight3D in level.get_meta("home_lights",[]):
		lamp.light_energy=lerpf(.07,.70,night)*float(lamp.get_meta("home_energy",1.0))
		lamp.shadow_enabled=false
		if lamp.has_meta("star_string"):lamp.light_energy=lerpf(.18,.7,night) if extra_lights else .015
	for halo in game.atmosphere.glows:
		var source: Node3D=halo.get_meta("source_lamp",null)
		halo.visible=game.atmosphere.effects and is_instance_valid(source) and source.is_visible_in_tree()
	if hour>=8.0 and hour<17.0:
		game.atmosphere.environment.background_color=Color("dcede5")
		game.atmosphere.environment.ambient_light_color=Color("d3e4d8")
		game.atmosphere.environment.ambient_light_energy=.35
		game.atmosphere.environment.ambient_light_sky_contribution=.32
		game.atmosphere.sun.light_energy=.40
		game.atmosphere.sun.light_color=Color("fff2dc")
		game.atmosphere.sun.shadow_opacity=.78
	# Read the final map lighting after its daytime override, not fixed shader colours.
	water.set_shader_parameter("sun_direction",game.atmosphere.sun.global_basis.z.normalized())
	water.set_shader_parameter("sun_colour",game.atmosphere.sun.light_color)
	water.set_shader_parameter("sun_energy",game.atmosphere.sun.light_energy)
	water.set_shader_parameter("sky_colour",game.atmosphere.environment.background_color)
	water.set_shader_parameter("ambient_colour",game.atmosphere.environment.ambient_light_color)
	water.set_shader_parameter("ambient_energy",game.atmosphere.environment.ambient_light_energy)
	var seabed: ShaderMaterial=level.get_meta("seabed_material")
	seabed.set_shader_parameter("night_weight",night)

func _update_sea() -> void:
	var height: float=sea_motion.mean_level(sea_clock)
	var water: ShaderMaterial=level.get_meta("sea_material")
	sea_surface.position.y=height
	water.set_shader_parameter("water_level",height)
	water.set_shader_parameter("wave_time",sea_clock)
	water.set_shader_parameter("tide_amount",.5+.5*sin(sea_clock*TAU/float(sea_motion.settings.tide_period)))
	var seabed: ShaderMaterial=level.get_meta("seabed_material")
	seabed.set_shader_parameter("wave_time",sea_clock)
	seabed.set_shader_parameter("water_level",height)
	var wet_height: float=sea_motion.wet_level(sea_clock)
	for material in coastal_materials:
		material.set_shader_parameter("water_level",height)
		material.set_shader_parameter("wet_level",wet_height)
	for boat in boats:
		var origin: Vector3=boat.get_meta("boat_origin")
		var surface: Vector3=sea_motion.sample(Vector2(origin.x,origin.z),sea_clock)
		boat.position=origin+Vector3.UP*(surface.x-float(sea_motion.settings.base_level))
		var yaw: float=boat.rotation.y
		var local_x: float=surface.y*cos(yaw)-surface.z*sin(yaw)
		var local_z: float=surface.y*sin(yaw)+surface.z*cos(yaw)
		boat.rotation.x=-atan(local_z)
		boat.rotation.z=atan(local_x)
	for mooring: Dictionary in moorings:
		Props.update_mooring(mooring.line,mooring.dock,mooring.eye.global_position)

func show_notice(text: String) -> void:notice=text;notice_time=6.0

func physics(delta: float) -> void:
	super.physics(delta)
	var y: float=game.player.position.y
	if y>.65 and absf(y-Home.HEIGHT)>.6 and absf(y-Home.HEIGHT*2)>.6:
		game.zone_label.text="当前："+("1F ↔ 2F · 海风木楼梯" if y<Home.HEIGHT else "2F ↔ 3F · 星光木楼梯")
	if notice_time>0:game.hint.text=notice
	elif not game.dialog_open:game.hint.text="WASD 漫步 · 楼梯直达三层 · E 家具交互 · H 楼层切面 · Z 总览 · M 导览"
