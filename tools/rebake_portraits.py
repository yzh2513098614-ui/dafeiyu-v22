# -*- coding: utf-8 -*-
"""白底对话立绘重抠（Python 离线版，算法与 tools/rebake_dialogue_portraits.gd 对齐并增强）。

病因与对策（与 GDScript 版一致）：
A  抠像残留：白底与白衣同色（250~252），纯阈值分不开。
   → 从画布四边泛洪判定背景（白衣被描边封住、不触边，天然安全）；
     轮廓按曼哈顿距离内缩 ERODE 像素 + 1px 羽化，吃掉抗锯齿过渡带。
A2 发丝缝隙白：发丝深色描边把白底切成大量「不触边」的封闭白连通域，
   泛洪进不去；腐蚀只能吃掉 <=4px 的窄缝，宽缝中心 alpha=255 留在画面上。
   → 透底缝隙 = 与外背景同色（min 通道 >=BG_T）且深藏于人物内部（到外背景
   >=DEPTH_MIN px）的封闭白域；服饰白/发丝高光色值低于背景、贴轮廓的纯白
   部件深度不足，均天然排除。内切半径判据已实测废弃（两方向都误判）。
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
BG_T = 253         # 外背景实测 min 通道 253~255；服饰白与发丝高光为 247~252
BGCOL_FRAC = 0.5   # 封闭白域内达到背景色的像素占比下限
RING_DARK_MIN = 0.35  # 域外邻环深色(线稿)占比下限；服饰高光点的邻环是自身浅色阴影
OUTER_BLUE_MIN = 0.5  # 再外一环为发蓝的占比下限；缝隙藏在发块内，服饰高光藏在阴影内

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
    mn = rgb.min(axis=2)
    white = mn >= WHITE_MIN

    # ---------- 2. 四边泛洪：与边框连通的白色才是背景 ----------
    labels, n_dom = ndimage.label(white, structure=CONN4)
    border_ids = np.unique(np.concatenate([labels[0, :], labels[-1, :],
                                           labels[:, 0], labels[:, -1]]))
    border_ids = border_ids[border_ids != 0]
    bg = np.isin(labels, border_ids) if border_ids.size else np.zeros_like(white)
    del labels

    # ---------- 2.5 透底缝隙：与外背景同色、且深藏于人物内部的封闭白 ----------
    # 内切半径判据已实测废弃：缝隙白是大块泪滴、白服饰细件半径反而小，两方向都误判。
    gap = white & ~bg
    g_labels, g_n = ndimage.label(gap, structure=CONN4)
    if g_n:
        sizes = np.bincount(g_labels.ravel(), minlength=g_n + 1)
        bgcol_frac = np.zeros(g_n + 1)
        np.add.at(bgcol_frac, g_labels.ravel(), (mn >= BG_T).ravel())
        bgcol_frac[1:] /= np.maximum(sizes[1:], 1)
        depth = ndimage.distance_transform_cdt(~bg, metric="taxicab")
        min_depth = np.full(g_n + 1, 1 << 20, dtype=np.int32)
        np.minimum.at(min_depth, g_labels.ravel(), depth.ravel())
        sel = bgcol_frac >= BGCOL_FRAC
        sel[0] = False
        pre_ids = np.nonzero(sel)[0]
        dark = mn < 150
        sel_list = []
        for i in pre_ids:
            comp = g_labels == i
            ring = ndimage.binary_dilation(comp, structure=CONN4, iterations=2) & ~comp
            if not ring.any() or dark[ring].mean() < RING_DARK_MIN:
                continue
            oring = ndimage.binary_dilation(comp, structure=CONN4, iterations=6) & ~ring & ~comp
            if not oring.any():
                continue
            v = rgb[oring]
            blue = ((v[:, 2].astype(np.int32) - v[:, 0].astype(np.int32)) > 60).mean()
            if blue >= OUTER_BLUE_MIN:
                sel_list.append(i)
        sel_ids = np.asarray(sel_list, dtype=np.int64)
        cleared = int(sizes[sel_ids].sum()) if sel_ids.size else 0
        if sel_ids.size:
            bg |= np.isin(g_labels, sel_ids)
            print(f"  gap-domains cleared: {sel_ids.size} comps / {cleared}px "
                  f"(depth {int(min_depth[sel_ids].min())}~{int(min_depth[sel_ids].max())}px)",
                  flush=True)
        kept = int(gap.sum()) - cleared
    else:
        cleared, kept = 0, 0
    del gap, g_labels

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
