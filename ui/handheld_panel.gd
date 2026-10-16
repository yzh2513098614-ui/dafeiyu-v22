@tool
extends Panel
## White rim, blue depth and a quiet pastel gradient; no nested inner frames.
var accent:GradientTexture2D
func _ready()->void:resized.connect(queue_redraw)

func _draw()->void:
 var base:=get_theme_stylebox("panel")
 if not base is StyleBoxFlat or size.x<90 or size.y<50:return
 if base.get_border_width(SIDE_LEFT)>=3:
  var edge:=StyleBoxFlat.new();edge.bg_color=Color.TRANSPARENT;edge.border_color=Color("8ca9d8");edge.set_border_width_all(2);edge.set_corner_radius_all(base.corner_radius_top_left+1);edge.anti_aliasing=true
  edge.draw(get_canvas_item(),Rect2(Vector2(-1,-1),size+Vector2(2,2)))
 if size.x<320 or size.y<110:return
 if accent==null:
  accent=GradientTexture2D.new();var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color("d9efff80"),Color("f8e6f680"),Color("e7ddff80")]);gradient.offsets=PackedFloat32Array([0,.55,1]);accent.gradient=gradient;accent.width=256;accent.height=128;accent.fill_from=Vector2.ZERO;accent.fill_to=Vector2.ONE
 var rect:=Rect2(Vector2(size.x-188,18),Vector2(168,minf(76,size.y-36)));var radius:=16.0
 var centers:Array[Vector2]=[rect.position+Vector2(rect.size.x-radius,radius),rect.end-Vector2.ONE*radius,rect.position+Vector2(radius,rect.size.y-radius),rect.position+Vector2.ONE*radius]
 var points:=PackedVector2Array();var uvs:=PackedVector2Array()
 for corner in 4:
  for step in 7:
   var angle:float=-PI/2+corner*PI/2+step*PI/12;var point:Vector2=centers[corner]+Vector2(cos(angle),sin(angle))*radius;points.append(point);uvs.append((point-rect.position)/rect.size)
 draw_polygon(points,PackedColorArray([Color.WHITE]),uvs,accent)
