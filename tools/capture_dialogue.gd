extends SceneTree
var game
const OUTPUT="res://预览/像素立绘对话_v19/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1000,750)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game)
 for i in 5:await process_frame
 game._travel("community_1");game.overview_mode=false;game.view_center=Vector3(-5,0,5);game.view_size=24;game.camera.size=24;game._camera();game.set_physics_process(false)
 var d=game.dialogue_controller
 d.context={"room":"潮汐社区馆 · 1F","object":"阅读室"};d.start("cafe");d.advance()
 await shot("01_立绘对白.png")
 d.advance();d.advance();await shot("02_对话选项.png")
 d.choose(0);d.advance();await shot("03_思考表情.png")
 d.show_backlog();await shot("04_对话回看.png")
 d.hide_backlog();d.close()
 var old=game;root.remove_child(old);old.queue_free()
 var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu)
 await shot("05_开场选择.png")
 print("CAPTURED DIALOGUE PREVIEWS");quit()
func shot(name: String) -> void:
 for i in 6:await process_frame
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 var im:=root.get_texture().get_image()
 im.save_png(ProjectSettings.globalize_path(OUTPUT+name))
