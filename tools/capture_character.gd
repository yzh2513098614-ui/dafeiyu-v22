extends SceneTree
## Render real movement through the production controller; never select sprite frames.
const OUTPUT:="res://预览/人物步态_v14/"
var game
var records: Array=[]

func _initialize() -> void:
 call_deferred("capture")

func capture() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+"序列"))
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game)
 for frame in 8:await process_frame
 game.set_process_unhandled_input(false)
 game._travel("apt_2")
 _layers(game,false)
 game.overview_mode=false;game.view_size=8.0;game.camera.size=8.0
 game.avatar.no_depth_test=false;game.avatar.render_priority=0
 var paths: Array=[
  ["down",Vector2.DOWN,Vector3(-16.6,0,-5.3)],
  ["left",Vector2.LEFT,Vector3(-14.8,0,0)],
  ["up",Vector2.UP,Vector3(-15.4,0,-2.5)],
  ["right",Vector2.RIGHT,Vector3(-17.4,0,1.2)]]
 for path in paths:await _walk(str(path[0]),path[1],path[2])
 game.movement=Vector2.ZERO
 await _ticks(6)
 game.foot_debug.visible=true
 await _photo("脚点定位.png",false)
 game.foot_debug.visible=false
 await _occlusion()
 var file:=FileAccess.open(OUTPUT+"movement_capture.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"source":"production physics movement","frames":records},"  "));file.close()
 print("CHARACTER CAPTURE COMPLETE; rendered_frames=",records.size())
 quit()

func _layers(node: Node,visible: bool) -> void:
 if node is CanvasLayer:node.visible=visible
 for child in node.get_children():_layers(child,visible)

func _ticks(count: int) -> void:
 for tick in count:await physics_frame

func _photo(filename: String,small: bool) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 var picture: Image=root.get_texture().get_image()
 if small:picture.resize(640,480,Image.INTERPOLATE_LANCZOS)
 var error: Error=picture.save_png(OUTPUT+filename)
 if error!=OK:push_error("Could not save "+filename+": "+str(error))

func _walk(direction: String,vector: Vector2,start: Vector3) -> void:
 game.movement=Vector2.ZERO;game.player.position=start;game.player.velocity=Vector3.ZERO
 game.view_center=start;game._camera()
 await _ticks(5)
 game.movement=vector
 var beginning:=Time.get_ticks_msec()
 for index in 36:
  await _ticks(3)
  var filename: String="序列/"+direction+"_%02d.png"%index
  await _photo(filename,true)
  var p: Vector3=game.player.position
  records.append({"direction":direction,"file":filename,"timestamp_ms":Time.get_ticks_msec(),"elapsed_ms":Time.get_ticks_msec()-beginning,"position":[p.x,p.y,p.z],"animation":str(game.avatar.animation),"frame":game.avatar.frame,"speed":game.player.get_real_velocity().length()})
  if index==8:await _photo(direction+"_行走.png",false)
 game.movement=Vector2.ZERO
 await _ticks(4)
 var traveled: float=game.player.position.distance_to(start)
 print("REAL WALK ",direction," distance=",snappedf(traveled,.001)," position=",game.player.position," animation=",game.avatar.animation)

func _occlusion() -> void:
 var furniture=null
 for item in game.items:
  if str(item.module_id) in ["bed_navy","bed_sage"]:furniture=item;break
 if furniture==null:
  print("OCCLUSION CAPTURE SKIPPED: no bed found");return
 # Stand on the clear floor behind the existing bed headboard, outside its collider.
 var position: Vector3=furniture.to_global(Vector3(.28,0,-float(furniture.collision_depth)-.48))
 position.y=0;game.player.position=position;game.player.velocity=Vector3.ZERO
 game.view_center=position;game._camera();game.movement=Vector2.ZERO
 await _ticks(7)
 await _photo("家具遮挡.png",false)
 print("OCCLUSION ",furniture.module_id," actor=",game.player.position," depth_test=",not game.avatar.no_depth_test)
