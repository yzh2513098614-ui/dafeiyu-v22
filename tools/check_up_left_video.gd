extends SceneTree
## Real scene verification with isolated settings and saves.
const OUT := "res://预览/左上视频替换_20261010/"
var game
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1;push_error(message)
func shot(filename: String) -> void:
 for n in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+filename))
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-merge" in args or not "--capture-ui" in args or not "--capture-dialogue" in args or DisplayServer.get_name()=="headless":
  push_error("Use a rendered window with isolated test and capture flags");quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 AudioServer.set_bus_mute(0,true)
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
 var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://备份/20261010_左上视频替换前/manifest.json"))
 var intact:=true
 for state in previous.frames_by_state:
  for direction in previous.atlas_order:
   var approved_mirror: bool=direction=="up_right" and manifest.get("mirrored_directions",{}).get("up_right","")=="up_left"
   if direction!="up_left" and not approved_mirror and manifest.frames_by_state[state][direction]!=previous.frames_by_state[state][direction]:intact=false
 check(intact,"directions outside the video and its approved mirror retain their exact resource sequences")
 var paths: Array=manifest.frames_by_state.walk.up_left
 check(paths.size()==26,"26 consecutive video frames replace the old four-frame up_left cycle")
 var good:=0
 var mipmapped:=0
 for path in paths:
  var texture:=load(str(path)) as Texture2D
  var mask:=load(str(path).get_base_dir()+"/masks/"+str(path).get_file()) as Texture2D
  if texture!=null and mask!=null and texture.get_size()==Vector2(1024,1152) and texture.resource_path==path and mask.get_size()==texture.get_size():good+=1
  if texture!=null and texture.get_image().has_mipmaps():mipmapped+=1
 check(good==26,"all complete PNGs and fixed alpha masks are imported native-size resources")
 check(mipmapped==26,"all walking textures have mipmaps for stable distant sampling")
 var info: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/up_left_video_20261010/extraction.json"))
 var green:=0
 for record in info.records:green+=int(record.green_pixels_remaining)
 check(green==0,"no visible green-screen chroma remains in the installed cycle")
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.smooth_camera=false
 prefs.values.day_cycle=false;prefs.values.effects=false;prefs.values.music=false;prefs.values.sfx=false
 prefs.starting_place="city";prefs.continue_game=false;prefs.apply_window()
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 for n in 12:await process_frame
 game.dialogue_controller.close();game.atmosphere.set_effects(false);game.atmosphere.set_process(false);game.atmosphere.set_time(12)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 game.set_physics_process(false);game.overview_mode=false;game.view_size=8
 var origin:=Vector3(0,0,8)
 game.player.position=origin;game.view_center=origin;game._camera()
 check(game.frames.get_frame_count("walk_up_left")==26,"live SpriteFrames loads the new 26-frame walk")
 check(is_equal_approx(game.frames.get_animation_speed("walk_up_left"),24),"source 24 fps playback metadata retained")
 game.facing="up_left";game.gait_phase=0;game._set_character_pose(true)
 check(game.character_material.get_shader_parameter("head_split")==Vector2(.68,.75),"lighting regions match the new source's native canvas placement")
 var position: Vector3=game.avatar.position
 var density: float=game.avatar.pixel_size
 var offset: Vector2=game.avatar.offset
 var fixed:=true
 var distinct: Dictionary={}
 var correct_paths:=true
 for i in 26:
  game.gait_phase=(float(i)+.05)/26.0;game._set_character_pose(true)
  var texture: Texture2D=game.frames.get_frame_texture(game.avatar.animation,game.avatar.frame)
  distinct[texture.resource_path]=true
  if texture.resource_path!=paths[i]:correct_paths=false
  if game.avatar.position!=position or game.avatar.offset!=offset or not is_equal_approx(game.avatar.pixel_size,density):fixed=false
  if i in [0,3,6,10,13,17,20,23]:await shot("city_walk_%02d.png"%i)
 check(correct_paths and distinct.size()==26,"movement phase visits every source video pose in order")
 check(fixed,"sprite root, floor anchor and size stay fixed through raised-foot poses")
 var target_height:=977.0*.0022
 check(absf(float(info.median_visible_height)*density-target_height)<.005,"new native pixels match the previous world height")
 check(not game.character_material.get_shader_parameter("safe_matte_enabled"),"fixed alpha needs no runtime white key")
 check(not game.character_material.get_shader_parameter("edge_ink_enabled"),"no doubled runtime ink border")
 # Exercise actual movement, rather than merely selecting a preview texture.
 game.player.position=origin;game.facing_accum=Vector2.ZERO;game.facing_timer=0;game.gait_phase=0
 game.movement=Vector2(-1,-1).normalized();game.set_physics_process(true)
 for n in 24:await physics_frame
 game.set_physics_process(false)
 check(game.player.position.distance_to(origin)>.2 and game.facing=="up_left" and game.avatar.animation=="walk_up_left","actual diagonal movement selects the new video direction")
 await shot("actual_up_left_movement.png")
 game.movement=Vector2.ZERO;game._set_character_pose(false)
 check(game.avatar.animation=="idle_up_left" and game.frames.get_frame_texture("idle_up_left",0).resource_path==paths[9],"stopping retains a matching video standing pose")
 await shot("city_idle.png")
 game._travel("apt_2");game.set_physics_process(false);game.player.position=Vector3.ZERO
 game.view_center=Vector3.ZERO;game.overview_mode=false;game.view_size=8;game._camera()
 for node in get_nodes_in_group("floor_room_labels"):node.hide()
 game.facing="up_left"
 for i in [0,9,16,23]:
  game.gait_phase=(float(i)+.05)/26;game._set_character_pose(true);await shot("interior_walk_%02d.png"%i)
 game.atmosphere.set_time(20);game.gait_phase=.52;game._set_character_pose(true)
 await shot("interior_night.png")
 print("UP LEFT VIDEO CHECK COMPLETE; FAILURES ",failures)
 quit(0 if failures==0 else 1)
