extends RefCounted
## 《玻璃温室》钢琴 BGM 工具链 —— 音高 / 和弦 / 时值 的纯函数助手。
##
## 全部是 static，由各模块 preload 引用；刻意不使用 class_name，
## 因为全局类缓存只在编辑器里刷新，headless 跑脚本时可能读不到新注册的类名。

const NOTE_PC := {
	"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4,
	"F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9,
	"A#": 10, "Bb": 10, "B": 11,
}

const PC_NAME := ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

## 和弦性质 → 半音音程。"" 与 "maj" 都是大三和弦。
const QUALITY := {
	"": [0, 4, 7],
	"maj": [0, 4, 7],
	"min": [0, 3, 7],
	"m": [0, 3, 7],
	"dim": [0, 3, 6],
	"aug": [0, 4, 8],
	"sus2": [0, 2, 7],
	"sus4": [0, 5, 7],
	"6": [0, 4, 7, 9],
	"m6": [0, 3, 7, 9],
	"7": [0, 4, 7, 10],
	"maj7": [0, 4, 7, 11],
	"m7": [0, 3, 7, 10],
	"m7b5": [0, 3, 6, 10],
	"dim7": [0, 3, 6, 9],
	"9": [0, 4, 7, 10, 14],
	"maj9": [0, 4, 7, 11, 14],
	"m9": [0, 3, 7, 10, 14],
	"add9": [0, 4, 7, 14],
	"madd9": [0, 3, 7, 14],
	"maj7sus4": [0, 5, 7, 11],
	"7sus4": [0, 5, 7, 10],
}


## "C4" -> 60（中央 C = 60，A4 = 69 = 440 Hz）。支持 "Bb3" / "F#5"。
static func midi(n: String) -> int:
	var pc := 0
	var idx := 1
	match n.substr(0, 1):
		"C": pc = 0
		"D": pc = 2
		"E": pc = 4
		"F": pc = 5
		"G": pc = 7
		"A": pc = 9
		"B": pc = 11
		_:
			push_error("无法解析音名: " + n)
	if n.length() > 1:
		var acc := n.substr(1, 1)
		if acc == "#":
			pc += 1
			idx = 2
		elif acc == "b":
			pc -= 1
			idx = 2
	return (int(n.substr(idx)) + 1) * 12 + pc


## 60 -> "C4"，仅用于日志与调试。
static func name_of(m: int) -> String:
	return PC_NAME[((m % 12) + 12) % 12] + str(int(floor(float(m) / 12.0)) - 1)


## 等十二平均律频率。接受 float 以便做微分音（双弦去谐）。
static func freq(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## 把 "Bbmaj7" 拆成 ["Bb", "maj7"]。
static func split_symbol(sym: String) -> Array:
	var root := sym.substr(0, 1)
	var rest_at := 1
	if sym.length() > 1:
		var acc := sym.substr(1, 1)
		if acc == "#" or acc == "b":
			root += acc
			rest_at = 2
	return [root, sym.substr(rest_at)]


## 和弦符号 → 从 lowest 起、根音位置的最低位排列。
## 例：chord("Fmaj7", 48) -> [53, 57, 60, 64]
static func chord(sym: String, lowest: int) -> Array:
	var parts := split_symbol(sym)
	if not NOTE_PC.has(parts[0]):
		push_error("无法解析和弦根音: " + sym)
		return []
	var iv: Array = QUALITY.get(parts[1], [])
	if iv.is_empty():
		push_error("无法解析和弦性质: " + sym)
		return []
	var root_pc: int = NOTE_PC[parts[0]]
	var low_pc := ((lowest % 12) + 12) % 12
	var base := lowest + (((root_pc - low_pc) % 12) + 12) % 12
	var out: Array = []
	for i in iv:
		out.append(base + int(i))
	return out


## 把一串音级按“就近排列”铺到 lowest 之上（用于自制 voicing）。
static func voice(pcs: Array, lowest: int) -> Array:
	var out: Array = []
	var cur := lowest
	for p in pcs:
		var target := int(p)
		var v := cur + (((target - (cur % 12)) % 12) + 12) % 12
		out.append(v)
		cur = v
	return out


## 整体移调。
static func transpose(notes: Array, semitones: int) -> Array:
	var out: Array = []
	for n in notes:
		out.append(int(n) + semitones)
	return out


## 拍 → 秒。
static func beats_sec(beats: float, bpm: float) -> float:
	return beats * 60.0 / bpm


## 一小节几拍。
static func beats_per_bar(time_sig: String) -> int:
	return int(time_sig.split("/")[0])
