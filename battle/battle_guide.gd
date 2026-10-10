extends RefCounted
## Read-only previews: never consume combat RNG or change an actor.
static func damage(engine, actor: Dictionary, target: Dictionary, spec: Dictionary = {}) -> String:
	if target.is_empty(): return "暂无可选目标"
	var base: float = float(actor.atk) * float(spec.get("power", 1.0))
	base += engine.stat_of(actor, str(spec.get("stat", ""))) * float(spec.get("stat_scale", 0.0))
	var spread: float = float(engine.rules.damage_variance)
	var shield: float = float(engine.rules.shield_reduction) if int(target.shield) > 0 else 1.0
	var low := maxf(1.0, base * (1.0 - spread) - float(target.def)) * shield
	var high := maxf(1.0, base * (1.0 + spread) - float(target.def)) * shield
	return "预计伤害 %d—%d（未计暴击%s）" % [floori(low), ceili(high), "，已计护盾" if int(target.shield) > 0 else ""]

static func skill(engine, id: String, target: Dictionary) -> String:
	var me: Dictionary = engine.allies[0]
	var spec: Dictionary = engine.skills.get(id, {})
	var lines: Array[String] = [str(spec.get("desc", ""))]
	match str(spec.get("kind", "")):
		"damage": lines.append(damage(engine, me, target, spec) + ("\n命中全体敌人" if spec.get("target") == "all" else "\n命中当前选中目标"))
		"heal": lines.append("恢复生命 %d · 适合受伤后使用" % int(float(spec.get("power", 0)) + engine.stat_of(me, str(spec.get("stat", ""))) * float(spec.get("stat_scale", 0))))
		"shield": lines.append("接下来 %d 回合减伤 %d%% · 适合承受重击" % [int(spec.get("turns", 1)), int((1.0-float(engine.rules.shield_reduction))*100)])
		"bind": lines.append("目标跳过 %d 次行动 · 可争取补给时间" % int(spec.get("turns", 1)))
		"haste": lines.append("提高 %d 回合行动速度 · 影响先后手" % int(spec.get("turns", 1)))
	lines.append("消耗体力 %d · 冷却 %d 回合\n每回合体力恢复 %d · 解锁等级 %d" % [int(spec.get("cost", 0)), int(spec.get("cooldown", 0)), int(engine.rules.stamina_regen_per_round), int(spec.get("unlock_level", 1))])
	var status: Dictionary = engine.skill_status(me, id)
	if not status.ready: lines.append("当前不可用：" + str(status.reason))
	return "\n\n".join(lines)

static func item(entry: Dictionary) -> String:
	var effects: Dictionary = entry.get("effects", {})
	var lines: Array[String] = []
	for pair in [["health", "生命"], ["stamina", "体力"]]:
		if float(effects.get(pair[0], 0)) > 0: lines.append("%s +%d" % [pair[1], int(effects[pair[0]])])
	lines.append("使用后结束本次行动，敌人仍会行动。")
	if not bool(entry.get("usable", true)): lines.append("当前不可用：" + str(entry.get("reason", "状态已满")))
	return "\n\n".join(lines)
