extends RefCounted
## 《玻璃温室》钢琴音源 —— 模态谐振器组（modal / struck-string）合成。
##
## 为什么不用逐样本 sin() 叠加：实测 GDScript 只有约 5.4M 分音-采样/秒。
## 每个分音用一对极点谐振器 y = 2r·cosω·y₁ − r²·y₂，
## 靠初始条件 y[0]=0、y[1]=A·r·sinω 直接给出 A·rⁿ·sin(nω)，
## 指数衰减是“免费”的，不需要逐样本乘包络。
##
## 制音器用分段实现：松键前用较长的 T60，松键后换成很短的 T60，
## 相位与幅度连续，听感上就是真实的“放掉琴键”。
##
## 音板共鸣（soundboard_eq）**不在**这里做 —— 那是线性时不变处理，
## 与求和可交换，放到混音之后统一做一次即可，代价从“每个音一次”降到“每首一次”。

const SR := 44100
const VEL_LEVELS := 16
const DUR_BUCKETS := [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 6.0, 9.0]

const Theory := preload("res://tools/bgm_glasshouse/theory.gd")
const Dsp := preload("res://tools/bgm_glasshouse/dsp.gd")

## 单音缓存：键是 "预设:音高:力度层:时值桶"。返回的数组只读，调用方禁止原地修改。
static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func cache_size() -> int:
	return _cache.size()


## 三角钢琴。
const PIANO := {
	"partials_max": 24,
	"tilt_lo": 2.05,          # 弱奏 → 高次分音压得狠（音色暗）
	"tilt_hi": 0.95,          # 强奏 → 谱线变平（音色亮）
	"inharm_lo": 0.00085,     # 非谐性：低音区强
	"inharm_hi": 0.00016,     # 高音区弱
	"t60_lo": 14.0,           # 最低音区基音 T60（秒）
	"t60_hi": 1.15,           # 最高音区
	"spread": 0.30,           # 高次分音衰减更快
	"t60_damp_lo": 1.25,      # 松键后制音器的 T60
	"t60_damp_hi": 0.22,
	"unison": 2,              # 双弦，产生真实的拍频滚动
	"detune_cents": 0.7,
	"hammer_gain": 0.06,      # 击槌噪声，给出手感
	"attack_sec": 0.0,
	"release_sec": 0.0,
	"tremolo_hz": 0.0,
	"tremolo_depth": 0.0,
}


static func _bucket_index(dur: float) -> int:
	for i in DUR_BUCKETS.size():
		if float(DUR_BUCKETS[i]) >= dur:
			return i
	return DUR_BUCKETS.size() - 1


## 带缓存的取音 —— 同一 (预设, 音高, 力度层, 时值桶) 只算一次。
static func render(preset_name: String, preset: Dictionary, m: int, vel: float, dur: float) -> PackedFloat32Array:
	var vb := clampi(int(round(vel * float(VEL_LEVELS))), 1, VEL_LEVELS)
	var db := _bucket_index(dur)
	var key := "%s:%d:%d:%d" % [preset_name, m, vb, db]
	var hit: Variant = _cache.get(key)
	if hit != null:
		return hit
	var buf := _render(m, float(vb) / float(VEL_LEVELS), float(DUR_BUCKETS[db]), preset)
	_cache[key] = buf
	return buf


static func _render(m: int, vel: float, dur: float, p: Dictionary) -> PackedFloat32Array:
	var sr := float(SR)
	var f0 := Theory.freq(float(m))
	var nyq := sr * 0.5
	# t: 0 = 最低音区, 1 = 最高音区
	var t := clampf((float(m) - 21.0) / 87.0, 0.0, 1.0)
	var k_nyq := int(floor(nyq / f0))
	var k_max := mini(k_nyq, int(p.partials_max))
	if k_max < 1:
		return PackedFloat32Array()

	var bright := clampf(0.30 + 0.70 * vel, 0.0, 1.0)
	var k_use := clampi(int(round(float(k_max) * lerpf(0.45, 1.0, bright))), 1, k_max)
	var tilt := lerpf(float(p.tilt_lo), float(p.tilt_hi), bright)
	var b_inh := lerpf(float(p.inharm_lo), float(p.inharm_hi), t)
	var t60_1 := lerpf(float(p.t60_lo), float(p.t60_hi), pow(t, 0.72))
	var spread := float(p.spread)
	var unison := maxi(1, int(p.unison))
	var detune := float(p.detune_cents)

	# --- 1) 把所有 (分音 × 弦) 展开成参数表 ---
	var fs := PackedFloat64Array()
	var amps := PackedFloat64Array()
	var t60s := PackedFloat64Array()
	var amp_sum := 0.0
	for k in range(1, k_use + 1):
		var fk := float(k) * f0 * sqrt(1.0 + b_inh * float(k * k))
		if fk >= nyq:
			break
		var a := pow(float(k), -tilt)
		# 超过 k_use 的部分平滑淡出，避免生硬地“砍掉”高频
		a *= 1.0 / (1.0 + pow(float(k) / float(k_use), 6.0))
		var tk := t60_1 / (1.0 + spread * float(k - 1))
		for u in unison:
			var cents := 0.0
			var ud := 0.0
			if unison > 1:
				ud = float(u) / float(unison - 1) * 2.0 - 1.0
				cents = detune * ud
			var fm := fk * pow(2.0, cents / 1200.0)
			if fm >= nyq:
				continue
			var au := a
			if unison > 1:
				# 正中的那根弦最响，两侧略轻
				au *= 1.0 - 0.10 * absf(ud)
			fs.append(fm)
			amps.append(au)
			t60s.append(tk * (1.0 + 0.05 * ud))
			amp_sum += au
	if fs.is_empty() or amp_sum <= 0.0:
		return PackedFloat32Array()

	# vel^1.5 接近真实钢琴的力度—响度曲线
	var norm := (1.0 / amp_sum) * pow(vel, 1.5) * 0.95

	var off_samples := int(round(dur * sr))
	var t60_damp := lerpf(float(p.t60_damp_lo), float(p.t60_damp_hi), t)
	var damp_frames := int(round(minf(2.2, t60_damp * 1.25) * sr))
	var total := maxi(off_samples + damp_frames, 32)
	var out := PackedFloat32Array()
	out.resize(total)

	# --- 2) 谐振器 ---
	for idx in fs.size():
		var fk := fs[idx]
		var amp := amps[idx] * norm
		var tk := t60s[idx]
		var w := TAU * fk / sr
		var cosw := cos(w)
		var r_sus := pow(0.001, 1.0 / (tk * sr))
		var a1s := 2.0 * r_sus * cosw
		var a2s := r_sus * r_sus
		var t_sus_90 := tk * 1.5
		# 只跑到「自然衰减到 −90 dB」或「松键」两者中先到的那个。
		# 已经听不见的分音没必要继续算，后面的制音段对它也没有意义 ——
		# 这一条能省掉大约四分之一的分音计算量。
		var n_sus := mini(off_samples, int(round(t_sus_90 * sr)))
		n_sus = mini(n_sus, total)
		if n_sus < 2:
			continue
		var y1 := amp * r_sus * sin(w)
		var y2 := 0.0
		out[1] += y1
		var i := 2
		while i < n_sus:
			var y := a1s * y1 - a2s * y2
			y2 = y1
			y1 = y
			out[i] += y
			i += 1
		if n_sus >= off_samples and off_samples >= 2 and total > off_samples:
			var r_d := pow(0.001, 1.0 / (t60_damp * sr))
			var a1d := 2.0 * r_d * cosw
			var a2d := r_d * r_d
			i = off_samples
			while i < total:
				var y := a1d * y1 - a2d * y2
				y2 = y1
				y1 = y
				out[i] += y
				i += 1

	# --- 3) 击槌噪声：一次微分把低频“咚”变成“嗒” ---
	var hg := float(p.hammer_gain) * vel
	if hg > 0.0:
		var bl := mini(int(0.0045 * sr), total)
		var rz := Dsp.rng(m * 7919 + int(vel * 997.0) + 13)
		var prev := 0.0
		for b in bl:
			var e := 1.0 - float(b) / float(maxi(1, bl))
			var raw := rz.randf_range(-1.0, 1.0)
			var hp := raw - prev
			prev = raw
			out[b] += hp * e * e * hg * 0.5

	# --- 4) 起音斜坡 / 松键斜坡 / 颤音（弦乐垫与音乐盒用） ---
	var atk := float(p.attack_sec)
	if atk > 0.0:
		var al := mini(int(atk * sr), total)
		for b in al:
			out[b] *= float(b) / float(maxi(1, al))
	var rel := float(p.release_sec)
	if rel > 0.0 and off_samples < total:
		var rl := mini(int(rel * sr), total - off_samples)
		for b in rl:
			out[off_samples + b] *= 1.0 - float(b) / float(maxi(1, rl))
	var thz := float(p.tremolo_hz)
	if thz > 0.0:
		var dep := float(p.tremolo_depth)
		var ph := 0.0
		var dph := TAU * thz / sr
		for b in total:
			out[b] *= 1.0 + dep * sin(ph)
			ph += dph

	return out
