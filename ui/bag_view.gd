extends Control
const WhaleStyle=preload("res://ui/whale_skin.gd")
var controller
var grid: GridContainer
var details: Panel
var result: Label
var search: LineEdit
var page_label: Label
var tabs: Dictionary={}
var visible_ids: Array=[]
var page:=0
var action_feedback: Label

func configure(loot) -> void:
 controller=loot;size=Vector2(1260,840)
 WhaleStyle.icon(self,"chest",Vector2(28,24),Vector2(47,47))
 WhaleStyle.label(self,"随身背包",Vector2(87,20),Vector2(654,46),32)
 WhaleStyle.label(self,"收好路上的小惊喜",Vector2(89,69),Vector2(664,29),20,WhaleStyle.MUTED)
 _button("Esc 关闭",Vector2(1080,25),Vector2(150,50),func():controller.close())
 var categories: Array=[["all","全部"],["补给","补给"],["工具","工具"],["收藏","随身物"],["线索","便签"],["材料","材料"],["favorite","收藏夹"]]
 for i in categories.size():
  var key: String=categories[i][0]
  var b:=_button(categories[i][1],Vector2(29+i*105,119),Vector2(98,45),func():controller.bag_category=key;page=0;refresh());b.add_theme_font_size_override("font_size",20)
  tabs[key]=b
 search=LineEdit.new();search.position=Vector2(29,179);search.size=Vector2(465,47);search.placeholder_text="搜索名称、用途或物品故事";search.clear_button_enabled=true;search.text=controller.bag_query;add_child(search)
 search.text_changed.connect(func(value: String):controller.bag_query=value;page=0;refresh())
 var sort:=OptionButton.new();sort.position=Vector2(509,179);sort.size=Vector2(244,47)
 for name in ["按类别整理","数量多的在前","名称排序"]:sort.add_item(name)
 sort.select(controller.bag_sort);sort.item_selected.connect(func(index: int):controller.bag_sort=index;page=0;refresh());add_child(sort)
 var tray:=WhaleStyle.panel(self,Vector2(24,243),Vector2(736,482),"sky")
 grid=GridContainer.new();grid.columns=6;grid.position=Vector2(12,12);grid.add_theme_constant_override("h_separation",9);grid.add_theme_constant_override("v_separation",9);tray.add_child(grid)
 details=WhaleStyle.panel(self,Vector2(783,119),Vector2(450,606),"paper")
 result=WhaleStyle.label(self,"",Vector2(30,745),Vector2(450,34),19,WhaleStyle.MUTED)
 _button("‹",Vector2(517,741),Vector2(55,44),func():page=maxi(0,page-1);refresh())
 page_label=WhaleStyle.label(self,"",Vector2(582,745),Vector2(98,34),19);page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 _button("›",Vector2(689,741),Vector2(55,44),func():page=mini(maxi(0,ceili(visible_ids.size()/24.0)-1),page+1);refresh())
 var status:=WhaleStyle.panel(self,Vector2(783,742),Vector2(450,72),"status")
 action_feedback=WhaleStyle.label(status,"每次取物与使用都会自动保存。",Vector2(15,10),Vector2(419,52),19,WhaleStyle.MUTED)
 refresh()

func _button(text: String,pos: Vector2,dimensions: Vector2,action: Callable,parent: Node=null) -> Button:
 return controller.game._button(text,pos,dimensions,self if parent==null else parent,action)

func refresh() -> void:
 visible_ids=controller.filtered_inventory()
 var pages:=maxi(1,ceili(visible_ids.size()/24.0));page=clampi(page,0,pages-1)
 for key in tabs:WhaleStyle.card_button(tabs[key],controller.bag_category==key)
 for child in grid.get_children():
  grid.remove_child(child);child.queue_free()
 controller.rows.clear()
 if not visible_ids.has(controller.chosen):controller.chosen=str(visible_ids[0]) if not visible_ids.is_empty() else ""
 for i in 24:
  var index:=page*24+i
  var b:=Button.new();b.custom_minimum_size=Vector2(110,108);grid.add_child(b)
  if index>=visible_ids.size():b.disabled=true;b.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_theme_stylebox_override("disabled",WhaleStyle.frame("sky"));continue
  var id: String=str(visible_ids[index]);var data: Dictionary=controller.definitions[id]
  WhaleStyle.card_button(b,id==controller.chosen)
  b.tooltip_text=str(data.name)+"\n"+str(data.kind)+"\n"+str(data.get("effect_summary",""))
  b.pressed.connect(func():controller.chosen=id;controller.status="";refresh())
  controller.rows[id]=b
  controller._icon(b,id,Vector2(20,7),Vector2(69,64))
  var badge:=ColorRect.new();badge.position=Vector2(54,6);badge.size=Vector2(52,26);badge.color=WhaleStyle.INK;badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(badge)
  var count:=WhaleStyle.label(badge,"×"+str(controller.inventory[id]),Vector2(2,1),Vector2(48,24),17,Color("fff8e7"));count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  var name_label:=WhaleStyle.label(b,data.name,Vector2(5,77),Vector2(100,26),18)
  name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.autowrap_mode=TextServer.AUTOWRAP_OFF;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  if controller.bag_favorites.has(id):WhaleStyle.label(b,"★",Vector2(5,6),Vector2(26,25),16,WhaleStyle.GOLD)
 result.text="%d 种 / 64 格  ·  共 %d 件"%[controller.occupied_slots(),controller.inventory_total()]
 page_label.text="%d / %d"%[page+1,pages]
 _detail()

func _detail() -> void:
 for child in details.get_children():
  details.remove_child(child);child.queue_free()
 controller.selected_button=null
 if controller.chosen=="":
  WhaleStyle.mascot(details,Vector2(110,92),Vector2(220,190))
  var empty:=WhaleStyle.label(details,"没有符合条件的物品\n试试其他分类，或去补给箱收集。",Vector2(28,340),Vector2(394,122),22,WhaleStyle.MUTED);empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
  return
 var id: String=controller.chosen;var data: Dictionary=controller.definitions[id]
 var icon_frame:=WhaleStyle.panel(details,Vector2(145,18),Vector2(160,141),"sky")
 controller._icon(icon_frame,id,Vector2(14,7),Vector2(132,127))
 var name_label:=WhaleStyle.label(details,data.name,Vector2(22,177),Vector2(406,41),28);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var kind:=WhaleStyle.label(details,str(data.kind)+"  ·  拥有 "+str(controller.inventory[id])+" 件",Vector2(22,225),Vector2(406,30),17,WhaleStyle.MUTED);kind.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 WhaleStyle.label(details,data.description,Vector2(28,266),Vector2(394,111),19)
 var effect:=WhaleStyle.panel(details,Vector2(22,380),Vector2(406,94),"sky")
 WhaleStyle.label(effect,str(data.get("effect_summary","可查看")),Vector2(13,10),Vector2(380,78),19)
 WhaleStyle.label(details,"「"+str(data.quote)+"」",Vector2(28,480),Vector2(394,35),16,WhaleStyle.MUTED)
 var action: String="享用 1 份" if str(data.kind).begins_with("补给") else ("阅读便签" if str(data.kind).begins_with("线索") else "查看物品")
 if controller.game.character_controller:
  var model=controller.game.character_controller.model
  var rule: Dictionary=model.balance.items.get(id,{})
  if rule.get("action","")=="equip":action="卸下装备" if model.state.equipment[rule.slot]==id else "装备到随身位"
 controller.selected_button=_button(action,Vector2(22,532),Vector2(255,52),func():controller.use_selected(),details)
 _button("★ 已收藏" if controller.bag_favorites.has(id) else "☆ 收藏",Vector2(292,532),Vector2(136,52),func():controller.toggle_favorite(id);refresh(),details)
 action_feedback.text=controller.status if controller.status!="" else "每次取物与使用都会自动保存。"
