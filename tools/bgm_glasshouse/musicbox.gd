extends RefCounted
## 《玻璃温室》音乐盒音色 —— 借用钢琴那套模态引擎，换一组参数。
##
## 音乐盒与钢琴的差别：谱线更“金属”（高次分音比例更高）、衰减快得多、
## 带一点点 4.5 Hz 的机械颤音、几乎听不到击槌噪声。
## 六首曲子都会在高音区用它做点缀；「雨中」那首升格为主奏之一。

const Piano := preload("res://tools/bgm_glasshouse/piano.gd")

const MUSICBOX := {
	"partials_max": 16,
	"tilt_lo": 1.55,
	"tilt_hi": 1.15,
	"inharm_lo": 0.00045,
	"inharm_hi": 0.00045,
	"t60_lo": 0.95,
	"t60_hi": 0.45,
	"spread": 0.45,
	"t60_damp_lo": 0.45,
	"t60_damp_hi": 0.30,
	"unison": 2,
	"detune_cents": 2.5,
	"hammer_gain": 0.09,
	"attack_sec": 0.001,
	"release_sec": 0.0,
	"tremolo_hz": 4.5,
	"tremolo_depth": 0.05,
}


## 返回只读缓冲，禁止原地修改。
static func render(m: int, vel: float, dur: float) -> PackedFloat32Array:
	return Piano.render("mb", MUSICBOX, m, vel, dur)
