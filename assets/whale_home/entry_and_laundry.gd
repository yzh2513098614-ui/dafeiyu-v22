extends RefCounted
## Close-up joinery, garment silhouettes, open weave and a perforated drum.
const Geo = preload("res://district/story_geometry.gd")
const Soft = preload("res://assets/whale_home/beds.gd")
const Optics = preload("res://assets/whale_home/lighting_and_optics.gd")
static var shoe_upper: ArrayMesh
static var shoe_sole: ArrayMesh
static var drum_mesh: ArrayMesh
static var woven_mesh: ArrayMesh

static func shoe_bench(b, bench: Node3D) -> void:
	for x in [-1.68,1.68]:
		for z in [-.42,.42]: b._finish_box(bench,Vector3(.12,.14,.12),Vector3(x,.07,z),"cream_cabinet","body",.018)
	b._finish_box(bench,Vector3(3.70,.09,1.04),Vector3(0,.145,0),"cream_cabinet","body",.018)
	b._finish_box(bench,Vector3(3.64,.46,.07),Vector3(0,.37,-.485),"cream_cabinet","back",.014)
	for x in [-1.84,-.615,.615,1.84]:
		b._finish_box(bench,Vector3(.10,.45,1.04),Vector3(x,.375,0),"cream_cabinet","body",.018)
	b._finish_box(bench,Vector3(3.8,.10,1.10),Vector3(0,.60,0),"cream_cabinet","top",.028)
	for i in 3:
		var x: float=(i-1)*1.23
		Soft._puff(b,bench,Vector3(x,.72,0),Vector3(1.18,.15,1.02),b.BLUE,true)
		for side in [-1.0,1.0]:
			var shoe: Node3D=b._group(bench,"OpenCollarHouseShoe",Vector3(x+side*.23,.195,.08))
			shoe.rotation.y=side*.08
			_shoe(b,shoe,b.LIGHT if i%2 else b.SAKURA)
		for side in [-1.0,1.0]:
			b._finish_box(bench,Vector3(.055,.34,.07),Vector3(x+side*.53,.38,.515),"cream_cabinet","body",.008)
		b._box(bench,Vector3(.18,.055,.018),Vector3(x,.55,.562),b.GOLD,0,.005)
		b._box(bench,Vector3(.12,.025,.008),Vector3(x,.55,.576),b.WHITE,0,.002)
	bench.set_meta("household_detail","open_cubby_bench_piped_seats_and_six_shoes_v1")

static func coat_tree(b, rack: Node3D) -> void:
	Geo.cylinder(rack,.40,.09,Vector3(0,.05,0),b.WHITE)
	Optics._rim(rack,.345,.014,Vector3(0,.10,0),b.GOLD)
	Geo.rod(rack,Vector3(0,.1,0),Vector3(0,2.50,0),.045,b.GOLD)
	for y in [.15,1.05,2.13]: Geo.cylinder(rack,.065,.045,Vector3(0,y,0),b.TEAL)
	for i in 4:
		var a: float=i*PI*.5
		var end:=Vector3(cos(a)*.36,2.35,sin(a)*.36)
		Geo.rod(rack,Vector3(0,2.15,0),end,.030,b.GOLD)
		b._sphere(rack,end,Vector3.ONE*.085,b.WHITE)
	var coat: Node3D=b._group(rack,"HangeredSeaCoat",Vector3(.22,2.10,.04))
	var outline:=PackedVector2Array([Vector2(-.08,0),Vector2(-.16,-.025),Vector2(-.36,-.14),Vector2(-.30,-.55),Vector2(-.20,-.50),Vector2(-.18,-.28),Vector2(-.24,-.95),Vector2(.24,-.95),Vector2(.18,-.28),Vector2(.20,-.50),Vector2(.30,-.55),Vector2(.36,-.14),Vector2(.16,-.025),Vector2(.08,0),Vector2(0,-.08)])
	var garment:=MeshInstance3D.new(); garment.mesh=Soft._panel(outline,.08); b._cloth(garment,b.BLUE); coat.add_child(garment)
	for side in [-1.0,1.0]:
		Geo.rod(coat,Vector3(0,.07,0),Vector3(side*.23,-.10,0),.012,b.GOLD)
		Geo.rod(coat,Vector3(side*.23,-.10,0),Vector3(0,-.10,0),.012,b.GOLD)
		var lapel:=PackedVector2Array([Vector2(side*.025,-.08),Vector2(side*.13,-.035),Vector2(side*.16,-.22),Vector2(side*.055,-.31)])
		var collar:=MeshInstance3D.new(); collar.mesh=Soft._panel(lapel,.020); collar.position.z=.055; b._cloth(collar,b.LIGHT); coat.add_child(collar)
		b._cloth(b._box(coat,Vector3(.13,.16,.025),Vector3(side*.14,-.67,.055),b.BLUE,0,.014),b.BLUE)
		b._cloth(b._box(coat,Vector3(.145,.035,.035),Vector3(side*.14,-.575,.065),b.LIGHT,0,.008),b.LIGHT)
		Geo.rod(coat,Vector3(side*.14-.045,-.72,.073),Vector3(side*.14+.045,-.72,.073),.0045,b.LIGHT)
		var cuff: MeshInstance3D=b._box(coat,Vector3(.10,.055,.035),Vector3(side*.285,-.49,.05),b.LIGHT,0,.010)
		cuff.rotation.z=side*-.20; b._cloth(cuff,b.LIGHT)
	b._cloth(b._box(coat,Vector3(.025,.79,.020),Vector3(0,-.53,.052),b.LIGHT,0,.004),b.LIGHT)
	for i in 5:
		var button: MeshInstance3D=Geo.cylinder(coat,.012,.012,Vector3(0,-.24-i*.13,.068),b.GOLD)
		button.rotation.x=PI*.5
	Geo.rod(coat,Vector3(-.20,-.90,.052),Vector3(.20,-.90,.052),.005,b.LIGHT)
	Geo.rod(coat,Vector3(0,.07,0),Vector3(0,.14,0),.010,b.GOLD)
	var last:=Vector3(0,.14,0)
	for i in range(1,13):
		var a: float=PI-i*PI/12.0
		var point:=Vector3(.055+cos(a)*.055,.14+sin(a)*.055,0)
		Geo.rod(coat,last,point,.010,b.GOLD); last=point
	Geo.cylinder(rack,.28,.05,Vector3(0,2.60,0),b.WOOD)
	Geo.cylinder(rack,.15,.16,Vector3(0,2.705,0),b.WOOD,.13)
	Geo.cylinder(rack,.153,.036,Vector3(0,2.65,0),b.TEAL,.15)
	Optics._rim(rack,.270,.010,Vector3(0,2.626,0),b.WHITE)
	var tray: Node3D=b._group(rack,"UmbrellaDripTray",Vector3(-.22,.11,.18))
	Geo.cylinder(tray,.14,.025,Vector3.ZERO,b.TEAL)
	Optics._rim(tray,.139,.010,Vector3(0,.015,0),b.GOLD)
	var umbrella: Node3D=b._group(tray,"PleatedFoldedUmbrella",Vector3(0,.02,0))
	umbrella.rotation.z=.04
	_umbrella(b,umbrella)
	rack.set_meta("household_detail","coat_lapels_pockets_buttons_hanger_and_folded_umbrella_v1")

static func washer(b, laundry: Node3D) -> void:
	b._box(laundry,Vector3(1.55,1.53,.07),Vector3(0,.78,-.595),b.LIGHT,0,.045)
	for x in [-.725,.725]: b._box(laundry,Vector3(.10,1.45,1.21),Vector3(x,.78,0),b.LIGHT,0,.045)
	for y in [.06,1.50]: b._box(laundry,Vector3(1.50,.09,1.28),Vector3(0,y,0),b.WHITE,0,.035)
	for x in [-.58,.58]:
		for z in [-.45,.45]: Geo.cylinder(laundry,.055,.05,Vector3(x,.025,z),b.TEAL)
	var front:=MeshInstance3D.new(); front.mesh=_aperture_plate(); front.material_override=Geo.material(b.WHITE)
	front.position=Vector3(0,.74,.63); laundry.add_child(front)
	var drum: Node3D=b._group(laundry,"PerforatedInnerDrum",Vector3(0,.74,.62))
	if not drum_mesh: drum_mesh=_perforated_drum()
	var steel:=MeshInstance3D.new(); steel.mesh=drum_mesh; steel.material_override=Geo.material(b.LIGHT,2); drum.add_child(steel)
	var backing:=MeshInstance3D.new(); var barrel:=CylinderMesh.new()
	barrel.top_radius=.370; barrel.bottom_radius=.370; barrel.height=.66; barrel.radial_segments=48
	backing.mesh=barrel; backing.material_override=Geo.material(b.TEAL); backing.rotation.x=PI*.5; backing.position.z=-.33
	backing.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The backing barrel's front cap is omitted so it cannot seal the cavity.
	barrel.cap_top=false; barrel.cap_bottom=false; barrel.flip_faces=true; drum.add_child(backing)
	var rear: MeshInstance3D=Geo.cylinder(drum,.35,.018,Vector3(0,0,-.65),b.LIGHT)
	rear.rotation.x=PI*.5
	for i in 3:
		var a: float=i*TAU/3.0+.35
		var paddle: MeshInstance3D=b._box(drum,Vector3(.065,.06,.46),Vector3(cos(a)*.315,sin(a)*.315,-.32),b.WHITE,0,.018)
		paddle.rotation.z=a-PI*.5
	# Turn the two annular seals into the vertical front plane.
	var seal: Node3D=b._group(laundry,"DoorSealAndBezel",Vector3(0,.74,.695)); seal.rotation.x=PI*.5
	Optics._rim(seal,.368,.019,Vector3.ZERO,b.TEAL)
	Optics._rim(seal,.430,.040,Vector3.ZERO,b.WHITE)
	var glass: MeshInstance3D=b._sphere(laundry,Vector3(0,.74,.707),Vector3(.66,.66,.08),b.LIGHT)
	glass.material_override=b.glass; glass.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [.56,.92]:
		b._box(laundry,Vector3(.075,.075,.065),Vector3(-.41,y,.70),b.LIGHT,0,.010)
		Geo.cylinder(laundry,.017,.10,Vector3(-.44,y,.72),b.GOLD)
	for y in [.64,.83]: Geo.rod(laundry,Vector3(.40,y,.70),Vector3(.43,y,.755),.022,b.GOLD)
	Geo.rod(laundry,Vector3(.43,.62,.755),Vector3(.43,.85,.755),.027,b.WHITE)
	b._box(laundry,Vector3(1.43,.27,.045),Vector3(0,1.30,.645),b.LIGHT,0,.018)
	b._box(laundry,Vector3(.48,.135,.025),Vector3(-.43,1.31,.680),b.WHITE,0,.012)
	b._box(laundry,Vector3(.28,.020,.030),Vector3(-.43,1.275,.700),b.GOLD,0,.006)
	var dial: MeshInstance3D=Geo.cylinder(laundry,.088,.045,Vector3(.09,1.30,.693),b.WHITE)
	dial.rotation.x=PI*.5
	for i in 12:
		var a: float=i*TAU/12.0
		b._sphere(laundry,Vector3(.09+cos(a)*.112,1.30+sin(a)*.112,.681),Vector3(.012,.012,.007),b.TEAL)
	b._box(laundry,Vector3(.008,.040,.010),Vector3(.09,1.343,.721),b.GOLD,0,.002)
	b._box(laundry,Vector3(.27,.12,.025),Vector3(.48,1.31,.680),b.TEAL,0,.008)
	_display_digit(b,laundry,Vector3(.43,1.31,.697),[1,2,5,6])
	_display_digit(b,laundry,Vector3(.53,1.31,.697),[0,1,2,3,4,5])
	b._box(laundry,Vector3(.23,.16,.018),Vector3(.49,.17,.655),b.WHITE,0,.016)
	var filter: MeshInstance3D=Geo.cylinder(laundry,.044,.016,Vector3(.49,.17,.675),b.LIGHT)
	filter.rotation.x=PI*.5
	b._box(laundry,Vector3(.045,.008,.008),Vector3(.49,.17,.689),b.TEAL,0,.002)
	for i in 3:
		var color: Color=b.WHITE if i%2 else b.BLUE
		Soft._puff(b,laundry,Vector3(0,1.60+i*.105,0),Vector3(1.12,.09,.66),color,true)
		b._cloth(b._box(laundry,Vector3(1.03,.020,.055),Vector3(0,1.60+i*.105,.29),color,0,.006),color,1)
		b._box(laundry,Vector3(.085,.025,.020),Vector3(.39,1.60+i*.105,.325),b.WHITE,0,.003)
	var detergent: Node3D=b._group(laundry,"LabeledDetergentPump",Vector3(.61,1.55,-.43))
	Geo.cylinder(detergent,.075,.20,Vector3(0,.10,0),b.MINT,.065)
	Geo.cylinder(detergent,.025,.055,Vector3(0,.228,0),b.GOLD)
	b._box(detergent,Vector3(.13,.025,.035),Vector3(.025,.27,0),b.WHITE,0,.006)
	b._box(detergent,Vector3(.08,.075,.014),Vector3(0,.11,.073),b.WHITE,0,.005)
	laundry.set_meta("household_detail","perforated_drum_seal_hinges_display_filter_and_folded_towels_v1")

static func cushion_basket(b, basket: Node3D) -> void:
	Geo.cylinder(basket,.49,.035,Vector3(0,.027,0),b.WOOD,.49)
	for i in 24:
		var a: float=i*TAU/24.0
		Geo.rod(basket,Vector3(cos(a)*.49,.04,sin(a)*.49),Vector3(cos(a)*.55,.58,sin(a)*.55),.009,b.WOOD)
	if not woven_mesh: woven_mesh=_woven_bands()
	var weave:=MeshInstance3D.new(); weave.mesh=woven_mesh; weave.material_override=Geo.material(b.WHITE); basket.add_child(weave)
	Optics._rim(basket,.49,.018,Vector3(0,.05,0),b.WOOD)
	Optics._rim(basket,.55,.022,Vector3(0,.59,0),b.WOOD)
	for side in [-1.0,1.0]:
		var previous:=Vector3(side*.525,.51,.14)
		for i in range(1,17):
			var a: float=i*PI/16.0
			var point:=Vector3(side*.525,.51+sin(a)*.20,cos(a)*.14)
			Geo.rod(basket,previous,point,.018,b.WOOD); previous=point
	Soft._puff(b,basket,Vector3(0,.55,.12),Vector3(.66,.30,.44),b.BLUE,true)
	for i in 2:
		var roll: Node3D=b._group(basket,"SpiralRolledTowel",Vector3(-.17+i*.34,.28,-.28))
		var color: Color=b.MINT if i else b.SAKURA
		var cloth: MeshInstance3D=Geo.cylinder(roll,.105,.39,Vector3(0,.195,0),color)
		b._cloth(cloth,color,1)
		var previous:=Vector3(.012,.396,0)
		for step in range(1,65):
			var a: float=step*TAU*2.5/64.0; var radius: float=.012+.084*step/64.0
			var point:=Vector3(cos(a)*radius,.396,sin(a)*radius)
			Geo.rod(roll,previous,point,.005,b.WHITE); previous=point
	b._star(basket,Vector3(0,.40,.537),.20,b.GOLD)
	basket.set_meta("household_detail","open_over_under_weave_handles_pillow_and_spiral_towels_v1")

static func _shoe(b, root: Node3D, color: Color) -> void:
	if not shoe_upper:
		var upper:=SurfaceTool.new(); upper.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sole:=SurfaceTool.new(); sole.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 32:
			var a: float=i*TAU/32.0; var c: float=(i+1)*TAU/32.0
			var rings_a: Array[Vector3]=_shoe_profile(a)
			var rings_c: Array[Vector3]=_shoe_profile(c)
			for band in 4:
				var normal: Vector3=(rings_c[band]-rings_a[band]).cross(rings_a[band+1]-rings_a[band]).normalized()
				var target:=Vector3(sin((a+c)*.5),0,cos((a+c)*.5))*(1.0 if band<3 else -1.0)
				if band==2:target=Vector3.UP
				if normal.dot(target)<0:normal=-normal
				Geo._face(upper,[rings_a[band],rings_c[band],rings_c[band+1],rings_a[band+1]],normal)
			Geo._face(upper,[Vector3(0,.047,-.07),rings_a[4],rings_c[4]],Vector3.UP)
			var low_a:=Vector3(rings_a[0].x,0,rings_a[0].z)
			var low_c:=Vector3(rings_c[0].x,0,rings_c[0].z)
			Geo._face(sole,[low_a,low_c,rings_c[0],rings_a[0]],Vector3(sin((a+c)*.5),0,cos((a+c)*.5)))
			Geo._face(sole,[Vector3.ZERO,low_a,low_c],Vector3.DOWN)
			Geo._face(sole,[Vector3(0,.025,0),rings_a[0],rings_c[0]],Vector3.UP)
		shoe_upper=upper.commit(); shoe_sole=sole.commit()
	for spec in [[shoe_upper,color],[shoe_sole,b.WHITE]]:
		var mesh:=MeshInstance3D.new(); mesh.mesh=spec[0]; mesh.material_override=Geo.material(spec[1]); root.add_child(mesh)
	b._box(root,Vector3(.18,.015,.035),Vector3(0,.151,-.015),color,0,.006)
	b._box(root,Vector3(.025,.020,.045),Vector3(.085,.153,-.015),b.GOLD,0,.004)

static func _shoe_profile(a: float) -> Array[Vector3]:
	var toe: float=cos(a)
	var x: float=sin(a)*.12*(.85+.15*toe)
	var z: float=toe*.245
	return [Vector3(x,.025,z),Vector3(x*.96,.09+.045*(.5-.5*toe),z*.94),Vector3(sin(a)*.082,.15,-.07+toe*.115),Vector3(sin(a)*.063,.145,-.07+toe*.09),Vector3(sin(a)*.054,.047,-.07+toe*.08)]

static func _umbrella(b, root: Node3D) -> void:
	Geo.rod(root,Vector3(0,0,0),Vector3(0,1.12,0),.012,b.GOLD)
	var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2]=[Vector2(.012,.04),Vector2(.10,.20),Vector2(.075,.72),Vector2(.020,.91)]
	for i in 16:
		var a: float=i*TAU/16.0; var c: float=(i+1)*TAU/16.0
		for row in 3:
			var f: float=.70 if i%2 else 1.0
			var g: float=.70 if (i+1)%2 else 1.0
			var p:=Vector3(cos(a)*profile[row].x*f,profile[row].y,sin(a)*profile[row].x*f)
			var q:=Vector3(cos(c)*profile[row].x*g,profile[row].y,sin(c)*profile[row].x*g)
			var r:=Vector3(cos(c)*profile[row+1].x*g,profile[row+1].y,sin(c)*profile[row+1].x*g)
			var s:=Vector3(cos(a)*profile[row+1].x*f,profile[row+1].y,sin(a)*profile[row+1].x*f)
			var normal: Vector3=(q-p).cross(s-p).normalized()
			if normal.dot(Vector3(cos(a),0,sin(a)))<0:normal=-normal
			Geo._face(tool,[p,q,r,s],normal)
	var cloth:=MeshInstance3D.new(); cloth.mesh=tool.commit(); b._cloth(cloth,b.BLUE,1); root.add_child(cloth)
	Optics._rim(root,.086,.010,Vector3(0,.46,0),b.WHITE)
	var previous:=Vector3(0,1.12,0)
	for i in range(1,17):
		var a: float=PI-i*PI/16.0
		var point:=Vector3(.055+cos(a)*.055,1.12+sin(a)*.055,0)
		Geo.rod(root,previous,point,.019,b.WOOD); previous=point
	Geo.rod(root,previous,previous-Vector3.UP*.09,.019,b.WOOD)

static func _aperture_plate() -> ArrayMesh:
	var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		var a: float=i*TAU/64.0; var c: float=(i+1)*TAU/64.0
		var ra: float=minf(.72/maxf(absf(cos(a)),.0001),.70/maxf(absf(sin(a)),.0001))
		var rc: float=minf(.72/maxf(absf(cos(c)),.0001),.70/maxf(absf(sin(c)),.0001))
		var inner_a:=Vector3(cos(a)*.355,sin(a)*.355,0)
		var inner_c:=Vector3(cos(c)*.355,sin(c)*.355,0)
		Geo._face(tool,[inner_a,inner_c,Vector3(cos(c)*rc,sin(c)*rc,0),Vector3(cos(a)*ra,sin(a)*ra,0)],Vector3.BACK)
	return tool.commit()

static func _perforated_drum() -> ArrayMesh:
	var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 48:
		for row in 8:
			var divisions: Array[float]=[0.0,.35,.65,1.0]
			for u in 3:
				for v in 3:
					if u==1 and v==1:continue
					var a: float=(i+divisions[u])*TAU/48.0
					var c: float=(i+divisions[u+1])*TAU/48.0
					var z0: float=-(row+divisions[v])*.65/8.0
					var z1: float=-(row+divisions[v+1])*.65/8.0
					Geo._face(tool,[Vector3(cos(a)*.35,sin(a)*.35,z0),Vector3(cos(c)*.35,sin(c)*.35,z0),Vector3(cos(c)*.35,sin(c)*.35,z1),Vector3(cos(a)*.35,sin(a)*.35,z1)],Vector3(-cos((a+c)*.5),-sin((a+c)*.5),0))
	return tool.commit()

static func _display_digit(b, root: Node3D, point: Vector3, segments: Array) -> void:
	var centers: Array[Vector2]=[Vector2(0,.035),Vector2(.025,.018),Vector2(.025,-.018),Vector2(0,-.035),Vector2(-.025,-.018),Vector2(-.025,.018),Vector2.ZERO]
	for i: int in segments:
		var horizontal: bool=i in [0,3,6]
		b._box(root,Vector3(.043 if horizontal else .006,.006 if horizontal else .030,.005),point+Vector3(centers[i].x,centers[i].y,0),b.LIGHT,0,.001)

static func _woven_bands() -> ArrayMesh:
	var tool:=SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 10:
		var y: float=.08+row*.05
		for i in 96:
			var a: float=i*TAU/96.0; var c: float=(i+1)*TAU/96.0
			var ra: float=.49+(y-.04)/.54*.06+cos(a*12+row*PI)*.018
			var rc: float=.49+(y-.04)/.54*.06+cos(c*12+row*PI)*.018
			for side in [-1.0,1.0]:
				var pa:=Vector3(cos(a)*(ra+side*.006),y-.015,sin(a)*(ra+side*.006))
				var pc:=Vector3(cos(c)*(rc+side*.006),y-.015,sin(c)*(rc+side*.006))
				Geo._face(tool,[pa,pc,pc+Vector3.UP*.030,pa+Vector3.UP*.030],Vector3(cos((a+c)*.5),0,sin((a+c)*.5))*side)
			for vertical in [-1.0,1.0]:
				Geo._face(tool,[Vector3(cos(a)*(ra-.006),y+vertical*.015,sin(a)*(ra-.006)),Vector3(cos(c)*(rc-.006),y+vertical*.015,sin(c)*(rc-.006)),Vector3(cos(c)*(rc+.006),y+vertical*.015,sin(c)*(rc+.006)),Vector3(cos(a)*(ra+.006),y+vertical*.015,sin(a)*(ra+.006))],Vector3.UP*vertical)
	return tool.commit()
