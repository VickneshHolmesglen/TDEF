# Damage & Status System

> **Status**: Revised (post-re-review — pending re-review)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-05-14
> **Review Date**: 2026-05-14 — NEEDS REVISION (4 of 12 pass-5 blockers resolved in-session)
> **Implements Pillar**: Mastery-as-Vindication · The Fight Must Be Worth It

## Overview

The Damage & Status System is the single authoritative pipeline through which all offensive actions in Sanctuary Defenders are resolved into damage values that reach monsters and the hero. Every attack that reaches a monster — whether from a tower's weapon component or the hero's auto-attack — passes through this system: raw attack values arrive as EventBus events, the system applies the appropriate multipliers (elite and boss targets take 150% from the hero, armored targets take 50% from towers, critical hits apply the crit multiplier), and the resolved damage is published back to the EventBus as `monster_damage_taken`, which the Monster System then applies to a target's current HP. The result is one place for all damage arithmetic — a single system to tune, test, and profile regardless of the number of attack sources in the game.

Technically, the system subscribes to three events: `tower_attacked` (tower fires at a monster, carrying pre-resolved `is_armored` flag), `hero_auto_attacked` (hero strikes a monster, carrying base damage and crit flag), and `monster_hp_absorbed` (Monster System confirms how much HP was actually removed — used for lifesteal resolution). `monster_damage_taken` is always deferred one frame after the triggering attack event to respect the EventBus cascade budget. Lifesteal resolution uses `monster_hp_absorbed` rather than the full resolved damage: on overkill hits, heal returns only what the monster actually had, keeping the moment of a finishing blow at "quiet arithmetic" rather than a windfall. At MVP, the system also owns a hero-incoming-damage pipeline (applying the hero's armor coefficient to incoming hits and emitting `hero_damage_taken`), stubbed pending the definition of which game entities will damage the hero. Status effects — burn, slow, poison — are explicitly out of scope for MVP.

The player never sees the Damage & Status System directly, but they feel it on every attack: the snap of a critical hit on an elite, the visible and audible signal when the tier bonus lands on a non-crit hit, the proof that the hero's 150% multiplier turns a dangerous target into a kill within a single skill cycle, the healing tick that confirms — after the hit resolves — exactly what was gained. This system is what gives those moments mathematical integrity.

## Player Fantasy

The feeling is never "I hit hard." It is the moment the elite monster — the one your fire lattice was never going to chew through in time — drops one step earlier than the math said it should, because your hero was the one swinging at it. That single step is the difference between the lane holding and the lane breaking, and you feel it before you see the corpse. The fantasy is the quiet arithmetic of being right: you understood that *this* threat needed *this* answer, and the battlefield just proved it. The damage didn't come from a number getting bigger. It came from the right weapon meeting the right target at the right second.

Sometimes the plan doesn't hold. The pack is already past your chokepoint, the towers are on cooldown, and the boss is three cells from the sanctuary. You throw the hero in — not because you're confident, but because you have nothing else — and the next few hits land like you needed them to. Not a miracle. Not a power fantasy. A conversion. The damage you wring out of a collapsing situation is proof that you were still thinking when the plan stopped thinking for you. That is the fantasy: the calm realization, mid-panic, that you're the one closing this gap, and the hits are going where you're telling them to go.

## Detailed Design

### Core Rules

**I. System Scope**

1. The Damage & Status System is the single authoritative pipeline for all damage applied to **monsters and the hero**. It does not own damage applied to towers — BOSS→Tower direct damage is routed through the Tower System and is a named exception to this scope (see Tower System GDD Rule 18 and Monster GDD Rule 18).
2. At MVP this system owns **four** event subscriptions and two active pipelines: (a) outgoing damage from towers and the hero to monsters, and (b) incoming damage to the hero with armor applied. Incoming hero damage is scaffolded but has no active sources at MVP. The third subscription (`monster_hp_absorbed`) drives lifesteal resolution only — it is not a damage pipeline. The fourth subscription (`wave_completed`) drives `_lifesteal_pending` cleanup — see Rule VII.
3. Status effects (burn, slow, poison) are explicitly out of scope for MVP.
4. The system is nearly stateless. The only cross-event state is `_lifesteal_pending: Dictionary[int, float]` — a map from `target_id` to `hero_lifesteal_fraction`, populated when D&S emits a hero-hit `monster_damage_taken` for a hero with `hero_lifesteal_fraction > 0`, and cleared when the corresponding `monster_hp_absorbed` arrives. All other processing is fully event-independent. Pending `await get_tree().process_frame` coroutines are transient — they exist only within the one-frame deferral window and carry no cross-event state. If the D&S node is freed mid-wave (which must not happen during WAVE_ACTIVE), pending coroutines will attempt to resume on `SceneTree.process_frame` — which outlives the node — and will error. This is prevented by the lifecycle invariant, not by silent cancellation. Add `is_instance_valid(self)` as the first guard after every `await` in the implementation. Pending deferred `monster_damage_taken` events that arrive after `wave_completed` are safely absorbed — the Monster System is idle in that phase and discards them.

**II. Tower Damage Pipeline** (event: `tower_attacked`)

1. Read `damage_amount: float` (aliased `raw_damage` in formulas below), `target_monster_id: int`, and `is_armored: bool` from the event payload. `is_armored` is pre-resolved by the Tower System from the target's `MonsterResource.archetype_tag` at fire time (`true` when `archetype_tag == &"armored"`). D&S never reads monster state directly.
2. Apply armored mitigation if applicable. No other multipliers apply — tower damage has no crit mechanic and no tier-bonus check (`hero_bonus_tier` is a hero-pipeline-only field):
   - If `is_armored == true`: `resolved_damage = raw_damage × 0.50`
   - Else: `resolved_damage = raw_damage`
3. `resolved_damage` is determined by Rule II.2 above.
4. Floor to integer: `final_damage = floor(resolved_damage)`
5. Defer one frame via `await get_tree().process_frame`. Add `is_instance_valid(self)` guard immediately after `await`. Emit `monster_damage_taken` with payload:
   - `entity_id: int` = target_monster_id
   - `amount: int` = final_damage
   - `source_type: int` = 0 (tower)
   - `is_crit: bool` = false
   - `hero_bonus_tier: int` = 0 (tower hits never carry tier bonus)

**III. Hero Auto-Attack Damage Pipeline** (event: `hero_auto_attacked`)

1. Read `base_damage: float`, `is_crit: bool`, `target_id: int`, `crit_multiplier_effective: float`, `hero_lifesteal_fraction: float`, and `hero_bonus_tier: int` from the `HeroAutoAttackEvent` Resource payload. Hero System pre-computes `crit_multiplier_effective` (= `hero_crit_multiplier_base + crit_multiplier_bonus`) and reads the target's archetype tier at attack-roll time before emitting — passing `hero_bonus_tier = 0` for STANDARD, `1` for ELITE, `2` for BOSS. **Follow-up required:** Hero GDD and EventBus GDD must be updated to replace `hero_damage_bonus_eligible: bool` with `hero_bonus_tier: int` in the `HeroAutoAttackEvent` Resource payload.
2. **Tier bonus step** (target vulnerability — applied first):
   - If `hero_bonus_tier > 0` (ELITE or BOSS): `tier_damage = base_damage × hero_damage_bonus_multiplier`
   - Else: `tier_damage = base_damage`
3. **Crit step** (hero execution — applied second):
   - If `is_crit == true`: `crit_damage = tier_damage × crit_multiplier_effective`
   - Else: `crit_damage = tier_damage`
4. `resolved_damage = crit_damage`. Floor to integer: `final_damage = floor(resolved_damage)`
5. **Zero-damage guard:** If `final_damage <= 0`: do not add any entry to `_lifesteal_pending`, do not emit `monster_damage_taken`, return. (Defensive guard only — Hero System's valid input ranges prevent this in normal operation. The guard must execute before lifesteal registration to prevent orphaned dictionary entries.)
6. **Lifesteal registration** (if `hero_lifesteal_fraction > 0`):
   - Store `_lifesteal_pending[target_id] = hero_lifesteal_fraction` before deferring.
   - Lifesteal resolution does NOT fire immediately — it is deferred until `monster_hp_absorbed` is received from the Monster System (see Rule VI). This ensures the heal reflects damage actually dealt, not resolved damage on overkill hits.
7. Defer one frame via `await get_tree().process_frame`. Add `is_instance_valid(self)` guard immediately after `await`. Emit `monster_damage_taken`:
   - `entity_id: int` = target_id, `amount: int` = final_damage
   - `source_type: int` = 1 (hero), `is_crit: bool` = forwarded, `hero_bonus_tier: int` = forwarded

**IV. Deferred Dispatch Rule**

1. `monster_damage_taken` is always emitted one frame after the triggering attack event using `await get_tree().process_frame` (not `call_deferred` — `call_deferred` defers to end-of-current-frame idle time, which is not a guaranteed next-frame boundary). This respects the EventBus cascade budget: D&S must not emit `monster_damage_taken` within the same dispatch cycle as the upstream attack event.
2. `hero_healed` fires synchronously within the `monster_hp_absorbed` handler (Rule VI) — it is not deferred from there. The Monster System processes `monster_damage_taken` and flushes `monster_hp_absorbed` synchronously at end of `_physics_process` (accumulator pattern — see Monster GDD Rule 21.e). Therefore `hero_healed` fires within the same `_physics_process` cycle that processes `monster_damage_taken`, which is the first physics frame after the original attack event. The cascade chain never exceeds depth 2 from `monster_hp_absorbed`: `monster_hp_absorbed` (level 0, flush-point dispatch) → `hero_healed` (level 1) → Hero System HP update (level 2, no further emission).
3. `hero_damage_taken` is deferred one frame from the triggering `hero_incoming_damage` event — same cascade-budget rule as `monster_damage_taken`.

**V. Hero Incoming Damage Pipeline** (stubbed — no MVP sources)

1. When any future source emits `hero_incoming_damage`: `effective_damage = max(1, floor(incoming × (100 / (hero_armor + 100))))`
2. Defer one frame via `await get_tree().process_frame`. Add `is_instance_valid(self)` guard immediately after `await`. Emit `hero_damage_taken` with `amount: int = effective_damage`, `source_type: int` = forwarded from `hero_incoming_damage` payload.
3. At MVP, no game entity is defined as a hero attack source. This pipeline is scaffolding only.

**VI. Lifesteal Resolution** (event: `monster_hp_absorbed`)

1. The Monster System emits `monster_hp_absorbed` (deferred one frame from `monster_damage_taken`) after applying the damage to the target's HP. Payload: `entity_id: int`, `absorbed: int` (actual HP removed — `min(amount_received, pre_hit_hp)`, computed by Monster System).
2. On `monster_hp_absorbed` received: check `_lifesteal_pending[entity_id]`. If not present, ignore — this hit was not a hero lifesteal hit, or the pending entry was already processed.
3. `hero_lifesteal_fraction = _lifesteal_pending[entity_id]`. Remove `entity_id` from `_lifesteal_pending`.
4. `heal_amount = floor(absorbed × hero_lifesteal_fraction)`
5. If `heal_amount > 0`: emit `hero_healed` immediately (synchronous — no `await`) with `amount: int = heal_amount`.
6. If `heal_amount == 0` (due to floor rounding or `absorbed == 0`): suppress `hero_healed` — do not emit a zero-heal event.

Note: At MVP, the hero attacks once per animation cycle. If a future mechanic introduces simultaneous multi-hit on the same target, `_lifesteal_pending[target_id]` would be overwritten by the second hit before the first `monster_hp_absorbed` arrives — an edge case to address if multi-hit is ever added.

**VII. Wave Boundary Cleanup** (event: `wave_completed`)

1. D&S subscribes to `wave_completed` (fourth subscription — see Rule I.2).
2. When `wave_completed` is received, D&S must **drain pending heals before clearing**: defer the clear by one frame to allow any in-flight `monster_hp_absorbed` events (deferred from the final wave frame) to resolve naturally before the dictionary is cleared. This preserves lifesteal heals on the killing blow of a wave. See Rule VII.3 for the exact implementation.
3. Implementation note: the `wave_completed` handler is: `await get_tree().process_frame` (if any `_lifesteal_pending` entries exist) → `_lifesteal_pending.clear()`. If `_lifesteal_pending` is already empty, skip the await and clear immediately.

---

### States and Transitions

The D&S System is nearly event-stateless. `_lifesteal_pending` is the only persistent data structure — it is populated per hero lifesteal hit and cleared on `monster_hp_absorbed` receipt. Every attack event otherwise triggers an independent, self-contained resolution. Pending `await get_tree().process_frame` coroutines are transient — they exist only within the one-frame deferral window.

### Performance Budget

The deferred-dispatch pattern relocates subscriber cost from frame N to frame N+1 — it does not eliminate it. At peak wave load (20 towers firing simultaneously), frame N+1 must absorb 20 sequential `monster_damage_taken` dispatches plus all subscriber work (Monster System HP reduction, Mission HUD floating number spawning, Audio hit sound selection). Per the EventBus cascade budget formula, the permitted total subscriber execution for the `monster_damage_taken` chain is approximately **0.83ms at 20 events** (50% of the EventBus-allocated budget slice — which is 10% of the 16.67ms frame budget, not 50% of the total frame budget). At 20 simultaneous firings, the per-firing budget is approximately **10.4µs across all subscribers combined**. This is tight: Mission HUD floating-number spawning via `Node.add_child()` costs ~10–50µs alone.

**Alpha gate required (two tests):**
1. Peak burst: Sustained 60fps at 20 simultaneous tower attacks confirmed by profiler with all D&S subscribers active.
2. Late-game density: Sustained 60fps at maximum grid tower saturation (≥30 towers) at peak firing rate. Mission HUD floating-number spawn cost must be profiled at this density — it is the most likely frame budget violation point.
Per-subscriber cost estimates are TBD from profiling — document in `production/qa/evidence/` when measured.

**If the spike exceeds budget:** This decision needs full specification before committing to the accumulator pattern: (a) define a new batched event (`monster_damage_taken_batch`) in the EventBus GDD with array payload, (b) update all subscriber contracts (Monster System, Mission HUD, Audio), (c) define the exact frame-time trigger threshold, (d) specify lifesteal interaction with batched payload. Do not implement the accumulator pattern without first making these design decisions explicit.

### Interactions with Other Systems

| System | Direction | Data | Notes |
|--------|-----------|------|-------|
| Hero System | ← upstream | `HeroAutoAttackEvent` payload: `base_damage`, `is_crit`, `target_id`, `crit_multiplier_effective`, `hero_lifesteal_fraction`, `hero_bonus_tier` | Hero System rolls crit and reads target archetype tier before emitting — D&S never rolls RNG or reads monster state directly |
| Tower System | ← upstream | `tower_attacked` (`damage_amount`, `target_monster_id`, `is_siege`, `is_armored`) | Tower System pre-resolves `is_armored` from target's `MonsterResource.archetype_tag` at fire time — D&S never reads monster state directly |
| Monster System | → downstream | `monster_damage_taken` (deferred one frame) | Monster System applies `amount` to target HP |
| Monster System | ← upstream | `monster_hp_absorbed` (`entity_id: int`, `absorbed: int`) | Monster System emits (deferred one frame from `monster_damage_taken`) after HP application — D&S uses to resolve lifesteal |
| Hero System | → downstream | `hero_healed` (fires within Monster System's `_physics_process` flush) | Hero System clamps at max HP — overheal behavior owned by Hero System |
| EventBus | constraint | Cascade budget rule | `monster_damage_taken` must always defer one frame; `hero_healed` fires at cascade depth 1 from `monster_hp_absorbed` (permitted — within 2-level chain rule) |
| Wave Manager | ← upstream | `wave_completed` (no payload fields consumed) | D&S clears `_lifesteal_pending` on receipt — see Rule VII |

**Multiplier summary by source × target:**

| Source | Target | Combined multiplier |
|--------|--------|---------------------|
| Tower | STANDARD / ELITE / BOSS (not armored) | 1.00× |
| Tower | ARMORED (any tier) | 0.50× |
| Hero non-crit | STANDARD | 1.00× |
| Hero non-crit | ELITE / BOSS | 1.50× |
| Hero crit | STANDARD | 1.75× |
| Hero crit | ELITE / BOSS | 2.625× |

> `is_armored` affects tower hits only — hero damage is never reduced by the armored tag. Hero crit multipliers in this table assume `crit_multiplier_effective = 1.75` (base, no bonus) and `hero_damage_bonus_multiplier = 1.50` (default). Maximum `crit_multiplier_effective = 3.25` yields 3.25× vs STANDARD and 4.875× vs ELITE/BOSS. `hero_bonus_tier` in `monster_damage_taken` distinguishes ELITE (1) and BOSS (2) for downstream feedback systems. See Formula D2 for full range.

## Formulas

#### D1 — Tower Damage Resolution

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `raw_damage` | float | 5–200 | Weapon component base damage; read from `tower_attacked` payload field `damage_amount` |
| `is_armored` | bool | — | Pre-resolved by Tower System from target's `archetype_tag`; `true` when `archetype_tag == &"armored"` |
| `final_damage` | int | 2–200 | Damage applied to monster HP via `monster_damage_taken` |

**Expression:**
```
resolved_damage = raw_damage × (armored_mitigation_multiplier if is_armored else 1.0)
final_damage    = floor(resolved_damage)
```

> `armored_mitigation_multiplier` defaults to `0.50` — see Tuning Knobs. Worked examples below use the default value.

**Worked examples** (armored_mitigation_multiplier = 0.50):
- raw_damage = 47.3, is_armored = false → final_damage = 47
- raw_damage = 80.7, is_armored = true → floor(80.7 × 0.50) = floor(40.35) = **40**
- raw_damage = 5.0, is_armored = true → floor(5.0 × 0.50) = floor(2.5) = **2** (minimum possible tower damage on armored target)

---

#### D2 — Hero Damage Resolution

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `base_damage` | float | > 0 | Hero base damage stat from `HeroAutoAttackEvent` payload |
| `hero_bonus_tier` | int | 0–2 | Target tier from `HeroAutoAttackEvent` payload: 0 = STANDARD (no bonus), 1 = ELITE (bonus applies), 2 = BOSS (bonus applies). Hero reads target archetype tier at attack-roll time. |
| `is_crit` | bool | — | Rolled by Hero System before emitting event |
| `crit_multiplier_effective` | float | 1.75–3.25 | Pre-computed by Hero System (`hero_crit_multiplier_base + crit_multiplier_bonus`) — carried in `HeroAutoAttackEvent` payload; D&S never reads crit_multiplier_bonus separately |
| `final_damage` | int | > 0 | Resolved hero damage |

**Expression:**
```
tier_damage  = base_damage × (hero_damage_bonus_multiplier if hero_bonus_tier > 0 else 1.0)
crit_damage  = tier_damage × (crit_multiplier_effective if is_crit else 1.0)
final_damage = floor(crit_damage)
```

> **Note:** `crit_multiplier_effective` is pre-computed by Hero System as `hero_crit_multiplier_base (1.75) + crit_multiplier_bonus (0.0–1.50)`. D&S receives the resolved value in the payload — it does not read `crit_multiplier_bonus` independently. `hero_damage_bonus_multiplier` defaults to `1.50` — see Tuning Knobs. Worked examples below use the default value.

**Multiplier table (base crit only, crit_multiplier_bonus = 0, hero_damage_bonus_multiplier = 1.50):**

| Target | Non-crit | Crit |
|--------|----------|------|
| STANDARD (`hero_bonus_tier = 0`) | 1.00× | 1.75× |
| ELITE (`hero_bonus_tier = 1`) | 1.50× | 2.625× |
| BOSS (`hero_bonus_tier = 2`) | 1.50× | 2.625× |

**Worked examples** (base_damage = 100, crit_multiplier_bonus = 0):

| Scenario | Calculation | final_damage |
|----------|-------------|--------------|
| Non-crit vs STANDARD | 100 × 1.0 × 1.0 | 100 |
| Non-crit vs ELITE | 100 × 1.50 × 1.0 | 150 |
| Crit vs STANDARD | 100 × 1.0 × 1.75 | 175 |
| Crit vs ELITE | 100 × 1.50 × 1.75 | floor(262.5) = **262** |
| Crit (+0.50 bonus) vs ELITE | 100 × 1.50 × 2.25 | floor(337.5) = **337** |
| Crit (max 3.25×) vs ELITE | 100 × 1.50 × 3.25 | floor(487.5) = **487** |

---

#### D3 — Lifesteal Heal Amount

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `absorbed` | int | 0–unbounded | Actual HP removed from the target, as emitted by Monster System in `monster_hp_absorbed`. Equals `min(final_damage, pre_hit_hp)`. |
| `hero_lifesteal_fraction` | float | 0.0–0.40 | Hero's effective lifesteal, capped at `hero_lifesteal_cap` (0.40) |
| `heal_amount` | int | 0–unbounded | HP returned to hero (Hero System clamps at max HP) |

**Expression:**
```
heal_amount = floor(absorbed × hero_lifesteal_fraction)
```

Notes: Uses `absorbed` (actual HP removed) rather than `final_damage` (resolved damage before overkill cap). On overkill hits, lifesteal is limited to HP the monster actually had — not the full resolved damage. `heal_amount` CAN be 0 due to floor rounding; no minimum is enforced. Formula does not apply if `hero_lifesteal_fraction == 0`.

**Worked examples:**

| Scenario | `absorbed` | Calculation | heal_amount |
|----------|------------|-------------|-------------|
| 262 dmg, 20% lifesteal, target had 300 HP (no overkill) | 262 | floor(262 × 0.20) | **52** |
| 487 dmg, 40% lifesteal, target had 80 HP (overkill) | 80 | floor(80 × 0.40) | **32** (not 194) |
| 100 dmg, 40% lifesteal (cap), target had 100 HP | 100 | floor(100 × 0.40) | **40** |
| 2 dmg, 10% lifesteal, target had 10 HP | 2 | floor(2 × 0.10) = floor(0.20) | **0** (valid) |

---

#### D4 — Hero Incoming Damage (Armor Reduction)

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `incoming` | float | > 0 | Raw damage from the attacking source |
| `hero_armor` | float | 0–1000+ | Hero's current armor stat |
| `hero_armor_coefficient` | int | 100 | Armor formula constant (registry, hero.md) |
| `effective_damage` | int | ≥ 1 | Damage applied to hero HP |

**Expression:**
```
hero_armor_clamped = max(0.0, hero_armor)
effective_damage   = max(1, floor(incoming × (100 / (hero_armor_clamped + 100))))
```

> The `max(0.0, hero_armor)` clamp prevents division by zero if armor reaches a negative value (invalid stat — Hero System should never produce this, but D&S guards defensively). At clamped armor=0, the hero takes 100% of incoming damage.

**Damage taken at key armor values:**

| Armor | % damage taken | Incoming 50 → effective |
|-------|---------------|------------------------|
| 0 | 100% | 50 |
| 100 | 50% | 25 |
| 200 | 33% | 16 (`floor(50 × 100/300) = floor(16.67) = 16`) |
| 500 | 17% | 9 |
| 1000 | 9% | 5 |

---

#### Event Payload: `monster_damage_taken` (resolves Monster GDD OQ-4)

```
monster_damage_taken:
  entity_id: int        # runtime entity ID of the targeted monster
  amount: int           # resolved damage (≥ 1 in practice; never emitted for 0-damage hits)
  source_type: int      # 0 = tower, 1 = hero
  is_crit: bool         # true if crit multiplier was applied
  hero_bonus_tier: int  # 0 = no tier bonus; 1 = ELITE tier bonus applied; 2 = BOSS tier bonus applied
                        # always 0 for tower hits (source_type = 0)
```

Guard: if `final_damage <= 0` after flooring, the event is not emitted. This should not occur given non-zero weapon and base damage stats; it is a sanity guard only.

## Edge Cases

**EC-1: Hero crit on STANDARD monster (no tier bonus, crit still applies)**
A `hero_auto_attacked` event with `is_crit=true` targeting a STANDARD monster (`hero_bonus_tier=0`) resolves as: `final_damage = floor(base_damage × 1.75)`. The tier bonus step is skipped (`hero_bonus_tier == 0`); crit applies to the raw base damage only. This is the intended behavior.

**EC-2: Tower targets ELITE or BOSS (non-armored)**
`hero_bonus_tier` is read only in the hero pipeline; the tower pipeline has no tier-bonus logic. Tower damage resolves as `floor(raw_damage × mitigation_factor)` regardless of target tier — `is_armored` is the only tower-pipeline flag. A non-armored tower hit on a BOSS applies no tier multiplier. `monster_damage_taken.hero_bonus_tier = 0` for all tower hits.

**EC-3: Lifesteal on overkill hit — capped at actual absorbed damage**
Hero deals 300 resolved damage (`final_damage=300`) to a monster with 50 HP remaining. The `monster_damage_taken` event carries `amount=300`. The Monster System applies 50 HP reduction (all that remains), emits `monster_hp_absorbed` with `absorbed=50`. D&S receives it and computes: `heal_amount = floor(50 × hero_lifesteal_fraction)`. At 20% lifesteal: `heal_amount = 10`. The hero heals for 10, not 60. This is the correct behavior — lifesteal on overkill is limited to HP actually removed, not the full resolved damage.

**EC-4: Lifesteal heal of 0 — event suppressed at source**
`absorbed=2`, `hero_lifesteal_fraction=0.10`: `floor(0.20) = 0`. D&S suppresses `hero_healed` — the event is NOT emitted. Emitting a zero-heal event adds bus noise with no gameplay effect. The Hero System receives no event for this hit. This aligns with the EventBus GDD contract: `hero_healed` fires only when `heal_amount > 0`.

**EC-5: `crit_multiplier_effective` at maximum**
`crit_multiplier_effective=3.25` (Hero System pre-computes: `1.75 base + 1.50 max bonus`). A crit on an ELITE target with base_damage=100: `floor(100 × hero_damage_bonus_multiplier × 3.25)` = `floor(100 × 1.50 × 3.25) = floor(487.5) = 487` (at default hero_damage_bonus_multiplier=1.50). This is the maximum output of Formula D2 for a given base_damage. Equipment Forge GDD must ensure no equipment combination can produce `crit_multiplier_effective > 3.25`. D&S does not re-clamp this value — it trusts Hero System pre-validation. Note: at max crit chance (80%) the expected DPS vs ELITE/BOSS (2.40× of base_damage) always exceeds expected DPS vs STANDARD (1.60× of base_damage) at any crit rate — the hero's tier bonus applies to crit and non-crit hits alike, so ELITE/BOSS are always the hero's superior DPS targets.

**EC-6: `hero_damage_taken` minimum enforcement**
`incoming=5`, `hero_armor=1000`: `floor(5 × 100/1100) = floor(0.454) = 0`. The `max(1, ...)` guard fires; `effective_damage = 1`. This is the minimum possible hero incoming damage — armor cannot fully negate a hit. The Hero System will receive a `hero_damage_taken` event with `amount=1`.

**EC-7: `monster_damage_taken` emitted for a dead monster**
The monster dies in frame N to a previous hit. In frame N+1, a deferred `monster_damage_taken` event arrives for the same entity. The Monster System is responsible for ignoring events targeting entities with `hp <= 0` or entities that no longer exist. D&S emits the event without checking monster HP state — it has no visibility into monster HP at emit time. When Monster System discards the event, no `monster_hp_absorbed` is emitted for that entity_id. D&S will retain an entry in `_lifesteal_pending[entity_id]` for that hit. This is safe: the orphaned entry persists until wave end, then is cleared with `_lifesteal_pending.clear()` during the `wave_completed` handler. `hero_healed` is not emitted for the orphaned entry.

**EC-8: Multiple simultaneous attacks in the same frame**
Ten tower attacks fire in frame N. Each generates an independent `monster_damage_taken` deferred to frame N+1. All ten events arrive in frame N+1. The Monster System applies them sequentially in receive order. D&S has no batching logic — it processes each attack event independently. If total deferred events per frame exceeds `eventbus_batch_threshold` (20), the obligation to switch to batched dispatch falls on the **Tower System** — which knows its own firing rate per frame. D&S is event-stateless across tower attacks and cannot track a per-frame count. Ten tower events in one frame is within threshold.

**EC-9: Hero attacks while lifesteal is at cap**
`hero_lifesteal_fraction` is already equal to `hero_lifesteal_cap` (0.40). No special case — the cap is enforced upstream by the Hero System before the stat is passed. D&S always receives a value in [0.0, 0.40]; it does not re-clamp.

**EC-10: Hero incoming damage pipeline with no sources (MVP)**
No game entity emits `hero_incoming_damage` at MVP. The pipeline exists as scaffolding. If the event is somehow emitted (test harness, future system), the formula executes correctly. D&S does not guard against receiving this event — it will process it.

**EC-11: Tower hits an armored target**
A `tower_attacked` event with `is_armored=true` and `damage_amount=80.7` resolves as: `floor(80.7 × 0.50) = floor(40.35) = 40`. The `monster_damage_taken` event carries `amount=40`, `source_type=0`, `hero_bonus_tier=0` — the armored mitigation is tower-only and produces no tier-bonus visual indicator. A hero hitting the same armored target in the same wave will NOT have `is_armored` applied to their damage — `is_armored` is read only in the tower pipeline.

**EC-12: Hero hits an armored target**
`is_armored` is not a field in `HeroAutoAttackEvent` and is not read in the hero pipeline (Rule III). A hero crit on an armored ELITE with base_damage=100 and `crit_multiplier_effective=1.75` resolves as: `floor(100 × hero_damage_bonus_multiplier × 1.75) = floor(100 × 1.50 × 1.75) = 262` (at default `hero_damage_bonus_multiplier=1.50`). The 50% armored mitigation does not apply. Hero damage is never reduced by the armored tag — this is by design (the hero's strategic value against elite targets is preserved regardless of armor). `monster_damage_taken.hero_bonus_tier = 1` for this hit.

**EC-13: Hero armor value is negative (invalid stat)**
`hero_armor` is invalid if negative — the Hero System should never produce this value, but D&S applies a defensive clamp before Formula D4. Example: `hero_armor = -50`. Clamped: `hero_armor_clamped = max(0.0, -50) = 0.0`. Formula: `max(1, floor(incoming × (100 / 100))) = incoming` (100% damage taken, no mitigation). The clamp prevents division by zero (which would occur at `hero_armor = -100`) and ensures the formula degrades gracefully to full-damage passthrough rather than crashing.

## Dependencies

#### Systems this GDD depends on

| System | GDD | What D&S requires |
|--------|-----|-------------------|
| EventBus System | `design/gdd/event-bus.md` | All inter-system communication. D&S subscribes to `tower_attacked`, `hero_auto_attacked`, `monster_hp_absorbed`, and `wave_completed`; emits `monster_damage_taken` (deferred) and `hero_healed` (synchronous from `monster_hp_absorbed` handler). Cascade budget rule: `monster_damage_taken` must defer one frame. `hero_healed` is a permitted synchronous emission at cascade depth 1 from `monster_hp_absorbed` (within the 2-level chain rule — no exemption needed). **Follow-up required:** EventBus GDD must be updated to (a) confirm `is_armored: bool` is in the `tower_attacked` payload, (b) confirm `monster_hp_absorbed` is in the event catalogue with payload `entity_id: int`, `absorbed: int`, and (c) update `HeroAutoAttackEvent` Resource payload to replace `hero_damage_bonus_eligible: bool` with `hero_bonus_tier: int`. |
| Hero System | `design/gdd/hero.md` | Emits `HeroAutoAttackEvent` Resource carrying `base_damage`, `is_crit`, `target_id`, `crit_multiplier_effective` (pre-computed), `hero_lifesteal_fraction` (pre-clamped to `hero_lifesteal_cap`), and `hero_bonus_tier` (read from target archetype tier at attack-roll time: 0=STANDARD, 1=ELITE, 2=BOSS). Owns the crit roll and target-tier check — D&S never rolls RNG or reads monster state. Receives `hero_healed` and owns overheal clamping behavior. **Follow-up required:** Hero GDD must be updated to replace `hero_damage_bonus_eligible: bool` with `hero_bonus_tier: int` in the `HeroAutoAttackEvent` payload definition and in the attack-roll emission logic. |
| Tower System | `design/gdd/tower.md` | Emits `tower_attacked` with `damage_amount`, `target_monster_id`, `is_siege`, and `is_armored`. Tower System reads the target's `MonsterResource.archetype_tag` at fire time and pre-resolves `is_armored` — D&S never reads monster state directly. **Follow-up required:** Tower System GDD must be updated to document this `archetype_tag` read and the `is_armored` flag. |
| Monster System | `design/gdd/monster.md` | Receives `monster_damage_taken` (deferred) and applies `amount` to target HP. Owns dead-monster guard (ignores events for entities with `hp <= 0`). **Emits `monster_hp_absorbed`** (deferred one frame from receiving `monster_damage_taken`) with `entity_id: int` and `absorbed: int` — the actual HP removed, capped at pre-hit HP. D&S subscribes to this event for lifesteal resolution. When Monster System discards a `monster_damage_taken` event (dead entity), it must NOT emit `monster_hp_absorbed` for that entity_id. **Follow-up required:** Monster System GDD must be updated to document `monster_hp_absorbed` emission. |

#### Systems that depend on this GDD

| System | GDD | What they consume from D&S |
|--------|-----|---------------------------|
| Monster System | `design/gdd/monster.md` | `monster_damage_taken` event — applies `amount` to target HP each frame |
| Hero System | `design/gdd/hero.md` | `hero_healed` event — applies `amount` to hero HP |
| Wave Manager | Not yet designed | May subscribe to `monster_damage_taken` for damage-dealt tracking and kill attribution |
| Mission HUD | Not yet designed | Subscribes to `monster_damage_taken` for floating damage numbers; uses `is_crit` and `hero_bonus_tier` fields to style the display |
| Audio System | Not yet designed | Subscribes to `monster_damage_taken.is_crit` and `source_type` for hit sound selection |
| Equipment Forge | Not yet designed | Must respect `crit_multiplier_bonus` maximum of 1.50 (cap defined in Formula D2) |

#### Bidirectionality notes

- Monster GDD must be updated to reference D&S as the owner of `monster_damage_taken` (this resolves Monster GDD OQ-4) and to document `monster_hp_absorbed` emission after HP application.
- Hero GDD must be updated to reference D&S as the owner of `hero_healed` and the lifesteal resolution formula (D3), and to replace `hero_damage_bonus_eligible: bool` with `hero_bonus_tier: int` in `HeroAutoAttackEvent`.
- EventBus GDD must be updated to confirm `monster_hp_absorbed` in the event catalogue, confirm `is_armored: bool` in `tower_attacked` payload, update `HeroAutoAttackEvent` payload to `hero_bonus_tier: int`, and update `monster_damage_taken` payload to `hero_bonus_tier: int` replacing `hero_bonus_applied: bool`.
- Tower System GDD must be updated to document the `archetype_tag` read and `is_armored` forwarding.
- Wave Manager GDD must note that D&S subscribes to `wave_completed` for `_lifesteal_pending` cleanup.

## Tuning Knobs

All knobs must be data-driven (no hardcoded values in GDScript). Safe ranges indicate values outside which gameplay breaks in a known way.

| Knob | Owner | Default | Safe Range | Gameplay Effect |
|------|-------|---------|-----------|-----------------|
| `hero_damage_bonus_multiplier` | D&S (this GDD) | 1.50 | 1.25–2.00 | Multiplies hero damage against ELITE and BOSS targets. Below 1.25: the hero advantage over tower damage becomes imperceptible, undermining "you were the one closing this gap." Above 2.00: hero one-shots ELITE targets consistently — the decision to engage feels trivial rather than calculated. |
| `armored_mitigation_multiplier` | D&S (this GDD) | 0.50 | 0.25–0.75 | Fraction of tower damage that reaches armored targets. Below 0.25: tower damage vs armored is negligible — towers become irrelevant against armored waves. Above 0.75: armored tag provides no meaningful strategic signal — towers and heroes are interchangeable against armored targets. |
| `hero_crit_multiplier_base` | Hero GDD | 1.75 | 1.50–2.50 | Base damage multiplier on crit. Tuned in Hero GDD; D&S reads it. A higher base makes individual crits more decisive; too high and non-crit builds feel broken. |
| `hero_lifesteal_cap` | Hero GDD | 0.40 | 0.25–0.60 | Maximum fraction of absorbed damage returned as HP. Tuned in Hero GDD; D&S reads it. Below 0.25: lifesteal becomes a rounding error — irrelevant in real combat. Above 0.60: lifesteal trivialises sustain; hero can outlast any encounter without positioning skill. |
| `hero_armor_coefficient` | Hero GDD | 100 | 50–200 | Armor value at which hero takes exactly 50% of incoming damage. Tuned in Hero GDD; D&S reads it. Lower values make armor more powerful per unit; higher values require more armor investment for the same mitigation. |
| `hero_incoming_damage_minimum` | D&S constant | 1 | fixed | Minimum effective damage the hero can receive from any single hit, regardless of armor. Not a tuning variable — fixed at 1 to prevent armor from fully negating hits. |

## Visual/Audio Requirements

D&S does not own any visual or audio assets — it exposes metadata via `monster_damage_taken` that enables downstream systems to implement contextual feedback.

**What D&S exposes for V/A systems:**

| Field | Value | V/A Use |
|-------|-------|---------|
| `amount` | int | Floating damage number magnitude |
| `source_type` | 0=tower, 1=hero | Distinct hit VFX and impact sounds per source |
| `is_crit` | bool | Crit hit VFX (screen flash, particle burst) and heavier impact audio |
| `hero_bonus_tier` | 0=none, 1=ELITE, 2=BOSS | **Required MVP**: distinct visual indicator + secondary feedback element for tier bonus hits (values 1 and 2). BOSS (2) should use a stronger variant than ELITE (1) — see requirements below |

**Requirements for downstream V/A systems:**

- A crit hit (`is_crit=true`) must be visually and audibly distinguishable from a non-crit hit in all circumstances. The player must be able to recognize a crit without reading the damage number.
- A tower hit and a hero hit on the same target must sound different.
- **`hero_bonus_tier > 0` requires two independent feedback channels at MVP:**
  - **Floating number:** a visually distinct indicator (color, border, or icon) — form is Art Direction's decision. BOSS hits (`hero_bonus_tier = 2`) should use a stronger visual variant than ELITE hits (`hero_bonus_tier = 1`).
  - **Secondary feedback:** an audio pitch shift OR distinct particle color that fires independently of the floating number. The player must be able to perceive the tier bonus during combat without reading the damage number. The Player Fantasy ("the elite drops because you were the one swinging at it") requires this bonus to be *felt*, not merely *visible*.
  - Both channels are required at MVP. Deferring either to polish risks shipping a pillar promise that players do not experience.
  - **QA verification:** Both channels must be confirmed present (screenshot + audio clip evidence filed in `production/qa/evidence/`) at Mission HUD integration milestone. Art Director must sign off on visual distinctiveness before MVP sign-off.
- `hero_healed` drives a green healing tick on the hero HP bar. The tick appears when `hero_healed` fires — which is within the Monster System's `_physics_process` flush following the attack event. The visual latency relative to the hit is within one physics frame (acceptable at 60fps).

**MVP audio scope:** Crit sounds and hero hit sounds are in scope for MVP. Tower hit sounds are deferred to Alpha (consistent with Monster GDD audio scope decision).

## UI Requirements

D&S does not own any UI widgets directly. It is the source system for floating damage numbers.

**Floating damage number requirements (owned by Mission HUD GDD):**

- Every `monster_damage_taken` event must produce a floating damage number at the target's world position.
- `is_crit=true`: number is larger, distinct color (not defined here — owned by Art Direction).
- `hero_bonus_tier = 1` (ELITE): number must carry a visually distinct indicator at MVP (e.g., ELITE-colored border, icon, or distinct color). **Required at MVP** — see Visual/Audio Requirements section for rationale. Not optional.
- `hero_bonus_tier = 2` (BOSS): number must carry a stronger visual variant than ELITE. **Required at MVP.** The boss encounter is the design's climactic scenario — the feedback must distinguish it.
- `source_type=0` (tower) vs `source_type=1` (hero): numbers may use different base colors to distinguish damage sources at a glance. Optional at MVP.
- Simultaneous hits on the same target (EC-8) should stagger floating numbers to avoid overlap.

## Acceptance Criteria

All criteria are verifiable via GUT unit tests or a controlled test harness. Pass/fail is binary.

**AC-1: Tower damage pipeline — basic resolution**
GIVEN a `tower_attacked` event with `damage_amount=47.3`, `target_monster_id=99`, `is_armored=false`, `is_siege=false`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=99`, `amount=47`, `source_type=0`, `is_crit=false`, `hero_bonus_tier=0`

**AC-2: Tower damage pipeline — armored mitigation**
GIVEN a `tower_attacked` event with `damage_amount=80.7`, `target_monster_id=42`, `is_armored=true`, `is_siege=false`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=42`, `amount=40` (`floor(80.7 × 0.50) = floor(40.35) = 40`), `source_type=0`, `is_crit=false`, `hero_bonus_tier=0`

**AC-3: Tower damage pipeline — ELITE/BOSS target with no tier multiplier**
GIVEN a `tower_attacked` event with `damage_amount=80.7`, `target_monster_id=42`, `is_armored=false`, `is_siege=false`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=42`, `amount=80`, `source_type=0`, `is_crit=false`, `hero_bonus_tier=0`
NOTE: This scenario represents a tower firing at an ELITE monster. The tower pipeline reads only `damage_amount` from the event payload — it has no access to monster tier and applies no tier multiplier. `hero_bonus_tier=0` on all tower hits regardless of target archetype.

**AC-4: Hero damage pipeline — non-crit vs STANDARD**
GIVEN a `HeroAutoAttackEvent` with `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=0`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=99`, `amount=100`, `source_type=1`, `is_crit=false`, `hero_bonus_tier=0`
AND `hero_healed` is NOT emitted

**AC-5: Hero damage pipeline — non-crit vs ELITE**
GIVEN a `HeroAutoAttackEvent` with `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=1`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=99`, `amount=150`, `source_type=1`, `is_crit=false`, `hero_bonus_tier=1`
AND `hero_healed` is NOT emitted

**AC-6: Hero damage pipeline — crit vs ELITE**
GIVEN a `HeroAutoAttackEvent` with `base_damage=100`, `is_crit=true`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=1`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=99`, `amount=262`, `source_type=1`, `is_crit=true`, `hero_bonus_tier=1`
AND `hero_healed` is NOT emitted

**AC-7: Hero damage pipeline — crit vs STANDARD**
GIVEN a `HeroAutoAttackEvent` with `base_damage=100`, `is_crit=true`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=0`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=99`, `amount=175`, `source_type=1`, `is_crit=true`, `hero_bonus_tier=0`
AND `hero_healed` is NOT emitted

**AC-8: Lifesteal — standard case (no overkill)** *(Integration test — requires live SceneTree + Monster System)*
GIVEN a `HeroAutoAttackEvent` with `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=1`, `hero_lifesteal_fraction=0.20`, `target_id=99`
AND a live monster entity at entity_id=99 is seeded with `current_hp=300` via Monster System test helper before the hit (no overkill; absorbed=150)
NOTE: Monster System test API for HP seeding is TBD — specify in Monster System GDD test section.
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=99`, `amount=150`
AND when Monster System processes `monster_damage_taken` and emits `monster_hp_absorbed` with `entity_id=99`, `absorbed=150`
THEN `hero_healed` is emitted with `amount=30` (`floor(150 × 0.20) = 30`)
AND `hero_healed` fires within the same `_physics_process` flush as `monster_hp_absorbed`

**AC-9: Lifesteal — zero heal is suppressed** *(Integration test — requires live SceneTree + Monster System)*
GIVEN a `HeroAutoAttackEvent` with `base_damage=2`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=0`, `hero_lifesteal_fraction=0.10`, `target_id=99`
AND a live monster entity at entity_id=99 is seeded with `current_hp=10` via Monster System test helper (no overkill; absorbed=2)
WHEN D&S processes the attack and `monster_hp_absorbed` is dispatched by Monster System with `entity_id=99`, `absorbed=2`
THEN `hero_healed` is NOT emitted — zero-heal events are suppressed (`floor(2 × 0.10) = 0`)
AND no `hero_healed` listener receives any call during this test

**AC-10: `monster_damage_taken` is deferred one frame** *(Integration test — requires live SceneTree)*
GIVEN a `tower_attacked` event with `damage_amount=50.0`, `target_monster_id=99`, `is_armored=false` fires in frame N
AND the test subscriber records `Engine.get_frames_drawn()` each time `monster_damage_taken` is received
WHEN D&S processes it
THEN `monster_damage_taken` is received at frame N+1 (verified by frame counter at subscribe time)

**AC-11: Lifesteal — overkill capped at absorbed** *(Integration test — requires live SceneTree + Monster System)*
GIVEN a `HeroAutoAttackEvent` with `base_damage=300`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=0`, `hero_lifesteal_fraction=0.20`, `target_id=99` (resolves to `final_damage=300`)
AND a live monster entity at entity_id=99 is seeded with `current_hp=50` via Monster System test helper (overkill; absorbed=50)
NOTE: Monster System test API for HP seeding is TBD — specify in Monster System GDD test section.
WHEN D&S processes the attack and Monster System processes `monster_damage_taken`, reducing HP from 50 to 0, and emits `monster_hp_absorbed` with `entity_id=99`, `absorbed=50`
THEN `hero_healed` is emitted with `amount=10` (`floor(50 × 0.20) = 10`) — NOT `amount=60` (which would be the pre-cap calculation on full 300 damage)
AND `monster_damage_taken.amount = 300` (the full resolved damage is emitted; absorbed cap is Monster System's job)

**AC-12: Lifesteal — hero_healed fires within Monster System's physics flush, after monster_damage_taken** *(Integration test — requires live SceneTree + Monster System)*
GIVEN a `HeroAutoAttackEvent` with `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=1`, `hero_lifesteal_fraction=0.20`, `target_id=99`
AND a live monster entity at entity_id=99 is seeded with `current_hp=300` via Monster System test helper
WHEN D&S processes the attack
THEN `monster_damage_taken` is emitted (deferred one idle frame from attack event)
AND `hero_healed` fires within the `_physics_process` cycle in which Monster System processes `monster_damage_taken` — this cycle is distinct from the idle frame in which `monster_damage_taken` was dispatched
AND `hero_healed` must NOT fire before `monster_damage_taken` has been dispatched (ordering constraint — `hero_healed` depends on the round-trip)

**AC-13: Armor reduction — standard case**
GIVEN `hero_incoming_damage` with `incoming=50.0`, `hero_armor=100`, `source_type=7`
WHEN D&S processes it
THEN `hero_damage_taken` is emitted with `amount=25`, `source_type=7` (forwarded unchanged)

**AC-14: Armor reduction — minimum 1 enforcement**
GIVEN `hero_incoming_damage` with `incoming=5`, `hero_armor=1000`, `source_type=2`
WHEN D&S processes it
THEN `hero_damage_taken` is emitted with `amount=1` (not 0), `source_type=2` (forwarded)

**AC-15: No event emitted for zero tower damage**
GIVEN `tower_attacked` with `damage_amount=0.4`, `target_monster_id=99`, `is_armored=false` producing `floor(0.4)=0`
(note: `damage_amount=0.4` is below Tower System's valid range — this is a defensive guard test)
WHEN D&S processes it
THEN no `monster_damage_taken` event is emitted

**AC-16: Hero damage pipeline — max crit path**
GIVEN a `HeroAutoAttackEvent` with `base_damage=100`, `is_crit=true`, `crit_multiplier_effective=3.25` (maximum: 1.75 base + 1.50 max bonus), `hero_bonus_tier=1`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken.amount = 487` (`floor(100 × 1.50 × 3.25) = floor(487.5) = 487`), `is_crit=true`, `hero_bonus_tier=1`

**AC-17: Lifesteal at zero fraction — event suppressed**
GIVEN a `HeroAutoAttackEvent` with `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=0`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `hero_healed` is NOT emitted (the lifesteal branch is skipped entirely when `hero_lifesteal_fraction == 0`)
AND no entry is added to `_lifesteal_pending` for target_id=99

**AC-18a: `hero_bonus_tier` forwarded correctly — ELITE hit**
GIVEN a `HeroAutoAttackEvent` with `hero_bonus_tier=1` (ELITE), `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken.hero_bonus_tier = 1`

**AC-18b: `hero_bonus_tier` forwarded correctly — STANDARD hit**
GIVEN a `HeroAutoAttackEvent` with `hero_bonus_tier=0` (STANDARD), `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken.hero_bonus_tier = 0`

**AC-18c: `hero_bonus_tier` is always 0 for tower hits**
GIVEN any `tower_attacked` event (regardless of target tier or `is_armored` value)
WHEN D&S processes it
THEN `monster_damage_taken.hero_bonus_tier = 0`

**AC-18d: `hero_bonus_tier` forwarded correctly — BOSS hit**
GIVEN a `HeroAutoAttackEvent` with `hero_bonus_tier=2` (BOSS), `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken.hero_bonus_tier = 2`
AND `monster_damage_taken.amount = 150` (same 1.50× multiplier as ELITE — BOSS and ELITE share the multiplier but are distinguished in the payload for downstream feedback)

**AC-19: `hero_damage_taken` is deferred one frame** *(Integration test — requires live SceneTree)*
GIVEN `hero_incoming_damage` with `incoming=50.0`, `hero_armor=0`, `source_type=1` fires in frame N
AND the test subscriber records `Engine.get_frames_drawn()` on `hero_damage_taken` receipt
WHEN D&S processes it
THEN `hero_damage_taken` is received at frame N+1, not frame N

**AC-20: No event emitted for zero hero damage (defensive guard)**
GIVEN a `HeroAutoAttackEvent` with `base_damage=0.4`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_bonus_tier=0`, `hero_lifesteal_fraction=0.0`, `target_id=99`
(resolves to `floor(0.4 × 1.0 × 1.0) = 0`)
WHEN D&S processes it
THEN no `monster_damage_taken` event is emitted
AND no entry is added to `_lifesteal_pending`
NOTE: `base_damage=0.4` is below Hero System's valid range — this is a defensive guard test against malformed upstream input. The zero-damage guard must fire BEFORE lifesteal registration to prevent orphan dictionary entries.

**AC-21: `hero_bonus_tier` visual indicator — D&S emits correctly** *(Boundary test — D&S responsibility only)*
GIVEN a `HeroAutoAttackEvent` with `hero_bonus_tier=1` (ELITE), `base_damage=100`, `is_crit=false`, `crit_multiplier_effective=1.75`, `hero_lifesteal_fraction=0.0`, `target_id=99`
WHEN D&S processes it
THEN `monster_damage_taken.hero_bonus_tier = 1` — D&S's responsibility ends here
NOTE: The downstream visual indicator (floating number style + secondary audio/particle feedback for ELITE and BOSS) is verified in Mission HUD GDD when authored. That AC requires screenshot evidence and Art Director sign-off.

**AC-22: `is_instance_valid(self)` lifecycle guard — no crash on freed node** *(Integration test — requires live SceneTree)*
GIVEN a `tower_attacked` event is received by D&S in frame N and a deferred coroutine is in-flight
AND the D&S node is freed before frame N+1 (test setup: free the node after event dispatch but before next frame)
WHEN the deferred coroutine attempts to resume in frame N+1
THEN no error is emitted, no crash occurs, and no `monster_damage_taken` event is dispatched
NOTE: This test validates that `is_instance_valid(self)` guard fires correctly and returns early. The lifecycle invariant prevents this during normal WAVE_ACTIVE gameplay — this is a regression guard.

**AC-23: `wave_completed` clears `_lifesteal_pending`** *(Integration test — requires live SceneTree + Monster System)*
GIVEN a `HeroAutoAttackEvent` is processed and creates a `_lifesteal_pending` entry for target_id=99
AND no `monster_hp_absorbed` arrives for entity_id=99 before `wave_completed` fires (simulating an orphaned entry)
WHEN `wave_completed` is dispatched
AND one frame passes (allowing the deferred clear in Rule VII)
THEN `_lifesteal_pending` is empty (no entries remain)
AND no `hero_healed` event is emitted for the orphaned entry
NOTE: Tests the Rule VII cleanup path. Verifies cross-wave state does not leak.

**AC-24: Hero incoming damage — negative armor clamped to zero**
GIVEN `hero_incoming_damage` with `incoming=50.0`, `hero_armor=-50`, `source_type=3`
WHEN D&S processes it
THEN `hero_armor` is clamped to `0.0` before formula evaluation
AND `hero_damage_taken` is emitted with `amount=50` (`max(1, floor(50 × 100/100)) = 50`), `source_type=3` (forwarded)
NOTE: Validates EC-13 defensive clamp. A negative armor value must not crash (division by zero at armor=-100) and must degrade to full-damage passthrough, not mitigation.

## Open Questions

**OQ-1: RESOLVED** — `hero_auto_attacked` payload extended to `HeroAutoAttackEvent` Resource subclass (6 fields: `base_damage`, `is_crit`, `target_id`, `crit_multiplier_effective`, `hero_lifesteal_fraction`, `hero_bonus_tier`). `hero_bonus_tier` replaces the former `hero_damage_bonus_eligible: bool` — Hero System reads target archetype tier at attack-roll time and passes 0/1/2 (STANDARD/ELITE/BOSS). D&S has no direct read dependency on Hero System state — all inputs arrive via the event payload. `event-bus.md` and `hero.md` must be updated to reflect the updated payload (tracked in Dependencies follow-up notes).

**OQ-2: RESOLVED** — All three events (`hero_healed`, `hero_incoming_damage`, `hero_damage_taken`) are present in `design/gdd/event-bus.md` as of the 2026-04-25 EventBus update. `hero_auto_attacked` payload was updated to reflect the 6-field `HeroAutoAttackEvent` Resource.

**OQ-3: RESOLVED** — Lifesteal overkill now uses `absorbed` (actual HP removed, from `monster_hp_absorbed`) rather than `final_damage`. A killing blow on a near-dead monster heals the hero for HP actually taken from that monster, not the full resolved damage. This preserves the "quiet arithmetic" Player Fantasy at the moment of a killing hit. The round-trip adds one frame of heal latency (N+2 instead of immediate), accepted as a reasonable trade-off. Monster System is responsible for emitting `monster_hp_absorbed` after every `monster_damage_taken` it processes (except discarded events for dead entities).

**OQ-4: RESOLVED** — `monster_damage_taken` payload defined in Formula section of this document.
