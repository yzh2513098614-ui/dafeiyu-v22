extends Node3D
## Furniture actions are resolved by the existing E/click map interaction system.
var game
var kind := ""
var action_id := ""
var opened := false
var parts: Array[Node3D] = []
var motion: Tween
var busy := false

func configure(owner_game, action: String, id: String, title: String) -> void:
	game=owner_game;kind=action;action_id="whale_home:facility:"+id
	opened=bool(game.visited.get(action_id,false))
	set_meta("interaction_title",title);set_meta("interaction_height",1.7)
	set_meta("home_dynamic",true);set_meta("home_action",kind)

func has_action() -> bool:return true

func map_action() -> String:
	match kind:
		"fridge","cabinet":return "关上柜门" if opened else "打开柜门"
		"tea":return "泡一壶海盐花茶"
		"cook":return "准备鲸鱼早餐"
		"bake":return "烤一盘星星饼干"
		"flowers":return "整理海风花束"
		"read":return "翻到下一页"
		"sketch":return "画一张海湾速写"
		"aquarium":return "喂小鱼"
		"bed":return "休息两小时"
		"scope":return "转动望远镜"
		"mail":return "读家门口的信"
		"lamp":return "关闭灯串" if opened else "点亮灯串"
	return "看看"

func map_detail() -> String:return str(get_meta("interaction_title",""))

func restore_pose() -> void:
	if kind in ["fridge","cabinet"]:
		for part in parts:part.rotation.y=deg_to_rad(-103.0) if opened else 0.0
	elif kind=="read":
		for part in parts:part.rotation.z=PI if opened else 0.0

func interact() -> void:
	if busy:return
	if motion and motion.is_valid():motion.kill()
	var note := ""
	match kind:
		"fridge","cabinet":
			opened=not opened
			motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			for part in parts:motion.tween_property(part,"rotation:y",deg_to_rad(-103.0) if opened else 0.0,.65)
			note="里面的牛奶、果酱和蓝鲸餐具都摆得整整齐齐。" if opened else "柜门轻轻合上了。"
		"tea","cook","bake","flowers","sketch":
			busy=true;set_meta("map_busy",true)
			motion=create_tween()
			for part in parts:
				var origin: Vector3=part.position
				motion.tween_property(part,"position",origin+Vector3.UP*.13,.25)
				motion.tween_property(part,"position",origin,.4)
			motion.finished.connect(func():busy=false;set_meta("map_busy",false))
			match kind:
				"tea":note="花茶泡好了，桌上还有一份星星饼干。"
				"cook":note="煎蛋、吐司和热牛奶，今天也好好吃早餐。"
				"bake":note="星星饼干出炉了，烤盘上还留着暖暖的黄油香。"
				"flowers":note="把粉白小花和鼠尾草叶扎成一束，给海风留一个位置。"
				"sketch":note="画下了海湾、灯塔和一只慢悠悠的小蓝鲸。"
		"read":
			opened=not opened;busy=true;set_meta("map_busy",true)
			motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			for part in parts:motion.tween_property(part,"rotation:z",PI if opened else 0.0,.65)
			motion.finished.connect(func():busy=false;set_meta("map_busy",false))
			note="这一页写着：鲸鱼用歌声，记住很远很远的朋友。" if opened else "翻回海湾手记的扉页，书签还停在那片蓝色海面。"
		"aquarium":
			game.home_controller.feeding=6.0
			note="小鱼们游过来了！水族箱里的蓝鲸也跟着摇尾巴。"
		"bed":
			game.atmosphere.set_time(game.atmosphere.hour+2.0)
			note="在鲸鱼床上休息了一会儿，海风替你翻过了两小时。"
		"scope":
			opened=not opened;motion=create_tween()
			for part in parts:motion.tween_property(part,"rotation:y",.48 if opened else -.20,.8)
			note="望远镜转向了海湾灯塔；夜里这里最适合看星星。"
		"mail":note="大肥鱼的信：厨房留了点心，楼上留了星光。这座小屋，也给你留了一个位置。"
		"lamp":
			opened=not opened
			game.home_controller.extra_lights=opened
			note="星星灯串亮起来了。" if opened else "灯串熄灭，留下温柔的海景。"
	game.visited[action_id]=opened
	game.home_controller.show_notice(note)
	if game.life_booted:game._save()
