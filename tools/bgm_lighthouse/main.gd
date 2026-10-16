extends SceneTree
## 《灯塔，音乐盒变奏》渲染入口 —— 复用《玻璃温室》的混音与母带链路
## （同一套钢琴 / 音乐盒 / 弦乐垫音源，同一套尾巴折回无缝循环与软限幅归一化）。
##
## 用法：
##   ... --script res://tools/bgm_lighthouse/main.gd -- --quality final
## 选项：
##   --list                 只打印乐谱统计，不渲染
##   --quality draft|final  草稿（少分音、无双弦）或成品
##   --out res://...        输出目录，默认 res://assets/music/lighthouse

const Scores := preload("res://tools/bgm_lighthouse/scores.gd")
const Render := preload("res://tools/bgm_glasshouse/render.gd")
const Theory := preload("res://tools/bgm_glasshouse/theory.gd")
const Piano := preload("res://tools/bgm_glasshouse/piano.gd")
const Pad := preload("res://tools/bgm_glasshouse/pad.gd")

const OUT_DEFAULT := "res://assets/music/lighthouse"

const QUALITY := {
	"draft": {
		"partials_max": 10, "unison": 1, "wet": 0.72, "tail_sec": 3.0,
		"noise_floor_db": -220.0, "room": 0.84, "damp": 0.32, "predelay_ms": 40.0,
	},
	"final": {
		"partials_max": 24, "unison": 2, "wet": 0.72, "tail_sec": 3.5,
		"noise_floor_db": -72.0, "room": 0.84, "damp": 0.30, "predelay_ms": 42.0,
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

	var score: Dictionary = Scores.new().build()
	var bpm := float(score["bpm"])
	var bars := int(score["bars"])
	var bpb := Theory.beats_per_bar(String(score["time_sig"]))
	var sec := float(bars * bpb) * 60.0 / bpm

	if opts.has("list"):
		var counts := {}
		for e in score["events"]:
			var layer := String(e["layer"])
			counts[layer] = int(counts.get(layer, 0)) + 1
		print("── 《灯塔，音乐盒变奏》 ──")
		print("%s  %s  %.1f BPM  %d 小节  %.1f 秒  事件 %d（钢琴 %d / 音乐盒 %d / 垫 %d）" % [
			String(score["key"]), String(score["title"]), bpm, bars, sec,
			score["events"].size(),
			int(counts.get("piano", 0)), int(counts.get("mb", 0)), int(counts.get("pad", 0)),
		])
		quit(0)
		return

	var out_dir := String(opts.get("out", OUT_DEFAULT)).trim_suffix("/")
	print("── 《灯塔，音乐盒变奏》渲染 ── 音质=%s  输出=%s" % [quality, out_dir])
	var t_all := Time.get_ticks_msec()
	var r := Render.render_track(score, ropts)
	var t1 := Time.get_ticks_msec()
	var path := "%s/%s.wav" % [out_dir, String(score["key"])]
	var err := Render.write_wav(path, r["left"], r["right"])
	var sm := Render.seam_metrics(r["left"])
	var t2 := Time.get_ticks_msec()
	var size_mb := 0.0
	if FileAccess.file_exists(path):
		size_mb = float(FileAccess.get_file_as_bytes(path).size()) / 1048576.0
	print("  %-24s %6.1f 秒  %5.1f MB  渲染 %5.0f ms  写盘 %4.0f ms  接缝 %3d%%×曲内最大跃变  缓存 %d  %s" % [
		String(score["key"]), float(r["loop_sec"]), size_mb,
		float(t1 - t_all), float(t2 - t1),
		int(round(float(sm["ratio"]) * 100.0)),
		Piano.cache_size() + Pad.cache_size(),
		"OK" if err == OK else ("失败 err=%d" % err),
	])
	print("总计 %.1f 秒" % (float(Time.get_ticks_msec() - t_all) / 1000.0))

	var mf := FileAccess.open("%s/lighthouse_manifest.json" % out_dir, FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify({
			"engine": Engine.get_version_info().string,
			"generated_by": "tools/bgm_lighthouse",
			"quality": quality,
			"options": ropts,
			"source": "主题与和声取自 tools/gal_piano 的 gal_piano_night（D# 小调），编曲重写为音乐盒 + 弦乐垫",
			"tracks": [{
				"key": score["key"], "title": score["title"], "bpm": score["bpm"],
				"time_sig": score["time_sig"], "bars": bars, "seed": score["seed"],
				"loop_sec": snappedf(float(r["loop_sec"]), 0.001),
				"loop_frames": r["loop_frames"],
				"format": "pcm_s16le / 44100 Hz / 2ch",
				"target_peak_dbfs": -1.5,
				"seam_ratio": snappedf(float(sm["ratio"]), 0.0001),
				"events": score["events"].size(),
				"file": "%s.wav" % String(score["key"]),
			}],
		}, "  "))
		mf.close()
		print("清单已写出: %s/lighthouse_manifest.json" % out_dir)

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
