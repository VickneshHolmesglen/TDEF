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
LEAF_PALETTE = [(28, 52, 26), (40, 70, 30), (56, 92, 34), (76, 116, 40), (102, 140, 48), (140, 172, 64)]
# Sun-bleached yellow-green, like the big conifer in the reference.
LEAF_GOLD_PALETTE = [(46, 54, 22), (70, 80, 28), (100, 108, 34), (134, 138, 44), (168, 164, 60), (204, 192, 92)]
MOSS_PALETTE = [(58, 84, 40), (78, 106, 46), (100, 128, 54)]


def ground_grass(pal: list[tuple[int, int, int]] = GRASS_PALETTE, ticks: int = 900) -> Image.Image:
    v = 0.55 * tile_noise(128, 4) + 0.45 * tile_noise(128, 32, 2)
    rgb = palette_map(dither(v, 0.22), pal)
    # Blade ticks: 1x2 lit strokes over a dark root pixel -- the chunky
    # crosshatch speckle the reference ground reads with.
    for _ in range(ticks):
        x, y = (int(c) for c in RNG.integers(0, 128, 2))
        lit = pal[int(RNG.integers(3, len(pal)))]
        rgb[y, x] = lit
        rgb[(y + 1) % 128, x] = lit
        rgb[(y + 2) % 128, x] = pal[0]
    return Image.fromarray(rgb)


def ground_dirt(pal: list[tuple[int, int, int]] = DIRT_PALETTE, pebbles: int = 90) -> Image.Image:
    v = 0.6 * tile_noise(128, 4) + 0.4 * tile_noise(128, 32, 2)
    rgb = palette_map(dither(v, 0.14), pal)
    # Pebbles: 2x2 light flecks with a dark underside.
    for _ in range(pebbles):
        x, y = RNG.integers(0, 128, 2)
        rgb[y % 128, x % 128] = pal[-1]
        rgb[y % 128, (x + 1) % 128] = pal[-1]
        rgb[(y + 1) % 128, x % 128] = pal[1]
        rgb[(y + 1) % 128, (x + 1) % 128] = pal[1]
    return Image.fromarray(rgb)


def stone_flags(pal: list[tuple[int, int, int]] = STONE_PALETTE, grout: tuple[int, int, int] = (44, 46, 42),
                moss_pal: list[tuple[int, int, int]] = MOSS_PALETTE, moss_threshold: float = 0.62) -> Image.Image:
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
    rgb = palette_map(v, pal)
    moss = tile_noise(size, 4) > moss_threshold
    rgb[moss] = palette_map(dither(tile_noise(size, 16, 2), 0.2), moss_pal)[moss]
    rgb[edge] = grout
    return Image.fromarray(rgb)


# ---------------------------------------------------------------------------
# Billboard cards (RGBA, alpha-scissored in-engine)
# ---------------------------------------------------------------------------

def grass_blades(w: int, h: int, count: int, width: tuple[float, float], seed_offset: int,
                 ramp: list[tuple[int, int, int]] | None = None) -> Image.Image:
    """A tuft of pointed blades, dark at the root, sunlit yellow-green at the tip.

    Thin (1-2 px) blades in large numbers read as the soft meadow grass of the
    reference; the root third is kept sparse so tufts don't sit on a solid block.
    """
    rng = np.random.default_rng(20261011 + seed_offset)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    ramp = ramp or [(30, 52, 24), (44, 74, 30), (64, 102, 38), (90, 132, 46), (124, 160, 56), (168, 192, 78), (206, 214, 112)]
    for _ in range(count):
        base_x = rng.normal(w / 2, w / 5)
        height = rng.uniform(0.4, 0.98) * h
        lean = rng.normal(0, 0.45) * height * 0.45
        blade_w = rng.uniform(*width)
        steps = int(height)
        bright = rng.uniform(0.8, 1.15)
        for st in range(steps):
            t = st / max(steps - 1, 1)
            y = h - 1 - st
            cx = base_x + lean * t * t
            half = blade_w * (1 - t) * 0.5 + 0.3
            shade = ramp[min(int(t * len(ramp) * bright), len(ramp) - 1)]
            for x in range(int(round(cx - half)), int(round(cx + half)) + 1):
                if 0 <= x < w and 0 <= y < h:
                    img[y, x] = (*shade, 255)
    return Image.fromarray(img)


def leaf_clump(seed_offset: int, pal: list[tuple[int, int, int]] | None = None) -> Image.Image:
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
    pal = pal or LEAF_PALETTE
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


def bush(pal: list[tuple[int, int, int]] | None = None) -> Image.Image:
    """Low shrub: wide dome of dark foliage, lit rim on top, flat-ish base."""
    w, h = 64, 44
    rng = np.random.default_rng(20261011 + 40)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    mask = np.zeros((h, w), dtype=bool)
    for _ in range(12):
        cx = rng.uniform(w * 0.18, w * 0.82)
        cy = rng.uniform(h * 0.35, h * 0.75)
        r = rng.uniform(h * 0.22, h * 0.36)
        mask |= np.hypot(xx - cx, (yy - cy) * 1.15) < r
    mask &= yy < h - 1
    ragged = rng.random((h, w)) < 0.4
    edge = mask & ~np.roll(mask, 1, 0)
    mask &= ~(edge & ragged)
    light = 1 - yy / h
    v = np.clip(light * 0.75 + rng.random((h, w)) * 0.4 - 0.1, 0, 1)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    img[..., :3] = palette_map(v, pal or [(22, 42, 22), (32, 58, 26), (46, 78, 30), (64, 100, 36), (92, 128, 44), (126, 154, 58)])
    img[..., 3] = np.where(mask, 255, 0)
    return Image.fromarray(img)


def pine(pal: list[tuple[int, int, int]] = LEAF_GOLD_PALETTE) -> Image.Image:
    """Conifer: stacked drooping tiers, sunlit on the left, dark core."""
    w, h = 72, 112
    rng = np.random.default_rng(20261011 + 50)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    trunk_top = int(h * 0.8)
    for y in range(trunk_top, h):
        for x in range(w // 2 - 3, w // 2 + 3):
            img[y, x] = (*[(58, 40, 26), (78, 54, 34)][x % 2], 255)
    tiers = 6
    for t in range(tiers):
        top = int(h * 0.04 + t * h * 0.13)
        bottom = top + int(h * 0.24)
        for y in range(top, min(bottom, int(h * 0.86))):
            k = (y - top) / (bottom - top)
            half = (3 + (w * 0.5 - 4) * (0.35 + 0.65 * t / (tiers - 1))) * k
            for x in range(int(w / 2 - half), int(w / 2 + half) + 1):
                if not 0 <= x < w:
                    continue
                if k > 0.85 and rng.random() < 0.5:
                    continue
                side = (x - w / 2) / max(half, 1)
                v = np.clip(0.55 - side * 0.35 - k * 0.25 + rng.random() * 0.35, 0, 1)
                img[y, x] = (*palette_map(np.array([v]), pal)[0], 255)
    return Image.fromarray(img)


def rock(pal: list[tuple[int, int, int]] = STONE_PALETTE, crack: tuple[int, int, int] = (52, 54, 50)) -> Image.Image:
    """Tileable boulder surface: stone, cracks."""
    size = 64
    v = dither(0.6 * tile_noise(size, 4) + 0.4 * tile_noise(size, 16, 2), 0.12)
    rgb = palette_map(v, pal)
    cracks = np.abs(tile_noise(size, 8, 2) - 0.5) < 0.025
    rgb[cracks] = crack
    return Image.fromarray(rgb)


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


# ---------------------------------------------------------------------------
# Per-mission sets (2026-10-11: Foothills / Hollow / Narrows HD-2D profiles)
# ---------------------------------------------------------------------------

def water() -> Image.Image:
    """Tileable river surface: deep blue body, current streaks, white glints.

    The ground shader scrolls and sparkles it (lane_shimmer); the texture only
    carries the painted ripple pattern.
    """
    size = 128
    pal = [(20, 42, 66), (26, 56, 84), (34, 72, 102), (46, 92, 122), (66, 120, 148), (110, 162, 186)]
    xx = np.mgrid[0:size, 0:size][1].astype(float)
    streaks = np.sin((xx / size) * math.tau * 3 + tile_noise(size, 4) * 4.0) * 0.5 + 0.5
    v = dither(0.55 * tile_noise(size, 4) + 0.45 * streaks * tile_noise(size, 8, 2), 0.1)
    rgb = palette_map(v, pal)
    glint = (tile_noise(size, 16, 2) > 0.82) & (RNG.random((size, size)) < 0.08)
    rgb[glint] = (214, 232, 238)
    return Image.fromarray(rgb)


def reeds() -> Image.Image:
    """River reeds: tall thin olive stalks, a few brown cattail heads."""
    w, h = 40, 72
    rng = np.random.default_rng(20261011 + 60)
    img = np.zeros((h, w, 4), dtype=np.uint8)
    ramp = [(40, 54, 26), (58, 76, 32), (80, 98, 40), (108, 122, 52), (140, 146, 70)]
    for _ in range(16):
        x0 = rng.normal(w / 2, w / 6)
        height = int(rng.uniform(0.55, 0.98) * h)
        lean = rng.normal(0, 3.0)
        for st in range(height):
            t = st / max(height - 1, 1)
            x = int(round(x0 + lean * t * t))
            if 0 <= x < w:
                img[h - 1 - st, x] = (*ramp[min(int(t * len(ramp)), len(ramp) - 1)], 255)
        if rng.random() < 0.45:
            top = h - height
            x = int(round(x0 + lean))
            for y in range(max(top, 0), min(top + 6, h)):
                for dx, c in ((0, (92, 58, 34)), (1, (120, 78, 44))):
                    if 0 <= x + dx < w:
                        img[y, x + dx] = (*c, 255)
    return Image.fromarray(img)


FOOT_GRASS = [(96, 78, 40), (122, 100, 50), (146, 122, 62), (168, 142, 74), (188, 162, 88), (208, 184, 108)]
FOOT_DIRT = [(150, 132, 104), (172, 154, 124), (192, 174, 144), (210, 194, 164), (224, 210, 182), (236, 224, 200)]
FOOT_CARD = [(84, 66, 32), (110, 88, 40), (140, 114, 52), (168, 140, 66), (194, 166, 84), (218, 192, 110), (236, 216, 140)]
FOOT_STONE = [(96, 88, 76), (122, 112, 96), (148, 136, 116), (172, 160, 138), (194, 182, 160)]
FOOT_PINE = [(30, 46, 30), (42, 62, 36), (58, 82, 42), (80, 104, 50), (108, 128, 60), (142, 152, 76)]

HOLLOW_GROUND = [(22, 26, 32), (30, 36, 42), (38, 46, 52), (48, 58, 62), (58, 72, 72), (72, 90, 86)]
HOLLOW_LANE = [(38, 42, 52), (50, 56, 66), (62, 68, 80), (76, 82, 94), (92, 98, 112)]
HOLLOW_MOSS = [(34, 70, 82), (46, 96, 112), (70, 132, 150)]
HOLLOW_CARD = [(16, 30, 32), (22, 44, 46), (30, 62, 62), (42, 84, 80), (62, 112, 102), (92, 146, 130), (130, 182, 164)]
HOLLOW_LEAF = [(14, 24, 28), (20, 36, 40), (28, 50, 54), (38, 68, 70), (54, 92, 90), (78, 122, 116)]
HOLLOW_ROCK = [(34, 38, 46), (46, 50, 60), (60, 64, 76), (76, 80, 94), (94, 98, 114)]

NARROWS_GROUND = [(92, 46, 30), (116, 60, 38), (138, 76, 46), (158, 92, 56), (178, 110, 68), (196, 130, 84)]
NARROWS_CARD = [(52, 44, 22), (72, 62, 28), (96, 82, 36), (122, 104, 46), (148, 126, 60), (174, 150, 80), (198, 176, 104)]
NARROWS_ROCK = [(86, 44, 30), (110, 58, 38), (134, 74, 48), (156, 92, 60), (176, 112, 76)]
NARROWS_STONE = [(112, 80, 62), (138, 102, 78), (160, 122, 94), (182, 144, 112), (200, 166, 132)]
NARROWS_SHRUB = [(40, 40, 20), (56, 56, 26), (74, 72, 32), (96, 92, 40), (120, 112, 52), (146, 136, 68)]


def mission_sets() -> None:
    # The Foothills: dry golden grassland, sandy road, pale stone.
    save(ground_grass(FOOT_GRASS, 700), "foothills_ground.png")
    save(ground_dirt(FOOT_DIRT, 140), "foothills_lane.png")
    save(stone_flags(FOOT_STONE, (70, 62, 52), [(120, 112, 60), (140, 130, 70), (160, 150, 84)], 0.7), "foothills_stone.png")
    save(grass_blades(64, 64, 60, (1.0, 2.0), 20, FOOT_CARD), "foothills_card_grass.png")
    save(grass_blades(48, 30, 30, (1.0, 2.0), 21, FOOT_CARD), "foothills_card_grass_short.png")
    save(pine(FOOT_PINE), "foothills_card_pine.png")
    save(leaf_clump(22, LEAF_GOLD_PALETTE), "foothills_card_leaves.png")
    save(rock(FOOT_STONE, (78, 70, 58)), "foothills_mat_rock.png")
    # The Hollow: dark slate floor with teal moss, cobbled lane; crystals are 3D.
    save(ground_grass(HOLLOW_GROUND, 500), "hollow_ground.png")
    save(stone_flags(HOLLOW_LANE, (16, 18, 24), HOLLOW_MOSS, 0.74), "hollow_lane.png")
    save(stone_flags(HOLLOW_ROCK, (14, 16, 20), HOLLOW_MOSS, 0.6), "hollow_stone.png")
    save(grass_blades(64, 64, 46, (1.0, 2.4), 30, HOLLOW_CARD), "hollow_card_fern.png")
    save(leaf_clump(31, HOLLOW_LEAF), "hollow_card_leaves.png")
    save(bush(HOLLOW_LEAF), "hollow_card_bush.png")
    save(rock(HOLLOW_ROCK, (18, 20, 26)), "hollow_mat_rock.png")
    # The Narrows: red canyon earth, river lane, reeds, red rock spires.
    save(ground_dirt(NARROWS_GROUND, 160), "narrows_ground.png")
    save(water(), "narrows_lane.png")
    save(stone_flags(NARROWS_STONE, (70, 42, 30), [(96, 92, 40), (120, 112, 52), (146, 136, 68)], 0.72), "narrows_stone.png")
    save(grass_blades(48, 40, 26, (1.0, 2.0), 40, NARROWS_CARD), "narrows_card_scrub.png")
    save(reeds(), "narrows_card_reeds.png")
    save(bush(NARROWS_SHRUB), "narrows_card_bush.png")
    save(rock(NARROWS_ROCK, (64, 32, 22)), "narrows_mat_rock.png")


# ---------------------------------------------------------------------------
# Photo-sourced material textures (2026-10-15). CC0 Poly Haven scans under
# assets/source/kits/polyhaven_ground/ are reduced to 64 px pixel art in the
# project palettes: the scan supplies believable structure (cracks, pebbles,
# moss growth), the palette keeps the HD-2D read. Used by the Kenney kit
# meshes (Hd2dScenery kit props). Poly Haven scans are seamless, and a box
# downscale of a seamless image stays seamless.
# ---------------------------------------------------------------------------

PHOTO_DIR = os.path.join("assets", "source", "kits", "polyhaven_ground")


def _photo(name: str, size: int) -> np.ndarray:
    """Scan as float RGB in [0, 1], box-downscaled to size x size."""
    img = Image.open(os.path.join(PHOTO_DIR, f"{name}_diff_1k.jpg")).convert("RGB")
    return np.asarray(img.resize((size, size), Image.BOX), dtype=np.float32) / 255.0


def _stretch(v: np.ndarray, lo: float = 3.0, hi: float = 97.0) -> np.ndarray:
    """Percentile contrast stretch to [0, 1] (scans are flat-lit and murky)."""
    a, b = np.percentile(v, [lo, hi])
    return np.clip((v - a) / max(b - a, 1e-6), 0.0, 1.0)


def photo_stone(name: str, pal: list[tuple[int, int, int]], size: int = 64) -> Image.Image:
    """A scan's luminance mapped onto a stone palette."""
    rgb = _photo(name, size)
    lum = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    return Image.fromarray(palette_map(dither(_stretch(lum), 0.05), pal))


def photo_moss_stone(name: str, stone: list[tuple[int, int, int]], moss: list[tuple[int, int, int]],
                     size: int = 64) -> Image.Image:
    """Like photo_stone, but pixels the scan shows as green growth take the
    moss palette -- the overgrown-ruin read of the reference's columns."""
    rgb = _photo(name, size)
    lum = _stretch(rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32))
    green = rgb[..., 1] - 0.5 * (rgb[..., 0] + rgb[..., 2])
    v = dither(lum, 0.05)
    out = palette_map(v, stone)
    mask = green > np.percentile(green, 62)
    out[mask] = palette_map(v, moss)[mask]
    return Image.fromarray(out)


def photo_sets() -> None:
    save(photo_stone("rocks_ground_02", STONE_PALETTE), "kit_rock.png")
    save(photo_moss_stone("mossy_rock", STONE_PALETTE, MOSS_PALETTE), "kit_ruin_stone.png")
    save(photo_stone("rocky_terrain_02", FOOT_STONE), "foothills_kit_rock.png")
    save(photo_moss_stone("mossy_rock", HOLLOW_ROCK, HOLLOW_MOSS), "hollow_kit_rock.png")
    save(photo_stone("rocky_trail", NARROWS_ROCK), "narrows_kit_rock.png")
    # Opaque needle/leaf mass for the kit's 3D pines (the leaf cards are
    # cut-out sprites and cannot wrap a solid canopy).
    save(foliage_mass(LEAF_PALETTE), "kit_foliage.png")
    save(foliage_mass(FOOT_PINE), "foothills_kit_foliage.png")
    save(foliage_mass(HOLLOW_LEAF), "hollow_kit_foliage.png")


def foliage_mass(pal: list[tuple[int, int, int]]) -> Image.Image:
    """Tileable opaque foliage: clumpy light/dark masses with needle speckle."""
    size = 64
    # Summed noise clusters around 0.5; stretch it so the whole palette (dark
    # hollows to sunlit tips) shows up on a solid cone.
    v = dither(_stretch(0.55 * tile_noise(size, 6) + 0.45 * tile_noise(size, 24, 2), 2.0, 98.0), 0.14)
    return Image.fromarray(palette_map(v, pal))


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    save(ground_grass(), "ground_grass.png")
    save(ground_dirt(), "ground_dirt.png")
    save(stone_flags(), "ground_stone.png")
    save(grass_blades(64, 64, 70, (1.0, 2.2), 10), "card_grass.png")
    save(grass_blades(48, 30, 34, (1.0, 2.0), 11), "card_grass_short.png")
    for i in range(3):
        save(leaf_clump(i), f"card_leaves_{i}.png")
    save(leaf_clump(3, LEAF_GOLD_PALETTE), "card_leaves_gold.png")
    save(bush(), "card_bush.png")
    save(pine(), "card_pine.png")
    save(rock(), "mat_rock.png")
    save(flowers(), "card_flowers.png")
    save(bark(), "mat_bark.png")
    save(wood_plank(), "mat_wood.png")
    save(ruin_bricks(), "mat_ruin_bricks.png")
    mission_sets()
    photo_sets()


if __name__ == "__main__":
    main()
