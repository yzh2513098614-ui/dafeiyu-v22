extends RefCounted
## Walkable irregular outdoor maps. Meshes, boundaries and placement share contours.
const Shape=preload("res://district/space_shape.gd")
const Packed=preload("res://district/packed_floor.gd")
const Decor=preload("res://district/decor_library.gd")
const Library=preload("res://district/library_models.gd")
const Modern=preload("res://modern_materials.gd")
const Walls=preload("res://district/themed_walls.gd")
const INK=Color("516675")
const PAPER=Color("dce4de")
const WOOD=Color("b9aa8d")

static func poly(points: Array) -> PackedVector2Array:
 var result:=PackedVector2Array()
 for p in points:result.append(Vector2(p[0],p[1]))
 if Geometry2D.is_polygon_clockwise(result):result.reverse()
 return result

static func ellipse(center: Vector2,size: Vector2,count: int=32) -> PackedVector2Array:
 var result:=PackedVector2Array()
 for n in count:
  var a: float=n*TAU/count
  result.append(center+Vector2(cos(a)*size.x,sin(a)*size.y))
 return result

static func _zone(id: String,title: String,outline: PackedVector2Array) -> Dictionary:
 var rect:=Packed._rect(outline);var c:=Packed.center(outline)
 return {"id":id,"name":title,"rect":rect,"polygon":outline,"center":Vector3(c.x,0,c.y),"paths":[],"door_clear":[]}

static func build(g,id: String) -> Dictionary:
 var contour: PackedVector2Array
 var spawn:=Vector3(-14,0,6);var exit:=Vector3(-17,0,6);var supply:=Vector3(-13,0,9)
 var title: String
 match id:
  "garden":
   contour=poly([[-22,-10],[-18,-17],[-5,-17],[-5,-14],[10,-14],[20,-8],[23,1],[20,8],[12,13],[2,13],[2,17],[-10,17],[-19,10],[-22,2]])
   title="青柠花房 · 折角温室与花岛"
  "market":
   contour=poly([[-24,-8],[-19,-15],[-6,-15],[-6,-18],[5,-18],[11,-14],[19,-14],[24,-7],[24,7],[20,12],[12,16],[1,17],[-9,14],[-17,12],[-24,4]])
   title="海风集市 · 街口与海岸"
  "reading_court":
   contour=poly([[-20,-8],[-14,-15],[-2,-15],[6,-12],[12,-12],[20,-5],[21,5],[16,13],[3,16],[-7,16],[-7,12],[-18,12],[-22,4]])
   title="漂流书庭 · 把书读给海风听"
   spawn=Vector3(-14,0,5);exit=Vector3(-18,0,5);supply=Vector3(-13,0,8)
  _:
   contour=poly([[-24,-4],[-17,-15],[-6,-15],[-6,-11],[11,-11],[20,-3],[24,5],[20,14],[6,17],[-3,13],[-17,13],[-17,8],[-24,8]])
   title="蓝湾公共花园 · 花径与小舞台"
   spawn=Vector3(-17,0,2);exit=Vector3(-20,0,2);supply=Vector3(-15,0,5)
 g.shell.set_meta("floor_layout","landscape_courtyard")
 g.shell.set_meta("layout_revision","courtyards_v2")
 g.shell.set_meta("floor_contours",[contour]);g.shell.set_meta("outdoor_obstacles",[])
 g.shell.set_meta("walk_clear",[])
 Shape.slab(g,contour)
 _surface(g,contour,.022,"terrazzo",Color("b6c9bb") if id=="garden" or id=="civic_garden" else Color("b2c8cd"))
 _boundary(g,contour)
 var zones: Array=[]
 match id:
  "garden":zones=_garden(g)
  "market":zones=_market(g)
  "reading_court":zones=_reading(g)
  _:zones=_civic(g)
 zones.append(_zone(id+"_court","花径与院庭" if id in ["garden","civic_garden"] else "开放休憩平台",contour))
 for zone in zones:
  zone.paths=g.shell.get_meta("walk_clear").duplicate()
  for p in [spawn,exit,supply]:zone.door_clear.append(Rect2(Vector2(p.x,p.z)-Vector2.ONE*1.5,Vector2.ONE*3))
 g.shell.set_meta("guide_anchor",Vector3(-7,0,3) if id=="garden" else (Vector3(-8,0,2) if id=="market" or id=="reading_court" else Vector3(-7,0,0)))
 _detailed(g,"notice_easel",Vector3(exit.x+1.5,0,exit.z-2.5),20)
 _detailed(g,"waste_bin",Vector3(exit.x+1,0,exit.z+2),0)
 var label=g._sign(title,Vector3(0,3.1,-16),32,Color("d6e6df"));label.outline_size=5;label.outline_modulate=Color("395363")
 var rect:=Packed._rect(contour)
 return {"bounds":Vector2(maxf(absf(rect.position.x),absf(rect.end.x))*2+3,maxf(absf(rect.position.y),absf(rect.end.y))*2+3),"spawn":spawn,"exit":exit,"supply":supply,"zones":zones,"camera_size":50.0}

static func _surface(g,outline: PackedVector2Array,height: float,style: String,tint: Color) -> void:
 var node:=Shape.floor_mesh(outline,height,style)
 var mat: ShaderMaterial=node.material_override.duplicate()
 mat.set_shader_parameter("tile_color",tint.srgb_to_linear());node.material_override=mat
 g.shell.add_child(node)

static func _boundary(g,outline: PackedVector2Array) -> void:
 var b=g._builder(g.shell)
 for n in outline.size():
  var a: Vector2=outline[n];var end: Vector2=outline[(n+1)%outline.size()]
  var length: float=a.distance_to(end);var center: Vector2=(a+end)*.5
  var holder:=Node3D.new();holder.name="ContourBoundary";holder.position=Vector3(center.x,0,center.y);holder.rotation.y=-atan2(end.y-a.y,end.x-a.x);g.shell.add_child(holder)
  var local=g._builder(holder)
  local.box(Vector3(length,.15,.13),Vector3(0,.06,0),INK)
  g._collision(holder,Vector3(length,1.4,.13),Vector3(0,.7,0))
  holder.set_meta("boundary_start",a);holder.set_meta("boundary_end",end)
  # Shore-facing rim gets light rails; the foreground remains legible.
  if center.y>10:
   local.box(Vector3(length,.045,.045),Vector3(0,.8,0),INK)
   for k in int(ceil(length/2.2))+1:
    var x: float=-length/2+length*k/maxi(1,int(ceil(length/2.2)))
    local.box(Vector3(.05,.82,.05),Vector3(x,.4,0),INK)

static func _solid(g,outline: PackedVector2Array,bottom: float,top: float,tint: Color,collision: bool=false) -> void:
 var node:=Shape.floor_mesh(outline,top,"terrazzo");node.material_override=Modern.surface(tint);g.shell.add_child(node)
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for n in outline.size():
  var p: Vector2=outline[n];var q: Vector2=outline[(n+1)%outline.size()]
  var a:=Vector3(p.x,top,p.y);var end:=Vector3(q.x,top,q.y)
  var c:=Vector3(q.x,bottom,q.y);var d:=Vector3(p.x,bottom,p.y)
  var normal:=Vector3(q.y-p.y,0,p.x-q.x).normalized()
  for point in [a,c,end,a,d,c]:tool.set_normal(normal);tool.add_vertex(point)
 var side:=MeshInstance3D.new();side.mesh=tool.commit();side.material_override=Modern.surface(tint.darkened(.14));g.shell.add_child(side)
 if collision:
  for part in Geometry2D.decompose_polygon_in_convex(outline):
   var points:=PackedVector3Array()
   for p in part:points.append(Vector3(p.x,bottom,p.y));points.append(Vector3(p.x,maxf(top,.65),p.y))
   var shape:=ConvexPolygonShape3D.new();shape.points=points
   var body:=StaticBody3D.new();var hit:=CollisionShape3D.new();hit.shape=shape;body.add_child(hit);g.shell.add_child(body)
  var obstacles: Array=g.shell.get_meta("outdoor_obstacles");obstacles.append(outline)

static func _detailed(g,id: String,pos: Vector3,angle: float=0) -> Node3D:
 var node: Node3D=Decor.instance(id)
 if node==null:return null
 node.position=pos;node.rotation_degrees.y=angle
 var footprint:=Decor.footprint(node)
 var contour: PackedVector2Array=g.shell.get_meta("floor_contour")
 if footprint.has_area() and not Shape.contains_rect(contour,footprint,.18):
  node.free();push_error("Outdoor decoration outside contour: "+id);return null
 node.name=id+"_"+str(g.shell.get_child_count());g.shell.add_child(node)
 return node

static func _library(g,id: String,pos: Vector3,angle: float=0) -> Node3D:
 var node: Node3D=Library.instance("library_"+id)
 if node==null:return null
 node.position=pos;node.rotation_degrees.y=angle
 var footprint:=Decor.footprint(node)
 var contour: PackedVector2Array=g.shell.get_meta("floor_contour")
 if footprint.has_area() and not Shape.contains_rect(contour,footprint,.18):
  node.free();push_error("Library decoration outside contour: "+id);return null
 node.name="library_"+id+"_"+str(g.shell.get_child_count());g.shell.add_child(node)
 return node

static func _flower_island(g,c: Vector2,size: Vector2,variant: int=0) -> void:
 var outline:=ellipse(c,size,24)
 _solid(g,outline,.035,.28,Color("c3ceba"),true)
 _solid(g,ellipse(c,size-Vector2.ONE*.14,24),.28,.30,Color("637d72"))
 var b=g._builder(g.shell)
 for n in 25:
  var a: float=n*2.39996+.4*variant
  var radius: float=sqrt(float(n+1)/26)*.78
  var p:=Vector3(c.x+cos(a)*size.x*radius,.33,c.y+sin(a)*size.y*radius)
  b.pillow(Vector3(.55,.23,.47),p+Vector3(.12,.11,0),Color("789887"))
  b.pillow(Vector3(.40,.19,.55),p+Vector3(-.17,.10,.08),Color("89a291"))
  var stem: MeshInstance3D=b.cylinder(.035,.48,p+Vector3(0,.22,0),Color("668b77"))
  stem.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for petal in 5:
   var theta: float=petal*TAU/5
   b.pillow(Vector3(.29,.20,.29),p+Vector3(cos(theta)*.16,.45,sin(theta)*.16),[Color("95afbf"),Color("c7b3b9"),Color("e0d4b0")][(n+variant)%3])
  b.pillow(Vector3(.12,.12,.12),p+Vector3(0,.52,0),Color("e5dab8"))
 _merge_flower_meshes(b)

static func _merge_flower_meshes(builder: Node3D) -> void:
 # Dense flowers retain actual 3D shapes but render once per material, instead
 # of hundreds of separate petal draw calls. Collision stays on the planter.
 var batches: Dictionary={};var sources: Array[MeshInstance3D]=[]
 for child in builder.get_children():
  if not child is MeshInstance3D:continue
  sources.append(child)
  for surface in child.mesh.get_surface_count():
   var mat: Material=child.material_override if child.material_override else child.mesh.surface_get_material(surface)
   var key: int=mat.get_instance_id()
   if not batches.has(key):
    var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    batches[key]={"tool":tool,"material":mat}
   batches[key].tool.append_from(child.mesh,surface,child.transform)
 for key in batches:
  var mesh:=MeshInstance3D.new();mesh.name="MergedFlowerMaterial"
  mesh.mesh=batches[key].tool.commit();mesh.material_override=batches[key].material
  mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  builder.add_child(mesh)
 for source in sources:source.free()

static func _walk(g,points: Array,width: float,tint: Color=Color("c9d8d2")) -> void:
 var b=g._builder(g.shell)
 var protected: Array=g.shell.get_meta("walk_clear")
 for n in range(points.size()-1):
  var a: Vector2=points[n];var end: Vector2=points[n+1];var c: Vector2=(a+end)/2
  protected.append(Rect2(a,Vector2.ZERO).expand(end).grow(width/2+.25))
  var strip=b.box(Vector3(a.distance_to(end),.009,width),Vector3(c.x,.051,c.y),tint);strip.rotation.y=-atan2(end.y-a.y,end.x-a.x)
  # Paving joints follow the actual bent paths.
  for k in range(1,int(a.distance_to(end)/1.4)):
   var p: Vector2=a.lerp(end,k*1.4/a.distance_to(end))
   var joint=b.box(Vector3(.025,.005,width),Vector3(p.x,.058,p.y),Color("a9bbb6"));joint.rotation.y=strip.rotation.y
 for p: Vector2 in points:
  var cap=b.cylinder(width/2,.009,Vector3(p.x,.051,p.y),tint);cap.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

static func _rooms(g,polys: Array[PackedVector2Array],kinds: Array,open_front: Array) -> void:
 for n in polys.size():_surface(g,polys[n],.034,"pale_oak" if n%2==0 else "ivory_tile",Color("cfcbbb"))
 for edge in Packed.segments(polys):
  var a:=Vector3(edge.a.x,0,edge.a.y);var end:=Vector3(edge.end.x,0,edge.end.y)
  var is_door: bool=edge.owners.size()==2
  for opening: Vector2 in open_front:
   if Geometry2D.get_closest_point_to_segment(opening,edge.a,edge.end).distance_to(opening)<.01:is_door=true
  if is_door and a.distance_to(end)>4.4:
   var direction: Vector3=(end-a).normalized();var c: Vector3=(a+end)*.5
   Walls.run(g,kinds[edge.owners[0]],a,c-direction*2)
   Walls.run(g,kinds[edge.owners[0]],c+direction*2,end)
   _beam(g,a,end,2.25,INK)
  else:Walls.run(g,kinds[edge.owners[0]],a,end)

static func _beam(g,a: Vector3,end: Vector3,height: float,tint: Color) -> void:
 var b=g._builder(g.shell);var d: Vector3=end-a;var c: Vector3=(a+end)/2
 var beam=b.box(Vector3(d.length(),.07,.07),c+Vector3(0,height,0),tint);beam.rotation.y=-atan2(d.z,d.x)

static func _pergola(g,c: Vector3,size: Vector2,angle: float=0) -> void:
 var holder:=Node3D.new();holder.name="OpenTimberPergola";holder.position=c;holder.rotation_degrees.y=angle;g.shell.add_child(holder)
 var b=g._builder(holder)
 for side in [-1.0,1.0]:
  for z in [-size.y/2,size.y/2]:
   b.cylinder(.085,2.65,Vector3(side*size.x/2,1.325,z),WOOD)
   g._collision(holder,Vector3(.18,2.7,.18),Vector3(side*size.x/2,1.35,z))
  b.box(Vector3(.14,.16,size.y+.5),Vector3(side*size.x/2,2.60,0),WOOD)
 for n in int(size.y/.6)+1:
  b.box(Vector3(size.x+.55,.09,.11),Vector3(0,2.73,-size.y/2+n*.6),WOOD)

static func _garden(g) -> Array:
 var greenhouse:=poly([[-19,-11],[-15,-14],[-5,-14],[-5,-9],[2,-9],[2,-1],[-19,-1]])
 _rooms(g,[greenhouse],["restaurant_lounge"],[Vector2(-8.5,-1)])
 for n in greenhouse.size():
  var a: Vector2=greenhouse[n];var end: Vector2=greenhouse[(n+1)%greenhouse.size()]
  _beam(g,Vector3(a.x,0,a.y),Vector3(end.x,0,end.y),3.15,Color("73988e"))
  if a.y==-1 and end.y==-1:continue
  var b=g._builder(g.shell);var count: int=maxi(1,int(a.distance_to(end)/2.7))
  for k in count+1:
   var p: Vector2=a.lerp(end,float(k)/count)
   b.box(Vector3(.07,2.12,.07),Vector3(p.x,2.10,p.y),Color("73988e"))
 # Two different roof wings show the L outline while leaving the player visible.
 for x in [-16.0,-11.0,-6.0]:_beam(g,Vector3(x,0,-12.5),Vector3(x,0,-1),3.15,Color("9dbab0"))
 for p in [Vector3(-16,0,-10),Vector3(-7,0,-13),Vector3(-17,0,-5)]:_detailed(g,"restaurant_herb_rack",p)
 _flower_island(g,Vector2(-11,-7),Vector2(3.5,1.2),1)
 _flower_island(g,Vector2(-11,-11.5),Vector2(2.1,.8),0)
 _detailed(g,"restaurant_service_cart",Vector3(-5,0,-5),25)
 _detailed(g,"sculpted_planter",Vector3(-1,0,-6))
 _flower_island(g,Vector2(10,-8),Vector2(5.5,2.5),0)
 _flower_island(g,Vector2(15,1),Vector2(3.6,4.1),1)
 _flower_island(g,Vector2(5,9),Vector2(4.0,2.3),2)
 _walk(g,[Vector2(-17,6),Vector2(-7,3),Vector2(-1,0),Vector2(5,-2),Vector2(10,2),Vector2(12,8)],2.8)
 _walk(g,[Vector2(-7,3),Vector2(-8,-4)],2.5)
 _pergola(g,Vector3(-9,0,9),Vector2(10,5),-12)
 _detailed(g,"restaurant_bistro_set",Vector3(-11,0,9),20)
 _detailed(g,"restaurant_bistro_set",Vector3(-6,0,8),-15)
 _detailed(g,"curved_bench",Vector3(4,0,-6),-50)
 _detailed(g,"curved_bench",Vector3(16.5,0,7),-30)
 _library(g,"tree_cherry",Vector3(-19,0,1))
 _library(g,"tree_birch",Vector3(0,0,14))
 _library(g,"tree_pine",Vector3(18,0,-4))
 _library(g,"bush_berry",Vector3(-19,0,4))
 _library(g,"shrub",Vector3(-17,0,3))
 return [_zone("glass","折角温室",greenhouse),_zone("tea","树下茶庭",poly([[-18,3],[-3,3],[-3,14],[-10,14],[-18,9]])),_zone("beds","弧形花岛",poly([[5,-11],[16,-6],[20,1],[16,9],[5,12],[4,3]]))]

static func _market(g) -> Array:
 var shops: Array[PackedVector2Array]=[
  poly([[-20,-9],[-16,-13],[-6,-13],[-6,-3],[-20,-3]]),
  poly([[-6,-16],[4,-16],[8,-12],[8,-3],[-6,-3]]),
  poly([[8,-12],[17,-12],[21,-6],[21,1],[8,1]])]
 _rooms(g,shops,["restaurant_patisserie","restaurant_bar","restaurant_lounge"],[Vector2(-13,-3),Vector2(1,-3),Vector2(14.5,1)])
 for n in 3:
  var rect:=Packed._rect(shops[n]);var y: float=rect.end.y
  var b=g._builder(g.shell)
  # Sloped striped awnings sit above each shop entrance, not over the walking street.
  for k in 8:
   var awning=b.box(Vector3((rect.size.x-.2)/8,.07,1.4),Vector3(rect.position.x+(k+.5)*rect.size.x/8,2.35,y+.30),Color("8daeb4") if k%2==0 else PAPER)
   awning.rotation.x=.12
 _detailed(g,"restaurant_pastry_display",Vector3(-13,0,-9))
 _detailed(g,"restaurant_pastry_table",Vector3(-17,0,-6),30)
 _detailed(g,"restaurant_pantry_shelf",Vector3(-8,0,-10))
 _detailed(g,"restaurant_coffee_station",Vector3(-2,0,-12))
 _detailed(g,"restaurant_service_cart",Vector3(5,0,-7))
 _detailed(g,"school_open_bookshelf",Vector3(12,0,-9))
 _detailed(g,"school_globe",Vector3(17,0,-5))
 _detailed(g,"market_kiosk",Vector3(14,0,7),-25)
 _detailed(g,"market_kiosk",Vector3(5,0,8),25)
 _walk(g,[Vector2(-18,6),Vector2(-12,2),Vector2(0,2),Vector2(8,4),Vector2(19,4)],3.5)
 _walk(g,[Vector2(0,2),Vector2(-1,10),Vector2(7,13)],3.0)
 var terrace:=poly([[-9,8],[-1,6],[9,8],[16,11],[12,15],[1,16],[-9,13]])
 _surface(g,terrace,.040,"pale_oak",Color("c5c1ae"))
 _detailed(g,"restaurant_bistro_set",Vector3(-6,0,10),30)
 _library(g,"bench",Vector3(6,0,14))
 _detailed(g,"parcel_station",Vector3(-21,0,0),90)
 _library(g,"recycling_bin",Vector3(21,0,-2),-90)
 for p in [Vector3(-18,0,9),Vector3(20,0,8)]:_library(g,"street_lamp",p)
 _library(g,"token_atm",Vector3(-21.5,0,-4),45)
 _library(g,"water_barrel",Vector3(18,0,10))
 _library(g,"supply_crate",Vector3(19.5,0,9))
 _library(g,"safe_floor",Vector3(18,0,-9))
 _library(g,"safe_tall",Vector3(9.5,0,-5),35)
 _library(g,"safe_compact",Vector3(9.7,0,-10))
 _flower_island(g,Vector2(-10,5),Vector2(2.3,1.2),2)
 return [_zone("bakery","晨光面包小铺",shops[0]),_zone("coffee","海风饮品吧",shops[1]),_zone("collect","海洋收藏铺",shops[2]),_zone("terrace","扇形海岸平台",terrace)]

static func _reading(g) -> Array:
 var pavilion:=poly([[-17,-6],[-14,-11],[-5,-12],[1,-9],[3,-4],[1,0],[-17,0]])
 _rooms(g,[pavilion],["school_library"],[Vector2(-8,0)])
 _pergola(g,Vector3(-7,0,-5),Vector2(13,6),0)
 for p in [Vector3(-13,0,-7),Vector3(-7,0,-9),Vector3(-1,0,-6)]:_detailed(g,"school_open_bookshelf",p)
 _detailed(g,"lounge_chair",Vector3(-12,0,-3),-20)
 _detailed(g,"lounge_chair",Vector3(-2,0,-2),25)
 _detailed(g,"floor_lamp",Vector3(-15,0,-2))
 var deck:=poly([[4,-5],[10,-9],[16,-6],[19,0],[15,6],[5,7],[2,2]])
 _surface(g,deck,.042,"pale_oak",Color("c9c8b5"))
 _detailed(g,"school_artist_easel",Vector3(12,0,-3),-35)
 _detailed(g,"school_art_cart",Vector3(16,0,0))
 _detailed(g,"restaurant_bistro_set",Vector3(9,0,3),0)
 _detailed(g,"curved_bench",Vector3(13,0,10),-20)
 _detailed(g,"school_telescope",Vector3(17,0,8),-40)
 _flower_island(g,Vector2(-5,8),Vector2(5.8,2.7),1)
 _flower_island(g,Vector2(8,-11),Vector2(2.0,.7),2)
 _walk(g,[Vector2(-18,5),Vector2(-10,2),Vector2(-5,2),Vector2(1,3),Vector2(5,10)],2.7)
 _walk(g,[Vector2(-8,2),Vector2(-8,-3)],2.5)
 _walk(g,[Vector2(1,3),Vector2(7,-2)],2.8)
 _detailed(g,"curved_bench",Vector3(-12,0,10),10)
 _library(g,"tree_oak",Vector3(-19,0,0))
 _library(g,"tree_birch",Vector3(1,0,12))
 _library(g,"whale_statue",Vector3(8,0,10.6))
 return [_zone("pavilion","弧形阅读书亭",pavilion),_zone("artdeck","海边手作平台",deck),_zone("flower","阅读花庭",poly([[-16,4],[0,4],[4,13],[-6,14],[-6,11],[-16,11]]))]

static func _civic(g) -> Array:
 var stage:=poly([[2,-9],[10,-9],[16,-4],[15,0],[4,1],[-1,-3]])
 _surface(g,stage,.042,"pale_oak",Color("bcbdaa"))
 _pergola(g,Vector3(7,0,-4),Vector2(12,5),12)
 _detailed(g,"school_learning_board",Vector3(8,0,-7))
 _detailed(g,"school_artist_easel",Vector3(13,0,-3),-30)
 _detailed(g,"school_art_cart",Vector3(2,0,-4))
 _flower_island(g,Vector2(-9,-8),Vector2(5.7,3.4),0)
 _flower_island(g,Vector2(10,9),Vector2(6.5,3.6),2)
 _flower_island(g,Vector2(-8,9),Vector2(3.4,1.7),1)
 _walk(g,[Vector2(-20,2),Vector2(-11,0),Vector2(-3,-1),Vector2(3,3),Vector2(9,3),Vector2(18,6)],3.2)
 _walk(g,[Vector2(-3,-1),Vector2(-2,6),Vector2(0,10)],2.7)
 _detailed(g,"restaurant_bistro_set",Vector3(-12,0,4),-20)
 _detailed(g,"curved_bench",Vector3(-5,0,-6),-25)
 _detailed(g,"curved_bench",Vector3(19,0,3),-45)
 _library(g,"bench",Vector3(0,0,12))
 _detailed(g,"mailbox_bank",Vector3(-19,0,-4),90)
 _detailed(g,"sculpted_planter",Vector3(20,0,10))
 _library(g,"tree_oak",Vector3(-18,0,-8))
 _library(g,"tree_birch",Vector3(-3,0,-9))
 _library(g,"tree_cherry",Vector3(-16,0,10))
 _library(g,"tree_pine",Vector3(18,0,12))
 _library(g,"whale_fountain",Vector3(-6,0,4))
 _library(g,"whale_sign",Vector3(-13.5,0,-2))
 return [_zone("stage","社区活动小舞台",stage),_zone("flowerwalk","花岛步道",poly([[-17,-11],[-6,-13],[-6,-8],[-2,-8],[-2,8],[-13,11],[-17,6]])),_zone("rest","蓝湾休息庭",poly([[1,3],[18,2],[21,8],[18,13],[7,15],[1,12]]))]

static func city_gates(g) -> Array:
 var entrances: Array=[]
 for data in [{"target":"reading_court","name":"漂流书庭","pos":Vector3(-47,0,5),"angle":90.0},{"target":"civic_garden","name":"蓝湾公共花园","pos":Vector3(33,0,35),"angle":-90.0}]:
  var holder:=Node3D.new();holder.name="LandscapeGate_"+data.target;holder.position=data.pos;holder.rotation_degrees.y=data.angle;g.shell.add_child(holder)
  var b=g._builder(holder)
  for x in [-2.0,2.0]:
   b.cylinder(.11,2.8,Vector3(x,1.4,0),INK)
   g._collision(holder,Vector3(.25,2.8,.25),Vector3(x,1.4,0))
  b.box(Vector3(4.6,.20,.36),Vector3(0,2.65,0),WOOD)
  b.box(Vector3(3.9,.035,2.6),Vector3(0,.02,0),PAPER)
  g._sign(str(data.name),holder.to_global(Vector3(0,3,0)),24,Color("d6e6df"))
  entrances.append({"target":data.target,"name":data.name,"pos":holder.to_global(Vector3(0,0,.4)),"spawn":holder.to_global(Vector3(0,0,1.8))})
 return entrances
