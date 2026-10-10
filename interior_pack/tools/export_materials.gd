extends SceneTree
func _initialize() -> void:
 var entries: Array=JSON.parse_string(FileAccess.get_file_as_string("res://interior_pack/catalog.json"))
 var seen: Dictionary={}
 DirAccess.make_dir_recursive_absolute("res://interior_pack/assets/materials")
 for entry in entries:
  var instance: Node=load(entry.model).instantiate()
  for mesh in instance.find_children("*","MeshInstance3D",true,false):
   for i in mesh.mesh.get_surface_count():
    var material: Material=mesh.mesh.surface_get_material(i)
    if material and not seen.has(material.resource_name):
     seen[material.resource_name]=true
     ResourceSaver.save(material,"res://interior_pack/assets/materials/"+material.resource_name+".tres")
  instance.free()
 print("Exported ",seen.size()," reusable native PBR materials")
 quit()
