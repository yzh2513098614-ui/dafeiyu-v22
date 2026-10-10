extends RefCounted
## Four different partitions, each completely tiled by neighboring rooms.
## These are room interiors, never a detached-room/corridor generator.
static func family(building: String,level: int) -> int:
 var base: int={"apartment":0,"community":2,"inn":1,"restaurant":1,"school":2,"hospital":3,"music":3,"observatory":2,"gallery":3}.get(building,0)
 return (base+level-1)%4

static func name_for(index: int) -> String:
 return ["错位双排","侧厅嵌合","梯级叠房","中央套间"][index]

static func _poly(points: Array) -> PackedVector2Array:
 var result:=PackedVector2Array()
 for point in points:result.append(Vector2(point[0],point[1]))
 if Geometry2D.is_polygon_clockwise(result):result.reverse()
 return result

static func make(index: int,seed: int) -> Array[PackedVector2Array]:
 var plans: Array=[]
 match index:
  1:
   plans=[
    [[-22,-12],[-19,-15],[-7,-15],[-7,3],[-22,3]],
    [[-7,-15],[8,-15],[8,-4],[-7,-4]],
    [[8,-15],[18,-15],[22,-11],[22,0],[8,0]],
    [[-7,-4],[8,-4],[8,7],[12,7],[12,16],[3,16],[3,14],[-7,14]],
    [[8,0],[22,0],[22,12],[18,16],[12,16],[12,7],[8,7]],
    [[-22,3],[-7,3],[-7,16],[-18,16],[-22,12]]]
  2:
   plans=[
    [[-22,-13],[-18,-17],[0,-17],[0,-2],[-22,-2]],
    [[0,-17],[16,-17],[20,-13],[20,-2],[0,-2]],
    [[-22,-2],[-7,-2],[-7,8],[-25,8],[-25,2],[-22,2]],
    [[-7,-2],[20,-2],[20,6],[17,8],[-7,8]],
    [[-25,8],[6,8],[6,17],[-18,17],[-18,14],[-25,14]],
    [[6,8],[17,8],[17,14],[13,17],[6,17]]]
  3:
   plans=[
    [[-18,-9],[-3,-9],[-3,9],[-18,9]],
    [[-18,-9],[-18,-16],[-11,-18],[-3,-18],[-3,-9]],
    [[-3,-18],[16,-18],[21,-13],[21,-2],[-3,-2]],
    [[-3,-2],[21,-2],[21,8],[10,8],[10,11],[-3,11]],
    [[-20,9],[-3,9],[-3,21],[-15,21],[-20,16]],
    [[-3,11],[10,11],[10,8],[21,8],[21,17],[17,21],[-3,21]]]
 var result: Array[PackedVector2Array]=[]
 for points in plans:
  var poly:=_poly(points)
  for n in poly.size():
   if seed%2==1:poly[n].x=-poly[n].x
   if seed%4 in [2,3]:poly[n].y=-poly[n].y
  if Geometry2D.is_polygon_clockwise(poly):poly.reverse()
  result.append(poly)
 return result
