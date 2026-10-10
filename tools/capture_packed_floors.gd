extends SceneTree
const Shape=preload("res://district/space_shape.gd")
const Floor=preload("res://district/whole_floor.gd")
const OUT="res://预览/餐厅学校医院_3D_v22/"
var failures:=0
var rooms:=0
var floors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:print("PASS ",label)
 else:failures+=1;push_error("FAIL "+label)
func area(poly: PackedVector2Array) -> float:
 var total:=0.0
 for n in poly.size():total+=poly[n].cross(poly[(n+1)%poly.size()])*.5
 return absf(total)
func hide_canvas(node: Node) -> void:
 if node is CanvasLayer:node.visible=false
 for child in node.get_children():hide_canvas(child)
func settle() -> void:
 for n in 8:await process_frame
 for n in 2:await physics_frame
func picture(game,id: String) -> void:
 game.overview_mode=false;game.view_center=Vector3.ZERO;game.view_size=44;game.camera.size=44;game._camera()
 await settle();await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+id+"_房间嵌合整层.png")==OK,id+" screenshot")
func audit(game,id: String) -> void:
 floors+=1;rooms+=game.room_zones.size()
 check(game.shell.get_meta("floor_layout","")=="interlocking_rooms",id+" uses shared-wall rooms without hallway spine")
 var contours: Array=game.shell.get_meta("floor_contours",[])
 check(contours.size()==1 and contours[0].size()>8,id+" continuous irregular exterior")
 var total:=0.0
 for i in game.room_zones.size():
  var zone: Dictionary=game.room_zones[i];total+=area(zone.polygon)
  check(zone.doors.size()>0,id+" "+str(zone.kind)+" direct neighboring-room doorway")
  for j in range(i+1,game.room_zones.size()):
   var overlap:=0.0
   for poly in Geometry2D.intersect_polygons(zone.polygon,game.room_zones[j].polygon):overlap+=area(poly)
   check(overlap<.01,id+" room polygons never overlap physically")
 if contours.size()==1:check(absf(total-area(contours[0]))<.03,id+" slab equals rooms with no invented corridor floor")
 var edges: Array=game.shell.get_meta("room_connections",[])
 var reached: Dictionary={0:true};var changed:=true
 while changed:
  changed=false
  for edge in edges:
   if reached.has(edge.owners[0]) or reached.has(edge.owners[1]):
    for owner in edge.owners:
     if not reached.has(owner):reached[owner]=true;changed=true
 check(reached.size()==6,id+" every room connects through adjacent rooms")
 for edge in edges:
  var center: Vector2=(edge.a+edge.end)*.5
  var tangent: Vector2=(edge.end-edge.a).normalized();var normal:=Vector2(-tangent.y,tangent.x)
  var ray:=PhysicsRayQueryParameters3D.create(Vector3(center.x-normal.x*.8,.46,center.y-normal.y*.8),Vector3(center.x+normal.x*.8,.46,center.y+normal.y*.8))
  ray.exclude=[game.player.get_rid()]
  check(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),id+" shared-wall doorway physically open")
 for node in game.shell.get_children():
  if not node.has_meta("wall_start"):continue
  var a: Vector3=node.get_meta("wall_start");var end: Vector3=node.get_meta("wall_end");var length: float=a.distance_to(end)
  check(node.to_global(Vector3(-length/2,0,0)).distance_to(a)<.002 and node.to_global(Vector3(length/2,0,0)).distance_to(end)<.002,id+" wall and collision rotate along true contour")
 for item in game.items:
  if not is_instance_valid(item) or item.position.y>.3:continue
  var footprint: Rect2=Floor._footprint(item)
  if not footprint.has_area():continue
  var inside:=false
  for zone in game.room_zones:
   if Shape.contains_rect(zone.polygon,footprint,.08):inside=true;break
  check(inside,id+" furniture on actual room floor: "+str(item.module_id))
 check_navigation(game,id)
func check_navigation(game,id: String) -> void:
 var step:=.45
 var bounds:=Rect2(game.room_zones[0].polygon[0],Vector2.ZERO)
 for zone in game.room_zones:
  for point in zone.polygon:bounds=bounds.expand(point)
 bounds=bounds.grow(.5)
 var origin: Vector2=bounds.position
 var probe:=SphereShape3D.new();probe.radius=.20
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=probe;query.exclude=[game.player.get_rid()]
 var free: Dictionary={};var per_room: Array[Dictionary]=[]
 for n in 6:per_room.append({})
 var root_cell:=Vector2i.ZERO;var best:=INF
 for z in int(ceil(bounds.size.y/step))+1:
  for x in int(ceil(bounds.size.x/step))+1:
   var point: Vector2=origin+Vector2(x,z)*step;var belongs: int=-1
   for i in game.room_zones.size():
    var zone: Dictionary=game.room_zones[i]
    if Geometry2D.is_point_in_polygon(point,zone.polygon):belongs=i;break
   if belongs<0:continue
   query.transform=Transform3D(Basis.IDENTITY,Vector3(point.x,.48,point.y))
   if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
   var cell:=Vector2i(x,z);free[cell]=point;per_room[belongs][cell]=true
   var distance: float=point.distance_to(Vector2(game.player.position.x,game.player.position.z))
   if distance<best:best=distance;root_cell=cell
 check(best<.7,id+" spawn has reachable floor")
 var queue: Array[Vector2i]=[root_cell];var visited: Dictionary={root_cell:true};var cursor:=0
 while cursor<queue.size():
  var cell: Vector2i=queue[cursor];cursor+=1
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=cell+direction
   if free.has(next) and not visited.has(next):visited[next]=true;queue.append(next)
 for n in 6:
  var reached:=0
  for cell in per_room[n]:
   if visited.has(cell):reached+=1
  var ratio: float=float(reached)/maxi(1,per_room[n].size())
  if ratio<.98:
   var isolated: Array=[]
   for cell in per_room[n]:
    if not visited.has(cell):isolated.append(free[cell])
   print("ISOLATED ",id," ",game.room_zones[n].kind," ",isolated)
  check(ratio>=.98,id+" "+str(game.room_zones[n].kind)+" navigable from entrance "+str(snappedf(ratio*100,.1))+"%")
 for portal in game.portals:
  var nearest:=INF
  for cell in visited:nearest=minf(nearest,free.get(cell,Vector2.INF).distance_to(Vector2(portal.pos.x,portal.pos.z)))
  check(nearest<.65,id+" elevator/stairs reachable: "+str(portal.target))
func run() -> void:
 var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="city";prefs.values.fullscreen=false;prefs.apply_window()
 root.size=Vector2i(1600,1000)
 var game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await settle();game.dialogue_controller.close();game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);hide_canvas(game)
 var ids: Array[String]=[]
 for id: String in game.locations:
  if game.locations[id].type=="floor":ids.append(id)
 for id in ids:
  var args: PackedStringArray=OS.get_cmdline_user_args()
  if not args.is_empty() and not ("--only="+id) in args:continue
  game._travel(id);await settle();audit(game,id)
  if id in ["apt_1","apt_2","school_1","hospital_1","restaurant_1","music_2","community_1"]:await picture(game,id)
 if OS.get_cmdline_user_args().is_empty():
  game.room_edits["apt_1"]={"items":[{"id":"sofa_cream","pos":[-16,0,-13],"angle":0},{"id":"v18_greenhouse_shelf","pos":[23,0,17],"angle":0}],"layout":"legacy"}
  game._travel("apt_1");await settle()
  check(game.room_edits.apt_1.layout=="packed_rooms_v2" and game.room_edits.apt_1.legacy_layout_items.size()==2,"old hallway furniture records preserved during migration")
  var migrated:=false
  for item in game.items:
   if item.module_id=="v18_greenhouse_shelf":migrated=true
  check(migrated,"extra saved furniture placed on available new room floor")
  check_navigation(game,"apt_1_migrated")
  var saved_spawn: Vector3=game.player.position
  var cutout:=Vector2(-23.0,17.0)
  game.player.position=Vector3(cutout.x,0,cutout.y);game._refresh_zone()
  check(game.zone_id=="","room labels exclude exterior cutouts")
  game.player.position=saved_spawn
 print("PACKED FLOORS ",floors," ROOMS ",rooms," FAILURES ",failures)
 quit(0 if failures==0 else 1)
