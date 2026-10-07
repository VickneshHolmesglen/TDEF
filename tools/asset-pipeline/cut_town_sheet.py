"""Alpha-cut a 5-tier Sanctuary town-building sheet on #FF00FF into per-tier PNGs.

usage (from the project root):
  python tools/asset-pipeline/cut_town_sheet.py assets/source/sanctuary/town/sanctuary_<id>_sheet.png <id> [check.png] [--distance-key]

Writes assets/art/sanctuary/town/<id>_tier_1..5.png. Keys on magenta excess
(min(R,B) - G) rather than colour distance, because the generator tints the
ground shadows magenta (e.g. (107,21,94)); those become a soft black shadow.
The edge pixels are despilled. Tiers = the 5 largest solid blobs, left to right;
every tier is padded bottom-centre onto ONE shared canvas so relative size
(tier 1 small, tier 5 big) survives the aspect-fit into the building
footprint. Set the building's footprint to the printed canvas aspect.
--distance-key: for buildings whose own palette is violet/magenta (the
Seer's Tower), where magenta excess would eat the roofs. Keys on plain colour
distance from #FF00FF instead and un-premultiplies the magenta (no shadow).
The optional check.png composites all tiers on green to spot fringe.
See design/art/sanctuary-town-buildings-prompts.md section 3."""
import sys
from PIL import Image
import numpy as np
from scipy import ndimage
distance_key = '--distance-key' in sys.argv
args = [a for a in sys.argv[1:] if a != '--distance-key']
src, bid = args[0], args[1]
im = np.asarray(Image.open(src).convert('RGB')).astype(float)
r, g, b = im[..., 0], im[..., 1], im[..., 2]
spill = np.minimum(r, b) - g
def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
w = smooth(25, 70, spill)
if distance_key:
    distance = np.sqrt((r - 255) ** 2 + g ** 2 + (b - 255) ** 2)
    w = 1 - smooth(40, 120, distance)
shadow_a = np.clip((250 - np.maximum(r, b)) / 250, 0, 1) * 0.55
excess = np.clip(spill, 0, None)
bld = 1 - w
out_a = bld + w * shadow_a
safe = np.where(out_a > 1e-4, out_a, 1)
rgb = np.stack([np.clip(r - excess, 0, 255), g, np.clip(b - excess, 0, 255)], -1) * (bld / safe)[..., None]
if distance_key:
    out_a = 1 - w
    safe = np.where(out_a > 1e-4, out_a, 1)
    rgb = np.clip((im - w[..., None] * np.array([255, 0, 255])) / safe[..., None], 0, 255)
rgba = np.dstack([rgb, out_a * 255]).clip(0, 255).astype(np.uint8)
# Tiers = the 5 largest solid-building blobs; every other visible pixel
# (shadow, a detached flag tip) belongs to whichever blob is nearest.
solid = bld > 0.5
lab, n = ndimage.label(solid)
sizes = ndimage.sum(solid, lab, range(1, n + 1))
keep = sorted((np.argsort(sizes)[::-1][:5] + 1), key=lambda k: np.where(lab == k)[1].mean())
seed = np.where(np.isin(lab, keep), lab, 0)
dist, (iy, ix) = ndimage.distance_transform_edt(seed == 0, return_indices=True)
owner = seed[iy, ix]
crops = []
for k in keep:
    m = (owner == k) & (dist < 60) & (rgba[..., 3] > 0)
    a = rgba.copy(); a[~m] = 0
    ys, xs = np.where(a[..., 3] > 12)
    crops.append(a[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
W = max(c.shape[1] for c in crops) + 8; H = max(c.shape[0] for c in crops) + 4
print('canvas', W, H, [c.shape[:2] for c in crops])
for i, c in enumerate(crops):
    can = np.zeros((H, W, 4), np.uint8)
    h, wd = c.shape[:2]; x0 = (W - wd) // 2; y0 = H - 2 - h
    can[y0:y0 + h, x0:x0 + wd] = c
    Image.fromarray(can).save(f'assets/art/sanctuary/town/{bid}_tier_{i + 1}.png')
sheet = Image.new('RGBA', (W * 5, H), (120, 200, 120, 255))
for i in range(5):
    sheet.alpha_composite(Image.open(f'assets/art/sanctuary/town/{bid}_tier_{i + 1}.png'), (i * W, 0))
sheet.save(args[2] if len(args) > 2 else 'check.png')
