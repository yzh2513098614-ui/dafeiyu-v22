extends RefCounted
## Ocean handheld skin, adapted from the independent code-rendered prototype.
const INK:=Color("403853")
const MUTED:=Color("756e88")
const BLUE:=Color("6469df")
const PINK:=Color("f48bb7")
const MINT:=Color("7adcc4")
const GOLD:=Color("ffe071")
const CREAM:=Color("fff7dd")
const DARK:=Color("45465f")
static var styles: Dictionary={}
static var textures: Dictionary={}

static func frame(kind: String="panel") -> StyleBoxFlat:
 if styles.has(kind):return styles[kind]
 var fills={"panel":"d7d8d8","dialogue":"d7d8d8","paper":"fff7dd","sky":"e0f3e9","quote":"7adcc4","status":"ece7ed","button":"f48bb7","hover":"f8a5c8","pressed":"d777a5","disabled":"c9c8cf","selected":"7adcc4","card":"fff7dd","nameplate":"45465f","speaker":"f48bb7","screen":"45465f","primary":"f48bb7"}
 var s:=StyleBoxFlat.new();s.bg_color=Color(fills.get(kind,"d7d8d8"));s.border_color=INK
 s.set_border_width_all(3);s.set_corner_radius_all(14);s.anti_aliasing=true
 s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=4;s.content_margin_bottom=4
 if kind in ["panel","dialogue"]:
  s.set_border_width_all(6);s.set_corner_radius_all(28);s.shadow_size=7;s.shadow_offset=Vector2(0,6)
 elif kind in ["nameplate","screen"]:
  s.set_border_width_all(5);s.border_color=MINT;s.set_corner_radius_all(20);s.shadow_size=5;s.shadow_offset=Vector2(0,4)
 elif kind in ["quote","speaker"]:
  s.set_border_width_all(4);s.set_corner_radius_all(18);s.shadow_size=4;s.shadow_offset=Vector2(0,4)
 elif kind in ["button","hover","pressed","primary"]:
  s.set_border_width_all(3);s.shadow_size=2;s.shadow_offset=Vector2(0,4 if kind!="pressed" else 1)
 elif kind=="status":s.set_border_width_all(2);s.set_corner_radius_all(12)
 s.shadow_color=Color(.20,.16,.28,.24)
 styles[kind]=s;return s

static func theme(font: Font) -> Theme:
 var t:=Theme.new();t.default_font=font;t.default_font_size=22
 for type in ["Label","RichTextLabel","Button","LineEdit","SpinBox","OptionButton"]:
  t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,INK);t.set_color("font_pressed_color",type,INK)
  t.set_color("font_focus_color",type,INK);t.set_color("font_disabled_color",type,MUTED)
 t.set_stylebox("panel","Panel",frame());t.set_stylebox("panel","PanelContainer",frame())
 for type in ["Button","OptionButton"]:
  for state in {"normal":"button","hover":"hover","pressed":"pressed","hover_pressed":"pressed","disabled":"disabled"}:
   t.set_stylebox(state,type,frame({"normal":"button","hover":"hover","pressed":"pressed","hover_pressed":"pressed","disabled":"disabled"}[state]))
  var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=BLUE
  focus.set_border_width_all(3);focus.set_corner_radius_all(14);focus.set_expand_margin_all(2);t.set_stylebox("focus",type,focus)
 t.set_stylebox("normal","LineEdit",frame("paper"));t.set_stylebox("focus","LineEdit",frame("selected"))
 t.set_color("caret_color","LineEdit",BLUE);t.set_color("selection_color","LineEdit",MINT)
 t.set_color("font_placeholder_color","LineEdit",MUTED);t.set_color("font_selected_color","LineEdit",INK)
 for type in ["VScrollBar","HScrollBar"]:
  var track:=frame("status").duplicate();track.set_border_width_all(0);track.set_corner_radius_all(5)
  track.content_margin_left=5;track.content_margin_right=5;track.content_margin_top=5;track.content_margin_bottom=5
  var thumb:=track.duplicate();thumb.bg_color=PINK
  t.set_stylebox("scroll",type,track);t.set_stylebox("scroll_focus",type,track)
  for state in ["grabber","grabber_highlight","grabber_pressed"]:t.set_stylebox(state,type,thumb)
 t.set_constant("separation","VBoxContainer",12)
 return t

static func panel(parent: Node,pos: Vector2,dimensions: Vector2,kind: String="panel") -> Panel:
 var p:=Panel.new();p.position=pos;p.size=dimensions;p.add_theme_stylebox_override("panel",frame(kind))
 p.set_script(preload("res://ui/handheld_panel.gd"));p.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 parent.add_child(p);return p

static func icon_texture(key: String) -> Texture2D:
 if textures.has(key):return textures[key]
 var path:="res://assets/ui/ocean_handheld/icons/"+key+".png"
 if not ResourceLoader.exists(path):return null
 var source: Texture2D=load(path)
 if source==null:return null
 var image:=source.get_image()
 image.generate_mipmaps()
 var texture:=ImageTexture.create_from_image(image);textures[key]=texture;return texture

static func button_icon(button: Button,key: String,side: int=26) -> void:
 button.icon=icon_texture(key);button.expand_icon=true
 button.add_theme_constant_override("icon_max_width",side);button.add_theme_constant_override("h_separation",6)
 button.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

static func primary(button: Button) -> void:
 for state in ["normal","hover","pressed"]:button.add_theme_stylebox_override(state,frame("primary" if state=="normal" else state))
 for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(key,CREAM)
 button.add_theme_color_override("font_outline_color",INK);button.add_theme_constant_override("outline_size",4)
