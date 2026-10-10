extends SceneTree
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	if ok:print("PASS ",message)
	else:failures+=1;push_error(message)
func run()->void:
	root.size=Vector2i(1000,750)
	var engine=load("res://battle/battle_engine.gd").new(20261004)
	engine.add_ally({"id":"player","name":"大肥鱼","hp":100,"max_hp":100,"stamina":84,"max_stamina":84,"atk":16,"def":7,"spd":7})
	for id in ["left","right"]:engine.add_foe({"id":id,"kind":"slime","name":"海沫团","hp":1000,"max_hp":1000,"atk":17,"def":1,"spd":1})
	engine.enable_cards(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json")))
	var screen=load("res://battle/battle_screen.gd").new();root.add_child(screen)
	screen.open(engine,{"textures":{"slime":"res://assets/monsters/sea_slime.png"},"items":[]})
	for n in 5:await process_frame
	screen.skip_playback();engine.hand.assign(["water_spear"]);engine.card_energy=3
	screen.mode="command";screen._refresh_all()
	for n in 3:await process_frame
	screen._submit_action({"kind":"card","index":0,"target":1})
	var settled_hp:float=engine.foes[1].hp
	var rng_state:int=engine.rng.state
	await create_timer(.34).timeout
	check(screen.slots[1].hp.text=="1000 / 1000","blood bar retains pre-hit health during the cast")
	var effect=screen.fx_layer.get_node_or_null("AttackEffect_spear")
	check(effect!=null and effect.destination.distance_to(screen._enemy_anchor("海沫团","right"))<12,"same-name enemies resolve effects by unique ID")
	await create_timer(.14).timeout
	check(screen.slots[1].hp.text=="%d / 1000" % ceili(settled_hp),"health display updates at the impact")
	check(screen.slots[0].hp.text=="1000 / 1000" and float(screen.slots[0].get("reaction_left",0))==0,"neighbour with the same name does not flash or lose displayed health")
	var shown_loss:=1000-ceili(settled_hp)
	var found_number:=false
	for child in screen.fx_layer.get_children():
		if child is Label and child.text==str(shown_loss):found_number=true
	check(found_number and str(screen.log_lines.back()).contains("  %d" % shown_loss),"floating damage and battle log agree with the visible HP loss")
	check(engine.rng.state==rng_state,"presentation does not consume gameplay random numbers")
	screen.skip_playback()
	engine.foes[1].hp=1;engine.foes[1].alive=true
	engine.hand.assign(["tidal_slash"]);engine.card_energy=3;screen.mode="command";screen._refresh_all()
	screen._submit_action({"kind":"card","index":0,"target":1})
	await create_timer(.06).timeout
	check(screen.slots[1].art.modulate.a>.9,"lethal settlement does not hide the target before the attack")
	await create_timer(1.02).timeout
	check(screen.slots[1].art.modulate.a<.01 and screen.slots[0].art.modulate.a>.9,"defeat animation removes only the defeated enemy")
	screen.skip_playback();engine.allies[0].block=100
	screen.mode="command";screen._refresh_all();screen._capture_display_state()
	engine.events.clear();engine.perform(engine.foes[0],{"kind":"attack","target":0})
	screen._ingest({"events":engine.events.duplicate(true),"result":""})
	await create_timer(.05).timeout
	check(screen.fx_layer.get_node_or_null("AttackEffect_windup")!=null,"enemy attack identifies the acting enemy")
	check(screen.dash.block_badge.value.text=="100","block badge retains its value before impact")
	await create_timer(.14).timeout
	check(screen.fx_layer.get_node_or_null("AttackEffect_shield")!=null and screen.dash.gauges[0].value.text=="100 / 100","fully blocked attack displays a shield without health loss")
	check(screen.dash.block_badge.value.text==str(ceili(float(engine.allies[0].block))),"block badge consumes the absorbed amount at impact")
	screen.skip_playback();engine.rules.crit_base=1.0;engine.allies[0].block=0
	screen._capture_display_state();engine.events.clear()
	engine.perform(engine.allies[0],{"kind":"attack","target":0})
	screen._ingest({"events":engine.events.duplicate(true),"result":""})
	await create_timer(.18).timeout
	check(screen.fx_layer.get_node_or_null("AttackEffect_critical")!=null,"critical event adds its own impact accent")
	screen.skip_playback()
	engine.foes[1].alive=true;engine.foes[1].hp=1000
	engine.allies[0].hp=100;engine.allies[0].alive=true;engine.allies[0].block=0
	engine.rules.crit_base=0;engine.rules.crit_per_luck=0;engine.rules.damage_variance=0
	screen._capture_display_state();engine.events.clear()
	engine.perform(engine.foes[0],{"kind":"attack","target":0})
	engine.perform(engine.foes[1],{"kind":"attack","target":0})
	var first_hp:float=engine.events[0].target_state.hp
	check(first_hp>float(engine.allies[0].hp),"first event keeps an immutable intermediate health snapshot")
	screen._ingest({"events":engine.events.duplicate(true),"result":""})
	await create_timer(.2).timeout
	check(screen.dash.gauges[0].value.text=="%d / 100" % ceili(first_hp),"consecutive enemy hits show intermediate health instead of final turn health")
	await create_timer(.3).timeout
	check(screen.dash.gauges[0].value.text=="%d / 100" % ceili(float(engine.allies[0].hp)),"second hit advances the health display to the settled value")
	screen.skip_playback();engine.foes[0].block=18;engine.foes[0].shield=0
	engine.foes[0].bind=1;engine.foes[0].haste=2
	engine.allies[0].block=0
	screen.mode="command";screen._refresh_all();screen._capture_display_state()
	check(screen.dash.block_badge.panel.visible and screen.dash.block_badge.value.text=="0","zero block retains a quiet labelled HUD slot")
	check(screen.slots[0].block_badge.panel.visible and screen.slots[0].block_badge.value.text=="18","enemy block has its own numeric shield badge")
	var badge_rect:=Rect2(screen.slots[0].block_badge.panel.position,screen.slots[0].block_badge.panel.size)
	for status in screen.slots[0].status:
		if status.visible:check(not badge_rect.intersects(Rect2(status.position,status.size)),"enemy block badge is separate from timed status icons")
	check(screen.dash.block_badge.panel.position.y+screen.dash.block_badge.panel.size.y<=screen.dash.dock.size.y,"block badge fits within the status dock")
	engine.events.clear();engine.perform(engine.allies[0],{"kind":"attack","target":0})
	screen._ingest({"events":engine.events.duplicate(true),"result":""})
	await create_timer(.05).timeout
	check(screen.slots[0].block_badge.value.text=="18","enemy block retains pre-impact value")
	await create_timer(.15).timeout
	check(screen.slots[0].block_badge.value.text==str(ceili(float(engine.foes[0].block))),"enemy block consumes at the same impact as player block")
	screen.skip_playback();engine.allies[0].block=12345;screen.mode="command";screen._refresh_all()
	var large_badge:Dictionary=screen.dash.block_badge
	check(large_badge.value.get_theme_font("font").get_string_size("12345",HORIZONTAL_ALIGNMENT_LEFT,-1,large_badge.value.get_theme_font_size("font_size")).x<=large_badge.value.size.x,"large block values remain readable without clipping")
	check(large_badge.icon.size.is_equal_approx(Vector2(40,40)),"large block amounts do not stretch the shield symbol")
	check(large_badge.caption.position.x+large_badge.caption.size.x+12<=large_badge.value.position.x,"block label stays separate from the emphasized number")
	check(large_badge.panel.position.x+large_badge.panel.size.x+12<=screen.dash.gauges[0].group.position.x,"large block values stay clear of the health resource")
	screen.close();screen.queue_free()
	print("BATTLE PRESENTATION FAILURES ",failures)
	quit(0 if failures==0 else 1)
