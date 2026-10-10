extends RefCounted
## Room programs and furniture for the shared-wall, interlocking floor builder.
const SpecialRooms=preload("res://district/special_rooms.gd")
const RoomDetails=preload("res://district/room_details.gd")
const ThemedWalls=preload("res://district/themed_walls.gd")
const Modern=preload("res://modern_materials.gd")
const Shape=preload("res://district/space_shape.gd")
const PackedFloor=preload("res://district/packed_floor.gd")
const Restaurant=preload("res://district/restaurant_composition.gd")
const WALL=Color("cdd5da")
const EDGE=Color("455665")
const DOOR_WIDTH=2.4

static func build(g,data: Dictionary) -> Dictionary:
 if str(data.get("building",""))=="restaurant":return Restaurant.build(g,data)
 return PackedFloor.build(g,data,_plan(str(data.get("building","apartment")).to_lower(),maxi(1,int(data.get("floor",1)))))

static func _plain_run(g,start: Vector3,end: Vector3,height: float) -> void:
 var length: float=start.distance_to(end)
 if length<.01:return
 var holder:=Node3D.new();holder.name="ContourWall";holder.position=(start+end)*.5
 holder.rotation.y=-atan2(end.z-start.z,end.x-start.x);g.shell.add_child(holder)
 holder.set_meta("wall_start",start);holder.set_meta("wall_end",end)
 var b=g._builder(holder)
 b.box(Vector3(length,height,.20),Vector3(0,height/2,0),WALL)
 b.box(Vector3(length+.015,.075,.25),Vector3(0,height+.025,0),EDGE)
 b.box(Vector3(length,.085,.24),Vector3(0,.065,0),Color("8d9eaa"))
 g._collision(holder,Vector3(length,height,.20),Vector3(0,height/2,0))

static func _props(g,center: Vector3,specs: Array) -> void:
 for spec in specs:
  var id: String=str(spec[0])
  if not g.catalog.has(id):continue
  g._prop(id,center+spec[1],float(spec[2]) if spec.size()>2 else 0.0)

static func _fit_furniture(g,parent: Node,first: int,room: Rect2,door: Vector3,south: bool,polygon: PackedVector2Array,access: Array=[]) -> void:
 var midpoint: Vector2=room.get_center();var center:=Vector3(midpoint.x,0,midpoint.y)
 var sx: float=clampf((room.size.x-2.0)/11.0,.45,1.9)
 var sz: float=clampf((room.size.y-2.0)/10.0,.40,1.4)
 var placed: Array[Rect2]=[]
 var inside: Rect2=room.grow(-.32)
 var clear_door:=Rect2(Vector2(door.x-1.4,door.z-.25 if south else door.z-2.2),Vector2(2.8,2.45))
 var nodes: Array=parent.get_children().slice(first)
 for node in nodes:
  # Hanging cupboards need full-height support; these floors use 1.1 m cutaway walls.
  if str(node.module_id)=="upper_cabinet":g.items.erase(node);node.free();continue
  var local: Vector3=node.position-center
  local.x*=sx;local.z*=sz
  if south:local=local.rotated(Vector3.UP,PI);node.rotation.y+=PI
  node.position=center+local
  if node.position.y>.3 and node.metadata.get("layer","")!="surface":
   var visual: Rect2=_visual_footprint(node)
   if visual.has_area() and not Shape.contains_rect(polygon,visual,-.12):
    g.items.erase(node);node.free();continue
  var footprint: Rect2=_footprint(node)
  if footprint.has_area():
   node.position.x+=maxf(0,inside.position.x-footprint.position.x)-maxf(0,footprint.end.x-inside.end.x)
   node.position.z+=maxf(0,inside.position.y-footprint.position.y)-maxf(0,footprint.end.y-inside.end.y)
   footprint=_footprint(node)
   if node.position.y<.3:
    var anchor: Vector3=node.position
    var fitted:=false
    for candidate in Shape.fitted_candidates(anchor,inside):
     node.position=candidate;footprint=_footprint(node)
     var blocked: bool=not inside.encloses(footprint) or not Shape.contains_rect(polygon,footprint) or footprint.intersects(clear_door)
     if not access.is_empty():
      blocked=not inside.encloses(footprint) or not Shape.contains_rect(polygon,footprint,.65)
      for aisle: Rect2 in access:
       if footprint.intersects(aisle):blocked=true;break
     for occupied in placed:
      if footprint.grow(.85).intersects(occupied):blocked=true;break
     if not blocked:fitted=true;break
    if not fitted:g.items.erase(node);node.free();continue
    placed.append(footprint)
   elif node.metadata.get("layer","")!="surface" and not Shape.contains_rect(polygon,footprint,0):
    g.items.erase(node);node.free();continue
  _record_position(node)
 # Keep tabletop cutouts with a surviving supporting piece of furniture.
 var support_ids: Array=["bed_navy","bed_sage","desk_oak","desk_white","nightstand","side_table","dining_round","dining_white","coffee_table","cubby","tv_cabinet","sink_counter","stove_counter","counter_blank","bar_cabinet","sofa_cream","loveseat_navy","armchair_sage"]
 for node in nodes:
  if not is_instance_valid(node) or node.position.y<.3 or node.metadata.get("layer","")!="surface":continue
  var supported:=false
  for base in nodes:
   if not is_instance_valid(base) or not str(base.module_id) in support_ids:continue
   if _footprint(base).grow(.30).has_point(Vector2(node.position.x,node.position.z)):supported=true;break
  if not supported:g.items.erase(node);node.free()

static func _visual_footprint(node: Node3D) -> Rect2:
 var pending: Array[Node]=[node];var bounds:=AABB();var found:=false
 while not pending.is_empty():
  var child: Node=pending.pop_back()
  if child is MeshInstance3D and child.mesh!=null:
   var world_bounds: AABB=child.global_transform*child.get_aabb()
   bounds=world_bounds if not found else bounds.merge(world_bounds);found=true
  for nested in child.get_children():pending.append(nested)
 return Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z)) if found else Rect2()

static func _footprint(node) -> Rect2:
 var width: float=float(node.collision_width);var depth: float=float(node.collision_depth)
 var local: Rect2
 if depth>0:local=Rect2(-width/2,-depth,width,depth)
 elif node.metadata.get("solid",false):
  var size: Array=node.metadata.get("footprint",[32,32])
  width=maxf(.30,float(size[0])/96.0)
  depth=maxf(.30,float(size[1])/96.0) if str(node.module_id).begins_with("district_") else width
  local=Rect2(-width/2,-depth/2,width,depth)
 else:return Rect2()
 var result:=Rect2(Vector2(node.position.x,node.position.z),Vector2.ZERO)
 for corner in [local.position,local.position+Vector2(local.size.x,0),local.end,local.position+Vector2(0,local.size.y)]:
  var point: Vector3=Vector3(corner.x,0,corner.y).rotated(Vector3.UP,node.rotation.y)+node.position
  result=result.expand(Vector2(point.x,point.z))
 return result

static func _record_position(node) -> void:
 if not node.has_meta("placement"):return
 var entry: Dictionary=node.get_meta("placement").duplicate(true)
 entry["pos"]=[node.position.x,node.position.y,node.position.z];entry["angle"]=node.rotation_degrees.y
 node.set_meta("placement",entry)

static func _fit_details(parent: Node,first: int,room: Rect2,south: bool,polygon: PackedVector2Array) -> void:
 var midpoint: Vector2=room.get_center();var center:=Vector3(midpoint.x,0,midpoint.y)
 var sx: float=clampf((room.size.x-2.0)/11.0,.45,1.9)
 var sz: float=clampf((room.size.y-2.0)/10.0,.40,1.4)
 for node in parent.get_children().slice(first):
  var local: Vector3=node.position-center;local.x*=sx;local.z*=sz
  node.scale.x*=sx;node.scale.z*=sz
  if south:local=local.rotated(Vector3.UP,PI);node.rotation.y+=PI
  node.position=center+local
  if node is MeshInstance3D:
   var bounds: AABB=node.get_aabb()
   var rect:=Rect2(Vector2(node.position.x-bounds.size.x*node.scale.x/2,node.position.z-bounds.size.z*node.scale.z/2),Vector2(bounds.size.x*node.scale.x,bounds.size.z*node.scale.z))
   if not Shape.contains_rect(polygon,rect,0):node.free()

static func _rug(b,center: Vector3,size: Vector2,tint: Color) -> void:
 b.box(Vector3(size.x,.012,size.y),center+Vector3(0,.035,0),tint)
 for side in [-1,1]:b.box(Vector3(size.x-.08,.004,.025),center+Vector3(0,.043,side*(size.y/2-.04)),tint.lightened(.28))

static func _room(kind: String,name: String,x: float,z: float,width: float,depth: float,shift: float=0) -> Dictionary:
 return {"kind":kind,"name":name,"rect":Rect2(x,z,width,depth),"shift":shift}

static func _plan(building: String,floor_no: int) -> Array:
 var special: Array=SpecialRooms.plan(building,floor_no)
 if not special.is_empty():return special
 if building.contains("gallery"):
  return [_room("exhibit","白帆主展厅",-23,-17,20,12,.12),_room("craft","海蓝绘画工作坊",1,-15,22,11,-.20),_room("reading","唱片与资料室",-23,6,10,10,.12),_room("exhibit","旅人小作品展",-10,8,9,8,-.10),_room("tea","艺廊窗边茶厅",2,4,13,12,.18),_room("storage","材料小库房",18,9,5,7,-.10)]
 if building.contains("community"):
  if floor_no==1:
   return [_room("meeting","社区活动大厅",-23,-17,19,13,.15),_room("exhibit","鲸落大展厅",0,-16,23,11,-.22),_room("cafe","潮汐咖啡",-23,4,12,12,-.12),_room("books","漂流书店",-8.4,7,10,9,.18),_room("reception","街区接待",4.2,5,8,10,-.15),_room("lounge","安静休息间",14.8,9,8.2,8,.12)]
  return [_room("work","创作工作间",-23,-15,14,10,-.15),_room("meeting","会议讨论厅",-6,-17,14,12,.18),_room("exhibit","作品展示间",11,-14,12,9,-.12),_room("craft","手作工坊",-23,6,12,9,.16),_room("reading","资料阅览室",-8,9,10,8,-.15),_room("tea","窗边会客茶厅",5,4,18,12,.20)]
 elif building.contains("inn"):
  if floor_no==1:
   return [_room("reception","海风旅舍接待",-23,-14,12,10,.10),_room("lounge","旅客共享大客厅",-8,-17,17,12,-.15),_room("dining","早餐餐厅",12,-15,11,10,.12),_room("kitchen","备餐厨房",-23,4,13,11,-.12),_room("laundry","洗衣与行李间",-7,8,10,8,.16),_room("bath","公共卫浴",6,10,8,6,-.12)]
  if floor_no==2:
   return [_room("guest","201 · 蓝湾套间",-23,-17,18,12,.18),_room("guest","202 · 安静单人房",-2,-13,9,9,-.13),_room("guest","203 · 海风双床房",10,-16,13,11,.15),_room("guest","204 · 家庭客房",-23,4,14,12,-.14),_room("reading","旅舍阅览室",-6,8,11,9,.16),_room("tea","楼层会客茶厅",8,6,15,10,-.15)]
  return [_room("guest","301 · 观景大套间",-23,-17,20,12,-.18),_room("guest","302 · 双人套间",1,-16,22,12,.18),_room("guest","303 · 海风客房",-23,5,11,12,.10),_room("guest","304 · 静夜单人房",-9.2,9,9,8,-.12),_room("reading","旅舍阅览室",2.6,7,10,10,.16),_room("tea","楼层小茶室",15.4,4,7.6,11,-.12)]
 if floor_no==1:
  return [_room("living","共享大客厅",-23,-17,18,12,.18),_room("kitchen","生活厨房",-2,-13,10,9,-.12),_room("reading","漂流书房",11,-16,12,9,.10),_room("guest","朋友的客房",-23,5,14,11,-.12),_room("bath","共享卫浴",-6,8,7,7,.10),_room("lounge","会客休息厅",4,4,19,12,-.18)]
 if floor_no==2:
  return [_room("bedroom","大肥鱼 · 大主卧",-22,-17,18,12,-.18),_room("living","家里的大客厅",0,-15,22,11,.18),_room("work","个人工作间",-23,4,10,9,.12),_room("kitchen","日常厨房",-10,6,10,10,-.12),_room("bath","蓝白小卫浴",3,9,6,7,.08),_room("guest","朋友的客房",12,4,11,12,-.12)]
 return [_room("plants","阳光植物大房",-23,-17,20,13,.15),_room("tea","观景茶厅",1,-16,21,11,-.18),_room("craft","手作收纳室",-23,5,10,9,-.10),_room("laundry","洗衣晾晒房",-10.2,8,8,8,.12),_room("storage","生活小储藏室",.6,10,7,6,-.08),_room("roof","屋顶联通休息区",10.4,4,12.6,13,.12)]

static func _furnish(g,b,c: Vector3,kind: String,index: int,size: Vector2=Vector2.ZERO) -> void:
 if SpecialRooms.furnish(g,b,c,kind,index):return
 match kind:
  "living","lounge":
   _rug(b,c+Vector3(-1.9,0,-1.3),Vector2(6.5,4.2),Color("809aaa"))
   _props(g,c,[["sofa_cream",Vector3(-2.7,0,-2.7)],["coffee_table",Vector3(-2.1,0,-.6)],["tea_tray",Vector3(-2.1,.55,-1.10)],["armchair_sage",Vector3(1.3,0,-.9),-18],["tv_cabinet",Vector3(2.7,0,-4.4)],["bookcase",Vector3(-4.8,0,-4.3)],["lamp_floor",Vector3(-4.5,0,-2.4)],["plant_fiddle",Vector3(4.9,0,-4.0)],["side_table",Vector3(3.8,0,2.0)],["flowers",Vector3(3.8,.66,1.58)],["whale_plush",Vector3(-2.3,.72,-3.17)],["basket",Vector3(-4.6,0,2.2)]])
   if kind=="lounge":_props(g,c,[["loveseat_navy",Vector3(2.2,0,3.6)],["lamp_table",Vector3(3.8,.66,1.58)]])
  "kitchen":
   _props(g,c,[["fridge",Vector3(-4.7,0,-4.5)],["sink_counter",Vector3(-3.0,0,-4.5)],["counter_blank",Vector3(-1.4,0,-4.5)],["stove_counter",Vector3(.2,0,-4.5)],["upper_cabinet",Vector3(-2.1,1.6,-5.35)],["microwave",Vector3(-1.4,1.0,-4.94)],["dining_round",Vector3(1.0,0,1.8)],["chair_white",Vector3(-.6,0,.96),90],["chair_white",Vector3(2.6,0,.96),-90],["tea_tray",Vector3(1,.89,.96)],["tea_trolley",Vector3(4.5,0,2.5)],["waste_bin",Vector3(4.7,0,-3.3)],["plant_snake",Vector3(-4.8,0,2.2)]])
  "bedroom","guest":
   _rug(b,c+Vector3(-1.8,0,-1.45),Vector2(6.0,4.8),Color("859bad"))
   var bed: String="bed_sage" if index%2==1 else "bed_navy"
   _props(g,c,[[bed,Vector3(-2.5,0,-.65)],["nightstand",Vector3(-4.25,0,-2.4)],["lamp_table",Vector3(-4.25,.73,-2.76)],["wardrobe",Vector3(4.5,0,-4.3)],["desk_white",Vector3(2.7,0,.9)],["office_chair",Vector3(2.7,0,2.0),180],["laptop",Vector3(2.7,.97,.43)],["bookcase",Vector3(-4.7,0,-4.4)],["folded_blanket",Vector3(-2.5,.8,-1.15)],["whale_plush",Vector3(-2.9,.8,-2.72)],["slippers",Vector3(-2.2,0,.1)],["plant_snake",Vector3(4.7,0,3.0)]])
   if kind=="guest" and index%2==1:_props(g,c,[["bed_navy",Vector3(.4,0,-.65)]])
  "work","craft":
   _props(g,c,[["desk_oak",Vector3(-2.9,0,-2.6)],["desk_white",Vector3(2.2,0,-2.6)],["office_chair",Vector3(-2.9,0,-1.1),180],["office_chair",Vector3(2.2,0,-1.1),180],["monitor",Vector3(-2.9,.97,-3.08)],["keyboard",Vector3(-2.9,.97,-2.80)],["laptop",Vector3(2.2,.97,-3.03)],["bookcase",Vector3(-4.7,0,-4.5)],["cubby",Vector3(-2.7,0,-4.5)],["storage_box",Vector3(4.6,0,-4.2)],["loveseat_navy",Vector3(2.5,0,3.7)],["side_table",Vector3(-3.4,0,2.9)],["whale_mug",Vector3(-3.4,.66,2.49)],["lamp_floor",Vector3(4.8,0,2.0)],["plant_broadleaf",Vector3(-4.6,0,1.8)]])
   if kind=="craft":_props(g,c,[["tea_trolley",Vector3(.2,0,2.1)],["basket",Vector3(-1.6,0,2.6)],["open_book",Vector3(2.6,.97,-2.95)]])
  "reading","books":
   _props(g,c,[["bookcase",Vector3(-4.6,0,-4.5)],["bookcase",Vector3(-2.7,0,-4.5)],["bookcase",Vector3(-.8,0,-4.5)],["armchair_sage",Vector3(-3.5,0,-.5)],["armchair_navy",Vector3(.2,0,-.5)],["coffee_table",Vector3(-1.5,0,1.3)],["books",Vector3(-1.5,.55,.82)],["desk_oak",Vector3(3.7,0,-2.8)],["chair_oak",Vector3(3.7,0,-1.3),180],["open_book",Vector3(3.7,.97,-3.27)],["lamp_floor",Vector3(-4.9,0,-.6)],["plant_fiddle",Vector3(4.8,0,2.8)],["basket",Vector3(-4.5,0,2.8)]])
   if kind=="books":_props(g,c,[["counter_blank",Vector3(2.7,0,3.8)],["keyboard",Vector3(2.7,1.0,3.36)]])
  "bath":
   _props(g,c,[["district_bathtub",Vector3(-3.4,0,-3.4)],["district_vanity",Vector3(.2,0,-4.7)],["district_shower",Vector3(3.8,0,-4.2)],["district_towel_rack",Vector3(-4.7,0,.8)],["basket",Vector3(-1.1,0,1.4)],["slippers",Vector3(-3.6,0,-1.0)],["plant_snake",Vector3(4.8,0,1.1)],["entry_bench",Vector3(2.8,0,2.8)]])
  "laundry":
   _props(g,c,[["district_washer",Vector3(-4.8,0,-4.6)],["district_washer",Vector3(-3.4,0,-4.6)],["district_washer",Vector3(-2,0,-4.6)],["counter_blank",Vector3(1.2,0,-4.6)],["folded_blanket",Vector3(1.2,1.0,-5.04)],["district_clothesline",Vector3(-2.5,0,1.9)],["district_clothesline",Vector3(1.9,0,1.9)],["basket",Vector3(-.3,0,.4)],["storage_box",Vector3(4.5,0,.5)],["entry_bench",Vector3(-4.5,0,3.2)],["plant_snake",Vector3(4.7,0,3.2)]])
  "plants","roof":
   for i in 5:g._asset("planter",c+Vector3(-4.8+i*2.4,0,-4.6))
   for x in [-4.5,4.5]:g._asset("bench",c+Vector3(x,0,2.0))
   g._asset("flower_stand",c+Vector3(-3.0,0,-2.5));g._asset("flower_stand",c+Vector3(.1,0,-2.5))
   g._asset("outdoor_table",c+Vector3(2.7,0,.8))
   _props(g,c,[["plant_fiddle",Vector3(-4.6,0,-1.2)],["plant_broadleaf",Vector3(4.8,0,-2.6)],["plant_snake",Vector3(-1.6,0,2.2)],["tea_trolley",Vector3(3.6,0,3.6)]])
   if kind=="roof":g._asset("tree",c+Vector3(-1.0,0,-4.4))
  "storage":
   _props(g,c,[["bookcase",Vector3(-4.7,0,-4.5)],["bookcase",Vector3(-2.8,0,-4.5)],["bookcase",Vector3(-.9,0,-4.5)],["cubby",Vector3(2.6,0,-4.5)],["wardrobe",Vector3(4.7,0,-4.4)],["storage_box",Vector3(-4.2,0,.8)],["storage_box",Vector3(-2.4,0,2.5)],["storage_box",Vector3(2.9,0,2.4)],["basket",Vector3(.8,0,-1.4)],["folded_blanket",Vector3(2.6,1.44,-4.84)],["entry_bench",Vector3(4.1,0,.6)]])
  "tea","dining":
   # 窄房间只摆一组桌椅。两组（每组一张圆桌 + 两把椅子）横排时会连成一道篱笆把房间
   # 拦腰截断 —— 海风旅舍 3F「楼层小茶室」宽 7.6m 就是这样：跨帧实测里侧 115 个可站格
   # 从门口可达 0。单组时它自己靠一侧，另一侧留出通道。
   var seats: Array=[-2.6,2.6] if size.x>=11.0 else [-2.6]
   for x in seats:
    _props(g,c,[["dining_round",Vector3(x,0,1.8)],["chair_white",Vector3(x-1.5,0,.96),90],["chair_white",Vector3(x+1.5,0,.96),-90],["tea_tray",Vector3(x,.89,.96)]])
   _props(g,c,[["bar_cabinet",Vector3(3.8,0,-4.0)],["espresso",Vector3(3.8,1.0,-4.4)],["tea_trolley",Vector3(-4.6,0,-2.0)],["armchair_sage",Vector3(-2.5,0,-2.8)],["lamp_floor",Vector3(-4.6,0,-3.8)],["plant_fiddle",Vector3(4.7,0,3.6)]])
  "cafe":
   _props(g,c,[["bar_cabinet",Vector3(3.9,0,-3.8)],["espresso",Vector3(3.9,1.0,-4.2)],["bakery_case",Vector3(1.8,0,-3.8)],["loveseat_navy",Vector3(-3.7,0,-2.8)],["side_table",Vector3(-1.8,0,-1.5)],["flowers",Vector3(-1.8,.66,-1.9)],["plant_fiddle",Vector3(-4.7,0,2.5)]])
   for x in [-2.1,2.7]:_props(g,c,[["dining_round",Vector3(x,0,2.6)],["chair_white",Vector3(x-1.5,0,1.76),90],["chair_white",Vector3(x+1.5,0,1.76),-90],["tea_tray",Vector3(x,.89,1.76)]])
  "reception":
   _props(g,c,[["bar_cabinet",Vector3(0,0,-2.8)],["monitor",Vector3(.3,1.0,-3.25)],["keyboard",Vector3(.3,1.0,-3.02)],["bookcase",Vector3(-3.8,0,-4.4)],["cubby",Vector3(3.6,0,-4.4)],["sofa_cream",Vector3(-3.6,0,1.2)],["armchair_sage",Vector3(2.8,0,1.2)],["coffee_table",Vector3(-.4,0,2.8)],["tea_tray",Vector3(-.4,.55,2.3)],["plant_fiddle",Vector3(4.8,0,3.6)],["lamp_floor",Vector3(-4.8,0,-2.7)]])
  "meeting":
   _props(g,c,[["dining_white",Vector3(-1.3,0,.3)],["dining_white",Vector3(1.3,0,.3)],["bookcase",Vector3(-4.7,0,-4.3)],["tv_cabinet",Vector3(2.8,0,-4.3)],["monitor",Vector3(2.8,.71,-4.6)],["plant_fiddle",Vector3(4.8,0,3.2)],["lamp_floor",Vector3(-4.6,0,2.8)]])
   for x in [-2.0,0.0,2.0]:_props(g,c,[["chair_white",Vector3(x,0,1.8),180],["chair_white",Vector3(x,0,-2.25)],["books",Vector3(x,.91,-.25)]])
  "exhibit":
   _props(g,c,[["cubby",Vector3(-4.4,0,-4.4)],["cubby",Vector3(0,0,-4.4)],["cubby",Vector3(4.4,0,-4.4)],["whale_plush",Vector3(-4.4,1.44,-4.73)],["bonsai",Vector3(0,1.44,-4.73)],["flowers",Vector3(4.4,1.44,-4.73)],["entry_bench",Vector3(-2.9,0,1.5)],["entry_bench",Vector3(2.9,0,1.5)],["plant_fiddle",Vector3(4.7,0,3.6)],["plant_broadleaf",Vector3(-4.7,0,3.6)]])
