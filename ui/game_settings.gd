extends Control
const UiStyle=preload("res://ui/whale_skin.gd")
const PixelFrames=preload("res://dialogue/pixel_skin.gd")
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
 game=owner_game;size=Vector2(980,668)
 UiStyle.mascot(self,Vector2(25,18),Vector2(96,96))
 UiStyle.label(self,"鲸鱼的小设置",Vector2(139,27),Vector2(607,48),32)
 UiStyle.label(self,"把鲸落港调成喜欢的样子。",Vector2(141,79),Vector2(597,28),21,UiStyle.MUTED)
 tab_buttons["display"]=game._button("画面",Vector2(139,110),Vector2(150,32),self,func():_set_tab("display"))
 tab_buttons["audio"]=game._button("声音",Vector2(297,110),Vector2(150,32),self,func():_set_tab("audio"))
 tab_buttons["audition"]=game._button("音效试听",Vector2(455,110),Vector2(150,32),self,func():_set_tab("audition"))
 game._button("Esc 关闭",Vector2(800,31),Vector2(150,50),self,func():game._settings(false))
 var options: Array=[["fullscreen","全屏显示","展开整个鲸落港"],["shadows","柔和阴影","保留建筑与家具的层次"],["effects","光影细节","墙角、物件底部与氛围微光"],["dusk","暮色暖光","让窗口亮起暖色的灯"],["follow","跟随人物","镜头靠近正在漫步的你"],["smooth_camera","柔顺镜头","走动时平缓地跟随"],["day_cycle","昼夜循环","清晨、午后、黄昏与夜晚"]]
 for i in options.size():
  var option: Array=options[i];var id: String=option[0]
  var card:=UiStyle.panel(self,Vector2(30+(i%2)*467,144+(i/2)*100),Vector2(453,90),"card")
  display_cards.append(card)
  UiStyle.label(card,option[1],Vector2(17,15),Vector2(271,37),25)
  UiStyle.label(card,option[2],Vector2(18,55),Vector2(415,32),19,UiStyle.MUTED)
  switches[id]=game._button("",Vector2(320,15),Vector2(113,40),card,func():_toggle(id))
 var time_card:=UiStyle.panel(self,Vector2(497,444),Vector2(453,90),"card")
 UiStyle.label(time_card,"一天的长度",Vector2(17,9),Vector2(260,30),23)
 day_speed=OptionButton.new();day_speed.position=Vector2(17,44);day_speed.size=Vector2(417,35);time_card.add_child(day_speed)
 for duration in [6,12,24]:day_speed.add_item("现实 %d 分钟"%duration)
 day_speed.item_selected.connect(func(index: int):HarborPrefs.day_minutes=[6.0,12.0,24.0][index];HarborPrefs.save();HarborPrefs.apply_game(game,true))
 display_cards.append(time_card)
 _build_audio_cards()
 _build_audition_cards()
 feedback=UiStyle.label(self,"设置会自动保存，下次打开依然生效。",Vector2(33,553),Vector2(911,36),20,UiStyle.MUTED)
 UiStyle.label(self,"战斗界面使用 MiSans 字体 · Xiaomi",Vector2(33,589),Vector2(911,18),14,UiStyle.MUTED)
 var done: Button=game._button("回到鲸落港   ▸",Vector2(30,610),Vector2(920,42),self,func():game._settings(false))
 done.add_theme_stylebox_override("normal",PixelFrames.frame("nameplate"));done.add_theme_color_override("font_color",Color("fff8e7"))
 # Keep debug controls available to existing engine diagnostics, outside the player UI.
 game.settings_front_button=Button.new();game.settings_front_button.pressed.connect(func():game._set_actor_front(not game.actor_front));add_child(game.settings_front_button);game.settings_front_button.hide()
 game.settings_foot_button=Button.new();game.settings_foot_button.pressed.connect(func():game.foot_debug.visible=not game.foot_debug.visible);add_child(game.settings_foot_button);game.settings_foot_button.hide()
 game.settings_fx_button=switches.effects;game.settings_light_button=switches.dusk
 refresh()
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
  if is_instance_valid(button):UiStyle.card_button(button,id==settings_tab)
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
 var board:=UiStyle.panel(self,Vector2(30,144),Vector2(920,400))
 audition_cards.append(board)
 UiStyle.label(board,"音效试听",Vector2(16,10),Vector2(150,30),25)
 audition_hint=UiStyle.label(board,"按分类排列 · 点一行听一个 · 音量配比与游戏内一致",Vector2(140,14),Vector2(560,26),17,UiStyle.MUTED)
 var stop_btn: Button=game._button("停止整类试听",Vector2(716,10),Vector2(190,30),board,func():_stop_audition())
 stop_btn.add_theme_font_size_override("font_size",17)
 var scroll:=ScrollContainer.new()
 scroll.position=Vector2(14,44);scroll.size=Vector2(892,344)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 var list:=VBoxContainer.new()
 list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 list.add_theme_constant_override("separation",5)
 scroll.add_child(list);board.add_child(scroll)
 for entry in SfxDirector.catalog():
  var head:=HBoxContainer.new()
  head.custom_minimum_size=Vector2(0,32)
  head.add_theme_constant_override("separation",10)
  var title:=Label.new()
  title.text="%s   %+.1f dB   ·   %d 个" % [str(entry.name),float(entry.gain_db),entry.sounds.size()]
  title.add_theme_font_size_override("font_size",20)
  title.add_theme_color_override("font_color",UiStyle.INK)
  head.add_child(title)
  var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(spacer)
  var cat_id:=str(entry.id)
  var all:=Button.new()
  all.text="整类试听"
  all.custom_minimum_size=Vector2(112,28)
  all.add_theme_font_size_override("font_size",17)
  UiStyle.card_button(all,false)
  all.pressed.connect(func():_audition_category(cat_id))
  head.add_child(all)
  list.add_child(head)
  for row in entry.sounds:
   var id:=str(row.id)
   var card:=Button.new()
   card.custom_minimum_size=Vector2(840,38)
   card.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
   card.add_theme_stylebox_override("normal",UiStyle.frame("dialogue"))
   var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color("d6a24e")
   focus.set_border_width_all(3);focus.set_expand_margin_all(3)
   card.add_theme_stylebox_override("focus",focus)
   card.pressed.connect(func():_audition_one(id))
   list.add_child(card)
   # 「正在响」标记固定建一次，之后只改文字 —— 靠名字查找会因为 Godot 清理非法字符而失败
   var mark:=UiStyle.label(card,"",Vector2(10,7),Vector2(24,24),18)
   UiStyle.label(card,str(row.name),Vector2(38,7),Vector2(180,24),19)
   UiStyle.label(card,str(row.use),Vector2(228,8),Vector2(510,24),17,UiStyle.MUTED)
   var length_label:=UiStyle.label(card,SfxDirector.duration_text(id),Vector2(748,8),Vector2(82,24),17,UiStyle.MUTED)
   length_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
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
 var music_card:=UiStyle.panel(self,Vector2(30,144),Vector2(453,90),"card")
 UiStyle.label(music_card,"背景音乐",Vector2(17,15),Vector2(200,37),25)
 UiStyle.label(music_card,"关闭后彻底静音，鉴赏页也不出声",Vector2(18,55),Vector2(296,32),17,UiStyle.MUTED)
 music_switch=game._button("",Vector2(320,15),Vector2(113,40),music_card,func():_toggle_music())
 audio_cards.append(music_card)

 var volume_card:=UiStyle.panel(self,Vector2(497,144),Vector2(453,90),"card")
 UiStyle.label(volume_card,"音乐音量",Vector2(17,10),Vector2(200,30),25)
 volume_slider=HSlider.new();volume_slider.position=Vector2(17,52);volume_slider.size=Vector2(310,26)
 volume_slider.min_value=0.0;volume_slider.max_value=100.0;volume_slider.step=5.0
 volume_slider.value_changed.connect(_set_music_volume)
 UiStyle.style_slider(volume_slider)
 volume_card.add_child(volume_slider)
 volume_value=UiStyle.label(volume_card,"",Vector2(337,48),Vector2(97,32),22,UiStyle.INK)
 volume_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 volume_value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 audio_cards.append(volume_card)

 var style_card:=UiStyle.panel(self,Vector2(30,244),Vector2(453,90),"card")
 UiStyle.label(style_card,"配乐风格",Vector2(17,10),Vector2(260,30),25)
 style_picker=OptionButton.new();style_picker.position=Vector2(17,46);style_picker.size=Vector2(417,34)
 for key in MusicDirector.style_keys():style_picker.add_item(MusicDirector.style_display_name(str(key)))
 style_picker.item_selected.connect(_pick_style)
 style_card.add_child(style_picker)
 audio_cards.append(style_card)

 var sfx_card:=UiStyle.panel(self,Vector2(30,344),Vector2(453,90),"card")
 UiStyle.label(sfx_card,"音效",Vector2(17,15),Vector2(200,37),25)
 UiStyle.label(sfx_card,"按钮、战斗与拾取",Vector2(18,55),Vector2(296,32),17,UiStyle.MUTED)
 sfx_switch=game._button("",Vector2(320,15),Vector2(113,40),sfx_card,func():_toggle_sfx())
 audio_cards.append(sfx_card)

 var sfx_volume_card:=UiStyle.panel(self,Vector2(497,344),Vector2(453,90),"card")
 UiStyle.label(sfx_volume_card,"音效音量",Vector2(17,10),Vector2(200,30),25)
 sfx_slider=HSlider.new();sfx_slider.position=Vector2(17,52);sfx_slider.size=Vector2(310,26)
 sfx_slider.min_value=0.0;sfx_slider.max_value=100.0;sfx_slider.step=5.0
 sfx_slider.value_changed.connect(_set_sfx_volume)
 # 松手时给一声试听：拖动过程中连续响会像盖革计数器，一下一下反而听不出音量
 sfx_slider.drag_ended.connect(func(_changed: bool):SfxDirector.play("ui_confirm",-3.0))
 UiStyle.style_slider(sfx_slider)
 sfx_volume_card.add_child(sfx_slider)
 sfx_value=UiStyle.label(sfx_volume_card,"",Vector2(337,48),Vector2(97,32),22,UiStyle.INK)
 sfx_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 sfx_value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 audio_cards.append(sfx_volume_card)

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
