extends RefCounted
## Shared candy palette, with battle typography preserved.
const S=preload("res://ui/candy_skin.gd")
const INK:=S.INK
const MUTED:=S.MUTED
const BLUE:=S.BLUE
const GOLD:=S.GOLD
const PaintedUi=preload("res://battle/candy_ui_assets.gd")
static var _body_font: FontFile
static var _numeric_font: FontFile
static func _prepare_font(path:String)->FontFile:
 var font:FontFile=load(path).duplicate()
 font.antialiasing=TextServer.FONT_ANTIALIASING_GRAY
 font.hinting=TextServer.HINTING_NORMAL
 font.force_autohinter=true
 font.subpixel_positioning=TextServer.SUBPIXEL_POSITIONING_DISABLED
 font.oversampling=0.0
 return font
static func body_font()->Font:
 if _body_font==null:
  _body_font=_prepare_font("res://assets/fonts/misans/MiSans-Demibold.ttf")
 return _body_font
static func numeric_font() -> Font:
 if _numeric_font == null:
  _numeric_font=_prepare_font("res://assets/fonts/misans/MiSans-Bold.ttf")
 return _numeric_font

static func frame(kind: String="panel") -> StyleBoxFlat:
 return S.frame(kind).duplicate() as StyleBoxFlat

static func theme(font: Font) -> Theme:
 return preload("res://ui/handheld_skin.gd").theme(font)

static func panel(parent: Node,pos: Vector2,size: Vector2,kind: String="panel") -> Panel:
 var p:=Panel.new();p.position=pos;p.size=size;p.add_theme_stylebox_override("panel",frame(kind));parent.add_child(p);PaintedUi.panel(p,kind);return p

static func label(parent: Node,text: String,pos: Vector2,size: Vector2,font_size: int=22,color: Color=INK) -> Label:
 var l:=Label.new();l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE
 l.add_theme_font_override("font",body_font())
 l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color)
 l.text=text;l.position=pos;l.size=size;parent.add_child(l);return l

static func card_button(b: Button,selected: bool=false) -> void:
 S.button(b,false,selected)

static func primary(b: Button) -> void:
 S.button(b,true)

static func action(b: Button,role: String) -> void:
 PaintedUi.button(b,role)
