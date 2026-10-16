extends SceneTree
## Runs the actual world and loot controller with isolated settings and saves.
const OUT="res://预览/正式背包贴纸_20261016/"
const Document=preload("res://ui/design/layout_document.gd")
const StickerSkin=preload("res://ui/harbor_inventory_skin.gd")
var game
var checks:Array=[]
var entries:Array=[]
var failures:=0

func _initialize()->void:
 if not "--show-inventory" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
  DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(ok:bool,message:String)->void:
 checks.append({"ok":ok,"message":message})
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1;push_error(message)

func settle(count:int=8)->void:
 for i in count:await process_frame

func capture(id:String,title:String)->void:
 if not "--bake-sticker-designs" in OS.get_cmdline_user_args():return
 var entry:=Document.capture(id,game.loot.modal,title);entries.append(entry)
 check(entry.error==OK,"editable capture "+id)
 var baseline:=ProjectSettings.globalize_path("res://ui/design/baselines/"+id+".tscn")
 var page:=ProjectSettings.globalize_path("res://ui/design/pages/"+id+".tscn")
 check(DirAccess.copy_absolute(baseline,page)==OK,"install editable page "+id)

func screenshot(name:String)->void:
 await settle()
 await RenderingServer.frame_post_draw
 var error:=root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+name+".png"))
 check(error==OK,"native game screenshot "+name)

func run()->void:
 var args:=OS.get_cmdline_user_args()
 if not "--test-session-ui" in args or not "--test-dialogue" in args:
  push_error("Required isolation flags: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.day_cycle=false
 prefs.starting_place="apt_2";prefs.continue_game=false;prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json"
 var designs=root.get_node("UiDesign");designs.enabled=false
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await settle(30)
 var loot=game.loot;loot.save_path=OUT+"inventory.json";loot.inventory.clear();loot.bag_favorites.clear()
 for id in loot.definitions:
  if loot.inventory.size()<25:loot.inventory[id]=2
 loot.inventory["snack_basket"]=3
 loot.character_data={};loot.bag_category="all";loot.bag_query="";loot.bag_page=0;loot.chosen=""
 loot.open_bag();await settle()
 if "--show-inventory" in args:
  designs.enabled=true;DisplayServer.window_set_title("大肥鱼 · 正式背包新皮肤（隔离存档）");return
 var view=loot.modal.get_child(1)
 check(view.get_script().resource_path=="res://ui/bag_view.gd","I bag uses actual BagView")
 check(view.grid.columns==5 and view.grid.get_child_count()==20,"native bag uses 5 by 4 slots")
 check(loot.modal.get_theme_stylebox("panel").bg_color==StickerSkin.frame("shell").bg_color,"live modal uses approved blue-white skin")
 check(view.next_button.disabled==false,"pagination remains available")
 view.next_button.pressed.emit();await settle();check(view.page==1,"next page works with 20 slots")
 view.previous_button.pressed.emit();await settle();check(view.page==0,"previous page works")
 view.tabs["补给"].pressed.emit();await settle();check(loot.bag_category=="补给" and not view.visible_ids.is_empty(),"existing category callback works")
 view.search.text="零食";view.search.text_changed.emit("零食");await settle();check(view.visible_ids.has("snack_basket"),"existing search finds real item")
 view.search.text="";view.search.text_changed.emit("");view.tabs["all"].pressed.emit();await settle()
 capture("inventory_bag_sticker","随身背包 · 蓝白贴纸")
 await screenshot("01_正式背包")
 loot.chosen="snack_basket";view.refresh();await settle()
 var model=game.character_controller.model
 model.state.vitals.health=40;model.state.vitals.stamina=40;model.state.vitals.hunger=40
 var previous_count:int=loot.inventory["snack_basket"]
 loot.selected_button.pressed.emit();await settle()
 check(int(loot.inventory["snack_basket"])==previous_count-1,"real use callback consumes exactly one item")
 check(model.value("health")>40,"real item use updates character state")
 var favorite=loot.modal.find_child("FavoriteSelectedItem",true,false)
 favorite.pressed.emit();await settle();check(loot.bag_favorites.has("snack_basket"),"favorite still uses original autosave callback")
 check(FileAccess.file_exists(loot.save_path),"actions save to isolated real inventory file")
 loot.close();loot.current_chest=loot.chests[0]
 # Movement is driven by the world, not by the CharacterBody node.
 game.set_physics_process(false);loot.current_chest.show()
 game.player.global_position=loot.current_chest.global_position+Vector3(0,0,1.05);game.player.velocity=Vector3.ZERO
 await settle(3)
 check(loot._in_range(loot.current_chest),"test player can reach actual container")
 var chest_id:String=loot.current_chest.container_id
 loot.stocks[chest_id]={"snack_basket":4,"tea_cup":3,"checklist":1}
 loot.mode="loot";loot.chosen="snack_basket";loot.chest_bag_chosen="";loot._render();await settle()
 var chest_view=loot.modal.get_child(1)
 check(chest_view.bag_grid.columns==3 and chest_view.chest_grid.columns==3,"real container uses two three-column trays")
 var before_bag:int=loot.inventory.get("snack_basket",0)
 var before_stock:int=loot.stocks[chest_id]["snack_basket"]
 loot.take_button.pressed.emit();await settle()
 check(int(loot.inventory.get("snack_basket",0))==before_bag+1 and int(loot.stocks[chest_id]["snack_basket"])==before_stock-1,"real take transaction conserves items")
 check(loot.deposit("snack_basket",1),"real deposit transaction succeeds")
 await settle()
 check(int(loot.inventory.get("snack_basket",0))==before_bag and int(loot.stocks[chest_id]["snack_basket"])==before_stock,"deposit returns both stocks to previous values")
 capture("inventory_chest_sticker","容器与背包 · 蓝白贴纸")
 await screenshot("02_正式宝箱")
 if not entries.is_empty():
  var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
  for entry in entries:
   for old in catalog:
    if old.id==str(entry.id).trim_suffix("_sticker") or old.id==entry.id:
     old.id=entry.id;old.scene=entry.scene;old.controls=entry.controls;old.title=entry.title
  var catalog_file:=FileAccess.open("res://ui/design/catalog.json",FileAccess.WRITE);catalog_file.store_string(JSON.stringify(catalog," ")+"\n");catalog_file.close()
 designs.reload_designs();designs.enabled=true
 loot.close();loot.open_bag();await settle()
 game.set_physics_process(true)
 check(loot.modal.get_theme_stylebox("panel").bg_color==StickerSkin.frame("shell").bg_color,"editable runtime does not restore obsolete purple skin")
 var report:=FileAccess.open(OUT+"checks.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"editable_pages":entries},"  "));report.close()
 print("STICKER INVENTORY: ",checks.size()," checks, ",failures," failures")
 game.queue_free();await settle(4);quit(0 if failures==0 else 1)
