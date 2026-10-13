extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 checks+=1
 if value:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)
func run() -> void:
 var actor=load("res://room_3d.gd").new()
 actor.frames=actor._build_frames()
 actor.player=CharacterBody3D.new();root.add_child(actor.player)
 actor.avatar=AnimatedSprite3D.new();actor.player.add_child(actor.avatar);actor.avatar.sprite_frames=actor.frames
 actor.character_material=ShaderMaterial.new();actor.character_material.shader=load("res://character/character_depth.gdshader")
 var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(actor.character_manifest.blink_config))
 actor.blink_controller=load("res://character/blink_controller.gd").new();root.add_child(actor.blink_controller)
 actor.blink_controller.set_process(false)
 actor.facing="down";actor._set_character_pose(false)
 actor.blink_controller.configure(config,Callable(actor,"_update_character_material"))
 check(config.interval_min>=5.0 and config.interval_max>=8.0,"natural slow random blink interval")
 check(absf(config.closing_time+config.closed_time+config.opening_time-.28)<.00001,"one blink takes 0.28 seconds")
 check(actor.blink_controller.waiting>=5.5 and actor.blink_controller.waiting<=8.5,"first blink does not happen immediately")
 actor.blink_controller.waiting=100.0
 for n in 240:actor.blink_controller.advance(1.0/60.0)
 check(actor.blink_controller.phase=="open","idle stays open between blinks")
 var directions: Array=["down","down_right","right","down_left","left"]
 for direction in directions:
  actor.facing=direction;actor.gait_phase=.1;actor._set_character_pose(false)
  var before: Vector3=actor.avatar.position
  actor.blink_controller.begin_blink()
  check(actor.character_material.get_shader_parameter("character_atlas").resource_path.contains("/half/"),"half closure is visible while idle "+direction)
  actor.blink_controller.advance(.08)
  check(actor.character_material.get_shader_parameter("character_atlas").resource_path.contains("/closed/"),"closed eyes are visible while idle "+direction)
  var phase: float=actor.gait_phase
  actor._advance_character_gait(Vector3(.08,0,0),1.0/60.0)
  check(actor.avatar.animation=="walk_"+direction and actor.gait_phase>phase,"walking continues during a blink "+direction)
  check(actor.character_material.get_shader_parameter("character_atlas").resource_path.contains("/closed/"),"closed frame follows the current walking picture "+direction)
  actor.blink_controller.advance(.12)
  check(actor.blink_controller.phase=="half","eyes reopen through half closure "+direction)
  actor.blink_controller.advance(.09)
  var base: Texture2D=actor.frames.get_frame_texture(actor.avatar.animation,actor.avatar.frame)
  check(actor.character_material.get_shader_parameter("character_atlas")==base and actor.avatar.position==before,"opening restores original art and fixed foot pivot "+direction)
 actor.facing="up_right";actor._set_character_pose(false);actor.blink_controller.begin_blink();actor.blink_controller.advance(.08)
 var rear: Texture2D=actor.frames.get_frame_texture("idle_up_right",0)
 check(actor.character_material.get_shader_parameter("character_atlas")==rear,"rear-facing views do not draw artificial eyes")
 actor.blink_controller.advance(.3)
 actor.blink_controller.completed=0
 actor.blink_controller.waiting=5.5
 for n in 7200:actor.blink_controller.advance(1.0/60.0)
 check(actor.blink_controller.completed>=12 and actor.blink_controller.completed<=21,"two-minute simulation stays at a relaxed cadence")
 check(actor.blink_controller.textures.size()<=12,"whole-frame blink GPU cache stays bounded")
 actor.blink_controller.free();actor.blink_controller=null
 actor.player.free();actor.player=null;actor.avatar=null;actor.free()
 print("BLINK CHECKS ",checks," PASSED ",checks-failures," FAILED ",failures)
 quit(0 if failures==0 else 1)
