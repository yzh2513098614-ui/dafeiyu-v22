extends SceneTree
## Explicit limb skin masks, flat sampled pigment, original silhouettes retained.
const SOURCE="res://assets/character/diagonal_palette_fill_20261013/"
const OUTPUT="res://assets/character/diagonal_skin_cleanup_20261013/"
const REVIEW="res://预览/diagonal_skin_cleanup_20261013/"
const REGIONS=[Rect2i(330,790,140,140),Rect2i(410,928,190,96)]
var records: Array=[]
var base:=Color8(249,225,215)
var shade:=Color8(236,204,193)

func _initialize() -> void:call_deferred("run")

func warm(c: Color,minimum_warmth: float) -> bool:
 return c.a>.85 and c.r>.46 and c.g>.30 and c.b>.25 and c.r-c.g>minimum_warmth and c.r-c.b>.045 and c.g-c.b>.004

func skin_mask(image: Image) -> PackedByteArray:
 var w:=image.get_width();var mask:=PackedByteArray();mask.resize(w*image.get_height())
 for region in REGIONS:
  var candidate:=PackedByteArray();candidate.resize(mask.size())
  for y in range(region.position.y,region.end.y):
   for x in range(region.position.x,region.end.x):
    if warm(image.get_pixel(x,y),.008 if region==REGIONS[0] else .040):candidate[y*w+x]=1
  for y in range(region.position.y,region.end.y):
   for x in range(region.position.x,region.end.x):
    var p:=y*w+x
    if candidate[p]!=1:continue
    var component:=PackedInt32Array([p]);candidate[p]=2;var cursor:=0
    var low:=Vector2i(x,y);var high:=low
    while cursor<component.size():
     var current:=component[cursor];cursor+=1
     var point:=Vector2i(current%w,current/w);low=low.min(point);high=high.max(point)
     for offset in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
      var next: Vector2i=point+offset
      if not region.has_point(next):continue
      var q: int=next.y*w+next.x
      if candidate[q]==1:candidate[q]=2;component.append(q)
    # Skin masses are tall connected areas; small lace/cloth pink flecks stay out.
    if component.size()<120 or high.y-low.y<18:continue
    for q in component:mask[q]=255
 # Close small grey holes inside skin only, without extending into white cloth.
 for pass_index in 2:
  var next:=mask.duplicate()
  for region in REGIONS:
   for y in range(region.position.y+2,region.end.y-2):
    for x in range(region.position.x+2,region.end.x-2):
     var p:=y*w+x
     if mask[p]>0:continue
     var c:=image.get_pixel(x,y)
     if c.a<.85 or c.r<.42 or c.b-c.r>.035 or c.g-c.r>.025:continue
     var surrounding:=0
     for offset in [-w-1,-w,-w+1,-1,1,w-1,w,w+1]:
      if mask[p+offset]>0:surrounding+=1
     if surrounding>=5:next[p]=255
  mask=next
 return mask

func repaint(image: Image,mask: PackedByteArray) -> Image:
 image.convert(Image.FORMAT_RGBA8)
 var pixels:=image.get_data();var original:=pixels.duplicate();var w:=image.get_width();var changed:=0
 for y in range(790,1024):
  for x in range(330,600):
   var p:=y*w+x
   if mask[p]==0:continue
   # A restrained edge shadow replaces noisy video pixels with clean skin paint.
   var edge:=mask[p-1]==0 or mask[p+1]==0 or mask[p-w]==0 or mask[p+w]==0
   var deeper:=mask[p-2]==0 or mask[p+2]==0 or mask[p-2*w]==0 or mask[p+2*w]==0
   var colour:=base.lerp(shade,.42 if edge else (.15 if deeper else 0.0))
   pixels[p*4]=colour.r8;pixels[p*4+1]=colour.g8;pixels[p*4+2]=colour.b8;changed+=1
 var alpha_ok:=true;var outside_ok:=true
 for p in mask.size():
  if pixels[p*4+3]!=original[p*4+3]:alpha_ok=false
  if mask[p]==0 and (pixels[p*4]!=original[p*4] or pixels[p*4+1]!=original[p*4+1] or pixels[p*4+2]!=original[p*4+2]):outside_ok=false
 assert(alpha_ok and outside_ok and changed>1500)
 records.append({"painted_skin_pixels":changed,"alpha_changed":0,"outside_skin_changed":0})
 return Image.create_from_data(w,image.get_height(),false,Image.FORMAT_RGBA8,pixels)

func write_import(path: String,input: String) -> void:
 var config:=ConfigFile.new()
 if FileAccess.file_exists(path+".import"):config.load(path+".import")
 else:config.load(input+".import");config.erase_section_key("remap","uid")
 var cached: String="res://.godot/imported/"+path.get_file()+"-"+path.md5_text()+".ctex"
 config.set_value("remap","path",cached);config.set_value("deps","source_file",path);config.set_value("deps","dest_files",[cached]);config.save(path+".import")

func run() -> void:
 for direction in ["up_left","up_right"]:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+direction+"/masks"))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW))
 # Use the same skin median and shadow quartile sampled for the six-direction fill.
 var palette: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"palette_report.json"))
 var rgb: Array=palette.ramps.skin.anchors[4].target;base=Color(rgb[0],rgb[1],rgb[2])
 rgb=palette.ramps.skin.anchors[2].target;shade=Color(rgb[0],rgb[1],rgb[2])
 var sheet:=Image.create(2940,1280,false,Image.FORMAT_RGBA8);sheet.fill(Color("a4b5bd"))
 for frame in 26:
  var name:="walk_%02d.png"%frame;var input:=SOURCE+"up_left/"+name
  var image:=Image.load_from_file(input);var mask:=skin_mask(image)
  var clean:=repaint(image,mask)
  var mask_image:=Image.create_from_data(image.get_width(),image.get_height(),false,Image.FORMAT_L8,mask)
  var overlay:=image.duplicate()
  for y in range(790,1024):
   for x in range(330,600):
    if mask[y*image.get_width()+x]>0:overlay.set_pixel(x,y,Color(1,.1,.3,image.get_pixel(x,y).a))
  var crop:=Image.create(420,320,false,Image.FORMAT_RGBA8);crop.fill(Color("a4b5bd"));crop.blend_rect(overlay,Rect2i(300,760,420,320),Vector2i.ZERO)
  sheet.blit_rect(crop,Rect2i(0,0,420,320),Vector2i((frame%7)*420,(frame/7)*320))
  crop.save_png(REVIEW+"mask_%02d.png"%frame)
  for direction in ["up_left","up_right"]:
   var path: String=OUTPUT+direction+"/"+name
   if direction=="up_right":clean.flip_x();mask_image.flip_x()
   assert(clean.save_png(path)==OK);mask_image.save_png(OUTPUT+direction+"/masks/"+name);write_import(path,SOURCE+direction+"/"+name)
  records[-1]["frame"]=frame;records[-1]["source_sha256"]=FileAccess.get_sha256(input)
  print("SKIN CLEANUP ",frame," painted=",records[-1].painted_skin_pixels," alpha and other regions unchanged")
 sheet.save_png(REVIEW+"skin_mask_sheet.png")
 var report:=FileAccess.open(OUTPUT+"skin_report.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"base_rgb":[base.r8,base.g8,base.b8],"shade_rgb":[shade.r8,shade.g8,shade.b8],"frames":records},"  ")+"\n");report.close()
 if not "--inspect-only" in OS.get_cmdline_user_args():
  var text:=FileAccess.get_file_as_string("res://assets/character/manifest.json").replace("\r\n","\n").replace(SOURCE,OUTPUT)
  var file:=FileAccess.open("res://assets/character/manifest.json",FileAccess.WRITE);file.store_string(text);file.close()
 print("SKIN CLEANUP: 52 complete frames; alpha and pixels outside explicit limb skin masks preserved")
 quit()
