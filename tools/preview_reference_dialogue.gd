extends SceneTree
## Scoped visual/interaction check; uses isolated saves and muted audio.
const OUTPUT="res://预览/对话示例排版_20261013/"
const Document=preload("res://ui/design/layout_document.gd")
var checks:=0
var failures:=0
var game
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)
func settle()->void:
 for i in 10:await process_frame
func shot(name:String)->void:
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+name+".png"))
func capture(id:String,d:Node)->void:
 var result:Dictionary=Document.capture(id,d.root,"对话 · 示例排版")
 check(result.error==OK,"capture editable page "+id)
func run()->void:
 AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false
 prefs.settings_path=OUTPUT+"settings.cfg";prefs.world_save_path=OUTPUT+"world.json"
 prefs.starting_place="city";prefs.continue_game=false
 var design=root.get_node("UiDesign")
 var recapture:bool="--capture-reference-pages" in OS.get_cmdline_user_args()
 if recapture:design.enabled=false
 root.size=Vector2i(1448,1086)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await settle()
 game.set_physics_process(false)
 var d=game.dialogue_controller
 d.save_path=OUTPUT+"dialogue.json";d.state={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]}
 d.context={"room":"鲸落港","object":"这里"};d.start("welcome");d.advance()
 await settle()
 if recapture:capture("dialogue",d)
 check(d.box.position.y==755 and d.box.size.y==313,"bottom navy dialogue layout survives live design overrides")
 check(absf(d.portrait.get_global_rect().get_center().x-d.root.size.x*.5)<1,"portrait is centered")
 check(d.text_label.position.x==245,"body leaves space for whale medallion")
 check(d.text_label.get_content_height()<=d.text_label.size.y,"complete dialogue fits text region")
 await shot("01_对白_4比3")
 d.text_label.text="这里的海风很轻，街灯也刚刚亮起来。先慢慢走一圈吧，窗边的花、书架上的旧书，还有转角那间小店，都在等你发现。等到潮水退下，我们再一起去看看远处的码头，好吗？"
 d.text_label.visible_characters=-1
 await settle();check(d.text_label.get_content_height()<=d.text_label.size.y,"long Chinese line wraps without clipping")
 await shot("02_长句排版")
 d.advance();d.advance();await settle()
 check(d.choice_panel.visible and d.choice_buttons.size()==3,"replies remain available")
 check(d.choice_panel.get_global_rect().end.y<d.box.position.y,"replies clear the dialogue box")
 if recapture:capture("dialogue_choices",d)
 await shot("03_回复选项")
 d.set_auto(true);d._process(20);check(d.current_node=="ask","auto waits for reply")
 d.choice_buttons[1].pressed.emit();await settle()
 check(d.current_node=="guide","reply button follows the actual story branch")
 d.advance();d.show_backlog();await settle()
 check(d.backlog.visible and d.backlog_open,"backlog opens")
 if recapture:capture("dialogue_backlog",d)
 await shot("04_回看")
 d.hide_backlog();d.set_auto(false)
 d.advance()
 root.size=Vector2i(1920,1080);await settle()
 check(d.box.get_global_rect().end.x<=d.root.size.x,"wide-screen box stays within viewport")
 check(d.text_label.get_content_height()<=d.text_label.size.y,"wide-screen text remains visible")
 await shot("05_对白_16比9")
 root.size=Vector2i(1000,750);await settle();await shot("06_对白_1000x750")
 d.close();check(not game.dialog_open and game.ui.visible,"closing restores game HUD and input")
 print("REFERENCE DIALOGUE: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
