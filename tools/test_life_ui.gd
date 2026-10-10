extends SceneTree
const OUTPUT="res://预览/人物数值与道具_v19/"
var game
var prefs
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)
func frames(count: int=5) -> void:
 for i in count:await process_frame
func key(code: Key) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event)
 await process_frame
 var release:=event.duplicate();release.pressed=false;root.push_input(release);await process_frame
func click(button: Button) -> void:
 root.notify_mouse_entered()
 var point:=button.get_global_transform_with_canvas()*(button.size*.5)
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
 var press:=InputEventMouseButton.new();press.position=point;press.button_index=MOUSE_BUTTON_LEFT;press.button_mask=MOUSE_BUTTON_MASK_LEFT;press.pressed=true;root.push_input(press,true)
 await process_frame
 var release:=press.duplicate();release.pressed=false;release.button_mask=0;root.push_input(release,true);await frames(2)
func shot(filename: String) -> void:
 await frames();await create_timer(.2).timeout;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename))
func write_json(path: String,data: Dictionary) -> void:
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
func select(id: String) -> void:
 game.loot.chosen=id;game.loot.modal.get_child(0).refresh();await process_frame
func run() -> void:
 prefs=root.get_node("HarborPrefs");prefs.values.fullscreen=false;prefs.starting_place="apt_2";prefs.continue_game=false;prefs.apply_window();root.size=Vector2i(1000,750)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 check(prefs.world_save_path=="user://whale_life_ui_test.json","life checks use isolated journey")
 write_json("user://whale_inventory_life_ui_test.json",{"version":1,"inventory":{"sea_biscuit":4},"stocks":{},"favorites":{}})
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await frames(12)
 game.set_physics_process(false);game.dialogue_controller.close()
 var cc=game.character_controller;var model=cc.model;var loot=game.loot
 check(loot.inventory.sea_biscuit==6 and loot.inventory.prompt_pen==1,"old inventory migration retains quantities and grants starter once")
 var migrated=JSON.parse_string(FileAccess.get_file_as_string(loot.save_path))
 check(migrated.version==2 and migrated.character.version==1,"migration writes combined inventory and character")
 for id in loot.definitions:loot.inventory[id]=2
 model.state.vitals={"health":70.0,"stamina":40.0,"hunger":60.0,"mood":50.0};cc.refresh()
 await shot("01_角色状态HUD.png")
 await key(KEY_C)
 check(cc.active and not game.ui.visible,"actual C opens character status")
 var state_before: Dictionary=model.snapshot()
 await create_timer(.25).timeout
 check(model.snapshot()==state_before,"status page freezes needs and buff timers")
 await key(KEY_Q)
 check(not game.dialogue_controller.active,"status page blocks dialogue shortcut")
 await shot("02_人物属性.png")
 cc.rest_button.grab_focus();await key(KEY_ENTER)
 check(model.value("stamina")==75 and model.value("health")==80 and model.value("hunger")==56,"actual Enter on Rest updates all costs and gains")
 await click(cc.bag_button)
 check(loot.mode=="inventory" and not cc.active,"actual mouse opens backpack from status page")
 if loot.mode!="inventory":cc.close();loot.open_bag()
 await select("sea_biscuit")
 var count: int=loot.inventory.sea_biscuit
 loot.selected_button.pressed.emit();await frames()
 check(loot.inventory.sea_biscuit==count-1 and model.value("health")==90 and model.value("stamina")==93 and model.value("hunger")==78,"food click consumes one and applies configured numeric effects")
 await shot("03_补给效果.png")
 for id in model.state.vitals:model.state.vitals[id]=model.maximum(id)
 await select("first_aid");count=loot.inventory.first_aid;loot.selected_button.pressed.emit();await frames()
 check(loot.inventory.first_aid==count and loot.status.contains("不会消耗"),"full-health first aid remains in inventory")
 model.state.vitals.health=40.0;model.state.vitals.stamina=30.0
 var before_inventory: Dictionary=loot.inventory.duplicate(true);state_before=model.snapshot()
 var actual_path: String=loot.save_path;loot.save_path="user://life_ui_missing_folder/failed.json"
 await select("first_aid");loot.selected_button.pressed.emit();await frames()
 check(model.snapshot()==state_before and loot.inventory==before_inventory,"failed item save rolls back character and quantity")
 loot.save_path=actual_path
 await select("prompt_pen");count=loot.inventory.prompt_pen;loot.selected_button.pressed.emit();await frames()
 check(model.attribute("insight")==7 and loot.inventory.prompt_pen==count,"equipment gives bonus without consuming quantity")
 await shot("04_装备说明.png")
 await select("tide_compass");loot.selected_button.pressed.emit();await frames()
 check(model.attribute("insight")==5 and model.attribute("agility")==5 and model.state.equipment.tool=="tide_compass","new equipment replaces same slot without bonus accumulation")
 await select("fish_badge");loot.selected_button.pressed.emit();await frames()
 check(model.attribute("charm")==8 and model.state.base.charm==6,"trinket uses independent slot and leaves base unchanged")
 await select("retry_tea");loot.selected_button.pressed.emit();await frames()
 check(model.state.buffs.get("calm",0)==90,"tea item supplies finite buff")
 var history_count: int=loot.inventory.whale_letter
 await select("whale_letter");loot.selected_button.pressed.emit();await frames()
 check(loot.inventory.whale_letter==history_count,"reading clue never consumes it")
 loot.modal.get_child(0).tabs["材料"].pressed.emit();await frames()
 check(loot.modal.get_child(0).visible_ids.size()==2,"materials have working backpack filter")
 await shot("05_材料分类.png")
 loot.close();await key(KEY_C);await shot("06_已装备与暖茶状态.png")
 var rest_before: Dictionary=model.snapshot();loot.save_path="user://life_ui_missing_folder/failed.json";cc.rest_button.pressed.emit();await frames()
 check(model.snapshot()==rest_before,"failed rest save rolls back vitals")
 loot.save_path=actual_path
 cc.equipment_buttons.tool.pressed.emit();await frames()
 check(model.state.equipment.tool=="" and model.attribute("agility")==4 and loot.inventory.tide_compass==2,"status slot button unequips without losing item")
 model.apply_item("prompt_pen");loot.save_state();cc.refresh()
 var saved_state: Dictionary=model.snapshot();var saved_inventory: Dictionary=loot.inventory.duplicate(true)
 check(loot.load_state() and model.attribute("insight")==7 and loot.inventory==saved_inventory,"reload combined file restores bonuses exactly once")
 var valid_data:=FileAccess.get_file_as_string(loot.save_path)
 var bad=JSON.parse_string(valid_data);bad.character.equipment.tool="not_owned";write_json(loot.save_path,bad)
 check(not loot.load_state() and model.snapshot()==saved_state and loot.inventory==saved_inventory,"corrupt character save rejects without changing live state")
 var file:=FileAccess.open(loot.save_path,FileAccess.WRITE);file.store_string(valid_data);file.close()
 var xp: int=model.state.xp;model.discover("test:new_room");var after_xp: int=model.state.xp;model.discover("test:new_room")
 check(after_xp>xp and model.state.xp==after_xp,"actual character grants discovery xp only once")
 await key(KEY_ESCAPE)
 game.set_physics_process(true);game.player.position=Vector3(0,0,0);game.movement=Vector2.RIGHT;model.state.vitals.stamina=70
 var stamina: float=model.value("stamina");var anchor: Vector3=game.player.position
 await create_timer(.2).timeout;game.movement=Vector2.ZERO
 check(game.player.position.distance_to(anchor)>.05 and model.value("stamina")<stamina,"actual walking spends stamina without render-frame idle recovery")
 await key(KEY_ESCAPE)
 check(game.pause_menu.active,"Escape still opens pause after status closes")
 state_before=model.snapshot();await create_timer(.2).timeout
 check(model.snapshot()==state_before,"pause freezes character needs and buffs")
 await shot("07_完善后的暂停菜单.png")
 print("LIFE UI CHECKS ",checks," PASSED ",checks-failures," FAILED ",failures)
 quit(0 if failures==0 else 1)
