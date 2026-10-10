extends SceneTree
## Separate whole original-resolution characters. No resize, quantization or recolor.
func _initialize() -> void:
 var source:=Image.load_from_file("res://assets/dialogue/portraits_original.png")
 if source==null:quit(1);return
 source.convert(Image.FORMAT_RGBA8)
 var w:=source.get_width();var h:=source.get_height();var bytes:=source.get_data()
 var visited:=PackedByteArray();visited.resize(w*h)
 var components: Array=[]
 for seed in w*h:
  if visited[seed]!=0 or bytes[seed*4+3]<128:continue
  var pixels:=PackedInt32Array();var queue: Array[int]=[seed];visited[seed]=1
  var low:=Vector2i(seed%w,seed/w);var high:=low
  while not queue.is_empty():
   var point: int=queue.pop_back();pixels.append(point)
   var x: int=point%w;var y: int=point/w
   low=Vector2i(mini(low.x,x),mini(low.y,y));high=Vector2i(maxi(high.x,x),maxi(high.y,y))
   for offset in [-1,1,-w,w]:
    var index: int=point+offset
    if index<0 or index>=w*h or (offset==-1 and x==0) or (offset==1 and x==w-1):continue
    if visited[index]==0 and bytes[index*4+3]>=128:visited[index]=1;queue.append(index)
  if pixels.size()>10000:components.append({"pixels":pixels,"bounds":Rect2i(low,high-low+Vector2i.ONE)})
 if components.size()!=3:push_error("Original sheet has "+str(components.size())+" large connected portraits; expected3");quit(1);return
 components.sort_custom(func(a,b):return a.bounds.position.x<b.bounds.position.x)
 # Use opaque body components only to locate the three actors, then assign EVERY
 # original nonzero-alpha pixel, including fringes, without changing RGBA values.
 var owners:=PackedByteArray();owners.resize(w*h)
 var frontier:=PackedInt32Array()
 for i in 3:
  for point in components[i].pixels:owners[point]=i+1;frontier.append(point)
 var cursor:=0
 while cursor<frontier.size():
  var point: int=frontier[cursor];cursor+=1;var x: int=point%w
  for offset in [-1,1,-w,w]:
   var index: int=point+offset
   if index<0 or index>=w*h or (offset==-1 and x==0) or (offset==1 and x==w-1):continue
   if owners[index]==0 and bytes[index*4+3]!=0:owners[index]=owners[point];frontier.append(index)
 var complete: Array=[]
 for i in 3:complete.append({"pixels":PackedInt32Array(),"low":Vector2i(w,h),"high":Vector2i.ZERO})
 for point in w*h:
  if bytes[point*4+3]==0:continue
  var owner: int=int(owners[point])-1
  if owner<0:owner=clampi(int((point%w)*3.0/w),0,2)
  var c: Dictionary=complete[owner];c.pixels.append(point)
  var x: int=point%w;var y: int=point/w
  c.low=Vector2i(mini(c.low.x,x),mini(c.low.y,y));c.high=Vector2i(maxi(c.high.x,x),maxi(c.high.y,y))
 components=complete
 for c in components:c.bounds=Rect2i(c.low,c.high-c.low+Vector2i.ONE)
 var frame_width:=0
 for c in components:frame_width=maxi(frame_width,c.bounds.size.x+32)
 frame_width=ceili(frame_width/4.0)*4
 var frame_height: int=h+32
 var keys: Array=["listen","talk","think"]
 var metadata: Dictionary={"method":"original_resolution_rgba","source":"res://assets/dialogue/portraits_original.png","source_size":[w,h],"frame_size":[frame_width,frame_height],"downsampled":false,"resized":false,"textures":{},"extraction":[]}
 for i in 3:
  var c: Dictionary=components[i];var r: Rect2i=c.bounds
  var data:=PackedByteArray();data.resize(frame_width*frame_height*4)
  var start:=Vector2i((frame_width-r.size.x)/2,frame_height-16-r.size.y)
  for point in c.pixels:
   var x: int=int(point)%w-r.position.x+start.x;var y: int=int(point)/w-r.position.y+start.y
   var target: int=(y*frame_width+x)*4;var original: int=int(point)*4
   for channel in 4:data[target+channel]=bytes[original+channel]
  var im:=Image.create_from_data(frame_width,frame_height,false,Image.FORMAT_RGBA8,data)
  var path: String="res://assets/dialogue/"+str(keys[i])+"_original.png"
  im.save_png(path);metadata.textures[keys[i]]=path
  metadata.extraction.append({"expression":keys[i],"source_bounds":[r.position.x,r.position.y,r.size.x,r.size.y],"dest_position":[start.x,start.y],"pixels_copied":c.pixels.size(),"pixel_scale":1.0})
 var f:=FileAccess.open("res://assets/dialogue/portraits.json",FileAccess.WRITE);f.store_string(JSON.stringify(metadata," "))
 print("ORIGINAL RESOLUTION PRESERVED ",w,"x",h," frames ",frame_width,"x",frame_height);quit()
