# Story 009: Difficulty Tier Selection & Completion Tracking

> **Epic**: Epic 07 — Cross-Cutting Flow Systems
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/mission-select.md`
**Requirement**: `TR-missel-003`

**ADR Governing Implementation**: ADR-0028 (Mission Select Runtime State and Retry Architecture)
**ADR Decision Summary**: `completion_records` is split off `MissionEntry` into a new runtime `CompletionLedger` — `Dictionary[String, Dictionary]` keyed `mission_id → difficulty_tier (1/2/3) → MissionCompletionRecord` (a plain `RefCounted`, mirroring ADR-0026's `CreatureInstance` precedent). An absent ledger entry is treated identically to an explicit `{completed:false, best_time_seconds:-1.0}` record via `Dictionary.get()` with a default.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Inner `Dictionary` is untyped (GDScript typed Dictionaries only type the outer container) — same limitation noted during ADR-0021's engine-specialist review.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0028 directly.
- Forbidden: Never store `completion_records` directly on the shared `MissionEntry` Resource instance — same class of violation ADR-0027 fixed for Tarot.
- Guardrail: `best_time_seconds` monotonically non-increasing — a record can only improve or stay the same, never regress.

---

## Acceptance Criteria

*From GDD `design/gdd/mission-select.md`, scoped to this story:*

- [x] AC-4 — `difficulty_tier` defaults to `recommended_difficulty_tier` on entering CONFIGURING, freely changeable to any of `{1,2,3}` before Launch
- [x] AC-5 — tier changes emit zero EventBus events; only `mission_launched`'s `difficulty_tier` field signals the final choice, once, at confirm time
- [x] AC-6 — per-tier independence: completing Normal doesn't touch Hard/Brutal's records
- [x] AC-7 — monotonic best-time: a slower attempt never regresses the stored record
- [x] AC-8 — sentinel handling: `-1.0` replaced by first real completion, never compared as if it were a real time

---

## Implementation Notes

*Derived from ADR-0028 Implementation Guidelines:*

```gdscript
# MissionCompletionRecord (RefCounted, runtime — not a Resource, never boot-loaded)
class_name MissionCompletionRecord extends RefCounted
var completed: bool = false
var best_time_seconds: float = -1.0    # sentinel — never 0.0

func get_completion_record(mission_id: String, tier: int) -> MissionCompletionRecord:
    var by_tier: Dictionary = _completion_ledger.get(mission_id, {})
    return by_tier.get(tier, MissionCompletionRecord.new())   # EC-1 — absence == default record
```

- **Formula 3** (best-time update): `best_time_seconds' = best_time_seconds` if a prior record exists and is faster; else `completion_time_seconds`. Equivalently: replace only if no prior record (`-1.0` sentinel) or the new attempt is faster.
- No `difficulty_tier_selected` event exists in the frozen event contract — tier changes are silent; the only observable signal is `mission_launched`'s `difficulty_tier` field, fired once, at confirm time. This is an explicit GDD assumption (Rule 3), tested directly by AC-5.
- `completion_records` tracks per-`difficulty_tier` independently — completing Normal does not mark Hard or Brutal complete.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: the static `MissionEntry` schema this ledger is keyed against
- Story 014: EC-1 (no-data-yet display) and EC-5 (orphaned completion records) — this story covers the happy-path tracking logic only

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-4**: Tier defaults and free selection
  - Given: a mission with `recommended_difficulty_tier = 2`
  - When: the player enters CONFIGURING for that mission
  - Then: `difficulty_tier` defaults to `2` without input, freely changeable to `1` or `3` before Launch with no validation blocking any value

- **AC-5**: Silent tier changes
  - Given: the player is in CONFIGURING and changes tier three times in a row (e.g. 2→1→3)
  - When: every EventBus emission during this sequence is recorded
  - Then: zero events fire as a result of the tier changes — the only observable signal is `mission_launched`'s `difficulty_tier` field, fired once at confirm

- **AC-6**: Per-tier independence
  - Given: `mission_id="mission_02"` with no prior `completion_records` entries
  - When: the player completes it on `difficulty_tier=1` (Normal) with `completion_time_seconds=900.0`
  - Then: `completion_records[1] = {completed:true, best_time_seconds:900.0}` while `completion_records[2]`/`[3]` remain `{completed:false, best_time_seconds:-1.0}`

- **AC-7**: Monotonic best-time
  - Given: `completion_records[2].best_time_seconds = 980.0` from a prior Hard completion
  - When: a new Hard attempt completes with `completion_time_seconds=1200.0` (slower)
  - Then: `best_time_seconds` remains `980.0` unchanged

- **AC-8**: Sentinel replacement
  - Given: `completion_records[3].best_time_seconds = -1.0` (never completed)
  - When: a Brutal attempt completes with any positive `completion_time_seconds`
  - Then: the sentinel is replaced by that value — never compared against `-1.0` as if real, never re-entered once a real completion exists

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/mission-select/difficulty-completion-tracking_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/mission-select/difficulty-completion-tracking_test.gd` (8 tests, passing)

---

## Dependencies

- Depends on: Story 008 (`MissionEntry` schema)
- Unlocks: Story 013 (persistence of this ledger), Story 014 (edge cases against it)

**Unblocked**: ADR-0028 accepted 2026-07-18 (Sprint 6, S6-03).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 5/5 passing (8 unit tests, all passing).
**Deviations**: None.
**Test Evidence**: Logic — `tests/unit/mission-select/difficulty-completion-tracking_test.gd`.
**Code Review**: Complete (batch review across Stories 009-014) — APPROVED WITH SUGGESTIONS, all required fixes applied.
