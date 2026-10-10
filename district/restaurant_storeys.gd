extends RefCounted
## Distinct upper dining rooms and a low-lit service basement.
const Restaurant=preload("res://district/restaurant_composition.gd")
const Lib=preload("res://district/decor_library.gd")
const Modern=preload("res://modern_materials.gd")

static func _polygons(outlines: Array) -> Array[PackedVector2Array]:
 var result: Array[PackedVector2Array]=[]
 for points in outlines:result.append(PackedVector2Array(points))
 return result

static func plan(level: int) -> Dictionary:
 if level==2:
  return {"rooms":[
   ["restaurant_dining","海风宴会厅",Vector2(1,9)],
   ["restaurant_lounge","西窗双人包间",Vector2(-11,-8)],
   ["restaurant_dining","蓝鲸家庭包间",Vector2(1,-8)],
   ["restaurant_kitchen","茶水与小食间",Vector2(14,-10)],
   ["restaurant_lounge","二层楼梯与接待",Vector2(12,-1)],
   ["restaurant_lounge","东湾会客包间",Vector2(12,8)],
   ["restaurant_lounge","海风露台",Vector2(8,19)]
  ],"polygons":_polygons([
   [Vector2(-19,-3),Vector2(4,-3),Vector2(4,3),Vector2(8,3),Vector2(8,17),Vector2(-15,17),Vector2(-19,13)],
   [Vector2(-19,-12),Vector2(-16,-15),Vector2(-6,-15),Vector2(-6,-3),Vector2(-19,-3)],
   [Vector2(-6,-15),Vector2(8,-15),Vector2(8,-6),Vector2(4,-6),Vector2(4,-3),Vector2(-6,-3)],
   [Vector2(8,-15),Vector2(20,-15),Vector2(20,-6),Vector2(8,-6)],
   [Vector2(4,-6),Vector2(20,-6),Vector2(20,3),Vector2(4,3)],
   [Vector2(8,3),Vector2(20,3),Vector2(20,11),Vector2(16,15),Vector2(8,15)],
   [Vector2(8,15),Vector2(16,15),Vector2(16,20),Vector2(12,23),Vector2(3,23),Vector2(3,17),Vector2(8,17)]
  ]),"openings":[
   [0,1,Vector2(-12,-3),3.2],[0,2,Vector2(-1,-3),3.0],
   [0,4,Vector2(4,0),2.8],[2,3,Vector2(8,-9.5),2.4],
   [2,4,Vector2(6,-6),2.4],[3,4,Vector2(15,-6),2.6],
   [4,5,Vector2(12,3),3.0],[0,5,Vector2(8,9),2.8],
   [0,6,Vector2(5.5,17),2.4],[5,6,Vector2(12.5,15),2.4]
  ],"styles":["herringbone","pale_oak","pale_oak","terrazzo","pale_oak","pale_oak","concrete"],"hidden_room":-1,"guide":Vector3(2,0,7.5),"supply":Vector3(18,0,-12.8),"bounds":Vector2(44,50),"camera_size":49.0,"spawn":Vector3(18,0,-1.4)}
 return {"rooms":[
  ["restaurant_kitchen","地下来往与整理区",Vector2(0,5)],
  ["restaurant_pantry","西侧低温食材库",Vector2(-11,-6)],
  ["restaurant_pantry","干货与陈酿库",Vector2(2,-10)],
  ["restaurant_kitchen","设备维修间",Vector2(14,-10)],
  ["restaurant_pantry","旧账册与工具档案",Vector2(12,-1)],
  ["restaurant_bar","值班管理小间",Vector2(15,8)],
  ["restaurant_pantry","食材架后的暗室",Vector2(1,-18)]
 ],"polygons":_polygons([
  [Vector2(-18,1),Vector2(-4,1),Vector2(-4,-4),Vector2(4,-4),Vector2(4,3),Vector2(11,3),Vector2(11,13),Vector2(-14,13),Vector2(-18,9)],
  [Vector2(-18,-12),Vector2(-15,-15),Vector2(-4,-15),Vector2(-4,1),Vector2(-18,1)],
  [Vector2(-4,-15),Vector2(9,-15),Vector2(9,-4),Vector2(-4,-4)],
  [Vector2(9,-15),Vector2(20,-15),Vector2(20,-6),Vector2(9,-6)],
  [Vector2(4,-4),Vector2(9,-4),Vector2(9,-6),Vector2(20,-6),Vector2(20,3),Vector2(4,3)],
  [Vector2(11,3),Vector2(20,3),Vector2(20,10),Vector2(17,13),Vector2(11,13)],
  [Vector2(-4,-22),Vector2(2,-22),Vector2(2,-19),Vector2(9,-19),Vector2(9,-15),Vector2(-4,-15)]
 ]),"openings":[
  [0,1,Vector2(-11,1),2.8],[0,2,Vector2(0,-4),2.8],
  [0,4,Vector2(4,0),2.8],[0,5,Vector2(11,8),2.8],
  [1,2,Vector2(-4,-8),2.4],[2,3,Vector2(9,-10),2.4],
  [3,4,Vector2(15,-6),2.8],[4,5,Vector2(16,3),2.4],
  [2,6,Vector2(1,-15),2.4]
 ],"styles":["concrete","terrazzo","walnut","concrete","pale_oak","pale_oak","navy_carpet"],"hidden_room":6,"guide":Vector3(3,0,7),"supply":Vector3(-12,0,9.5),"bounds":Vector2(44,48),"camera_size":47.0,"spawn":Vector3(0,0,8.5)}

static func portals(g,level: int) -> Array:
 var holder:=Node3D.new();holder.name="RestaurantStairs";holder.set_meta("room_owners",[]);g.shell.add_child(holder)
 if level==1:
  _stairs(g,holder,Vector3(21,0,-4.7))
  _stairs(g,holder,Vector3(20.7,0,-12),180)
  return [
   {"pos":Vector3(2,0,11.6),"target":"city","label":"走出海蓝餐厅","route":"entrance","spawn":Vector3(2,0,9.3)},
   {"pos":Vector3(21,0,-2.3),"target":"restaurant_2","label":"上楼 · 包间与露台 2F","route":"stairs","spawn":Vector3(21,0,-1.4)},
   {"pos":Vector3(20.7,0,-9.5),"target":"restaurant_b1","label":"下楼 · 后勤与仓储 B1","route":"stairs","spawn":Vector3(20.7,0,-9.0)}
  ]
 if level==2:
  _stairs(g,holder,Vector3(18,0,-4.5),180)
  return [{"pos":Vector3(18,0,-2.0),"target":"restaurant_1","label":"下楼 · 海蓝餐厅 1F","route":"stairs","spawn":Vector3(18,0,-1.3)}]
 _stairs(g,holder,Vector3(0,0,11))
 return [{"pos":Vector3(0,0,8.5),"target":"restaurant_1","label":"上楼 · 海蓝餐厅 1F","route":"stairs","spawn":Vector3(0,0,7.5)}]

static func _stairs(g,holder: Node3D,pos: Vector3,angle: float=0.0) -> void:
 var unit: Node3D=Restaurant._equipment(g,holder,"architecture_03",pos.x,pos.z,angle)
 unit.name="RestaurantFloorStair"
 var b=g._builder(holder)
 for side in [-1,1]:b.box(Vector3(.06,1.5,2.4),pos+Vector3(side*.80,.75,0),Color("647988"))

static func railing(g,a: Vector3,end: Vector3) -> void:
 var length: float=a.distance_to(end)
 var holder:=Node3D.new();holder.name="RestaurantTerraceRail";holder.position=(a+end)*.5;holder.rotation.y=-atan2(end.z-a.z,end.x-a.x);g.shell.add_child(holder)
 var b=g._builder(holder)
 b.box(Vector3(length,.08,.16),Vector3(0,.08,0),Color("becdd0"))
 b.box(Vector3(length,.07,.12),Vector3(0,1.05,0),Color("526c7d"))
 for n in range(ceili(length/2)+1):
  var x: float=-length/2+n*length/ceili(length/2)
  b.box(Vector3(.06,.98,.12),Vector3(x,.56,0),Color("526c7d"))
 var pane=b.box(Vector3(length,.85,.035),Vector3(0,.54,0),Color("a3c7d1"));pane.material_override=Modern.glass();pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 g._collision(holder,Vector3(length,1.1,.18),Vector3(0,.55,0))

static func _p(holder: Node3D,id: String,x: float,z: float,angle: float=0.0) -> void:
 Restaurant._place(holder,id,x,z,angle)
static func _e(g,holder: Node3D,id: String,x: float,z: float,angle: float=0.0) -> void:
 Restaurant._equipment(g,holder,id,x,z,angle)
static func _lamp(g,holder: Node3D,x: float,z: float) -> void:
 _e(g,holder,"decor_03",x,z)

static func dress(g,holder: Node3D,index: int,level: int) -> void:
 if level==2:_upper(g,holder,index)
 else:_basement(g,holder,index)

static func _upper(g,holder: Node3D,index: int) -> void:
 match index:
  0:
   for x in [-14.0,-9.0,-4.0]:
    for z in [5.0,9.5,14.0]:_p(holder,"restaurant_booth_set",x,z)
   for z in [3.0,11.7]:_p(holder,"sculpted_planter",-17,z)
   for z in [6.5,13.0]:_lamp(g,holder,-6.3,z)
   _p(holder,"restaurant_service_cart",-4.3,1.8)
   _e(g,holder,"lounge_06",-16.5,.1)
   _e(g,holder,"lounge_05",-11,.1)
   _p(holder,"restaurant_menu_stand",-8,.2)
  1:
   Lib.rug(holder,Vector3(-12,0,-9),Vector2(8,4.2),Color("85999f"))
   for x in [-15.0,-10.0]:_p(holder,"restaurant_bistro_set",x,-10)
   _p(holder,"restaurant_booth_set",-16.5,-6,90)
   _p(holder,"restaurant_service_cart",-8,-13.4)
   _p(holder,"floor_lamp",-17,-10)
   _p(holder,"hydrangea_pot",-7.2,-4.3)
  2:
   for x in [-2.5,4.7]:_p(holder,"restaurant_booth_set",x,-11.5)
   _p(holder,"restaurant_bistro_set",1,-6)
   _p(holder,"restaurant_service_cart",-4.8,-11.5)
   _p(holder,"school_open_bookshelf",1,-14.1)
   _p(holder,"sculpted_planter",6.6,-13)
   _lamp(g,holder,-4.5,-5)
  3:
   _p(holder,"restaurant_coffee_station",11,-13.7)
   _e(g,holder,"restaurant_06",18,-13.7)
   _p(holder,"restaurant_pantry_shelf",15,-13.7)
   _p(holder,"restaurant_kitchen_island",11,-9)
   _p(holder,"restaurant_dish_station",18,-9)
   _p(holder,"restaurant_service_cart",9.2,-7.5)
   _lamp(g,holder,19,-7.2)
  4:
   _p(holder,"curved_bench",9.0,-4.5)
   _p(holder,"notice_easel",5.2,1.6)
   _p(holder,"restaurant_coffee_station",17.4,1.8)
   _p(holder,"sculpted_planter",19,1.7)
   _p(holder,"floor_lamp",6.4,-4.4)
  5:
   Lib.rug(holder,Vector3(14,0,9),Vector2(8,6),Color("879d9e"))
   _p(holder,"restaurant_booth_set",15,6)
   _p(holder,"restaurant_bistro_set",15,10.5)
   _p(holder,"lounge_chair",10,5.2,20)
   _p(holder,"lounge_chair",10,12.5,-20)
   _p(holder,"floor_lamp",18.5,8.4)
   _p(holder,"hydrangea_pot",18.5,6)
   _p(holder,"restaurant_service_cart",10.2,14)
  6:
   _p(holder,"curved_bench",6,21.8)
   _p(holder,"restaurant_bistro_set",11.3,19.8)
   _p(holder,"sculpted_planter",14.8,17.4)
   _p(holder,"hydrangea_pot",4.1,18.8)
   _p(holder,"hydrangea_pot",9.5,22)
   _lamp(g,holder,14.5,19.5)

static func _basement(g,holder: Node3D,index: int) -> void:
 match index:
  0:
   for x in [-14.0,-9.0]:_e(g,holder,"logistics_01",x,3)
   _e(g,holder,"logistics_08",-15,7)
   _e(g,holder,"logistics_04",-7,4.5)
   _e(g,holder,"logistics_02",-8,10)
   _p(holder,"curved_bench",5,11.5)
   _p(holder,"notice_easel",7.5,5)
   for x in [-13.0,7.5]:_lamp(g,holder,x,9.5)
  1:
   for x in [-14.0,-10.0,-6.0]:_e(g,holder,"restaurant_06",x,-13.5)
   for z in [-9.5,-4.5]:_p(holder,"restaurant_pantry_shelf",-16.5,z,90)
   for z in [-10.5,-3.5]:_e(g,holder,"logistics_01",-6,z,90)
   _e(g,holder,"logistics_04",-14,-.3)
   _e(g,holder,"logistics_02",-13.5,-6)
   _p(holder,"woven_crate",-12,-6)
   _lamp(g,holder,-16,-1.5)
  2:
   # The middle shelf is the actual door, so its neighbouring racks match it.
   for x in [-2.6,5.0]:_p(holder,"restaurant_pantry_shelf",x,-14.65)
   for z in [-12.0,-6.0]:_p(holder,"restaurant_pantry_shelf",7.5,z,90)
   _e(g,holder,"logistics_01",-2.5,-10.5,90)
   _e(g,holder,"logistics_02",4.3,-7)
   _p(holder,"woven_crate",5.5,-7)
   _p(holder,"restaurant_service_cart",-2.3,-5.5)
   _lamp(g,holder,6.5,-13.6)
  3:
   _e(g,holder,"logistics_08",11,-13.5)
   _e(g,holder,"logistics_11",18,-13.5)
   _e(g,holder,"utility_09",19,-10)
   _e(g,holder,"logistics_01",12,-7.2)
   _e(g,holder,"logistics_12",17.5,-7.5)
   _lamp(g,holder,10.3,-7)
  4:
   for x in [10.5,14,18.0]:_p(holder,"school_open_bookshelf",x,-4.8)
   _e(g,holder,"lounge_09",7,-1)
   _e(g,holder,"lounge_01",7,1)
   _e(g,holder,"logistics_05",18,1.7)
   _p(holder,"floor_lamp",5.5,1.8)
   _lamp(g,holder,19,-1)
  5:
   _e(g,holder,"lounge_03",18,5)
   _p(holder,"restaurant_bistro_set",15,10)
   _p(holder,"restaurant_coffee_station",13,4.3)
   _p(holder,"school_open_bookshelf",18,8)
   _p(holder,"floor_lamp",12.2,11.7)
   _p(holder,"hydrangea_pot",18.2,10.3)
  6:
   for z in [-20.5,-17.5]:_p(holder,"school_open_bookshelf",-2.8,z,90)
   _e(g,holder,"lounge_09",5.5,-18)
   _e(g,holder,"lounge_01",5.5,-16.7)
   _e(g,holder,"logistics_05",7.5,-16.5)
   _p(holder,"woven_crate",-.5,-21)
   _p(holder,"floor_lamp",7.7,-18.1)
   var light:=OmniLight3D.new();light.position=Vector3(.5,1.2,-20.5);light.omni_range=2.6;light.light_energy=.24;light.set_meta("fixture_weight",.30);holder.add_child(light)

static func attach_loot(g) -> void:
 var basement: bool=g.location_id=="restaurant_b1"
 var chest=g.loot.CHEST.instantiate()
 chest.container_id="restaurant_hidden_cache" if basement else "restaurant_tea_supply"
 chest.display_name="旧餐厅暗室 · 收藏箱" if basement else "海蓝餐厅 · 茶点补给"
 chest.note="食材架后面藏着旧餐厅的账册和几件收藏。\n物品取走后不会刷新。" if basement else "宴会开始前备好的茶点，给来访的朋友留一份。"
 chest.position=Vector3(.5,0,-20.5) if basement else Vector3(18,0,-12.8)
 if basement:g.shell.get_node("RestaurantSecretRoom").add_child(chest)
 else:g.world.add_child(chest)
 g.loot.chests.append(chest)
