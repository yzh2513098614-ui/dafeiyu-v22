extends Button
## Native candy frame; every existing illustration and effect is preserved.
const CardStyle=preload("res://battle/battle_skin.gd")
const Surface=preload("res://battle/layered_panel.gd")
static var paintings:Dictionary={}
var _large := false
var _lift_tween: Tween

func _ready() -> void:
 mouse_entered.connect(_update_lift)
 mouse_exited.connect(_update_lift)
 focus_entered.connect(_update_lift)
 focus_exited.connect(_update_lift)

func _update_lift() -> void:
 if _large:return
 var raised:=not disabled and (is_hovered() or has_focus())
 z_index=1 if raised else 0
 if _lift_tween!=null and _lift_tween.is_valid():_lift_tween.kill()
 _lift_tween=create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
 _lift_tween.tween_property(self,"scale",Vector2.ONE*(1.035 if raised else 1.0),.12)

func configure(entry:Dictionary, dimensions:=Vector2(172,252), large:=false)->void:
 _large=large
 if paintings.is_empty() and FileAccess.file_exists("res://assets/cards/cute_v22/paintings.json"):
  paintings=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/cute_v22/paintings.json"))
 custom_minimum_size=dimensions;size=dimensions;size_flags_vertical=Control.SIZE_SHRINK_CENTER
 pivot_offset=Vector2(dimensions.x*.5,dimensions.y)
 texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 var kind:=str(entry.effects[0].kind) if not entry.get("effects",[]).is_empty() else "draw"
 var accent:Color={"damage":Color("596cde"),"heal":Color("238d85"),"block":Color("7765c7"),"stamina":Color("238d85"),"cleanse":Color("238d85"),"bind":Color("ac527c")}.get(kind,Color("6764bd"))
 var ready:=bool(entry.get("ready",true))
 var base:=StyleBoxFlat.new()
 base.bg_color=accent.lightened(.91);base.border_color=Color("455a7e")
 base.shadow_color=Color("40567d",.24);base.shadow_offset=Vector2(2,3)
 base.set_corner_radius_all(18);base.set_border_width_all(2);base.set_content_margin_all(0)
 for state in ["normal","hover","pressed","disabled","focus"]:
  var box:=base.duplicate() as StyleBoxFlat
  if state in ["hover","focus"]:box.border_color=Color("2f8c9f");box.set_border_width_all(3)
  elif state=="pressed":box.bg_color=Color("ccf4f1")
  elif state=="disabled":box.bg_color=Color("e5eaf2");box.border_color=Color("a0aec1");box.shadow_color=Color("40567d",.1)
  add_theme_stylebox_override(state,box)
 var header:=Panel.new();header.name="CardHeader";header.position=Vector2(6,6);header.size=Vector2(dimensions.x-12,dimensions.y*.15)
 var h:=StyleBoxFlat.new();h.bg_color=accent.lightened(.78) if ready else Color("e3e9f2");h.set_corner_radius_all(12)
 header.set_script(Surface);header.add_theme_stylebox_override("panel",h);header.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(header)
 var badge:=Panel.new();badge.position=Vector2(10,10);badge.size=Vector2(dimensions.y*.15,dimensions.y*.15)
 var b:=StyleBoxFlat.new();b.bg_color=Color("ffdf86");b.border_color=Color("8d7545");b.set_corner_radius_all(100);b.set_border_width_all(1)
 badge.add_theme_stylebox_override("panel",b);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(badge)
 var cost:=CardStyle.label(self,str(int(entry.cost)),badge.position,badge.size,28 if large else 23,CardStyle.INK)
 cost.name="CardCost";cost.add_theme_font_override("font",CardStyle.numeric_font());cost.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cost.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var title:=CardStyle.label(self,str(entry.name),Vector2(dimensions.x*.30,6),Vector2(dimensions.x*.65,dimensions.y*.15),24 if large else 17,accent.darkened(.17) if ready else Color("6c7c94"))
 title.name="CardTitle";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 title.max_lines_visible=1;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 var painting:Dictionary=paintings.get(str(entry.id),{})
 var art_size:=Vector2(dimensions.x-20,dimensions.y*.50)
 var art_pos:=Vector2(10,dimensions.y*.20)
 if not painting.is_empty():
  var art:=ColorRect.new();art.name="CardPainting"
  var material:=ShaderMaterial.new();material.shader=preload("res://battle/cute_card_painting.gdshader")
  material.set_shader_parameter("painting_image",load(str(painting.atlas)))
  var cell:=int(painting.cell)
  material.set_shader_parameter("region",Vector4(float(cell%4)/4.0,float(cell/4)/4.0,.25,.25))
  material.set_shader_parameter("view_size",art_size);material.set_shader_parameter("painting_crop",Vector2(1.0,art_size.y/art_size.x))
  art.material=material;art.position=art_pos;art.size=art_size;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.modulate=Color.WHITE if ready else Color(.78,.8,.84,.9);add_child(art)
 else:
  var art:=TextureRect.new();var atlas:=AtlasTexture.new();atlas.atlas=load(str(entry.image));atlas.region=Rect2(9,38,110,94)
  art.texture=atlas;art.position=art_pos;art.size=art_size;art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
  art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.modulate=Color.WHITE if ready else Color(.78,.8,.84,.9);add_child(art)
 var footer:=Panel.new();footer.name="CardFooter";footer.position=Vector2(9,dimensions.y*.72);footer.size=Vector2(dimensions.x-18,dimensions.y*.25)
 var f:=StyleBoxFlat.new();f.bg_color=accent.lightened(.90) if ready else Color("edf0f5");f.set_corner_radius_all(10)
 footer.set_script(Surface);footer.add_theme_stylebox_override("panel",f);footer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(footer)
 var body:=RichTextLabel.new();body.name="CardEffect";body.position=Vector2(3,2);body.size=footer.size-Vector2(6,4)
 body.bbcode_enabled=true;body.scroll_active=false;body.mouse_filter=Control.MOUSE_FILTER_IGNORE;body.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 body.add_theme_font_override("normal_font",CardStyle.body_font());body.add_theme_font_override("bold_font",CardStyle.numeric_font())
 body.add_theme_font_size_override("normal_font_size",17 if large else 15);body.add_theme_constant_override("line_separation",0)
 body.add_theme_color_override("default_color",Color("526b89") if ready else Color("73829a"))
 var description:=str(entry.description).replace("；","\n") if large else _brief_effects(entry)
 var numbers:=RegEx.new();numbers.compile("[0-9]+")
 var number_color:=accent.darkened(.16).to_html(false) if ready else "6c7c94"
 body.text="[center]"+numbers.sub(description,"[b][color=#"+number_color+"][font_size="+str(22 if large else 19)+"]$0[/font_size][/color][/b]",true)+"[/center]"
 footer.add_child(body)
 if not ready:
  var availability:=CardStyle.label(self,"能量不足",art_pos+Vector2(4,art_size.y-22),Vector2(art_size.x-8,20),13,Color("6b5260"))
  availability.name="CardAvailability";availability.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;availability.add_theme_color_override("font_outline_color",Color("f8f9fc"));availability.add_theme_constant_override("outline_size",3)
 # The full hover preview already contains the description; a tooltip would cover the hand.
 tooltip_text=""
 modulate=Color.WHITE

func _brief_effects(entry:Dictionary)->String:
 var formats:Dictionary={"damage":"伤害 %d","block":"格挡 +%d","heal":"生命 +%d","stamina":"体力 +%d","energy":"能量 +%d","draw":"抽 %d 张牌","amplify":"下次伤害 +%d","retrieve":"取回 %d 张弃牌","bind":"束缚 %d 次行动","cleanse":"解除束缚"}
 var lines:Array[String]=[]
 for effect in entry.get("effects",[]):
  var kind:=str(effect.get("kind",""))
  if not formats.has(kind): return str(entry.description)
  lines.append(str(formats[kind]) if kind=="cleanse" else str(formats[kind]) % int(effect.get("value",0)))
 return "\n".join(lines) if not lines.is_empty() else str(entry.description)
