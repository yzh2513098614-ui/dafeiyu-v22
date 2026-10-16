extends RefCounted
## Shared geometry contract for the playable roof and its single-storey tower.
const PLATFORM := Rect2(-28,-38,56,46.18)
const TOWER := Rect2(-20,-30,20,24)
const HEIGHT := 10.4
const Door = preload("res://district/interactive_door.gd")
const Geo = preload("res://district/story_geometry.gd")
var b
var floor_root: Node3D

func build(builder) -> void:
	b=builder;floor_root=b.floors[2]
	# Four closed slabs leave the existing west stairwell open through the soffit.
	for rect: Rect2 in [Rect2(-28,-38,56,24),Rect2(-28,-14,14,22.18),Rect2(-8.4,-14,36.4,22.18),Rect2(-14,-1.4,5.6,9.58)]:
		b._slab(floor_root,rect,HEIGHT);b._deck(floor_root,rect,HEIGHT)
	for edge: Array in [[Vector2(-28,-38),Vector2(28,-38)],[Vector2(28,-38),Vector2(28,8.18)],[Vector2(28,8.18),Vector2(-28,8.18)],[Vector2(-28,8.18),Vector2(-28,-38)]]:
		_guard(edge[0],edge[1])
	# The open stair runs south beyond the tower; guard its exposed upper rim.
	_guard(Vector2(-14,-6),Vector2(-14,-1.4))
	_guard(Vector2(-14,-1.4),Vector2(-8.4,-1.4))
	_guard(Vector2(-8.4,-1.4),Vector2(-8.4,-6))
	_wall(Vector2(-13.5,-30),Vector2(-13.5,-6),[[ -21.0,2.6,"floor_3_west_rear","海风客房"],[-16.3,3.0,"","入口厅"]])
	_wall(Vector2(-8.5,-30),Vector2(-8.5,-6),[[-26.0,2.6,"bathroom","海盐卫浴"],[-20.2,2.6,"bedroom","鲸鱼梦境卧室"]])
	_wall(Vector2(-8.5,-22),Vector2(0,-22))
	_wall(Vector2(-20,-18),Vector2(-13.5,-18))
	# Tower boundary walls remain physically present while their upper portions cut away.
	_wall(Vector2(-20,-30),Vector2(0,-30))
	_wall(Vector2(-20,-30),Vector2(-20,-6))
	_wall(Vector2(0,-30),Vector2(0,-6))
	# Stair opening continues through the front wall between x=-13.5 and -8.5.
	_wall(Vector2(-20,-6),Vector2(-13.5,-6),[[-16.75,3.0,"rooftop_entry","海景天台门"]])
	_wall(Vector2(-8.5,-6),Vector2(0,-6))
	_bed("WhaleDreamBed",Vector3(-4.25,HEIGHT,-15.5),false,"whale_bed")
	_bed("WhaleGuestBed",Vector3(-16.75,HEIGHT,-25.5),true,"guest_bed")
	# Explicit old storage keys preserve every migrated cabinet's contents.
	var specs := [
		[Vector3(-4.8,HEIGHT,-20.9),1.18,.82,"cabinet_m4p8_10p4_m18p9"],
		[Vector3(-2.0,HEIGHT,-20.9),1.18,.82,"cabinet_1p1_10p4_m14p4"],
		[Vector3(-4.25,HEIGHT,-7.1),4.2,1.3,"cabinet_5p6_10p4_m18p8"],
		[Vector3(-18.6,HEIGHT,-28.8),1.3,.85,"cabinet_m24p0_10p4_m30p0"],
		[Vector3(-14.8,HEIGHT,-28.8),1.3,.85,"cabinet_m18p0_10p4_m30p0"],
		[Vector3(-1.5,HEIGHT,-28.8),2.1,1.02,"cabinet_m7p0_10p4_m30p7"],
		[Vector3(-6.8,HEIGHT,-28.8),1.55,2.15,"cabinet_m11p7_10p4_m24p4"],
		[Vector3(-19,HEIGHT,-9),2.0,1.1,"cabinet_m9p0_10p4_m36p8"],
		[Vector3(-19,HEIGHT,-12),2.0,1.1,"cabinet_0p0_10p4_m36p8"],
		[Vector3(-1.1,HEIGHT,-9),2.0,1.1,"cabinet_9p0_10p4_m36p8"]]
	for spec: Array in specs:
		var cabinet: Node3D=b._cabinet(floor_root,spec[0],spec[1],spec[2],"cream_cabinet")
		cabinet.set_meta("home_storage_id",spec[3])
		if spec[0].x==-19 or spec[0].x==-1.1:cabinet.rotation.y=PI*.5
		if spec[3]=="cabinet_m7p0_10p4_m30p7":b.Fixtures.vanity_sink(b,cabinet)
	var bath: Node3D=b._furniture(floor_root,"WhaleFootedBath",Vector3(-4.3,HEIGHT,-24))
	b.Fixtures.bath(b,bath);b._coll(bath,Vector3(3.44,1.3,1.8),Vector3(0,.66,0))
	var interiors=preload("res://district/whale_home_interiors.gd").new();interiors.b=b
	interiors._guest_storage()
	var wardrobe: Node3D=b.game.world.get_node("HomeAction_guest_wardrobe")
	wardrobe.position=Vector3(-19,HEIGHT,-15.4);wardrobe.rotation.y=PI*.5
	var luggage: Node3D=floor_root.get_node("GuestLuggageRack");luggage.position=Vector3(15,HEIGHT,-29)
	var outdoors=preload("res://district/whale_home_outdoors.gd").new();outdoors.b=b;outdoors._sea_recliner()
	b.game.world.get_node("HomeAction_balcony_rest").position=Vector3(6,HEIGHT,-31)
	var scope: Node3D=b._action("scope","stargazer","观星望远镜 · 灯塔与星空",Vector3(19,HEIGHT,-15),HEIGHT)
	b.Optics.telescope(b,scope);b._coll(scope,Vector3(1.8,2.18,1.8),Vector3(0,1.09,0))
	b._chair(floor_root,Vector3(16.5,HEIGHT,-13),25,true)
	var tea: Node3D=b._table(floor_root,Vector3(9,HEIGHT,1),3.6,1.8,.65,"tea_table")
	b._cup(tea,Vector3(-1,.76,0),b.BLUE);b._cup(tea,Vector3(1,.76,0),b.WHITE)
	b._action("tea","rooftop_tea","海景天台 · 午后花茶",Vector3(9,HEIGHT,1),HEIGHT)
	for x in [6.0,12.0]:b._chair(floor_root,Vector3(x,HEIGHT,1),90 if x<9 else -90)
	var pergola: Node3D=b._model(floor_root,b.PERGOLA,Vector3(18,HEIGHT,-30),true)
	for x in [-2.0,2.0]:
		for z in [-1.65,1.65]:b._coll(pergola,Vector3(.26,3.35,.26),Vector3(x,1.675,z))
	b._sofa(floor_root,Vector3(18,HEIGHT,-30),4.2)
	b._fixture(floor_root,Vector3(18,HEIGHT+3.5,-30),true,true)
	b._action("lamp","star_lights","星星灯串开关",Vector3(20.5,HEIGHT,-27),HEIGHT)
	for point: Vector3 in [Vector3(15,HEIGHT,-33),Vector3(21,HEIGHT,-33),Vector3(22,HEIGHT,-19)]:b._plant(floor_root,point,1.2,true)
	for spec: Array in [["annex_guest","海风客房",Rect2(-20,-30,6.5,12)],["bathroom","海盐卫浴",Rect2(-8.5,-30,8.5,8)],["bedroom","鲸鱼梦境卧室",Rect2(-8.5,-22,8.5,16)],["landing","塔楼交通厅",Rect2(-13.5,-30,5,24)],["tower_entry","天台入口厅",Rect2(-20,-18,6.5,12)],["stars","海景天台",PLATFORM]]:
		b._zone(spec[0],"3F · "+spec[1],spec[2],HEIGHT)
	for zone: Dictionary in b.zones:
		if not is_equal_approx(float(zone.height),HEIGHT):continue
		zone.paths=[Rect2(-13.5,-30,5,24),Rect2(-17.9,-18,2.3,14),Rect2(-28,-38,56,3),Rect2(-28,5.18,56,3),Rect2(-28,-38,3,46.18),Rect2(25,-38,3,46.18)]
		zone.door_clear=[Rect2(-15.5,-22.5,4,3),Rect2(-10.5,-27.5,4,3),Rect2(-10.5,-21.7,4,3)]
	b.level.set_meta("rooftop_revision","sea_tower_v1")

func _guard(a: Vector2,c: Vector2) -> void:
	var d: Vector2=c-a
	var root: Node3D=b._group(floor_root,"RooftopGuard",Vector3((a.x+c.x)*.5,HEIGHT,(a.y+c.y)*.5))
	root.rotation.y=-atan2(d.y,d.x)
	b._box(root,Vector3(d.length()+.3,.22,.55),Vector3(0,-.17,0),b.WHITE)
	b._box(root,Vector3(d.length(),.4,.32),Vector3(0,.2,0),b.WHITE)
	b._box(root,Vector3(d.length(),.08,.42),Vector3(0,.44,0),b.MINT)
	for i in ceili(d.length()/1.6)+1:
		var x: float=minf(i*1.6,d.length())-d.length()*.5
		Geo.rod(root,Vector3(x,.44,0),Vector3(x,1.35,0),.045,b.TEAL)
	Geo.rod(root,Vector3(-d.length()*.5,1.35,0),Vector3(d.length()*.5,1.35,0),.065,b.WOOD)
	b._coll(root,Vector3(d.length(),1.35,.34),Vector3(0,.675,0))

func _bed(label: String,point: Vector3,guest: bool,id: String) -> void:
	var bed: Node3D=b._furniture(floor_root,label,point)
	b.Beds.build(b,bed,guest)
	b._coll(bed,Vector3(3.9,1.95,5.1) if guest else Vector3(5.28,2.35,6.42),Vector3(0,.98 if guest else 1.18,0))
	b._action("bed",id,"海景卧室 · 休息",point+Vector3(0,0,3.0 if guest else 3.65),HEIGHT)

func _wall(a: Vector2,c: Vector2,cuts: Array=[]) -> void:
	var d: Vector2=c-a
	var wall: Node3D=b._group(floor_root,"TowerPartition",Vector3((a.x+c.x)*.5,HEIGHT,(a.y+c.y)*.5))
	wall.rotation.y=-atan2(d.y,d.x);wall.set_meta("floor_height",HEIGHT)
	var upper: Node3D=b._group(wall,"CutawayUpper");upper.set_meta("home_dynamic",true)
	b.level.get_meta("home_wall_tops").append(upper)
	var start: float=-d.length()*.5
	for spec: Array in cuts:
		var offset: float=spec[0]-(a.y+c.y)*.5 if absf(d.y)>.1 else spec[0]-(a.x+c.x)*.5
		_span(wall,upper,start,offset-spec[1]*.5)
		b._box(upper,Vector3(spec[1],2.15,.25),Vector3(offset,4.125,0),b.WHITE)
		b._coll(wall,Vector3(spec[1],2.15,.25),Vector3(offset,4.125,0))
		if spec[2]!="":
			var door:=Door.new();door.name="RoomDoor_"+spec[2];door.position.x=offset;wall.add_child(door)
			door.set_meta("home_dynamic",true);door.set_meta("floor_height",HEIGHT)
			door.configure(b.game,spec[1],spec[2],spec[3],2.95)
			b.level.get_meta("home_room_doors").append(door)
		start=offset+spec[1]*.5
	_span(wall,upper,start,d.length()*.5)
	b._batch(upper)

func _span(wall: Node3D,upper: Node3D,start: float,end: float) -> void:
	if end<=start:return
	b._box(wall,Vector3(end-start,1.15,.25),Vector3((start+end)*.5,.575,0),b.WHITE)
	b._box(upper,Vector3(end-start,4.05,.25),Vector3((start+end)*.5,3.175,0),b.WHITE)
	b._coll(wall,Vector3(end-start,5.2,.25),Vector3((start+end)*.5,2.6,0))