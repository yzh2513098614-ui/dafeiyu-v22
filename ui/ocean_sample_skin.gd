extends RefCounted
const INK:=Color("403853")
const PINK:=Color("f48bb7")
const MINT:=Color("7adcc4")
const GOLD:=Color("ffe071")
const CREAM:=Color("fff7dd")
const BLUE:=Color("6469df")
const DARK:=Color("45465f")

static func box(fill: Color,radius: int=20,border: Color=INK,width: int=5,shadow: int=0) -> StyleBoxFlat:
 var s:=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(width);s.set_corner_radius_all(radius)
 s.anti_aliasing=true;s.shadow_size=shadow;s.shadow_color=Color(.16,.12,.24,.23);s.shadow_offset=Vector2(0,6)
 s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=8;s.content_margin_bottom=8
 return s

static func plate(parent: Node,rect: Rect2,fill: Color,radius: int=20,border: Color=INK,width: int=5,shadow: int=0) -> Panel:
 var p:=Panel.new();p.position=rect.position;p.size=rect.size;p.mouse_filter=Control.MOUSE_FILTER_IGNORE
 p.add_theme_stylebox_override("panel",box(fill,radius,border,width,shadow));parent.add_child(p);return p

static func frame(parent: Node,rect: Rect2,kind: String) -> Panel:
 var colors={"shell":Color("b8b9c1"),"mint":MINT,"pink":PINK,"dark":DARK,"paper":CREAM}
 var fill: Color=colors.get(kind,MINT)
 var radius:=68 if kind=="shell" else 24
 var outer:=plate(parent,rect,fill,radius,INK,6,7)
 var rim_color:=Color("f4f5ec") if kind=="shell" else fill.lightened(.35)
 plate(outer,Rect2(7,7,rect.size.x-14,rect.size.y-19),Color.TRANSPARENT,maxi(12,radius-7),rim_color,3)
 if kind=="shell":
  plate(outer,Rect2(13,14,rect.size.x-26,rect.size.y-34),Color("d7d8d8"),radius-12,Color("a7a7b2"),3)
 return outer

static func button(parent: Node,rect: Rect2,text: String,color: Color,callback: Callable) -> Button:
 var b:=Button.new();b.position=rect.position;b.size=rect.size;b.text=text
 for state in ["normal","hover","pressed","disabled"]:
  var shade:=color.lightened(.1) if state=="hover" else (color.darkened(.09) if state=="pressed" else color)
  var s:=box(shade,16,INK,4,2)
  s.shadow_color=color.darkened(.3);s.shadow_offset=Vector2(0,7 if state!="pressed" else 2)
  b.add_theme_stylebox_override(state,s)
 var focus:=box(Color.TRANSPARENT,16,GOLD,3);focus.set_expand_margin_all(4);b.add_theme_stylebox_override("focus",focus)
 for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(key,CREAM)
 b.add_theme_color_override("font_outline_color",INK);b.add_theme_constant_override("outline_size",6);b.add_theme_font_size_override("font_size",28)
 parent.add_child(b);b.pressed.connect(callback)
 var highlight:=plate(b,Rect2(12,8,rect.size.x-24,5),color.lightened(.32),2,Color.TRANSPARENT,0);highlight.name="Highlight"
 return b

static func text(parent: Node,value: String,rect: Rect2,font_size: int=24,color: Color=CREAM,center: bool=false) -> Label:
 var l:=Label.new();l.position=rect.position;l.size=rect.size;l.text=value;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
 l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color)
 l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 if center:l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 parent.add_child(l);return l

static func icon(parent: Node,key: String,rect: Rect2) -> TextureRect:
 var t:=TextureRect.new();t.position=rect.position;t.size=rect.size;t.texture=load("res://assets/ui/ocean_handheld/icons/"+key+".svg")
 t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 t.mouse_filter=Control.MOUSE_FILTER_IGNORE;t.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;parent.add_child(t);return t
