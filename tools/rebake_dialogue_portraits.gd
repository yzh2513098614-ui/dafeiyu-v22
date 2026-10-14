extends SceneTree
## 白底对话立绘重抠：修掉「发丝缝隙白块」与「轮廓白边」。
##
## 输入（白底原图，不改）：assets/dialogue/downloaded_20261014/<NN>_*.png
## 输出（覆盖为真透明）：assets/dialogue/downloaded_20261014/transparent/<NN>_*.png
##
## 白边有两个独立病因，必须分开治：
##
## A 抠像残留 —— 白底是 250~255 的微噪声白，而围裙 / 荷叶边 / 袜子这些「该保留的
##   白」也是 250~252，纯阈值根本分不开。旧产物只扣掉了接近纯白的部分，抗锯齿
##   过渡带（min 180~245）留在画面上，就是发丝缝隙里的白块和轮廓上的白边。
##   → 从画布四边泛洪判定背景：白衣服被描边和阴影封住，不与四边连通，天然安全；
##     再把轮廓向内收 ERODE 像素，直接吃掉残留的过渡带。
##
## B 线性过滤 —— 旧产物 99.8% 的透明像素 RGB 还留着白色。立绘在游戏里被缩到约
##   一半（1086→569）用 TEXTURE_FILTER_LINEAR 采样，2x2 插值会把白色混进边缘，
##   就是那圈亮白边。
##   → alpha bleed：把核心色向外填 BLEED 像素，透明区不再有白色可供插值。
const SRC := "res://assets/dialogue/downloaded_20261014/"
const OUT := "res://assets/dialogue/downloaded_20261014/transparent/"
const REPORT := "res://tools/rebake_dialogue_portraits.json"
const NAMES = ["01_listen", "02_kiss", "03_talk", "04_think", "05_relief", "06_shy", "07_expectant", "08_cheer", "09_happy", "10_concern", "11_side_welcome"]

const WHITE_MIN := 246   ## min(r,g,b) 达到此值才可能是背景白
const ERODE := 2         ## 轮廓内缩像素数，吃掉抠像残留的过渡带
const FEATHER := 1       ## 内缩后的 alpha 羽化宽度
const BLEED := 4         ## 核心色外扩像素数，消灭线性过滤白边
const MAXD := 12         ## 距离场上限，需覆盖 ERODE + FEATHER + BLEED


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	# REBAKE_ONLY=<name> 时只处理一张，报告另存 —— 便于逐张小批跑、出问题好定位
	var only := OS.get_environment("REBAKE_ONLY")
	var names: Array = NAMES if only.is_empty() else [only]
	var records: Array = []
	for name in names:
		records.append(bake(str(name)))
	var path := REPORT if only.is_empty() else REPORT.replace(".json", "_" + only + ".json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(records, "  "))
	f.close()
	print("REBAKE DONE ", records.size())
	quit()


func bake(name: String) -> Dictionary:
	var file := name + ".png"
	var rec := {"file": file, "before": metrics(OUT + file)}
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + file))
	if img == null:
		rec["error"] = "load_failed"
		push_error("读不到白底原图: " + SRC + file)
		return rec
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()

	# ---------- 0. 搬进 1px 边框的 padded 缓冲，之后全程免边界判断 ----------
	var W2 := w + 2
	var H2 := h + 2
	var total := W2 * H2
	var edge := PackedByteArray()
	edge.resize(W2 * 4)
	var side := PackedByteArray()
	side.resize(4)
	var pdata := PackedByteArray()
	pdata.append_array(edge)
	for y in h:
		pdata.append_array(side)
		pdata.append_array(data.slice(y * w * 4, (y + 1) * w * 4))
		pdata.append_array(side)
	pdata.append_array(edge)

	# ---------- 1. 白色候选 ----------
	var white := PackedByteArray()
	white.resize(total)
	for i in total:
		var o := i * 4
		var mn := pdata[o]
		if pdata[o + 1] < mn:
			mn = pdata[o + 1]
		if pdata[o + 2] < mn:
			mn = pdata[o + 2]
		if mn >= WHITE_MIN:
			white[i] = 1

	# ---------- 2. 从画布四边泛洪：与边框连通的白色才是背景 ----------
	var bg := PackedByteArray()
	bg.resize(total)
	var stack := PackedInt32Array()
	for x in w:
		stack.push_back(W2 + 1 + x)
		stack.push_back(h * W2 + 1 + x)
	for y in h:
		stack.push_back((y + 1) * W2 + 1)
		stack.push_back((y + 1) * W2 + w)
	var seeds := stack.duplicate()
	stack.clear()
	for p in seeds:
		if white[p] == 1 and bg[p] == 0:
			bg[p] = 1
			stack.push_back(p)
	var shead := 0
	while shead < stack.size():
		var p := stack[shead]
		shead += 1
		if white[p - 1] == 1 and bg[p - 1] == 0:
			bg[p - 1] = 1
			stack.push_back(p - 1)
		if white[p + 1] == 1 and bg[p + 1] == 0:
			bg[p + 1] = 1
			stack.push_back(p + 1)
		if white[p - W2] == 1 and bg[p - W2] == 0:
			bg[p - W2] = 1
			stack.push_back(p - W2)
		if white[p + W2] == 1 and bg[p + W2] == 0:
			bg[p + W2] = 1
			stack.push_back(p + W2)

	# ---------- 3. 距离场：到最近背景像素的步数 ----------
	var dist := PackedByteArray()
	dist.resize(total)
	dist.fill(255)
	for x in W2:
		dist[x] = 254
		dist[(H2 - 1) * W2 + x] = 254
	for y in H2:
		dist[y * W2] = 254
		dist[y * W2 + W2 - 1] = 254
	var queue := PackedInt32Array()
	for i in total:
		if bg[i] == 1:
			dist[i] = 0
			queue.push_back(i)
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var d := dist[p]
		if d >= MAXD:
			continue
		var nd := d + 1
		if dist[p - 1] == 255:
			dist[p - 1] = nd
			queue.push_back(p - 1)
		if dist[p + 1] == 255:
			dist[p + 1] = nd
			queue.push_back(p + 1)
		if dist[p - W2] == 255:
			dist[p - W2] = nd
			queue.push_back(p - W2)
		if dist[p + W2] == 255:
			dist[p + W2] = nd
			queue.push_back(p + W2)

	# ---------- 4. alpha：内缩 ERODE，再按距离羽化 ----------
	var alpha := PackedByteArray()
	alpha.resize(total)
	var core := PackedByteArray()
	core.resize(total)
	var ramp := float(FEATHER + 1)
	var opaque_at := ERODE + FEATHER + 1
	var background := 0
	var enclosed_white := 0
	for y in h:
		var prow := (y + 1) * W2 + 1
		for x in w:
			var p := prow + x
			var d := dist[p]
			if bg[p] == 1:
				background += 1
			elif white[p] == 1:
				enclosed_white += 1
			if d > ERODE:
				if d >= opaque_at:
					alpha[p] = 255
					core[p] = 1
				else:
					alpha[p] = int(round(255.0 * float(d - ERODE) / ramp))

	# ---------- 5. alpha bleed：核心色向外填，透明区不留白 ----------
	var level := PackedByteArray()
	level.resize(total)
	level.fill(255)
	for x in W2:
		level[x] = 0
		level[(H2 - 1) * W2 + x] = 0
	for y in H2:
		level[y * W2] = 0
		level[y * W2 + W2 - 1] = 0
	var bleedq := PackedInt32Array()
	for i in total:
		if core[i] == 1:
			level[i] = 0
			bleedq.push_back(i)
	var bhead := 0
	while bhead < bleedq.size():
		var p := bleedq[bhead]
		bhead += 1
		var l := level[p]
		if l >= BLEED:
			continue
		var nl := l + 1
		var o := p * 4
		if level[p - 1] == 255:
			level[p - 1] = nl
			copy_rgb(pdata, o, (p - 1) * 4)
			bleedq.push_back(p - 1)
		if level[p + 1] == 255:
			level[p + 1] = nl
			copy_rgb(pdata, o, (p + 1) * 4)
			bleedq.push_back(p + 1)
		if level[p - W2] == 255:
			level[p - W2] = nl
			copy_rgb(pdata, o, (p - W2) * 4)
			bleedq.push_back(p - W2)
		if level[p + W2] == 255:
			level[p + W2] = nl
			copy_rgb(pdata, o, (p + W2) * 4)
			bleedq.push_back(p + W2)

	# ---------- 6. 回到真实尺寸并写出 ----------
	var out := PackedByteArray()
	for y in h:
		var start := ((y + 1) * W2 + 1) * 4
		out.append_array(pdata.slice(start, start + w * 4))
	for y in h:
		var prow := (y + 1) * W2 + 1
		var dst := y * w * 4
		for x in w:
			out[dst + x * 4 + 3] = alpha[prow + x]
	var out_path := ProjectSettings.globalize_path(OUT + file)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, out)
	if img.save_png(out_path) != OK:
		rec["error"] = "save_failed"
		return rec
	rec["size"] = [w, h]
	rec["background"] = background
	rec["enclosed_white_kept"] = enclosed_white
	rec["after"] = metrics(OUT + file)
	print("REBAKE ", name, " bg=", background, " kept_white=", enclosed_white)
	return rec


func copy_rgb(buf: PackedByteArray, from_off: int, to_off: int) -> void:
	buf[to_off] = buf[from_off]
	buf[to_off + 1] = buf[from_off + 1]
	buf[to_off + 2] = buf[from_off + 2]


## 量三个指标：残留白块、轮廓白边、透明区白 RGB（线性过滤隐患）
func metrics(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	var opaque_nearwhite := 0
	var rim_light := 0
	var clear_nearwhite := 0
	for y in h:
		for x in w:
			var i := (y * w + x) * 4
			var a := d[i + 3]
			var mn := d[i]
			if d[i + 1] < mn:
				mn = d[i + 1]
			if d[i + 2] < mn:
				mn = d[i + 2]
			if a == 0:
				if mn >= 245:
					clear_nearwhite += 1
				continue
			if a >= 250 and mn >= 235:
				opaque_nearwhite += 1
			if a >= 250 and mn >= 225:
				var touch := false
				if x > 0 and d[i - 4 + 3] == 0:
					touch = true
				if not touch and x < w - 1 and d[i + 4 + 3] == 0:
					touch = true
				if not touch and y > 0 and d[i - w * 4 + 3] == 0:
					touch = true
				if not touch and y < h - 1 and d[i + w * 4 + 3] == 0:
					touch = true
				if touch:
					rim_light += 1
	return {"opaque_nearwhite": opaque_nearwhite, "rim_light": rim_light, "clear_nearwhite": clear_nearwhite}
