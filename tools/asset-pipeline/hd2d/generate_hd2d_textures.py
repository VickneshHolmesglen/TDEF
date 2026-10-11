"""Generate the HD-2D texture set (2026-10-11 direction: docs/images/graphics.PNG).

Codex no longer generates art, so these are authored procedurally. Every
texture is drawn at low resolution with a small palette and rendered in-engine
with nearest filtering -- that is what gives the pixel-painted HD-2D read.

Run from the repo root:
    python tools/asset-pipeline/hd2d/generate_hd2d_textures.py
Output: assets/art/hd2d/*.png (deterministic -- same seed, same pixels).
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image

OUT_DIR = os.path.join("assets", "art", "hd2d")
RNG = np.random.default_rng(20261011)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def tile_noise(size: int, cells: int, octaves: int = 4) -> np.ndarray:
    """Seamless value noise in [0, 1]: the lattice wraps, so the edges meet."""
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for _ in range(octaves):
        grid = RNG.random((cells, cells))
        coords = np.arange(size) * cells / size
        i0 = np.floor(coords).astype(int)
        t = coords - i0
        t = t * t * (3 - 2 * t)
        i1 = (i0 + 1) % cells
        i0 %= cells
        a = grid[np.ix_(i0, i0)]
        b = grid[np.ix_(i0, i1)]
        c = grid[np.ix_(i1, i0)]
        d = grid[np.ix_(i1, i1)]
        ty, tx = t[:, None], t[None, :]
        out += amp * ((a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty)
        total += amp
        amp *= 0.5
        cells *= 2
    out /= total
    return (out - out.min()) / (out.max() - out.min())


def palette_map(values: np.ndarray, palette: list[tuple[int, int, int]]) -> np.ndarray:
    """Quantize [0, 1] values onto a small palette (dark -> light)."""
    idx = np.clip((values * len(palette)).astype(int), 0, len(palette) - 1)
    return np.array(palette, dtype=np.uint8)[idx]


def dither(values: np.ndarray, strength: float = 0.08) -> np.ndarray:
    """Per-pixel jitter so palette bands break up into pixel speckle."""
    return np.clip(values + (RNG.random(values.shape) - 0.5) * strength * 2, 0, 1)


def save(img: Image.Image, name: str, scale: int = 1) -> None:
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    path = os.path.join(OUT_DIR, name)
    img.save(path)
    print(f"wrote {path} {img.size}")


# ---------------------------------------------------------------------------
# Ground (tileable, opaque)
# ---------------------------------------------------------------------------

GRASS_PALETTE = [(34, 52, 26), (48, 72, 32), (64, 90, 38), (82, 108, 44), (104, 126, 52), (130, 146, 62)]
DIRT_PALETTE = [(92, 64, 38), (118, 84, 48), (142, 104, 60), (164, 124, 72), (186, 146, 88), (204, 168, 106)]
STONE_PALETTE = [(70, 72, 68), (96, 98, 92), (122, 124, 116), (148, 150, 140), (172, 172, 160)]
MOSS_PALETTE = [(58, 84, 40), (78, 106, 46), (100, 128, 54)]


def ground_grass() -> Image.Image:
    v = 0.55 * tile_noise(128, 4) + 0.45 * tile_noise(128, 32, 2)
    rgb = palette_map(dither(v, 0.22), GRASS_PALETTE)
    # Blade ticks: 1x2 lit strokes over a dark root pixel -- the chunky
    # crosshatch speckle the reference ground reads with.
    for _ in range(900):
        x, y = (int(c) for c in RNG.integers(0, 128, 2))
        lit = GRASS_PALETTE[int(RNG.integers(3, len(GRASS_PALETTE)))]
        rgb[y, x] = lit
        rgb[(y + 1) % 128, x] = lit
        rgb[(y + 2) % 128, x] = GRASS_PALETTE[0]
    return Image.fromarray(rgb)


def ground_dirt() -> Image.Image:
    v = 0.6 * tile_noise(128, 4) + 0.4 * tile_noise(128, 32, 2)
    rgb = palette_map(dither(v, 0.14), DIRT_PALETTE)
    # Pebbles: 2x2 light flecks with a dark underside.
    for _ in range(90):
        x, y = RNG.integers(0, 128, 2)
        rgb[y % 128, x % 128] = DIRT_PALETTE[-1]
        rgb[y % 128, (x + 1) % 128] = DIRT_PALETTE[-1]
        rgb[(y + 1) % 128, x % 128] = DIRT_PALETTE[1]
        rgb[(y + 1) % 128, (x + 1) % 128] = DIRT_PALETTE[1]
    return Image.fromarray(rgb)


def stone_flags() -> Image.Image:
    """Mossy flagstones: irregular slabs (jittered grid) with dark grout."""
    size, n = 128, 4
    pts = [((i + 0.2 + RNG.random() * 0.6) * size / n, (j + 0.2 + RNG.random() * 0.6) * size / n)
           for j in range(n) for i in range(n)]
    yy, xx = np.mgrid[0:size, 0:size]
    d1 = np.full((size, size), 1e9)
    d2 = np.full((size, size), 1e9)
    owner = np.zeros((size, size), dtype=int)
    for k, (px, py) in enumerate(pts):
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d = np.hypot(xx - px - ox, yy - py - oy)
                closer = d < d1
                d2 = np.where(closer, d1, np.minimum(d2, d))
                owner = np.where(closer, k, owner)
                d1 = np.where(closer, d, d1)
    edge = (d2 - d1) < 2.5
    shade = np.array([RNG.random() for _ in pts])[owner]
    v = dither(0.25 + 0.5 * shade + 0.25 * tile_noise(size, 16, 2), 0.1)
    rgb = palette_map(v, STONE_PALETTE)
    moss = tile_noise(size, 4) > 0.62
    rgb[moss] = palette_map(dither(tile_noise(size, 16, 2), 0.2), MOSS_PALETTE)[moss]
    rgb[edge] = (44, 46, 42)
    return Image.fromarray(rgb)


# ---------------------------------------------------------------------------
# Billboard cards (RGBA, alpha-scissored in-engine)
# ---------------------------------------------------------------------------

def grass_blades() -> Image.Image:
    """A tuft of pointed blades, dark at the root, sunlit yellow-green at the tip."""
    w, h = 48, 48
    img = np.zeros((h, w, 4), dtype=np.uint8)
    ramp = [(34, 58, 26), (50, 82, 32), (72, 110, 40), (98, 138, 48), (132, 166, 58), (176, 196, 84)]
    for _ in range(26):
        base_x = RNG.normal(w / 2, w / 6)
        height = RNG.uniform(0.45, 0.98) * h
        lean = RNG.normal(0, 0.35) * height * 0.5
        width = RNG.uniform(1.6, 3.2)
        steps = int(height)
        for s in range(steps):
            t = s / max(steps - 1, 1)
            y = h - 1 - s
            cx = base_x + lean * t * t
            half = width * (1 - t) * 0.5 + 0.35
            shade = ramp[min(int(t * len(ramp) * RNG.uniform(0.85, 1.1)), len(ramp) - 1)]
            for x in range(int(cx - half), int(cx + half) + 1):
                if 0 <= x < w and 0 <= y < h:
                    img[y, x] = (*shade, 255)
    return Image.fromarray(img)


def leaf_clump(seed_offset: int) -> Image.Image:
    """Round foliage mass: lit from the upper-left, pixel-leaf speckle, ragged edge."""
    size = 64
    rng = np.random.default_rng(20261011 + seed_offset)
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    mask = np.zeros((size, size), dtype=bool)
    for _ in range(9):
        cx, cy = rng.normal(size / 2, size / 9, 2)
        r = rng.uniform(size * 0.16, size * 0.27)
        mask |= np.hypot(xx - cx, yy - cy) < r
    ragged = rng.random((size, size)) < 0.35
    edge = mask & ~np.roll(mask, 1, 0) | mask & ~np.roll(mask, -1, 1)
    mask &= ~(edge & ragged)
    light = 1 - (np.hypot(xx - size * 0.32, yy - size * 0.28) / (size * 0.85))
    # Inner pockets: low-frequency dark lobes so the mass reads as leaf clusters.
    pockets = np.zeros((size, size))
    for _ in range(6):
        cx, cy = rng.normal(size / 2, size / 6, 2)
        pockets = np.maximum(pockets, 1 - np.hypot(xx - cx, yy - cy) / (size * 0.12))
    v = np.clip(light * 0.8 + rng.random((size, size)) * 0.35 - np.clip(pockets, 0, 1) * 0.35, 0, 1)
    pal = [(28, 52, 26), (40, 70, 30), (56, 92, 34), (76, 116, 40), (102, 140, 48), (140, 172, 64)]
    rgb = palette_map(v, pal)
    img = np.zeros((size, size, 4), dtype=np.uint8)
    img[..., :3] = rgb
    img[..., 3] = np.where(mask, 255, 0)
    return Image.fromarray(img)


def flowers() -> Image.Image:
    """Scatter card: tiny white/yellow/orange blooms on short stems."""
    w, h = 32, 24
    img = np.zeros((h, w, 4), dtype=np.uint8)
    colors = [(238, 232, 210), (240, 206, 72), (232, 128, 54), (150, 196, 236)]
    for _ in range(7):
        x = int(RNG.integers(3, w - 3))
        top = int(RNG.integers(6, h - 6))
        for y in range(top, h):
            img[y, x] = (62, 98, 38, 255)
        c = colors[int(RNG.integers(0, len(colors)))]
        for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
            img[top + dy, x + dx] = (*c, 255)
        img[top, x] = (250, 230, 120, 255)
    return Image.fromarray(img)


# ---------------------------------------------------------------------------
# Material textures for 3D props (tileable, opaque)
# ---------------------------------------------------------------------------

def bark() -> Image.Image:
    w, h = 32, 64
    stripes = np.tile(np.sin(np.arange(w) / w * math.tau * 4)[None, :], (h, 1)) * 0.5 + 0.5
    v = dither(0.55 * stripes + 0.45 * tile_noise(64, 8, 3)[:h, :w], 0.15)
    return Image.fromarray(palette_map(v, [(46, 32, 22), (66, 46, 30), (88, 62, 40), (112, 82, 54)]))


def wood_plank() -> Image.Image:
    w, h = 32, 32
    grain = np.tile(np.sin(np.arange(h) / h * math.tau * 3)[:, None], (1, w)) * 0.5 + 0.5
    v = dither(0.6 * grain + 0.4 * tile_noise(32, 4, 2), 0.12)
    return Image.fromarray(palette_map(v, [(64, 42, 26), (88, 60, 36), (112, 80, 50), (140, 104, 66)]))


def ruin_bricks() -> Image.Image:
    """Stacked weathered bricks for the broken pillars, moss creeping up."""
    w, h = 64, 64
    rgb = np.zeros((h, w, 3), dtype=np.uint8)
    base = dither(tile_noise(64, 8, 3), 0.18)
    rgb[:] = palette_map(base, [(120, 104, 70), (146, 128, 86), (170, 150, 100), (192, 172, 120)])
    for row in range(0, h, 8):
        rgb[row, :] = (70, 60, 42)
        off = 0 if (row // 8) % 2 == 0 else 8
        for col in range(off, w, 16):
            rgb[row:row + 8, col % w] = (70, 60, 42)
    moss = (tile_noise(64, 4) * (np.linspace(1.0, 0.3, h)[:, None])) > 0.45
    rgb[moss] = palette_map(dither(tile_noise(64, 16, 2), 0.2), MOSS_PALETTE)[moss]
    return Image.fromarray(rgb)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    save(ground_grass(), "ground_grass.png")
    save(ground_dirt(), "ground_dirt.png")
    save(stone_flags(), "ground_stone.png")
    save(grass_blades(), "card_grass.png")
    for i in range(3):
        save(leaf_clump(i), f"card_leaves_{i}.png")
    save(flowers(), "card_flowers.png")
    save(bark(), "mat_bark.png")
    save(wood_plank(), "mat_wood.png")
    save(ruin_bricks(), "mat_ruin_bricks.png")


if __name__ == "__main__":
    main()
