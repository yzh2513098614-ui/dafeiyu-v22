extends SceneTree
## Compare imported new-character textures with PNGs after Godot alpha-border processing.
var checked := 0
var failures := 0
var sizes: Dictionary = {}

func _initialize() -> void:
	audit_directory("res://assets/character/download_walk_20261013")
	audit_directory("res://assets/character/blink_20261013")
	print("CHARACTER TEXTURE AUDIT checked=", checked, " failures=", failures, " sizes=", sizes)
	quit(0 if failures == 0 else 1)

func audit_directory(path: String) -> void:
	for directory in DirAccess.get_directories_at(path):
		audit_directory(path.path_join(directory))
	for file in DirAccess.get_files_at(path):
		if not file.ends_with(".png"):
			continue
		var source_path := path.path_join(file)
		var settings := ConfigFile.new()
		settings.load(source_path + ".import")
		var original := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		var texture: Texture2D = load(source_path)
		var imported := texture.get_image()
		var dimensions := str(original.get_size())
		sizes[dimensions] = int(sizes.get(dimensions, 0)) + 1
		if settings.get_value("params", "process/fix_alpha_border", false):
			original.fix_alpha_edges()
		original.convert(Image.FORMAT_RGBA8)
		imported.convert(Image.FORMAT_RGBA8)
		var matches := original.get_size() == imported.get_size() and original.get_data() == imported.get_data()
		var lossless: bool = settings.get_value("params", "compress/mode", -1) == 0
		var full_size: bool = settings.get_value("params", "process/size_limit", -1) == 0
		checked += 1
		if not (matches and lossless and full_size):
			failures += 1
			print("TEXTURE QUALITY FAILURE ", source_path, " pixels=", matches, " lossless=", lossless, " full_size=", full_size)
