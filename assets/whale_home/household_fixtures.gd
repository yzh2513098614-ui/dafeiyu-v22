extends RefCounted
## Hollow sanitary ware and a board-built fridge. All parts use existing finishes.
const Geo = preload("res://district/story_geometry.gd")
const Lounge = preload("res://assets/whale_home/lounge_furniture.gd")

static func kitchen_sink(b, cabinet: Node3D) -> void:
	var sink: Node3D = b._group(cabinet, "DeepKitchenSink", Vector3(0, 1.15, 0))
	_basin(sink, Vector2(1.35, .72), Vector2(1.12, .50), .20, .14, b.WHITE)
	_drain(b, sink, Vector3(0, .038, 0), .055)
	_faucet(b, sink, Vector3(.43, .20, -.27), .42, .30, .028, Vector3(-.8, 0, .6))
	for x in [-.45, -.31]:
		b._box(sink, Vector3(.085, .025, .08), Vector3(x, .2125, -.30), b.MINT, 0, .012)
	sink.set_meta("fixture_model", "hollow_kitchen_sink_v1")

static func cooker(b, cabinet: Node3D) -> void:
	# The fitted oven replaces the cabinet fronts beneath the hob.
	for child: Node in cabinet.get_children():
		if child.get_meta("cabinet_front", false):
			cabinet.remove_child(child); child.queue_free()
	var cooker_root: Node3D = b._group(cabinet, "FourBurnerCooker")
	b._box(cooker_root, Vector3(1.40, .055, .77), Vector3(0, 1.18, 0), b.DEEP, 2, .025)
	for x in [-.36, .36]:
		for z in [-.18, .18]:
			Geo.cylinder(cooker_root, .125, .025, Vector3(x, 1.22, z), b.TEAL)
			Geo.cylinder(cooker_root, .087, .018, Vector3(x, 1.24, z), b.DEEP)
			for axis in [Vector3.RIGHT, Vector3.BACK]:
				var center := Vector3(x, 1.27, z)
				Geo.rod(cooker_root, center-axis*.155, center+axis*.155, .017, b.WOOD.darkened(.30))
	b._box(cooker_root, Vector3(1.40, .66, .075), Vector3(0, .65, .585), b.TEAL, 0, .035)
	b._box(cooker_root, Vector3(1.16, .42, .025), Vector3(0, .61, .636), b.DEEP, 2, .025)
	b._box(cooker_root, Vector3(.91, .017, .012), Vector3(0, .72, .655), b.LIGHT, 0, .004)
	for i in 7:
		b._box(cooker_root, Vector3(.085, .018, .012), Vector3(-.36+i*.12, .38, .63), b.WOOD.darkened(.20), 0, .003)
	b._box(cooker_root, Vector3(1.40, .11, .06), Vector3(0, 1.025, .56), b.WHITE, 0, .014)
	for x in [-.47, -.16, .16, .47]:
		var knob: MeshInstance3D = Geo.cylinder(cooker_root, .047, .035, Vector3(x, 1.02, .61), b.WHITE)
		knob.rotation.x = PI*.5
		b._box(cooker_root, Vector3(.010, .028, .010), Vector3(x, 1.032, .634), b.GOLD, 0, .002)
	for x in [-.48, .48]:
		Geo.rod(cooker_root, Vector3(x, .91, .63), Vector3(x, .91, .69), .022, b.GOLD)
	Geo.rod(cooker_root, Vector3(-.50, .91, .69), Vector3(.50, .91, .69), .026, b.GOLD)
	cooker_root.set_meta("fixture_model", "grated_hob_and_fitted_oven_v1")

static func shelf_brackets(b, shelf: Node3D) -> void:
	for x in [-1.10, 1.10]:
		b._finish_box(shelf, Vector3(.07, .35, .07), Vector3(x, -.22, -.29), "display_shelf", "body", .012)
		b._finish_box(shelf, Vector3(.07, .065, .52), Vector3(x, -.10, -.065), "display_shelf", "body", .012)
		Geo.rod(shelf, Vector3(x, -.36, -.29), Vector3(x, -.10, .15), .022, b.WOOD)

static func fridge(b, action: Node3D) -> void:
	var carcass: Node3D = b._group(action, "InsulatedFridgeCarcass")
	b._box(carcass, Vector3(2.1, 3.1, .12), Vector3(0, 1.55, -.69), b.BLUE, 0, .07)
	for side in [-1.0, 1.0]:
		b._box(carcass, Vector3(.16, 3.1, 1.42), Vector3(side*.97, 1.55, .02), b.BLUE, 0, .06)
		b._box(carcass, Vector3(.025, 2.84, 1.25), Vector3(side*.878, 1.55, .025), b.WHITE, 0, .012)
	for y in [.07, 3.03]:
		b._box(carcass, Vector3(1.82, .14, 1.42), Vector3(0, y, .02), b.BLUE, 0, .045)
	b._box(carcass, Vector3(1.76, 2.82, .035), Vector3(0, 1.55, -.61), b.WHITE, 0, .018)
	b._box(carcass, Vector3(1.78, .11, 1.27), Vector3(0, 1.915, .025), b.WHITE, 0, .015)
	for y in [.32, .95, 2.05, 2.56]:
		b._box(carcass, Vector3(1.72, .045, 1.15), Vector3(0, y, -.02), b.LIGHT, 0, .012)
		b._box(carcass, Vector3(1.74, .065, .05), Vector3(0, y, .55), b.WHITE, 0, .008)
		for i in 3:
			_bottle(b, carcass, Vector3(-.51+i*.51, y+.025, .15), .30, b.MINT if i%2 else b.WHITE)
	for i in 8:
		b._box(carcass, Vector3(.09, .025, .025), Vector3(-.52+i*.15, .19, .744), b.TEAL, 0, .004)
	b._batch(carcass, false)
	for spec in [[.96, 1.8], [2.52, 1.10]]:
		var height: float = spec[1]
		var pivot: Node3D = b._group(action, "FridgeDoorPivot", Vector3(-1.02, float(spec[0]), .78))
		pivot.set_meta("home_dynamic", true); action.parts.append(pivot)
		b._box(pivot, Vector3(2.04, height, .14), Vector3(1.02, 0, 0), b.LIGHT, 0, .08)
		b._box(pivot, Vector3(1.80, height-.20, .035), Vector3(1.02, 0, -.086), b.WHITE, 0, .018)
		for side in [-1.0, 1.0]:
			b._box(pivot, Vector3(1.83, .035, .025), Vector3(1.02, side*(height*.5-.085), -.115), b.MINT, 0, .006)
			b._box(pivot, Vector3(.035, height-.17, .025), Vector3(1.02+side*.90, 0, -.115), b.MINT, 0, .006)
			Geo.cylinder(pivot, .045, .15, Vector3(0, side*height*.30, -.02), b.GOLD)
			Geo.rod(pivot, Vector3(1.83, side*.27, .07), Vector3(1.83, side*.27, .15), .024, b.GOLD)
		Geo.rod(pivot, Vector3(1.83, -.29, .15), Vector3(1.83, .29, .15), .031, b.GOLD)
		var bins: Array = [-.46, .24] if height>1.5 else [-.24]
		for y: float in bins:
			b._box(pivot, Vector3(1.58, .035, .30), Vector3(1.02, y, -.24), b.WHITE, 0, .012)
			b._box(pivot, Vector3(1.58, .12, .035), Vector3(1.02, y+.075, -.385), b.LIGHT, 0, .012)
			for x in [.26, 1.78]:
				b._box(pivot, Vector3(.035, .12, .30), Vector3(x, y+.075, -.24), b.WHITE, 0, .009)
		b._whale(pivot, Vector3(.70, -.1, .08), .19, 0, b.DEEP)
		b._batch(pivot, false)
	action.set_meta("fixture_model", "hollow_fridge_and_sealed_hinged_doors_v1")

static func bath(b, root: Node3D) -> void:
	for x in [-1.03, 1.03]:
		for z in [-.48, .48]:
			Geo.cylinder(root, .07, .26, Vector3(x, .22, z), b.GOLD)
			b._sphere(root, Vector3(x, .085, z), Vector3(.23, .13, .21), b.GOLD)
	var shell: Node3D = b._group(root, "HollowBathShell", Vector3(0, .27, 0))
	_basin(shell, Vector2(3.40, 1.72), Vector2(2.94, 1.26), .99, .70, b.WHITE)
	_drain(b, shell, Vector3(.72, .165, 0), .075)
	var water := MeshInstance3D.new()
	water.name = "BathWaterSurface"
	water.mesh = _flat_surface(Vector2(2.77, 1.14), .52, 1.03)
	water.material_override = Geo.material(Color("87cbdc"), 2)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	_faucet(b, root, Vector3(1.47, .18, -.15), 1.20, .34, .038)
	for z in [-.40, .13]:
		Geo.cylinder(root, .065, .12, Vector3(1.47, 1.18, z), b.GOLD)
		b._box(root, Vector3(.15, .032, .045), Vector3(1.47, 1.255, z), b.WHITE, 0, .012)
	var caddy: Node3D = b._group(root, "SlattedBathCaddy", Vector3(.55, 1.30, 0))
	for x in [-.20, 0.0, .20]:
		b._finish_box(caddy, Vector3(.18, .055, 1.48), Vector3(x, 0, 0), "ash_table", "top", .018)
	for z in [-.66, .66]:
		b._finish_box(caddy, Vector3(.65, .055, .08), Vector3(0, -.045, z), "ash_table", "body", .012)
	b._box(caddy, Vector3(.34, .035, .24), Vector3(0, .04, -.30), b.WHITE, 0, .025)
	b._box(caddy, Vector3(.24, .07, .15), Vector3(0, .09, -.30), b.SAKURA, 0, .025)
	_bottle(b, caddy, Vector3(0, .03, .30), .22, b.MINT)
	b._whale(root, Vector3(-.55, 1.06, .10), .18)
	root.set_meta("fixture_model", "hollow_footed_bath_and_slatted_caddy_v1")

static func vanity_sink(b, cabinet: Node3D) -> void:
	var sink: Node3D = b._group(cabinet, "CeramicVanityBasin", Vector3(0, 1.12, 0))
	_basin(sink, Vector2(1.10, .72), Vector2(.88, .50), .22, .25, b.WHITE)
	_drain(b, sink, Vector3(0, .042, .03), .045)
	_faucet(b, sink, Vector3(.34, .19, -.27), .38, .27, .024, Vector3(-.8, 0, .6))
	var dish: Node3D = b._group(cabinet, "SoapDish", Vector3(-.78, 1.16, .12))
	b._box(dish, Vector3(.32, .035, .23), Vector3.ZERO, b.MINT, 0, .025)
	b._box(dish, Vector3(.23, .07, .15), Vector3(0, .048, 0), b.WHITE, 0, .025)
	for x in [.68, .88]:
		_bottle(b, cabinet, Vector3(x, 1.13, -.12), .27, b.BLUE if x<.8 else b.WHITE)
	for x in [-.46, .46]:
		Geo.rod(cabinet, Vector3(x, .85, .50), Vector3(x, .85, .59), .022, b.GOLD)
	Geo.rod(cabinet, Vector3(-.49, .85, .59), Vector3(.49, .85, .59), .026, b.GOLD)
	var towel: MeshInstance3D = b._box(cabinet, Vector3(.48, .39, .035), Vector3(0, .67, .61), b.LIGHT, 0, .012)
	b._cloth(towel, b.LIGHT, 1)
	sink.set_meta("fixture_model", "hollow_vanity_basin_and_towel_rail_v1")

static func _bottle(b, parent: Node3D, point: Vector3, height: float, color: Color) -> void:
	var bottle: Node3D = b._group(parent, "CappedBottle", point)
	Geo.cylinder(bottle, height*.28, height*.72, Vector3(0, height*.36, 0), color, height*.24)
	Geo.cylinder(bottle, height*.13, height*.17, Vector3(0, height*.805, 0), color)
	Geo.cylinder(bottle, height*.16, height*.12, Vector3(0, height*.94, 0), b.GOLD)
	b._box(bottle, Vector3(height*.33, height*.24, .015), Vector3(0, height*.38, height*.268), b.LIGHT if color==b.WHITE else b.WHITE, 0, .005)

static func _faucet(b, parent: Node3D, base: Vector3, height: float, reach: float, radius: float, direction: Vector3=Vector3.LEFT) -> void:
	Geo.cylinder(parent, radius*1.8, radius, base, b.GOLD)
	var rise: float = height-reach*.5
	Geo.rod(parent, base, base+Vector3(0, rise, 0), radius, b.GOLD)
	var previous: Vector3 = base+Vector3(0, rise, 0)
	for i in range(1, 13):
		var angle: float = PI-float(i)*PI/12.0
		var next: Vector3 = base+direction*((1.0+cos(angle))*reach*.5)+Vector3.UP*(rise+sin(angle)*reach*.5)
		Geo.rod(parent, previous, next, radius, b.GOLD)
		previous = next
	Geo.rod(parent, previous, previous-Vector3.UP*radius*1.5, radius*1.12, b.WHITE)
	Geo.cylinder(parent, radius*1.6, radius*2.0, base+Vector3(.11, radius*.7, 0), b.GOLD)
	b._box(parent, Vector3(.14, radius*.8, radius*1.5), base+Vector3(.15, radius*2.0, 0), b.WHITE, 0, .009)

static func _drain(b, parent: Node3D, point: Vector3, radius: float) -> void:
	Geo.cylinder(parent, radius, .010, point, b.GOLD)
	Geo.cylinder(parent, radius*.74, .009, point+Vector3.UP*.006, b.TEAL)
	for i in 3:
		b._box(parent, Vector3(radius*1.10, .006, .008), point+Vector3(0, .013, (i-1)*radius*.32), b.GOLD, 0, .001)

static func _basin(parent: Node3D, outside: Vector2, inside: Vector2, height: float, radius: float, color: Color) -> void:
	var inner_radius: float = minf(radius*.80, inside.y*.48)
	var rings: Array = [
		Lounge._rim(outside*.76, radius*.70, 0),
		Lounge._rim(outside*.94, radius*.92, height*.32),
		Lounge._rim(outside, radius, height-.035),
		Lounge._rim(outside*.995, radius*.995, height),
		Lounge._rim(inside, inner_radius, height-.015),
		Lounge._rim(inside*.96, inner_radius*.96, height*.78),
		Lounge._rim(inside*.68, inner_radius*.68, height*.16)]
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in range(rings.size()-1):
		for i in rings[band].size():
			var next: int = (i+1)%rings[band].size()
			var a: Vector3 = rings[band][i]
			var c: Vector3 = rings[band][next]
			var d: Vector3 = rings[band+1][next]
			var normal: Vector3 = (c-a).cross(d-a).normalized()
			var middle: Vector3 = (a+c+d+rings[band+1][i])*.25
			var target: Vector3 = Vector3(middle.x, 0, middle.z) if band<3 else (Vector3.UP if band==3 else Vector3(-middle.x, 0, -middle.z))
			if normal.dot(target)<0: normal = -normal
			Geo._face(tool, [a, c, d, rings[band+1][i]], normal)
	for i in rings[0].size():
		var next: int = (i+1)%rings[0].size()
		Geo._face(tool, [Vector3.ZERO, rings[0][i], rings[0][next]], Vector3.DOWN)
		Geo._face(tool, [Vector3(0, height*.16, 0), rings[6][i], rings[6][next]], Vector3.UP)
	var mesh := MeshInstance3D.new(); mesh.name = "ContinuousBasinShell"
	mesh.mesh = tool.commit(); mesh.material_override = Geo.material(color)
	parent.add_child(mesh)
	parent.set_meta("basin_inner_depth", height*.84-.015)

static func _flat_surface(size: Vector2, radius: float, y: float) -> ArrayMesh:
	var ring: Array[Vector3] = Lounge._rim(size, radius, y)
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in ring.size():
		Geo._face(tool, [Vector3(0, y, 0), ring[i], ring[(i+1)%ring.size()]], Vector3.UP)
	return tool.commit()
