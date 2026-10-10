extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://预览/街区"))
 var game=load("res://district/neighborhood.tscn").instantiate();root.add_child(game)
 for n in 8:await process_frame
 for id in ["street","lobby","hall_2","home_102","home_201","home_301","roof","garden"]:
  game._travel(id)
  for n in 5:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://预览/街区/"+id+".png")
 game._show_map(true)
 for n in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://预览/街区/区域导览.png")
 var f:=FileAccess.open("res://district/locations.json",FileAccess.WRITE);f.store_string(JSON.stringify(game.locations,"  "));f.close()
 print("DISTRICT PREVIEWS SAVED; locations=",game.locations.size());quit()
