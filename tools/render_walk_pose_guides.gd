extends SceneTree
func _initialize() -> void:
 for name in ["right_8poses_guide","right_contact_B_guide"]:
  var picture:=Image.new()
  var error:=picture.load_svg_from_string(FileAccess.get_file_as_string("res://art_source/动作重绘/"+name+".svg"))
  if error!=OK:push_error("SVG construction guide failed");quit(1);return
  picture.save_png("res://art_source/动作重绘/"+name+".png")
 print("POSE GUIDE RENDERED")
 quit()
