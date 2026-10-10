extends RefCounted
## Complete original-height walls tiled on the actual room boundary.
const Modern = preload("res://modern_materials.gd")
const Surfaces = preload("res://district/wall_surfaces.gd")
const DIR := "res://models/themed_walls/"
const WIDTH := 2.7
const KINDS := [
 "restaurant_dining", "restaurant_patisserie", "restaurant_bar", "restaurant_kitchen", "restaurant_pantry", "restaurant_lounge",
 "school_lobby", "school_classroom", "school_staff", "school_library", "school_science", "school_art",
 "school_math", "school_language", "school_media", "school_observatory", "school_craft", "school_store",
 "hospital_lobby", "hospital_triage", "hospital_consult", "hospital_pharmacy", "hospital_imaging", "hospital_waiting",
 "hospital_ward", "hospital_treatment", "hospital_nurse", "hospital_recovery", "hospital_lab", "hospital_quiet"
]
static var _scenes: Dictionary = {}
static var _materials: Dictionary = {}
static func supports(kind: String) -> bool:
 return kind in KINDS
static func module(kind: String) -> Node3D:
 if not _scenes.has(kind):
  var path := DIR + "wall_" + kind + ".glb"
  if not ResourceLoader.exists(path):
   push_error("Missing wall module: " + path)
   return null
  _scenes[kind] = load(path)
 var instance: Node3D = _scenes[kind].instantiate()
 _finish(instance)
 var shadow := MeshInstance3D.new()
 shadow.name = "WallShadow"
 var box := BoxMesh.new()
 box.size = Vector3(WIDTH,1.1,.20)
 shadow.mesh = box
 shadow.position.y = .55
 shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
 instance.add_child(shadow)
 return instance
static func _finish(node: Node) -> void:
 if node is MeshInstance3D:
  # Fine visible geometry uses direct lighting; the solid body casts shadows.
  node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for surface in node.mesh.get_surface_count():
   var source: Material = node.mesh.surface_get_material(surface)
   if source == null: continue
   var key: String = source.resource_name
   if not key.begins_with("wall_"): continue
   if not _materials.has(key):
    var bits: PackedStringArray = key.split("_")
    var material: StandardMaterial3D = Modern.surface(Color(bits[1]), bits[2] == "metal", false).duplicate()
    # Low-poly compatibility shadows interpolate across broad triangles and
    # millimetre relief. Keep direct face lighting; the solid proxy casts the
    # complete wall's shadow on the floor without triangular face artifacts.
    material.disable_receive_shadows = true
    _materials[key] = material
   node.set_surface_override_material(surface, _materials[key])
 for child in node.get_children(): _finish(child)
static func run(g, kind: String, start: Vector3, end: Vector3) -> bool:
 var length: float = start.distance_to(end)
 if length < .01: return true
 var first: Node3D = module(kind)
 if first == null: return false
 var holder := Node3D.new()
 holder.name = "WallRun_" + kind + "_" + str(g.shell.get_child_count())
 holder.position = (start+end)*.5
 holder.rotation.y = -atan2(end.z-start.z,end.x-start.x)
 holder.set_meta("wall_kind", kind)
 holder.set_meta("wall_start", start)
 holder.set_meta("wall_end", end)
 holder.set_meta("wall_length", length)
 g.shell.add_child(holder)
 var count: int = maxi(1, ceili(length/WIDTH))
 var span: float = length/count
 for i in count:
  var part: Node3D = first if i == 0 else module(kind)
  part.name = "WallModule_" + str(i)
  part.position.x = -length/2 + (i+.5)*span
  part.scale.x = span/WIDTH
  holder.add_child(part)
  Surfaces.finish_module(part,kind,(end-start).normalized())
 g._collision(holder, Vector3(length,1.1,.20), Vector3(0,.55,0))
 return true
