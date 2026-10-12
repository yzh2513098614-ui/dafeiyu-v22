extends Node
## Native campus geometry with the game's character, camera, clock and rendering.
const SCENE="res://wuming_campus/scenes/world/campus.tscn"
const Style=preload("res://ui/whale_skin.gd")
const Fit=preload("res://ui/ui_fit.gd")
const STOPS=[["南门与入口广场",[707,2305]],["照片教学楼",[842,1946]],["独立钟楼",[722,1837]],["弘医楼双塔",[710,2270]],["图书馆与水景",[760,1250]],["B区生活与体育",[650,1080]],["C区宿舍与体育",[1011,578]]]
var game
var level: Node3D
var packed: PackedScene
var layout: Dictionary
var controls: Panel
var selector: OptionButton
var spawn: Vector3
var relocating:=false

func configure(owner_game) -> void:
 game=owner_game
 layout=JSON.parse_string(FileAccess.get_file_as_string("res://wuming_campus/data/campus_layout.json"))
 controls=Style.panel(game.district_canvas,Vector2(1098,366),Vector2(302,162),"paper")
 Fit.pin_right(controls,302,48,366,162)
 Style.label(controls,"武鸣校区 · 地标导览",Vector2(13,10),Vector2(276,30),21)
 selector=OptionButton.new();selector.position=Vector2(13,46);selector.size=Vector2(276,43)
 for stop in STOPS:selector.add_item(stop[0])
 selector.item_selected.connect(visit_stop);controls.add_child(selector)
 var back: Button=game._button("返回鲸落街区",Vector2(13,102),Vector2(276,43),controls,func():game.request_travel("city"))
 back.add_theme_font_size_override("font_size",18);controls.hide()

func is_active() -> bool:return is_instance_valid(level) and game.location_id=="wuming_campus"

func prepare() -> void:
 if packed:return
 ResourceLoader.load_threaded_request(SCENE,"PackedScene")
 var loader=preload("res://ui/loading_transition.gd").instance(get_tree())
 while ResourceLoader.load_threaded_get_status(SCENE)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
  var amount: Array=[]
  ResourceLoader.load_threaded_get_status(SCENE,amount)
  loader.target_progress=maxf(loader.target_progress,.28+.26*float(amount[0] if not amount.is_empty() else 0))
  loader.stage.text="读取武鸣校区的建筑与景观"
  await get_tree().process_frame
 packed=ResourceLoader.load_threaded_get(SCENE)

func build() -> Dictionary:
 if not packed:packed=load(SCENE)
 level=packed.instantiate();level.set_script(null)
 for name in ["WorldEnvironment","AfternoonSun","IsometricCamera","CampusWalker"]:level.get_node(name).free()
 game.world.add_child(level)
 # The imported viewer's lights and camera are removed before entering the tree.
 # Atmosphere.rebuild applies the same materials and light rig as other maps.
 for building in level.get_node("Buildings").get_children():
  if building.has_node("NameLabel"):building.get_node("NameLabel").hide()
 game.player.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED;game.player.collision_layer=4;game.player.collision_mask=3
 game.player.floor_snap_length=.35;game.player.floor_max_angle=deg_to_rad(48);game.player.floor_constant_speed=true
 game._configure_character_collision(true)
 spawn=road_point(wp(STOPS[0][1]))+Vector3(0,.08,0)
 selector.select(0);controls.show()
 var zones: Array=[]
 for building in layout.buildings:
  var center:=wp(building.map_center)
  var dimensions:=Vector2(float(building.map_size[0]),float(building.map_size[1]))/float(layout.map.working_pixels_per_metre)
  zones.append({"id":building.id,"name":building.name,"rect":Rect2(Vector2(center.x,center.z)-dimensions*.5-Vector2.ONE*8,dimensions+Vector2.ONE*16),"center":center})
 return {"bounds":Vector2(1800,2600),"spawn":spawn,"exit":spawn+Vector3(3,0,0),"zones":zones,"camera_size":2400.0}

func wp(point: Array) -> Vector3:
 return Vector3((float(point[0])-750)/float(layout.map.working_pixels_per_metre),0,(float(point[1])-1400)/float(layout.map.working_pixels_per_metre))

func road_point(point: Vector3) -> Vector3:
 var result:=wp(STOPS[0][1]);var distance:=INF
 for road in layout.roads:
  if road.kind=="public_road":continue
  for i in road.points.size()-1:
   var a:=wp(road.points[i]);var b:=wp(road.points[i+1])
   var p:=a+(b-a)*clampf((point-a).dot(b-a)/(b-a).length_squared(),0,1)
   var d:=p.distance_squared_to(point)
   if d<distance:distance=d;result=p
 return result

func visit_stop(index: int) -> void:
 if not is_active() or relocating or game.transitioning:return
 var loader=preload("res://ui/loading_transition.gd").instance(get_tree())
 if not loader.begin(str(STOPS[index][0])):return
 relocating=true
 await loader.reveal();await loader.checkpoint(.45,"准备校园地标与人物落点")
 game.player.position=road_point(wp(STOPS[index][1]))+Vector3(0,.08,0);game.player.velocity=Vector3.ZERO
 game._queue_collision_recovery(true);game.overview_mode=false;game.view_size=32.0
 game.view_center=game.player.position;game.camera.size=32.0;game._camera();game._update_view_button()
 await loader.checkpoint(.95,"地标准备就绪");await loader.finish();relocating=false

func overview_center() -> Vector3:return wp([735,1350])

func leave() -> void:
 controls.hide();level=null
 game.player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING;game.player.collision_mask=1
 game._configure_character_collision(false);game.character_material.set_shader_parameter("floor_height",game.CHARACTER_FLOOR_Y)
 game.atmosphere.sun.directional_shadow_max_distance=90

func physics(delta: float) -> void:
 var before: Vector3=game.player.position
 var free: bool=not game.dialog_open and not game.panel.visible and not game.settings_panel.visible and not game.loot.blocked() and not game.map_panel.visible and not game.editing
 var direction: Vector2=game.movement if free else Vector2.ZERO
 if free:direction+=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 var pace: float=game.character_controller.model.speed_multiplier(Input.is_physical_key_pressed(KEY_SHIFT)) if game.character_controller else 1.0
 var planar: Vector3=game._screen_direction_to_world(direction)*game.SPEED*pace
 game.player.velocity.x=planar.x;game.player.velocity.z=planar.z
 game.player.velocity.y=0.0 if game.player.is_on_floor() else game.player.velocity.y-18.0*delta
 game._move_character(delta,true)
 var travel: Vector3=game.player.position-before
 game.facing_accum+=game._character_screen_travel(travel);game.facing_timer+=delta
 if game.facing_timer>=game.FACING_WINDOW:
  if game.facing_accum.length()>game.FACING_MIN_TRAVEL:game.facing=game._direction_name(game.facing_accum)
  game.facing_accum=Vector2.ZERO;game.facing_timer=0
 game._advance_character_gait(travel,delta)
 game.character_material.set_shader_parameter("floor_height",game.player.position.y+game.CHARACTER_FLOOR_Y)
 var desired: Vector3=overview_center() if game.overview_mode else game.player.position
 game.view_center=game.view_center.lerp(desired,1.0-exp(-delta*7.0) if HarborPrefs.values.smooth_camera else 1.0)
 game.camera.size=lerpf(game.camera.size,game.view_size,1.0-exp(-delta*8.0));game._camera();game._refresh_zone()
 game.atmosphere.sun.directional_shadow_max_distance=game.camera.position.distance_to(game.view_center)+game.camera.size*.9+70
 game.nearest_portal={}
 for portal in game.portals:
  if game.player.position.distance_to(portal.pos)<1.25:game.nearest_portal=portal;break
 controls.visible=free;game.view_button.visible=free;game.zone_label.visible=free;game.clock_panel.visible=free
 game.clock_label.text=game.atmosphere.clock_text();game._route_frame(free)
 if free:game.hint.text="WASD 校园漫步 · Z 全校总览 · 右侧导览前往地标 · E 出入口 · M 地图"
 if game.character_controller:game.character_controller.advance(delta,before)
 if game.life_booted:
  game.autosave_clock+=delta
  if game.autosave_clock>7 and free:game.autosave_clock=0;game._save()
