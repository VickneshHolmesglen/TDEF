"""Generate the HD-2D UI skin (2026-10-12): 9-slice frames for panels, buttons,
tabs, focus rings and bars.

The look: dark translucent navy panels with a thin double gold rule and small
corner studs (the HD-2D menu idiom), drawn as pixel art on a 2x grid so the
chrome matches the pixel sprites. Each image is designed at 1x and upscaled 2x
with nearest-neighbour; 9-slice margins in the theme are in 2x pixels.

    python tools/asset-pipeline/hd2d/generate_ui_skin.py
Output: assets/ui/skin/*.png
"""
from __future__ import annotations

import os

import numpy as np
from PIL import Image

OUT = os.path.join("assets", "ui", "skin")
SCALE = 2

INK = (10, 10, 16, 255)
GOLD = (206, 168, 96, 255)
GOLD_DIM = (132, 104, 60, 255)
GOLD_BRIGHT = (246, 216, 140, 255)
BRONZE = (118, 92, 56, 255)


def vgradient(w: int, h: int, top: tuple, bottom: tuple) -> np.ndarray:
    t = np.linspace(0.0, 1.0, h)[:, None, None]
    a = np.array(top, dtype=np.float32)[None, None, :]
    b = np.array(bottom, dtype=np.float32)[None, None, :]
    g = a * (1 - t) + b * t
    # Quantise the gradient into hard bands: pixel art, not a smooth ramp.
    g = np.round(g / 6.0) * 6.0
    return np.repeat(g, w, axis=1).clip(0, 255).astype(np.uint8)


def rect_outline(img: np.ndarray, inset: int, color: tuple) -> None:
    h, w = img.shape[:2]
    img[inset, inset:w - inset] = color
    img[h - 1 - inset, inset:w - inset] = color
    img[inset:h - inset, inset] = color
    img[inset:h - inset, w - 1 - inset] = color


def studs(img: np.ndarray, inset: int, color: tuple) -> None:
    """Small diamond stud on each corner of the gold rule."""
    h, w = img.shape[:2]
    for cy, cx in ((inset, inset), (inset, w - 1 - inset), (h - 1 - inset, inset), (h - 1 - inset, w - 1 - inset)):
        for dy, dx in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
            y, x = cy + dy, cx + dx
            if 0 <= y < h and 0 <= x < w:
                img[y, x] = color
        img[cy, cx] = GOLD_BRIGHT


def frame(size: int, top: tuple, bottom: tuple, rule: tuple, inner: tuple | None, stud: bool) -> np.ndarray:
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[1:-1, 1:-1] = vgradient(size - 2, size - 2, top, bottom)
    rect_outline(img, 0, INK)
    rect_outline(img, 2, rule)
    if inner is not None:
        rect_outline(img, 4, inner)
    if stud:
        studs(img, 2, rule)
    return img


def save(a: np.ndarray, name: str) -> None:
    im = Image.fromarray(a)
    im = im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST)
    path = os.path.join(OUT, name)
    im.save(path)
    print("wrote", path, im.size)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    navy_top = (34, 38, 56, 236)
    navy_bot = (16, 18, 30, 236)
    # Panels: double rule (gold + faint inner), corner studs.
    save(frame(24, navy_top, navy_bot, GOLD, (64, 58, 52, 255), True), "panel.png")
    # Opaque variant for always-on HUD panels that sit over live scenery.
    save(frame(24, navy_top[:3] + (255,), navy_bot[:3] + (255,), GOLD, (64, 58, 52, 255), True), "panel_solid.png")
    # Inset well (lists, bag, text areas): darker, single bronze rule.
    save(frame(16, (12, 14, 22, 230), (10, 11, 18, 230), BRONZE, None, False), "inset.png")
    # Buttons.
    save(frame(16, (46, 48, 64, 255), (26, 28, 40, 255), BRONZE, None, False), "button_normal.png")
    save(frame(16, (62, 62, 78, 255), (36, 36, 50, 255), GOLD, None, False), "button_hover.png")
    save(frame(16, (20, 20, 30, 255), (30, 30, 42, 255), GOLD, None, False), "button_pressed.png")
    save(frame(16, (38, 38, 44, 200), (26, 26, 32, 200), (70, 66, 60, 255), None, False), "button_disabled.png")
    # Active / selected (current tab, primary action): warm amber fill.
    save(frame(16, (150, 108, 46, 255), (100, 66, 26, 255), GOLD_BRIGHT, None, False), "button_active.png")
    # Focus ring: bright gold double rule, transparent centre.
    f = np.zeros((16, 16, 4), dtype=np.uint8)
    rect_outline(f, 0, INK)
    rect_outline(f, 1, GOLD_BRIGHT)
    rect_outline(f, 2, GOLD)
    save(f, "focus.png")
    # Bars: inset trough and a neutral light fill the code tints.
    trough = np.zeros((8, 8, 4), dtype=np.uint8)
    trough[:] = (8, 9, 14, 255)
    rect_outline(trough, 0, (60, 52, 40, 255))
    save(trough, "bar_back.png")
    fill = np.zeros((8, 8, 4), dtype=np.uint8)
    fill[:] = (255, 255, 255, 255)
    fill[1, :] = (255, 255, 255, 255)
    fill[-2:, :] = (200, 200, 200, 255)  # darker lip along the bottom
    save(fill, "bar_fill.png")
    # Horizontal divider: gold rule with a centre stud.
    d = np.zeros((5, 24, 4), dtype=np.uint8)
    d[2, :] = GOLD_DIM
    d[1:4, 11:13] = GOLD
    d[2, 11:13] = GOLD_BRIGHT
    save(d, "divider.png")


if __name__ == "__main__":
    main()
