extends SceneTree
## Render the actual reusable Godot modules into transparent catalog thumbnails.
var viewport: SubViewport
var scene: Node3D
var camera: Camera3D
var current: Node3D
var entry: Dictionary

func _initialize() -> void:
 call_deferred("render_catalog")

func render_catalog() -> void:
 viewport=SubViewport.new();viewport.size=Vector2i(256,256);viewport.transparent_bg=true;viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 scene=Node3D.new();viewport.add_child(scene)
 var environment:=WorldEnvironment.new();var settings:=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(0,0,0,0)
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("ecf1f5");settings.ambient_light_energy=.55
 environment.environment=settings;scene.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-28,0);sun.light_energy=.82;sun.light_color=Color("f1f6ff");scene.add_child(sun)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;scene.add_child(camera)
 DirAccess.make_dir_recursive_absolute("res://assets/modern/thumbnails")
 var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog.json"))
 var rendered:=0
 for data in catalog:
  if "--only-floors" in OS.get_cmdline_user_args() and data.category!="floor":continue
  entry=data
  current=load("res://scenes/modules_3d/"+str(data.id)+".tscn").instantiate();scene.add_child(current)
  await process_frame
  var bound:=AABB(Vector3(-.45,0,-.45),Vector3(.9,1.1,.9));var bounds: Array[AABB]=[]
  gather_bounds(current,bounds)
  if bounds.size()>0:
   bound=bounds[0]
   for index in range(1,bounds.size()):bound=bound.merge(bounds[index])
  var center:=bound.position+bound.size/2
  camera.size=maxf(1.05,maxf(bound.size.x,maxf(bound.size.y,bound.size.z))*1.48)
  camera.position=center+Vector3(2.8,2.2,5.7);camera.look_at(center)
  await process_frame
  await RenderingServer.frame_post_draw
  var image:=viewport.get_texture().get_image()
  var error:=image.save_png("res://assets/modern/thumbnails/"+str(data.id)+".png")
  if error!=OK:push_error("thumbnail failed: "+str(data.id));quit(1);return
  rendered+=1;current.free()
 print("Rendered "+str(rendered)+" actual modern module thumbnails")
 quit()

func gather_bounds(node: Node,bounds: Array[AABB]) -> void:
 if node is MeshInstance3D and node.visible:
  if node.mesh!=null:bounds.append(node.global_transform*node.mesh.get_aabb())
 elif node is Sprite3D:
  var texture: Texture2D=node.texture
  var w: float=texture.get_width()*node.pixel_size;var h: float=texture.get_height()*node.pixel_size
  bounds.append(AABB(node.global_position-Vector3(w/2,h/2,.04),Vector3(w,h,.08)))
 for child in node.get_children():gather_bounds(child,bounds)
