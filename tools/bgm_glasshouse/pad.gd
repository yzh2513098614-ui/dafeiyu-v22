extends RefCounted
## 《玻璃温室》弦乐 / PAD 垫底音色 —— 本版相对「纯钢琴」的主要差异点。
##
## 与钢琴的根本不同：pad 是持续音，不需要吉他式衰减。所以这里只为每个音高
## 渲染一条「起音 + 稳态循环」的波形，混音时把稳态段反复铺满时值即可。
## 于是长音的成本只与**音高种类数**成正比，与曲子长短无关 ——
## 如果用钢琴那套模态引擎去渲 14 秒的长音，单音就要 5 秒，六首曲子会跑不完。
##
## 稳态段严格取整数个基频周期（periods 为整数），循环点天然无缝，不需要交叉淡化。
## 代价是失去弦乐的轻微去谐合唱感；这条由混音期的缓慢呼吸（0.08 Hz）与共享混响补回。

const SR := 44100
const Theory := preload("res://tools/bgm_glasshouse/theory.gd")

const ATTACK_SEC := 0.55
const LOOP_SEC := 1.5
const RELEASE_SEC := 1.0
const HARM_MAX := 9
const FORMANT_HZ := 700.0
const FORMANT_WIDTH := 1100.0

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func cache_size() -> int:
	return _cache.size()


## 返回 {"attack": PackedFloat32Array, "loop": PackedFloat32Array}，内容只读。
static func tone(m: int, vel: float) -> Dictionary:
	var vb := clampi(int(round(vel * 16.0)), 1, 16)
	var key := "%d:%d" % [m, vb]
	var hit: Variant = _cache.get(key)
	if hit != null:
		return hit
	var d := _build(m, float(vb) / 16.0)
	_cache[key] = d
	return d


static func _build(m: int, vel: float) -> Dictionary:
	var sr := float(SR)
	var f0 := Theory.freq(float(m))
	var nyq := sr * 0.5
	var k_top := mini(HARM_MAX, int(floor(nyq / f0)))
	if k_top < 1:
		return {"attack": PackedFloat32Array(), "loop": PackedFloat32Array()}
	var ks: Array = []
	var ws: Array = []
	var wsum := 0.0
	for k in range(1, k_top + 1):
		var fk := float(k) * f0
		if fk >= nyq:
			break
		# 弦乐没有钢琴那样的强高次分音，用一条宽共振峰把中频托起来
		var w := pow(float(k), -1.15) * exp(-pow((fk - FORMANT_HZ) / FORMANT_WIDTH, 2.0))
		ks.append(k)
		ws.append(w)
		wsum += w
	if wsum <= 0.0:
		return {"attack": PackedFloat32Array(), "loop": PackedFloat32Array()}

	var atk_len := int(round(ATTACK_SEC * sr))
	var periods := maxi(1, int(round(LOOP_SEC * f0)))
	var loop_len := int(round(float(periods) * sr / f0))
	var total := atk_len + loop_len
	var buf := PackedFloat32Array()
	buf.resize(total)

	var ph := PackedFloat64Array()
	ph.resize(ks.size())
	var dph := PackedFloat64Array()
	dph.resize(ks.size())
	for i in ks.size():
		dph[i] = TAU * float(ks[i]) * f0 / sr
	var g := (1.0 / wsum) * pow(vel, 1.4) * 0.55

	for n in total:
		var s := 0.0
		for i in ks.size():
			s += ws[i] * sin(ph[i])
			ph[i] += dph[i]
		buf[n] = s * g

	# 起音用 smoothstep，避免长音开头出现折角
	for n in atk_len:
		var u := float(n) / float(maxi(1, atk_len))
		buf[n] *= u * u * (3.0 - 2.0 * u)

	return {"attack": buf.slice(0, atk_len), "loop": buf.slice(atk_len, total)}
