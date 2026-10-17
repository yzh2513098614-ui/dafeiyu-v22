@tool
extends EditorPlugin
## Apply the project policy before the built-in texture importer reads options.
const SMOOTH_DIRECTORIES := [
 "res://assets/cards/cute_v22/",
 "res://assets/ui/card_quality/",
 "res://assets/ui/downloaded_20261011/",
 "res://assets/ui/inventory_icons_soft_edges_20261016/",
]
const MIXED_DIRECTORIES := ["res://assets/ui/pack/combat", "res://assets/ui/pack/combat32"]
const SMOOTH_COMBAT_ICONS := ["card_energy", "link", "block_counter"]
const OPTIONS := {
 "mipmaps/generate": true,
 "compress/mode": 0,
 "process/fix_alpha_border": true,
 "process/size_limit": 0,
}

func _enter_tree() -> void:
 EditorInterface.get_resource_filesystem().resources_reimporting.connect(_apply_import_rules)

func _exit_tree() -> void:
 EditorInterface.get_resource_filesystem().resources_reimporting.disconnect(_apply_import_rules)

func _is_smooth_ui(path:String) -> bool:
 if path.get_extension().to_lower() != "png":return false
 for directory in SMOOTH_DIRECTORIES:
  if path.begins_with(directory):return true
 return path.get_base_dir() in MIXED_DIRECTORIES and path.get_file().get_basename() in SMOOTH_COMBAT_ICONS

func _apply_import_rules(paths:PackedStringArray) -> void:
 var updated := 0
 for path in paths:
  if not _is_smooth_ui(path):continue
  var sidecar := path + ".import"
  var config := ConfigFile.new()
  if FileAccess.file_exists(sidecar):
   var error := config.load(sidecar)
   if error != OK:
    push_error("UI texture import: cannot read %s (%s)" % [sidecar, error_string(error)])
    continue
   if str(config.get_value("remap", "importer", "texture")) != "texture":continue
  var changed := false
  for option in OPTIONS:
   if not config.has_section_key("params", option) or config.get_value("params", option) != OPTIONS[option]:
    config.set_value("params", option, OPTIONS[option])
    changed = true
  if not changed:continue
  config.set_value("remap", "importer", "texture")
  var error := config.save(sidecar)
  if error != OK:push_error("UI texture import: cannot save %s (%s)" % [sidecar, error_string(error)])
  else:updated += 1
 if updated > 0:print("[UiTextureImport] Applied project import settings to ", updated, " PNG(s)")
