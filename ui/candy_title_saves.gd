extends RefCounted
## Fixed-key snapshot slots. Checksums, staged writes and a recovery journal protect existing saves.
const VERSION=1
const SLOT_COUNT=6
const MAX_FILE_BYTES=67108864
var directory:="user://candy_title_slots"
var paths:Dictionary={}
var last_error:=""

func configure(world_path:String,isolated:bool=false)->void:
 paths={"world":world_path,"inventory":"user://whale_inventory_v5.json","dialogue":"user://whale_dialogue_v19.json","pack26":"user://whale_pack26_v1.json","expedition":"user://whale_expedition_v1.json","expedition_backup":"user://whale_expedition_v1.json.bak"}
 if isolated:
  directory="res://预览/糖果贴纸开始界面_20261012/slots"
  for key in paths:
   if key!="world":paths[key]="res://预览/糖果贴纸开始界面_20261012/active_"+key+".json"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))

func _slot_path(index:int)->String:
 return directory+"/slot_%02d.json"%index if index>=1 and index<=SLOT_COUNT else ""

func _read(path:String)->Variant:
 if not FileAccess.file_exists(path):return null
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()>MAX_FILE_BYTES:last_error="存档无法读取或超过大小限制。";return null
 return file.get_as_text()

func _version_is(value:Variant,allowed:Array)->bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and int(value) in allowed

func _valid_world(raw:Variant)->bool:
 if not raw is Dictionary or not _version_is(raw.get("version"),[3,4,5,6]):return false
 var id:Variant=raw.get("location")
 if not id is String or id.is_empty() or id.length()>40:return false
 for index in id.length():
  var c:String=id[index]
  if not (c>="a" and c<="z" or c>="0" and c<="9" or c=="_"):return false
 var pos:Variant=raw.get("position")
 if not pos is Array or pos.size()!=2:return false
 for value in pos:
  if not (value is float or value is int) or not is_finite(float(value)):return false
 for key in ["rooms","visited","favorites","clock"]:
  if raw.has(key) and not raw[key] is Dictionary:return false
 return true

func _valid_content(key:String,text:Variant)->bool:
 if text==null:return key!="world"
 if not text is String or text.to_utf8_buffer().size()>MAX_FILE_BYTES:return false
 var value:Variant=JSON.parse_string(text)
 if not value is Dictionary:return false
 if key=="world":return _valid_world(value)
 if key=="dialogue":
  if not _version_is(value.get("version"),[1]) or not value.get("seen") is Dictionary or not value.get("flags") is Dictionary or not value.get("bookmark") is Dictionary or not value.get("history") is Array:return false
  for entry in value.history:
   if not entry is Dictionary or not entry.get("speaker") is String or not entry.get("text") is String or not entry.get("topic") is String:return false
 if key=="inventory":
  if not _version_is(value.get("version"),[1,2,3]) or not value.get("inventory") is Dictionary or not value.get("stocks") is Dictionary:return false
  if value.has("favorites") and not value.favorites is Dictionary:return false
  var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/meme_items.json"))
  var groups:Array=[value.inventory]
  for stock in value.stocks.values():
   if not stock is Dictionary:return false
   groups.append(stock)
  for group in groups:
   for id in group:
    var count:Variant=group[id]
    if not definitions.has(id) or not (count is int or count is float) or not is_finite(float(count)) or float(count)!=floorf(float(count)) or count<0 or count>9999:return false
  if value.has("character"):
   var profile=preload("res://character/life_state.gd").new()
   if not profile.restore(value.character):return false
   for id in profile.state.equipment.values():
    if id!="" and int(value.inventory.get(id,0))<1:return false
 if key in ["expedition","expedition_backup"]:
  if not _version_is(value.get("version"),[1]) or not value.get("profile") is Dictionary or not value.get("run") is Dictionary:return false
 if key=="pack26":
  for field in ["progress","remaining","bag","checkpoints"]:
   if not value.get(field) is Dictionary:return false
 return true

func _snapshot()->Dictionary:
 var files:Dictionary={};var hashes:Dictionary={}
 for key in paths:
  var text:Variant=_read(paths[key])
  if FileAccess.file_exists(paths[key]) and text==null:return {}
  if not _valid_content(key,text):last_error="当前进度尚不可保存，或 %s 数据无效。游戏中先按 F5 / 保存并返回标题。"%key;return {}
  files[key]=text;hashes[key]=text.sha256_text() if text is String else "missing"
 return {"version":VERSION,"created":Time.get_datetime_string_from_system(),"location":str(JSON.parse_string(files.world).location),"files":files,"hashes":hashes}

func read_slot(index:int)->Dictionary:
 var path:=_slot_path(index)
 if path=="":return {}
 var text:Variant=_read(path)
 if not text is String:return {}
 var data:Variant=JSON.parse_string(text)
 if not _valid_bundle(data):last_error="存档槽损坏或版本不兼容，未改动当前进度。";return {}
 return data

func _valid_bundle(data:Variant,allow_missing_world:bool=false)->bool:
 if not data is Dictionary or not _version_is(data.get("version"),[VERSION]) or not data.get("files") is Dictionary or not data.get("hashes") is Dictionary:return false
 if data.files.size()!=paths.size() or data.hashes.size()!=paths.size():return false
 for key in paths:
  if not data.files.has(key) or not data.hashes.has(key):return false
  var text:Variant=data.files[key]
  if not (allow_missing_world and key=="world" and text==null) and not _valid_content(key,text):return false
  if data.hashes[key]!=(text.sha256_text() if text is String else "missing"):return false
 return true

func _write_atomic(path:String,text:String)->bool:
 var temp:=path+".sticker_tmp"
 var file:=FileAccess.open(temp,FileAccess.WRITE)
 if file==null:return false
 file.store_string(text);file.flush();file.close()
 if FileAccess.get_file_as_string(temp)!=text:return false
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path))==OK

func save_slot(index:int,overwrite:bool=false)->bool:
 last_error=""
 var path:=_slot_path(index)
 if path=="":last_error="无效存档槽。";return false
 if FileAccess.file_exists(path) and not overwrite:last_error="该槽已有存档，请确认覆盖。";return false
 var snapshot:=_snapshot()
 if snapshot.is_empty():return false
 var encoded:=JSON.stringify(snapshot)
 if encoded.to_utf8_buffer().size()>MAX_FILE_BYTES:last_error="整份存档超过大小限制，旧槽位已保留。";return false
 if not _write_atomic(path,encoded):last_error="写入失败，旧槽位已保留。";return false
 return not read_slot(index).is_empty()

func _before_bundle()->Dictionary:
 var files:Dictionary={};var hashes:Dictionary={}
 for key in paths:
  var text:Variant=_read(paths[key])
  if FileAccess.file_exists(paths[key]) and text==null:return {}
  files[key]=text;hashes[key]=text.sha256_text() if text is String else "missing"
 return {"version":VERSION,"files":files,"hashes":hashes}

func _apply_files(files:Dictionary)->bool:
 for key in paths:
  var path:String=paths[key]
  if files[key]==null:
   if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path))!=OK:return false
  elif not _write_atomic(path,files[key]):return false
 return true

func restore_slot(index:int)->bool:
 last_error=""
 var data:=read_slot(index)
 if data.is_empty():return false
 var before:=_before_bundle()
 if before.is_empty():last_error="当前进度无法备份，未读取存档。";return false
 if JSON.stringify(before).to_utf8_buffer().size()>MAX_FILE_BYTES:last_error="当前进度备份超过大小限制，未读取存档。";return false
 var journal:=directory+"/pending_restore.json"
 if not _write_atomic(journal,JSON.stringify(before)):last_error="无法建立恢复记录，未改动进度。";return false
 if not _write_atomic(directory+"/before_restore.json",JSON.stringify(before)):last_error="无法保留读档前备份。";return false
 if not _apply_files(data.files):
  var rolled_back:=_apply_files(before.files)
  if rolled_back:DirAccess.remove_absolute(ProjectSettings.globalize_path(journal))
  last_error="读档失败，当前进度已回滚。" if rolled_back else "读档失败；恢复记录已保留，请重试恢复。"
  return false
 for key in paths:
  var actual:Variant=_read(paths[key])
  if (actual.sha256_text() if actual is String else "missing")!=data.hashes[key]:
   _apply_files(before.files);last_error="读档校验失败，已尝试回滚。";return false
 DirAccess.remove_absolute(ProjectSettings.globalize_path(journal))
 return true

func recover_pending()->bool:
 var journal:=directory+"/pending_restore.json"
 if not FileAccess.file_exists(journal):return true
 var text:Variant=_read(journal)
 if not text is String:last_error="上次读档恢复记录无法读取。";return false
 var before:Variant=JSON.parse_string(text)
 last_error="上次读档恢复记录损坏，请保留存档目录并检查备份。"
 # The journal holds original bytes, including an older invalid save; validate fixed keys and hashes without parsing its payloads.
 if not before is Dictionary or not before.get("files") is Dictionary or not before.get("hashes") is Dictionary:return false
 if before.files.size()!=paths.size():return false
 for key in paths:
  if not before.files.has(key) or not before.hashes.has(key):return false
  var raw:Variant=before.files[key]
  if raw!=null and not raw is String:return false
  if before.hashes[key]!=(raw.sha256_text() if raw is String else "missing"):return false
 if not _apply_files(before.files):last_error="上次读档恢复未完成，未进入游戏。";return false
 DirAccess.remove_absolute(ProjectSettings.globalize_path(journal));last_error="";return true
