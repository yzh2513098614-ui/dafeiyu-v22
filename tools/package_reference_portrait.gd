extends SceneTree
## Keep the generator original; create a clearly marked 4K delivery derivative.
func _initialize()->void:
 var img:=Image.load_from_file("res://assets/dialogue/whale_clean_generated_20261013.png")
 print("GENERATED ORIGINAL ",img.get_size())
 var width:=roundi(float(img.get_width())*4096/img.get_height())
 img.resize(width,4096,Image.INTERPOLATE_LANCZOS)
 var result:=img.save_png("res://assets/dialogue/whale_clean_4k_upscaled_20261013.png")
 print("4K LANCZOS DERIVATIVE ",img.get_size()," SAVE ",result)
 quit(result)
