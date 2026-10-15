# -*- coding: utf-8 -*-
"""阶段六逐块复核切片：每个被 fabric 闸门留下的候选块，产「左=白底原图(上下文) 右=当前产物(暗底)」
4x 最近邻放大并排板，输出 预览/立绘缝隙白三类复核/阶段六_逐块复核/。只读，不写产物。
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/dialogue/downloaded_20261014"
OUT = SRC / "transparent"
PROBE = json.loads((ROOT / "tools/stage6_probe.json").read_text(encoding="utf-8"))
PLATE_DIR = ROOT / "预览/立绘缝隙白三类复核/阶段六_逐块复核"
DARKBG = (110, 100, 90)
SCALE = 4
PAD = 28

for name, data in PROBE.items():
    blocked = [b for b in data["fabric_blocked"] if b["dist_bg_max"] >= 150]
    if not blocked:
        continue
    src = Image.open(SRC / (name + ".png")).convert("RGB")
    cur_rgba = np.asarray(Image.open(OUT / (name + ".png")).convert("RGBA"), dtype=np.uint8)
    cur = Image.fromarray(cur_rgba).copy()
    dark = Image.new("RGBA", cur.size, DARKBG + (255,))
    dark.alpha_composite(cur)
    dark = dark.convert("RGB")

    for b in blocked:
        x0, y0, x1, y1 = b["bbox"]
        box = (max(0, x0 - PAD), max(0, y0 - PAD), x1 + PAD, y1 + PAD)
        left = src.crop(box).resize(((box[2] - box[0]) * SCALE, (box[3] - box[1]) * SCALE), Image.NEAREST)
        right = dark.crop(box).resize(left.size, Image.NEAREST)
        d = ImageDraw.Draw(left)
        d.rectangle([ (x0 - box[0]) * SCALE - 1, (y0 - box[1]) * SCALE - 1,
                      (x1 - box[0]) * SCALE + 1, (y1 - box[1]) * SCALE + 1 ], outline=(255, 40, 40))
        gap = 10
        plate = Image.new("RGB", (left.width * 2 + gap, left.height + 26), (30, 30, 30))
        plate.paste(left, (0, 26)); plate.paste(right, (left.width + gap, 26))
        d2 = ImageDraw.Draw(plate)
        d2.text((6, 4), f"{name} comp{b['comp_id']} size={b['size']} diff={b['fabric_minus_bg']} "
                       f"nb={b['dist_bg_max']} bbox={b['bbox']}  [L: source w/ red box | R: product on dark]",
                fill=(240, 240, 240))
        out = PLATE_DIR / f"{name}_comp{b['comp_id']}.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        plate.save(out)
        print("PLATE", out.name, flush=True)
print("REVIEW PLATES DONE")
