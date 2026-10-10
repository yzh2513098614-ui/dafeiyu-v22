extends SceneTree
## Original-height room wall corners, with their real cap and thickness.
const Walls = preload("res://district/themed_walls.gd")
const OUT := "res://预览/餐厅学校医院_3D_v22/三款墙体_厚度近景.png"
const PICKS := [
 ["restaurant_bar", "餐厅 · 灰木护墙"],
 ["school_library", "学校 · 细条护墙"],
 ["hospital_ward", "医院 · 防撞护墙"],
]

func _initialize() -> void: call_deferred("run")

func run() -> void:
 root.size = Vector2i(1600,850)
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene = stage
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("17283a")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("b2c6cf")
 env.ambient_light_energy = .28
 world.environment = env
 stage.add_child(world)
 var floor := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(16,8)
 floor.mesh = plane
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color("697f8b")
 floor.material_override = mat
 stage.add_child(floor)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48,-38,0)
 sun.light_energy = .40
 sun.light_color = Color("fff0d5")
 sun.shadow_bias = .14
 sun.shadow_normal_bias = 1.3
 sun.directional_shadow_max_distance = 22
 sun.shadow_enabled = true
 stage.add_child(sun)
 for i in PICKS.size():
  var id: String = PICKS[i][0]
  var model: Node3D = Walls.module(id)
  if model == null: quit(1); return
  model.position = Vector3((i-1)*3.65,.02,0)
  stage.add_child(model)
  var side: Node3D = Walls.module(id)
  side.scale.x = .6
  side.rotation.y = -PI/2
  side.position = Vector3((i-1)*3.65-1.25,.02,.70)
  stage.add_child(side)
  var label := Label3D.new()
  label.text = PICKS[i][1]
  label.font_size = 38
  label.pixel_size = .008
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.modulate = Color("e3edf0")
  label.position = Vector3((i-1)*3.65,.10,1.42)
  stage.add_child(label)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 6.2
 camera.position = Vector3(5.0,5.8,12.0)
 stage.add_child(camera)
 camera.look_at(Vector3(0,.55,.30))
 camera.current = true
 for n in 16: await process_frame
 await RenderingServer.frame_post_draw
 var image: Image = root.get_texture().get_image()
 var result: Error = image.save_png(OUT)
 print("WALL DEPTH ", "OK" if result == OK else "FAIL")
 quit(0 if result == OK else 1)
