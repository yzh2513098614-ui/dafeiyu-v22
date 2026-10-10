extends Control
func _draw() -> void:
    draw_set_transform(Vector2(35,30),0,Vector2(1.25,.88))
    draw_circle(Vector2.ZERO,21,Color("456ba4"))
    draw_circle(Vector2(0,11),15,Color("eff9ff"))
    draw_circle(Vector2(-9,-1),2,Color("163b67"))
    draw_circle(Vector2(8,-1),2,Color("163b67"))
    draw_circle(Vector2(-12,4),3,Color("f0b5c1"))
    draw_circle(Vector2(12,4),3,Color("f0b5c1"))
    draw_colored_polygon(PackedVector2Array([Vector2(18,4),Vector2(29,-6),Vector2(31,6),Vector2(24,12)]),Color("456ba4"))
    draw_arc(Vector2(0,1),6,.4,2.7,12,Color("163b67"),1.5,true)
    draw_set_transform(Vector2.ZERO)
