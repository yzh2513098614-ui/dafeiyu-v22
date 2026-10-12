extends Node3D

var camera: Camera3D
var hud: CanvasLayer
var current_view: int = 0

func _ready() -> void:
	camera=$RoofCamera
	set_view(0)
	hud=CanvasLayer.new()
	add_child(hud)
	var panel:=PanelContainer.new()
	panel.position=Vector2(24,24)
	var stack:=VBoxContainer.new()
	var title:=Label.new()
	title.text="武鸣校区 · 屋顶细节"
	title.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	title.add_theme_font_size_override("font_size",24)
	stack.add_child(title)
	var select:=OptionButton.new()
	select.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	for label in ["1 教学楼灰瓦与檐口","2 独立钟楼两段尖顶","3 双塔阶梯弧顶","4 图书馆环形曲顶"]:select.add_item(label)
	select.item_selected.connect(set_view)
	stack.add_child(select)
	var help:=Label.new()
	help.text="1–4 切换 · 滚轮缩放 · Q/E 旋转 · Esc 返回校园"
	help.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	stack.add_child(help)
	panel.add_child(stack)
	hud.add_child(panel)

func set_view(index: int) -> void:
	current_view=clampi(index,0,3)
	for j in range(4):
		var model: Node3D=get_node(["TeachingRoofStudy","IndependentClockRoofStudy","TowerCrownStudy","LibraryRoofStudy"][j])
		model.visible=j==current_view
		if model.has_node("NameLabel"):model.get_node("NameLabel").visible=false
	var at: Vector3
	var aim: Vector3
	match current_view:
		1:
			at=Vector3(45,51,60)
			aim=Vector3(0,33.0,0)
			camera.size=21
		2:
			at=Vector3(-103,97,110)
			aim=Vector3(-4,53.2,0)
			camera.size=46
		3:
			at=Vector3(136,154,178)
			aim=Vector3(0,18,0)
			camera.size=122
		_:
			at=Vector3(44,55,67)
			aim=Vector3(0,21.7,0)
			camera.size=35
	camera.position=at
	camera.look_at(aim)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=.25
	camera.far=800

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:set_view(event.physical_keycode-KEY_1)
		if event.physical_keycode in [KEY_Q,KEY_E]:
			var aim: Vector3=[Vector3(0,21.7,0),Vector3(0,33.0,0),Vector3(-4,53.2,0),Vector3(0,18,0)][current_view]
			camera.position=aim+(camera.position-aim).rotated(Vector3.UP,deg_to_rad(15 if event.physical_keycode==KEY_E else -15))
			camera.look_at(aim)
		if event.physical_keycode==KEY_H:hud.visible=not hud.visible
		if event.physical_keycode==KEY_ESCAPE:get_tree().change_scene_to_file("res://wuming_campus/scenes/world/campus.tscn")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size*=.9
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size*=1.1
