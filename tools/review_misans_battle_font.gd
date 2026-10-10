extends SceneTree
const OUTPUT:="res://预览/MiSans战斗字体_v22/"
func _initialize()->void:call_deferred("run")
func capture(file_name:String)->void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+file_name+".png"))
func run()->void:
	root.size=Vector2i(1000,750)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var balance:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_balance.json"))
	var engine=load("res://battle/battle_engine.gd").new(20261005)
	engine.add_ally({"id":"player","name":"大肥鱼","level":4,"hp":100,"max_hp":100,"stamina":84,"max_stamina":84,"atk":16,"def":7})
	for kind in ["slime","crab"]:
		var entry:Dictionary=engine.foe_entry_from_monster({"id":kind,"type":kind},balance.monsters[kind])
		entry.hp=180;entry.max_hp=180;engine.add_foe(entry)
	engine.enable_cards(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json")))
	engine.rules.crit_base=0;engine.rules.crit_per_luck=0;engine.rules.damage_variance=0
	var screen=load("res://battle/battle_screen.gd").new();root.add_child(screen)
	screen.open(engine,{"title":"潮汐试炼 · 格挡数值","textures":{"slime":str(balance.monsters.slime.texture),"crab":str(balance.monsters.crab.texture)},"items":[]})
	for n in 10:await process_frame
	screen.skip_playback()
	engine.hand.assign(["whale_guard","water_spear","whale_scout","pearl_healing","ocean_release"])
	engine.card_energy=3
	engine.foes[0].block=18;engine.foes[0].shield=2;engine.foes[0].haste=2;engine.foes[0].bind=1
	screen.mode="command";screen._refresh_all();screen.card_preview.hide()
	for n in 3:await process_frame
	capture("01_零格挡与敌方格挡")
	screen._submit_action({"kind":"card","index":0,"target":0})
	for n in 48:await process_frame
	screen.card_preview.hide();capture("02_获得格挡13")
	RenderingServer.force_draw()
	var dock:Panel=screen.dash.dock
	var picture:=root.get_texture().get_image()
	var ui_scale:Vector2=Vector2(picture.get_size())/screen.root.size
	var dock_region:=Rect2(dock.global_position*ui_scale,dock.size*ui_scale)
	var crop:Rect2i=Rect2i(dock_region.grow(5)).intersection(Rect2i(Vector2i.ZERO,picture.get_size()))
	picture.get_region(crop).save_png(ProjectSettings.globalize_path(OUTPUT+"07_状态栏图标近景.png"))
	root.size=Vector2i(1920,1080)
	for n in 4:await process_frame
	capture("06_宽屏留白")
	root.size=Vector2i(1000,750)
	for n in 4:await process_frame
	screen.skip_playback();screen._capture_display_state();engine.events.clear()
	engine.perform(engine.foes[1],{"kind":"attack","target":0})
	screen._ingest({"events":engine.events.duplicate(true),"result":""})
	await process_frame;capture("03_命中前格挡保留")
	for n in 16:await process_frame
	screen.card_preview.hide();capture("04_命中后格挡消耗")
	screen.skip_playback();screen._capture_display_state();engine.events.clear()
	engine.perform(engine.allies[0],{"kind":"attack","target":0})
	screen._ingest({"events":engine.events.duplicate(true),"result":""})
	for n in 17:await process_frame
	screen.card_preview.hide();capture("05_敌方格挡消耗")
	print("MISANS FONT REVIEW COMPLETE")
	screen.close();screen.queue_free();quit()
