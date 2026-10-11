extends Node
## Inventory and container stocks are one transaction, saved after every change.
const WhaleSkin = preload("res://ui/whale_skin.gd")
const UiFit = preload("res://ui/ui_fit.gd")
const InventorySkin=preload("res://ui/harbor_inventory_skin.gd")
const ChestView=preload("res://ui/chest_view.gd")
const CHEST = preload("res://scenes/meme_chest.tscn")
const LifeState=preload("res://character/life_state.gd")
const INITIAL_STOCK := {
 "garden_supply":{"seed_packet":3,"hydrangea_bouquet":2,"whale_soap":3,"blue_teapot":1,"picnic_blanket":1},
 "market_supply":{"butter_bread":8,"sea_glass":2,"whale_compass":1,"harbor_ticket":1,"ivory_shell":2,"instant_camera":1},
 "gallery_supply":{"whale_sketchbook":1,"sewing_kit":1,"whale_music_box":1,"harbor_key":1,"paper_boat":2},
 "bedroom_supply":{"token_cracker":8,"context_note":1,"stopped_pillow":1,"retry_tea":3,"first_aid":2},
 "studio_supply":{"thinking_lamp":1,"prompt_pen":1,"hallucination_map":1,"cache_book":2,"tide_compass":1,"sea_shell":4,"soft_linen":3},
 "cafe_supply":{"fish_badge":1,"sea_biscuit":5,"branch_bookmark":2,"whale_letter":1,"lemon_water":4,"sea_soup":2},
 "restaurant_tea_supply":{"retry_tea":2,"butter_bread":3,"lemon_water":2},
 "restaurant_hidden_cache":{"harbor_key":1,"whale_music_box":1,"cache_book":1,"whale_letter":1}}
const ROOM_CHESTS := [
 {"id":"bedroom_supply","title":"大肥鱼的生活补给箱","pos":Vector3(-1.35,0,.50),"note":"鲸落港 · 新居民须知\n\n大肥鱼是港口蓝鲸信使的昵称。DeepSeek 深潜站在海面下收集居民的问题；港口在海面上认真生活。\n\n箱里的东西可以拿走，取走后不会凭空长回来。困了就休息，饿了就吃一点。\n\n——大肥鱼：今晚也不必给所有问题一个答案。"},
 {"id":"studio_supply","title":"DeepSeek 深潜站工具箱","pos":Vector3(-.85,0,.50),"note":"深潜站 · 值班守则\n\n一、先弄清问题，再开始思考。\n二、地图只是线索，重要的路要再核对。\n三、看到‘稍后重试’，先喝口茶。\n\n思考中……也可能是在摸鱼。\n\n——大肥鱼：别催，鱼在潜水。"},
 {"id":"cafe_supply","title":"鲸落港的阅读漂流箱","pos":Vector3(-.85,0,.50),"note":"鲸落港 · 阅读室留言\n\n故事未完，欢迎续杯。\n缓存旧书记得昨天，分支书签留给明天。\n如果一条路暂时走不通，就找个地方坐下。\n\n——大肥鱼：一起潜下去，也一起浮上来。"}]
var game: Node3D
var definitions: Dictionary
var inventory: Dictionary = {}
var stocks: Dictionary = INITIAL_STOCK.duplicate(true)
var chests: Array[Node3D] = []
var nearby: Node3D
var current_chest: Node3D
var mode := ""
var chosen := ""
var canvas: Control
var modal_shade: ColorRect
var quantity_minus: Button
var quantity_plus: Button
var prompt: Panel
var prompt_text: Label
var bag_button: Button
var modal: Panel
var rows: Dictionary = {}
var take_button: Button
var all_button: Button
var take_all_button: Button
var quantity: SpinBox
var selected_button: Button
var status := ""
var save_path := "user://whale_inventory_v5.json"
var bag_category := "all"
var bag_query := ""
var bag_sort := 0
var bag_page:=0
var chest_page:=0
var chest_bag_page:=0
var bag_favorites: Dictionary = {}
var character_data: Dictionary = {}
const BagView=preload("res://ui/bag_view.gd")

func occupied_slots() -> int:
 var slots:=0
 for value in inventory.values():
  if int(value)>0:slots+=1
 return slots

func filtered_inventory() -> Array:
 var ids: Array=[]
 for id in inventory:
  if int(inventory[id])<=0 or not definitions.has(id):continue
  var data: Dictionary=definitions[id]
  if bag_category=="favorite" and not bag_favorites.has(id):continue
  if bag_category not in ["all","favorite"] and not str(data.kind).begins_with(bag_category):continue
  if bag_query.strip_edges()!="" and not (str(data.name)+str(data.description)+str(data.kind)).to_lower().contains(bag_query.strip_edges().to_lower()):continue
  ids.append(id)
 ids.sort_custom(func(a,b):
  if bag_sort==1 and int(inventory[a])!=int(inventory[b]):return int(inventory[a])>int(inventory[b])
  if bag_sort==0 and str(definitions[a].kind)!=str(definitions[b].kind):return str(definitions[a].kind)<str(definitions[b].kind)
  return str(definitions[a].name)<str(definitions[b].name))
 return ids

func toggle_favorite(id: String) -> void:
 var before:=bag_favorites.duplicate(true)
 if bag_favorites.has(id):bag_favorites.erase(id)
 else:bag_favorites[id]=true
 if not save_state():bag_favorites=before;status="收藏保存失败，请稍后重试。"
 else:status="已收藏："+str(definitions[id].name) if bag_favorites.has(id) else "已取消收藏："+str(definitions[id].name)

func is_equipped(id: String) -> bool:
 return id!="" and game.character_controller!=null and game.character_controller.model.state.equipment.values().has(id)

func can_receive(id: String) -> int:
 if mode!="loot" or not is_instance_valid(current_chest) or not definitions.has(id):return 0
 var existing:=int(inventory.get(id,0))
 if existing==0 and occupied_slots()>=64:return 0
 return maxi(0,mini(int(stocks.get(current_chest.container_id,{}).get(id,0)),9999-existing))

func _receipt_plan() -> Dictionary:
 var plan: Dictionary={}
 if mode!="loot" or not _in_range(current_chest):return plan
 var stock: Dictionary=stocks.get(current_chest.container_id,{})
 var ids:=stock.keys();ids.sort()
 # Fill existing stacks first; they do not need a new inventory slot.
 ids.sort_custom(func(a,b):return int(inventory.get(a,0))>0 and int(inventory.get(b,0))<=0)
 var slots:=occupied_slots()
 for id in ids:
  if not definitions.has(id):continue
  var existing:=int(inventory.get(id,0))
  if existing==0 and slots>=64:continue
  var count:=maxi(0,mini(int(stock[id]),9999-existing))
  if count<=0:continue
  plan[id]=count
  if existing==0:slots+=1
 return plan

func receivable_total() -> int:
 var total:=0
 for count in _receipt_plan().values():total+=int(count)
 return total

func transfer_all() -> bool:
 var plan:=_receipt_plan()
 if plan.is_empty():
  status="背包已装满，剩余物品会留在宝箱。" if mode=="loot" and is_instance_valid(current_chest) and stock_total(current_chest.container_id)>0 else "宝箱已经空啦。"
  if mode=="loot":_render()
  return false
 var old_inventory:=inventory.duplicate(true);var old_stocks:=stocks.duplicate(true)
 var count:=0
 for id in plan:
  stocks[current_chest.container_id][id]-=int(plan[id]);inventory[id]=int(inventory.get(id,0))+int(plan[id]);count+=int(plan[id])
 if not save_state():
  inventory=old_inventory;stocks=old_stocks;status="保存失败，本次全部收取已撤回。";_render();return false
 var remaining:=stock_total(current_chest.container_id)
 status="收好 %d 件 · 还有 %d 件留在宝箱"%[count,remaining] if remaining>0 else "全部收好啦！共 %d 件。"%count
 game.get_node("/root/SfxDirector").play("pickup",-3.0);_bag_count();_render();return true


func _ready() -> void:
 game=get_parent()
 definitions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/meme_items.json"))
 var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character_balance.json")).items
 for id in definitions:
  definitions[id]["effect_summary"]=str(rules.get(id,{}).get("summary","可查看"))
  if rules.get(id,{}).get("action","")=="equip":definitions[id].kind="工具 · 可装备" if rules[id].slot=="tool" else "收藏 · 可装备"
 var args:=OS.get_cmdline_user_args()
 if "--test-expedition" in args:save_path="res://预览/expedition_inventory_test.json"
 elif "--test-loot" in args or "--test-room" in args or "--test-load" in args:
  save_path="user://whale_inventory_test.json"
  if "--test-load" in args:load_state()
 elif "--test-ui" in args:save_path="user://whale_inventory_ui_test.json"
 elif "--test-dialogue" in args:save_path="user://whale_inventory_dialogue_test.json"
 elif "--capture-ui" in args:save_path="user://whale_inventory_ui_preview.json"
 elif "--test-life-ui" in args:
  save_path="user://whale_inventory_life_ui_test.json";load_state()
 elif "--test-combat-ui" in args:
  save_path="user://whale_inventory_combat_ui_test.json";load_state()
 elif "--test-session-ui" in args:
  save_path="user://whale_inventory_session_ui_test.json";load_state()
 elif "--capture-dialogue" in args:save_path="user://whale_inventory_dialogue_preview.json"
 elif "--loot-demo" in args or "--atmosphere-demo" in args or "--ui-demo" in args:save_path="user://whale_inventory_demo.json"
 else:load_state()
 canvas=Control.new();canvas.z_index=90;canvas.theme=WhaleSkin.theme(game._game_font());canvas.size=Vector2(1448,1086);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;game.ui.add_child(canvas)
 UiFit.fill(canvas)
 modal_shade=ColorRect.new();modal_shade.color=Color(.08,.15,.30,.43);modal_shade.size=Vector2(1448,1086);canvas.add_child(modal_shade);modal_shade.hide()
 UiFit.fill(modal_shade)
 bag_button=game._button("I 背包 · 0",Vector2(1010,979),Vector2(190,55),canvas,func():open_bag())
 UiFit.pin_design(bag_button,1010,979,190,55)
 prompt=WhaleSkin.panel(canvas,Vector2.ZERO,Vector2(416,150))
 WhaleSkin.icon(prompt,"chest",Vector2(15,12),Vector2(40,40))
 prompt_text=_label(prompt,"",Vector2(65,13),Vector2(331,39),20)
 game._button("E 打开箱子",Vector2(17,63),Vector2(187,49),prompt,func():open_chest())
 game._button("漂流便签",Vector2(217,63),Vector2(181,49),prompt,func():open_note())
 _label(prompt,"靠近发现小惊喜，取走后自动保存。",Vector2(19,120),Vector2(379,25),16,WhaleSkin.MUTED)
 prompt.hide();_bag_count()

func blocked() -> bool:
 return mode!=""

func room_changed(index: int) -> void:
 close();nearby=null;chests.clear()
 # 新地点（type "depot"，见 district/container_rooms.gd）里的容器是 ContainerRooms
 # 自己登记进来的真实箱子。这里不要再摆一只默认补给箱 ——
 # 这个函数是 call_deferred 出来的，会在登记**之后**才跑，
 # 而它头一句就是 chests.clear()，正好把刚登记好的全抹掉。
 if game and game.locations.has(game.location_id) and str(game.locations[game.location_id].get("type",""))=="depot":return
 var entry: Dictionary=ROOM_CHESTS[index]
 var chest=CHEST.instantiate();chest.container_id=entry.id;chest.display_name=entry.title;chest.note=entry.note;chest.position=entry.pos
 chest.tint=[Color("95a9bb"),Color("748da8"),Color("b2c1cd")][index]
 game.world.add_child(chest);chests.append(chest)

func _physics_process(_delta: float) -> void:
 nearby=null
 if not game.editing and not game.panel.visible and not game.settings_panel.visible and not game.dialog_open and mode=="":
  var best:=1.6
  for chest in chests:
   if not is_instance_valid(chest):continue
   var d: float=game.player.global_position.distance_to(chest.global_position+Vector3(0,0,.22))
   if d<best and _reachable(chest):nearby=chest;best=d
 prompt.visible=nearby!=null
 if nearby:
  prompt_text.text=nearby.display_name+" · "+str(stock_total(nearby.container_id))+"件"
  var point: Vector2=game.camera.unproject_position(nearby.global_position+Vector3(0,1.48,-.35))
  prompt.position=Vector2(clampf(point.x-208,30,1002),clampf(point.y-158,128,755))

func _reachable(chest: Node3D) -> bool:
 var origin: Vector3=game.player.global_position+Vector3(0,.50,0)
 var target: Vector3=chest.global_position+Vector3(0,.50,-.38)
 var query:=PhysicsRayQueryParameters3D.create(origin,target,1,[game.player.get_rid()])
 var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():return true
 var collider: Object=hit.collider
 # 旧箱子：body 是 chest 的后代，is_ancestor_of 一发命中。
 if chest.is_ancestor_of(collider):return true
 # 新容器的树：ContainerBody 实测**不在** chest→inner 的子树里
 # （container_runtime._add_body_collision 的 add_child 时序把它挂到了内层外），
 # 所以 is_ancestor_of 和「沿父链走到 chest」两条路都返回 false。
 # 改用**距离**判定：命中点离箱子原点不到 1 米，只可能是它自己的碰撞体 ——
 # 0.38 米的探测射线里撞不到别人的东西。
 if collider is Node3D:
  var offset: Vector3=(collider as Node3D).global_position-chest.global_position
  return Vector2(offset.x,offset.z).length()<1.0
 return false

func _in_range(chest: Node3D) -> bool:
 return is_instance_valid(chest) and game.player.global_position.distance_to(chest.global_position+Vector3(0,0,.22))<1.6 and _reachable(chest)

func open_chest() -> void:
 if mode!="" or not _in_range(nearby):return
 current_chest=nearby;mode="loot";chosen="";chest_page=0;chest_bag_page=0;status="选择右侧物品，收进左侧背包。"
 current_chest.set_open(true);_face_chest();prompt.hide();_render()
 game.get_node("/root/SfxDirector").play("chest_open",-2.0)

func open_note() -> void:
 if mode!="" or not _in_range(nearby):return
 current_chest=nearby;mode="note";prompt.hide();_face_chest();_render()

func _face_chest() -> void:
 var v: Vector2=game.camera.unproject_position(current_chest.global_position)-game.camera.unproject_position(game.player.global_position)
 game.facing=game._direction_name(v);game.avatar.play("interact_"+game.facing)

func open_bag() -> void:
 var pack=game.get("pack26_controller")
 if pack!=null and pack.is_active():pack.open_bag();return
 if mode=="inventory":close();return
 close();game.panel.hide();game.settings_panel.hide();game.dialog.hide();game.dialog_open=false;game.editing=false
 mode="inventory";chosen="";status="";_render()

func close() -> void:
 if is_instance_valid(current_chest):current_chest.set_open(false)
 current_chest=null;mode="";chosen=""
 if prompt:prompt.hide()
 if modal_shade:modal_shade.hide()
 if is_instance_valid(modal):modal.hide();modal.queue_free()
 modal=null

func stock_total(id: String) -> int:
 var total:=0
 for value in stocks.get(id,{}).values():total+=int(value)
 return total

func inventory_total() -> int:
 var total:=0
 for value in inventory.values():total+=int(value)
 return total

func _bag_count() -> void:
 if bag_button:
  var value: String="I 背包 · "+str(inventory_total())
  if bag_button.text!=value:bag_button.text=value;WhaleSkin.pulse(bag_button)

func transfer(id: String,count: int) -> bool:
 if mode!="loot" or not _in_range(current_chest) or not definitions.has(id) or count<=0:return false
 var stock: Dictionary=stocks[current_chest.container_id]
 var have:=int(stock.get(id,0))
 if count>have or int(inventory.get(id,0))+count>9999:status="数量超过可收取范围，剩余物品会留在宝箱。";_render();return false
 if int(inventory.get(id,0))==0 and occupied_slots()>=64:status="背包 64 格已装满，先享用一些补给。";_render();return false
 var old_inventory: Dictionary=inventory.duplicate(true)
 stock[id]=have-count;inventory[id]=int(inventory.get(id,0))+count
 if not save_state():
  stock[id]=have;inventory=old_inventory;status="保存失败，物品尚未转移。";_render();return false
 status="已放入背包："+str(definitions[id].name)+" × "+str(count)
 game.get_node("/root/SfxDirector").play("pickup",-3.0)
 _bag_count();_render();return true

func use_selected() -> bool:
 if mode!="inventory" or not definitions.has(chosen) or int(inventory.get(chosen,0))<=0:return false
 var data: Dictionary=definitions[chosen]
 var count:=int(inventory[chosen])
 if game.character_controller:
  var model=game.character_controller.model
  var before: Dictionary=model.snapshot()
  if not model.apply_item(chosen):status=model.last_message;_render();return false
  var rule: Dictionary=model.balance.items.get(chosen,{})
  if rule.get("action","")=="consume":inventory[chosen]=count-1
  if not save_state():
   inventory[chosen]=count;model.restore(before);status="保存失败，物品与人物状态均未改变。";game.character_controller.refresh();_render();return false
  status=(str(data.use)+"\n" if rule.get("action","")=="consume" else "")+str(rule.get("summary",data.use))
  if rule.get("action","")=="equip":status=("已装备：" if model.state.equipment[rule.slot]==chosen else "已卸下：")+str(data.name)+" · "+str(rule.summary)
  # 装备走金属声，补给走治愈声 —— 「用掉一个东西」和「装上/卸下一个东西」手感要分开
  game.get_node("/root/SfxDirector").play("equip" if rule.get("action","")=="equip" else "heal",-3.0)
  game.character_controller.refresh();_bag_count();_render();return true
 if str(data.kind).begins_with("补给"):
  inventory[chosen]=count-1
  if not save_state():inventory[chosen]=count;status="保存失败，物品未消耗。";_render();return false
 status=str(data.use)
 _bag_count();_render();return true

func save_state() -> bool:
 var temp:=save_path+".tmp"
 var file:=FileAccess.open(temp,FileAccess.WRITE)
 if file==null:return false
 var profile: Dictionary=game.character_controller.model.snapshot() if game.character_controller else character_data
 var data: Dictionary={"version":2,"inventory":inventory,"stocks":stocks,"favorites":bag_favorites}
 if not profile.is_empty():data.character=profile
 file.store_string(JSON.stringify(data));file.flush();file.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(save_path))==OK

func load_state() -> bool:
 if not FileAccess.file_exists(save_path):return false
 var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
 if not data is Dictionary or not _valid_count(data.get("version",0)) or not int(data.get("version",0)) in [1,2] or not data.get("inventory") is Dictionary or not data.get("stocks") is Dictionary:return false
 var loaded: Dictionary={};var loaded_stocks: Dictionary=INITIAL_STOCK.duplicate(true)
 for id in data.inventory:
  if not definitions.has(id) or not _valid_count(data.inventory[id]):return false
  loaded[id]=int(data.inventory[id])
 for container in INITIAL_STOCK:
  if not data.stocks.get(container) is Dictionary:continue
  for id in INITIAL_STOCK[container]:
   var value=data.stocks[container].get(id,INITIAL_STOCK[container][id])
   if not _valid_count(value) or int(value)>int(INITIAL_STOCK[container][id]):return false
   loaded_stocks[container][id]=int(value)
 # 保留 INITIAL_STOCK 之外的那些容器 —— 新地点里的箱子（见 district/container_rooms.gd）
 # 是运行时按「房间__类型__序号」生成的，不在上面那张固定表里。
 # 不合并的话它们每次读档都会恢复成满的，等于可以来回刷。
 for container in data.stocks:
  if loaded_stocks.has(container) or not data.stocks[container] is Dictionary:continue
  var restored: Dictionary={}
  for id in data.stocks[container]:
   if not definitions.has(id) or not _valid_count(data.stocks[container][id]):continue
   restored[id]=int(data.stocks[container][id])
  if not restored.is_empty():loaded_stocks[container]=restored
 var profile: Dictionary={}
 if data.has("character"):
  var candidate:=LifeState.new()
  if not candidate.restore(data.character):return false
  for item in candidate.state.equipment.values():
   if item!="" and int(loaded.get(item,0))<1:return false
  profile=candidate.snapshot()
 var saved_favorites=data.get("favorites",{})
 if not saved_favorites is Dictionary:return false
 inventory=loaded;stocks=loaded_stocks;bag_favorites=saved_favorites;character_data=profile
 if game.character_controller and not profile.is_empty():game.character_controller.model.restore(profile);game.character_controller.refresh()
 _bag_count();return true

func _valid_count(value: Variant) -> bool:
 return (value is int or value is float) and float(value)==floorf(float(value)) and float(value)>=0 and float(value)<=9999

func _label(parent: Node,text: String,pos: Vector2,size: Vector2,font_size: int=21,color: Color=WhaleSkin.INK) -> Label:
 return WhaleSkin.label(parent,text,pos,size,font_size,color)

func _icon(parent: Node,id: String,pos: Vector2,size: Vector2) -> void:
 var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 icon.texture=load(str(definitions[id].get("icon_path","res://assets/item_icons/"+id+".svg")));icon.position=pos;icon.size=size;icon.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(icon)

func _render() -> void:
 if is_instance_valid(modal):modal.hide();modal.queue_free()
 rows.clear();take_button=null;all_button=null;take_all_button=null;selected_button=null;quantity_plus=null;quantity_minus=null
 modal_shade.show()
 if mode=="inventory":
  modal=InventorySkin.panel(canvas,Vector2(64,103),Vector2(1320,880),"shell")
  modal.mouse_filter=Control.MOUSE_FILTER_STOP
  UiFit.pin_center(modal,1320,103,880)
  modal.anchor_top=.5;modal.anchor_bottom=.5;modal.offset_top=-440;modal.offset_bottom=440
  var bag:=BagView.new();modal.add_child(bag);bag.configure(self);return
 if mode=="loot":
  modal=InventorySkin.panel(canvas,Vector2(64,103),Vector2(1320,880),"shell")
  modal.mouse_filter=Control.MOUSE_FILTER_STOP
  UiFit.pin_center(modal,1320,103,880)
  modal.anchor_top=.5;modal.anchor_bottom=.5;modal.offset_top=-440;modal.offset_bottom=440
  var chest:=ChestView.new();modal.add_child(chest);chest.configure(self);return
 modal=WhaleSkin.panel(canvas,Vector2(160,132),Vector2(1128,792))
 UiFit.pin_center(modal,1128,132,792)
 WhaleSkin.mascot(modal,Vector2(25,13),Vector2(77,79))
 game._button("Esc 关闭",Vector2(965,24),Vector2(136,50),modal,func():close())
 if mode=="note":
  _label(modal,"大肥鱼的漂流便签",Vector2(119,25),Vector2(819,43),29)
  _label(modal,"捡到一段小故事，慢慢读。",Vector2(121,76),Vector2(816,29),20,WhaleSkin.MUTED)
  WhaleSkin.panel(modal,Vector2(25,126),Vector2(1078,544),"paper")
  WhaleSkin.icon(modal,"book",Vector2(58,153),Vector2(41,42))
  _label(modal,current_chest.note,Vector2(120,157),Vector2(922,447),25)
  WhaleSkin.icon(modal,"star",Vector2(53,709),Vector2(35,35))
  _label(modal,"鲸落港 · 大肥鱼 × DeepSeek 深潜站",Vector2(110,708),Vector2(943,39),21,WhaleSkin.MUTED)
  return
