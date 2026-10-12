extends SceneTree
## Production renderer, isolated saves, fixed camera and silent audio.
const OUT := "res://预览/正面头身比例_20261012/"
var game
var failures := 0
var checks := 0

func _initialize() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 checks += 1
 if ok:print("PASS ",message)
 else:failures += 1;push_error(message)

func shot(name: String) -> void:
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name+".png"))

func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json"
 prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.smooth_camera=false
 prefs.values.day_cycle=false;prefs.values.effects=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false
 prefs.starting_place="city";prefs.continue_game=false;prefs.apply_window()
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 var before_only := "--before-only" in OS.get_cmdline_user_args()
 if before_only:
  var front: Dictionary=game.character_manifest.proportion_warp_by_direction.down
  front.head_height=0.0;front.head_width=0.0;front.top_padding=0.0;front.body_width=0.12
 for i in 12:await process_frame
 game.dialogue_controller.close();game.atmosphere.set_process(false);game.atmosphere.set_effects(false);game.atmosphere.set_time(12)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 if game.dialogue_controller.companion:game.dialogue_controller.companion.hide()
 game.set_physics_process(false);game.overview_mode=false;game.view_size=6
 var origin:=Vector3(0,0,8)
 game.player.position=origin;game.player.velocity=Vector3.ZERO;game.view_center=origin;game.camera.size=game.view_size;game._camera()
 game.player.hide();await shot("empty");game.player.show()
 var stage := "before" if before_only else "after"
 for direction in game.character_manifest.atlas_order:
  game.facing=direction;game.gait_phase=.25;game._set_character_pose(true)
  await shot(stage+"_"+direction)
 if before_only:quit();return
 game.facing="down";game.gait_phase=0;game._set_character_pose(true)
 var fixed_position: Vector3=game.avatar.position
 var fixed_density: float=game.avatar.pixel_size
 var fixed_offset: Vector2=game.avatar.offset
 for i in game.frames.get_frame_count("walk_down"):
  game.gait_phase=(float(i)+.05)/game.frames.get_frame_count("walk_down");game._set_character_pose(true)
  check(game.avatar.position==fixed_position and game.avatar.offset==fixed_offset and is_equal_approx(game.avatar.pixel_size,fixed_density),"front frame %d preserves root, scale and foot anchor"%i)
  await shot("after_walk_%02d"%i)
 game._set_character_pose(false);await shot("after_idle")
 check(game.character_material.get_shader_parameter("proportion_warp_enabled"),"idle retains front proportions")
 check(float(game.character_material.get_shader_parameter("proportion_head_width"))>0,"front material enlarges head")
 if game.dialogue_controller.companion:
  var sprites=game.dialogue_controller.companion.find_children("*","Sprite3D",true,false)
  check(sprites.size()>0 and is_equal_approx(float(sprites[0].material_override.get_shader_parameter("proportion_head_width")),.18),"front companion shares enlarged head proportions")
 for direction in game.character_manifest.atlas_order:
  if direction=="down":continue
  game.facing=direction;game._set_character_pose(true)
  check(not game.character_material.get_shader_parameter("proportion_warp_enabled"),"other direction remains native: "+direction)
 game.facing="down";game.gait_phase=0;game.facing_accum=Vector2.ZERO;game.facing_timer=0
 game.movement=Vector2.DOWN;game.set_physics_process(true)
 for i in 24:await physics_frame
 game.set_physics_process(false)
 check(game.player.position.distance_to(origin)>.2 and game.avatar.animation=="walk_down" and game.character_material.get_shader_parameter("proportion_warp_enabled"),"actual forward movement keeps enlarged head proportions")
 await shot("after_actual_movement")
 game.movement=Vector2.ZERO;game._set_character_pose(false)
 check(game.avatar.animation=="idle_down" and game.character_material.get_shader_parameter("proportion_warp_enabled"),"stopping keeps matching front proportions")
 game._travel("apt_2");game.set_physics_process(false)
 for i in 4:await physics_frame
 check(game.CollisionSafety.clear_at(game.player,game.player.global_position),"enlarged silhouette fits interior entrance")
 game.view_center=game.player.position;game.view_size=8;game.camera.size=8;game._camera()
 game.facing="down";game._set_character_pose(false);await shot("after_interior")
 print("FRONT UPPER BODY: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
