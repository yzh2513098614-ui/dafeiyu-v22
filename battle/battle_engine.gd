extends RefCounted
## 回合制战斗引擎（纯逻辑）
##
## 设计约束：这个文件**不引用任何节点、场景、UI 或 autoload**。
## 原因是战斗规则的正确性必须能被无头脚本直接验证 —— 可以跑上千场自动对局，
## 断言「不会死循环 / 血量不会变负 / 回合数有上限 / 无效指令不消耗回合」，
## 而不需要靠点界面猜。演出和输入全部交给 ui/battle_screen.gd。
##
## 用法：
##   var engine = load("res://battle/battle_engine.gd").new(seed_value)
##   engine.add_ally({...}); engine.add_foe({...})
##   var out = engine.submit({})                                    # 推进到等待玩家输入
##   out = engine.submit({"kind":"skill","id":"wave_touch","target":0})

const DATA_PATH := "res://assets/battle_data.json"

var data: Dictionary = {}
var rules: Dictionary = {}
var skills: Dictionary = {}
var enemy_skills: Dictionary = {}
var enemy_ai: Dictionary = {}
var rng := RandomNumberGenerator.new()

var allies: Array = []
var foes: Array = []
var round_no := 0
var order: Array = []
var slot := 0
var result := ""          ## "" | "win" | "lose" | "fled" | "timeout"
var events: Array = []    ## 本次 submit 产生的行动记录（每次 submit 开头清空，不会无限增长）
## Card battles use a hand/energy turn loop; the older command loop remains
## available to isolated rule tests and non-card callers.
var card_mode := false
var card_catalog: Dictionary = {}
var draw_pile: Array = []
var discard_pile: Array = []
var hand: Array = []
var card_energy := 0
var card_energy_max := 3
var card_hand_size := 5
var card_amplify := 0
var card_intents: Dictionary = {}

func _init(seed_value: int = 0, battle_data: Dictionary = {}) -> void:
	if battle_data.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		data = raw if raw is Dictionary else {}
	else:
		data = battle_data
	rules = data.get("rules", {})
	skills = data.get("skills", {})
	enemy_skills = data.get("enemy_skills", {})
	enemy_ai = data.get("enemies", {})
	rng.seed = seed_value

# ---------------------------------------------------------------- 建人

## 防御减伤的下限比例：**原始伤害的 25%**。
##
## 不加这个下限的话，高等级玩家会变成无敌的。实测（tools/measure_battle_balance.gd）：
##   1 级  防御 7  → 守潮者原始攻 24，实际扣血 17
##   10 级 防御 17 → 实际扣血 7
##   30 级 防御 39 → 实际扣血 **1**（被夹到最低值）
## 而怪物的强度是**固定**的（血 28~85、攻 13~24，见 combat_balance.json），
## 耐力却每级 +1，所以防御迟早会超过所有敌人的攻击力。
## 有了下限，防御仍然有用（24 → 6 是四倍减伤），但永远留一点压力。
##
## 取值从 battle_data.json 的 rules.defense_floor 读，缺省 0.25 ——
## 想调平衡改数据即可，不必改代码（和 rules.ap_max 一样的约定）。
const DEFENSE_FLOOR_DEFAULT := 0.25

func _damage_floor_ratio() -> float:
	return clampf(float(rules.get("defense_floor", DEFENSE_FLOOR_DEFAULT)), 0.0, 1.0)

func _blank(side: String, entry: Dictionary) -> Dictionary:
	return {
		"side": side,
		"id": str(entry.get("id", "")),
		"kind": str(entry.get("kind", "")),
		"name": str(entry.get("name", "?")),
		"level": int(entry.get("level", 1)),
		"hp": float(entry.get("hp", 1.0)),
		"max_hp": maxf(1.0, float(entry.get("max_hp", 1.0))),
		"stamina": float(entry.get("stamina", 0.0)),
		"max_stamina": maxf(1.0, float(entry.get("max_stamina", 1.0))),
		# AP「潮汐连携槽」：每场战斗独立，不进存档 —— 所以 life_state 的白名单不用动。
		# 上限取自 battle_data.json 的 rules.ap_max，想调平衡只改数据不改代码。
		"ap": maxf(0.0, float(entry.get("ap", 0.0))),
		"max_ap": maxf(1.0, float(entry.get("max_ap", rules.get("ap_max", 100.0)))),
		"atk": float(entry.get("atk", 1.0)),
		"def": float(entry.get("def", 0.0)),
		"spd": maxf(0.1, float(entry.get("spd", 1.0))),
		"stats": (entry.get("stats", {}) as Dictionary).duplicate(true),
		"skill_pool": (entry.get("skill_pool", []) as Array).duplicate(),
		"ai": str(entry.get("ai", "random")),
		"shield": 0,
		"block": 0.0,
		"bind": 0,
		"haste": 0,
		"cooldowns": {},
		"turn_speed": 0.0,
		"alive": true,
	}

func add_ally(entry: Dictionary) -> Dictionary:
	var c := _blank("ally", entry)
	allies.append(c)
	return c

func add_foe(entry: Dictionary) -> Dictionary:
	var c := _blank("foe", entry)
	foes.append(c)
	return c

## 从 combat_balance.json 的怪物记录 + battle_data 的 ai 配置生成敌人参数
func foe_entry_from_monster(record: Dictionary, monster: Dictionary) -> Dictionary:
	var kind := str(record.get("type", ""))
	var ai: Dictionary = enemy_ai.get(kind, {})
	return {
		"id": str(record.get("id", kind)),
		"kind": kind,
		"name": str(monster.get("name", kind)),
		"hp": float(monster.get("health", 1)),
		"max_hp": float(monster.get("health", 1)),
		"atk": float(monster.get("attack", 1)),
		"def": float(monster.get("defense", 0)),
		"spd": float(monster.get("speed", 1)) * float(rules.get("enemy_speed_scale", 3.0)),
		"skill_pool": ai.get("skills", ["slam"]),
		"ai": str(ai.get("ai", "random")),
	}

# ---------------------------------------------------------------- 查询（供 UI）

func stat_of(c: Dictionary, key: String) -> float:
	return float((c.get("stats", {}) as Dictionary).get(key, 0.0))

func living(side: String) -> Array:
	var pool: Array = allies if side == "ally" else foes
	var out: Array = []
	for c in pool:
		if bool(c.alive):
			out.append(c)
	return out

func is_over() -> String:
	return result

func unlocked_skills(c: Dictionary) -> Array:
	var out: Array = []
	for id in skills:
		var s: Dictionary = skills[id]
		if int(s.get("unlock_level", 1)) <= int(c.get("level", 1)):
			out.append(str(id))
	out.sort()
	return out

## 某个技能此刻能不能用；返回 {ready, reason}
func skill_status(c: Dictionary, id: String) -> Dictionary:
	if not skills.has(id):
		return {"ready": false, "reason": "没有这个技能"}
	var s: Dictionary = skills[id]
	if int(s.get("unlock_level", 1)) > int(c.get("level", 1)):
		return {"ready": false, "reason": "等级不足"}
	var cd := int((c.cooldowns as Dictionary).get(id, 0))
	if cd > 0:
		return {"ready": false, "reason": "冷却 %d 回合" % cd}
	if float(c.stamina) < float(s.get("cost", 0)):
		return {"ready": false, "reason": "体力不足"}
	return {"ready": true, "reason": ""}

## 玩家可选的技能列表（含不可用的，UI 好置灰并显示原因）
func ally_skill_menu(c: Dictionary) -> Array:
	var out: Array = []
	for id in unlocked_skills(c):
		var s: Dictionary = skills[id]
		var st := skill_status(c, id)
		out.append({
			"id": id,
			"name": str(s.get("name", id)),
			"desc": str(s.get("desc", "")),
			"cost": int(s.get("cost", 0)),
			"kind": str(s.get("kind", "damage")),
			"target": str(s.get("target", "one")),
			"ready": bool(st.ready),
			"reason": str(st.reason),
		})
	return out

## 潮汐连携（AP 大招）此刻能不能放；和技能菜单同构，UI 好统一处理「灰掉 + 原因」
func link_status(c: Dictionary) -> Dictionary:
	var cfg: Dictionary = data.get("link", {})
	var cap := maxf(1.0, float(c.max_ap))
	var ap := float(c.ap)
	var ready := ap >= cap
	return {
		"id": "link",
		"name": str(cfg.get("name", "潮汐连携")),
		"desc": str(cfg.get("desc", "")),
		"cost": int(cap),
		"ready": ready,
		"reason": "" if ready else "AP 未蓄满（%d / %d）" % [int(ap), int(cap)],
		"ap": ap,
		"max_ap": cap,
	}

func snapshot() -> Dictionary:
	return {"round": round_no, "result": result, "allies": allies.duplicate(true), "foes": foes.duplicate(true)}

func checkpoint() -> Dictionary:
	var sequence: Array = []
	for actor in order: sequence.append({"side": actor.side, "id": actor.id})
	return {"allies": allies.duplicate(true), "foes": foes.duplicate(true), "round": round_no,
		"slot": slot, "result": result, "events": events.duplicate(true), "order": sequence,
		"seed": rng.seed, "rng_state": rng.state, "card_mode": card_mode,
		"draw_pile": draw_pile.duplicate(), "discard_pile": discard_pile.duplicate(),
		"hand": hand.duplicate(), "card_energy": card_energy,
		"card_amplify": card_amplify, "card_intents": card_intents.duplicate(true)}

func restore_checkpoint(saved: Dictionary) -> void:
	allies = saved.allies.duplicate(true); foes = saved.foes.duplicate(true)
	round_no = int(saved.round); slot = int(saved.slot); result = str(saved.result)
	events = saved.events.duplicate(true); rng.seed = saved.seed; rng.state = saved.rng_state
	card_mode = bool(saved.get("card_mode", false))
	draw_pile = (saved.get("draw_pile", []) as Array).duplicate()
	discard_pile = (saved.get("discard_pile", []) as Array).duplicate()
	hand = (saved.get("hand", []) as Array).duplicate()
	card_energy = int(saved.get("card_energy", 0))
	card_amplify = int(saved.get("card_amplify", 0))
	card_intents = (saved.get("card_intents", {}) as Dictionary).duplicate(true)
	order.clear()
	for key in saved.order:
		for actor in (allies if key.side == "ally" else foes):
			if actor.id == key.id: order.append(actor); break

# ---------------------------------------------------------------- 伤害

func _roll(actor: Dictionary, power: float, stat_key: String, stat_scale: float, target_def: float) -> Dictionary:
	var base := float(actor.atk) * power
	if stat_key != "":
		base += stat_of(actor, stat_key) * stat_scale
	var variance := 1.0 + rng.randf_range(-float(rules.damage_variance), float(rules.damage_variance))
	var crit := rng.randf() < (float(rules.crit_base) + stat_of(actor, "luck") * float(rules.crit_per_luck))
	var raw := base * variance
	if crit:
		raw *= float(rules.crit_multiplier)
	# 减防但留下限：见 _damage_floor_ratio() 上面那段实测说明
	var after := maxf(raw - target_def, raw * _damage_floor_ratio())
	return {"damage": maxf(1.0, after), "crit": crit}

## 攒 AP。只有我方单位有槽；foes 调用直接返回 0。
## 只有「刚好蓄满」这一件事会发事件 —— 每次平A都发一条会把演出拖成幻灯片，
## 而且日志会被 +12 刷屏；平常的攒槽看界面上的条就够了。
func _gain_ap(c: Dictionary, amount: float, reason: String) -> float:
	if c.side != "ally" or amount <= 0.0:
		return 0.0
	var cap := maxf(1.0, float(c.max_ap))
	var before := float(c.ap)
	c.ap = minf(cap, before + amount)
	var delta := float(c.ap) - before
	if delta > 0.0 and before < cap and float(c.ap) >= cap:
		_event("ap_full", c, c, float(c.ap), "%s 的潮汐连携已就绪" % c.name,
			{"reason": reason, "ap": float(c.ap), "max_ap": cap})
	return delta

func _damage(target: Dictionary, amount: float, source: Variant = null) -> float:
	var dmg := amount
	if int(target.shield) > 0:
		dmg *= 1.0 - float(rules.shield_reduction)
	var blocked := minf(dmg, float(target.get("block", 0.0)))
	if blocked > 0.0:
		target.block = float(target.block) - blocked
		dmg -= blocked
	dmg = maxf(0.0, minf(float(target.hp), dmg))
	target.hp = float(target.hp) - dmg
	if float(target.hp) <= 0.0:
		target.hp = 0.0
		target.alive = false
	# 攒槽放在这里而不是各个技能分支里：我方打人和挨打的入口最终都会走到这个函数，
	# 以后再加技能也不用记得补 AP 结算。
	# source 为 null 表示「这一下不算我方出手」（潮汐连携自己），见 _use_link。
	if source != null and source is Dictionary and source.side == "ally" and target.side == "foe":
		_gain_ap(source, float(rules.get("ap_gain_deal", 12.0)), "deal")
	if target.side == "ally":
		_gain_ap(target, float(rules.get("ap_gain_take", 9.0)), "take")
	return dmg

func _heal(target: Dictionary, amount: float) -> float:
	var before := float(target.hp)
	target.hp = minf(float(target.max_hp), before + amount)
	return float(target.hp) - before

# ---------------------------------------------------------------- 行动

func _event(kind: String, actor: Variant, target: Variant, amount: float = 0.0, text: String = "", extra: Dictionary = {}) -> Dictionary:
	var e := {
		"type": kind,
		"actor": str(actor.name) if actor is Dictionary else "",
		"actor_side": str(actor.side) if actor is Dictionary else "",
		"target": str(target.name) if target is Dictionary else "",
		"amount": amount,
		"text": text,
		"actor_id": str(actor.id) if actor is Dictionary else "",
		"target_id": str(target.id) if target is Dictionary else "",
		"actor_state": presentation_state(actor),
		"target_state": presentation_state(target),
	}
	e.merge(extra, true)
	if kind=="round":
		var views:Array=[]
		for member in allies+foes:views.append(presentation_state(member))
		e["round_states"]=views
	events.append(e)
	return e

## Immutable display data captured at the event, separate from final turn settlement.
static func presentation_state(actor:Variant)->Dictionary:
	var view:Dictionary={}
	if not actor is Dictionary:return view
	for key in ["id","side","hp","max_hp","stamina","max_stamina","ap","max_ap","block","shield","haste","bind","alive"]:
		if actor.has(key):view[key]=actor[key]
	return view

func _foe_pool_for(actor: Dictionary) -> Array:
	return living("foe") if actor.side == "ally" else living("ally")

func _pick_targets(actor: Dictionary, scope: String, index: int) -> Array:
	if scope == "self":
		return [actor]
	var pool := _foe_pool_for(actor)
	if pool.is_empty():
		return []
	if scope == "all":
		return pool
	var i := index
	if i < 0 or i >= pool.size():
		i = 0
	return [pool[i]]

func _check_down(t: Dictionary) -> void:
	if not bool(t.alive):
		_event("down", t, t, 0.0, "%s 倒下了" % t.name)

## 执行一次行动，返回本次产生的事件数组
func perform(actor: Dictionary, action: Dictionary) -> Array:
	var mark := events.size()
	if not bool(actor.alive):
		return []
	var kind := str(action.get("kind", "attack"))
	if kind == "attack":
		for t in _pick_targets(actor, "one", int(action.get("target", 0))):
			var roll := _roll(actor, 1.0, "", 0.0, float(t.def))
			var dmg := _damage(t, float(roll.damage), actor)
			_event("damage", actor, t, dmg, "%s 攻击 %s" % [actor.name, t.name], {"crit": roll.crit})
			_check_down(t)
	elif kind == "link":
		_use_link(actor)
	elif kind == "flee":
		var chance := float(rules.flee_base) + stat_of(actor, "agility") * float(rules.flee_per_agility)
		if rng.randf() < chance:
			result = "fled"
			_event("flee", actor, null, 0.0, "%s 成功脱身" % actor.name)
		else:
			_event("flee_fail", actor, null, 0.0, "%s 没能脱身" % actor.name)
	elif kind == "skill":
		_use_skill(actor, str(action.get("id", "")), action)
	elif kind == "item":
		_use_item(actor, action)
	else:
		_event("invalid", actor, null, 0.0, "无效指令")
	return events.slice(mark)

## 战斗中使用道具。
## 架构上刻意的分工：引擎不知道背包存在，效果由界面层算好传进 action.effects，
## 引擎只负责把效果算进**战斗内**数值并让这一手消耗回合。
## 背包的扣减由控制层在「引擎确认执行之后」再做（见 battle_screen._submit_action），
## 这样被拒的指令不会白扣一个道具。
func _use_item(actor: Dictionary, action: Dictionary) -> void:
	if not bool(actor.alive):
		return
	var effects: Dictionary = action.get("effects", {})
	var label := str(action.get("label", action.get("id", "道具")))
	var healed := 0.0
	if effects.has("health"):
		var amount := float(effects["health"])
		if amount > 0.0:
			healed = _heal(actor, amount)
	if effects.has("stamina"):
		var amount := float(effects["stamina"])
		if amount > 0.0:
			actor.stamina = minf(float(actor.max_stamina), float(actor.stamina) + amount)
	# 只发一条 item 事件，不发 heal —— 战报读起来是「大肥鱼 使用了 急救包」一句话
	_event("item", actor, actor, healed, "%s 使用了 %s" % [actor.name, label],
		{"item": str(action.get("id", ""))})

func _use_skill(actor: Dictionary, id: String, action: Dictionary) -> void:
	var is_ally: bool = actor.side == "ally"
	var s: Dictionary = (skills if is_ally else enemy_skills).get(id, {})
	if s.is_empty():
		_event("invalid", actor, null, 0.0, "%s 无法使用该技能" % actor.name)
		return
	if is_ally:
		var st := skill_status(actor, id)
		if not bool(st.ready):
			_event("invalid", actor, null, 0.0, str(st.reason))
			return
		actor.stamina = maxf(0.0, float(actor.stamina) - float(s.get("cost", 0)))
		var cd := int(s.get("cooldown", 0))
		if cd > 0:
			(actor.cooldowns as Dictionary)[id] = cd

	var kind := str(s.get("kind", "damage"))
	var label := str(s.get("name", id))
	if kind == "damage":
		for t in _pick_targets(actor, str(s.get("target", "one")), int(action.get("target", 0))):
			var roll := _roll(actor, float(s.get("power", 1.0)), str(s.get("stat", "")), float(s.get("stat_scale", 0.0)), float(t.def))
			var dmg := _damage(t, float(roll.damage), actor)
			_event("damage", actor, t, dmg, "%s 使出 %s" % [actor.name, label], {"crit": roll.crit, "skill": id})
			_check_down(t)
	elif kind == "heal":
		var amount := float(s.get("power", 0.0)) + stat_of(actor, str(s.get("stat", ""))) * float(s.get("stat_scale", 0.0))
		_event("heal", actor, actor, _heal(actor, amount), "%s 使出 %s" % [actor.name, label], {"skill": id})
	elif kind == "shield":
		actor.shield = int(s.get("turns", 1))
		_event("status", actor, actor, 0.0, "%s 使出 %s" % [actor.name, label], {"status": "shield", "turns": actor.shield, "skill": id})
	elif kind == "bind":
		for t in _pick_targets(actor, "one", int(action.get("target", 0))):
			t.bind = int(s.get("turns", 1))
			_event("status", actor, t, 0.0, "%s 使出 %s" % [actor.name, label], {"status": "bind", "turns": t.bind, "skill": id})
	elif kind == "haste":
		actor.haste = int(s.get("turns", 1))
		_event("status", actor, actor, 0.0, "%s 使出 %s" % [actor.name, label], {"status": "haste", "turns": actor.haste, "skill": id})

## 潮汐连携：清空整条 AP，对全体敌人打一发重的。
## 注意这里 _damage 故意不传 source —— 大招自己的伤害不回填 AP，
## 否则「花 100 立刻回 12」会让槽看起来没清空，读条反馈是错的。
func _use_link(actor: Dictionary) -> void:
	var cfg: Dictionary = data.get("link", {})
	if not bool(link_status(actor).ready):
		_event("invalid", actor, null, 0.0, "AP 还没蓄满")
		return
	actor.ap = 0.0
	var label := str(cfg.get("name", "潮汐连携"))
	_event("link", actor, null, 0.0, "%s 发动 %s！" % [actor.name, label], {"skill": "link"})
	for t in _pick_targets(actor, "all", 0):
		var roll := _roll(actor, float(cfg.get("power", 1.6)), str(cfg.get("stat", "insight")), float(cfg.get("stat_scale", 3.0)), float(t.def))
		var dmg := _damage(t, float(roll.damage))
		_event("damage", actor, t, dmg, "%s → %s" % [label, t.name], {"crit": roll.crit, "skill": "link"})
		_check_down(t)

# ---------------------------------------------------------------- 回合推进

## 抖动后的速度每回合只算一次并缓存 —— 比较器里不能摇随机数，否则排序不可靠
func _roll_speed(c: Dictionary) -> float:
	var s := float(c.spd)
	if int(c.haste) > 0:
		s *= 1.8
	return s * (1.0 + rng.randf_range(-float(rules.speed_jitter), float(rules.speed_jitter)))

func _speed_first(a: Dictionary, b: Dictionary) -> bool:
	return float(a.turn_speed) > float(b.turn_speed)

func _begin_round() -> void:
	round_no += 1
	order.clear()
	for c in allies + foes:
		if bool(c.alive):
			c.turn_speed = _roll_speed(c)
			order.append(c)
	order.sort_custom(_speed_first)
	slot = 0
	_event("round", null, null, 0.0, "第 %d 回合" % round_no, {"round": round_no})

## 回合结束时才递减状态与冷却，并把体力回一点。
## 放在回合开始递减会让「2 回合护盾」实际只挡 1 回合。
func _end_round() -> void:
	for c in allies + foes:
		if not bool(c.alive):
			continue
		if int(c.shield) > 0:
			c.shield = int(c.shield) - 1
		if int(c.haste) > 0:
			c.haste = int(c.haste) - 1
		var cds: Dictionary = c.cooldowns
		for id in cds.keys():
			cds[id] = maxi(0, int(cds[id]) - 1)
		if c.side == "ally" and float(c.stamina) < float(c.max_stamina):
			c.stamina = minf(float(c.max_stamina), float(c.stamina) + float(rules.stamina_regen_per_round))
		# 每回合的被动攒槽：就算一直防御也会慢慢攒满，保证槽不会是死资源
		_gain_ap(c, float(rules.get("ap_gain_round", 5.0)), "round")

## 敌人选招：random 均匀随机；boss 在玩家半血以下优先重击
func _choose_enemy_action(c: Dictionary) -> Dictionary:
	var pool: Array = c.get("skill_pool", [])
	if pool.is_empty():
		return {"kind": "attack"}
	var pick := str(pool[rng.randi_range(0, pool.size() - 1)])
	if str(c.ai) == "boss":
		var targets := living("ally")
		if not targets.is_empty() and float(targets[0].hp) / maxf(1.0, float(targets[0].max_hp)) < 0.5:
			for id in pool:
				if str(id) == "tide_crush":
					pick = "tide_crush"
					break
	return {"kind": "skill", "id": pick, "target": 0}

func _finish_if_over() -> bool:
	if living("foe").is_empty():
		result = "win"
		return true
	if living("ally").is_empty():
		result = "lose"
		return true
	if round_no > int(rules.max_rounds):
		result = "timeout"
		return true
	return false

## 玩家这一手是否合法（不合法就不该消耗回合，让玩家重选）
func action_is_legal(actor: Dictionary, action: Dictionary) -> bool:
	var kind := str(action.get("kind", "attack"))
	if kind == "attack" or kind == "flee":
		return true
	if kind == "skill":
		return bool(skill_status(actor, str(action.get("id", ""))).ready)
	if kind == "link":
		return bool(link_status(actor).ready)
	if kind == "item":
		# 效果由界面层从 character_balance.json 算好放进 action.effects 传进来 ——
		# 引擎不读背包（那是控制层的事），所以这里只检查「带了 id 且有非空效果」。
		var effects: Variant = action.get("effects")
		return str(action.get("id", "")) != "" and effects is Dictionary and not (effects as Dictionary).is_empty()
	return false

## 推进到「等待玩家输入」或战斗结束。
## action 为空 = 只推进（开场用）；给出 action = 先执行玩家这一手再推进。
func submit(action: Dictionary = {}) -> Dictionary:
	if card_mode:
		return _submit_card_action(action)
	events.clear()
	if result != "":
		return {"events": [], "awaiting": "", "result": result}
	if order.is_empty():
		_begin_round()

	if not action.is_empty():
		var me: Array = living("ally")
		if me.is_empty():
			result = "lose"
			return {"events": events.duplicate(), "awaiting": "", "result": result}
		if not action_is_legal(me[0], action):
			_event("invalid", me[0], null, 0.0, "这一步现在不能用")
			return {"events": events.duplicate(), "awaiting": "ally", "result": ""}
		perform(me[0], action)
		slot += 1
		if _finish_if_over():
			return {"events": events.duplicate(), "awaiting": "", "result": result}

	var guard := 0
	while result == "" and guard < 400:
		guard += 1
		if slot >= order.size():
			_end_round()
			if _finish_if_over():
				break
			_begin_round()
			continue
		var actor: Dictionary = order[slot]
		if not bool(actor.alive):
			slot += 1
			continue
		if int(actor.bind) > 0:
			actor.bind = int(actor.bind) - 1
			_event("bound", actor, null, 0.0, "%s 被困住了，无法行动" % actor.name)
			slot += 1
			continue
		if actor.side == "ally":
			break
		perform(actor, _choose_enemy_action(actor))
		slot += 1
		if _finish_if_over():
			break
	if guard >= 400:
		result = "timeout"
		_event("timeout", null, null, 0.0, "战斗陷入僵局，自动撤退")

	return {"events": events.duplicate(), "awaiting": "ally" if result == "" else "", "result": result}


# ---------------------------------------------------------------- 手牌战斗

func enable_cards(cards: Array) -> void:
	card_catalog.clear()
	draw_pile.clear(); discard_pile.clear(); hand.clear()
	card_energy = 0; card_amplify = 0; card_intents.clear()
	for entry in cards:
		if not entry is Dictionary: continue
		var id := str(entry.get("id", ""))
		if id == "" or card_catalog.has(id): continue
		card_catalog[id] = entry.duplicate(true)
		draw_pile.append(id)
	card_mode = not draw_pile.is_empty()
	_shuffle_cards(draw_pile)

func _shuffle_cards(pile: Array) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = pile[i]; pile[i] = pile[j]; pile[j] = swap

func _draw_cards(count: int) -> int:
	var drawn := 0
	for _n in count:
		if hand.size() >= 10: break
		if draw_pile.is_empty():
			if discard_pile.is_empty(): break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle_cards(draw_pile)
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn

func card_hand_view() -> Array:
	var out: Array = []
	for i in hand.size():
		var card: Dictionary = card_catalog.get(str(hand[i]), {}).duplicate(true)
		card["index"] = i
		card["ready"] = card_energy >= int(card.get("cost", 0))
		out.append(card)
	return out

func intent_for(foe: Dictionary) -> Dictionary:
	return card_intents.get(str(foe.id), {})

func _begin_card_turn() -> void:
	round_no += 1
	for actor in allies:
		actor.block = 0.0
	card_amplify = 0
	card_energy = card_energy_max
	var drawn := _draw_cards(card_hand_size)
	card_intents.clear()
	for foe in living("foe"):
		card_intents[str(foe.id)] = _choose_enemy_action(foe)
	_event("round", null, null, 0.0, "第 %d 回合 · 抽 %d 张牌" % [round_no, drawn], {"round": round_no})

func _end_card_turn() -> void:
	discard_pile.append_array(hand)
	hand.clear()
	card_energy = 0
	_event("turn_end", allies[0] if not allies.is_empty() else null, null, 0.0, "结束回合")
	for foe in living("foe"):
		if int(foe.bind) > 0:
			foe.bind = int(foe.bind) - 1
			_event("bound", foe, null, 0.0, "%s 被束缚，无法行动" % foe.name)
			continue
		perform(foe, intent_for(foe))
		if _finish_if_over(): return
	_end_round()
	if _finish_if_over(): return
	_begin_card_turn()

func _card_effect(actor: Dictionary, card: Dictionary, effect: Dictionary, target_index: int) -> void:
	var kind := str(effect.get("kind", ""))
	var value := int(effect.get("value", 0))
	var label := str(card.get("name", card.get("id", "卡牌")))
	match kind:
		"damage":
			for target in _pick_targets(actor, str(card.get("target", "one")), target_index):
				var raw_amount := float(value) + float(actor.atk) * 0.25 + float(card_amplify)
				# 和 _roll 一样留减防下限，理由见 _damage_floor_ratio()
				var amount := maxf(1.0, maxf(raw_amount - float(target.def), raw_amount * _damage_floor_ratio()))
				var dealt := _damage(target, amount, actor)
				_event("damage", actor, target, dealt, "%s 打出 %s" % [actor.name, label], {"skill": str(card.id), "card": true})
				_check_down(target)
			card_amplify = 0
		"block":
			actor.block = float(actor.block) + float(value)
			_event("status", actor, actor, float(value), "%s 获得 %d 点格挡" % [actor.name, value], {"status": "block", "skill": str(card.id)})
		"heal":
			_event("heal", actor, actor, _heal(actor, float(value)), "%s 打出 %s" % [actor.name, label], {"skill": str(card.id)})
		"bind":
			for target in _pick_targets(actor, "one", target_index):
				target.bind = maxi(int(target.bind), value)
				_event("status", actor, target, 0.0, "%s 束缚了 %s" % [actor.name, target.name], {"status": "bind", "turns": value, "skill": str(card.id)})
		"draw":
			var actual := _draw_cards(value)
			_event("draw", actor, actor, float(actual), "抽取 %d 张牌" % actual)
		"energy":
			card_energy = mini(5, card_energy + value)
			_event("energy", actor, actor, float(value), "获得 %d 点能量" % value)
		"stamina":
			actor.stamina = minf(float(actor.max_stamina), float(actor.stamina) + float(value))
			_event("status", actor, actor, float(value), "恢复 %d 点体力" % value)
		"amplify":
			card_amplify = mini(30, card_amplify + value)
			_event("status", actor, actor, float(value), "下一次伤害 +%d" % value)
		"cleanse":
			actor.bind = 0
			_event("status", actor, actor, 0.0, "解除了束缚")
		"retrieve":
			var actual := 0
			for _n in value:
				if discard_pile.is_empty() or hand.size() >= 10: break
				hand.append(discard_pile.pop_back()); actual += 1
			_event("draw", actor, actor, float(actual), "取回 %d 张弃牌" % actual)

func _submit_card_action(action: Dictionary) -> Dictionary:
	events.clear()
	if result != "": return {"events": [], "awaiting": "", "result": result}
	if round_no == 0: _begin_card_turn()
	if not action.is_empty():
		var actor: Dictionary = allies[0]
		var kind := str(action.get("kind", ""))
		if kind == "card":
			var index := int(action.get("index", -1))
			if index < 0 or index >= hand.size():
				_event("invalid", actor, null, 0.0, "这张牌已不在手中")
			else:
				var id := str(hand[index])
				var card: Dictionary = card_catalog.get(id, {})
				var cost := int(card.get("cost", 0))
				if card_energy < cost:
					_event("invalid", actor, null, 0.0, "能量不足")
				else:
					card_energy -= cost
					hand.remove_at(index)
					_event("card", actor, null, float(cost), "打出 %s" % str(card.get("name", id)), {"card_id": id})
					for effect in card.get("effects", []):
						_card_effect(actor, card, effect, int(action.get("target", 0)))
					discard_pile.append(id)
					_finish_if_over()
		elif kind == "end_turn":
			_end_card_turn()
		elif kind in ["item", "link", "flee"]:
			if not action_is_legal(actor, action):
				_event("invalid", actor, null, 0.0, "这一步现在不能用")
			else:
				perform(actor, action)
				if result == "" and kind == "flee": _end_card_turn()
				else: _finish_if_over()
		else:
			_event("invalid", actor, null, 0.0, "请选择手牌或结束回合")
	return {"events": events.duplicate(), "awaiting": "ally" if result == "" else "", "result": result}
