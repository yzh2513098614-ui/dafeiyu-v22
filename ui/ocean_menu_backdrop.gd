extends Control
## Background transplanted from ocean-ui-code-demo; scales with the viewport.
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func _draw() -> void:
 draw_set_transform(Vector2.ZERO,0.0,size/Vector2(1440,1080))
 draw_rect(Rect2(0,0,1440,1080),Color("ffeed8"))
 draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(940,0),Vector2(1150,340),Vector2(0,780)]),Color("f5b7ce"))
 draw_colored_polygon(PackedVector2Array([Vector2(910,0),Vector2(1050,0),Vector2(430,1080),Vector2(290,1080)]),Color("fff6ce"))
 draw_circle(Vector2(1290,940),260,Color("afdfcc"))
 for i in 7:
  var x:=95.0+i*217.0
  draw_arc(Vector2(x,150),36,0,PI,20,Color("e899b9"),5,true)
 for origin in [Vector2(1215,88),Vector2(45,882),Vector2(1342,560)]:
  var p:=PackedVector2Array([origin+Vector2(-14,0),origin+Vector2(-4,-4),origin+Vector2(0,-22),origin+Vector2(5,-5),origin+Vector2(19,0),origin+Vector2(4,6),origin+Vector2(0,21),origin+Vector2(-5,6)])
  draw_colored_polygon(p,Color("fff7dd"));p.append(p[0]);draw_polyline(p,Color("9a77ac"),3,true)
