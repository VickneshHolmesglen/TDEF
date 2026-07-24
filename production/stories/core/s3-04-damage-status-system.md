# S3-04 — Damage & Status System Implementation

**Story ID**: S3-04
**Epic**: Core
**Layer**: Core
**Type**: Logic
**Owner**: godot-gdscript-specialist
**Sprint**: 3
**Estimate**: 1.0 days
**Status**: Complete
**Manifest Version**: 2026-05-16

## TR Coverage

| TR-ID | Requirement |
|-------|-------------|
| TR-monster-003 | Damage application: D1 tower formula (floor + armored check) |
| TR-monster-004 | Damage application: D2 hero formula (tier bonus + crit + floor) |
| TR-tower-003 | Lifesteal round-trip: D3 heal = floor(absorbed × fraction), suppressed if 0 |

## ADR Governing Implementation

`docs/architecture/adr-0007-damage-pipeline.md` (Accepted)

**ADR Decision Summary**: D&S is a single GDScript node subscribing to 4 EventBus events.
No public method API — all inputs arrive via EventBus, all outputs leave via EventBus.
Damage events are deferred exactly one frame via `await get_tree().process_frame`.
Every `await` is followed immediately by `if not is_instance_valid(self): return`.
Lifesteal uses a round-trip through `monster_hp_absorbed` — D&S cannot know absorbed
amount at resolve time.

**Engine**: Godot 4.6.2 | **Risk**: LOW — GDScript coroutines, is_instance_valid, floori() unchanged through 4.6

## Dependencies

- S2-01 EventBus Autoload — Complete
- S3-02 Monster System — Must be Complete (provides `monster_hp_absorbed`)
- S3-03 Tower System — Must be Complete (provides `tower_attacked` signal)

## Files to Create

- `src/core/damage_status/damage_status.gd` — DamageStatus autoload (single node, event-driven)
- `tests/unit/damage_status/damage_status_test.gd`

## Acceptance Criteria

### Tower Damage Pipeline — Formula D1
`final_damage = floor(raw_damage × (0.50 if is_armored else 1.0))`

- [ ] AC-1: raw_damage=47.3, is_armored=false → final_damage=**47**
- [ ] AC-2: raw_damage=80.7, is_armored=true → final_damage=**40** (floor(80.7 × 0.50))
- [ ] AC-3: raw_damage=80.7, ELITE target, is_armored=false → final_damage=**80**;
  tower pipeline ignores monster tier; `hero_bonus_tier` always 0 on tower hits
- [ ] AC-4: Zero-damage guard: if final_damage == 0 → do NOT emit `monster_damage_taken`

### Hero Damage Pipeline — Formula D2
`final_damage = floor(base_damage × (1.5 if hero_bonus_tier > 0 else 1.0) × (crit_mult if is_crit else 1.0))`

- [ ] AC-5: base=100, no crit, STANDARD (hero_bonus_tier=0) → final_damage=**100**
- [ ] AC-6: base=100, no crit, ELITE (hero_bonus_tier=1) → final_damage=**150**
- [ ] AC-7: base=100, crit, ELITE, crit_mult=1.75 → final_damage=**262** (floor(100 × 1.50 × 1.75))
- [ ] AC-8: base=100, crit, STANDARD, crit_mult=1.75 → final_damage=**175** (floor(100 × 1.75))

### Lifesteal Round-Trip — Formula D3
`hero_healed.amount = floor(absorbed × lifesteal_fraction)` (suppressed if result = 0)

- [ ] AC-9: lifesteal_fraction=0.20, absorbed=150 → `hero_healed` fires with amount=**30**
- [ ] AC-10: lifesteal_fraction=0.10, absorbed=2 → `hero_healed` NOT fired (floor(2×0.10)=0 — suppressed)
- [ ] AC-11: lifesteal_fraction=0.0, any absorbed → `hero_healed` never fires (fast path: skip if fraction==0)

### Architectural Invariants
- [ ] AC-12: After every `await get_tree().process_frame`, the FIRST statement is
  `if not is_instance_valid(self): return` — no variable access before the guard
- [ ] AC-13: D&S emits `hero_healed` synchronously from within `_on_monster_hp_absorbed`
  (Level-1 cascade — explicitly permitted; see ADR-0007 exemption rationale)
- [ ] AC-14: `_lifesteal_pending` dictionary cleared on `wave_completed` signal

## Implementation Notes (from ADR-0007)

### EventBus Subscriptions (4 signals)

```gdscript
func _ready() -> void:
    EventBus.tower_attacked.connect(_on_tower_attacked)
    EventBus.hero_auto_attacked.connect(_on_hero_auto_attacked)
    EventBus.monster_hp_absorbed.connect(_on_monster_hp_absorbed)
    EventBus.wave_completed.connect(_on_wave_completed)
```

### Deferral Pattern — `await get_tree().process_frame`

Use `await get_tree().process_frame` (NOT `call_deferred`). This guarantees
`monster_damage_taken` arrives in MonsterManager's NEXT frame Pass 1 drain:

```gdscript
func _on_tower_attacked(payload) -> void:
    var final_damage := _resolve_d1(payload)
    if final_damage == 0:
        return  # zero-damage guard
    var event := MonsterDamageTaken.new()
    event.entity_id = payload.target_id
    event.amount = float(final_damage)
    # ... populate remaining fields
    await get_tree().process_frame
    if not is_instance_valid(self):
        return
    EventBus.monster_damage_taken.emit(event)
```

### Lifesteal Round-Trip

```gdscript
var _lifesteal_pending: Dictionary = {}  # entity_id: int → fraction: float

func _on_hero_auto_attacked(payload) -> void:
    if payload.lifesteal_fraction == 0.0:
        return  # skip entirely — no pending entry
    _lifesteal_pending[payload.target_id] = payload.lifesteal_fraction
    # resolve D2 formula, emit monster_damage_taken deferred...

func _on_monster_hp_absorbed(entity_id: int, absorbed: float) -> void:
    if not _lifesteal_pending.has(entity_id):
        return
    var fraction: float = _lifesteal_pending[entity_id]
    _lifesteal_pending.erase(entity_id)
    var heal_amount: int = floori(absorbed * fraction)
    if heal_amount == 0:
        return  # suppressed
    EventBus.hero_healed.emit(heal_amount)  # synchronous — Level-1 cascade (ADR-0007 exemption)
```

### `hero_healed` Cascade Exemption

`hero_healed` fires synchronously from within `_on_monster_hp_absorbed`. This is a
Level-1 cascade explicitly permitted by ADR-0007 because:
- Volume bound: max 1 per hero auto-attack interval (well below 20/frame threshold)
- Terminal: Hero System only clamps HP, emits nothing further

**Revocation condition**: if hero attack rate approaches 20/frame in future, must convert to deferred.

## Out of Scope

- Status effects / DoTs / debuffs (post-MVP)
- Hero auto-attack targeting (Hero System story, Sprint 4+)
- `MonsterDamageTaken` Resource definition — created in S3-02; import it here

## QA Test Cases

- **AC-1**: D1 no-armor
  - Given: `tower_attacked` payload with raw_damage=47.3, is_armored=false
  - When: D&S `_on_tower_attacked` resolves
  - Then: emitted `monster_damage_taken` event has amount=47 (floored)
  - Edge cases: raw_damage=0.9 → floor=0 → zero-damage guard fires, no emission

- **AC-2**: D1 armored
  - Given: raw_damage=80.7, is_armored=true
  - When: D1 formula resolves
  - Then: amount=40 (floor(80.7 × 0.50))
  - Edge cases: raw_damage=5.0, is_armored=true → floor(2.5) = 2

- **AC-7**: D2 crit × elite
  - Given: `hero_auto_attacked` payload with base_damage=100, is_crit=true,
    hero_bonus_tier=1, crit_multiplier_effective=1.75
  - When: D2 formula resolves
  - Then: final_damage = floor(100 × 1.50 × 1.75) = 262
  - Edge cases: maximum crit base=100, ELITE, crit_mult=3.25 → floor(100 × 1.50 × 3.25) = 487

- **AC-9**: Lifesteal heal fires
  - Given: `_lifesteal_pending[42] = 0.20` set, `monster_hp_absorbed(42, 150.0)` fires
  - When: `_on_monster_hp_absorbed` handles event
  - Then: `hero_healed` emitted with amount=30; entry erased from `_lifesteal_pending`

- **AC-10**: Lifesteal suppressed at zero
  - Given: `_lifesteal_pending[42] = 0.10` set, `monster_hp_absorbed(42, 2.0)` fires
  - When: heal_amount = floor(2.0 × 0.10) = 0
  - Then: `hero_healed` NOT emitted; entry still erased from `_lifesteal_pending`

- **AC-12**: `is_instance_valid` guard placement
  - Verify via code inspection that every `await get_tree().process_frame` is immediately
    followed by `if not is_instance_valid(self): return` with no intervening statements

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage_status/damage_status_test.gd` — all ACs covered

**Status**: [x] Created — `tests/unit/damage_status/damage_status_test.gd` (17 test functions)

## Dependencies

- Depends on: S3-02 (Monster System, for MonsterDamageTaken Resource + monster_hp_absorbed signal)
- Depends on: S3-03 (Tower System, for tower_attacked signal)
- Unlocks: S3-05 (Combat loop integration)

## Completion Notes

**Completed**: 2026-07-01
**Criteria**: 14/14 passing
**Deviations**:
- ADVISORY: DamageStatus is scene-instanced (extends Node), not Autoload — `_lifesteal_pending` is per-wave state; control manifest prohibits autoloads from owning per-mission state. Consistent with S3-03 TowerSystem precedent.
- ADVISORY: TR-monster-003/004 registry descriptions reference Monster System internals, not D1/D2 formulas directly. TRs are active; connection is valid (D&S feeds Monster System's pending damage buffer).
**Test Evidence**: Logic — `tests/unit/damage_status/damage_status_test.gd` (17 tests: 14 ACs + 3 edge cases)
**Code Review**: Complete — godot-gdscript-specialist + qa-tester; all required findings resolved (typed Dictionary, AC-11 damage assertion, floor-vs-round edge case)
