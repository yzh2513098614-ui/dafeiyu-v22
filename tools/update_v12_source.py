"""One-time source migration for the expanded guide; no runtime patching."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
path=root/'district/neighborhood.gd'
text=path.read_text(encoding='utf-8')
start=text.index('func _render_map() -> void:')
end=text.index('\nfunc _remember_room()',start)
text=text[:start]+'''func _render_map() -> void:
 for child in map_panel.get_children():child.free()
 var view:=GuideView.new();map_panel.add_child(view);view.configure(self)
'''+text[end:]
path.write_text(text,encoding='utf-8',newline='\n')
