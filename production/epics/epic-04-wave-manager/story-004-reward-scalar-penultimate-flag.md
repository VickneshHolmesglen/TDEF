# Story 004: Wave Reward Scalar Formula & Penultimate-Wave Flag

> **Epic**: Wave Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-05-16
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/wave-manager.md`
**Requirement**: `TR-wave-006`, `TR-wave-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012: Wave Manager FSM Architecture
**ADR Decision Summary**: `wave_reward_scalar` is computed in `_enter_wave_active()` from `_wave_index` and `WaveConfig.difficulty_growth_rate`, passed in both `wave_started.wave_difficulty` and `monster_spawn_requested.wave_reward_scalar`. `is_penultimate_wave` is computed inline from `_wave_index == wave_scripts.size() - 1 AND wave_scripts.size() >= 5`.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Pure math — `pow()`/`**` operator, no post-cutoff risk. Verify Godot 4.6.2's `**` operator or `pow()` builtin syntax against `docs/engine-reference/godot/` before use (low risk, but check per this project's standing rule to never assume post-cutoff API behavior).

**Verified against the actual codebase (2026-07-04)**: `var _wave_reward_scalar: float = 1.0` exists as a static field — grep confirms no `difficulty_growth_rate`, `pow(`, or exponentiation anywhere in the file. The formula is never actually computed; every wave reports a flat 1.0× regardless of wave number.

`is_penultimate_wave` does not exist anywhere. Confirmed by reading the actual payload chain: `MonsterSpawnRequest` (`src/foundation/event_bus/event_payloads/monster_spawn_request.gd`) currently has exactly **5** `@export` fields (`monster_id`, `spawn_cell`, `wave_index`, `difficulty_tier`, `wave_reward_scalar`) — its own doc comment cites "ADR-0001 Rule 3: 5 fields." `difficulty_tier` is **already correctly implemented** end-to-end: `WaveSpawnEntry` (`src/gameplay/wave_spawn_entry.gd`) stores it per-entry and `to_payload()` already forwards it. The ONLY genuinely missing field for AC-12's required 6 is `is_penultimate_wave: bool` — a single field needs adding to `MonsterSpawnRequest`, and `WaveSpawnEntry.to_payload(wave_index, wave_reward_scalar, spawn_cell)` needs exactly one new parameter.

**Control Manifest Rules (Feature layer)**:
- Guardrail: formula computation is O(1) per wave (once at `_enter_wave_active()`), never recomputed per-spawn or per-frame

---

## Acceptance Criteria

*From `design/gdd/wave-manager.md`, scoped to this story:*

- [ ] F1 / AC-17: `wave_reward_scalar = 1.0 × (1 + r)^(w - 1)` where `w = _wave_index`, `r = difficulty_growth_rate`. Boundary table: wave 1 → 1.000 (any r); wave 4, r=0.20 → 1.728; wave 4, r=0.25 → 1.953; wave 8, r=0.20 → 3.583; wave 8, r=0.25 → 4.768 (±0.001 tolerance).
- [ ] AC-17 (payload consistency): `wave_reward_scalar` in `wave_started.wave_difficulty` matches the value in `monster_spawn_requested.wave_reward_scalar` for the same wave.
- [ ] Rule 15c / AC-12: `is_penultimate_wave` is `true` when `_wave_index == wave_scripts.size() - 1 AND wave_scripts.size() >= 5`; `false` in all other cases, including all sub-5-wave missions.
- [ ] AC-12: `monster_spawn_requested` payload contains exactly 6 fields: `monster_id`, `spawn_cell`, `wave_index`, `difficulty_tier`, `wave_reward_scalar`, `is_penultimate_wave` — no more, no fewer.
- [ ] Runtime validation: on `mission_launched`, validate `0.10 ≤ difficulty_growth_rate ≤ 0.25`; if violated, log a content error but do not clamp (mission continues with the authored value).
- [ ] Performance: No performance impact expected — `pow()` call and one boolean comparison, computed once per wave at WAVE_ACTIVE entry (never per-frame or per-spawn), consistent with the Control Manifest's O(1) guardrail for this story.

---

## Implementation Notes

*Derived from ADR-0012 Implementation Guidelines and the GDD Formulas section:*

```gdscript
## F1 (wave-manager.md): computed once per wave at WAVE_ACTIVE entry, never
## per-frame or per-spawn. difficulty_growth_rate comes from the mission's
## WaveConfig (Story 006) — until that lands, use a settable test-injection
## field, matching this file's established pattern for other not-yet-wired
## config values.
var difficulty_growth_rate: float = 0.20  # placeholder default; real source is WaveConfig (Story 006)

func _enter_wave_active() -> void:
    _wave_index += 1
    _enemies_alive = 0
    _all_spawns_fired = false
    _spawn_active = true
    _wave_reward_scalar = pow(1.0 + difficulty_growth_rate, float(_wave_index - 1))
    GEventBus.wave_started.emit(_wave_index, _total_wave_count(), _wave_reward_scalar)
    _run_spawn_sequence()


## Rule 15c: penultimate = second-to-last wave, ONLY for missions with 5+
## waves. wave_scripts_count comes from Story 006's real WaveConfig; until
## then, use the same test-injectable total-wave-count field Story 001
## introduced for _is_final_wave().
func _is_penultimate_wave() -> bool:
    var total: int = _total_wave_count()
    return _wave_index == total - 1 and total >= 5
```

Exactly two files need a one-field addition each:

```gdscript
# src/foundation/event_bus/event_payloads/monster_spawn_request.gd — ADD:
@export var is_penultimate_wave: bool = false
# (updates the class doc comment's "5 fields" to "6 fields" too)

# src/gameplay/wave_spawn_entry.gd — CHANGE to_payload()'s signature:
func to_payload(wave_index: int, wave_reward_scalar: float, spawn_cell: Vector2i,
        is_penultimate_wave: bool) -> MonsterSpawnRequest:
    var payload := MonsterSpawnRequest.new()
    payload.monster_id = monster_id
    payload.spawn_cell = spawn_cell
    payload.wave_index = wave_index
    payload.difficulty_tier = difficulty_tier
    payload.wave_reward_scalar = wave_reward_scalar
    payload.is_penultimate_wave = is_penultimate_wave
    return payload
```

Then update the one call site in `wave_manager.gd`'s `_run_spawn_sequence()`:

```gdscript
GEventBus.monster_spawn_requested.emit(
    entry.to_payload(_wave_index, _wave_reward_scalar, _spawn_cell, _is_penultimate_wave())
)
```

`difficulty_tier` needs no changes — confirmed already correctly implemented end-to-end (per-entry field on `WaveSpawnEntry`, already forwarded by the existing `to_payload()`).

**Runtime validation** (add to `mission_launched` handling — coordinate with Story 006, which owns the `mission_launched` handler itself):

```gdscript
if difficulty_growth_rate < 0.10 or difficulty_growth_rate > 0.25:
    push_error("WaveManager: difficulty_growth_rate %.2f outside valid range [0.10, 0.25]" % difficulty_growth_rate)
    # value is NOT clamped — mission continues with the authored value
```

---

## Out of Scope

- **Story 001**: `_total_wave_count()` this story reads
- **Story 006**: Real `WaveConfig.difficulty_growth_rate` sourcing — this story uses a settable placeholder field until then
- **Resource Economy System**: Consuming `wave_reward_scalar` for drop quantity/quality — that's a downstream system's own GDD/implementation, out of this epic entirely

---

## QA Test Cases

- **AC-17**: F1 formula boundary table
  - Given: `_wave_index` and `difficulty_growth_rate` set per the boundary table
  - When: `_enter_wave_active()` runs (or the formula function is called directly)
  - Then: `_wave_reward_scalar` matches the table within ±0.001 (5 assertions: wave 1 any-r=1.000, wave4/r0.20=1.728, wave4/r0.25=1.953, wave8/r0.20=3.583, wave8/r0.25=4.768)
  - Edge case: verify `wave_started.wave_difficulty` and `monster_spawn_requested.wave_reward_scalar` carry the identical value for the same wave

- **AC-12 / Rule 15c**: `is_penultimate_wave` correctness
  - Given: 5-wave mission, `_wave_index = 4` (penultimate)
  - When: a spawn fires
  - Then: `is_penultimate_wave == true`
  - Edge case: 5-wave mission at `_wave_index = 3` → `false`; 4-wave mission at `_wave_index = 3` (would-be penultimate but total < 5) → `false` (sub-5-wave exemption)

- **AC-12**: Payload has exactly 6 fields
  - Given: any spawn fires
  - When: the `monster_spawn_requested` `MonsterSpawnRequest` payload is captured
  - Then: assert exactly 6 `@export` fields exist with correct names and GDScript types (`monster_id: StringName`, `spawn_cell: Vector2i`, `wave_index: int`, `difficulty_tier: int`, `wave_reward_scalar: float`, `is_penultimate_wave: bool`) — no additional fields present

- **Runtime validation**: out-of-range `difficulty_growth_rate` logs, doesn't clamp
  - Given: `difficulty_growth_rate = 0.30`
  - When: `mission_launched` fires
  - Then: error logged containing the value; mission continues; wave 8's scalar still computes from 0.30 (unclamped) if the mission runs that long

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/wave_manager/wave_manager_reward_scalar_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`_total_wave_count()` / final-wave helpers)
- Unlocks: Story 008 (mission scene assembly benefits from real difficulty scaling, though not strictly blocking)

---

## Completion Notes
**Completed**: 2026-07-05
**Criteria**: 6/6 passing (all COVERED, no deferred items)
**Deviations**: ADVISORY (x5) — (1) corrected the story's recurring stale `_total_wave_count()` reference to the real `_wave_scripts_count` field; (2) a genuine sequencing conflict not anticipated by the original spec — Story 002's later relocation of `wave_started`'s emission into `_transition_to()` required moving this story's formula computation to the same point, proven correct via a dedicated cross-wave regression test; (3) a cross-story coordination gap was found and fixed this session — Story 006's draft has been updated to call `_validate_difficulty_growth_rate()` instead of duplicating the bounds check inline, preventing it from becoming dead code; (4) the performance-guardrail test is a textual proxy, not a behavioral test — consistent with existing house style, not blocking; (5) no explicit regression test for the Story-001 sentinel default (999999) in `_is_penultimate_wave()` — low risk, produces `false` (same accepted behavior as `_is_final_wave()`'s identical pattern).
**Test Evidence**: `tests/unit/wave_manager/wave_manager_reward_scalar_test.gd` — 21/21 passing; full `wave_manager` suite re-confirmed at 55/55, 0 errors, 0 failures
**Code Review**: Complete — APPROVED (after one APPROVED WITH SUGGESTIONS round addressing doc-comment clarity and the Story 006 coordination gap)
