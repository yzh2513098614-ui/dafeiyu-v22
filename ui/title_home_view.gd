extends RefCounted
## Native sticker controls; the title controller retains navigation and save actions.
const UiStyle=preload("res://ui/harbor_inventory_skin.gd")
const ICONS="res://assets/ui/candy_title/icons/"

static func build(menu)->void:
 var host:Panel=menu.content;host.theme=UiStyle.theme()
 var plate:=UiStyle.panel(host,Vector2(58,438),Vector2(690,454),"shell");plate.name="TitleMenuPlate"
 var outer:=UiStyle.frame("shell").duplicate();outer.bg_color=Color("edf4fff2");outer.shadow_offset=Vector2(0,9);outer.shadow_color=Color("638effc9");plate.add_theme_stylebox_override("panel",outer)
 var wash:ColorRect=plate.get_child(0);wash.material.set_shader_parameter("start_color",Color("fcfdfff2"));wash.material.set_shader_parameter("end_color",Color("e8effff2"))
 UiStyle.label(host,"鲸落港  /  开始今天的故事",Vector2(84,457),Vector2(520,22),14,UiStyle.MUTED)
 for i in 3:
  var dot:=UiStyle.panel(host,Vector2(670+i*15,464),Vector2(6,6),"card")
  var mark:=StyleBoxFlat.new();mark.bg_color=[UiStyle.MINT,UiStyle.PINK,Color("ac98d5")][i];mark.set_corner_radius_all(3);dot.add_theme_stylebox_override("panel",mark)
 var definitions:Array=[
  ["journey","开始游戏","play",Vector2(82,494),Vector2(314,78),Color("e4f6fc"),func():menu._show_page("journey")],
  ["resume","继续游戏","folder",Vector2(410,494),Vector2(314,78),Color("fff4dc"),func():menu._start(true)],
  ["load","读取存档","book",Vector2(82,618),Vector2(314,64),Color("eaf3ff"),func():menu._show_page("load")],
  ["save","保存游戏","save",Vector2(410,618),Vector2(314,64),Color("eaf3ff"),func():menu._show_page("save")],
  ["settings","设置","settings",Vector2(82,694),Vector2(314,64),Color("eaf7f8"),func():menu._show_page("settings")],
  ["memories","回想","chat",Vector2(410,694),Vector2(314,64),Color("fff0f6"),func():menu._show_page("memories")],
  ["cg","CG 鉴赏","image",Vector2(82,770),Vector2(314,64),Color("f2edff"),func():menu._show_page("cg")],
  ["quit","退出游戏","exit",Vector2(410,770),Vector2(314,64),Color("f2edff"),func():menu.get_tree().quit()]]
 for entry in definitions:
  var id:String=entry[0];var button:=_button(host,entry[1],entry[2],entry[3],entry[4],entry[5],entry[6],id in ["journey","resume"]);button.name="Menu_"+id;menu.menu_buttons[id]=button
 menu.resume_button=menu.menu_buttons.resume;menu.resume_button.disabled=menu._saved_journey().is_empty() or not menu.recovery_ok
 menu.resume_button.tooltip_text="还没有旅程记录，请先开始游戏。" if menu.resume_button.disabled else "继续上次已保存的旅程。"
 # A disabled resume keeps a neutral face; the native button still blocks activation.
 var resume_wash:ColorRect=menu.resume_button.get_node("StickerSurface");resume_wash.visible=not menu.resume_button.disabled
 UiStyle.label(host,"选择出发地，开启一段日常",Vector2(88,581),Vector2(302,22),13,UiStyle.MUTED)
 var resume_hint:="尚无旅程记录" if menu.resume_button.disabled else "接着上次的日常继续"
 UiStyle.label(host,resume_hint,Vector2(417,581),Vector2(301,22),13,UiStyle.MUTED)
 UiStyle.label(host,"Tab / 方向键切换  ·  Enter 确认",Vector2(85,854),Vector2(609,22),13,UiStyle.MUTED)
 var focus_order:Array=[]
 for id in menu.menu_buttons:
  var button:Button=menu.menu_buttons[id]
  if not button.disabled:focus_order.append(button)
 for i in focus_order.size():
  var button:Button=focus_order[i]
  button.focus_next=button.get_path_to(focus_order[(i+1)%focus_order.size()]);button.focus_previous=button.get_path_to(focus_order[posmod(i-1,focus_order.size())])
 if menu.page_status!="":
  UiStyle.label(host,menu.page_status,Vector2(85,899),Vector2(630,33),14,UiStyle.MUTED)

static func _button(parent:Node,text:String,key:String,pos:Vector2,dimensions:Vector2,wash:Color,action:Callable,primary:bool=false)->Button:
 var button:=UiStyle.button(parent,text,pos,dimensions,action,primary)
 button.icon=load(ICONS+key+".svg");button.expand_icon=true;button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
 button.add_theme_constant_override("icon_max_width",46 if primary else 35);button.add_theme_constant_override("h_separation",18)
 button.add_theme_font_size_override("font_size",27 if primary else 24)
 for state in ["normal","hover","pressed","disabled"]:
  var box:=button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
  box.content_margin_left=18;box.content_margin_right=22;box.set_corner_radius_all(18 if primary else 15)
  if state!="disabled":box.bg_color.a=0.0 if state=="normal" else .4
  if state in ["hover","pressed"]:box.border_color=UiStyle.BLUE
  box.shadow_offset.y=2 if state=="pressed" else 5 if primary else 3
  button.add_theme_stylebox_override(state,box)
 var focus:=UiStyle.frame("focus").duplicate();focus.set_corner_radius_all(18 if primary else 15);button.add_theme_stylebox_override("focus",focus)
 var tint:=UiStyle.surface(button,Color("fcfdff"),wash,3,15 if primary else 12);tint.show_behind_parent=true
 button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;return button

static func build_dialogue(menu)->void:
 menu.greeting=UiStyle.panel(menu.design_root,Vector2(788,778),Vector2(832,134),"panel");menu.greeting.name="TitleDialogue"
 var frame:=UiStyle.frame("panel").duplicate();frame.set_border_width_all(5);frame.set_corner_radius_all(27);frame.shadow_offset=Vector2(0,8);menu.greeting.add_theme_stylebox_override("panel",frame)
 var wash:ColorRect=menu.greeting.get_child(0);wash.material.set_shader_parameter("start_color",Color("fff8fc"));wash.material.set_shader_parameter("end_color",Color("eeebfc"));wash.position=Vector2(6,6);wash.size=menu.greeting.size-Vector2(12,12)
 var nameplate:=UiStyle.panel(menu.greeting,Vector2(28,-13),Vector2(140,33),"card");nameplate.name="SpeakerTag"
 var name_style:=UiStyle.frame("card").duplicate();name_style.bg_color=Color("fff0f7");name_style.border_color=UiStyle.PINK;name_style.set_border_width_all(1);name_style.shadow_size=0;name_style.shadow_offset=Vector2.ZERO;nameplate.add_theme_stylebox_override("panel",name_style)
 var speaker:=UiStyle.label(nameplate,"大肥鱼",Vector2(9,3),Vector2(122,26),18,Color("946580"));speaker.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 UiStyle.label(menu.greeting,"海风来信",Vector2(29,30),Vector2(300,20),12,Color("ae839f"))
 menu.intro_label=UiStyle.label(menu.greeting,menu.INTRO[0],Vector2(28,64),Vector2(730,42),25);menu.intro_label.visible_characters=0
 menu.auto_button=_reading_button(menu,"AUTO",Vector2(536,22),Vector2(82,28),func():menu.auto_intro=not menu.auto_intro;menu.auto_button.text="AUTO ✓" if menu.auto_intro else "AUTO")
 menu.auto_button.name="TitleAuto"
 _reading_button(menu,"SKIP",Vector2(625,22),Vector2(64,28),func():menu.intro_index=menu.INTRO.size()-1;menu.intro_elapsed=0;menu.intro_label.text=menu.INTRO[menu.intro_index];menu.intro_label.visible_characters=-1).name="TitleSkip"
 _reading_button(menu,"LOG",Vector2(696,22),Vector2(58,28),func():menu._show_page("memories")).name="TitleLog"
 _reading_button(menu,"›",Vector2(766,70),Vector2(38,32),func():menu._next_intro()).name="TitleNext"

static func _reading_button(menu,text:String,pos:Vector2,dimensions:Vector2,action:Callable)->Button:
 var button:=UiStyle.button(menu.greeting,text,pos,dimensions,action);button.add_theme_font_size_override("font_size",13 if text!="›" else 25)
 button.add_theme_stylebox_override("normal",StyleBoxEmpty.new());button.modulate.a=.78;return button

static func build_tools(menu)->void:
 var help:=_button(menu.design_root,"操作说明","settings",Vector2(1270,23),Vector2(174,46),Color("eaf7f8"),func():menu._show_page("help"));help.name="TitleHelp";help.add_theme_font_size_override("font_size",18);help.add_theme_constant_override("icon_max_width",23)
 var website:=_button(menu.design_root,"官方网站","help",Vector2(1456,23),Vector2(174,46),Color("f2edff"),func():menu._show_page("website"));website.name="TitleWebsite";website.add_theme_font_size_override("font_size",18);website.add_theme_constant_override("icon_max_width",23)
