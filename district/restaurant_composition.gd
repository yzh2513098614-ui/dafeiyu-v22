extends RefCounted
## Authored restaurant: shared partitions, customer aisles and grouped workstations.
const Packed=preload("res://district/packed_floor.gd")
const Shape=preload("res://district/space_shape.gd")
const Walls=preload("res://district/themed_walls.gd")
const Lib=preload("res://district/decor_library.gd")
const Interior=preload("res://district/interior_props.gd")
const Modern=preload("res://modern_materials.gd")
const WallSurfaces=preload("res://district/wall_surfaces.gd")
const HiddenDoor=preload("res://district/restaurant_hidden_door.gd")
const Finish=preload("res://district/restaurant_finish.gd")
const ROOMS=[
 ["restaurant_dining","海蓝餐厅 · 窗边用餐",Vector2(1,6)],
 ["restaurant_patisserie","烘焙柜台 · 取餐与点单",Vector2(-9,-7)],
 ["restaurant_bar","咖啡吧 · 午后小坐",Vector2(-.4,-4)],
 ["restaurant_kitchen","明档后厨 · 烹饪与备餐",Vector2(7.3,-7)],
 ["restaurant_pantry","食材库 · 冷藏与收纳",Vector2(13,0)],
 ["restaurant_lounge","窗边小餐室",Vector2(10,7.5)],
 ["restaurant_lounge","东侧楼梯厅",Vector2(20,0)],
 ["restaurant_kitchen","卸货与地下入口",Vector2(20,-10)]
]
const OPENINGS=[
 [0,1,Vector2(-9.5,-2),3.2],
 [0,2,Vector2(-.4,1),3.2],
 [0,3,Vector2(5.5,-2),2.6],
 [1,2,Vector2(-4,-5.7),2.4],
 [2,3,Vector2(3,-6.5),2.6],
 [3,4,Vector2(13,-5),2.4],
 [0,5,Vector2(8,6.5),2.8],
 [0,-1,Vector2(2,13),3.4],
 [4,6,Vector2(16,0),2.8],
 [5,6,Vector2(16,4.5),2.2],
 [6,7,Vector2(20,-7),2.6],
 [3,7,Vector2(16,-10.5),2.8]
]

static func polygons() -> Array[PackedVector2Array]:
 var outlines: Array=[
  [Vector2(-16,-2),Vector2(-4,-2),Vector2(-4,1),Vector2(3,1),Vector2(3,-2),Vector2(8,-2),Vector2(8,13),Vector2(-12,13),Vector2(-16,9)],
  [Vector2(-16,-11),Vector2(-13,-14),Vector2(-4,-14),Vector2(-4,-2),Vector2(-16,-2)],
  [Vector2(-4,-10),Vector2(3,-10),Vector2(3,1),Vector2(-4,1)],
  [Vector2(3,-14),Vector2(16,-14),Vector2(16,-5),Vector2(10,-5),Vector2(10,-2),Vector2(3,-2)],
  [Vector2(10,-5),Vector2(16,-5),Vector2(16,3),Vector2(8,3),Vector2(8,-2),Vector2(10,-2)],
  [Vector2(8,3),Vector2(16,3),Vector2(16,10),Vector2(13,13),Vector2(8,13)],
  [Vector2(16,-7),Vector2(24,-7),Vector2(24,3),Vector2(21,6),Vector2(16,6)],
  [Vector2(16,-14),Vector2(24,-14),Vector2(24,-7),Vector2(16,-7)]
 ]
 var result: Array[PackedVector2Array]=[]
 for points in outlines:result.append(PackedVector2Array(points))
 return result

static func build(g,data: Dictionary) -> Dictionary:
 var level: int=int(data.floor)
 var plan: Dictionary={"rooms":ROOMS,"polygons":polygons(),"openings":OPENINGS,"styles":["herringbone","pale_oak","pale_oak","terrazzo","terrazzo","pale_oak","pale_oak","terrazzo"],"hidden_room":-1,"guide":Vector3(-6.8,0,-3.1),"supply":Vector3(11.5,0,.9),"bounds":Vector2(52,32),"camera_size":48.0,"spawn":Vector3(2,0,9.3)}
 if level!=1:plan=load("res://district/restaurant_storeys.gd").plan(level)
 var rooms: Array=plan.rooms
 var polys: Array[PackedVector2Array]=plan.polygons
 var edges: Array=Packed.segments(polys)
 var zones: Array=[]
 for n in rooms.size():
  var anchor: Vector2=rooms[n][2]
  zones.append({"id":g.location_id+"_room"+str(n+1),"kind":rooms[n][0],"name":rooms[n][1],"rect":Packed._rect(polys[n]),"polygon":polys[n],"shape":"restaurant_nested", "center":Vector3(anchor.x,0,anchor.y),"doors":[],"door_clear":[],"paths":[],"external_edges":[]})
 var connections: Array=[]
 for opening in plan.openings:
  for edge in edges:
   if not int(opening[0]) in edge.owners:continue
   if int(opening[1])>=0 and not int(opening[1]) in edge.owners:continue
   if int(opening[1])<0 and edge.owners.size()!=1:continue
   if Geometry2D.get_closest_point_to_segment(opening[2],edge.a,edge.end).distance_to(opening[2])>.01:continue
   edge.door=true;edge.point=opening[2];edge.width=float(opening[3])
   connections.append(edge)
   for owner in edge.owners:
    zones[owner].doors.append(Vector3(edge.point.x,0,edge.point.y))
    var margin: float=maxf(1.4,edge.width*.5+.25)
    zones[owner].door_clear.append(Rect2(edge.point-Vector2.ONE*margin,Vector2.ONE*margin*2))
   edge.hidden=int(opening[1])==int(plan.hidden_room) and int(plan.hidden_room)>=0
   if not edge.hidden:_door(g,edge)
   break
 for edge in edges:
  var a:=Vector3(edge.a.x,0,edge.a.y);var end:=Vector3(edge.end.x,0,edge.end.y)
  var kind: String=str(zones[edge.owners[0]].kind)
  if edge.door:
   var point:=Vector3(edge.point.x,0,edge.point.y);var direction: Vector3=(end-a).normalized()
   _storey_wall(g,kind,a,point-direction*edge.width/2,edge.owners,level)
   _storey_wall(g,kind,point+direction*edge.width/2,end,edge.owners,level)
  else:_storey_wall(g,kind,a,end,edge.owners,level)
 var contours: Array[PackedVector2Array]=Shape.union(polys)
 g.shell.set_meta("floor_contours",contours);g.shell.set_meta("room_connections",connections)
 g.shell.set_meta("floor_layout","interlocking_rooms")
 g.shell.set_meta("layout_revision","restaurant_expansion_v2_"+str(level))
 g.shell.set_meta("partition_family","餐厅套间 · 共享墙体与直接互通")
 g.shell.set_meta("guide_anchor",plan.guide)
 g.shell.set_meta("supply_anchor",plan.supply)
 for contour in contours:Shape.slab(g,contour)
 var secret_room: Node3D
 for n in rooms.size():
  var zone: Dictionary=zones[n]
  zone.door=zone.doors[0]
  zone.paths=Shape.access_routes(zone.polygon,zone.center,zone.doors)
  var style: String=str(plan.styles[n])
  var floor: MeshInstance3D=Shape.floor_mesh(polys[n],.020,style)
  if style in ["herringbone","pale_oak","oak","walnut"]:floor.material_override=Finish.floor_material(style)
  floor.name="RoomFloor_"+str(n);floor.set_meta("room_polygon",polys[n]);g.shell.add_child(floor)
  var holder:=Node3D.new();holder.name="RestaurantGroup_"+str(n);holder.set_meta("room_owners",[n]);g.shell.add_child(holder)
  holder.set_meta("decor_polygon",polys[n])
  if level==1:_dress(g,holder,n)
  else:load("res://district/restaurant_storeys.gd").dress(g,holder,n,level)
  var sign=g._sign(zone.name,zone.center+Vector3(0,.42,0),28,Color("d7e4de"))
  sign.pixel_size=.018;sign.outline_size=4;sign.outline_modulate=Color("324b59")
  sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.add_to_group("floor_room_labels")
  if n==int(plan.hidden_room):
   secret_room=holder;holder.name="RestaurantSecretRoom";sign.reparent(holder,true)
 if int(plan.hidden_room)>=0:
  for edge in connections:
   if edge.hidden:
    var gate=HiddenDoor.new();gate.name="RestaurantHiddenDoor";gate.position=Vector3(edge.point.x,0,edge.point.y);g.world.add_child(gate)
    gate.configure(g,secret_room,edge.width)
 var portals: Array=load("res://district/restaurant_storeys.gd").portals(g,level)
 return {"bounds":plan.bounds,"spawn":plan.spawn,"zones":zones,"camera_size":plan.camera_size,"exit_anchor":Vector3(2,0,11.6),"supply":plan.supply,"portals":portals}

static func _storey_wall(g,kind: String,a: Vector3,end: Vector3,owners: Array,level: int) -> void:
 if level==1:_wall(g,kind,a,end,owners);return
 if level==0:Walls.run(g,kind,a,end);return
 var terrace: bool=owners.size()==1 and owners[0]==6
 var window: bool=owners.size()==1 and is_equal_approx(a.x,end.x) and (is_equal_approx(a.x,-19) or is_equal_approx(a.x,20)) and kind in ["restaurant_dining","restaurant_lounge"]
 if terrace:load("res://district/restaurant_storeys.gd").railing(g,a,end)
 elif window:_window(g,a,end)
 else:Walls.run(g,kind,a,end)

static func _place(holder: Node3D,id: String,x: float,z: float,angle: float=0.0) -> Node3D:
 var object: Node3D=Lib.instance(id)
 object.name=id+"_"+str(holder.get_child_count());object.position=Vector3(x,0,z);object.rotation_degrees.y=angle
 holder.add_child(object)
 if id=="restaurant_bistro_set":_table_detail(object,x,z)
 return object

static func _table_detail(object: Node3D,x: float,z: float) -> void:
 var variant:=absi(roundi(x*3+z*2))%3
 if variant==2:return
 var menu:=MeshInstance3D.new();menu.name="TableMenu" if variant==0 else "FoldedNapkin"
 var shape:=BoxMesh.new();shape.size=Vector3(.19,.006,.13);menu.mesh=shape
 menu.position=Vector3(.24,.826,.17);menu.rotation_degrees.y=12.0 if variant==0 else -18.0
 menu.material_override=Modern.surface(Color("d8d4c6") if variant==0 else Color("9eb9ba"),false,variant==1)
 menu.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;object.add_child(menu)

static func _equipment(g,holder: Node3D,id: String,x: float,z: float,angle: float=0.0) -> Node3D:
 var object: Node3D=Interior.place(g,id,Vector3(x,0,z),angle)
 object.set_meta("restaurant_group",str(holder.name))
 object.set_meta("room_owners",holder.get_meta("room_owners"))
 return object

static func _dress(g,holder: Node3D,index: int) -> void:
 match index:
  0:
   # Window booths, a central table group and a separate staff service corner.
   for z in [.2,4.1,8.0]:_place(holder,"restaurant_booth_set",-13.5,z,90)
   for z in [2.2,6.3,10.0]:_place(holder,"restaurant_bistro_set",-8.5,z)
   for z in [5.8,9.7]:_place(holder,"restaurant_booth_set",-4.3,z)
   for z in [3.3,7.3]:_place(holder,"sculpted_planter",-10.9,z)
   _place(holder,"hydrangea_pot",-13,11.3)
   _place(holder,"floor_lamp",-11.0,11.3,180)
   for z in [2.2,8.0]:_equipment(g,holder,"decor_03",-6.2,z)
   _place(holder,"restaurant_service_cart",-4.5,2.2)
   _place(holder,"restaurant_herb_rack",-3.0,3.3)
   _place(holder,"restaurant_menu_stand",4.5,10.8,-20)
   _place(holder,"coat_stand",6.4,11.8)
   _place(holder,"hydrangea_pot",6.4,9.8)
   Lib.rug(holder,Vector3(2,0,10.7),Vector2(3.5,2.6),Color("708fa0"))
  1:
   # Continuous display counter; the machines and ingredients stay behind it.
   for x in [-12.2,-9.7,-7.2]:_place(holder,"restaurant_pastry_display",x,-5)
   _equipment(g,holder,"restaurant_04",-5.3,-3.5)
   _place(holder,"restaurant_menu_stand",-13.8,-3.8)
   _place(holder,"restaurant_pantry_shelf",-12.2,-12.5)
   _place(holder,"restaurant_coffee_station",-8.7,-12.5)
   _place(holder,"retro_fridge",-5.5,-12.5)
   for x in [-12,-8.5]:_place(holder,"restaurant_pastry_table",x,-9)
   _place(holder,"restaurant_service_cart",-6.1,-8.5)
   _place(holder,"woven_crate",-11,-11.2)
   _place(holder,"hydrangea_pot",-14.8,-7.5)
   for x in [-12,-6]:
    var sconce: Node3D=_equipment(g,holder,"decor_05",x,-13.8);sconce.position.y=.45
  2:
   _place(holder,"restaurant_coffee_station",-.5,-8.8)
   _equipment(g,holder,"restaurant_05",-.5,-6.7)
   _place(holder,"restaurant_bistro_set",-2.6,-1,90)
   _place(holder,"floor_lamp",-2.6,.4,180)
   _place(holder,"sculpted_planter",1.7,-1.2)
   _place(holder,"restaurant_pastry_table",-2.6,-8.6)
  3:
   # Cooking line -> prep islands -> service opening; washing stays at the end.
   for x in [4.3,5.7]:_equipment(g,holder,"restaurant_01",x,-12.8)
   _equipment(g,holder,"restaurant_03",7.2,-12.8)
   _place(holder,"restaurant_pantry_shelf",9,-12.7)
   _place(holder,"restaurant_dish_station",11.2,-12.8)
   _equipment(g,holder,"restaurant_10",12.8,-12.8)
   _equipment(g,holder,"restaurant_09",14.3,-12.8)
   for x in [6.3,9,11.7]:_place(holder,"restaurant_kitchen_island",x,-9.4)
   _place(holder,"restaurant_kitchen_island",14.9,-9,90)
   _place(holder,"restaurant_service_cart",8,-4.0)
   _place(holder,"restaurant_herb_rack",4.2,-4.2,90)
   _place(holder,"waste_bin",15,-6.4)
   for x in [6.0,13.5]:
    var sconce: Node3D=_equipment(g,holder,"decor_05",x,-13.8);sconce.position.y=.45
  4:
   # A small room has a dense perimeter, with a clear route from the kitchen.
   _equipment(g,holder,"restaurant_06",11.1,-3.6)
   _place(holder,"retro_fridge",15,-3.6)
   for z in [-1.5,1.0]:_place(holder,"restaurant_pantry_shelf",15.2,z,90)
   for z in [-.5,1.5]:_place(holder,"restaurant_pantry_shelf",9,z,90)
   _place(holder,"restaurant_service_cart",11.1,-.5)
   _place(holder,"woven_crate",10.2,1.8)
   _place(holder,"woven_crate",12.6,1.8)
  5:
   Lib.rug(holder,Vector3(12.2,0,7.7),Vector2(5.5,5.8),Color("85999f"))
   for z in [5,10.3]:_place(holder,"restaurant_booth_set",12,z)
   _place(holder,"restaurant_bistro_set",12,7.5)
   _place(holder,"lounge_chair",14.5,7.4,-20)
   _place(holder,"floor_lamp",15,8.7)
   _place(holder,"hydrangea_pot",15,5)
   _place(holder,"restaurant_menu_stand",9.4,11.8)
  6:
   _place(holder,"curved_bench",18.4,3.8)
   _place(holder,"sculpted_planter",22.3,2)
   _place(holder,"floor_lamp",17.3,2.0)
   _place(holder,"notice_easel",17.7,-4.7)
  7:
   _equipment(g,holder,"logistics_01",17.8,-13.0)
   _equipment(g,holder,"logistics_02",22.5,-13.0)
   _equipment(g,holder,"logistics_04",17.2,-8.2)
   _place(holder,"woven_crate",22.6,-8.1)
   _place(holder,"floor_lamp",23,-12)

static func _wall(g,kind: String,a: Vector3,end: Vector3,owners: Array) -> void:
 var before: int=g.shell.get_child_count()
 # Real glazing faces the grouped window seats, rather than ornamental wall art.
 var window: bool=owners.size()==1 and ((is_equal_approx(a.x,-16) and is_equal_approx(end.x,-16) and kind=="restaurant_dining") or (is_equal_approx(a.x,16) and is_equal_approx(end.x,16) and kind=="restaurant_lounge"))
 if window:_window(g,a,end)
 else:Walls.run(g,kind,a,end)
 for node in g.shell.get_children().slice(before):node.set_meta("room_owners",owners)

static func _window(g,a: Vector3,end: Vector3) -> void:
 var length: float=a.distance_to(end)
 var holder:=Node3D.new();holder.name="RestaurantWindow";holder.position=(a+end)*.5
 holder.rotation.y=-atan2(end.z-a.z,end.x-a.x);g.shell.add_child(holder)
 holder.set_meta("wall_start",a);holder.set_meta("wall_end",end)
 holder.set_meta("restaurant_window",true)
 var b=g._builder(holder)
 b.box(Vector3(length,.40,.20),Vector3(0,.20,0),Color("d4d8d3")).material_override=WallSurfaces.material("oak_vertical",(end-a).normalized())
 b.box(Vector3(length,.07,.30),Vector3(0,.42,0),Color("e2dbcb"))
 # A deeper inner sill and a narrow lower reveal give the glazing real depth.
 b.box(Vector3(length,.045,.40),Vector3(0,.405,.045),Color("d5cebd"))
 b.box(Vector3(length,.025,.035),Vector3(0,.375,.18),Color("879897"))
 b.box(Vector3(length,.07,.14),Vector3(0,1.28,0),Color("455665"))
 var count: int=ceili(length/2.8);var span: float=length/count
 for n in range(count+1):b.box(Vector3(.06,.86,.14),Vector3(-length/2+n*span,.85,0),Color("455665"))
 var pane=b.box(Vector3(length,.77,.035),Vector3(0,.85,0),Color("a3c7d1"))
 pane.material_override=Modern.glass();pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 g._collision(holder,Vector3(length,1.28,.20),Vector3(0,.64,0))

static func _door(g,edge: Dictionary) -> void:
 var holder:=Node3D.new();holder.name="RestaurantDoor";holder.position=Vector3(edge.point.x,0,edge.point.y)
 holder.rotation.y=-atan2(edge.end.y-edge.a.y,edge.end.x-edge.a.x);holder.set_meta("room_owners",edge.owners);g.shell.add_child(holder)
 var b=g._builder(holder);var width: float=edge.width
 for side in [-1,1]:b.box(Vector3(.08,2.14,.12),Vector3(side*(width/2+.04),1.07,0),Color("455665"))
 b.box(Vector3(width+.16,.08,.12),Vector3(0,2.14,0),Color("455665"))
 b.box(Vector3(width-.08,.008,.36),Vector3(0,.03,0),Color("91b0b8"))
 var gate=preload("res://district/interactive_door.gd").new();gate.name="InteractiveDoor";holder.add_child(gate)
 gate.configure(g,width,Packed._key(edge.a,edge.end)+":"+str(edge.point),"餐厅门")
