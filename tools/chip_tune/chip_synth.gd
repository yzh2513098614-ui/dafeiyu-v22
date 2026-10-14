extends RefCounted
## 芯片音乐（chiptune）合成器：PolyBLEP 抗混叠方波 ×2 + 三角波低音 + LFSR 噪声鼓。
## 全部离线渲染：音符与立体声回声都按整圈取模混音，产出数学上无缝的循环 WAV。
## 输入 score：{duration, notes:[{c,midi,t,d,v,duty,vib} 或 {c:"drm",kind,t,v}], echo_delay, echo_mix}

const RATE := 44100
const GAIN_P1 := 0.34
const GAIN_P2 := 0.26
const GAIN_TRI := 0.46
const GAIN_DRM := 0.34

var last_report: Dictionary = {}

func render(score: Dictionary) -> AudioStreamWAV:
	var started := Time.get_ticks_msec()
	var frames := int(round(float(score.duration) * RATE))
	var left := PackedFloat32Array()
	var right := PackedFloat32Array()
	left.resize(frames)
	right.resize(frames)
	for n: Dictionary in score.notes:
		match str(n.c):
			"p1", "p2":
				_mix_pulse(n, left, right, frames)
			"tri":
				_mix_tri(n, left, right, frames)
			"drm":
				_mix_drum(n, left, right, frames)
	_echo(left, right, frames, float(score.get("echo_delay", 0.30)), float(score.get("echo_mix", 0.5)))
	# 直流去除 + 峰值归一
	var dc_l := 0.0
	var dc_r := 0.0
	for i in range(frames):
		dc_l += left[i]
		dc_r += right[i]
	dc_l /= frames
	dc_r /= frames
	var peak := 0.0
	for i in range(frames):
		left[i] -= dc_l
		right[i] -= dc_r
		peak = maxf(peak, maxf(absf(left[i]), absf(right[i])))
	var gain := 0.85 / maxf(peak, 0.001)
	var seam := maxf(absf(left[0] - left[frames - 1]), absf(right[0] - right[frames - 1])) * gain
	var pcm := PackedByteArray()
	pcm.resize(frames * 4)
	var square_sum := 0.0
	for i in range(frames):
		var l := left[i] * gain
		var r := right[i] * gain
		pcm.encode_s16(i * 4, int(round(clampf(l, -1.0, 1.0) * 32767.0)))
		pcm.encode_s16(i * 4 + 2, int(round(clampf(r, -1.0, 1.0) * 32767.0)))
		square_sum += (l * l + r * r) * 0.5
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = RATE
	audio.stereo = true
	audio.data = pcm
	audio.tags = {"title": str(score.title), "artist": "Original Godot Chip Tune", "comment": "Procedural chiptune; seamless loop; no external samples"}
	last_report = {"title": score.title, "sample_rate": RATE, "channels": 2, "bits": 16,
		"frames": frames, "duration": audio.get_length(), "notes": score.notes.size(),
		"peak_dbfs": linear_to_db(0.85), "rms_dbfs": linear_to_db(sqrt(square_sum / frames)),
		"seam_jump": seam, "render_seconds": (Time.get_ticks_msec() - started) / 1000.0}
	return audio

# ---------------------------------------------------------------- 方波（PolyBLEP 抗混叠）

static func _blep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0

func _mix_pulse(note: Dictionary, left: PackedFloat32Array, right: PackedFloat32Array, frames: int) -> void:
	var midi := float(note.midi)
	var base_freq := 440.0 * pow(2.0, (midi - 69.0) / 12.0)
	if str(note.c) == "p2":
		base_freq *= pow(2.0, -4.0 / 1200.0) # 第二方波微降 4 音分，出合唱厚度
	var duty := float(note.get("duty", 0.5))
	var vib_cents := float(note.get("vib", 0.0))
	var vel := float(note.v) / 100.0
	var amp := pow(vel, 1.3) * (GAIN_P1 if str(note.c) == "p1" else GAIN_P2)
	var pan := -0.16 if str(note.c) == "p1" else 0.16
	var lg := sqrt((1.0 - pan) * 0.5) * amp
	var rg := sqrt((1.0 + pan) * 0.5) * amp
	var start := int(round(float(note.t) * RATE))
	var held := int(round(float(note.d) * RATE))
	var attack := int(0.003 * RATE)
	var release := mini(int(0.012 * RATE), held)
	var vib_delay := int(0.14 * RATE)
	var vib_rate := TAU * 5.6 / RATE
	var phase := 0.0
	var dc_x := 0.0
	var dc_y := 0.0
	for i in range(held):
		var freq := base_freq
		if vib_cents > 0.0 and i > vib_delay:
			var depth := minf(1.0, float(i - vib_delay) / (0.10 * RATE))
			freq *= pow(2.0, vib_cents * depth * sin(vib_rate * (i - vib_delay)) / 1200.0)
		phase += freq / RATE
		if phase >= 1.0:
			phase -= 1.0
		var dt := freq / RATE
		var s := -1.0
		if phase < duty:
			s = 1.0
		s += _blep(phase, dt)
		s -= _blep(fmod(phase - duty + 1.0, 1.0), dt)
		# 占空比 ≠50% 时有直流分量，用一阶高通挡掉
		dc_y = s - dc_x + 0.995 * dc_y
		dc_x = s
		var env := 1.0
		if i < attack:
			env = float(i) / attack
		elif i >= held - release:
			env = float(held - 1 - i) / release
		var j := (start + i) % frames
		left[j] += dc_y * env * lg
		right[j] += dc_y * env * rg

# ---------------------------------------------------------------- 三角波（低音）

func _mix_tri(note: Dictionary, left: PackedFloat32Array, right: PackedFloat32Array, frames: int) -> void:
	var freq := 440.0 * pow(2.0, (float(note.midi) - 69.0) / 12.0)
	var vel := float(note.v) / 100.0
	var amp := pow(vel, 1.25) * GAIN_TRI
	var start := int(round(float(note.t) * RATE))
	var held := int(round(float(note.d) * RATE))
	var attack := int(0.004 * RATE)
	var release := mini(int(0.012 * RATE), held)
	var phase := 0.0
	for i in range(held):
		phase += freq / RATE
		if phase >= 1.0:
			phase -= 1.0
		var u := phase + 0.25
		if u >= 1.0:
			u -= 1.0
		var s := 1.0 - 4.0 * absf(u - 0.5) # 从 0 上升的三角波，起音无咔哒
		var env := 1.0
		if i < attack:
			env = float(i) / attack
		elif i >= held - release:
			env = float(held - 1 - i) / release
		var j := (start + i) % frames
		left[j] += s * env * amp * 0.7071
		right[j] += s * env * amp * 0.7071

# ---------------------------------------------------------------- 噪声鼓（LFSR + 音高踢鼓）

func _mix_drum(note: Dictionary, left: PackedFloat32Array, right: PackedFloat32Array, frames: int) -> void:
	var vel := float(note.v) / 100.0
	var amp := pow(vel, 1.2) * GAIN_DRM
	var start := int(round(float(note.t) * RATE))
	match str(note.kind):
		"K":
			# 踢鼓：正弦音高 130→42 Hz 下扫 + 起音咔哒
			var count := int(0.17 * RATE)
			var phase := 0.0
			for i in range(count):
				var t := float(i) / RATE
				var freq := 42.0 + 88.0 * exp(-t / 0.030)
				phase += freq / RATE
				var s := sin(TAU * phase) * exp(-t / 0.085)
				if i < int(0.002 * RATE):
					s += 0.35 * (1.0 - float(i) / (0.002 * RATE))
				var j := (start + i) % frames
				left[j] += s * amp * 0.95 * 0.7071
				right[j] += s * amp * 0.95 * 0.7071
		"S":
			# 军鼓：低速 LFSR 噪声 + 190 Hz 三角体
			var count := int(0.16 * RATE)
			var lfsr := 0x4A39
			var noise := 0.0
			var hp_prev := 0.0
			var phase := 0.0
			for i in range(count):
				if i % 19 == 0:
					var bit := ((lfsr >> 0) ^ (lfsr >> 1)) & 1
					lfsr = (lfsr >> 1) | (bit << 14)
					noise = 1.0 if (lfsr & 1) == 1 else -1.0
				var t := float(i) / RATE
				var hp := noise - hp_prev
				hp_prev = noise
				phase += 190.0 / RATE
				var body := sin(TAU * phase) * exp(-t / 0.028)
				var s := hp * 0.55 * exp(-t / 0.045) + body * 0.6
				var j := (start + i) % frames
				left[j] += s * amp * 0.8 * 0.68
				right[j] += s * amp * 0.8 * 0.74
		"H", "O":
			# 踩镲：高速 LFSR 噪声差分（高通），开镲衰减更慢
			var open := str(note.kind) == "O"
			var count := int((0.24 if open else 0.05) * RATE)
			var tau := 0.065 if open else 0.011
			var lfsr := 0x2E51
			var noise := 0.0
			var hp_prev := 0.0
			for i in range(count):
				if i % 4 == 0:
					var bit := ((lfsr >> 0) ^ (lfsr >> 1)) & 1
					lfsr = (lfsr >> 1) | (bit << 14)
					noise = 1.0 if (lfsr & 1) == 1 else -1.0
				var hp := noise - hp_prev
				hp_prev = noise
				var s := hp * exp(-float(i) / RATE / tau) * 0.40
				var j := (start + i) % frames
				left[j] += s * amp * 0.72
				right[j] += s * amp * 0.62

# ---------------------------------------------------------------- 立体声回声（整圈卷绕，循环无缝）

func _echo(left: PackedFloat32Array, right: PackedFloat32Array, frames: int, delay: float, mix: float) -> void:
	if mix <= 0.001:
		return
	var dl := int(delay * RATE)
	if dl <= 0 or dl >= frames / 2:
		return
	var fb := 0.36
	# bl/br 从干声出发做两轮环形迭代：回声方程的不动点即周期稳态解，
	# 第二轮之后「循环开始之前」的回声内容已经收敛，首尾天然连续。
	var bl := PackedFloat32Array(left)
	var br := PackedFloat32Array(right)
	var nl := PackedFloat32Array()
	var nr := PackedFloat32Array()
	nl.resize(frames)
	nr.resize(frames)
	for lap in range(2):
		for i in range(frames):
			var j := i - dl
			if j < 0:
				j += frames
			nl[i] = left[i] + br[j] * fb
			nr[i] = right[i] + bl[j] * fb
		var tmp := bl
		bl = nl
		nl = tmp
		tmp = br
		br = nr
		nr = tmp
	for i in range(frames):
		left[i] += (bl[i] - left[i]) * mix
		right[i] += (br[i] - right[i]) * mix
