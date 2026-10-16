extends RefCounted
## 把各条产线的乐谱读成「钢琴改编曲」—— 全项目 BGM 的钢琴版统一从这里出。
##
## 做法：源乐谱（各产线自己的事件表）→ 统一源事件（按音区分类成 melody / bass / chord /
## ornament / perc）→ 钢琴重写（弦乐垫与长音改成钢琴和弦型，鼓组丢掉，音区收进钢琴能弹的范围）
## → 交给 gal_piano/piano_synth.gd 渲染。
##
## 为什么按**音区**分类而不是按层名：各产线的层名不统一（"piano" 层里混着旋律、低音与分解），
## 但「最高的那条线是旋律、最低的是低音」这条判断对十二首玻璃温室、六首鲸落电台都成立。
##
## 事件统一成 {t: 拍, m: 音高, d: 时值拍, v: 力度(0–1), voice: 角色}。

const GlasshouseScores := preload("res://tools/bgm_glasshouse/scores.gd")
const WhalefmScores := preload("res://tools/bgm_whalefm/scores.gd")

## 鼓组的层名（鲸落电台用），编成钢琴时整层丢掉。
const DRUM_LAYERS := ["kick", "snare", "rim", "hat", "ohat", "shaker"]

## 音区阈值：≥ MELODY_MIN 归旋律，< BASS_MAX 归低音，其余是和声。
const MELODY_MIN := 71
const BASS_MAX := 50


# ─────────────────────────── 源适配 ───────────────────────────

## 十二首《玻璃温室》家族（含 6 首圆舞曲变奏）：层名 piano / pad / mb。
static func glasshouse_family(moods: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in GlasshouseScores.new().build_all():
		var id := String(s["key"])
		out.append({
			"id": id,
			"title": String(s["title"]) + " · 钢琴版",
			"bpm": float(s["bpm"]),
			"time_sig": String(s["time_sig"]),
			"bars": int(s["bars"]),
			"seed": int(s["seed"]),
			"room_wet": 0.31,
			"moods": moods.get(id, []),
			"events": _from_glasshouse(s["events"]),
		})
	return out


## 六首《鲸落电台》：层名 ep / bass / 鼓组。
static func whalefm_family(moods: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in WhalefmScores.new().build_all():
		var id := String(s["key"])
		out.append({
			"id": id,
			"title": String(s["title"]) + " · 钢琴版",
			"bpm": float(s["bpm"]),
			"time_sig": String(s["time_sig"]),
			"bars": int(s["bars"]),
			"seed": int(s["seed"]),
			"room_wet": 0.30,
			"moods": moods.get(id, []),
			"events": _from_whalefm(s["events"]),
		})
	return out


static func _from_glasshouse(events: Array) -> Array:
	var out: Array = []
	for e: Dictionary in events:
		var layer := String(e["layer"])
		var m := int(e["m"])
		var voice := ""
		if layer == "mb":
			voice = "ornament"
		elif layer == "pad":
			voice = "chord"
		else:
			voice = "melody" if m >= MELODY_MIN else ("bass" if m < BASS_MAX else "chord")
		out.append({"t": float(e["t"]), "m": m, "d": float(e["d"]), "v": float(e["v"]), "voice": voice})
	return out


static func _from_whalefm(events: Array) -> Array:
	var out: Array = []
	for e: Dictionary in events:
		var layer := String(e["layer"])
		if DRUM_LAYERS.has(layer):
			continue
		var m := int(e["m"])
		var voice := ""
		if layer == "bass":
			voice = "bass"
		else:
			voice = "melody" if m >= MELODY_MIN else ("bass" if m < BASS_MAX else "chord")
		out.append({"t": float(e["t"]), "m": m, "d": float(e["d"]), "v": float(e["v"]), "voice": voice})
	return out


# ─────────────────────────── 改写成钢琴 ───────────────────────────

## 源曲目 → piano_synth 能吃的乐谱。角色沿用原曲，只做「钢琴化」处理：
##   melody   原样，力度保留（旋律是曲子的身份，不动）
##   bass     低于 36 的抬八度（钢琴低音区会糊）
##   chord    长音按 1 拍重新触键（钢琴按不住弦乐垫的长音）；低于 40 的抬八度
##   ornament 高于 96 的降八度（钢琴高音区太尖），力度收一点
##   perc     丢掉（鼓组没有钢琴对应物）
static func to_piano(src: Dictionary) -> Dictionary:
	var bpm := float(src["bpm"])
	var spb := 60.0 / bpm
	var beats_per_bar := 4
	var sig := String(src["time_sig"]).split("/")
	if sig.size() == 2:
		beats_per_bar = int(sig[0])
	var notes: Array = []
	for e: Dictionary in src["events"]:
		var voice := String(e["voice"])
		var m := int(e["m"])
		var t := float(e["t"]) * spb
		var d := float(e["d"])
		var v := float(e["v"])
		match voice:
			"melody":
				_push(notes, m, t, d * spb * 0.96, v * 100.0, "melody", 0.44)
			"bass":
				if m < 36:
					m += 12
				_push(notes, m, t, d * spb * 0.96, v * 100.0, "bass", 0.70)
			"chord":
				if m < 40:
					m += 12
				# 长音拆成每拍一次触键：弦乐垫能一直托着，钢琴不能。
				var span := maxf(0.25, d)
				var k := 0.0
				while k < span - 0.001:
					var seg: float = minf(1.1, span - k)
					_push(notes, m, t + k * spb, seg * spb * 0.92, v * 88.0, "arpeggio", 0.60)
					k += 1.0
			"ornament":
				while m > 96:
					m -= 12
				_push(notes, m, t, d * spb * 0.96, v * 92.0, "ornament", 0.40)
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	var music := float(src["bars"] * beats_per_bar) * spb
	var rng := RandomNumberGenerator.new()
	rng.seed = int(src["seed"])
	return {
		"id": String(src["id"]) + "_piano",
		"title": String(src["title"]),
		"key": "钢琴改编",
		"bpm": bpm, "beats_per_bar": beats_per_bar, "bar_count": int(src["bars"]),
		"seed": int(src["seed"]), "notes": notes,
		"music_duration": music, "duration": music + 1.2,
		"room_wet": float(src["room_wet"]),
		"moods": src["moods"],
	}


## 写入一个音符；拍位加 ±6 ms 抖动，力度夹到 18–100。
static func _push(notes: Array, midi: int, time: float, duration: float,
		velocity: float, role: String, release: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = midi * 7919 + int(time * 1000.0)
	notes.append({
		"midi": midi,
		"time": maxf(0.0, time + rng.randf_range(-0.006, 0.006)),
		"duration": maxf(0.08, duration),
		"velocity": clampf(velocity + rng.randf_range(-2.0, 2.0), 18.0, 100.0),
		"role": role,
		"release": release,
	})
