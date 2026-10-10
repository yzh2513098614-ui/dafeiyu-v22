extends Node3D
## The PreviewRig is for F6 only; instances in another game remove it.
var time:=0.0
var jets: Array[Node]=[]
var rides: Array[Node]=[]
func _ready() -> void:
 if get_parent()!=get_tree().root:
  var rig:=get_node_or_null("PreviewRig")
  if rig:rig.free()
 jets=find_children("WaterJets","Node3D",true,false)
 rides=find_children("RideBody","Node3D",true,false)
func _process(delta: float) -> void:
 time+=delta
 for node in jets:node.position.y=.40+sin(time*2.5)*.025
 for node in rides:node.rotation.x=sin(time*1.7)*.055
