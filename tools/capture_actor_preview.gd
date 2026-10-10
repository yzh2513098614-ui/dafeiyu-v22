extends SceneTree
## Capture actual room rendering, never an AI reconstruction of the room.
var game: Node3D
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 game=load("res://room_3d.tscn").instantiate();root.add_child(game)
 for n in 12:await process_frame
 game.set_physics_process(false);game.ui.hide();game.atmosphere.set_effects(false)
 for layout in 3:
  game._layout(layout);game.player.position=Vector3(.3,0,2.0)
  for state in ["idle","walk"]:
   game.avatar.play(state+"_down");game.avatar.pause();game.avatar.frame=0
   for n in 4:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://预览/人物融合验证/房间%d_%s.png"%[layout,state])
 game._layout(0);game.player.position=Vector3(.3,0,2.0)
 for row in 4:
  var direction: String=["down","left","up","right"][row]
  game.avatar.play("walk_"+direction);game.avatar.pause()
  for frame in 6:
   game.avatar.frame=frame
   for n in 2:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://预览/人物融合验证/行走_%s_%d.png"%[direction,frame])
 print("ACTUAL ROOM CAPTURES COMPLETE");quit()
