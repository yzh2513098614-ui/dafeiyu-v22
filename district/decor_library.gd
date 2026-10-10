extends RefCounted
## Finished GLB furniture, original palette, and room-aware collision placement.
const Modern = preload("res://modern_materials.gd")
const Shape=preload("res://district/space_shape.gd")
const DIR := "res://models/themed_props/"
static var scenes: Dictionary = {}
static var materials: Dictionary = {}

static func instance(id: String) -> Node3D:
 if not scenes.has(id):
  var path := DIR + id + ".tscn"
  if not ResourceLoader.exists(path):
   push_error("Missing detailed decoration: " + path)
   return null
  scenes[id] = load(path)
 var model: Node3D = scenes[id].instantiate()
 model.set_meta("decor_id",id)
 _finish(model)
 return model

static func _finish(node: Node) -> void:
 if node is MeshInstance3D:
  var bounds: AABB = node.mesh.get_aabb()
  if bounds.size.length()<.18: node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for surface in node.mesh.get_surface_count():
   var source: Material = node.mesh.surface_get_material(surface)
   if source == null: continue
   var key: String = source.resource_name
   if not key.begins_with("decor_"): continue
   if not materials.has(key):
    var bits: PackedStringArray = key.split("_")
    var mat: StandardMaterial3D
    if bits[2] == "glass":
     mat = Modern.glass().duplicate()
     mat.albedo_color = Color(bits[1]); mat.albedo_color.a=.24
     mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    else:
     mat = Modern.surface(Color(bits[1]),bits[2]=="metal",bits[2]=="fabric").duplicate()
    # Stable direct lighting on curved furniture under GL Compatibility.
    mat.disable_receive_shadows = true
    materials[key] = mat
   node.set_surface_override_material(surface,materials[key])
   if key.ends_with("glass"): node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in node.get_children(): _finish(child)

static func configure(holder: Node3D,w: float,d: float,door: Vector3) -> void:
 holder.set_meta("decor_inside",Rect2(-w/2+.38,-d/2+.38,w-.76,d-.76))
 holder.set_meta("decor_door_clear",Rect2(door.x-1.50,door.z-2.35,3.0,2.70))
 holder.set_meta("decor_occupied",[])
 holder.set_meta("decor_skipped",0)

static func footprint(model: Node3D) -> Rect2:
 var hit: CollisionShape3D = model.get_node_or_null("Body/Collision")
 if hit == null or not hit.shape is BoxShape3D: return Rect2()
 var size: Vector3 = hit.shape.size
 var local: Vector3 = hit.position.rotated(Vector3.UP,model.rotation.y)
 var half := Vector2(absf(cos(model.rotation.y))*size.x+absf(sin(model.rotation.y))*size.z,
                     absf(sin(model.rotation.y))*size.x+absf(cos(model.rotation.y))*size.z)*.5
 return Rect2(Vector2(model.position.x+local.x,model.position.z+local.z)-half,half*2)

static func place(holder: Node3D,id: String,pos: Vector3,angle: float=0.0) -> Node3D:
 var model: Node3D = instance(id)
 if model == null: return null
 model.name = id+"_"+str(holder.get_child_count())
 model.position = pos; model.rotation_degrees.y = angle
 if holder.has_meta("decor_inside"):
  var inside: Rect2 = holder.get_meta("decor_inside")
  var entry: Rect2 = holder.get_meta("decor_door_clear")
  var occupied: Array = holder.get_meta("decor_occupied")
  var anchor: Vector3 = pos
  var fitted := false
  # Modest offsets preserve the designed layout; large objects get priority.
  var polygon: PackedVector2Array=holder.get_meta("decor_polygon",PackedVector2Array())
  for candidate in Shape.fitted_candidates(anchor,inside):
   model.position=candidate
   var rect: Rect2=footprint(model)
   model.position.x+=maxf(0,inside.position.x-rect.position.x)-maxf(0,rect.end.x-inside.end.x)
   model.position.z+=maxf(0,inside.position.y-rect.position.y)-maxf(0,rect.end.y-inside.end.y)
   rect=footprint(model)
   var blocked: bool=not inside.encloses(rect) or not Shape.contains_rect(polygon,rect) or entry.intersects(rect.grow(.08))
   var protected: Array=holder.get_meta("decor_access",[])
   if not protected.is_empty():
    blocked=not inside.encloses(rect) or not Shape.contains_rect(polygon,rect)
    for aisle: Rect2 in protected:
     if rect.intersects(aisle):blocked=true;break
   for other: Rect2 in occupied:
    if other.grow(.65).intersects(rect): blocked=true; break
   if not blocked:
    occupied.append(rect); holder.set_meta("decor_occupied",occupied)
    fitted=true; break
  if not fitted:
   holder.set_meta("decor_skipped",int(holder.get_meta("decor_skipped"))+1)
   model.free()
   return null
 holder.add_child(model)
 return model

static func rug(holder: Node3D,pos: Vector3,size: Vector2,tint: Color) -> void:
 var polygon: PackedVector2Array=holder.get_meta("decor_polygon",PackedVector2Array())
 if not Shape.contains_rect(polygon,Rect2(Vector2(pos.x-size.x/2,pos.z-size.y/2),size),0):return
 var mesh := MeshInstance3D.new()
 mesh.name="OvalRug"
 var disk:=CylinderMesh.new();disk.top_radius=1;disk.bottom_radius=1;disk.height=.006;disk.radial_segments=48
 mesh.mesh=disk;mesh.position=pos+Vector3(0,.040,0)
 mesh.scale=Vector3(size.x/2,1,size.y/2)
 mesh.material_override=Modern.surface(tint,false,true)
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 holder.add_child(mesh)
