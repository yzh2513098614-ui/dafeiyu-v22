extends RefCounted
## Local living-room doorway joinery; existing guarded hinges keep their physics.
const Geo=preload("res://district/story_geometry.gd")
const Optics=preload("res://assets/whale_home/lighting_and_optics.gd")

static func terrace_door(b) -> void:
	for door: Node3D in b.level.get_meta("home_room_doors",[]):
		if door.state_key!="whale_home:door:living_terrace":continue
		var height: float=door.blocker.shape.size.y
		var span: float=(door.door_width-.12)*.5
		for index in 2:
			var pivot: Node3D=door.pivots[index]
			# Replace the leaf's visual mesh only, retaining its guarded collision.
			for old: MeshInstance3D in pivot.find_children("*","MeshInstance3D",true,false):
				old.get_parent().remove_child(old)
				if not old.is_queued_for_deletion():old.queue_free()
			var side: float=-1.0 if index==0 else 1.0
			var center_x: float=-side*span*.5
			var leaf: Node3D=b._group(pivot,"DividedGlassTerraceLeaf")
			for x in [center_x-span*.5+.05,center_x+span*.5-.05]:
				b._box(leaf,Vector3(.10,height,.11),Vector3(x,height*.5,0),b.TEAL,0,.018)
			for y in [.07,1.15,height-.07]:
				b._box(leaf,Vector3(span,.13,.11),Vector3(center_x,y,0),b.TEAL,0,.018)
			b._box(leaf,Vector3(span-.20,1.00,.060),Vector3(center_x,.61,0),b.WHITE,0,.022)
			b._box(leaf,Vector3(span-.36,.69,.035),Vector3(center_x,.60,.045),b.MINT,0,.014)
			b._box(leaf,Vector3(span-.36,.69,.035),Vector3(center_x,.60,-.045),b.MINT,0,.014)
			for face in [-1.0,1.0]:
				for y in [.245,.955]:
					b._box(leaf,Vector3(span-.33,.025,.020),Vector3(center_x,y,face*.067),b.WHITE,0,.005)
				for x in [center_x-(span-.33)*.5,center_x+(span-.33)*.5]:
					b._box(leaf,Vector3(.025,.71,.020),Vector3(x,.60,face*.067),b.WHITE,0,.005)
			var glass: MeshInstance3D=b._box(leaf,Vector3(span-.20,height-1.35,.018),Vector3(center_x,(height+1.08)*.5,0),b.LIGHT,0,.004)
			glass.material_override=b.glass; glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b._box(leaf,Vector3(.035,height-1.34,.075),Vector3(center_x,(height+1.08)*.5,0),b.WHITE,0,.006)
			b._box(leaf,Vector3(span-.18,.045,.075),Vector3(center_x,(height+1.08)*.5,0),b.WHITE,0,.006)
			for y in [.29,height*.50,height-.29]:
				Geo.cylinder(leaf,.044,.16,Vector3(0,y,0),b.GOLD)
			var handle_x: float=-side*(span-.16)
			for face in [-1.0,1.0]:
				b._box(leaf,Vector3(.095,.33,.018),Vector3(handle_x,.98,face*.068),b.GOLD,2,.012)
				for y in [.88,1.08]:
					Geo.rod(leaf,Vector3(handle_x,y,face*.078),Vector3(handle_x,y,face*.125),.018,b.GOLD)
					b._sphere(leaf,Vector3(handle_x,y,face*.080),Vector3(.025,.025,.008),b.WHITE)
				Geo.rod(leaf,Vector3(handle_x,.86,face*.125),Vector3(handle_x,1.10,face*.125),.022,b.GOLD)
			b._batch(pivot,false)
		var sill: Node3D=b._group(door,"FlushBrassThreshold")
		b._box(sill,Vector3(door.door_width-.10,.012,.28),Vector3(0,.027,0),b.WOOD,1,.003)
		for z in [-.08,.08]:b._box(sill,Vector3(door.door_width-.14,.004,.012),Vector3(0,.035,z),b.GOLD,0,.001)
		b._batch(sill,false)
		door.set_meta("lounge_door_revision","divided_glass_raised_panels_hinges_and_mounted_pulls_v1")

static func ottoman(b, root: Node3D) -> void:
	for x in [-.36,.36]:
		for z in [-.30,.30]:Geo.cylinder(root,.05,.10,Vector3(x,.05,z),b.WOOD,.043)
	var body:=MeshInstance3D.new()
	body.mesh=_upholstery([Vector2(.52,.10),Vector2(.62,.16),Vector2(.66,.30),Vector2(.64,.46),Vector2(.59,.49)])
	b._cloth(body,b.BLUE,1);root.add_child(body)
	var top:=MeshInstance3D.new()
	top.mesh=_upholstery([Vector2(.59,.49),Vector2(.655,.52),Vector2(.63,.565),Vector2(.48,.60),Vector2(.16,.615)],.62)
	b._cloth(top,b.LIGHT);root.add_child(top)
	Optics._rim(root,.645,.008,Vector3(0,.53,0),b.WHITE)
	Optics._rim(root,.615,.006,Vector3(0,.16,0),b.LIGHT)
	for i in 8:
		var a: float=i*TAU/8.0
		var previous:=Vector3(cos(a)*.631,.20,sin(a)*.631)
		for sample: Vector2 in [Vector2(.664,.30),Vector2(.650,.40),Vector2(.618,.48)]:
			var point:=Vector3(cos(a)*sample.x,sample.y,sin(a)*sample.x)
			Geo.rod(root,previous,point,.004,b.LIGHT);previous=point
	for x in [-.20,.20]:
		for z in [-.16,.16]:b._sphere(root,Vector3(x,.616,z),Vector3(.035,.010,.035),b.BLUE)
	for x in [-.09,.09]:b._cloth(b._box(root,Vector3(.025,.055,.024),Vector3(x,.34,.646),b.BLUE,0,.008),b.BLUE)
	b._cloth(b._box(root,Vector3(.18,.025,.025),Vector3(0,.325,.66),b.BLUE,0,.008),b.BLUE)
	root.set_meta("ottoman_model_revision","rounded_separate_cushion_piping_panel_seams_and_carry_loop_v1")

static func _upholstery(profile: Array[Vector2], top_y: float=-1.0) -> ArrayMesh:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		var a: float=i*TAU/48.0;var c: float=(i+1)*TAU/48.0
		for band in profile.size()-1:
			var p:=Vector3(cos(a)*profile[band].x,profile[band].y,sin(a)*profile[band].x)
			var q:=Vector3(cos(c)*profile[band].x,profile[band].y,sin(c)*profile[band].x)
			var r:=Vector3(cos(c)*profile[band+1].x,profile[band+1].y,sin(c)*profile[band+1].x)
			var s:=Vector3(cos(a)*profile[band+1].x,profile[band+1].y,sin(a)*profile[band+1].x)
			var normal: Vector3=(q-p).cross(s-p).normalized()
			if normal.dot(Vector3(cos((a+c)*.5),0,sin((a+c)*.5)))<0:normal=-normal
			Geo._face(tool,[p,q,r,s],normal)
		var first: Vector2=profile[0];var last: Vector2=profile[-1]
		Geo._face(tool,[Vector3(0,first.y,0),Vector3(cos(a)*first.x,first.y,sin(a)*first.x),Vector3(cos(c)*first.x,first.y,sin(c)*first.x)],Vector3.DOWN)
		Geo._face(tool,[Vector3(0,last.y if top_y<0 else top_y,0),Vector3(cos(a)*last.x,last.y,sin(a)*last.x),Vector3(cos(c)*last.x,last.y,sin(c)*last.x)],Vector3.UP)
	return tool.commit()
