"""Fits the raw Blender renders of the Sanctuary buildings onto the game's
tier canvases (system Python + Pillow).

    python tools/asset-pipeline/blender/compose_sanctuary_buildings.py [sheet.png]

Each tier is fitted to a growing share of the canvas (TIER_SHARE: 55 % at
tier 1 up to 100 % at tier 5), bottom-centred on the same baseline. True
model scale would leave tier 1 at ~25 % of the canvas, too small to read or
click in the Overview, so the growth is compressed but stays monotonic. Canvas sizes are the
existing assets/art/sanctuary/town/<id>_tier_N.png sizes (SanctuaryBuilding
footprints and TownBuildingView's hit rect are tuned to them). An optional
argument writes a contact sheet of all 35 images.
"""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "assets/source/3d/sanctuary_buildings"
OUT = ROOT / "assets/art/sanctuary/town"
CANVAS = {
    "armoury": (522, 648), "blacksmith": (579, 624), "castle": (370, 604), "keep": (563, 668),
    "menagerie": (576, 631), "seers_tower": (452, 730), "training_hall": (629, 648),
}
TIERS = range(1, 6)
TIER_SHARE = {1: 0.55, 2: 0.66, 3: 0.77, 4: 0.88, 5: 1.0}


def compose(building_id):
    raws = [Image.open(RAW / f"{building_id}_tier_{t}.png").convert("RGBA") for t in TIERS]
    cw, ch = CANVAS[building_id]
    out = []
    for t, im in zip(TIERS, raws):
        box = im.getbbox()
        bw, bh = box[2] - box[0], box[3] - box[1]
        fit = min(cw / bw, ch / bh) * TIER_SHARE[t]
        crop = im.crop(box).resize((round(bw * fit), round(bh * fit)), Image.LANCZOS)
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.alpha_composite(crop, ((cw - crop.width) // 2, ch - crop.height))
        canvas.save(OUT / f"{building_id}_tier_{t}.png", optimize=True)
        out.append(canvas)
    return out


def main():
    sheet_rows = [compose(b) for b in CANVAS]
    if len(sys.argv) > 1:
        cell = 160
        sheet = Image.new("RGBA", (cell * 5, cell * len(sheet_rows)), (126, 178, 92, 255))
        for r, row in enumerate(sheet_rows):
            for c, im in enumerate(row):
                th = im.copy()
                th.thumbnail((cell, cell))
                sheet.alpha_composite(th, (c * cell + (cell - th.width) // 2, r * cell + cell - th.height))
        sheet.save(sys.argv[1])


if __name__ == "__main__":
    main()
