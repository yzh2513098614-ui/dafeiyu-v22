# -*- coding: utf-8 -*-
"""完美度审计（只读）：找产物中「不透明且 min(r,g,b)>=253」的封闭连通块。
外背景实测纯白 253~255，服饰白 247~252 —— 达到 253+ 的不透明像素理论上只可能是：
  1) 眼睛高光（受保护，脸部半径内跳过并标注）
  2) 漏网背景白（要清的）
  3) 偶然达到 253 的饰物点（人工审）
输出每块 bbox 至 tools/perfect_audit.json，同时拼「暗底全景」复核图。
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/dialogue/downloaded_20261014/transparent"
REPORT = ROOT / "tools/perfect_audit.json"
PLATE_DIR = ROOT / "预览/立绘缝隙白三类复核/阶段六_全图暗底"
DARKBG = (110, 100, 90)
MN_T = 253
MIN_SIZE = 8
CONN4 = ndimage.generate_binary_structure(2, 1)

NAMES = ["01_listen", "02_kiss", "03_talk", "04_think", "05_relief", "06_shy",
         "07_expectant", "08_cheer", "09_happy", "10_concern", "11_side_welcome"]

# 脸部保护圈：眼睛高光坐标来自交接文档（阶段二/四眼睛探针）
FACE_GUARDS = {
    "03_talk": (573, 394), "04_think": (572, 346), "01_listen": (517, 364),
    "08_cheer": (732, 422), "09_happy": (754, 387),
}


def near_face(cx, cy, fx, fy, r=160):
    return fx is not None and fy is not None and ((cx - fx) ** 2 + (cy - fy) ** 2) <= r * r


def audit(name: str) -> dict:
    path = OUT / (name + ".png")
    img = np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)
    h, w = img.shape[:2]
    rgb = img[..., :3].astype(np.int32)
    alpha = img[..., 3]
    mn = rgb.min(axis=2)
    pure = (alpha >= 250) & (mn >= MN_T)
    labels, n = ndimage.label(pure, CONN4)
    if n == 0:
        return {"size": (w, h), "blocks": [], "pure_opaque_total": 0}
    sizes = np.bincount(labels.ravel(), minlength=n + 1)
    blocks = []
    for i in range(1, n + 1):
        if sizes[i] < MIN_SIZE:
            continue
        ys, xs = np.nonzero(labels == i)
        cx, cy = float(xs.mean()), float(ys.mean())
        vals = mn[ys, xs]
        blocks.append({
            "comp_id": int(i), "size": int(sizes[i]),
            "bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
            "cx": round(cx), "cy": round(cy),
            "near_face": near_face(cx, cy, *(FACE_GUARDS.get(name) or (None, None))),
            "mn_max": int(vals.max()),
        })
    blocks.sort(key=lambda b: -b["size"])
    total = int(pure.sum())
    print(f"{name}: pure_opaque_total={total} blocks(size>={MIN_SIZE})={len(blocks)}", flush=True)
    for b in blocks[:10]:
        tag = " [face]" if b["near_face"] else ""
        print(f"   comp {b['comp_id']:>4} size={b['size']:>6} bbox={b['bbox']}{tag}", flush=True)
    # 全景暗底图（缩到宽 620 方便整图过目）
    dark = Image.new("RGBA", (w, h), DARKBG + (255,))
    dark.alpha_composite(Image.fromarray(img))
    dark = dark.convert("RGB").resize((620, round(h * 620 / w)), Image.LANCZOS)
    dark.save(PLATE_DIR / f"{name}_暗底全景.png")
    return {"size": [w, h], "blocks": blocks, "pure_opaque_total": total}


def main() -> None:
    only = sys.argv[1:] or NAMES
    PLATE_DIR.mkdir(parents=True, exist_ok=True)
    out = {n: audit(n) for n in only}
    REPORT.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print("AUDIT DONE", flush=True)


if __name__ == "__main__":
    main()
