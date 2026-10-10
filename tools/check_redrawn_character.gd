extends SceneTree
## Integration checks only. They do not certify drawing quality or correct foot contacts.
var game
var failures := 0
var checks := 0
var measured := {}

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var scene: PackedScene = load("res://district/continuous_world.tscn")
 if scene == null:
  push_error("Could not load the actual continuous world");quit(1);return
 game = scene.instantiate();root.add_child(game)
 await _ticks(3)
 game._travel("apt_2")
 game.overview_mode=false;game.view_size=18;game.view_center=Vector3.ZERO
 await _ticks(3)
 _check(not game.avatar.no_depth_test,"character participates in physical room occlusion")
 var fixed_position: Vector3 = game.avatar.position
 var fixed_offset: Vector2 = game.avatar.offset
 var root_drift := 0.0
 var offset_drift := 0.0
 var phase_error := 0.0
 var distances := {}
 var names := ["down", "left", "up", "right"]
 var inputs := [Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2.RIGHT]
 for i in names.size():
  game.movement=Vector2.ZERO;game.player.position=Vector3.ZERO;game.player.velocity=Vector3.ZERO
  await _ticks(3)
  var actual_distance := 0.0
  var frames_seen := {}
  game.movement=inputs[i]
  for tick in 48:
   var previous_position: Vector3 = game.player.position
   var previous_phase: float = game.gait_phase
   await _ticks(1)
   var difference: Vector3 = game.player.position-previous_position
   var distance := Vector2(difference.x,difference.z).length()
   actual_distance+=distance
   var expected: float = fposmod(previous_phase+distance/float(game.gait_cycle_distance),1.0)
   phase_error=maxf(phase_error,absf(wrapf(float(game.gait_phase)-expected,-.5,.5)))
   root_drift=maxf(root_drift,game.avatar.position.distance_to(fixed_position))
   offset_drift=maxf(offset_drift,game.avatar.offset.distance_to(fixed_offset))
   if game.avatar.animation=="walk_"+str(names[i]):frames_seen[game.avatar.frame]=true
  _check(actual_distance>.50,"actual displacement advances "+str(names[i]))
  _check(game.avatar.animation=="walk_"+str(names[i]),"camera-relative facing maps to "+str(names[i]))
  _check(frames_seen.size()>3,"several distinct frames are connected for "+str(names[i]))
  distances[names[i]]={"distance":actual_distance,"seen_frames":frames_seen.size()}
  game.movement=Vector2.ZERO
  await _ticks(3)
  var stopped_phase: float=game.gait_phase
  var stopped_position: Vector3=game.player.position
  await _ticks(8)
  _check(absf(wrapf(game.gait_phase-stopped_phase,-.5,.5))<.00001,"stopped phase remains fixed for "+str(names[i]))
  _check(game.player.position.distance_to(stopped_position)<.00001,"stopped root remains in place for "+str(names[i]))
  _check(str(game.avatar.animation).begins_with("idle_"),"stopped character uses idle for "+str(names[i]))
  game.movement=inputs[i]
  var resume_position: Vector3=game.player.position
  await _ticks(1)
  var resume_distance:=Vector2(game.player.position.x-resume_position.x,game.player.position.z-resume_position.z).length()
  var resume_expected:float=fposmod(stopped_phase+resume_distance/float(game.gait_cycle_distance),1.0)
  _check(absf(wrapf(game.gait_phase-resume_expected,-.5,.5))<.0001,"resume preserves distance phase for "+str(names[i]))
  game.movement=Vector2.ZERO
 _check(root_drift<.00001,"all directions and phases retain one fixed sprite position")
 _check(offset_drift<.00001,"all directions and phases retain one fixed sprite offset")
 _check(phase_error<.0001,"walk phase follows measured ground displacement")
 measured={"maximum_sprite_position_drift":root_drift,"maximum_sprite_offset_drift":offset_drift,"maximum_phase_error":phase_error,"directions":distances}
 print("REDRAWN_CHARACTER_CHECKS ",checks," FAILURES ",failures)
 print("REDRAWN_CHARACTER_MEASUREMENTS ",JSON.stringify(measured))
 quit(1 if failures>0 else 0)

func _ticks(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func _check(condition: bool, message: String) -> void:
 checks+=1
 if condition:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)
