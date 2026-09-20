# Equipment Display (Item Detail + Equipment Bonuses Panel)

**Date**: 2026-09-20
**Status**: Approved by user (design presented and approved in chat), pending spec review and implementation plan
**Scope**: Show the player what their equipment does. Adds (a) an item detail card and (b) an "Equipment Bonuses" summary to the Inventory screen's Equipment tab. Builds on `2026-09-20-equipment-stats-wiring-design.md` (gear now affects Hero stats) and the 45 authored `base_stats` (`design/balance/equipment-base-stats.md`). Does NOT show full effective Hero totals (see Out of Scope).

## 1. Overview

Today the Equipment tab shows only icons: `EquipmentPaperdoll` renders 10 slot frames and the slot grid renders items, with no way to see what any item does or what the gear adds up to. `inventory_screen.gd`'s header explicitly defers tooltips. This spec adds one fixed `EquipmentInfoPanel` beside the paperdoll, with two states:

- **Default — "Equipment Bonuses":** the sum of everything currently equipped, one row per stat.
- **Hover/focus — item detail card:** that item's own stats, imbued runes and free rune slots, plus a per-stat change preview against what would be replaced.

A fixed panel (not a floating tooltip) is deliberate: `technical-preferences.md` forbids hover-only interactions and requires K/M and gamepad parity, so one focus-or-hover-driven code path serves both.

To guarantee the panel never disagrees with in-mission numbers, the bonus-folding logic currently private to `Hero` is extracted into a shared pure class that both Hero and the UI call.

## 2. Player Fantasy

Equipping gear stops being blind. The player hovers (or d-pads onto) a helm and immediately sees "+96 Max HP, +20 Armor", and sees what swapping would gain or lose before committing. Imbuing a rune visibly moves the bonuses panel.

## 3. Detailed Rules

### 3.1 `EquipmentBonuses` — shared pure calculator (extracted from Hero)

New file `src/core/equipment/equipment_bonuses.gd`, `class_name EquipmentBonuses`, `extends RefCounted`, static methods only, no state, no autoload access except `GGameDataRegistry` and `EquipmentForge.resolve_rune_stat_delta()`.

- `const FAN_OUT_STATS: Array[StringName]` — the 14 real stat keys. Moved from `Hero.EQUIPMENT_FAN_OUT_STATS`; `Hero.EQUIPMENT_FAN_OUT_STATS` is kept as an alias (`const EQUIPMENT_FAN_OUT_STATS := EquipmentBonuses.FAN_OUT_STATS`) so existing tests and callers keep working.
- `static func fold_stat_entry(stat, value, new_flat, new_additive) -> void` — moved verbatim from `Hero._fold_stat_entry` (spec §3.3 rule of the wiring spec: `additive_bonus_total` fans out to every stat's additive bucket, any other key is flat). `Hero._fold_stat_entry` remains as a thin wrapper for the existing tests.
- `static func item_stats(contents: Dictionary) -> Dictionary[StringName, float]` — one item's own flat stat contribution: union of `definition.base_stats` and `contents["stat_overrides"]`, override wins per stat (definition looked up via `GGameDataRegistry.get_item_definition`; `{}` if not found). Excludes runes.
- `static func rune_stats(contents: Dictionary) -> Dictionary` — the folded contribution of the item's `imbued_runes` via `EquipmentForge.resolve_rune_stat_delta()`, returned as `{"flat": Dictionary[StringName, float], "additive": Dictionary[StringName, float]}`.
- `static func compute(slot_contents: Array[Dictionary]) -> Dictionary` — full fold over any list of equipped-slot contents (same shape as `Inventory.get_equipped_item()`), returning `{"flat": Dictionary[StringName, float], "additive": Dictionary[StringName, float]}`. Empty entries are skipped.
- `static func compute_equipped() -> Dictionary` — convenience: `compute()` over all 10 `Inventory.EQUIPMENT_SLOT_NAMES` via `GInventory.get_equipped_item()`.

`Hero._recompute_equipment_bonuses()` becomes: `var r := EquipmentBonuses.compute_equipped(); _flat_bonuses = r["flat"]; _additive_bonuses = r["additive"]`. Behavior is unchanged; the existing Hero tests must pass unmodified.

### 3.2 Swap preview

`static func preview_swap(slot_name: String, candidate_contents: Dictionary) -> Dictionary` on `EquipmentBonuses`: computes `compute_equipped()` with `slot_name`'s contents replaced by `candidate_contents`, and returns the per-stat difference vs. the current `compute_equipped()` as `{"flat": Dictionary[StringName, float], "additive": Dictionary[StringName, float]}` (positive = gain). Stats with a difference of exactly zero are omitted.

Target slot for a candidate item, `EquipmentBonuses.target_slot_for(category: String) -> String`: the first slot in `Inventory.EQUIPMENT_SLOT_NAMES` order whose `EQUIPMENT_SLOT_CATEGORY` equals `category` and that is empty; if none are empty, the first slot of that category (so `ring` compares against `ring_1` when both rings are occupied). Returns `""` for an unknown category (no preview shown).

### 3.3 `EquipmentInfoPanel`

New scene-less control built in code (matching `EquipmentPaperdoll`'s precedent), `src/gameplay/ui/inventory_screen/equipment_info_panel.gd`, `class_name EquipmentInfoPanel`, `extends PanelContainer`. Placed in `InventoryScreen.tscn` as a sibling of `EquipmentPaperdoll` inside `LeftPanel`, visible only while `_active_tab == &"Equipment"` (toggled next to the existing `_equipment_paperdoll.visible` lines in `inventory_screen.gd`).

Public API:
- `show_bonuses() -> void` — default state.
- `show_item(contents: Dictionary, equipped_slot: String = "") -> void` — detail card. `equipped_slot` is non-empty when the item is currently equipped (the card then shows no swap preview, only its own stats); empty when it is an inventory item (the card shows the swap preview per §3.2).
- `refresh() -> void` — re-render the current state (used after equip/imbue events).

**Bonuses state rows:** one row per stat with a non-zero contribution, ordered by `STAT_DISPLAY_ORDER` (below). Flat values render as `+N` (integers for HP/armor/speed/range, one decimal for attack stats, percent with one decimal for fractional stats — see §3.5). If the additive bucket is non-zero, one extra row "All stats +X%" (all 14 additive entries are equal by construction when only runes contribute; the row shows the max additive value). If nothing is equipped or everything sums to zero: a single muted "No equipment bonuses" line.

**Detail card contents (top to bottom):** item `display_name`; slot/category label; a stats list of `item_stats(contents)` (with the swap-preview change appended per stat, see below); imbued runes (one line per rune: the rune's stat_delta rendered the same way, or "Unknown rune" for an unresolvable `rune_id`); a free-rune-slot line "Rune slots: N/M free" when `rune_slot_count > 0`. An item with no stats and no runes shows "No stat bonuses".

**Swap-preview change:** for an inventory (not equipped) item, each stat row shows the change in the Hero's overall bonus if swapped in: `Armor +20 (+8)` — the parenthesised number is `preview_swap()`'s value for that stat, colored green when positive, red when negative, omitted when zero. Stats the swap would REMOVE (present on the currently-equipped item, absent on the candidate) are also listed after the item's own stats as red rows (`Max HP -40`), so the loss is visible. When the target slot is empty, the delta equals the item's full stats.

### 3.4 Wiring into `inventory_screen.gd` and the paperdoll

- Every slot widget built by `_make_slot_widget()` already connects `mouse_entered`/`mouse_exited` and `focus_entered`/`focus_exited`. Add two new connections per widget that call `_on_slot_info_requested(slot_index)` on enter/focus-enter and `_on_slot_info_cleared()` on exit/focus-exit. `_on_slot_info_requested` reads `GInventory.get_slot_contents(slot_index)`; empty slots and non-equipment items (`equipment_category == ""`) clear back to the bonuses state instead of showing a card. Focus and hover are independent per ADR-0011; the panel simply shows whichever fired most recently (last-writer-wins, no stacking).
- `EquipmentPaperdoll._build_slot_frame()` frames get the same treatment: they call `GInventory.get_equipped_item(slot_name)` and use `show_item(contents, slot_name)`. The paperdoll gains a signal `slot_info_requested(slot_name: String)` / `slot_info_cleared()` that `inventory_screen.gd` forwards to the panel (the paperdoll does not hold a panel reference).
- `EquipmentInfoPanel` connects to `GEventBus.equipment_slot_changed` and `GEventBus.item_rune_imbued` in `_ready()` (disconnect in `_exit_tree()`) and calls `refresh()`.

### 3.5 Stat display formatting and order

`STAT_DISPLAY_ORDER` (top to bottom): `max_hp`, `armor`, `physical_attack`, `magic_attack`, `move_speed`, `attack_range`, `crit_chance`, `crit_multiplier`, `luck`, `cdr`, `lifesteal`, `elemental_resist_fire`, `elemental_resist_frost`. (`tower_affinity` is never granted by equipment; if a future item does, it is appended after these.) Any stat key not in this list (including unknown typo keys) is listed last using its raw key as the label — never dropped silently, so a content typo is visible.

Formatting: `max_hp`, `armor`, `move_speed`, `attack_range` → integer; `physical_attack`, `magic_attack` → one decimal; `crit_chance`, `crit_multiplier`, `luck`, `cdr`, `lifesteal`, `elemental_resist_*` → percent with one decimal (value × 100, e.g. `0.056` → `+5.6%`). The additive row is percent with one decimal.

**Note on raw-input stats:** `crit_chance`, `crit_multiplier` and `luck` are raw inputs to Hero's diminishing-returns curve (`hero.md` Formula 7), so "+5.6% Crit Chance" is a raw-input contribution, not a flat +5.6 percentage points of final crit chance. Labels use the same wording as other stats (this spec does not attempt to show curved results). Flagged as a known simplification; see Open Questions.

### 3.6 Localization

All labels go through `tr()` with new `strings.csv` keys (`INVENTORY_STAT_MAX_HP`, `INVENTORY_STAT_ARMOR`, … one per stat; `INVENTORY_INFO_BONUSES_HEADER`, `INVENTORY_INFO_NO_BONUSES`, `INVENTORY_INFO_NO_STATS`, `INVENTORY_INFO_RUNE_SLOTS`, `INVENTORY_INFO_UNKNOWN_RUNE`, `INVENTORY_INFO_ALL_STATS`). After any `strings.csv` edit the translation must be reimported (`Godot.exe --headless --editor --path <project> --quit`) before headless/MCP verification, per `docs/engine-reference/godot/VERSION.md`. Green/red colors are theme-agnostic constants in the panel script; the panel must also convey direction with the sign character (`+`/`-`), never color alone (accessibility).

## 4. Formulas

No new game formulas. The panel displays sums produced by the same fold rule as the wiring spec §3.2–3.3. `preview_swap` is a difference of two such sums.

## 5. Edge Cases

- **Nothing equipped:** Bonuses state shows "No equipment bonuses".
- **Item with empty `base_stats` and no runes:** card shows "No stat bonuses" (never a blank card).
- **Definition missing from registry:** `item_stats()` returns `{}`; card shows the raw `item_id` as the title and "No stat bonuses" (defensive, consistent with Hero's null-definition skip).
- **Orphaned rune_id:** listed as "Unknown rune", contributes nothing (matches Equipment Forge's orphan precedent).
- **Ring with both ring slots full:** compares against `ring_1`.
- **Swap preview on an item whose category matches no slot:** no preview, own stats only.
- **Hover/focus on a non-equipment item or empty slot:** returns to Bonuses state.
- **Rapid hover across slots:** last event wins; the panel holds no per-slot state beyond what it is currently showing.
- **Equip/imbue happens while a card is showing:** `refresh()` re-renders the current card from live inventory data. If the item shown is no longer where it was (slot emptied), fall back to the Bonuses state.
- **Unknown stat key in `base_stats`:** rendered last with its raw key (see §3.5), not hidden.

## 6. Dependencies

- **Hero**: `_recompute_equipment_bonuses()` and `_fold_stat_entry()` refactored to delegate to `EquipmentBonuses` with no behavior change; `EQUIPMENT_FAN_OUT_STATS` kept as an alias.
- **Inventory**: `get_equipped_item()`, `get_slot_contents()`, `EQUIPMENT_SLOT_NAMES`, `EQUIPMENT_SLOT_CATEGORY` consumed as-is. No changes.
- **Equipment Forge**: `resolve_rune_stat_delta()` consumed as-is (already shipped).
- **GameDataRegistry**: `get_item_definition()` consumed as-is.
- **Inventory Screen / EquipmentPaperdoll**: new panel added; new signals on the paperdoll; new hover/focus connections in `_make_slot_widget()`. ADR-0011's independent hover-vs-focus rule is preserved.
- **`strings.csv`**: new keys (§3.6).

## 7. Tuning Knobs

None (pure presentation). Panel sizing and the green/red colors are constants in `equipment_info_panel.gd`.

## 8. Acceptance Criteria

- AC-1: `Hero`'s stat results are unchanged by the refactor — the existing `hero_equipment_stats_test.gd`, `hero_stat_resolution_test.gd` and `hero_leveling_test.gd` pass without modification.
- AC-2: `EquipmentBonuses.compute()` over a fixed set of slot contents returns the same flat/additive dictionaries as the pre-refactor Hero fold (verified with stat_overrides-only fixtures, a fan-out rune fixture, and two items sharing a stat).
- AC-3: `EquipmentBonuses.item_stats()` prefers `stat_overrides` per stat over `base_stats`; returns `{}` for an unregistered item.
- AC-4: `preview_swap()` returns the exact per-stat difference (positive gain, negative loss), omits zero differences, and includes stats the swap removes as negatives.
- AC-5: `target_slot_for("ring")` returns `ring_1` when both empty, `ring_2` when only `ring_1` is occupied, `ring_1` when both occupied; `""` for an unknown category.
- AC-6: On the Equipment tab, hovering OR focusing an equipment item (inventory grid or paperdoll frame) shows the detail card; leaving returns to Bonuses. Both input paths work with no mouse present.
- AC-7: Equipping/unequipping/imbuing updates the visible panel without any tab switch.
- AC-8: Every stat renders with the formatting in §3.5; an unknown stat key renders last with its raw key.
- AC-9: The panel is visible only on the Equipment tab.
- AC-10: Direction in swap previews is conveyed by the `+`/`-` sign, not color alone.

## 9. Open Questions

- **OQ-1: Raw-input stats vs. curved results.** Crit chance, crit multiplier and luck are shown as raw contributions. Should the panel eventually show the curved effective value? That needs a base stat and level/class context the Sanctuary doesn't have (the reason "full effective totals" is out of scope). Revisit if the player finds the raw numbers misleading in play.
- **OQ-2: Full effective totals.** Showing final Hero stats (base + level growth + class bonuses + gear) in the Sanctuary needs Hero's base stats reconstructed outside a mission. Deferred by explicit user decision; a separate spec if wanted.

## 10. Out of Scope

Floating/cursor-following tooltips; full effective Hero totals; cross-tab comparisons; rarity styling and new item art; showing tower-component stats; changing Inventory's own equip/unequip flow.
