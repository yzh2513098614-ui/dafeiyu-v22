extends SceneTree
const OUT := "res://预览/人物固定遮罩_v24/"
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures+=1; push_error(message)
func run() -> void:
 if not "--test-merge" in OS.get_cmdline_user_args() or not "--capture-ui" in OS.get_cmdline_user_args() or not "--capture-dialogue" in OS.get_cmdline_user_args():
  push_error("Use isolated test and capture flags");quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
 check(manifest.get("runtime_matte_baked",false),"active manifest uses fixed alpha masks")
 var unique: Dictionary={}
 for direction in manifest.atlas_order:
  for path in manifest.frames_by_state.walk[direction]: unique[path]=true
 var valid := 0
 for path in unique:
  var frame:=load(str(path)) as Texture2D
  var mask:=load(str(path).get_base_dir()+"/masks/"+str(path).get_file()) as Texture2D
  if frame==null or mask==null: continue
  if frame.get_size()==Vector2(1024,1152) and mask.get_size()==frame.get_size(): valid+=1
 check(valid==unique.size(),str(unique.size())+" complete native-resolution frames and masks import correctly")
 var texture:=load("res://assets/character/jimeng_v24/down_left/walk_04.png") as Texture2D
 var image:=texture.get_image()
 check(image.get_pixel(782,520).a<.1,"upper marked hair gap is transparent in saved PNG")
 check(image.get_pixel(754,760).a<.1,"tail-root gap is transparent in saved PNG")
 check(image.get_pixel(270,432).a>.95,"ear remains solid in saved PNG")
 var prefs:=root.get_node("HarborPrefs")
 prefs.starting_place="city"; prefs.continue_game=false
 var game=load("res://district/continuous_world.tscn").instantiate(); root.add_child(game); current_scene=game
 for i in 6: await process_frame
 game.facing="down_left"; game._set_character_pose(false)
 check(game.safe_matte_sources.is_empty(),"game no longer loads live matting sources")
 check(not game.character_material.get_shader_parameter("safe_matte_enabled"),"runtime white removal disabled")
 check(not game.character_material.get_shader_parameter("edge_ink_enabled"),"runtime ink disabled to prevent double borders")
 var count:=0
 for name in game.frames.get_animation_names():
  for i in game.frames.get_frame_count(name):
   var frame: Texture2D=game.frames.get_frame_texture(name,i)
   var state: String=name.get_slice("_",0)
   var direction: String=name.trim_prefix(state+"_")
   var entry=manifest.frames_by_state[state][direction][i]
   var expected: String=str(entry.get("path","")) if entry is Dictionary else str(entry)
   check(frame.resource_path==expected,"imported baked resource "+name+"/"+str(i))
   count+=1
 var view:=SubViewport.new(); view.disable_3d=true; view.size=Vector2i(720,610); view.render_target_update_mode=SubViewport.UPDATE_ONCE; root.add_child(view)
 var bg:=ColorRect.new(); bg.color=Color("627d88"); bg.size=Vector2(720,610); view.add_child(bg)
 for side in 2:
  var pic:=TextureRect.new(); pic.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; pic.texture=texture if side==0 else load("res://assets/character/jimeng_v24/down_left/masks/walk_04.png"); pic.position=Vector2(side*360+10,20); pic.size=Vector2(340,540); pic.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; view.add_child(pic)
  var title:=Label.new(); title.text="游戏直接读取的 PNG" if side==0 else "逐帧透明遮罩"; title.position=Vector2(side*360+10,568); title.size=Vector2(340,34); title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf")); title.add_theme_font_size_override("font_size",24); view.add_child(title)
 for i in 3: await process_frame
 await RenderingServer.frame_post_draw
 view.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"01_固定遮罩与人物.png"))
 print("BAKED ASSET CHECKS COMPLETE ",count," animation entries; FAILURES ",failures)
 quit(0 if failures==0 else 1)
