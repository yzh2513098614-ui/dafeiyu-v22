extends RefCounted
## Native presentation of the approved webpage. State stays in dialogue_controller.
const Shared=preload("res://ui/harbor_inventory_skin.gd")
const WARM:=Color("fffafc")
const INK:=Color("73556c")
const MUTED:=Color("9c748b")
const MINT:=Color("c9fff0")
var d
var chrome:Control
var chapter:Panel
var chapter_title:Label
var chapter_number:Label
var chapter_kicker:Label
var toolbar:Control
var tools:Dictionary={}
var cue:Button
var orbit:TextureRect
var star:TextureRect
var read_meter:ProgressBar
var wait_meter:ProgressBar
var brand:Label
var progress:Label
var notice:Label
var letter:TextureRect
var config:Panel
var wash:ColorRect
var elapsed:=0.0
var notice_time:=0.0

func _init(controller)->void:d=controller

func frame(fill:Color=Color("fff2f8"),edge:Color=Color("dfb8cf"),width:int=2)->StyleBoxFlat:
 var b:=StyleBoxFlat.new();b.bg_color=fill;b.border_color=edge;b.set_border_width_all(width);b.set_corner_radius_all(16);b.shadow_color=Color("b894b4");b.shadow_offset=Vector2(0,4);b.shadow_size=1
 return b

func label(parent:Node,text:String,pos:Vector2,dimensions:Vector2,font_size:int=20,color:Color=INK)->Label:
 return Shared.label(parent,text,pos,dimensions,font_size,color)

func icon(parent:Node,key:String,pos:Vector2,dimensions:Vector2,color:Color=WARM)->TextureRect:
 var node:=Shared.icon(parent,key,pos,dimensions);node.self_modulate=color;return node

func panel(parent:Node,name:String,dimensions:Vector2)->Panel:
 var p:=Panel.new();p.name=name;p.size=dimensions;p.add_theme_stylebox_override("panel",frame());parent.add_child(p);return p

func action(parent:Node,title:String,callback:Callable,quiet:bool=false)->Button:
 var b:=Button.new();b.text=title;b.pressed.connect(callback);b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for state in ["normal","hover","pressed","disabled","focus"]:
  var style:StyleBox=StyleBoxEmpty.new() if quiet else frame(Color("fffbfdee") if state=="normal" else Color("fbe5f2"))
  if state=="focus":style=frame(Color("ffffff0c"),MINT if quiet else Color("b68cc1"),2);style.shadow_size=0
  b.add_theme_stylebox_override(state,style)
 for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,WARM if quiet else INK)
 b.add_theme_color_override("font_disabled_color",Color("fffafc55") if quiet else Color("bfa9ba"));b.add_theme_font_size_override("font_size",18)
 if quiet:
  b.add_theme_color_override("font_shadow_color",Color("71405666"));b.add_theme_constant_override("shadow_offset_y",1)
 parent.add_child(b);return b

func meter(parent:Node,name:String,color:Color)->ProgressBar:
 var p:=ProgressBar.new();p.name=name;p.show_percentage=false;p.max_value=1;p.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var track:=StyleBoxFlat.new();track.bg_color=Color("fff8fc40")
 var fill:=StyleBoxFlat.new();fill.bg_color=color;p.add_theme_stylebox_override("background",track);p.add_theme_stylebox_override("fill",fill);parent.add_child(p);return p

func build()->void:
 d.layer=CanvasLayer.new();d.layer.layer=50;d.add_child(d.layer)
 d.root=Control.new();d.root.name="GalDialogue";d.root.size=Vector2(1448,1086);d.root.theme=Shared.theme();d.layer.add_child(d.root);d.UiFit.fill(d.root)
 d.shade=ColorRect.new();d.shade.name="SceneTint";d.shade.color=Color("68465c14");d.root.add_child(d.shade);d.UiFit.fill(d.shade);d.shade.gui_input.connect(d._click_advance)
 d.portrait=TextureRect.new();d.portrait.name="Portrait";d.portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;d.portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;d.portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;d.portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;d.portrait.set_meta("runtime_texture",true);d.root.add_child(d.portrait)
 chrome=Control.new();chrome.name="ReadingChrome";chrome.mouse_filter=Control.MOUSE_FILTER_IGNORE;d.root.add_child(chrome);d.UiFit.fill(chrome)
 chapter=panel(chrome,"Chapter",Vector2(310,130));Shared.surface(chapter,Color("fffdf9ed"),Color("eee9ffdc"),3,13)
 chapter_kicker=label(chapter,"CHAPTER",Vector2(22,18),Vector2(86,20),11,MUTED)
 chapter_number=label(chapter,"01",Vector2(112,17),Vector2(30,22),12);chapter_number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;chapter_number.add_theme_stylebox_override("normal",frame(Color("fbebf4"),Color("e3bfd5"),1))
 chapter_title=label(chapter,"海风与来信",Vector2(22,47),Vector2(274,36),24)
 d.location_text=label(chapter,"",Vector2(41,93),Vector2(247,23),11,MUTED);d.location_text.autowrap_mode=TextServer.AUTOWRAP_OFF;d.location_text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 icon(chapter,"gal-letter",Vector2(22,97),Vector2(13,13),Color("ca9cbb"))
 var ribbon:=ColorRect.new();ribbon.position=Vector2(263,0);ribbon.size=Vector2(25,35);ribbon.color=Color("ca9cbb");ribbon.mouse_filter=Control.MOUSE_FILTER_IGNORE;chapter.add_child(ribbon);icon(ribbon,"star",Vector2(6,8),Vector2(13,13))
 d.box=Panel.new();d.box.name="DialogueWash";d.box.add_theme_stylebox_override("panel",StyleBoxEmpty.new());chrome.add_child(d.box);d.box.gui_input.connect(d._click_advance)
 wash=ColorRect.new();wash.name="PinkGradient";wash.mouse_filter=Control.MOUSE_FILTER_IGNORE;var material:=ShaderMaterial.new();material.shader=preload("res://assets/ui/sticker/dialogue_wash.gdshader");wash.material=material;d.box.add_child(wash);d.UiFit.fill(wash)
 letter=icon(d.box,"gal-letter",Vector2.ZERO,Vector2(92,83));letter.modulate.a=.16
 d.speaker=label(d.box,"",Vector2.ZERO,Vector2(900,40),25,WARM)
 d.speaker.add_theme_color_override("font_shadow_color",Color("71405688"));d.speaker.add_theme_constant_override("shadow_offset_y",2)
 d.text_label=RichTextLabel.new();d.text_label.name="DialogueText";d.text_label.bbcode_enabled=false;d.text_label.scroll_active=true;d.text_label.mouse_filter=Control.MOUSE_FILTER_PASS;d.text_label.add_theme_color_override("default_color",WARM);d.text_label.add_theme_color_override("font_shadow_color",Color("71405688"));d.text_label.add_theme_constant_override("shadow_offset_y",2);d.text_label.gui_input.connect(d._click_advance);d.box.add_child(d.text_label)
 d.advance_hint=label(d.box,"",Vector2.ZERO,Vector2(96,24),11,WARM);d.advance_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 cue=action(d.box,"",func():d.advance(),true);cue.name="ContinueDialogue";cue.tooltip_text="补全当前句 / 下一句（Space / Enter）"
 orbit=icon(cue,"next-orbit",Vector2(10,0),Vector2(44,44));star=icon(cue,"star",Vector2(22,12),Vector2(20,20))
 read_meter=meter(d.box,"CharacterProgress",WARM);wait_meter=meter(d.box,"AutoWaitProgress",MINT)
 brand=label(d.box,"潮汐手记",Vector2.ZERO,Vector2(170,24),13,Color("fffafcaa"))
 progress=label(d.box,"",Vector2.ZERO,Vector2(210,22),11,Color("fffafc99"))
 toolbar=Control.new();toolbar.name="QuickToolbar";toolbar.mouse_filter=Control.MOUSE_FILTER_IGNORE;d.box.add_child(toolbar)
 var definitions:Array=[["Q.SAVE","gal-save","快存当前对白（Q）",func():d.quick_save()],["Q.LOAD","gal-load","读取快存（L）",func():d.quick_load()],["LOG","gal-letter","对话回看",func():d.show_backlog()],["SKIP","gal-skip","快进，遇到选项停止（Ctrl）",func():d.set_skip(not d.skip_play)],["AUTO","gal-play","自动阅读（A）",func():d.set_auto(not d.auto_play)],["BACK","gal-back","回到上一句并允许重选",func():d.previous_line()],["NEXT","gal-next","补全 / 下一句",func():d.advance()],["CONFIG","gal-config","阅读设置",func():d.show_config()],["HIDE","gal-eye","隐藏界面（H），点击恢复",func():d.toggle_hidden()]]
 for item in definitions:
  var b:=action(toolbar,str(item[0]),item[3],true);b.name=str(item[0]).replace(".","");b.tooltip_text=str(item[2]);b.alignment=HORIZONTAL_ALIGNMENT_RIGHT;b.add_theme_font_size_override("font_size",13)
  var glyph:=icon(b,str(item[1]),Vector2(3,13),Vector2(15,15));glyph.modulate.a=.48;tools[item[0]]=b
 d.auto_button=tools.AUTO
 notice=label(chrome,"",Vector2.ZERO,Vector2(360,36),17,WARM);notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 var exit:=action(chrome,"返回游戏  ×",func():d.close(),true);exit.name="ExitDialogue";exit.tooltip_text="结束对话并返回游戏（Esc）";exit.size=Vector2(160,42);d.UiFit.pin_right(exit,160,48,32,42)
 d.choice_panel=panel(chrome,"ReplyChoices",Vector2(645,299));d.choice_panel.hide()
 build_backlog();build_config();d.root.resized.connect(layout);layout();d.root.hide()

func build_backlog()->void:
 d.backlog=panel(chrome,"DialogueBacklog",Vector2(1060,760));d.backlog.hide()
 label(d.backlog,"对话回看",Vector2(30,22),Vector2(800,44),30)
 label(d.backlog,"点击带箭头的对白可以回到该句。",Vector2(32,75),Vector2(800,30),17,MUTED)
 var close:=action(d.backlog,"返回对话",func():d.hide_backlog());close.position=Vector2(850,27);close.size=Vector2(180,46)
 d.log_scroll=ScrollContainer.new();d.log_scroll.position=Vector2(30,124);d.log_scroll.size=Vector2(1000,600);d.log_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;d.backlog.add_child(d.log_scroll)
 d.log_list=VBoxContainer.new();d.log_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;d.log_list.add_theme_constant_override("separation",20);d.log_scroll.add_child(d.log_list)

func build_config()->void:
 config=panel(chrome,"ReadingSettings",Vector2(740,560));config.hide()
 label(config,"阅读设置",Vector2(32,25),Vector2(400,45),30)
 var close:=action(config,"返回对话",func():d.hide_config());close.position=Vector2(530,27);close.size=Vector2(180,46)
 var items:Array=[["文字速度","speed",20,80,1,"字 / 秒"],["自动等待","wait",.8,5,.1,"秒"],["正文字号","font",24,36,1,"px"],["渐变浓度","opacity",.35,1,.01,"%"]]
 for i in items.size():
  var row:Array=items[i];var key:String=row[1];label(config,row[0],Vector2(34,109+i*88),Vector2(180,28),20)
  var value:=label(config,"",Vector2(548,109+i*88),Vector2(155,28),17,MUTED);value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  var slider:=HSlider.new();slider.name="Reading_"+key;slider.position=Vector2(220,112+i*88);slider.size=Vector2(300,28);slider.min_value=row[2];slider.max_value=row[3];slider.step=row[4];slider.value=d.reading[key];slider.tooltip_text=row[0];config.add_child(slider)
  var display:=func(v:float):value.text=(str(roundi(v*100))+"%") if key=="opacity" else (str(snappedf(v,.1))+" "+str(row[5]))
  display.call(slider.value);slider.value_changed.connect(func(v:float):d.reading[key]=v;display.call(v);layout())
  slider.drag_ended.connect(func(_changed:bool):d.save_reading())
 var motion:=CheckButton.new();motion.name="ReadingMotion";motion.text="轻微闪烁与旋转";motion.position=Vector2(34,472);motion.size=Vector2(650,45);motion.button_pressed=d.reading.motion;config.add_child(motion);motion.toggled.connect(func(value:bool):d.reading.motion=value;d.save_reading())

func layout()->void:
 var size:Vector2=d.root.size;var s:=size.y/815.0
 var portrait_size:=Vector2(650,780)*s;d.portrait.position=Vector2(size.x*.535-portrait_size.x/2,size.y-portrait_size.y+1);d.portrait.size=portrait_size
 chapter.position=Vector2(55,32)*s;chapter.scale=Vector2.ONE*s
 d.box.position=Vector2(0,size.y-264*s);d.box.size=Vector2(size.x,264*s)
 var left:=size.x*240.0/1448.0
 d.speaker.position=Vector2(left,37*s);d.speaker.size=Vector2(size.x-left-174*s,40*s);d.speaker.add_theme_font_size_override("font_size",roundi(25*s))
 d.text_label.position=Vector2(left,86*s);d.text_label.size=Vector2(size.x-left-174*s,125*s);d.text_label.add_theme_font_size_override("normal_font_size",roundi((float(d.reading.font)-(1 if d.current.get("speaker","")=="旁白" else 0))*s));d.text_label.add_theme_constant_override("line_separation",roundi(9*s))
 letter.position=Vector2(70,82)*s;letter.size=Vector2(92,83)*s
 cue.position=Vector2(size.x-139*s,118*s);cue.size=Vector2(70,67)*s;orbit.position=Vector2(13,0)*s;orbit.size=Vector2(44,44)*s;orbit.pivot_offset=orbit.size/2;star.position=Vector2(25,12)*s;star.size=Vector2(20,20)*s
 d.advance_hint.position=Vector2(size.x-149*s,164*s);d.advance_hint.size=Vector2(96,24)*s;d.advance_hint.add_theme_font_size_override("font_size",roundi(11*s))
 read_meter.position=Vector2(size.x-149*s,195*s);read_meter.size=Vector2(96*s,2*s);wait_meter.position=read_meter.position+Vector2(0,5*s);wait_meter.size=read_meter.size
 brand.position=Vector2(55,232)*s;brand.add_theme_font_size_override("font_size",roundi(13*s));progress.position=Vector2(left,235*s);progress.add_theme_font_size_override("font_size",roundi(11*s))
 var menu_scale:=minf(s,(size.x-360*s)/950.0);toolbar.position=Vector2(size.x-48*s-950*menu_scale,220*s);toolbar.size=Vector2(950*menu_scale,42*s)
 for i in tools.size():
  var b:Button=tools.values()[i];b.position=Vector2(i*106*menu_scale,0);b.size=Vector2(96*menu_scale,42*s);b.add_theme_font_size_override("font_size",roundi(13*menu_scale));var glyph:TextureRect=b.get_child(0);glyph.position=Vector2(2*menu_scale,13*s);glyph.size=Vector2(15*menu_scale,15*menu_scale)
 notice.position=Vector2(size.x-440*s,88*s)
 d.choice_panel.position=Vector2((size.x-d.choice_panel.size.x)/2,size.y-264*s-d.choice_panel.size.y-24*s)
 d.backlog.position=(size-d.backlog.size)/2;config.position=(size-config.size)/2
 var night:bool=d.game.atmosphere.hour<7 or d.game.atmosphere.hour>=18
 wash.material.set_shader_parameter("blush",Color("74486f") if night else Color("f299bb"));wash.material.set_shader_parameter("strength",d.reading.opacity)
 chapter.add_theme_stylebox_override("panel",frame(Color("48364fee") if night else Color("fff2f8"),Color("ad8fae") if night else Color("dfb8cf")))
 var chapter_surface:ShaderMaterial=chapter.get_node("StickerSurface").material
 chapter_surface.set_shader_parameter("start_color",Color("48364fe6") if night else Color("fffdf9ed"));chapter_surface.set_shader_parameter("end_color",Color("635171e6") if night else Color("eee9ffdc"))
 chapter_title.add_theme_color_override("font_color",WARM if night else INK);chapter_kicker.add_theme_color_override("font_color",Color("d5bed2") if night else MUTED);d.location_text.add_theme_color_override("font_color",Color("d5bed2") if night else MUTED)

func choices(options:Array)->void:
 for child in d.choice_panel.get_children():d.choice_panel.remove_child(child);child.queue_free()
 d.choice_buttons.clear();d.choice_panel.hide();d.choice_panel.size.y=75+options.size()*65
 if not options.is_empty():
  label(d.choice_panel,"你想怎么回应？",Vector2(24,13),Vector2(590,35),23)
  for i in options.size():
   var index:=i;var b:=action(d.choice_panel,str(i+1)+"  "+d._format(str(options[i].text)),func():d.choose(index));b.position=Vector2(23,60+i*65);b.size=Vector2(599,54);d.choice_buttons.append(b)
 layout()

func line_changed()->void:
 d.speaker.text="〔 "+str(d.current.get("speaker","大肥鱼"))+" 〕"
 chapter_title.text=str(d.stories[d.current_story].title);chapter_number.text="%02d"%[d.stories.keys().find(d.current_story)+1]
 progress.text="CHAPTER %02d  ·  %02d / %02d"%[d.stories.keys().find(d.current_story)+1,d.stories[d.current_story].nodes.keys().find(d.current_node)+1,d.stories[d.current_story].nodes.size()]
 layout();refresh()

func refresh()->void:
 tools["Q.LOAD"].disabled=d.state.get("quick_save",{}).is_empty();tools.BACK.disabled=d.trail.is_empty();tools.NEXT.disabled=not d.choice_buttons.is_empty() and not d.is_typing();cue.visible=d.is_typing() or d.choice_buttons.is_empty();read_meter.visible=cue.visible;d.advance_hint.visible=cue.visible
 for key in ["AUTO","SKIP"]:tools[key].add_theme_color_override("font_color",MINT if (d.auto_play if key=="AUTO" else d.skip_play) else WARM)

func tick(delta:float)->void:
 if d.ui_hidden or d.backlog_open or d.config_open:return
 elapsed+=delta;var typing:bool=d.is_typing();var automatic:bool=d.auto_play or d.fast_forwarding()
 read_meter.value=clampf(float(d.text_label.visible_characters)/maxi(1,d.text_label.get_total_character_count()),0,1) if typing else 1
 wait_meter.visible=not typing and automatic and d.choice_buttons.is_empty();wait_meter.value=d.dwell/d.auto_delay()
 var accent:=MINT if automatic else WARM;orbit.self_modulate=accent;star.self_modulate=accent;d.advance_hint.add_theme_color_override("font_color",accent)
 if d.reading.motion:
  orbit.rotation=elapsed*(2.0 if d.fast_forwarding() else .45);star.modulate.a=.62+.30*sin(elapsed*TAU/1.65);orbit.modulate.a=.55+.18*sin(elapsed*TAU/1.65)
 else:orbit.rotation=0;orbit.modulate.a=.75;star.modulate.a=.9
 if notice_time>0:notice_time-=delta;notice.visible=notice_time>0

func message(text:String)->void:notice.text=text;notice.show();notice_time=2.5
