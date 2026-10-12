extends SceneTree
## Sample native pigments from six other directions; use one shared colour ramp.
const OUTPUT="res://assets/character/diagonal_palette_fill_20261013/"
const SOURCE="res://assets/character/diagonal_black_outline_20261013/"
const GROUPS=["hair","navy","skin","white"]
const QUANTILES=[.02,.10,.25,.40,.50,.65,.80,.90,.98]
var reference: Dictionary={}
var source: Dictionary={}
var ramps: Dictionary={}

func _initialize() -> void:call_deferred("bake")

func group(c: Color,y: float,diagonal: bool) -> String:
 if c.a<.98:return ""
 var blue:=c.b-c.r>.06 and c.b-c.g>.01 and c.b>.24
 if blue:return "hair" if y<(.80 if diagonal else .68) else "navy"
 if c.r-c.g>.055 and c.g-c.b>.015 and c.r>.48 and c.g>.28 and c.b>.20:return "skin"
 if minf(c.r,minf(c.g,c.b))>.62 and maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b))<.18:return "white"
 return ""

func collect(image: Image,diagonal: bool,table: Dictionary) -> void:
 for y in range(0,image.get_height(),3):
  for x in range(0,image.get_width(),3):
   var c:=image.get_pixel(x,y)
   var key:=group(c,float(y)/image.get_height(),diagonal)
   if not key.is_empty():table[key].append(c)

func value(c: Color) -> float:return maxf(c.r,maxf(c.g,c.b))
func peak(v: Vector3) -> float:return maxf(v.x,maxf(v.y,v.z))

func anchors(samples: Array) -> Array:
 samples.sort_custom(func(a,b):return value(a)<value(b))
 var result=[]
 for q in QUANTILES:
  var center:=int(q*(samples.size()-1));var total:=Vector3.ZERO;var count:=0
  var radius:=maxi(1,int(samples.size()*.012))
  for n in range(maxi(0,center-radius),mini(samples.size(),center+radius+1)):
   var c: Color=samples[n];total+=Vector3(c.r,c.g,c.b);count+=1
  result.append(total/count)
 return result

func match_colour(c: Color,key: String) -> Color:
 var ramp: Dictionary=ramps[key];var src: Array=ramp.source;var dst: Array=ramp.target
 var v:=value(c);var n:=0
 while n<src.size()-2 and v>peak(src[n+1]):n+=1
 var low: float=peak(src[n]);var high: float=peak(src[n+1])
 var t:=clampf((v-low)/maxf(high-low,.0001),0.0,1.0)
 var original: Vector3=src[n].lerp(src[n+1],t)
 var desired: Vector3=dst[n].lerp(dst[n+1],t)
 # Preserve the pixel's local colour variation around its brightness anchor.
 var rgb:=Vector3(c.r,c.g,c.b)+desired-original
 return Color(clampf(rgb.x,0,1),clampf(rgb.y,0,1),clampf(rgb.z,0,1),c.a)

func recolour(image: Image) -> Dictionary:
 image.convert(Image.FORMAT_RGBA8)
 var pixels:=image.get_data();var original:=pixels.duplicate();var w:=image.get_width()
 var counts={"hair":0,"navy":0,"skin":0,"white":0}
 for y in image.get_height():
  for x in w:
   var c:=image.get_pixel(x,y);var key:=group(c,float(y)/image.get_height(),true)
   if key.is_empty():continue
   var new_colour:=match_colour(c,key)
   var strength:=1.0
   if key in ["hair","navy"]:
    new_colour=match_colour(c,"hair").lerp(match_colour(c,"navy"),smoothstep(.76,.84,float(y)/image.get_height()))
    strength=smoothstep(.06,.12,c.b-c.r)*smoothstep(.01,.05,c.b-c.g)*smoothstep(.24,.32,c.b)
   elif key=="skin":strength=smoothstep(.055,.09,c.r-c.g)*smoothstep(.015,.05,c.g-c.b)*smoothstep(.48,.65,c.r)
   elif key=="white":strength=smoothstep(.62,.78,minf(c.r,minf(c.g,c.b)))*(1.0-smoothstep(.14,.18,maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b))))
   new_colour=c.lerp(new_colour,strength)
   var p:=(y*w+x)*4
   pixels[p]=new_colour.r8;pixels[p+1]=new_colour.g8;pixels[p+2]=new_colour.b8;counts[key]+=1
 var alpha_ok:=true;var ink_ok:=true
 for p in w*image.get_height():
  if pixels[p*4+3]!=original[p*4+3]:alpha_ok=false
  if maxi(original[p*4],maxi(original[p*4+1],original[p*4+2]))<=61 and (pixels[p*4]!=original[p*4] or pixels[p*4+1]!=original[p*4+1] or pixels[p*4+2]!=original[p*4+2]):ink_ok=false
 assert(alpha_ok and ink_ok)
 return {"image":Image.create_from_data(w,image.get_height(),false,Image.FORMAT_RGBA8,pixels),"counts":counts}

func write_import(path: String,source_path: String) -> void:
 var config:=ConfigFile.new()
 if FileAccess.file_exists(path+".import"):config.load(path+".import")
 else:config.load(source_path+".import");config.erase_section_key("remap","uid")
 var cached: String="res://.godot/imported/"+path.get_file()+"-"+path.md5_text()+".ctex"
 config.set_value("remap","path",cached);config.set_value("deps","source_file",path);config.set_value("deps","dest_files",[cached])
 config.save(path+".import")

func bake() -> void:
 for key in GROUPS:reference[key]=[];source[key]=[]
 for direction in ["down","up","left","right","down_left","down_right"]:
  for frame in [0,6,9]:collect(Image.load_from_file("res://assets/character/jimeng_v24/"+direction+"/walk_%02d.png"%frame),false,reference)
 for frame in [0,6,9,12,18,25]:collect(Image.load_from_file(SOURCE+"up_left/walk_%02d.png"%frame),true,source)
 var report={"reference_directions":["down","up","left","right","down_left","down_right"],"ramps":{},"frames":[]}
 for key in GROUPS:
  assert(source[key].size()>50 and reference[key].size()>50)
  ramps[key]={"source":anchors(source[key]),"target":anchors(reference[key])}
  var entries=[]
  for i in QUANTILES.size():
   var src: Vector3=ramps[key].source[i];var dst: Vector3=ramps[key].target[i]
   entries.append({"quantile":QUANTILES[i],"source":[src.x,src.y,src.z],"target":[dst.x,dst.y,dst.z]})
  report.ramps[key]={"source_samples":source[key].size(),"reference_samples":reference[key].size(),"anchors":entries}
  print("PALETTE SAMPLED ",key," source=",source[key].size()," reference=",reference[key].size()," median source=",ramps[key].source[4]," target=",ramps[key].target[4])
 for direction in ["up_left","up_right"]:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+direction))
 for frame in 26:
  var name:="walk_%02d.png"%frame;var input_path:=SOURCE+"up_left/"+name
  var recoloured:=recolour(Image.load_from_file(input_path));var image: Image=recoloured.image
  var left:=OUTPUT+"up_left/"+name;var right:=OUTPUT+"up_right/"+name
  assert(image.save_png(left)==OK);write_import(left,input_path)
  image.flip_x();assert(image.save_png(right)==OK);write_import(right,SOURCE+"up_right/"+name)
  report.frames.append({"frame":frame,"region_pixels":recoloured.counts,"source_sha256":FileAccess.get_sha256(input_path),"alpha_changed":0,"dark_ink_changed":0})
  print("PALETTE FILLED ",frame," ",recoloured.counts)
 var text:=FileAccess.get_file_as_string("res://assets/character/manifest.json").replace("\r\n","\n")
 text=text.replace(SOURCE,OUTPUT)
 var manifest: Dictionary=JSON.parse_string(text)
 for direction in ["up_left","up_right"]:
  var old: Dictionary=manifest.palette_match_by_direction[direction].duplicate(true)
  var next:=old.duplicate(true)
  next.enabled=false;next.hair_palette_gamma=[1.0,1.0,1.0];next.skin_palette_gamma=[1.0,1.0,1.0]
  next.hair_palette_strength=0.0;next.skin_palette_strength=0.0
  next.method="six-direction sampled material colour ramps baked into all full-picture frames; no repeated runtime gamma correction"
  # Replace only the specific direction's palette block; retain unrelated edits.
  var regex:=RegEx.new();regex.compile('(?s)("'+direction+'": \\{).*?(\\n    \\})')
  var match:=regex.search(text,text.find('"palette_match_by_direction"'))
  var block:=JSON.stringify(next,"  ")
  var lines:=block.split("\n");var formatted:=""
  for i in lines.size():formatted+=("" if i==0 else "    ")+lines[i]+("\n" if i<lines.size()-1 else "")
  text=text.substr(0,match.get_start())+'"'+direction+'": '+formatted+text.substr(match.get_end())
 var file:=FileAccess.open("res://assets/character/manifest.json",FileAccess.WRITE);file.store_string(text);file.close()
 file=FileAccess.open(OUTPUT+"palette_report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  ")+"\n");file.close()
 print("PALETTE FILL: 52 frames; alpha and dark ink preserved; single shared ramp across the full loop")
 quit()
