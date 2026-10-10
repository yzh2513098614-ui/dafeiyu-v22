extends SceneTree
const OUT = "res://预览/人物边缘纹理_20261004/"
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures += 1; push_error(message)
func material(style: int) -> ShaderMaterial:
 var shader := Shader.new()
 shader.code = 'shader_type canvas_item;\n#include "res://character/safe_matte.gdshaderinc"\n#include "res://character/edge_ink.gdshaderinc"\nvoid fragment(){ vec4 p=safe_matte_sample(UV);vec2 pixel=1.0/vec2(textureSize(original_frame,0));vec2 step=pixel*edge_ink_width;float a=min(min(original_sample(UV+vec2(step.x,0.0)).a,original_sample(UV-vec2(step.x,0.0)).a),min(original_sample(UV+vec2(0.0,step.y)).a,original_sample(UV-vec2(0.0,step.y)).a));COLOR=edge_ink_paint(p,UV/pixel,a); }'
 var mat := ShaderMaterial.new(); mat.shader = shader
 for pair in [["original_frame","v20"],["before_holes","v21"],["after_holes","v22"]]:
  mat.set_shader_parameter(pair[0],load("res://assets/character/jimeng_%s/down_left/walk_04.png" % pair[1]))
 mat.set_shader_parameter("original_shift",2.0)
 mat.set_shader_parameter("edge_ink_enabled",style>=0)
 mat.set_shader_parameter("edge_ink_style",maxi(style,0))
 return mat
func frames() -> void:
 for i in 3: await process_frame
 await RenderingServer.frame_post_draw
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var texture := load("res://assets/character/jimeng_v23/down_left/walk_04.png") as Texture2D
 var view := SubViewport.new(); view.size=Vector2i(1600,660); view.disable_3d=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
 var bg := ColorRect.new(); bg.size=Vector2(1600,660); bg.color=Color("627d88"); view.add_child(bg)
 var names := ["原轮廓","海港深蓝 · 默认","潮汐青蓝","暮色蓝紫"]
 for i in 4:
  var pic := TextureRect.new(); pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; pic.texture=texture; pic.material=material(i-1); pic.position=Vector2(i*400+8,45); pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pic.size=Vector2(384,555); view.add_child(pic)
  var label := Label.new(); label.text=names[i]; label.position=Vector2(i*400+20,605); label.size=Vector2(360,40); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf")); label.add_theme_font_size_override("font_size",26); view.add_child(label)
 await frames(); view.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"01_三种边缘纹理.png"))
 var native := SubViewport.new(); native.size=Vector2i(1024,1152); native.disable_3d=true; native.transparent_bg=true; native.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(native)
 var full := TextureRect.new(); full.texture=texture; full.size=Vector2(1024,1152); full.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; full.material=material(-1); native.add_child(full)
 await frames(); var base := native.get_texture().get_image()
 full.material=material(0); await frames(); var ink := native.get_texture().get_image()
 var alpha_changes := 0; var interior_changes := 0; var changed := 0
 for y in range(8,1144,4):
  for x in range(8,1016,4):
   var a := base.get_pixel(x,y); var b := ink.get_pixel(x,y)
   if absf(a.a-b.a) > .005: alpha_changes+=1
   if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > .01:
    changed+=1
    var core := true
    for dy in [-4,0,4]:
     for dx in [-4,0,4]:
      if base.get_pixel(x+dx,y+dy).a < .99: core=false
    if core: interior_changes+=1
 check(changed>20,"edge texture visibly overlays contour")
 check(alpha_changes==0,"overlay preserves silhouette alpha")
 check(interior_changes==0,"opaque interior artwork preserved")
 var file := FileAccess.open(OUT+"验证记录.json",FileAccess.WRITE); file.store_string(JSON.stringify({"failures":failures,"sampled_changed_pixels":changed,"alpha_changes":alpha_changes,"interior_changes":interior_changes},"  "))
 print("EDGE INK CHECKS COMPLETE, FAILURES ",failures)
 quit(0 if failures==0 else 1)
