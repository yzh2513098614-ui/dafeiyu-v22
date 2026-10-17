extends Node
## 回合制战斗的场地接线层
##
## 职责边界（重要）：
##   · 这里只做「世界里的遭遇点 + 点击战斗 + 打开界面 + 结算写回」
##   · 战斗规则一律在 battle/battle_engine.gd 里 —— 伤害、技能、回合、胜负都不在这里算
##   · 界面演出一律在 battle/battle_screen.gd 里
##
## 旧的即时战（怪物追击 / 红圈蓄力 / J K L）已按决定替换为回合制。

const Marker = preload("res://combat/encounter_marker.gd")
const ProgressCard = preload("res://ui/design/pages/world_trial_progress.tscn")
const EncounterPrompt = preload("res://ui/design/pages/world_encounter_prompt.tscn")
const WhaleStyle = preload("res://ui/whale_skin.gd")
const UiFit = preload("res://ui/ui_fit.gd")
const BattleScreen = preload("res://battle/battle_screen.gd")
const EngineScript = preload("res://battle/battle_engine.gd")

const ENCOUNTER_RANGE := 3.0     ## 走到这么近才弹 [战斗] 提示
const FLEE_COOLDOWN := 8.0       ## 绕开/逃脱后这个遭遇点暂时不再触发
## 练习场给正式经验的这个比例。
##
## 原来练习场**一点奖励都不发**：_settle_win 里只置 practice_defeated 再提示
## 「本轮不重复发奖」。于是清完 5 个之后，「再练一次」这条循环
## **机制上能重打、收益上是死路** —— 玩家没有任何理由再打。
## 现在：掉落仍然只发一次（保留「不重复发奖」的原意），但经验按比例给，
## 让练习真的能推等级（升级现在会影响全部六项属性，见 character/life_state.gain_xp）。
## 比例从 combat_balance.json 的 practice_xp_ratio 读，缺省 0.25 —— 改数据即可调。
const PRACTICE_XP_RATIO_DEFAULT := 0.25

var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_balance.json"))
var battle_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/battle_data.json"))
var card_data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
var game
var container: Node3D
var markers: Array = []
var near = null
var screen = null
var prompt: Panel
var prompt_title: Label
var prompt_sub: Label
var prompt_portrait: TextureRect
var prompt_kind := ""
var fight_button: Button
var avoid_button: Button
var hud: Panel
var progress_label: Label
var hint_label: Label
var practice_button: Button
var entry_button: Button
var pending: Dictionary = {}
var retry_timer := 0.0
var practice_mode := false
var practice_defeated: Dictionary = {}
var battle_no := 0

func configure(owner_game) -> void:
	game = owner_game
	hud = ProgressCard.instantiate()
	game.district_canvas.add_child(hud)
	UiFit.pin_right(hud, 366, 48, 118, 146)
	progress_label = hud.get_node("ProgressText")
	hint_label = hud.get_node("TrialHint")
	hud.get_node("ReturnHarbor").pressed.connect(func():game.request_travel("city"))
	practice_button = hud.get_node("PracticeButton")
	practice_button.pressed.connect(start_practice)
	# 试炼场入口按钮：不在试炼场时显示。漏掉它会让玩家没有直接进入的入口
	entry_button = game._button("潮汐试炼 · 前往训练场", Vector2(48, 394), Vector2(450, 49), game.district_canvas, func():game.request_travel("trial"))
	_build_prompt()
	world_changed()

# ---------------------------------------------------------------- 遭遇提示

func _build_prompt() -> void:
	prompt = EncounterPrompt.instantiate()
	game.district_canvas.add_child(prompt)
	UiFit.pin_left(prompt, 600, 28, 706, 184)
	prompt_title = prompt.get_node("EncounterTitle")
	prompt_sub = prompt.get_node("EncounterDetails")
	prompt_portrait = prompt.get_node("MonsterPortrait")
	fight_button = prompt.get_node("FightButton")
	avoid_button = prompt.get_node("AvoidButton")
	fight_button.pressed.connect(fight)
	avoid_button.pressed.connect(avoid)
	prompt.hide()

func world_changed() -> void:
	practice_mode = false
	practice_defeated.clear()
	near = null
	if is_instance_valid(container):
		container.queue_free()
	container = null
	markers.clear()
	if game.location_id == "trial":
		container = Node3D.new()
		game.world.add_child(container)
		var defeated: Dictionary = game.character_controller.model.state.combat.defeated
		for record in balance.spawns:
			if not defeated.has(record.id) and not pending.has(record.id):
				_spawn(record)
		_spawn_boss_if_ready()
	_refresh()

func _spawn(record: Dictionary):
	var marker = Marker.new()
	container.add_child(marker)
	marker.configure(self, record)
	markers.append(marker)
	return marker

func _spawn_boss_if_ready() -> void:
	var defeated: Dictionary = practice_defeated if practice_mode else game.character_controller.model.state.combat.defeated
	for record in balance.spawns:
		if not defeated.has(record.id):
			return
	if defeated.has("guardian"):
		return
	for marker in markers:
		if is_instance_valid(marker) and marker.id == "guardian":
			return
	_spawn(balance.boss)

func _nearest_available():
	var best = null
	var best_distance := INF
	for marker in markers:
		if not is_instance_valid(marker) or not marker.is_available():
			continue
		var distance: float = marker.position.distance_to(game.player.position)
		if distance < best_distance:
			best_distance = distance
			best = marker
	if best != null and best_distance <= ENCOUNTER_RANGE:
		return best
	return null

## 战斗中要冻结世界：角色不能走动，昼夜也不该继续走
func in_battle() -> bool:
	return screen != null

func battle_active() -> bool:
	return in_battle()

func _physics_process(delta: float) -> void:
	if not game:
		return
	retry_timer += delta
	if retry_timer >= 2.0:
		retry_timer = 0.0
		for id in pending.keys():
			claim_reward(id, pending[id])
	if in_battle():
		prompt.hide()
		return
	var free: bool = game.character_controller.free_world()
	near = _nearest_available() if free and game.location_id == "trial" else null
	if near != null:
		prompt_title.text = "遭遇  " + str(near.data.get("name", near.kind))
		if prompt_kind != str(near.kind):
			prompt_kind = str(near.kind)
			prompt_portrait.texture = load(str(near.data.get("map_texture", near.data.get("texture", ""))))
		prompt_sub.text = "生命 %d · 攻击 %d · 防御 %d" % [
			int(near.data.get("health", 0)), int(near.data.get("attack", 0)), int(near.data.get("defense", 0))]
		# 只在「提示从无到有」的那一刻响，不是每帧都响 ——
		# 用 prompt.visible 做边沿检测，省掉一个成员变量。
		if not prompt.visible:
			SfxDirector.play("encounter", -7.0)
		prompt.show()
	else:
		prompt.hide()
	_refresh()

func _refresh() -> void:
	if not game or not hud:
		return
	var visible_now: bool = game.location_id == "trial" and game.character_controller.free_world()
	hud.visible = visible_now
	# 不在试炼场时给出入口；战斗中隐藏，避免点着点着又传送
	if is_instance_valid(entry_button):
		entry_button.visible = game.character_controller.free_world() and game.location_id != "trial" and not in_battle()
	if not visible_now:
		return
	var count: int = practice_defeated.size() if practice_mode else game.character_controller.model.state.combat.defeated.size()
	progress_label.text = "已通过 %d / %d 场" % [count, int(balance.spawns.size()) + 1]
	practice_button.visible = count >= int(balance.spawns.size()) + 1 and pending.is_empty()
	hud.offset_bottom = hud.offset_top + (184 if practice_button.visible else 146)

# ---------------------------------------------------------------- 战斗

func fight() -> void:
	if in_battle() or near == null or not is_instance_valid(near):
		return
	var record: Dictionary = near.record
	var model = game.character_controller.model
	battle_no += 1
	var engine = EngineScript.new(battle_no * 7919 + int(Time.get_ticks_msec() % 100000), battle_data)
	var stats: Dictionary = {}
	for key in ["strength", "endurance", "insight", "charm", "agility", "luck"]:
		stats[key] = model.attribute(key)
	engine.add_ally({
		"id": "player", "name": "大肥鱼", "level": int(model.state.level),
		"hp": model.value("health"), "max_hp": model.maximum("health"),
		"stamina": model.value("stamina"), "max_stamina": model.maximum("stamina"),
		"atk": float(model.attack()), "def": float(model.defense()),
		"spd": float(model.attribute("agility")), "stats": stats,
	})
	engine.add_foe(engine.foe_entry_from_monster(record, balance.monsters.get(str(record.get("type", "")), {})))
	engine.enable_cards(card_data)
	screen = BattleScreen.new()
	game.add_child(screen)
	screen.battle_finished.connect(_on_battle_finished)
	screen.open(engine, {
		"title": "潮汐遭遇战",
		"textures": _textures(),
		"items": battle_items(engine),
		# 用 provider 而不是一份静态列表：道具的可用性依赖战斗内当前生命/体力
		# （满血时不该还能用急救包），每次打开道具菜单都要重新算一遍。
		"items_provider": Callable(self, "battle_items").bind(engine),
		"consume_item": Callable(self, "consume_item"),
		"result_provider": Callable(self, "result_summary").bind(engine),
	})
	prompt.hide()
	hud.hide()
	game.hint.text = "战斗中：" + str(record.get("id", ""))

func _textures() -> Dictionary:
	var out: Dictionary = {}
	for kind in balance.monsters:
		out[str(kind)] = str(balance.monsters[kind].get("texture", ""))
	return out

func _on_battle_finished(result: String) -> void:
	var finished_marker = near
	var engine = screen.engine if screen != null else null
	var prepared: bool = screen != null and bool(screen.context.get("result_prepared", false))
	screen = null
	if engine != null and not prepared:
		_sync_vitals(engine)
	match result:
		"win":
			if not prepared: _settle_win(engine)
			if finished_marker != null and is_instance_valid(finished_marker):
				finished_marker.retire()
				markers.erase(finished_marker)
			near = null
		"lose", "timeout":
			_recover_at_harbor()
		"fled":
			game.loot.save_state()
			if finished_marker != null and is_instance_valid(finished_marker):
				finished_marker.cooldown = FLEE_COOLDOWN
				finished_marker._refresh_caption()
			game.hint.text = "你选择先离开，等一会儿再来。"
	_refresh()

func result_summary(result: String, engine) -> Dictionary:
	if result != "win":
		return {"summary": "你已经成功离开交战。\n本场不发放阅历与掉落，补给消耗保留。" if result == "fled" else "回到港口后恢复一半生命。\n背包保留，可以补给后再次挑战。", "items": [], "saved": true}
	var model = game.character_controller.model
	if not bool(screen.context.get("result_prepared", false)):
		screen.context["level_before_result"] = int(model.state.level)
		_sync_vitals(engine)
		_settle_win(engine)
		screen.context["result_prepared"] = true
		if practice_mode: game.loot.save_state()
	var xp := 0
	var collected: Dictionary = {}
	var saved := true
	for foe in engine.foes:
		if bool(foe.alive): continue
		var definition: Dictionary = balance.monsters.get(str(foe.kind), {})
		if practice_mode: continue
		xp += int(definition.get("xp", 0))
		if not model.state.combat.defeated.has(str(foe.id)): saved = false
		for item in definition.get("drops", {}): collected[item] = int(collected.get(item, 0)) + int(definition.drops[item])
	var items: Array = []
	for id in collected: items.append({"name":str(game.loot.definitions.get(id, {}).get("name", id)), "count":collected[id]})
	var level_before := int(screen.context.get("level_before_result", model.state.level))
	var text := "自由练习完成\n本轮不重复发放阅历与物品。" if practice_mode else "阅历 +%d · %s" % [xp, "奖励已保存" if saved else "背包已满或保存失败，回到地图后自动重试"]
	if int(model.state.level)>level_before: text += "\n等级提升：Lv.%d → Lv.%d" % [level_before,int(model.state.level)]
	return {"summary":text,"items":items,"saved":saved}

## 把战斗结束时的生命/体力写回角色状态 —— 引擎不改存档，写回是这一层的责任
func _sync_vitals(engine) -> void:
	var model = game.character_controller.model
	model.state.vitals.health = clampf(float(engine.allies[0].hp), 0.0, model.maximum("health"))
	model.state.vitals.stamina = clampf(float(engine.allies[0].stamina), 0.0, model.maximum("stamina"))
	game.character_controller.dirty = true
	game.character_controller.refresh()

func _settle_win(engine) -> void:
	var model = game.character_controller.model
	for foe in engine.foes:
		if bool(foe.alive):
			continue
		if practice_mode:
			practice_defeated[str(foe.id)] = true
			_grant_practice_xp(model, str(foe.kind), str(foe.name))
			continue
		pending[str(foe.id)] = str(foe.kind)
		claim_reward(str(foe.id), str(foe.kind))
	if game.location_id == "trial":
		_spawn_boss_if_ready()
	_refresh()

## 练习场给多少经验。**纯计算**，好让无头测试直接验（见 tools/test_practice_loop.gd）——
## 结算那一段要 game/hint/存档，单独测不了。
func practice_xp_for(kind: String) -> int:
	var definition: Dictionary = balance.monsters.get(kind, {})
	if definition.is_empty():
		return 0
	var ratio := clampf(float(balance.get("practice_xp_ratio", PRACTICE_XP_RATIO_DEFAULT)), 0.0, 1.0)
	return int(floorf(float(definition.get("xp", 0)) * ratio))

## 练习场结算：**只给经验，不给掉落**。掉落走 claim_reward 那条一次性路径。
func _grant_practice_xp(model, kind: String, foe_name: String) -> void:
	var gained := practice_xp_for(kind)
	if gained <= 0:
		game.hint.text = "练习完成：%s" % foe_name
		return
	var level_before := int(model.state.level)
	model.gain_xp(gained)
	game.character_controller.dirty = true
	game.character_controller.refresh()
	game.loot.save_state()
	var tail := ""
	if int(model.state.level) > level_before:
		tail = " · 升到 %d 级！" % int(model.state.level)
	game.hint.text = "练习完成：%s · 阅历 +%d%s" % [foe_name, gained, tail]

func _recover_at_harbor() -> void:
	var model = game.character_controller.model
	model.state.vitals.health = model.maximum("health") * .5
	model.state.vitals.stamina = maxf(25.0, model.value("stamina"))
	game.loot.save_state()
	game.request_travel("city")
	game.hint.text = "倒下了，已回到港口休息；背包保留。"

func avoid() -> void:
	if near != null and is_instance_valid(near):
		near.cooldown = FLEE_COOLDOWN
		near._refresh_caption()
		game.hint.text = "绕开了 %s。" % str(near.data.get("name", near.kind))
	near = null
	prompt.hide()

func start_practice() -> bool:
	if in_battle() or not pending.is_empty():
		return false
	if game.character_controller.model.state.combat.defeated.size() < balance.spawns.size() + 1:
		return false
	practice_mode = true
	practice_defeated.clear()
	if is_instance_valid(container):
		container.queue_free()
	container = Node3D.new()
	game.world.add_child(container)
	markers.clear()
	for record in balance.spawns:
		_spawn(record)
	game.hint.text = "自由练习：状态照常消耗，掉落只发一次；阅历按 %d%% 计。" % int(clampf(float(balance.get("practice_xp_ratio", PRACTICE_XP_RATIO_DEFAULT)), 0.0, 1.0) * 100.0)
	return true

## 领取奖励：沿用原来的「先记 pending、失败每 2 秒重试」口径，保证不会丢奖励
func claim_reward(id: String, kind: String) -> bool:
	var model = game.character_controller.model
	var loot = game.loot
	if model.state.combat.defeated.has(id):
		pending.erase(id)
		return true
	var definition: Dictionary = balance.monsters.get(kind, {})
	if definition.is_empty():
		pending.erase(id)
		return true
	var inventory_before: Dictionary = loot.inventory.duplicate(true)
	var state_before: Dictionary = model.snapshot()
	var slots: int = loot.occupied_slots()
	for item in definition.drops:
		if int(loot.inventory.get(item, 0)) == 0:
			slots += 1
		if slots > 64 or int(loot.inventory.get(item, 0)) + int(definition.drops[item]) > 9999:
			game.hint.text = "背包满了；清出格子后会自动领取掉落。"
			return false
	for item in definition.drops:
		loot.inventory[item] = int(loot.inventory.get(item, 0)) + int(definition.drops[item])
	model.gain_xp(int(definition.xp))
	model.state.combat.defeated[id] = true
	if not loot.save_state():
		loot.inventory = inventory_before
		model.restore(state_before)
		game.hint.text = "掉落尚未保存，将自动重试。"
		return false
	pending.erase(id)
	loot._bag_count()
	game.character_controller.refresh()
	game.hint.text = "击败 %s · 阅历 +%d · 掉落已收好。" % [str(definition.get("name", kind)), int(definition.xp)]
	return true

# ---------------------------------------------------------------- 战斗内道具
#
# 分工刻意分三层，因为只有这里同时认识「背包」和「战斗引擎」：
#   · 战斗界面：只显示和收输入，不读背包、不读 character_balance.json
#   · 战斗引擎：只把效果算进**战斗内**数值，不知道背包存在
#   · 这一层：算效果、扣背包、保存（带回滚）
# 好处是引擎仍然可以被无头测试直接驱动（见 tools/test_battle.gd），不需要造背包。

## 战斗中可用的道具列表 = action 是 consume 且数量 > 0 的。
## engine 传进来时还会按战斗内当前数值过滤掉「现在用了也没意义」的（满血时的急救包）。
func battle_items(engine = null) -> Array:
	var loot = game.loot
	var balance_items: Dictionary = game.character_controller.model.balance.items
	var ally: Dictionary = {}
	if engine != null and not engine.allies.is_empty():
		ally = engine.allies[0]
	var out: Array = []
	for id in balance_items:
		var rule: Dictionary = balance_items[id]
		if str(rule.get("action", "")) != "consume":
			continue
		var count := int(loot.inventory.get(id, 0))
		if count <= 0:
			continue
		var effects: Dictionary = {}
		for vital in rule.get("effects", {}):
			effects[str(vital)] = float(rule.effects[vital])
		if effects.is_empty():
			continue
		# 战斗里只认生命和体力 —— 饱食/心情在战斗引擎里没有对应数值。
		# 把只加心情的东西列出来，等于让玩家用掉一个回合换一个战斗内看不见的效果。
		var battle_relevant := false
		for vital in effects:
			if str(vital) == "health" or str(vital) == "stamina":
				battle_relevant = true
				break
		if not battle_relevant:
			continue
		var usable := true
		var reason := ""
		if not ally.is_empty():
			# 只要有任意一项还能涨就允许用 —— 和 life_state.apply_item 同一口径：
			# 「相关状态已经充足，这次不会消耗物品」。
			usable = false
			var full := []
			for vital in effects:
				var current := 0.0
				var maximum := 0.0
				var label := ""
				if str(vital) == "health":
					current = float(ally.hp)
					maximum = float(ally.max_hp)
					label = "生命"
				elif str(vital) == "stamina":
					current = float(ally.stamina)
					maximum = float(ally.max_stamina)
					label = "体力"
				else:
					continue
				if current < maximum - 0.01:
					usable = true
				else:
					full.append(label)
			if not usable:
				reason = ("%s已满" % "与".join(full)) if not full.is_empty() else "现在用不上"
		out.append({
			"id": str(id),
			"name": str(loot.definitions.get(id, {}).get("name", id)),
			"summary": str(rule.get("summary", "")),
			"count": count,
			"effects": effects,
			"usable": usable,
			"reason": reason,
		})
	return out

## 引擎确认执行了道具之后才调用：扣掉一个并保存。
## 保存失败要回滚数量 —— 和 loot_controller.transfer 同一个口径，
## 不能让「用了没扣」或「扣了没存」发生。
func consume_item(id: String) -> bool:
	var loot = game.loot
	var before := int(loot.inventory.get(id, 0))
	if before <= 0:
		return false
	var model = game.character_controller.model
	var state_before: Dictionary = model.snapshot()
	var dirty_before: bool = game.character_controller.dirty
	if screen != null: _sync_vitals(screen.engine)
	var rule: Dictionary = model.balance.items.get(id, {})
	for vital in rule.get("effects", {}):
		if vital in ["hunger", "mood"]: model.state.vitals[vital] = clampf(model.value(vital) + float(rule.effects[vital]), 0, model.maximum(vital))
	if rule.has("buff"): model.state.buffs[rule.buff] = float(rule.get("duration", 0))
	loot.inventory[id] = before - 1
	if not loot.save_state():
		loot.inventory[id] = before
		model.restore(state_before)
		game.character_controller.dirty = dirty_before
		game.character_controller.refresh()
		game.hint.text = "道具尚未保存，这次使用没有扣掉。"
		return false
	loot._bag_count()
	game.character_controller.refresh()
	return true
