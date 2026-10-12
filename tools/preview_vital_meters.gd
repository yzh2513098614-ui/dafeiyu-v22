extends SceneTree
## Run with --test-session-ui --test-dialogue; all player saves remain isolated.
const OUTPUT="res://预览/vital_meters_20261012/"
var checks:=0
var failures:=0
var game

func _initialize() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
 DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)

func settle(frames: int=12) -> void:
 for i in frames:await process_frame

func shot(filename: String) -> void:
 await settle()
 RenderingServer.force_draw(false)
 check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename+".png"))==OK,"screenshot "+filename)

func click(button: Control) -> void:
 await settle(2)
 var point:=button.get_global_rect().get_center()
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 var released: InputEventMouseButton=event.duplicate();released.pressed=false;root.push_input(released,true)
 await settle(3)

func run() -> void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():
  push_error("Required isolation flags: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.music=false;prefs.values.sfx=false
 prefs.starting_place="apt_2";prefs.continue_game=false
 prefs.settings_path=OUTPUT+"isolated_settings.cfg";prefs.world_save_path=OUTPUT+"isolated_world.json"
 root.size=Vector2i(1000,750)
 var world=load("res://district/continuous_world.tscn").instantiate();root.add_child(world);current_scene=world;game=world
 await settle(35)
 game.atmosphere.set_time(12.0)
 var c=game.character_controller
 c.set_process(false)
 var saved=c.model.snapshot()
 c.model.state.vitals.health=c.model.maximum("health")*.82
 c.model.state.vitals.stamina=c.model.maximum("stamina")*.65
 c.model.state.vitals.hunger=0.0;c.model.state.vitals.mood=100.0;c.refresh();c.hud.show()
 check(not c.hud.get_global_rect().intersects(game.expedition_controller.entry.get_global_rect()),"research entry clears HUD")
 check(not c.hud.get_global_rect().intersects(game.combat_controller.entry_button.get_global_rect()),"trial entry clears HUD")
 check(not game.combat_controller.entry_button.get_global_rect().intersects(game.expedition_controller.entry.get_global_rect()),"world entries do not overlap")
 await shot("01_hud")
 c.refresh()
 for vital in ["health","stamina","hunger","mood"]:
  check(abs(c.meters["hud_"+vital].fill.value-c.model.value(vital))<.011,"live value "+vital)
 check(c.meters.hud_hunger.text.text.ends_with("!"),"empty hunger warning")
 var button: Button=null
 for child in c.hud.get_children():
  if child is Button:button=child;break
 await click(button);check(c.active,"pointer opens character status")
 await shot("02_status")
 c.close();check(not c.active,"status closes")
 for vital in ["health","stamina","hunger","mood"]:c.model.state.vitals[vital]=0.0
 c.refresh();await shot("03_empty")
 for vital in ["health","stamina","hunger","mood"]:c.model.state.vitals[vital]=c.model.maximum(vital)
 c.refresh();root.size=Vector2i(1280,720);await shot("04_widescreen")
 check(c.hud.get_global_rect().end.y<1086,"HUD fits widescreen")
 c.model.restore(saved);c.refresh()
 print("VITAL_METERS_REVIEW: ",checks," checks, ",failures," failures")
 game.queue_free();await settle(5);quit(0 if failures==0 else 1)
