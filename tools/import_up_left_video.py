"""Key the user's green-screen video at native resolution, then install one direction.

No resizing, skeletal deformation, white key, erosion, or generated poses.
The matte includes enclosed green gaps. Only a 3 px mixed-colour boundary is
decontaminated; the costume and all opaque interior RGB remain source pixels.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/video_runtime"))
from scipy import ndimage as ndi

SOURCE = ROOT / "art_source/up_left_20261010"
OUTPUT = ROOT / "assets/character/up_left_video_20261010"
REVIEW = ROOT / "预览/左上视频替换_20261010"
FPS = 24
# Source 68 and 94 show the same phase; 94 is the excluded duplicate endpoint.
START, END = 68, 94
CANVAS = (1024, 1152)
GROUND = (512, 1080)
TRANSLATION = (-1, 395)
IDLE_SOURCE = 77
SURFACE_PROFILE = {
    "head": [.504, .592, .112, .108], "body": [.480, .809, .103, .089],
    "tail": [.598, .869, .106, .070], "face": [.412, .621, .029, .037],
    "head_split": [.68, .75], "hair_split": [.71, .80], "tail_split": [.80, .85],
}


def key_green(rgb):
    colour = rgb.astype(np.float32)
    excess = colour[:, :, 1] - np.maximum(colour[:, :, 0], colour[:, :, 2])
    # Every matching green pixel is eligible, including hair and ankle holes.
    screen = (colour[:, :, 1] > 120) & (excess > 60)
    labels, _ = ndi.label(~screen)
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    silhouette = labels == sizes.argmax()
    interior_distance = ndi.distance_transform_edt(silhouette)
    clean = silhouette & (interior_distance > 3) & (excess < 8)
    distance, nearest = ndi.distance_transform_edt(~clean, return_indices=True)
    nearest_colour = colour[nearest[0], nearest[1]]
    border = np.concatenate((colour[0], colour[-1], colour[:, 0], colour[:, -1]))
    bg = np.median(border, axis=0)
    direction = nearest_colour - bg
    alpha_fit = np.clip(
        np.sum((colour - bg) * direction, axis=2)
        / np.maximum(np.sum(direction * direction, axis=2), 1), 0, 1)
    alpha = silhouette.astype(np.float32)
    edge = (distance <= 20) & (interior_distance <= 3)
    alpha[edge] = alpha_fit[edge]
    alpha[alpha < 0.03] = 0
    alpha[alpha > 0.985] = 1
    # Recover foreground RGB from C = alpha*F + (1-alpha)*green.
    mixed = edge & (alpha > 0) & ((alpha < 1) | (excess > 8))
    corrected = (colour - (1 - alpha[:, :, None]) * bg) / np.maximum(alpha[:, :, None], .03)
    result = rgb.copy()
    result[mixed] = np.clip(np.round(corrected[mixed]), 0, 255).astype(np.uint8)
    # Ill-conditioned unmixing near thin lace can introduce a magenta fringe.
    # Use the nearest clean source RGB for truly mixed boundary pixels instead.
    uncertain = mixed & (alpha < .95)
    result[uncertain] = nearest_colour[uncertain].astype(np.uint8)
    alpha8 = np.round(alpha * 255).astype(np.uint8)
    # H.264 ringing sometimes makes the projection prefer alpha=1 despite
    # chroma spill. This character has no green costume: replace only such
    # boundary RGB with a nearby clean source colour, never remove its alpha.
    spill = (alpha8 > 0) & (result[:, :, 1].astype(int)-result[:, :, [0, 2]].max(axis=2).astype(int) > 8)
    result[spill] = nearest_colour[spill].astype(np.uint8)
    # Transparent RGB comes from the closest solid pixel, preventing green
    # fringes when Godot samples bilinearly or builds mipmaps.
    visible = alpha8 > 0
    result[~visible] = nearest_colour[~visible].astype(np.uint8)
    rgba = np.dstack((result, alpha8))
    assert np.array_equal(result[clean], rgb[clean]), "Opaque interior changed"
    yy, xx = np.where(alpha8 > 127)
    residual = (alpha8 > 32) & (result[:, :, 1].astype(int) - result[:, :, [0, 2]].max(axis=2).astype(int) > 30)
    return rgba, {
        "bounds": [int(xx.min()), int(yy.min()), int(xx.max()+1), int(yy.max()+1)],
        "foreground_pixels": int(visible.sum()),
        "opaque_rgb_exact": True,
        "green_pixels_remaining": int(residual.sum()),
        "background_rgb": bg.astype(int).tolist(),
    }


def canvas_frame(rgba):
    x, y = TRANSLATION
    out = np.zeros((CANVAS[1], CANVAS[0], 4), dtype=np.uint8)
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(CANVAS[0], x+rgba.shape[1]), min(CANVAS[1], y+rgba.shape[0])
    out[y0:y1, x0:x1] = rgba[y0-y:y1-y, x0-x:x1-x]
    assert np.count_nonzero(out[:, :, 3]) == np.count_nonzero(rgba[:, :, 3]), "Clipped character"
    return out


def preview(frames):
    REVIEW.mkdir(parents=True, exist_ok=True)
    board = Image.new("RGB", (1040, 400*4), "#617d88")
    draw = ImageDraw.Draw(board)
    for i, index in enumerate(range(0, len(frames), 2)):
        picture = Image.fromarray(frames[index]).crop((300, 450, 760, 1100))
        picture.thumbnail((250, 350), Image.Resampling.LANCZOS)
        x, y = i % 4*260, i // 4*400
        board.paste(picture, (x+(260-picture.width)//2, y+16), picture)
        draw.text((x+16, y+370), f"{index:02d} / source {START+index}", fill="white")
    board.save(REVIEW / "transparent_contact.png")
    images = []
    for rgba in frames:
        picture = Image.fromarray(rgba).crop((280, 450, 780, 1120))
        for_bg = Image.new("RGBA", picture.size, "#617d88")
        for_bg.alpha_composite(picture)
        images.append(for_bg.convert("RGB"))
    # GIF is only a viewing aid. The installed PNGs retain every source pixel.
    images[0].save(REVIEW / "up_left_walk.gif", save_all=True, append_images=images[1:],
                   duration=[42, 42, 41]*8+[42, 42], loop=0, disposal=2)
    Image.fromarray(frames[9]).save(REVIEW / "native_transparent_frame.png")


def extract(all_frames=False):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "masks").mkdir(exist_ok=True)
    (SOURCE / ".gdignore").touch()
    numbers = range(1, 159) if all_frames else range(START, END)
    if all_frames:
        (SOURCE / "transparent").mkdir(exist_ok=True)
    records, frames = [], []
    for number in numbers:
        rgb = np.array(Image.open(SOURCE / f"frame_{number:04d}.png").convert("RGB"))
        rgba, record = key_green(rgb)
        if all_frames:
            Image.fromarray(rgba).save(SOURCE / f"transparent/frame_{number:04d}.png")
        if START <= number < END:
            index = number-START
            packed = canvas_frame(rgba)
            Image.fromarray(packed).save(OUTPUT / f"walk_{index:02d}.png")
            Image.fromarray(packed[:, :, 3]).save(OUTPUT / f"masks/walk_{index:02d}.png")
            frames.append(packed)
            records.append({"source_frame": number, "time": (number-1)/FPS,
                            "translation": list(TRANSLATION), **record})
        if number % 20 == 0:
            print("MATTED", number, flush=True)
    heights = [r["bounds"][3]-r["bounds"][1] for r in records]
    # Match the existing rear diagonal's visible height in world units while
    # keeping the 1024x768 video pixels at their native size in the PNG.
    reference = np.array(Image.open(ROOT / "assets/character/jimeng_v24/up_left/walk_00.png"))
    reference_y = np.where(reference[:, :, 3] > 127)[0]
    native_height = float(np.median(heights))
    world_height = float(reference_y.max()-reference_y.min()+1)*.0022
    info = {
        "direction": "up_left", "source": "res://art_source/up_left_20261010/upLeft.mp4",
        "source_sha256": hashlib.sha256((SOURCE / "upLeft.mp4").read_bytes()).hexdigest(),
        "source_resolution": [1024, 768], "source_fps": FPS, "source_frame_count": 158,
        "loop_source_frames": [START, END-1], "loop_frame_count": len(frames),
        "idle_source_frame": IDLE_SOURCE, "canvas_size": list(CANVAS), "ground": list(GROUND),
        "pixel_size": world_height/native_height, "median_visible_height": native_height,
        "matte": "green chroma only, enclosed gaps included, boundary RGB unmix, no white key or erosion",
        "registration": "one constant integer translation for every frame; source bob and foot motion retained",
        "records": records,
    }
    (OUTPUT / "extraction.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    preview(frames)
    print(json.dumps({k: v for k, v in info.items() if k != "records"}, ensure_ascii=True), flush=True)


def install():
    manifest_path = ROOT / "assets/character/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    before = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    backup = ROOT / "备份/20261010_左上视频替换前"
    backup.mkdir(parents=True, exist_ok=True)
    for relative in ["assets/character/manifest.json", "room_3d.gd"]:
        destination = backup / Path(relative).name
        if not destination.exists():
            destination.write_bytes((ROOT / relative).read_bytes())
    info = json.loads((OUTPUT / "extraction.json").read_text(encoding="utf-8"))
    resources = ["res://"+(OUTPUT / f"walk_{i:02d}.png").relative_to(ROOT).as_posix()
                 for i in range(info["loop_frame_count"])]
    for state in ["idle", "interact"]:
        manifest["frames_by_state"][state]["up_left"] = [resources[IDLE_SOURCE-START]]
    manifest["frames_by_state"]["walk"]["up_left"] = resources
    manifest["frame_counts_by_direction"]["up_left"] = len(resources)
    manifest.setdefault("pixel_size_by_direction", {})["up_left"] = info["pixel_size"]
    manifest.setdefault("surface_profiles_by_direction", {})["up_left"] = SURFACE_PROFILE
    manifest.setdefault("walk_fps_by_direction", {})["up_left"] = FPS
    manifest.setdefault("video_extraction_by_direction", {})["up_left"] = "res://assets/character/up_left_video_20261010/extraction.json"
    manifest["provenance"]["up_left"] = "user upLeft.mp4, native 24 fps complete video frames, fixed green-screen alpha"
    manifest.get("generated_source_sequences", {}).pop("up_left", None)
    manifest["version"] = max(int(manifest.get("version", 9)), 10)
    manifest["runtime_matte_baked"] = True
    for state in before["frames_by_state"]:
        for direction in before["atlas_order"]:
            if direction != "up_left":
                assert manifest["frames_by_state"][state][direction] == before["frames_by_state"][state][direction]
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("INSTALLED up_left", len(resources), "full-character PNGs; other directions verified unchanged", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--all-frames", action="store_true")
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    extract(args.all_frames)
    if args.install:
        install()
