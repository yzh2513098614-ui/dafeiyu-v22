extends RefCounted
## Shallow painted volume profiles, in each complete frame's UV coordinates.
## These describe lighting only; they never move a vertex or a joint.
const PROFILES: Dictionary={
	"down": [Vector4(.50,.33,.235,.19),Vector4(.50,.64,.235,.17),Vector4(.73,.77,.15,.15),Vector4(.50,.433,.125,.08)],
	"down_left": [Vector4(.47,.32,.225,.19),Vector4(.46,.63,.22,.17),Vector4(.76,.76,.16,.14),Vector4(.405,.43,.11,.08)],
	"left": [Vector4(.51,.32,.215,.20),Vector4(.48,.63,.205,.17),Vector4(.77,.76,.18,.15),Vector4(.385,.42,.09,.09)],
	"up_left": [Vector4(.55,.32,.215,.20),Vector4(.52,.63,.23,.17),Vector4(.72,.78,.19,.16),Vector4(.34,.41,.055,.07)],
	"up": [Vector4(.50,.33,.235,.20),Vector4(.50,.64,.235,.17),Vector4(.60,.79,.20,.19),Vector4(.50,.43,.0,.0)],
	"up_right": [Vector4(.45,.32,.215,.20),Vector4(.48,.63,.23,.17),Vector4(.28,.78,.19,.16),Vector4(.66,.41,.055,.07)],
	"right": [Vector4(.49,.32,.215,.20),Vector4(.52,.63,.205,.17),Vector4(.23,.76,.18,.15),Vector4(.615,.42,.09,.09)],
	"down_right": [Vector4(.53,.32,.225,.19),Vector4(.54,.63,.22,.17),Vector4(.24,.76,.16,.14),Vector4(.595,.43,.11,.08)]
}

static var edge_maps: Dictionary={}

static func apply(material: ShaderMaterial,direction: String,override_profile: Dictionary={},frame_index: int=0,walking: bool=false) -> void:
	var profile: Array=PROFILES[direction]
	material.set_shader_parameter("head_profile",profile[0])
	material.set_shader_parameter("body_profile",profile[1])
	material.set_shader_parameter("tail_profile",profile[2])
	material.set_shader_parameter("face_profile",profile[3])
	# Video pixels occupy a smaller area of the common canvas. These regions
	# calibrate lighting only; the whole frame and its animation are unchanged.
	for key in ["head","body","tail","face"]:
		if override_profile.has(key):
			var region: Array=override_profile[key]
			material.set_shader_parameter(key+"_profile",Vector4(region[0],region[1],region[2],region[3]))
	for key in ["head_split","hair_split","tail_split"]:
		var default_split: Array={"head_split":[.47,.60],"hair_split":[.56,.67],"tail_split":[.62,.71]}[key]
		var split: Array=override_profile.get(key,default_split)
		material.set_shader_parameter(key,Vector2(split[0],split[1]))
	var maps: Array=override_profile.get("edge_surface_maps",[])
	material.set_shader_parameter("edge_surface_enabled",not maps.is_empty())
	material.set_shader_parameter("edge_surface_strength",override_profile.get("edge_surface_strength",0.0))
	material.set_shader_parameter("edge_vignette_strength",override_profile.get("edge_vignette_strength",0.0))
	if not maps.is_empty():
		# Idle/interact use source walk_09, while walk uses every full video frame.
		var path: String=maps[frame_index if walking else 9]
		if not edge_maps.has(path):edge_maps[path]=load(path)
		material.set_shader_parameter("edge_surface_map",edge_maps[path])
