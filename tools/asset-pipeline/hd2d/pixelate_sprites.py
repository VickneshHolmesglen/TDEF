"""Pixel-art conversion for painted sprites (HD-2D unit pass, 2026-10-12).

Turns a painted RGBA sprite into an HD-2D-style pixel sprite:
  1. local-contrast boost (unsharp at about the output block size) -- painted
     sprites read through small highlights that a plain downscale averages away
  2. premultiplied downscale to a low pixel resolution (transparent pixels
     must not bleed black into edge colours)
  3. half-strength per-sprite value stretch, palette reduction (median cut
     over opaque pixels only), hard 1-bit alpha
  4. a 1 px outline tinted from the neighbouring colour

`pixelate_same_size()` then scales the result back up with hard pixel edges to
the source's EXACT dimensions, so nothing that reads texture sizes has to
change: frame slicing (`atlas_columns`), hero gear overlays (same canvas as the
body), tower layer stacking (painted-bounds read from pixels) and every
"scale to TARGET size" computation. Sheets are converted frame by frame and
share one palette, so animation does not flicker.

Painted originals live in assets/source/painted/ (same relative paths) and are
always the input of --batch, so re-running never pixelates twice.

    python tools/asset-pipeline/hd2d/pixelate_sprites.py --batch            # convert everything
    python tools/asset-pipeline/hd2d/pixelate_sprites.py --preview OUT.png SRC.png [...]
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import shutil

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ART = os.path.join("assets", "art")
ORIGINALS = os.path.join("assets", "source", "painted")
ATLAS_DIR = os.path.join("assets", "data", "creature_atlases")


# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

def downscale(img: Image.Image, w: int, h: int) -> np.ndarray:
    """Contrast-preserving premultiplied downscale -> uint8 RGBA array (h, w, 4)."""
    img = img.convert("RGBA")
    block = max(1.0, img.height / h)
    rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=block * 0.9, percent=160, threshold=2))
    rgb = ImageEnhance.Color(rgb).enhance(1.12)
    f = np.array(Image.merge("RGBA", (*rgb.split(), img.getchannel("A")))).astype(np.float32) / 255.0
    alpha = f[..., 3:4]
    prem = np.concatenate([f[..., :3] * alpha, alpha], axis=2)
    chans = [Image.fromarray(prem[..., i]).resize((w, h), Image.LANCZOS) for i in range(4)]
    small = np.stack([np.array(c) for c in chans], axis=2)
    sa = small[..., 3:4]
    rgb_small = np.where(sa > 1e-4, small[..., :3] / np.maximum(sa, 1e-4), 0.0)
    return (np.clip(np.concatenate([rgb_small, sa], axis=2), 0.0, 1.0) * 255.0).astype(np.uint8)


def finish(a: np.ndarray, colors: int, outline: bool = True) -> np.ndarray:
    """Value stretch, palette, 1-bit alpha and outline on a low-res RGBA array.

    Returns an array padded by 1 px on every side when `outline` is set (the
    outline needs room; callers crop it back off for same-size output).
    """
    a = a.copy()
    opaque = a[..., 3] >= 128
    if opaque.any():
        lum = a[..., :3].astype(np.float32) @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        lo, hi = np.percentile(lum[opaque], [2, 98])
        if hi - lo > 8:
            target = (np.clip(lum, lo, hi) - lo) / (hi - lo) * 190.0 + 28.0
            # Half-strength: a full stretch pushed dark warm paint to orange.
            gain = 1.0 + (target / np.maximum(lum, 1.0) - 1.0) * 0.45
            a[..., :3] = np.clip(a[..., :3].astype(np.float32) * gain[..., None], 0, 255).astype(np.uint8)
        flat = a[opaque][:, :3].reshape(-1, 1, 3)
        pal_img = Image.fromarray(flat.astype(np.uint8)).quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
        a[opaque, :3] = np.array(pal_img.convert("RGB")).reshape(-1, 3)
    a[..., 3] = np.where(opaque, 255, 0)
    if not outline:
        return a
    pad = 1
    out = np.zeros((a.shape[0] + 2 * pad, a.shape[1] + 2 * pad, 4), dtype=np.uint8)
    out[pad:-pad, pad:-pad] = a
    op = out[..., 3] > 0
    ring = np.zeros_like(op)
    acc = np.zeros(out.shape[:2] + (3,), dtype=np.float32)
    cnt = np.zeros(out.shape[:2], dtype=np.float32)
    rgbf = out[..., :3].astype(np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        shifted = np.roll(np.roll(op, dy, 0), dx, 1)
        rgb_s = np.roll(np.roll(rgbf, dy, 0), dx, 1)
        hit = shifted & ~op
        ring |= hit
        acc[hit] += rgb_s[hit]
        cnt[hit] += 1
    cnt[cnt == 0] = 1
    out[ring, :3] = (acc[ring] / cnt[ring][:, None] * 0.28).astype(np.uint8)
    out[ring, 3] = 255
    return out


def pixelate(src: Image.Image, height: int, colors: int = 20, outline: bool = True) -> Image.Image:
    """Cropped low-res pixel sprite `height` px tall (used by --preview)."""
    img = src.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    w = max(1, round(img.width * height / img.height))
    return Image.fromarray(finish(downscale(img, w, height), colors, outline))


def pixelate_same_size(src: Image.Image, low_w: int, low_h: int, colors: int, columns: int = 1) -> Image.Image:
    """Pixelate to a (low_w * columns) x low_h grid, then back to src's exact size.

    `low_w` is per frame. With columns > 1 the source is a one-row sheet: each
    frame is downscaled on its own (so no frame bleeds into the next), the
    frames share one palette, and each low-res frame is scaled back to exactly
    its original frame rectangle.
    """
    img = src.convert("RGBA")
    W, H = img.size
    bounds = [round(i * W / columns) for i in range(columns + 1)]
    lows = [downscale(img.crop((bounds[i], 0, bounds[i + 1], H)), low_w, low_h) for i in range(columns)]
    done = finish(np.concatenate(lows, axis=1), colors, outline=True)[1:-1, 1:-1]
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for i in range(columns):
        frame = Image.fromarray(done[:, i * low_w:(i + 1) * low_w])
        out.paste(frame.resize((bounds[i + 1] - bounds[i], H), Image.NEAREST), (bounds[i], 0))
    return out


# ---------------------------------------------------------------------------
# Batch rules: low-res size per category, from each sprite's on-screen size
# (about 1.4 screen px per sprite pixel, matching the scenery's chunkiness)
# ---------------------------------------------------------------------------

def _atlas_columns() -> dict[str, int]:
    cols: dict[str, int] = {}
    for p in glob.glob(os.path.join(ATLAS_DIR, "*.tres")):
        s = open(p, encoding="utf-8").read()
        tex = re.search(r'path="res://(assets/art/[^"]+\.png)"', s)
        col = re.search(r"atlas_columns = (\d+)", s)
        if tex and col:
            cols[os.path.normpath(tex.group(1))] = int(col.group(1))
    return cols


def _fit(w: int, h: int, long_edge: int) -> tuple[int, int]:
    s = long_edge / max(w, h)
    return max(1, round(w * s)), max(1, round(h * s))


def plan(rel: str, size: tuple[int, int], columns: int) -> tuple[int, int, int]:
    """(low_w per frame, low_h, colors) for an art file at assets/art-relative `rel`."""
    W, H = size
    fw = W / columns
    name = os.path.basename(rel)
    folder = rel.replace("\\", "/").split("/")[0]
    if folder == "characters":
        # Body and every gear overlay share one 1024x1536 canvas; same grid.
        return round(W * 44 / H), 44, 20
    if folder == "monsters":
        long_edge = 80 if "boss" in name else 46
        lw, lh = _fit(round(fw), H, long_edge)
        return lw, lh, 28 if "boss" in name else 20
    if folder == "towers":
        if re.match(r"tower_(base|shaft|top|modular)_", name):
            # Stacked pieces are fitted to a common width, so width-based
            # sizing keeps the pixel density equal across base/shaft/top.
            return 40, max(1, round(H * 40 / W)), 18
        lw, lh = _fit(W, H, 48)
        return lw, lh, 20
    if folder == "items":
        lw, lh = _fit(W, H, 36)
        return lw, lh, 16
    if folder == "sanctuary":
        # Town buildings show at ~150 px in the diorama.
        lw, lh = _fit(W, H, 96)
        return lw, lh, 28
    if folder == "species":
        lw, lh = _fit(W, H, 64)
        return lw, lh, 24
    raise ValueError(f"no rule for {rel}")


BATCH_GLOBS = ["characters/*.png", "characters/gear/*.png", "monsters/*.png",
               "towers/*.png", "items/*.png", "species/*.png",
               "sanctuary/*.png", "sanctuary/town/*.png"]
# Not sprites: painted fallback backdrops stay as they are.
BATCH_SKIP = ("background",)


def batch() -> None:
    columns = _atlas_columns()
    done = 0
    for g in BATCH_GLOBS:
        for art_path in sorted(glob.glob(os.path.join(ART, g))):
            if any(k in os.path.basename(art_path) for k in BATCH_SKIP):
                continue
            rel = os.path.relpath(art_path, ART)
            original = os.path.join(ORIGINALS, rel)
            if not os.path.exists(original):
                os.makedirs(os.path.dirname(original), exist_ok=True)
                shutil.copy2(art_path, original)  # first run: keep the painted original
            src = Image.open(original)
            cols = columns.get(os.path.normpath(art_path).replace("\\", "/"), columns.get(os.path.normpath(art_path), 1))
            lw, lh, colors = plan(rel, src.size, cols)
            pixelate_same_size(src, lw, lh, colors, cols).save(art_path, optimize=True)
            done += 1
            print(f"{rel}: {src.size} -> {lw * cols}x{lh} px grid ({cols} frame{'s' if cols > 1 else ''})")
    print(f"converted {done} sprites; painted originals in {ORIGINALS}")


def preview(paths: list[str], out_path: str, heights: tuple[int, ...] = (20, 32, 44)) -> None:
    """Sheet: original (scaled to the tallest preview) then each pixel height, all at 4x."""
    zoom = 4
    tiles: list[list[Image.Image]] = []
    for p in paths:
        src = Image.open(p).convert("RGBA")
        row = []
        h0 = max(heights) * zoom
        orig = src.crop(src.getbbox() or (0, 0, src.width, src.height))
        row.append(orig.resize((round(orig.width * h0 / orig.height), h0), Image.LANCZOS))
        for h in heights:
            px = pixelate(src, h)
            row.append(px.resize((px.width * zoom, px.height * zoom), Image.NEAREST))
        tiles.append(row)
    col_w = [max(r[i].width for r in tiles) + 16 for i in range(len(tiles[0]))]
    row_h = [max(t.height for t in r) + 16 for r in tiles]
    sheet = Image.new("RGBA", (sum(col_w), sum(row_h) + 24), (58, 84, 40, 255))
    d = ImageDraw.Draw(sheet)
    labels = ["painted (now)"] + [f"{h}px tall" for h in heights]
    x = 0
    for i, lab in enumerate(labels):
        d.text((x + 6, 4), lab, fill=(255, 255, 255, 255))
        x += col_w[i]
    y = 24
    for r, row in enumerate(tiles):
        x = 0
        for i, t in enumerate(row):
            sheet.alpha_composite(t, (x + 8, y + row_h[r] - t.height - 8))
            x += col_w[i]
        y += row_h[r]
    sheet.save(out_path)
    print("wrote", out_path)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--batch", action="store_true")
    ap.add_argument("--preview")
    ap.add_argument("srcs", nargs="*")
    args = ap.parse_args()
    if args.batch:
        batch()
    elif args.preview:
        preview(args.srcs, args.preview)
    else:
        ap.error("use --batch or --preview")


if __name__ == "__main__":
    main()
