extends SceneTree
## Native-resolution render preparation; never draws, resizes or deforms bodies.
const OUT := "res://assets/character/jimeng_v24/"
var view: SubViewport
var sprite: Sprite2D
var material: ShaderMaterial
var failures := 0
func _initialize() -> void: call_deferred("run")
func render(mask: bool) -> Image:
 material.set_shader_parameter("mask_only",mask)
 view.render_target_update_mode=SubViewport.UPDATE_ONCE
 await process_frame
 await RenderingServer.frame_post_draw
 var result := view.get_texture().get_image(); result.convert(Image.FORMAT_RGBA8)
 return result
func check(ok: bool, message: String) -> void:
 if not ok: failures+=1; push_error(message)
func run() -> void:
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
 if manifest.get("runtime_matte_baked",false):
  manifest=JSON.parse_string(FileAccess.get_file_as_string(OUT+"source_manifest.json"))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var backup:=FileAccess.open(OUT+"source_manifest.json",FileAccess.WRITE); backup.store_string(JSON.stringify(manifest,"  ")); backup.close()
 view=SubViewport.new(); view.size=Vector2i(1024,1152); view.disable_3d=true; view.transparent_bg=true; view.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(view)
 sprite=Sprite2D.new(); sprite.centered=false; sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; view.add_child(sprite)
 material=ShaderMaterial.new(); material.shader=load("res://character/bake_matte.gdshader"); sprite.material=material
 var mapped: Dictionary={}; var records: Array=[]
 var shifts := [4,2,3,2,2,3,2,2,2,2,2,2]
 for direction in manifest.atlas_order:
  var folder:=OUT+str(direction)+"/"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder+"masks/"))
  for entry in manifest.frames_by_state.walk[direction]:
   var path:=str(entry)
   if mapped.has(path): continue
   var source:=load(path) as Texture2D
   check(source!=null,"Missing source "+path)
   if source==null: continue
   sprite.texture=source; material.set_shader_parameter("source_frame",source)
   material.set_shader_parameter("safe_matte_enabled",str(direction)=="down_left")
   if str(direction)=="down_left":
    var filename:=path.get_file(); var index:=int(filename.get_basename().trim_prefix("walk_"))
    material.set_shader_parameter("original_frame",load("res://assets/character/jimeng_v20/down_left/"+filename))
    material.set_shader_parameter("before_holes",load("res://assets/character/jimeng_v21/down_left/"+filename))
    material.set_shader_parameter("after_holes",load("res://assets/character/jimeng_v22/down_left/"+filename))
    material.set_shader_parameter("original_shift",float(shifts[index]))
   var baked: Image=await render(false)
   var mask: Image=await render(true)
   var target:=folder+path.get_file()
   var mask_path:=folder+"masks/"+path.get_file()
   check(baked.get_size()==Vector2i(1024,1152),"Canvas changed "+path)
   check(baked.get_used_rect().get_area()>10000,"Empty character "+path)
   var mask_diffs:=0
   for y in range(0,1152,12):
    for x in range(0,1024,12):
     if absf(baked.get_pixel(x,y).a-mask.get_pixel(x,y).r)>.008: mask_diffs+=1
   check(mask_diffs==0,"Mask differs from baked alpha "+path)
   if str(direction)=="down_left" and path.get_file()=="walk_04.png":
    check(baked.get_pixel(782,520).a<.1,"Upper hair gap still white")
    check(baked.get_pixel(754,760).a<.1,"Tail-root gap still white")
    check(baked.get_pixel(270,432).a>.95,"Left ear damaged")
   baked.fix_alpha_edges()
   check(baked.save_png(ProjectSettings.globalize_path(target))==OK,"Cannot save "+target)
   check(mask.save_png(ProjectSettings.globalize_path(mask_path))==OK,"Cannot save "+mask_path)
   mapped[path]=target
   records.append({"source":path,"frame":target,"alpha_mask":mask_path,"size":[1024,1152],"mask_diffs":mask_diffs})
  print("BAKED ",direction)
 var report:=FileAccess.open(OUT+"validation.json",FileAccess.WRITE); report.store_string(JSON.stringify({"failures":failures,"unique_frames":records.size(),"frames":records},"  ")); report.close()
 if failures>0: print("BAKE FAILED ",failures,"; active manifest unchanged"); quit(1); return
 var next:=manifest.duplicate(true)
 for state in next.frames_by_state:
  for direction in next.frames_by_state[state]:
   var sequence: Array=next.frames_by_state[state][direction]
   for i in sequence.size(): sequence[i]=mapped[str(sequence[i])]
 next.version=9
 next.method="native_complete_frames_baked_alpha_masks_and_blue_ink"
 next.runtime_matte_baked=true
 next.baked_source_manifest=OUT+"source_manifest.json"
 next.mask_note="Explicit per-frame alpha masks; original size and sequence; no runtime colour key or erosion. Ink baked once, disable runtime ink."
 var file:=FileAccess.open("res://assets/character/manifest.json",FileAccess.WRITE); file.store_string(JSON.stringify(next,"  ")); file.close()
 print("BAKED MATTE COMPLETE ",records.size()," FRAMES; FAILURES ",failures)
 quit()
