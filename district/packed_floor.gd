extends RefCounted
## Interlocking rooms share walls and doorways; there is no corridor spine.
const Shape=preload("res://district/space_shape.gd")
const Walls=preload("res://district/themed_walls.gd")
const Details=preload("res://district/room_details.gd")
const Modern=preload("res://modern_materials.gd")
const Partitions=preload("res://district/floor_partitions.gd")
const DOOR=2.4

static func _rect(poly: PackedVector2Array) -> Rect2:
 var result:=Rect2(poly[0],Vector2.ZERO)
 for point in poly:result=result.expand(point)
 return result

static func _area(poly: PackedVector2Array) -> float:
 var result:=0.0
 for n in poly.size():result+=poly[n].cross(poly[(n+1)%poly.size()])*.5
 return absf(result)

static func polygons(programs: Array,seed: int) -> Array[PackedVector2Array]:
 # Unequal widths follow the existing room programs, while the two rows use
 # offset partitions. The middle upper room extends between the lower rooms.
 var upper: Array[float]=[];var total:=0.0
 for n in 3:upper.append(sqrt(programs[n].rect.get_area()));total+=upper[n]
 var widths: Array[float]=[]
 for weight in upper:widths.append(weight/total*44)
 var left: float=-22;var right: float=22
 var x1: float=left+widths[0];var x2: float=x1+widths[1]
 var b1: float=x1+(-2.8 if seed%2==0 else 2.4)
 var b2: float=x2+(2.6 if seed%3==0 else -2.1)
 b1=clampf(b1,left+7,x2-4);b2=clampf(b2,b1+6,right-7)
 var extension: float=2.4+.35*(seed%3)
 var depths: Array[float]=[]
 for n in 6:depths.append(clampf(programs[n].rect.size.y+2.0+float((seed+n)%3),10,17))
 var a: float=-depths[0];var b: float=-depths[1];var c: float=-depths[2]
 var result: Array[PackedVector2Array]=[]
 result.append(PackedVector2Array([Vector2(left,0),Vector2(x1,0),Vector2(x1,a),Vector2(left+3,a),Vector2(left,a+3)]))
 result.append(PackedVector2Array([Vector2(x1,0),Vector2(b1,0),Vector2(b1,extension),Vector2(b2,extension),Vector2(b2,0),Vector2(x2,0),Vector2(x2,b),Vector2(x1,b)]))
 var bay:=PackedVector2Array([Vector2(x2,0),Vector2(right,0),Vector2(right,c+3)])
 for n in range(1,9):
  var angle: float=n*PI/8
  bay.append(Vector2((x2+right)/2+cos(angle)*(right-x2)/2,c+3-sin(angle)*3))
 result.append(bay)
 result.append(PackedVector2Array([Vector2(left,0),Vector2(b1,0),Vector2(b1,depths[3]),Vector2(left+3.2,depths[3]),Vector2(left+3.2,depths[3]-3),Vector2(left,depths[3]-3)]))
 result.append(PackedVector2Array([Vector2(b1,extension),Vector2(b2,extension),Vector2(b2,depths[4]-1.8),Vector2(b2-1.8,depths[4]),Vector2(b1,depths[4])]))
 result.append(PackedVector2Array([Vector2(b2,0),Vector2(right,0),Vector2(right,depths[5]-2.8),Vector2(right-3,depths[5]),Vector2(b2,depths[5])]))
 for poly in result:
  if seed%2==1:
   for n in poly.size():poly[n].x=-poly[n].x
  if seed%4 in [2,3]:
   for n in poly.size():poly[n].y=-poly[n].y
  if Geometry2D.is_polygon_clockwise(poly):poly.reverse()
 return result

static func _key(a: Vector2,end: Vector2) -> String:
 var first: Vector2=a;var last: Vector2=end
 if first.x>last.x or (is_equal_approx(first.x,last.x) and first.y>last.y):first=end;last=a
 return "%.4f,%.4f:%.4f,%.4f"%[first.x,first.y,last.x,last.y]

static func segments(polys: Array[PackedVector2Array]) -> Array:
 var vertices: Array[Vector2]=[]
 for poly in polys:
  for point in poly:vertices.append(point)
 var found: Dictionary={}
 for owner in polys.size():
  var poly: PackedVector2Array=polys[owner]
  for n in poly.size():
   var a: Vector2=poly[n];var end: Vector2=poly[(n+1)%poly.size()]
   var split: Array[Vector2]=[a,end]
   for point in vertices:
    if point.distance_to(a)<.001 or point.distance_to(end)<.001:continue
    if Geometry2D.get_closest_point_to_segment(point,a,end).distance_to(point)<.001:
     if not split.has(point):split.append(point)
   split.sort_custom(func(p: Vector2,q: Vector2):return a.distance_squared_to(p)<a.distance_squared_to(q))
   for j in range(split.size()-1):
    var key:=_key(split[j],split[j+1])
    if not found.has(key):found[key]={"a":split[j],"end":split[j+1],"owners":[],"door":false}
    if not owner in found[key].owners:found[key].owners.append(owner)
 return found.values()

static func center(poly: PackedVector2Array) -> Vector2:
 var rect:=_rect(poly);var best:=rect.get_center();var score: float=-INF
 var z: float=rect.position.y+.8
 while z<rect.end.y:
  var x: float=rect.position.x+.8
  while x<rect.end.x:
   var point:=Vector2(x,z)
   if Geometry2D.is_point_in_polygon(point,poly):
    var distance: float=Shape.distance_to_edge(point,poly)-point.distance_to(rect.get_center())*.12
    if distance>score:score=distance;best=point
   x+=.5
  z+=.5
 return best

static func build(g,data: Dictionary,programs: Array) -> Dictionary:
 var level: int=int(data.get("floor",1));var building: String=str(data.get("building","apartment"))
 var seed: int=int(abs(building.hash()))%12+level
 var stem: String=str(data.get("id",str(data.get("prefix",building))+"_"+str(level)))
 var family: int=Partitions.family(building,level)
 var polys: Array[PackedVector2Array]=polygons(programs,seed) if family==0 else Partitions.make(family,seed)
 var walls: Array=segments(polys)
 var visited: Dictionary={0:true};var selected: Array=[]
 while visited.size()<polys.size():
  var candidates: Array=[]
  for edge in walls:
   if edge.owners.size()!=2 or edge.a.distance_to(edge.end)<DOOR+.65:continue
   if visited.has(edge.owners[0])!=visited.has(edge.owners[1]):candidates.append(edge)
  candidates.sort_custom(func(p,q):return p.a.distance_to(p.end)>q.a.distance_to(q.end))
  if candidates.is_empty():push_error("Packed floor room graph is disconnected");break
  var edge: Dictionary=candidates[0];edge.door=true
  visited[edge.owners[0]]=true;visited[edge.owners[1]]=true;selected.append(edge)
 # One additional cross-link gives a route around the kitchen or bedrooms.
 for edge in walls:
  if edge.owners.size()==2 and not edge.door and edge.a.distance_to(edge.end)>DOOR+1.3:
   edge.door=true;selected.append(edge);break
 var zones: Array=[]
 for n in 6:
  var midpoint: Vector2=center(polys[n]);var rect: Rect2=_rect(polys[n])
  zones.append({"id":stem+"_room"+str(n+1),"name":str(programs[n].name),"kind":str(programs[n].kind),"rect":rect,"polygon":polys[n],"shape":"interlock_"+str(n),"center":Vector3(midpoint.x,0,midpoint.y),"doors":[],"door_clear":[],"external_edges":[]})
 for edge in walls:
  if edge.owners.size()==1:zones[edge.owners[0]].external_edges.append(PackedVector2Array([edge.a,edge.end]))
 for edge in selected:
  var point: Vector2=(edge.a+edge.end)*.5;var door:=Vector3(point.x,0,point.y)
  for owner in edge.owners:
   zones[owner].doors.append(door);zones[owner].door_clear.append(Rect2(point-Vector2.ONE*1.50,Vector2.ONE*3.0))
  _door(g,edge,door)
 for edge in walls:
  var a:=Vector3(edge.a.x,0,edge.a.y);var end:=Vector3(edge.end.x,0,edge.end.y)
  var kind: String=zones[edge.owners[0]].kind
  if edge.door:
   var midpoint: Vector3=(a+end)*.5;var direction: Vector3=(end-a).normalized()
   _wall(g,kind,a,midpoint-direction*DOOR/2,edge.owners)
   _wall(g,kind,midpoint+direction*DOOR/2,end,edge.owners)
  else:_wall(g,kind,a,end,edge.owners)
 var contours: Array[PackedVector2Array]=Shape.union(polys)
 g.shell.set_meta("floor_contours",contours);g.shell.set_meta("room_connections",selected)
 g.shell.set_meta("floor_layout","interlocking_rooms")
 g.shell.set_meta("layout_revision","packed_rooms_v2")
 g.shell.set_meta("partition_family",Partitions.name_for(family))
 for poly in contours:Shape.slab(g,poly)
 var furnish=load("res://district/whole_floor.gd")
 var b=g._builder(g.shell)
 var root_rect: Rect2=zones[0].rect
 var spawn: Vector3=zones[0].center
 # Portals stay inside the entrance room, rather than a deleted hallway.
 var exit:=spawn+Vector3(-3.0,0,1.5);var up:=spawn+Vector3(3.0,0,1.5);var down:=spawn+Vector3(0,0,-3.0)
 for point in [exit,up,down]:zones[0].door_clear.append(Rect2(Vector2(point.x-1.4,point.z-3.5),Vector2(2.8,4.9)))
 for n in 6:
  var zone: Dictionary=zones[n];var south: bool=zone.center.z>0
  zone.door=zone.doors[0]
  zone.paths=Shape.access_routes(zone.polygon,zone.center,zone.doors+[exit,up,down] if n==0 else zone.doors)
  var floor_style: String=furnish.SpecialRooms.floor_style(zone.kind,"pale_oak" if zone.kind in ["guest","bedroom","reading","books","tea","living"] else "ivory_tile")
  var floor: MeshInstance3D=Shape.floor_mesh(zone.polygon,.020,floor_style);floor.name="RoomFloor_"+str(n);floor.set_meta("room_polygon",zone.polygon);g.shell.add_child(floor)
  var first_prop: int=g.world.get_child_count();var first_detail: int=b.get_child_count()
  var midpoint: Vector2=zone.rect.get_center();var anchor:=Vector3(midpoint.x,0,midpoint.y)
  furnish._furnish(g,b,anchor,zone.kind,n,zone.rect.size)
  furnish._fit_furniture(g,g.world,first_prop,zone.rect,zone.door,south,zone.polygon,zone.door_clear+zone.paths)
  furnish._fit_details(b,first_detail,zone.rect,south,zone.polygon)
  Details.build(g,zone.rect,zone.kind,south,n,zone.door,zone.polygon,zone.door_clear+zone.paths,zone.external_edges)
  var sign=g._sign(zone.name,zone.center+Vector3(0,.42,0),28,Color("d7e4de"));sign.pixel_size=.018;sign.outline_size=4;sign.outline_modulate=Color("324b59");sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sign.add_to_group("floor_room_labels")
 var outline: Rect2=_rect(contours[0])
 return {"bounds":Vector2(maxf(absf(outline.position.x),absf(outline.end.x))*2+4,maxf(absf(outline.position.y),absf(outline.end.y))*2+4),"spawn":spawn,"zones":zones,"camera_size":48.0,"exit_anchor":exit,"stairs_anchor":up,"down_anchor":down}

static func _wall(g,kind: String,a: Vector3,end: Vector3,owners: Array) -> void:
 var before: int=g.shell.get_child_count()
 if not (Walls.supports(kind) and Walls.run(g,kind,a,end)):
  var floor=load("res://district/whole_floor.gd");floor._plain_run(g,a,end,1.1)
 for node in g.shell.get_children().slice(before):node.set_meta("room_owners",owners)

static func _door(g,edge: Dictionary,pos: Vector3) -> void:
 var holder:=Node3D.new();holder.name="SharedRoomDoor";holder.position=pos
 holder.rotation.y=-atan2(edge.end.y-edge.a.y,edge.end.x-edge.a.x);g.shell.add_child(holder)
 var b=g._builder(holder)
 for side in [-1,1]:b.box(Vector3(.09,2.22,.13),Vector3(side*(DOOR/2+.04),1.11,0),Color("455665"))
 b.box(Vector3(DOOR+.20,.09,.13),Vector3(0,2.22,0),Color("455665"))
 b.box(Vector3(DOOR-.12,.008,.46),Vector3(0,.03,0),Color("9bbbc0"))
 holder.set_meta("room_owners",edge.owners)
 var gate=preload("res://district/interactive_door.gd").new();gate.name="InteractiveDoor";holder.add_child(gate)
 gate.configure(g,DOOR,_key(edge.a,edge.end),"房间门")
