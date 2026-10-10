extends SceneTree
## Record the production controller at 60 fixed physics ticks per second.
## Rendering and PNG writing never advance the character or choose sprite frames.
const OUTPUT := "res://预览/完整图片人物_v16/"
const STEP_SECONDS := 1.0 / 60.0
var game
var clock_node: CaptureClock
var records: Array = []
var simulation_tick := 0

class CaptureClock extends Node:
 signal advanced
 var controller
 var remaining := 0
 func _physics_process(_delta: float) -> void:
  if remaining <= 0:
   return
  # CharacterBody3D.move_and_slide runs inside a genuine engine physics callback.
  controller._physics_process(1.0 / 60.0)
  remaining -= 1
  advanced.emit()

func _initialize() -> void:
 Engine.physics_ticks_per_second = 60
 Engine.max_fps = 60
 call_deferred("capture")

func capture() -> void:
 root.size = Vector2i(960, 720)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT + "序列"))
 game = load("res://district/continuous_world.tscn").instantiate()
 root.add_child(game)
 # _ready must finish before replacing automatic game physics with the fixed clock.
 game.set_physics_process(false)
 game.set_process_unhandled_input(false)
 for frame in 5:
  await process_frame
 game._travel("apt_2")
 game.set_physics_process(false)
 _hide_ui(game)
 game.overview_mode = false
 game.view_size = 7.4
 game.camera.size = 7.4
 game.avatar.no_depth_test = false
 game.avatar.render_priority = 0
 clock_node = CaptureClock.new()
 clock_node.controller = game
 root.add_child(clock_node)
 for direction in ["down", "left", "up", "right"]:
  var input_vector: Vector2 = {"down": Vector2.DOWN, "left": Vector2.LEFT, "up": Vector2.UP, "right": Vector2.RIGHT}[direction]
  await _four_direction_walk(direction, input_vector)
 await _stop_restart()
 await _blocked_wall()
 await _occlusion()
 game.movement = Vector2.ZERO
 var file := FileAccess.open(OUTPUT + "movement_capture.json", FileAccess.WRITE)
 file.store_string(JSON.stringify({
  "source": "production continuous_world._physics_process inside engine physics callback",
  "physics_hz": 60,
  "capture_hz": 20,
  "timing": "simulation tick timestamps; character paused during render and file I/O",
  "frames": records,
 }, "  "))
 file.close()
 print("COMPLETE_PNG_CHARACTER_CAPTURE_COMPLETE frames=", records.size(), " simulation_ticks=", simulation_tick)
 quit()

func _hide_ui(node: Node) -> void:
 if node is CanvasLayer:
  node.visible = false
 for child in node.get_children():
  _hide_ui(child)

func _ticks(count: int) -> void:
 clock_node.remaining = count
 while clock_node.remaining > 0:
  await clock_node.advanced
  simulation_tick += 1

func _settle_at(position: Vector3) -> void:
 game.movement = Vector2.ZERO
 game.player.position = position
 game.player.velocity = Vector3.ZERO
 game._reset_character_gait()
 game.view_center = position
 game._camera()
 await _ticks(6)

func _photo(filename: String,small: bool = true) -> void:
 # No movement ticks occur here, irrespective of slow graphics or storage.
 await process_frame
 await RenderingServer.frame_post_draw
 var picture: Image = root.get_texture().get_image()
 if small:
  picture.resize(640, 480, Image.INTERPOLATE_LANCZOS)
 var error: Error = picture.save_png(OUTPUT + filename)
 if error != OK:
  push_error("Could not save " + filename + ": " + str(error))

func _record(group: String,index: int,begin_tick: int,state: String) -> void:
 var filename := "序列/" + group + "_%03d.png" % index
 await _photo(filename)
 var position: Vector3 = game.player.position
 records.append({
  "group": group,
  "direction": group,
  "state": state,
  "file": filename,
  "simulation_tick": simulation_tick,
  "timestamp_ms": int(round(simulation_tick * 1000.0 / 60.0)),
  "elapsed_ms": int(round((simulation_tick - begin_tick) * 1000.0 / 60.0)),
  "wall_timestamp_ms": Time.get_ticks_msec(),
  "position": [position.x, position.y, position.z],
  "animation": str(game.avatar.animation),
  "frame": game.avatar.frame,
  "speed": game.player.get_real_velocity().length(),
  "gait_phase": game.gait_phase,
 })

func _four_direction_walk(direction: String,input_vector: Vector2) -> void:
 # Use the large floor's open central area; distance is measured from production movement.
 var start := Vector3(-2, 0, 0)
 await _settle_at(start)
 var begin_tick := simulation_tick
 game.movement = input_vector
 for index in 32:
  await _ticks(3)
  await _record(direction, index, begin_tick, "walking")
  if index == 12:
   await _photo(direction + "_行走.png", false)
 game.movement = Vector2.ZERO
 await _ticks(6)
 print("CAPTURE_WALK ", direction, " ticks=96 seconds=1.6 distance=", start.distance_to(game.player.position))

func _stop_restart() -> void:
 await _settle_at(Vector3(-4, 0, 0))
 var begin_tick := simulation_tick
 for index in 48:
  var state := "walk" if index < 16 else ("stop" if index < 32 else "restart")
  game.movement = Vector2.ZERO if state == "stop" else Vector2.RIGHT
  await _ticks(3)
  await _record("停止再起步", index, begin_tick, state)
 game.movement = Vector2.ZERO
 await _ticks(6)

func _camera_input(world_direction: Vector3) -> Vector2:
 var right: Vector3 = game.camera.global_basis.x
 right.y = 0
 right = right.normalized()
 var down: Vector3 = game.camera.global_basis.z
 down.y = 0
 down = down.normalized()
 return Vector2(world_direction.dot(right), world_direction.dot(down))

func _blocked_wall() -> void:
 var zone: Dictionary = game.room_zones[0]
 var rectangle: Rect2 = zone.rect
 var door: Vector3 = zone.door
 var into := Vector3(0, 0, 1 if rectangle.get_center().y > 0 else -1)
 var wall_x := clampf(door.x + 3.8, rectangle.position.x + .8, rectangle.end.x - .8)
 var start := Vector3(wall_x, 0, door.z) - into * 1.1
 await _settle_at(start)
 var begin_tick := simulation_tick
 game.movement = _camera_input(into)
 for index in 36:
  await _ticks(3)
  await _record("堵墙停步", index, begin_tick, "holding_into_wall")
 await _photo("堵墙停步.png", false)
 print("CAPTURE_BLOCKED_WALL animation=", game.avatar.animation, " position=", game.player.position)
 game.movement = Vector2.ZERO
 await _ticks(6)

func _occlusion() -> void:
 var furniture = null
 for item in game.items:
  if str(item.module_id) in ["bed_navy", "bed_sage"]:
   furniture = item
   break
 if furniture == null:
  push_error("No bed found for the furniture occlusion screenshot")
  return
 var position: Vector3 = furniture.to_global(Vector3(.28, 0, -float(furniture.collision_depth) - .48))
 position.y = 0
 await _settle_at(position)
 await _photo("家具遮挡.png", false)
 print("CAPTURE_OCCLUSION ", furniture.module_id, " depth_test=", not game.avatar.no_depth_test)
 await _settle_at(Vector3(-2, 0, 0))
 game.foot_debug.visible = true
 await _photo("脚点定位.png", false)
 game.foot_debug.visible = false
