"""Builds the 2026-11-02 enemy-variety monsters' art and atlas mappings.

Each new monster reuses an existing sprite's silhouette in a new palette
(recolor_variant.py), so it reads as a relative of a known creature until
bespoke art exists:

  ashwing_moth   (flyer)    <- species/emberwing_moth, ash-grey, generated wing-flap sheet
  goblin_mender  (healer)   <- goblin_runner + walk sheet, moss green
  brood_sac      (splitter) <- spore_skitterling + walk sheet, bruised violet
  shade_stalker  (stealth)  <- goblin_runner + walk sheet, deep indigo

Writes assets/art/monsters/<id>.png (and <id>_locomotion.png plus
assets/data/creature_atlases/<id>.tres for the sheet-based ones). Re-runnable.

  python tools/asset-pipeline/hd2d/make_archetype_monsters.py
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from recolor_variant import recolor  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[3]
ART = ROOT / "assets/art"
ATLAS = ROOT / "assets/data/creature_atlases"

MONSTERS = [
    # id, static source, sheet source id (or None), tint, strength
    ("ashwing_moth", ART / "species/emberwing_moth.png", None, (150, 146, 140), 0.65),
    ("goblin_mender", ART / "monsters/goblin_runner.png", "goblin_runner", (120, 200, 96), 0.5),
    ("brood_sac", ART / "monsters/spore_skitterling.png", "spore_skitterling", (150, 92, 170), 0.6),
    ("shade_stalker", ART / "monsters/goblin_runner.png", "goblin_runner", (70, 64, 150), 0.7),
]


def flap_sheet(static_png: pathlib.Path, out_png: pathlib.Path, frame_h: int = 128) -> None:
    """5-frame wing-beat sheet from one still: frame 0 idle, frames 1-4 squash
    the sprite vertically (1.0, 0.75, 0.55, 0.75) around its centre."""
    from PIL import Image
    src = Image.open(static_png).convert("RGBA")
    scale = frame_h / src.height
    still = src.resize((max(1, round(src.width * scale)), frame_h), Image.NEAREST)
    fw = still.width
    sheet = Image.new("RGBA", (fw * 5, frame_h), (0, 0, 0, 0))
    for i, squash in enumerate((1.0, 1.0, 0.75, 0.55, 0.75)):
        h = max(1, round(frame_h * squash))
        frame = still.resize((fw, h), Image.NEAREST)
        sheet.alpha_composite(frame, (i * fw, (frame_h - h) // 2))
    sheet.save(out_png)


def write_mapping(mid: str, template_id: str) -> None:
    """Copies template_id's 5-frame atlas mapping (idle 0, walk 1-4) for `mid`."""
    mapping = (ATLAS / f"{template_id}.tres").read_text(encoding="utf-8")
    mapping = mapping.replace(f"{template_id}_locomotion.png", f"{mid}_locomotion.png")
    mapping = re.sub(r'creature_id = &"\w+"', f'creature_id = &"{mid}"', mapping)
    mapping = re.sub(r'family_atlas_id = &"\w+"', f'family_atlas_id = &"{mid}_family"', mapping)
    mapping = re.sub(r' uid="uid://[^"]+"', "", mapping)
    (ATLAS / f"{mid}.tres").write_text(mapping, encoding="utf-8", newline="\n")


def main() -> None:
    for mid, src, sheet_id, tint, strength in MONSTERS:
        recolor(str(src), str(ART / f"monsters/{mid}.png"), tint, strength, 1.1)
        if sheet_id is None:
            # No walk sheet to recolour: build a wing-flap sheet instead.
            flap_sheet(ART / f"monsters/{mid}.png", ART / f"monsters/{mid}_locomotion.png")
            write_mapping(mid, "goblin_runner")
            print("wrote", mid, "(flap sheet)")
            continue
        recolor(str(ART / f"monsters/{sheet_id}_locomotion.png"),
                str(ART / f"monsters/{mid}_locomotion.png"), tint, strength, 1.1)
        write_mapping(mid, sheet_id)
        print("wrote", mid, "(sheet)")
    print("done")


if __name__ == "__main__":
    main()
