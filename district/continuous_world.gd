extends "res://district/neighborhood.gd"
## One continuous city, and one continuous floor for each building level.
const CityMap=preload("res://district/city_map.gd")
const LifePlaces=preload("res://district/life_places.gd")
const WholeFloor=preload("res://district/whole_floor.gd")
const SpaceShape=preload("res://district/space_shape.gd")
const TrialGround=preload("res://combat/trial_ground.gd")
const ContainerRooms=preload("res://district/container_rooms.gd")
const ResearchSite=preload("res://expedition/research_site.gd")
const MapPack26=preload("res://district/map_pack26.gd")
var expedition_controller: Node
var pack26_controller: Node
var map_interactions: Node
var harbor_controller: Node
var home_controller: Node
var campus_controller: Node
var space_bounds:=Vector2(84,64)
var room_zones: Array=[]
var overview_mode:=true
var view_size:=90.0
var overview_size:=90.0
var view_center:=Vector3.ZERO
var zone_id:=""
var view_button: Button
var zone_label: Label
var clock_panel: Panel
var clock_label: Label
var life_booted:=false
var autosave_clock:=0.0
var loading_save:=false
var click_navigation: Node
var world_minimap: Control

func _ready() -> void:
 super._ready()
 demo=false;ui_demo=false;loot_demo=false;atmosphere_demo=false
 get_window().title="大肥鱼 · 数值战斗怪物 v22"
 nav_buttons[0].text="1 公寓";nav_buttons[1].text="2 街区";nav_buttons[2].text="3 社区馆"
 view_button=_button("Z 跟随人物",Vector2(1098,45),Vector2(302,55),district_canvas,func():_toggle_view())
 UiFit.pin_right(view_button,302,48,45,55)
 zone_label=WhaleSkin.label(district_canvas,"",Vector2(48,142),Vector2(450,40),19,WhaleSkin.INK)
 var location_style:=preload("res://ui/world_hud_skin.gd").frame();location_style.bg_color=Color("d2def6");location_style.set_corner_radius_all(12);location_style.content_margin_left=14;location_style.content_margin_right=14
 zone_label.add_theme_stylebox_override("normal",location_style)
 preload("res://ui/world_hud_skin.gd").single_line(zone_label)
 clock_panel=WhaleSkin.panel(district_canvas,Vector2(1098,312),Vector2(302,38),"paper")
 UiFit.pin_right(clock_panel,302,48,312,38)
 clock_label=WhaleSkin.label(clock_panel,"",Vector2(10,5),Vector2(282,28),18)
 _update_view_button()
 var resumed:=false
 if HarborPrefs.continue_game:
  resumed=_restore()
  if not resumed:_travel("city")
 else:_travel(HarborPrefs.starting_place if locations.has(HarborPrefs.starting_place) else "city")
 HarborPrefs.apply_game(self,resumed)
 if location_id=="whale_home" and not resumed and not overview_mode:view_size=15.0;camera.size=view_size
 pause_menu=preload("res://ui/pause_menu.gd").new();add_child(pause_menu);pause_menu.configure(self)
 character_controller=preload("res://character/character_controller.gd").new();add_child(character_controller);character_controller.configure(self)
 combat_controller=preload("res://combat/combat_controller.gd").new();add_child(combat_controller);combat_controller.configure(self)
 expedition_controller=preload("res://expedition/expedition_controller.gd").new();add_child(expedition_controller);expedition_controller.configure(self)
 map_interactions=preload("res://district/map_interactions.gd").new();add_child(map_interactions);map_interactions.configure(self)
 life_booted=true
 click_navigation=preload("res://character/click_navigation.gd").new();add_child(click_navigation);click_navigation.configure(self)
 world_minimap=preload("res://ui/world_minimap.gd").new();district_canvas.add_child(world_minimap);world_minimap.configure(self,click_navigation)
 if not "--test-dialogue" in OS.get_cmdline_user_args() and not "--capture-dialogue" in OS.get_cmdline_user_args():call_deferred("_welcome_dialogue")

func _welcome_dialogue() -> void:
 if location_id=="research":return
 if dialogue_controller and not dialogue_controller.state.seen.has("welcome"):dialogue_controller.start_topic()

func _define_locations() -> void:
 # The trial is an optional connected location; retain all existing city places.
 locations={"city":{"name":"鲸落港 · 连续街区","group":"outside","type":"city","subtitle":"海蓝餐厅 / 海湾学校 / 海湾医院 · 连续街区与多层室内","links":["apt_1","community_1","inn_1","garden","market","gallery","obs_1","music_1","restaurant_1","school_1","hospital_1"]}}
 locations.city.links.append("trial")
 locations["research"]={"name":"离线研究中心 · 搜打撤","group":"harbor","type":"expedition","subtitle":"搜索物资 / 三指令同步交战 / 双出口撤离","links":["city"]}
 locations.city.links.append("research")
 locations["trial"]={"name":"潮汐试炼场","group":"outside","type":"trial","subtitle":"海沫团、珊瑚蟹、gpt6 与守潮者 · 走近后点「战斗」进入回合制交战","links":["city"]}
 var specs: Array=[
  ["obs","observatory","潮汐观测站",3,["海洋标本 / 海水实验 / 航海档案 / 温室 / 气象 / 茶厅","大望远镜 / 星图研究 / 无线电 / 影像 / 气象 / 夜班休息","星空穹顶 / 精密观测 / 校准 / 星轨测算 / 器材 / 天象档案"]],
  ["music","music","蓝鲸音乐馆",2,["小剧场 / 录音 / 混录 / 乐器修理 / 鼓乐 / 会客","合奏 / 唱片试听 / 乐器收藏 / 琴房 / 旋律创作 / 静听"]],
  ["apt","apartment","云湾公寓",3,["共享客厅 / 厨房 / 阅读室 / 客房 / 卫浴 / 休息室","卧室 / 工作间 / 客厅 / 厨房 / 卫浴 / 客房","植物房 / 手作室 / 茶室 / 洗衣房 / 储藏室 / 露台"]],
  ["community","community","潮汐社区馆",2,["咖啡厅 / 书店 / 接待 / 活动室 / 厨房 / 卫浴","创作间 / 会议室 / 展示室 / 办公室 / 资料室 / 茶室"]],
  ["inn","inn","海风旅舍",3,["接待 / 休息厅 / 餐厅 / 厨房 / 行李间 / 卫浴","201 / 202 / 203 / 204 / 公共客厅 / 洗衣房","301 / 302 / 303 / 304 / 阅读室 / 茶室"]]]
 specs.append(["restaurant","restaurant","海蓝餐厅",2,["主餐厅 / 柜台 / 明档厨房 / 食材库 / 楼梯厅 / 地下入口","宴会厅 / 大小包间 / 茶水间 / 接待 / 海风露台"]])
 specs.append(["school","school","海湾学校",2,["门厅 / 教室 / 备课室 / 阅读室 / 海洋科学 / 手作室","数学 / 语言 / 媒体 / 天文实验 / 工艺 / 教具室"]])
 specs.append(["hospital","hospital","海湾医院",2,["接待 / 分诊 / 门诊 / 药房 / 影像 / 候诊","病房 / 治疗 / 护士站 / 恢复 / 检验 / 家属休息"]])
 for spec in specs:
  var prefix: String=spec[0]
  var count: int=spec[3]
  for level in range(1,count+1):
   var id:=prefix+"_"+str(level)
   var links: Array=["city"]
   if level>1:links.append(prefix+"_"+str(level-1))
   if level<count:links.append(prefix+"_"+str(level+1))
   locations[id]={"name":str(spec[2])+" · "+str(level)+"F 整层","group":"floor"+str(level),"type":"floor","building":spec[1],"building_name":spec[2],"prefix":prefix,"floor":level,"floors":count,"subtitle":spec[4][level-1],"links":links}
 locations.restaurant_1.links.append("restaurant_b1")
 locations.restaurant_2.links=["restaurant_1"]
 locations["restaurant_b1"]={"name":"海蓝餐厅 · B1 后勤与暗室","group":"floorb1","type":"floor","building":"restaurant","building_name":"海蓝餐厅","prefix":"restaurant","floor":0,"floors":2,"subtitle":"冷藏食材 / 干货陈酿 / 维修 / 账册 / 值班间 / 隐藏暗室","links":["restaurant_1"]}
 locations["garden"]={"name":"青柠花房 · 温室庭院","group":"outside","type":"courtyard","subtitle":"折角温室 / 弧形花岛 / 树下茶庭","links":["city"]}
 locations["market"]={"name":"海风集市 · 港口小街","group":"outside","type":"courtyard","subtitle":"交错店铺 / 双向街口 / 扇形海岸平台","links":["city"]}
 locations["reading_court"]={"name":"漂流书庭 · 海边阅读院","group":"outside","type":"courtyard","subtitle":"弧形书亭 / 阅读平台 / 手作树庭","links":["city"]}
 locations["civic_garden"]={"name":"蓝湾公共花园","group":"outside","type":"courtyard","subtitle":"花径 / 休息庭 / 社区活动平台","links":["city"]}
 locations.city.links.append("reading_court");locations.city.links.append("civic_garden")
 locations["story_quay"]={"name":"海风码头 · 探索画面样板","group":"outside","type":"courtyard","subtitle":"扇形石铺 / 木长椅 / 渔获箱 / 柔和暖光与蓝紫阴影","links":["city"]}
 locations.city.links.append("story_quay")
 locations["story_harbor"]={"name":"海风码头 · 双层港区","group":"outside","type":"harbor3d","subtitle":"渔获广场 / 双栈桥 / 渔具工坊 / 灯塔海景步道 · 真实楼梯上下层","links":["city","story_quay"]}
 locations.city.links.append("story_harbor");locations.story_quay.links.append("story_harbor")
 locations["tidal_cafe"]={"name":"潮汐信笺 · 海景咖啡馆","group":"floor1","type":"salon","subtitle":"海盐咖啡吧 / 分享桌 / 慢读角 / 海景窗湾 / 漂流信笺 · E 操作设施","links":["city"]}
 locations.city.links.append("tidal_cafe")
 locations["whale_home"]={"name":"大肥鱼之家 · 三层海景宅邸","group":"outside","type":"home3d","subtitle":"海盐厨房 / 水族客厅 / 海景书房 / 鲸鱼卧室 / 观星露台 / 花园码头 · 楼梯直达三层","links":["city"]}
 locations.city.links.append("whale_home")
 locations["gallery"]={"name":"白帆艺廊 · 创作整层","group":"floor1","type":"floor","building":"gallery","prefix":"gallery","floor":1,"floors":1,"subtitle":"主展厅 / 绘画工坊 / 资料室 / 小展 / 茶厅 / 库房","links":["city"]}
 # 2026-10-03「场景容器扩展包」搭的两个新地点。
 # 单独给一个 type ("depot") 是为了不走 floor 那条分支 ——
 # 那条分支会去读 data.floor / data.prefix 算上下楼，这里既没有楼层也不是建筑。
 locations["depot"]={"name":"港湾补给仓 · 1F 货区","group":"harbor","type":"depot","subtitle":"货笼 / 信号柜 / 潜水装备箱 / 托盘与气瓶 · 楼梯可上 2F","links":["city","depot_2f"]}
 # 二层：楼层在这台工程里就是「另一个地点 + 楼梯传送」（apt_1/2/3 也是这么做的）。
 # 人物被锁在 y=0，走不上抬高的地板（说明见 container_rooms.gd 的 _gallery），
 # 所以二层用「往下挖一口井」表达高度差，而不是抬高地面。
 locations["depot_2f"]={"name":"港湾补给仓 · 2F 环形挑廊","group":"harbor","type":"depot","subtitle":"绕一口挑空井走一圈，能看见一层的货区 · 楼梯下到 1F","links":["city","depot"]}
 locations["coldstore"]={"name":"后厨冷藏间","group":"harbor","type":"depot","subtitle":"双门冷藏柜 / 饮品柜 / 存货抽屉 / 存款保险柜 · 走近容器按 E 开合","links":["city"]}
 locations.city.links.append("depot")
 locations.city.links.append("coldstore")
 # 异形房间 / 室外潮间带（同样走 type "depot"，由 ContainerRooms 按 id 分派）
 locations["vault"]={"name":"港湾保险库","group":"harbor","type":"depot","subtitle":"L 形平面 · 主库房与东翼点钞室之间要绕过拐角 · 按 E 开保险柜","links":["city"]}
 locations["lab"]={"name":"地下实验区","group":"harbor","type":"depot","subtitle":"U 形平面 · 北楼样本库与东西两翼围着一个中央中庭 · 按 E 开柜","links":["city"]}
 locations["tidal_high"]={"name":"潮间带 · 涨潮","group":"harbor","type":"depot","subtitle":"露天海岸 · 水漫上滩地，能走的只剩堤顶与栈桥 · 按 E 换潮位","links":["city","tidal_low"]}
 locations["tidal_low"]={"name":"潮间带 · 落潮","group":"harbor","type":"depot","subtitle":"露天海岸 · 水位退去，礁石与贝壳露出来可以走过去 · 按 E 换潮位","links":["city","tidal_high"]}
 for extra in ["vault","lab","tidal_high","tidal_low"]:
  locations.city.links.append(extra)
 # 三种新拓扑：回字形环廊 / T 形 / Z 形
 locations["archive"]={"name":"潮汐档案馆","group":"harbor","type":"depot","subtitle":"回字形环廊 · 四翼围着一个中央天井，能绕一圈走回原地 · 按 E 开柜","links":["city"]}
 locations["customs"]={"name":"港口海关查验厅","group":"harbor","type":"depot","subtitle":"T 形平面 · 宽厅正中伸出一条支廊，走到中段才发现 · 按 E 开柜","links":["city"]}
 locations["weather"]={"name":"山地气象站","group":"harbor","type":"depot","subtitle":"Z 形平面 · 通道先偏左再偏右，一路转折 · 按 E 开柜","links":["city"]}
 for extra in ["archive","customs","weather"]:
  locations.city.links.append(extra)
 # 十字形 / 室内隔断 / 梳形
 locations["hub"]={"name":"中央枢纽站","group":"harbor","type":"depot","subtitle":"十字形平面 · 中央大厅四个方向各接一条翼，先走哪边是真选择 · 按 E 开柜","links":["city"]}
 locations["quarantine"]={"name":"分区检疫所","group":"harbor","type":"depot","subtitle":"矩形轮廓、室内四道隔断带门洞 · 走到门洞才知道隔壁有什么 · 按 E 开柜","links":["city"]}
 locations["spares"]={"name":"备件长库","group":"harbor","type":"depot","subtitle":"梳形平面 · 一条 24 米长脊，两侧交替伸出四个侧龛 · 按 E 开柜","links":["city"]}
 for extra in ["hub","quarantine","spares"]:
  locations.city.links.append(extra)
 locations["wuming_campus"]={"name":"广西医科大学 · 武鸣校区","group":"outside","type":"campus","subtitle":"照片细化校园 · 教学楼 / 独立钟楼 / 弘医双塔 / 图书馆 / A、B、C三区","links":["city"]}
 locations.city.links.append("wuming_campus")
 MapPack26.register(locations)


func _group_name(group: String) -> String:
 return {"outside":"连续大街区","harbor":"东港与仓储带","complex":"立体新区 · 26地图","floor1":"各建筑 · 1F 整层","floor2":"各建筑 · 2F 整层","floor3":"各建筑 · 3F 整层","floorb1":"B1 地下与隐蔽空间"}.get(group,group)

func _show_map(show: bool) -> void:
 super._show_map(show)
 if show:
  if view_button:view_button.hide()
  if zone_label:zone_label.hide()

func _layout(index: int) -> void:
 if not district_ready:super._layout(index);return
 request_travel(["apt_2","city","community_1"][clampi(index,0,2)])

## 按 E 的优先级：先给「开容器」一次机会，再走原有逻辑。
## 新地点里容器就是主要交互物，不先问一句的话，按 E 会一路走到
## 「屋里没有可交互的东西」那条分支，箱子摆在眼前却开不了。
## 只在 depot 类地点拦一次，其它地点的按键行为一字不改。
## 这个地点有没有**可开合的容器** —— 决定按 E 要不要先问一句「开箱」。
##
## depot 类（补给仓、冷藏间、档案馆…）是室内容器地点；city 大地图上现在也摆了
## 仓储带的货箱（见 city_map.gd 的 _containers），同样要能开。
## 这两处判断必须走同一个函数：分散写死在 _interact 和提示条里的话，
## 加一处地点就会漏掉另一处，症状是「箱子看得见、按 E 没反应」。
func _has_containers() -> bool:
 return location_id.begins_with("restaurant_") or str(locations.get(location_id, {}).get("type", "")) in ["depot","city"]

func _interact() -> void:
 if map_interactions and map_interactions.try_interact():return
 if pack26_controller and pack26_controller.is_active():
  if pack26_controller.blocked() or map_panel.visible or dialog_open:return
  var marker=pack26_controller.level.nearest_interaction(player.position)
  if marker:pack26_controller.level.activate(marker)
  return
 if _has_containers():
  # **站在出口地垫上（1.25m 内）时，E 一律是「离开」。**
  #
  # 为什么这条要放在最前面：容器（以及室内可开合物品）的判定半径是 2.4m，
  # 比地垫的 1.25m 大得多。原来的顺序是「先容器、后传送点」，于是任何
  # **柜子挨着门口**的房间都会出不去 —— 实验区、气象站、备件长库就是这样，
  # 站在回街区的垫子上按 E，开的是旁边两米外的柜子。
  # 潮间带更严重：它的 E 被「换潮位」永久占用，等于有进无出。
  # 现在踩在垫子上就是出去（潮间带同理），离开垫子 E 才归柜子/换潮位。
  if not nearest_portal.is_empty():
   super._interact();return
  # 潮间带：同一片滩的涨落潮是两个地点，按 E 直接换 —— 这是「同一张地图的两种状态」
  if location_id == "tidal_high":
   request_travel("tidal_low");return
  if location_id == "tidal_low":
   request_travel("tidal_high");return
  if ContainerRooms.try_toggle(self):return
 super._interact()

func _travel(target: String,route: String="",staged: bool=false) -> void:
 if expedition_controller and expedition_controller.is_active() and target!="research":return
 if combat_controller and combat_controller.in_battle():return
 target={"home_201":"city","street":"city","cafe":"community_1"}.get(target,target)
 if changing or not locations.has(target):return
 changing=true
 if click_navigation:click_navigation.cancel()
 if staged:await preload("res://ui/loading_transition.gd").instance(get_tree()).checkpoint(.12,"保存房间布置与当前位置")
 if map_interactions:map_interactions.clear()
 if harbor_controller and harbor_controller.is_active():harbor_controller.leave()
 if home_controller and home_controller.is_active():home_controller.leave()
 if pack26_controller and pack26_controller.is_active():pack26_controller.leave()
 if campus_controller and campus_controller.is_active():campus_controller.leave()
 var previous:=location_id
 if not loading_save and locations.has(previous):_remember_room()
 location_id=target;visited[target]=true
 nearest_portal={};portals.clear();closest=null
 panel.hide();settings_panel.hide();dialog.hide();dialog_open=false;editing=false
 if loot:loot.close()
 if map_panel:map_panel.hide();map_shade.hide()
 _clear_world();floor_mesh.hide()
 if staged:await preload("res://ui/loading_transition.gd").instance(get_tree()).checkpoint(.28,"整理场景空间")
 # Shell survives travel; scene-specific contour metadata must not leak into
 # the city or a different floor's placement and save restoration.
 for key in ["floor_layout","layout_revision","floor_contour","floor_contours","room_connections","partition_family","guide_anchor","outdoor_obstacles","walk_clear","supply_anchor","story_look","cafe_look","cafe_windows","harbor_water"]:
  if shell.has_meta(key):shell.remove_meta(key)
 var data: Dictionary=locations[target]
 var built: Dictionary
 if data.type=="home3d":
  if not home_controller:
   home_controller=preload("res://district/whale_home_controller.gd").new();add_child(home_controller);home_controller.configure(self)
  built=home_controller.build()
 elif data.type=="campus":
  if not campus_controller:
   campus_controller=preload("res://district/wuming_campus.gd").new();add_child(campus_controller);campus_controller.configure(self)
  if staged:await campus_controller.prepare()
  built=campus_controller.build()
 elif data.type=="harbor3d":
  if not harbor_controller:
   harbor_controller=preload("res://district/harbor_terraces_controller.gd").new();add_child(harbor_controller);harbor_controller.configure(self)
  built=harbor_controller.build()
 elif data.type=="pack26":
  if not pack26_controller:
   pack26_controller=MapPack26.new();add_child(pack26_controller);pack26_controller.configure(self)
  built=pack26_controller.build(data.map_id)
 else:built=ResearchSite.build(self) if data.type=="expedition" else (TrialGround.build(self) if data.type=="trial" else (LifePlaces.build(self,target) if data.type in ["courtyard","salon"] or target=="gallery" else (ContainerRooms.build(self,target) if data.type=="depot" else (CityMap.build(self) if data.type=="city" else WholeFloor.build(self,data)))))
 if staged:await preload("res://ui/loading_transition.gd").instance(get_tree()).checkpoint(.64,"布置房间、家具与灯光")
 space_bounds=built.get("bounds",Vector2(44,30));room_zones=built.get("zones",[])
 shell.set_meta("supply_anchor",built.get("supply",Vector3(2,0,1.25)))
 if data.type!="pack26":_restore_room_edits()
 overview_size=float(built.get("camera_size",90.0 if data.type=="city" else 42.0))
 var right:=camera.global_basis.x;var up:=camera.global_basis.y
 var projected_width: float=absf(right.x)*space_bounds.x+absf(right.z)*space_bounds.y
 var projected_height: float=absf(up.x)*space_bounds.x+absf(up.z)*space_bounds.y+absf(up.y)*(15.0 if data.type=="city" else 3.0)
 var screen_size: Vector2=get_viewport().get_visible_rect().size
 overview_size=maxf(overview_size,maxf(projected_height,projected_width/(screen_size.x/screen_size.y))+6.0)
 if target=="tidal_cafe":overview_size=19.8
 if data.type=="campus":overview_size=1960.0
 if target=="story_harbor":overview_size=40.0
 if target=="whale_home":overview_size=float(built.camera_size)
 if data.type=="floor":
  var names:=PackedStringArray()
  for zone in room_zones:names.append(str(zone.name))
  locations[target].subtitle=" / ".join(names)
 if data.type=="city":
  for entrance in built.get("entrances",[]):
   _exit(entrance.pos,entrance.target,"进入 · "+str(entrance.name),"entrance",entrance.get("spawn",entrance.pos+Vector3(0,0,1.1)))
   if is_instance_valid(entrance.get("door")):portals[-1]["door"]=entrance.door
  _exit(Vector3(0,0,54),"wuming_campus","校区专线 · 武鸣校区","entrance")
  _sign("校区专线 · 广西医科大学",Vector3(0,2.8,54),28)
  _exit(Vector3(0,0,14),"trial","进入 · 潮汐试炼场","entrance")
  _exit(Vector3(8,0,14),"pack26_foodhall","进入 · 26地图立体新区","entrance")
  _exit(Vector3(0,0,19),"story_quay","进入 · 海风码头样板","entrance")
  _exit(Vector3(-10,0,19),"story_harbor","进入 · 海风码头双层港区","entrance")
  _exit(Vector3(-5,0,19),"tidal_cafe","进入 · 潮汐信笺咖啡馆","entrance")
  _exit(Vector3(-16,0,19),"whale_home","前往 · 大肥鱼之家","entrance")
  _sign("大肥鱼之家 · 海景宅邸",Vector3(-16,2.2,19),28)
 elif data.type=="home3d":
  _exit(built.exit,"city","离开小岛 · 返回鲸落街区","entrance",built.exit+Vector3(0,0,-1.2))
 elif data.type=="campus":
  _exit(built.exit,"city","校区专线 · 返回鲸落街区","entrance",built.spawn)
 elif data.type=="harbor3d":
  _exit(built.exit,"city","回到鲸落街区","entrance")
  _exit(built.sample_exit,"story_quay","回到海风码头样板","entrance")
 elif data.type=="trial":_exit(Vector3(0,0,8.5),"city","返回鲸落港","entrance")
 elif data.type in ["courtyard","salon"]:
  _exit(built.get("exit",Vector3(-17,0,11)),"city","回到鲸落街区","entrance")
  if is_instance_valid(built.get("exit_door")):portals[-1]["door"]=built.exit_door
  if target=="story_quay":_exit(Vector3(8.8,0,8.6),"story_harbor","前往 · 双层港区","entrance")
 elif data.type=="depot":
  # 二层不是「回街区」，而是「下楼」。楼层之间靠楼梯传送 ——
  # 人物高度锁在 y=0，这是工程能表达上下楼的唯一方式。
  if target=="depot_2f":
   _exit(Vector3(-8.4,0,5.0),"depot","下楼 · 港湾补给仓 1F","stairs")
   _stairs_mark(Vector3(-8.4,0,5.2),false)
  else:
   # 回街区的传送点地垫位置用房间自己给的 exit —— 因为「(0,0,5.9) 一定在屋里」
   # 这个假设对多数房间不成立（保险库只到 z=4.5、冷藏间 5.0、查验厅 4.0），
   # 地垫会落到墙外，玩家从里面根本走不到，也就出不去了。
   _exit(built.get("exit",Vector3(0,0,5.9)),"city","回到鲸落街区","entrance")
   if target=="depot":
    _exit(Vector3(7.0,0,-5.6),"depot_2f","上楼 · 2F 环形挑廊","stairs")
    _stairs_mark(Vector3(7.0,0,-5.4),true)
 elif data.type=="floor" and data.building=="restaurant":
  for portal in built.portals:
   _exit(portal.pos,portal.target,portal.label,portal.route,portal.spawn)
   if portal.route=="entrance":
    var nearest_door: Node3D=null;var door_distance:=2.0
    for door in get_tree().get_nodes_in_group("map_interactive_doors"):
     var distance: float=door.global_position.distance_to(portal.pos)
     if distance<door_distance and is_ancestor_of(door):nearest_door=door;door_distance=distance
    if nearest_door:portals[-1]["door"]=nearest_door
 elif data.type not in ["expedition","pack26"]:
  var level: int=data.floor
  var prefix: String=data.prefix
  var lift: Vector3=built.get("exit_anchor",Vector3(17.6,0,0))
  if data.building=="restaurant":
   _exit(lift,"city","走出海蓝餐厅","entrance",built.spawn)
  else:
   _exit(lift,"city","电梯下到街区","elevator")
   _asset("elevator",lift+Vector3(0,0,-1.6))
  if level>1:
   var floor_stair_down: Vector3=built.get("down_anchor",Vector3(-19.8,0,0))
   _exit(floor_stair_down,prefix+"_"+str(level-1),"下楼 · "+str(level-1)+"F","stairs")
   _stairs_mark(floor_stair_down+Vector3(0,0,-1.5),false)
  if level<int(data.floors):
   var floor_stair_up: Vector3=built.get("stairs_anchor",Vector3(20,0,0))
   _exit(floor_stair_up,prefix+"_"+str(level+1),"上楼 · "+str(level+1)+"F","stairs")
   _stairs_mark(floor_stair_up+Vector3(0,0,-1.5),true)
 if staged:await preload("res://ui/loading_transition.gd").instance(get_tree()).checkpoint(.82,"准备入口、楼梯与人物落点")
 player.position=built.get("spawn",Vector3.ZERO)
 # 「回来时从哪道门出现」只对**开放地图**有意义：从公寓出来应该站在公寓门口，
 # 而不是街区正中央。所以这一段现在只在 target=="city" 时生效。
 #
 # 以前它对所有地点都生效，于是从街区进任何一个新房间时，
 # arrival_target 会匹配到「房间里那道通回街区的传送点」，
 # 把人放到**那道地垫的 spawn**（固定 z=7.0）上 —— 而多数房间没那么深
 # （后厨冷藏间 z 只到 5.0、保险库 4.5、海关查验厅 4.0），
 # 结果人落在南墙外面：相机越过 0.85m 矮墙看得见屋里，人却被墙挡着走不进去。
 # 这就是「新图进不去」的真正成因。
 if target=="city":
  var arrival_target:=previous
  if previous.begins_with("apt_"):arrival_target="apt_1"
  elif previous.begins_with("community_"):arrival_target="community_1"
  elif previous.begins_with("inn_"):arrival_target="inn_1"
  elif previous.begins_with("obs_"):arrival_target="obs_1"
  elif previous.begins_with("music_"):arrival_target="music_1"
  for portal in portals:
   if str(portal.target)==arrival_target:
    player.position=portal.spawn;break
 # 楼梯 / 电梯落点：楼层之间上下楼（以及从街区坐电梯上来）时，落点用**那道
 # 楼梯/电梯自己地垫的 spawn**，而不是楼层正中的 (0,0)。
 #
 # 第 6 轮我把「落点选择」限制成只对街区生效，是为了修「从街区进房间时被丢到
 # 南墙外」——那个修法对**房间通回街区的地垫**是对的（地垫的 spawn 在房外/贴墙），
 # 但把楼梯一起关掉了：从 1F 上到 2F 会被丢到楼层正中走廊，离楼梯 19.8m，
 # 玩家得自己找回去（跨帧实测：apt_2→apt_1 / inn_1→inn_2 落点都是 (0,0)、
 # 距最近传送点 17.6m）。楼梯地垫是作者摆在楼层**内部**、贴着楼梯的，用它才对。
 for portal in portals:
  var p_route:=str(portal.get("route"))
  if p_route in ["stairs","elevator"] and str(portal.target)==previous:
   player.position=portal.spawn;break
 player.velocity=Vector3.ZERO;facing="down";facing_accum=Vector2.ZERO;facing_timer=0;_reset_character_gait()
 _queue_collision_recovery(true)
 overview_mode=not HarborPrefs.values.follow;view_size=overview_size if overview_mode else (9.8 if target in ["story_quay","story_harbor"] else (11.6 if target=="tidal_cafe" else (24.0 if data.type=="city" else 22.0)));view_center=Vector3.ZERO if overview_mode else Vector3(player.position.x,0,player.position.z)
 if target=="whale_home":view_size=overview_size if overview_mode else 15.0
 camera_angle=-28 if target=="whale_home" else (-42 if target in ["story_quay","tidal_cafe","story_harbor"] else 28);camera.size=view_size;_camera()
 title.text=str(data.name);title.tooltip_text=str(data.name)
 # Special maps return before neighborhood.physics, so suppress legacy strips at travel time.
 breadcrumb.hide();arrival_note.hide()
 for i in nav_buttons.size():nav_buttons[i].set_pressed_no_signal(target==["apt_2","city","community_1"][i])
 if breadcrumb:breadcrumb.text="鲸落港  /  "+str(data.name)
 if arrival_note:arrival_note.text="同一场景连续行走 · "+("门口点击或按 E 开门、进入建筑" if data.type=="city" else str(room_zones.size())+" 个房间同屏 · 靠近门或设施点击 / 按 E 交互")
 if data.type=="floor" and data.building=="restaurant":arrival_note.text=str(room_zones.size())+" 个空间 · 房间门点击 / 按 E 开合 · 楼梯处换层"+(" · 留意松动的食材架" if target=="restaurant_b1" else "")
 if data.type=="home3d":
  view_center=home_controller.overview_center() if overview_mode else player.position
  home_controller.cutaway=not overview_mode;home_controller.set_layers()
  arrival_note.text="三层海景宅邸 · 沿楼梯步行上下楼 · E 家具交互 · H 楼层切面 · Z 整图总览"
 if data.type=="campus":
  view_center=campus_controller.overview_center() if overview_mode else player.position
  arrival_note.text="校园漫步 · Z 全校总览 · 右侧导览前往各地标"
 if data.type=="harbor3d":
  view_center=harbor_controller.overview_center() if overview_mode else player.position
  harbor_controller.cutaway=not overview_mode;harbor_controller.set_layers()
  arrival_note.text="双层港区 · 沿真实楼梯步行上下层 · H 上层切面 · Z 总览"
 if data.type=="pack26":
  view_center=pack26_controller.overview_center() if overview_mode else player.position
  arrival_note.text="真实楼梯跨层 · E 搜索与开门 · H 隐藏上层 · N 新区背包"
 zone_id="";_update_view_button();_refresh_zone()
 if atmosphere:atmosphere.rebuild()
 _life_supply(target)
 changing=false;_refresh_route()
 if dialogue_controller:dialogue_controller.world_changed()
 if data.type=="pack26" and dialogue_controller and is_instance_valid(dialogue_controller.companion):dialogue_controller.companion.hide()
 if combat_controller:combat_controller.world_changed()
 if expedition_controller:expedition_controller.world_changed()

func _exit(pos: Vector3,target: String,label_text: String,kind: String,spawn: Variant=null) -> void:
 portals.append({"pos":pos,"spawn":pos+Vector3(0,0,1.1) if spawn==null else spawn,"target":target,"label":label_text,"route":kind})
 var b:=_builder(world)
 b.box(Vector3(1.7,.018,1.2),pos+Vector3(0,.023,0),Color("91bfc3"))
 var label:=_sign(label_text,pos+Vector3(0,1.95,-.2),25,Color("294d62"));label.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func _stairs_mark(pos: Vector3,up: bool) -> void:
 var b:=_builder(world)
 for step in 5:
  var h: float=.13*(step+1)
  b.box(Vector3(1.65,h,.33),pos+Vector3(0,h/2,-step*.30),Color("a5bdc5") if up else Color("b8c9ca"))

func _camera() -> void:
 if not camera:return
 var a:=deg_to_rad(camera_angle)
 var target:=view_center+Vector3(0,.72,.04)
 # Keep the same viewing axis; ortho scale does not depend on camera distance.
 # The depth slab follows zoom instead of wasting shadow precision on 300 metres.
 var direction:=Vector3(sin(a)*76,50.8-.72,cos(a)*76-.04).normalized()
 var distance: float=(90.0 if location_id=="wuming_campus" else 24.0)+camera.size*.75
 camera.position=target+direction*distance
 camera.near=maxf(.1,distance-camera.size*.9-(100.0 if location_id=="wuming_campus" else 22.0))
 camera.far=distance+camera.size*.9+(160.0 if location_id=="wuming_campus" else 12.0)
 camera.look_at(target)

func _toggle_view() -> void:
 overview_mode=not overview_mode
 if pack26_controller and pack26_controller.is_active():pack26_controller.floor_cutaway=not overview_mode
 if harbor_controller and harbor_controller.is_active():harbor_controller.cutaway=not overview_mode;harbor_controller.set_layers()
 if home_controller and home_controller.is_active():home_controller.cutaway=not overview_mode;home_controller.set_layers()
 view_size=overview_size if overview_mode else (9.8 if location_id in ["story_quay","story_harbor"] else (11.6 if location_id=="tidal_cafe" else (24.0 if location_id=="city" else 22.0)))
 if location_id=="whale_home":view_size=overview_size if overview_mode else 15.0
 _update_view_button()

func _update_view_button() -> void:
 if view_button:view_button.text="Z 跟随人物" if overview_mode else "Z 整图总览"

func _physics_process(delta: float) -> void:
 if click_navigation:click_navigation.tick(delta)
 if transitioning:return
 if expedition_controller and expedition_controller.blocked():
  player.velocity=Vector3.ZERO;_set_character_pose(false);return
 if combat_controller and combat_controller.in_battle():
  player.velocity=Vector3.ZERO;_set_character_pose(false);return
 if (pause_menu and pause_menu.active) or (character_controller and character_controller.active):
  player.velocity=Vector3.ZERO;_set_character_pose(false);return
 if pack26_controller and pack26_controller.is_active():
  pack26_controller.physics(delta);return
 if harbor_controller and harbor_controller.is_active():
  harbor_controller.physics(delta);return
 if home_controller and home_controller.is_active():
  home_controller.physics(delta);return
 if campus_controller and campus_controller.is_active():
  campus_controller.physics(delta);return
 var stats_before:=player.position
 super._physics_process(delta)
 if not district_ready or transitioning:return
 var desired_center:=Vector3.ZERO if overview_mode else Vector3(player.position.x,0,player.position.z)
 view_center=view_center.lerp(desired_center,(1.0-exp(-delta*7.0)) if HarborPrefs.values.smooth_camera else 1.0)
 camera.size=lerpf(camera.size,view_size,1.0-exp(-delta*8.0));_camera()
 for label in get_tree().get_nodes_in_group("floor_room_labels"):
  label.visible=overview_mode or camera.size>=28.0
 _refresh_zone()
 if character_controller:character_controller.advance(delta,stats_before)
 var free_ui: bool=not panel.visible and not dialog_open and not settings_panel.visible and not loot.blocked() and not map_panel.visible and not editing
 if view_button:view_button.visible=free_ui
 if zone_label:zone_label.visible=free_ui
 if clock_panel:clock_panel.visible=free_ui;clock_label.text=atmosphere.clock_text()
 if free_ui and nearest_portal.is_empty():
  # 身边有东西可以开时，底部提示条改说这件事 —— 否则玩家根本不知道
  # 这些台子/柜子能按 E（interior_pack 那 44 件尤其明显：
  # 模型接进来了、代码能开合，但画面上没有任何提示）。
  var reachable = ContainerRooms.nearest(self, 2.4) if _has_containers() else null
  if reachable != null:
   hint.text = "E 开合 · " + ContainerRooms.describe(reachable) + "  ·  WASD 漫步 · 滚轮缩放"
  else:
   hint.text="右键地面 / 小地图自动寻路 · WASD 接管 · E 交互 · 滚轮缩放"

## 兜底区域名：走到所有 zone 之外时显示的名字。
##
## 原来这里写死「公共走廊」（街区除外），于是**户外**地点也被叫成走廊 ——
## 跨帧实测：潮间带有 738 个可站格落在全部 zone 之外（海堤与滩地之间的滩坡），
## 温室庭院 1593 格、集市小街 1072 格同理。玩家站在沙滩上却看到「当前：公共走廊」。
## 楼层走廊用「公共走廊」是对的（兜底本来就是为它写的），所以按地点类型分：
## 街区给道路、户外给各自的说法、室内仍是走廊。
func _fallback_zone() -> String:
 var named: Dictionary={
  "city":"街区道路","trial":"潮汐试炼场","wuming_campus":"武鸣校区 · 校园道路","whale_home":"大肥鱼之家 · 楼梯与海风步道",
  "tidal_high":"潮间滩地","tidal_low":"潮间滩地",
  "garden":"温室庭院","market":"港口小街","gallery":"白帆艺廊"}
 if named.has(location_id):return str(named[location_id])
 var kind:=str(locations.get(location_id,{}).get("type",""))
 return "公共走廊" if kind in ["floor","city"] else "作业区"

func _refresh_zone() -> void:
 if not district_ready:return
 var found:=_fallback_zone()
 var current:=""
 for zone in room_zones:
  if locations[location_id].type in ["pack26","harbor3d","home3d"] and absf(player.position.y-float(zone.height))>1.0:continue
  var rectangle: Rect2=zone.rect
  var point:=Vector2(player.position.x,player.position.z)
  var polygon: PackedVector2Array=zone.get("polygon",PackedVector2Array())
  if rectangle.has_point(point) and (polygon.is_empty() or Geometry2D.is_point_in_polygon(point,polygon)):
   found=str(zone.name);current=str(zone.id);break
 if zone_label:zone_label.text="当前："+found
 if current!=zone_id:
  zone_id=current
  if current!="":visited[location_id+":"+current]=true

func _unhandled_input(event: InputEvent) -> void:
 if transitioning:
  get_viewport().set_input_as_handled();return
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and click_navigation and click_navigation.available():
  click_navigation.click_screen(event.position);get_viewport().set_input_as_handled();return
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E:
  if map_interactions and map_interactions.try_interact():get_viewport().set_input_as_handled();return
 if harbor_controller and harbor_controller.handle_input(event):get_viewport().set_input_as_handled();return
 if home_controller and home_controller.handle_input(event):get_viewport().set_input_as_handled();return
 if pack26_controller and pack26_controller.handle_input(event):get_viewport().set_input_as_handled();return
 if expedition_controller:
  if expedition_controller.handle_input(event):get_viewport().set_input_as_handled();return
  if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F11 and character_controller.free_world():
   expedition_controller.briefing();get_viewport().set_input_as_handled();return
 if combat_controller and combat_controller.in_battle():return
 if district_ready and not transitioning:
  if event is InputEventKey and event.pressed and not event.echo:
   var modal_open: bool=settings_panel.visible or loot.blocked() or dialog_open or (pause_menu and pause_menu.active) or (character_controller and character_controller.active)
   if event.physical_keycode==KEY_Z and not map_panel.visible and not panel.visible and not modal_open:
    _toggle_view();get_viewport().set_input_as_handled();return
   if event.physical_keycode==KEY_TAB and not map_panel.visible and not modal_open:
    _catalog(not panel.visible);get_viewport().set_input_as_handled();return
   if event.physical_keycode==KEY_B and not map_panel.visible and not modal_open:
    _toggle_decor();get_viewport().set_input_as_handled();return
   if event.physical_keycode in [KEY_F2,KEY_F3,KEY_F4]:
    hint.text="整层结构已保留 · 先在连续空间中探索";get_viewport().set_input_as_handled();return
  if event is InputEventMouseButton and event.pressed and not map_panel.visible and not panel.visible and not settings_panel.visible and not loot.blocked() and not editing:
   if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
    if overview_mode:
     overview_mode=false;view_size=9.8 if location_id in ["story_quay","story_harbor"] else (11.6 if location_id=="tidal_cafe" else (28.0 if location_id=="city" else 26.0))
     if harbor_controller and harbor_controller.is_active():harbor_controller.cutaway=true;harbor_controller.set_layers()
     if home_controller and home_controller.is_active():home_controller.cutaway=true;home_controller.set_layers()
    view_size=clampf(view_size+(-2.0 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 2.0),8.0 if location_id in ["story_quay","tidal_cafe","story_harbor"] else 12.0,overview_size)
    _update_view_button();get_viewport().set_input_as_handled();return
 super._unhandled_input(event)

func _catalog(show: bool) -> void:
 if pack26_controller and pack26_controller.is_active() and show:
  hint.text="新区保留原地图布置；按 M 选择地点，按 E 搜索物资。";return
 super._catalog(show)
 if district_ready and show:
  for button in catalog_buttons:
   var entry: Dictionary=catalog[str(button.get_meta("module_id"))]
   if entry.category in ["floor","structure","opening"] or entry.layer=="wall":
    button.disabled=true;button.tooltip_text="保留楼层通道和门洞，先挑选家具与生活小物。"

func _place(id: String,p: Vector3) -> bool:
 if not district_ready:return super._place(id,p)
 if not catalog.has(id):return false
 var entry: Dictionary=catalog[id]
 if entry.category in ["floor","structure","opening"] or entry.layer=="wall":return false
 if absf(p.x)>space_bounds.x/2-.5 or absf(p.z)>space_bounds.y/2-.5:return false
 var object:=_spawn({"id":id,"pos":[p.x,p.y,p.z],"angle":placement_angle})
 var footprints: Array=[];_footprints(object,footprints)
 if footprints.is_empty():footprints.append(Rect2(Vector2(p.x-.12,p.z-.12),Vector2(.24,.24)))
 var feet:=Rect2(Vector2(player.position.x-FOOT_RADIUS,player.position.z-FOOT_RADIUS),Vector2.ONE*FOOT_RADIUS*2)
 var allowed:=not _placement_overlaps_character(object)
 for footprint: Rect2 in footprints:
  if footprint.intersects(feet):allowed=false;break
  # **门洞/出入口一律不许压** —— 这条原来只写在街区那个分支里，
  # 于是房间里的出口地垫完全没有保护：12 个仓储房（补给仓/冷藏间/保险库…）
  # 的玩家能把柜子直接摆在自己的出口地垫上，把出门的路堵掉。
  # 楼层靠 `absf(p.z)<2.3` 保护中间走廊、街区靠这条保护 23 个门，
  # 只有 depot 类房间两头都没有。现在提到公共位置，所有地点一致。
  for entrance in portals:
   var access: Rect2=Rect2(Vector2(entrance.pos.x-1.3,entrance.pos.z-1.3),Vector2(2.6,2.6))
   if footprint.intersects(access):allowed=false;break
  if not allowed:break
  if location_id!="city":
   var in_room:=false
   for zone in room_zones:
    var room_rect: Rect2=zone.rect
    var polygon: PackedVector2Array=zone.get("polygon",PackedVector2Array())
    if not room_rect.grow(-.22).encloses(footprint) or not SpaceShape.contains_rect(polygon,footprint,.12):continue
    var blocks_access:=false
    for aisle: Rect2 in zone.get("door_clear",[])+zone.get("paths",[]):
     if footprint.intersects(aisle):blocks_access=true;break
    if not blocks_access:in_room=true;break
   if not in_room:allowed=false;break
 if not allowed:
  items.erase(object);object.free();hint.text="给门口和走廊留出通道，再往房间里面摆一点。";return false
 return true

func _footprints(node: Node,result: Array) -> void:
 if node is CollisionShape3D and not node.disabled and node.shape:
  var extent:=Vector3.ZERO
  if node.shape is BoxShape3D:extent=node.shape.size/2
  elif node.shape is CylinderShape3D:extent=Vector3(node.shape.radius,node.shape.height/2,node.shape.radius)
  elif node.shape is CapsuleShape3D:extent=Vector3(node.shape.radius,node.shape.height/2,node.shape.radius)
  if extent!=Vector3.ZERO:
   var low_y: float=node.global_position.y-extent.y
   var high_y: float=node.global_position.y+extent.y
   if low_y<FOOT_HEIGHT+.01 and high_y>0:
    var first:=true;var rect:=Rect2()
    for x in [-extent.x,extent.x]:
     for z in [-extent.z,extent.z]:
      var point: Vector3=node.to_global(Vector3(x,0,z));var pos:=Vector2(point.x,point.z)
      if first:rect=Rect2(pos,Vector2.ZERO);first=false
      else:rect=rect.expand(pos)
    result.append(rect)
 for child in node.get_children():_footprints(child,result)

func _remember_room() -> void:
 if locations[location_id].type=="pack26":return
 if not locations.has(location_id):return
 var records: Array=[]
 for item in items:
  if item.has_meta("placement"):records.append(item.get_meta("placement"))
 var previous: Dictionary=room_edits.get(location_id,{})
 room_edits[location_id]={"items":records,"layout":shell.get_meta("layout_revision","legacy")}
 if previous.has("legacy_layout_items"):room_edits[location_id]["legacy_layout_items"]=previous.legacy_layout_items

func _restore_room_edits() -> void:
 if not room_edits.has(location_id):return
 if shell.has_meta("layout_revision") and room_edits[location_id].get("layout","")!=shell.get_meta("layout_revision"):
  # Keep the old records recoverable, but never restore obsolete hallway
  # coordinates over the new walls. Existing default items use new positions.
  var old: Array=room_edits[location_id].get("items",[]).duplicate(true)
  var available: Dictionary={}
  var structure: Array=[];_footprints(shell,structure)
  for obstacle: PackedVector2Array in shell.get_meta("outdoor_obstacles",[]):structure.append(preload("res://district/packed_floor.gd")._rect(obstacle))
  for child in world.get_children():
   if child!=player:_footprints(child,structure)
  for item in items:available[item.module_id]=int(available.get(item.module_id,0))+1
  var migrated: Array=[]
  for entry in old:
   if not catalog.has(entry.id):continue
   if int(available.get(entry.id,0))>0:available[entry.id]-=1;continue
   var origin:=Vector2(float(entry.pos[0]),float(entry.pos[2]))
   var ordered: Array=room_zones.duplicate()
   ordered.sort_custom(func(a,b):return origin.distance_squared_to(Vector2(a.center.x,a.center.z))<origin.distance_squared_to(Vector2(b.center.x,b.center.z)))
   for zone in ordered:
    if location_id=="whale_home" and absf(float(zone.height)-float(entry.pos[1]))>.6:continue
    var footprint: Rect2=zone.rect
    var fitted:=false
    for point in SpaceShape.fitted_candidates(zone.center,zone.rect.grow(-.65)):
     var candidate: Dictionary=entry.duplicate(true);candidate.pos=[point.x,float(entry.pos[1]),point.z]
     var object=_spawn(candidate);footprint=WholeFloor._footprint(object)
     var blocked: bool=not SpaceShape.contains_rect(zone.polygon,footprint,.65)
     if location_id=="whale_home":
      blocked=blocked or not _home_placement_supported(object,footprint)
     else:
      for occupied: Rect2 in structure:
       if occupied.grow(.42).intersects(footprint):blocked=true;break
     for aisle: Rect2 in zone.door_clear+zone.paths:
      if footprint.intersects(aisle):blocked=true;break
     for existing in items:
      if existing==object or absf(existing.position.y-object.position.y)>.6:continue
      var occupied: Rect2=WholeFloor._footprint(existing)
      if occupied.has_area() and occupied.grow(.85).intersects(footprint):blocked=true;break
     if blocked:items.erase(object);object.free();continue
     migrated.append(candidate);fitted=true;break
    if fitted:break
  var records: Array=[]
  for item in items:
   if item.has_meta("placement"):records.append(item.get_meta("placement"))
  var history: Array=room_edits[location_id].get("legacy_layout_items",[]).duplicate(true)
  for record in old:
   if not record in history:history.append(record)
  room_edits[location_id]={"items":records,"layout":shell.get_meta("layout_revision"),"legacy_layout_items":history}
  return
 for item in items:item.free()
 items.clear()
 for entry in room_edits[location_id].items:
  if catalog.has(entry.id):_spawn(entry)

func _home_placement_supported(object: Node3D,footprint: Rect2) -> bool:
 var space=player.get_world_3d().direct_space_state
 var h: float=object.position.y
 for p: Vector2 in [footprint.position,Vector2(footprint.end.x,footprint.position.y),footprint.end,Vector2(footprint.position.x,footprint.end.y),footprint.get_center()]:
  var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,h+.35,p.y),Vector3(p.x,h-.45,p.y),2)
  var hit: Dictionary=space.intersect_ray(query)
  if hit.is_empty() or absf(hit.position.y-h)>.15:return false
 var shape:=BoxShape3D.new();shape.size=Vector3(footprint.size.x,.9,footprint.size.y)
 var test:=PhysicsShapeQueryParameters3D.new();test.shape=shape;test.collision_mask=1
 test.transform=Transform3D(Basis.IDENTITY,Vector3(footprint.get_center().x,h+.55,footprint.get_center().y))
 var excluded: Array[RID]=[]
 for child in object.find_children("*","CollisionObject3D",true,false):excluded.append(child.get_rid())
 test.exclude=excluded
 return space.intersect_shape(test,1).is_empty()

func _save() -> bool:
 if expedition_controller and (expedition_controller.is_active() or location_id=="research"):return expedition_controller.checkpoint_save()
 if not district_ready:return false
 if character_controller and not loot.save_state():hint.text="人物状态和背包尚未保存，请重试。";return false
 if pack26_controller and pack26_controller.is_active():pack26_controller.save()
 _remember_room()
 var path: String=HarborPrefs.world_save_path
 var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify({"version":6,"floor_layout":"packed_rooms_v2","layout_revision":shell.get_meta("layout_revision","legacy"),"clock":atmosphere.save_clock(),"location":location_id,"position":[player.position.x,player.position.z],"position_y":player.position.y,"visited":visited,"favorites":favorites,"route":route_destination,"overview":overview_mode,"zoom":view_size,"rooms":room_edits}))
 file.flush();file.close()
 if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))!=OK:return false
 hint.text="已保存大地图位置、所在楼层和导览收藏。";return true

func _restore() -> bool:
 if not FileAccess.file_exists(HarborPrefs.world_save_path):return false
 var data=JSON.parse_string(FileAccess.get_file_as_string(HarborPrefs.world_save_path))
 if not data is Dictionary or not locations.has(data.get("location","")):return false
 visited=data.get("visited",{});favorites=data.get("favorites",{});route_destination=str(data.get("route",""))
 room_edits=data.get("rooms",{});loading_save=true
 _travel(str(data.location))
 loading_save=false
 if data.get("position") is Array and data.position.size()==2:
  var restored:=Vector2(float(data.position[0]),float(data.position[1]))
  var on_floor: bool=not shell.has_meta("layout_revision")
  if not on_floor and data.get("layout_revision",data.get("floor_layout",""))==shell.get_meta("layout_revision"):
   for zone in room_zones:
    if Geometry2D.is_point_in_polygon(restored,zone.polygon):on_floor=true;break
  if on_floor:player.position=Vector3(restored.x,float(data.get("position_y",0)) if locations[location_id].type in ["pack26","harbor3d","home3d","campus"] else 0,restored.y)
 _queue_collision_recovery()
 overview_mode=bool(data.get("overview",true));view_size=clampf(float(data.get("zoom",overview_size)),8.0 if location_id in ["story_quay","tidal_cafe","story_harbor"] else 12.0,overview_size);_update_view_button()
 if pack26_controller and pack26_controller.is_active():pack26_controller.floor_cutaway=not overview_mode
 if harbor_controller and harbor_controller.is_active():harbor_controller.cutaway=not overview_mode;harbor_controller.set_layers()
 if home_controller and home_controller.is_active():home_controller.cutaway=not overview_mode;home_controller.set_layers()
 atmosphere.restore_clock(data.get("clock",{}))
 return true

func _life_supply(place: String) -> void:
 if place=="whale_home":
  loot.chests.clear();loot.nearby=null
  for node in world.get_children():
   if node.get_meta("home_storage",false):loot.chests.append(node)
  return
 if place in ["tidal_cafe","story_harbor","wuming_campus"]:loot.chests.clear();loot.nearby=null;return
 if locations[place].type=="pack26":loot.chests.clear();loot.nearby=null;return
 if place=="research":loot.chests.clear();loot.nearby=null;return
 if place in ["restaurant_2","restaurant_b1"]:
  loot.nearby=null;loot.chests.clear();load("res://district/restaurant_storeys.gd").attach_loot(self);return
 # 新地点（type "depot"，见 district/container_rooms.gd）里已经摆了真实的容器，
 # 不要再放一只通用补给箱：这个函数头一句就是 chests.clear()，
 # 而它在 _travel 里的调用点在 ContainerRooms.build 之后，正好把登记好的全抹掉。
 # （和 loot_controller.room_changed 是同一个坑，那里也加了同样的守卫。）
 if locations.has(place) and str(locations[place].get("type","")) in ["depot","city"]:
  loot.nearby=null;return
 loot.nearby=null;loot.chests.clear()
 var id: String="bedroom_supply"
 if place in ["city","market"]:id="market_supply"
 elif place=="garden":id="garden_supply"
 elif place=="gallery" or place.begins_with("music_"):id="gallery_supply"
 elif place.begins_with("obs_"):id="studio_supply"
 elif place.begins_with("community"):id="cafe_supply"
 var crate=loot.CHEST.instantiate();crate.container_id=id;crate.display_name={"garden_supply":"青柠花房 · 园艺礼物","market_supply":"海风集市 · 旅途补给","gallery_supply":"白帆艺廊 · 创作礼物","bedroom_supply":"云湾公寓 · 生活补给","cafe_supply":"社区馆 · 阅读漂流箱"}.get(id,"鲸落港补给箱")
 crate.note="今天也可以收好一点小惊喜。

物品数量有限，取走后会自动保存。补给可以使用，便签和收藏会留下。

花房、集市与艺廊还有不同的物品，打开 M 导览去看看吧。"
 crate.position=Vector3(2.4,0,7) if place=="city" else (shell.get_meta("supply_anchor",Vector3(2,0,1.25)) if locations[place].type=="courtyard" or place=="restaurant_1" else Vector3(2,0,1.25))
 if place=="restaurant_1":crate.display_name="海蓝餐厅 · 食材补给箱"
 world.add_child(crate);loot.chests.append(crate)
