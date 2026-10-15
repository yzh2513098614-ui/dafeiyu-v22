extends RefCounted
const Geo = preload("res://district/story_geometry.gd")
const Soft = preload("res://assets/whale_home/beds.gd")
const Finishes = preload("res://assets/whale_home/furniture_finishes.gd")

static func chair(b, root: Node3D, stool: bool) -> void:
	root.set_meta("chair_model_revision", "curved_back_piped_seat_v2")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Geo.rod(root, Vector3(x*.30,.04,z*.29), Vector3(x*.25,.60,z*.23), .035, b.WOOD)
		Geo.rod(root, Vector3(x*.275,.31,-.26), Vector3(x*.275,.31,.26), .025, b.WOOD)
		Geo.rod(root, Vector3(-.275,.31,x*.26), Vector3(.275,.31,x*.26), .025, b.WOOD)
	var seat := MeshInstance3D.new(); seat.mesh = _table_top(Vector2(.82,.76)); seat.position.y = .59
	seat.material_override = Finishes.material("ash_table","top"); root.add_child(seat)
	Soft._puff(b, root, Vector3(0,.70,0), Vector3(.80,.17,.74), b.LIGHT, true)
	if stool: return
	for side in [-1.0, 1.0]:
		Geo.rod(root, Vector3(side*.30,.59,-.25), Vector3(side*.30,1.27,-.28), .032, b.WOOD)
		b._sphere(root, Vector3(side*.30,.90,-.215), Vector3.ONE*.045, b.GOLD)
	var back := MeshInstance3D.new(); back.mesh = _curved_back(.79,.54,.055); back.position = Vector3(0,1.06,-.34)
	back.material_override = Finishes.material("ash_table","body"); root.add_child(back)
	var pad := MeshInstance3D.new(); pad.mesh = _curved_back(.68,.40,.07); pad.position = Vector3(0,1.06,-.285)
	b._cloth(pad,b.BLUE); root.add_child(pad)
	b._star(root, Vector3(0,1.08,-.235), .17)

static func _curved_back(width: float, height: float, thickness: float) -> ArrayMesh:
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [-1.0, 1.0]:
		for i in 20:
			var points: Array[Vector3] = []
			for corner in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,1)]:
				var u: float = ((i+corner.x)/20.0)*2.0-1.0
				points.append(Vector3(u*width*.5,corner.y*(height*.5-.06*pow(absf(u),6)),.08*u*u+face*thickness*.5))
			Geo._face(tool,points,Vector3.BACK*face)
	for edge in [-1.0, 1.0]:
		for i in 20:
			var points: Array[Vector3] = []
			for corner in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,1)]:
				var u: float = ((i+corner.x)/20.0)*2.0-1.0
				points.append(Vector3(u*width*.5,edge*(height*.5-.06*pow(absf(u),6)),.08*u*u+corner.y*thickness*.5))
			Geo._face(tool,points,Vector3.UP*edge)
		var y: float = height*.5-.06
		Geo._face(tool,[Vector3(edge*width*.5,-y,.08-thickness*.5),Vector3(edge*width*.5,y,.08-thickness*.5),Vector3(edge*width*.5,y,.08+thickness*.5),Vector3(edge*width*.5,-y,.08+thickness*.5)],Vector3.RIGHT*edge)
	tool.index(); tool.generate_normals(); return tool.commit()

static func bookcase(b, root: Node3D, width: float, height: float, profile: String) -> void:
	root.set_meta("bookcase_model_revision", "grouped_library_shelves_v2")
	var frame: Node3D = b._group(root,"FramedBookcase")
	b._finish_box(frame,Vector3(width,height,.09),Vector3(0,height*.5,-.43),profile,"back",.02)
	for x in [-width*.5+.055,0.0,width*.5-.055]:
		b._finish_box(frame,Vector3(.11,height,.94),Vector3(x,height*.5,0),profile,"body",.02)
	b._finish_box(frame,Vector3(width+.10,.17,1.0),Vector3(0,.085,0),profile,"body",.025)
	b._finish_box(frame,Vector3(width+.10,.13,1.0),Vector3(0,height-.065,0),profile,"top",.025)
	var spacing: float = (height-.30)/3.0
	var bay_width: float = width*.5-.22
	for row in 3:
		var y: float = .16+row*spacing
		b._finish_box(frame,Vector3(width+.08,.08,1.0),Vector3(0,y,0),profile,"top",.015)
		b._finish_box(frame,Vector3(width+.08,.055,.09),Vector3(0,y-.005,.45),profile,"body",.012)
		var books: Node3D = b._group(root,"GroupedShelfBooks",Vector3(-width*.5+.17,y+.05,.02))
		var count: int = clampi(floori(bay_width/.145),3,12)
		var max_height: float = minf(.57,spacing-.13)
		_book_group(b,books,count,max_height,row)
		for x in [-.045,count*.145]:
			b._box(books,Vector3(.035,max_height*.55,.40),Vector3(x,max_height*.275,0),b.MINT,0,.006)
			b._box(books,Vector3(.12,.025,.40),Vector3(x+(.05 if x<0 else -.05),.0125,0),b.MINT,0,.004)
		var right: Node3D = b._group(root,"ShelfDisplayBay",Vector3(width*.25,y+.05,0))
		if row==0:
			for i in 3:
				b._box(right,Vector3(minf(.72,bay_width*.82),.065,.44),Vector3(0,.035+i*.07,0),b.LIGHT if i%2 else b.SAKURA,0,.009)
		elif row==1:
			b._whale(right,Vector3.ZERO,minf(.30,bay_width*.28),12)
		else:
			b._cup(right,Vector3(-bay_width*.18 if bay_width>1.0 else 0.0,0,.05),b.BLUE)
			if bay_width>1.0:b._cup(right,Vector3(bay_width*.18,0,.05),b.WHITE)
	b._plant(root,Vector3(-width*.32,height+.03,0),.55,true)

static func _book_group(b, parent: Node3D, count: int, max_height: float, row: int) -> void:
	var palette: Array[Color] = [b.BLUE,b.MINT,b.WHITE,b.LIGHT,b.SAKURA,b.GOLD]
	for i in count:
		var h: float = max_height*(.76+.12*float((i+row)%3))
		var book: Node3D = b._group(parent,"BoundBook",Vector3(i*.145,h*.5,0))
		b._box(book,Vector3(.115,h,.38),Vector3.ZERO,palette[(i+row)%palette.size()],0,.008)
		b._box(book,Vector3(.09,h-.045,.025),Vector3(0,0,-.18),b.WHITE,0,.003)
		for line in [.22,.73]: b._box(book,Vector3(.075,.017,.012),Vector3(0,h*(line-.5),.195),b.GOLD,0,.002)

static func sofa(b, root: Node3D, width: float) -> void:
	root.set_meta("sofa_model_revision", "piped_upholstery_v2")
	var structure: Node3D = b._group(root, "SofaWoodenUnderframe")
	for x in [-width*.38, width*.38]:
		for z in [-.54, .54]: Geo.cylinder(structure, .075, .25, Vector3(x, .125, z), b.WOOD, .055)
	b._finish_box(structure, Vector3(width-.18, .17, 1.58), Vector3(0, .30, 0), "ash_table")
	b._cloth(b._box(root, Vector3(width-.08, .25, 1.72), Vector3(0, .46, 0), b.BLUE, 0, .09), b.BLUE)
	b._cloth(b._box(root, Vector3(width-.36, .92, .22), Vector3(0, .98, -.78), b.LIGHT, 0, .07), b.LIGHT)
	var seats: int = maxi(2, roundi((width-.70)/1.7))
	var slot: float = (width-.72)/seats
	var cushions: Node3D = b._group(root, "SeparatePipedSeatCushions")
	for i in seats:
		var x: float = -(width-.72)*.5 + (i+.5)*slot
		Soft._puff(b, cushions, Vector3(x, .74, .12), Vector3(slot-.055, .33, 1.29), b.WHITE, true)
		var back: Node3D = Soft._puff(b, cushions, Vector3(x, 1.08, -.65), Vector3(slot-.055, .38, .88), b.WHITE, true)
		back.rotation.x = -PI*.5+.10
	for side in [-1.0, 1.0]:
		var arm_x: float = side*(width*.5-.18)
		b._cloth(b._box(root, Vector3(.31, .64, 1.68), Vector3(arm_x, .76, 0), b.LIGHT, 0, .06), b.LIGHT)
		Soft._puff(b, root, Vector3(arm_x, .98, 0), Vector3(.34, .36, 1.70), b.LIGHT, true)
		var pillow: Node3D = Soft._puff(b, root, Vector3(side*((width-.72)*.5-.35), 1.08, -.28), Vector3(.64, .24, .65), b.MINT if side < 0 else b.SAKURA, true)
		pillow.rotation = Vector3(-PI*.5, 0, side*.16)
	Soft._sheet(b, root, Vector3(width*.5-.50, 1.0, .1), Vector2(.65, 1.15), b.MINT, .15, .18, 1)
	var plush: Node3D = b._group(root, "SofaWhalePlush")
	b._whale(plush, Vector3(-.15, .88, .10), .30, -12, b.BLUE)

static func tea_table(b, root: Node3D, width: float, depth: float, height: float) -> void:
	root.set_meta("tea_table_model_revision", "rounded_shelf_table_v2")
	var frame: Node3D = b._group(root, "SplayedTeaTableLegs")
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var leg: MeshInstance3D = b._finish_box(frame, Vector3(.13, height-.10, .13), Vector3(x*width*.34, (height-.10)*.5, z*depth*.27), "tea_table", "body", .025)
			leg.rotation = Vector3(z*.07, 0, -x*.07)
	for side in [-1.0, 1.0]:
		b._finish_box(frame, Vector3(width-.36, .14, .10), Vector3(0, height-.15, side*depth*.27), "tea_table")
	var top := MeshInstance3D.new()
	top.name = "RoundedChamferedTeaTop"; top.mesh = _table_top(Vector2(width, depth)); top.position.y = height
	top.material_override = Finishes.material("tea_table", "top"); root.add_child(top)
	var border: Array[Vector3] = _rim(Vector2(width-.18, depth-.18), minf(width,depth)*.24-.06, height+.072)
	for i in border.size(): Geo.rod(root, border[i], border[(i+1)%border.size()], .007, b.WOOD.darkened(.13))
	var shelf: Node3D = b._group(root, "LowerMagazineShelf")
	var shelf_y: float = height*.32
	for i in 5:
		b._finish_box(shelf, Vector3(width-.48, .065, depth*.10), Vector3(0, shelf_y, -depth*.25+i*depth*.125), "tea_table", "top", .012)
	for i in 2:
		b._box(shelf, Vector3(.68, .055, .46), Vector3(-width*.10, shelf_y+.065+i*.06, 0), b.LIGHT if i==0 else b.MINT, 0, .008)
		b._box(shelf, Vector3(.62, .025, .44), Vector3(-width*.10, shelf_y+.065+i*.06, .015), b.WHITE, 0, .003)

static func _rim(size: Vector2, radius: float, y: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for corner in 4:
		var sx: float = 1.0 if corner in [0,3] else -1.0
		var sz: float = 1.0 if corner in [0,1] else -1.0
		var center := Vector2(sx*(size.x*.5-radius), sz*(size.y*.5-radius))
		for i in 7:
			var angle: float = corner*PI*.5+i*PI/12.0
			points.append(Vector3(center.x+cos(angle)*radius, y, center.y+sin(angle)*radius))
	return points

static func _table_top(size: Vector2) -> ArrayMesh:
	var radius: float = minf(size.x, size.y)*.24
	var rings: Array = [_rim(size-Vector2.ONE*.06,radius-.03,.07), _rim(size,radius,.035), _rim(size,radius,-.035), _rim(size-Vector2.ONE*.06,radius-.03,-.07)]
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rings[0].size():
		var next: int = (i+1)%rings[0].size()
		Geo._face(tool, [Vector3(0,.07,0),rings[0][i],rings[0][next]], Vector3.UP)
		Geo._face(tool, [Vector3(0,-.07,0),rings[3][i],rings[3][next]], Vector3.DOWN)
		for band in 3:
			var mid: Vector3 = (rings[band][i]+rings[band][next])*.5
			var normal := Vector3(mid.x, .6 if band==0 else (-.6 if band==2 else 0.0), mid.z).normalized()
			Geo._face(tool, [rings[band][i],rings[band][next],rings[band+1][next],rings[band+1][i]], normal)
	return tool.commit()
