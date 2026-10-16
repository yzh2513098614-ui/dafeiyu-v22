extends SceneTree
const Safety=preload("res://character/collision_safety.gd")

var game
var count:=0
var failures:=0
func _initialize() -> void:
	AudioServer.set_bus_mute(0,true);call_deferred("review")
func check(ok: bool,label: String) -> void:
	count+=1
	if ok:print("ROOFTOP PASS: ",label)
	else:failures+=1;push_error("ROOFTOP FAIL: "+label)
func settle(n: int=3) -> void:
	for i in n:await physics_frame
func place(p: Vector3) -> void:
	game.player.position=p;game.player.velocity=Vector3.ZERO;game.silhouette_body.global_position=p
	game.home_controller.set_layers()
func lane(points: Array) -> bool:
	for p: Vector3 in points:
		if not Safety.clear_at(game.player,p) or not Safety.supported(game.player,p):
			print("BLOCKED ",p)
			var query:=PhysicsShapeQueryParameters3D.new();var shape:=CylinderShape3D.new();shape.radius=1.04;shape.height=1.2;query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,p+Vector3.UP*.95);query.collision_mask=1
			for hit in game.player.get_world_3d().direct_space_state.intersect_shape(query):print("COLLIDER ",hit.collider.get_path())
			return false
	return true
func review() -> void:
	root.get_node("MusicDirector").set_process(false)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="whale_home";prefs.world_save_path="user://rooftop_test_world.json";prefs.settings_path="user://rooftop_test_settings.cfg"
	prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false;prefs.values.follow=true;prefs.values.day_cycle=false
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.life_booted=false;game.set_physics_process(false);game.dialogue_controller.save_path="user://rooftop_test_dialogue.json"
	await settle(8);game.dialogue_controller.close();game.dialog_open=false
	var home: Node3D=game.home_controller.level
	check(home.get_meta("gross_floor_area_m2")==4736.0 and is_equal_approx(home.get_meta("outdoor_rooftop_area_m2"),2106.08),"indoor and outdoor areas split")
	check(home.has_node("TowerExterior/OctagonalDaylightCrown") and not home.has_node("ExteriorVilla/WestHipRoof"),"single tower roof replaces full-building roofs")
	if not "--migration-only" in OS.get_cmdline_user_args():
		var doors: Array=home.get_meta("home_room_doors")
		for door: Node3D in doors:
			if door.get_meta("floor_height",0.0)<10:continue
			place(Vector3(10,10.45,-10));door.set_open(true);await settle(55)
			var points: Array=[]
			for i in 21:points.append(door.to_global(Vector3(0,.05,-2+i*.2)))
			check(door.is_passable() and lane(points),"door passage "+door.name)
			place(door.to_global(Vector3(0,.05,0)));door.set_open(false)
			check(door.opened,"close guard "+door.name)
			place(Vector3(10,10.45,-10));door.set_open(false);await settle(55)
			check(not door.opened and not Safety.clear_at(game.player,door.to_global(Vector3(0,.05,0))),"closed blocker "+door.name)
			door.set_open(true);await settle(55)
		var ring: Array=[]
		for x in range(-24,25,2):ring.append(Vector3(x,10.45,-34));ring.append(Vector3(x,10.45,5.5))
		for z in range(-34,5,2):ring.append(Vector3(-24,10.45,z));ring.append(Vector3(24,10.45,z))
		check(lane(ring),"continuous perimeter route and support")
		for p: Vector3 in [Vector3(-28,10.45,-20),Vector3(28,10.45,-20),Vector3(0,10.45,-38),Vector3(0,10.45,8.18)]:check(not Safety.clear_at(game.player,p),"edge guard "+str(p))
		# Walk both ramps with the actual player body and collision mask.
		for spec: Array in [[10.8,2.0,-8.5,0.0],[-10.8,-1.4,-14.0,5.2]]:
			for direction in [1,-1]:
				var start: float=spec[1] if direction==1 else spec[2]-.6
				place(Vector3(spec[0],spec[3]+(.05 if direction==1 else 5.25),start));await settle()
				var blocked:=false
				for i in 220:
					game.player.velocity=Vector3(0,-2,-direction*4.2);game.player.move_and_slide();game.silhouette_body.global_position=game.player.position
					await physics_frame
					if (direction==1 and game.player.position.z<spec[2]-.5) or (direction==-1 and game.player.position.z>spec[1]+.4):break
					if i==219:blocked=true
				check(not blocked,"physical stair "+str(spec[3])+" direction "+str(direction))
		for spec: Array in [["guest_wardrobe",Vector3(-16.8,10.45,-15.4)],["whale_bed",Vector3(-4.25,10.45,-10)],["guest_bed",Vector3(-16.75,10.45,-21.3)],["stargazer",Vector3(19,10.45,-12.9)],["rooftop_tea",Vector3(9,10.45,3.1)]]:
			place(spec[1]);await settle()
			var target: Node3D=game.world.get_node("HomeAction_"+spec[0])
			check(lane([spec[1]]) and game.map_interactions._pick().get("node")==target,"E target "+spec[0])
		place(Vector3(9,10.45,-8));game.overview_mode=false;game.home_controller.cutaway=true;game.home_controller.set_layers()
		check(home.get_node("TowerExterior").visible and home.get_node("Floor2").visible and not game.home_controller._is_exterior_player(),"roof follows camera with tower visible")
		place(Vector3(-10.8,10.45,-18));game.home_controller.set_layers()
		check(not home.get_node("TowerExterior").visible and home.get_node("Floor2").visible,"tower cutaway retains roof platform")
		place(Vector3(0,.05,15));game.home_controller._update_exterior_showcase()
		check(game.overview_mode and home.get_node("ExteriorVilla").visible,"ground exterior showcase")
		place(Vector3(9,10.45,-8));game.home_controller._update_exterior_showcase()
		check(not game.overview_mode,"leaving showcase restores follow camera")
	var legacy_items: Array=[{"id":"plant_snake","pos":[18,10.4,-22],"angle":0},{"id":"plant_snake","pos":[18,15.6,-22],"angle":0}]
	game.room_edits["whale_home"]={"items":legacy_items,"layout":"legacy_roof"}
	game._restore_room_edits();await settle()
	var migrated: Array=game.room_edits["whale_home"].items
	check(migrated.size()==1 and is_equal_approx(float(migrated[0].pos[1]),10.4),"furniture migration respects floor height and support")
	check(game.room_edits["whale_home"].legacy_layout_items.size()==2,"unplaceable furniture retained in migration history")
	var chest: Node3D=game.world.get_node("HomeAction_cabinet_m4p8_10p4_m18p9")
	var storage_id: String=chest.container_id
	game.loot.stocks[storage_id]={"crystal_cluster":3};game.visited["whale_home:door:bedroom"]=true
	check(game.loot.save_state() and game._save(),"isolated inventory and world saved")
	check(game._restore(),"world restores")
	await settle(8)
	check(game.loot.stocks[storage_id].crystal_cluster==3 and game.visited["whale_home:door:bedroom"],"storage ID and door state retained")
	var path: String=prefs.world_save_path
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));data.layout_revision="whale_home_three_floors_v1";data.position=[25,-30];data.position_y=10.4
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	check(game._restore(),"legacy save loads")
	await settle(5)
	check(game.player.position.distance_to(Vector3(-9.6,.05,11))<.1 and game.loot.stocks[storage_id].crystal_cluster==3,"legacy safe spawn preserves contents")
	print("ROOFTOP CHECK: ",count," CHECKS, ",count-failures," PASSED, ",failures," FAILED")
	quit(1 if failures else 0)