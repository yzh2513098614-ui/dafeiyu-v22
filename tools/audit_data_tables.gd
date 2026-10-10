extends SceneTree
## 跨数据表审计。跑法：
##   godot --headless --path <工程目录> --script res://tools/audit_data_tables.gd
##
## 为什么需要它：这个工程把内容拆在好几张表里，它们之间靠 **字符串 id** 相连。
## 任何一处写错字都**不会报错**，只会静默失效：箱子打不开、物品在背包里没图标、
## 卡面空白、怪物不出招。肉眼翻表很难发现，所以用脚本全量对一遍。
##
## 两个刻意的设计决定：
##   1. **不 preload 游戏脚本**。container_rooms.gd 引用了 SfxDirector 这个 autoload，
##      在 --script 模式下编译顺序不保证，会报 "Failed to compile depended scripts"。
##      改成从源码文本里抠常量块，工具就能在任何上下文跑。
##   2. **物品定义表用 assets/meme_items.json**，不是 character_balance.json 的 items。
##      后者只管消耗/装备效果；前者才是背包认的那张表（loot_controller 第 79 行加载的）。
##      我第一版比错了表，一次报了 14 条假缺口。
##
## 全部只读，不改任何文件。

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func problem(msg: String) -> void:
	failed += 1
	print("  !! ", msg)

func note(msg: String) -> void:
	print("  .. ", msg)

func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _ids_of(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for e in raw:
			out.append(str(e.get("id", "")))
	elif raw is Dictionary:
		for k in raw:
			out.append(str(k))
	out.sort()
	return out

func _re_all(pattern: String, text: String, group: int = 1) -> Array:
	var out: Array = []
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		return out
	for m in re.search_all(text):
		out.append(m.get_string(group))
	return out

## 从源码里抠出 `const <name> := {` … 到下一个顶层 `const` 之间的块
func _const_block(src: String, name: String) -> String:
	var start := src.find("const " + name)
	if start < 0:
		return ""
	var open := src.find("{", start)
	if open < 0:
		return ""
	var nxt := src.find("\nconst ", open)
	if nxt < 0:
		nxt = src.length()
	return src.substr(open, nxt - open)

## 把 `"type":{"item":n, ...}` 形式的块解析成 {type: [item...]}
func _parse_stock_block(block: String) -> Dictionary:
	var out: Dictionary = {}
	var re := RegEx.new()
	if re.compile("\"([a-z0-9_]+)\"\\s*:\\s*\\{([^}]*)\\}") != OK:
		return out
	for m in re.search_all(block):
		var type_id := m.get_string(1)
		var items: Array = []
		for item in _re_all("\"([a-z0-9_]+)\"\\s*:\\s*\\d+", m.get_string(2)):
			if not (item in items):
				items.append(item)
		out[type_id] = items
	return out

func run() -> void:
	var cr_src := FileAccess.get_file_as_string("res://district/container_rooms.gd")
	var loot_src := FileAccess.get_file_as_string("res://loot_controller.gd")
	var stock: Dictionary = _parse_stock_block(_const_block(cr_src, "STOCK"))
	var initial: Dictionary = _parse_stock_block(_const_block(loot_src, "INITIAL_STOCK"))

	print("=== ① 容器类型 ↔ 容器内容表 ===")
	var specs: Array = _ids_of(_json("res://container_specs.json"))
	print("  container_specs.json 定义 %d 种；ContainerRooms.STOCK 写了 %d 种内容" % [specs.size(), stock.size()])
	var no_stock: Array = []
	for id in specs:
		if not stock.has(str(id)):
			no_stock.append(str(id))
	if no_stock.is_empty():
		print("  每种容器都有自己的内容 ✓")
	else:
		note("没写内容、会退到 STOCK_DEFAULT：%s" % str(no_stock))
	var ghost: Array = []
	for id in stock:
		if not (str(id) in specs):
			ghost.append(str(id))
	if ghost.is_empty():
		print("  STOCK 里没有 container_specs 之外的类型 ✓")
	else:
		problem("STOCK 里有 container_specs 不存在的类型（永远打不开的死表项）：%s" % str(ghost))

	print("\n=== ② 实际摆进房间的容器 ↔ 容器表 ===")
	var placed: Array = []
	for id in _re_all("_container\\(g, \"([a-z0-9_]+)\"", cr_src):
		if not (id in placed):
			placed.append(id)
	placed.sort()
	print("  代码里实际摆了 %d 种" % placed.size())
	var placed_unknown: Array = []
	for id in placed:
		if not (str(id) in specs):
			placed_unknown.append(str(id))
	if placed_unknown.is_empty():
		print("  摆出来的都是 container_specs 里的类型 ✓")
	else:
		problem("摆了不存在的容器类型（场上会是打不开的假箱子）：%s" % str(placed_unknown))
	var never_placed: Array = []
	for id in specs:
		if not (str(id) in placed):
			never_placed.append(str(id))
	if never_placed.is_empty():
		print("  30 种容器都被用上了 ✓")
	else:
		note("有定义但从未摆出（模型闲置）：%d 种 %s" % [never_placed.size(), str(never_placed)])

	print("\n=== ③ 物品 id ↔ 物品定义（assets/meme_items.json）===")
	var defs: Dictionary = _json("res://assets/meme_items.json")
	var used: Dictionary = {}
	for type_id in stock:
		for item_id in stock[type_id]:
			used[str(item_id)] = true
	for type_id in initial:
		for item_id in initial[type_id]:
			used[str(item_id)] = true
	print("  meme_items.json 定义 %d 件；容器+初始库存引用 %d 件" % [defs.size(), used.size()])
	var undefined: Array = []
	for id in used:
		if not defs.has(str(id)):
			undefined.append(str(id))
	if undefined.is_empty():
		print("  引用的物品 id 全都有定义 ✓")
	else:
		problem("引用了未定义的物品 id（背包里没有图标和说明）：%s" % str(undefined))
	var unobtainable: Array = []
	for id in defs:
		if not used.has(str(id)):
			unobtainable.append(str(id))
	if unobtainable.is_empty():
		print("  每件物品都至少有一个获取途径 ✓")
	else:
		note("已定义但当前没有任何获取途径：%d 件 %s" % [unobtainable.size(), str(unobtainable)])

	print("\n=== ④ 卡牌 ↔ 卡图 ===")
	var raw_cards: Variant = _json("res://assets/cards/catalog.json")
	var missing_art: Array = []
	var card_count := 0
	if raw_cards is Array:
		for card in raw_cards:
			card_count += 1
			var img := str(card.get("image", ""))
			if img == "" or not ResourceLoader.exists(img):
				missing_art.append(str(card.get("id", "?")))
	print("  catalog 有 %d 张卡" % card_count)
	if missing_art.is_empty():
		print("  每张卡的图都能加载 ✓")
	else:
		problem("卡图缺失：%s" % str(missing_art))

	print("\n=== ⑤ 怪物 kind ↔ 敌人 AI/技能配置 ===")
	var combat: Dictionary = _json("res://assets/combat_balance.json")
	var battle: Dictionary = _json("res://assets/battle_data.json")
	var kinds: Array = combat.get("monsters", {}).keys()
	kinds.sort()
	var enemies: Dictionary = battle.get("enemies", {})
	var enemy_skills: Dictionary = battle.get("enemy_skills", {})
	print("  战斗数值 %d 只怪：%s；敌人技能表 %d 条" % [kinds.size(), str(kinds), enemy_skills.size()])
	var bad_ai: Array = []
	for kind in kinds:
		if not enemies.has(str(kind)):
			bad_ai.append("%s 没有 AI 配置" % str(kind))
			continue
		var e: Dictionary = enemies[str(kind)]
		for s in e.get("skills", []):
			if not enemy_skills.has(str(s)):
				bad_ai.append("%s 的技能 %s 未定义" % [str(kind), str(s)])
	for kind in enemies:
		if not (str(kind) in kinds):
			bad_ai.append("enemies 里的 %s 在战斗数值里没定义" % str(kind))
	if bad_ai.is_empty():
		print("  每只怪的 AI 与技能都在表里 ✓")
	else:
		problem("怪物配置对不上：%s" % str(bad_ai))

	print("\n=== ⑥ 室内模型清单 ↔ 场景文件 ===")
	var interior: Variant = _json("res://interior_pack/catalog.json")
	var bad_scene: Array = []
	var n := 0
	if interior is Array:
		for e in interior:
			n += 1
			var p := str(e.get("scene", ""))
			if p == "" or not ResourceLoader.exists(p):
				bad_scene.append(str(e.get("id", "?")))
	print("  interior_pack 清单 %d 件" % n)
	if bad_scene.is_empty():
		print("  每件的包装场景都在 ✓")
	else:
		problem("清单里有但场景缺失：%s" % str(bad_scene))

	print("")
	if failed == 0:
		print("DATA TABLE AUDIT PASSED（无缺口）")
	else:
		print("DATA TABLE AUDIT 发现 %d 处缺口" % failed)
	quit(0)
