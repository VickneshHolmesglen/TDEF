# Story 005: Persistence Boundary & Cross-Mission State

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/hero-skill-build.md`
**Requirement**: `TR-heroskill-002`

**ADR Governing Implementation**: ADR-0030 (Hero Skill Build Ultimate Lookup-Table Architecture)
**ADR Decision Summary**: `_equippable_skills` (a mirror of Tower Mastery's unlock state, populated exclusively via the `skill_unlocked` subscription), `_active_slots`, and `_passive_slots` are persisted under one `SaveRestorer`, `restore_order = 31` — corrected from the GDD's self-proposed 32, which collided with Equipment Forge's already-assigned 32. The resolved Ultimate itself is never persisted as a stored value — always recomputed from restored slot assignments.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: `restore_order = 31` resolves `save-persistence.md`'s own flagged open ordering question against Tower Mastery (34) — no restore-time dependency actually exists between the two, since Hero Skill Build's `_equippable_skills` mirror is built incrementally over the playthrough via the `skill_unlocked` subscription, never re-derived live from Tower Mastery's restored dictionaries.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0003/ADR-0030 directly.
- Forbidden: Never re-derive or duplicate Tower Mastery's mastery-tracking logic — `_equippable_skills` only remembers which `skill_id`s are currently equippable as a result of having received `skill_unlocked` events.
- Guardrail: The resolved Ultimate is never restored as a raw stored value — it is always recomputed from restored slot assignments, avoiding a class of bug where a content patch changes the derivation and a stale stored Ultimate silently drifts.

---

## Acceptance Criteria

*From GDD `design/gdd/hero-skill-build.md`, scoped to this story:*

- [x] AC-15 — slot assignments persist across missions within a playthrough, reset only on a new save (not on any mission-exit path, including `DEFEAT`)
- [x] AC-16 — only a brand-new save resets the equippable-skill library and all slot assignments together, in lockstep with Tower Mastery's own reset
- [x] AC-17 — `skill_unlocked` subscription remains live during `LOCKED`, adds to the library immediately, but does not trigger an Ultimate recompute or constitute a write
- [x] AC-26 — the full state machine (`DORMANT → CONFIGURABLE → LOCKED → CONFIGURABLE`) transitions exactly as specified, slot writes accepted only during `CONFIGURABLE`, Ultimate remains live-readable throughout `LOCKED`

---

## Implementation Notes

*Derived from ADR-0030 Implementation Guidelines:*

```gdscript
# HeroSkillBuild (Autoload #13, implements SaveRestorer per ADR-0003)
var _equippable_skills: Dictionary[String, bool] = {}      # persisted, mirror only
var _active_slots: Array[String] = []                       # persisted, size 4
var _passive_slots: Dictionary[String, Array] = {}           # persisted, skill_id -> item_ids

func get_save_key() -> String: return "hero_skill_build"
func get_save_data() -> Dictionary: ...   # 3 structures above, primitives only
func restore_save_data(data: Dictionary) -> bool: ...
func reset_to_defaults() -> void: ...
# SavePersistence.register(self, restore_order=31)
```

- **What resets only on a brand-new game**: Tower Mastery's learned-skill library and Hero Skill Build's active/Ultimate/passive slot assignments — both describe the same "new game" reset boundary in their own words (no actual conflict between `hero.md` Rule 11's "per-adventure" language and `tower-mastery.md` Rule 5's "new game" language).
- **What is freely re-selectable within a playthrough**: which unlocked skills occupy A/B/C/D, which skill-modifier items occupy passive slots, the resulting Ultimate (recomputed automatically). None of this affects Tower Mastery's `unlocked_skills`/`mastery_time`.
- Hero Skill Build subscribes to `skill_unlocked(skill_id, source_tower_id)` and adds `skill_id` to `_equippable_skills` the instant it's received — this is the sole mechanism by which a skill becomes assignable. This subscription is active in **every** state, including `LOCKED` — but adding to the library is not an active/passive-slot write and does not trigger an Ultimate recompute.
- State table: `DORMANT` (no save loaded) → `CONFIGURABLE` (`SANCTUARY`) → `LOCKED` (SCOUT/WAVE_ACTIVE/INTERMISSION/OUTCOME/DEFEAT). Only slot writes are load-bearing for gameplay — while `LOCKED`, the system is fully read-only but still recomputes/holds the currently-resolved Ultimate for Hero to read.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the slot/catalogue schema this story persists
- Story 006: orphaned-data edge cases on restore (this story covers the happy-path persistence boundary)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-15**: Mission-exit persistence
  - Given: an active playthrough with A/B/C/D bound and passive slots filled
  - When: a mission ends via `MISSION_COMPLETE`, `DEFEAT`, or manual abandon, player returns to `SANCTUARY`
  - Then: all slot bindings and the resolved Ultimate are unchanged from pre-mission values — no reset on any mission-exit path

- **AC-16**: New-save reset in lockstep
  - Given: a brand-new game/playthrough is started
  - When: the new save initializes
  - Then: the equippable-skill library, all slot bindings, and the resolved Ultimate reset to empty/`EMPTY` in the same operation as Tower Mastery's `unlocked_skills`/`mastery_time` reset

- **AC-17**: Live subscription during LOCKED, no write-lock violation
  - Given: the system is `LOCKED` (mid-mission)
  - When: Tower Mastery emits `skill_unlocked(skill_id, source_tower_id)`
  - Then: `skill_id` is added to the equippable library immediately (available the instant `CONFIGURABLE` re-enters), but this addition does not trigger an Ultimate recompute and does not constitute a write (AC-3 from Story 001 is not violated)

- **AC-26**: Full state machine transition sequence
  - Given: the state table (DORMANT, CONFIGURABLE, LOCKED)
  - When: `sanctuary_state_restored` fires from DORMANT, then `mission_launched` fires from CONFIGURABLE, then a mission ends and control returns to SANCTUARY
  - Then: transitions DORMANT → CONFIGURABLE → LOCKED → CONFIGURABLE exactly as specified, slot writes accepted only during CONFIGURABLE, Ultimate remains live-readable (not writable) throughout LOCKED

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/hero-skill-build/persistence-boundary-cross-mission_test.gd` — must exist and pass, including a save/load round-trip at `restore_order=31`

**Status**: [x] Created — `tests/integration/hero-skill-build/persistence-boundary-cross-mission_test.gd` (8 tests, passing, including a save/load round-trip at `restore_order=31`)

---

## Dependencies

- Depends on: Story 001 (slot/catalogue data model), Story 003 (Ultimate recompute this story's persistence must not stale-store)
- Unlocks: Story 006

**Unblocked**: ADR-0030 accepted 2026-07-18 (Sprint 6, S6-04). Hero Skill Build is Autoload — **unaffected** by the project-wide SavePersistence mid-session-restore gap (also separately resolved, ADR-0003's 2026-07-18 revision).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 4/4 passing (8 integration tests, all passing).
**Deviations**: None.
**Test Evidence**: Integration — `tests/integration/hero-skill-build/persistence-boundary-cross-mission_test.gd`.
**Code Review**: Complete (batch review across Stories 001-007) — APPROVED WITH SUGGESTIONS, required fixes applied.
