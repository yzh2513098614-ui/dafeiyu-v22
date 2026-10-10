extends SceneTree
func _initialize() -> void:
 var source:=Image.load_from_file("res://assets/materials/material_atlas_source.png")
 var names: Array[String]=["oak_grain","walnut_grain","aged_plaster","navy_weave","sage_weave","linen_weave","slate_stone","brushed_iron","rust_rug"]
 var edges_y: Array[int]=[0,418,820,1254]
 for i in 9:
  var row:=i/3;var col:=i%3
  var image:=source.get_region(Rect2i(col*418+2,edges_y[row]+2,414,edges_y[row+1]-edges_y[row]-4))
  image.resize(128,128,Image.INTERPOLATE_NEAREST)
  image.save_png("res://assets/materials/"+names[i]+".png")
  print("MATERIAL: ",names[i])
 quit()
