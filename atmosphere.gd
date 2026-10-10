extends Node3D
## Actual world-space lights and particles; optional so gameplay stays readable.
const RenderStyle=preload("res://district/render_style.gd")
const RestaurantFinish=preload("res://district/restaurant_finish.gd")
const StoryQuay=preload("res://district/story_quay.gd")
const HarborTerraces=preload("res://district/harbor_terraces.gd")
const TidalCafe=preload("res://district/tidal_cafe.gd")
var game: Node3D
var dusk := false
var effects := true
var elapsed := 0.0
var dust: Array[MeshInstance3D] = []
var lamps: Array[Light3D] = []
var fills: Array[OmniLight3D] = []
var glows: Array[MeshInstance3D] = []
var rng:=RandomNumberGenerator.new()
var sun: DirectionalLight3D
var environment: Environment
var contact_shading: MeshInstance3D
var curtains: Array[Node3D] = []
var image_props: Array[Sprite3D] = []
var cycle_enabled:=false
var day_minutes:=12.0
var hour:=9.0
var day:=1
var lamp_energy:=.12
var shadow_refresh:=0.0
const OUTDOOR_PLACES: Array[String]=["city","garden","market","trial","pack26_skypark","pack26_nightmarket","pack26_campsite","pack26_shipyard","pack26_boardwalk"]
const FIXTURE_TINTS := {"pack26_hospital":"e6eef8","hospital_1":"e6eef8","hospital_2":"e6eef8","hospital_3":"e6eef8","pack26_foodhall":"ffe0b4","restaurant_1":"ffe0b4","restaurant_2":"ffe0b4","restaurant_3":"ffe0b4","restaurant_b1":"ffe0b4"}
# Hour, direct light, ambient light, sunlight color, ambient color, sky, prop tint, night weight, pitch, yaw.
const LIGHT_KEYS: Array=[
 [0.0,.045,.21,"99afd2","a1b5cf","10192a","98accb",1.0,-32.0,-35.0],
 [5.0,.055,.21,"a2b6d4","a5b9d1","172337","a5b7cf",1.0,-24.0,-70.0],
 [6.5,.21,.25,"efd3b3","b8c7d6","273746","d5dae0",.45,-18.0,-75.0],
 [9.0,.36,.27,"f3e9dc","c6d2dd","182535","f3f2ed",.0,-38.0,-55.0],
 [12.0,.40,.28,"f3eee5","c6d2dd","182535","ffffff",.0,-48.0,-35.0],
 [16.0,.35,.27,"f1dec6","c6cbd0","25303a","f0e9de",.08,-34.0,10.0],
 [18.0,.26,.245,"f4c99c","bdc1cd","302e3a","ddd2ca",.55,-19.0,35.0],
 [20.0,.065,.22,"a5b5cf","a4b9d3","111a2b","aabbd2",1.0,-24.0,5.0],
 [24.0,.045,.21,"99afd2","a1b5cf","10192a","98accb",1.0,-32.0,-35.0]]

func configure(owner_game: Node3D) -> void:
 game=owner_game;sun=game.get_node("Sun");environment=game.get_node("RoomEnvironment").environment
 RenderStyle.configure(environment)
 contact_shading=preload("res://district/contact_shading.gd").install(game.camera)
 rng.seed=20260930

func rebuild() -> void:
 if not RestaurantFinish.active(game) and game.shell.has_meta("restaurant_finish"):game.shell.remove_meta("restaurant_finish")
 for child in get_children():child.free()
 dust.clear();lamps.clear();fills.clear();glows.clear();curtains.clear();image_props.clear()
 # Furniture and imported levels live in world; themed wall/room decorations
 # live in the separate shell. Both contain visible real lamp models.
 for scene_root in [game.world,game.shell]:
  preload("res://district/practical_lights.gd").install(scene_root)
  RenderStyle.prepare_surfaces(scene_root)
  if RestaurantFinish.active(game):RestaurantFinish.prepare_surfaces(scene_root)
  _gather(scene_root)
 if RestaurantFinish.active(game):
  RestaurantFinish.install(game,self)
  _gather(get_node("RestaurantLighting"))
  RestaurantFinish.batch_static(game)
 var anchors: Array[Vector3]=[Vector3(-3.5,0,-2.35),Vector3(2.4,0,-2.35)]
 var particle_count:=24
 var zones=game.get("room_zones")
 if game.get("location_id")=="city":anchors.clear()
 elif zones is Array and not zones.is_empty():
  anchors.clear();particle_count=8
  for zone in zones:
   var rect: Rect2=zone.rect
   anchors.append(zone.center+Vector3(0,0,-rect.size.y*.25))
 for anchor in anchors:
  for i in particle_count:
   var particle:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2.ONE*rng.randf_range(.008,.021);particle.mesh=quad
   particle.position=anchor+Vector3(rng.randf_range(-.76,.76),rng.randf_range(.45,2.2),rng.randf_range(-.45,1.85))
   var m:=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;m.albedo_color=Color(.82,.94,1.,.08);m.no_depth_test=false
   particle.material_override=m;particle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;particle.set_meta("origin",particle.position);particle.set_meta("phase",rng.randf()*TAU);particle.set_meta("floor_height",anchor.y);add_child(particle);dust.append(particle)
 # Room brightness comes from the environment and fixtures. Flat floor light
 # overlays ignore walls and floors, so do not use them in the cutaway world.
 for lamp in lamps:
  var halo:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.32,.32);halo.mesh=quad;halo.position=lamp.global_position
  var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,blend_add,depth_draw_never,cull_disabled;uniform float strength=.12;void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}void fragment(){float d=length((UV-vec2(.5))*2.);ALBEDO=vec3(1.,.56,.18);ALPHA=pow(max(1.-d,0.),3.)*strength;}"
  var m:=ShaderMaterial.new();m.shader=shader;halo.material_override=m;halo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;halo.set_meta("source_lamp",lamp);add_child(halo);glows.append(halo)
 set_effects(effects);_apply_lighting();_refresh_local_shadows()

func _refresh_local_shadows() -> void:
 # Keep fixtures in the same lighting pass while walking. Switching shadows
 # on/off by player distance also changes sRGB light accumulation in Compatibility.
 var enabled: bool=bool(HarborPrefs.values.get("shadows",true))
 for lamp in lamps:
  if lamp.has_meta("restaurant_window") or lamp.has_meta("cafe_lamp") or lamp.has_meta("harbor_lamp"):lamp.shadow_enabled=false;continue
  lamp.shadow_enabled=enabled
  if lamp is OmniLight3D:lamp.omni_shadow_mode=OmniLight3D.SHADOW_CUBE
  lamp.shadow_bias=.025;lamp.shadow_normal_bias=.20;lamp.shadow_blur=.85

func _gather(node: Node) -> void:
 if node is OmniLight3D or node is SpotLight3D:
  lamps.append(node)
  node.light_specular=.55 if RestaurantFinish.active(game) else .18
  var place: String=str(game.get("location_id"))
  if FIXTURE_TINTS.has(place) and not node.has_meta("finish_tint"):node.light_color=Color(FIXTURE_TINTS[place])
  if not node.has_meta("fixture_weight"):node.set_meta("fixture_weight",clampf(node.light_energy/.60,.75,1.25))
 if node is Sprite3D and not node.shaded:image_props.append(node)
 if node is Node3D and node.get("module_id") in ["curtains_ivory","curtains_navy"]:curtains.append(node)
 for child in node.get_children():_gather(child)

func set_dusk(value: bool) -> void:
 cycle_enabled=false
 hour=18.0 if value else 12.0
 _apply_lighting()

func set_cycle_enabled(value: bool) -> void:
 cycle_enabled=value;_apply_lighting()

func set_time(value: float,day_number: int=-1) -> void:
 if not is_finite(value):return
 hour=fposmod(value,24.0)
 if day_number>0:day=day_number
 _apply_lighting()

func advance_time(delta: float) -> void:
 if not cycle_enabled or delta<=0 or not is_finite(delta):return
 var total: float=hour+delta*24.0/(maxf(day_minutes,1.0)*60.0)
 day+=floori(total/24.0);hour=fposmod(total,24.0);_apply_lighting()

func save_clock() -> Dictionary:return {"hour":hour,"day":day}

func restore_clock(data: Variant) -> void:
 if not data is Dictionary:return
 var value=data.get("hour",9.0)
 if not (value is int or value is float):return
 set_time(float(value),maxi(1,int(data.get("day",1))))

func clock_text() -> String:
 var minutes:=floori(hour*60.0)
 var period:="夜晚" if hour<5.5 or hour>=20 else ("清晨" if hour<8 else ("上午" if hour<12 else ("午后" if hour<17 else "黄昏")))
 return "第 %d 天 · %02d:%02d · %s"%[day,minutes/60,minutes%60,period]

func _apply_lighting() -> void:
 if not is_instance_valid(sun):return
 var a: Array=LIGHT_KEYS[0];var b: Array=LIGHT_KEYS[1]
 for i in LIGHT_KEYS.size()-1:
  if hour>=LIGHT_KEYS[i][0] and hour<LIGHT_KEYS[i+1][0]:a=LIGHT_KEYS[i];b=LIGHT_KEYS[i+1];break
 var t: float=smoothstep(0.0,1.0,(hour-float(a[0]))/(float(b[0])-float(a[0])))
 var night: float=lerpf(a[7],b[7],t)
 var outside: bool=str(game.get("location_id")) in OUTDOOR_PLACES or str(game.get("location_id")) in ["story_quay","story_harbor"]
 sun.shadow_bias=.12;sun.shadow_normal_bias=1.8;sun.shadow_blur=.85
 contact_shading.visible=effects
 dusk=hour>=17.0 or hour<7.0
 sun.light_energy=lerpf(a[1],b[1],t)*(1.0 if outside else .94);sun.light_color=Color(a[3]).lerp(Color(b[3]),t)
 # Indoor cutaways use a high, gentle key: sunset must not project every
 # exposed partition across neighbouring rooms like an outdoor building.
 var pitch: float=lerpf(a[8],b[8],t) if outside else lerpf(-58.0,-52.0,night)
 sun.rotation_degrees=Vector3(pitch,lerpf(a[9],b[9],t),0)
 contact_shading.material_override.set_shader_parameter("key_direction",sun.global_basis.z.normalized())
 contact_shading.material_override.set_shader_parameter("key_weight",lerpf(1.0,.25,night))
 sun.shadow_opacity=.95 if outside else .88
 environment.ambient_light_energy=lerpf(a[2],b[2],t)+(.0 if outside else .02)
 environment.ambient_light_color=Color(a[4]).lerp(Color(b[4]),t)
 environment.ambient_light_sky_contribution=lerpf(.42,.24,night)
 environment.background_color=Color(a[5]).lerp(Color(b[5]),t)
 RenderStyle.set_reflection_time(environment,night,outside)
 lamp_energy=lerpf(.025,.84,night)
 if str(game.get("location_id"))=="restaurant_b1":
  # The cellar is below ground: its readable pools of light stay on in daytime.
  sun.light_energy=.025
  environment.ambient_light_energy=.13;environment.ambient_light_color=Color("9aaec7")
  environment.ambient_light_sky_contribution=.10;environment.background_color=Color("101a29")
  RenderStyle.set_reflection_time(environment,1.0,false);lamp_energy=.72;night=1.0
  contact_shading.material_override.set_shader_parameter("key_weight",.25)
 for lamp in lamps:
  lamp.light_energy=lamp_energy*float(lamp.get_meta("fixture_weight"))
 RestaurantFinish.apply_lighting(self,night,effects)
 StoryQuay.apply_lighting(self,night)
 HarborTerraces.apply_lighting(self,night)
 TidalCafe.apply_lighting(self,night)
 var tint:=Color(a[6]).lerp(Color(b[6]),t)
 for prop in image_props:
  if is_instance_valid(prop):prop.modulate=tint
 for glow in glows:
  glow.material_override.set_shader_parameter("strength",lerpf(.0,.055,night))

func set_effects(value: bool) -> void:
 effects=value
 environment.ssao_enabled=false
 contact_shading.visible=value
 for particle in dust:particle.visible=value
 for glow in glows:glow.visible=value
 for curtain in curtains:
  if is_instance_valid(curtain):curtain.rotation.z=0
 _apply_lighting()

func _process(delta: float) -> void:
 elapsed+=delta
 shadow_refresh+=delta
 if shadow_refresh>=.25:shadow_refresh=0;_refresh_local_shadows()
 if cycle_enabled and not game.settings_panel.visible and not game.loot.blocked() and not game.map_panel.visible and not game.dialog_open and not game.panel.visible and not (game.pause_menu and game.pause_menu.active) and not (game.character_controller and game.character_controller.active) and not (game.get("combat_controller") and game.combat_controller.in_battle()):advance_time(delta)
 if not effects:return
 for particle in dust:
  particle.visible=true
  if game.get("pack26_controller") and game.pack26_controller.is_active():
   particle.visible=not game.pack26_controller.floor_cutaway or float(particle.get_meta("floor_height"))<=game.pack26_controller.level.floor_view_height+.2
  var origin: Vector3=particle.get_meta("origin");var phase: float=particle.get_meta("phase")
  particle.position=origin+Vector3(sin(elapsed*.17+phase)*.17,fmod(elapsed*.035+phase*.045,.5)-.25,cos(elapsed*.14+phase)*.12)
  particle.material_override.albedo_color.a= .035+.065*(sin(elapsed*.40+phase)*.5+.5)
 for glow in glows:glow.visible=glow.get_meta("source_lamp").is_visible_in_tree()
 for i in curtains.size():
  if is_instance_valid(curtains[i]):curtains[i].rotation.z=sin(elapsed*.56+i)*.007
