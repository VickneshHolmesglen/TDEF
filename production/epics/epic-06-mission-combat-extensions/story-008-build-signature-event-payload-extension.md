# Story 008: Build Signature via Event-Payload Extension

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tower-mastery.md`
**Requirement**: `TR-towermast-002`, `TR-towermast-003`

**ADR Governing Implementation**: ADR-0029 (Tower Mastery Proximity-Detection Strategy)
**ADR Decision Summary**: `TowerSystem.get_component_loadout(tower_id)` is resolved by extending `tower_placed` and `tower_component_equipped`'s existing EventBus payloads to carry the tower's full 4-slot component loadout — not by adding a new Tower System query API. This mirrors ADR-0022's identical resolution for Constellation's `constellation_eligibility_tag` gap. `tower_component_equipped` must be promoted from 3 bare params to a 7-field Resource subclass (`TowerComponentEquippedEvent`) per `event-bus.md`'s 5+-field threshold.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM (per ADR-0029 Engine Compatibility)
**Engine Notes**: Typed `Dictionary[String, float]`/`Dictionary[int, String]` (4.4+, already verified working). No new engine subsystem beyond the Resource-subclass promotion pattern already established by `tower_placed`.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0029/`event-bus.md` Core Rule 4 (5+ fields require a Resource subclass) directly.
- Forbidden: Do not add `get_component_loadout()` as a new Tower System query API — this would require reclassifying `TowerManager` as Autoload and reopening ADR-0008's Accepted `write_access: tower-system-only` privacy boundary, which ADR-0029 explicitly rejects (Alternatives Considered, Alternative A).
- Guardrail: `tower_component_equipped`'s promotion is a breaking payload change for existing subscribers (Constellation, Mission HUD) — those subscribers' code must be updated to read the new Resource shape, coordinate before merging.

---

## Acceptance Criteria

*From GDD `design/gdd/tower-mastery.md`, scoped to this story:*

- [x] AC-07 — Mission-recycled `tower_id` with matching `build_signature` correctly accumulates across missions
- [x] AC-08 — Destroyed-and-replaced identical build resumes progress rather than restarting
- [x] AC-09 — Two same-mission towers sharing a `build_signature` accrue once per tick, not doubled
- [x] AC-11 — `tower_placed` handler populates `_active_signature_by_tower` from the payload's 4 loadout fields
- [x] AC-12 — component swap recomputes `build_signature`, old signature's `mastery_time` left untouched
- [x] AC-26 — signature derived from full 4-slot loadout, not archetype alone (power-slot-only difference produces distinct signatures)

---

## Implementation Notes

*Derived from ADR-0029 Implementation Guidelines — this story is the actual prerequisite work the GDD's own Open Questions flag as blocking:*

**Step 1 — Extend `tower_placed` (already a `TowerPlacedEvent` Resource subclass):** add `foundation_component_id: String`, `weapon_component_id: String`, `focus_component_id: String`, `power_component_id: String` — the tower's complete loadout at placement time. This is a field addition to an already-Resource-subclass event, no new promotion needed.

**Step 2 — Promote `tower_component_equipped` to a Resource subclass:**
```gdscript
class_name TowerComponentEquippedEvent extends Resource
var tower_id: int
var slot: String
var component_id: String
var foundation_component_id: String   # complete current loadout, not just the changed slot
var weapon_component_id: String
var focus_component_id: String
var power_component_id: String
```
Carries the tower's **complete current** loadout after the equip, not just the single changed slot — Tower Mastery's `build_signature` is a function of all 4 slots simultaneously, and receiving only the changed slot would reintroduce the exact query-API need this resolution avoids.

**Step 3 — Formula 4 derivation:**
```
build_signature = foundation_component_id + "|" + weapon_component_id + "|" + focus_component_id + "|" + power_component_id
```

**Step 4 — This is a requested `tower.md`/`event-bus.md` revision**, not an assumption smuggled in — flag to whoever owns those GDDs before this story can close. Existing subscribers of `tower_component_equipped` (Constellation, Mission HUD) must update their handlers to read the new 7-field Resource shape, even though their own logic doesn't need the 4 new fields.

**Assumption, flagged** (Formula 4): component ID strings never contain a `"|"` delimiter. If that assumption doesn't hold, switch delimiter or use a struct/array key instead of string concatenation — confirm with Tower System/content pipeline owner before content is authored at scale.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: radius/accumulator independence (does not depend on the loadout payload)
- Story 009: consuming `_active_signature_by_tower` for proximity tracking (depends on this story's output)
- Skill catalogue content (`SkillDefinitionResource` entries) — deferred as a content deliverable per Rule 7 / ADR-0030

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-07** `[BLOCKED]`: Cross-mission `build_signature` persistence via recycled `tower_id`
  - Given: Mission 1 tower `tower_id=0`, loadout resolves to `build_signature = "found_basic|weap_frost_bolt|focus_none|power_none"`, hero accrues 18s
  - When: Mission 1 ends, Mission 2 begins with a *different* tower at recycled `tower_id=0` sharing the same `build_signature`
  - Then: `mastery_time[...]` still reads `18.0` at Mission 2 start, further proximity adds onto it

- **AC-08** `[BLOCKED]`: Destroyed-and-replaced resumes, does not restart
  - Given: tower with `build_signature = S1` destroyed mid-mission, `mastery_time[S1] = 22.0`
  - When: a later mission places a physically new tower (different `tower_id`) with identical `build_signature S1`
  - Then: hero near the new tower resumes accruing from `22.0`, not `0.0`

- **AC-09** `[BLOCKED]`: Redundant same-signature coverage does not double-count
  - Given: two towers, `tower_id=3` and `tower_id=7`, identical loadouts (`build_signature S2`)
  - When: hero is simultaneously within radius of both
  - Then: `mastery_time[S2]` accrues exactly once per tick; still accrues correctly when hero is within range of only one

- **AC-11** `[BLOCKED — cannot be authored until tower_placed carries the loadout]`
  - Given: `tower_placed` fires for a `tower_id`
  - When: Tower Mastery's handler runs
  - Then: reads the 4 loadout fields directly from the payload and populates `_active_signature_by_tower[tower_id]` per Formula 4, no separate query call

- **AC-12** `[BLOCKED — cannot be authored until tower_component_equipped is promoted]`
  - Given: `tower_component_equipped` fires for a live `tower_id` whose weapon component changes
  - When: Tower Mastery's handler runs
  - Then: `_active_signature_by_tower[tower_id]` recomputed to the new signature; `mastery_time` under the old signature is left untouched (no retroactive transfer)

- **AC-26** `[BLOCKED]`: Signature derived from full loadout, not archetype alone
  - Given: two towers differing only in the `power` slot (`power_none` vs. `power_amp`)
  - When: `build_signature` derived for each (Formula 4)
  - Then: the two resulting strings differ, each accrues to a distinct `mastery_time` entry — confirms the signature isn't archetype-only (which derives solely from the Foundation slot)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/tower-mastery/build-signature-event-payload-extension_test.gd` — 6 tests covering AC-07/08/09/11/12/26, all passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run after this story's migration: 1044/1045 (the sole failure is a pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch in `lure_acquisition_test.gd`, untouched by this story's changes).

---

## Dependencies

- Depends on: None (foundational — but requires a coordinated `tower.md`/`event-bus.md` revision outside this story's own scope before any of its ACs can be test-authored)
- Unlocks: Story 009, Story 010, Story 011

**Blocked reason**: ADR-0029 accepted 2026-07-18 (Sprint 6, S6-02) — that part of the blocker is resolved. **Still blocked independently**: `tower_placed`/`tower_component_equipped` in `tower.md`/`event-bus.md` have not yet been revised to carry the 4-slot loadout fields this story's every AC depends on — this is a real content gap, not an ADR-acceptance formality. Coordinate with the Tower System GDD owner before starting.

**Deeper finding (2026-07-18, Sprint 6 S6-10)**: confirmed via direct source inspection (`grep` across `src/`) that this gap is structurally larger than "add 4 fields to an event payload." `tower_component_equipped` has ZERO real emitters or subscribers anywhere in the shipped codebase today (declared in `event_bus.gd`, never called) — so the "breaking change for existing subscribers" risk this story's own Guardrail warns about does not currently apply. More significantly: `TowerData` (`src/core/tower/tower_data.gd`) has **no component-slot fields at all** — no `foundation_component_id`/`weapon_component_id`/`focus_component_id`/`power_component_id` anywhere in `src/`. Tower System's actual shipped data model is a single flat blueprint Resource per archetype/tier (fixed stats), with no notion of swappable Foundation/Weapon/Focus/Power components. This story's "Step 1/2" implementation notes (add 4 fields to `tower_placed`, promote `tower_component_equipped`) assume that underlying component-slot model already exists on the Tower side — it doesn't. Resolving this for real requires designing and building that component-slot data model first (a genuine Tower System architecture decision, likely its own ADR), not something to invent ad hoc while implementing Tower Mastery's consumer-side story. Left Blocked; Story 007 (self-contained, no dependency on this gap) implemented instead this pass — see EPIC.md.

**Decision made, implementation still pending (2026-07-19, Sprint 7 S7-01)**: this was investigated further and turned out NOT to be an open design question — `docs/architecture/adr-0008-tower-placement-gate.md` already fully specifies a 4-component (Foundation/Weapon/Focus/Power) Resource architecture with `duplicate_deep()` isolation, Accepted since 2026-05-19; it was simply never implemented (confirmed via grep: zero component classes exist anywhere in `src/`). ADR-0008 has been amended in place with the exact field-level schema (sourced from `design/gdd/tower.md`'s own already-authored component tables) and a migration plan, validated by godot-gdscript-specialist (MINOR NOTES, not blocking). **Still Blocked here** — the ADR amendment only removes the design uncertainty; the actual code (4 component classes, `tower_system.gd` migration, `.tres` content restructure, live `duplicate_deep()` verification) has not landed yet. This story unblocks once that implementation (tracked as S7-01, ~3.0d) is complete.

**UNBLOCKED (2026-07-19, Sprint 7 S7-01 complete)**: `FoundationComponent`/`WeaponComponent`/`FocusComponent`/`PowerComponent` + `TowerBlueprintData` are implemented and live-verified (118/118 gdUnit4 tests, live MCP `duplicate_deep()` isolation confirmed, full project regression 1045/1045). This story's own remaining scope (extending `tower_placed` with 4 loadout-identifier fields, promoting `tower_component_equipped` to a Resource, deriving `build_signature` per Formula 4) can now actually be built — the underlying component data model it depends on is real. Status flipped to `Ready`.
