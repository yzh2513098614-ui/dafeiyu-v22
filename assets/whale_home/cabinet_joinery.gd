extends RefCounted
## Board-built cabinets and table frames, using the existing furniture finishes.
const Geo = preload("res://district/story_geometry.gd")

static func cabinet(b, root: Node3D, width: float, height: float, profile: String) -> void:
	root.set_meta("cabinet_model_revision", "framed_doors_drawers_and_recessed_plinth_v1")
	var frame: Node3D = b._group(root, "CabinetCarcassAndPlinth")
	b._finish_box(frame, Vector3(width-.14, .15, .72), Vector3(0, .075, -.045), profile, "back", .015)
	b._finish_box(frame, Vector3(width, .055, .88), Vector3(0, .17, 0), profile, "back", .008)
	b._finish_box(frame, Vector3(width-.12, height-.22, .07), Vector3(0, (height+.18)*.5, -.415), profile, "back", .015)
	for side in [-1.0, 1.0]:
		var x: float = side*(width*.5-.045)
		b._finish_box(frame, Vector3(.09, height-.18, .88), Vector3(x, (height+.18)*.5, 0), profile, "body", .018)
		b._finish_box(frame, Vector3(.025, height-.40, .62), Vector3(side*(width*.5+.006), height*.5+.07, -.015), profile, "back", .008)
	for y in [.23, height-.07]:
		b._finish_box(frame, Vector3(width-.10, .10, .88), Vector3(0, y, 0), profile, "body", .015)
	b._finish_box(frame, Vector3(width+.10, .10, 1.04), Vector3(0, height+.04, 0), profile, "top", .026)
	b._finish_box(frame, Vector3(width+.035, .045, .97), Vector3(0, height-.035, 0), profile, "body", .010)
	var bays: int = 1 if width<1.4 else (3 if width>3.3 else 2)
	var slot: float = (width-.16)/bays
	var drawers: bool = height<=1.45
	var top: float = height-.10
	var drawer_height: float = minf(.225, height*.22)
	var door_top: float = top-drawer_height-.035 if drawers else top
	for i in bays:
		var x: float = -(width-.16)*.5+(i+.5)*slot
		var door_height: float = door_top-.23
		var panel: Node3D = b._group(root, "FramedCabinetDoor", Vector3(x, .23+door_height*.5, .468))
		panel.set_meta("cabinet_front", true)
		_panel(b, panel, slot-.025, door_height, profile)
		var pull_x: float = 0.0 if bays==1 else (slot*.30 if i%2==0 else -slot*.30)
		_pull(b, panel, Vector3(pull_x, door_height*.20, .064), false)
		for hinge_y in [-door_height*.28, door_height*.28]:
			Geo.cylinder(panel, .018, .075, Vector3(-slot*.5+.055, hinge_y, .047), b.GOLD)
		if drawers:
			var drawer: Node3D = b._group(root, "InsetDrawerFront", Vector3(x, top-drawer_height*.5, .468))
			drawer.set_meta("cabinet_front", true)
			b._finish_box(drawer, Vector3(slot-.025, drawer_height, .060), Vector3.ZERO, profile, "body", .016)
			b._finish_box(drawer, Vector3(slot-.15, drawer_height-.075, .018), Vector3(0, 0, .037), profile, "back", .009)
			_pull(b, drawer, Vector3(0, 0, .064), true)
		if i<bays-1:
			b._finish_box(frame, Vector3(.035, height-.34, .10), Vector3(x+slot*.5, (height+.20)*.5, .385), profile, "body", .006)
	root.set_meta("cabinet_bays", bays)
	root.set_meta("cabinet_has_drawers", drawers)

static func _panel(b, root: Node3D, width: float, height: float, profile: String) -> void:
	# A recessed field sits behind separate stiles and rails.
	b._finish_box(root, Vector3(width-.09, height-.10, .035), Vector3(0, 0, -.012), profile, "back", .010)
	for side in [-1.0, 1.0]:
		b._finish_box(root, Vector3(.065, height, .065), Vector3(side*(width-.065)*.5, 0, 0), profile, "body", .012)
		b._finish_box(root, Vector3(width-.13, .065, .065), Vector3(0, side*(height-.065)*.5, 0), profile, "body", .012)
		b._finish_box(root, Vector3(.018, height-.13, .025), Vector3(side*(width-.15)*.5, 0, .015), profile, "top", .004)
		b._finish_box(root, Vector3(width-.15, .018, .025), Vector3(0, side*(height-.15)*.5, .015), profile, "top", .004)

static func _pull(b, root: Node3D, point: Vector3, horizontal: bool) -> void:
	var axis := Vector3.RIGHT if horizontal else Vector3.UP
	for side in [-1.0, 1.0]:
		var mount: Vector3 = point+axis*side*.095
		Geo.rod(root, mount-Vector3(0, 0, .035), mount, .014, b.GOLD)
	Geo.rod(root, point-axis*.11, point+axis*.11, .019, b.GOLD)

static func table_frame(b, root: Node3D, width: float, depth: float, height: float, profile: String) -> void:
	root.set_meta("table_model_revision", "tapered_legs_four_aprons_and_corner_blocks_v1")
	var underframe: Node3D = b._group(root, "MortisedTableUnderframe")
	for side in [-1.0, 1.0]:
		b._finish_box(underframe, Vector3(width*.76, .18, .09), Vector3(0, height-.19, side*depth*.34), profile, "body", .012)
		b._finish_box(underframe, Vector3(.09, .18, depth*.68), Vector3(side*width*.38, height-.19, 0), profile, "body", .012)
		for front in [-1.0, 1.0]:
			var x: float = side*width*.38
			var z: float = front*depth*.34
			var leg: MeshInstance3D = b._finish_box(underframe, Vector3(.16, height-.08, .16), Vector3(x, (height-.08)*.5, z), profile, "body", .022)
			# Taper the lower end while preserving the original leg footprint.
			var arrays: Array = leg.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				var factor: float = lerpf(.62, 1.0, (vertices[i].y+(height-.08)*.5)/(height-.08))
				vertices[i].x *= factor; vertices[i].z *= factor
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var tapered := ArrayMesh.new(); tapered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var tool := SurfaceTool.new(); tool.create_from(tapered, 0); tool.generate_normals(false); leg.mesh = tool.commit()
			b._finish_box(underframe, Vector3(.22, .12, .22), Vector3(x-side*.11, height-.19, z-front*.11), profile, "back", .025)
	b._finish_box(root, Vector3(width, .14, depth), Vector3(0, height, 0), profile, "top", .045)
	b._finish_box(underframe, Vector3(width-.10, .035, depth-.10), Vector3(0, height-.087, 0), profile, "body", .012)
