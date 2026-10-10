extends SceneTree
## Real submitted cards, fixed-timestep rendering, isolated from player save files.
const OUTPUT := "res://预览/攻击反馈_v22/"
var frame_index:=0
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1000,750)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"frames/"))
	var ignore:=FileAccess.open(OUTPUT+"frames/.gdignore",FileAccess.WRITE);ignore.close()
	var cards:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
	var balance:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_balance.json"))
	var engine=load("res://battle/battle_engine.gd").new(20261004)
	engine.add_ally({"id":"player","name":"大肥鱼","level":4,"hp":100,"max_hp":100,"stamina":84,"max_stamina":84,"atk":16,"def":7,"spd":7})
	for kind in ["slime","crab"]:
		var entry:Dictionary=engine.foe_entry_from_monster({"id":kind,"type":kind},balance.monsters[kind])
		entry.hp=180;entry.max_hp=180
		engine.add_foe(entry)
	engine.enable_cards(cards)
	var screen=load("res://battle/battle_screen.gd").new()
	root.add_child(screen)
	screen.open(engine,{"title":"攻击演出预览","textures":{"slime":str(balance.monsters.slime.texture),"crab":str(balance.monsters.crab.texture)},"items":[]})
	for n in 30:await process_frame
	screen.skip_playback()
	var samples:Array=["tidal_slash","water_spear","blue_lightning","whale_impact","echo_summon","bubble_prison","whale_guard","pearl_healing"]
	for sample_index in samples.size():
		var id:String=samples[sample_index]
		engine.hand.assign([id,"whale_scout","whale_guard"])
		engine.card_energy=3
		engine.allies[0].hp=72;engine.allies[0].block=0
		for foe in engine.foes:foe.hp=180;foe.alive=true;foe.bind=0
		screen.mode="command";screen._refresh_all();screen.card_preview.hide()
		screen.title_label.text="攻击演出 · "+str(engine.card_catalog[id].name)
		for n in 4:await process_frame
		screen._submit_action({"kind":"card","index":0,"target":sample_index%2})
		for n in 54:
			await process_frame
			RenderingServer.force_draw()
			var picture:=root.get_texture().get_image()
			picture.save_png(ProjectSettings.globalize_path(OUTPUT+"frames/%04d.png" % frame_index))
			if n==16:picture.save_png(ProjectSettings.globalize_path(OUTPUT+("%02d_" % (sample_index+1))+id+".png"))
			frame_index+=1
		screen.skip_playback()
	print("ATTACK CAPTURE COMPLETE ",frame_index," frames")
	screen.close();screen.queue_free()
	quit()
