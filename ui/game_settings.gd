extends Control
const UiStyle=preload("res://ui/harbor_inventory_skin.gd")
const WorldStyle=preload("res://ui/whale_skin.gd")
var game
var switches: Dictionary={}
var feedback: Label
var day_speed: OptionButton
var settings_tab:="display"
var tab_buttons: Dictionary={}
var display_cards: Array=[]
var audio_cards: Array=[]
var music_switch: Button
var volume_slider: HSlider
var volume_value: Label
var style_picker: OptionButton
var sfx_switch: Button
var sfx_slider: HSlider
var sfx_value: Label
var audition_cards: Array=[]
var audition_rows: Array=[]
var audition_hint: Label
var _syncing_audio:=false
func configure(owner_game) -> void:
 game=owner_game;size=Vector2(980,668);theme=UiStyle.theme();mouse_filter=Control.MOUSE_FILTER_IGNORE
 game.settings_panel.theme=theme;game.settings_panel.set_script(null);game.settings_panel.add_theme_stylebox_override("panel",UiStyle.frame("shell"))
 var background:=UiStyle.surface(game.settings_panel,Color("fcfdff"),Color("edf2ff"),8,24);game.settings_panel.move_child(background,0)
 WorldStyle.mascot(self,Vector2(26,20),Vector2(78,78))
 UiStyle.label(self,"鲸鱼的小设置",Vector2(123,20),Vector2(645,42),31)
 UiStyle.label(self,"把鲸落港调成喜欢的样子。",Vector2(125,66),Vector2(620,27),17,UiStyle.MUTED)
 var tabs:Array=[["display","画面","grid"],["audio","声音","gal-play"],["audition","音效试听","gal-next"]]
 for i in tabs.size():
  var id:String=tabs[i][0]
  var tab:=UiStyle.button(self,tabs[i][1],Vector2(28+i*154,110),Vector2(144,36),func():_set_tab(id));tab.name="SettingsTab_"+id;tab.add_theme_font_size_override("font_size",17);tab_buttons[id]=tab
  var glyph:=UiStyle.icon(tab,tabs[i][2],Vector2(14,10),Vector2(16,16));glyph.modulate.a=.7
 UiStyle.button(self,"Esc 关闭",Vector2(826,27),Vector2(126,44),func():game._settings(false)).name="CloseSettings"
 var rule:=ColorRect.new();rule.position=Vector2(28,155);rule.size=Vector2(924,1);rule.color=Color("c7d8ef");rule.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(rule)
 var options:Array=[["fullscreen","全屏显示","展开整个鲸落港"],["shadows","柔和阴影","保留建筑与家具的层次"],["effects","光影细节","墙角、物件底部与氛围微光"],["dusk","暮色暖光","让窗口亮起暖色的灯"],["follow","跟随人物","镜头靠近正在漫步的你"],["smooth_camera","柔顺镜头","走动时平缓地跟随"],["day_cycle","昼夜循环","清晨、午后、黄昏与夜晚"]]
 var washes:Array[Color]=[Color("eaf3ff"),Color("eaf3ff"),Color("f1edfc"),Color("fff0f6"),Color("e8f7f8"),Color("e8f7f8"),Color("fff5e3")]
 for i in options.size():
  var option:Array=options[i];var id:String=option[0]
  var card:=_card("Display_"+id,Vector2(28+(i%2)*470,170+(i/2)*94),Vector2(454,82),washes[i]);display_cards.append(card)
  var number:=UiStyle.label(card,"%02d"%[i+1],Vector2(14,17),Vector2(30,23),12,UiStyle.BLUE);number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  UiStyle.label(card,option[1],Vector2(56,11),Vector2(266,32),22)
  UiStyle.label(card,option[2],Vector2(56,49),Vector2(378,24),14,UiStyle.MUTED)
  switches[id]=UiStyle.button(card,"",Vector2(338,13),Vector2(96,34),func():_toggle(id));switches[id].name="Setting_"+id;switches[id].add_theme_font_size_override("font_size",16)
 var time_card:=_card("DayLength",Vector2(498,452),Vector2(454,82),Color("fff5e3"));display_cards.append(time_card)
 UiStyle.label(time_card,"08",Vector2(14,17),Vector2(30,23),12,UiStyle.BLUE)
 UiStyle.label(time_card,"一天的长度",Vector2(56,11),Vector2(260,28),22)
 day_speed=OptionButton.new();day_speed.name="DayLengthPicker";day_speed.position=Vector2(56,44);day_speed.size=Vector2(378,29);day_speed.add_theme_font_size_override("font_size",15);time_card.add_child(day_speed)
 for duration in [6,12,24]:day_speed.add_item("现实 %d 分钟"%duration)
 day_speed.item_selected.connect(func(index:int):HarborPrefs.day_minutes=[6.0,12.0,24.0][index];HarborPrefs.save();HarborPrefs.apply_game(game,true))
 _build_audio_cards();_build_audition_cards()
 UiStyle.icon(self,"check",Vector2(29,578),Vector2(19,19)).self_modulate=UiStyle.MINT
 feedback=UiStyle.label(self,"设置会自动保存，下次打开依然生效。",Vector2(59,574),Vector2(670,32),15,UiStyle.MUTED)
 UiStyle.label(self,"潮汐手记  /  PREFERENCES",Vector2(30,625),Vector2(620,19),11,UiStyle.MUTED)
 UiStyle.button(self,"完成设置   ↗",Vector2(740,609),Vector2(212,42),func():game._settings(false),true).name="DoneSettings"
 # Keep existing diagnostics attached to the same callbacks.
 game.settings_front_button=Button.new();game.settings_front_button.pressed.connect(func():game._set_actor_front(not game.actor_front));add_child(game.settings_front_button);game.settings_front_button.hide()
 game.settings_foot_button=Button.new();game.settings_foot_button.pressed.connect(func():game.foot_debug.visible=not game.foot_debug.visible);add_child(game.settings_foot_button);game.settings_foot_button.hide()
 game.settings_fx_button=switches.effects;game.settings_light_button=switches.dusk
 refresh()

func _card(id:String,pos:Vector2,dimensions:Vector2,wash:Color)->Panel:
 var card:=UiStyle.panel(self,pos,dimensions,"card");card.name=id
 UiStyle.surface(card,Color("fcfdff"),wash,3,11);return card

func refresh() -> void:
 for id in switches:
  var on: bool=HarborPrefs.values[id];var button: Button=switches[id]
  button.text="开启 ✓" if on else "关闭"
  UiStyle.card_button(button,on)
 if day_speed:day_speed.select([6.0,12.0,24.0].find(HarborPrefs.day_minutes) if HarborPrefs.day_minutes in [6.0,12.0,24.0] else 1);day_speed.disabled=not HarborPrefs.values.day_cycle
 if is_instance_valid(music_switch):
  var music_on: bool=MusicDirector.music_enabled()
  music_switch.text="开启 ✓" if music_on else "关闭"
  UiStyle.card_button(music_switch,music_on)
 if is_instance_valid(volume_slider):
  _syncing_audio=true
  volume_slider.value=roundi(MusicDirector.music_volume()*100.0)
  volume_slider.editable=MusicDirector.music_enabled()
  _syncing_audio=false
 if is_instance_valid(volume_value):
  volume_value.text=str(roundi(MusicDirector.music_volume()*100.0))+"%"
  volume_value.add_theme_color_override("font_color",UiStyle.INK if MusicDirector.music_enabled() else UiStyle.MUTED)
 if is_instance_valid(sfx_switch):
  var sfx_on: bool=SfxDirector.enabled()
  sfx_switch.text="开启 ✓" if sfx_on else "关闭"
  UiStyle.card_button(sfx_switch,sfx_on)
 if is_instance_valid(sfx_slider):
  _syncing_audio=true
  sfx_slider.value=roundi(SfxDirector.volume()*100.0)
  sfx_slider.editable=SfxDirector.enabled()
  _syncing_audio=false
 if is_instance_valid(sfx_value):
  sfx_value.text=str(roundi(SfxDirector.volume()*100.0))+"%"
  sfx_value.add_theme_color_override("font_color",UiStyle.INK if SfxDirector.enabled() else UiStyle.MUTED)
 if is_instance_valid(style_picker):
  var keys: Array=MusicDirector.style_keys()
  style_picker.select(maxi(0,keys.find(MusicDirector.style_key())))
 _refresh_tab()
func _toggle(id: String) -> void:
 var old: bool=HarborPrefs.values[id]
 HarborPrefs.values[id]=not old
 if id=="dusk":HarborPrefs.values.day_cycle=false
 if HarborPrefs.save()!=OK:
  HarborPrefs.values[id]=old;feedback.text="设置尚未保存，请重试。";refresh();return
 HarborPrefs.apply_window()
 if id=="shadows":game.get_node("Sun").shadow_enabled=HarborPrefs.values.shadows
 elif id=="effects":game.atmosphere.set_effects(HarborPrefs.values.effects)
 elif id in ["dusk","day_cycle"]:HarborPrefs.apply_game(game,true)
 elif id=="follow" and game.has_method("_toggle_view"):
  if game.overview_mode==HarborPrefs.values.follow:game._toggle_view()
 refresh();feedback.text="已经记住你的设置。"

func _set_tab(id: String) -> void:
 settings_tab=id
 _refresh_tab()

func _refresh_tab() -> void:
 for id in tab_buttons:
  var button: Button=tab_buttons[id]
  if is_instance_valid(button):
   UiStyle.card_button(button,id==settings_tab)
   for state in ["normal","hover","pressed"]:
    var compact:=button.get_theme_stylebox(state).duplicate()
    compact.content_margin_top=3;compact.content_margin_bottom=3
    button.add_theme_stylebox_override(state,compact)
   button.size.y=36
 for card in display_cards:
  if is_instance_valid(card):card.visible=settings_tab=="display"
 for card in audio_cards:
  if is_instance_valid(card):card.visible=settings_tab=="audio"
 for card in audition_cards:
  if is_instance_valid(card):card.visible=settings_tab=="audition"
 if settings_tab!="audition":SfxDirector.stop_audition()

## 「音效试听」页：按分类列出全部音效，点一行听一个。
##
## 这个页面存在的理由很实际：23 个音效散在游戏各处，触发它们要靠碰运气 ——
## 要翻页才听到打字机、要打完一场才听到连携、要升级才听到升级音。
## 没有试听页，想把整套音效听一遍判断「音色对不对、配比合不合理」几乎不可能。
##
## 试听走的是真实的分类音量偏移（见 SfxDirector.CATALOG），
## 所以听到的就是游戏里的实际配比，不是把所有音效拉到同一响度。
func _build_audition_cards() -> void:
 var board:=_card("SoundAudition",Vector2(28,170),Vector2(924,384),Color("f1edfc"));audition_cards.append(board)
 UiStyle.label(board,"音效试听",Vector2(20,14),Vector2(400,34),24)
 audition_hint=UiStyle.label(board,"按分类排列 · 点一行听一个 · 音量配比与游戏内一致",Vector2(21,55),Vector2(730,26),14,UiStyle.MUTED)
 var stop_btn:=UiStyle.button(board,"停止试听",Vector2(738,17),Vector2(166,36),func():_stop_audition());stop_btn.name="StopSoundAudition";stop_btn.add_theme_font_size_override("font_size",16)
 var scroll:=ScrollContainer.new();scroll.name="AuditionScroll";scroll.position=Vector2(16,91);scroll.size=Vector2(892,277);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",7);scroll.add_child(list);board.add_child(scroll)
 for entry in SfxDirector.catalog():
  var head:=HBoxContainer.new();head.custom_minimum_size=Vector2(0,36);head.add_theme_constant_override("separation",10)
  var title:=Label.new();title.text="%s  ·  %d 个音效"%[str(entry.name),entry.sounds.size()];title.add_theme_font_size_override("font_size",18);title.add_theme_color_override("font_color",UiStyle.INK);head.add_child(title)
  var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(spacer)
  var cat_id:=str(entry.id)
  var all:=UiStyle.button(head,"整类试听",Vector2.ZERO,Vector2(112,30),func():_audition_category(cat_id));all.custom_minimum_size=Vector2(112,30);all.add_theme_font_size_override("font_size",15);list.add_child(head)
  for row in entry.sounds:
   var id:=str(row.id)
   var card:=UiStyle.button(list,"",Vector2.ZERO,Vector2(840,42),func():_audition_one(id));card.name="Audition_"+id;card.custom_minimum_size=Vector2(840,42)
   var mark:=UiStyle.label(card,"",Vector2(12,9),Vector2(24,24),17,UiStyle.MINT)
   UiStyle.label(card,str(row.name),Vector2(48,9),Vector2(190,26),17)
   UiStyle.label(card,str(row.use),Vector2(248,10),Vector2(500,24),14,UiStyle.MUTED)
   var duration:=UiStyle.label(card,SfxDirector.duration_text(id),Vector2(766,10),Vector2(72,24),14,UiStyle.MUTED);duration.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
   audition_rows.append({"id":id,"mark":mark})

func _audition_one(id: String) -> void:
 SfxDirector.stop_audition()
 for row in audition_rows:
  if is_instance_valid(row.mark):row.mark.text="▶" if str(row.id)==id else ""
 SfxDirector.audition(id)

func _audition_category(category: String) -> void:
 _stop_audition()
 var count:=SfxDirector.audition_category(category)
 if audition_hint!=null and is_instance_valid(audition_hint):
  var label:=""
  for entry in SfxDirector.catalog():
   if str(entry.id)==category:label=str(entry.name);break
  audition_hint.text="正在依次试听「%s」的 %d 个音效…" % [label,count]

func _stop_audition() -> void:
 SfxDirector.stop_audition()
 for row in audition_rows:
  if is_instance_valid(row.mark):row.mark.text=""
 if audition_hint!=null and is_instance_valid(audition_hint):
  audition_hint.text="按分类排列 · 点一行听一个 · 音量配比与游戏内一致"

## 「声音」页：沿用画面开关的卡片外观。背景音乐与音效各一组「开关 + 音量」，
## 第三张是配乐风格选择。
func _build_audio_cards() -> void:
 var music_card:=_card("MusicSettings",Vector2(28,170),Vector2(924,138),Color("e7f5fa"));audio_cards.append(music_card)
 UiStyle.icon(music_card,"gal-play",Vector2(20,21),Vector2(27,27))
 UiStyle.label(music_card,"背景音乐",Vector2(63,13),Vector2(600,37),24)
 UiStyle.label(music_card,"关闭后彻底静音，鉴赏页也不出声",Vector2(64,53),Vector2(660,27),15,UiStyle.MUTED)
 music_switch=UiStyle.button(music_card,"",Vector2(790,18),Vector2(110,37),func():_toggle_music());music_switch.name="MusicEnabled";music_switch.add_theme_font_size_override("font_size",17)
 volume_slider=HSlider.new();volume_slider.name="MusicVolume";volume_slider.position=Vector2(64,93);volume_slider.size=Vector2(650,25);volume_slider.min_value=0;volume_slider.max_value=100;volume_slider.step=5;volume_slider.value_changed.connect(_set_music_volume);WorldStyle.style_slider(volume_slider,UiStyle.MINT);music_card.add_child(volume_slider)
 volume_value=UiStyle.label(music_card,"",Vector2(778,82),Vector2(122,38),24);volume_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;volume_value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var sfx_card:=_card("SfxSettings",Vector2(28,322),Vector2(924,138),Color("f1edfc"));audio_cards.append(sfx_card)
 UiStyle.icon(sfx_card,"bolt",Vector2(20,21),Vector2(27,27)).self_modulate=Color("a18acb")
 UiStyle.label(sfx_card,"游戏音效",Vector2(63,13),Vector2(600,37),24)
 UiStyle.label(sfx_card,"按钮、战斗、拾取与对白反馈",Vector2(64,53),Vector2(660,27),15,UiStyle.MUTED)
 sfx_switch=UiStyle.button(sfx_card,"",Vector2(790,18),Vector2(110,37),func():_toggle_sfx());sfx_switch.name="SfxEnabled";sfx_switch.add_theme_font_size_override("font_size",17)
 sfx_slider=HSlider.new();sfx_slider.name="SfxVolume";sfx_slider.position=Vector2(64,93);sfx_slider.size=Vector2(650,25);sfx_slider.min_value=0;sfx_slider.max_value=100;sfx_slider.step=5;sfx_slider.value_changed.connect(_set_sfx_volume);sfx_slider.drag_ended.connect(func(_changed:bool):SfxDirector.play("ui_confirm",-3.0));WorldStyle.style_slider(sfx_slider,Color("ab94d0"));sfx_card.add_child(sfx_slider)
 sfx_value=UiStyle.label(sfx_card,"",Vector2(778,82),Vector2(122,38),24);sfx_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;sfx_value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var style_card:=_card("MusicStyle",Vector2(28,474),Vector2(924,80),Color("fff5e7"));audio_cards.append(style_card)
 UiStyle.icon(style_card,"gal-letter",Vector2(20,24),Vector2(28,28)).self_modulate=UiStyle.GOLD
 UiStyle.label(style_card,"配乐风格",Vector2(64,10),Vector2(178,32),21)
 UiStyle.label(style_card,"按场景自动选曲",Vector2(65,46),Vector2(176,22),13,UiStyle.MUTED)
 style_picker=OptionButton.new();style_picker.name="MusicStylePicker";style_picker.position=Vector2(250,20);style_picker.size=Vector2(650,40);style_picker.add_theme_font_size_override("font_size",17)
 for key in MusicDirector.style_keys():style_picker.add_item(MusicDirector.style_display_name(str(key)))
 style_picker.item_selected.connect(_pick_style);style_card.add_child(style_picker)

func _toggle_music() -> void:
 MusicDirector.set_enabled(not MusicDirector.music_enabled())
 refresh()

func _set_music_volume(value: float) -> void:
 if _syncing_audio:return
 MusicDirector.set_volume(value/100.0)
 refresh()

func _pick_style(index: int) -> void:
 var keys: Array=MusicDirector.style_keys()
 if index>=0 and index<keys.size():MusicDirector.set_style(str(keys[index]))
 refresh()

func _toggle_sfx() -> void:
 # 不用再补一声确认音：树级钩子已经会给这次按钮点击放 ui_click，
 # 这里再来一声会和它叠在一起，听起来像回声。
 SfxDirector.set_enabled(not SfxDirector.enabled())
 refresh()

func _set_sfx_volume(value: float) -> void:
 if _syncing_audio:return
 SfxDirector.set_volume(value/100.0)
 refresh()
