extends SceneTree
## 《像素掌机》六首芯片音乐的离线渲染入口：
## 读 chip_scores.json，用 chip_synth.gd 逐首合成 44.1kHz/16bit/立体声 PCM，
## 写入 assets/music/chip/<id>.wav 与 chip_manifest.json（含接缝连续性报告）。
##
##   godot --headless --audio-driver Dummy --path . --script res://tools/chip_tune/render_chip.gd
##
## 会覆盖同名成品，重渲前先确认要保留旧版。

const Synth = preload("res://tools/chip_tune/chip_synth.gd")

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("_render")

func _render() -> void:
	var scores: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tools/chip_tune/chip_scores.json"))
	if not (scores is Array) or scores.is_empty():
		push_error("CHIP_SCORES_EMPTY")
		quit(1)
		return
	var dir_error := DirAccess.make_dir_recursive_absolute("res://assets/music/chip")
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("CHIP_DIR_FAILED " + str(dir_error))
		quit(1)
		return
	var synth := Synth.new()
	var reports: Array = []
	for score: Dictionary in scores:
		print("CHIP_RENDER_START ", score.id, " ", score.title)
		var wav: AudioStreamWAV = synth.render(score)
		var file := "res://assets/music/chip/" + str(score.id) + ".wav"
		var error := wav.save_to_wav(file)
		if error != OK:
			push_error("CHIP_SAVE_FAILED " + file + " " + str(error))
			quit(1)
			return
		var report: Dictionary = synth.last_report.duplicate()
		for key in ["id", "use", "key", "bpm", "bar_count"]:
			report[key] = score[key]
		report.file = file
		reports.append(report)
		print("CHIP_RENDER_SAVED ", JSON.stringify(report))
	var manifest := FileAccess.open("res://assets/music/chip/chip_manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"engine": Engine.get_version_info().string,
		"synth": "PolyBLEP pulse x2 + triangle bass + LFSR drums; wrap-around mixdown, seamless loop",
		"tracks": reports}, "\t") + "\n")
	print("CHIP_BATCH_COMPLETE ", reports.size(), " tracks")
	quit(0)
