extends RefCounted
## Generated images are consumed through a corner-preserving shader.
const MANIFEST:="res://assets/battle/ui_painted_v22/kit/regions.json"
const Surface=preload("res://battle/painted_ui_surface.gd")
static var _entries:Dictionary={}
static var _textures:Dictionary={}
static func _lookup(key:String)->Dictionary:
 if _entries.is_empty() and FileAccess.file_exists(MANIFEST):
  _entries=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
 return _entries.get(key,{})
static func apply(control:Control,key:String,color_driver:StyleBoxFlat=null)->void:
 var spec:=_lookup(key)
 if spec.is_empty():return
 var surface_path:="PaintedUiBackdrop/PaintedUiSurface" if control is PanelContainer else "PaintedUiSurface"
 var surface:=control.get_node_or_null(surface_path) as Surface
 if surface==null:
  surface=Surface.new()
  surface.name="PaintedUiSurface"
  surface.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  surface.stretch_mode=TextureRect.STRETCH_SCALE
  surface.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
  surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
  surface.show_behind_parent=true
  surface.color_driver=color_driver
  if control is PanelContainer:
   # Container layout must only manage content, not inset the background into the padding.
   var backdrop:=Node2D.new()
   backdrop.name="PaintedUiBackdrop"
   backdrop.show_behind_parent=true
   control.add_child(backdrop)
   backdrop.add_child(surface)
   surface.size=control.size
   control.resized.connect(func(): surface.size=control.size)
  else:
   control.add_child(surface)
   surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var path:=str(spec.atlas)
 if not _textures.has(path):_textures[path]=load(path)
 surface.texture=_textures[path]
 var material:=ShaderMaterial.new()
 material.shader=preload("res://battle/painted_ui.gdshader")
 var rect:Array=spec.region
 var atlas_size:Vector2=surface.texture.get_size()
 material.set_shader_parameter("atlas_image",surface.texture)
 material.set_shader_parameter("region",Vector4(rect[0]/atlas_size.x,rect[1]/atlas_size.y,rect[2]/atlas_size.x,rect[3]/atlas_size.y))
 var cut:float=float(spec.get("source_corner",32))
 var cuts:Array=spec.get("source_corners",[cut,cut,cut,cut])
 material.set_shader_parameter("source_border",Vector4(cuts[0]/rect[2],cuts[1]/rect[3],cuts[2]/rect[2],cuts[3]/rect[3]))
 var rim:float=float(spec.get("rim",16))
 var borders:Array=spec.get("native_border",[rim,rim,rim,rim])
 material.set_shader_parameter("border_pixels",Vector4(borders[0],borders[1],borders[2],borders[3]))
 material.set_shader_parameter("face_lighten",float(spec.get("face_lighten",0)))
 material.set_shader_parameter("view_size",Vector2(maxf(control.size.x,1),maxf(control.size.y,1)))
 if color_driver:material.set_shader_parameter("surface_tint",color_driver.bg_color)
 surface.material=material
 surface.set_meta("asset_key",key)
 if control is Button:
  for state in ["normal","hover","pressed","disabled","focus"]:
   var existing:StyleBox=control.get_theme_stylebox(state).duplicate()
   var blank:=StyleBoxFlat.new()
   for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
    blank.set_content_margin(side,existing.get_content_margin(side))
   blank.bg_color=Color.TRANSPARENT
   if state=="focus":
    blank.set_border_width_all(2);blank.border_color=Color("75adbd");blank.set_corner_radius_all(14)
   control.add_theme_stylebox_override(state,blank)
 elif control is Panel:
  control.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 elif control is PanelContainer:
  var existing:StyleBox=control.get_theme_stylebox("panel")
  var blank:=StyleBoxFlat.new()
  blank.bg_color=Color.TRANSPARENT
  for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
   blank.set_content_margin(side,existing.get_content_margin(side))
  control.add_theme_stylebox_override("panel",blank)
static func panel(control:Panel,kind:String)->void:
 var key:String={"hand_tray":"hand_tray","status":"status","plate":"tag","sky":"paper","card":"paper","paper":"paper","panel":"paper"}.get(kind,"paper")
 apply(control,key)
static func button(control:Button,role:String="secondary")->void:
 var key:String={"attack":"primary","primary":"primary","target":"target","intent_cast":"target","heal":"secondary","multihit":"secondary","move":"secondary"}.get(role,"secondary")
 apply(control,key)

