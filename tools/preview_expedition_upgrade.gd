extends SceneTree
## One short playable smoke session; all inventory and saves use preview fixtures.
var game
var expedition
var failed:=false

func _initialize() -> void:call_deferred("play")

func check(ok: bool, note: String) -> void:
	print(("OK: " if ok else "FAIL: ")+note)
	if not ok:failed=true

func capture(name: String) -> void:
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/敌群配装_"+name+".png")

func press(text: String) -> void:
	for button in expedition.modal.find_children("*","Button",true,false):
		if button.text==text and not button.disabled:button.pressed.emit();return

func play() -> void:
	root.size=Vector2i(1000,750)
	var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="research";prefs.values.fullscreen=false;prefs.values.day_cycle=false
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	for i in 10:await process_frame
	expedition=game.expedition_controller
	expedition.state=load("res://expedition/run_state.gd").new(expedition.data)
	expedition.state.save_path="res://预览/expedition_smoke_save.json"
	expedition.state.profile.warehouse={"parts":6,"chip":2,"fragments":8,"storage":4}
	expedition.open_loadout();press("制作");press("选用")
	check(expedition.state.profile.modules.barrier==1 and expedition.state.profile.warehouse.parts==3,"craft button spends warehouse materials and selects equipment")
	await capture("装备工坊")
	expedition.briefing();expedition.start_run(false)
	check(expedition.state.run.module=="barrier" and expedition.state.profile.modules.barrier==0,"departing carries a real equipment item")
	expedition.state.insure_module();expedition.state.run.bag.sample=1;expedition.state.run.quest=true
	expedition.open_bag();await capture("背包保险");expedition._close_panel()
	game.player.position=Vector3(-9,0,-6)
	for i in 3:await physics_frame
	expedition.state.run.trace=70;expedition.state.run.known.event_signal_lab="hallucination"
	expedition.selected_object={"id":"signal_lab","enemy":"hallucination"}
	expedition._inspect_signal();await capture("敌群预警")
	expedition.start_combat("hallucination","signal_lab")
	check(expedition.engine.enemy_ids().size()==3 and expedition.presenter.sprites.size()==3,"three enemies enter the actual scene together")
	check(expedition.engine.hand.size()+expedition.engine.draw_pile.size()==23,"20 base cards plus two equipment skills and one medical card")
	expedition.engine.hand=["data_probe","firewall","token_burst","prompt_injection","gradient_descent"]
	expedition._render_battle();expedition.choose_enemy("enemy_2");expedition.choose_card(1);expedition.choose_card(2);expedition.choose_card(0)
	check(expedition.engine.queue[1].target_actor=="enemy_2","attack locks the selected enemy")
	await capture("三敌同步指令")
	var before: int=expedition.engine.units.enemy_2.hp
	expedition.fast=true;expedition.presenter.fast=true
	await expedition.execute_queue()
	check(expedition.engine.units.enemy_2.hp<before and expedition.mode=="battle","one full window replays and returns to planning")
	print("TARGET HP: ",before," -> ",expedition.engine.units.enemy_2.hp," / BUTTON: ",expedition.enemy_buttons.enemy_2.text)
	await capture("窗口结算")
	expedition.checkpoint_save()
	var restored=load("res://expedition/combat_simulator.gd").new(expedition.data)
	restored.restore(JSON.parse_string(FileAccess.get_file_as_string(expedition.state.save_path)).run.combat.engine)
	check(restored.enemy_ids().size()==3 and restored.units.enemy_2.hp==expedition.engine.units.enemy_2.hp,"save restores the complete enemy group")
	expedition.engine.result="disengaged";expedition._end_combat()
	check(not expedition.state.run.cleared.get("signal_lab",false),"disengaging keeps the enemy signal on the map")
	expedition.finish_run(false)
	check(expedition.state.profile.modules.barrier==1,"insured equipment returns after failure")
	await capture("结算")
	expedition._return_harbor()
	print("ENEMY GROUP PLAY SESSION: ", "FAIL" if failed else "OK")
	quit(1 if failed else 0)

