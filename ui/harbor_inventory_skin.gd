extends RefCounted
## Approved web sticker skin, used by the real bag and container controllers.
const INK:=Color("2857c9")
const MUTED:=Color("7690b5")
const BLUE:=Color("638eff")
const MINT:=Color("31b9c6")
const PINK:=Color("e697b8")
const GOLD:=Color("edbf65")
const EDGE:=Color("8ca9d8")
const GRADIENT=preload("res://assets/ui/sticker/rounded_gradient.gdshader")
static var boxes:Dictionary={}
static var inventory_theme:Theme

static func frame(kind:String="panel")->StyleBoxFlat:
 if boxes.has(kind):return boxes[kind]
 var fills:Dictionary={"shell":"edf4ff","panel":"fcfdff","paper":"fcfdff","detail":"fcfdff","bag":"dfeafa","chest":"e6f0fc","status":"eaf2ff","card":"fcfdff","button":"fcfdff","hover":"eaf3ff","pressed":"e3efff","primary":"edf7ff","primary_hover":"e7f7f8","primary_pressed":"deeff6","disabled":"edf1f7","selected":"eaf4ff","empty":"d8e5f7","dark":"638eff","focus":"00000000"}
 var b:=StyleBoxFlat.new();b.resource_name=kind;b.bg_color=Color(fills.get(kind,"fcfdff"));b.border_color=EDGE;b.set_border_width_all(2);b.set_corner_radius_all(13);b.anti_aliasing=true
 b.content_margin_left=10;b.content_margin_right=10;b.content_margin_top=3;b.content_margin_bottom=3
 b.shadow_color=Color("88a8e4");b.shadow_size=1;b.shadow_offset=Vector2(0,3)
 if kind=="shell":b.border_color=Color.WHITE;b.set_border_width_all(7);b.set_corner_radius_all(32);b.shadow_color=Color("537cdb");b.shadow_offset.y=15
 elif kind in ["panel","paper","detail","bag","chest","status"]:
  b.border_color=Color.WHITE;b.set_border_width_all(5 if kind=="detail" else 4 if kind in ["bag","chest"] else 3);b.set_corner_radius_all(23 if kind=="detail" else 20);b.shadow_offset.y=9 if kind=="detail" else 5
 elif kind=="selected":b.border_color=BLUE;b.shadow_color=BLUE
 elif kind in ["pressed","primary_pressed"]:b.shadow_offset.y=1
 elif kind=="disabled":b.border_color=Color("c4cfdd");b.shadow_color=Color("c4cfdd");b.shadow_offset.y=2
 elif kind=="empty":b.border_color=Color("b6cce9");b.shadow_size=0;b.shadow_offset=Vector2.ZERO
 elif kind=="focus":b.border_color=Color("0879f4");b.shadow_size=0;b.shadow_offset=Vector2.ZERO
 elif kind=="dark":b.border_color=Color.WHITE;b.set_border_width_all(1);b.shadow_size=0
 boxes[kind]=b;return b

static func theme()->Theme:
 if inventory_theme!=null:return inventory_theme
 var t:=Theme.new();t.default_font=preload("res://assets/fonts/misans/MiSans-Demibold.ttf");t.default_font_size=18
 for type in ["Label","RichTextLabel","Button","LineEdit","SpinBox","OptionButton","PopupMenu"]:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:t.set_color(state,type,INK)
  t.set_color("font_disabled_color",type,Color("9aa9c0"))
 for type in ["Button","OptionButton"]:
  for state in ["normal","hover","pressed","disabled","focus"]:t.set_stylebox(state,type,frame("button" if state=="normal" else state))
 t.set_stylebox("normal","LineEdit",frame("card"));t.set_stylebox("focus","LineEdit",frame("focus"))
 t.set_color("font_placeholder_color","LineEdit",MUTED);t.set_color("caret_color","LineEdit",BLUE);t.set_color("selection_color","LineEdit",Color("d7e9ff"))
 inventory_theme=t;return t

static func palette(kind:String)->Dictionary:
 if kind.begins_with("补给"):return {"line":MINT,"ink":Color("287780"),"wash":Color("e7f7f8")}
 if kind.begins_with("工具"):return {"line":Color("a592d5"),"ink":Color("75609c"),"wash":Color("f2edff")}
 if kind.begins_with("线索") or kind=="favorite":return {"line":PINK,"ink":Color("9b607d"),"wash":Color("fff0f6")}
 if kind.begins_with("材料"):return {"line":GOLD,"ink":Color("8b662d"),"wash":Color("fff5df")}
 return {"line":BLUE,"ink":INK,"wash":Color("eaf2ff")}

static func surface(parent:Control,start:Color,finish:Color,inset:float=3,radius:float=13)->ColorRect:
 var r:=ColorRect.new();r.name="StickerSurface";r.mouse_filter=Control.MOUSE_FILTER_IGNORE;r.set_meta("sticker_surface",true)
 var m:=ShaderMaterial.new();m.shader=GRADIENT;m.set_shader_parameter("start_color",start);m.set_shader_parameter("end_color",finish);m.set_shader_parameter("radius",radius);r.material=m
 parent.add_child(r)
 var fit:=func():
  r.position=Vector2.ONE*inset;r.size=parent.size-Vector2.ONE*inset*2;m.set_shader_parameter("rect_size",r.size)
 fit.call();parent.resized.connect(fit);return r

static func panel(parent:Node,pos:Vector2,dimensions:Vector2,kind:String="panel")->Panel:
 var p:=Panel.new();p.position=pos;p.size=dimensions;p.add_theme_stylebox_override("panel",frame(kind));p.mouse_filter=Control.MOUSE_FILTER_IGNORE
 if kind=="shell":p.theme=theme()
 parent.add_child(p)
 if kind in ["shell","panel","paper","detail","bag","chest","status"]:
  var colors:Dictionary={"shell":[Color("fcfdff"),Color("edf2ff")],"bag":[Color("dfeefa"),Color("eaf4ff")],"chest":[Color("e5f1fc"),Color("eff0ff")],"detail":[Color("f2edff"),Color("fcfdff")],"status":[Color("e4f3ff"),Color("f1edff")]}
  var pair:Array=colors.get(kind,[Color("fcfdff"),Color("edf4ff")]);var border:=frame(kind).get_border_width(SIDE_LEFT)
  surface(p,pair[0],pair[1],border+1,maxf(2,frame(kind).corner_radius_top_left-border))
 return p

static func label(parent:Node,text:String,pos:Vector2,dimensions:Vector2,font_size:int=20,color:Color=INK)->Label:
 var l:=Label.new();l.text=text;l.position=pos;l.size=dimensions;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);l.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(l);return l

static func button(parent:Node,text:String,pos:Vector2,dimensions:Vector2,action:Callable,primary:bool=false)->Button:
 var b:=Button.new();b.text=text;b.position=pos;b.size=dimensions;b.add_theme_font_size_override("font_size",19)
 for state in ["normal","hover","pressed","disabled","focus"]:
  var kind:String=("primary" if primary else "button") if state=="normal" else ("primary_"+state if primary and state in ["hover","pressed"] else state)
  var box:=frame(kind)
  if dimensions.x<60:
   box=box.duplicate();box.content_margin_left=3;box.content_margin_right=3
  b.add_theme_stylebox_override(state,box)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,INK)
 b.add_theme_color_override("font_disabled_color",Color("9aa9c0"));b.pressed.connect(action);parent.add_child(b);return b

static func card_button(b:Button,selected:bool=false)->void:
 for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,frame("selected" if selected and state=="normal" else "card" if state=="normal" else state))
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,INK)
 if b.has_meta("inventory_category"):
  var colors:=palette(str(b.get_meta("inventory_category")))
  var box:=frame("selected" if selected else "button").duplicate();box.border_color=colors.line if selected else EDGE;box.bg_color=colors.wash if selected else Color("fcfdff");b.add_theme_stylebox_override("normal",box)
  b.add_theme_color_override("font_color",colors.ink if selected else INK)

static func icon(parent:Node,key:String,pos:Vector2,dimensions:Vector2)->TextureRect:
 var r:=TextureRect.new();r.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;r.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 var filename:String={"backpack":"bag","chest":"grid"}.get(key,key)
 r.texture=load("res://assets/ui/sticker/icons/"+filename+".svg");r.self_modulate=INK;r.position=pos;r.size=dimensions;r.mouse_filter=Control.MOUSE_FILTER_IGNORE;r.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;parent.add_child(r);return r

static func header(parent:Node,title:String,subtitle:String,key:String,close_action:Callable)->void:
 var badge:=panel(parent,Vector2(25,22),Vector2(78,78),"paper");icon(badge,key,Vector2(15,15),Vector2(48,48))
 label(parent,title,Vector2(122,20),Vector2(990,43),33)
 label(parent,subtitle,Vector2(124,68),Vector2(972,30),16,MUTED)
 var close:=button(parent,"Esc  关闭",Vector2(1124,29),Vector2(170,50),close_action);close.name="CloseInventory"
 var stripe:=ColorRect.new();stripe.position=Vector2(25,117);stripe.size=Vector2(1270,2);stripe.color=Color("bdd0ed");stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(stripe)

static func capacity(parent:Node,slots:int,pos:Vector2,width:float)->ProgressBar:
 var meter:=ProgressBar.new();meter.position=pos;meter.size=Vector2(width,8);meter.max_value=64;meter.value=slots;meter.show_percentage=false;meter.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var track:=StyleBoxFlat.new();track.bg_color=Color("d2dff4");track.set_corner_radius_all(4)
 var fill:=StyleBoxFlat.new();fill.bg_color=GOLD if slots>=64 else MINT;fill.set_corner_radius_all(4)
 meter.add_theme_stylebox_override("background",track);meter.add_theme_stylebox_override("fill",fill);parent.add_child(meter);return meter

static func feedback(parent:Node,text:String,pos:Vector2,dimensions:Vector2,font_size:int=16)->Label:
 var scroll:=ScrollContainer.new();scroll.position=pos;scroll.size=dimensions;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;parent.add_child(scroll)
 var l:=label(scroll,text,Vector2.ZERO,dimensions-Vector2(16,0),font_size,MUTED);l.custom_minimum_size.x=dimensions.x-16;l.size_flags_horizontal=Control.SIZE_EXPAND_FILL;return l
