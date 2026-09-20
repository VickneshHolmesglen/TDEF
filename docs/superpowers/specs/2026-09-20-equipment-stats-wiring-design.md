# Equipment & Rune Stats Wiring

**Date**: 2026-09-20
**Status**: Approved by user, pending implementation plan
**Scope**: Wire the mechanism connecting equipped items and imbued runes to Hero's combat stats. Does NOT author real `base_stats` values for the 36 equipment items (a separate, later content-authoring pass, per user's explicit scoping) — this closes the code gap only, using whatever `base_stats`/`stat_delta` content already exists (mostly empty today, so this pass produces no visible in-game change until content follows).

## 1. Overview

`Inventory.equip_item()`'s own doc comment states the always-intended architecture: *"Hero reads this passively via its own `equipment_slot_changed` subscription."* That subscription was never added. Separately, `Inventory.apply_rune_to_item()` receives a rune's `stat_delta` at imbue time and discards it — `InventorySlot.imbued_runes` persists only the rune's id, not its stat contribution. This spec closes both gaps: Hero subscribes to `equipment_slot_changed`/`item_rune_imbued` and, on either firing, fully recomputes its `_flat_bonuses`/`_additive_bonuses` dictionaries from Inventory's current equipped-slot state — with imbued runes' stat contributions resolved on demand from their `rune_id` (never persisted redundantly, since each rune source's `stat_delta` is fully determined by its `rune_id` alone).

## 2. Player Fantasy

No new player-facing mechanic — this is the wiring that makes an already-designed mechanic (equip gear, see your stats change) actually work. Once content is authored in the follow-up pass, equipping a weapon or imbuing a Constellation rune will visibly move Hero's effective stats for the first time.

## 3. Detailed Rules

### 3.1 Hero's new subscriptions

`Hero` subscribes to `GEventBus.equipment_slot_changed(slot: String, new_item_id: String, previous_item_id: String)` and `GEventBus.item_rune_imbued(item_id: String, rune_id: String, rune_source: String)` in `_ready()` (disconnected in `_exit_tree()`, matching every other subscription in this file). Both handlers call one shared method, `_recompute_equipment_bonuses()` — neither handler needs its own event arguments, since the recompute always re-derives the FULL current state from Inventory rather than applying an incremental delta (avoids any drift between Hero's cached bonuses and Inventory's real equipped state, and is simple enough at 10 slots × ≤2 rune slots each to not need incremental optimization).

### 3.2 Full recompute algorithm

`_recompute_equipment_bonuses()`:
1. Start with two empty accumulator dictionaries, `new_flat: Dictionary[StringName, float]` and `new_additive: Dictionary[StringName, float]`.
2. For each of Inventory's 10 named equipment slots (`helmet`, `chest`, `gloves`, `pants`, `boots`, `main_hand`, `neck`, `ring_1`, `ring_2`, `offhand`):
   a. `var contents: Dictionary = GInventory.get_equipped_item(slot_name)` — `{}` if empty, skip.
   b. Resolve the item's definition: `GGameDataRegistry.get_item_definition(StringName(contents["item_id"]))`. Null-safe skip if not found (defensive; should not happen for a real equipped item).
   c. For each stat key in the UNION of `definition.base_stats` and `contents["stat_overrides"]`: the item's contribution for that stat is `contents["stat_overrides"][stat]` if present, else `definition.base_stats[stat]` — matches the existing "stat_overrides is the real roll, base_stats is the template" convention. Add this value into `new_flat[stat]` (equipment always contributes to the flat bucket, per 3.3).
   d. For each rune_id in `contents["imbued_runes"]`: resolve `var delta: Dictionary = GEquipmentForge.resolve_rune_stat_delta(StringName(rune_id))` (3.4) and fold it in per 3.3's key-handling rule.
3. Replace `_flat_bonuses = new_flat` and `_additive_bonuses = new_additive` wholesale (not merged — a full recompute must fully replace stale state, e.g. an unequipped item's old contribution must disappear).

### 3.3 Key-handling rule (applies to both equipment `base_stats`/`stat_overrides` entries and rune `stat_delta` entries)

- If the key is the literal `&"additive_bonus_total"`: add the value into `new_additive[stat]` for **every one of Hero's real `_base_stats` dictionary keys** — `max_hp`, `physical_attack`, `move_speed`, `cdr`, `crit_chance`, `armor`, `magic_attack`, `attack_range`, `elemental_resist_fire`, `elemental_resist_frost`, `lifesteal`, `tower_affinity`, `crit_multiplier`, `luck` (14 keys at the code level — `hero.md`'s own stat table counts "Elemental Resistances" as a single row #9, but it's implemented as two separate dictionary keys, fire and frost, so the fan-out must hit both; see Dependencies for the exact list source). This is the ONLY key with this fan-out behavior.
- Any other key is treated as a real stat name and its value is added into `new_flat[that stat]` directly (a flat, per-stat bonus — equipment/runes never write to `new_additive` for a specific named stat, only via the fan-out case above).

### 3.4 Resolving an imbued rune's `stat_delta` on demand (new function, no new persistence)

New public method on `EquipmentForge`: `resolve_rune_stat_delta(rune_id: StringName) -> Dictionary`. Mirrors `is_rune_id_known()`'s exact 3-way source-matching logic (already shipped, `equipment_forge.gd`), but returns the real `stat_delta` dictionary instead of a bool:
- Constellation: if `rune_id == "rune_<shape_id>"` for any `Constellation.SHAPE_N` key, return `{"additive_bonus_total": RUNE_ADDITIVE_BONUS}` (the same fixed dict `_add_available_rune()` already constructs for this source).
- Tarot: if `rune_id` matches some loaded `TarotCardResource.linked_rune_id`, return the same `{"additive_bonus_total": RUNE_ADDITIVE_BONUS}` shape.
- Menagerie: if `rune_id` matches some loaded `SacrificeRecipeResource.rune_id`, return that recipe's own `stat_delta` dictionary (already real content, species-specific — see `SacrificeRecipeResource.stat_delta`'s own doc comment, "authored per species").
- No match (an orphaned/unknown rune_id, per Equipment Forge's own already-documented orphan-handling precedent): return `{}` — contributes nothing, never an error.

This works because every rune source's `stat_delta` is a pure function of `rune_id` alone (Constellation/Tarot use one shared fixed constant regardless of which specific rune; Menagerie's value is fixed per species at content-authoring time) — nothing about "resolving" a rune's bonus depends on WHEN it was imbued, so no historical/instance-specific data needs to survive the imbue action itself.

## 4. Formulas

No new combat formulas — this closes a data-flow gap feeding directly into the already-shipped Formula 1 (`effective_stat = (base + flat) × (1 + additive)`, `hero.md`). The only "formula" this spec introduces is the key-handling rule in 3.3 (single-key fan-out for `additive_bonus_total`), which is a data-resolution rule, not a new mathematical formula.

## 5. Edge Cases

- **An equipped item's `ItemDefinitionResource.base_stats` is empty** (true for all 36 equipment items today, pending the follow-up content pass): that item simply contributes nothing — `_recompute_equipment_bonuses()` still runs correctly, just sums to zero for that item. No special-case needed.
- **An item has a rune slot but no imbued runes yet** (`imbued_runes` empty, `rune_slot_count > 0`): the loop over `imbued_runes` in 3.2d simply doesn't execute — no contribution, no error.
- **A rune_id in `imbued_runes` no longer resolves to any known source** (a genuinely orphaned rune, per Equipment Forge's own existing "is_rune_id_known" orphan-handling precedent — e.g. game content was removed after the rune was imbued): `resolve_rune_stat_delta()` returns `{}`, contributing nothing. Matches the existing project convention of "unrecognized value = inert, not an error."
- **Two equipped items or runes both contribute to the same stat**: both contributions sum normally into the same accumulator entry — no special interaction, standard additive stacking within each bucket (flat bucket sums together, additive bucket sums together, per Formula 1's own existing multi-source-summing model).
- **Unequipping an item**: `equipment_slot_changed` fires with the item now absent from that slot; the next full recompute naturally omits its contribution since step 2 only iterates currently-occupied slots. No explicit "subtract" logic needed — this is why the recompute is full-replace, not incremental.
- **A stat key inside `base_stats`/`stat_overrides`/`stat_delta` that isn't one of Hero's 13 known stat names** (e.g. a future content-authoring typo, or a stat that doesn't exist yet): still gets added into `_flat_bonuses`/`_additive_bonuses` under that key — `get_effective_stat()` simply never reads an unknown key, so it's silently inert, matching this codebase's established "unrecognized value = inert" convention. Not validated/rejected by this pass (content validation, if wanted, is a separate concern for whichever system authors `base_stats` values).

## 6. Dependencies

- **Inventory System**: `get_equipped_item(slot_name)` and its 10-entry `EQUIPMENT_SLOT_INDEX` are consumed as-is, no changes. `apply_rune_to_item()`'s existing `_stat_delta` parameter stays unused/discarded by Inventory itself (correct — the persistence-avoidance design in 3.4 means Inventory never needs to store it; the parameter itself is pre-existing and out of this spec's scope to remove).
- **Equipment Forge System**: gains one new public method, `resolve_rune_stat_delta()` (3.4) — read-only, consumes already-shipped `Constellation.SHAPE_N`, `GGameDataRegistry.get_all_tarot_cards()`/`get_all_sacrifice_recipes()`, mirroring `is_rune_id_known()`'s existing logic exactly (that function is not modified, just mirrored — code duplication between the bool-check and the dict-resolve is acceptable here since they check the same 3 sources for genuinely different return shapes, matching this file's own existing tolerance for small mirrored-logic pairs).
- **Hero System**: new subscriptions (3.1), new `_recompute_equipment_bonuses()` method (3.2), no change to `get_effective_stat()`/`_apply_stat_cap()`/Formula 1 itself — this spec only changes how `_flat_bonuses`/`_additive_bonuses` get populated, never how they're consumed.
- **GameDataRegistry**: `get_item_definition(item_id)` consumed as-is, no changes.
- **The 14-key stat list**: the fan-out in 3.3 must enumerate every real `_base_stats` dictionary key exactly once (14 today, per 3.3's own note about Elemental Resistances being one GDD row but two code-level keys). If a future stat is added to Hero (e.g. the player's own previously-flagged future "Corrupting Damage" stat), the fan-out list in the implementation must be updated to include it — flagged here as a maintenance point, not solved by this spec (no dynamic "all current stat names" introspection exists on Hero today).

## 7. Tuning Knobs

None — this is pure wiring, no new tunable numeric values. (The already-existing `RUNE_ADDITIVE_BONUS = 0.05` constant is consumed as-is, not modified.)

## 8. Acceptance Criteria

- AC-1: Equipping an item into any of the 10 named slots and then reading any of Hero's stats via `get_effective_stat()` reflects that item's `base_stats` (or `stat_overrides` if present) as a flat bonus, without requiring a mission restart or any other trigger beyond the `equipment_slot_changed` emission `equip_item()` already fires.
- AC-2: Unequipping an item removes its stat contribution on the very next recompute (verified via `unequip_item()`'s own emission of the same signal with the item now absent).
- AC-3: Imbuing a Constellation- or Tarot-sourced rune into an equipped item adds `RUNE_ADDITIVE_BONUS` (0.05) to **every one of the 14 real stat keys'** additive bucket, verified by checking at least 2 different stats' `get_effective_stat()` output both move.
- AC-4: Imbuing a Menagerie-sourced rune adds that species' specific `stat_delta` entries as flat bonuses to their named stats only (no fan-out).
- AC-5: `resolve_rune_stat_delta()` returns `{}` for an unrecognized/orphaned `rune_id`, never errors.
- AC-6: Two equipped items each contributing to the same stat sum correctly (both amounts present in the final effective value).
- AC-7: `resolve_rune_stat_delta()`'s 3-way source matching produces IDENTICAL classification results to the pre-existing `is_rune_id_known()` for the same `rune_id` set (i.e., a rune classified as "known" by one function is never unresolvable by the other) — verified by testing the same rune_id fixtures against both functions.
