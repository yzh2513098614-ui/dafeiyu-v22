extends RefCounted
## A hand-written 32-bar original piano cue, in beats (not frame timers).

const TITLE := "夕照，未寄出的信"
const BPM := 84.0
const BARS := 32
const SEED := 20261013
const SECTIONS := [
	{"name": "引子", "start": 0, "end": 4},
	{"name": "主题 A", "start": 4, "end": 12},
	{"name": "回忆 A′", "start": 12, "end": 20},
	{"name": "心绪 B", "start": 20, "end": 28},
	{"name": "尾声", "start": 28, "end": 32},
]

# Chord label, left-hand bass, arpeggio voicing.
const HARMONY := [
	["Cmaj7", 36, [48, 55, 59, 64]],
	["G/B", 35, [47, 55, 59, 62]],
	["Am7", 33, [45, 52, 55, 60]],
	["Em7", 40, [52, 55, 59, 62]],
	["Fmaj7", 41, [53, 57, 60, 64]],
	["C/E", 40, [52, 55, 60, 64]],
	["Dm7", 38, [50, 57, 60, 65]],
	["Gsus4 → G", 43, [55, 60, 62, 67]],
]
const BRIDGE_HARMONY := [
	["Fmaj9", 41, [53, 57, 64, 67]],
	["G6", 43, [55, 59, 62, 64]],
	["Em7", 40, [52, 55, 59, 62]],
	["Am9", 33, [45, 55, 59, 64]],
	["Dm9", 38, [50, 57, 60, 64]],
	["Gsus4 → G7", 43, [55, 60, 62, 65]],
	["Cmaj9/E", 40, [52, 55, 59, 62]],
	["G7", 43, [55, 59, 62, 65]],
]

# Each row is [MIDI note, length in beats]. -1 is a rest.
const THEME := [
	[[-1, 0.5], [76, 0.5], [79, 0.5], [76, 0.5], [74, 1.0], [72, 0.75], [-1, 0.25]],
	[[74, 0.75], [67, 0.25], [71, 1.0], [74, 0.5], [76, 0.5], [74, 1.0]],
	[[72, 0.5], [76, 0.5], [81, 0.75], [79, 0.25], [76, 1.0], [72, 1.0]],
	[[71, 0.5], [76, 0.5], [79, 1.0], [74, 0.5], [71, 0.5], [76, 0.75], [-1, 0.25]],
	[[69, 0.5], [72, 0.5], [76, 1.0], [74, 0.5], [72, 0.5], [69, 1.0]],
	[[67, 0.5], [72, 0.5], [79, 1.0], [76, 0.5], [74, 0.5], [72, 1.0]],
	[[77, 0.75], [76, 0.25], [74, 0.5], [69, 0.5], [72, 1.0], [74, 0.75], [-1, 0.25]],
	[[72, 0.5], [74, 0.5], [71, 0.75], [69, 0.25], [67, 1.0], [74, 0.75], [-1, 0.25]],
]
const VARIATION := [
	[[76, 0.75], [79, 0.25], [84, 1.0], [83, 0.5], [79, 0.5], [76, 1.0]],
	[[74, 0.5], [71, 0.5], [79, 1.0], [78, 0.25], [76, 0.25], [74, 1.25], [-1, 0.25]],
	[[76, 0.5], [79, 0.5], [81, 1.0], [83, 0.5], [81, 0.5], [76, 1.0]],
	[[79, 0.75], [76, 0.25], [74, 0.5], [71, 0.5], [76, 1.5], [-1, 0.5]],
	[[77, 0.75], [76, 0.25], [72, 1.0], [69, 0.5], [72, 0.5], [76, 1.0]],
	[[79, 0.5], [76, 0.5], [84, 1.0], [83, 0.5], [79, 0.5], [76, 1.0]],
	[[81, 0.75], [79, 0.25], [77, 0.5], [76, 0.5], [74, 1.5], [-1, 0.5]],
	[[72, 0.5], [74, 0.5], [71, 1.0], [69, 0.5], [67, 0.5], [74, 0.75], [-1, 0.25]],
]
const BRIDGE := [
	[[81, 1.0], [79, 0.5], [76, 0.5], [77, 0.5], [79, 0.5], [81, 1.0]],
	[[83, 1.0], [81, 0.5], [79, 0.5], [76, 0.5], [74, 0.5], [79, 1.0]],
	[[79, 0.5], [83, 0.5], [86, 1.0], [84, 0.5], [83, 0.5], [79, 1.0]],
	[[88, 1.5], [86, 0.5], [84, 0.5], [83, 0.5], [81, 1.0]],
	[[81, 0.5], [77, 0.5], [76, 1.0], [74, 0.5], [72, 0.5], [69, 1.0]],
	[[74, 0.5], [79, 0.5], [84, 1.0], [83, 0.5], [81, 0.5], [79, 1.0]],
	[[76, 1.0], [79, 0.5], [83, 0.5], [81, 0.5], [79, 0.5], [76, 1.0]],
	[[74, 0.75], [72, 0.25], [71, 1.0], [69, 0.5], [67, 0.5], [71, 0.75], [-1, 0.25]],
]

static func build() -> Dictionary:
	var notes: Array = []
	var bars: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var start_sec := 0.18
	for bar in range(BARS):
		var tempo := BPM
		if bar == 30:
			tempo = 78.0
		elif bar == 31:
			tempo = 70.0
		var seconds_per_beat := 60.0 / tempo
		# Small phrase-end breath, fixed and reproducible.
		if bar in [3, 7, 11, 15, 19, 23, 27]:
			seconds_per_beat *= 1.025
		var chord: Array
		if bar < 4:
			chord = [HARMONY[0], HARMONY[2], HARMONY[4], HARMONY[7]][bar]
		elif bar < 20:
			chord = HARMONY[(bar - 4) % 8]
		elif bar < 28:
			chord = BRIDGE_HARMONY[bar - 20]
		else:
			chord = [HARMONY[0], HARMONY[4], HARMONY[6], ["Cmaj9", 36, [48, 55, 59, 64]]][bar - 28]
		bars.append({"bar": bar + 1, "beat": bar * 4, "time": start_sec,
			"duration": 4.0 * seconds_per_beat, "chord": chord[0], "bpm": tempo})
		var level := 44.0
		if bar < 4 or bar >= 28:
			level = 36.0
		elif bar >= 20:
			level = 48.0
		_add(notes, int(chord[1]), start_sec, 3.6 * seconds_per_beat,
			level + 3.0, "bass", bar * 4.0, rng)
		var voicing: Array = chord[2]
		var pattern := [0, 1, 2, 1, 3, 1, 2, 1]
		var count := 8
		var step := 0.5
		if bar < 4 or bar >= 28:
			count = 4
			step = 1.0
		if bar == 31:
			count = 0
			for k in range(4):
				_add(notes, int(voicing[k]), start_sec + 0.012 * k,
					3.7 * seconds_per_beat, 37.0 - k, "arpeggio", bar * 4.0, rng)
		for k in range(count):
			var pitch := int(voicing[pattern[k]])
			if bar in [3, 11, 19, 25] and k >= count / 2 and pitch == 60:
				pitch = 59
			var accent := 2.0 if k % 4 == 0 else -2.0
			_add(notes, pitch, start_sec + (k * step) * seconds_per_beat + 0.014,
				0.64 * seconds_per_beat, level + accent, "arpeggio", bar * 4.0 + k * step, rng)
		if bar in [0, 1, 2, 3]:
			var intro: Array = [
				[[-1, 2.0], [76, 1.0], [74, 1.0]],
				[[72, 2.0], [-1, 1.0], [76, 1.0]],
				[[69, 1.0], [72, 1.0], [76, 1.5], [-1, 0.5]],
				[[74, 1.0], [72, 1.0], [71, 1.0], [-1, 1.0]],
			][bar]
			_phrase(notes, intro, bar, start_sec, seconds_per_beat, 57.0, rng)
		elif bar < 12:
			_phrase(notes, THEME[bar - 4], bar, start_sec, seconds_per_beat, 71.0, rng)
		elif bar < 20:
			_phrase(notes, VARIATION[bar - 12], bar, start_sec, seconds_per_beat, 74.0, rng)
		elif bar < 28:
			_phrase(notes, BRIDGE[bar - 20], bar, start_sec, seconds_per_beat,
				81.0 if bar < 24 else 76.0, rng)
		else:
			var ending: Array = [
				THEME[0],
				[[69, 0.5], [72, 0.5], [76, 1.5], [74, 0.5], [72, 1.0]],
				[[77, 1.0], [76, 1.0], [74, 1.5], [-1, 0.5]],
				[[76, 1.0], [74, 1.0], [72, 2.0]],
			][bar - 28]
			_phrase(notes, ending, bar, start_sec, seconds_per_beat, 60.0 - (bar - 28) * 4.0, rng)
		start_sec += 4.0 * seconds_per_beat
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return {"title": TITLE, "bpm": BPM, "beats_per_bar": 4, "bar_count": BARS,
		"seed": SEED, "sections": SECTIONS, "bars": bars, "notes": notes,
		"music_duration": start_sec, "duration": start_sec + 4.2}

static func preview(full: Dictionary) -> Dictionary:
	var bars: Array = full.bars
	var start := float(bars[4].time)
	var finish := float(bars[12].time)
	var notes: Array = []
	for original: Dictionary in full.notes:
		if original.time >= start - 0.02 and original.time < finish - 0.02:
			var n := original.duplicate()
			n.time = maxf(0.04, float(n.time) - start + 0.16)
			notes.append(n)
	return {"title": TITLE + " · 8 小节主题", "notes": notes,
		"duration": finish - start + 4.0, "bar_count": 8, "bpm": BPM}

static func tone_study() -> Dictionary:
	var notes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pitches := [36, 48, 60, 72, 84]
	for k in range(pitches.size()):
		_add(notes, pitches[k], 0.1 + 1.5 * k, 0.8, 70.0, "melody", 0.0, rng)
	for k in range(4):
		_add(notes, [48, 55, 59, 64][k], 8.0 + 0.014 * k, 2.0, 54.0, "melody", 0.0, rng)
	return {"title": "钢琴音色 · 低中高音与 Cmaj7", "notes": notes, "duration": 13.0}

static func _phrase(notes: Array, rows: Array, bar: int, start: float,
		seconds_per_beat: float, velocity: float, rng: RandomNumberGenerator) -> void:
	var beat := 0.0
	for row: Array in rows:
		var pitch := int(row[0])
		var length := float(row[1])
		if pitch >= 0:
			var shaping := 2.5 * sin(beat * PI / 4.0) - (2.0 if beat >= 3.0 else 0.0)
			_add(notes, pitch, start + beat * seconds_per_beat,
				length * seconds_per_beat * 0.92, velocity + shaping,
				"melody", bar * 4.0 + beat, rng)
		beat += length
	assert(is_equal_approx(beat, 4.0), "A melody bar must have four beats")

static func _add(notes: Array, midi: int, time: float, duration: float,
		velocity: float, role: String, beat: float, rng: RandomNumberGenerator) -> void:
	notes.append({"midi": midi, "time": maxf(0.0, time + rng.randf_range(-0.007, 0.007)),
		"duration": duration, "velocity": clampf(velocity + rng.randf_range(-2.0, 2.0), 20.0, 100.0),
		"role": role, "beat": beat})
