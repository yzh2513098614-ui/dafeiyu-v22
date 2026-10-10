extends SceneTree
const OUT="res://预览/资料库24件3D/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(720,720)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var viewer=load("res://district/library_models_viewer.tscn").instantiate();root.add_child(viewer);current_scene=viewer
 viewer.ui.visible=false
 var failures:=0
 for n in 24:
  viewer.show_model(n)
  for view in ["front","rear"]:
   viewer.yaw=.55 if view=="front" else PI+.55;viewer._camera()
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   if root.get_texture().get_image().save_png(OUT+str(viewer.entries[n].id)+"_"+view+".png")!=OK:failures+=1
 viewer.show_model(0)
 var box=viewer.ui.get_child(0).get_child(0)
 box.get_child(2).get_child(1).pressed.emit()
 if viewer.selected!=1:failures+=1;push_error("Next model button failed")
 box.get_child(2).get_child(0).pressed.emit()
 if viewer.selected!=0:failures+=1;push_error("Previous model button failed")
 box.get_child(3).get_child(1).pressed.emit()
 if absf(viewer.yaw-(PI+.55))>.001:failures+=1;push_error("Rear view button failed")
 viewer.show_model(8);viewer.ui.visible=true;viewer._camera();root.size=Vector2i(1280,960)
 for frame in 4:await process_frame
 await RenderingServer.frame_post_draw
 if root.get_texture().get_image().save_png(OUT+"模型查看器.png")!=OK:failures+=1
 print("INDIVIDUAL LIBRARY RENDERS 48 / failures ",failures)
 quit(0 if failures==0 else 1)
