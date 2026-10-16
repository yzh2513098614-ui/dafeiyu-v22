extends SceneTree
## Opens the real settings with isolated preferences; optional first-time design capture.
const OUT="res://预览/正式设置迭代_20261016/"
const Document=preload("res://ui/design/layout_document.gd")
var game
var failures:=0
var checks:Array=[]
var entries:Array=[]

func _initialize()->void:
 AudioServer.set_bus_mute(0,true)
 if not "--show-settings" in OS.get_cmdline_user_args():DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func settle(count:int=8)->void:
 for i in count:await process_frame

func check(value:bool,message:String)->void:
 checks.append({"ok":value,"message":message});print("PASS " if value else "FAIL ",message)
 if not value:failures+=1;push_error(message)

func capture(tab:String)->void:
 var id:="settings_"+tab+"_sticker"
 if not FileAccess.file_exists("res://ui/design/baselines/"+id+".tscn"):
  var entry:=Document.capture(id,game.settings_panel,{"display":"设置 · 蓝白画面","audio":"设置 · 音乐与音效","audition":"设置 · 音效试听"}[tab]);entries.append(entry);check(entry.error==OK,"editable native page "+id)

func run()->void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-session-ui" in args or not "--test-dialogue" in args:push_error("Required isolation flags: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var prefs=root.get_node("HarborPrefs");prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json";prefs.starting_place="apt_2";prefs.continue_game=false;prefs.values.fullscreen=false;prefs.values.music=true;prefs.values.sfx=true;prefs.values.ambience=false;prefs.values.day_cycle=false
 var music=root.get_node("MusicDirector");var sfx=root.get_node("SfxDirector");music.set_volume(.55);sfx.set_volume(.5)
 var designs=root.get_node("UiDesign");designs.enabled=false;root.size=Vector2i(1100,825)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await settle(24);game._settings(true)
 var view=game.settings_view;view._set_tab("audio");await settle()
 if "--show-settings" in args:
  designs.enabled=true;DisplayServer.window_set_title("大肥鱼 · 正式设置新界面（隔离配置 · 静音预览）");return
 view.volume_slider.value=60;view.sfx_slider.value=45
 check(is_equal_approx(music.music_volume(),.6) and is_equal_approx(sfx.volume(),.45),"native volume sliders retain real audio callbacks")
 var before:bool=music.music_enabled();view.music_switch.pressed.emit();check(music.music_enabled()!=before and view.volume_slider.editable==music.music_enabled(),"music switch updates real state and slider availability");view.music_switch.pressed.emit()
 var original:int=view.style_picker.selected;view.style_picker.item_selected.emit((original+1)%view.style_picker.item_count);check(music.style_key()==music.style_keys()[(original+1)%view.style_picker.item_count],"music style picker retains original selection callback");view.style_picker.item_selected.emit(original)
 var smooth:bool=prefs.values.smooth_camera;view.switches.smooth_camera.pressed.emit();check(prefs.values.smooth_camera!=smooth,"display toggle retains original preferences callback");view.switches.smooth_camera.pressed.emit()
 var saved:=ConfigFile.new();var saved_ok:=saved.load(prefs.settings_path)==OK
 check(saved_ok and is_equal_approx(float(saved.get_value("audio","music_volume",-1)),.6) and is_equal_approx(float(saved.get_value("audio","sfx_volume",-1)),.45),"settings autosave writes isolated configuration")
 view.volume_slider.value=55;view.sfx_slider.value=50
 for tab in ["display","audio","audition"]:
  view._set_tab(tab);await settle();var cards:Array=view.display_cards if tab=="display" else view.audio_cards if tab=="audio" else view.audition_cards
  check(not cards.is_empty() and cards[0].visible,"settings tab remains usable "+tab)
  if "--bake-settings-designs" in args:capture(tab)
 if not entries.is_empty():
  var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
  for entry in entries:
   for row in catalog:
    if row.id==str(entry.id).trim_suffix("_sticker"):row.id=entry.id;row.scene=entry.scene;row.controls=entry.controls;row.title=entry.title
  var output:=FileAccess.open("res://ui/design/catalog.json",FileAccess.WRITE);output.store_string(JSON.stringify(catalog," ")+"\n");output.close()
 designs.reload_designs();designs.enabled=true;view._set_tab("audio");await settle()
 check(game.settings_panel.get_theme_stylebox("panel").border_width_left==7,"editable pages retain the new thick outer frame")
 game._settings(false);check(not game.settings_panel.visible,"original close returns to the game")
 var report:=FileAccess.open(OUT+"checks.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"pages":entries},"  "));report.close();print("STICKER SETTINGS: ",checks.size()," checks, ",failures," failures")
 game.queue_free();await settle(3);quit(0 if failures==0 else 1)
