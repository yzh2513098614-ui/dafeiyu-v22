extends SceneTree
## Actual home / E resolver / inventory UI, with isolated inventory and world saves.
const Life=preload("res://district/whale_home_life.gd")
const Safety=preload("res://character/collision_safety.gd")
const OUT="res://预览/大肥鱼之家_容器与厨房_20261016/"
var game
var checks:=0
var failures:=0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true);call_deferred("review")

func check(ok: bool,label: String) -> void:
	checks+=1
	if ok:print("HOME STORAGE PASS: ",label)
	else:failures+=1;push_error("HOME STORAGE FAIL: "+label)

func settle(frames: int=4) -> void:
	for i in frames:await physics_frame

func stand(point: Vector3) -> void:
	game.loot.close();game.player.position=point;game.player.velocity=Vector3.ZERO
	game.silhouette_body.global_position=point;game.home_controller.set_layers()
	await settle()

func review() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_node("MusicDirector").set_process(false)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="whale_home"
	prefs.world_save_path=OUT+"world.json";prefs.settings_path=OUT+"settings.cfg"
	prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false
	prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.day_cycle=false
	game=load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game);current_scene=game;game.life_booted=false;game.set_physics_process(false)
	game.dialogue_controller.save_path=OUT+"dialogue.json"
	game.dialogue_controller.state.seen["welcome"]=true
	await settle(8);game.dialogue_controller.close();game.dialog_open=false
	var loot=game.loot
	check(loot.save_path=="user://whale_inventory_home_life_test.json","test inventory is isolated before initial character save")
	var ids: Dictionary={}
	for chest in loot.chests:ids[chest.container_id]=true
	check(loot.chests.size()>=20 and ids.size()==loot.chests.size(),"home registers independent furniture containers: "+str(loot.chests.size()))
	var fridge: Node3D=game.world.get_node("HomeAction_blue_fridge")
	var pantry: Node3D=game.world.get_node("HomeAction_pantry")
	var wardrobe: Node3D=game.world.get_node("HomeAction_guest_wardrobe")
	check(loot.stocks[fridge.container_id].milk_carton==4 and loot.stocks[pantry.container_id].water_drop==6,"first visit seeds finite food and pantry stock")
	loot.inventory={"token_snack":2,"crystal_cluster":2,"pencil_cup":1}
	await stand(Vector3(-11.9,.05,-6.85))
	check(Safety.clear_at(game.player,game.player.position) and Safety.supported(game.player,game.player.position),"fridge approach has clearance and ground")
	check(game.map_interactions._pick().get("node")==fridge,"E resolver chooses the real fridge")
	var key:=InputEventKey.new();key.physical_keycode=KEY_E;key.pressed=true;Input.parse_input_event(key)
	await settle()
	check(loot.mode=="loot" and loot.current_chest==fridge and fridge.opened,"E key opens fridge and the shared storage UI")
	check(not game.character_controller.free_world() and game.click_navigation.path.is_empty(),"storage blocks movement and clears click navigation")
	if loot.mode!="loot":quit(1);return
	var before: Dictionary=loot.inventory.duplicate(true)
	check(not loot.deposit("crystal_cluster",1) and loot.inventory==before,"fridge rejects nonfood without consuming it")
	var bag_slot: Button=loot.modal.find_child("BagItem_token_snack",true,false)
	bag_slot.pressed.emit();loot.quantity.value=1;loot.take_button.pressed.emit()
	check(loot.inventory.token_snack==1 and loot.stocks[fridge.container_id].token_snack==1,"left inventory UI stores selected quantity")
	loot.rows.token_snack.pressed.emit();loot.take_button.pressed.emit()
	check(loot.inventory.token_snack==2 and loot.stocks[fridge.container_id].token_snack==0,"right container UI takes the stored item back")
	var saved_path: String=loot.save_path
	loot.save_path="user://missing_home_storage_directory/fail.json"
	before=loot.inventory.duplicate(true);var stocks_before: Dictionary=loot.stocks.duplicate(true)
	check(not loot.deposit("token_snack",1) and loot.inventory==before and loot.stocks==stocks_before,"failed storage save rolls both sides back")
	loot.save_path=saved_path;loot.close();await settle(34)
	check(not fridge.opened and is_zero_approx(fridge.parts[0].rotation.y),"closing UI closes fridge doors")
	var cabinet: Node3D=game.world.get_node("HomeAction_cabinet_m8p2_0p0_m10p9")
	await stand(cabinet.global_position+Vector3(0,.05,1.9))
	check(game.map_interactions._pick().get("node")==cabinet,"E resolver reaches existing kitchen cabinet")
	game.map_interactions.try_interact()
	check(loot.current_chest==cabinet and loot.stock_total(cabinet.container_id)==0,"empty cupboard opens for storage")
	check(loot.deposit("crystal_cluster",1) and loot.stocks[cabinet.container_id].crystal_cluster==1 and not loot.stocks[fridge.container_id].has("crystal_cluster"),"cupboards accept materials and keep independent stock")
	var tool_before: Dictionary=game.character_controller.model.state.equipment.duplicate(true)
	game.character_controller.model.state.equipment.tool="pencil_cup"
	check(not loot.deposit("pencil_cup",1) and loot.inventory.pencil_cup==1,"equipped final copy stays with character")
	game.character_controller.model.state.equipment=tool_before
	loot.close();await settle(32)
	check(is_zero_approx(cabinet.parts[0].rotation.y),"cupboard door animation returns closed")
	await stand(Vector3(-21,10.45,-18.3))
	check(game.map_interactions._pick().get("node")==wardrobe,"upstairs wardrobe is reachable through E resolver")
	game.map_interactions.try_interact()
	check(loot.current_chest==wardrobe and loot.transfer("wave_handbag",1),"wardrobe stores handbag and supports taking it")
	loot.close()
	# Stock is consumed from backpack first, then kitchen containers, in one save.
	await stand(Vector3(-1,.05,-8.95))
	var cook: Node3D=game.world.get_node("HomeAction_breakfast")
	check(game.map_interactions._pick().get("node")==cook,"stove interaction wins over adjacent cupboards")
	game.map_interactions.try_interact()
	check(loot.inventory.get("bento_box",0)==1 and loot.stocks[fridge.container_id].snack_basket==3 and cook.busy,"cooking produces breakfast and consumes fridge ingredients")
	cook.interact();check(loot.inventory.bento_box==1,"busy animation prevents duplicate cooking")
	await settle(48)
	game.character_controller.model.state.vitals.hunger=10.0
	loot.open_bag();loot.chosen="bento_box"
	check(loot.use_selected() and loot.inventory.bento_box==0 and game.character_controller.model.value("hunger")>10,"cooked breakfast is usable through existing character system")
	loot.close()
	await stand(Vector3(25,.05,-19.9))
	check(game.map_interactions._pick().get("node")==game.world.get_node("HomeAction_star_oven"),"oven is reachable through E resolver")
	game.map_interactions.try_interact()
	check(loot.inventory.token_snack==5 and loot.stocks[fridge.container_id].bread_loaf==2,"oven produces three snacks using actual ingredients")
	await settle(48)
	await stand(Vector3(2,.05,3.8))
	check(game.map_interactions._pick().get("node")==game.world.get_node("HomeAction_dining_tea"),"tea table is reachable through E resolver")
	game.map_interactions.try_interact()
	check(loot.inventory.get("tea_cup",0)==1 and loot.stocks[pantry.container_id].water_drop==5,"tea uses stored ingredients and creates a usable drink")
	await settle(48)
	await stand(Vector3(-4.6,.05,-8.5))
	check(game.map_interactions._pick().get("node")==game.world.get_node("HomeAction_kitchen_water"),"sink is reachable through E resolver")
	game.map_interactions.try_interact()
	check(loot.inventory.get("water_drop",0)==1,"sink adds one drink to inventory")
	await settle(48)
	stocks_before=loot.stocks.duplicate(true);before=loot.inventory.duplicate(true)
	loot.save_path="user://missing_home_storage_directory/fail.json"
	var result: Dictionary=Life.produce(game,"cook")
	check(not result.ok and loot.inventory==before and loot.stocks==stocks_before,"failed cooking save restores food and output")
	loot.save_path=saved_path
	loot.stocks[fridge.container_id].milk_carton=0
	stocks_before=loot.stocks.duplicate(true);before=loot.inventory.duplicate(true)
	result=Life.produce(game,"cook")
	check(not result.ok and result.message.contains("牛奶盒") and loot.inventory==before and loot.stocks==stocks_before,"missing ingredients report shortage without spending other food")
	loot.inventory.water_drop=9999
	check(not Life.produce(game,"drink").ok and loot.inventory.water_drop==9999,"full output stack prevents overflow")
	loot.inventory.water_drop=1
	check(loot.save_state(),"save commits all furniture stock with inventory")
	before=loot.inventory.duplicate(true);stocks_before=loot.stocks.duplicate(true)
	loot.inventory.clear();loot.stocks.clear()
	var restored: bool=loot.load_state()
	check(restored,"disk reload accepts the saved inventory and character profile")
	check(JSON.parse_string(JSON.stringify(loot.inventory))==JSON.parse_string(JSON.stringify(before)) and JSON.parse_string(JSON.stringify(loot.stocks))==JSON.parse_string(JSON.stringify(stocks_before)),"disk reload restores all stored and crafted items")
	var fridge_id: String=fridge.container_id
	game._travel("city");await settle()
	var contains_home:=false
	for chest in loot.chests:
		if chest.container_id==fridge_id:contains_home=true
	check(not contains_home,"leaving home clears home container registrations")
	game._travel("whale_home");await settle()
	var retained:=true
	for id in ids:
		if JSON.parse_string(JSON.stringify(loot.stocks.get(id,{})))!=JSON.parse_string(JSON.stringify(stocks_before[id])):retained=false
	check(loot.chests.size()==ids.size() and retained,"returning home keeps stored objects and depleted food")
	check(game.world.get_node("HomeAction_blue_fridge").opened==false,"rebuilt fridge starts closed")
	print("HOME STORAGE CHECK: ",checks," CHECKS, ",checks-failures," PASSED, ",failures," FAILED")
	game.queue_free();await settle(6);quit(1 if failures else 0)
