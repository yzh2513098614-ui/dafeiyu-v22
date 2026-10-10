extends RefCounted
## Only receives the start-of-window battlefield. Player queue is never an input.
static func plan(units: Dictionary, grid, window: int, actor_id: String = "enemy") -> Array:
	var enemy: Dictionary=units[actor_id]
	var p: Vector2i=grid.cell(units.player.pos)
	var e: Vector2i=grid.cell(enemy.pos)
	var occupied: Array=[p]
	var count:=0
	for id in units:
		if id!="player" and int(units[id].hp)>0:
			count+=1
			if id!=actor_id:occupied.append(grid.cell(units[id].pos))
	var output: Array=[]
	for slot in 3:
		var kind := "attack"
		var value := 7 if count==1 else 4
		if slot==0:
			match str(enemy.kind):
				"guardian": kind="shield"; value=9
				"hallucination": kind="jam"; value=1
				"injector": kind="corrupt"; value=1
				"berserker": kind="charge"; value=2+window
		elif grid.distance(e,p)>3 or not grid.sight(e,p):
			kind="move"; value=2
			var candidates: Array=[]
			for y in grid.side:
				for x in grid.side:
					var c:=Vector2i(x,y)
					if not c in occupied and not grid.path(e,c,2,occupied).is_empty(): candidates.append(c)
			candidates.sort_custom(func(a,b): return grid.distance(a,p)*64+a.y*8+a.x<grid.distance(b,p)*64+b.y*8+b.x)
			if not candidates.is_empty(): e=candidates[0]
		if enemy.kind=="berserker" and kind=="attack": value+=window*2
		output.append({"kind":kind,"value":value,"range":4,"target":grid.packed(e),"target_actor":"player","name":{"attack":"数据攻击","shield":"封锁护盾","jam":"虚假信号","corrupt":"注入污染","charge":"过载蓄力","move":"逼近"}[kind]})
	return output
