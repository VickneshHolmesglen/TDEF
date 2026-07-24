# ADR-0029: Tower Mastery Proximity-Detection Strategy

## Status
Accepted

## Acceptance Note
Accepted 2026-07-18 (Sprint 6, S6-02) by explicit user decision, outside the normal `/architecture-review` gate — same precedent as Epic 05's ADR-0020/0021/0023/0024/0026 batch acceptance. A lightweight manual cross-check (not a formal `/architecture-review` pass, which cannot run cleanly in a session that just authored the ADR-0003 revision this ADR depends on) confirmed: all 5 dependency ADRs (0005, 0009, 0010, 0020, 0022) are `Accepted`; `restore_order=34` does not collide with any other assigned value (10, 11, 20, 21, 22, 24, 30, 31, 32 — full authoritative table checked). The MEDIUM engine-risk classification (live-profiling of the accrual loop) remains open — Sprint 6's S6-05 prototype task exists specifically to close it; acceptance here does not substitute for that verification. Unblocks Epic 06's Tower Mastery stories (007–013) — flips them `Blocked` → `Ready`, except Story 008 which remains additionally blocked on the `tower.md`/`event-bus.md` payload revision it itself requires. An independent `/architecture-review` pass in a fresh session is still recommended before Epic 06 reaches its next milestone.

## Date
2026-07-17

## Last Verified
2026-07-17 — `SkillDefinitionResource` amended by ADR-0030 (Hero Skill Build): Rule 2's own text explicitly stated this Resource must round-trip between both systems' content pipelines without duplication, but this ADR's original definition (`skill_id`, `source_build_signature`, `mastery_threshold_seconds`, `output`) omitted the 2 fields Hero Skill Build actually needs (`category`, `passive_slot_count`) and used a less descriptive name (`output`) for what Hero Skill Build calls `effect_data`. **Corrected**: `output` renamed `effect_data`; `category: String` and `passive_slot_count: int` added. See ADR-0030's Key Interfaces for the complete, authoritative field list — this ADR's own Key Interfaces section below is updated to match. Source directory also corrected: `assets/data/tower_mastery_skills/` → **`assets/data/skills/`** (the canonical shared path, since this Resource is loaded by both systems, not owned by Tower Mastery alone).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Performance / Timing |
| **Knowledge Risk** | MEDIUM (per `systems-index.md`'s own High-Risk table) — not from any post-cutoff API, but from an unvalidated live-performance assumption: this GDD's own per-frame accrual loop has not been profiled against a real playable build. `systems-index.md` explicitly recommends prototyping before finalizing a specific polling strategy; this ADR commits to the strategy the GDD already specifies (cell-boundary-triggered recompute, not per-frame Grid queries) but flags the actual frame-cost validation as an open Verification Required item, not something an ADR alone can close. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0005 (Grid System Data Model — `get_occupied_cells_in_radius()`, the only Grid API this ADR's hot path calls); ADR-0022 (Constellation pattern-detection — direct precedent for resolving a "GDD needs new data on an existing event payload" gap by extending the payload rather than adding a query API) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[String, float]`/`Dictionary[int, String]` (4.4+, already verified working) |
| **Verification Required** | **Live profiling of the per-physics-frame accrual loop** (Formula 1) against a real mission with multiple simultaneously-accruing `build_signature`s and a full 100-monster wave active — this is the specific validation `systems-index.md` flags as needed before this system's HIGH-risk classification can be downgraded. Not closeable by ADR review alone. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (Grid System Data Model — `get_occupied_cells_in_radius()`), ADR-0009 (Resource Data Model — `SkillDefinitionResource`), ADR-0022 (Constellation pattern-detection — direct precedent for the event-payload-extension resolution this ADR applies to `get_component_loadout()`), ADR-0010 (Hero-Tower Synced Class — the sibling accumulator this system deliberately shares a radius constant with but never merges logic with, per Rule 2) |
| **Enables** | `design/gdd/tower-mastery.md` implementation stories (currently blocked pending this ADR); indirectly Hero Skill Build (consumes `skill_unlocked`) |
| **Blocks** | None further downstream within this batch |
| **Ordering Note** | This ADR does **not** reclassify any system's Autoload status — Tower Mastery itself is scene-instanced (`MissionScene` child; nothing calls into it directly, and its ephemeral per-mission data has no reason to survive past the mission). Unlike the four prior reclassifications this session, the architectural fix here is a **different pattern**: resolving `get_component_loadout()`'s cross-system data need by extending an existing EventBus payload (mirroring ADR-0022's OQ-4 resolution) rather than by adding a new direct-call surface — see Decision. |

## Context

### Problem Statement

`design/gdd/tower-mastery.md` is mechanically complete and already resolves three cross-document open questions (Hero OQ6/OQ7, Grid OQ-1) in its own prose, but has no ADR covering its data model, and — critically — depends on a Tower System API that does not exist: `TowerSystem.get_component_loadout(tower_id) -> Dictionary[String, String]` (Rule 4), needed to compute `build_signature` (Formula 4) whenever a tower is placed or its components change. The naive resolution — adding this as a direct Autoload call — would require reclassifying `TowerManager` from scene-instanced to Autoload, which this session has already done four times for other systems but which here would additionally require touching an **Accepted** ADR (ADR-0008, Tower Placement Gate) that explicitly designates Tower System's mission-instance state as `write_access: tower-system-only` and "Not accessible to other systems" (per the registry's `tower_mission_state` entry) — a materially bigger and more invasive change than any of the four prior reclassifications, which only ever touched `Proposed`/not-yet-Accepted classifications in ADR-0002.

### Constraints

- Must resolve `get_component_loadout()`'s data need without touching ADR-0008's Accepted `tower_mission_state` privacy boundary, if a lower-cost alternative exists.
- `TOWER_MASTERY_PROXIMITY_RADIUS` must remain literally the same registered value as `hero_class_proximity_radius_cells` (Rule 1) — no second registry entry, no divergence.
- Per Rule 9, the qualifying-tower-set recompute must happen **only** on cell-boundary crossing (`hero_position_changed`) and tower lifecycle events — never as a per-frame Grid query. This is the GDD's own load-bearing performance claim and must be preserved architecturally, not just asserted.
- Per Rule 10, once the qualifying set is known, per-frame accrual must be O(distinct accruing `build_signature`s), never re-deriving the set itself per frame.
- The two persisted structures (`mastery_time`, `unlocked_skills`) must survive correctly across repeated Sanctuary↔Mission scene transitions within a single play session — see the newly-identified Risk below, which this ADR surfaces but cannot fully resolve alone.

### Requirements

- `build_signature` derivation (Formula 4): 4-component-ID string key, computed whenever a tower's loadout becomes known or changes.
- Two persisted `Dictionary[String, float]`/`Dictionary[String, bool]` structures (`mastery_time`, `unlocked_skills`), `restore_order = 34` (the GDD's own self-proposed 31 collided with Hero Skill Build's already-assigned slot — corrected by `save-persistence.md`'s 2026-07-17 revision; this ADR adopts the corrected value, not the GDD's original proposal — see Risks).
- One ephemeral, per-mission `Dictionary[int, String]` (`_active_signature_by_tower`), rebuilt from EventBus events, never persisted.
- One ephemeral, cell-crossing-recomputed `Dictionary[String, bool]` (`_signatures_in_range`).
- `SkillDefinitionResource` catalogue entries (Rule 7), `GameDataRegistry`-backed, content deliverable deferred per the GDD's own scope note.

## Decision

**`get_component_loadout()` is resolved by extending `tower_placed` and `tower_component_equipped`'s existing EventBus payloads to carry the tower's full 4-slot component loadout — not by adding a new Tower System query API.** This directly mirrors ADR-0022's own resolution of Constellation's near-identical OQ-4 gap (adding `constellation_eligibility_tag` to `tower_placed`/`tower_removed`/`tower_destroyed` rather than inventing a Tower System query method) — the same class of problem, the same resolution shape, now applied a second time. Concretely:

- `tower_placed` (already a `TowerPlacedEvent` Resource subclass, per `event-bus.md`'s 2026-07-17 changelog) gains four new fields: `foundation_component_id: String`, `weapon_component_id: String`, `focus_component_id: String`, `power_component_id: String` — the tower's complete loadout at placement time. This is a straightforward field addition to an already-Resource-subclass event, no new promotion needed.
- `tower_component_equipped` (currently 3 bare typed params: `tower_id: int`, `slot: String`, `component_id: String` — under the ≤4-field threshold today) must be **promoted to a Resource subclass**, `TowerComponentEquippedEvent`, carrying the same 4 loadout fields as `tower_placed` (the tower's **complete current** loadout after this equip, not just the single changed slot) alongside the existing `tower_id`/`slot`/`component_id` fields — 7 fields total, requiring the Resource-subclass promotion per `event-bus.md`'s own Core Rule 4 ("5+ fields require a Resource subclass"), the same threshold that already forced `tower_placed`'s own promotion.
- **Why the full loadout, not just the changed slot**: Tower Mastery's `build_signature` (Formula 4) is a function of all 4 slots simultaneously — receiving only the single changed slot on `tower_component_equipped` would leave Tower Mastery unable to recompute the complete signature without a separate query for the other 3 (unchanged) slots, reintroducing the exact query-API need this resolution avoids. Tower System already holds the complete loadout internally at the moment it emits this event, so including all 4 fields costs nothing extra to compute, only a slightly larger payload.

This resolution requires a `tower.md`/`event-bus.md` revision (flagged, same "ADR requests a GDD/catalog update" pattern used throughout this session — e.g. ADR-0022's `constellation_eligibility_tag` addition, ADR-0025/26's `int`-type corrections) but does **not** require Tower System to become an Autoload, and does not touch ADR-0008's Accepted privacy boundary at all.

**Proximity-detection architecture** (Rules 8–11, confirmed sound, no changes): `_active_signature_by_tower: Dictionary[int, String]` populated/updated entirely from the now-extended `tower_placed`/`tower_component_equipped` payloads (plus erasure on `tower_removed`/`tower_destroyed`) — an EventBus-only data flow, no direct Tower System call anywhere in this system. `_signatures_in_range: Dictionary[String, bool]` recomputed only on `hero_position_changed` (cell-boundary crossing) or the four tower lifecycle events, via `Grid.get_occupied_cells_in_radius()` (Criterion A, ADR-0020, already-established Grid read API) — never per physics frame. Per-frame work (Formula 1) is bounded to iterating the already-cached `_signatures_in_range`, not re-deriving it.

**Skill catalogue**: `SkillDefinitionResource`, `GameDataRegistry`-backed, following ADR-0009's convention — `skill_id`, `category`, `passive_slot_count`, `source_build_signature`, `mastery_threshold_seconds`, `effect_data` (opaque `Resource` reference, format owned by Hero Skill Build System; Tower Mastery reads only `source_build_signature`/`mastery_threshold_seconds` and never interprets `effect_data`'s contents, per Rule 7). **Field set amended 2026-07-17 by ADR-0030** — see Last Verified.

**Persistence**: `mastery_time: Dictionary[String, float]` and `unlocked_skills: Dictionary[String, bool]`, one `SaveRestorer` implementation, `restore_order = 34` — restores after Hero (30), Hero Skill Build (31), and Equipment Forge (32), consistent with `save-persistence.md`'s own dependency-layer-index scheme (`dependency_layer_index * 10 + intra_layer_index`) for the Advanced layer.

**Flagged risk, not resolved by this ADR** (see Risks): Tower Mastery is a `MissionScene` child, destroyed and recreated on every Sanctuary↔Mission scene transition. Its persisted `mastery_time`/`unlocked_skills` must survive that repeated destroy/recreate cycle correctly *within a single play session* — not just across a save/load boundary. Whether `SavePersistence`'s restore mechanism (ADR-0003) actually re-applies previously-loaded save data to a system that re-registers mid-session (rather than only restoring once, at initial game/save load) is not confirmed anywhere in this session's ADRs, including ADR-0003 itself. This is flagged here because Tower Mastery surfaced it, but it applies equally to every other scene-instanced system with persisted state (Crafting, Constellation, Tarot, Equipment Forge) — this is a project-wide open question, not unique to Tower Mastery.

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads SkillDefinitionResource[] from assets/data/skills/ (canonical shared path,
       corrected 2026-07-17 by ADR-0030 from an earlier tower_mastery_skills/ path)
       validate() called per resource at boot (ADR-0009 contract)

TowerMastery (scene-instanced, MissionScene child — nothing calls into it
              directly, and its ephemeral data has no reason to survive past
              the mission, so it needs no Autoload status)
  ├─ owns: _mastery_time: Dictionary[String, float]          # persisted
  ├─ owns: _unlocked_skills: Dictionary[String, bool]         # persisted
  ├─ owns: _active_signature_by_tower: Dictionary[int, String]  # ephemeral, EventBus-sourced only
  ├─ owns: _signatures_in_range: Dictionary[String, bool]     # ephemeral, cell-crossing recompute
  ├─ implements SaveRestorer:
  │    get_save_key() -> "tower_mastery"
  │    get_save_data() -> Dictionary (primitives only — mastery_time + unlocked_skills)
  │    restore_save_data(data) -> bool
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=34)
  ├─ reads: GameDataRegistry.get_skill_definition(skill_id) -> SkillDefinitionResource
  ├─ calls (direct, Criterion A/ADR-0020): Grid.get_occupied_cells_in_radius(), Grid.get_occupant()
  │    — only on hero_position_changed or tower lifecycle events, never per-frame
  ├─ subscribes (EventBus): hero_position_changed, mission_phase_changed, tower_placed
  │    (now carries full loadout), tower_removed, tower_destroyed, tower_component_equipped
  │    (promoted to Resource, now carries full loadout)
  └─ emits (EventBus): mastery_progress_updated, skill_unlocked
```

### Key Interfaces

```gdscript
# SkillDefinitionResource (assets/data/skills/*.tres — canonical shared path)
# Field set amended 2026-07-17 by ADR-0030 (Hero Skill Build): category and
# passive_slot_count added, output renamed effect_data — see Last Verified.
class_name SkillDefinitionResource extends Resource
@export var skill_id: StringName = &""
@export var category: String = ""              # physical|ranged|elemental|support
@export var passive_slot_count: int = 1         # 1-3
@export var source_build_signature: StringName = &""
@export var mastery_threshold_seconds: float = 45.0
@export var effect_data: Resource = null        # format owned by Hero Skill Build System, opaque here
func validate() -> Array[String]: ...

# TowerComponentEquippedEvent (NEW — promotes tower_component_equipped from
# bare typed params to a Resource subclass, per event-bus.md Core Rule 4's
# 5+-field threshold, mirroring tower_placed's own prior promotion)
class_name TowerComponentEquippedEvent extends Resource
var tower_id: int
var slot: String
var component_id: String
var foundation_component_id: String   # complete current loadout, not just the changed slot
var weapon_component_id: String
var focus_component_id: String
var power_component_id: String

# TowerMastery (scene-instanced, implements SaveRestorer per ADR-0003)
var _active_signature_by_tower: Dictionary[int, String] = {}
var _signatures_in_range: Dictionary[String, bool] = {}
var _mastery_time: Dictionary[String, float] = {}
var _unlocked_skills: Dictionary[String, bool] = {}

func _on_tower_placed(event: TowerPlacedEvent) -> void:
    var sig := "%s|%s|%s|%s" % [event.foundation_component_id, event.weapon_component_id,
                                  event.focus_component_id, event.power_component_id]
    _active_signature_by_tower[event.tower_id] = sig
    _recompute_signatures_in_range()   # tower lifecycle event, immediate recompute (Rule 11)

func _physics_process(delta: float) -> void:
    if _mission_phase != Phase.WAVE_ACTIVE and _mission_phase != Phase.INTERMISSION:
        return
    for sig in _signatures_in_range:
        _mastery_time[sig] = _mastery_time.get(sig, 0.0) + delta   # Formula 1, O(accruing signatures)
```

## Alternatives Considered

### Alternative A: `TowerSystem.get_component_loadout(tower_id)` as a direct Autoload call, reclassifying `TowerManager` as Autoload

- **Description**: Follow the same pattern as Inventory/DefenseBuilding/Menagerie/MissionSelect — make Tower System an Autoload so this read API is a valid Criterion A direct call.
- **Pros**: Matches the GDD's literal Rule 4 wording exactly ("new read API"); consistent with this session's established pattern for the same class of gap.
- **Cons**: Unlike the four prior reclassifications (all of which corrected a `Proposed`, not-yet-Accepted classification in ADR-0002), Tower System's mission-instance state privacy is established by an **Accepted** ADR (ADR-0008) with an explicit, already-shipped-in-spirit `write_access: tower-system-only` / "Not accessible to other systems" boundary in the registry. Reclassifying Tower System would require revising an Accepted ADR's core privacy guarantee, not merely correcting an oversight in a still-`Proposed` boundary table — a materially higher-cost, higher-risk change for what the event-payload-extension resolution achieves for free.
- **Rejection Reason**: ADR-0022 already demonstrated the lower-cost resolution (extend the existing event payload) for the structurally identical problem (Constellation needing per-tower data it didn't have). Reusing that resolution here avoids reopening an Accepted ADR's boundary for no corresponding benefit.

### Alternative B: Per-frame Grid query for the qualifying-tower set, abandoning cell-boundary-triggered recompute

- **Description**: Recompute `_signatures_in_range` every `_physics_process` tick directly from `Grid.get_occupied_cells_in_radius()`, rather than caching it and only recomputing on `hero_position_changed`/tower lifecycle events.
- **Pros**: Simpler mental model — no cache invalidation logic to reason about.
- **Cons**: Directly contradicts Rule 9's explicit performance rationale and event-bus.md's own flagged concern ("Tower Mastery must confirm it can handle cell-resolution granularity") — a per-frame Grid query for every one of potentially many simultaneously-tracked Tower Mastery instances, on top of Constellation's own per-event Grid queries and Pathfinding's route lookups, is exactly the kind of redundant per-frame spatial query ADR-0005's `grid_spatial_query` contract exists to bound, not multiply.
- **Rejection Reason**: The GDD's own reasoning (Rule 9) is architecturally sound and already the cheaper option — no reason to abandon it for a simpler-but-more-expensive alternative.

## Consequences

### Positive
- Resolves `get_component_loadout()`'s dependency without touching ADR-0008's Accepted privacy boundary — the lowest-cost fix available, consistent with ADR-0022's own precedent for the identical problem shape.
- Confirms the GDD's own performance-conscious architecture (cell-boundary-triggered recompute, O(accruing signatures) per-frame work) is sound and requires no redesign — only live profiling to confirm in practice (see Verification Required).
- Surfaces a previously-unflagged, project-wide risk (persisted state on scene-instanced systems across repeated scene reloads within one session) that affects four other ADRs this session, not just this one — better caught now than at implementation time across all five systems independently.

### Negative
- `tower_component_equipped`'s promotion from 3 bare params to a 7-field Resource subclass is a breaking payload change for any other subscriber of that event (Constellation, Mission HUD, per `event-bus.md`'s existing Key Subscribers list) — those subscribers' code must be updated to read the new Resource shape, not the old positional params, even though their own logic doesn't need the 4 new fields.
- Tower Mastery's `build_signature` computation now depends on two separate event shapes (`tower_placed`'s and `tower_component_equipped`'s) staying in lockstep on their loadout-field naming — a future edit to one that doesn't mirror the other would silently break signature derivation for one code path but not the other.

### Risks
- **Risk** (discovered during `/create-epics` research, fixed in this revision): this ADR originally adopted `tower-mastery.md`'s own self-proposed `restore_order = 31`, but `save-persistence.md`'s authoritative table (corrected 2026-07-17, same day, in a pass this ADR's authoring did not cross-check) assigns Tower Mastery **34** — the GDD's self-proposed 31 collided with Hero Skill Build's already-assigned slot. This ADR's original `restore_order = 31` would have silently reintroduced that exact collision at the ADR level, even though the GDD-level collision had already been caught and fixed.
  - **Mitigation**: Fixed — `restore_order` corrected to 34 throughout this ADR. **Process note**: this class of error (an ADR trusting a GDD's self-proposed cross-system ordinal without checking the owning infrastructure doc's authoritative table) is a real gap in this session's own ADR-authoring discipline — `save-persistence.md` is the single source of truth for `restore_order` assignments, and any ADR specifying one should grep that table directly, not just cite the consuming GDD's own proposal.
- **Risk**: `tower_component_equipped`'s payload growth (3 → 7 fields) could be seen as scope creep by whichever GDD/ADR owns `tower.md`'s event contracts, if not coordinated.
  - **Mitigation**: Flagged explicitly here as a requested `tower.md`/`event-bus.md` revision, following the same "ADR proposes, GDD owner confirms" pattern already used repeatedly this session (e.g. ADR-0022's `constellation_eligibility_tag`, ADR-0021's Inventory Rule 5 exemption).
- **Risk** (newly identified during this ADR's authoring, not previously flagged in any prior ADR this session): scene-instanced systems with persisted state (Tower Mastery here, plus Crafting/Constellation/Tarot/Equipment Forge from earlier ADRs) are destroyed and recreated on every Sanctuary↔Mission scene transition. Whether `SavePersistence` (ADR-0003) correctly re-applies already-loaded save data to a system that re-registers mid-session — as opposed to only restoring once, at initial game/save load — is unconfirmed. If it does not, any progress accumulated in such a system since the last full save/load (even if auto-saved to disk at a checkpoint like `mission_launched`) would silently reset to defaults on the very next scene reload within the same session.
  - **Mitigation**: This is a project-wide question, not resolvable within Tower Mastery's own ADR. Flagged here for a dedicated verification pass — either (a) confirm `SavePersistence`'s `_restore_all_systems()` (or an equivalent) re-fires against the currently-cached in-memory master save Dictionary whenever a new `SaveRestorer` registers after the initial load, not only at boot, or (b) if it does not, this becomes a blocking finding requiring either an ADR-0003 revision or reclassifying every affected scene-instanced-with-persisted-state system as Autoload. Recommend running `/architecture-review`'s Phase 4/5 specifically checking this before any of the affected systems (Tower Mastery, Crafting, Constellation, Tarot, Equipment Forge) begin implementation.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| tower-mastery.md | Rule 4: `get_component_loadout()` new Tower System API | Resolved via event-payload extension instead — `tower_placed`/`tower_component_equipped` now carry the full 4-slot loadout; no new Tower System query API, no Autoload reclassification |
| tower-mastery.md | Rules 8–11: cell-boundary-triggered recompute, not per-frame | Confirmed sound; `_signatures_in_range` caching architecture specified in Key Interfaces |
| tower-mastery.md | Rule 7: skill catalogue data model | `SkillDefinitionResource`, `GameDataRegistry`-backed, following ADR-0009's convention |
| tower-mastery.md | Dependencies: `restore_order = 34` | Corrected from the GDD's self-proposed 31 (collided with Hero Skill Build) to `save-persistence.md`'s authoritative value |
| tower-mastery.md | Formula 4: `build_signature` derivation | Computed by Tower Mastery itself from the now-event-carried loadout fields, never by a Tower System call |

## Performance Implications
- **CPU**: Per-frame work bounded to O(distinct currently-accruing `build_signature`s), not O(tower count) or O(monster count) — confirmed architecturally sound, but **not yet profiled against a real build** (see Verification Required). This is the one open item preventing this ADR's Engine Compatibility risk from being downgraded from MEDIUM.
- **Memory**: `_active_signature_by_tower`/`_signatures_in_range` bounded by live tower count (negligible); `_mastery_time`/`_unlocked_skills` bounded by total distinct `build_signature`s ever encountered across the playthrough (small, since component catalogues are content-authoring-scale, not combinatorially large in practice).
- **Load Time**: `SkillDefinitionResource` definitions load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Tower Mastery has no existing implementation to migrate from. This is a greenfield decision, with one flagged open verification item (see Risks) before it should be considered fully de-risked.

## Validation Criteria
- **Live profiling test** (per Verification Required): measure `_physics_process` cost for the accrual loop with 5+ simultaneously-accruing `build_signature`s during a 100-monster `WAVE_ACTIVE` wave — confirms or refutes the MEDIUM engine-risk classification.
- Unit test confirms `_signatures_in_range` is recomputed only on `hero_position_changed` or the 4 tower lifecycle events, never on an arbitrary `_physics_process` tick (mirrors AC-style testing already established for Constellation's `get_all_occupied_cells()` call-counter assertion, ADR-0022).
- Unit test confirms `build_signature` derived from `tower_component_equipped`'s new 4-field loadout matches the signature derived from the same tower's original `tower_placed` payload when only the changed slot differs.
- Integration test confirms Tower Mastery's `mastery_time`/`unlocked_skills` correctly survive a Sanctuary→Mission→Sanctuary→Mission round trip within a single continuous play session (not just a save/load) — directly targets the newly-flagged scene-reload persistence risk.

## Related Decisions
- ADR-0005 (Grid System Data Model) — source of `get_occupied_cells_in_radius()`, the only Grid API this ADR's hot path calls
- ADR-0009 (Resource Data Model) — `GameDataRegistry` + `validate()` pattern `SkillDefinitionResource` extends
- ADR-0022 (Constellation pattern-detection data structure) — direct precedent for resolving a per-tower data gap via event-payload extension rather than a new query API; this ADR's resolution mirrors it exactly
- ADR-0020 (Direct-Autoload-call exception pattern) — governs why Tower Mastery's Grid calls are direct, not EventBus; also the reason Alternative A was considered and rejected
- ADR-0008 (Tower Placement Gate) — the Accepted ADR whose privacy boundary this ADR's resolution deliberately avoids reopening
- ADR-0010 (Hero-Tower Synced Class) — sibling accumulator sharing the same proximity radius constant but never merged with this system's own accumulator (Rule 2)
- ADR-0030 (Hero Skill Build Ultimate lookup-table architecture) — amended this ADR's `SkillDefinitionResource` in place to unify both systems' field needs into one shared Resource; see Last Verified
- `design/gdd/tower-mastery.md` — source GDD for all requirements this ADR addresses
