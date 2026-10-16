extends RefCounted
## 《灯塔变奏》六首 —— 给 tools/gal_piano 的六首原创钢琴各做一套钢琴变奏。
##
## 主题、发展部与和声骨架**逐音复用原曲**（`tools/gal_piano/compose_batch.js` 的 recipes），
## 编曲统一成同一套迭代结构，每首按自己原曲的性格取力度与织体：
##
##   主题    0–7   原样陈述，右手旋律 + 每拍一个和弦音
##   变奏一  8–15  流动：右手八分分解（驱动型曲子用十六分）
##   变奏二  16–23 低语：**主奏交给左手低八度**，右手只在上方分解
##   变奏三  24–31 涌动：换发展部素材，十六分滚动 + 每四拍重音
##   变奏四  32–39 辽阔：主题加高八度齐奏 + 左手脉动（全曲高潮）
##   尾声    40–47 主题逐句回收、渐弱，V→i 收束，主音长音接回循环
##
## 每小节的和弦与旋律句都取同一个索引 k = bar % 8，与原曲「逐句换和弦」的对位一致；
## SHIFT 与原曲同值（原曲素材按 C 大调 / A 小调记谱，加 shift 得到原调）。
## 尾长只留 +1.2 秒：gal_piano 默认尾巴是 music_duration + 3.6，原曲尾巴实测有 2 秒级静音。

const BARS := 48

## 原曲和声（C 大调记谱）与（A 小调记谱）。
const MAJOR := [
	["Cadd9", 36, [48, 55, 60, 62]],
	["G/B", 35, [47, 55, 59, 62]],
	["Am7", 33, [45, 52, 55, 60]],
	["Fmaj7", 41, [53, 57, 60, 64]],
	["Dm9", 38, [50, 57, 60, 64]],
	["G6", 43, [55, 59, 62, 64]],
	["C/E", 40, [52, 55, 60, 64]],
	["Gsus-G", 43, [55, 60, 62, 67]],
]
const MINOR := [
	["Am9", 33, [45, 52, 59, 60]],
	["Fmaj7", 41, [53, 57, 60, 64]],
	["Cmaj9", 36, [48, 55, 59, 62]],
	["G6", 43, [55, 59, 62, 64]],
	["Dm7", 38, [50, 57, 60, 65]],
	["Am/E", 40, [52, 57, 60, 64]],
	["Fadd9", 41, [53, 57, 60, 67]],
	["E7", 40, [52, 56, 59, 62]],
]

## 尾声收束句（C 大调与 A 小调记谱），emit 时统一加 shift。
const CADENCE_MAJOR := [[79, 1.0], [76, 0.5], [74, 0.5], [72, 2.0]]
const CADENCE_MINOR := [[76, 1.0], [72, 0.5], [71, 0.5], [69, 2.0]]
const FINAL_MAJOR := [[72, 4.0]]
const FINAL_MINOR := [[69, 4.0]]

## 五条配方：主题 / 发展部与和声骨架取自原曲，level 与 drive 是本变奏的性格。
## level 是主题段的基准力度；drive 为真时，流动段与辽阔段改用十六分驱动织体（紧张的曲子）。
const RECIPES := [
	{
		"id": "lighthouse_daily_var", "title": "海风课间 · 变奏", "use": "原创钢琴变奏 · 主题 + 四变奏 · 日常 / 标题",
		"key": "D 大调", "bpm": 94.0, "shift": 2, "wet": 0.26, "level": 46.0, "drive": false, "minor": false, "seed": 20261021,
		"form": [0, 1, 2, 3, 4, 5, 6, 7],
		"theme": [
			"E5:0.5 G5:0.5 E5:0.75 D5:0.25 C5:1 D5:0.5 E5:0.5",
			"D5:0.75 B4:0.25 G4:0.5 B4:0.5 D5:1 G5:1",
			"E5:0.5 A5:0.5 G5:0.5 E5:0.5 C5:1 B4:0.5 A4:0.5",
			"A4:0.5 C5:0.5 E5:0.75 G5:0.25 E5:1 C5:1",
			"F5:0.5 E5:0.5 D5:0.75 C5:0.25 A4:1 D5:1",
			"B4:0.5 D5:0.5 E5:1 G5:0.75 F5:0.25 D5:1",
			"E5:0.75 G5:0.25 C6:1 B5:0.5 G5:0.5 E5:1",
			"D5:0.5 C5:0.5 B4:1 A4:0.5 B4:0.5 G4:0.5 R:0.5"],
		"development": [
			"G5:0.5 C6:0.5 B5:0.75 G5:0.25 E5:1 G5:1",
			"B5:0.5 A5:0.5 G5:1 F5:0.5 D5:0.5 G5:1",
			"A5:1 C6:0.5 B5:0.5 A5:0.75 G5:0.25 E5:1",
			"A5:0.75 G5:0.25 E5:0.5 C5:0.5 F5:1 E5:1",
			"F5:0.5 A5:0.5 G5:1 F5:0.5 E5:0.5 D5:1",
			"D5:0.5 G5:0.5 B5:1 A5:0.5 G5:0.5 D5:1",
			"E5:1 G5:0.5 E5:0.5 D5:1 C5:1",
			"A4:0.5 B4:0.5 D5:1 C5:0.5 B4:0.5 G4:0.5 R:0.5"],
	},
	{
		"id": "lighthouse_indoor_var", "title": "窗边的热茶 · 变奏", "use": "原创钢琴变奏 · 主题 + 四变奏 · 室内 / 温柔",
		"key": "F 大调", "bpm": 88.0, "shift": 5, "wet": 0.29, "level": 42.0, "drive": false, "minor": false, "seed": 20261022,
		"form": [0, 3, 6, 2, 4, 5, 0, 7],
		"theme": [
			"G4:1 E4:0.5 G4:0.5 C5:1 B4:0.5 G4:0.5",
			"A4:1 G4:0.5 E4:0.5 F4:0.75 A4:0.25 C5:1",
			"G4:0.5 C5:0.5 B4:1 G4:0.5 E4:0.5 G4:1",
			"A4:1 C5:0.5 E5:0.5 D5:0.75 C5:0.25 A4:1",
			"F4:1 A4:0.5 C5:0.5 D5:1 C5:0.5 A4:0.5",
			"B4:0.75 A4:0.25 G4:1 D5:1 B4:1",
			"C5:1 B4:0.5 G4:0.5 E4:1 G4:1",
			"A4:0.5 G4:0.5 D4:1 B4:0.75 A4:0.25 G4:0.5 R:0.5"],
		"development": [
			"E5:1 G5:0.5 E5:0.5 D5:1 C5:1",
			"C5:0.5 E5:0.5 A5:1 G5:0.5 E5:0.5 C5:1",
			"B4:0.5 C5:0.5 E5:1 G5:1 E5:1",
			"E5:0.75 D5:0.25 C5:0.5 A4:0.5 B4:1 C5:1",
			"D5:1 F5:0.5 E5:0.5 D5:0.5 C5:0.5 A4:1",
			"B4:0.5 D5:0.5 G5:1 E5:0.5 D5:0.5 B4:1",
			"C5:1 G4:1 E4:0.5 G4:0.5 C5:1",
			"B4:1 A4:0.5 G4:0.5 D4:1 G4:0.5 R:0.5"],
	},
	{
		"id": "lighthouse_rain_var", "title": "雨声里的约定 · 变奏", "use": "原创钢琴变奏 · 主题 + 四变奏 · 回忆 / 雨夜",
		"key": "A 小调", "bpm": 90.0, "shift": 0, "wet": 0.34, "level": 46.0, "drive": false, "minor": true, "seed": 20261023,
		"form": [0, 2, 1, 3, 4, 5, 6, 7],
		"theme": [
			"E5:0.75 C5:0.25 B4:0.5 A4:0.5 C5:1 E5:1",
			"G5:0.5 E5:0.5 D5:0.75 C5:0.25 B4:1 G4:1",
			"A4:0.75 C5:0.25 E5:1 D5:0.5 C5:0.5 A4:1",
			"D5:0.5 G5:0.5 F5:1 D5:0.75 B4:0.25 G4:1",
			"F5:1 E5:0.5 D5:0.5 C5:1 A4:1",
			"E5:0.75 C5:0.25 A4:0.5 B4:0.5 C5:1 E5:1",
			"G5:1 E5:0.5 C5:0.5 A4:1 C5:1",
			"B4:0.75 G#4:0.25 E4:1 G#4:0.5 B4:0.5 D5:0.5 R:0.5"],
		"development": [
			"A5:1 G5:0.5 E5:0.5 C5:0.5 B4:0.5 A4:1",
			"G5:0.75 E5:0.25 C6:1 B5:0.5 G5:0.5 E5:1",
			"A5:0.5 G5:0.5 E5:1 C5:0.75 A4:0.25 C5:1",
			"B5:1 A5:0.5 G5:0.5 F5:1 D5:1",
			"F5:0.75 E5:0.25 D5:0.5 F5:0.5 A5:1 G5:1",
			"E5:1 C5:0.5 B4:0.5 A4:1 E5:1",
			"C5:0.5 E5:0.5 G5:1 E5:0.75 C5:0.25 A4:1",
			"B4:1 D5:0.5 B4:0.5 G#4:1 E4:0.5 R:0.5"],
	},
	{
		"id": "lighthouse_tension_var", "title": "潮汐之前 · 变奏", "use": "原创钢琴变奏 · 主题 + 四变奏 · 紧张 / 交战",
		"key": "B 小调", "bpm": 108.0, "shift": 2, "wet": 0.20, "level": 52.0, "drive": true, "minor": true, "seed": 20261024,
		"form": [0, 7, 4, 7, 1, 2, 4, 7],
		"theme": [
			"A4:0.5 E5:0.5 B4:0.5 C5:0.5 A4:1 E5:0.5 R:0.5",
			"G#4:0.5 B4:0.5 D5:0.5 E5:0.5 D5:1 B4:0.5 G#4:0.5",
			"A4:0.5 D5:0.5 F5:0.75 E5:0.25 D5:1 A4:1",
			"B4:0.5 G#4:0.5 E4:0.5 G#4:0.5 B4:1 D5:1",
			"A4:0.75 C5:0.25 F5:0.5 E5:0.5 C5:1 A4:1",
			"G4:0.5 C5:0.5 E5:0.5 G5:0.5 E5:1 C5:1",
			"F5:0.5 E5:0.5 D5:1 A4:0.5 C5:0.5 D5:1",
			"D5:0.5 B4:0.5 G#4:0.5 E4:0.5 B4:1 G#4:0.5 R:0.5"],
		"development": [
			"E5:0.5 A5:0.5 G5:0.5 E5:0.5 C5:1 A4:1",
			"B5:0.5 G#5:0.5 E5:0.5 D5:0.5 B4:1 E5:1",
			"F5:0.5 A5:0.5 D6:0.75 C6:0.25 A5:1 F5:1",
			"G#5:0.5 B5:0.5 D6:0.5 B5:0.5 G#5:1 E5:1",
			"A5:1 G5:0.5 F5:0.5 E5:0.5 C5:0.5 A4:1",
			"G5:0.5 E5:0.5 C5:1 B4:0.5 C5:0.5 E5:1",
			"F5:0.75 E5:0.25 D5:0.5 A4:0.5 D5:1 F5:1",
			"D5:0.5 B4:0.5 G#4:1 B4:0.5 D5:0.5 E5:0.5 R:0.5"],
	},
	{
		"id": "lighthouse_hope_var", "title": "明天仍有晴空 · 变奏", "use": "原创钢琴变奏 · 主题 + 四变奏 · 释怀 / 结局",
		"key": "F# 大调", "bpm": 96.0, "shift": 6, "wet": 0.28, "level": 48.0, "drive": false, "minor": false, "seed": 20261025,
		"form": [3, 5, 6, 2, 4, 5, 0, 7],
		"theme": [
			"A4:0.5 C5:0.5 F5:1 E5:0.5 C5:0.5 A4:1",
			"B4:0.5 D5:0.5 G5:0.75 E5:0.25 D5:1 B4:1",
			"G4:0.5 C5:0.5 E5:1 G5:0.5 E5:0.5 C5:1",
			"E5:1 A5:0.5 G5:0.5 E5:0.75 C5:0.25 A4:1",
			"A4:0.5 D5:0.5 F5:1 E5:0.5 D5:0.5 C5:1",
			"B4:0.75 D5:0.25 E5:0.5 G5:0.5 F5:1 D5:1",
			"E5:0.5 G5:0.5 C6:1 B5:0.5 G5:0.5 E5:1",
			"D5:1 B4:0.5 A4:0.5 G4:1 D5:0.5 R:0.5"],
		"development": [
			"C6:1 A5:0.5 G5:0.5 F5:1 E5:1",
			"B5:0.75 A5:0.25 G5:0.5 E5:0.5 D5:1 G5:1",
			"G5:0.5 C6:0.5 B5:1 G5:0.5 E5:0.5 C5:1",
			"A5:1 G5:0.5 E5:0.5 C5:0.5 E5:0.5 A5:1",
			"A5:0.5 G5:0.5 F5:1 E5:0.5 D5:0.5 C5:1",
			"D5:0.5 G5:0.5 B5:1 A5:0.75 G5:0.25 D5:1",
			"E5:1 D5:0.5 C5:0.5 G4:1 C5:1",
			"B4:0.75 A4:0.25 G4:1 D5:1 G4:0.5 R:0.5"],
	},
]


static func build(r: Dictionary) -> Dictionary:
	var notes: Array = []
	var bars: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(r["seed"])
	var shift := int(r["shift"])
	var src: Array = MINOR if bool(r["minor"]) else MAJOR
	var tonic := int(src[0][1]) + shift
	var cadence: Array = CADENCE_MINOR if bool(r["minor"]) else CADENCE_MAJOR
	var final: Array = FINAL_MINOR if bool(r["minor"]) else FINAL_MAJOR
	# 原曲的乐句是记谱字符串（"E5:0.5 G5:0.5 …"），先解析成 [[MIDI, 时值拍]] 再铺。
	var theme: Array = []
	for s in r["theme"]:
		theme.append(_rows(String(s)))
	var dev: Array = []
	for s in r["development"]:
		dev.append(_rows(String(s)))
	var sections: Array = []
	var t := 0.22
	for bar in range(BARS):
		var k := bar % 8
		var ch: Array = src[int(r["form"][k])]
		var tempo := _tempo(r, bar)
		var spb := 60.0 / tempo
		var lv := _level(r, bar)
		var tex := _texture(r, bar)
		var tight := 0.24 if bool(r["drive"]) else 0.5
		var mel: Array = _melody(theme, dev, bar, cadence, final)
		if bar % 8 == 0:
			sections.append({"name": ["主题", "变奏一 · 流动", "变奏二 · 低语", "变奏三 · 涌动", "变奏四 · 辽阔", "尾声"][bar / 8],
				"start": bar, "end": mini(BARS, bar + 8)})
		bars.append({"bar": bar + 1, "beat": bar * 4, "time": t, "duration": 4.0 * spb,
			"chord": String(ch[0]) + " (transpose " + str(shift) + ")", "bpm": tempo})

		if bar >= 16 and bar < 24:
			# 变奏二：主奏换手 —— 旋律降到左手低八度，右手只在上方分解，不再唱主句。
			_phrase(notes, mel, bar, t, spb, lv - 8.0, rng, shift, -12, tight)
			_bass(notes, ch, bar, t, spb, lv, rng, shift, 0, tight)
			_arp(notes, ch, bar, t, spb, lv - 4.0, rng, shift, 1, tight)
		else:
			_bass(notes, ch, bar, t, spb, lv, rng, shift, _bass_mode(bar), tight)
			_arp(notes, ch, bar, t, spb, lv, rng, shift, tex, tight)
			_phrase(notes, mel, bar, t, spb, lv + 6.0, rng, shift, 0, tight)
			if bar >= 32 and bar < 40:
				# 变奏四：主题加高八度齐奏，只做厚度，力度压 9 不抢轮廓。
				_phrase(notes, mel, bar, t, spb, lv - 9.0, rng, shift, 12, tight)

		if bar == BARS - 1:
			# 最后一小节下方留一个极轻的主音踏板音，让它自己鸣到淡出 ——
			# 循环点落在「又一个夜晚」的引子上，而不是硬切。
			_add(notes, tonic, t, 7.0 * spb, 40.0, "bass", float(bar * 4), rng, 0.6)

		t += 4.0 * spb

	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return {"id": r["id"], "title": r["title"], "use": r["use"], "key": r["key"],
		"bpm": float(r["bpm"]), "beats_per_bar": 4, "bar_count": BARS, "seed": int(r["seed"]),
		"sections": sections, "bars": bars, "notes": notes,
		"music_duration": t, "duration": t + 1.2, "room_wet": float(r["wet"])}


## 每小节的旋律句：变奏三换发展部；尾声 44–45 走主题第 7、8 句，46–47 是收束。
static func _melody(theme: Array, dev: Array, bar: int, cadence: Array, final: Array) -> Array:
	if bar < 8:
		return theme[bar]
	if bar < 16:
		return theme[bar - 8]
	if bar < 24:
		return theme[bar - 16]
	if bar < 32:
		return dev[bar - 24]
	if bar < 40:
		return theme[bar - 32]
	if bar < 44:
		return theme[bar - 40]
	if bar == 44:
		return theme[6]
	if bar == 45:
		return theme[7]
	if bar == 46:
		return cadence
	return final


## 把 "E5:0.5 G5:0.5 R:1" 这样的记谱解析成 [[MIDI, 时值拍], …]；R 是休止。
static func _rows(spec: String) -> Array:
	var out: Array = []
	for token in spec.split(" ", false):
		var parts := token.split(":")
		if parts.size() < 2:
			continue
		var name := String(parts[0])
		out.append([-1 if name == "R" else _pitch(name), float(parts[1])])
	return out


## 音名 → MIDI（素材只用 A–G 加 # / b，够用，不必依赖 theory.gd）。
static func _pitch(name: String) -> int:
	var step := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var accidental := {"#": 1, "b": -1}
	var semitone: int = int(step.get(name.substr(0, 1), 0))
	if name.length() > 1 and accidental.has(name.substr(1, 1)):
		semitone += int(accidental[name.substr(1, 1)])
	var octave := int(name.substr(name.length() - 1, 1))
	return (octave + 1) * 12 + semitone


## 力度布局：基准 level + 五段相对偏移（主题 +0 / 流动 +8 / 低语 −2 / 涌动 +16 / 辽阔 +26），尾声逐句收到 −20。
static func _level(r: Dictionary, bar: int) -> float:
	var l := float(r["level"])
	if bar < 8:
		return l
	if bar < 16:
		return l + 8.0
	if bar < 24:
		return l - 2.0
	if bar < 32:
		return l + 16.0
	if bar < 40:
		return l + 26.0
	if bar < 44:
		return l + 8.0
	return l + 8.0 - 7.0 * float(bar - 43)


## 织体：0 = 每拍一个和弦音 + 根音长音，1 = 八分分解，2 = 十六分滚动。
static func _texture(r: Dictionary, bar: int) -> int:
	var driven := bool(r["drive"])
	if bar < 8:
		return 0
	if bar < 16:
		return 2 if driven else 1
	if bar < 24:
		return 1
	if bar < 32:
		return 2
	if bar < 40:
		return 2 if driven else 1
	if bar < 44:
		return 1
	return 0


## 左手低音形态：0 = 整小节根音长音，1 = 根音 + 后半五音，2 = 每拍根音（涌动段与驱动型曲子）。
static func _bass_mode(bar: int) -> int:
	if bar < 8:
		return 0
	if bar >= 24 and bar < 32:
		return 2
	return 1


## 速度布局：整曲用原曲 BPM，最后三小节放慢，像把灯一盏盏关掉。
static func _tempo(r: Dictionary, bar: int) -> float:
	var bpm := float(r["bpm"])
	if bar >= 47:
		return bpm * 0.88
	if bar >= 46:
		return bpm * 0.92
	if bar >= 45:
		return bpm * 0.96
	return bpm


## 右手分解顺序（八分 / 十六分）。
const FIGURE := {
	1: [0, 1, 2, 1, 3, 1, 2, 1],
	2: [0, 2, 1, 3, 2, 1, 3, 2, 0, 2, 3, 1, 2, 3, 1, 2],
}


## 左手：0 = 根音长音；1/2 时在后半加五音，2 时每拍砸根音。
static func _bass(notes: Array, ch: Array, bar: int, start: float, spb: float,
		lv: float, rng: RandomNumberGenerator, shift: int, mode: int, tight: float) -> void:
	var root := int(ch[1]) + shift
	var fifth := root + 7
	if mode == 0:
		_add(notes, root, start, 3.8 * spb, lv - 10.0, "bass", bar * 4.0, rng, tight)
		return
	if mode == 2:
		for k in range(4):
			_add(notes, root if k % 2 == 0 else fifth, start + k * spb, 1.05 * spb,
				lv - 12.0 + (2.0 if k % 2 == 0 else 0.0), "bass", bar * 4.0 + k, rng, tight)
		return
	_add(notes, root, start, 3.6 * spb, lv - 9.0, "bass", bar * 4.0, rng, tight)
	_add(notes, fifth, start + 2.0 * spb, 1.7 * spb, lv - 13.0, "bass", bar * 4.0 + 2, rng, tight)


## 右手织体：0 = 每拍一个和弦音（长音），1/2 = 按 FIGURE 分解。
static func _arp(notes: Array, ch: Array, bar: int, start: float, spb: float,
		lv: float, rng: RandomNumberGenerator, shift: int, texture: int, tight: float) -> void:
	var voicing: Array = []
	for m in ch[2]:
		voicing.append(int(m) + shift)
	if texture == 0:
		for k in range(4):
			_add(notes, int(voicing[k]), start + k * spb + 0.014, 3.4 * spb,
				lv - 12.0 - k, "arpeggio", bar * 4.0 + k, rng, tight)
		return
	var figure: Array = FIGURE[texture]
	var step := 0.5 if texture == 1 else 0.25
	for k in range(figure.size()):
		var pitch := int(voicing[int(figure[k])])
		var accent := 2.0 if k % 4 == 0 else -2.0
		_add(notes, pitch, start + k * step * spb + 0.012, 0.66 * spb,
			lv - 10.0 + accent, "arpeggio", bar * 4.0 + k * step, rng, tight)


## 铺一句旋律。rows 为 [[MIDI, 时值拍]]，-1 是休止；transpose 为八度偏移。
static func _phrase(notes: Array, rows: Array, bar: int, start: float, spb: float,
		velocity: float, rng: RandomNumberGenerator, shift: int, transpose: int, tight: float) -> void:
	var beat := 0.0
	for row: Array in rows:
		var pitch := int(row[0])
		var length := float(row[1])
		if pitch >= 0:
			# 乐句内的拱形：拍位越靠后越推，过三拍后收一点
			var shaping := 2.5 * sin(beat * PI / 4.0) - (2.0 if beat >= 3.0 else 0.0)
			_add(notes, pitch + transpose + shift, start + beat * spb, length * spb * 0.94,
				velocity + shaping, "melody", bar * 4.0 + beat, rng, tight)
		beat += length
	assert(is_equal_approx(beat, 4.0), "旋律小节 %d 必须正好四拍（实得 %s）" % [bar, str(beat)])


static func _add(notes: Array, midi: int, time: float, duration: float, velocity: float,
		role: String, beat: float, rng: RandomNumberGenerator, release: float) -> void:
	notes.append({
		"midi": midi,
		"time": maxf(0.0, time + rng.randf_range(-0.006, 0.006)),
		"duration": duration,
		"velocity": clampf(velocity + rng.randf_range(-2.0, 2.0), 18.0, 100.0),
		"role": role,
		"beat": beat,
		"release": release,
	})
