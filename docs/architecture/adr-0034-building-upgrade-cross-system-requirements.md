# ADR-0034: Building Upgrade Cross-System Requirements Model

## Status
Accepted

## Date
2026-08-12

## Acceptance Note
Accepted 2026-08-12 by direct user decision during `/create-epics building-upgrade`, to unblock that epic's requirement-coverage check — outside the normal `/architecture-review` gate (review-mode: lean), mirroring ADR-0020's own precedent for the identical situation. godot-specialist validation already completed at authoring time (non-blocking, 2 minor fixes applied — see the ADR's own Key Interfaces/Risks sections); no separate TD-ADR pass performed (lean mode skips it, per this session's `/architecture-decision` run). Backfilled ADR — `BuildingUpgrade`/`BuildingUpgradeResource` (`src/core/building_upgrade/`) were implemented 2026-08-11 and passed a full `/design-review` pass 2026-08-12 (see `design/gdd/reviews/building-upgrade-review-log.md`) before this ADR was written. This document formally validates the as-built design against the project's existing architectural stances rather than proposing something new — mirrors ADR-0020's own precedent of retroactively formalizing an already-in-use pattern.

**Addendum (2026-08-12, Story 004, found during `/code-review`)**: this ADR's Decision below describes `BuildingUpgrade` purely as a *read* consumer (Criterion A reads + the flagged Tarot group-lookup). Story 004 (TR-buildupgrade-004) added an *active publisher* role on top: `BuildingUpgrade` now also subscribes to 6 EventBus signals (`sanctuary_structure_built`, `tech_unlocked`, `item_added`, `item_removed`, `creature_acquired`, `creature_sacrificed`) to detect its own `VISIBLE_LOCKED`→`PURCHASABLE` transitions and emit `building_upgrade_became_purchasable` — ADR-0001's own default EventBus pattern, not a new exception this ADR needs to govern, but noted here so a future reader doesn't have to reverse-engineer the publisher role from the story file alone.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Data model, cross-system read architecture |
| **Knowledge Risk** | LOW — this ADR governs a Resource-backed recipe model and GDScript calling conventions (direct Autoload calls, group-based Node lookup), not any specific post-cutoff engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (no domain-specific module doc applies) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0020 (Direct-Autoload-Call Exception Pattern — governs this system's DefenseBuilding/Inventory/Menagerie reads), ADR-0024 (Defense Building tech-tree data model — the ledger this system reads via `is_structure_built()`), ADR-0021 (Inventory cross-system API — extended here with `has_specific_item()`), ADR-0026 (Menagerie creature lifecycle — extended here with `has_creature_species()`), ADR-0027 (Tarot modifier aggregation pipeline — the ledger this system reads via `is_card_unlocked()`), ADR-0032 (Presentation Shell Hosting Pattern — this system's own screen is hosted as a tab inside Equipment Forge's shell, per `equipment-forge.md`) |
| **Enables** | The Building Upgrade epic/stories (`/create-epics building-upgrade`, this session) — this ADR is what unblocks that epic's ADR-coverage requirement |
| **Blocks** | None — this ADR retroactively documents a decision already shipped in code; it does not gate any currently-blocked story |
| **Ordering Note** | `restore_order=33` must sequence after Defense Building (21), Tarot (22), and Equipment Forge (32) — all already lower, per `save-persistence.md`'s table (independently verified during this system's `/design-review`) |

## Context

### Problem Statement

Building Upgrade needed a data model for a new kind of Sanctuary purchase: one whose "ingredients" are not consumed from Inventory (like Crafting) or paid from a currency pool (like Defense Building's tech tree), but are instead **read, non-destructively, from four different other systems' own already-owned state** — an already-built Defense Building structure, a specific crafted Equipment item, a specific unlocked Tarot card, a specific owned Menagerie creature species — plus a conventional gold+material cost that IS spent. This requires deciding: (1) the Resource schema for a multi-category, non-consumed "recipe," (2) how this system's own permanent PURCHASED ledger is structured and persisted, and (3) — the actual architectural decision this ADR exists to validate — **how a read against four different systems' owned state is allowed to happen at all**, given ADR-0001's default EventBus-only cross-system communication rule.

### Constraints
- Must not violate ADR-0001's `direct_cross_system_node_reference` forbidden pattern without a documented, criteria-bound exception (ADR-0020).
- Must not duplicate or cache state that Defense Building/Inventory/Menagerie/Tarot already own — `defense_building_ledgers`, `inventory_item_data`, `menagerie_creature_state`, and `tarot_progress_ledger` (registry) are each already registered as owned by exactly one system.
- Must follow `resource_object_in_save_data` (ADR-0003) — this system's own save payload must be primitive-only.
- Must slot into `save-persistence.md`'s `restore_order` sequence without colliding with an existing slot.

### Requirements
- Read-only, live (non-cached) queries against 4 upstream systems' owned state, re-evaluated on every relevant EventBus signal (no polling per-frame).
- A permanent, one-way `PURCHASED` ledger, structurally identical in shape to Defense Building's own `_tech_ledger`/`_structure_ledger` (`Dictionary[StringName, bool]`).
- Must not require any of the 4 upstream systems to change their own state-ownership model to accommodate this system.

## Decision

**Building Upgrade is a scene-instanced (not Autoload) system, following the same pattern as Crafting/Equipment Forge/Tarot, owning exactly one piece of state — its own `_purchased_upgrades: Dictionary[StringName, bool]` ledger — and reading four upstream systems' state through two different sanctioned mechanisms depending on whether the upstream system is an Autoload:**

1. **DefenseBuilding, Inventory, Menagerie (all Autoloads)** — read via **direct Autoload call**, classified under **ADR-0020 Criterion A** (read-only query against the registry's sole-owner of that state, at a frequency — every relevant EventBus signal while the Building Upgrade tab is open — where EventBus round-trip dispatch would provide no decoupling benefit, since Building Upgrade is the only consumer of these specific query results at this call site): `GDefenseBuilding.is_structure_built(structure_id)` (pre-existing, ADR-0024), `GInventory.has_specific_item(item_id)` (new, added 2026-08-11 — narrowly-scoped addition to Inventory's existing query surface, same pattern as `has_room_for()`), `GMenagerie.has_creature_species(species_id)` (new, added 2026-08-11 — same pattern).
2. **Tarot (scene-instanced, NOT an Autoload)** — read via `get_tree().get_first_node_in_group(&"tarot")`, calling `is_card_unlocked(card_id)` on whatever instance (if any) is found. **This is explicitly flagged, not silently accepted, as outside ADR-0020's own stated scope** (ADR-0020 Decision: "Autoload-to-Autoload (or UI-to-Autoload)") — see Risks below.
3. **Own state**: `_purchased_upgrades: Dictionary[StringName, bool]`, mirroring `defense_building_ledgers`' exact shape (registry). Persisted via `SaveRestorer`, `restore_order=33`. `resolve_upgrade()` debits `resources_changed(-cost, "structure_upgrade")` and writes the ledger, matching Defense Building's own `resolve_tech_unlock()`/`resolve_structure_build()` shape exactly (dual-gate: eligibility + materials, single synchronous call, no `await`).

### Architecture Diagram

```
BuildingUpgrade (scene-instanced, hosted inside Equipment Forge's shell — ADR-0032)
  ├─ owns: _purchased_upgrades: Dictionary[StringName, bool]  (its own only state)
  │
  ├─ Criterion A direct calls (ADR-0020) — read-only, sole-owner callees, all Autoloads:
  │    GDefenseBuilding.is_structure_built(structure_id)      [ADR-0024]
  │    GInventory.has_specific_item(item_id)                  [ADR-0021, extended 2026-08-11]
  │    GMenagerie.has_creature_species(species_id)             [ADR-0026, extended 2026-08-11]
  │
  └─ group-based lookup (NOT an ADR-0020 instance — flagged gap, see Risks):
       get_tree().get_first_node_in_group(&"tarot") → Tarot.is_card_unlocked(card_id)  [ADR-0027]
       Fails closed (false, never a crash) when no live "tarot" instance exists in the current
       scene tree — true today for any scene other than TarotDeckUI.tscn (see BUG-0001).
```

### Key Interfaces

```gdscript
# BuildingUpgradeResource (Resource, content-authored, assets/data/building_upgrades/*.tres)
upgrade_id: StringName
target_structure_id: StringName
prerequisite_upgrade_id: StringName          # "" = chain root
requirements: Dictionary[String, StringName] # 1-4 entries: "building"|"equipment"|"tarot"|"creature" -> target id
gold_cost: int
material_cost: Dictionary[StringName, int]   # rarity-keyed
effect_description: String                   # content-authoring only, no mechanical effect owned here

# BuildingUpgrade (scene-instanced Node, not Autoload)
func is_visible(upgrade_id: StringName) -> bool          # target_structure_id BUILT?
func can_purchase(upgrade_id: StringName) -> bool         # all requirements + costs satisfied?
func resolve_upgrade(upgrade_id: StringName) -> bool      # dual-gate resolve; debits cost, writes ledger, emits structure_upgraded
func _requirement_satisfied(requirement_type: String, identifier: StringName) -> bool  # the 4-branch dispatcher above
```

## Alternatives Considered

### Alternative B: Route all 4 requirement checks through EventBus request/response
- **Description**: Instead of direct calls, Building Upgrade would emit a request event per requirement check and each upstream system would respond with its own event.
- **Pros**: Perfect architectural uniformity with ADR-0001's default rule; no exception to reason about.
- **Cons**: Request/response round-tripping for what is, per system, a single Dictionary/method lookup provides zero decoupling benefit (Building Upgrade is the only consumer of these specific results, at this call site) — exactly the case ADR-0020 already carved its exception for (Grid, GameDataRegistry, MissionEconomy). Re-deriving the same argument here rather than citing ADR-0020 would be exactly the "third instance re-justifying itself independently" problem ADR-0020 was written to prevent.
- **Rejection Reason**: ADR-0020 already exists and already covers 3/4 of these calls (DefenseBuilding, Inventory, Menagerie) cleanly under Criterion A. Inventing a fourth independent justification, or a fourth calling convention, for the same underlying situation would be pure architectural churn.

### Alternative C: BuildingUpgrade caches local snapshots of requirement state
- **Description**: On each relevant EventBus signal, Building Upgrade would copy the current satisfied/unmet state of every requirement into its own local cache, rather than querying live at evaluation time.
- **Pros**: Slightly fewer cross-system calls if many upgrades share the same requirement.
- **Cons**: Directly duplicates state four other systems already own (`defense_building_ledgers`, `inventory_item_data`, `menagerie_creature_state`, `tarot_progress_ledger`) — a second, unsynchronized copy of e.g. "is this tech unlocked" is exactly the class of bug ADR-0001's state-ownership model exists to prevent (which copy is authoritative after a save/load, a scene transition, or a race between two writers?).
- **Rejection Reason**: Violates the registry's own state-ownership rule for no real performance benefit — Building Upgrade's own re-evaluation frequency (per EventBus signal while its tab is open, not per-frame) does not need caching to stay within budget.

## Consequences

### Positive
- Reuses ADR-0020's already-established Criterion A rubric for 3 of 4 upstream reads — no new calling-convention exception needed for DefenseBuilding/Inventory/Menagerie.
- `Inventory.has_specific_item()`/`Menagerie.has_creature_species()` are narrowly-scoped additions that follow this project's own established pattern for adding a query method to an existing Autoload's surface (e.g. `has_room_for()`), rather than a new interface class.
- Own state (`_purchased_upgrades`) is structurally identical to Defense Building's own ledgers — no new persistence pattern invented.

### Negative
- Introduces a 4th direct-call producer (Menagerie, via `has_creature_species()`) and extends a 3rd (Inventory) — a small, incremental surface-area cost consistent with the project's established trend (each new Feature-layer system tends to add one narrow query to an existing Autoload).
- The Tarot group-lookup call is NOT covered by any existing governing ADR (see Risks) — this ADR proceeds anyway, following the same "flag, don't silently invent a new governing decision mid-feature" discipline the project already uses elsewhere (e.g. Building Upgrade's own GDD explicitly declining to invent Watchtower's mechanical effect).

### Risks
- **Risk**: The Tarot read (`get_tree().get_first_node_in_group(&"tarot")` → direct method call on whatever Node is found) is architecturally the same shape as a `direct_cross_system_node_reference` (ADR-0001's forbidden pattern) — it is NOT one of ADR-0020's two criteria, because ADR-0020's Decision is explicitly scoped to "Autoload-to-Autoload (or UI-to-Autoload)" calls, and Tarot is not an Autoload (`tarot.gd`'s own doc comment: "deliberately scene-instanced... not an Autoload"). This exact group-lookup shape is *already* used identically elsewhere in the shipped codebase (Crafting discovering `equipment_forge`, Equipment Forge discovering `tarot`) — meaning this is at least the 3rd unreviewed instance of an unformalized pattern, the same situation ADR-0020 itself was written to close for the Autoload case.
  - **Mitigation**: Not resolved by this ADR — scope-bounded to Building Upgrade's own decision, and this pattern's other instances predate and are outside this system. Flagged explicitly here rather than either (a) silently treating it as already-covered by ADR-0020, or (b) inventing a new governing ADR for a cross-cutting pattern that affects systems this ADR doesn't own. Recommend a future dedicated ADR ("group-based scene-instanced cross-system lookup exception pattern," mirroring ADR-0020's own retroactive-formalization structure) once a second data point beyond this session's findings justifies it.
- **Risk**: The Tarot read currently fails closed with zero live instance reachable from Sanctuary UI (where Building Upgrade's own screen lives) — not a defect in this ADR's own decision, but a real, independent, currently-shipping data-loss bug in Tarot's own save-registration lifecycle, found while investigating this exact dependency during `/design-review` (2026-08-12).
  - **Mitigation**: Filed as `production/qa/bugs/BUG-0001.md`. Explicitly NOT this ADR's or Building Upgrade's own defect to fix — Tarot's own architecture (Autoload conversion, most likely) needs its own ADR from Tarot's owner. `"tarot"`-keyed upgrade content should not ship until that's resolved (`building-upgrade.md`'s own Open Questions table already carries this caveat). **Forward-looking hazard for whichever future ADR resolves BUG-0001** (godot-specialist validation, 2026-08-12): `get_first_node_in_group()` is order-dependent and undocumented when multiple members of a group exist simultaneously — if a future fix ever leaves two live `"tarot"`-group instances at once (e.g. a transitional state mid-Autoload-migration, rather than the current never-simultaneously-alive case), Building Upgrade would silently read from an arbitrary one of them with no error. That future ADR must guarantee at most one live `"tarot"`-group member at any time, not just eventually-consistent single-instance state.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| building-upgrade.md | Rule 2 (`"building"`/`"equipment"`/`"tarot"`/`"creature"` requirement resolution) | Formalizes the calling convention for each of the 4 branches — 3 as ADR-0020 Criterion A, 1 (Tarot) explicitly flagged as outside existing coverage |
| building-upgrade.md | Interactions with Other Systems / Dependencies (Save & Persistence row) | Confirms `restore_order=33` is correctly sequenced against `defense_building_ledgers` (21), `tarot_progress_ledger` (22), `equipment_forge_ledgers` (32) |
| defense-building.md | `is_structure_built()` as a read-only query surface | Confirms this ADR's Criterion A classification matches the registry's own `defense_building_ledgers` entry, which already documents this exact exception |
| inventory.md, menagerie.md | Narrowly-scoped query-method-addition precedent (`has_room_for()`) | `has_specific_item()`/`has_creature_species()` follow the identical addition pattern, not a new interface class |

## Performance Implications
- **CPU**: Negligible — reads are UI-tab-gated (only evaluated while the Building Upgrade tab is mounted), not per-frame; each read is an O(1) Dictionary/Array lookup on the callee side.
- **Memory**: `_purchased_upgrades` scales with total authored upgrade count (expected low tens at most) — negligible.
- **Load Time**: None — no new boot-time work beyond the existing `BuildingUpgradeResource` content-loading pass GameDataRegistry already performs.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — this ADR documents conventions and a data model already shipped in code (2026-08-11); no code changes result from writing this ADR.

## Validation Criteria
- `docs/registry/architecture.yaml`'s `state_ownership` entries for `defense_building_ledgers`/`inventory_item_data`/`menagerie_creature_state` should each gain (or already carry) a `referenced_by` line for this ADR, once the registry is updated (Step 6).
- `/architecture-review` (run independently, next session) should confirm no conflict between this ADR's Criterion A classification and the existing `defense_building_ledgers` registry entry's own Criterion A precedent.
- The Tarot group-lookup gap (Risks, above) should be re-surfaced by `/architecture-review` as an open item, not silently absorbed as "already resolved by ADR-0020."

## Related Decisions
- ADR-0001 (EventBus architecture) — the general rule this ADR's Criterion-A reads are an exception to
- ADR-0020 (Direct-Autoload-Call Exception Pattern) — governs 3 of this system's 4 upstream reads
- ADR-0024 (Defense Building tech-tree data model) — the ledger shape this system's own `_purchased_upgrades` mirrors, and the `is_structure_built()` interface this system reads
- ADR-0021 (Inventory cross-system API), ADR-0026 (Menagerie creature lifecycle) — the two Autoload surfaces this system extends with new query methods
- ADR-0027 (Tarot modifier aggregation pipeline) — the ledger this system reads via the flagged non-ADR-0020 group-lookup path
- ADR-0032 (Presentation Shell Hosting Pattern) — governs Building Upgrade's own screen's hosting inside Equipment Forge's shell
- `design/gdd/building-upgrade.md`, `design/gdd/reviews/building-upgrade-review-log.md`, `production/qa/bugs/BUG-0001.md`
