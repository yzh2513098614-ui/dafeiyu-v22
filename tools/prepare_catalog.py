"""Read atlas alpha bounds, write extraction metadata and independent Godot scenes."""
from pathlib import Path
import json, shutil
import numpy as np
from PIL import Image
from scipy.ndimage import label,find_objects
root=Path(__file__).resolve().parents[1]; workspace=root.parent
specs=[
('structure','1ec0ce84-0207-4539-b74d-5e17bb128ca7',[168,435,615,857],6,
'plaster_ivory oak_slats walnut_slats slate_panels concrete_panels navy_padded plaster_mint cream_tile brushed_metal beige_wainscot white_marble pale_wainscot cap_charcoal cap_oak base_charcoal base_oak rail_cyan rail_amber post_charcoal post_oak post_cream corner_charcoal corner_oak post_cyan'.split(),
'象牙灰墙 橡木格栅 胡桃格栅 石板墙 混凝土墙 深蓝软包 薄荷墙 奶油瓷砖 拉丝金属 米色护墙 白色大理石 浅木护墙 深灰压顶 橡木压顶 深灰踢脚线 橡木踢脚线 蓝色灯带 暖色灯带 深灰立柱 橡木立柱 奶油立柱 深灰转角柱 橡木转角柱 蓝灯立柱'.split()),
('furniture','2c12c835-70a4-41ca-8a21-c9cc38b19e2c',[170,425,650,875],6,
'bed_navy bed_sage desk_oak desk_white bookcase wardrobe loveseat_navy sofa_cream armchair_navy armchair_sage side_table coffee_table dining_round dining_white chair_oak chair_white office_chair nightstand dresser cubby tv_cabinet shoe_cabinet entry_bench coat_rack'.split(),
'蓝色床 绿色床 橡木书桌 白色书桌 书架 衣柜 双人沙发 奶油沙发 蓝色扶手椅 绿色扶手椅 边几 玻璃茶几 圆餐桌 白餐桌 木椅 白椅 办公椅 床头柜 斗柜 格子柜 电视柜 鞋柜 入口长凳 衣帽架'.split()),
('opening','caad694e-41d0-4079-aa10-28a559301c71',[175,480,820,1100],4,
'window_oak window_city window_frost window_arch door_walnut door_ivory door_glass door_sliding curtains_ivory curtains_navy blind shutters terminal intercom vent air_conditioner'.split(),
'木框窗 城市宽窗 磨砂窗 拱形窗 木门 白门 玻璃门 双滑门 白窗帘 蓝窗帘 百叶帘 木百叶 终端 门禁 通风口 空调'.split()),
('decor','4018d5da-95f6-4f99-93d5-dacadaca50e3',[205,545,815,1095],4,
'plant_broadleaf plant_fiddle plant_snake plant_hanging bonsai succulents flowers fern books open_book whale_mug tea_tray laptop monitor keyboard folded_blanket'.split(),
'阔叶盆栽 琴叶榕 虎尾兰 吊绿萝 盆景 多肉 花瓶 蕨类 叠书 打开的书 鲸鱼杯 茶盘 笔记本电脑 显示器 键鼠 叠毯'.split()),
('decor','d719fb5b-3c96-43be-92c0-ec373d93c7aa',[190,510,805,1085],4,
'lamp_table lamp_floor lamp_wall light_cyan painting_mountain painting_whale clock mirror basket storage_box slippers cushion whale_plush waste_bin lantern shelf_books'.split(),
'台灯 落地灯 壁灯 蓝光灯 山景画 鲸鱼画 时钟 镜子 竹篮 收纳箱 拖鞋 抱枕 鲸鱼玩偶 垃圾桶 提灯 书本壁架'.split())]
# Kitchen source is added after image generation finishes.
kitchen=list((workspace/'generated_images').glob('*'))
if (root/'tools/kitchen_source.txt').exists():
 specs.append(('kitchen',(root/'tools/kitchen_source.txt').read_text().strip(),[185,480,805,1100],4,
 'fridge sink_counter stove_counter counter_blank oven_counter corner_counter bar_cabinet bakery_case espresso microwave upper_cabinet plate_rack bar_stool tea_trolley menu_easel vending_machine'.split(),
 '冰箱 水槽台 灶台 空台面 烤箱柜 转角台 吧台柜 展示柜 咖啡机 微波炉 吊柜 盘架 吧凳 茶水车 菜单架 售货机'.split()))
fwidth=[192,192,240,240,128,144,256,264,132,132,104,200,160,240,80,80,92,104,200,152,256,96,180,86]
dwidth=[92,86,64,90,70,58,46,84,44,64,30,84,88,86,74,60,42,66,40,104,100,100,54,82,56,66,52,60,80,44,46,100]
openingwidth=[168,252,136,118,104,104,108,144,188,188,168,144,76,80,88,180]
kwidth=[120,128,128,128,128,128,128,204,76,88,144,132,64,124,78,120]
entries=[]
for category,source,rows,columns,names,labels in specs:
 p=workspace/'generated_images'/('exec-'+source+'.png')
 destination=root/'assets/sources'/f'{category}_{source[:8]}.png'
 if p.exists():shutil.copy2(p,destination)
 else:p=destination
 a=np.asarray(Image.open(p)); ids,n=label(a[:,:,3]>50); components=[]
 for k,s in enumerate(find_objects(ids),1):
  if s and (ids[s]==k).sum()>300:
   b=[s[1].start,s[0].start,s[1].stop,s[0].stop]
   components.append(b)
 groups=[[] for _ in rows]
 for b in components:
  row=min(range(4),key=lambda r:abs((b[1]+b[3])/2-rows[r]));groups[row].append(b)
 for row,bs in enumerate(groups):
  bs.sort(key=lambda b:b[0])
  if columns==4 and len(bs)>4:
   grouped=[[] for _ in range(4)]
   for b in bs:
    col=min(range(4),key=lambda c:abs((b[0]+b[2])/2-(c+.5)*a.shape[1]/4));grouped[col].append(b)
   bs=[[min(b[0] for b in g),min(b[1] for b in g),max(b[2] for b in g),max(b[3] for b in g)] for g in grouped]
  assert len(bs)==columns,(category,row,bs)
  for col,b in enumerate(bs):
   i=row*columns+col;name=names[i];layer='object';solid=True
   if category=='structure':
    size=[128,192] if i<12 else ([128,16] if i<18 else [24,176]);layer='wall';solid=False
   else:
    width=fwidth[i] if category=='furniture' else (openingwidth[i] if category=='opening' else (kwidth[i] if category=='kitchen' else dwidth[i-16 if source.startswith('d719') else i]))
    if category=='decor' and source.startswith('d719'):width=dwidth[16+i]
    size=[width,round(width*(b[3]-b[1])/(b[2]-b[0]))]
    if category=='opening':layer='wall';solid=False
    if category=='decor':
     solid=i<3 or i==7 if source.startswith('4018') else i in [1,8,9,13]
     if name in ['plant_hanging','lamp_wall','light_cyan','painting_mountain','painting_whale','clock','mirror','shelf_books']:layer='wall'
     elif not solid:layer='surface'
    if category=='kitchen' and i in [8,9,10,11]:solid=False;layer='wall' if i in [10,11] else 'surface'
   bx=max(0,b[0]-2);by=max(0,b[1]-2);bw=min(a.shape[1],b[2]+2)-bx;bh=min(a.shape[0],b[3]+2)-by
   foot=[round(size[0]*.8),round(size[1]*.4)] if solid else [0,0]
   if name.startswith('bed_'):foot=[160,200]
   entries.append(dict(id=name,name=labels[i],category=category,source=f'{category}_{source[:8]}.png',source_bounds=[bx,by,bw,bh],size=size,footprint=foot,layer=layer,solid=solid,texture=f'res://assets/modules/{name}.png'))
for i,(name,cn) in enumerate(zip('oak pale_oak walnut herringbone ivory_tile slate_tile concrete marble terrazzo navy_carpet tatami metal_grid'.split(),'橡木地板 浅木地板 胡桃地板 人字拼木 象牙瓷砖 石板瓷砖 水泥地面 大理石 磨石地面 蓝色地毯 榻榻米 金属格地'.split())):
 entries.append(dict(id='floor_'+name,name=cn,category='floor',size=[64,64],footprint=[0,0],solid=False,layer='floor',texture=f'res://assets/floors/{name}.png'))
(root/'assets/catalog.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2))
for m in entries:
 if m['category']=='floor':continue
 text=f'''[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://module.gd" id="1"]\n\n[node name="{m['id']}" type="Node2D"]\nscript = ExtResource("1")\nmodule_id = "{m['id']}"\n'''
 (root/'scenes/modules'/f"{m['id']}.tscn").write_text(text)
print('Catalog:',len(entries),'real modules; standalone scenes:',len(entries)-12)
