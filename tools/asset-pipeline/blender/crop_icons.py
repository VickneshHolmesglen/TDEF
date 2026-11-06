"""Crop tower kit icon renders to their painted bounds (ADR-0043).

Blender renders each piece's icon into a fixed square with wide transparent
margins; the Inventory galleries size tiles from the texture's aspect, so
uncropped icons show tiny towers. Run after tower_kit.export_pieces():

    python -I tools/asset-pipeline/blender/crop_icons.py
"""
import glob
import os

from PIL import Image

ICON_DIR = os.path.join("assets", "art", "towers3d", "icons")
PAD = 0.06  # fraction of the longer side kept as margin


def crop(path: str) -> bool:
    im = Image.open(path).convert("RGBA")
    box = im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if box is None:
        return False
    pad = int(max(box[2] - box[0], box[3] - box[1]) * PAD)
    box = (max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, im.width), min(box[3] + pad, im.height))
    if box == (0, 0, im.width, im.height):
        return False  # already cropped
    im.crop(box).save(path)
    return True


if __name__ == "__main__":
    done = [p for p in sorted(glob.glob(os.path.join(ICON_DIR, "*.png"))) if crop(p)]
    print(f"cropped {len(done)} icons")
