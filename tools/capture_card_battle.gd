extends SceneTree
## Real rendered capture of the card hand; does not load or write save data.
const OUTPUT := "res://预览/卡牌战斗_v22/"
func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.size = Vector2i(1448, 1086)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var cards: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_balance.json"))
	var engine = load("res://battle/battle_engine.gd").new(20261004)
	engine.add_ally({"id":"player","name":"大肥鱼","level":4,"hp":100,"max_hp":100,"stamina":84,"max_stamina":84,"atk":16,"def":7,"spd":7,"stats":{"luck":4}})
	for kind in ["slime", "crab"]:
		engine.add_foe(engine.foe_entry_from_monster({"id":kind,"type":kind}, balance.monsters[kind]))
	engine.enable_cards(cards)
	var textures := {"slime":str(balance.monsters.slime.texture), "crab":str(balance.monsters.crab.texture)}
	var screen = load("res://battle/battle_screen.gd").new()
	root.add_child(screen)
	screen.open(engine, {"title":"潮汐试炼 · 卡牌战斗", "textures":textures, "items":[]})
	for n in 25: await process_frame
	screen.skip_playback()
	for n in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "01_手牌与敌方意图.png"))
	if engine.hand.size() > 0:
		screen._submit_action({"kind":"card","index":0,"target":0})
		screen.skip_playback()
		for n in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "02_打出一张技能牌.png"))
	root.size = Vector2i(1000, 750)
	for n in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "03_默认窗口尺寸.png"))
	print("CARD CAPTURE COMPLETE")
	quit()
