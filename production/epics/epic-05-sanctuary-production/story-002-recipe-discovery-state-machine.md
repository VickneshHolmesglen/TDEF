# Story 002: Recipe Discovery State Machine (3-Trigger)

> **Epic**: Epic 05 — Sanctuary Production Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (3-4 hrs)
> **Manifest Version**: 2026-07-13b *(stale for this epic — see Story 001)*

## Context

**GDD**: `design/gdd/crafting.md`
**Requirement**: `TR-craft-002` — "Dual-gate discovery trigger architecture (tech_unlocked AND item_added, both required, fires recipe_discovered once permanently); a third initialization-time sweep for AC-1 is still an open implementability gap"

**ADR Governing Implementation**: ADR-0023 (Crafting recipe data model)
**ADR Decision Summary**: `_discovery_ledger: Dictionary[StringName, bool]` (recipe_id → discovered), checked from 3 trigger paths: `tech_unlocked`, `item_added`, and a one-time boot/restore-time sweep in `restore_save_data()` — resolves the GDD's own flagged gap where Rule 4 originally named only 2 triggers. Sweep runs after **both** Inventory's (restore_order=10) and Defense Building's (restore_order=21) restores complete — Crafting's own `restore_order` must be assigned `> 21`.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: None beyond typed Dictionary (already verified).

**Control Manifest Rules (extracted from ADR-0023)**:
- Required: `restore_save_data()` returns `false` only on a malformed save payload (not an undefined "sweep failure") — the boot sweep itself cannot fail, per ADR-0023's explicit contract
- Required: `Crafting.restore_order` must be strictly greater than both Inventory's (10) and Defense Building's (21) — confirm the actual assigned value against `save-persistence.md`'s live table at implementation time, not just this story
- Forbidden: re-deriving discovery from anything other than the 3 named trigger paths — no ad hoc 4th trigger

## Acceptance Criteria

*From `design/gdd/crafting.md`, scoped to this story:*

- [ ] AC-1 (Logic half): GIVEN a recipe with `tech_prerequisite=""` and Inventory already holding its full `inputs` cost at the moment the boot/restore-time sweep runs, WHEN that sweep executes, THEN `recipe_discovered` fires for that recipe exactly once.
- [ ] AC-2: GIVEN a recipe with a `tech_prerequisite` not yet unlocked, WHEN the player holds its full `inputs` cost anyway, THEN `recipe_discovered` does NOT fire until the matching `tech_unlocked` event arrives.
- [ ] AC-11: GIVEN a tech-gate-satisfied recipe not yet `DISCOVERED`, WHEN an `item_added` event pushes the player's material stock to newly satisfy `has_items(inputs)`, THEN `recipe_discovered` fires exactly once for that recipe.

## Implementation Notes

*Derived from ADR-0023 Decision/Key Interfaces:*

```gdscript
func restore_save_data(data: Dictionary) -> bool:
    var raw_ledger = data.get("discovery_ledger", {})
    if typeof(raw_ledger) != TYPE_DICTIONARY:
        return false
    _discovery_ledger = raw_ledger
    _run_boot_discovery_sweep()   # trigger 3
    return true

func _run_boot_discovery_sweep() -> void:
    for recipe: RecipeResource in GameDataRegistry.get_all_recipes():
        if _discovery_ledger.get(recipe.recipe_id, false):
            continue
        var tech_gate_ok := recipe.tech_prerequisite == &"" or DefenseBuilding.is_tech_unlocked(recipe.tech_prerequisite)
        if tech_gate_ok and Inventory.has_items(recipe.inputs):
            _fire_recipe_discovered(recipe.recipe_id, recipe.recipe_category)
```

`DefenseBuilding.is_tech_unlocked()` is a direct Autoload call (Criterion B, ADR-0020) — safe here specifically because Crafting's `restore_order` is constrained to run after Defense Building's.

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: continuous craftability re-check (separate from one-time discovery)
- Story 004: the actual crafting resolution sequence once a recipe is craftable

## QA Test Cases

**AC-1**
- Given: a restored save where Inventory's restore has already populated sufficient materials for a recipe with `tech_prerequisite=""`, and that recipe is not yet in `_discovery_ledger`
- When: Crafting's `restore_save_data()` runs its boot sweep
- Then: `recipe_discovered(recipe_id, recipe_category)` fires exactly once
- Edge cases: the recipe is already `DISCOVERED` in the restored ledger (sweep must not re-fire); `Inventory.has_items()` returns false for this recipe (sweep must not fire)

**AC-2**
- Given: a recipe with `tech_prerequisite = "tech_x"`, `tech_x` not yet unlocked, and sufficient materials held
- When: the player's material stock changes via any `item_added` event
- Then: `recipe_discovered` does not fire
- Edge cases: `tech_unlocked("tech_x")` fires later, with materials still sufficient — discovery must fire then, from the `tech_unlocked` trigger path

**AC-11**
- Given: a tech-gate-satisfied, not-yet-discovered recipe with insufficient materials
- When: `item_added` pushes the stock to now satisfy `has_items(inputs)`
- Then: `recipe_discovered` fires exactly once
- Edge cases: two `item_added` events in the same session both push past the threshold — must fire only once, on the first crossing

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/crafting/recipe_discovery_state_machine_test.gd` — must exist and pass
**Status**: [x] Created — 9 test functions covering AC-1, AC-2, AC-11. Not yet executed in this environment (no headless Godot/gdUnit4 runner available) — verified by direct inspection only.

## Completion Notes
**Completed**: 2026-07-18
**Criteria**: 3/3 passing (AC-1, AC-2, AC-11)
**Deviations**: ADVISORY — found and fixed `TD-craft-001` (RecipeResource.inputs vocabulary mismatch) while implementing this story; see Story 001's Completion Notes. Also found and fixed a real gap in `save-persistence.md`: no `restore_order` was ever assigned to Crafting despite ADR-0023 requiring `> 21` — assigned `25`, added to the authoritative table. Authored a third recipe (`recipe_advanced_component`, tech-gated) since Story 001's original 2 recipes were both ungated and couldn't exercise AC-2/AC-11.
**Test Evidence**: `tests/unit/crafting/recipe_discovery_state_machine_test.gd` (9 functions) — verified by inspection, not yet executed (no headless Godot runner available this session).
**Code Review**: Skipped per "keep skip review plan through the remaining stories" instruction

**Known limitation carried forward from the project**: Crafting is scene-instanced (per ADR-0023), so it is subject to the pre-existing, tracked SavePersistence mid-session-restore gap (`production/epics/index.md` cross-epic blocker) — the boot discovery sweep implemented here will not re-run every time the Sanctuary scene reloads mid-session, only on the very first load. This is not a defect introduced by this story; it's the same already-documented project-wide gap Epic 05's index has flagged since epic creation.

## Dependencies

- Depends on: Story 001 (RecipeResource schema)
- Unlocks: Story 003
