extends RefCounted
## One depth-aware pass, limited to ground contact and the unlit side of a solid.
const CONTACT_SHADER=preload("res://assets/modern/shaders/directional_contact.gdshader")

static func install(camera: Camera3D) -> MeshInstance3D:
	var pass_mesh:=MeshInstance3D.new();pass_mesh.name="DirectionalContact"
	var quad:=QuadMesh.new();quad.size=Vector2(2,2);pass_mesh.mesh=quad
	pass_mesh.extra_cull_margin=128
	pass_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new();material.shader=CONTACT_SHADER
	# Before transparent portraits, glass and particles. Do not darken sprite edges.
	material.render_priority=-128;pass_mesh.material_override=material
	camera.add_child(pass_mesh)
	return pass_mesh
