extends SceneTree
## Technical extraction of generated atlas regions. Preserves RGBA; no repainting.
func _init() -> void:
 var data: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/catalog.json"))
 for m in data:
  if m.category == "floor": continue
  var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sources/"+m.source))
  var b: Array = m.source_bounds
  var crop := image.get_region(Rect2i(b[0],b[1],b[2],b[3]))
  var size: Array = m.size
  crop.resize(size[0],size[1],Image.INTERPOLATE_NEAREST)
  var padded := Image.create(size[0]+8,size[1]+8,false,Image.FORMAT_RGBA8)
  padded.blit_rect(crop,Rect2i(0,0,size[0],size[1]),Vector2i(4,4))
  padded.save_png("res://assets/modules/"+m.id+".png")
 print("EXTRACTED ",data.size()," catalog entries")
 _floors()
 quit()

func _floors() -> void:
 var colors := [Color("b48b61"),Color("d5be97"),Color("705541"),Color("a08366"),Color("e0dacf"),Color("596571"),Color("b1ada7"),Color("d9dad6"),Color("c9bbb0"),Color("34475f"),Color("a1a58b"),Color("727c82")]
 var names := ["oak","pale_oak","walnut","herringbone","ivory_tile","slate_tile","concrete","marble","terrazzo","navy_carpet","tatami","metal_grid"]
 for kind in 12:
  var im := Image.create(64,64,false,Image.FORMAT_RGBA8)
  for y in 64:
   for x in 64:
    # Coordinates repeat at both edges. Guaranteed identical boundary samples.
    var px := x%63
    var py := y%63
    var variation := 0.004*sin(TAU*px/63.0*7+sin(TAU*py/63.0)*2)+0.004*cos(TAU*py/63.0*11)
    var c: Color = colors[kind]
    c = c.lightened(maxf(variation,0)).darkened(maxf(-variation,0))
    if kind < 3:
     if py%21==0 or (px==((py/21)*21)%63 and py%21>0): c=c.darkened(0.20)
     elif py%21==1: c=c.lightened(0.10)
    elif kind==3:
     var a := (px+py)%21
     var b := (px-py+63)%21
     if a==0 or (b==0 and ((px+py)/21)%2==0): c=c.darkened(0.17)
    elif kind in [4,5]:
     if px%21==0 or py%21==0: c=c.darkened(0.22)
     elif px%21==1 or py%21==1: c=c.lightened(0.08)
    elif kind==7:
     if absf(sin(TAU*px/63.0+0.8*sin(TAU*py/63.0*2)))<0.10: c=c.darkened(0.10)
    elif kind==8:
     if (px*11+py*19)%41<3: c=c.darkened(0.16)
    elif kind==9:
     c=c.lightened(0.025 if (px+py)%3==0 else 0)
    elif kind==10:
     if py%3==0: c=c.darkened(0.07)
     if px%21==0 or py%21==0: c=c.darkened(0.19)
    elif kind==11:
     if px%7==0 or py%7==0:c=c.darkened(0.12)
    im.set_pixel(x,y,c)
  im.save_png("res://assets/floors/"+names[kind]+".png")
 print("BUILT 12 seamless 64px floors")
