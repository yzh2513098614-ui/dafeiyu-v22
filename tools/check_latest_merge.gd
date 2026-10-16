extends SceneTree
## Integration checks in isolated inventory, dialogue and world-save files.
var game
var failures:=0
var checks: Array=[]
const OUT="res://预览/最新版本合并/"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 checks.append({"ok":ok,"check":message})
 if not ok:failures+=1;push_error(message)
 else:print("PASS ",message)
func frames(count: int=3) -> void:
 for i in count:await process_frame
func measure(node: Node,result: Dictionary) -> void:
 if node==game.player:return
 if game.dialogue_controller and node==game.dialogue_controller.companion:return
 if node is Sprite3D or node is AnimatedSprite3D:result.images+=1
 if node is MeshInstance3D and node.mesh:result.meshes+=1
 for child in node.get_children():measure(child,result)
func shot(name: String) -> void:
 if DisplayServer.get_name()=="headless":return
 await frames(5);RenderingServer.force_draw()
 root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
 if not "--test-merge" in OS.get_cmdline_user_args() or not "--capture-ui" in OS.get_cmdline_user_args() or not "--capture-dialogue" in OS.get_cmdline_user_args():quit(2);return
 root.size=Vector2i(1000,750)
 DirAccess.make_dir_recursive_absolute(OUT)
 var prefs=root.get_node("HarborPrefs");prefs.starting_place="city";prefs.continue_game=false;prefs.values.fullscreen=false;prefs.values.follow=true;prefs.values.day_cycle=true
 var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);await frames()
 await shot("01_最新开场");menu._show_page("journey");await frames()
 check(menu.cards.size()==8,"latest title screen includes eight departure choices")
 await shot("01b_八个出发地点");menu.free()
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await frames(8)
 game.dialogue_controller.close();game.set_physics_process(false);game.atmosphere.set_process(false)
 check(prefs.world_save_path=="user://whale_merge_test.json" and game.loot.save_path.contains("preview"),"integration checks never overwrite player saves")
 check(game.locations.has("garden") and game.locations.has("obs_3") and game.locations.has("music_2"),"latest game retains all expanded maps")
 var locations: Array=["city","apt_1","apt_2","apt_3","community_1","community_2","inn_1","inn_2","inn_3","garden","market","gallery","obs_1","obs_2","obs_3","music_1","music_2"]
 for place in locations:
  game._travel(place);await frames(1)
  var counts={"images":0,"meshes":0};measure(game.world,counts)
  check(counts.images==0 and counts.meshes>50,place+": scene contains solid 3D environment")
  if game.locations[place].type=="floor":check(game.shell.find_children("RoomTheme_*","Node3D",false,false).size()==6,place+": six separately dressed rooms")
 check(game.character_manifest.atlas_order.size()==8 and game.character_manifest.has("frames_by_state"),"latest eight-direction AI image animation stays installed")
 check(game.avatar.material_override==game.character_material and game.character_material.shader.resource_path=="res://character/character_depth.gdshader","latest character transparency and depth shader retained")
 game._travel("city");game.overview_mode=false;game.view_size=10;game.view_center=Vector3(0,0,8);game.camera.size=10;game._camera()
 var dirs: Array=["down","down_left","left","up_left","up","up_right","right","down_right"]
 var vectors: Array=[Vector2.DOWN,Vector2(-1,1),Vector2.LEFT,Vector2(-1,-1),Vector2.UP,Vector2(1,-1),Vector2.RIGHT,Vector2(1,1)]
 for i in dirs.size():
  game.player.position=Vector3(0,0,8);game.player.velocity=Vector3.ZERO;game.facing_accum=Vector2.ZERO;game.facing_timer=0;game._reset_character_gait()
  game.movement=vectors[i].normalized();var start: Vector3=game.player.position
  game.set_physics_process(true)
  for n in 16:await physics_frame
  game.set_physics_process(false)
  check(game.facing==dirs[i] and game.avatar.animation=="walk_"+dirs[i],"actual screen movement and PNG facing agree: "+dirs[i])
  check(game.player.position.distance_to(start)>.48,"merged walking speed increased: "+dirs[i])
  game.movement=Vector2.ZERO
 game._travel("garden");game.player.position=Vector3(-10,0,-6);game.view_center=Vector3(-10,0,-6);game.view_size=14;game.camera.size=14;game._camera();game.atmosphere.set_time(12)
 check(game.atmosphere.sun.light_energy<=.41 and game.atmosphere.environment.ambient_light_energy<=.29,"merged noon lighting stays below previous overexposure")
 await shot("02_新人物与3D花房")
 var t: float=game.atmosphere.hour;game.atmosphere.set_cycle_enabled(true);game.atmosphere.advance_time(60)
 check(game.atmosphere.hour>t,"daylight advances with game time")
 game.atmosphere.set_time(20.25,3);check(game._save(),"world position and clock save together")
 game.atmosphere.set_time(9,1);check(game._restore() and absf(game.atmosphere.hour-20.25)<.001 and game.atmosphere.day==3,"latest saved world restores day and clock")
 var continuation=load("res://ui/start_menu.tscn").instantiate();root.add_child(continuation);await frames()
 check(not continuation.resume_button.disabled and continuation._saved_journey().location=="garden","latest title resumes an expanded-map v4 save")
 continuation.free()
 await shot("03_花房夜间")
 game._settings(true);check(game.settings_view.switches.has("day_cycle") and game.settings_view.day_speed.item_count==3,"latest settings expose automatic daylight and three day durations")
 await shot("04_昼夜与最新设置");game._settings(false)
 var cc=game.character_controller;var before: float=cc.model.value("hunger");game.pause_menu.open();game.atmosphere.set_process(true);t=game.atmosphere.hour;await frames(8)
 check(game.pause_menu.active and is_equal_approx(t,game.atmosphere.hour) and is_equal_approx(before,cc.model.value("hunger")),"pause menu freezes both latest character needs and daylight")
 game.pause_menu.close();game.atmosphere.set_process(false)
 game.loot.inventory.bread_loaf=2;cc.model.state.vitals.hunger=45;game.loot.open_bag();game.loot.chosen="bread_loaf";game.loot.use_selected();game.loot.close()
 check(game.loot.inventory.bread_loaf==1 and cc.model.value("hunger")==70,"new scene supplies use latest numeric character effects")
 cc.open();await shot("05_最新人物属性");cc.close()
 game.dialogue_controller.start_topic();await frames(8);check(game.dialogue_controller.active,"latest portrait dialogue remains functional")
 await shot("06_新场景与立绘对话");game.dialogue_controller.close()
 var out=FileAccess.open(OUT+"合并检查.json",FileAccess.WRITE);out.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("LATEST MERGE CHECKS ",checks.size()," FAILURES ",failures);quit(failures)
