extends SceneTree
## One-time source extraction. Existing user pages are never overwritten.
const Document=preload("res://ui/design/layout_document.gd")
var entries:Array=[]
var failures:=0
var game

func _initialize()->void:
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
  DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func settle(count:int=10)->void:
 for i in count:await process_frame

func capture(id:String,target:Control,title:String,excluded:Array=[])->void:
 if "--resume-export" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://ui/design/pages/"+id+".tscn") and not id=="expedition_battle":
  var old:Control=load("res://ui/design/pages/"+id+".tscn").instantiate()
  var old_nodes:Dictionary={};Document.collect(old,old_nodes)
  entries.append({"id":id,"title":title,"scene":"res://ui/design/pages/"+id+".tscn","controls":old_nodes.size(),"error":OK});old.free();print("RETAIN ",id);return
 var result:=Document.capture(id,target,title,excluded);entries.append(result)
 if result.error!=OK:failures+=1;push_error("Capture failed "+id)
 print("CAPTURE ",id," ",result.controls)

func make_theme()->void:
 var filename:="res://ui/design/game_ui_theme.tres"
 if FileAccess.file_exists(filename):return
 var Candy=load("res://ui/candy_skin.gd");var Skin=load("res://ui/handheld_skin.gd")
 var shared:=Theme.new()
 for key in ["shell","panel","dialogue","paper","detail","sky","bag","chest","mint","pink","quote","status","button","white","hover","pressed","primary","primary_hover","primary_pressed","disabled","selected","card","empty","nameplate","screen","dark","plate","hand_tray","focus","gauge_track","tag"]:
  var box:StyleBox=Candy.frame(key).duplicate();box.resource_name=key;shared.set_stylebox(key,"GameUI",box)
 for key in ["map","backpack","tasks","chat","shop","music","deck","settings","mail","gift","calendar","shell","mana","attack","shield","energy","heal"]:
  shared.set_icon(key,"GameIcons",load(Skin.icon_path(key)))
 for type in ["Label","RichTextLabel","Button","LineEdit","SpinBox","OptionButton"]:
  for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:shared.set_color(state,type,Candy.INK)
  shared.set_color("font_disabled_color",type,Candy.MUTED)
 shared.resource_name="大肥鱼 · 全局 UI 皮肤与图标"
 ResourceSaver.save(shared,filename)

func run()->void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args() or not "--test-expedition" in OS.get_cmdline_user_args():push_error("Required isolation flags");quit(1);return
 root.get_node("UiDesign").enabled=false
 AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://预览/可编辑UI_20261011"))
 var prefs=root.get_node("HarborPrefs");prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.day_cycle=false;prefs.starting_place="apt_2";prefs.continue_game=false
 prefs.settings_path="res://预览/可编辑UI_20261011/settings.cfg";prefs.world_save_path="res://预览/可编辑UI_20261011/world.json"
 root.size=Vector2i(1000,750)
 make_theme()
 var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu;await settle()
 for page in ["title","journey","harbor","pack26","music","settings"]:
  menu.page=page;menu._render();await settle();capture("title_"+page,menu,{"title":"标题菜单","journey":"出发选择","harbor":"东港出发选择","pack26":"新区出发选择","music":"音乐鉴赏","settings":"标题画面设置"}[page])
 menu.queue_free();await settle()
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await settle(30);game.set_physics_process(false)
 var excluded:Array=[game.panel,game.settings_panel,game.dialog]
 capture("world_hud",game.ui.get_child(0),"世界工具栏",excluded)
 capture("world_navigation",game.district_canvas,"地点与导览入口",[game.map_panel])
 var loot=game.loot
 capture("world_loot_prompt",loot.canvas,"背包入口与宝箱提示",[loot.modal_shade])
 game.map_interactions.card.show();capture("world_interaction",game.map_interactions.root,"附近互动提示");game.map_interactions.card.hide()
 loot.inventory={"snack_basket":5,"first_aid_kit":3,"pencil_cup":1,"heart_keychain":1,"heart_letter":1,"crystal_cluster":4,"tea_cup":2,"map_route":1};loot._bag_count()
 loot.open_bag();await settle();capture("inventory_bag",loot.modal,"随身背包");loot.close()
 loot.current_chest=loot.chests[0];loot.mode="loot";loot._render();await settle();capture("inventory_chest",loot.modal,"发现宝箱")
 loot.mode="note";loot._render();await settle();capture("inventory_note",loot.modal,"漂流便签");loot.close()
 game._settings(true)
 for tab in ["display","audio","audition"]:
  game.settings_view._set_tab(tab);await settle();capture("settings_"+tab,game.settings_panel,{"display":"画面设置","audio":"声音设置","audition":"音效试听"}[tab])
 game._settings(false)
 game.pause_menu.open();await settle();capture("pause_main",game.pause_menu.root,"暂停菜单")
 game.pause_menu.page="help";game.pause_menu._render();await settle();capture("pause_help",game.pause_menu.root,"操作说明");game.pause_menu.close()
 game.character_controller.open();await settle();capture("character",game.character_controller.root,"人物状态与装备");game.character_controller.close()
 game._show_map(true);await settle();capture("world_map",game.map_panel,"地图导览");game._show_map(false)
 game._catalog(true);await settle();capture("world_decor",game.panel,"布置目录");game.panel.hide();game.editing=false
 game.dialog.show();capture("world_dialog",game.dialog,"通用互动对话");game.dialog.hide()
 var dialogue=game.dialogue_controller
 dialogue.state={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]};dialogue.context={"room":"云湾公寓","place":"apt_2","object":"这里"};dialogue.start("welcome")
 dialogue.revealed=10000;dialogue.text_label.visible_characters=-1;await settle();capture("dialogue",dialogue.root,"对话正文")
 dialogue.advance();dialogue.advance();await settle();capture("dialogue_choices",dialogue.root,"对话回复")
 dialogue.show_backlog();await settle();capture("dialogue_backlog",dialogue.root,"对话回看");dialogue.close()
 var expedition=game.expedition_controller
 expedition.state.save_path="res://预览/可编辑UI_20261011/expedition.json"
 expedition.briefing();await settle();capture("expedition_briefing",expedition.surface,"研究远征 · 出发说明")
 expedition.open_warehouse();await settle();capture("expedition_warehouse",expedition.surface,"研究远征 · 仓库")
 expedition.open_loadout();await settle();capture("expedition_loadout",expedition.surface,"研究远征 · 制作配装")
 expedition.state.new_run(20261011);expedition.running=true;expedition.mode="";expedition._render_explore();await settle();capture("expedition_explore",expedition.surface,"研究远征 · 探索")
 expedition.selected_object={"id":"preview_signal","enemy":"hallucination","name":"未知异常"};expedition._encounter();await settle();capture("expedition_encounter",expedition.surface,"研究远征 · 异常信号")
 expedition.selected_object={"id":"preview_exit","permission":false,"name":"安全撤离口"};expedition._extraction();await settle();capture("expedition_extraction",expedition.surface,"研究远征 · 撤离选择")
 var preview_item:String=expedition.data.resources.keys()[0]
 expedition.state.run.rolled["preview_cache"]={preview_item:3}
 expedition.selected_object={"id":"preview_cache","name":"数据柜","type":"server"};expedition._open_loot();await settle();capture("expedition_loot",expedition.surface,"研究远征 · 搜索物资")
 expedition.state.run.bag={preview_item:2};expedition.mode="";expedition.open_bag();await settle();capture("expedition_bag",expedition.surface,"研究远征 · 背包")
 expedition.pause();await settle();capture("expedition_pause",expedition.surface,"研究远征 · 暂停")
 expedition.mode="";expedition.start_combat("hallucination","preview_signal");await settle();capture("expedition_battle",expedition.surface,"研究远征 · 三指令交战")
 expedition.finish_run(true);await settle();capture("expedition_settlement",expedition.surface,"研究远征 · 撤离结算")
 expedition.running=false;expedition.mode="";expedition.root.hide()
 var pack=load("res://district/map_pack26.gd").new();game.add_child(pack);pack.configure(game);game.pack26_controller=pack
 capture("pack26_hud",pack.root,"立体新区 · 工具栏",[pack.shade])
 pack.save_path="res://预览/可编辑UI_20261011/pack26.json";pack.bag={"Token":2};pack.open_bag();await settle();capture("pack26_bag",pack.modal,"立体新区 · 背包")
 pack.source_loot={"id":"preview","title":"示例补给"};pack.remaining={"preview":{"Token":3}};pack._open_loot();await settle();capture("pack26_loot",pack.modal,"立体新区 · 搜索补给")
 pack._extract();await settle();capture("pack26_extracted",pack.modal,"立体新区 · 撤离结果")
 game.queue_free();await settle()
 var engine=load("res://battle/battle_engine.gd").new(20261011)
 engine.add_ally({"id":"player","name":"大肥鱼","level":13,"hp":69,"max_hp":148,"stamina":198,"max_stamina":198,"atk":16,"def":7,"spd":9,"ap":100})
 engine.add_foe({"id":"gpt6","kind":"gpt6","name":"gpt6","hp":65,"max_hp":65,"atk":5,"def":1,"spd":1})
 engine.enable_cards(JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json")))
 var screen=load("res://battle/battle_screen.gd").new();root.add_child(screen)
 screen.open(engine,{"title":"潮汐遭遇战","textures":{"gpt6":"res://assets/monsters/gpt6.png"},"items":[{"id":"first_aid_kit","name":"港口急救包","count":3,"description":"恢复生命","effects":{"heal":10},"usable":true}]})
 await create_timer(.5).timeout;screen.skip_playback();await settle();capture("battle",screen.root,"卡牌战斗")
 screen._on_item_menu();await settle();capture("battle_item",screen.root,"战斗补给")
 screen._back_to_command();screen._on_skill_menu();await settle();capture("battle_skill",screen.root,"战斗技能")
 screen.context.pending_result="win";screen._finish_playback();await settle();capture("battle_result",screen.root,"战斗结算");screen.close();screen.queue_free();await settle()
 var file:=FileAccess.open("res://ui/design/catalog.json",FileAccess.WRITE);file.store_string(JSON.stringify(entries," "));file.close()
 print("EDITABLE_UI_EXPORT: ",entries.size()," pages, ",failures," failures")
 quit(0 if failures==0 else 1)
