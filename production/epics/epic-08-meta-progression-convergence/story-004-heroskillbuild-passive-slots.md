# Story 004: Passive Slots as Internal State

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/hero-skill-build.md`
**Requirement**: `TR-heroskill-001`

**ADR Governing Implementation**: ADR-0030 (Hero Skill Build Ultimate Lookup-Table Architecture)
**ADR Decision Summary**: Passive-slot changes are internal to Hero Skill Build — no new EventBus event is introduced (resolving `event-bus.md`'s Open Note 4). A synchronous read API, `HeroSkillBuild.get_passive_loadout(skill_id) -> Array[String]`, is pulled at UI-open time rather than pushed.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: No new engine subsystem — mirrors the pull-not-push precedent Save & Persistence's own EC-10 establishes for Sanctuary-only, non-live-combat state.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0030 directly.
- Forbidden: Never emit a new EventBus event for a passive-slot-only change (e.g. no `skill_passive_equipped`) — Hero Skill Build updates its own internal data structure directly.
- Guardrail: Hero Skill Build pre-folds all equipped passive modifiers into the skill's effective `effect_data` at the moment the skill activates — Damage & Status never needs per-passive-slot granularity.

---

## Acceptance Criteria

*From GDD `design/gdd/hero-skill-build.md`, scoped to this story:*

- [x] AC-13 — no EventBus event fires for a passive-slot-only change; active-slot changes still emit `active_skill_equipped`/`ultimate_skill_changed` as normal
- [x] AC-14 — passive loadout is queryable via `HeroSkillBuild.get_passive_loadout(skill_id) -> Array[String]`, called synchronously at UI-open time, never delivered via subscription/event

---

## Implementation Notes

*Derived from ADR-0030 Implementation Guidelines:*

- When a skill-modifier item is equipped into or removed from one of a skill's `passive_slot_count` passive slots, Hero Skill Build updates its own internal `_passive_slots: Dictionary[String, Array]` (`skill_id -> Array[String]` of installed item IDs) directly — no signal emission.
- Rationale: passive slot changes only happen at Sanctuary, no live-combat consumer needs a push notification. The one system that would care (Damage & Status, resolving `hero_skill_activated`) doesn't need per-passive-slot granularity — Hero Skill Build pre-folds all equipped passive modifiers into the skill's effective `effect_data` at activation time.
- `HeroSkillBuild.get_passive_loadout(skill_id) -> Array[String]` is a synchronous read API, pulled at UI-open time by the Sanctuary skill-build screen — same pull-not-push precedent Save & Persistence's own EC-10 establishes.
- Skill-modifier items are recommended to file under Inventory's existing Equipment tab using `item_type = "skill_modifier"` — this is a flagged cross-GDD dependency, covered separately in Story 007 (not yet resolved on Inventory's side).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: active-slot assignment mechanics (this story covers only the passive sub-slot layer)
- Story 007: the `skill_modifier` item_type Inventory dependency itself (this story assumes the interface, doesn't resolve the gap)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-13**: No event for passive-only change; active-slot changes still emit
  - Given: `CONFIGURABLE` state with an active-slot skill already equipped
  - When: a skill-modifier item is equipped/removed from one of that skill's passive slots
  - Then: no EventBus event fires, internal passive-loadout data structure updates directly
  - Edge cases: given the same starting state, when an active slot is instead reassigned, then `active_skill_equipped`/`ultimate_skill_changed` fire as normal — proving the "no event" resolution is scoped strictly to passive-slot changes

- **AC-14**: Synchronous pull, not push
  - Given: the Sanctuary skill-build screen opens
  - When: it needs to display a skill's current passive loadout
  - Then: it calls `HeroSkillBuild.get_passive_loadout(skill_id) -> Array[String]` synchronously at open time; no subscription or event delivers this data

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/hero-skill-build/passive-slots-internal-state_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/hero-skill-build/passive-slots-internal-state_test.gd` (9 tests, passing)

---

## Dependencies

- Depends on: Story 001 (slot/catalogue data model)
- Unlocks: None further within this epic

**Unblocked**: ADR-0030 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 2/2 passing (9 unit tests, all passing).
**Deviations**: None.
**Test Evidence**: Logic — `tests/unit/hero-skill-build/passive-slots-internal-state_test.gd`.
**Code Review**: Complete (batch review across Stories 001-007) — APPROVED WITH SUGGESTIONS, required fixes applied.
