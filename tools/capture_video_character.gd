extends SceneTree
## Technical contact sheet and actual rendered walks. Never loads player saves.
const OUTPUT:="res://预览/人物去白边_v23/"
const DIRECTIONS: Array[String]=["down","down_left","left","up_left","up","up_right","right","down_right"]
const VECTORS: Array[Vector2]=[Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1),Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1)]
var game
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
 if not "--capture-ui" in OS.get_cmdline_user_args() or not "--capture-dialogue" in OS.get_cmdline_user_args():
  push_error("Capture requires both --capture-ui and --capture-dialogue for isolated preview state")
  quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
 if metadata.atlas_order.size()!=8 or not metadata.has("frames_by_state"):
  push_error("Eight-direction complete PNG material must be installed before capture")
  quit(1);return
 await contact_sheet(metadata)
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.smooth_camera=false
 prefs.starting_place="city";prefs.continue_game=false;prefs.apply_window()
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 for n in 12:await process_frame
 game.dialogue_controller.close();game.atmosphere.set_effects(false)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for region in ["city","apt_2"]:
  game._travel(region)
  for node in get_nodes_in_group("floor_room_labels"):node.hide()
  game.overview_mode=false;game.view_size=8.0
  var origin:=Vector3(0,0,8) if region=="city" else Vector3(0,0,0)
  for i in DIRECTIONS.size():
   game.set_physics_process(false);game.player.position=origin;game.player.velocity=Vector3.ZERO
   game.facing=DIRECTIONS[i];game.facing_accum=Vector2.ZERO;game.facing_timer=0.0;game.gait_phase=0.0
   game.view_center=Vector3(origin.x,0,origin.z);game.camera.size=game.view_size;game._camera()
   # The game inverts the camera projection, so this is the exact rendered
   # heading requested by the player, including diagonal movement.
   game.movement=VECTORS[i].normalized()
   game.set_physics_process(true)
   for n in 24:await physics_frame
   game.set_physics_process(false)
   if game.facing!=DIRECTIONS[i] or game.avatar.animation!="walk_"+DIRECTIONS[i]:
    failures+=1;push_error("Walk capture did not reach requested direction: "+region+"/"+DIRECTIONS[i])
   await shot(("02_街道_" if region=="city" else "03_室内_")+DIRECTIONS[i]+".png")
   game.movement=Vector2.ZERO
  game.facing="down";game._set_character_pose(false)
  await shot(("04_街道_" if region=="city" else "05_室内_")+"正面站姿.png")
 print("ACTUAL EIGHT DIRECTION CAPTURES COMPLETE, FAILURES ",failures)
 quit(0 if failures==0 else 1)
func contact_sheet(metadata: Dictionary) -> void:
 var viewport:=SubViewport.new();viewport.disable_3d=true;viewport.size=Vector2i(2048,1536)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var background:=ColorRect.new();background.color=Color("263649");background.size=Vector2(2048,1536);viewport.add_child(background)
 var font: Font=load("res://assets/NotoSansSC.ttf")
 for i in DIRECTIONS.size():
  var origin:=Vector2(float(i%4)*512,floorf(float(i)/4.0)*768)
  var paths: Array=metadata.frames_by_state.walk.get(DIRECTIONS[i],[])
  if paths.is_empty():
   failures+=1;push_error("No original PNG for "+DIRECTIONS[i]);continue
  var entry=paths[0]
  var path: String=str(entry.get("path","")) if entry is Dictionary else str(entry)
  var texture:=ImageTexture.create_from_image(Image.load_from_file(path))
  var picture:=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  picture.texture=texture;picture.position=origin+Vector2(8,36);picture.size=Vector2(496,644)
  picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;viewport.add_child(picture)
  var label:=Label.new();label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",27)
  label.text=DIRECTIONS[i]+"  ·  "+str(paths.size())+" 帧";label.position=origin+Vector2(8,690);label.size=Vector2(496,42)
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;viewport.add_child(label)
 for n in 6:await process_frame
 await RenderingServer.frame_post_draw
 viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+"01_八方向完整帧预览.png"))
 viewport.queue_free();await process_frame
func shot(filename: String) -> void:
 for n in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename))
