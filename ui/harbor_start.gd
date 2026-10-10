extends Control
## Main menu made from existing harbor art, full-resolution portraits and scene previews.
const HarborStyle=preload("res://dialogue/pixel_skin.gd")
const WhaleStyle=preload("res://ui/whale_skin.gd")
const UiFit=preload("res://ui/ui_fit.gd")
const PLACES: Array=[
 ["city","漫步鲸落港","错位街巷\n多层建筑"],
 ["apt_2","回到云湾公寓","大小房间\n连通走廊"],
 ["community_1","去潮汐社区馆","咖啡阅读\n共享生活"],
 ["inn_1","到海风旅舍","海风旅人 · 多层客房"],
 ["garden","逛青柠花房","玻璃温室 · 树下茶庭"],
 ["market","去海风集市","错位摊位 · 港口小街"],
 ["obs_1","看潮汐观测站","海洋实验 · 三层星空"],
 ["music_1","听蓝鲸音乐馆","小剧场 · 录音与合奏"]]
## 新地点（东港仓储带那批）不在「楼名_楼层」这套命名里的，这里给可读名字。
## 没有这份表的话，下面 _journey_place 里取 parts[1] 对 "depot" 这种
## 没有下划线的 id 会直接越界。
const EXTRA_PLACES: Dictionary={
 "depot":"港湾补给仓 · 1F 货区","depot_2f":"港湾补给仓 · 2F 环形挑廊",
 "coldstore":"后厨冷藏间","vault":"港湾保险库","lab":"地下实验区",
 "archive":"潮汐档案馆","customs":"港口海关查验厅","weather":"山地气象站",
 "hub":"中央枢纽站","quarantine":"分区检疫所","spares":"备件长库",
 "tidal_high":"潮间带 · 涨潮","tidal_low":"潮间带 · 落潮"}

## 东港仓储带那 13 个新地点的出发点列表（标题页「去东港仓储带」按钮进入的那一页）。
## 为什么单独开一页、而不是塞进 PLACES：
## PLACES 的卡片网格是 2 列 × 340×86，8 张正好占满 4 行（204~572）；
## 第 5 行会落在 580~666，正撞上「出发地」提示（591）和「开始漫步」（629）。
## 所以新开一页，用更紧凑的 3 列 × 226×62 卡片（13 张 = 5 行，198~548）。
const HARBOR_PLACES: Array=[
 ["depot","港湾补给仓 · 1F","货笼 · 信号柜 · 潜水装备箱"],
 ["depot_2f","港湾补给仓 · 2F","环形挑廊 · 能往下看见一层"],
 ["coldstore","后厨冷藏间","双门冷藏柜 · 存货抽屉"],
 ["vault","港湾保险库","L 形平面 · 保险柜列"],
 ["lab","地下实验区","U 形中庭 · 仪器与样本"],
 ["archive","潮汐档案馆","回字形环廊 · 能绕一圈"],
 ["customs","港口海关查验厅","T 形平面 · 查验通道"],
 ["weather","山地气象站","Z 形平面 · 通道两折"],
 ["hub","中央枢纽站","十字形 · 四个方向"],
 ["quarantine","分区检疫所","室内四道隔断"],
 ["spares","备件长库","梳形 · 24 米长脊"],
 ["tidal_high","潮间带 · 涨潮","海堤 · 栈桥 · 灯塔"],
 ["tidal_low","潮间带 · 落潮","礁石与贝壳露出来"]]
var content: Panel
var page:="title"
var cards: Dictionary={}
var setting_cards: Dictionary={}
var feedback: Label
var start_button: Button
var resume_button: Button
var tabs: Dictionary={}
var selection_hint: Label
var portrait: TextureRect
var menu_buttons: Dictionary={}
var gallery_rows: Array=[]
var gallery_hint: Label
var gallery_scroll: ScrollContainer
var music_mute_button: Button
var music_volume_slider: HSlider
var music_volume_value: Label
var _syncing_audio:=false

func _ready() -> void:
 var font:=FontVariation.new();font.base_font=load("res://assets/NotoSansSC.ttf")
 font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):650.0}
 theme=HarborStyle.theme(font)
 var bg:=TextureRect.new();bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/start/harbor_background.png"))
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
 var wash:=ColorRect.new();wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);wash.color=Color(.93,.96,.95,.09);wash.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(wash)
 var brand:=HarborStyle.panel(self,Vector2(61,49),Vector2(739,174),"nameplate")
 WhaleStyle.mascot(brand,Vector2(22,27),Vector2(129,117))
 HarborStyle.label(brand,"大肥鱼",Vector2(171,19),Vector2(423,88),64,Color("fffaf0"))
 HarborStyle.label(brand,"鲸落港物语",Vector2(177,108),Vector2(330,40),28,Color("d7e4ef"))
 var seal:=HarborStyle.panel(brand,Vector2(538,109),Vector2(167,40))
 var seal_text:=HarborStyle.label(seal,"探索 · 日常",Vector2(12,6),Vector2(143,27),17);seal_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 portrait=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/dialogue/listen_original.png"));portrait.position=Vector2(850,74);portrait.size=Vector2(556,966);portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(portrait)
 # 画布宽度会随窗口比例变宽，立绘与问候框必须钉在右边缘（原设计右边距 42 / 58）
 UiFit.pin_right(portrait,556,42,74,966)
 content=HarborStyle.panel(self,Vector2(61,249),Vector2(739,773));_render()
 var greeting:=HarborStyle.panel(self,Vector2(852,919),Vector2(538,103))
 UiFit.pin_right(greeting,538,58,919,103)
 HarborStyle.label(greeting,"大肥鱼  /  港口的蓝鲸信使",Vector2(22,15),Vector2(490,29),19,HarborStyle.MUTED)
 HarborStyle.label(greeting,"“今天也慢慢来。”",Vector2(21,50),Vector2(493,39),29)
 var hint:=HarborStyle.label(self,"WASD 漫步   ·   E 互动   ·   Q 对话   ·   I 背包",Vector2(82,1041),Vector2(1259,29),17,HarborStyle.INK)
 UiFit.pin_wide(hint,82,107,1041,29)

func _button(parent: Node,label: String,pos: Vector2,size: Vector2,action: Callable,selected: bool=false) -> Button:
 var b:=Button.new();b.text=label;b.position=pos;b.size=size;b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;b.pressed.connect(action);parent.add_child(b)
 b.add_theme_stylebox_override("normal",HarborStyle.frame("selected" if selected else "dialogue"));b.add_theme_font_size_override("font_size",22)
 var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=HarborStyle.BLUE;focus.set_border_width_all(2);focus.set_corner_radius_all(9);focus.set_expand_margin_all(2)
 b.add_theme_stylebox_override("focus",focus)
 return b

func _primary(b: Button) -> void:
 for key in ["normal","hover","pressed"]:b.add_theme_stylebox_override(key,HarborStyle.frame("nameplate"))
 for key in ["font_color","font_hover_color","font_pressed_color"]:b.add_theme_color_override(key,Color("fff8e7"))
 b.add_theme_color_override("font_hover_color",Color.WHITE);b.add_theme_font_size_override("font_size",28)

func _render() -> void:
 for child in content.get_children():
  content.remove_child(child);child.queue_free()
 cards.clear();setting_cards.clear();tabs.clear();menu_buttons.clear()
 gallery_rows.clear();gallery_hint=null;gallery_scroll=null
 music_mute_button=null;music_volume_slider=null;music_volume_value=null
 # 进鉴赏页就切到鉴赏模式（停掉标题曲），离开就恢复自动跟随场合
 if page=="music":
  if not music().in_gallery():music().enter_gallery()
 elif music().in_gallery():music().exit_gallery()
 content.position=Vector2(61,249);content.size=Vector2(739,773)
 if page=="title":_title();return
 tabs["back"]=_button(content,"‹ 返回标题",Vector2(542,25),Vector2(170,48),func():_show_page("title"))
 HarborStyle.label(content,{"music":"音乐鉴赏","harbor":"东港仓储带","journey":"出发选择","pack26":"立体新区 · 26地图","settings":"画面设置"}[page],Vector2(30,25),Vector2(460,48),29)
 if page=="settings":_settings();return
 if page=="music":_music();return
 if page=="harbor":_harbor();return
 if page=="pack26":_pack26();return
 HarborStyle.label(content,"今天，从哪里开始？",Vector2(29,100),Vector2(680,43),31)
 HarborStyle.label(content,"选择一个出发点，已有背包会保留。",Vector2(31,150),Vector2(677,33),18,HarborStyle.MUTED)
 for i in PLACES.size():
  var place: Array=PLACES[i];var picked: bool=prefs().starting_place==place[0]
  var b:=_button(content,"",Vector2(25+(i%2)*347,204+(i/2)*94),Vector2(340,86),func():var pref:=prefs();pref.starting_place=place[0];pref.save();_render(),picked)
  cards[place[0]]=b
  var well:=ColorRect.new();well.position=Vector2(10,9);well.size=Vector2(94,68);well.color=Color("1a2837");well.clip_contents=true;well.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(well)
  var picture:=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.texture=load("res://assets/district/places/"+str(place[0])+".png");picture.position=Vector2.ZERO;picture.size=well.size;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;well.add_child(picture)
  HarborStyle.label(b,place[1],Vector2(116,10),Vector2(212,30),20)
  HarborStyle.label(b,str(place[2]).replace("\n"," · "),Vector2(117,47),Vector2(210,27),15,HarborStyle.MUTED)
  if picked:
   HarborStyle.label(b,"◆",Vector2(312,9),Vector2(18,24),14,HarborStyle.BLUE)
 selection_hint=HarborStyle.label(content,"出发地："+_place_name(),Vector2(32,591),Vector2(678,28),18,HarborStyle.MUTED)
 start_button=_button(content,"开始漫步   ▸",Vector2(25,629),Vector2(687,61),func():_start(false));_primary(start_button)
 _button(content,"画面设置",Vector2(25,706),Vector2(687,44),func():_show_page("settings"))

func _show_page(id: String) -> void:
 if id=="journey" and (prefs().starting_place=="research" or prefs().starting_place.begins_with("pack26_")):prefs().starting_place="city"
 if id=="pack26" and not prefs().starting_place.begins_with("pack26_"):prefs().starting_place="pack26_foodhall"
 page=id;_render()

func _title() -> void:
 content.position=Vector2(61,309);content.size=Vector2(629,713)
 HarborStyle.label(content,"把日子，过成一段小小的旅程。",Vector2(32,30),Vector2(562,42),25)
 HarborStyle.label(content,"海风、街巷，还有等你说话的人。",Vector2(33,85),Vector2(558,40),20,HarborStyle.MUTED)
 menu_buttons["journey"]=_button(content,"出发去漫步   ▸",Vector2(30,147),Vector2(569,58),func():_show_page("journey"));_primary(menu_buttons.journey)
 menu_buttons["pack26"]=_button(content,"26地图立体新区 · 多层探索   ▸",Vector2(30,215),Vector2(569,50),func():_show_page("pack26"))
 menu_buttons["research"]=_button(content,"离线研究中心 · 卡牌搜打撤   ▸",Vector2(30,273),Vector2(569,50),func():prefs().starting_place="research";_start(false))
 menu_buttons["research"].tooltip_text="三指令同步交战 · 搜索物资 · 双出口撤离"
 var journey:=_saved_journey()
 resume_button=_button(content,"继续上次旅程",Vector2(30,331),Vector2(569,50),func():_start(true));resume_button.disabled=journey.is_empty();menu_buttons["resume"]=resume_button
 menu_buttons["harbor"]=_button(content,"去东港仓储带   ▸",Vector2(30,389),Vector2(569,50),func():_show_page("harbor"));menu_buttons["harbor"].tooltip_text="海岸仓储带 · 13 个新地点"
 menu_buttons["settings"]=_button(content,"画面设置",Vector2(30,447),Vector2(569,50),func():_show_page("settings"))
 menu_buttons["music"]=_button(content,"音乐鉴赏",Vector2(30,505),Vector2(569,50),func():_show_page("music"))
 menu_buttons["quit"]=_button(content,"离开鲸落港",Vector2(30,563),Vector2(569,50),func():get_tree().quit())
 HarborStyle.label(content,"上次漫步："+_journey_place(journey) if not resume_button.disabled else "第一次来？从「出发去漫步」开始。",Vector2(35,624),Vector2(551,30),19,HarborStyle.MUTED)
 HarborStyle.label(content,"鼠标选择  ·  方向键 / Tab 切换  ·  Enter 确认",Vector2(35,662),Vector2(552,30),18,HarborStyle.MUTED)

## 东港仓储带出发点页。
## 用 3 列 × 226×62 的紧凑卡 —— 13 个地点排成 5 行（198~548），
## 后面留给「出发地」提示和「开始漫步」。
func _harbor() -> void:
 HarborStyle.label(content,"海岸仓储带上的 13 个地点",Vector2(29,96),Vector2(680,40),30)
 HarborStyle.label(content,"从街区东侧走到，或直接选这里当出发点。背包与进度照旧保留。",Vector2(31,142),Vector2(677,30),17,HarborStyle.MUTED)
 for i in HARBOR_PLACES.size():
  var place: Array=HARBOR_PLACES[i]
  var picked: bool=prefs().starting_place==place[0]
  var col: int=i%3
  var row: int=i/3
  var b:=_button(content,"",Vector2(25+col*236,196+row*72),Vector2(226,62),func():var pref:=prefs();pref.starting_place=place[0];pref.save();_render(),picked)
  cards[place[0]]=b
  var well:=ColorRect.new();well.position=Vector2(8,7);well.size=Vector2(84,48);well.color=Color("1a2837");well.clip_contents=true;well.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(well)
  var path: String="res://assets/district/places/"+str(place[0])+".png"
  if ResourceLoader.exists(path):
   var picture:=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.texture=load(path);picture.position=Vector2.ZERO;picture.size=well.size;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;well.add_child(picture)
  HarborStyle.label(b,place[1],Vector2(98,5),Vector2(122,26),17)
  var sub:=HarborStyle.label(b,str(place[2]),Vector2(98,31),Vector2(122,22),12,HarborStyle.MUTED)
  sub.max_lines_visible=1;sub.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  if picked:
   HarborStyle.label(b,"◆",Vector2(202,5),Vector2(18,24),14,HarborStyle.BLUE)
 selection_hint=HarborStyle.label(content,"出发地："+_place_name(),Vector2(32,562),Vector2(678,28),18,HarborStyle.MUTED)
 start_button=_button(content,"开始漫步   ▸",Vector2(25,590),Vector2(687,54),func():_start(false));_primary(start_button)
 _button(content,"‹ 回到出发选择",Vector2(25,650),Vector2(687,44),func():_show_page("journey"))

func _pack26() -> void:
 HarborStyle.label(content,"真实楼梯 · 错层 · 挑空 · 连通房间",Vector2(29,94),Vector2(682,41),25)
 HarborStyle.label(content,"E 搜索与开门 · H 隐藏上层 · 撤离后材料进入港口仓库",Vector2(31,140),Vector2(677,30),17,HarborStyle.MUTED)
 var definitions: Array=preload("res://district/map_pack26.gd").maps()
 for i in definitions.size():
  var spec: Dictionary=definitions[i];var id: String="pack26_"+str(spec.id)
  var b:=_button(content,spec.title,Vector2(25+(i%3)*236,185+(i/3)*51),Vector2(226,44),func():prefs().starting_place=id;prefs().save();_render(),prefs().starting_place==id)
  b.add_theme_font_size_override("font_size",16);b.tooltip_text=spec.subtitle;cards[id]=b
 selection_hint=HarborStyle.label(content,"出发地："+_place_name(),Vector2(31,655),Vector2(679,30),19,HarborStyle.MUTED)
 start_button=_button(content,"进入立体新区   ▸",Vector2(25,700),Vector2(687,52),func():
  if not prefs().starting_place.begins_with("pack26_"):prefs().starting_place="pack26_foodhall"
  _start(false));_primary(start_button)

func _unhandled_key_input(event: InputEvent) -> void:
 if event.is_action_pressed("ui_cancel") and page!="title":
  _show_page("title");get_viewport().set_input_as_handled()

func _place_name() -> String:
 if prefs().starting_place.begins_with("pack26_"):
  for spec in preload("res://district/map_pack26.gd").maps():
   if prefs().starting_place=="pack26_"+str(spec.id):return spec.title
 for place in PLACES:
  if place[0]==prefs().starting_place:return str(place[1])
 # 东港仓储带那批不在 PLACES 里，得单独查一遍，
 # 否则在这一页选了出发点，底部提示仍会显示「漫步鲸落港」
 for place in HARBOR_PLACES:
  if place[0]==prefs().starting_place:return str(place[1])
 return "漫步鲸落港"

func _settings() -> void:
 HarborStyle.label(content,"把画面调成喜欢的样子",Vector2(29,101),Vector2(680,43),30)
 HarborStyle.label(content,"设置会自动保存，下次打开依然生效。",Vector2(31,149),Vector2(677,33),18,HarborStyle.MUTED)
 var options: Array=[["fullscreen","全屏显示","专心漫步鲸落港"],["shadows","柔和阴影","保留建筑与家具层次"],["effects","氛围微光","让房间有细微的变化"],["dusk","固定暮色","需关闭自动昼夜循环"],["follow","跟随人物","开场镜头靠近出发点"],["smooth_camera","柔顺镜头","行走时平缓地跟随"],["day_cycle","昼夜循环","清晨到深夜逐渐变化"]]
 for i in options.size():
  var option: Array=options[i];var on: bool=prefs().values[option[0]]
  var b:=_button(content,"",Vector2(25+(i%2)*347,209+(i/2)*100),Vector2(340,92),func():var pref:=prefs();pref.values[option[0]]=not pref.values[option[0]];pref.apply_window();var result=pref.save();_render();feedback.text="设置已保存。" if result==OK else "设置保存失败，请重试。",on)
  setting_cards[option[0]]=b
  HarborStyle.label(b,option[1],Vector2(16,16),Vector2(226,32),23)
  var pill:=HarborStyle.panel(b,Vector2(253,15),Vector2(69,36),"nameplate" if on else "dialogue");pill.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var status:=HarborStyle.label(pill,"开启" if on else "关闭",Vector2(9,5),Vector2(51,26),17,Color("fff8e7") if on else HarborStyle.MUTED);status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  HarborStyle.label(b,option[2],Vector2(17,55),Vector2(305,30),17,HarborStyle.MUTED)
 var speed:=OptionButton.new();speed.position=Vector2(382,548);speed.size=Vector2(305,43);content.add_child(speed)
 for duration in [6,12,24]:speed.add_item("一天 = 现实 %d 分钟"%duration)
 speed.select([6.0,12.0,24.0].find(prefs().day_minutes) if prefs().day_minutes in [6.0,12.0,24.0] else 1)
 speed.item_selected.connect(func(index: int):var pref:=prefs();pref.day_minutes=[6.0,12.0,24.0][index];pref.save())
 feedback=HarborStyle.label(content,"喜欢安静一点的画面，可以关闭氛围微光。",Vector2(32,626),Vector2(679,45),18,HarborStyle.MUTED)
 HarborStyle.label(content,"战斗界面使用 MiSans 字体 · Xiaomi",Vector2(32,674),Vector2(679,18),14,HarborStyle.MUTED)
 var back:=_button(content,"返回标题",Vector2(25,696),Vector2(687,54),func():_show_page("title"));_primary(back)

## 音频控件的小回调：统一走 MusicDirector 的公开接口，界面不再直接碰 _store_* 私有方法。
func _toggle_music() -> void:
 music().set_enabled(not music().music_enabled())
 _refresh_music()

func _set_music_volume(value: float) -> void:
 if _syncing_audio:return
 music().set_volume(value/100.0)
 _refresh_music()

## 音乐设置与鉴赏：顶部是真控件（静音 / 音量 / 风格），下面是当前风格组的曲目列表
func _music() -> void:
 HarborStyle.label(content,"想听哪一首？",Vector2(29,96),Vector2(680,40),30)
 music_mute_button=_button(content,"",Vector2(31,140),Vector2(190,44),func():_toggle_music())
 music_volume_slider=HSlider.new();music_volume_slider.position=Vector2(235,146);music_volume_slider.size=Vector2(250,32)
 music_volume_slider.min_value=0.0;music_volume_slider.max_value=100.0;music_volume_slider.step=5.0
 music_volume_slider.value_changed.connect(_set_music_volume)
 WhaleStyle.style_slider(music_volume_slider);content.add_child(music_volume_slider)
 music_volume_value=HarborStyle.label(content,"",Vector2(493,140),Vector2(66,44),20,HarborStyle.INK)
 music_volume_value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 music_volume_value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 _button(content,"切换风格",Vector2(567,140),Vector2(147,44),func():music().cycle_style();_render())
 var style_label:=HarborStyle.label(content,"",Vector2(31,190),Vector2(680,28),18,HarborStyle.MUTED)
 gallery_hint=HarborStyle.label(content,"",Vector2(31,222),Vector2(680,30),18)

 var catalog: Array=music().catalog()
 # 行高与间距配合 448px 的可视高度（列表高度按曲目数算、超了会滚动）：旧值 6×74+5×8 = 484px 超过了 444px 的可视高度，
 # 最后一行会被下面的「返回标题」按钮裁掉。
 var row_h:=64
 var gap:=6
 var list_h:=catalog.size()*row_h + maxi(0,catalog.size()-1)*gap
 var list:=VBoxContainer.new();list.position=Vector2(0,0);list.size=Vector2(679,list_h)
 list.add_theme_constant_override("separation",gap)
 gallery_scroll=ScrollContainer.new();gallery_scroll.position=Vector2(24,256);gallery_scroll.size=Vector2(691,448)
 gallery_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 gallery_scroll.add_child(list);content.add_child(gallery_scroll)

 for row in catalog:
  var id: String=str(row.id)
  var card:=Button.new();card.custom_minimum_size=Vector2(679,row_h);card.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
  card.pressed.connect(func():
   music().select_gallery(id)
   if not music().music_enabled():music().set_enabled(true)
   _refresh_music())
  card.add_theme_stylebox_override("normal",HarborStyle.frame("dialogue"))
  card.add_theme_font_size_override("font_size",21)
  var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=HarborStyle.BLUE;focus.set_border_width_all(2);focus.set_corner_radius_all(9);focus.set_expand_margin_all(2)
  card.add_theme_stylebox_override("focus",focus)
  list.add_child(card)

  var title_label:=HarborStyle.label(card,str(row.name),Vector2(18,6),Vector2(430,30),21)
  var use_label:=HarborStyle.label(card,str(row.use),Vector2(19,35),Vector2(430,24),15,HarborStyle.MUTED)
  var length_label:=HarborStyle.label(card,music().track_time_text(id),Vector2(616,20),Vector2(56,24),17,HarborStyle.MUTED)
  length_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  # 「正在播放」标记固定建一次，之后只改可见性。
  # 不要靠名字查找：设置 name 时 Godot 会清理非法字符，查找必然失败，会反复叠加标签。
  var now:=HarborStyle.label(card,"▶ 正在播放",Vector2(468,20),Vector2(142,24),17,Color("fff8e7"))
  now.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  now.visible=false
  gallery_rows.append({"id":id,"card":card,"now":now,"title_label":title_label,"use_label":use_label,"length_label":length_label})

 var back:=_button(content,"返回标题",Vector2(25,720),Vector2(687,48),func():_show_page("title"));_primary(back)
 _refresh_music()
 style_label.text="当前风格组："+music().style_name()

## 只更新音频控件状态、「正在播放」标记和提示文字，不重建整个列表（避免点击时闪烁）
func _refresh_music() -> void:
 var enabled: bool=music().music_enabled()
 var percent: int=roundi(music().music_volume()*100.0)
 if is_instance_valid(music_mute_button):
  music_mute_button.text="音乐 开启 ✓" if enabled else "音乐 已静音"
  music_mute_button.add_theme_color_override("font_color",HarborStyle.INK if enabled else HarborStyle.MUTED)
 if is_instance_valid(music_volume_slider):
  _syncing_audio=true
  music_volume_slider.value=percent
  music_volume_slider.editable=enabled
  _syncing_audio=false
 if is_instance_valid(music_volume_value):
  music_volume_value.text=str(percent)+"%"
  music_volume_value.add_theme_color_override("font_color",HarborStyle.INK if enabled else HarborStyle.MUTED)
 var selected: String=music().gallery_track()
 for entry in gallery_rows:
  var id: String=str(entry.id)
  var card: Button=entry.card
  # 直接比对鉴赏页选中的曲目 id。
  # 不要用 MOOD_ORDER.find(曲目 id)：那个数组装的是场合名，永远返回 -1，
  # 而未试听时 preview_index() 也是 -1，两者相等会把全部卡片判定成「正在播放」。
  var playing: bool=selected!="" and selected==id
  card.add_theme_stylebox_override("normal",HarborStyle.frame("nameplate" if playing else "dialogue"))
  for key in ["font_color","font_hover_color","font_pressed_color"]:
   card.add_theme_color_override(key,Color("fff8e7") if playing else HarborStyle.INK)
  var now: Label=entry.now
  if is_instance_valid(now):now.visible=playing
  # 高亮行是深色 nameplate 底，而 HarborStyle.label 给每个子 Label 单独设了 font_color，
  # 只改 Button 的主题色管不到它们 —— 深色文字会压在深色底上，必须逐个子 Label 改。
  var title_label: Label=entry.title_label
  var use_label: Label=entry.use_label
  var length_label: Label=entry.length_label
  if is_instance_valid(title_label):title_label.add_theme_color_override("font_color",Color("fff8e7") if playing else HarborStyle.INK)
  if is_instance_valid(use_label):use_label.add_theme_color_override("font_color",Color("d7e4ef") if playing else HarborStyle.MUTED)
  if is_instance_valid(length_label):length_label.add_theme_color_override("font_color",Color("d7e4ef") if playing else HarborStyle.MUTED)
 if gallery_hint:
  gallery_hint.text=("已静音 · 点一首开始，或按 F10 开启" if not enabled else "点一下播放 · 只听这里的曲子 · F9 下一首 · F10 静音 · [ ] 也能调音量")

func music() -> Node:
 return get_node("/root/MusicDirector")

func prefs() -> Node:
 return get_node("/root/HarborPrefs")

func _start(resume: bool) -> void:
 if resume and _saved_journey().is_empty():return
 var pref:=prefs();pref.continue_game=resume;pref.save()
 get_tree().change_scene_to_file("res://district/continuous_world.tscn")

func _saved_journey() -> Dictionary:
 var pref:=prefs()
 if not FileAccess.file_exists(pref.world_save_path):return {}
 var data=JSON.parse_string(FileAccess.get_file_as_string(pref.world_save_path))
 if not data is Dictionary or int(data.get("version",0)) not in [3,4,5,6]:return {}
 # 这里原来硬编码了 18 个地点 id。新加的地点（港湾补给仓 / 潮间带 / 档案馆…）
 # 只要漏在名单外就会被判成「存档无效」：从那儿存档之后再打开，
 # 开始界面说不出你上次在哪。一张必须跟着内容一起改的白名单，迟早会漏 ——
 # 所以改成只校验 id 的格式，地点名交给 _journey_place 兜底。
 if not _valid_location_id(str(data.get("location",""))):return {}
 var position=data.get("position",[])
 if not position is Array or position.size()!=2:return {}
 for value in position:
  if not (value is int or value is float) or not is_finite(float(value)):return {}
 return data

func _valid_location_id(id: String) -> bool:
 if id.is_empty() or id.length()>40:return false
 for i in id.length():
  var c:=id[i]
  if (c>="a" and c<="z") or (c>="0" and c<="9") or c=="_":continue
  return false
 return true

func _journey_place(data: Dictionary) -> String:
 var location:=str(data.get("location","city"))
 if location.begins_with("pack26_"):
  for spec in preload("res://district/map_pack26.gd").maps():
   if location=="pack26_"+str(spec.id):return spec.title
 if location=="city":return "鲸落港 · 街区"
 if location in ["trial","garden","market","gallery"]:return {"trial":"潮汐试炼场","garden":"青柠温室庭院","market":"海风集市","gallery":"白帆艺廊"}[location]
 if EXTRA_PLACES.has(location):return str(EXTRA_PLACES[location])
 var parts:=location.split("_")
 var buildings: Dictionary={"apt":"云湾公寓","community":"潮汐社区馆","inn":"海风旅舍","obs":"潮汐观测站","music":"蓝鲸音乐馆"}
 # 认不出来的 id 就报个中性名字，绝不硬取 parts[1]
 if parts.size()<2 or not buildings.has(parts[0]):return "鲸落港 · 某处"
 return str(buildings[parts[0]])+" · "+parts[1]+"F"
