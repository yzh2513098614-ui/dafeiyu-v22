extends Control
## Title preferences share the approved sticker skin and the real HarborPrefs data.
const UiStyle=preload("res://ui/harbor_inventory_skin.gd")
var menu
var day_speed:OptionButton
var dusk_hint:Label

func configure(title_menu)->void:
 menu=title_menu;name="TitleSettings";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE;theme=UiStyle.theme()
 menu.content.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 var shell:=UiStyle.panel(self,Vector2.ZERO,size,"shell");shell.name="SettingsShell";shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 UiStyle.label(self,"PREFERENCES  /  鲸落港",Vector2(30,23),Vector2(420,21),12,UiStyle.MUTED)
 UiStyle.label(self,"画面设置",Vector2(28,52),Vector2(448,43),32)
 var music_button:=UiStyle.button(self,"音乐设置  ›",Vector2(542,35),Vector2(168,43),func():menu._show_page("music"));music_button.name="MusicSettings"
 var banner:=UiStyle.panel(self,Vector2(28,113),Vector2(683,68),"card");banner.name="SettingsIntro"
 UiStyle.surface(banner,Color("eaf7fa"),Color("f5edfc"),3,11)
 UiStyle.label(banner,"把画面调成喜欢的样子",Vector2(18,10),Vector2(570,30),23)
 UiStyle.label(banner,"光影、镜头与一天的节奏，都由你决定。",Vector2(19,42),Vector2(610,20),13,UiStyle.MUTED)
 UiStyle.icon(banner,"gal-config",Vector2(616,17),Vector2(32,32)).modulate.a=.35
 _section("01","画面与光影",207,UiStyle.MINT)
 _section("02","镜头与时间",421,Color("a592d5"))
 var options:Array=[
  ["fullscreen","全屏显示","专心漫步鲸落港",Color("eaf3ff")],
  ["shadows","柔和阴影","保留建筑与家具层次",Color("e8f7f8")],
  ["effects","氛围微光","让房间有细微的变化",Color("f1edfc")],
  ["dusk","固定暮色","关闭昼夜循环后生效",Color("fff0f6")],
  ["follow","跟随人物","开场镜头靠近出发点",Color("e8f7f8")],
  ["smooth_camera","柔顺镜头","行走时平缓地跟随",Color("f1edfc")],
  ["day_cycle","昼夜循环","清晨到深夜逐渐变化",Color("fff5e3")]]
 for i in options.size():
  var option:Array=options[i];var id:String=option[0]
  var y:float=240+(i/2)*94 if i<4 else 454+((i-4)/2)*94
  var card:=_card("SettingCard_"+id,Vector2(28+(i%2)*350,y),option[3])
  UiStyle.label(card,option[1],Vector2(16,12),Vector2(203,31),21)
  var hint:=UiStyle.label(card,option[2],Vector2(17,51),Vector2(294,22),14,UiStyle.MUTED)
  if id=="dusk":dusk_hint=hint
  var button:=UiStyle.button(card,"",Vector2(234,13),Vector2(81,32),func():_toggle(id));button.name="Setting_"+id;button.add_theme_font_size_override("font_size",14)
  menu.setting_cards[id]=button
 var time_card:=_card("DayLength",Vector2(378,548),Color("fff5e3"))
 UiStyle.label(time_card,"一天的长度",Vector2(16,9),Vector2(290,30),21)
 day_speed=OptionButton.new();day_speed.name="DayLengthPicker";day_speed.position=Vector2(17,45);day_speed.size=Vector2(297,29);day_speed.add_theme_font_size_override("font_size",14);time_card.add_child(day_speed)
 for duration in [6,12,24]:day_speed.add_item("一天 = 现实 %d 分钟"%duration)
 day_speed.item_selected.connect(func(index:int):
  var pref=menu.prefs();pref.day_minutes=[6.0,12.0,24.0][index]
  menu.feedback.text="一天的长度已保存。" if pref.save()==OK else "设置保存失败，请重试。")
 var rule:=ColorRect.new();rule.position=Vector2(30,661);rule.size=Vector2(679,1);rule.color=Color("c7d8ef");rule.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(rule)
 UiStyle.icon(self,"check",Vector2(31,686),Vector2(20,20)).self_modulate=UiStyle.MINT
 menu.feedback=UiStyle.label(self,"设置会自动保存，下次打开依然生效。",Vector2(61,682),Vector2(435,45),14,UiStyle.MUTED)
 menu.tabs["back"]=UiStyle.button(self,"‹  返回标题",Vector2(521,683),Vector2(189,45),func():menu._show_page("title"),true);menu.tabs.back.name="BackToTitle"
 UiStyle.label(self,"潮汐手记  /  DISPLAY",Vector2(31,740),Vector2(430,18),10,UiStyle.MUTED)
 UiStyle.label(self,"MiSans · Xiaomi",Vector2(560,740),Vector2(150,18),10,UiStyle.MUTED)
 refresh()

func _section(number:String,title:String,y:float,accent:Color)->void:
 var tag:=UiStyle.label(self,number,Vector2(30,y),Vector2(26,23),12,accent)
 tag.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 UiStyle.label(self,title,Vector2(66,y-2),Vector2(592,29),18)

func _card(id:String,pos:Vector2,wash:Color)->Panel:
 var card:=UiStyle.panel(self,pos,Vector2(333,82),"card");card.name=id
 UiStyle.surface(card,Color("fcfdff"),wash,3,11);return card

func refresh()->void:
 var pref=menu.prefs()
 for id in menu.setting_cards:
  var button:Button=menu.setting_cards[id];var on:bool=pref.values[id]
  button.text="开启 ✓" if on else "关闭";UiStyle.card_button(button,on)
 day_speed.select([6.0,12.0,24.0].find(pref.day_minutes) if pref.day_minutes in [6.0,12.0,24.0] else 1)
 day_speed.disabled=not pref.values.day_cycle
 day_speed.tooltip_text="开启昼夜循环后可调整一天长度" if day_speed.disabled else "设置清晨到深夜的流逝速度"
 dusk_hint.text="昼夜循环开启时不生效" if pref.values.day_cycle else "保持温柔的黄昏光线"

func _toggle(id:String)->void:
 var pref=menu.prefs();pref.values[id]=not pref.values[id];pref.apply_window()
 menu.feedback.text="已经记住你的设置。" if pref.save()==OK else "设置保存失败，请重试。"
 refresh()
