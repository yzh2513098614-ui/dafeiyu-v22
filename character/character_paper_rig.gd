extends Node2D
## A painted cutout rig. No procedural geometry is drawn without the source PNG.
## phase is normalized distance / cycle_distance; both feet share one cycle.

const DEFAULT_CANVAS := Vector2(384.0, 512.0)
const DEFAULT_GROUND := Vector2(192.0, 420.0)
const DEFAULT_PIXEL_SIZE := 0.0064
const WEIGHT_BOB_KEYS := [0.0, -0.012, 0.006, 0.016, 0.0, -0.012, 0.006, 0.016]
const GRID_COLUMNS := 5
const GRID_ROWS := 18

var canvas_size := DEFAULT_CANVAS
var ground := DEFAULT_GROUND
var pixel_size := DEFAULT_PIXEL_SIZE
var hip_height := 0.64
var hem_height := 0.21
var body_height := 2.0
var stride_halfspan := 0.30
var stance_ratio := 0.60
var lift_height := 0.10
var shoe_height := 0.15
var cycle_distance := 1.0
var camera_pitch_degrees := 33.0
var hip_spacing := 0.23
var body_sway := 0.004
var upper_length := 0.40
var lower_length := 0.40
var last_pose: Dictionary = {}

var _body: Sprite2D
var _legs: Array[Polygon2D] = []
var _views: Dictionary = {}
var _direction := ""
var _sheet: Texture2D
var _crop_shader: Shader


func configure(body_texture: Texture2D, leg_texture: Texture2D, manifest: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_legs.clear()
	_views.clear()
	_direction = ""
	_sheet = leg_texture
	canvas_size = _vector(manifest.get("canvas_size", [384, 512]), DEFAULT_CANVAS)
	ground = _vector(manifest.get("ground", [192, 420]), DEFAULT_GROUND)
	pixel_size = maxf(float(manifest.get("pixel_size", DEFAULT_PIXEL_SIZE)), 0.0001)
	hip_height = float(manifest.get("hip_height", 0.64))
	hem_height = float(manifest.get("hem_height", 0.21))
	body_height = float(manifest.get("body_height", 2.0))
	stride_halfspan = float(manifest.get("stride_halfspan", 0.30))
	stance_ratio = clampf(float(manifest.get("stance_ratio", 0.60)), 0.51, 0.85)
	lift_height = float(manifest.get("lift_height", 0.10))
	shoe_height = float(manifest.get("shoe_height", 0.15))
	cycle_distance = 2.0 * stride_halfspan / stance_ratio
	camera_pitch_degrees = float(manifest.get("camera_pitch_degrees", 33.0))
	hip_spacing = float(manifest.get("hip_spacing", 0.23))
	body_sway = clampf(float(manifest.get("body_sway", 0.004)), 0.0, 0.006)
	upper_length = float(manifest.get("upper_length", 0.40))
	lower_length = float(manifest.get("lower_length", 0.40))
	_crop_shader = Shader.new()
	# Polygon2D normalizes UV against AtlasTexture.region, whereas its texture RID
	# is the full sheet. Explicitly sample the regional atlas without changing PNGs.
	_crop_shader.code = """shader_type canvas_item;
uniform sampler2D sheet_texture : source_color, filter_linear;
uniform vec4 part_rect;
uniform float alpha_threshold = 0.30;
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
 vec2 local_uv = clamp(UV, vec2(0.0001), vec2(0.9999));
 vec4 paint = texture(sheet_texture, part_rect.xy + local_uv * part_rect.zw);
 // Remove the very faint ambient halo generated around otherwise isolated legs.
 paint.a = smoothstep(alpha_threshold, alpha_threshold + 0.08, paint.a);
 COLOR = paint * vertex_tint;
}
"""
	_body = Sprite2D.new()
	_body.name = "PaintedBody"
	_body.centered = false
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_body.z_index = 2
	add_child(_body)
	for i in range(2):
		var node := Polygon2D.new()
		node.name = "PaintedLeg%d" % i
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(node)
		_legs.append(node)
	var directions: Dictionary = manifest.get("directions", {})
	for direction in ["down", "left", "up", "right"]:
		if not directions.has(direction):
			continue
		var data: Dictionary = directions[direction]
		var body_data: Dictionary = data.get("body", {})
		var body_rect := _rect(body_data.get("rect", [0, 0, 1, 1]))
		var body_atlas := _atlas(body_texture, body_rect)
		var body_anchor := Vector2(float(body_data.get("anchor_x", body_rect.size.x * 0.5)), float(body_data.get("anchor_y", body_rect.size.y)))
		var leg_entries: Array = data.get("legs", [])
		var prepared: Array = []
		for i in range(mini(2, leg_entries.size())):
			var part := _prepare_leg(leg_entries[i])
			part["identity"] = str(leg_entries[i].get("identity", "A" if i == 0 else "B"))
			prepared.append(part)
		_views[direction] = {"body": body_atlas, "body_anchor": body_anchor, "legs": prepared}
	set_pose("down", 0.0, false)


func set_pose(direction: String, phase: float, walking: bool) -> void:
	if not _views.has(direction):
		direction = "down"
	if not _views.has(direction):
		return
	var view: Dictionary = _views[direction]
	var parts: Array = view["legs"]
	if parts.size() != 2:
		return
	if direction != _direction:
		_direction = direction
		_body.texture = view["body"]
		for i in range(2):
			var part: Dictionary = parts[i]
			_legs[i].texture = part["texture"]
			_legs[i].material = part["material"]
			_legs[i].uv = part["uv"]
			_legs[i].polygons = part["triangles"]
	phase = fposmod(phase, 1.0)
	var bob := _weight_bob(phase) if walking else 0.0
	var body_anchor: Vector2 = view["body_anchor"]
	var body_scale := body_height / (maxf(body_anchor.y, 1.0) * pixel_size)
	_body.scale = Vector2.ONE * body_scale
	# The skirt hem is its own anchor. Hips/knees remain behind the painted skirt,
	# leaving only ~33 screen pixels from lower ruffle to the grounded shoe.
	_body.offset = -body_anchor
	_body.position = ground + Vector2(0.0, -(hem_height + bob) / pixel_size)
	_body.rotation = sin(phase * TAU) * body_sway if walking else 0.0
	var poses: Array[Dictionary] = []
	for i in range(2):
		var leg_phase := fposmod(phase + float(i) * 0.5, 1.0)
		var target := _foot_target(leg_phase, walking)
		var forward: float = target.x
		var lift: float = target.y
		# Side views: A is the anatomical near leg. Front/back use left/right hips.
		var side := (1.0 if i == 0 else -1.0) if direction in ["left", "right"] else (-1.0 if i == 0 else 1.0)
		var lane := _lane(direction, side)
		var part: Dictionary = parts[i]
		var source_scale: float = part["scale"]
		var rest_ankle: Vector2 = part["ankle"]
		var ankle_height: float = (float(part["sole_y"]) - rest_ankle.y) * source_scale * pixel_size
		var hip_world := Vector2(0.0, hip_height + bob)
		var ankle_world := Vector2(forward, ankle_height + lift)
		var knee_world := _knee(hip_world, ankle_world)
		var hip := _project(direction, hip_world, lane)
		var knee := _project(direction, knee_world, lane)
		var ankle := _project(direction, ankle_world, lane)
		var shoe_angle := 0.0
		if walking and leg_phase >= stance_ratio and (direction == "left" or direction == "right"):
			shoe_angle = deg_to_rad(7.0) * sin(PI * (leg_phase - stance_ratio) / (1.0 - stance_ratio))
			if direction == "left":
				shoe_angle = -shoe_angle
		_legs[i].polygon = _deform(part, hip, knee, ankle, shoe_angle)
		var foot := _project(direction, Vector2(forward, lift), lane)
		poses.append({"identity":part["identity"], "phase": leg_phase, "forward": forward, "lift": lift, "planted":not walking or leg_phase < stance_ratio, "foot": foot, "hip": hip, "knee": knee, "ankle": ankle, "depth": _ground_depth(direction, forward, lane), "ankle_height":ankle_height, "source_scale":source_scale})
	# Sort by ground depth, not by elevated foot Y: a lifted foreground shoe stays
	# in front of the far leg. The opaque skirt always covers their upper overlap.
	var near_leg := 0 if float(poses[0]["depth"]) >= float(poses[1]["depth"]) else 1
	_legs[near_leg].z_index = 1
	_legs[1 - near_leg].z_index = 0
	last_pose = {"direction": direction, "phase": phase, "walking": walking, "bob": bob, "body_hem":_body.position, "body_rotation":_body.rotation, "hem_height":hem_height, "hip_height":hip_height, "legs": poses, "cycle_distance": cycle_distance}


func _weight_bob(phase: float) -> float:
	# Eight semantic pose keys in world metres; the root itself never drifts.
	var coordinate := fposmod(phase, 1.0) * WEIGHT_BOB_KEYS.size()
	var key := int(floor(coordinate))
	var t := coordinate - key
	var p0: float = WEIGHT_BOB_KEYS[posmod(key - 1, 8)]
	var p1: float = WEIGHT_BOB_KEYS[key]
	var p2: float = WEIGHT_BOB_KEYS[posmod(key + 1, 8)]
	var p3: float = WEIGHT_BOB_KEYS[posmod(key + 2, 8)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)


func _prepare_leg(entry: Dictionary) -> Dictionary:
	var rect := _rect(entry.get("rect", [0, 0, 1, 1]))
	var w := rect.size.x
	var h := rect.size.y
	var hip := _vector(entry.get("hip", [w * 0.5, h * 0.02]), Vector2(w * 0.5, h * 0.02))
	var knee := _vector(entry.get("knee", [w * 0.5, h * 0.47]), Vector2(w * 0.5, h * 0.47))
	var ankle := _vector(entry.get("ankle", [w * 0.5, h * 0.77]), Vector2(w * 0.5, h * 0.77))
	var sole_y := float(entry.get("sole_y", h * 0.97))
	# Shoe size comes from the painted ankle-to-sole region. The long hidden
	# source shin is allowed to bend/stretch inside the skirt without enlarging
	# the shoe until it consumes the entire .21m hem-to-ground space.
	var scale := shoe_height / (maxf(sole_y - ankle.y, 1.0) * pixel_size)
	var rows: Array[float] = []
	for y in range(GRID_ROWS + 1):
		rows.append(h * float(y) / float(GRID_ROWS))
	for special in [hip.y, knee.y - h * 0.04, knee.y, knee.y + h * 0.04, ankle.y - h * 0.035, ankle.y, ankle.y + h * 0.035, sole_y]:
		if special >= 0.0 and special <= h:
			rows.append(float(special))
	rows.sort()
	var uv := PackedVector2Array()
	for y in rows:
		for x in range(GRID_COLUMNS + 1):
			uv.append(Vector2(w * float(x) / float(GRID_COLUMNS), y))
	var triangles: Array[PackedInt32Array] = []
	for y in range(rows.size() - 1):
		for x in range(GRID_COLUMNS):
			var a := y * (GRID_COLUMNS + 1) + x
			var b := a + 1
			var c := a + GRID_COLUMNS + 1
			var d := c + 1
			triangles.append(PackedInt32Array([a, b, d]))
			triangles.append(PackedInt32Array([a, d, c]))
	var material := ShaderMaterial.new()
	material.shader = _crop_shader
	material.set_shader_parameter("sheet_texture", _sheet)
	var sheet_size := _sheet.get_size()
	material.set_shader_parameter("part_rect", Vector4(rect.position.x / sheet_size.x, rect.position.y / sheet_size.y, w / sheet_size.x, h / sheet_size.y))
	material.set_shader_parameter("alpha_threshold", float(entry.get("alpha_threshold", 0.30)))
	return {"texture": _atlas(_sheet, rect), "material": material, "uv": uv, "triangles": triangles, "hip": hip, "knee": knee, "ankle": ankle, "sole_y": sole_y, "scale": scale, "height": h}


func _deform(part: Dictionary, hip: Vector2, knee: Vector2, ankle: Vector2, shoe_angle: float) -> PackedVector2Array:
	var source: PackedVector2Array = part["uv"]
	var result := PackedVector2Array()
	result.resize(source.size())
	var rest_hip: Vector2 = part["hip"]
	var rest_knee: Vector2 = part["knee"]
	var rest_ankle: Vector2 = part["ankle"]
	var scale: float = part["scale"]
	var band := float(part["height"]) * 0.04
	for i in range(source.size()):
		var point := source[i]
		var upper := _segment(point, rest_hip, rest_knee, hip, knee, scale)
		var lower := _segment(point, rest_knee, rest_ankle, knee, ankle, scale)
		var knee_weight := smoothstep(rest_knee.y - band, rest_knee.y + band, point.y)
		var bent := upper.lerp(lower, knee_weight)
		# The whole shoe is a rigid painted piece, preserving the toe/heel silhouette.
		var shoe := ankle + ((point - rest_ankle) * scale).rotated(shoe_angle)
		var shoe_weight := smoothstep(rest_ankle.y - band, rest_ankle.y + band * 0.35, point.y)
		result[i] = bent.lerp(shoe, shoe_weight)
	return result


func _segment(point: Vector2, source_a: Vector2, source_b: Vector2, target_a: Vector2, target_b: Vector2, scale: float) -> Vector2:
	var axis := source_b - source_a
	var length := maxf(axis.length(), 0.001)
	axis /= length
	var delta := point - source_a
	var along := delta.dot(axis) / length
	var across := delta.dot(Vector2(axis.y, -axis.x)) * scale
	var posed_axis := target_b - target_a
	var posed_normal := Vector2(posed_axis.y, -posed_axis.x).normalized()
	if posed_axis.length_squared() < 0.0001:
		posed_normal = Vector2.RIGHT
	return target_a + posed_axis * along + posed_normal * across


func _knee(hip: Vector2, ankle: Vector2) -> Vector2:
	var delta := ankle - hip
	var distance := maxf(delta.length(), 0.0001)
	# Never clamp the foot target. In extreme custom poses only the hidden upper
	# leg extends; default .40+.40m reaches the .30m stride naturally.
	var a := upper_length
	var b := lower_length
	if distance > a + b:
		a += distance - (a + b) + 0.0001
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var bend := sqrt(maxf(a * a - along * along, 0.0))
	var axis := delta / distance
	return hip + axis * along + Vector2(-axis.y, axis.x) * bend


func _foot_target(phase: float, walking: bool) -> Vector2:
	if not walking:
		return Vector2.ZERO
	if phase < stance_ratio:
		return Vector2(lerpf(stride_halfspan, -stride_halfspan, phase / stance_ratio), 0.0)
	var swing := (phase - stance_ratio) / (1.0 - stance_ratio)
	return Vector2(lerpf(-stride_halfspan, stride_halfspan, smoothstep(0.0, 1.0, swing)), sin(PI * swing) * lift_height)


func _lane(direction: String, side: float) -> Vector2:
	if direction == "down" or direction == "up":
		return Vector2(side * hip_spacing * 0.5, 0.0)
	return Vector2(0.0, side * hip_spacing * 0.5)


func _project(direction: String, point: Vector2, lane: Vector2) -> Vector2:
	var depth_slope := tan(deg_to_rad(camera_pitch_degrees))
	var p := Vector2(lane.x, lane.y * depth_slope - point.y)
	match direction:
		"left": p.x -= point.x
		"right": p.x += point.x
		"down": p.y += point.x * depth_slope
		"up": p.y -= point.x * depth_slope
	return ground + p / pixel_size


func _ground_depth(direction: String, forward: float, lane: Vector2) -> float:
	if direction == "down":
		return lane.y + forward
	if direction == "up":
		return lane.y - forward
	return lane.y


func _atlas(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = rect
	atlas.filter_clip = true
	return atlas


func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _rect(value: Array) -> Rect2:
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
