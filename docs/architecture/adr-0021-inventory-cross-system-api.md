# ADR-0021: Inventory Cross-System Query/Mutation API

## Status
Accepted

## Date
2026-07-17

## Acceptance Note
Accepted 2026-07-17 by direct user decision during `/create-stories epic-05-sanctuary-production`, to unblock that epic's stories — outside the normal `/architecture-review` gate (which was explicitly deferred this session, see `production/session-state/active.md`). engine-specialist validation already completed at authoring time; no re-review performed at acceptance.

## Amendment (2026-07-18, Sprint 6 S6-06b): `has_items_by_rarity()` / `consume_by_rarity()`

**TD-craft-001 / TD-defbuild-002 RESOLVED.** `crafting.md`'s Formulas 1-3 and `defense-building.md`'s `material_costs` are authored against a material-**rarity** vocabulary (`Common`/`Uncommon`/`Rare`), but this ADR's original `has_items()` (ADR-0016/`inventory.md`) only ever summed by `ItemDefinitionResource.item_type` — a recipe/tech/structure cost keyed by rarity was structurally uncraftable/unaffordable regardless of actual stock. Resolved by adding `rarity: String` as a fourth `ItemDefinitionResource` field (separate aggregation axis from `item_type` — a single item, e.g. `common_scrap`, legitimately has both `item_type="Material"` and `rarity="Common"`) and two new Inventory methods that mirror `has_items()`/`consume_by_type()` exactly, summing by `rarity` instead:

```gdscript
func has_items_by_rarity(cost: Dictionary) -> bool:
    # Mirrors has_items() — same unlocked+stackable slot filtering, sums by
    # ItemDefinitionResource.rarity instead of item_type. Empty cost -> true.
    ...

func consume_by_rarity(rarity: String, quantity: int, emit_events: bool = true) -> int:
    # Mirrors consume_by_type() exactly — draws from whichever item_type(s)
    # share the given rarity, in slot order. Returns amount actually consumed.
    ...
```

Callers (Crafting's `resolve_repair()`/`_has_recipe_inputs()`/`_consume_recipe_inputs()`, Defense Building's `resolve_tech_unlock()`/`resolve_structure_build()`) split a mixed item_type/rarity-keyed cost Dictionary by checking `RecipeResource.VALID_RARITIES.has(key)`, routing each half to the matching pair of methods — a recipe/cost table may therefore mix both vocabularies in one Dictionary (`RecipeResource.validate()` already permitted this; only the Inventory-side query was missing).

**Live-verification finding (same pass):** `has_items_by_rarity()`/`has_items()`/`consume_by_rarity()`/`consume_by_type()` all resolve a slot's `item_type`/`rarity` via `GGameDataRegistry.get_item_definition(slot.item_id)` — **never** from the `ItemDefinitionResource` object a caller passes to `add_stackable()`. Several tests written earlier in this same sprint pass seeded Inventory with fabricated, unregistered `item_id`s (e.g. `test_material_Common`) and asserted affordability against them — these could never have passed, since `GGameDataRegistry.get_item_definition()` only resolves `.tres` content actually loaded from `res://assets/data/items/`. Found via live Godot MCP `run_script` verification (not caught by static review) and fixed by seeding tests with the genuinely registered `common_scrap` (rarity=Common) / `iron_ore` (rarity=Uncommon) definitions instead. This is a documented gotcha for any future test seeding Inventory: **the definition object passed to `add_stackable()` only supplies `item_id`/`quantity` to the slot — everything `item_type`/`rarity`-keyed reads back through the registry, so the `item_id` must be real.**

**Validation Criteria addition**: `tests/unit/inventory/has_items_by_rarity_test.gd` (7 tests), `tests/unit/crafting/mixed_vocabulary_recipe_inputs_test.gd` (4 tests, mixed-vocabulary split) — all passing via live gdUnit4 run, plus the 4 pre-existing defense_building/crafting test files whose seeding helpers were corrected in the same pass (`currency_dual_gate_test.gd`, `resolution_ordering_test.gd`, `persistence_through_defeat_test.gd`, `component_repair_test.gd`, `edge_cases_shared_guard_test.gd`).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (data/integration contract) |
| **Knowledge Risk** | LOW — extends ADR-0016's existing `InventorySlot`/`RefCounted` model with additional methods; no new engine subsystem introduced. Inherits ADR-0016's already-verified `Dictionary.duplicate(true)` isolation pattern. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0016 (Inventory Storage Model) |
| **Post-Cutoff APIs Used** | None new — reuses `Dictionary.duplicate(true)` (pre-existing, ADR-0016) |
| **Verification Required** | Confirm `apply_rune_to_item()`'s in-place mutation of `stat_overrides`/a new `imbued_runes` array does not require `duplicate_deep()` — it should not, since `InventorySlot` is a plain `RefCounted`, not a Resource tree (same reasoning ADR-0016 already established for `stat_overrides`). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0016 (Inventory Storage Model — Accepted; this ADR extends its `InventorySlot` query surface, does not replace it), ADR-0020 (Direct-Autoload-call exception pattern — these methods are direct Autoload calls, Criterion A) |
| **Enables** | `design/gdd/crafting.md` (unblocks AC-4, AC-6, AC-11, AC-12 — currently `[BLOCKED — depends on unimplemented API]`), `design/gdd/equipment-forge.md` (unblocks AC-9, AC-16(c), and indirectly AC-17/AC-19/AC-20 which also need Menagerie's `request_sacrifice()`), `design/gdd/menagerie.md` and `design/gdd/defense-building.md` (both already use the existing `has_items()` — no new blocker, but this ADR is the formal record for the shared Inventory API surface both consume) |
| **Blocks** | None — this ADR is itself the blocker being resolved for Crafting/Equipment Forge stories |
| **Ordering Note** | Must land before Crafting or Equipment Forge implementation stories move out of `Blocked` — both GDDs' Open Questions tables cite these exact three new methods as their top interface dependency. |

## Context

### Problem Statement

`inventory.md` was updated 2026-07-17 to specify three new cross-system query/mutation methods (`has_room_for()`, `clear_damaged_flag()`, `apply_rune_to_item()`) that Crafting and Equipment Forge both depend on, but no ADR exists formalizing how these extend ADR-0016's already-Accepted `InventorySlot` storage model. Without this ADR, every Acceptance Criterion in `crafting.md` and `equipment-forge.md` that exercises these methods is explicitly flagged `[BLOCKED — depends on unimplemented API]` — 4+ ACs in Crafting, 3+ in Equipment Forge. This is also the single ADR the 2026-07-17 architecture review identified as unblocking two systems at once (Crafting's `TR-craft-003` and Equipment Forge's `TR-equipforge-001`).

### Constraints

- Must not contradict ADR-0016's existing decision that `InventorySlot` is a plain `RefCounted`, not a Resource — these are additional methods on the same Autoload/node, not a new storage tier.
- Must not return `Resource` instances or violate the `resource_object_in_save_data` forbidden pattern (ADR-0003) — none of the three new methods touch save data directly, but any new field they introduce (e.g. `imbued_runes`) must remain save-compatible (primitive-only) per ADR-0016's existing `get_save_data()` contract.
- Must resolve the explicit conflict flagged by `equipment-forge.md` Rule 16: `apply_rune_to_item()` **must** be permitted on a currently-equipped item, which requires an explicit, scoped exemption to Inventory's existing Rule 5 equipped-item lock (ADR-0016's `locked: bool` field blocks *removal*, not in-place metadata mutation — this ADR must state that distinction as an architectural invariant, not leave it to per-caller discipline).
- Per ADR-0020 (Direct-Autoload-call exception pattern): these are read/write query methods called from gameplay-triggered actions (craft confirm, rune imbue), not per-frame — they qualify as direct Autoload calls under the project's existing convention (`has_items()` is already a direct call per `inventory.md`'s own note: "consistent with how Grid and Tower already expose read/query APIs").

### Requirements

- `has_room_for(item_type: String, quantity: int) -> bool` — pre-check runnable before a craft/acquire action consumes its cost, so a failed room check never leaves materials spent with nothing received (Crafting Rule 7, Equipment Forge Rule 9b).
- `clear_damaged_flag(item_id: String) -> bool` — mutate an existing stored instance's `damaged` metadata field in place, without a remove/re-add cycle (Crafting Rule 6).
- `apply_rune_to_item(item_id: String, rune_id: String, stat_delta: Dictionary) -> bool` — mutate an existing item instance's `imbued_runes` in place, consuming one free rune slot; must succeed on an equipped item (Equipment Forge Rule 16).
- All three must integrate with the existing `instance_id`-keyed lookup from ADR-0016 (items are found by `item_id` here, meaning the item's `instance_id`-scoped identity per ADR-0016 — Inventory resolves this internally, callers pass the same identifier Crafting/Equipment Forge already receive from `item_added`).

## Decision

**Extend `InventorySlot` (ADR-0016, unchanged as a plain `RefCounted`) with two new fields and add three new query/mutation methods to the Inventory Autoload, following the existing `has_items()` direct-call convention.**

**New `InventorySlot` fields** (both primitive, both save-compatible per ADR-0016's existing `get_save_data()` contract — `get_save_data()`'s per-slot flat-`Dictionary` conversion, ADR-0016 Decision, must include both new keys alongside the existing four):
- `damaged: bool = false` — set by mission-time component damage (Tower System, out of this ADR's scope to define when it's set — only how it's cleared), cleared by `clear_damaged_flag()`.
- `imbued_runes: Array[String] = []` — array of `rune_id` values, appended to by `apply_rune_to_item()`, capped implicitly by the item definition's `rune_slot_count` (an `ItemDefinitionResource` field, read-only, defined by Equipment Forge's data authoring — not introduced by this ADR). Typed per the project's static-typing convention (same reasoning as ADR-0016's own minor note on `stat_overrides`).

**Method behaviors:**

1. `has_room_for(item_type: String, quantity: int) -> bool` — a pure read-only capacity check. Computes whether adding `quantity` units of `item_type` would exceed the tier-capacity floor (`inventory.md` Rule 5a), using the same stack-cap logic `item_pickup_rejected`'s existing rejection path already implements internally. Does not mutate any state. Returns `false` conservatively if `item_type` is unrecognized (not found in `GameDataRegistry`).

2. `clear_damaged_flag(item_id: String) -> bool` — locates the slot by `item_id` (resolved the same way `item_added`'s payload identifies a specific instance — this ADR does not redefine identity resolution, it reuses ADR-0016's `instance_id` scheme). Sets `damaged = false` in place. Returns `false` (no mutation) if the item is not found or `damaged` was already `false` is still a valid no-op success — returns `true` in that case (idempotent). No `item_added`/`item_removed` fires — this is a metadata mutation, not a stack change.

3. `apply_rune_to_item(item_id: String, rune_id: String, stat_delta: Dictionary) -> bool` — locates the slot by `item_id`. Validates `imbued_runes.size() < rune_slot_count` (read from the item's `ItemDefinitionResource`); if the slot is full, returns `false` with **zero mutation** (per `equipment-forge.md`'s explicit "no destructive default" requirement — never evicts an existing rune to make room). On success: appends `rune_id` to `imbued_runes`, merges `stat_delta` into the slot's existing `stat_overrides` (via `Dictionary.duplicate(true)`-then-merge, following ADR-0016's established isolation pattern for that field; merge policy is overwrite-on-key-collision, i.e. `Dictionary.merge(stat_delta, true)` — a rune stat that targets the same key as an existing override replaces it, it does not stack additively), and returns `true`. Neither `item_added` nor `item_removed` fires — same in-place-mutation contract as `clear_damaged_flag()`.
4. `reserve_instance_id() -> int` — added 2026-07-17 for ADR-0025 (Equipment Forge): draws from the same monotonic `_next_instance_id: int` counter this ADR already defines (Decision, Unique-instance identity), letting a caller mint a collision-safe `instance_id` **before** the item it will belong to is constructed — needed when a cross-system call (e.g. `Menagerie.request_sacrifice()`) must receive a `target_item_id` ahead of item creation. Pure counter increment, no slot lookup, no mutation to any `InventorySlot`.

**Equipped-item lock exemption (formalizes `equipment-forge.md` Rule 16's flagged requirement):** ADR-0016's `locked: bool` field gates **removal** operations only (`inventory.md` Rule 5). `clear_damaged_flag()` and `apply_rune_to_item()` are both in-place metadata mutations that do not remove, re-add, or reindex the slot — they must **not** check `locked` at all. This is stated here as an architectural invariant on the two mutation methods' contracts, not left to each caller's discipline: any future method added to this Autoload that performs a metadata-only mutation (not a stack/slot change) follows the same rule; any method that removes or replaces a slot must continue to check `locked`.

### Architecture Diagram

```
Inventory (Autoload, extends ADR-0016's existing model — no new Autoload, no boot-order change)
  ├─ InventorySlot (RefCounted, ADR-0016)
  │    + damaged: bool = false          (new field, this ADR)
  │    + imbued_runes: Array = []       (new field, this ADR)
  ├─ existing: has_items(cost: Dictionary) -> bool   (already a direct call, ADR-0016/inventory.md)
  ├─ new: has_room_for(item_type: String, quantity: int) -> bool         (read-only, Criterion A/ADR-0020)
  ├─ new: clear_damaged_flag(item_id: String) -> bool                    (in-place mutation, no locked check)
  └─ new: apply_rune_to_item(item_id, rune_id, stat_delta: Dictionary) -> bool  (in-place mutation, no locked check)

Callers (direct Autoload calls, per ADR-0020 Criterion A):
  Crafting        → has_room_for(), clear_damaged_flag()
  Equipment Forge → has_room_for(), apply_rune_to_item()
```

### Key Interfaces

```gdscript
# Inventory (Autoload) — additions to the existing ADR-0016 surface
func has_room_for(item_type: String, quantity: int = 1) -> bool:
    # Read-only. Returns false for unrecognized item_type.
    ...

func clear_damaged_flag(item_id: String) -> bool:
    # In-place mutation. Does NOT check InventorySlot.locked.
    # Idempotent: returns true whether or not damaged was already false.
    # Returns false only if item_id is not found.
    # Does not fire item_added/item_removed.
    ...

func apply_rune_to_item(item_id: String, rune_id: String, stat_delta: Dictionary) -> bool:
    # In-place mutation. Does NOT check InventorySlot.locked.
    # Returns false with zero mutation if no free rune slot (imbued_runes.size() >= rune_slot_count).
    # Does not fire item_added/item_removed.
    ...

func reserve_instance_id() -> int:
    # Added 2026-07-17 (ADR-0025 gap): draws from the same monotonic
    # _next_instance_id counter ADR-0016 already owns and persists.
    # Lets a caller (e.g. Equipment Forge's sacrifice flow) mint a
    # collision-safe item_id BEFORE the item itself is constructed,
    # without needing scene-local ID state of its own.
    _next_instance_id += 1
    return _next_instance_id - 1

# InventorySlot (RefCounted, ADR-0016) — new fields
var damaged: bool = false
var imbued_runes: Array = []   # Array[String] of rune_id values
```

## Alternatives Considered

### Alternative A: New `item_metadata_changed` EventBus event instead of direct-mutation methods

- **Description**: Crafting/Equipment Forge would emit a `component_repaired`/`item_rune_imbued`-triggering EventBus event, and Inventory would subscribe and apply the mutation itself, rather than exposing callable mutation methods.
- **Pros**: Keeps Inventory's mutation surface entirely event-driven, consistent with the project's default EventBus-first convention.
- **Cons**: Both `crafting.md` and `equipment-forge.md` require the mutation to complete **synchronously before** the confirming `component_repaired`/`item_rune_imbued` event fires (both GDDs' Rule 6/16 sequence the Inventory mutation as a precondition step, not a reaction) — an event-driven mutation would need a request/response round-trip (emit request, await confirmation) to preserve that ordering, which is exactly the pattern ADR-0020 Criterion A exists to avoid for gameplay-action-triggered, single-outcome calls.
- **Rejection Reason**: `has_items()` (the existing, already-Accepted precedent from ADR-0016/`inventory.md`) already established direct-call as the pattern for Inventory's cross-system query surface. Splitting mutations onto EventBus while queries stay direct-call would create an inconsistent API surface for the same Autoload.

### Alternative B: Separate mutation Autoload/service distinct from Inventory

- **Description**: A new `InventoryMutator` or similar service Autoload owns these three methods, reading/writing Inventory's internal state via a friend-like interface.
- **Pros**: Keeps Inventory's own Autoload surface minimal.
- **Cons**: `state_ownership` in the registry designates Inventory as sole owner of `inventory_item_data` with `write_access: inventory-only` — a separate mutator Autoload would either violate that (a second writer) or become a thin pass-through with no independent value, adding an Autoload boot-order entry for no architectural benefit.
- **Rejection Reason**: No technical justification for a second Autoload when the existing owner (Inventory) can simply expose more methods, exactly as ADR-0016's own Consequences section anticipated ("Anticipated query API... once those GDDs exist — not yet finalized").

## Consequences

### Positive
- Unblocks Crafting AC-4/AC-6/AC-11/AC-12 and Equipment Forge AC-9/AC-16(c) immediately — no further design work needed before these stories can leave `Blocked`.
- Single consistent calling convention (`has_items()`, `has_room_for()`, `clear_damaged_flag()`, `apply_rune_to_item()` are all direct Autoload calls) — no split between event-driven and direct-call Inventory access.
- The `locked`-field exemption is now a documented architectural invariant rather than a per-caller judgment call, closing the exact gap `equipment-forge.md` Rule 16 flagged as "a required amendment."

### Negative
- `InventorySlot` now carries two additional fields (`damaged`, `imbued_runes`) beyond ADR-0016's original four — a small growth in per-slot memory (negligible at the GDD's own 40-slot cap) and in `get_save_data()` payload size.
- Two more methods on Inventory's public Autoload surface that must each independently remember not to check `locked` — a future maintainer adding a fourth in-place-mutation method must know this pattern exists (mitigated by the explicit invariant statement in the Decision section, but still a discipline point).

### Risks
- **Risk**: A future caller might mistakenly assume `clear_damaged_flag()` or `apply_rune_to_item()` fires `item_added`/`item_removed` (since most other Inventory mutations do) and build UI logic that never refreshes on an in-place change.
  - **Mitigation**: Both GDDs already specify that no add/remove event fires; Crafting's/Equipment Forge's own UI-refresh logic must key off `component_repaired`/`item_rune_imbued` instead. Flagged here so implementers see it at the ADR level too.
- **Risk**: `imbued_runes.size() >= rune_slot_count` check depends on `rune_slot_count` being correctly read from the item's `ItemDefinitionResource` at call time — if that Resource lookup is stale or fails silently, the cap could be bypassed.
  - **Mitigation**: Reuses the exact same `GameDataRegistry.get_item_definition()` lookup path ADR-0016 already established for `is_unique_instance`/`base_stats` — no new lookup mechanism introduced, so this is an existing, already-relied-upon path, not a new risk surface.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| inventory.md | Cross-System Query & Mutation APIs section (added 2026-07-17): `has_room_for`, `clear_damaged_flag`, `apply_rune_to_item` | All three specified as direct-call methods on the existing Inventory Autoload, extending ADR-0016 |
| crafting.md | Rule 6 (`clear_damaged_flag`), Rule 7 (`has_room_for` pre-check before consume) | Method behaviors specified in Decision; both are in-place/read-only, no `item_added`/`item_removed` side effects for the damage-clear case |
| equipment-forge.md | Rule 16 (`apply_rune_to_item`, explicit Rule 5 lock exemption) | Exemption formalized as an architectural invariant on in-place-mutation methods, not left to caller discipline |

## Performance Implications
- **CPU**: Negligible — all three methods are gameplay-action-triggered (craft confirm, rune imbue), not per-frame. No frame-budget concern, consistent with ADR-0016's existing assessment of Inventory operations generally.
- **Memory**: Two new primitive fields per `InventorySlot` (`bool` + `Array`), well within the existing 40-slot-cap memory budget.
- **Load Time**: None — no new boot-time data loading introduced.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Inventory has no existing shipped implementation; this ADR extends the not-yet-implemented ADR-0016 design before either lands in code.

## Validation Criteria
- Unit test confirms `has_room_for()` returns `false` when adding would exceed the tier-capacity floor, `true` otherwise, for both stackable and unique-instance item types.
- Unit test confirms `clear_damaged_flag()`/`apply_rune_to_item()` do not fire `item_added` or `item_removed`, and do not check `locked` — specifically including a case where the target item is currently equipped (`locked == true`), confirming the mutation still succeeds.
- Unit test confirms `apply_rune_to_item()` returns `false` with zero mutation (unchanged `imbued_runes`, unchanged `stat_overrides`) when the target item's rune slots are already full.

## Related Decisions
- ADR-0016 (Inventory Storage Model) — the `InventorySlot` model this ADR extends
- ADR-0020 (Direct-Autoload-call exception pattern) — governs why these are direct calls, not EventBus events
- ADR-0003 (Save file format) — `get_save_data()` primitive-only constraint the two new fields must satisfy
- `design/gdd/crafting.md`, `design/gdd/equipment-forge.md` — source GDDs for all requirements this ADR addresses
