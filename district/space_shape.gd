extends RefCounted
## Authoritative floor contours shared by meshes, physics, placement and UI.
const Modern=preload("res://modern_materials.gd")
const SHAPES=["l_right","l_left","t_wing","courtyard","bevel","trapezoid","round_bay"]

static func rectangle(rect: Rect2) -> PackedVector2Array:
 return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

static func profile(rect: Rect2,south: bool,style: String) -> PackedVector2Array:
 var points: Array
 match style:
  "l_right":points=[Vector2(-.5,0),Vector2(.5,0),Vector2(.5,.55),Vector2(.05,.55),Vector2(.05,1),Vector2(-.5,1)]
  "l_left":points=[Vector2(-.5,0),Vector2(.5,0),Vector2(.5,1),Vector2(-.05,1),Vector2(-.05,.55),Vector2(-.5,.55)]
  "t_wing":points=[Vector2(-.5,0),Vector2(.5,0),Vector2(.5,.61),Vector2(.26,.61),Vector2(.26,1),Vector2(-.26,1),Vector2(-.26,.61),Vector2(-.5,.61)]
  "courtyard":points=[Vector2(-.5,0),Vector2(.5,0),Vector2(.5,1),Vector2(.17,1),Vector2(.17,.65),Vector2(-.17,.65),Vector2(-.17,1),Vector2(-.5,1)]
  "bevel":points=[Vector2(-.5,0),Vector2(.5,0),Vector2(.5,.73),Vector2(.26,1),Vector2(-.26,1),Vector2(-.5,.73)]
  "trapezoid":points=[Vector2(-.5,0),Vector2(.5,0),Vector2(.32,1),Vector2(-.32,1)]
  "round_bay":
   points=[Vector2(-.5,0),Vector2(.5,0),Vector2(.5,.65)]
   for n in range(1,13):
    var a: float=n*PI/12
    points.append(Vector2(cos(a)*.5,.65+sin(a)*.35))
  _:return rectangle(rect)
 var result:=PackedVector2Array()
 var front: float=rect.position.y if south else rect.end.y
 for point: Vector2 in points:
  result.append(Vector2(rect.get_center().x+point.x*rect.size.x,front+point.y*rect.size.y*(1 if south else -1)))
 if Geometry2D.is_polygon_clockwise(result):result.reverse()
 return result

static func choose(building: String,level: int,index: int,rect: Rect2) -> String:
 if minf(rect.size.x,rect.size.y)<8:return "bevel" if (index+level)%2==0 else "trapezoid"
 var offset: int=int(abs(building.hash()))%SHAPES.size()
 return SHAPES[(offset+level*2+index)%SHAPES.size()]

static func contains_rect(poly: PackedVector2Array,rect: Rect2,margin: float=.12) -> bool:
 if poly.is_empty():return true
 var corners: PackedVector2Array=rectangle(rect.grow(margin))
 for point in corners:
  if not Geometry2D.is_point_in_polygon(point,poly):return false
 # Corners alone miss a U-shaped notch. Sample edges and reject boundary crossings.
 for n in 4:
  var a: Vector2=corners[n];var z: Vector2=corners[(n+1)%4]
  for p in [.25,.5,.75]:
   if not Geometry2D.is_point_in_polygon(a.lerp(z,p),poly):return false
  for j in poly.size():
   if Geometry2D.segment_intersects_segment(a,z,poly[j],poly[(j+1)%poly.size()])!=null:return false
 return true

static func distance_to_edge(point: Vector2,poly: PackedVector2Array) -> float:
 var distance:=INF
 for n in poly.size():distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,poly[n],poly[(n+1)%poly.size()])))
 return distance

static func local_polygon(holder: Node3D,poly: PackedVector2Array) -> PackedVector2Array:
 var result:=PackedVector2Array()
 for point in poly:
  var p: Vector3=holder.to_local(Vector3(point.x,0,point.y));result.append(Vector2(p.x,p.z))
 return result

static func floor_mesh(poly: PackedVector2Array,height: float,style: String) -> MeshInstance3D:
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var indices: PackedInt32Array=Geometry2D.triangulate_polygon(poly)
 for n in range(0,indices.size(),3):
  var a: Vector2=poly[indices[n]];var z: Vector2=poly[indices[n+1]];var c: Vector2=poly[indices[n+2]]
  if (z-a).cross(c-a)<0:
   var swap:=z;z=c;c=swap
  for point in [a,z,c]:
   tool.set_normal(Vector3.UP);tool.set_uv(point);tool.add_vertex(Vector3(point.x,height,point.y))
 var mesh:=MeshInstance3D.new();mesh.mesh=tool.commit()
 mesh.material_override=Modern.floor_material(style);mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return mesh

static func union(parts: Array) -> Array[PackedVector2Array]:
 var result: Array[PackedVector2Array]=[]
 for part: PackedVector2Array in parts:
  var pending:=part;var changed:=true
  while changed:
   changed=false
   for n in result.size():
    var merged: Array[PackedVector2Array]=Geometry2D.merge_polygons(pending,result[n])
    if merged.size()==1:
     pending=merged[0];result.remove_at(n);changed=true;break
  result.append(pending)
 return result

static func slab(g,poly: PackedVector2Array) -> void:
 var top: MeshInstance3D=floor_mesh(poly,-.025,"slate_tile");top.name="ContouredFloorSlab";g.shell.add_child(top)
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for n in poly.size():
  var a:=Vector3(poly[n].x,-.025,poly[n].y);var z:=Vector3(poly[(n+1)%poly.size()].x,-.025,poly[(n+1)%poly.size()].y)
  var c:=z-Vector3(0,.24,0);var d:=a-Vector3(0,.24,0)
  var normal: Vector3=Vector3(z.z-a.z,0,a.x-z.x).normalized()
  for point in [a,c,z,a,d,c]:tool.set_normal(normal);tool.add_vertex(point)
 var side:=MeshInstance3D.new();side.name="ContouredSlabEdge";side.mesh=tool.commit();side.material_override=Modern.surface(Color("617482"),false,false);g.shell.add_child(side)
 g.shell.set_meta("floor_contour",poly)

static func fitted_candidates(anchor: Vector3,inside: Rect2) -> Array[Vector3]:
 var result: Array[Vector3]=[anchor]
 for step in [.55,1.1,1.7,2.4]:
  for shift in [Vector2(step,0),Vector2(-step,0),Vector2(0,step),Vector2(0,-step),Vector2(step,-step),Vector2(-step,-step)]:result.append(anchor+Vector3(shift.x,0,shift.y))
 var wide: Array[Vector3]=[]
 var z: float=inside.position.y+.6
 while z<inside.end.y:
  var x: float=inside.position.x+.6
  while x<inside.end.x:wide.append(Vector3(x,anchor.y,z));x+=.9
  z+=.9
 wide.sort_custom(func(a: Vector3,b: Vector3):return a.distance_squared_to(anchor)<b.distance_squared_to(anchor))
 result.append_array(wide)
 return result

static func access_routes(poly: PackedVector2Array,center: Vector3,doors: Array) -> Array:
 var rect:=Rect2(poly[0],Vector2.ZERO)
 for p in poly:rect=rect.expand(p)
 var step:=.5;var free: Dictionary={}
 for z in int(rect.size.y/step)+1:
  for x in int(rect.size.x/step)+1:
   var point: Vector2=rect.position+Vector2(x,z)*step
   if Geometry2D.is_point_in_polygon(point,poly) and distance_to_edge(point,poly)>.64:free[Vector2i(x,z)]=point
 if free.is_empty():return []
 var root:=Vector2i.ZERO;var distance:=INF
 for cell in free:
  var d: float=free[cell].distance_to(Vector2(center.x,center.z))
  if d<distance:distance=d;root=cell
 var queue: Array[Vector2i]=[root];var parents: Dictionary={root:root};var cursor:=0
 while cursor<queue.size():
  var cell: Vector2i=queue[cursor];cursor+=1
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=cell+direction
   if free.has(next) and not parents.has(next):parents[next]=cell;queue.append(next)
 var protected: Dictionary={}
 for door: Vector3 in doors:
  var target: Vector2i=root;distance=INF
  for cell in parents:
   var d: float=free[cell].distance_to(Vector2(door.x,door.z))
   if d<distance:distance=d;target=cell
  var cell: Vector2i=target
  while cell!=root:protected[cell]=true;cell=parents[cell]
 protected[root]=true
 var result: Array=[]
 for cell in protected:result.append(Rect2(free[cell]-Vector2.ONE*.57,Vector2.ONE*1.14))
 return result
