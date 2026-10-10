extends RefCounted
## Room-scale dressing follows each actual rectangle, with no furniture in doorways.
const Models=preload("res://environment_models.gd")
const M=preload("res://modern_materials.gd")
const ThemedProps=preload("res://district/themed_props.gd")
const ThemedWalls=preload("res://district/themed_walls.gd")
const Shape=preload("res://district/space_shape.gd")
static func build(g,rect: Rect2,kind: String,south: bool,index: int,door: Vector3=Vector3.ZERO,polygon: PackedVector2Array=PackedVector2Array(),access: Array=[],external_edges: Array=[]) -> void:
 var holder=Node3D.new();holder.name="RoomTheme_"+kind+"_"+str(index);g.shell.add_child(holder)
 var b=g._builder(holder);var m=Models.new();m.b=b
 var center=rect.get_center();holder.position=Vector3(center.x,0,center.y)
 if south:holder.rotation.y=PI
 if not polygon.is_empty():holder.set_meta("decor_polygon",Shape.local_polygon(holder,polygon))
 var local_access: Array=[]
 for area: Rect2 in access:
  var outline: PackedVector2Array=Shape.local_polygon(holder,Shape.rectangle(area))
  var local_rect:=Rect2(outline[0],Vector2.ZERO)
  for point in outline:local_rect=local_rect.expand(point)
  local_access.append(local_rect)
 if not local_access.is_empty():holder.set_meta("decor_access",local_access)
 var w=rect.size.x;var d=rect.size.y;var back=-d/2+.15
 if ThemedWalls.supports(kind):
  ThemedProps.dress(holder,kind,w,d,holder.to_local(door))
  return
 if not polygon.is_empty():
  _contour_accents(g,holder,polygon,external_edges)
  return
 var color=Color("a8beb7")
 if kind in ["performance","recording","mixing","rehearsal","percussion","piano_room","vinyl_library"]:color=Color("637a91")
 elif kind in ["ocean_exhibit","aquatic_lab","sky_observation","planetarium","chart_lab","weather_lab","navigation_archive"]:color=Color("8aa6b8")
 elif kind in ["bedroom","guest","living","lounge"]:color=Color("b8b1a2")
 elif kind in ["work","craft","songwriting","instrument_repair"]:color=Color("93aaa5")
 elif kind.begins_with("restaurant_"):color=Color("b9ab94")
 elif kind.begins_with("school_"):color=Color("8caea7")
 elif kind.begins_with("hospital_"):color=Color("a4bcc8")
 # A low inset wainscot respects the cutaway wall height in both room rows.
 m.box(Vector3(w-.45,.62,.035),Vector3(0,.44,back),color)
 m.box(Vector3(w-.4,.045,.06),Vector3(0,.77,back+.025),Models.CREAM)
 if kind in ["performance","rehearsal","piano_room"]:
  # Curtains flank the performance area; an open central aisle stays visible.
  for side in [-1,1]:
   m.rod(Vector3(side*w*.34,.05,back+.02),Vector3(side*w*.34,1.83,back+.02),.025,Models.GOLD)
   m.rod(Vector3(side*w*.33,1.83,back+.04),Vector3(side*(w*.33+.52),1.83,back+.04),.023,Models.GOLD)
   for i in 5:
    m.cyl(.065,1.0,Vector3(side*(w*.33+i*.11),1.27,back+.10),Models.BLUE)
   m.rod(Vector3(side*w*.34,.91,back+.20),Vector3(side*w*.34,1.16,back+.20),.035,Models.GOLD)
  m.box(Vector3(minf(w*.35,4.2),.045,.045),Vector3(0,1.64,back+.12),Models.GOLD)
 elif kind in ["recording","mixing","percussion"]:
  for i in range(1,int(w/1.1)):
   var x=-w/2+i*1.1
   m.box(Vector3(.70,.69,.10),Vector3(x,.61,back+.07),Models.NAVY)
   for stripe in 4:m.box(Vector3(.05,.61,.018),Vector3(x-.25+stripe*.17,.61,back+.13),color)
 elif kind in ["sky_observation","planetarium","chart_lab","calibration"]:
  var board=Vector3(0,.64,back+.10)
  m.box(Vector3(minf(w*.57,4.8),.85,.07),board,Models.NAVY)
  for r in [.17,.29,.40]:m.ring(r,r-.006,board+Vector3(0,0,.05),Models.GOLD,true)
  for i in 12:
   var a=i*2.39996;m.ell(Vector3(.025,.025,.02),board+Vector3(sin(a)*1.05,cos(a)*.33,.06),Models.WHITE)
 elif kind in ["aquatic_lab","ocean_exhibit","sea_lounge"]:
  for i in 3:m.whale(Vector3(-.8+i*.8,.63+.08*(i%2),back+.11),.36,Models.WHITE)
 elif kind in ["work","craft","songwriting","instrument_repair","weather_lab","radio"]:
  m.box(Vector3(minf(w*.55,3.4),.66,.065),Vector3(0,.65,back+.09),Models.CREAM)
  for i in 6:
   m.box(Vector3(.24,.32,.018),Vector3(-.80+i*.32,.64+.08*(i%2),back+.13),Models.BLUE if i%2 else Models.WHITE)
   m.cyl(.015,.025,Vector3(-.80+i*.32,.77+.08*(i%2),back+.15),Models.GOLD).rotation.x=PI/2
 elif kind in ["reading","books","vinyl_library","navigation_archive","photo_archive"]:
  # Display ledge at a different height from the floor-standing bookcases.
  m.box(Vector3(minf(w*.42,3.1),.06,.23),Vector3(0,.60,back+.11),Models.CREAM)
  m.books(Vector3(-.53,.63,back+.10),7)
 elif kind in ["bath","laundry","kitchen"]:
  for x in [-w*.28,w*.28]:
   m.box(Vector3(.78,.50,.025),Vector3(x,.65,back+.05),Models.WHITE)
   for i in 4:m.box(Vector3(.008,.49,.008),Vector3(x-.30+i*.2,.65,back+.07),color)
 elif kind in ["exhibit","reception","living","lounge","guest","bedroom","tea","dining","cafe","music_lounge"]:
  var p=Vector3(minf(w*.15,1.35),.63,back+.10)
  m.box(Vector3(1.26,.72,.065),p,Models.GOLD);m.box(Vector3(1.13,.60,.025),p+Vector3(0,0,.043),Models.BLUE)
  m.whale(p+Vector3(-.04,0,.08),.56,Models.CREAM)
 # Two physical sconces per large room, one in the small rooms.
 for side in [-1,1] if w>9 else [1]:
  var q=Vector3(side*(w/2-.65),.74,back+.15)
  m.box(Vector3(.18,.52,.06),Vector3(q.x,.49,back+.015),color.lightened(.12))
  m.box(Vector3(.16,.25,.05),q,Models.GOLD)
  var bulb=m.ell(Vector3(.11,.18,.12),q+Vector3(0,0,.07),Models.CREAM);bulb.material_override=M.led(Color("f1d7ad"),.10)
  bulb.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var light=OmniLight3D.new();light.position=q+Vector3(0,-.10,.22);light.light_color=Color("ffe1b7");light.light_energy=.12;light.omni_range=3.0;b.add_child(light)

static func _contour_accents(g,holder: Node3D,_polygon: PackedVector2Array,external_edges: Array) -> void:
 for edge: PackedVector2Array in external_edges:
  var local: PackedVector2Array=Shape.local_polygon(holder,edge)
  var a: Vector2=local[0];var end: Vector2=local[1]
  var length: float=a.distance_to(end)
  # Long rear and diagonal edges receive small cutaway-height window panels.
  if length<3 or (a.y>0 and end.y>0):continue
  var group:=Node3D.new();group.position=Vector3((a.x+end.x)/2,0,(a.y+end.y)/2)
  group.rotation.y=-atan2(end.y-a.y,end.x-a.x);holder.add_child(group)
  var builder=g._builder(group);var m=Models.new();m.b=builder
  var w: float=minf(length-.8,4.5)
  m.box(Vector3(w,.65,.04),Vector3(0,.67,0),Models.CREAM)
  m.box(Vector3(w-.13,.50,.055),Vector3(0,.67,.022),Color("8aa6b8"))
  for x in [-w*.33,0,w*.33]:m.box(Vector3(.035,.55,.065),Vector3(x,.67,.035),Models.NAVY)
  m.box(Vector3(w+.15,.07,.16),Vector3(0,.37,.05),Models.CREAM)
