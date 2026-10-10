extends SceneTree
func _init() -> void:
 var names := ["oak","pale_oak","walnut","herringbone","ivory_tile","slate_tile","concrete","marble","terrazzo","navy_carpet","tatami","metal_grid"]
 var library := TileSet.new()
 library.tile_size=Vector2i(64,64)
 for i in names.size():
  var atlas := TileSetAtlasSource.new()
  atlas.texture=load("res://assets/floors/"+names[i]+".png")
  atlas.texture_region_size=Vector2i(64,64)
  atlas.create_tile(Vector2i.ZERO)
  library.add_source(atlas,i)
 var error := ResourceSaver.save(library,"res://assets/floors/floor_library.tres")
 print("Floor TileSet saved: ",error)
 quit(error)
