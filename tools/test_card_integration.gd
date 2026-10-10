extends SceneTree
## Opens an actual trial encounter on isolated test paths; never settles it.
var failures := 0
func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: print("PASS ", label)
	else:
		failures += 1
		push_error("FAIL " + label)

func run() -> void:
	var prefs = root.get_node("HarborPrefs")
	prefs.continue_game = false
	prefs.starting_place = "trial"
	prefs.values.fullscreen = false
	prefs.values.follow = true
	prefs.apply_window()
	root.size = Vector2i(1000, 750)
	var game = load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game); current_scene = game
	for n in 12: await process_frame
	game.loot.save_path = "user://card_integration_inventory.json"
	game.dialogue_controller.save_path = "user://card_integration_dialogue.json"
	game.dialogue_controller.close()
	game.character_controller.model.state.combat.defeated.clear()
	var combat = game.combat_controller
	combat.world_changed()
	check(game.location_id == "trial" and combat.markers.size() > 0, "trial encounter is available")
	if combat.markers.is_empty(): quit(1); return
	combat.near = combat.markers[0]
	combat.fight()
	check(combat.screen != null and combat.screen.engine.card_mode, "encounter opens the card battle")
	if combat.screen == null: quit(1); return
	var screen = combat.screen
	for n in 15: await process_frame
	screen.skip_playback()
	check(screen.engine.hand.size() == 5 and screen.card_row.get_child_count() == 5, "battle draws and renders five cards")
	var before_round: int = screen.engine.round_no
	(screen.card_row.get_child(0) as Button).pressed.emit()
	check(screen.engine.round_no == before_round and screen.engine.discard_pile.size() > 0, "real encounter plays a card before enemy turn")
	screen.skip_playback()
	screen._submit_action({"kind":"end_turn"})
	check(screen.engine.round_no == before_round + 1, "end turn advances real encounter")
	print("CARD INTEGRATION FAILURES ", failures)
	quit(0 if failures == 0 else 1)
