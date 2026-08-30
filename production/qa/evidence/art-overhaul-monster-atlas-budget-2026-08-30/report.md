# Animated Monster Atlas Budget Closure — 2026-08-30

## Outcome

All eight animated textures referenced by `CreatureAtlasMappingResource` now satisfy `design/art/codex-art-overhaul.md` §5.6. Standard/elite atlases are below the 256 KiB PNG cap; boss animsets are below the 2 MiB PNG cap. All assets import as BPTC VRAM-compressed textures with mipmaps disabled.

## Before / After

| Atlas | Class | Before | After | Final grid | Reduction | Budget |
|---|---|---:|---:|---|---:|---|
| `armored_brute_locomotion.png` | Standard/elite | 4,331,662 B (5695×773) | 206,578 B (945×128) | 5 × 1; 189×128/cell | 95.2% | PASS ≤ 262,144 B |
| `bog_lurker_elite_locomotion.png` | Standard/elite | 3,712,047 B (5480×849) | 145,500 B (825×128) | 5 × 1; 165×128/cell | 96.1% | PASS ≤ 262,144 B |
| `forest_troll_elite_locomotion.png` | Standard/elite | 6,898,464 B (5095×1328) | 97,191 B (490×128) | 5 × 1; 98×128/cell | 98.6% | PASS ≤ 262,144 B |
| `goblin_runner_locomotion.png` | Standard/elite | 2,481,851 B (4695×685) | 130,649 B (875×128) | 5 × 1; 175×128/cell | 94.7% | PASS ≤ 262,144 B |
| `iron_colossus_elite.png` | Standard/elite | 6,689,088 B (5780×1087) | 150,619 B (680×128) | 5 × 1; 136×128/cell | 97.7% | PASS ≤ 262,144 B |
| `spore_skitterling_locomotion.png` | Standard/elite | 3,058,264 B (5225×621) | 205,048 B (1075×128) | 5 × 1; 215×128/cell | 93.3% | PASS ≤ 262,144 B |
| `goblin_warlord_boss_animset.png` | Boss | 14,234,615 B (15162×1148) | 1,068,501 B (3388×256) | 14 × 1; 242×256/cell | 92.5% | PASS ≤ 2,097,152 B |
| `rift_sentinel_boss_animset.png` | Boss | 14,498,162 B (14066×1049) | 1,252,614 B (3430×256) | 14 × 1; 245×256/cell | 91.4% | PASS ≤ 2,097,152 B |

## Method and invariants

- Each frame was split using the mapping resource's existing column count, uniformly Lanczos-downsampled, then recomposed into an exactly divisible horizontal atlas.
- Standard/elite cells are 128 pixels tall for a 64-pixel presentation target (2× source sampling); boss cells are 256 pixels tall for the documented 112-pixel presentation target.
- No `CreatureAtlasMappingResource` clip indices, frame counts, row/column counts, world sizes, or foot-anchor offsets changed.
- Every output remains RGBA with alpha extrema 0–255.
- Every atlas width divides exactly by `atlas_columns`; this also removes the prior Rift Sentinel 10-pixel grid remainder.
- Frame baselines remain inherited from the original whole-cell canvases; the contact sheet confirms grounded silhouettes and distinct readable poses at display scale.

## Import verification

- All eight `.png.import` files use `compress/mode=2`, `compress/high_quality=true`, `mipmaps/generate=false`, and produce `.bptc.ctex` artifacts.
- BPTC artifacts were generated successfully by the pinned Godot 4.6.2 editor import pass.
- A headless project boot completed with no load/import errors.
- A three-frame explicit D3D12 launch (`--rendering-driver d3d12`) completed with no BPTC decode or texture errors.

## Visual evidence

- [`contact-sheet-at-display-scale.jpg`](contact-sheet-at-display-scale.jpg) previews all 48 frames at 64px standard/elite and 112px boss display heights on checkerboard.

## Verdict: COMPLIANT

No animated monster atlas remains over its §5.6 budget.