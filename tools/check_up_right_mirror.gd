extends SceneTree
const OUT := "res://预览/右上镜像替换_20261010/"
var game
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,text: String) -> void:
 print("PASS " if ok else "FAIL ",text)
 if not ok:failures+=1;push_error(text)
func shot(filename: String) -> void:
 for n in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+filename))
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-merge" in args or not "--capture-ui" in args or not "--capture-dialogue" in args or DisplayServer.get_name()=="headless":
  push_error("Use rendered isolated test/capture flags");quit(2);return
 AudioServer.set_bus_mute(0,true)
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
 var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://备份/20261010_右上镜像替换前/manifest.json"))
 var intact:=true
 for state in before.frames_by_state:
  for direction in before.atlas_order:
   if direction!="up_right" and manifest.frames_by_state[state][direction]!=before.frames_by_state[state][direction]:intact=false
 check(intact,"all seven existing direction sequences retain their exact resources")
 var paths: Array=manifest.frames_by_state.walk.up_right
 check(paths.size()==26,"mirrored up_right contains the complete 26-frame video cycle")
 var valid:=0
 for path in paths:
  var texture:=load(str(path)) as Texture2D
  var mask:=load(str(path).get_base_dir()+"/masks/"+str(path).get_file()) as Texture2D
  if texture!=null and texture.resource_path==path and texture.get_size()==Vector2(1024,1152) and texture.get_image().has_mipmaps() and mask!=null and mask.get_size()==texture.get_size():valid+=1
 check(valid==26,"all mirrored full-frame textures and masks import at native size with mipmaps")
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
 game.set_physics_process(false);game.overview_mode=false;game.view_size=8
 var origin:=Vector3(0,0,8)
 var diagonal_y:=0.0
 for direction in ["up_left","up_right"]:
  game.player.position=origin;game.player.velocity=Vector3.ZERO
  game.facing=direction;game.facing_accum=Vector2.ZERO;game.facing_timer=0;game.gait_phase=0
  game.view_center=origin;game._camera()
  game.movement=Vector2(-1,-1).normalized() if direction=="up_left" else Vector2(1,-1).normalized()
  game.set_physics_process(true)
  for n in 24:await physics_frame
  game.set_physics_process(false)
  check(game.player.position.distance_to(origin)>.2 and game.facing==direction and game.avatar.animation=="walk_"+direction,"actual diagonal movement selects "+direction)
  await shot("actual_"+direction+".png")
  game.movement=Vector2.ZERO;game._set_character_pose(false)
  var standing: Texture2D=game.frames.get_frame_texture("idle_"+direction,0)
  check(standing.resource_path==manifest.frames_by_state.idle[direction][0],"stopping retains matching standing material for "+direction)
  if direction=="up_left":diagonal_y=game.avatar.position.y
  else:check(is_equal_approx(diagonal_y,game.avatar.position.y),"left and right diagonals share the exact world size and floor anchor")
 game.facing="up_right";game.gait_phase=0;game._set_character_pose(true)
 var root_position: Vector3=game.avatar.position
 var correct:=true
 for i in 26:
  game.gait_phase=(float(i)+.05)/26;game._set_character_pose(true)
  var texture: Texture2D=game.frames.get_frame_texture(game.avatar.animation,game.avatar.frame)
  if texture.resource_path!=paths[i] or game.avatar.position!=root_position:correct=false
  if i in [0,4,8,13,18,23]:await shot("walk_%02d.png"%i)
 check(correct,"all mirrored poses select in order with a fixed sprite root")
 var right_head: Vector4=game.character_material.get_shader_parameter("head_profile")
 check(is_equal_approx(right_head.x,.496),"head lighting region mirrors horizontally with the artwork")
 var right_tail: Vector4=game.character_material.get_shader_parameter("tail_profile")
 check(is_equal_approx(right_tail.x,.402),"tail lighting region mirrors horizontally with the artwork")
 game.facing="up_left";game._set_character_pose(true)
 var left_head: Vector4=game.character_material.get_shader_parameter("head_profile")
 check(is_equal_approx(left_head.x,.504),"turning back restores left lighting regions")
 check(not game.character_material.get_shader_parameter("safe_matte_enabled") and not game.character_material.get_shader_parameter("edge_ink_enabled"),"fixed mirrored alpha avoids a second runtime matte or ink pass")
 game._travel("apt_2");game.set_physics_process(false);game.player.position=Vector3.ZERO
 game.view_center=Vector3.ZERO;game.overview_mode=false;game.view_size=8;game._camera()
 game.facing="up_right";game.gait_phase=.5;game._set_character_pose(true)
 for node in get_nodes_in_group("floor_room_labels"):node.hide()
 await shot("interior_up_right.png")
 print("UP RIGHT MIRROR CHECK COMPLETE; FAILURES ",failures)
 quit(0 if failures==0 else 1)
