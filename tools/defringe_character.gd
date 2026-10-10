extends SceneTree
## Native texture preparation, preserving original video and generated frames.
const OUTPUT := "res://assets/character/jimeng_v21/"
var viewport: SubViewport
var sprite: Sprite2D
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/manifest.json"))
 # Reprocess original source textures even if the tool is run twice.
 if old.has("border_cleanup_source_manifest"):
  old=JSON.parse_string(FileAccess.get_file_as_string(str(old.border_cleanup_source_manifest)))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var backup:=FileAccess.open(OUTPUT+"source_manifest.json",FileAccess.WRITE)
 backup.store_string(JSON.stringify(old,"  "));backup.close()
 var next: Dictionary=old.duplicate(true)
 viewport=SubViewport.new();viewport.disable_3d=true;viewport.transparent_bg=true
 viewport.size=Vector2i(1024,1152);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 sprite=Sprite2D.new();sprite.centered=false;sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var material:=ShaderMaterial.new();material.shader=load("res://character/alpha_border_cleanup.gdshader")
 sprite.material=material;viewport.add_child(sprite)
 var mapped: Dictionary={};var records: Array=[]
 for direction in old.atlas_order:
  var radius: float=6.0 if str(old.provenance.get(direction,""))!="video" else 2.0
  var folder:=OUTPUT+str(direction)+"/"
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
  for source in old.frames_by_state.walk[direction]:
   if mapped.has(source):continue
   var image:=Image.load_from_file(str(source))
   image.fix_alpha_edges()
   sprite.texture=ImageTexture.create_from_image(image);material.set_shader_parameter("radius",radius)
   await process_frame;await RenderingServer.frame_post_draw
   var cleaned:=viewport.get_texture().get_image();cleaned.convert(Image.FORMAT_RGBA8)
   # Restore exactly the same floor anchor after trimming the contaminated rim.
   var foot:=floor_row(cleaned)
   var shift:=1080-foot
   var registered:=Image.create(1024,1152,false,Image.FORMAT_RGBA8)
   registered.fill(Color.TRANSPARENT)
   registered.blit_rect(cleaned,Rect2i(0,0,1024,1152),Vector2i(0,shift))
   registered.fix_alpha_edges()
   var target:=folder+str(source).get_file()
   if registered.save_png(ProjectSettings.globalize_path(target))!=OK:push_error("Cannot save cleaned texture");quit(1);return
   mapped[source]=target
   records.append({"source":source,"output":target,"rim_pixels":radius,"foot_shift":shift,"floor_y":floor_row(registered),"canvas":[1024,1152]})
  print("CLEANED ALPHA BORDER ",direction)
 for state in next.frames_by_state:
  for direction in next.frames_by_state[state]:
   var sequence: Array=next.frames_by_state[state][direction]
   for n in sequence.size():sequence[n]=mapped[str(sequence[n])]
 next.version=6;next.method="complete_png_native_alpha_border_cleanup"
 next.border_cleanup_source_manifest=OUTPUT+"source_manifest.json"
 next.border_cleanup="native alpha edge color bleed, exterior rim cleanup, fixed foot re-registration; no resize or body deformation"
 next.note="Source artwork retained separately. Full character pictures only; RGB inside retained silhouette unchanged. Transparent RGB prepared for linear sampling."
 var report:=FileAccess.open(OUTPUT+"border_cleanup.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"frames":records,"unique_frames":records.size()},"  "));report.close()
 var file:=FileAccess.open("res://assets/character/manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(next,"  "));file.close()
 print("ALPHA BORDER CLEANUP COMPLETE ",records.size()," unique frames")
 quit()
func floor_row(image: Image) -> int:
 for y in range(image.get_height()-1,-1,-1):
  for x in range(image.get_width()):
   if image.get_pixel(x,y).a>=.28:return y+1
 return 0
