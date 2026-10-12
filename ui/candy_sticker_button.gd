extends Button
## The hit area and live label stay stable; only the sticker layers move.
var accent:=Color("81bcff")
var decoration:="star"
var icon_texture:Texture2D
var compact:=false
var live_label:Label

func _ready()->void:
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for event in [mouse_entered,mouse_exited,button_down,button_up,focus_entered,focus_exited]:event.connect(queue_redraw)
 resized.connect(queue_redraw)

func _process(_delta:float)->void:
 if not is_instance_valid(live_label):return
 live_label.text=text;live_label.size=Vector2(size.x-live_label.position.x-31,size.y-16)
 live_label.add_theme_font_size_override("font_size",get_theme_font_size("font_size"))
 live_label.add_theme_color_override("font_color",Color("7a92bf") if disabled else (Color("127bde") if is_hovered() else Color("2857c9")))

func _box(fill:Color,border:Color,width:int,radius:int)->StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=fill;box.border_color=border
 box.set_border_width_all(width);box.set_corner_radius_all(radius);box.anti_aliasing=true
 return box

func _draw()->void:
 var h:=size.y
 var pressed:=is_pressed() and not disabled
 var shift:=Vector2(3,5) if pressed else (Vector2(0,-2) if is_hovered() and not disabled else Vector2.ZERO)
 var tint:=Color("b1bed9") if disabled else Color("638eff")
 var outer:=Rect2(Vector2(2,1)+shift,size-Vector2(12,14))
 _box(tint,tint,0,int(h*.33)).draw(get_canvas_item(),Rect2(Vector2(8,9),size-Vector2(12,14)))
 _box(Color.WHITE,Color.WHITE,0,int(h*.33)).draw(get_canvas_item(),outer)
 var face:=outer.grow(-6)
 _box(Color("f5fbff") if is_hovered() and not disabled else Color("fcfdff"),Color("e0efff"),1,int(h*.25)).draw(get_canvas_item(),face)
 var inner:=face.grow(-3)
 _box(Color.TRANSPARENT,accent.lightened(.35) if disabled else accent,2,int(h*.21)).draw(get_canvas_item(),inner)
 # White interruptions give the inset the printed, slightly broken line of the reference.
 for fraction in [.20,.67,.83]:
  draw_line(Vector2(inner.position.x+inner.size.x*fraction,inner.position.y),Vector2(inner.position.x+inner.size.x*fraction+10,inner.position.y),Color.WHITE,3,true)
 if icon_texture:
  var icon_h:=h*.72
  draw_texture_rect(icon_texture,Rect2(Vector2(18,(h-icon_h)*.40)+shift,Vector2(icon_h,icon_h)),false,Color(1,1,1,.5 if disabled else 1))
 if not compact:
  var center:=Vector2(size.x-24,h*.24)+shift
  if decoration=="star":
   var star:=PackedVector2Array()
   for i in 10:
    var angle:float=-PI*.5+i*PI*.2
    star.append(center+Vector2(cos(angle),sin(angle))*(19.0 if i%2==0 else 9.0))
   var outline:=PackedVector2Array(star);outline.append(star[0]);draw_polyline(outline,Color.WHITE,8,true);draw_colored_polygon(star,Color("ffd16c"))
  elif decoration=="heart":
   var heart:=PackedVector2Array([center+Vector2(-16,-3),center+Vector2(-9,-12),center+Vector2(0,-7),center+Vector2(9,-12),center+Vector2(16,-3),center+Vector2(0,15)])
   var outline:=PackedVector2Array(heart);outline.append(heart[0]);draw_polyline(outline,Color.WHITE,7,true);draw_colored_polygon(heart,Color("ff83bf"))
  else:
   draw_circle(center,18,Color.WHITE);draw_circle(center,12,accent)
 if has_focus():
  _box(Color.TRANSPARENT,Color("2269df"),3,int(h*.34)).draw(get_canvas_item(),Rect2(Vector2(-4,-5),size+Vector2(2,0)))
