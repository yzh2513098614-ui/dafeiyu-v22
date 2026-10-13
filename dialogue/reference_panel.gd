@tool
extends Panel
## Vector ornament remains sharp at every window size and ignores input.
@export var role:="dialogue"
const GOLD=Color("d8c490")
const PALE=Color("d8e4ff")
func _ready()->void:resized.connect(queue_redraw)
func star(center:Vector2,radius:float)->void:
 var points:=PackedVector2Array()
 for i in 8:
  var a:=PI*.25*i
  points.append(center+Vector2(cos(a),sin(a))*(radius if i%2==0 else radius*.30))
 draw_colored_polygon(points,GOLD)
func _draw()->void:
 if size.x<40:return
 if role=="screen":
  draw_style_box(rim(),Rect2(Vector2(9,9),size-Vector2(18,18)))
  for x in range(220,int(size.x)-40,14):draw_circle(Vector2(x,20),1.1,Color("918dba"))
  draw_line(Vector2(231,size.y-66),Vector2(size.x-46,size.y-66),Color("65709b"),1,true)
  # Layered bow and scalloped fan behind the left medallion.
  var center:=Vector2(121,68)
  for i in 15:
   var a:float=TAU*i/15
   draw_circle(center+Vector2(cos(a),sin(a))*92,15,PALE)
  draw_colored_polygon(PackedVector2Array([center+Vector2(-30,65),center+Vector2(-75,204),center+Vector2(-14,176),center+Vector2(10,83)]),Color("c5d7f2"))
  draw_colored_polygon(PackedVector2Array([center+Vector2(20,73),center+Vector2(50,220),center+Vector2(84,185),center+Vector2(48,66)]),Color("5f7cba"))
  draw_colored_polygon(PackedVector2Array([center+Vector2(-3,66),center+Vector2(-81,113),center+Vector2(-91,48)]),Color("354b84"))
  draw_colored_polygon(PackedVector2Array([center+Vector2(3,66),center+Vector2(81,113),center+Vector2(91,48)]),Color("354b84"))
  draw_circle(center,87,Color("263359"));draw_arc(center,86,0,TAU,96,GOLD,3,true)
  draw_arc(center,76,0,TAU,96,Color("92a6d2"),1.5,true)
  # Original whale silhouette: body, fins, split tail, and a tiny eye.
  ellipse_shape(center+Vector2(-11,12),Vector2(44,27),PALE)
  draw_colored_polygon(PackedVector2Array([center+Vector2(17,20),center+Vector2(52,-13),center+Vector2(42,-28),center+Vector2(31,-12),center+Vector2(16,-16),center+Vector2(21,2)]),PALE)
  ellipse_shape(center+Vector2(-16,30),Vector2(25,6),Color("97b3dc"))
  draw_circle(center+Vector2(-35,7),3,Color("263359"))
  draw_arc(center+Vector2(-18,-22),9,PI,TAU,12,PALE,2,true)
  star(center+Vector2(0,-91),13);star(center+Vector2(0,93),10)
  for p in [Vector2(size.x-32,50),Vector2(size.x-32,98),Vector2(size.x-32,146),Vector2(216,size.y-40)]:star(p,7)
  draw_line(Vector2(size.x-32,32),Vector2(size.x-32,162),GOLD,1,true)
 elif role=="speaker":
  draw_arc(Vector2(30,size.y*.5),21,PI*.55,PI*1.45,24,GOLD,2,true)
  star(Vector2(size.x-18,size.y*.5),10)
 elif role=="quote":
  draw_style_box(rim(),Rect2(Vector2(7,7),size-Vector2(14,14)))
func rim()->StyleBoxFlat:
 var s:=StyleBoxFlat.new();s.bg_color=Color.TRANSPARENT;s.border_color=Color("7385b0")
 s.set_border_width_all(1);s.set_corner_radius_all(10);return s
func ellipse_shape(center:Vector2,radii:Vector2,color:Color)->void:
 var points:=PackedVector2Array()
 for i in 48:points.append(center+Vector2(cos(TAU*i/48),sin(TAU*i/48))*radii)
 draw_colored_polygon(points,color)
