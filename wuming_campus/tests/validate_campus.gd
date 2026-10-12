extends SceneTree

var checks: int = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, name: String, detail: Variant = null) -> void:
	checks+=1
	if not condition:failures.append({"check":name,"detail":detail})

func validate() -> void:
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://wuming_campus/data/campus_layout.json"))
	var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://wuming_campus/data/asset_catalog.json"))
	check(is_equal_approx(628.0/layout.map.original_pixels_per_metre,100.0),"100m reference scale")
	var models: Dictionary={}
	for item in catalog:
		check(ResourceLoader.exists(item.scene),"loadable native asset "+item.id)
		check(FileAccess.file_exists(item.model),"GLB export "+item.id)
		models[item.id]=true
		check(item.triangles>0,"nonempty mesh "+item.id)
	for p in layout.placements:
		check(models.has(p.asset),"placement model "+p.asset)
		check(p.scale>0 and p.scale<3,"finite prop scale "+p.asset)
	var campus: Node3D=load("res://wuming_campus/scenes/world/campus.tscn").instantiate()
	root.add_child(campus)
	await process_frame
	await physics_frame
	await physics_frame
	campus.set_process(false)
	campus.walker.set_physics_process(false)
	campus.walker.collision_layer=0
	campus.walker.collision_mask=0
	check(campus.get_node("Buildings").get_child_count()==layout.buildings.size(),"all mapped buildings present")
	check(campus.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"2.5D orthographic camera")
	var space: PhysicsDirectSpaceState3D=campus.get_world_3d().direct_space_state
	var building_hits: int=0
	for v in layout.buildings:
		var at: Vector3=campus.wp(v.map_center)
		if v.kind=="library":at.x+=float(v.map_size[0])/float(layout.map.working_pixels_per_metre)*.5-.5
		elif v.kind=="activity_ring":at.x+=minf(float(v.map_size[0]),float(v.map_size[1]))/float(layout.map.working_pixels_per_metre)*.43-.5
		elif v.kind.begins_with("courtyard_"):
			var offset:=Vector3(-float(v.map_size[0])/float(layout.map.working_pixels_per_metre)*.43,0,0)
			at+=Basis(Vector3.UP,-deg_to_rad(float(v.yaw_degrees)))*offset
		elif v.kind=="dormitory_pair":at+=Basis(Vector3.UP,-deg_to_rad(float(v.yaw_degrees)))*Vector3(18,0,0)
		var query:=PhysicsRayQueryParameters3D.create(at+Vector3(0,90,0),at+Vector3(0,.4,0))
		var hit: Dictionary=space.intersect_ray(query)
		check(not hit.is_empty(),"solid building "+v.id,at)
		if not hit.is_empty():building_hits+=1
	# Roads must have supporting ground. This catches scene-offset or scale mistakes.
	var road_samples: int=0
	for road in layout.roads:
		if road.kind=="public_road":continue
		for i in range(road.points.size()-1):
			var at: Vector3=campus.wp(road.points[i]).lerp(campus.wp(road.points[i+1]),.5)
			var q:=PhysicsRayQueryParameters3D.create(at+Vector3(0,1,0),at-Vector3(0,1,0))
			var hit: Dictionary=space.intersect_ray(q)
			check(not hit.is_empty(),"walkable road "+road.id,at)
			road_samples+=1
	# A standard human capsule must rest on the campus ground under gravity.
	var body:=CharacterBody3D.new()
	var c:=CollisionShape3D.new()
	var shape:=CapsuleShape3D.new()
	shape.radius=.32
	shape.height=1.72
	c.shape=shape
	c.position.y=.88
	body.add_child(c)
	body.position=campus.wp([707,2305])+Vector3(0,1.0,0)
	root.add_child(body)
	await physics_frame
	for i in range(90):
		body.velocity.y-=9.8/60.0
		body.move_and_slide()
		await physics_frame
	check(body.is_on_floor(),"human capsule settles on ground",body.position)
	check(body.position.y>-.10 and body.position.y<.5,"human remains at campus datum",body.position.y)
	var library: Node3D=campus.get_node("Buildings/B1")
	var radius: float=174.0/float(layout.map.working_pixels_per_metre)/2.0
	var ramp_samples: int=0
	for side in [-1,1]:
		for i in range(11):
			var u: float=float(i)/10.0
			var local:=Vector3(side*12.5,0,radius+36.0-28.8*u)
			var at: Vector3=library.to_global(local)
			var q:=PhysicsRayQueryParameters3D.create(at+Vector3(0,12,0),at-Vector3(0,1,0))
			var hit: Dictionary=space.intersect_ray(q)
			check(not hit.is_empty(),"library ramp support",local)
			if not hit.is_empty():check(absf(float(hit.position.y)-lerpf(.16,4.2,u))<.10,"library ramp height follows slope",hit.position)
			ramp_samples+=1
	var at: Vector3=library.to_global(Vector3(60,0,46))
	var deck_hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3(0,8,0),at-Vector3(0,1,0)))
	check(not deck_hit.is_empty(),"raised library promenade has supporting collision")
	if not deck_hit.is_empty():check(absf(float(deck_hit.position.y)-4.2)<.05,"library promenade rests at platform height",deck_hit.position)
	var gate: Node3D=campus.get_node("Landmarks/motto_gate")
	for x in [-7.45,0.0,7.45]:
		var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(gate.to_global(Vector3(x,1.6,-3)),gate.to_global(Vector3(x,1.6,3))))
		check(hit.is_empty(),"three arch passages remain open",x)
	for x in [-4.4,4.4]:
		var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(gate.to_global(Vector3(x,1.6,-3)),gate.to_global(Vector3(x,1.6,3))))
		check(not hit.is_empty(),"arch pier blocks passage",x)
	var vault: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(gate.to_global(Vector3(0,10,0)),gate.to_global(Vector3(0,3,0))))
	check(not vault.is_empty(),"main arch vault has overhead collision")
	for tower_id in ["A10","A11"]:
		var tower: Node3D=campus.get_node("Buildings/"+tower_id)
		var front: float=58.0/float(layout.map.working_pixels_per_metre)/2.0
		var expected: float=front+.45+17.5*pow(1.0-6.0/29.0,2)
		var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(tower.to_global(Vector3(0,6,expected+5)),tower.to_global(Vector3(0,6,expected-5))))
		check(not hit.is_empty(),"curved tower front blocks movement",tower_id)
		if not hit.is_empty():check(absf(tower.to_local(hit.position).z-expected)<.18,"curved tower collision follows visible facade",tower_id)
	# Move the actual human-sized capsule up part of the entrance ramp; a flat
	# ground collider alone cannot pass this check.
	body.floor_snap_length=.3
	body.position=library.to_global(Vector3(-12.5,1.55,radius+36-28.8*.2))
	body.velocity=Vector3.ZERO
	for i in range(60):
		body.velocity.y-=9.8/60.0
		body.move_and_slide()
		await physics_frame
	var start_position: Vector3=body.position
	var direction: Vector3=library.global_basis*Vector3(0,0,-1)
	for i in range(240):
		body.velocity.x=direction.x*2.4
		body.velocity.z=direction.z*2.4
		body.velocity.y-=9.8/60.0
		body.move_and_slide()
		await physics_frame
	check(body.is_on_floor(),"human capsule keeps contact while ascending ramp",body.position)
	check(body.position.y>start_position.y+.65,"ramp raises walker above campus datum",body.position.y-start_position.y)
	check(Vector2(body.position.x-start_position.x,body.position.z-start_position.z).length()>6.0,"walker travels along the ramp",body.position)
	var report: Dictionary={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"mapped_buildings":layout.buildings.size(),"building_collision_samples":building_hits,"road_ground_samples":road_samples,"library_ramp_samples":ramp_samples,"arch_passages":3,"ramp_walking_test":true,"trees":campus.get_node("TreeTrunks").get_child_count(),"scope":"native resources, metre scale, building collision, road support, open arches, raised platform, curved facade and human capsule walking on slope; not a cadastral accuracy certification"}
	var f:=FileAccess.open("res://wuming_campus/data/validation_report.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	print("VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
