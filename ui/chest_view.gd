extends Control
## Two real inventories, inspired only by the supplied reference's layout.
const S=preload("res://ui/harbor_inventory_skin.gd")
const Slot=preload("res://ui/inventory_slot.gd")
var controller
var bag_grid: GridContainer
var chest_grid: GridContainer
var details: Panel
var action_feedback: Label
var bag_page_label: Label
var chest_page_label: Label
var bag_ids: Array=[]
var stock_ids: Array=[]
var bag_page:=0
var chest_page:=0
var inspecting_bag:=false
var inspected_id:=""
var previous_bag: Button
var next_bag: Button
var previous_chest: Button
var next_chest: Button
var quantity_label: Label

func configure(loot) -> void:
 controller=loot;size=Vector2(1320,880);mouse_filter=Control.MOUSE_FILTER_IGNORE
 bag_page=controller.chest_bag_page;chest_page=controller.chest_page
 inspected_id=controller.chest_bag_chosen;inspecting_bag=inspected_id!=""
 S.header(self,"容器与背包","鲸落港  /  物资收纳     ·     点击左侧存入，点击右侧取出","chest",func():controller.close())
 var bag:=S.panel(self,Vector2(24,137),Vector2(756,482),"bag")
 S.icon(bag,"backpack",Vector2(18,15),Vector2(34,34));S.label(bag,"随身背包",Vector2(66,15),Vector2(224,39),24)
 S.label(bag,"%d / 64 格  ·  空余 %d 格"%[controller.occupied_slots(),maxi(0,64-controller.occupied_slots())],Vector2(373,23),Vector2(361,29),19)
 bag_grid=GridContainer.new();bag_grid.columns=6;bag_grid.position=Vector2(19,67);bag_grid.add_theme_constant_override("h_separation",8);bag_grid.add_theme_constant_override("v_separation",8);bag.add_child(bag_grid)
 var chest:=S.panel(self,Vector2(802,159),Vector2(494,460),"chest")
 S.icon(chest,"chest",Vector2(18,12),Vector2(39,39))
 var title:=S.label(chest,controller.current_chest.display_name,Vector2(70,15),Vector2(405,41),22);title.autowrap_mode=TextServer.AUTOWRAP_OFF;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 S.label(chest,"存放 %d 件  ·  存入 / 取出自动保存"%controller.stock_total(controller.current_chest.container_id),Vector2(20,61),Vector2(452,29),18,S.MUTED)
 chest_grid=GridContainer.new();chest_grid.columns=4;chest_grid.position=Vector2(20,105);chest_grid.add_theme_constant_override("h_separation",8);chest_grid.add_theme_constant_override("v_separation",8);chest.add_child(chest_grid)
 previous_bag=S.button(self,"‹",Vector2(599,578),Vector2(39,29),func():bag_page=maxi(0,bag_page-1);refresh());previous_bag.name="PreviousChestBagPage"
 bag_page_label=S.label(self,"",Vector2(640,581),Vector2(68,25),16);bag_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 next_bag=S.button(self,"›",Vector2(715,578),Vector2(39,29),func():bag_page+=1;refresh());next_bag.name="NextChestBagPage"
 S.label(self,"点击查看 · 同类物品自动叠加",Vector2(44,582),Vector2(530,25),16,S.MUTED)
 previous_chest=S.button(self,"‹",Vector2(1113,578),Vector2(39,29),func():chest_page=maxi(0,chest_page-1);controller.chosen="";refresh());previous_chest.name="PreviousChestPage"
 chest_page_label=S.label(self,"",Vector2(1154,581),Vector2(68,25),16);chest_page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 next_chest=S.button(self,"›",Vector2(1228,578),Vector2(39,29),func():chest_page+=1;controller.chosen="";refresh());next_chest.name="NextChestPage"
 details=S.panel(self,Vector2(24,637),Vector2(756,221),"detail")
 var actions:=S.panel(self,Vector2(802,637),Vector2(494,221),"panel")
 quantity_label=S.label(actions,"转移数量",Vector2(18,13),Vector2(170,33),20)
 controller.quantity_minus=S.button(actions,"−",Vector2(234,11),Vector2(44,39),func():controller.quantity.value=maxf(1,controller.quantity.value-1));controller.quantity_minus.name="DecreaseLootQuantity"
 controller.quantity=SpinBox.new();controller.quantity.name="LootQuantity";controller.quantity.position=Vector2(288,11);controller.quantity.size=Vector2(118,39);controller.quantity.min_value=1;controller.quantity.max_value=1;controller.quantity.value=1;controller.quantity.add_theme_font_size_override("font_size",18);actions.add_child(controller.quantity)
 controller.quantity.get_line_edit().add_theme_stylebox_override("normal",S.frame("card"));controller.quantity.get_line_edit().alignment=HORIZONTAL_ALIGNMENT_CENTER
 controller.quantity_plus=S.button(actions,"+",Vector2(416,11),Vector2(44,39),func():controller.quantity.value=minf(controller.quantity.max_value,controller.quantity.value+1));controller.quantity_plus.name="IncreaseLootQuantity"
 controller.take_button=S.button(actions,"收进背包",Vector2(18,65),Vector2(205,49),func():_transfer_selected(false),true);controller.take_button.name="TakeSelectedLoot"
 controller.all_button=S.button(actions,"这一种全收取",Vector2(239,65),Vector2(237,49),func():_transfer_selected(true));controller.all_button.name="TakeSelectedStack";controller.all_button.add_theme_font_size_override("font_size",18)
 controller.take_all_button=S.button(actions,"全部收取",Vector2(18,128),Vector2(205,48),func():controller.transfer_all(),true);controller.take_all_button.name="TakeAllLoot"
 var bag_button:=S.button(actions,"I  查看背包",Vector2(239,128),Vector2(237,48),func():controller.open_bag());bag_button.name="OpenBagFromChest"
 action_feedback=S.feedback(actions,"",Vector2(19,183),Vector2(457,31))
 refresh()

func _transfer_selected(whole_stack: bool) -> void:
 var id: String=inspected_id if inspecting_bag else controller.chosen
 var count: int=(controller.can_store(id) if inspecting_bag else controller.can_receive(id)) if whole_stack else int(controller.quantity.value)
 if inspecting_bag:controller.deposit(id,count)
 else:controller.transfer(id,count)

func _fill_grid(grid: GridContainer,ids: Array,source: Dictionary,current_page: int,slots: int,dimensions: Vector2,is_bag: bool) -> void:
 for child in grid.get_children():grid.remove_child(child);child.queue_free()
 for i in slots:
  var index:=current_page*slots+i;var id:=str(ids[index]) if index<ids.size() else ""
  var b:=Slot.new();grid.add_child(b)
  b.configure(controller,id,int(source.get(id,0)),dimensions,id!="" and (id==inspected_id if inspecting_bag and is_bag else id==controller.chosen and not is_bag),is_bag and controller.is_equipped(id),is_bag and controller.bag_favorites.has(id))
  if id!="":
   if is_bag:
    b.name="BagItem_"+id;b.pressed.connect(func():inspecting_bag=true;inspected_id=id;controller.chest_bag_chosen=id;controller.status="";controller.quantity.value=1;refresh())
   else:
    b.name="ChestItem_"+id;b.pressed.connect(func():inspecting_bag=false;inspected_id="";controller.chest_bag_chosen="";controller.chosen=id;controller.status="";controller.quantity.value=1;refresh());controller.rows[id]=b

func refresh() -> void:
 bag_ids.clear();stock_ids.clear();controller.rows.clear()
 for id in controller.inventory:
  if int(controller.inventory[id])>0 and controller.definitions.has(id):bag_ids.append(id)
 var stock: Dictionary=controller.stocks.get(controller.current_chest.container_id,{})
 for id in stock:
  if int(stock[id])>0 and controller.definitions.has(id):stock_ids.append(id)
 bag_ids.sort();stock_ids.sort()
 var bag_pages:=maxi(1,ceili(bag_ids.size()/24.0));var chest_pages:=maxi(1,ceili(stock_ids.size()/12.0))
 if inspecting_bag and not bag_ids.has(inspected_id):
  inspecting_bag=false;inspected_id="";controller.chest_bag_chosen=""
 bag_page=clampi(bag_page,0,bag_pages-1);chest_page=clampi(chest_page,0,chest_pages-1);controller.chest_bag_page=bag_page;controller.chest_page=chest_page
 if not stock_ids.has(controller.chosen):controller.chosen=str(stock_ids[chest_page*12]) if not stock_ids.is_empty() else ""
 _fill_grid(bag_grid,bag_ids,controller.inventory,bag_page,24,Vector2(113,86),true)
 _fill_grid(chest_grid,stock_ids,stock,chest_page,12,Vector2(107,84),false)
 bag_page_label.text="%d / %d"%[bag_page+1,bag_pages];chest_page_label.text="%d / %d"%[chest_page+1,chest_pages]
 previous_bag.disabled=bag_page==0;next_bag.disabled=bag_page>=bag_pages-1;previous_chest.disabled=chest_page==0;next_chest.disabled=chest_page>=chest_pages-1
 var available: int=controller.can_store(inspected_id) if inspecting_bag else controller.can_receive(controller.chosen)
 quantity_label.text="存入数量" if inspecting_bag else "取出数量"
 controller.take_button.text="存入容器" if inspecting_bag else "收进背包"
 controller.all_button.text="这一种全存入" if inspecting_bag else "这一种全收取"
 controller.quantity.max_value=maxi(1,available);controller.quantity.value=clampf(controller.quantity.value,1,controller.quantity.max_value)
 var allowed: bool=available>0
 controller.take_button.disabled=not allowed;controller.all_button.disabled=not allowed
 controller.quantity.editable=allowed;controller.quantity_minus.disabled=not allowed;controller.quantity_plus.disabled=not allowed
 controller.take_all_button.disabled=controller.receivable_total()==0
 action_feedback.text=controller.status if controller.status!="" else ("已装备的最后一件，请先卸下再存入" if inspecting_bag and controller.is_equipped(inspected_id) and available==0 else "存取后自动保存 · 每侧 64 格 / 9999 叠加")
 _detail()

func _detail() -> void:
 for child in details.get_children():details.remove_child(child);child.queue_free()
 var id: String=inspected_id if inspecting_bag else controller.chosen
 if id=="" or not controller.definitions.has(id):
  S.icon(details,"chest",Vector2(24,47),Vector2(123,123))
  S.label(details,"容器里暂时没有物品",Vector2(173,38),Vector2(547,42),29)
  S.label(details,"点击左侧背包物品，可以存放在这里。\n下次回来，物品仍会留在这个容器。",Vector2(176,97),Vector2(543,95),21,S.MUTED);return
 var data: Dictionary=controller.definitions[id]
 var icon_frame:=S.panel(details,Vector2(18,20),Vector2(127,143),"bag");controller._icon(icon_frame,id,Vector2(8,17),Vector2(111,107))
 S.label(details,str(data.name),Vector2(165,17),Vector2(568,38),27)
 S.label(details,("背包内" if inspecting_bag else "宝箱内")+"  ·  "+str(data.kind)+"  ·  "+str(data.get("effect_summary","可查看")),Vector2(167,61),Vector2(563,32),17,S.MUTED)
 S.feedback(details,str(data.description),Vector2(166,104),Vector2(565,69))
 var amount:=int(controller.inventory.get(id,0)) if inspecting_bag else int(controller.stocks[controller.current_chest.container_id].get(id,0))
 S.label(details,"× "+str(amount),Vector2(20,178),Vector2(124,25),18)
 S.label(details,"「"+str(data.quote)+"」",Vector2(165,184),Vector2(565,30),17,S.MUTED)
