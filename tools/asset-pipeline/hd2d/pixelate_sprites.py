"""Pixel-art conversion for painted sprites (HD-2D unit pass, 2026-10-12).

Turns a painted RGBA sprite into an HD-2D-style pixel sprite:
  1. crop to the opaque bounds
  2. downscale to a target height in pixels (area-averaged, so detail is
     summarised rather than aliased)
  3. hard alpha cut (no soft edges -- pixel sprites are 1-bit alpha)
  4. palette reduction (median cut over the opaque pixels only)
  5. a 1 px dark outline, tinted from the neighbouring colour rather than
     flat black, which is how HD-2D sprites separate from busy scenery

Usage (comparison sheet, nothing in assets/ is touched):
    python tools/asset-pipeline/hd2d/pixelate_sprites.py --preview OUT.png SRC.png [SRC.png ...]
Usage (write converted sprites next to a target dir):
    python tools/asset-pipeline/hd2d/pixelate_sprites.py --height 40 --out DIR SRC.png [...]
"""
from __future__ import annotations

import argparse
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter


def pixelate(src: Image.Image, height: int, colors: int = 20, outline: bool = True) -> Image.Image:
    img = src.convert("RGBA")
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    # Painted sprites read through small bright highlights over a dark mean
    # (the hero's armour averages to brown); a plain downscale averages those
    # highlights away. Unsharp-mask at roughly the output block size first so
    # local contrast survives, then lift saturation a touch.
    block = max(1.0, img.height / height)
    rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=block * 0.9, percent=160, threshold=2))
    rgb = ImageEnhance.Color(rgb).enhance(1.12)
    img = Image.merge("RGBA", (*rgb.split(), img.getchannel("A")))

    pad = 1 if outline else 0
    w = max(1, round(img.width * height / img.height))
    # Premultiplied downscale: a plain RGBA resize averages the black of
    # fully transparent pixels into every edge colour, which turned thin
    # figures (the hero) brown and greens olive in the first test.
    f = np.array(img).astype(np.float32) / 255.0
    alpha = f[..., 3:4]
    prem = np.concatenate([f[..., :3] * alpha, alpha], axis=2)
    chans = [Image.fromarray(prem[..., i]).resize((w, height), Image.LANCZOS) for i in range(4)]
    small = np.stack([np.array(c) for c in chans], axis=2)
    sa = small[..., 3:4]
    rgb_small = np.where(sa > 1e-4, small[..., :3] / np.maximum(sa, 1e-4), 0.0)
    a = np.concatenate([rgb_small, sa], axis=2)
    a = (np.clip(a, 0.0, 1.0) * 255.0).astype(np.uint8)
    opaque = a[..., 3] >= 128

    # Per-sprite value stretch: map the 2nd..98th luminance percentile of the
    # opaque pixels to a fuller range, so small sprites keep their highlights.
    if opaque.any():
        lum = a[..., :3].astype(np.float32) @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
        lo, hi = np.percentile(lum[opaque], [2, 98])
        if hi - lo > 8:
            target = (np.clip(lum, lo, hi) - lo) / (hi - lo) * 190.0 + 28.0
            # Half-strength: a full stretch pushed dark warm paint to orange.
            gain = 1.0 + (target / np.maximum(lum, 1.0) - 1.0) * 0.45
            a[..., :3] = np.clip(a[..., :3].astype(np.float32) * gain[..., None], 0, 255).astype(np.uint8)

    # Palette reduction over opaque pixels only (transparent pixels would
    # otherwise steal palette slots).
    flat = a[opaque][:, :3].reshape(-1, 1, 3)
    if len(flat) > 0:
        pal_img = Image.fromarray(flat.astype(np.uint8)).quantize(colors=colors, method=Image.Quantize.MEDIANCUT)
        a[opaque, :3] = np.array(pal_img.convert("RGB")).reshape(-1, 3)
    a[..., 3] = np.where(opaque, 255, 0)

    out = np.zeros((height + pad * 2, w + pad * 2, 4), dtype=np.uint8)
    out[pad:pad + height, pad:pad + w] = a
    if outline:
        op = out[..., 3] > 0
        ring = np.zeros_like(op)
        acc = np.zeros(out.shape[:2] + (3,), dtype=np.float32)
        cnt = np.zeros(out.shape[:2], dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(np.roll(op, dy, 0), dx, 1)
            rgb_s = np.roll(np.roll(out[..., :3].astype(np.float32), dy, 0), dx, 1)
            hit = shifted & ~op
            ring |= hit
            acc[hit] += rgb_s[hit]
            cnt[hit] += 1
        cnt[cnt == 0] = 1
        out[ring, :3] = (acc[ring] / cnt[ring][:, None] * 0.28).astype(np.uint8)
        out[ring, 3] = 255
    return Image.fromarray(out)


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
    ap.add_argument("--preview")
    ap.add_argument("--height", type=int, default=40)
    ap.add_argument("--colors", type=int, default=20)
    ap.add_argument("--out")
    ap.add_argument("srcs", nargs="+")
    args = ap.parse_args()
    if args.preview:
        preview(args.srcs, args.preview)
        return
    os.makedirs(args.out, exist_ok=True)
    for p in args.srcs:
        dst = os.path.join(args.out, os.path.basename(p))
        pixelate(Image.open(p), args.height, args.colors).save(dst)
        print("wrote", dst)


if __name__ == "__main__":
    main()
