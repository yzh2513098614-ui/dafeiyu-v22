extends Node
## Incremental physical-ground A*: shares the actor's collision and support rules.
const STEP := 0.6
const LIMIT := 18000
var game: Node
var path: Array[Vector3] = []
var destination := Vector3.ZERO
var searching := false
var status := "右键地面行走"
var heap: Array = []
var points := {}
var costs := {}
var parents := {}
var closed := {}
var samples := {}
var origin := Vector3.ZERO
var grounded := false
var previous := Vector3.ZERO
var stuck := 0.0
var driving := false
var marker: MeshInstance3D

func configure(owner_game: Node) -> void:
	game = owner_game
	marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.27; ring.outer_radius = 0.34
	marker.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("65f5d0")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = material
	game.add_child(marker); marker.hide()

func cancel() -> void:
	path.clear(); searching = false; heap.clear()
	if driving: game.movement = Vector2.ZERO
	driving = false
	marker.hide(); stuck = 0.0
	status = "右键地面行走"

func available() -> bool:
	return game.character_controller != null and game.character_controller.free_world()

func click_screen(screen: Vector2) -> bool:
	if not available(): return false
	var from: Vector3 = game.camera.project_ray_origin(screen)
	var ray: Vector3 = game.camera.project_ray_normal(screen)
	var target: Variant
	if game.player.motion_mode == CharacterBody3D.MOTION_MODE_GROUNDED:
		var query := PhysicsRayQueryParameters3D.create(from, from + ray * 600.0, 3, [game.player.get_rid(), game.silhouette_body.get_rid()])
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.65: return false
		target = hit.position
	else:
		target = Plane(Vector3.UP, game.player.position.y).intersects_ray(from, ray)
	if target == null: return false
	return request(target)

func request(target: Vector3) -> bool:
	if not available(): return false
	cancel()
	grounded = game.player.motion_mode == CharacterBody3D.MOTION_MODE_GROUNDED
	origin = game.player.global_position; destination = target
	if not game._collision_point_allowed(destination, grounded):
		var found := false
		for radius in [0.3, 0.6, 0.9, 1.2]:
			for i in 16:
				var candidate: Vector3 = target + Vector3(cos(i * TAU / 16.0), 0, sin(i * TAU / 16.0)) * radius
				if game._collision_point_allowed(candidate, grounded):
					destination = candidate; found = true; break
			if found: break
		if not found: status = "目的地不可通行"; return false
	marker.position = destination + Vector3.UP * 0.045; marker.show()
	previous = origin
	if _edge(origin, destination):
		path.assign([destination]); status = "自动行走中"; return true
	heap.clear(); points.clear(); costs.clear(); parents.clear(); closed.clear(); samples.clear()
	var key := _key(origin)
	points[key] = origin; costs[key] = 0.0
	_push(key, origin.distance_to(destination))
	searching = true; status = "正在规划路线…"
	return true

func tick(delta: float) -> void:
	if not available(): cancel(); return
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ESCAPE]:
		if Input.is_physical_key_pressed(key): cancel(); return
	if searching: _search()
	if path.is_empty(): return
	game.movement = Vector2.ZERO
	var here: Vector3 = game.player.global_position
	while not path.is_empty() and Vector2(here.x, here.z).distance_to(Vector2(path[0].x, path[0].z)) < 0.13 and absf(here.y - path[0].y) < 0.5:
		path.pop_front()
	if path.is_empty(): cancel(); status = "已到达"; return
	if here.distance_to(previous) < 0.003: stuck += delta
	else: stuck = 0.0
	previous = here
	if stuck > 0.65:
		cancel(); status = "通道受阻，请重新指定目的地"; return
	var travel := path[0] - here; travel.y = 0
	game.movement = game._character_screen_travel(travel).normalized()
	driving = true

func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi((p.x - origin.x) / STEP), roundi(p.y / 0.25), roundi((p.z - origin.z) / STEP))

func _surface(x: int, z: int, height: float) -> Variant:
	var cache_key := Vector3i(x, roundi(height / 0.25), z)
	if samples.has(cache_key): return samples[cache_key]
	var p := Vector3(origin.x + x * STEP, height, origin.z + z * STEP)
	var result: Variant = null
	if grounded:
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p - Vector3.UP * 0.65, 3, [game.player.get_rid(), game.silhouette_body.get_rid()])
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y < 0.65:
			samples[cache_key] = null; return null
		p.y = hit.position.y
	if game._collision_point_allowed(p, grounded): result = p
	samples[cache_key] = result
	return result

func _edge(a: Vector3, b: Vector3) -> bool:
	var count := maxi(1, ceili(a.distance_to(b) / 0.18))
	for i in range(1, count + 1):
		if not game._collision_point_allowed(a.lerp(b, float(i) / count), grounded): return false
	return true

func _search() -> void:
	var started := Time.get_ticks_usec()
	while not heap.is_empty() and Time.get_ticks_usec() - started < 5000:
		var key: Vector3i = _pop()
		if closed.has(key): continue
		closed[key] = true
		var p: Vector3 = points[key]
		if p.distance_to(destination) < STEP * 1.5 and _edge(p, destination):
			path.assign([destination])
			while parents.has(key):
				path.push_front(points[key]); key = parents[key]
			searching = false; status = "自动行走中"; return
		if closed.size() >= LIMIT: break
		for x in [-1, 0, 1]:
			for z in [-1, 0, 1]:
				if x == 0 and z == 0: continue
				var next: Variant = _surface(key.x + x, key.z + z, p.y)
				if next == null: continue
				var next_key := _key(next)
				if closed.has(next_key) or not _edge(p, next): continue
				var cost: float = costs[key] + p.distance_to(next)
				if cost >= float(costs.get(next_key, INF)): continue
				points[next_key] = next; costs[next_key] = cost; parents[next_key] = key
				_push(next_key, cost + next.distance_to(destination))
	if heap.is_empty() or closed.size() >= LIMIT:
		cancel(); status = "没有可通行路线"

func _push(key: Vector3i, score: float) -> void:
	heap.append([key, score])
	var i := heap.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if heap[parent][1] <= score: break
		var swap: Array = heap[parent]; heap[parent] = heap[i]; heap[i] = swap; i = parent

func _pop() -> Vector3i:
	var key: Vector3i = heap[0][0]
	var last: Array = heap.pop_back()
	if heap.is_empty(): return key
	heap[0] = last
	var i := 0
	while i * 2 + 1 < heap.size():
		var child := i * 2 + 1
		if child + 1 < heap.size() and heap[child + 1][1] < heap[child][1]: child += 1
		if heap[i][1] <= heap[child][1]: break
		var swap: Array = heap[i]; heap[i] = heap[child]; heap[child] = swap; i = child
	return key
