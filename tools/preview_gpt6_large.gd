extends SceneTree

const OUT := "res://预览/gpt6放大_20261013/"
var screen
var engine
var failures := 0
var results: Array = []

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)
	DisplayServer.window_set_position(Vector2i(-9999, -9999))
	call_deferred("run")

func check(ok: bool, note: String) -> void:
	results.append({"ok": ok, "check": note})
	if not ok:
		failures += 1
		push_error(note)
	else:
		print("PASS ", note)

func settle() -> void:
	for i in 20:
		await process_frame

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await settle()

func open_battle(mixed: bool) -> void:
	engine = load("res://battle/battle_engine.gd").new(20261013)
	engine.add_ally({"id":"player", "name":"大肥鱼", "level":13, "hp":148, "max_hp":148, "stamina":198, "max_stamina":198, "atk":8, "def":7, "spd":9, "ap":100})
	engine.add_foe({"id":"gpt6", "kind":"gpt6", "name":"gpt6", "hp":65, "max_hp":65, "atk":5, "def":1, "spd":1})
	if mixed:
		for id in ["left", "right"]:
			engine.add_foe({"id":id, "kind":"slime", "name":"海沫团", "hp":1000, "max_hp":1000, "atk":3, "def":1, "spd":1})
	engine.enable_cards(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json")))
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_balance.json"))
	screen = load("res://battle/battle_screen.gd").new()
	root.add_child(screen)
	screen.open(engine, {"title":"潮汐遭遇战", "textures":{"gpt6":balance.monsters.gpt6.texture, "slime":balance.monsters.slime.texture}, "items":[{"id":"preview_heal", "name":"测试补给", "count":1, "description":"仅用于检查", "effects":{"heal":10}, "usable":true}]})
	await create_timer(0.7).timeout
	screen.skip_playback()
	screen.card_preview.hide()
	await settle()

func capture(tag: String) -> void:
	var slot: Dictionary = screen.slots[0]
	var art_rect: Rect2 = slot.art.get_rect()
	var original: Texture2D = load("res://assets/monsters/gpt6.png")
	var old_used := original.get_image().get_used_rect()
	var old_scale := minf(250.0 / old_used.size.y, 460.0 / old_used.size.x)
	var old_size := Vector2(old_used.size) * old_scale
	check(art_rect.size.x >= old_size.x * 2.0 and art_rect.size.y >= old_size.y * 2.0, tag + " visible width and height both exceed 2x")
	check(art_rect.position.y >= 104.0, tag + " full portrait below title")
	check(art_rect.end.y <= slot.plate.position.y, tag + " feet clear of nameplate")
	check(not art_rect.intersects(screen.card_panel.get_rect()), tag + " portrait clear of cards")
	check(not art_rect.intersects(screen.log_box.get_rect()), tag + " portrait clear of log")
	check(slot.hit.get_rect().is_equal_approx(art_rect), tag + " enlarged portrait remains selectable")
	for companion in screen.slots:
		if companion.foe != null and str(companion.foe.kind) != "gpt6":
			check(companion.bar_back.get_rect().end.y < screen.log_box.position.y, tag + " companion HP clear of log")
	for child in screen.card_row.get_children():
		check(child.size.y + screen.card_scroll.get_h_scroll_bar().size.y <= screen.card_scroll.size.y, tag + " complete card visible")
	var actions: Array = [screen.card_item_button, screen.card_link_button, screen.card_end_button, screen.card_panel.get_node("CardTargetButton")]
	for a in actions:
		check(a.get_rect().end.x <= screen.card_panel.size.x - 10.0, tag + " action fits")
		for b in actions:
			if a != b:
				check(not a.get_rect().intersects(b.get_rect()), tag + " action buttons do not overlap")
	await settle()
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(OUT + tag + ".png") == OK, tag + " rendered screenshot")
	results.append({"layout":tag, "portrait_size":str(art_rect.size), "original_size":str(old_size), "width_ratio":art_rect.size.x / old_size.x, "height_ratio":art_rect.size.y / old_size.y})

func run() -> void:
	if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():
		push_error("Required isolation flags: --test-session-ui --test-dialogue")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.get_node("MusicDirector").set_enabled(false)
	root.get_node("SfxDirector").set_enabled(false)
	root.get_node("HarborPrefs").values.fullscreen = false
	var texture: Texture2D = load("res://assets/monsters/gpt6_ai_4k.png")
	check(texture.get_size() == Vector2(2160, 3840), "actual 2160x3840 imported texture")
	check(texture.get_image().get_pixel(0,0).a == 0.0, "transparent background")
	root.size = Vector2i(1000, 750)
	await open_battle(false)
	for dimensions in [Vector2i(1000,750), Vector2i(1280,720), Vector2i(800,600)]:
		root.size = dimensions
		await settle()
		await capture("gpt6_%dx%d" % [dimensions.x, dimensions.y])
	await click(screen.card_item_button)
	check(screen.mode == "item", "supply button works after layout change")
	await click(screen.submenu_back)
	check(screen.mode == "command", "return from supply works")
	var before: int = engine.round_no
	await click(screen.card_end_button)
	check(engine.round_no > before, "end turn works")
	screen.skip_playback()
	screen.close()
	screen.queue_free()
	await settle()
	root.size = Vector2i(1000,750)
	await open_battle(true)
	await capture("gpt6_three_targets")
	await click(screen.slots[2].hit)
	check(screen.context.target == 2, "companion remains selectable")
	await click(screen.slots[0].hit)
	check(screen.context.target == 0, "large gpt6 remains selectable")
	var hand_before: int = engine.hand.size()
	await click(screen.card_row.get_child(1))
	check(engine.hand.size() == hand_before - 1, "card play works")
	screen.skip_playback()
	screen.close()
	screen.queue_free()
	await settle()
	var output := FileAccess.open(OUT + "review.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"failures":failures, "results":results}, " "))
	output.close()
	print("GPT6 REVIEW: ", results.size(), " records, ", failures, " failures")
	quit(0 if failures == 0 else 1)
