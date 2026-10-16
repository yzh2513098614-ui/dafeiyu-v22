extends SceneTree
## Real title settings, with isolated preferences and no audible playback.
const OUT="res://预览/标题设置迭代_20261016/"
const Document=preload("res://ui/design/layout_document.gd")
var menu
var failures:=0
var checks:Array=[]

func _initialize()->void:
 AudioServer.set_bus_mute(0,true)
 call_deferred("run")

func settle(count:int=8)->void:
 for i in count:await process_frame

func check(value:bool,message:String)->void:
 checks.append({"ok":value,"message":message});print("PASS " if value else "FAIL ",message)
 if not value:failures+=1;push_error(message)

func run()->void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-session-ui" in args or not "--test-candy-title" in args:push_error("Required isolation flags: --test-session-ui --test-candy-title");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var prefs=root.get_node("HarborPrefs");prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json";prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false;prefs.values.day_cycle=true;prefs.day_minutes=12.0;prefs.apply_window()
 var designs=root.get_node("UiDesign");designs.enabled=false;root.size=Vector2i(1280,720)
 menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu;await settle();menu._show_page("settings");await settle()
 if "--show-title-settings" in args:
  designs.enabled=true;DisplayServer.window_set_title("大肥鱼 · 标题设置（隔离配置 · 静音预览）");return
 var view=menu.content.get_node("TitleSettings")
 check(menu.setting_cards.size()==7,"all seven original display preferences remain available")
 var before:bool=prefs.values.smooth_camera;var toggle:Button=menu.setting_cards.smooth_camera
 toggle.grab_focus();toggle.pressed.emit()
 check(prefs.values.smooth_camera!=before and toggle.has_focus(),"real preference callback preserves keyboard focus")
 toggle.pressed.emit()
 view.day_speed.item_selected.emit(2)
 var saved:=ConfigFile.new();var saved_ok:=saved.load(prefs.settings_path)==OK
 check(saved_ok and is_equal_approx(float(saved.get_value("time","day_minutes",0)),24.0) and saved.get_value("display","smooth_camera") == before,"native day length picker and display toggle autosave to isolated config")
 menu.setting_cards.day_cycle.pressed.emit();check(view.day_speed.disabled,"day length follows the real cycle switch");menu.setting_cards.day_cycle.pressed.emit();view.day_speed.item_selected.emit(1);view.refresh()
 check(toggle.get_theme_stylebox("focus").expand_margin_left==0,"keyboard focus uses the existing single edge")
 if "--bake-title-settings-design" in args and not FileAccess.file_exists("res://ui/design/baselines/title_settings_sticker.tscn"):
  var entry:=Document.capture("title_settings_sticker",menu,"标题设置 · 蓝白分层")
  check(entry.error==OK,"editable native title settings page created")
  var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
  for row in catalog:
   if row.id in ["title_settings","title_settings_sticker"]:row.id=entry.id;row.scene=entry.scene;row.controls=entry.controls;row.title=entry.title
  var output:=FileAccess.open("res://ui/design/catalog.json",FileAccess.WRITE);output.store_string(JSON.stringify(catalog," ")+"\n");output.close()
 designs.reload_designs();designs.enabled=true;await settle()
 check(designs.contexts()[0].id=="title_settings_sticker" and view.get_node("SettingsShell").get_theme_stylebox("panel").border_width_left==7,"versioned editable page retains the thick outer rim")
 view.get_node("MusicSettings").pressed.emit();await settle();check(menu.page=="music" and root.get_node("MusicDirector").in_gallery(),"music settings link retains the real gallery navigation")
 menu._show_page("settings");await settle();menu.tabs.back.pressed.emit();await settle();check(menu.page=="title" and menu.menu_buttons.has("settings"),"return restores the original title menu")
 var report:=FileAccess.open(OUT+"checks.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));report.close()
 print("TITLE SETTINGS: ",checks.size()," checks, ",failures," failures")
 menu.queue_free();await settle(3);quit(0 if failures==0 else 1)
