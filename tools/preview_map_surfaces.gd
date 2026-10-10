extends SceneTree
## Fixed views of the production world; uses the existing isolated save flags.
var game
var prefix := "地图材质_修改前_"
var records: Array = []

func _initialize() -> void:
	if "--after" in OS.get_cmdline_user_args():prefix="地图材质_改善后_"
	call_deferred("capture")

func place(id: String,hour: float,size: float) -> void:
	game._travel(id);game.set_physics_process(false)
	game.atmosphere.set_time(hour);game.atmosphere.cycle_enabled=false
	game.ui.hide();game.pack26_controller.root.hide()
	if game.pack26_controller.is_active():
		game.pack26_controller.floor_cutaway=true;game.pack26_controller.level.set_floor_view(0,true)
	for label in game.world.find_children("*","Label3D",true,false):label.hide()
	game.camera.size=size;game.view_size=size
	game.view_center=game.player.position if id.begins_with("pack26") else Vector3.ZERO
	game._camera()

func near_fixture() -> void:
	for lamp in game.atmosphere.lamps:
		if lamp.is_visible_in_tree() and lamp.global_position.y<3:
			game.view_center=Vector3(lamp.global_position.x,0,lamp.global_position.z)
			game._camera();return

func frame(tag: String) -> void:
	for i in 24:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/"+prefix+tag+".png")
	var material_counts: Dictionary={}
	var boxes: Array=[]
	for node: MeshInstance3D in game.world.find_children("*","MeshInstance3D",true,false):
		if node.mesh is BoxMesh and str(node.get_path()).contains("Architecture"):
			boxes.append({"name":str(node.name),"size":str(node.mesh.size)})
		for surface in node.mesh.get_surface_count():
			var m:=node.get_active_material(surface)
			if m is StandardMaterial3D:
				var name: String=m.resource_name
				material_counts[name]=int(material_counts.get(name,0))+1
	var lights: Array=[]
	for lamp in game.atmosphere.lamps:
		var reach: float=lamp.spot_range if lamp is SpotLight3D else lamp.omni_range
		lights.append({"part":str(lamp.get_parent().name),"type":lamp.get_class(),"position":str(lamp.global_position),"visible":lamp.is_visible_in_tree(),"range":reach})
	records.append({"scene":tag,"materials":material_counts,"boxes":boxes,"lights":lights})
	print("MAP SURFACE CAPTURE ",tag)

func capture() -> void:
	root.size=Vector2i(1000,750)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_hospital"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	place("pack26_hospital",12,16);await frame("医院日间")
	place("pack26_hospital",22,12);near_fixture();await frame("医院灯具")
	place("pack26_foodhall",22,14);near_fixture();await frame("餐厅夜间")
	place("apt_1",12,18);await frame("公寓日间")
	place("apt_1",22,14);near_fixture();await frame("公寓夜间")
	place("school_1",12,18);await frame("学校")
	if "--after" in OS.get_cmdline_user_args():
		place("school_1",22,16);near_fixture();await frame("学校夜间")
	place("city",18,24);await frame("街道")
	if "--after" in OS.get_cmdline_user_args():
		place("pack26_hospital",22,12);near_fixture()
		var origin: Vector3=game.view_center
		for i in 8:
			game.view_center=origin+Vector3(.045*i,0,.025*i);game._camera()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(180,100,640,500)).save_png("res://预览/地图材质_移动%02d.png"%i)
		game.pack26_controller.level.set_floor_view(3.6,true)
		print("UPPER FLOOR FIXTURES ",game.atmosphere.lamps.filter(func(lamp):return lamp.is_visible_in_tree()).size())
		game.pack26_controller.level.set_floor_view(0,true)
		print("GROUND FLOOR FIXTURES ",game.atmosphere.lamps.filter(func(lamp):return lamp.is_visible_in_tree()).size())
	FileAccess.open("res://预览/"+prefix+"记录.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	quit()
