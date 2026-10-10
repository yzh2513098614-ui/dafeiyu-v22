extends SceneTree
const OUT = "user://battle_ui_validation_20261004/"
var game
var failures := 0
var results: Array = []
var prefs
func _initialize() -> void:
 call_deferred("run")
func frames(count: int = 8) -> void:
 for i in count: await process_frame
func record(name: String, evidence: Variant) -> void:
 results.append({"check":name,"evidence":evidence})
 print("REVIEW ",name," ",JSON.stringify(evidence))
 var ok := true
 match name:
  "world_and_clock_frozen": ok = evidence.position and evidence.clock
  "failed_item_save": ok = evidence.hp_before == evidence.hp_after and evidence.count_before == evidence.count_after and evidence.round_before == evidence.round_after
  "battle_return_and_rewards": ok = evidence.battle_closed and evidence.defeated.get("slime_a", false)
  "practice_gate_before_boss": ok = not evidence
  "battle_engine_500": ok = evidence.failures.is_empty()
  "resized_gauges": ok = evidence
  "persisted_item_vitals": ok = evidence
  "checkpoint_replay": ok = evidence
  "guide_rng_unchanged": ok = evidence
  "reward_provider_idempotent": ok = evidence
  "defeat_has_no_trophy": ok = evidence
  "Q_during_battle_opens_dialogue", "I_during_battle_opens_bag", "M_during_battle_opens_map", "B_during_battle_enables_edit", "Tab_during_battle_opens_catalog", "Escape_during_battle_opens_pause": ok = not evidence
 if not ok:
  failures += 1
  push_error("FAILED: " + name)
func shot(name: String) -> void:
 await frames(8)
 RenderingServer.force_draw()
 root.get_texture().get_image().save_png(OUT+name+".png")
func key(code: int) -> void:
 var e := InputEventKey.new()
 e.keycode=code;e.physical_keycode=code;e.pressed=true
 root.push_input(e,true)
 await frames(2)
 e.pressed=false;root.push_input(e,true)
 await frames(3)
func click(b: Control) -> void:
 var p: Vector2 = b.get_global_transform_with_canvas() * (b.size * .5)
 var m:=InputEventMouseMotion.new();m.position=p;root.push_input(m,true)
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.pressed=true
 root.push_input(e,true);await frames(2)
 e.pressed=false;root.push_input(e,true);await frames(3)
func finish_playback(s) -> void:
 if s.mode=="busy":s.skip_playback()
 await frames(3)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OUT)
 prefs=root.get_node("HarborPrefs")
 prefs.settings_path="user://battle_ui_20261004_settings.cfg"
 prefs.world_save_path="user://battle_ui_20261004_world.json"
 prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.day_cycle=true
 prefs.starting_place="city";prefs.continue_game=false;prefs.apply_window()
 root.size=Vector2i(1000,750)
 root.get_node("MusicDirector").set_enabled(false)
 root.get_node("SfxDirector").set_enabled(false)
 var menu=load("res://ui/start_menu.tscn").instantiate()
 root.add_child(menu);current_scene=menu
 await shot("01_标题_4比3")
 menu._show_page("journey");await shot("02_出发选择")
 root.size=Vector2i(1280,720);menu._show_page("title");await shot("03_标题_16比9")
 record("title_departures",menu.PLACES.size())
 menu._show_page("music");await shot("04_音乐鉴赏")
 menu.free()
 game=load("res://district/continuous_world.tscn").instantiate()
 root.add_child(game);current_scene=game
 await frames(16)
 game.loot.save_path="user://battle_ui_20261004_inventory.json"
 game.dialogue_controller.save_path="user://battle_ui_20261004_dialogue.json"
 game.dialogue_controller.close()
 game.atmosphere.set_time(12)
 record("locations",game.locations.keys())
 await shot("05_街区_默认跟随")
 game._toggle_view();await shot("06_街区_全览")
 game._travel("apt_2");await shot("07_公寓二层_全览")
 game._toggle_view();await shot("08_公寓二层_跟随")
 game.character_controller.open();await shot("09_人物属性")
 game.character_controller.close()
 game.loot.inventory.first_aid=2;game.loot.inventory.sea_biscuit=2
 game.loot.open_bag();game.loot.chosen="first_aid";game.loot._render();await shot("10_背包")
 game.loot.close()
 game.dialogue_controller.start_topic();await frames(30);await shot("11_立绘对话")
 game.dialogue_controller.close()
 game._travel("garden");await shot("12_花房")
 game._travel("trial")
 var combat=game.combat_controller
 game.player.position=combat.markers[0].position+Vector3(0,0,1.5)
 await frames(14)
 record("encounter_near",combat.near!=null and combat.prompt.visible)
 await shot("13_靠近怪物")
 await click(combat.avoid_button)
 record("avoid_keeps_world",not combat.in_battle() and not combat.prompt.visible)
 combat.markers[0].cooldown=0;await frames(10)
 await click(combat.fight_button)
 var s=combat.screen
 record("mouse_enters_battle",s!=null)
 if s==null:quit(2);return
 await frames(25);await finish_playback(s)
 await shot("14_战斗界面_16比9")
 root.size=Vector2i(1000,750);await shot("15_战斗界面_4比3")
 var t: float=game.atmosphere.hour
 var pos: Vector3=game.player.position
 game.movement=Vector2.RIGHT;await frames(25);game.movement=Vector2.ZERO
 record("world_and_clock_frozen",{"position":game.player.position==pos,"clock":is_equal_approx(t,game.atmosphere.hour)})
 s._on_skill_menu();await frames(3)
 record("default_skill_focus",str(root.gui_get_focus_owner().text) if root.gui_get_focus_owner() is Button else "none")
 await shot("16_技能选择")
 await key(KEY_ENTER);await finish_playback(s)
 record("focus_after_skill",str(root.gui_get_focus_owner().text) if root.gui_get_focus_owner() is Button else "none")
 if s.mode=="skill":s._back_to_command()
 if s.mode=="busy":await finish_playback(s)
 var contained := true
 for gauge in s.dash.gauges:
  contained = contained and gauge.fill.size.x <= gauge.back.size.x - 8.0 + .01
 record("resized_gauges", contained)
 var checkpoint: Dictionary = s.engine.checkpoint()
 var rng_before: int = s.engine.rng.state
 load("res://battle/battle_guide.gd").skill(s.engine, "wave_touch", s.engine.foes[0])
 record("guide_rng_unchanged", rng_before == s.engine.rng.state)
 var action := {"kind":"attack", "target":0}
 var first: Dictionary = s.engine.submit(action)
 s.engine.restore_checkpoint(checkpoint)
 var second: Dictionary = s.engine.submit(action)
 record("checkpoint_replay", first == second)
 s.engine.restore_checkpoint(checkpoint)
 # Isolated failure probe: item persistence must be atomic with its battle effect.
 if s.mode=="command":
  s.engine.allies[0].hp=10.0
  s.engine.foes[0].hp=1000.0;s.engine.foes[0].max_hp=1000.0
  s._refresh_all();s._on_item_menu();await shot("17_战斗道具")
  s._back_to_command()
  var old_hp: float=s.engine.allies[0].hp
  var old_round: int=s.engine.round_no
  var old_count: int=game.loot.inventory.first_aid
  var valid_path: String=game.loot.save_path
  game.loot.save_path="user://review_nonexistent_dir_20261003/no_save.json"
  s._submit_action({"kind":"item","id":"first_aid","label":"急救包","effects":{"health":35.0}})
  await finish_playback(s)
  record("failed_item_save",{"hp_before":old_hp,"hp_after":s.engine.allies[0].hp,"count_before":old_count,"count_after":game.loot.inventory.first_aid,"round_before":old_round,"round_after":s.engine.round_no})
  game.loot.save_path=valid_path
  s._submit_action({"kind":"item","id":"first_aid","label":"急救包","effects":{"health":35.0}})
  await finish_playback(s)
  var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(valid_path))
  record("persisted_item_vitals", int(saved.inventory.first_aid) == old_count-1 and game.loot.inventory.first_aid == old_count-1 and is_equal_approx(float(saved.character.vitals.health), float(s.engine.allies[0].hp)) and is_equal_approx(game.character_controller.model.value("health"), float(s.engine.allies[0].hp)))
 # Real keyboard events: hidden world interfaces must not react during battle.
 await key(KEY_Q)
 record("Q_during_battle_opens_dialogue",game.dialogue_controller.active)
 game.dialogue_controller.close()
 await key(KEY_I)
 record("I_during_battle_opens_bag",game.loot.blocked())
 game.loot.close()
 await key(KEY_M)
 record("M_during_battle_opens_map",game.map_panel.visible)
 game._show_map(false)
 await key(KEY_B)
 record("B_during_battle_enables_edit",game.editing)
 game.editing=false
 await key(KEY_TAB)
 record("Tab_during_battle_opens_catalog",game.panel.visible)
 game.panel.hide()
 await key(KEY_ESCAPE)
 record("Escape_during_battle_opens_pause",game.pause_menu.active)
 game.pause_menu.close()
 s.engine.foes[0].hp=1.0
 if s.mode in ["skill","item"]:s._back_to_command()
 if s.mode=="busy":await finish_playback(s)
 s._on_attack();await finish_playback(s);await frames(20)
 await shot("18_胜利结算")
 var reward_before: Dictionary = game.loot.inventory.duplicate(true)
 var xp_before: Dictionary = game.character_controller.model.snapshot()
 combat.result_summary("win", s.engine)
 record("reward_provider_idempotent", reward_before == game.loot.inventory and xp_before == game.character_controller.model.snapshot())
 s.context.pending_result = "lose"
 s._play_result()
 await frames(24)
 record("defeat_has_no_trophy", not s.result_banner.visible)
 s.context.pending_result = "win"
 s._play_result()
 await frames(24)
 s._on_continue();await frames(10)
 record("battle_return_and_rewards",{"battle_closed":not combat.in_battle(),"defeated":game.character_controller.model.state.combat.defeated,"location":game.location_id})
 # Recheck a suspected stale 4/5 completion gate using an isolated model.
 var flags=game.character_controller.model.state.combat.defeated
 flags.clear()
 for id in ["slime_a","slime_b","crab_a","gpt6_a"]:flags[id]=true
 record("practice_gate_before_boss",combat.start_practice())
 var model=load("res://character/life_state.gd").new()
 var before_stats: Dictionary=model.state.base.duplicate()
 var attack_before: int=model.attack()
 model.gain_xp(4000)
 record("actual_level_growth",{"level":model.state.level,"before":before_stats,"after":model.state.base,"attack_before":attack_before,"attack_after":model.attack(),"defense":model.defense()})
 var sim=load("res://tools/test_battle.gd").new().run(500)
 record("battle_engine_500",sim)
 record("engine",Engine.get_version_info())
 record("isolated_paths",{"inventory":game.loot.save_path,"world":prefs.world_save_path,"dialogue":game.dialogue_controller.save_path,"settings":prefs.settings_path})
 var file:=FileAccess.open(OUT+"实测记录.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(results,"  "))
 print("REVIEW COMPLETE")
 quit(0 if failures == 0 else 1)
