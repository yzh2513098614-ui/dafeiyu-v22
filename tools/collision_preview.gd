extends Node
## Isolated, renderable verification scene; never writes the player's save files.
func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	HarborPrefs.continue_game=false;HarborPrefs.starting_place="city"
	HarborPrefs.values.fullscreen=false;HarborPrefs.world_save_path="res://预览/穿模修复_preview_world.json"
	var game=load("res://district/continuous_world.tscn").instantiate()
	get_tree().root.add_child(game);get_tree().current_scene=game
	game.loot.save_path="res://预览/穿模修复_preview_loot.json"
	game.dialogue_controller.save_path="res://预览/穿模修复_preview_dialogue.json"
	game.expedition_controller.state.save_path="res://预览/穿模修复_preview_expedition.json"
	game.autosave_clock=-3600.0
	game.set_physics_process(false)
	if game.dialogue_controller.active:game.dialogue_controller.close()
	queue_free()
