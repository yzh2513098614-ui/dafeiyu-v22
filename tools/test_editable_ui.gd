extends SceneTree
const Document=preload("res://ui/design/layout_document.gd")
var checks:=0
var failures:=0
var page_original:=""
const PAGE="res://ui/design/pages/title_title.tscn"
func _initialize()->void:
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true);DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true);DisplayServer.window_set_position(Vector2i(-9999,-9999))
 call_deferred("run")
func check(ok:bool,note:String)->void:
 checks+=1
 if ok:print("PASS ",note)
 else:failures+=1;push_error(note)
func settle(count:int=8)->void:
 for i in count:await process_frame
func shot(name:String)->void:
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://预览/可编辑UI_20261011/"+name+".png"))
func restore()->void:
 if page_original!="":
  var file:=FileAccess.open(PAGE,FileAccess.WRITE);file.store_string(page_original);file.close();page_original=""
func run()->void:
 if not "--test-session-ui" in OS.get_cmdline_user_args() or not "--test-dialogue" in OS.get_cmdline_user_args():quit(1);return
 var bridge=root.get_node("UiDesign");bridge.enabled=false
 root.get_node("HarborPrefs").values.fullscreen=false;AudioServer.set_bus_mute(0,true);root.size=Vector2i(1000,750)
 var catalog:Array=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
 check(catalog.size()==44,"44 editable pages")
 var total:=0
 for entry in catalog:
  var page:Control=load(entry.scene).instantiate()
  var nodes:Dictionary={};Document.collect(page,nodes);total+=nodes.size()
  check(nodes.size()==int(entry.controls),"native editable controls "+str(entry.id))
  check(Document.changes(entry.id).is_empty(),"unchanged design keeps live logic "+str(entry.id))
  page.free()
 check(total>2000,"complete native control coverage")
 var menu=load("res://ui/start_menu.tscn").instantiate();root.add_child(menu);current_scene=menu;await settle()
 await shot("01_修改前_真实菜单")
 var button:Button=menu.menu_buttons.journey
 var index_id:=""
 var control:Node=button
 while control!=menu:
  index_id=str(control.get_index())+("/"+index_id if index_id!="" else "");control=control.get_parent()
 var before_rect:=button.get_rect();var old_text:=button.text
 page_original=FileAccess.get_file_as_string(PAGE)
 var designed:Control=load(PAGE).instantiate()
 var nodes:Dictionary={};Document.collect(designed,nodes)
 check(nodes.has(index_id),"editable control maps to real departure button")
 var editable:Button=nodes[index_id]
 editable.offset_top+=18;editable.offset_bottom+=18
 editable.icon=load("res://assets/ui/downloaded_20261011/gift.png")
 editable.add_theme_color_override("font_color",Color("064f4a"))
 var style:StyleBoxFlat=editable.get_theme_stylebox("normal").duplicate();style.bg_color=Color("4ad9c5");editable.add_theme_stylebox_override("normal",style)
 var packed:=PackedScene.new();packed.pack(designed);ResourceSaver.save(packed,PAGE);designed.free()
 var patch:=Document.changes("title_title")
 check(patch.size()==1,"only edited button produces a visual delta")
 check(bridge.apply_now("title_title",menu)==1,"saved native design reaches real menu")
 check(is_equal_approx(button.position.y,before_rect.position.y+18),"editor layout movement applies")
 check(button.icon.resource_path.ends_with("gift.png"),"editor icon replacement applies")
 check(button.get_theme_stylebox("normal").bg_color==Color("4ad9c5"),"editor button styling applies")
 check(button.text==old_text and not button.disabled,"live text and enabled state retained")
 bridge.enabled=true;bridge.reload_designs();menu._render();await settle()
 button=menu.menu_buttons.journey
 check(is_equal_approx(button.position.y,before_rect.position.y+18),"automatic runtime bridge survives controller redraw")
 check(button.icon.resource_path.ends_with("gift.png"),"automatic runtime bridge applies edited icon")
 await shot("02_修改后_真实菜单")
 var point:=button.get_global_rect().get_center()
 var press:=InputEventMouseButton.new();press.position=point;press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;root.push_input(press,true);await process_frame
 var release:=press.duplicate();release.pressed=false;root.push_input(release,true);await settle()
 check(menu.page=="journey","moved button still opens the original departure page")
 restore();bridge.reload_designs()
 check(Document.changes("title_title").is_empty(),"test restores original editable scene")
 menu.queue_free();await settle()
 print("EDITABLE_UI_TEST: ",checks," checks, ",failures," failures; ",total," controls")
 quit(0 if failures==0 else 1)
