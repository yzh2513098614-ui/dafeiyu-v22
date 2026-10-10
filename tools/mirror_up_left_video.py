"""Lossless horizontal mirror of the complete up-left video sprites into up-right."""
from copy import deepcopy
from pathlib import Path
import hashlib
import json

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "assets/character/up_right_mirror_20261010"
REVIEW = ROOT / "预览/右上镜像替换_20261010"


def main():
    manifest_path = ROOT / "assets/character/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    before = deepcopy(manifest)
    backup = ROOT / "备份/20261010_右上镜像替换前"
    backup.mkdir(parents=True, exist_ok=True)
    (backup / ".gdignore").touch()
    if not (backup / "manifest.json").exists():
        (backup / "manifest.json").write_bytes(manifest_path.read_bytes())
    assert float(manifest["ground"][0]) == float(manifest["frame_size"][0])/2, "Mirror requires a centred ground anchor"
    TARGET.mkdir(parents=True, exist_ok=True)
    (TARGET / "masks").mkdir(exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    (REVIEW / ".gdignore").touch()
    mirrored_paths, records, pictures = {}, [], []
    for entry in manifest["frames_by_state"]["walk"]["up_left"]:
        resource = entry["path"] if isinstance(entry, dict) else entry
        if resource in mirrored_paths:
            continue
        source = ROOT / resource.removeprefix("res://")
        image = Image.open(source).convert("RGBA")
        mirrored = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        destination = TARGET / source.name
        mirrored.save(destination)
        source_mask = source.parent / "masks" / source.name
        mask = Image.open(source_mask).convert("L").transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        mask.save(TARGET / "masks" / source.name)
        original_pixels = np.asarray(image)
        result = np.asarray(mirrored)
        assert np.array_equal(result, original_pixels[:, ::-1]), "RGBA mirror changed source pixels"
        assert np.array_equal(result[:, :, 3], np.asarray(mask)), "Alpha and fixed mask differ"
        assert image.size == mirrored.size == (1024, 1152), "Native canvas size changed"
        mirrored_resource = "res://"+destination.relative_to(ROOT).as_posix()
        mirrored_paths[resource] = mirrored_resource
        records.append({"source": resource, "result": mirrored_resource,
                        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                        "rgba_exact_horizontal_flip": True, "alpha_mask_exact": True})
        crop = mirrored.crop((244, 450, 744, 1120))
        frame = Image.new("RGBA", crop.size, "#617d88")
        frame.alpha_composite(crop)
        pictures.append(frame.convert("RGB"))

    for state in ["idle", "walk", "interact"]:
        entries = []
        for entry in manifest["frames_by_state"][state]["up_left"]:
            if isinstance(entry, dict):
                new = deepcopy(entry)
                new["path"] = mirrored_paths[entry["path"]]
                entries.append(new)
            else:
                entries.append(mirrored_paths[entry])
        manifest["frames_by_state"][state]["up_right"] = entries
    profile = deepcopy(manifest["surface_profiles_by_direction"]["up_left"])
    for region in ["head", "body", "tail", "face"]:
        profile[region][0] = 1-profile[region][0]
    manifest["surface_profiles_by_direction"]["up_right"] = profile
    # Pigment matching is colour-only; the mirror shares the same palette.
    if "up_left" in manifest.get("palette_match_by_direction", {}):
        manifest["palette_match_by_direction"]["up_right"] = deepcopy(manifest["palette_match_by_direction"]["up_left"])
    manifest["pixel_size_by_direction"]["up_right"] = manifest["pixel_size_by_direction"]["up_left"]
    manifest["walk_fps_by_direction"]["up_right"] = manifest["walk_fps_by_direction"]["up_left"]
    manifest["frame_counts_by_direction"]["up_right"] = len(manifest["frames_by_state"]["walk"]["up_right"])
    manifest["video_extraction_by_direction"]["up_right"] = "res://assets/character/up_right_mirror_20261010/extraction.json"
    manifest["provenance"]["up_right"] = "exact native RGBA horizontal mirror of user upLeft.mp4 video frames"
    manifest.setdefault("mirrored_directions", {})["up_right"] = "up_left"
    manifest.get("generated_source_sequences", {}).pop("up_right", None)
    manifest["version"] = max(int(manifest.get("version", 10)), 11)
    for state in before["frames_by_state"]:
        for direction in before["atlas_order"]:
            if direction != "up_right":
                assert manifest["frames_by_state"][state][direction] == before["frames_by_state"][state][direction]
    info = {"direction": "up_right", "mirrored_from": "up_left", "loop_frame_count": len(records),
            "canvas_size": [1024, 1152], "ground": manifest["ground"],
            "pixel_size": manifest["pixel_size_by_direction"]["up_right"],
            "source_fps": manifest["walk_fps_by_direction"]["up_right"],
            "method": "exact horizontal pixel permutation; no resampling or rematting",
            "surface_profile": profile, "records": records}
    (TARGET / "extraction.json").write_text(json.dumps(info, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    fps = info["source_fps"]
    pictures[0].save(REVIEW / "up_right_walk.gif", save_all=True, append_images=pictures[1:],
                     duration=[round(1000/fps)]*len(pictures), loop=0, disposal=2)
    print("INSTALLED up_right:", len(records), "native-size mirrored RGBA frames and masks; standing and lighting regions matched")


if __name__ == "__main__":
    main()
