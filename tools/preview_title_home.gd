extends SceneTree
## Opens the real title; checks are limited to the controls changed by this iteration.
const OUT="res://预览/标题首页迭代_20261016/"
const Document=preload("res://ui/design/layout_document.gd")
var menu
var failures:=0
var checks:Array=[]

func _initialize()->void:
 AudioServer.set_bus_mute(0,true);call_deferred("run")

func settle(count:int=6)->void:
 for i in count:await process_frame

func check(ok:bool,message:String)->void:
 checks.append({"ok":ok,"message":message});print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1;push_error(message)

func run()->void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-session-ui" in args or not "--test-candy-title" in args:push_error("Required isolation flags: --test-session-ui --test-candy-title");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var prefs=root.get_node("HarborPrefs");prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json";prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false;prefs.apply_window()
 var designs=root.get_node("UiDesign");designs.enabled=false;root.size=Vector2i(1280,720)
 menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu;await settle()
 if "--show-title-home" in args:
  designs.enabled=true;DisplayServer.window_set_title("大肥鱼 · 标题首页新设计（隔离存档 · 静音预览）");return
 check(menu.menu_buttons.size()==8 and menu.content.get_node("TitleMenuPlate").get_theme_stylebox("panel").border_width_left==7,"all original entries use the grouped native title layout")
 check(menu.resume_button.disabled==(menu._saved_journey().is_empty() or not menu.recovery_ok),"resume availability still follows the real save state")
 var start:Button=menu.menu_buttons.journey;start.grab_focus()
 check(start.has_focus() and start.get_node(start.focus_next)!=menu.resume_button if menu.resume_button.disabled else start.has_focus(),"keyboard traversal skips an unavailable resume")
 menu.greeting.get_node("TitleSkip").pressed.emit();check(menu.intro_label.visible_characters==-1 and menu.intro_label.text==menu.INTRO[-1],"title dialogue skip retains the actual greeting sequence")
 menu.greeting.get_node("TitleNext").pressed.emit();menu.auto_button.pressed.emit();check(menu.auto_intro and menu.intro_index==0,"next and auto retain the original reading state");menu.auto_button.pressed.emit()
 for id in ["journey","load","save","settings","memories","cg"]:
  menu.menu_buttons[id].pressed.emit();await settle()
  var ok:bool=menu.page==id
  if id=="settings":ok=ok and menu.content.has_node("TitleSettings")
  check(ok,"original title navigation "+id)
  menu.tabs.back.pressed.emit();await settle()
 if "--bake-title-home-design" in args and not FileAccess.file_exists("res://ui/design/baselines/title_home_sticker.tscn"):
  var entry:=Document.capture("title_home_sticker",menu,"标题首页 · 海风手记")
  check(entry.error==OK,"native editable title home page created")
  var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
  for row in catalog:
   if row.id=="title_title":row.id=entry.id;row.scene=entry.scene;row.controls=entry.controls;row.title=entry.title
  var output:=FileAccess.open("res://ui/design/catalog.json",FileAccess.WRITE);output.store_string(JSON.stringify(catalog," ")+"\n");output.close()
 designs.reload_designs();designs.enabled=true;await settle()
 check(designs.contexts()[0].id=="title_home_sticker" and menu.logo.texture.resource_path=="res://assets/ui/candy_title/logo.png","native editable page keeps the existing logo and real menu")
 var report:=FileAccess.open(OUT+"checks.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));report.close();print("TITLE HOME: ",checks.size()," checks, ",failures," failures")
 menu.queue_free();await settle(3);quit(0 if failures==0 else 1)
