extends SceneTree
## Produce actual game renders; use -- --overview after thumbnail imports finish.
var game

func _initialize() -> void:
 call_deferred("capture")

func capture() -> void:
 game=load("res://district/neighborhood.tscn").instantiate()
 root.add_child(game)
 for n in 8:await process_frame
 game.set_physics_process(false)
 game.set_process_unhandled_input(false)
 var overview: bool="--overview" in OS.get_cmdline_user_args()
 if overview:await _overviews()
 else:await _thumbnails()
 var f:=FileAccess.open("res://district/locations.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(game.locations,"  "));f.close()
 print("V12 CAPTURE COMPLETE; locations=",game.locations.size(),"; overview=",overview)
 quit()

func _layers(node: Node,visible: bool) -> void:
 if node is CanvasLayer:node.visible=visible
 for child in node.get_children():_layers(child,visible)

func _settle() -> void:
 for n in 6:await process_frame
 await RenderingServer.frame_post_draw

func _thumbnails() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/district/places"))
 for id in game.locations:
  game._travel(str(id));_layers(game,false)
  await _settle()
  var picture: Image=root.get_texture().get_image()
  # Preserve the viewport's camera composition and image aspect ratio.
  picture.resize(384,288,Image.INTERPOLATE_LANCZOS)
  var error: Error=picture.save_png("res://assets/district/places/"+str(id)+".png")
  var targets: Array=[]
  for portal in game.portals:targets.append(str(portal.target))
  var missing: Array=[]
  for link in game.locations[id].links:
   if str(link) not in targets:missing.append(str(link))
  print("THUMBNAIL ",id," saved=",error==OK," portals=",targets," missing=",missing)

func _overviews() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://预览/街区_v12"))
 for id in ["east_street","waterfront","suite_living","suite_bath"]:
  game._travel(id);_layers(game,true)
  await _settle()
  root.get_texture().get_image().save_png("res://预览/街区_v12/"+id+".png")
 game._travel("street");_layers(game,true)
 for group in ["outside","floor2"]:
  game._show_map(true)
  var guide=game.map_panel.get_child(0)
  guide.selected_group=group;guide._draw_cards();guide._tab_states()
  await _settle()
  root.get_texture().get_image().save_png("res://预览/街区_v12/导览_"+group+".png")
  game._show_map(false)
