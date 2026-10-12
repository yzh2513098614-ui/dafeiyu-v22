@tool
extends Node3D
## Select this scene's root in the editor; controls update the production shader.
const MANIFEST := "res://assets/character/manifest.json"
const Proportions = preload("res://character/proportion_profiles.gd")
const Surface = preload("res://character/surface_profiles.gd")
const Palette = preload("res://character/palette_profiles.gd")
const CollisionBuilder = preload("res://tools/editor_collision_profile.gd")

@export_group("主要调整：头部下拉，身体压短")
## Increase to stretch the lower head down and shorten the torso. Top and feet stay fixed.
@export_range(0.0,0.08,0.001) var head_drop: float = 0.035
@export_range(0.0,0.35,0.005) var head_width: float = 0.18
@export_range(0.0,0.30,0.005) var body_width: float = 0.18
@export_group("头顶与总高度")
## Keeps the original top height when changing head height or torso length.
@export var keep_original_height: bool = true
@export_range(0.0,0.30,0.005) var head_height: float = 0.18
@export_range(-0.01,0.06,0.001) var body_extension: float = 0.022
## 仅在关闭 Keep Original Height 时使用。开启时实际值 = max(0, 0.4 * Head Height + Body Extension - 0.03)。
@export_range(0.0,0.09,0.001) var crown_compression: float = 0.064
@export_group("眼睛高度：上缘下压，下缘微移")
## 眼睛上缘向下移动，眼睛变矮；0 为原样，建议先试 0.006～0.010。只影响正面。
@export_range(0.0,0.020,0.001) var eye_upper_drop: float:
 set(value):set_meta("proportion_eye_upper_drop",value)
 get:return float(get_meta("proportion_eye_upper_drop",0.0))
## 眼睛下缘也向下移动，幅度建议小一些：0.001～0.003。数值越大，下缘越低。
@export_range(0.0,0.006,0.0005) var eye_lower_drop: float:
 set(value):set_meta("proportion_eye_lower_drop",value)
 get:return float(get_meta("proportion_eye_lower_drop",0.0))
@export_group("预览")
@export var animate_walk: bool = false
@export_range(0,11,1) var frame_index: int = 3
@export_tool_button("读取游戏参数", "Reload") var reload_action = load_game_parameters
@export_tool_button("保存到游戏（含碰撞轮廓）", "Save") var save_action = save_to_game
@export_multiline var status: String = "拖动参数后自动同步游戏比例；满意后点保存更新碰撞轮廓。查看相机效果需选 PreviewCamera 并勾选视口的预览。"

var manifest: Dictionary
var last_profile: Dictionary = {}
var last_frame := -1
var clock := 0.0
var saving := false
var source_text := ""
var sync_clock := 0.0

func _manifest_path() -> String:
 return str(get_meta("proportion_manifest_path",MANIFEST))

func _ready() -> void:
 source_text=FileAccess.get_file_as_string(_manifest_path())
 manifest=JSON.parse_string(source_text)
 _align_preview_camera()
 _refresh()
 if not Engine.is_editor_hint():load_game_parameters()
 if Engine.is_editor_hint():print("CHARACTER PROPORTION EDITOR READY: Inspector controls active")

func profile() -> Dictionary:
 var config: Dictionary=manifest.proportion_warp_by_direction.down.duplicate()
 config.head_drop=head_drop;config.head_width=head_width;config.body_width=body_width
 config.head_height=head_height;config.body_extension=body_extension
 config.eye_upper_drop=eye_upper_drop;config.eye_lower_drop=eye_lower_drop
 config.crown_compression=maxf(0.0,.4*head_height+body_extension-.03) if keep_original_height else crown_compression
 return config

func _process(delta: float) -> void:
 if manifest.is_empty():return
 _align_preview_camera()
 if not Engine.is_editor_hint():
  sync_clock+=delta
  if sync_clock>=.5:
   sync_clock=0.0
   if FileAccess.get_file_as_string(_manifest_path())!=source_text:load_game_parameters()
 if animate_walk:
  clock+=delta
  frame_index=int(clock*8.0)%12
 var config:=profile()
 if Engine.is_editor_hint():sync_editor_changes(config,delta)
 if config!=last_profile or frame_index!=last_frame:_refresh()

func _align_preview_camera() -> void:
 # Match the world's elevation; yaw stays zero to keep the three comparisons aligned.
 var target:=Vector3(0,1.2,0)
 var world_axis:=Vector3(sin(deg_to_rad(28.0))*76.0,50.08,cos(deg_to_rad(28.0))*76.0-.04)
 var position:=target+Vector3(0,world_axis.y,Vector2(world_axis.x,world_axis.z).length()).normalized()*10.0
 if $PreviewCamera.position!=position:
  $PreviewCamera.position=position
  $PreviewCamera.look_at(target)
  if Engine.is_editor_hint():print("CHARACTER PREVIEW CAMERA UPDATED: game elevation ~33.4 degrees")

func sync_editor_changes(config: Dictionary,delta: float) -> void:
 # Metadata survives editor script hot reload, including already open scene instances.
 if not has_meta("proportion_last_edit"):
  set_meta("proportion_last_edit",config.duplicate(true))
  return
 if config!=get_meta("proportion_last_edit"):
  set_meta("proportion_last_edit",config.duplicate(true))
  set_meta("proportion_pending_edit",true)
  set_meta("proportion_edit_delay",.3)
 if not get_meta("proportion_pending_edit",false) or saving:return
 var delay:=float(get_meta("proportion_edit_delay",.3))-delta
 set_meta("proportion_edit_delay",delay)
 if delay>0.0:return
 _write_profile(_manifest_path())
 set_meta("proportion_pending_edit",false)
 status="比例已自动写入游戏，约 0.5 秒内同步；满意后点保存更新碰撞轮廓。头顶实际压缩量：%.3f" % float(config.crown_compression)

func _refresh() -> void:
 if manifest.is_empty() or not is_node_ready():return
 last_profile=profile();last_frame=frame_index
 var preview_manifest: Dictionary=manifest.duplicate(true)
 preview_manifest.proportion_warp_by_direction.down=last_profile
 var original: Dictionary=last_profile.duplicate()
 original.head_height=0.0;original.head_width=0.0;original.crown_compression=0.0;original.head_drop=0.0;original.body_extension=.03;original.body_width=.12;original.top_padding=0.0
 original.eye_upper_drop=0.0;original.eye_lower_drop=0.0
 var original_manifest: Dictionary=manifest.duplicate(true)
 original_manifest.proportion_warp_by_direction.down=original
 _pose($Original,"down",original_manifest)
 _pose($Adjusted,"down",preview_manifest)
 _pose($Diagonal,"down_left",manifest)

func _pose(sprite: Sprite3D,direction: String,data: Dictionary) -> void:
 var paths: Array=data.frames_by_state.walk[direction]
 var path: String=paths[frame_index%paths.size()]
 sprite.texture=load(path)
 sprite.pixel_size=float(data.get("pixel_size_by_direction",{}).get(direction,data.pixel_size))
 sprite.position.y=.056+(float(data.ground[1])-float(data.frame_size[1])*.5)*sprite.pixel_size
 if not sprite.material_override:
  var material:=ShaderMaterial.new();material.shader=load("res://character/character_depth.gdshader");sprite.material_override=material
 var material: ShaderMaterial=sprite.material_override
 material.set_shader_parameter("character_atlas",sprite.texture)
 material.set_shader_parameter("edge_ink_enabled",false)
 Surface.apply(material,direction,data.get("surface_profiles_by_direction",{}).get(direction,{}),frame_index,true)
 Palette.apply(material,direction,data)
 Proportions.apply(material,direction,data)

func load_game_parameters() -> void:
 source_text=FileAccess.get_file_as_string(_manifest_path())
 manifest=JSON.parse_string(source_text)
 var config: Dictionary=manifest.proportion_warp_by_direction.down
 head_drop=config.get("head_drop",0.0);head_width=config.get("head_width",0.0);body_width=config.body_width
 head_height=config.get("head_height",0.0);body_extension=config.body_extension;crown_compression=config.get("crown_compression",0.0)
 eye_upper_drop=config.get("eye_upper_drop",0.0);eye_lower_drop=config.get("eye_lower_drop",0.0)
 keep_original_height=is_equal_approx(crown_compression,maxf(0.0,.4*head_height+body_extension-.03))
 _refresh();status="已读取游戏里的当前比例。"
 notify_property_list_changed()

func save_to_game() -> void:
 await save_parameters(_manifest_path(),str(get_meta("proportion_collision_path","res://assets/character/collision_profile.json")))

func save_parameters(manifest_path: String,collision_path: String) -> void:
 if saving:return
 saving=true;status="正在保存参数并更新碰撞轮廓…"
 var current:=_write_profile(manifest_path)
 var collision: Dictionary=await CollisionBuilder.build(current,get_tree())
 var file:=FileAccess.open(collision_path,FileAccess.WRITE);file.store_string(JSON.stringify(collision,"  ",false)+"\n");file.close()
 manifest=current;saving=false;status="已保存。正在运行的游戏和 F6 预览会自动同步参数；碰撞轮廓已更新。"
 print(status)

func _write_profile(manifest_path: String) -> Dictionary:
 var text:=FileAccess.get_file_as_string(manifest_path)
 var current: Dictionary=JSON.parse_string(text)
 var config: Dictionary=current.proportion_warp_by_direction.down
 config.merge(profile(),true)
 var regex:=RegEx.new()
 regex.compile('"proportion_warp_by_direction"\\s*:\\s*\\{\\s*"down"\\s*:\\s*(\\{[^{}]*\\})')
 var match_result:=regex.search(text)
 var block:=JSON.stringify(config,"  ",false).replace("\n","\n    ")
 var file:=FileAccess.open(manifest_path,FileAccess.WRITE)
 file.store_string(text.substr(0,match_result.get_start(1))+block+text.substr(match_result.get_end(1)));file.close()
 current.proportion_warp_by_direction.down=config
 source_text=FileAccess.get_file_as_string(manifest_path)
 manifest=current
 return current
