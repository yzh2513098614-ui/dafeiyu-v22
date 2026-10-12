extends SceneTree
## Focused integration check with real rendering, collision and isolated saves.
const OUTPUT="res://预览/武鸣校区_20261012/"
var game
var checks:=0
var failures:=0

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

func shot(name: String) -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+name+".png"))

func key(code: Key) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;root.push_input(event,true)
 await process_frame
 event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false;root.push_input(event,true)

func wait_loading(name: String) -> void:
 var loader=preload("res://ui/loading_transition.gd").instance(self)
 var start:=Time.get_ticks_msec();var captured:=false;var previous:=0.0;var monotonic:=true
 while loader.busy and Time.get_ticks_msec()-start<120000:
  monotonic=monotonic and loader.progress>=previous;previous=loader.progress
  if not captured and loader.progress>.3 and loader.progress<.9:await shot(name);captured=true
  await process_frame
 check(not loader.busy and not paused,"loading finishes and releases input "+name)
 check(monotonic,"progress remains monotonic "+name)
 await settle()

func plate(view_index: int,name: String,hour: float=12.0) -> void:
 game.set_physics_process(false)
 var view: Dictionary=game.campus_controller.layout.views[view_index]
 game.view_center=game.campus_controller.wp(view.target)
 game.camera_angle=float(view.yaw);game.camera.size=float(view.size);game._camera()
 game.atmosphere.sun.directional_shadow_max_distance=maxf(90,float(view.size)*2+100)
 game.atmosphere.set_time(hour)
 game.ui.hide();game.campus_controller.controls.hide();game.map_interactions.root.hide()
 if is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()
 for i in 3:await process_frame
 await shot(name)
 game.ui.show();game.campus_controller.controls.show();game.map_interactions.root.show()
 game.camera_angle=28;game.camera.size=32;game.view_center=game.player.position;game._camera();game.set_physics_process(true)

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true);root.size=Vector2i(1280,720)
 var prefs=root.get_node("HarborPrefs")
 prefs.continue_game=false;prefs.starting_place="city";prefs.world_save_path=OUTPUT+"isolated_world.json";prefs.settings_path=OUTPUT+"isolated_settings.cfg"
 prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false;prefs.values.day_cycle=false;prefs.values.follow=true;prefs.values.fullscreen=false
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await settle()
 check(game.locations.has("wuming_campus"),"campus is registered in the game map")
 check(game.find_route("city","wuming_campus")==["city","wuming_campus"],"campus is connected to the city guide")
 var entry: Dictionary={}
 for portal in game.portals:
  if portal.target=="wuming_campus":entry=portal;break
 check(not entry.is_empty(),"city has a physical campus entrance")
 game.player.position=entry.pos+Vector3(0,0,1);game._queue_collision_recovery(true);game.view_center=game.player.position;game._camera()
 await settle()
 check(not game.map_interactions._pick().is_empty(),"city entrance is reachable and interactable")
 await shot("01_街区校区专线")
 await key(KEY_E);await wait_loading("02_校园加载")
 check(game.location_id=="wuming_campus","E enters the campus through the real game route")
 if game.location_id!="wuming_campus":quit(1);return
 var campus=game.campus_controller
 check(campus.level.get_node("Buildings").get_child_count()==campus.layout.buildings.size(),"all source buildings are present")
 check(not campus.level.has_node("CampusWalker") and not campus.level.has_node("IsometricCamera"),"game character and camera replace the source viewer")
 check(not campus.level.has_node("WorldEnvironment") and not campus.level.has_node("AfternoonSun"),"only the existing game environment and sunlight remain")
 check(game.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"existing 2.5D renderer is retained")
 check(game.atmosphere.environment==game.get_node("RoomEnvironment").environment,"campus uses the shared game environment")
 check(game.atmosphere.contact_shading.is_visible_in_tree(),"shared contact shading is active")
 check(game.player.is_on_floor(),"game character is grounded on campus")
 check(game.player.position.distance_to(campus.spawn)<1,"entrance spawn stays at the intended campus road")
 await shot("03_校区南门漫步")
 var before: Vector3=game.player.position;game.movement=Vector2(0,-1)
 await settle(30);game.movement=Vector2.ZERO
 check(game.player.position.distance_to(before)>.3,"existing character can walk on campus roads")
 check(game.player.is_on_floor(),"walking maintains contact with ground")
 for stop in campus.STOPS.size():
  campus.visit_stop(stop);await wait_loading("地标加载_"+str(stop));await settle()
  check(game.player.is_on_floor() and absf(game.player.position.y)<.4,"grounded arrival at "+str(campus.STOPS[stop][0]))
  check(campus.controls.visible,"campus navigation stays available")
  if stop in [1,2,3,4]:await shot("地标漫步_"+str(stop))
 game.atmosphere.set_time(12);var day_energy: float=game.atmosphere.sun.light_energy
 game.atmosphere.set_time(20);check(game.atmosphere.sun.light_energy<day_energy,"campus uses the existing day and night lighting")
 await plate(0,"04_全校总览")
 await plate(15,"05_照片教学楼")
 await plate(18,"06_独立钟楼")
 await plate(13,"07_弘医双塔")
 await plate(14,"08_图书馆")
 await plate(17,"09_黄昏校园",18)
 game.atmosphere.set_time(12)
 var place: Vector3=game.player.position
 check(game._save(),"campus position can be saved")
 game.request_travel("city");await wait_loading("10_返回街区")
 check(game.location_id=="city" and not campus.controls.visible,"leaving removes the campus navigation")
 check(game.atmosphere.sun.directional_shadow_max_distance==90,"city shadow range is restored")
 check(game.player.motion_mode==CharacterBody3D.MOTION_MODE_FLOATING,"city character movement is restored")
 check(game._restore() and game.location_id=="wuming_campus","continue save restores the campus")
 await settle()
 check(Vector2(game.player.position.x,game.player.position.z).distance_to(Vector2(place.x,place.z))<.5,"save restores the character's campus position")
 await shot("11_继续校园")
 game.request_travel("restaurant_1");await wait_loading("12_回到原有室内")
 check(game.location_id=="restaurant_1" and not campus.controls.visible,"existing indoor scene works after campus travel")
 var report={"checks":checks,"failures":failures,"buildings":campus.layout.buildings.size(),"scope":"actual city entrance, full campus import, shared renderer and lighting, 7 landmark arrivals, walking, save restore and return to existing scenes"}
 var file:=FileAccess.open(OUTPUT+"验证结果.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 print("WUMING_CAMPUS: ",checks," checks, ",failures," failures")
 game.queue_free();await process_frame;quit(0 if failures==0 else 1)
