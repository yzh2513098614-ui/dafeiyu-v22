extends SceneTree
var game
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 checks+=1
 if value:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)
func run() -> void:
 var prefs=root.get_node("HarborPrefs")
 prefs.starting_place="city";prefs.continue_game=false
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game)
 for i in 4:await physics_frame
 var d=game.dialogue_controller
 d.state={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]}
 check(game.locations.size()==9,"existing city and eight floors preserved")
 check(d.stories.size()==11,"eleven context dialogue topics loaded")
 for id in d.stories:
  var story: Dictionary=d.stories[id]
  check(story.nodes.has(story.start),"valid start for "+id)
  for n in story.nodes.values():
   if n.has("next"):check(story.nodes.has(n.next),"valid dialogue next")
   for c in n.get("choices",[]):check(story.nodes.has(c.next),"valid choice branch")
 d.context={"room":"测试房间","object":"书桌"};d.start("welcome")
 check(d.active and game.dialog_open and d.root.visible,"dialogue takes focus and shows overlay")
 check(d.is_typing(),"line initially types instead of appearing fully")
 d.advance();var history_count: int=d.state.history.size()
 check(not d.is_typing() and history_count==1,"first advance reveals the current line")
 d._process(.5)
 check(d.text_label.visible_characters==-1 and d.state.history.size()==history_count,"completed line remains complete without duplicate log")
 d.advance();d.advance()
 check(d.current_node=="ask" and d.choice_panel.visible and d.choice_buttons.size()==3,"choices appear only after their line completes")
 d.set_auto(true);d._process(20)
 check(d.current_node=="ask","auto playback never chooses an option")
 var before: Vector3=game.player.position
 game.movement=Vector2.UP
 var w:=InputEventKey.new();w.physical_keycode=KEY_W;w.keycode=KEY_W;w.pressed=true;root.push_input(w)
 for i in 5:await physics_frame
 var released_w: InputEventKey=w.duplicate();released_w.pressed=false;root.push_input(released_w);game.movement=Vector2.ZERO
 check(game.player.position.distance_to(before)<.001,"walking input cannot move player during conversation")
 var branch:=InputEventKey.new();branch.physical_keycode=KEY_2;branch.keycode=KEY_2;branch.pressed=true;root.push_input(branch)
 await process_frame
 var released_branch: InputEventKey=branch.duplicate();released_branch.pressed=false;root.push_input(released_branch)
 check(d.current_node=="guide" and d.state.flags.has("route_community"),"number-key choice selects and persists correct branch")
 check(game.location_id=="city" and game.route_destination=="community_1" and game.route_steps.size()==2,"branch marks actual route without changing scene")
 d.advance();d.set_auto(true);d.show_backlog();var n: String=d.current_node
 d._process(20)
 check(d.current_node==n and d.backlog.visible,"backlog suspends automatic advance")
 d.hide_backlog();d.close()
 check(not d.active and not game.dialog_open and not d.root.visible,"closing restores game control")
 var saved: Dictionary=d.state.duplicate(true)
 d.state={};d._load_state()
 check(d.state==JSON.parse_string(JSON.stringify(saved)),"dialogue bookmark choices and history survive disk reload")
 check(d.resume() and d.current_node=="guide","resume restores the actual saved branch")
 d.advance();d.advance();d.advance();d.advance()
 check(not d.active and d.state.seen.has("welcome") and d.state.bookmark.is_empty(),"finishing story marks read and clears bookmark")
 d.start_topic()
 check(d.current_story=="harbor","completed welcome changes subsequent conversation")
 d.advance();d.advance();d.advance()
 var old: Dictionary=d.state.duplicate(true);var original: String=d.save_path
 d.save_path="user://uncreated_dialogue_directory/cannot_save.json";d.choose(0)
 check(d.current_node=="ask" and d.state==old,"failed choice save rolls back flags bookmark and history")
 d.save_path=original
 var expected: String=str(d.current.choices[0].next)
 d.choice_buttons[0].pressed.emit()
 check(d.current_node==expected,"clicking the actual choice button safely advances its branch")
 var new_choices: Array=d.current.get("choices",[])
 check(d.choice_buttons.size()==new_choices.size(),"previous choice buttons are removed after clicking")
 d.close()
 var book: Node3D=game._prop("bookcase",Vector3(0,0,-5))
 d.start_context(book);d.advance()
 check(d.current_story=="books" and not d.text_label.text.contains("{object}"),"object interaction selects topic and resolves name")
 d.close();game._travel("apt_2")
 check(is_instance_valid(d.companion) and d.companion.get_parent()==game.world,"travelling replaces companion in new floor")
 d.start_topic();check(d.current_story=="home","location selects apartment dialogue")
 d.close()
 if not d.portrait_regions.is_empty():
  check(d.portrait_regions.size()==3,"three portrait expressions integrated")
  var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dialogue/portraits.json"))
  check(metadata.method=="original_resolution_rgba" and not metadata.resized and not metadata.downsampled,"original-resolution material has no resizing or downsampling")
  for tex in d.portrait_regions.values():check(tex.get_width()==576 and tex.get_height()==1056,"full-resolution576x1056 portrait uploaded directly")
 print("DIALOGUE CHECKS ",checks," PASSED ",checks-failures," FAILED ",failures)
 quit(0 if failures==0 else 1)
