extends SceneTree
## Runtime-only checks: no UI, inventory, dialogue or user save is loaded.
const HEADINGS: Array[String]=["right","down_right","down","down_left","left","up_left","up","up_right"]
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 checks+=1
 if value:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)
func run() -> void:
 var actor=load("res://room_3d.gd").new()
 actor.frames=actor._build_frames()
 var actual_order: Array=actor.character_manifest.atlas_order.duplicate()
 if "--require-eight" in OS.get_cmdline_user_args():
  check(actual_order.size()==8 and actual_order.has("down_left") and actual_order.has("up_right"),"final material exposes eight distinct directions")
 # Probe both readers without replacing any material or writing any save.
 actor.character_manifest.atlas_order=["down","down_left","left","up_left","up","up_right","right","down_right"]
 var correct_sectors:=true
 for i in HEADINGS.size():
  for offset in [-.3926,0.0,.3926]:
   var angle: float=float(i)*PI/4.0+float(offset)
   if actor._direction_name(Vector2(cos(angle),sin(angle)))!=HEADINGS[i]:correct_sectors=false
 check(correct_sectors,"each of eight45-degree sectors preserves its own facing")
 actor.camera=Camera3D.new();root.add_child(actor.camera)
 var camera_headings_match:=true
 for azimuth in [22.0,28.0,42.0]:
  var radians: float=deg_to_rad(azimuth)
  actor.camera.position=Vector3(sin(radians)*19,12.7,cos(radians)*19)
  actor.camera.look_at(Vector3(0,.72,.04))
  var camera_right: Vector3=actor.camera.global_basis.x
  var ground_down: Vector3=Vector3(actor.camera.global_basis.z.x,0,actor.camera.global_basis.z.z).normalized()
  var screen_down_scale: float=-ground_down.dot(actor.camera.global_basis.y)
  for i in HEADINGS.size():
   var angle: float=float(i)*PI/4.0
   var world_travel: Vector3=camera_right*cos(angle)+ground_down*(sin(angle)/screen_down_scale)
   var screen_travel: Vector2=actor._character_screen_travel(world_travel)
   if actor._direction_name(screen_travel)!=HEADINGS[i]:camera_headings_match=false
 check(camera_headings_match,"eight headings follow actual screen projection at all supported camera angles")
 actor.facing="up_left"
 check(actor._direction_name(Vector2.ZERO)=="up_left","zero displacement retains facing")
 actor.character_manifest.atlas_order=["down","left","up","right"]
 var compatible:=true
 for pair in [[Vector2.RIGHT,"right"],[Vector2.LEFT,"left"],[Vector2.UP,"up"],[Vector2.DOWN,"down"],[Vector2(1,.3),"right"],[Vector2(.3,1),"down"]]:
  if actor._direction_name(pair[0])!=pair[1]:compatible=false
 check(compatible,"legacy four-direction manifest keeps original facing behavior")
 actor.character_manifest.atlas_order=actual_order
 actor.player=CharacterBody3D.new();root.add_child(actor.player)
 actor.avatar=AnimatedSprite3D.new();actor.player.add_child(actor.avatar)
 actor.avatar.sprite_frames=actor.frames
 actor.avatar.position=Vector3(.03,.77,0);actor.avatar.offset=Vector2(0,-4)
 actor.character_material=ShaderMaterial.new();actor.character_material.shader=load("res://character/character_depth.gdshader")
 var fixed_position: Vector3=actor.avatar.position
 var fixed_offset: Vector2=actor.avatar.offset
 var fixed_body_position: Vector3=actor.player.position
 var direct_states: Dictionary=actor.character_manifest.get("frames_by_state",{})
 var texture_size:=Vector2(actor.character_manifest.frame_size[0],actor.character_manifest.frame_size[1])
 var texture_by_path: Dictionary={}
 var cache_reused:=true
 for direction in actual_order:
  var complete_frames:=true
  var expected_walk: int=0
  for state in ["idle","walk","interact"]:
   var animation: String=str(state)+"_"+str(direction)
   var expected: int=int(actor.character_manifest.frame_counts[state])
   if not direct_states.is_empty():
    var direction_frames: Array=direct_states.get(state,{}).get(direction,[])
    if direction_frames.is_empty() and state=="interact":direction_frames=direct_states.get("idle",{}).get(direction,[])
    expected=direction_frames.size()
   if state=="walk":expected_walk=expected
   check(expected>0 and actor.frames.has_animation(animation) and actor.frames.get_frame_count(animation)==expected,"frame count "+animation)
   for n in actor.frames.get_frame_count(animation):
    var texture: Texture2D=actor.frames.get_frame_texture(animation,n)
    if texture==null or texture.get_size()!=texture_size:complete_frames=false
    if not direct_states.is_empty():
     var source_frames: Array=direct_states.get(state,{}).get(direction,[])
     if source_frames.is_empty() and state=="interact":source_frames=direct_states.get("idle",{}).get(direction,[])
     var entry=source_frames[n]
     var path: String=str(entry.get("path","")) if entry is Dictionary else str(entry)
     if texture_by_path.has(path) and texture_by_path[path]!=texture:cache_reused=false
     texture_by_path[path]=texture
  check(complete_frames,"complete fixed-canvas images for "+str(direction))
  actor.facing=direction
  actor._set_character_pose(false)
  fixed_position=actor.avatar.position
  var fixed_size: float=actor.avatar.pixel_size
  var visited: Dictionary={}
  var body_stable:=true
  for n in maxi(expected_walk,1):
   actor.gait_phase=(float(n)+.25)/maxi(expected_walk,1)
   actor._set_character_pose(true);visited[actor.avatar.frame]=true
   if actor.avatar.position!=fixed_position or actor.avatar.offset!=fixed_offset or actor.player.position!=fixed_body_position or actor.avatar.pixel_size!=fixed_size:body_stable=false
  check(body_stable and visited.size()==expected_walk,"frame playback leaves body and foot pivot fixed for "+str(direction))
  actor._set_character_pose(false)
  check(actor.avatar.animation=="idle_"+str(direction) and actor.avatar.frame==0,"standing retains "+str(direction))
 if not direct_states.is_empty():check(cache_reused and not texture_by_path.is_empty(),"all repeated PNG paths reuse one uploaded texture across idle walk and interaction")
 actor.facing="down";actor.gait_phase=.2
 var measured_travel:=Vector3(.08,0,.06)
 actor._advance_character_gait(measured_travel,1.0/60.0)
 var expected_phase: float=fposmod(.2+measured_travel.length()/actor.gait_cycle_distance,1.0)
 check(absf(actor.gait_phase-expected_phase)<.00001,"walk phase uses measured planar displacement")
 var held_phase: float=actor.gait_phase
 actor._advance_character_gait(Vector3.ZERO,1.0/60.0)
 check(actor.gait_phase==held_phase and actor.avatar.animation=="idle_down","blocked displacement freezes gait and switches to standing")
 actor._advance_character_gait(Vector3(0,1,0),1.0/60.0)
 check(actor.gait_phase==held_phase,"vertical changes cannot advance a walking cycle")
 var displayed_texture: Texture2D=actor.frames.get_frame_texture(actor.avatar.animation,actor.avatar.frame)
 var shader_texture: Texture2D=actor.character_material.get_shader_parameter("character_atlas")
 check(shader_texture==(displayed_texture.atlas if displayed_texture is AtlasTexture else displayed_texture),"depth material uses the actual full-frame texture")
 check(actor.frames.get_animation_speed("walk_down")==float(actor.character_manifest.get("walk_fps",8)),"walk frame rate metadata is honored")
 for direction in actual_order:
  actor.facing=direction;actor.gait_phase=0.0
  actor._advance_character_gait(Vector3(.3,0,0),.125)
  var cycle: float=1.5 if direction in ["left","right"] else actor.gait_cycle_distance
  check(absf(actor.gait_phase-.3/cycle)<.00001,"distance-driven cadence for "+str(direction))
  if direction in ["left","right"]:
   var held: float=actor.gait_phase
   actor._advance_character_gait(Vector3.ZERO,1.0/60.0)
   check(actor.gait_phase==held and actor.avatar.animation=="idle_"+str(direction),"slower side walk stops immediately for "+str(direction))
 actor.facing="left";actor.gait_phase=.37
 actor._advance_character_gait(Vector3.ZERO,1.0/60.0)
 actor.facing="right";actor._advance_character_gait(Vector3(.15,0,0),1.0/60.0)
 check(absf(actor.gait_phase-.47)<.00001,"turning between side directions preserves gait phase")
 actor.player.free();actor.avatar=null;actor.player=null;actor.camera.free();actor.camera=null;actor.free()
 print("CHARACTER CHECKS ",checks," PASSED ",checks-failures," FAILED ",failures)
 quit(0 if failures==0 else 1)
