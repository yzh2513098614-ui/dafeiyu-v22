extends SceneTree
const OUT = "res://预览/斜左下无损去白_20261004/"
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures += 1; push_error(message)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var view := SubViewport.new()
 view.size = Vector2i(2048, 1728); view.disable_3d = true
 view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var background := ColorRect.new(); background.color = Color("627d88"); background.size = Vector2(2048,1728); view.add_child(background)
 var shader := Shader.new()
 shader.code = 'shader_type canvas_item;\n#include "res://character/safe_matte.gdshaderinc"\nvoid fragment(){ COLOR = safe_matte_sample(UV); }'
 var report: Array = []
 var shifts := [4,2,3,2,2,3,2,2,2,2,2,2]
 var native := SubViewport.new(); native.size = Vector2i(1024,1152); native.disable_3d = true; native.transparent_bg = true
 native.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(native)
 var native_picture := TextureRect.new(); native_picture.size = Vector2(1024,1152); native_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; native.add_child(native_picture)
 for i in 12:
  var filename := "walk_%02d.png" % i
  var source := load("res://assets/character/jimeng_v20/down_left/"+filename) as Texture2D
  var old := load("res://assets/character/jimeng_v23/down_left/"+filename) as Texture2D
  var before := load("res://assets/character/jimeng_v21/down_left/"+filename) as Texture2D
  var after := load("res://assets/character/jimeng_v22/down_left/"+filename) as Texture2D
  check(source != null and old != null and before != null and after != null, filename+" source textures exist")
  check(source.get_size() == Vector2(1024,1152), filename+" original resolution preserved")
  var origin := Vector2((i%4)*512, (i/4)*576)
  for side in 2:
   var picture := TextureRect.new(); picture.texture = old
   picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
   picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   picture.position = origin + Vector2(side*256,40); picture.size = Vector2(256,504)
   view.add_child(picture)
   var label := Label.new(); label.text = "%02d · %s" % [i, "旧削边" if side==0 else "原帧保护"]
   label.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf")); label.add_theme_font_size_override("font_size",22)
   label.position = origin + Vector2(side*256+15,10); view.add_child(label)
   if side == 1:
    var material := ShaderMaterial.new(); material.shader = shader
    material.set_shader_parameter("original_frame",source)
    material.set_shader_parameter("before_holes",before)
    material.set_shader_parameter("after_holes",after)
    material.set_shader_parameter("original_shift",float(shifts[i]))
    picture.material = material
    native_picture.texture = old; native_picture.material = material
  for n in 2: await process_frame
  await RenderingServer.frame_post_draw
  var recovered := native.get_texture().get_image()
  var original_pixels := source.get_image()
  var before_pixels := before.get_image(); var after_pixels := after.get_image()
  var tested := 0; var mismatches := 0
  for y in range(170,1060,8):
   for x in range(280,780,8):
    var uv := Vector2(float(x)/1024.0,float(y)/1152.0)
    var hair := uv.y > .405 and uv.y < .66 and (uv.x < .395 or uv.x > .65)
    var tail := uv.x > .712 and uv.y > .59 and uv.y < .83
    if hair or tail: continue
    var p := original_pixels.get_pixel(x,y-shifts[i])
    if p.a < .99 or before_pixels.get_pixel(x,y).a < .99 or after_pixels.get_pixel(x,y).a < .99: continue
    var q := recovered.get_pixel(x,y)
    var core := true
    for dy in [-4,0,4]:
     for dx in [-4,0,4]:
      if original_pixels.get_pixel(x+dx,y-shifts[i]+dy).a < .99 or after_pixels.get_pixel(x+dx,y+dy).a < .99: core = false
    if not core: continue
    tested += 1
    if q.a < .99 or maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b))) > .016:
     mismatches += 1
     print("PROTECTED DIFF ",filename," ",Vector2i(x,y)," ",p," -> ",q)
  check(tested > 200 and mismatches == 0, filename+" protected original pixels unchanged: %d checked, %d damaged" % [tested,mismatches])
  var ear_restored := 0
  var ear_white := 0
  var old_pixels := old.get_image()
  for y in range(390,472,2):
   for x in range(212,323,2):
    if old_pixels.get_pixel(x,y).a < .1 and recovered.get_pixel(x,y).a > .99: ear_restored += 1
    var ear_pixel := original_pixels.get_pixel(x,y-shifts[i])
    if ear_pixel.a > .99 and minf(ear_pixel.r,minf(ear_pixel.g,ear_pixel.b)) > .84 and recovered.get_pixel(x,y).a > .99: ear_white += 1
  check(ear_white > 80,filename+" white ear intact: %d samples; restored: %d" % [ear_white,ear_restored])
  report.append({"frame":filename,"original":source.resource_path,"shift":shifts[i]})
  if i == 4:
   check(recovered.get_pixel(782,520).a < .1,"marked upper-right hair opening is transparent")
   check(recovered.get_pixel(754,760).a < .1,"marked tail-root studio triangle is transparent")
   var bg := ColorRect.new(); bg.color = Color("627d88"); bg.size = Vector2(1024,1152); native.add_child(bg); native.move_child(bg,0)
   for n in 2: await process_frame
   await RenderingServer.frame_post_draw
   native.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"02_第四帧放大检查.png"))
   var detail := SubViewport.new(); detail.size = Vector2i(600,220); detail.disable_3d = true; detail.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(detail)
   var detail_bg := ColorRect.new(); detail_bg.color = Color("627d88"); detail_bg.size = Vector2(600,220); detail.add_child(detail_bg)
   for side in 2:
    var clip := Control.new(); clip.position = Vector2(side*300,30); clip.size = Vector2(300,190); clip.clip_contents = true; detail.add_child(clip)
    var pic := TextureRect.new(); pic.texture = old; pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pic.size = Vector2(1024,1152); pic.position = Vector2(-200,-340); clip.add_child(pic)
    if side==1: pic.material = native_picture.material
    var title := Label.new(); title.text = "修补前" if side==0 else "修补后"; title.position = Vector2(side*300+100,0); title.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf")); title.add_theme_font_size_override("font_size",22); detail.add_child(title)
   for n in 2: await process_frame
   await RenderingServer.frame_post_draw
   detail.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"03_左耳修补放大对比.png")); detail.queue_free()
   var gap_view := SubViewport.new(); gap_view.size=Vector2i(340,420); gap_view.disable_3d=true; gap_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(gap_view)
   var gap_bg := ColorRect.new(); gap_bg.color=Color("627d88"); gap_bg.size=Vector2(340,420); gap_view.add_child(gap_bg)
   var gap_pic := TextureRect.new(); gap_pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; gap_pic.texture=old; gap_pic.size=Vector2(1024,1152); gap_pic.position=Vector2(-585,-420); gap_pic.material=native_picture.material; gap_view.add_child(gap_pic)
   for n in 2: await process_frame
   await RenderingServer.frame_post_draw
   gap_view.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"04_发丝与尾根清理.png")); gap_view.queue_free()
   bg.queue_free(); await process_frame
 for i in 6: await process_frame
 await RenderingServer.frame_post_draw
 var rendered := view.get_texture().get_image()
 rendered.save_png(ProjectSettings.globalize_path(OUT+"01_十二帧去白对比.png"))
 check(rendered.get_size() == Vector2i(2048,1728), "all twelve old/new frames rendered")
 var file := FileAccess.open(OUT+"验证记录.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"failures":failures,"frames":report},"  "))
 print("SAFE MATTE CHECKS COMPLETE, FAILURES ",failures)
 quit(0 if failures==0 else 1)
