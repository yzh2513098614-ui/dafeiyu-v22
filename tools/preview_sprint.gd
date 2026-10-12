extends SceneTree
## Real keyboard input, movement and isolated saves; BGM/SFX stay muted.
const OUTPUT="res://预览/冲刺_20261012/"
const Life=preload("res://character/life_state.gd")
var game
var checks:=0
var failures:=0
var results: Array=[]

func _initialize() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)

func settle(count: int=12) -> void:
 for i in count:await physics_frame

func key(code: Key,pressed: bool) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed
 Input.parse_input_event(event);Input.flush_buffered_events()

func shot(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+name+".png"))

func travel(place: String) -> void:
 game.request_travel(place)
 var loader=preload("res://ui/loading_transition.gd").instance(self)
 while loader.busy:await process_frame
 await settle()
 check(game.location_id==place,"arrival "+place)

func sample(origin: Vector3,direction: Vector2,sprint: bool,baseline: Dictionary) -> Dictionary:
 game.character_controller.model.restore(baseline)
 game.player.position=origin;game.player.velocity=Vector3.ZERO;game._queue_collision_recovery(true)
 await settle(2)
 var before: Vector3=game.player.position
 game.movement=direction;key(KEY_SHIFT,sprint)
 await settle(18)
 var result: Dictionary={"distance":Vector2(game.player.position.x-before.x,game.player.position.z-before.z).length(),"stamina":game.character_controller.model.value("stamina"),"speed":Vector2(game.player.velocity.x,game.player.velocity.z).length()}
 game.character_controller.refresh()
 result.hud=game.character_controller.hud_status.text
 if sprint:await shot(game.location_id+"_冲刺")
 key(KEY_SHIFT,false);game.movement=Vector2.ZERO
 await settle(2)
 return result

func test_place(place: String) -> void:
 if game.location_id!=place:await travel(place)
 var origin: Vector3=game.player.position
 var direction:=Vector2.UP
 for candidate in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1),Vector2(-1,-1)]:
  if not game.player.test_move(game.player.global_transform,game._screen_direction_to_world(candidate)*2.2):direction=candidate;break
 var baseline: Dictionary=Life.new().snapshot()
 var walk: Dictionary=await sample(origin,direction,false,baseline)
 var sprint: Dictionary=await sample(origin,direction,true,baseline)
 check(walk.distance>.2,"walk actually moves "+place)
 check(absf(sprint.speed/walk.speed-2.0)<.01,"Shift doubles actual velocity "+place)
 check(sprint.distance>walk.distance*1.85,"sprint covers more ground "+place)
 check(sprint.stamina<walk.stamina,"sprint consumes additional stamina "+place)
 check(str(sprint.hud).begins_with("冲刺中"),"HUD shows sprint state "+place)
 var stopped: Vector3=game.player.position
 key(KEY_SHIFT,true);await settle(8);key(KEY_SHIFT,false)
 check(game.player.position.distance_to(stopped)<.06,"Shift alone does not move "+place)
 game.character_controller.refresh()
 check(not game.character_controller.hud_status.text.begins_with("冲刺中"),"idle clears sprint state "+place)
 game.movement=direction;await settle(3)
 check(absf(Vector2(game.player.velocity.x,game.player.velocity.z).length()-game.SPEED)<.01,"release restores walking speed "+place)
 game.movement=Vector2.ZERO;await settle(2)
 results.append({"place":place,"walk":walk,"sprint":sprint})

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720)
 var prefs=root.get_node("HarborPrefs")
 prefs.continue_game=false;prefs.starting_place="city";prefs.world_save_path=OUTPUT+"isolated_world.json";prefs.settings_path=OUTPUT+"isolated_settings.cfg"
 prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false;prefs.values.day_cycle=false;prefs.values.follow=true;prefs.values.fullscreen=false
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await settle()
 for place in ["city","apt_2","wuming_campus","story_harbor","pack26_foodhall"]:await test_place(place)
 await travel("wuming_campus")
 var model=game.character_controller.model
 model.state.vitals.stamina=10.0
 game.movement=Vector2.UP;key(KEY_SHIFT,true);await settle(8)
 check(absf(Vector2(game.player.velocity.x,game.player.velocity.z).length()-game.SPEED*.8)<.01,"low stamina prevents sprint acceleration")
 game.character_controller.refresh()
 check(game.character_controller.hud_status.text.contains("恢复后冲刺"),"low stamina has explicit recovery hint")
 key(KEY_SHIFT,false);game.movement=Vector2.ZERO
 var low: float=model.value("stamina");await settle(20)
 check(model.value("stamina")>low,"standing still recovers stamina")
 model.state.vitals.stamina=60.0;game.pause_menu.open();var before: Vector3=game.player.position;var stamina: float=model.value("stamina")
 game.movement=Vector2.UP;key(KEY_SHIFT,true);await settle(8)
 check(game.player.position.distance_to(before)<.01 and is_equal_approx(model.value("stamina"),stamina),"pause blocks sprint and stamina drain")
 key(KEY_SHIFT,false);game.movement=Vector2.ZERO;game.pause_menu.close()
 game.loot.open_bag();before=game.player.position;game.movement=Vector2.UP;key(KEY_SHIFT,true);await settle(8)
 check(game.player.position.distance_to(before)<.06,"backpack blocks sprint")
 key(KEY_SHIFT,false);game.movement=Vector2.ZERO;game.loot.close()
 model.state.vitals.stamina=100;game.character_controller.refresh();await shot("校园_待机冲刺提示")
 var file:=FileAccess.open(OUTPUT+"验证结果.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":results},"  "));file.close()
 print("SPRINT: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
