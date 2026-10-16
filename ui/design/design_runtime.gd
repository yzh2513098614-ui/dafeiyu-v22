extends Node
## Late visual overrides retain the original nodes, signals, save logic and live game data.
const Document=preload("res://ui/design/layout_document.gd")
var cache:Dictionary={}
var battle_refs:Array=[]
var enabled:=true
var applied_count:=0

func _ready()->void:
 process_priority=10000
 get_tree().node_added.connect(_node_added)

func _node_added(node:Node)->void:
 var script:Script=node.get_script()
 if script!=null and script.resource_path=="res://battle/battle_screen.gd":battle_refs.append(weakref(node))

func context(id:String,target:Control,title:String)->Dictionary:
 return {"id":id,"target":target,"title":title}

func contexts()->Array:
 var result:Array=[]
 var game:Node=get_tree().current_scene
 if is_instance_valid(game):
  var script:Script=game.get_script()
  if script!=null and script.resource_path=="res://ui/harbor_start.gd":
   result.append(context("title_"+str(game.page),game,"标题 · "+str(game.page)))
  elif game.has_method("_game_font") and game.get("loot")!=null:
   var loot=game.loot
   result.append(context("world_hud",game.ui.get_child(0),"世界 · 常用工具栏"))
   if game.get("district_canvas")!=null:result.append(context("world_navigation",game.district_canvas,"世界 · 地点与导览入口"))
   if is_instance_valid(loot.canvas):result.append(context("world_loot_prompt",loot.canvas,"世界 · 背包入口与宝箱提示"))
   if is_instance_valid(loot.modal) and loot.mode!="":result.append(context("inventory_"+{"inventory":"bag_sticker","loot":"chest_sticker","note":"note"}.get(loot.mode,loot.mode),loot.modal,"背包 · "+loot.mode))
   if is_instance_valid(game.settings_view):result.append(context("settings_"+str(game.settings_view.settings_tab),game.settings_panel,"设置 · "+str(game.settings_view.settings_tab)))
   if game.pause_menu and is_instance_valid(game.pause_menu.root):result.append(context("pause_"+str(game.pause_menu.page),game.pause_menu.root,"暂停 · "+str(game.pause_menu.page)))
   if game.dialogue_controller and is_instance_valid(game.dialogue_controller.root):
    var dialogue=game.dialogue_controller
    result.append(context("dialogue_gal",dialogue.root,"对话 · 粉色正文"))
    if dialogue.choice_panel.visible:result.append(context("dialogue_gal_choices",dialogue.root,"对话 · 回复"))
    if dialogue.backlog_open:result.append(context("dialogue_gal_backlog",dialogue.root,"对话 · 回看"))
    if dialogue.config_open:result.append(context("dialogue_gal_config",dialogue.root,"对话 · 阅读设置"))
   if game.character_controller and is_instance_valid(game.character_controller.root):result.append(context("character",game.character_controller.root,"人物 · 状态与装备"))
   if game.get("map_panel")!=null:result.append(context("world_map",game.map_panel,"世界 · 地图导览"))
   result.append(context("world_decor",game.panel,"世界 · 布置目录"))
   result.append(context("world_dialog",game.dialog,"世界 · 通用互动对话"))
   if game.get("map_interactions")!=null:result.append(context("world_interaction",game.map_interactions.root,"世界 · 附近互动"))
   if game.get("pack26_controller")!=null:
    var pack=game.pack26_controller
    if is_instance_valid(pack.root):result.append(context("pack26_hud",pack.root,"新区 · 探索工具栏"))
    if is_instance_valid(pack.modal):result.append(context("pack26_"+str(pack.mode),pack.modal,"新区 · "+str(pack.mode)))
   if game.get("expedition_controller")!=null:
    var expedition=game.expedition_controller
    var design_mode:String="explore" if expedition.mode=="" else ("battle" if expedition.mode=="executing" else str(expedition.mode))
    if is_instance_valid(expedition.surface):result.append(context("expedition_"+design_mode,expedition.surface,"研究远征 · "+str(expedition.mode)))
 for ref in battle_refs:
  var screen:Node=ref.get_ref()
  if is_instance_valid(screen) and is_instance_valid(screen.root):
   result.append(context("battle",screen.root,"战斗 · 手牌、敌人、行动与结算"))
   if screen.mode in ["item","skill","result"]:result.append(context("battle_"+str(screen.mode),screen.root,"战斗 · "+str(screen.mode)))
 return result

func _process(_delta:float)->void:
 if not enabled:return
 applied_count=0
 for entry in contexts():
  var id:String=entry.id
  if not cache.has(id):cache[id]=Document.changes(id)
  if not cache[id].is_empty():applied_count+=Document.apply(entry.target,cache[id])

func reload_designs()->void:
 cache.clear()

func apply_now(id:String,target:Control)->int:
 cache[id]=Document.changes(id)
 return Document.apply(target,cache[id])
