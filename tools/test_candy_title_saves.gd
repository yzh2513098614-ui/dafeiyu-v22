extends SceneTree
const Slots=preload("res://ui/candy_title_saves.gd")
const OUTPUT="res://预览/糖果贴纸开始界面_20261012/service_test"
var checks:=0
var failures:=0

class FailOnceSlots extends Slots:
 var fail_path:=""
 var triggered:=false
 func _write_atomic(path:String,text:String)->bool:
  if path==fail_path and not triggered:triggered=true;return false
  return super._write_atomic(path,text)

func check(value:bool,message:String)->void:
 checks+=1
 if value:print("PASS: ",message)
 else:failures+=1;push_error(message)

func write(path:String,data:Variant)->void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()

func _initialize()->void:call_deferred("run")

func run()->void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var service:=Slots.new();service.directory=OUTPUT+"/slots";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(service.directory))
 service.paths={"world":OUTPUT+"/world.json","inventory":OUTPUT+"/inventory.json","dialogue":OUTPUT+"/dialogue.json","pack26":OUTPUT+"/pack26.json","expedition":OUTPUT+"/expedition.json","expedition_backup":OUTPUT+"/expedition.bak"}
 for key in service.paths:
  if FileAccess.file_exists(service.paths[key]):DirAccess.remove_absolute(ProjectSettings.globalize_path(service.paths[key]))
 for index in range(1,7):
  var path:=service._slot_path(index)
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 check(not service.save_slot(1),"empty active world cannot create a false save")
 var world:Dictionary={"version":6,"location":"apt_2","position":[1.0,1.0],"rooms":{},"visited":{},"favorites":{}}
 var inventory:Dictionary={"version":3,"inventory":{"token_cracker":3},"stocks":{},"favorites":{}}
 var dialogue:Dictionary={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[{"speaker":"大肥鱼","text":"海风正好。","topic":"鲸落港"}]}
 write(service.paths.world,world);write(service.paths.inventory,inventory);write(service.paths.dialogue,dialogue)
 check(service.save_slot(1),"snapshot stores world inventory and dialogue together")
 var first:=service.read_slot(1)
 if first.is_empty():push_error(service.last_error);quit(1);return
 check(first.files.size()==6 and first.files.pack26==null,"absent optional save has explicit missing state")
 var prior_slot:=FileAccess.get_file_as_string(service._slot_path(1))
 check(not service.save_slot(1),"occupied slot needs overwrite confirmation")
 check(FileAccess.get_file_as_string(service._slot_path(1))==prior_slot,"unconfirmed overwrite retains old bytes")
 check(not service.save_slot(0) and not service.save_slot(7),"out-of-range slots cannot escape directory")
 world.location="city";write(service.paths.world,world)
 inventory.inventory.token_cracker=9;write(service.paths.inventory,inventory)
 write(service.paths.pack26,{"progress":{},"remaining":{},"bag":{},"checkpoints":{}})
 check(service.restore_slot(1),"restore succeeds after independent active-file changes")
 check(JSON.parse_string(FileAccess.get_file_as_string(service.paths.world)).location=="apt_2","world location restored")
 check(JSON.parse_string(FileAccess.get_file_as_string(service.paths.inventory)).inventory.token_cracker==3,"inventory restored from same snapshot")
 check(not FileAccess.file_exists(service.paths.pack26),"optional progress absent from snapshot is not leaked from newer save")
 check(FileAccess.file_exists(service.directory+"/before_restore.json"),"restore retains a durable previous-progress backup")
 check(not FileAccess.file_exists(service.directory+"/pending_restore.json"),"successful transaction clears pending recovery")
 var broken:Dictionary=first.duplicate(true);broken.files.world="{}";write(service._slot_path(2),broken)
 var original_world:=FileAccess.get_file_as_string(service.paths.world)
 check(not service.restore_slot(2),"corrupt slot refused before mutation")
 check(FileAccess.get_file_as_string(service.paths.world)==original_world,"corrupt slot does not touch active world")
 write(service.paths.inventory,{"version":3,"inventory":{"token_cracker":-1},"stocks":{}})
 check(not service.save_slot(3),"negative inventory counts refused")
 write(service.paths.inventory,inventory)
 var invalid_world:=world.duplicate(true);invalid_world.position=["bad",1];write(service.paths.world,invalid_world)
 check(not service.save_slot(3),"malformed position refused")
 write(service.paths.world,world)
 check(service.save_slot(1,true),"explicit overwrite succeeds")
 var damaged:Dictionary=service.read_slot(1).duplicate(true);damaged.files.inventory="{}";damaged.hashes.inventory="{}".sha256_text();write(service._slot_path(2),damaged)
 check(not service.restore_slot(2),"updated checksum cannot bypass payload validation")
 var prior:=service._before_bundle()
 write(service.directory+"/pending_restore.json",prior)
 var changed:=world.duplicate(true);changed.location="market";write(service.paths.world,changed)
 check(service.recover_pending(),"interrupted restore journal recovers on next startup")
 check(FileAccess.get_file_as_string(service.paths.world)==prior.files.world,"recovery returns original world bytes")
 var failure:=FailOnceSlots.new();failure.directory=service.directory;failure.paths=service.paths.duplicate();failure.fail_path=service.paths.inventory
 check(not failure.restore_slot(1),"simulated second-file write failure is reported")
 check(failure.triggered and FileAccess.get_file_as_string(service.paths.world)==prior.files.world,"partial transaction rolls world back")
 check(FileAccess.get_file_as_string(service.paths.inventory)==prior.files.inventory,"partial transaction rolls inventory back")
 check(not FileAccess.file_exists(service.directory+"/pending_restore.json"),"successful rollback clears recovery journal")
 for invalid_version in [{},[],"3",true,3.5]:
  var malformed:=inventory.duplicate(true);malformed.version=invalid_version
  check(not service._valid_content("inventory",JSON.stringify(malformed)),"malformed inventory version refused without conversion: "+str(invalid_version))
 write(service.directory+"/pending_restore.json",{"files":{},"hashes":{}})
 check(not service.recover_pending() and service.last_error!="","damaged recovery journal gives actionable error")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(service.directory+"/pending_restore.json"))
 var report:=FileAccess.open(OUTPUT+"/result.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));report.close()
 print("CANDY_SAVE_REVIEW: ",checks," checks, ",failures," failures");quit(0 if failures==0 else 1)
