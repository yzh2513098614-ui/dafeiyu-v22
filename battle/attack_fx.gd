extends Node2D
## Finite, deterministic battle effects. No gameplay RNG or global time scale is touched.
var style := "slash"
var source := Vector2.ZERO
var destination := Vector2.ZERO
var strength := 1.0
var playback_speed := 1.0
var age := 0.0
var lifetime := .62
var frozen := false
const WATER := Color("78d7ed")
const WHITE := Color("fff9e5")
const GOLD := Color("f5cd80")

static func profile(skill:String,actor:String="")->String:
 var id:=skill.to_lower()
 if id.contains("lightning"):return "lightning"
 if id.contains("spear"):return "spear"
 if id in ["whale_impact","ocean_release","impact","slam"]:return "heavy"
 if id.contains("bubble") or id.contains("prison"):return "bubble"
 if id.contains("wave") or id.contains("torrent") or id.contains("echo") or id=="link":return "wave"
 if actor.contains("蟹") or id.contains("pinch"):return "claw"
 if actor.contains("海沫"):return "bubble"
 return "slash"

func configure(kind:String,from:Vector2,to:Vector2,power:float=1.0,speed:float=1.0)->void:
 style=kind;source=from;destination=to;strength=clampf(power,.7,1.5);playback_speed=speed
 lifetime=.82 if kind in ["wave","heavy","bind","shield","heal"] else .62
 if kind=="windup":lifetime=.24
 queue_redraw()

func _process(delta:float)->void:
 if frozen:return
 age+=delta*playback_speed
 if age>=lifetime:queue_free();return
 queue_redraw()

func _ink(color:Color,alpha:float)->Color:
 return Color(color.r,color.g,color.b,clampf(alpha,0.0,1.0))

func _stroke(points:PackedVector2Array,color:Color,width:float,alpha:float)->void:
 if points.size()<2 or alpha<=0:return
 draw_polyline(points,_ink(color,alpha*.12),width*2.8,true)
 draw_polyline(points,_ink(color,alpha),width,true)
 draw_polyline(points,_ink(WHITE,alpha*.85),maxf(1.0,width*.28),true)

func _arc(center:Vector2,radius:float,start:float,end:float,color:Color,width:float,alpha:float,flatten:float=1.0)->void:
 var points:=PackedVector2Array()
 for i in 49:
  var a:=lerpf(start,end,float(i)/48.0)
  points.append(center+Vector2(cos(a),sin(a)*flatten)*radius)
 _stroke(points,color,width,alpha)

func _spark(at:Vector2,radius:float,color:Color,alpha:float)->void:
 var polygon:=PackedVector2Array()
 for i in 8:
  var a:=float(i)*TAU/8.0
  polygon.append(at+Vector2(cos(a),sin(a))*(radius if i%2==0 else radius*.24))
 draw_colored_polygon(polygon,_ink(color,alpha))

func _bubble(at:Vector2,radius:float,alpha:float)->void:
 draw_circle(at,radius,_ink(WATER,alpha*.14),true,-1,true)
 draw_arc(at,radius,0,TAU,32,_ink(WATER,alpha),2.2,true)
 draw_arc(at+Vector2(-radius*.18,-radius*.18),radius*.58,PI,PI*1.55,12,_ink(WHITE,alpha*.85),2.0,true)

func _burst(center:Vector2,t:float,color:Color,heavy:bool=false)->void:
 var alpha:=pow(1.0-clampf(t,0,1),1.5)
 var radius:float=lerpf(12.0,112.0 if heavy else 72.0,t)*strength
 _arc(center,radius,0,TAU,color,3.5*alpha,alpha*.65,.62)
 for i in (14 if heavy else 9):
  var angle:float=float(i)*2.39996
  var v:=Vector2(cos(angle),sin(angle)*.8)
  var at:Vector2=center+v*radius
  if i%3==0:_bubble(at,lerpf(8.0,3.0,t)*strength,alpha)
  else:_spark(at,lerpf(13.0,2.0,t)*strength,color,alpha)

func _draw()->void:
 var p:float=clampf(age/lifetime,0,1)
 var impact:float=clampf((age-.12)/(lifetime-.12),0,1)
 var fade:float=1.0-impact
 var aim:Vector2=(destination-source).normalized()
 if aim.length_squared()<.1:aim=Vector2.UP
 match style:
  "windup":
   var alpha:float=sin(p*PI)
   _arc(destination,58*(1-p*.3),PI*.15,PI*.85,Color("efba85"),4,alpha,.6)
   for side in [-1,1]:
    var at:Vector2=destination+Vector2(float(side)*48,-20-p*12)
    _stroke(PackedVector2Array([at+Vector2(-6,-8),at,at+Vector2(-6,8)]),GOLD,3,alpha)
  "critical":
   _burst(destination,p,GOLD,true)
   _spark(destination,46*(1-p),WHITE,1-p)
  "defeat":
   for i in 9:
    var a:float=float(i)*2.39996
    var at:Vector2=destination+Vector2(cos(a),sin(a)*.65)*(20+p*95)
    draw_circle(at,(12+float(i%3)*5)*(1-p),_ink(WATER,(1-p)*.28),true,-1,true)
    _spark(at,9*(1-p),WHITE,1-p)
   _arc(destination,30+p*115,0,TAU,WATER,3*(1-p),(1-p)*.45,.45)
  "slash","claw":
   for i in (3 if style=="claw" else 2):
    var offset:=Vector2(float(i)*23.0-18.0,float(i)*13.0-12.0)
    var sweep:float=clampf(age/.15,0,1)
    var color:Color=Color("f4b394") if style=="claw" else WATER
    _arc(destination+offset,88*strength,PI*.85,PI*.85+sweep*PI*1.04,color,9*fade,fade,.64)
   if age>=.12:_burst(destination,impact,WATER)
  "spear":
   var travel:float=clampf(age/.12,0,1)
   var head:Vector2=source.lerp(destination,travel)
   var tail:Vector2=head-aim*minf(source.distance_to(head),135.0)
   _stroke(PackedVector2Array([tail,head]),WATER,10*strength,fade)
   var normal:=aim.orthogonal()
   draw_colored_polygon(PackedVector2Array([head+aim*17,head-aim*20+normal*11,head-aim*13,head-aim*20-normal*11]),_ink(WHITE,fade))
   if age>=.12:_burst(destination,impact,WATER)
  "lightning":
   var bolt:=PackedVector2Array()
   var top:Vector2=destination-Vector2(0,185)
   for i in 9:
    var f:=float(i)/8
    bolt.append(top.lerp(destination,f)+Vector2(sin(float(i)*8.7)*23*sin(f*PI),0))
   _stroke(bolt,Color("a8acff"),8*strength,fade)
   if age>=.12:_burst(destination,impact,Color("cfb9f4"),true)
  "wave":
   var travel:float=clampf(age/.12,0,1)
   var head:Vector2=source.lerp(destination,travel)
   for i in 3:
    var center:Vector2=head-aim*float(i)*24
    _arc(center,58+float(i)*9,aim.angle()-PI*.56,aim.angle()+PI*.56,WATER,12-float(i)*2,fade*(1-float(i)*.2))
   if age>=.12:_burst(destination,impact,WATER,true)
  "heavy":
   if age<.12:
    _arc(destination,118*(1-age/.15),0,TAU,GOLD,4,.65,.65)
   else:
    _burst(destination,impact,GOLD,true)
    _arc(destination,35+impact*155,0,TAU,WATER,6*fade,fade*.65,.4)
    _spark(destination,42*strength*fade,WHITE,fade)
  "bubble","bind":
   var radius:float=78*strength
   for i in 8:
    var a:float=float(i)*TAU/8+age*.8
    var at:Vector2=destination+Vector2(cos(a),sin(a)*.8)*(radius*(.7+.6*impact))
    _bubble(at,(18+float(i%3)*7)*fade,fade)
   if style=="bind":
    _arc(destination,86,age*3,TAU+age*3,Color("cbb2e8"),5,fade,.75)
   elif age>=.12:_burst(destination,impact,WATER)
  "shield":
   var alpha:float=sin(p*PI)
   var r:float=55+12*sin(p*PI)
   var poly:=PackedVector2Array([destination+Vector2(-r,-r*.6),destination+Vector2(0,-r),destination+Vector2(r,-r*.6),destination+Vector2(r*.85,r*.35),destination+Vector2(0,r),destination+Vector2(-r*.85,r*.35)])
   draw_colored_polygon(poly,_ink(WATER,alpha*.12))
   poly.append(poly[0]);_stroke(poly,WATER,4,alpha)
   _arc(destination,r*1.25,0,TAU,WATER,2,alpha*.4,.65)
  "heal":
   var alpha:float=sin(p*PI)
   var green:=Color("a0ddbb")
   _arc(destination,64+p*26,0,TAU,green,3,alpha*.7,.48)
   for i in 7:
    var at:Vector2=destination+Vector2(sin(float(i)*4.3)*52,35-p*100+float(i%3)*16)
    if i%2==0:
     draw_line(at-Vector2(0,7),at+Vector2(0,7),_ink(green,alpha),5,true)
     draw_line(at-Vector2(7,0),at+Vector2(7,0),_ink(green,alpha),5,true)
    else:_spark(at,8,WHITE,alpha)
  "support":
   var alpha:float=sin(p*PI)
   _arc(destination,34+p*46,0,TAU,GOLD,3,alpha,.65)
   for i in 6:
    var a:float=float(i)*TAU/6+age
    _spark(destination+Vector2(cos(a),sin(a))*(26+p*40),10,GOLD,alpha)
