extends SceneTree
func _init() -> void:call_deferred("_render")
func _render() -> void:
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1600,3260)
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var node=load("res://tools/catalog_sheet.gd").new()
 viewport.add_child(node)
 for n in 4:await process_frame
 await RenderingServer.frame_post_draw
 var error:=viewport.get_texture().get_image().save_png("res://素材总览.png")
 print("CATALOG RENDERED: ",error)
 quit(error)
