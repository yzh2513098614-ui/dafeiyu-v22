extends SceneTree
const Safety=preload("res://character/collision_safety.gd")
var game
var failed:=0
var checked:=0
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("review")
func check(value: bool, label: String) -> void:
	checked+=1
	if not value: failed+=1;push_error("PASTEL FAIL: "+label)
	else:print("PASTEL PASS: ",label)
func review() -> void:
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="whale_home"
	prefs.world_save_path="res://预览/大肥鱼之家_小清新_20261014/isolated_world.json"
	prefs.settings_path="res://预览/大肥鱼之家_小清新_20261014/isolated_settings.cfg"
	prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false
	prefs.values.follow=true;prefs.values.day_cycle=false;prefs.values.fullscreen=false
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.life_booted=false;game.set_physics_process(false)
	game.loot.save_path="res://预览/大肥鱼之家_小清新_20261014/inventory.json"
	game.dialogue_controller.save_path="res://预览/大肥鱼之家_小清新_20261014/dialogue.json"
	for i in 6:await physics_frame
	game.dialogue_controller.close();game.dialog_open=false
	for point in [Vector3(-2.8,5.25,3.0),Vector3(2.8,10.45,-1.0)]:check(Safety.clear_at(game.player,point),"balcony inner walking lane "+str(point))
	var route: Array[Vector3]=[Vector3(-9.6,.05,11),Vector3(0,.05,11),Vector3(0,.05,33.7)]
	var route_ok:=true
	for segment in route.size()-1:
		var steps:=ceili(route[segment].distance_to(route[segment+1])/.25)
		for i in steps+1:
			var point: Vector3=route[segment].lerp(route[segment+1],float(i)/steps)
			if not Safety.clear_at(game.player,point) or not Safety.supported(game.player,point):route_ok=false;print("ROUTE BLOCKED: ",point)
	check(route_ok,"continuous front entrance to dock return route")
	var side_ok:=true
	for x in [-31.0,31.0]:
		for i in 261:
			var point:=Vector3(x,.05,-42+i*.25)
			if not Safety.clear_at(game.player,point) or not Safety.supported(game.player,point):side_ok=false;print("SIDE ROUTE BLOCKED: ",point)
	check(side_ok,"both side garden walking lanes stay clear")
	var landing: Array[Vector3]=[Vector3(-10.8,10.45,-14.69),Vector3(-10.8,10.45,-15.6),Vector3(-6.8,10.45,-15.6),Vector3(-6.8,10.45,-9.2),Vector3(-4.4,10.45,-9.2)]
	var landing_ok:=true
	for segment in landing.size()-1:
		var steps:=ceili(landing[segment].distance_to(landing[segment+1])/.20)
		for i in steps+1:
			var point: Vector3=landing[segment].lerp(landing[segment+1],float(i)/steps)
			if not Safety.clear_at(game.player,point) or not Safety.supported(game.player,point):landing_ok=false;print("LANDING BLOCKED: ",point)
	check(landing_ok,"third floor landing connects to bedroom walking lane")
	game.player.position=Vector3(-10.8,10.45,-15.6)
	game.home_controller.cutaway=true;game.home_controller.set_layers()
	check(not game.home_controller.level.get_node("Roof").visible,"follow camera keeps third floor roof out of the player view")
	var rugs_ok:=true
	for rug: Vector3 in game.home_controller.level.get_meta("rug_surfaces"):
		var feet: float=floorf(rug.y/5.2)*5.2+game.CHARACTER_FLOOR_Y
		if rug.y>=feet:rugs_ok=false
	check(rugs_ok,"all three rug surfaces stay below character foot depth")
	game.atmosphere.set_time(12)
	await process_frame;await process_frame
	check(game.atmosphere.environment.background_color.is_equal_approx(Color("dcede5")),"local pastel daylight is active")
	check(is_equal_approx(game.atmosphere.sun.light_energy,.40) and is_equal_approx(game.atmosphere.environment.ambient_light_energy,.35),"reduced home daylight energy")
	game.atmosphere.set_effects(true)
	await process_frame;await process_frame
	var petals: MultiMeshInstance3D=game.home_controller.garden_petals
	var start: Vector3=petals.multimesh.get_instance_transform(0).origin
	var clock_before: float=game.home_controller.sea_clock
	await create_timer(.2).timeout
	var moved: float=start.distance_to(petals.multimesh.get_instance_transform(0).origin)
	print("PETAL PROBE: renderer=",RenderingServer.get_video_adapter_name()," clock=",game.home_controller.sea_clock-clock_before," delta=",moved," start=",start," end=",petals.multimesh.get_instance_transform(0).origin)
	check(game.home_controller.sea_clock-clock_before>.15 and (DisplayServer.get_name()=="headless" or moved>.02),"garden petal animation advances")
	game.atmosphere.set_effects(false);await process_frame;await process_frame
	check(not petals.visible,"effects setting hides petals")
	game.atmosphere.set_effects(true)
	game.atmosphere.set_time(20);await process_frame;await process_frame
	check(float(game.home_controller.level.get_meta("sea_material").get_shader_parameter("night_weight"))>.99,"night water follows the game clock")
	game.atmosphere.set_time(12);await process_frame;await process_frame
	game._travel("city");await process_frame
	check(not game.atmosphere.environment.background_color.is_equal_approx(Color("dcede5")),"leaving home restores city environment")
	print("PASTEL MAP CHECK: ",checked," CHECKS, ",checked-failed," PASSED, ",failed," FAILED")
	game.queue_free()
	for i in 6:await process_frame
	quit(1 if failed else 0)
