"""Arrange real Godot thumbnail renders into twelve labeled catalog sheets. Requires Pillow."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
r=Path(__file__).resolve().parents[1];p=r.parent
data=json.loads((r/'catalog.json').read_text())
font=ImageFont.truetype(str(r/'assets/NotoSansSC.ttf'),22)
heading=ImageFont.truetype(str(r/'assets/NotoSansSC.ttf'),35)
font.set_variation_by_axes([500]);heading.set_variation_by_axes([650])
categories={'safes':'保险盒与保管柜','storage':'收纳与储物','living':'现代生活家具','restaurant':'餐厅与厨房','utility':'生活设备与科技','decor':'灯具与装饰','retail':'零售与商店','lab':'实验室器材','medical':'医疗与护理','logistics':'仓储与维修','lounge':'公共休闲家具','architecture':'建筑模块'}
for cat,title in categories.items():
 sheet=Image.new('RGB',(1400,1050),'#e9eff4');draw=ImageDraw.Draw(sheet)
 draw.rectangle((0,0,1400,98),fill='#233c5c')
 draw.text((32,20),'大肥鱼 · '+title+' / 12件真实3D模型',font=heading,fill='#f8f4e9')
 for i,entry in enumerate(x for x in data if x['category']==cat):
  x=22+(i%4)*344;y=120+(i//4)*298
  draw.rounded_rectangle((x,y,x+325,y+278),12,fill='#fbfcfd',outline='#a8bccf',width=2)
  img=Image.open(r/'assets/thumbnails'/f"{entry['id']}.png").convert('RGBA')
  bbox=img.getchannel('A').getbbox()
  if bbox:img=img.crop(bbox)
  img.thumbnail((278,210),Image.Resampling.LANCZOS)
  sheet.paste(img,(x+(325-img.width)//2,y+12+(212-img.height)//2),img)
  text=entry['name'];box=draw.textbbox((0,0),text,font=font)
  draw.text((x+(325-(box[2]-box[0]))//2,y+233),text,font=font,fill='#304b6d')
  if entry['moving']:draw.text((x+18,y+12),'可开合',font=font,fill='#2d8e9a')
 (p/'预览').mkdir(exist_ok=True)
 sheet.save(p/'预览'/(title+'_12件.png'))
print('Twelve sheets from actual Godot renders saved')
