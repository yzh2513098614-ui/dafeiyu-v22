extends SceneTree
## Real rendered review; required flags isolate settings, inventory and dialogue.
const OUTPUT := "res://预览/样例掌机UI接入_20261011/"
var checks := 0
var failures := 0
var menu
var prefs

func _initialize() -> void:
 # Match Godot MCP background mode so desktop input cannot disturb the replay.
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
  DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(value: bool,message: String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
 else:print("PASS: ",message)

func settle(count: int=8) -> void:
 for i in count:await process_frame

func shot(filename: String) -> void:
 await settle(10);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename+".png"))==OK,"screenshot "+filename)

func click(button: Control) -> void:
 await settle(8)
 var point:=button.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
 root.push_input(motion,true);await process_frame
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 var released: InputEventMouseButton=event.duplicate();released.pressed=false;root.push_input(released,true)
 await settle(8)

func key(code: Key) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle(3)

func bounds() -> void:
 var rect: Rect2=menu.content.get_global_rect()
 for id in menu.menu_buttons:
  var button: Button=menu.menu_buttons[id]
  check(rect.encloses(button.get_global_rect()),"title button contained "+id)
  check(not button.get_global_rect().intersection(menu.portrait.get_global_rect()).has_area(),"portrait clears button "+id)
 var buttons: Array=menu.menu_buttons.values()
 var overlaps:=false
 for i in buttons.size():
  for j in range(i+1,buttons.size()):
   if buttons[i].get_global_rect().intersection(buttons[j].get_global_rect()).has_area():overlaps=true
 check(not overlaps,"title buttons do not overlap")
 check(menu.portrait.get_global_rect().end.x<=menu.size.x+1.0,"portrait within right edge")
 check(menu.device_shell.get_global_rect().encloses(rect),"menu screen within device shell")
 check(menu.portrait_frame.get_global_rect().encloses(menu.greeting.get_global_rect()),"greeting within portrait screen")

func run() -> void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():
  push_error("Required isolation flags: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 prefs=root.get_node("HarborPrefs");prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false
 prefs.settings_path=OUTPUT+"isolated_settings.cfg";prefs.world_save_path=OUTPUT+"isolated_world.json"
 prefs.starting_place="city";prefs.continue_game=false
 if FileAccess.file_exists(prefs.world_save_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.world_save_path))
 root.size=Vector2i(1000,750)
 if "--menu-baseline" in OS.get_cmdline_user_args():
  menu=Control.new();menu.set_script(load("res://备份/20261011_粉蓝双列标题菜单前/ui/harbor_start.gd"));root.add_child(menu);menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);current_scene=menu
  await shot("00_改版前");quit(0 if failures==0 else 1);return
 menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 await shot("01_标题_4比3")
 check(menu.menu_buttons.size()==8,"eight existing entries remain")
 check(menu.get_node("OceanBackdrop").get_script().resource_path=="res://ui/ocean_menu_backdrop.gd","sample backdrop integrated")
 check(menu.device_shell.get_theme_stylebox("panel").corner_radius_top_left==68,"sample shell radius")
 check(menu.content.get_theme_stylebox("panel").bg_color==Color("7adcc4"),"sample mint screen rim")
 check(menu.portrait_frame.get_theme_stylebox("panel").bg_color==Color("f48bb7"),"sample pink portrait frame")
 for id in menu.menu_buttons:
  var button: Button=menu.menu_buttons[id]
  var white: bool=button.get_meta("white_button",false)
  var expected:=Color("f9fcff") if white else (Color("689bd0") if id=="journey" else Color("91b9df"))
  check(button.get_theme_stylebox("normal").bg_color==expected,"blue-white button "+id)
  check(button.get_script().resource_path=="res://ui/ocean_menu_button.gd","sample highlight "+id)
  check(button.get_theme_stylebox("hover").bg_color!=button.get_theme_stylebox("normal").bg_color,"visible hover "+id)
 check(menu.resume_button.disabled,"no save disables continue")
 check(menu.portrait.texture.resource_path=="res://assets/start/portraits/whale_wave_pixel.png","new pixel portrait integrated")
 check(menu.portrait.texture.get_image().get_pixel(0,0).a==0.0,"portrait corner transparent")
 bounds()
 await click(menu.menu_buttons.journey);check(menu.page=="journey","mouse opens departure")
 check(menu.cards.size()==8,"all eight harbor destinations remain")
 await click(menu.cards.apt_2);check(prefs.starting_place=="apt_2","mouse chooses apartment")
 for card in menu.cards.values():check(menu.content.get_global_rect().encloses(card.get_global_rect()),"departure card within screen")
 await shot("03_出发选择")
 await key(KEY_ESCAPE);check(menu.page=="title","Escape returns to title")
 menu.menu_buttons.settings.grab_focus();await key(KEY_ENTER);check(menu.page=="settings","Enter opens focused settings")
 var shadows: bool=prefs.values.shadows
 await click(menu.setting_cards.shadows);check(prefs.values.shadows!=shadows,"mouse toggles existing display preference")
 for card in menu.setting_cards.values():check(menu.content.get_global_rect().encloses(card.get_global_rect()),"settings card within screen")
 await shot("04_画面设置")
 await key(KEY_ESCAPE);await click(menu.menu_buttons.harbor)
 check(menu.page=="harbor" and menu.cards.size()==13,"warehouse retains thirteen destinations")
 await click(menu.cards.depot);check(prefs.starting_place=="depot","warehouse destination selected: "+prefs.starting_place)
 await shot("05_东港仓储")
 await key(KEY_ESCAPE);await click(menu.menu_buttons.pack26)
 check(menu.page=="pack26" and menu.cards.size()==26,"all twenty-six maps remain: "+menu.page+" / "+str(menu.cards.size()))
 await shot("06_立体新区")
 await key(KEY_ESCAPE);await click(menu.menu_buttons.music)
 check(menu.page=="music" and menu.music().in_gallery(),"music gallery opens")
 check(menu.gallery_rows.size()>0,"music tracks remain")
 await click(menu.gallery_rows[0].card)
 check(menu.music().gallery_track()==menu.gallery_rows[0].id,"mouse plays chosen gallery track")
 var playing:=0
 for entry in menu.gallery_rows:
  if entry.now.visible:playing+=1
 check(playing==1,"one current-track marker")
 check(menu.gallery_rows[0].card.get_theme_stylebox("hover").bg_color==Color("53566f"),"playing row retains readable blue hover state")
 await shot("07_音乐鉴赏")
 await key(KEY_ESCAPE);check(not menu.music().in_gallery(),"leaving music restores title mode")
 var save:=FileAccess.open(prefs.world_save_path,FileAccess.WRITE)
 save.store_string(JSON.stringify({"version":6,"location":"apt_2","position":[1,1]}));save.close()
 menu._render();await settle();check(not menu.resume_button.disabled,"valid existing save enables continue")
 menu.menu_buttons.journey.grab_focus();await key(KEY_TAB)
 check(root.gui_get_focus_owner()==menu.menu_buttons.music,"Tab follows first menu row")
 await shot("08_继续可用与键盘焦点")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.world_save_path));menu._render()
 root.size=Vector2i(1280,720);await settle(16);bounds();await shot("02_标题_16比9")
 root.size=Vector2i(800,600);await settle(16);bounds();await shot("09_标题_小窗口")
 root.size=Vector2i(1000,750);await settle(12)
 await click(menu.menu_buttons.journey);await click(menu.cards.apt_2);await click(menu.start_button);await settle(30)
 var game=current_scene
 check(game!=null and game.get("location_id")=="apt_2","start launches selected apartment in real world")
 print("OCEAN_MENU_REVIEW: ",checks," checks, ",failures," failures")
 var report:=FileAccess.open(OUTPUT+"review_result.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));report.close()
 quit(0 if failures==0 else 1)
