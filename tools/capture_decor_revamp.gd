extends SceneTree
## Fifty finished models, five Godot render pages, no image stand-ins.
const Decor=preload("res://district/decor_library.gd")
const OUT="res://预览/餐厅学校医院_3D_v22/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.size=Vector2i(1920,1080)
 var catalog: Array=JSON.parse_string(FileAccess.get_file_as_string("res://models/themed_props/decor_catalog.json"))
 for page in 5:
  var stage:=Node3D.new();root.add_child(stage);current_scene=stage
  var world:=WorldEnvironment.new();var env:=Environment.new()
  env.background_mode=Environment.BG_COLOR;env.background_color=Color("192a38")
  env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
  env.ambient_light_color=Color("c6d2dd");env.ambient_light_energy=.28
  world.environment=env;stage.add_child(world)
  var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0)
  sun.light_color=Color("fff0d5");sun.light_energy=.40;sun.shadow_enabled=true
  sun.directional_shadow_max_distance=40;sun.shadow_bias=.10;stage.add_child(sun)
  var plane:=PlaneMesh.new();plane.size=Vector2(25,12)
  var floor:=MeshInstance3D.new();floor.mesh=plane
  var mat:=StandardMaterial3D.new();mat.albedo_color=Color("71828c");mat.roughness=.9
  floor.material_override=mat;stage.add_child(floor)
  for n in 10:
   var entry: Dictionary=catalog[page*10+n]
   var model: Node3D=Decor.instance(entry.id)
   if model == null: quit(1);return
   var x: float=(n%5-2)*4.6;var z: float=(int(n/5)-.5)*4.6
   model.position=Vector3(x,.025,z);stage.add_child(model)
   var label:=Label3D.new();label.text=entry.name
   label.font_size=36;label.pixel_size=.008;label.modulate=Color("dae5e5")
   label.outline_size=3;label.outline_modulate=Color("223847")
   label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=Vector3(x,.10,z+1.7)
   stage.add_child(label)
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
  camera.size=13.2;camera.position=Vector3(2.8,13.5,18)
  stage.add_child(camera);camera.look_at(Vector3(0,.6,0));camera.current=true
  for n in 12:await process_frame
  await RenderingServer.frame_post_draw
  var result: Error=root.get_texture().get_image().save_png(OUT+"五十件装饰_"+str(page+1)+".png")
  if result != OK:push_error("Decoration preview failed");quit(1);return
  stage.queue_free();await process_frame
 print("50 DECORATION RENDERS OK")
 quit()
