extends SceneTree
## Real dialogue screenshots and resource/usage verification; isolated saves, muted audio.
const OUTPUT="res://预览/对话差分_20261013/"
var failures:=0
var checks:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error(label)
func settle()->void:
 for i in 10:await process_frame
func shot(name:String)->void:
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+name+".png"))
func run()->void:
 AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false
 prefs.settings_path=OUTPUT+"settings.cfg";prefs.world_save_path=OUTPUT+"world.json"
 prefs.starting_place="city";prefs.continue_game=false
 root.size=Vector2i(1448,1086)
 var game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 await settle();game.set_physics_process(false)
 var d=game.dialogue_controller
 var preserved_box_position:Vector2=d.box.position
 d.save_path=OUTPUT+"dialogue.json";d.state={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]}
 d.context={"room":"鲸落港","object":"书桌"}
 var used:Dictionary={}
 var valid:=true
 for story in d.stories.values():
  for node in story.nodes.values():
   var expression:String=str(node.get("expression","listen"))
   valid=valid and d.portrait_regions.has(expression)
   used[expression]=true
 check(valid,"every story expression resolves to an imported portrait")
 var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dialogue/portraits.json"))
 var variants:Dictionary=metadata.variants
 var paths:Dictionary={}
 for id in variants:
  var tex:Texture2D=d.portrait_regions.get(id)
  check(tex!=null and used.has(id),id+" is loaded and assigned to real dialogue")
  if tex:
   paths[tex.resource_path]=true
   check(tex.get_image().detect_alpha()!=Image.ALPHA_NONE,id+" retains alpha transparency")
 check(paths.size()==variants.size(),"all delivered variants are distinct assets")
 for id in variants:
  var route:Array=variants[id].nodes[0].split("/")
  d.start(route[0],route[1]);d.advance();await settle()
  check(d.portrait.texture==d.portrait_regions[id],str(route)+" displays "+id)
  await shot(id)
 check(d.box.position==preserved_box_position,"current restored dialogue layout remains in place")
 d.start("welcome","ask");d.advance();await settle()
 check(d.choice_buttons.size()==3,"choices remain functional")
 d.choice_buttons[1].pressed.emit();await settle()
 var guide_expression:String=d.stories.welcome.nodes.guide.expression
 check(d.current_node=="guide" and d.portrait.texture==d.portrait_regions[guide_expression],"real reply switches to the guide expression")
 d.close();check(not game.dialog_open and game.ui.visible,"closing restores world HUD")
 print("PORTRAIT VARIANTS: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
