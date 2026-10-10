@tool
extends "res://world_pack26/interior_pack/scripts/item_3d.gd"
## Original Library stair meshes stay intact. A continuous slope collider below
## them supports capsule movement and navigation instead of high stair risers.
func _ready() -> void:
    super._ready()
    $Body.collision_layer = 0
    $Body.collision_mask = 0
