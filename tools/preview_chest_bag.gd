extends SceneTree
## Actual engine screenshots and mouse/keyboard checks, using isolated saves.
const OUTPUT="res://预览/宝箱背包_20261011/"
var game
var loot
var checks:=0
var failures:=0
var evidence: Array=[]

func _initialize() -> void:
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
  DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 checks+=1;evidence.append({"ok":ok,"check":message})
 if ok:print("PASS: ",message)
 else:failures+=1;push_error(message)

func settle(count: int=5) -> void:
 for i in count:await process_frame

func click(control: Control) -> void:
 await settle(3)
 var point:=control.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=point;press.pressed=true;root.push_input(press,true);await process_frame
 var release:=press.duplicate();release.pressed=false;root.push_input(release,true);await settle(4)

func key(code: Key) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;root.push_input(event,true);await process_frame
 var release:=event.duplicate();release.pressed=false;root.push_input(release,true);await settle(3)

func shot(name: String) -> void:
 await settle(8);await RenderingServer.frame_post_draw
 var path:=OUTPUT+name+".png";root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path));print("SCREENSHOT: ",path)

func select_item(id: String) -> void:
 loot.chosen=id
 if loot.mode=="inventory":loot.modal.get_child(0).refresh()
 else:loot._render()
 await settle()

func bounds() -> void:
 var outer: Rect2=loot.modal.get_global_rect()
 check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(outer),"modal stays inside viewport at "+str(root.size))
 var buttons: Array=[]
 _buttons(loot.modal,buttons)
 for b in buttons:
  check(outer.encloses(b.get_global_rect()),"control inside modal: "+str(b.name))
 var overlap:=false
 for i in buttons.size():
  for j in range(i+1,buttons.size()):
   if buttons[i].get_global_rect().intersection(buttons[j].get_global_rect()).get_area()>1:overlap=true
 check(not overlap,"interactive controls do not overlap at "+str(root.size))

func _buttons(node: Node,output: Array) -> void:
 for child in node.get_children():
  if child is Button and not child.disabled:output.append(child)
  _buttons(child,output)

func open_fixture() -> void:
 loot.close();loot.nearby=loot.chests[0]
 game.player.global_position=loot.nearby.global_position+Vector3(0,0,1.05)
 await settle(4);loot.open_chest();await settle(4)

func run() -> void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():push_error("Required flags: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs");prefs.settings_path=OUTPUT+"settings.cfg";prefs.world_save_path=OUTPUT+"world.json";prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.day_cycle=false;prefs.continue_game=false;prefs.starting_place="apt_2"
 var initial_inventory: Dictionary={"sea_biscuit":5,"first_aid":3,"prompt_pen":1,"fish_badge":1,"whale_letter":1,"sea_shell":4,"retry_tea":2,"tide_compass":1}
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await settle(15)
 game.set_physics_process(false);game.dialogue_controller.close();loot=game.loot;loot.inventory=initial_inventory;loot.bag_favorites={"whale_letter":true};loot._bag_count();root.notify_mouse_entered()
 loot.save_path=OUTPUT+"inventory.json";loot.save_state()
 check(prefs.world_save_path.begins_with(OUTPUT) and loot.save_path.begins_with(OUTPUT),"preview uses isolated world, settings and inventory")
 check(not loot.chests.is_empty(),"real map contains an interactive chest")
 await open_fixture()
 check(loot.mode=="loot","real nearby chest opens")
 if loot.mode!="loot":quit(1);return
 check(loot.modal.get_child(0).bag_grid.get_child_count()==24 and loot.modal.get_child(0).chest_grid.get_child_count()==12,"two inventories render real grids")
 bounds();await shot("01_宝箱_4比3")
 var chest_id: String=loot.current_chest.container_id
 loot.stocks[chest_id]={"token_cracker":4,"first_aid":2,"context_note":1};loot._render();await settle()
 await click(loot.rows.token_cracker)
 check(loot.chosen=="token_cracker","mouse selects container item")
 var before_count: int=int(loot.inventory.get("token_cracker",0))
 await click(loot.quantity_plus);check(int(loot.quantity.value)==2,"mouse increases quantity")
 await click(loot.take_button)
 check(int(loot.inventory.token_cracker)==before_count+2 and int(loot.stocks[chest_id].token_cracker)==2,"quantity transfer conserves both inventories")
 await shot("02_取物反馈")
 var before_inventory: Dictionary=loot.inventory.duplicate(true);var before_stock: Dictionary=loot.stocks.duplicate(true);var valid_path: String=loot.save_path
 loot.save_path=OUTPUT+"missing/fail.json"
 check(not loot.transfer_all() and loot.inventory==before_inventory and loot.stocks==before_stock,"failed bulk save restores inventory and entire stock")
 loot.save_path=valid_path
 await click(loot.take_all_button)
 check(loot.stock_total(chest_id)==0,"mouse collects whole chest")
 var received: Dictionary=loot.inventory.duplicate(true)
 check(not loot.transfer_all() and received==loot.inventory,"empty chest cannot grant duplicate loot")
 await shot("03_空宝箱")
 check(loot.take_button.disabled and loot.take_all_button.disabled,"empty chest disables collection actions")
 loot.close();check(not loot.blocked() and not loot.modal_shade.visible,"close restores world input")
 await key(KEY_I);check(loot.mode=="inventory","I opens backpack")
 bounds();await shot("04_背包_4比3")
 var bag=loot.modal.get_child(0)
 await click(bag.tabs["材料"]);check(bag.visible_ids.has("sea_shell") and bag.visible_ids.size()==1,"mouse category filters material")
 await click(bag.tabs.all)
 bag.search.text="不存在的鲸鱼物品";bag.search.text_changed.emit(bag.search.text);await settle()
 check(bag.visible_ids.is_empty() and loot.selected_button==null,"empty search shows safe empty state");await shot("05_空搜索")
 bag.search.text="";bag.search.text_changed.emit("");await settle()
 await select_item("first_aid")
 var favorite_button=loot.modal.find_child("FavoriteSelectedItem",true,false)
 await click(favorite_button);check(loot.bag_favorites.has("first_aid"),"mouse favorite is persisted")
 var model=game.character_controller.model;model.state.vitals.health=50.0
 var aid_before: int=int(loot.inventory.first_aid)
 await click(loot.selected_button)
 check(loot.inventory.first_aid==aid_before-1 and model.value("health")>50,"mouse uses supply and updates character")
 var saved_inventory: Dictionary=loot.inventory.duplicate(true);var saved_character: Dictionary=model.snapshot()
 loot.save_path=OUTPUT+"missing/fail.json";await select_item("sea_biscuit");await click(loot.selected_button)
 check(saved_inventory==loot.inventory and saved_character==model.snapshot(),"failed item save restores quantity and character")
 loot.save_path=valid_path
 await select_item("prompt_pen");var pen_before: int=int(loot.inventory.prompt_pen);await click(loot.selected_button)
 check(loot.is_equipped("prompt_pen") and loot.inventory.prompt_pen==pen_before,"mouse equips without consuming item")
 await shot("06_装备与反馈")
 await select_item("whale_letter");var letter_before: int=int(loot.inventory.whale_letter);await click(loot.selected_button)
 check(loot.inventory.whale_letter==letter_before,"reading clue never consumes it")
 for id in loot.definitions:loot.inventory[id]=2
 loot.bag_category="all";loot.bag_query="";loot.bag_page=0;loot._render();await settle()
 bag=loot.modal.get_child(0);await click(bag.next_button)
 check(bag.page==1,"mouse paginates more than 24 item kinds")
 check(loot.rows.has(loot.chosen),"pagination selects an item visible on the current page")
 var current_page: int=bag.page;await click(loot.selected_button)
 check(loot.modal.get_child(0).page==current_page,"item action retains inventory page")
 loot.close();await open_fixture()
 loot.stocks[chest_id]=loot.INITIAL_STOCK[chest_id].duplicate(true)
 for id in loot.stocks[chest_id]:loot.stocks[chest_id][id]=0
 loot.stocks[chest_id].token_cracker=3;loot.stocks[chest_id].context_note=1;loot.inventory={"token_cracker":9998}
 for i in 63:
  var id:="fixture_"+str(i);loot.definitions[id]=loot.definitions.sea_shell.duplicate(true);loot.inventory[id]=1
 loot._render();await settle()
 check(loot.occupied_slots()==64 and loot.receivable_total()==1,"full inventory can fill existing stack without a new slot")
 check(loot.transfer_all() and loot.inventory.token_cracker==9999 and loot.stocks[chest_id].token_cracker==2 and loot.stocks[chest_id].context_note==1,"partial collection leaves overflow in chest")
 await shot("07_容量已满")
 check(not loot.transfer_all(),"full slots and stacks block further receipt")
 var full_inventory: Dictionary=loot.inventory.duplicate(true);var full_stocks: Dictionary=loot.stocks.duplicate(true);loot.close()
 # Remove fixture equipment ownership before round-trip validation.
 for slot in model.state.equipment:model.state.equipment[slot]=""
 loot.save_state();check(loot.load_state() and loot.inventory==full_inventory and loot.stocks==full_stocks,"reload preserves depleted stocks and full inventory")
 for i in 63:loot.inventory.erase("fixture_"+str(i));loot.definitions.erase("fixture_"+str(i))
 loot.inventory={"sea_biscuit":5,"first_aid":3,"prompt_pen":1,"whale_letter":1,"fish_badge":1,"retry_tea":2};loot.save_state();loot._bag_count();loot.bag_category="all";loot.bag_query="";loot.bag_page=0
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600),Vector2i(720,960)]:
  root.size=dimensions;await settle(10);loot.open_bag();await settle(4);bounds();await shot("08_背包_"+str(dimensions.x)+"x"+str(dimensions.y));loot.close()
 root.size=Vector2i(1280,720);await settle(8);await open_fixture();bounds();await shot("09_宝箱_宽屏")
 await key(KEY_ESCAPE);check(not loot.blocked(),"Esc closes chest")
 await key(KEY_I);await key(KEY_I);check(not loot.blocked(),"I toggles backpack closed")
 var report:=FileAccess.open(OUTPUT+"checks.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":evidence},"  "));report.close()
 print("CHEST_BAG_CHECKS: ",checks," failures=",failures)
 quit(0 if failures==0 else 1)
