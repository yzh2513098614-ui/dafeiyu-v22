extends Node
## Uses the production battle screen and engine; no player progress is loaded or saved.

var screen
var engine
var failures := 0
var checks := 0

func _enter_tree() -> void:
	AudioServer.set_bus_mute(0, true)

func _ready() -> void:
	get_node("/root/MusicDirector").set_enabled(false)
	get_node("/root/SfxDirector").set_enabled(false)
	get_node("/root/HarborPrefs").values.fullscreen = false
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	get_window().size = Vector2i(1280, 720)
	var verify := "--verify-original-battle" in OS.get_cmdline_user_args()
	if verify:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_position(Vector2i(-9999, -9999))
	engine = load("res://battle/battle_engine.gd").new(20261016)
	engine.add_ally({"id":"player", "name":"大肥鱼", "level":13, "hp":117, "max_hp":148, "stamina":198, "max_stamina":198, "atk":8, "def":7, "spd":9, "ap":100})
	engine.add_foe({"id":"gpt6", "kind":"gpt6", "name":"gpt6", "hp":65, "max_hp":65, "atk":5, "def":1, "spd":1})
	engine.add_foe({"id":"slime", "kind":"slime", "name":"海沫团", "hp":100, "max_hp":100, "atk":3, "def":1, "spd":1})
	engine.enable_cards(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json")))
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_balance.json"))
	screen = load("res://battle/battle_screen.gd").new()
	add_child(screen)
	screen.open(engine, {"title":"潮汐遭遇战", "textures":{"gpt6":balance.monsters.gpt6.texture, "slime":balance.monsters.slime.texture}, "items":[{"id":"preview_heal", "name":"恢复补给", "count":1, "description":"恢复 10 点生命", "effects":{"heal":10}, "usable":true}]})
	await get_tree().create_timer(0.8).timeout
	screen.skip_playback()
	screen.card_preview.hide()
	if verify:
		await verify_inputs()

func settle() -> void:
	for i in 8:
		await get_tree().process_frame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS ", message)

func click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event, true)
	await get_tree().process_frame
	event.pressed = false
	get_viewport().push_input(event, true)
	await settle()

func verify_inputs() -> void:
	await settle()
	var title_style: StyleBoxFlat = screen.title_plate.get_theme_stylebox("panel")
	var player_style: StyleBoxFlat = screen.dash.dock.get_theme_stylebox("panel")
	check(title_style.border_color == Color.WHITE and player_style.bg_color.is_equal_approx(Color("eff5ff")), "production screen receives the native design page")
	check(screen.dash.dock.position.x < screen.slots[0].art.position.x and screen.card_panel.position.y > screen.slots[0].bar_back.get_rect().end.y, "original player / portrait / hand layout retained")
	var rng_before: int = engine.rng.state
	await click(screen.slots[1].hit)
	check(screen.context.target == 1 and screen.slots[1].mark.visible, "portrait click selects the real target")
	await click(screen.card_panel.get_node("CardTargetButton"))
	check(screen.context.target == 0, "target action cycles the real target")
	await click(screen.card_item_button)
	check(screen.mode == "item", "supply opens the production item menu")
	await click(screen.submenu_back)
	check(screen.mode == "command" and engine.rng.state == rng_before, "return restores commands; UI selection preserves battle RNG")
	var index := -1
	for entry in engine.card_hand_view():
		if bool(entry.ready) and str(entry.effects[0].kind) == "damage":
			index = int(entry.index)
			break
	check(index >= 0, "seeded hand contains a playable attack card")
	if index >= 0:
		var card: Control = screen.card_row.get_child(index)
		var motion := InputEventMouseMotion.new()
		motion.position = card.get_global_rect().get_center()
		get_viewport().push_input(motion, true)
		await settle()
		check(screen.card_preview.visible, "card hover opens the full original illustration preview")
		var hand_before: int = engine.hand.size()
		var hp_before: float = engine.foes[0].hp
		await click(card)
		screen.skip_playback()
		await settle()
		check(engine.hand.size() == hand_before - 1 and engine.foes[0].hp < hp_before, "card click spends the card and damages the selected enemy")
	var round_before: int = engine.round_no
	await click(screen.card_end_button)
	screen.skip_playback()
	await settle()
	check(engine.round_no > round_before and screen.mode == "command", "end turn resolves through the production battle engine")
	print("ORIGINAL BATTLE UI: %d checks, %d failures" % [checks, failures])
	screen.close()
	get_tree().quit(1 if failures else 0)
