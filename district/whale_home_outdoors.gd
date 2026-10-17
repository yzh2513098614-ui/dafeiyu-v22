extends RefCounted
## Outdoor furnishings use the existing slabs, floor cutaways and E resolver.
const Geo = preload("res://district/story_geometry.gd")
var b

func build(builder) -> void:
	b = builder
	_balcony_tea()
	_watering_box()
	_garden_chime()
	_porch_details()
	_dock_details()
	_garden_edge_details()
	b.level.set_meta("outdoor_revision", "seaside_daily_life_v2")

func _balcony_tea() -> void:
	var h: float = b.HEIGHT
	var tea: Node3D = b._action("tea", "balcony_tea", "2F · 海景露台茶席", Vector3(-15, h, 3.3), h)
	var seat_offset := Vector3(0, 0, 1.8)
	var table: Node3D = b._table(tea, seat_offset, 2.5, 1.2, .74, "garden_table")
	for x in [-.8, .8]: b._cup(table, Vector3(x, .85, .14), b.WHITE)
	var pot: Node3D = b._group(tea, "BalconyTeapot", seat_offset + Vector3(0, .92, 0))
	pot.set_meta("home_dynamic", true)
	b._sphere(pot, Vector3.ZERO, Vector3(.46, .33, .42), b.BLUE)
	Geo.cylinder(pot, .13, .035, Vector3(0, .18, 0), b.GOLD)
	Geo.rod(pot, Vector3(.13, .03, 0), Vector3(.35, .14, 0), .055, b.BLUE)
	tea.parts.append(pot); b._batch(pot, false)
	for side in [-1.0, 1.0]: b._chair(tea, seat_offset + Vector3(side * 2.4, 0, 0), side * 90)
	# Eight fabric gores and ribs form an actual raised sunshade.
	var shade_center := Vector3(0, 0, 1.45)
	Geo.rod(tea, shade_center + Vector3.UP * .8, shade_center + Vector3.UP * 3.45, .045, b.WOOD)
	for i in 8:
		var a: float = i * TAU / 8.0
		var c: float = (i + 1) * TAU / 8.0
		var tip := shade_center + Vector3.UP * 3.45
		var left := shade_center + Vector3(cos(a) * 2.1, 3.0, sin(a) * 2.1)
		var right := shade_center + Vector3(cos(c) * 2.1, 3.0, sin(c) * 2.1)
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		Geo._face(tool, [tip, left, right], Vector3.UP)
		Geo._face(tool, [tip, right, left], Vector3.DOWN)
		var panel := MeshInstance3D.new(); panel.mesh = tool.commit()
		b._cloth(panel, b.WHITE if i % 2 else b.MINT, 0); tea.add_child(panel)
		Geo.rod(tea, tip - Vector3.UP * .025, left - Vector3.UP * .025, .018, b.WOOD)
	b._batch(tea)

func _sea_recliner() -> void:
	var h: float = b.HEIGHT * 2
	var rest: Node3D = b._action("sea_rest", "balcony_rest", "3F · 海风躺椅与小茶几", Vector3(11, h, -.2), h)
	var chair: Node3D = b._furniture(rest, "SeaViewRecliner", Vector3(0, 0, 3.0), 90)
	for side in [-1.0, 1.0]:
		Geo.rod(chair, Vector3(side * .62, .12, -1.25), Vector3(side * .62, .75, 1.25), .055, b.WOOD)
		Geo.rod(chair, Vector3(side * .62, .1, 1.15), Vector3(side * .62, .75, -1.0), .055, b.WOOD)
	var seat: MeshInstance3D = b._box(chair, Vector3(1.35, .20, 1.8), Vector3(0, .73, .38), b.LIGHT, 0, .08)
	b._cloth(seat, b.LIGHT, 1)
	var back: MeshInstance3D = b._box(chair, Vector3(1.35, 1.25, .18), Vector3(0, 1.18, -.78), b.WHITE, 0, .08)
	back.rotation.x = -.32; b._cloth(back, b.WHITE)
	var pillow: MeshInstance3D = b._box(chair, Vector3(.95, .32, .42), Vector3(0, 1.56, -.95), b.SAKURA, 0, .12)
	b._cloth(pillow, b.SAKURA)
	b._coll(chair, Vector3(1.45, 1.5, 2.15), Vector3(0, .75, 0))
	var table: Node3D = b._table(rest, Vector3(3.2, 0, 2.7), 1.25, 1.1, .60, "garden_table")
	b._cup(table, Vector3(-.25, .72, 0), b.BLUE)
	b._books(table, Vector3(.05, .72, -.1), 3)
	b._batch(rest)

func _watering_box() -> void:
	var water: Node3D = b._action("water", "garden_watering", "东侧庭院 · 海风花箱", Vector3(35, 0, -27.5), 0)
	var box: Node3D = b._furniture(water, "WateredGardenBox", Vector3(0, 0, -1.5))
	for side in [-1.0, 1.0]:
		b._finish_box(box, Vector3(4.8, .66, .14), Vector3(0, .35, side * 1.05), "garden_table")
		b._finish_box(box, Vector3(.14, .66, 2.1), Vector3(side * 2.33, .35, 0), "garden_table")
	b._box(box, Vector3(4.5, .12, 1.95), Vector3(0, .55, 0), Color("9b8970"))
	b._coll(box, Vector3(4.8, .68, 2.24), Vector3(0, .34, 0))
	var can: Node3D = b._group(water, "GardenWateringCan", Vector3(-1.5, .72, -.35))
	can.set_meta("home_dynamic", true)
	Geo.cylinder(can, .23, .44, Vector3(0, .22, 0), b.MINT, .21)
	Geo.rod(can, Vector3(0, .2, -.17), Vector3(0, .55, -.75), .065, b.MINT)
	var nozzle := Geo.cylinder(can, .12, .06, Vector3(0, .56, -.77), b.GOLD)
	nozzle.rotation.x = -.7
	for side in [-1.0, 1.0]: Geo.rod(can, Vector3(side * .20, .25, .12), Vector3(side * .20, .65, .12), .025, b.WOOD)
	Geo.rod(can, Vector3(-.20, .65, .12), Vector3(.20, .65, .12), .025, b.WOOD)
	var stream: Node3D = b._group(can, "PouringWater")
	stream.set_meta("home_dynamic", true)
	for i in 4: Geo.rod(stream, Vector3((i - 1.5) * .025, .52, -.82), Vector3((i - 1.5) * .07, -.14, -1.0), .009, b.LIGHT)
	stream.hide(); water.parts.append(can)
	b._batch(stream, false); b._batch(can, false)
	for i in 9:
		var x: float = -1.8 + float(i % 5) * .85
		var z: float = -1.95 + float(i / 5) * .80
		var bloom: Node3D = b._group(water, "GrowingGardenFlower", Vector3(x, .64, z))
		bloom.set_meta("home_dynamic", true); bloom.set_meta("plant_bloom", true)
		Geo.rod(bloom, Vector3.ZERO, Vector3(0, .60, 0), .023, b.GREEN)
		b._sphere(bloom, Vector3(.14, .3, 0), Vector3(.35, .13, .20), b.GREEN)
		b._flower(bloom, Vector3(0, .62, 0), b.SAKURA if i % 2 else b.WHITE, .32)
		water.parts.append(bloom); b._batch(bloom, false)
	water.restore_pose(); b._batch(water)

func _garden_chime() -> void:
	var key := "whale_home:facility:garden_chime"
	if not b.game.visited.has(key): b.game.visited[key] = true
	var chime: Node3D = b._action("chime", "garden_chime", "前庭 · 小鲸鱼风铃", Vector3(-6.8, 0, 19), 0)
	var stand: Node3D = b._furniture(chime, "GardenChimeStand", Vector3.ZERO)
	b._finish_box(stand, Vector3(.18, 3.2, .18), Vector3(0, 1.6, 0), "garden_table")
	b._finish_box(stand, Vector3(1.45, .14, .16), Vector3(.6, 3.12, 0), "garden_table")
	Geo.rod(stand, Vector3(0, 2.5, 0), Vector3(.85, 3.12, 0), .025, b.WOOD)
	b._box(stand, Vector3(.65, .14, .65), Vector3(0, .07, 0), b.STONE)
	b._coll(stand, Vector3(.65, 3.2, .65), Vector3(0, 1.6, 0))
	var bell: Node3D = b._group(chime, "WhaleWindChime", Vector3(1.05, 3.05, 0))
	bell.set_meta("home_dynamic", true)
	Geo.rod(bell, Vector3.ZERO, Vector3(0, -.45, 0), .012, b.GOLD)
	Geo.cylinder(bell, .22, .30, Vector3(0, -.56, 0), b.LIGHT, .07)
	Geo.rod(bell, Vector3(0, -.65, 0), Vector3(0, -1.18, 0), .009, b.GOLD)
	b._box(bell, Vector3(.22, .50, .025), Vector3(0, -1.38, 0), b.WHITE, 0, .01)
	b._whale(bell, Vector3(0, -.67, 0), .17)
	chime.parts.append(bell); b._batch(bell, false)
	chime.restore_pose(); b._batch(chime)

func _ring(parent: Node3D, point: Vector3, radius: float, tube: float, color: Color, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - tube
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 10
	node.mesh = torus
	node.position = point
	node.rotation = rotation
	node.material_override = Geo.material(color)
	parent.add_child(node)
	return node

func _porch_details() -> void:
	var porch: Node3D = b._group(b.level, "PorchDailyDetails", Vector3(-8.7, 0, 18.0))
	# Keep the center approach open while adding the small objects beside the sign.
	b._box(porch, Vector3(1.45, .12, .72), Vector3(-2.0, .08, .42), b.WOOD, 1, .025)
	b._box(porch, Vector3(.42, .10, .68), Vector3(-2.32, .18, .42), b.BLUE, 0, .04)
	b._box(porch, Vector3(.42, .10, .68), Vector3(-1.78, .18, .42), b.SAKURA, 0, .04)
	var shell_bowl: Node3D = b._group(porch, "PorchShellBowl", Vector3(.25, .08, .48))
	Geo.cylinder(shell_bowl, .42, .10, Vector3.ZERO, b.LIGHT, .34)
	for i in 5:
		var a: float = i * TAU / 5.0
		b._soft_ball(shell_bowl, Vector3(cos(a) * .19, .10, sin(a) * .15), Vector3(.12, .06, .14), b.WHITE if i % 2 else b.GOLD)
	b._plant(porch, Vector3(1.65, .04, .36), .62, true)
	var hanging: Node3D = b._group(porch, "PorchShellHanger", Vector3(2.45, 1.55, .12))
	Geo.rod(hanging, Vector3.ZERO, Vector3(0, -.65, 0), .018, b.GOLD)
	_ring(hanging, Vector3(0, -.77, 0), .23, .035, b.WHITE, Vector3(PI * .5, 0, 0))
	b._whale(hanging, Vector3(0, -.83, .03), .12, 90, b.BLUE)
	b._batch(porch)

func _dock_details() -> void:
	var dock: Node3D = b._group(b.level, "DockLooseDetails", Vector3(0, 0, b.DOCK_SHIFT))
	# Loose cargo and rope coils make the dock feel used without changing its lanes.
	var crate: Node3D = b._group(dock, "DockSupplyCrate", Vector3(1.55, .05, 26.65))
	b._box(crate, Vector3(.86, .68, .86), Vector3(0, .34, 0), b.WOOD, 1, .035)
	for side in [-1.0, 1.0]:
		b._box(crate, Vector3(.06, .73, .92), Vector3(side * .28, .34, 0), b.TEAL, 0, .012)
		b._box(crate, Vector3(.92, .06, .06), Vector3(0, .34, side * .28), b.TEAL, 0, .012)
	for z in [27.45, 27.70, 27.95]:
		_ring(dock, Vector3(-1.85, .14, z), .30, .055, b.WOOD)
	var float_ring: Node3D = b._group(dock, "DockLifeRing", Vector3(-20.15, .92, 31.80))
	_ring(float_ring, Vector3.ZERO, .52, .12, b.SAKURA, Vector3(PI * .5, 0, 0))
	_ring(float_ring, Vector3.ZERO, .35, .035, b.WHITE, Vector3(PI * .5, 0, 0))
	Geo.rod(float_ring, Vector3(-.45, 0, 0), Vector3(.45, 0, 0), .035, b.WHITE)
	var marker: Node3D = b._group(dock, "DockShellMarker", Vector3(-14.4, .05, 29.55))
	b._box(marker, Vector3(.72, .10, .72), Vector3.ZERO, b.STONE, 0, .08)
	b._flower(marker, Vector3(0, .11, 0), b.SAKURA, .24)
	b._batch(dock)

func _garden_edge_details() -> void:
	var edge: Node3D = b._group(b.level, "GardenEdgeDetails")
	for side in [-1.0, 1.0]:
		var cluster: Node3D = b._group(edge, "ShellStoneCluster", Vector3(side * 29.8, .03, -18.4))
		for i in 5:
			var a: float = i * TAU / 5.0
			b._soft_ball(cluster, Vector3(cos(a) * (1.0 + .12 * i), .18 + .04 * (i % 2), sin(a) * (.62 + .10 * i)), Vector3(.34, .20, .28), b.STONE if i % 2 else b.LIGHT)
		if side < 0:
			b._flower(cluster, Vector3(.12, .38, .06), b.WHITE, .22)
		else:
			b._flower(cluster, Vector3(-.12, .38, -.06), b.SAKURA, .22)
		var pot: Node3D = b._group(edge, "EdgeLowPlanter", Vector3(side * 31.8, .04, -18.4))
		Geo.cylinder(pot, .30, .38, Vector3(0, .19, 0), b.MINT, .23)
		Geo.cylinder(pot, .22, .025, Vector3(0, .39, 0), Color("785c42"))
		for i in 4:
			var a: float = i * TAU / 4.0
			Geo.rod(pot, Vector3.ZERO, Vector3(cos(a) * .22, .68 + .05 * i, sin(a) * .22), .018, b.GREEN)
		b._flower(pot, Vector3(.10, .68, .04), b.SAKURA if side > 0 else b.WHITE, .19)
		b._batch(cluster)
		b._batch(pot)
