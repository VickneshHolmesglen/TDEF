"""Bronze / silver / gold rims for Mission Select medallions (Ascension reward,
design/quick-specs/ascension-rewards-2026-11-03.md).

Each rim is a bevelled metal ring on a transparent square: lit from the top
left, a dark inner edge, a bright outer edge and small studs at the four
points. MedallionRim (src/gameplay/ui/mission_select_screen/medallion_rim.gd)
scales it onto the medallion's visible area at runtime.

  python tools/asset-pipeline/hd2d/generate_rank_rims.py
"""
import math
import pathlib

from PIL import Image

SIZE = 512
OUTER = 0.5 * SIZE - 2          # outer radius, px
WIDTH = 0.075 * SIZE            # ring width, px
STUD_RADIUS = 0.03 * SIZE

METALS = {
    "bronze": ((92, 52, 24), (205, 132, 70), (255, 214, 160)),
    "silver": ((70, 76, 90), (182, 190, 206), (250, 252, 255)),
    "gold": ((110, 72, 12), (232, 178, 52), (255, 240, 170)),
}
OUT_DIR = pathlib.Path("assets/art/ui")


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def shade(dark, mid, light, t):
    """t in [0, 1]: 0 dark, 0.5 mid, 1 light."""
    return lerp(dark, mid, t * 2) if t < 0.5 else lerp(mid, light, (t - 0.5) * 2)


def make_rim(name, dark, mid, light):
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = im.load()
    c = SIZE / 2 - 0.5
    inner = OUTER - WIDTH
    studs = [(c + math.cos(a) * (OUTER - WIDTH / 2), c + math.sin(a) * (OUTER - WIDTH / 2))
             for a in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4)]
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x - c, y - c
            r = math.hypot(dx, dy)
            stud = min(math.hypot(x - sx, y - sy) for sx, sy in studs)
            if stud <= STUD_RADIUS:
                # domed stud: brightest toward the light (top left)
                k = 1.0 - stud / STUD_RADIUS
                lit = 0.5 + 0.5 * ((-(x - c) - (y - c)) / (SIZE * 0.7))
                px[x, y] = (*shade(dark, mid, light, min(1.0, 0.35 + 0.65 * k * (0.6 + 0.4 * lit))), 255)
                continue
            if r < inner - 1 or r > OUTER + 1:
                continue
            # across the band: 0 inner edge .. 1 outer edge, a rounded bevel
            u = (r - inner) / WIDTH
            bevel = math.sin(math.pi * min(max(u, 0.0), 1.0))
            # light from the top left
            angle_light = 0.5 + 0.5 * (-(dx + dy) / (r * math.sqrt(2)) if r else 0.0)
            t = 0.15 + 0.55 * bevel * (0.45 + 0.55 * angle_light) + 0.25 * angle_light * (u > 0.55)
            t = min(1.0, max(0.0, t))
            alpha = 255
            if r < inner:      # 1 px anti-alias on the inner edge
                alpha = round(255 * (1 - (inner - r)))
            elif r > OUTER:    # and the outer edge
                alpha = round(255 * (1 - (r - OUTER)))
            if alpha <= 0:
                continue
            px[x, y] = (*shade(dark, mid, light, t), alpha)
    out = OUT_DIR / f"rank_rim_{name}.png"
    im.save(out)
    print("wrote", out)


if __name__ == "__main__":
    for metal, (dark, mid, light) in METALS.items():
        make_rim(metal, dark, mid, light)
