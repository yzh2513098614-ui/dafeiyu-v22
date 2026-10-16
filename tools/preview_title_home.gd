extends SceneTree
## Real title using isolated settings and save slots.
const OUT="res://预览/标题首页小幅调整_20261016/"

func _initialize()->void:
 AudioServer.set_bus_mute(0,true);call_deferred("open_title")

func open_title()->void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-candy-title" in OS.get_cmdline_user_args():push_error("Use isolated preview flags");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var prefs=root.get_node("HarborPrefs");prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json";prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false;prefs.apply_window()
 root.size=Vector2i(1280,720)
 var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 await process_frame;DisplayServer.window_set_title("大肥鱼 · 标题首页（原布局 · 静音预览）")
