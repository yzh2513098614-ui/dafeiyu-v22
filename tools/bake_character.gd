extends SceneTree
const Rig=preload("res://character/character_paper_rig.gd")
const DEST="res://assets/character/"
var viewport: SubViewport
var rig

func _initialize() -> void:
 call_deferred("_bake")

func _bake() -> void:
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEST+"manifest.json"))
 if manifest.get("method","")!="painted_cutout_two_bone_ik":
  push_error("当前使用用户选定的完整人物图集；旧拼腿烘焙器禁止覆盖它。")
  quit(1);return
 var size:=Vector2i(int(manifest.canvas_size[0]),int(manifest.canvas_size[1]))
 viewport=SubViewport.new();viewport.size=size;viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 rig=Rig.new();viewport.add_child(rig)
 rig.configure(load(DEST+"body_parts.png"),load(DEST+"leg_parts.png"),manifest)
 var directions: Array=["down","left","up","right"]
 var counts: Dictionary={"walk":12,"idle":1,"interact":1}
 for state in counts:
  var count: int=counts[state]
  var atlas:=Image.create(size.x*count,size.y*4,false,Image.FORMAT_RGBA8)
  atlas.fill(Color.TRANSPARENT)
  for row in 4:
   for column in count:
    rig.set_pose(directions[row],float(column)/count,state=="walk")
    await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image=viewport.get_texture().get_image()
    atlas.blit_rect(frame,Rect2i(Vector2i.ZERO,size),Vector2i(column*size.x,row*size.y))
  var result:=atlas.save_png(DEST+state+"_atlas_v14.png")
  if result!=OK:push_error("Bake save failed "+state);quit(1);return
 manifest["frame_size"]=[size.x,size.y]
 manifest["frame_counts"]=counts
 manifest["cycle_distance"]=rig.cycle_distance
 manifest["atlas_order"]=directions
 var file:=FileAccess.open(DEST+"manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(manifest,"  "));file.close()
 print("CHARACTER_BAKE_COMPLETE frames=56 cycle_distance=",rig.cycle_distance)
 quit()
