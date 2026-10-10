"""Install the packed whole-character images without any runtime rig."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/character/v16"
metadata = json.loads((DEST / "packing_metadata.json").read_text(encoding="utf-8"))
if metadata["method"] != "complete_png_normalized_user_selected":
    raise SystemExit("The completed atlas must use the approved whole-character PNG.")
w,h = metadata["canvas_size"]
count = metadata["frame_counts"]["walk"]
for name in ("walk_atlas.png","idle_atlas.png"):
    if not (DEST/name).is_file():
        raise SystemExit(f"Packed atlas is missing: {name}")
walk = [[[col*w,row*h,w,h] for col in range(count)] for row in range(4)]
idle = [[[0,row*h,w,h]] for row in range(4)]
manifest = {
    "version":4,"method":metadata["method"],
    "sheet":"res://assets/character/v16/walk_atlas.png",
    "sheet_by_state":{"walk":"res://assets/character/v16/walk_atlas.png","idle":"res://assets/character/v16/idle_atlas.png","interact":"res://assets/character/v16/idle_atlas.png"},
    "frame_size":[w,h],"canvas_size":[w,h],"ground":metadata["ground"],
    "pixel_size":metadata["pixel_size"],"cycle_distance":metadata["cycle_distance"],
    "frame_counts":{"walk":count,"idle":1,"interact":1},
    "atlas_order":metadata["atlas_order"],"idle_columns":[0,0,0,0],
    "regions":walk,"regions_by_state":{"idle":idle,"interact":idle},
    "source_manifest":"res://assets/character/v16/completeframes.json",
    "source_art":"res://art_source/用户选定_完整人物.png",
    "note":"Complete character pictures only; all textures now share one canvas and world pivot. New redraw drafts are not used.",
}
(ROOT/"assets/character/manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print("COMPLETE_PNG_INSTALLED direction_count=4 unique_walk_frames=24")
