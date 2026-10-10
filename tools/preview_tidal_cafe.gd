extends SceneTree
## Actual engine art plates, with preferences and world saves isolated from play.
var game
var output:="C:/Users/Administrator/Documents/Codex/2026-10-10/moonlit-cafe-v22/results"

func _initialize() -> void:call_deferred("capture")

func _plate(filename: String) -> void:
 for i in 30:await process_frame
 await RenderingServer.frame_post_draw
 var error: Error=root.get_texture().get_image().save_png(output+"/"+filename+".png")
 if error!=OK:push_error("Unable to save art plate: "+filename)
 else:print("TIDAL CAFE ART PLATE: ",filename)

func _view(center: Vector3,size: float,player: Vector3) -> void:
 game.view_center=center;game.camera.size=size;game.view_size=size;game.camera_angle=-42;game._camera()
 game.player.position=player;game.player.velocity=Vector3.ZERO

func _hide_overlay() -> void:
 game.ui.hide();game.map_interactions.root.hide()
 if game.dialogue_controller and is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()
 for branch in [game.world,game.shell]:
  for label in branch.find_children("*","Label3D",true,false):
   if not label.text.contains("COFFEE & LETTERS"):label.hide()

func capture() -> void:
 DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1200,675);AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="tidal_cafe"
 prefs.world_save_path=output+"/isolated_world.json";prefs.settings_path=output+"/isolated_settings.cfg"
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.follow=true;prefs.values.effects=true
 var script: Script=load("res://district/continuous_world.gd")
 if not script or not script.can_instantiate():quit(1);return
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 game.life_booted=false;game.set_physics_process(false)
 for i in 5:await process_frame
 game.atmosphere.cycle_enabled=false;game.atmosphere.set_time(12.0);_hide_overlay()
 _view(Vector3(.3,0,-.2),17.7,Vector3(1.7,0,3.8))
 game.shell.set_meta("cafe_look",false);game.atmosphere.set_time(12.0);await _plate("cafe_original_lighting")
 game.shell.set_meta("cafe_look",true);game.atmosphere.set_time(12.0);await _plate("cafe_day_overview")
 _view(Vector3(5.3,0,-1.8),10.3,Vector3(4.8,0,-1.2));await _plate("cafe_reading_bay")
 var curtains: Node3D=null;var coffee: Node3D=null;var letter: Node3D=null
 for node in game.world.get_children():
  if node.has_method("map_action"):
   if node.kind=="curtain":curtains=node
   elif node.kind=="coffee":coffee=node
   elif node.kind=="letter":letter=node
 if not curtains or not coffee or not letter:push_error("Cafe facilities could not be loaded");quit(1);return
 curtains.interact();await create_timer(1.05).timeout;await _plate("cafe_open_curtains")
 _view(Vector3(-4.8,0,-3.0),9.8,Vector3(-3.5,0,-2.0));coffee.interact();await create_timer(.65).timeout;await _plate("cafe_brewing")
 _view(Vector3(5.25,0,3.15),9.0,Vector3(5.65,0,2.35));letter.interact();await create_timer(.75).timeout
 game.map_interactions.root.show();await _plate("cafe_letter_interaction");game.map_interactions.root.hide()
 game.atmosphere.set_time(20.0);_view(Vector3(.3,0,-.2),17.7,Vector3(1.7,0,3.8));await _plate("cafe_evening_overview")
 game.atmosphere.set_time(12.0);_view(Vector3(1.7,0,4.9),9.8,Vector3(1.7,0,5.0))
 game.map_interactions.try_interact();await create_timer(.95).timeout;game.map_interactions.root.show();await _plate("cafe_open_entry");game.map_interactions.root.hide()
 # Keep the reusable night-clock behavior visible, and include the prior quay as context.
 game._travel("story_quay");game.set_physics_process(false);game.atmosphere.set_time(12.0);_hide_overlay()
 _view(Vector3(-.5,0,2.1),9.8,Vector3(-1.9,0,2.2));await _plate("quay_current_context")
 game.queue_free();for i in 5:await process_frame
 quit()
