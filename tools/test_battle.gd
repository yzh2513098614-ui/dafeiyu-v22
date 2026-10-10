extends RefCounted
## 回合制战斗引擎的无头验证
##
## 用法（在运行中的项目里）：
##   load("res://tools/test_battle.gd").new().run(500)
##
## 它跑大量自动对局并断言「规则不变量」，而不是看输出好不好看：
##   · 战斗一定会结束（不会死循环），回合数不超过上限
##   · 生命/体力永远不为负、不超上限
##   · 无效指令（没解锁 / 体力不足 / 冷却中）不消耗回合
##   · 护盾真的减半、束缚真的跳过一回合
##   · 敌人 id 与存档白名单一致（否则旧档会被 restore() 拒绝）

const BattleEngine = preload("res://battle/battle_engine.gd")
const BALANCE_PATH := "res://assets/combat_balance.json"
const BATTLE_PATH := "res://assets/battle_data.json"
const CHARACTER_PATH := "res://assets/character_balance.json"

## 存档校验里 combat.defeated 只允许这几个键（见 character/life_state.gd:restore）
const SAVE_ALLOWED_IDS: Array = ["slime_a", "slime_b", "crab_a", "gpt6_a", "guardian"]

func _load_json(path: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return raw if raw is Dictionary else {}

## 从 character_balance 初始属性 + 现有派生公式造一个我方单位
func _ally(level: int = 1) -> Dictionary:
	var cb := _load_json(CHARACTER_PATH)
	var base: Dictionary = cb.get("initial", {})
	var strength := float(base.get("strength", 4))
	var endurance := float(base.get("endurance", 5))
	var agility := float(base.get("agility", 4))
	# 与 life_state.gd 完全一致的派生口径，避免测试和实机两套算法
	var atk := 4.0 + strength * 2.0
	var defense := endurance + floorf(strength / 2.0)
	var max_hp := 80.0 + endurance * 4.0
	var max_stamina := 56.0 + endurance * 8.0 + strength
	return {
		"id": "player", "name": "大肥鱼", "level": level,
		"hp": max_hp, "max_hp": max_hp,
		"stamina": max_stamina, "max_stamina": max_stamina,
		"atk": atk, "def": defense, "spd": agility,
		"stats": base.duplicate(true),
	}

func _make_engine(seed_value: int, foe_kinds: Array, level: int = 1) -> Variant:
	var engine = BattleEngine.new(seed_value)
	var bal := _load_json(BALANCE_PATH)
	var monsters: Dictionary = bal.get("monsters", {})
	engine.add_ally(_ally(level))
	for i in foe_kinds.size():
		var kind := str(foe_kinds[i])
		var record := {"id": SAVE_ALLOWED_IDS[i] if i < SAVE_ALLOWED_IDS.size() else "extra_%d" % i, "type": kind}
		engine.add_foe(engine.foe_entry_from_monster(record, monsters.get(kind, {})))
	return engine

func _pick_action(engine, me: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var menu: Array = engine.ally_skill_menu(me)
	var ready: Array = []
	for entry in menu:
		if bool(entry.ready):
			ready.append(entry)
	if not ready.is_empty() and rng.randf() < 0.7:
		var pick: Dictionary = ready[rng.randi_range(0, ready.size() - 1)]
		return {"kind": "skill", "id": str(pick.id), "target": rng.randi_range(0, 2)}
	return {"kind": "attack", "target": rng.randi_range(0, 2)}

# ---------------------------------------------------------------- 主验证

func run(battles: int = 500) -> Dictionary:
	var failures: Array = []
	var tally := {"win": 0, "lose": 0, "fled": 0, "timeout": 0}
	var rounds_total := 0
	var submits_total := 0
	var skill_uses := {}
	var bound_events := 0
	var battle_data := _load_json(BATTLE_PATH)
	var max_rounds := int(battle_data.get("rules", {}).get("max_rounds", 60))
	var setups: Array = [["slime"], ["slime", "slime"], ["crab", "slime"], ["guardian"], ["gpt6"]]

	for n in battles:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + n
		var kinds: Array = setups[n % setups.size()]
		var engine = _make_engine(1000 + n, kinds, 1 + (n % 8))
		var out: Dictionary = engine.submit({})
		# 事件必须每回合累积：submit 只返回本次的事件，循环里覆盖 out 会丢统计
		var seen: Array = out.events.duplicate()
		var submits := 1
		while str(out.result) == "" and submits < max_rounds * 12 + 50:
			var me: Array = engine.living("ally")
			if me.is_empty():
				break
			out = engine.submit(_pick_action(engine, me[0], rng))
			seen.append_array(out.events)
			submits += 1
		submits_total += submits
		rounds_total += int(engine.round_no)

		# --- 断言 ---
		if str(out.result) == "":
			failures.append("对局 %d 未结束（submits=%d round=%d）" % [n, submits, engine.round_no])
		elif not tally.has(str(out.result)):
			failures.append("对局 %d 出现未知结局 %s" % [n, str(out.result)])
		else:
			tally[str(out.result)] = int(tally[str(out.result)]) + 1
		if int(engine.round_no) > max_rounds + 1:
			failures.append("对局 %d 回合数 %d 超过上限" % [n, engine.round_no])
		for group in [engine.allies, engine.foes]:
			for c in group:
				if float(c.hp) < -0.001:
					failures.append("对局 %d %s 生命为负 %f" % [n, c.name, c.hp])
				if float(c.hp) > float(c.max_hp) + 0.001:
					failures.append("对局 %d %s 生命超过上限" % [n, c.name, c.hp])
				if float(c.stamina) < -0.001:
					failures.append("对局 %d %s 体力为负" % [n, c.name, c.stamina])
				# AP 是本轮新加的战斗资源，越界必须当成硬失败：它不进存档，没有 restore() 兜底
				if float(c.ap) < -0.001:
					failures.append("对局 %d %s AP 为负 %f" % [n, c.name, c.ap])
				if float(c.ap) > float(c.max_ap) + 0.001:
					failures.append("对局 %d %s AP 超过上限 %f" % [n, c.name, c.ap])
		if str(out.result) == "win" and not engine.living("foe").is_empty():
			failures.append("对局 %d 判胜但敌人未清空" % n)
		if str(out.result) == "lose" and not engine.living("ally").is_empty():
			failures.append("对局 %d 判负但我方还活着" % n)
		for e in seen:
			if str(e.type) == "skill":
				skill_uses[str(e.get("skill", "?"))] = int(skill_uses.get(str(e.get("skill", "?")), 0)) + 1
			if str(e.type) == "bound":
				bound_events += 1
			if float(e.amount) < 0:
				failures.append("对局 %d 出现负数值事件 %s" % [n, str(e.type)])

	var stats := {
		"battles": battles,
		"tally": tally,
		"avgRounds": roundf(float(rounds_total) / maxf(1.0, float(battles)) * 10.0) / 10.0,
		"avgSubmits": roundf(float(submits_total) / maxf(1.0, float(battles)) * 10.0) / 10.0,
		"boundEvents": bound_events,
	}
	return {"failures": failures, "stats": stats, "targeted": _targeted_tests()}

# ---------------------------------------------------------------- 定向断言

func _targeted_tests() -> Dictionary:
	var out: Dictionary = {}
	out["invalid_action_is_free"] = _test_invalid_action_free()
	out["shield_halves_damage"] = _test_shield_halves()
	out["bind_skips_a_turn"] = _test_bind_skips()
	out["save_ids_compatible"] = _test_save_ids()
	out["regen_and_cap"] = _test_stamina_regen()
	out["ap_flow"] = _test_ap_flow()
	return out

## AP「潮汐连携槽」的三条硬口径：
##   1. AP 未满时连携是非法指令 —— 不能消耗回合（否则玩家会白送一回合）
##   2. AP 满时连携合法、清空整条槽，并且打到「全体敌人」
##   3. 连携自己的伤害不回填 AP（否则刚清零就回一截，读条反馈是错的）
func _test_ap_flow() -> Dictionary:
	var engine = _make_engine(77, ["slime", "slime"], 5)
	engine.submit({})
	var me: Dictionary = engine.allies[0]
	var cap := float(me.max_ap)

	# 1. 未蓄满 → 非法，且回合数不变
	var round_before := int(engine.round_no)
	var low: Dictionary = engine.submit({"kind": "link"})
	var got_invalid := false
	for e in low.events:
		if str(e.type) == "invalid":
			got_invalid = true
	var free_ok: bool = got_invalid and int(engine.round_no) == round_before

	# 2. 蓄满 → 合法、清空、命中全体
	me.ap = cap
	var full_ok: bool = bool(engine.link_status(me).ready)
	var before_hp: Array = []
	for f in engine.foes:
		before_hp.append(float(f.hp))
	var out: Dictionary = engine.submit({"kind": "link"})
	var hit := 0
	for e in out.events:
		if str(e.type) == "damage" and str(e.get("skill", "")) == "link":
			hit += 1
	var damaged := 0
	for i in engine.foes.size():
		if float(engine.foes[i].hp) < float(before_hp[i]) - 0.001:
			damaged += 1
	# 3. 大招本身不回填：清空后被打到的敌人不该让槽涨回来
	var spent_ok: bool = absf(float(me.ap)) < 0.001

	return {
		"pass": free_ok and full_ok and spent_ok and hit == engine.foes.size() and damaged == engine.foes.size(),
		"illegalBelowFull": free_ok,
		"legalAtFull": full_ok,
		"linkHits": hit,
		"foesDamaged": damaged,
		"apAfterLink": float(me.ap),
		"apCap": cap,
	}

func _test_invalid_action_free() -> Dictionary:
	var engine = _make_engine(7, ["slime"], 1)
	engine.submit({})
	var round_before := int(engine.round_no)
	# 1 级用不了 7 级才解锁的鲸歌
	var out: Dictionary = engine.submit({"kind": "skill", "id": "whale_song", "target": 0})
	var got_invalid := false
	for e in out.events:
		if str(e.type) == "invalid":
			got_invalid = true
	return {
		"pass": str(out.awaiting) == "ally" and int(engine.round_no) == round_before and got_invalid,
		"awaiting": str(out.awaiting), "roundBefore": round_before, "roundAfter": int(engine.round_no), "invalidEvent": got_invalid,
	}

func _test_shield_halves() -> Dictionary:
	var plain = _make_engine(31, ["crab"], 3)
	var shielded = _make_engine(31, ["crab"], 3)
	plain.submit({})
	shielded.submit({})
	shielded.allies[0].shield = 5
	# 直接让敌人平a，不走 AI 选招 —— 珊瑚蟹有 50% 概率抽到「缩壳」（不造成伤害），
	# 经过 AI 会让这个对比随机失败。两边同种子，随机数消耗一致，只有护盾是变量。
	var ea: Array = plain.perform(plain.foes[0], {"kind": "attack", "target": 0})
	var eb: Array = shielded.perform(shielded.foes[0], {"kind": "attack", "target": 0})
	var da := _damage_to_ally(ea)
	var db := _damage_to_ally(eb)
	return {
		"pass": da > 0.0 and absf(db - da * 0.5) < 0.02,
		"damageWithoutShield": roundf(da * 100.0) / 100.0,
		"damageWithShield": roundf(db * 100.0) / 100.0,
	}

func _damage_to_ally(events: Array) -> float:
	var total := 0.0
	for e in events:
		if str(e.type) == "damage" and str(e.actor_side) == "foe":
			total += float(e.amount)
	return total

func _test_bind_skips() -> Dictionary:
	var engine = _make_engine(53, ["slime"], 3)
	engine.submit({})
	engine.foes[0].bind = 1
	var out: Dictionary = engine.submit({"kind": "attack", "target": 0})
	var bound := false
	var foe_acted := false
	for e in out.events:
		if str(e.type) == "bound" and str(e.actor) == str(engine.foes[0].name):
			bound = true
		if str(e.type) == "damage" and str(e.actor_side) == "foe":
			foe_acted = true
	return {"pass": bound and not foe_acted, "boundEvent": bound, "foeStillActed": foe_acted}

func _test_save_ids() -> Dictionary:
	var bal := _load_json(BALANCE_PATH)
	var ids: Array = []
	for record in bal.get("spawns", []):
		ids.append(str(record.get("id", "")))
	ids.append(str(bal.get("boss", {}).get("id", "")))
	ids.sort()
	var allowed := SAVE_ALLOWED_IDS.duplicate()
	allowed.sort()
	return {"pass": ids == allowed, "engineIds": ids, "saveWhitelist": allowed}

func _test_stamina_regen() -> Dictionary:
	var engine = _make_engine(11, ["slime"], 5)
	engine.submit({})
	var me: Dictionary = engine.allies[0]
	me.stamina = 10.0
	var before := float(me.stamina)
	for i in 3:
		engine.submit({"kind": "attack", "target": 0})
	return {
		"pass": float(me.stamina) >= minf(before, float(me.max_stamina)) and float(me.stamina) <= float(me.max_stamina) + 0.001,
		"before": before, "after": float(me.stamina), "cap": float(me.max_stamina),
	}
