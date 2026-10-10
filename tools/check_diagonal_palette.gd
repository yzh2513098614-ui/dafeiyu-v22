extends SceneTree
const OUT := "res://预览/斜后方向校色_20261010/"
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
  game.CharacterPalette.apply(game.character_material,"up",game.character_manifest)
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
 game.player.hide();await shot("day_empty.png");game.player.show()
 for direction in game.character_manifest.atlas_order:
  game.facing=direction;game.gait_phase=.25;pose(true)
  await shot("day_"+direction+".png")
 var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://备份/20261010_斜后方向校色前/assets/character/manifest.json"))
 if not before:
  check(game.character_manifest.frames_by_state==old.frames_by_state,"all native source image sequences remain unchanged")
  check(game.character_manifest.palette_match_by_direction.up_left==game.character_manifest.palette_match_by_direction.up_right,"mirrored diagonals share exactly the same pigment and outline settings")
 for direction in ["up_left","up_right"]:
  game.facing=direction;game.gait_phase=0;pose(true)
  var density: float=game.avatar.pixel_size
  var anchor: Vector3=game.avatar.position
  var gamma: Vector3=game.character_material.get_shader_parameter("hair_palette_gamma")
  var stable:=true
  var count: int=game.frames.get_frame_count("walk_"+direction)
  for i in count:
   game.gait_phase=(float(i)+.05)/count;pose(true)
   if game.avatar.pixel_size!=density or game.avatar.position!=anchor or game.character_material.get_shader_parameter("hair_palette_gamma")!=gamma:stable=false
   if not before or i in [0,4,8,13,18,23]:await shot(direction+"_walk_%02d.png"%i)
  if not before:
   check(stable and count==26,"all 26 "+direction+" poses retain a fixed palette, size and ground anchor")
  pose(false);await shot("idle_"+direction+".png")
  if not before:
   check(game.character_material.get_shader_parameter("palette_match_enabled"),direction+" standing retains matching pigment treatment")
   check(is_equal_approx(float(game.character_material.get_shader_parameter("soft_contour_strength")),.58),direction+" receives the deeper blue contour")
   check(not game.character_material.get_shader_parameter("safe_matte_enabled") and not game.character_material.get_shader_parameter("edge_ink_enabled"),direction+" fixed alpha does not get re-keyed or eroded")
 if not before:
  for direction in ["up","down","down_left","down_right","left","right"]:
   game.facing=direction;pose(true)
   check(not game.character_material.get_shader_parameter("palette_match_enabled") and game.character_material.get_shader_parameter("hair_palette_gamma")==Vector3.ONE and is_equal_approx(float(game.character_material.get_shader_parameter("soft_contour_strength")),.42),"turning to "+direction+" restores its original palette and contour")
  game.facing="down";pose(true)
  check(game.character_material.get_shader_parameter("proportion_warp_enabled"),"front local proportion correction remains enabled")
 game.atmosphere.set_time(0)
 game.player.hide();await shot("night_empty.png");game.player.show()
 for direction in ["up_left","up_right","up"]:
  game.facing=direction;game.gait_phase=.25;pose(true);await shot("night_"+direction+".png")
 game.atmosphere.set_time(12)
 if not before:
  for direction in ["up_left","up_right"]:
   game.player.position=origin;game.facing=direction;game.facing_accum=Vector2.ZERO;game.facing_timer=0;game.gait_phase=0
   game.movement=Vector2(-1,-1).normalized() if direction=="up_left" else Vector2(1,-1).normalized()
   game.set_physics_process(true)
   for n in 24:await physics_frame
   game.set_physics_process(false)
   check(game.player.position.distance_to(origin)>.2 and game.facing==direction and game.avatar.animation=="walk_"+direction and game.character_material.get_shader_parameter("palette_match_enabled"),"actual movement uses corrected "+direction+" material")
   await shot("actual_"+direction+".png")
  game.movement=Vector2.ZERO
  game._travel("apt_2");game.set_physics_process(false);game.player.position=Vector3.ZERO
  game.view_center=Vector3.ZERO;game.overview_mode=false;game.view_size=6;game.camera.size=game.view_size;game._camera()
  game.facing="up_right";game.gait_phase=.25;pose(true)
  for node in get_nodes_in_group("floor_room_labels"):node.hide()
  await shot("interior_up_right.png")
  if game.dialogue_controller.companion:
   var sprites=game.dialogue_controller.companion.find_children("*","Sprite3D",true,false)
   check(sprites.size()>0 and not sprites[0].material_override.get_shader_parameter("palette_match_enabled"),"front-facing companion restores its original palette when cloned after diagonal movement")
 print("DIAGONAL PALETTE ",stage," CHECK COMPLETE; FAILURES ",failures)
 quit(0 if failures==0 else 1)
