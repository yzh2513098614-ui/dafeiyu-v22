extends "res://district/continuous_world.gd"
## F6 entry scene for this map; F5 continues to use the normal game title.
func _ready() -> void:
	HarborPrefs.continue_game=false;HarborPrefs.starting_place="whale_home"
	super._ready()
