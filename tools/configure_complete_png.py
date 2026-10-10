"""Configure whole-character atlas packing from the user's approved PNG sheet."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/character/v16"
OUT.mkdir(parents=True, exist_ok=True)
bands = [(0,248),(248,506),(506,742),(742,1024)]
anchors = [(135,243),(115,247),(127,229),(144,251)]
directions = ["down","left","up","right"]
idle_columns = [2,1,2,1]
data = {
    "method": "complete_png_normalized_user_selected",
    "canvas_size": [512,512], "ground": [256,420],
    "pixel_size": .0064, "walk_count": 6, "cycle_distance": .82,
    "note": "The approved complete 24-frame PNG remains the character artwork. Only whole-frame atlas extraction, uniform scale and a constant per-direction placement are applied. No joints, local deformation or body-part assembly.",
    "directions": {},
}
for index, direction in enumerate(directions):
    y0, y1 = bands[index]
    frames = [{"path":"res://art_source/用户选定_完整人物.png", "rect":[col*256,y0,256,y1-y0], "source_ground":list(anchors[index]), "source_scale":.0094/.0064} for col in range(6)]
    data["directions"][direction] = {"frames":frames, "sequence":list(range(6)), "idle":frames[idle_columns[index]]}
(OUT / "completeframes.json").write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding="utf-8")
print("COMPLETE_PNG_CONFIG_READY real_source_poses=24")
