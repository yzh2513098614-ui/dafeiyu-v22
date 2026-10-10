extends RefCounted
## 大肥鱼 · 环境音（音景）合成器 —— **当前未启用**
##
## 生成出来的 4 段环境音目前游戏里不用（见 sound/ambience_director.gd 顶部的说明）。
## 这个生成器保留着：素材是无损再生资源，但生成它的逻辑（无缝循环折叠、
## 循环安全混响、周期整除循环长度的包络）是可复用的，删了要重写。
## 想重新启用：跑 write_all() 生成 wav，再把 AmbienceDirector 注册成 autoload。
##
## 和音效的区别在两点，也是这个文件存在的理由：
##   1. **必须无缝循环**。环境音是一放几十分钟的底噪，接缝处「咔」一下比没有更糟。
##   2. **需要混响尾巴**，否则室外的空旷感和室内的闷感做不出来。
##
## 无缝循环怎么做的：先按 len+fade 秒渲染，再把多出来的那段尾巴按
## 淡入淡出叠回开头（见 _loop_fold）。这样第 n 个采样接回第 0 个采样时，
## 0..fade 区间里已经混着「本该跟在 n 后面」的内容，所以听不出接缝。
##
## 混响也要循环安全：延迟线长度对缓冲区取模，尾巴从结尾绕回开头
## （见 _loop_reverb）。用普通的混响，尾巴会在循环点被切断。
##
## 包络全部用「周期能整除循环长度」的正弦叠加 —— 只要周期是 len/k，
## 第 0 秒和第 len 秒的包络值就完全相等，涌浪不会在接缝处跳变。
##
## 输出：assets/ambience/<名称>.wav，16bit 单声道 22050Hz。
## 用法：var a = load("res://tools/ambience_synth.gd").new(); a.write_all()

const RATE := 22050
const OUT_REL := "res://assets/ambience"

const NAMES: Array = ["amb_sea_day", "amb_sea_night", "amb_indoor", "amb_trial"]

var _buf := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------- 基础

func _seconds(sec: float) -> void:
	_buf = PackedFloat32Array()
	_buf.resize(maxi(1, int(sec * RATE)))
	_buf.fill(0.0)

## 把尾巴叠回开头，得到一个可无缝循环的缓冲区。
## fade 越长接缝越糊（但太短又会有可听的交叉点），1.0~1.5 秒对海浪刚好。
##
## 注意：这里**原地修改 _buf、不返回数组**。第一版写成了「返回新数组」，
## 结果调用方 `_loop_fold(fade)` 丢掉了返回值，折叠白算了一场，
## 文件长度还停在 total+fade（9.3s 而不是 8.0s）—— 是靠量文件时长才发现的。
## 改成原地修改之后，调用方不可能再忘。
func _loop_fold(fade_sec: float) -> void:
	var f := int(fade_sec * RATE)
	var n := _buf.size() - f
	if n <= f * 2 or f <= 0:
		return
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = _buf[i]
	for i in f:
		var w := float(i) / float(f)
		out[i] = _buf[i] * w + _buf[n + i] * (1.0 - w)
	_buf = out

## 循环安全的梳状混响：延迟线在缓冲区长度内取模绕回，
## 所以湿声不会在循环点被截断。offset 单位是采样数，必须小于缓冲区长度。
func _loop_reverb(mix: float, decay: float, offsets: Array) -> void:
	var n := _buf.size()
	var wet := PackedFloat32Array()
	wet.resize(n)
	wet.fill(0.0)
	var scale := 1.0 / float(offsets.size())
	for base in offsets:
		var d := int(base) % n
		if d < 4:
			continue
		var line := PackedFloat32Array()
		line.resize(d)
		var idx := 0
		var damp := 0.0
		for i in n:
			var y := line[idx]
			damp = y * 0.30 + damp * 0.70
			line[idx] = _buf[i] + damp * decay
			wet[i] += y * scale
			idx += 1
			if idx >= d:
				idx = 0
	for i in n:
		_buf[i] += wet[i] * mix

## 归一化 + 直流滤除。**不能加首尾淡入淡出** —— 那是给一次性音效用的，
## 加上去循环点反而会变成一段静音。
func _finish_loop(peak: float = 0.85) -> PackedFloat32Array:
	# 直流滤除：包络里如果有常数项，叠加后会产生直流偏移，接耳机时是「噗」声
	var mean := 0.0
	for v in _buf:
		mean += v
	mean /= maxf(1.0, float(_buf.size()))
	for i in _buf.size():
		_buf[i] -= mean
	var mx := 0.0
	for v in _buf:
		mx = maxf(mx, absf(v))
	if mx > 0.0001:
		var g := peak / mx
		for i in _buf.size():
			_buf[i] *= g
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

# ---------------------------------------------------------------- 海

## 海：三层带通噪声，各走一个自己的慢包络。
##   surf  低频涌动，决定「浪有多大」
##   wash  中频碎浪，决定「浪拍在岸上的哗」
##   wind  高频，决定「风有多响」
## 三层的周期分别是 len/3、len/5、len/1 —— 都是 len 的整数分之一，所以循环无缝。
func _sea(night: bool) -> PackedFloat32Array:
	var total := 8.0
	var fade := 1.3
	_seconds(total + fade)
	var n := _buf.size()

	var swell_period := total / 3.0
	var crash_period := total / 5.0
	# 夜里的浪更慢更长，风更小，碎浪更少 —— 是「远处退潮」而不是「白天拍岸」
	var swell_amp := 0.50 if night else 0.58
	var crash_amp := 0.16 if night else 0.34
	var wind_amp := 0.045 if night else 0.11
	var cut_surf := 380.0 if night else 440.0
	var cut_wash := 1300.0 if night else 1800.0
	var cut_wind := 4200.0 if night else 5400.0

	var y_surf := 0.0
	var y_wash := 0.0
	var y_wind := 0.0
	var a_surf := 1.0 - exp(-TAU * cut_surf / float(RATE))
	var a_wash := 1.0 - exp(-TAU * cut_wash / float(RATE))
	var a_wind := 1.0 - exp(-TAU * cut_wind / float(RATE))
	for i in n:
		var t := float(i) / float(RATE)
		var raw := _rng.randf_range(-1.0, 1.0)
		# 涌动：正半周抬高、负半周压低，但不要归零（归零会有「呼吸暂停」感）
		var swell := 0.55 + 0.45 * sin(TAU * t / swell_period)
		# 碎浪：用三次方把正弦压成短促的尖峰，得到「哗——」而不是「嗡——」
		var crash := pow(maxf(0.0, sin(TAU * t / crash_period + 1.1)), 3.0)
		var breeze := 0.55 + 0.45 * sin(TAU * t / total + 0.7)
		y_surf += a_surf * (raw - y_surf)
		y_wash += a_wash * (raw - y_wash)
		y_wind += a_wind * (raw - y_wind)
		var v := 0.0
		v += y_surf * swell_amp * swell
		v += (y_wash - y_surf) * crash_amp * crash
		v += (y_wind - y_wash) * wind_amp * breeze
		_buf[i] = v
	# 顺序不能反：先折叠成循环，再做混响。
	# 混响本身是循环安全的（延迟线取模绕回），但它必须在「已经是循环」的信号上跑，
	# 否则折叠加在混响之后会把刚做好的混响尾巴切掉。
	_loop_fold(fade)
	if night:
		_loop_reverb(0.30, 0.60, [1153, 1439, 1721])
	else:
		_loop_reverb(0.18, 0.55, [1153, 1439])
	return _finish_loop(0.82)

# ---------------------------------------------------------------- 室内

## 室内：极轻的房间底噪 + 50Hz 电源嗡声。
## 50Hz 在 6 秒里正好 300 个周期，所以嗡声本身也是无缝的。
func _indoor() -> PackedFloat32Array:
	var total := 6.0
	var fade := 1.0
	_seconds(total + fade)
	var n := _buf.size()
	var y_low := 0.0
	var y_air := 0.0
	var a_low := 1.0 - exp(-TAU * 260.0 / float(RATE))
	var a_air := 1.0 - exp(-TAU * 2400.0 / float(RATE))
	for i in n:
		var t := float(i) / float(RATE)
		var raw := _rng.randf_range(-1.0, 1.0)
		y_low += a_low * (raw - y_low)
		y_air += a_air * (raw - y_air)
		# 房间的「呼吸」：一次完整的强弱起伏
		var room := 0.75 + 0.25 * sin(TAU * t / total)
		# 50Hz 嗡声 + 二次谐波（家用电器那味），幅度压得很低，只在安静时才听得出
		var hum := sin(TAU * 50.0 * t) * 0.055 + sin(TAU * 100.0 * t) * 0.022
		_buf[i] = y_low * 0.30 * room + (y_air - y_low) * 0.045 * room + hum * room
	# 先折叠成循环，再做混响（理由同 _sea）
	_loop_fold(fade)
	# 小房间的短混响：延迟短、衰减快
	_loop_reverb(0.22, 0.42, [431, 587, 733])
	return _finish_loop(0.62)

# ---------------------------------------------------------------- 试炼场

## 试炼场：还是海，但更空旷、更冷、混响更长 —— 要能和鲸落港的海区分开。
## 做法是压低碎浪（没有岸可拍）、拉长涌动、加重混响。
func _trial() -> PackedFloat32Array:
	var total := 8.0
	var fade := 1.3
	_seconds(total + fade)
	var n := _buf.size()
	var y_surf := 0.0
	var y_wind := 0.0
	var a_surf := 1.0 - exp(-TAU * 300.0 / float(RATE))
	var a_wind := 1.0 - exp(-TAU * 3600.0 / float(RATE))
	for i in n:
		var t := float(i) / float(RATE)
		var raw := _rng.randf_range(-1.0, 1.0)
		var swell := 0.45 + 0.55 * sin(TAU * t / (total / 2.0))
		var breeze := 0.5 + 0.5 * sin(TAU * t / total + 2.2)
		y_surf += a_surf * (raw - y_surf)
		y_wind += a_wind * (raw - y_wind)
		var v := 0.0
		v += y_surf * 0.62 * swell
		v += (y_wind - y_surf) * 0.07 * breeze
		_buf[i] = v
	# 先折叠成循环，再做混响（理由同 _sea）
	_loop_fold(fade)
	# 长混响：这是「试炼场」和「港口」听感上最主要的差别
	_loop_reverb(0.55, 0.72, [1153, 1439, 1721, 2003, 2311])
	return _finish_loop(0.80)

# ---------------------------------------------------------------- 对外

func render(name: String) -> PackedFloat32Array:
	match name:
		"amb_sea_day":
			_rng.seed = 20261004
			return _sea(false)
		"amb_sea_night":
			_rng.seed = 20261005
			return _sea(true)
		"amb_indoor":
			_rng.seed = 20261006
			return _indoor()
		"amb_trial":
			_rng.seed = 20261007
			return _trial()
	return PackedFloat32Array()

func write(name: String) -> Dictionary:
	var mono := render(name)
	if mono.is_empty():
		return {"name": name, "ok": false, "error": "未知环境音"}
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
