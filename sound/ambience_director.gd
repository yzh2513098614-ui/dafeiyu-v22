extends Node
## 大肥鱼 · 环境音（音景）总监 —— **当前已停用**
##
## 停用原因：这是我未经确认就加进来的一层（把海浪/室内底噪铺满整个游戏），
## 而正确的做法是先问「要不要」。现在它：
##   · 没有注册为 autoload（project.godot 里没有它）
##   · 设置页里也没有对应开关了
## 所以运行时完全不会有环境音。
##
## 代码和 assets/ambience/ 的 4 个 wav 都保留着，因为**这个项目没有 git，
## 删掉就找不回来了**。想重新启用只需两步：
##   1. 把本文件注册成 autoload（名字必须叫 AmbienceDirector）
##   2. 在 ui/game_settings.gd 的「声音」页加回开关 + 音量（HarborPrefs 里的
##      ambience / ambience_volume 两个字段一直留着没删）
##
## ─────────────────────────── 以下为原说明 ───────────────────────────
## 和 MusicDirector 结构相近（双声部交叉淡入淡出 + 定时重新判断场合），差别在：
##   · 环境音是**循环底噪**，切换要更慢更隐蔽（FADE 3 秒 vs 音乐的 1.8 秒）
##   · 整体压低 LEVEL_DB dB，永远垫在音乐和音效下面 —— 环境音是「空气」，
##     不该抢任何东西，听不见它才是对的，一旦听出来说明太响了
##   · 场合按「地点类型 + 昼夜」判断，而不是按心情
##
## 判断口径（读当前场景，不硬依赖任何节点）：
##   试炼场                    → amb_trial（更空旷、混响更长）
##   室外 白天 / 夜晚           → amb_sea_day / amb_sea_night
##   楼层、房间（室内）         → amb_indoor
##   标题菜单等没有 location_id → 不放（标题有音乐就够了）
##
## 用法：SfxDirector 那边一样，外部不需要手动控制；想调音量/replace 素材就
## 改 assets/ambience/*.wav 或重跑 tools/ambience_synth.gd。

const DIR := "res://assets/ambience/"
const FADE := 3.0        ## 交叉淡入淡出秒数
const POLL := 0.5        ## 重新判断场合的间隔
const LEVEL_DB := -13.0  ## 环境音整体垫底的电平
const NIGHT_FROM := 19.0
const NIGHT_TO := 6.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _gain: Array[float] = [0.0, 0.0]
var _target: Array[float] = [0.0, 0.0]
var _slot := 0
var _bed := ""
var _poll := 0.0
var _fallback_enabled := true
var _fallback_volume := 0.55

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_poll = POLL
	if DisplayServer.get_name() != "headless":
		print("[AmbienceDirector] 环境音就绪 · 路径 %s" % DIR)

# ---------------------------------------------------------------- 偏好读写

func _prefs() -> Variant:
	return get_node_or_null("/root/HarborPrefs")

func enabled() -> bool:
	var prefs: Variant = _prefs()
	if prefs != null:
		var values: Variant = prefs.get("values")
		if values is Dictionary and values.has("ambience"):
			return bool(values["ambience"])
	return _fallback_enabled

func volume() -> float:
	var prefs: Variant = _prefs()
	if prefs != null and prefs.get("ambience_volume") != null:
		return clampf(float(prefs.ambience_volume), 0.0, 1.0)
	return _fallback_volume

func set_enabled(value: bool) -> void:
	var prefs: Variant = _prefs()
	if prefs != null:
		var values: Variant = prefs.get("values")
		if values is Dictionary and values.has("ambience"):
			values["ambience"] = value
			prefs.save()
			if not value:
				stop_all()
			return
	_fallback_enabled = value
	if not value:
		stop_all()

func set_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	var prefs: Variant = _prefs()
	if prefs != null and prefs.get("ambience_volume") != null:
		prefs.ambience_volume = clamped
		prefs.save()
	else:
		_fallback_volume = clamped

func current_bed() -> String:
	return _bed

func stop_all() -> void:
	for p in _players:
		p.stop()

# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	for i in 2:
		var goal := _target[i]
		var step := delta / FADE
		if _gain[i] < goal:
			_gain[i] = minf(goal, _gain[i] + step)
		else:
			_gain[i] = maxf(goal, _gain[i] - step)
		var level := _gain[i] if enabled() else 0.0
		_players[i].volume_db = linear_to_db(maxf(level * volume(), 0.0001)) + LEVEL_DB
		if _target[i] <= 0.0 and _gain[i] <= 0.002 and _players[i].playing:
			_players[i].stop()
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL
	var want := _detect()
	if want != _bed:
		_switch(want)

func _switch(bed: String) -> void:
	_bed = bed
	if bed == "":
		_target[0] = 0.0
		_target[1] = 0.0
		return
	var stream := _load_stream(bed)
	if stream == null:
		_bed = ""
		return
	_slot = 1 - _slot
	_players[_slot].stream = stream
	_players[_slot].play()
	_target[_slot] = 1.0
	_target[1 - _slot] = 0.0

# ---------------------------------------------------------------- 场合判断

func _detect() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var location: Variant = scene.get("location_id")
	if location == null or str(location) == "":
		# 标题菜单 / 还没进世界：不放环境音
		return ""
	var id := str(location)
	if id == "trial":
		return "amb_trial"
	var type := ""
	var group := ""
	var locations: Variant = scene.get("locations")
	if locations is Dictionary and locations.has(id):
		var entry: Variant = locations[id]
		if entry is Dictionary:
			type = str(entry.get("type", ""))
			group = str(entry.get("group", ""))
	if type in ["floor", "room"] or group.begins_with("floor"):
		return "amb_indoor"
	var hour := 12.0
	var atmosphere: Variant = scene.get("atmosphere")
	if atmosphere != null and atmosphere.get("hour") != null:
		hour = float(atmosphere.hour)
	return "amb_sea_night" if (hour >= NIGHT_FROM or hour < NIGHT_TO) else "amb_sea_day"

# ---------------------------------------------------------------- WAV 解析

## 和 SfxDirector 同一口径，唯一差别是 LOOP_FORWARD —— 环境音必须循环。
func _load_stream(bed: String) -> AudioStreamWAV:
	if _streams.has(bed):
		return _streams[bed]
	var bytes := FileAccess.get_file_as_bytes(DIR + bed + ".wav")
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		push_warning("[AmbienceDirector] 读取不到环境音：" + DIR + bed + ".wav（先跑 tools/ambience_synth.gd 生成）")
		_streams[bed] = null
		return null
	var channels := int(bytes.decode_u16(22))
	if bytes.decode_u16(20) != 1 or bytes.decode_u16(34) != 16 or (channels != 1 and channels != 2):
		push_warning("[AmbienceDirector] 只支持 16bit 单声道或立体声 PCM：" + bed)
		_streams[bed] = null
		return null
	var rate := int(bytes.decode_u32(24))
	var offset := 12
	var frames := 0
	var pcm := PackedByteArray()
	while offset + 8 <= bytes.size():
		var tag := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var size := int(bytes.decode_u32(offset + 4))
		if tag == "data":
			pcm = bytes.slice(offset + 8, mini(offset + 8 + size, bytes.size()))
			frames = pcm.size() / (2 * channels)
			break
		offset += 8 + size + (size & 1)
	if frames <= 0:
		_streams[bed] = null
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels == 2
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	_streams[bed] = stream
	return stream
