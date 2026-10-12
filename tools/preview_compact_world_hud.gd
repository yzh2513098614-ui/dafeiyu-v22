extends SceneTree
## Actual GPU preview; uses isolated preferences and player data.
const OUTPUT="res://预览/compact_world_hud_20261012/"
var checks:=0
var failures:=0
var game

func _initialize() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)

func settle(frames: int=12) -> void:
 for i in frames:await process_frame

func shot(filename: String) -> void:
 await settle();RenderingServer.force_draw(false)
 check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename+".png"))==OK,"screenshot "+filename)

func click(button: Control) -> void:
 var point:=button.get_global_rect().get_center()
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 var released: InputEventMouseButton=event.duplicate();released.pressed=false;root.push_input(released,true)
 await settle(3)

func layout_check() -> void:
 var c=game.character_controller
 check(not game.breadcrumb.visible and not game.arrival_note.visible,"legacy strips hidden at "+game.location_id)
 check(not game.zone_label.get_global_rect().intersects(c.hud.get_global_rect()),"location clears vitals")
 check(not c.hud.get_global_rect().intersects(game.combat_controller.entry_button.get_global_rect()) and not c.hud.get_global_rect().intersects(game.expedition_controller.entry.get_global_rect()),"world actions clear vitals")
 check(game.zone_label.size.x==c.hud.size.x and game.zone_label.position.x==c.hud.position.x,"cards share width and left edge")
 check(c.meters.hud_health.fill.size.y<=14.1 and c.meters.hud_hunger.fill.size.y<=11.1,"meter heights leave space for captions")

func run() -> void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():push_error("Isolation flags required");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.music=false;prefs.values.sfx=false
 prefs.starting_place="wuming_campus";prefs.continue_game=false
 prefs.settings_path=OUTPUT+"isolated_settings.cfg";prefs.world_save_path=OUTPUT+"isolated_world.json"
 root.size=Vector2i(1000,750)
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await settle(40)
 game.atmosphere.set_time(12.0)
 var c=game.character_controller
 c.model.state.vitals.hunger=0.0;c.refresh()
 layout_check()
 check(c.meters.hud_hunger.text.text.ends_with("!"),"zero hunger warning retained")
 for vital in ["health","stamina","hunger","mood"]:check(abs(c.meters["hud_"+vital].fill.value-c.model.value(vital))<.1,"live meter "+vital)
 await shot("01_campus")
 var button: Button=null
 for child in c.hud.get_children():
  if child is Button:button=child;break
 await click(button);check(c.active,"pointer opens character status")
 await shot("02_status")
 var event:=InputEventKey.new();event.physical_keycode=KEY_ESCAPE;event.pressed=true;root.push_input(event,true);await settle(3)
 event=InputEventKey.new();event.physical_keycode=KEY_ESCAPE;event.pressed=false;root.push_input(event,true)
 check(not c.active and c.free_world(),"Escape closes status and restores world")
 root.size=Vector2i(1280,720);await settle();layout_check();await shot("03_campus_wide")
 root.size=Vector2i(900,750);await settle();layout_check();await shot("04_campus_narrow")
 await game._travel("apt_2");await settle(20);layout_check();await shot("05_apartment")
 print("COMPACT_WORLD_HUD: ",checks," checks, ",failures," failures")
 game.queue_free();await settle(5);quit(0 if failures==0 else 1)
