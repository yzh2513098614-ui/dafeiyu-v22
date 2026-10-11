extends Control
const S=preload("res://ui/harbor_inventory_skin.gd")
const Slot=preload("res://ui/inventory_slot.gd")
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
var previous_button: Button
var next_button: Button

func configure(loot) -> void:
 controller=loot;size=Vector2(1320,880);mouse_filter=Control.MOUSE_FILTER_IGNORE;page=controller.bag_page
 S.header(self,"随身背包","鲸落港  /  旅途收纳     ·     补给、装备与发现的故事","backpack",func():controller.close())
 var tray:=S.panel(self,Vector2(24,136),Vector2(784,646),"bag")
 var categories: Array=[["all","全部"],["补给","补给"],["工具","工具"],["收藏","随身物"],["线索","便签"],["材料","材料"],["favorite","收藏夹"]]
 for i in categories.size():
  var key: String=categories[i][0]
  var b:=S.button(self,categories[i][1],Vector2(42+i*106,153),Vector2(99,40),func():controller.bag_category=key;controller.chosen="";page=0;refresh())
  b.name="Category_"+key;b.add_theme_font_size_override("font_size",18);tabs[key]=b
 search=LineEdit.new();search.name="InventorySearch";search.position=Vector2(43,209);search.size=Vector2(449,44)
 search.placeholder_text="搜索物品名称、用途或故事…";search.clear_button_enabled=true;search.text=controller.bag_query
 search.add_theme_stylebox_override("normal",S.frame("card"));search.add_theme_stylebox_override("focus",S.frame("selected"));search.add_theme_font_size_override("font_size",18);add_child(search)
 search.text_changed.connect(func(value: String):controller.bag_query=value;controller.chosen="";page=0;refresh())
 var sort:=OptionButton.new();sort.name="InventorySort";sort.position=Vector2(506,209);sort.size=Vector2(279,44)
 for caption in ["类别整理","数量从多到少","名称排序"]:sort.add_item(caption)
 sort.add_theme_stylebox_override("normal",S.frame("button"));sort.add_theme_stylebox_override("hover",S.frame("hover"));sort.add_theme_font_size_override("font_size",18)
 sort.select(controller.bag_sort);sort.item_selected.connect(func(index: int):controller.bag_sort=index;controller.chosen="";page=0;refresh());add_child(sort)
 grid=GridContainer.new();grid.columns=6;grid.position=Vector2(19,133);grid.add_theme_constant_override("h_separation",8);grid.add_theme_constant_override("v_separation",8);tray.add_child(grid)
 previous_button=S.button(self,"‹",Vector2(578,733),Vector2(52,35),func():page=maxi(0,page-1);controller.chosen="";refresh());previous_button.name="PreviousBagPage"
 page_label=S.label(self,"",Vector2(636,739),Vector2(86,26),18);page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 next_button=S.button(self,"›",Vector2(729,733),Vector2(52,35),func():page=mini(maxi(0,ceili(visible_ids.size()/24.0)-1),page+1);controller.chosen="";refresh());next_button.name="NextBagPage"
 S.label(self,"点击格子查看  ·  ★ 收藏  ·  I / Esc 关闭",Vector2(44,739),Vector2(514,27),17,S.MUTED)
 details=S.panel(self,Vector2(828,154),Vector2(468,626),"detail")
 result=S.label(self,"",Vector2(42,797),Vector2(749,32),20)
 S.capacity(self,controller.occupied_slots(),Vector2(43,840),741)
 var status:=S.panel(self,Vector2(828,798),Vector2(468,62),"status")
 action_feedback=S.feedback(status,"",Vector2(14,9),Vector2(441,44))
 refresh()

func refresh() -> void:
 visible_ids=controller.filtered_inventory()
 var pages:=maxi(1,ceili(visible_ids.size()/24.0));page=clampi(page,0,pages-1);controller.bag_page=page
 for key in tabs:S.card_button(tabs[key],controller.bag_category==key)
 for child in grid.get_children():grid.remove_child(child);child.queue_free()
 controller.rows.clear()
 if not visible_ids.has(controller.chosen):controller.chosen=str(visible_ids[page*24]) if not visible_ids.is_empty() else ""
 for i in 24:
  var index:=page*24+i;var id:=str(visible_ids[index]) if index<visible_ids.size() else ""
  var b:=Slot.new();grid.add_child(b)
  b.configure(controller,id,int(controller.inventory.get(id,0)),Vector2(116,105),id!="" and id==controller.chosen,controller.is_equipped(id),controller.bag_favorites.has(id))
  if id!="":
   b.pressed.connect(func():controller.chosen=id;controller.status="";refresh());controller.rows[id]=b
 result.text="收纳 %d / 64 格   ·   空余 %d 格   ·   共 %d 件"%[controller.occupied_slots(),maxi(0,64-controller.occupied_slots()),controller.inventory_total()]
 page_label.text="%d / %d"%[page+1,pages];previous_button.disabled=page==0;next_button.disabled=page>=pages-1
 _detail()

func _detail() -> void:
 for child in details.get_children():details.remove_child(child);child.queue_free()
 controller.selected_button=null
 action_feedback.text=controller.status if controller.status!="" else "收取、使用与收藏后自动保存。"
 if controller.chosen=="":
  S.icon(details,"backpack",Vector2(154,78),Vector2(160,160))
  var empty:=S.label(details,"还没有找到这类物品\n\n换个分类，或去补给箱收集。",Vector2(30,298),Vector2(408,152),23,S.MUTED);empty.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;return
 var id: String=controller.chosen;var data: Dictionary=controller.definitions[id]
 var icon_frame:=S.panel(details,Vector2(162,18),Vector2(144,125),"chest");controller._icon(icon_frame,id,Vector2(12,6),Vector2(120,112))
 var name_label:=S.label(details,str(data.name),Vector2(21,155),Vector2(426,42),27);name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 var state:="  ·  已装备" if controller.is_equipped(id) else ""
 var kind:=S.label(details,str(data.kind)+"  ·  ×"+str(controller.inventory[id])+state,Vector2(18,209),Vector2(432,31),17,S.MUTED);kind.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 S.feedback(details,str(data.description),Vector2(27,257),Vector2(414,105))
 var effect:=S.panel(details,Vector2(22,374),Vector2(424,84),"bag")
 S.label(effect,str(data.get("effect_summary","可查看")),Vector2(13,12),Vector2(399,65),18)
 S.label(details,"「"+str(data.quote)+"」",Vector2(27,477),Vector2(412,60),17,S.MUTED)
 var action:="享用 1 份" if str(data.kind).begins_with("补给") else ("阅读便签" if str(data.kind).begins_with("线索") else "查看物品")
 if controller.game.character_controller:
  var rule: Dictionary=controller.game.character_controller.model.balance.items.get(id,{})
  if rule.get("action","")=="equip":action="卸下装备" if controller.is_equipped(id) else "装备到随身位"
 controller.selected_button=S.button(details,action,Vector2(22,548),Vector2(251,53),func():controller.use_selected(),true);controller.selected_button.name="UseSelectedItem"
 var favorite:=S.button(details,"★ 已收藏" if controller.bag_favorites.has(id) else "☆ 收藏",Vector2(287,548),Vector2(159,53),func():controller.toggle_favorite(id);refresh());favorite.name="FavoriteSelectedItem";favorite.add_theme_font_size_override("font_size",18)
