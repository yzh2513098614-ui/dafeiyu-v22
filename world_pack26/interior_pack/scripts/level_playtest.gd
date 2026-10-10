extends Node3D
## Optional standalone test rig. Maps themselves remain independent of this controller.
var embedded_level: Node3D
var level: Node3D
var player: CharacterBody3D
var camera: Camera3D
var scene_environment: Environment
var key_light: DirectionalLight3D
var definitions: Array = []
var definition: Dictionary = {}
var state = {"keys": [], "switches": [], "opened": [], "checkpoint": "", "visited": []}
var remaining: Dictionary = {}
var bag: Dictionary = {}
var stash: Dictionary = {}
var checkpoint_position = Vector3(0,0,.7)
var current_id = "foodhall"
var overlay: Control
var status: Label
var prompt: Label
var mission: Label
var bag_count: Label
var map_view: Control
var modal: PanelContainer
var modal_rows: VBoxContainer
var modal_title: Label
var overview = false
var floor_cutaway = false
var extraction = -1.0
var extraction_position = Vector3.ZERO
var tick = 0
var demo = false
var busy_loading = false
var demo_phase = 0
var screenshot_mode = false
var map_selection: OptionButton
var demo_maps = ["foodhall","expo","sports","datacenter","emergency","media"]
func _ready() -> void:
    definitions = JSON.parse_string(FileAccess.get_file_as_string("res://world_pack26/interior_pack/levels.json"))
    _lights()
    _ui()
    if embedded_level:
        level = embedded_level
        for d in definitions:
            if d.id == level.level_id:
                definition = d
                current_id = d.id
        _bind()
    else:
        _load_level("foodhall")
    var args = OS.get_cmdline_user_args()
    demo = "--level-demo" in args
    if "--city-wave-demo" in args:
        demo_maps = ["library","sports","foodhall","museum","fabrication","skypark"]
    if "--previous-wave-demo" in args:
        demo_maps = ["residence","research","datacenter","harbor","transit"]
    screenshot_mode = "--level-shots" in args
    if screenshot_mode:
        call_deferred("_screenshots")
func _lights() -> void:
    var env = WorldEnvironment.new()
    var e = Environment.new()
    scene_environment = e
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("d8e9f5")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("d8eaff")
    e.ambient_light_energy = .30
    env.environment = e
    add_child(env)
    var key = DirectionalLight3D.new()
    key_light = key
    key.rotation_degrees = Vector3(-55,-28,0)
    key.light_color = Color("fff5e8")
    key.light_energy = .52
    key.shadow_enabled = true
    key.directional_shadow_max_distance = 65
    add_child(key)
    var fill = DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-35,135,0)
    fill.light_color = Color("cbe8ff")
    fill.light_energy = .10
    add_child(fill)
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.current = true
    add_child(camera)
func _load_level(id: String,preserve_current: bool=true) -> void:
    if embedded_level:
        for d in definitions:
            if d.id == id:
                get_tree().change_scene_to_file(d.scene)
        return
    busy_loading = true
    if is_instance_valid(level):
        if preserve_current:
            state = level.capture_progress()
        remove_child(level)
        level.queue_free()
    for d in definitions:
        if d.id == id:
            definition = d
    current_id = id
    level = load(definition.scene).instantiate()
    level.standalone_preview = false
    add_child(level)
    _bind()
    busy_loading = false
func _bind() -> void:
    var night = current_id == "nightmarket"
    scene_environment.background_color = Color("b4c7e0" if night else "d8e9f5")
    scene_environment.ambient_light_color = Color("9cb7e2" if night else "d8eaff")
    scene_environment.ambient_light_energy = .35 if night else .30
    key_light.light_energy = .23 if night else .52
    level.apply_progress(state)
    level.interaction_requested.connect(_interaction)
    level.world_exit_requested.connect(func(id, _spawn): _load_level.call_deferred(id))
    level.progress_changed.connect(func(snapshot): state = snapshot)
    level.zone_entered.connect(func(_region,name,_risk):
        if extraction<0:status.text="当前区域："+name+" · 钥匙、箱子和近路进度会保留"
    )
    if is_instance_valid(player):
        player.queue_free()
    player = CharacterBody3D.new()
    player.set_script(load("res://world_pack26/interior_pack/scripts/map_player.gd"))
    add_child(player)
    player.global_position = level.get_node("Spawns/Entrance").global_position + Vector3(0,.04,0)
    checkpoint_position = player.global_position
    map_view.set("definition",definition)
    map_view.set("level",level)
    map_view.set("player",player)
    if map_selection:
        for index in definitions.size():
            if definitions[index].id==current_id:map_selection.select(index)
    extraction = -1
    modal.hide()
    status.text = "已进入 "+str(definition.title)+" · "+str(definition.rooms.size())+"个区域等待探索"
    _camera(true)
func _ui() -> void:
    var layer = CanvasLayer.new()
    add_child(layer)
    overlay = Control.new()
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.size = Vector2(1280,900)
    layer.add_child(overlay)
    var theme = Theme.new()
    var face = FontVariation.new()
    face.base_font = load("res://world_pack26/interior_pack/assets/NotoSansSC.ttf")
    face.variation_opentype = {2003265652:600.0}
    theme.default_font = face
    theme.default_font_size = 19
    theme.set_color("font_color","Label",Color("24456c"))
    for key in ["normal","hover","pressed","focus"]:
        var style = StyleBoxFlat.new()
        style.bg_color = Color("b9d6ee" if key=="pressed" else ("e1f3ff" if key=="hover" else "f7fbff"))
        style.border_color = Color("88aace")
        style.set_border_width_all(2)
        style.set_corner_radius_all(10)
        style.content_margin_left=12
        style.content_margin_right=12
        style.content_margin_top=8
        style.content_margin_bottom=8
        theme.set_stylebox(key,"Button",style)
    theme.set_color("font_color","Button",Color("24456c"))
    theme.set_color("font_hover_color","Button",Color("24456c"))
    theme.set_color("font_pressed_color","Button",Color("24456c"))
    overlay.theme = theme
    _panel(Rect2(18,14,1244,76))
    var badge = Control.new()
    badge.set_script(load("res://world_pack26/interior_pack/scripts/whale_ui_badge.gd"))
    badge.position = Vector2(26,21)
    badge.size = Vector2(75,55)
    overlay.add_child(badge)
    _label("一个大肥鱼同人SLG · 连通探索关卡",Vector2(109,24),Vector2(695,35),27)
    _label("鲸蓝城市漫游 / 通行卡与秘密支线 / 搜索与撤离",Vector2(111,59),Vector2(685,26),17)
    var selection = OptionButton.new()
    map_selection = selection
    selection.position = Vector2(925,31)
    selection.size = Vector2(316,46)
    for i in definitions.size():
        selection.add_item(str(definitions[i].title))
        if definitions[i].id == current_id: selection.select(i)
    selection.item_selected.connect(func(index): _load_level(str(definitions[index].id)))
    overlay.add_child(selection)
    _panel(Rect2(968,107,291,416))
    _label("鲸鱼探索地图",Vector2(986,116),Vector2(253,30),23)
    map_view = Control.new()
    map_view.set_script(load("res://world_pack26/interior_pack/scripts/level_minimap.gd"))
    map_view.position = Vector2(983,155)
    map_view.size = Vector2(260,215)
    overlay.add_child(map_view)
    _label("蓝点：自己  金点：箱子\n蓝紫：钥匙/开关  绿点：出口",Vector2(986,377),Vector2(255,56),17)
    mission = _label("",Vector2(986,438),Vector2(255,80),17)
    _panel(Rect2(18,790,1244,93))
    prompt = _label("",Vector2(35,799),Vector2(990,30),22)
    status = _label("",Vector2(35,832),Vector2(990,27),18)
    bag_count = _label("背包：0",Vector2(1086,807),Vector2(149,30),20)
    _button("背包 B",Vector2(1084,843),Vector2(149,32),_inventory)
    _label("WASD移动 · E交互 · M全图 · H隐藏上层 · V墙壁切面 · R补给点 · F9存档/F10读取",Vector2(28,747),Vector2(1160,30),18)
    modal = PanelContainer.new()
    modal.position = Vector2(325,231)
    modal.size = Vector2(605,395)
    modal.add_theme_stylebox_override("panel",_style())
    overlay.add_child(modal)
    var margin = MarginContainer.new()
    for k in ["margin_left","margin_right","margin_top","margin_bottom"]:
        margin.add_theme_constant_override(k,22)
    modal.add_child(margin)
    var list = VBoxContainer.new()
    list.add_theme_constant_override("separation",12)
    margin.add_child(list)
    modal_title = Label.new()
    modal_title.add_theme_font_size_override("font_size",25)
    list.add_child(modal_title)
    modal_rows = VBoxContainer.new()
    modal_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
    list.add_child(modal_rows)
    var close = Button.new()
    close.text = "关闭 · Esc"
    close.pressed.connect(_close_modal)
    list.add_child(close)
    modal.hide()
func _style() -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = Color("f5fbff")
    style.border_color = Color("7c9fc7")
    style.set_border_width_all(3)
    style.set_corner_radius_all(18)
    style.shadow_color = Color(0.15,.30,.5,.13)
    style.shadow_size = 6
    return style
func _panel(rect: Rect2) -> void:
    var panel = Panel.new()
    panel.position=rect.position
    panel.size=rect.size
    panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel",_style())
    overlay.add_child(panel)
func _label(text: String,pos: Vector2,size: Vector2,fs: int) -> Label:
    var label = Label.new()
    label.text=text
    label.position=pos
    label.size=size
    label.add_theme_font_size_override("font_size",fs)
    label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    overlay.add_child(label)
    return label
func _button(text: String,pos: Vector2,size: Vector2,callback: Callable) -> void:
    var button=Button.new()
    button.text=text
    button.position=pos
    button.size=size
    button.pressed.connect(callback)
    overlay.add_child(button)
func _clear_rows() -> void:
    for node in modal_rows.get_children():
        modal_rows.remove_child(node)
        node.queue_free()
func _close_modal() -> void:
    modal.hide()
    player.paused=false
func _inventory() -> void:
    _clear_rows()
    modal_title.text="大肥鱼背包 / 已撤离仓库"
    for item in bag:
        var label=Label.new()
        label.text=str(item)+" × "+str(bag[item])
        modal_rows.add_child(label)
    var total=0
    for count in stash.values():
        total+=count
    var label=Label.new()
    label.text="已撤离入库："+str(total)+" 件"
    modal_rows.add_child(label)
    modal.show()
    player.paused=true
func _interaction(kind: String,data: Dictionary) -> void:
    if demo:print("DEMO INTERACTION ",current_id," ",kind," ",data.id)
    match kind:
        "key": status.text="获得 "+str(data.title)+" · 对应权限门已解锁"
        "switch": status.text="配电恢复！中庭近路已打开，可以绕回补给点。"
        "checkpoint":
            checkpoint_position=player.global_position
            status.text="补给点已记录 · R返回此处"
        "chest": _show_chest(data)
        "extract":
            extraction=5.0
            extraction_position=data.position
            status.text="撤离开始：停留5秒，离开范围将取消"
func _show_chest(data: Dictionary) -> void:
    _clear_rows()
    modal_title.text="搜索 · "+str(data.title)
    if not remaining.has(data.id):
        remaining[data.id]=data.loot.duplicate()
    for item in remaining[data.id].duplicate():
        var button=Button.new()
        button.text="取走："+str(item)+"  →  背包"
        button.pressed.connect(func():
            _take(data.id,str(item))
            _show_chest(data)
        )
        modal_rows.add_child(button)
    if remaining[data.id].is_empty():
        var label=Label.new()
        label.text="这里已经搜空啦。"
        modal_rows.add_child(label)
    modal.show()
    player.paused=true
func _take(chest_id: String,item: String) -> void:
    if not remaining.has(chest_id) or item not in remaining[chest_id]:
        return
    remaining[chest_id].erase(item)
    if demo:print("DEMO INVENTORY ",current_id," ",item)
    bag[item]=int(bag.get(item,0))+1
    if remaining[chest_id].is_empty():
        level.mark_chest_empty(chest_id)
    status.text="已收入背包："+item
func _process(delta: float) -> void:
    if not is_instance_valid(player) or busy_loading:
        return
    var storey=0.0
    for height in definition.get("floor_heights",[0,3.6] if not definition.get("stairs",[]).is_empty() else [0]):
        if player.global_position.y>float(height)-.65:storey=float(height)
    level.set_floor_view(storey,floor_cutaway)
    var target=level.nearest_interaction(player.global_position)
    prompt.text="E · "+str(target.get_meta("title")) if target else "探索支线获取通行卡 · 回环路线避开锁门"
    mission.text=str(definition.get("mission","蓝卡：学生/检查/服装区\n红卡：教室/影像/咖啡区\n近路开关：西南区域"))
    var count=0
    for n in bag.values(): count+=n
    bag_count.text="背包："+str(count)+" 件"
    if extraction>=0:
        if player.global_position.distance_to(extraction_position)>2:
            extraction=-1
            status.text="离开撤离范围，倒计时取消"
        else:
            extraction-=delta
            prompt.text="正在撤离 … "+str(snappedf(maxf(0,extraction),.1))+" 秒"
            if extraction<=0:
                extraction=-1
                for item in bag:
                    stash[item]=int(stash.get(item,0))+int(bag[item])
                bag.clear()
                status.text="撤离成功！背包物品已保存到仓库。"
    _camera(false,delta)
    if demo:
        _demo_step()
func _camera(instant: bool=false,delta: float=.016) -> void:
    var bounds=definition.get("size",[36,30])
    var origin=definition.get("origin",[-18,-15])
    var map_center=Vector3(origin[0]+bounds[0]*.5,0,origin[1]+bounds[1]*.5)
    var overview_size=maxf(float(bounds[0])*.98,float(bounds[1])*1.35)
    if int(definition.get("wave",0)) == 5:
        overview_size *= 1.08
        map_center.z += 1.1
    var target=map_center+Vector3(float(bounds[0])*.16,0,0) if overview else player.global_position+Vector3(2.8,0,-1.0)
    target.y=.3 if overview else player.global_position.y+.3
    var desired=target+Vector3(0,31,29)
    if instant:
        camera.position=desired
        camera.size=overview_size if overview else 17
    else:
        camera.position=camera.position.lerp(desired,minf(1,delta*6))
        camera.size=lerpf(camera.size,overview_size if overview else 17.0,minf(1,delta*5))
    camera.look_at(camera.position-Vector3(0,31,29))
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_E:
                if not modal.visible:
                    var marker=level.nearest_interaction(player.global_position)
                    if marker:level.activate(marker)
            KEY_B:_inventory()
            KEY_ESCAPE:_close_modal()
            KEY_M:overview=not overview
            KEY_V:level.set_wall_cutaway(not level.cutaway_walls)
            KEY_H:
                floor_cutaway=not floor_cutaway
                status.text="上层已隐藏，可查看当前楼层" if floor_cutaway else "显示完整立体建筑"
            KEY_R:
                player.global_position=checkpoint_position
                player.velocity=Vector3.ZERO
            KEY_F9:_save()
            KEY_F10:_restore()
func _save() -> void:
    var output={"map":current_id,"progress":level.capture_progress(),"remaining":remaining,"bag":bag,"stash":stash,"position":[player.position.x,player.position.y,player.position.z],"checkpoint_position":[checkpoint_position.x,checkpoint_position.y,checkpoint_position.z]}
    var file=FileAccess.open("user://whale_level_progress.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(output))
    status.text="地图、钥匙、箱子与背包进度已保存"
func _restore() -> void:
    if not FileAccess.file_exists("user://whale_level_progress.json"):
        status.text="还没有存档"
        return
    var data=JSON.parse_string(FileAccess.get_file_as_string("user://whale_level_progress.json"))
    if not data is Dictionary:return
    state=data.progress
    remaining=data.remaining
    bag=data.bag
    stash=data.stash
    _load_level(data.map,false)
    if data.has("checkpoint_position"):
        checkpoint_position=Vector3(data.checkpoint_position[0],data.checkpoint_position[1],data.checkpoint_position[2])
    player.position=Vector3(data.position[0],data.position[1],data.position[2])
    status.text="已恢复地图与物品进度"
func _demo_step() -> void:
    tick+=1
    var frame=(tick-1)%450
    if frame==0:
        var index=int((tick-1)/450)%demo_maps.size()
        _load_level(str(demo_maps[index]))
        overview=true
        demo_phase=0
        _camera(true)
    if frame==60:
        overview=false
        player.move_to(level.get_node("Interactions/"+str(definition.get("demo_chest_id",current_id+"_chest_4"))).global_position)
        demo_phase=1
    if demo_phase==1 and player.target_reached:
        level.activate(level.get_node("Interactions/"+str(definition.get("demo_chest_id",current_id+"_chest_4"))))
        demo_phase=2
    if frame==123 and demo_phase==2:
        var id=str(definition.get("demo_chest_id",current_id+"_chest_4"))
        _take(id,"Token代币")
        _show_chest({"id":id,"title":"可搜索补给箱","loot":[]})
        if current_id=="nightmarket":_capture_chest.call_deferred()
    if frame==155:
        _close_modal()
        player.move_to(level.get_node("Interactions/"+str(definition.get("demo_key_id",current_id+"_key_0"))).global_position)
        demo_phase=3
    if demo_phase==3 and player.target_reached:
        var marker=level.get_node("Interactions/"+str(definition.get("demo_key_id",current_id+"_key_0")))
        if player.global_position.distance_to(marker.global_position)<1.8:
            level.activate(marker)
        demo_phase=4
    if frame==225 and demo_phase==4:
        player.move_to(level.get_node("Interactions/"+current_id+"_key_"+str(int(definition.get("secret_region",0)))).global_position)
        demo_phase=5
    if demo_phase==5 and player.target_reached:
        var secured=level.get_node("Interactions/"+current_id+"_key_"+str(int(definition.get("secret_region",0))))
        if player.global_position.distance_to(secured.global_position)<1.8:
            level.activate(secured)
        demo_phase=6
    if frame==393:
        overview=true
func _capture_chest() -> void:
    for i in 2:await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/箱内选择_滨海扩展_Godot实机.png")
func _screenshots() -> void:
    demo=false
    overview=true
    DirAccess.make_dir_recursive_absolute("res://world_pack26/预览")
    for d in definitions:
        var requested_map=""
        for arg in OS.get_cmdline_user_args():
            if arg.begins_with("--map-shot="):requested_map=arg.trim_prefix("--map-shot=")
        if requested_map!="" and requested_map!=str(d.id):continue
        if "--new-map-shots" in OS.get_cmdline_user_args() and not d.has("hub"):continue
        if "--vertical-map-shots" in OS.get_cmdline_user_args() and int(d.get("layout_revision",0))!=4:continue
        if "--functional-map-shots" in OS.get_cmdline_user_args() and int(d.get("layout_revision",0))!=5:continue
        if "--complex-map-shots" in OS.get_cmdline_user_args() and int(d.get("layout_revision",0))!=3:continue
        if "--coastal-map-shots" in OS.get_cmdline_user_args() and d.get("wave",0)!=5:continue
        if "--district-map-shots" in OS.get_cmdline_user_args() and d.get("wave",0)!=4:continue
        if "--city-map-shots" in OS.get_cmdline_user_args() and d.get("wave",0)!=3:continue
        _load_level(d.id)
        overview=true
        _camera(true)
        for i in 20:await get_tree().process_frame
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_复杂地图_Godot实机.png")
        print("LEVEL SHOT ",d.id)
        if int(d.get("layout_revision",0)) in [3,4,5]:
            set_process(false)
            overlay.hide()
            player.hide()
            level.set_floor_view(0,false)
            var center=Vector3(d.origin[0]+d.size[0]*.5,2,d.origin[1]+d.size[1]*.5)
            camera.position=center+Vector3(24,39,37)
            camera.size=maxf(d.size[0]*.88,d.size[1]*1.10)+10
            camera.look_at(center)
            for i in 12:await get_tree().process_frame
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_现实立体全景_Godot实机.png")
            if int(d.get("layout_revision",0)) in [4,5]:
                level.set_wall_cutaway(false)
                for i in 12:await get_tree().process_frame
                await RenderingServer.frame_post_draw
                get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_建筑全墙_Godot实机.png")
                level.set_wall_cutaway(true)
            level.set_floor_view(0,true)
            for i in 12:await get_tree().process_frame
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_一层内部_Godot实机.png")
            if int(d.get("layout_revision",0)) in [4,5]:
                for h in d.floor_heights:
                    if absf(float(h))<.1:continue
                    level.set_floor_view(float(h),true)
                    if float(h)<0:
                        var min_x=10000.0
                        var max_x=-10000.0
                        var min_z=10000.0
                        var max_z=-10000.0
                        for room in d.rooms:
                            if absf(float(room.height)-float(h))>.1:continue
                            min_x=minf(min_x,room.rect[0]);max_x=maxf(max_x,room.rect[2])
                            min_z=minf(min_z,room.rect[1]);max_z=maxf(max_z,room.rect[3])
                        var floor_focus=Vector3((min_x+max_x)*.5,float(h)+1,(min_z+max_z)*.5)
                        camera.position=floor_focus+Vector3(24,39,37)
                        camera.size=maxf((max_x-min_x)*.88,(max_z-min_z)*1.10)+8
                        camera.look_at(floor_focus)
                    elif float(h)==1.8:
                        var half_focus=Vector3(0,1.3,0) if d.id=="sports" else Vector3(0,1.3,20)
                        camera.position=half_focus+Vector3(20,32,33)
                        camera.size=64 if d.id=="sports" else 46
                        camera.look_at(half_focus)
                    else:
                        camera.position=center+Vector3(24,39,37)
                        camera.size=maxf(d.size[0]*.88,d.size[1]*1.10)+10
                        camera.look_at(center)
                    for i in 12:await get_tree().process_frame
                    await RenderingServer.frame_post_draw
                    var tag="地下层" if float(h)<0 else ("错层平台" if float(h)==1.8 else "二层内部" if float(h)==3.6 else "三层内部")
                    get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_"+tag+"_Godot实机.png")
            level.set_floor_view(0,false)
            if d.id in ["mall","hotel","library","fabrication","customs","transit","school","research","museum","civic","harbor","underground","foodhall","expo","datacenter","sports","emergency","media"]:
                camera.position=center+Vector3(18,23,30)
                camera.size=58 if int(d.get("layout_revision",0)) in [4,5] else (42 if d.id!="customs" else 50)
                camera.look_at(center)
                for i in 12:await get_tree().process_frame
                await RenderingServer.frame_post_draw
                get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_跨层连廊细节_Godot实机.png")
            if d.id=="school" and int(d.get("layout_revision",0))==4:
                var stair_focus=Vector3(-15,1.8,27)
                camera.position=stair_focus+Vector3(10,16,19)
                camera.size=24
                camera.look_at(stair_focus)
                for i in 12:await get_tree().process_frame
                await RenderingServer.frame_post_draw
                get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/school_折返楼梯_Godot实机.png")
            if int(d.get("layout_revision",0))==5:
                var themes={"foodhall":[Vector3(-27,1,-16),24.0,"厨房与后勤"],"expo":[Vector3(0,5,-4),55.0,"跨厅高桥"],"sports":[Vector3(-12,1.8,0),42.0,"阶梯看台"],"datacenter":[Vector3(-16,1,-11),38.0,"服务器阵列"],"emergency":[Vector3(-16,1,-1),38.0,"应急车库"],"media":[Vector3(-7.7,1,-7.5),26.0,"弧形演播布景"]}
                var detail=themes[d.id]
                level.set_floor_view(3.6 if d.id=="sports" else 0,true)
                if d.id=="expo":level.set_floor_view(0,false)
                camera.position=detail[0]+Vector3(15,22,25)
                camera.size=detail[1]
                camera.look_at(detail[0])
                for i in 12:await get_tree().process_frame
                await RenderingServer.frame_post_draw
                get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_"+detail[2]+"_Godot实机.png")
                level.set_floor_view(0,false)
            player.show()
            overlay.show()
            set_process(true)
            _camera(true)
        if int(d.get("layout_revision",0))==2:
            set_process(false)
            overlay.hide()
            var origin=d.origin
            var center=Vector3(origin[0]+d.size[0]*.5,1.2,origin[1]+d.size[1]*.5+2.5)
            camera.position=center+Vector3(0,36,32)
            camera.size=maxf(d.size[0]*.84,d.size[1]*1.05)+9
            camera.look_at(center)
            for i in 10:await get_tree().process_frame
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_异形轮廓_Godot实机.png")
            if d.id=="boardwalk":
                camera.position=Vector3(18,23,27)
                camera.size=35
                camera.look_at(Vector3(0,1.8,0))
                for i in 10:await get_tree().process_frame
                await RenderingServer.frame_post_draw
                get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/boardwalk_双层挑空中庭_Godot实机.png")
            if d.id=="customs":
                camera.position=Vector3(7,30,35)
                camera.size=52
                camera.look_at(Vector3(0,0,-2))
                for i in 10:await get_tree().process_frame
                await RenderingServer.frame_post_draw
                get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/customs_货架与小房间_Godot实机.png")
            player.show()
            overlay.show()
            set_process(true)
            _camera(true)
        if d.has("hub"):
            var region=int(d.get("detail_region",3 if d.id=="residence" else (7 if d.id=="harbor" else (4 if d.id=="transit" else 1))))
            var focus=d.rooms[region].center
            if d.id=="harbor" and int(d.get("layout_revision",0))<4:focus=[1.65,7.55]
            camera.position=Vector3(focus[0]+2.2,31.3,focus[1]+29)
            camera.size=15
            camera.look_at(camera.position-Vector3(0,31,29))
            status.text="细节视角："+str(d.rooms[region].name)+" · 真实三维模型与阴影"
            set_process(false)
            for i in 10:await get_tree().process_frame
            await RenderingServer.frame_post_draw
            get_viewport().get_texture().get_image().save_png("res://world_pack26/预览/"+d.id+"_细节视角_Godot实机.png")
            set_process(true)
    get_tree().quit()
