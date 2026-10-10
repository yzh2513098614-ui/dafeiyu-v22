extends SceneTree
## Engine art plates and a continuous walking capture, with isolated saves.
var game
var output:="C:/Users/Administrator/Documents/Codex/2026-10-10/harbor-terraces-v22/results"

func _initialize() -> void:call_deferred("capture")

func _plate(filename: String) -> void:
 for i in 18:await process_frame
 await RenderingServer.frame_post_draw
 var error: Error=root.get_texture().get_image().save_png(output+"/"+filename+".png")
 if error!=OK:push_error("Unable to save art plate: "+filename)
 else:print("HARBOR ART PLATE: ",filename)

func _view(center: Vector3,size: float,point: Vector3) -> void:
 game.view_center=center;game.camera.size=size;game.view_size=size;game.camera_angle=-42;game._camera()
 game.player.position=point;game.player.velocity=Vector3.ZERO
 game.character_material.set_shader_parameter("floor_height",point.y+game.CHARACTER_FLOOR_Y)
 game.harbor_controller.set_layers()

func _hide_overlay() -> void:
 game.ui.hide();game.map_interactions.root.hide()
 if game.dialogue_controller and is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()
 for branch in [game.world,game.shell]:
  for label in branch.find_children("*","Label3D",true,false):label.hide()

func _walk_stairs(x: float,front: float,back: float,label: String) -> void:
 game.player.position=Vector3(x,.06,front+1.15);game.player.velocity=Vector3.ZERO
 game._queue_collision_recovery(true);game.harbor_controller.cutaway=false
 game.movement=game._character_screen_travel(Vector3.FORWARD).normalized()
 game.overview_mode=true
 var recorded_mid:=false
 var trace: Array=[]
 for frame in 310:
  await physics_frame;game.harbor_controller.physics(1.0/60.0)
  game.view_center=Vector3(x,1.5,(front+back)*.5);game.camera.size=14.2;game.view_size=14.2;game._camera();_hide_overlay()
  if frame%20==0:trace.append({"frame":frame,"x":game.player.position.x,"y":game.player.position.y,"z":game.player.position.z})
  if not recorded_mid and game.player.position.y>1.5:
   recorded_mid=true;await _plate(label+"_walking_mid")
  if game.player.position.z<back-1.3:break
 game.movement=Vector2.ZERO
 trace.append({"arrival":true,"x":game.player.position.x,"y":game.player.position.y,"z":game.player.position.z})
 print("HARBOR WALK CAPTURE ",label,": ",JSON.stringify(trace))
 var file:=FileAccess.open(output+"/"+label+"_walking.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace," "));file.close()
 await _plate(label+"_walking_top")
 game.movement=game._character_screen_travel(Vector3.BACK).normalized();trace=[]
 for frame in 310:
  await physics_frame;game.harbor_controller.physics(1.0/60.0)
  game.view_center=Vector3(x,1.5,(front+back)*.5);game.camera.size=14.2;game.view_size=14.2;game._camera();_hide_overlay()
  if frame%20==0:trace.append({"frame":frame,"x":game.player.position.x,"y":game.player.position.y,"z":game.player.position.z})
  if game.player.position.z>front+1.1:break
 game.movement=Vector2.ZERO
 trace.append({"arrival":true,"x":game.player.position.x,"y":game.player.position.y,"z":game.player.position.z})
 print("HARBOR RETURN CAPTURE ",label,": ",JSON.stringify(trace))
 file=FileAccess.open(output+"/"+label+"_return_walking.json",FileAccess.WRITE);file.store_string(JSON.stringify(trace," "));file.close()
 await _plate(label+"_walking_return")

func capture() -> void:
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1200,675);AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="story_harbor"
 prefs.world_save_path=output+"/isolated_world.json";prefs.settings_path=output+"/isolated_settings.cfg"
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.follow=true;prefs.values.effects=true
 var script: Script=load("res://district/continuous_world.gd")
 if not script or not script.can_instantiate():quit(1);return
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 game.life_booted=false;game.set_physics_process(false)
 for i in 6:await process_frame
 game.atmosphere.cycle_enabled=false;game.atmosphere.set_time(12.0);_hide_overlay()
 game.harbor_controller.cutaway=false
 _view(Vector3(-4,1,-1),40,Vector3(-2.4,.04,2));await _plate("harbor_day_overview")
 game.harbor_controller.cutaway=true
 _view(Vector3(-.5,0,2.1),9.8,Vector3(-1.9,.04,2.2));await _plate("harbor_lower_quay")
 _view(Vector3(-10,0,8.9),13.4,Vector3(-8.8,.04,8.6));await _plate("harbor_fish_market")
 _view(Vector3(-24,0,6.8),17.0,Vector3(-20,.04,9));await _plate("harbor_piers")
 _view(Vector3(8,3.6,-16.5),15.3,Vector3(5.8,3.64,-15.2));await _plate("harbor_lighthouse")
 _view(Vector3(13,3.6,1),13,Vector3(12,3.64,2));await _plate("harbor_upper_promenade")
 _view(Vector3(13,0,-3),11.8,Vector3(13,.04,1.1))
 game.map_interactions.root.show();await _plate("harbor_workshop_door_ui")
 game.map_interactions.try_interact()
 await create_timer(.9).timeout;game.map_interactions.root.hide();await _plate("harbor_workshop_open")
 game.harbor_controller.cutaway=false
 await _walk_stairs(-10,-5,-13,"west_stair")
 await _walk_stairs(12,16,8,"east_stair")
 game.atmosphere.set_time(20.0)
 _view(Vector3(-4,1,-1),40,Vector3(-2.4,.04,2));await _plate("harbor_evening_overview")
 game.queue_free();for i in 6:await process_frame
 quit()
