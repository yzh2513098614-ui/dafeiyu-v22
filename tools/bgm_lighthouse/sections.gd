extends SceneTree
## 按段统计已渲染 wav 的 RMS / 峰值 —— 用于验证「编排弧线」是否真的落到音频里。
##
## 听感验收由用户完成；这个脚本只看一件客观的事：每一段是不是按设计的力度层级在走。
## 《灯塔，音乐盒变奏》的 40 小节被切成 5 段（每段 8 小节 = 24 秒），
## 期望的弧线是：主题 < 变奏一 < 变奏二 < 变奏三 > 尾声。
##
## 用法：
##   ... --script res://tools/bgm_lighthouse/sections.gd -- <wav 路径> [段数]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("需要 wav 路径")
		quit(1)
		return
	var path := String(args[0])
	var parts := 5
	if args.size() > 1 and String(args[1]).is_valid_int():
		parts = maxi(1, int(args[1]))

	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		push_error("读取失败: " + path)
		quit(1)
		return

	var pos := 12
	var ch := 0
	var rate := 0
	var off := -1
	var dlen := 0
	while pos + 8 <= bytes.size():
		var cid := bytes.decode_u32(pos)
		var clen := int(bytes.decode_u32(pos + 4))
		var body := pos + 8
		if cid == 0x20746D66:
			ch = bytes.decode_u16(body + 2)
			rate = int(bytes.decode_u32(body + 4))
		elif cid == 0x61746164:
			off = body
			dlen = clen
		pos = body + clen + (clen & 1)
	if off < 0 or ch < 1:
		push_error("不是可解析的 PCM wav")
		quit(1)
		return

	var frame_bytes := ch * 2
	var frames := mini(dlen / frame_bytes, (bytes.size() - off) / frame_bytes)
	var per := frames / parts
	print("── 分段统计 ── %s" % path.get_file())
	print("%-4s %8s %8s %9s %9s" % ["段", "起点s", "时长s", "RMS dB", "峰值 dB"])
	var rms_list: Array = []
	for p in parts:
		var from := p * per
		var to := mini(frames, from + per)
		var sumsq := 0.0
		var peak := 0.0
		var n := 0
		for i in range(from, to):
			var l := float(bytes.decode_s16(off + i * frame_bytes)) / 32767.0
			var r := float(bytes.decode_s16(off + i * frame_bytes + 2)) / 32767.0 if ch > 1 else l
			var s := (l + r) * 0.5
			sumsq += s * s
			var a: float = absf(s)
			if a > peak:
				peak = a
			n += 1
		var rms_db := linear_to_db(maxf(sqrt(sumsq / float(maxi(1, n))), 1e-9))
		var peak_db := linear_to_db(maxf(peak, 1e-9))
		rms_list.append(rms_db)
		print("%-4d %8.1f %8.1f %9.2f %9.2f" % [p + 1, float(from) / float(rate), float(n) / float(rate), rms_db, peak_db])

	# 期望弧线：前面逐段加到高潮，末段（尾声）回落
	var trend: Array = []
	var top := 0
	for p in parts:
		if p > 0:
			trend.append("↑" if float(rms_list[p]) > float(rms_list[p - 1]) else "↓")
		if float(rms_list[p]) > float(rms_list[top]):
			top = p
	print("逐段走向 %s ；最响段 = 第 %d 段" % [" ".join(trend), top + 1])
	var coda_ok := top < parts - 1 and float(rms_list[parts - 1]) < float(rms_list[top])
	print("尾声回落：%s（第 %d 段 %.2f dB < 第 %d 段 %.2f dB）" % [
		"符合预期" if coda_ok else "★不符合预期",
		parts, float(rms_list[parts - 1]), top + 1, float(rms_list[top])])
	quit(0)
