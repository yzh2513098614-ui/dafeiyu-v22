extends RefCounted
## 《灯塔替我记得 · 音乐盒变奏》 —— 主题、发展部与和声骨架取自 tools/gal_piano 的 gal_piano_night
## （原曲 D# 小调；原素材按 A 小调记谱，这里同样 +6 移调，所以两句旋律与原曲逐音对应），
## 编曲全部重写：音乐盒主奏 + 弦乐垫 + 钢琴低音 / 八度齐奏 / 高音加花。
##
## 40 小节 · 80 BPM · 4/4，五段（每段 8 小节，段内第 k 小节用主题第 k 句 + 和声第 k 个和弦，
## 与原曲的「逐句换和弦」对位一致）：
##   0–7   主题    音乐盒独奏，钢琴只给每小节一个低音
##   8–15  变奏一  弦乐垫与钢琴分解和弦进场
##   16–23 变奏二  发展部：音乐盒奏发展旋律，钢琴低八度齐奏
##   24–31 变奏三  高潮：主奏交给钢琴，音乐盒上方八度点缀 + 高音加花，垫最厚
##   32–39 尾声    主题逐句回收、力度递减，属和弦后收束到主音（属 → 主），接回开头的独奏

const Theory := preload("res://tools/bgm_glasshouse/theory.gd")

const SHIFT := 6          ## 原曲素材的移调量（A 小调 → D# 小调）
const BPM := 80.0
const BARS := 40
const SEED := 20261014

## 原曲和声（A 小调记谱）：[名称, 低音, 内声部]
const HARMONY := [
	["Am9", 33, [45, 52, 59, 60]],
	["Fmaj7", 41, [53, 57, 60, 64]],
	["Cmaj9", 36, [48, 55, 59, 62]],
	["G6", 43, [55, 59, 62, 64]],
	["Dm7", 38, [50, 57, 60, 65]],
	["Am/E", 40, [52, 57, 60, 64]],
	["Fadd9", 41, [53, 57, 60, 67]],
	["E7", 40, [52, 56, 59, 62]],
]

## 主题（8 句，每句一小节四拍）—— 与 gal_piano_night 的 theme 完全一致
const THEME := [
	"A4:1 E5:0.5 C5:0.5 B4:1 A4:0.5 R:0.5",
	"C5:0.75 A4:0.25 G4:1 E4:0.5 F4:0.5 A4:1",
	"G4:0.5 C5:0.5 E5:1 D5:0.75 B4:0.25 C5:1",
	"B4:1 D5:0.5 G5:0.5 F5:0.5 D5:0.5 B4:1",
	"A4:1 F5:0.5 E5:0.5 D5:1 C5:0.5 A4:0.5",
	"B4:0.75 C5:0.25 E5:1 C5:0.5 A4:0.5 E4:1",
	"A4:0.5 C5:0.5 G5:1 E5:1 C5:1",
	"B4:1 G#4:0.5 E4:0.5 B4:1 G#4:0.5 R:0.5",
]

## 发展部（8 句）—— 与 gal_piano_night 的 development 完全一致
const DEVELOPMENT := [
	"E5:1 A5:0.5 G5:0.5 E5:0.75 C5:0.25 B4:1",
	"A4:0.5 C5:0.5 E5:1 G5:0.75 E5:0.25 C5:1",
	"G5:1 E5:0.5 D5:0.5 C5:1 B4:1",
	"D5:0.5 G5:0.5 B5:1 A5:0.5 G5:0.5 D5:1",
	"A5:1 G5:0.5 F5:0.5 E5:1 D5:1",
	"E5:0.75 C5:0.25 B4:1 A4:0.5 C5:0.5 E5:1",
	"C5:1 A4:0.5 G4:0.5 F4:1 A4:1",
	"G#4:1 B4:0.5 D5:0.5 B4:1 E4:0.5 R:0.5",
]

var ev: Array = []


# ─────────────────────────── 基础写入 ───────────────────────────

func _ev(layer: String, beat: float, m: int, dur: float, vel: float, pan: float) -> void:
	ev.append({"layer": layer, "t": maxf(0.0, beat), "m": m, "d": dur, "v": clampf(vel, 0.02, 1.0), "pan": pan})


## 一小节的和弦（段内第 k 小节 ↔ 第 k 个和弦）。
func _harmony_at(k: int) -> Array:
	return HARMONY[k % HARMONY.size()]


## 铺一句旋律。spec 形如 "A4:1 E5:0.5 C5:0.5"，R 为休止；oct 为八度偏移。
func _phrase(bar: int, spec: String, layer: String, oct: int, vel: float, pan: float) -> void:
	var t := 0.0
	for token in spec.split(" ", false):
		var parts := token.split(":")
		if parts.size() < 2:
			continue
		var name := String(parts[0])
		var dur := float(parts[1])
		if name != "R":
			var m := Theory.midi(name) + SHIFT + oct * 12
			_ev(layer, float(bar * 4) + t, m, dur * 0.94, vel, pan)
		t += dur


## 钢琴低音：小节头一个根音长音。
func _bass(bar: int, m: int, dur: float, vel: float) -> void:
	_ev("piano", float(bar * 4), m, dur, vel, -0.42)


## 弦乐垫：一小节一个和弦，内声部左右铺开；起音 0.55 秒、释放 1 秒，彼此交叠。
func _pad(bar: int, ch: Array, vel: float) -> void:
	var notes: Array = []
	for m in ch[2]:
		notes.append(int(m) + SHIFT)
	var n := notes.size()
	for i in n:
		var pan := 0.0
		if n > 1:
			pan = clampf(float(i) / float(n - 1) * 1.3 - 0.65, -0.65, 0.65)
		_ev("pad", float(bar * 4), int(notes[i]), 4.1, vel, pan)


## 钢琴分解和弦：每小节 count 个音，上下来回，音区越高越靠右。
func _arp(bar: int, ch: Array, count: int, vel: float, pan_lo: float, pan_hi: float) -> void:
	var notes: Array = []
	for m in ch[2]:
		notes.append(int(m) + SHIFT)
	var n := notes.size()
	if n < 2:
		return
	var order: Array = [0, 1, 2, 1, 3, 2, 1, 2] if count == 8 else [0, 1, 2, 1]
	var span := float(maxi(1, n - 1))
	for k in count:
		var idx: int = int(order[k % order.size()]) % n
		var pan := lerpf(pan_lo, pan_hi, float(idx) / span)
		_ev("piano", float(bar * 4) + float(k) * 4.0 / float(count), int(notes[idx]), (4.0 / float(count)) * 0.7, vel, pan)


## 高音加花：用和弦内声部升两个八度，落在反拍。
func _ornament(bar: int, ch: Array, count: int, vel: float) -> void:
	var voices: Array = ch[2]
	var n := voices.size()
	if n < 2:
		return
	var idxs: Array = [3, 2, 1, 2]
	for k in count:
		var m: int = int(voices[int(idxs[k % idxs.size()]) % n]) + SHIFT + 24
		while m > 96:
			m -= 12
		_ev("mb", float(bar * 4) + float(k) * 0.5 + 0.5, m, 0.36, vel, -0.25)


## 人性化：±13 ms 时值抖动 + ±6% 力度抖动。
func _humanize(seed_value: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	for e in ev:
		e["t"] = maxf(0.0, float(e["t"]) + r.randf_range(-0.013, 0.013))
		e["v"] = clampf(float(e["v"]) * r.randf_range(0.94, 1.06), 0.02, 1.0)


# ─────────────────────────── 五段 ───────────────────────────

## 0–7 主题：音乐盒独奏。
func _section_solo(start: int) -> void:
	for k in 8:
		var bar := start + k
		var ch := _harmony_at(k)
		_phrase(bar, THEME[k], "mb", 0, 0.62, 0.15)
		# 音乐盒衰减很快，低音每小节托一次，别让它掉进静音
		_bass(bar, int(ch[1]) + SHIFT, 3.6, 0.24)
		if k >= 4:
			_pad(bar, ch, 0.13)


## 8–15 变奏一：弦乐垫与分解和弦进场。
func _section_pad(start: int) -> void:
	for k in 8:
		var bar := start + k
		var ch := _harmony_at(k)
		_phrase(bar, THEME[k], "mb", 0, 0.66, 0.15)
		_bass(bar, int(ch[1]) + SHIFT, 3.6, 0.32)
		_pad(bar, ch, 0.30)
		_arp(bar, ch, 4, 0.21, -0.30, 0.05)


## 16–23 变奏二：发展部，音乐盒奏旋律、钢琴低八度齐奏。
func _section_develop(start: int) -> void:
	for k in 8:
		var bar := start + k
		var ch := _harmony_at(k)
		_phrase(bar, DEVELOPMENT[k], "mb", 0, 0.70, 0.18)
		_phrase(bar, DEVELOPMENT[k], "piano", -1, 0.34, -0.20)
		_bass(bar, int(ch[1]) + SHIFT, 3.6, 0.36)
		_pad(bar, ch, 0.36)
		if k % 2 == 1:
			_ornament(bar, ch, 2, 0.20)


## 24–31 变奏三：高潮，主奏交给钢琴，音乐盒上方八度点缀。
func _section_climax(start: int) -> void:
	for k in 8:
		var bar := start + k
		var ch := _harmony_at(k)
		_phrase(bar, THEME[k], "piano", -1, 0.46, -0.12)
		_phrase(bar, THEME[k], "mb", 0, 0.40, 0.22)
		_bass(bar, int(ch[1]) + SHIFT, 3.6, 0.42)
		_pad(bar, ch, 0.44)
		_arp(bar, ch, 4, 0.18, -0.35, 0.0)
		_ornament(bar, ch, 2, 0.18)


## 32–39 尾声：逐句回收、力度递减，属和弦收束到主音。
func _section_coda(start: int) -> void:
	for k in 6:
		var bar := start + k
		var ch := _harmony_at(k)
		_phrase(bar, THEME[k], "mb", 0, 0.58 - 0.05 * float(k), 0.15)
		_bass(bar, int(ch[1]) + SHIFT, 3.6, 0.26)
		_pad(bar, ch, 0.22)
	# 属和弦（主题第 8 句落在属音上）
	var bar_dom := start + 6
	var ch_dom := _harmony_at(7)
	_phrase(bar_dom, THEME[7], "mb", 0, 0.50, 0.15)
	_bass(bar_dom, int(ch_dom[1]) + SHIFT, 3.6, 0.26)
	_pad(bar_dom, ch_dom, 0.22)
	# 主音收束：垫 + 音乐盒滚奏主和弦
	var bar_end := start + 7
	var tonic := int(HARMONY[0][1]) + SHIFT          # D#2
	_pad(bar_end, HARMONY[0], 0.30)
	_bass(bar_end, tonic, 3.8, 0.30)
	var triad: Array = [0, 3, 7]
	for i in 3:
		_ev("mb", float(bar_end * 4) + float(i) * 0.14, tonic + 36 + int(triad[i]), 3.6, 0.40 - 0.04 * float(i), 0.15 - 0.10 * float(i))


# ─────────────────────────── 汇总 ───────────────────────────

func build() -> Dictionary:
	ev = []
	_section_solo(0)
	_section_pad(8)
	_section_develop(16)
	_section_climax(24)
	_section_coda(32)
	_humanize(SEED)
	return {
		"key": "lighthouse_musicbox",
		"title": "灯塔，音乐盒变奏",
		"bpm": BPM,
		"time_sig": "4/4",
		"bars": BARS,
		"seed": SEED,
		"events": ev,
	}
