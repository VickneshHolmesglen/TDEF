"""Make a recoloured variant of an existing sprite (icon or worn overlay).

Luminance-preserving tint: each pixel keeps its brightness but is pulled
toward a target colour by --strength. Alpha is untouched, so the pixel-art
outline and silhouette stay identical to the source.

Used for the Steelwrought mid-tier gear line (2026-11-02), whose items reuse
the tier-2 shapes in a blued-steel finish until bespoke art exists.

  python tools/asset-pipeline/hd2d/recolor_variant.py SRC DST --tint 96,132,188 --strength 0.55
"""
import argparse
import pathlib

from PIL import Image


def recolor(src: str, dst: str, tint: tuple[int, int, int], strength: float, contrast: float) -> None:
    im = Image.open(src).convert("RGBA")
    px = im.load()
    tr, tg, tb = (c / 255.0 for c in tint)
    t_lum = 0.299 * tr + 0.587 * tg + 0.114 * tb
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            lum = min(1.0, max(0.0, 0.5 + (lum - 0.5) * contrast))
            scale = lum / t_lum if t_lum > 0 else 0.0
            nr, ng, nb = (min(1.0, c * scale) for c in (tr, tg, tb))
            out = []
            for orig, new in ((r, nr), (g, ng), (b, nb)):
                o = orig / 255.0
                out.append(round(255 * (o + (new - o) * strength)))
            px[x, y] = (out[0], out[1], out[2], a)
    im.save(dst)


def copy_import_params(src_png: str, dst_png: str) -> bool:
    """Gives `dst_png` the same Godot import [params] as `src_png`.

    A variant must follow its source's VRAM policy (size_limit, BPTC
    compression; design/art/animation-pipeline.md §4), but Godot creates a new
    PNG's .import with defaults. Run after the editor has imported the new file
    (so its .import exists), then re-run the editor import pass. Returns False
    when either .import file is missing.
    """
    src_imp = pathlib.Path(src_png + ".import")
    dst_imp = pathlib.Path(dst_png + ".import")
    if not src_imp.exists() or not dst_imp.exists():
        return False
    params = src_imp.read_text(encoding="utf-8").split("[params]", 1)[1]
    head = dst_imp.read_text(encoding="utf-8").split("[params]", 1)[0]
    dst_imp.write_text(head + "[params]" + params, encoding="utf-8", newline="\n")
    return True


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--tint", default="96,132,188")
    ap.add_argument("--strength", type=float, default=0.55)
    ap.add_argument("--contrast", type=float, default=1.1)
    a = ap.parse_args()
    recolor(a.src, a.dst, tuple(int(c) for c in a.tint.split(",")), a.strength, a.contrast)


if __name__ == "__main__":
    main()
