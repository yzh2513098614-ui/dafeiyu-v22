extends RefCounted
## The inhabited garden sits inside the wall; the promenade follows its outside.
const Geo = preload("res://district/story_geometry.gd")
const Ground = preload("res://assets/whale_home/garden_ground.gd")
const Door = preload("res://district/interactive_door.gd")
const Fountain = preload("res://district/whale_home_fountain.gd")
const WALL_RECT := Rect2(-46, -46, 92, 73)
const CREAM := Color("eee6d2")
const CAP := Color("f8efd9")
const BLUE := Color("547a9c")
const GOLD := Color("d6b774")
var b
var gate_x := 3.5

func build(builder) -> void:
	b = builder
	gate_x = b.level.get_meta("grand_gate").global_position.x
	var root: Node3D = b._group(b.level.get_node("Island"), "CastleGardenBoundary")
	_segment(root, Vector2(-46, -46), Vector2(46, -46))
	_segment(root, Vector2(-46, -46), Vector2(-46, 27))
	_segment(root, Vector2(46, -46), Vector2(46, 27))
	_segment(root, Vector2(-46, 27), Vector2(gate_x - 4.5, 27))
	_segment(root, Vector2(gate_x + 4.5, 27), Vector2(46, 27))
	_gate(root)
	_fountain(root)
	_planting(root)
	_promenade(root)
	b.level.set_meta("estate_boundary", WALL_RECT)
	b.level.set_meta("island_area_m2", b.ISLAND_RECT.get_area())
	b.level.set_meta("island_area_multiplier", b.ISLAND_RECT.get_area() / 5880.0)
	b.level.set_meta("estate_revision", "enclosed_island_castle_v1")

func _pillar(parent: Node3D, x: float, height: float = 2.45) -> void:
	b._box(parent, Vector3(.94, .22, .94), Vector3(x, .11, 0), CREAM)
	b._box(parent, Vector3(.67, height - .38, .67), Vector3(x, height * .5, 0), CREAM)
	for y in [.40, height - .22]:
		b._box(parent, Vector3(.81, .14, .81), Vector3(x, y, 0), CAP)
	b._box(parent, Vector3(.94, .20, .94), Vector3(x, height, 0), CAP)
	for y in [.8, 1.3, 1.8]:
		if y < height - .3: b._box(parent, Vector3(.68, .018, .68), Vector3(x, y, 0), Color("dfd5c1"), 0, .002)

func _segment(parent: Node3D, a: Vector2, c: Vector2) -> void:
	var d: Vector2 = c - a
	var root: Node3D = b._group(parent, "CreamWallBlueIron", Vector3((a.x + c.x) * .5, 0, (a.y + c.y) * .5))
	root.rotation.y = -atan2(d.y, d.x)
	root.set_meta("estate_wall_segment", [a, c])
	var bays: int = ceili(d.length() / 6.5)
	var width: float = d.length() / bays
	b._box(root, Vector3(d.length(), 1.22, .54), Vector3(0, .61, 0), CREAM, 0, .045)
	b._box(root, Vector3(d.length(), .17, .73), Vector3(0, 1.26, 0), CAP)
	b._box(root, Vector3(d.length(), .22, .72), Vector3(0, .11, 0), Color("cfc8b6"))
	for y in [1.45, 2.02]:
		b._box(root, Vector3(d.length(), .075, .10), Vector3(0, y, 0), BLUE, 0, .009)
	for i in ceili(d.length() / .46) + 1:
		var x: float = -d.length() * .5 + minf(i * .46, d.length())
		Geo.rod(root, Vector3(x, 1.34, 0), Vector3(x, 2.16, 0), .025, BLUE)
		if i % 3 == 0: b._sphere(root, Vector3(x, 2.19, 0), Vector3(.09, .12, .09), GOLD)
	for i in bays + 1: _pillar(root, -d.length() * .5 + i * width)
	b._coll(root, Vector3(d.length(), 2.3, .64), Vector3(0, 1.15, 0))

func _gate(parent: Node3D) -> void:
	var surround: Node3D = b._group(parent, "GardenMainGate", Vector3(gate_x, 0, 27))
	for side in [-1.0, 1.0]:
		_pillar(surround, side * 4.5, 3.15)
		b._coll(surround, Vector3(.94, 3.3, .94), Vector3(side * 4.5, 1.65, 0))
		b._fixture(surround, Vector3(side * 4.5, 2.0, .54))
	var door := Door.new()
	door.name = "GardenSeaGate"
	surround.add_child(door)
	door.set_meta("home_dynamic", true)
	door.configure(b.game, 8.0, "garden_sea_gate", "海岛庭院大门", 2.7)
	for index in 2:
		var pivot: Node3D = door.pivots[index]
		for child in pivot.get_children():
			if child is MeshInstance3D: child.free()
		var side: float = -1.0 if index == 0 else 1.0
		var width: float = 3.94
		var x: float = -side * width * .5
		b._box(pivot, Vector3(width, 1.18, .13), Vector3(x, .66, 0), BLUE)
		for y in [.14, 1.21, 2.60]: b._box(pivot, Vector3(width, .09, .16), Vector3(x, y, 0), GOLD, 0, .012)
		for i in 10:
			var px: float = -side * (.14 + i * .40)
			Geo.rod(pivot, Vector3(px, 1.2, 0), Vector3(px, 2.65 + sin(i / 9.0 * PI) * .18, 0), .028, BLUE)
		b._whale(pivot, Vector3(x, .70, .12), .44, 90, GOLD)
		b._batch(pivot, false)
	door._pose(door.fraction)
	b.level.set_meta("garden_gate", door)

func _fountain(parent: Node3D) -> void:
	var root := Fountain.new(); root.name = "CourtyardSeaFountain"; root.position = Vector3(gate_x,0,17.0)
	parent.add_child(root); root.build(b)
	b._coll(root, Vector3(4.65, 1.35, 4.65), Vector3(0, .675, 0))
	b.level.set_meta("estate_fountain", root)

func _planting(parent: Node3D) -> void:
	var clearings: Array[Rect2] = [Rect2(-24.85,18.15,1.7,1.7),Rect2(23.15,18.15,1.7,1.7)]
	var tufts := 0
	for rect: Rect2 in [Rect2(-44, -44, 88, 3), Rect2(-44, -41, 2.5, 66), Rect2(41.5, -41, 2.5, 66), Rect2(-42, 24, 35, 1.7), Rect2(14, 24, 28, 1.7),Rect2(-28.5,15.3,9,10.4),Rect2(19.5,15.3,9,10.4)]:
		tufts += Ground.lawn(parent, rect, clearings, int(rect.position.x * rect.position.y) + 9120)
	b.level.set_meta("lawn_patches",int(b.level.get_meta("lawn_patches"))+7)
	b.level.set_meta("lawn_tufts",int(b.level.get_meta("lawn_tufts"))+tufts)
	for side in [-1.0, 1.0]:
		for i in 23:
			var z: float = -42 + i * 2.9
			b.Pastel.clump(parent, Vector3(side * 44.1, .58, z), Vector3(1.1, 1.08, 2.5), b.GREEN)
			if i % 3 == 0: b._flower(parent, Vector3(side * 43.8, 1.15, z), b.SAKURA, .30)
	for x in range(-40, 43, 3):
		if x > gate_x - 7 and x < gate_x + 7: continue
		b.Pastel.clump(parent, Vector3(x, .52, 25.2), Vector3(2.7, .95, 1.1), b.GREEN)
		b._flower(parent, Vector3(x, 1.02, 25.1), b.SAKURA if x % 2 else CAP, .33)
	_formal_beds(parent)

func _formal_beds(parent: Node3D) -> void:
	var root: Node3D = b._group(parent, "FrontCourtRoseParterres")
	# Reuse the existing lawns and clip their borders to the paved walking lanes.
	for lawn: Rect2 in [Rect2(-14.4,12.5,8.2,9.0),Rect2(10.85,12.5,3.55,9.0),Rect2(-28.5,15.3,9,10.4),Rect2(19.5,15.3,9,10.4)]:
		for rect: Rect2 in Ground._remaining(lawn):
			if rect.size.x < 2.5 or rect.size.y < 2.5: continue
			var a := rect.position + Vector2(.22,.22)
			var c := rect.end - Vector2(.22,.22)
			_flower_edge(root, Vector2(a.x,c.y), c)
			_flower_edge(root, a, Vector2(a.x,c.y))
			_flower_edge(root, Vector2(c.x,a.y), c)
			if rect.position.x < -14.0 and rect.end.x > -7.0:
				# The porch-side opening lines up with the existing entrance path.
				_flower_edge(root, a, Vector2(-11.1,a.y))
				_flower_edge(root, Vector2(-8.1,a.y), Vector2(c.x,a.y))
			else:
				_flower_edge(root, a, Vector2(c.x,a.y))

func _flower_edge(parent: Node3D, a: Vector2, c: Vector2) -> void:
	var length: float = a.distance_to(c)
	var root: Node3D = b._group(parent, "LowCreamRoseBorder", Vector3((a.x+c.x)*.5,0,(a.y+c.y)*.5))
	root.rotation.y = -atan2(c.y-a.y,c.x-a.x)
	b._box(root, Vector3(length,.18,.48), Vector3(0,.13,0), CREAM, 0, .035)
	b._box(root, Vector3(length,.44,.58), Vector3(0,.39,0), Color("82a878"), 0, .035)
	var count: int = maxi(1,ceili(length/.72))
	for i in count:
		var x: float = (float(i)+.5)*length/count-length*.5
		b.Pastel.clump(root, Vector3(x,.54,0), Vector3(.92,.60,.78), Color("82a878"))
		b._flower(root, Vector3(x,.82,.16), Color("e2a1b6") if i%3 else CAP, .24)
		if i%2==0:b._flower(root, Vector3(x-.19,.68,-.20), CAP, .19)

func _promenade(parent: Node3D) -> void:
	for side in [-1.0, 1.0]:
		b._rail(parent, Vector3(side * 53.1, 0, -52.1), Vector3(side * 53.1, 0, 34.0), false)
	b._rail(parent, Vector3(-53.1, 0, -52.1), Vector3(53.1, 0, -52.1), false)
	for span: Vector2 in [Vector2(-53.1, -22.5), Vector2(-16.0, -3.4), Vector2(3.4, 53.1)]:
		b._rail(parent, Vector3(span.x, 0, 34.0), Vector3(span.y, 0, 34.0), false)
	for side in [-1.0, 1.0]:
		for z in [-42.0, -15.0, 12.0, 30.0]:
			var lamp: Node3D = b._group(parent, "SeafrontLantern", Vector3(side * 51.4, 0, z))
			Geo.cylinder(lamp, .25, .16, Vector3(0, .08, 0), CREAM)
			Geo.rod(lamp, Vector3(0, .1, 0), Vector3(0, 3.05, 0), .065, BLUE)
			b._fixture(lamp, Vector3(0, 2.95, 0))
	for x in [-34.0, 27.0]:
		var bench: Node3D = b._model(parent, b.BENCH, Vector3(x, .02, 32.0), true)
		b._coll(bench, Vector3(2.2, 1.24, .83), Vector3(0, .62, 0))
