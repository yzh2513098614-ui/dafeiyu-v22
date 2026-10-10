extends Node3D
## A native 3D exhibit. The reusable Library whale floats above its projector.
var elapsed: float = 0.0
func _process(delta: float) -> void:
    elapsed += delta
    $Whale.position.y = 1.36 + sin(elapsed * 1.4) * 0.12
    $Whale.rotation.y = sin(elapsed * 0.4) * 0.35
    $Projection.scale.x = 1.0 + sin(elapsed * 2.2) * 0.035
    $Projection.scale.z = $Projection.scale.x
