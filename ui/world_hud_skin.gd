extends RefCounted
## Compact cards share the approved blue-white palette and short blue base.
const Shared=preload("res://ui/harbor_inventory_skin.gd")
const INK:=Shared.INK

static func frame(dark: bool=false) -> StyleBoxFlat:
 var style:StyleBoxFlat=Shared.frame("dark" if dark else "paper").duplicate()
 style.set_corner_radius_all(18)
 return style

static func single_line(label: Label) -> void:
 label.autowrap_mode=TextServer.AUTOWRAP_OFF
 label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 label.clip_text=true;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
