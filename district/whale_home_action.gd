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
		"curtain":return "合上窗帘" if opened else "拉开窗帘"
		"room_lamp":return "关闭阅读灯" if opened else "打开阅读灯"
		"wardrobe":return "合上衣柜" if opened else "拉开衣柜"
		"water":return "给花箱浇水"
		"sea_rest":return "吹会儿海风"
		"chime":return "收起风铃" if opened else "挂起风铃"
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
	elif kind=="curtain":
		for part in parts:
			part.scale.x=.22 if opened else 1.0
			part.position.x=float(part.get_meta("curtain_side"))*(2.5 if opened else 1.3)
	elif kind=="wardrobe":
		for part in parts:part.position.x=.95 if opened else -.95
	elif kind=="room_lamp":_lamp_pose()
	elif kind=="water":
		for part in parts:
			if part.has_meta("plant_bloom"):part.scale=Vector3.ONE*(1.0 if opened else .65)
	elif kind=="chime":_chime_pose()

func _chime_pose() -> void:
	parts[0].visible=opened;parts[0].rotation.z=0.0
	if opened:
		motion=create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		motion.tween_property(parts[0],"rotation:z",.12,1.4).from(-.12)
		motion.tween_property(parts[0],"rotation:z",-.12,1.4)

func _lamp_pose() -> void:
	for part in parts:
		if part is OmniLight3D:part.visible=opened
		elif part is MeshInstance3D:
			var material: StandardMaterial3D=part.material_override
			material.emission_enabled=opened
			material.albedo_color=Color("fff0bd") if opened else Color("d3cfba")

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
		"curtain","wardrobe":
			opened=not opened;busy=true;set_meta("map_busy",true)
			motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			for part in parts:
				if kind=="curtain":
					motion.tween_property(part,"scale:x",.22 if opened else 1.0,.8)
					motion.tween_property(part,"position:x",float(part.get_meta("curtain_side"))*(2.5 if opened else 1.3),.8)
				else:motion.tween_property(part,"position:x",.95 if opened else -.95,.7)
			motion.finished.connect(func():busy=false;set_meta("map_busy",false))
			if kind=="curtain":note="窗帘收向两边，海湾又映进了窗框。" if opened else "合上柔软的窗帘，给房间留一小片安静。"
			else:note="衣柜滑门拉开了，干净的毛巾、被褥和备用衣物分层收好。" if opened else "滑门轻轻合拢，把整齐的日常收回柜里。"
		"room_lamp":
			opened=not opened;_lamp_pose()
			note="阅读灯亮了，暖光落在身边。" if opened else "阅读灯关好了，房间留给窗外的光。"
		"water":
			opened=true;busy=true;set_meta("map_busy",true)
			var can: Node3D=parts[0]
			var stream: Node3D=can.get_node("PouringWater")
			stream.show()
			motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
			motion.tween_property(can,"rotation:x",-.35,.3)
			motion.tween_property(can,"rotation:x",0.0,.4).set_delay(.55)
			for part in parts:
				if part.has_meta("plant_bloom"):motion.tween_property(part,"scale",Vector3.ONE,.8)
			motion.finished.connect(func():stream.hide();busy=false;set_meta("map_busy",false))
			note="给花箱浇过水了，小花舒展开来，叶片也精神了一点。"
		"sea_rest":
			game.atmosphere.set_time(game.atmosphere.hour+.5)
			note="看海湾的云慢慢走过，半小时也跟着海风溜走了。"
		"chime":
			opened=not opened;_chime_pose()
			note="把小鲸鱼风铃挂回檐下，海风轻轻摇动了纸签。" if opened else "风铃收好了，让这片庭院安静一会儿。"
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
