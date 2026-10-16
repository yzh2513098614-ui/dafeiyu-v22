extends SceneTree
## 全项目 BGM 的钢琴改编渲染入口。
##
## 目前覆盖「事件式乐谱」的两条产线（共 18 首）：
##   《玻璃温室》六首 + 《玻璃温室·变奏集》六首（tools/bgm_glasshouse/scores.gd）
##   《鲸落电台》六首（tools/bgm_whalefm/scores.gd）
## 另两条（`chip_tune` 的芯片音乐、`music_synth*.gd` 的老合成曲）数据结构不同，
## 待各自的适配器写好后再并入同一条管线。
##
##   & "$env:USERPROFILE\Godot\Godot_v4.7.2-stable_win64_console.exe" `
##     --headless --audio-driver Dummy --path "D:\迅雷下载\大肥鱼_数值战斗怪物_v22" `
##     --script res://tools/bgm_piano/render.gd

const Transcribe := preload("res://tools/bgm_piano/transcribe.gd")
const Synth := preload("res://tools/gal_piano/piano_synth.gd")
const OUT_DIR := "res://assets/music/piano_edition"

## 各源曲目的场合归属（照原风格组的映射，钢琴版接进同一个场合轮换）。
const MOODS := {
	"glasshouse_01_prologue": ["title"], "glasshouse_02_meeting": ["day"],
	"glasshouse_03_longing": ["indoor"], "glasshouse_04_rain": ["night"],
	"glasshouse_05_confession": ["battle"], "glasshouse_06_farewell": ["hope"],
	"glasshouse_var_01_intro": ["title"], "glasshouse_var_02_reunion": ["day"],
	"glasshouse_var_03_steps": ["indoor"], "glasshouse_var_04_moon": ["night"],
	"glasshouse_var_05_spin": ["battle"], "glasshouse_var_06_final": ["hope"],
	"wf_01_fm885": ["title"], "wf_02_breakwater": ["day"],
	"wf_03_konbini": ["indoor"], "wf_04_nightlight": ["night"],
	"wf_05_container": ["battle"], "wf_06_ebbtide": ["hope"],
}


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	call_deferred("_render")


func _render() -> void:
	var dir := ProjectSettings.globalize_path(OUT_DIR)
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var sources: Array = []
	sources.append_array(Transcribe.glasshouse_family(MOODS))
	sources.append_array(Transcribe.whalefm_family(MOODS))
	var synth := Synth.new()
	var tracks: Array = []
	for src: Dictionary in sources:
		var score: Dictionary = Transcribe.to_piano(src)
		var wav: AudioStreamWAV = synth.render(score)
		var file := "%s/%s.wav" % [OUT_DIR, String(score.id)]
		var error := wav.save_to_wav(file)
		if error != OK:
			push_error("PIANO_EDITION_SAVE_FAILED " + file + " " + str(error))
			quit(1)
			return
		var report := synth.last_report.duplicate()
		report["source"] = src["id"]
		report["moods"] = src["moods"]
		report["file"] = file
		tracks.append(report)
		print("PIANO_EDITION %-34s 源 %-24s %6.1f 秒  音符 %4d  RMS %.2f dB  峰值 %.2f dB  %s" % [
			String(score.id), String(src["id"]), float(score["duration"]),
			score.notes.size(), float(report["rms_dbfs"]), float(report["peak_dbfs"]),
			str(src["moods"]),
		])
	var mf := FileAccess.open("%s/piano_edition_manifest.json" % OUT_DIR, FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify({
			"engine": Engine.get_version_info().string,
			"generated_by": "tools/bgm_piano/render.gd",
			"rule": "源乐谱按音区分成 melody/bass/chord/ornament，弦乐垫长音改成每拍触键的钢琴和弦，鼓组整层丢掉",
			"tracks": tracks,
		}, "  "))
		mf.close()
	print("PIANO_EDITION_COMPLETE ", tracks.size(), " tracks")
	quit(0)
