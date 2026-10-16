extends RefCounted
## Applied before floor batching. Upper trim belongs to the existing cutaway.
const LOW_HEIGHT := 1.15
const OPENING := 3.6
const DOOR_HEIGHT := 2.9

static func build(b) -> void:
	for wall: Node3D in b.level.get_meta("home_partitions", []):
		_partition(b, wall)
	b.level.set_meta("wall_detail_revision", "framed_panels_and_layered_trim_v1")

static func back_wall(b, wall: Node3D, length: float) -> void:
	var trim: Node3D = b._group(wall, "BackWallJoinery")
	_skirting(b, trim, -length*.5, length*.5)
	_panel_frames(b, trim, -length*.5, length*.5, .70, .18, 1.12, [1.0])

static func side_wall(b, wall: Node3D, length: float) -> void:
	var trim: Node3D = b._group(wall, "SideWallJoinery")
	trim.rotation.y = PI*.5
	_skirting(b, trim, -length*.5, length*.5)
	_panel_frames(b, trim, -length*.5, length*.5, 1.4, .23, .92, [-1.0, 1.0])

static func _skirting(b, root: Node3D, start: float, end: float) -> void:
	var width := end-start
	var x := (start+end)*.5
	b._box(root, Vector3(width, .10, .34), Vector3(x, .06, 0), b.TEAL, 0, .012)
	b._box(root, Vector3(width, .055, .31), Vector3(x, .155, 0), b.WHITE, 0, .010)
	b._box(root, Vector3(width, .028, .32), Vector3(x, .197, 0), b.MINT, 0, .006)

static func _panel_frames(b, root: Node3D, start: float, end: float, pitch: float, bottom: float, top: float, faces: Array) -> void:
	for i in ceili((end-start)/pitch):
		var width: float = minf(pitch-.10, end-start-i*pitch-.06)
		if width < .16: continue
		var x: float = start+i*pitch+width*.5+.045
		for face: float in faces:
			var z: float = face*.165
			for y in [bottom, top]:
				b._box(root, Vector3(width, .032, .028), Vector3(x, y, z), b.WHITE, 0, .006)
			for side in [-1.0, 1.0]:
				b._box(root, Vector3(.032, top-bottom, .028), Vector3(x+side*(width-.032)*.5, (top+bottom)*.5, z), b.WHITE, 0, .006)

static func _partition(b, wall: Node3D) -> void:
	var upper: Node3D = wall.get_node("CutawayUpper")
	var lower_trim: Node3D = b._group(wall, "PartitionLowerJoinery")
	var upper_trim: Node3D = b._group(upper, "PartitionUpperJoinery")
	var length: float = wall.get_meta("wall_length")
	var doors: Array[Node3D] = []
	for child: Node in wall.get_children():
		if child.has_meta("map_interactive_door"): doors.append(child)
	doors.sort_custom(func(a: Node3D, c: Node3D) -> bool: return a.position.x < c.position.x)
	var start := -length*.5
	for door: Node3D in doors:
		var opening: float=door.get_meta("home_opening_width",OPENING)
		_span(b, lower_trim, upper_trim, start, door.position.x-opening*.5)
		if not door.get_meta("home_custom_frame",false):_door_frame(b, lower_trim, upper_trim, door.position.x)
		start = door.position.x+opening*.5
	_span(b, lower_trim, upper_trim, start, length*.5)
	# Header boards and room names should disappear with the wall above them.
	for child: Node in wall.get_children():
		if child is Label3D:
			child.reparent(upper_trim)
		elif child is MeshInstance3D:
			var bounds: AABB = child.get_aabb()
			if child.position.y+bounds.position.y >= DOOR_HEIGHT-.001:
				child.reparent(upper_trim)
	wall.set_meta("wall_detail_revision", "framed_panels_and_layered_trim_v1")
	b._batch(upper_trim, false)

static func _span(b, lower: Node3D, upper: Node3D, start: float, end: float) -> void:
	if end <= start: return
	_skirting(b, lower, start, end)
	_panel_frames(b, lower, start, end, .70, .25, .95, [-1.0, 1.0])
	var width := end-start
	var x := (start+end)*.5
	b._box(lower, Vector3(width, .035, .35), Vector3(x, LOW_HEIGHT-.01, 0), b.WHITE, 0, .008)
	for tier: Vector3 in [Vector3(.09, 3.74, .29), Vector3(.055, 3.81, .34), Vector3(.035, 3.855, .39)]:
		b._box(upper, Vector3(width, tier.x, tier.z), Vector3(x, tier.y, 0), b.WHITE, 0, .010)
	for edge in [start+.035, end-.035]:
		b._box(lower, Vector3(.07, 1.04, .32), Vector3(edge, .61, 0), b.WHITE, 0, .012)

static func _door_frame(b, lower: Node3D, upper: Node3D, x: float) -> void:
	for side in [-1.0, 1.0]:
		var jamb_x: float = x+side*(OPENING*.5+.09)
		# The decorative architrave stays outside the original clear opening.
		for band in [[lower, 0.0, LOW_HEIGHT], [upper, LOW_HEIGHT, DOOR_HEIGHT]]:
			var band_root: Node3D = band[0]
			var bottom: float = band[1]
			var top: float = band[2]
			for face in [-1.0, 1.0]:
				b._box(band_root, Vector3(.14, top-bottom, .055), Vector3(jamb_x, (top+bottom)*.5, face*.195), b.WHITE, 0, .015)
				var bead_bottom: float = maxf(.26, bottom)
				b._box(band_root, Vector3(.032, top-bead_bottom, .025), Vector3(jamb_x-side*.035, (top+bead_bottom)*.5, face*.232), b.MINT, 0, .006)
		b._box(lower, Vector3(.19, .25, .46), Vector3(jamb_x, .125, 0), b.WHITE, 0, .018)
	var width := OPENING+.36
	b._box(upper, Vector3(width, .12, .45), Vector3(x, DOOR_HEIGHT+.16, 0), b.WHITE, 0, .020)
	b._box(upper, Vector3(width+.08, .045, .49), Vector3(x, DOOR_HEIGHT+.245, 0), b.MINT, 0, .010)
	for face in [-1.0, 1.0]:
		for y in [3.075, 3.565]:
			b._box(upper, Vector3(3.46, .035, .025), Vector3(x, y, face*.171), b.WHITE, 0, .007)
