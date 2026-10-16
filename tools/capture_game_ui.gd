extends SceneTree
const OUTPUT="res://预览/界面完善_v19/"
var game
var prefs
var saved_values: Dictionary
var saved_place: String
var settings_bytes: PackedByteArray
var had_settings: bool
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error(message)
func run() -> void:
 prefs=root.get_node("HarborPrefs");saved_values=prefs.values.duplicate();saved_place=prefs.starting_place
 had_settings=FileAccess.file_exists(prefs.SETTINGS_PATH)
 if had_settings:settings_bytes=FileAccess.get_file_as_bytes(prefs.SETTINGS_PATH)
 prefs.values.fullscreen=false;prefs.starting_place="apt_2";prefs.continue_game=false;prefs.apply_window();root.size=Vector2i(1000,750)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 for i in 12:await process_frame
 game.dialogue_controller.state.bookmark={};game.dialogue_controller.close()
 await shot("01_探索界面.png")
 check(game.dialogue_controller.hud_button.get_global_rect().intersection(game.destination_hint.get_global_rect()).has_area()==false,"conversation and doorway prompts do not overlap")
 check(game.loot.bag_button.get_global_rect().intersection(game.dialogue_controller.hud_button.get_global_rect()).has_area()==false,"backpack and conversation buttons have separate positions")
 game._show_map(true)
 await shot("02_生活导览.png")
 var guide=game.map_panel.get_child(0)
 guide.tabs.floor2.pressed.emit();await process_frame
 check(guide.grid.get_child_count()==3,"floor navigation shows three buildings")
 guide.search.text="公寓";guide.search.text_changed.emit(guide.search.text)
 await process_frame
 check(guide.grid.get_child_count()==3,"search finds all three apartment floors")
 guide.tabs.favorites.pressed.emit();guide.search.text="";guide.search.text_changed.emit(guide.search.text);await process_frame
 await shot("03_导航收藏.png")
 guide.tabs.floor2.pressed.emit();await process_frame
 guide.grid.get_child(1).get_child(5).pressed.emit()
 await process_frame
 check(not game.map_panel.visible and game.route_steps.size()>1,"guide route button marks a real connected route")
 await shot("04_路线提示.png")
 game.set_route("")
 game._settings(true)
 var was_overview: bool=game.overview_mode
 root.gui_release_focus();await key(KEY_Z)
 check(game.overview_mode==was_overview,"settings modal blocks world camera shortcuts")
 await key(KEY_B)
 check(not game.editing and not game.panel.visible,"settings modal blocks decoration shortcuts")
 var old_effects: bool=prefs.values.effects
 game.settings_view.switches.effects.pressed.emit();await process_frame
 check(prefs.values.effects!=old_effects and game.atmosphere.effects==prefs.values.effects,"in-game settings switch updates the actual atmosphere")
 check(FileAccess.file_exists(prefs.SETTINGS_PATH),"in-game settings are saved")
 await shot("05_游戏设置.png")
 game._settings(false)
 var loot=game.loot
 for id in loot.definitions:loot.inventory[id]=2
 loot._bag_count();loot.open_bag();await process_frame
 await shot("06_随身背包.png")
 var bag=loot.modal.get_child(0)
 var id: String=str(bag.visible_ids[0])
 loot.rows[id].pressed.emit();await process_frame
 check(loot.chosen==id and loot.selected_button!=null,"clicking a bag item safely rebuilds its details")
 bag=loot.modal.get_child(0)
 var favorite_button=bag.details.get_children().filter(func(child):return child is Button and child!=loot.selected_button)[0]
 favorite_button.pressed.emit();await process_frame
 check(loot.bag_favorites.has(id),"favorite click updates and saves the item")
 bag.tabs.favorite.pressed.emit();await process_frame
 check(bag.visible_ids.size()==1,"favorites filter shows the bookmarked item")
 bag.search.text="不存在的物品";bag.search.text_changed.emit(bag.search.text);await process_frame
 check(bag.visible_ids.is_empty(),"empty search displays an empty inventory state")
 await shot("07_背包空搜索.png")
 bag.search.text="";bag.search.text_changed.emit("");bag.search.grab_focus()
 for i in 4:await key(KEY_Z,122)
 check(bag.search.text=="zzzz" and bag.visible_ids.is_empty(),"actual keyboard typing updates backpack search")
 root.gui_release_focus()
 bag.search.text="";bag.search.text_changed.emit(bag.search.text);bag.tabs.all.pressed.emit();await process_frame
 loot.rows.snack_basket.pressed.emit();await process_frame
 var snacks: int=int(loot.inventory.snack_basket)
 game.character_controller.model.state.vitals.stamina=50.0
 loot.selected_button.pressed.emit();await process_frame
 check(int(loot.inventory.snack_basket)==snacks-1,"actual item action consumes exactly one item")
 check(loot.modal.get_child(0).action_feedback.text==loot.status,"item result appears inside the styled backpack")
 await shot("08_背包使用反馈.png")
 loot.close()
 game._toggle_decor();await shot("11_家居选择.png")
 check(game.panel.visible and not game.editing,"decoration entry opens the home catalog before placement")
 game._toggle_decor()
 var d=game.dialogue_controller
 d.state={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]}
 d.context={"room":str(game.title.text),"place":game.location_id,"object":"这里"}
 d.start("home");d.advance();d.advance();d.advance()
 await shot("09_立绘与选项.png")
 check(d.choice_buttons.size()>0,"dialogue choices remain available with original portraits")
 d.choice_buttons[0].pressed.emit();d.advance()
 d.show_backlog();await shot("10_对话回看.png");d.hide_backlog();d.close()
 restore()
 print("GAME UI CHECKS ",checks," PASSED ",checks-failures," FAILED ",failures)
 quit(0 if failures==0 else 1)
func restore() -> void:
 prefs.values=saved_values;prefs.starting_place=saved_place
 if had_settings:
  var file:=FileAccess.open(prefs.SETTINGS_PATH,FileAccess.WRITE);file.store_buffer(settings_bytes);file.close()
 else:DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.SETTINGS_PATH))
func key(code: Key,unicode: int=0) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.unicode=unicode;event.pressed=true;root.push_input(event)
 await process_frame
 var release:=event.duplicate();release.pressed=false;root.push_input(release)
 await process_frame
func shot(filename: String) -> void:
 for i in 6:await process_frame
 await create_timer(.25).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename))
