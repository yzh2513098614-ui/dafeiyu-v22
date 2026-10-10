extends CharacterBody3D
## Capsule radius 0.28 m, collision at feet; original whale mesh used as a preview character.
@export var move_speed: float = 4.4
var paused = false
var automated = false
var route = PackedVector3Array()
var route_index = 0
var target_reached = true
var walk_time = 0.0
func _ready() -> void:
    collision_layer = 4
    collision_mask = 3
    var shape = CollisionShape3D.new()
    var capsule = CapsuleShape3D.new()
    capsule.radius = .28
    capsule.height = 1.30
    shape.shape = capsule
    shape.position.y = .65
    add_child(shape)
    var mesh = load("res://world_pack26/interior_pack/assets/models/decor_10.glb").instantiate()
    mesh.name = "WhaleVisual"
    mesh.scale = Vector3.ONE * 1.15
    mesh.position.y = .48
    add_child(mesh)
    floor_snap_length = .15
func move_to(destination: Vector3) -> void:
    automated = true
    target_reached = false
    route_index = 0
    route = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, destination, true)
    if route.is_empty():
        target_reached = true
func _physics_process(delta: float) -> void:
    var direction = Vector3.ZERO
    if not paused:
        if automated and not target_reached:
            while route_index < route.size() and Vector2(route[route_index].x-global_position.x,route[route_index].z-global_position.z).length() < .16:
                route_index += 1
            if route_index < route.size():
                direction = Vector3(route[route_index].x-global_position.x,0,route[route_index].z-global_position.z).normalized()
            else:
                target_reached = true
        elif not automated:
            var input = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
            direction = Vector3(input.x,0,input.y).normalized()
    velocity.x = direction.x * move_speed
    velocity.z = direction.z * move_speed
    if not is_on_floor():
        velocity.y -= 18 * delta
    else:
        velocity.y = 0
    move_and_slide()
    walk_time += delta
    $WhaleVisual.position.y = .48 + sin(walk_time * (9 if direction.length()>.1 else 2.5)) * .055
    if direction.length()>.1:
        $WhaleVisual.rotation.y = lerp_angle($WhaleVisual.rotation.y,atan2(direction.x,direction.z),delta*12)
