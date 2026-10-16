extends Node
## Data-driven visual-novel dialogue. The game only displays complete PNG portraits.
const DialogueStyle=preload("res://ui/harbor_inventory_skin.gd")
const GalView=preload("res://dialogue/gal_view.gd")
const UiFit=preload("res://ui/ui_fit.gd")
const DB_PATH="res://dialogue/stories.json"
var save_path:="user://whale_dialogue_v19.json"
var game
var stories: Dictionary={}
var state: Dictionary={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]}
var root: Control
var layer: CanvasLayer
var shade: ColorRect
var portrait: TextureRect
var box: Panel
var speaker: Label
var text_label: RichTextLabel
var advance_hint: Label
var location_text: Label
var choice_panel: Panel
var choice_buttons: Array[Button]=[]
var backlog: Panel
var log_scroll: ScrollContainer
var log_list: VBoxContainer
var auto_button: Button
var hud_button: Button
var resume_button: Button
var active:=false
var auto_play:=false
var portrait_visible:=true
var game_ui_was_visible:=true
var portrait_button: Button
var current_story:=""
var current_node:=""
var current: Dictionary={}
var context: Dictionary={}
var revealed:=0.0
## 下一个打字机音效触发的字符下标。_process 里每 3 个字推一次。
var type_tick_at:=0
var dwell:=0.0
var line_logged:=false
var backlog_open:=false
var companion: Node3D
var portrait_regions: Dictionary={}
var transition: Tween
var chars_per_second:=34.0
var view
var trail:Array=[]
var line_start_history:=0
var reading:Dictionary={"speed":34.0,"wait":1.6,"font":30.0,"opacity":.82,"motion":true}
var skip_play:=false
var ui_hidden:=false
var config_open:=false

func _ready() -> void:
 game=get_parent()
 if "--test-expedition" in OS.get_cmdline_user_args():save_path="res://预览/expedition_dialogue_test.json"
 elif "--test-dialogue" in OS.get_cmdline_user_args():save_path="user://whale_dialogue_v19_test.json"
 elif "--test-session-ui" in OS.get_cmdline_user_args():save_path="user://whale_dialogue_session_ui_test.json"
 elif "--test-life-ui" in OS.get_cmdline_user_args():save_path="user://whale_dialogue_life_ui_test.json"
 elif "--test-combat-ui" in OS.get_cmdline_user_args():save_path="user://whale_dialogue_combat_ui_test.json"
 elif "--capture-dialogue" in OS.get_cmdline_user_args():save_path="user://whale_dialogue_v19_preview.json"
 stories=JSON.parse_string(FileAccess.get_file_as_string(DB_PATH))
 _load_state();reading.merge(state.get("reading",{}),true);chars_per_second=float(reading.speed);_portraits();_build_ui()

func _portraits() -> void:
 if not FileAccess.file_exists("res://assets/dialogue/portraits.json"):return
 var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/dialogue/portraits.json"))
 if metadata.has("textures"):
  for key in metadata.textures:
   portrait_regions[key]=load(str(metadata.textures[key])) as Texture2D
  return
 var sheet: Texture2D=load(str(metadata.sheet))
 for key in metadata.regions:
  var r: Array=metadata.regions[key]
  var tex:=AtlasTexture.new();tex.atlas=sheet;tex.region=Rect2(r[0],r[1],r[2],r[3]);tex.filter_clip=true
  portrait_regions[key]=tex

func _button(parent: Node,label: String,pos: Vector2,size: Vector2,action: Callable) -> Button:
 var b:=Button.new();b.text=label;b.position=pos;b.size=size;b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;b.pressed.connect(action);parent.add_child(b);return b

func _build_ui() -> void:
 view=GalView.new(self);view.build()
 hud_button=DialogueStyle.button(game.ui.get_child(0),"Q 和大肥鱼聊聊",Vector2(72,979),Vector2(248,55),func():start_topic())
 UiFit.pin_design(hud_button,72,979,248,55)
 resume_button=DialogueStyle.button(game.ui.get_child(0),"接着上次",Vector2(334,979),Vector2(163,55),func():resume())
 UiFit.pin_design(resume_button,334,979,163,55)

func world_changed() -> void:
 if active:close()
 companion=null
 if not game.get("district_ready"):return
 companion=Node3D.new();companion.name="WhaleGuide"
 companion.position=Vector3(2.0,0,7.2) if game.location_id=="city" else Vector3(-2.3,0,.25)
 if game.shell.has_meta("guide_anchor"):companion.position=game.shell.get_meta("guide_anchor")
 game.world.add_child(companion)
 var body:=StaticBody3D.new();body.name="GuideBody";companion.add_child(body)
 game.CollisionSafety.add_guards(body)
 var feet:=CollisionShape3D.new();var foot_shape:=CylinderShape3D.new()
 foot_shape.radius=game.FOOT_RADIUS;foot_shape.height=game.FOOT_HEIGHT
 feet.shape=foot_shape;feet.position.y=game.FOOT_HEIGHT*.5+.01;body.add_child(feet)
 var anchor:=companion.global_position
 var fitted: bool=game.CollisionSafety.clear_at(body,anchor)
 for ring in range(1,17):
  if fitted:break
  for direction in 32:
   var candidate: Vector3=anchor+Vector3(cos(direction*TAU/32)*ring*.25,0,sin(direction*TAU/32)*ring*.25)
   if game.CollisionSafety.clear_at(body,candidate):companion.global_position=candidate;fitted=true;break
 # 同伴固定用正面（idle_down）立绘，所以尺寸必须按 down 显式取值：
 # 直接复制 avatar.pixel_size / avatar.position.y 会随主角当前朝向变化，大小不确定。
 var sprite:=Sprite3D.new();sprite.texture=game.frames.get_frame_texture("idle_down",0);sprite.pixel_size=game.character_pixel_size("down")
 sprite.offset=game.avatar.offset;sprite.position=Vector3(0.0,game.character_ground_offset("down"),0.0);sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;sprite.alpha_scissor_threshold=.28;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;sprite.shaded=true;sprite.modulate=Color.WHITE;companion.add_child(sprite)
 # Guide uses the same live scene lighting and corrected frame depth.
 var material: ShaderMaterial=game.character_material.duplicate()
 material.set_shader_parameter("character_atlas",sprite.texture.atlas if sprite.texture is AtlasTexture else sprite.texture)
 game.CharacterSurface.apply(material,"down")
 game.CharacterProportions.apply(material,"down",game.character_manifest)
 game.CharacterPalette.apply(material,"down",game.character_manifest)
 sprite.material_override=material;sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in game.player.get_children():
  if child is MeshInstance3D and child.mesh is PlaneMesh:companion.add_child(child.duplicate())
 var label:=Label3D.new();label.text="大肥鱼 · E 对话";label.font=game._game_font();label.font_size=30;label.pixel_size=.014;label.position.y=2.1;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.modulate=Color("334475");label.outline_modulate=Color("fffdf4");label.outline_size=6;companion.add_child(label)

func can_talk() -> bool:
 if not is_instance_valid(companion) or active:return false
 if game.player.global_position.distance_to(companion.global_position)>3.0:return false
 var body: StaticBody3D=companion.get_node("GuideBody")
 var q:=PhysicsRayQueryParameters3D.create(game.player.global_position+Vector3(0,.5,0),companion.global_position+Vector3(0,.5,0),1,[game.player.get_rid(),body.get_rid()])
 return game.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _physics_process(_delta: float) -> void:
 if is_instance_valid(companion):companion.get_node("GuideBody").collision_layer=1 if companion.is_visible_in_tree() else 0
 if not is_instance_valid(hud_button):return
 if active:_hide_scene_labels()
 hud_button.visible=not active and not game.panel.visible and not game.settings_panel.visible and not game.dialog_open and not game.loot.blocked() and not game.editing
 if game.get("map_panel") and game.map_panel.visible:hud_button.hide()
 resume_button.visible=hud_button.visible and not state.bookmark.is_empty()
 if can_talk() and hud_button.visible:game.hint.text="大肥鱼在这里等你 · 按 E 对话 · Q 随时聊聊"

func start_topic() -> void:
 if active:return
 var place: String=str(game.get("location_id")) if game.get("location_id")!=null else "room"
 context={"place":place,"room":str(game.title.text),"object":"这里"}
 if not state.seen.has("welcome"):start("welcome")
 elif place=="city":start("harbor")
 elif place.begins_with("community"):start("cafe")
 elif place.begins_with("inn"):start("inn")
 else:start("home")

func start_context(object: Node) -> void:
 if not is_instance_valid(object):start_topic();return
 context={"place":str(game.get("location_id")),"room":str(game.title.text),"object":str(object.metadata.name)}
 var id: String=str(object.module_id)
 var story:="small_thing"
 if id.begins_with("bed_"):story="bed"
 elif id.begins_with("desk_"):story="desk"
 elif id.contains("plant") or id in ["fern","bonsai","flowers"]:story="plant"
 elif id.contains("book") or id in ["painting_whale","painting_mountain"]:story="books"
 elif id.contains("chair") or id.contains("sofa") or id.contains("loveseat"):story="seat"
 start(story)

func start(id: String,node: String="") -> void:
 if not stories.has(id):return
 if not active:game_ui_was_visible=game.ui.visible
 game.loot.close();game.panel.hide();game.settings_panel.hide();game.dialog.hide();game.editing=false
 if game.get("map_panel"):game._show_map(false)
 game.dialog_open=true;active=true;backlog_open=false;config_open=false;ui_hidden=false;backlog.hide();view.config.hide();view.chrome.show();auto_play=false;skip_play=false;trail.clear()
 game.ui.hide();_hide_scene_labels()
 current_story=id;current_node=node if node!="" else str(stories[id].start)
 root.show();_show_line()
 if transition and transition.is_running():transition.kill()
 portrait.modulate=Color(1,1,1,0);transition=create_tween();transition.tween_property(portrait,"modulate:a",1.0,.18)

func _format(value: String) -> String:
 for key in context:value=value.replace("{"+key+"}",str(context[key]))
 return value

func _show_line() -> void:
 if not stories[current_story].nodes.has(current_node):close();return
 current=stories[current_story].nodes[current_node]
 revealed=0.0;dwell=0.0;line_logged=false;line_start_history=state.history.size()
 type_tick_at=3
 speaker.text=str(current.get("speaker","大肥鱼"))
 text_label.text=_format(str(current.get("text","")));text_label.visible_characters=0
 text_label.scroll_to_line(0)
 var expression: String=str(current.get("expression","listen"))
 portrait.texture=portrait_regions.get(expression,game.frames.get_frame_texture("idle_down",0))
 portrait.visible=portrait_visible and speaker.text!="你" and speaker.text!="旁白"
 location_text.text=str(context.get("room",game.title.text))
 # 每显示一行对白翻一页。音量压得很低（连点会翻得很快），"page" 声道自带节流。
 SfxDirector.play("page",-9.0,1.0,"page")
 view.choices(current.get("choices",[]))
 state.bookmark={"story":current_story,"node":current_node,"context":context.duplicate(true),"trail":trail.duplicate(true)}
 view.line_changed()
 if current.has("route") and game.has_method("set_route") and game.locations.has(str(current.route)):
  game.set_route(str(current.route))
 _save_state();_refresh_hint()

func _process(delta: float) -> void:
 if not active:return
 if not game.dialog_open:close();return
 if backlog_open or config_open or ui_hidden:return
 view.tick(delta)
 var total:=text_label.get_total_character_count()
 if is_typing():
  revealed=minf(total,revealed+delta*(1800.0 if fast_forwarding() else float(reading.speed)))
  text_label.visible_characters=int(revealed)
  # 打字机音：每 3 个字响一次。一个字一响在中文语速下会变成机关枪，
  # 而且 type_tick 是正弦短点（不是噪声），连续响也不会积成沙沙声。
  if text_label.visible_characters>=type_tick_at:
   type_tick_at=text_label.visible_characters+3
   SfxDirector.play("type_tick",-15.0,1.0,"type")
  if text_label.visible_characters>=total:_line_complete()
 elif (auto_play or fast_forwarding()) and choice_buttons.is_empty():
  dwell+=delta
  if dwell>=auto_delay():advance()

func _line_complete() -> void:
 text_label.visible_characters=-1
 if not line_logged:
  state.history.append({"speaker":str(current.get("speaker","大肥鱼")),"text":text_label.text,"topic":str(stories[current_story].title),"story":current_story,"node":current_node,"context":context.duplicate(true),"flags":state.flags.duplicate(true)})
  while state.history.size()>200:state.history.pop_front();line_start_history=maxi(0,line_start_history-1)
  line_logged=true;_save_state()
 choice_panel.visible=not choice_buttons.is_empty()
 if not choice_buttons.is_empty():skip_play=false
 _refresh_hint()

func is_typing() -> bool:
 return text_label.visible_characters>=0 and text_label.visible_characters<text_label.get_total_character_count()

func _refresh_hint() -> void:
 advance_hint.text="…" if is_typing() else ("SKIP" if fast_forwarding() else "AUTO" if auto_play else "NEXT")
 view.refresh()

func advance() -> void:
 if not active or backlog_open or config_open or ui_hidden:return
 if is_typing():revealed=text_label.get_total_character_count();_line_complete();return
 if not choice_buttons.is_empty():return
 var next: String=str(current.get("next",""))
 if next=="":
  state.seen[current_story]=true;state.bookmark={};_save_state();close();return
 trail.append(_reading_snapshot());current_node=next;_show_line()

func choose(index: int) -> void:
 if not active or backlog_open or is_typing() or index<0 or index>=choice_buttons.size():return
 var choices: Array=current.get("choices",[])
 if index>=choices.size():return
 var choice: Dictionary=choices[index]
 var previous:=_reading_snapshot()
 var old: Dictionary=state.duplicate(true)
 state.history.append({"speaker":"你","text":_format(str(choice.text)),"topic":str(stories[current_story].title)})
 if choice.has("flag"):state.flags[str(choice.flag)]=true
 state.bookmark={"story":current_story,"node":str(choice.next),"context":context.duplicate(true)}
 if not _save_state():state=old;advance_hint.text="选择保存失败，请重试。";return
 trail.append(previous);current_node=str(choice.next);_show_line()

func set_auto(value: bool) -> void:
 auto_play=value;dwell=0
 if value:skip_play=false
 _refresh_hint()

func close() -> void:
 if active:_save_state()
 active=false;auto_play=false;skip_play=false;backlog_open=false;config_open=false;ui_hidden=false;root.hide();backlog.hide();view.config.hide();choice_panel.hide();game.dialog_open=false
 game.ui.visible=game_ui_was_visible
 if is_instance_valid(companion):
  for child in companion.get_children():
   if child is Label3D:child.show()
 game.dialog.hide();game.player.velocity=Vector3.ZERO

func _hide_scene_labels() -> void:
 for label in get_tree().get_nodes_in_group("floor_room_labels"):label.hide()
 if is_instance_valid(companion):
  for child in companion.get_children():
   if child is Label3D:child.hide()

func _click_advance(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
  if ui_hidden:toggle_hidden()
  else:advance()
  get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
 var pack: Variant=game.get("pack26_controller")
 if pack!=null and pack.blocked():return
 var expedition: Variant=game.get("expedition_controller")
 if expedition!=null and (expedition.is_active() or expedition.blocked()):return
 if game.combat_controller and game.combat_controller.in_battle():return
 if game.pause_menu and game.pause_menu.active:return
 if game.character_controller and game.character_controller.active:return
 if event is InputEventKey and event.pressed and not event.echo:
  if active:
   if not event.physical_keycode in [KEY_ESCAPE,KEY_H,KEY_A,KEY_Q,KEY_L,KEY_ENTER,KEY_SPACE,KEY_E,KEY_1,KEY_2,KEY_3]:return
   var focused:=get_viewport().gui_get_focus_owner()
   if event.physical_keycode in [KEY_ENTER,KEY_SPACE] and focused is BaseButton and root.is_ancestor_of(focused):return
   if backlog_open:
    if event.physical_keycode in [KEY_ESCAPE,KEY_H]:hide_backlog()
   elif config_open:
    if event.physical_keycode in [KEY_ESCAPE,KEY_H]:hide_config()
   elif ui_hidden:
    if event.physical_keycode in [KEY_ESCAPE,KEY_H,KEY_ENTER,KEY_SPACE]:toggle_hidden()
   elif event.physical_keycode==KEY_ESCAPE:close()
   elif event.physical_keycode==KEY_H:toggle_hidden()
   elif event.physical_keycode==KEY_A:set_auto(not auto_play)
   elif event.physical_keycode==KEY_Q:quick_save()
   elif event.physical_keycode==KEY_L:quick_load()
   elif event.physical_keycode in [KEY_ENTER,KEY_SPACE,KEY_E]:advance()
   elif event.physical_keycode in [KEY_1,KEY_2,KEY_3]:choose(int(event.physical_keycode)-KEY_1)
   get_viewport().set_input_as_handled()
  elif event.physical_keycode==KEY_Q and hud_button.visible:start_topic();get_viewport().set_input_as_handled()

func show_backlog() -> void:
 if not active:return
 if is_typing():_line_complete()
 config_open=false;view.config.hide();backlog_open=true;backlog.show();choice_panel.hide()
 for child in log_list.get_children():log_list.remove_child(child);child.queue_free()
 for i in state.history.size():
  var entry:Dictionary=state.history[i]
  var block:=VBoxContainer.new();block.size_flags_horizontal=Control.SIZE_EXPAND_FILL;log_list.add_child(block)
  var row:=HBoxContainer.new();block.add_child(row)
  var who:=Label.new();who.text=str(entry.speaker)+"  ·  "+str(entry.topic);who.size_flags_horizontal=Control.SIZE_EXPAND_FILL;who.add_theme_font_size_override("font_size",17);who.add_theme_color_override("font_color",view.MUTED);row.add_child(who)
  if stories.has(str(entry.get("story",""))) and stories[str(entry.story)].nodes.has(str(entry.get("node",""))):
   var index:int=i;var jump:Button=view.action(row,"回到这里 ↶",func():jump_history(index));jump.custom_minimum_size=Vector2(140,32);jump.add_theme_font_size_override("font_size",14)
  var line:=Label.new();line.text=str(entry.text);line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;line.custom_minimum_size.x=974;line.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_theme_font_size_override("font_size",22);line.add_theme_color_override("font_color",view.INK);block.add_child(line)
 call_deferred("_scroll_bottom")

func _scroll_bottom() -> void:
 await get_tree().process_frame
 log_scroll.scroll_vertical=int(log_scroll.get_v_scroll_bar().max_value)

func hide_backlog() -> void:
 backlog_open=false;backlog.hide();choice_panel.visible=not choice_buttons.is_empty() and not is_typing();dwell=0

func resume() -> bool:
 var bookmark: Dictionary=state.get("bookmark",{})
 if bookmark.is_empty() or not stories.has(str(bookmark.get("story",""))):return false
 var id:=str(bookmark.story);var node:=str(bookmark.get("node",""))
 if not stories[id].nodes.has(node):return false
 context=bookmark.get("context",{});var saved_trail:Array=bookmark.get("trail",[]).duplicate(true);start(id,node);trail=saved_trail;state.bookmark.trail=trail.duplicate(true);_refresh_hint();return true

func _save_state() -> bool:
 var file:=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
 if not file:return false
 file.store_string(JSON.stringify(state));file.flush();file.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path))==OK

func _load_state() -> void:
 if not FileAccess.file_exists(save_path):return
 var value=JSON.parse_string(FileAccess.get_file_as_string(save_path))
 if value is Dictionary and value.get("version",0)==1 and value.get("seen") is Dictionary and value.get("flags") is Dictionary and value.get("history") is Array and value.get("bookmark") is Dictionary:
  state=value

func fast_forwarding()->bool:return skip_play or Input.is_physical_key_pressed(KEY_CTRL)

func auto_delay()->float:
 return .12 if fast_forwarding() else maxf(float(reading.wait),float(text_label.get_total_character_count())*.045)

func set_skip(value:bool)->void:
 skip_play=value;dwell=0
 if value:auto_play=false
 _refresh_hint()

func _reading_snapshot()->Dictionary:
 return {"story":current_story,"node":current_node,"context":context.duplicate(true),"flags":state.flags.duplicate(true),"seen":state.seen.duplicate(true),"history":state.history.slice(0,line_start_history).duplicate(true),"route":str(game.get("route_destination"))}

func previous_line()->void:
 if not active or trail.is_empty():return
 var previous:Dictionary=trail.pop_back();auto_play=false;skip_play=false
 state.flags=previous.flags;state.seen=previous.seen;state.history=previous.history
 if game.has_method("set_route"):game.set_route(previous.get("route",""))
 current_story=previous.story;current_node=previous.node;context=previous.context;_show_line()

func quick_save()->void:
 if not active:return
 var old:Dictionary=state.get("quick_save",{}).duplicate(true)
 var snapshot:=_reading_snapshot();snapshot.trail=trail.duplicate(true);snapshot.completed=not is_typing();state.quick_save=snapshot
 if _save_state():view.message("已快存 · "+str(stories[current_story].title))
 else:state.quick_save=old;view.message("快存失败，请重试。")
 view.refresh()

func quick_load()->void:
 var snapshot:Dictionary=state.get("quick_save",{}).duplicate(true)
 if snapshot.is_empty():return
 state.flags=snapshot.flags;state.seen=snapshot.seen;state.history=snapshot.history;context=snapshot.context
 if game.has_method("set_route"):game.set_route(snapshot.get("route",""))
 start(snapshot.story,snapshot.node);trail=snapshot.trail;state.bookmark.trail=trail.duplicate(true)
 if snapshot.completed:_line_complete()
 _save_state();_refresh_hint();view.message("已读取快存")

func jump_history(index:int)->void:
 var entry:Dictionary=state.history[index].duplicate(true)
 state.history=state.history.slice(0,index);state.flags=entry.get("flags",state.flags).duplicate(true);context=entry.get("context",{}).duplicate(true)
 start(entry.story,entry.node)

func toggle_hidden()->void:
 ui_hidden=not ui_hidden;view.chrome.visible=not ui_hidden;dwell=0

func show_config()->void:
 if not active:return
 backlog_open=false;backlog.hide();config_open=true;view.config.show();choice_panel.hide();dwell=0

func hide_config()->void:
 save_reading();config_open=false;view.config.hide();choice_panel.visible=not choice_buttons.is_empty() and not is_typing();dwell=0

func save_reading()->void:
 chars_per_second=float(reading.speed);state.reading=reading.duplicate(true);_save_state()
