@tool
extends Node3D
## Solid environment geometry; illustrations are retained only as catalog references.
@export var module_id := "bed_navy"
var metadata: Dictionary
var collision_depth := 0.0
var collision_width := 0.0
var collision_height := 0.8
const Catalog = preload("res://module.gd")
const Modern = preload("res://modern_materials.gd")
const Models = preload("res://environment_models.gd")
const DetailDecor = preload("res://district/decor_library.gd")
const DETAIL_REPLACEMENTS := {"bookcase":"school_open_bookshelf","entry_bench":"curved_bench","plant_fiddle":"sculpted_planter","plant_broadleaf":"sculpted_planter","plant_snake":"sculpted_planter","flowers":"hydrangea_pot","bonsai":"hydrangea_pot","storage_box":"woven_crate","basket":"woven_crate","fridge":"retro_fridge","armchair_sage":"lounge_chair","armchair_navy":"lounge_chair","lamp_floor":"floor_lamp","tea_trolley":"restaurant_service_cart"}
const WOOD := Color("c6ccce")
const EDGE := Color("455665")
const METAL := Color("3b4b5b")
const BLUE := Color("3b6396")
const IVORY := Color("ecebe4")
const SAGE := Color("a2bec5")
static var mats: Dictionary = {}
static var bevel_meshes: Dictionary = {}

static func surface_texture(_color: Color) -> String:
 return ""

static func material(color: Color, _texture: String = "") -> StandardMaterial3D:
 return Modern.surface(color,color in [EDGE,METAL],false)

func led_box(size: Vector3,pos: Vector3,color: Color = Color("71dce8"),power: float = .65) -> MeshInstance3D:
 var mesh:=box(size,pos,color);mesh.material_override=Modern.led(color,power);return mesh

func box(size: Vector3,pos: Vector3,color: Color,texture: String = "") -> MeshInstance3D:
 var mesh: Mesh
 if minf(size.x,minf(size.y,size.z))>.055:mesh=beveled_mesh(size)
 else:
  var plain:=BoxMesh.new();plain.size=size;mesh=plain
 var instance := MeshInstance3D.new();instance.mesh=mesh;instance.position=pos
 instance.material_override=material(color,texture);add_child(instance)
 return instance

static func beveled_mesh(size: Vector3) -> ArrayMesh:
 var key:=str(size)
 if bevel_meshes.has(key):return bevel_meshes[key]
 var b:=minf(.027,minf(size.x,minf(size.y,size.z))*.18)
 var hw:=size.x/2;var hd:=size.z/2;var hh:=size.y/2
 var outer: Array[Vector2]=[Vector2(-hw+b,-hd),Vector2(hw-b,-hd),Vector2(hw,-hd+b),Vector2(hw,hd-b),Vector2(hw-b,hd),Vector2(-hw+b,hd),Vector2(-hw,hd-b),Vector2(-hw,-hd+b)]
 var inner: Array[Vector2]=[]
 for p in outer:inner.append(Vector2(p.x-clampf(p.x,-b,b),p.y-clampf(p.y,-b,b)))
 var rings: Array=[]
 for i in 4:
  var ring: Array[Vector3]=[]
  var points: Array=inner if i in [0,3] else outer
  var y: float=[-hh,-hh+b,hh-b,hh][i]
  for p in points:ring.append(Vector3(p.x,y,p.y))
  rings.append(ring)
 var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for level in 3:
  for i in 8:
   var j: int=(i+1)%8
   _mesh_triangle(tool,rings[level][i],rings[level][j],rings[level+1][j])
   _mesh_triangle(tool,rings[level][i],rings[level+1][j],rings[level+1][i])
 for i in 8:
  var j: int=(i+1)%8
  _mesh_triangle(tool,Vector3(0,hh,0),rings[3][i],rings[3][j])
  _mesh_triangle(tool,Vector3(0,-hh,0),rings[0][j],rings[0][i])
 var mesh:=tool.commit();bevel_meshes[key]=mesh;return mesh

static func _mesh_triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
 var normal: Vector3=-(b-a).cross(c-a).normalized()
 for p in [a,b,c]:tool.set_normal(normal);tool.set_uv(Vector2(p.x,p.z));tool.add_vertex(p)

func cylinder(radius: float,height: float,pos: Vector3,color: Color) -> MeshInstance3D:
 var mesh := CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=16
 var instance := MeshInstance3D.new();instance.mesh=mesh;instance.position=pos;instance.material_override=material(color);add_child(instance)
 return instance

func pillow(size: Vector3,pos: Vector3,color: Color) -> MeshInstance3D:
 var mesh := SphereMesh.new();mesh.radius=0.5;mesh.height=1.0;mesh.radial_segments=16;mesh.rings=8
 var instance := MeshInstance3D.new();instance.mesh=mesh;instance.scale=size;instance.position=pos
 instance.material_override=Modern.surface(color,false,true)
 add_child(instance);return instance

func _ready() -> void:
 metadata=Catalog.get_catalog().get(module_id,{})
 if metadata.is_empty():return
 var id:=module_id
 if DETAIL_REPLACEMENTS.has(id):
  var detailed: Node3D=DetailDecor.instance(DETAIL_REPLACEMENTS[id])
  if detailed != null:
   var hit: CollisionShape3D=detailed.get_node("Body/Collision")
   var factor: float=.40 if metadata.get("layer","")=="surface" else 1.0
   var visual_scale:=Vector3.ONE*factor
   if id=="plant_fiddle":visual_scale*=Vector3(1.0,1.22,1.0)
   elif id=="plant_broadleaf":visual_scale*=Vector3(1.1,.95,1.1)
   elif id=="plant_snake":visual_scale*=Vector3(.68,1.12,.68)
   detailed.scale=visual_scale
   collision_width=hit.shape.size.x*visual_scale.x
   collision_depth=hit.shape.size.z*visual_scale.z
   collision_height=hit.shape.size.y*visual_scale.y
   detailed.position=Vector3(-hit.position.x*visual_scale.x,0,-collision_depth/2-hit.position.z*visual_scale.z)
   add_child(detailed)
   return
 if Models.build(self,id,metadata):pass
 elif metadata.category=="structure":_structure()
 elif metadata.category=="floor":_floor_tile()
 elif id.begins_with("bed_"):_bed(id.ends_with("sage"))
 elif id.begins_with("desk_"):_desk(id.ends_with("white"))
 elif id=="bookcase":_bookcase()
 elif id in ["wardrobe","dresser","cubby","tv_cabinet","shoe_cabinet","nightstand"]:_storage(id)
 elif id in ["loveseat_navy","sofa_cream","armchair_navy","armchair_sage"]:_sofa(id)
 elif id in ["chair_oak","chair_white","office_chair","bar_stool"]:_chair(id)
 elif id in ["side_table","dining_round","dining_white","coffee_table","entry_bench"]:_table(id)
 elif id in ["fridge","sink_counter","stove_counter","counter_blank","oven_counter","corner_counter","bar_cabinet","bakery_case","vending_machine","upper_cabinet","plate_rack","tea_trolley"]:_kitchen(id)
 elif id in ["monitor","laptop","keyboard"]:_computer(id)
 elif id in ["lamp_table","lamp_floor"]:_lamp(id)
 elif id=="coat_rack":_coat_rack()
 elif id.begins_with("curtains_"):_curtains()
 elif id.begins_with("window_"):_window()
 elif id.begins_with("door_"):_door()
 elif id=="lamp_wall":_wall_light()
 elif id in ["shelf_books","shelf_plants","shelf_small"]:_shelf()
 elif id=="basket":_basket()
 else:push_error("Unregistered 3D environment module: "+id)
 if collision_depth>0:
  var body:=StaticBody3D.new();var hit:=CollisionShape3D.new();var shape:=BoxShape3D.new()
  shape.size=Vector3(collision_width,collision_height,collision_depth)
  hit.shape=shape;hit.position=Vector3(0,collision_height/2,-collision_depth/2)
  body.add_child(hit);add_child(body)
 elif metadata.solid:
  var body:=StaticBody3D.new();var hit:=CollisionShape3D.new();var shape:=CylinderShape3D.new()
  shape.radius=maxf(float(metadata.footprint[0])/192.0,0.15);shape.height=0.55;hit.position.y=0.275;hit.shape=shape
  body.add_child(hit);add_child(body)
 if metadata.layer=="object" and metadata.solid and metadata.category!="structure":_contact_shadow()

func _contact_shadow() -> void:
 var shadow:=MeshInstance3D.new();var plane:=PlaneMesh.new()
 shadow.name="ContactShadow"
 plane.size=Vector2(collision_width+.20,collision_depth+.18) if collision_depth>0 else Vector2(.63,.42)
 shadow.mesh=plane;shadow.position=Vector3(0,.014,-collision_depth/2)
 var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void fragment(){vec2 q=abs(UV-vec2(.5))*2.;float edge=1.-smoothstep(.50,1.,max(q.x,q.y));ALBEDO=vec3(.065,.083,.105);ALPHA=edge*.13;}"
 var m:=ShaderMaterial.new();m.shader=shader;shadow.material_override=m;shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(shadow)

func _solid(w: float,d: float) -> void:collision_width=w;collision_depth=d

func _structure() -> void:
 var id:=module_id
 if id.begins_with("cap_") or id.begins_with("base_") or id.begins_with("rail_"):
  var h:=.11;var d:=.34
  if id.begins_with("base_"):h=.10;d=.08
  if id.begins_with("rail_"):
   led_box(Vector3(1.3334,.025,.035),Vector3(0,.015,-.02),Color("71dce8") if id.ends_with("cyan") else Color("ffe4af"),.45)
  else:box(Vector3(1.3334,h,d),Vector3(0,h/2,-d/2),METAL)
 elif id.begins_with("post_") or id.begins_with("corner_"):
  var w:=.18 if id.begins_with("post_") else .26
  box(Vector3(w,2.78,w),Vector3(0,1.39,0),METAL)
  if id.ends_with("cyan"):led_box(Vector3(.025,2.45,.014),Vector3(0,1.36,w/2+.005))
 else:
  _solid(1.3334,.23);collision_height=2.78
  var colors: Dictionary={"plaster_ivory":Color("d6dce0"),"oak_slats":Color("cbbba3"),"walnut_slats":Color("8b9298"),"slate_panels":Color("8b9ba7"),"concrete_panels":Color("bcc5cd"),"navy_padded":Color("4b6383"),"plaster_mint":Color("c6d8d7"),"cream_tile":Color("dee2e2"),"brushed_metal":Color("a0afbb"),"beige_wainscot":Color("c6ced4"),"white_marble":Color("e2e5e5"),"pale_wainscot":Color("cdd6dc")}
  var color: Color=colors.get(id,IVORY)
  box(Vector3(1.3334,2.78,.23),Vector3(0,1.39,-.115),color)
  # Flush panels and a fine expansion joint, shared by all wall modules.
  box(Vector3(.012,2.63,.007),Vector3(.66,1.39,.004),color.darkened(.13))
  box(Vector3(1.334,.09,.06),Vector3(0,.06,.026),METAL)
  if id in ["beige_wainscot","pale_wainscot","slate_panels","brushed_metal"]:
   box(Vector3(1.32,.72,.022),Vector3(0,.49,.022),color.darkened(.045))
   led_box(Vector3(1.30,.012,.012),Vector3(0,.89,.037),Color("8acdd5"),.23)
  if id in ["oak_slats","walnut_slats"]:
   for x in [-.55,-.33,-.11,.11,.33,.55]:box(Vector3(.07,2.62,.028),Vector3(x,1.39,.025),color.lightened(.035))

func _floor_tile() -> void:
 var m:=box(Vector3(2.0/3,.035,2.0/3),Vector3(0,-.0175,0),Color.WHITE)
 m.material_override=Modern.floor_material(module_id.trim_prefix("floor_"))
 var body:=StaticBody3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(2.0/3,.035,2.0/3)
 var hit:=CollisionShape3D.new();hit.shape=shape;body.position.y=-.0175;body.add_child(hit);add_child(body)

func _legs(w: float,d: float,h: float,color: Color = METAL) -> void:
 for x in [-w/2+0.08,w/2-0.08]:
  for z in [-d+0.08,-0.08]:box(Vector3(0.085,h,0.085),Vector3(x,h/2,z),color)

func _bed(green: bool) -> void:
 var fabric := SAGE if green else BLUE
 _solid(1.92,2.65)
 _legs(1.96,2.62,0.24)
 box(Vector3(2.04,0.20,2.65),Vector3(0,0.33,-1.325),WOOD,"res://assets/floors/oak.png")
 box(Vector3(1.90,0.26,2.52),Vector3(0,0.55,-1.33),IVORY)
 box(Vector3(2.05,1.28,0.12),Vector3(0,0.72,-2.68),EDGE)
 for x in [-0.49,0.49]:box(Vector3(0.94,0.59,0.11),Vector3(x,0.97,-2.59),fabric)
 pillow(Vector3(0.79,0.24,0.49),Vector3(-0.45,0.75,-2.13),IVORY)
 pillow(Vector3(0.79,0.24,0.49),Vector3(0.45,0.75,-2.13),IVORY)
 box(Vector3(1.98,0.11,1.66),Vector3(0,0.72,-0.91),fabric)
 for z in [-1.58,-.32]:box(Vector3(1.93,.006,.018),Vector3(0,.780,z),fabric.lightened(.07))
 led_box(Vector3(1.96,.018,.018),Vector3(0,1.35,-2.58),Color("81d8e1"),.30)
 for x in [-.95,.95]:box(Vector3(.035,.05,2.36),Vector3(x,.48,-1.33),METAL)
 box(Vector3(1.99,0.27,0.055),Vector3(0,0.55,-0.06),fabric)
 box(Vector3(1.99,0.018,0.08),Vector3(0,0.64,-0.03),IVORY)

func _desk(white: bool) -> void:
 _solid(2.48,0.97)
 var wood:=IVORY if white else Color("d1cabd")
 _legs(2.46,0.94,0.84)
 box(Vector3(2.50,0.11,1.00),Vector3(0,0.89,-0.50),wood,"res://assets/floors/pale_oak.png" if white else "res://assets/floors/oak.png")
 box(Vector3(0.68,0.65,0.88),Vector3(0.81,0.48,-0.46),wood)
 for y in [0.28,0.60]:
  box(Vector3(0.62,0.28,0.025),Vector3(0.81,y,-0.005),wood.lightened(0.12))
  box(Vector3(0.23,0.027,0.04),Vector3(0.81,y+0.02,0.025),METAL)
 box(Vector3(1.70,0.09,0.10),Vector3(-0.27,0.65,-0.93),METAL)

func _bookcase() -> void:
 _solid(1.28,0.48)
 box(Vector3(1.34,2.23,0.075),Vector3(0,1.24,-0.48),WOOD.darkened(0.15))
 for x in [-0.625,0.625]:box(Vector3(0.10,2.28,0.54),Vector3(x,1.20,-0.25),WOOD)
 var colors: Array[Color]=[BLUE,Color("667d88"),Color("bba574"),Color("a66e64"),SAGE]
 for level in range(4):
  var y:=0.22+level*0.57
  box(Vector3(1.30,0.075,0.55),Vector3(0,y,-0.25),WOOD.lightened(0.13))
  for book in range(6):
   var h:=0.34+0.045*((book+level)%3)
   var b:=box(Vector3(0.10,h,0.28),Vector3(-0.49+book*0.15,y+0.045+h/2,-0.20),colors[(book+level)%5])
   if book==5:b.rotation.z=0.11
   box(Vector3(0.075,0.018,0.006),Vector3(-0.49+book*0.15,y+0.17,-0.056),IVORY)
 box(Vector3(1.40,0.08,0.61),Vector3(0,2.42,-0.25),WOOD)

func _storage(id: String) -> void:
 var w:=1.45;var h:=2.25;var d:=0.74;var color:=Color("c5ced5")
 match id:
  "nightstand":w=1.02;h=0.66;d=0.72;color=METAL
  "dresser":w=2.02;h=1.0;d=0.72;color=IVORY
  "cubby":w=1.55;h=1.34;d=0.64
  "tv_cabinet":w=2.65;h=0.63;d=0.60
  "shoe_cabinet":w=0.96;h=1.12;d=0.44;color=METAL
 _solid(w,d)
 _legs(w,d,0.15)
 box(Vector3(w,h-0.13,d),Vector3(0,(h+0.13)/2,-d/2),color)
 box(Vector3(w+0.055,0.08,d+0.05),Vector3(0,h,-d/2),WOOD if id!="dresser" else IVORY)
 if id=="wardrobe":
  for x in [-w/4,w/4]:
   box(Vector3(w/2-0.035,h-0.27,0.035),Vector3(x,h/2+0.07,0.018),color.lightened(0.10))
   box(Vector3(0.023,0.40,0.055),Vector3(x*0.18,1.18,0.055),METAL)
   led_box(Vector3(.012,.46,.015),Vector3(x*1.77,1.14,.044),Color("8bd5df"),.26)
 elif id=="cubby":
  for x in [-0.38,0.38]:
   for y in [0.49,1.07]:
    box(Vector3(0.63,0.45,0.008),Vector3(x,y,0.02),EDGE)
    for n in 3:box(Vector3(0.09,0.32,0.06),Vector3(x-0.21+n*0.13,y-0.035,0.054),[BLUE,IVORY,SAGE][n])
 else:
  var rows:=3 if id=="dresser" else 2
  for i in rows:
   var y:=0.20+(h-0.20)*(i+0.5)/rows
   box(Vector3(w-0.10,(h-0.23)/rows-0.024,0.032),Vector3(0,y,0.02),color.lightened(0.12))
   box(Vector3(w*0.24,0.024,0.054),Vector3(0,y+0.03,0.054),METAL if color.r>0.5 else IVORY)

func _sofa(id: String) -> void:
 var armchair:=id.begins_with("armchair")
 var w:=1.34 if armchair else 2.62;var d:=1.10
 var color:=SAGE if id.ends_with("sage") else (IVORY if id=="sofa_cream" else BLUE)
 _solid(w,d);_legs(w,d,0.19)
 box(Vector3(w,0.23,d),Vector3(0,0.33,-d/2),METAL)
 box(Vector3(w-0.24,0.23,d-0.16),Vector3(0,0.55,-d/2+0.02),color)
 box(Vector3(w,.79,.20),Vector3(0,.78,-d+.06),color)
 for x in [-w/2+0.095,w/2-0.095]:
  box(Vector3(.19,.66,d),Vector3(x,.62,-d/2),color)
  box(Vector3(0.20,0.11,d),Vector3(x,0.985,-d/2),color)
 var count:=1 if armchair else 2
 for i in count:
  var x: float=(i-(count-1)/2.0)*(w-0.30)/count
  box(Vector3((w-0.34)/count-0.05,0.49,0.19),Vector3(x,0.99,-d+0.19),color.lightened(0.07))
  if not armchair:pillow(Vector3(0.43,0.45,0.16),Vector3(x+0.26,0.90,-d+0.34),IVORY if id!="sofa_cream" else BLUE)

func _chair(id: String) -> void:
 var office:=id=="office_chair";var stool:=id=="bar_stool"
 var h:=0.83 if stool else 0.51;var w:=0.72
 _solid(w,0.74)
 if office or stool:
  cylinder(0.045,h-0.12,Vector3(0,h/2,-0.36),METAL)
  cylinder(0.29,0.055,Vector3(0,0.07,-0.36),METAL)
  if office:
   for i in 5:
    var leg:=box(Vector3(0.47,0.04,0.05),Vector3(0,0.10,-0.36),METAL);leg.rotation.y=TAU*i/5
 else:_legs(w,0.71,h,WOOD)
 box(Vector3(w,0.12,0.70),Vector3(0,h,-0.36),IVORY if id=="chair_white" else BLUE)
 box(Vector3(w,0.53,0.10),Vector3(0,h+0.42,-0.70),IVORY if id=="chair_white" else BLUE)
 if office:
  for x in [-0.39,0.39]:box(Vector3(0.07,0.05,0.43),Vector3(x,h+0.28,-0.37),METAL)

func _table(id: String) -> void:
 var w:=1.1;var d:=0.85;var h:=0.60
 match id:
  "dining_round":w=1.68;d=1.68;h=0.80
  "dining_white":w=2.48;d=1.10;h=0.81
  "coffee_table":w=2.03;d=0.99;h=0.47
  "entry_bench":w=1.87;d=0.66;h=0.46
 _solid(w,d)
 if id in ["side_table","dining_round"]:
  cylinder(w/2,0.095,Vector3(0,h,-d/2),WOOD)
  cylinder(0.08,h-0.11,Vector3(0,h/2,-d/2),METAL)
  cylinder(w*0.26,0.065,Vector3(0,0.06,-d/2),METAL)
 else:
  _legs(w,d,h)
  box(Vector3(w+0.05,0.09,d+0.05),Vector3(0,h,-d/2),IVORY if id=="dining_white" else WOOD)
  if id=="coffee_table":
   box(Vector3(w-0.12,0.011,d-0.12),Vector3(0,h+0.051,-d/2),Color("b1c7ce"))
   box(Vector3(w-0.20,0.035,d-0.20),Vector3(0,0.14,-d/2),METAL)
   led_box(Vector3(w-.12,.012,.018),Vector3(0,h+.011,.025),Color("7dd7e1"),.32)

func _kitchen(id: String) -> void:
 if id=="fridge" or id=="vending_machine":
  var w:=1.23;var d:=0.87;var h:=2.28
  _solid(w,d);box(Vector3(w,h,d),Vector3(0,h/2,-d/2),METAL)
  if id=="fridge":
   for x in [-0.3,0.3]:
    box(Vector3(0.55,2.16,0.04),Vector3(x,1.14,0.025),METAL.lightened(0.10))
    box(Vector3(0.028,0.65,0.08),Vector3(x*0.36,1.25,0.075),IVORY)
   box(Vector3(0.055,0.25,0.026),Vector3(0.49,1.86,0.075),Color("58d6de"))
  else:
   box(Vector3(0.88,1.57,0.016),Vector3(-0.08,1.35,0.035),Color("173843"))
   for row in 3:
    for col in 4:cylinder(0.075,0.32,Vector3(-0.39+col*0.22,0.91+row*0.45,0.06),[BLUE,IVORY,Color("ae624e"),SAGE][col])
  return
 if id=="upper_cabinet":
  box(Vector3(1.48,0.88,0.48),Vector3(0,0.44,-0.24),WOOD)
  for x in [-0.37,0.37]:box(Vector3(0.69,0.80,0.03),Vector3(x,0.44,0.012),WOOD.lightened(0.10))
  return
 if id=="plate_rack":Models.build(self,id,metadata);return
 if id=="tea_trolley":
  _solid(1.25,0.60);_legs(1.22,0.57,0.79)
  for y in [0.15,0.70]:box(Vector3(1.25,0.06,0.60),Vector3(0,y,-0.30),WOOD)
  return
 var w:=1.31;var d:=0.94;var h:=0.91
 if id=="bakery_case":w=2.13;h=1.02
 _solid(w,d)
 box(Vector3(w,h-0.09,d),Vector3(0,(h-0.09)/2,-d/2),WOOD if id!="bar_cabinet" else METAL)
 box(Vector3(w+0.04,0.09,d+0.04),Vector3(0,h,-d/2),IVORY)
 for x in [-w*0.24,w*0.24]:
  box(Vector3(w*0.45,h-0.20,0.025),Vector3(x,h/2,0.015),WOOD.lightened(0.05))
  box(Vector3(0.17,0.025,0.05),Vector3(x,h-0.25,0.049),METAL)
 if id=="sink_counter":
  box(Vector3(0.79,0.014,0.53),Vector3(0,h+0.052,-d/2),Color("727f83"))
  box(Vector3(0.64,0.015,0.39),Vector3(0,h+0.06,-d/2),METAL)
  cylinder(0.033,0.32,Vector3(0,h+0.2,-d+0.15),METAL)
  box(Vector3(0.055,0.04,0.25),Vector3(0,h+0.38,-d+0.25),METAL)
 elif id=="stove_counter":
  box(Vector3(1.0,0.01,0.65),Vector3(0,h+0.055,-d/2),METAL)
  for x in [-0.29,0.29]:cylinder(0.19,0.013,Vector3(x,h+0.065,-d/2),Color("72bac2"));cylinder(0.15,0.016,Vector3(x,h+0.075,-d/2),METAL)
 elif id=="oven_counter":box(Vector3(0.94,0.50,0.05),Vector3(0,0.41,0.042),METAL)
 elif id=="bakery_case":
  box(Vector3(w-0.18,0.60,0.04),Vector3(0,h+0.38,-0.08),Color("66969e"))
  for x in [-w/2+0.06,w/2-0.06]:box(Vector3(0.07,0.69,d),Vector3(x,h+0.39,-d/2),METAL)
  box(Vector3(w,0.05,d),Vector3(0,h+0.72,-d/2),Color("82bcc7"))

func _computer(id: String) -> void:
 if id=="keyboard":
  box(Vector3(0.62,0.035,0.24),Vector3(0,0.025,0),METAL)
  for y in 3:
   for x in 9:box(Vector3(0.05,0.011,0.045),Vector3(-0.25+x*0.061,0.05,-0.07+y*0.06),IVORY)
  return
 if id=="laptop":box(Vector3(0.82,0.035,0.58),Vector3(0,0.03,0.12),Color("8d989e"))
 else:
  box(Vector3(0.40,0.035,0.26),Vector3(0,0.025,0),METAL)
  box(Vector3(0.045,0.24,0.07),Vector3(0,0.13,0),METAL)
 var screen:=box(Vector3(0.86,0.54,0.045),Vector3(0,0.50,-0.025),METAL)
 var glass:=led_box(Vector3(.79,.47,.008),Vector3(0,.50,.001),Color("4386ac"),.25)
 for i in 4:box(Vector3(0.25+0.07*i,0.012,0.005),Vector3(-0.13,0.60-i*0.05,0.010),Color("a4d6dd"))

func _lamp(id: String) -> void:
 var h:=1.55 if id=="lamp_floor" else .49
 if id=="lamp_floor":_solid(.38,.38)
 cylinder(.19,.035,Vector3(0,.035,-.12),METAL)
 cylinder(.018,h-.10,Vector3(0,h/2,-.12),METAL)
 var globe:=pillow(Vector3(.43,.43,.43),Vector3(0,h,-.12),IVORY)
 globe.material_override=Modern.led(Color("fff1d2"),.18)
 globe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var lamp:=OmniLight3D.new();lamp.position=Vector3(0,h,-.12);lamp.light_color=Color("ffe7c0");lamp.light_energy=.60;lamp.omni_range=2.7;add_child(lamp)

func _wall_light() -> void:
 box(Vector3(.14,.64,.08),Vector3(0,.32,.035),METAL)
 led_box(Vector3(.08,.52,.03),Vector3(0,.32,.09),Color("ffe9c3"),.40)

func _window() -> void:
 var w:=3.50;var h:=1.46
 # Physical glazing and a miniature skyline; no unlit panoramic billboard.
 box(Vector3(w+.16,h+.18,.095),Vector3(0,h/2,-.015),METAL)
 box(Vector3(w,h,.015),Vector3(0,h/2,.041),Color("9caebc"))
 for i in 12:
  var bh:=.24+.07*((i*7)%8)
  var x: float=-1.58+i*.285
  box(Vector3(.22,bh,.075),Vector3(x,bh/2,.092),Color("607e95") if i%2 else Color("7d939f"))
  for row in 3:
   if .12+row*.14<bh:box(Vector3(.09,.047,.008),Vector3(x,.12+row*.14,.135),Color("b9cad1"))
 for x in [-w/2,0,w/2]:box(Vector3(.055,h+.04,.07),Vector3(x,h/2,.075),METAL)
 for y in [-.03,h+.03]:box(Vector3(w+.14,.075,.12),Vector3(0,y,.062),METAL)
 box(Vector3(w+.20,.085,.28),Vector3(0,-.10,.04),Color("b9c7cf"))
 led_box(Vector3(w-.10,.012,.018),Vector3(0,h+.064,.112),Color("8ad7e5"),.26)
 var pane:=box(Vector3(w-.10,h-.06,.002),Vector3(0,h/2,.114),Color.WHITE);pane.material_override=Modern.glass();pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var reflections:=MeshInstance3D.new();var reflection_quad:=QuadMesh.new();reflection_quad.size=Vector2(w-.1,h-.06);reflections.mesh=reflection_quad;reflections.position=Vector3(0,h/2,.118)
 var shader:=Shader.new();shader.code="shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void fragment(){float p=UV.x+UV.y*.30;float a=(1.-smoothstep(.03,.06,abs(p-.32)))*.095;float b=(1.-smoothstep(.003,.009,abs(p-.41)))*.16;ALBEDO=vec3(.84,.95,1.);ALPHA=a+b;}"
 var reflection_mat:=ShaderMaterial.new();reflection_mat.shader=shader;reflections.material_override=reflection_mat;reflections.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(reflections)

func _curtains() -> void:
 box(Vector3(3.65,.035,.035),Vector3(0,1.72,.14),METAL)
 var color:=IVORY if module_id=="curtains_ivory" else BLUE
 for side in [-1,1]:
  box(Vector3(.22,1.66,.05),Vector3(side*1.67,.85,.11),color)
  for i in 3:box(Vector3(.038,1.66,.034),Vector3(side*1.67-.068+i*.068,.85,.15),color.darkened(.045))

func _door() -> void:
 var h:=2.43;var w:=1.03
 box(Vector3(w+.16,h+.10,.10),Vector3(0,h/2,0),METAL)
 box(Vector3(w-.05,h-.08,.045),Vector3(0,h/2,.073),Color("acb8c3") if module_id!="door_glass" else Color("7c9aa8"))
 box(Vector3(.032,.18,.055),Vector3(.33,1.12,.12),METAL)
 led_box(Vector3(w-.08,.022,.02),Vector3(0,.07,.113),Color("7ddbe7"),.38)
 box(Vector3(.11,.23,.035),Vector3(-w/2-.19,1.32,.05),METAL)
 led_box(Vector3(.055,.10,.012),Vector3(-w/2-.19,1.36,.077),Color("72c8e0"),.30)

func _shelf() -> void:
 box(Vector3(1.17,.07,.30),Vector3(0,.025,.08),METAL)
 for x in [-.39,.39]:box(Vector3(.035,.17,.15),Vector3(x,-.08,.02),METAL)
 if module_id=="shelf_books":
  for i in 5:
   box(Vector3(.12,.29+float(i%2)*.04,.18),Vector3(-.39+i*.16,.20,.08),[BLUE,IVORY,Color("86aeb9")][i%3])
 led_box(Vector3(1.03,.010,.015),Vector3(0,-.016,.208),Color("ffeacd"),.22)

func _basket() -> void:
 _solid(.55,.48)
 box(Vector3(.55,.43,.48),Vector3(0,.24,-.24),Color("a6b8c5"))
 box(Vector3(.58,.045,.51),Vector3(0,.47,-.24),IVORY)
 box(Vector3(.15,.045,.024),Vector3(0,.30,.013),METAL)

func _coat_rack() -> void:
 _solid(0.54,0.55);cylinder(0.25,0.04,Vector3(0,0.04,-0.25),METAL);cylinder(0.035,1.65,Vector3(0,0.87,-0.25),WOOD)
 box(Vector3(0.67,0.05,0.055),Vector3(0,1.53,-0.25),WOOD)
 box(Vector3(0.31,0.72,0.06),Vector3(0.15,1.02,-0.21),BLUE)
