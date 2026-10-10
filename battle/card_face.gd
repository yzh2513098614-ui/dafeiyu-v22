extends Button
## Every skill has independent art, with a shared functional frame by category.
const CardStyle=preload("res://battle/battle_skin.gd")
const PaintedFrames=preload("res://battle/painted_card_frames.gd")
static var paintings:Dictionary={}
func configure(entry:Dictionary, dimensions:=Vector2(172,252), large:=false)->void:
 if paintings.is_empty() and FileAccess.file_exists("res://assets/cards/cute_v22/paintings.json"):
  paintings=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/cute_v22/paintings.json"))
 custom_minimum_size=dimensions
 size=dimensions
 size_flags_vertical=Control.SIZE_SHRINK_CENTER
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 var kind:=str(entry.effects[0].kind) if not entry.get("effects",[]).is_empty() else "draw"
 for state in ["normal","hover","pressed","disabled","focus"]:
  var style:=StyleBoxFlat.new()
  style.bg_color=Color.TRANSPARENT
  style.set_content_margin_all(0)
  style.set_corner_radius_all(14)
  if state in ["hover","focus"]:
   style.border_color=Color("69a5b5");style.set_border_width_all(2)
  add_theme_stylebox_override(state,style)
 var painting:Dictionary=paintings.get(str(entry.id),{})
 var art_size:=Vector2(dimensions.x*.82,dimensions.y*.48)
 var art_pos:=Vector2(dimensions.x*.09,dimensions.y*.212)
 if not painting.is_empty():
  var art:=ColorRect.new()
  var material:=ShaderMaterial.new()
  material.shader=preload("res://battle/cute_card_painting.gdshader")
  material.set_shader_parameter("painting_image",load(str(painting.atlas)))
  var cell:=int(painting.cell)
  material.set_shader_parameter("region",Vector4(float(cell%4)/4.0,float(cell/4)/4.0,.25,.25))
  material.set_shader_parameter("view_size",art_size)
  material.set_shader_parameter("painting_crop",Vector2(1.0,art_size.y/art_size.x))
  art.material=material;art.position=art_pos;art.size=art_size
  art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art)
 else:
  var art:=TextureRect.new()
  var atlas:=AtlasTexture.new();atlas.atlas=load(str(entry.image));atlas.region=Rect2(9,38,110,94)
  art.texture=atlas;art.position=art_pos;art.size=art_size
  art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
  art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art)
 var rim:=TextureRect.new()
 rim.name="PaintedFrame"
 rim.texture=PaintedFrames.texture(kind)
 rim.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 rim.stretch_mode=TextureRect.STRETCH_SCALE
 rim.size=dimensions;rim.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var rim_material:=ShaderMaterial.new();rim_material.shader=preload("res://battle/painted_frame_alpha.gdshader")
 rim.material=rim_material;add_child(rim)
 var cost:=CardStyle.label(self,str(int(entry.cost)),dimensions*Vector2(.07,.037),dimensions*Vector2(.24,.15),28 if large else 23,CardStyle.INK)
 cost.name="CardCost"
 cost.add_theme_font_override("font",CardStyle.numeric_font())
 cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cost.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var title:=CardStyle.label(self,str(entry.name),dimensions*Vector2(.32,.045),dimensions*Vector2(.60,.16),24 if large else 19,Color("fffaf0"))
 title.name="CardTitle"
 title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 title.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
 title.max_lines_visible=1;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 var footer:=Panel.new()
 footer.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 footer.position=dimensions*Vector2(.09,.735);footer.size=dimensions*Vector2(.82,.24)
 footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(footer)
 var body:=CardStyle.label(footer,str(entry.description).replace("；","\n") if large else _brief_effects(entry),Vector2(1,1),footer.size-Vector2(2,3),17 if large else 18,CardStyle.INK)
 body.name="CardEffect"
 body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 body.max_lines_visible=4 if large else 2
 body.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 tooltip_text="%s · %d 能量\n%s" % [entry.name,int(entry.cost),entry.description]
 if not bool(entry.get("ready",true)): modulate=Color(.76,.8,.84,.90)

func _brief_effects(entry:Dictionary)->String:
 var formats:Dictionary={"damage":"伤害 %d","block":"格挡 +%d","heal":"生命 +%d","stamina":"体力 +%d","energy":"能量 +%d","draw":"抽 %d 张牌","amplify":"下次伤害 +%d","retrieve":"取回 %d 张弃牌","bind":"束缚 %d 次行动","cleanse":"解除束缚"}
 var lines:Array[String]=[]
 for effect in entry.get("effects",[]):
  var kind:=str(effect.get("kind",""))
  if not formats.has(kind): return str(entry.description)
  lines.append(str(formats[kind]) if kind=="cleanse" else str(formats[kind]) % int(effect.get("value",0)))
 return "\n".join(lines) if not lines.is_empty() else str(entry.description)

