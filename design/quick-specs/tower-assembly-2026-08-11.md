# Quick Design Spec: Tower Assembly ("Create New Towers")

**Type**: New mechanic
**System**: Tower (`design/gdd/tower.md`), Crafting (`design/gdd/crafting.md`), Equipment Forge (`design/gdd/equipment-forge.md`)
**GDD Reference**: `tower.md`'s Foundation/Weapon/Focus/Power schema, ADR-0008 (4-gate placement, `duplicate_deep()` component isolation)
**Date**: 2026-08-11
**Relocated, 2026-08-21**: originally shipped as the Forge screen's 4th tab (as described below). Player-requested move: it now lives as the **Assemble Towers** sub-tab of the Crafting panel inside `InventoryScreen.tscn` (Inventory & Crafting room), alongside a new **Recipes** sub-tab holding Crafting's existing recipe list. Rationale: `TowerAssembly.assemble_tower()` consumes items Crafting itself produces, not anything Forge-specific — the Forge tab placement was a UI-placement accident, not an architectural requirement. `TowerAssembly` itself (the scene-instanced system described below, discovered via the `"tower_assembly"` group) is unchanged — only which screen hosts its UI moved. The Forge screen (`EquipmentForgeScreen.tscn`/`.gd`) no longer has an Assemble tab; `FORGE_TAB_ASSEMBLE`/`FORGE_ASSEMBLE_*` in `equipment_forge_screen.gd` were removed. The body below describes the original Forge-tab design — read "Forge tab" as historical context; the current UI lives in `InventoryScreen.tscn`'s `AssembleView` node (see `tests/integration/inventory-screen/assemble-towers-tab_test.gd`).

## Change Summary

A new Forge tab lets the player combine four owned crafted tower components
(one Foundation, one Weapon, one Focus, one Power — each a real, separate
Inventory item) into a brand-new, player-named `TowerBlueprintData`, which is
then placeable in missions exactly like the game's pre-authored blueprints
(Archer, Frostbolt Turret, Longshot Sniper, Rally Banner). The four source
items are consumed; the new blueprint persists permanently across the save.

## Motivation

Investigating this Forge tab found a real, pre-existing gap: `crafting.md`'s
`tower_component` recipes already produce Foundation/Weapon/Focus/Power items
in Inventory (with a `quality_tier` stat override), but **nothing anywhere
reads them back**. `TowerSystem.place_tower()` only ever resolves blueprints
from `GameDataRegistry`'s boot-loaded, pre-authored `TowerBlueprintData`
files (`assets/data/towers/blueprints/*.tres`) — entirely disconnected from
whatever the player has crafted. Crafting a Foundation component today
produces inert Inventory clutter with no gameplay effect. This spec is the
missing bridge closing that loop: craft components → assemble them into a
tower → place it in a mission.

A second, smaller gap found in the same pass: no "focus" component recipe
exists at all (only foundation/weapon/power are craftable today), which
would make Assembly permanently blocked in practice. One new recipe is
added to close it (see Design Delta).

## Design Delta

**New field on `ItemDefinitionResource`** (`item_definition_resource.gd`):

```
@export var component_resource_path: String = ""  # only meaningful when item_type == "TowerComponent"
```

Points at a standalone `.tres` whose root resource is a real
`FoundationComponent`/`WeaponComponent`/`FocusComponent`/`PowerComponent` —
the same schema `tower.md`'s pre-authored blueprints already use inline as
sub-resources, just saved as its own top-level file so a crafted item can
reference one directly. **New content**: one standalone component `.tres`
per existing tower-component item (`iron_foundation_component`,
`advanced_weapon_component`, `tier4_power_component`) plus one new recipe +
item + component for `basic_focus_component` (ungated, Tier 1, cheap — the
missing focus recipe named above), so a full 4-slot assembly is actually
exercisable end-to-end with content that exists today.

**New system: `TowerAssembly`** (scene-instanced under `SanctuaryUI.tscn`,
discovered via the `"tower_assembly"` group — same established pattern as
`Crafting`/`EquipmentForge`/`BuildingUpgrade`, since RoomHost's generic mount
mechanism has no injection seam):

```
func assemble_tower(foundation_instance_id: int, weapon_instance_id: int,
        focus_instance_id: int, power_instance_id: int,
        display_name: String) -> StringName
```

Steps, in order (mirrors `crafting.md` Rule 8's own resolution-order
discipline):
1. Re-validate: all 4 `instance_id`s resolve to a real, currently-owned,
   non-`damaged` Inventory item (via `get_slot_contents_by_instance_id()`).
2. Validate each resolved item's `ItemDefinitionResource.item_type ==
   "TowerComponent"` and that its recipe's `component_slot` matches its
   assigned position (foundation item in the foundation slot, etc.) —
   cross-checked via `component_resource_path`'s own component script type
   (`FoundationComponent`/`WeaponComponent`/`FocusComponent`/
   `PowerComponent`), not by trusting a naming convention.
3. Reject (no side effects) if any check fails — matches Crafting's own
   stale-UI defense.
4. On success: `duplicate_deep()` each of the 4 resolved component
   Resources (ADR-0008's own established deep-copy policy — the new
   blueprint's components must be independent of whatever future Assembly
   calls reuse the same source `component_resource_path`), compose them
   into a new `TowerBlueprintData` with a freshly generated `tower_id`
   (`&"assembled_%d" % _assembly_counter`, monotonically incrementing,
   never reused even after a save/reload), the player-supplied
   `display_name`, and `placement_cost` per Formula 1 below.
5. Consume the 4 source items (`Inventory.remove_item()` by each item's own
   slot index, resolved from its `instance_id`; emits `item_removed` per
   item afterward, matching `consume_by_type()`'s own event-emission
   responsibility — `remove_item()` itself does not emit).
6. Register the new blueprint via a new public
   `GameDataRegistry.register_dynamic_tower_blueprint(blueprint:
   TowerBlueprintData) -> void` (extends the boot-loaded static dictionary
   at runtime; a real public API, not a private-dict reach-in — the latter
   is this project's established TEST-only convention, not acceptable from
   production code).
7. Emit a new EventBus signal `tower_assembled(tower_id: StringName,
   display_name: String)` (subscribers: Mission HUD's Build Panel refresh,
   Encyclopedia, Audio — mirrors `component_crafted`'s own decoupled
   pattern).

**Formula 1 — Assembled Placement Cost** (reuses `tower.md`'s own
per-component tier-cost-factor vocabulary rather than inventing a new
curve):

```
placement_cost = round(base_assembly_cost
    × foundation.tier_cost_factor
    × (1.0 + 0.25 × (weapon.component_id != "" as int))
    × (1.0 + 0.25 × (focus.component_id != "" as int))
    × (1.0 + 0.25 × (power.component_id != "" as int)))
```

Simplified for this first pass since every assembled tower always has all 4
slots filled (Assembly's own precondition, step 1): `placement_cost =
round(base_assembly_cost × foundation.tier_cost_factor × 1.75)`.
`base_assembly_cost` default 8 (safe range 5–15) — deliberately below the
pre-authored blueprints' 10–12g range (`tower.md`'s own registered content),
since an assembled tower already cost real Crafting materials once per
component; charging the full pre-authored price again would double-tax the
same investment.

**Save & Persistence**: `TowerAssembly` implements `SaveRestorer`.
`restore_order` = 33... **collision flagged**: `building-upgrade.md`
(this same session) already claims slot 33. Proposed `restore_order = 36`
(after Encyclopedia's 35, since an assembled blueprint's own component data
is fully self-contained at save time — no other system needs to have
already restored for `TowerAssembly.restore_save_data()` to correctly
reconstruct and re-register every assembled blueprint). Save payload: an
array of `{tower_id, display_name, placement_cost, foundation/weapon/focus/
power resource paths, per-component stat overrides applied at assembly
time}` — enough to fully reconstruct each `TowerBlueprintData` and
re-register it via `register_dynamic_tower_blueprint()` on load, plus
`_assembly_counter`'s own last value so newly-assembled `tower_id`s never
collide with restored ones.

## Testing

- Unit: `assemble_tower()` rejects a missing/wrong-slot/damaged component
  instance with zero side effects (no consumption, no registration, no
  event).
- Unit: a successful assembly consumes exactly the 4 source items, produces
  exactly one new registered blueprint with the correct composed stats, and
  fires `tower_assembled` exactly once.
- Integration: the newly-registered blueprint is immediately placeable via
  `TowerSystem.place_tower()` in the same mission-scene test harness already
  used for the pre-authored blueprints (`tests/integration/mission_scene/
  mission_scene_the_gap_test.gd`'s own established pattern).
- Integration: save → reload round-trip re-registers an assembled blueprint
  identically (same `tower_id`, same stats), and a subsequent new assembly
  doesn't collide with the restored counter.
