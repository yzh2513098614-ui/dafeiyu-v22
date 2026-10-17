extends RefCounted
## Finishes and fitted furniture for the existing third-floor rooms.
const Geo = preload("res://district/story_geometry.gd")
const Castle = preload("res://district/whale_home_castle.gd")
const H := 10.4
const IVORY := Color("f2e8d6")
const BLUE := Color("91b0c4")
const ROSE := Color("d6b5b6")
const MINT := Color("a5c1b6")
const GOLD := Color("cbb083")
var b
var root: Node3D

static func accent(point: Vector3) -> Color:
	if point.x > -8.5:return MINT if point.z < -22.0 else BLUE
	if point.x < -13.5:return ROSE if point.z < -18.0 else MINT
	return Color("b2bdc6")

static func wall_span(builder, wall: Node3D, upper: Node3D, start: float, end: float) -> void:
	var length: float=end-start
	if length<=0:return
	var x: float=(start+end)*.5
	builder._box(wall,Vector3(length,1.15,.25),Vector3(x,.575,0),IVORY)
	builder._box(upper,Vector3(length,4.05,.25),Vector3(x,3.175,0),IVORY)
	builder._coll(wall,Vector3(length,5.2,.25),Vector3(x,2.6,0))
	for side: float in [-1.0,1.0]:
		var color: Color=accent(wall.to_global(Vector3(x,0,side*.4)))
		builder._box(wall,Vector3(length,1.07,.035),Vector3(x,.60,side*.145),color.lightened(.12))
		builder._box(upper,Vector3(length,3.95,.035),Vector3(x,3.16,side*.145),IVORY.lerp(color,.20))
		for y: float in [.12,1.12]:
			builder._box(wall,Vector3(length,.075,.075),Vector3(x,y,side*.17),IVORY)
		var count: int=maxi(1,roundi(length/1.3))
		var width: float=length/count
		for i in count:
			var px: float=start+(i+.5)*width
			for y: float in [.29,.94]:builder._box(wall,Vector3(maxf(.03,width-.22),.035,.04),Vector3(px,y,side*.18),IVORY)
			for edge: float in [-1.0,1.0]:builder._box(wall,Vector3(.035,.68,.04),Vector3(px+edge*(width-.22)*.5,.615,side*.18),IVORY)
		for spec: Vector2 in [Vector2(4.90,.09),Vector2(5.06,.15)]:
			builder._box(upper,Vector3(length,spec.y,.16),Vector3(x,spec.x,side*.17),IVORY)
		builder._box(upper,Vector3(length,.025,.025),Vector3(x,4.81,side*.19),GOLD)

static func wall_details(builder, wall: Node3D, upper: Node3D, cuts: Array) -> void:
	for spec: Array in cuts:
		var along_z: bool=absf(sin(wall.rotation.y))>.5
		var offset: float=spec[0]-(wall.position.z if along_z else wall.position.x)
		for side: float in [-1.0,1.0]:
			for edge: float in [-1.0,1.0]:
				builder._box(upper,Vector3(.18,3.02,.17),Vector3(offset+edge*(spec[1]*.5+.10),1.56,side*.20),IVORY)
				builder._box(wall,Vector3(.25,.20,.24),Vector3(offset+edge*(spec[1]*.5+.10),.12,side*.20),IVORY)
			for i in 20:
				var a: float=i*PI/20.;var c: float=(i+1)*PI/20.
				Geo.rod(upper,Vector3(offset+cos(a)*(spec[1]*.5+.10),3.02+sin(a)*.67,side*.21),Vector3(offset+cos(c)*(spec[1]*.5+.10),3.02+sin(c)*.67,side*.21),.075,IVORY)
			builder._box(upper,Vector3(.22,.28,.20),Vector3(offset,3.66,side*.22),GOLD)
	for door: Node3D in wall.get_children():
		if not door.has_meta("map_interactive_door"):continue
		for mesh: MeshInstance3D in door.find_children("*","MeshInstance3D",true,false):
			var material: StandardMaterial3D=mesh.material_override
			var color: Color=material.albedo_color
			if color.is_equal_approx(Color("476274")):color=Color("7a929e")
			elif color.is_equal_approx(Color("93b9c2")):color=accent(door.global_position).lightened(.27)
			elif color.is_equal_approx(Color("d5dfd9")):color=IVORY
			else:color=GOLD
			mesh.material_override=Geo.material(color)
	var p: Vector3=wall.position
	if is_equal_approx(p.x,-20.0):
		_window(builder,upper,Vector3(-19.82,H+1.55,-10.8),PI*.5,1.9,2.95,MINT)
	elif is_equal_approx(p.x,0.0) and absf(wall.rotation.y)>1.0:
		for z: float in [-26.2,-16.2,-10.3]:_window(builder,upper,Vector3(-.18,H+1.55,z),-PI*.5,2.0,2.95,MINT if z< -22 else BLUE)
	elif is_equal_approx(p.z,-30.0):
		_window(builder,upper,Vector3(-10.95,H+1.35,-29.82),0,2.35,3.15,BLUE)

static func _window(builder, parent: Node3D, point: Vector3, yaw: float, width: float, height: float, color: Color) -> void:
	var frame: Node3D=builder._group(parent,"SuiteArchedCasement",parent.to_local(point))
	frame.global_rotation=Vector3(0,yaw,0)
	var details:=Castle.new();details.b=builder
	details._arch_window(frame,width,height)
	# Curtains, rails and the sill all follow their wall's existing cutaway.
	for side: float in [-1.0,1.0]:
		for i in 4:
			var cloth: MeshInstance3D=builder._box(frame,Vector3(.14,height-.25,.17),Vector3(side*(width*.5+.16)+(.10*i-.15),height*.48,.17+sin(i)*.025),color,0,.045)
			builder._cloth(cloth,color,0)
		Geo.rod(frame,Vector3(side*(width*.5-.03),height*.40,.31),Vector3(side*(width*.5+.37),height*.40,.31),.025,GOLD)
	Geo.rod(frame,Vector3(-width*.5-.45,height+.16,.19),Vector3(width*.5+.45,height+.16,.19),.035,GOLD)
	for side: float in [-1.0,1.0]:builder._sphere(frame,Vector3(side*(width*.5+.48),height+.16,.19),Vector3.ONE*.13,GOLD)

func build(builder, floor_root: Node3D) -> void:
	b=builder;root=b._group(floor_root,"CastlePrivateSuite")
	# Retain the original curtain action and moving panels, while attaching
	# its window to the wall cutaway instead of leaving a freestanding frame.
	var curtain: Node3D=b.game.world.get_node("HomeAction_guest_curtain")
	var frame: Node3D=curtain.get_node("SeaViewWindow")
	for child: Node3D in curtain.get_children():
		if child!=frame:child.reparent(frame,true)
	for upper: Node3D in b.level.get_meta("home_wall_tops"):
		var wall: Node3D=upper.get_parent()
		if is_equal_approx(wall.position.x,-20.0) and is_equal_approx(float(wall.get_meta("floor_height")),H):
			frame.reparent(upper,true);break
	_wood_floor(Rect2(-19.83,-29.83,6.16,11.66))
	_wood_floor(Rect2(-19.83,-17.83,6.16,11.66))
	_wood_floor(Rect2(-8.33,-21.83,8.16,15.66))
	_bath_floor()
	_hall_floor()
	_rug(Vector2(-16.7,-24.5),Vector2(5.1,8.5),ROSE)
	_rug(Vector2(-4.25,-15.0),Vector2(6.9,10.4),BLUE)
	_rug(Vector2(-16.7,-11.5),Vector2(3.6,6.2),MINT)
	_rug(Vector2(-10.95,-23.25),Vector2(2.65,11.5),Color("90a6b8"))
	_master_bedroom()
	_guest_room()
	_bathroom()
	_wall_lamps()
	b.level.set_meta("suite_interiors_revision","castle_private_suite_v1")
	b.level.set_meta("suite_interior_rooms",["bedroom","annex_guest","bathroom","landing","tower_entry"])

func _wood_floor(rect: Rect2) -> void:
	var group: Node3D=b._group(root,"OakRoomFloor")
	b._box(group,Vector3(rect.size.x,.035,rect.size.y),Vector3(rect.get_center().x,H+.072,rect.get_center().y),Color("c7ae8b"),0,0)
	var columns: int=ceili(rect.size.x/.55)
	var width: float=rect.size.x/columns
	for col in columns:
		var cursor: float=rect.position.y
		while cursor<rect.end.y-.01:
			var length: float=minf(1.35 if is_equal_approx(cursor,rect.position.y) and col%2 else 2.70,rect.end.y-cursor)
			b._finish_box(group,Vector3(width-.012,.035,length-.018),Vector3(rect.position.x+(col+.5)*width,H+.097,cursor+length*.5),"ash_table","body",.006)
			cursor+=length
	for side: float in [-1.0,1.0]:
		b._box(group,Vector3(.12,.025,rect.size.y),Vector3(rect.get_center().x+side*(rect.size.x*.5-.08),H+.12,rect.get_center().y),GOLD)
		b._box(group,Vector3(rect.size.x,.025,.12),Vector3(rect.get_center().x,H+.12,rect.get_center().y+side*(rect.size.y*.5-.08)),GOLD)

func _bath_floor() -> void:
	var group: Node3D=b._group(root,"MintCeramicFloor")
	var width: float=8.16/8.;var depth: float=7.66/8.
	for row in 8:
		for col in 8:
			b._box(group,Vector3(width-.024,.055,depth-.024),Vector3(-8.33+(col+.5)*width,H+.10,-29.83+(row+.5)*depth),IVORY if (row+col)%2 else MINT.lightened(.26),0,.012)

func _hall_floor() -> void:
	var group: Node3D=b._group(root,"InlaidGalleryFloor")
	# Stop at the rear landing; the stairwell stays open over the lower flight.
	for row in 13:
		b._box(group,Vector3(4.66,.055,.97),Vector3(-11,H+.10,-29.5+row*.98),IVORY,0,.01)
	for x: float in [-13.14,-8.86]:b._box(group,Vector3(.08,.02,12.7),Vector3(x,H+.14,-23.5),BLUE)

func _rug(center: Vector2,size: Vector2,color: Color) -> void:
	var rug: Node3D=b._group(root,"WovenRoomRug",Vector3(center.x,H+.15,center.y))
	b._cloth(b._box(rug,Vector3(size.x,.025,size.y),Vector3.ZERO,color,0,.025),color,0)
	for side: float in [-1.0,1.0]:
		b._box(rug,Vector3(.07,.014,size.y-.18),Vector3(side*(size.x*.5-.16),.023,0),IVORY)
		b._box(rug,Vector3(size.x-.26,.014,.07),Vector3(0,.023,side*(size.y*.5-.16)),IVORY)
		for i in 12:
			Geo.rod(rug,Vector3(-size.x*.43+i*size.x*.86/11.,0,side*size.y*.5),Vector3(-size.x*.43+i*size.x*.86/11.,0,side*(size.y*.5+.11)),.012,IVORY)
	for z: float in [-size.y*.30,0.0,size.y*.30]:
		var motif: MeshInstance3D=b._box(rug,Vector3(.28,.012,.28),Vector3(0,.025,z),IVORY,0,0)
		motif.rotation.y=PI*.25

func _master_bedroom() -> void:
	var bench: Node3D=b._furniture(root,"BlueVelvetBedBench",Vector3(-4.25,H,-9.6))
	for x: float in [-1.5,1.5]:
		for z: float in [-.37,.37]:Geo.rod(bench,Vector3(x,0,z),Vector3(x*.96,.60,z),.055,GOLD)
	b._box(bench,Vector3(3.5,.18,.95),Vector3(0,.54,0),IVORY)
	b._cloth(b._box(bench,Vector3(3.4,.26,1.02),Vector3(0,.75,0),BLUE,0,.12),BLUE)
	b._coll(bench,Vector3(3.5,.9,1.02),Vector3(0,.45,0))
	b._books(bench,Vector3(.8,.94,0),3)
	# The existing dressing cabinet remains the same saved container.
	var dresser: Node3D=b._group(root,"DressingTray",Vector3(-4.25,H+1.43,-7.1))
	b._box(dresser,Vector3(1.20,.06,.55),Vector3.ZERO,IVORY)
	for x: float in [-.32,.05,.30]:
		Geo.cylinder(dresser,.09,.22,Vector3(x,.14,0),MINT if x<0 else ROSE)
		Geo.cylinder(dresser,.055,.065,Vector3(x,.28,0),GOLD)
	var left: Node3D=b._group(root,"BedsideFlowerVase",Vector3(-3.7,H+.93,-20.9))
	Geo.cylinder(left,.16,.31,Vector3(0,.16,0),IVORY,.10)
	for i in 3:b._flower(left,Vector3((i-1)*.16,.65+.05*(i%2),0),ROSE,.18)
	_wall_art(Vector3(-4.3,H+3.3,-21.80),0,Vector2(3.6,1.65),BLUE)

func _guest_room() -> void:
	var desk: Node3D=b._table(root,Vector3(-17.0,H,-18.65),2.65,.92,.92,"desk")
	b._books(desk,Vector3(-.80,1.02,0),4);b._cup(desk,Vector3(.70,1.04,0),IVORY)
	b._chair(root,Vector3(-17.0,H,-18.90),180,true)
	b._plant(root,Vector3(-18.9,H,-19.25),.55,true)
	_wall_art(Vector3(-16.7,H+3.35,-29.8),0,Vector2(3.3,1.7),ROSE)

func _bathroom() -> void:
	var shower: Node3D=b._furniture(root,"BrassWalkInShower",Vector3(-1.65,H,-23.70))
	b._box(shower,Vector3(2.35,.14,2.7),Vector3(0,.16,0),IVORY,0,.06)
	for x: float in [-1.12,1.12]:Geo.rod(shower,Vector3(x,.22,1.25),Vector3(x,3.25,1.25),.035,GOLD)
	Geo.rod(shower,Vector3(-1.12,3.25,1.25),Vector3(1.12,3.25,1.25),.035,GOLD)
	var glass: MeshInstance3D=b._box(shower,Vector3(2.20,2.9,.045),Vector3(0,1.76,1.25),MINT)
	glass.material_override=b.glass
	Geo.rod(shower,Vector3(1.03,.75,.75),Vector3(1.03,3.5,.75),.035,GOLD)
	Geo.rod(shower,Vector3(1.03,3.5,.75),Vector3(.35,3.5,.75),.035,GOLD)
	Geo.cylinder(shower,.23,.055,Vector3(.35,3.46,.75),GOLD)
	b._coll(shower,Vector3(2.35,2.9,.075),Vector3(0,1.65,1.25))
	var wc: Node3D=b._furniture(root,"PorcelainWaterCloset",Vector3(-4.05,H,-28.65))
	b._box(wc,Vector3(.94,1.15,.32),Vector3(0,.65,-.38),IVORY,0,.10)
	b._sphere(wc,Vector3(0,.50,.25),Vector3(.86,.72,1.20),IVORY)
	b._box(wc,Vector3(.82,.09,1.07),Vector3(0,.81,.25),Color("e1e8dd"),0,.16)
	b._box(wc,Vector3(.18,.055,.10),Vector3(.18,1.26,-.38),GOLD)
	b._coll(wc,Vector3(.96,1.32,1.58),Vector3(0,.66,.20))
	var rail: Node3D=b._group(root,"FoldedBathTowels",Vector3(-6.85,H+2.42,-28.8))
	for i in 3:b._cloth(b._box(rail,Vector3(1.08,.14,.65),Vector3(0,i*.145,0),IVORY if i%2 else MINT,0,.055),IVORY if i%2 else MINT)
	_rug(Vector2(-4.15,-25.80),Vector2(3.5,1.05),IVORY)

func _wall_art(point: Vector3,yaw: float,size: Vector2,color: Color) -> void:
	# Parent wall decorations to its upper section so they never hang in midair.
	var target: Node3D
	var nearest: float=1000.0
	for upper: Node3D in b.level.get_meta("home_wall_tops"):
		var wall: Node3D=upper.get_parent()
		if not is_equal_approx(float(wall.get_meta("floor_height")),H):continue
		var local: Vector3=wall.to_local(point)
		var distance: float=absf(local.z)
		if distance<nearest and absf(local.x)<15:
			nearest=distance;target=upper
	var art: Node3D=b._group(target,"FramedSeaStudy",target.to_local(point))
	art.global_rotation=Vector3(0,yaw,0)
	b._box(art,Vector3(size.x,size.y,.10),Vector3.ZERO,GOLD)
	b._box(art,Vector3(size.x-.14,size.y-.14,.035),Vector3(0,0,.07),IVORY)
	b._box(art,Vector3(size.x-.35,size.y*.34,.018),Vector3(0,-size.y*.19,.10),color)
	b._whale(art,Vector3(0,-.05,.16),.30,0,color.darkened(.1))

func _wall_lamps() -> void:
	for upper: Node3D in b.level.get_meta("home_wall_tops"):
		var wall: Node3D=upper.get_parent()
		if not is_equal_approx(float(wall.get_meta("floor_height")),H):continue
		var p: Vector3=wall.position
		if not is_equal_approx(p.x,-13.5) and not is_equal_approx(p.x,-8.5):continue
		for z: float in [-28.4,-23.3,-18.3]:
			var point:=Vector3(p.x+(.22 if p.x< -10 else -.22),H+3.35,z)
			var lamp: Node3D=b._group(upper,"BrassWallSconce",upper.to_local(point))
			lamp.global_rotation.y=PI*.5 if p.x< -10 else -PI*.5
			b._box(lamp,Vector3(.18,.48,.08),Vector3.ZERO,GOLD)
			Geo.rod(lamp,Vector3(0,-.1,.02),Vector3(0,-.1,.38),.035,GOLD)
			Geo.cylinder(lamp,.22,.34,Vector3(0,.05,.38),IVORY,.15)
			b._sphere(lamp,Vector3(0,-.12,.38),Vector3.ONE*.14,Color("ffe1a6"))
			var light:=OmniLight3D.new()
			light.position=Vector3(0,.05,.48);light.omni_range=5.0
			light.light_color=Color("ffe3b9");light.light_energy=.12;light.shadow_enabled=false
			light.set_meta("home_energy",.7);lamp.add_child(light);b.lights.append(light)
