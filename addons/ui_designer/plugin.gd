@tool
extends EditorPlugin
var dock:VBoxContainer
var pages:ItemList
var filter:LineEdit
var entries:Array=[]
var displayed:Array=[]

func _enter_tree()->void:
 dock=VBoxContainer.new();dock.name="UI 设计";dock.custom_minimum_size.x=260
 var title:=Label.new();title.text="大肥鱼 · UI 设计";dock.add_child(title)
 var help:=Label.new();help.text="双击界面 → 2D 拖动控件\n检查器改图标、字体、Theme Overrides\nCtrl+S 保存 → F5 在游戏中生效";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.custom_minimum_size.y=72;dock.add_child(help)
 filter=LineEdit.new();filter.placeholder_text="搜索界面";filter.text_changed.connect(func(_text:String):_refresh());dock.add_child(filter)
 pages=ItemList.new();pages.size_flags_vertical=Control.SIZE_EXPAND_FILL;pages.custom_minimum_size.y=300;pages.item_activated.connect(_open_page);dock.add_child(pages)
 _button("打开选中界面",func():if not pages.get_selected_items().is_empty():_open_page(pages.get_selected_items()[0]))
 _button("全局按钮皮肤与图标",func():get_editor_interface().edit_resource(load("res://ui/design/game_ui_theme.tres")))
 _button("使用说明",func():get_editor_interface().get_file_system_dock().navigate_to_path("res://docs/Godot可视化UI编辑.md"))
 _button("刷新界面列表",_refresh)
 add_control_to_dock(DOCK_SLOT_RIGHT_UL,dock)
 _refresh()

func _button(text:String,action:Callable)->void:
 var button:=Button.new();button.text=text;button.pressed.connect(action);dock.add_child(button)

func _refresh()->void:
 entries=[]
 if FileAccess.file_exists("res://ui/design/catalog.json"):
  entries=JSON.parse_string(FileAccess.get_file_as_string("res://ui/design/catalog.json"))
 pages.clear();displayed.clear()
 for entry in entries:
  if filter.text!="" and not (str(entry.title)+str(entry.id)).contains(filter.text):continue
  displayed.append(entry);pages.add_item(str(entry.title))

func _open_page(index:int)->void:
 if index<0 or index>=displayed.size():return
 get_editor_interface().open_scene_from_path(str(displayed[index].scene))
 get_editor_interface().set_main_screen_editor("2D")

func _exit_tree()->void:
 if is_instance_valid(dock):remove_control_from_docks(dock);dock.queue_free()
