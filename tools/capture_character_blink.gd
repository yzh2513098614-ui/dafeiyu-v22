extends SceneTree
const OUTPUT:="res://预览/眨眼_20261013/实机/"
var game
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
 AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.smooth_camera=false
 prefs.starting_place="city";prefs.continue_game=false;prefs.apply_window()
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 for n in 12:await process_frame
 game.dialogue_controller.close();game.atmosphere.set_effects(false)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 game.set_physics_process(false);game.blink_controller.set_process(false)
 game.player.position=Vector3(-22,0,-12);game.player.velocity=Vector3.ZERO
 game.facing="down";game._set_character_pose(false)
 game.view_size=4.5;game.camera.size=4.5;game.view_center=game.player.position;game._camera()
 await shot("01_idle_open.png")
 game.blink_controller.begin_blink()
 await shot("02_idle_half.png")
 game.blink_controller.advance(.08)
 await shot("03_idle_closed.png")
 var origin: Vector3=game.player.position
 game.collision_recovery_pending=false;game.collision_has_safe=true;game.collision_last_safe=origin
 game.movement=Vector2.DOWN;game.set_physics_process(true)
 var visited: Dictionary={}
 for n in 24:
  await physics_frame
  if game.avatar.animation=="walk_down":visited[game.avatar.frame]=true
 game.set_physics_process(false)
 var walking_distance: float=game.player.position.distance_to(origin)
 if visited.size()<3 or walking_distance<.2 or game.blink_controller.phase!="closed":
  failures+=1;push_error("Closed eyes interrupted actual walking")
 await shot("04_walk_closed.png")
 game.movement=Vector2.ZERO;game._set_character_pose(false)
 game.blink_controller.advance(.12)
 await shot("05_idle_reopening.png")
 game.blink_controller.advance(.09)
 await shot("06_idle_open_again.png")
 var companion: Node3D=game.dialogue_controller.companion
 var guide_blink=companion.get_node_or_null("NaturalBlink")
 if guide_blink==null:
  failures+=1;push_error("Standing companion has no independent blink")
 else:
  guide_blink.set_process(false);guide_blink.begin_blink();guide_blink.advance(.08)
  game.player.hide();game.view_center=companion.global_position;game._camera()
  for child in companion.get_children():
   if child is Label3D:child.hide()
  await shot("07_companion_closed.png")
  guide_blink.advance(.3)
  await shot("08_companion_open.png")
 var result:={"failures":failures,"walking_distance":walking_distance,"walk_frames_seen":visited.size(),"independent_companion":guide_blink!=null}
 FileAccess.open(OUTPUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("ACTUAL BLINK CAPTURE ",JSON.stringify(result))
 quit(0 if failures==0 else 1)
func shot(filename: String) -> void:
 for n in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename))
