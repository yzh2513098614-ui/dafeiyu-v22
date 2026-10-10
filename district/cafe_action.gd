extends Node3D
## Scene-local actions share the existing proximity card and never consume items.
var game
var kind:=""
var opened:=false
var elapsed:=0.0
var brewing:=false
var motion: Tween
var parts: Array[Node3D]=[]
var lid: Node3D
var letter: Node3D
var lever: Node3D
var cup: Node3D
var steam: Array[MeshInstance3D]=[]
var title:=""
var state_key:=""

func configure(owner_game,action: String,label: String) -> void:
 game=owner_game;kind=action;title=label;state_key="tidal_cafe:"+action
 set_meta("interaction_title",title)
 set_meta("interaction_height",2.10 if kind=="letter" else 1.80)
 if kind!="coffee":opened=bool(game.visited.get(state_key,false))

func has_action() -> bool:return true

func map_action() -> String:
 match kind:
  "coffee":return "正在冲泡…" if brewing else "冲一杯咖啡"
  "letter":return "收好信笺" if opened else "读一封漂流信"
  "curtain":return "放下遮阳帘" if opened else "拉起遮阳帘"
 return "交互"

func map_detail() -> String:
 if kind=="letter" and opened:return "“慢一点，海风会替你翻到下一页。”"
 if kind=="coffee":return "模型演出 · 不消耗背包物品"
 if kind=="curtain":return "百叶帘收拢后，窗湾会更明亮"
 return "点击按钮或按 E · 离开后自动收起"

func interact() -> void:
 if kind=="coffee":
  if brewing:return
  brewing=true;set_meta("map_busy",true);elapsed=0.0;game.hint.text="磨豆、注水…这一杯留给今天的自己。"
  if motion and motion.is_valid():motion.kill()
  motion=create_tween();motion.tween_property(lever,"rotation:z",-.48,.22);motion.tween_property(lever,"rotation:z",0.0,.30)
  game.get_node("/root/SfxDirector").play("chest_open",-14.0)
  return
 opened=not opened;game.visited[state_key]=opened
 if motion and motion.is_valid():motion.kill()
 motion=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
 if kind=="letter":
  motion.tween_property(lid,"rotation:x",deg_to_rad(-108.0) if opened else 0.0,.65)
  motion.tween_property(letter,"position:y",1.16 if opened else .59,.55)
  motion.tween_property(letter,"rotation:x",-.50 if opened else PI*.5,.55)
  game.hint.text="漂流信：“慢一点，海风会替你把今天翻到下一页。”" if opened else "信笺已收好，留给下一位来客。"
 elif kind=="curtain":
  for part in parts:motion.tween_property(part,"scale:y",.15 if opened else 1.0,.85)
  game.hint.text="窗湾遮阳帘已拉起。" if opened else "窗湾遮阳帘已放下。"
  motion.finished.connect(func():if is_instance_valid(game.atmosphere):game.atmosphere.set_time(game.atmosphere.hour))
 if game.life_booted:game._save()

func restore_pose() -> void:
 if kind=="letter":
  lid.rotation.x=deg_to_rad(-108.0) if opened else 0.0
  letter.position.y=1.16 if opened else .59;letter.rotation.x=-.50 if opened else PI*.5
 elif kind=="curtain":
  for part in parts:part.scale.y=.15 if opened else 1.0

func _process(delta: float) -> void:
 if kind!="coffee":return
 if not brewing:
  for particle in steam:particle.hide()
  return
 elapsed+=delta
 for i in steam.size():
  var particle: MeshInstance3D=steam[i];particle.show()
  var phase: float=fposmod(elapsed*.6+float(i)*.22,1.0)
  particle.position=Vector3(.25+sin(elapsed*2.+i)*.06,.91+phase*.63,.42)
  particle.scale=Vector3(.105,.17,.105)*(.65+phase*.8)
  particle.material_override.albedo_color.a=sin(phase*PI)*.25
 cup.scale.y=lerpf(cup.scale.y,1.0,delta*3.0)
 if elapsed>3.5:
  brewing=false;set_meta("map_busy",false);game.hint.text="咖啡好了。可以再冲一杯，或去窗边坐坐。"
