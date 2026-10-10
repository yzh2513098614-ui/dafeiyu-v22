extends RefCounted
## 大肥鱼 · 音效合成器
##
## 为什么自己合成而不是找现成素材：这个工程从第一天起就不依赖外部素材管线 ——
## 音乐也是 tools/music_synth*.gd 现算出来的 WAV，连 .import 都不需要。
## 音效沿用同一套口径：改一个参数就能重生成全套。
##
## 输出：assets/sfx/<名称>.wav，16bit 单声道 22050Hz。
## 用法：var s = load("res://tools/sfx_synth.gd").new(); s.write_all()
##
## ─────────────────────────── 音色口径（重要）───────────────────────────
## 第一版做成了「写实音效」：噪声爆发 + 1.5~4.2kHz 高频 + 0.001s 瞬间起音 +
## 归一化到 0.92 满刻度，还用方波和锯齿波。结果整体刺耳 —— 那不是音量问题，
## 是音色骨架选错了，调小音量只会变成「小声的刺耳」。
##
## 这一版按「可爱点击音」重做，五条硬规矩：
##   1. **只用正弦和三角**，不用方波/锯齿（后两者天生带刺）
##   2. **中频为主**：界面音 600~1000Hz，命中的「啵」在 300~660Hz
##   3. **起音 4~8ms**，不能是瞬间 —— 瞬间起音听起来是「咔」，不是「嘟」
##   4. **音尾快速下滑**（droop + shape）：这是「嘟」和「嘀」的唯一区别
##   5. **收尾一律低通**（_finish 的 smooth 参数）+ 峰值压到 0.6 左右，
##      把高频毛刺和过冲削掉
## 噪声只在逃跑/开门里留极少量、且重低通 —— 它是「质感」，不是主体。
##
## 随机数用固定种子，同样的参数永远生成同样的音效（可复现）。

const RATE := 22050
const OUT_REL := "res://assets/sfx"

## 全部会生成的音效名。改这里就能增删。
const NAMES: Array = [
	"ui_click", "ui_back", "ui_confirm",
	"page",
	"hit_light", "hit_crit", "hit_take",
	"skill_cast", "heal", "shield", "bind",
	"link_ready", "link_cast",
	"enemy_down", "flee", "invalid",
	"pickup", "chest_open", "level_up", "equip", "door",
	"encounter", "type_tick",
]

var _buf := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------- 渲染核心

func _seconds(sec: float) -> void:
	_buf = PackedFloat32Array()
	_buf.resize(maxi(1, int(sec * RATE)))
	_buf.fill(0.0)

func _at(idx: int, value: float) -> void:
	if idx >= 0 and idx < _buf.size():
		_buf[idx] += value

## 波形只留两种：0 正弦 · 1 三角。（原来还有方波和锯齿，是刺耳的主要来源之一）
func _wave(kind: int, phase: float) -> float:
	if kind == 1:
		var p := fposmod(phase, TAU) / TAU
		return 4.0 * absf(p - 0.5) - 1.0
	return sin(phase)

## 一个音。
##   freq_end 给音尾的落点（滑音）；shape < 1 表示「先掉得快、后面平」，
##   这正是「嘟」的包络形状 —— 线性下滑听起来像警报。
##   vib_hz / vib_depth 给一点颤音，用来做泡泡和水膜之类的软音色。
func _tone(start: float, dur: float, freq: float, amp: float, kind: int = 0,
		attack: float = 0.006, decay: float = 8.0, freq_end: float = -1.0,
		shape: float = 0.55, vib_hz: float = 0.0, vib_depth: float = 0.0) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	if n <= 1:
		return
	var a := maxf(1.0, attack * RATE)
	var f1 := freq if freq_end < 0.0 else freq_end
	var ratio := f1 / maxf(1.0, freq)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= _buf.size():
			break
		var t := float(i) / float(RATE)
		var env := 1.0
		if i < int(a):
			env = float(i) / a
		env *= exp(-t * decay)
		var p := float(i) / float(n)
		var f := freq * pow(ratio, pow(p, shape))
		if vib_hz > 0.0 and vib_depth > 0.0:
			f *= 1.0 + sin(TAU * vib_hz * t) * vib_depth
		_at(idx, _wave(kind, phase) * env * amp)
		phase += TAU * f / float(RATE)

## 噪声：只用来加一点「质感」，所以振幅一律给得很小，并且从强低通开始。
func _noise(start: float, dur: float, amp: float, decay: float = 12.0,
		lp: float = 900.0, hp: float = 0.0, lp_end: float = -1.0) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	if n <= 1:
		return
	var attack := maxf(1.0, 0.004 * RATE)
	var y := 0.0
	var z := 0.0
	for i in n:
		var idx := i0 + i
		if idx >= _buf.size():
			break
		var t := float(i) / float(RATE)
		var env := 1.0
		if i < int(attack):
			env = float(i) / attack
		env *= exp(-t * decay)
		var v := _rng.randf_range(-1.0, 1.0)
		if lp > 0.0:
			var cut := lp
			if lp_end > 0.0:
				cut = lerpf(lp, lp_end, float(i) / float(n))
			var a_lp := 1.0 - exp(-TAU * cut / float(RATE))
			y += a_lp * (v - y)
			v = y
		if hp > 0.0:
			var a_hp := 1.0 - exp(-TAU * hp / float(RATE))
			z += a_hp * (v - z)
			v -= z
		_at(idx, v * env * amp)

## 一阶低通铺满整个缓冲区。可爱音色只留中低频 ——
## 高频的「边角料」正是刺耳感的来源，这一步比调音量有用得多。
func _lowpass_all(cutoff: float) -> void:
	if cutoff <= 0.0:
		return
	var a := 1.0 - exp(-TAU * cutoff / float(RATE))
	var y := 0.0
	for i in _buf.size():
		y += a * (_buf[i] - y)
		_buf[i] = y

## 收尾：低通 → 归一化到 peak → 首尾各 4ms 淡入淡出（防止起止爆音）。
## peak 默认 0.62 而不是 0.92：留出余量，连点时不会一耳朵炸出来。
func _finish(peak: float = 0.62, smooth: float = 3200.0) -> PackedFloat32Array:
	_lowpass_all(smooth)
	var mx := 0.0
	for v in _buf:
		mx = maxf(mx, absf(v))
	if mx > 0.0001:
		var g := peak / mx
		for i in _buf.size():
			_buf[i] *= g
	var fade := int(0.004 * RATE)
	var n := _buf.size()
	for i in mini(fade, n / 2):
		var w := float(i) / float(fade)
		_buf[i] *= w
		_buf[n - 1 - i] *= w
	return _buf

func _to_wav(mono: PackedFloat32Array) -> PackedByteArray:
	var payload := mono.size() * 2
	var out := PackedByteArray()
	out.resize(44 + payload)
	_ascii(out, 0, "RIFF")
	out.encode_u32(4, 36 + payload)
	_ascii(out, 8, "WAVE")
	_ascii(out, 12, "fmt ")
	out.encode_u32(16, 16)
	out.encode_u16(20, 1)
	out.encode_u16(22, 1)
	out.encode_u32(24, RATE)
	out.encode_u32(28, RATE * 2)
	out.encode_u16(32, 2)
	out.encode_u16(34, 16)
	_ascii(out, 36, "data")
	out.encode_u32(40, payload)
	for i in mono.size():
		out.encode_u16(44 + i * 2, int(round(clampf(mono[i], -1.0, 1.0) * 32767.0)) & 0xFFFF)
	return out

func _ascii(out: PackedByteArray, offset: int, text: String) -> void:
	var bytes := text.to_ascii_buffer()
	for i in bytes.size():
		out[offset + i] = bytes[i]

# ---------------------------------------------------------------- 具体音效
#
# 命名规律：
#   界面类 = 单音「嘟」（高一点、干净、极短）
#   命中类 = 「啵」（三角波 + 快速下滑 + 一点噪声质感）
#   正向反馈 = 上行两三个音「叮-咚」
#   负向反馈 = 下行低音，但不用方波，靠音高而不是靠谐波来传达「不行」

func _ui_click() -> PackedFloat32Array:
	# 「嘟」：单音、中频、极短、音尾掉下来
	_seconds(0.10)
	_tone(0.0, 0.075, 880.0, 0.55, 0, 0.005, 26.0, 700.0)
	_tone(0.0, 0.055, 1760.0, 0.07, 0, 0.004, 34.0, 1400.0)
	return _finish(0.60, 3000.0)

func _ui_back() -> PackedFloat32Array:
	_seconds(0.13)
	_tone(0.0, 0.100, 660.0, 0.52, 0, 0.006, 22.0, 500.0)
	_tone(0.0, 0.070, 1320.0, 0.06, 0, 0.005, 30.0, 1050.0)
	return _finish(0.58, 2800.0)

func _ui_confirm() -> PackedFloat32Array:
	# 「嘟-嘟」上行两音：这是最典型的可爱确认音
	_seconds(0.26)
	_tone(0.0, 0.085, 784.0, 0.50, 0, 0.005, 24.0, 640.0)
	_tone(0.095, 0.130, 1174.0, 0.50, 0, 0.005, 18.0, 980.0)
	return _finish(0.62, 3200.0)

func _page() -> PackedFloat32Array:
	# 翻页：比点击更轻更短，纯正弦，不要噪声（噪声在连续翻页时会积成沙沙声）
	_seconds(0.07)
	_tone(0.0, 0.050, 1318.0, 0.34, 0, 0.004, 40.0, 1120.0)
	return _finish(0.40, 3600.0)

func _hit_light() -> PackedFloat32Array:
	# 「啵」：三角波 + 快速下滑，加一点低通噪声当打击质感
	_seconds(0.20)
	_noise(0.0, 0.055, 0.16, 46.0, 1100.0, 200.0)
	_tone(0.0, 0.150, 494.0, 0.52, 1, 0.005, 17.0, 330.0)
	_tone(0.0, 0.090, 988.0, 0.10, 0, 0.004, 26.0, 660.0)
	return _finish(0.64, 2600.0)

func _hit_crit() -> PackedFloat32Array:
	# 暴击 = 「啵」+ 上面叠一个高的「叮」，落在五度上，所以是「好听的重」而不是「刺耳的响」
	_seconds(0.34)
	_noise(0.0, 0.065, 0.18, 42.0, 1300.0, 220.0)
	_tone(0.0, 0.190, 523.0, 0.50, 1, 0.005, 14.0, 349.0)
	_tone(0.0, 0.120, 1046.0, 0.16, 0, 0.004, 20.0, 784.0)
	_tone(0.045, 0.190, 1568.0, 0.11, 0, 0.006, 15.0, 1318.0)
	return _finish(0.66, 3400.0)

func _hit_take() -> PackedFloat32Array:
	# 自己挨打：更闷更低，低通压到 1500 以下，避免和命中的「啵」混淆
	_seconds(0.26)
	_noise(0.0, 0.070, 0.14, 34.0, 520.0, 100.0)
	_tone(0.0, 0.180, 262.0, 0.50, 1, 0.006, 16.0, 175.0)
	return _finish(0.58, 1500.0)

func _skill_cast() -> PackedFloat32Array:
	# 起手：正弦上滑 + 轻微颤音，像「咻」但不带噪声，因此不刺
	_seconds(0.40)
	_tone(0.0, 0.330, 392.0, 0.46, 0, 0.020, 9.0, 784.0, 0.85, 5.5, 0.012)
	_tone(0.020, 0.180, 196.0, 0.14, 1, 0.020, 12.0, 330.0)
	return _finish(0.58, 3000.0)

func _heal() -> PackedFloat32Array:
	# 上行三音「叮-叮-咚」，软起音、长衰减
	_seconds(0.90)
	var notes := [659.25, 783.99, 1046.5]
	for k in notes.size():
		_tone(0.075 * float(k), 0.52, notes[k], 0.44, 0, 0.014, 5.2, notes[k] * 0.98)
	_tone(0.20, 0.45, 2093.0, 0.05, 0, 0.020, 7.0)
	return _finish(0.60, 4200.0)

func _shield() -> PackedFloat32Array:
	# 水膜：正弦上下摆动 + 颤音，纯粹的正弦所以很软
	_seconds(0.55)
	_tone(0.0, 0.430, 523.0, 0.44, 0, 0.014, 6.5, 784.0, 0.75, 7.0, 0.018)
	_tone(0.030, 0.300, 1046.0, 0.07, 0, 0.012, 9.0, 1318.0)
	return _finish(0.56, 3400.0)

func _bind() -> PackedFloat32Array:
	# 泡泡：三个短促上行的「啵」，像水里冒泡
	_seconds(0.42)
	for k in 3:
		var t := 0.085 * float(k)
		var f := 440.0 + 150.0 * float(k)
		_tone(t, 0.095, f, 0.46, 0, 0.005, 24.0, f * 1.28)
	return _finish(0.58, 3200.0)

func _link_ready() -> PackedFloat32Array:
	# 连携就绪：柔起的和弦，营造「可以了」的期待感，不用刺亮的高音
	_seconds(1.10)
	for f in [523.25, 659.25, 783.99]:
		_tone(0.0, 0.85, f, 0.30, 0, 0.045, 3.0, f * 0.995)
	_tone(0.10, 0.55, 1568.0, 0.05, 0, 0.060, 5.5)
	return _finish(0.60, 3600.0)

func _link_cast() -> PackedFloat32Array:
	# 大招：和弦 + 上滑，尾音长一点，但依然全是正弦三角
	_seconds(1.40)
	for f in [392.0, 523.25, 659.25, 1046.5]:
		_tone(0.0, 1.05, f, 0.28, 1, 0.035, 2.6, f * 0.99)
	_tone(0.06, 0.75, 784.0, 0.14, 0, 0.030, 3.4, 1568.0, 0.85)
	return _finish(0.68, 4000.0)

func _enemy_down() -> PackedFloat32Array:
	# 敌人倒下：三角波下行（原来是锯齿波，那个波形天生刺耳）
	_seconds(0.70)
	_tone(0.0, 0.520, 440.0, 0.48, 1, 0.008, 5.4, 165.0, 0.7)
	_tone(0.0, 0.220, 220.0, 0.16, 0, 0.008, 8.0, 110.0)
	return _finish(0.58, 2000.0)

func _flee() -> PackedFloat32Array:
	# 脱身：低通噪声的下扫（风声感）压得很低 + 一个软下滑音，不做「呼——」的高频嘶声
	_seconds(0.44)
	_noise(0.0, 0.300, 0.16, 10.0, 1500.0, 260.0, 320.0)
	_tone(0.0, 0.240, 392.0, 0.26, 0, 0.018, 9.0, 262.0, 0.8)
	return _finish(0.50, 2400.0)

func _invalid() -> PackedFloat32Array:
	# 「不行」：两个下行低音。用音高表达否定，不用方波的谐波（那是「刺耳」的来源）
	_seconds(0.28)
	_tone(0.0, 0.090, 330.0, 0.46, 1, 0.006, 22.0, 262.0)
	_tone(0.130, 0.115, 262.0, 0.44, 1, 0.006, 18.0, 208.0)
	return _finish(0.56, 2000.0)

func _pickup() -> PackedFloat32Array:
	# 「叮-咚」：两个上行正弦，经典可爱拾取音
	_seconds(0.40)
	_tone(0.0, 0.150, 1046.5, 0.50, 0, 0.004, 13.0, 988.0)
	_tone(0.095, 0.230, 1568.0, 0.46, 0, 0.004, 10.0, 1480.0)
	return _finish(0.62, 4200.0)

func _chest_open() -> PackedFloat32Array:
	# 开箱：极低通的木箱质感 + 上行四音，把「吱呀」压到几乎听不见
	_seconds(0.90)
	_noise(0.0, 0.240, 0.13, 13.0, 480.0, 120.0, 900.0)
	for k in 3:
		var f := 784.0 * pow(1.26, float(k))
		_tone(0.235 + 0.105 * float(k), 0.230, f, 0.40, 0, 0.005, 12.0, f * 0.97)
	return _finish(0.62, 4000.0)

func _level_up() -> PackedFloat32Array:
	# 升级：上行四音「叮-叮-咚-咚」，软起音，最后停在主音上（有结束感）
	_seconds(1.35)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for k in notes.size():
		_tone(0.115 * float(k), 0.62, notes[k], 0.44, 1, 0.010, 3.6, notes[k] * 0.99)
	_tone(0.46, 0.72, 2093.0, 0.07, 0, 0.030, 3.2)
	return _finish(0.66, 4400.0)

func _equip() -> PackedFloat32Array:
	# 装备：两个很短的软「嗒」，中频，不要金属泛音
	_seconds(0.24)
	_tone(0.0, 0.070, 1046.5, 0.42, 1, 0.004, 30.0, 880.0)
	_tone(0.085, 0.095, 1318.5, 0.38, 1, 0.004, 24.0, 1120.0)
	return _finish(0.56, 3200.0)

func _door() -> PackedFloat32Array:
	# 开门：低通噪声的软下扫（气流感），加一个很低的三角垫底
	_seconds(0.46)
	_noise(0.0, 0.300, 0.13, 9.0, 700.0, 140.0, 260.0)
	_tone(0.0, 0.220, 175.0, 0.26, 1, 0.014, 12.0, 117.0, 0.8)
	return _finish(0.50, 1800.0)

func _encounter() -> PackedFloat32Array:
	# 遭遇提示：两个下行低音，可爱里带一点「有点不妙」。
	# 用音高（而不是失真或噪声）表达紧张，所以既不刺耳也还是提示得到。
	_seconds(0.80)
	_tone(0.0, 0.300, 294.0, 0.42, 1, 0.016, 8.0, 233.0)
	_tone(0.190, 0.380, 220.0, 0.40, 1, 0.016, 6.5, 175.0)
	_tone(0.190, 0.240, 880.0, 0.045, 0, 0.030, 9.0)
	return _finish(0.56, 2200.0)

func _type_tick() -> PackedFloat32Array:
	# 打字机：极短极轻的正弦小点。这里绝对不能用噪声 ——
	# 打字是每秒好几个的高频重复事件，噪声会累积成一层沙沙声。
	_seconds(0.055)
	_tone(0.0, 0.038, 1568.0, 0.30, 0, 0.003, 46.0, 1318.0)
	return _finish(0.34, 4200.0)

# ---------------------------------------------------------------- 对外

func render(name: String) -> PackedFloat32Array:
	_rng.seed = 20261003          # 固定种子：同样的参数永远得到同样的结果
	match name:
		"ui_click":
			return _ui_click()
		"ui_back":
			return _ui_back()
		"ui_confirm":
			return _ui_confirm()
		"page":
			return _page()
		"hit_light":
			return _hit_light()
		"hit_crit":
			return _hit_crit()
		"hit_take":
			return _hit_take()
		"skill_cast":
			return _skill_cast()
		"heal":
			return _heal()
		"shield":
			return _shield()
		"bind":
			return _bind()
		"link_ready":
			return _link_ready()
		"link_cast":
			return _link_cast()
		"enemy_down":
			return _enemy_down()
		"flee":
			return _flee()
		"invalid":
			return _invalid()
		"pickup":
			return _pickup()
		"chest_open":
			return _chest_open()
		"level_up":
			return _level_up()
		"equip":
			return _equip()
		"door":
			return _door()
		"encounter":
			return _encounter()
		"type_tick":
			return _type_tick()
	return PackedFloat32Array()

func write(name: String) -> Dictionary:
	var mono := render(name)
	if mono.is_empty():
		return {"name": name, "ok": false, "error": "未知音效"}
	var wav := _to_wav(mono)
	var folder := ProjectSettings.globalize_path(OUT_REL)
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join(name + ".wav")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"name": name, "ok": false, "error": "无法写入 " + path}
	f.store_buffer(wav)
	f.close()
	return {
		"name": name,
		"ok": true,
		"bytes": wav.size(),
		"seconds": snappedf(float(mono.size()) / float(RATE), 0.01),
	}

func write_all() -> Array:
	var report: Array = []
	for name in NAMES:
		report.append(write(str(name)))
	return report
