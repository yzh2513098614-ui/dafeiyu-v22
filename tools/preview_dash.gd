extends SceneTree
const OUTPUT="res://预览/长段突进_20261012/"
const Life=preload("res://character/life_state.gd")
var game
var checks:=0
var failures:=0
var samples: Array=[]
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
func key(code: Key,pressed: bool,echo: bool=false) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;event.echo=echo
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
func reset_at(origin: Vector3) -> void:
 var actor=game.character_controller
 actor.cancel_dash();actor.dash_cooldown=0;actor.model.restore(Life.new().snapshot())
 game.player.position=origin;game.player.velocity=Vector3.ZERO;game.movement=Vector2.ZERO;game._queue_collision_recovery(true)
 key(KEY_SHIFT,false);await settle(2)
func direction_for(length: float) -> Vector2:
 for candidate in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
  if not game.player.test_move(game.player.global_transform,game._screen_direction_to_world(candidate)*length):return candidate
 return Vector2.UP
func test_place(place: String) -> void:
 if game.location_id!=place:await travel(place)
 var origin: Vector3=game.player.position
 await reset_at(origin)
 var direction:=direction_for(6.2)
 var expected: Vector3=game._screen_direction_to_world(direction)
 game.movement=direction;key(KEY_SHIFT,true);game.movement=Vector2.ZERO;key(KEY_SHIFT,false)
 check(game.character_controller.dash_remaining>0,"tap starts a dash "+place)
 check(is_equal_approx(game.character_controller.model.value("stamina"),88),"dash spends 12 stamina once "+place)
 await settle(7);game.character_controller.refresh();await shot(place+"_突进")
 await settle(24)
 var displacement: Vector3=game.player.position-origin
 var distance:=Vector2(displacement.x,displacement.z).length()
 check(distance>1.0,"dash continues after Shift release "+place)
 check(distance<=6.15,"dash is capped at six meters "+place)
 check(displacement.dot(expected)>distance*.85,"dash follows selected direction "+place)
 check(game.character_controller.dash_remaining==0,"dash ends "+place)
 check(game.CollisionSafety.clear_at(game.player,game.player.position),"dash ends outside obstacles "+place)
 if place=="wuming_campus":check(absf(distance-6.0)<.15,"open campus road supports the full six meter displacement")
 samples.append({"place":place,"distance":distance})
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT));AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720)
 var prefs=root.get_node("HarborPrefs")
 prefs.continue_game=false;prefs.starting_place="city";prefs.world_save_path=OUTPUT+"isolated_world.json";prefs.settings_path=OUTPUT+"isolated_settings.cfg"
 prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false;prefs.values.day_cycle=false;prefs.values.follow=true;prefs.values.fullscreen=false
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await settle()
 for place in ["city","apt_2","wuming_campus","story_harbor","pack26_foodhall"]:await test_place(place)
 await travel("wuming_campus")
 var actor=game.character_controller;var origin: Vector3=game.player.position
 await reset_at(origin)
 game.facing=game._direction_name(direction_for(6.2));var expected: Vector3=game._screen_direction_to_world(direction_for(6.2))
 key(KEY_SHIFT,true);var after_cost: float=actor.model.value("stamina")
 key(KEY_SHIFT,true,true)
 check(is_equal_approx(actor.model.value("stamina"),after_cost),"keyboard repeat does not retrigger or charge stamina")
 check(not actor.start_dash(),"active dash and cooldown block repeated activation")
 await settle(90);key(KEY_SHIFT,false)
 check(absf((game.player.position-origin).dot(expected)-6.0)<.15,"stationary dash follows facing and holding Shift never repeats")
 await reset_at(origin)
 actor.model.state.vitals.stamina=10;key(KEY_SHIFT,true);key(KEY_SHIFT,false)
 check(actor.dash_remaining==0 and actor.model.value("stamina")==10,"low stamina blocks dash without spending stamina")
 await reset_at(origin)
 game.pause_menu.open();key(KEY_SHIFT,true);key(KEY_SHIFT,false);await settle(8)
 check(game.player.position.distance_to(origin)<.06 and actor.dash_remaining==0,"pause blocks dash")
 game.pause_menu.close();game.loot.open_bag();key(KEY_SHIFT,true);key(KEY_SHIFT,false);await settle(8)
 check(game.player.position.distance_to(origin)<.06 and actor.dash_remaining==0,"backpack blocks dash")
 game.loot.close();await reset_at(origin)
 var direction:=direction_for(6.2);expected=game._screen_direction_to_world(direction)
 var wall:=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(8,5,.2);collider.shape=box;wall.add_child(collider);game.world.add_child(wall)
 wall.position=origin+expected*2.0+Vector3.UP*2.0;wall.rotation.y=atan2(expected.x,expected.z)
 await settle(2)
 game.movement=direction;key(KEY_SHIFT,true);key(KEY_SHIFT,false);game.movement=Vector2.ZERO;await settle(24)
 var distance: float=(game.player.position-origin).dot(expected)
 check(distance>0 and distance<1.9,"solid wall truncates dash before penetration")
 check(actor.dash_remaining==0,"collision stops active dash")
 check(game.CollisionSafety.clear_at(game.player,game.player.position),"wall dash leaves character collision clear")
 await shot("校园_撞墙停止");wall.queue_free();await settle(2);await reset_at(origin)
 game.movement=direction;key(KEY_SHIFT,true);key(KEY_SHIFT,false);game.movement=Vector2.ZERO;await settle(3)
 game.pause_menu.open();await settle(3);check(actor.dash_remaining==0,"opening a menu cancels an active dash");game.pause_menu.close()
 await reset_at(origin)
 game.movement=direction;key(KEY_SHIFT,true);key(KEY_SHIFT,false);game.movement=Vector2.ZERO;game.request_travel("city")
 var loader=preload("res://ui/loading_transition.gd").instance(self)
 while loader.busy:await process_frame
 await settle();check(actor.dash_remaining==0 and game.location_id=="city","transition cancels dash before entering the next scene")
 actor.refresh();await shot("街区_突进操作提示")
 var file:=FileAccess.open(OUTPUT+"验证结果.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"  "));file.close()
 print("DASH: ",checks," checks, ",failures," failures");quit(0 if failures==0 else 1)
