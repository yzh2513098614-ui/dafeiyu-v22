extends "res://tools/preview_map_surfaces.gd"
## A short visual comparison of character and prop contour strength.
var stage := "调整前"

func _initialize() -> void:
	if "--after" in OS.get_cmdline_user_args():stage="加强后"
	call_deferred("capture")

func shot(tag: String) -> void:
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/轮廓加强_"+stage+"_"+tag+".png")
	print("SOFT CONTOUR ",tag)

func capture() -> void:
	root.size=Vector2i(1000,750)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="pack26_hospital"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	place("pack26_hospital",12,7)
	game.atmosphere.set_process(false)
	game.view_center=Vector3(-1.9,0,6.5);game._camera()
	game.facing="down";game._set_character_pose(false)
	await shot("正面近景")
	game.facing="left";game._set_character_pose(false)
	await shot("侧面近景")
	game.facing="down";game._set_character_pose(false)
	game.camera.size=22;game._camera();await shot("正常视角")
	quit()
