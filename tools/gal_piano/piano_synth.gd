extends RefCounted
## Additive struck-string piano. All samples, mixing and room reverb run in Godot.

const RATE := 44100
const PARTIALS := [1.0, 0.55, 0.31, 0.18, 0.12, 0.079, 0.052, 0.035, 0.024, 0.016, 0.011, 0.008]
var cache: Dictionary = {}
var last_report: Dictionary = {}

func prepare(scores: Array) -> void:
	var pitches: Dictionary = {}
	for score: Dictionary in scores:
		for n: Dictionary in score.notes:
			pitches[int(n.midi)] = true
	var keys := pitches.keys()
	keys.sort()
	for pitch in keys:
		if not cache.has(pitch):
			cache[pitch] = _make_key(int(pitch))
			print("PIANO_KEY ", pitch, " ", cache.size(), "/", keys.size())

func render(score: Dictionary) -> AudioStreamWAV:
	var started := Time.get_ticks_msec()
	prepare([score])
	var frames := int(ceil(float(score.duration) * RATE))
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(frames)
	right.resize(frames)
	for n: Dictionary in score.notes:
		_mix_note(n, left, right)
	print("PIANO_MIXED ", score.title, " ", score.notes.size(), " notes")
	_room(left, right, float(score.get("room_wet", 0.33)))
	var peak := 0.0
	var dc_left := 0.0
	var dc_right := 0.0
	for i in range(frames):
		dc_left += left[i]
		dc_right += right[i]
	dc_left /= frames
	dc_right /= frames
	for i in range(frames):
		left[i] -= dc_left
		right[i] -= dc_right
		peak = maxf(peak, maxf(absf(left[i]), absf(right[i])))
	var gain := 0.88 / maxf(peak, 0.001)
	var pcm := PackedByteArray()
	pcm.resize(frames * 4)
	var square_sum := 0.0
	var fade_frames := int(RATE * 0.55)
	for i in range(frames):
		var fade := 1.0
		if i >= frames - fade_frames:
			var t := float(frames - 1 - i) / fade_frames
			fade = t * t * (3.0 - 2.0 * t)
		var l := left[i] * gain * fade
		var r := right[i] * gain * fade
		pcm.encode_s16(i * 4, int(round(l * 32767.0)))
		pcm.encode_s16(i * 4 + 2, int(round(r * 32767.0)))
		square_sum += (l * l + r * r) * 0.5
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = RATE
	audio.stereo = true
	audio.data = pcm
	audio.tags = {"title": score.title, "artist": "Original Godot Piano Study", "comment": "Procedural additive piano; no external samples"}
	last_report = {"title": score.title, "sample_rate": RATE, "channels": 2, "bits": 16,
		"frames": frames, "duration": audio.get_length(), "notes": score.notes.size(),
		"peak_dbfs": linear_to_db(0.88), "rms_dbfs": linear_to_db(sqrt(square_sum / frames)),
		"render_seconds": (Time.get_ticks_msec() - started) / 1000.0, "cached_keys": cache.size()}
	return audio

func _make_key(midi: int) -> Dictionary:
	var frequency := 440.0 * pow(2.0, (midi - 69.0) / 12.0)
	var length := clampf(4.4 * pow(440.0 / frequency, 0.15), 3.5, 6.0)
	var count := int(length * RATE)
	var soft := PackedFloat32Array()
	var bright := PackedFloat32Array()
	soft.resize(count)
	bright.resize(count)
	# Stiff strings: progressively stretched upper partials.
	var stiffness := 0.00010 + 0.00010 * pow(frequency / 440.0, 0.7)
	for h_index in range(PARTIALS.size()):
		var harmonic := float(h_index + 1)
		var hz := frequency * harmonic * sqrt(1.0 + stiffness * harmonic * harmonic)
		if hz >= RATE * 0.45:
			break
		var decay_seconds := clampf(2.6 * pow(440.0 / frequency, 0.24) / pow(harmonic, 0.72), 0.1, 5.0)
		var damping := exp(-1.0 / (decay_seconds * RATE))
		var w := TAU * hz / RATE
		var rotate_sin := sin(w) * damping
		var rotate_cos := cos(w) * damping
		var s := sin(0.075 * harmonic) * float(PARTIALS[h_index])
		var c := cos(0.075 * harmonic) * float(PARTIALS[h_index])
		var soft_color := pow(harmonic, -0.44)
		var bright_color := pow(harmonic, 0.10)
		for i in range(count):
			soft[i] += s * soft_color
			bright[i] += s * bright_color
			var next_s := s * rotate_cos + c * rotate_sin
			c = c * rotate_cos - s * rotate_sin
			s = next_s
		# A quieter, very slightly detuned companion string on lower partials.
		if h_index < 4:
			var detuned := hz * pow(2.0, (0.6 + h_index * 0.17) / 1200.0)
			rotate_sin = sin(TAU * detuned / RATE) * damping
			rotate_cos = cos(TAU * detuned / RATE) * damping
			s = 0.0
			c = float(PARTIALS[h_index]) * 0.24
			for i in range(count):
				soft[i] += s * soft_color
				bright[i] += s * bright_color
				var next_s := s * rotate_cos + c * rotate_sin
				c = c * rotate_cos - s * rotate_sin
				s = next_s
	var rng := RandomNumberGenerator.new()
	rng.seed = 9317 + midi * 71
	var noise_decay := 1.0
	var noise_damping := exp(-1.0 / (0.009 * RATE))
	var previous_noise := 0.0
	var end_fade := int(0.04 * RATE)
	for i in range(count):
		var attack := minf(1.0, float(i) / (0.004 * RATE))
		var noise := 0.0
		if i < RATE * 0.09:
			var white := rng.randf_range(-1.0, 1.0)
			noise = (white - previous_noise) * noise_decay * 0.015
			previous_noise = white
			noise_decay *= noise_damping
		var end_window := minf(1.0, float(count - 1 - i) / end_fade)
		soft[i] = (soft[i] + noise * 0.6) * attack * end_window
		bright[i] = (bright[i] + noise) * attack * end_window
	return {"soft": soft, "bright": bright}

func _mix_note(note: Dictionary, left: PackedFloat32Array, right: PackedFloat32Array) -> void:
	var key: Dictionary = cache[int(note.midi)]
	var soft: PackedFloat32Array = key.soft
	var bright: PackedFloat32Array = key.bright
	var velocity := float(note.velocity) / 100.0
	var color := clampf((velocity - 0.30) / 0.60, 0.0, 1.0)
	var amplitude := pow(velocity, 1.65)
	if note.role == "bass":
		amplitude *= 0.64
	elif note.role == "arpeggio":
		amplitude *= 0.76
	elif note.role == "ornament":
		amplitude *= 0.54
	var pan := clampf((float(note.midi) - 62.0) / 80.0, -0.30, 0.30)
	if note.role == "melody":
		pan *= 0.45
	var left_gain := sqrt((1.0 - pan) * 0.5) * amplitude
	var right_gain := sqrt((1.0 + pan) * 0.5) * amplitude
	var start := int(float(note.time) * RATE)
	var held := int(float(note.duration) * RATE)
	# Shallow pedal: damper release is slower on accompaniment.
	var release := float(note.get("release", 0.44 if note.role == "melody" else 0.72))
	var release_factor := exp(-1.0 / (release * RATE))
	var limit := mini(soft.size(), left.size() - start)
	limit = mini(limit, held + int(release * 5.0 * RATE))
	var envelope := 1.0
	for i in range(limit):
		if i >= held:
			envelope *= release_factor
		var sample := (soft[i] * (1.0 - color) + bright[i] * color) * envelope
		left[start + i] += sample * left_gain
		right[start + i] += sample * right_gain

func _room(left: PackedFloat32Array, right: PackedFloat32Array, wet: float) -> void:
	# Four damped, mutually diffusing delays. No playback-only bus effects:
	# the PCM itself includes this room so exported WAVs sound the same.
	var a := PackedFloat32Array()
	var b := PackedFloat32Array()
	var c := PackedFloat32Array()
	var d := PackedFloat32Array()
	a.resize(1559)
	b.resize(1811)
	c.resize(2137)
	d.resize(2341)
	var ia := 0
	var ib := 0
	var ic := 0
	var id := 0
	var la := 0.0
	var lb := 0.0
	var lc := 0.0
	var ld := 0.0
	for i in range(left.size()):
		la = la * 0.43 + a[ia] * 0.57
		lb = lb * 0.43 + b[ib] * 0.57
		lc = lc * 0.43 + c[ic] * 0.57
		ld = ld * 0.43 + d[id] * 0.57
		var excitation := (left[i] + right[i]) * 0.115
		a[ia] = excitation + (la + lb + lc + ld) * 0.435
		b[ib] = excitation + (la - lb + lc - ld) * 0.435
		c[ic] = excitation + (la + lb - lc - ld) * 0.435
		d[id] = excitation + (la - lb - lc + ld) * 0.435
		left[i] = left[i] * 0.96 + (la + lc - lb * 0.20) * wet
		right[i] = right[i] * 0.96 + (lb + ld - la * 0.20) * wet
		ia = (ia + 1) % a.size()
		ib = (ib + 1) % b.size()
		ic = (ic + 1) % c.size()
		id = (id + 1) % d.size()
