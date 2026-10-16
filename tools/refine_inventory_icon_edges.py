from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "assets/meme_items.json"
SOURCE_DIR = ROOT / "assets/ui/generated_icons_20261016"
OUTPUT_DIR = ROOT / "assets/ui/inventory_icons_soft_edges_20261016"
OUTPUT_RES_PATH = "res://assets/ui/inventory_icons_soft_edges_20261016"

# The source icons are 1254 px; all changes are subtle at the game's 66-120 px display sizes.
EDGE_FADE = 0.64
EDGE_TINT = 0.44
GLOW_OPACITY = 0.17
SHADOW_OPACITY = 0.21


def refine(source_path: Path) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    pixels = np.asarray(source).copy()
    alpha = Image.fromarray(pixels[:, :, 3], "L")
    width, height = alpha.size

    # Estimate the outer 16 px silhouette band at half resolution, then feather it back up.
    small = alpha.resize((width // 2, height // 2), Image.Resampling.BILINEAR)
    inner = small.filter(ImageFilter.MinFilter(17))
    edge_band = ImageChops.subtract(small, inner)
    edge_band = edge_band.filter(ImageFilter.GaussianBlur(1.6))
    edge_band = edge_band.resize((width, height), Image.Resampling.BICUBIC)

    fade = np.asarray(edge_band, dtype=np.float32) / 255.0
    rgb = pixels[:, :, :3].astype(np.float32)
    output_alpha = pixels[:, :, 3].astype(np.float32)
    dark_outline = rgb.max(axis=2) < 110
    weight = fade * dark_outline
    output_alpha *= 1.0 - EDGE_FADE * weight
    tint = EDGE_TINT * weight[:, :, None]
    rgb = rgb * (1.0 - tint) + np.array([111, 177, 225], dtype=np.float32) * tint

    pixels[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    pixels[:, :, 3] = np.clip(output_alpha, 0, 255).astype(np.uint8)
    foreground = Image.fromarray(pixels, "RGBA")

    glow_alpha = alpha.filter(ImageFilter.GaussianBlur(23)).point(
        lambda value: round(value * GLOW_OPACITY)
    )
    glow = Image.new("RGBA", source.size, (113, 190, 247, 0))
    glow.putalpha(glow_alpha)

    shadow_alpha = alpha.filter(ImageFilter.GaussianBlur(18))
    offset_shadow = Image.new("L", source.size, 0)
    offset_shadow.paste(shadow_alpha, (3, 8))
    offset_shadow = offset_shadow.point(lambda value: round(value * SHADOW_OPACITY))
    shadow = Image.new("RGBA", source.size, (48, 83, 154, 0))
    shadow.putalpha(offset_shadow)

    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    result.alpha_composite(shadow)
    result.alpha_composite(glow)
    result.alpha_composite(foreground)
    return result


def main() -> None:
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for item_id, item in catalog.items():
        source_path = SOURCE_DIR / f"{item_id}.png"
        output_path = OUTPUT_DIR / f"{item_id}.png"
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        refine(source_path).save(output_path, format="PNG", compress_level=6)
        item["icon_path"] = f"{OUTPUT_RES_PATH}/{item_id}.png"

    CATALOG_PATH.write_bytes(
        (json.dumps(catalog, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    )
    print(f"Refined {len(catalog)} item icons into {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
