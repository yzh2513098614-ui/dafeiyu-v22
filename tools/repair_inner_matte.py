"""Remove studio-background islands trapped inside whole-character video frames.

The source PNGs remain untouched.  The published frames preserve RGB and only
change alpha for flat, neutral holes surrounded by hair or between the shoes.
Run without --apply to inspect the selected regions first.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent / "video_runtime"))
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/character/jimeng_v22"
MANIFEST = ROOT / "assets/character/manifest.json"


def selected_islands(rgba: np.ndarray) -> tuple[np.ndarray, list[dict]]:
    rgb = rgba[:, :, :3].astype(np.int16)
    alpha = rgba[:, :, 3]
    neutral = rgb.max(2) - rgb.min(2)
    candidate = (alpha >= 200) & (rgb.min(2) >= 229) & (neutral <= 12)
    labels, _ = ndi.label(candidate)
    selected = np.zeros(candidate.shape, bool)
    records: list[dict] = []

    for label, bounds in enumerate(ndi.find_objects(labels), 1):
        if bounds is None:
            continue
        local = labels[bounds] == label
        area = int(local.sum())
        if area < 120:
            continue
        y0, y1 = bounds[0].start, bounds[0].stop
        x0, x1 = bounds[1].start, bounds[1].stop
        height, width = y1 - y0, x1 - x0
        center_x, center_y = (x0 + x1) * .5, (y0 + y1) * .5
        pixels = rgb[bounds][local]
        mean = pixels.mean(0)
        spread = pixels.std(0).max()
        if mean.min() < 235 or spread > 5:
            continue

        kind = ""
        ring_blue = 0.0
        if (150 < center_x < 400 or 620 < center_x < 875) and 385 < center_y < 690 and height >= 25 and width >= 10:
            # A real opening is surrounded by blue hair; the pale ears and
            # maid lace have much less blue in their immediate perimeter.
            margin = 4
            region = (slice(max(0, y0-margin), min(rgba.shape[0], y1+margin)),
                      slice(max(0, x0-margin), min(rgba.shape[1], x1+margin)))
            component = labels[region] == label
            ring = ndi.binary_dilation(component, iterations=3) & ~ndi.binary_dilation(component, iterations=1)
            colors = rgb[region][ring]
            if len(colors):
                ring_blue = float(np.mean((colors[:, 2] - colors[:, 0] > 24) & (colors[:, 2] - colors[:, 1] > 8)))
            if ring_blue >= .62:
                kind = "hair_opening"
        elif 430 < center_x < 595 and 875 < center_y < 1055 and height >= 48 and width <= 55 and area >= 300 and spread <= 4:
            # The studio gap between the legs is tall and nearly uniform.
            # White socks are wider, shorter and slightly lavender.
            kind = "leg_gap"

        if not kind:
            continue
        selected[bounds] |= local
        records.append({"kind": kind, "box": [x0, y0, x1, y1], "pixels": area,
                        "mean_rgb": [round(float(c), 1) for c in mean],
                        "ring_blue": round(ring_blue, 2)})

    # Take one faint matte pixel around each hole without cutting into the
    # surrounding blue line art, skin, socks or white clothing.
    fringe = ndi.binary_dilation(selected, iterations=1) & (rgb.min(2) >= 225) & (neutral <= 16)
    return fringe, records


def main() -> None:
    apply = "--apply" in sys.argv
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if "inner_matte_source_manifest" in manifest:
        manifest = json.loads((ROOT / manifest["inner_matte_source_manifest"].removeprefix("res://")).read_text(encoding="utf-8"))
    mapped: dict[str, str] = {}
    report: list[dict] = []
    if apply:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        (OUTPUT / "source_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    for direction in manifest["atlas_order"]:
        for source in manifest["frames_by_state"]["walk"][direction]:
            if source in mapped:
                continue
            source_file = ROOT / source.removeprefix("res://")
            target = OUTPUT / direction / source_file.name
            mapped[source] = "res://" + target.relative_to(ROOT).as_posix()
            if manifest["provenance"][direction] != "video":
                if apply:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source_file, target)
                continue
            rgba = np.array(Image.open(source_file).convert("RGBA"))
            hole, islands = selected_islands(rgba)
            report.append({"direction": direction, "frame": source_file.name,
                           "removed_pixels": int(hole.sum()), "islands": islands})
            if apply:
                target.parent.mkdir(parents=True, exist_ok=True)
                rgba[:, :, 3][hole] = 0
                Image.fromarray(rgba, "RGBA").save(target)

    by_direction = {direction: {"frames": 0, "hair": 0, "legs": 0, "removed_pixels": 0}
                    for direction in manifest["atlas_order"]}
    for row in report:
        totals = by_direction[row["direction"]]
        totals["frames"] += 1
        totals["removed_pixels"] += row["removed_pixels"]
        totals["hair"] += sum(item["kind"] == "hair_opening" for item in row["islands"])
        totals["legs"] += sum(item["kind"] == "leg_gap" for item in row["islands"])
    print(json.dumps(by_direction, ensure_ascii=False, indent=2))
    if not apply:
        print("DRY RUN: no sprites or manifest changed")
        return

    next_manifest = json.loads(json.dumps(manifest))
    for state in next_manifest["frames_by_state"].values():
        for direction, frames in state.items():
            state[direction] = [mapped[source] for source in frames]
    next_manifest["version"] = 7
    next_manifest["method"] = "complete_png_inner_matte_repair"
    next_manifest["inner_matte_source_manifest"] = "res://assets/character/jimeng_v22/source_manifest.json"
    next_manifest["inner_matte"] = "Video-source neutral hair openings and leg gaps only; RGB and all generated directions unchanged"
    (OUTPUT / "inner_matte_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    MANIFEST.write_text(json.dumps(next_manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Published cleaned video frames and manifest v7")


if __name__ == "__main__":
    main()
