extends Node
## Inventory and container stocks are one transaction, saved after every change.
const WhaleSkin = preload("res://ui/whale_skin.gd")
const UiFit = preload("res://ui/ui_fit.gd")
const InventorySkin=preload("res://ui/harbor_inventory_skin.gd")
const ChestView=preload("res://ui/chest_view.gd")
const Compact=preload("res://ui/map_action_button.gd")
const CHEST = preload("res://scenes/meme_chest.tscn")
const LifeState=preload("res://character/life_state.gd")
const INITIAL_STOCK := {
 "garden_supply":{"potted_plant":2,"soap_bar":2,"electric_kettle":1,"scented_candle":1,"cosmetic_jar":1,"lotion_bottle":1,"spray_bottle":1,"rubber_duck":1},
 "market_supply":{"bread_loaf":8,"crystal_cluster":2,"map_route":1,"gift_box":1,"star_coin":2,"instant_camera":1,"sunglasses":1,"wallet":1},
 "gallery_supply":{"collectible_cards":1,"pencil_cup":1,"retro_radio":1,"heart_key":1,"magic_scroll":2,"vinyl_music":1,"chat_bubbles":1,"game_controller":1,"handheld_console":1,"digital_camera":1},
 "bedroom_supply":{"token_snack":8,"checklist":1,"sleep_mask":1,"tea_cup":3,"first_aid_kit":2,"backpack_crown":1,"red_alarm_clock":1,"blue_alarm_clock":1,"heart_keychain":1},
 "studio_supply":{"bedside_lamp":1,"smartphone":1,"map_route":1,"memory_module":2,"crystal_cluster":4,"wave_handbag":3,"settings_gear":1,"keyboard":1,"computer_mouse":1,"lightning_bolt":1,"crystal_sword":1,"star_shield":1,"star_bomb":1,"star_orb_bomb":1},
 "cafe_supply":{"star_coin":1,"snack_basket":5,"collectible_cards":2,"heart_letter":1,"mana_potion":4,"bento_box":2},
 "restaurant_tea_supply":{"tea_cup":2,"bread_loaf":3,"mana_potion":2,"frying_pan":1,"rice_cooker":1,"blender":1},
 "restaurant_hidden_cache":{"heart_key":1,"retro_radio":1,"memory_module":1,"heart_letter":1}}
const ROOM_CHESTS := [
 {"id":"bedroom_supply","title":"大肥鱼的生活补给箱","pos":Vector3(-1.35,0,.50),"note":"鲸落港 · 新居民须知\n\n大肥鱼是港口蓝鲸信使的昵称。DeepSeek 深潜站在海面下收集居民的问题；港口在海面上认真生活。\n\n箱里的东西可以拿走，取走后不会凭空长回来。困了就休息，饿了就吃一点。\n\n——大肥鱼：今晚也不必给所有问题一个答案。"},
 {"id":"studio_supply","title":"DeepSeek 深潜站工具箱","pos":Vector3(-.85,0,.50),"note":"深潜站 · 值班守则\n\n一、先弄清问题，再开始思考。\n二、地图只是线索，重要的路要再核对。\n三、看到‘稍后重试’，先喝口茶。\n\n思考中……也可能是在摸鱼。\n\n——大肥鱼：别催，鱼在潜水。"},
 {"id":"cafe_supply","title":"鲸落港的阅读漂流箱","pos":Vector3(-.85,0,.50),"note":"鲸落港 · 阅读室留言\n\n故事未完，欢迎续杯。\n记忆模块存着过去，卡片留给明天。\n如果一条路暂时走不通，就找个地方坐下。\n\n——大肥鱼：一起潜下去，也一起浮上来。"}]
## Old saved IDs fold into the current image-backed inventory during load.
const LEGACY_ITEM_MAP := {
 "token_cracker":"token_snack","context_note":"checklist","stopped_pillow":"sleep_mask","retry_tea":"tea_cup",
 "thinking_lamp":"bedside_lamp","prompt_pen":"pencil_cup","hallucination_map":"smartphone","cache_book":"memory_module",
 "fish_badge":"heart_keychain","sea_biscuit":"snack_basket","branch_bookmark":"collectible_cards","whale_letter":"heart_letter",
 "first_aid":"first_aid_kit","lemon_water":"mana_potion","sea_soup":"bento_box","tide_compass":"map_route",
 "sea_shell":"crystal_cluster","soft_linen":"wave_handbag","sea_glass":"crystal_cluster","whale_compass":"map_route",
 "butter_bread":"bread_loaf","hydrangea_bouquet":"potted_plant","harbor_ticket":"gift_box","whale_sketchbook":"collectible_cards",
 "seed_packet":"potted_plant","blue_teapot":"electric_kettle","sewing_kit":"hair_comb","ivory_shell":"crystal_cluster",
 "picnic_blanket":"wave_handbag","whale_music_box":"retro_radio","harbor_key":"heart_key","paper_boat":"magic_scroll",
 "whale_soap":"soap_bar","fresh_egg":"snack_basket","fresh_milk":"milk_carton","baking_flour":"bread_loaf",
 "tea_leaves":"tea_cup","drinking_water":"water_drop","whale_breakfast":"bento_box"}
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
var prompt: Button
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
var chest_bag_chosen:=""
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

func can_store(id: String) -> int:
 if mode!="loot" or not _in_range(current_chest) or not definitions.has(id):return 0
 if current_chest.has_method("can_store_item") and not current_chest.can_store_item(id):return 0
 var stock: Dictionary=stocks.get(current_chest.container_id,{})
 var existing:=int(stock.get(id,0));var slots:=0
 for value in stock.values():
  if int(value)>0:slots+=1
 if existing==0 and slots>=64:return 0
 # Equipment remains owned by the player; extra copies can still be stored.
 var available:=int(inventory.get(id,0))-(1 if is_equipped(id) else 0)
 return maxi(0,mini(available,9999-existing))

func deposit(id: String,count: int) -> bool:
 if mode!="loot" or not _in_range(current_chest) or not definitions.has(id) or count<=0:return false
 if count>can_store(id):
  if current_chest.has_method("can_store_item") and not current_chest.can_store_item(id):
   status="冰箱只收纳食材、食物和饮料。";_render();return false
  status="容器已满或数量不足；正在装备的最后一件需要先卸下。";_render();return false
 var old_inventory:=inventory.duplicate(true);var old_stocks:=stocks.duplicate(true)
 var container_id: String=current_chest.container_id
 if not stocks.has(container_id):stocks[container_id]={}
 stocks[container_id][id]=int(stocks[container_id].get(id,0))+count
 inventory[id]=int(inventory[id])-count
 if not save_state():
  inventory=old_inventory;stocks=old_stocks;status="保存失败，本次存入已撤回。";_render();return false
 status="已存入容器："+str(definitions[id].name)+" × "+str(count)
 game.get_node("/root/SfxDirector").play("pickup",-3.0)
 _bag_count();_render();return true

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
 if "--test-home-life" in args:save_path="user://whale_inventory_home_life_test.json"
 elif "--test-expedition" in args:save_path="res://预览/expedition_inventory_test.json"
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
 prompt=Compact.create(game,canvas,"E 存取物品",func():open_chest(),func():open_note())
 prompt.name="NearbyContainerButton";Compact.fit_text(prompt)
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
  var best:=2.4
  for chest in chests:
   if not is_instance_valid(chest):continue
   var d: float=game.player.global_position.distance_to(chest.global_position+Vector3(0,0,.22))
   if d<best and _in_range(chest):nearby=chest;best=d
 prompt.visible=nearby!=null and game.get("map_interactions")==null
 if nearby:
  prompt.tooltip_text=nearby.display_name+" · "+str(stock_total(nearby.container_id))+"件 · 右键阅读便签"
  Compact.place(prompt,game.camera,nearby.global_position+Vector3(0,1.48,-.35))

func _reachable(chest: Node3D) -> bool:
 var origin: Vector3=game.player.global_position+Vector3(0,.50,0)
 var target: Vector3=chest.to_global(Vector3(0,.50,0))
 var query:=PhysicsRayQueryParameters3D.create(origin,target,1,[game.player.get_rid()])
 var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():return true
 var collider: Object=hit.collider
 # Both adapters own their collision bodies. A nearby wall is never the chest.
 return collider==chest or chest.is_ancestor_of(collider)

func _in_range(chest: Node3D) -> bool:
 if not is_instance_valid(chest) or not chests.has(chest) or not chest.is_visible_in_tree():return false
 # Larger model containers need clearance for the player's silhouette before opening.
 var radius:=2.4 if chest.has_meta("container_type") else 1.6
 return game.player.global_position.distance_to(chest.global_position+Vector3(0,0,.22))<radius and _reachable(chest)

func open_chest() -> void:
 if mode!="" or not _in_range(nearby):return
 if game.get("click_navigation"):game.click_navigation.cancel()
 current_chest=nearby;mode="loot";chosen="";chest_bag_chosen="";chest_page=0;chest_bag_page=0;status="右侧取出，左侧存入；每次转移自动保存。"
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
 current_chest=null;mode="";chosen="";chest_bag_chosen=""
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
 var stock: Dictionary=stocks.get(current_chest.container_id,{})
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
 var data: Dictionary={"version":3,"inventory":inventory,"stocks":stocks,"favorites":bag_favorites}
 if not profile.is_empty():data.character=profile
 file.store_string(JSON.stringify(data));file.flush();file.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(save_path))==OK

func load_state() -> bool:
 if not FileAccess.file_exists(save_path):return false
 var data=JSON.parse_string(FileAccess.get_file_as_string(save_path))
 if not data is Dictionary or not _valid_count(data.get("version",0)) or not int(data.get("version",0)) in [1,2,3] or not data.get("inventory") is Dictionary or not data.get("stocks") is Dictionary:return false
 var loaded: Dictionary={};var loaded_stocks: Dictionary=INITIAL_STOCK.duplicate(true)
 for old_id in data.inventory:
  if not _valid_count(data.inventory[old_id]):return false
  var id:=_canonical_item_id(str(old_id))
  if id=="":return false
  loaded[id]=mini(9999,int(loaded.get(id,0))+int(data.inventory[old_id]))
 for container in data.stocks:
  if not data.stocks[container] is Dictionary:return false
  var restored: Dictionary=INITIAL_STOCK.get(container,{}).duplicate(true) if int(data.version)<3 else {}
  var migrated_stock: Dictionary={}
  for old_id in data.stocks[container]:
   if not _valid_count(data.stocks[container][old_id]):return false
   var id:=_canonical_item_id(str(old_id))
   if id=="":return false
   migrated_stock[id]=mini(9999,int(migrated_stock.get(id,0))+int(data.stocks[container][old_id]))
  for id in migrated_stock:restored[id]=migrated_stock[id]
  loaded_stocks[container]=restored
 var profile: Dictionary={}
 if data.has("character"):
  if not data.character is Dictionary:return false
  var migrated_profile: Dictionary=data.character.duplicate(true)
  if migrated_profile.get("equipment") is Dictionary:
   for slot in ["tool","charm"]:
    var old_item:=str(migrated_profile.equipment.get(slot,""))
    if old_item!="":migrated_profile.equipment[slot]=_canonical_item_id(old_item)
  var candidate:=LifeState.new()
  if not candidate.restore(migrated_profile):return false
  for item in candidate.state.equipment.values():
   if item!="" and int(loaded.get(item,0))<1:return false
  profile=candidate.snapshot()
 var saved_favorites=data.get("favorites",{})
 if not saved_favorites is Dictionary:return false
 var migrated_favorites: Dictionary={}
 for old_id in saved_favorites:
  if saved_favorites[old_id]!=true:continue
  var id:=_canonical_item_id(str(old_id))
  if id!="":migrated_favorites[id]=true
 inventory=loaded;stocks=loaded_stocks;bag_favorites=migrated_favorites;character_data=profile
 if game.character_controller and not profile.is_empty():game.character_controller.model.restore(profile);game.character_controller.refresh()
 _bag_count();return true

func _canonical_item_id(old_id: String) -> String:
 var id:=str(LEGACY_ITEM_MAP.get(old_id,old_id))
 return id if definitions.has(id) else ""

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
