extends SceneTree
## A short real-game session, isolated from the player's saves.
var game
var pack
var failed:=false

func _initialize() -> void:call_deferred("play")

func check(ok: bool,note: String) -> void:
	print(("OK: " if ok else "FAIL: ")+note)
	if not ok:failed=true

func capture(name: String) -> void:
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://预览/26地图_"+name+".png")

func press_modal(text: String) -> void:
	for button in pack.modal.find_children("*","Button",true,false):
		if button.text==text and not button.disabled:button.pressed.emit();return

func walk_to(goal: Vector3) -> void:
	for i in 260:
		var offset: Vector3=goal-game.player.position;offset.y=0
		if offset.length()<.13:break
		game.movement=game._character_screen_travel(offset).normalized()
		await physics_frame
	game.movement=Vector2.ZERO
	for i in 6:await physics_frame
	print("WALK: ",game.player.position," -> ",goal)

func play() -> void:
	root.size=Vector2i(1100,825)
	var fixture:=FileAccess.open("res://预览/pack26_smoke_save.json",FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"progress":{},"remaining":{},"bag":{},"checkpoints":{}}));fixture.close()
	var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="city";prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.music=false;prefs.values.sfx=false
	var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
	menu._show_page("pack26");check(menu.cards.size()==26,"all 26 maps are selectable in the real start menu")
	await capture("出发选择");menu.free()
	prefs.starting_place="pack26_foodhall"
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	for i in 15:await process_frame
	pack=game.pack26_controller
	game.expedition_controller.state=load("res://expedition/run_state.gd").new(game.expedition_controller.data)
	game.expedition_controller.state.save_path="res://预览/pack26_warehouse_smoke.json"
	var registered:=0
	for id in game.locations:
		if id.begins_with("pack26_"):registered+=1
	check(registered==26 and pack.is_active() and game.player.motion_mode==CharacterBody3D.MOTION_MODE_GROUNDED,"v22 uses the original maps and a grounded eight-direction player")
	await capture("餐饮市场入口")
	game._toggle_view();await capture("餐饮市场总览");game._toggle_view()
	game.player.position=Vector3(3.1,.08,12.65);game.player.velocity=Vector3.ZERO
	for i in 6:await physics_frame
	game._interact();check(pack.mode=="loot","the game's existing interaction button opens the original search container")
	press_modal("收取一件");press_modal("收取一件")
	check(pack.bag.has("Token代币") and pack.bag.has("导览资料"),"search keeps original item names and removes fixed container stock")
	await capture("搜索容器");pack.close();game.loot.open_bag()
	check(pack.mode=="bag" and game.loot.mode=="","the existing inventory button opens the new map bag")
	await capture("新区背包");pack.close()
	var stair: Dictionary=pack.definition.stairs[0]
	game.player.position=Vector3(stair.start[0],stair.start[1]+.12,stair.start[2]);game.player.velocity=Vector3.ZERO
	for i in 12:await physics_frame
	for point in stair.turn_points:await walk_to(Vector3(point[0],point[1],point[2]))
	await walk_to(Vector3(stair.end[0],stair.end[1],stair.end[2]))
	check(game.player.position.y>3.3 and absf(game.player.position.x-stair.end[0])<.3,"the actual character climbs a dogleg staircase to 2F without a floor teleport")
	await capture("二层楼梯")
	game._save();var elevated: Vector3=game.player.position;game._travel("city");game._restore()
	for i in 8:await physics_frame
	check(game.location_id=="pack26_foodhall" and game.player.position.distance_to(elevated)<.25 and pack.bag.has("导览资料"),"save restores the same floor height and searched inventory")
	var exit_marker=pack.level.get_node("Interactions/foodhall_extract_10")
	game.player.position=exit_marker.global_position+Vector3(0,.08,0);game.player.velocity=Vector3.ZERO
	for i in 6:await physics_frame
	game._interact()
	await create_timer(5.3).timeout
	check(pack.mode=="extracted" and pack.bag.is_empty() and game.expedition_controller.state.profile.warehouse.get("token",0)==1 and game.expedition_controller.state.profile.warehouse.get("fragments",0)==1,"standing at the real extraction marker deposits materials into the existing crafting warehouse")
	await capture("撤离入库");pack.close()
	for id in ["school","hospital"]:
		game._travel("pack26_"+id)
		for i in 8:await physics_frame
		check(pack.current_id==id and game.player.is_on_floor(),id+" enters with original geometry and floor collision")
		game._toggle_view();await capture(id+"总览")
	game._show_map(true)
	var guide=game.map_panel.get_child(0);guide.selected_group="complex";guide._draw_cards();guide._tab_states()
	check(guide.grid.get_child_count()==26,"the in-game guide contains all map thumbnails and travel buttons")
	await capture("游戏导览");game._show_map(false);game._travel("city")
	check(not pack.is_active() and game.player.motion_mode==CharacterBody3D.MOTION_MODE_FLOATING and not game.loot.chests.is_empty(),"returning restores the original harbor controls and containers")
	print("PACK26 PLAY SESSION: ","FAIL" if failed else "OK")
	quit(1 if failed else 0)
