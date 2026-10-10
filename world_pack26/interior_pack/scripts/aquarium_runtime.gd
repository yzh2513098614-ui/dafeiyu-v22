extends Node3D
## Small original procedural fish animate inside an editable native 3D display.
var time := 0.0
var swimmers: Array[Node3D] = []
var origins: Array[Vector3] = []
func _ready() -> void:
    for node in $Fish.get_children():
        swimmers.append(node)
        origins.append(node.position)
func _process(delta: float) -> void:
    time += delta
    for i in swimmers.size():
        var phase := time * (0.55 + i * 0.08) + i * 1.35
        swimmers[i].position = origins[i] + Vector3(sin(phase) * .24, cos(phase * 1.3) * .045, sin(phase * .8) * .035)
        swimmers[i].rotation.y = sin(phase) * .15
