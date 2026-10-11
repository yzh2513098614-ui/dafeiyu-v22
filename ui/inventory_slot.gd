extends Button
## Decorative corner marks and stack count never intercept input.
const S=preload("res://ui/harbor_inventory_skin.gd")
var selected:=false

func configure(controller,id: String,count: int,dimensions: Vector2,chosen: bool=false,equipped: bool=false,favorite: bool=false) -> void:
 custom_minimum_size=dimensions;size=dimensions;selected=chosen;clip_contents=true
 S.card_button(self,chosen);texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 if id=="":
  disabled=true;mouse_filter=Control.MOUSE_FILTER_IGNORE;add_theme_stylebox_override("disabled",S.frame("empty"));return
 name="Item_"+id;tooltip_text=str(controller.definitions[id].name)+"\n"+str(controller.definitions[id].get("effect_summary",""))
 controller._icon(self,id,Vector2((dimensions.x-66)/2,5),Vector2(66,minf(59,dimensions.y-34)))
 var number:=S.label(self,"×"+str(count),Vector2(32,5),Vector2(dimensions.x-38,22),16,S.INK);number.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 number.add_theme_color_override("font_outline_color",Color("edf0fc"));number.add_theme_constant_override("outline_size",4)
 var title:=S.label(self,str(controller.definitions[id].name),Vector2(5,dimensions.y-29),Vector2(dimensions.x-10,23),16)
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.autowrap_mode=TextServer.AUTOWRAP_OFF;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 if favorite:S.label(self,"★",Vector2(6,5),Vector2(23,23),16,S.BLUE)
 if equipped:
  var tag:=S.panel(self,Vector2(5,dimensions.y-47),Vector2(43,19),"dark")
  S.label(tag,"装备",Vector2(3,-1),Vector2(38,19),12,Color("b6f4e4"))
 mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw);resized.connect(queue_redraw)

func _draw() -> void:
 if disabled:
  draw_line(Vector2(size.x/2-10,size.y/2),Vector2(size.x/2+10,size.y/2),Color("88a7b8"),2)
  draw_line(Vector2(size.x/2,size.y/2-10),Vector2(size.x/2,size.y/2+10),Color("88a7b8"),2)
 elif selected:
  draw_circle(Vector2(size.x-9,size.y-9),4,S.BLUE)
