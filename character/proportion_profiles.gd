extends RefCounted
## Fixed per-direction display proportions. Never changes a source PNG or pose.
static func apply(material: ShaderMaterial,direction: String,manifest: Dictionary) -> void:
 var config: Dictionary=manifest.get("proportion_warp_by_direction",{}).get(direction,{})
 material.set_shader_parameter("proportion_warp_enabled",not config.is_empty() and config.get("enabled",true))
 if config.is_empty():return
 var cell: Array=manifest.frame_size
 var ground: Array=manifest.ground
 material.set_shader_parameter("proportion_ground",float(ground[1])/float(cell[1]))
 material.set_shader_parameter("proportion_canvas_height",float(cell[1])*float(manifest.get("pixel_size_by_direction",{}).get(direction,manifest.pixel_size)))
 for key in ["head_height","head_width","top_padding"]:
  material.set_shader_parameter("proportion_"+key,float(config.get(key,0.0)))
 for key in ["head_end","body_end","body_extension","leg_extension","body_width","skirt_width"]:
  material.set_shader_parameter("proportion_"+key,float(config[key]))
