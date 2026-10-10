extends SceneTree
## Technical whole-picture normalization. Original generated artwork stays intact.
## Inputs are complete PNG poses; no bones, deformation or drawn body parts.
const ROOT := "res://assets/character/jimeng_v20/"
func _initialize() -> void:call_deferred("pack")
func pack() -> void:
 var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"generated_extraction.json"))
 for direction in config.directions:
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT+direction))
  var poses: Array=config.directions[direction]
  for index in poses.size():
   var pose: Dictionary=poses[index]
   var image:=Image.load_from_file(str(pose.native_frame))
   if image==null or image.is_empty():push_error("Missing full generated pose");quit(1);return
   # One shared scale for all poses/directions. Keep original native PNGs too.
   var factor:=float(pose.source_scale)
   image.resize(roundi(image.get_width()*factor),roundi(image.get_height()*factor),Image.INTERPOLATE_LANCZOS)
   var canvas:=Image.create(1024,1152,false,Image.FORMAT_RGBA8)
   canvas.fill(Color.TRANSPARENT)
   var target:=Vector2i(int(pose.target[0]),int(pose.target[1]))
   canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),target)
   var error:=canvas.save_png(ProjectSettings.globalize_path(ROOT+direction+"/walk_%02d.png"%index))
   if error!=OK:push_error("Cannot save full generated pose");quit(2);return
  print("PACKED GENERATED WHOLE IMAGES ",direction," ",poses.size())
 quit()
