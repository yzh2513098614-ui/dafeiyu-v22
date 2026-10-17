extends RefCounted
## Slate pavilions and octagonal towers built on the existing playable floors.
const Geo = preload("res://district/story_geometry.gd")
const STONE_SHADER = preload("res://assets/whale_home/castle_stone.gdshader")
const CREAM := Color("e8dbc3")
const TRIM := Color("f2e7d1")
const BLUE := Color("6587b2")
const RIDGE := Color("4a668a")
const PANE := Color("739ba8")
const GOLD := Color("d9b876")
const ROSE := Color("df93ad")
const LEAF := Color("75a276")
static var stone_materials: Dictionary = {}
var b
var exterior

static func stone(color: Color) -> ShaderMaterial:
	if not stone_materials.has(color):
		var material := ShaderMaterial.new(); material.shader = STONE_SHADER
		material.set_shader_parameter("stone_color", color); stone_materials[color] = material
	return stone_materials[color]

func build(builder, facade, villa: Node3D) -> void:
	b = builder; exterior = facade
	_pavilion(villa, "WestSlateGallery", Rect2(-28.35, -30.0, 8.5, 26.0), 14.1, 3.1, -24.1)
	_pavilion(villa, "EastSlateHall", Rect2(.65, -27.4, 27.7, 23.0), 14.0, 7.0, 24.0, true)
	var cx: float = facade.entry_x
	var center_rect := Rect2(cx - 6.7, -7.3, 13.4, 17.05)
	var center: Node3D = b._group(villa, "CentralCastlePediment")
	exterior._elevation(center, "HighArchedHall", cx - 6.0, cx + 6.0, Vector3(0, 10.4, 9.35), 0, [exterior._window_spec(cx, 4.8, .55, 4.7, "hall")], 0, TRIM)
	_gable(center, center_rect, 15.62, 4.25)
	exterior._gable_wall(center, 9.35, 15.62, 4.25)
	exterior._round_window(center, Vector3(cx, 17.1, 9.58))
	_hall_balustrade(center, cx)
	for spec: Array in [[Vector3(-26.8, 0, 9.1), 2.85, 14.4, 6.6], [Vector3(-27.5, 0, -29.1), 2.35, 15.8, 6.5], [Vector3(26.8, 0, 9.1), 2.85, 13.6, 6.2], [Vector3(27.5, 0, -28.8), 2.35, 15.4, 6.1]]:
		_tower(villa, spec[0], spec[1], spec[2], spec[3], true)
	var boundary: Node3D = b._group(b.level.get_node("Island"), "GardenCornerTurrets")
	for point: Vector3 in [Vector3(-44.2, 0, 25.0), Vector3(44.2, 0, 25.0)]:
		_tower(boundary, point, 2.1, 6.5, 4.4, true)
	# Low rear sentries leave the higher house towers readable in silhouette.
	for point: Vector3 in [Vector3(-44.2, 0, -44.2), Vector3(44.2, 0, -44.2)]:
		_tower(boundary, point, 1.6, 5.0, 3.3, true)
	_terrace_greenery(villa)
	_stair_garden_porch(villa)
	_balconettes(villa)
	_climbing_roses(villa)
	for point: Vector3 in [Vector3(9.0, 20.45, -17.5), Vector3(21.0, 20.45, -14.2)]:
		var chimney: Node3D = b._group(villa, "CreamCappedChimney", point)
		b._box(chimney, Vector3(1.35, 2.7, 1.4), Vector3(0, .6, 0), CREAM)
		for y: float in [1.3, 1.9]: b._box(chimney, Vector3(1.65, .22, 1.7), Vector3(0, y, 0), TRIM)
		for x: float in [-.48, .48]: b._box(chimney, Vector3(.32, .44, 1.1), Vector3(x, 2.15, 0), CREAM)
	b.level.set_meta("castle_revision", "cross_gabled_castle_rose_garden_v2")
	b.level.set_meta("castle_tower_count", 9)

func _balconettes(parent: Node3D) -> void:
	for spec: Vector2 in [Vector2(-21.0,5.2),Vector2(-9.6,3.4),Vector2(21.0,4.8)]:
		var root: Node3D=b._group(parent,"FloweredWindowBalconette",Vector3(spec.x,5.85,9.35))
		var width: float=spec.y
		b._box(root,Vector3(width+.35,.22,1.25),Vector3(0,0,.45),TRIM)
		for side in [-1.0,1.0]:
			b._box(root,Vector3(.22,.64,1.20),Vector3(side*(width*.5),.37,.45),CREAM)
		for y: float in [.23,1.05]:Geo.rod(root,Vector3(-width*.5,y,1.0),Vector3(width*.5,y,1.0),.045,RIDGE)
		for i in ceili(width/.45)+1:
			var x: float=-width*.5+minf(i*.45,width)
			Geo.rod(root,Vector3(x,.23,1),Vector3(x,1.05,1),.025,RIDGE)
		for i in 6:
			var x: float=(float(i)/5.0-.5)*(width-.5)
			b.Pastel.clump(root,Vector3(x,.41,.70),Vector3(.85,.65,.85),b.GREEN)
			b._flower(root,Vector3(x,.79,.85),b.SAKURA if i%2 else TRIM,.27)

func _hall_balustrade(parent: Node3D, cx: float) -> void:
	var root: Node3D = b._group(parent, "GrandHallStoneBalconette", Vector3(cx,10.4,9.3))
	b._box(root, Vector3(10.2,.26,1.65), Vector3(0,-.04,.40), TRIM)
	for side in [-1.0,1.0]:
		var x: float = side*4.9
		b._box(root, Vector3(.40,1.13,1.50), Vector3(x,.55,.40), CREAM)
		b._box(root, Vector3(.54,.16,1.65), Vector3(x,1.14,.40), TRIM)
		b._box(root, Vector3(.55,.75,.60), Vector3(x,-.48,.10), CREAM)
	for y: float in [.22,1.12]:b._box(root,Vector3(9.7,.16,.35),Vector3(0,y,1.03),TRIM)
	for i in 19:
		var x: float = -4.5+i*.5
		Geo.cylinder(root,.075,.75,Vector3(x,.66,1.03),TRIM)
		Geo.cylinder(root,.135,.25,Vector3(x,.61,1.03),TRIM,.10)
	for x: float in [-4.8,4.8]:
		b.Pastel.clump(root,Vector3(x,1.35,.36),Vector3(.88,.68,1.1),LEAF)
		for i in 3:b._flower(root,Vector3(x+(i-1)*.22,1.66,.52),ROSE if i%2 else TRIM,.27)

func _stair_garden_porch(parent: Node3D) -> void:
	var spec: Dictionary = b.floors[2].get_node("MoonriseStairs_3F_4F").get_meta("home_stair")
	var root: Node3D = b._group(parent, "FloweredStairPorch", Vector3(spec.x,spec.base,spec.front+.5))
	for x: float in [-2.3,2.3]:
		for z: float in [-1.35,0.0]:
			b._box(root,Vector3(.48,.20,.48),Vector3(x,.12,z),TRIM)
			b._box(root,Vector3(.30,3.55,.30),Vector3(x,1.92,z),CREAM)
			b._box(root,Vector3(.50,.18,.50),Vector3(x,3.72,z),TRIM)
			b._coll(root,Vector3(.48,3.8,.48),Vector3(x,1.9,z))
		b._vines(root,Vector3(x,.40,.16),Vector3(x,3.75,.16),.05)
		for i in 4:
			b.Pastel.clump(root,Vector3(x,1.10+i*.70,.10),Vector3(.55,.80,.50),LEAF)
			b._flower(root,Vector3(x+.12,1.3+i*.70,.39),ROSE,.27)
	b._box(root,Vector3(5.0,.23,1.85),Vector3(0,3.77,-.6),TRIM)
	_gable(root,Rect2(-2.55,-1.9,5.1,3.4),3.85,1.25)
	for i in 7:
		b.Pastel.clump(root,Vector3(-2.1+i*.70,3.87,1.46),Vector3(.85,.54,.55),LEAF)
		b._flower(root,Vector3(-2.1+i*.70,4.08,1.64),ROSE if i%2 else TRIM,.27)
	for side: float in [-1.0,1.0]:
		var a := Vector3(spec.x+side*2.12,spec.base+.90,spec.front)
		var c := Vector3(a.x,spec.base+6.0,spec.back)
		b._vines(parent,a,c,.08)
		for i in 7:
			var point: Vector3 = a.lerp(c,i/6.0)
			b.Pastel.clump(parent,point,Vector3(.62,.62,.72),LEAF)
			b._flower(parent,point+Vector3(side*.18,.20,.20),ROSE if i%3 else TRIM,.27)
	for rect: Rect2 in [Rect2(-17.8,-3.9,3.0,4.6),Rect2(-6.7,-3.8,2.7,4.8),Rect2(12.2,-4.1,8.4,.95)]:
		_terrace_rose_bed(parent,rect,spec.base)

func _terrace_rose_bed(parent: Node3D, rect: Rect2, height: float) -> void:
	var root: Node3D = b._group(parent,"RaisedTerraceRoseBed",Vector3(rect.get_center().x,height,rect.get_center().y))
	b._box(root,Vector3(rect.size.x,.42,rect.size.y),Vector3(0,.23,0),CREAM)
	b._box(root,Vector3(rect.size.x+.12,.13,rect.size.y+.12),Vector3(0,.46,0),TRIM)
	b._box(root,Vector3(rect.size.x-.16,.10,rect.size.y-.16),Vector3(0,.55,0),Color("7b8d64"))
	var rows: int = maxi(1,ceili(rect.size.y/.90))
	var columns: int = maxi(1,ceili(rect.size.x/.90))
	for row in rows:
		for column in columns:
			var x: float = (column+.5)*rect.size.x/columns-rect.size.x*.5
			var z: float = (row+.5)*rect.size.y/rows-rect.size.y*.5
			var y: float = .80+sin(row*2.1+column)*.08
			b.Pastel.clump(root,Vector3(x,y,z),Vector3(.94,.72,.94),LEAF)
			b._flower(root,Vector3(x+.12,y+.31,z+.12),ROSE if (row+column)%3 else TRIM,.29)
	b._coll(root,Vector3(rect.size.x+.12,.8,rect.size.y+.12),Vector3(0,.4,0))

func _pavilion(parent: Node3D, label: String, rect: Rect2, eave: float, rise: float, passage_x: float, cross_roof: bool = false) -> void:
	var root: Node3D = b._group(parent, label)
	var bottom := 10.4
	var height: float = eave - bottom
	for x: float in [rect.position.x + .30, rect.end.x - .30]:
		var wall: Node3D = b._group(root, "AtticSideWall", Vector3(x, bottom, rect.get_center().y))
		var depth: float = rect.size.y - .5
		# The end portals retain the existing continuous perimeter walking route.
		b._box(wall, Vector3(.22, height, depth), Vector3(0, height * .5, 0), CREAM).material_override = stone(CREAM)
		b._coll(wall, Vector3(.22, height, depth), Vector3(0, height * .5, 0))
		for i in 4:
			var z: float = -depth * .5 + (i + .5) * depth / 4.0
			var frame: Node3D = b._group(wall, "ArchedAtticWindow", Vector3(-.13 if x < rect.get_center().x else .13, .35, z))
			frame.rotation.y = -PI * .5 if x < rect.get_center().x else PI * .5
			_arch_window(frame, 1.6, height - .7)
	for z: float in [rect.position.y + .3, rect.end.y - .3]:
		var end: Node3D = b._group(root, "AtticOpenPortal", Vector3(0, bottom, z))
		var left: float = rect.position.x + .3
		var right: float = rect.end.x - .3
		var gate_left: float = passage_x - 2.1
		var gate_right: float = passage_x + 2.1
		for span: Vector2 in [Vector2(left, gate_left), Vector2(gate_right, right)]:
			if span.y <= span.x: continue
			b._box(end, Vector3(span.y - span.x, height, .22), Vector3((span.x + span.y) * .5, height * .5, 0), CREAM).material_override = stone(CREAM)
			b._coll(end, Vector3(span.y - span.x, height, .22), Vector3((span.x + span.y) * .5, height * .5, 0))
		b._box(end, Vector3(4.2, .25, .24), Vector3(passage_x, height - .125, 0), TRIM)
		for x: float in [gate_left - .08, gate_right + .08]:
			b._box(end, Vector3(.17, height, .30), Vector3(x, height * .5, 0), TRIM)
	if cross_roof:
		_cross_roof(root, rect, eave, rise)
		return
	_gable(root, rect, eave, rise)
	for z: float in [rect.position.y + .25, rect.end.y - .25]:
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		Geo._face(tool, [Vector3(rect.position.x + .3, eave, z), Vector3(rect.end.x - .3, eave, z), Vector3(rect.get_center().x, eave + rise - .1, z)], Vector3.BACK if z > rect.get_center().y else Vector3.FORWARD)
		var wall := MeshInstance3D.new(); wall.mesh = tool.commit(); wall.material_override = Geo.material(CREAM); root.add_child(wall)
		var frame: Node3D = b._group(root, "GableArchedWindow", Vector3(rect.get_center().x, eave + .25, z + (.035 if z > rect.get_center().y else -.035)))
		if z < rect.get_center().y: frame.rotation.y = PI
		_arch_window(frame, minf(2.8, rect.size.x * .22), minf(2.8, rise - .6))
	for spec: Vector2 in [Vector2(rect.position.x + .2, rect.get_center().y - 5.2), Vector2(rect.end.x - .2, rect.get_center().y + 4.0)]:
		_dormer(root, Vector3(spec.x, eave + .30, spec.y), -PI * .5 if spec.x < rect.get_center().x else PI * .5)

func _cross_roof(parent: Node3D, rect: Rect2, eave: float, rise: float) -> void:
	# A long east-west ridge exposes the front slate slope and its dormers.
	var center: Vector2 = rect.get_center()
	var roof: Node3D = b._group(parent, "TransverseSlateRoof", Vector3(center.x, 0, center.y))
	roof.rotation.y = PI * .5
	_gable(roof, Rect2(-rect.size.y * .5, -rect.size.x * .5, rect.size.y, rect.size.x), eave, rise)
	for x: float in [rect.position.x + .3, rect.end.x - .3]:
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		Geo._face(tool, [Vector3(x, eave, rect.position.y + .3), Vector3(x, eave, rect.end.y - .3), Vector3(x, eave + rise - .1, center.y)], Vector3.LEFT if x < center.x else Vector3.RIGHT)
		var wall := MeshInstance3D.new(); wall.mesh = tool.commit(); wall.material_override = stone(CREAM); parent.add_child(wall)
		var frame: Node3D = b._group(parent, "TransverseGableArch", Vector3(x + (-.035 if x < center.x else .035), eave + .25, center.y))
		frame.rotation.y = -PI * .5 if x < center.x else PI * .5
		_arch_window(frame, 2.8, 2.8)
	for x: float in [4.8, 12.0, 19.2]:
		_dormer(parent, Vector3(x, 15.35, -7.2), 0)
		for z: float in [rect.position.y + .13, rect.end.y - .13]:
			var frame: Node3D = b._group(parent, "FrontAtticArchedBay", Vector3(x, 11.0, z))
			if z < center.y: frame.rotation.y = PI
			_arch_window(frame, 2.0, 2.5)

func _gable(parent: Node3D, rect: Rect2, eave: float, rise: float) -> void:
	var root: Node3D = b._group(parent, "LayeredSlateRoof")
	var mid: float = rect.get_center().x
	var half: float = rect.size.x * .5
	for side in [-1.0, 1.0]:
		var edge: float = mid + side * half
		var normal := Vector3(side * rise, half, 0).normalized()
		var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		Geo._face(surface, [Vector3(edge, eave, rect.position.y), Vector3(mid, eave + rise, rect.position.y), Vector3(mid, eave + rise, rect.end.y), Vector3(edge, eave, rect.end.y)], normal)
		_mesh(root, surface, RIDGE)
		var tools: Array[SurfaceTool] = []
		for i in 3:
			var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); tools.append(tool)
		var rows: int = ceili(Vector2(half, rise).length() / .65)
		for row in rows:
			var start: float = float(row) / rows + .007
			var stop: float = float(row + 1) / rows - .003
			var shift: float = .52 if row % 2 else 0.0
			for column in ceili(rect.size.y / 1.05) + 1:
				var za: float = maxf(rect.position.y + .015, rect.position.y + column * 1.05 - shift)
				var zb: float = minf(rect.end.y - .015, rect.position.y + (column + 1) * 1.05 - shift - .028)
				if zb <= za: continue
				var p := Vector3(lerpf(edge, mid, start), eave + rise * start + .025, za)
				var q := Vector3(lerpf(edge, mid, stop), eave + rise * stop + .025, za)
				Geo._face(tools[(row + column) % 3], [p, q, Vector3(q.x, q.y, zb), Vector3(p.x, p.y, zb)], normal)
		for i in 3: _mesh(root, tools[i], BLUE.lightened(i * .035))
		Geo.rod(root, Vector3(edge, eave - .08, rect.position.y), Vector3(edge, eave - .08, rect.end.y), .12, TRIM)
		for z: float in [rect.position.y, rect.end.y]:
			Geo.rod(root, Vector3(edge, eave, z), Vector3(mid, eave + rise, z), .12, TRIM)
	Geo.rod(root, Vector3(mid, eave + rise + .05, rect.position.y), Vector3(mid, eave + rise + .05, rect.end.y), .15, RIDGE)
	root.set_meta("castle_roof_rect", rect)
	root.set_meta("castle_roof_eave", eave)

func _mesh(parent: Node3D, tool: SurfaceTool, color: Color) -> void:
	var node := MeshInstance3D.new(); node.mesh = tool.commit(); node.material_override = Geo.material(color); parent.add_child(node)

func _dormer(parent: Node3D, point: Vector3, yaw: float) -> void:
	var root: Node3D = b._group(parent, "SlateRoofDormer", point); root.rotation.y = yaw
	b._box(root, Vector3(2.0, 2.0, 1.6), Vector3(0, 1.0, -.4), CREAM)
	var face: Node3D = b._group(root, "ArchedDormerFace", Vector3(0, .2, .43))
	_arch_window(face, 1.25, 1.7)
	_gable(root, Rect2(-1.2, -1.3, 2.4, 2.05), 2.0, 1.0)

func _arch_window(parent: Node3D, width: float, height: float) -> void:
	var radius: float = width * .5
	var spring: float = height - radius
	var points: Array[Vector3] = [Vector3(-radius, 0, 0), Vector3(radius, 0, 0)]
	for i in 17:
		var angle: float = i * PI / 16.0
		points.append(Vector3(cos(angle) * radius, spring + sin(angle) * radius, 0))
	var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	Geo._face(tool, points, Vector3.BACK); _mesh(parent, tool, PANE)
	for side in [-1.0, 1.0]:
		Geo.rod(parent, Vector3(side * radius, 0, .04), Vector3(side * radius, spring, .04), .09, TRIM)
	for i in 16:
		var a: float = i * PI / 16.0; var c: float = (i + 1) * PI / 16.0
		Geo.rod(parent, Vector3(cos(a) * radius, spring + sin(a) * radius, .04), Vector3(cos(c) * radius, spring + sin(c) * radius, .04), .10, TRIM)
	Geo.rod(parent, Vector3(0, .04, .06), Vector3(0, height - .04, .06), .035, GOLD)
	Geo.rod(parent, Vector3(-radius, spring, .06), Vector3(radius, spring, .06), .035, RIDGE)
	b._box(parent, Vector3(width + .32, .15, .45), Vector3(0, -.06, 0), TRIM)

func _octagon(parent: Node3D, radius: float, height: float, y: float, color: Color) -> void:
	var mesh := CylinderMesh.new(); mesh.radial_segments = 8; mesh.rings = 1
	mesh.bottom_radius = radius; mesh.top_radius = radius; mesh.height = height
	var node := MeshInstance3D.new(); node.mesh = mesh; node.position.y = y
	node.rotation.y = PI / 8.0; node.material_override = stone(color) if color == CREAM else Geo.material(color); parent.add_child(node)

func _tower(parent: Node3D, point: Vector3, radius: float, height: float, rise: float, collision: bool) -> Node3D:
	var root: Node3D = b._group(parent, "OctagonalCastleTurret", point)
	root.set_meta("castle_tower_radius", radius); root.set_meta("castle_tower_height", height + rise)
	_octagon(root, radius, height, height * .5, CREAM)
	for y: float in [.16, .55, height - .45, height - .12]:
		_octagon(root, radius + (.24 if y > height - .5 else .12), .20, y, TRIM)
	var levels: int = ceili(height / 5.2) if radius >= 2.0 else 1
	var storey: float = height / levels
	for level in range(1, levels):
		_octagon(root, radius + .035, .10, storey * level, Color("ded4bf"))
	for level in levels:
		for angle: float in [0.0, PI * .5, PI, PI * 1.5]:
			var sill: float = storey * level + .70 if levels > 1 else height - minf(4.2,height*.65)
			var face: Node3D = b._group(root, "TurretArchedWindow", Vector3(sin(angle) * (radius * .925 + .02), sill, cos(angle) * (radius * .925 + .02)))
			face.rotation.y = angle
			_arch_window(face, minf(1.35, radius * .85), minf(3.0,storey-1.4) if levels > 1 else minf(3.0,height*.48))
	_cone(root, radius + .32, height, rise)
	if radius >= 2.0:
		for angle: float in [0.0,PI*.5,PI,PI*1.5]:
			var dormer: Node3D = b._group(root,"SpireRoofArchedDormer",Vector3(sin(angle)*(radius+.10),height+.18,cos(angle)*(radius+.10)))
			dormer.rotation.y = angle; dormer.scale = Vector3.ONE*.46
			_dormer(dormer,Vector3.ZERO,0)
	if collision:
		var body := StaticBody3D.new(); var shape := CollisionShape3D.new(); var cylinder := CylinderShape3D.new()
		cylinder.radius = radius; cylinder.height = height
		shape.shape = cylinder; shape.position.y = height * .5; body.add_child(shape); root.add_child(body)
	return root

func _cone(parent: Node3D, radius: float, y: float, rise: float) -> void:
	# A continuous slate shell closes the joints between individual shingle faces.
	var shell := MeshInstance3D.new(); var cone := CylinderMesh.new()
	cone.radial_segments = 8; cone.rings = 1; cone.bottom_radius = radius - .025; cone.top_radius = 0; cone.height = rise - .04
	shell.mesh = cone; shell.position.y = y + rise * .5 - .02; shell.rotation.y = PI / 8.0
	shell.material_override = Geo.material(RIDGE); parent.add_child(shell)
	var tools: Array[SurfaceTool] = []
	for i in 3:
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES); tools.append(tool)
	var rows: int = ceili(rise / .5)
	for side in 8:
		var angle: float = PI / 8.0 + side * TAU / 8.0
		var next: float = angle + TAU / 8.0
		var a := Vector3(cos(angle) * radius, y, sin(angle) * radius)
		var c := Vector3(cos(next) * radius, y, sin(next) * radius)
		var top := Vector3(0, y + rise, 0)
		var normal: Vector3 = Vector3(cos(angle + PI / 8), radius / rise, sin(angle + PI / 8)).normalized()
		for row in rows:
			var t: float = float(row) / rows + .003
			var u: float = minf(1.0, float(row + 1) / rows - .003)
			for column in 3:
				var left: float = column / 3.0 + .008
				var right: float = (column + 1) / 3.0 - .008
				Geo._face(tools[(row + side + column) % 3], [a.lerp(c, left).lerp(top, t), a.lerp(c, right).lerp(top, t), a.lerp(c, right).lerp(top, u), a.lerp(c, left).lerp(top, u)], normal)
		Geo.rod(parent, a, top, .025, RIDGE)
	for i in 3: _mesh(parent, tools[i], BLUE.lightened(i * .035))
	_octagon(parent, radius + .04, .18, y - .05, TRIM)
	Geo.cylinder(parent, .13, 1.5, Vector3(0, y + rise + .55, 0), GOLD, .018)
	b._sphere(parent, Vector3(0, y + rise + .12, 0), Vector3(.31, .35, .31), GOLD)

func _climbing_roses(parent: Node3D) -> void:
	for spec: Array in [[Vector3(-17.8, 0, 9.53), 0.0], [Vector3(17.0, 0, 9.53), 0.0], [Vector3(-28.52, 0, -12.4), -PI * .5], [Vector3(-28.52, 0, -23.4), -PI * .5]]:
		var root: Node3D = b._group(parent, "ClimbingRoseEspalier", spec[0]); root.rotation.y = spec[1]
		for side in [-1.0, 1.0]:
			b._vines(root, Vector3(side * .18, .25, .03), Vector3(side * .95, 9.1, .03), .25)
		for i in 12:
			var y: float = .9 + i * .70
			var x: float = sin(i * 1.75) * .72
			b.Pastel.clump(root, Vector3(x, y, .14), Vector3(1.25, 1.15, .62), LEAF)
			b._flower(root, Vector3(x + .18, y + .28, .48), ROSE if i % 4 else TRIM, .32)
			if i % 3 == 0:
				b.Pastel.clump(root, Vector3(x + .65, y + .28, .12), Vector3(1.0, .85, .58), LEAF)
				b._flower(root, Vector3(x + .66, y + .51, .46), ROSE, .29)
	for x: float in [-19.0, -15.5, 14.5, 18.0, 21.5]:
		var cascade: Node3D = b._group(parent, "TerraceTrailingRoses", Vector3(x, 10.9, 8.95))
		for strand in 3:
			var offset: float = (strand - 1) * .55
			b._vines(cascade, Vector3(offset, .15, 0), Vector3(offset + .20, -1.8 + strand * .24, .18), .12)
			for i in 3:
				b.Pastel.clump(cascade, Vector3(offset, -.15 - i * .55, .13), Vector3(.86, .84, .68), LEAF)
				b._flower(cascade, Vector3(offset + .13, -.04 - i * .55, .52), ROSE if (i + strand) % 3 else TRIM, .26)

func _terrace_greenery(parent: Node3D) -> void:
	for point: Vector3 in [Vector3(-16,0,10.6),Vector3(-5.5,0,10.6),Vector3(12.7,0,10.6)]:
		var topiary: Node3D = b._group(parent, "PottedGardenTopiary", point)
		Geo.cylinder(topiary,.48,.75,Vector3(0,.38,0),CREAM,.60)
		Geo.cylinder(topiary,.63,.13,Vector3(0,.76,0),TRIM)
		Geo.rod(topiary,Vector3(0,.7,0),Vector3(0,2.4,0),.055,b.WOOD)
		for i in 3: b.Pastel.clump(topiary,Vector3(0,1.15+i*.61,0),Vector3(1.55-i*.32,.95,1.55-i*.32),b.GREEN)
		b._coll(topiary,Vector3(1.2,.9,1.2),Vector3(0,.45,0))
	for point: Vector3 in [Vector3(-24, 10.45, 5.4), Vector3(17, 10.45, 5.4), Vector3(23, 10.45, 5.4), Vector3(4, 10.45, -31.5), Vector3(12, 10.45, -31.5)]:
		b._plant(parent, point, 1.1, true)
	for x: float in [-19.0, -15.5, 14.5, 18.0, 21.5]:
		var box: Node3D = b._group(parent, "TerraceFlowerBalustrade", Vector3(x, 10.4, 7.4))
		b._box(box, Vector3(2.8, .48, .85), Vector3(0, .35, 0), TRIM)
		b._box(box, Vector3(2.9, .12, .98), Vector3(0, .63, 0), CREAM)
		for i in 5:
			b.Pastel.clump(box, Vector3(-1.0 + i * .5, .83, 0), Vector3(.68, .55, .70), b.GREEN)
			b._flower(box, Vector3(-1.0 + i * .5, 1.13, .04), b.SAKURA if i % 2 else TRIM, .25)
		b._coll(box, Vector3(2.9, .8, .98), Vector3(0, .4, 0))
	# A shaded seating group fills the wider east terrace while keeping the front lane.
	var garden: Node3D=b._model(parent,b.PERGOLA,Vector3(-20.4,10.4,1.0),true)
	for x: float in [-2.0,2.0]:
		for z: float in [-1.65,1.65]:
			b._coll(garden,Vector3(.22,3.35,.22),Vector3(x,1.675,z))
			b._vines(garden,Vector3(x,.45,z+.12),Vector3(x,3.25,z+.12),.10)
			for i in 4:
				b.Pastel.clump(garden,Vector3(x,.8+i*.65,z),Vector3(.60,.80,.6),LEAF)
				b._flower(garden,Vector3(x+.13,1.0+i*.65,z+.35),ROSE,.27)
	b._table(garden,Vector3.ZERO,2.7,1.4,.72,"garden_table")
	for side: float in [-1.0,1.0]:b._chair(garden,Vector3(side*2.0,0,0),side*90)
	b._vines(garden,Vector3(-2,3.2,1.7),Vector3(2,3.2,1.7),.30)
	for x: float in [-1.5,-.5,.5,1.5]:
		b.Pastel.clump(garden,Vector3(x,3.25,1.65),Vector3(1.2,.55,.80),b.GREEN)
		b._flower(garden,Vector3(x,3.4,1.8),b.SAKURA,.35)
	for x: float in [11.6,21.7]:
		var planter: Node3D = b._group(parent,"EastTerraceRoseUrn",Vector3(x,10.4,-2.35))
		Geo.cylinder(planter,.44,.60,Vector3(0,.30,0),CREAM,.58)
		Geo.cylinder(planter,.60,.14,Vector3(0,.65,0),TRIM)
		b.Pastel.clump(planter,Vector3(0,1.08,0),Vector3(1.25,1.05,1.25),LEAF)
		for i in 5:
			var angle: float = i*TAU/5.0
			b._flower(planter,Vector3(cos(angle)*.38,1.50,sin(angle)*.38),ROSE if i%2 else TRIM,.29)
		b._coll(planter,Vector3(1.15,.85,1.15),Vector3(0,.425,0))
	var seating: Node3D = b._group(parent, "EastTerraceSunshade", Vector3(17.5, 10.4, 1.7))
	b._table(seating, Vector3.ZERO, 2.8, 1.5, .72, "garden_table")
	for side in [-1.0, 1.0]: b._chair(seating, Vector3(side * 2.3, 0, 0), 90 * side)
	Geo.rod(seating, Vector3.ZERO, Vector3(0, 3.5, 0), .045, GOLD)
	for i in 8:
		var a: float = i * TAU / 8.0; var c: float = (i + 1) * TAU / 8.0
		var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		Geo._face(tool, [Vector3(0, 3.6, 0), Vector3(cos(a) * 2.3, 3.0, sin(a) * 2.3), Vector3(cos(c) * 2.3, 3.0, sin(c) * 2.3)], Vector3.UP)
		_mesh(seating, tool, TRIM if i % 2 else BLUE.lightened(.15))
	for point: Vector3 in [Vector3(-20.7, 0, 9.35), Vector3(19.5, 0, 9.35)]:
		b._vines(parent, point + Vector3(0, .8, .1), point + Vector3(1.7, 8.5, .1), .65)
	for x: float in [-24.0, 14.5, 22.0]:
		var awning: Node3D = b._group(parent, "BlueCanvasWindowAwning", Vector3(x, 8.9, 9.28))
		for i in 5:
			var cloth: MeshInstance3D = b._box(awning, Vector3(.63, .09, 1.65), Vector3((i - 2) * .63, 0, .68), BLUE.lightened(.08) if i % 2 == 0 else TRIM, 0, .014)
			cloth.rotation.x = .18
