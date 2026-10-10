extends SceneTree
func _initialize()->void:
 var image:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/battle/ui_painted_v22/refined_frames.png"))
 print("SIZE ", image.get_size())
 for row in 2:
  for col in 3:
   var area:=Rect2i(col*image.get_width()/3,row*image.get_height()/2,image.get_width()/3,image.get_height()/2)
   var minp:=Vector2i(area.size);var maxp:=Vector2i.ZERO
   for y in area.size.y:
    for x in area.size.x:
     if image.get_pixel(x+area.position.x,y+area.position.y).a>.6:
      minp=minp.min(Vector2i(x,y));maxp=maxp.max(Vector2i(x,y))
   print("CELL ", row*3+col, " ", Rect2i(area.position+minp,maxp-minp+Vector2i.ONE))
 quit()

