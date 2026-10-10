extends SceneTree
## Export reusable materials and check that restaurant state clears on travel.
const OUTPUT="C:/Users/Administrator/Documents/Codex/2026-10-10/restaurant-render-v22/project_files/"
func _initialize() -> void:call_deferred("finish")
func finish() -> void:
	var surfaces: Script=load("res://district/wall_surfaces.gd")
	DirAccess.make_dir_recursive_absolute(OUTPUT+"assets/modern/wall_surfaces")
	var exported:=0
	for id in surfaces.PRESETS:
		var recipe: Dictionary=surfaces.PRESETS[id]
		var material: Material=surfaces.material(id,Vector3.RIGHT,recipe.scope=="外墙",Color(recipe.tint))
		var error:=ResourceSaver.save(material,OUTPUT+"assets/modern/wall_surfaces/"+id+".tres")
		if error!=OK:push_error("Material export failed: "+str(id));quit(1);return
		exported+=1
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="restaurant_1"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false
	var script: Script=load("res://district/continuous_world.gd")
	if script==null or not script.can_instantiate():quit(1);return
	var game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.life_booted=false;game.set_physics_process(false)
	for i in 6:await process_frame
	var restaurant: Dictionary=game.shell.get_meta("restaurant_finish",{})
	if restaurant.is_empty():push_error("Restaurant finish was not installed");quit(1);return
	game._travel("hospital_1");game.life_booted=false
	if game.shell.has_meta("restaurant_finish") or game.atmosphere.environment.adjustment_enabled:
		push_error("Restaurant state leaked into hospital");quit(1);return
	print("FINAL FINISH CHECK: exported=",exported," restaurant=",restaurant," hospital state cleared=true")
	game.queue_free();current_scene=null
	for i in 5:await process_frame
	quit()
