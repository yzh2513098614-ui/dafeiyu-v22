extends SceneTree
func _initialize() -> void:
 var source:="res://art_source/完整图片帧/right_contact_A_pose_guide.svg"
 var picture:=Image.new()
 var error:=picture.load_svg_from_string(FileAccess.get_file_as_string(source))
 if error!=OK:quit(1);return
 picture.save_png(source.replace(".svg",".png"))
 quit()
