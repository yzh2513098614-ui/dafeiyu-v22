@tool
extends RefCounted
## Native editor counterpart to build_collision_profile.py; no external Python needed.
static func smooth(a: float,b: float,v: float) -> float:
 var t:=clampf((v-a)/(b-a),0.0,1.0)
 return t*t*(3.0-2.0*t)

static func build(manifest: Dictionary,tree: SceneTree) -> Dictionary:
 var bands: Array=[[.34,.65],[.65,1.0],[1.0,1.35],[1.35,1.7],[1.7,2.05],[2.05,2.45]]
 var radii: Array=[0.0,0.0,0.0,0.0,0.0,0.0]
 var count:=0
 for direction in manifest.atlas_order:
  var paths: Dictionary={}
  for state in manifest.frames_by_state.values():
   for path in state[direction]:paths[path]=true
  var density: float=manifest.get("pixel_size_by_direction",{}).get(direction,manifest.pixel_size)
  var warp: Dictionary=manifest.get("proportion_warp_by_direction",{}).get(direction,{})
  for path in paths:
   var texture: Texture2D=load(path)
   var image:=texture.get_image();image.convert(Image.FORMAT_RGBA8)
   var bytes:=image.get_data();var width:=image.get_width();var height:=image.get_height()
   var rect:=image.get_used_rect()
   for row in range(rect.position.y,rect.end.y):
    var left:=rect.position.x;var right:=rect.end.x-1
    while left<=right and bytes[(row*width+left)*4+3]<64:left+=1
    if left>right:continue
    while right>left and bytes[(row*width+right)*4+3]<64:right-=1
    var y:=float(row)/height
    var scale:=1.0
    if warp.get("enabled",false):
     var head: float=warp.head_end;var body: float=warp.body_end;var ground: float=float(manifest.ground[1])/height
     scale+=smooth(head,.585,y)*(1.0-smooth(.86,.925,y))*(float(warp.body_width)+float(warp.skirt_width)*exp(-pow((y-.745)/.085,2.0)))
     scale+=(1.0-smooth(head-.04,.585,y))*float(warp.get("head_width",0.0))
     y+=float(warp.get("head_height",0.0))*minf(y-head,0.0)+float(warp.get("crown_compression",0.0))*(1.0-smooth(.12,.38,y))+float(warp.get("head_drop",0.0))*smooth(.20,.53,y)*(1.0-smooth(.53,body,y))+float(warp.body_extension)*(smooth(head,body,y)-1.0)+float(warp.leg_extension)*(smooth(body,ground,y)-1.0)
    var world_height:=.056+(float(manifest.ground[1])-y*height)*density
    bands[-1][1]=maxf(bands[-1][1],snappedf(world_height+.025,.0001))
    var radius:=maxf(absf(left-float(manifest.ground[0])),absf(right-float(manifest.ground[0])))*density*scale
    for i in bands.size():
     if world_height>=float(bands[i][0])-.025 and world_height<=float(bands[i][1])+.025:radii[i]=maxf(radii[i],radius)
   count+=1
   await tree.process_frame
 var result: Dictionary={"source_frames":count,"alpha_threshold":64,"margin":.025,"bands":[]}
 for i in bands.size():
  if radii[i]>0:result.bands.append({"bottom":bands[i][0],"top":bands[i][1],"radius":snappedf(float(radii[i])+.025,.0001)})
 return result
