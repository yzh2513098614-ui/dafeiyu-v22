extends SceneTree
## Real rendered capture of the card hand; does not load or write save data.
const OUTPUT := "res://预览/战斗UI_二次精修_v22/"
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
	await create_timer(0.7).timeout
	screen.card_preview.hide()
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "01_手牌与敌方意图.png"))
	root.size = Vector2i(1000,750)
	for n in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "09_默认窗口_初始.png"))
	var actor:Dictionary=engine.allies[0]
	var previous_hp:float=float(actor.hp)
	var previous_stamina:float=float(actor.stamina)
	actor.hp=35;actor.stamina=34
	screen._refresh_ally()
	screen._set_gauge(screen.dash.gauges[2],60,100,"60%")
	for n in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+"10_受伤与进度条材质.png"))
	actor.hp=previous_hp;actor.stamina=previous_stamina
	screen._refresh_ally()
	root.size = Vector2i(1448,1086)
	for n in 8: await process_frame
	screen._preview_card(engine.card_hand_view()[0])
	for n in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "05_卡牌放大预览.png"))
	screen.card_preview.hide()
	if engine.hand.size() > 0:
		screen._submit_action({"kind":"card","index":0,"target":0})
		screen.skip_playback()
		for n in 8: await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "02_打出一张技能牌.png"))
	root.size = Vector2i(1000, 750)
	for n in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "03_默认窗口尺寸.png"))
	root.size = Vector2i(1280,720)
	for n in 8: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "06_宽屏战斗界面.png"))
	root.size = Vector2i(1448,1086)
	engine.hand.clear()
	for entry in cards.slice(0,8): engine.hand.append(str(entry.id))
	screen.mode = "command"
	screen._refresh_cards()
	for n in 5: await process_frame
	screen.card_preview.hide()
	screen.card_scroll.scroll_horizontal = 160
	for n in 3: await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "07_多张手牌滚动.png"))
	screen.context["pending_result"] = "win"
	screen._finish_playback()
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "08_新版胜利结算.png"))
	screen.context["result_provider"] = Callable(self,"reward_fixture")
	screen._finish_playback()
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "12_胜利奖励格.png"))
	screen.context["result_provider"] = null
	actor.hp=0;actor.stamina=0
	screen.context["pending_result"] = "lose"
	screen._finish_playback()
	await create_timer(0.7).timeout
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT + "11_休息恢复结算.png"))
	print("CARD CAPTURE COMPLETE")
	quit()

func reward_fixture(_result:String)->Dictionary:
	return {"summary":"获得经验 24 · 战利品已收进背包","saved":true,"items":[{"name":"贝壳币","count":80},{"name":"小体力药","count":2},{"name":"海盐糖","count":1}]}





