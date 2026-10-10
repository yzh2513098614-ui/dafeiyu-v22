@tool
extends RefCounted
## Editable solid models. No Sprite3D, camera-facing quads or baked object silhouettes.
const M = preload("res://modern_materials.gd")
const CREAM = Color("e3dfd1")
const BLUE = Color("53749e")
const NAVY = Color("344c6a")
const GREEN = Color("749781")
const LEAF = Color("86a28a")
const GOLD = Color("ad9360")
const STEEL = Color("526574")
const WHITE = Color("d9e0e0")
const SOIL = Color("53645a")
const LEGACY = ["blind","shutters","terminal","intercom","vent","air_conditioner","plant_broadleaf","plant_fiddle","plant_snake","plant_hanging","bonsai","succulents","flowers","fern","books","open_book","whale_mug","tea_tray","folded_blanket","light_cyan","painting_mountain","painting_whale","clock","mirror","storage_box","slippers","cushion","whale_plush","waste_bin","lantern","espresso","microwave","menu_easel","plate_rack"]
var b
static var leaf_geometry: ArrayMesh

static func leaf_mesh() -> ArrayMesh:
 if leaf_geometry!=null:return leaf_geometry
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows: Array=[]
 for y in [-.50,-.28,0.0,.28,.50]:
  var w=.32*pow(maxf(0.0,1.0-absf(y)*2.0),.65)
  rows.append([Vector3(-w,y,-.035),Vector3(0,y,.11*sin((y+.5)*PI)),Vector3(w,y,-.035)])
 for i in 4:
  for j in 2:
   var a: Vector3=rows[i][j];var z: Vector3=rows[i+1][j];var c: Vector3=rows[i+1][j+1];var d: Vector3=rows[i][j+1]
   triangle(tool,a,z,c);triangle(tool,a,c,d)
   triangle(tool,d-Vector3(0,0,.027),c-Vector3(0,0,.027),z-Vector3(0,0,.027));triangle(tool,d-Vector3(0,0,.027),z-Vector3(0,0,.027),a-Vector3(0,0,.027))
 leaf_geometry=tool.commit();return leaf_geometry
static func triangle(tool: SurfaceTool,a: Vector3,z: Vector3,c: Vector3) -> void:
 var normal=-(z-a).cross(c-a).normalized()
 if normal.length_squared()<.01:return
 for p in [a,z,c]:tool.set_normal(normal);tool.set_uv(Vector2(p.x+.5,p.y+.5));tool.add_vertex(p)

static func build(owner_node, id: String, data: Dictionary) -> bool:
 if not id.begins_with("v18_") and id not in LEGACY:return false
 var maker = new();maker.b = owner_node
 var first: int = owner_node.get_child_count()
 maker.construct(id)
 if id.begins_with("v18_"):
  maker.finish(first,float(data.get("pixel_size",.01))*float(data.size[1]),bool(data.solid))
 return true

func box(s: Vector3,p: Vector3,c: Color=CREAM) -> MeshInstance3D:
 var n = b.box(s,p,c);n.material_override=M.surface(c,c==GOLD or c==STEEL,false);return n
func ell(s: Vector3,p: Vector3,c: Color=BLUE) -> MeshInstance3D:
 var n = b.pillow(s,p,c);n.material_override=M.surface(c,false,true);return n
func cyl(r: float,h: float,p: Vector3,c: Color=CREAM) -> MeshInstance3D:
 var n = b.cylinder(r,h,p,c);n.material_override=M.surface(c,c==GOLD or c==STEEL,false);return n
func cone(rb: float,rt: float,h: float,p: Vector3,c: Color) -> MeshInstance3D:
 var mesh= CylinderMesh.new();mesh.bottom_radius=rb;mesh.top_radius=rt;mesh.height=h;mesh.radial_segments=24
 var n=MeshInstance3D.new();n.mesh=mesh;n.position=p;n.material_override=M.surface(c,false,false);b.add_child(n);return n
func rod(a: Vector3,z: Vector3,r: float=.025,c: Color=STEEL) -> MeshInstance3D:
 var n=cyl(r,a.distance_to(z),(a+z)*.5,c)
 var axis=(z-a).normalized();n.quaternion=Quaternion(Vector3.UP,axis);return n
func ring(outer: float,inner: float,p: Vector3,c: Color=GOLD,vertical: bool=false) -> MeshInstance3D:
 var mesh=TorusMesh.new();mesh.outer_radius=outer;mesh.inner_radius=inner;mesh.rings=24;mesh.ring_segments=8
 var n=MeshInstance3D.new();n.mesh=mesh;n.position=p;n.material_override=M.surface(c,c==GOLD or c==STEEL,false)
 if vertical:n.rotation.x=PI/2
 b.add_child(n);return n
func glass(s: Vector3,p: Vector3) -> void:
 var n=box(s,p,Color.WHITE);n.material_override=M.glass();n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func legs(w: float,d: float,h: float,c: Color=STEEL) -> void:
 for x in [-w/2+.07,w/2-.07]:
  for z in [-d/2+.07,d/2-.07]:box(Vector3(.085,h,.085),Vector3(x,h/2,z),c)
func handle(p: Vector3,w: float=.18) -> void:
 for x in [-w/2,w/2]:box(Vector3(.025,.04,.045),p+Vector3(x,0,0),GOLD)
 box(Vector3(w,.025,.035),p+Vector3(0,0,.025),GOLD)
func book(p: Vector3,h: float=.3,c: Color=BLUE,w: float=.10) -> void:
 box(Vector3(w,h,.24),p+Vector3(0,h/2,0),c)
 box(Vector3(w*.7,.02,.012),p+Vector3(0,h*.72,.126),GOLD)
 box(Vector3(w*.65,h-.045,.008),p+Vector3(0,h/2,-.125),CREAM)
func books(p: Vector3,n: int=5) -> void:
 for i in n:book(p+Vector3(i*.13,0,0),.27+.025*(i%3),[BLUE,GREEN,CREAM,NAVY,GOLD][i%5])
func drawer_cab(w: float,h: float,d: float,rows: int=3,c: Color=CREAM) -> void:
 legs(w,d,.13,NAVY);box(Vector3(w,h-.12,d),Vector3(0,(h+.12)/2,0),c.darkened(.05))
 box(Vector3(w+.08,.07,d+.07),Vector3(0,h,0),c)
 for row in rows:
  var y=.15+(h-.18)/rows*(row+.5)
  box(Vector3(w-.10,(h-.23)/rows-.025,.04),Vector3(0,y,d/2+.02),c)
  handle(Vector3(0,y+.035,d/2+.065))
func pot(p: Vector3,r: float=.2,h: float=.3,c: Color=CREAM) -> void:
 cone(r*.76,r,h,p+Vector3(0,h/2,0),c);ring(r+.015,r-.025,p+Vector3(0,h,0),c)
 cyl(r*.88,.02,p+Vector3(0,h+.008,0),SOIL)
func leaf(p: Vector3,a: float,size: float=.22,c: Color=LEAF) -> void:
 var n=MeshInstance3D.new();n.mesh=leaf_mesh();n.position=p;n.scale=Vector3.ONE*size;n.rotation=Vector3(.45,a,.55);n.material_override=M.surface(c,false,true);b.add_child(n)
 var vein=rod(Vector3(0,-.39,.003)*size,Vector3(0,.38,.04)*size,.006*size,c.lightened(.16))
 b.remove_child(vein);n.add_child(vein);vein.scale=Vector3.ONE;vein.position/=size
 # The central vein is expressed in the leaf's local coordinates.
 vein.mesh=vein.mesh.duplicate();vein.mesh.height=.77;vein.mesh.top_radius=.006;vein.mesh.bottom_radius=.006
func plant(p: Vector3,s: float=.8,flower: bool=false) -> void:
 pot(p,s*.24,s*.34)
 for i in 8:
  var a=TAU*i/8;var root=p+Vector3(0,s*.35,0)
  var tip=p+Vector3(cos(a)*s*.22,s*(.57+.08*(i%3)),sin(a)*s*.22)
  rod(root,tip,s*.014,GREEN);leaf(tip,a,s*.32,LEAF if i%2 else GREEN)
  if flower:
   for j in 5:
    var ang=TAU*j/5
    ell(Vector3(s*.075,s*.05,s*.075),tip+Vector3(cos(ang)*s*.058,s*.14,sin(ang)*s*.058),WHITE if i%2 else Color("a8bed7"))
   ell(Vector3(s*.045,s*.045,s*.045),tip+Vector3(0,s*.16,0),GOLD)
func trailing(p: Vector3,length: float=1) -> void:
 for i in 8:
  var q=p+Vector3(sin(i*.6)*.06,-length*i/8,.01)
  if i>0:rod(q,q+Vector3(0,length/8,0),.009,GREEN)
  leaf(q,0,.18,LEAF if i%2 else GREEN)
func whale(p: Vector3,s: float=1,c: Color=BLUE) -> void:
 ell(Vector3(s,s*.56,s*.55),p,c)
 ell(Vector3(s*.88,s*.19,s*.48),p+Vector3(-s*.035,-s*.18,s*.018),CREAM)
 for side in [-1,1]:
  var fin=ell(Vector3(s*.28,s*.08,s*.19),p+Vector3(-s*.10,-s*.12,side*s*.30),c);fin.rotation.y=side*.45
  var tail=ell(Vector3(s*.31,s*.10,s*.28),p+Vector3(s*.61,s*.12,side*s*.09),c);tail.rotation.z=-.5;tail.rotation.y=side*.6
 for side in [-1,1]:
  ell(Vector3(s*.060,s*.060,s*.030),p+Vector3(-s*.30,s*.065,side*s*.247),NAVY)
  ell(Vector3(s*.014,s*.014,s*.013),p+Vector3(-s*.306,s*.079,side*s*.267),WHITE)
  ell(Vector3(s*.065,s*.032,s*.013),p+Vector3(-s*.24,-s*.014,side*s*.269),Color("c8a9a0"))
func cup(p: Vector3,s: float=.2) -> void:
 cyl(s*.48,s,p+Vector3(0,s/2,0),CREAM);cyl(s*.38,.012,p+Vector3(0,s+.003,0),SOIL)
 var n=ring(s*.33,s*.21,p+Vector3(s*.56,s*.54,0),CREAM,true);n.rotation.y=PI/2
func tripod(p: Vector3,h: float=1.2,r: float=.5) -> void:
 cyl(.045,h,p+Vector3(0,h/2,0),NAVY)
 for i in 3:
  var a=TAU*i/3;var end=p+Vector3(cos(a)*r,.06,sin(a)*r)
  rod(p+Vector3(0,h*.68,0),end,.035,STEEL);ell(Vector3(.12,.09,.12),end,NAVY)
func light(p: Vector3,h: float=1.8,street: bool=false) -> void:
 cyl(.17,.06,p+Vector3(0,.03,0),NAVY);cyl(.035,h,p+Vector3(0,h/2,0),GOLD if not street else NAVY)
 var q=p+Vector3(0,h,0)
 if street:
  cone(.28,.12,.16,q+Vector3(0,.34,0),NAVY)
  for x in [-.16,.16]:
   for z in [-.16,.16]:box(Vector3(.025,.35,.025),q+Vector3(x,.10,z),NAVY)
  glass(Vector3(.29,.33,.29),q+Vector3(0,.10,0));box(Vector3(.39,.08,.39),q+Vector3(0,-.10,0),NAVY)
 else:cone(.26,.15,.3,q,CREAM)
 var bulb=ell(Vector3(.13,.16,.13),q,WHITE);bulb.material_override=M.led(Color("ffe2b8"),.18)
 bulb.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var lamp=OmniLight3D.new();lamp.position=q+Vector3(0,-.18,0);lamp.light_color=Color("ffe5c0");lamp.light_energy=.12;lamp.omni_range=4;b.add_child(lamp)

func construct(id: String) -> void:
 if id.begins_with("v18_buildings_") or id.begins_with("v18_special_buildings_"):
  building(id.get_slice("buildings_",1));return
 if id.begins_with("v18_interior_"):
  interior(id.trim_prefix("v18_interior_"));return
 if id.begins_with("v18_street_"):
  street(id.trim_prefix("v18_street_"));return
 if id.begins_with("v18_special_"):
  special(id.trim_prefix("v18_special_"));return
 match id.trim_prefix("v18_"):
  "whale_planter":
   whale(Vector3(0,.40,0),1.05);cyl(.30,.02,Vector3(-.08,.64,0),SOIL)
   for i in 9:
    var a=TAU*i/9;leaf(Vector3(cos(a)*.25,.81+.05*(i%3),sin(a)*.23),a,.42)
   trailing(Vector3(-.38,.70,.22),.58)
  "hydrangea":hydrangea()
  "pastry_cart":cart(true)
  "tea_cart":cart(false)
  "record_cabinet":record_cabinet()
  "reading_chair":reading_chair()
  "easel":easel(false)
  "greenhouse_shelf":greenhouse()
  "parcels":parcels()
  "sewing_basket":basket(true)
  "picnic_hamper":basket(false)
  "aquarium":aquarium(false)
  _:legacy(id)

func reuse(kind: String) -> void:
 # District modules already contain editable geometry; share their construction.
 var script=load("res://district/street_asset.gd")
 var source=Node3D.new();source.set_script(script);source.asset_kind=kind
 source._ready()
 for n in source.get_children():
  source.remove_child(n)
  if n is StaticBody3D:n.free()
  else:b.add_child(n)
 source.free()

func interior(id: String) -> void:
 match id:
  "whale_bed":
   b._bed(false);whale(Vector3(0,1.25,-2.54),.40)
   box(Vector3(1.9,.01,.12),Vector3(0,.786,-1.03),CREAM)
  "cream_sofa":b._sofa("sofa_cream")
  "ivory_bookcase":b._bookcase();plant(Vector3(.25,2.46,-.2),.45)
  "writing_desk":
   b._desk(true);books(Vector3(.43,.95,-.54),3);cup(Vector3(-.65,.95,-.38));easel_table(Vector3(-.1,.95,-.5))
  "navy_wardrobe":
   drawer_cab(1.25,1.95,.68,1,NAVY)
   for x in [-.3,.3]:
    box(Vector3(.57,1.64,.035),Vector3(x,1.08,.395),NAVY.lightened(.1));handle(Vector3(x*.3,1.1,.45),.055)
   whale(Vector3(0,1.56,.435),.27,CREAM)
  "sink_cabinet":b._kitchen("sink_counter");cup(Vector3(.47,1.01,-.3))
  "tea_table":
   b._table("coffee_table");cup(Vector3(-.2,.77,-.42));cup(Vector3(.2,.77,-.42));plant(Vector3(.4,.77,-.65),.32)
  "floor_lamp":light(Vector3.ZERO)
  "clawfoot_bath":bathtub()
  "ivory_drawers":drawer_cab(1.15,1.15,.62,4);plant(Vector3(-.28,1.19,-.1),.48)
  "blue_fridge":
   b._kitchen("fridge")
   for n in b.get_children():
    if n is MeshInstance3D and n.mesh is ArrayMesh:n.material_override=M.surface(BLUE,false,false)
  "shoe_cabinet":b._storage("shoe_cabinet");plant(Vector3(.19,1.18,-.25),.36)

func street(id: String) -> void:
 match id:
  "lantern":light(Vector3.ZERO,2.6,true)
  "bench":reuse("bench")
  "bus_shelter":
   reuse("bus_stop");glass(Vector3(.025,1.7,.85),Vector3(-1.27,1.38,.13))
   for i in 7:box(Vector3(.38,.035,.96),Vector3(-1.14+i*.38,2.43,.08),CREAM if i%2 else BLUE)
  "postbox":
   box(Vector3(.55,.95,.46),Vector3(0,.67,0),NAVY);cyl(.10,.21,Vector3(0,.105,0),NAVY)
   ell(Vector3(.56,.16,.46),Vector3(0,1.16,0),BLUE)
   box(Vector3(.34,.045,.025),Vector3(0,.98,.25),STEEL);whale(Vector3(0,.69,.25),.22,CREAM)
  "bicycle":reuse("bicycle");pot(Vector3(.46,.78,.04),.15,.20,CREAM)
  "parasol_table":
   reuse("outdoor_table");cyl(.025,2.4,Vector3(0,1.2,0),GOLD)
   var mesh=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
   for i in 16:
    var a=TAU*i/16;var z=TAU*(i+1)/16
    mesh.set_color(CREAM if i%2 else BLUE)
    for v in [Vector3(0,2.55,0),Vector3(cos(a)*1.2,2.16,sin(a)*1.2),Vector3(cos(z)*1.2,2.16,sin(z)*1.2)]:mesh.add_vertex(v)
    rod(Vector3(0,2.5,0),Vector3(cos(a)*1.17,2.16,sin(a)*1.17),.014,GOLD)
   mesh.generate_normals();var n=MeshInstance3D.new();n.mesh=mesh.commit();var mat=M.surface(WHITE,false,false).duplicate();mat.vertex_color_use_as_albedo=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;n.material_override=mat;b.add_child(n)
   cup(Vector3(.18,.81,0));cup(Vector3(-.2,.81,0))
  "flower_trough":reuse("planter");trailing(Vector3(-.5,.48,.22),.35)
  "info_board":reuse("noticeboard");box(Vector3(1.86,.09,.36),Vector3(0,2.04,0),BLUE)
  "recycling_bins":reuse("recycling")
  "whale_fountain":
   cyl(.70,.17,Vector3(0,.085,0),CREAM);cyl(.63,.025,Vector3(0,.18,0),Color("729fba"));ring(.72,.63,Vector3(0,.23,0),WHITE)
   cyl(.18,.55,Vector3(0,.43,0),CREAM);whale(Vector3(0,.98,0),1)
   for i in 5:ell(Vector3(.035,.08,.035),Vector3(-.1,.98+.11*i,0),Color("95bacc"))
  "harbor_crates":parcels(true)
  "parcel_locker":reuse("parcel_locker");whale(Vector3(.56,1.72,.34),.20,CREAM)

func reading_chair() -> void:
 legs(.86,.83,.29,NAVY)
 box(Vector3(.89,.13,.85),Vector3(0,.35,0),CREAM)
 ell(Vector3(.78,.18,.75),Vector3(0,.46,.015),BLUE)
 var back=ell(Vector3(.86,.78,.17),Vector3(0,.78,-.36),BLUE);back.rotation.x=-.12
 for x in [-.48,.48]:
  box(Vector3(.13,.47,.81),Vector3(x,.60,0),CREAM);ell(Vector3(.13,.11,.78),Vector3(x,.85,0),BLUE)
 ell(Vector3(.44,.30,.13),Vector3(.08,.65,-.19),CREAM)
 for x in [-.12,.02,.16]:box(Vector3(.055,.25,.012),Vector3(x,.66,-.11),WHITE)
 for x in [-.31,.31]:rod(Vector3(x,.51,.29),Vector3(x,.51,-.27),.006,BLUE.lightened(.2))
 rod(Vector3(-.30,.93,-.26),Vector3(.30,.93,-.26),.006,BLUE.lightened(.2))

func hydrangea() -> void:
 pot(Vector3.ZERO,.31,.42)
 for i in 7:
  var a=TAU*i/7;leaf(Vector3(cos(a)*.29,.64,sin(a)*.26),a,.39,GREEN if i%2 else LEAF)
 for spec in [[Vector3(-.21,.86,.04),.23],[Vector3(.18,.93,.08),.25],[Vector3(.04,.99,-.23),.24],[Vector3(-.04,.75,.27),.20]]:
  var p: Vector3=spec[0];var r: float=spec[1]
  rod(Vector3(0,.44,0),p,.019,GREEN)
  ell(Vector3.ONE*r*1.70,p,Color("bac8c4") if p.x>.1 else Color("91a9bf"))
  # Merge the small, fully volumetric petal meshes into one flower head.
  var mesh=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
  var petal=SphereMesh.new();petal.radius=.5;petal.height=1.;petal.radial_segments=8;petal.rings=2
  for j in 48:
   var y=1.-2.*(j+.5)/48.;var a=j*2.39996;var radial=sqrt(1.-y*y)
   var normal=Vector3(cos(a)*radial,y,sin(a)*radial)
   var tangent=Basis(Quaternion(Vector3.UP,normal))
   var q=p+normal*r*.85
   for k in 5:
    var ang=TAU*k/5
    var center=q+tangent*Vector3(cos(ang)*.025,.009,sin(ang)*.025)
    mesh.append_from(petal,0,Transform3D(tangent.scaled_local(Vector3(.059,.022,.059)),center))
  var head=MeshInstance3D.new();head.mesh=mesh.commit();head.material_override=M.surface(Color("d2dcd6") if p.x>.1 else Color("b7c9df"),false,true);b.add_child(head)

func cart(pastry: bool) -> void:
 var w=1.35;var d=.66
 for x in [-.53,.53]:
  for z in [-.22,.22]:
   var wheel=cyl(.10,.045,Vector3(x,.11,z),NAVY);wheel.rotation.z=PI/2
   rod(Vector3(x,.12,z),Vector3(x,.27,z),.02,STEEL)
 box(Vector3(w,.06,d),Vector3(0,.25,0),NAVY)
 if pastry:
  drawer_cab(w,.82,d,1)
  for x in [-.63,.63]:box(Vector3(.045,1.28,.045),Vector3(x,1.16,-.25),CREAM)
  for i in 8:
   var top=box(Vector3(.18,.055,.96),Vector3(-.63+i*.18,1.8,0),BLUE if i%2 else CREAM);top.rotation.x=.20
   box(Vector3(.18,.17,.055),Vector3(-.63+i*.18,1.66,.46),BLUE if i%2 else CREAM)
  box(Vector3(.84,.025,.46),Vector3(-.12,1.12,0),CREAM)
  for x in [-.53,.30]:box(Vector3(.025,.33,.42),Vector3(x,1.01,0),GOLD)
  glass(Vector3(.80,.31,.015),Vector3(-.12,1.0,.215));glass(Vector3(.80,.015,.42),Vector3(-.12,1.16,0))
  for i in 5:ell(Vector3(.17,.10,.14),Vector3(-.45+i*.16,.92,.04),GOLD.lightened(.13))
  cup(Vector3(.51,.87,0));plant(Vector3(.42,1.22,-.13),.26)
 else:
  for x in [-w/2+.05,w/2-.05]:
   for z in [-d/2+.05,d/2-.05]:box(Vector3(.045,.8,.045),Vector3(x,.64,z),GOLD)
  box(Vector3(w,.07,d),Vector3(0,1.04,0),CREAM)
  rod(Vector3(-.68,1.08,-.31),Vector3(-.68,1.22,-.31),.023,GOLD)
  rod(Vector3(.68,1.08,-.31),Vector3(.68,1.22,-.31),.023,GOLD)
  rod(Vector3(-.68,1.22,-.31),Vector3(.68,1.22,-.31),.023,GOLD)
  cup(Vector3(.28,1.08,.04));cup(Vector3(-.19,.3,.07));books(Vector3(.13,.3,-.05),3)
  cone(.16,.12,.32,Vector3(-.28,1.27,-.02),CREAM);cone(.17,.06,.07,Vector3(-.28,1.47,-.02),GOLD)
  rod(Vector3(-.43,1.28,-.02),Vector3(-.55,1.51,-.02),.032,CREAM);plant(Vector3(.4,1.08,-.14),.34)

func record_cabinet() -> void:
 shelf(1.0,1.45,.50,3,NAVY)
 for row in 2:books(Vector3(-.38,.16+row*.43,.05),6)
 box(Vector3(1.05,.06,.55),Vector3(0,1.51,0),BLUE)
 cyl(.23,.025,Vector3(0,1.56,0),NAVY);cyl(.05,.03,Vector3(0,1.58,0),CREAM)
 rod(Vector3(.36,1.57,-.16),Vector3(.12,1.59,.13),.016,GOLD)
 var lid=box(Vector3(1.0,.035,.51),Vector3(0,1.85,-.2),BLUE);lid.rotation.x=-.8
 glass(Vector3(.90,.02,.42),Vector3(0,1.855,-.20))
func shelf(w: float,h: float,d: float,rows: int=3,c: Color=CREAM) -> void:
 for x in [-w/2,w/2]:box(Vector3(.075,h,d),Vector3(x,h/2,0),c)
 box(Vector3(w,h,.035),Vector3(0,h/2,-d/2),c.darkened(.09))
 for row in rows+1:box(Vector3(w+.05,.055,d),Vector3(0,.12+(h-.12)*row/rows,0),c)
func greenhouse() -> void:
 var w=1.;var h=1.65;var d=.53
 for x in [-w/2,w/2]:
  for z in [-d/2,d/2]:box(Vector3(.04,h,.04),Vector3(x,h/2,z),CREAM)
 for row in 3:
  var y=.12+row*.43;box(Vector3(w,.05,d),Vector3(0,y,0),CREAM)
  plant(Vector3(-.26,y+.03,0),.48);plant(Vector3(.23,y+.03,0),.48,true)
 glass(Vector3(.012,h-.1,d),Vector3(-w/2,h/2,0));glass(Vector3(.012,h-.1,d),Vector3(w/2,h/2,0));glass(Vector3(w,h-.1,.012),Vector3(0,h/2,-d/2))
 for side in [-1,1]:
  var roof=box(Vector3(.58,.035,d+.06),Vector3(side*.26,h+.12,0),CREAM);roof.rotation.z=-side*.5
  var pane=box(Vector3(.51,.012,d),Vector3(side*.26,h+.14,0),WHITE);pane.rotation.z=-side*.5;pane.material_override=M.glass()
 trailing(Vector3(-.52,h+.1,.28),1.28)
func parcels(harbor: bool=false) -> void:
 for spec in [[Vector3(1,.58,.62),Vector3(0,.29,0)],[Vector3(.53,.38,.46),Vector3(-.20,.79,-.04)],[Vector3(.40,.23,.35),Vector3(.32,.71,.05)]]:
  box(spec[0],spec[1],NAVY if harbor else CREAM);box(Vector3(.075,.012,spec[0].z+.012),spec[1]+Vector3(0,spec[0].y/2+.01,0),BLUE)
  box(Vector3(.17,.10,.012),spec[1]+Vector3(.11,.02,spec[0].z/2+.007),WHITE)
 whale(Vector3(-.16,.30,.325),.22,CREAM if harbor else BLUE)
func basket(sewing: bool) -> void:
 var c=GREEN if sewing else CREAM
 box(Vector3(.73,.40,.47),Vector3(0,.20,0),c)
 for i in 7:box(Vector3(.75,.017,.49),Vector3(0,.04+i*.05,0),c.lightened(.13))
 for x in [-.35,.35]:
  rod(Vector3(x,.42,0),Vector3(x,.70,0),.028,NAVY)
 rod(Vector3(-.35,.7,0),Vector3(.35,.7,0),.035,NAVY)
 if sewing:
  for i in 3:cyl(.055,.22,Vector3(-.2+i*.15,.49,0),[BLUE,CREAM,GOLD][i])
  ell(Vector3(.18,.13,.18),Vector3(.15,.46,.08),BLUE);rod(Vector3(.14,.48,.08),Vector3(.19,.72,.08),.008,STEEL)
 else:
  box(Vector3(.77,.05,.51),Vector3(0,.435,0),CREAM)
  for x in [-.23,.23]:box(Vector3(.055,.37,.035),Vector3(x,.25,.25),NAVY);handle(Vector3(x,.29,.285),.065)
 box(Vector3(.23,.06,.46),Vector3(.20,.48,0),WHITE)
 for z in [-.12,0,.12]:box(Vector3(.23,.008,.045),Vector3(.20,.518,z),BLUE)
func aquarium(tall: bool) -> void:
 var w=1.05;var d=.59;var base=.82 if tall else .38;var h=.69
 if tall:drawer_cab(w,base,d,2)
 else:legs(w,d,base-.06,NAVY);box(Vector3(w+.08,.08,d+.06),Vector3(0,base-.04,0),NAVY)
 box(Vector3(w,.035,d),Vector3(0,base,0),CREAM)
 for x in [-w/2,w/2]:
  for z in [-d/2,d/2]:box(Vector3(.019,h,.019),Vector3(x,base+h/2,z),GOLD)
 for z in [-d/2,d/2]:glass(Vector3(w,h,.01),Vector3(0,base+h/2,z))
 for x in [-w/2,w/2]:glass(Vector3(.01,h,d),Vector3(x,base+h/2,0))
 glass(Vector3(w,.013,d),Vector3(0,base+h-.08,0))
 for i in 8:ell(Vector3(.1,.055,.08),Vector3(-.42+i*.12,base+.06,sin(i)*.18),WHITE if i%2 else BLUE)
 for x in [-.36,.34]:
  for i in 4:leaf(Vector3(x+sin(i)*.035,base+.16+i*.1,-.15),i*.8,.18,GREEN)
 whale(Vector3(0,base+.34,.01),.37,WHITE)
 if tall:rod(Vector3(-.46,base+h,-.24),Vector3(-.46,base+h+.32,-.24),.017,GOLD);cone(.18,.05,.12,Vector3(-.46,base+h+.32,-.1),NAVY)
func easel(menu: bool) -> void:
 for x in [-.35,.35]:rod(Vector3(x,.04,.20),Vector3(x*.42,1.58,-.13),.032,CREAM)
 rod(Vector3(0,.04,-.4),Vector3(0,1.38,-.13),.032,CREAM)
 box(Vector3(.82,.055,.28),Vector3(0,.51,0),GOLD)
 box(Vector3(.79,.91,.065),Vector3(0,1.05,-.07),CREAM)
 box(Vector3(.68,.8,.02),Vector3(0,1.05,-.02),NAVY if menu else Color("a9c1d1"))
 if menu:
  for i in 5:box(Vector3(.46-i*.03,.016,.005),Vector3(0,1.28-i*.12,-.006),CREAM)
 else:
  box(Vector3(.65,.29,.014),Vector3(0,.84,-.004),BLUE);ell(Vector3(.23,.04,.014),Vector3(.16,1.21,.008),CREAM)
  for i in 3:box(Vector3(.37,.012,.01),Vector3(-.12+i*.07,.91+i*.06,.01),WHITE)
func easel_table(p: Vector3) -> void:
 box(Vector3(.5,.015,.33),p+Vector3(0,.01,0),BLUE)
 for i in 4:box(Vector3(.3-i*.045,.007,.005),p+Vector3(0,.021,-.10+i*.055),CREAM)
func bathtub() -> void:
 for x in [-.67,.67]:
  for z in [-.27,.27]:ell(Vector3(.16,.15,.13),Vector3(x,.10,z),GOLD)
 ell(Vector3(1.8,.60,.83),Vector3(0,.43,0),CREAM)
 ell(Vector3(1.53,.14,.63),Vector3(0,.64,0),BLUE.darkened(.1))
 ell(Vector3(1.40,.07,.54),Vector3(0,.66,0),Color("a4c5cc"))
 rod(Vector3(.68,.60,-.24),Vector3(.68,.94,-.24),.025,GOLD);rod(Vector3(.68,.94,-.24),Vector3(.43,.94,-.24),.025,GOLD)
 box(Vector3(.31,.05,.38),Vector3(-.54,.75,0),WHITE)

func special(id: String) -> void:
 match id:
  "telescope":
   tripod(Vector3.ZERO,1.3,.55)
   var a=Vector3(-.43,1.90,0);var z=Vector3(.45,1.50,0)
   rod(a,z,.20,CREAM);rod(a,a+(a-z).normalized()*.07,.225,NAVY);rod(a,a+(a-z).normalized()*.085,.17,Color("567e9d"))
   rod(z,z+(z-a).normalized()*.23,.058,GOLD)
   rod(Vector3(.13,1.65,-.20),Vector3(-.18,1.79,-.20),.045,BLUE)
   for x in [-.15,.25]:rod(Vector3(x,1.70-x*.4,0),Vector3(x+.02,1.75-x*.4,0),.205,NAVY)
  "weather_station":
   box(Vector3(.83,.30,.58),Vector3(0,.15,0));tripod(Vector3(0,.32,0),1.4,.32)
   for i in 5:cyl(.15,.025,Vector3(-.27,1.22+i*.05,0),CREAM)
   box(Vector3(.24,.32,.15),Vector3(.25,1.13,0),NAVY);cyl(.075,.024,Vector3(.25,1.13,.09),CREAM).rotation.x=PI/2
   for i in 3:
    var a=TAU*i/3;var end=Vector3(cos(a)*.34,1.77,sin(a)*.34)
    rod(Vector3(0,1.77,0),end,.012,STEEL);ell(Vector3(.12,.09,.12),end,NAVY)
   box(Vector3(.22,.22,.015),Vector3(.18,1.90,-.04),BLUE);plant(Vector3(-.27,.31,0),.47,true)
  "specimen_tank":aquarium(true)
  "radio_console":workbench("radio")
  "star_desk":workbench("star")
  "mixing_console":workbench("mixing")
  "chart_cabinet":
   drawer_cab(.77,1.27,.53,4);plant(Vector3(-.19,1.31,-.08),.38)
   for i in 3:
    cyl(.053,.91,Vector3(.49, .63,-.18+i*.17),CREAM)
    ring(.065,.051,Vector3(.49,.36,-.18+i*.17),GOLD)
   trailing(Vector3(-.41,1.39,.14),.70)
  "upright_piano":piano()
  "drum_kit":drums()
  "guitar_stand":guitar()
  "speaker_stack":
   for spec in [[Vector3(.73,.75,.45),Vector3(0,.42,0)],[Vector3(.62,.59,.40),Vector3(0,1.10,0)]]:
    box(spec[0],spec[1],NAVY);var q=spec[1]+Vector3(0,0,spec[0].z/2+.021)
    ring(spec[0].x*.32,spec[0].x*.27,q,CREAM,true);cyl(spec[0].x*.25,.025,q,NAVY.darkened(.3)).rotation.x=PI/2
    ell(Vector3(.09,.09,.04),q+Vector3(0,0,.024),STEEL)
   ring(.07,.045,Vector3(0,1.29,.225),CREAM,true);plant(Vector3(.1,1.42,0),.43);trailing(Vector3(-.3,1.43,.20),.64)
  "microphone":
   tripod(Vector3.ZERO,1.45,.38);cyl(.066,.25,Vector3(0,1.6,0),GOLD)
   ell(Vector3(.14,.14,.14),Vector3(0,1.75,0),CREAM)
   for i in 5:ring(.069,.064,Vector3(0,1.52+i*.04,0),STEEL)
   rod(Vector3(0,1.38,0),Vector3(-.20,1.69,.09),.012,STEEL);ring(.12,.09,Vector3(-.20,1.7,.09),NAVY,true)
   cyl(.091,.018,Vector3(-.20,1.7,.09),NAVY).rotation.x=PI/2
func workbench(kind: String) -> void:
 drawer_cab(1.4,.78,.70,2);box(Vector3(1.47,.08,.77),Vector3(0,.83,0),CREAM)
 if kind=="mixing":
  var panel=box(Vector3(1.25,.065,.55),Vector3(0,.94,.015),NAVY);panel.rotation.x=-.15
  for col in 8:
   var x=-.53+col*.15
   box(Vector3(.015,.012,.27),Vector3(x,.99,.07),STEEL);box(Vector3(.068,.032,.025),Vector3(x,1.01,-.01+.04*(col%3)),CREAM)
   for row in 3:cyl(.022,.029,Vector3(x,1.04,-.19+row*.055),GOLD if row==0 else BLUE)
  for x in [-.40,0,.40]:box(Vector3(.29,.17,.055),Vector3(x,1.13,-.28),CREAM);box(Vector3(.23,.10,.014),Vector3(x,1.13,-.242),GOLD)
 elif kind=="radio":
  box(Vector3(.70,.36,.36),Vector3(-.19,1.08,-.09),NAVY)
  box(Vector3(.26,.11,.015),Vector3(-.13,1.16,.103),GOLD)
  for i in 4:cyl(.026,.02,Vector3(-.44+i*.13,.99,.104),CREAM).rotation.x=PI/2
  for i in 6:box(Vector3(.012,.14,.009),Vector3(-.45+i*.025,1.15,.104),CREAM)
  rod(Vector3(.10,1.26,-.24),Vector3(.10,1.84,-.24),.010,GOLD)
  books(Vector3(.31,.88,-.04),3);easel_table(Vector3(-.1,.88,.20))
 else:
  easel_table(Vector3(-.14,.89,.03))
  for r in [.07,.15,.22]:ring(r,r-.006,Vector3(-.14,.915,.03),CREAM)
  books(Vector3(.34,.88,-.03),3);cup(Vector3(.52,.88,.17))
 plant(Vector3(-.54,.88,-.20),.33)
 rod(Vector3(-.59,.88,-.27),Vector3(-.59,1.47,-.27),.015,GOLD);cone(.12,.06,.13,Vector3(-.48,1.43,-.24),NAVY)
func piano() -> void:
 legs(1.37,.54,.32,NAVY);box(Vector3(1.38,1.11,.37),Vector3(0,.84,-.11),CREAM)
 box(Vector3(1.40,.12,.25),Vector3(0,.80,.15),NAVY)
 for i in 24:
  var x=-.60+i*.052
  box(Vector3(.048,.025,.22),Vector3(x,.877,.18),WHITE)
  if i%7 not in [2,6]:box(Vector3(.027,.032,.12),Vector3(x+.024,.904,.135),NAVY)
 for x in [-.68,.68]:box(Vector3(.07,1.18,.48),Vector3(x,.78,0),CREAM)
 box(Vector3(1.46,.07,.44),Vector3(0,1.47,-.09),CREAM)
 box(Vector3(.51,.29,.045),Vector3(0,1.10,.101),CREAM);box(Vector3(.006,.27,.007),Vector3(0,1.10,.13),GOLD)
 for i in 5:box(Vector3(.42,.009,.007),Vector3(0,1.20-i*.046,.13),STEEL)
 for x in [-.15,0,.15]:box(Vector3(.06,.03,.14),Vector3(x,.15,.15),GOLD)
 ell(Vector3(.59,.13,.40),Vector3(0,.49,.71),BLUE)
 # Separate stool feet, correctly under the detached padded seat.
 for x in [-.23,.23]:
  for z in [.59,.83]:box(Vector3(.045,.43,.045),Vector3(x,.23,z),GOLD)
 plant(Vector3(.48,1.51,-.10),.27,true)
func drum(p: Vector3,r: float,h: float,vertical: bool=false) -> void:
 var n=cyl(r,h,p,BLUE)
 if vertical:n.rotation.x=PI/2
 var axis=Vector3(0,0,h/2) if vertical else Vector3(0,h/2,0)
 for side in [-1,1]:
  var n2=cyl(r+.009,.017,p+axis*side,CREAM)
  if vertical:n2.rotation.x=PI/2
  ring(r+.025,r-.008,p+axis*side,GOLD,vertical)
 for i in 8:
  var a=TAU*i/8;var q=Vector3(cos(a)*r,0,sin(a)*r)
  if vertical:q=Vector3(cos(a)*r,sin(a)*r,0)
  rod(p+q-axis*.8,p+q+axis*.8,.009,GOLD)
func drums() -> void:
 drum(Vector3(0,.44,.24),.40,.37,true)
 drum(Vector3(-.29,.99,-.07),.23,.30);drum(Vector3(.25,.90,-.03),.25,.27)
 drum(Vector3(.63,.54,.08),.27,.33)
 for x in [-.62,.62]:
  tripod(Vector3(x,0,-.28),1.22,.25);cone(.34,.07,.035,Vector3(x,1.24,-.28),GOLD);cyl(.019,.11,Vector3(x,1.28,-.28),GOLD)
 whale(Vector3(0,.45,.44),.22,BLUE)
 cyl(.14,.06,Vector3(0,.49,-.60),BLUE);tripod(Vector3(0,0,-.60),.44,.18)
func guitar() -> void:
 box(Vector3(.62,.07,.45),Vector3(0,.055,0),GREEN)
 for x in [-.23,.23]:rod(Vector3(x,.08,.16),Vector3(x,.48,-.12),.028,GREEN)
 ell(Vector3(.46,.48,.13),Vector3(0,.42,0),NAVY)
 ell(Vector3(.35,.31,.13),Vector3(0,.70,0),NAVY)
 box(Vector3(.105,.72,.07),Vector3(0,1.03,0),GOLD)
 box(Vector3(.14,.21,.075),Vector3(0,1.46,0),NAVY)
 cyl(.083,.022,Vector3(0,.67,.079),CREAM).rotation.x=PI/2
 cyl(.063,.026,Vector3(0,.67,.09),NAVY).rotation.x=PI/2
 box(Vector3(.19,.025,.027),Vector3(0,.37,.082),CREAM)
 for i in 6:
  rod(Vector3(-.025+i*.01,.38,.101),Vector3(-.025+i*.01,1.52,.05),.0017,CREAM)
  cyl(.023,.035,Vector3(.095 if i%2 else -.095,1.41+float(i/2)*.057,0),GOLD).rotation.z=PI/2
 for i in 10:box(Vector3(.108,.008,.006),Vector3(0,.88+i*.046,.042),CREAM)

func building(kind: String) -> void:
 var levels=3 if kind in ["apartment","observatory"] else (2 if kind in ["bookstore","gallery","music","cafe"] else 1)
 var w=3.5;var d=2.4;var h=levels*2.05+.40
 box(Vector3(w+.30,.20,d+.30),Vector3(0,.10,0),STEEL)
 # Solid side and back walls. Door and shop windows are actual separate openings.
 for x in [-w/2,w/2]:box(Vector3(.18,h,d),Vector3(x,h/2+.18,0),CREAM)
 box(Vector3(w,h,.18),Vector3(0,h/2+.18,-d/2),CREAM)
 for floor_index in levels:
  var y=.23+floor_index*2.05
  box(Vector3(w,.14,d),Vector3(0,y,0),CREAM)
  box(Vector3(w,.36,.18),Vector3(0,y+1.93,d/2),CREAM)
  for col in [-1,0,1]:
   var x=col*1.12
   for edge in [-.50,.50]:box(Vector3(.08,1.59,.16),Vector3(x+edge,y+1.01,d/2),BLUE)
   box(Vector3(.92,.10,.17),Vector3(x,y+.26,d/2),BLUE)
   glass(Vector3(.94,1.42,.045),Vector3(x,y+1.01,d/2))
   box(Vector3(.035,1.40,.10),Vector3(x,y+1.01,d/2+.04),CREAM)
   if floor_index>0:
    box(Vector3(.95,.07,.12),Vector3(x,y+1.05,d/2+.02),CREAM)
    box(Vector3(1.06,.18,.31),Vector3(x,y+.22,d/2+.12),BLUE)
    for i in 3:leaf(Vector3(x-.3+i*.3,y+.45,d/2+.18),i,.25,GREEN)
   elif col!=0:
    for i in 3:
     if kind=="bookstore":books(Vector3(x-.32,y+.30+i*.37,d/2-.10),5)
     elif kind=="florist":plant(Vector3(x-.28+i*.27,y+.28,d/2-.14),.43,true)
     elif kind in ["cafe","bakery"]:ell(Vector3(.20,.13,.15),Vector3(x-.28+i*.26,y+.32,d/2-.08),GOLD)
  box(Vector3(.92,.10,.12),Vector3(0,y+1.65,d/2),BLUE)
  for x in [-.48,.48]:box(Vector3(.08,1.55,.16),Vector3(x,y+.85,d/2),BLUE)
  if floor_index==0:
   glass(Vector3(.40,1.4,.03),Vector3(-.23,y+.88,d/2));handle(Vector3(-.12,y+.83,d/2+.04),.06)
 if kind=="observatory":
  cyl(1.65,.22,Vector3(0,h+.32,0),BLUE)
  var mesh=SphereMesh.new();mesh.radius=1.5;mesh.height=3.;mesh.is_hemisphere=true;mesh.radial_segments=32;mesh.rings=16
  var dome=MeshInstance3D.new();dome.mesh=mesh;dome.position=Vector3(0,h+.40,0);dome.material_override=M.surface(BLUE,false,false);b.add_child(dome)
  box(Vector3(.35,1.45,.12),Vector3(0,h+1.05,1.05),CREAM).rotation.x=-.60
 elif kind=="gallery":
  for i in 3:
   var roof=box(Vector3(1.25,.10,d+.2),Vector3(-1.13+i*1.13,h+.27,0),BLUE);roof.rotation.z=-.25
   glass(Vector3(.72,.03,d*.60),Vector3(-1.25+i*1.13,h+.40,-.1))
 elif kind=="music":
  box(Vector3(w+.22,.18,d+.24),Vector3(0,h+.28,0),BLUE)
  for x in [-1.15,1.15]:cyl(.12,1.8,Vector3(x,h+1.12,0),GOLD);ell(Vector3(.45,.22,.30),Vector3(x+.13,h+.40,.03),NAVY)
  rod(Vector3(-1.15,h+2.0,0),Vector3(1.15,h+1.8,0),.08,GOLD)
 else:
  for side in [-1,1]:box(Vector3(w/2+.28,.12,d+.38),Vector3(side*w/4,h+.62,0),BLUE).rotation.z=-side*.34
  box(Vector3(.12,.12,d+.44),Vector3(0,h+.94,0),CREAM)
  if kind=="apartment":
   for x in [-1.18,1.18]:box(Vector3(.48,.68,.55),Vector3(x,h+.74,0),CREAM)
 if kind in ["cafe","bakery","florist","bookstore"]:
  for i in 12:
   var roof=box(Vector3(.31,.05,.95),Vector3(-1.705+i*.31,2.02,d/2+.35),CREAM if i%2 else BLUE);roof.rotation.x=.20
   box(Vector3(.31,.18,.045),Vector3(-1.705+i*.31,1.85,d/2+.81),CREAM if i%2 else BLUE)
  box(Vector3(1.35,.38,.12),Vector3(0,2.46,d/2+.1),NAVY);whale(Vector3(0,2.46,d/2+.2),.45,CREAM)
 for x in [-1.5,1.5]:plant(Vector3(x,.20,d/2+.5),.66,kind=="florist")

func legacy(id: String) -> void:
 match id:
  "plant_broadleaf","plant_fiddle","plant_snake","plant_hanging","bonsai","succulents","flowers","fern":
   var s=1.1 if id in ["plant_broadleaf","plant_fiddle","plant_snake"] else .45
   plant(Vector3.ZERO,s,id=="flowers")
   if id=="plant_hanging":trailing(Vector3(0,.31,.1),.62)
  "books":books(Vector3(-.24,0,0),4)
  "open_book":
   for side in [-1,1]:box(Vector3(.22,.025,.29),Vector3(side*.11,.04,0),CREAM).rotation.z=side*.12
   for i in 4:box(Vector3(.17,.006,.008),Vector3(.11,.075,-.08+i*.045),STEEL)
  "whale_mug":cup(Vector3.ZERO,.23);whale(Vector3(0,.11,.116),.085,BLUE)
  "tea_tray":box(Vector3(.67,.025,.44),Vector3(0,.025,0),GOLD);cup(Vector3(-.18,.04,0));cup(Vector3(.18,.04,0))
  "folded_blanket":
   for i in 3:box(Vector3(.55,.055,.36),Vector3(0,.045+i*.055,0),BLUE if i%2 else WHITE)
  "cushion":ell(Vector3(.48,.17,.48),Vector3(0,.1,0),BLUE)
  "whale_plush":whale(Vector3(0,.18,0),.58)
  "storage_box":parcels()
  "slippers":
   for x in [-.13,.13]:ell(Vector3(.18,.095,.35),Vector3(x,.05,0),NAVY);ell(Vector3(.17,.11,.15),Vector3(x,.08,-.10),BLUE)
  "waste_bin":cone(.18,.23,.45,Vector3(0,.225,0),NAVY);ring(.25,.21,Vector3(0,.46,0),CREAM)
  "lantern":light(Vector3.ZERO,.26,true)
  "painting_whale","painting_mountain":
   box(Vector3(.86,.68,.055),Vector3(0,.34,0),GOLD);box(Vector3(.76,.58,.021),Vector3(0,.34,.038),BLUE)
   if id=="painting_whale":whale(Vector3(0,.34,.065),.4,CREAM)
   else:
    for i in 3:cone(.19,.0,.28+.08*i,Vector3(-.23+i*.23,.28,.06),CREAM)
  "clock":
   cyl(.27,.045,Vector3(0,.27,0),NAVY).rotation.x=PI/2;cyl(.24,.016,Vector3(0,.27,.035),CREAM).rotation.x=PI/2
   rod(Vector3(0,.27,.05),Vector3(.12,.27,.05),.009,NAVY);rod(Vector3(0,.27,.05),Vector3(0,.44,.05),.009,NAVY)
  "mirror":box(Vector3(.6,.92,.045),Vector3(0,.46,0),GOLD);box(Vector3(.54,.85,.012),Vector3(0,.46,.032),Color("9dadb7"))
  "espresso":
   box(Vector3(.53,.35,.31),Vector3(0,.21,0),NAVY);box(Vector3(.42,.19,.08),Vector3(0,.24,.18),STEEL);cup(Vector3(.13,.035,.18),.13)
   cyl(.06,.04,Vector3(-.12,.32,.225),CREAM).rotation.x=PI/2
  "microwave":box(Vector3(.65,.38,.38),Vector3(0,.19,0),CREAM);box(Vector3(.46,.26,.012),Vector3(-.07,.19,.201),NAVY);handle(Vector3(.20,.19,.23),.06)
  "menu_easel":easel(true)
  "plate_rack":
   box(Vector3(.75,.065,.28),Vector3(0,.04,0),CREAM)
   for i in 6:
    cyl(.14,.021,Vector3(-.30+i*.12,.19,0),WHITE).rotation.z=PI/2
    rod(Vector3(-.35+i*.12,.07,-.13),Vector3(-.35+i*.12,.24,-.13),.009,GOLD)
  "blind","shutters":
   for i in 12:box(Vector3(1.8,.07,.055),Vector3(0,.08+i*.085,0),CREAM)
   for x in [-.81,.81]:box(Vector3(.025,1.14,.055),Vector3(x,.54,.05),BLUE)
  "air_conditioner":
   box(Vector3(1.0,.32,.22),Vector3(0,.16,0),WHITE)
   for i in 6:box(Vector3(.8,.012,.015),Vector3(0,.07+i*.028,.12),STEEL)
  "vent":
   box(Vector3(.42,.42,.045),Vector3(0,.21,0),WHITE)
   for i in 7:box(Vector3(.34,.016,.015),Vector3(0,.07+i*.045,.03),STEEL)
  "light_cyan":b.led_box(Vector3(.75,.065,.045),Vector3(0,.04,0),Color("84b9c3"),.18)
  "terminal","intercom":
   box(Vector3(.25,.46,.09),Vector3(0,.23,0),NAVY);box(Vector3(.18,.15,.008),Vector3(0,.32,.052),BLUE)
   for i in 3:box(Vector3(.11,.014,.008),Vector3(0,.14+i*.034,.052),WHITE)
  _:push_error("Missing solid environment model: "+id)

func gather(node: Node,transform: Transform3D,bounds: Array) -> void:
 var next=transform
 if node is Node3D:next=transform*node.transform
 if node is MeshInstance3D and node.mesh!=null:bounds.append(next*node.mesh.get_aabb())
 for child in node.get_children():gather(child,next,bounds)
func finish(first: int,target_height: float,solid: bool) -> void:
 var bounds: Array=[];var nodes: Array=[]
 for i in range(first,b.get_child_count()):
  var n=b.get_child(i);nodes.append(n);gather(n,Transform3D.IDENTITY,bounds)
 if bounds.is_empty():return
 var bound: AABB=bounds[0]
 for a in bounds:bound=bound.merge(a)
 var factor=target_height/maxf(bound.size.y,.01)
 factor=clampf(factor,.20,3.5)
 var shift=Vector3(-bound.get_center().x,-bound.position.y,-bound.end.z)
 for n in nodes:
  if n is Node3D:n.position=(n.position+shift)*factor;n.scale*=factor
 if solid:
  # Front anchored, matching the existing placement/floor-fitting convention.
  b.collision_width=bound.size.x*factor;b.collision_depth=bound.size.z*factor
  b.collision_height=minf(.80,target_height)
  if target_height>4:b.collision_height=target_height
