extends RefCounted
## Home furniture adapts to the existing two-way inventory and its atomic save.
static var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/whale_home/life_interactions.json"))

func build(b) -> void:
	# The proximity ray must recognise the furniture body as part of its action.
	# Keep all existing transforms while giving the stove/tea tables ownership
	# of their original collision and preserving the moving pan/teapot meshes.
	for action in b.facility_nodes:
		if action.kind not in ["cook","tea"]:continue
		for part: Node3D in action.parts:part.set_meta("home_dynamic",true)
		for furniture: Node3D in b.level.find_children("*","Node3D",true,false):
			if furniture.has_meta("home_furniture") and furniture.global_position.is_equal_approx(action.global_position):
				furniture.reparent(action,true)
		b._batch(action)
	for id in ["blue_fridge","pantry","guest_wardrobe"]:
		var action: Node3D=b.game.world.get_node("HomeAction_"+id)
		action.configure_storage(id,str(action.get_meta("interaction_title")),rules.initial_stock.get(id,{}),id=="blue_fridge")
		if id!="guest_wardrobe":action.set_meta("kitchen_storage",true)
	# Move the existing models, their collisions and materials together. Only
	# their door/drawer fronts stay outside the map's static mesh batches.
	var cabinets: Array[Node3D]=[]
	for node: Node3D in b.level.find_children("*","Node3D",true,false):
		if node.has_meta("cabinet_model_revision") and not node.has_node("FourBurnerCooker"):cabinets.append(node)
	for cabinet in cabinets:
		var point: Vector3=cabinet.global_position
		if cabinet.has_node("DeepKitchenSink"):continue
		var id: String=("cabinet_%.1f_%.1f_%.1f"%[point.x,point.y,point.z]).replace("-","m").replace(".","p")
		var floor_number: int=roundi(point.y/b.HEIGHT)+1
		var title: String="%dF · 储物柜"%floor_number
		if cabinet.name=="LibraryCatalogueDrawers":title="2F · 藏书分类柜"
		elif cabinet.name=="SeaBreezeConsole":title="1F · 会客厅边柜"
		elif floor_number==3:title="3F · 床头 / 衣物收纳柜"
		elif point.z< -9.0 and floor_number==1:title="1F · 厨房储物柜"
		var storage: Node3D=b._action("storage",id,title,point,point.y)
		cabinet.reparent(storage,true)
		for front: Node3D in cabinet.get_children():
			if not front.get_meta("cabinet_front",false):continue
			if str(front.name).begins_with("InsetDrawerFront"):
				front.set_meta("drawer",true);front.set_meta("closed_z",front.position.z)
				front.set_meta("home_dynamic",true);storage.parts.append(front)
			else:
				var left: float=0.0
				for mesh: MeshInstance3D in front.find_children("*","MeshInstance3D",true,false):
					var bounds: AABB=mesh.transform*mesh.get_aabb()
					left=minf(left,bounds.position.x)
				var pivot: Node3D=b._group(cabinet,"StorageDoorHinge",front.position+Vector3(left,0,0))
				pivot.set_meta("home_dynamic",true);front.reparent(pivot,true);storage.parts.append(pivot)
		storage.configure_storage(id,title)
		if floor_number==1 and point.z< -9.0:storage.set_meta("kitchen_storage",true)
		b._batch(storage)
	var sink: Node3D=b._action("drink","kitchen_water","厨房水槽 · 接饮用水",Vector3(-4.6,0,-9.95),0)
	# A brief cup lift makes the tap action visible while keeping the existing sink.
	var cup: Node3D=b._group(sink,"DrinkingWaterCup",Vector3(.25,1.40,-.75))
	b._cup(cup,Vector3.ZERO,b.BLUE);sink.parts.append(cup)
	for action in b.facility_nodes:
		if not rules.recipes.has(action.kind):continue
		var recipe: Dictionary=rules.recipes[action.kind]
		var costs: Array[String]=[]
		for id in recipe.inputs:costs.append(str(b.game.loot.definitions[id].name)+" × "+str(recipe.inputs[id]))
		action.set_meta("interaction_title",str(action.get_meta("interaction_title"))+"\n"+("无需材料" if costs.is_empty() else "需要："+"、".join(costs))+"\n自动取用背包和厨房容器；成品放入背包。")
	b.level.set_meta("home_storage_count",cabinets.size()+2)
	b.level.set_meta("home_life_revision","persistent_storage_and_kitchen_v1")

static func is_food(definition: Dictionary,id: String) -> bool:
	return definition.get("storage_group","")=="food" or rules.food_ids.has(id)

static func produce(game,kind: String) -> Dictionary:
	var recipe: Dictionary=rules.recipes[kind]
	var loot=game.loot
	var sources: Array[String]=[]
	for chest in loot.chests:
		if is_instance_valid(chest) and chest.get_meta("kitchen_storage",false):sources.append(chest.container_id)
	var missing: Array[String]=[]
	for id in recipe.inputs:
		var available: int=int(loot.inventory.get(id,0))
		for source in sources:available+=int(loot.stocks.get(source,{}).get(id,0))
		if available<int(recipe.inputs[id]):missing.append(str(loot.definitions[id].name)+" × "+str(int(recipe.inputs[id])-available))
	if not missing.is_empty():return {"ok":false,"message":"材料不足，还缺："+"、".join(missing)+"。可先去冰箱或餐具柜查看。"}
	var inventory: Dictionary=loot.inventory.duplicate(true)
	var stocks: Dictionary=loot.stocks.duplicate(true)
	for id in recipe.inputs:
		var needed: int=int(recipe.inputs[id])
		var used: int=mini(needed,int(loot.inventory.get(id,0)))
		if used>0:loot.inventory[id]-=used;needed-=used
		for source in sources:
			used=mini(needed,int(loot.stocks.get(source,{}).get(id,0)))
			if used>0:loot.stocks[source][id]-=used;needed-=used
	var fits:=true
	for id in recipe.outputs:
		loot.inventory[id]=int(loot.inventory.get(id,0))+int(recipe.outputs[id])
		if int(loot.inventory[id])>9999:fits=false
	if loot.occupied_slots()>64:fits=false
	if not fits:
		loot.inventory=inventory;loot.stocks=stocks
		return {"ok":false,"message":"背包装不下成品，先把一些物品存进柜子吧。材料没有消耗。"}
	if not loot.save_state():
		loot.inventory=inventory;loot.stocks=stocks
		return {"ok":false,"message":"保存失败，本次制作已撤回，材料没有消耗。"}
	loot._bag_count()
	var products: Array[String]=[]
	for id in recipe.outputs:products.append(str(loot.definitions[id].name)+" × "+str(recipe.outputs[id]))
	return {"ok":true,"message":"已放入背包："+"、".join(products)+"。按 I 查看或使用。"}
