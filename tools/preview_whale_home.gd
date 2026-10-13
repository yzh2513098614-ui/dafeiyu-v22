extends SceneTree
## Reproducible GPU plates plus scoped gameplay checks with isolated saves.
const Safety=preload("res://character/collision_safety.gd")
const HEIGHT=5.2
var game
var output := "res://预览/大肥鱼之家_20261013"
var checks: Array = []
var failed := 0
var capture_images := false
var traces: Dictionary = {}

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("review")

func check(condition: bool, label: String, detail: Variant=null) -> void:
	checks.append({"pass":condition,"check":label,"detail":detail})
	if not condition:failed+=1;push_error("HOME FAIL: "+label+" "+str(detail))
	else:print("HOME PASS: ",label)

func settle(frames: int=8) -> void:
	for i in frames:await physics_frame

func _view(center: Vector3, size_value: float, point: Vector3, all_floors: bool=false) -> void:
	game.movement=Vector2.ZERO;game.player.position=point;game.player.velocity=Vector3.ZERO
	game.home_controller.cutaway=not all_floors;game.home_controller.set_layers()
	game.view_center=center;game.camera.size=size_value;game.view_size=size_value;game.camera_angle=-28;game._camera()
	game.character_material.set_shader_parameter("floor_height",point.y+game.CHARACTER_FLOOR_Y)
	game.ui.hide();game.district_canvas.hide();game.map_interactions.root.hide()
	if game.dialogue_controller and is_instance_valid(game.dialogue_controller.companion):game.dialogue_controller.companion.hide()

func plate(filename: String) -> void:
	if not capture_images:return
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	check(image.save_png(output+"/"+filename+".png")==OK,"GPU screenshot "+filename)

func walk_stair(x: float, front: float, back: float, base: float, label: String, up: bool) -> void:
	game.player.position=Vector3(x,base+.06,front+.80) if up else Vector3(x,base+HEIGHT+.06,back-.80)
	game.player.velocity=Vector3.ZERO;game._queue_collision_recovery(true)
	game.home_controller.cutaway=true
	game.movement=game._character_screen_travel(Vector3.FORWARD if up else Vector3.BACK).normalized()
	var trace: Array = []
	for frame in 560:
		await physics_frame;game.home_controller.physics(1.0/60.0)
		if frame%30==0:trace.append([frame,game.player.position.x,game.player.position.y,game.player.position.z])
		if (up and game.player.position.z<back-.68) or (not up and game.player.position.z>front+.68):break
	game.movement=Vector2.ZERO
	for i in 8:await physics_frame;game.home_controller.physics(1.0/60.0)
	trace.append(["arrival",game.player.position.x,game.player.position.y,game.player.position.z]);traces[label]=trace
	var expected_y: float=base+HEIGHT if up else base
	check(absf(game.player.position.y-expected_y)<.18,"continuous stair traversal "+label,game.player.position)
	check((game.player.position.z<back-.5) if up else (game.player.position.z>front+.5),"stair landing reached "+label,game.player.position)
	check(Safety.clear_at(game.player,game.player.position),"head and skirt clear "+label)
	print("HOME STAIR TRACE: ",label," ",JSON.stringify(trace))

func review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	capture_images=DisplayServer.get_name()!="headless"
	root.size=Vector2i(1600,1000)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="whale_home"
	prefs.world_save_path=output+"/isolated_world.json";prefs.settings_path=output+"/isolated_settings.cfg"
	prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.day_cycle=false
	prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.life_booted=false;game.set_physics_process(false)
	game.loot.save_path=output+"/isolated_inventory.json"
	game.dialogue_controller.save_path=output+"/isolated_dialogue.json"
	game.dialogue_controller.state.seen["welcome"]=true
	await settle(10);game.dialogue_controller.close();game.dialog_open=false
	game.atmosphere.set_time(12.0)
	var home: Node3D=game.home_controller.level
	check(game.location_id=="whale_home","registered game map and actual scene entry")
	check(game.locations.city.links.has("whale_home"),"bidirectional city guide connection")
	check(home.get_meta("furniture_count")>=120,"detailed furniture inventory",home.get_meta("furniture_count"))
	check(home.get_meta("detail_meshes")>=3000,"authored mesh detail",home.get_meta("detail_meshes"))
	check(home.get_meta("static_surfaces")<220,"static geometry batched",home.get_meta("static_surfaces"))
	check(game.room_zones.size()==15,"named indoor and outdoor zones")
	check(home.get_meta("walkable_slabs").size()>=10,"island, dock, landings and stair support")
	check(game.home_controller.fish.size()==11,"animated aquarium whale and reef fish")
	check(game.home_controller.boats.size()==2,"two animated whale rowboats")
	check(game.home_controller.facilities.size()==9,"nine connected furniture facilities",game.home_controller.facilities.size())
	game.player.position=Vector3(-9.6,.07,11);game._queue_collision_recovery(true)
	game.home_controller.physics(1.0/60.0)
	check(Safety.supported(game.player,game.player.position),"safe entry support")
	check(Safety.clear_at(game.player,game.player.position),"safe entry silhouette")
	# Check the walking lane, leaving room for the current 1.03 m skirt guard.
	for point in [Vector3(-2.8,HEIGHT+.05,3.0),Vector3(2.8,HEIGHT*2+.05,-1.0)]:
		check(Safety.supported(game.player,point),"curved balcony has physical support "+str(point.y))
		check(Safety.clear_at(game.player,point),"curved balcony is walkable "+str(point.y))
	for spec in [[Vector3(-3,HEIGHT+.04,-9.4),"sofa"],[Vector3(-2.6,HEIGHT*2+.04,-13.6),"bed"],[Vector3(-11.9,.04,-8.9),"fridge"],[Vector3(2,.04,1.6),"dining table"],[Vector3(-3.1,HEIGHT+.04,-14.78),"aquarium"]]:
		check(not Safety.clear_at(game.player,spec[0]),"physical furniture collision "+str(spec[1]))
	for i in 3:
		var point:=Vector3(4.4,i*HEIGHT+.05,-7.5 if i>0 else 5.4)
		game.player.position=point;game.home_controller.set_layers()
		check(home.get_node("Floor"+str(i)).visible,"current floor visible "+str(i+1))
		if i<2:check(not home.get_node("Floor"+str(i+1)).visible,"upper floor automatically hidden "+str(i+1))
		game._refresh_zone();check(game.zone_label.text.contains(str(i+1)+"F"),"zone tracks physical floor "+str(i+1),game.zone_label.text)
	var fridge: Node3D=game.world.get_node("HomeAction_blue_fridge")
	game.player.position=Vector3(-11.9,.05,-6.92);game._queue_collision_recovery(true)
	await settle(3)
	check(game.map_interactions.try_interact(),"E proximity interaction activates fridge")
	await create_timer(.75).timeout
	check(fridge.opened and absf(fridge.parts[0].rotation.y)>1.5,"cabinet door animation opens")
	fridge.interact();await create_timer(.75).timeout
	check(not fridge.opened and absf(fridge.parts[0].rotation.y)<.05,"cabinet door animation closes")
	var fish: Node3D=game.home_controller.fish[0];var fish_start: Vector3=fish.position
	await create_timer(.5).timeout
	check(fish.position.distance_to(fish_start)>.025,"visible aquarium swimming animation")
	game.world.get_node("HomeAction_aquarium_feed").interact();check(game.home_controller.feeding>0,"aquarium feeding action")
	var hour_before: float=game.atmosphere.hour
	game.world.get_node("HomeAction_whale_bed").interact();check(is_equal_approx(game.atmosphere.hour,fposmod(hour_before+2.,24.)),"bed rest advances two hours")
	game.world.get_node("HomeAction_star_lights").interact();check(game.home_controller.extra_lights,"star light interaction")
	await walk_stair(10.8,6.6,-6.0,0,"1F_to_2F",true)
	await walk_stair(10.8,6.6,-6.0,0,"2F_to_1F",false)
	await walk_stair(-10.8,-1.4,-14.0,HEIGHT,"2F_to_3F",true)
	await walk_stair(-10.8,-1.4,-14.0,HEIGHT,"3F_to_2F",false)
	game.player.position=Vector3(4.4,HEIGHT*2+.05,-7.5);game._queue_collision_recovery(true)
	check(game._save(),"isolated world save succeeds")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prefs.world_save_path))
	check(saved.location=="whale_home" and float(saved.position_y)>10,"save retains map and upper-floor height")
	game._travel("city")
	check(not game.home_controller.is_active() and game.player.motion_mode==CharacterBody3D.MOTION_MODE_FLOATING,"leaving restores normal city movement")
	var city_gate := false
	for portal in game.portals:if portal.target=="whale_home":city_gate=true
	check(city_gate,"walkable city entrance exists")
	check(game._restore(),"isolated world restore succeeds")
	check(game.location_id=="whale_home" and game.player.position.y>10,"restore returns to third floor")
	check(game.home_controller.extra_lights,"facility state survives travel and restore")
	game.atmosphere.set_time(12.0)
	_view(Vector3(0,4.4,1.8),62,Vector3(-9.6,.05,11),true);await plate("01_island_overview")
	root.size=Vector2i(1200,1450)
	_view(Vector3(0,6.5,-6.8),50,Vector3(2.5,.05,5.2),true);await plate("02_three_storey_home")
	root.size=Vector2i(1600,1000)
	_view(Vector3(-4.1,1.0,-6.8),15,Vector3(-5.1,.05,-1.8));await plate("03_kitchen_details")
	_view(Vector3(2.9,.8,1.1),12.3,Vector3(5.7,.05,4.8));await plate("04_dining_details")
	_view(Vector3(-3.0,HEIGHT+.8,-9.9),14,Vector3(1.9,HEIGHT+.05,-6.4));await plate("05_aquarium_living_room")
	_view(Vector3(6.8,HEIGHT+.8,-11.8),12.0,Vector3(3.1,HEIGHT+.05,-10));await plate("06_study_details")
	_view(Vector3(-2.8,HEIGHT*2+.8,-13.8),14,Vector3(1.8,HEIGHT*2+.05,-9));await plate("07_whale_bedroom")
	_view(Vector3(8.1,HEIGHT*2+.8,-7.4),12.6,Vector3(5.5,HEIGHT*2+.05,-7.3));await plate("08_stargazing_terrace")
	_view(Vector3(0,.4,27.1),25,Vector3(0,.05,28));await plate("09_whale_docks")
	_view(Vector3(-19.3,.4,10.5),14.5,Vector3(-17,.05,14.4));await plate("10_flower_garden")
	game.atmosphere.set_time(20.0)
	_view(Vector3(0,7.0,-8.4),38,Vector3(2.5,.05,5.2),true);await plate("11_home_at_night")
	game.atmosphere.set_time(12.0)
	root.size=Vector2i(1200,900)
	_view(Vector3(-3.0,HEIGHT+.8,-8.9),15.0,Vector3(1.8,HEIGHT+.05,-6.5));game.ui.show();game.district_canvas.show();game.map_interactions.root.show();game._refresh_zone()
	await plate("12_live_game_4x3")
	game.queue_free();for i in 6:await process_frame
	var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
	menu._show_page("journey");await settle(4)
	check(menu.content.find_child("StartWhaleHome",true,false)!=null,"title journey page exposes direct home entry")
	check(menu._journey_place({"location":"whale_home"}).contains("大肥鱼之家"),"resume screen names the new map")
	if capture_images:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output+"/13_start_menu_entry.png")==OK,"GPU screenshot direct game entry")
	var report: Dictionary={"checks":checks,"passed":checks.size()-failed,"failed":failed,"traces":traces,"map":"whale_home","gpu_capture":capture_images}
	var file:=FileAccess.open(output+"/checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("WHALE HOME REVIEW: ",checks.size()," CHECKS, ",checks.size()-failed," PASSED, ",failed," FAILED")
	quit(1 if failed else 0)
