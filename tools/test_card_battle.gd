extends SceneTree
## Checks the imported 42-card loop without changing player saves.
const BattleEngine = preload("res://battle/battle_engine.gd")
var failed := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok: print("PASS ", message)
	else:
		failed += 1
		push_error("FAIL " + message)

func run() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
	check(raw is Array and raw.size() == 42, "42 imported cards")
	var cards: Array = raw if raw is Array else []
	var ids: Dictionary = {}
	for card in cards:
		ids[str(card.id)] = true
		check(ResourceLoader.exists(str(card.image)), "art " + str(card.id))
	check(ids.size() == 42, "unique card IDs")
	var controller = load("res://combat/combat_controller.gd").new()
	check(controller.card_data.size() == 42, "real encounter controller loads the card catalog")
	controller.free()
	var engine = BattleEngine.new(20261004)
	engine.add_ally({"id":"player","name":"大肥鱼","hp":1000,"max_hp":1000,"stamina":100,"max_stamina":100,"atk":12,"def":2,"spd":4})
	engine.add_foe({"id":"dummy","kind":"slime","name":"木桩","hp":1000,"max_hp":1000,"atk":2,"def":1,"spd":1,"skill_pool":["slam"]})
	engine.enable_cards(cards)
	var start: Dictionary = engine.submit({})
	check(str(start.awaiting) == "ally" and engine.round_no == 1, "player begins card turn")
	check(engine.hand.size() == 5 and engine.card_energy == 3, "five-card hand and three energy")
	var first: Dictionary = engine.card_hand_view()[0]
	var ally_hp := float(engine.allies[0].hp)
	var played: Dictionary = engine.submit({"kind":"card","index":0,"target":0})
	check(str(played.result) == "" and engine.round_no == 1, "playing a card stays in the same turn")
	check(float(engine.allies[0].hp) >= ally_hp, "enemy does not act between cards")
	var gained := 0
	for effect in first.effects:
		if str(effect.kind) == "energy": gained += int(effect.value)
	check(engine.card_energy == mini(5, 3 - int(first.cost) + gained), "card cost and energy effects settle exactly")
	var hand_before: Array = engine.hand.duplicate()
	var energy_before: int = engine.card_energy
	var invalid: Dictionary = engine.submit({"kind":"card","index":999,"target":0})
	check(engine.hand == hand_before and engine.card_energy == energy_before and str(invalid.awaiting) == "ally", "invalid card costs nothing")
	var checkpoint: Dictionary = engine.checkpoint()
	var ended: Dictionary = engine.submit({"kind":"end_turn"})
	check(engine.round_no == 2 and str(ended.awaiting) == "ally", "end turn runs enemy then draws next hand")
	check(engine.hand.size() == 5 and engine.card_energy == 3, "next turn refills hand and energy")
	var enemy_acted := false
	for event in ended.events:
		if str(event.get("actor_side", "")) == "foe": enemy_acted = true
	check(enemy_acted, "enemy acts only after end turn")
	engine.restore_checkpoint(checkpoint)
	check(engine.round_no == 1 and engine.hand == hand_before and engine.card_energy == energy_before, "checkpoint restores card state")
	var stable := true
	for n in 12:
		engine.submit({"kind":"end_turn"})
		if engine.draw_pile.size() + engine.discard_pile.size() + engine.hand.size() != 42: stable = false
	check(stable and engine.round_no == 13, "reshuffle preserves every card")
	var playable := 0
	for card in cards:
		var probe = BattleEngine.new(3000 + playable)
		probe.add_ally({"id":"player","name":"大肥鱼","hp":100,"max_hp":100,"stamina":100,"max_stamina":100,"atk":12,"def":2,"spd":4})
		probe.add_foe({"id":"dummy","kind":"slime","name":"木桩","hp":1000,"max_hp":1000,"atk":1,"def":1,"spd":1,"skill_pool":["slam"]})
		probe.enable_cards(cards); probe.submit({})
		probe.hand = [str(card.id)]; probe.card_energy = 3
		var played_one: Dictionary = probe.submit({"kind":"card","index":0,"target":0})
		for event in played_one.events:
			if str(event.get("type", "")) == "card": playable += 1
	check(playable == 42, "every imported card can be played as a skill")
	var blocked = BattleEngine.new(91)
	blocked.add_ally({"id":"player","name":"大肥鱼","hp":100,"max_hp":100,"atk":10,"def":0})
	blocked.allies[0].block = 10.0
	blocked._damage(blocked.allies[0], 8.0)
	check(float(blocked.allies[0].hp) == 100.0 and float(blocked.allies[0].block) == 2.0, "card block absorbs damage before health")
	# Instantiate the actual screen so its card controls and textures are parsed.
	var screen = load("res://battle/battle_screen.gd").new()
	root.add_child(screen)
	screen.open(engine, {"title":"卡牌战斗测试"})
	await process_frame
	check(screen.card_panel != null and screen.card_row.get_child_count() == engine.hand.size(), "live screen renders current hand")
	screen._finish_playback()
	if screen.card_row.get_child_count() > 0:
		(screen.card_row.get_child(0) as Button).pressed.emit()
		var signal_works := false
		for event in engine.events:
			if str(event.get("type", "")) == "card": signal_works = true
		check(signal_works, "card button submits its skill")
	screen.close(); screen.queue_free()
	var legacy: Dictionary = load("res://tools/test_battle.gd").new().run(100)
	check((legacy.failures as Array).is_empty(), "legacy command battles retain their rules")
	print("CARD BATTLE FAILURES ", failed)
	quit(0 if failed == 0 else 1)
