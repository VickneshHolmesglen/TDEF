# Mission Select System

> **Status**: Needs Revision (`/design-review --depth lean` 2026-07-17 found `grid-system.md`'s Tuning Knobs table silently contradicted its own OQ-4 resolution (still said "set per mission, 48–128" three sections after being marked fixed), and `mission-hud.md` had zero ownership of the Retry button this GDD assigns it — both fixed same-day in the respective docs. `wave-manager.md`'s own follow-up edit (removing Tarot as a `run_modifier_selected` sender) is also now applied, closing that gap too. **`/design-review --depth lean` re-review 2026-08-27**: `retry_current_mission()`'s implementation gap is closed — confirmed shipped in `mission_select.gd`, unblocking AC-23/AC-25. One real gap remains open: the DEFEAT-save-then-immediate-retry checkpoint interaction is still untested by either this doc or `save-persistence.md`. Re-review recommended once that interaction has a test, before flipping to Approved.) → **Approved** (2026-08-27, same day — the checkpoint-race test was written (`tests/integration/mission-select/defeat-retry-checkpoint-race_test.gd`) and the real gap it surfaced, `TD-save-004`, was fixed the same session. No blocking items remain.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-17
> **Implements Pillar**: Mastery-as-Vindication
> **Closes**: `grid-system.md` OQ-4 (`cell_size` is a fixed project constant, 64.0 — registered, and now consistently reflected everywhere in `grid-system.md` as of 2026-07-17). **Known gaps**: `retry_current_mission()` Autoload API — **RESOLVED, found stale 2026-08-27**: shipped in `mission_select.gd` (`func retry_current_mission()`), called from `mission_hud.gd` per Rule 26; AC-23/AC-25 are now automatable. `wave-manager.md` has been updated (2026-07-17) to remove Tarot as a `run_modifier_selected` sender. **Test written 2026-08-27, gap fixed same day**: `tests/integration/mission-select/defeat-retry-checkpoint-race_test.gd` covers this interaction. Writing it surfaced why it was untestable as originally framed — `save-persistence.md` Rule 9's own "DEFEAT-triggered save" mechanism had no implementation anywhere in shipped code (`TD-save-004`, `docs/tech-debt-register.md`). Fixed same day: `save_persistence.gd` now subscribes to `mission_phase_changed` and defers a real `save_slot()` write on DEFEAT. The suite verifies both real save paths near a DEFEAT+retry sequence: DEFEAT's new deferred full save, and the pre-existing `retry_current_mission()` -> `mission_launched` -> checkpoint write, confirmed non-stale and race-free. **Live-verified same day via Godot MCP** against the real pinned 4.6.2.stable binary, independent of gdUnit4. This also surfaced one more real, narrower interaction — `TD-save-005` (`docs/tech-debt-register.md`, `save-persistence.md` Rule 5): if DEFEAT's deferred save is still pending when the player retries, it can land right after and delete the retry's own fresh checkpoint. Investigated 2026-08-27 and accepted as correct-by-construction, not fixed as a bug: the deleted checkpoint and the full save that replaces it are byte-identical in content (both come from the same snapshot function, and nothing persisted changes between DEFEAT and an immediate retry), so nothing real is lost. See Open Questions.

## Overview

Mission Select is the screen and flow that sits between the Sanctuary and a mission — the deliberate last step before a run begins. It presents the player with the available mission list, a difficulty-tier selection (Normal / Hard / Brutal, registered as a locked integer 1–3), and a set of optional "run modifier" toggles (generic difficulty / length / composition adjustments that are applied *before* Tarot's own card-driven modifiers, per the ordering rule locked in `game-concept.md`). Confirming launch fires the `mission_launched` signal, which commits the chosen `mission_id`, the selected run modifiers, and the `difficulty_tier` for the remainder of that run. Unlike the Sanctuary systems, Mission Select produces no content, persists no meta-progression, and grants no build-defining identity choice — its entire job is to let the player aim everything they have already built at a specific target and lock in the terms of the fight. Its player-facing effect is a single, unambiguous moment of commitment: after this screen, the run's mission, difficulty, and modifier set are fixed and no longer negotiable.

## Player Fantasy

*Everything you built in the Sanctuary has been theoretical until now. This is where you point it at something.*

The six systems behind you are where the player becomes someone — a tower is authored, a constellation composed, a deck built, a creature kept. Mission Select is not another place to become someone. It is the threshold where all of that stops being potential and becomes a single committed choice: **this** mission, at **this** difficulty, under **these** terms. The feeling here is not drama or dread — it is resolve. The quiet, deliberate weight of picking up everything you've made and aiming it. Once you confirm, the terms are fixed for the entire run; this is the last honest moment in which you can still change your mind, and the player should feel that door close behind them.

The one emotion that belongs *only* to this screen is the difficulty declaration. Choosing Normal, Hard, or Brutal is not a menu setting — it is the player stating on the record what they believe they are ready to beat. That is where this system serves Mastery-as-Vindication: vindication requires you to first name the standard you're claiming, and this is the screen where you name it. Deliberately, the rest is left to its rightful owners — the *wager* of trading safety for reward lives in Tarot, and the tension of reading a specific fight lives in the mission's own Scout Phase. Mission Select's fantasy is small by design: **I choose my test, and I say so out loud.** It earns its keep by being the clean, unhurried gate through which mastery gets aimed and locked.

## Detailed Design

### Core Rules

1. **Mission catalogue.** Alpha scope is a handful of representative missions (4–6), each authored as a `MissionEntry` Resource (`.tres` file in `assets/data/missions/`). Fields:

   | Field | Type | Description |
   |---|---|---|
   | `mission_id` | String | Unique, stable key. Never reused, never renamed once shipped (save data references it by string — see EC-6). |
   | `display_name` | String | UI-owned display text (Mission Select UI's concern, not this GDD's). |
   | `grid_config` | `GridConfig` (Resource, from `grid-system.md`) | Embedded per-mission grid data: `grid_cols`, `grid_rows`, `cell_size`, `_cell_types` map. `cell_size` is always the fixed project constant (see Rule 2 — closes Grid OQ-4); `grid_cols`/`grid_rows`/`_cell_types` vary per mission and are the actual map-shape/difficulty lever. |
   | `wave_config_path` | String | Path to the mission's `WaveConfig` Resource (owned and validated by Wave Manager's own content pipeline — Mission Select does not read or interpret `WaveConfig` internals, it only carries the path forward so Wave Manager can load it independently on `mission_launched`). |
   | `base_wave_count` | int | Cached display value, authored to equal `WaveConfig.wave_scripts.size()` at content-authoring time. This is a **display cache only** — Wave Manager's own loaded `WaveConfig` remains the sole runtime source of truth for actual wave count. Mission Select does not read `WaveConfig` at runtime to avoid a cross-system runtime coupling; a content-validation script (out of scope for this GDD, mirrors Wave Manager's own `AC-19b` CI pattern) should assert these stay in sync at authoring time. |
   | `recommended_difficulty_tier` | int (1–3) | Non-binding UI hint only ("Recommended: Hard"). Does not constrain the player's actual tier selection (Rule 3). |
   | `completion_records` | `Dictionary[int, MissionCompletionRecord]` | Keyed by `difficulty_tier` (1/2/3). See Rule 4. |

   `MissionCompletionRecord` (inline struct, not a standalone Resource): `completed: bool` (default `false`), `best_time_seconds: float` (default `-1.0`, a sentinel meaning "no time recorded yet" — never `0.0`, which would be a real, if implausible, completion time).

2. **`cell_size` is a fixed project-wide constant — this closes Grid System's Open Question OQ-4.** Decision: `cell_size = 64.0` world units, for every mission, always. Rationale:
   - No other GDD's formulas, tuning knobs, or visual calibration currently scale with a *varying* `cell_size` — hero movement feel, tower attack range in cells (`tower_attack_range_cells_max`, registered at 8 cells), and the Tower Mastery/hero proximity radius (`hero_class_proximity_radius_cells`, registered at 3 cells) are all calibrated once, in cell units, against a single implicit physical scale. A per-mission `cell_size` would require re-validating all of these against every mission's own value — a maintenance burden with no corresponding design benefit at Alpha scope.
   - The actual mission-shape/pacing/difficulty lever the project needs is `grid_cols` × `grid_rows` (map footprint) and `_cell_types` layout (lane design, choke points) — both of which already vary per mission via `GridConfig`, per Grid System Rule 1. `cell_size` varying on top of that would be a second, redundant lever for the same "bigger/smaller map" outcome, expressed in world-unit scale instead of cell count — strictly worse for player-facing legibility (a minimap or UI element calibrated in cells doesn't need to know `cell_size` at all if it's constant).
   - `GridConfig` still *carries* a `cell_size` field (unchanged from Grid System's existing schema — no breaking change to `GridConfig`'s shape) so the API remains future-proofed if a genuine per-mission need emerges later (e.g., a "giant boss" special mission). Mission Select's `MissionEntry` authoring tool must always populate it with the fixed value; this is a content-authoring discipline, not a schema restriction.
   - **Registry action**: `cell_size` (value `64.0`, unit: world units per grid cell) should be added to `design/registry/entities.yaml` as a project-wide constant, sourced from this GDD, referenced by `design/gdd/grid-system.md`. Flagged at the end of this session per the standard cross-system-fact protocol.

3. **Difficulty tier selection.** The player picks exactly one `difficulty_tier: int` (1=Normal, 2=Hard, 3=Brutal) per mission attempt, matching `monster.md`'s registered enum and range exactly — this GDD does not redefine or rename the tier set. Default selection on entering CONFIGURING (Rule 6) is `recommended_difficulty_tier` from the `MissionEntry`, but the player may freely change it to any of the 3 values before launch. There is no dedicated EventBus event for a tier *change* — no `difficulty_tier_selected` event exists in the frozen event contract (`event-bus.md`), and this GDD does not invent one (assumption flagged below). The selected value is communicated exactly once, at confirm time, as the `difficulty_tier` field of `mission_launched`.

4. **Per-difficulty-tier completion tracking.** `completion_records` tracks a separate `MissionCompletionRecord` per `difficulty_tier` (1/2/3) per `mission_id` — completing a mission on Normal does not mark Hard or Brutal as complete, and a Brutal best-time is tracked independently of a Normal best-time. This gives a meaningful "I beat it on Brutal" record, consistent with the project's completionist framing (a future Encyclopedia/completionist system is a known planned feature per prior design sessions). On `mission_phase_changed` reaching `MISSION_COMPLETE` (Wave Manager-owned transition), Mission Select records the completion (see Formula 3) using whatever `difficulty_tier` was active for that attempt (the value it itself sent in that attempt's `mission_launched`).

5. **Run modifier catalogue — Mission Select is the sole emitter of `run_modifier_selected`.** Confirmed explicitly (correcting the looseness in `wave-manager.md`'s own Interactions table, which lists "Tarot System" as also sending this event — `tarot.md`'s own Rule/AC-38 already establishes Tarot is subscribe-only on this channel; this GDD is the other half of that correction, stated from the sending side). At Alpha scope, exactly 2 generic run modifiers exist at this layer (distinct from Tarot's own card-driven `mission_modifier_applied` layer):

   | `modifier_id` | `modifier_value` (float) | Effect (resolved by Wave Manager, not here) |
   |---|---|---|
   | `"extend_waves"` | `0.0` (off/default) \| `1.0` \| `2.0` | Requests `+0`/`+1`/`+2` waves added to the mission's base wave count, extending mission length. |
   | `"difficulty_growth_boost"` | `0.0` (off/default) \| `0.03` \| `0.05` | Requests an additive increase to Wave Manager's per-wave `difficulty_growth_rate` (`r`), adding challenge via steeper escalation. |

   Each is presented in the UI as a 3-position stepper (off / low / high), not a free-form slider — this keeps the option space small and each value individually playtestable. Changing a stepper's position emits `run_modifier_selected(modifier_id, modifier_value)` immediately (live, not batched on confirm) — this matches `event-bus.md`'s literal description ("Player toggles a run modifier on/off"), with `0.0` serving as the "off" value for both modifiers.

   **Assumption flagged**: `game-concept.md`'s Overview text also names "alter wave composition" as a purpose for run modifiers. This GDD does not implement a composition-altering runtime modifier at Alpha scope, because Wave Manager's `WaveConfig` (`wave_scripts`) is static per-mission authored content with no exposed runtime parameter for composition (elite density, monster mix, etc.) — inventing one here would mean designing a Wave Manager-owned data model change from the Mission Select side, which this GDD should not do unilaterally. Composition variation at Alpha is instead achieved at the content layer (a mission's `WaveConfig` is simply authored with the desired composition) rather than a player-facing toggle. Deferred to a future revision of this GDD (or a joint revision with `wave-manager.md`) if a runtime composition modifier is wanted post-Alpha.

6. **Two-step select → configure → launch flow.** Per the frozen event contract, `mission_selected` and `mission_launched` are deliberately separate events (see States and Transitions):
   - Selecting a mission tile in BROWSING emits `mission_selected(mission_id)` immediately and transitions to CONFIGURING for that mission. This does not commit the player to launching — Wave Manager and Mission HUD may use it to pre-warm/preview the mission's context, but no gameplay state (Grid, Wave Manager phase) changes yet.
   - In CONFIGURING, the player sets difficulty tier (Rule 3, no event) and toggles run modifiers (Rule 5, `run_modifier_selected` per toggle change).
   - Pressing "Launch" runs the validation gate (Rule 8) and, if it passes, emits `mission_launched(mission_id, modifiers, difficulty_tier)` and transitions to LAUNCHED (mission begins; Mission Select's own UI is dismissed).
   - The player may back out of CONFIGURING to BROWSING, or select a different mission tile directly from CONFIGURING (re-emitting `mission_selected` with the new id and resetting modifier toggles to their `0.0` defaults and difficulty tier to that mission's `recommended_difficulty_tier`), at any point before pressing Launch. No event is emitted for backing out — nothing was locked in yet, so there is nothing to cancel.

7. **`modifiers: PackedStringArray` payload contents.** The frozen `mission_launched` payload carries `modifiers` as a `PackedStringArray` (string IDs only, no values — unlike `run_modifier_selected`, which already carried each `(modifier_id, modifier_value)` pair individually as it happened). Mission Select populates this array, at launch confirm, with the `modifier_id` of every modifier currently at a non-`0.0` ("on") value. A modifier left at its `0.0` default is omitted. This is the resolved final manifest for consumers that only subscribe to `mission_launched` and were not listening for the individual `run_modifier_selected` toggles (e.g., Save & Persistence's pre-mission checkpoint, per its Dependencies note). **Assumption flagged**: the frozen payload shape does not itself specify this inclusion rule (values-non-zero-only) — no other GDD defines it, and this is Mission Select's own reasonable closure of that gap.

8. **Launch validation gate.** Before `mission_launched` fires, Mission Select checks:
   - Save & Persistence has completed its restore pass. Structurally, this should always be true by the time this screen is reachable (see Dependencies and EC-4), but the check exists as a defensive guard.
   - A `mission_id` is actually selected (i.e., the flow is in CONFIGURING or later, not BROWSING with nothing chosen).
   - `difficulty_tier` holds a valid value in `{1, 2, 3}` (guaranteed by Rule 3's default-to-recommended behavior — the player cannot reach an unset state).

   If validation fails, the Launch action is blocked at the UI level and `mission_launched` is never emitted — see EC-2.

9. **Non-duplication of Wave Manager's own clamps.** Mission Select emits raw requested modifier values (Rule 5's table) without clamping them against Wave Manager's internal safe ranges (`wave_count` 5–8, `difficulty_growth_rate` 0.10–0.25 hard-validated). Wave Manager's own existing validation and clamping (already specified in `wave-manager.md`) is the single authority for what actually happens to those requests once received — this GDD deliberately does not re-implement or shadow that logic. See Edge Cases.

10. **Mission restart after DEFEAT reuses `mission_launched`, not a trip through Mission Select's browsing UI.** This reconciles three existing constraints across GDDs: Grid System's Rule 10 ("a mission restart (DEFEAT → SCOUT) reinitializes the Grid from the same `GridConfig`"), Wave Manager's EC-9 ("the Wave Manager must return to IDLE before receiving the new `mission_launched` event... loaded fresh on the subsequent `mission_launched`"), and `game-concept.md`'s own state table ("DEFEAT → Restart mission from SCOUT — Sanctuary progress fully preserved"). The mechanism:
    - At `mission_launched` (initial launch), Mission Select caches the resolved `MissionRuntimeState` in memory (Autoload singleton field, never persisted to save): `mission_id`, the `GridConfig` instance from that mission's `MissionEntry`, `difficulty_tier`, and the active `modifiers` array.
    - On DEFEAT, the Mission HUD/in-mission UI (not Mission Select's own browsing screen) presents a "Retry" action — this is UI ownership outside this GDD's scope, per the Collaboration Protocol's UI/HUD boundary.
    - Pressing Retry calls a new, small Mission Select API — `MissionSelect.retry_current_mission() -> void` — a direct Autoload call from the Mission HUD (mirroring Grid's own justified direct-call exception for this kind of in-mission, non-EventBus-appropriate action). This function re-emits `mission_launched(mission_id, modifiers, difficulty_tier)` with the identical cached values, and re-issues the same direct `GridConfig` initialization call to Grid using the identical cached `GridConfig` instance (satisfying Grid's Rule 10 literally — "the same `GridConfig`," not a re-fetched equivalent one).
    - The player never sees Mission Select's own browsing/configuring UI during a same-mission retry — no `mission_selected` re-fires, no catalogue is shown. This is what makes DEFEAT → SCOUT a fast in-mission retry rather than a trip back through Sanctuary, per `game-concept.md`'s design intent.
    - `MissionRuntimeState` is cleared when the mission ends via `MISSION_COMPLETE` (not DEFEAT) — at that point Mission Select returns fully to BROWSING for the catalogue's next visit.
    - **Assumption flagged**: `retry_current_mission()` is a new API surface this GDD originates; no other GDD currently names it. It is a direct Autoload call, an explicit (and narrow) exception to EventBus-only communication, justified the same way Grid's own Rule 9/Rule 8 justify their direct-call exceptions (a UI-triggered, single-caller action with no benefit from event indirection).

### States and Transitions

| Mission Select State | Entry Trigger | Player Actions Available | Exit |
|---|---|---|---|
| `BROWSING` | Player reaches this screen from Sanctuary (or app start); or `MISSION_COMPLETE` clears cached runtime state | View mission catalogue; select a mission tile | Selecting a mission tile → `CONFIGURING` |
| `CONFIGURING` | `mission_selected` emitted for the chosen `mission_id` | Set difficulty tier; toggle run modifiers; select a different mission tile (re-enters `CONFIGURING` for new id); back out to `BROWSING`; press Launch | Launch validated → `LAUNCHED`. Back out → `BROWSING`. Different tile → `CONFIGURING` (new id) |
| `LAUNCHED` | Launch validation passes; `mission_launched` emitted | None (Mission Select UI dismissed; mission gameplay owns the screen) | Mission ends: `MISSION_COMPLETE` → `BROWSING` (state cleared). `DEFEAT` → dormant, retry-armed (see below) |
| `DORMANT_RETRY_ARMED` | `mission_phase_changed` reaches `DEFEAT` | None (Mission Select has no visible UI here — Mission HUD owns the Defeat screen) | Player presses Retry (as of 2026-09-27 the `MissionOutcomeScreen` Defeat panel; formerly the interim Mission HUD button, now suppressed when the screen is present) → `retry_current_mission()` called (API unchanged) → re-enters `LAUNCHED` (new `mission_launched`, same cached state). Player instead chooses to abandon to Sanctuary (Mission HUD-owned action, out of this GDD's scope) → `BROWSING` (state cleared) |

Mission Select subscribes to `mission_phase_changed` only to know when to clear or retain `MissionRuntimeState` (Rule 10) — it does not otherwise react to in-mission phase transitions (SCOUT, PRE_WAVE, WAVE_ACTIVE, INTERMISSION are entirely Wave Manager's concern).

### Interactions with Other Systems

| System | Data Flow | Data | Mechanism |
|---|---|---|---|
| Grid System | Mission Select → Grid | `GridConfig` Resource (`grid_cols`, `grid_rows`, fixed `cell_size`, `_cell_types` map) | Direct initialization call at `mission_launched` (initial launch **and** every `retry_current_mission()` restart — same `GridConfig` instance both times) |
| Wave Manager | Mission Select → Wave Manager (EventBus) | `mission_selected(mission_id)`, `run_modifier_selected(modifier_id, modifier_value)`, `mission_launched(mission_id, modifiers, difficulty_tier)` | EventBus signals, per the frozen contract |
| Mission HUD | Mission Select → Mission HUD (EventBus) | `mission_selected(mission_id)`, `mission_launched(mission_id, modifiers, difficulty_tier)` | EventBus signals |
| Tarot System | Mission Select → Tarot (EventBus, read-only) | `run_modifier_selected(modifier_id, modifier_value)` | EventBus signal. Tarot subscribes read-only for UI conflict-awareness (per `tarot.md` Rule 8) and never emits on this channel itself — Mission Select is confirmed as this channel's sole sender. |
| Save & Persistence | Save & Persistence → Mission Select | Restored `completion_records` per `mission_id`/`difficulty_tier` | `restore_order = 11`, independent of Inventory; must complete before this screen is reachable |
| Save & Persistence | Mission Select → Save & Persistence | `mission_launched` consumed for pre-mission checkpoint | EventBus signal (Save & Persistence subscribes; no direct call) |
| Mission HUD (Defeat screen) | Mission HUD → Mission Select | Calls `MissionSelect.retry_current_mission()` | Direct Autoload call (justified exception — Rule 10) |
| EventBus | Mission Select ← subscribes | `mission_phase_changed` | To track `MISSION_COMPLETE` (clear cached state) vs `DEFEAT` (retain cached state, arm retry) |

## Formulas

### Formula 1: Requested Wave Count Delta

```
requested_wave_count = base_wave_count + extend_waves_value
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `base_wave_count` | int | 5–8 | The mission's authored base wave count (cached display value; Wave Manager's loaded `WaveConfig.wave_scripts.size()` is the real source). |
| `extend_waves_value` | float | `{0.0, 1.0, 2.0}` | The `"extend_waves"` `run_modifier_selected` value currently toggled. |
| `requested_wave_count` | float | 5–10 (unclamped here) | The value Mission Select conceptually "requests." Never sent as its own field — Wave Manager derives its actual final wave count from its own `WaveConfig` content plus this modifier per its own rules. |

**Output range**: Unbounded by this GDD — 5 to 10 is the raw arithmetic range at Alpha's `base_wave_count` (5–8) and `extend_waves_value` (0–2) bounds. **Not clamped here.** Wave Manager's own registered safe range for total wave count is 5–8 (`wave_count` tuning knob, `wave-manager.md`) — any requested value above 8 is Wave Manager's own responsibility to clamp or reject (Rule 9's non-duplication decision). This GDD only defines what is *requested*, never what is *honored*.

**Worked example**: A mission with `base_wave_count = 6` and the player toggling `"extend_waves"` to its high position (`extend_waves_value = 2.0`) yields `requested_wave_count = 8` — at the top of Wave Manager's own safe range, so in this example the request is fully honored. A mission with `base_wave_count = 8` and the same toggle yields `requested_wave_count = 10` — 2 above Wave Manager's ceiling; per Rule 9, Mission Select still sends `extend_waves_value = 2.0` unmodified via `run_modifier_selected`, and Wave Manager's own clamp (not specified here) determines the actual outcome.

---

### Formula 2: Requested Difficulty Growth Rate Delta

```
requested_r = base_r + difficulty_growth_boost_value
```

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `base_r` | float | 0.15–0.25 | The mission's authored `WaveConfig.difficulty_growth_rate` (Wave Manager's own data; default 0.20). |
| `difficulty_growth_boost_value` | float | `{0.0, 0.03, 0.05}` | The `"difficulty_growth_boost"` `run_modifier_selected` value currently toggled. |
| `requested_r` | float | 0.15–0.30 (unclamped here) | The conceptual requested growth rate. Never sent as its own field — Wave Manager applies this modifier to its own `WaveConfig` value per its own rules. |

**Output range**: Unbounded by this GDD. Wave Manager's own runtime-validated hard range is 0.10–0.25 (`wave_reward_scalar`/`difficulty_growth_rate`, `wave-manager.md`) — a `requested_r` above 0.25 is Wave Manager's own clamp responsibility (Rule 9).

**Worked example**: `base_r = 0.20` (default), player toggles `"difficulty_growth_boost"` to high (`0.05`) → `requested_r = 0.25`, exactly at Wave Manager's own ceiling — fully honored in this example. At `base_r = 0.25` (a mission already authored at Wave Manager's max) with the same toggle, `requested_r = 0.30` — above the ceiling; Wave Manager's own clamp resolves this, not Mission Select.

---

### Formula 3: Best-Time Record Update

```
best_time_seconds' = best_time_seconds if best_time_seconds >= 0.0 and best_time_seconds <= completion_time_seconds
                      else completion_time_seconds
```

Equivalently: `best_time_seconds' = completion_time_seconds` if no prior record exists (`best_time_seconds == -1.0`, the sentinel) or the new attempt is faster; otherwise the existing record is kept unchanged.

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `best_time_seconds` | float | `-1.0` (sentinel, no record) or `> 0.0` | The stored best time for this `mission_id` + `difficulty_tier` before this attempt. |
| `completion_time_seconds` | float | `> 0.0` | Elapsed mission time for the attempt that just reached `MISSION_COMPLETE` (measured from `mission_launched` — or, for a DEFEAT-retried run, from the most recent `retry_current_mission()` re-emission — to `MISSION_COMPLETE`; a retried run's clock restarts, it is not cumulative across retries). |
| `best_time_seconds'` | float | `> 0.0` | The updated stored value. |

**Output range**: Always a positive float once any completion is recorded; never re-enters the `-1.0` sentinel state once cleared. Monotonically non-increasing over the mission's lifetime (a record can only improve or stay the same, never regress).

**Worked example**: `mission_id = "mission_02"`, `difficulty_tier = 2`, no prior record (`best_time_seconds = -1.0`). Player completes in `completion_time_seconds = 1140.0` (19:00). New `best_time_seconds' = 1140.0`. A later Hard attempt completes in `980.0` (16:20) → `best_time_seconds' = 980.0` (improved). A subsequent attempt completes in `1200.0` (20:00) → `best_time_seconds'` remains `980.0` (not overwritten — slower run does not regress the record).

## Edge Cases

**EC-1: Selecting a mission with no completion data yet (first attempt)**
> A player selects a `mission_id` whose `completion_records` dictionary has no entry for any `difficulty_tier` (first-ever attempt on this mission, on any tier). Mission Select treats every tier as `completed: false, best_time_seconds: -1.0` — the UI (out of this GDD's scope) displays this as "not yet completed / no best time." No error, no special-cased content-authoring warning; this is the normal state for any never-attempted mission/tier pair.

**EC-2: Attempting to launch with no mission selected**
> If the Launch action is somehow invoked while still in `BROWSING` (no `mission_id` chosen — should be structurally prevented by the UI graying out or hiding the Launch control outside `CONFIGURING`), the validation gate (Rule 8) blocks it. `mission_launched` is never emitted; the failure never reaches EventBus at all. This is a UI/validation-layer concern, not a Wave Manager or Grid concern — no downstream system ever observes an invalid launch attempt.

**EC-3: A run modifier request would push a Wave-Manager-owned parameter out of its own validated range**
> E.g., `requested_wave_count` (Formula 1) or `requested_r` (Formula 2) exceeds Wave Manager's own safe range. Per Rule 9 (non-duplication), Mission Select does **not** clamp, warn, or reject at its own layer — it sends the raw toggled `modifier_value` via `run_modifier_selected` exactly as selected. Wave Manager's own existing clamp/validation logic (already specified in `wave-manager.md`) is solely responsible for the resulting behavior. This GDD explicitly declines to duplicate that logic or guess at its outcome.

**EC-4: Save & Persistence not yet restored when the player somehow reaches this screen**
> Per `save-persistence.md`'s `restore_order` (Mission Select = 11, restored during the standard ascending-order restore pass before any mission can be selected), this should be structurally impossible — the Mission Select screen itself should not be reachable (main menu/Sanctuary flow gates entry until restore completes, outside this GDD's scope). As a defensive guard only (Rule 8), if this screen is somehow reached pre-restore, `completion_records` reads as empty for every mission (equivalent to EC-1's "no data yet" state, not an error) and the Launch validation gate blocks confirm until restore completion is signaled. No crash, no launch with unrestored data.

**EC-5: A save references completion data for a `mission_id` no longer in game data**
> Mirrors the orphaned-data pattern used in `hero.md` (proximity accumulator vs. unknown `class_id`) and `tower-mastery.md`. On load, if `completion_records` contains an entry keyed by a `mission_id` that does not match any currently-shipped `MissionEntry`, Mission Select restores it as orphaned data (does not discard it — supports the mission being re-added in a future content update). It is never surfaced in the catalogue UI (there is no `MissionEntry` to display it against) and cannot be selected or launched. Mission Select logs a warning (e.g., `"Orphaned completion record for unknown mission_id '[id]' — retained, not discarded."`). The load never blocks or fails on this condition.

**EC-6: Mission restart after DEFEAT reuses cached `GridConfig`, never fetches a new one**
> Per Rule 10, `retry_current_mission()` must re-supply the *same* `GridConfig` instance the mission originally launched with, not a freshly re-loaded equivalent one from the `MissionEntry`. This matters if a future hot-reload or live-content-edit path exists — the retry must not accidentally pick up an edited `GridConfig` mid-session; it must be the exact cached reference from the original `mission_launched`. If `MissionRuntimeState` is somehow missing when `retry_current_mission()` is called (e.g., called with no prior `mission_launched` — should be structurally impossible since Retry is only ever shown from within a mission's own DEFEAT state), Mission Select logs an error and takes no action — it must not silently fall back to re-fetching a fresh `GridConfig` from the catalogue, which would violate Grid's Rule 10 guarantee.

## Dependencies

### Upstream Dependencies (systems this GDD depends on)

| System | Dependency Type | What Mission Select needs from it |
|---|---|---|
| **EventBus System** | Infrastructure | Mission Select emits `mission_selected`, `run_modifier_selected`, `mission_launched`; subscribes to `mission_phase_changed` to track `MISSION_COMPLETE`/`DEFEAT`. |
| **Save & Persistence** | Data source | Restores `completion_records` (`restore_order = 11`) before this screen is reachable. Mission Select cannot show meaningful completion/best-time data without this restore having completed. |
| **Grid System** | Data contract | Mission Select's `GridConfig` payload shape (`grid_cols`, `grid_rows`, `cell_size`, `_cell_types`) is defined by `grid-system.md`, not by this GDD — this GDD only populates and delivers it. |
| **Wave Manager** | Data contract (indirect) | `wave_config_path` in `MissionEntry` must point to a valid `WaveConfig` Wave Manager can load; `base_wave_count` must stay in sync with it (content-authoring discipline, not a runtime dependency). |

### Downstream Dependents (systems that depend on this GDD)

| System | What it needs from Mission Select | Constraint on Mission Select |
|---|---|---|
| **Grid System** | `GridConfig` Resource, direct call at `mission_launched` and every retry | Must deliver the *same* `GridConfig` instance across a DEFEAT→SCOUT restart (Rule 10, EC-6) |
| **Wave Manager** | `mission_selected`, `run_modifier_selected`, `mission_launched` | Must not clamp or pre-validate modifier values (Rule 9) — Wave Manager owns that validation |
| **Tarot System** | `run_modifier_selected` (read-only) | Mission Select must remain the sole emitter on this channel (Rule 5) — Tarot never emits it |
| **Mission HUD** | `mission_selected`, `mission_launched`; direct call to `retry_current_mission()` | Retry API must be idempotent-safe against being called only from a valid DEFEAT state (EC-6) |
| **Save & Persistence** | `mission_launched` (checkpoint trigger); `completion_records` save payload shape | Payload must remain keyed `mission_id` → `difficulty_tier` → `MissionCompletionRecord` for restore compatibility |

## Tuning Knobs

| Knob | Default | Safe Range | Gameplay Effect |
|---|---|---|---|
| `cell_size` | 64.0 world units | Fixed (project constant — see Rule 2, closes Grid OQ-4) | Not a per-mission tuning lever. Changing the project-wide default affects visual/physical scale for every mission simultaneously and requires re-validating hero movement feel and all cell-based ranges (`tower_attack_range_cells_max`, `hero_class_proximity_radius_cells`) project-wide. |
| `extend_waves` step values | `{0.0, 1.0, 2.0}` | Fixed 3-position set at Alpha | Too many steps (e.g., a 0–5 range) risks requests routinely exceeding Wave Manager's 5–8 safe range, making the "high" option feel broken once Wave Manager silently clamps it. Keeping the max delta at `+2` means even an 8-wave mission's "high" request (10) is only 2 over Wave Manager's ceiling — a bounded, known gap rather than an open-ended one. |
| `difficulty_growth_boost` step values | `{0.0, 0.03, 0.05}` | Fixed 3-position set at Alpha | Small deltas relative to Wave Manager's own 0.10–0.25 range and 0.15–0.25 authored safe range — a mission already authored near the top of that range (0.25) will hit Wave Manager's hard ceiling exactly at the boost's high setting; a mission authored at the low end (0.15) has headroom for both steps without ever needing Wave Manager to clamp. Raising the high step above ~0.05 risks routinely clamping regardless of a mission's authored `base_r`. |
| Alpha mission catalogue size | 4–6 missions | 3–10 | Below 3: catalogue feels sparse, undermines the mission-select screen's own reason to exist as a distinct step. Above 10 at Alpha: scope creep into full campaign-map territory, disproportionate to other Alpha-tier GDDs this session (deliberate scope discipline call, not a hard technical ceiling). |
| `recommended_difficulty_tier` per mission | Authored per mission (typically 1 for early missions) | 1–3 | Pure UI hint — has no mechanical effect on Wave Manager, Grid, or Monster System. Miscalibrating it only affects new-player guidance quality, never balance. |

## Visual/Audio Requirements

Mission Select is a utilitarian, informational screen — a list-and-toggle
configuration flow, not a piece of Sanctuary content. It belongs to the
Inventory/Crafting/Tarot UI-panel visual language, not the diorama/living-world
language used for Menagerie or Defense Building. No mission thumbnail, icon, or
panel chrome here should read as a hand-carved diorama piece; it should read as
a clean operations screen the Architect-General consults before committing
forces.

**Mission list presentation**

- Missions render as a vertical list of cards (not a diorama grid). Each card
  shows: mission name, a small flat environment-motif icon (silhouette-level,
  not a diorama render — e.g. a simplified tree-line glyph for a forest
  mission), and a compact 3-column mini-table for Normal/Hard/Brutal.
- Each tier column in that mini-table shows exactly one of three non-color-only
  states: a checkmark glyph + best time text (`mm:ss`) for completed, a plain
  dash for attempted-but-not-completed-or-no-record, or a small lock glyph for
  a tier gated behind a prerequisite (if any tier gating exists — see Open
  Questions). This satisfies `save-persistence.md`'s "completion flags, best
  times" payload directly on the list, with no drill-in required.
- Cards use UI Chrome/UI Parchment tones only (Sec 4.4) — no world-saturation
  Sanctum Amber, Parchment Cream, Verdant Green, or Threat Crimson at full
  intensity anywhere on this screen, matching the project's standing "UI
  reads as UI" discipline.

**Difficulty tier visual coding (Normal / Hard / Brutal)**

Shape-first escalation, color-second, per Sec 4.5 discipline (every state
distinction needs a non-color backup) — extends Crafting's shape-first
rarity-coding precedent (circle/hexagon/diamond) to a different primitive
better suited to an *ordered* escalation rather than a categorical set:

| Tier | Shape cue | Color (confirmatory only) | Rationale |
|---|---|---|---|
| Normal | 1 filled chevron | UI Accent Cyan | Calm/informational register — matches Accent Cyan's existing "this is interactive/available" meaning |
| Hard | 2 filled chevrons | UI Warning Orange | Caution register, reuses the existing UI Warning vocabulary rather than inventing a new mid-tier hue |
| Brutal | 3 filled chevrons | Reduced-saturation Threat Crimson | Reuses the project's established danger/threat hue (Art Bible 4.2) at reduced saturation for a UI context — same "existing hue, UI-shifted" pattern the HUD's PC-2 blocked-cell treatment already sets a precedent for, rather than inventing a fourth UI color |

Chevron *count* is the primary, fully colorblind-safe signal; color is a
confirmatory tint on the pip cluster, never the sole differentiator. This
mirrors Boss Purple's discipline of exhausting existing hues before proposing
a new one — no new color is introduced for this system.

**Run modifier toggle presentation**

- Each modifier renders as a chip/pill, reusing the project's established
  filled-vs-outline "actionable/active" convention (Crafting/Defense Building):
  **filled = currently ON**, **outline = currently OFF**. This is a direct,
  legible extension of that convention's existing meaning ("this state is in
  effect") rather than a new visual grammar.
- A single persistent summary readout ("Modifiers Active: N") sits directly
  above the launch control at all times once any mission is selected, so the
  full at-a-glance state of every toggle is visible without requiring the
  player to scan each chip individually before committing.
- Modifiers that would meaningfully lengthen or intensify the run (e.g. a
  wave-count extension) get a small numeral badge showing the resulting
  delta (e.g. "+3 waves") directly on the chip — the consequence is legible
  on the toggle itself, not hidden behind a tooltip.

**Launch-confirmation moment**

No reveal-beat treatment. This is deliberately NOT given an equivalent to
Constellation's rune ignition, Crafting's unlock-cascade, Menagerie's breeding
reveal, Tarot's card-flip, Defense Building's tech sparkle, or Tower Mastery's
amber pulse — those all mark a **permanent-progression milestone** the player
has earned; launching a mission is a **functional commitment point**, not a
milestone, and manufacturing a spectacle beat here would misrepresent it as
one. Instead:

- The launch action gets a distinct but restrained treatment: the confirm
  control itself has a heavier, more deliberate visual weight than routine
  UI confirms (a slightly larger filled control with a brief, single
  inward-settle animation on press, ~0.2s, no particles, no color flash) —
  communicating "this is weightier than a normal click" without claiming
  it's an achievement.
- The screen transition into SCOUT phase is a clean fade/wipe (UI Chrome dark
  tones, ~0.4–0.6s), sprite/color-driven per the standing Godot 4.6 glow
  constraint (no bloom dependency). No particle burst, no gold/amber
  treatment — those hues are reserved for genuine milestones elsewhere and
  must not be diluted by reuse on a routine (if weighty) action.

**Audio direction (category only — no audio bible yet)**

- Mission-card selection / tier-pip selection / modifier-toggle: routine,
  light UI blip — same category used for ordinary menu navigation elsewhere
  in the project.
- Launch-confirm: a **distinct "committing" sound**, deliberately different
  from routine menu-confirm — a lower-register, single mechanical
  lock/gate-closing tone (not a bright fanfare, not a "reward" stinger,
  since nothing is being unlocked or earned here). It should read as
  weighty and final-feeling for this button press, without borrowing the
  celebratory register any of the six reveal-beat systems use.

**Principles most directly invoked**: Sec 4.2 (Semantic Color Vocabulary —
Threat Crimson reuse for Brutal), Sec 4.4 (UI-only palette discipline), Sec
4.5 (Colorblind Safety, shape-first/color-second), Sec 3.3 (UI Shape Grammar,
lock-icon reuse for gated tiers).

## UI Requirements

**Overall screen flow**

One continuous screen, not a wizard sequence. Three zones, always on one
screen with progressive disclosure:

1. **Mission list** (primary/left region) — always visible and interactive.
2. **Difficulty + modifiers panel** (right region) — empty/placeholder state
   until a mission is selected from the list; populates immediately on
   selection with that mission's tier picker and modifier chips.
3. **Persistent launch bar** (bottom) — shows the modifier summary readout and
   the Launch control; disabled/greyed (non-color-paired, per Sec 4.5) until
   both a mission and a tier are selected.

A wizard-step sequence was considered and rejected: this screen is visited
before every single mission, making it one of the most frequently-revisited
screens in the game — a multi-step forward/back flow would add navigation
friction to a screen whose own framing (per this GDD's premise) is explicitly
utilitarian and infrastructural, not a deliberate content-browsing experience
like Crafting or Tarot. One continuous screen keeps repeat visits fast.

**Confirm convention for the final launch action**

**Two-step, but lightweight** — an "arm, then confirm" pattern on the same
Launch control, not a modal dialog:

- First press of Launch expands an inline recap directly in the launch bar
  (mission name, tier, full modifier list) and the control itself relabels
  to a distinct "Confirm Launch" state.
- Second press (same control, same location) commits and transitions to
  SCOUT phase.
- Pressing any other control (reselecting a mission, changing tier, toggling
  a modifier) while armed silently disarms it back to the first-press state
  — no confirmation is required to back out, only to proceed.

**Justification against precedent**: Crafting's single-confirm precedent is
scoped to actions that are routine, frequent, and reversible-by-repetition.
Menagerie's full modal two-step is reserved for actions that permanently
destroy player-authored content (a bred creature). Launch is neither — it
doesn't destroy anything, but committing to the wrong tier or modifier set
costs the player a real chunk of played time (a full mission run) before
they can return here, which is a meaningfully higher mis-click cost than a
recraftable item. A lightweight arm/confirm pattern adds the deliberate
pause the stakes warrant without borrowing the heavier modal weight reserved
for genuinely irreversible loss.

**Surfacing best-time/completion data without drill-in**

Fully covered on the mission card itself (Visual/Audio Requirements above) —
the 3-column Normal/Hard/Brutal mini-table with checkmark+time / dash / lock
per cell is always visible in the list. No detail view or tooltip is required
to see per-tier completion and best time; a drill-in view may still exist for
other purposes but is never load-bearing for this data.

**Gamepad navigation model**

Consistent with the established model across Inventory/Crafting/Menagerie/
Tarot/Defense Building:

- D-pad/left-stick moves selection within the mission list using 2D spatial
  adjacency; moving past the list's right edge crosses into the difficulty
  tier pips, then into the modifier chip row, then into the launch bar —
  the whole screen is one adjacency space, not separately-tabbed regions.
- Shoulder buttons (LB/RB) cycle mission sort/category if the catalogue is
  large enough to warrant grouping (see Open Questions on catalogue size).
- Single confirm button: selects a mission card (populates the right panel),
  selects a tier pip, or toggles a modifier chip. On the Launch control
  specifically, confirm performs the arm/confirm two-step described above —
  this is the only control on the screen where confirm has this two-stage
  behavior; everywhere else on this screen confirm is a single immediate
  action.
- No drag-and-drop anywhere on this screen (unlike Inventory/Crafting) — it
  requires no gamepad drag-drop carve-out at all, simplifying parity work
  relative to those systems.
- Focus rendering: same non-color outline + slight scale highlight used
  project-wide.
- Keyboard-only mirrors the same adjacency model (arrow keys / Tab-Shift+Tab,
  Enter/Space to confirm).

**Accessibility notes**

- Difficulty tier is never color-only: chevron count is the primary signal,
  color is confirmatory (Sec 4.5).
- Modifier on/off state is never color-only: filled-vs-outline is the primary
  signal, matching the project's existing convention.
- Completion/best-time data uses glyphs (checkmark/dash/lock) plus explicit
  `mm:ss` text — never a color-coded cell with no other differentiator.
- The disabled Launch control (before mission+tier are both selected) follows
  the project's standing UI Disabled Grey + icon/opacity treatment (Sec 4.5
  Pair 3 — BLOCKING), never grey-alone.
- Text scaling and contrast follow the same WCAG-equivalent minimums applied
  to other UI-panel screens (Crafting/Inventory) — this screen introduces no
  new contrast exceptions.

## Acceptance Criteria

### Group 1 — Mission Catalogue & `cell_size` Resolution (Rules 1, 2)

- **AC-1** *(Config/Data)*: GIVEN the Alpha mission catalogue (4–6 `MissionEntry` resources), WHEN every entry's `grid_config.cell_size` field is inspected, THEN it reads exactly `64.0` for every single mission with zero variance — no `MissionEntry` in the catalogue authors a different value. This is a content-validation smoke check, not a runtime behavior test.
- **AC-2** *(closes Grid System OQ-4 — the dedicated `cell_size` constant AC)*: GIVEN two different missions with deliberately different `grid_cols`/`grid_rows`/`_cell_types` (map footprint varies, per Grid System Rule 1), WHEN each mission's `GridConfig` is delivered to Grid at `mission_launched`, THEN `cell_size` is identical (`64.0`) across both deliveries while `grid_cols`, `grid_rows`, and `_cell_types` differ — proving `cell_size` is a fixed project-wide constant carried *through* `GridConfig`, not an authored per-mission value, even though the `GridConfig` schema field itself is unchanged and still present (Rule 2's "field exists, value doesn't vary" distinction). **Interface note**: this AC exercises `GridConfig`'s existing schema, not a new API — no interface dependency flag needed.
- **AC-3**: GIVEN a `MissionEntry`'s `base_wave_count` field, WHEN compared against its linked `WaveConfig.wave_scripts.size()` (read only by a content-validation script, never at runtime by Mission Select itself), THEN the two values match at content-authoring time. This is a Config/Data smoke check (mirrors Wave Manager's own AC-19b CI pattern) — not a runtime assertion, since Mission Select never reads `WaveConfig` at runtime (Rule 1).

### Group 2 — Difficulty Tier Selection & Completion Tracking (Rules 3, 4; Formula 3)

- **AC-4**: GIVEN a mission with `recommended_difficulty_tier = 2`, WHEN the player enters CONFIGURING for that mission, THEN `difficulty_tier` defaults to `2` without any player input, and the player may change it to `1` or `3` before Launch with no validation blocking any of the three values.
- **AC-5** *(the silent-tier-change assumption — dedicated AC)*: GIVEN the player is in CONFIGURING and changes the difficulty tier selection three times in a row (e.g., 2 → 1 → 3), WHEN every EventBus emission during this sequence is recorded, THEN zero events fire as a result of the tier changes themselves — no `difficulty_tier_selected` or equivalent event exists or is emitted. The only observable signal of the final tier choice is the `difficulty_tier` field inside `mission_launched`, fired once, at confirm time. This explicitly tests the silence Rule 3 asserts, not merely assumes it.
- **AC-6** *(Formula 3, per-tier independence)*: GIVEN `mission_id = "mission_02"` with no prior `completion_records` entries, WHEN the player completes it on `difficulty_tier = 1` (Normal) with `completion_time_seconds = 900.0`, THEN `completion_records[1] = {completed: true, best_time_seconds: 900.0}` while `completion_records[2]` and `completion_records[3]` remain `{completed: false, best_time_seconds: -1.0}` (untouched) — proving tiers are tracked independently, not as a single shared record.
- **AC-7** *(Formula 3, monotonic best-time)*: GIVEN `completion_records[2].best_time_seconds = 980.0` from a prior Hard completion, WHEN a new Hard attempt completes with `completion_time_seconds = 1200.0` (slower), THEN `best_time_seconds` remains `980.0` unchanged — a slower run never regresses the stored record.
- **AC-8** *(Formula 3, sentinel handling)*: GIVEN `completion_records[3].best_time_seconds = -1.0` (sentinel, never completed), WHEN a Brutal attempt completes with any positive `completion_time_seconds`, THEN the sentinel is replaced by that value — never compared against `-1.0` as if it were a real time, and never re-entered once a real completion exists.

### Group 3 — Run Modifiers & Sole-Emitter Correction (Rule 5; Formulas 1, 2)

- **AC-9** *(sole-emitter correction — mirrors `tarot.md` AC-18's "subscriber, never sender" AC from the other side)*: GIVEN a full mission lifecycle (BROWSING → CONFIGURING with modifier toggling → LAUNCHED → mission end), WHEN every EventBus emission on the `run_modifier_selected` channel across the entire game session is recorded and attributed to its emitting system, THEN Mission Select is the only system that ever appears as the emitter — Tarot never emits on this channel (per `tarot.md` AC-18), and no other system does either. This is the AC that specifically corrects `wave-manager.md`'s Interactions table, which previously listed "Tarot System" as also sending this event.
- **AC-10**: GIVEN the `"extend_waves"` stepper set to its high position, WHEN the player toggles it, THEN `run_modifier_selected("extend_waves", 2.0)` fires immediately (live, on toggle), not batched or deferred to Launch confirm.
- **AC-11** *(Formula 1, worked example)*: GIVEN `base_wave_count = 6` and `extend_waves_value = 2.0`, WHEN `requested_wave_count` is computed, THEN it equals `8` — Mission Select performs this arithmetic conceptually but never transmits `requested_wave_count` as its own field; only the raw `modifier_value` (`2.0`) is sent via `run_modifier_selected`.
- **AC-12** *(Formula 2, worked example)*: GIVEN `base_r = 0.20` and `difficulty_growth_boost_value = 0.05`, WHEN `requested_r` is computed, THEN it equals `0.25` — again never transmitted as its own field.
- **AC-13** *(composition-modifier assumption, explicitly not implemented)*: GIVEN the Alpha run modifier catalogue (`"extend_waves"`, `"difficulty_growth_boost"`), WHEN the full set of `modifier_id` values Mission Select can ever emit is enumerated, THEN no composition-altering modifier (elite density, monster mix, etc.) exists among them — confirming Rule 5's flagged deferral is actually honored in the implemented catalogue, not just stated in prose.

### Group 4 — Non-Duplication of Wave Manager's Clamps (Rule 9; EC-3)

- **AC-14** *(the non-duplication AC)*: GIVEN a run modifier toggle whose resulting `requested_wave_count` (10) or `requested_r` (0.30) would exceed Wave Manager's own registered safe ranges (`wave_count` 5–8, `difficulty_growth_rate` 0.10–0.25), WHEN Mission Select emits `run_modifier_selected`, THEN the raw, unclamped `modifier_value` (`2.0` or `0.05`) is sent exactly as selected — Mission Select performs no clamping, no rejection, no warning, and no re-implementation of Wave Manager's validation logic at its own layer. Verified by confirming Mission Select's emitted payload is bit-identical to the player's raw stepper selection regardless of the mission's authored `base_wave_count`/`base_r`, i.e., the emission is *not* a function of Wave Manager's safe-range constants at all.

### Group 5 — Two-Step Flow & `mission_launched` Payload (Rules 6, 7, 8)

- **AC-15**: GIVEN the player selects a mission tile while in BROWSING, WHEN the selection registers, THEN `mission_selected(mission_id)` fires immediately, the state transitions to CONFIGURING, and no gameplay state (Grid, Wave Manager phase) changes as a result — this AC also verifies no `mission_launched` fires at this step.
- **AC-16**: GIVEN the player is in CONFIGURING for mission A and selects a different mission tile B directly (without backing out to BROWSING first), WHEN the new selection registers, THEN `mission_selected(mission_id="B")` re-fires, run modifiers reset to their `0.0` defaults, difficulty tier resets to mission B's own `recommended_difficulty_tier`, and the state remains/re-enters CONFIGURING (now for B).
- **AC-17**: GIVEN the player backs out of CONFIGURING to BROWSING without pressing Launch, WHEN the back-out registers, THEN no EventBus event fires as a result — nothing was locked in, so nothing is cancelled.
- **AC-18** *(payload inclusion rule — Mission Select's own closure of an unspecified gap)*: GIVEN `"extend_waves"` toggled to `1.0` (on) and `"difficulty_growth_boost"` left at `0.0` (off/default), WHEN Launch is confirmed, THEN `mission_launched`'s `modifiers: PackedStringArray` contains exactly `["extend_waves"]` — the still-`0.0` `"difficulty_growth_boost"` is omitted, not included with a zero value. This proves the "non-zero-value modifiers only" inclusion rule (Rule 7) is actually implemented, since no other GDD or frozen payload spec defines this rule for Mission Select to inherit.
- **AC-19**: GIVEN all modifiers left at their `0.0` defaults, WHEN Launch is confirmed, THEN `mission_launched`'s `modifiers` array is empty (`PackedStringArray()`), not omitted or null.

### Group 6 — Launch Validation Gate (Rule 8; EC-2, EC-4)

- **AC-20**: GIVEN the flow is in BROWSING with no `mission_id` selected, WHEN a Launch action is somehow invoked (bypassing the UI's own graying-out), THEN the validation gate blocks it, `mission_launched` never fires, and no downstream system (Grid, Wave Manager, Mission HUD) ever observes the attempt.
- **AC-21**: GIVEN Save & Persistence's restore pass has not yet completed (EC-4's defensive scenario), WHEN the player attempts to reach or use Launch, THEN `completion_records` reads as empty for every mission (equivalent to EC-1's no-data state) and the Launch validation gate blocks confirm until restore completion is signaled — no crash, no launch with unrestored data.
- **AC-22**: GIVEN `difficulty_tier` is guaranteed non-empty by Rule 3's default-to-recommended behavior, WHEN the validation gate's tier check runs, THEN it always passes in practice — this AC exists to confirm the guarantee holds (no code path exists that leaves `difficulty_tier` unset once CONFIGURING is entered), not to exercise a failure path that Rule 3 asserts is unreachable.

### Group 7 — `retry_current_mission()` New API Surface (Rule 10; EC-6)

- **AC-23** *(interface dependency — RESOLVED, found stale 2026-08-27)*: GIVEN an initial `mission_launched` for `mission_id = "mission_03"` with `difficulty_tier = 2` and `modifiers = ["extend_waves"]`, followed by a `DEFEAT` phase transition and a Mission HUD-initiated call to `MissionSelect.retry_current_mission()`, WHEN the retry executes, THEN `mission_launched("mission_03", ["extend_waves"], 2)` re-fires with values identical to the original, and the *same* `GridConfig` instance (not a re-fetched equivalent) is re-delivered to Grid via direct call. **Interface note**: `retry_current_mission()` shipped in `mission_select.gd` — see `tests/integration/mission-select/retry-current-mission-api_test.gd`. Automatable.
- **AC-24**: GIVEN a completed mission run (`MISSION_COMPLETE`, not `DEFEAT`), WHEN the phase transition is observed, THEN `MissionRuntimeState` is cleared and the state returns to `BROWSING` — `retry_current_mission()` is not armed and calling it in this state is not a valid player-reachable path (contrast with AC-23's `DEFEAT` path).
- **AC-25** *(EC-6, missing-state guard)*: GIVEN `MissionRuntimeState` is somehow absent when `retry_current_mission()` is called (a structurally-should-be-impossible condition), WHEN the call executes, THEN Mission Select logs an error and takes no action — it does not silently fall back to fetching a fresh `GridConfig` from the `MissionEntry` catalogue, which would violate Grid's Rule 10 same-instance guarantee.
- **AC-26** *(Formula 3, retry timing)*: GIVEN a DEFEAT-then-retry sequence via `retry_current_mission()`, WHEN `completion_time_seconds` is measured for the retried attempt, THEN the clock restarts from the retry's `mission_launched` re-emission (not cumulative with the original failed attempt's elapsed time before DEFEAT).

### Group 8 — Edge Cases (EC-1, EC-5)

- **AC-27** *(EC-1)*: GIVEN a `mission_id` with no `completion_records` entries for any tier (first-ever attempt), WHEN the mission card is displayed, THEN every tier reads as `completed: false, best_time_seconds: -1.0` with no error or content-authoring warning.
- **AC-28** *(EC-5, orphaned save data — mirrors `hero.md`'s orphan pattern)*: GIVEN a loaded save whose `completion_records` contains an entry keyed by a `mission_id` that matches no currently-shipped `MissionEntry`, WHEN the load completes, THEN the orphaned entry is retained (not discarded), a warning is logged (`"Orphaned completion record for unknown mission_id '[id]' — retained, not discarded."`), the entry is never surfaced in the catalogue UI, cannot be selected or launched, and the load does not block or fail.

### Group 9 — States and Transitions (State Model)

- **AC-29**: GIVEN the state machine (BROWSING, CONFIGURING, LAUNCHED, DORMANT_RETRY_ARMED), WHEN every documented transition in the States and Transitions table is exercised in sequence (BROWSING → CONFIGURING → LAUNCHED → DORMANT_RETRY_ARMED → LAUNCHED [retry] → BROWSING [MISSION_COMPLETE]), THEN each transition fires only its documented entry trigger and no undocumented transition (e.g., BROWSING → LAUNCHED directly, skipping CONFIGURING) is ever reachable.
- **AC-30**: GIVEN Mission Select is subscribed to `mission_phase_changed`, WHEN phases other than `MISSION_COMPLETE` or `DEFEAT` fire (SCOUT, PRE_WAVE, WAVE_ACTIVE, INTERMISSION), THEN Mission Select takes no action and its own state (`LAUNCHED`/`DORMANT_RETRY_ARMED`) does not change — confirming it does not react to in-mission phase detail beyond the two phases it cares about.

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| ~~`cell_size = 64.0` is not yet registered in `design/registry/entities.yaml`~~ **RESOLVED** | — | Registered 2026-07-17, sourced from this GDD, `referenced_by` includes `grid-system.md`. Closed. |
| ~~`grid-system.md`'s own OQ-4 entry has not been updated to point at this resolution~~ **RESOLVED** | — | `grid-system.md`'s OQ-4 updated 2026-07-17 to record the resolution and cross-reference this document. Closed. |
| No `difficulty_tier_selected` event exists — is the resulting silence (tier changes invisible until `mission_launched`) actually acceptable, or does any consumer need live tier-change visibility before launch? | game-designer / Mission HUD owner | Flagged as an assumption in Rule 3, tested explicitly by AC-5. No known consumer currently needs pre-launch tier visibility (recommended-tier UI hint and the tier picker itself are both local to Mission Select's own screen), but this has not been confirmed against Mission HUD's or Tarot's own read requirements. If a future need for live tier-change awareness emerges (e.g., a HUD preview that reacts to tier before launch), a new event would need to be added to `event-bus.md`. |
| `MissionSelect.retry_current_mission() -> void` | Mission HUD owner / EventBus owner | **RESOLVED** (found stale 2026-08-27) — shipped in `mission_select.gd`, per its contract (Rule 10, EC-6). Called directly from Mission HUD's Defeat screen (`mission_hud.gd`). AC-23/AC-25 are now automatable. |
| ~~DEFEAT-save-then-immediate-retry checkpoint interaction — still genuinely open~~ **RESOLVED 2026-08-27** | Save & Persistence owner / Mission Select owner | `tests/integration/mission-select/defeat-retry-checkpoint-race_test.gd` covers it, live-verified via Godot MCP against the real 4.6.2.stable binary. `save-persistence.md` Rule 9's DEFEAT-triggered save had no implementation anywhere in shipped code (`TD-save-004`) — fixed same day (`save_persistence.gd` now subscribes to `mission_phase_changed`, defers a real `save_slot()` write on DEFEAT). Both real save paths near a DEFEAT+retry sequence are now implemented and verified. |
| ~~New, narrower gap found while live-verifying the above~~ **RESOLVED (accepted, not a bug) 2026-08-27** — `TD-save-005`: DEFEAT's deferred save can land right after an immediate retry and delete the retry's own fresh checkpoint | Save & Persistence owner | Investigated, not mechanically fixed: `save_checkpoint()`/`save_slot()` share one parameterless snapshot function, and `retry_current_mission()` touches only never-persisted `MissionRuntimeState` — the deleted checkpoint and the replacing full save are byte-identical, so the retried attempt loses nothing real. |
| `mission_launched.modifiers` non-zero-value-only inclusion rule (Rule 7) is Mission Select's own closure of an unspecified gap in the frozen payload shape | EventBus owner | No other GDD defines this inclusion rule; `event-bus.md` should be updated to make it explicit as part of the frozen contract rather than leaving it as an assumption local to this GDD, since any future emitter-side changes to `mission_launched` need to preserve it. Tested by AC-18/AC-19. |
| Tier-gating (a tier locked behind a prerequisite, referenced by the Visual/Audio Requirements' "lock glyph" state) is not designed anywhere in this GDD | game-designer | The lock-glyph visual state is specified defensively ("if any tier gating exists") but no Core Rule defines what would gate a tier, or whether tier-gating exists at Alpha at all. If it does not exist at Alpha, the lock-glyph visual state is dead code/UI and should be explicitly deferred rather than left ambiguous. |
~~Wave Manager's own Interactions/Dependencies table still needs a follow-up edit to remove "Tarot System" as a `run_modifier_selected` emitter~~ **RESOLVED (2026-07-17)** | Wave Manager owner | `wave-manager.md` has been edited: its Interactions and Downstream Dependencies tables now correctly split Mission Select (sole `run_modifier_selected` sender) from Tarot (`mission_modifier_applied`, a separate channel); OQ-2 marked resolved there; AC-39b added. |
