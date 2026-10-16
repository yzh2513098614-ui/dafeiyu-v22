extends RefCounted
## Open lamp shades and optical tubes. Existing controllers own light and motion.
const Geo = preload("res://district/story_geometry.gd")
static var shells: Dictionary = {}

static func fixture_frame(b, root: Node3D, hanging: bool) -> void:
	if hanging:
		Geo.rod(root, Vector3(0,.40,0), Vector3(0,1.35,0), .018, b.GOLD)
		Geo.cylinder(root, .13, .075, Vector3(0,1.31,0), b.WHITE)
		Geo.cylinder(root, .075, .13, Vector3(0,.34,0), b.GOLD)
		_shell(root, .43, .22, .40, .022, Vector3(0,-.16,0), b.WHITE, .008)
		_rim(root, .43, .027, Vector3(0,-.16,0), b.GOLD)
		_rim(root, .22, .018, Vector3(0,.24,0), b.GOLD)
		for i in 3:
			var angle: float = i*TAU/3.0
			Geo.rod(root, Vector3(0,.28,0), Vector3(cos(angle)*.20,.24,sin(angle)*.20), .012, b.GOLD)
	else:
		Geo.cylinder(root, .30, .08, Vector3(0,.04,0), b.GOLD)
		Geo.cylinder(root, .25, .025, Vector3(0,.095,0), b.WHITE)
		Geo.cylinder(root, .055, .64, Vector3(0,.36,0), b.GOLD)
		_shell(root, .45, .20, .50, .022, Vector3(0,.56,0), b.WHITE, .010)
		_rim(root, .45, .025, Vector3(0,.56,0), b.GOLD)
		_rim(root, .20, .018, Vector3(0,1.06,0), b.GOLD)
		Geo.cylinder(root, .08, .055, Vector3(0,1.075,0), b.GOLD)
		for i in 3:
			var angle: float = i*TAU/3.0
			Geo.rod(root, Vector3(0,.67,0), Vector3(cos(angle)*.19,1.02,sin(angle)*.19), .012, b.GOLD)
		Geo.rod(root, Vector3(.06,.18,0), Vector3(.15,.18,0), .013, b.GOLD)
		b._sphere(root, Vector3(.17,.18,0), Vector3.ONE*.065, b.WHITE)
	root.set_meta("optics_detail", "open_pleated_fixture_v1")

static func reading_stand(b, stand: Node3D) -> void:
	Geo.cylinder(stand, .34, .09, Vector3(0,.055,0), b.TEAL)
	Geo.cylinder(stand, .28, .025, Vector3(0,.112,0), b.WHITE)
	Geo.rod(stand, Vector3(0,.1,0), Vector3(0,2.35,0), .035, b.GOLD)
	for y in [.20, 1.25, 2.21]:
		Geo.cylinder(stand, .055, .065, Vector3(0,y,0), b.TEAL)
	_shell(stand, .45, .24, .60, .022, Vector3(0,2.25,0), b.WHITE, .010)
	_rim(stand, .45, .025, Vector3(0,2.25,0), b.GOLD)
	_rim(stand, .24, .018, Vector3(0,2.85,0), b.GOLD)
	Geo.cylinder(stand, .07, .06, Vector3(0,2.87,0), b.GOLD)
	for i in 3:
		var angle: float = i*TAU/3.0
		Geo.rod(stand, Vector3(0,2.28,0), Vector3(cos(angle)*.22,2.80,sin(angle)*.22), .012, b.GOLD)
	Geo.rod(stand, Vector3(.07,2.28,0), Vector3(.13,2.11,0), .010, b.GOLD)
	b._sphere(stand, Vector3(.13,2.08,0), Vector3(.05,.07,.05), b.WHITE)
	stand.set_meta("optics_detail", "open_pleated_reading_lamp_v1")

static func telescope(b, action: Node3D) -> void:
	var tripod: Node3D = b._group(action, "BracedTelescopingTripod")
	for i in 3:
		var angle: float = i*TAU/3.0
		var foot := Vector3(cos(angle)*.92,.05,sin(angle)*.92)
		var top := Vector3(cos(angle)*.12,1.50,sin(angle)*.12)
		var middle: Vector3 = foot.lerp(top,.47)
		Geo.rod(tripod, foot, middle, .036, b.WOOD)
		Geo.rod(tripod, middle, top, .052, b.WHITE)
		Geo.rod(tripod, foot.lerp(top,.43), foot.lerp(top,.51), .067, b.TEAL)
		Geo.cylinder(tripod, .075, .035, Vector3(foot.x,.025,foot.z), b.TEAL)
		Geo.rod(tripod, foot.lerp(top,.58), Vector3(0,.85,0), .022, b.GOLD)
	Geo.cylinder(tripod, .32, .04, Vector3(0,.85,0), b.TEAL)
	Geo.cylinder(tripod, .18, .14, Vector3(0,1.52,0), b.WHITE)
	_rim(tripod, .17, .018, Vector3(0,1.60,0), b.GOLD)
	var axis: Node3D = b._group(action, "TelescopeAxis", Vector3(0,1.73,0))
	axis.rotation.y=-.2; axis.set_meta("home_dynamic",true); action.parts.append(axis)
	for side in [-1.0,1.0]:
		b._box(axis, Vector3(.065,.36,.28), Vector3(side*.23,0,0), b.WHITE, 0, .022)
		var knob: MeshInstance3D = Geo.cylinder(axis, .085, .07, Vector3(side*.31,.18,0), b.GOLD)
		knob.rotation.z=PI*.5
	Geo.rod(axis, Vector3(-.31,.18,0), Vector3(.31,.18,0), .034, b.GOLD)
	var tube: Node3D = b._group(axis,"HollowOpticalTube",Vector3(0,.18,0))
	tube.rotation.x=1.1
	_shell(tube,.22,.22,1.54,.024,Vector3(0,-.67,0),b.WHITE)
	for y in [-.62,.43]:
		_shell(tube,.24,.24,.10,.025,Vector3(0,y,0),b.DEEP)
		for side in [-1.0,1.0]:
			b._box(tube,Vector3(.04,.08,.07),Vector3(side*.24,y+.05,0),b.GOLD,0,.008)
	_shell(tube,.245,.245,.17,.027,Vector3(0,.80,0),b.DEEP)
	_rim(tube,.243,.012,Vector3(0,.975,0),b.GOLD)
	Geo.cylinder(tube,.19,.014,Vector3(0,.89,0),b.LIGHT)
	b._box(tube,Vector3(.19,.004,.018),Vector3(-.035,.902,-.045),b.WHITE,0,.003).rotation.y=-.35
	_shell(tube,.105,.105,.25,.020,Vector3(0,-.91,0),b.TEAL)
	_shell(tube,.12,.12,.09,.020,Vector3(0,-.98,0),b.DEEP)
	Geo.cylinder(tube,.085,.012,Vector3(0,-.972,0),b.LIGHT)
	Geo.rod(tube,Vector3(-.16,-.77,0),Vector3(.16,-.77,0),.020,b.GOLD)
	for side in [-1.0,1.0]:
		var focus: MeshInstance3D = Geo.cylinder(tube,.045,.04,Vector3(side*.18,-.77,0),b.DEEP)
		focus.rotation.z=PI*.5
	for y in [.10,.40]: Geo.rod(tube,Vector3(.20,y,-.10),Vector3(.32,y,-.10),.021,b.GOLD)
	_shell(tube,.065,.065,.48,.012,Vector3(.33,.02,-.10),b.BLUE)
	Geo.cylinder(tube,.049,.012,Vector3(.33,.495,-.10),b.LIGHT)
	_shell(tube,.077,.077,.055,.013,Vector3(.33,.47,-.10),b.DEEP)
	action.set_meta("optics_detail","hollow_refractor_finder_and_braced_tripod_v1")
	b._batch(tripod,false); b._batch(axis,false)

static func eyepiece_tray(b, table: Node3D) -> void:
	var tray: Node3D = b._group(table,"EyepieceStorageTray",Vector3(0,.73,.43))
	b._finish_box(tray,Vector3(.80,.035,.40),Vector3(0,.02,0),"ash_table","body",.018)
	b._box(tray,Vector3(.72,.025,.33),Vector3(0,.045,0),b.TEAL,0,.012)
	for side in [-1.0,1.0]:
		b._finish_box(tray,Vector3(.035,.11,.40),Vector3(side*.385,.085,0),"ash_table","body",.010)
		b._finish_box(tray,Vector3(.73,.11,.035),Vector3(0,.085,side*.182),"ash_table","body",.010)
	for x in [-.22,0.0,.22]:
		_shell(tray,.068,.068,.12,.014,Vector3(x,.06,0),b.DEEP)
		_rim(tray,.071,.011,Vector3(x,.165,0),b.GOLD)
		Geo.cylinder(tray,.050,.010,Vector3(x,.17,0),b.LIGHT)
	b._box(tray,Vector3(.14,.045,.018),Vector3(0,.095,.21),b.GOLD,0,.006)
	tray.set_meta("optics_detail","three_eyepiece_storage_tray_v1")

static func _rim(parent: Node3D, radius: float, thickness: float, point: Vector3, color: Color) -> void:
	var mesh:=MeshInstance3D.new(); var ring:=TorusMesh.new()
	ring.inner_radius=radius-thickness; ring.outer_radius=radius+thickness
	ring.rings=40; ring.ring_segments=8
	mesh.mesh=ring; mesh.position=point; mesh.material_override=Geo.material(color); parent.add_child(mesh)

static func _shell(parent: Node3D, bottom: float, top: float, height: float, wall: float, point: Vector3, color: Color, pleat: float=0.0) -> void:
	var key := str([bottom,top,height,wall,pleat])
	if not shells.has(key):
		var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 40:
			var a: float=i*TAU/40.0; var c: float=(i+1)*TAU/40.0
			var extra_a: float=pleat if i%2 else 0.0
			var extra_c: float=pleat if (i+1)%2 else 0.0
			var lower:=Vector3(cos(a)*(bottom+extra_a),0,sin(a)*(bottom+extra_a))
			var lower_next:=Vector3(cos(c)*(bottom+extra_c),0,sin(c)*(bottom+extra_c))
			var upper:=Vector3(cos(a)*(top+extra_a),height,sin(a)*(top+extra_a))
			var upper_next:=Vector3(cos(c)*(top+extra_c),height,sin(c)*(top+extra_c))
			var inner_lower:=lower-Vector3(cos(a),0,sin(a))*wall
			var inner_lower_next:=lower_next-Vector3(cos(c),0,sin(c))*wall
			var inner_upper:=upper-Vector3(cos(a),0,sin(a))*wall
			var inner_upper_next:=upper_next-Vector3(cos(c),0,sin(c))*wall
			var normal: Vector3=(lower_next-lower).cross(upper-lower).normalized()
			if normal.dot(Vector3(cos((a+c)*.5),0,sin((a+c)*.5)))<0:normal=-normal
			Geo._face(tool,[lower,lower_next,upper_next,upper],normal)
			Geo._face(tool,[inner_lower,inner_lower_next,inner_upper_next,inner_upper],-normal)
			Geo._face(tool,[lower,lower_next,inner_lower_next,inner_lower],Vector3.DOWN)
			Geo._face(tool,[upper,upper_next,inner_upper_next,inner_upper],Vector3.UP)
		shells[key]=tool.commit()
	var mesh:=MeshInstance3D.new(); mesh.name="OpenShell"
	mesh.mesh=shells[key]; mesh.position=point; mesh.material_override=Geo.material(color); parent.add_child(mesh)
