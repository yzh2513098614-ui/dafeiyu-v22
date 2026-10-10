extends SceneTree
## 练习场循环的检查。跑法：
##   godot --headless --path <工程目录> --script res://tools/test_practice_loop.gd
##
## 为什么需要它：清完 5 个遭遇点之后，「再练一次」是玩家唯一还能继续打的东西。
## 原来这条路**只置 practice_defeated 再提示「不重复发奖」，一点经验都不给** ——
## 机制上能重打、收益上是死路。这个测试盯的就是「这条路必须真的能推等级」。
##
## 只测纯计算部分（practice_xp_for）：结算那一段要 game/hint/存档，脱离场景测不了。

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS ", message)
	else:
		failed += 1
		push_error("FAIL " + message)

func run() -> void:
	var controller = load("res://combat/combat_controller.gd").new()
	var balance: Dictionary = controller.balance
	var monsters: Dictionary = balance.get("monsters", {})
	check(monsters.size() == 4, "combat_balance 里有 4 只怪")

	# 练习经验必须对每只怪都 > 0，否则那只怪的练习就是白打
	var zero: Array = []
	print("  怪         正式经验  练习经验")
	for kind in monsters:
		var formal := int(monsters[kind].get("xp", 0))
		var practice := int(controller.practice_xp_for(str(kind)))
		print("  %-10s %-9d %d" % [str(kind), formal, practice])
		if practice <= 0:
			zero.append(str(kind))
		check(practice < formal, "练习经验少于正式 " + str(kind))
	check(zero.is_empty(), "每只怪的练习经验都 > 0（否则这条循环对它没意义）")

	# 认不出的怪不能崩，也不该给经验
	check(int(controller.practice_xp_for("no_such_monster")) == 0, "未知怪物给 0 经验而不是报错")

	# 只靠练习能不能推到满级？推不到就说明比例低到没有意义
	var model = load("res://character/life_state.gd").new()
	var fights := 0
	var guard := 0
	while int(model.state.level) < 30 and guard < 200000:
		model.gain_xp(int(controller.practice_xp_for("guardian")))
		fights += 1
		guard += 1
	print("  只靠练习守潮者（%d 经验/场）升到 30 级需要 %d 场" % [int(controller.practice_xp_for("guardian")), fights])
	check(int(model.state.level) == 30, "练习场能推到满级")
	check(fights > 0 and fights < 5000, "满级场次在合理范围（当前 %d 场）" % fights)

	# 顺带确认升级确实涨了不止耐力/学识（这是上一轮改的，别被回退掉）
	var grew := 0
	for key in ["strength", "endurance", "insight", "charm", "agility", "luck"]:
		if int(model.state.base.get(key, 0)) > int(model.balance.initial.get(key, 0)):
			grew += 1
	check(grew == 6, "升级后六项属性都涨了（实际 %d 项）" % grew)
	controller.free()
	if failed == 0:
		print("PRACTICE LOOP CHECKS PASSED")
	else:
		print("PRACTICE LOOP FAILURES ", failed)
	quit(failed)
