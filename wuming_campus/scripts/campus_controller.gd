extends Node3D

var layout: Dictionary
var camera: Camera3D
var walker: CharacterBody3D
var target := Vector3.ZERO
var yaw: float = 12.0
var pitch: float = 54.0
var camera_size: float = 760.0
var view_distance: float = 0.0
var dragging: bool = false
var walk_mode: bool = false
var show_labels: bool = false
var hud: CanvasLayer
var status: Label
var current_view_name: String = "A区教学楼与弘医轴线"

func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://wuming_campus/data/campus_layout.json"))
	camera = $IsometricCamera
	walker = $CampusWalker
	walker.set_physics_process(false)
	set_view(17)
	make_hud()
	set_labels(false)
	apply_camera()

func wp(p: Array) -> Vector3:
	var s: float = float(layout.map.working_pixels_per_metre)
	return Vector3((float(p[0])-750)/s,0,(float(p[1])-1400)/s)

func set_view(index: int) -> void:
	var v: Dictionary = layout.views[clampi(index,0,layout.views.size()-1)]
	target = wp(v.target)
	yaw = float(v.yaw)
	pitch = float(v.pitch)
	camera_size = float(v.size)
	view_distance = float(v.get("distance",0.0))
	current_view_name = v.name
	walk_mode = false
	if walker != null:walker.set_physics_process(false)
	apply_camera()

func apply_camera() -> void:
	if camera == null:return
	var y: float = deg_to_rad(yaw)
	var p: float = deg_to_rad(pitch)
	var distance: float = view_distance if view_distance>0 else maxf(220.0,camera_size*1.4)
	var aim: Vector3 = target + Vector3(0,5,0)
	camera.position = aim+Vector3(sin(y)*cos(p),sin(p),cos(y)*cos(p))*distance
	camera.look_at(aim,Vector3.UP)
	camera.size = camera_size
	camera.near = .5
	camera.far = maxf(600.0,camera_size*4.0+220.0)
	if status != null:
		status.text = current_view_name + ("  ·  步行" if walk_mode else "  ·  斜俯瞰")

func _process(delta: float) -> void:
	if walk_mode:
		target = target.lerp(walker.position,1-exp(-delta*5))
		apply_camera()
	elif not dragging:
		var input := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):input.y-=1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):input.y+=1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):input.x-=1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):input.x+=1
		if input.length_squared()>0:
			input=input.normalized()
			var right := Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
			var down := Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
			target += (right*input.x+down*input.y)*camera_size*.45*delta
			apply_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera_size=clampf(camera_size*(.88 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.14),18,2200)
			apply_camera()
	if event is InputEventMouseMotion and dragging:
		var right := Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
		var down := Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
		target -= (right*event.relative.x+down*event.relative.y)*camera_size/get_viewport().get_visible_rect().size.y
		apply_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key >= KEY_1 and key <= KEY_9:set_view(key-KEY_1)
		if key == KEY_0:set_view(9)
		if key == KEY_G:set_view(12)
		if key == KEY_T:set_view(13)
		if key == KEY_B:set_view(14)
		if key == KEY_C:set_view(15)
		if key == KEY_J:set_view(18)
		if key == KEY_P:get_tree().change_scene_to_file("res://wuming_campus/scenes/world/photo_teaching_detail.tscn")
		if key == KEY_O:get_tree().change_scene_to_file("res://wuming_campus/scenes/world/photo_roof_detail.tscn")
		if key == KEY_V:set_view(17)
		if key == KEY_Q:yaw-=15;apply_camera()
		if key == KEY_E:yaw+=15;apply_camera()
		if key == KEY_R:pitch=clampf(pitch+5,30,85);apply_camera()
		if key == KEY_F:pitch=clampf(pitch-5,30,85);apply_camera()
		if key == KEY_L:show_labels=not show_labels;set_labels(show_labels)
		if key == KEY_TAB:
			walk_mode=not walk_mode
			walker.set_physics_process(walk_mode)
			if walk_mode:
				walker.position=nearest_road_point(target)+Vector3(0,.8,0)
				target=walker.position
				camera_size=32
				current_view_name="校园慢行"
			apply_camera()
		if key == KEY_H:hud.visible=not hud.visible

func nearest_road_point(point: Vector3) -> Vector3:
	var best: Vector3 = wp([707,2305])
	var best_distance: float = INF
	for road in layout.roads:
		if road.kind == "public_road":continue
		for i in range(road.points.size()-1):
			var a: Vector3=wp(road.points[i])
			var b: Vector3=wp(road.points[i+1])
			var along: float=clampf((point-a).dot(b-a)/maxf((b-a).length_squared(),.001),0,1)
			var q: Vector3=a+(b-a)*along
			var distance: float=q.distance_squared_to(point)
			if distance<best_distance:best_distance=distance;best=q
	return best

func set_labels(value: bool) -> void:
	for building in $Buildings.get_children():
		if building.has_node("NameLabel"):building.get_node("NameLabel").visible=value

func make_hud() -> void:
	hud=CanvasLayer.new()
	hud.name="CampusNavigation"
	add_child(hud)
	var panel := PanelContainer.new()
	panel.position=Vector2(22,22)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.10,.16,.16,.89)
	style.content_margin_left=18
	style.content_margin_right=18
	style.content_margin_top=12
	style.content_margin_bottom=12
	style.corner_radius_top_left=8
	style.corner_radius_bottom_right=8
	panel.add_theme_stylebox_override("panel",style)
	var stack:=VBoxContainer.new()
	var title:=Label.new()
	title.text="广西医科大学 · 武鸣校区"
	title.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	title.add_theme_font_size_override("font_size",23)
	title.add_theme_color_override("font_color",Color(.92,.89,.72))
	stack.add_child(title)
	status=Label.new()
	status.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	status.add_theme_font_size_override("font_size",16)
	stack.add_child(status)
	var controls:=Label.new()
	controls.text="1–9 地标   滚轮缩放   中键拖动   Q/E 旋转\nWASD 移动   Tab 慢行   L 楼名   H 隐藏面板\nC 教学楼   J 独立钟楼   P 照片近景   O 屋顶细节\nT 双塔   B 图书馆"
	controls.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	controls.add_theme_font_size_override("font_size",14)
	controls.add_theme_color_override("font_color",Color(.72,.79,.75))
	stack.add_child(controls)
	var views := OptionButton.new()
	views.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	views.add_theme_font_size_override("font_size",14)
	for view in layout.views:views.add_item(view.name)
	views.select(17)
	views.item_selected.connect(set_view)
	stack.add_child(views)
	panel.add_child(stack)
	hud.add_child(panel)
