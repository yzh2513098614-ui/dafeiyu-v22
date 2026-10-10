extends Control
const WhaleStyle=preload("res://ui/whale_skin.gd")
var game
var search: LineEdit
var grid: GridContainer
var scroll: ScrollContainer
var result_count: Label
var selected_group:="outside"
var query:=""
var tabs: Dictionary={}

func configure(owner_game) -> void:
 game=owner_game;selected_group=game.map_tab;size=Vector2(1278,805)
 WhaleStyle.icon(self,"book",Vector2(29,25),Vector2(44,44))
 WhaleStyle.label(self,"鲸落港 · 生活导览",Vector2(88,24),Vector2(770,48),32,WhaleStyle.INK)
 WhaleStyle.label(self,"现在在 "+str(game.locations[game.location_id].name)+"  ·  选个地方慢慢走过去",Vector2(90,78),Vector2(982,31),20,WhaleStyle.MUTED)
 _button("关闭 ×",Vector2(1112,28),Vector2(132,45),func():game._show_map(false))
 var rail:=WhaleStyle.panel(self,Vector2(20,129),Vector2(226,592),"sky")
 var groups: Array=[["outside","连续大街区"],["harbor","东港与仓储带"],["complex","立体新区 · 26地图"],["floor1","1F  各建筑一层"],["floor2","2F  各建筑二层"],["floor3","3F  各建筑三层"],["floorb1","B1  地下与暗室"],["nearby","相邻的地方"],["favorites","我的收藏"]]
 for i in groups.size():
  var key: String=groups[i][0]
  var button:=_button(groups[i][1],Vector2(31,141+i*48),Vector2(205,42),func():selected_group=key;game.map_tab=key;_draw_cards();_tab_states())
  button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.add_theme_font_size_override("font_size",18);tabs[key]=button
 var discovered:=0
 for place_id in game.locations:
  if game.visited.has(place_id):discovered+=1
 WhaleStyle.label(self,"已经发现\n%d / %d 个地点"%[discovered,game.locations.size()],Vector2(47,580),Vector2(178,74),20,Color("547b87"))
 WhaleStyle.label(self,"收藏常去的地方\n也可以在右侧搜索门牌",Vector2(46,662),Vector2(184,48),15,Color("7d9398"))
 search=LineEdit.new();search.position=Vector2(270,128);search.size=Vector2(974,49);search.placeholder_text="搜索建筑、楼层或房间用途，例如：公寓 / 2F / 厨房";search.clear_button_enabled=true;search.add_theme_font_size_override("font_size",20);add_child(search)
 search.text_changed.connect(func(value: String):query=value.strip_edges();_draw_cards())
 result_count=WhaleStyle.label(self,"",Vector2(275,187),Vector2(945,25),16,Color("738b91"))
 scroll=ScrollContainer.new();scroll.position=Vector2(270,222);scroll.size=Vector2(974,490);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.follow_focus=true;add_child(scroll)
 grid=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",18);scroll.add_child(grid)
 WhaleStyle.label(self,"带我走过去：标记下一处出口  ·  直达：快速切换  ·  E 进出  ·  M 关闭导览",Vector2(32,751),Vector2(1200,31),18,Color("70878e"))
 _tab_states();_draw_cards()

func _button(text: String,pos: Vector2,dimensions: Vector2,action: Callable,parent: Node=null) -> Button:
 if parent==null:parent=self
 var b: Button=game._button(text,pos,dimensions,parent,action)
 WhaleStyle.card_button(b);b.add_theme_color_override("font_color",WhaleStyle.INK)
 return b

func _tab_states() -> void:
 for key in tabs:
  WhaleStyle.card_button(tabs[key],selected_group==key)

func _draw_cards() -> void:
 for child in grid.get_children():
  grid.remove_child(child);child.queue_free()
 var ids: Array=[]
 for id in game.locations:
  var d: Dictionary=game.locations[id]
  var group_match: bool=d.group==selected_group
  if selected_group=="favorites":group_match=game.favorites.has(id)
  elif selected_group=="nearby":group_match=id in game.locations[game.location_id].links
  var searchable: String=str(d.name)+" "+str(d.subtitle)
  if query!="":group_match=searchable.to_lower().contains(query.to_lower())
  if group_match:ids.append(id)
 result_count.text=("搜索结果" if query!="" else ("相邻地点" if selected_group=="nearby" else ("我的收藏" if selected_group=="favorites" else game._group_name(selected_group))))+"  ·  "+str(ids.size())+" 个地点"
 if ids.is_empty():
  var empty:=Label.new();empty.text="这里还没有地点。\n试试别的关键词，或用 ☆ 收藏常去的地方。";empty.custom_minimum_size=Vector2(920,230);empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;empty.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;empty.add_theme_font_size_override("font_size",21);empty.modulate=Color("83999f");grid.add_child(empty)
 for id in ids:_card(str(id))
 scroll.scroll_vertical=0

func _card(id: String) -> void:
 var data: Dictionary=game.locations[id]
 var card:=Panel.new();card.custom_minimum_size=Vector2(302,338);card.add_theme_stylebox_override("panel",WhaleStyle.frame("selected" if id==game.location_id else "card"));grid.add_child(card)
 var art:=TextureRect.new();art.position=Vector2(12,12);art.size=Vector2(278,123);art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;art.clip_contents=true;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 var path: String="res://assets/district/places/"+id+".png"
 if ResourceLoader.exists(path):art.texture=load(path)
 else:
  var bg:=ColorRect.new();bg.position=art.position;bg.size=art.size;bg.color=Color("e2eced");bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(bg)
 card.add_child(art)
 var star:=_button("★" if game.favorites.has(id) else "☆",Vector2(250,16),Vector2(36,34),func():
  if game.favorites.has(id):game.favorites.erase(id)
  else:game.favorites[id]=true
  call_deferred("_draw_cards"),card)
 star.add_theme_font_size_override("font_size",21)
 WhaleStyle.label(card,str(data.name),Vector2(14,145),Vector2(277,33),21,Color("2f4d5d"))
 var subtitle:=WhaleStyle.label(card,str(data.subtitle),Vector2(14,184),Vector2(274,46),18,WhaleStyle.MUTED)
 subtitle.max_lines_visible=2;subtitle.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 subtitle.tooltip_text=str(data.subtitle);subtitle.mouse_filter=Control.MOUSE_FILTER_PASS
 var route: Array=game.find_route(game.location_id,id)
 var status: String="就在这里" if id==game.location_id else ("经过 "+str(maxi(0,route.size()-1))+" 处出入口" if not route.is_empty() else "暂未连接")
 WhaleStyle.label(card,status,Vector2(14,249),Vector2(276,27),18,WhaleStyle.MUTED)
 var walk:=_button("就在这里" if id==game.location_id else "带我走过去",Vector2(14,290),Vector2(176,35),func():game.set_route(id),card);walk.add_theme_font_size_override("font_size",17);walk.disabled=id==game.location_id or route.is_empty()
 var jump:=_button("直达",Vector2(201,290),Vector2(88,35),func():game.request_travel(id),card);jump.add_theme_font_size_override("font_size",17);jump.disabled=id==game.location_id
