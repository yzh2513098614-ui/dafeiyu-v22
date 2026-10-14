extends SceneTree
## Inspect rendered triangles and native physics at the garden/dock junctions.
const Safety = preload("res://character/collision_safety.gd")
const Ground = preload("res://assets/whale_home/garden_ground.gd")
const OUTPUT = "res://预览/室外穿模修复_20261015/"
var game
var checked := 0
var failed := 0
var route_samples := 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	call_deferred("review")

func check(value: bool, label: String) -> void:
	checked += 1
	if value:
		print("SURFACE PASS: ", label)
	else:
		failed += 1
		push_error("SURFACE FAIL: " + label)

func area(polygon: PackedVector2Array) -> float:
	var result := 0.0
	for i in polygon.size():
		result += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(result) * 0.5

func bounds(polygon: PackedVector2Array) -> Rect2:
	var result := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: result = result.expand(point)
	return result

func horizontal_triangles(parent: Node3D, height: float) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for node: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
		if not node.is_visible_in_tree() or not node.mesh: continue
		var faces := node.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var a: Vector3 = node.global_transform * faces[i]
			var b: Vector3 = node.global_transform * faces[i + 1]
			var c: Vector3 = node.global_transform * faces[i + 2]
			if absf(a.y - height) > 0.00001 or absf(b.y - height) > 0.00001 or absf(c.y - height) > 0.00001: continue
			var triangle := PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
			if area(triangle) > 0.00001: result.append(triangle)
	return result

func overlapping_triangles(triangles: Array[PackedVector2Array]) -> int:
	var grid := {}
	var rectangles: Array[Rect2] = []
	var overlaps := 0
	for i in triangles.size():
		var rect := bounds(triangles[i])
		rectangles.append(rect)
		var first := Vector2i(floori(rect.position.x / 2.0), floori(rect.position.y / 2.0))
		var last := Vector2i(floori(rect.end.x / 2.0), floori(rect.end.y / 2.0))
		var seen := {}
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				var cell := Vector2i(x, z)
				if not grid.has(cell): grid[cell] = []
				for j: int in grid[cell]:
					if seen.has(j): continue
					seen[j] = true
					if not rect.intersects(rectangles[j]): continue
					for polygon in Geometry2D.intersect_polygons(triangles[i], triangles[j]):
						if area(polygon) <= 0.00001: continue
						overlaps += 1
						if overlaps <= 8: print("COPLANAR OVERLAP: ", rect, " vs ", rectangles[j], " area=", area(polygon))
				grid[cell].append(i)
	return overlaps

func route(points: Array[Vector3]) -> bool:
	var result := true
	for segment in points.size() - 1:
		var steps := ceili(points[segment].distance_to(points[segment + 1]) / 0.25)
		for i in steps + 1:
			var point := points[segment].lerp(points[segment + 1], float(i) / steps)
			route_samples += 1
			if not Safety.clear_at(game.player, point) or not Safety.supported(game.player, point):
				result = false
				print("SURFACE ROUTE BLOCKED: ", point)
	return result

func review() -> void:
	var prefs = root.get_node("HarborPrefs")
	prefs.continue_game = false; prefs.starting_place = "whale_home"
	prefs.world_save_path = OUTPUT + "world.json"; prefs.settings_path = OUTPUT + "settings.cfg"
	prefs.values.music = false; prefs.values.sfx = false; prefs.values.ambience = false
	prefs.values.follow = true; prefs.values.day_cycle = false; prefs.values.fullscreen = false
	game = load("res://district/continuous_world.tscn").instantiate()
	root.add_child(game); current_scene = game
	game.life_booted = false; game.set_physics_process(false)
	game.loot.save_path = OUTPUT + "inventory.json"
	game.dialogue_controller.save_path = OUTPUT + "dialogue.json"
	game.home_controller.set_process(false)
	for i in 6: await physics_frame
	game.dialogue_controller.close(); game.dialog_open = false
	var island: Node3D = game.home_controller.level.get_node("Island")
	var home_script: GDScript = load("res://district/whale_home_map.gd")
	var paving := horizontal_triangles(island, float(Ground.settings.paving_top))
	var grass := horizontal_triangles(island, float(Ground.settings.grass_top))
	var dock := horizontal_triangles(island, 0.025)
	print("SURFACE TRIANGLES: paving=", paving.size(), " grass=", grass.size(), " dock=", dock.size())
	check(paving.size() > 1000 and overlapping_triangles(paving) == 0, "actual pavers and lawn curbs have no coplanar overlap")
	check(dock.size() > 100 and overlapping_triangles(dock) == 0, "actual dock boards have no coplanar overlap at the T junctions")
	var hidden_grass := 0
	for triangle in grass:
		for rect in Ground.paving_regions:
			var outline := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
			for polygon in Geometry2D.intersect_polygons(triangle, outline):
				if area(polygon) > 0.00001: hidden_grass += 1
	check(not grass.is_empty() and hidden_grass == 0, "actual lawn caps are cut out beneath paved paths and patios")
	check(float(Ground.settings.paving_top) < game.CHARACTER_FLOOR_Y and float(Ground.settings.grass_top) < game.CHARACTER_FLOOR_Y, "garden surfaces stay below character feet")
	var reef_count := 0
	var reef_collision_count := 0
	var clear_reefs := true
	var matched_reefs := true
	for node: Node3D in island.find_children("*", "Node3D", true, false):
		if not node.has_meta("coastal_reef"): continue
		reef_count += 1
		var rect: Rect2 = node.get_meta("reef_bounds")
		for keepout: Rect2 in home_script.DOCK_RECTS:
			if rect.intersects(keepout.grow(0.35)): clear_reefs = false
		for child in node.get_children():
			if child is StaticBody3D and child.name.begins_with("FracturedReefCollision"):
				reef_collision_count += 1
		var query := PhysicsRayQueryParameters3D.create(node.global_position + Vector3(0, 4, 0), node.global_position - Vector3(0, 4, 0), 1)
		var hit: Dictionary = game.player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or not hit.collider.name.begins_with("FracturedReefCollision"): matched_reefs = false; print("REEF HIT MISMATCH: ", node.global_position, " ", hit)
	print("SURFACE REEFS: ", reef_count, " primary colliders=", reef_collision_count)
	check(reef_count > 40 and clear_reefs, "all reef clusters keep clear of the island/dock entrances")
	check(reef_collision_count == reef_count and matched_reefs, "visible reef crowns are backed by native solid collisions")
	check(route([Vector3(-9.6, 0.05, 11), Vector3(0, 0.05, 11), Vector3(0, 0.05, 33.7)]), "main entrance to dock return route remains clear and supported")
	check(route([Vector3(-17, 0.05, -23), Vector3(-17, 0.05, 23)]) and route([Vector3(17, 0.05, -23), Vector3(17, 0.05, 23)]), "both side promenades remain clear and supported")
	check(route([Vector3(-19.25, 0.05, 22), Vector3(-19.25, 0.05, 29.5), Vector3(0, 0.05, 29.5)]), "west dock entrance and crossbridge T junction remain clear and supported")
	check(route([Vector3(-19.25, 0.05, 29.5), Vector3(-19.25, 0.05, 33.2)]), "moved whale sculpture leaves the west dock walking lane clear")
	var solid_posts := true
	var post_count := 0
	for z in [25.5, 29.3, 33.0]:
		for x in [-21.7, -16.8]:
			if x == -16.8 and z == 29.3: continue
			post_count += 1
			if Safety.clear_at(game.player, Vector3(x, 0.05, z)): solid_posts = false
	for z in [28.16, 30.84]:
		for x in [-16.25, -12.0, -7.7, -3.25]:
			post_count += 1
			if Safety.clear_at(game.player, Vector3(x, 0.05, z)): solid_posts = false
	check(solid_posts and post_count == 13, "all 13 west dock and crossbridge posts block the character silhouette")
	check(not Safety.clear_at(game.player, Vector3(-20.9, 0.05, 32.4)), "west dock whale sculpture blocks physical penetration")
	print("SURFACE NATIVE RENDERER: ", RenderingServer.get_video_adapter_name())
	print("SURFACE ROUTE SAMPLES: ", route_samples)
	print("SURFACE COLLISION CHECK: ", checked, " CHECKS, ", checked - failed, " PASSED, ", failed, " FAILED")
	game.queue_free()
	for i in 6: await process_frame
	quit(1 if failed else 0)
