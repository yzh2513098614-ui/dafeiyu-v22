extends Button
## Native candy frame; every existing illustration and effect is preserved.
const CardStyle=preload("res://battle/battle_skin.gd")
const Candy=preload("res://ui/candy_skin.gd")
static var paintings:Dictionary={}
func configure(entry:Dictionary, dimensions:=Vector2(172,252), large:=false)->void:
 if paintings.is_empty() and FileAccess.file_exists("res://assets/cards/cute_v22/paintings.json"):
  paintings=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/cute_v22/paintings.json"))
 custom_minimum_size=dimensions;size=dimensions;size_flags_vertical=Control.SIZE_SHRINK_CENTER
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
 var kind:=str(entry.effects[0].kind) if not entry.get("effects",[]).is_empty() else "draw"
 var accent:Color={"damage":Color("596cde"),"heal":Color("238d85"),"block":Color("7765c7"),"stamina":Color("238d85"),"cleanse":Color("238d85"),"bind":Color("ac527c")}.get(kind,Color("6764bd"))
 var base:=Candy.frame("card").duplicate() as StyleBoxFlat
 base.set_corner_radius_all(18);base.set_border_width_all(3);base.set_content_margin_all(0)
 for state in ["normal","hover","pressed","disabled","focus"]:
  var box:=base.duplicate() as StyleBoxFlat
  if state in ["hover","focus"]:box.border_color=Candy.MINT;box.set_border_width_all(4)
  elif state=="pressed":box.bg_color=Color("ccf4f1")
  elif state=="disabled":box.bg_color=Color("c5cedf");box.shadow_size=0
  add_theme_stylebox_override(state,box)
 var header:=Panel.new();header.name="CardHeader";header.position=Vector2(6,6);header.size=Vector2(dimensions.x-12,dimensions.y*.18)
 var h:=Candy.frame("dark").duplicate() as StyleBoxFlat;h.bg_color=accent;h.set_border_width_all(0);h.shadow_size=0;h.set_corner_radius_all(12)
 header.add_theme_stylebox_override("panel",h);header.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(header)
 var badge:=Panel.new();badge.position=Vector2(10,10);badge.size=Vector2(dimensions.y*.15,dimensions.y*.15)
 var b:=Candy.frame("mint").duplicate() as StyleBoxFlat;b.bg_color=Candy.GOLD;b.set_corner_radius_all(100);b.set_border_width_all(2);b.shadow_size=0
 badge.add_theme_stylebox_override("panel",b);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(badge)
 var cost:=CardStyle.label(self,str(int(entry.cost)),badge.position,badge.size,28 if large else 23,CardStyle.INK)
 cost.name="CardCost";cost.add_theme_font_override("font",CardStyle.numeric_font());cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cost.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var title:=CardStyle.label(self,str(entry.name),Vector2(dimensions.x*.30,8),Vector2(dimensions.x*.65,dimensions.y*.17),24 if large else 17,Color("eaf1ff"))
 title.name="CardTitle";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 title.max_lines_visible=1;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 var painting:Dictionary=paintings.get(str(entry.id),{})
 var art_size:=Vector2(dimensions.x-20,dimensions.y*.47)
 var art_pos:=Vector2(10,dimensions.y*.22)
 if not painting.is_empty():
  var art:=ColorRect.new();art.name="CardPainting"
  var material:=ShaderMaterial.new();material.shader=preload("res://battle/cute_card_painting.gdshader")
  material.set_shader_parameter("painting_image",load(str(painting.atlas)))
  var cell:=int(painting.cell)
  material.set_shader_parameter("region",Vector4(float(cell%4)/4.0,float(cell/4)/4.0,.25,.25))
  material.set_shader_parameter("view_size",art_size);material.set_shader_parameter("painting_crop",Vector2(1.0,art_size.y/art_size.x))
  art.material=material;art.position=art_pos;art.size=art_size;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art)
 else:
  var art:=TextureRect.new();var atlas:=AtlasTexture.new();atlas.atlas=load(str(entry.image));atlas.region=Rect2(9,38,110,94)
  art.texture=atlas;art.position=art_pos;art.size=art_size;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
  art.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(art)
 var footer:=Panel.new();footer.name="CardFooter";footer.position=Vector2(9,dimensions.y*.72);footer.size=Vector2(dimensions.x-18,dimensions.y*.25)
 var f:=Candy.frame("sky").duplicate() as StyleBoxFlat;f.bg_color=accent.lightened(.84);f.set_border_width_all(0);f.shadow_size=0;f.set_corner_radius_all(10)
 footer.add_theme_stylebox_override("panel",f);footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(footer)
 var body:=CardStyle.label(footer,str(entry.description).replace("；","\n") if large else _brief_effects(entry),Vector2(3,1),footer.size-Vector2(6,2),17 if large else 17,CardStyle.INK)
 body.name="CardEffect";body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 body.max_lines_visible=4 if large else 2;body.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 # The full hover preview already contains the description; a tooltip would cover the hand.
 tooltip_text=""
 modulate=Color.WHITE if bool(entry.get("ready",true)) else Color(.76,.8,.84,.90)

func _brief_effects(entry:Dictionary)->String:
 var formats:Dictionary={"damage":"伤害 %d","block":"格挡 +%d","heal":"生命 +%d","stamina":"体力 +%d","energy":"能量 +%d","draw":"抽 %d 张牌","amplify":"下次伤害 +%d","retrieve":"取回 %d 张弃牌","bind":"束缚 %d 次行动","cleanse":"解除束缚"}
 var lines:Array[String]=[]
 for effect in entry.get("effects",[]):
  var kind:=str(effect.get("kind",""))
  if not formats.has(kind): return str(entry.description)
  lines.append(str(formats[kind]) if kind=="cleanse" else str(formats[kind]) % int(effect.get("value",0)))
 return "\n".join(lines) if not lines.is_empty() else str(entry.description)
