extends Camera3D
## 无屏幕 UI 的微缩景观观察相机。左键旋转，右键/中键平移，滚轮缩放。
var yaw := 0.50
var pitch := 0.32
var target := Vector3(0.0, 1.0, 0.0)
var orbiting := false
var panning := false
var desired_size := 18.6

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = desired_size
	near = 0.1
	far = 100.0
	current = true
	update_pose()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: orbiting = event.pressed
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE: panning = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed: desired_size = clampf(desired_size * 0.90, 7.0, 27.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed: desired_size = clampf(desired_size / 0.90, 7.0, 27.0)
	elif event is InputEventMouseMotion:
		if orbiting:
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch + event.relative.y * 0.005, 0.12, 1.18)
		if panning:
			var factor := size / float(get_viewport().get_visible_rect().size.y)
			target += (-global_basis.x * event.relative.x + global_basis.y * event.relative.y) * factor
			target.x = clampf(target.x, -5.0, 5.0)
			target.z = clampf(target.z, -5.0, 5.0)
			target.y = clampf(target.y, 0.1, 4.0)
	elif event is InputEventMagnifyGesture:
		desired_size = clampf(desired_size / event.factor, 7.0, 27.0)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			yaw = 0.50
			pitch = 0.32
			target = Vector3(0, 1, 0)
			desired_size = 18.6
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()

func _process(delta: float) -> void:
	size = lerpf(size, desired_size, 1.0-exp(-delta*12.0))
	update_pose()

func update_pose() -> void:
	position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*25.0
	look_at(target)
