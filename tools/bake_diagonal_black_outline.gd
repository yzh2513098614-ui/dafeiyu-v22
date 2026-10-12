extends SceneTree
## Deterministic native-frame ink pass. Alpha, pose and registration stay exact.
const OUTPUT="res://assets/character/diagonal_black_outline_20261013/"
const SOURCES={"up_left":"res://assets/character/up_left_video_20261010/","up_right":"res://assets/character/up_right_mirror_20261010/"}
const CORE:=5.0
const WIDTH:=7.0
const DIAGONAL:=1.41421356
var records: Array=[]

func _initialize() -> void:call_deferred("bake")

func ink_frame(source: Image) -> Image:
 source.convert(Image.FORMAT_RGBA8)
 var w:=source.get_width();var h:=source.get_height()
 var original:=source.get_data();var pixels:=original.duplicate()
 var distance:=PackedFloat32Array();distance.resize(w*h)
 for p in w*h:distance[p]=10000.0 if original[p*4+3]>=107 else 0.0
 for y in range(1,h-1):
  for x in range(1,w-1):
   var p:=y*w+x
   distance[p]=minf(distance[p],minf(minf(distance[p-1]+1.0,distance[p-w]+1.0),minf(distance[p-w-1]+DIAGONAL,distance[p-w+1]+DIAGONAL)))
 for y in range(h-2,0,-1):
  for x in range(w-2,0,-1):
   var p:=y*w+x
   distance[p]=minf(distance[p],minf(minf(distance[p+1]+1.0,distance[p+w]+1.0),minf(distance[p+w-1]+DIAGONAL,distance[p+w+1]+DIAGONAL)))
 var changed:=0;var alpha_changed:=0;var interior_changed:=0
 var ink_values=[6,7,10]
 for p in w*h:
  if original[p*4+3]==0 or distance[p]>=WIDTH:continue
  var strength:=1.0-smoothstep(CORE,WIDTH,distance[p])
  for channel in 3:
   pixels[p*4+channel]=roundi(lerpf(original[p*4+channel],ink_values[channel],strength))
  changed+=1
 for p in w*h:
  if pixels[p*4+3]!=original[p*4+3]:alpha_changed+=1
  if distance[p]>=WIDTH and (pixels[p*4]!=original[p*4] or pixels[p*4+1]!=original[p*4+1] or pixels[p*4+2]!=original[p*4+2]):interior_changed+=1
 assert(alpha_changed==0 and interior_changed==0 and changed>1000)
 records.append({"changed_boundary_pixels":changed,"alpha_changed":alpha_changed,"interior_changed":interior_changed})
 return Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,pixels)

func write_import(path: String,source_path: String) -> void:
 var config:=ConfigFile.new();config.load(source_path+".import")
 config.erase_section_key("remap","uid")
 var cached: String="res://.godot/imported/"+path.get_file()+"-"+path.md5_text()+".ctex"
 config.set_value("remap","path",cached)
 config.set_value("deps","source_file",path);config.set_value("deps","dest_files",PackedStringArray([cached]))
 config.set_value("params","compress/mode",0);config.set_value("params","mipmaps/generate",true)
 config.save(path+".import")

func bake() -> void:
 for direction in SOURCES:DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT+direction))
 for i in 26:
  var name:="walk_%02d.png"%i
  var source_path: String=SOURCES.up_left+name
  var frame:=ink_frame(Image.load_from_file(source_path))
  var left: String=OUTPUT+"up_left/"+name;var right: String=OUTPUT+"up_right/"+name
  assert(frame.save_png(left)==OK);write_import(left,source_path)
  frame.flip_x();assert(frame.save_png(right)==OK);write_import(right,SOURCES.up_right+name)
  var right_original:=Image.load_from_file(SOURCES.up_right+name)
  var left_original:=Image.load_from_file(source_path);left_original.flip_x()
  assert(right_original.get_data()==left_original.get_data())
  var record: Dictionary=records[-1]
  record["frame"]=i;record["source_left_sha256"]=FileAccess.get_sha256(source_path)
  record["source_right_sha256"]=FileAccess.get_sha256(SOURCES.up_right+name)
  print("BLACK INK FRAME ",i," boundary=",record.changed_boundary_pixels," alpha preserved; exact mirror")
 var text:=FileAccess.get_file_as_string("res://assets/character/manifest.json").replace("\r\n","\n")
 for direction in SOURCES:text=text.replace(SOURCES[direction]+"walk_",OUTPUT+direction+"/walk_")
 text=text.replace('"contour_strength": 0.58','"contour_strength": 0.12').replace('"contour_width": 1.8','"contour_width": 0.8')
 var file:=FileAccess.open("res://assets/character/manifest.json",FileAccess.WRITE);file.store_string(text);file.close()
 file=FileAccess.open(OUTPUT+"bake_report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"method":"native alpha inward ink, 5 pixel core plus 2 pixel transition, original alpha and interior RGB preserved, exact horizontal mirror","ink_rgb":[6,7,10],"frames":records},"  ")+"\n");file.close()
 print("BLACK INK BAKE: 52 complete frames; 26 alpha/interior checks and exact mirror checks passed")
 quit()
