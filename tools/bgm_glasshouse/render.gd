extends RefCounted
## 《玻璃温室》混音与母带。
##
## 顺序：分轨混音 → 音板共鸣 EQ → 大厅混响 → 底噪 → **尾巴折回开头** → 软限幅 → 归一化 → 16-bit PCM。
##
## 两个关键设计：
## 1. 音板共鸣与磁带高频缓降放在混音之后做一次 —— 它们是线性时不变处理，
##    与求和可交换（∑f(xᵢ) = f(∑xᵢ)），所以与逐音做数学等价，
##    但代价从「每个音一次」降到「每首一次」。
## 2. 尾巴折回开头：把 [循环长度, 循环长度+尾巴] 的内容**加**回开头，
##    于是首尾天然咬合。整段循环播放不会有接缝，也不需要交叉淡化。

const SR := 44100

const Theory := preload("res://tools/bgm_glasshouse/theory.gd")
const Dsp := preload("res://tools/bgm_glasshouse/dsp.gd")
const Piano := preload("res://tools/bgm_glasshouse/piano.gd")
const MusicBox := preload("res://tools/bgm_glasshouse/musicbox.gd")
const Pad := preload("res://tools/bgm_glasshouse/pad.gd")

## 各层的整体配比。弦乐垫压在钢琴下方约 −16 dB。
const LAYER_GAIN := {"piano": 1.0, "mb": 0.50, "pad": 0.16}


static func render_track(score: Dictionary, opts: Dictionary) -> Dictionary:
	var sr := float(SR)
	var bpm := float(score["bpm"])
	var bpb := Theory.beats_per_bar(String(score["time_sig"]))
	var bars := int(score["bars"])
	var beat_sec := 60.0 / bpm
	var loop_sec := float(bars * bpb) * beat_sec
	var loop_frames := int(round(loop_sec * sr))
	var tail_sec := float(opts.get("tail_sec", 4.0))
	var tail_frames := int(round(tail_sec * sr))
	var total := loop_frames + tail_frames

	# 音质档位只影响分音数与双弦数；缓存键带上档位，避免草稿与成品互相污染
	var preset := Piano.PIANO.duplicate()
	preset["partials_max"] = int(opts.get("partials_max", 24))
	preset["unison"] = int(opts.get("unison", 2))
	var ptag := "piano%d_%d" % [int(preset["partials_max"]), int(preset["unison"])]

	var dry_l := PackedFloat32Array()
	var dry_r := PackedFloat32Array()
	dry_l.resize(total)
	dry_r.resize(total)

	var rel_frames := int(round(Pad.RELEASE_SEC * sr))
	var swell_dph := TAU * float(opts.get("pad_swell_hz", 0.08)) / sr
	var swell_depth := float(opts.get("pad_swell_depth", 0.10))

	for e in score["events"]:
		var layer := String(e["layer"])
		var lg := float(LAYER_GAIN.get(layer, 1.0))
		var start := int(round(Theory.beats_sec(float(e["t"]), bpm) * sr))
		if start >= total:
			continue
		var dur_sec := Theory.beats_sec(float(e["d"]), bpm)
		var m := int(e["m"])
		var v := float(e["v"])
		var pg := Dsp.pan_gains(float(e["pan"]))
		var gl: float = pg[0] * lg
		var gr: float = pg[1] * lg

		if layer == "pad":
			var td := Pad.tone(m, v)
			var atk: PackedFloat32Array = td["attack"]
			var lp: PackedFloat32Array = td["loop"]
			var alen := atk.size()
			var llen := lp.size()
			if alen <= 0 or llen <= 0:
				continue
			var nlen := int(round(dur_sec * sr))
			var blen := nlen + rel_frames
			var i := 0
			var src := 0
			var ph := 0.0
			while i < blen:
				var idx := start + i
				if idx >= total:
					break
				var s := 0.0
				if i < alen:
					s = atk[i]
				else:
					s = lp[src]
					src += 1
					if src >= llen:
						src = 0
				if i >= nlen:
					var u := 1.0 - float(i - nlen) / float(maxi(1, rel_frames))
					s *= u * u
				s *= 1.0 + swell_depth * sin(ph)
				ph += swell_dph
				dry_l[idx] += s * gl
				dry_r[idx] += s * gr
				i += 1
		else:
			var buf: PackedFloat32Array
			if layer == "mb":
				buf = MusicBox.render(m, v, dur_sec)
			else:
				buf = Piano.render(ptag, preset, m, v, dur_sec)
			var bl := buf.size()
			var i := 0
			while i < bl:
				var idx := start + i
				if idx >= total:
					break
				var s := buf[i]
				dry_l[idx] += s * gl
				dry_r[idx] += s * gr
				i += 1

	# --- 音板共鸣 + 磁带高频缓降（混音后一次） ---
	dry_l = Dsp.soundboard_eq(dry_l, sr)
	dry_r = Dsp.soundboard_eq(dry_r, sr)

	# --- 大厅混响：单声道送出。工程没有 bus layout，混响必须烘进 wav ---
	var mono := PackedFloat32Array()
	mono.resize(total)
	for i in total:
		mono[i] = (dry_l[i] + dry_r[i]) * 0.5
	var pd := Dsp.predelay(mono, sr, float(opts.get("predelay_ms", 42.0)))
	var wet_pair := Dsp.freeverb_stereo(pd, sr, float(opts.get("room", 0.86)), float(opts.get("damp", 0.28)))
	var wet_l: PackedFloat32Array = wet_pair[0]
	var wet_r: PackedFloat32Array = wet_pair[1]
	var wet_gain := float(opts.get("wet", 0.85))

	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(total)
	out_r.resize(total)
	for i in total:
		out_l[i] = dry_l[i] + wet_l[i] * wet_gain
		out_r[i] = dry_r[i] + wet_r[i] * wet_gain

	# --- 极低电平房间底噪 ---
	var nf_db := float(opts.get("noise_floor_db", -72.0))
	if nf_db > -200.0:
		var amp := pow(10.0, nf_db / 20.0)
		var nz := Dsp.rng(int(score["seed"]) + 77)
		var nl := Dsp.noise_floor(total, nz, amp)
		var nr := Dsp.noise_floor(total, nz, amp)
		for i in total:
			out_l[i] += nl[i]
			out_r[i] += nr[i]

	# --- 尾巴折回开头：这一步之后首尾天然咬合 ---
	for i in tail_frames:
		out_l[i] += out_l[loop_frames + i]
		out_r[i] += out_r[loop_frames + i]
	var fin_l := out_l.slice(0, loop_frames)
	var fin_r := out_r.slice(0, loop_frames)

	# --- 母带：软限幅 → 归一化到目标真峰 ---
	var target := pow(10.0, float(opts.get("target_peak_db", -1.5)) / 20.0)
	var ceiling := pow(10.0, -0.5 / 20.0)
	fin_l = Dsp.soft_clip(fin_l, ceiling)
	fin_r = Dsp.soft_clip(fin_r, ceiling)
	var pk := maxf(Dsp.peak(fin_l), Dsp.peak(fin_r))
	var gain := 1.0 if pk <= 0.0 else target / pk
	fin_l = Dsp.scale(fin_l, gain)
	fin_r = Dsp.scale(fin_r, gain)

	return {
		"left": fin_l, "right": fin_r, "loop_frames": loop_frames,
		"loop_sec": loop_sec, "peak": target, "gain_applied": gain,
	}


## 写 16-bit 立体声 PCM wav。加 1 LSB 的 TPDF 抖动，避免量化噪声与信号相关。
static func write_wav(path: String, left: PackedFloat32Array, right: PackedFloat32Array) -> Error:
	var n := left.size()
	if n != right.size():
		push_error("左右声道长度不一致")
		return ERR_INVALID_DATA
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	var dither := 1.0 / 32768.0
	var rz := Dsp.rng(20261014)
	for i in n:
		var dl := (left[i] + rz.randf_range(-1.0, 1.0) * dither) * 32767.0
		var dr := (right[i] + rz.randf_range(-1.0, 1.0) * dither) * 32767.0
		bytes.encode_s16(i * 4, clampi(int(round(dl)), -32768, 32767))
		bytes.encode_s16(i * 4 + 2, clampi(int(round(dr)), -32768, 32767))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SR
	wav.stereo = true
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n

	var dir := path.get_base_dir()
	if dir != "":
		var gdir := ProjectSettings.globalize_path(dir)
		if not DirAccess.dir_exists_absolute(gdir):
			DirAccess.make_dir_recursive_absolute(gdir)
	return wav.save_to_wav(path)


## 接缝质量：只看向量首尾**相接那一跳**有多突兀。
##
## 判据是 |L[0] − L[n−1]| 与曲内正常样本间跃变的比较 —— 拿结尾一段跟开头一段逐点比对
## 是错的（那是两个不同的音乐时刻，怎么算都不相关）。
## 实现上尾巴已经折回开头，所以 L[0] = dry[0] + dry[n]，而 dry[n] 正是 dry[n−1] 的自然续接，
## 于是这一跳等于「dry[0] 加上一个正常步长」。只要曲子从静音起头（dry[0] ≈ 0），
## 接缝就与普通样本跃变同级。ratio ≤ 1 表示接缝比曲内绝大多数跃变还平缓。
static func seam_metrics(left: PackedFloat32Array) -> Dictionary:
	var n := left.size()
	if n < 4096:
		return {"wrap": 0.0, "max": 0.0, "mean": 0.0, "ratio": 1.0}
	var wrap: float = absf(left[0] - left[n - 1])
	var stride := maxi(1, n / 400000)
	var mx := 0.0
	var sum := 0.0
	var cnt := 0
	var i := 0
	while i + 1 < n:
		var d: float = absf(left[i + 1] - left[i])
		if d > mx:
			mx = d
		sum += d
		cnt += 1
		i += stride
	var mean := sum / float(maxi(1, cnt))
	return {
		"wrap": wrap,
		"max": mx,
		"mean": mean,
		"ratio": wrap / maxf(mx, 1e-9),
	}
