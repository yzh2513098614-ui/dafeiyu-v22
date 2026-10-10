"""Original parametric 3D authoring source. Python + NumPy + SciPy; outputs self-contained glTF 2.0 GLB."""
from pathlib import Path
import numpy as np
from scipy.spatial import ConvexHull
import struct,json,math,csv
ROOT=Path(__file__).resolve().parents[1]
P={
'ivory':('eeeae0',0,.52),'white':('dbe4e9',0,.48),'blue':('6586a6',.2,.43),'navy':('304d73',.1,.57),
'metal':('718393',.72,.3),'dark':('283444',.5,.38),'silver':('afbbc4',.75,.26),'glass':('acddea',0,.12),
'cyan':('56d5dd',.05,.35),'warm':('ffcf7c',.1,.4),'green':('589c72',0,.7),'leaf':('8aba79',0,.7),
'soil':('655549',0,.86),'wood':('b5a18a',0,.72),'pink':('d69dac',0,.64),'paper':('f3efe6',0,.8),
'water':('78b6cf',.1,.16),'red':('b36e78',0,.55)}
MATERIALS=[]
for k,(h,m,r) in P.items():
 c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
 d={'name':k,'pbrMetallicRoughness':{'baseColorFactor':c+[.27 if k=='glass' else 1],'metallicFactor':m,'roughnessFactor':r}}
 if k=='glass':d.update(alphaMode='BLEND',doubleSided=True)
 if k in ['cyan','warm']:d['emissiveFactor']=[v*.65 for v in c]
 MATERIALS.append(d)
CACHE={}
def geometry(kind,args):
 key=(kind,tuple(round(float(a),6) for a in args))
 if key in CACHE:return CACHE[key]
 if kind=='box':
  x,y,z,b=args;h=np.array([x,y,z])/2;b=min(b,min(h)*.45)
  v=[]
  for sx in [-1,1]:
   for sy in [-1,1]:
    for sz in [-1,1]:
     sg=np.array([sx,sy,sz]);base=(h-b)*sg
     for axis in range(3):q=base.copy();q[axis]=h[axis]*sg[axis];v.append(q)
  v=np.array(v);f=ConvexHull(v).simplices.copy()
  for i,t in enumerate(f):
   a,bb,c=v[t];n=np.cross(bb-a,c-a)
   if np.dot(n,(a+bb+c)/3)<0:f[i]=t[::-1]
 elif kind in ['cylinder','cone']:
  r,height,r2,segments=args;segments=int(segments);v=[]
  for y,rad in [(-height/2,r),(height/2,r2)]:
   for i in range(segments):a=2*math.pi*i/segments;v.append([rad*math.cos(a),y,rad*math.sin(a)])
  v.extend([[0,-height/2,0],[0,height/2,0]]);f=[]
  for i in range(segments):
   j=(i+1)%segments;f.extend([[i,segments+i,segments+j],[i,segments+j,j],[2*segments,i,j],[2*segments+1,segments+j,segments+i]])
  v=np.array(v);f=np.array(f)
 elif kind=='sphere':
  rx,ry,rz,segments,rings=args;segments=int(segments);rings=int(rings);v=[]
  for j in range(rings+1):
   b=math.pi*j/rings
   for i in range(segments):a=2*math.pi*i/segments;v.append([rx*math.sin(b)*math.cos(a),ry*math.cos(b),rz*math.sin(b)*math.sin(a)])
  f=[]
  for j in range(rings):
   for i in range(segments):a=j*segments+i;b=j*segments+(i+1)%segments;c=a+segments;d=b+segments;f.extend([[a,b,c],[b,d,c]])
  v=np.array(v);f=np.array(f)
 elif kind=='torus':
  major,minor,segments,rings=args;segments=int(segments);rings=int(rings);v=[]
  for i in range(segments):
   a=2*math.pi*i/segments
   for j in range(rings):b=2*math.pi*j/rings;v.append([(major+minor*math.cos(b))*math.cos(a),minor*math.sin(b),(major+minor*math.cos(b))*math.sin(a)])
  f=[]
  for i in range(segments):
   for j in range(rings):a=i*rings+j;b=((i+1)%segments)*rings+j;c=i*rings+(j+1)%rings;d=((i+1)%segments)*rings+(j+1)%rings;f.extend([[a,c,b],[c,d,b]])
  v=np.array(v);f=np.array(f)
 pos=v[f].reshape(-1,3).astype('<f4');normal=np.cross(pos[1::3]-pos[::3],pos[2::3]-pos[::3]);lens=np.linalg.norm(normal,axis=1);normal/=np.maximum(lens[:,None],1e-9)
 if kind=='sphere':normal=pos/np.array(args[:3])**2;normal/=np.maximum(np.linalg.norm(normal,axis=1)[:,None],1e-9)
 else:normal=np.repeat(normal,3,axis=0)
 result=(pos,normal.astype('<f4'));CACHE[key]=result;return result
class Model:
 def __init__(self,id,name,category,size):
  self.id=id;self.name=name;self.category=category;self.size=list(size);self.nodes=[{'name':id,'children':[]}];self.parts=[];self.moving=[];self.hinges=[]
 def group(self,name,pos=(0,0,0),parent=0):
  n=len(self.nodes);self.nodes.append({'name':name,'translation':list(pos),'children':[]});self.nodes[parent]['children'].append(n);return n
 def add(self,name,kind,args,pos,mat='ivory',parent=0,rot=None):
  n=len(self.nodes);node={'name':name,'translation':list(pos),'_geom':(kind,args,mat)}
  if rot:
   ax=np.array(rot[:3],float);ax/=np.linalg.norm(ax);ang=rot[3]/2;node['rotation']=(ax*math.sin(ang)).tolist()+[math.cos(ang)]
  self.nodes.append(node);self.nodes[parent]['children'].append(n);self.parts.append(n);return n
 def box(self,name,size,pos,mat='ivory',parent=0,bevel=.018,rot=None):return self.add(name,'box',list(size)+[bevel],pos,mat,parent,rot)
 def cyl(self,name,r,h,pos,mat='metal',parent=0,rot=None,r2=None):return self.add(name,'cylinder',[r,h,r if r2 is None else r2,20],pos,mat,parent,rot)
 def sphere(self,name,r,pos,mat='ivory',parent=0):return self.add(name,'sphere',r,pos,mat,parent)
 def orb(self,name,r,pos,mat='ivory',parent=0):return self.sphere(name,list(r)+[16,10],pos,mat,parent)
 def torus(self,name,r,minor,pos,mat='metal',parent=0,rot=None):return self.add(name,'torus',[r,minor,24,8],pos,mat,parent,rot)
 def legs(self,w,d,h=.25,y=None,mat='dark'):
  y=h/2 if y is None else y
  for x in [-w/2,w/2]:
   for z in [-d/2,d/2]:self.box('Leg',(.06,h,.06),(x,y,z),mat)
 def handle(self,x,y,z,w=.18,parent=0):
  self.box('Handle',(.028,.028,w),(x,y,z),'silver',parent,rot=(0,1,0,math.pi/2))
 def badge(self,x,y,z,parent=0):
  self.orb('WhaleBody',(.055,.026,.008),(x,y,z),'blue',parent);self.box('WhaleTail',(.04,.028,.008),(x+.06,y+.006,z),'blue',parent,rot=(0,0,1,.5))
 def door(self,w,h,x,y,z,parent=0,mat='ivory',name='DoorHinge',axis='y',angle=-105):
  side=-1 if angle>0 else 1
  node=self.group(name,(x-side*w/2,y,z),parent);self.box('DoorPanel',(w,h,.065),(side*w/2,0,0),mat,node)
  self.box('InsetPanel',(w*.81,h*.80,.02),(side*w/2,0,.043),'blue',node);self.handle(side*w*.82,0,.08,w*.19,node)
  self.moving.append({'node':name,'axis':axis,'angle':angle});self.hinges.append(node);return node
 def drawer(self,w,h,y,z,name='DrawerSlide',mat='ivory'):
  node=self.group(name,(0,y,z));self.box('DrawerFace',(w,h,.07),(0,0,0),mat,node);self.box('DrawerBase',(w*.87,.035,.45),(0,-h*.3,-.20),'dark',node);self.handle(0,0,.065,w*.2,node)
  self.moving.append({'node':name,'axis':'z','distance':.38});return node
 def export(self):
  data=bytearray();views=[];access=[];meshes=[];used={};nodes=[];tris=0
  def acc(arr,typ):
   raw=arr.tobytes();pad=(-len(data))%4;data.extend(b'\0'*pad);offset=len(data);data.extend(raw);vi=len(views);views.append({'buffer':0,'byteOffset':offset,'byteLength':len(raw)})
   a={'bufferView':vi,'componentType':5126,'count':len(arr),'type':typ}
   if typ=='VEC3':a.update(min=np.min(arr,axis=0).tolist(),max=np.max(arr,axis=0).tolist())
   access.append(a);return len(access)-1
  for source in self.nodes:
   node={k:v for k,v in source.items() if k!='_geom'}
   if '_geom' in source:
    kind,args,mat=source['_geom'];key=(kind,tuple(args),mat)
    if key not in used:
     pos,norm=geometry(kind,args);a=acc(pos,'VEC3');b=acc(norm,'VEC3');used[key]=len(meshes);meshes.append({'name':source['name'],'primitives':[{'attributes':{'POSITION':a,'NORMAL':b},'material':list(P).index(mat)}]})
    node['mesh']=used[key];tris+=len(geometry(kind,args)[0])//3
   nodes.append(node)
  animations=[]
  for label,end in [('open',1),('close',0)]:
   if not self.moving:break
   times=acc(np.array([0,.18,.75],dtype='<f4'),'SCALAR');samplers=[];channels=[]
   for move in self.moving:
    idx=next(i for i,n in enumerate(nodes) if n['name']==move['node']);base=nodes[idx].get('translation',[0,0,0])
    if 'distance' in move:
     va=[]
     for t in ([0,.10,1] if end else [1,.9,0]):q=list(base);q[{"x":0,"y":1,"z":2}[move["axis"]]]+=move['distance']*t;va.append(q)
     out=acc(np.array(va,dtype='<f4'),'VEC3');path='translation'
    else:
     va=[]
     for t in ([0,.1,1] if end else [1,.9,0]):
      axis=[1,0,0] if move['axis']=='x' else [0,1,0];a=math.radians(move['angle'])*t/2;va.append([v*math.sin(a) for v in axis]+[math.cos(a)])
     out=acc(np.array(va,dtype='<f4'),'VEC4');path='rotation'
    samplers.append({'input':times,'output':out,'interpolation':'LINEAR'});channels.append({'sampler':len(samplers)-1,'target':{'node':idx,'path':path}})
   animations.append({'name':label,'samplers':samplers,'channels':channels})
  doc={'asset':{'version':'2.0','generator':'Token whale interior parametric authoring'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':nodes,'meshes':meshes,'materials':MATERIALS,'buffers':[{'byteLength':len(data)}],'bufferViews':views,'accessors':access}
  if animations:doc['animations']=animations
  raw=json.dumps(doc,separators=(',',':')).encode();raw+=b' '*((-len(raw))%4);data+=b'\0'*((-len(data))%4)
  out=struct.pack('<4sII',b'glTF',2,12+8+len(raw)+8+len(data))+struct.pack('<I4s',len(raw),b'JSON')+raw+struct.pack('<I4s',len(data),b'BIN\0')+data
  (ROOT/'assets/models'/f'{self.id}.glb').write_bytes(out)
  return {'id':self.id,'name':self.name,'category':self.category,'size':self.size,'triangles':tris,'mesh_parts':len(self.parts),'moving':self.moving,'model':'res://interior_pack/assets/models/'+self.id+'.glb','scene':'res://interior_pack/scenes/items/'+self.id+'.tscn'}
def cabinet(m,w,h,d,mat='ivory',base=.08):
 m.box('Base',(w,.10,d),(0,.05,0),'dark');m.box('Back',(w-.14,h-base-.07,.065),(0,(h+base-.07)/2,-d/2+.033),mat)
 for x in [-w/2+.035,w/2-.035]:m.box('Side',(.07,h-base-.07,d),(x,(h+base-.07)/2,0),mat)
 m.box('Top',(w,.07,d),(0,h-.035,0),mat);m.box('Bottom',(w-.14,.065,d-.14),(0,base,0),mat)
 m.box('StatusLight',(w*.4,.012,.008),(0,h-.13,d/2+.012),'cyan')
def keypad(m,x,y,z,parent=0):
 m.box('KeypadPanel',(.16,.22,.015),(x,y,z),'dark',parent);m.box('TinyScreen',(.11,.045,.008),(x,y+.066,z+.015),'cyan',parent)
 for i in range(9):m.box('Key',(.024,.024,.009),(x+(i%3-1)*.033,y-.005-(i//3)*.04,z+.014),'silver',parent,bevel=.003)
def safe(m,i):
 w,h,d=m.size;cabinet(m,w,h,d,'white' if i%3 else 'navy')
 if i==11:
  node=m.group('LidHinge',(0,h,-d/2));m.box('Lid',(w,.08,d),(0,0,d/2),'blue',node);m.handle(0,.05,d*.75,w*.22,node);m.moving.append({'node':'LidHinge','axis':'x','angle':-105})
 elif i in [2,10]:m.drawer(w*.89,h*.64,h*.47,d/2,name='SecureDrawer',mat='blue');keypad(m,0,h*.65,d/2+.054)
 elif i==5:
  for side in range(2):
   node=m.door(w*.46,h*.78,(-1 if side==0 else 1)*w*.24,h*.52,d/2,name='VaultHinge'+str(side),angle=-105 if side==0 else 105)
   if side==0:keypad(m,w*.23,0,.058,node)
 else:
  node=m.door(w*.88,h*.8,0,h*.52,d/2,mat='ivory' if i%2 else 'blue');keypad(m,w*.58,h*.17,.06,node);m.badge(w*.22,-h*.20,.06,node)
  if i==4:
   for y in [-h*.2,0,h*.2]:m.box('Reinforcement',(w*.75,.036,.02),(w*.44,y,.071),'silver',node)
  if i==6:m.box('DepositSlot',(w*.42,.035,.017),(w*.40,h*.27,.071),'dark',node)
  if i==7:m.cyl('TokenSlot',.054,.012,(w*.44,h*.25,.08),'warm',node,rot=(1,0,0,math.pi/2));m.box('Slot',(.08,.012,.02),(w*.44,h*.25,.089),'dark',node)
 for y in [.18,h*.45]:
  if y<h-.1:m.box('InsideShelf',(w*.82,.04,d*.85),(0,y,0),'metal')
 if i in [3,9]:m.box('MountingFrame',(w*1.1,h*1.05,.10),(0,h*.52,-d/2),'metal')
 if i==8:
  m.box('MedicineCrossV',(.05,h*.24,.012),(.10,h*.78,d/2+.11),'cyan');m.box('MedicineCrossH',(.16,.04,.012),(.10,h*.78,d/2+.115),'cyan')
def storage(m,i):
 w,h,d=m.size
 if i in [0,6]:
  cabinet(m,w,h,d)
  for k in range(3):m.drawer(w*.90,(h-.14)/3*.88,.11+(k+.5)*(h-.14)/3,d/2,name='Drawer'+str(k))
  if i==6:
   for x in [-w*.36,w*.36]:
    for z in [-d*.32,d*.32]:m.cyl('Caster',.055,.035,(x,.06,z),'dark',rot=(0,0,1,math.pi/2))
 elif i==1:
  cabinet(m,w,h,d)
  for k in range(4):
   y=.22+k*(h-.25)/4;m.box('Shelf',(w*.92,.04,d*.94),(0,y,0),'blue')
   for j in range(5):m.box('Book',(.07,.20+.02*(j%3),d*.47),(-w*.36+j*w*.17,y+.13,-d*.1),['navy','blue','pink','wood','ivory'][j])
 elif i==2:
  m.legs(w*.86,d*.78,.30);m.box('BenchBody',(w,.28,d),(0,.41,0));m.box('Cushion',(w*.96,.12,d*.94),(0,.62,0),'blue')
  for j in range(4):m.box('SlattedShelf',(w*.90,.032,.055),(0,.17,-d*.3+j*d*.2),'dark')
 elif i==3:
  cabinet(m,w,h,d)
  for k in range(2):
   node=m.group('SlidingDoor'+str(k),((-1 if k==0 else 1)*w*.245,h*.51,d/2+(k*.04)));m.box('SlidingPanel',(w*.51,h*.85,.045),(0,0,0),'white' if k else 'blue',node);m.handle(w*.2,0,.04,.18,node);m.moving.append({'node':'SlidingDoor'+str(k),'axis':'x','distance':w*.40*(-1 if k==0 else 1)})
 elif i==4:
  cabinet(m,w,h,d)
  for col in range(2):
   for row in range(3):
    x=(col-.5)*w*.48;y=.10+(row+.5)*(h-.10)/3;node=m.door(w*.45,(h-.13)/3*.91,x,y,d/2,name='LockerHinge'+str(col)+str(row),mat='blue' if row==1 else 'ivory');m.box('NamePlate',(.08,.028,.006),(w*.12,.08,.05),'silver',node)
 elif i==5:
  m.box('CabinetLeft',(w*.63,h,d*.40),(-w*.18,h/2,-d*.28));m.box('CabinetRight',(w*.40,h,d*.76),(w*.30,h/2,d*.10));m.box('LTopLeft',(w*.65,.06,d*.43),(-w*.18,h,-d*.28),'blue');m.box('LTopRight',(w*.42,.06,d*.78),(w*.30,h,d*.10),'blue')
  for j in range(2):m.handle(-w*.18,.3+j*.25,-d*.045,w*.22)
 elif i==7:
  cabinet(m,w,h,d);m.box('GlassDoor',(w*.92,h*.84,.014),(0,h*.52,d/2),'glass')
  for k in range(3):m.box('GlassShelf',(w*.86,.018,d*.9),(0,.23+k*h*.23,0),'glass');m.cyl('DisplayStand',.09,.08,(-w*.22,.28+k*h*.23,0),'blue');m.orb('Exhibit',(.09,.08,.08),(w*.19,.33+k*h*.23,0),'warm')
 elif i==8:
  m.box('PegPanel',(w,h*.22,.06),(0,h*.86,-d*.35),'white');m.box('ShoeUnit',(w,h*.35,d),(0,h*.19,0));m.box('BenchPad',(w*.93,.07,d*.88),(0,h*.39,0),'blue')
  for k in range(4):x=(k-1.5)*w*.23;m.box('Hook',(.025,.08,.035),(x,h*.84,-d*.30),'silver');m.box('HookLip',(.025,.025,.09),(x,h*.80,-d*.27),'silver')
 elif i==9:
  cabinet(m,w,h,d);m.door(w*.9,h*.48,0,h*.32,d/2,name='LowerHinge');m.door(w*.9,h*.35,0,h*.78,d/2,name='UpperHinge')
 elif i==10:
  cabinet(m,w,h,d);m.door(w*.88,h*.79,0,h*.51,d/2);m.box('WallMount',(w*.80,.10,.08),(0,h*.75,-d/2-.04),'dark')
 else:
  for k in range(3):
   ww=w*(1-.1*k);hh=h/3*.82;y=.035+hh/2+k*h/3;m.box('StackCrate',(ww,hh,d),(0,y,0),'blue' if k==1 else 'white');m.box('Lid',(ww*1.03,.035,d*1.03),(0,y+hh/2,0),'dark');m.handle(0,y,d/2+.025,ww*.24);m.badge(-ww*.23,y,d/2+.021)
def sofa(m,w,d,seat_count=3):
 m.legs(w*.84,d*.78,.16);m.box('SofaBase',(w,.30,d),(0,.29,0),'navy');m.box('Backrest',(w,.59,.18),(0,.69,-d/2+.06),'blue')
 for x in [-w/2+.08,w/2-.08]:m.box('Armrest',(.18,.44,d*.96),(x,.56,0),'ivory')
 for j in range(seat_count):x=(j-(seat_count-1)/2)*(w-.4)/seat_count;m.box('SeatCushion',((w-.42)/seat_count,.16,d*.70),(x,.52,d*.08),'ivory',bevel=.045);m.box('BackCushion',((w-.42)/seat_count,.42,.12),(x,.78,-d*.28),'blue',bevel=.04)
def living(m,i):
 w,h,d=m.size
 if i==0:sofa(m,w,d)
 elif i==1:
  m.cyl('Pedestal',.29,.09,(0,.06,0),'dark');m.cyl('Stem',.075,.32,(0,.24,0),'silver');m.orb('Seat',(.38,.14,.33),(0,.48,0),'ivory');m.box('Back',(.75,.46,.12),(0,.72,-.28),'blue',bevel=.05)
  for x in [-.38,.38]:m.orb('SoftArm',(.09,.13,.29),(x,.56,.02),'blue')
 elif i==2:m.orb('BeanBag',(.48,.35,.44),(0,.36,0),'blue');m.orb('SeatDimple',(.32,.065,.29),(0,.56,.05),'ivory')
 elif i==3:m.box('OttomanBase',(w,.20,d),(0,.12,0),'dark');m.box('OttomanCushion',(w,.29,d),(0,.36,0),'blue',bevel=.07);m.box('Seam',(w*.91,.006,.008),(0,.39,d/2+.002),'ivory')
 elif i==4:
  m.legs(w*.92,d*.72,.68);m.box('ConsoleTop',(w,.065,d),(0,.74,0),'ivory');m.box('ConsoleShelf',(w*.88,.05,d*.84),(0,.18,0),'blue');m.box('DrawerFace',(w*.87,.18,.06),(0,.57,d/2-.02));m.handle(0,.58,d/2+.02,w*.15)
 elif i==5:
  cabinet(m,w,.46,d);m.drawer(w*.44,.22,.24,d/2,name='MediaDrawer');m.box('ScreenFrame',(w*.85,.78,.06),(0,1.07,-.04),'dark');m.box('Display',(w*.81,.72,.012),(0,1.07,.001),'navy');m.box('DisplayLine',(w*.61,.023,.014),(0,1.08,.013),'cyan');m.box('TVFoot',(.46,.04,.24),(0,.64,0),'dark');m.box('TVStand',(.06,.18,.045),(0,.67,-.04),'metal')
 elif i==6:
  for x in [-w*.39,w*.39]:m.box('DeskFoot',(.09,.035,d*.83),(x,.04,0),'dark');m.box('DeskLeg',(.085,h*.90,.10),(x,h*.45,-d*.08),'metal')
  m.box('Desktop',(w,.065,d),(0,h-.03,0),'ivory');m.box('ControlPad',(.16,.06,.015),(w*.25,h-.06,d/2+.01),'dark');m.box('Screen',(.13,.02,.017),(w*.25,h-.06,d/2+.025),'cyan')
 elif i==7:
  m.cyl('ChairPost',.05,.43,(0,.25,0),'silver')
  for k in range(5):
   a=k*2*math.pi/5;m.box('ChairSpoke',(.42,.035,.045),(.17*math.cos(a),.08,.17*math.sin(a)),'dark',rot=(0,1,0,-a));m.orb('Wheel',(.046,.052,.04),(.36*math.cos(a),.057,.36*math.sin(a)),'dark')
  m.box('ChairSeat',(.51,.13,.48),(0,.53,0),'blue',bevel=.04);m.box('ChairBack',(.49,.56,.11),(0,.89,-.21),'blue',bevel=.04)
  for x in [-.31,.31]:m.box('ArmSupport',(.035,.25,.04),(x,.63,0),'silver');m.box('ArmPad',(.09,.045,.34),(x,.76,.05),'dark')
 elif i==8:m.cyl('CoffeeBase',w*.25,.05,(0,.026,0),'dark');m.cyl('CoffeeStem',.07,h-.10,(0,h/2,0),'metal');m.cyl('CoffeeTop',w/2,.065,(0,h-.032,0),'ivory')
 elif i==9:
  m.legs(w*.72,d*.68,.33);m.orb('OvalTop',(w/2,.045,d/2),(0,.40,0),'ivory');m.box('LowerShelf',(w*.73,.035,d*.68),(0,.16,0),'blue')
 elif i==10:
  m.box('BedBase',(w,.28,d),(0,.22,0),'dark');m.box('Mattress',(w*.95,.22,d*.95),(0,.47,0),'ivory',bevel=.05);m.box('Headboard',(w,.76,.10),(0,.52,-d/2),'blue');m.box('Blanket',(w*.96,.11,d*.64),(0,.61,d*.17),'blue',bevel=.04)
  for x in [-w*.25,w*.25]:m.box('Pillow',(w*.40,.14,d*.18),(x,.64,-d*.30),'ivory',bevel=.05)
  m.box('BlanketSeam',(w*.9,.008,.025),(0,.67,-d*.14),'ivory')
 else:
  cabinet(m,w,h,d);m.drawer(w*.9,h*.31,h*.62,d/2,name='NightDrawer');m.box('OpenShelf',(w*.87,.04,d*.92),(0,h*.26,0),'blue')
def restaurant(m,i):
 w,h,d=m.size
 if i in [0,8,9]:
  cabinet(m,w,h,d,'white')
  if i==0:
   m.box('StovePlate',(w*.94,.04,d*.92),(0,h+.015,0),'dark')
   for x in [-w*.24,w*.24]:
    for z in [-d*.23,d*.23]:m.torus('Burner',.105,.014,(x,h+.05,z),'silver');m.cyl('BurnerCenter',.06,.015,(x,h+.04,z),'dark')
   m.box('OvenDoor',(w*.86,h*.54,.06),(0,h*.40,d/2),'blue');m.box('OvenWindow',(w*.63,h*.32,.01),(0,h*.40,d/2+.034),'glass');m.handle(0,h*.68,d/2+.075,w*.55)
   for x in [-w*.31,0,w*.31]:m.cyl('Knob',.03,.018,(x,h*.85,d/2+.03),'silver',rot=(1,0,0,math.pi/2))
  elif i==8:
   m.box('SinkRim',(w*.8,.045,d*.77),(0,h+.02,0),'silver');m.box('SinkInside',(w*.69,.026,d*.61),(0,h+.035,0),'dark');m.box('BasinWater',(w*.59,.015,d*.47),(0,h+.05,0),'water');m.box('TapPost',(.045,.30,.045),(w*.30,h+.19,-d*.32),'silver');m.box('TapNeck',(.045,.045,.21),(w*.30,h+.34,-d*.23),'silver');m.door(w*.9,h*.78,0,h*.49,d/2)
  else:
   m.door(w*.91,h*.81,0,h*.48,d/2,name='DishwasherHinge',angle=-85);m.box('DishwasherTop',(w*.9,.065,.016),(0,h*.93,d/2+.065),'dark');m.box('DigitalReadout',(.12,.032,.008),(w*.24,h*.93,d/2+.08),'cyan')
 elif i==1:
  m.box('EspressoBase',(w,.07,d),(0,.05,0),'dark');m.box('EspressoBody',(w,.38,d*.67),(0,.29,-d*.1),'ivory');m.box('ControlFront',(w*.83,.10,.024),(0,.40,d*.25),'dark');m.box('ControlGlow',(w*.31,.033,.01),(0,.41,d*.268),'cyan');m.box('DripTray',(w*.85,.026,d*.45),(0,.10,d*.29),'silver')
  for x in [-w*.24,w*.24]:m.cyl('GroupHead',.053,.11,(x,.30,d*.27),'silver');m.cyl('Cup',.043,.075,(x,.16,d*.27),'ivory',r2=.048);m.cyl('Coffee',.038,.008,(x,.20,d*.27),'soil')
  m.cyl('SteamWand',.012,.23,(w*.43,.22,d*.24),'silver');m.box('BeanHopper',(w*.40,.18,d*.44),(0,.57,-d*.13),'glass');m.box('Beans',(w*.34,.07,d*.37),(0,.51,-d*.13),'soil')
 elif i==2:
  m.legs(w*.84,d*.77,.12);m.box('OvenStack',(w,h-.13,d),(0,(h+.13)/2,0),'white')
  for k in range(2):y=h*(.3+.44*k);m.box('OvenFront',(w*.90,h*.34,.04),(0,y,d/2),'dark');m.box('OvenGlass',(w*.71,h*.23,.012),(0,y,d/2+.03),'glass');m.handle(0,y+h*.13,d/2+.065,w*.65)
 elif i==3:
  m.box('KioskBase',(w,.05,d),(0,.025,0),'dark');m.box('KioskPost',(.15,h*.65,.12),(0,h*.35,0),'silver');m.box('TabletBody',(w*.93,h*.40,.055),(0,h*.81,0),'white',rot=(1,0,0,-.15));m.box('TabletScreen',(w*.84,h*.33,.012),(0,h*.81,.036),'navy',rot=(1,0,0,-.15))
  for k in range(3):m.box('MenuTile',(w*.67,.045,.015),(0,h*.90-k*.09,.062),'cyan' if k==0 else 'blue');m.box('PayReader',(.16,.14,.07),(0,h*.48,.14),'dark');m.badge(0,h*.48,.18)
 elif i==4:
  cabinet(m,w,h,d);m.box('BarCounter',(w*1.08,.08,d*1.17),(0,h+.04,0),'ivory');m.box('FrontKicklight',(w*.88,.018,.012),(0,.13,d/2+.021),'cyan')
  for k in range(8):m.box('CounterSlat',(.045,h*.70,.018),((k-3.5)*w*.11,h*.51,d/2+.026),'blue')
 elif i==5:
  cabinet(m,w,h,d);m.door(w*.91,h*.54,0,h*.35,d/2,name='FridgeLower');m.door(w*.91,h*.30,0,h*.81,d/2,name='FridgeUpper');m.badge(-w*.24,h*.79,d/2+.08)
 elif i==6:
  cabinet(m,w,h*.37,d);m.box('CaseBack',(w,h*.57,.04),(0,h*.70,-d/2+.02),'white');m.box('CaseGlass',(w*.96,h*.54,.014),(0,h*.69,d/2),'glass');m.box('CaseTop',(w,.035,d),(0,h,0),'white')
  for k in range(2):
   yy=h*(.44+.27*k);m.box('DisplayShelf',(w*.92,.027,d*.91),(0,yy,0),'glass')
   for j in range(4):m.orb('Cake',(.09,.05,.075),((j-1.5)*w*.20,yy+.065,0),'warm' if j%2 else 'pink');m.cyl('Plate',.10,.012,((j-1.5)*w*.20,yy+.01,0),'ivory')
 elif i==7:
  m.legs(w*.70,d*.70,.72);m.box('DiningTop',(w,.06,d),(0,.76,0),'ivory');m.cyl('PlantPot',.07,.10,(0,.84,0),'blue');m.orb('Plant',(.10,.13,.10),(0,.97,0),'green')
 elif i==10:
  sofa(m,w,d,2);m.box('BoothHighBack',(w,.93,.16),(0,.90,-d/2),'navy');m.box('BoothRail',(w,.045,.17),(0,1.38,-d/2),'metal')
 else:
  m.box('MicrowaveBody',(w,h,d),(0,h/2,0),'white');m.box('FrontPlate',(w*.92,h*.87,.024),(0,h*.51,d/2),'dark');m.box('GlassDoor',(w*.68,h*.70,.012),(-w*.095,h*.51,d/2+.026),'glass');m.box('Screen',(.11,.052,.01),(w*.35,h*.72,d/2+.03),'cyan');keypad(m,w*.35,h*.40,d/2+.027)
def utility(m,i):
 w,h,d=m.size
 if i in [0,1]:
  m.box('Appliance',(w,h,d),(0,h/2,0),'white');levels=2 if i==1 else 1
  for k in range(levels):
   yy=h*(k+.43)/levels;r=w*.31;m.torus('DrumRim',r,.036,(0,yy,d/2+.02),'silver',rot=(1,0,0,math.pi/2));m.cyl('DrumGlass',r*.91,.018,(0,yy,d/2+.028),'glass',rot=(1,0,0,math.pi/2));m.cyl('DrumDark',r*.86,.02,(0,yy,d/2+.002),'dark',rot=(1,0,0,math.pi/2));m.box('Display',(.19,.05,.01),(w*.19,yy+r+.09,d/2+.02),'cyan')
 elif i==2:
  cabinet(m,w,h*.51,d);m.box('SinkTop',(w,.10,d),(0,h*.54,0),'ivory');m.orb('Basin',(.23,.014,.17),(0,h*.60,0),'water');m.box('MirrorFrame',(w*.94,h*.33,.04),(0,h*.82,-d*.40),'white');m.box('Mirror',(w*.84,h*.28,.014),(0,h*.82,-d*.37),'silver');m.box('Tap',(.04,.17,.05),(w*.23,h*.64,-d*.28),'metal')
 elif i==3:
  m.orb('ToiletBase',(.25,.22,.29),(0,.24,0),'ivory');m.orb('ToiletBowl',(.31,.10,.38),(0,.47,.08),'ivory');m.orb('SeatInset',(.22,.013,.27),(0,.562,.10),'dark');m.box('Tank',(.48,.47,.18),(0,.58,-.28),'ivory',bevel=.04);m.box('Flush',(.08,.012,.055),(0,.824,-.28),'silver')
 elif i==4:
  m.box('TubBody',(w,h,d),(0,h/2,0),'ivory',bevel=.08);m.box('TubInside',(w*.86,.014,d*.72),(0,h+.006,0),'dark',bevel=.04);m.box('Water',(w*.79,.015,d*.62),(0,h+.015,0),'water',bevel=.04);m.box('TapPost',(.055,.18,.06),(-w*.37,h+.08,-d*.35),'silver');m.box('TapMouth',(.14,.04,.06),(-w*.32,h+.18,-d*.35),'silver')
 elif i==5:
  m.cyl('PurifierBody',w*.49,h*.87,(0,h*.48,0),'white');m.cyl('TopGrille',w*.45,.035,(0,h*.94,0),'dark');m.cyl('TopCap',w*.23,.04,(0,h*.98,0),'white');m.box('PurifierLight',(.08,.04,.018),(0,h*.72,d/2),'cyan')
  for k in range(10):a=2*math.pi*k/10;m.box('Vent',(.012,h*.30,.016),(w*.49*math.cos(a),h*.30,w*.49*math.sin(a)),'dark',rot=(0,1,0,-a))
 elif i==6:
  m.box('WaterDispenser',(w,h*.87,d),(0,h*.44,0),'white');m.box('WaterRecess',(w*.75,h*.25,.018),(0,h*.63,d/2+.008),'dark');m.box('DripTray',(w*.74,.028,d*.27),(0,h*.49,d*.45),'silver')
  for x in [-w*.14,w*.14]:m.box('Tap',(.035,.06,.07),(x,h*.72,d/2+.045),'cyan' if x<0 else 'warm')
  m.cyl('Bottle',w*.36,h*.20,(0,h*.97,0),'glass')
 elif i==7:
  m.box('WallAC',(w,h,d),(0,h/2,0),'white',bevel=.045);m.box('VentPanel',(w*.91,h*.25,.015),(0,h*.24,d/2+.01),'dark')
  for k in range(5):m.box('Louvre',(w*.86,.012,.020),(0,h*.15+k*h*.04,d/2+.021),'silver')
  m.box('ACGlow',(.12,.021,.01),(w*.30,h*.63,d/2+.016),'cyan')
 elif i==8:
  cabinet(m,w,h,d,'dark');m.door(w*.88,h*.84,0,h*.51,d/2,mat='dark')
  for k in range(8):
   yy=.20+k*(h-.3)/8;m.box('ServerBlade',(w*.78,.11,d*.8),(0,yy,0),'metal');m.box('BladeFace',(w*.76,.085,.02),(0,yy,d/2-.04),'dark');m.box('BladeLight',(.027,.015,.025),(w*.27,yy,d/2-.024),'cyan')
 elif i==9:
  m.box('BinBody',(w,h*.82,d),(0,h*.42,0),'white');m.box('BinLid',(w*1.04,.08,d*1.04),(0,h*.87,0),'blue');m.box('Pedal',(w*.40,.04,.16),(0,.035,d/2+.04),'silver');m.badge(0,h*.55,d/2+.015)
 elif i==10:
  m.box('Dock',(w,.14,d*.40),(0,.075,-d*.30),'dark');m.cyl('RobotBody',w*.45,.13,(0,.09,d*.12),'white');m.cyl('Lidar',.065,.06,(0,.175,d*.12),'blue');m.box('BumperLight',(w*.43,.017,.013),(0,.11,d*.12+w*.43),'cyan')
 else:
  m.box('ChargingBody',(w,h,d),(0,h/2,0),'white');m.box('ChargingFront',(w*.83,h*.79,.025),(0,h*.51,d/2),'navy');keypad(m,0,h*.73,d/2+.04)
  for x in [-w*.23,w*.23]:m.box('Socket',(.10,.13,.025),(x,h*.40,d/2+.033),'dark');m.cyl('SocketHole',.028,.012,(x,h*.4,d/2+.052),'silver',rot=(1,0,0,math.pi/2))
def plant(m,x,y,z,scale=1):
 m.cyl('Pot',.13*scale,.22*scale,(x,y+.11*scale,z),'white',r2=.16*scale);m.cyl('Soil',.14*scale,.015,(x,y+.223*scale,z),'soil')
 for i in range(7):
  a=i*2*math.pi/7;yy=y+.25*scale;m.box('Stem',(.012,.31*scale,.012),(x,yy+.12*scale,z),'green');m.orb('Leaf',(.075*scale,.17*scale,.035*scale),(x+.11*scale*math.cos(a),yy+.23*scale+.02*(i%3),z+.11*scale*math.sin(a)),'leaf' if i%2 else 'green')
def decor(m,i):
 w,h,d=m.size
 if i==0:
  plant(m,0,0,0,2)
 elif i==1:
  m.box('Planter',(w,.32,d),(0,.17,0),'white')
  for j in range(3):plant(m,(j-1)*w*.27,.20,0,.75)
  m.box('PlanterStripe',(w*.90,.015,.009),(0,.20,d/2+.013),'cyan')
 elif i==2:
  m.cyl('FloorLightBase',.23,.035,(0,.021,0),'dark');m.cyl('FloorLightStem',.024,h*.76,(0,h*.40,0),'silver');m.orb('FrostedGlobe',(.21,.21,.21),(0,h-.22,0),'warm')
 elif i==3:
  m.cyl('DeskLightBase',.16,.04,(0,.025,0),'dark');m.cyl('DeskLightStem',.02,.29,(0,.20,0),'silver');m.add('LampShade','cone',[.19,.17,.10,24],(0,.42,0),'ivory');m.orb('Bulb',(.067,.06,.067),(0,.35,0),'warm')
 elif i==4:
  m.box('WallSconce',(w,h,.07),(0,h/2,0),'metal');m.box('WarmDiffuser',(w*.64,h*.82,.044),(0,h/2,.058),'warm');m.box('SconceCap',(w*1.03,.04,.12),(0,h-.02,.035),'dark')
 elif i==5:
  m.box('PictureFrame',(w,h,.06),(0,h/2,0),'metal');m.box('PicturePaper',(w*.89,h*.88,.017),(0,h/2,.042),'paper');m.orb('WhaleArt',(w*.25,h*.15,.018),(0,h*.48,.058),'blue');m.orb('WhaleArtBelly',(w*.19,h*.04,.009),(0,h*.39,.079),'ivory');m.box('WhaleArtTail',(w*.20,h*.1,.025),(w*.30,h*.50,.067),'navy',rot=(0,0,1,.4));m.orb('WhaleEye',(.012,.012,.008),(-w*.14,h*.51,.088),'dark')
 elif i==6:
  m.cyl('ClockFrame',w/2,.045,(0,h/2,0),'metal',rot=(1,0,0,math.pi/2));m.cyl('ClockFace',w*.44,.018,(0,h/2,.03),'ivory',rot=(1,0,0,math.pi/2));m.box('ClockHour',(.019,h*.22,.012),(-w*.048,h*.54,.046),'navy',rot=(0,0,1,.5));m.box('ClockMinute',(.014,h*.32,.012),(w*.054,h*.56,.047),'navy',rot=(0,0,1,-.5))
  for i2 in range(12):a=i2*math.pi/6;m.box('Tick',(.012,.026,.006),(w*.36*math.sin(a),h/2+w*.36*math.cos(a),.046),'metal',rot=(0,0,1,-a))
 elif i==7:
  m.box('FloatShelf',(w,.055,d),(0,.15,0),'ivory')
  for x in [-w*.32,w*.32]:m.box('WallBracket',(.04,.13,.04),(x,.07,-d*.32),'metal')
  plant(m,-w*.27,.18,0,.65)
  for j in range(4):m.box('ShelfBook',(.06,.24,d*.55),(w*.10+j*.07,.30,-d*.1),['navy','blue','paper','pink'][j])
 elif i==8:
  for j in range(3):m.box('BookStack',(w*(1-.06*j),.055,d),(0,.03+j*.055,0),['navy','blue','pink'][j]);m.box('BookPages',(w*.88,.038,d*.98),(0,.03+j*.055,.008),'paper')
  m.cyl('WhaleMug',.065,.12,(w*.22,.23,0),'ivory');m.torus('MugHandle',.042,.01,(w*.29,.23,0),'blue',rot=(0,0,1,math.pi/2));m.badge(w*.22,.23,.071)
 elif i==9:
  m.orb('WhaleBody',(.28,.16,.16),(-.04,.19,0),'blue');m.orb('WhaleBelly',(.22,.055,.14),(-.055,.105,.01),'ivory');m.orb('WhaleEye',(.018,.020,.010),(-.18,.23,.15),'dark')
  for z in [-.07,.07]:m.orb('WhaleFluke',(.11,.075,.10),(.30,.23,z),'navy')
  m.orb('WhaleFin',(.08,.025,.12),(-.025,.13,.15),'navy')
 elif i==10:
  m.box('PrivacyBase',(w,.08,d),(0,.04,0),'dark');m.box('PartitionPanel',(w*.93,h*.92,.08),(0,h*.52,0),'blue')
  for x in [-w*.47,w*.47]:m.box('PartitionFrame',(.05,h,.10),(x,h/2,0),'silver')
  m.box('PartitionLight',(w*.77,.018,.012),(0,h*.89,.055),'cyan')
 else:
  m.box('HoloBase',(w,.07,d),(0,.045,0),'dark');m.box('HoloPanel',(w*.91,h*.82,.02),(0,h*.55,0),'glass');m.box('HoloBorder',(w*.85,.023,.026),(0,h*.89,.014),'cyan');m.badge(-w*.25,h*.73,.033)
  for j in range(3):m.box('HoloLine',(w*(.68-.11*j),.022,.012),(-w*.03,h*(.56-.11*j),.025),'cyan')
NAMES={
'safes':['电子小保险盒','酒店迷你保险柜','文件抽屉保险盒','嵌墙密码保险柜','加固高保险柜','双门保险柜','投递式保险柜','Token存币保险箱','医疗密码保管柜','嵌入式长保险盒','低矮安全抽屉柜','翻盖贵重物品盒'],
'storage':['三抽收纳柜','分格开放书架','鞋柜坐凳','双滑门衣柜','六格更衣柜','L型转角柜','带轮抽屉柜','玻璃陈列柜','入户挂钩坐柜','上下双门收纳柜','壁挂储物柜','叠放整理箱'],
'living':['三座现代沙发','旋转圆座扶手椅','柔软豆袋座椅','模块化软凳','窄边玄关台','电视与媒体柜','升降工作桌','五星脚办公椅','圆形金属边几','椭圆低茶几','蓝白平台床','开放格床边柜'],
'restaurant':['四灶烤箱一体机','双头咖啡机','双层嵌入烤箱','自助点餐终端','灯带餐厅吧台','双门冷藏柜','玻璃糕点展示柜','现代四脚餐桌','水槽操作柜','嵌入洗碗机','高背餐厅卡座','台面微波炉'],
'utility':['前开门洗衣机','洗烘叠放机','镜面洗手台','简洁坐便器','独立长浴缸','圆柱空气净化器','冷热饮水机','壁挂空调','深潜站服务器柜','脚踏分类垃圾桶','扫地机器人与充电座','室内充电终端'],
'decor':['落地绿植','长条组合花槽','磨砂球落地灯','锥罩阅读台灯','暖光壁灯','蓝鲸装饰画','无数字圆时钟','书本绿植浮墙架','书本与鲸鱼杯','大肥鱼鲸鱼摆件','科技隔断屏风','透明信息立牌']}
SIZES={
'safes':[(.62,.60,.47),(.72,.44,.46),(.85,.38,.50),(.62,.70,.23),(.78,1.45,.60),(1.3,1.10,.58),(.65,1.02,.49),(.52,.64,.43),(.68,1.05,.46),(.92,.48,.25),(.92,.32,.54),(.65,.30,.43)],
'storage':[(.85,.95,.48),(1.1,1.75,.37),(1.3,.69,.46),(1.55,1.95,.56),(1.05,1.80,.45),(1.2,.86,1.0),(.54,.76,.48),(.92,1.58,.44),(1.15,1.5,.44),(.72,1.28,.45),(1.0,.62,.34),(.71,.90,.48)],
'living':[(2.2,1.0,.84),(.9,1.0,.85),(.96,.72,.88),(.72,.51,.72),(1.6,.78,.40),(1.45,1.47,.42),(1.45,1.04,.65),(.80,1.18,.80),(.75,.55,.75),(1.3,.45,.72),(1.5,.94,2.1),(.55,.60,.42)],
'restaurant':[(.95,.91,.64),(.74,.69,.50),(.78,1.7,.63),(.49,1.38,.43),(1.85,1.02,.72),(.78,1.85,.65),(1.48,1.32,.67),(1.38,1.1,.78),(1.05,.89,.63),(.64,.88,.59),(1.50,1.45,.82),(.65,.39,.45)],
'utility':[(.64,.91,.62),(.68,1.84,.67),(1.02,1.65,.52),(.65,.85,.76),(1.75,.59,.79),(.52,.92,.52),(.48,1.40,.43),(1.05,.32,.22),(.70,1.82,.67),(.43,.68,.40),(.52,.23,.55),(.47,1.25,.32)],
'decor':[(.60,1.20,.60),(1.50,.83,.45),(.48,1.58,.48),(.40,.52,.40),(.18,.60,.14),(.72,.57,.08),(.50,.50,.08),(1.15,.48,.30),(.48,.31,.30),(.74,.43,.37),(1.2,1.7,.40),(.57,.68,.20)]}
BUILDERS={'safes':safe,'storage':storage,'living':living,'restaurant':restaurant,'utility':utility,'decor':decor}
def main():
 records=[]
 for category,names in NAMES.items():
  for i,name in enumerate(names):
   id=category+'_'+str(i+1).zfill(2);m=Model(id,name,category,SIZES[category][i]);BUILDERS[category](m,i);entry=m.export();records.append(entry)
 (ROOT/'catalog.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
 with (ROOT/'素材索引.csv').open('w',encoding='utf-8-sig',newline='') as out:
  w=csv.writer(out);w.writerow(['ID','名称','类别','宽米','高米','深米','三角形数','网格部件','活动部件','GLB','Godot场景'])
  for r in records:w.writerow([r['id'],r['name'],r['category'],*r['size'],r['triangles'],r['mesh_parts'],len(r['moving']),r['model'],r['scene']])
 for r in records:
  w,h,d=r['size'];solid=r['category']!='decor' or r['id'] in ['decor_01','decor_02','decor_03','decor_11'];shape=''
  if solid:shape=f'''\n[sub_resource type="BoxShape3D" id="Shape"]\nsize = Vector3({w},{h},{d})\n'''
  text=f'''[gd_scene load_steps={4 if solid else 3} format=3]\n\n[ext_resource type="PackedScene" path="res://interior_pack/assets/models/{r['id']}.glb" id="1"]\n[ext_resource type="Script" path="res://interior_pack/scripts/item_3d.gd" id="2"]\n{shape}\n[node name="{r['id']}" type="Node3D"]\nscript = ExtResource("2")\nasset_id = "{r['id']}"\n\n[node name="Model" parent="." instance=ExtResource("1")]\n'''
  if solid:text+=f'''\n[node name="Body" type="StaticBody3D" parent="."]\ncollision_layer = 1\ncollision_mask = 1\n\n[node name="Shape" type="CollisionShape3D" parent="Body"]\nposition = Vector3(0,{h/2},0)\nshape = SubResource("Shape")\n'''
  (ROOT/'scenes/items'/f'{r['id']}.tscn').write_text(text)
 print('Generated',len(records),'real GLB models and Godot scenes;',sum(x['triangles'] for x in records),'triangles')
if __name__=='__main__':main()
