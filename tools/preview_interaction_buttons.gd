extends SceneTree
## Compact world prompts, real mouse/E actions and editable pages; isolated saves.
const OUT="res://预览/地图交互小按钮_20261012/"
const Document=preload("res://ui/design/layout_document.gd")
var game
var checks:=0
var failures:=0
var results:Array=[]

func _initialize()->void:
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
  DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(ok:bool,message:String)->void:
 checks+=1;results.append({"ok":ok,"check":message})
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)

func settle(frames:int=4)->void:
 for i in frames:await physics_frame;await process_frame

func key(code:Key)->void:
 var press:=InputEventKey.new();press.keycode=code;press.physical_keycode=code;press.pressed=true
 root.push_input(press,true);await process_frame
 var release:=press.duplicate();release.pressed=false;root.push_input(release,true);await settle()

func click(button:Button,mouse_button:MouseButton=MOUSE_BUTTON_LEFT)->void:
 var point:=button.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
 var press:=InputEventMouseButton.new();press.position=point;press.button_index=mouse_button;press.pressed=true
 root.push_input(press,true);await process_frame
 var release:=press.duplicate();release.pressed=false;root.push_input(release,true);await settle()
 motion.position=Vector2.ZERO;root.push_input(motion,true)

func approach(point:Vector3,kind:String,node:Node=null)->Dictionary:
 # Keep away from the swept door leaf so the existing clearance guard can close it.
 var radii:Array=[2.15,1.8,1.4,1.1] if kind in ["door","portal"] else [1.1,1.4,1.8,2.15]
 for radius in radii:
  for side in [0,1,7,2,6,3,5,4]:
   var angle:float=side*TAU/8.0
   var standing:=point+Vector3(sin(angle)*radius,0,cos(angle)*radius)
   if not game._collision_point_allowed(standing,false):continue
   game.player.global_position=standing;game.player.velocity=Vector3.ZERO
   game.view_center=point;game.view_size=13;game.camera.size=13;game._camera()
   await settle(2)
   var pick:Dictionary=game.map_interactions._pick()
   if pick.get("kind")==kind and (node==null or pick.get("node")==node):return pick
 return {}

func check_prompt(label:String)->void:
 var map=game.map_interactions
 check(map.root.get_child_count()==1 and map.card is Button and map.card.get_child_count()==0,label+" has one button without a panel or labels")
 check(map.card.visible and map.card.size.x<=240 and map.card.size.y<=40,label+" displays a compact action")
 check(not game.loot.prompt.visible and not game.destination_hint.visible,label+" hides duplicate legacy prompts")
 check(root.get_visible_rect().encloses(map.card.get_global_rect()),label+" stays within the viewport")

func shot(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await settle(10);RenderingServer.force_draw(false);await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name+".png"))

func refresh(id:String,target:Control,title:String,excluded:Array=[])->void:
 var filename:="res://ui/design/pages/"+id+".tscn"
 var baseline:="res://ui/design/baselines/"+id+".tscn"
 if FileAccess.get_file_as_string(filename)!=FileAccess.get_file_as_string(baseline):
  check(false,"refusing to overwrite customized page "+id);return
 var capture:Dictionary=Document.capture(id,target,title,excluded)
 check(capture.error==OK,"capture editable small-button page "+id)
 if capture.error!=OK:return
 var page:=FileAccess.open(filename,FileAccess.WRITE);page.store_string(FileAccess.get_file_as_string(baseline));page.close()
 var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
 for entry in catalog:
  entry.controls=int(entry.controls)
  if entry.id==id:entry.controls=capture.controls;entry.title=title
 var file:=FileAccess.open("res://ui/design/catalog.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(catalog," ").replace('"error": 0,','"error": 0.0,')+"\n");file.close()

func run()->void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-session-ui" in args or not "--test-dialogue" in args or not "--test-expedition" in args:
  push_error("Required: --test-session-ui --test-dialogue --test-expedition");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json"
 prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.day_cycle=false
 prefs.continue_game=false;prefs.starting_place="city"
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 game.set_physics_process(false);game.dialogue_controller.close();game.loot.save_path=OUT+"inventory.json"
 await settle(6)
 var maps_seen:Array=[]
 for location in ["city","restaurant_1","restaurant_2","apt_2","coldstore","tidal_cafe","story_harbor","pack26_library"]:
  if game.location_id!=location:game._travel(location)
  await settle(5);maps_seen.append(location)
  var target:Dictionary={}
  if location in ["city","apt_2","coldstore"]:
   for chest in game.loot.chests:
    target=await approach(chest.global_position,"chest",chest)
    if not target.is_empty():break
  elif location in ["restaurant_1","restaurant_2"]:
   for door in get_nodes_in_group("map_interactive_doors"):
    if not game.is_ancestor_of(door):continue
    target=await approach(door.global_position,"door",door)
    if not target.is_empty():break
  elif location=="pack26_library":
   game.pack26_controller.save_path=OUT+"pack26.json"
   for marker in game.pack26_controller.level.get_node("Interactions").get_children():
    target=await approach(marker.global_position,"marker",marker)
    if not target.is_empty():break
  else:
   for object in game.world.get_children():
    if object.has_method("map_action"):
     target=await approach(object.global_position,"object",object)
     if not target.is_empty():break
  check(not target.is_empty(),location+" reachable real interaction")
  if target.is_empty():continue
  check_prompt(location)
  await shot(location+"_小按钮")
  if location=="city":
   await click(game.map_interactions.primary)
   check(game.loot.mode=="loot" and game.loot.current_chest==target.node,"real mouse opens the chosen storage container")
   check(not game.map_interactions.card.visible,"proximity button hides while inventory is open")
   await key(KEY_ESCAPE)
   check(game.map_interactions.card.visible,"Esc restores the small proximity button")
   game.player.global_position=Vector3(0,0,0);await settle()
   check(not game.map_interactions.card.visible,"walking away hides the small button")
  if location=="restaurant_1":
   var door=target.node;var opened:bool=door.opened
   await click(game.map_interactions.primary)
   check(door.opened!=opened,"real mouse toggles the restaurant door")
   await key(KEY_E)
   check(door.opened==opened,"E uses the same door action as the button")
   for dimensions in [Vector2i(1280,720),Vector2i(800,600)]:
    root.size=dimensions;await settle();check_prompt("door "+str(dimensions));await shot("餐厅门_"+str(dimensions.x)+"x"+str(dimensions.y))
   root.size=Vector2i(1000,750)
  if location=="apt_2":
   check(game.loot.prompt is Button and game.loot.prompt.get_child_count()==0 and game.destination_hint is Button,"legacy container and portal prompts are also buttons")
  if location=="tidal_cafe":
   var object=target.node;var before:bool=object.opened
   await click(game.map_interactions.primary)
   check(object.opened!=before or bool(object.get_meta("map_busy",false)),"compact facility button still activates its model")
 # Portal routes and the newer maps use the same compact renderer.
 game._travel("city");await settle()
 var entrance:Dictionary={}
 for portal:Dictionary in game.portals:
  if not is_instance_valid(portal.get("door")):continue
  entrance=await approach(portal.pos,"portal")
  if not entrance.is_empty():break
 check(not entrance.is_empty(),"real entrance door has a compact portal button")
 if not entrance.is_empty():
  var door=entrance.portal.door;var before:bool=door.opened
  await click(game.map_interactions.primary,MOUSE_BUTTON_RIGHT)
  check(door.opened!=before,"right click retains the entrance door's alternate action")
  await settle(45)
  await click(game.map_interactions.primary,MOUSE_BUTTON_RIGHT)
  check(door.opened==before,"single entrance button can both open and close the door")
 game._travel("restaurant_1");await settle()
 for route in ["stairs","elevator","entrance"]:
  var found:=false
  for portal:Dictionary in game.portals:
   if str(portal.route)!=route:continue
   found=true;game.map_interactions._render({"kind":"portal","portal":portal})
   check(game.map_interactions.primary.size.x<=240 and game.map_interactions.primary.size.y<=40,route+" uses the same compact button")
   break
  if route=="stairs":check(found,"restaurant has a real stair route")
 if "--refresh-compact-design" in args:
  game.map_interactions.clear();game.map_interactions.primary.text="E 开门"
  game.map_interactions.primary.position=Vector2(630,400);game.map_interactions.card.show()
  refresh("world_interaction",game.map_interactions.root,"附近互动 · 小按钮")
  game.loot.prompt.show();game.loot.prompt.position=Vector2(630,460)
  refresh("world_loot_prompt",game.loot.canvas,"背包入口与容器小按钮",[game.loot.modal_shade])
  game.destination_hint.position=Vector2(630,520)
  refresh("world_navigation",game.district_canvas,"地点与导览入口",[game.map_panel])
 for id in ["world_interaction","world_loot_prompt","world_navigation"]:
  var page:Control=load("res://ui/design/pages/"+id+".tscn").instantiate()
  check(page!=null,"native editable page loads "+id);page.free()
 var file:=FileAccess.open(OUT+"checks.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"maps":maps_seen,"results":results},"  "));file.close()
 print("COMPACT_INTERACTION_CHECKS ",checks," FAILURES ",failures)
 game.queue_free();await process_frame;await process_frame;quit(1 if failures>0 else 0)
