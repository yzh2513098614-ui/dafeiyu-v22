extends SceneTree
const OUT := "res://预览/游戏比例实时同步_20261012/"
var failures := 0
var checks := 0

func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func capture(name: String) -> Image:
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 image.save_png(ProjectSettings.globalize_path(OUT+name+".png"))
 return image

func proportion_y(y: float,config: Dictionary) -> float:
 var smooth=preload("res://tools/editor_collision_profile.gd")
 return y+float(config.head_height)*minf(y-float(config.head_end),0.0)+float(config.crown_compression)*(1.0-smooth.smooth(.12,.38,y))+float(config.head_drop)*smooth.smooth(.20,.53,y)*(1.0-smooth.smooth(.53,float(config.body_end),y))+float(config.body_extension)*(smooth.smooth(float(config.head_end),float(config.body_end),y)-1.0)+float(config.leg_extension)*(smooth.smooth(float(config.body_end),.9375,y)-1.0)

func eye_screen_box(game) -> Rect2i:
 var config: Dictionary=game.character_manifest.proportion_warp_by_direction.down
 var density: float=game.avatar.pixel_size
 var card: Vector2=Vector2(game.character_manifest.frame_size[0],game.character_manifest.frame_size[1])*density
 var right: Vector3=game.camera.global_basis.x
 var a: Vector2=game.camera.unproject_position(game.avatar.global_position+right*(-.14*card.x*(1.0+float(config.head_width)))+Vector3.UP*((.5-proportion_y(.37,config))*card.y))
 var b: Vector2=game.camera.unproject_position(game.avatar.global_position+right*(.14*card.x*(1.0+float(config.head_width)))+Vector3.UP*((.5-proportion_y(.48,config))*card.y))
 var scale:=root.get_final_transform()
 a=scale*a;b=scale*b
 return Rect2i(Vector2i(a.floor()),Vector2i((b-a).ceil())).grow(6)
func run() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 AudioServer.set_bus_mute(0,true);root.size=Vector2i(1000,750)
 var source:=FileAccess.get_file_as_string("res://assets/character/manifest.json")
 var original_collision:=FileAccess.get_file_as_string("res://assets/character/collision_profile.json")
 var file:=FileAccess.open(OUT+"manifest_test.json",FileAccess.WRITE);file.store_string(source);file.close()
 file=FileAccess.open(OUT+"collision_test.json",FileAccess.WRITE);file.store_string(original_collision);file.close()
 var prefs=root.get_node("HarborPrefs")
 prefs.settings_path=OUT+"settings.cfg";prefs.world_save_path=OUT+"world.json"
 prefs.continue_game=false;prefs.starting_place="city"
 prefs.values.fullscreen=false;prefs.values.music=false;prefs.values.sfx=false;prefs.values.ambience=false;prefs.values.effects=false;prefs.values.day_cycle=false
 var game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game
 for i in 12:await process_frame
 game.set_physics_process(false);game.dialogue_controller.close()
 game.atmosphere.set_process(false);game.atmosphere.set_effects(false);game.atmosphere.set_time(12)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 if game.dialogue_controller.companion:game.dialogue_controller.companion.hide()
 game.player.position=Vector3(0,0,8);game.view_center=game.player.position;game.overview_mode=false;game.view_size=6;game.camera.size=6;game._camera()
 game.facing="down";game.gait_phase=.25;game._set_character_pose(true)
 var reload_node=game.get_node("CharacterProportionLiveReload")
 reload_node.manifest_path=OUT+"manifest_test.json";reload_node.collision_path=OUT+"collision_test.json"
 var position: Vector3=game.player.position
 var avatar_position: Vector3=game.avatar.position
 var old_width: float=game.character_material.get_shader_parameter("proportion_head_width")
 var before: Image=await capture("before")
 var viewport:=SubViewport.new();viewport.own_world_3d=true;viewport.size=Vector2i(320,240);root.add_child(viewport)
 var editor=load("res://tools/character_proportion_editor.tscn").instantiate()
 editor.set_meta("proportion_manifest_path",OUT+"manifest_test.json")
 editor.set_meta("proportion_collision_path",OUT+"collision_test.json")
 editor.head_width=.30;viewport.add_child(editor)
 check(is_equal_approx(editor.head_width,old_width),"F6 startup reads saved game profile instead of stale scene values")
 check(is_equal_approx(-editor.get_node("PreviewCamera").global_basis.z.normalized().y,-game.camera.global_basis.z.normalized().y),"preview camera matches production elevation")
 editor.sync_editor_changes(editor.profile(),0.0)
 var eye_upper:=.010 if not is_equal_approx(editor.eye_upper_drop,.010) else 0.0
 var eye_lower:=.002 if not is_equal_approx(editor.eye_lower_drop,.002) else 0.0
 game.camera.size=3;game._camera()
 var eye_before: Image=await capture("eye_before")
 editor.eye_upper_drop=eye_upper;editor.eye_lower_drop=eye_lower
 editor.sync_editor_changes(editor.profile(),.4)
 await create_timer(.8).timeout
 check(is_equal_approx(float(game.character_material.get_shader_parameter("proportion_eye_upper_drop")),eye_upper) and is_equal_approx(float(game.character_material.get_shader_parameter("proportion_eye_lower_drop")),eye_lower),"both downward eye edge controls auto-sync to actual game shader")
 check(is_equal_approx(editor.eye_upper_drop,eye_upper) and is_equal_approx(editor.eye_lower_drop,eye_lower) and is_equal_approx(float(editor.get_node("Adjusted").material_override.get_shader_parameter("proportion_eye_lower_drop")),eye_lower),"F6 preview loads and renders both eye edge controls")
 check(is_equal_approx(float(editor.get_node("Original").material_override.get_shader_parameter("proportion_eye_upper_drop")),0.0) and is_equal_approx(float(editor.get_node("Original").material_override.get_shader_parameter("proportion_eye_lower_drop")),0.0),"original reference retains original eye height")
 var eye_after: Image=await capture("eye_after")
 var eye_box:=eye_screen_box(game)
 var inside:=0;var outside:=0
 var changed_box:=Rect2i()
 for y in eye_before.get_height():
  for x in eye_before.get_width():
   var a:=eye_before.get_pixel(x,y);var b:=eye_after.get_pixel(x,y)
   if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)+absf(a.a-b.a)>.06:
    changed_box=Rect2i(Vector2i(x,y),Vector2i.ONE) if inside+outside==0 else changed_box.merge(Rect2i(Vector2i(x,y),Vector2i.ONE))
    if eye_box.has_point(Vector2i(x,y)):inside+=1
    else:outside+=1
 print("EYE PIXELS: inside=",inside," outside=",outside," expected=",eye_box," changed=",changed_box)
 check(inside>0 and outside==0,"GPU eye adjustment changes only face region, leaving crown, body and feet intact")
 check(game.avatar.position==avatar_position and is_equal_approx(float(game.character_material.get_shader_parameter("proportion_head_width")),old_width),"eye control preserves foot anchor and head width")
 game.camera.size=6;game._camera()
 editor.head_width=old_width+.12
 editor.sync_editor_changes(editor.profile(),.4)
 await create_timer(.8).timeout
 check(is_equal_approx(float(game.character_material.get_shader_parameter("proportion_head_width")),old_width+.12),"Inspector edit auto-syncs to running production character before save button")
 check(FileAccess.get_file_as_string(OUT+"collision_test.json")==original_collision,"automatic visual tuning keeps collision rebuild on explicit save")
 await editor.save_to_game()
 await create_timer(.8).timeout
 check(is_equal_approx(float(game.character_material.get_shader_parameter("proportion_head_width")),old_width+.12),"editor save updates already running production character")
 check(is_equal_approx(float(editor.get_node("Adjusted").material_override.get_shader_parameter("proportion_head_width")),old_width+.12),"F6 running preview follows saved file changes")
 var after: Image=await capture("after")
 check(before.get_data()!=after.get_data(),"actual GPU rendered game image changes without restarting")
 check(game.player.position==position and game.avatar.position==avatar_position,"live update preserves character position and foot anchor")
 var collision: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"collision_test.json"))
 var guards_match:=true
 for body in [game.player,game.silhouette_body]:
  var index:=0
  for child in body.get_children():
   if child is CollisionShape3D and child.name.begins_with("SilhouetteGuard"):
    if not is_equal_approx(child.shape.radius,float(collision.bands[index].radius)):guards_match=false
    index+=1
 check(guards_match,"player and swept silhouette collision guards update live")
 if game.dialogue_controller.companion:
  var sprites=game.dialogue_controller.companion.find_children("*","Sprite3D",true,false)
  check(is_equal_approx(float(sprites[0].material_override.get_shader_parameter("proportion_head_width")),old_width+.12),"companion material receives same saved parameters")
 game.facing="down_left";game._set_character_pose(true)
 check(not game.character_material.get_shader_parameter("proportion_warp_enabled"),"other directions retain original mapping after live update")
 game.facing="down";game._set_character_pose(false)
 check(is_equal_approx(float(game.character_material.get_shader_parameter("proportion_head_width")),old_width+.12),"idle front keeps newly saved parameters")
 paused=true
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"manifest_test.json"))
 data.proportion_warp_by_direction.down.head_width=old_width+.08
 file=FileAccess.open(OUT+"manifest_test.json",FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
 await create_timer(.8,true).timeout
 check(is_equal_approx(float(game.character_material.get_shader_parameter("proportion_head_width")),old_width+.08),"parameter synchronization also works while game is paused")
 paused=false
 await create_timer(.8).timeout
 check(is_equal_approx(editor.head_width,old_width+.08) and is_equal_approx(float(editor.get_node("Adjusted").material_override.get_shader_parameter("proportion_head_width")),old_width+.08),"F6 window reloads externally saved parameters")
 check(FileAccess.get_file_as_string("res://assets/character/manifest.json")==source and FileAccess.get_file_as_string("res://assets/character/collision_profile.json")==original_collision,"verification preserves user saved parameters")
 print("LIVE PROPORTION SYNC: ",checks," checks, ",failures," failures")
 quit(0 if failures==0 else 1)
