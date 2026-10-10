extends SceneTree
const Library=preload("res://district/library_models.gd")
const OUT="res://预览/餐厅学校医院_3D_v22/"
const TOWN=["safe_floor","safe_tall","safe_compact","token_atm","bench","street_lamp","supply_crate","water_barrel","whale_fountain","whale_statue","recycling_bin","whale_sign"]
const NATURE=["tree_oak","tree_pine","tree_birch","tree_cherry","tree_palm","tree_autumn","tree_snow_pine","tree_dead","bush_berry","shrub","stump","fallen_log"]
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(2000,1600)
 for ids in [TOWN,NATURE]:
  var stage:=Node3D.new();root.add_child(stage);current_scene=stage
  var world:=WorldEnvironment.new();var env:=Environment.new()
  env.background_mode=Environment.BG_COLOR;env.background_color=Color("192a38")
  env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d1d9df");env.ambient_light_energy=.35
  world.environment=env;stage.add_child(world)
  var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_color=Color("fff4dc");sun.light_energy=.55
  sun.shadow_enabled=true;sun.directional_shadow_max_distance=50;stage.add_child(sun)
  var plane:=PlaneMesh.new();plane.size=Vector2(26,25)
  var floor:=MeshInstance3D.new();floor.mesh=plane
  var mat:=StandardMaterial3D.new();mat.albedo_color=Color("7a9093");mat.roughness=.9;floor.material_override=mat;stage.add_child(floor)
  for n in ids.size():
   var id: String="library_"+ids[n];var model: Node3D=Library.instance(id)
   if model==null:failures+=1;continue
   var x: float=(n%4-1.5)*5.8;var z: float=(int(n/4)-1)*6.2
   model.position=Vector3(x,.035,z);stage.add_child(model)
   if model.get_node_or_null("Body/Collision")==null:failures+=1;push_error("Missing collider: "+id)
   var label:=Label3D.new();label.text=str(n+1)+" · "+str(ids[n]);label.font_size=32;label.pixel_size=.010
   label.position=Vector3(x,.34,z+2.6);label.modulate=Color("f3eddd");label.outline_size=4;label.outline_modulate=Color("243847");label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;stage.add_child(label)
  var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=23.5;stage.add_child(camera);camera.current=true
  for view in ["front","rear"]:
   camera.position=Vector3(8,22,31) if view=="front" else Vector3(-8,22,-31)
   camera.look_at(Vector3(0,1.1,0))
   for n in 10:await process_frame
   await RenderingServer.frame_post_draw
   var page: String="library_town" if ids==TOWN else "library_nature"
   if root.get_texture().get_image().save_png(OUT+page+"_"+view+".png")!=OK:failures+=1
  stage.queue_free();await process_frame
 print("LIBRARY MODELS 24 RENDER FAILURES ",failures)
 quit(0 if failures==0 else 1)
