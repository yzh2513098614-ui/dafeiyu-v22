extends SceneTree
## 音乐设置界面检查：存档分组与旧档兼容、MusicDirector 公开接口、主菜单音频控件、热键隔离、游戏内画面/声音标签页。
## 运行：godot --headless --path . --script res://tools/test_audio_ui.gd -- --test-audio-ui
var prefs
var music
var checks:=0
var failures:=0
const OUT="res://预览/音乐设置_v22/"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)
func frames(count: int=4) -> void:
 for i in count:await process_frame
func shot(filename: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await frames(5);RenderingServer.force_draw()
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+filename))
func write_cfg(path: String,sections: Dictionary) -> void:
 var cfg:=ConfigFile.new()
 for section in sections:
  for key in sections[section]:cfg.set_value(section,key,sections[section][key])
 cfg.save(path)
func find_button(parent: Node,text: String) -> Button:
 for child in parent.get_children():
  if child is Button and child.text==text:return child
 return null
func run() -> void:
 if not "--test-audio-ui" in OS.get_cmdline_user_args():quit(2);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 prefs=root.get_node("HarborPrefs")
 music=root.get_node("MusicDirector")
 check(prefs.settings_path=="res://_audio_ui_test.cfg","audio checks use an isolated settings file")

 # ---------- 1. 旧档兼容：music 只写在 [display]（加音乐设置之前的格式） ----------
 write_cfg(prefs.settings_path,{"display":{"music":false,"shadows":false},"audio":{"music_volume":0.3,"music_style":"harbor"}})
 var legacy=load("res://ui/harbor_prefs.gd").new()
 root.add_child(legacy)
 check(legacy.values["music"]==false,"legacy [display] music=false is honoured")
 check(legacy.values["shadows"]==false,"legacy display flags still load")
 check(is_equal_approx(legacy.music_volume,0.3),"legacy [audio] volume still loads")
 check(legacy.music_style=="harbor","legacy [audio] style still loads")
 legacy.free()

 # ---------- 2. 新格式：音频项统一写进 [audio] ----------
 prefs.values["music"]=false;prefs.music_volume=0.75;prefs.music_style="harbor"
 check(prefs.save()==OK,"settings save succeeds")
 var saved:=ConfigFile.new()
 check(saved.load(prefs.settings_path)==OK,"saved settings file reloads")
 check(saved.get_value("display","music","__absent__")=="__absent__","music flag no longer written to [display]")
 check(saved.get_value("audio","music","__absent__")==false,"music flag written to [audio]")
 check(is_equal_approx(float(saved.get_value("audio","music_volume",0.0)),0.75),"volume written to [audio]")
 check(str(saved.get_value("audio","music_style",""))=="harbor","style written to [audio]")
 check(saved.get_value("display","shadows","__absent__")!="__absent__","display flags still written to [display]")

 # ---------- 3. 往返：新格式能被自己读回 ----------
 var reloaded=load("res://ui/harbor_prefs.gd").new()
 root.add_child(reloaded)
 check(reloaded.values["music"]==false,"saved music=false survives a reload")
 check(is_equal_approx(reloaded.music_volume,0.75),"saved volume survives a reload")
 check(reloaded.music_style=="harbor","saved style survives a reload")
 reloaded.free()

 # ---------- 4. MusicDirector 公开接口 ----------
 music.set_volume(0.4)
 check(is_equal_approx(music.music_volume(),0.4),"set_volume writes through to prefs")
 music.set_enabled(false)
 check(not music.music_enabled(),"set_enabled(false) writes through to prefs")
 music.set_enabled(true)
 check(music.music_enabled(),"set_enabled(true) restores music")
 check(music.style_keys().size()==2,"both style sets are exposed")
 var style_home: String=music.style_key()
 music.set_style("harbor")
 check(music.style_key()=="harbor","set_style switches the style set")
 music.set_style(style_home)
 check(music.style_key()==style_home,"set_style switches back")
 check(music.style_display_name("galgame")!="","style_display_name returns a readable label")
 var catalog: Array=music.catalog()
 check(catalog.size()>0 and catalog[0].has("id") and catalog[0].has("name") and catalog[0].has("use"),"catalog still exposes id/name/use for the gallery")

 # ---------- 5. 主菜单「音乐鉴赏」页的真控件 ----------
 prefs.values["music"]=true;prefs.music_volume=0.65;prefs.music_style="galgame";prefs.save()
 var menu=load("res://ui/start_menu.tscn").instantiate()
 root.add_child(menu)
 await frames(6)
 menu._show_page("music")
 await frames(6)
 check(is_instance_valid(menu.music_volume_slider),"gallery builds a real volume slider")
 check(is_instance_valid(menu.music_mute_button),"gallery builds a mute button")
 check(menu.music_volume_slider.value==65.0,"slider reflects the saved volume")
 check(menu.music_volume_value.text=="65%","volume label shows the saved percentage")
 check(menu.music_mute_button.text.contains("开启"),"mute button shows the current state")
 check(not menu.gallery_hint.text.contains("已静音"),"hint does not claim to be muted while music is on")
 menu.music_volume_slider.value=30
 await frames(4)
 check(is_equal_approx(music.music_volume(),0.3),"dragging the slider changes the live volume")
 check(menu.music_volume_value.text=="30%","volume label follows the slider")
 var persisted:=ConfigFile.new();persisted.load(prefs.settings_path)
 check(is_equal_approx(float(persisted.get_value("audio","music_volume",0.0)),0.3),"slider volume is persisted immediately")
 menu.music_mute_button.pressed.emit()
 await frames(4)
 check(not music.music_enabled(),"mute button turns the music off")
 check(menu.music_volume_slider.editable==false,"slider greys out while muted")
 check(menu.music_mute_button.text.contains("静音"),"mute button flips to the muted label")
 check(menu.gallery_hint.text.contains("已静音"),"hint explains how to unmute")
 menu.music_mute_button.pressed.emit()
 await frames(4)
 check(music.music_enabled(),"mute button turns the music back on")
 check(menu.music_volume_slider.editable,"slider becomes editable again when unmuted")
 var style_button: Button=find_button(menu.content,"切换风格")
 check(style_button!=null,"gallery has a style switch button")
 var style_before: String=music.style_key()
 if style_button:
  style_button.pressed.emit()
  await frames(4)
  check(music.style_key()!=style_before,"style switch button cycles the style set")
 # 点曲子会自动解除静音（原有行为要保持）
 music.set_enabled(false)
 await frames(2)
 if menu.gallery_rows.size()>0:
  var target: String=str(menu.gallery_rows[0].id)
  menu.gallery_rows[0].card.pressed.emit()
  await frames(4)
  check(music.music_enabled(),"clicking a track lifts the mute")
  check(music.gallery_track()==target,"clicking a track selects it")
 await shot("01_菜单音乐设置.png")

 # ---------- 6. 热键隔离：文本输入态不该改音量 ----------
 var field:=LineEdit.new();field.position=Vector2(20,700);field.size=Vector2(200,40)
 menu.content.add_child(field);field.grab_focus()
 await frames(4)
 var volume_before: float=music.music_volume()
 var press:=InputEventKey.new();press.keycode=KEY_BRACKETRIGHT;press.physical_keycode=KEY_BRACKETRIGHT;press.pressed=true
 root.push_input(press)
 await frames(4)
 check(is_equal_approx(music.music_volume(),volume_before),"[ is ignored while a text field has focus")
 field.release_focus()
 await frames(4)
 root.push_input(press)
 await frames(4)
 check(music.music_volume()>volume_before,"[ changes the volume when nothing is being typed")
 field.free()
 menu.free()
 music.exit_gallery()

 # ---------- 7. 游戏内设置的「画面 / 声音」标签页 ----------
 var game=load("res://district/continuous_world.tscn").instantiate()
 root.add_child(game);current_scene=game
 await frames(12)
 if game.has_method("set_physics_process"):game.set_physics_process(false)
 if game.dialogue_controller:game.dialogue_controller.close()
 game._settings(true)
 await frames(6)
 var view=game.settings_view
 check(view.tab_buttons.has("display") and view.tab_buttons.has("audio"),"in-game settings expose 画面/声音 tabs")
 check(view.audio_cards.size()==3,"audio tab has three cards")
 check(view.display_cards.size()==8,"display tab keeps its eight cards")
 check(view.audio_cards[0].visible==false,"audio cards start hidden on the 画面 tab")
 check(view.display_cards[0].visible,"display cards start visible")
 view._set_tab("audio")
 await frames(4)
 check(view.audio_cards[0].visible and not view.display_cards[0].visible,"switching to 声音 hides the display cards")
 check(view.volume_slider.value==roundi(music.music_volume()*100.0),"in-game slider reflects the live volume")
 var enabled_before: bool=music.music_enabled()
 view.music_switch.pressed.emit()
 await frames(4)
 check(music.music_enabled()!=enabled_before,"in-game music switch toggles the live state")
 view.music_switch.pressed.emit()
 await frames(4)
 check(music.music_enabled()==enabled_before,"in-game music switch toggles back")
 view.volume_slider.value=80
 await frames(4)
 check(is_equal_approx(music.music_volume(),0.8),"in-game slider changes the live volume")
 var style_before_2: String=music.style_key()
 view.style_picker.select(1 if style_before_2=="galgame" else 0)
 view.style_picker.item_selected.emit(view.style_picker.selected)
 await frames(4)
 check(music.style_key()!=style_before_2,"in-game style picker switches the style set")
 await shot("02_游戏内声音设置.png")
 view._set_tab("display")
 await frames(4)
 check(view.display_cards[0].visible and not view.audio_cards[0].visible,"switching back to 画面 restores the display cards")
 await shot("03_游戏内画面设置.png")
 game._settings(false)

 # 清掉工程内的临时存档，别把测试残留留在项目里
 for leftover in [prefs.settings_path,prefs.world_save_path]:
  if FileAccess.file_exists(leftover):DirAccess.remove_absolute(ProjectSettings.globalize_path(leftover))

 print("AUDIO UI CHECKS ",checks," PASSED ",checks-failures," FAILED ",failures)
 quit(0 if failures==0 else 1)
