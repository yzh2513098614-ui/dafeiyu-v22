extends Node
## Real grounded movement uses the same feet, silhouette and landing logic as pack26.
const Scene=preload("res://district/harbor_terraces.gd")
var game
var level: Node3D
var cutaway:=true
var spawn:=Vector3(-2.4,.04,2.0)
var boats: Array[Node3D]=[]
var sea_clock:=0.0
var gulls: Array[Node3D]=[]
var facilities: Array[Node3D]=[]

func configure(owner_game) -> void:game=owner_game

func is_active() -> bool:return is_instance_valid(level) and game.location_id=="story_harbor"

func build() -> Dictionary:
 var result: Dictionary=Scene.build(game);level=result.level;spawn=result.spawn;cutaway=HarborPrefs.values.follow;boats.clear();gulls.clear();facilities.clear();sea_clock=0.0
 for node: Node3D in level.get_node("Sea").get_children():
  if node.has_meta("boat_origin"):boats.append(node)
  elif node.has_meta("harbor_gull"):gulls.append(node)
 for node: Node3D in game.world.get_children():
  if node.has_meta("harbor_facility"):facilities.append(node)
 var slabs: Array=level.get_meta("walkable_slabs",[])
 game.player.set_meta("floor_slabs",slabs);game.silhouette_body.set_meta("floor_slabs",slabs)
 game.player.motion_mode=CharacterBody3D.MOTION_MODE_GROUNDED;game.player.collision_layer=4;game.player.collision_mask=3
 game.player.floor_snap_length=.35;game.player.floor_max_angle=deg_to_rad(48);game.player.floor_constant_speed=true
 game._configure_character_collision(true)
 return result

func leave() -> void:
 if not is_instance_valid(level):return
 for slab in game.silhouette_body.get_meta("floor_slabs",[]):
  if is_instance_valid(slab):game.silhouette_body.remove_collision_exception_with(slab)
 game.player.remove_meta("floor_slabs");game.silhouette_body.remove_meta("floor_slabs")
 game.player.motion_mode=CharacterBody3D.MOTION_MODE_FLOATING;game.player.collision_mask=1
 game._configure_character_collision(false);game.character_material.set_shader_parameter("floor_height",game.CHARACTER_FLOOR_Y)
 level=null;boats.clear();gulls.clear();facilities.clear()

func _process(delta: float) -> void:
 if not is_active() or (game.pause_menu and game.pause_menu.active):return
 sea_clock+=delta
 for i in boats.size():
  var boat: Node3D=boats[i]
  boat.position=boat.get_meta("boat_origin")+boat.get_meta("moor_offset",Vector3.ZERO)+Vector3.UP*sin(sea_clock*.85+i*1.7)*.045
  boat.rotation.z=sin(sea_clock*.65+i)*.012
 for gull in gulls:
  var phase: float=sea_clock*.19+float(gull.get_meta("phase"))
  gull.position=Vector3(-28+cos(phase)*5.4,2.5+sin(phase*1.7)*.45,3+sin(phase)*8.0)
  gull.rotation.y=-phase+PI;gull.rotation.z=sin(phase)*.10
  var flap: float=sin(sea_clock*3.2+phase)*.22
  gull.get_node("LeftWing").rotation.z=flap;gull.get_node("RightWing").rotation.z=-flap

func overview_center() -> Vector3:return Vector3(-4.0,1.0,-1.0)

func set_layers() -> void:
 if not is_active():return
 var reveal: bool=not cutaway or game.player.position.y>2.95
 level.get_node("Upper").visible=reveal
 for facility in facilities:facility.visible=reveal or float(facility.get_meta("floor_height",0.0))<1.0
 # Visibility changes never disable the floor, railing or furniture colliders.

func handle_input(event: InputEvent) -> bool:
 if not is_active() or not event is InputEventKey or not event.pressed or event.echo:return false
 if event.physical_keycode!=KEY_H:return false
 if game.transitioning or game.dialog_open or game.map_panel.visible or game.settings_panel.visible or game.loot.blocked():return false
 if game.pause_menu and game.pause_menu.active:return false
 if game.character_controller and game.character_controller.active:return false
 cutaway=not cutaway;set_layers();return true

func physics(delta: float) -> void:
 var before: Vector3=game.player.position
 var free: bool=not game.transitioning and not game.dialog_open and not game.panel.visible and not game.settings_panel.visible and not game.loot.blocked() and not game.map_panel.visible and not game.editing
 var direction: Vector2=game.movement if free else Vector2.ZERO
 if free:direction+=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
 var planar: Vector3=game.character_controller.movement_velocity(direction,delta) if game.character_controller else game._screen_direction_to_world(direction)*game.SPEED
 game.player.velocity.x=planar.x;game.player.velocity.z=planar.z
 game.player.velocity.y=0.0 if game.player.is_on_floor() else game.player.velocity.y-18.0*delta
 game._move_character(delta,true)
 var travel: Vector3=game.player.position-before
 game.facing_accum+=game._character_screen_travel(travel);game.facing_timer+=delta
 if game.facing_timer>=game.FACING_WINDOW:
  if game.facing_accum.length()>game.FACING_MIN_TRAVEL:game.facing=game._direction_name(game.facing_accum)
  game.facing_accum=Vector2.ZERO;game.facing_timer=0.0
 game._advance_character_gait(travel,delta)
 game.character_material.set_shader_parameter("floor_height",game.player.global_position.y+game.CHARACTER_FLOOR_Y)
 var desired: Vector3=overview_center() if game.overview_mode else game.player.position
 game.view_center=game.view_center.lerp(desired,1.0-exp(-delta*7.0) if HarborPrefs.values.smooth_camera else 1.0)
 game.camera.size=lerpf(game.camera.size,game.view_size,1.0-exp(-delta*8.0));game._camera();game._refresh_zone();set_layers()
 if game.player.position.y>.65 and game.player.position.y<2.98:
  var west: bool=game.player.position.x<0
  game.zone_label.text="当前：1F ↔ 2F · "+("西侧海景楼梯" if west else "东侧回港楼梯")
 if game.character_controller:game.character_controller.advance(delta,before)
 game.nearest_portal={};var best:=1.25
 for portal: Dictionary in game.portals:
  if absf(portal.pos.y-game.player.position.y)>1.0:continue
  var distance: float=Vector2(portal.pos.x,portal.pos.z).distance_to(Vector2(game.player.position.x,game.player.position.z))
  if distance<best:game.nearest_portal=portal;best=distance
 if game.destination_hint:game.destination_hint.hide()
 game.view_button.visible=free;game.zone_label.visible=free;game.clock_panel.visible=free
 game.clock_label.text=game.atmosphere.clock_text();game._route_frame(free)
 if free:game.hint.text="WASD 漫步 · 沿楼梯步行上下层 · H 上层切面 · Z 总览 · E 设施交互 · M 导览"
 if game.player.position.y< -3.0:
  game.player.position=spawn;game.player.velocity=Vector3.ZERO;game._queue_collision_recovery(true)
 if game.life_booted:
  game.autosave_clock+=delta
  if game.autosave_clock>7.0 and free:game.autosave_clock=0;game._save()
