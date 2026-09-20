# Rune Variety (Themed Targeted Rune Stats)

**Date**: 2026-09-20
**Status**: Approved by user (design and value table presented and approved in chat), pending spec review and implementation plan
**Scope**: Replace the single generic rune bonus (+5% all stats for every Constellation and Tarot rune; 2/5/8% all stats for Menagerie) with themed, targeted flat stat bonuses per rune, keeping two all-stats "wildcard" runes. Builds on `2026-09-20-equipment-stats-wiring-design.md` (runes resolve on demand from `rune_id` via `EquipmentForge.resolve_rune_stat_delta()`) and `equipment-forge.md` Formula 3 (which already defines the flat-rune path: hand-authored per targeted stat, guideline ~3%-10% of that stat's typical mid-game value).

## 1. Overview

There are 22 runes: 4 Constellation (one per code-defined shape), 13 Tarot (one per card via `linked_rune_id`), 5 Menagerie (one per species via `SacrificeRecipeResource.rune_id`). Today they are interchangeable: 17 of 22 give exactly `{additive_bonus_total: 0.05}` (a hardcoded `EquipmentForge.RUNE_ADDITIVE_BONUS`), and Menagerie's 5 give the same key at 0.02/0.05/0.08. This spec gives 20 of the 22 a themed flat bonus to specific stats and keeps 2 as generic all-stats wildcards, so "which rune goes on which item" becomes a real choice. All values move into data (Tarot card resources, Menagerie recipes, a Constellation table), removing the hardcoded constant from the resolution path.

## 2. Player Fantasy

A rune reflects where it came from. A Tarot card about relentless speed leaves a rune that makes you faster; a card about iron resolve leaves one that hardens you. Choosing between a Golden Ticket rune (pure luck) and an Aurora Stag rune (a modest boost to everything) is a build decision, not a rounding error.

## 3. Detailed Rules

### 3.1 Rune value storage (data-driven)

- **Tarot:** `TarotCardResource` (`src/core/tarot/tarot_card_resource.gd`) gains `@export var rune_stat_delta: Dictionary[StringName, float] = {}`, placed next to `linked_rune_id`. It is meaningful only when `linked_rune_id` is non-empty. It is DISTINCT from the existing `rune_bonus_flat` (Tarot's own in-mission Formula F5 bonus), which is unchanged. All 13 card `.tres` files in `assets/data/tarot/` are updated with their §4 values.
- **Menagerie:** `SacrificeRecipeResource.stat_delta` already exists and is already consumed by `resolve_rune_stat_delta()`. Only the 5 recipe `.tres` files in `assets/data/sacrifice_recipes/` change values.
- **Constellation:** the 4 shapes have no resource files (code-defined constants). `Constellation` gains `const SHAPE_RUNE_STAT_DELTA: Dictionary[String, Dictionary]` next to `SHAPE_N`/`SHAPE_COMPLEXITY_BONUS` (established precedent for per-shape config). Keys are the `SHAPE_N` keys.

### 3.2 Resolution change (`EquipmentForge.resolve_rune_stat_delta`)

Same 3-way source matching and same signature (`static func resolve_rune_stat_delta(rune_id: StringName) -> Dictionary`), changed returns:
- **Constellation** (`rune_id == "rune_<shape_id>"`): return `Constellation.SHAPE_RUNE_STAT_DELTA[shape_id].duplicate()`. If a `SHAPE_N` key has no entry in `SHAPE_RUNE_STAT_DELTA` (a future shape added without a value), fall back to `{"additive_bonus_total": RUNE_ADDITIVE_BONUS}`.
- **Tarot** (`rune_id == card.linked_rune_id`): return `card.rune_stat_delta.duplicate()`; if that is empty, fall back to `{"additive_bonus_total": RUNE_ADDITIVE_BONUS}`.
- **Menagerie:** unchanged (`recipe.stat_delta.duplicate()`).
- **Unknown:** `{}` (unchanged).

`RUNE_ADDITIVE_BONUS` stays as the documented fallback constant; it is no longer the normal path. `EquipmentBonuses`, `Hero`, and the equipment info panel already consume `resolve_rune_stat_delta()` and need NO changes: the wiring spec's key-handling rule (§3.3: `additive_bonus_total` fans out, any other key is flat) already handles targeted flat keys.

**No save migration.** A rune's bonus is resolved on demand from its `rune_id` (wiring spec §3.4), so runes already imbued into equipped items pick up the new values on the next recompute, automatically. The Forge's persisted `_available_runes` ledger also stores a `stat_delta` per rune, but that value is vestigial (never read for bonus resolution; `apply_rune_to_item()` discards it) and is deliberately left as-is by this spec.

### 3.3 Magnitude scale

Values are multiples of the T1 stat units used for equipment (`design/balance/equipment-base-stats.md`): max_hp 25, armor 5, physical_attack 2.5, magic_attack 2.5, move_speed 5, attack_range 8, crit_chance 0.02, crit_multiplier 0.05, luck 0.02, cdr 0.01, lifesteal 0.005, elemental_resist_* 0.03. A rune is roughly 2-4 units in total, about one mid-tier gear piece's contribution per rune, consistent with Formula 3's guideline for flat runes. Rarer sources are stronger: Menagerie keeps its 8% / 5% / 2% tier ordering (aurora_stag > duskfang_fox, emberwing_moth > glimmer_hare, mossback_toad). Each item has at most 2 rune slots, so a full loadout holds at most 20 runes.

## 4. Rune Values (authoritative)

Values are exact; units in parentheses are for reviewers. `additive_bonus_total` values are fractions (0.05 = +5% to every stat's additive bucket).

### Constellation (`Constellation.SHAPE_RUNE_STAT_DELTA`)

| shape_id | rune_id | Delta |
|---|---|---|
| triad_line | rune_triad_line | `physical_attack: 5.0` (2 units) |
| quad_line | rune_quad_line | `attack_range: 24.0` (3 units), `physical_attack: 2.5` (1 unit) |
| l_corner | rune_l_corner | `magic_attack: 7.5` (3 units) |
| cross_plus | rune_cross_plus | `additive_bonus_total: 0.05` (**wildcard**) |

### Tarot (`TarotCardResource.rune_stat_delta`)

Grouped by what each card does in missions (`modifier_type`): speed cards lean offense/mobility, reward cards lean luck, difficulty cards lean defense.

| Group | card_id (rune_id = `rune_<card_id-suffix>`) | Delta |
|---|---|---|
| Speed | apex_predator | `crit_chance: 0.04`, `crit_multiplier: 0.10` |
| Speed | hunters_pace | `move_speed: 15.0`, `attack_range: 12.0` |
| Speed | swift_current | `move_speed: 20.0`, `cdr: 0.02` |
| Speed | reckless_onslaught | `physical_attack: 6.25`, `crit_chance: 0.03` |
| Speed | cautious_advance | `armor: 15.0`, `move_speed: 5.0` |
| Reward | golden_ticket | `luck: 0.08` |
| Reward | bountiful_harvest | `luck: 0.06`, `max_hp: 50.0` |
| Reward | lucky_charm | `luck: 0.04`, `crit_chance: 0.03` |
| Reward | grinding_gauntlet | `max_hp: 75.0`, `physical_attack: 3.75` |
| Difficulty | grim_resolve | `max_hp: 100.0`, `lifesteal: 0.01` |
| Difficulty | iron_resolve | `armor: 20.0`, `elemental_resist_fire: 0.045`, `elemental_resist_frost: 0.045` |
| Difficulty | measured_pace | `cdr: 0.03`, `armor: 10.0` |
| Difficulty | steady_hand | `crit_chance: 0.04`, `attack_range: 16.0` |

(The rune_id for each card is that card's existing `linked_rune_id`, e.g. `rune_apex_predator`; this spec does not change any id.)

### Menagerie (`SacrificeRecipeResource.stat_delta`)

| species | rune_id | Old | New Delta |
|---|---|---|---|
| aurora_stag | rune_menagerie_aurora_stag | all-stats 0.08 | `additive_bonus_total: 0.08` (**wildcard**, unchanged) |
| duskfang_fox | rune_menagerie_duskfang_fox | all-stats 0.05 | `crit_chance: 0.05`, `move_speed: 10.0` |
| emberwing_moth | rune_menagerie_emberwing_moth | all-stats 0.05 | `magic_attack: 7.5`, `elemental_resist_fire: 0.06` |
| glimmer_hare | rune_menagerie_glimmer_hare | all-stats 0.02 | `move_speed: 10.0`, `luck: 0.03` |
| mossback_toad | rune_menagerie_mossback_toad | all-stats 0.02 | `armor: 10.0`, `elemental_resist_frost: 0.045` |

## 5. Formulas

No new formulas. Bonuses flow through the already-shipped Formula 1 (`effective = (base + flat) x (1 + additive)`); targeted runes populate the flat bucket, wildcards the additive bucket via the wiring spec's fan-out rule. Note `crit_chance`, `crit_multiplier` and `luck` values are raw inputs to `hero.md` Formula 7's diminishing-returns curve (same simplification as the equipment display spec's OQ-1).

## 6. Edge Cases

- **A new Constellation shape is added without a `SHAPE_RUNE_STAT_DELTA` entry:** resolves to the generic +5% all-stats fallback, never `{}` and never an error; the content test (§9 AC-4) fails so the omission is caught.
- **A Tarot card with a `linked_rune_id` but empty `rune_stat_delta`:** same generic fallback.
- **Orphaned/unknown rune_id:** `{}` (unchanged).
- **A typo'd stat key in any rune value:** stored but inert in Hero (project convention); the content test rejects it (AC-4) and the equipment info panel would list it last under its raw key.
- **Two runes granting the same stat on one item or across items:** sum normally (flat bucket adds, additive bucket adds).
- **Already-imbued runes:** re-evaluated with the new values on the next `equipment_slot_changed`/`item_rune_imbued`-driven recompute and on Hero `_ready()`. Players will see their gear's bonuses change after this update; intended.
- **Tarot `rune_bonus_flat` vs. `rune_stat_delta`:** independent; changing one never affects the other.

## 7. Dependencies

- **Equipment Forge:** `resolve_rune_stat_delta()` changed (§3.2). `is_rune_id_known()` unchanged.
- **Tarot:** `TarotCardResource` gains one export; 13 `.tres` files updated. `validate()`-style checks in that resource (if any exist for `rune_bonus_flat`) are untouched.
- **Constellation:** gains one const table.
- **Equipment Bonuses / Hero / Info Panel:** no code change (consume `resolve_rune_stat_delta()` as-is).
- **`equipment-forge.md`:** Formula 3's flat-rune guideline is now actually used; a short note in that GDD (rune magnitudes now authored per rune, see this spec) should be added when the implementation lands.

## 8. Tuning Knobs

The per-rune values in §4 are the knobs (data files, no code change to retune). `RUNE_ADDITIVE_BONUS = 0.05` remains only as the fallback value. Guard rails (Formula 3 / Hero): additive wildcards stay within 0.02-0.08 per rune so 20 simultaneous runes cannot approach `hero_additive_bonus_cap` (+3.00) on wildcards alone; targeted flat values follow the ~3%-10% of typical mid-game stat guideline.

## 9. Acceptance Criteria

- AC-1: `resolve_rune_stat_delta()` returns exactly the §4 delta for each of the 22 rune ids (spot-checked in tests across all three sources, including both wildcards and at least one multi-stat rune per source).
- AC-2: The two wildcards (`rune_cross_plus`, `rune_menagerie_aurora_stag`) resolve to `additive_bonus_total` only (0.05 and 0.08); every other rune resolves to flat stat keys only, with no `additive_bonus_total`.
- AC-3: Fallback behavior: a Tarot card with empty `rune_stat_delta` and a Constellation shape absent from `SHAPE_RUNE_STAT_DELTA` both resolve to `{"additive_bonus_total": 0.05}`; an unknown rune_id still resolves to `{}`.
- AC-4: Content-integrity test over all 22 runes: every rune resolves non-empty; every stat key is `additive_bonus_total` or one of Hero's 14 real stat keys; every value is > 0; additive values are within 0.02-0.08; flat values are within per-stat ceilings (equal to or looser than those in `equipment_base_stats_content_test.gd`).
- AC-5: Imbuing a themed rune raises only its targeted stats (e.g. `rune_golden_ticket` raises luck and no other stat) as observed through `EquipmentBonuses.compute()`.
- AC-6: `is_rune_id_known()` agrees with `resolve_rune_stat_delta()` for all 22 ids (existing AC-7 of the wiring spec still passes).
- AC-7: Existing equipment-stats-wiring, equipment-display, Equipment Forge and Tarot test suites pass, updated only where they assert the old uniform +5% value.

## 10. Out of Scope

New runes or rune sources; rune leveling/upgrading; changes to how runes are discovered or imbued; the Forge ledger's vestigial `stat_delta`; changes to Tarot's in-mission modifier effects; localization of rune names/descriptions (the equipment info panel already renders any stat key).
