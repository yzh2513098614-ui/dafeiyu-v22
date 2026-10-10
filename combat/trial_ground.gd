extends RefCounted
static func build(g) -> Dictionary:
 var b=g._builder(g.shell)
 b.box(Vector3(28,.22,22),Vector3(0,-.14,0),Color("839fa9"))
 b.box(Vector3(27.8,.035,21.8),Vector3(0,-.018,0),Color("d7e3dd"))
 for x in range(-13,14,2):b.box(Vector3(.02,.006,21.5),Vector3(x,.015,0),Color("b9cbd0"))
 for z in range(-10,11,2):b.box(Vector3(27.5,.006,.02),Vector3(0,.015,z),Color("b9cbd0"))
 b.box(Vector3(19,.013,14),Vector3(0,.017,-1),Color("bed5d2"))
 for x in [-10.0,10.0]:
  for z in [-7.5,6.0]:g._prop("plant_fiddle",Vector3(x,0,z))
 g._sign("潮汐试炼场",Vector3(0,2.5,-9.1),40,Color("334475"))
 g._sign("红圈亮起，先走出范围再反击。",Vector3(0,1.75,-9.1),22,Color("54728b"))
 g._bounds(Vector2(28,22))
 return {"bounds":Vector2(28,22),"spawn":Vector3(0,0,6),"camera_size":24.0,"zones":[{"id":"trial_court","name":"潮汐试炼场","rect":Rect2(-14,-11,28,22),"center":Vector3.ZERO}]}
