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
	get_window().title = "战斗试玩 · 背包与主界面同款"
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
	await verify_shared_status()
	var title_style: StyleBoxFlat = screen.title_plate.get_theme_stylebox("panel")
	var player_style: StyleBoxFlat = screen.dash.dock.get_theme_stylebox("panel")
	check(title_style.border_color.is_equal_approx(Color("40567d")) and player_style.bg_color.is_equal_approx(Color("fcfdff")) and player_style.border_color.is_equal_approx(Color.WHITE) and get_node("/root/UiDesign").applied_count > 0, "production screen receives the backpack frame and native design page")
	var field: Panel = screen.root.get_node("BattlefieldFrame")
	var hand_frame: Panel = screen.root.get_node("HandAreaFrame")
	check(not field.visible and field.mouse_filter == Control.MOUSE_FILTER_IGNORE, "extra battlefield outline removed without blocking portraits")
	check(hand_frame.get_global_rect().encloses(screen.card_scroll.get_global_rect()), "hand scroll fits within the new outer frame")
	var actions_frame: Panel = hand_frame.get_node("ActionFrame")
	var actions: Array = [screen.card_panel.get_node("CardTargetButton"), screen.card_item_button, screen.card_link_button, screen.card_end_button]
	var fit := true
	for i in actions.size():
		fit = fit and actions_frame.get_global_rect().encloses(actions[i].get_global_rect())
		if i > 0:
			fit = fit and not actions[i].get_global_rect().intersects(actions[i - 1].get_global_rect())
	check(fit, "all action buttons fit their inner frame without overlap")
	check(screen.dash.dock.position.x < screen.slots[0].art.position.x and screen.card_panel.position.y > screen.slots[0].bar_back.get_rect().end.y, "original player / portrait / hand layout retained")
	var intel_fits := true
	for slot in screen.slots:
		if slot.foe != null:
			intel_fits = intel_fits and slot.plate.get_global_rect().encloses(slot.intent.get_global_rect()) and slot.plate.get_global_rect().encloses(slot.bar_back.get_global_rect())
	check(intel_fits, "enemy intent and health share one readable nameplate group")
	var hand_before_scroll: Array = engine.hand.duplicate()
	for entry in engine.card_hand_view():
		if int(entry.cost) > 0:
			engine.card_energy = 0
			screen._refresh_cards()
			await settle()
			var unavailable: Button = screen.card_row.get_child(int(entry.index))
			check(unavailable.disabled and unavailable.has_node("CardAvailability"), "insufficient energy disables the card with a readable reason")
			break
	engine.card_energy = engine.card_energy_max
	engine.hand.clear()
	for id in engine.card_catalog.keys().slice(0, 8):
		engine.hand.append(str(id))
	screen._refresh_cards()
	await settle()
	var scrollbar: HScrollBar = screen.card_scroll.get_h_scroll_bar()
	var cards_fit := scrollbar.visible
	var content_bottom: float = screen.card_scroll.get_global_rect().end.y - scrollbar.size.y
	for card in screen.card_row.get_children():
		cards_fit = cards_fit and card.get_global_rect().end.y <= content_bottom + 1.0
	check(cards_fit, "eight-card hand keeps card bottoms above the scrollbar")
	screen.card_row.get_child(7).grab_focus()
	await settle()
	check(screen.card_scroll.scroll_horizontal > 0, "keyboard focus still scrolls to a later card")
	engine.hand = hand_before_scroll
	screen._refresh_cards()
	await settle()
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
		check(card.scale.y > 1.02 and card.get_global_rect().position.y >= screen.card_scroll.get_global_rect().position.y, "hover lifts the card within its reserved scroll space")
		var effects: RichTextLabel = card.get_node("CardFooter/CardEffect")
		check(not effects.get_parsed_text().is_empty() and effects.get_content_height() <= effects.size.y + 1.0, "card effect text remains readable without vertical clipping")
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

func verify_shared_status() -> void:
	var dock: Panel = screen.dash.dock
	check(dock.size.is_equal_approx(Vector2(312, 390)) and is_equal_approx(dock.position.y + dock.size.y, 766.0), "shared-style status card retains its compact placement")
	var actor: Dictionary = engine.allies[0]
	var original: Dictionary = actor.duplicate(true)
	var renderer: Node = screen.status_meters
	var health: Dictionary = renderer.meters.health
	check(renderer.process_mode == Node.PROCESS_MODE_DISABLED and renderer.game == null, "world meter renderer has no world gameplay, processing or input")
	var face: StyleBoxFlat = health.fill.get_theme_stylebox("background")
	check(face.border_width_left == 3 and face.border_color.is_equal_approx(Color.WHITE) and face.shadow_color.is_equal_approx(Color("638eff")) and face.shadow_offset.is_equal_approx(Vector2(2, 3)), "health uses the actual HUD white rim and solid blue offset")
	for hp in [107, 148, 29, 0]:
		actor.hp = hp
		screen._refresh_ally()
		await get_tree().create_timer(0.45).timeout
		var expected: String = "0 !" if hp == 0 else "29 / 148 !" if hp == 29 else "满" if hp == 148 else "107 / 148"
		var expected_color := Color("974154") if hp <= 29 else Color("93a6c4") if hp == 148 else Color("2857c9")
		check(health.text.text == expected and is_equal_approx(health.fill.value, hp) and health.text.get_theme_color("font_color").is_equal_approx(expected_color) and health.zero == (hp == 0), "health %d / 148 follows the real HUD reading and warning rules" % hp)
	actor.hp = 107
	actor.stamina = 20
	screen._refresh_ally()
	await settle()
	check(renderer.meters.stamina.low and renderer.meters.stamina.reading_color.is_equal_approx(Color("8a5a17")) and renderer.meters.stamina.track_backing.face.shadow_color.is_equal_approx(Color("feb633")), "low stamina uses the HUD warm warning colors")
	actor.block = 12345
	actor.shield = 1
	actor.haste = 1
	actor.bind = 1
	actor.ap = engine.link_status(actor).max_ap
	screen._refresh_ally()
	await settle()
	var badge: Dictionary = screen.dash.block_badge
	var fit: bool = dock.get_global_rect().encloses(badge.panel.get_global_rect())
	fit = fit and badge.value.get_theme_font("font").get_string_size(badge.value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, badge.value.get_theme_font_size("font_size")).x <= badge.value.size.x
	for icon in screen.dash.icons.values():
		fit = fit and icon.visible and dock.get_global_rect().encloses(icon.get_global_rect()) and not icon.get_global_rect().intersects(badge.panel.get_global_rect())
	check(fit, "five-digit block and all three active statuses fit without collision")
	check(renderer.meters.mood.reading == "满" and not screen.card_link_button.disabled, "full link follows HUD readings and enables the real link action")
	actor.block = 0
	screen._refresh_ally()
	await settle()
	check(badge.panel.visible and badge.value.text == "0" and badge.value.get_theme_color("font_color").is_equal_approx(Color("7690b5")), "zero block remains in place with the backpack muted color")
	var resources_fit := true
	for meter in renderer.meters.values():
		var row: Control = meter.fill.get_parent()
		resources_fit = resources_fit and dock.get_global_rect().encloses(row.get_global_rect()) and row.get_global_rect().encloses(meter.text.get_global_rect()) and row.get_global_rect().encloses(meter.fill.get_global_rect()) and not meter.fill.get_global_rect().intersects(meter.text.get_global_rect())
	check(resources_fit, "all shared HUD rows, readouts and tracks fit without overlap")
	actor.merge(original, true)
	screen._refresh_ally()
	await settle()
