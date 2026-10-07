"""Extract a fitted hero-gear overlay from an image EDIT of the base body.

usage (from the project root):
  python tools/asset-pipeline/extract_worn_overlay.py <base.png> <edit.png> <out.png>
         [--threshold 40] [--min-area 400] [--check check.png]
  python tools/asset-pipeline/extract_worn_overlay.py --base-only <base_raw.png> <out.png>

Hero equipment appearance spec (docs/superpowers/specs/2026-10-07-hero-
equipment-appearance-design.md) section 4. Codex renders the bare base body, then each item
as an edit of it ("same character, now wearing X, change nothing else"),
both on flat #FF00FF. This keeps only what the edit changed, so the overlay
lines up with the base body by construction:

1. Both images are keyed off magenta (magenta-excess key, as in cut_town_sheet.py).
2. The edit is resized to the base canvas and aligned to it by phase
   correlation (edits often drift a few pixels).
3. The per-pixel difference is smoothed and thresholded; speckle smaller than
   --min-area is dropped, holes are filled and the edge is feathered.
4. Output: the edit's pixels under that mask, on the base canvas (RGBA).

--base-only keys the raw base render off magenta and writes the engine base
body (assets/art/characters/hero_base_body.png).
--check writes base | edit | base+overlay on green, side by side, to eyeball.
"""
import argparse
from PIL import Image
import numpy as np
from scipy import ndimage


def key_magenta(rgb):
    """RGB float array -> (despilled rgb, alpha 0..1)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    spill = np.minimum(r, b) - g
    t = np.clip((spill - 25) / 45, 0, 1)
    w = t * t * (3 - 2 * t)                 # 1 = background
    excess = np.clip(spill, 0, None)
    out = np.stack([np.clip(r - excess, 0, 255), g, np.clip(b - excess, 0, 255)], -1)
    return out, 1 - w


def load_keyed(path, size=None):
    im = Image.open(path).convert('RGBA')
    if size is not None and im.size != size:
        im = im.resize(size, Image.LANCZOS)
    arr = np.asarray(im).astype(float)
    if (arr[..., 3] < 250).mean() > 0.05:     # already has real transparency
        return arr[..., :3], arr[..., 3] / 255
    return key_magenta(arr[..., :3])


def phase_shift(a, b, limit=24):
    """Integer (dy, dx) that best moves b onto a."""
    fa, fb = np.fft.fft2(a), np.fft.fft2(b)
    r = fa * np.conj(fb)
    r /= np.abs(r) + 1e-9
    corr = np.abs(np.fft.ifft2(r))
    dy, dx = np.unravel_index(np.argmax(corr), corr.shape)
    h, w = a.shape
    dy = dy - h if dy > h // 2 else dy
    dx = dx - w if dx > w // 2 else dx
    if abs(dy) > limit or abs(dx) > limit:
        return 0, 0
    return int(dy), int(dx)


def save_rgba(rgb, alpha, path):
    Image.fromarray(np.dstack([rgb, alpha * 255]).clip(0, 255).astype(np.uint8)).save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('paths', nargs='+')
    ap.add_argument('--threshold', type=float, default=40)
    ap.add_argument('--min-area', type=int, default=400)
    ap.add_argument('--check')
    ap.add_argument('--base-only', action='store_true')
    a = ap.parse_args()

    if a.base_only:
        rgb, alpha = load_keyed(a.paths[0])
        save_rgba(rgb, alpha, a.paths[1])
        return

    base_path, edit_path, out_path = a.paths
    base_rgb, base_a = load_keyed(base_path)
    size = (base_rgb.shape[1], base_rgb.shape[0])
    edit_rgb, edit_a = load_keyed(edit_path, size)

    # Align on luminance x alpha so the background doesn't dominate.
    lum = lambda rgb, al: rgb.mean(-1) * al
    dy, dx = phase_shift(lum(base_rgb, base_a), lum(edit_rgb, edit_a))
    if dy or dx:
        edit_rgb = np.roll(edit_rgb, (dy, dx), (0, 1))
        edit_a = np.roll(edit_a, (dy, dx), (0, 1))

    diff = np.abs(edit_rgb * edit_a[..., None] - base_rgb * base_a[..., None]).max(-1)
    diff = np.maximum(diff, np.abs(edit_a - base_a) * 255)
    diff = ndimage.gaussian_filter(diff, 1.5)
    mask = (diff > a.threshold) & (edit_a > 0.5)
    mask = ndimage.binary_opening(mask, iterations=2)
    mask = ndimage.binary_closing(mask, iterations=4)
    mask = ndimage.binary_fill_holes(mask)
    lab, n = ndimage.label(mask)
    if n:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        mask = np.isin(lab, np.where(sizes >= a.min_area)[0] + 1)
    alpha = np.clip(ndimage.gaussian_filter(mask.astype(float), 1.0) * 1.4, 0, 1) * edit_a
    save_rgba(edit_rgb, alpha, out_path)

    ys, xs = np.where(alpha > 0.05)
    bbox = (xs.min(), ys.min(), xs.max(), ys.max()) if len(xs) else None
    print(f'shift=({dy},{dx}) overlay_px={int((alpha > 0.5).sum())} bbox={bbox}')

    if a.check:
        h, w = base_a.shape
        green = np.array([120, 200, 120], float)
        def over(rgb, al):
            return rgb * al[..., None] + green * (1 - al[..., None])
        combo_a = np.clip(base_a + alpha, 0, 1)
        combo_rgb = (edit_rgb * alpha[..., None] + base_rgb * (base_a * (1 - alpha))[..., None]) / np.maximum(combo_a, 1e-6)[..., None]
        sheet = np.concatenate([over(base_rgb, base_a), over(edit_rgb, edit_a), over(combo_rgb, combo_a)], 1)
        Image.fromarray(sheet.clip(0, 255).astype(np.uint8)).save(a.check)


if __name__ == '__main__':
    main()
