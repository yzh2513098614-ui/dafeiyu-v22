# -*- coding: utf-8 -*-
"""白底对话立绘重抠（Python 离线版，算法与 tools/rebake_dialogue_portraits.gd 对齐并增强）。

病因与对策（与 GDScript 版一致）：
A  抠像残留：白底与白衣同色（250~252），纯阈值分不开。
   → 从画布四边泛洪判定背景（白衣被描边封住、不触边，天然安全）；
     轮廓按曼哈顿距离内缩 ERODE 像素 + 1px 羽化，吃掉抗锯齿过渡带。
A2 发丝缝隙白：发丝深色描边把白底切成大量「不触边」的封闭白连通域，
   泛洪进不去；腐蚀只能吃掉 <=4px 的窄缝，宽缝中心 alpha=255 留在画面上。
   → 对每个封闭白连通域算「域内到非候选的曼哈顿距离」峰值（=内切半径），
   缝隙白块窄（<=GAP_MAX_D）整体并入背景，白衣服块宽则保留。
B  线性过滤白边：透明像素 RGB 残留白色，缩略采样时插值出亮白边。
   → alpha bleed：核心色向外填 BLEED 像素，透明区不再有白色可供插值。

用法：
  python rebake_portraits.py            # 全量 11 张
  python rebake_portraits.py 09_happy   # 只处理一张
产物直接写回 assets/dialogue/downloaded_20261014/transparent/，Godot 下次加载
检测到 mtime 变化会重新导入。
"""
import json
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent          # 项目根（tools/ 的上一级）
SRC = ROOT / "assets/dialogue/downloaded_20261014"
OUT = SRC / "transparent"
REPORT = ROOT / "tools/rebake_portraits.json"
BACKUP_OLD = ROOT / "备份/20261014_立绘缝隙白优化前_transparent"

NAMES = ["01_listen", "02_kiss", "03_talk", "04_think", "05_relief", "06_shy",
         "07_expectant", "08_cheer", "09_happy", "10_concern", "11_side_welcome"]

WHITE_MIN = 246    # min(r,g,b) 达到此值才可能是背景白
ERODE = 2          # 轮廓内缩像素数（曼哈顿距离），吃掉过渡带
FEATHER = 1        # 内缩后的 alpha 羽化宽度
OPAQUE_AT = ERODE + FEATHER + 1
BLEED = 4          # 核心色外扩像素数，消灭线性过滤白边
GAP_MAX_D = 6      # 封闭白连通域内切半径上限（cdt 单位，= GDScript max_d+1）

CONN4 = ndimage.generate_binary_structure(2, 1)  # 4 连通


def metrics(path: Path) -> dict:
    """量三个指标：残留白块、轮廓白边、透明区白 RGB（与 GDScript 版对齐）。"""
    if not path.exists():
        return {}
    a = np.asarray(Image.open(path).convert("RGBA"), dtype=np.uint8)
    rgb = a[..., :3].astype(np.int16)
    alpha = a[..., 3]
    mn = rgb.min(axis=2)
    clear_nearwhite = int(((alpha == 0) & (mn >= 245)).sum())
    opaque_nearwhite = int(((alpha >= 250) & (mn >= 235)).sum())
    opaque = (alpha >= 250) & (mn >= 225)
    a0 = alpha == 0
    touch = np.zeros_like(opaque)
    touch[:, :-1] |= a0[:, 1:]
    touch[:, 1:] |= a0[:, :-1]
    touch[:-1, :] |= a0[1:, :]
    touch[1:, :] |= a0[:-1, :]
    rim_light = int((opaque & touch).sum())
    return {"opaque_nearwhite": opaque_nearwhite, "rim_light": rim_light,
            "clear_nearwhite": clear_nearwhite}


def bake(name: str) -> dict:
    t0 = time.time()
    src_path = SRC / (name + ".png")
    out_path = OUT / (name + ".png")
    rec: dict = {"file": name + ".png", "before": metrics(out_path)}
    img = Image.open(src_path).convert("RGBA")
    rgba = np.asarray(img, dtype=np.uint8)
    h, w = rgba.shape[:2]
    rgb = rgba[..., :3].astype(np.uint16)

    # ---------- 1. 白色候选 ----------
    white = rgb.min(axis=2) >= WHITE_MIN

    # ---------- 2. 四边泛洪：与边框连通的白色才是背景 ----------
    labels, n_dom = ndimage.label(white, structure=CONN4)
    border_ids = np.unique(np.concatenate([labels[0, :], labels[-1, :],
                                           labels[:, 0], labels[:, -1]]))
    border_ids = border_ids[border_ids != 0]
    bg = np.isin(labels, border_ids) if border_ids.size else np.zeros_like(white)
    del labels

    # ---------- 2.5 封闭白缝：内切半径小的封闭白连通域也是背景 ----------
    gap = white & ~bg
    gap_dt = ndimage.distance_transform_cdt(gap, metric="taxicab")
    g_labels, g_n = ndimage.label(gap, structure=CONN4)
    if g_n:
        peak = np.zeros(g_n + 1, dtype=np.int32)
        np.maximum.at(peak, g_labels, gap_dt)
        narrow_ids = np.nonzero(peak <= GAP_MAX_D)[0]
        narrow_ids = narrow_ids[narrow_ids != 0]
        cleared = int(gap_dt[np.isin(g_labels, narrow_ids)].size) if narrow_ids.size else 0
        if narrow_ids.size:
            bg |= np.isin(g_labels, narrow_ids)
        kept = int(gap.sum()) - cleared
    else:
        cleared, kept = 0, 0
    del gap, gap_dt, g_labels

    # ---------- 3/4. 距离场内缩 + 羽化 ----------
    fg = ~bg
    dist = ndimage.distance_transform_cdt(fg, metric="taxicab")  # 前景到背景步数
    alpha = np.zeros((h, w), dtype=np.uint8)
    solid = dist >= OPAQUE_AT
    alpha[solid] = 255
    band = (dist > ERODE) & ~solid
    alpha[band] = np.round(255.0 * (dist[band] - ERODE) / (FEATHER + 1)).astype(np.uint8)
    core = solid  # bleed 源

    # ---------- 5. alpha bleed：核心色外填 BLEED 像素 ----------
    core_dt = ndimage.distance_transform_cdt(~core, metric="taxicab")
    _, indices = ndimage.distance_transform_edt(~core, return_indices=True)
    ring = (core_dt >= 1) & (core_dt <= BLEED)
    ys, xs = np.nonzero(ring)
    rgb[ys, xs] = rgb[indices[0][ys, xs], indices[1][ys, xs]]

    out = np.dstack([rgb.astype(np.uint8), alpha])
    Image.fromarray(out, "RGBA").save(out_path)

    rec.update(size=[w, h], background=int(bg.sum()),
               enclosed_white_cleared=cleared, enclosed_white_kept=kept,
               seconds=round(time.time() - t0, 2), after=metrics(out_path))
    print(f"REBAKE {name} bg={rec['background']} cleared_gap={cleared} "
          f"kept_white={kept} {rec['seconds']}s after={rec['after']}", flush=True)
    return rec


def compare_plate(name: str) -> Path:
    """旧产物 vs 新产物：发丝区域裁剪放大并排，便于人工验收。"""
    old_path = BACKUP_OLD / (name + ".png")
    new_path = OUT / (name + ".png")
    old = Image.open(old_path).convert("RGBA")
    new = Image.open(new_path).convert("RGBA")
    w, h = old.size
    # 代表性裁剪区：左侧发簇、右侧发簇、头饰（按 1086x1400 原图经验坐标）
    regions = [(0.02, 0.16, 0.30, 0.52), (0.66, 0.16, 0.98, 0.52), (0.28, 0.00, 0.72, 0.20)]
    tiles = []
    for i, (x0, y0, x1, y1) in enumerate(regions):
        box = (int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h))
        # 透明底叠到游戏场景近似底色上，白残留无所遁形
        for img in (old, new):
            pass
        tiles.append((old.crop(box), new.crop(box), i))
    rows = []
    for old_c, new_c, i in tiles:
        scale = 2
        ow, oh = old_c.size
        row = Image.new("RGBA", (ow * scale * 2 + 12, oh * scale), (120, 108, 96, 255))
        row.alpha_composite(old_c.resize((ow * scale, oh * scale), Image.NEAREST), (0, 0))
        row.alpha_composite(new_c.resize((ow * scale, oh * scale), Image.NEAREST),
                            (ow * scale + 12, 0))
        rows.append(row)
    gap_h = 10
    plate = Image.new("RGBA", (max(r.width for r in rows),
                               sum(r.height for r in rows) + gap_h * (len(rows) - 1)),
                      (90, 90, 90, 255))
    y = 0
    for r in rows:
        plate.alpha_composite(r, (0, y))
        y += r.height + gap_h
    plate_path = ROOT / "预览/立绘缝隙白对比" / (name + "_对比.png")
    plate_path.parent.mkdir(parents=True, exist_ok=True)
    plate.convert("RGB").save(plate_path)
    return plate_path


def main() -> None:
    only = sys.argv[1:] or NAMES
    OUT.mkdir(parents=True, exist_ok=True)
    records = [bake(n) for n in only]
    REPORT.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
    for n in only:
        if (BACKUP_OLD / (n + ".png")).exists():
            print("PLATE", compare_plate(n), flush=True)
    print("REBAKE DONE", len(records), flush=True)


if __name__ == "__main__":
    main()
