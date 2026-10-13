extends SceneTree
## 《玻璃温室》批量渲染入口 —— 完全离线，不需要音频设备。
##
## 用法（Windows，注意 -- 之后才是本脚本自己的参数）：
##   "C:\Users\Administrator\Godot\Godot_v4.7.2-stable_win64_console.exe" ^
##     --headless --audio-driver Dummy ^
##     --path "D:\迅雷下载\大肥鱼_数值战斗怪物_v22" ^
##     --script res://tools/bgm_glasshouse/main.gd -- --quality final
##
## 选项：
##   --list                 只列出曲目与预计时长，不渲染
##   --tracks 1,3,5         只渲染指定曲目（从 1 开始计）
##   --quality draft|final  草稿（少分音、无双弦、无底噪）/ 成品
##   --out res://...        输出目录，默认 res://assets/music/glasshouse

const Scores := preload("res://tools/bgm_glasshouse/scores.gd")
const Render := preload("res://tools/bgm_glasshouse/render.gd")
const Theory := preload("res://tools/bgm_glasshouse/theory.gd")
const Piano := preload("res://tools/bgm_glasshouse/piano.gd")
const Pad := preload("res://tools/bgm_glasshouse/pad.gd")

const OUT_DEFAULT := "res://assets/music/glasshouse"

const QUALITY := {
	"draft": {
		"partials_max": 10, "unison": 1, "wet": 0.70, "tail_sec": 3.0,
		"noise_floor_db": -220.0, "room": 0.84, "damp": 0.32, "predelay_ms": 42.0,
	},
	"final": {
		"partials_max": 24, "unison": 2, "wet": 0.85, "tail_sec": 4.0,
		"noise_floor_db": -72.0, "room": 0.86, "damp": 0.28, "predelay_ms": 46.0,
	},
}


func _initialize() -> void:
	var opts := _parse(OS.get_cmdline_user_args())
	var quality := String(opts.get("quality", "final"))
	if not QUALITY.has(quality):
		push_error("未知音质档位: " + quality)
		quit(1)
		return
	var ropts: Dictionary = QUALITY[quality].duplicate()
	ropts["target_peak_db"] = -1.5

	var all: Array = Scores.new().build_all()

	if opts.has("list"):
		print("── 《玻璃温室》曲目表 ──")
		for i in all.size():
			var s: Dictionary = all[i]
			var beats := float(int(s["bars"]) * Theory.beats_per_bar(String(s["time_sig"])))
			var sec := Theory.beats_sec(beats, float(s["bpm"]))
			var n_piano := 0
			var n_pad := 0
			var n_mb := 0
			for e in s["events"]:
				match String(e["layer"]):
					"pad":
						n_pad += 1
					"mb":
						n_mb += 1
					_:
						n_piano += 1
			print("%d. %-34s %-4s %5.1f BPM %-4s %2d 小节  %6.1f 秒  事件 %4d（钢琴 %d / 垫 %d / 盒 %d）" % [
				i + 1, String(s["key"]), String(s["title"]), float(s["bpm"]),
				String(s["time_sig"]), int(s["bars"]), sec,
				s["events"].size(), n_piano, n_pad, n_mb,
			])
		quit(0)
		return

	var want := _parse_tracks(opts.get("tracks", ""), all.size())
	var out_dir := String(opts.get("out", OUT_DEFAULT)).trim_suffix("/")

	print("── 《玻璃温室》渲染 ── 音质=%s  输出=%s  曲目数=%d" % [quality, out_dir, want.size()])
	var t_all := Time.get_ticks_msec()
	var manifest: Array = []
	var done := 0
	for idx in want:
		var s: Dictionary = all[idx]
		var t0 := Time.get_ticks_msec()
		var r := Render.render_track(s, ropts)
		var t1 := Time.get_ticks_msec()
		var path := "%s/%s.wav" % [out_dir, String(s["key"])]
		var err := Render.write_wav(path, r["left"], r["right"])
		var sm := Render.seam_metrics(r["left"])
		var t2 := Time.get_ticks_msec()
		var size_mb := 0.0
		if FileAccess.file_exists(path):
			size_mb = float(FileAccess.get_file_as_bytes(path).size()) / 1048576.0
		done += 1
		var verdict := "OK" if err == OK else ("失败 err=%d" % err)
		print("  [%d/%d] %-34s %6.1f 秒  %5.1f MB  渲染 %5.0f ms  写盘 %4.0f ms  接缝 %3d%%×曲内最大跃变  缓存 %d  %s" % [
			done, want.size(), String(s["key"]), float(r["loop_sec"]),
			size_mb, float(t1 - t0), float(t2 - t1),
			int(round(float(sm["ratio"]) * 100.0)),
			Piano.cache_size() + Pad.cache_size(), verdict,
		])
		manifest.append({
			"key": s["key"], "title": s["title"], "bpm": s["bpm"],
			"time_sig": s["time_sig"], "bars": s["bars"], "seed": s["seed"],
			"loop_sec": snappedf(float(r["loop_sec"]), 0.001),
			"loop_frames": r["loop_frames"],
			"format": "pcm_s16le / 44100 Hz / 2ch",
			"target_peak_dbfs": -1.5,
			"seam_ratio": snappedf(float(sm["ratio"]), 0.0001),
			"seam_wrap_step": snappedf(float(sm["wrap"]), 0.000001),
			"seam_max_inner_step": snappedf(float(sm["max"]), 0.000001),
			"events": s["events"].size(),
			"file": "%s.wav" % s["key"],
		})
	print("总计 %.1f 秒" % (float(Time.get_ticks_msec() - t_all) / 1000.0))

	var mf := FileAccess.open("%s/glasshouse_manifest.json" % out_dir, FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify({
			"engine": Engine.get_version_info().string,
			"generated_by": "tools/bgm_glasshouse",
			"quality": quality,
			"options": ropts,
			"tracks": manifest,
		}, "  "))
		mf.close()
		print("清单已写出: %s/glasshouse_manifest.json" % out_dir)

	quit(0)


func _parse(argv: PackedStringArray) -> Dictionary:
	var out := {}
	var i := 0
	while i < argv.size():
		var a := String(argv[i])
		if a.begins_with("--"):
			var key := a.substr(2)
			if i + 1 < argv.size() and not String(argv[i + 1]).begins_with("--"):
				out[key] = String(argv[i + 1])
				i += 2
			else:
				out[key] = true
				i += 1
		else:
			i += 1
	return out


func _parse_tracks(spec: Variant, total: int) -> Array:
	var out: Array = []
	if spec is String and String(spec) != "":
		for part in String(spec).split(","):
			var p := part.strip_edges()
			if p.is_valid_int():
				var n := int(p) - 1
				if n >= 0 and n < total and not out.has(n):
					out.append(n)
		return out
	for i in total:
		out.append(i)
	return out
