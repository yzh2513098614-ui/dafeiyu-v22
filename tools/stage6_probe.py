# -*- coding: utf-8 -*-
"""阶段六探测：只读枚举被 S2_FABRIC_BG_MAX=0.15 拦下的候选白块（真发缝 vs 服饰亮部难分档）。

与 rebake_portraits.py 完全同参同判据重放选择逻辑，但：
1. 不写任何产物；
2. 额外把「唯一被 fabric 判据拦下」的候选（diff >= 0.15）连同 metadata 一起输出，
   供人工逐块视觉审核后下显式坐标掩膜。
用法：
  python tools/stage6_probe.py                 # 全量 11 张
  python tools/stage6_probe.py 09_happy        # 只探一张
输出：tools/stage6_probe.json
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets/dialogue/downloaded_20261014"
OUT = SRC / "transparent"
REPORT = ROOT / "tools/stage6_probe.json"

NAMES = ["01_listen", "02_kiss", "03_talk", "04_think", "05_relief", "06_shy",
         "07_expectant", "08_cheer", "09_happy", "10_concern", "11_side_welcome"]

WHITE_MIN = 246
BG_T = 253
BGCOL_FRAC = 0.5
RING_DARK_MIN = 0.35
S2_RING_DARK_MIN = 0.35
OUTER_BLUE_MIN = 0.5
S2_OUTER_BLUE_MIN = 0.5
EYE_GUARD_AREA = 400
SKIN_MIN = 0.02
SKIN_TIGHT_MIN = 0.05
S2_FABRIC_BG_MAX = 0.15
S2_FABRIC_BG_MAX_PROBE = 0.30   # 探测时把这道闸抬到 0.30，收「仅被 fabric 拦下」的块
S2_FABRIC_NB_MIN = 150
S2_Y_MAX = 1200
GAP_MIN_AREA = 20
S3_HAIRFAR_MIN = 0.25
S3_NB_MIN = 100
CONN4 = ndimage.generate_binary_structure(2, 1)


def probe(name: str) -> list:
    src_path = SRC / (name + ".png")
    img = Image.open(src_path).convert("RGBA")
    rgba = np.asarray(img, dtype=np.uint8)
    h, w = rgba.shape[:2]
    rgb = rgba[..., :3].astype(np.uint16)

    mn = rgb.min(axis=2)
    white = mn >= WHITE_MIN
    labels, n_dom = ndimage.label(white, structure=CONN4)
    border_ids = np.unique(np.concatenate([labels[0, :], labels[-1, :],
                                           labels[:, 0], labels[:, -1]]))
    border_ids = border_ids[border_ids != 0]
    bg = np.isin(labels, border_ids) if border_ids.size else np.zeros_like(white)
    del labels

    gap = white & ~bg
    g_labels, g_n = ndimage.label(gap, structure=CONN4)
    found = []
    if g_n:
        sizes = np.bincount(g_labels.ravel(), minlength=g_n + 1)
        bgcol_frac = np.zeros(g_n + 1)
        np.add.at(bgcol_frac, g_labels.ravel(), (mn >= BG_T).ravel())
        bgcol_frac[1:] /= np.maximum(sizes[1:], 1)
        dark = mn < 150
        r_, g_, b_ = rgb[..., 0].astype(np.int32), rgb[..., 1].astype(np.int32), rgb[..., 2].astype(np.int32)
        skin = (r_ > b_ + 20) & (r_ > 170) & (g_ > b_)
        hairb = (b_ - r_ > 60) & (b_ > 150) & (b_ < 235) & (g_ < b_ - 15)
        fabric_band = (mn >= 240) & (mn < BG_T)
        bg_band = mn >= BG_T
        dist_bg = ndimage.distance_transform_cdt(~bg, metric="taxicab")

        for i in range(1, g_n + 1):
            stage1 = bgcol_frac[i] >= BGCOL_FRAC
            if not stage1 and sizes[i] < GAP_MIN_AREA:
                continue
            comp = g_labels == i
            ring = ndimage.binary_dilation(comp, structure=CONN4, iterations=2) & ~comp
            if not ring.any() or dark[ring].mean() < (RING_DARK_MIN if stage1 else S2_RING_DARK_MIN):
                continue
            oring = ndimage.binary_dilation(comp, structure=CONN4, iterations=6) & ~ring & ~comp
            if not oring.any():
                continue
            v = rgb[oring]
            blue = ((v[:, 2].astype(np.int32) - v[:, 0].astype(np.int32)) > 60).mean()
            if blue < (OUTER_BLUE_MIN if stage1 else S2_OUTER_BLUE_MIN):
                continue
            if sizes[i] < EYE_GUARD_AREA:
                tight = ndimage.binary_dilation(comp, structure=CONN4, iterations=14) & ~oring & ~comp
                guard = ndimage.binary_dilation(comp, structure=CONN4, iterations=26) & ~oring & ~comp
                if (tight.any() and skin[tight].mean() >= SKIN_TIGHT_MIN) or \
                   (guard.any() and skin[guard].mean() >= SKIN_MIN):
                    continue
            if not stage1:
                band = ndimage.binary_dilation(comp, structure=CONN4, iterations=16) & ~oring
                diff = None
                if band.any():
                    diff = fabric_band[band].mean() - bg_band[band].mean()
                    # 先按阶段五原始逻辑过一遍 fabric 闸门（闸门本身：diff>=0.15 且 nb>=150 → 保留）
                    if diff >= S2_FABRIC_BG_MAX and dist_bg[comp].max() >= S2_FABRIC_NB_MIN:
                        ys, xs = np.nonzero(comp)
                        found.append({
                            "comp_id": int(i), "size": int(sizes[i]), "stage": 2,
                            "bgcol_frac": round(float(bgcol_frac[i]), 3),
                            "ring_dark": round(float(dark[ring].mean()), 3),
                            "outer_blue": round(float(blue), 3),
                            "fabric_minus_bg": round(float(diff), 3),
                            "dist_bg_max": int(dist_bg[comp].max()),
                            "bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
                            "cy": round(float(ndimage.center_of_mass(comp)[0]), 1),
                            "kind": "fabric_blocked",
                        })
                        continue        # 阶段五就是这样把它留下来的，探测到此为止
                cy = ndimage.center_of_mass(comp)[0]
                if cy > S2_Y_MAX:
                    continue
                near4 = ndimage.binary_dilation(comp, structure=CONN4, iterations=4) & ~comp
                far12 = ndimage.binary_dilation(comp, structure=CONN4, iterations=12) & ~near4 & ~comp
                hf = None
                if far12.any():
                    hf = float(hairb[far12].mean())
                if hf is not None and hf < S3_HAIRFAR_MIN and dist_bg[comp].max() >= S3_NB_MIN:
                    continue
                # 走到这里 = 该块在阶段五判据下本来会被清（diff < 0.15→放行）
                kind = "clears_anyway" if diff is None or diff < S2_FABRIC_BG_MAX else "fabric_blocked"
                ys, xs = np.nonzero(comp)
                found.append({
                    "comp_id": int(i), "size": int(sizes[i]), "stage": 1 if stage1 else 2,
                    "bgcol_frac": round(float(bgcol_frac[i]), 3),
                    "ring_dark": round(float(dark[ring].mean()), 3),
                    "outer_blue": round(float(blue), 3),
                    "fabric_minus_bg": None if diff is None else round(float(diff), 3),
                    "hairfar": None if hf is None else round(hf, 3),
                    "dist_bg_max": int(dist_bg[comp].max()),
                    "bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
                    "cy": round(float(cy), 1),
                    "kind": kind,
                })
    return found


def main() -> None:
    only = sys.argv[1:] or NAMES
    result = {}
    for n in only:
        blocks = probe(n)
        blocked = [b for b in blocks if b["kind"] == "fabric_blocked"]
        anyway = [b for b in blocks if b["kind"] == "clears_anyway"]
        result[n] = {"fabric_blocked": blocked, "clears_anyway": len(anyway)}
        print(f"{n}: fabric_blocked={len(blocked)} clears_anyway={len(anyway)}", flush=True)
        for b in blocked:
            print(f"   comp {b['comp_id']:>4} size={b['size']:>6} diff={b['fabric_minus_bg']} "
                  f"nb={b['dist_bg_max']} bbox={b['bbox']}", flush=True)
    REPORT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print("PROBE DONE", flush=True)


if __name__ == "__main__":
    main()
