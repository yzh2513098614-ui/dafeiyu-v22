extends RefCounted
## 屏幕适配辅助（配合 project.godot 的 window/stretch/aspect="expand"）
##
## 设计画布是 1448x1086（4:3）。改成 expand 后，画布宽度会随窗口比例伸展：
## 1920x1080 全屏下逻辑画布约 1931x1086，高度不变、宽度变大。
## 因此所有「按 1448 宽写死像素坐标」的元素都要改成锚定，否则会全部挤在左侧。
##
## 三种情形：
##   fill()       遮罩层 / 根画布 —— 必须铺满，否则右侧会露出一条没被盖住的画面
##   pin_right()  原本贴右边缘的元素（立绘、时钟、导览按钮…）
##   pin_center() 原本在设计里左右对称居中的模态框，居中锚定后在任何宽度都保持居中
##   pin_wide()   原本左右拉通的横条（对话框、底部按钮条…）
##
## 注意：锚定要「先设 anchors 再设 offsets」，否则偏移量会按旧锚点解释而错位。

static func fill(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## 贴父级右边缘：width 宽度、right_margin 距右边距、top/height 纵向绝对像素
static func pin_right(node: Control, width: float, right_margin: float, top: float, height: float) -> void:
	node.anchor_left = 1.0
	node.anchor_right = 1.0
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = -(right_margin + width)
	node.offset_right = -right_margin
	node.offset_top = top
	node.offset_bottom = top + height

## 贴父级左边缘：width 宽度、left_margin 距左边距、top/height 纵向绝对像素。
## 和 pin_right 对称。注意不能拿 pin_design 代替：pin_design 保持的是「相对画布中心」
## 的偏移，画布一加宽它就跟着往右漂；贴边的元素必须用 pin_left 才不会跑掉。
static func pin_left(node: Control, width: float, left_margin: float, top: float, height: float) -> void:
	node.anchor_left = 0.0
	node.anchor_right = 0.0
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = left_margin
	node.offset_right = left_margin + width
	node.offset_top = top
	node.offset_bottom = top + height

## 在父级内水平居中：width 宽度、top/height 纵向绝对像素
static func pin_center(node: Control, width: float, top: float, height: float) -> void:
	node.anchor_left = 0.5
	node.anchor_right = 0.5
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = -width * 0.5
	node.offset_right = width * 0.5
	node.offset_top = top
	node.offset_bottom = top + height

## 左右拉通：left/right 为两侧边距，top/height 纵向绝对像素
static func pin_wide(node: Control, left: float, right: float, top: float, height: float) -> void:
	node.anchor_left = 0.0
	node.anchor_right = 1.0
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = left
	node.offset_right = -right
	node.offset_top = top
	node.offset_bottom = top + height

## 按「设计画布坐标」锚定：元素保持它相对设计画布中心的原位置。
##
## 用于那些在设计里并非贴边、而是成组排布的横排元素（底部按钮条、顶部导航按钮）——
## 单独逐个 pin_right 会把它们拆散、破坏间距；用这个函数则整组随画布加宽而同步外移，
## 间距不变，并且随窗口尺寸自适应（不像直接改 position 那样把位移写死）。
## design_x 是该元素在 1448 宽设计画布里的原始 x。
static func pin_design(node: Control, design_x: float, top: float, width: float, height: float, ref_width: float = 1448.0) -> void:
	node.anchor_left = 0.5
	node.anchor_right = 0.5
	node.anchor_top = 0.0
	node.anchor_bottom = 0.0
	var offset := (design_x + width * 0.5) - ref_width * 0.5
	node.offset_left = offset - width * 0.5
	node.offset_right = offset + width * 0.5
	node.offset_top = top
	node.offset_bottom = top + height
