extends RefCounted
## 《鲸落电台》混音与母带。
##
## 顺序：分轨混音 → lo-fi 染色 EQ → 小房间混响 → 黑胶炒豆 + 底噪
##       → **尾巴折回开头** → 软限幅 → 归一化 → 16-bit PCM。
##
## 与《玻璃温室》render.gd 的差异都在音色决策上：
##   音板共鸣 EQ   → lo-fi 染色 EQ（暖低频 / 收中低 / 磁带高频缓降）
##   大厅混响 0.85 → 小房间 0.30（Lo-fi 要近场、要干）
##   −72 dB 底噪   → 黑胶炒豆（泊松脉冲，final 档才有）+ 更低底噪
## 无缝循环的「尾巴折回」与母带链路沿用同一套思路，此处为独立副本，互不影响。

const SR := 44100

const Dsp := preload("res://tools/bgm_glasshouse/dsp.gd")
const Voices := preload("res://tools/bgm_whalefm/voices.gd")
const Drums := preload("res://tools/bgm_whalefm/drums.gd")

## 各层配比。鼓件单独压：镲片噪声最吵，给最少。
const LAYER_GAIN := {
	"ep": 1.0, "bass": 0.82,
	"kick": 0.92, "snare": 0.50, "rim": 0.40,
	"hat": 0.24, "ohat": 0.26, "shaker": 0.28,
}

const DRUM_VOICES := ["kick", "snare", "rim", "hat", "ohat", "shaker"]


static func render_track(score: Dictionary, opts: Dictionary) -> Dictionary:
	var sr := float(SR)
	var bpm := float(score["bpm"])
	var bars := int(score["bars"])
	var loop_sec := float(bars * 4) * 60.0 / bpm
	var loop_frames := int(round(loop_sec * sr))
	var tail_sec := float(opts.get("tail_sec", 2.5))
	var tail_frames := int(round(tail_sec * sr))
	var total := loop_frames + tail_frames

	var ep_partials := int(opts.get("ep_partials", 9))
	var ep_unison := int(opts.get("ep_unison", 2))
	var bass_partials := int(opts.get("bass_partials", 5))

	var dry_l := PackedFloat32Array()
	var dry_r := PackedFloat32Array()
	dry_l.resize(total)
	dry_r.resize(total)

	for e in score["events"]:
		var layer := String(e["layer"])
		var lg := float(LAYER_GAIN.get(layer, 1.0))
		var start := int(round(float(e["t"]) * 60.0 / bpm * sr))
		if start >= total:
			continue
		var v := float(e["v"])
		var pg := Dsp.pan_gains(float(e["pan"]))
		var gl: float = pg[0] * lg
		var gr: float = pg[1] * lg

		var buf: PackedFloat32Array
		if layer == "ep":
			buf = Voices.epiano(int(e["m"]), v, float(e["d"]) * 60.0 / bpm, ep_partials, ep_unison)
		elif layer == "bass":
			buf = Voices.bass(int(e["m"]), v, float(e["d"]) * 60.0 / bpm, bass_partials)
		elif DRUM_VOICES.has(layer):
			buf = Drums.hit(layer, v)
		else:
			continue
		var bl := buf.size()
		var i := 0
		while i < bl:
			var idx := start + i
			if idx >= total:
				break
			dry_l[idx] += buf[i] * gl
			dry_r[idx] += buf[i] * gr
			i += 1

	# --- lo-fi 染色 EQ（混音后一次，线性时不变） ---
	# 高通 34 Hz：kick 的下扫在这个频段会留下直流偏移，实测 28 Hz 时整曲直流均值会越过 1 LSB
	var eq_co := [
		Dsp.coeff_highpass(sr, 34.0, 0.707),
		Dsp.coeff_peaking(sr, 95.0, 1.0, 2.5),
		Dsp.coeff_peaking(sr, 400.0, 1.1, -2.5),
		Dsp.coeff_peaking(sr, 2400.0, 1.0, 1.2),
		Dsp.coeff_highshelf(sr, 8500.0, 0.7, -7.0),
	]
	dry_l = Dsp.filter_chain(dry_l, eq_co)
	dry_r = Dsp.filter_chain(dry_r, eq_co)

	# --- 小房间混响：单声道送出，两条全通链做宽度 ---
	var mono := PackedFloat32Array()
	mono.resize(total)
	for i in total:
		mono[i] = (dry_l[i] + dry_r[i]) * 0.5
	var pd := Dsp.predelay(mono, sr, float(opts.get("predelay_ms", 26.0)))
	var wet_pair := Dsp.freeverb_stereo(pd, sr, float(opts.get("room", 0.72)), float(opts.get("damp", 0.35)))
	var wet_l: PackedFloat32Array = wet_pair[0]
	var wet_r: PackedFloat32Array = wet_pair[1]
	var wet_gain := float(opts.get("wet", 0.30))

	var out_l := PackedFloat32Array()
	var out_r := PackedFloat32Array()
	out_l.resize(total)
	out_r.resize(total)
	for i in total:
		out_l[i] = dry_l[i] + wet_l[i] * wet_gain
		out_r[i] = dry_r[i] + wet_r[i] * wet_gain

	# --- 黑胶炒豆（final 档）：泊松脉冲 → 3.5 kHz 低通，左右声道独立 ---
	if float(opts.get("crackle_per_sec", 14.0)) > 0.0:
		var cl := _crackle(total, int(score["seed"]) + 501, float(opts["crackle_per_sec"]))
		var cr := _crackle(total, int(score["seed"]) + 502, float(opts["crackle_per_sec"]))
		for i in total:
			out_l[i] += cl[i]
			out_r[i] += cr[i]

	# --- 极低电平底噪 ---
	var nf_db := float(opts.get("noise_floor_db", -68.0))
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


## 黑胶炒豆：稀疏脉冲经低通。脉冲间平均间隔 1/rate 秒，幅度随机。
static func _crackle(n: int, seed_value: int, rate: float) -> PackedFloat32Array:
	var imp := PackedFloat32Array()
	imp.resize(n)
	var r := Dsp.rng(seed_value)
	var i := int(r.randf() / rate * SR)
	while i < n:
		var amp := r.randf_range(0.0035, 0.013) * (1.0 if r.randf() < 0.5 else -1.0)
		imp[i] += amp
		if r.randf() < 0.3 and i + 1 < n:
			imp[i + 1] += amp * 0.4
		# 抖动间隔：平均 rate/秒，±40%
		i += int(round((1.0 / rate * SR) * r.randf_range(0.6, 1.4)))
	return Dsp.onepole_lowpass(imp, float(SR), 3500.0)


## 写 16-bit 立体声 PCM wav，加 TPDF 抖动。与玻璃温室同规格。
static func write_wav(path: String, left: PackedFloat32Array, right: PackedFloat32Array) -> Error:
	var n := left.size()
	if n != right.size():
		push_error("左右声道长度不一致")
		return ERR_INVALID_DATA
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	var dither := 1.0 / 32768.0
	var rz := Dsp.rng(20261015)
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


## 接缝质量：首尾相接那一跳 vs 曲内最大样本跃变（同玻璃温室的判据）。
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
		"wrap": wrap, "max": mx, "mean": mean,
		"ratio": wrap / maxf(mx, 1e-9),
	}
