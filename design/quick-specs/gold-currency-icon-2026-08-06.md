# Quick Design Spec: Gold Currency Icon

**Type**: Tweak
**System**: Mission HUD (`design/gdd/mission-hud.md`), Sanctuary UI (`design/gdd/sanctuary-ui.md`)
**GDD Reference**: `design/art/art-bible.md` Section 4.2 (Herald Gold reservation), `mission-hud.md` AC-64, `sanctuary-ui.md` Core Rule 3
**Date**: 2026-08-06

## Change Summary

Replace the plain "Gold: N" text in Mission HUD's `GoldLabel` and Sanctuary's
`ResourceHeader` with a coin icon + number. Purely visual — no change to the
underlying gold data, events, or balance logic (both already fully
implemented and tested).

## Motivation

Both currency displays are currently placeholder text (`"Gold: 50"`), matching
this project's "mechanism real, content placeholder" convention. This closes
the content half specifically for Gold — the single highest-visibility
currency — without touching materials display (a separate, larger 13-icon
scope explicitly deferred, per user decision).

## Design Delta

No GDD rule changes — this doesn't alter `mission-hud.md`'s AC-64 or
`sanctuary-ui.md`'s Core Rule 3 requirements ("gold delta reflected in the
header," "gold displayed in Combat Cluster"), only how the number is rendered.

**Real constraint found and honored, not invented here**: `art-bible.md`
Section 4.2 reserves Herald Gold (`#F5C01A`) exclusively for crit/Tower
Affinity/achievement "performance" feedback — "must not appear as ambient
decoration." A persistent currency icon is exactly the "ambient decoration"
case that rule excludes. The coin icon uses **Sanctum Amber** (`#C8801A`,
the general warm-UI-chrome color already used for tarot art, borders, and
other persistent UI) instead, matching how every other non-performance warm
UI element in this project already respects the same reservation.

## New Rules / Values

1. **Asset**: one coin icon, generated via the established ChatGPT-drop
   pipeline (`assets/source/ui/` → `assets/art/ui/`), alpha-cut per
   `design/art/asset-generation-prompts.md`'s documented flood-fill
   technique. Palette: Sanctum Amber `#C8801A` dominant, Parchment Cream
   `#F5EDCB` highlight/rim, Fieldstone Grey `#7E8590` shadow if needed. No
   Herald Gold, no purple, no green, no cyan (matches every other
   Sanctuary-adjacent asset's constraint list this session).
2. **Sizing**: 32×32 minimum effective display size — matches the art
   bible's own "combat-scan icon minimum (32px, not 24px)" rule (Section
   3.3's delta note), since Mission HUD's Gold icon is visible during
   WAVE_ACTIVE, a time-critical/peripheral-vision context.
3. **Mission HUD** (`MissionScene.tscn`): `GoldLabel` (currently a direct
   child of `CombatCluster/Chrome`) is wrapped in a new `GoldRow`
   `HBoxContainer` containing a `GoldIcon` `TextureRect` + the existing
   `GoldLabel`. `mission_hud.gd`'s `@onready var _gold_label` path updates
   to `$CombatCluster/Chrome/GoldRow/GoldLabel`. Label text changes from
   `"Gold: %d"` to just `"%d"` — the icon now carries the "this is gold"
   meaning the word "Gold" used to.
4. **Sanctuary `ResourceHeader`** (`resource_header.gd`): currently combines
   gold AND materials into one single dynamically-built `Label` string
   (`"Gold: 50    goblin_hide 3 · ..."`). Restructured into an `HBoxContainer`
   containing a `TextureRect` gold icon + a `_gold_label` (just the number)
   + the existing materials text in a separate trailing `Label` — same
   overall content, same scale-pop animation (now applied to the icon+number
   group together), materials portion untouched/still plain text.
5. **Materials remain plain text in both locations** — explicitly out of
   scope per user decision (13 distinct material types is a separate,
   larger art batch).

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `src/scenes/MissionScene.tscn` | New `GoldRow` wrapper node | Update scene |
| `src/presentation/mission_hud/mission_hud.gd` | `_gold_label` NodePath update, text format change | Update script |
| `src/presentation/sanctuary_ui/resource_header.gd` | Restructure single Label into icon+label+materials-label | Update script |
| `tests` (mission_hud, resource_header if any) | NodePath/text-format assertions may need updating | Check + update |

## Acceptance Criteria

- [ ] Gold icon renders at ≥32×32 effective size in both Mission HUD and Sanctuary's resource header
- [ ] Icon uses Sanctum Amber, not Herald Gold — spot-checked against the art bible's reserved-color rule
- [ ] Gold number still updates live and correctly on every `resources_changed` event, in both locations (no regression to AC-64/Core Rule 3)
- [ ] Materials display is completely unchanged (still plain text)
- [ ] No regression in existing Mission HUD / Sanctuary UI test suites
- [ ] Live-verified via Godot MCP screenshot in both locations

## GDD Update Required?

No — this is a rendering change within already-specified behavior, not a
rule change.
