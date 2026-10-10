extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,description:String)->void:
	if not ok:failures+=1;push_error(description)
	else:print("PASS ",description)
func run()->void:
	root.size=Vector2i(1000,750)
	var engine=load("res://battle/battle_engine.gd").new(20261004)
	engine.add_ally({"id":"player","name":"大肥鱼","hp":100,"max_hp":100,"stamina":84,"max_stamina":84,"atk":16,"def":7,"spd":7})
	engine.add_foe({"id":"dummy","kind":"slime","name":"木桩","hp":1000,"max_hp":1000,"atk":2,"def":1,"spd":1})
	engine.enable_cards(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json")))
	var screen=load("res://battle/battle_screen.gd").new()
	root.add_child(screen)
	screen.open(engine,{"textures":{"slime":"res://assets/monsters/sea_slime.png"},"items":[]})
	for n in 5:await process_frame
	screen.skip_playback()
	engine.hand.assign(["water_spear","whale_scout"]);engine.card_energy=3
	screen.mode="command";screen._refresh_all()
	for n in 3:await process_frame
	var dock_position:Vector2=screen.dash.dock.position
	screen._submit_action({"kind":"card","index":0,"target":0})
	await create_timer(.08).timeout
	check(screen.fx_layer.get_node_or_null("PlayedCard")!=null,"played card has its own transient flight")
	check(screen.card_panel.visible and screen.card_end_button.disabled,"hand stays visible and blocks repeated submissions while busy")
	await create_timer(.36).timeout
	var effect=screen.fx_layer.get_node_or_null("AttackEffect_spear")
	check(effect!=null,"actual submitted spear produces its distinct effect")
	if effect!=null:
		check(effect.destination.distance_to(screen._enemy_anchor("木桩"))<12,"effect follows the correct target in a small window")
	check(screen.dash.dock.position==dock_position,"world impact leaves HUD layout stable")
	screen.skip_playback()
	await create_timer(.25).timeout
	check(screen.fx_layer.get_child_count()==0,"skip cancels outstanding feedback callbacks and visuals")
	check(engine.hand.size()==1 and screen.mode=="command" and not screen.card_end_button.disabled,"skip preserves settled card state and restores actions")
	screen._submit_action({"kind":"card","index":99,"target":0})
	await create_timer(.05).timeout
	check(screen.fx_layer.get_child_count()==0,"rejected cards emit no attack effects")
	screen.skip_playback();screen.speed_index=2
	var fast=screen._spawn_fx("wave",Vector2(400,540),Vector2(400,330))
	check(fast!=null and fast.playback_speed==4.0,"effects obey four-times playback")
	screen._play_damage_fx({"type":"damage","actor":"大肥鱼","actor_side":"ally","target":"木桩","amount":10})
	screen.close()
	await create_timer(.15).timeout
	check(not screen.is_active(),"closing during an attack safely cancels delayed feedback")
	screen.queue_free()
	print("ATTACK FEEDBACK FAILURES ",failures)
	quit(0 if failures==0 else 1)
