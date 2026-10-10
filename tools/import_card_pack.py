"""Import the 42 authored card paintings from the local TokenWhale bundle.

This copies the original 128x176 PNGs without resizing or repainting them.
Game text and mechanics live separately in assets/cards/catalog.json.
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(r"D:\迅雷下载\_素材包_20261003\总包\TokenWhale_AllAssets")
OUTPUT = ROOT / "assets/cards"

# cost, target, effects. Every imported painting has a playable effect.
RULES = {
    "never_surrender": (2, "self", [("block", 12), ("amplify", 4)]),
    "whale_impact": (2, "one", [("damage", 18)]),
    "deep_blue_shield": (1, "self", [("block", 10)]),
    "tidal_healing": (1, "self", [("heal", 8)]),
    "token_torrent": (1, "self", [("energy", 1), ("draw", 1)]),
    "echo_summon": (2, "all", [("damage", 9)]),
    "precise_search": (1, "self", [("draw", 2)]),
    "deep_thinking": (1, "self", [("draw", 2), ("amplify", 3)]),
    "memory_recall": (1, "self", [("retrieve", 1)]),
    "compute_overdrive": (2, "self", [("amplify", 10)]),
    "ocean_echo": (2, "one", [("block", 8), ("damage", 7)]),
    "zero_restart": (3, "self", [("cleanse", 1), ("heal", 12)]),
    "tidal_slash": (1, "one", [("damage", 11)]),
    "blue_lightning": (1, "one", [("damage", 14)]),
    "water_spear": (2, "one", [("damage", 19)]),
    "wave_advance": (1, "one", [("damage", 9), ("block", 5)]),
    "whale_combo": (2, "all", [("damage", 11)]),
    "ocean_release": (3, "all", [("damage", 17)]),
    "whale_guard": (1, "self", [("block", 13)]),
    "pearl_healing": (1, "self", [("heal", 10)]),
    "inspired_thought": (1, "self", [("draw", 2)]),
    "token_reward": (1, "self", [("energy", 1), ("draw", 1)]),
    "quiet_rest": (1, "self", [("heal", 8), ("stamina", 8)]),
    "together_forward": (1, "self", [("block", 8), ("draw", 1)]),
    "frost_bind": (2, "one", [("damage", 6), ("bind", 1)]),
    "silent_seal": (1, "one", [("bind", 1)]),
    "bubble_prison": (2, "one", [("bind", 1), ("block", 5)]),
    "force_interrupt": (2, "one", [("damage", 8), ("bind", 1)]),
    "time_slow": (2, "one", [("bind", 1), ("draw", 1)]),
    "current_tangle": (2, "one", [("damage", 6), ("bind", 1)]),
    "evasive_step": (1, "self", [("block", 7), ("draw", 1)]),
    "umbrella_parry": (1, "self", [("block", 12)]),
    "wave_jump": (1, "one", [("damage", 8), ("draw", 1)]),
    "deep_stealth": (2, "self", [("block", 16)]),
    "current_counter": (2, "one", [("block", 8), ("damage", 8)]),
    "rewind_step": (1, "self", [("retrieve", 1)]),
    "whale_scout": (1, "self", [("draw", 2)]),
    "team_command": (1, "self", [("amplify", 7), ("draw", 1)]),
    "data_sort": (2, "self", [("draw", 3)]),
    "secure_backup": (2, "self", [("block", 8), ("heal", 5)]),
    "token_bargain": (1, "self", [("energy", 1), ("draw", 1)]),
    "efficient_compute": (2, "self", [("draw", 2), ("energy", 1)]),
}

LABEL = {
    "damage": "造成 {n} 点基础伤害", "block": "获得 {n} 点格挡",
    "heal": "恢复 {n} 点生命", "draw": "抽 {n} 张牌",
    "energy": "获得 {n} 点能量", "bind": "束缚目标 {n} 次行动",
    "stamina": "恢复 {n} 点体力", "amplify": "下一次伤害 +{n}",
    "cleanse": "解除束缚", "retrieve": "从弃牌堆取回 {n} 张牌",
}


def main() -> None:
    packs = [
        ("base", SOURCE / "01_BaseAssets", "skills.json", "image"),
        ("character", SOURCE / "02_CharacterCards_12", "cards.json", "pixel_image"),
        ("tactics", SOURCE / "03_CharacterCards_18", "cards.json", "pixel_image"),
    ]
    cards = []
    for group, directory, manifest, image_key in packs:
        entries = json.loads((directory / manifest).read_text(encoding="utf-8-sig"))
        for entry in entries:
            card_id = entry["id"]
            cost, target, effects = RULES[card_id]
            source = directory / entry[image_key]
            target_path = OUTPUT / group / f"{card_id}.png"
            target_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target_path)
            cards.append({
                "id": card_id, "name": entry["name"], "group": group,
                "image": "res://assets/cards/" + group + "/" + card_id + ".png",
                "cost": cost, "target": target,
                "description": "；".join(LABEL[k].format(n=n) for k, n in effects),
                "effects": [{"kind": k, "value": n} for k, n in effects],
            })
    assert len(cards) == len(RULES) == 42
    (OUTPUT / "catalog.json").write_text(json.dumps(cards, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUTPUT / "SOURCE.txt").write_text(str(SOURCE) + "\nOriginal 128x176 pixel PNGs copied without resizing.\n", encoding="utf-8")
    print(f"Imported {len(cards)} playable cards to {OUTPUT}")


if __name__ == "__main__":
    main()
