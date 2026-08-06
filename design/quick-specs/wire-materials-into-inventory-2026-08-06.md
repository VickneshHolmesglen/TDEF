# Quick Design Spec: Wire Monster-Drop Materials into Real Inventory Storage

**Type**: Addition
**System**: Inventory (`design/gdd/inventory.md`), Resource Economy (`design/gdd/resource-economy.md`)
**GDD Reference**: `resource-economy.md` Rule 1, `inventory.md` Core Rule 2/AC-8, `docs/architecture/adr-0016-inventory-storage-model.md`
**Date**: 2026-08-06

## Change Summary

Inventory subscribes to `materials_earned`/`materials_spent` and actually
stores the resulting items, using its existing `add_stackable()`/
`consume_stackable()` API. Author the 13 missing `ItemDefinitionResource`
files the 13 real drop materials need to resolve through `GameDataRegistry`.

## Motivation

Investigating "add material icons to Inventory slots" found a real,
pre-existing gap underneath the display work: `resource-economy.md` Rule 1
states "Inventory is the ledger of record for materials," but nothing in the
codebase ever wires `materials_earned`/`materials_spent` into Inventory —
they're purely display-side running tallies (Mission HUD, Sanctuary header).
A player killing monsters all mission never actually accumulates real
Material-tab inventory items; the Inventory grid shows nothing for them
today. Icons on top of this would just be icons on a display that doesn't
work — the wiring has to exist first.

## Design Delta

`resource-economy.md` already states the target behavior (Rule 1: "Inventory
is the ledger of record for materials") — this spec implements it, it
doesn't change it.

## New Rules / Values

1. **Inventory subscribes to 2 new EventBus signals** in `_ready()`/
   `_exit_tree()`, matching this project's ubiquitous subscriber pattern
   (`MissionHud`, `ResourceHeader`, `AudioCueDispatcher`, etc.) — no new
   intermediary node, since `Inventory.has_items()` already establishes the
   precedent of calling `GGameDataRegistry` directly (its own class doc:
   "the one exception... resolves a slot's item_id to its item_type via
   GGameDataRegistry.get_item_definition()").
2. **`_on_materials_earned(material_type, quantity, _source)`**: resolves
   `GGameDataRegistry.get_item_definition(StringName(material_type))`. If
   found, calls `add_stackable(definition, quantity)` (reuses all of that
   method's existing overflow/partial-fill/`item_pickup_rejected` behavior
   unchanged). If not found (a material with no authored definition —
   should not happen for the 13 covered by this spec, but is a real
   possible future-content gap), `push_warning()` and skip — never crash on
   unrecognized data.
3. **`_on_materials_spent(material_type, quantity, _destination)`**:
   resolves the same way, calls `consume_stackable(definition, quantity)`.
4. **13 new `ItemDefinitionResource` `.tres` files** under
   `assets/data/items/`, one per real drop `material_id`
   (`goblin_hide`/`goblin_fang`/`iron_plating`/`brute_core`/`lurker_ichor`/
   `bog_pearl`/`rift_shard`/`sentinel_core`/`spore_dust`/`troll_hide`/
   `troll_marrow`/`warlord_iron`/`warlord_emblem`), `item_type = &"Material"`,
   `is_unique_instance = false`, human-readable `display_name` (e.g.
   "Goblin Hide"), `rarity` mapped 1:1 from each material's `DropEntry.
   is_rare` flag: `false -> "Common"`, `true -> "Rare"`.
5. **Real, disclosed gap NOT invented around**: `inventory.md`'s slot-
   expansion cost table expects a genuine 3-tier Common/Uncommon/Rare
   vocabulary (Uncommon introduced at Tier 2), but `DropEntry.is_rare` is a
   binary flag — none of these 13 materials can honestly be marked
   Uncommon from data that doesn't distinguish a middle tier. All 13 map to
   Common or Rare only. Flagged here for whoever eventually authors
   Uncommon-tier materials (a new drop-table field or a different source
   entirely) — not solved by inventing an arbitrary Common/Rare split.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `src/core/inventory/inventory.gd` | New `_on_materials_earned()`/`_on_materials_spent()`, 2 new `_ready()`/`_exit_tree()` subscriptions | Update script |
| `assets/data/items/` | 13 new `.tres` files | Author data |
| `tests/unit/inventory/` or `tests/integration/` | New tests for the wiring | Add tests |

## Acceptance Criteria

- [ ] `materials_earned("goblin_hide", 3, ...)` results in a real Inventory slot holding 3 `goblin_hide`, discoverable via `get_slot_contents()`
- [ ] `materials_spent` correctly consumes from existing stacks via `consume_stackable()`
- [ ] All 13 materials resolve via `GGameDataRegistry.get_item_definition()` with the correct `rarity` (Common/Rare per their drop table's `is_rare`)
- [ ] An unrecognized `material_type` logs a warning and does not crash
- [ ] Existing overflow/partial-fill/`item_pickup_rejected` behavior of `add_stackable()` is exercised correctly through this new call path (not just directly)
- [ ] No regression in existing Inventory/Resource Economy test suites
- [ ] Mission HUD's/Sanctuary's own display tallies remain unaffected (they keep their own independent local accumulation, unchanged)

## GDD Update Required?

No — this implements `resource-economy.md` Rule 1's own already-stated
requirement; no rule text changes.
