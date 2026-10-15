"""Build the offline sticker UI sample from current project assets."""
from base64 import b64encode
from html.parser import HTMLParser
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
OUTPUT = HERE / "dist" / "index.html"
ITEM_IDS = [
    "token_cracker", "sea_biscuit", "retry_tea", "first_aid",
    "lemon_water", "sea_soup", "prompt_pen", "tide_compass",
    "fish_badge", "context_note", "sea_shell", "soft_linen",
]
ASSETS = {
    "font": "assets/fonts/misans/MiSans-Bold.ttf",
    "mascot": "assets/ui/whale_mascot.png",
    "portrait": "assets/dialogue/downloaded_20261014/transparent/01_listen.png",
    "happy": "assets/dialogue/downloaded_20261014/transparent/09_happy.png",
    "think": "assets/dialogue/downloaded_20261014/transparent/04_think.png",
    "talk": "assets/dialogue/downloaded_20261014/transparent/03_talk.png",
    "shy": "assets/dialogue/downloaded_20261014/transparent/06_shy.png",
    "harbor": "assets/start/harbor_background.png",
}
asset_manifest = []
encoded_cache = {}


def data_url(relative):
    if relative in encoded_cache:
        return encoded_cache[relative]
    source = PROJECT / relative
    content = source.read_bytes()
    mime = {".png": "image/png", ".svg": "image/svg+xml", ".ttf": "font/ttf"}[source.suffix]
    encoded = f"data:{mime};base64,{b64encode(content).decode('ascii')}"
    encoded_cache[relative] = encoded
    asset_manifest.append({"source": relative, "bytes": len(content)})
    return encoded


class PageAudit(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.images = 0
    def handle_starttag(self, tag, attrs):
        props = dict(attrs)
        if "id" in props:
            if props["id"] in self.ids:
                raise ValueError(f"Duplicate id: {props['id']}")
            self.ids.add(props["id"])
        if tag == "img":
            self.images += 1
            assert props["src"].startswith("data:image/"), "Image is not embedded"


def main():
    definitions = json.loads((PROJECT / "assets/meme_items.json").read_text(encoding="utf-8-sig"))
    balance = json.loads((PROJECT / "assets/character_balance.json").read_text(encoding="utf-8-sig"))
    items = []
    for item_id in ITEM_IDS:
        definition = definitions[item_id]
        rules = balance["items"].get(item_id, {})
        action = rules.get("action", "inspect")
        category = {"consume": "supplies", "equip": "tools", "read": "stories", "material": "materials"}.get(action, "stories")
        items.append({
            "id": item_id, "name": definition["name"], "kind": definition["kind"],
            "description": definition["description"], "quote": definition["quote"],
            "use": definition["use"], "action": action, "category": category,
            "effects": rules.get("effects", {}), "equipmentSlot": rules.get("slot", ""),
            "summary": rules.get("summary", definition["kind"]),
            "icon": data_url(definition["icon_path"].removeprefix("res://")),
        })
    assets = {name: data_url(relative) for name, relative in ASSETS.items()}
    data = {"items": items, "assets": {name: assets[name] for name in ["portrait", "happy", "think", "talk", "shy"]}}
    template = (HERE / "index.template.html").read_text(encoding="utf-8")
    style = "\n".join((HERE / name).read_text(encoding="utf-8") for name in ["ui.css", "gal-system.css", "inventory.css", "gal-dialogue.css"])
    script = (HERE / "gal-dialogue.js").read_text(encoding="utf-8") + "\n" + (HERE / "ui.js").read_text(encoding="utf-8")
    packed = template.replace("__STYLE__", style).replace("__SCRIPT__", script).replace("__DATA__", json.dumps(data, ensure_ascii=False).replace("</", "<\\/"))
    for name, encoded in assets.items():
        packed = packed.replace(f"__ASSET_{name}__", encoded)
    assert not re.search(r"__(?:ASSET_\w+|STYLE|SCRIPT|DATA)__", packed), "Unresolved template token"
    assert not re.search(r"(?:src|href)=[\"']https?://", packed), "Unexpected network dependency"
    audit = PageAudit()
    audit.feed(packed)
    static_ids = re.findall(r"\$\(['\"]([^'\"]+)['\"]\)", script)
    assert set(static_ids) <= audit.ids, f"Missing DOM nodes: {set(static_ids) - audit.ids}"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(packed, encoding="utf-8", newline="\n")
    manifest = {"canvas": [1448, 1086], "dialogue_canvas": [1448, 815], "pages": ["components", "inventory", "dialogue"], "offline": True, "assets": asset_manifest, "bytes": OUTPUT.stat().st_size}
    (HERE / "asset-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"Built {OUTPUT}")
    print(f"{len(items)} project items; {len(asset_manifest)} embedded assets; {OUTPUT.stat().st_size / 1024 / 1024:.1f} MB; all template references resolved")


if __name__ == "__main__":
    main()
