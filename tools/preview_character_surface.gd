extends SceneTree
## Actual v22 pictures and lights. Compare only the character material.
var game
var prefix:="人物材质_修改前"

func _initialize() -> void:call_deferred("capture")

func shot(tag: String) -> void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/"+prefix+"_"+tag+".png")
	print("CHARACTER SURFACE ",tag)

func focus(location: String,hour: float) -> void:
	game._travel(location);game.set_physics_process(false)
	game.atmosphere.set_time(hour);game.atmosphere.cycle_enabled=false
	game.ui.hide();game.pack26_controller.root.hide()
	for label in game.world.find_children("*","Label3D",true,false):label.hide()
	game.camera.size=6;game.view_size=6
	game.view_center=game.player.position;game._camera()
	game.facing="down";game._set_character_pose(false)

func capture() -> void:
	root.size=Vector2i(1000,750)
	if "--after" in OS.get_cmdline_user_args():prefix="人物材质_改善后"
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_hospital"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	focus("pack26_hospital",12)
	game.pack26_controller.floor_cutaway=true;game.pack26_controller.level.set_floor_view(0,true)
	await shot("日间正面")
	game.facing="left";game._set_character_pose(false);await shot("日间侧面")
	game.facing="up_left";game._set_character_pose(false);await shot("日间背面")
	focus("apt_1",22)
	var lamp: OmniLight3D=game.atmosphere.lamps[0]
	game.player.position=Vector3(lamp.global_position.x+1.0,0,lamp.global_position.z+.4)
	game.view_center=game.player.position;game._camera();await shot("夜间台灯")
	# The same full-resolution frame under a controlled side light shows the
	# surface response more clearly than a dark night scene alone.
	focus("pack26_hospital",22)
	game.pack26_controller.floor_cutaway=true;game.pack26_controller.level.set_floor_view(0,true)
	var key:=OmniLight3D.new();key.position=game.player.position+Vector3(-1.2,1.4,1.0)
	key.omni_range=4;key.light_energy=.8;key.light_color=Color("ffddb8");game.world.add_child(key)
	await shot("左侧暖光")
	key.position=game.player.position+Vector3(1.2,1.4,1.0);key.light_color=Color("b9ddff")
	await shot("右侧冷光")
	key.free();game.atmosphere.set_time(12)
	game.camera.size=22;game._camera();await shot("常用视角")
	if "--after" in OS.get_cmdline_user_args():
		var origin: Vector3=game.view_center
		for i in 12:
			game.view_center=origin+Vector3(.012*i,0,.018*i);game._camera()
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(440,260,125,160)).save_png("res://预览/人物材质_移动%02d.png"%i)
	quit()
