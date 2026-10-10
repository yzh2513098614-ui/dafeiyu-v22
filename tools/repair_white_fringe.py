"""Remove video-matte fringe around the silhouette and newly cleared holes.

The earlier hole pass removed flat studio islands, but left 1-3 pixels of pale
compositing colour around their edges. This pass trims only the newly opened
holes, then decontaminates RGB at both kinds of transparent boundary.
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
MANIFEST = ROOT / "assets/character/manifest.json"
OUTPUT = ROOT / "assets/character/jimeng_v23"


def clean(rgba: np.ndarray, old_alpha: np.ndarray) -> tuple[np.ndarray, dict]:
    result = rgba.copy()
    # v21 -> v22 is the precise record of which transparent pixels were newly
    # opened in hair and between legs. Limit alpha changes to a narrow ring
    # around those openings; white lace elsewhere must not be damaged.
    new_holes = (old_alpha >= 128) & (result[:, :, 3] == 0)
    if new_holes.any():
        distance_from_hole = ndi.distance_transform_edt(~new_holes)
        inner_rim = (result[:, :, 3] > 0) & (distance_from_hole <= 4.6)
        result[:, :, 3][inner_rim] = 0
    else:
        inner_rim = np.zeros(result.shape[:2], bool)
        distance_from_hole = np.full(result.shape[:2], np.inf)
    rgb = result[:, :, :3].astype(np.int16)
    foreground = result[:, :, 3] >= 128
    distance_in = ndi.distance_transform_edt(foreground)
    deep = foreground & (distance_in >= 4.0)
    if not deep.any():
        return result, {"inner_rim_removed": int(inner_rim.sum()),
                        "recolored": 0, "transparent_rgb_filled": 0}
    _, near_deep = ndi.distance_transform_edt(~deep, return_indices=True)
    interior = rgb[near_deep[0], near_deep[1]]
    # The colour immediately behind an internal gap can still be a pale matte
    # strand. Reach further into the blue hair or leg before choosing colour.
    far_deep = foreground & (distance_in >= 9.0)
    _, near_far = ndi.distance_transform_edt(~far_deep, return_indices=True)
    far_interior = rgb[near_far[0], near_far[1]]
    yy, xx = np.ogrid[:rgba.shape[0], :rgba.shape[1]]
    hair_gap = (((xx < 355) | (xx > 670)) & (yy >= 480) & (yy <= 750))
    leg_gap = (xx >= 482) & (xx <= 542) & (yy >= 875) & (yy <= 1050)
    curl = (xx >= 400) & (xx <= 690) & (yy <= 190)
    interior = np.where((hair_gap | leg_gap | curl)[:, :, None], far_interior, interior)
    pale = (rgb.min(2) >= 207) & ((rgb.max(2) - rgb.min(2)) <= 30)
    studio = np.linalg.norm(rgb - np.array([241, 240, 243]), axis=2) < 38
    luma = rgb.astype(np.float32) @ np.array([.2126, .7152, .0722], np.float32)
    inner_luma = interior.astype(np.float32) @ np.array([.2126, .7152, .0722], np.float32)
    colour_difference = np.linalg.norm(rgb - interior, axis=2)
    suspicious = foreground & (distance_in <= 3.2) & pale & studio & ((luma - inner_luma > 26) | (colour_difference > 42))
    result[:, :, :3][suspicious] = interior[suspicious].astype(np.uint8)

    # A few lavender pixels remain after the alpha trim. They are visibly
    # pale against the dark hair yet fall outside the near-neutral studio
    # test above. Recolour only the immediate rim of a recorded hair opening.
    hair_zone = (((xx < 400) | (xx > 620)) & (yy >= 380) & (yy <= 760))
    far_luma = far_interior.astype(np.float32) @ np.array([.2126, .7152, .0722], np.float32)
    hair_halo = (foreground & (distance_in <= 1.5) &
                 (distance_from_hole <= 8.0) & hair_zone &
                 (rgb.min(2) >= 175) & (luma - far_luma > 25))
    result[:, :, :3][hair_halo] = far_interior[hair_halo].astype(np.uint8)

    # Alpha-zero pixels newly opened inside hair and between legs still store
    # the studio RGB. Bilinear sampling reads those colours unless they are
    # extended from the repaired foreground edge.
    clear = result[:, :, 3] == 0
    distance_out, near_edge = ndi.distance_transform_edt(clear, return_indices=True)
    nearby_clear = clear & (distance_out <= 4.0)
    edge_rgb = result[:, :, :3][near_edge[0], near_edge[1]]
    result[:, :, :3][nearby_clear] = edge_rgb[nearby_clear]
    return result, {"inner_rim_removed": int(inner_rim.sum()),
                    "recolored": int((suspicious | hair_halo).sum()),
                    "transparent_rgb_filled": int(nearby_clear.sum())}


def main() -> None:
    apply = "--apply" in sys.argv
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if "white_fringe_source_manifest" in manifest:
        source = ROOT / manifest["white_fringe_source_manifest"].removeprefix("res://")
        manifest = json.loads(source.read_text(encoding="utf-8"))
    if apply:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        (OUTPUT / "source_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    mapped: dict[str, str] = {}
    report: list[dict] = []
    for direction in manifest["atlas_order"]:
        for source in manifest["frames_by_state"]["walk"][direction]:
            if source in mapped:
                continue
            source_path = ROOT / source.removeprefix("res://")
            target = OUTPUT / direction / source_path.name
            mapped[source] = "res://" + target.relative_to(ROOT).as_posix()
            if manifest["provenance"][direction] != "video":
                if apply:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source_path, target)
                continue
            rgba = np.array(Image.open(source_path).convert("RGBA"))
            old_file = ROOT / "assets/character/jimeng_v21" / direction / source_path.name
            old_alpha = np.array(Image.open(old_file).convert("RGBA"))[:, :, 3]
            repaired, counts = clean(rgba, old_alpha)
            report.append({"direction": direction, "frame": source_path.name, **counts})
            if apply:
                target.parent.mkdir(parents=True, exist_ok=True)
                Image.fromarray(repaired, "RGBA").save(target)
    summary: dict[str, dict] = {}
    for direction in manifest["atlas_order"]:
        rows = [row for row in report if row["direction"] == direction]
        summary[direction] = {"frames": len(rows),
                              "inner_rim_removed": sum(row["inner_rim_removed"] for row in rows),
                              "recolored": sum(row["recolored"] for row in rows),
                              "transparent_rgb_filled": sum(row["transparent_rgb_filled"] for row in rows)}
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if not apply:
        print("DRY RUN: no assets or manifest changed")
        return
    next_manifest = json.loads(json.dumps(manifest))
    for state in next_manifest["frames_by_state"].values():
        for direction, frames in state.items():
            state[direction] = [mapped[source] for source in frames]
    next_manifest["version"] = 8
    next_manifest["method"] = "complete_png_inner_and_outer_video_matte_repair"
    next_manifest["white_fringe_source_manifest"] = "res://assets/character/jimeng_v23/source_manifest.json"
    next_manifest["white_fringe"] = "Trim 4.6px around newly cleared studio holes, decontaminate opaque edge colours and transparent RGB bleed"
    (OUTPUT / "white_fringe_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    MANIFEST.write_text(json.dumps(next_manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Published repaired frames and manifest v8")


if __name__ == "__main__":
    main()
