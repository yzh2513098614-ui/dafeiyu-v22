extends "res://ui/harbor_start.gd"
## Reference-led title presentation; original travel, preferences and music actions are inherited.
const Candy=preload("res://ui/candy_sticker_skin.gd")
const Slots=preload("res://ui/candy_title_saves.gd")
const TitleView=preload("res://ui/title_home_view.gd")
const DESIGN_SIZE=Vector2(1672,941)
const INTRO=["未来，也想和你一起编写……","海风正好，一起去鲸落港走走吧。","把今天的小小惊喜，收进我们的故事里。"]
const CGS=[
 {"title":"糖果色海洋 · 标题插画","path":"res://assets/ui/candy_title/backdrop.png"},
 {"title":"蓝鲸信使 · 挥手立绘","path":"res://assets/ui/candy_title/gallery/whale_wave_source.png"},
 {"title":"鲸落港 · 海风街景","path":"res://assets/v18/harbor_title.png"},
 {"title":"大肥鱼 · 聊聊","path":"res://assets/dialogue/downloaded_20261014/transparent/03_talk.png"},
 {"title":"大肥鱼 · 倾听","path":"res://assets/dialogue/downloaded_20261014/transparent/01_listen.png"},
 {"title":"大肥鱼 · 思考","path":"res://assets/dialogue/downloaded_20261014/transparent/04_think.png"}]
var design_root:Control
var logo:TextureRect
var slot_service
var slots_buttons:Dictionary={}
var page_status:=""
var intro_index:=0
var intro_elapsed:=0.0
var auto_intro:=false
var intro_label:Label
var auto_button:Button
var memories:Array=[]
var cg_index:=0
var cg_image:TextureRect
var cg_caption:Label
var confirmation:ConfirmationDialog
var confirmation_action:Callable
var recovery_ok:=true
var isolated:=false

func _ready()->void:
 isolated="--test-candy-title" in OS.get_cmdline_user_args()
 theme=Candy.theme_for_menu();texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 if not isolated and not prefs().values.fullscreen and not get_tree().root.has_meta("candy_title_sized"):
  get_tree().root.size=Vector2i(1280,720);get_tree().root.set_meta("candy_title_sized",true)
 slot_service=Slots.new();slot_service.configure(prefs().world_save_path,isolated)
 recovery_ok=slot_service.recover_pending()
 if not recovery_ok:page_status=slot_service.last_error
 var outer:=ColorRect.new();outer.color=Color("d9eaff");outer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(outer);UiFit.fill(outer)
 design_root=Control.new();design_root.name="CandyCanvas";design_root.mouse_filter=Control.MOUSE_FILTER_IGNORE;design_root.size=DESIGN_SIZE;add_child(design_root)
 var backdrop:=TextureRect.new();backdrop.name="ReferenceBackdrop";backdrop.texture=load("res://assets/ui/candy_title/backdrop.png")
 backdrop.size=DESIGN_SIZE;backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;backdrop.stretch_mode=TextureRect.STRETCH_SCALE;backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;design_root.add_child(backdrop)
 logo=TextureRect.new();logo.name="StickerLogo";logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;logo.texture=load("res://assets/ui/candy_title/logo.png");logo.position=Vector2(52,-15);logo.size=Vector2(740,525)
 logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;logo.mouse_filter=Control.MOUSE_FILTER_IGNORE;design_root.add_child(logo)
 TitleView.build_dialogue(self)
 content=Panel.new();content.name="StickerMenu";content.mouse_filter=Control.MOUSE_FILTER_IGNORE;design_root.add_child(content)
 TitleView.build_tools(self)
 var quote:=Candy.label(design_root,"{ 未来，\n  也想和你\n  一起编写… }",Vector2(1407,140),Vector2(248,184),38)
 var handwriting:=SystemFont.new();handwriting.font_names=PackedStringArray(["KaiTi","STKaiti"]);handwriting.fallbacks=[load("res://assets/fonts/misans/MiSans-Bold.ttf")];quote.add_theme_font_override("font",handwriting);quote.rotation=-.06
 quote.add_theme_color_override("font_outline_color",Color.WHITE);quote.add_theme_constant_override("outline_size",10)
 var code:=Candy.label(design_root,"</>",Vector2(1512,394),Vector2(160,118),90)
 code.rotation=.08;code.add_theme_color_override("font_outline_color",Color.WHITE);code.add_theme_constant_override("outline_size",14)
 confirmation=ConfirmationDialog.new();confirmation.title="确认存档操作";confirmation.ok_button_text="确认";confirmation.cancel_button_text="取消";add_child(confirmation)
 confirmation.confirmed.connect(func():if confirmation_action.is_valid():confirmation_action.call())
 resized.connect(_fit_canvas);_fit_canvas();_render()

func _fit_canvas()->void:
 if not is_instance_valid(design_root):return
 var factor:=minf(size.x/DESIGN_SIZE.x,size.y/DESIGN_SIZE.y)
 design_root.scale=Vector2.ONE*factor;design_root.position=(size-DESIGN_SIZE*factor)*.5

func _process(delta:float)->void:
 if page!="title":return
 intro_elapsed+=delta
 if intro_label.visible_characters>=0:intro_label.visible_characters=mini(int(intro_elapsed*19),intro_label.text.length())
 if auto_intro and intro_elapsed>maxf(5.0,intro_label.text.length()/19.0+2.0):_next_intro()

func _next_intro()->void:
 intro_index=(intro_index+1)%INTRO.size();intro_elapsed=0;intro_label.text=INTRO[intro_index];intro_label.visible_characters=0

func _button(parent:Node,label:String,pos:Vector2,dimensions:Vector2,action:Callable,selected:bool=false)->Button:
 var button:=Candy.button(parent,label,pos,dimensions,action)
 if selected:button.accent=Color("ff99c8")
 return button

func _primary(button:Button)->void:
 button.accent=Color("ff8ebf");button.add_theme_font_size_override("font_size",26)

func _render()->void:
 content.theme=null
 for child in content.get_children():content.remove_child(child);child.queue_free()
 cards.clear();setting_cards.clear();tabs.clear();menu_buttons.clear();slots_buttons.clear();gallery_rows.clear()
 gallery_hint=null;gallery_scroll=null;music_mute_button=null;music_volume_slider=null;music_volume_value=null
 if page=="music":
  if not music().in_gallery():music().enter_gallery()
 elif music().in_gallery():music().exit_gallery()
 logo.visible=page=="title";greeting.visible=page=="title"
 content.position=Vector2.ZERO if page=="title" else Vector2(63,92)
 content.size=DESIGN_SIZE if page=="title" else Vector2(760,805);content.scale=Vector2.ONE
 content.add_theme_stylebox_override("panel",Candy.frame("empty" if page=="title" else "panel"))
 if page=="title":_title();return
 if page=="settings":
  content.size=Vector2(739,773);_settings();return
 var title:String={"journey":"开始游戏","harbor":"东港仓储带","pack26":"立体新区","settings":"设置","music":"音乐鉴赏","load":"读取存档","save":"保存游戏","memories":"回想","cg":"CG 鉴赏","help":"操作说明","website":"官方网站"}.get(page,"鲸落港")
 Candy.label(content,title,Vector2(30,25),Vector2(300,48),31)
 tabs["back"]=_button(content,"‹ 返回标题",Vector2(542,25),Vector2(180,53),func():_show_page("title"));tabs.back.name="BackToTitle"
 match page:
  "journey":_journey()
  "harbor":_harbor()
  "pack26":_pack26()
  "music":_music()
  "load","save":_slots_page()
  "memories":_memories_page()
  "cg":_cg_page()
  "help":_help_page()
  "website":
   Candy.label(content,"鲸落港 · 大肥鱼",Vector2(34,135),Vector2(690,55),37)
   var note:=Candy.label(content,"当前原型尚未设置公开官网。\n\n你可以在「开始游戏」中选择鲸落港、东港仓储带、\n26 地图新区与研究远征。\n\n制作中的故事，会从这里慢慢长大。",Vector2(36,218),Vector2(676,395),24)
   note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _title()->void:
 TitleView.build(self)

func _journey()->void:
 _button(content,"鲸落港",Vector2(28,96),Vector2(163,56),func():_show_page("journey"))
 _button(content,"东港仓储",Vector2(205,96),Vector2(163,56),func():_show_page("harbor"))
 _button(content,"26 地图",Vector2(382,96),Vector2(163,56),func():_show_page("pack26"))
 _button(content,"研究远征",Vector2(559,96),Vector2(163,56),func():prefs().starting_place="research";_start(false))
 Candy.label(content,"今天，从哪里开始？",Vector2(30,166),Vector2(684,45),28)
 var home_entry:=_button(content,"大肥鱼之家 · 直接入住",Vector2(397,165),Vector2(315,47),func():prefs().starting_place="whale_home";_start(false))
 home_entry.name="StartWhaleHome"
 for i in PLACES.size():
  var place:Array=PLACES[i]
  var button:=_button(content,"",Vector2(25+(i%2)*347,224+(i/2)*94),Vector2(340,86),func():prefs().starting_place=place[0];prefs().save();_render(),prefs().starting_place==place[0]);cards[place[0]]=button
  Candy.label(button,place[1],Vector2(20,12),Vector2(298,31),23)
  Candy.label(button,str(place[2]).replace("\n"," · "),Vector2(21,45),Vector2(298,25),16,Candy.MUTED)
 selection_hint=Candy.label(content,"出发地："+_place_name(),Vector2(32,624),Vector2(678,29),19)
 start_button=_button(content,"开始漫步   ▸",Vector2(25,669),Vector2(687,66),func():_start(false));_primary(start_button)
 Candy.label(content,"已有背包会保留；游戏中按 F5 保存旅程。",Vector2(33,747),Vector2(668,28),17,Candy.MUTED)

func _confirm(text:String,action:Callable)->void:
 confirmation.dialog_text=text;confirmation_action=action;confirmation.popup_centered(Vector2i(540,190))

func _slots_page()->void:
 var saving:=page=="save"
 Candy.label(content,"把上次记录的旅程收入槽位。游戏中先按 F5 保存。" if saving else "选择一段已保存的旅程。读档前会备份当前进度。",Vector2(31,101),Vector2(688,45),19,Candy.MUTED)
 for index in range(1,Slots.SLOT_COUNT+1):
  var data:Dictionary=slot_service.read_slot(index)
  var pos:=Vector2(28+((index-1)%2)*355,171+((index-1)/2)*156)
  var button:=_button(content,"",pos,Vector2(341,134),func():_slot_selected(index));button.name="Slot_%d"%index;slots_buttons[index]=button
  Candy.label(button,"存档 %02d"%index,Vector2(20,14),Vector2(299,35),26)
  Candy.label(button,"空白槽位" if data.is_empty() else _journey_place({"location":data.get("location","city")}),Vector2(21,53),Vector2(298,29),19)
  var date:=Candy.label(button,"点击保存" if saving and data.is_empty() else str(data.get("created","尚无记录")).replace("T","  "),Vector2(21,85),Vector2(298,26),15,Candy.MUTED);date.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  button.disabled=not recovery_ok or (not saving and data.is_empty()) or (saving and _saved_journey().is_empty())
 feedback=Candy.label(content,page_status if page_status!="" else ("尚无可保存的旅程；先开始游戏并保存，再回到标题。" if saving and _saved_journey().is_empty() else "存档包含位置、房间、背包、人物、对话及新区 / 远征进度。"),Vector2(34,671),Vector2(687,84),19,Candy.MUTED)
 feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _slot_selected(index:int)->void:
 if page=="save":
  if FileAccess.file_exists(slot_service._slot_path(index)):
   _confirm("覆盖存档 %02d？原槽位将由当前已记录的旅程替换。"%index,func():_write_slot(index,true))
  else:_write_slot(index,false)
 else:_confirm("读取存档 %02d 并继续游戏？读档前的进度会自动保留一份备份。"%index,func():
  if slot_service.restore_slot(index):page_status="";_start(true)
  else:page_status=slot_service.last_error;_render())

func _write_slot(index:int,overwrite:bool)->void:
 page_status="存档 %02d 已保存。"%index if slot_service.save_slot(index,overwrite) else slot_service.last_error
 _render()

func _memories_page()->void:
 memories.clear()
 var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(slot_service.paths.dialogue)) if FileAccess.file_exists(slot_service.paths.dialogue) else null
 if raw is Dictionary and raw.get("history") is Array:
  for entry in raw.history:
   if entry is Dictionary and entry.get("speaker") is String and entry.get("text") is String:memories.append(entry)
 Candy.label(content,"我们的对话，都会留在这里。",Vector2(32,106),Vector2(687,43),23,Candy.MUTED)
 if memories.is_empty():
  var empty:=Candy.label(content,"还没有回想记录。\n进入鲸落港后，按 Q 和大肥鱼聊聊。\n说过的话会自动保存，回到这里就能重温。",Vector2(38,209),Vector2(676,224),25);empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return
 var scroll:=ScrollContainer.new();scroll.position=Vector2(29,165);scroll.size=Vector2(695,591);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;content.add_child(scroll)
 var list:=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_theme_constant_override("separation",18);scroll.add_child(list)
 for entry in memories:
  var row:=VBoxContainer.new();row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_child(row)
  var who:=Label.new();who.text=str(entry.speaker)+"  ·  "+str(entry.get("topic","鲸落港"));who.add_theme_font_size_override("font_size",17);who.add_theme_color_override("font_color",Candy.MUTED);row.add_child(who)
  var line:=Label.new();line.text=entry.text;line.custom_minimum_size.x=645;line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.add_theme_font_size_override("font_size",24);row.add_child(line)

func _cg_page()->void:
 cg_index=clampi(cg_index,0,CGS.size()-1)
 cg_image=TextureRect.new();cg_image.name="CGPreview";cg_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;cg_image.texture=load(CGS[cg_index].path);cg_image.position=Vector2(28,104);cg_image.size=Vector2(692,505);cg_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;cg_image.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_child(cg_image)
 cg_caption=Candy.label(content,"%d / %d  ·  %s"%[cg_index+1,CGS.size(),CGS[cg_index].title],Vector2(31,624),Vector2(686,43),23)
 _button(content,"‹ 上一张",Vector2(28,698),Vector2(214,60),func():cg_index=posmod(cg_index-1,CGS.size());_render())
 _button(content,"下一张 ›",Vector2(509,698),Vector2(214,60),func():cg_index=(cg_index+1)%CGS.size();_render())

func _help_page()->void:
 var rows:Array=[["开始与探索","开始游戏 → 选择鲸落港、东港、26 地图或研究远征。"],["漫步与互动","WASD / 方向键移动 · E 互动 · Q 对话 · I 背包。"],["保存与读取","游戏中 F5 保存；Esc 打开菜单后选择「保存并返回标题」。\n标题的「保存游戏」可将已记录进度收入六个槽位。"],["回想与鉴赏","回想读取真实对话记录；CG 鉴赏浏览项目插画。"],["键盘操作","Tab / 方向键切换 · Enter 确认 · Esc 返回标题。"],["标题对话","AUTO 自动播放问候 · SKIP 显示最后一句 · LOG 回想。"]]
 for i in rows.size():
  Candy.label(content,rows[i][0],Vector2(33,111+i*103),Vector2(683,34),26)
  var note:=Candy.label(content,rows[i][1],Vector2(35,151+i*103),Vector2(678,62),19,Candy.MUTED);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _start(resume:bool)->void:
 if not recovery_ok:page_status="请先完成上次读档恢复。";_render();return
 super._start(resume)

func _unhandled_key_input(event:InputEvent)->void:
 if event.is_action_pressed("ui_cancel") and page!="title":page_status="";_show_page("title");get_viewport().set_input_as_handled()
