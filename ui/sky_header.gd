extends Panel
## Decorative diagonal ribbons. Panel input and child layout remain native.
func _ready() -> void:
 resized.connect(queue_redraw)

func _draw() -> void:
 var right:=size.x-10.0
 var span:=minf(80.0,size.x*.20)
 var inset:=8.0
 for shift in [0.0,span*.7]:
  draw_colored_polygon(PackedVector2Array([Vector2(right-span-shift,inset),Vector2(right-shift,inset),Vector2(right-span*.55-shift,size.y-inset),Vector2(right-span*1.55-shift,size.y-inset)]),Color(1,1,1,.10))
