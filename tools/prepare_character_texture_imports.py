import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
backup = root / "备份/20261010_人物材质改善前/纹理导入"
manifest = json.loads((root / "assets/character/manifest.json").read_text(encoding="utf-8"))
paths = sorted({entry if isinstance(entry, str) else entry["path"]
                for state in manifest["frames_by_state"].values()
                for frames in state.values() for entry in frames})
records = []
for uri in paths:
    relative = Path(uri.removeprefix("res://"))
    image = root / relative
    imported = Path(str(image) + ".import")
    text = imported.read_text(encoding="utf-8")
    saved = backup / Path(str(relative) + ".import")
    saved.parent.mkdir(parents=True, exist_ok=True)
    saved.write_text(text, encoding="utf-8")
    # Preserve the native image and lossless import. Only add minification levels.
    text = text.replace("mipmaps/generate=false", "mipmaps/generate=true")
    text = text.replace("detect_3d/compress_to=1", "detect_3d/compress_to=0")
    imported.write_text(text, encoding="utf-8")
    records.append({"path": uri, "sha256": hashlib.sha256(image.read_bytes()).hexdigest()})
report = root / "预览/人物材质_原图记录.json"
report.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Prepared {len(records)} full-size, lossless character texture imports; PNGs untouched.")
