@tool
extends Node2D
## Reusable placeable module. Position is its floor contact / bottom-center pivot.
@export var module_id := "bed_navy"
static var catalog: Dictionary = {}
var metadata: Dictionary
var visual: Sprite2D

static func get_catalog() -> Dictionary:
 if catalog.is_empty():
  var source: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog.json"))
  for entry in source: catalog[entry.id] = entry
 return catalog

func _ready() -> void:
 metadata = get_catalog().get(module_id,{})
 if metadata.is_empty(): return
 if metadata.solid:
  var shadow := Polygon2D.new()
  var points := PackedVector2Array()
  for i in 24: points.append(Vector2(cos(TAU*i/24)*float(metadata.footprint[0])*0.57,sin(TAU*i/24)*10-6))
  shadow.polygon=points
  shadow.color=Color(0.035,0.045,0.05,0.18)
  add_child(shadow)
 visual = Sprite2D.new()
 visual.texture = load(metadata.texture)
 visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 visual.position = Vector2(0,-float(metadata.size[1])/2)
 add_child(visual)
 if metadata.solid:
  var body := StaticBody2D.new()
  var collision := CollisionShape2D.new()
  var rectangle := RectangleShape2D.new()
  rectangle.size = Vector2(metadata.footprint[0],metadata.footprint[1])
  collision.shape = rectangle
  collision.position.y = -rectangle.size.y/2+2
  body.add_child(collision)
  add_child(body)
 if metadata.layer == "wall": z_index = -3

func bounds() -> Rect2:
 var foot: Array = metadata.footprint
 return Rect2(position-Vector2(foot[0]/2.0,foot[1]-2),Vector2(foot[0],foot[1]))
