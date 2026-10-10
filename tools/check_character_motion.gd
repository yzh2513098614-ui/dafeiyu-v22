extends SceneTree
## Small integration check: real character, real corridor, real room wall.
## Run only after the new character resources have been imported.
var game
var failures:=0
var checks:=0
var measured: Dictionary={}

func _initialize() -> void:
 call_deferred("_run")

func _run() -> void:
 var packed: PackedScene=load("res://district/continuous_world.tscn")
 if packed==null:push_error("Character check could not load continuous_world.tscn");quit(1);return
 game=packed.instantiate();root.add_child(game)
 await _ticks(3)
 game._travel("apt_2")
 game.overview_mode=false;game.view_size=18;game.view_center=Vector3.ZERO
 await _ticks(3)
 _check(game.player!=null and game.avatar!=null,"actual continuous scene creates its character")
 _check(not game.avatar.no_depth_test,"character uses the room's depth testing")
 _check(game.frames.has_animation("walk_down") and game.frames.has_animation("walk_left") and game.frames.has_animation("walk_up") and game.frames.has_animation("walk_right"),"all four directions are connected")
 var texture: Texture2D=game.frames.get_frame_texture("walk_down",0)
 var source: String=texture.atlas.resource_path if texture is AtlasTexture else texture.resource_path
 measured["walk_texture"]=source
 _check(not source.contains("assets/animations/walk_atlas.png"),"new walk art is the active texture")
 await _four_directions()
 await _door_and_wall()
 game.movement=Vector2.ZERO
 print("CHARACTER_MOTION_CHECKS ",checks," FAILURES ",failures)
 print("CHARACTER_MOTION_MEASUREMENTS ",JSON.stringify(measured))
 quit(1 if failures>0 else 0)

func _four_directions() -> void:
 var names: Array=["right","up","left","down"]
 var inputs: Array=[Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN]
 var walks: Dictionary={}
 for i in names.size():
  game.movement=Vector2.ZERO;game.player.position=Vector3.ZERO;game.player.velocity=Vector3.ZERO
  await _ticks(3)
  var start: Vector3=game.player.position
  var frames_seen: Dictionary={}
  game.movement=inputs[i]
  for step in 30:
   await _ticks(1)
   if game.avatar.animation=="walk_"+str(names[i]):frames_seen[game.avatar.frame]=true
  var travel: float=start.distance_to(game.player.position)
  _check(travel>.35,"actual movement advances in "+str(names[i]))
  _check(game.avatar.animation=="walk_"+str(names[i]),"camera-relative facing is "+str(names[i]))
  _check(frames_seen.size()>1,"walk frames change while moving "+str(names[i]))
  game.movement=Vector2.ZERO
  await _ticks(10)
  _check(str(game.avatar.animation).begins_with("idle_"),"releasing movement stops the walk in "+str(names[i]))
  walks[names[i]]={"distance":travel,"walk_frames_seen":frames_seen.size(),"stop_animation":game.avatar.animation}
 measured["four_directions"]=walks

func _door_and_wall() -> void:
 var zone: Dictionary=game.room_zones[0]
 var rectangle: Rect2=zone.rect
 var door: Vector3=zone.door
 var south: bool=rectangle.get_center().y>0
 var into:=Vector3(0,0,1 if south else -1)
 var original_location: String=game.location_id
 game.movement=Vector2.ZERO;game.player.position=door-into*1.10;game.player.velocity=Vector3.ZERO
 await _ticks(3)
 game.movement=_camera_input(into)
 var largest_step:=0.0
 var walked:=0.0
 for tick in 65:
  var previous: Vector3=game.player.position
  await _ticks(1)
  var distance: float=previous.distance_to(game.player.position)
  walked+=distance;largest_step=maxf(largest_step,distance)
 game.movement=Vector2.ZERO
 await _ticks(4)
 _check(rectangle.has_point(Vector2(game.player.position.x,game.player.position.z)),"character crosses a real room doorway")
 _check(game.location_id==original_location and largest_step<.20,"room entry stays in the same space without a position jump")
 measured["door"]={"zone":zone.name,"path_length":walked,"largest_step":largest_step,"end":[game.player.position.x,game.player.position.z]}

 # The same movement now meets a solid portion of that room's front wall.
 var wall_x: float=clampf(door.x+3.8,rectangle.position.x+.8,rectangle.end.x-.8)
 game.player.position=Vector3(wall_x,0,door.z)-into*1.10;game.player.velocity=Vector3.ZERO
 await _ticks(3)
 game.movement=_camera_input(into)
 await _ticks(55)
 var stopped_at: Vector3=game.player.position
 var states: Dictionary={}
 for tick in 18:
  await _ticks(1);states[str(game.avatar.animation)]=true
 var blocked_travel: float=stopped_at.distance_to(game.player.position)
 _check(blocked_travel<.01,"holding movement into a real wall does not move the feet")
 var only_idle:=true
 for animation in states:
  if not str(animation).begins_with("idle_"):only_idle=false
 _check(only_idle,"blocked movement settles to idle instead of walking in place")
 _check(absf(game.player.position.y)<.001,"feet remain on the floor")
 measured["wall"]={"blocked_distance":blocked_travel,"animations":states.keys(),"position":[game.player.position.x,game.player.position.z]}
 game.movement=Vector2.ZERO

func _camera_input(world_direction: Vector3) -> Vector2:
 var right: Vector3=game.camera.global_basis.x;right.y=0;right=right.normalized()
 var down: Vector3=game.camera.global_basis.z;down.y=0;down=down.normalized()
 return Vector2(world_direction.dot(right),world_direction.dot(down))

func _ticks(count: int) -> void:
 for i in count:
  await physics_frame
  await process_frame

func _check(condition: bool,text: String) -> void:
 checks+=1
 if condition:print("PASS ",text)
 else:failures+=1;push_error("FAIL "+text)
