from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

project = Path(__file__).resolve().parents[1]
preview = project / '预览'
font = ImageFont.truetype(str(project / 'assets/NotoSansSC.ttf'), 18)
frames = []
for index in range(20):
    before = Image.open(preview / f'地砖_修正前_移动{index:02}.png').convert('RGB')
    after = Image.open(preview / f'地砖_修正后_移动{index:02}.png').convert('RGB')
    canvas = Image.new('RGB', (580, 246), '#f7f5e9')
    canvas.paste(before, (6, 32))
    canvas.paste(after, (294, 32))
    draw = ImageDraw.Draw(canvas)
    draw.text((10, 5), '修正前 · 细金属砖缝', font=font, fill='#33466e')
    draw.text((298, 5), '修正后 · 按像素过滤', font=font, fill='#33466e')
    frames.append(canvas)
sheet = Image.new('RGB', (580, 246 * len(frames)))
for index, frame in enumerate(frames):
    sheet.paste(frame, (0, 246 * index))
palette = sheet.quantize(colors=256, dither=Image.Dither.NONE)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
sequence = frames + frames[-2:0:-1]
sequence[0].save(preview / '地砖_移动前后对照.gif', save_all=True,
                 append_images=sequence[1:], duration=90, loop=0)
print('Saved camera-pan comparison')
