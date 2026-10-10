"""Build a contact sheet from real module renders and package the v12 project."""
import argparse
import json
import math
from pathlib import Path
import zipfile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
VERSION = "v12"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--sheet-only", action="store_true", help="Build preview without creating a zip.")
args = parser.parse_args()
modules = json.loads((ROOT / "assets/district/modules.json").read_text(encoding="utf-8"))
names = {kind: info["name"] if isinstance(info, dict) else str(info) for kind, info in modules.items()}
catalog = json.loads((ROOT / "assets/catalog.json").read_text(encoding="utf-8"))
output = ROOT / "预览/街区_v12"
output.mkdir(parents=True, exist_ok=True)
font_path = ROOT / "assets/NotoSansSC.ttf"
font = ImageFont.truetype(str(font_path), 23)
title_font = ImageFont.truetype(str(font_path), 36)
sheet = Image.new("RGB", (1200, 140 + math.ceil(len(names) / 4) * 292 + 24), "#eff3ef")
draw = ImageDraw.Draw(sheet)
draw.text((36, 24), "鲸落港 · 同风格街区素材 v12", font=title_font, fill="#2d475b")
draw.text((39, 83), f"{len(names)} 个可复用场景 / 透明 PNG / 素材宝箱共 {len(catalog)} 项", font=font, fill="#6d838b")
for index, (kind, name) in enumerate(names.items()):
    x, y = 24 + index % 4 * 294, 140 + index // 4 * 292
    draw.rounded_rectangle((x, y, x + 278, y + 274), radius=18, fill="white")
    with Image.open(ROOT / "assets/district" / f"{kind}.png") as source:
        image = source.convert("RGBA")
    image.thumbnail((250, 225), Image.Resampling.LANCZOS)
    sheet.paste(image, (x + (278 - image.width) // 2, y + 4), image)
    draw.text((x + 16, y + 236), name, font=font, fill="#365568")
preview = output / "街区素材总览.png"
sheet.save(preview)
print(f"Preview: {preview}; modules={len(names)}; catalog={len(catalog)}")
if args.sheet_only:
    raise SystemExit(0)
archive = ROOT.parent / f"大肥鱼_鲸落港街区_{VERSION}_完整工程.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if any(part in {".godot", ".git", "__pycache__"} for part in relative.parts):
            continue
        zipped.write(path, Path(f"大肥鱼_鲸落港街区_{VERSION}") / relative)
print(f"Archive: {archive} ({archive.stat().st_size:,} bytes)")
