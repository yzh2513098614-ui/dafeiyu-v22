extends RefCounted
## 大肥鱼 · 原创音乐合成器
##
## 把下面写死的乐谱合成为 16bit / 22050Hz 单声道 WAV，输出到 res://assets/music/。
## 全部旋律与和声都是本项目原创，不依赖任何外部素材或第三方库。
## 想换曲子：改下面的和弦走向 / 旋律数组 / bpm，再重新生成一次即可。
##
## 用法（在运行中的项目里）：
##   var synth = load("res://tools/music_synth.gd").new()
##   synth.write_track("title_harbor")
##
## 注意：PackedFloat32Array 在 Godot 4 里是写时复制的值类型，
## 所以缓冲区一律用成员变量 _buf / _scratch，不靠函数参数传出修改。

const RATE := 22050
const OUT_REL := "res://assets/music"
const BEATS_PER_BAR := 4

# 波形
const W_SINE := 0
const W_TRI := 1
const W_PULSE := 2
const W_SAW := 3

const TRACKS: Array = ["title_harbor", "day_town", "night_town", "indoor_warm", "battle_tide"]

# ---------------------------------------------------------------- 和弦（MIDI 音高）
const G_MAJ: Array = [67, 71, 74]
const E_MIN: Array = [64, 67, 71]
const C_MAJ: Array = [72, 76, 79]
const D_MAJ: Array = [62, 66, 69]
const A_MIN: Array = [69, 72, 76]
const F_MAJ: Array = [65, 69, 72]
const D_MIN: Array = [62, 65, 69]
const B_FLAT: Array = [70, 74, 77]
const C_HI: Array = [67, 71, 74]

# ---------------------------------------------------------------- 旋律 [音高, 起始拍, 时值拍, 力度]
const MEL_TITLE: Array = [
	[74, 0, 3, 0.20], [71, 4, 4, 0.18],
	[76, 8, 3, 0.20], [71, 12, 4, 0.18],
	[72, 16, 2, 0.19], [76, 18, 2, 0.19], [74, 20, 4, 0.20],
	[78, 24, 3, 0.20], [74, 28, 3, 0.18], [69, 31, 1, 0.15],
]

const MEL_DAY: Array = [
	[72, 0, 1, 0.20], [76, 1, 1, 0.18], [79, 2, 2, 0.20],
	[76, 4, 1, 0.18], [72, 5, 1, 0.18], [74, 6, 2, 0.20],
	[72, 8, 1, 0.20], [69, 9, 1, 0.18], [72, 10, 2, 0.20],
	[76, 12, 2, 0.20], [74, 14, 2, 0.19],
	[69, 16, 1, 0.20], [72, 17, 1, 0.18], [77, 18, 2, 0.20],
	[76, 20, 2, 0.19], [72, 22, 2, 0.18],
	[79, 24, 1, 0.20], [77, 25, 1, 0.18], [74, 26, 2, 0.20],
	[72, 28, 2, 0.19], [71, 30, 2, 0.18],
]

const MEL_NIGHT: Array = [
	[69, 0, 4, 0.16], [72, 4, 4, 0.15],
	[72, 8, 4, 0.16], [69, 12, 2, 0.14], [65, 14, 2, 0.14],
	[67, 16, 4, 0.15], [72, 20, 4, 0.16],
	[71, 24, 4, 0.15], [69, 28, 4, 0.16],
]

const MEL_INDOOR: Array = [
	[69, 0, 2, 0.18], [72, 2, 2, 0.17], [74, 4, 4, 0.18],
	[72, 8, 2, 0.17], [69, 10, 2, 0.16], [65, 12, 4, 0.17],
	[70, 16, 2, 0.18], [74, 18, 2, 0.17], [77, 20, 4, 0.18],
	[76, 24, 2, 0.17], [74, 26, 2, 0.17], [72, 28, 4, 0.18],
]

const MEL_BATTLE: Array = [
	[74, 0, 1, 0.22], [77, 1, 1, 0.20], [79, 2, 2, 0.22],
	[77, 4, 1, 0.20], [74, 5, 1, 0.20], [72, 6, 2, 0.21],
	[70, 8, 1, 0.22], [74, 9, 1, 0.20], [77, 10, 2, 0.22],
	[74, 12, 2, 0.21], [72, 14, 2, 0.21],
	[72, 16, 1, 0.22], [74, 17, 1, 0.21], [77, 18, 2, 0.22],
	[79, 20, 2, 0.22], [81, 22, 2, 0.21],
	[79, 24, 1, 0.22], [77, 25, 1, 0.21], [74, 26, 2, 0.22],
	[72, 28, 2, 0.21], [74, 30, 2, 0.22],
]

# ---------------------------------------------------------------- 缓冲区
var _buf := PackedFloat32Array()
var _scratch := PackedFloat32Array()

func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)

func _wave(kind: int, phase: float, duty: float) -> float:
	if kind == W_TRI:
		var p := fposmod(phase, TAU) / TAU
		return 4.0 * absf(p - 0.5) - 1.0
	if kind == W_PULSE:
		var q := fposmod(phase, TAU) / TAU
		return 1.0 if q < duty else -1.0
	if kind == W_SAW:
		var r := fposmod(phase, TAU) / TAU
		return 2.0 * r - 1.0
	return sin(phase)

# ---------------------------------------------------------------- 编曲辅助

## 铺底和弦：每个和弦持续 bars_per_chord 小节
func _pads(prog: Array, bars_per_chord: int, amp: float, tail: float = 0.25) -> Array:
	var out: Array = []
	var span := float(bars_per_chord * BEATS_PER_BAR)
	for k in prog.size():
		var start := float(k) * span
		for midi in prog[k][0]:
			out.append([midi, start, span - tail, amp])
	return out

## 琶音：在和弦音之间按 pattern 循环
func _arps(prog: Array, bars_per_chord: int, step: float, pattern: Array, amp: float, lift: int = 0) -> Array:
	var out: Array = []
	var span := float(bars_per_chord * BEATS_PER_BAR)
	var count := int(round(span / step))
	for k in prog.size():
		var chord: Array = prog[k][0]
		for j in count:
			var index: int = int(pattern[j % pattern.size()]) % chord.size()
			out.append([int(chord[index]) + lift, float(k) * span + float(j) * step, step * 0.92, amp])
	return out

## 低音：每小节按 offsets 打根音
func _bass(prog: Array, bars_per_chord: int, offsets: Array, dur: float, amp: float) -> Array:
	var out: Array = []
	var span := float(bars_per_chord * BEATS_PER_BAR)
	for k in prog.size():
		var root: int = int(prog[k][1])
		for bar in bars_per_chord:
			for off in offsets:
				out.append([root, float(k) * span + float(bar * BEATS_PER_BAR) + float(off), dur, amp])
	return out

# ---------------------------------------------------------------- 渲染

func _song(bpm: float, bars: int) -> float:
	var samples := int(round(float(bars * BEATS_PER_BAR) * 60.0 / bpm * RATE))
	_buf = PackedFloat32Array()
	_buf.resize(samples)
	_scratch = PackedFloat32Array()
	_scratch.resize(samples)
	return 60.0 / bpm * RATE

func _add(notes: Array, spb: float, kind: int, lp: float, pluck: float, gain: float, duty: float = 0.5) -> void:
	if notes.is_empty():
		return
	_scratch.fill(0.0)
	_render_notes(notes, spb, kind, duty, lp, pluck)
	for i in _buf.size():
		_buf[i] += _scratch[i] * gain

func _render_notes(notes: Array, spb: float, kind: int, duty: float, lp: float, pluck: float) -> void:
	var total := _scratch.size()
	var attack := maxf(1.0, 0.006 * RATE)
	var release := maxf(1.0, 0.05 * RATE)
	for note in notes:
		var start := int(round(float(note[1]) * spb))
		var dur := int(round(float(note[2]) * spb))
		if start >= total or dur <= 1:
			continue
		dur = mini(dur, total - start)
		var amp: float = note[3]
		var inc := TAU * hz(float(note[0])) / RATE
		var phase := 0.0
		for i in dur:
			var x := float(i)
			var e := 1.0
			if x < attack:
				e = x / attack
			if pluck > 0.0:
				e *= pow(1.0 - x / float(dur), pluck)
			elif x > float(dur) - release:
				e *= maxf(0.0, (float(dur) - x) / release)
			_scratch[start + i] += _wave(kind, phase, duty) * e * amp
			phase += inc
	if lp > 0.0:
		_lowpass(lp)

func _lowpass(cutoff: float) -> void:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in _scratch.size():
		y += a * (_scratch[i] - y)
		_scratch[i] = y

## 打击乐：hits 是 [类型, 起始拍, 力度]，类型为 kick / snare / hat
func _drums(hits: Array, spb: float, gain: float) -> void:
	var total := _buf.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261008
	for hit in hits:
		var kind: String = hit[0]
		var start := int(round(float(hit[1]) * spb))
		if start >= total:
			continue
		var amp: float = float(hit[2]) * gain
		if kind == "kick":
			var kdur := mini(int(0.17 * RATE), total - start)
			var ph := 0.0
			for i in kdur:
				var t := float(i) / RATE
				_buf[start + i] += sin(ph) * exp(-t * 8.5) * amp
				ph += TAU * (118.0 * exp(-t * 24.0) + 44.0) / RATE
		elif kind == "snare":
			var sdur := mini(int(0.14 * RATE), total - start)
			for i in sdur:
				var t := float(i) / RATE
				_buf[start + i] += (rng.randf_range(-1.0, 1.0) * 0.7 + sin(TAU * 190.0 * t) * 0.3) * exp(-t * 24.0) * amp
		else:
			var hdur := mini(int(0.05 * RATE), total - start)
			var y := 0.0
			for i in hdur:
				var t := float(i) / RATE
				var n := rng.randf_range(-1.0, 1.0)
				y += 0.55 * (n - y)
				_buf[start + i] += (n - y) * exp(-t * 80.0) * amp

func _finish(peak: float = 0.88) -> PackedFloat32Array:
	var mx := 0.0
	for v in _buf:
		mx = maxf(mx, absf(v))
	if mx > 0.0001:
		var g := peak / mx
		for i in _buf.size():
			_buf[i] *= g
	# 首尾各 5ms 淡入淡出，消除循环接缝的爆音
	var fade := int(0.005 * RATE)
	var n := _buf.size()
	for i in mini(fade, n / 2):
		var w := float(i) / float(fade)
		_buf[i] *= w
		_buf[n - 1 - i] *= w
	return _buf

# ---------------------------------------------------------------- 五首曲子

func _title_harbor() -> PackedFloat32Array:
	var spb := _song(76.0, 8)
	var prog: Array = [[G_MAJ, 43], [E_MIN, 40], [C_MAJ, 48], [D_MAJ, 50]]
	_add(_pads(prog, 2, 0.16), spb, W_SINE, 1200.0, 0.0, 1.0)
	_add(_arps(prog, 2, 0.5, [0, 1, 2, 1], 0.05, 12), spb, W_TRI, 2600.0, 0.0, 1.0)
	_add(_bass(prog, 2, [0.0, 2.0], 1.8, 0.22), spb, W_TRI, 480.0, 0.0, 1.0)
	_add(MEL_TITLE, spb, W_TRI, 4200.0, 0.35, 1.0)
	return _finish()

func _day_town() -> PackedFloat32Array:
	var spb := _song(108.0, 8)
	var prog: Array = [[C_MAJ, 48], [A_MIN, 45], [F_MAJ, 41], [G_MAJ, 43]]
	_add(_pads(prog, 2, 0.10), spb, W_TRI, 1100.0, 0.0, 1.0)
	_add(_arps(prog, 2, 0.5, [0, 1, 2, 1, 2, 1, 0, 1], 0.055, 0), spb, W_TRI, 3000.0, 0.5, 1.0)
	_add(_bass(prog, 2, [0.0, 1.0, 2.0, 3.0], 0.85, 0.24), spb, W_TRI, 420.0, 0.4, 1.0)
	_add(MEL_DAY, spb, W_PULSE, 3800.0, 0.30, 1.0, 0.35)
	_drums(_backbeat(8, 0.85, 0.34, 0.13), spb, 1.0)
	return _finish()

func _night_town() -> PackedFloat32Array:
	var spb := _song(72.0, 8)
	var prog: Array = [[A_MIN, 45], [F_MAJ, 41], [C_MAJ, 48], [G_MAJ, 43]]
	_add(_pads(prog, 2, 0.17), spb, W_SINE, 900.0, 0.0, 1.0)
	_add(_arps(prog, 2, 1.0, [0, 1, 2, 1], 0.04, 12), spb, W_SINE, 2200.0, 0.0, 1.0)
	_add(_bass(prog, 2, [0.0, 2.0], 2.2, 0.20), spb, W_SINE, 380.0, 0.0, 1.0)
	_add(MEL_NIGHT, spb, W_SINE, 3400.0, 0.18, 1.0)
	_drums(_soft_ticks(8, 0.09), spb, 1.0)
	return _finish()

func _indoor_warm() -> PackedFloat32Array:
	var spb := _song(88.0, 8)
	var prog: Array = [[F_MAJ, 41], [D_MIN, 38], [B_FLAT, 46], [C_HI, 48]]
	_add(_pads(prog, 2, 0.13), spb, W_TRI, 950.0, 0.0, 1.0)
	_add(_arps(prog, 2, 0.75, [0, 2, 1], 0.05, 12), spb, W_SINE, 2400.0, 0.25, 1.0)
	_add(_bass(prog, 2, [0.0, 2.0], 1.6, 0.19), spb, W_TRI, 400.0, 0.0, 1.0)
	_add(MEL_INDOOR, spb, W_TRI, 3600.0, 0.25, 1.0)
	return _finish()

func _battle_tide() -> PackedFloat32Array:
	var spb := _song(132.0, 8)
	var prog: Array = [[D_MIN, 38], [B_FLAT, 46], [F_MAJ, 41], [C_HI, 48]]
	_add(_pads(prog, 2, 0.09), spb, W_SAW, 900.0, 0.0, 1.0)
	_add(_arps(prog, 2, 0.25, [0, 2, 1, 2], 0.05, 12), spb, W_PULSE, 3200.0, 0.5, 1.0, 0.25)
	_add(_bass(prog, 2, [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5], 0.42, 0.28), spb, W_SAW, 500.0, 0.35, 1.0)
	_add(MEL_BATTLE, spb, W_PULSE, 4600.0, 0.30, 1.0, 0.4)
	_drums(_backbeat(8, 1.0, 0.40, 0.16), spb, 1.0)
	return _finish()

# ---------------------------------------------------------------- 鼓型

## 常规律动：每小节 1、3 拍底鼓，2、4 拍军鼓，八分音符踩镲
func _backbeat(bars: int, kick: float, snare: float, hat: float) -> Array:
	var out: Array = []
	for bar in bars:
		var b := float(bar * BEATS_PER_BAR)
		out.append(["kick", b, kick])
		out.append(["kick", b + 2.0, kick])
		out.append(["snare", b + 1.0, snare])
		out.append(["snare", b + 3.0, snare])
		for j in 8:
			out.append(["hat", b + float(j) * 0.5, hat if j % 2 == 0 else hat * 0.6])
	return out

## 夜间只用极轻的踩镲点，保持安静
func _soft_ticks(bars: int, amp: float) -> Array:
	var out: Array = []
	for bar in bars:
		for j in [1.0, 3.0]:
			out.append(["hat", float(bar * BEATS_PER_BAR) + j, amp])
	return out

# ---------------------------------------------------------------- WAV 输出

func to_wav(buf: PackedFloat32Array) -> PackedByteArray:
	var n := buf.size()
	var out := PackedByteArray()
	out.resize(44 + n * 2)
	_ascii(out, 0, "RIFF")
	out.encode_u32(4, 36 + n * 2)
	_ascii(out, 8, "WAVE")
	_ascii(out, 12, "fmt ")
	out.encode_u32(16, 16)
	out.encode_u16(20, 1)
	out.encode_u16(22, 1)
	out.encode_u32(24, RATE)
	out.encode_u32(28, RATE * 2)
	out.encode_u16(32, 2)
	out.encode_u16(34, 16)
	_ascii(out, 36, "data")
	out.encode_u32(40, n * 2)
	for i in n:
		var v := int(round(clampf(buf[i], -1.0, 1.0) * 32767.0))
		out.encode_u16(44 + i * 2, v & 0xFFFF)
	return out

func _ascii(out: PackedByteArray, offset: int, text: String) -> void:
	var bytes := text.to_ascii_buffer()
	for i in bytes.size():
		out[offset + i] = bytes[i]

func render_track(id: String) -> PackedFloat32Array:
	if id == "title_harbor":
		return _title_harbor()
	if id == "day_town":
		return _day_town()
	if id == "night_town":
		return _night_town()
	if id == "indoor_warm":
		return _indoor_warm()
	if id == "battle_tide":
		return _battle_tide()
	return PackedFloat32Array()

func write_track(id: String) -> Dictionary:
	var rendered := render_track(id)
	if rendered.is_empty():
		return {"id": id, "ok": false, "error": "unknown track"}
	var wav := to_wav(rendered)
	var folder := ProjectSettings.globalize_path(OUT_REL)
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join(id + ".wav")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"id": id, "ok": false, "error": "cannot write " + path}
	f.store_buffer(wav)
	f.close()
	return {
		"id": id,
		"ok": true,
		"bytes": wav.size(),
		"seconds": round(float(rendered.size()) / float(RATE) * 100.0) / 100.0,
	}
