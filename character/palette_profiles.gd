extends RefCounted
## Direction-specific pigment matching. Identity values reset on every turn.
static func apply(material: ShaderMaterial,direction: String,manifest: Dictionary) -> void:
 var profile: Dictionary=manifest.get("palette_match_by_direction",{}).get(direction,{})
 material.set_shader_parameter("palette_match_enabled",profile.get("enabled",false))
 for key in ["hair_palette_gamma","skin_palette_gamma"]:
  var value: Array=profile.get(key,[1.0,1.0,1.0])
  material.set_shader_parameter(key,Vector3(value[0],value[1],value[2]))
 material.set_shader_parameter("hair_palette_strength",profile.get("hair_palette_strength",0.0))
 material.set_shader_parameter("skin_palette_strength",profile.get("skin_palette_strength",0.0))
 material.set_shader_parameter("soft_contour_strength",profile.get("contour_strength",.42))
 material.set_shader_parameter("soft_contour_width",profile.get("contour_width",1.8))
 var colour: Array=profile.get("contour_colour",[.10,.15,.22])
 material.set_shader_parameter("soft_contour_colour",Vector3(colour[0],colour[1],colour[2]))
