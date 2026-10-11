extends SceneTree
## Run with --test-session-ui --test-dialogue; all player saves remain isolated.
const OUTPUT="res://预览/下载图标接入_20261011/"
var checks:=0
var failures:=0
var game

func _initialize() -> void:
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,true)
 DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")

func check(ok: bool,message: String) -> void:
 checks+=1
 if ok:print("PASS ",message)
 else:failures+=1;push_error("FAIL "+message)

func settle(frames: int=12) -> void:
 for i in frames:await process_frame

func shot(filename: String) -> void:
 await settle()
 RenderingServer.force_draw(false)
 check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT+filename+".png"))==OK,"screenshot "+filename)

func click(button: Control) -> void:
 await settle(2)
 var point:=button.get_global_rect().get_center()
 var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true
 root.push_input(event,true);await process_frame
 var released: InputEventMouseButton=event.duplicate();released.pressed=false;root.push_input(released,true)
 await settle(3)

func run() -> void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():
  push_error("Required isolation flags: --test-session-ui --test-dialogue");quit(1);return
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
 AudioServer.set_bus_mute(0,true)
 var prefs=root.get_node("HarborPrefs")
 prefs.values.fullscreen=false;prefs.values.day_cycle=false;prefs.values.music=false;prefs.values.sfx=false
 prefs.starting_place="apt_2";prefs.continue_game=false
 prefs.settings_path=OUTPUT+"isolated_settings.cfg";prefs.world_save_path=OUTPUT+"isolated_world.json"
 root.size=Vector2i(1000,750)
 await icon_catalog()
 var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu
 await shot("01_标题菜单")
 check(menu.theme.get_stylebox("normal","Button") is StyleBoxFlat,"menu uses native button skin")
 check(menu.theme.get_stylebox("normal","Button").bg_color==preload("res://ui/candy_skin.gd").frame("button").bg_color,"menu consumes shared candy buttons")
 for key in ["map","backpack","tasks","chat","shop","music","deck","settings","mail","gift","calendar","shell"]:
  var texture=preload("res://ui/handheld_skin.gd").icon_texture(key)
  var source: Texture2D=load(preload("res://ui/handheld_skin.gd").icon_path(key))
  check(texture!=null and source!=null and texture.get_width()==source.get_width(),"shared function icon "+key)
  if texture:check(texture.get_image().has_mipmaps(),"mipmap icon "+key)
 await click(menu.menu_buttons.journey)
 check(menu.page=="journey","pointer opens departure menu")
 if menu.page!="journey":quit(1);return
 await click(menu.cards.apt_2)
 check(prefs.starting_place=="apt_2","pointer selects existing destination")
 await shot("02_出发选择")
 await click(menu.start_button)
 await settle(30)
 game=current_scene
 if game==null or game.get("dialogue_controller")==null:
  check(false,"menu launches world");quit(1);return
 check(game.location_id=="apt_2","start button launches selected game scene")
 game.atmosphere.set_time(12.0)
 await shot("03_探索HUD")
 game.loot.open_bag();await shot("04_背包")
 check(game.loot.modal.visible,"existing inventory opens")
 game.loot.close()
 game._settings(true);await shot("05_设置")
 check(game.settings_panel.visible,"existing settings opens")
 var view=game.settings_view
 check(not view.tab_buttons.display.get_global_rect().intersection(view.display_cards[0].get_global_rect()).has_area(),"settings tabs do not overlap first card")
 await click(view.tab_buttons.audio)
 check(view.settings_tab=="audio" and view.volume_slider.visible,"pointer switches audio tab")
 await shot("11_声音设置")
 await click(view.tab_buttons.display)
 check(view.settings_tab=="display","pointer returns to display tab")
 game._settings(false)
 var d=game.dialogue_controller
 d.state={"version":1,"seen":{},"flags":{},"bookmark":{},"history":[]}
 d.context={"room":str(game.title.text),"place":game.location_id,"object":"这里"};d.start("welcome")
 await click(d.box)
 check(not d.is_typing(),"pointer reveals dialogue")
 await shot("06_对话框")
 d.advance();d.advance()
 check(d.current_node=="ask" and d.choice_panel.visible and d.choice_buttons.size()==3,"existing dialogue choices appear")
 await shot("07_回复选项")
 if d.choice_buttons.is_empty():quit(1);return
 var expected: String=str(d.current.choices[0].next)
 await click(d.choice_buttons[0])
 check(d.current_node==expected,"pointer chooses existing dialogue branch")
 await click(d.auto_button)
 check(d.auto_play,"pointer toggles automatic dialogue")
 await click(d.auto_button)
 check(not d.auto_play,"automatic dialogue can be turned off")
 d.advance();d.show_backlog();await shot("08_对话回看");d.hide_backlog()
 root.size=Vector2i(1280,720);await settle(16)
 check(d.box.get_global_rect().end.x<=d.root.size.x+1.0,"dialogue panel fits widescreen")
 check(d.auto_button.get_global_rect().end.x<=d.box.get_global_rect().end.x,"dialogue controls stay inside panel")
 await shot("09_宽屏对话")
 var end_button: Button=null
 for button in d.root.find_children("*","Button",true,false):
  if button.text=="结束对话":end_button=button;break
 check(end_button!=null,"dialogue close button remains")
 if end_button:await click(end_button)
 check(not d.active and not game.dialog_open and game.ui.visible,"pointer close restores game control")
 root.size=Vector2i(1000,750);await settle(12)
 game.pause_menu.open();await shot("10_暂停菜单")
 check(game.pause_menu.active,"pause menu uses shared skin")
 game.pause_menu.close()
 print("DOWNLOADED_GLOBAL_UI_REVIEW: ",checks," checks, ",failures," failures")
 game.queue_free();await settle(5)
 quit(0 if failures==0 else 1)

func icon_catalog() -> void:
 var Skin=preload("res://ui/handheld_skin.gd")
 var Icons=preload("res://ui/downloaded_icons.gd")
 var catalog:=Control.new();catalog.size=Vector2(1448,1086);catalog.theme=Skin.theme(load("res://assets/NotoSansSC.ttf"));root.add_child(catalog)
 var background:=ColorRect.new();background.color=Color("aab2de");background.size=catalog.size;catalog.add_child(background)
 var heading:=Label.new();heading.text="下载图标 · 用途标记与实际尺寸";heading.position=Vector2(28,20);heading.add_theme_font_size_override("font_size",32);catalog.add_child(heading)
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/downloaded_20261011/manifest.json"))
 for i in data.assets.size():
  var entry: Dictionary=data.assets[i];var key: String=str(entry.key)
  var texture: Texture2D=Skin.icon_texture(key)
  check(Skin.icon_path(key)==Icons.path_for(key),"downloaded source "+key)
  check(texture!=null and texture.get_width()==1254 and texture.get_height()==1254,"original dimensions "+key)
  if texture==null:continue
  var img:=texture.get_image()
  check(img.has_mipmaps(),"mipmaps "+key)
  check(img.get_pixel(0,0).a==0 and img.get_pixel(1253,1253).a==0 and img.detect_alpha()!=Image.ALPHA_NONE,"transparent alpha "+key)
  var pos:=Vector2(25+(i%5)*282,96+(i/5)*304)
  var tile:=Skin.panel(catalog,pos,Vector2(270,286),"paper")
  var label:=Label.new();label.text=str(entry.label)+"  /  "+key;label.position=Vector2(12,10);label.add_theme_font_size_override("font_size",20);tile.add_child(label)
  var id:=Label.new();id.text=str(entry.source_file).left(8);id.position=Vector2(12,42);id.add_theme_font_size_override("font_size",16);tile.add_child(id)
  for row in 2:
   var well:=ColorRect.new();well.color=Color("eaf1ff") if row==0 else Color("414a7b");well.position=Vector2(10,77+row*90);well.size=Vector2(250,82);well.mouse_filter=Control.MOUSE_FILTER_IGNORE;tile.add_child(well)
   for column in 3:
    var side: int=[32,48,64][column]
    var picture:=TextureRect.new();picture.texture=texture;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.position=Vector2(9+column*80+(64-side)/2.0,(82-side)/2.0);picture.size=Vector2(side,side);well.add_child(picture)
  var sizes:=Label.new();sizes.text="32 px        48 px        64 px";sizes.position=Vector2(21,258);sizes.add_theme_font_size_override("font_size",14);tile.add_child(sizes)
 check(Icons.path_for("block_counter")==Icons.path_for("shield"),"shield maps to block counter")
 check(Icons.path_for("multihit")==Icons.path_for("mana"),"water drop maps to tide link")
 await shot("00_图标用途与尺寸")
 catalog.queue_free();await settle()
