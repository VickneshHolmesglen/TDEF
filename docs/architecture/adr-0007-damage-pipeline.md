# ADR-0007: Damage Pipeline — Deferred Dispatch with `await` + `is_instance_valid` Guard

## Status
Proposed

## Date
2026-05-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | LOW — GDScript coroutines (`await`), `is_instance_valid()`, `floori()`, and `Dictionary` are pre-4.x APIs unchanged through 4.6 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — all APIs in this ADR predate Godot 4.4 |
| **Verification Required** | Confirm `await get_tree().process_frame` suspends to start-of-next-frame (not end-of-current-frame) in Godot 4.6.2; confirm `is_instance_valid(self)` returns `false` for freed nodes whose coroutines are still suspended |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (EventBus — all cross-system communication routed through EventBus; cascade rules define which emissions require deferral); ADR-0006 (Monster movement — defines `monster_hp_absorbed` emission in MonsterManager Pass 4 and `MonsterDamageTaken` Resource type used by `_pending_damage: Array[MonsterDamageTaken]`) |
| **Enables** | D&S implementation story; Monster System HP-application story (requires `monster_damage_taken` event shape Accepted); Hero System lifesteal story (requires `hero_healed` pattern Accepted) |
| **Blocks** | D&S Core epic; Monster System Core epic (HP application cannot be implemented until `monster_damage_taken` payload is Accepted) |
| **Ordering Note** | ADR-0006 must be Accepted before this ADR is Accepted — `monster_hp_absorbed` (Pass 4 emission defined in ADR-0006) is the trigger for lifesteal resolution in this ADR. Both ADRs can be Proposed simultaneously. |

## Context

### Problem Statement

Damage in Sanctuary Defenders flows from two attack sources — towers and the hero — to Monster System. Each source carries a different payload, applies different formulas (armored mitigation for towers; tier bonus + crit for hero), and has different downstream effects (only hero hits can trigger lifesteal). A single intermediary, Damage & Status (D&S), must resolve all damage calculations and deliver a normalized `monster_damage_taken` event without holding any direct system references, without blocking physics-frame execution, and without leaking per-hit state across waves.

The three open implementation questions this ADR resolves:
1. How to defer damage events one frame without introducing timing ambiguity relative to MonsterManager's `_physics_process` pass order
2. How to guard against the D&S node being freed mid-coroutine during a scene transition
3. How to resolve lifesteal against actual absorbed HP (which only Monster System knows) without a direct call to Monster System

### Constraints
- All inter-system communication must use EventBus (ADR-0001: `direct_cross_system_node_reference` forbidden)
- EventBus cascade depth ≤ 2 levels; synchronous Level-1 cascades are forbidden at tower-attack volume (`synchronous_level1_cascade` registered forbidden pattern)
- The D&S node may be freed mid-coroutine if a scene transition fires during WAVE_ACTIVE; no crash may result
- Lifesteal heal amount requires `absorbed` (actual HP removed, potentially less than `final_damage` on overkill) — D&S cannot compute this at attack-resolve time

### Requirements
- **Tower pipeline**: resolve D1 (`floori(raw × mitigation)`), emit `monster_damage_taken` deferred one frame
- **Hero pipeline**: resolve D2 (`floori(base × tier_mult × crit_mult)`), emit `monster_damage_taken` deferred one frame, register lifesteal if `hero_lifesteal_fraction > 0`
- **Hero armor**: resolve D4 (`max(1, floori(incoming × 100 / (armor_clamped + 100)))`), emit `hero_damage_taken` deferred one frame
- **Lifesteal**: register fraction before defer; resolve D3 on `monster_hp_absorbed`; suppress `hero_healed` if `heal_amount == 0`; clean `_lifesteal_pending` on `wave_completed`
- All guard checks must fire as the first statement after every `await`

## Decision

D&S is a single GDScript node that subscribes to four EventBus events and has no public method API. All inputs arrive via EventBus; all outputs leave via EventBus.

### Deferral Pattern: `await get_tree().process_frame`

All damage events that feed Monster System via HP application are deferred exactly one frame using `await get_tree().process_frame`. This is chosen over `call_deferred` because:

- `call_deferred` executes at end-of-current-frame, before `_physics_process` runs again. It does not guarantee the event arrives in MonsterManager's **next** frame Pass 1 drain — it may interleave with the current frame's physics tail.
- `await get_tree().process_frame` suspends the coroutine until the start of the **next** full frame cycle, guaranteeing `monster_damage_taken` arrives in the following frame's Pass 1 drain.

### Guard Invariant: `is_instance_valid(self)` After Every `await`

After every `await`, the guard is the **first statement** — before any variable reads, method calls, or Dictionary accesses. This is an architectural invariant, not a style preference:

```gdscript
await get_tree().process_frame
if not is_instance_valid(self):
    return
```

If the D&S node is freed during the `await` suspension (e.g., mission ends mid-wave), `self` is invalid. Any property access before the guard produces an invalid memory access. The guard must be unconditional and immediate.

### Lifesteal Round-Trip Pattern

Lifesteal requires the actual HP absorbed from the target — which only Monster System knows after applying `monster_damage_taken`. D&S cannot compute `absorbed` at resolve time. The pattern:

1. `hero_auto_attacked` arrives → resolve `final_damage`, register `_lifesteal_pending[target_id] = hero_lifesteal_fraction` (skip entirely if fraction == 0.0)
2. Emit `monster_damage_taken` deferred one frame
3. Monster System processes it in the next Pass 1 drain, applies HP, emits `monster_hp_absorbed(entity_id, absorbed)` from Pass 4
4. D&S receives `monster_hp_absorbed` → look up fraction → compute D3 → emit `hero_healed` if `heal_amount > 0` → erase entry

Orphaned entries (dead entity discards, where Monster System does not emit `monster_hp_absorbed`) persist until `wave_completed` clears `_lifesteal_pending`.

### `hero_healed` Cascade Exemption

`hero_healed` is emitted synchronously from within the `monster_hp_absorbed` handler — a Level-1 cascade. The registered forbidden pattern `synchronous_level1_cascade` bans this generally to protect EventBus frame budget at tower-attack volume. `hero_healed` qualifies for an explicit exemption because:

- **Volume bound**: fires at most once per hero auto-attack interval (hero attack rate at MVP is far below the 20/frame batch threshold)
- **Terminal**: `hero_healed` has no further emissions from its subscriber (Hero System clamps HP only)
- **GDD authority**: the D&S GDD explicitly permits this cascade as "within the 2-level chain rule — no exemption needed"

**Revocation condition**: if Hero System's attack rate is ever raised to approach 20 attacks/frame, `hero_healed` must be converted to a deferred emit. This limit must be tracked in the Hero GDD attack-speed cap.

### `MonsterDamageTaken` Resource Formalization

The `monster_damage_taken` signal carries a `MonsterDamageTaken` Resource subclass (5 fields — ≥5 fields per ADR-0001 requires a Resource subclass). This is consistent with ADR-0006's `_pending_damage: Array[MonsterDamageTaken]`. The D&S GDD documents the fields as a payload spec but does not explicitly call out the Resource subclass requirement — this ADR formalizes that.

**GDD gap note**: `design/gdd/damage-status.md` (Formula section, "Event Payload: monster_damage_taken") should be updated to add a line stating it is a `MonsterDamageTaken` Resource subclass, not 5 individual signal parameters.

### Architecture Diagram

```
EventBus signals:
  tower_attacked ──────────► D&S._on_tower_attacked
                                  resolve D1 (floor, armored check)
                                  zero-damage guard
                                  await process_frame
                                  is_instance_valid guard
                                  emit monster_damage_taken(MonsterDamageTaken)
                                       │
  hero_auto_attacked ───────► D&S._on_hero_auto_attacked
                                  resolve D2 (floor, tier, crit)
                                  zero-damage guard
                                  register _lifesteal_pending[target_id] if fraction > 0
                                  await process_frame
                                  is_instance_valid guard
                                  emit monster_damage_taken(MonsterDamageTaken)
                                       │
                                       ▼
                              MonsterManager (Pass 1 drain)
                              applies HP, computes absorbed
                                       │
                              MonsterManager (Pass 4 flush)
                              emit monster_hp_absorbed(entity_id, absorbed)
                                       │
  monster_hp_absorbed ──────► D&S._on_monster_hp_absorbed
                                  look up _lifesteal_pending[entity_id]
                                  resolve D3 (floor, absorbed × fraction)
                                  erase entry
                                  if heal > 0: emit hero_healed(heal) [cascade depth 1]
                                       │
  hero_incoming_damage ─────► D&S._on_hero_incoming_damage
                                  resolve D4 (floor, armor reduction, max-1 guard)
                                  await process_frame
                                  is_instance_valid guard
                                  emit hero_damage_taken(amount, source_type)

  wave_completed ───────────► D&S._on_wave_completed
                                  if _lifesteal_pending not empty:
                                    await process_frame
                                    is_instance_valid guard
                                    _lifesteal_pending.clear()
```

### Key Interfaces

```gdscript
# Internal state
var _lifesteal_pending: Dictionary  # Dictionary[int, float]: target_id → hero_lifesteal_fraction

# Tuning constants (data-driven, not hardcoded in formulas)
const armored_mitigation_multiplier: float = 0.50
const hero_damage_bonus_multiplier: float = 1.50

# — Tower pipeline (async) —
func _on_tower_attacked(damage_amount: float, target_monster_id: int,
        is_armored: bool, _is_siege: bool) -> void:
    var resolved := damage_amount * (armored_mitigation_multiplier if is_armored else 1.0)
    var final_damage: int = floori(resolved)
    if final_damage <= 0:
        return
    await get_tree().process_frame
    if not is_instance_valid(self):
        return
    var ev := MonsterDamageTaken.new()
    ev.entity_id = target_monster_id
    ev.amount = final_damage
    ev.source_type = 0
    ev.is_crit = false
    ev.hero_bonus_tier = 0
    EventBus.monster_damage_taken.emit(ev)

# — Hero pipeline (async) —
func _on_hero_auto_attacked(event: HeroAutoAttackEvent) -> void:
    var tier_dmg := event.base_damage * (hero_damage_bonus_multiplier if event.hero_bonus_tier > 0 else 1.0)
    var crit_dmg := tier_dmg * (event.crit_multiplier_effective if event.is_crit else 1.0)
    var final_damage: int = floori(crit_dmg)
    if final_damage <= 0:
        return
    if event.hero_lifesteal_fraction > 0.0:
        _lifesteal_pending[event.target_id] = event.hero_lifesteal_fraction
    await get_tree().process_frame
    if not is_instance_valid(self):
        return
    var ev := MonsterDamageTaken.new()
    ev.entity_id = event.target_id
    ev.amount = final_damage
    ev.source_type = 1
    ev.is_crit = event.is_crit
    ev.hero_bonus_tier = event.hero_bonus_tier
    EventBus.monster_damage_taken.emit(ev)

# — Lifesteal resolution (synchronous — cascade depth 1 from monster_hp_absorbed) —
func _on_monster_hp_absorbed(entity_id: int, absorbed: int) -> void:
    if not _lifesteal_pending.has(entity_id):
        return
    var fraction: float = _lifesteal_pending[entity_id]
    _lifesteal_pending.erase(entity_id)
    var heal_amount: int = floori(absorbed * fraction)
    if heal_amount > 0:
        EventBus.hero_healed.emit(heal_amount)

# — Hero armor pipeline (async) —
func _on_hero_incoming_damage(incoming: float, source_type: int) -> void:
    var armor_clamped: float = max(0.0, hero_armor)  # hero_armor read from Hero System state (TBD)
    var effective: int = max(1, floori(incoming * 100.0 / (armor_clamped + 100.0)))
    await get_tree().process_frame
    if not is_instance_valid(self):
        return
    EventBus.hero_damage_taken.emit(effective, source_type)

# — Wave cleanup —
func _on_wave_completed() -> void:
    if _lifesteal_pending.is_empty():
        return
    await get_tree().process_frame
    if not is_instance_valid(self):
        return
    _lifesteal_pending.clear()
```

> **Note on `hero_armor` read**: Formula D4 requires the hero's current armor stat. How D&S accesses this is an open question — options include carrying it in the `hero_incoming_damage` event payload (cleanest: Hero System pre-resolves) or reading a Hero System Autoload property (violates EventBus rule). The recommended resolution is extending the `hero_incoming_damage` event to carry `hero_armor: float` in its payload. This follow-up is tracked as an open question for the Hero GDD.

## Alternatives Considered

### Alternative 1: `call_deferred` for damage dispatch
- **Description**: `EventBus.monster_damage_taken.emit.call_deferred(ev)` instead of `await get_tree().process_frame`
- **Pros**: Simpler — no coroutine state, no `is_instance_valid` guard needed
- **Cons**: `call_deferred` schedules at end-of-current-frame, not start-of-next-frame. MonsterManager's `_physics_process` may run again in the same frame after the deferred call, producing ordering ambiguity. Additionally, `call_deferred` cannot easily be guarded against freed-node crashes without wrapping in a callable that checks validity.
- **Rejection Reason**: Frame-boundary timing is ambiguous relative to `_physics_process` scheduling. `await get_tree().process_frame` guarantees next-frame delivery.

### Alternative 2: Direct call to Monster System for lifesteal
- **Description**: D&S calls a method on Monster System directly after emitting `monster_damage_taken` to retrieve `absorbed` HP in the same frame
- **Pros**: Eliminates the round-trip latency and `_lifesteal_pending` Dictionary state
- **Cons**: Requires D&S to hold a direct Node reference to Monster System — violates `direct_cross_system_node_reference` (ADR-0001 registered forbidden pattern)
- **Rejection Reason**: Forbidden pattern.

### Alternative 3: Synchronous damage application (no deferral)
- **Description**: Emit `monster_damage_taken` synchronously from within the `tower_attacked` / `hero_auto_attacked` subscriber
- **Pros**: Simplest possible — no coroutine state
- **Cons**: Synchronous Level-1 cascade from `tower_attacked` into `monster_damage_taken`. At 10+ towers firing simultaneously (20+ events/frame during WAVE_ACTIVE), this violates the cascade budget. `monster_damage_taken` → `monster_hp_absorbed` → `hero_healed` would be a 3-level synchronous chain exceeding the 2-level limit.
- **Rejection Reason**: Violates ADR-0001 cascade limit and `synchronous_level1_cascade` forbidden pattern.

## Consequences

### Positive
- D&S holds zero direct system references — fully decoupled from Monster System and Hero System
- Lifesteal resolves on `absorbed` (actual HP removed), making overkill behavior correct by construction
- The `await` + `is_instance_valid` coroutine guard pattern is now a documented project-wide idiom for all future async EventBus subscribers
- `MonsterDamageTaken` Resource subclass is formally established as the signal carrier shape

### Negative
- Lifesteal heal fires 2 frames after the hero's attack event (N+1 for `monster_damage_taken` delivery, N+2 for `hero_healed` in Monster System's Pass 4) — imperceptible at 60fps but measurable in integration tests
- `_lifesteal_pending` Dictionary accumulates orphaned entries if Monster System discards a `monster_damage_taken` event for a dead entity (does not emit `monster_hp_absorbed`) — cleared at `wave_completed` but not sooner
- The `wave_completed` defer adds one additional frame before `_lifesteal_pending` is confirmed empty — cross-wave state cleanup is not instantaneous

### Risks
- **Coroutine leak on freed node**: Mitigated by `is_instance_valid(self)` guard as first statement after every `await`. If the guard fires, the coroutine returns early and no event is emitted.
- **`_lifesteal_pending` growth if Monster System violates its contract**: Monster System MUST emit `monster_hp_absorbed` for every `monster_damage_taken` it processes (except discarded dead-entity events). If Monster System skips this emission, lifesteal entries accumulate silently until `wave_completed`. Mitigated by AC-23 integration test.
- **`hero_healed` cascade exemption revocation**: If Hero System's attack rate rises to approach 20 attacks/frame, `hero_healed` must be converted to a deferred emit. Requires updating this ADR and the Hero GDD attack-speed cap. Currently not a production risk at MVP hero attack rates.

## GDD Requirements Addressed

| GDD System | TR-ID | Requirement | How This ADR Addresses It |
|------------|-------|-------------|--------------------------|
| damage-status.md | TR-ds-001 | Two pipelines: direct hit + DoT | Defines tower pipeline (D1: armored mitigation) and hero pipeline (D2: tier + crit) as distinct async subscribers with distinct resolution formulas |
| damage-status.md | TR-ds-002 | `await` + `is_instance_valid` guard pattern | Documents this as an architectural invariant — guard must be the first statement after every `await`, before any other access to `self` |
| damage-status.md | TR-ds-003 | `_lifesteal_pending: Dictionary[int, float]` | Defines the round-trip pattern: register fraction before defer, resolve on `monster_hp_absorbed`, erase on resolution, clear on `wave_completed` |
| damage-status.md | TR-ds-004 | 5 status effect types + stack/duration rules | Out of scope — status effects are a separate system not yet designed. This ADR covers the HP damage pipeline only. |
| damage-status.md | TR-ds-005 | No direct call API — EventBus only | Confirmed: D&S exposes no public methods. All inputs arrive via EventBus subscriptions; all outputs leave via EventBus emissions. |
| hero.md | TR-hero-004 | Event-driven targeting (no direct Monster refs) | D&S receives `hero_auto_attacked` and emits `monster_damage_taken` — hero never calls Monster System |
| tower.md | TR-tower-003 | Monster cache via EventBus; no direct refs | Tower System emits `tower_attacked`; D&S resolves and forwards — Tower System never accesses Monster System |

> **Note on TR-ds-004**: Status effects are referenced as out-of-scope for MVP in the D&S GDD. A separate ADR will be required when that system is designed.

## Performance Implications
- **CPU**: At MVP combat load (≤10 towers × attack rate + 1 hero), peak input is ~20 events/frame (at EventBus batch threshold). Each handler performs ≤3 multiplications and one `floori()` call before yielding. Coroutine allocation per event is negligible vs. GDScript object allocation baseline. D&S performance budget: < 0.1 ms/frame at peak load.
- **Memory**: `_lifesteal_pending` holds at most 1 entry per hero attack interval (one active target per auto-attack). At MVP hero attack rates (0.5–2s interval), maximum simultaneous entries = 1. Dictionary overhead is bounded.
- **Load Time**: None — no precomputation or resource loading.
- **Network**: Not applicable — single-player MVP.

## Migration Plan
Greenfield system — no existing code to migrate. Three GDD follow-up updates required before D&S stories can be authored:

1. **Monster GDD** (`design/gdd/monster.md`): document `monster_hp_absorbed` emission after HP application in Pass 4, and non-emission on dead-entity discard (resolves Monster GDD OQ-4 reference in D&S GDD)
2. **Hero GDD** (`design/gdd/hero.md`): replace `hero_damage_bonus_eligible: bool` with `hero_bonus_tier: int` in `HeroAutoAttackEvent` payload; document that `hero_incoming_damage` event should carry `hero_armor: float` in its payload so D&S does not need a direct stat read
3. **EventBus GDD** (`design/gdd/event-bus.md`): confirm `monster_hp_absorbed` in event catalogue; confirm `is_armored: bool` in `tower_attacked` payload; update `HeroAutoAttackEvent` to `hero_bonus_tier: int`; confirm `monster_damage_taken` uses `MonsterDamageTaken` Resource subclass

## Validation Criteria
- AC-10: `monster_damage_taken` received at frame N+1 (verified by `Engine.get_frames_drawn()` comparison)
- AC-22: `is_instance_valid` guard fires correctly on freed node — no crash, no event emitted
- AC-23: `_lifesteal_pending` is empty after `wave_completed` + 1 frame
- AC-8, AC-11: lifesteal resolves on `absorbed`, not `final_damage` (overkill capped correctly)
- AC-4 through AC-7, AC-16: tower and hero pipeline formulas for all tier/crit combinations
- AC-15, AC-20: zero-damage guard fires before `_lifesteal_pending` registration — no orphan entries from malformed input

## Related Decisions
- ADR-0001 — EventBus architecture (cascade rules and forbidden patterns referenced by this ADR)
- ADR-0006 — Monster movement (defines `monster_hp_absorbed` emission in Pass 4; `MonsterDamageTaken` Resource type established there)
- ADR-0008 — Tower placement gate (Tower System GDD references `monster_damage_taken` as the event Tower fires into)
