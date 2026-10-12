extends SceneTree
## Render the actual world character with measured-distance gait playback.
const OUTPUT="res://预览/side_walk_cadence_20261012/"
var game

func _initialize() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func run() -> void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
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
 game.view_center=game.player.position;game.view_size=5;game.camera.size=5;game._camera()
 var sheet:=Image.create(1600,640,false,Image.FORMAT_RGB8)
 sheet.fill(Color("27303e"))
 for direction in ["left","right"]:
  game.facing=direction;game.gait_phase=0
  var seen: Dictionary={}
  for tick in 30:
   game._advance_character_gait(Vector3(.1,0,0),1.0/24.0)
   seen[game.avatar.frame]=true
   await process_frame;await process_frame
   RenderingServer.force_draw(false)
   var image:=root.get_texture().get_image()
   var foot: Vector2=game.camera.unproject_position(game.player.global_position)
   foot*=Vector2(image.get_width(),image.get_height())/game.camera.get_viewport().get_visible_rect().size
   var crop:=image.get_region(Rect2i(Vector2i(foot)-Vector2i(160,290),Vector2i(320,320)))
   crop.convert(Image.FORMAT_RGB8)
   crop.save_png(OUTPUT+direction+"_%02d.png"%tick)
   if tick in [0,3,6,9,12]:sheet.blit_rect(crop,Rect2i(0,0,320,320),Vector2i([0,3,6,9,12].find(tick)*320,0 if direction=="left" else 320))
  print("SIDE_WALK_RENDER ",direction," frames_seen=",seen.size()," cycle_distance=",game.character_manifest.cycle_distance_by_direction[direction])
 sheet.save_png(OUTPUT+"side_walk_contact_sheet.png")
 game.queue_free();await process_frame;quit()
