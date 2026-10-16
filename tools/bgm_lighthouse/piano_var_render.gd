extends SceneTree
## 渲染《灯塔变奏》五首 —— 为 gal_piano 的五首原创钢琴各做的一套钢琴变奏。
##
## 五首共用一套合成器与一份音色缓存，逐首渲染、逐首按 SECTIONS 打分段动态
## （我听不到声音，靠这张表判断每首的力度层级是否按设计走）。
## 输出：res://assets/music/lighthouse/lighthouse_<曲子>_var.wav
##
##   & "$env:USERPROFILE\Godot\Godot_v4.7.2-stable_win64_console.exe" `
##     --headless --audio-driver Dummy --path "D:\迅雷下载\大肥鱼_数值战斗怪物_v22" `
##     --script res://tools/bgm_lighthouse/piano_var_render.gd

const Scores := preload("res://tools/bgm_lighthouse/piano_var_scores.gd")
const Synth := preload("res://tools/gal_piano/piano_synth.gd")
const OUT_DIR := "res://assets/music/lighthouse"


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	call_deferred("_render")


func _render() -> void:
	var synth := Synth.new()
	var tracks: Array = []
	for r: Dictionary in Scores.RECIPES:
		var score: Dictionary = Scores.build(r)
		var roles := {}
		for n: Dictionary in score.notes:
			roles[n.role] = int(roles.get(n.role, 0)) + 1
		print("SCORE %-28s %d 小节  %.1f 秒  音符 %d（%s）" % [
			score.title, score.bar_count, score.duration, score.notes.size(),
			", ".join(roles.keys().map(func(k): return "%s %d" % [k, roles[k]])),
		])
		var wav: AudioStreamWAV = synth.render(score)
		var file := "%s/%s.wav" % [OUT_DIR, String(score.id)]
		var error := wav.save_to_wav(file)
		if error != OK:
			push_error("PIANO_VAR_SAVE_FAILED " + file + " " + str(error))
			quit(1)
			return
		for s in _sections(wav, score):
			print("SECTION %-28s %-14s %8.1f %8.1f %9.2f %9.2f" % [
				score.id, s.name, s.start, s.length, s.rms, s.peak,
			])
		var report := synth.last_report.duplicate()
		for key in ["id", "use", "key", "bpm", "bar_count"]:
			report[key] = score[key]
		report.file = file
		report.sections = _sections(wav, score)
		tracks.append(report)
		print("PIANO_VAR_SAVED ", JSON.stringify(report))
	var mf := FileAccess.open("%s/lighthouse_var_manifest.json" % OUT_DIR, FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify({"engine": Engine.get_version_info().string,
			"generated_by": "tools/bgm_lighthouse/piano_var_render.gd",
			"source": "主题、发展部与和声骨架逐音取自 tools/gal_piano 的六首原创钢琴；编曲为「主题 + 四变奏 + 尾声」",
			"tracks": tracks}, "  "))
		mf.close()
	print("PIANO_VAR_COMPLETE ", tracks.size(), " tracks")
	quit(0)


## 按 SECTIONS 分段统计刚渲出来的 PCM。注意 sections 里是小节号，必须走 score.bars 换算时间。
func _sections(wav: AudioStreamWAV, score: Dictionary) -> Array:
	var pcm: PackedByteArray = wav.data
	var rate := float(wav.mix_rate)
	var frames := pcm.size() / 4
	var bars: Array = score.bars
	var out: Array = []
	for sec: Dictionary in score.sections:
		var begin_bar := maxi(0, int(sec.start))
		var end_bar := mini(bars.size(), int(sec.end))
		if end_bar <= begin_bar:
			continue
		var from := maxi(0, int(float(bars[begin_bar].time) * rate))
		var to := mini(frames, int((float(bars[end_bar - 1].time) + float(bars[end_bar - 1].duration)) * rate))
		var sumsq := 0.0
		var peak := 0.0
		var n := 0
		for i in range(from, to):
			var l := float(pcm.decode_s16(i * 4)) / 32767.0
			var r := float(pcm.decode_s16(i * 4 + 2)) / 32767.0
			var m := (l + r) * 0.5
			sumsq += m * m
			peak = maxf(peak, absf(m))
			n += 1
		out.append({
			"name": sec.name,
			"start": float(from) / rate,
			"length": float(n) / rate,
			"rms": linear_to_db(maxf(sqrt(sumsq / float(maxi(1, n))), 1e-9)),
			"peak": linear_to_db(maxf(peak, 1e-9)),
		})
	return out
