extends RefCounted
## Life-sized annex furnishings. Static pieces join the existing floor batches;
## only the baking tray, bouquet, book page and brush remain independent.
const Geo = preload("res://district/story_geometry.gd")
var b

func build(builder) -> void:
	b = builder
	_baking_corner()
	_flower_station()
	_lounge_console()
	_reading_corner()
	_artist_corner()
	_library_catalogue()
	_guest_storage()
	_rest_corner()
	_dressing_mirror()
	b.level.set_meta("interior_revision", "annex_daily_life_v1")

func _baking_corner() -> void:
	var oven: Node3D = b._action("bake", "star_oven", "花艺与烘焙工坊 · 星星烤箱", Vector3(25, 0, -22), 0)
	var body: Node3D = b._furniture(oven, "StarBakingOven", Vector3.ZERO)
	b._finish_box(body, Vector3(3.4, 1.65, 1.5), Vector3(0, .88, 0), "cabinet")
	b._finish_box(body, Vector3(3.6, .12, 1.68), Vector3(0, 1.77, 0), "cabinet", "top")
	b._box(body, Vector3(2.5, 1.0, .08), Vector3(0, .85, .79), b.TEAL)
	b._box(body, Vector3(2.12, .68, .035), Vector3(0, .85, .84), b.LIGHT)
	Geo.rod(body, Vector3(-.9, 1.45, .92), Vector3(.9, 1.45, .92), .045, b.GOLD)
	for x in [-1.1, 0.0, 1.1]:
		var knob := Geo.cylinder(body, .10, .08, Vector3(x, 1.62, .82), b.GOLD)
		knob.rotation.x = PI * .5
	b._coll(body, Vector3(3.6, 1.86, 1.68), Vector3(0, .93, 0))
	var tray: Node3D = b._group(oven, "WarmCookieTray", Vector3(0, 1.88, 0))
	tray.set_meta("home_dynamic", true)
	b._box(tray, Vector3(2.1, .07, 1.12), Vector3.ZERO, b.TEAL, 2, .04)
	for x in [-.65, 0.0, .65]:
		for z in [-.26, .26]:
			var cookie: Node3D = b._group(tray, "StarCookie", Vector3(x, .07, z))
			cookie.rotation.x = -PI * .5
			b._star(cookie, Vector3.ZERO, .30)
	oven.parts.append(tray)
	b._batch(tray, false)
	b._batch(oven)
	var shelf: Node3D = b._furniture(b.floors[0], "BakingHutchShelf", Vector3(24, 0, -23.05))
	b._finish_box(shelf, Vector3(4.7, .12, .48), Vector3(0, 2.45, 0), "ash_table", "top")
	for x in [-2.15, 2.15]:
		b._finish_box(shelf, Vector3(.13, 2.5, .16), Vector3(x, 1.25, 0), "ash_table")
		b._coll(shelf, Vector3(.13, 2.5, .16), Vector3(x, 1.25, 0))
	for i in 4:
		var x: float = -1.6 + i * .85
		Geo.cylinder(shelf, .20, .42, Vector3(x, 2.73, 0), b.WHITE if i % 2 else b.MINT)
		Geo.cylinder(shelf, .22, .065, Vector3(x, 2.97, 0), b.WOOD)
		b._box(shelf, Vector3(.22, .14, .02), Vector3(x, 2.73, .20), b.LIGHT)

func _flower_station() -> void:
	var flowers: Node3D = b._action("flowers", "flower_wrapping", "花艺与烘焙工坊 · 海风花束台", Vector3(24, 0, -9), 0)
	var table: Node3D = b._table(flowers, Vector3.ZERO, 4.2, 1.7, 1.05, "craft_table")
	# Wrapping paper, a ribbon reel and open scissors sit on the worktop.
	b._box(table, Vector3(1.7, .018, 1.10), Vector3(.65, 1.14, 0), b.WHITE, 0, .008)
	Geo.cylinder(table, .18, .11, Vector3(-1.55, 1.20, .35), b.SAKURA)
	for side in [-1.0, 1.0]:
		Geo.rod(table, Vector3(.6, 1.18, .3), Vector3(.6 + side * .22, 1.18, -.06), .018, b.TEAL)
	var bouquet: Node3D = b._group(flowers, "SeaBreezeBouquet", Vector3(.55, 1.19, -.10))
	bouquet.set_meta("home_dynamic", true)
	for i in 7:
		var angle: float = i * 2.4
		var end := Vector3(cos(angle) * .35, .35 + float(i % 3) * .12, sin(angle) * .25)
		Geo.rod(bouquet, Vector3(0, 0, 0), end, .018, b.GREEN)
		b._flower(bouquet, end, b.SAKURA if i % 2 else b.WHITE, .26)
	b._box(bouquet, Vector3(.16, .10, .20), Vector3(0, .12, 0), b.SAKURA)
	flowers.parts.append(bouquet)
	b._batch(bouquet, false)
	for x in [-1.45, -.65]: b._plant(table, Vector3(x, 1.15, -.35), .55, true)
	b._batch(flowers)
	var rack: Node3D = b._furniture(b.floors[0], "FloristPaperRack", Vector3(25, 0, -13))
	b._finish_box(rack, Vector3(2.5, .14, 1.0), Vector3(0, .15, 0), "craft_table")
	for i in 4:
		var height: float = 1.50 + float(i % 2) * .30
		Geo.cylinder(rack, .14, height, Vector3(-.9 + i * .6, .22 + height * .5, 0), b.WHITE if i % 2 else b.SAKURA)
	b._coll(rack, Vector3(2.6, 1.9, 1.05), Vector3(0, .95, 0))

func _lounge_console() -> void:
	var console: Node3D = b._cabinet(b.floors[0], Vector3(-22, 0, -14), 4.6, 1.0, "cream_cabinet")
	console.name = "SeaBreezeConsole"
	b._whale(console, Vector3(-1.25, 1.15, 0), .45)
	b._books(console, Vector3(.25, 1.15, .05), 6)
	b._fixture(console, Vector3(1.65, 1.15, -.1), false)

func _reading_corner() -> void:
	var h: float = b.HEIGHT
	var read: Node3D = b._action("read", "bay_journal", "海景阅读会客室 · 海湾手记", Vector3(-21, h, -11), h)
	var table: Node3D = b._table(read, Vector3.ZERO, 3.3, 1.8, .83, "tea_table")
	b._cup(table, Vector3(1.05, .95, .25), b.BLUE)
	b._fixture(table, Vector3(-1.15, .94, -.35), false)
	b._box(table, Vector3(1.35, .08, .95), Vector3(0, .96, .05), b.TEAL, 0, .015)
	for side in [-1.0, 1.0]:
		b._box(table, Vector3(.61, .045, .86), Vector3(side * .32, 1.025, .05), b.WHITE, 0, .006)
	var page: Node3D = b._group(read, "TurningJournalPage", Vector3(0, 1.07, .05))
	page.set_meta("home_dynamic", true)
	b._box(page, Vector3(.61, .016, .86), Vector3(.32, 0, 0), b.WHITE, 0, .003)
	for i in 5:
		b._box(page, Vector3(.39, .006, .012), Vector3(.32, .012, -.25 + i * .1), b.TEAL, 0, .001)
	read.parts.append(page)
	read.restore_pose()
	b._batch(page, false)
	b._batch(read)
	b._chair(b.floors[1], Vector3(-23.5, h, -9.4), -35)
	var ottoman: Node3D = b._furniture(b.floors[1], "ReadingFootstool", Vector3(-24, h, -13))
	var seat: MeshInstance3D = b._box(ottoman, Vector3(1.4, .55, 1.1), Vector3(0, .42, 0), b.SAKURA, 0, .12)
	b._cloth(seat, b.SAKURA, 1)
	b._coll(ottoman, Vector3(1.4, .7, 1.1), Vector3(0, .35, 0))

func _artist_corner() -> void:
	var h: float = b.HEIGHT
	var sketch: Node3D = b._action("sketch", "bay_easel", "双人创作书房 · 海湾画架", Vector3(24.5, h, -18), h)
	var easel: Node3D = b._furniture(sketch, "BaySketchEasel", Vector3.ZERO)
	for side in [-1.0, 1.0]:
		Geo.rod(easel, Vector3(side * .9, 0, .4), Vector3(side * .45, 2.9, -.20), .065, b.WOOD)
	Geo.rod(easel, Vector3(0, .04, -.75), Vector3(0, 2.8, -.2), .065, b.WOOD)
	b._finish_box(easel, Vector3(2.1, .12, .45), Vector3(0, 1.0, .18), "ash_table")
	b._box(easel, Vector3(1.8, 1.5, .09), Vector3(0, 1.85, 0), b.WOOD)
	b._box(easel, Vector3(1.64, 1.34, .04), Vector3(0, 1.85, .07), b.LIGHT)
	b._box(easel, Vector3(1.64, .42, .015), Vector3(0, 1.39, .1), b.MINT)
	b._sphere(easel, Vector3(.52, 2.25, .11), Vector3(.28, .28, .045), b.GOLD)
	b._whale(easel, Vector3(-.25, 1.65, .22), .35, 0)
	b._coll(easel, Vector3(2.1, 2.9, 1.25), Vector3(0, 1.45, -.1))
	var brush: Node3D = b._group(sketch, "PaintingBrush", Vector3(.62, 1.15, .33))
	brush.set_meta("home_dynamic", true)
	Geo.rod(brush, Vector3.ZERO, Vector3(.24, .42, 0), .022, b.TEAL)
	b._sphere(brush, Vector3(.26, .46, 0), Vector3(.09, .14, .08), b.SAKURA)
	sketch.parts.append(brush)
	b._batch(brush, false)
	b._batch(sketch)
	b._chair(b.floors[1], Vector3(26, h, -15.3), 180, true)

func _library_catalogue() -> void:
	var h: float = b.HEIGHT
	var chest: Node3D = b._cabinet(b.floors[1], Vector3(-6.5, h, -20), 4.2, 1.2, "bookcase")
	chest.name = "LibraryCatalogueDrawers"
	for x in [-1.35, 0.0, 1.35]:
		for y in [.35, .85]:
			b._box(chest, Vector3(1.17, .40, .05), Vector3(x, y, .55), b.WOOD)
			b._box(chest, Vector3(.28, .11, .025), Vector3(x, y + .04, .59), b.WHITE, 0, .005)
			Geo.rod(chest, Vector3(x - .12, y - .07, .64), Vector3(x + .12, y - .07, .64), .02, b.GOLD)
	b._books(chest, Vector3(-1.6, 1.32, 0), 8)
	b._whale(chest, Vector3(1.15, 1.34, 0), .4)

func _guest_storage() -> void:
	var h: float = b.HEIGHT * 2
	var wardrobe: Node3D = b._cabinet(b.floors[2], Vector3(-21, h, -20.5), 4.0, 2.9, "cream_cabinet")
	wardrobe.name = "GuestLinenWardrobe"
	b._box(wardrobe, Vector3(4.2, .14, 1.12), Vector3(0, 3.02, 0), b.MINT)
	b._star(wardrobe, Vector3(-.96, 2.25, .56), .35)
	b._whale(wardrobe, Vector3(.9, 1.6, .62), .32)
	var luggage: Node3D = b._furniture(b.floors[2], "GuestLuggageRack", Vector3(-22, h, -10))
	for side in [-1.0, 1.0]:
		Geo.rod(luggage, Vector3(side * .8, 0, -.45), Vector3(-side * .8, .75, .45), .04, b.WOOD)
	b._box(luggage, Vector3(2.0, .10, 1.15), Vector3(0, .75, 0), b.WOOD)
	b._box(luggage, Vector3(1.75, .75, 1.0), Vector3(0, 1.15, 0), b.BLUE, 0, .12)
	for x in [-.55, .55]: b._box(luggage, Vector3(.10, .78, 1.03), Vector3(x, 1.16, 0), b.WHITE)
	Geo.rod(luggage, Vector3(-.22, 1.63, 0), Vector3(.22, 1.63, 0), .04, b.GOLD)
	b._coll(luggage, Vector3(2.0, 1.6, 1.15), Vector3(0, .8, 0))

func _rest_corner() -> void:
	var h: float = b.HEIGHT * 2
	b._art(b.floors[2], Vector3(22, h + .055, -23), Vector2(6.5, 4.2), true)
	var cushions: Node3D = b._furniture(b.floors[2], "SeaViewFloorCushions", Vector3(22, h, -23))
	for side in [-1.0, 1.0]:
		var cushion: MeshInstance3D = b._box(cushions, Vector3(1.3, .26, 1.25), Vector3(side * 1.5, .20, 0), b.LIGHT if side < 0 else b.SAKURA, 0, .12)
		b._cloth(cushion, b.LIGHT if side < 0 else b.SAKURA, 1)
		b._coll(cushions, Vector3(1.3, .40, 1.25), Vector3(side * 1.5, .20, 0))
	var table: Node3D = b._table(b.floors[2], Vector3(22, h, -25.2), 2.8, 1.2, .48, "tea_table")
	b._cup(table, Vector3(-.8, .60, 0), b.BLUE)
	b._books(table, Vector3(.15, .59, 0), 4)
	b._plant(b.floors[2], Vector3(25.5, h, -21), 1.2, true)

func _dressing_mirror() -> void:
	var h: float = b.HEIGHT * 2
	var mirror: Node3D = b._furniture(b.floors[2], "MorningVanityMirror", Vector3(0, h + 2.55, -37.5))
	b._box(mirror, Vector3(2.8, 2.3, .15), Vector3.ZERO, b.WOOD, 1, .07)
	b._box(mirror, Vector3(2.48, 1.98, .06), Vector3(0, 0, .11), b.LIGHT, 0, .05)
	# Soft highlights suggest glass without adding a second reflection camera.
	for side in [-1.0, 1.0]:
		for i in 4: b._sphere(mirror, Vector3(side * 1.27, -.73 + i * .48, .20), Vector3.ONE * .12, b.WHITE)
	var stool: Node3D = b._furniture(b.floors[2], "MorningVanityStool", Vector3(0, h, -33.2))
	for x in [-.4, .4]:
		for z in [-.3, .3]: Geo.rod(stool, Vector3(x, 0, z), Vector3(x * .85, .65, z * .85), .035, b.WOOD)
	var seat: MeshInstance3D = b._box(stool, Vector3(1.2, .22, .95), Vector3(0, .70, 0), b.SAKURA, 0, .10)
	b._cloth(seat, b.SAKURA)
	b._coll(stool, Vector3(1.2, .85, .95), Vector3(0, .425, 0))
