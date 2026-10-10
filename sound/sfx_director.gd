extends Node
## 大肥鱼 · 音效总监
##
## 和 MusicDirector 一样自己解析 assets/sfx/*.wav，不依赖导入管线
## （不需要 .import，新生成的音效直接就能播）。
##
## 职责只有三件事：**加载 / 播放 / 限流**。它不认识任何玩法概念 ——
## 哪里响什么由调用方决定，这里不做「战斗中才准放 hit」这种判断，
## 否则音效规则会和玩法逻辑缠成两处。
##
## 几个刻意的设计：
##   · 声部池：12 个 AudioStreamPlayer 轮转。一次性音效会重叠（连击、连点按钮），
##     共享一个 player 会把前一个掐断，听起来像掉帧。
##   · 同名节流：同一个音效在 GAPS 秒内只响一次。按钮连点、连续命中，
##     不节流会糊成一片噪音。
##   · 单声道素材：音效不需要声场宽度，单声道还省一半内存。
##   · 音量每帧刷新：拖设置里的滑条时正在播的音效会跟着变，不然手感很怪。
##
## 用法：
##   SfxDirector.play("hit_crit")
##   SfxDirector.set_volume(0.5) / set_enabled(false)
##
## 想换成自己的音效：把 16bit 单声道 WAV 按同名放进 assets/sfx/ 覆盖即可。

const DIR := "res://assets/sfx/"
const VOICES := 12

## ───────────────────────── 音效分类表 ─────────────────────────
## 「分类」在这里是唯一事实来源，它一次决定三件事：
##   1. **每类的默认音量偏移** gain_db。这不是凑数：UI 轻点天然该比战斗命中轻，
##      打字机不能盖过对白。写死在各 play() 调用点
##      会变成到处手调 -dB，改一次要翻十个文件。
##   2. **每个音效的中文名与触发点**，用来核对「哪个音效还没接上玩法」。
##   3. **用途边界**：一个音效只属于一类，不跨类复用 —— 否则同一个声音在两种
##      语境里出现，玩家会分不清「这是什么反馈」。
##
## 音量顺序（从响到轻）刻意是：命中 > 技能/结果/物品 > 界面 > 场景 > 提示 > 对白。
const CATALOG := {
	"hit": {
		"name": "命中",
		"gain_db": -1.0,
		"sounds": [
			["hit_light", "命中", "我方攻击命中敌人"],
			["hit_crit", "暴击", "同一位置，带一个五度「叮」"],
			["hit_take", "受伤", "敌人打中我方，音色更闷"],
		],
	},
	"skill": {
		"name": "技能",
		"gain_db": -2.0,
		"sounds": [
			["skill_cast", "起手", "任意技能出手的瞬间"],
			["heal", "治疗", "海风治愈"],
			["shield", "护盾", "潮汐护盾 / 敌人缩壳"],
			["bind", "束缚", "泡泡束缚"],
			["link_ready", "连携就绪", "AP 蓄满那一下"],
			["link_cast", "连携发动", "潮汐连携，全场最高规格"],
		],
	},
	"result": {
		"name": "战斗结果",
		"gain_db": -2.0,
		"sounds": [
			["enemy_down", "敌人倒下", "敌人生命归零"],
			["flee", "脱身", "逃跑成功"],
			["invalid", "无效操作", "指令不合法 / 逃跑失败"],
		],
	},
	"item": {
		"name": "成长与物品",
		"gain_db": -2.0,
		"sounds": [
			["pickup", "拾取", "物品进入背包"],
			["chest_open", "开箱", "打开箱子的那一下"],
			["equip", "装备", "装上 / 卸下装备"],
			["level_up", "升级", "等级提升（refresh 里检测）"],
		],
	},
	"ui": {
		"name": "界面操作",
		"gain_db": -3.0,
		"sounds": [
			["ui_click", "轻点", "所有按钮按下（树级钩子自动挂）"],
			["ui_back", "返回", "关闭 / 退回上一层的操作"],
			["ui_confirm", "确认", "需要明确肯定的操作"],
		],
	},
	"scene": {
		"name": "场景",
		"gain_db": -5.0,
		"sounds": [
			["door", "进门 / 旅行", "切换地点（request_travel）"],
		],
	},
	"notice": {
		"name": "提示",
		"gain_db": -5.0,
		"sounds": [
			["encounter", "遭遇", "走近遭遇点弹提示；开战时同一动机加大音量"],
		],
	},
	"text": {
		"name": "文字对白",
		"gain_db": -6.0,
		"sounds": [
			["page", "翻页", "对白显示新的一行"],
			["type_tick", "打字机", "逐字显示，每 3 个字一次"],
		],
	},
}

## 分类展示顺序：从最常听到的到最少听到的
const CATEGORY_ORDER: Array = ["ui", "text", "hit", "skill", "result", "notice", "item", "scene"]

## 同名音效的最小间隔（秒）。按「逻辑声道」算，不是按文件名 ——
## 例如一次连击里的多次命中共享 "hit" 声道，互相之间也节流。
const GAPS := {
	"ui": 0.05,
	"page": 0.045,
	"hit": 0.05,
	"default": 0.03,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _base_db: Array[float] = []          ## 每个声部本次播放的基础音量（含分类偏移，每帧再叠加主音量）
var _next := 0
var _last: Dictionary = {}               ## 逻辑声道 → 上次播放时刻
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _missing_warned := false
var _fallback_enabled := true
var _fallback_volume := 0.8
var _category: Dictionary = {}           ## 音效 id → 分类 id，_ready 时建好

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_build_category_index()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
		_base_db.append(0.0)
	# 全局按钮点击：不去改 10 处各自实现的 _button()，而是挂一个树级钩子。
	# 全工程有 10 个重复的 _button() helper（room_3d/room/dialogue/bag_view/…），
	# 逐个接线既容易漏、又会把音效逻辑散到十个文件里。
	if DisplayServer.get_name() != "headless":
		get_tree().node_added.connect(_on_node_added)
		print("[SfxDirector] 音效就绪 · %d 个声部 · %d 类 %d 个音效 · 路径 %s" % [
			VOICES, CATEGORY_ORDER.size(), _category.size(), DIR])

## 建 id → 分类 的反查表。每次播放都遍历 CATALOG 太浪费，而且分类表是静态的。
func _build_category_index() -> void:
	_category.clear()
	for key in CATALOG:
		for row in CATALOG[key].sounds:
			_category[str(row[0])] = str(key)

func category_of(id: String) -> String:
	return str(_category.get(id, ""))

func category_gain_db(id: String) -> float:
	var cat := category_of(id)
	if cat == "" or not CATALOG.has(cat):
		return 0.0
	return float(CATALOG[cat].get("gain_db", 0.0))

## 扁平化的分类表，给设置页 / 试听页 / 自检脚本用。
## 返回 [{id, name, gain_db, sounds:[{id, name, use}]}]
func catalog() -> Array:
	var out: Array = []
	for key in CATEGORY_ORDER:
		if not CATALOG.has(key):
			continue
		var entry: Dictionary = CATALOG[key]
		var rows: Array = []
		for row in entry.sounds:
			rows.append({"id": str(row[0]), "name": str(row[1]), "use": str(row[2])})
		out.append({
			"id": str(key),
			"name": str(entry.name),
			"gain_db": float(entry.get("gain_db", 0.0)),
			"sounds": rows,
		})
	return out

## 自检：分类表里列了、但磁盘上没有的音效文件。
## 这就是「分类」的实用价值 —— 换素材/加音效时能一眼看出漏了哪个。
func missing_files() -> Array:
	var out: Array = []
	for key in CATALOG:
		for row in CATALOG[key].sounds:
			var id := str(row[0])
			if _load_stream(id) == null:
				out.append(id)
	return out

## 已接上玩法的音效（分类表全量），用于统计覆盖率
func catalog_ids() -> Array:
	var out: Array = []
	for key in CATEGORY_ORDER:
		if not CATALOG.has(key):
			continue
		for row in CATALOG[key].sounds:
			out.append(str(row[0]))
	return out

## 时长文本（试听页列表用）
func duration_text(id: String) -> String:
	var stream := _load_stream(id)
	if stream == null:
		return "缺失"
	return "%.2fs" % stream.get_length()

# ---------------------------------------------------------------- 试听（给试听页用）
#
# 「整类试听」需要一个定时器来一首一首放。用 _process 累加而不是 SceneTreeTimer：
# 一来不用管理 Timer 的生命周期（页面关掉时不会有悬挂的回调），
# 二来和节流用的同一个 _time，避免两套时钟。

var _audition: Array = []
var _audition_gap := 0.7
var _audition_next := 0.0

## 依次试听某一分类的全部音效。返回这一类的音效数（0 表示分类名不对）。
func audition_category(category: String, gap: float = 0.7) -> int:
	if not CATALOG.has(category):
		return 0
	_audition.clear()
	for row in CATALOG[category].sounds:
		_audition.append(str(row[0]))
	_audition_gap = maxf(0.25, gap)
	_audition_next = 0.0
	return _audition.size()

func stop_audition() -> void:
	_audition.clear()

func audition_running() -> bool:
	return not _audition.is_empty()

## 试听一个音效。走的是和游戏里完全相同的分类音量偏移，
## 所以听到的就是实际配比 —— 不能为了「听得清楚」把音量拉平，
## 那样试听页会骗人：进游戏才发现某个音效根本听不见/太吵。
func audition(id: String) -> bool:
	return play(id, 0.0, 1.0, "audition")

# ---------------------------------------------------------------- 偏好读写（不硬依赖 HarborPrefs）

func _prefs() -> Variant:
	return get_node_or_null("/root/HarborPrefs")

func enabled() -> bool:
	var prefs: Variant = _prefs()
	if prefs != null:
		var values: Variant = prefs.get("values")
		if values is Dictionary and values.has("sfx"):
			return bool(values["sfx"])
	return _fallback_enabled

func volume() -> float:
	var prefs: Variant = _prefs()
	if prefs != null and prefs.get("sfx_volume") != null:
		return clampf(float(prefs.sfx_volume), 0.0, 1.0)
	return _fallback_volume

func set_enabled(value: bool) -> void:
	var prefs: Variant = _prefs()
	if prefs != null:
		var values: Variant = prefs.get("values")
		if values is Dictionary and values.has("sfx"):
			values["sfx"] = value
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
	if prefs != null and prefs.get("sfx_volume") != null:
		prefs.sfx_volume = clamped
		prefs.save()
	else:
		_fallback_volume = clamped

# ---------------------------------------------------------------- 播放

## 播一个一次性音效。channel 为空时用文件名当声道。
## 返回是否真的播了（被节流 / 未启用 / 文件缺失都会返回 false）。
func play(name: String, volume_db: float = 0.0, pitch: float = 1.0, channel: String = "") -> bool:
	if name == "" or not enabled():
		return false
	var ch := channel if channel != "" else name
	var gap := float(GAPS.get(ch, GAPS["default"]))
	if _time - float(_last.get(ch, -999.0)) < gap:
		return false
	var stream := _load_stream(name)
	if stream == null:
		return false
	_last[ch] = _time
	var p := _take_voice()
	var idx := _players.find(p)
	p.stream = stream
	p.pitch_scale = maxf(0.05, pitch)
	# 分类音量偏移在这里叠加一次，存进 _base_db；
	# 每帧刷新只叠主音量，不然会把分类偏移冲掉。
	var base := volume_db + category_gain_db(name)
	if idx >= 0:
		_base_db[idx] = base
	p.volume_db = base + _master_db()
	p.play()
	return true

## 界面点击（树级钩子用；手动调用也可以）
func ui(kind: String = "ui_click") -> bool:
	return play(kind, -2.0, 1.0, "ui")

func stop_all() -> void:
	for p in _players:
		p.stop()

# ---------------------------------------------------------------- 内部

func _master_db() -> float:
	return linear_to_db(maxf(volume(), 0.0001))

## 优先拿空闲声部；全忙就抢最早那个（轮转顺序天然是最旧的）
func _take_voice() -> AudioStreamPlayer:
	for i in _players.size():
		var idx := (_next + i) % _players.size()
		if not _players[idx].playing:
			_next = (idx + 1) % _players.size()
			return _players[idx]
	var fallback := _players[_next]
	_next = (_next + 1) % _players.size()
	return fallback

func _process(delta: float) -> void:
	_time += delta
	# 音量每帧刷新：设置里拖动滑条时，正在播的音效要跟着变
	var master := _master_db()
	for i in _players.size():
		var p := _players[i]
		if p.playing:
			p.volume_db = _base_db[i] + master
		elif p.volume_db > -79.0:
			p.volume_db = -80.0
	# 「整类试听」的推进
	if not _audition.is_empty():
		_audition_next -= delta
		if _audition_next <= 0.0:
			_audition_next = _audition_gap
			play(str(_audition.pop_front()), 0.0, 1.0, "audition")

func _on_node_added(node: Node) -> void:
	if node is Button and not node.has_meta("sfx_click_hooked"):
		node.set_meta("sfx_click_hooked", true)
		node.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	ui()

## 解析 WAV 并缓存。只支持 16bit PCM 单/双声道 —— 和 MusicDirector 同一口径。
func _load_stream(name: String) -> AudioStreamWAV:
	if _streams.has(name):
		return _streams[name]
	var bytes := FileAccess.get_file_as_bytes(DIR + name + ".wav")
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		if not _missing_warned:
			_missing_warned = true
			push_warning("[SfxDirector] 读取不到音效：" + DIR + name + ".wav（先跑 tools/sfx_synth.gd 生成）")
		_streams[name] = null
		return null
	var channels := int(bytes.decode_u16(22))
	if bytes.decode_u16(20) != 1 or bytes.decode_u16(34) != 16 or (channels != 1 and channels != 2):
		push_warning("[SfxDirector] 只支持 16bit 单声道或立体声 PCM：" + name)
		_streams[name] = null
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
		_streams[name] = null
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels == 2
	stream.data = pcm
	# 音效不循环 —— 这是和 BGM 唯一的格式差别
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_streams[name] = stream
	return stream
