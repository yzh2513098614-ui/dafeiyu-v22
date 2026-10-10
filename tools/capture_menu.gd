extends SceneTree
## Review the real rendered menu and its navigation without keeping preview settings.
const OUTPUT="res://预览/像素立绘对话_v19/"
var menu
var original_settings: PackedByteArray
var had_settings:=false
var original_values: Dictionary
var original_place: String
var prefs
func _initialize() -> void:call_deferred("run")
func run() -> void:
 prefs=root.get_node("HarborPrefs")
 original_values=prefs.values.duplicate();original_place=prefs.starting_place
 had_settings=FileAccess.file_exists(prefs.SETTINGS_PATH)
 if had_settings:original_settings=FileAccess.get_file_as_bytes(prefs.SETTINGS_PATH)
 prefs.values.fullscreen=false;prefs.apply_window();root.size=Vector2i(1000,750)
 menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 await shot("05_标题菜单.png")
 menu.menu_buttons.journey.pressed.emit()
 await shot("06_出发选择.png")
 for id in ["city","community_1","inn_1","apt_2"]:
  menu.cards[id].pressed.emit()
  await process_frame
  if prefs.starting_place!=id:fail("Destination selection did not update");return
  for card in menu.cards.values():
   var well=card.get_child(0);var pic=well.get_child(0)
   if pic.size.x>well.size.x+.1 or pic.size.y>well.size.y+.1:fail("Scene thumbnail overflow");return
 await shot("07_选中公寓.png")
 menu._show_page("settings")
 var before: bool=prefs.values.shadows
 menu.setting_cards.shadows.pressed.emit()
 if prefs.values.shadows==before:fail("Settings switch did not update");return
 await shot("08_画面设置.png")
 var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;root.push_input(escape)
 await process_frame
 var escape_up:=escape.duplicate();escape_up.pressed=false;root.push_input(escape_up)
 if menu.page!="title":fail("Escape did not return to title");return
 menu.menu_buttons.journey.grab_focus()
 var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.pressed=true;root.push_input(enter)
 await process_frame
 var enter_up:=enter.duplicate();enter_up.pressed=false;root.push_input(enter_up)
 await process_frame
 if menu.page!="journey":fail("Keyboard selection did not open departure page");return
 menu.start_button.pressed.emit()
 for i in 20:await process_frame
 if current_scene==null or current_scene.location_id!="apt_2":fail("Departure did not open the selected floor");return
 await shot("09_从公寓出发.png")
 restore_settings()
 print("MENU REVIEW PASSED: title, four destinations, bounded thumbnails, settings, Escape, Enter, selected-floor launch")
 quit()
func restore_settings() -> void:
 prefs.values=original_values;prefs.starting_place=original_place
 if had_settings:
  var file:=FileAccess.open(prefs.SETTINGS_PATH,FileAccess.WRITE);file.store_buffer(original_settings);file.close()
 else:DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.SETTINGS_PATH))
func fail(reason: String) -> void:
 restore_settings();push_error(reason);quit(1)
func shot(filename: String) -> void:
 for i in 8:await process_frame
 await create_timer(.25).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename))
