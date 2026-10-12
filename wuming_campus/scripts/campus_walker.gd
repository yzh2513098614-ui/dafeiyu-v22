extends CharacterBody3D

const WALK_SPEED: float = 2.4

func _physics_process(delta: float) -> void:
	var input:=Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):input.y-=1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):input.y+=1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):input.x-=1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):input.x+=1
	input=input.normalized()
	var camera: Camera3D=get_viewport().get_camera_3d()
	var right:=Vector3(camera.global_basis.x.x,0,camera.global_basis.x.z).normalized()
	var down:=Vector3(camera.global_basis.z.x,0,camera.global_basis.z.z).normalized()
	var direction: Vector3=right*input.x+down*input.y
	velocity.x=direction.x*WALK_SPEED
	velocity.z=direction.z*WALK_SPEED
	if not is_on_floor():velocity.y-=9.8*delta
	else:velocity.y=0
	move_and_slide()
