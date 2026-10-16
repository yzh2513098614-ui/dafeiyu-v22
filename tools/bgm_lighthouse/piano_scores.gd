extends RefCounted
## 《灯塔替我记得 · 钢琴变奏》—— 手写 48 小节钢琴独奏（主题 + 四个变奏 + 尾声）。
##
## 主题与发展部逐音复用 tools/gal_piano 的 gal_piano_night（原曲 A 小调记谱，这里同样 +6 移到
## D# 小调），和声骨架也用原曲那 8 个和弦的移调；变奏是「同一句主题的四种迭代」：
##
##   主题    0–7   原样：右手旋律 + 每拍一个和弦音（力度 50）
##   变奏一  8–15  流动：右手改八分分解，左手根音 + 五音脉动（力度 54）
##   变奏二  16–23 低语：**旋律整个交给左手低八度**，右手在上方分解（力度 52）
##   变奏三  24–31 涌动：换发展部素材，右手十六分滚动织体 + 每四拍重音（力度 62）
##   变奏四  32–39 辽阔：主题回到右手并加高八度齐奏，左手脉动（力度 68，全曲高潮）
##   尾声    40–47 主题逐句回收、渐弱，V→i 收束，最后 D# 长音接回循环
##
## 每小节的和弦与旋律句索引都取自同一个 k = bar % 8，与原曲「逐句换和弦」的对位一致。
## 曲终落在 D#5 长音（75）而不是更高：是「我记得」，不是「再大声一点」。

const TITLE := "灯塔替我记得 · 钢琴变奏"
const ID := "lighthouse_piano_var"
const BPM := 80.0
const BARS := 48
const SEED := 20261015

const SECTIONS := [
	{"name": "主题", "start": 0, "end": 8},
	{"name": "变奏一 · 流动", "start": 8, "end": 16},
	{"name": "变奏二 · 低语", "start": 16, "end": 24},
	{"name": "变奏三 · 涌动", "start": 24, "end": 32},
	{"name": "变奏四 · 辽阔", "start": 32, "end": 40},
	{"name": "尾声", "start": 40, "end": 48},
]

## 原曲和声（A 小调记谱 +6 后的实际音高）：[名称, 左手根音, 右手四音排列]
## 逐条对应原曲 gal_piano_night 的 minor 阵列：Am9 / Fmaj7 / Cmaj9 / G6 / Dm7 / Am-E / Fadd9 / E7。
const H := {
	"i9": ["D#m9", 39, [51, 58, 65, 66]],
	"VI": ["Bmaj7", 47, [59, 63, 66, 70]],
	"III": ["F#maj9", 42, [54, 61, 65, 68]],
	"VII": ["C#7", 49, [61, 65, 68, 70]],
	"iv": ["G#m7", 44, [56, 63, 66, 71]],
	"i5": ["D#m/A#", 46, [58, 63, 66, 70]],
	"VIa": ["Badd9", 47, [59, 63, 66, 73]],
	"V": ["A#7", 46, [58, 62, 65, 68]],
}

## 每小节一个和弦，8 个为一轮。
const FORM := ["i9", "VI", "III", "VII", "iv", "i5", "VIa", "V"]

## 织体：0 = 每拍一个和弦音 + 根音长音，1 = 八分分解 + 根音/五音，2 = 十六分滚动。
const TEXTURE := [
	0, 0, 0, 0, 0, 0, 0, 0,
	1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1,
	2, 2, 2, 2, 2, 2, 2, 2,
	1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 0, 0, 0, 0,
]

## 右手分解顺序（八分 / 十六分）。
const FIGURE := {
	1: [0, 1, 2, 1, 3, 1, 2, 1],
	2: [0, 2, 1, 3, 2, 1, 3, 2, 0, 2, 3, 1, 2, 3, 1, 2],
}

## 主题：8 句，每句正好四拍（原曲 gal_piano_night 的 theme，+6 后的 MIDI）。
const THEME := [
	[[75, 1.0], [82, 0.5], [78, 0.5], [77, 1.0], [75, 0.5], [-1, 0.5]],
	[[78, 0.75], [75, 0.25], [73, 1.0], [70, 0.5], [71, 0.5], [75, 1.0]],
	[[73, 0.5], [78, 0.5], [82, 1.0], [80, 0.75], [77, 0.25], [78, 1.0]],
	[[77, 1.0], [80, 0.5], [85, 0.5], [83, 0.5], [80, 0.5], [77, 1.0]],
	[[75, 1.0], [83, 0.5], [82, 0.5], [80, 1.0], [78, 0.5], [75, 0.5]],
	[[77, 0.75], [78, 0.25], [82, 1.0], [78, 0.5], [75, 0.5], [70, 1.0]],
	[[75, 0.5], [78, 0.5], [85, 1.0], [82, 1.0], [78, 1.0]],
	[[77, 1.0], [74, 0.5], [70, 0.5], [77, 1.0], [74, 0.5], [-1, 0.5]],
]

## 发展部：8 句（原曲 gal_piano_night 的 development，+6）。变奏三用它，音区比主题更宽。
const DEVELOPMENT := [
	[[82, 1.0], [87, 0.5], [85, 0.5], [82, 0.75], [78, 0.25], [77, 1.0]],
	[[75, 0.5], [78, 0.5], [82, 1.0], [85, 0.75], [82, 0.25], [78, 1.0]],
	[[85, 1.0], [82, 0.5], [80, 0.5], [78, 1.0], [77, 1.0]],
	[[80, 0.5], [85, 0.5], [89, 1.0], [87, 0.5], [85, 0.5], [80, 1.0]],
	[[87, 1.0], [85, 0.5], [83, 0.5], [82, 1.0], [80, 1.0]],
	[[82, 0.75], [78, 0.25], [77, 1.0], [75, 0.5], [78, 0.5], [82, 1.0]],
	[[78, 1.0], [75, 0.5], [73, 0.5], [71, 1.0], [75, 1.0]],
	[[74, 1.0], [77, 0.5], [80, 0.5], [77, 1.0], [70, 0.5], [-1, 0.5]],
]

## 尾声的收束句：46 小节从 A#7 的音一路下行落到主音，47 小节主音长音。
const CADENCE := [[73, 1.0], [71, 0.5], [68, 0.5], [66, 1.0], [63, 1.0]]
const FINAL := [[75, 4.0]]


static func build() -> Dictionary:
	var notes: Array = []
	var bars: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var start_sec := 0.22
	for bar in range(BARS):
		var k := bar % 8
		var chord: Array = H[FORM[k]]
		var tempo := _tempo(bar)
		var spb := 60.0 / tempo
		var level := _level(bar)
		var texture := int(TEXTURE[bar])
		bars.append({"bar": bar + 1, "beat": bar * 4, "time": start_sec,
			"duration": 4.0 * spb, "chord": String(chord[0]), "bpm": tempo})

		# --- 左手 ---
		if bar >= 16 and bar < 24:
			# 变奏二：主奏换手。旋律降到左手低八度，右手只在上方分解，不再唱主句。
			_phrase(notes, _melody(bar), bar, start_sec, spb, level - 8.0, rng, -12)
			_bass(notes, chord, bar, start_sec, spb, level, rng, 0)
			_arp(notes, chord, bar, start_sec, spb, level - 4.0, rng, 1)
		else:
			_bass(notes, chord, bar, start_sec, spb, level, rng, _bass_mode(bar))
			_arp(notes, chord, bar, start_sec, spb, level, rng, texture)
			_phrase(notes, _melody(bar), bar, start_sec, spb, level + 6.0, rng)
			if bar >= 32 and bar < 40:
				# 变奏四：主题加高八度齐奏，只做厚度，力度压 9 不抢轮廓。
				_phrase(notes, _melody(bar), bar, start_sec, spb, level - 9.0, rng, 12)

		if bar == BARS - 1:
			# 最后一小节下方留一个极轻的 D#2 踏板音，让它自己鸣到淡出 ——
			# 循环点落在「又一个夜晚」的引子上，而不是硬切。
			_add(notes, 39, start_sec, 7.0 * spb, 40.0, "bass", float(bar * 4), rng)

		start_sec += 4.0 * spb

	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	# 尾长只留「最后长音的释放段 + 合成器自带的 0.55 s 淡出」：gal_piano 的默认尾巴是
	# music_duration + 3.6 秒，原曲 gal_piano_night 因此结尾有 2.45 秒静音（实测），
	# 而 MusicDirector 是整段循环，每循环都会听见这段空白 —— 迭代 6 收到 +1.2。
	return {"id": ID, "title": TITLE, "use": "夜晚 / 回忆（钢琴变奏）", "key": "D# 小调",
		"bpm": BPM, "beats_per_bar": 4, "bar_count": BARS, "seed": SEED,
		"sections": SECTIONS, "bars": bars, "notes": notes,
		"music_duration": start_sec, "duration": start_sec + 1.2, "room_wet": 0.30}


## 每小节的旋律句：变奏三换成发展部，尾声 44–45 走主题第 7、8 句，46–47 是收束。
static func _melody(bar: int) -> Array:
	if bar < 8:
		return THEME[bar]
	if bar < 16:
		return THEME[bar - 8]
	if bar < 24:
		return THEME[bar - 16]
	if bar < 32:
		return DEVELOPMENT[bar - 24]
	if bar < 40:
		return THEME[bar - 32]
	if bar < 44:
		return THEME[bar - 40]
	if bar == 44:
		return THEME[6]
	if bar == 45:
		return THEME[7]
	if bar == 46:
		return CADENCE
	return FINAL


## 左手低音形态：0 = 整小节根音长音，1 = 根音 + 后半五音，2 = 每拍根音（变奏三的涌动）。
static func _bass_mode(bar: int) -> int:
	if bar < 8:
		return 0
	if bar >= 24 and bar < 32:
		return 2
	return 1


## 力度布局（定稿）：主题 44 → 流动 54 → 低语 42 → 涌动 68 → 辽阔 84（高潮）→ 尾声 44 逐句收到 22。
## 迭代过程记账：迭代 1–3 的分段统计把 SECTIONS 的**小节号当秒**用，量的是错位窗口，
## 「尾声比高潮还响」是假象；迭代 4 修了换算之后才看到真实弧线是
## −28.9 → −22.9 → −30.6 → −19.4 → −16.1 → −28.2（已经可用）。
## 迭代 5 据此把首段与尾声各收 4、变奏一压 4，让「主题最轻、低语最静、辽阔最响」三段的关系更干净。
static func _level(bar: int) -> float:
	if bar < 8:
		return 44.0
	if bar < 16:
		return 54.0
	if bar < 24:
		return 42.0
	if bar < 32:
		return 68.0
	if bar < 40:
		return 84.0
	if bar < 44:
		return 44.0
	return 44.0 - 6.0 * float(bar - 43)


## 速度布局：整曲 80，最后三小节放慢，像把灯一盏盏关掉。
static func _tempo(bar: int) -> float:
	if bar >= 47:
		return 66.0
	if bar >= 46:
		return 72.0
	if bar >= 45:
		return 76.0
	return BPM


## 左手：根音长音；mode 1/2 时在后半加五音，2 时每拍砸根音。
static func _bass(notes: Array, chord: Array, bar: int, start: float,
		spb: float, level: float, rng: RandomNumberGenerator, mode: int) -> void:
	var root := int(chord[1])
	var fifth := _fifth(root, String(chord[0]))
	if mode == 0:
		_add(notes, root, start, 3.8 * spb, level - 10.0, "bass", bar * 4.0, rng)
		return
	if mode == 2:
		for k in range(4):
			_add(notes, root if k % 2 == 0 else fifth, start + k * spb, 1.05 * spb,
				level - 12.0 + (2.0 if k % 2 == 0 else 0.0), "bass", bar * 4.0 + k, rng)
		return
	_add(notes, root, start, 3.6 * spb, level - 9.0, "bass", bar * 4.0, rng)
	_add(notes, fifth, start + 2.0 * spb, 1.7 * spb, level - 13.0, "bass", bar * 4.0 + 2, rng)


## 右手织体：0 = 每拍一个和弦音（长音），1/2 = 按 FIGURE 分解。
static func _arp(notes: Array, chord: Array, bar: int, start: float,
		spb: float, level: float, rng: RandomNumberGenerator, texture: int) -> void:
	var voicing: Array = chord[2]
	if texture == 0:
		for k in range(4):
			_add(notes, int(voicing[k]), start + k * spb + 0.014, 3.4 * spb,
				level - 12.0 - k, "arpeggio", bar * 4.0 + k, rng)
		return
	var figure: Array = FIGURE[texture]
	var step := (0.5 if texture == 1 else 0.25)
	for k in range(figure.size()):
		var pitch := int(voicing[int(figure[k])])
		var accent := 2.0 if k % 4 == 0 else -2.0
		_add(notes, pitch, start + k * step * spb + 0.012, 0.66 * spb,
			level - 10.0 + accent, "arpeggio", bar * 4.0 + k * step, rng)


## 铺一句旋律。rows 为 [[MIDI, 时值拍]]，-1 是休止；transpose 为八度偏移。
static func _phrase(notes: Array, rows: Array, bar: int, start: float,
		spb: float, velocity: float, rng: RandomNumberGenerator,
		transpose: int = 0) -> void:
	var beat := 0.0
	for row: Array in rows:
		var pitch := int(row[0])
		var length := float(row[1])
		if pitch >= 0:
			# 乐句内的拱形：拍位越靠后越推，过三拍后收一点
			var shaping := 2.5 * sin(beat * PI / 4.0) - (2.0 if beat >= 3.0 else 0.0)
			_add(notes, pitch + transpose, start + beat * spb, length * spb * 0.94,
				velocity + shaping, "melody", bar * 4.0 + beat, rng)
		beat += length
	assert(is_equal_approx(beat, 4.0), "旋律小节 %d 必须正好四拍（实得 %s）" % [bar, str(beat)])


static func _fifth(root_midi: int, chord_name: String = "") -> int:
	# 半减和弦的五音要跟着和弦走，否则左手会在最响处把色彩抹平。
	return root_midi + (6 if chord_name.ends_with("-5") else 7)


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
