extends SceneTree
## 渲染《晚安，鲸落港》为 res://assets/music/gal_goodnight.wav。
##
## 完全离线：先静音 Master 总线，不需要音频设备。
##   & "$env:USERPROFILE\Godot\Godot_v4.7.2-stable_win64_console.exe" `
##     --headless --audio-driver Dummy --path "D:\迅雷下载\大肥鱼_数值战斗怪物_v22" `
##     --script res://tools/gal_piano/render_goodnight.gd

const Score := preload("res://tools/gal_piano/score_goodnight.gd")
const Synth := preload("res://tools/gal_piano/piano_synth.gd")
const OUTPUT := "res://assets/music/gal_goodnight.wav"


func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	call_deferred("_render")


func _render() -> void:
	var score: Dictionary = Score.build()
	var roles := {}
	for n: Dictionary in score.notes:
		roles[n.role] = int(roles.get(n.role, 0)) + 1
	print("SCORE %s  %d 小节  %.1f 秒  音符 %d（%s）" % [
		score.title, score.bar_count, score.duration, score.notes.size(),
		", ".join(roles.keys().map(func(k): return "%s %d" % [k, roles[k]])),
	])
	var synth := Synth.new()
	var wav: AudioStreamWAV = synth.render(score)
	var error := wav.save_to_wav(OUTPUT)
	if error != OK:
		push_error("PIANO_SAVE_FAILED " + str(error))
		quit(1)
		return
	print("PIANO_SAVED ", OUTPUT, " ", JSON.stringify(synth.last_report))
	quit(0)
