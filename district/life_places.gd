extends RefCounted
## Distinct walkable courtyards. Props leave the winding access paths free.
static func build(g,id: String) -> Dictionary:
 if id=="gallery":
  var data: Dictionary=g.locations[id].duplicate(true)
  var floor=preload("res://district/whole_floor.gd")
  var result: Dictionary=floor.build(g,data)
  for zone in result.zones:
   var first_prop: int=g.world.get_child_count()
   var c: Vector3=zone.center
   if zone.kind=="exhibit":
    for x in [-3.6,0,3.6]:g._prop("v18_easel",c+Vector3(x,0,-2.1))
   elif zone.kind=="craft":g._prop("v18_sewing_basket",c+Vector3(-2,0,1.6))
   elif zone.kind=="reading":g._prop("v18_record_cabinet",c+Vector3(-3.1,0,-3.2))
   elif zone.kind=="tea":g._prop("v18_tea_cart",c+Vector3(-3,0,-2.1))
   if zone.kind in ["reading","tea"]:
    g._prop("v18_interior_cream_sofa",c+Vector3(-2.8,0,2.2))
    # 茶几位置：「唱片与资料室」那间必须避开 whole_floor 摆的两把扶手椅（c+(2.5,0.4) 与 c+(-0.1,0.4)，
     # 两者相距 2.6m），而茶几本身宽 2.0m —— 摆在正中的 (1.4,1.5) 会同时插进两把椅子
     # （实测重叠 0.40 m³）。挪到它们北侧空位，两把椅子都拉开到 2.2m 以上。
    g._prop("v18_interior_tea_table",c+(Vector3(1.2,0,-1.4) if zone.kind=="reading" else Vector3(1.4,0,1.5)))
    g._prop("v18_interior_floor_lamp",c+Vector3(-4.2,0,2.0))
   if zone.kind=="craft":
    g._prop("v18_interior_writing_desk",c+Vector3(3.5,0,-3.2))
    g._prop("v18_greenhouse_shelf",c+Vector3(-4.3,0,-3.1))
   floor._fit_furniture(g,g.world,first_prop,zone.rect,zone.door,zone.center.z>0,zone.polygon,zone.door_clear+zone.paths)
  return result
 return preload("res://district/courtyard_scenes.gd").build(g,id)

