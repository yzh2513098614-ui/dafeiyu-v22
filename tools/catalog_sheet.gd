extends Node2D
var font: Font=preload("res://assets/NotoSansSC.ttf")
var data: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog.json"))
var textures: Array[Texture2D]=[]
func _ready() -> void:
 for entry in data:textures.append(load(entry.texture))
 queue_redraw()
func _draw() -> void:
 draw_rect(Rect2(0,0,1600,3260),Color("142234"))
 draw_string(font,Vector2(30,42),"大肥鱼 · 124个可复用房间部件",HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color.WHITE)
 draw_string(font,Vector2(30,72),"24结构 + 24家具 + 16门窗 + 32装饰 + 16厨房 + 12无缝地板",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("9eb9ce"))
 for i in data.size():
  var x := (i%8)*200
  var y := 94+(i/8)*197
  draw_style_box(_box(),Rect2(x+7,y+6,186,184))
  var texture: Texture2D=textures[i]
  var original := texture.get_size()
  var scale_factor := minf(160.0/original.x,137.0/original.y)
  var size := original*scale_factor
  draw_texture_rect(texture,Rect2(Vector2(x+100,y+78)-size/2,size),false)
  draw_string(font,Vector2(x+14,y+170),str(i+1)+" "+str(data[i].name),HORIZONTAL_ALIGNMENT_LEFT,175,18,Color("dbe7ef"))
func _box() -> StyleBoxFlat:
 var b:=StyleBoxFlat.new();b.bg_color=Color("22344b");b.set_corner_radius_all(6);return b
