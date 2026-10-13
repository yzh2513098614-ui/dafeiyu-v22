extends SceneTree
const Synth = preload("res://tools/gal_piano/piano_synth.gd")

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("_render")

func _render() -> void:
	var scores: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/gal_piano/batch_scores.json"))
	var synth := Synth.new()
	var preview: Dictionary = scores[0].duplicate(true)
	preview.title = str(preview.title) + " · 40 秒试听"
	preview.duration = 40.0
	preview.notes = preview.notes.filter(func(n: Dictionary) -> bool: return float(n.time) < 39.0)
	var wav: AudioStreamWAV = synth.render(preview)
	var error := wav.save_to_wav("res://预览/原创钢琴BGM_20261014/海风课间_40秒试听.wav")
	if error != OK:
		push_error("PIANO_PREVIEW_SAVE_FAILED " + str(error))
		quit(1)
		return
	print("PIANO_PREVIEW_READY 海风课间_40秒试听.wav")
	synth.prepare(scores)
	var reports: Array = []
	for score: Dictionary in scores:
		print("PIANO_BATCH_START ", score.id, " ", score.title)
		wav = synth.render(score)
		var file := "res://assets/music/" + str(score.id) + ".wav"
		error = wav.save_to_wav(file)
		if error != OK:
			push_error("PIANO_BATCH_SAVE_FAILED " + file + " " + str(error))
			quit(1)
			return
		var report := synth.last_report.duplicate()
		for key in ["id", "use", "key", "bpm", "bar_count"]:
			report[key] = score[key]
		report.file = file
		reports.append(report)
		print("PIANO_BATCH_SAVED ", JSON.stringify(report))
	var manifest := FileAccess.open("res://assets/music/gal_piano_batch_manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"engine": Engine.get_version_info().string,
		"reference_analysis": "flower MIDI structure; newly composed themes; solo piano",
		"tracks": reports}, "\t") + "\n")
	print("PIANO_BATCH_COMPLETE ", reports.size(), " tracks")
	quit(0)
