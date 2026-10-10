extends RefCounted
## Cut real openings in floors/railings where an authored stair passes through.
## Floor support (2) and horizontal slab clearance (8) have separate purposes.
const HEAD_CLEARANCE:=2.55
const HALF_WIDTH:=1.13

static func apply(architecture: Node3D) -> void:
	var stairs: Array[CollisionShape3D]=[]
	for support in architecture.find_children("StairSupport","StaticBody3D",true,false):
		stairs.append(support.get_node("Shape"))
	for node in architecture.get_children():
		if node is StaticBody3D and str(node.name).begins_with("Floor"):
			node.collision_layer=10
			var shape: CollisionShape3D=node.get_node_or_null("Shape")
			if not shape or not shape.shape is BoxShape3D:continue
			var mesh: MeshInstance3D=architecture.get_node_or_null(str(node.name).trim_suffix("Body"))
			_cut_box(shape,mesh,stairs,true)
		elif node is Node3D and str(node.name).begins_with("Floor") and str(node.name).contains("Guard"):
			var continuous: CollisionShape3D=node.get_node_or_null("ContinuousSafetyBody/Shape")
			if continuous:_cut_box(continuous,null,stairs,false)
			for rail in node.get_children():
				if not str(rail.name).begins_with("LibraryGlassRail"):continue
				_cut_rail(rail,stairs)
		elif node is Node3D and (str(node.name).begins_with("Boundary") or str(node.name).contains("Wall")):
			var shape: CollisionShape3D=node.get_node_or_null("Body/Shape")
			if not shape or not shape.shape is BoxShape3D:continue
			_cut_box(shape,null,stairs,false)
			if not shape.disabled:continue
			var visual: Node3D=node.get_node_or_null("Visual")
			if not visual:continue
			var old_scale:=visual.scale;visual.scale=Vector3.ONE
			for part in visual.get_children():
				if not part is MeshInstance3D or not part.mesh is BoxMesh:continue
				var temporary:=StaticBody3D.new();temporary.collision_layer=0;visual.add_child(temporary)
				var hit:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=part.mesh.size;hit.shape=box
				temporary.add_child(hit);hit.global_transform=part.global_transform
				_cut_box(hit,part,stairs,false);temporary.free()
			visual.scale=old_scale
	# Intermediate landings have the same floor/ceiling semantics as room slabs.
	for landing in architecture.find_children("HalfLandingBody","StaticBody3D",true,false):
		landing.collision_layer=10
	for slab in architecture.find_children("*","StaticBody3D",true,false):
		if (slab.collision_layer&8)==0:continue
		var top: float=-INF
		if slab.has_meta("stair_support"):
			var ramp: CollisionShape3D=slab.get_node("Shape")
			slab.set_meta("walkable_stair",ramp)
			for point in ramp.shape.points:top=maxf(top,ramp.to_global(point).y)
		for hit in slab.get_children():
			if hit is CollisionShape3D and not hit.disabled and hit.shape is BoxShape3D:
				top=maxf(top,hit.global_position.y+hit.shape.size.y*hit.global_basis.y.length()*.5)
		slab.set_meta("walkable_top",top)

static func _channel(stair: CollisionShape3D,y_min: float,y_max: float,floor: bool) -> Rect2:
	if not stair.shape is ConvexPolygonShape3D:return Rect2()
	var front: float=-INF;var back: float=INF;var low: float=-INF;var high: float=-INF
	for point in stair.shape.points:front=maxf(front,point.z);back=minf(back,point.z)
	for point in stair.shape.points:
		if is_equal_approx(point.z,front):low=maxf(low,point.y)
		if is_equal_approx(point.z,back):high=maxf(high,point.y)
	var start:=stair.to_global(Vector3(0,low,front))
	var end:=stair.to_global(Vector3(0,high,back))
	var rise:=end.y-start.y
	if rise<=.01 or y_max<=start.y+.01:return Rect2()
	var first:=clampf((y_min-HEAD_CLEARANCE-start.y)/rise,0,1)
	var last:=clampf((y_max+(.0 if floor else .10)-start.y)/rise,0,1)
	if last<=first:return Rect2()
	var direction:=Vector2(end.x-start.x,end.z-start.z).normalized()
	var a:=Vector2(start.x,start.z).lerp(Vector2(end.x,end.z),first)-direction*(.35 if floor else HALF_WIDTH)
	var b:=Vector2(start.x,start.z).lerp(Vector2(end.x,end.z),last)+direction*(0.0 if floor else HALF_WIDTH)
	var side:=Vector2(-direction.y,direction.x)*HALF_WIDTH
	var minimum: Vector2=(a-side).min(a+side).min(b-side).min(b+side)
	var maximum: Vector2=(a-side).max(a+side).max(b-side).max(b+side)
	return Rect2(minimum,maximum-minimum)

static func _local_rect(node: Node3D,rect: Rect2) -> Rect2:
	var minimum:=Vector2(INF,INF);var maximum:=Vector2(-INF,-INF)
	for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		var local:=node.to_local(Vector3(point.x,node.global_position.y,point.y))
		minimum=minimum.min(Vector2(local.x,local.z));maximum=maximum.max(Vector2(local.x,local.z))
	return Rect2(minimum,maximum-minimum)

static func _subtract(rect: Rect2,cut: Rect2) -> Array[Rect2]:
	var overlap:=rect.intersection(cut)
	if not overlap.has_area():return [rect]
	var pieces: Array[Rect2]=[
	 Rect2(rect.position,Vector2(overlap.position.x-rect.position.x,rect.size.y)),
	 Rect2(Vector2(overlap.end.x,rect.position.y),Vector2(rect.end.x-overlap.end.x,rect.size.y)),
	 Rect2(Vector2(overlap.position.x,rect.position.y),Vector2(overlap.size.x,overlap.position.y-rect.position.y)),
	 Rect2(Vector2(overlap.position.x,overlap.end.y),Vector2(overlap.size.x,rect.end.y-overlap.end.y))]
	return pieces.filter(func(piece):return piece.size.x>.002 and piece.size.y>.002)

static func _pieces(shape: CollisionShape3D,stairs: Array[CollisionShape3D],floor: bool) -> Array[Rect2]:
	var size: Vector3=shape.shape.size
	var original:=Rect2(Vector2(-size.x,-size.z)*.5,Vector2(size.x,size.z))
	var pieces: Array[Rect2]=[original]
	var scale_y:=shape.global_basis.y.length()
	for stair in stairs:
		var channel:=_channel(stair,shape.global_position.y-size.y*scale_y*.5,shape.global_position.y+size.y*scale_y*.5,floor)
		if not channel.has_area():continue
		var cut:=_local_rect(shape,channel)
		var next: Array[Rect2]=[]
		for piece in pieces:next.append_array(_subtract(piece,cut))
		pieces=next
	return pieces

static func _cut_box(shape: CollisionShape3D,mesh: MeshInstance3D,stairs: Array[CollisionShape3D],floor: bool) -> void:
	if not shape.shape is BoxShape3D:return
	var pieces:=_pieces(shape,stairs,floor)
	var size: Vector3=shape.shape.size
	if pieces.size()==1 and is_equal_approx(pieces[0].size.x,size.x) and is_equal_approx(pieces[0].size.y,size.z):return
	shape.disabled=true
	if mesh:mesh.visible=false
	for piece in pieces:
		var replacement:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(piece.size.x,size.y,piece.size.y);replacement.shape=box
		shape.get_parent().add_child(replacement)
		replacement.global_transform=shape.global_transform
		replacement.global_position=shape.to_global(Vector3(piece.get_center().x,0,piece.get_center().y))
		if mesh:
			var visual:=MeshInstance3D.new();var geometry:=BoxMesh.new();geometry.size=box.size
			visual.mesh=geometry;visual.material_override=mesh.material_override
			mesh.get_parent().add_child(visual);visual.global_transform=replacement.global_transform
			visual.set_meta("floor_height",mesh.get_meta("floor_height",shape.global_position.y+size.y*.5))

static func _cut_rail(rail: Node3D,stairs: Array[CollisionShape3D]) -> void:
	var shape: CollisionShape3D=rail.get_node_or_null("Body/Shape")
	if not shape or not shape.shape is BoxShape3D:return
	var pieces:=_pieces(shape,stairs,false)
	var size: Vector3=shape.shape.size
	if pieces.size()==1 and is_equal_approx(pieces[0].size.x,size.x) and is_equal_approx(pieces[0].size.y,size.z):return
	for piece in pieces:
		var replacement: Node3D=rail.duplicate()
		rail.get_parent().add_child(replacement)
		replacement.position=rail.position+rail.basis*Vector3(piece.get_center().x,0,piece.get_center().y)
		replacement.scale=rail.scale*Vector3(piece.size.x/size.x,1,piece.size.y/size.z)
	# Both model and its original collision are removed; no invisible rail remains.
	rail.free()
