extends RefCounted
## Expedition economy is isolated from the player's existing life-mode inventory.
var data: Dictionary
var run: Dictionary = {}
var profile: Dictionary = {"version":1,"warehouse":{},"blueprints":[],"modules":{},"loadout":"","completed":0,"failed":0,"quest_completed":0}
var rng := RandomNumberGenerator.new()
var last_error := ""
var save_path := "user://whale_expedition_v1.json"

func _init(rules: Dictionary) -> void:
	data=rules

func new_run(seed_value: int) -> void:
	rng.seed=seed_value
	run={"seed":seed_value,"active":true,"hp":int(data.rules.integrity),"trace":0,"elapsed":0.0,"bag":{"token":12,"medical":1},"issued":{"token":12,"medical":1},"insured":{},"opened":{},"known":{},"cleared":{},"rolled":{},"log":[],"quest":false,"position":[-10,8],"combat":{},"last_summary":{}}
	run["module"]="";run["protected_module"]=false
	var selected:=str(profile.get("loadout",""))
	if data.modules.has(selected) and int(profile.modules.get(selected,0))>0:
		profile.modules[selected]-=1;run.module=selected
		log_event("携带 "+str(data.modules[selected].name)+"，装备技能已加入牌组。")
	log_event("接到委托：找到原始研究样本并带回。")

func craft_module(id: String) -> String:
	if not data.modules.has(id):return "没有这种装备"
	var spec: Dictionary=data.modules[id]
	for resource in spec.cost:
		if int(profile.warehouse.get(resource,0))<int(spec.cost[resource]):return "仓库材料不足，先搜集并安全撤离"
	for resource in spec.cost:profile.warehouse[resource]-=int(spec.cost[resource])
	profile.modules[id]=int(profile.modules.get(id,0))+1
	return "制作完成："+str(spec.name)

func equip_module(id: String) -> String:
	if bool(run.get("active",false)):return "装备在出发前选择，本局配装已经锁定"
	if id!="" and (not data.modules.has(id) or int(profile.modules.get(id,0))<=0):return "仓库中没有这件装备"
	profile.loadout=id
	return "下次出发携带 "+str(data.modules[id].name) if id!="" else "下次使用基础牌组"

func equipment_cards() -> Array:
	var id:=str(run.get("module",""))
	return data.modules[id].cards.duplicate() if data.modules.has(id) else []

func insurance_used() -> int:
	return occupied(run.get("insured",{}))+(1 if bool(run.get("protected_module",false)) else 0)

func insure_module() -> String:
	if str(run.get("module",""))=="":return "本局没有携带装备"
	if bool(run.get("protected_module",false)):return "装备已经保护"
	if insurance_used()+1>int(data.rules.insured_capacity):return "保险仓容量不足，保护装备需要一格"
	run.protected_module=true
	return "装备已保护，远征失败也能带回"

func uninsure(resource: String) -> void:
	if resource=="module":run.protected_module=false
	elif int(run.insured.get(resource,0))>0:run.insured[resource]-=1

func log_event(note: String) -> void:
	run.log.append(note)
	if run.log.size()>80: run.log.pop_front()

func trace(amount: int, reason: String) -> void:
	run.trace=clampi(int(run.trace)+amount,0,100)
	if amount!=0: log_event("%s · 痕迹 %+d"%[reason,amount])

func threat() -> String:
	var level:=int(run.get("trace",0))
	return "安全" if level<20 else ("可疑" if level<45 else ("危险" if level<75 else "极度危险"))

func occupied(bag: Variant = null) -> int:
	var entries: Dictionary=run.get("bag",{}) if bag==null else bag
	var total:=0
	for id in entries: total+=int(entries[id])*int(data.resources.get(id,{}).get("size",1))
	return total

func value_of(bag: Dictionary) -> int:
	var total:=0
	for id in bag: total+=int(bag[id])*int(data.resources.get(id,{}).get("value",0))
	return total

func loot_for(id: String, kind: String) -> Dictionary:
	if run.rolled.has(id): return run.rolled[id].duplicate(true)
	var table: Dictionary=data.loot_tables.get(kind,{})
	var output: Dictionary={}
	for resource in table:
		var count:=rng.randi_range(int(table[resource][0]),int(table[resource][1]))
		if count>0: output[resource]=count
	run.rolled[id]=output.duplicate(true)
	return output

func take(id: String, resource: String, count: int) -> String:
	if count<=0 or not run.rolled.has(id) or int(run.rolled[id].get(resource,0))<count: return "容器中的物资不足"
	var next: Dictionary=run.bag.duplicate(true)
	next[resource]=int(next.get(resource,0))+count
	if occupied(next)>int(data.rules.capacity): return "背包已满，先丢弃一些物资"
	run.bag=next;run.rolled[id][resource]=int(run.rolled[id][resource])-count
	if resource=="sample": run.quest=true
	if resource=="blueprint" and not "context_overflow" in profile.blueprints: profile.blueprints.append("context_overflow")
	log_event("收取 %s ×%d"%[data.resources[resource].name,count])
	return ""

func insure(resource: String) -> String:
	if int(run.bag.get(resource,0))<=int(run.insured.get(resource,0)): return "没有更多可保护的物资"
	if int(data.resources[resource].size)==0: return "Token不用占用保险格"
	var candidate: Dictionary=run.insured.duplicate(true);candidate[resource]=int(candidate.get(resource,0))+1
	if occupied(candidate)+(1 if bool(run.get("protected_module",false)) else 0)>int(data.rules.insured_capacity): return "保险仓只有两格容量"
	run.insured=candidate;return "已保护一件 "+str(data.resources[resource].name)

func drop(resource: String) -> void:
	if int(run.bag.get(resource,0))<=0: return
	run.bag[resource]-=1
	if int(run.insured.get(resource,0))>int(run.bag[resource]):run.insured[resource]=int(run.bag[resource])
	if resource=="sample" and int(run.bag[resource])==0:run.quest=false

func sync_bag(supply: Dictionary) -> void:
	run.bag=supply.duplicate(true)
	for id in run.insured:run.insured[id]=mini(int(run.insured[id]),int(run.bag.get(id,0)))
	run.quest=int(run.bag.get("sample",0))>0

func finish(success: bool) -> Dictionary:
	if not bool(run.get("active",false)): return run.get("last_summary",{})
	var secured: Dictionary=run.bag.duplicate(true) if success else run.insured.duplicate(true)
	# Issued starting consumables are a loan, preventing free warehouse farming.
	for id in secured:
		var owned:=maxi(0,int(run.bag.get(id,0))-int(run.get("issued",{"token":12,"medical":1}).get(id,0)))
		secured[id]=mini(int(secured[id]),owned)
	for id in secured: profile.warehouse[id]=int(profile.warehouse.get(id,0))+int(secured[id])
	profile.completed+=1 if success else 0;profile.failed+=0 if success else 1
	var quest: bool=success and int(secured.get("sample",0))>0
	if quest:
		profile.quest_completed+=1;profile.warehouse.token=int(profile.warehouse.get("token",0))+30
	var equipped:=str(run.get("module",""))
	var returned: bool=equipped!="" and (success or bool(run.get("protected_module",false)))
	if returned:profile.modules[equipped]=int(profile.modules.get(equipped,0))+1
	elif equipped!="" and int(profile.modules.get(equipped,0))==0:profile.loadout=""
	var summary: Dictionary={"success":success,"secured":secured,"value":value_of(secured),"quest":quest,"trace":run.trace,"elapsed":run.elapsed,"log":run.log.duplicate(),"blueprints":profile.blueprints.duplicate(),"module":equipped,"module_returned":returned}
	run.active=false;run.combat={};run.last_summary=summary
	return summary

func save() -> bool:
	var previous: String=FileAccess.get_file_as_string(save_path) if FileAccess.file_exists(save_path) else ""
	var file:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file==null: last_error="无法写入远征存档";return false
	file.store_string(JSON.stringify({"version":1,"profile":profile,"run":run,"rng_state":str(rng.state)}));file.flush();file.close()
	# Use a backup so a failed replacement cannot destroy an older valid save.
	if previous!="":
		var backup:=FileAccess.open(save_path+".bak",FileAccess.WRITE)
		if backup==null: last_error="无法保留旧远征存档";return false
		backup.store_string(previous);backup.close()
	var err:=DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path))
	last_error="" if err==OK else "远征存档替换失败"
	return err==OK

func load_save() -> bool:
	for path in [save_path,save_path+".bak"]:
		if not FileAccess.file_exists(path): continue
		var raw: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not raw is Dictionary or int(raw.get("version",0))!=1 or not raw.get("profile") is Dictionary or not raw.get("run") is Dictionary:continue
		profile=raw.profile;run=raw.run
		if not profile.has("modules"):profile["modules"]={}
		if not profile.has("loadout"):profile["loadout"]=""
		if not run.has("module"):run["module"]=""
		if not run.has("protected_module"):run["protected_module"]=false
		rng.state=int(raw.get("rng_state","1"));return true
	return false
