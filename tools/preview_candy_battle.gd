extends SceneTree
## Real rendering and pointer input. Requires isolated autoload paths.
const OUTPUT="res://预览/糖果UI全局改造_20261011/"
var checks:=0
var failures:=0
var screen
var engine
var evidence:Array=[]

func _initialize()->void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
 DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(ok:bool,note:String)->void:
 checks+=1;evidence.append({"ok":ok,"check":note})
 if ok:print("PASS ",note)
 else:failures+=1;push_error(note)

func settle(frames:int=8)->void:
 for i in frames:await process_frame

func shot(name:String)->void:
 await settle();RenderingServer.force_draw(false)
 check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+name+".png"))==OK,"screenshot "+name)

func click(control:Control)->void:
 await settle(3)
 var point:=control.get_global_rect().get_center()
 var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.position=point;press.pressed=true;root.push_input(press,true);await process_frame
 var release:=press.duplicate();release.pressed=false;root.push_input(release,true);await settle(3)

func open_battle(multiple:bool=false)->void:
 engine=load("res://battle/battle_engine.gd").new(20261011)
 engine.add_ally({"id":"player","name":"大肥鱼","level":13,"hp":69,"max_hp":148,"stamina":198,"max_stamina":198,"atk":16,"def":7,"spd":9,"ap":100})
 engine.add_foe({"id":"gpt6","kind":"gpt6","name":"gpt6","hp":65,"max_hp":65,"atk":5,"def":1,"spd":1})
 if multiple:
  for id in ["left","right"]:engine.add_foe({"id":id,"kind":"slime","name":"海沫团","hp":1000,"max_hp":1000,"atk":3,"def":1,"spd":1})
 engine.enable_cards(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json")))
 screen=load("res://battle/battle_screen.gd").new();root.add_child(screen)
 screen.open(engine,{"title":"潮汐遭遇战","textures":{"gpt6":"res://assets/monsters/gpt6.png","slime":"res://assets/monsters/sea_slime.png"},"items":[{"id":"preview_heal","name":"测试补给","count":1,"description":"仅用于界面检查","effects":{"heal":10},"usable":true}]})
 await create_timer(.65).timeout
 screen.skip_playback()
 # Read the current deck instead of depending on historical card IDs.
 var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
 engine.hand.clear()
 for card in catalog.slice(0,5):engine.hand.append(str(card.id))
 engine.card_energy=3;screen.mode="command";screen._refresh_all();await settle()

func layout_checks(tag:String)->void:
 check(screen.card_panel.position.y+screen.card_panel.size.y+20<=screen.dash.dock.position.y,tag+" tray clear of status dock")
 check(screen.log_box.position.y+screen.log_box.size.y+20<=screen.card_panel.position.y,tag+" log clear of tray")
 check(screen.card_row.get_child_count()==5,tag+" five cards visible")
 for face in screen.card_row.get_children():check(face.size.y+screen.card_scroll.get_h_scroll_bar().size.y<=screen.card_scroll.size.y,tag+" full card fits")
 var buttons:Array=[screen.card_item_button,screen.card_link_button,screen.card_panel.get_node("CardTargetButton"),screen.card_end_button]
 for a in buttons:
  check(a.get_rect().end.x<=screen.card_panel.size.x-10,tag+" action fits")
  for b in buttons:
   if a!=b:check(not a.get_rect().intersection(b.get_rect()).has_area(),tag+" actions distinct")
 check(screen.dash.block_badge.panel.get_rect().end.x+12<=screen.dash.gauges[0].group.position.x,tag+" block clear of gauge")

func run()->void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():push_error("Required isolation flags");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 root.get_node("HarborPrefs").values.fullscreen=false
 root.size=Vector2i(1000,750)
 await open_battle();layout_checks("4:3")
 screen.card_preview.hide();await shot("21_战斗_4比3")
 await click(screen.card_item_button)
 check(screen.mode=="item" and screen.skill_box.visible,"pointer opens supply list")
 await shot("27_战斗_补给")
 await click(screen.submenu_back)
 check(screen.mode=="command" and screen.card_panel.visible,"pointer returns from supply list")
 var rng_state:int=engine.rng.state
 await click(screen.speed_button)
 check(screen.speed_index==1,"pointer changes animation speed")
 check(engine.rng.state==rng_state,"UI speed action leaves gameplay RNG untouched")
 var face:Control=screen.card_row.get_child(0)
 var motion:=InputEventMouseMotion.new();motion.position=face.get_global_rect().get_center();root.push_input(motion,true);await settle()
 check(screen.card_preview.visible,"pointer opens full card preview");await shot("22_战斗_卡牌说明")
 var hand_before:int=engine.hand.size()
 await click(face)
 check(engine.hand.size()==hand_before-1,"pointer plays a hand card")
 screen.skip_playback();await settle()
 check(screen.mode=="command" and not screen.card_end_button.disabled,"skip restores active action bar")
 var round_before:int=engine.round_no
 await click(screen.card_end_button)
 print("END TURN STATE: ",round_before," -> ",engine.round_no," mode=",screen.mode," disabled=",screen.card_end_button.disabled)
 check(engine.round_no>round_before,"pointer advances turn")
 screen.skip_playback();screen.close();screen.queue_free();await settle()
 await open_battle(true)
 await click(screen.slots[2].hit)
 check(screen.context.target==2,"pointer selects third enemy by slot")
 await shot("23_战斗_多目标")
 for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,600)]:
  root.size=dimensions;await settle(16);screen.card_preview.hide()
  layout_checks(str(dimensions));await shot("24_战斗_%dx%d" % [dimensions.x,dimensions.y])
 engine.allies[0].block=12345;screen._refresh_all();await settle()
 check(screen.dash.block_badge.value.text=="12345","five digit block remains readable")
 check(screen.dash.block_badge.panel.get_rect().end.x+12<=screen.dash.gauges[0].group.position.x,"large block remains clear of gauge")
 await shot("25_战斗_高格挡")
 for foe in engine.foes:foe.hp=0;foe.alive=false
 engine.foes[0].hp=1;engine.foes[0].alive=true
 var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
 for card in catalog:
  if str(card.effects[0].kind)=="damage":engine.hand.assign([str(card.id)]);break
 engine.card_energy=3;screen.context.target=0;screen._refresh_all();await settle()
 await click(screen.card_row.get_child(0));screen.skip_playback();await settle()
 check(screen.mode=="result" and screen.result_box.visible,"accepted card displays victory summary")
 await create_timer(.5).timeout
 await shot("26_战斗_胜利")
 await click(screen.result_go)
 check(not is_instance_valid(screen) or not screen.is_active(),"pointer leaves victory summary")
 if is_instance_valid(screen):screen.queue_free()
 await settle()
 var output:=FileAccess.open(OUTPUT+"battle_review.json",FileAccess.WRITE)
 output.store_string(JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}," "));output.close()
 print("CANDY_BATTLE_REVIEW: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
