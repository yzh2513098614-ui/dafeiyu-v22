from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

out = Path(__file__).resolve().parent.parent / "预览"
font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 23)
canvas = Image.new("RGB", (1400, 484), "#182535")
draw = ImageDraw.Draw(canvas)
for col, version, title in [(0, "修正前", "修改前：阴影边缘发糊"), (1, "修正后", "修改后：轮廓清楚，投影更贴地")]:
    draw.text((col * 700 + 18, 10), title, font=font, fill="#f1eadd")
    screenshot = Image.open(out / f"光影_{version}_餐厅_日间.png").convert("RGB")
    canvas.paste(screenshot.crop((150, 280, 850, 720)), (col * 700, 44))
canvas.save(out / "光影_改善对照.png")

frames = []
for path in sorted(out.glob("光影_移动[0-9][0-9].png")):
    capture = Image.open(path).convert("RGB")
    frame = Image.new("RGB", (480, 396), "#182535")
    ImageDraw.Draw(frame).text((10, 6), "v22 实际镜头移动 · 阴影细节", font=font, fill="#f1eadd")
    frame.paste(capture, (0, 36))
    frames.append(frame)
palette = Image.new("RGB", (480, 396 * len(frames)))
for i, frame in enumerate(frames):
    palette.paste(frame, (0, i * 396))
palette = palette.quantize(colors=256)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
frames[0].save(out / "光影_镜头移动.gif", save_all=True, append_images=frames[1:] + frames[-2:0:-1], duration=90, loop=0, optimize=False)
print(out / "光影_改善对照.png")
