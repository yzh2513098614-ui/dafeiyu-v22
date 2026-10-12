extends Node3D

var camera: Camera3D
var hud: CanvasLayer
var current_view: int = 0

func _ready() -> void:
	camera=$DetailCamera
	set_view(0)
	hud=CanvasLayer.new()
	add_child(hud)
	var panel:=PanelContainer.new()
	panel.position=Vector2(24,24)
	var stack:=VBoxContainer.new()
	var title:=Label.new()
	title.text="教学楼与独立钟楼 · 照片细节"
	title.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	title.add_theme_font_size_override("font_size",24)
	stack.add_child(title)
	var select:=OptionButton.new()
	select.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	for name in ["1 两栋独立建筑与间距","2 教学楼正面立面","3 独立钟楼近景"]:select.add_item(name)
	select.item_selected.connect(set_view)
	stack.add_child(select)
	var help:=Label.new()
	help.text="1/2/3 切换视角 · O 屋顶细节 · 滚轮缩放 · Esc 返回校园"
	help.add_theme_font_override("font",load("res://wuming_campus/assets/fonts/NotoSansSC.ttf"))
	stack.add_child(help)
	panel.add_child(stack)
	hud.add_child(panel)

func set_view(index: int) -> void:
	current_view=index
	$IndependentTeachingBuilding.visible=index!=2
	$IndependentClocktower.visible=index!=1
	$FrontGardenPlanting.visible=index!=2
	var at: Vector3
	var aim: Vector3
	match index:
		1:
			at=Vector3(8,21,82)
			aim=Vector3(0,11.5,-8.5)
			camera.size=34
		2:
			at=Vector3(67,37,72)
			aim=Vector3(29,19,15)
			camera.size=43
		_:
			at=Vector3(-74,65,118)
			aim=Vector3(7,16,0)
			camera.size=66
	camera.position=at
	camera.look_at(aim)
	camera.far=500
	camera.near=.25
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_1,KEY_2,KEY_3]:set_view(event.physical_keycode-KEY_1)
		if event.physical_keycode==KEY_H:hud.visible=not hud.visible
		if event.physical_keycode==KEY_O:get_tree().change_scene_to_file("res://wuming_campus/scenes/world/photo_roof_detail.tscn")
		if event.physical_keycode==KEY_ESCAPE:get_tree().change_scene_to_file("res://wuming_campus/scenes/world/campus.tscn")
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size*=.9
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size*=1.1
