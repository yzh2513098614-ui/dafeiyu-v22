extends Node
## 大肥鱼 · 背景音乐总监
##
## 自己解析 assets/music/*.wav 并构造 AudioStreamWAV，因此不依赖 Godot 的导入管线
## （不需要 .import 文件，也不会因为新增素材而要求重新导入）。支持单声道与立体声。
##
## 每 0.35 秒判断一次该放哪首，切换时交叉淡入淡出：
##   标题菜单            → title
##   室外 白天           → day
##   室外 夜晚           → night
##   室内（楼层/院落）   → indoor
##   潮汐试炼场有遭遇点  → battle
##   潮汐试炼场已清完    → hope
##
## 轮换：每个场合是一「组」曲目而不是一首（见 STYLE_SETS 的 tracks）。
##   每次进入该场合都会换到组里的下一首；停在同一场合超过 DWELL 秒也会自己换下一首。
##   这样在街区里待久了不会从进游戏到退出都听同一段旋律。
##
## 五套风格组，F8 切换（会记住）：
##   galgame     galgame 场景配乐二十首（默认，八首原创钢琴加入对应场合轮换）
##   harbor      最初那五首港町氛围曲（曲目少，组内跨场合复用）
##   glasshouse  《玻璃温室》六首（钢琴 + 弦乐垫 + 音乐盒，一条叙事弧，每场合固定一首）
##   whalefm     《鲸落电台》六首（电钢 + 贝斯 + 鼓组 + 黑胶炒豆的 Lo-fi 电台，每场合固定一首）
##   chip        《像素掌机》六首（方波×2 + 三角波 + 噪声鼓的芯片音乐，每场合固定一首）
##
## glasshouse / whalefm / chip 的音轨放在 assets/music/ 子目录里，所以它们的曲目 id 带一段路径
## （"glasshouse/glasshouse_01_prologue"、"whalefm/wf_01_fm885"、"chip/chip_title"）——
## 下面的 DIR + id + ".wav" 拼接天然支持。这三组每首都是整段无缝循环（尾音已折回开头），
## 一个场合只排一首、靠循环铺满，不轮换。
##
## 快捷键：F8 切换风格组 · F9 试听下一首（循环回自动）· F10 静音开关 · [ ] 调音量
##
## 想换成自己的音乐：把 16bit 单声道或立体声 WAV 按同名放进 assets/music/ 覆盖即可。

const DIR := "res://assets/music/"

## tracks 里每个场合是一个数组：组内轮换。写成单个字符串也兼容（等价于只有一首）。
const STYLE_SETS := {
	"galgame": {
		"name": "galgame 场景二十首",
		"tracks": {
			"title": ["gal_piano_daily", "gal_piano_hope", "gal_after_school", "gal_bittersweet", "gal_title2"],
			"day": ["gal_piano_daily", "gal_daily", "gal_daily2"],
			"night": ["gal_piano_night", "gal_piano_rain", "gal_after_school", "gal_memory", "gal_goodnight", "gal_memory2"],
			"indoor": ["gal_piano_indoor", "gal_piano_rain", "gal_after_school", "gal_light", "gal_light2"],
			"battle": ["gal_piano_tension", "gal_tension", "gal_tension2"],
			"hope": ["gal_piano_hope", "gal_hope", "gal_goodnight", "gal_hope2"],
		},
	},
	"harbor": {
		"name": "港町氛围五首",
		"tracks": {
			# 这一组只有五首，凑不出「每场合两首」，所以在组内跨场合复用。
			# 同一首不会连着播两次，但题目和战斗曲的差别比 galgame 组小，这是素材量决定的。
			"title": ["title_harbor", "day_town"],
			"day": ["day_town", "indoor_warm"],
			"night": ["night_town", "title_harbor"],
			"indoor": ["indoor_warm", "night_town"],
			"battle": ["battle_tide"],
			"hope": ["day_town", "night_town"],
		},
	},
	"glasshouse": {
		"name": "玻璃温室六首",
		"tracks": {
			# 六首是一条叙事弧：序章 → 相遇 → 思念 → 雨中 → 告白 → 告别。
			# 每个场合只排一首，循环播放；告白那首是唯一的全奏高潮，给它战斗。
			"title": "glasshouse/glasshouse_01_prologue",
			"day": "glasshouse/glasshouse_02_meeting",
			"indoor": "glasshouse/glasshouse_03_longing",
			"night": "glasshouse/glasshouse_04_rain",
			"battle": "glasshouse/glasshouse_05_confession",
			"hope": "glasshouse/glasshouse_06_farewell",
		},
	},
	"whalefm": {
		"name": "鲸落电台六首",
		"tracks": {
			# Whale-Fall FM 88.5：港口小镇的 Lo-fi 电台节目单。
			# 电钢 + 贝斯 + 鼓组 + 黑胶炒豆；整段无缝循环，一个场合一首。
			"title": "whalefm/wf_01_fm885",
			"day": "whalefm/wf_02_breakwater",
			"indoor": "whalefm/wf_03_konbini",
			"night": "whalefm/wf_04_nightlight",
			"battle": "whalefm/wf_05_container",
			"hope": "whalefm/wf_06_ebbtide",
		},
	},
	"chip": {
		"name": "像素掌机六首",
		"tracks": {
			# 同一台「掌机」上的六盘卡带：出海 → 集市 → 夜潮 → 小屋 → 激战 → 归港。
			# PolyBLEP 方波×2 + 三角波低音 + LFSR 噪声鼓；整段无缝循环，一个场合一首。
			# 战斗曲 152 BPM 十六分驱动贝斯，是全库最快的曲子。
			"title": "chip/chip_title",
			"day": "chip/chip_day",
			"night": "chip/chip_night",
			"indoor": "chip/chip_indoor",
			"battle": "chip/chip_battle",
			"hope": "chip/chip_hope",
		},
	},
}

const MOOD_ORDER: Array = ["title", "day", "night", "indoor", "battle", "hope"]

## 鉴赏用的曲目表（style → [{id, 标题, 用途, 时长}]，时长自动从 WAV 读，这里只写用途）
const CATALOG := {
	"galgame": [
		["gal_piano_daily", "海风课间", "原创钢琴 · 日常 / 标题"],
		["gal_piano_indoor", "窗边的热茶", "原创钢琴 · 室内 / 温柔对话"],
		["gal_piano_night", "灯塔替我记得", "原创钢琴 · 夜晚 / 思念"],
		["gal_piano_rain", "雨声里的约定", "原创钢琴 · 回忆 / 雨夜告白"],
		["gal_piano_tension", "潮汐之前", "原创钢琴 · 紧张 / 决意"],
		["gal_piano_hope", "明天仍有晴空", "原创钢琴 · 释怀 / 结尾"],
		["gal_after_school", "夕照，未寄出的信", "原创钢琴 · 标题 / 室内 / 夜晚"],
		["gal_goodnight", "晚安，鲸落港", "原创钢琴 · 夜晚 / 回忆 / 通关"],
		["gal_daily", "港口的一天", "日常 · 教室 · 据点"],
		["gal_daily2", "午后集市", "日常 · 白天（轮换）"],
		["gal_light", "轻快的午后", "喜剧 · 打闹"],
		["gal_light2", "旧书与茶", "室内 · 安静场面（轮换）"],
		["gal_bittersweet", "伤感又舒畅", "告白 · 温柔场面"],
		["gal_title2", "潮声前奏", "标题画面（轮换）"],
		["gal_memory", "旧日回忆", "回忆 · 乡愁"],
		["gal_memory2", "夜航灯", "夜晚 · 空寂（轮换）"],
		["gal_tension", "潮水逼近", "冲突 · 剧情转折"],
		["gal_tension2", "深潮涌动", "连续战斗（轮换）"],
		["gal_hope", "退潮之后", "结局 · 释怀"],
		["gal_hope2", "归港", "通关 · 收束（轮换）"],
	],
	"harbor": [
		["title_harbor", "鲸落港的清晨", "标题菜单"],
		["day_town", "海风街巷", "街区 · 白天"],
		["night_town", "灯塔与夜潮", "街区 · 夜晚"],
		["indoor_warm", "暖灯小屋", "室内"],
		["battle_tide", "潮汐试炼", "战斗"],
	],
	"glasshouse": [
		["glasshouse/glasshouse_01_prologue", "玻璃温室的序章", "原创钢琴 + 弦乐 · 序章 / 标题"],
		["glasshouse/glasshouse_02_meeting", "相遇的圆舞曲", "原创钢琴 + 弦乐 · 相遇 / 街区白天"],
		["glasshouse/glasshouse_03_longing", "思念的形状", "原创钢琴 + 弦乐 · 思念 / 室内"],
		["glasshouse/glasshouse_04_rain", "雨中的音乐盒", "原创钢琴 + 弦乐 · 雨中 / 街区夜晚"],
		["glasshouse/glasshouse_05_confession", "告白，升一个全音", "原创钢琴 + 弦乐 · 高潮 / 潮汐试炼"],
		["glasshouse/glasshouse_06_farewell", "告别与同主音", "原创钢琴 + 弦乐 · 告别 / 已通关"],
	],
	"whalefm": [
		["whalefm/wf_01_fm885", "调频 88.5", "鲸落电台 · Lo-fi 电钢 · 标题"],
		["whalefm/wf_02_breakwater", "防波堤散步道", "鲸落电台 · Lo-fi 电钢 · 街区白天"],
		["whalefm/wf_03_konbini", "便利店暖光", "鲸落电台 · Lo-fi 电钢 · 室内"],
		["whalefm/wf_04_nightlight", "夜航灯", "鲸落电台 · Lo-fi 电钢 · 街区夜晚"],
		["whalefm/wf_05_container", "集装箱突围", "鲸落电台 · Lo-fi 电钢 · 潮汐试炼"],
		["whalefm/wf_06_ebbtide", "退潮，晨光", "鲸落电台 · Lo-fi 电钢 · 已通关"],
	],
	"chip": [
		["chip/chip_title", "像素浪潮", "原创芯片音乐 · 标题 / 出海冒险"],
		["chip/chip_day", "贝壳集市", "原创芯片音乐 · 街区白天"],
		["chip/chip_night", "星光栈桥", "原创芯片音乐 · 街区夜晚"],
		["chip/chip_indoor", "小屋收音机", "原创芯片音乐 · 室内 / 慵懒午后"],
		["chip/chip_battle", "怒涛排位战", "原创芯片音乐 · 潮汐试炼 / 高速战斗"],
		["chip/chip_hope", "归港烟火", "原创芯片音乐 · 释怀 / 已通关"],
	],
}
const MOOD_LABEL := {
	"title": "标题",
	"day": "街区 · 白天",
	"night": "街区 · 夜晚",
	"indoor": "室内",
	"battle": "潮汐试炼 · 战斗",
	"hope": "潮汐试炼 · 已通关",
}

const FADE := 1.8        ## 交叉淡入淡出秒数
const POLL := 0.35       ## 重新判断场合的间隔
## 同一场合里两首之间的驻留时长。曲子是 LOOP_FORWARD 循环流，永远不会「放完」，
## 所以换曲只能靠时间，不能靠播放结束信号。
const DWELL := 96.0
const NIGHT_FROM := 19.0 ## 夜晚音乐起点（小时）
const NIGHT_TO := 6.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _gain: Array[float] = [0.0, 0.0]
var _target: Array[float] = [0.0, 0.0]
var _slot := 0
var _mood := ""
var _track := ""                                  ## 正在播的那一首（轮换后与 _mood 不再一一对应）
var _rotation: Dictionary = {}                    ## mood → 下一首在组内的下标
var _dwell := DWELL
var _poll := 0.0
var _preview := -1
var _gallery := ""
var _style := "galgame"
var _fallback_enabled := true
var _fallback_volume := 0.65
var _layer: CanvasLayer
var _label: Label
var _toast_left := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	var prefs: Variant = _prefs()
	if prefs != null:
		var saved: Variant = prefs.get("music_style")
		if saved != null and STYLE_SETS.has(str(saved)):
			_style = str(saved)
	_poll = POLL
	if DisplayServer.get_name() != "headless":
		print("[MusicDirector] 背景音乐就绪 · F8 换风格组 · F9 试听 · F10 静音 · [ ] 音量")

# ---------------------------------------------------------------- 偏好读写（不硬依赖 HarborPrefs）

func _prefs() -> Variant:
	return get_node_or_null("/root/HarborPrefs")

func music_enabled() -> bool:
	var prefs: Variant = _prefs()
	if prefs != null:
		var values: Variant = prefs.get("values")
		if values is Dictionary and values.has("music"):
			return bool(values["music"])
	return _fallback_enabled

func music_volume() -> float:
	var prefs: Variant = _prefs()
	if prefs != null:
		var value: Variant = prefs.get("music_volume")
		if value != null:
			return clampf(float(value), 0.0, 1.0)
	return _fallback_volume

func _store_volume(value: float) -> void:
	var prefs: Variant = _prefs()
	if prefs != null and prefs.get("music_volume") != null:
		prefs.music_volume = value
		prefs.save()
	else:
		_fallback_volume = value

func _store_enabled(value: bool) -> void:
	var prefs: Variant = _prefs()
	if prefs != null:
		var values: Variant = prefs.get("values")
		if values is Dictionary and values.has("music"):
			values["music"] = value
			prefs.save()
			return
	_fallback_enabled = value

func _store_style() -> void:
	var prefs: Variant = _prefs()
	if prefs != null and prefs.get("music_style") != null:
		prefs.music_style = _style
		prefs.save()

# ---------------------------------------------------------------- 对外设置入口
# 界面一律走这里，不要再直接调 _store_* 私有方法。

func set_volume(value: float) -> void:
	_store_volume(clampf(value, 0.0, 1.0))

func set_enabled(value: bool) -> void:
	_store_enabled(value)

func cycle_style() -> void:
	_cycle_style()

func style_keys() -> Array:
	return STYLE_SETS.keys()

func style_display_name(key: String) -> String:
	var entry: Variant = STYLE_SETS.get(key)
	if entry is Dictionary:
		return str(entry.get("name", key))
	return key

# ---------------------------------------------------------------- 风格组

func style_key() -> String:
	return _style

func style_name() -> String:
	return style_display_name(_style)

## 曲目显示名（鉴赏页用）
func track_title(id: String) -> String:
	var entry: Variant = CATALOG.get(_style)
	if entry is Array:
		for row in entry:
			if str(row[0]) == id:
				return str(row[1])
	return id

## 某个场合的曲目组。单个字符串写成数组，调用方就只需要处理一种形状。
func _tracks_for(mood: String) -> Array:
	var entry: Variant = STYLE_SETS.get(_style)
	if not (entry is Dictionary):
		return []
	var tracks: Variant = entry.get("tracks")
	if not (tracks is Dictionary):
		return []
	var value: Variant = tracks.get(mood, "")
	if value is Array:
		return value
	if value is String and str(value) != "":
		return [str(value)]
	return []

## 该场合「下一次会播」的那一首（只读游标，不推进）。
func _track_for(mood: String) -> String:
	var list := _tracks_for(mood)
	if list.is_empty():
		return ""
	return str(list[int(_rotation.get(mood, 0)) % list.size()])

## 推进游标：下一次进同一场合会换到组里的下一首。
func _advance_rotation(mood: String) -> void:
	var count := _tracks_for(mood).size()
	if count > 0:
		_rotation[mood] = (int(_rotation.get(mood, 0)) + 1) % count

func _cycle_style() -> void:
	var keys: Array = STYLE_SETS.keys()
	var index := keys.find(_style)
	_style = str(keys[(index + 1) % keys.size()])
	_store_style()
	_preview = -1
	if in_gallery():
		# 鉴赏页里换风格组：直接改播新组的第一首
		_gallery = "?"
		select_gallery(first_catalog_track())
	else:
		_mood = ""
		_evaluate()
	_toast("配乐风格：" + style_name())

# ---------------------------------------------------------------- 主循环

func _process(delta: float) -> void:
	for i in 2:
		var goal := _target[i]
		var step := delta / FADE
		if _gain[i] < goal:
			_gain[i] = minf(goal, _gain[i] + step)
		else:
			_gain[i] = maxf(goal, _gain[i] - step)
		var level := _gain[i] if music_enabled() else 0.0
		_players[i].volume_db = linear_to_db(maxf(level * music_volume(), 0.0001))
		if _target[i] <= 0.0 and _gain[i] <= 0.002 and _players[i].playing:
			_players[i].stop()
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		# 鉴赏模式期间不跑自动场合判断，否则标题曲会盖掉正在鉴赏的曲子
		if not in_gallery():
			_evaluate()
	# 场合判断只在「场合变了」时切曲，所以同一个场合里要靠这个计时器轮换。
	# 试听（F9）和鉴赏页都手动选曲，不受它影响。
	if not in_gallery() and _preview < 0:
		_dwell -= delta
		if _dwell <= 0.0:
			_rotate_in_place()
	_tick_toast(delta)

func _evaluate() -> void:
	var want := _detect()
	if want != _mood:
		_switch(want)

func _switch(mood: String) -> void:
	var track := _track_for(mood)
	if track == "":
		return
	var stream := _load_stream(track)
	if stream == null:
		return
	_mood = mood
	_track = track
	_advance_rotation(mood)
	_dwell = DWELL
	# 新增钢琴曲在自己的尾音段换曲，避免固定计时切进下一遍的乐句。
	if track.begins_with("gal_piano_") or track == "gal_after_school":
		_dwell = stream.get_length() - FADE
	_slot = 1 - _slot
	_players[_slot].stream = stream
	_players[_slot].play()
	_target[_slot] = 1.0
	_target[1 - _slot] = 0.0

## 停留太久就在同一场合里换下一首。
## 不能走 _evaluate()：_mood 没变，_evaluate 会认为「不需要切」，永远是同一首。
func _rotate_in_place() -> void:
	if _mood == "":
		return
	if _tracks_for(_mood).size() <= 1:
		_dwell = DWELL
		return
	_switch(_mood)

# ---------------------------------------------------------------- 场合判断

func _detect() -> String:
	if _preview >= 0:
		return str(MOOD_ORDER[_preview])
	var scene := get_tree().current_scene
	if scene == null:
		return _mood if _mood != "" else "title"
	# 标题菜单
	if scene.has_method("_saved_journey"):
		return "title"
	var location: Variant = scene.get("location_id")
	if location == null or str(location) == "":
		return "title"
	# 潮汐试炼场：有活怪放战斗曲，清完了放释怀曲
	if str(location) == "trial":
		return "battle" if _has_living_monster(scene) else "hope"
	var group := ""
	var locations: Variant = scene.get("locations")
	if locations is Dictionary and locations.has(str(location)):
		var entry: Variant = locations[str(location)]
		if entry is Dictionary:
			group = str(entry.get("group", ""))
	if group == "outside":
		var hour := 12.0
		var atmosphere: Variant = scene.get("atmosphere")
		if atmosphere != null and atmosphere.get("hour") != null:
			hour = float(atmosphere.hour)
		return "night" if (hour >= NIGHT_FROM or hour < NIGHT_TO) else "day"
	return "indoor"

## 试炼场里还有没有可打的遭遇点。
## 注意：改成回合制之后，场地上的对象叫 markers（combat/combat_controller.gd），
## 旧即时战的 monsters 数组已经不存在了。这里必须跟着改 ——
## 否则 markers 永远读成 null，试炼场会被判成「已清完」，一进去就放通关曲，
## 而且战斗曲一次都不会响。这是切回合制时漏掉的一处引用。
func _has_living_monster(scene: Node) -> bool:
	var combat: Variant = scene.get("combat_controller")
	if combat == null:
		return false
	var markers: Variant = combat.get("markers")
	if not (markers is Array) or markers.is_empty():
		return false
	for marker in markers:
		if not is_instance_valid(marker):
			continue
		if not bool(marker.get("defeated")):
			return true
	return false

# ---------------------------------------------------------------- WAV 解析

func _load_stream(track: String) -> AudioStreamWAV:
	if track == "":
		return null
	if _streams.has(track):
		return _streams[track]
	var bytes := FileAccess.get_file_as_bytes(DIR + track + ".wav")
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		push_warning("[MusicDirector] 读取不到音乐：" + DIR + track + ".wav")
		_toast("曲目文件缺失：" + track)
		_streams[track] = null
		return null
	var channels := int(bytes.decode_u16(22))
	if bytes.decode_u16(20) != 1 or bytes.decode_u16(34) != 16 or (channels != 1 and channels != 2):
		push_warning("[MusicDirector] 只支持 16bit 单声道或立体声 PCM：" + track)
		_toast("曲目格式不支持：" + track)
		_streams[track] = null
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
		_streams[track] = null
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels == 2
	stream.data = pcm
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	_streams[track] = stream
	return stream

# ---------------------------------------------------------------- 快捷键与提示

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# 文本输入态一律让路：否则在搜索框里敲 [ 会改音量，且 set_input_as_handled() 会把按键吞掉。
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	match event.physical_keycode:
		KEY_F8:
			_cycle_style()
			get_viewport().set_input_as_handled()
		KEY_F9:
			if in_gallery():
				# 鉴赏页里 F9 = 当前风格组的下一首
				var nxt := next_gallery_track()
				if nxt != "":
					select_gallery(nxt)
					_toast("鉴赏 · " + track_title(nxt))
			else:
				_preview += 1
				if _preview >= MOOD_ORDER.size():
					_preview = -1
				if _preview < 0:
					_toast("背景音乐：自动跟随场合")
				else:
					_toast("试听 " + str(MOOD_LABEL[MOOD_ORDER[_preview]]) + " · " + _track_for(str(MOOD_ORDER[_preview])))
				_evaluate()
			get_viewport().set_input_as_handled()
		KEY_F10:
			var now := not music_enabled()
			_store_enabled(now)
			_toast("背景音乐：" + ("开" if now else "关"))
			get_viewport().set_input_as_handled()
		KEY_BRACKETLEFT:
			var lower := maxf(0.0, music_volume() - 0.1)
			_store_volume(lower)
			_toast("背景音乐音量 %d%%" % roundi(lower * 100.0))
			get_viewport().set_input_as_handled()
		KEY_BRACKETRIGHT:
			var higher := minf(1.0, music_volume() + 0.1)
			_store_volume(higher)
			_toast("背景音乐音量 %d%%" % roundi(higher * 100.0))
			get_viewport().set_input_as_handled()

func _toast(text: String) -> void:
	if _label == null:
		_layer = CanvasLayer.new()
		_layer.layer = 128
		add_child(_layer)
		_label = Label.new()
		var font := load("res://assets/NotoSansSC.ttf")
		if font != null:
			_label.add_theme_font_override("font", font)
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color("fff8e7"))
		_label.add_theme_color_override("font_outline_color", Color(0.05, 0.09, 0.14, 0.85))
		_label.add_theme_constant_override("outline_size", 6)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(_label)
	_label.text = text
	_label.visible = true
	_toast_left = 2.4

func _tick_toast(delta: float) -> void:
	if _toast_left <= 0.0 or _label == null:
		return
	_toast_left -= delta
	var size := get_viewport().get_visible_rect().size
	_label.size = Vector2(size.x, 40.0)
	_label.position = Vector2(0.0, size.y - 96.0)
	if _toast_left <= 0.0:
		_label.visible = false

# ---------------------------------------------------------------- 供外部调用

func current_mood() -> String:
	return _mood

func current_track() -> String:
	# 轮换之后「当前播的」不再等于 _track_for(_mood)（那首是下一次要播的），
	# 所以优先报 _track。
	return _track if _track != "" else _track_for(_mood)

# ---------------------------------------------------------------- 音乐鉴赏模式
#
# 进入鉴赏页后必须彻底停掉「自动场合判断」，否则 _process 每 0.35 秒都会跑一次
# _evaluate()：在标题场景里 _detect() 恒为 "title"，于是刚点开的鉴赏曲会被标题曲
# 覆盖掉，表现就是「标题音乐反复重播」。

## 进入鉴赏页：停掉自动音乐（标题曲），并默认播放当前风格组第一首
func enter_gallery() -> void:
	_preview = -1
	_mood = ""
	_gallery = "?"
	_target[0] = 0.0
	_target[1] = 0.0
	# 全局静音时不自动开播：否则会标成「正在播放」却听不到声音，容易以为坏了。
	# 玩家点任意一首会自动取消静音（见鉴赏页的卡片点击）。
	if not music_enabled():
		return
	var first := first_catalog_track()
	if first != "":
		select_gallery(first)

## 鉴赏页里选播某一首（点同一首＝从头重播）
func select_gallery(id: String) -> void:
	if str(id) == "":
		return
	_gallery = str(id)
	_play_track(str(id))

## 离开鉴赏页：停掉鉴赏曲，恢复自动跟随场合
func exit_gallery() -> void:
	if _gallery == "":
		return
	_gallery = ""
	_target[0] = 0.0
	_target[1] = 0.0
	_mood = ""
	_evaluate()

func in_gallery() -> bool:
	return _gallery != ""

## 鉴赏页当前选中的曲目 id（"?" 表示还没选）
func gallery_track() -> String:
	return _gallery

func first_catalog_track() -> String:
	var entry: Variant = CATALOG.get(_style)
	if entry is Array and not entry.is_empty():
		return str(entry[0][0])
	return ""

## 鉴赏页里 F9 用：切到当前风格组的下一首
func next_gallery_track() -> String:
	var entry: Variant = CATALOG.get(_style)
	if not (entry is Array) or entry.is_empty():
		return ""
	var ids: Array = []
	for row in entry:
		ids.append(str(row[0]))
	var index := ids.find(_gallery)
	return str(ids[(index + 1) % ids.size()])

func _play_track(track: String) -> void:
	if track == "":
		return
	var stream := _load_stream(track)
	if stream == null:
		return
	_slot = 1 - _slot
	_players[_slot].stream = stream
	_players[_slot].play()
	_target[_slot] = 1.0
	_target[1 - _slot] = 0.0

## 试听指定场合；_preview 指向 MOOD_ORDER 的序号，-1 表示恢复自动跟随场合
func preview_index() -> int:
	return _preview

func set_preview(index: int) -> void:
	_preview = index if index >= 0 and index < MOOD_ORDER.size() else -1
	_evaluate()

func stop_preview() -> void:
	_preview = -1
	_mood = ""
	_evaluate()

## 当前风格组的曲目列表 [{id, name, use, seconds}]
func catalog() -> Array:
	var out: Array = []
	var entry: Variant = CATALOG.get(_style)
	if not (entry is Array):
		return out
	for row in entry:
		out.append({
			"id": str(row[0]),
			"name": str(row[1]),
			"use": str(row[2]),
			"seconds": track_seconds(str(row[0])),
		})
	return out

## 从 WAV 头读时长（顺带验证文件是否可读）
func track_seconds(id: String) -> float:
	var stream := _load_stream(id)
	if stream == null:
		return 0.0
	return round(float(stream.loop_end) / float(maxi(1, stream.mix_rate)) * 10.0) / 10.0

func track_time_text(id: String) -> String:
	if _load_stream(id) == null:
		return "缺失"
	var seconds := track_seconds(id)
	var whole := int(round(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]

func set_style(key: String) -> void:
	if not STYLE_SETS.has(key):
		return
	_style = key
	_store_style()
	_preview = -1
	_mood = ""
	_evaluate()
