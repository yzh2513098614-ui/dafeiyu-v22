extends RefCounted
## Compatibility facade for existing dialogue and menu callers.
const SkyStyle=preload("res://ui/sky_skin.gd")
const INK=SkyStyle.INK
const MUTED=SkyStyle.MUTED
const BLUE=SkyStyle.BLUE
static func frame(kind: String="dialogue") -> StyleBoxFlat:
 return SkyStyle.frame(kind)
static func theme(font: Font) -> Theme:
 return SkyStyle.theme(font)
static func label(parent: Node,text: String,pos: Vector2,size: Vector2,font_size: int=22,color: Color=INK) -> Label:
 var l:=Label.new();l.text=text;l.position=pos;l.size=size;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.add_theme_font_size_override("font_size",font_size);l.add_theme_color_override("font_color",color);parent.add_child(l);return l
static func panel(parent: Node,pos: Vector2,size: Vector2,kind: String="dialogue") -> Panel:
 return SkyStyle.panel(parent,pos,size,kind)
