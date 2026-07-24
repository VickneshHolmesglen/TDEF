# ADR-0022: Constellation Pattern-Detection Data Structure

## Status
Accepted

## Acceptance Note
Accepted 2026-07-18 (Sprint 6, S6-02) by explicit user decision, outside the normal `/architecture-review` gate — same precedent as Epic 05's ADR-0020/0021/0023/0024/0026 batch acceptance. A lightweight manual cross-check (not a formal `/architecture-review` pass, which cannot run cleanly in a session that just authored the ADR-0003 revision this ADR depends on) confirmed: all 5 dependency ADRs (0001, 0003, 0005, 0016, 0020) are `Accepted`; `restore_order=24` does not collide with any other assigned value (10, 11, 20, 21, 22, 30, 31, 32, 34 — full authoritative table checked). Unblocks Epic 06's Constellation stories (001–006) — flips them `Blocked` → `Ready`. An independent `/architecture-review` pass in a fresh session is still recommended before Epic 06 reaches its next milestone, per this ADR's own note on ADR-0029 surfacing the SavePersistence gap.

## Date
2026-07-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Data Structures / Performance |
| **Knowledge Risk** | LOW — reuses Grid's already-Accepted `get_occupied_cells_in_radius()` read API (ADR-0005) and typed `Dictionary`/`Array` (Godot 4.4+, already verified working per `VERSION.md`'s Project-Specific API Tracking table). No new engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0005 (Grid System Data Model); ADR-0020 (Direct-Autoload-call exception pattern) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[K,V]` (4.4+) for the active-instance table and Discovery Ledger — same already-verified pattern Grid and Pathfinding use |
| **Verification Required** | None beyond what `VERSION.md` already confirms for typed Dictionaries |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (Grid System Data Model — Accepted; Constellation's spatial queries call `Grid.get_occupied_cells_in_radius()`), ADR-0020 (Direct-Autoload-call exception pattern — Constellation's Grid calls are Criterion A), ADR-0001 (EventBus — Constellation subscribes to `tower_placed`/`tower_removed`/`tower_destroyed` and emits `constellation_activated`/`constellation_deactivated`/`constellation_rune_discovered`) |
| **Enables** | `design/gdd/constellation.md` implementation stories (currently blocked pending this ADR per the 2026-07-17 architecture review — all 27 requirements across the 9 new-system batch include Constellation's 3) |
| **Blocks** | None further downstream within this batch — Equipment Forge and Encyclopedia only consume `constellation_rune_discovered` as an event payload, no direct dependency on this ADR's internal data structure |
| **Ordering Note** | None — Constellation depends only on already-Accepted Tower/Grid/EventBus contracts, consistent with the review's note that this is "Feature layer, only depends on already-Approved Tower/Grid/EventBus." |

## Context

### Problem Statement

`design/gdd/constellation.md` specifies a localized, per-event pattern-detection algorithm (Core Rules 1–9, Formula 2) whose entire design intent is that per-event recheck cost must not scale with total tower count on the field (Edge Cases: "40–60 towers... recheck cost is bounded to a `pattern_search_radius`-cell neighborhood"). No ADR exists specifying the actual data structures — the active-instance table, the Discovery Ledger, and the canonicalization/matching algorithm — that make this O(local neighborhood) guarantee real rather than aspirational prose. Without this ADR, all of Constellation's implementation stories are `Blocked`.

The GDD's own OQ-4 (no interface for reading `constellation_eligibility_tag` off a placed tower) has since been **resolved** — as of 2026-07-17, `tower_placed`/`tower_removed`/`tower_destroyed` payloads in `event-bus.md` all carry `constellation_eligibility_tag: String` directly. This ADR does not need to resolve OQ-4 itself; it inherits the now-closed payload contract and only needs to specify the detection data structure built on top of it.

### Constraints

- Must not call `Grid.get_all_occupied_cells()` on the hot recheck path (Core Rule 8 is explicit and testable: AC-17 asserts a test double's `get_all_occupied_cells()` call counter stays 0).
- Must use `Grid.get_occupied_cells_in_radius(center, radius)` per ADR-0005's existing read API and ADR-0020's Criterion A (read-only, high-frequency, sole-owner callee).
- Must produce exactly one `pattern_id` per physical tower cluster regardless of read/iteration order (Core Rule 1's canonicalization rule, AC-28) — the anchor is always the lexicographically smallest cell in the shape's cell set.
- Must not re-fire `constellation_rune_discovered` for an already-`DISCOVERED` `shape_id`, even across break/reform cycles at the same or different anchors (Core Rule 7, AC-15/AC-16) — the Discovery Ledger is a one-way, per-`shape_id` terminal set that must persist across save/load (per the now-assigned `restore_order=24`).
- Must independently detect and fire overlapping pattern instances that share member towers (AC-26) — never suppress, average, or pick one shape over another when a single event completes two instances at once.

### Requirements

- `pattern_search_radius` (registered constant, `design/registry/entities.yaml`, currently `3` for the 4-shape catalogue) bounds every `Grid.get_occupied_cells_in_radius()` call.
- Detection must run synchronously, per-event, non-batched, triggered by `tower_placed`/`tower_removed`/`tower_destroyed` (Core Rule 3).
- Active-instance table must support O(1)-ish membership checks (a tower removal/destruction must efficiently find which active instances it belongs to, to fire the correct `constellation_deactivated` events — potentially more than one, per AC of the "tower belonging to two or more overlapping ACTIVE instances" edge case).

## Decision

**Two data structures, both Constellation-internal (not accessible to other systems — same "not accessible" convention as every other system's mission-runtime state in the registry):**

1. **Active-instance table**: `Dictionary[String, ConstellationInstance]` keyed by `pattern_id` (the canonical `"{shape_id}@{anchor_cell}"` string, e.g. `"triad_line@(2,4)"`, matching the GDD's own worked examples). `ConstellationInstance` is a lightweight `RefCounted` (not a Resource — mirrors ADR-0016's `InventorySlot` precedent for mission-scoped runtime state that never needs `validate()` or boot-time loading): `shape_id: String`, `anchor_cell: Vector2i`, `member_cells: Array[Vector2i]`, `member_tower_ids: Array[int]`, `bonus_type: String`, `bonus_value: float`. This table is rebuilt incrementally per event, never fully rescanned — an entry is added on activation, removed on deactivation.

2. **Reverse index**: `Dictionary[int, Array[String]]` keyed by `tower_id`, mapping to the list of `pattern_id`s that tower is currently a member of. This is what makes multi-instance-membership deactivation (AC's overlapping-instance edge case) efficient: on `tower_removed`/`tower_destroyed`, look up the reverse index for the affected `tower_id`, and for each `pattern_id` found, deactivate that instance and remove it from both structures — no scan of the active-instance table itself is needed.

**Discovery Ledger** (separate from the active-instance table, since it is save-persisted and playthrough-scoped rather than mission-scoped): `Dictionary[String, bool]` keyed by `shape_id` (not `pattern_id` — discovery is per-shape, not per-instance, per Core Rule 7/AC-15). Implements `SaveRestorer` per ADR-0003's convention, registered at `restore_order=24` (already assigned in `save-persistence.md` per the session's registry work). `get_save_data()` returns the ledger as a flat `Dictionary[String, bool]` — already primitive-only by construction, satisfying `resource_object_in_save_data` (ADR-0003) without any conversion step.

**Detection algorithm on each `tower_placed`/`tower_removed`/`tower_destroyed` event:**
1. Call `Grid.get_occupied_cells_in_radius(changed_cell, pattern_search_radius)` — the one and only Grid call per event (Core Rule 8).
2. For `tower_placed`: for every catalogued shape, for every orientation, test whether `changed_cell` completes a valid instance anchored somewhere within the returned neighborhood — checking eligibility (uniform, non-empty `constellation_eligibility_tag`, read directly off the `tower_placed` payload for `changed_cell` and cross-referenced against each candidate member's own last-known tag, cached in the reverse index's companion data — see Key Interfaces) and canonicalizing the anchor per Core Rule 1. Any newly-satisfied instance is added to the active-instance table and reverse index; `constellation_activated` fires; if `shape_id` is not yet in the Discovery Ledger, `constellation_rune_discovered` fires and the ledger is updated.
3. For `tower_removed`/`tower_destroyed`: look up `changed_cell`'s `tower_id` in the reverse index; for each `pattern_id` found, remove the entry from both structures and fire `constellation_deactivated(pattern_id, reason)`.

**Per-tower tag cache**: since `constellation_eligibility_tag` arrives only in the event payload (not queryable from Grid, which does not store Power-component data — Grid's `grid_cell_data` per the registry is spatial/occupancy only), Constellation maintains its own `Dictionary[int, String]` cache of `tower_id -> constellation_eligibility_tag`, populated from `tower_placed` payloads and cleared on `tower_removed`/`tower_destroyed`. This is the only per-tower state Constellation itself owns; it is not shared with or readable by any other system.

### Architecture Diagram

```
Constellation (scene-instanced node, subscribes to EventBus, calls Grid directly)
  ├─ _active_instances: Dictionary[String, ConstellationInstance]   # pattern_id -> instance
  ├─ _tower_membership: Dictionary[int, Array[String]]              # tower_id -> [pattern_id, ...]
  ├─ _tag_cache: Dictionary[int, String]                            # tower_id -> constellation_eligibility_tag
  ├─ _discovery_ledger: Dictionary[String, bool]                    # shape_id -> discovered (SaveRestorer, restore_order=24)
  │
  ├─ subscribes (EventBus): tower_placed, tower_removed, tower_destroyed
  ├─ calls (direct, Criterion A): Grid.get_occupied_cells_in_radius(cell, pattern_search_radius)
  └─ emits (EventBus): constellation_activated, constellation_deactivated, constellation_rune_discovered
```

### Key Interfaces

```gdscript
# ConstellationInstance (RefCounted, mission-scoped, never saved directly)
class_name ConstellationInstance extends RefCounted
var shape_id: String
var anchor_cell: Vector2i
var member_cells: Array[Vector2i] = []
var member_tower_ids: Array[int] = []
var bonus_type: String
var bonus_value: float

# Constellation (scene-instanced node)
var _active_instances: Dictionary[String, ConstellationInstance] = {}   # pattern_id key
var _tower_membership: Dictionary[int, Array[String]] = {}              # tower_id -> pattern_ids
var _tag_cache: Dictionary[int, String] = {}                            # tower_id -> tag
var _discovery_ledger: Dictionary[String, bool] = {}                    # shape_id -> discovered

# SaveRestorer (ADR-0003) — Discovery Ledger only; active-instance table is NOT persisted (mission-scoped, rebuilds from Grid/Tower state each mission)
func get_save_key() -> String: return "constellation"
func get_save_data() -> Dictionary: return {"discovery_ledger": _discovery_ledger}
func restore_save_data(data: Dictionary) -> bool: ...
func reset_to_defaults() -> void: _discovery_ledger.clear()

func _on_tower_placed(event: TowerPlacedEvent) -> void:
    _tag_cache[event.tower_id] = event.constellation_eligibility_tag
    var neighborhood: Array[Vector2i] = Grid.get_occupied_cells_in_radius(event.grid_position, PATTERN_SEARCH_RADIUS)
    _recheck_patterns_near(event.grid_position, neighborhood)

func _on_tower_removed_or_destroyed(tower_id: int, reason: String) -> void:
    # .duplicate() is required here: the raw reference would be mutated in place
    # by _deactivate_instance() (which scrubs pattern_id from every member's
    # entry, including this one), causing a mutate-during-iterate skip otherwise.
    var affected: Array[String] = _tower_membership.get(tower_id, []).duplicate()
    for pattern_id in affected:
        _deactivate_instance(pattern_id, reason)
    _tag_cache.erase(tower_id)

func _deactivate_instance(pattern_id: String, reason: String) -> void:
    var instance: ConstellationInstance = _active_instances.get(pattern_id)
    if instance == null:
        return
    # Scrub pattern_id from EVERY member tower's reverse-index entry, not just
    # the triggering tower — otherwise non-triggering members retain a stale
    # pattern_id after the instance is gone.
    for member_tower_id in instance.member_tower_ids:
        var entry: Array[String] = _tower_membership.get(member_tower_id)
        if entry != null:
            entry.erase(pattern_id)
            if entry.is_empty():
                _tower_membership.erase(member_tower_id)
    _active_instances.erase(pattern_id)
    EventBus.constellation_deactivated.emit(pattern_id, reason)
```

## Alternatives Considered

### Alternative A: Full-board rescan on every event (no active-instance table, no reverse index)

- **Description**: On every `tower_placed`/`tower_removed`/`tower_destroyed`, call `Grid.get_all_occupied_cells()` and re-derive every active pattern from scratch.
- **Pros**: Simplest possible implementation — no incremental state to keep in sync, no risk of the active-instance table drifting from actual Grid occupancy.
- **Cons**: Directly violates Core Rule 8 and AC-17 (explicitly forbids `get_all_occupied_cells()` on the hot path) and the GDD's own stated design intent that per-event cost must not scale with total tower count (Edge Cases, AC-30).
- **Rejection Reason**: The GDD is unambiguous and testable on this point — this alternative fails the acceptance criteria by construction.

### Alternative B: Store pattern membership directly on Tower System's `TowerMissionState` instead of a separate Constellation-owned table

- **Description**: Rather than Constellation maintaining its own reverse index, tag each `TowerMissionState` (ADR-0008) with the `pattern_id`s it belongs to, so Tower System can answer "what patterns is this tower in" directly.
- **Pros**: Avoids a second copy of membership data.
- **Cons**: Violates the registry's `write_access: tower-system-only` on `tower_mission_state` (ADR-0008) — Constellation would need write access to another system's owned state, which the project's state-ownership model forbids. Also creates a bidirectional coupling (Tower needs to know about Constellation's pattern IDs) where the GDD's own Interactions table states Constellation never writes to Tower state directly.
- **Rejection Reason**: Violates an existing, Accepted ADR's write-access boundary (ADR-0008) for no compensating benefit — the reverse index is cheap (an `int -> Array[String]` map, bounded by tower count) and keeps ownership clean.

## Consequences

### Positive
- Detection cost per event is bounded by `pattern_search_radius` and catalogue size (4 shapes at Vertical Slice), never by total tower count — satisfies AC-30 by construction, not by convention.
- The reverse index makes multi-instance deactivation (a tower shared by 2+ overlapping instances) an O(membership count) lookup rather than a scan of all active instances.
- Discovery Ledger's `Dictionary[String, bool]` is already primitive-only, requiring zero conversion work to satisfy ADR-0003's save-data constraint.

### Negative
- Three separate `Dictionary` structures (active-instance table, reverse index, tag cache) must be kept mutually consistent — a bug in one update path (e.g. forgetting to clear `_tag_cache` on `tower_destroyed`) could leak stale per-tower state across a mission's lifetime (bounded, since it resets on scene reload per mission, but still a within-mission risk).
- The tag cache duplicates data Grid/Tower already emit per-event rather than reading it fresh each time — a minor memory/consistency tradeoff traded for avoiding a second cross-system query per candidate member cell during a recheck.

### Risks
- **Risk**: If `_tag_cache` is not updated atomically with `_tower_membership`/`_active_instances` (e.g. an exception partway through `_recheck_patterns_near`), the three structures could desync within a single mission.
  - **Mitigation**: All three updates for a single event must happen within one synchronous handler call (no `await` between them) — consistent with the project's existing synchronous-dispatch convention (ADR-0001) and Core Rule 3's "synchronous, per-event, non-batched" requirement, which already forces this to be a single call stack.
- **Risk**: `pattern_search_radius` is a derived constant (Formula 2) that must be recomputed whenever a larger pattern is added to the catalogue — a stale radius silently under-detects at the new shape's true edges (already flagged as a Tuning Knobs risk in the GDD itself).
  - **Mitigation**: Already registered in `design/registry/entities.yaml` (`constellation_pattern_search_radius`) per this session's earlier registry work — any future catalogue change should be checked against that registry entry, not hand-derived again.
- **Risk** (godot-specialist validation): `Dictionary`/`Array` values in GDScript are reference types — reading `_tower_membership.get(tower_id, [])` and iterating it directly while `_deactivate_instance()` mutates that same array (removing entries) causes a mutate-during-iterate skip, silently dropping a deactivation.
  - **Mitigation**: `.duplicate()` the affected-`pattern_id` list before iterating (specified in Key Interfaces above). `_deactivate_instance()` must also scrub the departing `pattern_id` from every member tower's reverse-index entry, not only the triggering tower's — otherwise non-triggering members retain a stale `pattern_id` after the instance is gone. Both fixes are now spelled out explicitly in Key Interfaces rather than left implicit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| constellation.md | Core Rule 8 / Formula 2: localized, radius-bounded detection, no full-board scan | `Grid.get_occupied_cells_in_radius()` is the only Grid call per event; no active-instance rescan, no `get_all_occupied_cells()` |
| constellation.md | Core Rule 1: canonicalization (lexicographically-smallest-cell anchor) prevents duplicate `pattern_id` | Anchor computed deterministically at detection time, keyed identically regardless of read order |
| constellation.md | Core Rule 7 / AC-15/AC-16: Discovery Ledger never re-fires per `shape_id` | Separate `Dictionary[String, bool]` keyed by `shape_id` (not `pattern_id`), checked before `constellation_rune_discovered` fires |
| constellation.md | Overlapping-instance deactivation edge case | Reverse index (`tower_id -> Array[pattern_id]`) makes multi-instance deactivation an O(membership) lookup, firing one `constellation_deactivated` per affected `pattern_id` |
| constellation.md | OQ-1 (Discovery Ledger persistence) | `SaveRestorer` implementation specified in Key Interfaces, `restore_order=24` (already assigned in `save-persistence.md`) |

## Performance Implications
- **CPU**: Per-event cost is O(catalogue size × orientations × neighborhood size), independent of total tower count on the field — satisfies the GDD's own stated design intent (AC-30). No per-frame cost; detection only runs on the three triggering events.
- **Memory**: Three `Dictionary` structures bounded by (active pattern count, tower count, tower count) respectively — negligible at the GDD's own 40–60 tower ceiling.
- **Load Time**: None — Discovery Ledger restore happens during Save & Persistence's existing restore pass (`restore_order=24`), no new load phase.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Constellation has no existing implementation; this is a greenfield decision.

## Validation Criteria
- Unit test confirms a test-double Grid's `get_all_occupied_cells()` call counter stays 0 across any sequence of `tower_placed`/`tower_removed`/`tower_destroyed` events (mirrors AC-17 directly).
- Unit test confirms detection cost (measured as Grid calls made, not wall-clock) does not increase as total tower count grows from 10 to 60, for a fixed number of triggering events (mirrors AC-30).
- Unit test confirms a tower belonging to two overlapping active instances, when destroyed, fires exactly two `constellation_deactivated` events (one per `pattern_id`), not one combined event.
- Unit test confirms re-forming an already-`DISCOVERED` shape at a new anchor fires `constellation_activated` but not `constellation_rune_discovered` (mirrors AC-15).
- Integration test confirms the Discovery Ledger round-trips correctly across a save/load cycle at `restore_order=24`.

## Related Decisions
- ADR-0005 (Grid System Data Model) — source of `get_occupied_cells_in_radius()`, the only Grid API this ADR's hot path calls
- ADR-0020 (Direct-Autoload-call exception pattern) — governs why Constellation's Grid calls are direct, not EventBus
- ADR-0016 (Inventory Storage Model) — precedent for a plain-`RefCounted`, non-Resource runtime data structure with a `SaveRestorer`-implementing owner
- ADR-0003 (Save file format) — `SaveRestorer` convention the Discovery Ledger implements
- ADR-0008 (Tower Placement Gate) — source of the write-access boundary that ruled out Alternative B
- `design/gdd/constellation.md` — source GDD for all requirements this ADR addresses
