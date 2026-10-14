extends SceneTree
## 量化「线性过滤白边」隐患：统计紧贴不透明轮廓、且 RGB 仍是近白的透明像素。
## 这些像素就是 GPU 用 TEXTURE_FILTER_LINEAR 缩小采样时把白色插值进边缘的来源。
const BEFORE := "res://备份/20261014_立绘重抠前/transparent/"
const AFTER := "res://assets/dialogue/downloaded_20261014/transparent/"
const REPORT := "res://tools/measure_portrait_halo.json"
const NAMES = ["01_listen", "02_kiss", "03_talk", "04_think", "05_relief", "06_shy", "07_expectant", "08_cheer", "09_happy", "10_concern", "11_side_welcome"]
const NEAR_WHITE := 235


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var rows: Array = []
	for name in NAMES:
		rows.append({
			"file": name + ".png",
			"before": halo(BEFORE + name + ".png"),
			"after": halo(AFTER + name + ".png"),
		})
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "  "))
	f.close()
	quit()


func halo(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return -1
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var total := w * h
	var opaque := PackedByteArray()
	opaque.resize(total)
	for i in total:
		if d[i * 4 + 3] >= 250:
			opaque[i] = 1
	var count := 0
	for y in h:
		for x in w:
			var i := y * w + x
			if opaque[i] == 1:
				continue
			var o := i * 4
			var mn := d[o]
			if d[o + 1] < mn:
				mn = d[o + 1]
			if d[o + 2] < mn:
				mn = d[o + 2]
			if mn < NEAR_WHITE:
				continue
			var touch := false
			if x > 0 and opaque[i - 1] == 1:
				touch = true
			elif x < w - 1 and opaque[i + 1] == 1:
				touch = true
			elif y > 0 and opaque[i - w] == 1:
				touch = true
			elif y < h - 1 and opaque[i + w] == 1:
				touch = true
			if touch:
				count += 1
	return count
