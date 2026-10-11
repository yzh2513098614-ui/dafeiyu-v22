extends SceneTree
## Rendered mouse/keyboard regression. All snapshots and preferences use isolated paths.
const OUTPUT="res://预览/糖果贴纸开始界面_20261012/"
var checks:=0
var failures:=0
var menu
var prefs

func _initialize()->void:
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
  DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(value:bool,message:String)->void:
 checks+=1
 if value:print("PASS: ",message)
 else:failures+=1;push_error(message)

func settle(count:int=8)->void:
 for i in count:await process_frame

func shot(filename:String)->void:
 await settle(10);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename+".png"))==OK,"screenshot "+filename)

func click(button:Control)->void:
 await settle()
 var point:=button.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true)
 await process_frame
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()

func key(code:Key)->void:
 var event:=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true);await process_frame
 event=event.duplicate();event.pressed=false;root.push_input(event,true);await settle()

func named_button(parent:Node,text:String)->Button:
 for child in parent.get_children():
  if child is Button and child.text==text:return child
 return null

func write(path:String,data:Variant)->void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()

func bounds()->void:
 var canvas:Rect2=menu.design_root.get_global_rect()
 var controls:Array=menu.menu_buttons.values()+[menu.greeting,menu.design_root.get_node("TitleHelp"),menu.design_root.get_node("TitleWebsite")]
 for control in controls:check(canvas.encloses(control.get_global_rect()),"title control within canvas: "+str(control.name))
 var overlapping:=false
 var clickable:Array=menu.menu_buttons.values()+[menu.design_root.get_node("TitleHelp"),menu.design_root.get_node("TitleWebsite")]
 for i in clickable.size():
  for j in range(i+1,clickable.size()):
   if clickable[i].get_global_rect().intersection(clickable[j].get_global_rect()).has_area():overlapping=true
 check(not overlapping,"title interactive controls do not overlap")
 check(menu.greeting.mouse_filter==Control.MOUSE_FILTER_IGNORE,"decorative dialogue border never intercepts menu clicks")
 check(menu.design_root.scale.x==menu.design_root.scale.y,"reference retains uniform aspect ratio")

func page_bounds(items:Array)->void:
 for item in items:check(menu.content.get_global_rect().encloses(item.get_global_rect()),"page control contained: "+str(item.name))

func title()->void:
 if menu.page!="title":await key(KEY_ESCAPE)
 check(menu.page=="title","Escape returns to title")

func run()->void:
 for flag in ["--test-candy-title","--test-session-ui","--test-dialogue"]:
  if not flag in OS.get_cmdline_user_args():push_error("Required isolation flag: "+flag);quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 prefs=root.get_node("HarborPrefs");prefs.settings_path=OUTPUT+"isolated_settings.cfg";prefs.world_save_path=OUTPUT+"active_world.json"
 prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.starting_place="city";prefs.continue_game=false
 if FileAccess.file_exists(prefs.world_save_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.world_save_path))
 root.size=Vector2i(1280,720);root.gui_embed_subwindows=true
 menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 await settle(20)
 for path in menu.slot_service.paths.values():
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 for index in range(1,7):
  var path:String=menu.slot_service._slot_path(index)
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 menu._render();await settle()
 var expected:Dictionary={"journey":"开始游戏","resume":"继续游戏","load":"读取存档","save":"保存游戏","settings":"设置","memories":"回想","cg":"CG 鉴赏","quit":"退出游戏"}
 check(menu.menu_buttons.size()==8,"eight reference entries")
 for id in expected:
  check(menu.menu_buttons[id].text==expected[id] and menu.menu_buttons[id].live_label.text==expected[id],"reference text remains readable: "+str(id))
  check(menu.menu_buttons[id].pressed.get_connections().size()>=1,"button action connected: "+str(id))
 check(menu.resume_button.disabled,"empty progress disables continue")
 check(menu.logo.texture.get_image().get_pixel(0,0).a==0.0,"logo has real transparent outside corner")
 menu.intro_label.visible_characters=-1
 bounds();await shot("01_标题_16比9")
 var point:Vector2=menu.menu_buttons.journey.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;root.push_input(motion,true);await settle()
 check(menu.menu_buttons.journey.is_hovered(),"real pointer hovers start sticker");await shot("16_按钮悬停")
 var held:=InputEventMouseButton.new();held.button_index=MOUSE_BUTTON_LEFT;held.position=point;held.global_position=point;held.pressed=true;root.push_input(held,true);await settle()
 check(menu.menu_buttons.journey.is_pressed(),"real held pointer presses start sticker");await shot("17_按钮按下")
 motion.position=Vector2.ZERO;motion.global_position=Vector2.ZERO;root.push_input(motion,true)
 held.position=Vector2.ZERO;held.global_position=Vector2.ZERO;held.pressed=false;root.push_input(held,true);await settle()
 check(menu.page=="title","releasing outside cancels menu action")
 menu.menu_buttons.journey.grab_focus();await key(KEY_TAB)
 check(root.gui_get_focus_owner()==menu.menu_buttons.load,"Tab skips disabled continue in reference row order")
 await shot("02_键盘焦点")
 await click(menu.menu_buttons.journey);check(menu.page=="journey" and menu.cards.size()==8,"mouse opens eight original starting places")
 check(named_button(menu.content,"研究远征")!=null,"research expedition still accessible")
 await click(menu.cards.apt_2);check(prefs.starting_place=="apt_2","mouse selects apartment")
 page_bounds(menu.cards.values()+[menu.start_button]);await shot("03_开始游戏")
 await click(named_button(menu.content,"东港仓储"));check(menu.page=="harbor" and menu.cards.size()==13,"thirteen warehouse locations retained")
 await click(menu.cards.depot);check(prefs.starting_place=="depot","warehouse selection works")
 page_bounds(menu.cards.values()+[menu.start_button]);await shot("04_东港仓储")
 await title();await click(menu.menu_buttons.journey);await click(named_button(menu.content,"26 地图"))
 check(menu.page=="pack26" and menu.cards.size()==26,"twenty-six maps retained")
 page_bounds(menu.cards.values()+[menu.start_button]);await shot("05_26地图")
 await title();menu.menu_buttons.settings.grab_focus();await key(KEY_ENTER)
 check(menu.page=="settings","Enter activates focused settings")
 var prior:bool=prefs.values.shadows;await click(menu.setting_cards.shadows)
 check(prefs.values.shadows!=prior and FileAccess.file_exists(prefs.settings_path),"display preference persists to isolated settings")
 page_bounds(menu.setting_cards.values());await shot("06_设置")
 await click(named_button(menu.content,"音乐设置"));check(menu.page=="music" and menu.music().in_gallery(),"music retained through settings")
 await click(menu.gallery_rows[0].card);check(menu.music().gallery_track()==menu.gallery_rows[0].id,"selected music actually plays")
 var highlighted:=0
 for entry in menu.gallery_rows:
  if entry.now.visible:highlighted+=1
 check(highlighted==1,"single playing-track marker")
 await shot("07_音乐设置");await title();check(not menu.music().in_gallery(),"leaving gallery resets music mode")
 await click(menu.menu_buttons.load)
 check(menu.slots_buttons.size()==6,"six real load slots")
 for button in menu.slots_buttons.values():check(button.disabled,"empty load slot disabled")
 await title();await click(menu.menu_buttons.save)
 for button in menu.slots_buttons.values():check(button.disabled,"saving unavailable before real world progress")
 await title();await click(menu.menu_buttons.memories)
 check(menu.memories.is_empty(),"empty recollection shown honestly")
 await title()
 write(menu.slot_service.paths.world,{"version":6,"location":"apt_2","position":[1,1],"rooms":{},"visited":{},"favorites":{}})
 write(menu.slot_service.paths.inventory,{"version":3,"inventory":{"token_cracker":3},"stocks":{},"favorites":{}})
 write(menu.slot_service.paths.dialogue,{"version":1,"seen":{},"flags":{},"bookmark":{},"history":[{"speaker":"大肥鱼","text":"未来，也想和你一起编写…","topic":"鲸落港"},{"speaker":"你","text":"那么，就从今天的海风开始吧。","topic":"鲸落港"}]})
 menu._render();await settle();check(not menu.resume_button.disabled,"valid world progress enables continue")
 await click(menu.menu_buttons.save);await click(menu.slots_buttons[1])
 check(not menu.slot_service.read_slot(1).is_empty(),"mouse saves a snapshot into slot one")
 var saved:String=FileAccess.get_file_as_string(menu.slot_service._slot_path(1))
 await click(menu.slots_buttons[1]);check(menu.confirmation.visible,"occupied slot asks for overwrite")
 await key(KEY_ESCAPE);check(not menu.confirmation.visible,"Escape cancels overwrite")
 check(FileAccess.get_file_as_string(menu.slot_service._slot_path(1))==saved,"cancelled overwrite preserves snapshot")
 await click(menu.slots_buttons[1]);await key(KEY_ENTER)
 check(menu.page_status.contains("已保存") and not menu.confirmation.visible,"confirmed overwrite saves successfully")
 page_bounds(menu.slots_buttons.values());await shot("08_六个存档槽")
 await title();await click(menu.menu_buttons.memories)
 check(menu.memories.size()==2 and menu.memories[0].text=="未来，也想和你一起编写…","recollection reads actual dialogue history")
 await shot("09_回想");await title();await click(menu.menu_buttons.cg)
 var first_texture:String=menu.cg_image.texture.resource_path
 await click(named_button(menu.content,"下一张 ›"))
 check(menu.cg_index==1 and menu.cg_image.texture.resource_path!=first_texture,"CG next shows another real project image")
 check(menu.content.get_global_rect().encloses(menu.cg_image.get_global_rect()),"CG image contained without stretching")
 await shot("10_CG鉴赏");await title()
 await click(menu.design_root.get_node("TitleHelp"));check(menu.page=="help","operation help opens")
 await shot("11_操作说明");await title();await click(menu.design_root.get_node("TitleWebsite"))
 check(menu.page=="website","website entry explains current project status")
 await title();await click(menu.auto_button);check(menu.auto_intro,"AUTO toggles title playback")
 await click(named_button(menu.greeting,"▶▶ SKIP"));check(menu.intro_index==2 and menu.intro_label.visible_characters==-1,"SKIP completes greeting")
 await click(named_button(menu.greeting,"☰ LOG"));check(menu.page=="memories","LOG opens real recollection");await title()
 menu.intro_index=0;menu.intro_label.text=menu.INTRO[0];menu.intro_label.visible_characters=-1;await click(menu.auto_button)
 root.size=Vector2i(1000,750);await settle(20);bounds();await shot("12_标题_4比3")
 root.size=Vector2i(800,600);await settle(20);bounds();await shot("13_标题_小窗口")
 root.size=Vector2i(1280,720);await settle(20)
 if root.gui_get_focus_owner()!=null:root.gui_get_focus_owner().release_focus()
 await shot("14_最终标题")
 write(menu.slot_service.paths.world,{"version":6,"location":"city","position":[2,2]})
 await click(menu.menu_buttons.load);await click(menu.slots_buttons[1]);check(menu.confirmation.visible,"load asks before replacing current progress")
 await key(KEY_ENTER);await settle(50)
 check(current_scene!=menu and current_scene.get("location_id")=="apt_2","confirmed load enters restored apartment in actual game")
 check(JSON.parse_string(FileAccess.get_file_as_string(prefs.world_save_path)).location=="apt_2","loaded world file matches selected slot")
 await shot("15_读取存档进入游戏")
 current_scene.pause_menu.open();await settle();await click(current_scene.pause_menu.buttons.title);await settle(30);menu=current_scene
 check(menu.get_script().resource_path=="res://ui/candy_sticker_start.gd","game pause returns to new title")
 await click(menu.menu_buttons.resume);await settle(40)
 check(current_scene.get("location_id")=="apt_2","continue resumes actual saved apartment")
 current_scene.pause_menu.open();await settle();await click(current_scene.pause_menu.buttons.title);await settle(30);menu=current_scene
 await click(menu.menu_buttons.journey);await click(menu.cards.apt_2);await click(menu.start_button);await settle(40)
 check(current_scene.get("location_id")=="apt_2" and not prefs.continue_game,"start launches selected apartment through original game logic")
 var report:=FileAccess.open(OUTPUT+"review_result.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));report.close()
 print("CANDY_TITLE_REVIEW: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
