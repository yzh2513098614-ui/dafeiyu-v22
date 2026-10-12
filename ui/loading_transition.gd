extends CanvasLayer
## One persistent overlay for scene changes and in-world doorway travel.
const DESIGN_SIZE := Vector2(1672,941)
const Backdrop = preload("res://assets/ui/whale_loading/backdrop.png")
const Water = preload("res://assets/ui/whale_loading/water.gdshader")
var busy := false
var progress := 0.0
var target_progress := 0.0
var elapsed := 0.0
var last_error := ""
var previous_pause := false
var canvas: Control
var sheet: Control
var percentage: Label
var heading: Label
var destination: Label
var stage: Label
var water_material: ShaderMaterial
var finished_count := 0

static func instance(tree: SceneTree):
 var overlay = tree.root.get_node_or_null("WhaleLoading")
 if overlay == null:
  overlay = load("res://ui/loading_transition.gd").new()
  overlay.name = "WhaleLoading"
  tree.root.add_child(overlay)
 return overlay

func _ready() -> void:
 layer = 120
 process_mode = Node.PROCESS_MODE_ALWAYS
 canvas = Control.new();canvas.name="LoadingScreen";add_child(canvas)
 canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 canvas.mouse_filter=Control.MOUSE_FILTER_STOP
 var outer:=ColorRect.new();outer.color=Color("bbd9ff");outer.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(outer)
 outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 sheet=Control.new();sheet.size=DESIGN_SIZE;sheet.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(sheet)
 var art:=TextureRect.new();art.name="ReferenceIllustration";art.texture=Backdrop;art.size=DESIGN_SIZE
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.mouse_filter=Control.MOUSE_FILTER_IGNORE;sheet.add_child(art)
 var font:=FontVariation.new();font.base_font=load("res://assets/NotoSansSC.ttf")
 font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):900.0}
 var theme:=Theme.new();theme.default_font=font;sheet.theme=theme
 var bar:=Panel.new();bar.name="ProgressTrack";bar.position=Vector2(500,583);bar.size=Vector2(1034,126);bar.scale=Vector2(.65,.65);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var frame:=StyleBoxFlat.new();frame.bg_color=Color("e5eafa");frame.border_color=Color.WHITE;frame.set_border_width_all(12);frame.set_corner_radius_all(63)
 frame.shadow_color=Color(.25,.47,.86,.22);frame.shadow_size=9;frame.shadow_offset=Vector2(0,4);bar.add_theme_stylebox_override("panel",frame);sheet.add_child(bar)
 var ring:=Panel.new();ring.position=Vector2(14,14);ring.size=Vector2(1006,98);ring.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var edge:=StyleBoxFlat.new();edge.bg_color=Color("e1e6f3");edge.border_color=Color("87b7ff");edge.set_border_width_all(4);edge.set_corner_radius_all(49);ring.add_theme_stylebox_override("panel",edge);bar.add_child(ring)
 var liquid:=ColorRect.new();liquid.name="AnimatedWater";liquid.position=Vector2(20,20);liquid.size=Vector2(994,86);liquid.mouse_filter=Control.MOUSE_FILTER_IGNORE
 water_material=ShaderMaterial.new();water_material.shader=Water;liquid.material=water_material;bar.add_child(liquid)
 percentage=_label(bar,"0%",Vector2(841,13),Vector2(167,96),65,Color("0874ff"),10)
 heading=_label(sheet,"加载中",Vector2(515,688),Vector2(642,124),86,Color("0874ff"),17)
 var capsule:=Panel.new();capsule.position=Vector2(386,821);capsule.size=Vector2(900,55);capsule.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var pill:=StyleBoxFlat.new();pill.bg_color=Color(1,1,1,.95);pill.set_corner_radius_all(28);pill.shadow_color=Color(.25,.47,.86,.12);pill.shadow_size=4;capsule.add_theme_stylebox_override("panel",pill);sheet.add_child(capsule)
 destination=_label(capsule,"",Vector2(18,1),Vector2(864,53),27,Color("0874ff"),0)
 destination.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 stage=_label(sheet,"",Vector2(386,882),Vector2(900,38),19,Color("4a79b8"),0)
 get_viewport().size_changed.connect(_fit);_fit();canvas.hide();set_process(false)

func _label(parent: Node,text: String,pos: Vector2,dimensions: Vector2,font_size: int,color: Color,outline: int) -> Label:
 var label:=Label.new();label.text=text;label.position=pos;label.size=dimensions;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color)
 label.add_theme_color_override("font_outline_color",Color.WHITE);label.add_theme_constant_override("outline_size",outline);parent.add_child(label);return label

func _fit() -> void:
 var viewport_size:=get_viewport().get_visible_rect().size
 var factor:=minf(viewport_size.x/DESIGN_SIZE.x,viewport_size.y/DESIGN_SIZE.y)
 sheet.scale=Vector2.ONE*factor;sheet.position=(viewport_size-DESIGN_SIZE*factor)*.5

func _process(delta: float) -> void:
 elapsed+=delta
 progress=move_toward(progress,target_progress,delta*1.4)
 water_material.set_shader_parameter("progress",progress)
 water_material.set_shader_parameter("animation_time",elapsed)
 percentage.text="%d%%"%int(floor(progress*100.0))
 heading.text="加载完成" if progress>=1.0 else "加载中"+".".repeat(1+int(elapsed*2.5)%3)
 heading.position.y=688+sin(elapsed*3.0)*3.0

func _input(_event: InputEvent) -> void:
 if busy:get_viewport().set_input_as_handled()

func begin(place: String) -> bool:
 if busy:return false
 busy=true;last_error="";progress=0.0;target_progress=0.0;elapsed=0.0
 previous_pause=get_tree().paused;get_tree().paused=true
 destination.text="正在进入 · "+place;stage.text="准备旅程";percentage.text="0%"
 water_material.set_shader_parameter("progress",0.0);canvas.modulate.a=0;canvas.show();set_process(true)
 return true

func reveal() -> void:
 var fade:=create_tween();fade.tween_property(canvas,"modulate:a",1.0,.12);await fade.finished
 await get_tree().process_frame

func checkpoint(value: float,note: String) -> void:
 target_progress=maxf(target_progress,minf(value,.95));stage.text=note
 await get_tree().create_timer(.08,true,false,true).timeout

func finish() -> void:
 stage.text="场景准备就绪"
 if elapsed<.8:await get_tree().create_timer(.8-elapsed,true,false,true).timeout
 target_progress=1.0
 while progress<1.0:await get_tree().process_frame
 await get_tree().create_timer(.12,true,false,true).timeout
 var fade:=create_tween();fade.tween_property(canvas,"modulate:a",0.0,.18);await fade.finished
 canvas.hide();get_tree().paused=previous_pause;busy=false;finished_count+=1;set_process(false)

func _fail(message: String) -> void:
 last_error=message;stage.text=message;heading.text="加载失败";set_process(false)
 await get_tree().create_timer(1.5,true,false,true).timeout
 canvas.hide();get_tree().paused=previous_pause;busy=false

func change_scene(path: String,place: String) -> void:
 if not begin(place):return
 await reveal()
 var error:=ResourceLoader.load_threaded_request(path,"PackedScene")
 if error!=OK:
  await _fail("无法读取场景："+error_string(error));return
 var started:=Time.get_ticks_msec()
 while true:
  var amount: Array=[]
  var status:=ResourceLoader.load_threaded_get_status(path,amount)
  if status==ResourceLoader.THREAD_LOAD_LOADED:break
  if status!=ResourceLoader.THREAD_LOAD_IN_PROGRESS or Time.get_ticks_msec()-started>60000:
   await _fail("场景读取失败，请重试");return
  target_progress=maxf(target_progress,.08+float(amount[0] if not amount.is_empty() else 0.0)*.62)
  stage.text="读取场景资源";await get_tree().process_frame
 var packed: PackedScene=ResourceLoader.load_threaded_get(path)
 await checkpoint(.74,"布置目标场景")
 error=get_tree().change_scene_to_packed(packed)
 if error!=OK:
  await _fail("无法进入场景："+error_string(error));return
 await get_tree().scene_changed
 await checkpoint(.94,"准备人物、镜头与交互")
 await get_tree().process_frame
 await finish()
