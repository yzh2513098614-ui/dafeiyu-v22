extends SceneTree
const Life=preload("res://character/life_state.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)
func run() -> void:
 var model:=Life.new()
 check(model.maximum("health")==100 and model.maximum("stamina")==100,"initial caps follow attribute formulas")
 check(model.attribute("insight")==5 and model.attack()==12 and model.defense()==7,"derived attributes use base values")
 check(not model.apply_item("sea_biscuit") and model.value("health")==100,"full vitals reject wasted food")
 model.state.vitals={"health":50.0,"stamina":40.0,"hunger":60.0,"mood":60.0}
 check(model.apply_item("sea_biscuit") and model.value("health")==60 and model.value("stamina")==58 and model.value("hunger")==82,"food applies distinct recovery effects")
 model.state.vitals.health=99;model.apply_item("first_aid")
 check(model.value("health")==100,"healing clamps to health cap")
 check(not model.apply_item("first_aid"),"full health prevents first aid use")
 model.apply_item("retry_tea");model.tick(1,0,false)
 check(model.state.buffs.has("calm") and model.state.buffs.calm==89,"tea creates finite buff")
 var stamina:=model.value("stamina");model.tick(1,0,false)
 check(is_equal_approx(model.value("stamina")-stamina,3.0),"tea adds idle recovery")
 model.apply_item("retry_tea")
 check(model.state.buffs.calm==90 and model.state.buffs.size()==1,"repeated tea refreshes one buff")
 model.tick(90,0,false)
 check(model.state.buffs.is_empty(),"buff expires without permanent bonuses")
 model.apply_item("prompt_pen")
 check(model.attribute("insight")==7 and model.state.base.insight==5,"equipment changes effective value only")
 model.apply_item("tide_compass")
 check(model.attribute("insight")==5 and model.attribute("agility")==5 and model.attribute("luck")==5,"new tool replaces old tool bonus")
 model.apply_item("tide_compass")
 check(model.attribute("agility")==4 and model.state.equipment.tool=="","second equip action unequips")
 model.apply_item("stopped_pillow");model.state.vitals.stamina=110;model.apply_item("stopped_pillow")
 check(model.maximum("stamina")==100 and model.value("stamina")==100,"unequip clamps lowered stamina cap")
 model.state.vitals.stamina=50;model.tick(1,1,false)
 check(is_equal_approx(model.value("stamina"),49.72),"walking has distance-based stamina cost")
 model.state.vitals.stamina=50;model.tick(1,1,true)
 check(is_equal_approx(model.value("stamina"),47.92),"sprint adds time-based cost")
 check(is_equal_approx(model.speed_multiplier(true),1.5),"sprint increases movement speed")
 model.state.vitals.stamina=0;model.tick(1000,1000,true)
 check(model.value("stamina")==0 and model.value("hunger")>=0,"long sessions clamp lower resource bounds")
 check(is_equal_approx(model.speed_multiplier(true),.8),"low stamina stops sprint acceleration")
 model.state.vitals.hunger=10;model.state.vitals.stamina=10;model.tick(1,0,false)
 check(model.value("stamina")==11,"low hunger halves idle recovery")
 var before:=model.snapshot()
 check(not model.rest() and model.snapshot()==before,"hungry rest fails without changing state")
 model.state.vitals.hunger=50;model.state.vitals.health=50;model.state.vitals.stamina=20;model.state.vitals.mood=40
 check(model.rest() and model.value("stamina")==55 and model.value("hunger")==46 and model.value("health")==60,"rest has real recovery and hunger cost")
 model.state.vitals.health=100
 check(model.take_damage(20)==13 and model.value("health")==87,"damage respects defense")
 check(model.take_damage(-1)==0,"negative damage is ignored")
 check(model.take_damage(999,true)==87 and model.value("health")==0,"raw damage stops at zero health")
 model=Life.new();model.discover("apt_2:bedroom")
 var xp: int=model.state.xp
 check(not model.discover("apt_2:bedroom") and model.state.xp==xp,"same room never rewards twice")
 model.gain_xp(60-xp)
 check(model.state.level==2 and model.state.xp==0 and model.attribute("endurance")==6 and model.maximum("health")==104,"level up consumes correct xp and grows caps")
 model.gain_xp(100000)
 check(model.state.level==30 and model.state.xp<model.xp_needed(),"max level has bounded xp")
 model.apply_item("prompt_pen");var saved:=model.snapshot();var copy:=Life.new()
 check(copy.restore(JSON.parse_string(JSON.stringify(saved))) and copy.attribute("insight")==model.attribute("insight"),"JSON roundtrip restores equipment once")
 var copy_before:=copy.snapshot()
 var corrupted:=saved.duplicate(true);corrupted.vitals.health=-1
 check(not copy.restore(corrupted) and copy.snapshot()==copy_before,"bad vital rejects load without partial mutation")
 corrupted=saved.duplicate(true);corrupted.equipment.tool="first_aid"
 check(not copy.restore(corrupted),"non-equipment cannot occupy tool slot")
 corrupted=saved.duplicate(true);corrupted.buffs={"calm":999}
 check(not copy.restore(corrupted),"invalid buff duration is rejected")
 corrupted=saved.duplicate(true);corrupted.base.insight="huge"
 check(not copy.restore(corrupted),"invalid attribute type is rejected")
 print("LIFE MODEL CHECKS ",checks," PASSED ",checks-failures," FAILED ",failures)
 quit(0 if failures==0 else 1)
