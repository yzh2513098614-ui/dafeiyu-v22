extends RefCounted
## 把卡图从「插画」转成真正的像素画。
##
## ── 为什么需要这个 ──
## 这套卡图原本是 512×704 的插画缩到 128×176，**独立色 16845 个**
## （像素画通常几十个色；16845 等于几乎每个像素都是独有的颜色）。
## 再配上 card_painting.gdshader 里的 filter_linear、以及把 110×94 的裁切区
## 拉成 140×92（横向 ×1.27、纵向 ×0.98）的非等比拉伸，
## 在一屏像素 UI 里一眼就是「贴了一张照片，而且脸被拉宽了」。
##
## 素材包自带的 cards_pixel 目录只是「尺寸小」，独立色 17689 —— 同样不是像素画，
## 所以不能靠换图解决，必须真的转。
##
## ── 做法（两步，缺一不可）──
##   1. 降采样到 55×47，显示时 2 倍整数放大：像素格子才和 UI 其它部分一样粗。
##      110→55、94→47 都是正好 2 倍，因此这是一次干净的 2×2 平均，不会走样。
##   2. 每通道 posterize 到 6 级：颜色数从 1.6 万压到几百，渐变变成色带。
## 只做 1 会得到「一张小照片」；只做 2 会得到「一张糊掉的插画」。

const SRC_DIR := "res://assets/cards/"
const DST_DIR := "res://assets/cards_pixel/"
const GROUPS := ["base", "character", "tactics"]

## 卡牌战斗显示的是**插画窗口**，不是整张卡。
##
## 原来贴的是整张卡（含烘死的金边、标题绶带和下方说明板）：缩到 56×77 之后
## 那两处变成一团糊字，还被压在代码画的姓名/说明下面 —— 两层文字叠在一起。
## 所以这里只取插画窗口：110×94 → 50×43，显示时正好 2 倍 = 100×86。
## 金边和文字交给代码画（代码画的是矢量硬边，不会跟着插画一起被像素化）。
##
## 窗口坐标和 card_painting.gdshader 里的 illustration 完全一致 —— 那个 shader
## 已经不再需要（裁切改在转换阶段做），这里保留数值只为对得上历史。
const ILLUSTRATION := Rect2i(9, 38, 110, 94)
const PIXEL_SIZE := Vector2i(50, 43)
## 每通道色阶数。6 级 = 216 色上限，够留住角色配色，又能把渐变切成明显色带。
const LEVELS := 6

static func write_all() -> Dictionary:
	var made := 0
	var failed: Array = []
	var colors_before := 0
	var colors_after := 0
	var sample := 0
	for group in GROUPS:
		var gname: String = str(group)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST_DIR + gname))
		for raw_name in _card_names(gname):
			var name: String = str(raw_name)
			var src: String = SRC_DIR + gname + "/" + name + ".png"
			var img := Image.load_from_file(ProjectSettings.globalize_path(src))
			if img == null:
				failed.append(src)
				continue
			var crop: Image = img.get_region(ILLUSTRATION)
			var before := _count_colors(crop)
			crop.resize(PIXEL_SIZE.x, PIXEL_SIZE.y, Image.INTERPOLATE_BILINEAR)
			_posterize(crop)
			var after := _count_colors(crop)
			var dst: String = DST_DIR + gname + "/" + name + ".png"
			var err: int = crop.save_png(ProjectSettings.globalize_path(dst))
			if err != OK:
				failed.append(dst)
				continue
			made += 1
			if sample < 3:
				colors_before += before
				colors_after += after
				sample += 1
	return {
		"written": made,
		"failed": failed,
		"pixel_size": [PIXEL_SIZE.x, PIXEL_SIZE.y],
		"levels": LEVELS,
		"avg_colors_before": colors_before / maxi(1, sample),
		"avg_colors_after": colors_after / maxi(1, sample),
		"display_size": [PIXEL_SIZE.x * 2, PIXEL_SIZE.y * 2],
	}

static func _card_names(group: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(SRC_DIR + group)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".png"):
			out.append(file.get_basename())
	out.sort()
	return out

## 每通道压到 LEVELS 级。alpha 不动 —— 卡图窗口内基本不透明，
## 但边缘有抗锯齿残留，动 alpha 会啃掉一圈。
static func _posterize(img: Image) -> void:
	var steps := float(LEVELS - 1)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c.r = roundf(c.r * steps) / steps
			c.g = roundf(c.g * steps) / steps
			c.b = roundf(c.b * steps) / steps
			img.set_pixel(x, y, c)

static func _count_colors(img: Image) -> int:
	var seen := {}
	for y in img.get_height():
		for x in img.get_width():
			seen[img.get_pixel(x, y).to_rgba32()] = true
	return seen.size()
