extends Control
const WhaleStyle=preload("res://ui/whale_skin.gd")
const PLACES: Array=[
 ["city","漫步鲸落港","错位街巷 · 多层建筑"],
 ["apt_2","回到云湾公寓","大小房间 · 连通走廊"],
 ["community_1","去潮汐社区馆","咖啡阅读 · 共享生活"],
 ["inn_1","到海风旅舍","来往旅人 · 多层客房"],
 ["garden","逛青柠花房","温室花圃 · 树下茶庭"],
 ["market","去海风集市","错位摊位 · 港口小街"],
 ["obs_1","看潮汐观测站","实验标本 · 三层星空"],
 ["music_1","听蓝鲸音乐馆","小剧场 · 录音与合奏"]]
var content: Panel
var page:="journey"
var cards: Dictionary={}
var feedback: Label

func _ready() -> void:
 var font:=FontVariation.new();font.base_font=load("res://assets/NotoSansSC.ttf")
 theme=WhaleStyle.theme(font)
 var bg:=TextureRect.new();bg.texture=load("res://assets/v18/harbor_title.png") if ResourceLoader.exists("res://assets/v18/harbor_title.png") else load("res://assets/modern/city_panorama.png")
 bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
 var wash:=ColorRect.new();wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);wash.color=Color(.91,.95,.95,.16);wash.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(wash)
 WhaleStyle.label(self,"大肥鱼",Vector2(82,52),Vector2(530,85),65)
 WhaleStyle.label(self,"鲸落港的慢生活",Vector2(85,145),Vector2(530,38),27,WhaleStyle.MUTED)
 content=WhaleStyle.panel(self,Vector2(72,218),Vector2(606,782))
 _render()
 var tag:=WhaleStyle.panel(self,Vector2(849,918),Vector2(508,82),"paper")
 WhaleStyle.label(tag,"像素立绘 · 鲸落港物语",Vector2(22,11),Vector2(464,29),23)
 WhaleStyle.label(tag,"选择出发点，和大肥鱼慢慢聊一会儿。",Vector2(22,44),Vector2(464,27),18,WhaleStyle.MUTED)

func _button(parent: Node,text: String,pos: Vector2,size: Vector2,action: Callable) -> Button:
 var b:=Button.new();b.text=text;b.position=pos;b.size=size;b.pressed.connect(action);parent.add_child(b);return b

func _render() -> void:
 for child in content.get_children():child.free()
 cards.clear()
 for i in 2:
  var id: String=["journey","settings"][i]
  var b:=_button(content,["出发选择","画面设置"][i],Vector2(26+i*277,24),Vector2(265,53),func():page=id;_render())
  WhaleStyle.card_button(b,page==id)
 if page=="settings":_settings();return
 WhaleStyle.label(content,"今天，想去哪里？",Vector2(28,105),Vector2(546,47),29)
 WhaleStyle.label(content,"选择仅改变出发地点，已有背包会保留。",Vector2(29,153),Vector2(547,43),18,WhaleStyle.MUTED)
 for i in PLACES.size():
  var place: Array=PLACES[i]
  var b:=_button(content,"",Vector2(26+(i%2)*283,217+(i/2)*94),Vector2(271,83),func():HarborPrefs.starting_place=place[0];HarborPrefs.save();_render())
  WhaleStyle.card_button(b,HarborPrefs.starting_place==place[0]);cards[place[0]]=b
  WhaleStyle.icon(b,["star","heart","leaf","chest"][i] if i<2 else ("heart" if i==2 else "chest"),Vector2(12,24),Vector2(32,32))
  WhaleStyle.label(b,place[1],Vector2(54,10),Vector2(207,31),19)
  WhaleStyle.label(b,place[2],Vector2(54,45),Vector2(207,27),14,WhaleStyle.MUTED)
 var start:=_button(content,"开始漫步  →",Vector2(26,625),Vector2(554,61),func():_start(false));WhaleStyle.card_button(start,true)
 var resume:=_button(content,"继续上次旅程",Vector2(26,704),Vector2(365,49),func():_start(true))
 resume.disabled=not FileAccess.file_exists(HarborPrefs.world_save_path)
 _button(content,"退出",Vector2(410,704),Vector2(170,49),func():get_tree().quit())

func _settings() -> void:
 WhaleStyle.label(content,"让画面舒服一点",Vector2(29,108),Vector2(542,44),29)
 var options: Array=[["fullscreen","全屏显示","适合专心漫步"],["shadows","柔和阴影","建筑与物品更有层次"],["effects","光影细节","墙角阴影与氛围微光"],["dusk","暮色暖光","蓝色街区与暖色窗口"],["follow","跟随人物","开场镜头靠近出发点"],["smooth_camera","柔顺镜头","移动时缓慢跟随"],["day_cycle","昼夜循环","日光随旅程缓缓变化"]]
 for i in options.size():
  var opt: Array=options[i]
  var b:=_button(content,"",Vector2(26,177+i*69),Vector2(554,62),func():HarborPrefs.values[opt[0]]=not HarborPrefs.values[opt[0]];HarborPrefs.apply_window();var result:=HarborPrefs.save();_render();feedback.text="设置已保存" if result==OK else "设置保存失败，请检查目录权限")
  WhaleStyle.card_button(b,bool(HarborPrefs.values[opt[0]]))
  WhaleStyle.label(b,opt[1],Vector2(17,7),Vector2(390,28),21)
  WhaleStyle.label(b,opt[2],Vector2(17,37),Vector2(402,24),16,WhaleStyle.MUTED)
  WhaleStyle.label(b,"开启" if HarborPrefs.values[opt[0]] else "关闭",Vector2(456,21),Vector2(80,30),19)
 feedback=WhaleStyle.label(content,"一天默认 12 分钟，可在游戏设置中调整。",Vector2(29,686),Vector2(542,43),18,WhaleStyle.MUTED)

func _start(resume: bool) -> void:
 HarborPrefs.continue_game=resume
 HarborPrefs.save()
 get_tree().change_scene_to_file("res://district/continuous_world.tscn")
