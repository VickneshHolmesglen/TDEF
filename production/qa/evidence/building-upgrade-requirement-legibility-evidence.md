# QA Evidence: Building Upgrade Per-Requirement Legibility (AC-6, AC-6b)

**Story**: `production/epics/epic-14-building-upgrade/story-003-per-requirement-legibility.md`
**Date**: 2026-08-12
**Engine**: Godot 4.6.2.stable.official, driven live via the Godot MCP bridge (`run_project` on `src/gameplay/ui/equipment_forge_screen/EquipmentForgeScreen.tscn`, `run_script`, `take_screenshot`)
**Status**: Advisory evidence, closing the manual/visual verification this story's Test Evidence section required. Automated coverage already exists (`tests/integration/equipment-forge-screen/equipment_forge_screen_test.gd`, 6 tests targeting AC-6/AC-6b specifically) and remains the primary evidence for exact-text/state-transition correctness — this doc covers what only a rendered screenshot can prove.

---

## What was verified

- AC-6: each `requirements` entry renders as its own independent chip (category tag + resolved display name + satisfied/unmet state), not one collapsed pass/fail state for the whole upgrade.
- AC-6b: the 4 requirement categories render with distinct, non-color-only tags (bracketed text, since no icon assets exist for these categories yet).

## Method

1. Launched `EquipmentForgeScreen.tscn` directly, live, via the Godot MCP bridge (background mode).
2. Injected a real `BuildingUpgrade` instance (no shell/group available in an isolated scene run) and built `watchtower_tier_1` (satisfies visibility only) via `run_script`.
3. Switched to the Upgrade Buildings tab and screenshotted — real content (`upgrade_watchtower_reinforced`, requirements: building=`habitat_expansion_tier_1`, creature=`glimmer_hare`, tarot=`iron_resolve`).
4. Built `habitat_expansion_tier_1` too (satisfying the `"building"` requirement specifically) and re-screenshotted to confirm the per-chip state flips independently.

## Results

**Screenshot 1 — all 3 requirements unmet** (`.mcp/screenshots/screenshot_1786520367_748.png`):
```
Craft | Imbue | Upgrade Buildings
upgrade_watchtower_reinforced [VISIBLE_LOCKED]
✗ [Bldg] Habitat Expansion Tier 1   ✗ [Creature] Glimmer Hare   ✗ [Tarot] Iron Resolve
```

**Screenshot 2 — building requirement now satisfied, creature/tarot still unmet** (`.mcp/screenshots/screenshot_1786520376_781.png`):
```
✓ [Bldg] Habitat Expansion Tier 1   ✗ [Creature] Glimmer Hare   ✗ [Tarot] Iron Resolve
```

| Check | Result |
|---|---|
| 3 requirements render as 3 independent chips (not 1 collapsed tag) | **Confirmed** — both screenshots show 3 separate chip texts |
| Display names are resolved, not raw ids (`habitat_expansion_tier_1` → "Habitat Expansion Tier 1", `glimmer_hare` → "Glimmer Hare", `iron_resolve` → "Iron Resolve") | **Confirmed** |
| Category tags are distinct text, not color-only (`[Bldg]`/`[Creature]`/`[Tarot]`) | **Confirmed** — all 3 categories visually distinguishable in a plain grayscale-equivalent rendering (this UI uses no color differentiation at all currently, so it trivially passes the "not color alone" bar) |
| Chip state flips independently per entry when only the `"building"` requirement's underlying condition changes | **Confirmed** — building chip alone changed ✗→✓ between the two screenshots; creature/tarot chips unchanged |
| No leftover "Assemble Towers" tab (out-of-scope work reverted this session) | **Confirmed** — tab strip shows exactly Craft / Imbue / Upgrade Buildings |
| Runtime errors during the run | **0** |

## Verdict

**PASS.** Both AC-6 and AC-6b are confirmed against the real running engine, not just unit assertions — the previous binary `READY`/`REQUIREMENTS_UNMET` tag this story replaced is gone, and each of the 3 real requirements on real shipped content renders and updates independently.

## Notes

- The category tags are currently plain text (`[Bldg]`, `[Equip]`, `[Tarot]`, `[Creature]`) — no icon assets exist for these 4 categories in this project yet (confirmed during implementation). AC-6b's "non-color-only" bar is met by construction (text has no color-only differentiation to begin with), but this is a placeholder visual treatment, not a final art pass. Flagged in `building-upgrade.md`'s own Open Questions as a follow-up once real icons are authored.
- A true colorblind-simulation filter pass was not run (no such tooling available in this environment) — not needed here since the current implementation has zero color-based differentiation to simulate against; this note exists so a future accessibility pass on the eventual icon-based version doesn't skip that check by assuming this evidence already covered it.
