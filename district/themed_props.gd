extends RefCounted
## Detailed GLB furniture for thematic rooms and shared public decorations.
const Library=preload("res://district/decor_library.gd")
const Dressing=preload("res://district/decor_dressing.gd")
static func place(holder: Node3D,id: String,pos: Vector3,angle: float=0.0) -> Node3D:
 return Library.place(holder,id,pos,angle)
static func dress(holder: Node3D,kind: String,w: float,d: float,door: Vector3=Vector3.INF) -> void:
 if door == Vector3.INF: door=Vector3(0,0,d/2)
 Dressing.dress(holder,kind,w,d,door)
