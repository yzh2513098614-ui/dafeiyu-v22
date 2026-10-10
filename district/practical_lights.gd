extends RefCounted
## Real lamps in the imported pack. Child lights inherit their storey's visibility.
const PARTS: Dictionary={
 "lamp_diffuser":[2.5,.60,.035],
 "lantern_diffuser":[3.0,.50,0.0],
 "FrostedGlobe":[3.8,.65,0.0],
 "Bulb":[2.5,.55,.09],
 "WarmDiffuser":[3.0,.50,.0],
 "PendantGlow":[4.0,.65,.04],
 "LampLens":[2.5,.45,.04]
}

static func install(world: Node3D) -> void:
 for part: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
  var role: String=str(part.name)
  # The older finished floor lamp is grouped by material rather than by part.
  # Match its actual decoration ID as well, so cream furniture never becomes a light.
  var floor_lamp: bool=role=="decor_d8dcd8_matte" and str(part.get_parent().get_parent().get_meta("decor_id",""))=="floor_lamp"
  if not PARTS.has(role) and not floor_lamp:continue
  if part.has_node("PracticalLight"):continue
  var spec: Array=[3.3,.60,.035] if floor_lamp else PARTS[role]
  var box: AABB=part.mesh.get_aabb()
  var light: Light3D
  if floor_lamp or role in ["lamp_diffuser","PendantGlow","LampLens"]:
   var spot:=SpotLight3D.new()
   spot.rotation_degrees.x=-90
   spot.spot_range=float(spec[0]);spot.spot_angle=58;spot.spot_angle_attenuation=.65
   spot.spot_attenuation=1.4
   light=spot
  else:
   var omni:=OmniLight3D.new();omni.omni_range=spec[0];omni.omni_attenuation=1.4
   light=omni
  light.name="PracticalLight"
  light.position=box.get_center()-Vector3(0,box.size.y*.5+float(spec[2]),0)
  light.light_color=Color("ffe4bd");light.light_energy=spec[1]
  part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  part.add_child(light)
