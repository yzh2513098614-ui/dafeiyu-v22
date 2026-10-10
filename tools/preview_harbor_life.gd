extends SceneTree
## Actual art plates, with isolated world, UI and dialogue saves.
var game
var output:="C:/Users/Administrator/Documents/Codex/2026-10-11/harbor-life-v22/results"

func _initialize() -> void:call_deferred("capture")

func _plate(filename: String) -> void:
 for i in 20:await process_frame
 await RenderingServer.frame_post_draw
 var error: Error=root.get_texture().get_image().save_png(output+"/"+filename+".png")
 if error!=OK:push_error("Unable to save art plate: "+filename)
 else:print("HARBOR LIFE ART PLATE: ",filename)

func _view(center: Vector3,size: float,point: Vector3) -> void:
 game.view_center=center;game.camera.size=size;game.view_size=size;game.camera_angle=-42;game._camera()
 game.player.position=point;game.player.velocity=Vector3.ZERO
 game.character_material.set_shader_parameter("floor_height",point.y+game.CHARACTER_FLOOR_Y)
 game.harbor_controller.set_layers()

func _hide_overlay() -> void:
 game.ui.hide();game.map_interactions.root.hide()
 if game.dialogue_controller and is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()
 for branch in [game.world,game.shell]:
  for label in branch.find_children("*","Label3D",true,false):
   if not label.has_meta("harbor_wayfinding"):label.hide()

func _facility(kind: String):
 for node in game.world.get_children():
  if node.has_meta("harbor_facility") and node.kind==kind:return node
 return null

func capture() -> void:
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1200,675);AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="story_harbor"
 prefs.world_save_path=output+"/isolated_world.json";prefs.settings_path=output+"/isolated_settings.cfg"
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.follow=true;prefs.values.effects=true
 var script: Script=load("res://district/continuous_world.gd")
 if not script or not script.can_instantiate():quit(1);return
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 game.life_booted=false;game.set_physics_process(false)
 for i in 8:await process_frame
 game.atmosphere.cycle_enabled=false;game.atmosphere.set_time(12.0);_hide_overlay()
 game.harbor_controller.cutaway=false
 _view(Vector3(-4,1,-1),40,Vector3(-2.4,.04,2));await _plate("harbor_life_day")
 game.harbor_controller.cutaway=true
 _view(Vector3(-10,0,11.2),13.5,Vector3(-9.2,.04,8.0));await _plate("harbor_market_wind")
 game.harbor_controller.cutaway=false
 _view(Vector3(-10.8,1,-6.4),15.0,Vector3(-10.7,.04,-3.2));await _plate("harbor_wayfinding")
 game.harbor_controller.cutaway=true
 _view(Vector3(-24,0,12.1),13.4,Vector3(-23,.04,8.75))
 game.map_interactions.root.show();await _plate("harbor_winch_ui")
 game.map_interactions.try_interact();await create_timer(.85).timeout;game.map_interactions.root.hide();await _plate("harbor_winch_turning")
 await create_timer(2.0).timeout;await _plate("harbor_winch_taut")
 var winch=_facility("winch");print("WINCH ART STATE: ",winch.opened," / ",winch.amount," / ",winch.busy)
 game.atmosphere.set_time(20.0)
 _view(Vector3(9.4,3.6,-16.9),12.8,Vector3(7.1,3.64,-15.9))
 game.map_interactions.root.show();await _plate("harbor_beacon_ui")
 game.map_interactions.try_interact();await create_timer(.9).timeout;game.map_interactions.root.hide()
 var beacon=_facility("beacon");beacon.clock=4.9;beacon.set_process(false);beacon._pose_beacon()
 await _plate("harbor_beacon_on");print("BEACON ART STATE: ",beacon.opened," / ",beacon.amount," / ",beacon.busy)
 beacon.interact();await create_timer(.8).timeout;beacon._pose_beacon();await _plate("harbor_beacon_off")
 beacon.interact();await create_timer(.8).timeout;beacon._pose_beacon()
 game.harbor_controller.cutaway=false
 _view(Vector3(-4,1,-1),40,Vector3(-2.4,.04,2));await _plate("harbor_life_evening")
 beacon.set_process(true)
 game.queue_free();for i in 6:await process_frame
 quit()
