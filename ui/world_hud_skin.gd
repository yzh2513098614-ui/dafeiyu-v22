extends RefCounted
## Compact world cards retain the project's blue-purple palette.
const INK:=Color("394364")

static func frame(dark: bool=false) -> StyleBoxFlat:
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("414a75") if dark else Color("e5ebfc")
 style.border_color=Color("8b99c6") if dark else Color("7584ae")
 style.set_border_width_all(2);style.set_corner_radius_all(18)
 style.shadow_color=Color(.10,.13,.24,.18);style.shadow_size=3;style.shadow_offset=Vector2(0,3)
 return style

static func single_line(label: Label) -> void:
 label.autowrap_mode=TextServer.AUTOWRAP_OFF
 label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 label.clip_text=true;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
