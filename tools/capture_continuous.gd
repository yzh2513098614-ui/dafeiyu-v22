extends SceneTree
## Produce native game renders, then -- --overview after the thumbnail import.
var game
const PREVIEW:="res://预览/连续大地图_v13/"

func _initialize() -> void:
 call_deferred("capture")

func capture() -> void:
 game=load("res://district/continuous_world.tscn").instantiate()
 root.add_child(game)
 for n in 8:await process_frame
 game.set_physics_process(false)
 game.set_process_unhandled_input(false)
 if "--map-only" in OS.get_cmdline_user_args():await _maps()
 elif "--overview" in OS.get_cmdline_user_args():await _overviews()
 else:await _thumbnails()
 var file:=FileAccess.open("res://district/continuous_locations.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(game.locations,"  "));file.close()
 print("CONTINUOUS CAPTURE COMPLETE; spaces=",game.locations.size())
 quit()

func _layers(node: Node,visible: bool) -> void:
 if node is CanvasLayer:node.visible=visible
 for child in node.get_children():_layers(child,visible)

func _settle() -> void:
 for n in 7:await process_frame
 await RenderingServer.frame_post_draw

func _thumbnails() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/district/places"))
 for id in game.locations:
  game._travel(str(id));_layers(game,false)
  await _settle()
  var picture: Image=root.get_texture().get_image()
  picture.resize(384,288,Image.INTERPOLATE_LANCZOS)
  var result: Error=picture.save_png("res://assets/district/places/"+str(id)+".png")
  print("THUMBNAIL ",id," saved=",result==OK," room_zones=",game.room_zones.size())

func _picture(name: String) -> void:
 await _settle()
 var result: Error=root.get_texture().get_image().save_png(PREVIEW+name+".png")
 print("PREVIEW ",name," saved=",result==OK," room_zones=",game.room_zones.size())

func _overviews() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW))
 for id in ["city","apt_2","community_1","inn_2"]:
  game._travel(id);_layers(game,true)
  await _picture(id+"_总览")
 game._travel("apt_2");_layers(game,true)
 game.player.position=Vector3(-15,0,-3.0)
 game.overview_mode=false;game.view_size=22.0;game.camera.size=22.0
 game.view_center=Vector3(game.player.position.x,0,game.player.position.z)
 game._camera();game._update_view_button();game._refresh_zone()
 await _picture("apt_2_跟随")
 await _maps()

func _maps() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREVIEW))
 game._travel("city");_layers(game,true)
 for group in ["outside","floor2"]:
  game._show_map(true)
  var guide=game.map_panel.get_child(0)
  guide.selected_group=group;guide._draw_cards();guide._tab_states()
  await _picture("导览_"+group)
  game._show_map(false)
