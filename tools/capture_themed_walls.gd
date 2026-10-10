extends SceneTree
## Original game wall modules under identical materials in an oblique view.
const Walls = preload("res://district/themed_walls.gd")
const KINDS := [
 "restaurant_dining", "restaurant_patisserie", "restaurant_bar", "restaurant_kitchen", "restaurant_pantry", "restaurant_lounge",
 "school_lobby", "school_classroom", "school_staff", "school_library", "school_science", "school_art",
 "school_math", "school_language", "school_media", "school_observatory", "school_craft", "school_store",
 "hospital_lobby", "hospital_triage", "hospital_consult", "hospital_pharmacy", "hospital_imaging", "hospital_waiting",
 "hospital_ward", "hospital_treatment", "hospital_nurse", "hospital_recovery", "hospital_lab", "hospital_quiet"
]
const OUT := "res://预览/餐厅学校医院_3D_v22/三十款墙体模型_斜视总览.png"

func _initialize() -> void: call_deferred("run")

func run() -> void:
 root.size = Vector2i(2200,1600)
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene = stage
 var world := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("17283a")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("bacbd0")
 env.ambient_light_energy = .28
 world.environment = env
 stage.add_child(world)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-27,-21,0)
 light.light_energy = .40
 light.light_color = Color("fff0d5")
 stage.add_child(light)
 for i in KINDS.size():
  var kind: String = KINDS[i]
  var col: int = i%5
  var row: int = int(i/5)
  var x: float = (col-2)*3.35
  var y: float = (2.5-row)*1.90
  var module: Node3D = Walls.module(kind)
  if module == null: quit(1); return
  module.position = Vector3(x,y,0)
  module.rotation_degrees.y = -24.0
  stage.add_child(module)
  var label := Label3D.new()
  label.text = kind.trim_prefix("restaurant_").trim_prefix("school_").trim_prefix("hospital_")
  label.font_size = 32
  label.pixel_size = .009
  label.modulate = Color("dce8eb")
  label.position = Vector3(x,y-.24,.40)
  stage.add_child(label)
 var camera := Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 13.6
 camera.position = Vector3(0,12.8,25)
 stage.add_child(camera)
 camera.look_at(Vector3(0,.55,0))
 camera.current = true
 for n in 18: await process_frame
 await RenderingServer.frame_post_draw
 var image: Image = root.get_texture().get_image()
 var result: Error = image.save_png(OUT)
 print("THIRTY WALLS ", "OK" if result == OK else "FAIL")
 quit(0 if result == OK else 1)
