extends RefCounted
## Moving doors/drawers own real collision, and pause before reaching a player.
var shapes: Array[CollisionShape3D]=[]

func add_meshes(root: Node,only_moving: bool=true) -> void:
	if root is MeshInstance3D and root.mesh and (not only_moving or str(root.name).begins_with("moving_")):
		var bounds: AABB=root.mesh.get_aabb()
		if bounds.size.length()>.045:
			var body:=StaticBody3D.new();body.name="MovingSolid";root.add_child(body)
			var hit:=CollisionShape3D.new();var box:=BoxShape3D.new()
			box.size=bounds.size.max(Vector3.ONE*.012)
			hit.shape=box;hit.position=bounds.get_center();body.add_child(hit);shapes.append(hit)
	for child in root.get_children():
		if child is MeshInstance3D or not child is CollisionObject3D:add_meshes(child,only_moving)

func blocked() -> bool:
	for shape in shapes:
		if players_overlap(shape):return true
	return false

func update_visibility(visible: bool) -> void:
	for shape in shapes:shape.get_parent().collision_layer=1 if visible else 0

static func players_overlap(shape: CollisionShape3D) -> bool:
	if not shape.is_inside_tree():return false
	# Transform notifications may still be queued when a teleport and an opening
	# happen in the same frame. Check current scene transforms before server state.
	if shape.shape is BoxShape3D:
		var inverse:=shape.global_transform.affine_inverse()
		var half: Vector3=shape.shape.size*.5
		for player in shape.get_tree().get_nodes_in_group("collision_protected_player"):
			for guard in player.get_children():
				if not guard is CollisionShape3D or not guard.shape is CylinderShape3D:continue
				if guard.disabled and not str(guard.name).begins_with("SilhouetteGuard"):continue
				var center: Vector3=inverse*guard.global_position
				var basis: Basis=inverse.basis*guard.global_basis
				var radius: float=guard.shape.radius
				var height: float=guard.shape.height*.5
				# Projection bounds remain conservative for tilted lids and scaled models.
				var extent:=Vector3(
				 radius*Vector2(basis.x.x,basis.z.x).length()+height*absf(basis.y.x),
				 radius*Vector2(basis.x.y,basis.z.y).length()+height*absf(basis.y.y),
				 radius*Vector2(basis.x.z,basis.z.z).length()+height*absf(basis.y.z))
				if absf(center.y)>half.y+extent.y+.012:continue
				if absf(basis.y.x)<.001 and absf(basis.y.z)<.001:
					var distance:=Vector2(maxf(absf(center.x)-half.x,0),maxf(absf(center.z)-half.z,0))
					if distance.length()<maxf(extent.x,extent.z)+.012:return true
				elif absf(center.x)<half.x+extent.x+.012 and absf(center.z)<half.z+extent.z+.012:return true
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape.shape;query.transform=shape.global_transform;query.collision_mask=4;query.margin=.012
	return not shape.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty()
