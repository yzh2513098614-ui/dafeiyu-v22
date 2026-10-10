extends Node
## Fixed bridge: original map geometry and interactions, v22 character and warehouse.
const Style=preload("res://ui/whale_skin.gd")
const Fit=preload("res://ui/ui_fit.gd")
var game
var level: Node3D
var definition: Dictionary={}
var floor_heights: Array=[]
var current_id:=""
var progress_by_map: Dictionary={}
var remaining: Dictionary={}
var bag: Dictionary={}
var checkpoints: Dictionary={}
var mode:=""
var floor_cutaway:=true
var extraction:=-1.0
var extraction_position:=Vector3.ZERO
var root: Control
var controls: Panel
var modal: Panel
var shade: ColorRect
var feedback: Label
var bag_button: Button
var mission_label: Label
var source_loot: Dictionary={}
var status:=""
var save_path:="user://whale_pack26_v1.json"
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/expedition/rules.json"))

static func maps() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://world_pack26/interior_pack/levels.json"))

static func register(locations: Dictionary) -> void:
	for spec in maps():
		var links: Array=["city"]
		for id in [spec.next,spec.previous]:links.append("pack26_"+str(id))
		locations["pack26_"+str(spec.id)]={"name":spec.title,"subtitle":spec.subtitle,"group":"complex","type":"pack26","map_id":spec.id,"links":links}
	locations.city.links.append("pack26_foodhall")

func configure(owner_game) -> void:
	game=owner_game
	if "--test-expedition" in OS.get_cmdline_user_args():save_path="res://预览/pack26_smoke_save.json"
	if FileAccess.file_exists(save_path):
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(save_path))
		progress_by_map=saved.progress;remaining=saved.remaining;bag=saved.bag;checkpoints=saved.checkpoints
	var layer:=CanvasLayer.new();layer.layer=60;add_child(layer)
	root=Control.new();root.theme=Style.theme(game._game_font());root.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(root);Fit.fill(root)
	controls=Style.panel(root,Vector2(1098,368),Vector2(302,430),"paper");Fit.pin_right(controls,302,48,368,430)
	Style.label(controls,"立体新区 · 26张地图",Vector2(13,12),Vector2(276,33),22)
	_button(controls,"H 显示 / 隐藏上层",Vector2(13,57),Vector2(276,44),func():floor_cutaway=not floor_cutaway)
	_button(controls,"V 墙壁切面",Vector2(13,109),Vector2(276,44),func():level.set_wall_cutaway(not level.cutaway_walls))
	bag_button=_button(controls,"N 新区背包",Vector2(13,161),Vector2(276,44),open_bag)
	_button(controls,"返回鲸落港",Vector2(13,213),Vector2(276,44),func():game.request_travel("city"))
	mission_label=Style.label(controls,"",Vector2(13,270),Vector2(276,147),17)
	shade=ColorRect.new();shade.color=Color(.05,.10,.17,.36);root.add_child(shade);Fit.fill(shade);shade.hide()
	root.hide()

func is_active() -> bool:
	return current_id!="" and is_instance_valid(level)

func blocked() -> bool:
	return mode!=""

func build(id: String) -> Dictionary:
	for spec in maps():
		if spec.id==id:definition=spec;break
	current_id=id;mode="";extraction=-1;floor_cutaway=HarborPrefs.values.follow;root.show();shade.hide()
	floor_heights=[]
	for room in definition.rooms:
		var height: float=float(room.get("height",0.0))
		if not height in floor_heights:floor_heights.append(height)
	floor_heights.sort()
	level=load(definition.scene).instantiate();level.standalone_preview=false;game.world.add_child(level)
	preload("res://district/stair_space.gd").apply(level.get_node("Architecture"))
	_separate_stair_support()
	preload("res://district/stair_clearance.gd").apply(level.get_node("Architecture"))
	var slabs: Array=[]
	for slab in level.get_node("Architecture").find_children("*","StaticBody3D",true,false):
		if slab.has_meta("walkable_top"):slabs.append(slab)
	game.silhouette_body.set_meta("floor_slabs",slabs)
	game.player.set_meta("floor_slabs",slabs)
	level.apply_progress(progress_by_map.get(id,{"keys":[],"switches":[],"opened":[],"container_open":[],"checkpoint":"","visited":[]}))
	level.interaction_requested.connect(_interaction)
	level.world_exit_requested.connect(func(destination,_spawn):game.request_travel.call_deferred("city" if destination=="city" else "pack26_"+destination))
	level.progress_changed.connect(func(snapshot):progress_by_map[current_id]=snapshot)
	var spawn: Vector3=level.get_node("Spawns/Entrance").global_position+Vector3(0,.04,0)
	var harbor_exit:=Marker3D.new();harbor_exit.name="HarborReturn";harbor_exit.position=spawn+Vector3(0,-.04,2.5)
	harbor_exit.set_meta("kind","portal");harbor_exit.set_meta("interaction_id",id+"_harbor_return");harbor_exit.set_meta("title","返回鲸落港");harbor_exit.set_meta("destination","city");level.get_node("Interactions").add_child(harbor_exit)
	game._exit(harbor_exit.global_position,"city","返回鲸落港","entrance")
	for marker in level.get_node("Interactions").get_children():
		if marker.get_meta("kind")=="portal" and marker!=harbor_exit:
			game.portals.append({"pos":marker.global_position,"spawn":marker.global_position,"target":"pack26_"+str(marker.get_meta("destination")),"label":str(marker.get_meta("title")),"route":"entrance"})
	if not checkpoints.has(id):checkpoints[id]=[spawn.x,spawn.y,spawn.z]
	game.player.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED;game.player.collision_layer=4;game.player.collision_mask=3;game.player.floor_snap_length=.35
	game.player.floor_max_angle=deg_to_rad(48)
	game.player.floor_constant_speed=true;game._configure_character_collision(true)
	var zones: Array=[]
	for room in definition.rooms:
		var rect: Array=room.rect
		var height: float=float(room.get("height",0.0))
		zones.append({"id":str(room.id),"name":str(room.get("floor_label",""))+" · "+str(room.name),"rect":Rect2(rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1]),"height":height,"center":Vector3(room.center[0],height,room.center[1])})
	game.breadcrumb.hide();game.arrival_note.hide()
	mission_label.text=str(definition.mission)
	for room in definition.rooms:
		if room.id==definition.exit_region:mission_label.text+="\n撤离点："+str(room.name)
	for marker in level.get_node("Interactions").get_children():
		if marker.get_meta("kind")!="extract":continue
		var beacon: MeshInstance3D=level.get_node("Signals/"+str(marker.name)+"_Beacon")
		var material: StandardMaterial3D=beacon.material_override.duplicate();material.albedo_color=Color("69ba96");material.emission_enabled=false;beacon.material_override=material
		var label:=Label3D.new();label.text="撤离 · 停留5秒";label.font=game._game_font();label.font_size=24;label.pixel_size=.01;label.position=marker.position+Vector3(0,.85,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("a9e3c0");label.outline_size=4;label.shaded=false;label.set_meta("floor_height",marker.position.y);level.add_child(label)
	status="已进入 "+str(definition.title)+"。沿真实楼梯跨层，找通行卡与配电开关。"
	return {"bounds":Vector2(definition.size[0],definition.size[1]),"spawn":spawn,"zones":zones,"camera_size":maxf(definition.size[0],definition.size[1])*1.2}

func _separate_stair_support() -> void:
	for body in level.get_node("Architecture").find_children("*Body","StaticBody3D",true,false):
		var label:=str(body.name)
		if label.begins_with("Floor") or label.begins_with("StoreyFloor") or label=="HalfLandingBody":
			body.collision_layer=2;body.collision_mask=4
	for slope in level.get_node("Architecture").find_children("WalkableSlope","StaticBody3D",true,false):
		var shape: CollisionShape3D=slope.get_node_or_null("Shape")
		if not shape:continue
		# Ramp and side guards were one layer-1 body. Keep the guards solid for
		# the entire character while treating only the ramp as floor support.
		var support:=StaticBody3D.new();support.name="StairSupport";support.collision_layer=10;support.collision_mask=4
		slope.get_parent().add_child(support);support.global_transform=slope.global_transform
		shape.reparent(support,true)
		support.set_meta("stair_support",true)

func overview_center() -> Vector3:
	return Vector3(definition.origin[0]+definition.size[0]*.5,0,definition.origin[1]+definition.size[1]*.5)

func leave() -> void:
	if is_active():progress_by_map[current_id]=level.capture_progress();save()
	current_id="";mode="";root.hide();extraction=-1
	game.player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING;game.player.collision_layer=4;game.player.collision_mask=1
	game._configure_character_collision(false)
	game.character_material.set_shader_parameter("floor_height",game.CHARACTER_FLOOR_Y)
	game.loot._bag_count()
	game.breadcrumb.show();game.arrival_note.show()

func physics(delta: float) -> void:
	var before: Vector3=game.player.position
	var direction: Vector2=game.movement
	if not game.transitioning and not game.dialog_open and not game.panel.visible and not game.settings_panel.visible and not game.loot.blocked() and not game.map_panel.visible and not blocked():
		direction+=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	else:direction=Vector2.ZERO
	var pace: float=game.character_controller.model.speed_multiplier(Input.is_physical_key_pressed(KEY_SHIFT)) if game.character_controller else 1.0
	var planar: Vector3=game._screen_direction_to_world(direction)*game.SPEED*pace
	game.player.velocity.x=planar.x;game.player.velocity.z=planar.z
	game.player.velocity.y=0.0 if game.player.is_on_floor() else game.player.velocity.y-18.0*delta
	game._move_character(delta,true)
	var travel: Vector3=game.player.position-before
	game.facing_accum+=game._character_screen_travel(travel);game.facing_timer+=delta
	if game.facing_timer>=game.FACING_WINDOW:
		if game.facing_accum.length()>game.FACING_MIN_TRAVEL:game.facing=game._direction_name(game.facing_accum)
		game.facing_accum=Vector2.ZERO;game.facing_timer=0.0
	game._advance_character_gait(travel,delta)
	game.character_material.set_shader_parameter("floor_height",game.player.global_position.y+game.CHARACTER_FLOOR_Y)
	var desired: Vector3=overview_center() if game.overview_mode else game.player.position
	game.view_center=game.view_center.lerp(desired,1.0-exp(-delta*7.0) if HarborPrefs.values.smooth_camera else 1.0)
	game.camera.size=lerpf(game.camera.size,game.view_size,1.0-exp(-delta*8.0));game._camera();game._refresh_zone()
	if game.character_controller:game.character_controller.advance(delta,before)
	var free_ui: bool=not game.dialog_open and not game.map_panel.visible and not game.settings_panel.visible and not game.loot.blocked() and not blocked()
	controls.visible=free_ui;game.view_button.visible=free_ui;game.zone_label.visible=free_ui;game.clock_panel.visible=free_ui
	game._route_frame(free_ui)
	game.clock_label.text=game.atmosphere.clock_text()
	var height: float=-100
	for value in floor_heights:
		if game.player.position.y>float(value)-.65:height=float(value)
	level.set_floor_view(height,floor_cutaway)
	var marker=level.nearest_interaction(game.player.global_position)
	game.hint.text="E · "+str(marker.get_meta("title"))+"  ·  N 新区背包" if marker else "WASD 漫步 · H 上层切面 · V 墙壁切面 · Z 总览 · M 导览"
	bag_button.text="N 新区背包 %d/20"%occupied()
	game.loot.bag_button.text="I 新区背包 %d/20"%occupied()
	if extraction>=0:
		if game.player.position.distance_to(extraction_position)>2:extraction=-1;game.hint.text="已离开撤离范围，撤离取消。"
		else:
			extraction-=delta;game.hint.text="撤离中 · 保持在出口附近 %.1f 秒"%maxf(extraction,0)
			if extraction<=0:_extract()
	if game.player.position.y<-12:
		_return_to_checkpoint()

func _return_to_checkpoint() -> void:
	var point: Array=checkpoints[current_id]
	game.player.position=Vector3(point[0],point[1],point[2]);game.player.velocity=Vector3.ZERO
	game._queue_collision_recovery();game._reset_character_gait()
	game.character_material.set_shader_parameter("floor_height",game.player.global_position.y+game.CHARACTER_FLOOR_Y)

func _interaction(kind: String, item: Dictionary) -> void:
	match kind:
		"key":status="获得 "+str(item.title)+"，对应权限门已开启。"
		"switch":status="配电恢复，对应近路已经开启。"
		"checkpoint":checkpoints[current_id]=[game.player.position.x,game.player.position.y,game.player.position.z];status="已记录补给点，R 返回此处。"
		"chest":
			var id: String=current_id+":"+str(item.id)
			if not remaining.has(id):
				var loot: Dictionary={}
				for name in item.loot:loot[name]=int(loot.get(name,0))+1
				remaining[id]=loot
			source_loot={"id":id,"marker_id":item.id,"title":item.title};_open_loot()
		"extract":extraction=5;extraction_position=item.position
	save()

func _resource(name: String) -> String:
	if name.contains("Token") or name.contains("代币"):return "token"
	if name.contains("通行") or name.contains("权限"):return "key"
	if name.contains("药") or name.contains("急救") or name.contains("医疗") or name.contains("补给"):return "medical"
	if name.contains("样本"):return "sample"
	if name.contains("蓝图"):return "blueprint"
	if name.contains("芯片") or name.contains("运算"):return "chip"
	if name.contains("权重"):return "weights"
	if name.contains("零件") or name.contains("工具") or name.contains("维修") or name.contains("线缆"):return "parts"
	if name.contains("模块") or name.contains("存储"):return "storage"
	return "fragments"

func occupied() -> int:
	var count:=0
	for name in bag:count+=int(bag[name])*int(rules.resources[_resource(name)].size)
	return count

func _button(parent: Node,text: String,pos: Vector2,size: Vector2,action: Callable) -> Button:
	var button:=Button.new();button.text=text;button.position=pos;button.size=size;button.pressed.connect(action);button.add_theme_font_size_override("font_size",20);parent.add_child(button);return button

func _panel(title: String) -> void:
	if is_instance_valid(modal):modal.hide();modal.queue_free()
	shade.show();modal=Style.panel(root,Vector2(224,154),Vector2(1000,772));Fit.pin_center(modal,1000,154,772)
	Style.label(modal,title,Vector2(29,21),Vector2(942,47),30)
	feedback=Style.label(modal,status,Vector2(29,649),Vector2(942,55),21)
	_button(modal,"关闭",Vector2(29,715),Vector2(942,39),close)

func _open_loot() -> void:
	mode="loot";_panel("搜索 · "+str(source_loot.title))
	var goods: Dictionary=remaining[source_loot.id];var row:=0
	for id in goods:
		if int(goods[id])<=0:continue
		var card:=Style.panel(modal,Vector2(29,95+row*79),Vector2(942,69),"sky")
		var size: int=int(rules.resources[_resource(id)].size)
		Style.label(card,"%s ×%d · 每件%d格"%[id,goods[id],size],Vector2(16,16),Vector2(667,38),24)
		_button(card,"收取一件",Vector2(716,13),Vector2(210,43),func():
			if occupied()+size>20:status="背包已满，先丢弃物资或去出口撤离。"
			else:
				bag[id]=int(bag.get(id,0))+1;goods[id]-=1;status="物资已收入新区背包，安全撤离后才进入仓库。"
				var stock:=0
				for count in goods.values():stock+=int(count)
				if stock==0:level.mark_chest_empty(source_loot.marker_id)
				save()
			_open_loot())
		row+=1
	Style.label(modal,"背包 %d/20 · 容器库存固定，切换地图不会刷新。"%occupied(),Vector2(29,570),Vector2(942,40),23)

func open_bag() -> void:
	mode="bag";_panel("新区背包 · 待撤离物资")
	var scroll:=ScrollContainer.new();scroll.position=Vector2(29,90);scroll.size=Vector2(942,474);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;modal.add_child(scroll)
	var rows:=VBoxContainer.new();rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rows.add_theme_constant_override("separation",5);scroll.add_child(rows)
	for id in bag:
		if int(bag[id])<=0:continue
		var row:=HBoxContainer.new();row.custom_minimum_size.y=44;rows.add_child(row)
		var nameplate:=Label.new();nameplate.text="%s ×%d · 每件%d格"%[id,bag[id],rules.resources[_resource(id)].size];nameplate.size_flags_horizontal=Control.SIZE_EXPAND_FILL;nameplate.add_theme_font_size_override("font_size",23);row.add_child(nameplate)
		var discard:=Button.new();discard.text="丢弃一件";discard.custom_minimum_size=Vector2(182,36);discard.pressed.connect(func():bag[id]-=1;save();open_bag());row.add_child(discard)
	Style.label(modal,"容量 %d/20 · 到地图中的绿色撤离点，停留5秒。\n带回的材料可用于研究中心的装备工坊。"%occupied(),Vector2(29,577),Vector2(942,65),23)

func close() -> void:
	mode="";shade.hide();modal.hide()

func _extract() -> void:
	extraction=-1
	var economy=game.expedition_controller.state
	var total:=0
	for name in bag:
		var id:=_resource(name)
		economy.profile.warehouse[id]=int(economy.profile.warehouse.get(id,0))+int(bag[name]);total+=int(bag[name])
		if id=="blueprint" and int(bag[name])>0 and not "context_overflow" in economy.profile.blueprints:economy.profile.blueprints.append("context_overflow")
	economy.save();bag.clear();save()
	status="撤离成功 · %d 件物资已进入港口仓库，可用于制作装备。"%total
	mode="extracted";_panel("撤离成功")
	Style.label(modal,status,Vector2(29,101),Vector2(942,103),28)
	_button(modal,"回港查看仓库与工坊",Vector2(29,265),Vector2(942,61),func():close();game.request_travel("city"))
	_button(modal,"继续探索这张地图",Vector2(29,351),Vector2(942,55),close)

func save() -> void:
	if is_active():progress_by_map[current_id]=level.capture_progress()
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"progress":progress_by_map,"remaining":remaining,"bag":bag,"checkpoints":checkpoints}))

func handle_input(event: InputEvent) -> bool:
	if not is_active():return false
	if event is InputEventKey and event.pressed and not event.echo:
		if blocked():
			if event.physical_keycode==KEY_ESCAPE:close()
			return true
		if game.transitioning or game.dialog_open or game.map_panel.visible or game.settings_panel.visible or game.loot.blocked() or game.pause_menu.active or game.character_controller.active:return false
		match event.physical_keycode:
			KEY_E:
				var marker=level.nearest_interaction(game.player.position)
				if marker:level.activate(marker)
				return true
			KEY_N,KEY_I:open_bag();return true
			KEY_H:floor_cutaway=not floor_cutaway;return true
			KEY_V:level.set_wall_cutaway(not level.cutaway_walls);return true
			KEY_R:
				_return_to_checkpoint();return true
			KEY_TAB,KEY_B:game.hint.text="新区保留原地图布置，请在 Godot 中编辑场景。";return true
	return blocked() and event is InputEventMouseButton
