from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json

root = Path(__file__).resolve().parent.parent
preview = root / "预览"
font = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 22)
small = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 17)
canvas = Image.new("RGB", (1000, 500), "#142133")
draw = ImageDraw.Draw(canvas)
for column, (stage, label) in enumerate([
    ("诊断", "修改前：顶边、背景也被灰晕覆盖"),
    ("改善后", "现在：顶边清晰，背光侧保留浅暗边"),
]):
    draw.text((column * 500 + 12, 12), label, font=font, fill="#f2efdf")
    source = Image.open(preview / f"边缘渲染_{stage}_近景.png").convert("RGB")
    # Identical actual camera, crop only. No color correction or sharpening.
    canvas.paste(source.crop((300, 240, 800, 650)), (column * 500, 52))
draw.text((14, 470), "v22 实机原尺寸裁切 · 相同镜头与光照", font=small, fill="#bed0de")
draw.line((499, 0, 499, 500), fill="#334958", width=2)
canvas.save(preview / "边缘渲染_前后对照.png")

records = []
regions = {
    "柜子顶面": (489, 336, 519, 349),
    "柜子正面": (464, 375, 509, 411),
    "柜子右侧": (528, 367, 541, 415),
    "柜顶外侧背景": (473, 312, 505, 319),
}
for tag, disabled in [
    ("近景", "关闭定向暗边"),
    ("反向光照", "反向光照_关闭暗边"),
]:
    enabled_img = Image.open(preview / f"边缘渲染_改善后_{tag}.png").convert("RGB")
    disabled_img = Image.open(preview / f"边缘渲染_改善后_{disabled}.png").convert("RGB")
    for name, region in regions.items():
        on = np.asarray(enabled_img.crop(region), dtype=float)
        off = np.asarray(disabled_img.crop(region), dtype=float)
        records.append({"光照": tag, "采样区": name, "平均压暗RGB": round(float((off - on).mean()), 3)})
(preview / "边缘渲染_受光面记录.json").write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(records, ensure_ascii=False))

frames = [Image.open(preview / f"边缘渲染_改善后_移动{i:02d}.png").crop((300, 240, 800, 650)).convert("RGB") for i in range(6)]
palette = frames[0].quantize(colors=256)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
frames[0].save(preview / "边缘渲染_镜头移动.gif", save_all=True, append_images=frames[1:], duration=160, loop=0)
