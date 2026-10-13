extends RefCounted
## 《玻璃温室》工具链 —— DSP 工具箱。
##
## 纪律：本文件所有函数都是**纯函数** —— 只读入参、写局部缓冲、返回新数组。
## 绝不能原地改传进来的 Packed*Array：Godot 的 Packed 数组是写时复制，
## 函数参数持有一份引用，在函数内写元素会触发复制，改动悄悄丢掉。
## 需要原地累加的地方（混音）一律放在拥有该数组的那个函数里做。

const COMB_TUNE_44K := [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
const ALLPASS_TUNE_L_44K := [556, 441, 341, 225]
const ALLPASS_TUNE_R_44K := [579, 464, 364, 248]


## 固定种子的随机数发生器 —— 保证每次渲染结果完全可复现。
static func rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


## RBJ 峰值均衡。返回 [b0, b1, b2, a1, a2]（a0 已归一）。
static func coeff_peaking(sr: float, f: float, q: float, db: float) -> PackedFloat64Array:
	var a := pow(10.0, db / 40.0)
	var w := TAU * f / sr
	var alpha := sin(w) / (2.0 * q)
	var cw := cos(w)
	var a0 := 1.0 + alpha / a
	var co := PackedFloat64Array()
	co.resize(5)
	co[0] = (1.0 + alpha * a) / a0
	co[1] = (-2.0 * cw) / a0
	co[2] = (1.0 - alpha * a) / a0
	co[3] = (-2.0 * cw) / a0
	co[4] = (1.0 - alpha / a) / a0
	return co


## RBJ 低通。
static func coeff_lowpass(sr: float, f: float, q: float) -> PackedFloat64Array:
	var w := TAU * f / sr
	var alpha := sin(w) / (2.0 * q)
	var cw := cos(w)
	var a0 := 1.0 + alpha
	var co := PackedFloat64Array()
	co.resize(5)
	co[0] = (1.0 - cw) * 0.5 / a0
	co[1] = (1.0 - cw) / a0
	co[2] = co[0]
	co[3] = (-2.0 * cw) / a0
	co[4] = (1.0 - alpha) / a0
	return co


## RBJ 高通。
static func coeff_highpass(sr: float, f: float, q: float) -> PackedFloat64Array:
	var w := TAU * f / sr
	var alpha := sin(w) / (2.0 * q)
	var cw := cos(w)
	var a0 := 1.0 + alpha
	var co := PackedFloat64Array()
	co.resize(5)
	co[0] = (1.0 + cw) * 0.5 / a0
	co[1] = -(1.0 + cw) / a0
	co[2] = co[0]
	co[3] = (-2.0 * cw) / a0
	co[4] = (1.0 - alpha) / a0
	return co


## RBJ 高架（用于磁带式高频缓降）。
static func coeff_highshelf(sr: float, f: float, q: float, db: float) -> PackedFloat64Array:
	var a := pow(10.0, db / 40.0)
	var w := TAU * f / sr
	var cw := cos(w)
	var sw := sin(w)
	var alpha := sw / (2.0 * q)
	var beta := 2.0 * sqrt(a) * alpha
	var a0 := (a + 1.0) - (a - 1.0) * cw + beta
	var co := PackedFloat64Array()
	co.resize(5)
	co[0] = a * ((a + 1.0) + (a - 1.0) * cw + beta) / a0
	co[1] = -2.0 * a * ((a - 1.0) + (a + 1.0) * cw) / a0
	co[2] = a * ((a + 1.0) + (a - 1.0) * cw - beta) / a0
	co[3] = 2.0 * ((a - 1.0) - (a + 1.0) * cw) / a0
	co[4] = ((a + 1.0) - (a - 1.0) * cw - beta) / a0
	return co


## 双二阶（Direct Form 1），返回新数组。
static func filter(x: PackedFloat32Array, co: PackedFloat64Array) -> PackedFloat32Array:
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var b0 := co[0]
	var b1 := co[1]
	var b2 := co[2]
	var a1 := co[3]
	var a2 := co[4]
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var xi := x[i]
		var y := b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = y
		out[i] = y
	return out


## 依次串起多个双二阶。
static func filter_chain(x: PackedFloat32Array, coeffs: Array) -> PackedFloat32Array:
	var cur := x
	for co in coeffs:
		cur = filter(cur, co)
	return cur


## 音板共鸣：几个固定峰把干巴巴的合成正弦“架”成有木头的钢琴。
## 这几个峰对所有音是同一组，是线性时不变处理，
## 所以放在混音之后做一次，与逐个单音做在数学上等价，但快一个数量级。
static func soundboard_eq(x: PackedFloat32Array, sr: float) -> PackedFloat32Array:
	var co := [
		coeff_highpass(sr, 22.0, 0.707),        # 清掉直流与次声，最低的 F1（43.6 Hz）远在其上
		coeff_peaking(sr, 105.0, 1.1, 3.5),
		coeff_peaking(sr, 260.0, 1.4, -2.0),
		coeff_peaking(sr, 780.0, 1.0, 2.5),
		coeff_peaking(sr, 2450.0, 1.2, -3.0),
		coeff_highshelf(sr, 9000.0, 0.7, -6.0),
	]
	return filter_chain(x, co)


## 单极点低通（便宜的高频缓降）。
static func onepole_lowpass(x: PackedFloat32Array, sr: float, cutoff: float) -> PackedFloat32Array:
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var k := 1.0 - exp(-TAU * cutoff / sr)
	var y := 0.0
	for i in n:
		y += k * (x[i] - y)
		out[i] = y
	return out


## 施罗德全通链（Freeverb 的扩散级）。
static func allpass_chain(x: PackedFloat32Array, tunings: Array, sr: float, feedback: float) -> PackedFloat32Array:
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var count := tunings.size()
	var total := 0
	var off := PackedInt32Array()
	off.resize(count)
	var ln := PackedInt32Array()
	ln.resize(count)
	for c in count:
		ln[c] = maxi(1, int(round(float(tunings[c]) * sr / 44100.0)))
		off[c] = total
		total += ln[c]
	var buf := PackedFloat32Array()
	buf.resize(total)
	var idx := PackedInt32Array()
	idx.resize(count)
	for i in n:
		var v := x[i]
		for c in count:
			var base := off[c]
			var j := idx[c]
			var bv := buf[base + j]
			var o := -v + bv
			buf[base + j] = v + bv * feedback
			j += 1
			if j >= ln[c]:
				j = 0
			idx[c] = j
			v = o
		out[i] = v
	return out


## Freeverb 大厅，返回 [左, 右]。两声道共用梳状滤波器组，
## 再走两条不同调谐的全通链做去相关 —— 便宜的立体声宽度。
static func freeverb_stereo(x: PackedFloat32Array, sr: float, room: float, damp: float) -> Array:
	var n := x.size()
	var scale := sr / 44100.0
	var count := COMB_TUNE_44K.size()
	var total := 0
	var coff := PackedInt32Array()
	coff.resize(count)
	var clen := PackedInt32Array()
	clen.resize(count)
	for c in count:
		clen[c] = maxi(1, int(round(float(COMB_TUNE_44K[c]) * scale)))
		coff[c] = total
		total += clen[c]
	var cbuf := PackedFloat32Array()
	cbuf.resize(total)
	var cidx := PackedInt32Array()
	cidx.resize(count)
	var cstore := PackedFloat32Array()
	cstore.resize(count)

	var sum := PackedFloat32Array()
	sum.resize(n)
	var fb := room * 0.28 + 0.7
	var d1 := damp * 0.4
	var inv := 1.0 / float(count)
	for i in n:
		var inp := x[i] * 0.015
		var acc := 0.0
		for c in count:
			var base := coff[c]
			var j := cidx[c]
			var bv := cbuf[base + j]
			var st := cstore[c]
			st = bv * (1.0 - d1) + st * d1
			cstore[c] = st
			cbuf[base + j] = inp + st * fb
			j += 1
			if j >= clen[c]:
				j = 0
			cidx[c] = j
			acc += bv
		sum[i] = acc * inv

	var wl := allpass_chain(sum, ALLPASS_TUNE_L_44K, sr, 0.5)
	var wr := allpass_chain(sum, ALLPASS_TUNE_R_44K, sr, 0.5)
	return [wl, wr]


## 预延迟：把混响整体往后推，让直达声先到 —— 大厅感的关键。
static func predelay(x: PackedFloat32Array, sr: float, ms: float) -> PackedFloat32Array:
	var d := int(round(ms * sr / 1000.0))
	if d <= 0:
		return x
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var i := d
	while i < n:
		out[i] = x[i - d]
		i += 1
	return out


## 温和软限幅：只在超过阈值时介入，避免给整条母带染色。
static func soft_clip(x: PackedFloat32Array, ceiling: float) -> PackedFloat32Array:
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var knee := ceiling * 0.7
	for i in n:
		var v := x[i]
		if v > knee:
			v = ceiling * tanh(v / ceiling)
		elif v < -knee:
			v = -ceiling * tanh(-v / ceiling)
		out[i] = v
	return out


static func peak(x: PackedFloat32Array) -> float:
	var p := 0.0
	for v in x:
		var a: float = absf(v)
		if a > p:
			p = a
	return p


static func scale(x: PackedFloat32Array, gain: float) -> PackedFloat32Array:
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = x[i] * gain
	return out


## 等功率声像：pan = -1 全左，+1 全右。返回 [左增益, 右增益]。
static func pan_gains(pan: float) -> Array:
	var p := clampf(pan, -1.0, 1.0)
	var a := (p + 1.0) * PI * 0.25
	return [cos(a), sin(a)]


## 极低电平的房间底噪 —— 让 wav 不至于“死寂”，是 gal BGM 的常见手感。
static func noise_floor(n: int, r: RandomNumberGenerator, amplitude: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var w := r.randf_range(-1.0, 1.0)
		y += 0.25 * (w - y)
		out[i] = y * amplitude
	return out
