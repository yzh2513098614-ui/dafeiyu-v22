extends SceneTree
## Regenerate the game's original piano WAV entirely inside Godot.
const Score = preload("res://tools/gal_piano/score.gd")
const Synth = preload("res://tools/gal_piano/piano_synth.gd")
const OUTPUT := "res://assets/music/gal_after_school.wav"

func _initialize() -> void:
	call_deferred("_generate")

func _generate() -> void:
	# Keep synthesis runs quiet; this does not change saved audio settings.
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	var score: Dictionary = Score.build()
	var synth := Synth.new()
	var wav: AudioStreamWAV = synth.render(score)
	var error := wav.save_to_wav(OUTPUT)
	if error != OK:
		push_error("PIANO_SAVE_FAILED " + str(error))
		quit(1)
		return
	print("PIANO_SAVED ", OUTPUT, " ", JSON.stringify(synth.last_report))
	quit(0)
