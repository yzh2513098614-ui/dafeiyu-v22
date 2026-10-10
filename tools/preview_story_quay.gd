extends SceneTree
## Engine-rendered art plates with isolated save paths; no player save is edited.
var game
var output:="C:/Users/Administrator/Documents/Codex/2026-10-10/blue-archive-look-v22/results"

func _initialize() -> void:
 call_deferred("capture")

func _plate(filename: String) -> void:
 for i in 30:await process_frame
 await RenderingServer.frame_post_draw
 var error: Error=root.get_texture().get_image().save_png(output+"/"+filename+".png")
 if error!=OK:push_error("Unable to save art plate: "+filename)
 else:print("STORY QUAY ART PLATE: ",filename)

func _hide_overlay() -> void:
 game.ui.hide()
 if game.map_interactions:game.map_interactions.root.hide()
 if game.dialogue_controller and is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()
 for branch in [game.world,game.shell]:
  for label in branch.find_children("*","Label3D",true,false):label.hide()

func capture() -> void:
 DirAccess.make_dir_recursive_absolute(output)
 root.size=Vector2i(1200,675);AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.continue_game=false;prefs.starting_place="story_quay"
 prefs.world_save_path=output+"/isolated_world.json";prefs.settings_path=output+"/isolated_settings.cfg"
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.follow=true;prefs.values.effects=true
 var script: Script=load("res://district/continuous_world.gd")
 if not script or not script.can_instantiate():quit(1);return
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 game.life_booted=false;game.set_physics_process(false)
 for i in 5:await process_frame
 game.atmosphere.cycle_enabled=false;game.atmosphere.set_time(12.0)
 game.player.position=Vector3(-1.9,0,2.2);game.view_center=Vector3(-.5,0,2.1)
 game.view_size=9.8;game.camera.size=9.8;game.camera_angle=-42;game._camera();_hide_overlay()
 game.shell.set_meta("story_look",false);game.atmosphere.set_time(12.0);await _plate("same_scene_original_lighting")
 game.shell.set_meta("story_look",true);game.atmosphere.set_time(12.0);await _plate("reference_style_day")
 game.view_center=Vector3(3.0,0,1.7);game.camera.size=8.4;game._camera();await _plate("reference_style_detail")
 game.view_center=Vector3(-.5,0,2.1);game.camera.size=9.8;game._camera()
 game.atmosphere.set_time(19.0);await _plate("reference_style_dusk")
 game._travel("market");game.set_physics_process(false);game.atmosphere.set_time(12.0)
 game.view_center=game.player.position;game.camera.size=13;game._camera();_hide_overlay();await _plate("current_market_for_context")
 game.queue_free();for i in 5:await process_frame
 quit()
