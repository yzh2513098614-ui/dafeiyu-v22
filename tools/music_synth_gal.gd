extends RefCounted
## 大肥鱼 · 第二代音乐合成器（galgame 场景配乐版）
##
## 相比第一代 tools/music_synth.gd，补上了真正决定「舒畅 / 空间感」的四件事：
##   1. 立体声输出（声部各自摆位，混响左右解相关）
##   2. 混响（3 条阻尼梳状延迟线，钢线感的空间尾巴）
##   3. 钢琴音色（波表 + 泛音快衰减，音越高衰减越快）
##   4. 七和弦 / 九和弦 / 挂留（伤感色彩靠这个，不是靠旋律）
##
## 六首曲子按 galgame 业界惯例的场景分工写：
##   gal_daily      日常 · 教室 · 据点
##   gal_light      轻快 · 喜剧
##   gal_bittersweet 告白 · 温柔 · 伤感又舒畅  ← 用王道進行
##   gal_memory     回忆 · 乡愁
##   gal_tension    冲突 · 剧情转折
##   gal_hope       结局 · 释怀
##
## 用法：var s = load("res://tools/music_synth_gal.gd").new(); s.write_track("gal_bittersweet")

const RATE := 22050
const OUT_REL := "res://assets/music"
const BEATS_PER_BAR := 4
const TBL := 2048          ## 波表长度

const W_SINE := 0
const W_TRI := 1
const W_PULSE := 2
const W_SAW := 3

## 第一代六首（每个场合一首）
const TRACKS: Array = ["gal_daily", "gal_light", "gal_bittersweet", "gal_memory", "gal_tension", "gal_hope"]

## 第二代六首：给每个场合再补一首轮换曲。
## 音乐总监现在按「场合 = 一组曲目」轮换（见 music/music_director.gd 的 STYLE_SETS），
## 只有一首的话玩家在同一个地方待久了就会一直听同一段，这正是要修的问题。
## 所以这六首刻意和第一代错开调性 / 速度 / 配器：
##   gal_daily2   A大调 104 明亮集市      gal_memory2  D小调 58  夜航音乐盒
##   gal_light2   F大调 72  下行室内      gal_tension2 E小调 116 驱动型紧张
##   gal_title2   G大调 68  慢速大混响    gal_hope2    C大调 92  卡农式收束
const TRACKS_2: Array = ["gal_daily2", "gal_light2", "gal_title2", "gal_memory2", "gal_tension2", "gal_hope2"]

# ---------------------------------------------------------------- 和弦
# 王道進行：IVM7 - V7 - iii7 - vi（D大调 = GM7 - A7 - F#m7 - Bm7）
const GM7: Array = [67, 71, 74, 78]      # G  B  D  F#
const A7: Array = [69, 73, 76, 79]       # A  C# E  G
const FSM7: Array = [66, 69, 73, 76]     # F# A  C# E
const BM7: Array = [59, 62, 66, 69]      # B  D  F# A

# C大调日常
const CM7: Array = [60, 64, 67, 71]
const G7C: Array = [59, 62, 67, 71]
const AM7: Array = [57, 60, 64, 67]
const FM7: Array = [53, 57, 60, 64]

# A小调回忆
const MEM_AM: Array = [57, 60, 64, 67]
const MEM_F: Array = [53, 57, 60, 64]
const MEM_C: Array = [60, 64, 67, 71]
const MEM_G: Array = [55, 59, 62, 67]

# D小调紧张
const T_DM: Array = [62, 65, 69]
const T_BB: Array = [58, 62, 65]
const T_GM: Array = [55, 58, 62]
const T_A: Array = [57, 61, 64]

# F大调希望（卡农进行）
const H_F: Array = [65, 69, 72, 76]
const H_C: Array = [64, 67, 72, 76]
const H_DM: Array = [62, 65, 69, 72]
const H_AM: Array = [57, 60, 64, 67]
const H_BB: Array = [58, 62, 65, 69]

# G大调轻快
const L_G: Array = [67, 71, 74, 79]
const L_EM: Array = [64, 67, 71, 76]
const L_AM: Array = [69, 72, 76, 81]
const L_D: Array = [62, 66, 69, 74]

# A大调白天二（明亮集市）
const D2_A: Array = [57, 61, 64, 68]
const D2_FSM: Array = [54, 57, 61, 64]
const D2_D: Array = [50, 54, 57, 61]
const D2_E: Array = [52, 56, 59, 62]

# D小调夜航二（稀疏音乐盒）
const N2_DM: Array = [50, 53, 57, 60]
const N2_BB: Array = [46, 50, 53, 57]
const N2_GM: Array = [43, 46, 50, 53]
const N2_A: Array = [45, 49, 52, 55]

# F大调室内二（下行级进）
const I2_F: Array = [53, 57, 60, 64]
const I2_EM: Array = [52, 55, 59, 62]
const I2_DM: Array = [50, 53, 57, 60]
const I2_CM: Array = [48, 52, 55, 59]

# E小调紧张二（驱动型）
const B2_EM: Array = [52, 55, 59]
const B2_C: Array = [48, 52, 55]
const B2_AM: Array = [45, 48, 52]
const B2_B: Array = [47, 51, 54]

# G大调标题二
const T2_G: Array = [55, 59, 62, 66]
const T2_EM: Array = [52, 55, 59, 62]
const T2_C: Array = [48, 52, 55, 59]
const T2_D: Array = [50, 54, 57, 61]

# C大调希望二
const H2_C: Array = [48, 52, 55, 59]
const H2_G: Array = [43, 47, 50, 55]
const H2_AM: Array = [45, 48, 52, 55]
const H2_F: Array = [41, 45, 48, 53]

# ---------------------------------------------------------------- 旋律 [音高, 起始拍, 时值拍, 力度]
# 伤感又舒畅：上行到高处再落下，结束停在开放音（Bm7 的 b7 = A）而不是主音
const MEL_BSW: Array = [
	[69, 0, 2, 0.19], [71, 2, 2, 0.18], [74, 4, 4, 0.21],
	[76, 8, 2, 0.20], [74, 10, 2, 0.19], [73, 12, 4, 0.20],
	[78, 16, 3, 0.21], [76, 19, 2, 0.19], [73, 21, 3, 0.19],
	[74, 24, 2, 0.20], [71, 26, 2, 0.18], [69, 28, 4, 0.20],
]

const MEL_DAILY: Array = [
	[64, 0, 1, 0.19], [67, 1, 1, 0.17], [72, 2, 2, 0.20],
	[71, 4, 1, 0.18], [67, 5, 1, 0.17], [69, 6, 2, 0.19],
	[67, 8, 1, 0.19], [64, 9, 1, 0.17], [67, 10, 2, 0.19],
	[69, 12, 2, 0.19], [67, 14, 2, 0.18],
	[69, 16, 1, 0.19], [72, 17, 1, 0.18], [76, 18, 2, 0.20],
	[74, 20, 2, 0.19], [72, 22, 2, 0.18],
	[69, 24, 1, 0.19], [67, 25, 1, 0.17], [64, 26, 2, 0.19],
	[67, 28, 2, 0.19], [69, 30, 2, 0.19],
]

const MEL_MEMORY: Array = [
	[76, 0, 4, 0.16], [72, 4, 4, 0.15],
	[74, 8, 4, 0.16], [72, 12, 2, 0.14], [69, 14, 2, 0.14],
	[76, 16, 4, 0.16], [79, 20, 4, 0.15],
	[74, 24, 4, 0.15], [71, 28, 4, 0.16],
]

const MEL_TENSION: Array = [
	[74, 0, 0.5, 0.18], [75, 1.5, 0.5, 0.15], [74, 3, 1, 0.18],
	[77, 4, 0.5, 0.16], [75, 5.5, 1, 0.15],
	[74, 8, 0.5, 0.18], [72, 9.5, 0.5, 0.15], [70, 11, 1, 0.17],
	[73, 12, 0.5, 0.16], [74, 13.5, 1.5, 0.18],
	[74, 16, 0.5, 0.18], [77, 17.5, 0.5, 0.15], [79, 19, 1, 0.18],
	[77, 20, 0.5, 0.16], [74, 21.5, 1, 0.15],
	[72, 24, 0.5, 0.18], [73, 25.5, 0.5, 0.16], [74, 27, 2, 0.19],
	[76, 30, 2, 0.17],
]

const MEL_HOPE: Array = [
	[69, 0, 2, 0.18], [72, 2, 2, 0.18], [77, 4, 4, 0.20],
	[76, 8, 2, 0.19], [72, 10, 2, 0.18], [74, 12, 4, 0.19],
	[77, 16, 2, 0.20], [79, 18, 2, 0.20], [81, 20, 4, 0.21],
	[79, 24, 2, 0.20], [77, 26, 2, 0.20], [74, 28, 2, 0.19], [72, 30, 2, 0.19],
]

const MEL_LIGHT: Array = [
	[79, 0, 0.5, 0.18], [78, 0.75, 0.5, 0.15], [79, 1.5, 1, 0.18], [74, 3, 1, 0.16],
	[76, 4, 0.5, 0.18], [74, 4.75, 0.5, 0.15], [71, 5.5, 2, 0.18],
	[71, 8, 0.5, 0.18], [74, 8.75, 0.5, 0.15], [76, 9.5, 1, 0.18], [72, 11, 1, 0.16],
	[74, 12, 0.5, 0.18], [72, 12.75, 0.5, 0.15], [69, 13.5, 2, 0.18],
	[71, 16, 0.5, 0.18], [74, 16.75, 0.5, 0.15], [79, 17.5, 1, 0.19], [81, 19, 1, 0.18],
	[79, 20, 0.5, 0.18], [76, 20.75, 0.5, 0.15], [74, 21.5, 2, 0.18],
	[69, 24, 0.5, 0.18], [71, 24.75, 0.5, 0.15], [74, 25.5, 1, 0.18], [78, 27, 1, 0.17],
	[76, 28, 0.5, 0.18], [74, 28.75, 0.5, 0.15], [71, 29.5, 2, 0.18],
]

# ---------------------------------------------------------------- 第二代旋律

# 明亮集市：A大调，短句反复上行，收在属音上吊着（接回主歌不落地）
const MEL_DAY2: Array = [
	[73, 0, 1, 0.19], [76, 1, 1, 0.17], [81, 2, 2, 0.20],
	[78, 4, 1, 0.18], [76, 5, 1, 0.17], [73, 6, 2, 0.19],
	[76, 8, 1, 0.19], [73, 9, 1, 0.17], [78, 10, 2, 0.19],
	[81, 12, 2, 0.19], [80, 14, 2, 0.18],
	[78, 16, 1, 0.19], [76, 17, 1, 0.18], [73, 18, 2, 0.20],
	[76, 20, 2, 0.19], [78, 22, 2, 0.18],
	[81, 24, 1, 0.19], [80, 25, 1, 0.17], [78, 26, 2, 0.19],
	[76, 28, 2, 0.19], [73, 30, 2, 0.19],
]

# 夜航灯：D小调，长音为主，音程跳动大，像雾里的灯塔一闪一闪
const MEL_NIGHT2: Array = [
	[74, 0, 4, 0.15], [77, 4, 4, 0.14],
	[81, 8, 4, 0.15], [79, 12, 4, 0.14],
	[77, 16, 4, 0.15], [74, 20, 4, 0.14],
	[72, 24, 4, 0.15], [74, 28, 4, 0.15],
]

# 旧书与茶：F大调下行，旋律跟着和声一级一级往下走，室内感
const MEL_INDOOR2: Array = [
	[72, 0, 2, 0.17], [76, 2, 2, 0.16], [79, 4, 4, 0.18],
	[77, 8, 2, 0.17], [76, 10, 2, 0.16], [72, 12, 4, 0.17],
	[74, 16, 2, 0.17], [77, 18, 2, 0.16], [81, 20, 4, 0.18],
	[79, 24, 2, 0.17], [76, 26, 2, 0.16], [72, 28, 4, 0.18],
]

# 深潮涌动：E小调，十六分附点推着走，紧张但不刺耳
const MEL_TENSION2: Array = [
	[76, 0, 0.5, 0.18], [77, 1, 0.5, 0.15], [76, 2, 1, 0.18],
	[79, 4, 0.5, 0.17], [77, 5.5, 1, 0.15],
	[76, 8, 0.5, 0.18], [74, 9.5, 0.5, 0.15], [72, 11, 1, 0.17],
	[75, 12, 0.5, 0.16], [76, 13.5, 1.5, 0.18],
	[76, 16, 0.5, 0.18], [79, 17.5, 0.5, 0.15], [83, 19, 1, 0.18],
	[81, 20, 0.5, 0.16], [79, 21.5, 1, 0.15],
	[77, 24, 0.5, 0.18], [76, 25.5, 0.5, 0.16], [74, 27, 2, 0.19],
	[76, 30, 2, 0.17],
]

# 潮声前奏：G大调慢速，大跳之后长音悬着，标题画面的留白
const MEL_TITLE2: Array = [
	[78, 0, 3, 0.17], [81, 3, 1, 0.15], [83, 4, 4, 0.19],
	[81, 8, 2, 0.18], [79, 10, 2, 0.17], [78, 12, 4, 0.18],
	[83, 16, 3, 0.18], [81, 19, 1, 0.16], [79, 20, 4, 0.18],
	[76, 24, 2, 0.17], [78, 26, 2, 0.17], [74, 28, 4, 0.18],
]

# 归港：C大调卡农式，逐句上行，最后落回主音（和一代的 gal_hope 同用途但不同调）
const MEL_HOPE2: Array = [
	[72, 0, 2, 0.18], [76, 2, 2, 0.18], [79, 4, 4, 0.20],
	[78, 8, 2, 0.19], [76, 10, 2, 0.18], [74, 12, 4, 0.19],
	[79, 16, 2, 0.20], [81, 18, 2, 0.20], [83, 20, 4, 0.21],
	[81, 24, 2, 0.20], [79, 26, 2, 0.20], [76, 28, 2, 0.19], [72, 30, 2, 0.19],
]

# ---------------------------------------------------------------- 缓冲区
var _l := PackedFloat32Array()
var _r := PackedFloat32Array()
var _mono := PackedFloat32Array()
var _tables: Dictionary = {}

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

# ---------------------------------------------------------------- 波表（钢琴音色）

func _table(name: String, levels: Array) -> PackedFloat32Array:
	if _tables.has(name):
		return _tables[name]
	var t := PackedFloat32Array()
	t.resize(TBL)
	for i in TBL:
		var ph := TAU * float(i) / float(TBL)
		var s := 0.0
		for h in levels.size():
			s += sin(ph * float(h + 1)) * float(levels[h])
		t[i] = s
	var mx := 0.0
	for v in t:
		mx = maxf(mx, absf(v))
	if mx > 0.0001:
		for i in TBL:
			t[i] /= mx
	_tables[name] = t
	return t

func _body_table() -> PackedFloat32Array:
	return _table("body", [1.0, 0.42, 0.20, 0.09, 0.04])

func _bright_table() -> PackedFloat32Array:
	return _table("bright", [0.0, 0.55, 0.70, 0.55, 0.38, 0.22])

# ---------------------------------------------------------------- 编曲辅助

func _pads(prog: Array, bars_per_chord: int, amp: float, tail: float = 0.30, lift: int = 0) -> Array:
	var out: Array = []
	var span := float(bars_per_chord * BEATS_PER_BAR)
	for k in prog.size():
		var start := float(k) * span
		for midi in prog[k][0]:
			out.append([int(midi) + lift, start, span - tail, amp])
	return out

func _arps(prog: Array, bars_per_chord: int, step: float, pattern: Array, amp: float, lift: int = 0) -> Array:
	var out: Array = []
	var span := float(bars_per_chord * BEATS_PER_BAR)
	var count := int(round(span / step))
	for k in prog.size():
		var chord: Array = prog[k][0]
		for j in count:
			var index: int = int(pattern[j % pattern.size()]) % chord.size()
			out.append([int(chord[index]) + lift, float(k) * span + float(j) * step, step * 0.88, amp])
	return out

func _bass(prog: Array, bars_per_chord: int, offsets: Array, dur: float, amp: float) -> Array:
	var out: Array = []
	var span := float(bars_per_chord * BEATS_PER_BAR)
	for k in prog.size():
		var root: int = int(prog[k][1])
		for bar in bars_per_chord:
			for off in offsets:
				out.append([root, float(k) * span + float(bar * BEATS_PER_BAR) + float(off), dur, amp])
	return out

# ---------------------------------------------------------------- 渲染核心

func _song(bpm: float, bars: int) -> float:
	var samples := int(round(float(bars * BEATS_PER_BAR) * 60.0 / bpm * RATE))
	_l = PackedFloat32Array(); _l.resize(samples)
	_r = PackedFloat32Array(); _r.resize(samples)
	_mono = PackedFloat32Array(); _mono.resize(samples)
	return 60.0 / bpm * RATE

func _pan_to(buffer: PackedFloat32Array, gain: float, pan: float) -> void:
	var gl := gain * sqrt(0.5 * (1.0 - pan))
	var gr := gain * sqrt(0.5 * (1.0 + pan))
	for i in _mono.size():
		var v := _mono[i]
		_l[i] += v * gl
		_r[i] += v * gr

func _add_wave(notes: Array, spb: float, kind: int, lp: float, pluck: float, gain: float, pan: float, duty: float = 0.5) -> void:
	if notes.is_empty():
		return
	_mono.fill(0.0)
	var total := _mono.size()
	var attack := maxf(1.0, 0.010 * RATE)
	var release := maxf(1.0, 0.06 * RATE)
	for note in notes:
		var start := int(round(float(note[1]) * spb))
		var dur := int(round(float(note[2]) * spb))
		if start >= total or dur <= 1:
			continue
		dur = mini(dur, total - start)
		var amp: float = float(note[3])
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
			_mono[start + i] += _wave(kind, phase, duty) * e * amp
			phase += inc
	if lp > 0.0:
		_lowpass(lp)
	_pan_to(_l, gain, pan)

## 钢琴音色：波表 + 泛音快衰减 + 音越高衰减越快 + 轻微时值人性化
func _add_piano(notes: Array, spb: float, decay: float, bright: float, gain: float, pan: float, rng: RandomNumberGenerator) -> void:
	if notes.is_empty():
		return
	_mono.fill(0.0)
	var body := _body_table()
	var edge := _bright_table()
	var total := _mono.size()
	var attack := maxf(1.0, 0.003 * RATE)
	var jitter := 0.009 * RATE
	for note in notes:
		var start := clampi(int(round(float(note[1]) * spb + rng.randf_range(-jitter, jitter))), 0, total - 2)
		var dur := int(round(float(note[2]) * spb))
		if dur <= 1:
			continue
		dur = mini(dur, total - start)
		var midi := float(note[0])
		var amp: float = float(note[3]) * rng.randf_range(0.88, 1.12)
		var d := decay * (1.0 + (midi - 60.0) * 0.013)
		var inc := hz(midi) / RATE * float(TBL)
		var ph := 0.0
		for i in dur:
			var x := float(i)
			var e := 1.0
			if x < attack:
				e = x / attack
			var t := x / RATE
			var idx := int(ph)
			_mono[start + i] += (body[idx] * exp(-t * d) + edge[idx] * exp(-t * d * 5.5) * bright) * e * amp
			ph += inc
			if ph >= float(TBL):
				ph -= float(TBL)
	if decay > 0.0:
		pass
	_pan_to(_l, gain, pan)

func _lowpass(cutoff: float) -> void:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in _mono.size():
		y += a * (_mono[i] - y)
		_mono[i] = y

# ---------------------------------------------------------------- 混响

func _reverb(mix: float, decay: float = 0.62) -> void:
	# 混响源取左右单声道和，这是关键：
	# 如果对左右各自的信号做梳状延迟，两声道相位响应不同，湿声会在一侧与干声部分抵消，
	# 实测造成 L/R 约 3.4dB 的能量失衡。
	# 改用同一个单声道和分别喂给左右两组不同长度的延迟线 → 同一输入、同结构，
	# 总能量近似相等（不失衡），而内容互不相关（有宽度）。
	var n := _l.size()
	var src := PackedFloat32Array()
	src.resize(n)
	for i in n:
		src[i] = (_l[i] + _r[i]) * 0.5
	var wet_l := _tail(src, [1153, 1439, 1721, 2003], decay)
	var wet_r := _tail(src, [1213, 1499, 1783, 2063], decay)
	for i in n:
		_l[i] += wet_l[i] * mix
		_r[i] += wet_r[i] * mix

func _tail(src: PackedFloat32Array, offsets: Array, decay: float) -> PackedFloat32Array:
	var n := src.size()
	var wet := PackedFloat32Array()
	wet.resize(n)
	var scale := 1.0 / float(offsets.size())
	for base in offsets:
		var d := int(base)
		var line := PackedFloat32Array()
		line.resize(d)
		var idx := 0
		var damp := 0.0
		for i in n:
			var y := line[idx]
			damp = y * 0.30 + damp * 0.70
			line[idx] = src[i] + damp * decay
			wet[i] += y * scale
			idx += 1
			if idx >= d:
				idx = 0
	return wet

# ---------------------------------------------------------------- 收尾与输出

func _finish(peak: float = 0.90) -> PackedFloat32Array:
	var mx := 0.0
	for i in _l.size():
		mx = maxf(mx, maxf(absf(_l[i]), absf(_r[i])))
	if mx > 0.0001:
		var g := peak / mx
		for i in _l.size():
			_l[i] *= g
			_r[i] *= g
	# 首尾各 25ms 淡入淡出，混响尾巴不会在循环接缝处爆音
	var fade := int(0.025 * RATE)
	var n := _l.size()
	for i in mini(fade, n / 2):
		var w := float(i) / float(fade)
		_l[i] *= w
		_r[i] *= w
		_l[n - 1 - i] *= w
		_r[n - 1 - i] *= w
	var out := PackedFloat32Array()
	out.resize(n * 2)
	for i in n:
		out[i * 2] = _l[i]
		out[i * 2 + 1] = _r[i]
	return out

func to_wav(stereo: PackedFloat32Array) -> PackedByteArray:
	var frames := stereo.size() / 2
	var payload := frames * 4
	var out := PackedByteArray()
	out.resize(44 + payload)
	_ascii(out, 0, "RIFF")
	out.encode_u32(4, 36 + payload)
	_ascii(out, 8, "WAVE")
	_ascii(out, 12, "fmt ")
	out.encode_u32(16, 16)
	out.encode_u16(20, 1)
	out.encode_u16(22, 2)
	out.encode_u32(24, RATE)
	out.encode_u32(28, RATE * 4)
	out.encode_u16(32, 4)
	out.encode_u16(34, 16)
	_ascii(out, 36, "data")
	out.encode_u32(40, payload)
	for i in stereo.size():
		var v := int(round(clampf(stereo[i], -1.0, 1.0) * 32767.0))
		out.encode_u16(44 + i * 2, v & 0xFFFF)
	return out

func _ascii(out: PackedByteArray, offset: int, text: String) -> void:
	var bytes := text.to_ascii_buffer()
	for i in bytes.size():
		out[offset + i] = bytes[i]

# ---------------------------------------------------------------- 六首曲子

func _gal_daily() -> PackedFloat32Array:
	var spb := _song(96.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 1101
	var prog: Array = [[CM7, 48], [G7C, 43], [AM7, 45], [FM7, 41]]
	_add_wave(_pads(prog, 2, 0.048), spb, W_TRI, 1000.0, 0.0, 1.0, -0.50)
	_add_wave(_pads(prog, 2, 0.048, 0.30, 12), spb, W_SINE, 1500.0, 0.0, 1.0, 0.50)
	_add_piano(_arps(prog, 2, 0.5, [0, 1, 2, 1], 0.055, 12), spb, 2.4, 0.30, 1.0, 0.22, rng)
	_add_wave(_bass(prog, 2, [0.0, 1.5, 2.0, 3.5], 0.80, 0.20), spb, W_TRI, 400.0, 0.35, 1.0, 0.0)
	_add_piano(MEL_DAILY, spb, 2.0, 0.34, 1.0, -0.10, rng)
	_soft_hats(spb, 8, 0.055)
	_reverb(0.38)
	return _finish()

func _gal_light() -> PackedFloat32Array:
	var spb := _song(120.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 2202
	var prog: Array = [[L_G, 43], [L_EM, 40], [L_AM, 45], [L_D, 50]]
	_add_wave(_pads(prog, 2, 0.042), spb, W_TRI, 1100.0, 0.0, 1.0, -0.50)
	_add_wave(_pads(prog, 2, 0.042, 0.30, 12), spb, W_SINE, 1600.0, 0.0, 1.0, 0.50)
	_add_piano(_arps(prog, 2, 0.25, [0, 2, 1, 3, 2, 0], 0.045, 12), spb, 3.2, 0.42, 1.0, 0.30, rng)
	_add_wave(_bass(prog, 2, [0.0, 0.75, 1.5, 2.0, 2.75, 3.5], 0.38, 0.22), spb, W_TRI, 450.0, 0.45, 1.0, 0.0)
	_add_piano(MEL_LIGHT, spb, 2.8, 0.40, 1.0, -0.12, rng)
	_soft_hats(spb, 8, 0.075)
	_reverb(0.32)
	return _finish()

## 伤感又舒畅：王道進行 IVM7-V7-iii7-vi（D大调 G-A-F#m-Bm）
## 前半明亮让人期待解决，后半落到关系小调 → 惆怅但开阔
func _gal_bittersweet() -> PackedFloat32Array:
	var spb := _song(76.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 3303
	var prog: Array = [[GM7, 43], [A7, 45], [FSM7, 42], [BM7, 47]]
	# 弦垫：左右对称摆位。两边音量必须相同，否则整首曲子的能量会整体偏向一侧。
	_add_wave(_pads(prog, 2, 0.062, 0.30, 0), spb, W_SINE, 900.0, 0.0, 1.0, -0.52)
	_add_wave(_pads(prog, 2, 0.062, 0.30, 12), spb, W_TRI, 1400.0, 0.0, 1.0, 0.52)
	# 流动的钢琴八分音符 —— 这是「舒畅」的发动机
	_add_piano(_arps(prog, 2, 0.5, [0, 2, 1, 3, 2, 1], 0.058, 12), spb, 2.1, 0.26, 1.0, 0.18, rng)
	_add_wave(_bass(prog, 2, [0.0, 2.0], 1.9, 0.19), spb, W_SINE, 380.0, 0.0, 1.0, 0.0)
	# 主旋律：钢琴，稍偏左，长音，泛音亮一点
	_add_piano(MEL_BSW, spb, 1.7, 0.30, 1.0, -0.14, rng)
	# 空间感靠混响，不靠打击乐 —— 所以这里一首鼓都不加
	_reverb(0.70, 0.66)
	return _finish()

func _gal_memory() -> PackedFloat32Array:
	var spb := _song(64.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 4404
	var prog: Array = [[MEM_AM, 45], [MEM_F, 41], [MEM_C, 48], [MEM_G, 43]]
	_add_wave(_pads(prog, 2, 0.050, 0.40, 0), spb, W_SINE, 800.0, 0.0, 1.0, -0.50)
	_add_wave(_pads(prog, 2, 0.050, 0.40, 12), spb, W_TRI, 1300.0, 0.0, 1.0, 0.50)
	# 音乐盒式的稀疏琶音，高八度
	_add_piano(_arps(prog, 2, 1.0, [0, 2, 1, 3], 0.050, 24), spb, 1.2, 0.55, 1.0, 0.34, rng)
	_add_wave(_bass(prog, 2, [0.0, 2.0], 2.4, 0.17), spb, W_SINE, 340.0, 0.0, 1.0, 0.0)
	_add_piano(MEL_MEMORY, spb, 1.1, 0.48, 1.0, -0.16, rng)
	_reverb(0.80, 0.70)
	return _finish()

func _gal_tension() -> PackedFloat32Array:
	var spb := _song(100.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 5505
	# 低音保持 D 踏板音，和声在上方移动 —— 紧张感的经典做法
	var prog: Array = [[T_DM, 38], [T_BB, 38], [T_GM, 38], [T_A, 38]]
	_add_wave(_pads(prog, 2, 0.060), spb, W_SAW, 700.0, 0.0, 1.0, -0.34)
	_add_wave(_pads(prog, 2, 0.060, 0.30, 12), spb, W_SAW, 1200.0, 0.0, 1.0, 0.34)
	_add_wave(_arps(prog, 2, 0.5, [0, 1, 2], 0.040, 0), spb, W_PULSE, 1500.0, 0.55, 1.0, 0.34, 0.30)
	_add_wave(_bass(prog, 2, [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5], 0.40, 0.24), spb, W_SAW, 420.0, 0.30, 1.0, 0.0)
	_add_piano(MEL_TENSION, spb, 2.6, 0.30, 1.0, 0.0, rng)
	_reverb(0.26, 0.58)
	return _finish()

## 结局 · 希望：卡农进行，琶音持续上行，结尾解决到主音
func _gal_hope() -> PackedFloat32Array:
	var spb := _song(88.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 6606
	var prog: Array = [[H_F, 41], [H_C, 36], [H_DM, 38], [H_AM, 45], [H_BB, 34], [H_F, 41], [H_BB, 46], [H_C, 48]]
	_add_wave(_pads(prog, 1, 0.058, 0.25, 0), spb, W_TRI, 1000.0, 0.0, 1.0, -0.52)
	_add_wave(_pads(prog, 1, 0.058, 0.25, 12), spb, W_SINE, 1600.0, 0.0, 1.0, 0.52)
	_add_piano(_arps(prog, 1, 0.5, [0, 1, 2, 3], 0.056, 12), spb, 2.2, 0.30, 1.0, 0.16, rng)
	_add_wave(_bass(prog, 1, [0.0, 2.0], 1.9, 0.20), spb, W_TRI, 400.0, 0.0, 1.0, 0.0)
	_add_piano(MEL_HOPE, spb, 1.8, 0.34, 1.0, -0.12, rng)
	_soft_hats(spb, 8, 0.05)
	_reverb(0.62, 0.66)
	return _finish()

# ---------------------------------------------------------------- 第二代六首
#
# 和第一代共用同一套渲染管线（波表钢琴 / 立体声摆位 / 梳状混响），
# 差别只在调性、速度、和声进行与配器密度 —— 这样两首轮换着听是同一位作曲者的
# 两首曲子，而不是两种音色打架。

## 明亮集市：A大调 104，三角波垫底 + 八分音符钢琴 + 极轻踩镲
func _gal_daily2() -> PackedFloat32Array:
	var spb := _song(104.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 1201
	var prog: Array = [[D2_A, 45], [D2_FSM, 42], [D2_D, 50], [D2_E, 40]]
	_add_wave(_pads(prog, 2, 0.046), spb, W_TRI, 1100.0, 0.0, 1.0, -0.50)
	_add_wave(_pads(prog, 2, 0.046, 0.30, 12), spb, W_SINE, 1600.0, 0.0, 1.0, 0.50)
	_add_piano(_arps(prog, 2, 0.5, [0, 2, 1, 3], 0.052, 12), spb, 2.6, 0.32, 1.0, 0.20, rng)
	_add_wave(_bass(prog, 2, [0.0, 1.5, 2.0, 3.5], 0.80, 0.20), spb, W_TRI, 420.0, 0.35, 1.0, 0.0)
	_add_piano(MEL_DAY2, spb, 2.2, 0.32, 1.0, -0.10, rng)
	_soft_hats(spb, 8, 0.060)
	_reverb(0.34)
	return _finish()

## 下行室内：F大调 72，和声一级一级往下走，钢琴密度比一代的 gal_light 更低
func _gal_light2() -> PackedFloat32Array:
	var spb := _song(72.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 1401
	var prog: Array = [[I2_F, 41], [I2_EM, 40], [I2_DM, 38], [I2_CM, 36]]
	_add_wave(_pads(prog, 2, 0.056, 0.32, 0), spb, W_TRI, 1000.0, 0.0, 1.0, -0.50)
	_add_wave(_pads(prog, 2, 0.056, 0.32, 12), spb, W_SINE, 1500.0, 0.0, 1.0, 0.50)
	_add_piano(_arps(prog, 2, 0.75, [0, 1, 2, 1], 0.050, 12), spb, 2.8, 0.30, 1.0, 0.26, rng)
	_add_wave(_bass(prog, 2, [0.0, 2.0], 1.9, 0.19), spb, W_TRI, 400.0, 0.30, 1.0, 0.0)
	_add_piano(MEL_INDOOR2, spb, 2.0, 0.30, 1.0, -0.12, rng)
	_reverb(0.62)
	return _finish()

## 潮声前奏：G大调 68，慢速大混响，只在标题画面用；旋律故意留长音不解决
func _gal_title2() -> PackedFloat32Array:
	var spb := _song(68.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 1601
	var prog: Array = [[T2_G, 43], [T2_EM, 40], [T2_C, 48], [T2_D, 50]]
	_add_wave(_pads(prog, 2, 0.062, 0.30, 0), spb, W_SINE, 900.0, 0.0, 1.0, -0.52)
	_add_wave(_pads(prog, 2, 0.062, 0.30, 12), spb, W_TRI, 1400.0, 0.0, 1.0, 0.52)
	_add_piano(_arps(prog, 2, 1.0, [0, 2, 1, 3], 0.050, 12), spb, 1.8, 0.34, 1.0, 0.18, rng)
	_add_wave(_bass(prog, 2, [0.0, 2.0], 2.6, 0.18), spb, W_SINE, 380.0, 0.0, 1.0, 0.0)
	_add_piano(MEL_TITLE2, spb, 1.4, 0.38, 1.0, -0.14, rng)
	_reverb(0.78, 0.70)
	return _finish()

## 夜航灯：D小调 58，音乐盒式高八度琶音，一代的 gal_memory 是 A小调中音区，
## 这首刻意更空、更冷，夜里和它轮换才不会觉得是同一首
func _gal_memory2() -> PackedFloat32Array:
	var spb := _song(58.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 1301
	var prog: Array = [[N2_DM, 38], [N2_BB, 34], [N2_GM, 43], [N2_A, 45]]
	_add_wave(_pads(prog, 2, 0.050, 0.45, 0), spb, W_SINE, 800.0, 0.0, 1.0, -0.50)
	_add_wave(_pads(prog, 2, 0.050, 0.45, 12), spb, W_TRI, 1300.0, 0.0, 1.0, 0.50)
	_add_piano(_arps(prog, 2, 1.0, [0, 2, 1, 3], 0.045, 24), spb, 1.0, 0.55, 1.0, 0.34, rng)
	_add_wave(_bass(prog, 2, [0.0, 2.0], 2.4, 0.16), spb, W_SINE, 330.0, 0.0, 1.0, 0.0)
	_add_piano(MEL_NIGHT2, spb, 1.0, 0.50, 1.0, -0.16, rng)
	_reverb(0.82, 0.70)
	return _finish()

## 深潮涌动：E小调 116，锯齿垫 + 十六分脉冲；一代的 gal_tension 是 D小调踏板音，
## 这首换成小调四和弦循环，速度更快，适合连续战斗时不腻
func _gal_tension2() -> PackedFloat32Array:
	var spb := _song(116.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 1501
	var prog: Array = [[B2_EM, 40], [B2_C, 36], [B2_AM, 45], [B2_B, 35]]
	_add_wave(_pads(prog, 2, 0.055), spb, W_SAW, 700.0, 0.0, 1.0, -0.32)
	_add_wave(_pads(prog, 2, 0.055, 0.30, 12), spb, W_SAW, 1200.0, 0.0, 1.0, 0.32)
	_add_wave(_arps(prog, 2, 0.25, [0, 1, 2, 1], 0.034, 12), spb, W_PULSE, 1600.0, 0.55, 1.0, 0.36, 0.35)
	_add_wave(_bass(prog, 2, [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5], 0.38, 0.24), spb, W_SAW, 430.0, 0.30, 1.0, 0.0)
	_add_piano(MEL_TENSION2, spb, 2.4, 0.34, 1.0, 0.0, rng)
	_reverb(0.24, 0.55)
	return _finish()

## 归港：C大调 92，卡农式上行；一代的 gal_hope 是 F大调，两首轮换着听都是「结束」的味道
func _gal_hope2() -> PackedFloat32Array:
	var spb := _song(92.0, 8)
	var rng := RandomNumberGenerator.new(); rng.seed = 1701
	var prog: Array = [[H2_C, 48], [H2_G, 43], [H2_AM, 45], [H2_F, 41]]
	_add_wave(_pads(prog, 2, 0.056, 0.25, 0), spb, W_TRI, 1000.0, 0.0, 1.0, -0.52)
	_add_wave(_pads(prog, 2, 0.056, 0.25, 12), spb, W_SINE, 1600.0, 0.0, 1.0, 0.52)
	_add_piano(_arps(prog, 2, 0.5, [0, 1, 2, 3], 0.054, 12), spb, 2.2, 0.32, 1.0, 0.16, rng)
	_add_wave(_bass(prog, 2, [0.0, 2.0], 1.9, 0.20), spb, W_TRI, 400.0, 0.0, 1.0, 0.0)
	_add_piano(MEL_HOPE2, spb, 1.8, 0.34, 1.0, -0.12, rng)
	_soft_hats(spb, 8, 0.05)
	_reverb(0.60, 0.66)
	return _finish()

## 极轻的踩镲，只用来点拍子（日常类才用）
func _soft_hats(spb: float, bars: int, amp: float) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 777
	var total := _l.size()
	var y := 0.0
	for bar in bars:
		for j in 8:
			var beat := float(bar * BEATS_PER_BAR) + float(j) * 0.5
			var start := int(round(beat * spb))
			var d := mini(int(0.04 * RATE), total - start)
			if d <= 0:
				continue
			var a := amp if j % 2 == 0 else amp * 0.55
			for i in d:
				var t := float(i) / RATE
				var n := rng.randf_range(-1.0, 1.0)
				y += 0.55 * (n - y)
				var s := (n - y) * exp(-t * 85.0) * a
				_l[start + i] += s
				_r[start + i] += s

func render_track(id: String) -> PackedFloat32Array:
	if id == "gal_daily":
		return _gal_daily()
	if id == "gal_light":
		return _gal_light()
	if id == "gal_bittersweet":
		return _gal_bittersweet()
	if id == "gal_memory":
		return _gal_memory()
	if id == "gal_tension":
		return _gal_tension()
	if id == "gal_hope":
		return _gal_hope()
	if id == "gal_daily2":
		return _gal_daily2()
	if id == "gal_light2":
		return _gal_light2()
	if id == "gal_title2":
		return _gal_title2()
	if id == "gal_memory2":
		return _gal_memory2()
	if id == "gal_tension2":
		return _gal_tension2()
	if id == "gal_hope2":
		return _gal_hope2()
	return PackedFloat32Array()

func write_track(id: String) -> Dictionary:
	var stereo := render_track(id)
	if stereo.is_empty():
		return {"id": id, "ok": false, "error": "unknown track"}
	var wav := to_wav(stereo)
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
		"seconds": round(float(stereo.size() / 2) / float(RATE) * 100.0) / 100.0,
	}
