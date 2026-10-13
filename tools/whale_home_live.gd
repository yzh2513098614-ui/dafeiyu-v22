extends Node
## Silent MCP entry. Test saves never touch the player's normal journey.
func _ready() -> void:
	AudioServer.set_bus_mute(0,true)
	HarborPrefs.values.music=false;HarborPrefs.values.sfx=false;HarborPrefs.values.ambience=false
	HarborPrefs.values.fullscreen=false;HarborPrefs.values.follow=true;HarborPrefs.values.day_cycle=false
	HarborPrefs.continue_game=false;HarborPrefs.starting_place="whale_home"
	HarborPrefs.world_save_path="res://预览/大肥鱼之家_20261013/live_world.json"
	HarborPrefs.settings_path="res://预览/大肥鱼之家_20261013/live_settings.cfg"
	call_deferred("_enter")

func _enter() -> void:
	var game=load("res://district/continuous_world.tscn").instantiate()
	get_tree().root.add_child(game);get_tree().current_scene=game
	game.life_booted=false;game.loot.save_path="res://预览/大肥鱼之家_20261013/live_inventory.json"
	game.dialogue_controller.save_path="res://预览/大肥鱼之家_20261013/live_dialogue.json"
	game.dialogue_controller.state.seen["welcome"]=true
	game.atmosphere.set_time(12.0)
	queue_free()
