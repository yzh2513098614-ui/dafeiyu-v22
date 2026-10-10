extends RefCounted
## Reference-based solid models. Same material finish as the rest of v22.
const Decor=preload("res://district/decor_library.gd")
static var scenes: Dictionary={}
static func instance(id: String) -> Node3D:
 if not scenes.has(id):scenes[id]=load("res://models/library_props/"+id+".tscn")
 if scenes[id]==null:push_error("Missing library reconstruction: "+id);return null
 var node: Node3D=scenes[id].instantiate()
 Decor._finish(node);node.set_meta("library_id",id)
 return node
static func place(g,id: String,pos: Vector3,angle: float=0) -> Node3D:
 var node:=instance(id)
 if node==null:return null
 node.position=pos;node.rotation_degrees.y=angle;g.shell.add_child(node)
 return node
