extends SceneTree
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,note:String)->void:
 if not ok: failures+=1;push_error(note)
func run()->void:
 root.size=Vector2i(1448,1086)
 var cards:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
 var font:=load("res://assets/NotoSansSC.ttf")
 var holder:=Control.new();holder.theme=load("res://battle/battle_skin.gd").theme(font);root.add_child(holder)
 for entry in cards:
  var face=load("res://battle/card_face.gd").new();face.configure(entry);holder.add_child(face)
  await process_frame
  for child in face.get_children():
   if child is Panel and child.position.y>100:
    for label in child.get_children():
     if label is Label: print(str(entry.name)," ",label.size," footer=",child.position.y," font=",label.get_theme_font_size("font_size"));check(child.position.y+label.position.y+label.size.y <= face.size.y, str(entry.name)+" effect text fits card")
  face.queue_free()
 var engine=load("res://battle/battle_engine.gd").new(20261004)
 engine.add_ally({"id":"player","name":"大肥鱼","hp":100,"max_hp":100,"stamina":100,"max_stamina":100,"atk":10,"def":7})
 engine.add_foe({"id":"slime","kind":"slime","name":"海沫团","hp":100,"max_hp":100,"atk":3,"def":1})
 engine.enable_cards(cards)
 var screen=load("res://battle/battle_screen.gd").new();root.add_child(screen);screen.open(engine,{"title":"新卡牌界面检查"})
 for n in 8: await process_frame
 screen._finish_playback()
 for n in 3: await process_frame
 check(screen.card_panel.position.y+screen.card_panel.size.y <= screen.dash.dock.position.y,"hand stays above status dock")
 for face in screen.card_row.get_children(): check(face.size.y+8 <= screen.card_scroll.size.y,"full hand card fits with scrollbar")
 var before:=int(engine.round_no)
 screen.card_end_button.pressed.emit()
 check(int(engine.round_no)>before,"end-turn button advances round")
 screen._finish_playback()
 check(engine.hand.size()==5,"next turn deals five cards")
 screen.close();screen.queue_free()
 print("CUTE CARD LAYOUT FAILURES ",failures)
 quit(0 if failures==0 else 1)

