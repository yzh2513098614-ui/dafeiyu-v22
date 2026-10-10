extends RefCounted
## Keep original room surfaces, spacing and collision; replace metallic seam boxes.
const FLOOR_SHADER=preload("res://assets/modern/shaders/pack_floor.gdshader")

static func apply(architecture: Node3D) -> void:
	var floor_mesh: MeshInstance3D
	var joints: Array[MeshInstance3D]=[]
	for node in architecture.get_children():
		if not node is MeshInstance3D:continue
		if str(node.name).begins_with("Floor") and node.mesh is BoxMesh:
			if floor_mesh:_replace(floor_mesh,joints)
			floor_mesh=node;joints=[]
		elif str(node.name).contains("Joint"):
			joints.append(node)
	if floor_mesh:_replace(floor_mesh,joints)

static func _replace(floor_mesh: MeshInstance3D,joints: Array[MeshInstance3D]) -> void:
	if joints.is_empty():return
	var positions: Array=[[],[]]
	for joint in joints:
		var axis:=0 if joint.mesh.size.x<joint.mesh.size.z else 1
		var value: float=joint.global_position.x if axis==0 else joint.global_position.z
		if not value in positions[axis]:positions[axis].append(value)
	var spacing:=Vector2(2,2)
	var phase:=Vector2(floor_mesh.global_position.x,floor_mesh.global_position.z)
	var axes:=Vector2.ZERO
	for axis in 2:
		positions[axis].sort()
		if positions[axis].is_empty():continue
		axes[axis]=1;phase[axis]=positions[axis][0]
		if positions[axis].size()>1:spacing[axis]=positions[axis][1]-positions[axis][0]
		elif str(joints[0].name).begins_with("StoreyJoint"):spacing[axis]=3
	var original: StandardMaterial3D=floor_mesh.material_override
	var material:=ShaderMaterial.new();material.shader=FLOOR_SHADER
	material.set_shader_parameter("tile_color",original.albedo_color)
	material.set_shader_parameter("roughness_value",original.roughness)
	material.set_shader_parameter("tile_size",spacing)
	material.set_shader_parameter("tile_origin",phase)
	material.set_shader_parameter("line_axes",axes)
	floor_mesh.material_override=material
	for joint in joints:
		joint.get_parent().remove_child(joint);joint.queue_free()
