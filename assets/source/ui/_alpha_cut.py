"""Alpha-cut a flat/gradient background via border flood-fill on edge magnitude.
Usage: python _alpha_cut.py <in.png> <out.png> [edge_threshold=14] [close_iters=2]
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

def alpha_cut(in_path, out_path, edge_threshold=14, close_iters=2, min_component_frac=0.02, final_open_iters=1, feather=1.2):
    im = Image.open(in_path).convert("RGB")
    arr = np.asarray(im).astype(np.float32)
    gray = arr.mean(axis=2)
    gray_smooth = ndimage.gaussian_filter(gray, sigma=3)

    gx = ndimage.sobel(gray_smooth, axis=1)
    gy = ndimage.sobel(gray_smooth, axis=0)
    mag = np.hypot(gx, gy)

    wall = mag > edge_threshold
    # remove thin speckle walls (checker-pattern / compression noise) that are
    # only 1-2px wide, while real object-boundary edges (thicker, with shadow)
    # survive the open/close pair
    wall = ndimage.binary_opening(wall, iterations=2)
    # thicken walls slightly so faint drop-shadow gradients still seal the boundary
    wall = ndimage.binary_dilation(wall, iterations=close_iters)

    passable = ~wall
    labels, _ = ndimage.label(passable, structure=np.ones((3, 3)))

    h, w = gray.shape
    border_labels = set(labels[0, :].tolist()) | set(labels[-1, :].tolist()) | \
        set(labels[:, 0].tolist()) | set(labels[:, -1].tolist())
    border_labels.discard(0)

    bg_mask = np.isin(labels, list(border_labels))
    # pixels that are literal wall AND touch background on both sides can stay background
    # only the interior (non-background, non-reachable-from-border) becomes opaque
    obj_mask = ~bg_mask

    # drop speckle: discard connected opaque components smaller than min_component_frac
    # of the largest one (checker-pattern residue/compression noise survives as tiny
    # isolated islands) while keeping every real object on a multi-object sheet
    obj_labels, n = ndimage.label(obj_mask, structure=np.ones((3, 3)))
    if n > 0:
        sizes = ndimage.sum(obj_mask, obj_labels, index=range(1, n + 1))
        keep_min = sizes.max() * min_component_frac
        keep_ids = [i + 1 for i, s in enumerate(sizes) if s >= keep_min]
        obj_mask = np.isin(obj_labels, keep_ids)

    # smooth ragged boundary noise left by the threshold (checker-pattern residue
    # fused onto the real object's edge survives the component-size filter since
    # it's touching the object, not isolated -- shave it with a stronger opening)
    obj_mask = ndimage.binary_closing(obj_mask, iterations=2)
    obj_mask = ndimage.binary_opening(obj_mask, iterations=final_open_iters)

    alpha_f = np.where(obj_mask, 255.0, 0.0)
    if feather > 0:
        # soften the hard threshold edge into a smooth falloff -- turns jagged
        # per-pixel cutoff noise (checker-pattern remnants at the boundary) into
        # a clean antialiased/soft-shadow-like edge instead of a ragged line
        alpha_f = ndimage.gaussian_filter(alpha_f, sigma=feather)
    alpha = np.clip(alpha_f, 0, 255).astype(np.uint8)

    rgba = np.dstack([arr.astype(np.uint8), alpha])
    Image.fromarray(rgba, mode="RGBA").save(out_path)

    ys, xs = np.where(alpha > 0)
    if len(xs):
        print(f"{in_path} -> {out_path}: bbox x[{xs.min()},{xs.max()}] y[{ys.min()},{ys.max()}], opaque px={len(xs)}")
    else:
        print(f"{in_path} -> {out_path}: WARNING no opaque pixels found")

if __name__ == "__main__":
    in_path, out_path = sys.argv[1], sys.argv[2]
    edge_threshold = float(sys.argv[3]) if len(sys.argv) > 3 else 14
    close_iters = int(sys.argv[4]) if len(sys.argv) > 4 else 2
    final_open_iters = int(sys.argv[5]) if len(sys.argv) > 5 else 1
    alpha_cut(in_path, out_path, edge_threshold, close_iters, final_open_iters=final_open_iters)
