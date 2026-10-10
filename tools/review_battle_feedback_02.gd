extends SceneTree
## Isolated review fixtures, including controlled critical probability; no game data is saved.
const OUTPUT:="res://预览/战斗反馈_二次完善_v22/"
var frame_index:=0
func _initialize()->void:call_deferred("run")
func run()->void:
	root.size=Vector2i(1000,750)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"frames/"))
	var ignore:=FileAccess.open(OUTPUT+"frames/.gdignore",FileAccess.WRITE);ignore.close()
	var balance:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_balance.json"))
	var engine=load("res://battle/battle_engine.gd").new(20261004)
	engine.add_ally({"id":"player","name":"大肥鱼","level":4,"hp":100,"max_hp":100,"stamina":84,"max_stamina":84,"atk":16,"def":7,"spd":7})
	for kind in ["slime","crab"]:
		var entry:Dictionary=engine.foe_entry_from_monster({"id":kind,"type":kind},balance.monsters[kind])
		entry.hp=180;entry.max_hp=180;engine.add_foe(entry)
	engine.enable_cards(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json")))
	var screen=load("res://battle/battle_screen.gd").new();root.add_child(screen)
	screen.open(engine,{"title":"战斗反馈精修","textures":{"slime":str(balance.monsters.slime.texture),"crab":str(balance.monsters.crab.texture)},"items":[]})
	for n in 24:await process_frame
	screen.skip_playback()
	var titles:Array=["敌方出手","完整格挡","部分格挡","暴击命中","击败消散","同名敌人定位"]
	for scenario in titles.size():
		screen.skip_playback()
		var player:Dictionary=engine.allies[0]
		player.hp=100;player.stamina=84;player.ap=0;player.alive=true;player.block=0;player.shield=0;player.bind=0
		engine.rules.crit_base=1.0 if scenario==3 else 0.0
		engine.rules.crit_per_luck=0.0
		engine.result="";engine.card_energy=3;engine.hand.assign(["water_spear","whale_scout","whale_guard"])
		for i in engine.foes.size():
			var foe:Dictionary=engine.foes[i]
			var kind:String="slime" if i==0 or scenario==5 else "crab"
			foe.kind=kind;foe.name=balance.monsters[kind].name
			foe.hp=180;foe.alive=true;foe.block=0;foe.bind=0;foe.shield=0
			var slot:Dictionary=screen.slots[i]
			slot.art_data=null;slot.defeat_left=0;slot.defeat_alpha=.3;slot.reaction_left=0;slot.attack_left=0
			slot.reaction_offset=Vector2.ZERO;slot.attack_offset=Vector2.ZERO;slot.art.scale=Vector2.ONE
		if scenario==1:player.block=30
		if scenario==2:player.block=5
		if scenario==4:engine.foes[1].hp=1
		screen.mode="command";screen._refresh_all();screen.card_preview.hide()
		screen.title_label.text="战斗反馈 · "+str(titles[scenario])
		for n in 3:await process_frame
		if scenario>=4:
			screen._submit_action({"kind":"card","index":0,"target":1})
		else:
			screen._capture_display_state();engine.events.clear()
			engine.perform(player if scenario==3 else engine.foes[1],{"kind":"attack","target":0})
			screen._ingest({"events":engine.events.duplicate(true),"result":""})
		for n in 40:
			await process_frame
			RenderingServer.force_draw()
			var picture:=root.get_texture().get_image()
			picture.save_jpg(ProjectSettings.globalize_path(OUTPUT+"frames/%04d.jpg" % frame_index),.94)
			if n==(16 if scenario>=4 else 6):picture.save_png(ProjectSettings.globalize_path(OUTPUT+("%02d_" % (scenario+1))+str(titles[scenario])+".png"))
			if scenario==4 and n==4:picture.save_png(ProjectSettings.globalize_path(OUTPUT+"07_致命攻击_命中前.png"))
			if scenario==4 and n==35:picture.save_png(ProjectSettings.globalize_path(OUTPUT+"08_致命攻击_消散完成.png"))
			frame_index+=1
	print("BATTLE FEEDBACK REVIEW COMPLETE ",frame_index," frames")
	screen.close();screen.queue_free();quit()
