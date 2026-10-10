extends Node
## One proximity card and one action resolver for mouse buttons and the E key.
const Style=preload("res://ui/whale_skin.gd")
const Fit=preload("res://ui/ui_fit.gd")
const Containers=preload("res://district/container_rooms.gd")
const Door=preload("res://district/interactive_door.gd")
var game
var root: Control
var card: Panel
var title_label: Label
var detail_label: Label
var primary: Button
var secondary: Button
var selected: Dictionary={}
var appear: Tween

func configure(owner_game) -> void:
 game=owner_game
 var layer:=CanvasLayer.new();layer.name="MapInteractionLayer";layer.layer=58;add_child(layer)
 root=Control.new();root.name="MapInteractionCanvas";root.mouse_filter=Control.MOUSE_FILTER_IGNORE
 root.theme=Style.theme(game._game_font());layer.add_child(root);Fit.fill(root)
 card=Style.panel(root,Vector2.ZERO,Vector2(368,150),"paper");card.name="NearbyInteractionCard"
 title_label=Style.label(card,"",Vector2(16,10),Vector2(336,40),20)
 title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 detail_label=Style.label(card,"",Vector2(16,52),Vector2(336,30),16,Style.MUTED)
 primary=game._button("E 开门",Vector2(15,92),Vector2(338,46),card,func():_clicked(false))
 primary.name="PrimaryInteraction";primary.focus_mode=Control.FOCUS_NONE
 secondary=game._button("关门",Vector2(246,92),Vector2(107,46),card,func():_clicked(true))
 secondary.name="SecondaryInteraction";secondary.focus_mode=Control.FOCUS_NONE
 card.hide()

func clear() -> void:
 selected={}
 if appear and appear.is_valid():appear.kill()
 if card:card.hide()

func _available() -> bool:
 if not game or not game.district_ready or game.transitioning or game.changing:return false
 if game.dialog_open or game.editing or game.panel.visible or game.map_panel.visible or game.settings_panel.visible or game.loot.blocked():return false
 if game.pause_menu and game.pause_menu.active:return false
 if game.character_controller and game.character_controller.active:return false
 if game.combat_controller and game.combat_controller.in_battle():return false
 if game.expedition_controller and game.expedition_controller.is_active():return false
 if game.pack26_controller and game.pack26_controller.is_active() and game.pack26_controller.blocked():return false
 return true

func _distance(point: Vector3) -> float:
 if absf(point.y-game.player.global_position.y)>1.1:return INF
 return Vector2(point.x-game.player.global_position.x,point.z-game.player.global_position.z).length()

func _visible_target(point: Vector3,node: Node=null) -> bool:
 if node is Node3D and not node.is_visible_in_tree():return false
 var query:=PhysicsRayQueryParameters3D.create(game.player.global_position+Vector3(0,.75,0),point+Vector3(0,.75,0),1,[game.player.get_rid()])
 var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():return true
 return node!=null and (hit.collider==node or node.is_ancestor_of(hit.collider))

func _pick() -> Dictionary:
 if not _available():return {}
 if game.pack26_controller and game.pack26_controller.is_active():
  var marker: Node3D=game.pack26_controller.level.nearest_interaction(game.player.global_position)
  if marker:return {"kind":"marker","node":marker,"point":marker.global_position,"id":str(marker.get_instance_id())}
  return {}
 var best:=2.4
 var chosen: Dictionary={}
 # Standing on the destination mat keeps its priority over nearby cupboards.
 for portal: Dictionary in game.portals:
  var point: Vector3=portal.pos
  var door=portal.get("door") as Door
  if not is_instance_valid(door):door=null
  var d: float=_distance(point)
  if d>=best or not _visible_target(point,door):continue
  chosen={"kind":"portal","portal":portal,"point":point,"id":"portal:"+str(portal.target)+":"+str(point)};best=d
  if d<1.25:return chosen
 for node in get_tree().get_nodes_in_group("map_interactive_doors"):
  if not is_instance_valid(node) or not game.is_ancestor_of(node):continue
  var point: Vector3=node.interaction_position()
  var d: float=_distance(point)
  if d>=best or not _visible_target(point,node):continue
  # Entrance doors belong to the destination card, which offers open then enter.
  var linked:=false
  for portal: Dictionary in game.portals:
   if portal.get("door")==node:linked=true;break
  if linked:continue
  chosen={"kind":"door","node":node,"point":point,"id":str(node.get_instance_id())};best=d
 var objects: Array=game.world.get_children()
 for chest in game.loot.chests:
  if is_instance_valid(chest) and not objects.has(chest):objects.append(chest)
 for node in objects:
  if not is_instance_valid(node) or not node is Node3D:continue
  var chest: bool=game.loot.chests.has(node)
  var usable: bool=chest or node.has_method("toggle_open") or (node.has_method("has_action") and bool(node.call("has_action")))
  if not usable:continue
  if chest and game.loot.nearby!=node:continue
  var point: Vector3=node.global_position
  var d: float=_distance(point)
  if d>=best or not _visible_target(point,node):continue
  chosen={"kind":"chest" if chest else "object","node":node,"point":point,"id":str(node.get_instance_id())};best=d
 return chosen

func try_interact() -> bool:
 var target: Dictionary=_pick()
 if target.is_empty():return false
 _activate(target,false);return true

func _clicked(alternate: bool) -> void:
 # A button never acts on a different target after the player walks away.
 var target: Dictionary=_pick()
 if target.is_empty() or target.id!=selected.get("id",""):clear();return
 _activate(target,alternate)

func _activate(target: Dictionary,alternate: bool) -> void:
 match target.kind:
  "portal":
   var portal: Dictionary=target.portal
   var door=portal.get("door") as Door
   if is_instance_valid(door):
    if alternate:door.set_open(not door.opened);return
    if not door.is_passable():
     if not door.opened:door.set_open(true)
     return
   clear();game.request_travel(str(portal.target),str(portal.route))
  "door":target.node.toggle_open()
  "chest":game.loot.open_chest()
  "object":
   var node: Node3D=target.node
   var was_open: bool=bool(node.get("opened"))
   if node.has_method("toggle_open"):node.call("toggle_open")
   else:node.call("interact")
   if not was_open and bool(node.get("opened")):SfxDirector.play("chest_open",-4.0)
  "marker":game.pack26_controller.level.activate(target.node)

func _process(_delta: float) -> void:
 if not card:return
 var target: Dictionary=_pick()
 if target.is_empty():clear();return
 var changed: bool=target.id!=selected.get("id","")
 selected=target
 if game.loot.prompt:game.loot.prompt.hide()
 if game.destination_hint:game.destination_hint.hide()
 card.show()
 if changed:
  if appear and appear.is_valid():appear.kill()
  card.modulate.a=.0;appear=card.create_tween();appear.tween_property(card,"modulate:a",1.0,.14)
 _render(target)
 var point: Vector3=target.point+Vector3(0,1.25,0)
 if game.camera.is_position_behind(point):card.hide();return
 var screen: Vector2=game.camera.unproject_position(point)
 var area: Vector2=game.get_viewport().get_visible_rect().size
 card.position=Vector2(clampf(screen.x-card.size.x*.5,24,maxf(24,area.x-card.size.x-24)),clampf(screen.y-card.size.y-22,128,maxf(128,area.y-card.size.y-150)))

func _render(target: Dictionary) -> void:
 primary.disabled=false;secondary.hide();primary.size.x=338
 detail_label.text="点击按钮或按 E · 离开后自动收起"
 match target.kind:
  "door":
   var door=target.node as Door
   title_label.text=door.display_name
   primary.text="E 关门" if door.opened else "E 开门"
   if door.animating:detail_label.text="门扇正在转动 · 可再次按 E 改变方向"
   if door.obstructed:detail_label.text="门扇前有人 · 移开后继续开合"
  "portal":
   var portal: Dictionary=target.portal
   title_label.text=str(portal.label)
   var door=portal.get("door") as Door
   primary.text="E "+("进入" if str(portal.route)=="entrance" else "通行")
   if str(portal.route)=="stairs":primary.text="E 下楼" if str(portal.label).contains("下") else "E 上楼"
   elif str(portal.route)=="elevator":primary.text="E 乘电梯"
   if is_instance_valid(door):
    if not door.is_passable():primary.text="E 开门";primary.disabled=door.opened
    secondary.show();primary.size.x=221;secondary.text="关门" if door.opened else "开门"
    if door.animating:detail_label.text="正在开门…" if door.opened else "正在关门…"
    if door.obstructed:detail_label.text="请离开门扇转动范围"
  "chest":
   title_label.text=str(target.node.display_name);primary.text="E 打开并查看物品"
  "object":
   title_label.text=Containers.describe(target.node)
   primary.text="E 合上" if bool(target.node.get("opened")) else "E 打开"
   if target.node.has_meta("asset_definition") and bool(target.node.get("passage")):
    primary.text="E 关门" if bool(target.node.get("opened")) else "E 开门"
  "marker":
   var marker: Node3D=target.node
   title_label.text=str(marker.get_meta("title","附近设施"))
   primary.text="E "+str({"key":"拾取钥匙","switch":"操作开关","chest":"打开并搜索","checkpoint":"记录补给点","portal":"进入","extract":"撤离"}.get(str(marker.get_meta("kind")),"交互"))
