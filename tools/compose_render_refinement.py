from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
previews = root / "预览"
font = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 24)
small = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 17)
canvas = Image.new("RGB", (1280, 914), "#142133")
draw = ImageDraw.Draw(canvas)
draw.text((20, 12), "修改前", font=font, fill="#f2efdf")
draw.text((660, 12), "本次强化后 · v22 实际渲染", font=font, fill="#f2efdf")
for row, (name, crop) in enumerate([
    ("医院", (120, 5, 760, 405)),
    ("公寓", (230, 150, 870, 550)),
]):
    y = 56 + row * 426
    for col, stage in enumerate(["修改前", "完成"]):
        picture = Image.open(previews / f"渲染强化_{stage}_{name}.png").convert("RGB")
        canvas.paste(picture.crop(crop), (col * 640, y))
    draw.text((16, y + 400), f"{name} · 相同镜头、日间光照，原始像素裁切", font=small, fill="#bed0de")
draw.line((639, 0, 639, 914), fill="#334958", width=2)
canvas.save(previews / "渲染强化_前后对照.png")

frames = [Image.open(previews / f"渲染强化_移动{i:02d}.png").convert("RGB") for i in range(12)]
# One shared palette avoids palette changes being mistaken for lighting flicker.
palette = frames[0].quantize(colors=256)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
frames[0].save(previews / "渲染强化_镜头移动.gif", save_all=True, append_images=frames[1:], duration=85, loop=0)
print(previews / "渲染强化_前后对照.png")
print(previews / "渲染强化_镜头移动.gif")
