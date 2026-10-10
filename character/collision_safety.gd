extends RefCounted
## The union of every animation silhouette stays clear, including when turning.
static func add_guards(body: CollisionObject3D) -> void:
	var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/collision_profile.json"))
	for band in profile.bands:
		var guard:=CollisionShape3D.new()
		guard.name="SilhouetteGuard"+str(body.get_child_count())
		var shape:=CylinderShape3D.new()
		shape.radius=float(band.radius)
		shape.height=float(band.top)-float(band.bottom)
		guard.shape=shape
		guard.position.y=(float(band.bottom)+float(band.top))*.5
		body.add_child(guard)

static func clear_at(body: CollisionObject3D,point: Vector3) -> bool:
	if not point.is_finite():return false
	if not _body_clear_at(body,point):return false
	var silhouette: Variant=body.get_meta("silhouette_body") if body.has_meta("silhouette_body") else null
	if is_instance_valid(silhouette) and silhouette.collision_layer!=0:
		return _body_clear_at(silhouette,point)
	return true

static func _body_clear_at(body: CollisionObject3D,point: Vector3) -> bool:
	var params:=PhysicsTestMotionParameters3D.new()
	params.from=body.global_transform;params.from.origin=point
	params.margin=.001;params.max_collisions=32;params.recovery_as_collision=true
	if body.has_meta("floor_slabs"):
		var excluded: Array[RID]=[]
		var feet_only: bool=body is CharacterBody3D and body.motion_mode==CharacterBody3D.MOTION_MODE_GROUNDED and body.has_meta("silhouette_body")
		for slab in body.get_meta("floor_slabs"):
			# Native grounded motion and the support ray validate feet/floors.
			# Cold zero-motion recovery can choose a slab's underside for a
			# cylinder merely touching its top; the silhouette validates ceilings.
			if is_instance_valid(slab) and (feet_only or slab_near_feet(slab,point)):excluded.append(slab.get_rid())
		params.exclude_bodies=excluded
	var result:=PhysicsTestMotionResult3D.new()
	if not PhysicsServer3D.body_test_motion(body.get_rid(),params,result):return true
	# Collision depth is measured AFTER engine recovery. A deep overlap can
	# therefore report only millimetres while recovery moved a whole metre.
	var recovery:=result.get_travel()
	if recovery.length()>.012:
		if not body is CharacterBody3D or body.motion_mode!=CharacterBody3D.MOTION_MODE_GROUNDED:return false
		for index in result.get_collision_count():
			if result.get_collision_normal(index).y<.65:return false
	for i in result.get_collision_count():
		# A standing foot's contact with a floor/slope is support, not penetration.
		var foot_support: bool=body is CharacterBody3D and body.motion_mode==CharacterBody3D.MOTION_MODE_GROUNDED and result.get_collision_normal(i).y>=.65
		if result.get_collision_depth(i)>.012 and not foot_support:return false
	return true

static func slab_near_feet(slab: StaticBody3D,point: Vector3) -> bool:
	var height: float=float(slab.get_meta("walkable_top"))
	if slab.has_meta("walkable_stair"):
		var ramp: CollisionShape3D=slab.get_meta("walkable_stair")
		var local:=ramp.to_local(point)
		var front: float=-INF;var back: float=INF;var low: float=-INF;var high: float=-INF
		for vertex in ramp.shape.points:front=maxf(front,vertex.z);back=minf(back,vertex.z)
		for vertex in ramp.shape.points:
			if is_equal_approx(vertex.z,front):low=maxf(low,vertex.y)
			if is_equal_approx(vertex.z,back):high=maxf(high,vertex.y)
		var fraction:=clampf((front-local.z)/(front-back),0,1)
		height=ramp.to_global(Vector3(local.x,lerpf(low,high,fraction),local.z)).y
	return height<=point.y+.50

static func supported(body: CharacterBody3D,point: Vector3) -> bool:
	var excluded: Array[RID]=[body.get_rid()]
	var silhouette: Variant=body.get_meta("silhouette_body") if body.has_meta("silhouette_body") else null
	if is_instance_valid(silhouette):excluded.append(silhouette.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3(0,.20,0),point-Vector3(0,.45,0),body.collision_mask,excluded)
	var hit:=body.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.normal.y>=.65

static func overlaps_shape(body: CharacterBody3D,shape: Shape3D,transform: Transform3D) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape;query.transform=transform;query.collision_mask=body.collision_layer
	for hit in body.get_world_3d().direct_space_state.intersect_shape(query,32):
		if hit.collider==body or hit.collider==body.get_meta("silhouette_body",null):return true
	return false
