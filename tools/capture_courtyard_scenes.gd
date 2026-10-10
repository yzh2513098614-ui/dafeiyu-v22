extends SceneTree
const Shape=preload("res://district/space_shape.gd")
const Decor=preload("res://district/decor_library.gd")
const OUT="res://预览/餐厅学校医院_3D_v22/"
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if ok:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)
func settle() -> void:
 for n in 8:await process_frame
 for n in 3:await physics_frame
func hide_canvas(node: Node) -> void:
 if node is CanvasLayer:node.visible=false
 for child in node.get_children():hide_canvas(child)
func navigation(game,id: String) -> void:
 var poly: PackedVector2Array=game.shell.get_meta("floor_contour")
 var rect: Rect2=preload("res://district/packed_floor.gd")._rect(poly).grow(.3)
 var step:=.4;var query:=PhysicsShapeQueryParameters3D.new()
 var sphere:=SphereShape3D.new();sphere.radius=.21;query.shape=sphere;query.exclude=[game.player.get_rid()]
 var free: Dictionary={};var nearest:=INF;var root_cell:=Vector2i.ZERO
 for z in int(ceil(rect.size.y/step))+1:
  for x in int(ceil(rect.size.x/step))+1:
   var point: Vector2=rect.position+Vector2(x,z)*step
   if not Geometry2D.is_point_in_polygon(point,poly):continue
   query.transform=Transform3D(Basis.IDENTITY,Vector3(point.x,.48,point.y))
   if not game.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
   var cell:=Vector2i(x,z);free[cell]=point
   var distance: float=point.distance_to(Vector2(game.player.position.x,game.player.position.z))
   if distance<nearest:nearest=distance;root_cell=cell
 check(nearest<.5,id+" safe player spawn")
 var visited: Dictionary={root_cell:true};var queue: Array[Vector2i]=[root_cell];var cursor:=0
 while cursor<queue.size():
  var cell: Vector2i=queue[cursor];cursor+=1
  for shift in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next: Vector2i=cell+shift
   if free.has(next) and not visited.has(next):visited[next]=true;queue.append(next)
 var ratio: float=float(visited.size())/maxi(1,free.size())
 check(ratio>=.98,id+" connected usable ground "+str(snappedf(ratio*100,.1))+"%")
 for zone in game.room_zones:
  var found:=false
  for cell in visited:
   if Geometry2D.is_point_in_polygon(free[cell],zone.polygon):found=true;break
  check(found,id+" region accessible: "+str(zone.name))
 for portal in game.portals:
  var best:=INF
  for cell in visited:best=minf(best,free[cell].distance_to(Vector2(portal.pos.x,portal.pos.z)))
  check(best<.55,id+" street exit reachable")
 for node in game.shell.get_children():
  if node.has_meta("decor_id") or node.has_meta("library_id"):
   check(Shape.contains_rect(poly,Decor.footprint(node),.12),id+" detailed prop stays on real ground: "+str(node.get_meta("decor_id",node.get_meta("library_id",""))))
  if node.has_meta("boundary_start"):
   var a: Vector2=node.get_meta("boundary_start");var end: Vector2=node.get_meta("boundary_end");var length: float=a.distance_to(end)
   check(node.to_global(Vector3(-length/2,0,0)).distance_to(Vector3(a.x,0,a.y))<.002 and node.to_global(Vector3(length/2,0,0)).distance_to(Vector3(end.x,0,end.y))<.002,id+" boundary physics follows irregular rim")
 # Updating an old courtyard cannot load its obsolete furniture coordinates.
 check(game.shell.get_meta("floor_layout","")=="landscape_courtyard",id+" no old rectangular floor builder")
func run() -> void:
 var prefs=root.get_node("HarborPrefs");prefs.continue_game=false;prefs.starting_place="city";prefs.values.fullscreen=false;prefs.apply_window()
 root.size=Vector2i(1600,1000)
 var game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await settle();game.dialogue_controller.close();game.set_process(false);game.set_physics_process(false);game.set_process_unhandled_input(false);hide_canvas(game)
 for id in ["garden","market","reading_court","civic_garden"]:
  game._travel(id);await settle();navigation(game,id)
  game.overview_mode=false;game.view_center=Vector3.ZERO;game.view_size=46;game.camera.size=46;game._camera()
  await settle();await RenderingServer.frame_post_draw
  check(root.get_texture().get_image().save_png(OUT+id+"_庭院重做.png")==OK,id+" actual game screenshot")
 game._travel("city");await settle()
 check(not game.shell.has_meta("layout_revision") and not game.shell.has_meta("guide_anchor"),"courtyard metadata cannot leak into city travel")
 for id in ["reading_court","civic_garden"]:
  var found:=false
  for portal in game.portals:
   if portal.target!=id:continue
   found=true
   var ray:=PhysicsRayQueryParameters3D.create(portal.pos+Vector3(0,.48,0),portal.spawn+Vector3(0,.48,0));ray.exclude=[game.player.get_rid()]
   check(game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),id+" physical city gateway clear")
  check(found,id+" real city entrance registered")
  check(game.locations.city.links.has(id),id+" guide map destination registered")
 game.room_edits["garden"]={"items":[{"id":"chair_white","pos":[24,0,18],"angle":0}],"layout":"legacy","legacy_layout_items":[{"id":"basket","pos":[30,0,20],"angle":0}]}
 game._travel("garden");await settle()
 check(game.room_edits.garden.layout=="courtyards_v2" and game.room_edits.garden.legacy_layout_items.size()==2,"old courtyard furniture history preserved and migrated")
 var restored:=false
 for item in game.items:
  if item.module_id=="chair_white":restored=true
 check(restored,"user's additional saved chair relocated onto new courtyard")
 navigation(game,"garden_migrated")
 print("COURTYARD SCENES 4 FAILURES ",failures)
 quit(0 if failures==0 else 1)
