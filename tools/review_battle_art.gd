extends SceneTree
const OUT="res://预览/战斗界面美术_v22/"
var screen
var failures:=0
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks.append({"ok":ok,"check":message});print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1;push_error(message)
func draw() -> void:
 for i in 5:await process_frame
 RenderingServer.force_draw()
func shot(name: String) -> void:
 await draw();root.get_texture().get_image().save_png(OUT+name+".png")
func key(code: int) -> void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true;root.push_input(e,true)
 await process_frame;e.pressed=false;root.push_input(e,true);await draw()
func click(button: Control) -> void:
 var point: Vector2=button.get_global_transform_with_canvas()*(button.size*.5)
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=true
 root.push_input(event,true);await process_frame;event.pressed=false;root.push_input(event,true);await draw()
func verify_layout() -> void:
 var bounds:=Rect2(Vector2.ZERO,screen.root.size)
 for panel in [screen.command_box,screen.dash.dock,screen.log_box,screen.tactics_box,screen.skill_box]:
  check(bounds.encloses(Rect2(panel.position,panel.size)),"panel fits viewport: "+str(panel.name))
 for button in screen.command_buttons:
  check(Rect2(Vector2.ZERO,screen.command_box.size).encloses(Rect2(button.global_position-screen.command_box.global_position,button.size)),"action fits horizontal bar: "+button.text)
 var count:=0
 for slot in screen.slots:
  if slot.foe==null:continue
  count+=1
  check(slot.art.position.x>=0 and slot.art.get_rect().end.x<=screen.root.size.x,"enemy art fits viewport: "+str(slot.foe.name))
 check(screen.command_buttons.size()==6,"all six combat actions remain reachable")
 check(screen.enemy_layer.get_child_count()==3,"battlefield contains enemy slots only")
func build(kinds: Array) -> void:
 var balance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/combat_balance.json"))
 var engine=load("res://battle/battle_engine.gd").new(721)
 engine.add_ally({"id":"player","name":"大肥鱼","level":8,"hp":74,"max_hp":100,"stamina":82,"max_stamina":100,"ap":36,"atk":15,"def":8,"spd":12,"stats":{"strength":5,"endurance":5,"insight":5,"charm":5,"agility":5,"luck":2}})
 var textures: Dictionary={}
 for kind in balance.monsters:textures[kind]=balance.monsters[kind].texture
 for i in kinds.size():engine.add_foe(engine.foe_entry_from_monster({"id":"review_"+str(i),"type":kinds[i]},balance.monsters[kinds[i]]))
 screen=load("res://battle/battle_screen.gd").new();root.add_child(screen)
 screen.open(engine,{"title":"潮汐遭遇战","textures":textures,"items":[{"id":"first_aid","name":"急救包","count":3,"effects":{"health":35},"usable":true},{"id":"sea_biscuit","name":"海盐饼干","count":2,"effects":{"stamina":25},"usable":true}]})
func run() -> void:
 if DisplayServer.get_name()=="headless" or not "--battle-art-review" in OS.get_cmdline_user_args():quit(2);return
 AudioServer.set_bus_mute(0,true);DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1000,750)
 build(["slime"]);await create_timer(.85).timeout
 if screen.mode=="busy":screen.skip_playback()
 await shot("01_战斗主界面_4比3");verify_layout()
 root.size=Vector2i(1280,720);await shot("02_战斗主界面_16比9");verify_layout()
 screen._on_skill_menu();await shot("03_技能选择")
 check(screen.skill_list.get_child_count()==6,"all six skills populate scrollable menu")
 check(root.gui_get_focus_owner() is Button,"skill list retains keyboard focus")
 await key(KEY_ESCAPE);check(screen.mode=="command","Escape returns from skills")
 screen._on_item_menu();await shot("04_补给选择")
 check(screen.skill_list.get_child_count()==2,"battle item menu stays functional")
 await key(KEY_ESCAPE);check(screen.mode=="command","Escape returns from items")
 screen.engine.allies[0].ap=100;screen._refresh_all();await shot("05_连携就绪")
 check(not screen.link_button.disabled,"full AP enables link action")
 var result_before: String=screen.engine.result
 await key(KEY_RIGHT);check(root.gui_get_focus_owner() in screen.command_buttons,"horizontal navigation stays in command buttons")
 screen.engine.foes[0].hp=1;screen._on_attack();screen.skip_playback();await create_timer(.5).timeout
 await shot("06_胜利结算");check(screen.mode=="result" and screen.result_box.visible,"attack reaches visible victory result")
 screen.close();screen.free();await draw()
 root.size=Vector2i(1000,750);build(["slime","crab","guardian"]);await create_timer(.85).timeout
 if screen.mode=="busy":screen.skip_playback()
 await shot("07_三敌人_4比3");verify_layout()
 screen._cycle_target();check(int(screen.context.target)==1,"switch target still selects second foe")
 screen.engine.allies[0].shield=2;screen.engine.foes[1].shield=1;screen._refresh_all();await create_timer(.3).timeout
 await shot("08_护盾与目标状态")
 screen.context.pending_result="lose";screen.mode="result";screen.result_label.text="暂时力竭";screen.result_details.text="回港补给后，可以再次挑战。";screen._play_result();await create_timer(.5).timeout
 await shot("09_力竭结算");check(not screen.result_banner.visible,"defeat does not show victory trophy")
 screen.close();screen.free();await draw()
 await real_battle()
 var simulation: Dictionary=load("res://tools/test_battle.gd").new().run(500)
 check(simulation.failures.is_empty(),"500 combat simulations retain valid results and resource limits")
 for id in simulation.targeted:check(bool(simulation.targeted[id].pass),"combat rule retained: "+id)
 var file:=FileAccess.open(OUT+"界面验证.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"simulation":simulation.stats},"  "))
 print("BATTLE ART CHECKS ",checks.size()," FAILURES ",failures)
 quit(failures)

func real_battle() -> void:
 var prefs=root.get_node("HarborPrefs");prefs.starting_place="city";prefs.continue_game=false;prefs.values.fullscreen=false
 prefs.world_save_path="user://battle_art_review_world.json"
 root.size=Vector2i(1000,750)
 var game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await draw()
 game.dialogue_controller.close();game.loot.save_path="user://battle_art_review_inventory.json"
 game.character_controller.model=load("res://character/life_state.gd").new()
 game.loot.inventory.first_aid=2;game._travel("trial")
 var combat=game.combat_controller
 game.player.position=combat.markers[0].position+Vector3(0,0,1.5);await create_timer(.15).timeout
 check(combat.near!=null and combat.prompt.visible,"real encounter offers battle entry")
 await click(combat.fight_button);check(combat.in_battle(),"real battle button opens redesigned screen")
 if not combat.in_battle():game.free();return
 await create_timer(.85).timeout
 screen=combat.screen
 if screen.mode=="busy":screen.skip_playback()
 await shot("10_实际游戏_一级遭遇战")
 var position: Vector3=game.player.position;var hour: float=game.atmosphere.hour
 game.movement=Vector2.RIGHT;await create_timer(.15).timeout;game.movement=Vector2.ZERO
 check(game.player.position==position and is_equal_approx(game.atmosphere.hour,hour),"world movement and day clock remain frozen during battle")
 await click(screen.skill_button);check(screen.mode=="skill","real skill button opens submenu")
 await key(KEY_ESCAPE);check(screen.mode=="command","real submenu returns to actions")
 screen.engine.allies[0].hp=40;screen._refresh_all();await click(screen.item_button)
 var item_buttons: Array=screen.skill_list.get_children()
 check(not item_buttons.is_empty(),"real backpack supply appears in battle")
 if not item_buttons.is_empty():
  await click(item_buttons[0])
  if screen.mode=="busy":screen.skip_playback()
  check(int(game.loot.inventory.first_aid)==1 and screen.engine.allies[0].hp>40,"real item click consumes one supply and heals")
 screen.engine.foes[0].hp=1;screen._on_attack();screen.skip_playback();await create_timer(.4).timeout
 check(screen.mode=="result" and screen.result_box.visible,"real battle opens reward result")
 await shot("11_实际游戏_奖励结算")
 await click(screen.result_go);check(not combat.in_battle(),"real result button returns to map")
 game.free();await draw()
