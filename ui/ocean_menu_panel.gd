@tool
extends Panel
## Sample-style rims rendered without children, so page rebuilds keep the frame.
const S=preload("res://ui/ocean_sample_skin.gd")
const Candy=preload("res://ui/candy_skin.gd")
func _ready() -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
func _draw() -> void:
 if size.x<40 or size.y<40:return
 var kind:=str(get_meta("ocean_kind","panel"))
 var raw:=get_theme_stylebox("panel")
 if not raw is StyleBoxFlat:return
 var outer:StyleBoxFlat=raw
 var inset:=7.0
 var rim_color:=Color("dce5ff") if kind=="shell" else outer.bg_color.lightened(.35)
 var rim:=S.box(Color.TRANSPARENT,maxi(8,outer.corner_radius_top_left-7),rim_color,3)
 rim.draw(get_canvas_item(),Rect2(inset,inset,size.x-inset*2,size.y-inset*2-5))
 if kind in ["panel","portrait","shell"]:
  inset=14.0
  var well:=S.box(Color("c2cff1") if kind=="shell" else Candy.PAPER,maxi(12,outer.corner_radius_top_left-12),Candy.INK,3 if kind=="shell" else 4)
  well.draw(get_canvas_item(),Rect2(inset,inset,size.x-inset*2,size.y-inset*2-5))
 if kind=="shell":
  for x in [48.0,191.0]:
   S.box(Candy.DARK,9,Candy.INK,2).draw(get_canvas_item(),Rect2(x,7,126,18))
  for i in 3:draw_circle(Vector2(size.x-106+i*23,15),6,Candy.MINT if i==0 else Candy.BLUE)
