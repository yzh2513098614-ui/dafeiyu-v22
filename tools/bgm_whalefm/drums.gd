extends RefCounted
## 《鲸落电台》鼓组 —— 逐件程序合成，短缓冲直接逐样本算，无需谐振器引擎。
##
## kick   正弦下扫（165→43 Hz）+ 2ms 高通 click
## snare  185/330 Hz 双音调体 + 1.2k–7k 带通噪声
## rim    边击：短谐振音 + 极短噪声
## hat    闭镲：8.2k 高通噪声，t60 ≈ 45ms
## ohat   开镲：同 hat 但衰减长，加三枚非谐正弦做金属感
## shaker 4.5k–10k 带通噪声，前 12ms 起音斜坡
##
## 缓存键是 (件, 力度层)——鼓的时值不参与音色（都是敲一下自然衰减）。

const SR := 44100
const VEL_LEVELS := 8

const Dsp := preload("res://tools/bgm_glasshouse/dsp.gd")

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func cache_size() -> int:
	return _cache.size()


## 渲染一件鼓。voice: kick/snare/rim/hat/ohat/shaker。
static func hit(voice: String, vel: float) -> PackedFloat32Array:
	var vb := clampi(int(round(vel * float(VEL_LEVELS))), 1, VEL_LEVELS)
	var key := "%s:%d" % [voice, vb]
	var hit_buf: Variant = _cache.get(key)
	if hit_buf != null:
		return hit_buf
	var buf := _build(voice, float(vb) / float(VEL_LEVELS))
	_cache[key] = buf
	return buf


static func _build(voice: String, vel: float) -> PackedFloat32Array:
	match voice:
		"kick":
			return _kick(vel)
		"snare":
			return _snare(vel)
		"rim":
			return _rim(vel)
		"hat":
			return _hat(vel, 0.045, 0.12)
		"ohat":
			return _hat(vel, 0.28, 0.65)
		"shaker":
			return _shaker(vel)
	return PackedFloat32Array()


## kick：相位积分的下扫正弦。力度影响下扫起点（越重越亮）与响度。
static func _kick(vel: float) -> PackedFloat32Array:
	var sr := float(SR)
	var total := int(round(0.55 * sr))
	var out := PackedFloat32Array()
	out.resize(total)
	var f_end := 43.0
	var f_top := 150.0 + 26.0 * vel
	var tau_f := 0.026
	var tau_a := 0.16
	var ph := 0.0
	var rz := Dsp.rng(911 + int(vel * 100.0))
	var prev := 0.0
	for i in total:
		var t := float(i) / sr
		var f := f_end + (f_top - f_end) * exp(-t / tau_f)
		ph += TAU * f / sr
		var s := sin(ph) * exp(-t / tau_a)
		if i < int(0.0025 * sr):
			var e := 1.0 - float(i) / float(int(0.0025 * sr))
			var raw := rz.randf_range(-1.0, 1.0)
			s += (raw - prev) * e * e * 0.14
			prev = raw
		out[i] = s * (0.72 + 0.28 * vel)
	return out


## snare：音调体 + 带通噪声。噪声链 HP 1.2k → LP 7k。
static func _snare(vel: float) -> PackedFloat32Array:
	var sr := float(SR)
	var total := int(round(0.42 * sr))
	var noise := PackedFloat32Array()
	noise.resize(total)
	var rz := Dsp.rng(4177 + int(vel * 131.0))
	for i in total:
		noise[i] = rz.randf_range(-1.0, 1.0)
	var band := Dsp.filter_chain(noise, [
		Dsp.coeff_highpass(sr, 1200.0, 0.8),
		Dsp.coeff_lowpass(sr, 7000.0, 0.8),
	])
	var out := PackedFloat32Array()
	out.resize(total)
	for i in total:
		var t := float(i) / sr
		var tone := sin(TAU * 185.0 * t) * exp(-t / 0.055) * 0.55
		tone += sin(TAU * 330.0 * t) * exp(-t / 0.040) * 0.30
		var nz := band[i] * exp(-t / 0.11) * 0.85
		out[i] = (tone + nz) * (0.62 + 0.38 * vel) * 0.9
	return out


## rim：两枚短谐振音 + 一粒噪声脉冲。
static func _rim(vel: float) -> PackedFloat32Array:
	var sr := float(SR)
	var total := int(round(0.09 * sr))
	var out := PackedFloat32Array()
	out.resize(total)
	var rz := Dsp.rng(823 + int(vel * 57.0))
	for i in total:
		var t := float(i) / sr
		var s := sin(TAU * 1750.0 * t) * exp(-t / 0.016) * 0.7
		s += sin(TAU * 2620.0 * t) * exp(-t / 0.012) * 0.5
		s += rz.randf_range(-1.0, 1.0) * exp(-t / 0.004) * 0.35
		out[i] = s * (0.55 + 0.45 * vel)
	return out


## hat / ohat：高通噪声 +（开镲）非谐正弦簇。
static func _hat(vel: float, t60: float, len_sec: float) -> PackedFloat32Array:
	var sr := float(SR)
	var total := int(round(len_sec * sr))
	var noise := PackedFloat32Array()
	noise.resize(total)
	var rz := Dsp.rng(2027 + int(vel * 97.0) + int(t60 * 1000.0))
	for i in total:
		noise[i] = rz.randf_range(-1.0, 1.0)
	var hp := Dsp.filter(noise, Dsp.coeff_highpass(sr, 8200.0, 0.8))
	var out := PackedFloat32Array()
	out.resize(total)
	var metallic := [3140.0, 4230.0, 5710.0]
	for i in total:
		var t := float(i) / sr
		var s := hp[i] * exp(-t / t60)
		if t60 > 0.1:
			for f in metallic:
				s += sin(TAU * float(f) * t) * exp(-t / (t60 * 0.7)) * 0.045
		# 1ms 起音，消掉滤波器瞬态的「噗」
		var atk := int(0.001 * sr)
		if i < atk:
			s *= float(i) / float(maxi(1, atk))
		out[i] = s * (0.66 + 0.34 * vel)
	return out


## shaker：带通噪声，前 12ms 线性起音（沙锤是被摇出来的，不是被敲的）。
static func _shaker(vel: float) -> PackedFloat32Array:
	var sr := float(SR)
	var total := int(round(0.16 * sr))
	var noise := PackedFloat32Array()
	noise.resize(total)
	var rz := Dsp.rng(6079 + int(vel * 71.0))
	for i in total:
		noise[i] = rz.randf_range(-1.0, 1.0)
	var band := Dsp.filter_chain(noise, [
		Dsp.coeff_highpass(sr, 4500.0, 0.8),
		Dsp.coeff_lowpass(sr, 10000.0, 0.8),
	])
	var out := PackedFloat32Array()
	out.resize(total)
	var atk := int(0.012 * sr)
	for i in total:
		var s := band[i]
		if i < atk:
			s *= float(i) / float(maxi(1, atk))
		else:
			s *= exp(-(float(i - atk) / sr) / 0.058)
		out[i] = s * (0.60 + 0.40 * vel)
	return out
