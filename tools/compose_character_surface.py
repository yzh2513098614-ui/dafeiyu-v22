import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
previews = root / "预览"
font = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 23)
small = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 17)
canvas = Image.new("RGB", (1120, 1070), "#142133")
draw = ImageDraw.Draw(canvas)
draw.text((20, 10), "修改前", font=font, fill="#f2efdf")
draw.text((580, 10), "本次改善后 · v22 实际人物", font=font, fill="#f2efdf")
for row, (name, crop, target) in enumerate([
    ("日间正面", (395, 160, 620, 460), (225, 300)),
    ("夜间台灯", (395, 160, 620, 460), (225, 300)),
]):
    y = 54 + row * 338
    for col, stage in enumerate(["修改前", "改善后"]):
        picture = Image.open(previews / f"人物材质_{stage}_{name}.png").convert("RGB")
        # Native screenshot pixels: no sharpening or retouching of the comparison.
        canvas.paste(picture.crop(crop), (col * 560 + 18, y))
        detail = picture.crop((436, 211, 569, 311)).resize((266, 200), Image.Resampling.NEAREST)
        canvas.paste(detail, (col * 560 + 270, y + 25))
        draw.text((col * 560 + 275, y + 232), "细节 2× 像素放大", font=small, fill="#bed0de")
    draw.text((18, y + 301), f"{name} · 相同镜头、姿势与光源", font=small, fill="#bed0de")

draw.text((18, 737), "常用视角 · 4× 像素放大，查看远景纹理", font=small, fill="#bed0de")
for col, stage in enumerate(["修改前", "改善后"]):
    picture = Image.open(previews / f"人物材质_{stage}_常用视角.png").convert("RGB")
    detail = picture.crop((468, 324, 532, 398)).resize((256, 296), Image.Resampling.NEAREST)
    canvas.paste(detail, (col * 560 + 152, 770))
draw.line((559, 0, 559, 1070), fill="#334958", width=2)
canvas.save(previews / "人物材质_前后对照.png")

frames = [Image.open(previews / f"人物材质_移动{i:02d}.png").convert("RGB") for i in range(12)]
palette = frames[0].quantize(colors=256)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
frames[0].save(previews / "人物材质_镜头移动.gif", save_all=True, append_images=frames[1:], duration=90, loop=0)

records = json.loads((previews / "人物材质_原图记录.json").read_text(encoding="utf-8"))
changed = []
for record in records:
    path = root / record["path"].removeprefix("res://")
    if hashlib.sha256(path.read_bytes()).hexdigest() != record["sha256"]:
        changed.append(record["path"])
    imported = Path(str(path) + ".import").read_text(encoding="utf-8")
    assert "compress/mode=0" in imported
    assert "mipmaps/generate=true" in imported
    assert "process/size_limit=0" in imported
    with Image.open(path) as original:
        assert original.size == (1024, 1152)
assert not changed, changed
print(f"Verified {len(records)} unchanged 1024x1152 PNGs; lossless imports with mipmaps.")
print(previews / "人物材质_前后对照.png")
