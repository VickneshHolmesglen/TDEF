# Equipment Set Bonuses (Themed Stat Bonuses, 9 Sets)

**Date**: 2026-09-20
**Status**: Approved by user (design, roster and bonus table presented and approved in chat), pending spec review and implementation plan
**Scope**: Equipping several items from the same item family grants themed, cumulative stat bonuses. Stat bonuses only (user decision: special effects are out of scope). Builds on `2026-09-20-equipment-stats-wiring-design.md` (Hero recomputes bonuses from equipped gear), `2026-09-20-equipment-display-design.md` (`EquipmentBonuses` shared calculator + info panel), and `design/balance/equipment-base-stats.md` (T1 stat unit scale).

## 1. Overview

The 45 equipment items already fall into named families (Brute, Warlord, Sentinel, Troll, Goblin, Lurker, plus the Iron, Leather and Reinforced starter/mid-tier lines). No GDD defines set bonuses today. This spec adds nine sets as data (`EquipmentSetResource`), counts how many distinct pieces of each set are equipped, and folds each set's earned bonuses into the same flat/additive buckets as gear and runes, so Hero and the Inventory UI pick them up through the already-shared `EquipmentBonuses` calculator with no Hero change. Bonuses are derived from equipped state and never saved.

## 2. Player Fantasy

Collecting matching gear matters. Two pieces of Brute armor already toughen you; four make you a wall; a full five-piece Warlord loadout is a capstone reward. Because bonuses stack across sets, "commit to one family" competes with "mix two 2-piece bonuses", a real build decision.

## 3. Detailed Rules

### 3.1 Data: `EquipmentSetResource`

New Resource `src/core/equipment/equipment_set_resource.gd`, `class_name EquipmentSetResource`, `extends Resource`:

- `@export var set_id: StringName = &""`
- `@export var display_name: String = ""` (rendered as-is, matching `ItemDefinitionResource.display_name`'s existing convention)
- `@export var member_item_ids: Array[StringName] = []`
- `@export var bonuses: Dictionary[int, Dictionary] = {}` mapping `pieces_required` to a stat delta (`{StringName: float}`), using the same key rules as gear and runes: a named stat key is a flat bonus to that stat; the literal key `&"additive_bonus_total"` fans out to every stat's additive bucket (wiring spec §3.3).
- `func validate() -> Array[String]` returning error strings (matching `SacrificeRecipeResource.validate()`'s convention): `set_id` and `display_name` non-empty; at least 2 unique `member_item_ids`; `bonuses` non-empty; every threshold is an int between 2 and `member_item_ids.size()` inclusive; every delta is non-empty with every value greater than 0; every delta key is `additive_bonus_total` or one of `EquipmentBonuses.FAN_OUT_STATS`.

Content: one `.tres` per set in `assets/data/equipment_sets/` (`set_iron.tres`, `set_leather.tres`, `set_reinforced.tres`, `set_goblin.tres`, `set_brute.tres`, `set_sentinel.tres`, `set_troll.tres`, `set_warlord.tres`, `set_lurker.tres`). No `#` comments inside `.tres`. Adding the `class_name` requires a class-cache rebuild (`Godot.exe --headless --editor --path <project> --quit`).

### 3.2 Registry

`GameDataRegistry` follows its existing per-directory pattern (`DEFAULT_SACRIFICE_RECIPES_DIR` / `_load_sacrifice_recipes()`): a `DEFAULT_EQUIPMENT_SETS_DIR = "res://assets/data/equipment_sets/"` constant, an `_equipment_sets_dir` field, `_equipment_sets: Dictionary[StringName, EquipmentSetResource]`, a `_load_equipment_sets()` loader (skips non-`.tres`, logs a `push_error` for a load failure, each `validate()` error, and a duplicate `set_id`), `get_equipment_set(set_id) -> EquipmentSetResource`, `get_all_equipment_sets() -> Dictionary[StringName, EquipmentSetResource]` (shallow copy, like its siblings), and one new trailing optional `equipment_sets_dir` parameter on `_inject()` so tests can point at a fixture directory.

### 3.3 Counting and cumulative thresholds

For a list of equipped-slot contents (`Inventory.get_equipped_item()` shape), a set's piece count is the number of DISTINCT `item_id`s in that list that appear in the set's `member_item_ids`. Two equipped copies of the same item (for example the same ring in both ring slots) count once. An item belongs to at most one set (§3.7 enforces it in content), so an item never counts toward two sets. Items with no registered definition are skipped exactly as `EquipmentBonuses.compute()` already skips them.

A set grants every bonus whose threshold is less than or equal to its piece count (cumulative: at 4 pieces both the 2-piece and the 4-piece bonuses apply).

### 3.4 Integration with `EquipmentBonuses`

`EquipmentBonuses.compute(slot_contents)` (equipment-display spec §3.1) gains a final step: after folding item stats and rune stats, call `set_bonuses(slot_contents)` and fold its result into the same `flat`/`additive` dictionaries with `fold_stat_entry()`. New static helpers on `EquipmentBonuses`:

- `static func set_piece_counts(slot_contents: Array[Dictionary]) -> Dictionary` returning `{set_id: StringName -> int}` for sets with at least one piece equipped (count from §3.3).
- `static func set_bonuses(slot_contents: Array[Dictionary]) -> Dictionary` returning `{"flat": Dictionary[StringName, float], "additive": Dictionary[StringName, float]}` for all earned thresholds (§3.3), using `fold_stat_entry()` so `additive_bonus_total` fans out like every other source.
- `static func set_id_for_item(item_id: StringName) -> StringName` returning the set an item belongs to, or `&""`.

`compute_equipped()`, `preview_swap()`, and Hero's `_recompute_equipment_bonuses()` need NO change: they already call `compute()`. Consequently completing (or breaking) a set threshold shows up in `preview_swap()` deltas automatically. The set-bonus path resolves its `GameDataRegistry` data on demand every call (no cache), consistent with rune resolution.

Recompute triggers: none new. Set bonuses depend only on which items are equipped, and `equipment_slot_changed` already triggers Hero's and the panel's recompute. `item_rune_imbued` is unaffected.

### 3.5 UI (extends the equipment display spec)

`equipment_info_panel.gd` gains:

- **Bonuses state:** after the existing per-stat rows, a "Set Bonuses" section. For each set with at least 1 piece equipped, in `set_id` order: a header line `"<display_name> (<count>/<member count>)"`, then one line per threshold `"<N> pieces: <formatted delta>"` (formatted with the panel's existing `format_value`/`stat_label`, `additive_bonus_total` shown as "All stats +X%"), earned thresholds in normal text and unearned ones muted. If no set piece is equipped the section is omitted.
- **Item detail card:** if the item belongs to a set, one extra line `"Set: <display_name> (<count>/<member count>)"`, where `count` is the equipped count as it would be if this item were equipped (for an inventory item, the current equipped count plus 1 when the item's `item_id` is not already equipped; for an already-equipped item, the current count).
- **Swap preview generalization:** the card's per-stat preview (equipment display spec §3.3) currently lists own-stat deltas and removed stats. It additionally lists every stat present in `preview_swap()`'s result but absent from the item's own stats, whether the change is a gain or a loss, in the existing `+`/`-` signed green/red style, so set-bonus swings are visible. Direction is conveyed by sign, never color alone (accessibility rule unchanged).
- New `strings.csv` keys: `INVENTORY_INFO_SET_BONUSES_HEADER` ("Set Bonuses"), `INVENTORY_INFO_SET_LINE` ("Set: %s (%d/%d)"), `INVENTORY_INFO_SET_HEADER_LINE` ("%s (%d/%d)"), `INVENTORY_INFO_SET_THRESHOLD` ("%d pieces:"). After any `strings.csv` edit the translation must be reimported before headless/MCP verification (`docs/engine-reference/godot/VERSION.md`).

### 3.6 Persistence

None. Set bonuses are a pure function of equipped items and registry data, recomputed on demand, never saved (same principle as rune resolution in the wiring spec §3.4).

### 3.7 Content invariants (enforced by a content test)

Every `member_item_ids` entry is a real registered equipment item (`equipment_category != ""`); no `item_id` appears in more than one set; every set passes `validate()`; the nine expected `set_id`s exist; exact values match §4.

## 4. Set Values (authoritative)

Bonus values are per stat, on the T1-unit scale of `design/balance/equipment-base-stats.md` (max_hp 25, armor 5, physical_attack 2.5, magic_attack 2.5, move_speed 5, attack_range 8, crit_chance 0.02, luck 0.02, cdr 0.01, lifesteal 0.005, elemental_resist_* 0.03). A 2-piece bonus is about 3-4 units; higher thresholds about 6-10 units. First-pass and unplaytested.

| set_id | display_name | member_item_ids | Bonuses (pieces: delta) |
|---|---|---|---|
| set_iron | Iron | iron_sword, iron_helm, iron_greaves, iron_buckler, iron_band | 2: `armor 8.0`; 4: `max_hp 50.0`, `physical_attack 3.0` |
| set_leather | Leather | leather_gloves, leather_jerkin, leather_leggings | 2: `move_speed 8.0`; 3: `luck 0.03` |
| set_reinforced | Reinforced | reinforced_helm, reinforced_plate, reinforced_boots, reinforced_gauntlets | 2: `max_hp 40.0`; 4: `armor 12.0`, `physical_attack 4.0` |
| set_goblin | Goblin | goblin_fang_circlet, goblin_claw_gauntlets, goblin_raider_leggings, goblin_signet | 2: `luck 0.04`; 4: `crit_chance 0.06`, `move_speed 15.0` |
| set_brute | Brute | brutes_war_helm, brutes_bulwark_plate, brute_gauntlets, brute_legguards, brute_core_band | 2: `max_hp 60.0`; 4: `armor 25.0`; 5: `max_hp 100.0` |
| set_sentinel | Sentinel | sentinel_visor, sentinel_ward, sentinels_aegis, sentinels_lance, sentinels_striders | 2: `attack_range 16.0`; 4: `cdr 0.05`, `elemental_resist_fire 0.06`, `elemental_resist_frost 0.06` |
| set_troll | Troll | troll_hide_mantle, trollhide_buckler, trollhide_striders, trollmarrow_band | 2: `max_hp 60.0`; 4: `lifesteal 0.02`, `max_hp 80.0` |
| set_warlord | Warlord | warlords_battleplate, warlords_greatblade, warlords_greaves, warlords_legguards, warlords_standard_amulet | 2: `physical_attack 5.0`; 4: `max_hp 80.0`, `armor 15.0`; 5: `additive_bonus_total 0.05` |
| set_lurker | Lurker | lurker_claw_gauntlets, lurker_fang_blade | 2: `crit_chance 0.05`, `lifesteal 0.015` |

Notes: `sentinel_ward` and `sentinels_aegis` are both offhand items (one offhand slot), so at most 4 Sentinel pieces can be worn at once and 4 is its top threshold. Iron, Reinforced, Goblin, Sentinel, Troll top out at 4; Brute and Warlord have five items in five different slots and get a 5-piece capstone. `crit_chance` and `luck` values are raw inputs to Hero's diminishing-returns curve (Formula 7), as for gear and runes.

## 5. Formulas

No new formulas. Set bonuses flow through the already-shipped Formula 1 (`effective = (base + flat) x (1 + additive)`), populating the flat bucket (named stats) or the additive bucket (`additive_bonus_total` fan-out) exactly like gear and runes.

## 6. Edge Cases

- **Same item equipped twice** (two identical rings): counts once.
- **Two offhands in one set:** only one can be equipped; the other never contributes a piece.
- **Item with no registered definition, or removed from a set later:** skipped / no longer counted; bonuses re-derive on the next recompute.
- **A set whose `member_item_ids` names an unknown item:** `validate()` cannot check the registry; the content test (§3.7) catches it. At runtime the unknown id simply never matches an equipped item.
- **Threshold above the number of wearable pieces:** disallowed by `validate()` (threshold <= member count); a set that can never reach a threshold because of slot conflicts (Sentinel's two offhands) is a content-design matter, handled in §4's threshold choice.
- **Mixed-tier sets (Iron spans T1-T2):** allowed; membership is by item, not tier.
- **Cumulative thresholds:** a 5-piece Brute earns the 2-, 4- and 5-piece bonuses together.
- **Preview swap that breaks a set threshold:** the deltas (including set-driven losses on stats the swapped-in item lacks) appear in the card per §3.5.
- **No registry / empty sets directory:** no sets, no set bonuses, no error beyond the loader's existing directory-missing `push_error` convention.

## 7. Dependencies

- **`EquipmentBonuses`:** extended (`set_piece_counts`, `set_bonuses`, `set_id_for_item`, one added step in `compute()`); all existing callers (Hero, `preview_swap`, info panel) unchanged in signature.
- **`GameDataRegistry`:** new directory, loader, getters, `_inject` parameter.
- **Hero:** no code change (already delegates to `EquipmentBonuses.compute_equipped()`).
- **Equipment Info Panel:** extended per §3.5.
- **`strings.csv`:** four new keys.
- **Docs:** a balance table at `design/balance/equipment-set-bonuses.md` and a short note in `design/gdd/equipment-forge.md` or `inventory.md` pointing to this spec.

## 8. Tuning Knobs

The per-set threshold/bonus data in §4 (edit `.tres` files, no code change). No global constants.

## 9. Acceptance Criteria

- AC-1: `EquipmentSetResource.validate()` accepts each of the nine §4 sets and rejects: empty `set_id`/`display_name`, fewer than 2 members, duplicate members, empty `bonuses`, a threshold below 2 or above the member count, an empty delta, a non-positive value, and an unknown stat key.
- AC-2: `GameDataRegistry` loads all nine sets from `assets/data/equipment_sets/`, exposes them via `get_equipment_set()`/`get_all_equipment_sets()`, logs (does not crash on) a duplicate `set_id`, and can load a fixture directory via `_inject()`.
- AC-3: `set_piece_counts()` counts distinct item_ids per set; two equipped copies of the same item count once; sets with zero pieces are omitted.
- AC-4: `set_bonuses()` is cumulative: at 2 pieces only the 2-piece delta applies; at 4 pieces both the 2- and 4-piece deltas apply; below 2 nothing applies.
- AC-5: A set's `additive_bonus_total` entry (Warlord 5-piece) fans out to all 14 stats' additive buckets via `fold_stat_entry()`; named-stat entries land in the flat bucket only.
- AC-6: `EquipmentBonuses.compute_equipped()` includes set bonuses, so Hero's effective stat after equipping 2 pieces of one set exceeds its value with those same 2 pieces' own stats alone by exactly the 2-piece delta.
- AC-7: `preview_swap()` reflects a threshold being completed or broken (for example swapping in the 4th Brute piece adds the 4-piece delta to the reported changes).
- AC-8: Content test: exactly nine sets with the expected ids; each passes `validate()`; every member is a real equipment item; no item is in two sets; every set's values match §4.
- AC-9: The info panel's Bonuses state shows a Set Bonuses section listing each partially-equipped set with progress and earned/unearned thresholds (earned normal, unearned muted, sign-conveyed values); the section is absent when no set piece is equipped.
- AC-10: The item card shows the "Set: ..." line for set items with the correct would-be count, and the swap preview lists set-induced stat changes not present on the item itself, gains and losses, signed.
- AC-11: Existing suites pass: equipment wiring, equipment display, rune variety, Hero stat resolution, inventory-screen integration, registry tests (updated only where a fixed registry `_inject` signature or fixed loader expectation needs the new parameter).

## 10. Out of Scope

Special-effect set bonuses (procs, auras, skill modifiers, behavior changes); set-specific crafting recipes or drop tables; set art, icons or frame styling; tower-component sets; a "set collection" progress screen; balancing beyond the first-pass values (needs playtest).

## 11. Open Questions

- **OQ-1: Cross-set stacking.** Multiple 2-piece bonuses from different sets stack freely; combined with gear and rune stats this may outpace commit-to-one-set play. Revisit with playtest data.
- **OQ-2: Sentinel's dual offhands** cap it at 4 usable pieces by slot geometry; whether a 5-item set with a mutually exclusive pair is the intended design is left to the content designer.
