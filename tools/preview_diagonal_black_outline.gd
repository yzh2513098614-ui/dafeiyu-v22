extends SceneTree
## Before/after actual GPU rendering, plus all 52 walking frames.
const OUTPUT="res://预览/diagonal_outline_refine_20261013/"
const BEFORE="res://备份/20261013_细线调色前/diagonal_black_outline_20261013/"
var game
var checks:=0
func _initialize() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 DisplayServer.window_set_position(Vector2i(-9999,-9999));call_deferred("run")

func capture(name: String) -> Image:
 for i in 3:await process_frame
 RenderingServer.force_draw(false)
 var shot:=root.get_texture().get_image()
 var foot: Vector2=game.camera.unproject_position(game.player.global_position)
 foot*=Vector2(shot.get_width(),shot.get_height())/game.camera.get_viewport().get_visible_rect().size
 var crop:=shot.get_region(Rect2i(Vector2i(foot)-Vector2i(110,220),Vector2i(220,240)))
 crop.convert(Image.FORMAT_RGB8);crop.save_png(OUTPUT+name+".png")
 return crop

func run() -> void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT));AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.music=false;prefs.values.sfx=false
 prefs.continue_game=false;prefs.starting_place="apt_2"
 prefs.settings_path=OUTPUT+"isolated_settings.cfg";prefs.world_save_path=OUTPUT+"isolated_world.json"
 root.size=Vector2i(800,600)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 for i in 35:await process_frame
 game.set_physics_process(false);game.atmosphere.set_process(false);game.atmosphere.set_time(12)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 for label in game.world.find_children("*","Label3D",true,false):label.hide()
 game.view_center=game.player.position;game.view_size=6;game.camera.size=6;game._camera()
 var comparison:=Image.create(660,480,false,Image.FORMAT_RGB8)
 var sheet:=Image.create(1100,480,false,Image.FORMAT_RGB8)
 for direction in ["up_left","up_right"]:
  game.facing=direction;game.gait_phase=9.25/26.0;game._set_character_pose(true)
  var old_image:=Image.load_from_file(BEFORE+direction+"/walk_09.png");old_image.generate_mipmaps()
  game.character_material.set_shader_parameter("character_atlas",ImageTexture.create_from_image(old_image))
  var before: Image=await capture(direction+"_before")
  game._set_character_pose(true)
  assert(is_equal_approx(float(game.character_material.get_shader_parameter("soft_contour_strength")),.12));checks+=1
  var after: Image=await capture(direction+"_after")
  comparison.blit_rect(before,Rect2i(0,0,220,240),Vector2i(0,0 if direction=="up_left" else 240))
  comparison.blit_rect(after,Rect2i(0,0,220,240),Vector2i(220,0 if direction=="up_left" else 240))
  game.facing="left" if direction=="up_left" else "right";game._set_character_pose(false)
  var reference: Image=await capture(direction+"_reference")
  comparison.blit_rect(reference,Rect2i(0,0,220,240),Vector2i(440,0 if direction=="up_left" else 240))
  game.facing=direction;game._set_character_pose(true)
  var position: Vector3=game.avatar.position
  for i in 26:
   game.gait_phase=(float(i)+.25)/26.0;game._set_character_pose(true)
   assert(game.avatar.frame==i and game.avatar.position==position)
   assert(game.character_material.get_shader_parameter("character_atlas")==game.frames.get_frame_texture("walk_"+direction,i));checks+=1
   var snapshot: Image=await capture(direction+"_%02d"%i)
   var selected=[0,6,12,18,25]
   if i in selected:sheet.blit_rect(snapshot,Rect2i(0,0,220,240),Vector2i(selected.find(i)*220,0 if direction=="up_left" else 240))
  game._set_character_pose(false)
  assert(game.character_material.get_shader_parameter("character_atlas")==game.frames.get_frame_texture("walk_"+direction,9));checks+=1
 game.facing="down";game._set_character_pose(false)
 assert(is_equal_approx(float(game.character_material.get_shader_parameter("soft_contour_strength")),.42));checks+=1
 comparison.save_png(OUTPUT+"before_after.png");sheet.save_png(OUTPUT+"walk_contact_sheet.png")
 game.facing="up_left";game._set_character_pose(false);game.view_size=11.7;game.camera.size=11.7;game._camera()
 await capture("normal_zoom")
 print("BLACK OUTLINE REVIEW: ",checks," checks passed; 52 actual GPU walk captures")
 game.queue_free();await process_frame;quit()
