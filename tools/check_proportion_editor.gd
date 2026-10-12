extends SceneTree
const OUT := "res://预览/人物编辑器调参_20261012/"
var failures := 0

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 AudioServer.set_bus_mute(0,true);root.size=Vector2i(1100,750)
 var scene=load("res://tools/character_proportion_editor.tscn").instantiate()
 root.add_child(scene);current_scene=scene
 for i in 4:await process_frame
 var sprite: Sprite3D=scene.get_node("Adjusted")
 var material: ShaderMaterial=sprite.material_override
 var old: float=scene.head_drop
 var old_width: float=scene.head_width
 var expected_crown: float=scene.profile().crown_compression
 scene.head_drop=old+.01
 for i in 2:await process_frame
 check(is_equal_approx(float(material.get_shader_parameter("proportion_head_drop")),old+.01),"Inspector parameter updates production shader live")
 check(is_equal_approx(float(material.get_shader_parameter("proportion_crown_compression")),expected_crown),"height lock preserves crown alignment")
 scene.head_drop=old
 for i in 2:await process_frame
 check(is_equal_approx(float(material.get_shader_parameter("proportion_head_width")),old_width),"head width remains unchanged")
 scene.frame_index=7
 for i in 2:await process_frame
 check(sprite.texture.resource_path.ends_with("walk_07.png"),"manual frame scrub updates full source texture")
 scene.frame_index=3
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT+"编辑器场景渲染.png"))
 var source:=FileAccess.get_file_as_string("res://assets/character/manifest.json")
 var file:=FileAccess.open(OUT+"manifest_test.json",FileAccess.WRITE);file.store_string(source);file.close()
 await scene.save_parameters(OUT+"manifest_test.json",OUT+"collision_test.json")
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"manifest_test.json"))
 check(is_equal_approx(float(saved.proportion_warp_by_direction.down.head_drop),old),"save button writes edited proportion profile")
 check(saved.frames_by_state==scene.manifest.frames_by_state,"save preserves all source frame references")
 var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/character/collision_profile.json"))
 var actual: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"collision_test.json"))
 check(expected==actual,"native collision rebuild matches production Python generator")
 check(FileAccess.get_file_as_string("res://assets/character/manifest.json")==source,"isolated editor verification leaves game data unchanged")
 print("PROPORTION EDITOR: 8 checks, ",failures," failures")
 quit(0 if failures==0 else 1)
