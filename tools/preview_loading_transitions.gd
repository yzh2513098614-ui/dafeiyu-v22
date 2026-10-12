extends SceneTree
## Focused rendered regression with isolated saves and real doorway input.
const Loading=preload("res://ui/loading_transition.gd")
const OUTPUT="res://预览/加载转场_20261012/"
var checks:=0
var failures:=0
var loader
var game

func _initialize() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)

func settle(frames: int=3) -> void:
 for i in frames:await process_frame

func shot(name: String) -> Image:
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 image.save_png(ProjectSettings.globalize_path(OUTPUT+name+".png"))
 return image

func wait_loading(name: String) -> void:
 var previous:=0.0
 var captured:=false
 var started:=Time.get_ticks_msec()
 var monotonic:=true
 while loader.busy and Time.get_ticks_msec()-started<60000:
  monotonic=monotonic and loader.progress>=previous
  previous=loader.progress
  if not captured and loader.progress>.28 and loader.progress<.95:
   await shot(name);captured=true
  await process_frame
 check(not loader.busy,"loading completes "+name)
 check(monotonic,"progress never decreases "+name)
 check(not paused and not loader.canvas.visible,"input and world resume "+name)
 if loader.busy:quit(1)
 await settle(6)

func key(code: Key) -> void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=true;root.push_input(event,true)
 await process_frame
 event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false;root.push_input(event,true)

func travel(target: String,name: String) -> void:
 game.request_travel(target)
 check(loader.busy and game.transitioning,"world travel shows loader "+target)
 game.request_travel("garden")
 await wait_loading(name)
 check(game.location_id==target and not game.transitioning and not game.changing,"single travel reaches "+target)
 check(game.player.velocity.length()<.01,"player remains still during loading "+target)

func approach_portal(portal: Dictionary) -> bool:
 for radius in [1.8,1.4,1.1,2.15]:
  for side in 8:
   var angle: float=side*TAU/8.0
   var standing: Vector3=portal.pos+Vector3(sin(angle)*radius,0,cos(angle)*radius)
   if not game._collision_point_allowed(standing,false):continue
   game.player.position=standing;game.player.velocity=Vector3.ZERO
   await physics_frame;await physics_frame;await settle(2)
   var selected: Dictionary=game.map_interactions._pick()
   if selected.get("kind")=="portal" and selected.portal.target==portal.target:return true
 return false

func run() -> void:
 for flag in ["--test-session-ui","--test-dialogue","--test-expedition","--test-candy-title"]:
  if not flag in OS.get_cmdline_user_args():push_error("Required isolation flag "+flag);quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.settings_path=OUTPUT+"settings.cfg";prefs.world_save_path=OUTPUT+"world.json"
 prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.day_cycle=false;prefs.starting_place="city";prefs.continue_game=false
 root.size=Vector2i(1280,720)
 loader=Loading.instance(self)
 check(loader.begin("海蓝餐厅 · 1F 整层"),"reference illustration overlay opens")
 await loader.reveal()
 loader.progress=.45;loader.target_progress=.45;await settle(3)
 var a: Image=await shot("01_水波45_A")
 var bounds: Rect2=loader.sheet.get_global_rect()
 var liquid: Control=loader.sheet.get_node("ProgressTrack/AnimatedWater")
 var water_bounds:=liquid.get_global_rect()
 var raster_scale:=Vector2(a.get_size())/root.get_visible_rect().size
 var crop:=Rect2i(Vector2i((water_bounds.position+Vector2(3,3))*raster_scale),Vector2i(water_bounds.size*Vector2(.4,.85)*raster_scale))
 var sample_a:=a.get_region(crop).get_data()
 await create_timer(.25,true,false,true).timeout
 var b: Image=await shot("02_水波45_B")
 check(sample_a!=b.get_region(crop).get_data(),"water and highlights animate at unchanged 45 percent")
 check(loader.percentage.text=="45%","percentage is dynamic and independent of image")
 root.size=Vector2i(1000,750);await settle(4);await shot("03_4比3加载")
 bounds=loader.sheet.get_global_rect()
 check(bounds.position.x>=-.1 and bounds.position.y>=-.1 and bounds.end.x<=root.get_visible_rect().size.x+.1 and bounds.end.y<=root.get_visible_rect().size.y+.1,"complete illustration and progress fit 4:3")
 await loader.finish();root.size=Vector2i(1280,720);await settle()
 var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu;await settle()
 menu._start(false)
 check(loader.busy and paused,"start game activates persistent loader")
 menu._start(false)
 await wait_loading("04_进入游戏")
 game=current_scene
 check(game!=null and game.get("location_id")=="city","title launches selected world")
 if game==null or game.get("location_id")==null:quit(1);return
 check(loader==root.get_node("WhaleLoading"),"loading overlay survives scene replacement")
 await shot("05_街区落点")
 await travel("restaurant_1","06_进入餐厅")
 await shot("07_餐厅落点")
 var door: Dictionary={}
 for portal in game.portals:
  if portal.target=="restaurant_2":door=portal;break
 check(not door.is_empty(),"indoor stairs portal exists")
 if not door.is_empty():
  check(await approach_portal(door),"player can approach interior stairs")
  await key(KEY_E)
  check(loader.busy,"real E stairs input opens loading")
  await key(KEY_E)
  await wait_loading("08_E楼梯换层")
  check(game.location_id=="restaurant_2","E enters requested floor once")
 await travel("city","09_回到街区")
 await travel("tidal_cafe","10_进入咖啡馆")
 await shot("11_咖啡馆落点")
 await travel("pack26_foodhall","12_进入26地图")
 await travel("city","13_离开26地图")
 var count: int=loader.finished_count
 game.request_travel("missing_place");await settle()
 check(not loader.busy and not game.transitioning and loader.finished_count==count,"invalid location leaves game usable")
 game.pause_menu.open();game.pause_menu.return_to_title()
 check(loader.busy,"save and return to title uses loading")
 await wait_loading("14_返回标题")
 check(current_scene.has_method("_start"),"return to title succeeds")
 prefs.continue_game=true;current_scene._start(true)
 await wait_loading("15_继续游戏")
 game=current_scene
 check(game.get("location_id")=="city","continue game restores saved place")
 await shot("16_继续游戏落点")
 print("LOADING_TRANSITIONS: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
