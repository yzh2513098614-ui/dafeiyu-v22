"""Package the v13 continuous world and compose actual preview renders."""
import argparse
import json
import math
from pathlib import Path
import zipfile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "预览/连续大地图_v13"
OUTPUT.mkdir(parents=True, exist_ok=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--preview-only", action="store_true", help="Compose existing renders without creating a zip.")
args = parser.parse_args()
modules = json.loads((ROOT / "assets/district/modules.json").read_text(encoding="utf-8"))
catalog = json.loads((ROOT / "assets/catalog.json").read_text(encoding="utf-8"))
font_path = ROOT / "assets/NotoSansSC.ttf"
font = ImageFont.truetype(str(font_path), 23)
title_font = ImageFont.truetype(str(font_path), 36)
sheet = Image.new("RGB", (1200, 164 + math.ceil(len(modules) / 4) * 292), "#eff3ef")
draw = ImageDraw.Draw(sheet)
draw.text((36, 24), "鲸落港 · 同材质部件 v13", font=title_font, fill="#2d475b")
draw.text((39, 83), f"{len(modules)} 个街区部件 / 素材宝箱共 {len(catalog)} 项", font=font, fill="#6d838b")
for index, (kind, info) in enumerate(modules.items()):
    x, y = 24 + index % 4 * 294, 140 + index // 4 * 292
    draw.rounded_rectangle((x, y, x + 278, y + 274), radius=18, fill="white")
    with Image.open(ROOT / "assets/district" / f"{kind}.png") as source:
        image = source.convert("RGBA")
    image.thumbnail((250, 225), Image.Resampling.LANCZOS)
    sheet.paste(image, (x + (278 - image.width) // 2, y + 4), image)
    draw.text((x + 16, y + 236), info["name"], font=font, fill="#365568")
sheet.save(OUTPUT / "同风格素材总览.png")
previews = [
    ("city_总览.png", "连续街区 · 12 栋建筑"),
    ("apt_2_总览.png", "云湾公寓 2F · 六房间与走廊"),
    ("community_1_总览.png", "潮汐社区馆 1F · 六个公共空间"),
    ("inn_2_总览.png", "海风旅舍 2F · 客房与共享空间"),
]
if all((OUTPUT / filename).is_file() for filename, _ in previews):
    overview = Image.new("RGB", (1600, 1410), "#edf3ef")
    drawing = ImageDraw.Draw(overview)
    drawing.text((34, 22), "大肥鱼 v13 · 实际游戏视图", font=title_font, fill="#2d475b")
    for index, (filename, label) in enumerate(previews):
        x, y = 24 + index % 2 * 790, 92 + index // 2 * 648
        drawing.rounded_rectangle((x, y, x + 766, y + 625), radius=16, fill="white")
        with Image.open(OUTPUT / filename) as source:
            picture = source.convert("RGB")
        picture.thumbnail((746, 560), Image.Resampling.LANCZOS)
        overview.paste(picture, (x + (766 - picture.width) // 2, y + 12))
        drawing.text((x + 18, y + 583), label, font=font, fill="#365568")
    overview.save(OUTPUT / "连续空间实景总览.png")
print(f"PREVIEWS READY: modules={len(modules)}; catalog={len(catalog)}")
if args.preview_only:
    raise SystemExit(0)
archive = ROOT.parent / "大肥鱼_连续大地图_v13_完整工程.zip"
with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zipped:
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(ROOT)
        if any(part in {".godot", ".git", "__pycache__"} for part in relative.parts):
            continue
        zipped.write(path, Path("大肥鱼_连续大地图_v13") / relative)
print(f"ARCHIVE: {archive} ({archive.stat().st_size:,} bytes)")
