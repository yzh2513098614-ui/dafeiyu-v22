extends SceneTree
## 《晚安，鲸落港》接入自检：曲库里的每一个 id 都要真的指向一个 wav，
## 新曲要同时出现在轮换表和音乐鉴赏目录里。
##
##   ... --script res://tools/gal_piano/check_goodnight.gd

const MD := preload("res://music/music_director.gd")
const Score := preload("res://tools/gal_piano/score_goodnight.gd")
const ID := "gal_goodnight"
const DIR := "res://assets/music/"

var _bad := 0


func _initialize() -> void:
	var score: Dictionary = Score.build()
	print("── 《%s》接入自检 ── %d 小节 / %.1f 秒 / %d 音符" % [
		score.title, score.bar_count, score.duration, score.notes.size()])

	# 1. 产物存在，且 RIFF 头报得出 44100 Hz / 16 bit / 2 ch
	#    Godot 4 的 AudioStreamWAV 只有 save_to_wav，没有对应的读函数，
	#    运行时也是自己解析字节（见 music_director.gd 头部注释），这里沿用同一做法。
	var path := DIR + ID + ".wav"
	if not FileAccess.file_exists(path):
		_fail("缺文件 " + path)
	else:
		var info := _riff_info(path)
		var ok_fmt: bool = int(info.get("rate", 0)) == 44100 and int(info.get("ch", 0)) == 2 \
			and int(info.get("bits", 0)) == 16
		print("  %s  %s  %.2f 秒  %.1f MB  %d Hz / %d ch / %d bit" % [
			"OK " if ok_fmt else "BAD", path, float(info.get("sec", 0.0)),
			float(info.get("bytes", 0)) / 1048576.0,
			int(info.get("rate", 0)), int(info.get("ch", 0)), int(info.get("bits", 0))])
		if not ok_fmt:
			_fail("WAV 头不对：%s" % str(info))
		if absf(float(info.get("sec", 0.0)) - float(score.duration)) > 0.6:
			_fail("时长与谱面不符：wav %.2f 秒 vs 谱面 %.2f 秒" % [
				float(info.get("sec", 0.0)), score.duration])

	# 2. 每一个场合轮换表里的 id 都要有对应文件
	for mood in MD.STYLE_SETS:
		var tracks: Dictionary = MD.STYLE_SETS[mood]["tracks"]
		for key in tracks:
			var list: Variant = tracks[key]
			if not (list is Array):
				continue
			for t in list:
				var file := DIR + String(t) + ".wav"
				if not FileAccess.file_exists(file):
					_fail("%s / %s 指向不存在的 %s" % [mood, key, file])

	# 3. 新曲必须在 night 与 hope 的轮换里，也要在鉴赏目录里
	for mood in ["night", "hope"]:
		var list: Array = MD.STYLE_SETS["galgame"]["tracks"][mood]
		_expect(list.has(ID), "galgame / %s 轮换含 %s" % [mood, ID])
	var listed := false
	for row in MD.CATALOG["galgame"]:
		if String(row[0]) == ID:
			listed = true
			print("  OK  鉴赏目录：%s · %s" % [row[0], row[1]])
	_expect(listed, "鉴赏目录列出 " + ID)

	# 4. 曲目数口径与风格组名字一致（「galgame 场景二十首」）
	var n := MD.CATALOG["galgame"].size()
	var label := String(MD.STYLE_SETS["galgame"]["name"])
	print("  %s  galgame 曲库 %d 首 · 组名「%s」" % ["OK " if label.ends_with(_cn(n)) else "BAD", n, label])
	if not label.ends_with(_cn(n)):
		_fail("组名与实际曲目数不一致")

	print("── 完成：%s ──" % ["全部通过" if _bad == 0 else "%d 项不通过" % _bad])
	quit(0 if _bad == 0 else 1)


## 走 RIFF chunk 找 fmt / data —— 不能按固定偏移读，save_to_wav 会插 LIST / INFO 块。
func _riff_info(path: String) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(path)
	var out := {"bytes": b.size(), "sec": 0.0, "rate": 0, "ch": 0, "bits": 0}
	if b.size() < 44 or b.decode_u32(0) != 0x46464952 or b.decode_u32(8) != 0x45564157:
		return out
	var rate := 0
	var ch := 0
	var bits := 0
	var dlen := 0
	var pos := 12
	while pos + 8 <= b.size():
		var cid := b.decode_u32(pos)
		var clen := int(b.decode_u32(pos + 4))
		var body := pos + 8
		if body + clen > b.size():
			break
		if cid == 0x20746D66:       # "fmt "
			ch = int(b.decode_u16(body + 2))
			rate = int(b.decode_u32(body + 4))
			bits = int(b.decode_u16(body + 14))
		elif cid == 0x61746164:     # "data"
			dlen = clen
		pos = body + clen + (clen & 1)
	var frames := dlen / maxi(1, ch * maxi(1, bits / 8))
	out["rate"] = rate
	out["ch"] = ch
	out["bits"] = bits
	out["sec"] = float(frames) / float(maxi(1, rate))
	return out


func _expect(cond: bool, what: String) -> void:
	print("  %s %s" % ["OK " if cond else "BAD", what])
	if not cond:
		_bad += 1


func _fail(what: String) -> void:
	push_error(what)
	_bad += 1


## 19 → 「十九首」、20 → 「二十首」，够用来核对组名口径。
func _cn(n: int) -> String:
	match n:
		19: return "十九首"
		20: return "二十首"
		21: return "二十一首"
		_: return "%d首" % n
