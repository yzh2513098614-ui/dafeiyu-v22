extends RefCounted
## World and dialogue adapter for the shared original candy game UI.
const S=preload("res://ui/candy_skin.gd")
const DownloadedIcons=preload("res://ui/downloaded_icons.gd")
const INK:=S.INK
const MUTED:=S.MUTED
const BLUE:=S.BLUE
const PINK:=S.PINK
const MINT:=S.MINT
const GOLD:=S.GOLD
const CREAM:=S.PAPER
const DARK:=S.DARK
const BUTTON_ICON_SCALE: float=1.3
static var textures: Dictionary={}

static func frame(kind: String="panel") -> StyleBoxFlat:
 return S.frame(kind)

static func theme(font: Font) -> Theme:
 var t:=Theme.new();t.default_font=font;t.default_font_size=22
 for type in ["Label","RichTextLabel","Button","LineEdit","SpinBox","OptionButton"]:
  t.set_color("font_color",type,INK);t.set_color("font_hover_color",type,INK);t.set_color("font_pressed_color",type,INK)
  t.set_color("font_focus_color",type,INK);t.set_color("font_disabled_color",type,MUTED)
 t.set_stylebox("panel","Panel",frame());t.set_stylebox("panel","PanelContainer",frame())
 for type in ["Button","OptionButton"]:
  for state in {"normal":"button","hover":"hover","pressed":"pressed","hover_pressed":"pressed","disabled":"disabled"}:
   t.set_stylebox(state,type,frame({"normal":"button","hover":"hover","pressed":"pressed","hover_pressed":"pressed","disabled":"disabled"}[state]))
  t.set_stylebox("focus",type,frame("focus"))
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
 var editable:=S.editable_theme()
 if editable!=null:t.merge_with(editable)
 return t

static func panel(parent: Node,pos: Vector2,dimensions: Vector2,kind: String="panel") -> Panel:
 var p:=Panel.new();p.position=pos;p.size=dimensions;p.add_theme_stylebox_override("panel",frame(kind))
 p.set_script(preload("res://ui/handheld_panel.gd"));p.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 parent.add_child(p);return p

static func icon_path(key: String) -> String:
 var downloaded:=DownloadedIcons.path_for(key)
 return downloaded if downloaded!="" else "res://assets/ui/ocean_handheld/icons/"+key+".png"

static func icon_texture(key: String) -> Texture2D:
 if textures.has(key):return textures[key]
 var path:=icon_path(key)
 if not ResourceLoader.exists(path):return null
 var source: Texture2D=load(path)
 if source==null:return null
 var image:=source.get_image()
 image.generate_mipmaps()
 var texture:=ImageTexture.create_from_image(image);textures[key]=texture;return texture

static func button_icon(button: Button,key: String,side: int=26) -> void:
 button.icon=icon_texture(key);button.expand_icon=true
 button.add_theme_constant_override("icon_max_width",roundi(side*BUTTON_ICON_SCALE));button.add_theme_constant_override("h_separation",6)
 button.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

static func primary(button: Button) -> void:
 S.button(button,true)
