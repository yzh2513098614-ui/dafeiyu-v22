extends Node3D
## A pantry shelf conceals the doorway. Uses the world's existing E interaction.
const Library=preload("res://district/decor_library.gd")
const Clearance=preload("res://character/moving_clearance.gd")
const FLAG="restaurant_b1:hidden_door_open"
const DISCOVERY="restaurant_b1:hidden_room_discovered"
var game
var opened:=false
var display_name:="松动的食材架 · 隐藏暗门"
var pivot: Node3D
var blocker: CollisionShape3D
var room: Node3D
var room_equipment: Array[Node3D]=[]
var active_tween: Tween
var shelf_collision: CollisionShape3D
var door_fraction:=0.0

func configure(owner_game,secret_room: Node3D,width: float) -> void:
 game=owner_game;room=secret_room
 pivot=Node3D.new();pivot.position.x=-width/2;add_child(pivot)
 var shelf: Node3D=Library.instance("restaurant_pantry_shelf")
 shelf.scale.x=(width+.2)/1.73;shelf.position.x=width/2;pivot.add_child(shelf)
 shelf_collision=shelf.get_node("Body/Collision")
 var body:=StaticBody3D.new();add_child(body)
 blocker=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(width,2,.40)
 blocker.shape=shape;blocker.position.y=1;body.add_child(blocker)
 opened=bool(game.visited.get(FLAG,false))
 door_fraction=1.0 if opened else 0.0
 pivot.rotation.y=PI*.5 if opened else 0.0
 blocker.disabled=opened;room.visible=opened or bool(game.visited.get(DISCOVERY,false))
 for object in game.world.get_children():
  if str(object.get_meta("restaurant_group",""))=="RestaurantGroup_6":
   room_equipment.append(object);object.visible=room.visible

func toggle_open() -> void:
 if opened and Clearance.players_overlap(blocker):
  game.hint.text="先离开暗门通道，再合上食材架。";return
 opened=not opened;game.visited[FLAG]=opened
 if opened:game.visited[DISCOVERY]=true
 if active_tween and active_tween.is_valid():active_tween.kill()
 room.visible=bool(game.visited.get(DISCOVERY,false))
 for object in room_equipment:object.visible=room.visible
 game.hint.text="食材架后的暗室打开了。" if opened else "食材架已合上，暗门重新隐藏。"
 game._save()

func _physics_process(delta: float) -> void:
 if not is_instance_valid(pivot):return
 var destination:=1.0 if opened else 0.0
 if is_equal_approx(door_fraction,destination):return
 if not opened and Clearance.players_overlap(blocker):return
 var remaining:=minf(delta/.65,absf(destination-door_fraction))
 while remaining>0:
  var step:=minf(.015,remaining)
  var next:=move_toward(door_fraction,destination,step)
  pivot.rotation.y=smoothstep(0.0,1.0,next)*PI*.5
  if Clearance.players_overlap(shelf_collision):
   pivot.rotation.y=smoothstep(0.0,1.0,door_fraction)*PI*.5;return
  door_fraction=next;remaining-=step
 blocker.set_deferred("disabled",door_fraction>=.999 or (not opened and door_fraction>0))
