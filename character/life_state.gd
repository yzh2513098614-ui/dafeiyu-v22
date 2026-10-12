extends RefCounted
## Model only. Item effects and inventory are committed together by LootController.
var balance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character_balance.json"))
var state: Dictionary={}
var last_message:=""

func _init() -> void:
 state={"version":1,"level":1,"xp":0,"base":balance.initial.duplicate(true),"vitals":{"health":100.0,"stamina":100.0,"hunger":100.0,"mood":100.0},"equipment":{"tool":"","charm":""},"buffs":{},"discovered":{}}
 for id in state.base:state.base[id]=int(state.base[id])
 state.combat={"defeated":{}}

func snapshot() -> Dictionary:return state.duplicate(true)
func value(id: String) -> float:return float(state.vitals.get(id,0.0))
func attribute(id: String) -> int:
 var result:=int(state.base.get(id,0))
 for item in state.equipment.values():result+=int(balance.items.get(item,{}).get("modifiers",{}).get(id,0))
 return result
func maximum(id: String) -> float:
 if id=="health":return 80.0+attribute("endurance")*4.0
 if id=="stamina":
  var result:=56.0+attribute("endurance")*8.0+attribute("strength")
  for item in state.equipment.values():result+=float(balance.items.get(item,{}).get("modifiers",{}).get("max_stamina",0))
  return result
 return 100.0
func xp_needed() -> int:return int(balance.rules.xp_first_level)+(int(state.level)-1)*int(balance.rules.xp_step)
func attack() -> int:return 4+attribute("strength")*2
func defense() -> int:return attribute("endurance")+int(attribute("strength")/2)
func can_sprint() -> bool:return value("stamina")>=float(balance.rules.low_stamina_threshold)
func speed_multiplier(sprint: bool=false) -> float:
 var result:=1.0+(attribute("agility")-4)*.015
 if not can_sprint():result*=float(balance.rules.low_stamina_multiplier)
 elif sprint:result*=float(balance.rules.sprint_multiplier)
 return result
func status_text() -> String:
 if value("health")<=0:return "需要照顾 · 补给或休息可以恢复"
 if value("hunger")<20:return "肚子有点空 · 找些吃的吧"
 if not can_sprint():return "稍有疲惫 · 停下恢复后冲刺"
 if state.buffs.has("calm"):return "暖茶陪伴 · %d 秒"%ceili(float(state.buffs.calm))
 return "状态良好 · 慢慢探索吧"
func _clamp_vitals() -> void:
 for id in state.vitals:state.vitals[id]=clampf(value(id),0.0,maximum(id))
func tick(delta: float,distance: float,sprint: bool) -> void:
 if delta<=0 or not is_finite(delta) or distance<0 or not is_finite(distance):return
 for id in state.buffs.keys():
  state.buffs[id]=maxf(0,float(state.buffs[id])-delta)
  if state.buffs[id]<=0:state.buffs.erase(id)
 state.vitals.hunger=value("hunger")-float(balance.rules.hunger_per_second)*delta
 if distance>.0001:
  state.vitals.stamina=value("stamina")-distance*float(balance.rules.walk_cost_per_meter)-(float(balance.rules.sprint_cost_per_second)*delta if sprint and can_sprint() else 0.0)
 else:
  var recovery:=float(balance.rules.idle_recovery_per_second)+(1.0 if state.buffs.has("calm") else 0.0)
  state.vitals.stamina=value("stamina")+recovery*delta*(.5 if value("hunger")<20 else 1.0)
 _clamp_vitals()
func discover(id: String) -> bool:
 if id=="" or state.discovered.has(id):return false
 state.discovered[id]=true
 gain_xp(int(balance.rules.discovery_xp)+int(attribute("insight")/3))
 return true
func gain_xp(amount: int) -> void:
 if amount<=0:return
 state.xp=int(state.xp)+amount
 while int(state.xp)>=xp_needed() and int(state.level)<int(balance.rules.max_level):
  var old_health:=maximum("health");var old_stamina:=maximum("stamina")
  state.xp=int(state.xp)-xp_needed();state.level=int(state.level)+1
  # 升级加点：耐力、学识每级各 +1（原有），另外四维**轮转**各 +1。
  #
  # 原来只涨耐力/学识。后果都能从本文件的派生公式倒推出来：
  #   attack()   = 4 + 力量*2          → 力量不涨，攻击永远 12
  #   暴击率      = 3% + 幸运*1.2%      → 幸运不涨，永远 6.6%
  #   移速        = 1 + (灵巧-4)*1.5%   → 灵巧不涨，速度不变
  #   休息回心情  = +亲和/3             → 亲和不涨
  # 而且没有任何一件装备加力量（钢笔→学识、罗盘→幸运/灵巧、徽章→亲和、
  # 枕头→体力上限、台灯→学识），所以升级只涨血和防，**打人的数字一辈子不变**。
  # 轮转而不是六项全加：30 级时这四维各约 +7，攻击 12→26 左右，
  # 不会让固定强度的怪物（血 28~85）在十级之后完全没威胁。
  state.base.endurance=int(state.base.endurance)+1
  state.base.insight=int(state.base.insight)+1
  var cycle:Array=["strength","charm","agility","luck"]
  var pick:String=str(cycle[int(state.level)%cycle.size()])
  state.base[pick]=int(state.base[pick])+1
  state.vitals.health=value("health")+maximum("health")-old_health;state.vitals.stamina=value("stamina")+maximum("stamina")-old_stamina
 if int(state.level)==int(balance.rules.max_level):state.xp=mini(int(state.xp),xp_needed()-1)
 _clamp_vitals()
func apply_item(id: String) -> bool:
 var rule: Dictionary=balance.items.get(id,{})
 if rule.is_empty():last_message="这件物品暂时只能查看。";return false
 if rule.action=="equip":
  var slot: String=rule.slot
  state.equipment[slot]="" if state.equipment[slot]==id else id
  _clamp_vitals();last_message=("已卸下：" if state.equipment[slot]=="" else "已装备：")+id;return true
 if rule.action!="consume":last_message=str(rule.summary);return true
 var changed:=false
 for vital in rule.effects:
  if value(vital)<maximum(vital):changed=true
 if rule.has("buff") and float(state.buffs.get(rule.buff,0))<float(rule.duration)-1.0:changed=true
 if not changed:last_message="相关状态已经充足，这次不会消耗物品。";return false
 for vital in rule.effects:state.vitals[vital]=value(vital)+float(rule.effects[vital])
 if rule.has("buff"):state.buffs[rule.buff]=float(rule.duration)
 _clamp_vitals();last_message=str(rule.summary);return true
func rest() -> bool:
 if value("hunger")<20:last_message="先吃一点东西，再好好休息。";return false
 if value("stamina")>=maximum("stamina") and value("health")>=maximum("health") and value("mood")>=100:last_message="现在精神很好，继续漫步吧。";return false
 state.vitals.hunger=value("hunger")-float(balance.rules.rest_hunger_cost)
 state.vitals.stamina=value("stamina")+float(balance.rules.rest_stamina)
 state.vitals.health=value("health")+float(balance.rules.rest_health)
 state.vitals.mood=value("mood")+float(balance.rules.rest_mood)+int(attribute("charm")/3)
 _clamp_vitals();last_message="休息好了：体力 +35，生命 +10，心情恢复；饱食 -4。";return true
func take_damage(amount: float,ignore_defense: bool=false) -> float:
 if amount<=0 or not is_finite(amount):return 0.0
 var damage:=amount if ignore_defense else maxf(1.0,amount-defense())
 var actual:=minf(value("health"),damage);state.vitals.health=value("health")-actual;return actual
func restore(data: Variant) -> bool:
 if not data is Dictionary or data.get("version",0)!=1:return false
 for key in ["base","vitals","equipment","buffs","discovered"]:
  if not data.get(key) is Dictionary:return false
 if not _integer(data.get("level"),1,int(balance.rules.max_level)) or not _integer(data.get("xp"),0,10000):return false
 for id in balance.initial:
  if not _integer(data.base.get(id),1,99):return false
 if data.base.size()!=balance.initial.size() or data.vitals.size()!=4 or data.equipment.size()!=2:return false
 for id in ["health","stamina","hunger","mood"]:
  if not _number(data.vitals.get(id),0,1000):return false
 for slot in ["tool","charm"]:
  var item=data.equipment.get(slot)
  if not item is String:return false
  if item!="" and (not balance.items.has(item) or balance.items[item].get("slot","")!=slot):return false
 for id in data.buffs:
  if id!="calm" or not _number(data.buffs[id],0,90):return false
 if data.discovered.size()>512:return false
 for id in data.discovered:
  if not id is String or id.length()>128 or data.discovered[id]!=true:return false
 var combat=data.get("combat",{"defeated":{}})
 if not combat is Dictionary or not combat.get("defeated") is Dictionary:return false
 for id in combat.defeated:
  if not id in ["slime_a","slime_b","crab_a","gpt6_a","guardian"] or combat.defeated[id]!=true:return false
 var before:=snapshot();state=data.duplicate(true)
 if int(state.xp)>=xp_needed():state=before;return false
 for id in state.vitals:
  if value(id)>maximum(id):state=before;return false
 state.version=1;state.level=int(state.level);state.xp=int(state.xp)
 for id in state.base:state.base[id]=int(state.base[id])
 for id in state.vitals:state.vitals[id]=float(state.vitals[id])
 for id in state.buffs:state.buffs[id]=float(state.buffs[id])
 state.combat=combat.duplicate(true)
 return true
func _number(value: Variant,low: float,high: float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high
func _integer(value: Variant,low: int,high: int) -> bool:
 return _number(value,low,high) and float(value)==floorf(float(value))
