extends SceneTree
## Inspect only floor rendering at three zooms and during a short camera pan.
var game
var prefix:="地砖_修正后"

func _initialize() -> void:call_deferred("capture_floor")

func image_frame() -> Image:
	for i in 2:await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func capture_floor() -> void:
	root.size=Vector2i(1000,750)
	if "--before" in OS.get_cmdline_user_args():prefix="地砖_修正前"
	var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="pack26_foodhall";prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=false
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;game.set_physics_process(false)
	game.ui.hide();game.pack26_controller.root.hide();game.player.hide()
	for label in game.world.find_children("*","Label3D",true,false):label.hide()
	var origin:=Vector3(0,0,8)
	for zoom in [12.0,22.0,90.0]:
		game.camera.size=zoom;game.view_center=origin;game._camera()
		var frame: Image=await image_frame();frame.save_png("res://预览/"+prefix+"_距离%d.png"%zoom)
	game.camera.size=22
	for i in 20:
		game.view_center=origin+Vector3(.04*i,0,.025*i);game._camera()
		var frame: Image=await image_frame()
		frame.get_region(Rect2i(360,268,280,210)).save_png("res://预览/"+prefix+"_移动%02d.png"%i)
	print("FLOOR RENDER: ",prefix," / MSAA ",root.msaa_3d," / JOINT MESHES ",game.pack26_controller.level.get_node("Architecture").find_children("*Joint*","MeshInstance3D",false,false).size())
	quit()
