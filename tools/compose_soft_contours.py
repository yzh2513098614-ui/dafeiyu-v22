from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
preview = root / "预览"
font = ImageFont.truetype(str(root / "assets/NotoSansSC.ttf"), 22)
canvas = Image.new("RGB", (860, 460), "#142133")
draw = ImageDraw.Draw(canvas)
for column, stage in enumerate(["修改前", "改善后"]):
    draw.text((column * 430 + 12, 10), stage + (" · 浅暗边稍加深" if column else ""), font=font, fill="#f2efdf")
    source = Image.open(preview / f"浅暗边_{stage}_正面近景.png").convert("RGB")
    canvas.paste(source.crop((220, 80, 650, 460)), (column * 430, 44))
draw.text((12, 427), "v22 实机 · 相同镜头，原尺寸裁切", font=font, fill="#bed0de")
draw.line((429, 0, 429, 460), fill="#334958", width=2)
canvas.save(preview / "浅暗边_人物物品对比.png")
