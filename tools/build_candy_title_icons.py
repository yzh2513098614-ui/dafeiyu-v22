"""Editable, deterministic standard menu symbols matching the white-border stickers."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/ui/candy_title/icons"
DEST.mkdir(parents=True, exist_ok=True)
symbols = {
    "play": '<path d="M16 12 Q16 7 22 10 L58 31 Q64 35 58 40 L22 62 Q16 65 16 58 Z" fill="#FF66AA" stroke="#FF95C5" stroke-width="2"/>',
    "folder": '<path d="M8 22 Q8 13 16 13 H29 L36 20 H56 Q64 20 64 29 V55 Q64 62 56 62 H16 Q8 62 8 55 Z" fill="#FFCF65" stroke="#EEAA36" stroke-width="2"/><path d="M10 30 Q10 26 17 26 H61 L58 57 H13 Z" fill="#FFE29A"/>',
    "book": '<path d="M16 8 L52 5 Q61 4 62 14 L65 54 Q65 62 56 64 L18 67 Q9 66 9 56 L7 20 Q7 11 16 8 Z" fill="#4E95FF" stroke="#2C69D7" stroke-width="2"/><path d="M21 23 L48 20 M22 34 L50 32 M23 46 L42 44" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>',
    "save": '<path d="M12 7 H53 L64 18 V59 Q64 66 56 66 H14 Q7 66 7 58 V16 Q7 7 12 7 Z" fill="#4C92FF" stroke="#2A68D8" stroke-width="2"/><path d="M20 7 H47 V26 H20 Z M18 40 H52 V60 H18 Z" fill="#FFFFFF"/><path d="M38 10 H44 V23 H38 Z" fill="#A9DAFF"/>',
    "settings": '<path d="M28 6 H43 L45 16 L53 21 L63 19 L69 33 L61 39 L59 49 L62 57 L48 66 L40 59 L30 59 L21 65 L9 54 L14 45 L12 36 L4 30 L11 17 L21 20 L27 15 Z" fill="#548FFF" stroke="#2F6AD4" stroke-width="2"/><circle cx="36" cy="36" r="12" fill="#FFFFFF"/>',
    "chat": '<path d="M6 31 Q6 10 31 10 Q56 10 56 30 Q56 48 33 50 L19 61 L20 48 Q6 43 6 31 Z" fill="#509DFF" stroke="#2E75DF" stroke-width="2"/><circle cx="22" cy="30" r="3" fill="white"/><circle cx="33" cy="30" r="3" fill="white"/><circle cx="44" cy="30" r="3" fill="white"/><path d="M45 49 Q43 37 56 37 Q69 37 69 49 Q69 58 61 60 L59 67 L53 60 Q46 57 45 49 Z" fill="#FFA0D5"/>',
    "image": '<path d="M11 8 L54 4 Q63 4 63 13 L68 57 Q68 64 59 65 L18 69 Q9 68 8 61 L4 21 Q4 10 11 8 Z" fill="#4F9EFF" stroke="#2B70D8" stroke-width="2"/><circle cx="21" cy="24" r="6" fill="#FFFFFF"/><path d="M15 57 L32 32 L55 55 Z" fill="#FFFFFF"/>',
    "exit": '<path d="M13 6 L40 11 V65 L13 60 Z" fill="#5794FF" stroke="#2768D7" stroke-width="2"/><path d="M40 13 H50 V61 H40" fill="none" stroke="#A7D6FF" stroke-width="4"/><circle cx="31" cy="36" r="2.5" fill="white"/><path d="M51 31 H64 M58 24 L65 31 L58 39" fill="none" stroke="#FF79B9" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>',
    "help": '<circle cx="36" cy="36" r="29" fill="#4B89EE" stroke="#2D60C4" stroke-width="2"/><path d="M27 25 Q27 14 39 17 Q51 20 43 30 L35 38 V44" fill="none" stroke="white" stroke-width="5" stroke-linecap="round"/><circle cx="35" cy="54" r="3" fill="white"/>'
}
for name, content in symbols.items():
    # A white plate matches the button face and keeps the standard symbols editable.
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 72 72"><title>{name}</title><rect x="1" y="1" width="70" height="70" rx="20" fill="#FFFFFF"/><g stroke-linejoin="round">{content}</g></svg>\n'
    (DEST / f"{name}.svg").write_text(svg, encoding="utf-8", newline="\n")
print(json.dumps({"icons": len(symbols), "path": str(DEST)}, ensure_ascii=False))
