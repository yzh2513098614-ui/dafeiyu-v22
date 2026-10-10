"""Second collection: 72 original, editable volumetric meshes; no image planes.
Run build_models.py then this script to rebuild the complete 144 item collection.
Python 3, NumPy, SciPy. Units: metres, Y up, front +Z, origin on floor.
"""
import math,json,csv
import build_models as b
R=b.ROOT
PI=math.pi
NAMES={
'retail':['传送带收银台','单门玻璃饮料冰柜','双面商品陈列架','金属购物推车','服装与衣架展示架','圆形商品展示台','三格果蔬货台','化妆品阶梯展架','服务台与呼叫铃','自助售货机','四格快递取件柜','翼闸检票通道'],
'lab':['通风实验操作台','翻盖离心机','双目光学显微镜','玻璃罩分析天平','试剂瓶与试管架','试剂冷藏柜','生物反应罐','恒温培养箱','PCR热循环仪','实验控制双屏台','移液器工作站','实验器材推车'],
'medical':['检查诊疗床','超声诊断推车','输液架与输液袋','心电监护推车','急救转运担架','五灯手术照明架','医疗抽屉车','壁挂急救药箱','便携除颤仪','器械托盘架','手动轮椅','三折医疗屏风'],
'logistics':['三层重型仓储架','木质货物托盘','液压搬运叉车','双层运货手推车','翻盖加固运输箱','落地灭火器','壁挂工具整理板','带台钳维修工作台','两轮搬运手推车','智能物流转运柜','机房备用电源柜','防护网工业风扇'],
'lounge':['软垫现代餐椅','三席公共等候椅','L形模块转角沙发','圆形会议桌','演讲台与话筒','电子钢琴与琴凳','室内跑步机','蓝布台球桌','折叠会议桌','带书写板培训椅','双面图书推车','大肥鱼观景水族箱'],
'architecture':['双扇自动玻璃门','双滑门电梯入口','十级模块楼梯','透明玻璃护栏','L形墙壁转角','灯带装饰墙单元','厚框观景窗','吊顶通风模块','翻盖架空地板','灯带结构立柱','嵌墙电气控制柜','四折移动隔断']}
SIZES={
'retail':[(2.1,1.25,.85),(.8,1.85,.75),(1.8,1.75,.85),(.7,1.08,1.05),(1.6,1.8,.58),(.85,.9,.85),(1.5,1.03,.75),(.95,.65,.62),(1.35,1.1,.62),(.9,1.85,.68),(1.1,1.7,.48),(1.35,1.05,1.0)],
'lab':[(1.7,1.9,.8),(.64,.45,.62),(.42,.64,.48),(.56,.56,.45),(.62,.35,.40),(.8,1.85,.66),(.75,1.55,.75),(.75,.9,.6),(.58,.46,.58),(1.6,1.45,.72),(.55,.65,.4),(.75,.95,.5)],
'medical':[(.85,.92,1.9),(.65,1.43,.65),(.62,1.85,.62),(.6,1.48,.55),(.85,.96,1.92),(.95,1.95,.75),(.6,.94,.52),(.65,.60,.2),(.5,.37,.4),(.64,1.05,.5),(.78,1.08,.93),(1.9,1.65,.42)],
'logistics':[(1.9,1.95,.7),(1.15,.16,.95),(.62,1.13,1.6),(.85,.95,1.18),(.85,.64,.62),(.32,.8,.32),(1.3,.9,.18),(1.5,1.1,.7),(.58,1.25,.62),(1.15,1.7,.65),(.72,1.15,.66),(.75,1.4,.55)],
'lounge':[(.56,.88,.58),(1.8,.9,.6),(1.6,.86,1.5),(1.35,.77,1.35),(.7,1.24,.62),(1.35,1.0,.8),(.83,1.3,1.8),(1.9,.86,1.04),(1.6,.75,.75),(.64,.99,.67),(.9,1.22,.55),(1.25,1.35,.52)],
'architecture':[(2.15,2.25,.32),(1.85,2.25,.36),(1.2,1.65,2.1),(1.7,1.1,.2),(1.1,2.2,1.1),(1.15,2.2,.16),(1.65,1.35,.22),(1.0,.15,1.0),(1.0,.16,1.0),(.35,2.2,.35),(.65,1.05,.22),(1.9,1.7,.4)]}
def wheels(m,w,d,y=.11,r=.09,parent=0):
 for x in [-w/2,w/2]:
  for z in [-d/2,d/2]:
   m.cyl('Wheel',r,.055,(x,y,z),'dark',parent,rot=(0,0,1,PI/2));m.cyl('WheelHub',r*.42,.061,(x,y,z),'silver',parent,rot=(0,0,1,PI/2))
def screen(m,w,h,pos,parent=0):
 x,y,z=pos;m.box('MonitorFrame',(w,h,.04),pos,'dark',parent);m.box('Screen',(w*.91,h*.84,.012),(x,y,z+.027),'navy',parent)
 for j in range(3):m.box('DisplayLine',(w*(.65-j*.13),.012,.008),(x-w*.04,y+h*(.23-j*.21),z+.037),'cyan',parent)
def shelf(m,w,d,y,parent=0,mat='ivory'):m.box('Shelf',(w,.045,d),(0,y,0),mat,parent)
def lid(m,w,d,y,name='LidHinge',mat='ivory',angle=-105):
 g=m.group(name,(0,y,-d/2));m.box('Lid',(w,.045,d),(0,0,d/2),mat,g);m.handle(0,.03,d*.85,w*.25,g);m.moving.append({'node':name,'axis':'x','angle':angle});return g
def jar(m,x,y,z,h=.18,r=.05,mat='blue',parent=0):
 m.cyl('Bottle',r,h,(x,y+h/2,z),mat,parent);m.cyl('BottleCap',r*.8,.035,(x,y+h+.014,z),'ivory',parent);m.box('Label',(r*1.35,h*.38,.008),(x,y+h*.52,z+r+.005),'paper',parent)
def cross(m,x,y,z,size=.14,parent=0):
 m.box('MedicalCrossVertical',(size*.30,size,.012),(x,y,z),'red',parent);m.box('MedicalCrossHorizontal',(size,size*.30,.012),(x,y,z+.002),'red',parent)
def trolley(m,w,d,h):
 wheels(m,w*.85,d*.8);m.legs(w*.86,d*.82,h-.18,y=(h+.18)/2,mat='silver')
 shelf(m,w,d,.22);shelf(m,w,d,h)
 for x in [-w*.42,w*.42]:m.cyl('HandlePost',.02,.16,(x,h+.08,-d*.40),'silver')
 m.box('PushHandle',(w*.85,.032,.032),(0,h+.16,-d*.4),'blue')
def table(m,w,d,h,mat='ivory'):
 m.legs(w*.82,d*.75,h-.065);m.box('TableTop',(w,.07,d),(0,h-.035,0),mat)
def slats(m,w,z,y=.8):
 for j in range(7):m.box('VentSlot',(w,.012,.012),(0,y+j*.025,z),'dark')
def retail(m,i):
 w,h,d=m.size
 if i==0:
  b.cabinet(m,w,.86,d);m.box('Belt',(1.1,.035,.57),(-.35,.9,0),'dark')
  for j in range(8):m.box('BeltSeam',(.008,.006,.55),(-.85+j*.14,.921,0),'metal')
  m.cyl('DisplayStand',.025,.22,(.68,1.0,-.10),'silver');screen(m,.48,.30,(.68,1.15,-.08));m.drawer(.6,.18,.64,d/2+.01);m.box('Scanner',(.18,.09,.22),(.43,.92,.2),'blue')
 elif i in [1,9]:
  b.cabinet(m,w,h,d);g=m.door(w-.12,h-.23,0,h/2+.03,d/2,name='CoolingDoor' if i==1 else 'ServiceDoor',mat='metal')
  # Override inset to transparent glazing.
  for n in m.nodes:
   if n.get('name')=='InsetPanel':n['_geom']=('box',[w*.68,(h-.23)*.8,.02,.01],'glass')
  for row in range(4):
   shelf(m,w-.19,d-.15,.35+row*.32)
   for col in range(4):jar(m,(col-1.5)*.14,.38+row*.32,.06,h=.18,mat=['blue','pink','green','ivory'][col])
  if i==9:screen(m,.15,.19,(w*.36,h*.61,d/2+.06));m.box('DispenseSlot',(.5,.15,.02),(0,.2,d/2+.06),'dark')
 elif i==2:
  m.box('Base',(w,.13,d),(0,.065,0),'dark');m.box('Spine',(w,h-.13,.09),(0,h/2+.065,0),'blue')
  for side in [-1,1]:
   for row in range(4):
    y=.20+row*.4;m.box('DisplayShelf',(w,.04,d*.43),(0,y,side*d*.27),'ivory')
    for col in range(6):jar(m,(col-2.5)*.25,y+.03,side*d*.28,h=.23,mat=['paper','blue','pink'][col%3])
 elif i==3:
  wheels(m,w*.84,d*.80);m.box('CartBase',(w,.06,d),(0,.23,0),'metal')
  for x in [-w*.45,w*.45]:m.box('BasketRim',(.024,.024,d*.79),(x,.82,-.06),'silver');m.box('BasketBase',(.025,.025,d*.64),(x*.8,.43,-.06),'silver')
  for j in range(8):
   z=-d*.38+j*d*.1
   for x in [-w*.45,w*.45]:m.box('BasketWire',(.012,.39,.012),(x,.625,z),'silver')
  for y in [.44,.56,.68,.80]:
   for z in [-d*.38,d*.31]:m.box('BasketWire',(w*.9,.012,.012),(0,y,z),'silver')
  for x in [-w*.4,w*.4]:m.box('HandleStem',(.028,.76,.028),(x,.66,d*.45),'metal')
  m.box('HandleGrip',(w*.85,.047,.05),(0,1.04,d*.45),'blue')
 elif i==4:
  for x in [-w*.47,w*.47]:m.box('RackFoot',(.14,.045,d),(x,.03,0),'dark');m.cyl('RackUpright',.025,h-.06,(x,h/2,0),'silver')
  m.box('ClothesRail',(w,.04,.04),(0,h-.05,0),'silver')
  for j in range(7):
   x=(j-3)*.19;m.torus('HangerHook',.032,.008,(x,h-.10,0),'silver',rot=(1,0,0,PI/2));m.box('Garment',(.13,.75,.15),(x,h-.64,0),['blue','ivory','pink'][j%3]);m.box('Shoulder',(.19,.065,.16),(x,h-.25,0),'ivory')
 elif i==5:
  m.cyl('PlinthFoot',w/2,.10,(0,.05,0),'dark');m.cyl('PlinthBody',w*.46,h-.18,(0,h/2,0),'ivory');m.cyl('DisplayCap',w/2,.06,(0,h-.03,0),'silver');m.badge(0,h*.7,w*.46+.014)
 elif i==6:
  b.cabinet(m,w,.7,d)
  for j in range(3):
   x=(j-1)*.48;m.box('ProduceBin',(.43,.13,.62),(x,.78,0),'wood')
   for a in range(3):
    for k in range(3):m.orb('Fruit',(.052,.052,.052),(x+(a-1)*.10,.89+(a+k)%2*.035,(k-1)*.14),['red','green','warm'][j])
 elif i==7:
  for row in range(3):
   y=.12+row*.15;z=.20-row*.20;m.box('Tier',(w,y,.2),(0,y/2,z),'ivory')
   for j in range(6):jar(m,(j-2.5)*.14,y,z,h=.15+row*.025,r=.035,mat=['pink','blue','paper'][j%3])
 elif i==8:
  b.cabinet(m,w,.96,d);m.box('CounterTop',(w+.03,.065,d+.04),(0,.99,0),'ivory');m.cyl('BellBase',.09,.035,(-.4,1.035,.1),'dark');m.orb('BellDome',(.075,.055,.075),(-.4,1.074,.1),'silver');m.cyl('BellButton',.016,.023,(-.4,1.135,.1),'dark');screen(m,.38,.25,(.35,1.22,-.1))
 elif i==10:
  b.cabinet(m,w,h,d)
  for j in range(4):
   g=m.door(w-.16,.35,0,.3+j*.39,d/2,name='LockerHinge'+str(j));m.badge((w-.16)*.48,0,.06,g)
 elif i==11:
  for x in [-w*.38,w*.38]:
   m.box('GateHousing',(.27,.99,d),(x,.5,0),'ivory');screen(m,.17,.20,(x,.84,d/2+.025))
  for j in [-1,1]:
   name='Wing'+str(j);g=m.group(name,(j*w*.28,.58,0));m.box('GateWing',(.38,.63,.025),(-j*.17,0,0),'glass',g);m.box('WingLED',(.35,.013,.029),(-j*.17,.30,0),'cyan',g);m.moving.append({'node':name,'axis':'y','angle':j*90})
def lab(m,i):
 w,h,d=m.size
 if i==0:
  b.cabinet(m,w,.8,d);m.box('Worktop',(w,.055,d),(0,.84,0),'white')
  for x in [-w*.47,w*.47]:m.box('HoodPost',(.07,1.02,d),(x,1.35,0),'silver')
  m.box('HoodRoof',(w,.10,d),(0,1.84,0),'white');m.box('HoodBack',(w,.95,.06),(0,1.34,-d*.46),'navy')
  g=m.group('HoodSash',(0,1.35,d*.43));m.box('GlassSash',(w*.87,.82,.02),(0,0,0),'glass',g);m.box('SashGrip',(w*.85,.03,.04),(0,-.42,.012),'silver',g);m.moving.append({'node':'HoodSash','axis':'y','distance':.4})
  for j in range(4):jar(m,(j-1.5)*.24,.875,-.05,h=.2,mat=['blue','pink','green','ivory'][j])
 elif i==1:
  m.box('InstrumentBody',(w,.30,d),(0,.15,0),'white');m.cyl('RotorWell',.23,.022,(0,.31,0),'dark');m.cyl('RotorHub',.07,.06,(0,.35,0),'silver')
  for j in range(8):a=j*PI/4;m.cyl('SampleTube',.026,.065,(.15*math.cos(a),.355,.15*math.sin(a)),'blue')
  lid(m,w*.96,d*.96,.4,angle=-105);screen(m,.25,.095,(0,.16,d/2+.025))
 elif i==2:
  m.box('MicroscopeBase',(.4,.05,.42),(0,.025,0),'white');m.box('MicroscopeArm',(.065,.40,.10),(0,.26,-.12),'silver',rot=(1,0,0,-.22));m.box('SampleStage',(.34,.025,.28),(0,.24,.03),'dark');m.box('GlassSlide',(.12,.007,.035),(0,.26,.05),'glass')
  m.cyl('Objective',.035,.14,(0,.37,.04),'silver');m.box('OpticalBody',(.12,.11,.15),(0,.48,-.02),'white')
  for x in [-.065,.065]:m.cyl('Eyepiece',.027,.15,(x,.56,-.055),'dark',rot=(1,0,0,-.38))
  for x in [-.085,.085]:m.cyl('FocusKnob',.043,.045,(x,.31,-.12),'blue',rot=(0,0,1,PI/2))
 elif i==3:
  m.box('BalanceBase',(w,.15,d),(0,.075,0),'white');m.cyl('WeighPan',.14,.018,(0,.175,0),'silver')
  for x in [-w*.43,w*.43]:m.box('GlassSide',(.018,.36,d*.83),(x,.36,0),'glass')
  m.box('GlassBack',(w*.86,.36,.018),(0,.36,-d*.40),'glass');m.box('GlassRoof',(w*.89,.025,d*.86),(0,.548,0),'white');m.door(w*.85,.34,0,.36,d*.43,mat='glass');screen(m,.25,.085,(0,.082,d/2+.025))
 elif i==4:
  for y in [.035,.17]:m.box('TubeRack',(w,.018,d),(0,y,0),'ivory')
  for x in [-w*.45,w*.45]:m.box('RackLeg',(.025,.18,.025),(x,.09,0),'silver')
  for j in range(6):
   for k in range(2):jar(m,(j-2.5)*.095,.06,(k-.5)*.20,h=.21,r=.024,mat='glass');m.cyl('SampleLiquid',.019,.095,((j-2.5)*.095,.115,(k-.5)*.20),['blue','pink'][k])
 elif i==5:
  b.cabinet(m,w,h,d);m.door(w-.13,h-.23,0,h/2+.02,d/2,mat='white');screen(m,.18,.09,(w*.3,h-.14,d/2+.03))
 elif i==6:
  m.cyl('TankFoot',.3,.08,(0,.045,0),'dark');m.cyl('ReactionTank',.28,.92,(0,.72,0),'silver');m.orb('TankDome',(.28,.13,.28),(0,1.19,0),'white')
  for x in [-.25,.25]:m.cyl('FeedTube',.018,.30,(x,1.38,0),'silver');m.torus('ValveWheel',.065,.012,(x,1.49,0),'red')
  m.box('LevelWindow',(.07,.61,.025),(0,.75,.281),'glass');m.box('LevelLiquid',(.045,.35,.012),(0,.64,.30),'blue');screen(m,.18,.16,(.10,.56,.3))
 elif i==7:
  b.cabinet(m,w,h,d);m.door(w-.13,h-.2,0,h*.51,d/2);m.box('InternalGlass',(w*.74,h*.59,.025),(0,h*.54,d/2+.05),'glass');screen(m,.17,.065,(0,h-.12,d/2+.05))
 elif i==8:
  m.box('PCRBody',(w,.31,d),(0,.16,0),'white')
  for j in range(6):
   for k in range(4):m.cyl('PCRWell',.013,.028,((j-2.5)*.06,.33,(k-1.5)*.075),'silver')
  lid(m,w*.96,d*.9,.415);screen(m,.32,.12,(0,.17,d/2+.025))
 elif i==9:
  table(m,w,d,.77)
  for x in [-.4,.4]:m.cyl('MonitorPole',.027,.35,(x,.95,-.1),'silver');screen(m,.64,.40,(x,1.24,-.08))
  m.box('Keyboard',(.6,.03,.20),(0,.82,.17),'blue')
 elif i==10:
  m.box('StationBase',(w,.06,d),(0,.03,0),'white');m.box('StationUpright',(.05,.5,.05),(0,.30,-.1),'silver');m.box('PipetteCrossbar',(w,.03,.14),(0,.55,-.05),'blue')
  for j in range(5):x=(j-2)*.10;m.cyl('PipetteHandle',.024,.22,(x,.48,-.03),'ivory');m.cyl('PipetteTip',.007,.17,(x,.285,-.03),'silver');m.cyl('PipetteButton',.013,.028,(x,.606,-.03),'blue')
 elif i==11:
  trolley(m,w,d,.82)
  for j in range(3):jar(m,(j-1)*.19,.85,0,h=.14,r=.055)
  m.box('LowerSampleCase',(.5,.20,.30),(0,.35,0),'blue')
def medical(m,i):
 w,h,d=m.size
 if i in [0,4]:
  if i==4:wheels(m,w*.8,d*.82,r=.09)
  m.box('Chassis',(w*.79,.11,d*.91),(0,.28,0),'silver');m.cyl('LiftColumn',.09,.40,(0,.47,0),'metal');m.box('Mattress',(w,.14,d),(0,.73,0),'ivory');m.box('Pillow',(w*.72,.10,.36),(0,.85,-d*.32),'blue')
  for x in [-w*.49,w*.49]:
   m.box('SafetyRail',(.026,.026,d*.62),(x,.9,0),'silver')
   for z in [-d*.28,d*.28]:m.box('RailPost',(.025,.19,.025),(x,.81,z),'silver')
  if i==0:m.box('FloorBase',(w*.7,.07,d*.55),(0,.04,0),'dark')
 elif i in [1,3]:
  trolley(m,w,d,.72);m.box('InstrumentBody',(w*.82,.22,d*.78),(0,.88,0),'white');m.cyl('DisplayMast',.024,.30,(0,1.1,-.03),'silver');screen(m,w*.8,.32,(0,1.28,0));m.box('InputPanel',(w*.7,.03,.25),(0,1.01,.12),'blue')
  for j in range(4):m.box('Button',(.03,.014,.03),((j-1.5)*.08,1.033,.15),'ivory')
  if i==1:m.box('UltrasoundProbe',(.05,.13,.035),(w*.5,.90,.10),'white');m.torus('ProbeCable',.14,.008,(w*.43,.62,0),'dark',rot=(1,0,0,PI/2))
 elif i==2:
  wheels(m,w*.72,d*.72,r=.055);m.cyl('IVPole',.016,1.75,(0,.95,0),'silver');m.box('IVBase',(w*.7,.032,.045),(0,.10,0),'metal');m.box('IVBase',(.045,.032,d*.7),(0,.10,0),'metal');m.box('HookRail',(.47,.02,.02),(0,1.81,0),'silver')
  for z in [-d*.36,d*.36]:m.box('CasterCrossBrace',(math.hypot(w*.72,d*.72),.025,.035),(0,.10,0),'silver',rot=(0,1,0,-math.atan2(z,w*.36)))
  for x in [-.18,.18]:m.torus('BagHook',.028,.007,(x,1.77,0),'silver',rot=(1,0,0,PI/2));m.box('IVBag',(.13,.26,.034),(x,1.58,0),'glass');m.box('Fluid',(.105,.16,.012),(x,1.53,.02),'water');m.cyl('Tube',.003,.88,(x,1.0,.018),'water')
 elif i==5:
  m.cyl('LampBase',.25,.045,(0,.025,0),'dark');m.cyl('LampMast',.035,1.74,(0,.9,-.18),'silver');m.box('LampArm',(.05,.05,.58),(0,1.8,.1),'silver');m.cyl('LampHead',.35,.07,(0,1.71,.32),'white')
  for j in range(5):a=j*2*PI/5;m.cyl('LampLens',.095,.025,(.21*math.cos(a),1.662,.32+.21*math.sin(a)),'warm')
 elif i==6:
  b.cabinet(m,w,.85,d);wheels(m,w*.82,d*.82,r=.06)
  for j in range(3):m.drawer(w-.13,.19,.26+j*.23,d/2,name='MedicalDrawer'+str(j))
  m.box('TrayLip',(w,.04,.04),(0,.91,-d*.45),'blue');cross(m,0,.25,d/2+.085,.1)
 elif i==7:
  b.cabinet(m,w,h,d);g=m.door(w-.10,h-.14,0,h/2+.01,d/2,mat='white');cross(m,(w-.10)*.5,0,.06,.20,g)
 elif i==8:
  m.box('DefibrillatorBody',(w,.28,d),(0,.15,0),'white');screen(m,.24,.15,(-.055,.20,d/2+.022));m.box('Paddle',(.07,.12,.03),(.17,.18,d/2+.04),'blue');m.box('CarryHandle',(.23,.03,.04),(0,.35,0),'dark')
  for x in [-.115,.115]:m.box('HandleSupport',(.028,.06,.04),(x,.32,0),'dark')
  cross(m,.17,.055,d/2+.025,.065)
 elif i==9:
  wheels(m,w*.8,d*.8,r=.055);m.cyl('TrayPedestal',.023,.79,(0,.51,0),'silver');m.box('Tray',(w,.034,d),(0,1.0,0),'silver')
  for z in [-d*.40,d*.40]:m.box('TrayCasterBrace',(math.hypot(w*.8,d*.8),.025,.035),(0,.11,0),'silver',rot=(0,1,0,-math.atan2(z,w*.4)))
  for x in [-w/2,w/2]:m.box('TrayRim',(.015,.035,d),(x,1.03,0),'silver')
  for j in range(3):m.cyl('Instrument',.008,.23,((j-1)*.11,1.035,0),'silver',rot=(1,0,0,PI/2));m.orb('InstrumentGrip',(.019,.01,.037),((j-1)*.11,1.034,.08),'blue')
 elif i==10:
  for x in [-.32,.32]:
   m.torus('RearWheel',.26,.032,(x,.295,-.15),'dark',rot=(0,0,1,PI/2));m.torus('HandRim',.22,.010,(x*1.09,.295,-.15),'silver',rot=(0,0,1,PI/2))
   for j in range(8):a=j*PI/4;m.box('Spoke',(.014,.45,.014),(x,.295,-.15),'silver',rot=(1,0,0,a))
   m.cyl('FrontCaster',.06,.045,(x,.085,.35),'dark',rot=(0,0,1,PI/2));m.box('ArmRest',(.065,.05,.47),(x*.78,.74,0),'blue');m.box('ArmPost',(.025,.23,.025),(x*.78,.60,.15),'silver')
  m.cyl('RearAxle',.017,.73,(0,.295,-.15),'silver',rot=(0,0,1,PI/2))
  m.box('FrontAxle',(.69,.03,.035),(0,.45,.35),'silver')
  for x in [-.32,.32]:m.box('FrontFork',(.028,.38,.028),(x,.275,.35),'silver')
  for x in [-.24,.24]:m.box('ChassisSide',(.03,.035,.58),(x,.45,.06),'silver')
  for x in [-.21,.21]:m.box('FootSupport',(.025,.26,.09),(x,.32,.37),'silver')
  m.box('Seat',(.47,.07,.43),(0,.50,0),'blue');m.box('Backrest',(.48,.43,.08),(0,.77,-.25),'blue');m.box('Footrest',(.43,.035,.19),(0,.19,.40),'metal')
  for x in [-.24,.24]:m.box('BackFrame',(.03,.72,.03),(x,.62,-.27),'silver');m.box('PushGrip',(.03,.03,.15),(x,.97,-.35),'dark')
 elif i==11:
  for j in range(3):
   x=(j-1)*.61;m.box('PrivacyFabric',(.57,1.35,.025),(x,.87,0),'blue')
   for xx in [x-.295,x+.295]:m.box('PanelUpright',(.025,1.62,.025),(xx,.84,0),'silver');m.box('PanelFoot',(.09,.035,.40),(xx,.04,0),'dark')
   m.box('PanelTop',(.60,.025,.03),(x,1.64,0),'silver')
def logistics(m,i):
 w,h,d=m.size
 if i==0:
  m.legs(w*.96,d*.88,h,mat='metal')
  for row in range(3):
   shelf(m,w,d,.18+row*.60,mat='silver')
   for j in range(3):m.box('CargoBox',(.48,.35,.48),((j-1)*.56,.38+row*.60,0),['blue','ivory','metal'][j]);m.box('CargoLabel',(.14,.09,.008),((j-1)*.56,.38+row*.6,.247),'paper')
 elif i==1:
  for x in [-w*.4,0,w*.4]:
   for z in [-d*.4,0,d*.4]:m.box('PalletBlock',(.13,.085,.13),(x,.07,z),'wood')
  for j in range(7):m.box('PalletBoard',(w,.035,.10),(0,.142,(j-3)*.13),'wood')
  for x in [-w*.4,0,w*.4]:m.box('BottomRunner',(.13,.025,d),(x,.013,0),'wood')
 elif i==2:
  for x in [-.22,.22]:m.box('Fork',(.15,.08,1.32),(x,.12,-.11),'blue');m.cyl('ForkRoller',.065,.12,(x,.069,-.62),'dark',rot=(0,0,1,PI/2))
  m.box('JackBody',(.52,.24,.32),(0,.2,.53),'metal');m.cyl('HydraulicRam',.05,.35,(0,.42,.55),'silver');m.box('PullHandleStem',(.045,.73,.045),(0,.77,.64),'silver');m.box('PullHandle',(.32,.045,.08),(0,1.12,.64),'dark')
 elif i==3:
  trolley(m,w,d,.8);m.box('CargoBox',(.52,.40,.65),(0,.45,0),'blue')
 elif i==4:
  b.cabinet(m,w,h-.06,d,mat='metal');lid(m,w,d,h-.02,mat='blue',angle=-100)
  for x in [-w*.35,w*.35]:m.box('CaseStrap',(.034,h-.1,.019),(x,h/2,d/2+.025),'dark');m.box('Latch',(.065,.08,.035),(x,h-.16,d/2+.05),'silver')
  m.handle(0,h*.45,d/2+.04,.23);m.badge(0,h*.66,d/2+.04)
 elif i==5:
  m.cyl('Extinguisher',.10,.49,(0,.29,0),'red');m.orb('Shoulder',(.10,.065,.10),(0,.535,0),'red');m.cyl('Valve',.025,.10,(0,.62,0),'silver');m.box('Lever',(.15,.025,.05),(0,.685,0),'dark');m.box('Label',(.10,.20,.008),(0,.29,.106),'paper');m.torus('Hose',.10,.009,(.07,.58,-.03),'dark',rot=(1,0,0,PI/2));m.cyl('Nozzle',.017,.15,(.15,.65,-.02),'dark')
 elif i==6:
  m.box('ToolBoard',(w,h,.04),(0,h/2,0),'blue')
  for j in range(11):
   for k in range(6):m.cyl('Perforation',.008,.01,((j-5)*.10,.13+k*.12,.028),'dark',rot=(1,0,0,PI/2))
  for j in range(5):x=(j-2)*.22;m.box('ToolShaft',(.025,.30,.025),(x,.58,.065),'silver');m.orb('ToolGrip',(.03,.065,.025),(x,.40,.065),'dark');m.box('ToolHead',(.08,.055,.035),(x,.75,.065),'silver')
  for j in [-1,1]:m.box('PartsBin',(.32,.13,.15),(j*.30,.10,.06),'ivory')
 elif i==7:
  table(m,w,d,.9,mat='wood');m.box('LowerBrace',(w*.86,.045,.05),(0,.22,0),'silver');m.box('ViseBase',(.24,.10,.25),(.45,.99,.12),'blue')
  for z in [-.04,.14]:m.box('ViseJaw',(.25,.09,.045),(.45,1.055,z),'silver')
  m.cyl('ViseScrew',.015,.32,(.45,1.0,.2),'dark',rot=(1,0,0,PI/2));m.box('Crank',(.17,.02,.02),(.45,1.0,.35),'silver')
 elif i==8:
  for x in [-.24,.24]:m.box('HandTruckFrame',(.035,1.11,.035),(x,.65,-.10),'silver');m.cyl('Wheel',.11,.07,(x,.12,-.12),'dark',rot=(0,0,1,PI/2))
  for y in [.35,.65,.94,1.23]:m.box('Crossbar',(.50,.033,.033),(0,y,-.1),'blue')
  m.box('LoadFoot',(.5,.04,.43),(0,.065,.10),'silver');m.box('Cargo',(.41,.55,.33),(0,.37,.065),'ivory')
 elif i==9:
  b.cabinet(m,w,h,d)
  for j in range(3):m.door(w-.18,.41,0,.32+j*.47,d/2,name='TransferDoor'+str(j))
  screen(m,.26,.1,(0,h-.13,d/2+.03))
 elif i==10:
  b.cabinet(m,w,h,d,mat='metal');m.door(w-.12,h-.23,0,h/2,d/2,mat='dark');screen(m,.23,.13,(0,.91,d/2+.064));slats(m,w*.63,d/2+.065,y=.35)
 elif i==11:
  m.cyl('FanBase',.25,.04,(0,.025,0),'dark');m.cyl('FanStem',.027,.83,(0,.47,0),'silver');m.torus('FanRing',.32,.018,(0,1.05,0),'silver',rot=(1,0,0,PI/2));m.cyl('FanHub',.06,.07,(0,1.05,.015),'blue',rot=(1,0,0,PI/2))
  for j in range(6):
   a=j*PI/3;m.box('FanBlade',(.095,.26,.016),(.13*math.sin(a),1.05+.13*math.cos(a),0),'blue',rot=(0,0,1,-a))
  for j in range(12):m.box('SafetySpoke',(.009,.63,.009),(0,1.05,.065),'silver',rot=(0,0,1,j*PI/12))
def lounge(m,i):
 w,h,d=m.size
 if i in [0,9]:
  table(m,.48,.46,.46);m.box('Seat',(.49,.075,.47),(0,.47,0),'blue');m.box('Backrest',(.48,.32,.065),(0,.70,-.23),'ivory')
  for x in [-.21,.21]:m.box('BackSupport',(.025,.46,.025),(x,.61,-.22),'silver')
  if i==9:m.box('WritingArm',(.028,.4,.03),(.28,.70,.05),'silver');m.box('WritingTablet',(.35,.035,.37),(.14,.95,.1),'ivory')
 elif i==1:
  m.box('BenchBeam',(w*.88,.06,.055),(0,.38,0),'silver')
  for x in [-w*.35,w*.35]:m.box('BeamFoot',(.045,.35,.05),(x,.20,0),'metal');m.box('FloorFoot',(.25,.035,.4),(x,.025,0),'dark')
  for j in range(3):x=(j-1)*.57;m.box('BenchSeat',(.53,.08,.46),(x,.46,0),'blue');m.box('BenchBack',(.53,.34,.075),(x,.71,-.22),'ivory')
 elif i==2:
  m.box('SofaBase',(w,.18,.69),(0,.20,-.38),'dark');m.box('SofaBase',(.69,.18,d-.28),(-.45,.20,.19),'dark')
  m.box('Seat',(w-.1,.20,.6),(0,.41,-.33),'ivory');m.box('Seat',(.60,.20,.76),(-.46,.41,.36),'ivory');m.box('Back',(w,.37,.12),(0,.65,-.65),'blue');m.box('SideBack',(.12,.37,d-.05),(-.73,.65,.06),'blue');m.box('ArmRest',(.14,.28,.63),(.73,.55,-.34),'ivory')
 elif i==3:
  m.cyl('MeetingFoot',.45,.045,(0,.025,0),'dark');m.cyl('Pedestal',.13,.63,(0,.36,0),'silver');m.cyl('TableTop',w/2,.075,(0,h-.037,0),'ivory')
 elif i==4:
  m.box('LecternFoot',(w,.055,d),(0,.03,0),'dark');m.box('LecternColumn',(w*.63,.87,d*.55),(0,.5,0),'white');m.box('ReadingTop',(w,.06,d),(0,1.0,0),'blue',rot=(1,0,0,.18));m.cyl('MicrophoneStem',.009,.17,(.21,1.12,-.10),'silver',rot=(1,0,0,.28));m.orb('Microphone',(.023,.035,.022),(.21,1.23,-.075),'dark');m.badge(0,.6,d*.275+.02)
 elif i==5:
  table(m,w,.36,.77,mat='dark');m.box('PianoBody',(w,.12,.36),(0,.83,-.12),'blue')
  for j in range(28):
   x=(j-13.5)*.039;m.box('WhiteKey',(.036,.016,.16),(x,.90,-.015),'ivory')
   if j%7 not in [2,6]:m.box('BlackKey',(.022,.023,.085),(x+.019,.92,-.055),'dark')
  for x in [-.23,.23]:
   for z in [.31,.57]:m.box('BenchLeg',(.038,.467,.038),(x,.2335,z),'dark')
  m.box('BenchSeat',(.56,.045,.30),(0,.485,.44),'blue')
 elif i==6:
  m.box('TreadmillDeck',(w,.12,d),(0,.10,0),'white');m.box('RunningBelt',(w*.74,.015,d*.76),(0,.167,.10),'dark')
  for x in [-w*.42,w*.42]:m.box('HandrailStem',(.05,1.06,.055),(x,.68,-d*.37),'silver',rot=(1,0,0,-.10));m.box('HandleGrip',(.06,.06,.49),(x,1.17,-.45),'blue')
  m.box('ControlBar',(w,.08,.24),(0,1.24,-.63),'white');screen(m,.34,.12,(0,1.24,-.48))
 elif i==7:
  m.legs(w*.8,d*.7,.68,y=.34,mat='metal');m.box('PoolBody',(w,.16,d),(0,.74,0),'ivory');m.box('PoolCloth',(w*.88,.025,d*.78),(0,.835,0),'blue')
  for x in [-w*.46,0,w*.46]:
   for z in [-d*.4,d*.4]:m.cyl('Pocket',.046,.025,(x,.856,z),'dark')
  for j in range(7):m.orb('PoolBall',(.026,.026,.026),(-.35+j*.07,.872,.02+(j%2)*.06),['ivory','red','warm','blue'][j%4])
  m.cyl('PoolCue',.009,1.3,(.1,.87,-.25),'wood',rot=(0,0,1,PI/2))
 elif i==8:
  m.box('FoldingTop',(w,.055,d),(0,.72,0),'ivory')
  for x in [-w*.35,w*.35]:
   for sign in [-1,1]:m.box('FoldingLeg',(.032,.71,.035),(x,.36,0),'silver',rot=(1,0,0,sign*.47))
  m.box('CrossSupport',(w*.70,.025,.03),(0,.22,0),'dark')
 elif i==10:
  trolley(m,w,d,1.08)
  for y in [.27,.63,1.1]:
   shelf(m,w,d,y)
   for j in range(9):m.box('Book',(.065,.22,.20),((j-4)*.085,y+.13,.08),['navy','blue','paper','pink'][j%4])
 elif i==11:
  b.cabinet(m,w,.51,d);m.box('WaterVolume',(w-.08,.61,d-.08),(0,.86,0),'glass')
  for x in [-w*.49,w*.49]:m.box('TankSide',(.026,.65,d),(x,.86,0),'glass')
  for z in [-d*.49,d*.49]:m.box('TankPane',(w,.65,.016),(0,.86,z),'glass')
  m.box('AquariumTop',(w,.06,d),(0,1.22,0),'dark');m.box('AquariumLight',(w*.85,.018,.025),(0,1.181,d*.43),'cyan');m.orb('WhaleBody',(.21,.115,.10),(0,.89,0),'blue');m.orb('WhaleBelly',(.16,.036,.09),(-.02,.82,.005),'ivory')
  for z in [-.045,.045]:m.orb('WhaleTail',(.08,.044,.06),(.25,.93,z),'navy')
  m.orb('WhaleEye',(.013,.013,.008),(-.11,.925,.10),'dark')
  for j in range(8):m.orb('Pebble',(.04,.017,.04),((j-3.5)*.13,.56,.12*(j%2-.5)),'silver')
def architecture(m,i):
 w,h,d=m.size
 if i in [0,1]:
  for x in [-w/2+.075,w/2-.075]:m.box('FramePost',(.15,h,d),(x,h/2,0),'metal')
  m.box('Lintel',(w,.14,d),(0,h-.07,0),'silver');m.box('Sensor',(.15,.035,.035),(0,h-.12,d/2+.017),'dark')
  for sign in [-1,1]:
   name='SlidingLeaf'+str(sign);g=m.group(name,(sign*(w-.3)/4,(h-.14)/2,0));pw=(w-.30)/2
   m.box('DoorLeaf',(pw,h-.16,.035),(0,0,0),'glass' if i==0 else 'silver',g)
   for x in [-pw/2+.015,pw/2-.015]:m.box('DoorVertical',(.025,h-.16,.044),(x,0,0),'dark',g)
   for y in [-(h-.16)/2,(h-.16)/2]:m.box('DoorHorizontal',(pw,.025,.044),(0,y,0),'dark',g)
   m.box('DoorSafetyStripe',(pw,.035,.009),(0,0,.030),'cyan',g);m.moving.append({'node':name,'axis':'x','distance':sign*pw*.96})
  if i==1:screen(m,.085,.14,(w/2-.075,1.12,d/2+.03))
 elif i==2:
  for j in range(10):
   y=(j+1)*h/10;z=d/2-(j+.5)*d/10;m.box('StairStep',(w,y,d/10),(0,y/2,z),'white');m.box('StepNose',(w,.012,.025),(0,y+.007,z+d/20-.015),'cyan')
  for x in [-w*.47,w*.47]:
   for j in range(5):m.box('RailPost',(.025,.72,.025),(x,.35+(j+1)*h/5,d/2-(j+1)*d/5+.12),'silver')
   # Inclined cylinder connects the endpoints of the handrail.
   m.cyl('StairHandrail',.021,math.hypot(h,d),(x,h/2+.80,0),'silver',rot=(1,0,0,-math.atan2(d,h)))
  m.size[1]=h+.95
 elif i==3:
  m.box('RailingGlass',(w-.1,.89,.018),(0,.56,0),'glass')
  for x in [-w*.47,w*.47]:m.box('RailingPost',(.035,h,.035),(x,h/2,0),'silver');m.box('Anchor',(.10,.02,.10),(x,.01,0),'metal')
  m.box('Handrail',(w,.04,.065),(0,h-.02,0),'silver')
 elif i in [4,5]:
  m.box('WallPanel',(w,h,.12),(0,h/2,-d/2+.06),'white')
  if i==4:m.box('CornerReturn',(.12,h,d-.12),(-w/2+.06,h/2,.06),'white')
  for y in [.09,h-.05]:m.box('WallTrim',(w,.07,.16),(0,y,-d/2+.07),'metal')
  for j in range(3):m.box('PanelSeam',(.006,h-.15,.008),((j-1)*w*.31,h/2,-d/2+.126),'metal')
  m.box('WallLED',(w*.83,.012,.012),(0,h-.18,-d/2+.131),'cyan')
 elif i==6:
  m.box('WindowGlass',(w-.14,h-.14,.017),(0,h/2,0),'glass')
  for x in [-w/2+.035,w/2-.035,0]:m.box('WindowVertical',(.07,h,d*.7),(x,h/2,0),'metal')
  for y in [.035,h-.035]:m.box('WindowHorizontal',(w,.07,d),(0,y,0),'silver')
  m.box('WindowSill',(w+.03,.05,d),(0,.025,.02),'white');m.box('WindowLED',(w-.15,.015,.012),(0,h-.071,.092),'warm')
 elif i==7:
  m.box('CeilingFrame',(w,h,d),(0,h/2,0),'white');m.box('VentRecess',(w*.8,.02,d*.8),(0,.01,0),'dark')
  for j in range(12):m.box('VentLouver',(w*.75,.02,.035),(0,.015,(j-5.5)*.063),'silver')
 elif i==8:
  for x in [-w*.47,w*.47]:m.box('HatchFrame',(.06,.10,d),(x,.06,0),'metal')
  for z in [-d*.47,d*.47]:m.box('HatchFrame',(w,.10,.06),(0,.06,z),'metal')
  lid(m,w*.87,d*.87,.15,mat='white',angle=-110)
 elif i==9:
  m.box('Column',(w,h,d),(0,h/2,0),'metal')
  for z in [-d/2-.006,d/2+.006]:m.box('ColumnLight',(.035,h*.86,.012),(0,h/2,z),'cyan')
  for y in [.07,h-.07]:m.box('ColumnCap',(w+.035,.12,d+.035),(0,y,0),'silver')
 elif i==10:
  b.cabinet(m,w,h,d);m.door(w-.10,h-.17,0,h/2,d/2,mat='white')
  for j in range(6):m.box('CircuitBreaker',(.055,.12,.05),((j-2.5)*.076,.6,.005),'dark');m.box('Switch',(.025,.03,.02),((j-2.5)*.076,.62,.035),'blue')
 elif i==11:
  for j in range(4):
   g=m.group('FoldPanel'+str(j),((j-1.5)*.46,h/2,0));m.box('Fabric',(.44,h-.16,.025),(0,0,0),'ivory',g)
   for x in [-.23,.23]:m.box('FoldStile',(.018,h,.028),(x,0,0),'silver',g)
   for y in [-h/2+.02,h/2-.02]:m.box('FoldRail',(.46,.022,.028),(0,y,0),'silver',g)
   m.box('PrivacyAccent',(.40,.05,.013),(0,h*.18,.021),'blue',g)
  for x in [-.85,.85]:m.box('PartitionFoot',(.13,.035,.36),(x,.023,0),'dark')
BUILDERS={'retail':retail,'lab':lab,'medical':medical,'logistics':logistics,'lounge':lounge,'architecture':architecture}
def scene(r):
 w,h,d=r['size'];id=r['id'];small=id in ['lab_02','lab_03','lab_04','lab_05','lab_08','lab_09','lab_11','medical_08','medical_09','logistics_07','architecture_07','architecture_08','architecture_11']
 shapes=[]
 if not small:
  if id in ['architecture_01','architecture_02']:
   shapes=[('LeftPost',(.15,h,d),(-w/2+.075,h/2,0)),('RightPost',(.15,h,d),(w/2-.075,h/2,0)),('Lintel',(w-.3,.14,d),(0,h-.07,0))]
  elif id=='architecture_03':
   stair_h=SIZES['architecture'][2][1];shapes=[('Step'+str(j),(w,(j+1)*stair_h/10,d/10),(0,(j+1)*stair_h/20,d/2-(j+.5)*d/10)) for j in range(10)]
  elif id=='architecture_05':shapes=[('Back',(w,h,.12),(0,h/2,-d/2+.06)),('Return',(.12,h,d-.12),(-w/2+.06,h/2,.06))]
  elif id in ['retail_12','medical_03','medical_06','medical_10']:
   shapes=[('Footprint',(w,.18,d),(0,.09,0))]
  else:shapes=[('Shape',(w,h,d),(0,h/2,0))]
 s='[gd_scene load_steps='+str(3+len(shapes)+(1 if id in ['architecture_01','architecture_02'] else 0))+' format=3]\n\n'
 s+=f'[ext_resource type="PackedScene" path="{r["model"]}" id="1"]\n[ext_resource type="Script" path="res://interior_pack/scripts/item_3d.gd" id="2"]\n'
 for name,size,pos in shapes:s+=f'\n[sub_resource type="BoxShape3D" id="{name}"]\nsize = Vector3({','.join(str(float(v)) for v in size)})\n'
 passage=id in ['architecture_01','architecture_02']
 if passage:s+=f'\n[sub_resource type="BoxShape3D" id="DoorBlock"]\nsize = Vector3({w-.3},{h-.16},0.07)\n'
 s+=f'\n[node name="{id}" type="Node3D"]\nscript = ExtResource("2")\nasset_id = "{id}"\npassage = {str(passage).lower()}\n\n[node name="Model" parent="." instance=ExtResource("1")]\n'
 if shapes:
  s+='\n[node name="Body" type="StaticBody3D" parent="."]\ncollision_layer = 1\ncollision_mask = 1\n'
  for name,size,pos in shapes:s+=f'\n[node name="{name}" type="CollisionShape3D" parent="Body"]\nposition = Vector3({','.join(str(float(v)) for v in pos)})\nshape = SubResource("{name}")\n'
 if passage:s+=f'\n[node name="DoorBlocker" type="StaticBody3D" parent="."]\n\n[node name="Shape" type="CollisionShape3D" parent="DoorBlocker"]\nposition = Vector3(0,{(h-.16)/2},0)\nshape = SubResource("DoorBlock")\n'
 (R/'scenes/items'/f'{id}.tscn').write_text(s)
def glaze_doors(m):
 # A glazing inset cannot show the interior if a solid slab is left behind it.
 for group in list(m.nodes):
  children=group.get('children',[])
  panel=next((m.nodes[n] for n in children if m.nodes[n].get('name')=='DoorPanel'),None)
  inset=next((m.nodes[n] for n in children if m.nodes[n].get('name')=='InsetPanel'),None)
  if panel is None or inset is None:continue
  g=m.nodes.index(group);_,args,mat=panel['_geom'];w,h,d,bev=args;x=panel['translation'][0]
  panel['_geom']=('box',[w,.055,d,.01],'silver');panel['translation']=[x,-h/2+.0275,0]
  inset['_geom']=('box',[w-.08,h-.09,.016,.003],'glass');inset['translation']=[x,0,0]
  m.box('GlazedTopRail',(w,.055,d),(x,h/2-.0275,0),'silver',g)
  for side in [-1,1]:m.box('GlazedSideRail',(.045,h-.11,d),(x+side*(w/2-.0225),0,0),'silver',g)
def fit_bounds(m):
 import numpy as np
 from scipy.spatial.transform import Rotation
 lo=np.full(3,np.inf);hi=-lo
 def visit(idx,parent):
  n=m.nodes[idx];t=np.eye(4);t[:3,3]=n.get('translation',[0,0,0])
  if 'rotation' in n:t[:3,:3]=Rotation.from_quat(n['rotation']).as_matrix()
  world=parent@t
  if '_geom' in n:
   kind,args,mat=n['_geom'];v,_=b.geometry(kind,args);v=v@world[:3,:3].T+world[:3,3]
   nonlocal lo,hi
   lo=np.minimum(lo,v.min(axis=0));hi=np.maximum(hi,v.max(axis=0))
  for child in n.get('children',[]):visit(child,world)
 visit(0,np.eye(4))
 m.size=[round(max(abs(lo[0]),abs(hi[0]))*2,4),round(max(hi[1],m.size[1]),4),round(max(abs(lo[2]),abs(hi[2]))*2,4)]
def main():
 records=[r for r in json.loads((R/'catalog.json').read_text()) if r['category'] not in NAMES]
 assert len(records)==72,'Build the original collection first.'
 for category,names in NAMES.items():
  for i,name in enumerate(names):
   m=b.Model(category+'_'+str(i+1).zfill(2),name,category,SIZES[category][i]);BUILDERS[category](m,i);
   if m.id in ["retail_02","retail_10","lab_04","lab_08"]:glaze_doors(m)
   fit_bounds(m);r=m.export();scene(r);records.append(r)
 (R/'catalog.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
 with (R/'素材索引.csv').open('w',encoding='utf-8-sig',newline='') as f:
  out=csv.writer(f);out.writerow(['ID','名称','类别','宽米','高米','深米','三角形数','网格部件','活动部件','GLB','Godot场景'])
  for r in records:out.writerow([r['id'],r['name'],r['category'],*r['size'],r['triangles'],r['mesh_parts'],len(r['moving']),r['model'],r['scene']])
 print('Total',len(records),'models;',sum(r['triangles'] for r in records),'triangles;',sum(bool(r['moving']) for r in records),'animated assets')
if __name__=='__main__':main()
