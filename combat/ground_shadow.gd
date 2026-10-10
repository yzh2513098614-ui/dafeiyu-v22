extends RefCounted
## 地面接触阴影（2.5D 场景通用的「立绘踩在地上」视觉）
##
## 为什么不用真实阴影：立绘是 Sprite3D 平面，方向光投出来的是一块薄片，
## 从正交俯视相机看几乎没有形状。本项目一直用的是「贴地柔和椭圆」的假阴影，
## 配方原先写在 room_3d.gd 的玩家初始化里。这里把它抽成共用件，
## 让街道 / 试炼场上的遭遇点和房间里的玩家用同一套柔和度与透明度 ——
## 否则两边各写一份，改了一处忘了另一处，同一个世界里会出现两种软硬不同的影子。
##
## 阴影平面朝上（PlaneMesh 默认 FACE_Y），只做 ALPHA 混合、不写深度，
## 因此不会遮挡立在它上面的立绘，也不会在地板接缝处产生 Z-fighting。

## 与 room_3d.gd 玩家影子完全一致的着色配方：内外两层软边叠加。
const SHADER_CODE := "shader_type spatial;render_mode unshaded,cull_disabled,depth_draw_never;void fragment(){float d=length((UV-vec2(0.5))*2.0);float outer=1.0-smoothstep(0.32,1.0,d);float core=1.0-smoothstep(0.0,0.56,d);ALBEDO=vec3(0.08,0.11,0.15);ALPHA=outer*0.18+core*0.18;}"

## 影子相对立绘世界高度的比例。
## 0.78 x 0.45 是照玩家立绘反推的：玩家影子写成 1.22 x 0.70，
## 而玩家立绘世界高度约 1.6，1.6 * 0.78 ≈ 1.25、1.6 * 0.45 ≈ 0.72，两边对得上。
const WIDTH_RATIO := 0.78
const DEPTH_RATIO := 0.45

static var _shader: Shader

static func _shared_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader

static func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shared_shader()
	return m

## 在 parent 下挂一块贴合地面的柔和阴影。
## world_height 传立绘的世界高度（像素尺寸 x pixel_size），影子会按比例跟着大小走。
static func attach(parent: Node3D, world_height: float, floor_y: float = 0.018) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "GroundShadow"
	var plane := PlaneMesh.new()
	plane.size = Vector2(maxf(0.2, world_height * WIDTH_RATIO), maxf(0.12, world_height * DEPTH_RATIO))
	mesh.mesh = plane
	mesh.position.y = floor_y
	mesh.material_override = material()
	# 假阴影，不能再让方向光去投一次，否则地上会有两层影
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh
