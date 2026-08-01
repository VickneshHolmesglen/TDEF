# Asset Generation Prompts

Reference log of prompts used with external image generators for game art,
kept so a prompt can be reused, tweaked, or regenerated later without
reconstructing the art-bible constraints from scratch each time.

---

## Rally Banner (Support archetype tower)

**Date:** 2026-08-02
**Target:** `blueprint_rally_banner.tres` (`archetype = "support"`, damage-buff
aura, radius 3 cells) — art gap identified while wiring `TowerInstance.gd`'s
archetype→texture lookup; no existing sliced asset has the open/radiating
silhouette the Support archetype requires (art bible §3.1.3 Rule 3).
**Status:** Generated, sliced, and wired (2026-08-02). Result was clean — real
alpha channel from the generator (no color-key alpha-cut needed, unlike the
sheet-sourced towers), open timber archway with visible open floor beneath the
banner (clears the 30% negative-space rule easily), soft ambient glow reads as
contained to the object once composited against a real background rather than
bleeding into it. Cropped to bbox, erased the "RALLY BANNER" plaque text (same
treatment as the other towers), saved as
`assets/art/towers/tower_support_base.png`, wired into `TowerInstance.gd`'s
`"support"` slot. Live-verified via Godot MCP — all 4 archetypes now resolve
with zero warnings.

```
Isometric fantasy game tower asset, "Rally Banner" support structure, single
object centered on a plain dark background for easy cutout. NOT a solid
enclosed tower — an open wooden-and-stone standard/banner platform: a raised
stone dais with an open timber frame archway, no walls enclosing the center,
at least 30% of the silhouette empty/negative space so it reads as
broadcasting outward rather than containing. A tall banner pole rises from
the center flying a large flowing amber-and-gold heraldic banner. Two
smaller flanking pennant poles with open trailing streamers extend outward
left and right, reinforcing an open, radiating, welcoming shape — not
symmetrical closed walls. Stone hexagonal pedestal base matching the style
of a matched tower set, with a label plaque on the front face. Soft golden
aura glow rising from the base, suggesting a buff/blessing effect emanating
outward, no particle explosion, just a warm ambient radiance.

Color palette: warm amber-gold (#C8801A) trim, muted fieldstone grey
(#7E8590) stone, parchment cream (#F5EDCB) banner highlights, Herald Gold
(#F5C01A) accents on the aura glow only. Do not use green, red, purple, or
cyan anywhere — this is a support/buff structure, not healing, damage, boss,
or UI-themed.

Style: hand-painted miniature cabinet-diorama aesthetic, painterly pixel-art
texture with visible brushwork, fixed oblique isometric play-angle (same
angle as a tabletop miniature), chamfered/hand-carved stone edges (not
CAD-perfect), consistent with a painted fantasy tower-defense game asset
set. Single centered object, no other towers in frame, no ground clutter
beyond the pedestal base.
```

**Constraint mapping** (why each clause is there):
- "at least 30% ... negative space" → art bible §3.1.3 Rule 3 (Support
  towers, non-negotiable).
- "open ... not symmetrical closed walls" → distinguishes from the
  Defensive/Damage-Dealer/Specialist archetypes, which are all closed forms.
- "Do not use green, red, purple, or cyan" → art bible §4.2 semantic color
  vocabulary (heal/damage/boss/UI-reserved hues respectively).
- "hand-painted miniature cabinet-diorama ... fixed oblique isometric" →
  art bible §1 Visual Identity Statement + §3.4 (camera/scale register).
- "plain dark background for easy cutout" → matches this project's existing
  alpha-cut pipeline (see `tower_ranged_base.png`, `tower_physical_base.png`,
  `tower_elem_*.png` — all sliced from generated sheets the same way).
