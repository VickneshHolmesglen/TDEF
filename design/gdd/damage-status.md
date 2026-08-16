# Damage & Status System

> **Status**: Revised (post-re-review — pending re-review)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-15
> **Amendment (2026-08-13)**: Rule I.3's "status effects... out of scope for MVP" is narrowed — burn and poison are now in scope (content already existed unconsumed on `firebolt_turret`/`venomdart_turret`'s Power components; `frostbolt_turret`'s "slow" remains out of scope, unchanged). New Formula D5 (Status Effect DoT Tick Damage), Rule I.1's exception list gains a second named exception (alongside BOSS→Tower), new Edge Cases EC-14/EC-15, new Tuning Knob `status_tick_interval`, new ACs. **Ownership note**: tick damage is resolved directly by Monster System (ADR-0006's 4-pass architecture amended to 5 passes — see that ADR's own Amendment section), not routed through D&S — Power component effects have no armored mitigation, crit, or tier-bonus multiplier to apply, so there is no multiplier logic for D&S to own, and D&S's Rule I.4 "nearly stateless" design principle would be broken by per-monster multi-second timer state. This is architecturally identical in shape to the existing BOSS→Tower named exception (Rule I.1).
> **Amendment (2026-08-13, same day, follow-up)**: `frostbolt_turret`'s "slow" is now also in scope — Rule I.3 no longer names it as the sole remaining excluded effect. New Formula D6 (Slow Effect Speed Multiplier), new Edge Cases EC-16/EC-17, new Tuning Knob `speed_multiplier_floor`, new ACs. Same ownership note as burn/poison: Monster System resolves it directly, not D&S. **Mechanically distinct from D5**: slow has no ticks — it's a continuous multiplier on `MonsterEntity.scaled_speed` (read fresh every movement-pass frame via a new `_effective_speed()` helper, never applied by mutating `scaled_speed` itself, which stays immutable after spawn per ADR-0006). Multiple simultaneous slow instances on one monster combine **multiplicatively** (a user design decision, made explicitly before implementation): two 15% slows yield `0.85 × 0.85 = 72.25%` of original speed, not a summed 30% reduction — this structurally prevents effective speed from ever reaching zero or negative regardless of stack count, with no separate clamp needed at the combination site.
> **Amendment (2026-08-16, Tower Stats System Phase 1, player-requested)**: Formula D1 extended with `armor_penetration: float` (new `tower_attacked` payload field) — reduces `armored_mitigation_multiplier` itself rather than replacing it; see D1's own updated worked examples. `raw_damage` (D1's own `damage_amount` input) now already reflects Tower System's own crit/vs-tag/boss-multiplier/elemental-resistance resolution before D&S ever sees it — that math is intentionally owned by Tower System, not D&S (see `tower.md` Formula 1b), keeping D&S's own "pure math, no registry dependency" shape unchanged; `element` itself never crosses the `tower_attacked` signal. `is_crit: bool` also added to the payload — D&S now forwards a real value into `MonsterDamageTaken.is_crit` for tower hits instead of the previous hardcoded `false`. **Semantic change to `effect_type`**: it can now arrive `""` for two independent reasons — no Power component equipped (pre-existing), or a new `status_proc_chance` roll on the firing weapon failed this hit (new) — D&S's own handler still ignores `effect_type` either way (Rule I.2, unchanged), but Monster System's D5/D6 exception-note readers should not assume `effect_type==""` means "no Power equipped." **Formula D5's recognized-DoT set gains `"bleed"`** (authored as a physical effect, reuses the DoT machinery verbatim) — note this tick-damage path does not read elemental resistance at all (neither does burn/poison), so "bleed is unresisted while poison isn't" is not yet a real distinction; deferred to a later phase as a named open decision (should Burn/Poison ticks become resistance-aware too?).
> **Review Date**: 2026-05-14 — NEEDS REVISION (4 of 12 pass-5 blockers resolved in-session). **Cross-doc staleness pass (2026-07-15)**: the Dependencies table's Wave Manager/Mission HUD rows still said "Not yet designed" though both GDDs now exist — fixed (Mission HUD's subscription confirmed accurate; Wave Manager's was speculative and never actually true, corrected to point at the real, already-documented relationship). A stray `is_siege` reference in the Tower System row was removed (that mechanic was struck from tower.md this session). All 5 items in the Bidirectionality notes follow-up list were verified against their target GDDs directly and confirmed already resolved — none required new changes here, only marking as closed. **`/review-all-gdds` re-run (same day) found 4 more leftover `is_siege` references** (Interactions table's Tower System row, AC-1/AC-2/AC-3) that the first pass missed — fixed, no `is_siege` remains anywhere in this document. **Also found and fixed a genuine structural bug via cross-system scenario walkthrough**: Rule VII's "preserve lifesteal heals on the killing blow of a wave" was previously unachievable in all cases — root-caused to `monster.md`'s Rule 21f, which explicitly suppressed `monster_hp_absorbed` on lethal hits (fixed there, see monster.md's Pass 7 revision note). Rule VII.2 annotated to confirm the corrected timing holds. **`/review-all-gdds` 4th pass (2026-07-15d)** found a related, previously-undetected race: a lifesteal heal from a hit landed just before the hero's own death had no cleanup hook — Rule VII's cleanup is scoped only to `wave_completed`, which DEFEAT never emits, so a `hero_healed` event could arrive after `hero_died` and visually contradict the death sequence (hero.md's death VFX vs. lifesteal's green flash/heal chime). **Fixed same-day**: new Rule VIII — D&S adds a fifth subscription (`hero_died`) and clears `_lifesteal_pending` synchronously (no frame delay, unlike Rule VII's drain-then-clear) the instant the hero dies; Rule VI's existing "if not present: ignore" guard then naturally suppresses any heal whose `monster_hp_absorbed` arrives afterward. New AC-25. **`/review-all-gdds` 5th pass (same day)**: re-verified Rule VIII at the engine-loop level (not just doc-level) — confirmed structurally sound, but its correctness depends on an undocumented timing dependency (Monster's physics-tied flush vs. D&S's idle-tied defer). Documented same-day as Rule VIII.6; hero.md gained a matching defensive `state == DEAD` guard (Formula 6, AC-15) as defense-in-depth.
> **Implements Pillar**: Mastery-as-Vindication · The Fight Must Be Worth It

## Engine Risk Notes (Godot 4.6.2)

No post-cutoff engine API dependency identified. This GDD's payload/formula surface (floats, ints, bools passed through EventBus events) has no direct engine API surface — no FileAccess, physics, or shader calls. Clean.

## Overview

The Damage & Status System is the single authoritative pipeline through which all offensive actions in Sanctuary Defenders are resolved into damage values that reach monsters and the hero. Every attack that reaches a monster — whether from a tower's weapon component or the hero's auto-attack — passes through this system: raw attack values arrive as EventBus events, the system applies the appropriate multipliers (elite and boss targets take 150% from the hero, armored targets take 50% from towers, critical hits apply the crit multiplier), and the resolved damage is published back to the EventBus as `monster_damage_taken`, which the Monster System then applies to a target's current HP. The result is one place for all damage arithmetic — a single system to tune, test, and profile regardless of the number of attack sources in the game.

Technically, the system subscribes to three events: `tower_attacked` (tower fires at a monster, carrying pre-resolved `is_armored` flag), `hero_auto_attacked` (hero strikes a monster, carrying base damage and crit flag), and `monster_hp_absorbed` (Monster System confirms how much HP was actually removed — used for lifesteal resolution). `monster_damage_taken` is always deferred one frame after the triggering attack event to respect the EventBus cascade budget. Lifesteal resolution uses `monster_hp_absorbed` rather than the full resolved damage: on overkill hits, heal returns only what the monster actually had, keeping the moment of a finishing blow at "quiet arithmetic" rather than a windfall. At MVP, the system also owns a hero-incoming-damage pipeline (applying the hero's armor coefficient to incoming hits and emitting `hero_damage_taken`), stubbed pending the definition of which game entities will damage the hero. Status effects: burn, poison, and slow are all in scope (amended 2026-08-13, resolved by Monster System directly — see Rule I.1's second named exception and Formulas D5/D6).

The player never sees the Damage & Status System directly, but they feel it on every attack: the snap of a critical hit on an elite, the visible and audible signal when the tier bonus lands on a non-crit hit, the proof that the hero's 150% multiplier turns a dangerous target into a kill within a single skill cycle, the healing tick that confirms — after the hit resolves — exactly what was gained. This system is what gives those moments mathematical integrity.

## Player Fantasy

The feeling is never "I hit hard." It is the moment the elite monster — the one your fire lattice was never going to chew through in time — drops one step earlier than the math said it should, because your hero was the one swinging at it. That single step is the difference between the lane holding and the lane breaking, and you feel it before you see the corpse. The fantasy is the quiet arithmetic of being right: you understood that *this* threat needed *this* answer, and the battlefield just proved it. The damage didn't come from a number getting bigger. It came from the right weapon meeting the right target at the right second.

Sometimes the plan doesn't hold. The pack is already past your chokepoint, the towers are on cooldown, and the boss is three cells from the sanctuary. You throw the hero in — not because you're confident, but because you have nothing else — and the next few hits land like you needed them to. Not a miracle. Not a power fantasy. A conversion. The damage you wring out of a collapsing situation is proof that you were still thinking when the plan stopped thinking for you. That is the fantasy: the calm realization, mid-panic, that you're the one closing this gap, and the hits are going where you're telling them to go.

## Detailed Design

### Core Rules

**I. System Scope**

1. The Damage & Status System is the single authoritative pipeline for all damage applied to **monsters and the hero**. It does not own damage applied to towers — BOSS→Tower direct damage is routed through the Tower System and is a named exception to this scope (see Tower System GDD Rule 18 and Monster GDD Rule 18). **Second named exception (added 2026-08-13):** burn/poison status-effect DoT tick damage AND slow status-effect speed reduction are both resolved directly by Monster System, not routed through D&S — see Formulas D5/D6 and this Rule's Amendment notes above for why. (Slow is not "damage" at all, so it is arguably outside D&S's scope by definition rather than a true exception to it — grouped here anyway since it shares the same `tower_attacked`-sourced, D&S-bypassing mechanism as burn/poison.)
2. At MVP this system owns **five** event subscriptions and two active pipelines: (a) outgoing damage from towers and the hero to monsters, and (b) incoming damage to the hero with armor applied. Incoming hero damage is scaffolded but has no active sources at MVP. The third subscription (`monster_hp_absorbed`) drives lifesteal resolution only — it is not a damage pipeline. The fourth subscription (`wave_completed`) drives `_lifesteal_pending` cleanup — see Rule VII. The fifth subscription (`hero_died`, added 2026-07-15d) drives an earlier, narrower `_lifesteal_pending` cleanup for the hero's own death — see Rule VIII. D&S's own five subscriptions are unchanged by the 2026-08-13 status-effect amendment — Monster System subscribes to `tower_attacked` independently for the status-tick pass (see Formula D5); D&S still ignores the payload's `effect_type`/`effect_value`/`effect_duration` fields entirely.
3. Status effects: **burn, poison, and slow are all in scope** (burn/poison amended 2026-08-13 — Formula D5; slow amended the same day, follow-up — Formula D6). No status effect remains out of scope for MVP as of this amendment.
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
2. When `wave_completed` is received, D&S must **drain pending heals before clearing**: defer the clear by one frame to allow any in-flight `monster_hp_absorbed` events (deferred from the final wave frame) to resolve naturally before the dictionary is cleared. This preserves lifesteal heals on the killing blow of a wave. See Rule VII.3 for the exact implementation. *(Verified 2026-07-15 — `/review-all-gdds` cross-system scenario walkthrough: this rule's stated purpose depends on `monster.md`'s absorbed-flush pass (pass 4 of its per-frame algorithm) running after the `monster_died`→`wave_completed` cascade (pass 3) within the same Monster System `_physics_process` call. Confirmed this ordering holds and correctly resolves the killing-blow's `monster_hp_absorbed` before this rule's deferred clear resumes on the next frame — see `monster.md` Rule 21f's 2026-07-15 correction, which fixed a prior bug where lethal hits never emitted `monster_hp_absorbed` at all, making this rule's purpose previously unachievable regardless of timing.)*
3. Implementation note: the `wave_completed` handler is: `await get_tree().process_frame` (if any `_lifesteal_pending` entries exist) → `_lifesteal_pending.clear()`. If `_lifesteal_pending` is already empty, skip the await and clear immediately.

**VIII. Hero-Death Cleanup** (event: `hero_died`) *(added 2026-07-15d — `/review-all-gdds` 4th pass)*

1. D&S subscribes to `hero_died` (fifth subscription — see Rule I.2).
2. On `hero_died` received: `_lifesteal_pending.clear()` **immediately, synchronously — no `await`, unlike Rule VII's wave-boundary clear.**
3. **Rationale:** a lifesteal hit landed just before the hero's own death defers its heal by one frame (Rule III.6-7) before `monster_damage_taken`/`monster_hp_absorbed` resolve on the Monster System side. The hero's own incoming-damage pipeline (Rule V) is independently deferred. Because these are two unrelated deferred chains, their relative arrival order within a frame is not guaranteed. If `monster_hp_absorbed` for a pending lifesteal hit arrives *after* `hero_died` has already fired, Rule VI would otherwise emit `hero_healed` on a hero already in the `DEAD` state — contradicting `hero.md`'s death sequence (Visual/Audio table: "screen desaturates... vignette freezes at max opacity") with a simultaneous green heal flash and absorption chime. Clearing `_lifesteal_pending` the instant `hero_died` fires means any `monster_hp_absorbed` that arrives afterward finds no entry — Rule VI.2's existing "if not present: ignore" guard suppresses the heal with no new logic needed there. If `monster_hp_absorbed` arrives *before* `hero_died` (the hero was still alive when the heal resolved), the heal is legitimate and unaffected — this rule only ever discards entries for hits whose heal would otherwise land on a corpse.
4. This clear does **not** wait a frame the way Rule VII's does — Rule VII drains pending heals before clearing (preserving legitimate end-of-wave killing-blow lifesteal); Rule VIII does the opposite, discarding immediately, because by definition no heal received after `hero_died` can be legitimate — the hero the heal targets is already dead.
5. `wave_completed` and `hero_died` are mutually exclusive triggers within a mission — Wave Manager's own DEFEAT-priority rule (`wave-manager.md` Rule 14: "if `hero_died` and a wave-clear signal arrive in the same frame, DEFEAT takes priority") guarantees D&S never receives both cleanup triggers for the same pending state. No double-clear ordering hazard exists between Rule VII and Rule VIII.

6. **Timing dependency this rule's correctness relies on** *(documented 2026-07-15d — `/review-all-gdds` 5th pass, cross-system scenario walkthrough)*: Rule VIII only reliably wins the race against a pending lifesteal heal because Monster System's `monster_hp_absorbed` flush is pinned to `_physics_process` (monster.md Rule 21e's accumulator pattern) while D&S's own dispatch defer uses `await get_tree().process_frame` (an idle-step callback, not `call_deferred` — see Rule IV.1's note on why that distinction matters). Godot's frame loop always runs pending physics ticks before the idle step in the same frame, so any `monster_hp_absorbed` not yet flushed by the time `hero_died`'s idle-step callback runs cannot be flushed until a later physics tick — after Rule VIII's synchronous clear has already landed. **This guarantee is structural, not incidental, but it depends on both of the specific mechanisms named above staying as they are.** If Monster System's absorbed-flush is ever moved off `_physics_process`, or D&S's dispatch defer is ever changed to `call_deferred` or another mechanism with different timing semantics, this ordering guarantee must be re-verified — it is not independently enforced by any test or assertion. Hero System's `hero_healed` handler carries a defensive `state == DEAD` guard (`hero.md`, Formula 6) as a second layer in case this dependency is ever silently broken.

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
| Tower System | ← upstream | `tower_attacked` (`damage_amount`, `target_monster_id`, `is_armored`) | Tower System pre-resolves `is_armored` from target's `MonsterResource.archetype_tag` at fire time — D&S never reads monster state directly. *(`is_siege` removed 2026-07-15 — struck along with tower.md's T4 Siege mechanic.)* |
| Monster System | → downstream | `monster_damage_taken` (deferred one frame) | Monster System applies `amount` to target HP |
| Monster System | ← upstream | `monster_hp_absorbed` (`entity_id: int`, `absorbed: int`) | Monster System emits (deferred one frame from `monster_damage_taken`) after HP application — D&S uses to resolve lifesteal |
| Hero System | → downstream | `hero_healed` (fires within Monster System's `_physics_process` flush) | Hero System clamps at max HP — overheal behavior owned by Hero System |
| EventBus | constraint | Cascade budget rule | `monster_damage_taken` must always defer one frame; `hero_healed` fires at cascade depth 1 from `monster_hp_absorbed` (permitted — within 2-level chain rule) |
| Wave Manager | ← upstream | `wave_completed` (no payload fields consumed) | D&S clears `_lifesteal_pending` on receipt — see Rule VII |
| Hero System | ← upstream | `hero_died` (no payload fields consumed) | D&S clears `_lifesteal_pending` synchronously on receipt — see Rule VIII (added 2026-07-15d) |

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
| `raw_damage` | float | 5–200 | Weapon component base damage; read from `tower_attacked` payload field `damage_amount`. **As of Tower Stats System Phase 1 (2026-08-16), this already reflects Tower System's own crit/vs-tag/boss-multiplier/elemental-resistance resolution — see `tower.md` Formula 1b — before it ever reaches D&S.** |
| `is_armored` | bool | — | Pre-resolved by Tower System from target's `archetype_tag`; `true` when `archetype_tag == &"armored"` |
| `armor_penetration` | float | [0.0, 1.0] | **Added Phase 1.** From the firing weapon's `WeaponComponent.armor_penetration`, read from `tower_attacked` payload field `armor_penetration`. Fraction of `armored_mitigation_multiplier` this hit negates; irrelevant when `is_armored == false`. |
| `final_damage` | int | 2–200 | Damage applied to monster HP via `monster_damage_taken` |

**Expression** (extended Phase 1 — collapses to the original formula when `armor_penetration = 0.0`, the default for all pre-Phase-1 content):
```
effective_mitigation = clamp(
    armored_mitigation_multiplier + (1.0 - armored_mitigation_multiplier) × armor_penetration,
    armored_mitigation_multiplier, 1.0
) if is_armored else 1.0
resolved_damage = raw_damage × effective_mitigation
final_damage    = floor(resolved_damage)
```

> `armored_mitigation_multiplier` defaults to `0.50` — see Tuning Knobs. Worked examples below use the default value and `armor_penetration = 0.0` unless stated.

**Worked examples** (armored_mitigation_multiplier = 0.50):
- raw_damage = 47.3, is_armored = false → final_damage = 47
- raw_damage = 80.7, is_armored = true, armor_penetration = 0.0 → floor(80.7 × 0.50) = floor(40.35) = **40**
- raw_damage = 5.0, is_armored = true, armor_penetration = 0.0 → floor(5.0 × 0.50) = floor(2.5) = **2** (minimum possible tower damage on armored target)
- raw_damage = 80.7, is_armored = true, armor_penetration = 0.5 → effective_mitigation = 0.50 + 0.50×0.5 = 0.75 → floor(80.7 × 0.75) = floor(60.525) = **60**
- raw_damage = 80.7, is_armored = true, armor_penetration = 1.0 → effective_mitigation = 1.0 (mitigation fully countered) → floor(80.7) = **80**

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

#### D5 — Status Effect (Burn/Poison) DoT Tick Damage *(amended 2026-08-13; resolved by Monster System, not D&S — see Rule I.1's second named exception)*

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `effect_type` | String | `"burn"` / `"poison"` / anything else | From the firing tower's `PowerComponent.effect_type`, forwarded on `tower_attacked`. Any value other than `"burn"`/`"poison"` (including `"slow"` and `""`) is ignored — no DoT instance is created. |
| `effect_value` | float | 0.0–1.0 in practice | From `PowerComponent.effect_value` — the fraction of the target's `scaled_hp` (max HP) dealt as **total** damage across the whole effect duration, not per tick. |
| `effect_duration` | float | > 0.0 | From `PowerComponent.effect_duration`, in seconds. |
| `scaled_hp` | float | > 0 | The target monster's own max HP at spawn time (Monster GDD) — the DoT scales with the target, not the tower, so it stays meaningful against both STANDARD and BOSS tiers without separate per-tier tuning. |
| `num_ticks` | int | ≥ 1 | `round(effect_duration / status_tick_interval)`, floored at 1 so a very short duration still deals its full damage in one tick rather than rounding to zero ticks. |
| `tick_damage` | float | > 0 | Damage applied to the target's HP at each tick. |

**Expression:**
```
num_ticks   = max(1, round(effect_duration / status_tick_interval))
tick_damage = (effect_value × scaled_hp) / num_ticks
```

> `status_tick_interval` defaults to `1.0` second — see Tuning Knobs.

**Worked examples** (`status_tick_interval = 1.0`):
- Firebolt Turret hit: `effect_type="burn"`, `effect_value=0.10`, `effect_duration=3.0`, target `scaled_hp=200` → `num_ticks = round(3.0/1.0) = 3`; `tick_damage = (0.10 × 200) / 3 = 6.667`. Total burn damage over 3 ticks ≈ 20 (10% of max HP), matching the field's own name.
- Venom Dart Turret hit: `effect_type="poison"`, `effect_value=0.08`, `effect_duration=4.0`, target `scaled_hp=500` (BOSS-tier) → `num_ticks = 4`; `tick_damage = (0.08 × 500) / 4 = 10.0`. The formula's %-of-max-HP basis means this BOSS takes proportionally the same 8% total as a STANDARD monster hit by the identical tower, with no separate BOSS tuning required.
- `effect_type="slow"` (frostbolt_turret) or `effect_type=""` (any non-elemental tower) → not a recognized DoT type; no `ActiveStatusEffect` instance is created; the hit's direct damage (Formula D1) is entirely unaffected.

**Stacking (design decision, not an oversight):** a monster hit by burn/poison while an instance of that same `effect_type` is already active gets a **second, independent** instance — each with its own `num_ticks`/`tick_damage` computed fresh from that hit. Instances do not merge, refresh each other's duration, or cap in count. Two Firebolt Turrets both hitting one target burn it roughly twice as hard, not once.

**Kill attribution:** a tick that reduces `current_hp` to ≤ 0 sets `last_hit_source = &"tower"` and routes through the same `MonsterDiedEvent`/`monster_died` (or `monsters_died_batch`) path as any other tower-sourced kill (`kill_source = &"tower"`) — no new kill-source value is introduced.

#### D6 — Slow Effect Speed Multiplier *(amended 2026-08-13, same day, follow-up; resolved by Monster System, not D&S — see Rule I.1's second named exception)*

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `effect_type` | String | `"slow"` / anything else | From `PowerComponent.effect_type`, forwarded on `tower_attacked`. Any value other than `"slow"` is ignored by this formula (may still be a recognized DoT — see Formula D5). |
| `effect_value` | float | 0.0–1.0 in practice | From `PowerComponent.effect_value` — the fraction of the target's own current speed removed by **one** instance. Unlike D5, this is not scaled against any HP-like stat; it's a direct percentage of speed. |
| `effect_duration` | float | > 0.0 | From `PowerComponent.effect_duration`, in seconds. |
| `speed_multiplier` | float | `[speed_multiplier_floor, 1.0]` | `1.0 - effect_value`, floored at `speed_multiplier_floor` so one extreme content value can never freeze a monster in place entirely. |
| `effective_speed` | float | ≥ 0 | What Monster System's movement pass (Pass 3) actually reads each frame — `MonsterEntity.scaled_speed` is NEVER mutated; it stays immutable after spawn per ADR-0006. |

**Expression:**
```
speed_multiplier = max(speed_multiplier_floor, 1.0 - effect_value)     # per instance, computed once when the instance is created
effective_speed  = scaled_speed × Π(speed_multiplier for each active instance on this monster)
```

> `speed_multiplier_floor` defaults to `0.05` — see Tuning Knobs. The product (`Π`) is the multiplicative-stacking rule — see the Amendment note above for the worked reasoning on why multiplicative was chosen over additive.

**Worked examples** (`speed_multiplier_floor = 0.05`):
- Frostbolt Turret hit: `effect_type="slow"`, `effect_value=0.15`, target has no other active slow → `speed_multiplier = max(0.05, 1.0 - 0.15) = 0.85`. A monster with `scaled_speed=2.0` cells/sec moves at `2.0 × 0.85 = 1.7` cells/sec for the instance's remaining duration.
- Two Frostbolt Turrets hit the same target (both `effect_value=0.15`) → two independent instances, both `speed_multiplier=0.85` → `effective_speed = scaled_speed × 0.85 × 0.85 = scaled_speed × 0.7225` (27.75% total reduction, not 30%).
- A hypothetical extreme content value `effect_value=0.99` → `speed_multiplier = max(0.05, 0.01) = 0.05` (the floor wins) — the monster crawls at 5% speed rather than stopping dead.
- `effect_type="burn"`/`"poison"`/`""` → not a recognized slow type; no `ActiveSlowEffect` instance is created; `effective_speed` is unaffected by this hit (though a recognized DoT type still creates a Formula D5 instance independently — the two formulas are entirely independent per hit).

**Duration decay, not ticks:** unlike D5, a slow instance has no discrete tick events — `remaining_duration` counts down by `delta` every Pass 1b, and the instance is removed once it reaches 0. There is no "partial tick" concept; the movement pass simply reads whichever instances are still present each frame.

**Stacking (design decision, matching D5's philosophy):** a monster hit by slow while another slow instance is already active gets a **second, independent** instance with its own `remaining_duration`. Instances do not merge, refresh each other's duration, or cap in count — see the Amendment note above for why multiplicative combination was chosen specifically to make this safe regardless of stack count.

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

**EC-14: Target dies mid-effect from a DoT tick, with other instances still active** *(amended 2026-08-13)*
A monster carries 2 independent burn instances (from 2 separate Firebolt hits) plus 1 poison instance. A burn tick fires and reduces `current_hp` to 0. Monster System sets `lifecycle_state = DEAD`, emits the death event, and stops processing that entity's remaining status-effect instances for the current frame — the still-`ticks_remaining > 0` poison instance and second burn instance are simply discarded along with the (now `queue_free()`'d) entity. No error, no orphaned per-monster timer state, since the instances live on the `MonsterEntity` itself and are freed with it.

**EC-15: Target dies from the direct hit that also carries a status effect** *(amended 2026-08-13)*
A `tower_attacked` event carries both lethal `damage_amount` and a nonzero `effect_type`. Formula D1's direct-damage resolution (via D&S → `monster_damage_taken` → Monster System Pass 1) and the status-effect application (Monster System's own `tower_attacked` subscription, independent of D&S) are two separate listeners on the same event, processed independently. If Pass 1's direct hit already killed the entity before the status-tick pass (Pass 1b) would otherwise apply, the status-application handler's own `lifecycle_state == DEAD` guard rejects it — no `ActiveStatusEffect` instance is created on an already-dead entity. This is a duplicate-work avoidance, not a correctness requirement (an instance on a dead entity would simply never tick, since Pass 1b also skips DEAD entities) — the guard exists so a needless allocation isn't made every time a killing blow happens to come from an elemental tower.

**EC-16: A slowed monster dies before the slow expires** *(amended 2026-08-13, same day, follow-up)*
A monster carries an active `ActiveSlowEffect` with `remaining_duration=1.5` when it dies (from any damage source — direct hit or a DoT tick). The entity is freed via the normal death path; `active_slow_effects` is a field on the `MonsterEntity` instance itself, so it is freed along with the entity — no separate cleanup step is required, and no orphaned per-monster timer state can leak (same reasoning as EC-14 for DoT instances).

**EC-17: A monster is simultaneously slowed and burning/poisoned** *(amended 2026-08-13, same day, follow-up)*
A single `tower_attacked` event can carry only one `effect_type` (Firebolt Turret's Power component is either burn OR slow OR poison — never more than one per weapon in current content), but two *different* towers can independently apply a DoT and a slow to the same monster in the same or different frames. `active_status_effects` (DoT) and `active_slow_effects` (slow) are two entirely separate arrays on `MonsterEntity`, processed by two separate helper functions (`_tick_dot_instances`/`_decay_slow_instances`) within the same Pass 1b — a monster can be burning AND slowed at once with no interaction between the two formulas. The only shared state is `current_hp`, which only the DoT path touches.

## Dependencies

#### Systems this GDD depends on

| System | GDD | What D&S requires |
|--------|-----|-------------------|
| EventBus System | `design/gdd/event-bus.md` | All inter-system communication. D&S subscribes to `tower_attacked`, `hero_auto_attacked`, `monster_hp_absorbed`, and `wave_completed`; emits `monster_damage_taken` (deferred) and `hero_healed` (synchronous from `monster_hp_absorbed` handler). Cascade budget rule: `monster_damage_taken` must defer one frame. `hero_healed` is a permitted synchronous emission at cascade depth 1 from `monster_hp_absorbed` (within the 2-level chain rule — no exemption needed). **Follow-up required:** EventBus GDD must be updated to (a) confirm `is_armored: bool` is in the `tower_attacked` payload, (b) confirm `monster_hp_absorbed` is in the event catalogue with payload `entity_id: int`, `absorbed: int`, and (c) update `HeroAutoAttackEvent` Resource payload to replace `hero_damage_bonus_eligible: bool` with `hero_bonus_tier: int`. |
| Hero System | `design/gdd/hero.md` | Emits `HeroAutoAttackEvent` Resource carrying `base_damage`, `is_crit`, `target_id`, `crit_multiplier_effective` (pre-computed), `hero_lifesteal_fraction` (pre-clamped to `hero_lifesteal_cap`), and `hero_bonus_tier` (read from target archetype tier at attack-roll time: 0=STANDARD, 1=ELITE, 2=BOSS). Owns the crit roll and target-tier check — D&S never rolls RNG or reads monster state. Receives `hero_healed` and owns overheal clamping behavior. **Follow-up required:** Hero GDD must be updated to replace `hero_damage_bonus_eligible: bool` with `hero_bonus_tier: int` in the `HeroAutoAttackEvent` payload definition and in the attack-roll emission logic. |
| Tower System | `design/gdd/tower.md` | Emits `tower_attacked` with `damage_amount`, `target_monster_id`, and `is_armored`. Tower System reads the target's `MonsterResource.archetype_tag` at fire time and pre-resolves `is_armored` — D&S never reads monster state directly. **Resolved (2026-05-11, confirmed still current 2026-07-15):** tower.md Rule 20a documents the `archetype_tag` read and `is_armored` field. *(`is_siege` removed 2026-07-15 — the T4 Siege mechanic was struck from tower.md; see `tower.md`'s T4 Boss-Lane Identity section and `event-bus.md`'s `tower_attacked` catalogue row.)* **Payload grown 2026-08-13:** `tower_attacked` also carries `effect_type`/`effect_value`/`effect_duration` (the firing tower's own `PowerComponent` fields) — D&S's own handler ignores all three (Rule I.2); they exist for Monster System's independent status-effect subscription (Formulas D5/D6). **Payload grown again 2026-08-16 (Tower Stats System Phase 1):** `armor_penetration: float` and `is_crit: bool` added — both consumed by D&S's own Formula D1 (see this doc's top-of-file Amendment note); `damage_amount` itself now already reflects Tower System's crit/vs-tag/boss/resistance resolution. |
| Monster System | `design/gdd/monster.md` | Receives `monster_damage_taken` (deferred) and applies `amount` to target HP. Owns dead-monster guard (ignores events for entities with `hp <= 0`). **Emits `monster_hp_absorbed`** (deferred one frame from receiving `monster_damage_taken`) with `entity_id: int` and `absorbed: int` — the actual HP removed, capped at pre-hit HP. D&S subscribes to this event for lifesteal resolution. When Monster System discards a `monster_damage_taken` event (dead entity), it must NOT emit `monster_hp_absorbed` for that entity_id. **Follow-up required:** Monster System GDD must be updated to document `monster_hp_absorbed` emission. **Amended 2026-08-13:** Monster System also independently subscribes to `tower_attacked` (not routed through D&S — see Rule I.1's second named exception) to apply Formula D5's burn/poison DoT ticks and Formula D6's slow speed multiplier via its own 5th `_physics_process` pass (ADR-0006 amendment). |

#### Systems that depend on this GDD

| System | GDD | What they consume from D&S |
|--------|-----|---------------------------|
| Monster System | `design/gdd/monster.md` | `monster_damage_taken` event — applies `amount` to target HP each frame |
| Hero System | `design/gdd/hero.md` | `hero_healed` event — applies `amount` to hero HP |
| Mission HUD | `design/gdd/mission-hud.md` | Subscribes to `monster_damage_taken` for floating damage numbers; uses `is_crit` and `hero_bonus_tier` fields to style the display. **Confirmed 2026-07-15** — mission-hud.md's own Dependencies table lists this event, added during its own review pass. |
| Audio System | Not yet designed | Subscribes to `monster_damage_taken.is_crit` and `source_type` for hit sound selection |
| Equipment Forge | Not yet designed | Must respect `crit_multiplier_bonus` maximum of 1.50 (cap defined in Formula D2) |

**Correction (2026-07-15):** this table previously also listed a speculative "Wave Manager — may subscribe to `monster_damage_taken`" row. Now that `wave-manager.md` is designed and Approved, its actual dependency on D&S is confirmed to be the reverse relationship already documented in the Interactions table above (D&S subscribes to Wave Manager's `wave_completed` for `_lifesteal_pending` cleanup) — Wave Manager does not consume `monster_damage_taken` at all; its kill tracking uses `monster_died`/`monsters_died_batch` directly from Monster System. The speculative row was removed as stale rather than propagated forward incorrectly.

#### Bidirectionality notes

**All 5 follow-ups below are now confirmed RESOLVED (verified 2026-07-15 — each target GDD checked directly, not assumed):**

- ~~Monster GDD must be updated to reference D&S as the owner of `monster_damage_taken` (this resolves Monster GDD OQ-4) and to document `monster_hp_absorbed` emission after HP application.~~ **RESOLVED** — monster.md's own OQ-4 is marked Resolved, citing this exact `MonsterDamageTaken` schema; Rules 20-21 document `monster_hp_absorbed` emission (and non-emission on dead-entity discard).
- ~~Hero GDD must be updated to reference D&S as the owner of `hero_healed` and the lifesteal resolution formula (D3), and to replace `hero_damage_bonus_eligible: bool` with `hero_bonus_tier: int` in `HeroAutoAttackEvent`.~~ **RESOLVED** — hero.md's Dependencies table credits D&S with damage resolution and `hero_healed`/`hero_damage_taken`; `HeroAutoAttackEvent` uses `hero_bonus_tier: int` throughout, no trace of `hero_damage_bonus_eligible`.
- ~~EventBus GDD must be updated to confirm `monster_hp_absorbed` in the event catalogue, confirm `is_armored: bool` in `tower_attacked` payload, update `HeroAutoAttackEvent` payload to `hero_bonus_tier: int`, and update `monster_damage_taken` payload to `hero_bonus_tier: int` replacing `hero_bonus_applied: bool`.~~ **RESOLVED** — event-bus.md's catalogue has all four: `monster_hp_absorbed` (entity_id, absorbed), `tower_attacked.is_armored`, `HeroAutoAttackEvent.hero_bonus_tier`, `monster_damage_taken.hero_bonus_tier`.
- ~~Tower System GDD must be updated to document the `archetype_tag` read and `is_armored` forwarding.~~ **RESOLVED** — tower.md Rule 20a, marked Resolved 2026-05-11.
- ~~Wave Manager GDD must note that D&S subscribes to `wave_completed` for `_lifesteal_pending` cleanup.~~ **RESOLVED** — wave-manager.md's Interactions table lists "Damage & Status System — `wave_completed` for end-of-wave state cleanup (D&S cross-GDD follow-up from D&S pass 6)".

No outstanding cross-GDD follow-ups remain from this list.

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
| `status_tick_interval` | Monster System (this GDD's Formula D5, owned outside D&S — see Rule I.1) | 1.0s | 0.5–2.0s | How often an active burn/poison instance deals damage. Below 0.5: ticks become imperceptible individually, reading as continuous drain rather than distinct hits — also raises per-frame iteration cost across many simultaneously-affected monsters. Above 2.0: with short `effect_duration` values (e.g. 3.0s), `num_ticks` rounds down to 1-2, making the DoT feel like a single delayed hit rather than a sustained effect. |
| `speed_multiplier_floor` | Monster System (this GDD's Formula D6, owned outside D&S — see Rule I.1) | 0.05 | 0.0–0.20 | Minimum `speed_multiplier` a single slow instance may have, regardless of `effect_value`. At 0.0: a single extreme-value slow (or enough stacked instances) can freeze a monster in place entirely — a stuck-forever state, not a strong slow, and a monster that never reaches the hero/goal breaks the wave-clear condition. Above 0.20: caps how strong a single slow can ever feel, even from deliberately-tuned high-`effect_value` content — reduces design headroom for a "near-stun" elemental effect. |

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
GIVEN a `tower_attacked` event with `damage_amount=47.3`, `target_monster_id=99`, `is_armored=false`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=99`, `amount=47`, `source_type=0`, `is_crit=false`, `hero_bonus_tier=0`

**AC-2: Tower damage pipeline — armored mitigation**
GIVEN a `tower_attacked` event with `damage_amount=80.7`, `target_monster_id=42`, `is_armored=true`
WHEN D&S processes it
THEN `monster_damage_taken` is emitted with `entity_id=42`, `amount=40` (`floor(80.7 × 0.50) = floor(40.35) = 40`), `source_type=0`, `is_crit=false`, `hero_bonus_tier=0`

**AC-3: Tower damage pipeline — ELITE/BOSS target with no tier multiplier**
GIVEN a `tower_attacked` event with `damage_amount=80.7`, `target_monster_id=42`, `is_armored=false`
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

**AC-25: `hero_died` clears `_lifesteal_pending` synchronously, suppressing a post-death heal** *(Integration test — requires live SceneTree + Monster System)* *(added 2026-07-15d)*
GIVEN a `HeroAutoAttackEvent` creates a `_lifesteal_pending` entry for target_id=99 with `hero_lifesteal_fraction=0.40`
AND `hero_died` fires before `monster_hp_absorbed` for entity_id=99 arrives (simulating the hero dying to an unrelated hit while this lifesteal hit is still in-flight)
WHEN D&S processes `hero_died`
THEN `_lifesteal_pending` is cleared immediately, synchronously, with no frame delay
AND when the previously-in-flight `monster_hp_absorbed(entity_id=99, ...)` subsequently arrives, Rule VI.2 finds no pending entry and emits no `hero_healed`
NOTE: Tests the Rule VIII cleanup path. Verifies a heal cannot visually land on the hero after the death sequence has begun. Contrast with AC-23 (Rule VII): that path drains pending heals with a one-frame delay before clearing (preserving legitimate wave-end lifesteal); this path clears with zero delay (no heal after death can ever be legitimate).

**AC-26: Status effect DoT — basic burn tick sequence** *(added 2026-08-13; Integration test — requires live SceneTree + Monster System)*
GIVEN a `tower_attacked` event with `target_monster_id=99`, `effect_type="burn"`, `effect_value=0.10`, `effect_duration=3.0`, and a live monster at entity_id=99 with `scaled_hp=200`
WHEN Monster System's status-application handler processes it
THEN one `ActiveStatusEffect` instance is created on entity 99 with `ticks_remaining=3` and `tick_damage=6.667` (`(0.10 × 200) / 3`)
AND after 3 simulated `status_tick_interval` (1.0s) intervals, `current_hp` has been reduced by a total of ~20 (10% of `scaled_hp`) and the instance has been removed from `active_status_effects`

**AC-27: Status effect DoT — reapplication stacks, does not refresh**
GIVEN entity 99 already carries one active burn instance (`ticks_remaining=2` remaining)
WHEN a second `tower_attacked` event with `effect_type="burn"` targeting entity 99 arrives
THEN entity 99's `active_status_effects` now holds 2 independent burn instances, each with its own `ticks_remaining`/`tick_damage` — the first instance's `ticks_remaining` is NOT reset or merged with the second

**AC-28: Status effect DoT — unrecognized effect_type is a no-op**
GIVEN a `tower_attacked` event with `effect_type="slow"` (or `effect_type=""`)
WHEN Monster System's status-application handler processes it
THEN no `ActiveStatusEffect` instance is created — `RECOGNIZED_DOT_EFFECTS` (`["burn", "poison"]`) does not include `"slow"` or `""`

**AC-29: Status effect DoT — a killing tick routes through the normal death path**
GIVEN entity 99 has `current_hp=5` and one active burn instance with `tick_damage=10.0` about to tick
WHEN the tick fires
THEN `current_hp` clamps to 0, `lifecycle_state` becomes `DEAD`, `last_hit_source = &"tower"`, and a `MonsterDiedEvent` with `kill_source = &"tower"` is buffered into `_pending_deaths` — identical to a direct-hit kill, no new kill-source value

**AC-30: Status effect DoT — target dies with other instances still pending (EC-14)**
GIVEN entity 99 carries 2 active status instances and a tick from the first one kills the entity
WHEN Pass 1b continues iterating that entity's remaining instances
THEN processing for entity 99 stops immediately (no further HP mutation, no error) — the second instance is discarded along with the freed entity, not double-counted or leaked

**AC-31: Slow effect — basic application** *(added 2026-08-13, same day, follow-up)*
GIVEN a `tower_attacked` event with `target_monster_id=99`, `effect_type="slow"`, `effect_value=0.15`, `effect_duration=2.0`
WHEN Monster System's status-application handler processes it
THEN one `ActiveSlowEffect` instance is created on entity 99 with `remaining_duration=2.0` and `speed_multiplier=0.85` (`max(0.05, 1.0 - 0.15)`)
AND `active_status_effects` (the DoT array) is unaffected — `"slow"` never creates a DoT instance

**AC-32: Slow effect — effective speed reduction during movement**
GIVEN entity 99 has `scaled_speed=2.0` and one active slow instance with `speed_multiplier=0.85`
WHEN Monster System's movement pass (Pass 3) computes this frame's movement budget
THEN it reads `effective_speed = 2.0 × 0.85 = 1.7`, NOT `scaled_speed` directly
AND `entity.scaled_speed` itself remains `2.0` (unmutated) both during and after the slow's active window

**AC-33: Slow effect — multiplicative stacking**
GIVEN entity 99 already carries one active slow instance with `speed_multiplier=0.85`
WHEN a second `tower_attacked` event with `effect_type="slow"`, `effect_value=0.15` targeting entity 99 arrives
THEN entity 99's `active_slow_effects` now holds 2 independent instances
AND `effective_speed = scaled_speed × 0.85 × 0.85 = scaled_speed × 0.7225` — NOT `scaled_speed × 0.70` (the additive alternative that was explicitly rejected)

**AC-34: Slow effect — speed_multiplier_floor prevents a full stop**
GIVEN a `tower_attacked` event with `effect_type="slow"`, `effect_value=0.99`
WHEN the instance is created
THEN `speed_multiplier = max(0.05, 1.0 - 0.99) = max(0.05, 0.01) = 0.05` — the floor wins, not the raw `0.01`
AND a monster with only this one instance active still moves at 5% of `scaled_speed`, never 0

**AC-35: Slow effect — duration decay and expiry (no ticks)**
GIVEN entity 99 has one active slow instance with `remaining_duration=1.5`
WHEN Pass 1b runs with `delta=1.0` then again with `delta=1.0`
THEN after the first call, `remaining_duration=0.5` and the instance is still present
AND after the second call, `remaining_duration` would be `-0.5`, so the instance is removed from `active_slow_effects` entirely — `effective_speed` returns to `scaled_speed × 1.0` (no other instances) immediately, not gradually

## Open Questions

**OQ-1: RESOLVED** — `hero_auto_attacked` payload extended to `HeroAutoAttackEvent` Resource subclass (6 fields: `base_damage`, `is_crit`, `target_id`, `crit_multiplier_effective`, `hero_lifesteal_fraction`, `hero_bonus_tier`). `hero_bonus_tier` replaces the former `hero_damage_bonus_eligible: bool` — Hero System reads target archetype tier at attack-roll time and passes 0/1/2 (STANDARD/ELITE/BOSS). D&S has no direct read dependency on Hero System state — all inputs arrive via the event payload. `event-bus.md` and `hero.md` must be updated to reflect the updated payload (tracked in Dependencies follow-up notes).

**OQ-2: RESOLVED** — All three events (`hero_healed`, `hero_incoming_damage`, `hero_damage_taken`) are present in `design/gdd/event-bus.md` as of the 2026-04-25 EventBus update. `hero_auto_attacked` payload was updated to reflect the 6-field `HeroAutoAttackEvent` Resource.

**OQ-3: RESOLVED** — Lifesteal overkill now uses `absorbed` (actual HP removed, from `monster_hp_absorbed`) rather than `final_damage`. A killing blow on a near-dead monster heals the hero for HP actually taken from that monster, not the full resolved damage. This preserves the "quiet arithmetic" Player Fantasy at the moment of a killing hit. The round-trip adds one frame of heal latency (N+2 instead of immediate), accepted as a reasonable trade-off. Monster System is responsible for emitting `monster_hp_absorbed` after every `monster_damage_taken` it processes (except discarded events for dead entities).

**OQ-4: RESOLVED** — `monster_damage_taken` payload defined in Formula section of this document.
