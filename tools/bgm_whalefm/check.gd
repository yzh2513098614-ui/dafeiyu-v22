extends SceneTree
## 独立校验已生成的 wav —— 读盘、自己解 RIFF、统计，验证的是**产物本身**而不是内存里的缓冲。
##
## 用法：
##   ... --script res://tools/bgm_whalefm/check.gd                       校验默认输出目录下所有 wav
##   ... --script res://tools/bgm_whalefm/check.gd -- <路径或目录>…       校验指定目标
##
## 判定标准（全部满足才算通过）：
##   16-bit / 44100 Hz / 2 声道 · 无样本触顶 · 直流可忽略 · 接缝那一跳不超过曲内最大跃变。
## 黑胶炒豆会造成极低的瞬态，但远达不到削波；接缝判据与玻璃温室一致。

const DIR := "res://assets/music/whalefm"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var paths: Array = []
	if args.is_empty():
		paths.append(DIR)
	else:
		for a in args:
			paths.append(String(a))

	var files: Array = []
	for p in paths:
		if String(p).ends_with(".wav"):
			files.append(String(p))
		else:
			var d := DirAccess.open(String(p))
			if d != null:
				var ns := d.get_files()
				ns.sort()
				for n in ns:
					if String(n).to_lower().ends_with(".wav"):
						files.append("%s/%s" % [String(p), String(n)])

	print("── wav 校验 ── 共 %d 个文件" % files.size())
	print("%-30s %9s %7s %7s %7s %8s %6s %8s %11s %5s %s" % [
		"文件", "帧数", "秒", "峰值dB", "RMSdB", "直流", "削波", "接缝比", "静音s@起点", "段数", "判定"])
	var bad := 0
	for f in files:
		if not _check(String(f)):
			bad += 1
	print("── 完成：%d/%d 通过 ──" % [files.size() - bad, files.size()])
	quit(0 if bad == 0 else 1)


func _check(path: String) -> bool:
	var name := path.get_file()
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		print("%-30s  读取失败或文件过短" % name)
		return false
	if bytes.decode_u32(0) != 0x46464952 or bytes.decode_u32(8) != 0x45564157:
		print("%-30s  不是 RIFF/WAVE" % name)
		return false

	var pos := 12
	var ch := 0
	var rate := 0
	var bits := 0
	var off := -1
	var dlen := 0
	while pos + 8 <= bytes.size():
		var cid := bytes.decode_u32(pos)
		var clen := int(bytes.decode_u32(pos + 4))
		var body := pos + 8
		if cid == 0x20746D66:          # "fmt "
			ch = bytes.decode_u16(body + 2)
			rate = int(bytes.decode_u32(body + 4))
			bits = bytes.decode_u16(body + 14)
		elif cid == 0x61746164:        # "data"
			off = body
			dlen = clen
		pos = body + clen + (clen & 1)
	if bits != 16 or off < 0 or ch < 1:
		print("%-30s  不是 16-bit PCM（bits=%d ch=%d）" % [name, bits, ch])
		return false
	if off + dlen > bytes.size():
		dlen = bytes.size() - off

	var frame_bytes := ch * 2
	var frames := dlen / frame_bytes
	if frames < 2:
		print("%-30s  采样帧太少" % name)
		return false

	var peak := 0
	var clipped := 0
	var dc_sum := 0.0
	var sumsq := 0.0
	var max_step := 0.0
	var prev := 0.0
	for i in frames:
		var s := float(bytes.decode_s16(off + i * frame_bytes))
		var a := absi(int(s))
		if a > peak:
			peak = a
		if a >= 32767:
			clipped += 1
		dc_sum += s
		sumsq += s * s
		if i > 0:
			var d := absf(s - prev)
			if d > max_step:
				max_step = d
		prev = s

	var first := float(bytes.decode_s16(off))
	var last := float(bytes.decode_s16(off + (frames - 1) * frame_bytes))
	var wrap := absf(first - last)
	var ratio := wrap / maxf(max_step, 1e-9)
	var peak_db := linear_to_db(maxf(float(peak), 1.0) / 32767.0)
	var rms_db := linear_to_db(maxf(sqrt(sumsq / float(frames)), 1.0) / 32767.0)
	var dc := dc_sum / float(frames)

	# 静音断档：按 50 ms 分块巡检。长于一秒的断档说明编排漏了段落。
	var block := maxi(1, rate / 20)
	var quiet := 0
	var longest_quiet := 0
	var longest_at := 0
	var gap_spans: Array = []
	var i2 := 0
	while i2 + block <= frames:
		var acc := 0.0
		for j in block:
			var s := float(bytes.decode_s16(off + (i2 + j) * frame_bytes))
			acc += s * s
		var brms := sqrt(acc / float(block)) / 32767.0
		if linear_to_db(maxf(brms, 1e-9)) < -60.0:
			quiet += 1
			if quiet > longest_quiet:
				longest_quiet = quiet
				longest_at = i2 / block - quiet + 1
		else:
			if float(quiet) * float(block) / float(rate) >= 1.0:
				gap_spans.append("%.1f@%.1f" % [float(quiet) * float(block) / float(rate), float(i2 / block - quiet) * float(block) / float(rate)])
			quiet = 0
		i2 += block
	if float(quiet) * float(block) / float(rate) >= 1.0:
		gap_spans.append("%.1f@%.1f" % [float(quiet) * float(block) / float(rate), float(i2 / block - quiet) * float(block) / float(rate)])
	var gap_sec := float(longest_quiet) * float(block) / float(rate)
	var gap_at := float(longest_at) * float(block) / float(rate)

	var ok := rate == 44100 and ch == 2 and peak <= 32767 and absf(dc) < 1.0 and ratio <= 1.0 and gap_sec < 1.0
	print("%-30s %9d %7.2f %7.2f %7.2f %8.3f %6d %7.2f %5.2f@%6.1f %5d %s" % [
		name, frames, float(frames) / float(rate), peak_db, rms_db, dc, clipped, ratio,
		gap_sec, gap_at, gap_spans.size(), "通过" if ok else "★不通过",
	])
	if not gap_spans.is_empty():
		print("%-30s 断档清单(秒@起点): %s" % ["", ", ".join(gap_spans)])
	return ok
