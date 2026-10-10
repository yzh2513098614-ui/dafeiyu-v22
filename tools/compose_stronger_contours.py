from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json

root = Path(__file__).resolve().parent.parent
preview = root / "预览"
font = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 22)
small = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 17)
canvas = Image.new("RGB", (900, 938), "#142133")
draw = ImageDraw.Draw(canvas)
for column, stage in enumerate(["调整前", "加强后"]):
    draw.text((column * 450 + 12, 10), stage, font=font, fill="#f2efdf")
    normal = Image.open(preview / f"轮廓加强_{stage}_正常视角.png").convert("RGB")
    canvas.paste(normal.crop((415, 285, 565, 421)).resize((450, 408), Image.Resampling.NEAREST), (column * 450, 44))
    close = Image.open(preview / f"轮廓加强_{stage}_正面近景.png").convert("RGB")
    canvas.paste(close.crop((200, 80, 650, 530)), (column * 450, 482))
draw.text((12, 457), "正常游戏视角局部 ×3 · 最近邻放大，无锐化", font=small, fill="#bed0de")
draw.line((449, 0, 449, 938), fill="#334958", width=2)
canvas.save(preview / "轮廓加强_实机对比.png")

on = np.asarray(Image.open(preview / "轮廓加强_加强后_正面近景.png").convert("RGB"), dtype=int)
off = np.asarray(Image.open(preview / "轮廓加强_调整前_正面近景.png").convert("RGB"), dtype=int)
records = {}
for name, (x0, y0, x1, y1) in {
    "character": (265, 95, 431, 330),
    "cabinet": (447, 311, 555, 457),
    "cabinet_top": (489, 336, 519, 349),
}.items():
    diff = off[y0:y1, x0:x1] - on[y0:y1, x0:x1]
    changed = np.any(abs(diff) > 1, axis=2)
    records[name] = {"changed_pixels": int(changed.sum()), "max_rgb_darkening": int(diff.max()), "mean_darkening_changed": round(float(diff[changed].mean()), 2) if changed.any() else 0}
(preview / "轮廓加强_局部像素记录.json").write_text(json.dumps(records, indent=2), encoding="utf-8")
print(json.dumps(records))
