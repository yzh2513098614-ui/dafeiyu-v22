"""Compose actual fixed-tick game captures and package the complete PNG v16 project."""
import argparse
import json
from pathlib import Path
import shutil
import zipfile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "预览/完整图片人物_v16"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--preview-only", action="store_true", help="Compose screenshots without creating a zip.")
args = parser.parse_args()
metadata_path = OUTPUT / "movement_capture.json"
if not metadata_path.is_file():
    raise SystemExit("Capture is missing. Run tools/capture_redrawn_character.gd first.")
metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
records = metadata["frames"]
groups = {
    "down": "向下行走",
    "left": "向左行走",
    "up": "向上行走",
    "right": "向右行走",
    "停止再起步": "停止再起步",
    "堵墙停步": "持续推墙后停步",
}
all_frames = []
all_durations = []
report = {}
for group, label in groups.items():
    segment = [record for record in records if record["group"] == group]
    if not segment:
        raise SystemExit(f"Missing real movement frames: {group}")
    pictures = []
    durations = []
    # Timestamps describe the real 60 Hz game simulation; file I/O was paused.
    for index, record in enumerate(segment):
        with Image.open(OUTPUT / record["file"]) as source:
            pictures.append(source.convert("RGB"))
        elapsed = segment[index + 1]["timestamp_ms"] - record["timestamp_ms"] if index + 1 < len(segment) else segment[index]["timestamp_ms"] - segment[index - 1]["timestamp_ms"]
        durations.append(max(10, round(elapsed / 10) * 10))
    filename = f"{group}_实机行走.gif" if group in {"down", "left", "up", "right"} else f"{group}_实机.gif"
    pictures[0].save(OUTPUT / filename, save_all=True, append_images=pictures[1:], duration=durations, loop=0, disposal=2, optimize=False)
    if group in {"down", "left", "up", "right"}:
        all_frames.extend(pictures)
        all_durations.extend(durations)
    start, end = segment[0]["position"], segment[-1]["position"]
    distance = ((end[0] - start[0]) ** 2 + (end[2] - start[2]) ** 2) ** .5
    report[group] = {"frames": len(segment), "duration_ms": sum(durations), "distance_first_to_last": round(distance, 4), "states": sorted({record["animation"] for record in segment}), "source": metadata["source"]}
all_frames[0].save(OUTPUT / "四方向_实机行走.gif", save_all=True, append_images=all_frames[1:], duration=all_durations, loop=0, disposal=2, optimize=False)
(OUTPUT / "预览来源与时序.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
font_path = ROOT / "assets/NotoSansSC.ttf"
font = ImageFont.truetype(str(font_path), 26)
title_font = ImageFont.truetype(str(font_path), 38)
sheet = Image.new("RGB", (1600, 1420), "#edf3ef")
draw = ImageDraw.Draw(sheet)
draw.text((32, 20), "完整图片人物 v16 · 游戏实际画面", font=title_font, fill="#2d475b")
for index, (direction, label) in enumerate(list(groups.items())[:4]):
    x, y = 24 + index % 2 * 790, 94 + index // 2 * 646
    draw.rounded_rectangle((x, y, x + 766, y + 622), radius=16, fill="white")
    with Image.open(OUTPUT / f"{direction}_行走.png") as source:
        picture = source.convert("RGB")
    picture.thumbnail((746, 560), Image.Resampling.LANCZOS)
    sheet.paste(picture, (x + (766 - picture.width) // 2, y + 12))
    draw.text((x + 18, y + 580), label, font=font, fill="#365568")
sheet.save(OUTPUT / "四方向实机总览.png")
print(f"REAL_CAPTURE_GIFS_READY groups={len(groups)} frames={len(records)}")
if args.preview_only:
    raise SystemExit(0)

EXCLUDE_EXACT = {
    "assets/character/body_parts.png",
    "assets/character/leg_parts.png",
    "assets/character/walk_atlas_v14.png",
    "assets/character/idle_atlas_v14.png",
    "assets/character/interact_atlas_v14.png",
    "tools/bake_character.gd",
    "tools/bake_character_v15.gd",
    "tools/capture_character.gd",
    "tools/package_character.py",
    "tools/select_user_character.py",
    "tools/finalize_selected_character.py",
    "character/character_paper_rig.gd",
    "assets/character/v15/parts_manifest.json",
    "assets/character/v15/legs_landmarks.json",
    "assets/character/v15/pose_metadata.json",
    "00_人物步态完成使用说明.md",
    "00_人物动作重绘使用说明.md",
}

def include(relative: Path) -> bool:
    parts = relative.parts
    name = relative.name
    posix = relative.as_posix()
    base_posix = posix.removesuffix(".import").removesuffix(".uid")
    if any(part in {".godot", ".git", "__pycache__"} for part in parts):
        return False
    if relative.suffix.lower() in {".log", ".tmp", ".zip", ".pyc"}:
        return False
    if base_posix in EXCLUDE_EXACT or name.startswith("项目文件清单"):
        return False
    if posix.startswith("assets/character/v15/review_frames/"):
        return False
    if base_posix in {"assets/character/v15/walk_atlas.png", "assets/character/v15/idle_atlas.png"} and "res://" + base_posix not in manifest_text:
        return False
    if parts[0] == "预览":
        if len(parts) < 2 or parts[1] not in {"完整图片人物_v16", "连续大地图_v13"}:
            return False
        if len(parts) > 2 and parts[2] == "序列":
            return False
    if parts[0] == "art_source":
        return len(parts) > 1 and parts[1] in {"用户选定_完整人物.png", "房间风格参考.png", "用户选定_完整人物.png.import", "房间风格参考.png.import"}
    return True

# Verify current sprite manifests do not point to known excluded failed assets.
manifest_path = ROOT / "assets/character/manifest.json"
manifest_text = manifest_path.read_text(encoding="utf-8")
method = str(json.loads(manifest_text).get("method", "")).lower()
if method != "complete_png_normalized_user_selected":
    raise SystemExit("Final character manifest has not switched to the approved complete PNG normalized frames.")
for excluded in EXCLUDE_EXACT:
    if "res://" + excluded in manifest_text:
        raise SystemExit(f"Current manifest still depends on an excluded old asset: {excluded}")

required = {
    "project.godot",
    "district/continuous_world.tscn",
    "district/continuous_world.gd",
    "room_3d.gd",
    "assets/character/manifest.json",
}

def manifest_paths(value):
    if isinstance(value, dict):
        for item in value.values():
            yield from manifest_paths(item)
    elif isinstance(value, list):
        for item in value:
            yield from manifest_paths(item)
    elif isinstance(value, str) and value.startswith("res://"):
        yield value.removeprefix("res://")

required.update(manifest_paths(json.loads(manifest_text)))
for relative in sorted(required):
    path = ROOT / relative
    if not path.exists() or (path.is_file() and not include(Path(relative))):
        raise SystemExit(f"Final package would miss a required resource: {relative}")

archive = ROOT.parent / "大肥鱼_完整图片人物_v16_完整工程.zip"
delivery_root = ROOT.parent / "大肥鱼_完整图片人物_v16"
delivery_root.mkdir(parents=True, exist_ok=True)
if delivery_root.resolve().parent != ROOT.parent.resolve() or delivery_root.resolve() == ROOT.resolve():
    raise SystemExit("Invalid delivery directory.")
files = []
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
    for path in sorted(ROOT.rglob("*")):
        if path.is_file() and include(path.relative_to(ROOT)):
            relative = path.relative_to(ROOT)
            destination = delivery_root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination)
            zipped.write(path, Path("大肥鱼_完整图片人物_v16") / relative)
            files.append(relative.as_posix())
with zipfile.ZipFile(archive) as zipped:
    error = zipped.testzip()
    if error:
        raise SystemExit(f"Archive CRC failure: {error}")
print(f"ARCHIVE_READY {archive} bytes={archive.stat().st_size:,} files={len(files)} CRC=ok")
print(f"PROJECT_READY {delivery_root} files={len(files)}")
