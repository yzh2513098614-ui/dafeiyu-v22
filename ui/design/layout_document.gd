extends RefCounted
## Native editable scenes + immutable baselines. Only visual deltas reach live controls.
const DIRECTORY="res://ui/design/"
const DECORATION_SCRIPTS=["res://ui/ocean_menu_backdrop.gd","res://ui/ocean_menu_panel.gd","res://ui/ocean_menu_button.gd","res://ui/handheld_panel.gd"]
const IGNORED=["script","owner","name","unique_name_in_owner","process_mode","process_priority","process_physics_priority","visible","disabled","button_pressed","value","text","bbcode_enabled","scroll_horizontal","scroll_vertical","selected","mouse_filter","focus_mode","mouse_default_cursor_shape","tooltip_text"]
static var resource_cache:Dictionary={}
static var fingerprint_cache:Dictionary={}

static func is_visual(name:String)->bool:
 if name in IGNORED or name.begins_with("metadata/"):return false
 return name.begins_with("theme") or name.begins_with("anchor_") or name.begins_with("offset_") or name.begins_with("grow_") or name.begins_with("size_flags_") or name in ["custom_minimum_size","layout_mode","scale","rotation","pivot_offset","modulate","self_modulate","texture","icon","material","color","texture_filter","expand_mode","stretch_mode","expand_icon","alignment","horizontal_alignment","vertical_alignment","autowrap_mode","text_overrun_behavior","clip_contents","columns","separation","placeholder_text","max_lines_visible","z_index"]

static func normalize(value:Variant)->Variant:
 if not value is Resource:return value
 var resource:Resource=value
 if resource_cache.has(resource.get_instance_id()):return resource_cache[resource.get_instance_id()]
 if resource.resource_path.begins_with("res://") and not resource.resource_path.contains("::"):
  return load(resource.resource_path)
 if resource is FontFile:
  for filename in ["res://assets/fonts/misans/MiSans-Demibold.ttf","res://assets/fonts/misans/MiSans-Bold.ttf","res://assets/NotoSansSC.ttf"]:
   var font:FontFile=load(filename)
   if font.get_font_name()==resource.get_font_name() and font.get_font_style_name()==resource.get_font_style_name():return font
 if resource is Texture2D:
  var Skin=load("res://ui/handheld_skin.gd")
  for key in Skin.textures:
   if resource==Skin.textures[key]:return load(Skin.icon_path(key))
  var img:Image=resource.get_image()
  if img==null:return resource
  var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256);digest.update(img.get_data())
  var filename:=DIRECTORY+"preview_assets/"+digest.finish().hex_encode()+".png"
  if not FileAccess.file_exists(filename):
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY+"preview_assets"))
   img.save_png(ProjectSettings.globalize_path(filename))
  var result:=ImageTexture.create_from_image(img)
  result.resource_path=filename
  resource_cache[resource.get_instance_id()]=result
  return result
 var copy:Resource=resource.duplicate()
 resource_cache[resource.get_instance_id()]=copy
 for property in resource.get_property_list():
  var key:String=property.name
  if int(property.usage)&PROPERTY_USAGE_STORAGE and not key in ["script","resource_path"]:
   var child:Variant=resource.get(key)
   if child is Resource:copy.set(key,normalize(child))
 return copy

static func readable_name(node:Control,index:int)->String:
 var label:=str(node.name)
 if label.begins_with("@") or label==node.get_class():
  label=node.get_class()
  if node is Button or node is Label:label+="_"+str(node.get("text")).left(18)
 for invalid in ["/",":","@","\"",".","\n","\r"]:label=label.replace(invalid,"_")
 return "%02d_%s"%[index,label]

static func copy_control(source:Control,id:String,excluded:Array)->Control:
 var clone:Control=ClassDB.instantiate(source.get_class())
 clone.name=readable_name(source,source.get_index())
 var decoration:Script=source.get_script()
 if decoration!=null and decoration.resource_path in DECORATION_SCRIPTS:clone.set_script(decoration)
 for property in source.get_property_list():
  var key:String=property.name
  if not(int(property.usage)&PROPERTY_USAGE_STORAGE) or key in ["script","owner","name"] or key.begins_with("metadata/"):continue
  # Runtime scripts may expose variables. Only properties available on the native Control are copied.
  if not has_property(clone,key):continue
  clone.set(key,normalize(source.get(key)))
 clone.set_meta("design_id",id)
 clone.set_meta("design_native_class",source.get_class())
 var text:=str(source.get("text")) if source is Label or source is Button else ""
 var digits:=RegEx.new();digits.compile("[0-9]")
 clone.set_meta("design_edit_text",text!="" and digits.search(text)==null and not text.begins_with("自动") and not text in ["开启 ✓","关闭","已选择","已装备"])
 clone.set_meta("design_note","只编辑视觉属性。文本、禁用、选中与数值由游戏数据更新。")
 for child in source.get_children():
  if child is Control and not child in excluded:
   var child_id:=str(child.get_index()) if id=="." else id+"/"+str(child.get_index())
   clone.add_child(copy_control(child,child_id,excluded))
 return clone

static func has_property(node:Object,key:String)->bool:
 for property in node.get_property_list():
  if str(property.name)==key:return true
 return false

static func own_children(node:Node,root:Node)->void:
 for child in node.get_children():
  child.owner=root;own_children(child,root)

static func capture(id:String,source:Control,title:String,excluded:Array=[])->Dictionary:
 resource_cache.clear()
 var page:=Control.new();page.name="UI_"+id;page.size=Vector2(1448,1086);page.mouse_filter=Control.MOUSE_FILTER_IGNORE
 page.theme=Theme.new();page.theme.default_font=load("res://assets/NotoSansSC.ttf")
 page.set_meta("design_page",id);page.set_meta("design_title",title)
 page.set_meta("design_help","修改带 design_id 的原生控件；保存后 F5 使用新设计。不要删除 design_id。")
 var clone:=copy_control(source,".",excluded);page.add_child(clone);clone.visible=true
 if source.get_parent() is Control and source.get_parent()!=source.get_viewport():
  # Root offsets remain relative to the original design canvas, except local panels already scoped.
  pass
 own_children(page,page)
 var packed:=PackedScene.new();var error:=packed.pack(page)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY+"pages"))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY+"baselines"))
 if error==OK:error=ResourceSaver.save(packed,DIRECTORY+"baselines/"+id+".tscn")
 var editable:=DIRECTORY+"pages/"+id+".tscn"
 # Recapture never overwrites an existing user design.
 if error==OK and not FileAccess.file_exists(editable):error=ResourceSaver.save(packed,editable)
 var editable_controls:Dictionary={};collect(page,editable_controls)
 var count:=editable_controls.size()
 page.free();resource_cache.clear()
 return {"id":id,"title":title,"scene":editable,"controls":count,"error":error}

static func collect(node:Node,result:Dictionary)->void:
 if node is Control and node.has_meta("design_id"):result[str(node.get_meta("design_id"))]=node
 for child in node.get_children():collect(child,result)

static func fingerprint(value:Variant)->Variant:
 if not value is Resource:return value
 var resource:Resource=value
 if fingerprint_cache.has(resource.get_instance_id()):return fingerprint_cache[resource.get_instance_id()]
 if resource is Texture2D or resource is FontFile or resource is Shader:
  return resource.get_class()+":"+resource.resource_path
 var values:Dictionary={"class":resource.get_class()}
 for property in resource.get_property_list():
  var key:String=property.name
  if int(property.usage)&PROPERTY_USAGE_STORAGE and not key in ["script","resource_name","resource_path","resource_local_to_scene"]:
   var child:Variant=resource.get(key)
   if child is PackedByteArray:values[key]=hash(child)
   else:values[key]=fingerprint(child)
 fingerprint_cache[resource.get_instance_id()]=values
 return values

static func changes(id:String)->Dictionary:
 fingerprint_cache.clear()
 var editable:=DIRECTORY+"pages/"+id+".tscn";var baseline:=DIRECTORY+"baselines/"+id+".tscn"
 if not ResourceLoader.exists(editable) or not ResourceLoader.exists(baseline):return {}
 if FileAccess.get_file_as_string(editable)==FileAccess.get_file_as_string(baseline):return {}
 var edited_scene:PackedScene=ResourceLoader.load(editable,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
 var baseline_scene:PackedScene=ResourceLoader.load(baseline,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
 var edited:Control=edited_scene.instantiate();var original:Control=baseline_scene.instantiate()
 var after:Dictionary={};var before:Dictionary={};collect(edited,after);collect(original,before)
 var patch:Dictionary={}
 for key in after:
  if not before.has(key):continue
  var a:Control=after[key];var b:Control=before[key];var properties:Dictionary={}
  var before_properties:Dictionary={}
  for property in b.get_property_list():before_properties[str(property.name)]=true
  for property in a.get_property_list():
   var name:String=property.name
   if int(property.usage)&PROPERTY_USAGE_STORAGE and (is_visual(name) or (name=="text" and bool(a.get_meta("design_edit_text",false)))) and before_properties.has(name):
    var new_value:Variant=a.get(name);var old_value:Variant=b.get(name)
    if fingerprint(new_value)!=fingerprint(old_value):properties[name]=new_value
  # Removed Theme Overrides must remove the corresponding runtime override.
  for property in b.get_property_list():
   var name:String=property.name
   if name.begins_with("theme_override") and not has_property(a,name):properties[name]=null
  if not properties.is_empty():patch[key]={"class":str(b.get_meta("design_native_class",b.get_class())),"properties":properties}
 original.free();edited.free();fingerprint_cache.clear()
 return patch

static func target(root:Control,key:String)->Control:
 var node:Node=root
 if key!=".":
  for segment in key.split("/"):
   var index:=int(segment)
   if index>=node.get_child_count():return null
   node=node.get_child(index)
 return node as Control

static func apply(root:Control,patch:Dictionary)->int:
 var applied:=0
 for key in patch:
  var node:=target(root,str(key))
  if node==null or node.get_class()!=str(patch[key]["class"]):continue
  for property in patch[key].properties:
   node.set(property,patch[key].properties[property])
  node.queue_redraw();applied+=1
 return applied
