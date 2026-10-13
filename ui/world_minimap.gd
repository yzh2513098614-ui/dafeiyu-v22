extends Control
## North-up schematic of the actual current floor, with actor and route overlays.
var game: Node
var navigation: Node
var map_rect := Rect2(12, 38, 278, 210)
var bounds := Rect2()
var obstacles: Array[Rect2] = []
var floor_polygons: Array = []
var last_location := ""
var last_height := -INF
var refresh_time := 0.0

func configure(owner_game: Node, navigator: Node) -> void:
	game = owner_game; navigation = navigator
	name = "WorldMinimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	preload("res://ui/ui_fit.gd").pin_right(self, 302, 48, 362, 290)
	tooltip_text = "右键小地图：前往当前位置所在楼层的目的地\n青色：你 · 黄色：出口 · 绿线：行走路线 · N：北"

func _process(delta: float) -> void:
	if not game: return
	visible = navigation.available()
	if not visible: return
	refresh_time += delta
	if last_location != game.location_id or absf(last_height - game.player.position.y) > 0.7 or refresh_time > 1.5:
		_rebuild(); refresh_time = 0
	queue_redraw()

func _rebuild() -> void:
	last_location = game.location_id; last_height = game.player.position.y
	bounds = Rect2(-game.space_bounds * 0.5, game.space_bounds)
	floor_polygons.clear(); obstacles.clear()
	for polygon in game.shell.get_meta("floor_contours", []): floor_polygons.append(polygon)
	if game.shell.has_meta("floor_contour"): floor_polygons.append(game.shell.get_meta("floor_contour"))
	_collect(game.world)
	# Some custom scenes extend past the nominal centered bounds.
	for zone in game.room_zones:
		bounds = bounds.merge(zone.rect)
	bounds = bounds.expand(Vector2(game.player.position.x, game.player.position.z)).grow(1.0)
	var aspect := map_rect.size.x / map_rect.size.y
	if bounds.size.x / bounds.size.y > aspect:
		var extra := bounds.size.x / aspect - bounds.size.y
		bounds.position.y -= extra * 0.5; bounds.size.y += extra
	else:
		var extra := bounds.size.y * aspect - bounds.size.x
		bounds.position.x -= extra * 0.5; bounds.size.x += extra

func _collect(node: Node) -> void:
	if node == game.player or node == game.silhouette_body: return
	if node is CollisionShape3D and not node.disabled and node.shape:
		var aabb: AABB = node.shape.get_debug_mesh().get_aabb()
		var low := INF; var high := -INF
		var rect := Rect2(); var first := true
		for x in [aabb.position.x, aabb.end.x]:
			for y in [aabb.position.y, aabb.end.y]:
				for z in [aabb.position.z, aabb.end.z]:
					var p: Vector3 = node.to_global(Vector3(x, y, z))
					low = minf(low, p.y); high = maxf(high, p.y)
					if first: rect = Rect2(Vector2(p.x, p.z), Vector2.ZERO); first = false
					else: rect = rect.expand(Vector2(p.x, p.z))
		if low < last_height + 0.8 and high > last_height + 0.08: obstacles.append(rect)
	for child in node.get_children(): _collect(child)

func project(point: Vector3) -> Vector2:
	return map_rect.position + (Vector2(point.x, point.z) - bounds.position) / bounds.size * map_rect.size

func unproject(point: Vector2) -> Vector3:
	var p := bounds.position + (point - map_rect.position) / map_rect.size * bounds.size
	return Vector3(p.x, game.player.position.y, p.y)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if map_rect.has_point(event.position): navigation.request(unproject(event.position))
		accept_event()

func _draw() -> void:
	if not game or bounds.size == Vector2.ZERO: return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("102b42"); panel.border_color = Color("7ed5e4")
	panel.set_border_width_all(2); panel.set_corner_radius_all(14)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(14, 25), "小地图 · N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e3f8ff"))
	draw_rect(map_rect, Color("244b58"))
	for polygon in floor_polygons:
		var mapped := PackedVector2Array()
		for p in polygon: mapped.append(project(Vector3(p.x, 0, p.y)))
		if mapped.size() >= 3: draw_colored_polygon(mapped, Color("3a6670"))
	for zone in game.room_zones:
		if absf(float(zone.get("height", 0)) - game.player.position.y) > 1: continue
		var rect: Rect2 = zone.rect
		draw_rect(Rect2(project(Vector3(rect.position.x, 0, rect.position.y)), rect.size / bounds.size * map_rect.size), Color("497c83"), false, 1)
	for rect in obstacles:
		var mapped := Rect2(project(Vector3(rect.position.x, 0, rect.position.y)), rect.size / bounds.size * map_rect.size).intersection(map_rect)
		if mapped.has_area(): draw_rect(mapped, Color("172d3e"))
	for portal in game.portals:
		var p: Vector3 = portal.get("pos", portal.get("position", portal.get("spawn", Vector3.ZERO)))
		if absf(p.y - game.player.position.y) < 1: draw_circle(project(p), 3, Color("ffd27d"))
	var route := PackedVector2Array([project(game.player.position)])
	for p in navigation.path: route.append(project(p))
	if route.size() > 1: draw_polyline(route, Color("68edbd"), 2, true)
	if navigation.searching or not navigation.path.is_empty(): draw_arc(project(navigation.destination), 5, 0, TAU, 20, Color("68edbd"), 2)
	var actor := project(game.player.position)
	draw_circle(actor, 6, Color("e5ffff")); draw_circle(actor, 4, Color("43dbea"))
	var directions := {"up":Vector2.UP, "down":Vector2.DOWN, "left":Vector2.LEFT, "right":Vector2.RIGHT, "up_left":Vector2(-1,-1), "up_right":Vector2(1,-1), "down_left":Vector2(-1,1), "down_right":Vector2(1,1)}
	var forward: Vector3 = game._screen_direction_to_world(directions.get(game.facing, Vector2.DOWN))
	draw_line(actor, actor + Vector2(forward.x, forward.z).normalized() * 11, Color("e5ffff"), 2)
	draw_string(font, Vector2(14, 273), navigation.status, HORIZONTAL_ALIGNMENT_LEFT, 274, 15, Color("c9e7ef"))
