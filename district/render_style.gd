extends RefCounted
## Quiet hemisphere lighting; contact shading is explicitly surface-aware.
const ModelSurfaces=preload("res://district/model_surfaces.gd")

static func configure(environment: Environment) -> void:
	# S4AO darkens silhouettes by depth alone, including the clean top contour.
	# A separate normal-aware pass now limits this to ground and unlit side faces.
	environment.ssao_enabled=false
	var sky:=Sky.new()
	sky.radiance_size=Sky.RADIANCE_SIZE_128
	var material:=ProceduralSkyMaterial.new()
	material.sky_top_color=Color("9bb9d0")
	material.sky_horizon_color=Color("b4c2ca")
	material.ground_bottom_color=Color("324453")
	material.ground_horizon_color=Color("82939e")
	material.sky_energy_multiplier=.40
	material.ground_energy_multiplier=.11
	material.sun_angle_max=0.0
	sky.sky_material=material
	environment.sky=sky
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	# A modest hemisphere contribution separates top, side and underside planes.
	# The clock's ambient color remains the main fill, including at night.
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution=.42

static func set_reflection_time(environment: Environment,night: float,outside: bool) -> void:
	var material: ProceduralSkyMaterial=environment.sky.sky_material
	# Rebake the small reflection sky only on a lighting step, not every frame.
	var step:=roundi(night*16.0)+(32 if outside else 0)
	if int(material.get_meta("light_step",-1))==step:return
	material.set_meta("light_step",step)
	var weight:=roundf(night*16.0)/16.0
	material.sky_energy_multiplier=lerpf(.40,.12,weight)*(1.0 if outside else .85)
	material.ground_energy_multiplier=lerpf(.11,.04,weight)

static func prepare_surfaces(world: Node3D) -> void:
	# Glass should let the light through. Its frame still casts a proper shadow.
	for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		ModelSurfaces.apply(node)
		var glass_only:=node.mesh.get_surface_count()>0
		for surface in node.mesh.get_surface_count():
			var material:=node.get_active_material(surface)
			glass_only=glass_only and material is BaseMaterial3D and material.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS] and material.albedo_color.a<.5
		if glass_only:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
