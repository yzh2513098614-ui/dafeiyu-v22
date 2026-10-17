@tool
extends Control
## Small native symbols for the world encounter cards and floating prompts.
@export_enum("swords", "search", "sparkle", "pointer", "chevron") var kind := "swords":
 set(value):kind=value;queue_redraw()
@export var tint:=Color.WHITE:
 set(value):tint=value;queue_redraw()
func _ready()->void:resized.connect(queue_redraw)
func _draw()->void:
 var k:=minf(size.x,size.y)/24.0
 draw_set_transform((size-Vector2.ONE*24*k)*.5,0,Vector2.ONE*k)
 match kind:
  "swords":
   draw_line(Vector2(5,3),Vector2(20,19),tint,3,true)
   draw_line(Vector2(19,3),Vector2(4,19),tint,3,true)
   draw_line(Vector2(13,17),Vector2(19,11),tint,2.5,true)
   draw_line(Vector2(5,11),Vector2(11,17),tint,2.5,true)
   draw_circle(Vector2(21,21),1.8,tint);draw_circle(Vector2(3,21),1.8,tint)
  "search":
   draw_arc(Vector2(10,9),6,0,TAU,32,tint,2.6,true)
   draw_line(Vector2(14,14),Vector2(21,21),tint,3.2,true)
  "sparkle":
   var points:=PackedVector2Array([Vector2(12,1),Vector2(15,9),Vector2(23,12),Vector2(15,15),Vector2(12,23),Vector2(9,15),Vector2(1,12),Vector2(9,9)])
   draw_colored_polygon(points,Color("fff3bf"))
   points.append(points[0]);draw_polyline(points,tint,2,true)
  "pointer":draw_polyline(PackedVector2Array([Vector2(5,8),Vector2(12,15),Vector2(19,8)]),Color("4d81c5"),6,true);draw_polyline(PackedVector2Array([Vector2(5,8),Vector2(12,15),Vector2(19,8)]),Color.WHITE,3,true)
  "chevron":draw_polyline(PackedVector2Array([Vector2(9,5),Vector2(16,12),Vector2(9,19)]),tint,3,true)
