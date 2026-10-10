from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
import json

ROOT = Path(r'D:\迅雷下载\大肥鱼_像素立绘对话_v19')
SOURCE = ROOT / 'art_source' / 'jimeng_20261001'
OUT = ROOT / '预览' / '视频八方向_v20'
OUT.mkdir(parents=True, exist_ok=True)

groups = {
    'down': list(range(1, 74, 6)),
    'down_left': list(range(97, 158, 6)),
    'left': list(range(169, 236, 6)),
    'up': list(range(241, 308, 6)),
    'right': list(range(313, 452, 12)),
    'down_right': list(range(457, 576, 10)),
}
for name, indices in groups.items():
    tile_w, tile_h = 200, 286
    cols = 6
    rows = (len(indices) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * tile_w, rows * tile_h), '#d8d8d8')
    draw = ImageDraw.Draw(sheet)
    for slot, idx in enumerate(indices):
        p = SOURCE / f'frame_{idx:04d}.png'
        if not p.exists():
            continue
        im = Image.open(p).convert('RGB')
        thumb = im.copy()
        thumb.thumbnail((tile_w, tile_h - 20))
        x, y = (slot % cols) * tile_w, (slot // cols) * tile_h
        sheet.paste(thumb, (x, y + 20))
        draw.text((x + 4, y + 3), f'{idx:04d}  t={(idx - 1) / 24:.2f}s', fill='black')
    sheet.save(OUT / f'review_{name}.png')

# Read-only loop matching compares appearance, weighting lower limbs more highly.
windows = {
    'down': (1, 88),
    'down_left': (102, 159),
    'left': (173, 231),
    'up': (249, 308),
    'right': (325, 453),
    'down_right': (491, 575),
}
scores = {}
for name, (first, last) in windows.items():
    arrays = {}
    for i in range(first, last + 1):
        p = SOURCE / f'frame_{i:04d}.png'
        if not p.exists():
            continue
        a = np.asarray(Image.open(p).convert('RGB').resize((104, 139)), dtype=np.float32) / 255
        arrays[i] = a
    matches = []
    for i, a in arrays.items():
        for period in range(24, 41):
            j = i + period
            if j not in arrays:
                continue
            b = arrays[j]
            feet = np.mean(abs(a[100:] - b[100:]))
            body = np.mean(abs(a - b))
            matches.append({'start': i, 'end_exclusive': j, 'period': period,
                            'score': float(0.7 * feet + 0.3 * body),
                            'feet': float(feet), 'body': float(body)})
    matches.sort(key=lambda x: x['score'])
    scores[name] = matches[:10]
(OUT / 'review_loop_matches.json').write_text(json.dumps(scores, indent=2), encoding='utf-8')
print(json.dumps(scores, indent=2))

selected = {'down':(1,25),'down_left':(111,135),'left':(174,207),
            'up':(262,286),'right':(417,443),'down_right':(502,526)}
for name, (first,last) in selected.items():
    indices = list(range(first,last+1,2))
    cols=7
    tile_w,tile_h=190,155
    sheet=Image.new('RGB',(cols*tile_w,((len(indices)+cols-1)//cols)*tile_h),'#ccc')
    draw=ImageDraw.Draw(sheet)
    for slot,idx in enumerate(indices):
        im=Image.open(SOURCE/f'frame_{idx:04d}.png').convert('RGB')
        feet=im.crop((180,730,700,1110))
        feet.thumbnail((tile_w,tile_h-20))
        x,y=(slot%cols)*tile_w,(slot//cols)*tile_h
        sheet.paste(feet,(x,y+20))
        draw.text((x+3,y+3),f'{idx}',fill='black')
    sheet.save(OUT/f'feet_{name}.png')
