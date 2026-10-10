extends SceneTree
## Bake painted image parts through a real GPU viewport. Never write runtime manifest.
const Rig=preload("res://character/character_paper_rig.gd")
const DEST:="res://assets/character/v15/"
const SOURCE_MANIFEST:=DEST+"parts_manifest.json"
const ORDER:=["down","left","up","right"]
const DEFAULTS:={"canvas_size":[384,512],"ground":[192,420],"pixel_size":0.0064,"hem_height":0.21,"body_height":2.0,"hip_height":0.64,"hip_spacing":0.23,"stride_halfspan":0.30,"stance_ratio":0.60,"lift_height":0.10,"shoe_height":0.15,"upper_length":0.40,"lower_length":0.40,"camera_pitch_degrees":33.0}
var viewport: SubViewport
var rig

func _initialize() -> void:
 call_deferred("_bake")

func _fail(message: String) -> void:
 push_error("V15_CHARACTER_BAKE: "+message)
 quit(2)

func _source(value: String) -> String:
 return value if value.begins_with("res://") or value.is_absolute_path() else DEST+value

func _bake() -> void:
 if not FileAccess.file_exists(SOURCE_MANIFEST):
  _fail("Missing "+SOURCE_MANIFEST+". Prepare the generated body/leg PNGs and their source-pixel annotations first.");return
 var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_MANIFEST))
 if not decoded is Dictionary:
  _fail("parts_manifest.json must be a JSON object.");return
 var manifest: Dictionary=decoded.duplicate(true)
 manifest.merge(DEFAULTS,false)
 var body_path:=_source(str(manifest.get("body_sheet","")))
 var leg_path:=_source(str(manifest.get("leg_sheet","")))
 if str(manifest.get("body_sheet",""))=="" or str(manifest.get("leg_sheet",""))=="":
  _fail("body_sheet and leg_sheet must name the generated source PNGs.");return
 for path in [body_path,leg_path]:
  if not FileAccess.file_exists(path):
   _fail("Source PNG missing: "+str(path)+". No atlas was produced.");return
 var body: Texture2D=load(body_path)
 var legs: Texture2D=load(leg_path)
 if body==null or legs==null:
  _fail("Source PNG exists but cannot be loaded. Import the project resources before GPU baking.");return
 var views: Variant=manifest.get("directions",{})
 if not views is Dictionary:
  _fail("directions must map down/left/up/right to body/legs annotations.");return
 for direction in ORDER:
  if not views.has(direction):
   _fail("Missing direction: "+direction);return
  var view: Dictionary=views[direction]
  if not _part_rect_valid(view.get("body",{}),body.get_size()):
   _fail(direction+" body rect is missing or outside its source sheet.");return
  var entries: Variant=view.get("legs",[])
  if not entries is Array or entries.size()!=2:
   _fail(direction+" needs exactly two annotated legs: A near, B far.");return
  for entry in entries:
   if not entry is Dictionary or not _part_rect_valid(entry,legs.get_size()):
    _fail(direction+" leg rect is missing or outside its source sheet.");return
   for anchor in ["hip","knee","ankle"]:
    if not entry.get(anchor) is Array or entry[anchor].size()!=2:
     _fail(direction+" leg needs local source-pixel "+anchor+"=[x,y].");return
   if not entry.has("sole_y"):
    _fail(direction+" leg needs local source-pixel sole_y.");return
 var size_values: Array=manifest.canvas_size
 var size:=Vector2i(int(size_values[0]),int(size_values[1]))
 if size.x<=0 or size.y<=0:
  _fail("canvas_size must contain two positive dimensions.");return
 viewport=SubViewport.new();viewport.size=size;viewport.transparent_bg=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
 root.add_child(viewport)
 rig=Rig.new();viewport.add_child(rig);rig.configure(body,legs,manifest)
 var records: Array=[]
 var save_frames: bool="--frames" in OS.get_cmdline_user_args()
 if save_frames:
  var directory_error: Error=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST+"review_frames"))
  if directory_error!=OK:
   _fail("Could not create review_frames, error "+str(directory_error));return
 for state in ["walk","idle"]:
  var count: int=16 if state=="walk" else 1
  var atlas:=Image.create(size.x*count,size.y*4,false,Image.FORMAT_RGBA8)
  atlas.fill(Color.TRANSPARENT)
  for row in 4:
   for column in count:
    var phase: float=float(column)/count
    rig.set_pose(ORDER[row],phase,state=="walk")
    await process_frame
    await RenderingServer.frame_post_draw
    var frame: Image=viewport.get_texture().get_image()
    atlas.blit_rect(frame,Rect2i(Vector2i.ZERO,size),Vector2i(column*size.x,row*size.y))
    if save_frames:
     var frame_error: Error=frame.save_png(DEST+"review_frames/%s_%s_%02d.png"%[state,ORDER[row],column])
     if frame_error!=OK:
      _fail("Could not save a native review frame, error "+str(frame_error));return
    records.append({"state":state,"direction":ORDER[row],"frame":column,"pose":_jsonable(rig.last_pose)})
  var error: Error=atlas.save_png(DEST+state+"_atlas.png")
  if error!=OK:
   _fail("Could not save "+state+" atlas, error "+str(error));return
 var parameters: Dictionary={"hem_height":rig.hem_height,"body_height":rig.body_height,"hip_height":rig.hip_height,"hip_spacing":rig.hip_spacing,"stride_halfspan":rig.stride_halfspan,"stance_ratio":rig.stance_ratio,"lift_height":rig.lift_height,"shoe_height":rig.shoe_height,"upper_length":rig.upper_length,"lower_length":rig.lower_length,"camera_pitch_degrees":rig.camera_pitch_degrees,"body_sway":rig.body_sway,"weight_bob_keys":Rig.WEIGHT_BOB_KEYS}
 var metadata: Dictionary={"version":1,"method":"painted_image_parts_short_leg_ik","source_manifest":SOURCE_MANIFEST,"body_sheet":body_path,"leg_sheet":leg_path,"canvas_size":[size.x,size.y],"ground":_jsonable(rig.ground),"pixel_size":rig.pixel_size,"frame_counts":{"walk":16,"idle":1},"atlas_order":ORDER,"cycle_distance":rig.cycle_distance,"parameters":parameters,"source_annotations":manifest.directions,"poses":records}
 var file:=FileAccess.open(DEST+"pose_metadata.json",FileAccess.WRITE)
 if file==null:
  _fail("Could not create separate pose_metadata.json.");return
 file.store_string(JSON.stringify(metadata,"  "));file.close()
 print("V15_CHARACTER_BAKE_COMPLETE frames=68 cycle_distance=",rig.cycle_distance,"; runtime manifest unchanged")
 quit()

func _part_rect_valid(part: Variant,sheet_size: Vector2) -> bool:
 if not part is Dictionary:return false
 var values: Variant=part.get("rect")
 if not values is Array or values.size()!=4:return false
 var rect:=Rect2(float(values[0]),float(values[1]),float(values[2]),float(values[3]))
 return rect.has_area() and Rect2(Vector2.ZERO,sheet_size).encloses(rect)

func _jsonable(value: Variant) -> Variant:
 if value is Vector2:return [value.x,value.y]
 if value is Vector3:return [value.x,value.y,value.z]
 if value is Dictionary:
  var result: Dictionary={}
  for key in value:result[key]=_jsonable(value[key])
  return result
 if value is Array:
  var result: Array=[]
  for item in value:result.append(_jsonable(item))
  return result
 return value
