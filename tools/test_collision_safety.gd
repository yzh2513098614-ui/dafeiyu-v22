extends SceneTree
## Run with Godot --headless --path PROJECT --script res://tools/test_collision_safety.gd -- --test-expedition --test-dialogue
var game
var checks: Array=[]
var fixture: Node3D

func _initialize() -> void:call_deferred("run")

func check(ok: bool,label: String,detail: Variant=null) -> void:
	checks.append({"ok":ok,"check":label,"detail":detail})
	if not ok:print("COLLISION FAIL ",label," ",detail)

func body(size: Vector3,position: Vector3,angle: float=0,layer: int=1) -> StaticBody3D:
	var solid:=StaticBody3D.new();solid.collision_layer=layer
	var hit:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;hit.shape=shape
	solid.add_child(hit);solid.position=position;solid.rotation.y=angle;fixture.add_child(solid)
	return solid

func clear_fixture() -> void:
	if is_instance_valid(fixture):fixture.free()
	fixture=Node3D.new();game.world.add_child(fixture)
	game.player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	game.player.collision_mask=1;game.player.velocity=Vector3.ZERO
	game.collision_has_safe=false;game.collision_recovery_pending=false

func drive(direction: Vector3,speed: float,frames: int,grounded: bool=false) -> void:
	for i in frames:
		game.player.velocity.x=direction.x*speed;game.player.velocity.z=direction.z*speed
		game.player.velocity.y=(0.0 if game.player.is_on_floor() else game.player.velocity.y-18.0/60.0) if grounded else 0.0
		game._move_character(1.0/60.0,grounded)

func run() -> void:
	Engine.physics_ticks_per_second=60
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="city";prefs.values.fullscreen=false
	prefs.world_save_path="res://预览/穿模修复_world_test.json"
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_physics_process(false)
	game.loot.save_path="res://预览/穿模修复_loot_test.json"
	if game.dialogue_controller.active:game.dialogue_controller.close()
	var maps:=0
	for id in game.locations:
		game.changing=false;game._travel(id);game.set_physics_process(false)
		if game.pack26_controller:game.pack26_controller.save_path="res://预览/穿模修复_pack_test.json"
		await physics_frame;await physics_frame
		var grounded: bool=game.player.motion_mode==CharacterBody3D.MOTION_MODE_GROUNDED
		check(game._recover_character(grounded),"safe spawn "+id,game.player.position)
		check(game.location_id==id,"map constructed "+id)
		var spawn: Vector3=game.player.position
		for direction in 8:
			game.player.position=spawn;game.player.velocity=Vector3.ZERO
			var angle: float=direction*TAU/8
			drive(Vector3(cos(angle),0,sin(angle)),6.0,12,grounded)
			check(game.CollisionSafety.clear_at(game.player,game.player.position),"eight directions "+id+" "+str(direction))
		if grounded:
			for slope in game.pack26_controller.level.get_node("Architecture").find_children("StairSupport","StaticBody3D",true,false):
				var hit: CollisionShape3D=slope.get_node("Shape")
				if not hit.shape is ConvexPolygonShape3D:continue
				var points: PackedVector3Array=hit.shape.points
				var front: float=-INF;var back: float=INF
				for point in points:front=maxf(front,point.z);back=minf(back,point.z)
				var low: float=-INF;var high: float=-INF
				for point in points:
					if is_equal_approx(point.z,front):low=maxf(low,point.y)
					if is_equal_approx(point.z,back):high=maxf(high,point.y)
				if high-low<.5:continue
				game.player.global_position=hit.to_global(Vector3(0,low+.25*(high-low)/(front-back)+.02,front-.25))
				game.player.velocity=Vector3.ZERO;game.collision_recovery_pending=false
				var climb: Vector3=(hit.global_basis*Vector3(0,0,-1)).normalized()
				var peak: float=game.player.global_position.y
				for step in ceili((front-back)/2.4*120)+90:
					drive(climb,2.4,1,true);peak=maxf(peak,game.player.global_position.y)
				var collisions: Array=[]
				for actor in [game.player,game.silhouette_body]:
					for index in actor.get_slide_collision_count():
						var contact: KinematicCollision3D=actor.get_slide_collision(index)
						collisions.append({"body":str(contact.get_collider().get_path()),"normal":contact.get_normal()})
				check(peak>hit.to_global(Vector3(0,high,back)).y-.012,"real staircase "+id+" "+slope.get_parent().name,{"peak":peak,"target":hit.to_global(Vector3(0,high,back)).y,"position":game.player.global_position,"collisions":collisions})
				# Descend along the same ramp, rather than teleporting between floors.
				game.player.global_position=hit.to_global(Vector3(0,high-.25*(high-low)/(front-back)+.12,back+.25))
				game.player.velocity=Vector3.ZERO;game.collision_recovery_pending=false
				var bottom: float=game.player.global_position.y
				for step in ceili((front-back)/2.4*120)+90:
					drive(-climb,2.4,1,true);bottom=minf(bottom,game.player.global_position.y)
				check(bottom<hit.to_global(Vector3(0,low,front)).y+.30,"real staircase descent "+id+" "+slope.get_parent().name,{"bottom":bottom,"target":hit.to_global(Vector3(0,low,front)).y})
		maps+=1
		if maps%10==0:print("COLLISION MAPS ",maps)
	# Actual map gates and drawer, including obstruction during an instant pose.
	game._travel("pack26_hospital");game.set_physics_process(false)
	await physics_frame;await physics_frame
	var stair_hit: CollisionShape3D=game.pack26_controller.level.get_node("Architecture/PublicWestStair/StairSupport/Shape")
	game.player.global_position=stair_hit.to_global(Vector3(2.0,.02,0));game._configure_character_collision(true)
	check(not game.CollisionSafety.clear_at(game.player,game.player.position),"saved position intersecting stair silhouette is rejected")
	check(game._recover_character(true) and game.CollisionSafety.clear_at(game.player,game.player.position),"stair-side saved position recovers without engine pushing through geometry")
	var gate=game.pack26_controller.level.get_node("Gates").get_child(0)
	gate.set_physics_process(false)
	game.player.position=gate.global_position+Vector3(0,0,3)
	gate.apply_state(true,true);await physics_frame
	check(gate.opened,"gate opens when clear")
	game.player.position=gate.global_position
	gate.apply_state(false);gate._physics_process(.8)
	check(gate.openness>.99,"gate refuses to close on player")
	game.player.position=gate.global_position+Vector3(0,0,4)
	gate._physics_process(.8);await physics_frame
	check(gate.openness<.01 and not gate.get_node("Blocker/Shape").disabled,"gate closes after player leaves")
	var cabinet=game.pack26_controller.level.get_node("Furnishings/lib_searchable_file_cabinet_180")
	game.player.position=cabinet.global_position+Vector3(0,0,4)
	cabinet.set_open_state(true,false)
	check(cabinet.moving_clearance.shapes.size()>0,"drawers have moving collision")
	var moving: CollisionShape3D=cabinet.moving_clearance.shapes[0]
	game.player.position=moving.global_position-Vector3(0,.65,0)
	cabinet.set_open_state(false,false)
	check(cabinet.animation_obstructed,"drawer pauses on player")
	game.player.position=cabinet.global_position+Vector3(0,0,4)
	cabinet._physics_process(.016)
	check(not cabinet.animation_obstructed and cabinet.progress<.001,"drawer resumes after player leaves")
	# Synthetic geometry isolates thin walls/corners/passages from level design.
	if game.pack26_controller:game.pack26_controller.leave()
	game.atmosphere.set_process(false)
	game._clear_world()
	for key in ["floor_contours","floor_contour","layout_revision"]:
		if game.shell.has_meta(key):game.shell.remove_meta(key)
	game.space_bounds=Vector2(200,200)
	for angle in [0.0,PI/8,PI/4,PI/2,PI*.75]:
		for speed in [2.4,6.0,120.0,1500.0]:
			clear_fixture();body(Vector3(16,3,.04),Vector3(0,1.5,0),angle)
			await physics_frame
			var normal:=Vector3(sin(angle),0,cos(angle))
			game.player.position=normal*3.5
			drive(-normal,speed,120)
			check(game.player.position.dot(normal)>.9 and game.CollisionSafety.clear_at(game.player,game.player.position),"thin wall angle %.2f speed %.1f"%[angle,speed],game.player.position)
	clear_fixture();body(Vector3(12,3,.08),Vector3(4,1.5,0));body(Vector3(.08,3,12),Vector3(0,1.5,4))
	await physics_frame
	game.player.position=Vector3(3,0,3);drive(Vector3(-1,0,-1).normalized(),6,120)
	check(game.player.position.x>.9 and game.player.position.z>.9,"concave corner blocks both axes",game.player.position)
	clear_fixture();body(Vector3(5,3,.10),Vector3(-3.7,1.5,0));body(Vector3(5,3,.10),Vector3(3.7,1.5,0))
	await physics_frame
	game.player.position=Vector3(0,0,3);drive(Vector3(0,0,-1),6,90)
	check(game.player.position.z< -2,"2.4 metre doorway remains passable",game.player.position)
	clear_fixture();body(Vector3(4,.30,.40),Vector3(0,1.2,0))
	await physics_frame
	game.player.position=Vector3(0,0,3);drive(Vector3(0,0,-1),6,90)
	check(game.player.position.z>.9,"head/body stop at raised furniture")
	game.player.position=Vector3.ZERO;game.collision_has_safe=false
	check(game._recover_character(false) and game.CollisionSafety.clear_at(game.player,game.player.position),"embedded saved position recovers")
	clear_fixture();await physics_frame
	game.player.position=Vector3(0,0,0)
	var placement:=body(Vector3(2,.35,.5),Vector3(0,1.2,0))
	check(game._placement_overlaps_character(placement),"same-frame furniture placement protects upper body")
	placement.position.x=4
	check(not game._placement_overlaps_character(placement),"clear furniture placement remains allowed")
	# A walkable ramp followed by a raised landing tests the new upper guards.
	clear_fixture();body(Vector3(20,.10,20),Vector3(0,-.05,0),0,2)
	var pitch:=atan(1.0/3.2)
	var end_z: float=3.4*cos(pitch)*.5
	var rise: float=3.4*sin(pitch)
	var ramp=body(Vector3(2.8,.10,3.4),Vector3(0,rise*.5-.05*cos(pitch),0),0,2);ramp.rotation.x=pitch
	body(Vector3(2.8,.15,3),Vector3(0,rise-.075,-end_z-1.5),0,2)
	await physics_frame
	game.player.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED;game.player.collision_mask=3;game.player.floor_snap_length=.35
	game.player.position=Vector3(0,.03,2.0);drive(Vector3(0,0,-1),2.4,132,true)
	check(game.player.position.y>.8 and game.player.position.z< -1.5,"ramp ascent and landing",game.player.position)
	drive(Vector3(0,0,1),2.4,132,true)
	check(game.player.position.y<.25 and game.player.position.z>1.4,"ramp descent",game.player.position)
	clear_fixture();body(Vector3(6,.1,4),Vector3(0,-.05,0),0,2)
	await physics_frame
	game.player.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED;game.player.collision_mask=3
	game.player.position=Vector3(0,.03,0);drive(Vector3(0,0,1),120,30,true)
	check(game.player.position.z<=2.01,"platform edge stops unsupported movement",game.player.position)
	# A ceiling remains solid even though walkable floors use their own layer.
	clear_fixture();body(Vector3(12,.1,12),Vector3(0,-.05,0),0,2)
	body(Vector3(4,.15,4),Vector3(0,1.8,-3),0,8)
	await physics_frame
	game.player.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED;game.player.collision_mask=3
	game.player.position=Vector3(0,.02,1);drive(Vector3(0,0,-1),6,120,true)
	check(game.player.position.z>-.49 and game.CollisionSafety.clear_at(game.player,game.player.global_position),"low ceiling stops entire character",game.player.position)
	var failures: Array=checks.filter(func(item):return not item.ok)
	var report={"maps":maps,"checks":checks.size(),"failures":failures,"results":checks}
	var file:=FileAccess.open("res://预览/穿模修复_检查报告.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("COLLISION RESULT maps=",maps," checks=",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
