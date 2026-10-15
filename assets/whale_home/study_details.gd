extends RefCounted
## Desk equipment, a framed tea trolley and the existing journal's moving leaf.
const Geo = preload("res://district/story_geometry.gd")

static func computer(b, desk: Node3D) -> void:
	var monitor: Node3D = b._group(desk, "WhaleComputer", Vector3(-.14, 1.13, -.10))
	b._box(monitor, Vector3(.68, .045, .42), Vector3(0, .02, 0), b.WHITE, 0, .025)
	b._box(monitor, Vector3(.075, .39, .08), Vector3(0, .23, -.15), b.GOLD, 2, .012)
	var display: Node3D = b._group(monitor, "TiltedDisplay", Vector3(0, .75, -.09))
	display.rotation.x = -.08
	b._box(display, Vector3(1.42, .92, .10), Vector3.ZERO, b.BLUE, 0, .05)
	b._art(display, Vector3(0, 0, .015), Vector2(1.20, .68))
	b._box(display, Vector3(.30, .25, .065), Vector3(0, -.20, -.075), b.WHITE, 0, .018)
	Geo.rod(display, Vector3(-.15, -.26, -.10), Vector3(.15, -.26, -.10), .038, b.GOLD)
	for i in 9:
		b._box(display, Vector3(.065, .012, .010), Vector3(-.36+i*.09, .28, -.055), b.TEAL, 0, .002)
	b._sphere(display, Vector3(.57, -.40, .058), Vector3(.034, .018, .012), b.MINT)
	_cable(monitor, [Vector3(0,.58,-.15), Vector3(.10,.40,-.22), Vector3(.16,.15,-.25), Vector3(.20,.03,-.40)], b.TEAL)
	var keyboard: Node3D = b._group(desk, "FourRowKeyboard", Vector3(-.12, 1.15, .49))
	b._box(keyboard, Vector3(1.04, .042, .36), Vector3.ZERO, b.WHITE, 0, .020)
	for row in 3:
		for column in 12:
			b._box(keyboard, Vector3(.061, .012, .057), Vector3(-.44+column*.080, .027, -.11+row*.078), b.LIGHT if column<11 else b.MINT, 0, .004)
	b._box(keyboard, Vector3(.34, .012, .055), Vector3(0, .027, .125), b.LIGHT, 0, .005)
	for x in [-.43, -.34, .34, .43]:
		b._box(keyboard, Vector3(.061, .012, .055), Vector3(x, .027, .125), b.MINT, 0, .004)
	_cable(desk, [Vector3(.34,1.16,.33), Vector3(.46,1.137,.20), Vector3(.48,1.137,-.30), Vector3(.34,1.137,-.62)], b.TEAL)
	var mouse: Node3D = b._group(desk, "MouseAndDeskMat", Vector3(.88, 1.136, .43))
	b._box(mouse, Vector3(.62, .012, .48), Vector3.ZERO, b.MINT, 0, .035)
	b._sphere(mouse, Vector3(0, .052, .03), Vector3(.16, .075, .24), b.WHITE)
	b._box(mouse, Vector3(.008, .007, .07), Vector3(0, .089, .005), b.TEAL, 0, .002)
	var wheel: MeshInstance3D = Geo.cylinder(mouse, .012, .025, Vector3(0, .093, -.025), b.GOLD)
	wheel.rotation.z = PI*.5
	_cable(mouse, [Vector3(0,.05,-.075), Vector3(.04,.015,-.15), Vector3(.12,.012,-.28), Vector3(.02,.012,-.47)], b.TEAL)
	var notebook: Node3D = b._group(desk, "DeskNotebook", Vector3(-1.05, 1.13, .02))
	notebook.rotation.y = -.12
	_closed_book(b, notebook, Vector2(.62, .43), b.MINT)
	b._box(notebook, Vector3(.030, .010, .35), Vector3(.18, .091, .04), b.GOLD, 0, .003)
	var pencils: Node3D = b._group(desk, "DeskPencilCup", Vector3(-1.36, 1.13, -.25))
	Geo.cylinder(pencils, .10, .19, Vector3(0,.095,0), b.LIGHT, .115)
	Geo.cylinder(pencils, .088, .008, Vector3(0,.194,0), b.TEAL)
	for i in 5:
		var start := Vector3(cos(i*2.4)*.045, .10, sin(i*2.4)*.045)
		var end: Vector3 = start+Vector3((i-2)*.025, .25+float(i%3)*.035, -.025)
		Geo.rod(pencils, start, end, .011, b.BLUE if i%2 else b.WOOD)
		Geo.rod(pencils, end, end+Vector3.UP*.025, .007, b.TEAL)
	desk.set_meta("study_detail", "computer_keyboard_mouse_and_stationery_v1")

static func tea_trolley(b, cart: Node3D) -> void:
	for x in [-.53, .53]:
		for z in [-.25, .25]:
			Geo.rod(cart, Vector3(x,.18,z), Vector3(x,1.02,z), .027, b.GOLD)
			var caster: Node3D = b._group(cart, "ForkedCaster", Vector3(x,.10,z))
			var wheel: MeshInstance3D = Geo.cylinder(caster, .085, .065, Vector3.ZERO, b.TEAL)
			wheel.rotation.z = PI*.5
			var hub: MeshInstance3D = Geo.cylinder(caster, .033, .082, Vector3.ZERO, b.GOLD)
			hub.rotation.z = PI*.5
			for side in [-1.0, 1.0]:
				b._box(caster, Vector3(.022, .11, .045), Vector3(side*.045,.045,0), b.GOLD, 0, .006)
	for y in [.24, .80]:
		b._finish_box(cart, Vector3(1.26,.055,.77), Vector3(0,y,0), "ash_table", "top", .022)
		for x in [-.60, .60]:
			b._finish_box(cart, Vector3(.045,.065,.75), Vector3(x,y+.055,0), "ash_table", "body", .012)
		for z in [-.35, .35]:
			b._finish_box(cart, Vector3(1.19,.065,.045), Vector3(0,y+.055,z), "ash_table", "body", .012)
	for x in [-.53, .53]:
		Geo.rod(cart, Vector3(x,1.02,-.25), Vector3(x,1.02,.25), .028, b.GOLD)
	Geo.rod(cart, Vector3(-.53,1.02,.25), Vector3(.53,1.02,.25), .030, b.WOOD)
	for x in [-.35, .35]: b._cup(cart, Vector3(x,.84,-.14), b.BLUE)
	var pot: Node3D = b._group(cart, "SmallTrolleyTeapot", Vector3(0,.84,.07))
	b._sphere(pot, Vector3(0,.11,0), Vector3(.30,.22,.27), b.WHITE)
	Geo.cylinder(pot, .075, .025, Vector3(0,.225,0), b.GOLD)
	b._sphere(pot, Vector3(0,.25,0), Vector3.ONE*.052, b.GOLD)
	Geo.rod(pot, Vector3(.12,.10,0), Vector3(.23,.19,0), .035, b.WHITE)
	var handle := MeshInstance3D.new(); var ring := TorusMesh.new()
	ring.inner_radius=.055; ring.outer_radius=.078; ring.rings=16; ring.ring_segments=8
	handle.mesh=ring; handle.material_override=Geo.material(b.WHITE); handle.rotation.x=PI*.5
	handle.position=Vector3(-.15,.12,0); pot.add_child(handle)
	for i in 2:
		var book: Node3D = b._group(cart, "LowerTrayJournal", Vector3(-.16,.28+i*.10,0))
		book.rotation.y = .09 if i else -.06
		_closed_book(b, book, Vector2(.70,.43), b.LIGHT if i else b.SAKURA)
	var basket: Node3D = b._group(cart, "TeaNapkinBasket", Vector3(.43,.28,0))
	b._box(basket, Vector3(.27,.035,.48), Vector3(0,.02,0), b.WOOD, 0, .012)
	for x in [-.12, .12]:
		b._box(basket, Vector3(.025,.20,.48), Vector3(x,.12,0), b.WOOD, 0, .009)
	for z in [-.23, .23]:
		for row in 3:
			b._box(basket, Vector3(.27,.035,.025), Vector3(0,.05+row*.065,z), b.WHITE, 0, .005)
	for i in 3:
		var napkin: MeshInstance3D = b._box(basket, Vector3(.20,.035,.36), Vector3(0,.06+i*.04,0), b.WHITE, 0, .012)
		b._cloth(napkin, b.LIGHT if i%2 else b.WHITE, 1)
	cart.set_meta("study_detail", "rimmed_trays_forked_castors_and_tea_service_v1")

static func journal(b, action: Node3D, table: Node3D) -> Node3D:
	var book: Node3D = b._group(table, "LayeredOpenJournal", Vector3(0,.935,.05))
	b._box(book, Vector3(1.39,.040,.99), Vector3(0,-.015,0), b.TEAL, 0, .012)
	for side in [-1.0, 1.0]:
		b._box(book, Vector3(.61,.075,.86), Vector3(side*.32,.050,0), b.WHITE, 0, .008)
		for layer in 3:
			b._box(book, Vector3(.59,.005,.012), Vector3(side*.32,.027+layer*.022,.435), b.LIGHT, 0, .001)
		for line in 5:
			b._box(book, Vector3(.39 if line<4 else .27,.005,.012), Vector3(side*.32,.091,-.25+line*.10), b.TEAL, 0, .001)
	Geo.rod(book, Vector3(0,.075,-.44), Vector3(0,.075,.44), .013, b.TEAL)
	b._box(book, Vector3(.045,.012,.63), Vector3(-.10,.094,.19), b.SAKURA, 0, .003)
	b._box(book, Vector3(.07,.010,.08), Vector3(-.10,.09,.51), b.SAKURA, 0, .003)
	var page: Node3D = b._group(action, "TurningJournalPage", Vector3(0,1.07,.05))
	page.set_meta("home_dynamic", true)
	var leaf := MeshInstance3D.new(); leaf.mesh = _curved_page(); leaf.material_override = Geo.material(b.WHITE)
	page.add_child(leaf)
	for face in [-1.0, 1.0]:
		for line in 5:
			for part in 6:
				var x: float = .13+part*.062
				var stroke: MeshInstance3D = b._box(page, Vector3(.059,.003,.012), Vector3(x,_page_height(x/.61)+face*.006,-.25+line*.10), b.TEAL, 0, .001)
				stroke.rotation.z = atan((PI*.018*cos(x/.61*PI)+.048*pow(x/.61,3))/.61)
	action.set_meta("study_detail", "layered_journal_with_curved_turning_leaf_v1")
	return page

static func _page_height(u: float) -> float:
	return sin(u*PI)*.018+pow(u,4)*.012

static func _curved_page() -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 16:
		var x: float = i*.61/16.0
		var next_x: float = (i+1)*.61/16.0
		var y: float = _page_height(float(i)/16.0)
		var next_y: float = _page_height(float(i+1)/16.0)
		for face in [-1.0, 1.0]:
			var normal: Vector3 = Vector3(-(next_y-y)/(next_x-x),1,0).normalized()*face
			Geo._face(tool, [Vector3(x,y+face*.005,-.43),Vector3(next_x,next_y+face*.005,-.43),Vector3(next_x,next_y+face*.005,.43),Vector3(x,y+face*.005,.43)],normal)
			Geo._face(tool, [Vector3(x,y-.005,face*.43),Vector3(next_x,next_y-.005,face*.43),Vector3(next_x,next_y+.005,face*.43),Vector3(x,y+.005,face*.43)],Vector3.BACK*face)
	for end in [0.0, 1.0]:
		var x: float = end*.61; var y: float = _page_height(end)
		Geo._face(tool, [Vector3(x,y-.005,-.43),Vector3(x,y-.005,.43),Vector3(x,y+.005,.43),Vector3(x,y+.005,-.43)],Vector3.RIGHT*(end*2-1))
	return tool.commit()

static func _closed_book(b, parent: Node3D, size: Vector2, color: Color) -> void:
	for y in [.012, .078]:
		b._box(parent, Vector3(size.x,.022,size.y), Vector3(0,y,0), color, 0, .009)
	b._box(parent, Vector3(size.x-.045,.045,size.y-.035), Vector3(0,.045,0), b.WHITE, 0, .005)
	b._box(parent, Vector3(.035,.08,size.y), Vector3(-size.x*.5+.015,.045,0), color, 0, .008)
	for y in [.035, .055]:
		b._box(parent, Vector3(size.x-.06,.004,.006), Vector3(0,y,size.y*.5-.015), b.LIGHT, 0, .001)

static func _cable(parent: Node3D, points: Array[Vector3], color: Color) -> void:
	for i in range(points.size()-1): Geo.rod(parent, points[i], points[i+1], .007, color)
