extends SceneTree
const OUT="res://预览/人物环境受光_v22_20261004/"
var game
var studio: SubViewport
var scene: Node3D
var actor: Node3D
var portrait: AnimatedSprite3D
var sun: DirectionalLight3D
var lamp: OmniLight3D
var blocker: MeshInstance3D
var env: Environment
var failures:=0
var checks: Array=[]
var records: Dictionary={}
var captures: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int=4) -> void:
 for i in n:await process_frame
 RenderingServer.force_draw()
func check(ok: bool,message: String) -> void:
 checks.append({"ok":ok,"check":message})
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1;push_error(message)
func geometry(size: Vector3,pos: Vector3,color: Color) -> MeshInstance3D:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.position=pos
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=1;m.metallic_specular=0;mesh.material_override=m;scene.add_child(mesh);return mesh
func capture(id: String,title: String) -> void:
 portrait.hide();await frames();var empty:=studio.get_texture().get_image()
 portrait.show();await frames();var drawn:=studio.get_texture().get_image()
 drawn.save_png(OUT+id+".png");captures.append({"title":title,"image":drawn})
 var count:=0;var sum:=Vector3.ZERO;var bright:=0
 for y in range(60,650,2):
  for x in range(210,750,2):
   var a:=drawn.get_pixel(x,y);var b:=empty.get_pixel(x,y)
   if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)<.035:continue
   sum+=Vector3(a.r,a.g,a.b);count+=1
   if minf(a.r,minf(a.g,a.b))>.985:bright+=1
 var color: Vector3=sum/maxf(count,1)
 records[id]={"pixels":count,"rgb":[color.x,color.y,color.z],"luminance":color.dot(Vector3(.2126,.7152,.0722)),"clipped_fraction":float(bright)/maxf(count,1)}
 check(count>1500,id+": actual GPU-rendered character pixels present")
func build_studio() -> void:
 studio=SubViewport.new();studio.size=Vector2i(960,720);studio.own_world_3d=true;studio.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(studio)
 scene=Node3D.new();studio.add_child(scene)
 var world:=WorldEnvironment.new();env=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("253442");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment=env;scene.add_child(world)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.8;camera.position=Vector3(0,2.4,5);scene.add_child(camera);camera.look_at(Vector3(0,.85,0));camera.current=true
 geometry(Vector3(12,.04,12),Vector3(0,-.025,0),Color("b5c4c4"))
 sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.shadow_enabled=true;sun.directional_shadow_max_distance=30;sun.shadow_bias=.02;sun.shadow_normal_bias=.15;scene.add_child(sun)
 lamp=OmniLight3D.new();lamp.position=Vector3(0,1.0,1.35);lamp.omni_range=3;lamp.light_specular=0;scene.add_child(lamp)
 blocker=geometry(Vector3(10,.15,10),Vector3(0,3.2,0),Color("7c8b99"));blocker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;blocker.hide()
 actor=Node3D.new();scene.add_child(actor)
 portrait=game.avatar.duplicate();portrait.animation="idle_down";portrait.frame=0;portrait.stop();portrait.material_override=game.character_material.duplicate()
 var texture: Texture2D=game.frames.get_frame_texture("idle_down",0)
 portrait.material_override.set_shader_parameter("character_atlas",texture.atlas if texture is AtlasTexture else texture)
 portrait.material_override.set_shader_parameter("character_tint",Vector3.ONE);actor.add_child(portrait)
 for child in game.player.get_children():
  if child is MeshInstance3D and child.mesh is PlaneMesh:actor.add_child(child.duplicate())
func noon() -> void:
 env.ambient_light_color=Color("c6d2dd");env.ambient_light_energy=.28;sun.light_color=Color("f3eee5");sun.light_energy=.40;lamp.light_energy=0;blocker.hide()
func night() -> void:
 env.ambient_light_color=Color("a1b5cf");env.ambient_light_energy=.21;sun.light_color=Color("99afd2");sun.light_energy=.045;lamp.light_energy=0;blocker.hide()
func comparison() -> void:
 var height: int=ceili(captures.size()/3.0)*404
 var view:=SubViewport.new();view.size=Vector2i(1440,height);view.disable_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var bg:=ColorRect.new();bg.size=Vector2(1440,height);bg.color=Color("182534");view.add_child(bg)
 for i in captures.size():
  var p:=Vector2((i%3)*480,(i/3)*404)
  var picture:=TextureRect.new();picture.position=p+Vector2(4,4);picture.size=Vector2(472,354);picture.texture=ImageTexture.create_from_image(captures[i].image);picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;view.add_child(picture)
  var label:=Label.new();label.text=captures[i].title;label.position=p+Vector2(12,365);label.size=Vector2(456,32);label.add_theme_font_override("font",load("res://assets/NotoSansSC.ttf"));label.add_theme_font_size_override("font_size",23);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;view.add_child(label)
 await frames(6);view.get_texture().get_image().save_png(OUT+"00_人物真实受光对比.png");view.free()
func run() -> void:
 var args:=OS.get_cmdline_user_args()
 if DisplayServer.get_name()=="headless" or not "--test-merge" in args or not "--capture-ui" in args or not "--capture-dialogue" in args:quit(2);return
 AudioServer.set_bus_mute(0,true)
 DirAccess.make_dir_recursive_absolute(OUT)
 var prefs=root.get_node("HarborPrefs");prefs.values.fullscreen=false;prefs.starting_place="city";prefs.continue_game=false
 game=load("res://district/continuous_world.tscn").instantiate();root.add_child(game);current_scene=game;await frames(8);game.dialogue_controller.close();game.set_physics_process(false);game.atmosphere.set_process(false)
 for child in game.get_children():
  if child is CanvasLayer:child.hide()
 build_studio();await frames(8)
 noon();await capture("01_正午","正午 · 阳光与环境光")
 night();await capture("02_夜晚","夜晚 · 冷色环境光")
 lamp.light_color=Color("ffbd76");lamp.light_energy=1.2;await capture("03_暖灯","靠近暖灯 · 自然染色")
 lamp.light_color=Color("709bff");await capture("04_蓝灯","同一位置 · 蓝色灯光")
 lamp.light_color=Color("ffbd76");lamp.position=Vector3(8,1,1.35);await capture("05_远离灯","远离灯具 · 光线衰减")
 noon();blocker.show();await capture("06_建筑阴影","建筑遮挡 · 实时接收阴影")
 check(records["01_正午"].luminance>records["02_夜晚"].luminance*1.1,"character darkens under actual night illumination")
 check(records["03_暖灯"].luminance>records["05_远离灯"].luminance*1.10,"nearby practical light affects character and falls off with distance")
 check(records["03_暖灯"].rgb[0]>records["04_蓝灯"].rgb[0] and records["04_蓝灯"].rgb[2]>records["03_暖灯"].rgb[2],"real light color changes painted character color")
 check(records["06_建筑阴影"].luminance<records["01_正午"].luminance*.95,"world occluder casts a received shadow on character")
 for id in records:check(records[id].clipped_fraction<.03,id+": white costume avoids broad clipping")
 night();lamp.position=Vector3(-1.3,1.2,1.35);lamp.light_color=Color("ffbd76");lamp.light_energy=1.2;lamp.shadow_enabled=true
 lamp.omni_shadow_mode=OmniLight3D.SHADOW_CUBE;lamp.shadow_bias=.035;lamp.shadow_normal_bias=.12
 await capture("09_隔墙前灯光","局部暖灯 · 隔墙前")
 var wall:=geometry(Vector3(.16,4,5),Vector3(-.6,1.8,0),Color.GRAY)
 wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
 await capture("10_隔墙后灯光","隔墙遮挡 · 局部灯阴影")
 check(records["10_隔墙后灯光"].luminance<records["09_隔墙前灯光"].luminance*.9,"local light is blocked by a wall instead of illuminating through it")
 wall.free();lamp.shadow_enabled=false;lamp.position=Vector3(0,1,1.35);lamp.light_energy=20
 var overlap:=OmniLight3D.new();overlap.position=Vector3(.6,1.2,1.1);overlap.omni_range=3;overlap.light_color=Color("709bff");overlap.light_energy=12;scene.add_child(overlap)
 await capture("11_强灯亮部","强灯重叠 · 柔和亮部")
 check(records["11_强灯亮部"].clipped_fraction<.03,"strong practical lighting preserves white costume detail")
 overlap.free()
 var directions: Array=["down","down_left","left","up_left","up","up_right","right","down_right"]
 for direction in directions:
  var frame_texture: Texture2D=game.frames.get_frame_texture("walk_"+direction,1)
  portrait.stop();portrait.animation="walk_"+direction;portrait.frame=1
  portrait.pixel_size=game.character_pixel_size(direction);portrait.position.y=game.character_ground_offset(direction)
  portrait.material_override.set_shader_parameter("character_atlas",frame_texture.atlas if frame_texture is AtlasTexture else frame_texture)
  night();lamp.position=Vector3(0,1,1.35);lamp.light_color=Color("ffbd76");lamp.light_energy=1.2
  await frames();var lit:=studio.get_texture().get_image();lit.save_png(OUT+"八方向_暖灯_"+direction+".png")
  lamp.light_energy=0;await frames();var dark:=studio.get_texture().get_image()
  var difference:=0.0
  # The upper central pixels belong to the character, above the ground plane.
  for y in range(180,360,3):
   for x in range(330,630,3):
    var a:=lit.get_pixel(x,y);var b:=dark.get_pixel(x,y)
    difference+=maxf(0,a.r-b.r)+maxf(0,a.g-b.g)+maxf(0,a.b-b.b)
  check(difference>5.0,"live lamp affects walking frame in direction: "+direction)
 await comparison();studio.free()
 for child in game.get_children():
  if child is CanvasLayer:child.show()
 game._travel("garden");game.player.position=Vector3(-7,0,-7);game.view_center=game.player.position;game.overview_mode=false;game.view_size=10;game.camera.size=10;game._camera()
 for hour in [12.0,20.0]:
  game.atmosphere.set_time(hour);game._update_character_material();game.clock_label.text=game.atmosphere.clock_text();await frames(6)
  root.get_texture().get_image().save_png(OUT+("07_场景白天.png" if hour==12 else "08_场景夜晚.png"))
 game._travel("apt_2");game.atmosphere.set_time(20)
 var original: bool=prefs.values.shadows;prefs.values.shadows=true
 if not game.atmosphere.lamps.is_empty():
  var near: Vector3=game.atmosphere.lamps[0].global_position
  game.player.position=Vector3(near.x+1.2,0,near.z+.5)
 game.atmosphere._refresh_local_shadows()
 game.view_center=game.player.position;game.overview_mode=false;game.view_size=10;game.camera.size=10;game._camera();game.clock_label.text=game.atmosphere.clock_text();await frames(6)
 root.get_texture().get_image().save_png(OUT+"12_室内夜晚受光.png")
 var count:=0
 for practical in game.atmosphere.lamps:
  if is_instance_valid(practical) and practical.shadow_enabled:count+=1
 check(count>0 and count<=game.atmosphere.LOCAL_SHADOW_LIMIT,"real interior assigns shadow atlas to nearby practical lamps")
 prefs.values.shadows=false;game.atmosphere._refresh_local_shadows();count=0
 for practical in game.atmosphere.lamps:
  if is_instance_valid(practical) and practical.shadow_enabled:count+=1
 check(count==0,"player shadow preference also disables local lamp shadows")
 prefs.values.shadows=original;game.atmosphere._refresh_local_shadows()
 var file:=FileAccess.open(OUT+"受光验证.json",FileAccess.WRITE);file.store_string(JSON.stringify({"failures":failures,"records":records,"checks":checks},"  "))
 print("ENVIRONMENT LIGHT CHECKS ",checks.size()," FAILURES ",failures);quit(failures)
