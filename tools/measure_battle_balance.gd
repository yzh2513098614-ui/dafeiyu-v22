extends SceneTree
## 战斗数值体检。跑法：
##   godot --headless --path <工程目录> --script res://tools/measure_battle_balance.gd
##
## 为什么要这个工具：数值问题光读代码会判断错。我在笔记里记过「平A 只有 3%、
## 技能 90%」，实际一量才发现那是**过期结论**（代码里 atk 早就接了 model.attack()）。
## 所以这里一律用**真引擎**打一遍看事件里的实际伤害，不做纸面推算。
##
## 附带回答另一个问题：升级到底涨了什么。
## 改之前只涨耐力/学识，导致力量不涨 → attack() 恒为 12、幸运不涨 → 暴击恒 6.6%。

const EngineScript = preload("res://battle/battle_engine.gd")
const LifeState = preload("res://character/life_state.gd")
const BATTLE_DATA := "res://assets/battle_data.json"
const COMBAT_BALANCE := "res://assets/combat_balance.json"
const CARD_CATALOG := "res://assets/cards/catalog.json"

var battle_data: Dictionary = {}
var balance: Dictionary = {}
var catalog: Array = []

func _initialize() -> void:
	call_deferred("run")

func _load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

## 用真引擎打一次平A，返回实际伤害
func _basic_attack_damage(m, kind: String) -> float:
	var monster: Dictionary = balance.monsters.get(kind, {})
	if monster.is_empty():
		return -1.0
	var engine = EngineScript.new(20261003, battle_data)
	engine.add_ally({
		"id": "player", "name": "大肥鱼", "level": int(m.state.level),
		"hp": m.maximum("health"), "max_hp": m.maximum("health"),
		"atk": float(m.attack()), "def": float(m.defense()),
		"spd": float(m.attribute("agility")), "stats": _stats(m),
	})
	engine.add_foe(engine.foe_entry_from_monster({"id": "probe", "type": kind}, monster))
	var events: Array = engine.perform(engine.allies[0], {"kind": "attack", "target": 0})
	for e in events:
		# 事件字段名是 "type" 不是 "kind"（见 battle_engine._event）——
		# 我第一版写错成 kind，结果整列平A 伤害都读成 0。
		if str(e.get("type", "")) == "damage":
			return float(e.get("amount", 0.0))
	return 0.0

## 用真引擎让**怪物打玩家**，返回实际扣血。
## 不能用「raw - defense()」自己算 —— 那条路绕过了引擎里的减防下限，
## 第一版就是这么写的，结果 30 级显示扣 1 点，看不出下限到底有没有生效。
func _enemy_hit_damage(m, kind: String) -> float:
	var monster: Dictionary = balance.monsters.get(kind, {})
	if monster.is_empty():
		return -1.0
	var engine = EngineScript.new(20261004, battle_data)
	engine.add_ally({
		"id": "player", "name": "大肥鱼", "level": int(m.state.level),
		"hp": m.maximum("health"), "max_hp": m.maximum("health"),
		"atk": float(m.attack()), "def": float(m.defense()),
		"spd": float(m.attribute("agility")), "stats": _stats(m),
	})
	engine.add_foe(engine.foe_entry_from_monster({"id": "probe", "type": kind}, monster))
	# 怪物动手：foe 的 _pick_targets 池子就是 allies
	var events: Array = engine.perform(engine.foes[0], {"kind": "attack", "target": 0})
	for e in events:
		if str(e.get("type", "")) == "damage":
			return float(e.get("amount", 0.0))
	return 0.0

func _stats(m) -> Dictionary:
	var out: Dictionary = {}
	for key in ["strength", "endurance", "insight", "charm", "agility", "luck"]:
		out[key] = m.attribute(key)
	return out

## 卡牌伤害按 battle_engine._card_effect 的公式算（那一步要手牌状态，这里只算数值）
func _card_damage(m, value: int, target_def: float) -> float:
	return maxf(1.0, float(value) + float(m.attack()) * 0.25 - target_def)

## 42 张卡里 damage 类的最大值
func _top_card_value() -> int:
	var top := 0
	for card in catalog:
		for e in card.get("effects", []):
			if str(e.get("kind", "")) == "damage":
				top = maxi(top, int(e.get("value", 0)))
	return top

func run() -> void:
	battle_data = _load_json(BATTLE_DATA)
	balance = _load_json(COMBAT_BALANCE)
	var cat: Variant = _load_json(CARD_CATALOG)
	if cat is Array:
		catalog = cat
	print("=== 敌人（固定强度，不随玩家等级变）===")
	for kind in balance.monsters:
		var mo: Dictionary = balance.monsters[kind]
		print("  %-10s %-10s 血 %-4d 攻 %-3d 防 %-3d" % [kind, str(mo.get("name", "")),
			int(mo.get("health", 0)), int(mo.get("attack", 0)), int(mo.get("defense", 0))])
	var top := _top_card_value()
	print("\n=== 属性成长（1 / 10 / 30 级）===")
	print("  等级  力量 耐力 学识 亲和 灵巧 幸运 | 攻击 防御 生命上限 暴击率")
	var rows: Array = []
	for target in [1, 10, 30]:
		var m = LifeState.new()
		var guard := 0
		while int(m.state.level) < target and guard < 200:
			m.gain_xp(int(m.xp_needed()))
			guard += 1
		var crit := float(battle_data.rules.crit_base) + float(m.attribute("luck")) * float(battle_data.rules.crit_per_luck)
		print("  %-5d %-4d %-4d %-4d %-4d %-4d %-4d | %-4d %-4d %-8d %.1f%%" % [
			int(m.state.level), m.attribute("strength"), m.attribute("endurance"), m.attribute("insight"),
			m.attribute("charm"), m.attribute("agility"), m.attribute("luck"),
			m.attack(), m.defense(), int(m.maximum("health")), crit * 100.0])
		rows.append(m)
	print("\n=== 平A 实际伤害（真引擎打出来的）占怪物血量比 ===")
	print("  等级  " + "  ".join(PackedStringArray(balance.monsters.keys())))
	for i in rows.size():
		var m = rows[i]
		var parts: Array = []
		for kind in balance.monsters:
			var mo: Dictionary = balance.monsters[kind]
			var hp := float(mo.get("health", 1))
			var dmg := _basic_attack_damage(m, str(kind))
			parts.append("%s %.0f(%.0f%%)" % [str(kind).substr(0, 3), dmg, dmg / hp * 100.0])
		print("  %-5d  %s" % [int(m.state.level), "  ".join(PackedStringArray(parts))])
	print("\n=== 最强伤害卡（value=%d）一击占血量比 ===" % top)
	for i in rows.size():
		var m = rows[i]
		var parts: Array = []
		for kind in balance.monsters:
			var mo: Dictionary = balance.monsters[kind]
			var hp := float(mo.get("health", 1))
			var dmg := _card_damage(m, top, float(mo.get("defense", 0)))
			parts.append("%s %.0f(%.0f%%)" % [str(kind).substr(0, 3), dmg, dmg / hp * 100.0])
		print("  %-5d  %s" % [int(m.state.level), "  ".join(PackedStringArray(parts))])
	print("\n=== 玩家挨打（真引擎：怪物打玩家）===")
	print("  等级  guardian 原始攻 24        gpt6 原始攻 21        玩家生命")
	for i in rows.size():
		var m = rows[i]
		var g_hit := _enemy_hit_damage(m, "guardian")
		var x_hit := _enemy_hit_damage(m, "gpt6")
		print("  %-5d  实际扣血 %-5.0f (%d 下倒)   实际扣血 %-5.0f (%d 下倒)   %.0f" % [
			int(m.state.level), g_hit, int(ceilf(m.maximum("health") / maxf(1.0, g_hit))),
			x_hit, int(ceilf(m.maximum("health") / maxf(1.0, x_hit))), m.maximum("health")])
	quit()
