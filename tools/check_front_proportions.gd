extends SceneTree
const OUT := "res://预览/正面比例校正_20261010/"
var game
var failures:=0
var before:=false
var stage:="after"
func _initialize() -> void:
 before="--before" in OS.get_cmdline_user_args()
 stage="before" if before else "after"
 call_deferred("run")
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1;push_error(message)
func shot(filename: String) -> void:
 for n in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+stage+"_"+filename))
func pose(walking: bool) -> void:
 game._set_character_pose(walking)
 if before:
  # Reproduce the saved version's uniform front factor for the same close view.
  game.character_material.set_shader_parameter("proportion_warp_enabled",false)
  if game.facing=="down":
   var cell: Array=game.character_manifest.frame_size
   var ground: Array=game.character_manifest.ground
   game.avatar.pixel_size=float(game.character_manifest.pixel_size)*1.16
   game.avatar.position.y=game.CHARACTER_FLOOR_Y+(float(ground[1])-float(cell[1])*.5)*game.avatar.pixel_size
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-merge" in args or not "--capture-ui" in args or not "--capture-dialogue" in args or DisplayServer.get_name()=="headless":
  push_error("Use rendered isolated test/capture flags");quit(2);return
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.smooth_camera=false
 prefs.values.day_cycle=false;prefs.values.effects=false;prefs.values.music=false;prefs.values.sfx=false
 prefs.starting_place="city";prefs.continue_game=false;prefs.apply_window()
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 for n in 12:await process_frame
 game.dialogue_controller.close();game.atmosphere.set_process(false);game.atmosphere.set_effects(false);game.atmosphere.set_time(12)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 if game.dialogue_controller.companion:game.dialogue_controller.companion.hide()
 game.set_physics_process(false);game.overview_mode=false;game.view_size=6
 var origin:=Vector3(0,0,8)
 game.player.position=origin;game.player.velocity=Vector3.ZERO;game.view_center=origin;game.camera.size=game.view_size;game._camera()
 game.player.hide();await shot("empty.png");game.player.show()
 for direction in game.character_manifest.atlas_order:
  game.facing=direction;game.gait_phase=.25;pose(true)
  await shot("direction_"+direction+".png")
 game.facing="down";game.gait_phase=0;pose(true)
 var fixed_position: Vector3=game.avatar.position
 var fixed_density: float=game.avatar.pixel_size
 var fixed_offset: Vector2=game.avatar.offset
 var stable:=true
 var count: int=game.frames.get_frame_count("walk_down")
 for i in count:
  game.gait_phase=(float(i)+.05)/count;pose(true)
  if game.avatar.position!=fixed_position or game.avatar.offset!=fixed_offset or not is_equal_approx(game.avatar.pixel_size,fixed_density):stable=false
  await shot("walk_%02d.png"%i)
 pose(false);await shot("idle.png")
 if not before:
  check(stable and count==12,"all twelve source poses retain a fixed root and ground anchor")
  check(is_equal_approx(game.avatar.pixel_size,float(game.character_manifest.pixel_size)),"front view no longer has the old uniform 16 percent enlargement")
  check(game.character_material.get_shader_parameter("proportion_warp_enabled"),"standing uses the same local proportion curve as walking")
  var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://备份/20261010_正面比例校正前/manifest.json"))
  check(game.character_manifest.frames_by_state==old.frames_by_state,"every original high-resolution picture and its alpha mask remains unchanged")
  for direction in ["down_left","up_left","up_right","up"]:
   game.facing=direction;pose(true)
   check(not game.character_material.get_shader_parameter("proportion_warp_enabled"),"local front warp clears when turning to "+direction)
  game.facing="down";pose(true)
  game.player.position=origin;game.facing_accum=Vector2.ZERO;game.facing_timer=0;game.gait_phase=0
  game.movement=Vector2.DOWN;game.set_physics_process(true)
  for n in 24:await physics_frame
  game.set_physics_process(false)
  check(game.player.position.distance_to(origin)>.2 and game.facing=="down" and game.avatar.animation=="walk_down","actual forward movement uses the locally corrected material")
  await shot("actual_movement.png")
  game.movement=Vector2.ZERO;pose(false)
  check(game.avatar.animation=="idle_down" and game.character_material.get_shader_parameter("proportion_warp_enabled"),"stopping retains matching standing proportions")
  game._travel("apt_2");game.set_physics_process(false);game.player.position=Vector3.ZERO
  game.view_center=Vector3.ZERO;game.overview_mode=false;game.view_size=8;game.camera.size=game.view_size;game._camera()
  game.facing="down";game.gait_phase=.25;pose(true)
  for node in get_nodes_in_group("floor_room_labels"):node.hide()
  await shot("interior.png")
  if game.dialogue_controller.companion:
   var sprites=game.dialogue_controller.companion.find_children("*","Sprite3D",true,false)
   check(sprites.size()>0 and sprites[0].material_override.get_shader_parameter("proportion_warp_enabled"),"front-facing companion uses the same corrected proportions")
 print("FRONT PROPORTION ",stage," CHECK COMPLETE; FAILURES ",failures)
 quit(0 if failures==0 else 1)
