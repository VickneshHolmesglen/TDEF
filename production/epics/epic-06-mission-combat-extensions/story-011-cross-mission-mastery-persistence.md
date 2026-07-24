# Story 011: Cross-Mission Mastery Persistence

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tower-mastery.md`
**Requirement**: `TR-towermast-003`

**ADR Governing Implementation**: ADR-0029 (Tower Mastery Proximity-Detection Strategy)
**ADR Decision Summary**: `mastery_time: Dictionary[String, float]` and `unlocked_skills: Dictionary[String, bool]` are the two persisted, cross-mission structures, one `SaveRestorer` implementation, `restore_order = 34` — corrected from the GDD's self-proposed 31 (which collided with Hero Skill Build's already-assigned 31) per `save-persistence.md`'s authoritative table.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: `Dictionary[String, float]`/`Dictionary[String, bool]` are primitive-only, satisfying ADR-0003's save-data constraint directly.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0003/ADR-0029 directly.
- Forbidden: Never clear `mastery_time`/`unlocked_skills` on anything other than a brand-new-game adventure reset — mission end (any exit: `MISSION_COMPLETE`, `DEFEAT`, abandon) must never reset either structure.
- Guardrail: **Project-wide SavePersistence gap** — Tower Mastery is a `MissionScene` child (destroyed/recreated every mission). Whether `SavePersistence` correctly re-applies already-loaded save data to a system that re-registers mid-session is unconfirmed project-wide (ADR-0029 Risks). Do not mark this story's persistence behavior fully verified until that gap is resolved — see `EPIC.md` Known Blockers.

---

## Acceptance Criteria

*From GDD `design/gdd/tower-mastery.md`, scoped to this story:*

- [x] AC-10 — Persisted `mastery_time` reads correctly immediately after `restore_save_data()`, with no dependency on a live tower existing yet
- [x] AC-13 — Pause-not-reset: hero leaving range leaves `mastery_time` unchanged, state moves to `TRACKED_INACTIVE`
- [x] AC-14 — Sole live tower destroyed while hero in range: `mastery_time` pauses, does not reset, same-frame state update
- [x] AC-15 — Accrual resumes automatically from the paused value when a matching-signature tower is later placed in range
- [x] AC-16 — `DEFEAT` mission outcome does not reset in-progress `mastery_time`
- [x] AC-17 — `DEFEAT` mission outcome does not revoke a permanent `unlocked_skills` entry
- [x] AC-18 — Orphaned `unlocked_skills` entry (unknown `skill_id` post-launch) is retained, marked `UNKNOWN`, excluded from UI, logged, load never blocks

---

## Implementation Notes

*Derived from ADR-0029 Implementation Guidelines:*

```gdscript
# TowerMastery implements SaveRestorer per ADR-0003
func get_save_key() -> String: return "tower_mastery"
func get_save_data() -> Dictionary: return {"mastery_time": _mastery_time, "unlocked_skills": _unlocked_skills}
func restore_save_data(data: Dictionary) -> bool: ...
func reset_to_defaults() -> void:
    _mastery_time.clear()
    _unlocked_skills.clear()

# Register: SavePersistence.register(self, restore_order=34)
```

- `restore_order = 34` — restores after Hero (30), Hero Skill Build (31), Equipment Forge (32), per `save-persistence.md`'s dependency-layer-index scheme. This is the corrected value; do not use the GDD's original self-proposed 31.
- **Pause, not reset** (Edge Cases): if a tower is destroyed mid-accrual and no other tower shares its `build_signature`, accrual pauses — `mastery_time[build_signature]` retains its value and resumes automatically the moment a matching-signature tower is placed within radius (same mission or a future one).
- **Orphaned skill on load**: if a save references a `skill_id` no longer in the current catalogue, retain the entry (don't discard), mark it `UNKNOWN` internally, exclude it from the Hero Skill Build UI's equippable list while unknown, log a warning, and never block the load — mirrors `hero.md`'s precedent for an unknown `class_id`.
- Mission outcome (`MISSION_COMPLETE`, `DEFEAT`, manual abandon) has no bearing on whether progress persists — only a brand-new-game adventure reset clears it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: the accrual/unlock logic that produces the values this story persists
- Resolving the project-wide SavePersistence mid-session-restore gap itself (tracked as a cross-epic blocker, not owned by this story)

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-10**: Restore works standalone, no live tower dependency
  - Given: `mastery_time["S1"] = 40.0` persisted from a prior mission
  - When: a new mission loads and `restore_save_data()` runs before any tower is placed
  - Then: `mastery_time["S1"]` reads `40.0` immediately after restore

- **AC-13**: Pause on out-of-range, not reset
  - Given: `mastery_time["S1"] = 22.0`, hero standing within range of the only live `S1` tower
  - When: hero moves out of the 3-cell radius (same mission, still `WAVE_ACTIVE`)
  - Then: `mastery_time["S1"]` remains exactly `22.0`, state moves `TRACKED_ACCRUING` → `TRACKED_INACTIVE`

- **AC-14**: Pause on tower destruction, same-frame
  - Given: `mastery_time["S1"] = 22.0`, sole live `S1` tower destroyed while hero in range
  - When: the destruction event is processed
  - Then: `mastery_time["S1"]` remains exactly `22.0`, `_signatures_in_range["S1"]` becomes `false` the same frame (no waiting for next `hero_position_changed`)

- **AC-15**: Resume from paused value
  - Given: the AC-14 state
  - When: any subsequent tower with `build_signature = "S1"` is placed within 3 cells of the hero (this mission or a future one)
  - Then: accrual resumes automatically from `22.0`, no manual re-trigger required

- **AC-16**: Defeat does not reset partial progress
  - Given: `mastery_time["S1"] = 30.0` (below 45s threshold) accrued during a mission ending in `DEFEAT`
  - When: the next mission/Sanctuary session loads and `restore_save_data()` runs
  - Then: `mastery_time["S1"]` still reads `30.0`

- **AC-17**: Defeat does not revoke permanent unlock
  - Given: `unlocked_skills["skill_x"] = true` from a prior mission
  - When: the current mission subsequently ends in `DEFEAT`
  - Then: `unlocked_skills["skill_x"]` still reads `true` after the defeat and after the next mission's restore

- **AC-18**: Orphaned skill handling
  - Given: save's `unlocked_skills` contains `"legacy_skill_id": true`, current catalogue no longer defines it
  - When: `restore_save_data()` processes this entry
  - Then: entry retained (not discarded), marked `UNKNOWN` internally, excluded from Hero Skill Build UI while unknown, warning logged, load completes with no blocking error

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/tower-mastery/cross-mission-mastery-persistence_test.gd` — 13 tests, including a full save/load round-trip and `RESTORE_ORDER == 34`. All passing.

**Status**: [x] Created and passing (2026-07-19). Full project regression re-run: 1079/1080 (the sole failure is the same pre-existing, unrelated Menagerie `CreatureInstance.CreatureState` enum-value mismatch, `TD-menag-006` — untouched by this story).

---

## Dependencies

- Depends on: Story 010 (DONE) — persists the values that story's logic produces
- Unlocks: Hero Skill Build System's consumption of `skill_unlocked` (Epic 08)

**Unblocked**: ADR-0029 accepted 2026-07-18 (Sprint 6, S6-02). The project-wide SavePersistence mid-session-restore gap this story was also flagged against is resolved (ADR-0003's 2026-07-18 revision).

**Implemented (2026-07-19, Sprint 7 S7-08)**: `tower_mastery.gd` now implements the full `SaveRestorer` interface (`get_save_key()`/`get_save_data()`/`restore_save_data()`/`reset_to_defaults()`), registers via `GSavePersistence.register(self, RESTORE_ORDER)` in `_ready()` (`RESTORE_ORDER = 34`, the corrected collision-free value) and unregisters in `_exit_tree()`. `get_save_data()` persists `mastery_time`/`unlocked_skills` as primitive-only Dictionaries (ADR-0003). `restore_save_data()` validates shape before mutating anything (returns `false` on malformed data, matching every other `SaveRestorer` in this project). Pause-not-reset (AC-13/14/15) required no special-casing: `mastery_time`/`_active_signature_by_tower` were already never mutated by the hero leaving range or a tower vanishing (Stories 007/009) — only `_signatures_in_range` changes, so accrual simply stops and resumes automatically once a matching-signature tower re-enters range. AC-16/17 (DEFEAT doesn't reset/revoke) fall out for the same reason: nothing in this file's mission-outcome handling ever calls `reset_to_defaults()` — only `SavePersistence` does, on a genuinely new adventure. **AC-18 (orphaned skill_id)**: added `_has_skill_catalogue`/`_known_skill_ids` as a DI seam (mirrors `_grid`'s pattern) — defaults to `false`/`{}` in production since no real skill catalogue exists yet (Rule 7/ADR-0030, unchanged), so nothing is ever false-flagged as unknown today; when enabled (by a future real catalogue, or directly in tests), any restored `skill_id` absent from `_known_skill_ids` is retained (never discarded), tracked in a new `_unknown_skills` dict, logged via `push_warning`, and exposed via a new `is_skill_unknown(skill_id)` query for the (not-yet-built) Hero Skill Build UI to consult. Live-verified via gdUnit4: 13/13 new tests passing; full regression 1079/1080 (same pre-existing unrelated `TD-menag-006` failure).
