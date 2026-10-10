extends SceneTree
## Run with --test-session-ui --test-dialogue; all player saves remain isolated.
const OUTPUT="res://预览/蓝白UI_20261011/"
var checks:=0
var failures:=0
var game

func _initialize() -> void:call_deferred("run")

func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)

func settle(frames: int=12) -> void:
 for i in frames:await process_frame

func shot(filename: String) -> void:
 await settle()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename+".png"))==OK,"screenshot "+filename)

func click(button: Control) -> void:
 await settle(2)
 var point:=button.get_global_rect().get_center()
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 var released: InputEventMouseButton=event.duplicate();released.pressed=false;root.push_input(released,true)
 await settle(3)

func run() -> void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():
  push_error("Required isolation flags: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.music=false;prefs.values.sfx=false
 prefs.starting_place="apt_2";prefs.continue_game=false
 prefs.settings_path=OUTPUT+"isolated_settings.cfg";prefs.world_save_path=OUTPUT+"isolated_world.json"
 root.size=Vector2i(1000,750)
 var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 await shot("01_标题菜单")
 check(menu.theme.get_stylebox("normal","Button") is StyleBoxFlat,"menu uses native button skin")
 await click(menu.menu_buttons.journey)
 check(menu.page=="journey","pointer opens departure menu")
 if menu.page!="journey":quit(1);return
 await click(menu.cards.apt_2)
 check(prefs.starting_place=="apt_2","pointer selects existing destination")
 await shot("02_出发选择")
 await click(menu.start_button)
 await settle(30)
 game=current_scene
 if game==null or game.get("dialogue_controller")==null:
  check(false,"menu launches world");quit(1);return
 check(game.location_id=="apt_2","start button launches selected game scene")
 game.atmosphere.set_time(12.0)
 await shot("03_探索HUD")
 game.loot.open_bag();await shot("04_背包")
 check(game.loot.modal.visible,"existing inventory opens")
 game.loot.close()
 game._settings(true);await shot("05_设置")
 check(game.settings_panel.visible,"existing settings opens")
 var view=game.settings_view
 check(not view.tab_buttons.display.get_global_rect().intersection(view.display_cards[0].get_global_rect()).has_area(),"settings tabs do not overlap first card")
 await click(view.tab_buttons.audio)
 check(view.settings_tab=="audio" and view.volume_slider.visible,"pointer switches audio tab")
 await shot("11_声音设置")
 await click(view.tab_buttons.display)
 check(view.settings_tab=="display","pointer returns to display tab")
 game._settings(false)
 var d=game.dialogue_controller
 d.state={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]}
 d.context={"room":str(game.title.text),"place":game.location_id,"object":"这里"};d.start("welcome")
 await click(d.box)
 check(not d.is_typing(),"pointer reveals dialogue")
 await shot("06_对话框")
 d.advance();d.advance()
 check(d.current_node=="ask" and d.choice_panel.visible and d.choice_buttons.size()==3,"existing dialogue choices appear")
 await shot("07_回复选项")
 if d.choice_buttons.is_empty():quit(1);return
 var expected: String=str(d.current.choices[0].next)
 await click(d.choice_buttons[0])
 check(d.current_node==expected,"pointer chooses existing dialogue branch")
 await click(d.auto_button)
 check(d.auto_play,"pointer toggles automatic dialogue")
 await click(d.auto_button)
 check(not d.auto_play,"automatic dialogue can be turned off")
 d.advance();d.show_backlog();await shot("08_对话回看");d.hide_backlog()
 root.size=Vector2i(1280,720);await settle(16)
 check(d.box.get_global_rect().end.x<=d.root.size.x+1.0,"dialogue panel fits widescreen")
 check(d.auto_button.get_global_rect().end.x<=d.box.get_global_rect().end.x,"dialogue controls stay inside panel")
 await shot("09_宽屏对话")
 var end_button: Button=null
 for button in d.root.find_children("*","Button",true,false):
  if button.text=="结束对话":end_button=button;break
 check(end_button!=null,"dialogue close button remains")
 if end_button:await click(end_button)
 check(not d.active and not game.dialog_open and game.ui.visible,"pointer close restores game control")
 root.size=Vector2i(1000,750);await settle(12)
 game.pause_menu.open();await shot("10_暂停菜单")
 check(game.pause_menu.active,"pause menu uses shared skin")
 game.pause_menu.close()
 print("SKY_UI_REVIEW: ",checks," checks, ",failures," failures")
 game.queue_free();await settle(5)
 quit(0 if failures==0 else 1)
