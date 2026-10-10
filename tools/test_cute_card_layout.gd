extends SceneTree
var failures:=0
func _initialize()->void: call_deferred("run")
func check(ok:bool,note:String)->void:
 if not ok: failures+=1;push_error(note)
func run()->void:
 root.size=Vector2i(1448,1086)
 var cards:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/catalog.json"))
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/cute_v22/paintings.json"))
 check(manifest.size()==cards.size(),"all 42 skills have new illustrations")
 var unique:Dictionary={}
 for entry in cards:
  var art:Dictionary=manifest.get(str(entry.id),{})
  check(not art.is_empty(),str(entry.name)+" illustration assigned")
  var key:=str(art.get("atlas",""))+":"+str(art.get("cell",-1))
  check(not unique.has(key),str(entry.name)+" does not share an illustration")
  unique[key]=true
  check(ResourceLoader.exists(str(art.get("atlas",""))),str(entry.name)+" painting resource available")
 var font:=load("res://assets/NotoSansSC.ttf")
 var holder:=Control.new();holder.theme=load("res://battle/battle_skin.gd").theme(font);root.add_child(holder)
 for entry in cards:
  var face=load("res://battle/card_face.gd").new();face.configure(entry);holder.add_child(face)
  await process_frame
  var title:Label=face.get_node("CardTitle")
  check(title.get_theme_font("font").get_string_size(title.text,HORIZONTAL_ALIGNMENT_LEFT,-1,title.get_theme_font_size("font_size")).x <= title.size.x,str(entry.name)+" full hand title fits")
  for child in face.get_children():
   if child is Panel and child.position.y>100:
    for label in child.get_children():
     if label is Label:
      check(child.position.y+label.position.y+label.size.y <= face.size.y, str(entry.name)+" effect text fits card")
      check(label.get_line_count()*label.get_line_height()<=label.size.y+1,str(entry.name)+" hand effects have enough line space")
  face.queue_free()
 var engine=load("res://battle/battle_engine.gd").new(20261004)
 var body_font=load("res://battle/battle_skin.gd").body_font()
 check(body_font.get_font_name().contains("MiSans"),"battle uses MiSans rather than the old variable font")
 var missing_glyphs:Dictionary={}
 for entry in cards:
  var skill_text:String=str(entry.name)+str(entry.description)
  for char_index in skill_text.length():
   var code:int=skill_text.unicode_at(char_index)
   if code>=32 and not body_font.has_char(code):missing_glyphs[code]=true
 if not missing_glyphs.is_empty():print("MISSING FONT GLYPHS ",missing_glyphs.keys())
 check(missing_glyphs.is_empty(),"new battle font contains every skill title and description glyph")
 engine.add_ally({"id":"player","name":"大肥鱼","hp":100,"max_hp":100,"stamina":100,"max_stamina":100,"atk":10,"def":7})
 engine.add_foe({"id":"slime","kind":"slime","name":"海沫团","hp":100,"max_hp":100,"atk":3,"def":1})
 engine.enable_cards(cards)
 var screen=load("res://battle/battle_screen.gd").new();root.add_child(screen);screen.open(engine,{"title":"新卡牌界面检查"})
 for n in 8: await process_frame
 screen._finish_playback()
 for n in 3: await process_frame
 check(screen.card_panel.position.y+screen.card_panel.size.y <= screen.dash.dock.position.y,"hand stays above status dock")
 check(screen.log_box.position.y+screen.log_box.size.y+8 <= screen.card_panel.position.y,"feedback row has a clear gap above hand")
 check(screen.card_panel.position.y+screen.card_panel.size.y+20 <= screen.dash.dock.position.y,"hand and dock have a full breathing gap")
 check(screen.log_box.position.y+screen.log_box.size.y+20 <= screen.card_panel.position.y,"feedback is separated from the card tray")
 check(screen.card_scroll.position.y>=16 and screen.card_scroll.position.y+screen.card_scroll.size.y+12<=screen.card_panel.size.y,"card tray reserves top and bottom padding")
 check(screen.dash.block_badge.panel.position.x+screen.dash.block_badge.panel.size.x+12<=screen.dash.gauges[0].group.position.x,"block badge belongs to character info and stays clear of life gauge")
 check(screen.dash.name.position.y+screen.dash.name.size.y+8<=screen.dash.block_badge.panel.position.y,"block badge stays below the character name")
 check(screen.dash.block_badge.panel.position.y+screen.dash.block_badge.panel.size.y+6<=screen.dash.status_icons.position.y,"block badge stays clear of timed statuses")
 check(screen.dash.block_badge.panel.position.y+screen.dash.block_badge.panel.size.y+12<=screen.dash.dock.size.y,"block badge stays clear of the outer frame")
 for control in [screen.card_panel,screen.dash.dock,screen.log_box,screen.tactics_box,screen.card_end_button,screen.card_link_button,screen.dash.portrait_frame]:
  check(control.has_node("PaintedUiSurface"),"battle controls consume generated UI materials")
 var end_surface:TextureRect=screen.card_end_button.get_node("PaintedUiSurface")
 screen.card_end_button.disabled=true
 for n in 2: await process_frame
 check(float(end_surface.material.get_shader_parameter("state_gray"))>.5,"generated button material visibly distinguishes disabled state")
 screen.card_end_button.disabled=false
 for n in 2: await process_frame
 check(float(end_surface.material.get_shader_parameter("state_gray"))==0,"generated button restores enabled material")
 var paint_surface:TextureRect=screen.dash.gauges[0].fill.get_node("PaintedUiSurface")
 var gauge_style:StyleBoxFlat=screen.dash.gauges[0].style
 var prior_color:Color=gauge_style.bg_color
 gauge_style.bg_color=Color("fff0c0")
 for n in 2: await process_frame
 check(paint_surface.material.get_shader_parameter("surface_tint").is_equal_approx(gauge_style.bg_color),"generated gauge follows live fill color")
 gauge_style.bg_color=prior_color
 check(screen.tactics_name.position.x+screen.tactics_name.size.x+12 <= screen.tactics_text.position.x,"target name and intent do not collide")
 check(screen.card_energy_label.position.y+screen.card_energy_label.size.y+8 <= screen.card_panel.get_node("CardEnergyBadge").position.y+screen.card_panel.get_node("CardEnergyBadge").get_node("CardEnergyCaption").position.y,"energy number and caption have separate rows")
 for gauge in screen.dash.gauges:
  check(gauge.title.position.x+gauge.title.size.x+12 <= gauge.value.position.x,"status title has space before numbers")
  check(gauge.value.position.y+gauge.value.size.y+8 <= gauge.back.position.y,"status numbers stay clear of bar")
 for entry in cards:
  var face=load("res://battle/card_face.gd").new();face.configure(entry,Vector2(242,360),true);holder.add_child(face)
  await process_frame
  for child in face.get_children():
   if child is Panel and child.position.y>100:
    for label in child.get_children():
     if label is Label: check(label.get_line_count()*label.get_line_height()<=label.size.y+1,str(entry.name)+" full preview effect text fits")
  face.queue_free()
 for face in screen.card_row.get_children(): check(face.size.y+8 <= screen.card_scroll.size.y,"full hand card fits with scrollbar")
 engine.hand.clear()
 for entry in cards.slice(0,8): engine.hand.append(str(entry.id))
 screen._refresh_cards()
 for n in 4: await process_frame
 check(screen.card_scroll.get_h_scroll_bar().visible and screen.card_scroll.get_h_scroll_bar().size.y >= 6,"many-card hand has usable scrollbar")
 screen.card_row.get_child(7).grab_focus()
 for n in 3: await process_frame
 check(screen.card_scroll.scroll_horizontal>0,"keyboard focus scrolls to last card")
 for face in screen.card_row.get_children(): check(face.size.y <= screen.card_scroll.size.y-screen.card_scroll.get_h_scroll_bar().size.y,"all card bottoms fit above scrollbar")
 var before:=int(engine.round_no)
 screen.card_end_button.pressed.emit()
 check(int(engine.round_no)>before,"end-turn button advances round")
 screen._finish_playback()
 check(engine.hand.size()==5,"next turn deals five cards")
 screen.close();screen.queue_free()
 print("CUTE CARD LAYOUT FAILURES ",failures)
 quit(0 if failures==0 else 1)


