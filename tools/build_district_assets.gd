extends SceneTree
const Asset=preload("res://district/street_asset.gd")
func _initialize() -> void:
 call_deferred("build")
func build() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/district"))
 var entries: Dictionary={}
 var viewport:=SubViewport.new();viewport.size=Vector2i(384,384);viewport.transparent_bg=true;viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var environment:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color.TRANSPARENT;e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("e0e9f0");e.ambient_light_energy=.5;environment.environment=e;viewport.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_energy=.9;sun.light_color=Color("f0f6ff");viewport.add_child(sun)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.65;viewport.add_child(camera);camera.position=Vector3(3,3.3,5);camera.look_at(Vector3(0,1.15,0));camera.current=true
 for kind in Asset.NAMES:
  var asset:=Asset.new();asset.asset_kind=kind;viewport.add_child(asset)
  for n in 3:await process_frame
  await RenderingServer.frame_post_draw
  var rendered: Image=viewport.get_texture().get_image()
  var bounds: Rect2i=rendered.get_used_rect()
  if bounds.size==Vector2i.ZERO:
   push_error("Empty district render: "+kind);quit(1);return
  # A tight transparent sprite keeps its visible floor contact at the Node2D pivot.
  var cropped:=Image.create(bounds.size.x+4,bounds.size.y+4,false,Image.FORMAT_RGBA8)
  cropped.blit_rect(rendered,bounds,Vector2i(2,2))
  var output: String="res://assets/district/"+kind+".png"
  if cropped.save_png(output)!=OK:
   push_error("Unable to save district render: "+output);quit(1);return
  entries[kind]={"name":Asset.NAMES[kind],"size":[cropped.get_width(),cropped.get_height()],"footprint":Asset.FOOTPRINTS[kind]}
  asset.free()
 var manifest:=FileAccess.open("res://assets/district/modules.json",FileAccess.WRITE)
 manifest.store_string(JSON.stringify(entries,"  "));manifest.close()
 print(Asset.NAMES.size()," DISTRICT ASSET PREVIEWS RENDERED");quit()
