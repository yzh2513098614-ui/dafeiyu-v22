extends SceneTree
## 渲染《灯塔替我记得 · 钢琴变奏》为 res://assets/music/lighthouse/lighthouse_piano_var.wav。
##
## 与 gal_piano 的单曲渲染（render_goodnight.gd）同一套做法，额外做一件事：
## 渲完立刻按 SECTIONS 分段统计 RMS 与峰值 —— 我听不到声音，就靠这张表判断
## 每一次迭代到底改好了没有（对比同一段在两次渲染里的力度层级）。
##
##   & "$env:USERPROFILE\Godot\Godot_v4.7.2-stable_win64_console.exe" `
##     --headless --audio-driver Dummy --path "D:\迅雷下载\大肥鱼_数值战斗怪物_v22" `
##     --script res://tools/bgm_lighthouse/piano_render.gd

const Score := preload("res://tools/bgm_lighthouse/piano_scores.gd")
const Synth := preload("res://tools/gal_piano/piano_synth.gd")
const OUTPUT := "res://assets/music/lighthouse/lighthouse_piano_var.wav"
const MANIFEST := "res://assets/music/lighthouse/lighthouse_piano_manifest.json"


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	call_deferred("_render")


func _render() -> void:
	var score: Dictionary = Score.build()
	var roles := {}
	for n: Dictionary in score.notes:
		roles[n.role] = int(roles.get(n.role, 0)) + 1
	print("SCORE %s  %d 小节  %.1f 秒  音符 %d（%s）" % [
		score.title, score.bar_count, score.duration, score.notes.size(),
		", ".join(roles.keys().map(func(k): return "%s %d" % [k, roles[k]])),
	])
	var synth := Synth.new()
	var wav: AudioStreamWAV = synth.render(score)
	var sections: Array = _sections(wav, score)
	print("SECTION %-16s %8s %8s %9s %9s" % ["段", "起点s", "时长s", "RMS dB", "峰值 dB"])
	for s in sections:
		print("SECTION %-16s %8.1f %8.1f %9.2f %9.2f" % [
			s.name, s.start, s.length, s.rms, s.peak,
		])
	var error := wav.save_to_wav(OUTPUT)
	if error != OK:
		push_error("PIANO_SAVE_FAILED " + str(error))
		quit(1)
		return
	print("PIANO_SAVED ", OUTPUT, " ", JSON.stringify(synth.last_report))
	var mf := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify({
			"engine": Engine.get_version_info().string,
			"generated_by": "tools/bgm_lighthouse/piano_render.gd",
			"source": "主题与发展部取自 tools/gal_piano 的 gal_piano_night（D# 小调），编曲为钢琴变奏（主题 + 四变奏 + 尾声）",
			"track": synth.last_report,
			"output": OUTPUT,
			"sections": sections.map(func(s): return {
				"name": s.name, "start_sec": s.start, "length_sec": s.length,
				"rms_db": s.rms, "peak_db": s.peak,
			}),
		}, "  "))
		mf.close()
	quit(0)


## 按 SECTIONS 分段统计 PCM 的 RMS 与峰值（读的是刚渲出来的 PCM 本身）。
## 注意 sections 里的 start / end 是**小节号**，不是秒 —— 必须走 score.bars 换算成时间，
## 否则量出来的是从曲首数起的第 N 秒。迭代 1–3 就是这么量的：窗口全错位，
## 「尾声比高潮还响」是量错造成的假象。
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
