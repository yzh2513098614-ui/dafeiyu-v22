extends SceneTree
const OUTPUT="res://预览/暂停与旅程_v19/"
var game
var prefs
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)
func frames(count: int=6) -> void:
 for i in count:await process_frame
func key(code: Key) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event)
 await process_frame
 var release:=event.duplicate();release.pressed=false;root.push_input(release)
 await process_frame
func shot(filename: String) -> void:
 await frames();await create_timer(.2).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename))
func run() -> void:
 prefs=root.get_node("HarborPrefs")
 check(prefs.world_save_path=="user://whale_session_ui_test.json" and prefs.settings_path=="user://harbor_session_ui_test.cfg","session fixture uses isolated files")
 prefs.values.fullscreen=false;prefs.values.follow=true;prefs.starting_place="apt_2";prefs.continue_game=false;prefs.apply_window();root.size=Vector2i(1000,750)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await frames(12)
 game.dialogue_controller.close();game.dialogue_controller.state={"version":1,"seen":{"welcome":true},"flags":{},"bookmark":{},"history":[]}
 game.loot.inventory={"sea_biscuit":3};game.loot.bag_favorites={"sea_biscuit":true};game.loot._bag_count()
 await key(KEY_ESCAPE)
 check(game.pause_menu.active and not game.ui.visible,"actual Escape opens pause and hides underlying HUD")
 var anchor: Vector3=game.player.position
 game.movement=Vector2.RIGHT;await create_timer(.2).timeout
 check(game.player.position.distance_to(anchor)<.001,"pause blocks movement even when direction remains held")
 game.movement=Vector2.ZERO
 await key(KEY_Q)
 check(game.pause_menu.active and not game.dialogue_controller.active,"pause blocks conversation shortcut")
 var zoom: float=game.view_size
 var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.position=Vector2(960,710);root.push_input(wheel)
 await frames()
 check(game.view_size==zoom,"pause blocks world wheel zoom")
 await shot("01_暂停菜单.png")
 game.pause_menu.buttons.help.pressed.emit();await frames()
 check(game.pause_menu.page=="help","help button opens controls page")
 await shot("02_操作说明.png")
 await key(KEY_ESCAPE)
 check(game.pause_menu.active and game.pause_menu.page=="main","Escape from help returns to pause")
 await key(KEY_ESCAPE)
 check(not game.pause_menu.active and game.ui.visible,"Escape from pause resumes and restores HUD")
 await key(KEY_ESCAPE);game.pause_menu.buttons.settings.pressed.emit();await frames()
 check(game.settings_panel.visible and not game.pause_menu.active,"pause settings opens actual display preferences")
 await shot("03_暂停中的设置.png")
 await key(KEY_ESCAPE)
 check(game.pause_menu.active and not game.settings_panel.visible,"closing settings returns to pause")
 var actual_path: String=game.loot.save_path
 game.loot.save_path="user://session_ui_missing_folder/cannot_save.json"
 check(not game.pause_menu.save_session(),"save failure is reported")
 game.pause_menu.buttons.title.pressed.emit();await frames()
 check(current_scene==game and game.pause_menu.active,"failed save prevents leaving the session")
 game.loot.save_path=actual_path
 game.player.position=Vector3(1.25,0,0);game.overview_mode=true;game.view_size=35.5;game.favorites={"inn_2":true};game.set_route("inn_2")
 game.dialogue_controller.state.history=[{"speaker":"大肥鱼","topic":"home","text":"下次接着慢慢逛。"}]
 game.pause_menu.buttons.save.pressed.emit();await frames()
 var data=JSON.parse_string(FileAccess.get_file_as_string(prefs.world_save_path))
 check(data is Dictionary and data.version==3 and data.location=="apt_2" and absf(data.position[0]-1.25)<.001 and data.zoom==35.5,"save includes floor, position and camera")
 check(game.pause_menu.feedback.contains("已经记住"),"successful save appears in styled menu")
 await shot("04_保存反馈.png")
 game.pause_menu.buttons.title.pressed.emit();await frames(14)
 var menu=current_scene
 check(menu!=game and menu.has_method("_saved_journey"),"real save-and-title button changes scene")
 if menu==game:quit(1);return
 check(not menu.resume_button.disabled and menu._journey_place(menu._saved_journey())=="云湾公寓 · 2F","title shows validated last floor")
 await shot("05_继续旅程标题.png")
 var valid_save:=FileAccess.get_file_as_string(prefs.world_save_path)
 var invalid:=FileAccess.open(prefs.world_save_path,FileAccess.WRITE);invalid.store_string("{\"version\":3,\"location\":\"apt_2\",\"position\":[\"bad\",0]}");invalid.close();menu._render()
 check(menu.resume_button.disabled,"invalid position disables Continue")
 menu._start(true);await frames()
 check(current_scene==menu,"invalid save does not enter game")
 var restored:=FileAccess.open(prefs.world_save_path,FileAccess.WRITE);restored.store_string(valid_save);restored.close();menu._render()
 menu.resume_button.pressed.emit();await frames(14)
 game=current_scene
 check(game.location_id=="apt_2" and game.player.position.distance_to(Vector3(1.25,0,0))<.01,"real Continue restores exact floor and position")
 check(game.overview_mode and absf(game.view_size-35.5)<.001,"continue preserves saved zoom despite follow preference")
 check(game.loot.inventory.get("sea_biscuit",0)==3 and game.loot.bag_favorites.has("sea_biscuit"),"continue restores inventory and item favorites")
 check(game.favorites.has("inn_2") and game.route_destination=="inn_2","continue restores navigation favorites and route")
 check(game.dialogue_controller.state.history.size()==1,"continue restores conversation history")
 await shot("06_恢复后的漫步.png")
 print("SESSION UI CHECKS ",checks," PASSED ",checks-failures," FAILED ",failures)
 quit(0 if failures==0 else 1)
