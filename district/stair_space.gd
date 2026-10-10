extends RefCounted
## Enlarge authored switchback stairs before floor support is separated.
const FLIGHT_WIDTH:=3.8
const LANDING_WIDTH:=9.2
const LANDING_DEPTH:=3.6

static func apply(architecture: Node3D) -> void:
	for stair in architecture.get_children():
		if not stair is Node3D or stair.get_meta("stair_kind","")!="dogleg":continue
		if stair.has_meta("stair_space_revision"):continue
		for flight in stair.get_children():
			if not str(flight.name).begins_with("Flight"):continue
			var slope: StaticBody3D=flight.get_node("WalkableSlope")
			var ramp: CollisionShape3D=slope.get_node("Shape")
			var half_width: float=0
			for point in ramp.shape.points:half_width=maxf(half_width,absf(point.x))
			var ratio:=FLIGHT_WIDTH/(half_width*2)
			var widening:=FLIGHT_WIDTH*.5-half_width
			for hit in slope.get_children():
				if not hit is CollisionShape3D or not hit.shape is ConvexPolygonShape3D:continue
				var shape: ConvexPolygonShape3D=hit.shape.duplicate()
				var points:=shape.points
				for i in points.size():
					points[i].x=points[i].x*ratio if hit==ramp else points[i].x+signf(points[i].x)*widening
				shape.points=points;hit.shape=shape
			for rail in flight.get_children():
				if str(rail.name).begins_with("Handrail"):rail.position.x+=signf(rail.position.x)*widening
			flight.get_node("OriginalLibraryStair").scale.x*=ratio
		_resize_pair(stair,"HalfLanding","HalfLandingBody",Vector3(LANDING_WIDTH,.18,LANDING_DEPTH),Vector3(0,1.71,LANDING_DEPTH*.5))
		# The academy uses an open landing; the other maps have a service box.
		if stair.has_node("UnderLandingServiceCloset"):
			_resize_pair(stair,"UnderLandingServiceCloset","UnderLandingServiceClosetBody",Vector3(LANDING_WIDTH,1.55,LANDING_DEPTH),Vector3(0,.775,LANDING_DEPTH*.5))
		_resize_pair(stair,"LandingSideGuard","LandingSideGuardBody",Vector3(.1,1.1,LANDING_DEPTH),Vector3(-LANDING_WIDTH*.5,2.35,LANDING_DEPTH*.5))
		_resize_pair(stair,"LandingSideGuard_2","LandingSideGuardBody_2",Vector3(.1,1.1,LANDING_DEPTH),Vector3(LANDING_WIDTH*.5,2.35,LANDING_DEPTH*.5))
		_resize_pair(stair,"LandingBackGuard","LandingBackGuardBody",Vector3(LANDING_WIDTH,1.1,.1),Vector3(0,2.35,LANDING_DEPTH))
		stair.set_meta("stair_space_revision",1)

static func _resize_pair(stair: Node3D,mesh_name: String,body_name: String,size: Vector3,point: Vector3) -> void:
	var visual: MeshInstance3D=stair.get_node(mesh_name)
	var geometry: BoxMesh=visual.mesh.duplicate();geometry.size=size
	visual.mesh=geometry;visual.position=point
	var hit: CollisionShape3D=stair.get_node(body_name+"/Shape")
	var shape: BoxShape3D=hit.shape.duplicate();shape.size=size
	hit.shape=shape;hit.position=point
