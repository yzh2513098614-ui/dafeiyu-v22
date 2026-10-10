"""Compose unretouched game screenshots into GIFs and package the v14 project."""
import argparse
import json
from pathlib import Path
import zipfile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "预览/人物步态_v14"
OUTPUT.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--preview-only", action="store_true", help="Compose real captures without creating a zip.")
args = parser.parse_args()
metadata_path = OUTPUT / "movement_capture.json"
if not metadata_path.is_file():
    raise SystemExit("Capture is missing. Run tools/capture_character.gd first.")
records = json.loads(metadata_path.read_text(encoding="utf-8"))["frames"]
directions = {"down": "向下行走", "left": "向左行走", "up": "向上行走", "right": "向右行走"}
all_frames = []
all_durations = []
for direction in directions:
    segment = [record for record in records if record["direction"] == direction]
    frames = []
    durations = []
    for index, record in enumerate(segment):
        with Image.open(OUTPUT / record["file"]) as source:
            frames.append(source.convert("RGB"))
        if index + 1 < len(segment):
            elapsed = segment[index + 1]["timestamp_ms"] - record["timestamp_ms"]
        else:
            elapsed = record["timestamp_ms"] - segment[index - 1]["timestamp_ms"] if index else 50
        # GIF stores centiseconds: preserve actual elapsed time without acceleration.
        durations.append(max(10, round(elapsed / 10) * 10))
    if not frames:
        raise SystemExit(f"Missing real movement frames: {direction}")
    frames[0].save(OUTPUT / f"{direction}_实机行走.gif", save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=2, optimize=False)
    all_frames.extend(frames)
    all_durations.extend(durations)
all_frames[0].save(OUTPUT / "四方向_实机行走.gif", save_all=True, append_images=all_frames[1:], duration=all_durations, loop=0, disposal=2, optimize=False)
font_path = ROOT / "assets/NotoSansSC.ttf"
font = ImageFont.truetype(str(font_path), 25)
title_font = ImageFont.truetype(str(font_path), 36)
sheet = Image.new("RGB", (1600, 1430), "#edf3ef")
draw = ImageDraw.Draw(sheet)
draw.text((32, 20), "人物步态 v14 · 实际游戏帧", font=title_font, fill="#2d475b")
for index, (direction, label) in enumerate(directions.items()):
    x, y = 24 + index % 2 * 790, 94 + index // 2 * 648
    draw.rounded_rectangle((x, y, x + 766, y + 625), radius=16, fill="white")
    with Image.open(OUTPUT / f"{direction}_行走.png") as source:
        picture = source.convert("RGB")
    picture.thumbnail((746, 560), Image.Resampling.LANCZOS)
    sheet.paste(picture, (x + (766 - picture.width) // 2, y + 12))
    draw.text((x + 18, y + 583), label, font=font, fill="#365568")
sheet.save(OUTPUT / "四方向实机总览.png")
print(f"REAL CAPTURE GIFS READY: directions={len(directions)}; frames={len(records)}")
if args.preview_only:
    raise SystemExit(0)
archive = ROOT.parent / "大肥鱼_指定人物图集_v14_完整工程.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if any(part in {".godot", ".git", "__pycache__"} for part in relative.parts):
            continue
        zipped.write(path, Path("大肥鱼_人物步态完成_v14") / relative)
print(f"ARCHIVE: {archive} ({archive.stat().st_size:,} bytes)")
