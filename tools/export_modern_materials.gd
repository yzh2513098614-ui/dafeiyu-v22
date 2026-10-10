extends SceneTree
const Modern = preload("res://modern_materials.gd")

func _initialize() -> void:
 var directory: String="res://assets/modern/materials/"
 DirAccess.make_dir_recursive_absolute(directory)
 var count:=0
 for style in ["oak","pale_oak","walnut","herringbone","ivory_tile","slate_tile","concrete","marble","terrazzo","navy_carpet","tatami","metal_grid"]:
  var m:=Modern.floor_material(style);m.resource_name="Modern floor / "+style
  ResourceSaver.save(m,directory+"floor_"+style+".tres");count+=1
 var palette: Dictionary={"paint_fog":"d6dce0","paint_bluegrey":"bcc5cd","paint_mint":"c6d8d7","paint_white":"e2e5e5","metal_graphite":"3b4b5b","metal_silver":"a0afbb","metal_blue":"748da8","fabric_cream":"ecebe4","fabric_navy":"3b6396","fabric_ice":"a2bec5","fabric_rug":"63738a","accent_pale_oak":"d1cabd"}
 for id in palette:
  var m:=Modern.surface(Color(palette[id]),id.begins_with("metal_"),id.begins_with("fabric_"));m.resource_name=id
  ResourceSaver.save(m,directory+str(id)+".tres");count+=1
 for id in {"cyan":"71dce8","ice":"8ad7e5","warm":"ffe9c3"}:
  var color: String={"cyan":"71dce8","ice":"8ad7e5","warm":"ffe9c3"}[id]
  var m:=Modern.led(Color(color),.35);m.resource_name="LED / "+str(id)
  ResourceSaver.save(m,directory+"led_"+str(id)+".tres");count+=1
 ResourceSaver.save(Modern.glass(),directory+"glass_clear.tres");count+=1
 print("Exported "+str(count)+" reusable modern Godot materials")
 quit()
