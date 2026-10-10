"""Index the user's approved complete PNG without changing any image pixels."""
import json
import shutil
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "art_source/用户选定_完整人物.png"
destination = ROOT / "assets/character/selected_walk_sheet.png"
shutil.copy2(source, destination)
alpha = np.asarray(Image.open(source))[:, :, 3]
bands = [(0, 248), (248, 506), (506, 742), (742, 1024)]
foot_ranges = [(92, 172), (60, 156), (96, 145), (100, 202)]
axes = [135, 115, 127, 144]
regions, anchors = [], []
for row, (top, bottom) in enumerate(bands):
    row_regions, row_anchors = [], []
    lo, hi = foot_ranges[row]
    for col in range(6):
        x = col * 256
        foreground = (alpha[top:bottom, x + lo:x + hi] > 100).any(axis=1)
        sole = int(np.flatnonzero(foreground)[-1]) + 1
        row_regions.append([x, top, 256, bottom - top])
        row_anchors.append([axes[row], sole])
    regions.append(row_regions)
    anchors.append(row_anchors)
manifest = {
    "version": 2, "method": "user_selected_complete_sprite_sheet",
    "sheet": "res://assets/character/selected_walk_sheet.png",
    "original_file": source.name, "source_pixels": "copied byte-for-byte; no redraw or deformation",
    "frame_size": [256, 256], "canvas_size": [256, 256], "ground": [135, 243],
    "pixel_size": 0.0094, "cycle_distance": 0.82,
    "frame_counts": {"walk": 6, "idle": 1, "interact": 1},
    "atlas_order": ["down", "left", "up", "right"],
    "idle_columns": [2, 1, 2, 1], "regions": regions, "anchors": anchors,
    "note": "Use safe unequal row bands to retain the complete hair and feet; foot anchors are measured inside each body lane, excluding the tail."
}
(ROOT / "assets/character/manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print("SELECTED_USER_SHEET_READY: 24 frames, original PNG unchanged")
