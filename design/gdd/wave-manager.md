# Wave Manager

> **Status**: Needs Revision (review #10 — 2026-05-22 Approved; 0 blockers. **Review #11 — 2026-07-15**: scoped `/design-review` re-pass for Tower GDD's OQ-11 boss-lane telegraph — `boss_spawn_cell: Vector2i` field added, AC-42 added. **Review #12, 2026-07-15**: propagation-debt fixes — 4 remaining `Array[Dictionary]` references corrected to `Array[WaveCompositionEntry]`/`WavePreviewEvent`. **2026-07-15, later same day**: `/review-all-gdds` found 2 more items — a stale "Siege shield-penetration" reference (struck along with tower.md's T4 Siege mechanic) and Tower System's undocumented dependency on a frame-yield guarantee between `wave_completed` and the next `wave_started`. Both fixed: stale reference removed; new Rule 12a formalizes the guarantee as a binding invariant (previously only emergent from the state machine's structure), with new AC-43. **Review #13, 2026-07-15d**: `/review-all-gdds` 4th pass found Rule 11's `wave_preview_available` note deferred to tower.md's "archetype" bucketing language without flagging that no monster archetype field exists — annotated Rule 11 to clarify Mission HUD resolves tier (not archetype) via the existing `GameDataRegistry.get_monster()` lookup; `WaveCompositionEntry`'s schema is unaffected. **Review #14, 2026-07-15d (5th pass, same day)**: `/review-all-gdds` found AC-10's 3-spawn-cell test fixture had been cited (by an earlier same-day pathfinding.md fix, since reverted) as proof multi-SPAWN maps are ordinary MVP content — they are not; `pathfinding.md`'s AC-13d is a deliberate CI gate blocking any such map from shipping until a post-MVP pathfinding fix lands. AC-10 itself was correct as a Wave Manager unit test (its round-robin algorithm is legitimately N-agnostic code) but needed a scope note distinguishing "code correctness for arbitrary N" from "N>1 content is shippable" — added. **Review #15, 2026-07-17 (`/design-review --depth lean` re-review)**: confirmed the long-standing `run_modifier_selected` misattribution — Tarot was named as sender in the Interactions table, Downstream Dependencies table, OQ-2, and AC-39, despite both `tarot.md` and `mission-select.md` having already resolved this from their own sides. Fixed here: Interactions/Downstream tables split into a Mission Select row (the actual sole sender of `run_modifier_selected`) and a separate Tarot row (`mission_modifier_applied`, the channel Tarot actually uses); OQ-2 marked resolved; AC-39b added for the previously-blocked positive case.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-17
> **Implements Pillar**: The Fight Must Be Worth It

## Engine Risk Notes (Godot 4.6.2)

| API | Used for | Risk | Status |
|-----|---------|------|--------|
| `Array[WaveScript]`, `Array[WaveSpawnEntry]`, `Array[Vector2i]` (typed Arrays) | Wave data structures | LOW | Stable since Godot 4.0 |
| Signal-based coroutine gating (`await` on EventBus signals) | `templates_ready` gate, rebuild gates | LOW | Standard GDScript coroutine pattern, no known 4.4–4.6 changes |

## Overview

The Wave Manager is the mission director: it owns the full phase lifecycle of a mission (SCOUT → WAVE_ACTIVE → INTERMISSION → MISSION_COMPLETE / DEFEAT), sequences monster spawns within each wave, tracks wave-clear conditions, and drives phase transitions. It is an Autoload singleton, active for the duration of a mission and idle between missions. At mission launch it receives wave composition data from a `WaveConfig` Resource — an ordered list of `WaveScript` entries that define which monster types spawn, in what quantities, and on what per-spawn schedule for each wave. During WAVE_ACTIVE, the Wave Manager emits `monster_spawn_requested` events at timed intervals to cue the Monster System to instantiate entities. It tracks incoming `monster_died` / `monsters_died_batch` and `boss_died` events to detect wave completion, then advances to INTERMISSION (if more waves remain) or triggers MISSION_COMPLETE. A BOSS breach (`monster_breached` with `tier == 2`) counts as wave-cleared rather than a defeat condition — the Mission HUD provides the warning feedback. `hero_died` transitions to DEFEAT at any point. Phase timers (60s Scout, 20s Intermission, 10s pre-wave countdown) drive the wave rhythm and are surfaced to the player via `phase_timer_tick` and `wave_countdown_warning` events consumed by the Mission HUD. Without the Wave Manager, no monsters spawn, no phases advance, and the mission has no rhythm — the defence systems have nothing to defend against.

From the player's perspective, the Wave Manager is what makes the battlefield feel alive: the countdown before a wave that creates urgency, the composition of the incoming horde that shapes the next 90 seconds, the escalation from wave 1 to the final BOSS. It doesn't announce itself — but every time the player feels pressure build, braces for the next wave, or exhales as the last monster falls, that is the Wave Manager's work.

## Player Fantasy

*The Wave Manager does not hand the player a challenge — it hands them a clock.*

The fantasy is not survival. It is command: the satisfaction of running a defense across a known timeline with the authority to reassess and recommit between engagements. SCOUT is the war room. The wave is the engagement. The intermission is the debrief.

The peak moment is not the combat itself — it is the quiet afterward. The wave collapses. The field goes quiet. The player exhales, scans the grid for what held and what nearly broke, and decides what to change before the next wave arrives. That rhythm — pressure, release, plan, repeat — is what the Wave Manager produces. Every intermission is a small vindication and a new question: *that worked. Now, is this enough for what comes next?*

Wave composition is forewarning, not surprise. Each wave teaches the player something about the mission before the boss arrives: an early rush reveals the chokepoint under pressure; the penultimate elite pack declares the stakes; the final BOSS is announced by everything that came before it. The dread is earned and legible.

**What "I read it correctly" means**: The payoff of retrospective mastery — *not I survived, but I read it correctly* — is the emotional return on a wave where nothing escaped. Every standard monster killed, every ELITE stopped before the exit, every spawn cell covered: that is a wave you read correctly. The satisfaction is retrospective: you look at what you built and see it as a deliberate answer to the threat the wave preview announced.

**What BOSS breach means**: A BOSS that reaches the map exit is not a win. The Wave Manager clears the wave — the mission continues, hero breach damage is applied — but the player did not stop the BOSS. This is a different emotional register: legible failure without mission loss. The BOSS breach counter in the Mission HUD records what got through. The mission's continuation is not a reprieve; it is the player living with the consequence they could not prevent. The BOSS breach IS the consequence beat — hero damage applied, the breach counter incremented, the `was_boss_breached: true` flag on the wave-clear banner. There is no second chance at that BOSS. The mission continues because the design says legible failure is not automatic defeat, not because the BOSS can be re-engaged. *I survived* is not the same as *I read it correctly.*

The Wave Manager is invisible. What the player feels is that the mission has a spine.

**The PRE_WAVE window**: The 10-second countdown before each wave is a buffer the player may take or waive. A commander who has resolved the intermission debrief — who knows what to change and why — presses Ready and commits early. The dread is not in the countdown itself; it is in the decision to initiate. A player who waits through the full countdown is taking space to reconsider. Both are valid expressions of the commander archetype. The clock the Wave Manager hands the player is the mission's known timeline — not the mandatory duration of any single phase.

**Pillar served:** "The Fight Must Be Worth It" — the wave cadence is the engine that makes the fight worth preparing for. Without escalation, pacing, and a clear final wave, resource investment and strategic positioning lose their stakes.

## Detailed Design

### Core Rules

#### Group 1 — System Identity

1. The Wave Manager is an Autoload singleton. Active during missions; idle between missions. It is the sole authority on mission phase transitions — no other system may trigger a phase change.
2. All cross-system communication goes through EventBus. The only direct Autoload calls are: (1) `Grid.get_spawn_cells()` once at `mission_launched`, and (2) `PathfindingSystem.is_rebuild_pending()` at the INTERMISSION→PRE_WAVE transition (Rule 22). All other cross-system communication uses EventBus signals.

---

#### Group 2 — Wave Composition Schema

3. Wave composition is defined by a `WaveConfig` Resource (`.tres` file in `assets/data/waves/`). One `WaveConfig` per mission. Fields:

   | Field | Type | Description |
   |-------|------|-------------|
   | `wave_scripts` | `Array[WaveScript]` | Ordered list of waves; `wave_scripts.size()` = total wave count (5–8) |
   | `difficulty_growth_rate` | `float` | Per-wave exponential scalar growth. Default: 0.20. Safe range: 0.15–0.25 |
   | `wave_time_budget` | `float` | Maximum total `pre_delay` sum (seconds) across all entries in a single `WaveScript`. Default: 90s. Safe range: 45–120s. Validated at `mission_launched`; content authoring error if any wave exceeds this budget. **Bounds the spawn-scheduling window only** — prevents excessively long `pre_delay` chains. Independent of `wave_stuck_timeout`, which governs the post-spawn stuck-state safety net. Maximum WAVE_ACTIVE duration at defaults = `wave_time_budget` (90s) + `wave_stuck_timeout` (60s) + monster traversal time — these timers are sequential, not competing. |

4. A `WaveScript` Resource defines one wave. Field: `entries: Array[WaveSpawnEntry]`.

5. A `WaveSpawnEntry` Resource defines one monster spawn event. Fields:

   | Field | Type | Description |
   |-------|------|-------------|
   | `monster_id` | `StringName` | References a MonsterResource by id |
   | `spawn_cell_index` | `int` | Index into `Grid.get_spawn_cells()`. `-1` = round-robin auto-assign |
   | `pre_delay` | `float` | Seconds to wait after the previous entry (or after `wave_started` for index 0) before firing this spawn. Minimum: 0.0 |

6. Content constraints (validated by QA, not enforced at runtime):
   - The **penultimate wave** (wave N−1, where N = `wave_scripts.size()`) entries must contain only ELITE `monster_id` values. For a 5-wave mission this is wave 4; for an 8-wave mission this is wave 7. For a 2-wave mission (below the 5-wave minimum) this rule does not apply.
   - The final wave's entries must contain at least two entries: one or more standard/elite monsters followed by exactly one BOSS `monster_id` as the last entry.
   - **The final wave's BOSS entry must use an explicit `spawn_cell_index >= 0` — round-robin (`spawn_cell_index = -1`) is not permitted on a BOSS entry.** *(Added during `/design-review` 2026-07-14 re-review, resolves Tower GDD OQ-11's boss-lane telegraph requirement.)* **Rationale:** `wave_preview_available` (Rule 11) must surface the boss's spawn cell at INTERMISSION entry, before the wave's spawn sequencing has run — but round-robin resolution (Rule 15b) depends on `_round_robin_counter`, which only advances as entries actually fire during WAVE_ACTIVE (Rule 10f resets it to 0 at wave start). A round-robin boss entry has no resolvable spawn cell at preview time. Requiring an explicit index sidesteps building a parallel simulated-resolution algorithm. Enforced by the AC-19b CI validator (see Edge Cases and Acceptance Criteria).

---

#### Group 3 — Phase Lifecycle

7. The Wave Manager operates across 7 states:

   | State | Entry Trigger | Player Actions | Timer |
   |-------|--------------|----------------|-------|
   | `IDLE` | App start / mission end | None | None |
   | `SCOUT` | `mission_launched` received | Tower placement, Tarot selection | 60s; `phase_timer_tick` every second |
   | `PRE_WAVE` | Scout timer expires **or** player presses Ready | None | 10s; `wave_countdown_warning` fires at entry, `phase_timer_tick` every second thereafter (2026-08-13 extension — see Formula F2) |
   | `WAVE_ACTIVE` | PRE_WAVE countdown expires | Hero combat, tower monitoring | None |
   | `INTERMISSION` | Wave cleared (more waves remain) | Tower repositioning | 30s; `phase_timer_tick` every second |
   | `MISSION_COMPLETE` | Final wave cleared | None | None |
   | `DEFEAT` | `hero_died` received | None | None |

8. On `mission_launched`: Wave Manager transitions `IDLE → SCOUT`. Reads `WaveConfig` from the mission resource. Reads `difficulty_tier: int` from the mission launch data. Reads SPAWN cells via `Grid.get_spawn_cells()`. Resets `_wave_index = 0`, `_round_robin_counter = 0`. If `wave_scripts.size() > 0` and `wave_scripts.size() < 5`, logs a content warning: `"WaveConfig has [N] wave_scripts — below the 5-wave minimum. is_penultimate_wave flag semantics may not behave as designed."` Mission continues; this surfaces authoring errors without blocking runtime.

    **Wave 1 preview on SCOUT entry:** Immediately on SCOUT entry, Wave Manager emits `wave_preview_available(next_wave_number: 1, composition: Array[WaveCompositionEntry], boss_spawn_cell: Vector2i)` (as a `WavePreviewEvent` Resource — see Rule 11's payload note; **corrected 2026-07-15, `/review-all-gdds`** — this was still stated as `Array[Dictionary]` after `event-bus.md` promoted it to `WaveCompositionEntry`/`WavePreviewEvent` Resource subclasses on 2026-07-15) using the same payload format as Rule 11 (one dict per unique `monster_id` with `count: int`; `boss_spawn_cell` per the Boss-lane telegraph note below Rule 11 — relevant only for the rare case of a 1-wave mission where wave 1 is also the final/boss wave, sentinel `Vector2i(-1,-1)` otherwise). This gives the player full wave 1 composition during tower placement — closing the "forewarning, not surprise" gap that would otherwise leave wave 1 as the only unpreviewed wave. **If `wave_scripts` is empty, skip this emit** (EC-6 handles the empty case). The Mission HUD must display this preview in the SCOUT phase HUD. *(Corrected 2026-07-15d — `/review-all-gdds` 6th pass: this previously said "same composition display it shows during INTERMISSION," which is no longer accurate. Per tower.md Rule 8's explicit SCOUT/Intermission asymmetry — SCOUT delivers full composition, Intermission delivers partial tier-only information — Mission HUD renders these as two distinct views: the full per-monster-type list at SCOUT [`mission-hud.md` Rule 11g] versus the tier-bucketed summary at INTERMISSION [Rule 11f]. Same UI panel location, different content.)*

9. `SCOUT → PRE_WAVE`: Triggered by 60s timer expiry **or** player pressing Ready (at any time ≥ `scout_phase_min_duration` elapsed — default 0s allows instant skip). Emits `mission_phase_changed` (SCOUT → PRE_WAVE). Starts 10s countdown. Emits `wave_countdown_warning` (seconds_remaining: 10) immediately on PRE_WAVE entry.

10. `PRE_WAVE → WAVE_ACTIVE`: When 10s countdown expires **or** player presses Ready during PRE_WAVE (instant skip). Pressing Ready during PRE_WAVE cancels the remaining countdown and transitions immediately:
    - a. Increments `_wave_index` (first wave: `_wave_index = 1`).
    - b. Computes `wave_reward_scalar` for this wave (see Formulas).
    - c. Emits `wave_started` (`wave_number`, `total_waves`, `wave_difficulty: wave_reward_scalar`).
    - d. Emits `mission_phase_changed` (PRE_WAVE → WAVE_ACTIVE).
    - e. Sets `_enemies_alive = 0`, `_all_spawns_fired = false`, `_wave_clear_fired = false`.
    - f. Resets `_round_robin_counter = 0`. Each wave starts its spawn cell distribution fresh.
    - g. Begins spawn sequencing for `wave_scripts[_wave_index - 1]`.

11. `WAVE_ACTIVE → INTERMISSION` (non-final wave): When wave is cleared (see Group 5), Wave Manager emits `wave_completed` (`wave_number`, `enemies_remaining: 0`, `was_boss_breached: false`), emits `mission_phase_changed` (WAVE_ACTIVE → INTERMISSION), starts 30s timer. Immediately on INTERMISSION entry, emits `wave_preview_available` (a `WavePreviewEvent` Resource — see Core Rule 4; **corrected 2026-07-15, `/review-all-gdds`**, was still described as raw `next_wave_number: int`, `composition: Array[Dictionary]`, `boss_spawn_cell: Vector2i` typed parameters after `event-bus.md`'s 2026-07-15 Resource promotion): `next_wave_number: int`, `composition: Array[WaveCompositionEntry]`, `boss_spawn_cell: Vector2i` — `composition` contains `WaveCompositionEntry` Resource instances (`monster_id: StringName`, `count: int`), aggregated across all `WaveSpawnEntry` items for the upcoming wave. Consumed by Mission HUD to display upcoming wave composition during the intermission window. **This event delivers the "forewarning, not surprise" player fantasy.** *(Corrected 2026-07-15d — `/review-all-gdds` 4th pass: `tower.md` Rule 8's Intermission display mandate previously described bucketing `composition` by monster "archetype," a field that does not exist on `MonsterResource` — it's Tower's own Foundation-component vocabulary. Mission HUD instead buckets by `tier` (STANDARD/ELITE/BOSS), resolved per-entry via `GameDataRegistry.get_monster(monster_id).tier`; `WaveCompositionEntry`'s schema is unchanged — no new field needed.)*

    **Boss-lane telegraph (`boss_spawn_cell`, added during `/design-review` 2026-07-14 re-review, resolves Tower GDD OQ-11):** `boss_spawn_cell: Vector2i` is **always present** in this payload (fixed-shape, matching this document's `monster_spawn_requested` convention — see AC-12). When the upcoming wave (`next_wave_number == wave_scripts.size()`, i.e. the final wave — the only wave that can contain a BOSS per Rule 6) is being previewed, `boss_spawn_cell` resolves to the actual grid cell the BOSS's `WaveSpawnEntry` will spawn at: `spawn_cells[entries[last].spawn_cell_index % spawn_cells.size()]` (post-EC-7-modulo-wrap value, not the raw authored index — consistent with the resolved value Rule 15b actually uses at spawn time). This is resolvable at preview time only because Rule 6 now forbids round-robin (`spawn_cell_index = -1`) on the BOSS entry. For every other wave, `boss_spawn_cell` is the sentinel `Vector2i(-1, -1)`. **No separate `has_boss` field is emitted** — the player (or Mission HUD) can already derive boss presence for the previewed wave from `next_wave_number == total_waves` (available via the prior `wave_started` event), and the `composition` array already contains the boss's actual `monster_id` — an additional boolean would be a second source of truth for a fact the payload already carries, risking desync. **Design rationale (Tower OQ-11):** without spawn-cell information, a T4 Foundation's boss-lane investment (`tier_boss_dps_multiplier`) was committed blind — the player had no way to validate T4 placement against where the boss would actually appear. *(Corrected 2026-07-15: this note previously also cited "Siege shield-penetration" as part of T4's boss-lane investment — the Siege mechanic was struck from tower.md this session; T4's identity is `tier_boss_dps_multiplier` alone.)* This is a deliberate, narrow exception to the partial-information model above: only spatial/positional information is exposed (where), never composition, stats, HP, or attack damage (what/how much) — the player still supplies the read ("is this lane worth a T4 commitment"), preserving the "I read it correctly" retrospective-vindication fantasy this document's Player Fantasy section is built around, rather than converting it into a checklist.

12. `INTERMISSION → PRE_WAVE`: Triggered by 30s timer expiry **or** player pressing Ready. Emits `mission_phase_changed` (INTERMISSION → PRE_WAVE). Starts 10s countdown.

12a. **Frame-yield contract between `wave_completed` and the next `wave_started`** *(added 2026-07-15 — `/review-all-gdds` found Tower System depends on this guarantee but it was never stated here explicitly)*: Wave Manager guarantees **at least one frame elapses** between emitting `wave_completed` (Rules 11/13/20c) and emitting the next `wave_started` (Rule 10c). This is not an independent timer — it is a structural consequence of the state machine: a non-final wave's clear passes through two full phase transitions before the next `wave_started` (`WAVE_ACTIVE → INTERMISSION`, Rule 11; then `INTERMISSION → PRE_WAVE`, Rule 12; then `PRE_WAVE → WAVE_ACTIVE`, Rule 10), each gated by either a timer (guaranteed >0 frames to elapse) or explicit player input (which cannot be processed in the same frame as the event that made the Ready button available — Godot's input system always trails the emitting frame by at least one). There is no code path in this state machine where `wave_completed` and the following `wave_started` can fire in the same frame. **This is a binding invariant, not an incidental property**: Tower System's targeting cache (`_monster_cache`) and per-wave counters (`tower_wave_summary`) rely on at least one frame of separation to fully drain in-flight `CONNECT_DEFERRED` cache mutations before the next wave's spawns begin (see `tower.md`'s signal subscription mode table). **Any future change that collapses a phase transition (e.g., allowing `INTERMISSION → WAVE_ACTIVE` directly, skipping `PRE_WAVE`) must preserve this guarantee** or explicitly renegotiate it with the Tower System GDD before shipping — nothing currently enforces it beyond this state machine's own structure, so a future phase-skip change could silently violate it with no automated test to catch the regression. See AC-43 for the mechanical assertion of this guarantee.

13. `WAVE_ACTIVE → MISSION_COMPLETE` (final wave cleared): Emits `wave_completed` (`wave_number`, `enemies_remaining: 0`, `was_boss_breached: false`), then `mission_phase_changed` (WAVE_ACTIVE → MISSION_COMPLETE). Stops all spawn sequencing and timers.

14. Any active state → `DEFEAT`: On `hero_died`, Wave Manager sets `_phase_locked = true`, stops all timers and spawn sequencing, emits `mission_phase_changed` (current_state → DEFEAT). If `hero_died` and a wave-clear signal arrive in the same frame, DEFEAT takes priority — the wave-clear is discarded.

    **Design intent (non-negotiable):** `hero_died` = DEFEAT is intentional and permanent. The hero is not "one battlefield asset" — the hero is the player's embodied agency on the battlefield. The commander archetype (strategic frame) and the hero (tactical instrument) fail together because the game ends when the player can no longer act. This failure condition must not be changed to a "hero-respawn" or "continue without hero" model without a full game-concept revision. Future systems must not attempt to suppress or reroute `hero_died` → DEFEAT.

---

#### Group 4 — Spawn Sequencing

15. On WAVE_ACTIVE entry, Wave Manager executes the current wave's `entries` array sequentially:
    - a. Wait `entries[i].pre_delay` seconds.
    - b. Determine `spawn_cell`: if `entries[i].spawn_cell_index >= 0` → use `spawn_cells[entries[i].spawn_cell_index % spawn_cells.size()]`; if `-1` → `spawn_cells[_round_robin_counter % spawn_cells.size()]` (increment `_round_robin_counter`).
    - c. Emit `monster_spawn_requested` (`monster_id`, `spawn_cell`, `wave_index: _wave_index`, `difficulty_tier`, `wave_reward_scalar`, `is_penultimate_wave: bool`). `is_penultimate_wave` is `true` when `_wave_index == wave_scripts.size() - 1` (the second-to-last wave) AND `wave_scripts.size() >= 5`; `false` in all other cases. **Sub-5-wave guard:** if `wave_scripts.size() < 5`, `is_penultimate_wave` is always `false` — the penultimate constraint does not apply to missions below the 5-wave minimum, and the ELITE HP amplifier must not fire for these configs. The Monster System uses `is_penultimate_wave` to apply the ELITE HP amplifier (formula F4 in Monster System GDD) — this replaces the hardcoded `wave_index == 4` condition in that formula, making amplification relative to mission length rather than absolute. **Note:** `wave_reward_scalar` is for Resource Economy consumption only — the Monster System must not apply it to HP, speed, or combat stats.
    - d. Advance to `entries[i+1]`.

16. After the last entry fires, set `_all_spawns_fired = true`. Wave-clear check runs immediately (see Group 5).

17. Spawn sequencing is fire-and-forget. Wave Manager does not await confirmation from Monster System. Aborted spawns (unknown `monster_id`, invalid cell logged by Monster System) are not retried.

---

#### Group 5 — Wave-Clear Detection

18. `_enemies_alive` tracking during WAVE_ACTIVE:
    - `+1` on `monster_spawned` received. **Phase guard**: this increment is processed only when the current phase is `WAVE_ACTIVE`. If `monster_spawned` arrives in any other phase (e.g., a deferred Monster System instantiation arriving in INTERMISSION after a BOSS breach), the event is discarded and a warning is logged: `"monster_spawned received outside WAVE_ACTIVE (phase: [phase]) — discarded."` This prevents stray spawned events from corrupting `_enemies_alive` for the next wave.
    - `-1` on `monster_died` received (clamped at minimum 0).
    - `-N` on `monsters_died_batch` received. **Precondition**: `count` must be `>= 1`. If `count <= 0`, discard the event and log a warning: `"monsters_died_batch received with invalid count [N] — discarded."` Do not modify `_enemies_alive`. If count is valid, decrement by `count: int` (clamped at minimum 0). Wave Manager subscribes to both individual `monster_died` and batched `monsters_died_batch` — whichever the Monster System emits, the count remains accurate. **OQ-1 resolved.**
    - `-1` on `monster_breached` received (any tier, clamped at minimum 0).

19. Standard wave-clear condition: `_all_spawns_fired == true AND _enemies_alive == 0`. Checked after every decrement.

20. **`boss_died` fast-path**: The `_on_boss_died()` handler checks `_wave_clear_fired` as its **second** operation (after EC-5b's phase-equality guard). If `_wave_clear_fired == true`, the event is discarded immediately — a stray `boss_died(cause: "force_removed")` from Monster System cleanup cannot re-trigger wave-clear if the current phase is still WAVE_ACTIVE but wave-clear has already fired in this frame. Otherwise, sets `_wave_clear_fired = true` before proceeding. Wave Manager immediately clears the wave regardless of `_enemies_alive`. Emits `wave_completed` (`wave_number`, `enemies_remaining: 0`, `was_boss_breached: false`) — the BOSS was killed, not breached. If final wave: triggers MISSION_COMPLETE. If non-final wave: triggers INTERMISSION. Monster System force-removes remaining entities on `wave_completed`.

21. **BOSS breach fast-path**: The full BOSS breach sequence is:
    - **(a)** Monster System processes the breach: the BOSS entity reaches the map exit, emits `monster_breached(tier==2)`, and is immediately despawned. The entity is removed from the scene before any subscriber receives the event.
    - **(b)** Monster System applies hero breach damage through its own breach-damage path (independent of Wave Manager). Wave Manager takes no action on hero HP.
    - **(c)** Wave Manager receives `monster_breached(tier==2)`. Sets `_wave_clear_fired = true` before emitting anything, then triggers immediate wave-clear. Emits `wave_completed` (`wave_number`, `enemies_remaining: 0`, `was_boss_breached: true`) — this is the one path where `was_boss_breached` is `true`. Monster System force-removes any remaining alive monsters on `wave_completed`.

    **Invariant — BOSS-alive cannot coexist with INTERMISSION.** The force-clear on `wave_completed` is the enforcement: by the time INTERMISSION starts, both the BOSS (despawned at breach) and all other alive monsters (force-removed by Monster System on `wave_completed`) are gone from the scene.

    BOSS breach is **not** DEFEAT. Only `hero_died` triggers DEFEAT.

---

#### Group 6 — Pathfinding Synchronization

22. Pathfinding templates build asynchronously during SCOUT phase — they are constructed after the Grid receives its `GridConfig` via EventBus, not during `_ready()` or the `mission_launched` → SCOUT transition. When all N templates are built, the Pathfinding System emits `templates_ready(spawn_count: int, build_duration_ms: float)` via EventBus. **Wave Manager subscribes to `templates_ready` and must not emit `monster_spawn_requested` until this event fires.** Phase ordering alone does not guarantee template readiness — the explicit event subscription is required. This closes Pathfinding System OQ-2 (Option a: event-based synchronization).
    **Secondary gate for waves 2+ (INTERMISSION→WAVE_ACTIVE):** A deferred template rebuild may be in progress when WaveManager transitions from INTERMISSION to PRE_WAVE (if the player placed or removed a tower late in INTERMISSION, or if a BOSS destroyed a tower in the preceding wave). To prevent the first monster of wave N+1 from receiving stale path data: at the INTERMISSION→PRE_WAVE transition, WaveManager must call `PathfindingSystem.is_rebuild_pending() -> bool` **once**. If it returns `true`, WaveManager subscribes to `path_invalidated` on EventBus and holds the spawn sequencing coroutine until that event fires before emitting `monster_spawn_requested`. If it returns `false`, WaveManager proceeds immediately. `is_rebuild_pending()` is a public API on PathfindingSystem that returns the current value of `_rebuild_queued` — no internal state exposure required. **Implementation constraint:** `_templates_ready: bool` and `_rebuild_pending_gate: bool` track these two gates independently. The spawn sequencing coroutine checks both before firing the first `monster_spawn_requested` of each wave; Wave 1 uses the `templates_ready` event; waves 2+ use `is_rebuild_pending()` + optional `path_invalidated` await.

    **`_rebuild_pending_gate` lifecycle (Rule 22 field):**
    - **Set `true`**: at the INTERMISSION→PRE_WAVE transition, immediately after `is_rebuild_pending()` returns `true`.
    - **Set `false`**: immediately when `path_invalidated` is received and the gate is released; also on `mission_launched` (see EC-9).
    - **Early-fire guard**: if `path_invalidated` fires during the PRE_WAVE countdown (before the spawn coroutine starts), `_rebuild_pending_gate` is already `false` by the time the coroutine runs. The coroutine must check `_rebuild_pending_gate` at its start — if `false`, proceed immediately without awaiting. Do NOT await a signal that has already fired.

    **Coroutine phase-check guard (applies to all await boundaries):** The spawn sequencing coroutine must check `phase == WAVE_ACTIVE` **immediately after every `await` boundary** (`templates_ready`, `path_invalidated`). If the phase is no longer `WAVE_ACTIVE` when the coroutine resumes (e.g., a `boss_died` fast-path cleared wave 1 before `templates_ready` arrived, advancing to INTERMISSION), the coroutine must abort without emitting any `monster_spawn_requested` events. Reason: a late `templates_ready` or `path_invalidated` firing during INTERMISSION must not trigger spawns for a wave that has already been cleared.

    **Wave-index gate selection**: The spawn sequencing coroutine uses `_wave_index` to select the active gate. If `_wave_index == 1`, the coroutine awaits `_templates_ready == true` (set by the `templates_ready` EventBus subscription) before firing the first `monster_spawn_requested` — this is the only gate for wave 1. If `_wave_index > 1`, the coroutine checks `_rebuild_pending_gate` at its start and optionally awaits `path_invalidated` if the gate is set; `_templates_ready` is not re-checked for waves 2+ (it is already `true` from wave 1 and does not reset between waves). The two gates are mutually exclusive per wave — never both checked in the same wave.

    **`templates_ready` handler phase contract**: The `_on_templates_ready()` handler sets `_templates_ready = true` **unconditionally — no phase guard**. This ensures the latch is set even if the player presses Ready during the same frame `templates_ready` fires (transitioning SCOUT → PRE_WAVE before the handler executes). Without this guarantee, if a phase guard discarded the signal outside SCOUT, the spawn coroutine would await a signal that has already fired — a deadlock. The handler is safe to call outside SCOUT because `_templates_ready = true` in a non-SCOUT phase is harmless: the spawn coroutine only reads it, and EC-9's reset clears it before the next mission.

    **`templates_ready` subscription lifecycle**: Wave Manager remains subscribed to `templates_ready` for the full mission duration — no disconnect is required. Re-receipt after the `_templates_ready` latch is set is harmless (the handler re-sets `true` to `true`). This is intentionally different from the `path_invalidated` subscription, which must disconnect on gate release to prevent handler accumulation across waves.

    **`path_invalidated` subscription lifecycle**: Wave Manager disconnects the `path_invalidated` subscription immediately when `_rebuild_pending_gate` is released (i.e., when `path_invalidated` is received and the gate clears). This prevents subscription accumulation across waves: without explicit disconnection, repeated `is_rebuild_pending() == true` transitions across waves 2–8 would accumulate connections and cause the handler to fire once per accumulated connection on each subsequent `path_invalidated` event.

---

#### Group 7 — Wave-Stuck Watchdog

23. **Stuck-wave watchdog and stall signal**: When `_all_spawns_fired` transitions to `true` during WAVE_ACTIVE with `_enemies_alive > 0`, the watchdog timer starts. Two events fire as the timer progresses:

    - **30s mark** (`wave_stall_warning` threshold): Wave Manager emits `wave_stalled` (`wave_number: int`, `enemies_remaining: int`). Mission HUD consumes this to surface "X enemies remaining" to the player — providing legible feedback that monsters still exist before the force-clear fires.
    - **60s mark** (force-clear): Sets `_wave_clear_fired = true`. Wave Manager logs an error (`"Wave [N] stuck: _enemies_alive=[N], all spawns fired. Forcing wave-clear. Check Monster System entity lifecycle."`) and emits `wave_completed(wave_number: N, enemies_remaining: <current stuck count>, was_boss_breached: false)` (force-clear — `enemies_remaining` carries the non-zero count at the moment of force-clear, not 0), then advances to INTERMISSION or MISSION_COMPLETE as normal.

    Default `wave_stuck_timeout`: 60s. `wave_stall_warning`: 30s. Both are dev-only constants, not authored-per-mission `WaveConfig` fields. This safety net must never trigger in a correctly authored and tested mission. If the Monster System GDD formally specifies a lifetime guarantee that every spawned entity eventually emits `monster_died` or `monster_breached`, the force-clear may be downgraded to a debug-only assert — but `wave_stalled` should still emit for player visibility. **See OQ-5.**

---

### States and Transitions

| From | To | Trigger |
|------|----|---------|
| `IDLE` | `SCOUT` | `mission_launched` received |
| `SCOUT` | `PRE_WAVE` | 60s timer expires **or** player presses Ready |
| `PRE_WAVE` | `WAVE_ACTIVE` | 10s countdown expires **or** player presses Ready |
| `WAVE_ACTIVE` | `INTERMISSION` | Wave cleared (non-final wave) |
| `WAVE_ACTIVE` | `MISSION_COMPLETE` | Wave cleared (final wave) |
| `INTERMISSION` | `PRE_WAVE` | 30s timer expires **or** player presses Ready |
| Any active state | `DEFEAT` | `hero_died` received |

---

### Interactions with Other Systems

| System | Direction | Data | Mechanism | When |
|--------|-----------|------|-----------|------|
| **EventBus** | → emits | `mission_phase_changed`, `wave_started`, `wave_completed`, `wave_countdown_warning`, `phase_timer_tick`, `monster_spawn_requested`, `wave_preview_available`, `wave_stalled` | EventBus signal | Per phase transition, per countdown tick, per spawn, per INTERMISSION entry, on stall |
| **EventBus** | ← subscribes | `monster_spawned`, `monster_died`, `monsters_died_batch`, `monster_breached`, `boss_died`, `hero_died`, `mission_launched`, `run_modifier_selected`, `templates_ready`, `path_invalidated` (conditional — subscribed at INTERMISSION→PRE_WAVE when `is_rebuild_pending()` returns `true`; disconnected immediately after `_rebuild_pending_gate` releases) | EventBus signal | Continuous during mission; `templates_ready` gates first `monster_spawn_requested`; `path_invalidated` gates wave 2+ first spawn when rebuild is pending |
| **Grid** | ← reads | `Grid.get_spawn_cells() -> Array[Vector2i]` | Direct Autoload call | Once at `mission_launched` |
| **Monster System** | → Monster | `monster_spawn_requested` events | EventBus | Per spawn entry during WAVE_ACTIVE |
| **Monster System** | ← Monster | `monster_spawned`, `monster_died`, `monster_breached`, `boss_died` | EventBus | Per entity lifecycle event |
| **Mission HUD** | → HUD | `wave_started`, `wave_completed`, `wave_countdown_warning`, `phase_timer_tick`, `mission_phase_changed`, `wave_preview_available`, `wave_stalled` | EventBus | Continuously during mission |
| **Hero System** | ← Hero | `hero_died` → triggers DEFEAT | EventBus | When hero HP reaches 0 |
| **Mission Select System** | ← | `run_modifier_selected` (`"extend_waves"`/`"difficulty_growth_boost"`, value) | EventBus | SCOUT phase before first PRE_WAVE. *(Corrected 2026-07-17 — Mission Select is the confirmed sole sender; see `mission-select.md` Rule 5/AC-9.)* |
| **Tarot System** | ← | `mission_modifier_applied` (`modifier_type` ∈ {`tarot_reward_scalar_mult`, `tarot_difficulty_growth_rate`, `tarot_wave_config_override`}) | EventBus | SCOUT phase before first PRE_WAVE. *(Split out 2026-07-17 — Tarot never sends `run_modifier_selected`; that was a misattribution. Tarot's actual contribution to Wave Manager is this separate, already-resolved channel — see `tarot.md` AC-18 and Rule 7.)* |
| **Pathfinding** | ← subscribes | `templates_ready(spawn_count, build_duration_ms)` — gates first `monster_spawn_requested` | EventBus subscription | SCOUT phase; fires after templates built from GridConfig |

## Formulas

#### F1 — Wave Reward Scalar

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `wave_index` | `w` | int | 1–8 | Current wave number within the mission |
| `difficulty_growth_rate` | `r` | float | 0.15–0.25 | Per-wave exponential growth. Authored per `WaveConfig`. Default: 0.20 |
| `wave_reward_scalar` | `s` | float | 1.00–4.768 | Composite reward scalar passed in `monster_spawn_requested` and surfaced as `wave_difficulty` in `wave_started` |

**Expression:**
```
wave_reward_scalar = 1.0 × (1 + r) ^ (w - 1)
```

**Output range:** 1.00× at wave 1 → up to 4.768× at wave 8 (r=0.25 ceiling).

**Purpose:** Passed as `wave_reward_scalar` in every `monster_spawn_requested` payload. Also emitted as the `wave_difficulty` field in `wave_started` (same value — for Mission HUD display). The Monster System uses `wave_index` directly for its own HP/speed linear scaling — `wave_reward_scalar` is for Resource Economy only and must not influence combat stats.

**Semantic contract — two reward dimensions (resolved):** The Resource Economy GDD must anchor to this scalar for exactly two output dimensions:
1. **Drop quantity**: Number of material items dropped per monster kill, multiplied by `wave_reward_scalar`.
2. **Drop quality percentage**: Probability of obtaining higher-quality material tiers, multiplied by `wave_reward_scalar`. `base_quality` is the high-quality drop probability at wave 1 specifically (when `wave_reward_scalar = 1.0`). **Constraint**: `base_quality` is a **single global constant** — it does not vary per-mission or per-difficulty. It must satisfy `base_quality × 4.768 ≤ 1.0`, giving a hard ceiling of **≤ 20.97%**. This constraint uses the absolute worst-case scalar across all authored WaveConfigs (r=0.25, wave 8 = 4.768×), not the scalar of any individual mission. A `base_quality` that is legal for a default r=0.20 mission (e.g., 25% × 3.583 = 89.6% — seemingly safe) will overflow to 119.2% on any r=0.25 hard mission. Per-mission `r` variation is not a basis for relaxing the base_quality ceiling. The Resource Economy GDD must register this as `MAX_BASE_QUALITY_PROBABILITY = 0.2097` and the AC-19b CI validator must verify `base_quality × 4.768 ≤ 1.0` for every WaveConfig it validates. **TODO: Resource Economy GDD must define `max_base_quality_probability` as a global constant ≤ 20.97%.**

**Combined ERI ceiling (forward contract):** Because `wave_reward_scalar` multiplies both output dimensions simultaneously, the combined economic return index at maximum settings is `wave_reward_scalar_max^2 = 4.768^2 = 22.73×` wave-1 baseline. The project constant `WAVE_ERI_CEILING_COMBINED = 22.73` is registered in `design/registry/entities.yaml` (owner: Resource Economy GDD — pending authoring). The Resource Economy GDD must define `MAX_COMBINED_ERI` anchored to this registered value, calibrating base drop rates so the combined quantity × quality output stays within the intended economy envelope. **Wave Manager specifies the scalar; Resource Economy owns the ceiling calibration.** The constant `max_base_quality_probability` (already forward-referenced above) is the per-dimension enforcement mechanism; `MAX_COMBINED_ERI` is the cross-dimension ceiling. **The Resource Economy GDD must back-solve base drop rates from an absolute mission-yield target, not forward from wave-1 feel alone** — see `WAVE_ERI_CEILING_COMBINED` registry entry for the constraint anchor.

`wave_reward_scalar` does **not** affect Monster HP, speed, count, or combat behaviour. The two scaling systems are intentionally separate: this formula produces continuous compounding for economy escalation; Monster HP/speed use linear `wave_index` scaling for deterministic budget calculations.

**Runtime validation**: On `mission_launched`, Wave Manager validates `0.10 ≤ r ≤ 0.25`. If violated, logs a content error. The value is not clamped — the mission continues with the authored value so the authoring error surface is visible during playtest. The upper bound is 0.25 (not 0.30) — at r=0.30 the wave 8 output reaches 6.275×, breaking the base drop quality probability cap (see semantic contract above).

**Full boundary table** (for r range 0.15–0.25):

| r | Wave 4 | Wave 8 |
|---|--------|--------|
| 0.15 | 1.521× | 2.660× |
| 0.20 | 1.728× | 3.583× |
| 0.25 | 1.953× | 4.768× |

**Worked example (default r=0.20):**

| Wave | Calculation | Scalar |
|------|-------------|--------|
| 1 | `1.0 × 1.20^0` | 1.00× |
| 4 | `1.0 × 1.20^3` | 1.73× |
| 8 | `1.0 × 1.20^7` | 3.583× |

---

#### F2 — Phase Timer Tick

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `phase_duration` | `D` | float | 10–120 | Full duration of the current phase (60s SCOUT default, 30s INTERMISSION default; tuning ranges in Tuning Knobs section) |
| `elapsed` | `e` | float | 0–D | Seconds elapsed since phase start |
| `seconds_remaining` | `t` | float | 0–D | Remaining seconds for `phase_timer_tick` payload |

**Expression:**
```
seconds_remaining = max(0.0, phase_duration - elapsed)
```
`phase_timer_tick` fires every 1.0 second during SCOUT, PRE_WAVE, and INTERMISSION. Payload: `phase: String`, `seconds_remaining: float` (floored to nearest int for display). The `max(0.0, …)` clamp prevents frame-boundary slop (timer firing at `elapsed = phase_duration + one_frame_slop`) from producing a negative seconds_remaining value on the HUD.

**Purpose:** Powers the Mission HUD countdown display. No gameplay logic depends on this value — display signal only.

**Type note:** F2 applies to `phase_timer_tick` (emitted every 1.0s during SCOUT, PRE_WAVE, and INTERMISSION — PRE_WAVE added 2026-08-13; see below). `wave_countdown_warning` is a separate signal with a different contract: it fires once at PRE_WAVE entry with `seconds_remaining: int` (a fixed integral value — 10 at default `pre_wave_countdown`). The `int` type for `wave_countdown_warning.seconds_remaining` matches the UI Requirements table and is not subject to F2's float flooring logic. `phase_timer_tick` was originally scoped to SCOUT/INTERMISSION only, with `wave_countdown_warning`'s single entry-time firing considered sufficient for PRE_WAVE. In practice this left the HUD frozen on a static "Wave incoming: 10s" for the entire PRE_WAVE window (no per-second update after entry) — a real, player-visible gap, not a hypothetical. `phase_timer_tick` now also ticks during PRE_WAVE to close it; `wave_countdown_warning` is unchanged (still fires once at entry, still drives the entry-moment audio sting per `event-bus.md`).

## Edge Cases

### EC-1 — `hero_died` received during INTERMISSION

The player dies in INTERMISSION (possible if a BOSS breach damaged the hero). Wave Manager immediately transitions to DEFEAT. The 30s intermission timer is stopped. All state is locked (`_phase_locked = true`). The partial INTERMISSION does not count as completed.

---

### EC-2 — Player presses Ready at t=0 of SCOUT (instant skip)

A player who immediately presses Ready skips the Scout phase with zero elapsed time. Wave Manager transitions to PRE_WAVE and begins the 10s countdown. Pathfinding templates are guaranteed complete before any `monster_spawn_requested` fires: Wave Manager gates spawn sequencing on `templates_ready` (Rule 22), which fires after templates build from `GridConfig` during SCOUT. The 10s PRE_WAVE countdown provides additional buffer, but the `templates_ready` subscription is the hard gate — not the countdown timer.

---

### EC-3 — `boss_died` received before `_all_spawns_fired == true`

The BOSS is killed before all spawn entries in the wave have fired. Wave Manager triggers the `boss_died` fast-path immediately: wave is cleared, remaining spawn entries are discarded without firing. `_all_spawns_fired` is set to `true` as a side effect of clearing. Monster System force-removes any still-alive monsters on receiving `wave_completed`. No gap condition: the spawn coroutine is cancelled, not paused.

**Synchronous cancellation guarantee**: The `_on_boss_died()` handler cancels the spawn coroutine as its first substantive action, before emitting `wave_completed` or advancing phase state. Cancellation is synchronous within the same `_process` tick — no further spawn entries execute and no further `_round_robin_counter` increments occur after the handler fires. `_round_robin_counter` retains whatever value it held at cancellation; Rule 10f's reset at the next WAVE_ACTIVE entry overwrites it.

---

### EC-4 — `hero_died` and wave-clear signal arrive in the same frame

`hero_died` takes absolute priority. DEFEAT is triggered immediately; the wave-clear signal is discarded. `_phase_locked = true` is set before processing any further events in the same frame. This is consistent with Rule 14.

---

### EC-5 — Monster entity removed before `wave_completed` is processed

When `boss_died` fast-path triggers `wave_completed`, Monster System begins force-removing remaining alive entities. These removals emit `monster_died` events. Wave Manager receives them during or after the INTERMISSION/MISSION_COMPLETE transition. Because `_phase_locked` is set on MISSION_COMPLETE (not INTERMISSION), these stray `monster_died` events could decrement `_enemies_alive` below 0. **Handling**: `_enemies_alive` is clamped at 0. Any decrement below 0 is logged as a warning but does not trigger additional wave-clear checks — the phase has already advanced.

---

### EC-5b — Stray `boss_died` received outside WAVE_ACTIVE

Monster System Rule 28b emits `boss_died(cause: "force_removed")` when force-removing a BOSS entity during `wave_completed` cleanup. If Wave Manager has already advanced to INTERMISSION or MISSION_COMPLETE, the stray `boss_died` must be a no-op — it must NOT trigger Rule 20's wave-clear fast-path again.

**Handling**: The `_on_boss_died()` handler applies two sequential guards as its first operations before executing any wave-clear logic:
1. **Phase-equality guard**: If the current phase is not `WAVE_ACTIVE`, the event is discarded immediately.
2. **Wave-clear latch guard**: If `_wave_clear_fired == true`, the event is discarded immediately — this catches stray `boss_died(cause: "force_removed")` that arrive while the phase is still nominally WAVE_ACTIVE but wave-clear has already executed in the same frame (see Rule 20 for the latch; Rule 21c for the BOSS breach path that also sets it).

**Note**: AC-8's `_phase_locked` guard covers DEFEAT and MISSION_COMPLETE. INTERMISSION requires the phase-equality check (guard 1 above), since `_phase_locked` is not set on INTERMISSION. The `_wave_clear_fired` latch (guard 2) covers the within-WAVE_ACTIVE same-frame re-trigger race that neither `_phase_locked` nor phase-equality can catch.

---

### EC-6 — `WaveConfig.wave_scripts` is empty (zero waves authored)

Content constraint violation. Wave Manager logs an error: `"WaveConfig has 0 wave_scripts — mission has no waves. Triggering MISSION_COMPLETE immediately."` Then emits `mission_phase_changed` (SCOUT → MISSION_COMPLETE). No PRE_WAVE, no WAVE_ACTIVE, no INTERMISSION. This is a content authoring error; it is logged and handled gracefully rather than crashing.

---

### EC-7 — `spawn_cell_index` out of range (positive index exceeds spawn cell count)

The authored `spawn_cell_index` exceeds `spawn_cells.size() - 1`. Wave Manager applies modulo wrap: `spawn_cells[entries[i].spawn_cell_index % spawn_cells.size()]`. This silently recovers from an authoring error without crashing. A warning is logged: `"spawn_cell_index [N] out of range — wrapping to [M]."` Same behaviour as Rule 15b.

---

### EC-8 — Player presses Ready during PRE_WAVE countdown

Ready button **is active** during PRE_WAVE. Pressing Ready during PRE_WAVE cancels the remaining countdown and immediately transitions to WAVE_ACTIVE, bypassing the rest of the 10s timer. This rewards decisive players who resolve their intermission debrief quickly. Mission HUD should NOT disable the Ready button during PRE_WAVE.

---

### EC-9 — Mission restart (loss → restart) with Wave Manager in non-IDLE state

If the player restarts the mission from the DEFEAT or MISSION_COMPLETE screen, the Wave Manager must return to IDLE before receiving the new `mission_launched` event. All internal state is reset: `_phase_locked = false`, all timers stopped, all spawn sequencing cancelled, `_wave_index = 0`, `_round_robin_counter = 0`, `_enemies_alive = 0`, `_all_spawns_fired = false`, `_wave_clear_fired = false`, `_templates_ready = false`, `_rebuild_pending_gate = false`. The new `WaveConfig` is loaded fresh on the subsequent `mission_launched`. No stale state from the previous run persists.

**Critical**: `_templates_ready` must be reset to `false`. If stale `true` from the prior mission persists, the wave-1 pathfinding gate (Rule 22) is bypassed on the new mission — a player pressing Ready at t=0 of SCOUT on mission 2 can enter WAVE_ACTIVE before Pathfinding has rebuilt templates for the (potentially different) map layout.

---

### EC-10 — BOSS authored at a non-last position in WaveScript

Content constraint violation: a `WaveSpawnEntry` with a BOSS `monster_id` appears at any index other than the final entry in a `WaveScript`. At runtime, when the BOSS dies or breaches, the `boss_died` / BOSS breach fast-path (Rules 20–21) clears the wave immediately — all un-fired entries after the BOSS index are discarded. The wave ends 30–50% through its intended spawn list with no player-visible indication of the missing monsters.

**Detection**: DEBUG assert in Wave Manager on `mission_launched`. On receiving the event, Wave Manager iterates each `WaveScript.entries` array: for every entry at any index less than `entries.size() - 1`, if the `monster_id` resolves to a BOSS-tier MonsterResource, log an error: `"WaveScript[N] authoring error: BOSS entry at position [i] is not the last entry. Entries at indices [i+1 … end] will never fire if the BOSS is killed or breached."` The assert fires in DEBUG builds only; the mission continues without crashing.

**Scope**: Content authoring error. The fast-path logic in Rules 20–21 is correct — this EC documents the downstream consequence of violating Rule 6's content constraint.

### EC-11 — `Grid.get_spawn_cells()` returns an empty array

Content constraint violation: the mission map has no SPAWN cells. Wave Manager calls `Grid.get_spawn_cells()` once on `mission_launched` (Rule 8). If the result is empty (`spawn_cells.size() == 0`), Rule 15b's round-robin (`spawn_cells[_round_robin_counter % spawn_cells.size()]`) and the positive-index path (`spawn_cells[entries[i].spawn_cell_index % spawn_cells.size()]`) both divide by zero — a runtime crash.

**Handling**: Wave Manager validates `spawn_cells.size() > 0` immediately after the `Grid.get_spawn_cells()` call. If the check fails, logs an error: `"WaveConfig mission map has 0 spawn cells — cannot spawn any monsters. Triggering MISSION_COMPLETE immediately."` Then emits `mission_phase_changed` (SCOUT → MISSION_COMPLETE). No PRE_WAVE, no WAVE_ACTIVE, no spawn sequencing. This is a content authoring error; it is logged and handled gracefully rather than crashing (same pattern as EC-6).

---

## Dependencies

### Upstream — Systems the Wave Manager depends on

| System | What Wave Manager needs from it | How |
|--------|--------------------------------|-----|
| **EventBus** | Signal bus for all cross-system communication; `mission_launched`, `monster_spawned`, `monster_died`, `monster_breached`, `boss_died`, `hero_died`, `run_modifier_selected` subscriptions | Subscribe on `_ready()` |
| **Grid** | `Grid.get_spawn_cells() → Array[Vector2i]` — the set of valid spawn cell positions for this mission map | Direct Autoload call once at `mission_launched` |
| **Monster System** | Source of `monster_spawned`, `monster_died`, `monster_breached`, `boss_died` events that drive `_enemies_alive` tracking and wave-clear detection | EventBus subscriptions |
| **Pathfinding System** | `templates_ready` event must be received before the first `monster_spawn_requested` fires. Wave Manager subscribes to `templates_ready` via EventBus and gates spawn sequencing on its receipt. (Pathfinding OQ-2 resolved — Option a: event-based synchronization.) | EventBus subscription |

### Downstream — Systems that depend on Wave Manager

| System | What it needs from Wave Manager | How |
|--------|--------------------------------|-----|
| **Monster System** | `monster_spawn_requested` (6-field payload: `monster_id`, `spawn_cell`, `wave_index`, `difficulty_tier`, `wave_reward_scalar`, `is_penultimate_wave: bool`) to instantiate entities; `wave_completed` (`wave_number`, `enemies_remaining`, `was_boss_breached: bool`) to force-remove survivors | EventBus |
| **Mission HUD** | `mission_phase_changed`, `wave_started`, `wave_completed`, `wave_countdown_warning`, `phase_timer_tick` for all phase displays and countdown timers | EventBus |
| **Mission Select System** | `run_modifier_selected` is **sent to** Wave Manager during SCOUT (Mission Select → Wave Manager one-way); Wave Manager reads the modifier as configuration. *(Corrected 2026-07-17 — this row previously named Tarot as the sender, which was wrong; Mission Select is the confirmed sole sender, see `mission-select.md` Rule 5/AC-9 and `tarot.md` AC-18.)* | EventBus |
| **Tarot System** | `mission_modifier_applied` is **sent to** Wave Manager during SCOUT (Tarot → Wave Manager one-way, separate channel from `run_modifier_selected` above); Wave Manager reads the modifier as configuration. Tarot does not subscribe to Wave Manager events during WAVE_ACTIVE — no runtime cycle. | EventBus |
| **Resource Economy System** | `wave_reward_scalar` in `monster_spawn_requested` payload used to scale material drop quantity and drop quality percentage | EventBus payload field |
| **Mission HUD (wave preview)** | `wave_preview_available` (`next_wave_number`, `composition`, `boss_spawn_cell`) emitted at INTERMISSION entry — enables the "forewarning, not surprise" player experience; `boss_spawn_cell` additionally enables Tower System's T4 boss-lane placement legibility (see Rule 11's Boss-lane telegraph, resolves Tower GDD OQ-11) | EventBus |
| **Mission HUD (stall feedback)** | `wave_stalled` (`wave_number`, `enemies_remaining`) emitted 30s into a stuck wave — enables "X enemies remaining" display before force-clear | EventBus |
| **Damage & Status System** | `wave_completed` for end-of-wave state cleanup (D&S cross-GDD follow-up from D&S pass 6) | EventBus |
| **Constellation System** | `wave_started`, `wave_completed` to track wave-scoped constellation activation windows | EventBus |
| **Save & Persistence** | Wave Manager is stateless between missions (no persistent wave progress). No direct dependency. Wave index and difficulty tier are fully re-initialized at each `mission_launched`. | None |

### Scout Phase Economy (TODO)

The player's initial resource pool at mission start (what they spend during SCOUT on tower placement) is delivered by the Resource Economy System. The mechanism — event type, payload, timing relative to `mission_launched` — is **TBD**. Specify in the Resource Economy GDD. Wave Manager has no dependency on this mechanism; it is documented here for cross-GDD traceability.

### Bidirectionality Notes

- **Monster GDD OQ-6 resolved here**: `monster_breached(tier==2)` = wave-cleared, not DEFEAT. This rule is owned by Wave Manager (Rule 21) and closes the open question left in the Monster System GDD.
- **Pathfinding GDD OQ-2 resolved here**: Wave Manager subscribes to `templates_ready` via EventBus and must not emit `monster_spawn_requested` until that event fires. **Phase ordering alone does NOT guarantee readiness** — the explicit event subscription is required. This is documented in Rule 22 and closes Pathfinding OQ-2.
- **EventBus `monster_spawn_requested` confirmed**: 6-field payload (`monster_id`, `spawn_cell`, `wave_index`, `difficulty_tier`, `wave_reward_scalar`, `is_penultimate_wave: bool`) — added to EventBus catalogue 2026-04-25; updated 2026-05-20 to include `is_penultimate_wave` (Wave Manager Rule 15c). **EventBus GDD `monster_spawn_requested` entry must be updated to show 6 fields before implementation.** Similarly, `wave_completed` now carries a third field: `was_boss_breached: bool` (false for all clear paths except BOSS breach; true only on `monster_breached(tier==2)` fast-path).

## Tuning Knobs

All authored per-mission in `WaveConfig` or `MissionResource`. No tuning knobs are hardcoded; all live in data.

| Knob | Default | Safe Range | Gameplay Effect |
|------|---------|------------|-----------------|
| `scout_phase_duration` | 60s | 30–120s | Time the player has for tower placement and Tarot selection before the first wave. Lower = more pressure at mission start; higher = relaxed prep. |
| `scout_phase_min_duration` | 0s | 0–30s | Minimum elapsed SCOUT time before the Ready button is accepted. Default 0 allows instant skip (EC-2). Increase in tuning to enforce a minimum deliberation window if playtesting shows instant-skip is dominant. **CD ruling**: ship at 0; validate in vertical-slice playtest before raising. |
| `intermission_duration` | 30s | 25–40s | Time between waves for repositioning. Lower = less breathing room; higher = tactical reconsideration between engagements. Canonical range from game-concept Rule 7 and Tower GDD tuning knobs. |
| `pre_wave_countdown` | 10s | 5–15s | The countdown before each wave begins. Skippable via Ready button at any point (Rule 10, EC-8) — a player who has resolved their intermission debrief may commit early. Creates anticipation; too short reduces dread; too long feels stalled. |
| `difficulty_growth_rate` (`r`) | 0.20 | 0.15–0.25 | Per-wave exponential growth of `wave_reward_scalar`. Feeds Resource Economy drop quantity and quality scaling. Below 0.15: near-flat economy, no escalation feel. Above 0.25: economy runaway by wave 6+. Runtime-validated on `mission_launched` (**hard cap: 0.10–0.25** — values above 0.25 overflow the drop quality probability formula at r=0.30 wave_reward_scalar reaches 6.275×, above the 4.768× ceiling the base quality cap is calibrated against). |
| `wave_count` (= `wave_scripts.size()`) | 6 | 5–8 | Total waves per mission. Fewer = tighter, higher-stakes missions; more = sustained endurance. Final wave always contains exactly one BOSS entry. |
| `pre_delay` per `WaveSpawnEntry` | varies (authored) | 0.0–30.0s | Delay before a specific monster spawns within a wave. Controls burst cadence and "big entrance" pacing. 0.0 = simultaneous with previous entry (same frame). **Anti-burst warning**: entries at `pre_delay = 0.0` fire in the same frame as the prior entry — a burst of consecutive 0.0 delays creates an instantaneous monster dump that can produce an unplayable pressure spike. The CI validator (AC-19b) uses a 3-entry rolling-window check: any 3 consecutive entries whose `pre_delay` values sum to less than 0.15s are flagged as a content advisory. Note: alternating 0.0/0.05 values bypass a naive consecutive-zero check but produce an equivalent burst — the rolling-window check catches this pattern. Recommended minimum inter-spawn gap: 0.05s. Values > 15s risk breaking wave-active tension if overused. |

### Tuning Notes

- `scout_phase_duration` and `intermission_duration` interact with the player's mental model: both should feel "enough time if you know what you're doing, tight if you don't."
- `difficulty_growth_rate` is economy-only (drives Resource Economy scaling); it does NOT affect Monster HP or speed — those are controlled by `wave_index` inside the Monster System.
- `wave_count` of 8 at `r=0.25` produces `wave_reward_scalar` of 4.768× at the final wave — the designed ceiling. Do not author more than 8 waves.
- **Wave count and total mission economy**: Longer missions yield disproportionately higher total economic output under dual-dimension scaling. At r=0.20, the sum of `wave_reward_scalar^2` (combined quantity × quality output per wave) across all waves is **11.80** for a 5-wave mission and **39.74** for an 8-wave mission — an 8-wave mission produces approximately **3.37× the total combined economic output** of a 5-wave mission. This disparity is intentional: longer missions represent greater investment and greater reward. The Resource Economy GDD must not normalize per-wave base drop rates by `wave_count` unless this principle is explicitly revised. *(Note: the quantity-only sum ratio is 7.44 vs 16.50 = 2.22× — the 3.37× figure is the correct combined-dimension figure and the one the Resource Economy GDD must calibrate against.)*
- Increasing `pre_wave_countdown` beyond 15s is inadvisable: after the intermission debrief is done, the player is waiting without control — tension decays into boredom.
- **`intermission_duration` playtest validation**: The 30s default is not defended analytically — it is a tuning knob that must be validated in the first vertical-slice playtest. The validation criterion: does the player exhale, scan the grid, read the wave preview, and make a repositioning decision within 30s without feeling rushed? If testers consistently skip intermission early (pressing Ready at < 10s), the duration is over-tuned; if they consistently feel rushed (running out of time before completing a reposition), it is under-tuned. Adjust and re-test before locking the default.
- **Total intermission budget at maximum wave count**: At 8 waves with `intermission_duration = 40s` (ceiling), total intermission time = 7 × 40s = 280s (4.67 min). In a 25-minute mission ceiling, this is 18.7% of total mission time in non-combat intermission. Review the compound budget when authoring 8-wave missions at the high end of the intermission range.

## Visual/Audio Requirements

The Wave Manager produces no direct visual or audio output. All player-facing phase feedback — countdown displays, wave announce banners, defeat overlays — is owned by the Mission HUD, which consumes Wave Manager events via EventBus.

Wave Manager's responsibilities end at signal emission. The Mission HUD is the sole consumer of `phase_timer_tick`, `wave_countdown_warning`, `wave_started`, `wave_completed`, and `mission_phase_changed` for display purposes.

| Player-facing feedback | Wave Manager's role | Consuming system |
|------------------------|--------------------|--------------------|
| Scout phase countdown (60s→0) | Emits `phase_timer_tick` every 1s | Mission HUD |
| "Wave incoming" 10s countdown | Emits `wave_countdown_warning` at PRE_WAVE entry (audio sting), then `phase_timer_tick` every 1s for the rest of the countdown | Mission HUD |
| Wave number announce | Emits `wave_started` | Mission HUD |
| Intermission countdown (30s→0) | Emits `phase_timer_tick` every 1s | Mission HUD |
| "Wave cleared" feedback | Emits `wave_completed` | Mission HUD |
| Mission complete screen | Emits `mission_phase_changed` (→ MISSION_COMPLETE) | Mission HUD / UI system |
| Defeat screen | Emits `mission_phase_changed` (→ DEFEAT) | Mission HUD / UI system |
| BOSS breach — immediate moment | `monster_breached(tier==2)` fires as the BOSS exits (before wave-clear) — drives the immediate feedback: HUD flash, audio cue, breach counter increment. This is the signal the HUD consumes for the real-time breach moment. | Mission HUD |
| BOSS breach — end-of-wave state | `wave_completed(was_boss_breached: true)` fires after wave-clear — drives post-wave banner differentiation: "WAVE CLEARED — BOSS ESCAPED" vs "WAVE CLEARED". HUD reads `was_boss_breached` to determine which banner to display. | Mission HUD |

**Audio**: No audio cues are scheduled directly by Wave Manager. The Audio System (Full Vision tier) hooks into EventBus signals to trigger stingers and ambient shifts. For MVP: no audio output from this system.

**Dev tools only**: A debug overlay showing current phase state, `_wave_index`, `_enemies_alive`, and `_all_spawns_fired` may be implemented as a development utility. This overlay is not shipped content.

## UI Requirements

Wave Manager owns no UI components. All phase-driven UI is owned by the Mission HUD and triggered by EventBus events.

**Ready button contract** (the one UI interaction Wave Manager governs):

The Ready button must be active (pressable) exactly when:
- Current phase is `SCOUT` (any time ≥ 0s elapsed), OR
- Current phase is `PRE_WAVE` (any time ≥ 0s elapsed — pressing Ready skips the remaining countdown), OR
- Current phase is `INTERMISSION` (any time ≥ 0s elapsed)

The Ready button must be inactive (not pressable) when:
- Current phase is `WAVE_ACTIVE`
- Current phase is any terminal state (`MISSION_COMPLETE`, `DEFEAT`, `IDLE`)

Wave Manager handles Ready signals received in SCOUT (Rule 9), PRE_WAVE (Rule 10), and INTERMISSION (Rule 12). Ready signals received during WAVE_ACTIVE or terminal states are silently ignored. Mission HUD owns the visual enable/disable state of the button.

**Phase display data contract** (what Wave Manager promises to emit for UI):

| Signal | Payload fields | UI purpose |
|--------|----------------|------------|
| `mission_phase_changed` | `from_phase: String`, `to_phase: String` | Transition animations, banner reveals |
| `wave_started` | `wave_number: int`, `total_waves: int`, `wave_difficulty: float` | "Wave N / M" display |
| `wave_completed` | `wave_number: int`, `enemies_remaining: int`, `was_boss_breached: bool` | "Wave cleared" banner; HUD uses `was_boss_breached` to differentiate clean clear (false) from BOSS breach (true) feedback |
| `wave_countdown_warning` | `seconds_remaining: int` | PRE_WAVE countdown display |
| `phase_timer_tick` | `phase: String`, `seconds_remaining: float` | Scout / Intermission timer bar |
| `wave_preview_available` | `WavePreviewEvent` Resource: `next_wave_number: int`, `composition: Array[WaveCompositionEntry]`, `boss_spawn_cell: Vector2i` **(corrected 2026-07-15, `/review-all-gdds` — was still `Array[Dictionary]`)** | Wave composition preview; `boss_spawn_cell` (sentinel `Vector2i(-1,-1)` on non-boss waves) drives Mission HUD's boss-lane telegraph display, consumed downstream by Tower System's T4 placement UX (see Rule 11) |

No additional UI is required from the Wave Manager in MVP scope.

## Acceptance Criteria

#### Phase Lifecycle

**AC-1** — On `mission_launched`, Wave Manager transitions from IDLE to SCOUT and starts the 60s timer. Mission HUD receives `mission_phase_changed(from: "IDLE", to: "SCOUT")` within the same frame.

**AC-2** — When the 60s Scout timer expires with the player taking no action, Wave Manager transitions to PRE_WAVE and emits `wave_countdown_warning(seconds_remaining: 10)` immediately.

**AC-3** — When the player presses Ready in SCOUT at t=0 (instant skip), Wave Manager transitions to PRE_WAVE. The 60s timer is cancelled. `wave_countdown_warning(seconds_remaining: 10)` is emitted.

**AC-4** — The PRE_WAVE countdown runs for exactly 10 seconds (±1 frame, ≤17ms at 60 FPS) when no Ready signal is received. GIVEN Wave Manager in PRE_WAVE with a mocked timer, WHEN Ready is pressed at t=3s (simulated), THEN `mission_phase_changed(from: 'PRE_WAVE', to: 'WAVE_ACTIVE')` fires immediately and `wave_started` is emitted. No further countdown ticks fire. **Requires unit test with mocked timer** — one case for natural expiry, one case for Ready-skip mid-countdown.

**AC-5** — GIVEN a WaveConfig with 5 `wave_scripts`, WHEN the PRE_WAVE countdown expires (or Ready is pressed during PRE_WAVE), THEN Wave Manager emits `wave_started(wave_number: 1, total_waves: 5, wave_difficulty: 1.00)` followed by `mission_phase_changed(from: 'PRE_WAVE', to: 'WAVE_ACTIVE')` in the same frame. **Requires unit test** with mocked timer and a 5-wave WaveConfig fixture. `total_waves: 5` must be pinned to the fixture count — asserting `total_waves == N` (unbound) is not a valid test. Assert `wave_started` is captured before `mission_phase_changed` in the event log — emission order is required, not merely co-tick presence.

**AC-6** — GIVEN a 2-wave WaveConfig with Wave Manager in WAVE_ACTIVE for wave 2, WHEN `boss_died` is injected, THEN `wave_completed(wave_number: 2, enemies_remaining: 0, was_boss_breached: false)` is emitted, immediately followed by `mission_phase_changed(from: 'WAVE_ACTIVE', to: 'MISSION_COMPLETE')`. THEN, for 60 simulated seconds (mocked timer), no further `wave_started`, `wave_completed`, `phase_timer_tick`, `wave_countdown_warning`, or `monster_spawn_requested` events are emitted. **Requires unit test with mocked timer.** The observation window (60s) is mandatory — "no further transitions" without a bounded window cannot be verified.

**AC-7** — GIVEN Wave Manager in each of SCOUT, PRE_WAVE, INTERMISSION, and WAVE_ACTIVE (four separate test cases), WHEN `hero_died` is injected, THEN `mission_phase_changed(from: <current_phase>, to: 'DEFEAT')` is emitted with the correct `from_phase` value for each case. THEN, for 60 simulated seconds (mocked timer), no further `wave_started`, `wave_completed`, `phase_timer_tick`, `wave_countdown_warning`, or `monster_spawn_requested` events are emitted. **Requires 4 unit tests** (one per source phase) with mocked timers. Verifying only WAVE_ACTIVE does not satisfy "regardless of the current phase."

**AC-8** — GIVEN Wave Manager in WAVE_ACTIVE with `_all_spawns_fired == true` and `_enemies_alive == 1`, WHEN `_on_hero_died()` is called directly in the test, immediately followed by the competing event handler (`_on_monster_died()`, `_on_boss_died()`, or `_on_monster_breached(tier:2)`) in the same test function invocation (not via separate await cycles), THEN only `mission_phase_changed(to: 'DEFEAT')` is emitted — `wave_completed` is NOT emitted. **Requires 3 unit tests** covering the three wave-clear trigger variants: (a) `_on_hero_died()` then `_on_monster_died()`, (b) `_on_hero_died()` then `_on_boss_died()`, (c) `_on_hero_died()` then `_on_monster_breached(tier:2)`. The test asserts the observable event sequence only — the internal ordering of `_phase_locked` assignment is a code-review concern, not a test-verifiable assertion.

**Implementation note (code-review-only, not test-verified)**: The `hero_died` handler must set `_phase_locked = true` as its first operation. All other event handlers must check `_phase_locked` as their first operation and return immediately if true. This ordering guarantee is verified at code review, not by the AC-8 test.

---

#### Spawn Sequencing

**AC-9** — During WAVE_ACTIVE, monsters from `WaveScript.entries` spawn in order. For each entry, the spawn fires within `pre_delay` ±1 frame (≤17ms at 60 FPS) after the previous entry (or after `wave_started` for index 0). A 0.0 pre_delay entry fires in the same frame as the previous. Verified via unit test with mocked timer.

**AC-10** — GIVEN a WaveScript with 4 entries (spawn_cell_index: [2, -1, -1, -1]) on a **test-fixture GridConfig with 3 spawn cells [A, B, C]** (unit test only — see note below):
WHEN WAVE_ACTIVE begins (round-robin resets to 0),
THEN `monster_spawn_requested` payloads show `spawn_cell`: [C (index 2 % 3), A (counter 0), B (counter 1), C (counter 2)].
On the subsequent WAVE_ACTIVE for the next wave, round-robin resets again: first `-1` entry uses cell A.
**Scope note *(corrected 2026-07-15d — `/review-all-gdds` 5th pass)*:** this AC unit-tests Rule 15b's round-robin/modulo-wrap algorithm in isolation against a mocked 3-spawn GridConfig — it verifies Wave Manager's own spawn-cell-selection code is written correctly for arbitrary N, not that a 3-SPAWN mission map is currently shippable content. `pathfinding.md`'s `AC-13d` is a separate, deliberate CI gate that blocks any real mission map with 2+ SPAWN cells from shipping at MVP (the nearest-SPAWN Chebyshev routing-template algorithm is documented as incorrect near walls between SPAWNs; a reverse-Dijkstra fix is deferred to post-MVP). This AC's test fixture is exempt from that content gate because it is a code-level unit test, not an authored mission map — no contradiction, but the two constraints must not be conflated: Wave Manager's spawn-selection logic being N-agnostic does not by itself make multi-SPAWN missions MVP-shippable.
Requires unit test with known fixture. **`_round_robin_counter` resets to 0 at every WAVE_ACTIVE entry (wave-scoped, not mission-scoped).**

**AC-11** — GIVEN all spawn entries have fired and all `monster_spawned` events have been matched by `monster_died` or `monster_breached` events, WHEN the final `monster_died` is received, THEN `wave_completed` is emitted in the same frame. **Requires unit test** — author a 2-entry wave; inject `monster_spawned` × 2 then `monster_died` × 2; confirm `wave_completed` fires immediately after the second `monster_died`.

**AC-12** — `monster_spawn_requested` payload contains exactly these **six** fields and no others: `monster_id: StringName`, `spawn_cell: Vector2i`, `wave_index: int`, `difficulty_tier: int`, `wave_reward_scalar: float`, `is_penultimate_wave: bool`. **Requires unit test**: trigger one spawn cycle; capture the `monster_spawn_requested` payload; assert the dictionary has exactly 6 keys with the correct names and GDScript types; assert no additional keys are present. *(Note: asserting Monster System behavior regarding `wave_reward_scalar` belongs in the Monster System GDD and its own test file — Wave Manager cannot assert cross-system behavior.)*

---

#### Wave-Clear Detection

**AC-13** — GIVEN N `monster_spawned` events followed by N `monster_died` events with `_all_spawns_fired == true`, WHEN the Nth `monster_died` is received, THEN `wave_completed` fires. GIVEN an (N+1)th `monster_died` arrives after wave clear, THEN no duplicate `wave_completed` fires and no error is thrown. **Requires unit test** — verify wave clears exactly once even with stray over-count decrements.

**AC-14** — Standard wave-clear (no BOSS): when `_all_spawns_fired == true` AND `_enemies_alive == 0`, wave-clear is triggered. Both conditions must be met; either alone does not clear the wave. **Requires unit test — two negative-case assertions with mocked timer:** (a) GIVEN `_all_spawns_fired == true` and `_enemies_alive == 1`, WHEN 30 simulated seconds elapse, THEN `wave_completed` is NOT emitted. (b) GIVEN `_all_spawns_fired == false` and `_enemies_alive == 0`, WHEN 30 simulated seconds elapse, THEN `wave_completed` is NOT emitted.

**AC-15** — On `boss_died`, wave-clear is triggered immediately regardless of `_enemies_alive` or `_all_spawns_fired`. Remaining spawn entries are not fired. **Requires unit test with mocked timer** — inject `boss_died` into WAVE_ACTIVE with 3 remaining WaveScript entries unfired and `_enemies_alive == 2`. Assert `wave_completed(was_boss_breached: false)` is emitted. For 30 simulated seconds after `boss_died`, assert no `monster_spawn_requested` events fire (remaining entries discarded).

**AC-16** — On `monster_breached(tier == 2)` (BOSS breach), wave-clear is triggered. **Requires unit test with mocked timer** — inject `monster_breached(tier: 2)` into WAVE_ACTIVE. Assert `wave_completed(was_boss_breached: true)` is emitted. Assert `mission_phase_changed(to: 'DEFEAT')` is NOT emitted (observe 30 simulated seconds). This is the one clear path where `was_boss_breached` must be `true`.

---

#### Difficulty Scaling

**AC-17** — `wave_reward_scalar` boundary verification (unit test, GDScript float64 ±0.001 tolerance):

| Wave | r | Expected | Test |
|------|---|----------|------|
| 1 | any | 1.000 | F1 base case |
| 4 | 0.20 | 1.728 | `1.20^3` |
| 4 | 0.25 | 1.953 | `1.25^3` |
| 8 | 0.20 | 3.583 | `1.20^7` |
| 8 | 0.25 | 4.768 | `1.25^7` |

No negative outputs possible (exponential is always positive for r > 0). No division by zero. Verify `wave_reward_scalar` in the `wave_started` `wave_difficulty` payload matches the `monster_spawn_requested` `wave_reward_scalar` payload for the same wave.

**AC-18** — **Requires unit test with mocked timer.** GIVEN Wave Manager in SCOUT with `scout_phase_duration = 60`, WHEN the mocked timer fires 3 sequential 1-second ticks, THEN exactly 3 `phase_timer_tick(phase: 'SCOUT', seconds_remaining: N)` events are emitted with `seconds_remaining` values of [59, 58, 57] respectively (F2: `max(0.0, 60 - elapsed)`, floored). GIVEN Wave Manager then transitions to PRE_WAVE or WAVE_ACTIVE (via mock), THEN no `phase_timer_tick` events fire for 30 simulated seconds. Repeat independently for INTERMISSION: `intermission_duration = 30`, first tick `seconds_remaining = 29`. Real-time blocking tests (waiting 60s) are not acceptable; mocked timer is mandatory.

---

#### Edge Case Handling

**AC-19** — If `WaveConfig.wave_scripts` is empty, Wave Manager logs an error and immediately emits `mission_phase_changed(SCOUT → MISSION_COMPLETE)`. No spawn events are fired.

**AC-19b** *(Infrastructure delivery story — not a runtime behavioral AC; tracked separately in CI backlog)* — A WaveConfig validator tool (editor plugin or CI script) must exist and run in CI on every commit that touches `assets/data/waves/`. The validator asserts:
- All `monster_id` values exist in `assets/data/monsters/` (resolved by `id` field in `.tres` file, not filename)
- **Wave count bounds**: `wave_scripts.size() >= 1` (EC-6 handles 0 at runtime) AND `wave_scripts.size() <= 8` (hard CI failure if exceeded — a 9-wave WaveConfig with r=0.25 produces scalar 5.960×, breaking the base_quality probability cap calibrated for 4.768×).
- **If `wave_scripts.size() >= 5`**: The penultimate wave contains only ELITE-tier entries; tier is determined by reading `MonsterResource.tier` from the corresponding `.tres` file resolved by `monster_id` match to the `id` field. Tier schema cross-reference: `{0: STANDARD, 1: ELITE, 2: BOSS}` per Monster System GDD — the validator must read this schema from MonsterResource, not hard-code it. **If `wave_scripts.size() < 5`**: Skip the penultimate tier check (emit advisory log only; do not fail CI). This matches Rule 6's exemption for sub-5-wave missions.
- **Minimum entries per wave**: Every wave must contain at least 2 entries (`entries.size() >= 2`). A 1-entry wave is a content authoring error (insufficient to create meaningful wave pressure). Hard CI failure.
- **Final wave constraints**: The final wave contains `entries.size() >= 2` AND all entries at indices `[0 .. N-2]` (every entry except the last) are **not** BOSS-tier — AND the last entry is exactly one BOSS-tier entry (same tier-resolution method). A single-entry final wave containing only a BOSS fails this check. **AND the final wave's BOSS entry (last entry) has `spawn_cell_index >= 0`** — hard CI failure if `spawn_cell_index == -1` *(added during `/design-review` 2026-07-14 re-review, enforces Rule 6's boss-lane-telegraph constraint — a round-robin BOSS spawn cell cannot be resolved at `wave_preview_available` preview time)*.
- **BOSS-at-non-last in any wave**: For every wave at any index, no entry at position `[0 .. entries.size()-2]` (any non-last position) may be BOSS-tier (hard CI failure). This closes the gap that EC-10's DEBUG-only runtime assert cannot catch in release builds.
- No individual wave's total `pre_delay` sum exceeds `wave_time_budget`
- **Anti-burst rolling-window check**: For every wave, for every 3-entry sliding window, if the sum of `pre_delay` values across those 3 entries is less than 0.15s, flag as an advisory warning (not a hard CI failure). This replaces the prior "3+ consecutive entries all at 0.0" check, which was bypassable via alternating 0.0/0.05 patterns that produce the same instantaneous burst effect.

Violations log authoring errors and fail CI. **CI contract**: The validator script exits `0` on pass and non-zero on any failure; the CI step identifier is `wave-config-validator`. This AC is met when the validator tool is implemented, the CI step is present, and a passing run produces exit code `0`. Runtime Wave Manager code is not required to ship for this AC to be verified.

**AC-20** — On `mission_launched` received while in `DEFEAT` or `MISSION_COMPLETE` state, Wave Manager resets all internal state synchronously within `_on_mission_launched` before the SCOUT transition begins. **Requires unit test** — verified by firing two `mission_launched` events sequentially (first mission runs to DEFEAT or MISSION_COMPLETE, second is immediately launched) and confirming no state from the first mission bleeds into the second. The test must explicitly assert ALL of the following fields after the reset:
- `_wave_index == 0`
- `_round_robin_counter == 0`
- `_enemies_alive == 0`
- `_all_spawns_fired == false`
- `_phase_locked == false`
- `_wave_clear_fired == false`
- `_templates_ready == false`
- `_rebuild_pending_gate == false`

All 8 fields must be asserted — asserting a subset is insufficient. Additionally, the test must include a timer-cancellation sub-case: GIVEN Wave Manager in INTERMISSION with 15s remaining on the intermission timer, WHEN `mission_launched` is injected, THEN for 30 simulated seconds after the injection no `phase_timer_tick(phase: "INTERMISSION", ...)` events fire (verifying the intermission timer was actually cancelled, not just ignored).

---

#### Additional Edge-Case Acceptance Criteria

**AC-21** — If `hero_died` is received during INTERMISSION, Wave Manager immediately transitions to DEFEAT and stops the 30s intermission timer. `mission_phase_changed(from: "INTERMISSION", to: "DEFEAT")` is emitted. The partial intermission is discarded; no PRE_WAVE follows.

**AC-22** — **Requires unit test with mocked timer.** GIVEN Wave Manager enters INTERMISSION (non-final wave), WHEN the mocked timer fires 30 sequential 1-second ticks, THEN exactly 30 `phase_timer_tick(phase: 'INTERMISSION', seconds_remaining: N)` events are emitted (values decrementing from 29 to 0), and `mission_phase_changed(from: 'INTERMISSION', to: 'PRE_WAVE')` is emitted in the same frame as the 30th tick. No 31st `phase_timer_tick(phase: 'INTERMISSION', ...)` event fires. Real-time blocking tests (waiting 30s) are not acceptable; mocked timer is mandatory.

**AC-23** — A complete N-wave mission (all waves spawned, BOSS killed on final wave) advances through all expected phases. `wave_started` is emitted exactly N times and `wave_completed` is emitted exactly N times before `mission_phase_changed(→ MISSION_COMPLETE)`. **Requires integration test** — full SCOUT → [PRE_WAVE → WAVE_ACTIVE → INTERMISSION] × (N-1) → PRE_WAVE → WAVE_ACTIVE → MISSION_COMPLETE traversal with mocked Monster System responses.

**AC-24** — `monster_breached` with `tier == 1` (ELITE breach) does NOT trigger the BOSS breach fast-path. Wave Manager treats a tier-1 breach as a standard decrement: `_enemies_alive` decrements by 1; wave-clear checks standard conditions only. **Requires unit test** — inject `monster_breached(tier:1)` in a wave with 3 remaining enemies; confirm wave does NOT clear.

---

#### Wave-Stuck Watchdog

**AC-25** — GIVEN a wave where all spawns have fired (`_all_spawns_fired == true`) and `_enemies_alive == 2`, WHEN 30 seconds elapse with no `monster_died` or `monster_breached` events, THEN Wave Manager emits exactly one `wave_stalled(wave_number: N, enemies_remaining: 2)` event. No `wave_completed` fires at 30s. **Requires unit test** with mocked timer.

**AC-26** — GIVEN the same stuck-wave scenario as AC-25, WHEN 60 seconds elapse (`wave_stuck_timeout`), THEN Wave Manager emits `wave_completed` (force-clear), advances to INTERMISSION or MISSION_COMPLETE, and logs an error string containing `"Wave [N] stuck"`. Exactly one `wave_stalled` (at 30s) and one `wave_completed` (at 60s) emitted — no duplicates. **Requires unit test** with mocked timer.

---

#### Wave Composition Preview

**AC-27** — After a non-final wave clears, Wave Manager emits `wave_preview_available` on INTERMISSION entry. Payload `next_wave_number` equals the current `_wave_index + 1`. Payload `composition` is an `Array[WaveCompositionEntry]` (**corrected 2026-07-15, `/review-all-gdds`** — was still `Array[Dictionary]`) where each `WaveCompositionEntry` Resource has fields `monster_id: StringName` and `count: int`; the sum of all `count` values equals the total `WaveSpawnEntry` count for the upcoming wave. Payload `boss_spawn_cell` is the sentinel `Vector2i(-1, -1)` (the upcoming wave in this test's fixture is non-final, per AC-42 below for the boss case). **Requires unit test** — author a 2-wave WaveConfig with known entries; verify composition payload matches after wave 1 clears.

---

**AC-42** — GIVEN a 2-wave WaveConfig where wave 2 (the final wave) has a BOSS entry as its last entry with `spawn_cell_index = 1` on a 3-spawn-cell map (`spawn_cells = [A, B, C]`), WHEN INTERMISSION is entered after wave 1 clears (previewing wave 2, the boss wave), THEN `wave_preview_available` payload includes `boss_spawn_cell == B` (`spawn_cells[1 % 3]`). **AND GIVEN** the same WaveConfig's preview of wave 1 (a non-boss wave, fired at SCOUT entry per Rule 8), **THEN** `boss_spawn_cell == Vector2i(-1, -1)` — the sentinel value, not an absent field. **AND GIVEN** the BOSS entry's `spawn_cell_index = 4` on the same 3-cell map (out-of-range, exercising EC-7's modulo wrap), **THEN** `boss_spawn_cell == spawn_cells[4 % 3] == B` — confirming the preview reflects the resolved (post-wrap) cell, not the raw authored index. **Requires unit test** — author the 2-wave fixture described above; assert both waves' preview payloads (boss-wave positive case and non-boss-wave sentinel case) in the same test, plus the modulo-wrap variant. *(Rule 11 — boss-lane telegraph, added during `/design-review` 2026-07-14 re-review, closes a confirmed pre-existing gap: no prior AC exercised `wave_preview_available`'s payload for the wave that is itself the boss wave.)*

---

#### `monsters_died_batch` Subscription

**AC-28** — GIVEN a wave with 5 alive monsters and all `monster_spawn_requested` events fired (inferred from 5 `monster_spawned` received, 0 `monster_died`), WHEN one `monsters_died_batch(count: 5)` event is received (no individual `monster_died` events), THEN wave-clear is triggered — `wave_completed` is emitted and the phase advances. **Requires unit test** — inject `monsters_died_batch` directly; verify wave clears identically to 5 sequential `monster_died` events.

---

#### boss_died Fast-Path + Wave Preview

**AC-29** — GIVEN Wave Manager in WAVE_ACTIVE for a non-final wave with `_all_spawns_fired == false` (boss killed before all spawn entries fired), WHEN `boss_died` is received, THEN (in sequence, within the same `_process` tick): `wave_completed(was_boss_breached: false)` is emitted, `mission_phase_changed(from: 'WAVE_ACTIVE', to: 'INTERMISSION')` is emitted, and `wave_preview_available(next_wave_number: N+1, composition: [...])` is emitted. All three events must fire via the same INTERMISSION entry path used by the standard wave-clear — the `boss_died` fast-path must not bypass the INTERMISSION entry logic. **Requires unit test** — author a 2-wave WaveConfig, inject `boss_died` before all spawn entries fire; capture and verify the 3-event sequence in order with `was_boss_breached: false` asserted in the first event.

---

#### `was_boss_breached` Flag Verification

**AC-30** — `wave_completed` payload carries the correct `was_boss_breached` flag in all three clear paths. **Requires 3 unit tests** (one per path):
- **(a) Standard clear** (all `monster_died` / `monster_breached(tier:1)` events, no BOSS involved): assert `wave_completed(was_boss_breached: false)`.
- **(b) `boss_died` fast-path** (BOSS was killed): assert `wave_completed(was_boss_breached: false)`.
- **(c) BOSS breach fast-path** (`monster_breached(tier:2)`): assert `wave_completed(was_boss_breached: true)`.

Each test must capture the `wave_completed` payload and assert `was_boss_breached` explicitly — asserting only that `wave_completed` fires is insufficient.

---

#### `templates_ready` Gate

**AC-31** — No `monster_spawn_requested` fires before `templates_ready` is received. **Requires unit test with mocked timer and mocked `templates_ready` signal injection.**

GIVEN Wave Manager in SCOUT with `templates_ready` not yet received,
WHEN Scout timer expires (or Ready is pressed) and PRE_WAVE countdown runs to completion (or Ready is pressed during PRE_WAVE), entering WAVE_ACTIVE,
THEN no `monster_spawn_requested` events are emitted for 30 simulated seconds.

GIVEN `templates_ready(spawn_count: N, build_duration_ms: M)` is subsequently injected,
THEN the WaveScript's first spawn entry fires within 1 frame of the injection (or after `pre_delay` if non-zero).

GIVEN `templates_ready` fires before SCOUT timer expires (normal path — templates build during SCOUT),
THEN spawn sequencing begins normally at WAVE_ACTIVE entry with no delay beyond `pre_delay` values (within ±1 frame / ≤17ms at 60 FPS of WAVE_ACTIVE entry).

**Implementation constraint**: Wave Manager stores `_templates_ready: bool = false`, set to `true` on receipt of `templates_ready`. The spawn sequencing coroutine checks `_templates_ready` before firing the first `monster_spawn_requested`; if `false`, it awaits the `templates_ready` EventBus signal before proceeding.

---

#### Stray `boss_died` Guard

**AC-32** — GIVEN Wave Manager has transitioned to INTERMISSION (non-final wave) after a wave-clear, WHEN `boss_died(cause: "force_removed")` is injected (simulating Monster System force-removing a BOSS during wave_completed cleanup), THEN no additional `wave_completed`, `mission_phase_changed`, or `wave_started` events are emitted. Wave Manager remains in INTERMISSION with its 30s timer intact. **Requires unit test with mocked timer** — observe for 30 simulated seconds after `boss_died` injection; confirm no unexpected events fire.

---

#### Pathfinding Synchronization — Wave 2+ Gate

**AC-33** — **Requires unit test with mocked timer and stubbed PathfindingSystem.** GIVEN Wave Manager at the INTERMISSION→PRE_WAVE transition with a stubbed `PathfindingSystem.is_rebuild_pending()` returning `true`, WHEN Wave Manager transitions to PRE_WAVE and then to WAVE_ACTIVE (countdown expires or Ready), THEN no `monster_spawn_requested` events are emitted for 30 simulated seconds. GIVEN `path_invalidated` is subsequently injected via EventBus, THEN the WaveScript's first spawn entry fires within 1 frame of the injection (or after `pre_delay` if non-zero). In the negative case: GIVEN the same transition with `is_rebuild_pending()` returning `false`, THEN spawn sequencing begins at WAVE_ACTIVE entry with no additional gate.

**Implementation constraint**: `_templates_ready: bool` and `_rebuild_pending_gate: bool` track the two gates independently. The spawn sequencing coroutine checks `_templates_ready` first (wave 1); for waves 2+, checks `_rebuild_pending_gate` (set from the `is_rebuild_pending()` call at INTERMISSION→PRE_WAVE). Both flags are reset to `false` on `mission_launched` (see EC-9 and AC-20).

---

#### `_wave_clear_fired` Latch — Same-Frame Stray boss_died Guard

**AC-34** — **Requires unit test with mocked timer.** GIVEN Wave Manager in WAVE_ACTIVE, WHEN BOSS breach fast-path fires (`monster_breached(tier:2)` injected) and, in the same test function invocation (before the phase state variable has updated to INTERMISSION), `boss_died(cause: "force_removed")` is subsequently injected, THEN only one `wave_completed` event is emitted (from the breach path), `was_boss_breached: true`. The stray `boss_died` does NOT emit a second `wave_completed`. Phase advances to INTERMISSION exactly once. **Requires 2-event sequence assertion**: capture event log; assert `wave_completed` appears exactly once with `was_boss_breached: true`; assert no second `wave_completed` entry present. *(This test specifically validates the `_wave_clear_fired` latch from Rules 20–21 and EC-5b guards 1+2.)*

---

#### Mocked Timer — Test Fixture Note

**Timer mocking (applies to AC-4, AC-6, AC-7, AC-14, AC-15, AC-16, AC-18, AC-22, AC-25, AC-26, AC-31, AC-32, AC-37, AC-38)**: Call timer callback methods directly on the Wave Manager instance via GUT's `get_node()` access (e.g., invoke `_on_scout_timer_timeout()` directly). Do not use `Engine.time_scale` — time_scale affects the entire scene tree and produces non-deterministic test results in CI.

**Monster System mocking (applies to AC-23 and integration tests)**: Inject `monster_spawned` events (one per `monster_spawn_requested` received) and `monster_died` events per entity directly via EventBus in the test harness. No Monster System Autoload is required. The test harness acts as a stub that reflects spawn requests back as spawned+died events.

---

#### Spawn Cell Modulo Wrap

**AC-35** — **Requires unit test.** GIVEN a WaveScript with one `WaveSpawnEntry` with `spawn_cell_index = 5` on a map with 3 spawn cells (indices 0, 1, 2), WHEN Wave Manager processes the entry during WAVE_ACTIVE, THEN `monster_spawn_requested` fires with `spawn_cell == spawn_cells[5 % 3]` (i.e., `spawn_cells[2]`) AND a warning is logged containing `"spawn_cell_index [5] out of range"`. No crash occurs. Repeat with `spawn_cell_index = 3` (wraps to index 0) and `spawn_cell_index = 7` (wraps to index 1) to verify modulo correctness.

---

#### Empty Spawn Cells

**AC-36** — **Requires unit test with mocked `Grid.get_spawn_cells()`.** GIVEN `Grid.get_spawn_cells()` is stubbed to return `[]` (empty array), WHEN `mission_launched` is received, THEN Wave Manager emits `mission_phase_changed(from: "SCOUT", to: "MISSION_COMPLETE")`, logs an error containing `"0 spawn cells"`, and no `monster_spawn_requested` events are emitted for 30 simulated seconds after the event. No crash or division-by-zero occurs.

---

#### `monsters_died_batch` Invalid Count Guard

**AC-37** — **Requires unit test with mocked timer.** GIVEN Wave Manager in WAVE_ACTIVE with `_enemies_alive == 3` (established by 3 prior `monster_spawned` events), WHEN `monsters_died_batch(count: 0)` is injected via EventBus, THEN `_enemies_alive` remains 3, no `wave_completed` fires, and a warning is logged containing `"invalid count 0 — discarded"`. Repeat with `count: -1`. For 30 simulated seconds after injection, assert no `wave_completed` fires.

---

#### `monster_spawned` Outside WAVE_ACTIVE Guard

**AC-38** — **Requires unit test with mocked timer.** GIVEN Wave Manager has transitioned to INTERMISSION (non-final wave, after a wave clear), WHEN `monster_spawned` is injected via EventBus, THEN `_enemies_alive` does not increment (assert `_enemies_alive == 0` before and after injection) AND a warning is logged containing `"outside WAVE_ACTIVE"`. For 30 simulated seconds after injection, assert no `wave_completed` fires (the stray `monster_spawned` does not corrupt `_enemies_alive` for the next wave).

---

#### `run_modifier_selected` Phase Guard

**AC-39** — **Requires unit test.** GIVEN Wave Manager in each of WAVE_ACTIVE, INTERMISSION, PRE_WAVE, MISSION_COMPLETE, and DEFEAT (five separate test cases), WHEN `run_modifier_selected` is injected via EventBus, THEN no state changes occur and no events are emitted.

**AC-39b** *(added 2026-07-17, closes OQ-2's deferred positive case)* — GIVEN Wave Manager in SCOUT phase, before the first PRE_WAVE begins, WHEN `run_modifier_selected("difficulty_growth_boost", 0.05)` is received from Mission Select, THEN `difficulty_growth_rate` is adjusted per Rule 9's clamp before the first PRE_WAVE begins, and the adjusted value is used by Formula F1 for every subsequent wave in the mission.

---

#### `templates_ready` Same-Frame Race Guard

**AC-40** — **Requires unit test.** GIVEN Wave Manager in SCOUT (templates not yet ready), WHEN, in a single test function invocation (simulating same-frame arrival): (a) the player presses Ready (SCOUT→PRE_WAVE transition is triggered), immediately followed by (b) `templates_ready(spawn_count: 1, build_duration_ms: 10)` injected via EventBus — THEN `_templates_ready == true` after both operations complete. GIVEN Wave Manager then transitions to WAVE_ACTIVE (PRE_WAVE timer mocked to expire), THEN the spawn sequencing coroutine proceeds immediately (no indefinite await), and `monster_spawn_requested` fires within the same synchronous call chain as WAVE_ACTIVE entry (for the first spawn entry with `pre_delay = 0.0`). This verifies that the `templates_ready` handler sets `_templates_ready = true` unconditionally (no phase guard that would discard it during PRE_WAVE).

---

#### `wave_time_budget` Runtime Validation

**AC-41** — **Requires unit test.** GIVEN a `WaveConfig` where at least one `WaveScript`'s total `pre_delay` sum exceeds `wave_time_budget` (e.g., a 3-entry wave with `pre_delay` values [0.0, 50.0, 50.0] against a `wave_time_budget` of 90s — sum = 100s > 90s), WHEN `mission_launched` is received, THEN Wave Manager logs a content error containing `"exceeds wave_time_budget"` identifying the offending wave index. The mission continues without crashing or aborting — this is an authoring error surface for playtest visibility, not a fatal condition. Spawn sequencing proceeds with the authored `pre_delay` values as-is (they are not clamped). For 30 simulated seconds after `mission_launched`, assert at least one `phase_timer_tick` fires in SCOUT (confirming the mission did not abort to MISSION_COMPLETE). **Negative case**: GIVEN a WaveConfig where all waves' `pre_delay` sums are ≤ `wave_time_budget`, WHEN `mission_launched` is received, THEN no error is logged (verified by asserting the test harness error log is empty for this message).

---

#### Frame-Yield Contract Between `wave_completed` and Next `wave_started`

**AC-43** — **Requires unit test with mocked timers.** GIVEN Wave Manager clears a non-final wave (all monsters dead, `wave_completed` emitted, frame counter recorded as `F_clear`), WHEN the test harness mocks both the INTERMISSION 30s timer and the PRE_WAVE 10s countdown to expire on their very next `_process` tick each (fastest possible legal path through the state machine), THEN the next `wave_started` emission's frame counter is strictly greater than `F_clear` — at least one frame elapsed, even under the fastest possible mocked-timer path. **AND GIVEN** the same scenario but with the player pressing Ready immediately on both INTERMISSION and PRE_WAVE entry (input-driven instant-skip path) instead of waiting for timers, **THEN** the same invariant holds — `wave_started`'s frame is still strictly greater than `F_clear`, confirming no code path (timer-driven or input-driven) collapses the two phase transitions into the same frame as the clear. *(Rule 12a — frame-yield contract, added 2026-07-15 during `/review-all-gdds` follow-up. This formalizes a guarantee `tower.md`'s targeting cache depends on but that was previously only emergent from the state machine's structure, never contractually tested.)*

---

## Open Questions

~~**OQ-1 — RESOLVED**~~ Wave Manager subscribes to both `monster_died` (individual, clamped −1) and `monsters_died_batch` (batch, decrement by `count: int`, clamped at 0). Rule 18 updated. No further action needed before implementation.

**OQ-2 — `run_modifier_selected`: override protocol — RESOLVED (2026-07-17)**
Resolved from two directions: (1) `mission-select.md` Formulas 1/2 define exactly what `run_modifier_selected("extend_waves"|"difficulty_growth_boost", value)` means as sole sender of that channel, with Wave Manager owning the clamping (Rule 9, EC-3). (2) `tarot.md` AC-18 proves Tarot never emits on `run_modifier_selected` at all — Tarot's actual override channel is the separate, already-resolved `mission_modifier_applied` event (Rule 7 there), with one fixed mechanism per modifier type (MULTIPLICATIVE or REPLACE, no ambiguity). The original premise of this OQ — that Tarot sends `run_modifier_selected` — was a misattribution, now corrected in both the Interactions table and Downstream Dependencies table above.

~~**OQ-3 — RESOLVED**~~ Minimum INTERMISSION delay before Ready button activates: **0 seconds.** Ready is available immediately at INTERMISSION start. No minimum delay is enforced by Wave Manager. The design prioritises player agency between engagements — the "debrief" is the player's choice to take, not a mandatory gate. Mission HUD owns the visual button state per the UI Requirements contract.

**OQ-4 — Scout timer persistence across session crash**
If a crash or save occurs during SCOUT, should the timer resume at the saved elapsed time, or reset to 0? Current design: Wave Manager is stateless between saves; any mission restart re-enters SCOUT with a fresh 60s timer. If this feels punishing in playtesting, consider saving `scout_elapsed` in the mission session data. Deferred to playtesting.

**OQ-6 — Drop resolution on BOSS breach and force-cleared monsters**

Two unresolved economic interactions require Monster System + Resource Economy GDD coordination before implementation:

**(a) BOSS breach drops**: When the BOSS breaches, Monster System despawns it immediately (Rule 21a). The document is currently silent on whether drop rewards apply. Two options with different incentives: (1) no drops on breach — breach is failure, player loses the most valuable loot; (2) drops apply on breach — players may intentionally let BOSS breach to guarantee drop collection without the risk of extended BOSS combat. Recommend option (1) as consistent with "breach is legible failure" player fantasy framing, but this must be specified in the Monster System GDD's breach-handling rules.

**(b) Force-remove drops**: Monsters force-removed by Monster System on `wave_completed` (the boss_died fast-path cleanup) carry live `wave_reward_scalar` in their spawn payloads but are never killed by the player. Recommend no drop resolution for force-cleared entities — they were not defeated, they were janitor'd. This also prevents a perverse incentive to avoid killing standard monsters before the BOSS in order to preserve those drops. This must be specified in the Monster System GDD's entity removal rules.

Resolution: define both behaviors explicitly in Monster System GDD. Wave Manager takes no action on drops.

**OQ-5 — Wave-stuck watchdog: contract or timeout?**
Rule 23 implements a 60s watchdog as a safety net. An alternative design would strengthen Monster System's contract: every spawned entity must eventually emit exactly one of `monster_died` or `monster_breached` — making the watchdog unnecessary. If the Monster System GDD formally specifies this guarantee, the watchdog can be downgraded to a debug-only assert (never force-clears). Resolution: during Monster System GDD review, confirm whether a lifetime guarantee on monster entity events is specified. If yes, annotate Rule 23 as a debug-only assert. If no, Rule 23's watchdog stands.
