extends SceneTree
## Exercises the actual dialogue controller with an isolated save and native UI.
const OUT="res://预览/正式对话迁移_20261016/"
const Document=preload("res://ui/design/layout_document.gd")
var game
var checks:Array=[]
var entries:Array=[]
var failures:=0

func _initialize()->void:
 if not "--show-dialogue" in OS.get_cmdline_user_args():
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(value:bool,message:String)->void:
 checks.append({"ok":value,"message":message});print("PASS " if value else "FAIL ",message)
 if not value:failures+=1;push_error(message)

func settle(count:int=8)->void:
 for i in count:await process_frame

func shot(name:String,id:String,title:String)->void:
 await settle();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name+".png"))==OK,"native screenshot "+name)
 if "--bake-gal-designs" in OS.get_cmdline_user_args():
  var entry:=Document.capture(id,game.dialogue_controller.root,title);entries.append(entry)
  check(entry.error==OK,"editable capture "+id)
  check(DirAccess.copy_absolute(ProjectSettings.globalize_path("res://ui/design/baselines/"+id+".tscn"),ProjectSettings.globalize_path(entry.scene))==OK,"install editable page "+id)

func run()->void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-session-ui" in args or not "--test-dialogue" in args:push_error("Required isolation flags: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs");prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.day_cycle=false;prefs.starting_place="story_quay";prefs.continue_game=false;prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json"
 var designs=root.get_node("UiDesign");designs.enabled=false;root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await settle(30);game.set_physics_process(false);game.atmosphere.set_time(12)
 var d=game.dialogue_controller;d.save_path=OUT+"dialogue.json";d.state={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]};d.context={"room":"海风码头 · 海风与来信","object":"潮汐手记"};d.start("welcome")
 if "--show-dialogue" in args:
  designs.enabled=true;root.size=Vector2i(1280,720);game.set_physics_process(true);d.advance();DisplayServer.window_set_title("大肥鱼 · 正式对话新界面（隔离存档）");return
 check(d.active and game.dialog_open and not game.ui.visible,"actual dialogue captures game input")
 check(d.view.tools.size()==9 and d.box.position.y>0,"native Galgame toolbar and bottom gradient")
 check(d.is_typing(),"original typewriter starts incomplete");d.advance();var logged:int=d.state.history.size();d._process(.1)
 check(not d.is_typing() and d.state.history.size()==logged,"complete current sentence once")
 d.view.tools["Q.SAVE"].pressed.emit();check(not d.state.get("quick_save",{}).is_empty() and FileAccess.file_exists(d.save_path),"quick save persists through real dialogue save path")
 await shot("01_正式对话","dialogue_gal","对话 · 粉色渐变正文")
 d.advance();d.advance();check(d.current_node=="ask" and d.choice_buttons.size()==3 and d.choice_panel.visible,"original three replies remain live")
 await shot("02_正式分支","dialogue_gal_choices","对话 · 粉色回复")
 d.choice_buttons[0].pressed.emit();check(d.current_node=="about" and d.state.flags.has("asked_harbor"),"real reply applies original story flag")
 d.view.tools.BACK.pressed.emit();check(d.current_node=="ask" and not d.state.flags.has("asked_harbor"),"back restores question and clears later choice flag")
 d.advance();d.choice_buttons[1].pressed.emit();check(d.current_node=="guide" and game.route_destination=="community_1","reselection still marks actual game route")
 d.view.tools["Q.LOAD"].pressed.emit();check(d.current_node=="hello" and not d.state.flags.has("route_community") and d.state.history.size()==1 and game.route_destination=="","quick load restores saved node flags history and route")
 d.show_backlog();var node:String=d.current_node;d.set_auto(true);d._process(20);check(d.current_node==node and d.backlog.visible,"backlog pauses automatic reading")
 await shot("03_正式回看","dialogue_gal_backlog","对话 · 粉色回看")
 d.jump_history(0);check(d.current_node=="hello" and d.state.history.is_empty(),"history entry returns to actual story node without duplicate log")
 d.show_config();var revealed:int=d.text_label.visible_characters;d._process(20);check(d.config_open and d.text_label.visible_characters==revealed,"reading settings pause typewriter")
 var slider=d.view.config.find_child("Reading_speed",true,false);slider.value=45;d.hide_config();check(float(d.reading.speed)==45 and float(d.state.reading.speed)==45,"reading speed writes through native slider to save")
 d.show_config();await shot("04_正式阅读设置","dialogue_gal_config","对话 · 阅读设置");d.hide_config()
 d.toggle_hidden();d._process(20);check(d.ui_hidden and not d.view.chrome.visible and d.text_label.visible_characters==revealed,"hidden chrome pauses reading and leaves portrait visible")
 d.toggle_hidden();d.set_skip(true);d._process(1);d._process(.2);d._process(1)
 check(d.current_node=="ask" and d.choice_panel.visible and not d.skip_play,"fast forward stops at reply choices")
 d.close();check(not d.active and not game.dialog_open and game.ui.visible,"closing restores actual game controls")
 if not entries.is_empty():
  var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
  for entry in entries:
   var old_id:String={"dialogue_gal":"dialogue","dialogue_gal_choices":"dialogue_choices","dialogue_gal_backlog":"dialogue_backlog"}.get(entry.id,entry.id);var found:=false
   for old in catalog:
    if old.id in [old_id,entry.id]:old.id=entry.id;old.scene=entry.scene;old.controls=entry.controls;old.title=entry.title;found=true;break
   if not found:catalog.append({"id":entry.id,"scene":entry.scene,"controls":entry.controls,"title":entry.title})
  var file:=FileAccess.open("res://ui/design/catalog.json",FileAccess.WRITE);file.store_string(JSON.stringify(catalog," ")+"\n");file.close()
 designs.reload_designs();designs.enabled=true;d.start("welcome");d.advance();await settle()
 check(d.view.tools.size()==9 and d.text_label.get_theme_color("default_color")==Color("fffafc"),"editable pages preserve new dialogue style")
 var report:=FileAccess.open(OUT+"checks.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"editable_pages":entries},"  "));report.close();print("GAL DIALOGUE: ",checks.size()," checks, ",failures," failures")
 game.queue_free();await settle(3);quit(0 if failures==0 else 1)
