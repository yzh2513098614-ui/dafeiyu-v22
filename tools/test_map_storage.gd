extends SceneTree
## Real city interactions and storage transactions; never uses player saves.
## --test-session-ui --test-dialogue [--verify-containers] [--refresh-container-design]
const OUT="res://预览/大地图容器_20261012/"
var game
var loot
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

func click(control:Control)->void:
 await settle(2)
 var point:=control.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
 var press:=InputEventMouseButton.new();press.position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
 root.push_input(press,true);await process_frame
 var release:=press.duplicate();release.pressed=false;root.push_input(release,true);await settle()

func shot(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await settle(5);RenderingServer.force_draw(false);await process_frame;RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name+".png"))

func approach(chest:Node3D)->bool:
 loot.close()
 # Only choose an actual unoccupied standing point, then exercise production rays.
 for radius in [1.05,1.3,1.48,1.75,2.1,2.3]:
  for side in [0,1,7,2,6,3,5,4]:
   var angle:float=side*TAU/8.0
   var point:Vector3=chest.to_global(Vector3(sin(angle)*radius,0,cos(angle)*radius))
   if not game._collision_point_allowed(point,false):continue
   game.player.global_position=point;game.player.velocity=Vector3.ZERO
   await settle(2)
   if loot._in_range(chest) and loot.nearby==chest:
    var pick:Dictionary=game.map_interactions._pick()
    if pick.get("kind")=="chest" and pick.get("node")==chest:return true
 return false

func open_target(chest:Node3D)->bool:
 if not await approach(chest):return false
 await key(KEY_E)
 if loot.mode!="loot" or loot.current_chest!=chest:print("OPEN_FAIL ",chest.container_id," mode=",loot.mode," position=",game.player.position," range=",loot._in_range(chest)," nearby=",loot.nearby," pick=",game.map_interactions._pick())
 return loot.mode=="loot" and loot.current_chest==chest

func run()->void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-session-ui" in args or not "--test-dialogue" in args:
  push_error("Required: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json"
 prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.day_cycle=false
 prefs.continue_game=false;prefs.starting_place="city"
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 game.set_physics_process(false);game.dialogue_controller.close();loot=game.loot;loot.save_path=OUT+"inventory.json"
 await settle(8)
 check(game.location_id=="city" and prefs.world_save_path.begins_with(OUT) and loot.save_path.begins_with(OUT),"city fixture uses isolated saves")
 if "--verify-containers" in args:
  check(loot.load_state(),"fresh process loads deposited inventory")
  var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"expected.json"))
  check(JSON.parse_string(JSON.stringify(loot.inventory))==expected.inventory,"fresh process restores backpack exactly")
  check(JSON.parse_string(JSON.stringify(loot.stocks))==expected.stocks,"fresh process restores every container exactly")
  game._travel("coldstore");await settle();game._travel("city");await settle()
  check(JSON.parse_string(JSON.stringify(loot.stocks))==expected.stocks,"fresh process travel cannot refill boxes")
  var document=load("res://ui/design/layout_document.gd")
  var native_page:Control=load("res://ui/design/pages/inventory_chest.tscn").instantiate()
  var native_controls:Dictionary={};document.collect(native_page,native_controls)
  check(native_controls.size()>90,"editable native container page loads with real controls");native_page.free()
  check(document.changes("inventory_chest").is_empty(),"new native container baseline matches its editable page")
  finish("reload_checks");return
 # Reset only test state; real inventory was never read.
 loot.inventory={};loot.stocks=loot.INITIAL_STOCK.duplicate(true)
 load("res://district/container_rooms.gd")._wire_loot(game)
 check(loot.chests.size()==38,"all 38 city containers are registered")
 var ids:Dictionary={};var first_id:=""
 for chest in loot.chests.duplicate():
  var id:String=chest.container_id
  check(not ids.has(id),"unique container "+id);ids[id]=true
  var known:bool=loot.stock_total(id)>0
  for item in loot.stocks.get(id,{}):known=known and loot.definitions.has(item)
  check(known,"seeded known items "+id)
  var opened:bool=await open_target(chest)
  check(opened,"walkable standing point and actual E open "+id)
  if opened:
   check(chest.opened and chest.inner.target_open and loot.blocked(),"3D lid and modal agree "+id)
   await key(KEY_ESCAPE)
   check(not loot.blocked() and not chest.opened,"actual Esc closes "+id)
  if first_id=="":first_id=id
 if failures>0:finish("checks");return
 var target:Node3D=loot.chests[0]
 check(await open_target(target),"open storage fixture")
 loot.inventory={"sea_biscuit":6,"first_aid":3,"prompt_pen":2,"whale_letter":1}
 loot._render();await settle()
 await shot("01_打开大地图容器")
 var id:String=target.container_id
 var before_stock:int=int(loot.stocks[id].get("sea_biscuit",0))
 var view=loot.modal.get_child(0)
 await click(view.bag_grid.find_child("BagItem_sea_biscuit",true,false))
 check(loot.take_button.text=="存入容器" and not loot.take_button.disabled,"mouse selects left bag and enables deposit")
 await click(loot.quantity_plus);await click(loot.take_button)
 check(int(loot.inventory.sea_biscuit)==4 and int(loot.stocks[id].sea_biscuit)==before_stock+2,"mouse deposits selected quantity without loss")
 check(loot.modal.get_child(0).inspecting_bag,"deposit keeps the bag selection")
 await shot("02_存入物品与反馈")
 var snapshot_inventory:Dictionary=loot.inventory.duplicate(true);var snapshot_stocks:Dictionary=loot.stocks.duplicate(true)
 var valid_path:String=loot.save_path;loot.save_path=OUT+"missing/fail.json"
 check(not loot.deposit("first_aid",2) and loot.inventory==snapshot_inventory and loot.stocks==snapshot_stocks,"failed deposit save rolls back both sides")
 loot.save_path=valid_path
 check(not loot.deposit("unknown",1) and not loot.deposit("first_aid",0) and not loot.deposit("first_aid",-1) and not loot.deposit("first_aid",99),"invalid deposit IDs and amounts rejected")
 var model=game.character_controller.model
 check(model.apply_item("prompt_pen"),"equip storage fixture tool")
 check(loot.can_store("prompt_pen")==1 and not loot.deposit("prompt_pen",2),"last equipped copy is protected")
 check(loot.deposit("prompt_pen",1) and int(loot.inventory.prompt_pen)==1 and loot.is_equipped("prompt_pen"),"extra equipped copy may be stored")
 check(loot.deposit("whale_letter",1) and int(loot.inventory.whale_letter)==0,"clue can be stored without using it")
 loot._render();await settle();await click(loot.rows.sea_biscuit);await click(loot.take_button)
 check(int(loot.inventory.sea_biscuit)==5 and int(loot.stocks[id].sea_biscuit)==before_stock+1,"mouse takes an item back from right grid")
 var saved_inventory:Dictionary=loot.inventory.duplicate(true);var saved_stocks:Dictionary=loot.stocks.duplicate(true)
 check(loot.load_state() and loot.inventory==saved_inventory and loot.stocks==saved_stocks,"reload retains added kinds and equipment ownership")
 loot.close();game._travel("coldstore");await settle();game._travel("city");await settle()
 check(loot.stocks[id]==saved_stocks[id],"leaving and re-entering city never resets stock")
 target=loot.chests[0];check(target.container_id==id and await open_target(target),"stable ID reopens the same container")
 # Keep empty state distinct from a box that has never been initialized.
 loot.stocks[id]={};loot._render();await settle()
 check(loot.save_state() and loot.load_state() and loot.stocks[id].is_empty(),"empty dictionary persists without refill")
 loot.close();game._travel("coldstore");await settle();game._travel("city");await settle()
 check(loot.stocks[id].is_empty(),"empty city box stays empty after travel")
 target=loot.chests[0];check(await open_target(target),"empty box still opens for storage")
 loot.inventory.sea_biscuit=9999;loot.stocks[id]={"sea_biscuit":9998};loot._render()
 check(loot.can_store("sea_biscuit")==1 and not loot.deposit("sea_biscuit",2),"container stack limit rejects overflow")
 check(loot.deposit("sea_biscuit",1) and loot.stocks[id].sea_biscuit==9999 and loot.can_store("sea_biscuit")==0,"container stack reaches exactly 9999")
 var fake:Array=[]
 loot.stocks[id]={}
 for i in 64:
  var fixture_id:="storage_fixture_"+str(i);fake.append(fixture_id)
  loot.definitions[fixture_id]=loot.definitions.sea_biscuit.duplicate(true);loot.stocks[id][fixture_id]=1
 check(loot.can_store("first_aid")==0 and not loot.deposit("first_aid",1),"full 64-kind container blocks a new kind")
 loot.inventory[fake[0]]=2
 check(loot.deposit(fake[0],1),"full container accepts an existing stack")
 loot.inventory.erase(fake[0]);loot.stocks[id]={}
 for fixture_id in fake:loot.definitions.erase(fixture_id)
 # A physical barrier, including one close to the box, blocks both directions.
 var solid:=StaticBody3D.new();var hit:=CollisionShape3D.new();var shape:=BoxShape3D.new()
 shape.size=Vector3(.10,2.0,3.0);hit.shape=shape;solid.add_child(hit)
 solid.position=(target.global_position+game.player.global_position)*.5
 var direction:Vector3=target.global_position-game.player.global_position
 solid.rotation.y=atan2(-direction.z,direction.x);game.world.add_child(solid);await settle()
 check(not loot._in_range(target) and not loot.deposit("first_aid",1) and not loot.transfer("sea_biscuit",1),"wall blocks deposits and withdrawals")
 solid.free();await settle()
 game.player.position=Vector3.ZERO;await settle()
 check(not loot.deposit("first_aid",1) and not loot.transfer_all(),"out-of-range actions cannot mutate inventory")
 check(await open_target(target),"storage reopens after returning")
 loot.inventory={"sea_biscuit":6,"first_aid":3,"prompt_pen":1,"sea_shell":7}
 loot.stocks[id]={};loot._render();await settle()
 view=loot.modal.get_child(0);await click(view.bag_grid.find_child("BagItem_sea_shell",true,false));await click(loot.all_button)
 check(loot.stocks[id].sea_shell==7 and loot.inventory.sea_shell==0,"mouse stores the entire selected stack")
 for dimensions in [Vector2i(1000,750),Vector2i(1280,720)]:
  root.size=dimensions;await settle()
  for control in [loot.quantity_plus,loot.quantity_minus,loot.take_button,loot.all_button,loot.take_all_button]:
   check(loot.modal.get_global_rect().encloses(control.get_global_rect()),"storage action stays in modal "+str(dimensions)+" "+control.name)
  await shot("03_双向容器_"+str(dimensions.x)+"x"+str(dimensions.y))
 # Verify old schemas without touching the original path.
 loot.close();var final_inventory:Dictionary=loot.inventory.duplicate(true);var final_stocks:Dictionary=loot.stocks.duplicate(true)
 loot.save_path=OUT+"legacy.json"
 for version in [1,2]:
  var file:=FileAccess.open(loot.save_path,FileAccess.WRITE)
  file.store_string(JSON.stringify({"version":version,"inventory":{"first_aid":1},"stocks":loot.INITIAL_STOCK}));file.close()
  check(loot.load_state() and loot.inventory.first_aid==1,"legacy v"+str(version)+" loads")
 loot.inventory=final_inventory;loot.stocks=final_stocks;loot.save_path=valid_path
 # Ordinary fixed-stock supply chests must also accept extra counts and new kinds.
 game._travel("apt_2");await settle()
 check(await open_target(loot.chests[0]),"ordinary supply chest also opens for storage")
 loot.inventory.token_cracker=19;loot.inventory.sea_shell=2
 check(loot.deposit("token_cracker",19) and loot.stocks.bedroom_supply.token_cracker==27,"fixed supply chest accepts more than its original quantity")
 check(loot.deposit("sea_shell",2),"fixed supply chest accepts a new item kind")
 check(loot.load_state() and loot.stocks.bedroom_supply.token_cracker==27 and loot.stocks.bedroom_supply.sea_shell==2,"v3 reload preserves extra quantities and new kinds in fixed chests")
 loot.close();loot.inventory=final_inventory;loot.stocks=final_stocks
 game._travel("city");await settle()
 check(loot.save_state(),"final deposit state committed for separate process")
 var expected_file:=FileAccess.open(OUT+"expected.json",FileAccess.WRITE)
 expected_file.store_string(JSON.stringify({"inventory":loot.inventory,"stocks":loot.stocks}));expected_file.close()
 if "--refresh-container-design" in args:
  if FileAccess.get_file_as_string("res://ui/design/pages/inventory_chest.tscn")!=FileAccess.get_file_as_string("res://ui/design/baselines/inventory_chest.tscn"):
   check(false,"refusing to overwrite a customized container design");finish("checks");return
  target=loot.chests[0];await open_target(target)
  var document=load("res://ui/design/layout_document.gd")
  var capture:Dictionary=document.capture("inventory_chest",loot.modal,"背包 · 容器存取")
  check(capture.error==OK,"native container design scene captured")
  if capture.error==OK:
   var page:=FileAccess.open("res://ui/design/pages/inventory_chest.tscn",FileAccess.WRITE)
   page.store_string(FileAccess.get_file_as_string("res://ui/design/baselines/inventory_chest.tscn"));page.close()
   var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
   for entry in catalog:
    if entry.id=="inventory_chest":entry.controls=capture.controls;entry.title="背包 · 容器存取"
   var file:=FileAccess.open("res://ui/design/catalog.json",FileAccess.WRITE);file.store_string(JSON.stringify(catalog," ").replace('"error": 0,','"error": 0.0,')+"\n");file.close()
 finish("checks")

func finish(report_name:String)->void:
 var file:=FileAccess.open(OUT+report_name+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results},"  "));file.close()
 print("MAP_STORAGE_CHECKS ",checks," FAILURES ",failures)
 game.queue_free();await process_frame;await process_frame;quit(1 if failures>0 else 0)
