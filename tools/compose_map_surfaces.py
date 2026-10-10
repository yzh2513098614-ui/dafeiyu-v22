from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
preview = root / "预览"
font = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 24)
small = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 18)
canvas = Image.new("RGB", (1280, 994), "#142133")
draw = ImageDraw.Draw(canvas)
draw.text((20, 12), "修改前", font=font, fill="#f2efdf")
draw.text((660, 12), "本次改善后 · v22 实机画面", font=font, fill="#f2efdf")
# Crop actual rendered pixels only; no exposure, color or sharpening adjustment.
for row, (tag, crop, caption) in enumerate([
    ("医院日间", (200, 220, 840, 630), "日间：墙边倒角、哑光涂层与环境受光"),
    ("医院灯具", (160, 100, 800, 510), "夜间：台灯朝下照射，减小桌面与墙面的亮斑"),
]):
    y = 56 + row * 464
    for column, stage in enumerate(["修改前", "改善后"]):
        source = Image.open(preview / f"地图材质_{stage}_{tag}.png").convert("RGB")
        canvas.paste(source.crop(crop), (column * 640, y))
    draw.text((16, y + 416), caption + " · 相同镜头原尺寸裁切", font=small, fill="#bed0de")
draw.line((639, 0, 639, 994), fill="#334958", width=2)
canvas.save(preview / "地图材质_前后对照.png")

frames = [Image.open(preview / f"地图材质_移动{i:02d}.png").convert("RGB") for i in range(8)]
palette = frames[0].quantize(colors=256)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
frames[0].save(preview / "地图材质_镜头移动.gif", save_all=True, append_images=frames[1:], duration=100, loop=0)
print(preview / "地图材质_前后对照.png")
