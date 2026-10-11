extends RefCounted
## Original candy-color inventory controls. No reference art is used.
const INK:=Color("383655")
const MUTED:=Color("777293")
const BLUE:=Color("6469df")
const MINT:=Color("7adcc4")
const PINK:=Color("f48bb7")
const GOLD:=Color("ffe071")
const Base=preload("res://ui/handheld_skin.gd")
static var boxes: Dictionary={}

static func frame(kind: String="shell") -> StyleBoxFlat:
 if boxes.has(kind):return boxes[kind]
 var fills: Dictionary={"shell":"b9b7d1","panel":"d9ddf8","bag":"b6e7e4","chest":"d8ccf3","detail":"e8e4f7","card":"edf0fc","empty":"a5c7d2","selected":"7adcc4","button":"c1cff4","hover":"d7e3ff","pressed":"9faee2","primary":"f48bb7","primary_hover":"ffadd0","primary_pressed":"d96b9d","disabled":"b7b6c7","status":"d2e9ec","dark":"45465f"}
 var s:=StyleBoxFlat.new();s.bg_color=Color(fills.get(kind,"d9ddf8"));s.border_color=INK
 s.set_border_width_all(3);s.set_corner_radius_all(13);s.anti_aliasing=true
 s.content_margin_left=10;s.content_margin_right=10;s.content_margin_top=4;s.content_margin_bottom=4
 if kind=="shell":s.set_border_width_all(5);s.set_corner_radius_all(34);s.shadow_size=12;s.shadow_offset=Vector2(0,8)
 elif kind in ["bag","chest","detail","panel"]:s.set_border_width_all(4);s.set_corner_radius_all(22);s.shadow_size=4;s.shadow_offset=Vector2(0,4)
 elif kind in ["button","primary","hover","primary_hover"]:s.shadow_size=2;s.shadow_offset=Vector2(0,4)
 elif kind=="empty":s.set_border_width_all(2);s.border_color=Color("87a4b5")
 elif kind=="selected":s.set_border_width_all(4)
 s.shadow_color=Color(.14,.12,.25,.22);boxes[kind]=s;return s

static func panel(parent: Node,pos: Vector2,dimensions: Vector2,kind: String="panel") -> Panel:
 var p:=Panel.new();p.position=pos;p.size=dimensions;p.add_theme_stylebox_override("panel",frame(kind));parent.add_child(p)
 p.mouse_filter=Control.MOUSE_FILTER_IGNORE;return p

static func label(parent: Node,text: String,pos: Vector2,dimensions: Vector2,font_size: int=20,color: Color=INK) -> Label:
 var l:=Label.new();l.text=text;l.position=pos;l.size=dimensions;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(l);return l

static func button(parent: Node,text: String,pos: Vector2,dimensions: Vector2,action: Callable,primary: bool=false) -> Button:
 var b:=Button.new();b.text=text;b.position=pos;b.size=dimensions;b.add_theme_font_size_override("font_size",20)
 for state in {"normal":"primary" if primary else "button","hover":"primary_hover" if primary else "hover","pressed":"primary_pressed" if primary else "pressed","disabled":"disabled"}:
  b.add_theme_stylebox_override(state,frame({"normal":"primary" if primary else "button","hover":"primary_hover" if primary else "hover","pressed":"primary_pressed" if primary else "pressed","disabled":"disabled"}[state]))
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,INK)
 b.set_script(preload("res://ui/ocean_menu_button.gd"));b.pressed.connect(action);parent.add_child(b);return b

static func card_button(b: Button,selected: bool=false) -> void:
 b.add_theme_stylebox_override("normal",frame("selected" if selected else "card"));b.add_theme_stylebox_override("hover",frame("selected"));b.add_theme_stylebox_override("pressed",frame("selected"))

static func icon(parent: Node,key: String,pos: Vector2,dimensions: Vector2) -> TextureRect:
 var r:=TextureRect.new();r.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;r.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 r.texture=load("res://assets/ui/inventory/chest.svg") if key=="chest" else Base.icon_texture(key)
 r.position=pos;r.size=dimensions;r.mouse_filter=Control.MOUSE_FILTER_IGNORE;r.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;parent.add_child(r);return r

static func header(parent: Node,title: String,subtitle: String,key: String,close_action: Callable) -> void:
 var badge:=panel(parent,Vector2(25,22),Vector2(78,78),"dark")
 icon(badge,key,Vector2(9,8),Vector2(60,60))
 label(parent,title,Vector2(122,20),Vector2(990,43),33)
 label(parent,subtitle,Vector2(124,68),Vector2(972,30),18,MUTED)
 var close:=button(parent,"Esc  关闭",Vector2(1124,29),Vector2(170,50),close_action);close.name="CloseInventory"
 var stripe:=panel(parent,Vector2(25,111),Vector2(1270,6),"dark");stripe.add_theme_stylebox_override("panel",frame("dark"))

static func capacity(parent: Node,slots: int,pos: Vector2,width: float) -> void:
 var track:=panel(parent,pos,Vector2(width,9),"dark")
 var fill:=StyleBoxFlat.new();fill.bg_color=PINK if slots>=64 else MINT;fill.set_corner_radius_all(4)
 var meter:=Panel.new();meter.position=Vector2(2,2);meter.size=Vector2(maxf(0,(width-4)*slots/64.0),5);meter.add_theme_stylebox_override("panel",fill);meter.mouse_filter=Control.MOUSE_FILTER_IGNORE;track.add_child(meter)

static func feedback(parent: Node,text: String,pos: Vector2,dimensions: Vector2) -> Label:
 var scroll:=ScrollContainer.new();scroll.position=pos;scroll.size=dimensions;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(scroll)
 var l:=label(scroll,text,Vector2.ZERO,dimensions-Vector2(16,0),18)
 l.custom_minimum_size.x=dimensions.x-16;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return l
