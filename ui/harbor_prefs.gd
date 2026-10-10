extends Node
const SETTINGS_PATH := "user://harbor_settings_v18.cfg"
var settings_path := SETTINGS_PATH
var world_save_path := "user://whale_continuous_v19.json"
var starting_place := "city"
var continue_game := false
var values := {"fullscreen":false,"shadows":true,"effects":true,"dusk":false,"follow":true,"smooth_camera":true,"day_cycle":true,"music":true,"sfx":true,"ambience":false}
## 归 [audio] 段的开关（不写在 [display] 里）。以后再加音频开关只要加进这个数组。
const AUDIO_SWITCHES: Array = ["music","sfx","ambience"]
var day_minutes:=12.0
var music_volume:=0.65
var music_style:="galgame"
var sfx_volume:=0.80
var ambience_volume:=0.55
var favorites: Dictionary = {}

func _ready() -> void:
 if "--test-expedition" in OS.get_cmdline_user_args():
  settings_path="res://预览/expedition_settings_test.cfg";world_save_path="res://预览/expedition_world_test.json"
 elif "--test-merge" in OS.get_cmdline_user_args():
  settings_path="user://harbor_merge_test.cfg";world_save_path="user://whale_merge_test.json"
 elif "--test-session-ui" in OS.get_cmdline_user_args():
  settings_path="user://harbor_session_ui_test.cfg";world_save_path="user://whale_session_ui_test.json"
 elif "--test-life-ui" in OS.get_cmdline_user_args():
  settings_path="user://harbor_life_ui_test.cfg";world_save_path="user://whale_life_ui_test.json"
 elif "--test-combat-ui" in OS.get_cmdline_user_args():
  settings_path="user://harbor_combat_ui_test.cfg";world_save_path="user://whale_combat_ui_test.json"
 elif "--test-audio-ui" in OS.get_cmdline_user_args():
  # 音频界面检查用工程内的临时文件，而不是 user://：
  # 无 GUI / 受限沙箱下 Godot 可能写不了 user://，而 res://（从工程目录运行时）始终可写。
  settings_path="res://_audio_ui_test.cfg";world_save_path="res://_audio_ui_test_world.json"
 var cfg:=ConfigFile.new()
 if cfg.load(settings_path)==OK:
  for key in values:
   # 音频开关都归 [audio]，不在 [display] 里读
   if not AUDIO_SWITCHES.has(key):values[key]=bool(cfg.get_value("display",key,values[key]))
  # 音频开关归 [audio]；旧档把它写在 [display]，两级回退保证老存档不丢设置。
  values["music"]=bool(cfg.get_value("audio","music",cfg.get_value("display","music",true)))
  values["sfx"]=bool(cfg.get_value("audio","sfx",true))
  # 环境音默认关闭：它是实验性的音景层，不该在不打招呼的情况下铺满整个游戏。
  # 想要的人自己去 设置 → 声音 打开。
  values["ambience"]=bool(cfg.get_value("audio","ambience",false))
  starting_place=str(cfg.get_value("journey","place","city"))
  day_minutes=clampf(float(cfg.get_value("time","day_minutes",12.0)),6.0,24.0)
  music_volume=clampf(float(cfg.get_value("audio","music_volume",0.65)),0.0,1.0)
  music_style=str(cfg.get_value("audio","music_style","galgame"))
  sfx_volume=clampf(float(cfg.get_value("audio","sfx_volume",0.80)),0.0,1.0)
  ambience_volume=clampf(float(cfg.get_value("audio","ambience_volume",0.55)),0.0,1.0)
 apply_window()

func save() -> Error:
 var cfg:=ConfigFile.new()
 for key in values:
  if not AUDIO_SWITCHES.has(key):cfg.set_value("display",key,values[key])
 cfg.set_value("journey","place",starting_place)
 cfg.set_value("time","day_minutes",day_minutes)
 cfg.set_value("audio","music",values["music"])
 cfg.set_value("audio","music_volume",music_volume)
 cfg.set_value("audio","music_style",music_style)
 cfg.set_value("audio","sfx",values["sfx"])
 cfg.set_value("audio","sfx_volume",sfx_volume)
 cfg.set_value("audio","ambience",values["ambience"])
 cfg.set_value("audio","ambience_volume",ambience_volume)
 return cfg.save(settings_path)

func apply_window() -> void:
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func apply_game(game: Node,preserve_camera: bool=false) -> void:
 apply_window()
 game.get_node("Sun").shadow_enabled=values.shadows
 game.atmosphere.set_effects(values.effects)
 game.atmosphere.day_minutes=day_minutes
 game.atmosphere.set_cycle_enabled(values.day_cycle)
 if not values.day_cycle:game.atmosphere.set_dusk(values.dusk)
 if not preserve_camera:
  game.overview_mode=not values.follow
  game.view_size=game.overview_size if game.overview_mode else (24.0 if game.location_id=="city" else 22.0)
 game._update_view_button()
