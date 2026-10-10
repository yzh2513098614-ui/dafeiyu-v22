extends RefCounted
## Material names describe a surface; a dark paint color does not make it metal.
## Runtime copies preserve the GLB source, textures and all interaction geometry.
const Bevel = preload("res://module_3d.gd")
const PROFILES := {
	"white": [.74,0.0,.18], "ivory": [.76,0.0,.18], "cream": [.80,0.0,.16],
	"blue": [.65,0.0,.20], "navy": [.68,0.0,.18], "green": [.72,0.0,.18],
	"dark": [.79,0.0,.16], "olive": [.80,0.0,.16], "sand": [.82,0.0,.16],
	"red": [.67,0.0,.18], "pink": [.70,0.0,.18], "orange": [.72,0.0,.18],
	"yellow": [.72,0.0,.18],
	"wood": [.82,0.0,.16], "woodlight": [.82,0.0,.16], "paper": [.93,0.0,.08],
	"rubber": [.94,0.0,.08], "foam_lining": [.97,0.0,.06],
	"leaf": [.85,0.0,.14], "soil": [.98,0.0,.04],
	"metal": [.46,.65,.26], "silver": [.40,.72,.28],
	"graphite": [.49,.58,.24], "gunmetal": [.46,.65,.26], "gold": [.40,.70,.26],
	"glass": [.22,0.0,.30], "water": [.30,0.0,.26],
	"cyan": [.62,0.0,.16], "warm": [.70,0.0,.16], "light": [.70,0.0,.16]
}
const WALL_PARTS := ["Panel","TopEdge","Base","Cap","LowerWall","WindowPost","WindowBeam","Sill"]
static var materials: Dictionary = {}

static func finish_material(source: StandardMaterial3D) -> StandardMaterial3D:
	if not PROFILES.has(source.resource_name):return source
	var key := source.get_instance_id()
	if materials.has(key):return materials[key]
	var result: StandardMaterial3D = source.duplicate()
	var profile: Array = PROFILES[source.resource_name]
	result.roughness=profile[0];result.metallic=profile[1];result.metallic_specular=profile[2]
	if source.resource_name=="cyan":result.emission_energy_multiplier=.55
	elif source.resource_name in ["warm","light"]:result.emission_energy_multiplier=.65
	materials[key]=result;materials[result.get_instance_id()]=result
	return result

static func apply(mesh: MeshInstance3D) -> void:
	if mesh.material_override is StandardMaterial3D:
		mesh.material_override=finish_material(mesh.material_override)
	elif mesh.material_override==null:
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			if source is StandardMaterial3D:mesh.set_surface_override_material(surface,finish_material(source))
	# Only the pack's solid architecture gets chamfers. Glazing, LED strips,
	# floor meshes, collision bodies and animated/interactive furniture are intact.
	if mesh.mesh is BoxMesh and str(mesh.name) in WALL_PARTS and str(mesh.get_path()).contains("/Architecture/"):
		mesh.mesh=Bevel.beveled_mesh(mesh.mesh.size)
