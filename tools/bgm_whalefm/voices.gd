extends RefCounted
## 《鲸落电台》电钢与贝斯 —— 复用《玻璃温室》的模态谐振器引擎，换预设出全新音色。
##
## 电钢琴（Rhodes / Dyno 风）：关键在 spread —— 高次分音衰减得比基音快得多，
## 听感就是「叮」一声 tine 起音之后剩下圆润的基音长鸣；
## 双弦轻微去谐给出 Dyno 那种 chorus 感。击槌噪声几乎关掉（簧片不是琴弦）。
##
## 贝斯：基音为主、高次压狠、松键快停 —— 圆润的 sub bass，不抢电钢的中频。

const PianoEngine := preload("res://tools/bgm_glasshouse/piano.gd")

const EPIANO := {
	"partials_max": 9,
	"tilt_lo": 2.50,            # 弱奏偏暗
	"tilt_hi": 1.55,            # 强奏谱线抬起来，tine 更亮
	"inharm_lo": 0.00060,       # 簧片有轻微非谐性
	"inharm_hi": 0.00025,
	"t60_lo": 7.0,              # 低音区余音
	"t60_hi": 2.0,
	"spread": 0.62,             # ★ tine 感：k≥2 的分音速衰
	"t60_damp_lo": 0.55,        # 松键后制音
	"t60_damp_hi": 0.14,
	"unison": 2,
	"detune_cents": 0.45,       # 轻 chorus
	"hammer_gain": 0.012,       # 簧片触感，比钢琴轻得多
	"attack_sec": 0.0,
	"release_sec": 0.0,
	"tremolo_hz": 0.0,
	"tremolo_depth": 0.0,
}

const BASS := {
	"partials_max": 5,
	"tilt_lo": 3.40,
	"tilt_hi": 2.60,
	"inharm_lo": 0.00020,
	"inharm_hi": 0.00010,
	"t60_lo": 4.0,
	"t60_hi": 1.8,
	"spread": 0.85,             # 高次几乎只是起音染色
	"t60_damp_lo": 0.30,        # 松键即停，贝斯不能糊
	"t60_damp_hi": 0.10,
	"unison": 1,
	"detune_cents": 0.0,
	"hammer_gain": 0.006,
	"attack_sec": 0.0,
	"release_sec": 0.0,
	"tremolo_hz": 0.0,
	"tremolo_depth": 0.0,
}


static func epiano(m: int, vel: float, dur: float, partials_max: int, unison: int) -> PackedFloat32Array:
	var preset := EPIANO.duplicate()
	preset["partials_max"] = partials_max
	preset["unison"] = unison
	var tag := "wf_ep%d_%d" % [partials_max, unison]
	return PianoEngine.render(tag, preset, m, vel, dur)


static func bass(m: int, vel: float, dur: float, partials_max: int) -> PackedFloat32Array:
	var preset := BASS.duplicate()
	preset["partials_max"] = partials_max
	var tag := "wf_bs%d" % partials_max
	return PianoEngine.render(tag, preset, m, vel, dur)


static func cache_size() -> int:
	return PianoEngine.cache_size()


static func clear_cache() -> void:
	PianoEngine.clear_cache()
