extends Node3D
const WhaleSkin = preload("res://ui/whale_skin.gd")
const UiFit = preload("res://ui/ui_fit.gd")
## Complete video frames use a common density or their manifest calibration.
## Front proportions use one continuous local map; no global 16% enlargement.
const DIRECTION_SIZE_FIX := {}
const FOOT_RADIUS := .32
const FOOT_HEIGHT := .32
const CHARACTER_FLOOR_Y := .056
const Module = preload("res://module.gd")
const SolidModule = preload("res://module_3d.gd")
const Modern = preload("res://modern_materials.gd")
const Atmosphere = preload("res://atmosphere.gd")
const CharacterSurface = preload("res://character/surface_profiles.gd")
const CharacterProportions = preload("res://character/proportion_profiles.gd")
const CharacterPalette = preload("res://character/palette_profiles.gd")
const CharacterBlink = preload("res://character/blink_controller.gd")
const CollisionSafety = preload("res://character/collision_safety.gd")
var collision_recovery_pending:=true
var collision_last_safe:=Vector3.ZERO
var collision_has_safe:=false
var collision_spawn:=Vector3.ZERO
var silhouette_body: CharacterBody3D
var collision_grounded:=false
var atmosphere
var atmosphere_demo := false
const LootController = preload("res://loot_controller.gd")
const SPEED := 2.40
# 步态调参口：步频跟着真实移动速度走，朝向跟着真实位移走
const FACING_WINDOW := 0.10
const FACING_MIN_TRAVEL := 0.010
var loot
var loot_demo := false
const FLOOR_NAMES := ["oak","pale_oak","walnut","herringbone","ivory_tile","slate_tile","concrete","marble","terrazzo","navy_carpet","tatami","metal_grid"]
const WALL_NAMES := ["plaster_ivory","oak_slats","walnut_slats","slate_panels","concrete_panels","navy_padded","plaster_mint","cream_tile","brushed_metal","beige_wainscot","white_marble","pale_wainscot"]
var catalog: Dictionary
var world: Node3D
var shell: Node3D
var floor_mesh: MeshInstance3D
var camera: Camera3D
var player: CharacterBody3D
var avatar: AnimatedSprite3D
var facing := "down"
var facing_accum := Vector2.ZERO
var facing_timer := 0.0
var frames: SpriteFrames
var character_manifest: Dictionary
var character_material: ShaderMaterial
var blink_controller
var safe_matte_sources: Dictionary = {}
var gait_phase := 0.0
var gait_cycle_distance := 1.0
var items: Array = []
var layout_index := 0
var floor_index := 0
var wall_index := 0
var editing := false
var selected := "plant_broadleaf"
var ui_demo := false
var actor_front := false
var foot_collision: CollisionShape3D
var foot_debug: MeshInstance3D
var overlay_backdrop: ColorRect
var settings_panel: Panel
var settings_front_button: Button
var settings_light_button: Button
var settings_fx_button: Button
var settings_foot_button: Button
var settings_view: Control
var pause_menu: Node
var character_controller: Node
var combat_controller: Node
var nav_buttons: Array[Button] = []
var catalog_buttons: Array[Button] = []
var category_buttons: Dictionary = {}
var catalog_category := "furniture"
var catalog_filtered: Array = []
var ui: CanvasLayer
var title: Label
var hint: Label
var panel: Panel
var catalog_page := 0
var catalog_ids: Array = []
var ghost: Node3D
var ghost_id := ""
var placement_angle := 0
var dialog: Panel
var message: Label
var dialog_open := false
var dialogue_controller
const DialogueController=preload("res://dialogue/dialogue_controller.gd")
var closest: Node3D
var demo := false
var tick := 0
var movement := Vector2.ZERO
var failures := 0
var camera_angle := 28.0
const SURFACES := {"bed_navy":.80,"bed_sage":.80,"desk_oak":.97,"desk_white":.97,"nightstand":.73,"side_table":.66,"dining_round":.89,"dining_white":.91,"coffee_table":.55,"entry_bench":.55,"cubby":1.44,"tv_cabinet":.71,"sink_counter":1.0,"stove_counter":1.0,"counter_blank":1.0,"bar_cabinet":1.0,"loveseat_navy":.72,"sofa_cream":.72,"armchair_sage":.72,"armchair_navy":.72}

func _ready() -> void:
 catalog=Module.get_catalog();catalog_ids=catalog.keys()
 ui_demo="--ui-demo" in OS.get_cmdline_user_args()
 loot_demo="--loot-demo" in OS.get_cmdline_user_args()
 atmosphere_demo="--atmosphere-demo" in OS.get_cmdline_user_args()
 demo="--demo" in OS.get_cmdline_user_args() or loot_demo or atmosphere_demo or ui_demo
 var environment:=WorldEnvironment.new();var settings:=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("142133")
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("c6d2dd");settings.ambient_light_energy=0.28
 environment.environment=settings;environment.name="RoomEnvironment";add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_color=Color("fff0d5");sun.light_energy=0.40;sun.shadow_enabled=true
 sun.name="Sun";sun.directional_shadow_max_distance=90
 # One full-resolution map suits the orthographic view better than four depth splits.
 sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
 sun.directional_shadow_fade_start=1.0;sun.shadow_bias=.12;sun.shadow_normal_bias=1.8
 sun.shadow_blur=.85;sun.light_specular=.20;add_child(sun)
 world=Node3D.new();add_child(world);shell=Node3D.new();add_child(shell)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=11.7;camera.near=0.1;camera.far=65;camera.current=true;add_child(camera);_camera()
 _player();_ui()
 loot=LootController.new();add_child(loot)
 atmosphere=Atmosphere.new();add_child(atmosphere);atmosphere.configure(self)
 _layout(0)
 ghost=Node3D.new();add_child(ghost)
 dialogue_controller=DialogueController.new();add_child(dialogue_controller)
 if OS.is_debug_build():
  var proportion_reload=preload("res://character/proportion_live_reload.gd").new()
  proportion_reload.name="CharacterProportionLiveReload";proportion_reload.game=self;add_child(proportion_reload)
 if "--test-room" in OS.get_cmdline_user_args():call_deferred("_test")
 if "--test-loot" in OS.get_cmdline_user_args():call_deferred("_test_loot")
 if "--test-load" in OS.get_cmdline_user_args():call_deferred("_test_reload")
 if "--test-ui" in OS.get_cmdline_user_args():call_deferred("_test_ui")
 if "--test-atmosphere" in OS.get_cmdline_user_args():call_deferred("_test_atmosphere")
 if loot_demo:player.position=Vector3(-1.35,0,2.65)

func _camera() -> void:
 var a:=deg_to_rad(camera_angle)
 camera.position=Vector3(sin(a)*19,12.7,cos(a)*19)
 camera.look_at(Vector3(0,0.72,0.04))

func _player() -> void:
 player=CharacterBody3D.new();player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
 player.collision_layer=4;player.add_to_group("collision_protected_player")
 player.max_slides=8;player.safe_margin=.008
 foot_collision=CollisionShape3D.new();foot_collision.name="FeetCollision"
 var shape:=CylinderShape3D.new();shape.radius=FOOT_RADIUS;shape.height=FOOT_HEIGHT
 foot_collision.shape=shape;foot_collision.position=Vector3(0,FOOT_HEIGHT/2+.01,0);player.add_child(foot_collision)
 CollisionSafety.add_guards(player)
 silhouette_body=CharacterBody3D.new();silhouette_body.name="CharacterSilhouetteSweep"
 silhouette_body.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
 silhouette_body.collision_layer=0;silhouette_body.collision_mask=9
 silhouette_body.max_slides=8;silhouette_body.safe_margin=.008
 for hit in player.get_children():
  if hit is CollisionShape3D:silhouette_body.add_child(hit.duplicate())
 add_child(silhouette_body);player.set_meta("silhouette_body",silhouette_body)
 foot_debug=MeshInstance3D.new();var disk:=CylinderMesh.new();disk.top_radius=FOOT_RADIUS;disk.bottom_radius=FOOT_RADIUS;disk.height=.008
 foot_debug.mesh=disk;foot_debug.position.y=CHARACTER_FLOOR_Y
 var debug_material:=StandardMaterial3D.new();debug_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;debug_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;debug_material.albedo_color=Color(.35,.72,1.,.50)
 foot_debug.material_override=debug_material;foot_debug.visible=false;foot_debug.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;player.add_child(foot_debug)
 var shadow:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(1.22,0.70);shadow.mesh=plane;shadow.position.y=CHARACTER_FLOOR_Y
 var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void fragment(){float d=length((UV-vec2(0.5))*2.0);float outer=1.0-smoothstep(0.32,1.0,d);float core=1.0-smoothstep(0.0,0.56,d);ALBEDO=vec3(0.08,0.11,0.15);ALPHA=outer*0.18+core*0.18;}"
 var material:=ShaderMaterial.new();material.shader=shader;shadow.material_override=material;player.add_child(shadow)
 frames=_build_frames();avatar=AnimatedSprite3D.new();avatar.sprite_frames=frames
 avatar.pixel_size=character_pixel_size(facing)
 var cell: Array=character_manifest.frame_size;var ground: Array=character_manifest.ground
 avatar.offset.x=float(cell[0])/2-float(ground[0])
 avatar.position.y=character_ground_offset(facing)
 avatar.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
 avatar.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;avatar.alpha_scissor_threshold=0.28
 avatar.no_depth_test=actor_front;avatar.render_priority=127 if actor_front else 0
 avatar.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED if actor_front else SpriteBase3D.ALPHA_CUT_DISCARD
 avatar.shaded=true;avatar.double_sided=true;avatar.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 character_material=ShaderMaterial.new();character_material.shader=load("res://character/character_depth.gdshader")
 character_material.set_shader_parameter("edge_ink_enabled",not character_manifest.get("runtime_matte_baked",false))
 character_material.set_shader_parameter("floor_height",CHARACTER_FLOOR_Y)
 avatar.material_override=character_material
 avatar.animation_finished.connect(func():_set_character_pose(false))
 player.add_child(avatar);world.add_child(player);_reset_character_gait()
 if character_manifest.has("blink_config"):
  var settings: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(character_manifest.blink_config))
  blink_controller=CharacterBlink.new();blink_controller.name="NaturalBlink";add_child(blink_controller)
  blink_controller.configure(settings,Callable(self,"_update_character_material"))
  world.child_entered_tree.connect(func(child: Node):
   if child.name=="WhaleGuide":_attach_guide_blink.call_deferred(child))

func _attach_guide_blink(guide) -> void:
 if not is_instance_valid(guide):return # Travel may free a queued companion.
 for child in guide.get_children():
  if not child is Sprite3D:continue
  var base: Texture2D=child.texture
  var material: ShaderMaterial=child.material_override
  var guide_blink=CharacterBlink.new();guide_blink.name="NaturalBlink";guide.add_child(guide_blink)
  guide_blink.configure(blink_controller.config,func():
   var picture: Texture2D=guide_blink.texture_for(base)
   child.texture=picture;material.set_shader_parameter("character_atlas",picture))
  return

func _floor() -> void:
 if not floor_mesh:
  var plane:=PlaneMesh.new();plane.size=Vector2(12,6.67);floor_mesh=MeshInstance3D.new();floor_mesh.mesh=plane;floor_mesh.position=Vector3(0,0.006,0.085);add_child(floor_mesh)
 floor_mesh.material_override=Modern.floor_material(FLOOR_NAMES[floor_index])

func _wall_material() -> StandardMaterial3D:
 var texture: Texture2D=load(catalog[WALL_NAMES[wall_index]].texture)
 var image:=texture.get_image();image=image.get_region(Rect2i(4,4,image.get_width()-8,image.get_height()-8))
 var m:=StandardMaterial3D.new();m.albedo_texture=ImageTexture.create_from_image(image);m.roughness=0.95;m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
 return m

func _shell() -> void:
 for child in shell.get_children():child.free()
 var builder:=SolidModule.new();builder.module_id="";shell.add_child(builder)
 builder.box(Vector3(12.42,0.28,7.07),Vector3(0,-0.15,0.085),Color("617482"))
 for i in 9:
  var wall=load("res://scenes/modules_3d/"+WALL_NAMES[wall_index]+".tscn").instantiate();wall.position=Vector3(-5.333+i*1.3333,0,-3.25);shell.add_child(wall)
  var cap=load("res://scenes/modules_3d/cap_charcoal.tscn").instantiate();cap.position=Vector3(-5.333+i*1.3333,2.78,-3.20);shell.add_child(cap)
 for i in 5:
  var wall=load("res://scenes/modules_3d/"+WALL_NAMES[wall_index]+".tscn").instantiate();wall.position=Vector3(-6,0,-2.583+i*1.334);wall.rotation.y=PI/2;shell.add_child(wall)
  var cap=load("res://scenes/modules_3d/cap_charcoal.tscn").instantiate();cap.position=Vector3(-5.98,2.78,-2.583+i*1.334);cap.rotation.y=PI/2;shell.add_child(cap)
 # Upper cut faces, floor slab and skirting form a real, open dollhouse volume.
 for size_pos in [[Vector3(12.25,0.10,0.08),Vector3(0,0.06,-3.22)],[Vector3(0.08,0.10,6.67),Vector3(-5.975,0.06,0.08)]]:builder.box(size_pos[0],size_pos[1],Color("6a7e8e"))
 builder.box(Vector3(12.35,0.18,0.22),Vector3(0,0.035,3.535),Color("b6c4ce"))
 builder.box(Vector3(0.22,0.18,6.90),Vector3(6.12,0.035,0.08),Color("b6c4ce"))
 builder.led_box(Vector3(11.9,.014,.018),Vector3(0,.105,-3.17),Color("7acfdc"),.28)
 builder.led_box(Vector3(.018,.014,6.50),Vector3(-5.91,.105,.08),Color("7acfdc"),.28)
 for x in [-6,6]:builder.box(Vector3(0.12,0.12,7.10),Vector3(x,-0.23,0.08),Color("383d43"))
 for bounds in [AABB(Vector3(-6.25,0,-3.5),Vector3(0.25,3,7.15)),AABB(Vector3(6,0,-3.5),Vector3(0.25,3,7.15)),AABB(Vector3(-6,0,-3.5),Vector3(12,3,0.25)),AABB(Vector3(-6,0,3.42),Vector3(12,3,0.25))]:
  var body:=StaticBody3D.new();var hit:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=bounds.size;hit.shape=shape;body.position=bounds.position+bounds.size/2;body.add_child(hit);shell.add_child(body)

func _spawn(entry: Dictionary) -> Node3D:
 var object=load("res://scenes/modules_3d/"+str(entry.id)+".tscn").instantiate()
 object.position=Vector3(entry.pos[0],entry.pos[1],entry.pos[2]);object.rotation_degrees.y=float(entry.get("angle",0));world.add_child(object);object.set_meta("placement",entry.duplicate(true));items.append(object)
 return object

func _layout(index: int) -> void:
 layout_index=index
 for child in world.get_children():
  if child!=player:child.free()
 items.clear()
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://layouts_3d/"+["bedroom","studio","reading_cafe"][index]+".json"))
 floor_index=FLOOR_NAMES.find(data.floor);wall_index=WALL_NAMES.find(data.wall);_floor();_shell()
 for entry in data.items:_spawn(entry)
 player.position=Vector3(data.spawn[0],0,data.spawn[2]);player.velocity=Vector3.ZERO
 _queue_collision_recovery(true)
 dialog_open=false;dialog.hide();editing=false
 title.text=str(data.name)
 for i in nav_buttons.size():nav_buttons[i].set_pressed_no_signal(i==index)
 settings_panel.hide()
 _rug()
 if loot:loot.room_changed(index)
 if atmosphere:atmosphere.rebuild()

func _rug() -> void:
 var rug:=SolidModule.new();rug.module_id="";world.add_child(rug)
 var origin:=Vector3(.20,0,2.10)
 rug.box(Vector3(4.40,.015,1.94),origin+Vector3(0,.018,0),Color("63738a"))
 for z in [-.92,.92]:rug.box(Vector3(4.38,.005,.025),origin+Vector3(0,.029,z),Color("a9b8c8"))
 for x in [-2.15,2.15]:rug.box(Vector3(.025,.005,1.87),origin+Vector3(x,.029,0),Color("a9b8c8"))

func _physics_process(delta: float) -> void:
 var direction:=movement
 if ui_demo:
  tick+=1
  direction=_ui_demo_step()
 elif loot_demo:
  tick+=1
  direction=_loot_demo_step()
 elif atmosphere_demo:
  tick+=1
  direction=_atmosphere_demo_step()
 elif demo:
  tick+=1
  if tick==300:player.position=Vector3(4.02,0,1.07)
  if tick==400:camera_angle=42;_camera()
  if tick==480:camera_angle=28;_camera();_layout(1)
  if tick==960:camera_angle=35;_camera();_layout(2)
  if tick==1440:catalog_page=1;_catalog(true)
  if tick==1500:catalog_page=2;_catalog(true)
  if tick==1560:panel.hide();camera_angle=28;_camera();_layout(0)
  if tick==1620:_place("plant_fiddle",Vector3(-1.4,0,2.24))
  if tick==1680:_place("whale_plush",Vector3(.58,0,2.40))
  if tick==1740:floor_index=1;_floor()
  var local_tick:=tick%480
  if tick<1440 and not (tick>=300 and tick<480):direction=Vector2.RIGHT if local_tick<120 else (Vector2.UP if local_tick<240 else (Vector2.LEFT if local_tick<360 else Vector2.DOWN))
 else:
  direction+=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 if dialog_open or panel.visible or settings_panel.visible or editing or loot.blocked():direction=Vector2.ZERO
 # Keyboard directions are screen-space directions. Invert the camera's ground
 # projection so diagonal input and the eight-way sprite sectors use the same axes.
 player.velocity=character_controller.movement_velocity(direction,delta) if character_controller else _screen_direction_to_world(direction)*SPEED
 # 闪避位移随即时战一起移除（战斗已改为回合制，移动不再受战斗输入影响）
 var before:=player.position
 _move_character(delta,false)
 # 朝向跟着真实位移走：顶着家具不再空转转身，沿家具滑动时朝向贴着滑行方向
 var travel:=player.position-before
 facing_accum+=_character_screen_travel(travel);facing_timer+=delta
 if facing_timer>=FACING_WINDOW:
  if facing_accum.length()>FACING_MIN_TRAVEL:facing=_direction_name(facing_accum)
  facing_accum=Vector2.ZERO;facing_timer=0.0
 if not avatar.animation.begins_with("interact_") or not avatar.is_playing():
  _advance_character_gait(travel,delta)
 _update_character_material()
 closest=null;var distance:=1.65
 for object in items:
  if object.metadata.layer=="surface":continue
  var d: float=Vector2(player.position.x,player.position.z).distance_to(Vector2(object.position.x,object.position.z))
  if d<distance:closest=object;distance=d
 overlay_backdrop.visible=panel.visible or dialog_open or settings_panel.visible
 if editing:
  _update_ghost()
  hint.text="正在装饰："+str(catalog[selected].name)+" · 点击放置 / 右键移除 · R旋转 · F5保存"
 else:
  if ghost:ghost.hide()
  if loot.blocked():hint.text="收纳时间 · Esc回到房间 · I切换背包 · 取物后自动保存"
  elif not dialog_open:
   if is_instance_valid(loot.nearby):hint.text="发现补给箱啦！按 E 打开，喜欢的东西收进背包。"
   else:hint.text=("按 E 看看："+str(closest.metadata.name) if closest else "大肥鱼陪你逛房间，今天也慢慢来。")+" · Tab 打开家居箱"

func _queue_collision_recovery(new_world: bool=false) -> void:
 collision_recovery_pending=true
 if new_world:
  if character_controller:character_controller.cancel_dash()
  collision_spawn=player.global_position;collision_has_safe=false

func _collision_point_allowed(point: Vector3,grounded: bool) -> bool:
 if not CollisionSafety.clear_at(player,point):return false
 if grounded:return CollisionSafety.supported(player,point)
 if shell.has_meta("floor_contours"):
  for polygon in shell.get_meta("floor_contours"):
   if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon):return true
  return false
 if shell.has_meta("floor_contour"):
  return Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),shell.get_meta("floor_contour"))
 var bounds: Variant=get("space_bounds")
 if bounds is Vector2:return absf(point.x)<bounds.x*.5 and absf(point.z)<bounds.y*.5
 return absf(point.x)<6.0 and point.z> -3.25 and point.z<3.42

func _recover_character(grounded: bool) -> bool:
 _configure_character_collision(grounded)
 var origin:=player.global_position
 if _collision_point_allowed(origin,grounded):
  collision_last_safe=origin;collision_has_safe=true;collision_recovery_pending=false;return true
 # Never let engine recovery push a saved character through a wall to its far side.
 var candidates: Array[Vector3]=[]
 if collision_has_safe:candidates.append(collision_last_safe)
 for ring in range(1,25):
  var radius: float=ring*.25
  for direction in 32:
   var angle: float=direction*TAU/32
   candidates.append(origin+Vector3(cos(angle)*radius,0,sin(angle)*radius))
 candidates.append(collision_spawn)
 for candidate in candidates:
  if not _collision_point_allowed(candidate,grounded):continue
  player.global_position=candidate;player.velocity=Vector3.ZERO
  collision_last_safe=candidate;collision_has_safe=true;collision_recovery_pending=false
  _reset_character_gait();return true
 player.velocity=Vector3.ZERO
 return false

func _configure_character_collision(grounded: bool) -> void:
 if collision_grounded!=grounded:
  collision_grounded=grounded
  for guard in player.get_children():
   if guard is CollisionShape3D and str(guard.name).begins_with("SilhouetteGuard"):guard.disabled=grounded
  silhouette_body.collision_layer=4 if grounded else 0
 silhouette_body.global_transform=player.global_transform
 if grounded and silhouette_body.has_meta("floor_slabs"):
  for slab in silhouette_body.get_meta("floor_slabs"):
   if not is_instance_valid(slab):continue
   # Small floor lips are stepped onto by the feet, rather than struck by
   # the broad lower skirt/tail guard. Slabs overhead still stop the head.
   if CollisionSafety.slab_near_feet(slab,player.global_position):silhouette_body.add_collision_exception_with(slab)
   else:silhouette_body.remove_collision_exception_with(slab)

func _move_character(_delta: float,grounded: bool) -> void:
 _configure_character_collision(grounded)
 if collision_recovery_pending and not _recover_character(grounded):return
 var before:=player.global_position
 var had_support: bool=grounded and CollisionSafety.supported(player,before)
 var requested_velocity:=player.velocity
 player.move_and_slide()
 if had_support:_step_onto_landing(before,requested_velocity)
 if grounded:
  var destination:=player.global_position
  silhouette_body.global_transform=player.global_transform;silhouette_body.global_position=before
  # Floor contact belongs to the feet. The complete silhouette sweeps only
  # walls, railings and furniture, so a rising ramp cannot push the hair back.
  silhouette_body.velocity=(destination-before)/maxf(get_physics_process_delta_time(),.0001)
  silhouette_body.move_and_slide();player.global_position=silhouette_body.global_position
 if not grounded:player.position.y=before.y
 if not grounded and not _collision_point_allowed(player.global_position,false):
  player.global_position=before;player.velocity=Vector3.ZERO
 if had_support:
  var destination:=player.global_position
  var steps:=maxi(1,ceili(before.distance_to(destination)/.15))
  for i in range(1,steps+1):
   if not CollisionSafety.supported(player,before.lerp(destination,float(i)/steps)):
    player.global_position=before;player.velocity=Vector3.ZERO;break
 # Sweep handles large displacements; this catches newly enabled/moving blockers.
 if not CollisionSafety.clear_at(player,player.global_position):
  if CollisionSafety.clear_at(player,before):player.global_position=before;player.velocity=Vector3.ZERO
  else:collision_recovery_pending=true;_recover_character(grounded)
 if _collision_point_allowed(player.global_position,grounded):
  collision_last_safe=player.global_position;collision_has_safe=true
 silhouette_body.global_transform=player.global_transform

func _step_onto_landing(before: Vector3,requested: Vector3) -> void:
 # A cylinder can stop against the few-millimetre vertical seam between a
 # convex stair and its landing. Step only onto identified walkable slabs.
 var candidates: Array[StaticBody3D]=[]
 for index in player.get_slide_collision_count():
  var contact:=player.get_slide_collision(index)
  var slab:=contact.get_collider() as StaticBody3D
  if not slab or not slab.has_meta("walkable_top") or contact.get_normal().y>=.65:continue
  candidates.append(slab)
 var planar:=Vector3(requested.x,0,requested.z)
 var actual:=Vector2(player.position.x-before.x,player.position.z-before.z).length()
 if planar.length()>.01 and actual<planar.length()*get_physics_process_delta_time()*.5:
  var ahead:=player.global_position+planar.normalized()*(FOOT_RADIUS+.10)
  var query:=PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*.25,ahead-Vector3.UP*.35,2,[player.get_rid(),silhouette_body.get_rid()])
  var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
  if not hit.is_empty() and hit.collider is StaticBody3D and hit.normal.y>=.65:
   var slab: StaticBody3D=hit.collider
   if slab.has_meta("walkable_top") and not slab.has_meta("walkable_stair") and not slab in candidates:candidates.append(slab)
 for slab in candidates:
  var foot_bottom: float=player.global_position.y+foot_collision.position.y-FOOT_HEIGHT*.5
  var rise: float=float(slab.get_meta("walkable_top"))+.008-foot_bottom
  if rise<=0 or rise>.18:continue
  var lifted:=before+Vector3.UP*rise
  if not CollisionSafety.clear_at(player,lifted):continue
  var original:=player.global_position
  player.global_position=lifted;player.velocity=Vector3(requested.x,0,requested.z)
  player.move_and_collide(player.velocity*get_physics_process_delta_time());player.apply_floor_snap()
  if Vector2(player.position.x-before.x,player.position.z-before.z).length()<=Vector2(original.x-before.x,original.z-before.z).length()+.0001:
   player.global_position=original
  return

func _placement_overlaps_character(node: Node) -> bool:
 if node is CollisionShape3D and not node.disabled and node.shape:
  if node.shape is BoxShape3D and preload("res://character/moving_clearance.gd").players_overlap(node):return true
  if CollisionSafety.overlaps_shape(player,node.shape,node.global_transform):return true
 for child in node.get_children():
  if _placement_overlaps_character(child):return true
 return false

func _mouse_ground() -> Vector3:
 var mouse:=get_viewport().get_mouse_position()
 var origin:=camera.project_ray_origin(mouse);var ray:=camera.project_ray_normal(mouse)
 if catalog[selected].layer=="surface":
  var distance:=INF;var surface_point: Variant=null
  for object in items:
   if not SURFACES.has(object.module_id):continue
   var height: float=object.position.y+SURFACES[object.module_id]
   var hit=Plane(Vector3.UP,height).intersects_ray(origin,ray)
   if hit==null:continue
   var local: Vector3=object.to_local(hit)
   var rect:=Rect2(-object.collision_width/2,-object.collision_depth,object.collision_width,object.collision_depth)
   if rect.has_point(Vector2(local.x,local.z)) and origin.distance_to(hit)<distance:surface_point=hit;distance=origin.distance_to(hit)
  if surface_point!=null:return Vector3(snappedf(surface_point.x,.08),surface_point.y+.015,snappedf(surface_point.z,.08))
 var point=Plane(Vector3.UP,0).intersects_ray(origin,ray)
 if point==null:return Vector3.ZERO
 return Vector3(snappedf(point.x,.16),0,snappedf(point.z,.16))

func _unhandled_input(event: InputEvent) -> void:
 if combat_controller and combat_controller.in_battle():return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.physical_keycode==KEY_I:loot.open_bag();get_viewport().set_input_as_handled();return
  if settings_panel.visible:
   if event.physical_keycode==KEY_ESCAPE:_settings(false)
   get_viewport().set_input_as_handled();return
  if loot.blocked():
   if event.physical_keycode==KEY_ESCAPE:loot.close()
   get_viewport().set_input_as_handled();return
  match event.physical_keycode:
   KEY_F8:_set_actor_front(not actor_front)
   KEY_1:_layout(0)
   KEY_2:_layout(1)
   KEY_3:_layout(2)
   KEY_TAB:_catalog(not panel.visible)
   KEY_B:_toggle_decor()
   KEY_R:
    if editing:placement_angle=(placement_angle+90)%360
   KEY_F2:floor_index=(floor_index+1)%12;_floor()
   KEY_F3:wall_index=(wall_index+1)%12;_shell()
   KEY_F4:camera_angle=42 if camera_angle<35 else 22;_camera()
   KEY_F6:settings_view._toggle("dusk")
   KEY_F7:settings_view._toggle("effects")
   KEY_F5:_save()
   KEY_F9:_restore()
   KEY_E,KEY_ENTER,KEY_SPACE:_interact()
   KEY_ESCAPE:panel.hide();dialog.hide();dialog_open=false;editing=false
 if event is InputEventMouseButton and event.pressed and editing and not panel.visible:
  var point:=_mouse_ground()
  if event.button_index==MOUSE_BUTTON_LEFT:_place(selected,point)
  elif event.button_index==MOUSE_BUTTON_RIGHT:
   var nearest: Node3D;var distance:=1.0
   for object in items:
    var d: float=Vector2(point.x,point.z).distance_to(Vector2(object.position.x,object.position.z))
    if d<distance:distance=d;nearest=object
   if nearest:
    items.erase(nearest);nearest.free()
    if atmosphere:atmosphere.rebuild()

func _place(id: String,p: Vector3) -> bool:
 if not catalog.has(id) or catalog[id].category=="floor":return false
 if p.x<-5.85 or p.x>5.85 or p.z<-3.1 or p.z>3.2:return false
 p=_placement_point(p,id)
 var object:=_spawn({"id":id,"pos":[p.x,p.y,p.z],"angle":placement_angle})
 var local: Vector3=object.to_local(player.position)
 var intersects:=false
 if object.collision_depth>0:
  var footprint:=Rect2(-object.collision_width/2,-object.collision_depth,object.collision_width,object.collision_depth).grow(FOOT_RADIUS)
  intersects=footprint.has_point(Vector2(local.x,local.z)) and local.y<object.collision_height and local.y+FOOT_HEIGHT+.01>0
 elif catalog[id].solid:intersects=Vector2(local.x,local.z).length()<float(catalog[id].footprint[0])/192+FOOT_RADIUS
 if intersects or _placement_overlaps_character(object):items.erase(object);object.free();return false
 if atmosphere and (id.begins_with("lamp_") or id.begins_with("curtains_")):atmosphere.rebuild()
 return true

func _placement_point(point: Vector3,id: String) -> Vector3:
 var entry: Dictionary=catalog[id]
 if entry.category=="structure":
  if id.begins_with("cap_"):point.y=2.78
  elif id.begins_with("rail_"):point.y=2.5
  else:point.y=0
 elif entry.layer=="wall":
  point.y=1.55;point.z=-3.15
  if id.begins_with("door_"):point.y=0
  elif id.begins_with("window_"):point.y=1.08
  elif id.begins_with("curtains_"):point.y=.84
 return point

func _update_ghost() -> void:
 if ghost_id!=selected:
  for child in ghost.get_children():child.free()
  var preview=load("res://scenes/modules_3d/"+selected+".tscn").instantiate();ghost.add_child(preview)
  _preview_style(preview)
  ghost_id=selected
 ghost.show();ghost.position=_placement_point(_mouse_ground(),selected);ghost.rotation_degrees.y=placement_angle

func _preview_style(node: Node) -> void:
 if node is CollisionObject3D:node.collision_layer=0;node.collision_mask=0
 if node is Light3D:node.visible=false
 if node is MeshInstance3D:
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var original: Material=node.material_override
  if original is StandardMaterial3D:
   var translucent:=original.duplicate();translucent.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;translucent.albedo_color=Color(.65,1,.8,.46);node.material_override=translucent
  elif original is ShaderMaterial:
   var translucent:=StandardMaterial3D.new();translucent.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;translucent.albedo_color=Color(.65,1,.8,.46);node.material_override=translucent
 if node is Sprite3D:node.modulate=Color(.65,1,.8,.5);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in node.get_children():_preview_style(child)

func _interact() -> void:
 if dialogue_controller and dialogue_controller.active:dialogue_controller.advance();return
 if loot.blocked():return
 if loot.nearby and not panel.visible and not editing:loot.open_chest();return
 if panel.visible or editing or settings_panel.visible:return
 if dialogue_controller and dialogue_controller.can_talk():dialogue_controller.start_topic();return
 if closest==null:
  if dialogue_controller:dialogue_controller.start_topic()
  return
 if str(closest.module_id).begins_with("door_"):_layout((layout_index+1)%3);return
 var difference:=camera.unproject_position(closest.position)-camera.unproject_position(player.position)
 facing=_direction_name(difference)
 if dialogue_controller:dialogue_controller.start_context(closest)

func _save() -> bool:
 var placements:=[]
 for object in items:placements.append(object.get_meta("placement"))
 var file:=FileAccess.open("user://modular_room_25d.json",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify({"layout":layout_index,"floor":floor_index,"wall":wall_index,"items":placements,"player":[player.position.x,player.position.y,player.position.z],"angle":camera_angle}))
 return true

func _restore() -> bool:
 if not FileAccess.file_exists("user://modular_room_25d.json"):return false
 var data=JSON.parse_string(FileAccess.get_file_as_string("user://modular_room_25d.json"))
 if not data is Dictionary:return false
 for entry in data.items:
  if not catalog.has(entry.id):return false
 _layout(int(data.layout))
 for object in items:object.free()
 items.clear();floor_index=int(data.floor)%12;wall_index=int(data.wall)%12;_floor();_shell()
 for entry in data.items:_spawn(entry)
 player.position=Vector3(data.player[0],0,data.player[2]);camera_angle=float(data.angle);_camera()
 _queue_collision_recovery()
 if atmosphere:atmosphere.rebuild()
 return true

func _check(condition: bool,text: String) -> void:
 if condition:print("PASS: ",text)
 else:failures+=1;push_error("FAIL: "+text)

func _loot_demo_step() -> Vector2:
 if tick<82:
  var target:=Vector3(-1.35,0,1.24)
  var travel: Vector3=(target-player.position).normalized()
  return Vector2(travel.dot(camera.global_basis.x),travel.dot(Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()))
 if tick==110:_interact()
 if tick==190:loot.rows.context_note.pressed.emit()
 if tick==240:loot.take_button.pressed.emit()
 if tick==300:loot.rows.token_cracker.pressed.emit();loot.quantity.value=3
 if tick==360:loot.take_button.pressed.emit()
 if tick==420:loot.rows.stopped_pillow.pressed.emit()
 if tick==470:loot.all_button.pressed.emit()
 if tick==530:loot.close()
 if tick==560:loot.open_bag()
 if tick==620:loot.rows.context_note.pressed.emit()
 if tick==680:loot.selected_button.pressed.emit()
 if tick==800:loot.rows.stopped_pillow.pressed.emit();loot.selected_button.pressed.emit()
 if tick==900:loot.rows.token_cracker.pressed.emit();loot.selected_button.pressed.emit()
 if tick==1010:loot.close()
 if tick==1040:loot.open_note()
 if tick==1180:loot.close();_layout(1);player.position=Vector3(-.85,0,1.25)
 if tick==1240:_interact()
 if tick==1290:loot.rows.thinking_lamp.pressed.emit()
 if tick==1370:loot.take_button.pressed.emit()
 if tick==1440:loot.close();loot.open_bag()
 if tick==1480:loot.rows.thinking_lamp.pressed.emit();loot.selected_button.pressed.emit()
 if tick==1590:loot.close();_layout(2);player.position=Vector3(-.85,0,1.25)
 if tick==1650:_interact()
 if tick==1710:loot.rows.whale_letter.pressed.emit()
 if tick==1760:loot.take_button.pressed.emit()
 return Vector2.ZERO

func _atmosphere_demo_step() -> Vector2:
 if tick==1:player.position=Vector3(.35,0,1.0)
 if tick==120:camera_angle=34;_camera()
 if tick==240:atmosphere.set_dusk(true)
 if tick==430:player.position=Vector3(-1.35,0,1.25)
 if tick==470:_interact()
 if tick==540:loot.rows.stopped_pillow.pressed.emit()
 if tick==580:loot.take_button.pressed.emit()
 if tick==650:loot.close()
 if tick==710:loot.open_bag()
 if tick==750:loot.rows.stopped_pillow.pressed.emit();loot.selected_button.pressed.emit()
 if tick==860:loot.close();_layout(1);camera_angle=28;_camera()
 if tick==1100:atmosphere.set_dusk(false)
 if tick==1240:_layout(2);camera_angle=35;_camera()
 if tick==1500:atmosphere.set_dusk(true)
 if tick==1740:atmosphere.set_effects(false)
 if tick==1800:atmosphere.set_effects(true)
 if tick==1820:catalog_page=0;_catalog(true)
 if tick==1865:catalog_page=1;_catalog(true)
 if tick==1910:panel.hide();_layout(0);camera_angle=28;_camera();atmosphere.set_dusk(false)
 if tick>=30 and tick<115:return Vector2.RIGHT
 if tick>=135 and tick<230:return Vector2.LEFT
 if tick>=930 and tick<1075:return Vector2.RIGHT
 if tick>=1280 and tick<1445:return Vector2.RIGHT
 return Vector2.ZERO

func _test_loot() -> void:
 _layout(0);loot.inventory.clear();loot.stocks=LootController.INITIAL_STOCK.duplicate(true)
 player.position=Vector3(0,0,3.0)
 for n in 3:await get_tree().physics_frame
 _check(not loot.prompt.visible and loot.nearby==null,"crate options stay hidden outside range")
 player.position=Vector3(-1.35,0,1.22)
 for n in 4:await get_tree().physics_frame
 _check(loot.prompt.visible and loot.nearby!=null,"approaching crate displays world-anchored options")
 _interact();await get_tree().process_frame
 _check(loot.mode=="loot" and loot.current_chest.opened,"E opens loot menu and actual 3D lid")
 var anchor:=player.position;movement=Vector2.RIGHT
 for n in 8:await get_tree().physics_frame
 _check(player.position.distance_to(anchor)<.01,"loot panel blocks character movement")
 movement=Vector2.ZERO
 loot.rows.token_cracker.pressed.emit();loot.quantity.value=3;loot.take_button.pressed.emit()
 _check(int(loot.inventory.get("token_cracker",0))==3 and int(loot.stocks.bedroom_supply.token_cracker)==5,"UI quantity selection transfers three items and reduces crate stock")
 _check(not loot.transfer("token_cracker",6) and not loot.transfer("token_cracker",0) and not loot.transfer("unknown",1),"invalid amounts and unknown items rejected")
 loot.rows.context_note.pressed.emit();loot.all_button.pressed.emit()
 _check(int(loot.inventory.context_note)==1 and int(loot.stocks.bedroom_supply.context_note)==0 and not loot.rows.has("context_note"),"take-all removes depleted entry from crate UI")
 _check(not loot.transfer("context_note",1),"depleted item cannot be duplicated")
 var original_path: String=loot.save_path
 loot.save_path="user://missing_directory_v5/blocked.json"
 var before: int=int(loot.inventory.token_cracker)
 _check(not loot.transfer("token_cracker",1) and int(loot.inventory.token_cracker)==before and int(loot.stocks.bedroom_supply.token_cracker)==5,"failed save rolls back both inventory and crate")
 loot.save_path=original_path
 loot.close();await get_tree().process_frame;_interact()
 _check(not loot.rows.has("context_note") and int(loot.stocks.bedroom_supply.token_cracker)==5,"reopening keeps depleted stock")
 loot.close();loot.open_bag();loot.rows.context_note.pressed.emit();loot.selected_button.pressed.emit()
 for child in loot.modal.get_children():
  if child is Label and child.has_meta("item_description"):_check(child.size.x<=635.1 and child.position.x+child.size.x<loot.modal.size.x-28,"long item description wraps inside panel")
 _check(int(loot.inventory.context_note)==1 and loot.status.contains("DeepSeek"),"reading original meme lore preserves clue item")
 loot.rows.token_cracker.pressed.emit();loot.selected_button.pressed.emit()
 _check(int(loot.inventory.token_cracker)==2,"using consumable subtracts exactly one")
 _layout(1);player.position=Vector3(-.85,0,1.25)
 for n in 4:await get_tree().physics_frame
 _interact();loot.rows.thinking_lamp.pressed.emit();loot.all_button.pressed.emit()
 _check(int(loot.inventory.thinking_lamp)==1 and int(loot.inventory.token_cracker)==2,"backpack persists across rooms and collects distinct supply")
 loot.close();_layout(0);player.position=Vector3(-1.35,0,1.25)
 for n in 4:await get_tree().physics_frame
 _interact();_check(not loot.rows.has("context_note"),"returning to room does not reset crate")
 var stored: Dictionary=loot.inventory.duplicate(true);var saved_stock: Dictionary=loot.stocks.duplicate(true)
 loot.inventory.clear();loot.stocks=LootController.INITIAL_STOCK.duplicate(true)
 _check(loot.load_state() and loot.inventory==stored and loot.stocks==saved_stock,"disk reload restores inventory and all room stocks together")
 for id in loot.stocks.bedroom_supply.keys():
  var remaining:=int(loot.stocks.bedroom_supply[id])
  if remaining>0:_check(loot.transfer(id,remaining),"take remaining "+str(id))
 _check(loot.stock_total("bedroom_supply")==0 and loot.chosen=="" and loot.take_button==null,"empty crate displays safe empty state")
 var committed: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(loot.save_path))
 _check(committed.inventory==JSON.parse_string(JSON.stringify(loot.inventory)) and committed.stocks==JSON.parse_string(JSON.stringify(loot.stocks)),"last take transaction is committed on disk")
 _check(not loot.transfer("token_cracker",1),"empty crate prevents extra transfers")
 loot.close();player.position=Vector3(0,0,3)
 for n in 4:await get_tree().physics_frame
 loot.open_chest();_check(loot.mode=="","out-of-range crate cannot open")
 var chest: Node3D=loot.chests[0]
 player.position=Vector3(-1.35,0,1.28)
 for n in 45:player.velocity=Vector3(0,0,-2);player.move_and_slide()
 _check(player.position.z>=.64,"native crate collider blocks actor")
 player.position=Vector3(-1.35,0,1.25)
 for n in 4:await get_tree().physics_frame
 loot.open_note();_check(loot.mode=="note" and loot.current_chest.note.contains("DeepSeek"),"proximity note option opens world lore")
 loot.close();await get_tree().create_timer(.45).timeout
 _check(not chest.opened and absf(chest.hinge.rotation.x)<.01,"lid closes smoothly when modal closes")
 print("ALL LOOT CHECKS PASSED" if failures==0 else "FAILURES: "+str(failures));get_tree().quit(0 if failures==0 else 1)

func _test_reload() -> void:
 _check(int(loot.inventory.get("token_cracker",0))==7 and int(loot.inventory.get("context_note",0))==1 and int(loot.inventory.get("thinking_lamp",0))==1,"new Godot process automatically restores backpack")
 _check(loot.stock_total("bedroom_supply")==0 and int(loot.stocks.studio_supply.thinking_lamp)==0,"new Godot process restores depleted crate states")
 player.position=Vector3(-1.35,0,1.25)
 for n in 4:await get_tree().physics_frame
 var key:=InputEventKey.new();key.physical_keycode=KEY_E;key.pressed=true;Input.parse_input_event(key)
 for n in 3:await get_tree().process_frame
 _check(loot.mode=="loot" and loot.chosen=="","actual E key opens persisted empty crate")
 key=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.pressed=true;Input.parse_input_event(key)
 for n in 3:await get_tree().process_frame
 _check(loot.mode=="","actual Escape key closes loot modal")
 key=InputEventKey.new();key.physical_keycode=KEY_I;key.pressed=true;Input.parse_input_event(key)
 for n in 3:await get_tree().process_frame
 _check(loot.mode=="inventory" and loot.rows.has("context_note"),"actual I key opens restored inventory")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(loot.save_path))
 print("ALL RESTART CHECKS PASSED" if failures==0 else "FAILURES: "+str(failures));get_tree().quit(0 if failures==0 else 1)

func _test_atmosphere() -> void:
 _check(atmosphere.dust.size()==48 and atmosphere.lamps.size()>=2,"world-space window dust and practical lamps instantiated")
 _check(atmosphere.curtains.size()>0 and atmosphere.glows.size()>=4,"curtain breeze and floor/light halo effects instantiated")
 var position: Vector3=atmosphere.dust[0].position
 for n in 12:await get_tree().process_frame
 _check(atmosphere.dust[0].position.distance_to(position)>.0001,"dust moves in actual game world")
 atmosphere.set_dusk(true)
 _check(atmosphere.sun.light_energy<.5 and atmosphere.environment.ambient_light_energy<.4,"dusk uses dim cool exterior and warm practical lights")
 atmosphere.set_effects(false)
 _check(not atmosphere.dust[0].visible and not atmosphere.glows[0].visible,"effects switch hides animated particles and glows")
 atmosphere.set_effects(true);atmosphere.set_dusk(false)
 _check(atmosphere.dust[0].visible and atmosphere.sun.light_energy>.7,"effects and daylight restore")
 var preview:=SolidModule.beveled_mesh(Vector3(1,.5,.8))
 _check(preview.get_surface_count()==1 and preview.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>36,"beveled geometry has real chamfer faces")
 _check(FLOOR_NAMES[floor_index]=="ivory_tile" and WALL_NAMES[wall_index]=="plaster_ivory","modern default uses cool tiles and plain painted walls")
 _check(floor_mesh.material_override is ShaderMaterial,"reusable floor material renders world-aligned large tile joints")
 var metal:=Modern.surface(Color("3b4b5b"),true)
 _check(metal.metallic>.3 and metal.roughness<.5,"satin metal has controlled metallic response")
 var led:=Modern.led(Color("71dce8"),.3)
 _check(led.emission_enabled and led.emission_energy_multiplier<1.,"restrained technology LED uses actual emissive material")
 var city: Texture2D=load("res://assets/modern/city_panorama.png")
 _check(city.get_width()>1000,"new reusable city panorama loaded in engine")
 for object in items:
  if object.module_id.begins_with("window_"):
   var panes:=0
   for child in object.get_children():
    if child is MeshInstance3D and child.mesh is QuadMesh:panes+=1
   _check(panes==2,"window contains native metal frame, skyline and glass reflection "+object.module_id)
 for i in 3:
  _layout(i);_check(atmosphere.dust.size()==48 and loot.chests.size()==1,"room switch rebuilds effects and keeps supply chest "+str(i))
 _check(not avatar.shaded and frames.get_animation_speed("walk_down")==8,"illustrated actor preserves its source colours and walks at relaxed animation speed")
 _layout(0);var count: int=atmosphere.lamps.size()
 _check(_place("lamp_floor",Vector3(4,0,.7)) and atmosphere.lamps.size()==count+1,"newly placed lamp joins dynamic lighting")
 var placed=items.back();items.erase(placed);placed.free();atmosphere.rebuild()
 for n in 3:await get_tree().process_frame
 _check(atmosphere.lamps.size()==count,"deleting lamp removes stale dynamic-light reference")
 _save();_restore()
 for n in 3:await get_tree().process_frame
 _check(atmosphere.lamps.size()==count,"layout restore rebuilds live light and curtain references")
 print("ALL ATMOSPHERE CHECKS PASSED" if failures==0 else "FAILURES: "+str(failures));get_tree().quit(0 if failures==0 else 1)

func _test() -> void:
 _check(camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"orthographic 2.5D camera")
 _check(avatar is AnimatedSprite3D and player is CharacterBody3D,"animated 2D actor in actual 3D space")
 _check(catalog.size()==124,"124 reusable assets retained")
 # 真正的约束是：立绘图里的 ground 行必须正好落在地面高度上。
 # 原断言写成 position.y ≈ 100*pixel_size，与脚点换算完全不相干（改之前就是失败的）。
 var cell: Array=character_manifest.frame_size
 var ground_row: float=float(character_manifest.ground[1])
 _check(avatar.billboard==BaseMaterial3D.BILLBOARD_FIXED_Y and absf(avatar.position.y+(float(cell[1])*0.5-ground_row)*avatar.pixel_size-CHARACTER_FLOOR_Y)<.001,"upright sprite keeps feet on the 3D floor")
 for id in catalog:
  var scene: PackedScene=load("res://scenes/modules_3d/"+str(id)+".tscn")
  var module=scene.instantiate();module.position=Vector3(50,0,0);world.add_child(module)
  _check(module.get_child_count()>0,"3D reusable module "+str(id));module.free()
 var start:=player.position
 var key:=InputEventKey.new();key.physical_keycode=KEY_D;key.pressed=true;Input.parse_input_event(key)
 for n in 30:await get_tree().physics_frame
 key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
 _check(player.position.distance_to(start)>0.55,"screen-relative controls move 3D body")
 player.position=Vector3(5.65,0,2.6);player.velocity=Vector3(2,0,0)
 for n in 30:player.velocity=Vector3(2,0,0);player.move_and_slide()
 _check(player.position.x<=5.86,"east wall blocks physical movement")
 player.position=Vector3(-3.4,0,.6)
 for n in 60:player.velocity=Vector3(0,0,-2);player.move_and_slide()
 _check(player.position.z>=-0.02,"3D bed collider blocks actor")
 player.position=Vector3(0,0,.7);player.velocity=Vector3.ZERO
 var bed: Node3D
 for object in items:
  if object.module_id=="bed_navy":bed=object
 var mesh_count:=0
 for child in bed.get_children():
  if child is MeshInstance3D:mesh_count+=1
 _check(mesh_count>13,"bed is solid multi-part geometry with top and sides")
 for state in ["idle","walk","interact"]:
  for dir in ["down","left","up","right"]:_check(frames.get_frame_count(state+"_"+dir)==int(character_manifest.frame_counts[state]),"frames "+state+"_"+dir)
 for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
  player.position=Vector3(0,0,.4);movement=direction;var visited: Dictionary={}
  for n in 30:await get_tree().physics_frame;visited[avatar.frame]=true
  _check(avatar.animation=="walk_"+_direction_name(direction) and visited.size()>=3,"walk frames "+_direction_name(direction))
  _check(facing==_direction_name(direction),"facing follows real displacement "+_direction_name(direction))
  movement=Vector2.ZERO
  for n in 3:await get_tree().physics_frame
  _check(avatar.animation=="idle_"+_direction_name(direction),"idle facing "+_direction_name(direction))
 # 校验接入和距离相位；动作是否自然由原地与实机画面审核。
 player.position=Vector3(0,0,.4);movement=Vector2.UP
 var distance_driven:=true
 var fixed_sprite_position:=avatar.position
 var fixed_sprite_offset:=avatar.offset
 var fixed_root:=true
 for n in 24:
  var previous_position:=player.position
  var previous_phase:=gait_phase
  await get_tree().physics_frame
  var travel:=player.position-previous_position
  var measured_distance:=Vector2(travel.x,travel.z).length()
  var expected_phase:=fposmod(previous_phase+measured_distance/gait_cycle_distance,1.0)
  if absf(wrapf(gait_phase-expected_phase,-.5,.5))>.0001:distance_driven=false
  if avatar.position.distance_to(fixed_sprite_position)>.00001 or avatar.offset.distance_to(fixed_sprite_offset)>.00001:fixed_root=false
 movement=Vector2.ZERO
 _check(distance_driven,"walk phase follows measured travel distance")
 _check(fixed_root,"raised feet do not move the whole sprite root")
 # 步态四：朝向必须跟着真实位移走，而不是跟着按键走
 # 这里自己建一个受控障碍物，才能确定性地造出「斜着顶上去只能沿面滑行」的场景
 var obstacle:=StaticBody3D.new();var obstacle_collision:=CollisionShape3D.new();var obstacle_shape:=BoxShape3D.new()
 obstacle_shape.size=Vector3(3.0,.60,.40);obstacle_collision.shape=obstacle_shape;obstacle.position=Vector3(0,.30,0)
 obstacle.add_child(obstacle_collision);world.add_child(obstacle)
 # 按键给的是「西北」，但实际只能沿障碍物向西滑——两种实现会给出不同朝向
 var diagonal:=Vector3(-1,0,-1).normalized()
 var slide_origin:=Vector3(0,0,1.2)
 player.position=slide_origin
 movement=_character_screen_travel(diagonal).normalized()
 for n in 45:await get_tree().physics_frame
 var slid:=player.position-slide_origin
 var slide_dir:=_direction_name(_character_screen_travel(slid))
 _check(slid.length()>0.25 and facing==slide_dir,"facing follows the real slide direction")
 _check(facing!=_direction_name(movement),"sliding along an obstacle no longer reports the key direction")
 # 正面顶死、一步都动不了时，朝向必须保持不变
 var north:=Vector3(0,0,-1)
 player.position=Vector3(0,0,.40)
 movement=_character_screen_travel(north).normalized()
 for n in 20:await get_tree().physics_frame
 var held:=facing
 for n in 30:await get_tree().physics_frame
 _check(facing==held and player.get_real_velocity().length()<0.06,"facing holds while an obstacle fully blocks the actor")
 movement=Vector2.ZERO
 obstacle.free()
 for n in 3:await get_tree().physics_frame
 player.position=Vector3(0,0,.7)
 _check(not _place("bed_sage",Vector3(0,0,.7)),"placement rejects solid geometry overlapping the actor")
 placement_angle=90
 _check(_place("chair_oak",Vector3(2.4,0,2.5)) and absf(items.back().rotation.y-PI/2)<.001,"placed furniture rotates in 3D")
 placement_angle=0
 _check(_place("whale_plush",Vector3(1.6,0,2.8)),"3D prop placement")
 selected="monitor"
 Input.warp_mouse(get_viewport().get_final_transform()*camera.unproject_position(Vector3(2.4,.97,-2.6)))
 await get_tree().process_frame
 var surface_point:=_mouse_ground()
 _check(surface_point.y>.9 and absf(surface_point.x-2.4)<.25,"camera ray places small props on actual desk height")
 player.position=Vector3(4.8,0,-2.7)
 for n in 3:await get_tree().physics_frame
 _interact();_check(layout_index==1,"3D room door switches layout")
 _layout(0)
 _place("whale_plush",Vector3(1.6,0,2.8))
 var count:=items.size();_check(_save(),"3D layout saves");_layout(1);_check(_restore() and items.size()==count,"3D edited layout restores")
 for i in 3:_layout(i);_check(items.size()>25,"3D layout "+str(i))
 loot.close();catalog_category="all";catalog_page=0;_catalog(true);catalog_buttons[0].pressed.emit();_update_ghost();_check(editing and not panel.visible and ghost.get_child_count()==1,"catalog previews actual 3D placement module")
 print("ALL 2.5D CHECKS PASSED" if failures==0 else "FAILURES: "+str(failures));get_tree().quit(0 if failures==0 else 1)

func _style() -> StyleBox:
 return WhaleSkin.frame()

func _button(text: String,pos: Vector2,size: Vector2,parent: Node,action: Callable) -> Button:
 var button:=Button.new();button.text=text;button.position=pos;button.size=size;button.focus_mode=Control.FOCUS_ALL
 button.add_theme_font_size_override("font_size",20);button.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 button.pressed.connect(action);parent.add_child(button)
 var icon_key:=""
 if text.begins_with("M "):icon_key="map"
 elif text.begins_with("I "):icon_key="backpack"
 elif text.begins_with("Q "):icon_key="chat"
 elif text.begins_with("B "):icon_key="shop"
 elif text=="Esc 菜单":icon_key="settings"
 if icon_key!="":WhaleSkin.button_icon(button,icon_key,24)
 return button

func _ui() -> void:
 ui=CanvasLayer.new();ui.layer=20;add_child(ui)
 var canvas:=Control.new();canvas.theme=WhaleSkin.theme(_game_font());canvas.size=Vector2(1448,1086);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;ui.add_child(canvas)
 UiFit.fill(canvas)
 var brand:=WhaleSkin.panel(canvas,Vector2(48,32),Vector2(450,98))
 brand.name="WorldBrand"
 brand.add_theme_stylebox_override("panel",preload("res://ui/world_hud_skin.gd").frame(true))
 WhaleSkin.mascot(brand,Vector2(12,8),Vector2(88,82))
 WhaleSkin.label(brand,"鲸落港 · 大肥鱼",Vector2(112,13),Vector2(316,34),26,Color("f3f5ff"))
 title=WhaleSkin.label(brand,"",Vector2(113,53),Vector2(316,29),18,Color("c9d6f4"))
 preload("res://ui/world_hud_skin.gd").single_line(title)
 for i in 3:
  var room:=_button(["1 小卧室","2 工作站","3 咖啡角"][i],Vector2(660+i*171,35),Vector2(159,59),canvas,func():_layout(i))
  room.toggle_mode=true;nav_buttons.append(room);room.hide()
  UiFit.pin_design(room,660+i*171,35,159,59)
 var footer:=WhaleSkin.panel(canvas,Vector2(48,961),Vector2(1352,92))
 UiFit.pin_design(footer,48,961,1352,92)
 WhaleSkin.icon(footer,"heart",Vector2(404,33),Vector2(28,28))
 var b_decor:=_button("B 布置",Vector2(711,979),Vector2(140,55),canvas,func():_toggle_decor())
 UiFit.pin_design(b_decor,711,979,140,55)
 var b_save:=_button("F5 保存",Vector2(865,979),Vector2(132,55),canvas,func():_save())
 UiFit.pin_design(b_save,865,979,132,55)
 var info:=WhaleSkin.panel(canvas,Vector2(48,905),Vector2(934,43),"status")
 UiFit.pin_design(info,48,905,934,43)
 hint=WhaleSkin.label(info,"",Vector2(13,7),Vector2(907,29),18)
 var b_menu:=_button("Esc 菜单",Vector2(1214,979),Vector2(161,55),canvas,func():
  if pause_menu:pause_menu.open()
  else:_settings(not settings_panel.visible))
 UiFit.pin_design(b_menu,1214,979,161,55)
 overlay_backdrop=ColorRect.new();overlay_backdrop.color=Color(.08,.15,.30,.42);overlay_backdrop.size=Vector2(1448,1086);canvas.add_child(overlay_backdrop);overlay_backdrop.hide()
 UiFit.fill(overlay_backdrop)
 panel=WhaleSkin.panel(canvas,Vector2(80,125),Vector2(1288,832));panel.hide()
 UiFit.pin_center(panel,1288,125,832)
 dialog=WhaleSkin.panel(canvas,Vector2(80,769),Vector2(1288,182));dialog.hide()
 UiFit.pin_center(dialog,1288,769,182)
 var portrait_frame:=WhaleSkin.panel(dialog,Vector2(18,15),Vector2(163,150),"sky")
 var portrait:=TextureRect.new();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 portrait.texture=frames.get_frame_texture("idle_down",0);portrait.position=Vector2(11,8);portrait.size=Vector2(141,136);portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;portrait_frame.add_child(portrait)
 WhaleSkin.label(dialog,"蓝鲸小助手",Vector2(204,16),Vector2(610,34),25)
 WhaleSkin.icon(dialog,"star",Vector2(1214,18),Vector2(32,32))
 message=WhaleSkin.label(dialog,"",Vector2(204,57),Vector2(1036,111),23)
 settings_panel=WhaleSkin.panel(canvas,Vector2(234,185),Vector2(980,668));settings_panel.hide()
 UiFit.pin_center(settings_panel,980,185,668)
 _build_settings()

func _game_font() -> Font:
 var font:=FontVariation.new();font.base_font=load("res://assets/NotoSansSC.ttf")
 var text_server:=TextServerManager.get_primary_interface();font.variation_opentype={text_server.name_to_tag("wght"):650.0};return font

func _catalog(show: bool) -> void:
 if show:
  if loot:loot.close()
  dialog_open=false;dialog.hide();settings_panel.hide()
 panel.visible=show
 if not show:return
 for child in panel.get_children():
  panel.remove_child(child);child.queue_free()
 catalog_buttons.clear();category_buttons.clear();catalog_filtered.clear()
 for id in catalog_ids:
  if catalog_category=="all" or catalog[id].category==catalog_category:catalog_filtered.append(id)
 var pages:=maxi(1,ceili(catalog_filtered.size()/24.0));catalog_page=clampi(catalog_page,0,pages-1)
 WhaleSkin.mascot(panel,Vector2(22,8),Vector2(64,69))
 WhaleSkin.label(panel,"鲸鱼的家居箱",Vector2(98,18),Vector2(550,37),28)
 WhaleSkin.label(panel,str(catalog_filtered.size())+" 件家具与装饰 · 挑选后放进房间",Vector2(99,57),Vector2(552,28),18,WhaleSkin.MUTED)
 WhaleSkin.label(panel,str(catalog_page+1)+" / "+str(pages)+" 页",Vector2(710,30),Vector2(138,30),20,WhaleSkin.MUTED)
 var prev:=_button("上一页",Vector2(850,20),Vector2(120,50),panel,func():catalog_page=posmod(catalog_page-1,pages);_catalog(true));prev.disabled=pages<=1
 var next:=_button("下一页",Vector2(984,20),Vector2(120,50),panel,func():catalog_page=(catalog_page+1)%pages;_catalog(true));next.disabled=pages<=1
 _button("关闭",Vector2(1118,20),Vector2(140,50),panel,func():panel.hide())
 var categories: Array=[ ["all","全部"],["structure","墙体"],["furniture","家具"],["opening","门窗"],["decor","装饰"],["kitchen","厨房"],["floor","地面"],["street","街区"] ]
 for i in categories.size():
  var key: String=categories[i][0]
  var tab:=_button(categories[i][1],Vector2(25+i*155,98),Vector2(146,44),panel,func():catalog_category=key;catalog_page=0;_catalog(true))
  tab.toggle_mode=true;tab.set_pressed_no_signal(catalog_category==key);category_buttons[key]=tab
 for i in 24:
  var index:=catalog_page*24+i
  if index>=catalog_filtered.size():break
  var id: String=catalog_filtered[index];var m: Dictionary=catalog[id]
  var b:=_button("",Vector2(25+(i%6)*208,163+(i/6)*157),Vector2(196,148),panel,func():
   if m.category=="floor":floor_index=FLOOR_NAMES.find(id.trim_prefix("floor_"));_floor();editing=false
   else:selected=id;editing=true
   panel.hide())
  b.set_meta("module_id",id);catalog_buttons.append(b);WhaleSkin.card_button(b)
  var icon:=TextureRect.new();icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.texture=load(m.get("preview_texture",m.texture));icon.position=Vector2(18,9);icon.size=Vector2(160,101);icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(icon)
  var caption:=WhaleSkin.label(b,m.name,Vector2(6,116),Vector2(184,27),17);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 WhaleSkin.label(panel,"B 结束装饰 · R 旋转 · 右键移除 · F5 保存你的房间",Vector2(34,798),Vector2(1074,25),17,WhaleSkin.MUTED)
 WhaleSkin.icon(panel,"heart",Vector2(1221,794),Vector2(26,27))

func _toggle_decor() -> void:
 if editing:
  editing=false;_catalog(false);ghost.hide();return
 _catalog(not panel.visible)

func _set_actor_front(value: bool) -> void:
 actor_front=value;avatar.no_depth_test=value;avatar.render_priority=127 if value else 0
 avatar.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED if value else SpriteBase3D.ALPHA_CUT_DISCARD
 if is_instance_valid(settings_front_button):settings_front_button.text="人物优先显示："+("开启" if value else "关闭");settings_front_button.set_pressed_no_signal(value)

func _settings(show: bool) -> void:
 if show:
  loot.close();panel.hide();dialog.hide();dialog_open=false;editing=false
  settings_view.refresh()
 settings_panel.visible=show
 if not show and pause_menu:pause_menu.settings_closed()

func _build_settings() -> void:
 settings_view=preload("res://ui/game_settings.gd").new();settings_panel.add_child(settings_view);settings_view.configure(self)

func _build_frames() -> SpriteFrames:
 character_manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
 gait_cycle_distance=maxf(float(character_manifest.get("cycle_distance",1.0)),.01)
 var library := SpriteFrames.new();library.remove_animation("default")
 var direct_states: Dictionary=character_manifest.get("frames_by_state",{})
 var image_cache: Dictionary={}
 for state in ["idle","walk","interact"]:
  var state_frames: Dictionary=direct_states.get(state,{})
  for row in character_manifest.atlas_order.size():
   var direction: String=character_manifest.atlas_order[row]
   var name: String=state+"_"+direction
   library.add_animation(name);library.set_animation_loop(name,state!="interact")
   var direction_fps: float=float(character_manifest.get("walk_fps_by_direction",{}).get(direction,character_manifest.get("walk_fps",8)))
   library.set_animation_speed(name,direction_fps if state=="walk" else (6 if state=="interact" else 1))
   if not direct_states.is_empty():
    # Every entry is one complete picture. Interaction may hold that direction's
    # idle image; a missing walking direction must never borrow a front view.
    var image_paths: Array=state_frames.get(direction,[])
    if image_paths.is_empty() and state=="interact":image_paths=direct_states.get("idle",{}).get(direction,[])
    if image_paths.is_empty():
     push_error("Missing complete character frames: "+name)
     continue
    for entry in image_paths:
     var image_path: String=str(entry.get("path","")) if entry is Dictionary else str(entry)
     if not image_cache.has(image_path):
      if character_manifest.get("runtime_matte_baked",false) and ResourceLoader.exists(image_path):
       image_cache[image_path]=load(image_path)
       var duration: float=float(entry.get("duration",1.0)) if entry is Dictionary else 1.0
       library.add_frame(name,image_cache[image_path],duration)
       continue
      var image:=Image.load_from_file(image_path)
      if image==null or image.is_empty():
       push_error("Cannot read character frame: "+image_path)
       continue
      image_cache[image_path]=ImageTexture.create_from_image(image)
      if direction == "down_left" and image_path.contains("jimeng_v23/"):
       var filename := image_path.get_file()
       var original_path := "res://assets/character/jimeng_v20/down_left/"+filename
       var original := load(original_path) as Texture2D
       if original != null:
        var index := int(filename.get_basename().trim_prefix("walk_"))
        var shifts := [4,2,3,2,2,3,2,2,2,2,2,2]
        safe_matte_sources[image_cache[image_path]] = {
         "original": original,
         "before": load("res://assets/character/jimeng_v21/down_left/"+filename),
         "after": load("res://assets/character/jimeng_v22/down_left/"+filename),
         "shift": shifts[index]
        }
     var duration: float=float(entry.get("duration",1.0)) if entry is Dictionary else 1.0
     library.add_frame(name,image_cache[image_path],duration)
    continue
   # Old four-direction atlases retain their original regions and orientation.
   var count: int=int(character_manifest.frame_counts[state])
   var sources: Dictionary=character_manifest.get("sheet_by_direction",{})
   var state_sources: Dictionary=character_manifest.get("sheet_by_state",{})
   var atlas: Texture2D=load(str(state_sources.get(state,sources.get(direction,character_manifest.get("sheet","")))))
   for col in count:
    var source_col: int=col if state=="walk" else int(character_manifest.idle_columns[row])
    var state_regions: Dictionary=character_manifest.get("regions_by_state",{})
    var region_rows: Array=state_regions.get(state,character_manifest.regions)
    var region: Array=region_rows[row][source_col]
    var texture := AtlasTexture.new();texture.atlas=atlas;texture.region=Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3]));texture.filter_clip=true
    library.add_frame(name,texture,1.0)
 return library

## 指定方向的像素密度（世界单位 / 像素）。同伴立绘必须调这个而不是读 avatar.pixel_size ——
## avatar 的值会随主角朝向变化，直接复制会拿到不确定的大小。
func character_pixel_size(direction: String) -> float:
 # Native video frames can have a different visible resolution. Match their
 # world height with a direction-specific density, without resizing PNG pixels.
 var density: float=float(character_manifest.get("pixel_size_by_direction",{}).get(direction,character_manifest.pixel_size))
 return density * float(DIRECTION_SIZE_FIX.get(direction, 1.0))

## 指定方向的立绘节点世界高度。脚点对齐量是用 pixel_size 算出来的，
## 所以改缩放必须同步重算，否则脚会离地或陷进地面。
func character_ground_offset(direction: String) -> float:
 var cell: Array = character_manifest.frame_size
 var ground: Array = character_manifest.ground
 return CHARACTER_FLOOR_Y + (float(ground[1]) - float(cell[1]) / 2.0) * character_pixel_size(direction)

func _advance_character_gait(travel: Vector3,delta: float) -> void:
 var planar_distance:=Vector2(travel.x,travel.z).length()
 var walking:=planar_distance/maxf(delta,.00001)>.06
 if walking:
  var cycle_distance: float=float(character_manifest.get("cycle_distance_by_direction",{}).get(facing,gait_cycle_distance))
  gait_phase=fposmod(gait_phase+planar_distance/cycle_distance,1.0)
 _set_character_pose(walking)

func _reset_character_gait() -> void:
 gait_phase=0.0
 _set_character_pose(false)

func _set_character_pose(walking: bool) -> void:
 var desired: String=("walk_" if walking else "idle_")+facing
 if not frames.has_animation(desired) or frames.get_frame_count(desired)==0:
  push_error("Character animation has no complete frames: "+desired)
  return
 # Source density and the ground anchor are calibrated together. The front
 # material corrects local proportions while retaining complete native frames.
 avatar.pixel_size=character_pixel_size(facing)
 avatar.position.y=character_ground_offset(facing)
 if avatar.animation!=desired:avatar.animation=desired
 avatar.pause()
 var count:=frames.get_frame_count(desired)
 var progress:=gait_phase*count if walking else 0.0
 avatar.set_frame_and_progress(int(progress)%count,progress-floorf(progress))
 avatar.speed_scale=1.0
 _update_character_material()

func _update_character_material() -> void:
 if not character_material:return
 var frame_texture: Texture2D=frames.get_frame_texture(avatar.animation,avatar.frame)
 var displayed_texture: Texture2D=frame_texture.atlas if frame_texture is AtlasTexture else frame_texture
 if blink_controller:displayed_texture=blink_controller.texture_for(displayed_texture)
 character_material.set_shader_parameter("character_atlas",displayed_texture)
 var repair: Dictionary = safe_matte_sources.get(frame_texture, {})
 character_material.set_shader_parameter("safe_matte_enabled", not repair.is_empty())
 character_material.set_shader_parameter("edge_ink_enabled",not character_manifest.get("runtime_matte_baked",false))
 if not repair.is_empty():
  character_material.set_shader_parameter("original_frame", repair.original)
  character_material.set_shader_parameter("before_holes", repair.before)
  character_material.set_shader_parameter("after_holes", repair.after)
  character_material.set_shader_parameter("original_shift", float(repair.shift))
 # Scene lights and shadows drive brightness; do not multiply a dusk preset.
 character_material.set_shader_parameter("character_tint",Vector3.ONE)
 CharacterSurface.apply(character_material,facing,character_manifest.get("surface_profiles_by_direction",{}).get(facing,{}),avatar.frame,avatar.animation.begins_with("walk_"))
 CharacterProportions.apply(character_material,facing,character_manifest)
 CharacterPalette.apply(character_material,facing,character_manifest)
 # The drawing owns the small hip bob. The world root and billboard offset
 # remain fixed; selecting a raised shoe must never raise the entire character.

func _direction_name(v: Vector2) -> String:
 if v.length_squared()<.000001:return facing
 if character_manifest.get("atlas_order",[]).has("down_left"):
  # Screen-space y points down. Eight equal sectors are centered on the
  # cardinal and diagonal headings, independent of the atlas row order.
  var headings: Array[String]=["right","down_right","down","down_left","left","up_left","up","up_right"]
  var sector:=int(floorf((v.angle()+PI/8.0)/(PI/4.0)))
  return headings[posmod(sector,8)]
 if absf(v.x)>absf(v.y):return "right" if v.x>0 else "left"
 return "down" if v.y>0 else "up"

func _character_screen_travel(travel: Vector3) -> Vector2:
 # Use the rendered screen heading, including the foreshortening caused by
 # the tilted camera, when choosing a complete directional picture.
 return Vector2(travel.dot(camera.global_basis.x),-travel.dot(camera.global_basis.y))

func _screen_direction_to_world(screen_direction: Vector2) -> Vector3:
 if screen_direction.length_squared()<0.000001:return Vector3.ZERO
 var right:=camera.global_basis.x
 var up:=camera.global_basis.y
 # Project the two ground axes into screen space, then invert that 2x2 map.
 var x_axis:=Vector2(right.x,-up.x)
 var z_axis:=Vector2(right.z,-up.z)
 var determinant:=x_axis.x*z_axis.y-z_axis.x*x_axis.y
 if absf(determinant)<0.00001:return Vector3(screen_direction.x,0,screen_direction.y).normalized()
 var target:=screen_direction.normalized()
 var world_x: float=(target.x*z_axis.y-z_axis.x*target.y)/determinant
 var world_z: float=(x_axis.x*target.y-target.x*x_axis.y)/determinant
 return Vector3(world_x,0,world_z).normalized()

func _ui_demo_step() -> Vector2:
 if tick==1:player.position=Vector3(.35,0,1)
 if tick==240:_settings(true)
 if tick==300:foot_debug.visible=true;settings_foot_button.set_pressed_no_signal(true)
 if tick==360:_settings(false);player.position=Vector3(-1.35,0,1.25)
 if tick==390:_interact()
 if tick==440:loot.quantity_plus.pressed.emit()
 if tick==480:loot.take_button.pressed.emit()
 if tick==500:loot.rows.context_note.pressed.emit()
 if tick==510:loot.all_button.pressed.emit()
 if tick==535:loot.rows.stopped_pillow.pressed.emit()
 if tick==570:loot.take_button.pressed.emit()
 if tick==630:loot.close()
 if tick==660:loot.open_bag()
 if tick==700:loot.rows.stopped_pillow.pressed.emit()
 if tick==750:loot.selected_button.pressed.emit()
 if tick==820:loot.rows.context_note.pressed.emit()
 if tick==840:loot.selected_button.pressed.emit()
 if tick==910:loot.close()
 if tick==940:loot.open_note()
 if tick==1080:loot.close()
 if tick==1110:catalog_category="all";catalog_page=0;_catalog(true)
 if tick==1170:catalog_category="furniture";catalog_page=0;_catalog(true)
 if tick==1290:catalog_category="decor";catalog_page=0;_catalog(true)
 if tick==1350:catalog_page=1;_catalog(true)
 if tick==1410:panel.hide();player.position=Vector3(-3.4,0,.72)
 if tick==1480:_interact()
 if tick==1570:dialog.hide();dialog_open=false;_layout(1);foot_debug.visible=false
 if tick==1740:atmosphere.set_dusk(true)
 if tick==1850:_layout(2);atmosphere.set_dusk(false)
 if tick==2170:atmosphere.set_dusk(true)
 if tick==2330:_layout(0);atmosphere.set_dusk(false);_settings(true)
 if tick==2470:_settings(false)
 if tick>=40 and tick<125:return Vector2.RIGHT
 if tick>=135 and tick<215:return Vector2.LEFT
 if tick>=1590 and tick<1710:return Vector2.RIGHT
 if tick>=1880 and tick<2030:return Vector2.RIGHT
 return Vector2.ZERO

func _click_ui(button: Button) -> void:
 var point: Vector2=get_viewport().get_final_transform()*button.get_global_rect().get_center()
 Input.warp_mouse(point)
 var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
 await get_tree().process_frame
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;Input.parse_input_event(event)
 await get_tree().process_frame
 event=event.duplicate();event.pressed=false;Input.parse_input_event(event)
 await get_tree().process_frame

func _test_ui() -> void:
 _layout(0);loot.inventory.clear();loot.stocks=LootController.INITIAL_STOCK.duplicate(true)
 for n in 3:await get_tree().process_frame
 _check(foot_collision.shape is CylinderShape3D and is_equal_approx(foot_collision.shape.radius,FOOT_RADIUS),"actor uses foot-sized circular collider")
 _check(foot_collision.shape.height<.4 and foot_collision.position.y<.2,"head hair and tail are outside physical collider")
 _check(avatar.no_depth_test==actor_front and avatar.render_priority==(127 if actor_front else 0) and avatar.alpha_cut==(SpriteBase3D.ALPHA_CUT_DISABLED if actor_front else SpriteBase3D.ALPHA_CUT_DISCARD),"startup draws the actor exactly as its priority setting says")
 _check(ui.layer==20 and WhaleSkin.frame() is StyleBox,"HUD uses independent upper canvas layer and scalable pixel frame")
 _check(WhaleSkin.INK.v<.5,"dark ink is used on cream and pale blue UI")
 _settings(true);var anchor:=player.position;movement=Vector2.RIGHT
 for n in 5:await get_tree().physics_frame
 _check(player.position.distance_to(anchor)<.01,"settings modal blocks actor movement")
 movement=Vector2.ZERO;settings_front_button.pressed.emit()
 _check(avatar.no_depth_test and avatar.render_priority==127 and avatar.alpha_cut==SpriteBase3D.ALPHA_CUT_DISABLED,"turning actor priority on draws it in front of furniture")
 settings_front_button.pressed.emit();settings_foot_button.pressed.emit()
 _check(not avatar.no_depth_test and avatar.render_priority==0 and foot_debug.visible,"turning actor priority off restores real furniture occlusion")
 foot_debug.visible=false;settings_panel.hide()
 # An elevated obstacle intersects the illustrated head but clears the feet.
 var obstacle:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(1.1,.30,.6);collision.shape=shape;obstacle.position=Vector3(0,1.20,1.85);obstacle.add_child(collision);world.add_child(obstacle)
 player.position=Vector3(0,0,2.72)
 for n in 48:player.velocity=Vector3(0,0,-2);player.move_and_slide();await get_tree().physics_frame
 _check(player.position.z<1.52,"feet pass beneath raised obstacle without hair-height collision")
 obstacle.free()
 player.position=Vector3(-1.35,0,1.25)
 for n in 4:await get_tree().physics_frame
 _check(loot.prompt.visible,"cute proximity card appears near supply chest")
 _interact();await get_tree().process_frame
 _check(loot.mode=="loot" and loot.modal.get_theme_color("font_color","Label")==WhaleSkin.INK,"loot modal uses shared readable whale theme")
 await _click_ui(loot.quantity_plus)
 _check(loot.quantity.value==2,"actual mouse click on quantity plus increments amount")
 await _click_ui(loot.quantity_minus)
 _check(loot.quantity.value==1,"actual mouse click on quantity minus respects minimum")
 await _click_ui(loot.take_button)
 _check(int(loot.inventory.get("token_cracker",0))==1,"actual mouse click transfers item into backpack")
 await _click_ui(loot.bag_button)
 _check(loot.mode=="inventory" and loot.rows.has("token_cracker"),"HUD backpack button opens stored item after transfer")
 for child in loot.modal.get_children():
  if child is Label and child.has_meta("item_description"):_check(child.position.x+child.size.x<loot.modal.size.x-25 and child.size.y<160,"item description wraps within paper detail pane")
 loot.close();catalog_category="all";_catalog(true)
 await _click_ui(category_buttons.furniture)
 _check(catalog_category=="furniture" and catalog_filtered.size()==24,"actual category tab filters furniture without arbitrary mixed pages")
 _check(catalog_buttons.size()==24,"catalog renders all furniture cards using actual module previews")
 await _click_ui(catalog_buttons[0]);_update_ghost()
 _check(editing and not panel.visible and ghost.get_child_count()==1,"actual module card selects a reusable placement preview")
 editing=false;ghost.hide();panel.hide()
 # Capture the same occluded position with depth sorting off and on.
 atmosphere.set_effects(false);ui.hide();player.position=Vector3(-1.2,0,-3.12);avatar.play("idle_down");avatar.stop()
 _set_actor_front(false)
 for n in 3:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var behind: Image=get_viewport().get_texture().get_image()
 behind.save_png("res://tests/人物_普通遮挡.png")
 _set_actor_front(true)
 for n in 3:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var front: Image=get_viewport().get_texture().get_image();front.save_png("res://tests/人物_优先显示.png")
 var logical: Vector2=get_viewport().get_visible_rect().size
 var point: Vector2=camera.unproject_position(player.position+Vector3(0,1.04,0))
 var factor:=Vector2(front.get_width(),front.get_height())/logical;var center:=point*factor
 var changed:=0
 for y in range(maxi(0,int(center.y)-100),mini(front.get_height(),int(center.y)+100)):
  for x in range(maxi(0,int(center.x)-100),mini(front.get_width(),int(center.x)+100)):
   var a:=front.get_pixel(x,y);var b:=behind.get_pixel(x,y)
   if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.18:changed+=1
 _check(changed>800,"actual render restores actor silhouette in front of occluding wardrobe")
 ui.show();_layout(0);atmosphere.set_effects(true)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(loot.save_path))
 print("ALL CUTE UI CHECKS PASSED" if failures==0 else "FAILURES: "+str(failures));get_tree().quit(0 if failures==0 else 1)
