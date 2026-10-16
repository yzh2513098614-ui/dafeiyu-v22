extends RefCounted
## The central garden entrance: a true enlarged opening and detailed joinery.
## Hinges, occupancy guards, E interaction and save keys remain the existing door's.
const Geo=preload("res://district/story_geometry.gd")
const Pastel=preload("res://assets/whale_home/pastel_props.gd")
const Finish=preload("res://assets/whale_home/furniture_finishes.gd")
const Ground=preload("res://assets/whale_home/garden_ground.gd")
const OPENING:=7.2
const WIDTH:=6.98
const HEIGHT:=4.2
const CREAM=Color("f3eedb")
const DEEP=Color("557d76")
const BRASS=Color("c6ad72")
const STONE=Color("e5dfcc")

static func build(b) -> void:
	var door: Node3D
	for candidate: Node3D in b.level.get_meta("home_room_doors",[]):
		if candidate.state_key=="whale_home:door:dining_garden":door=candidate
	if not door:return
	var wall: Node3D=door.get_parent()
	var upper: Node3D=wall.get_node("CutawayUpper")
	# Rebuild only this facade segment, retaining both live door instances.
	for child: Node in wall.get_children():
		if child==upper or child.has_meta("map_interactive_door"):continue
		_remove(child)
	for child: Node in upper.get_children():_remove(child)
	door.door_width=WIDTH;door.display_name="大肥鱼之家 · 海风大门"
	door.blocker.shape.size=Vector3(WIDTH-.09,HEIGHT,.32);door.blocker.position.y=HEIGHT*.5
	door.set_meta("home_opening_width",OPENING);door.set_meta("home_custom_frame",true)
	var span: float=(WIDTH-.12)*.5
	for index in 2:
		var side: float=-1.0 if index==0 else 1.0
		var pivot: Node3D=door.pivots[index]
		pivot.position.x=side*(WIDTH*.5-.035)
		var hit: CollisionShape3D=door.clearance.shapes[index]
		hit.shape.size=Vector3(span,HEIGHT,.32);hit.position=Vector3(-side*span*.5,HEIGHT*.5,0)
		for mesh: MeshInstance3D in pivot.find_children("*","MeshInstance3D",true,false):_remove(mesh)
		_leaf(b,pivot,side,span)
		b._batch(pivot,false)
	door._pose(door.fraction)
	var doors: Array[Node3D]=[]
	for child: Node in wall.get_children():
		if child.has_meta("map_interactive_door"):doors.append(child)
	doors.sort_custom(func(a: Node3D,c: Node3D):return a.position.x<c.position.x)
	var start: float=-float(wall.get_meta("wall_length"))*.5
	for gate: Node3D in doors:
		var opening: float=gate.get_meta("home_opening_width",3.6)
		var height: float=HEIGHT if gate==door else 2.9
		_wall_span(b,wall,upper,start,gate.position.x-opening*.5)
		var header_height: float=.54 if gate==door else .88
		b._box(upper,Vector3(opening,header_height,.26),Vector3(gate.position.x,height+header_height*.5,0),CREAM)
		b._coll(wall,Vector3(opening,header_height,.28),Vector3(gate.position.x,height+header_height*.5,0))
		if gate==door:_surround(b,wall,upper,gate.position.x)
		else:_regular_frame(b,wall,upper,gate.position.x,gate.display_name)
		start=gate.position.x+opening*.5
	_wall_span(b,wall,upper,start,float(wall.get_meta("wall_length"))*.5)
	b._batch(upper,false)
	_apron(b,door)
	door.set_meta("grand_gate_revision","seven_metre_coastal_joinery_v1")
	b.level.set_meta("grand_gate_dimensions",Vector3(OPENING,HEIGHT,5.10))
	b.level.set_meta("grand_gate",door)

static func _remove(node: Node) -> void:
	node.get_parent().remove_child(node)
	if not node.is_queued_for_deletion():node.queue_free()

static func _wall_span(b,wall: Node3D,upper: Node3D,start: float,end: float) -> void:
	if end<=start:return
	var width: float=end-start;var x: float=(start+end)*.5
	b._box(wall,Vector3(width,1.15,.24),Vector3(x,.575,0),b.WHITE)
	b._box(upper,Vector3(width,2.75,.24),Vector3(x,2.525,0),b.WHITE)
	b._box(upper,Vector3(width,.12,.34),Vector3(x,3.9,0),b.WOOD,1)
	b._coll(wall,Vector3(width,3.9,.26),Vector3(x,1.95,0))

static func _regular_frame(b,wall: Node3D,upper: Node3D,x: float,title: String) -> void:
	for side in [-1.0,1.0]:
		b._box(wall,Vector3(.12,3.02,.34),Vector3(x+side*1.74,1.51,0),b.TEAL)
		b._coll(wall,Vector3(.12,3.02,.34),Vector3(x+side*1.74,1.51,0))
	b._box(upper,Vector3(3.6,.12,.36),Vector3(x,2.96,0),b.TEAL)
	b._box(upper,Vector3(3.5,.5,.30),Vector3(x,3.32,0),b.MINT)
	for face in [-1.0,1.0]:_label(b,upper,title,Vector3(x,3.32,face*.16),face,.007)

static func _surround(b,wall: Node3D,upper: Node3D,x: float) -> void:
	var low: Node3D=b._group(wall,"GrandGateStoneBases",Vector3(x,0,0))
	var high: Node3D=b._group(upper,"GrandGateColumnsAndCornice",Vector3(x,0,0))
	for side in [-1.0,1.0]:
		var cx: float=side*3.99
		for tier: Vector3 in [Vector3(.78,.16,.11),Vector3(.70,.10,.24),Vector3(.62,.12,.35)]:
			b._box(low,Vector3(tier.x,tier.y,tier.x),Vector3(cx,tier.z,0),STONE,0,.025)
		# Split tall joinery at the room cutaway line.
		b._box(low,Vector3(.56,.74,.56),Vector3(cx,.78,0),CREAM,0,.03)
		b._box(high,Vector3(.56,2.64,.56),Vector3(cx,2.47,0),CREAM,0,.03)
		for face in [-1.0,1.0]:
			for channel in [-.18,-.09,0.0,.09,.18]:
				b._box(high,Vector3(.024,2.38,.018),Vector3(cx+channel,2.43,face*.288),b.MINT,0,.006)
			b._box(high,Vector3(.39,.055,.035),Vector3(cx,1.22,face*.29),BRASS,2,.012)
			for y in [1.36,3.50]:_rosette(b,high,Vector3(cx,y,face*.31),.10,face)
		for tier: Vector3 in [Vector3(.64,.13,3.79),Vector3(.72,.12,3.915),Vector3(.80,.15,4.05)]:
			b._box(high,Vector3(tier.x,tier.y,tier.x),Vector3(cx,tier.z,0),CREAM,0,.022)
		b._coll(wall,Vector3(.78,4.2,.78),Vector3(x+cx,2.1,0))
		_lantern(b,high,Vector3(cx,2.92,.66))
		# A framed house number and an inset bell flank the opening.
		if side>0:
			b._box(low,Vector3(.19,.29,.045),Vector3(cx,.91,.41),DEEP,0,.025)
			_disk(b,low,Vector3(cx,.94,.447),.047,.025,BRASS)
			for y in [.85,1.025]:_screw(b,low,Vector3(cx,y,.44),1.0)
		else:
			b._box(high,Vector3(.34,.24,.045),Vector3(cx,1.64,.32),DEEP,0,.028)
			_label(b,high,"01",Vector3(cx,1.64,.347),1.0,.0038)
	for tier: Vector3 in [Vector3(8.45,.16,4.24),Vector3(8.72,.13,4.385),Vector3(8.98,.09,4.495)]:
		b._box(high,Vector3(tier.x,tier.y,1.16),Vector3(0,tier.z,.25),CREAM,0,.025)
	for i in 29:
		var dx: float=-4.2+i*.30
		b._box(high,Vector3(.11,.10,.18),Vector3(dx,4.32,.85),b.MINT,0,.012)
	# Individual curved roof strips, end caps and a continuous drip edge.
	for i in 27:
		var tile:=MeshInstance3D.new();tile.mesh=Pastel.curved_tile_mesh(.325,1.40)
		tile.position=Vector3(-4.29+i*.33,4.60,.28);tile.material_override=Geo.material(b.TEAL);high.add_child(tile)
	b._box(high,Vector3(9.16,.07,.10),Vector3(0,4.615,1.00),DEEP,0,.018)
	for side in [-1.0,1.0]:
		b._box(high,Vector3(.10,.13,1.46),Vector3(side*4.5,4.62,.28),b.TEAL,0,.022)
		for dx in [-2.75,-1.55,1.55,2.75]:
			Geo.rod(high,Vector3(dx,4.02,side*.16),Vector3(dx,4.24,side*.55),.045,CREAM)
		_label(b,high,"大肥鱼之家" if side>0 else "海风前庭",Vector3(0,4.26,side*.855),side,.0085)
		for dx in [-2.65,-1.78,1.78,2.65]:_wave(b,high,Vector3(dx,4.22,side*.838),.62,.05,side,BRASS)
	_crest(b,high,Vector3(0,4.70,1.04))

static func _leaf(b,pivot: Node3D,side: float,span: float) -> void:
	var root: Node3D=b._group(pivot,"GrandCarvedOakLeaf")
	var cx: float=-side*span*.5
	for edge in [-1.0,1.0]:_wood(b,root,Vector3(.19,HEIGHT,.22),Vector3(cx+edge*(span-.19)*.5,HEIGHT*.5,0))
	for row: Vector2 in [Vector2(.13,.24),Vector2(1.98,.20),Vector2(4.08,.24)]:_wood(b,root,Vector3(span,row.y,.22),Vector3(cx,row.x,0))
	_wood(b,root,Vector3(span-.30,1.76,.15),Vector3(cx,1.09,0))
	var rx: float=(span-.58)*.5
	var opening: PackedVector2Array=PackedVector2Array([Vector2(-rx,2.06),Vector2(rx,2.06)])
	for i in 33:
		var a: float=i*PI/32.0;opening.append(Vector2(cos(a)*rx,3.14+sin(a)*.70))
	var pane:=MeshInstance3D.new();pane.name="ArchedClearGlass";pane.mesh=Pastel.prism(opening,.024)
	pane.position.x=cx;pane.material_override=b.glass;pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(pane)
	# Solid shoulders follow the arched glazing rather than covering it.
	for i in 32:
		var a: float=i*PI/32.0;var c: float=(i+1)*PI/32.0
		var points:=PackedVector2Array([Vector2(cos(a)*(rx+.12),3.14+sin(a)*.82),Vector2(cos(c)*(rx+.12),3.14+sin(c)*.82),Vector2(cos(c)*(rx+.12),4.08),Vector2(cos(a)*(rx+.12),4.08)])
		var piece:=MeshInstance3D.new();piece.mesh=Pastel.prism(points,.18);piece.position.x=cx;piece.material_override=Geo.material(DEEP);root.add_child(piece)
	for face in [-1.0,1.0]:
		for panel_side in [-1.0,1.0]:
			var panel_x: float=cx+panel_side*(span-.38)*.25
			var panel_size:=Vector2((span-.66)*.5,1.28)
			b._box(root,Vector3(panel_size.x,panel_size.y,.035),Vector3(panel_x,1.10,face*.099),DEEP,0,.035)
			b._box(root,Vector3(panel_size.x-.15,panel_size.y-.15,.025),Vector3(panel_x,1.10,face*.126),b.MINT,0,.04)
			_frame(b,root,Vector3(panel_x,1.10,face*.145),panel_size,.045,.026,CREAM)
			_frame(b,root,Vector3(panel_x,1.10,face*.16),panel_size-Vector2.ONE*.14,.014,.014,BRASS)
			_wave(b,root,Vector3(panel_x,.74,face*.17),panel_size.x-.30,.055,face,BRASS)
			_rosette(b,root,Vector3(panel_x,1.40,face*.167),.13,face)
		for dx in [-rx-.055,rx+.055]:b._box(root,Vector3(.11,1.16,.055),Vector3(cx+dx,2.63,face*.11),CREAM,0,.014)
		b._box(root,Vector3(rx*2+.20,.10,.055),Vector3(cx,2.06,face*.11),CREAM,0,.014)
		_arch(b,root,Vector3(cx,3.14,face*.115),rx,.70,.12,.055,CREAM)
		_arch(b,root,Vector3(cx,3.14,face*.151),rx+.027,.727,.016,.018,BRASS)
		for dx in [-rx*.5,0.0,rx*.5]:b._box(root,Vector3(.035,1.12,.065),Vector3(cx+dx,2.60,face*.04),BRASS,2,.006)
		b._box(root,Vector3(rx*2,.045,.065),Vector3(cx,3.14,face*.04),BRASS,2,.006)
		for i in range(1,6):
			var a: float=i*PI/6.0
			Geo.rod(root,Vector3(cx,3.14,face*.04),Vector3(cx+cos(a)*rx,3.14+sin(a)*.70,face*.04),.016,BRASS)
		# Satin kick plate and a line of real round-head fixings.
		b._box(root,Vector3(span-.34,.18,.025),Vector3(cx,.24,face*.13),BRASS,2,.022)
		for i in 7:_screw(b,root,Vector3(cx-(span-.52)*.5+i*(span-.52)/6.0,.24,face*.148),face)
		_hardware(b,root,-side*(span-.28),face)
		# A separate ring knocker on each carved leaf.
		_disk(b,root,Vector3(cx,1.72,face*.17),.09,.045,BRASS)
		var knocker:=MeshInstance3D.new();knocker.mesh=Pastel.ring_mesh(.105,.139,.027)
		knocker.position=Vector3(cx,1.58,face*.203);knocker.material_override=Geo.material(BRASS,2);root.add_child(knocker)
	for y in [.45,1.52,2.70,3.80]:
		for i in 5:
			var pin:=Geo.cylinder(root,.058,.057,Vector3(0,y+(i-2)*.06,0),BRASS if i%2 else CREAM)
			pin.material_override=Geo.material(BRASS if i%2 else CREAM,2 if i%2 else 0)
		for end in [-1.0,1.0]:b._sphere(root,Vector3(0,y+end*.18,0),Vector3(.13,.065,.13),BRASS)
		for face in [-1.0,1.0]:
			b._box(root,Vector3(.18,.24,.025),Vector3(-side*.12,y,face*.12),BRASS,2,.018)
			for end in [-1.0,1.0]:_screw(b,root,Vector3(-side*.12,y+end*.075,face*.14),face)
	if side<0:b._box(root,Vector3(.065,4.10,.035),Vector3(span-.035,2.10,.14),DEEP,0,.008)
	root.set_meta("joinery","raised_panels_fanlight_fanbars_hinges_ring_knocker_and_lock")

static func _wood(b,root: Node3D,size: Vector3,point: Vector3) -> void:
	var panel: MeshInstance3D=b._box(root,size,point,b.TEAL,0,.028)
	Finish.apply(panel,size,.028,"cabinet","body")

static func _hardware(b,root: Node3D,x: float,face: float) -> void:
	b._box(root,Vector3(.16,1.08,.034),Vector3(x,1.53,face*.15),BRASS,2,.035)
	for y in [1.10,1.96]:
		_screw(b,root,Vector3(x,y,face*.175),face)
	for y in [1.30,1.88]:
		Geo.rod(root,Vector3(x,y,face*.17),Vector3(x,y,face*.29),.033,BRASS)
		_disk(b,root,Vector3(x,y,face*.184),.052,.028,CREAM)
	Geo.rod(root,Vector3(x,1.26,face*.29),Vector3(x,1.92,face*.29),.035,BRASS)
	_disk(b,root,Vector3(x,1.11,face*.199),.048,.022,DEEP)
	b._sphere(root,Vector3(x,1.12,face*.214),Vector3(.028,.029,.009),CREAM)
	b._box(root,Vector3(.015,.038,.008),Vector3(x,1.097,face*.218),CREAM,0,.003)

static func _frame(b,root: Node3D,p: Vector3,size: Vector2,width: float,depth: float,color: Color) -> void:
	for side in [-1.0,1.0]:
		b._box(root,Vector3(size.x,width,depth),p+Vector3(0,side*(size.y-width)*.5,0),color,0,.008)
		b._box(root,Vector3(width,size.y-width*2,depth),p+Vector3(side*(size.x-width)*.5,0,0),color,0,.008)

static func _arch(b,root: Node3D,p: Vector3,rx: float,ry: float,width: float,depth: float,color: Color) -> void:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a: float=i*PI/40.0;var c: float=(i+1)*PI/40.0
		var outline:=PackedVector2Array([Vector2(cos(a)*rx,sin(a)*ry),Vector2(cos(c)*rx,sin(c)*ry),Vector2(cos(c)*(rx+width),sin(c)*(ry+width)),Vector2(cos(a)*(rx+width),sin(a)*(ry+width))])
		var piece: ArrayMesh=Pastel.prism(outline,depth)
		tool.append_from(piece,0,Transform3D.IDENTITY)
	var node:=MeshInstance3D.new();node.mesh=tool.commit();node.position=p;node.material_override=Geo.material(color);root.add_child(node)

static func _disk(b,root: Node3D,p: Vector3,radius: float,depth: float,color: Color) -> void:
	var disk:=Geo.cylinder(root,radius,depth,p,color);disk.rotation.x=PI*.5;disk.material_override=Geo.material(color,2 if color==BRASS else 0)

static func _screw(b,root: Node3D,p: Vector3,face: float) -> void:
	_disk(b,root,p,.017,.009,BRASS)
	b._box(root,Vector3(.022,.004,.003),p+Vector3(0,0,face*.006),DEEP,0,.001)

static func _wave(b,root: Node3D,p: Vector3,width: float,height: float,face: float,color: Color) -> void:
	var previous: Vector3=p+Vector3(-width*.5,0,0)
	for i in 24:
		var t: float=(i+1)/24.0
		var point: Vector3=p+Vector3((t-.5)*width,sin(t*TAU*2)*height,0)
		Geo.rod(root,previous,point,.010,color);previous=point

static func _rosette(b,root: Node3D,p: Vector3,radius: float,face: float) -> void:
	_disk(b,root,p,radius*.53,.024,BRASS)
	for i in 8:
		var angle: float=i*TAU/8.0
		var petal: MeshInstance3D=b._sphere(root,p+Vector3(cos(angle)*radius*.68,sin(angle)*radius*.68,face*.014),Vector3(radius*.65,radius*.32,.025),CREAM)
		petal.rotation.z=angle

static func _lantern(b,root: Node3D,p: Vector3) -> void:
	var lamp: Node3D=b._group(root,"GrandGateGlazedLantern_Left" if p.x<0 else "GrandGateGlazedLantern_Right",p)
	b._box(lamp,Vector3(.24,.43,.055),Vector3(0,-.15,-.35),DEEP,0,.04)
	Geo.rod(lamp,Vector3(0,-.15,-.35),Vector3(0,.17,0),.042,BRASS)
	for y in [-.40,.20]:b._box(lamp,Vector3(.42,.07,.38),Vector3(0,y,0),DEEP,2,.028)
	for dx in [-.18,.18]:
		for z in [-.16,.16]:Geo.rod(lamp,Vector3(dx,-.38,z),Vector3(dx,.20,z),.022,BRASS)
	var glass: MeshInstance3D=b._box(lamp,Vector3(.34,.53,.28),Vector3(0,-.10,0),b.LIGHT)
	glass.material_override=b.glass;glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bulb: MeshInstance3D=b._sphere(lamp,Vector3(0,-.15,0),Vector3(.18,.25,.18),Color("fff0c8"))
	var glow:=StandardMaterial3D.new();glow.albedo_color=Color("fff0c8");glow.emission_enabled=true;glow.emission=Color("ffd599");glow.emission_energy_multiplier=.30;bulb.material_override=glow
	var cap:=MeshInstance3D.new();cap.mesh=Pastel.prism(PackedVector2Array([Vector2(-.25,.22),Vector2(0,.43),Vector2(.25,.22)]),.42);cap.material_override=Geo.material(DEEP);lamp.add_child(cap)
	b._sphere(lamp,Vector3(0,.46,0),Vector3(.085,.11,.085),BRASS)
	var light:=OmniLight3D.new();light.position=Vector3(0,-.1,.12);light.omni_range=4.5;light.light_color=Color("ffe7b5");light.light_energy=.07;light.shadow_enabled=false;light.set_meta("home_energy",.6);lamp.add_child(light);b.lights.append(light)

static func _crest(b,root: Node3D,p: Vector3) -> void:
	var badge: Node3D=b._group(root,"WhaleReliefCrest",p)
	var disk:=Geo.cylinder(badge,.40,.06,Vector3.ZERO,DEEP);disk.rotation.x=PI*.5;disk.scale.x=2.15
	var rim:=MeshInstance3D.new();rim.mesh=Pastel.ring_mesh(.37,.40,.025);rim.scale.x=2.15;rim.position.z=.042;rim.material_override=Geo.material(BRASS,2);badge.add_child(rim)
	var outline:=PackedVector2Array([Vector2(-.60,-.04),Vector2(-.57,.10),Vector2(-.42,.20),Vector2(-.16,.23),Vector2(.13,.16),Vector2(.36,.01),Vector2(.53,.10),Vector2(.65,.20),Vector2(.67,.05),Vector2(.58,-.04),Vector2(.70,-.14),Vector2(.56,-.19),Vector2(.38,-.09),Vector2(.19,-.16),Vector2(-.17,-.18),Vector2(-.45,-.14)])
	var whale:=MeshInstance3D.new();whale.mesh=Pastel.prism(outline,.06);whale.position=Vector3(0,.015,.07);whale.material_override=Geo.material(BRASS,2);badge.add_child(whale)
	b._sphere(badge,Vector3(-.40,.09,.109),Vector3(.040,.040,.014),DEEP)
	_wave(b,badge,Vector3(-.05,-.225,.09),1.15,.032,1.0,CREAM)
	for side in [-1.0,1.0]:
		b._star(badge,Vector3(side*.73,0,.08),.17)

static func _label(b,root: Node3D,text: String,p: Vector3,face: float,pixel_size: float) -> void:
	var label:=Label3D.new();label.text=text;label.font=b.game._game_font();label.font_size=48;label.pixel_size=pixel_size;label.outline_size=0;label.modulate=CREAM;label.position=p;label.rotation.y=0 if face>0 else PI;root.add_child(label)

static func _apron(b,door: Node3D) -> void:
	Ground.path(b.level.get_node("Island"),Rect2(-.3,8.2,7.6,4.8),"GrandGateStoneApron")
	var root: Node3D=b._group(b.floors[0],"GrandGateFlushThreshold",door.global_position)
	b._box(root,Vector3(7.2,.016,.52),Vector3(0,.032,0),STONE,0,.006)
	for z in [-.18,.18]:b._box(root,Vector3(7.10,.006,.025),Vector3(0,.044,z),BRASS,2,.002)
	for x in [-3.50,3.50]:b._box(root,Vector3(.11,.014,4.40),Vector3(x,.038,2.75),DEEP,0,.004)
	for z in [.55,4.95]:b._box(root,Vector3(7.10,.014,.11),Vector3(0,.038,z),DEEP,0,.004)
	for i in 13:
		var x: float=-3.0+i*.50
		b._box(root,Vector3(.018,.005,.18),Vector3(x,.041,.43),BRASS,2,.001)
	root.set_meta("floor_decoration_only",true)
