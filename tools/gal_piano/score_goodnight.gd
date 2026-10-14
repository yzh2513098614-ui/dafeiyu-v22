extends RefCounted
## 《晚安，鲸落港》—— 手写 32 小节原创 gal 风格钢琴独奏。
##
## 与 score.gd（「夕照，未寄出的信」）同一套做法：和声用拍号写成表，
## 旋律逐小节手写并以 assert 保证每句正好四拍；右手分解和弦只做织体，
## 声部走向由左手根音与旋律线决定。全部原创。
##
## 曲式（♩=68，4/4，A♭ 大调）：
##   引子   0–3   A♭maj9 长音铺底，右手单音，像港口的灯一盏盏亮起来
##   主题 A 4–11  | A♭ | Fm7 | B♭m7 | E♭7 | A♭ | Fm7 | Gm7 | A♭add9 |
##   回忆 A′ 12–19 同一条旋律落在关系小调上：| Fm7 | B♭m7 | E♭7 | A♭ | D♭maj7 | B♭m7 | Gm7 | C7 |
##   心绪 B 20–27 音区抬高、织体变密，终止在 E♭7 上悬住
##   尾声   28–31 回到 A♭，旋律沉回低音，最后一个 A♭ 长鸣接回循环起点
##
## 为什么是 A♭：黑键多的调在钢琴上有天然的柔和度，也留出足够的低音区
## 给左手根音；曲终落在 A♭3（56）而不是高音，是「晚安」而不是「再见」。

const TITLE := "晚安，鲸落港"
const ID := "gal_goodnight"
const BPM := 68.0
const BARS := 32
const SEED := 20261014

const SECTIONS := [
	{"name": "引子", "start": 0, "end": 4},
	{"name": "主题 A", "start": 4, "end": 12},
	{"name": "回忆 A′", "start": 12, "end": 20},
	{"name": "心绪 B", "start": 20, "end": 28},
	{"name": "尾声", "start": 28, "end": 32},
]

## [和弦名, 左手根音 MIDI, 右手四音排列]
const H := {
	"Ab": ["Abmaj9", 32, [60, 63, 67, 70]],
	"Ab9": ["Ab(add9)", 32, [60, 63, 68, 70]],
	"Fm": ["Fm7", 29, [56, 63, 68, 72]],
	"Bm": ["Bbm7", 34, [62, 65, 68, 70]],
	"Eb": ["Eb7", 39, [55, 58, 61, 63]],
	"Ebs": ["Ebm9", 39, [54, 58, 61, 65]],
	"Gs": ["Gm7", 31, [58, 62, 65, 67]],
	"Db": ["Dbmaj7", 37, [60, 65, 68, 72]],
	"C7": ["C7", 36, [64, 67, 70, 72]],
	"AbE": ["Ab/Eb", 39, [56, 60, 63, 68]],
}

## 每小节换一个和弦。
const FORM := ["Ab", "Ab", "Fm", "Ebs", "Ab", "Fm", "Bm", "Eb", "Ab", "Fm", "Gs", "Ab9",
	"Fm", "Bm", "Eb", "Ab", "Db", "Bm", "Gs", "C7", "Fm", "Gs", "Ab", "Bm",
	"Fm", "Gs", "Ab9", "Eb", "Ab9", "Fm", "Bm", "AbE"]

## 织体：0 = 全音符长音，1 = 八分分解，2 = 滚动的十六分织体（心绪段）。
const TEXTURE := [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 0]

## 右手分解的顺序。
const FIGURE := {
	1: [0, 1, 2, 1, 3, 1, 2, 1],
	2: [0, 2, 1, 3, 2, 1, 3, 2],
}

# 旋律：每行是 [MIDI 音高, 时值（拍）]，-1 是休止。每小节合计必须等于四拍。
const INTRO := [
	[[-1, 2.0], [63, 1.0], [65, 1.0]],
	[[68, 1.5], [-1, 0.5], [70, 1.0], [72, 1.0]],
	[[75, 2.0], [72, 1.0], [-1, 1.0]],
	[[70, 1.0], [68, 1.0], [-1, 2.0]],
]
const THEME := [
	[[-1, 0.5], [68, 0.5], [70, 0.5], [72, 0.5], [75, 1.5], [-1, 0.5]],
	[[77, 1.0], [75, 0.5], [72, 0.5], [70, 1.5], [-1, 0.5]],
	[[72, 0.75], [75, 0.75], [77, 0.5], [75, 1.0], [72, 1.0]],
	[[73, 1.0], [75, 1.0], [79, 1.5], [-1, 0.5]],
	[[80, 2.0], [77, 1.0], [75, 1.0]],
	[[77, 0.75], [75, 0.25], [72, 1.0], [68, 1.0], [65, 1.0]],
	[[67, 1.0], [70, 1.0], [75, 1.5], [72, 0.5]],
	[[75, 1.0], [72, 1.0], [70, 1.5], [-1, 0.5]],
]
## 回忆段：主题的同头变奏，句尾往下走而不是往上抬。
const MEMORY := [
	[[-1, 0.5], [65, 0.5], [68, 0.5], [70, 0.5], [72, 1.5], [-1, 0.5]],
	[[75, 1.0], [72, 0.5], [70, 0.5], [68, 1.5], [-1, 0.5]],
	[[70, 0.75], [72, 0.75], [75, 0.5], [80, 1.5], [79, 0.5]],
	[[77, 2.5], [75, 0.5], [72, 1.0]],
	[[73, 1.0], [77, 1.0], [80, 1.5], [77, 0.5]],
	[[75, 1.0], [72, 0.5], [70, 0.5], [68, 2.0]],
	[[70, 1.0], [72, 1.0], [75, 1.0], [79, 1.0]],
	[[77, 1.5], [72, 1.0], [70, 1.5]],
]
## 心绪段：整曲最高点在 22–23 小节（B♭5、C6），之后一路回落。
const FEELING := [
	[[80, 1.0], [77, 0.5], [75, 0.5], [72, 1.5], [70, 0.5]],
	[[75, 1.0], [77, 1.0], [79, 1.0], [80, 1.0]],
	[[83, 2.0], [80, 1.0], [77, 1.0]],
	[[85, 1.0], [83, 1.0], [80, 1.5], [79, 0.5]],
	[[80, 1.5], [77, 0.5], [75, 1.0], [72, 1.0]],
	[[75, 0.75], [77, 0.75], [79, 0.5], [80, 1.0], [77, 1.0]],
	[[80, 1.5], [77, 1.0], [75, 1.5]],
	[[73, 1.0], [75, 1.0], [77, 1.0], [79, 1.0]],
]
const CODA := [
	[[80, 1.5], [77, 1.0], [75, 1.5]],
	[[72, 1.0], [70, 1.0], [68, 2.0]],
	[[70, 1.0], [68, 1.0], [65, 2.0]],
	[[61, 2.0], [56, 2.0]],
]


static func build() -> Dictionary:
	var notes: Array = []
	var bars: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var start_sec := 0.22
	for bar in range(BARS):
		var tempo := _tempo(bar)
		var spb := 60.0 / tempo
		# 乐句换气：句尾小节稍稍拖一点（与 score.gd 同一手法）
		if bar in [3, 7, 11, 15, 19, 23, 27]:
			spb *= 1.03
		var chord: Array = H[FORM[bar]]
		var texture := int(TEXTURE[bar])
		var level := _level(bar)
		bars.append({"bar": bar + 1, "beat": bar * 4, "time": start_sec,
			"duration": 4.0 * spb, "chord": chord[0], "bpm": tempo})

		# --- 左手 ---
		var bass := int(chord[1])
		if texture == 2:
			# 心绪段：根音 + 五音的八分脉动，把低频撑住
			for k in range(4):
				var pitch := bass if k % 2 == 0 else _fifth(bass)
				_add(notes, pitch, start_sec + k * spb, 1.05 * spb,
					level - 16.0 + (2.0 if k % 2 == 0 else 0.0), "bass", bar * 4.0 + float(k), rng)
		else:
			_add(notes, bass, start_sec, 3.8 * spb, level - 14.0, "bass", bar * 4.0, rng)
			if texture == 1 and bar % 2 == 1:
				_add(notes, _fifth(bass), start_sec + 2.0 * spb, 1.7 * spb,
					level - 20.0, "bass", bar * 4.0 + 2.0, rng)

		# --- 右手分解 ---
		var voicing: Array = chord[2]
		if texture == 0:
			for k in range(4):
				_add(notes, int(voicing[k]), start_sec + k * 1.0 * spb + 0.014,
					3.4 * spb, level - 12.0 - k, "arpeggio", bar * 4.0 + float(k), rng)
		else:
			var figure: Array = FIGURE[texture]
			for k in range(figure.size()):
				var pitch := int(voicing[int(figure[k])])
				var accent := 2.0 if k % 4 == 0 else -2.5
				if texture == 2 and k % 2 == 1:
					accent -= 2.0
				_add(notes, pitch, start_sec + k * 0.5 * spb + 0.012,
					0.66 * spb, level + accent, "arpeggio", bar * 4.0 + k * 0.5, rng)

		# --- 旋律 ---
		var rows: Array
		var voice := 0.0
		if bar < 4:
			rows = INTRO[bar]
			voice = 58.0
		elif bar < 12:
			rows = THEME[bar - 4]
			voice = 72.0
		elif bar < 20:
			rows = MEMORY[bar - 12]
			voice = 75.0
		elif bar < 28:
			rows = FEELING[bar - 20]
			voice = 84.0 if bar < 24 else 79.0
		else:
			rows = CODA[bar - 28]
			voice = 62.0 - (bar - 28) * 3.0
		_phrase(notes, rows, bar, start_sec, spb, voice, rng)

		# 最后一小节下方加一个极轻的 A♭ 踏板音，让它自己鸣到自然消失 ——
		# 循环点于是落在「又一个夜晚」的引子上，而不是硬切。
		if bar == BARS - 1:
			_add(notes, 32, start_sec, 7.5 * spb, 36.0, "bass", float(bar * 4), rng)

		start_sec += 4.0 * spb

	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	# 尾音 3.8 秒：最后的 A♭ 鸣到 −58 dB 上下才进 0.55 秒淡出，听不见截断。
	# 比 score.gd 的 4.2 秒短一点是有意的 —— MusicDirector 强制整段循环，
	# 尾部每少一秒空洞，循环点就少一秒「唱片停了」的感觉。
	return {"id": ID, "title": TITLE, "use": "夜晚 / 回忆 / 通关", "key": "A♭ 大调",
		"bpm": BPM, "beats_per_bar": 4, "bar_count": BARS, "seed": SEED,
		"sections": SECTIONS, "bars": bars, "notes": notes,
		"music_duration": start_sec, "duration": start_sec + 3.8,
		"room_wet": 0.30}


## 速度布局：整曲 68，尾声逐层放慢（rit.），最后四拍像道晚安。
static func _tempo(bar: int) -> float:
	if bar >= 31:
		return 56.0
	if bar >= 30:
		return 60.0
	if bar >= 29:
		return 64.0
	return BPM


## 力度布局：引子最轻，主题中性，回忆略暖，心绪最响，尾声收回。
static func _level(bar: int) -> float:
	if bar < 4:
		return 40.0
	if bar < 12:
		return 50.0
	if bar < 20:
		return 54.0
	if bar < 28:
		return 60.0
	return 42.0


static func _fifth(root_midi: int) -> int:
	return root_midi + 7


static func _phrase(notes: Array, rows: Array, bar: int, start: float,
		spb: float, velocity: float, rng: RandomNumberGenerator) -> void:
	var beat := 0.0
	for row: Array in rows:
		var pitch := int(row[0])
		var length := float(row[1])
		if pitch >= 0:
			# 乐句内的拱形：拍位越靠后越推，过三拍后收一点
			var shaping := 2.5 * sin(beat * PI / 4.0) - (2.0 if beat >= 3.0 else 0.0)
			_add(notes, pitch, start + beat * spb, length * spb * 0.94,
				velocity + shaping, "melody", bar * 4.0 + beat, rng)
		beat += length
	assert(is_equal_approx(beat, 4.0), "旋律小节 %d 必须正好四拍（实得 %s）" % [bar, str(beat)])


static func _add(notes: Array, midi: int, time: float, duration: float,
		velocity: float, role: String, beat: float, rng: RandomNumberGenerator) -> void:
	notes.append({
		"midi": midi,
		"time": maxf(0.0, time + rng.randf_range(-0.006, 0.006)),
		"duration": duration,
		"velocity": clampf(velocity + rng.randf_range(-2.0, 2.0), 18.0, 100.0),
		"role": role,
		"beat": beat,
	})


## 8 小节主题试听片段（与 score.gd 的 preview 同一用法）。
static func preview(full: Dictionary) -> Dictionary:
	var bars: Array = full.bars
	var begin := float(bars[4].time)
	var finish := float(bars[12].time)
	var notes: Array = []
	for original: Dictionary in full.notes:
		if original.time >= begin - 0.02 and original.time < finish - 0.02:
			var n := original.duplicate()
			n.time = maxf(0.04, float(n.time) - begin + 0.16)
			notes.append(n)
	return {"id": ID + "_preview", "title": TITLE + " · 8 小节主题", "notes": notes,
		"duration": finish - begin + 4.0, "bar_count": 8, "bpm": BPM}
