extends Node
## Development game sessions follow parameters saved by the editor tool.
const Proportions = preload("res://character/proportion_profiles.gd")
var manifest_path := "res://assets/character/manifest.json"
var collision_path := "res://assets/character/collision_profile.json"
var game
var last_manifest_text := ""
var last_collision_text := ""

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 last_manifest_text=FileAccess.get_file_as_string(manifest_path)
 last_collision_text=FileAccess.get_file_as_string(collision_path)
 var timer:=Timer.new();timer.wait_time=.5;timer.timeout.connect(poll);add_child(timer);timer.start()

func poll() -> void:
 var text:=FileAccess.get_file_as_string(manifest_path)
 if text!=last_manifest_text:
  var data=JSON.parse_string(text)
  if data is Dictionary and data.has("proportion_warp_by_direction"):
   last_manifest_text=text
   game.character_manifest.proportion_warp_by_direction=data.proportion_warp_by_direction
   game._update_character_material()
   var companion=game.dialogue_controller.companion if game.dialogue_controller else null
   if is_instance_valid(companion):
    for sprite in companion.find_children("*","Sprite3D",true,false):
     Proportions.apply(sprite.material_override,"down",game.character_manifest)
   print("CHARACTER PROPORTIONS RELOADED: saved editor parameters applied to running game")
 text=FileAccess.get_file_as_string(collision_path)
 if text!=last_collision_text:
  var data=JSON.parse_string(text)
  if data is Dictionary and data.has("bands"):
   last_collision_text=text
   game.CollisionSafety.update_guards(game.player,data)
   game.CollisionSafety.update_guards(game.silhouette_body,data)
   var companion=game.dialogue_controller.companion if game.dialogue_controller else null
   if is_instance_valid(companion):game.CollisionSafety.update_guards(companion.get_node("GuideBody"),data)
