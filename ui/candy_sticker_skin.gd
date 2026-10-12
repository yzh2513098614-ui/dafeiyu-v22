extends RefCounted
const ButtonArt=preload("res://ui/candy_sticker_button.gd")
const INK=Color("2857c9")
const MUTED=Color("607eb6")

static func frame(kind:String="panel")->StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.anti_aliasing=true;box.bg_color=Color("f8fcff")
 box.set_corner_radius_all(26);box.set_border_width_all(7);box.border_color=Color.WHITE
 box.shadow_color=Color("769cff");box.shadow_size=2;box.shadow_offset=Vector2(5,8)
 if kind=="empty":box.bg_color=Color.TRANSPARENT;box.set_border_width_all(0);box.shadow_size=0;box.shadow_color=Color.TRANSPARENT
 if kind=="dialogue":box.bg_color=Color(.97,.985,1,.95);box.set_corner_radius_all(40)
 if kind=="selected":box.bg_color=Color("e6f5ff");box.border_color=Color("a0d0ff")
 return box

static func theme_for_menu()->Theme:
 var result:=Theme.new();result.default_font=load("res://assets/fonts/misans/MiSans-Bold.ttf");result.default_font_size=23
 for type in ["Label","Button","CheckButton","OptionButton"]:result.set_color("font_color",type,INK)
 for kind in ["normal","hover","pressed","disabled","focus"]:
  var button:=frame("selected" if kind in ["hover","pressed","focus"] else "panel")
  button.set_border_width_all(3);button.set_corner_radius_all(16);button.shadow_size=0
  result.set_stylebox(kind,"Button",button)
 result.set_stylebox("panel","Panel",frame())
 return result

static func label(parent:Node,text:String,pos:Vector2,dimensions:Vector2,font_size:int=25,color:Color=INK)->Label:
 var node:=Label.new();node.text=text;node.position=pos;node.size=dimensions;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
 node.add_theme_color_override("font_color",color);node.add_theme_font_size_override("font_size",font_size);parent.add_child(node)
 return node

static func button(parent:Node,text:String,pos:Vector2,dimensions:Vector2,action:Callable,icon:String="",accent:Color=Color("aad4ff"))->Button:
 var node:=Button.new();node.set_script(ButtonArt);node.text=text;node.position=pos;node.size=dimensions;node.accent=accent
 node.add_theme_color_override("font_color",INK);node.add_theme_color_override("font_hover_color",Color("127bde"))
 node.add_theme_color_override("font_pressed_color",INK);node.add_theme_color_override("font_disabled_color",Color("7a92bf"))
 node.add_theme_font_size_override("font_size",32 if dimensions.y>=78 else 23)
 var empty:=StyleBoxEmpty.new();empty.content_margin_left=66 if icon!="" else 12;empty.content_margin_right=30;empty.content_margin_top=0;empty.content_margin_bottom=12
 for state in ["normal","hover","pressed","disabled","focus"]:node.add_theme_stylebox_override(state,empty)
 node.compact=dimensions.y<70
 if icon!="":node.icon_texture=load("res://assets/ui/candy_title/icons/"+icon+".svg")
 var caption:=Label.new();caption.text=text;caption.position=Vector2((69 if node.compact else 85) if icon!="" else 14,0)
 caption.size=Vector2(dimensions.x-caption.position.x-31,dimensions.y-16);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
 caption.add_theme_font_size_override("font_size",32 if dimensions.y>=78 else 23);caption.add_theme_color_override("font_color",INK);node.add_child(caption);node.live_label=caption
 node.pressed.connect(action);parent.add_child(node);return node
