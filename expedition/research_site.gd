extends RefCounted
const Rooms=preload("res://district/container_rooms.gd")
const Interior=preload("res://district/interior_props.gd")
const Shape=preload("res://district/space_shape.gd")
const LootContainer=preload("res://district/loot_container.gd")
const OBJECTS: Array=[
	{"id":"maintenance","kind":"loot","table":"cabinet","name":"维护工具柜","pos":[-14,7],"model":"industrial_tool_chest"},
	{"id":"supply","kind":"loot","table":"cabinet","name":"应急补给箱","pos":[-5,10],"model":"field_medical_chest"},
	{"id":"server_a","kind":"loot","table":"server","name":"离线存储服务器","pos":[10,-8],"model":"server_service_cabinet"},
	{"id":"server_b","kind":"loot","table":"server","name":"计算模块机柜","pos":[3,-8],"model":"battery_module_crate"},
	{"id":"samples","kind":"loot","table":"sample","name":"原始研究样本箱","pos":[16,-4],"model":"sample_transport_case"},
	{"id":"terminal","kind":"loot","table":"terminal","name":"权限恢复终端","pos":[7,10],"model":"wall_data_safe"},
	{"id":"vault","kind":"loot","table":"safe","name":"加密蓝图库","pos":[16,8],"model":"office_armored_safe","locked":true},
	{"id":"exit_main","kind":"exit","name":"南侧维护出口","pos":[-10,10.5],"permission":false},
	{"id":"exit_lift","kind":"exit","name":"东侧权限电梯","pos":[17,4],"permission":true},
	{"id":"signal_lab","kind":"encounter","enemy":"hallucination","name":"实验区异常信号","pos":[-9,-6]},
	{"id":"signal_server","kind":"encounter","enemy":"guardian","name":"服务器异常信号","pos":[6,-3]},
	{"id":"signal_hot","kind":"encounter","enemy":"berserker","name":"散热区异常信号","pos":[-3,-9]},
	{"id":"signal_terminal","kind":"encounter","enemy":"injector","name":"档案区异常信号","pos":[4,5]}
]
const DOORS: Array=[{"id":"door_lab","pos":[-9,2],"axis":"x"},{"id":"door_server","pos":[0,-3],"axis":"z"},{"id":"door_archive","pos":[0,7],"axis":"z"},{"id":"door_control","pos":[10,6],"axis":"z"},{"id":"door_sample","pos":[14,-2],"axis":"z"}]

static func build(g) -> Dictionary:
	var rects: Array=[Rect2(-16,2,16,10),Rect2(-16,-12,16,14),Rect2(0,-10,14,12),Rect2(0,2,10,10),Rect2(10,2,8,8),Rect2(14,-6,4,8)]
	Rooms._shell_shaped(g,rects,Color("738897"),Color("a1b7c1"),Color("dcecf3"))
	var contours: Array=[]
	for rect: Rect2 in rects:contours.append(Shape.rectangle(rect))
	g.shell.set_meta("floor_contours",Shape.union(contours))
	var zones: Array=[]
	var labels: Array=["维护入口","离线实验大厅","存储机房","研究档案室","控制与撤离","样本冷藏区"]
	for i in rects.size():
		var r: Rect2=rects[i];var center:=Vector3(r.get_center().x,0,r.get_center().y)
		zones.append({"id":"research_"+str(i),"name":labels[i],"rect":r,"center":center,"polygon":Shape.rectangle(r)})
		var sign: Label3D=g._sign(labels[i],center+Vector3(0,.18,-r.size.y*.32),44,Color("3f596b"));sign.pixel_size=.008;sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	Rooms._partition(g,Vector2(-16,2),Vector2(0,2),.85,-9,2.7,Color("dde5e7"))
	Rooms._partition(g,Vector2(0,-10),Vector2(0,2),1.0,-3,2.7,Color("c1d3db"))
	Rooms._partition(g,Vector2(0,2),Vector2(0,12),1.0,7,2.7,Color("d7e0e4"))
	Rooms._partition(g,Vector2(10,2),Vector2(10,10),.85,6,2.7,Color("dde5e7"))
	Rooms._partition(g,Vector2(14,-6),Vector2(14,2),.85,-2,2.7,Color("b9cfd5"))
	for p in [Vector3(-14,0,-10),Vector3(-7,0,-10),Vector3(-14,0,-2)]:Interior.place(g,"lab_01",p)
	Interior.place(g,"lab_10",Vector3(-4,0,-11))
	Interior.place(g,"lab_07",Vector3(-2,0,-2))
	Interior.place(g,"lab_06",Vector3(16,0,0))
	for p in [Vector3(2,0,10),Vector3(2,0,3)]:g._prop("bookcase",p)
	g._prop("desk_white",Vector3(12,0,3));g._prop("plant_snake",Vector3(-15,0,3.5))
	for spec in OBJECTS:
		var p:=Vector3(spec.pos[0],0,spec.pos[1])
		if spec.kind=="loot":
			var box=LootContainer.spawn(g.world,spec.model,"exp_"+spec.id,spec.name,p,0)
			box.set_meta("expedition_id",spec.id)
		else:
			var holder:=Node3D.new();holder.name=spec.id;holder.position=p;g.world.add_child(holder);holder.set_meta("expedition_id",spec.id)
			var b=g._builder(holder)
			b.box(Vector3(1.1,.035,1.1),Vector3(0,.05,0),Color("8fc9c8") if spec.kind=="exit" else Color("d4af70"))
			var label:=Label3D.new();label.text=spec.name if spec.kind=="exit" else "? 异常信号";label.font=g._game_font();label.font_size=40;label.pixel_size=.010;label.position=Vector3(0,1.6,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("f5ead5");holder.add_child(label)
	for spec in DOORS:
		var door:=Node3D.new();door.name=spec.id;door.position=Vector3(spec.pos[0],0,spec.pos[1]);g.world.add_child(door);door.set_meta("expedition_id",spec.id)
		var span:=Vector3(2.6,.95,.12) if spec.axis=="x" else Vector3(.12,.95,2.6)
		var b=g._builder(door);b.box(span,Vector3(0,.48,0),Color("799aa8"));g._collision(door,span,Vector3(0,.48,0))
	return {"bounds":Vector2(38,28),"zones":zones,"spawn":Vector3(-10,0,8),"camera_size":39.0,"supply":Vector3(-14,0,7)}
