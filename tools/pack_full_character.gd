extends SceneTree
## Pack complete painted PNG frames through a single whole-image Sprite2D.
## No rig, body parts, local deformation or runtime manifest writes.
const DEFAULT_INPUT := "res://assets/character/v15/completeframes.json"
const DEFAULT_OUTPUT := "res://assets/character/v15/full_png/"
const ORDER := ["down", "left", "up", "right"]
var _walk_count := 16
var _input := DEFAULT_INPUT
var _output := DEFAULT_OUTPUT
var _config: Dictionary = {}
var _textures: Dictionary = {}
var _views: Dictionary = {}
var _viewport: SubViewport
var _sprite: Sprite2D
var _size := Vector2i(512, 512)
var _ground := Vector2(256, 420)
var _save_frames := false
var _failed := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--input="):
			_input = argument.trim_prefix("--input=")
		elif argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
		elif argument == "--frames":
			_save_frames = true
	if not _output.ends_with("/"):
		_output += "/"
	call_deferred("_pack")


func _fail(message: String) -> void:
	_failed = true
	push_error("FULL_PNG_PACK: " + message)
	quit(2)


func _pack() -> void:
	if not FileAccess.file_exists(_input):
		_fail("Missing " + _input + ". Supply approved complete-character PNG frames first.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_input))
	if not parsed is Dictionary:
		_fail("Input must be a JSON object.")
		return
	_config = parsed
	_walk_count = clampi(int(_config.get("walk_count",16)),1,32)
	var size_value: Variant = _config.get("canvas_size", [512, 512])
	if not _pair(size_value):
		_fail("canvas_size must be [width,height].")
		return
	_size = Vector2i(int(size_value[0]), int(size_value[1]))
	if _size.x <= 0 or _size.y <= 0 or _size.x * _walk_count > 16384:
		_fail("Invalid canvas_size or walk atlas wider than 16384 pixels.")
		return
	var ground_value: Variant = _config.get("ground", [256, 420])
	if not _pair(ground_value):
		_fail("ground must be a fixed canvas [x,y].")
		return
	_ground = Vector2(float(ground_value[0]), float(ground_value[1]))
	var directions: Variant = _config.get("directions", {})
	if not directions is Dictionary:
		_fail("directions must map down/left/up/right to complete frames.")
		return
	for direction in ORDER:
		var resolved := _resolve_view(direction, directions, [])
		if _failed:
			return
		_views[direction] = resolved
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	if directory_error != OK:
		_fail("Cannot create output directory, error " + str(directory_error))
		return
	if _save_frames:
		directory_error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output + "review_frames"))
		if directory_error != OK:
			_fail("Cannot create review_frames, error " + str(directory_error))
			return
	_viewport = SubViewport.new()
	_viewport.size = _size
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(_viewport)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_viewport.add_child(_sprite)
	var records: Array = []
	var unique_counts: Dictionary = {}
	for state in ["walk", "idle"]:
		var count: int = _walk_count if state == "walk" else 1
		var atlas := Image.create(_size.x * count, _size.y * ORDER.size(), false, Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for row in ORDER.size():
			var direction: String = ORDER[row]
			var view: Dictionary = _views[direction]
			unique_counts[direction] = view.frames.size()
			for column in count:
				var source_index: int = int(view.sequence[column]) if state == "walk" else -1
				var frame: Dictionary = view.frames[source_index] if state == "walk" else view.idle
				_place_complete_image(frame)
				await process_frame
				await RenderingServer.frame_post_draw
				var rendered: Image = _viewport.get_texture().get_image()
				atlas.blit_rect(rendered, Rect2i(Vector2i.ZERO, _size), Vector2i(column * _size.x, row * _size.y))
				if _save_frames:
					var frame_error := rendered.save_png(_output + "review_frames/%s_%s_%02d.png" % [state, direction, column])
					if frame_error != OK:
						_fail("Cannot save native frame, error " + str(frame_error))
						return
				records.append({"state":state, "direction":direction, "frame":column, "source_index":source_index, "source":frame.path, "source_rect":frame.source_rect, "source_size":frame.source_size, "source_ground":frame.source_ground, "source_scale":frame.source_scale, "flip_h":frame.flip_h, "canvas_position":[_sprite.position.x,_sprite.position.y]})
		var save_error := atlas.save_png(_output + state + "_atlas.png")
		if save_error != OK:
			_fail("Cannot save " + state + " atlas, error " + str(save_error))
			return
	var metadata := {"version":1, "method":_config.get("method","complete_generated_png_frames"), "source_manifest":_input, "canvas_size":[_size.x,_size.y], "ground":[_ground.x,_ground.y], "pixel_size":_config.get("pixel_size",0.0064), "atlas_order":ORDER, "frame_counts":{"walk":_walk_count,"idle":1}, "unique_source_poses":unique_counts, "cycle_distance":_config.get("cycle_distance",1.0), "transform":"whole image uniform scale and translation; optional whole image horizontal mirror", "frames":records, "runtime_manifest_modified":false}
	var metadata_file := FileAccess.open(_output + "packing_metadata.json", FileAccess.WRITE)
	if metadata_file == null:
		_fail("Cannot save packing_metadata.json.")
		return
	metadata_file.store_string(JSON.stringify(metadata, "  "))
	metadata_file.close()
	print("FULL_PNG_PACK_COMPLETE walk=",_walk_count*4," idle=4 output=", _output, "; unique source poses=", unique_counts, "; runtime manifest unchanged")
	quit()


func _resolve_view(direction: String, directions: Dictionary, chain: Array) -> Dictionary:
	if direction in chain or not directions.get(direction) is Dictionary:
		_fail("Missing direction or circular mirror_of: " + direction)
		return {}
	var view: Dictionary = directions[direction]
	if view.has("mirror_of"):
		var next_chain := chain.duplicate()
		next_chain.append(direction)
		var original := _resolve_view(str(view.mirror_of), directions, next_chain)
		if _failed:
			return {}
		for frame in original.frames:
			frame.flip_h = not frame.flip_h
		original.idle.flip_h = not original.idle.flip_h
		return original
	var sources: Variant = view.get("frames", [])
	if not sources is Array or sources.is_empty() or sources.size() > _walk_count:
		_fail(direction + " requires 1 to 16 complete PNG frames.")
		return {}
	var frames: Array = []
	for source in sources:
		frames.append(_parse_frame(source))
		if _failed:
			return {}
	var sequence: Variant = view.get("sequence", [])
	if not sequence is Array:
		_fail(direction + " sequence must contain 16 source-frame indices.")
		return {}
	if sequence.is_empty():
		for index in _walk_count:
			sequence.append(int(float(index) * frames.size() / _walk_count))
	if sequence.size() != _walk_count:
		_fail(direction + " sequence must contain exactly 16 indices.")
		return {}
	for index in sequence:
		if not _number(index) or int(index) != float(index) or int(index) < 0 or int(index) >= frames.size():
			_fail(direction + " has an invalid source-frame index.")
			return {}
	var idle: Dictionary = _parse_frame(view.idle) if view.has("idle") else frames[0].duplicate(true)
	return {"frames":frames, "sequence":sequence, "idle":idle}


func _parse_frame(value: Variant) -> Dictionary:
	var data: Dictionary
	if value is String:
		data = {"path":value}
	elif value is Dictionary:
		data = value.duplicate(true)
	else:
		_fail("A frame must be a PNG path or a frame object.")
		return {}
	var path := str(data.get("path", data.get("source", "")))
	if path == "":
		_fail("Complete frame path is empty.")
		return {}
	if not path.begins_with("res://") and not path.is_absolute_path():
		path = _input.get_base_dir().path_join(path)
	if not path.to_lower().ends_with(".png") or not FileAccess.file_exists(path):
		_fail("Complete source PNG missing: " + path)
		return {}
	if not _textures.has(path):
		var source_image := Image.new()
		var load_error := source_image.load(path)
		if load_error != OK:
			_fail("Cannot load complete source PNG: " + path)
			return {}
		if source_image.detect_alpha() == Image.ALPHA_NONE:
			_fail("Source PNG needs real transparent alpha around the complete character: " + path)
			return {}
		_textures[path] = ImageTexture.create_from_image(source_image)
	var texture: Texture2D = _textures[path]
	var rect: Array = data.get("rect",[0,0,texture.get_width(),texture.get_height()])
	if rect.size()!=4 or float(rect[2])<=0 or float(rect[3])<=0 or not Rect2(Vector2.ZERO,texture.get_size()).encloses(Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))):
		_fail("Complete character region is invalid: "+path)
		return {}
	var source_ground: Variant = data.get("source_ground", _config.get("source_ground", [730,1110]))
	var source_scale: Variant = data.get("source_scale", _config.get("source_scale", 0.336))
	if not _pair(source_ground) or not _number(source_scale) or float(source_scale) <= 0.0:
		_fail("source_ground must be [x,y] and source_scale one positive uniform scalar: " + path)
		return {}
	return {"path":path, "source_rect":rect, "source_size":[rect[2],rect[3]], "source_ground":[float(source_ground[0]),float(source_ground[1])], "source_scale":float(source_scale), "flip_h":bool(data.get("flip_h",false))}


func _place_complete_image(frame: Dictionary) -> void:
	var texture: Texture2D = _textures[frame.path]
	var anchor := Vector2(float(frame.source_ground[0]),float(frame.source_ground[1]))
	_sprite.texture = texture
	_sprite.region_enabled = true
	_sprite.region_filter_clip_enabled = true
	var rect: Array = frame.source_rect
	_sprite.region_rect = Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3]))
	_sprite.flip_h = frame.flip_h
	if _sprite.flip_h:
		anchor.x = float(frame.source_size[0]) - anchor.x
	var uniform_scale: float = frame.source_scale
	_sprite.scale = Vector2.ONE * uniform_scale
	_sprite.rotation = 0.0
	_sprite.position = _ground - anchor * uniform_scale


func _number(value: Variant) -> bool:
	return value is int or value is float


func _pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])
