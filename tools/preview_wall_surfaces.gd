extends "res://tools/preview_restaurant_composition.gd"
const Surfaces=preload("res://district/wall_surfaces.gd")

func _initialize() -> void:
	prefix="内外墙纹理_"
	call_deferred("capture")

func view(id: String,center: Vector3,size: float) -> void:
	game._travel(id);game.set_physics_process(false);game.atmosphere.set_time(14);game.atmosphere.cycle_enabled=false;game.ui.hide()
	restaurant_view(center,size)

func swatches() -> void:
	game.world.hide();game.shell.hide()
	var board:=Node3D.new();board.name="WallMaterialSwatches";game.add_child(board)
	var builder=game._builder(board);var n:=0
	for id in Surfaces.PRESETS:
		var recipe: Dictionary=Surfaces.PRESETS[id]
		var outside: bool=recipe.scope=="外墙"
		var material: ShaderMaterial=Surfaces.material(id,Vector3.RIGHT,outside,Color(recipe.tint)).duplicate()
		material.set_shader_parameter("wainscot_height",0.0);material.set_shader_parameter("plinth",false)
		ResourceSaver.save(Surfaces.material(id,Vector3.RIGHT,outside,Color(recipe.tint)),"res://assets/modern/wall_surfaces/"+id+".tres")
		var point:=Vector3((n%4-1.5)*3.9,6.4-floori(n/4.)*2.3,0)
		builder.box(Vector3(3.2,1.5,.20),point,Color(recipe.tint)).material_override=material
		var label:=Label3D.new();label.position=point+Vector3(0,-1.04,.20);label.text=recipe.name;label.font_size=26;label.pixel_size=.008
		label.modulate=Color("e4eceb");label.outline_modulate=Color("243849");label.outline_size=4;board.add_child(label)
		n+=1
	game.camera.size=10.8;game.camera.near=.1;game.camera.far=100
	game.camera.position=Vector3(.9,4.2,20);game.camera.look_at(Vector3(0,4.2,0))
	await frame("12套材质实机样板")

func capture() -> void:
	root.size=Vector2i(1200,850);AudioServer.set_bus_mute(0,true)
	var prefs=root.get_node("HarborPrefs")
	prefs.continue_game=false;prefs.starting_place="restaurant_2"
	prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.effects=true
	game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
	game.set_physics_process(false);game.atmosphere.set_time(14);game.atmosphere.cycle_enabled=false;game.ui.hide()
	for i in 3:await process_frame
	restaurant_view(Vector3(-8,0,-3),14);await frame("餐厅木饰面与墙纸")
	view("restaurant_1",Vector3(10,0,-10),14);await frame("后厨瓷砖")
	view("city",Vector3(-33,0,45),22);await frame("餐厅错缝砖外墙")
	restaurant_view(Vector3(-12,0,45),23);await frame("学校灰蓝外墙")
	restaurant_view(Vector3(20,0,45),23);await frame("医院石材外墙")
	restaurant_view(Vector3(-29,0,-3.5),20);await frame("咖啡馆横木外墙")
	await swatches()
	FileAccess.open("res://预览/内外墙纹理_灯光记录.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
	print("WALL SURFACES COMPLETE: ",Surfaces.PRESETS.size()," reusable materials / 4 original textures")
	quit()
