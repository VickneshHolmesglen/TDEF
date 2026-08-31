# Tower Mastery System

> **Status**: Needs Revision — a second `/review-all-gdds` re-verification pass (2026-08-31, same day) found the first fix round's Rule/Formula corrections had not propagated to this document's own Interactions table, Downstream Dependents table, and an Edge Case — all three still described the removed direct `hero_skill_tree.all_nodes_unlocked()` call, contradicting Rule 13/14/Formula 3 elsewhere in the same document. Fixed same day (third pass) — see those sections' own "corrected 2026-08-31, second pass" notes. **A third `/review-all-gdds` pass confirmed this document's own consistency fully holds** (Interactions/Downstream-Dependents/Edge-Cases/Rules/Formula 3 now all agree). It also found this document's Player Fantasy, revised in an earlier pass to match the point-grant model, still implied a permanent gold-adjacent payout once `hero-skill-tree.md`'s (now-reverted) terminal gold conversion existed — rewritten again to describe an honest, quiet terminal state once a tower's archetype is fully mastered, matching `hero-skill-tree.md`'s own reverted terminal design. Not yet re-verified a fourth time. Prior verdict (`/design-review --depth lean` re-review 2026-08-27 — sole blocker resolved) preserved for history.
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-08-31 (second pass, same day) — **`/review-all-gdds` found and fixed 5 real defects in the first companion-revision pass** (also dated 2026-08-31, described in the paragraph below): (1) a double point-grant bug (this system's Formula 3 and `hero-skill-tree.md`'s own handler both mutated `skill_tree_points`) — fixed by making Tower Mastery emit unconditionally and Hero Skill Tree the sole owner of the pool mutation; (2) an undeclared direct Autoload call (`hero_skill_tree.all_nodes_unlocked()`) violating the project's EventBus-only architecture rule, with an inverted restore-order risk — removed entirely, Tower Mastery now has zero cross-system reads; (3) a Rule 7/Rule 12 self-contradiction over whether `skill_id` is runtime-vestigial — resolved by making Rule 12 fire for every accruing signature (catalogued or not) with `skill_id` as a decorative, best-effort-only field; (4) this document's own Player Fantasy was never updated for the original revision and described mid-combat behavior (a skill "locking in") that revision deleted — rewritten; (5) several residual `unlocked_skills`/`skill_unlocked` references survived in Rules 2/3, an Edge Case (now AC-18, retired), and the Visual/Audio audio spec — all corrected. **First companion-revision pass (2026-08-31, same day, earlier)**: landed alongside `hero-skill-tree.md`'s Approved GDD, per that document's explicit "land-together, not standalone" requirement. Rule 13 (Group 4) and its supporting data model (Rule 5), Formula 3, the per-signature `MASTERED`→`POINT_GRANTING` state rename, the Interactions/Downstream Dependents tables, and the mid-combat Visual/Audio treatment were all revised: crossing a `mastery_threshold_seconds` multiple no longer directly unlocks a specific skill — it now emits `skill_tree_point_earned`, consumed by `hero-skill-tree.md`'s own node-purchase economy, which is now the **sole** remaining emitter of `skill_unlocked`. Rules 1–12 and 14 (the underlying proximity/accrual mechanism itself) remain structurally unchanged throughout both passes — only what a completed threshold *produces*, and who owns what happens next, changed.
> **Implements Pillar**: Everything Connects · Mastery-as-Vindication
> **Closes**: `hero.md` OQ6/OQ7 and `grid-system.md` OQ-1 (proximity radius/accumulator questions). **Known blocker — RESOLVED, found stale 2026-08-27**: `tower.md` Revision 23 (2026-07-17) added `TowerSystem.get_component_loadout(tower_id: int) -> Dictionary[String, String]` exactly as this GDD's Rule 4 required, but this doc's own header/body were never updated to say so. The 7 previously-blocked Acceptance Criteria (AC-07–AC-12, AC-26) are now automatable. See Open Questions.

## Overview

Tower Mastery is the game's only mid-combat progression system. While a wave is live (`WAVE_ACTIVE`) or resolving (`INTERMISSION`), the hero accumulates "mastery progress" for every moment spent within a proximity radius (the same 3-cell Chebyshev radius used by the Hero System's Tower-Synced Class) of a placed tower. Progress is tracked per *tower archetype/loadout* rather than per physical tower — because a tower's runtime `tower_id` is mission-scoped and recycled each mission, mastery is keyed to what the tower *is* (its archetype and component build), and that progress persists across missions. **Revised 2026-08-31, landing with `hero-skill-tree.md`:** crossing a threshold no longer directly and permanently unlocks a specific skill — it grants the hero one spendable skill tree point in that build signature's archetype, which the player later spends on the Hero Skill Tree System's own node chains at Sanctuary; a node purchase, not a mastery threshold, is what now hands a skill off to the Hero Skill Build System. Mechanically it is a proximity accumulator running off the `hero_position_changed` signal, in parallel with — and deliberately distinct from — the Tower-Synced Class accumulator that shares the same signal (proximity → class identity there; proximity → spendable skill tree currency here). For the player, it turns the combat field into a place to *learn* and not only to fight: it introduces a live positioning trade-off in which choosing to hold ground beside a tower — at the cost of not covering the rest of the board — is how the hero earns permanent, build-defining growth.

## Player Fantasy

> The tower does not need you to stand beside it. You are the one who needs to stand beside it.
>
> Everything else you build in the sanctuary flows outward from you. You author a tower and it holds the decision you made; you compose a constellation and it stands as you arranged it; you originate a component at the forge and it leaves your hands finished. In every one of those systems you are the source — the thing that instructs, and the sanctuary is what carries the instruction forward. Tower Mastery is the one system where the arrow runs the other way. Here the tower is the thing that knows something, and you are the one who has to learn it. It is the only part of the game where you are not the teacher but the student — and the proof that a lesson landed is the only thing in this whole loop that is earned in the middle of a live wave, with enemies on the board and the clock running, rather than in the calm of the sanctuary. **Revised 2026-08-31**: what you carry off the field is no longer the finished lesson itself — it's proof you learned *something*, a point you haven't yet decided what to spend. The actual lesson, the moment you can name what you know, waits for the sanctuary now, same as everything else. Only the earning stays where it always was: under fire.
>
> That reversal is the whole feeling, and it is what keeps this apart from the class you earn by the same standing-near. Class identity is a coronation — proximity to your towers decides *who you become*, the shape of the whole build. Mastery is an apprenticeship — proximity to a *kind* of tower decides *what you learned from it*, one specific skill at a time. One is who you are; the other is a craft you picked up from a particular teacher. And it is genuinely a *kind* of teacher, not a particular one: the tower you are standing beside will be gone when the mission ends, its very name recycled, but what it taught you is keyed to what it *was* — its archetype, its loadout — not to the fleeting instance in front of you. You are not bonding with this tower. You are learning what towers like this one can teach.
>
> None of this is free, and the fantasy should not pretend it is. Everywhere else on the field, the hero's instinct is to be where the fight is hottest — to read the wave and throw yourself at the point of maximum consequence. Standing still beside a tower is the exact opposite of that instinct. The time you spend inside its radius is time you are *not* spending covering the gap opening two lanes over; the mastery bar pays out nothing this wave, and the wave knows it. That tension is not a flaw in the system to be smoothed away — it is the system. To learn from a tower is to decide, in the middle of a fight, that this lesson is worth a lane. It is a real wager made with the one resource the hero cannot duplicate: where you are standing.
>
> **Revised 2026-08-31** — and when the bar finally fills, when you held your ground through the surge: what locks in is not the skill anymore, it's the *promise* of one — a point, banked, undecided, proof this lesson counted. The towers get dismantled. The map resets. But the point stays in you, permanent, carried into the next sanctuary visit whether you spend it there or hold it for something else you're chasing harder. That is the vindication Tower Mastery still gives you, even now that the payoff moved: a tower is the proof that you were *right*. A menagerie is the proof that you were *there*. Tower Mastery is the proof that, when the fight was pulling you everywhere at once, you chose to stay in the lesson — and walked off the field carrying something you didn't have when you walked on, even if you haven't opened it yet. **Revised again 2026-08-31, third pass**: even mastered past the point of anything left to learn from one archetype, the lesson still counts for something — for a while, it becomes a point that pays out wherever you need it most instead. But eventually, master everything there is, and there is nothing left to teach — the wager doesn't owe you a payout forever, only for as long as there was still something to learn. Standing beside a fully-mastered tower after that isn't a wasted stand, either; it just isn't a lesson anymore, and the fantasy doesn't need to pretend otherwise.

## Detailed Design

### Core Rules

#### Group 1: Cross-System Resolutions (closes Hero OQ6, Hero OQ7, Grid OQ-1)

1. **Proximity radius — CLOSES Hero `hero.md` OQ6 and Grid `grid-system.md` OQ-1.** Tower Mastery uses the **same 3-cell Chebyshev radius** as the Hero System's Tower-Synced Class accumulator. This is an intentional, confirmed shared value — not a coincidence and not a silent duplication. Rationale: (a) both mechanics answer the same underlying question — "is the hero standing close enough to a tower to be affected by it" — and giving the player two different invisible radii for two different systems that both key off standing near a tower is a legibility tax with no gameplay upside; (b) reusing the value lets both systems consume Grid's existing `get_occupied_cells_in_radius(center, radius)` (Chebyshev, O(1)) with zero new Grid API surface, per Grid's own recommendation in its Formula 3 note ("If Euclidean feel is required... a Euclidean check can be applied as a secondary filter after Chebyshev culling" — not required here, no divergence found). No `get_occupied_cells_in_euclidean_radius()` is needed. Per the registry's own instruction (`hero_class_proximity_radius_cells` entry note), this value is **not** re-registered under a second Tower-Mastery-owned name — see Dependencies for the registry update this GDD requests (a `referenced_by` addition, not a new entry).

2. **Separate accumulators — CLOSES Hero `hero.md` OQ7.** Tower Mastery maintains its own proximity accumulator, entirely independent of the Hero System's Tower-Synced Class accumulator, even though both consume the same `hero_position_changed` signal and use the same radius. They differ in every other respect: Hero's accumulator is keyed by `tower_type` (archetype only) and feeds `hero_class_unlocked`; Tower Mastery's accumulator is keyed by **build signature** (Rule 3, finer-grained than archetype) and feeds `mastery_progress_updated` / `skill_tree_point_earned` (revised 2026-08-31 — was `skill_unlocked`, which this system no longer emits, per Rule 13). Concretely, this means two separate `Dictionary` structures, two separate sets of thresholds, and two separate EventBus emissions — a shared radius constant does not imply a shared timer, and implementors must not attempt to derive one system's progress from the other's.

3. **Cross-mission mastery key ("build signature") — resolves the `tower_id`/Rule-11a persistence conflict.** Per `tower.md` Rule 11a, `tower_id` is a per-mission sequential counter that resets to 0 every mission and carries no cross-mission meaning. Because Tower Mastery progress must persist across missions (matching Hero's own cross-mission cumulative model for `proximity_time[tower_type]`), it cannot be stored keyed by `tower_id`. Tower Mastery instead defines a **build signature**: a stable string key derived from a tower's full 4-slot component loadout, not from its archetype alone (archetype is a derived property of the Foundation slot per `tower.md` Rule 5 and is therefore already implied by the signature):
   ```
   build_signature = foundation_component_id + "|" + weapon_component_id + "|" + focus_component_id + "|" + power_component_id
   ```
   Two towers — in the same mission or across different missions — with identical component IDs in all 4 slots share a build signature and therefore share a mastery track, regardless of `tower_id`. All **persistent** mastery storage (`mastery_time`, `points_granted_count` — revised 2026-08-31, was `_mastery_progress`/`_unlocked_skills`, retired by Rule 5) is keyed by `build_signature`. The `tower_id` in the live, per-mission `mastery_progress_updated` event (Rule 4) identifies *which on-screen tower instance* triggered that particular update (for Mission HUD highlighting) — it is never used as a storage key and does not need to survive past mission end on its own, consistent with the event-bus.md contract note that this event is fired live and per-mission.

4. **Cross-GDD dependency this rule creates — RESOLVED 2026-07-17, found stale here 2026-08-27**: `tower.md`'s `tower_placed` event (`TowerPlacedEvent` Resource) carries `tower_id`, `grid_position`, `archetype`, `footprint`, `placed_in_scout` — **it does not carry the 4-slot component loadout**. Tower Mastery reads it via `TowerSystem.get_component_loadout(tower_id: int) -> Dictionary[String, String]` (keys `"foundation"`, `"weapon"`, `"focus"`, `"power"`, values are component IDs) — called once, synchronously, whenever `tower_placed` or `tower_component_equipped` fires for that `tower_id`, to compute/refresh `build_signature`. `tower.md` Revision 23 added exactly this API to its own Tower Mastery dependency row.

#### Group 2: Data Model

5. **Revised 2026-08-31 (`hero-skill-tree.md` companion revision).** Tower Mastery maintains exactly two persistent (cross-mission, Save & Persistence-backed) structures, both keyed by `build_signature: String`:
   - `mastery_time: Dictionary[String, float]` — cumulative seconds of qualifying proximity, unbounded, never decreases.
   - `points_granted_count: Dictionary[String, int]` — count of skill tree points already granted for this signature, starting at 0. **Replaces the retired `unlocked_skills: Dictionary[String, bool]`** (a different key space and a different semantic: `unlocked_skills` gated a one-time permanent flag per `skill_id`; `points_granted_count` tracks how many repeating point-grants a `build_signature` has produced, per `hero-skill-tree.md` Formula 1).
   Both reset to empty on a new game (adventure start), matching Hero's own Skills-are-per-adventure precedent (`hero.md` Rule 11). **Migration note**: a save written before this revision carries `unlocked_skills` data with no `points_granted_count` populated; per `hero-skill-tree.md`'s own Dependencies section, this is an accepted, out-of-scope-for-migration gap — absence of `points_granted_count[build_signature]` is treated identically to `0` (see `hero-skill-tree.md` AC-12).

6. Tower Mastery maintains exactly one **ephemeral, per-mission** structure, keyed by `tower_id: int` (not persisted, rebuilt every mission):
   - `_active_signature_by_tower: Dictionary[int, String]` — cache of each live tower's current `build_signature`, populated on `tower_placed`, refreshed on `tower_component_equipped`, erased on `tower_removed`/`tower_destroyed`.

7. **Skill definition data model** (the skill *catalogue* itself — the actual list of skills, which build signatures teach them, and their gameplay effects — is explicitly **deferred as a content deliverable**, mirroring Hero's own deferred "class catalogue" precedent at `hero.md` Rule 23; this GDD specifies only the shape every entry must have):

   | Field | Type | Description |
   |---|---|---|
   | `skill_id` | String | Unique identifier across the entire catalogue. |
   | `source_build_signature` | String | The `build_signature` (Rule 3) whose mastery track teaches this skill. A single signature may map to at most one skill at MVP (see Rule 15 for the "already unlocked" case). |
   | `mastery_threshold_seconds` | float | Cumulative proximity seconds required to unlock. Defaults to the global `MASTERY_UNLOCK_THRESHOLD` tuning knob unless the catalogue entry overrides it. |
   | `output` | Resource reference (skill/passive definition, format owned by Hero Skill Build System) | What the hero actually receives — handed to the Hero Skill Build System on unlock. Tower Mastery does not interpret this field's contents, only forwards the reference via `skill_unlocked`'s `skill_id`. |

   **Field status after the 2026-08-31 revision (flagged, not fixed here):** only `mastery_threshold_seconds` remains load-bearing at runtime — it is the sole value `hero-skill-tree.md` Formula 1 reads from this catalogue (keyed by `build_signature`; the archetype a point is credited to is derived independently, from the signature's Foundation component, per Rule 4/`tower.md` Rule 5, not from this table). `skill_id`, `source_build_signature`, and `output` described a *direct signature-to-skill mapping* that no longer exists in the runtime data flow — a mastered signature now feeds an archetype-wide point pool, not one specific `skill_id`, and which skill a point ultimately buys is instead fixed by `hero-skill-build.md`'s own catalogue order within `hero-skill-tree.md`'s per-archetype node chain. These three fields are retained here as content-authoring reference (documenting which signature a skill was thematically designed around) but are no longer read by any runtime system. Resolving this cleanly (e.g. dropping the fields from the schema, or re-scoping them as authoring metadata only) is left to a future content-pipeline pass, not required for `hero-skill-tree.md`'s own Approval.

   The relationship to Hero: `hero_class_unlocked` (Hero's proximity → class-identity event) is **not** a hard gate on any skill unlock at MVP — no skill catalogue entry may require a specific `class_id` to be owned as a precondition. This is left as an optional, non-blocking future hook (a catalogue entry *could* add a soft bonus, e.g. faster accrual, if a matching class is owned — not specified here, not required anywhere in the locked contracts, and not implemented at MVP).

#### Group 3: Proximity Tracking

8. Tower Mastery subscribes to `mission_phase_changed` and caches the current phase locally. Accrual (Rule 10) is gated to `WAVE_ACTIVE` and `INTERMISSION` only — **SCOUT phase never accrues mastery progress**, for the same reason as Hero's own Tower-Synced Class system: SCOUT has no live combat, and this system's fantasy is explicitly "learning under fire" (see Player Fantasy). This mirrors `hero.md` Rule 15's phase gate exactly.

9. Tower Mastery subscribes to `hero_position_changed` (`grid_position: Vector2i`). On receipt, it recomputes the **qualifying-tower set** by calling `Grid.get_occupied_cells_in_radius(grid_position, TOWER_MASTERY_PROXIMITY_RADIUS)`, resolving each occupied cell to a `tower_id` via `Grid.get_occupant()`, and grouping the resulting `tower_id`s by `_active_signature_by_tower[tower_id]` into a cached `Dictionary[String, bool] _signatures_in_range`. This recompute happens **only on cell-boundary crossing** (i.e., only when `hero_position_changed` fires), not every physics frame — this directly answers event-bus.md's own note that "Tower Mastery must confirm it can handle cell-resolution granularity": cell-resolution is not merely sufficient, it is the intended granularity, because the qualifying-tower set is spatially stable between cell crossings and recomputing it every frame would be wasted work.

10. Between `hero_position_changed` events, Tower Mastery accrues proximity time every physics frame (Formula 1) for **every** `build_signature` currently marked `true` in `_signatures_in_range`, gated by the phase check in Rule 8. If the hero is simultaneously within radius of towers of two or more different build signatures, **each signature accrues independently** — proximity is not exclusive to a single "nearest" tower. If the hero is within radius of two or more towers that **share** the same build signature, that signature still accrues only once per tick (no double-counting from redundant coverage).

11. Tower Mastery also subscribes to `tower_placed`, `tower_removed`, `tower_destroyed`, and `tower_component_equipped` to keep `_active_signature_by_tower` (Rule 6) and `_signatures_in_range` (Rule 9) current without waiting for the next `hero_position_changed`: any of these four events triggers an immediate recompute of `_signatures_in_range` using the hero's last-known `grid_position`, so a tower vanishing or appearing under a stationary hero is reflected the same frame (matching the "no grace period" precedent in `hero.md`'s own Tower Affinity edge cases).

#### Group 4: Progress and Unlock

12. **Revised 2026-08-31 — resolves a Rule 7/Rule 12 self-contradiction `/review-all-gdds` found.** Every physics frame in which at least one `build_signature` accrues time (Rule 10), Tower Mastery emits `mastery_progress_updated(tower_id, skill_id, progress_percent)` (Formula 2) for **every** currently-accruing signature, catalogued or not — not just catalogued ones, since Rule 7's global-default fallback means every signature now has a real threshold to show progress against, catalogued or not. `mastery_threshold_seconds` for Formula 2's calculation uses the catalogue entry's value if one exists for this signature, else the global `MASTERY_UNLOCK_THRESHOLD` knob. `skill_id` is looked up from the catalogue entry whose `source_build_signature` matches **only if a catalogue entry exists**; if none exists, `skill_id = ""` (empty). This payload field is **decorative/best-effort only** (per Rule 7's vestigial-field note) — it does not determine which skill a point eventually buys (that's `hero-skill-tree.md`'s chain order), it's a nice-to-have flavor hint for catalogued signatures only, and Mission HUD/UI consumers must tolerate an empty value and fall back to the archetype glyph as the primary signal (see Visual/Audio 1a, also revised).

13. **REVISED 2026-08-31 (`hero-skill-tree.md` companion revision), corrected again same day (`/review-all-gdds` found a double-grant bug and an architecture violation in the first version of this revision) — Tower Mastery no longer emits `skill_unlocked` at all, and never reads or calls into Hero Skill Tree.** Every time `mastery_time[build_signature]` crosses another whole multiple of that signature's `mastery_threshold_seconds` (Rule 7 — catalogued or not, since the global `MASTERY_UNLOCK_THRESHOLD` applies when uncatalogued), Tower Mastery emits `skill_tree_point_earned(archetype, source_tower_id)` (new event; same "representative live tower_id" rule as Rule 12 for `source_tower_id`) — **unconditionally, every crossing, with no check of Hero Skill Tree's state.** This is a **repeating** emission, not a one-time unlock — see Formula 3 (revised) for the exact multiple-crossing arithmetic, which mirrors `hero-skill-tree.md`'s own Formula 1 exactly (that document's Formula 1 is the canonical version; this rule and this GDD's Formula 3 restate it from Tower Mastery's side of the boundary so this document remains self-contained). `points_granted_count[build_signature]` (Rule 5) tracks how many crossings have already been emitted for this signature, so a repeat evaluation never double-emits for the same crossing. **Tower Mastery's responsibility ends at emitting the event.** It never touches `skill_tree_points`, never calls `all_nodes_unlocked()` or any other Hero Skill Tree method, and never needs Hero Skill Tree's restored state to be available — Hero Skill Tree's own event handler decides everything downstream (credit the archetype pool, or convert to overflow if that archetype's chain is already spent — see `hero-skill-tree.md` Rule 3a/3b). The first version of this revision had Tower Mastery perform the pool increment *and* call `hero_skill_tree.all_nodes_unlocked()` directly — both were real defects (a double-grant when Hero Skill Tree also credited the same event, and an undeclared direct Autoload reference violating this project's EventBus-only architecture rule, compounded by Tower Mastery restoring at `restore_order=34` before Hero Skill Tree's `37`). Corrected same day.

14. `mastery_time` accrual does **not** stop once an archetype's chain is fully spent, or ever. It continues accumulating unbounded for the same reason as Hero's Formula 3 accumulator ("continues past the threshold to track mastery depth") — originally reserved for a future next-tier skill on the same build signature, this hook is now the load-bearing mechanism `hero-skill-tree.md`'s own repeating point income depends on (that document's Formula 1 explicitly reuses this rule). `progress_percent` (Formula 2) is clamped for *display* purposes at 100%, but the underlying `mastery_time` value is never clamped. **Tower Mastery's own emission never stops either** (corrected 2026-08-31, same pass as Rule 13 above) — `skill_tree_point_earned` keeps firing for every crossing forever, regardless of whether any archetype's chain is full. What happens to a point once its archetype's chain is spent (credited as overflow rather than dropped) is entirely `hero-skill-tree.md`'s concern, not a gate Tower Mastery enforces.

15. **REVISED 2026-08-31.** Rule 13's old one-time gate (a signature's "only catalogue entry" being already unlocked) no longer applies, since points now emit repeatedly rather than gating on a single permanent flag. The only remaining edge case at this layer is Formula 3's own repeat-crossing arithmetic (identical in shape to `hero-skill-tree.md`'s Formula 1: `new_points = floor(mastery_time / threshold) - points_granted_count`, looped per crossing, each iteration an unconditional emission) — see `hero-skill-tree.md`'s Edge Cases for what happens on its side once a mastered archetype's chain is fully spent (overflow crediting, not a no-op).

### States and Transitions

Tower Mastery does not have a single global state — the meaningful state lives **per build signature** (whether that signature is currently accruing), layered on top of a simple system-level lifecycle state. Both are shown below.

**System-level lifecycle:**

| State | Active During | Entry | Exit |
|---|---|---|---|
| `DORMANT` | No mission loaded (`SANCTUARY`) | Mission ends / game starts | `mission_phase_changed` → any in-mission phase |
| `ARMED` | `SCOUT` | `mission_phase_changed` → `SCOUT` | `mission_phase_changed` → `WAVE_ACTIVE` |
| `LIVE` | `WAVE_ACTIVE`, `INTERMISSION` | `mission_phase_changed` → `WAVE_ACTIVE` or `INTERMISSION` | `mission_phase_changed` → `SCOUT` (next mission) or mission ends |

`ARMED` exists so subscriptions are live and `_active_signature_by_tower` stays current during SCOUT placement, without any accrual occurring — this avoids a "cold start" gap where towers placed during SCOUT are unrecognized the instant `WAVE_ACTIVE` begins.

**Per-build-signature accrual state** (evaluated only while system-level state is `LIVE`):

| State | Meaning | Entry | Exit |
|---|---|---|---|
| `NOT_TRACKED` | No catalogue entry exists yet for this signature, or no tower of this signature has ever been placed this playthrough | Default | A catalogue entry is authored AND a matching tower is placed |
| `TRACKED_INACTIVE` | Catalogue entry exists; `mastery_time` is not currently accruing (hero out of range of any tower with this signature, or system-level state is not `LIVE`) | Signature enters `_active_signature_by_tower` with no matching entry in `_signatures_in_range`, or system-level state leaves `LIVE` | Hero enters range of a qualifying tower while `LIVE` |
| `TRACKED_ACCRUING` | `mastery_time[build_signature]` incrementing every physics frame (Formula 1) | Signature present in `_signatures_in_range` while system-level state is `LIVE` | Hero leaves range, or last tower of this signature is removed/destroyed, or phase changes away from `WAVE_ACTIVE`/`INTERMISSION` |
| `POINT_GRANTING` *(renamed 2026-08-31, was `MASTERED`)* | `points_granted_count[build_signature] > 0` for this signature — at least one skill tree point has ever been credited from it | `mastery_time` first crosses `mastery_threshold_seconds` | Never exits within a playthrough — `points_granted_count` only ever increases (Rule 13), but unlike the retired `MASTERED` state this is **not** a terminal "done" flag: a signature can keep re-entering the point-granting moment (Rule 13's repeating grant) indefinitely, subject only to `hero-skill-tree.md`'s spending-side archetype cap |

A signature can move `TRACKED_ACCRUING` → `POINT_GRANTING` while still allowed to remain `TRACKED_ACCRUING`-shaped afterward (Rule 14) — `POINT_GRANTING` is a flag layered on top of continued accrual, not a terminal state that stops the underlying timer. **Renamed from `MASTERED`** because that name implied a single, permanent "the skill is learned" outcome this system no longer produces directly (Rule 13's revision) — this state now only means "this signature has produced at least one point," which is compatible with producing many more.

### Interactions with Other Systems

| System | Direction | Data | Mechanism |
|---|---|---|---|
| **EventBus** | → Tower Mastery | `hero_position_changed`, `mission_phase_changed`, `tower_placed`, `tower_removed`, `tower_destroyed`, `tower_component_equipped` | Signal subscriptions connected in `_ready()` (Rules 8, 9, 11) |
| **EventBus** | Tower Mastery → | `mastery_progress_updated(tower_id, skill_id, progress_percent)`, `skill_tree_point_earned(archetype, source_tower_id)` *(revised 2026-08-31 — replaces `skill_unlocked`, which Tower Mastery no longer emits at all; see Rule 13)* | Direct signal emission (Rules 12, 13) |
| **Grid System** | Tower Mastery → Grid | `get_occupied_cells_in_radius(center, radius)`, `get_occupant(cell)` | Direct read API, called only on cell-boundary crossing or tower placement/removal events (Rule 9), not per-frame |
| **Tower System** | Tower Mastery → Tower System | `get_component_loadout(tower_id) -> Dictionary[String, String]` | Shipped in `tower.md` Revision 23 (2026-07-17), per Rule 4 |
| **Hero System** | Hero → Tower Mastery | `hero_position_changed` (read-only consumption; Tower Mastery does not call back into Hero) | EventBus subscription. Hero's own Tower-Synced Class accumulator runs in parallel off the same signal but is a fully separate system (Rule 2) |
| **Hero System** | Hero → Tower Mastery (soft, optional) | `hero_class_unlocked` | Not consumed at MVP (Rule 7) — reserved as a future non-blocking hook |
| **Hero Skill Tree System** | Tower Mastery → Hero Skill Tree | `skill_tree_point_earned(archetype, source_tower_id)` — the sole trigger for that system's point income *(new row, 2026-08-31, replaces the old direct Hero Skill Build row below)* | EventBus subscription (downstream) only. **Corrected 2026-08-31, second pass** — this row previously claimed "Tower Mastery also reads `hero_skill_tree.all_nodes_unlocked(archetype)` at grant time to stop crediting a maxed archetype," directly contradicting Rule 13/14/Formula 3's own text a few sections away. That claim described the exact direct-Autoload-call defect those rules already state was removed. Tower Mastery has zero cross-system reads of any kind — this table entry was simply never updated when the rule/formula were fixed. |
| **Hero Skill Build System** | *(no longer a direct consumer of this system, 2026-08-31)* | — Tower Mastery emits `skill_tree_point_earned` only; `skill_unlocked` (which Hero Skill Build still consumes) now originates exclusively from `hero-skill-tree.md`'s node-purchase path, not from Tower Mastery | — |
| **Mission HUD** | Tower Mastery → | `mastery_progress_updated` for live progress bars; `skill_tree_point_earned` for the "you earned a point" mid-mission notification *(revised 2026-08-31 — was `skill_unlocked`; that unlock moment now happens at Sanctuary, per `hero-skill-tree.md`)* | EventBus subscription |
| **Encyclopedia** | Tower Mastery → | *(no longer a direct consumer, 2026-08-31)* — permanent unlock logging now happens off `hero-skill-tree.md`'s `skill_unlocked`/`skill_tree_node_unlocked`, not this system | — |
| **Save & Persistence** | Bidirectional | `get_save_data()` / `restore_save_data()` / `reset_to_defaults()` for `mastery_time` and `points_granted_count` *(revised 2026-08-31 — was `unlocked_skills`; see Rule 5)* | Direct API call in `_ready()`; `restore_order = 34` (corrected 2026-08-27, found stale — this doc's self-proposed 31 collided with Hero Skill Build's already-assigned 31; `save-persistence.md` resolved to 34 on 2026-07-17) |

## Formulas

### Formula 1: Mastery Proximity Accumulation

Tracks cumulative time the hero spends near towers of a given build signature. Structurally mirrors `hero.md` Formula 3 (Class Proximity Accumulation) but keyed by `build_signature` instead of `tower_type`, and feeds a fully separate accumulator (closes Hero OQ7).

```
mastery_time[build_signature] += delta_time
    while build_signature ∈ signatures_in_range(hero_cell)
    and mission_phase ∈ {WAVE_ACTIVE, INTERMISSION}

signatures_in_range(hero_cell) = { _active_signature_by_tower[t] : t ∈ Grid.get_occupied_cells_in_radius(hero_cell, TOWER_MASTERY_PROXIMITY_RADIUS) resolved to tower_ids }
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Mastery time | `mastery_time` | float | 0 – unbounded | Cumulative seconds of qualifying proximity, per `build_signature`, per playthrough. Never decreases, never resets except new game. |
| Physics frame delta | `delta_time` | float | ~0.0167 | Godot `_physics_process` delta at 60 FPS |
| Hero cell | `hero_cell` | Vector2i | grid bounds | Cached from the last `hero_position_changed` payload |
| Proximity radius | `TOWER_MASTERY_PROXIMITY_RADIUS` | int | constant: 3 (Chebyshev) | Same value as Hero's `hero_class_proximity_radius_cells` — confirmed intentional shared constant (Rule 1) |
| Build signature | `build_signature` | String | see Rule 3 | Stable cross-mission key derived from the tower's 4-slot component loadout |
| Mission phase | `mission_phase` | enum | {SCOUT, WAVE_ACTIVE, INTERMISSION, ...} | Cached from `mission_phase_changed`; only `WAVE_ACTIVE`/`INTERMISSION` gate accrual |

**Output range:** Unbounded, monotonically non-decreasing per `build_signature`. Continues accumulating past any unlock threshold (Rule 14) to support future multi-tier skills on the same signature.

**Worked example:**
```
Mission 1: hero spends 18s within 3 cells of a tower with build_signature "found_basic|weap_frost_bolt|focus_none|power_none" during WAVE_ACTIVE
  → mastery_time["found_basic|weap_frost_bolt|focus_none|power_none"] = 18
Mission 2: hero spends 30s near a DIFFERENT tower instance with the SAME build_signature (different tower_id, e.g. tower_id=2 this mission vs tower_id=0 last mission)
  → mastery_time["found_basic|weap_frost_bolt|focus_none|power_none"] = 18 + 30 = 48
```

---

### Formula 2: Mastery Progress Percent

Converts accumulated `mastery_time` into the `progress_percent` field of `mastery_progress_updated`, clamped for display.

```
progress_percent = clamp(100.0 × mastery_time[build_signature] / mastery_threshold_seconds, 0.0, 100.0)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Progress percent | `progress_percent` | float | 0.0 – 100.0 | Emitted in `mastery_progress_updated`; clamped even though `mastery_time` itself is not |
| Mastery time | `mastery_time` | float | 0 – unbounded | From Formula 1 |
| Mastery threshold | `mastery_threshold_seconds` | float | 20 – 90 (tuning range); default 45 | Per-skill value from the catalogue entry (Rule 7), defaulting to the global `MASTERY_UNLOCK_THRESHOLD` tuning knob |

**Output range:** Strictly bounded [0.0, 100.0] — this is the one place in the system where the underlying unbounded accumulator is intentionally clamped, specifically because this value drives a HUD progress bar that must never overflow visually.

**Worked example:**
```
mastery_time["found_basic|weap_frost_bolt|focus_none|power_none"] = 48, mastery_threshold_seconds = 45
progress_percent = clamp(100 × 48/45, 0, 100) = clamp(106.7, 0, 100) = 100.0
```

---

### Formula 3: Skill Tree Point Emission (REVISED 2026-08-31 — was "Skill Unlock Condition"; corrected again same day to remove a cross-system call and a double-grant)

**Superseded arithmetic — `hero-skill-tree.md` Formula 1 is canonical.** This formula previously fired a one-time `skill_unlocked` per `skill_id`. It is restated here, from Tower Mastery's own side of the system boundary, purely so this document stays self-contained about what it itself does (emit the event); the authoritative, fully-worked version lives in `hero-skill-tree.md` Formula 1 and should be treated as the single source of truth if the two ever drift.

```
points_earnable = floor(mastery_time[build_signature] / mastery_threshold_seconds)
new_points = points_earnable - points_granted_count[build_signature]

if new_points > 0:
    archetype = archetype_of(build_signature)
    for i in range(new_points):
        emit skill_tree_point_earned(archetype, source_tower_id)   # unconditional — Tower Mastery never checks or mutates Hero Skill Tree's state
    points_granted_count[build_signature] = points_earnable
```

**Corrected 2026-08-31** — the prior version of this formula also performed `skill_tree_points[archetype] += 1` inline and gated the whole block on `NOT hero_skill_tree.all_nodes_unlocked(...)`. Both were removed: the pool increment duplicated a write `hero-skill-tree.md`'s own event handler already performs (a double-grant bug), and the `all_nodes_unlocked()` call was an undeclared direct reference into another system's Autoload, violating `systems-index.md`'s EventBus-only architecture rule — compounded by this system restoring (`restore_order=34`) before Hero Skill Tree (`37`), so the callee might not even exist yet when called. Tower Mastery's formula is now purely a function of its own state (`mastery_time`, `points_granted_count`) and has zero cross-system reads.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Points earnable | `points_earnable` | int | 0 – unbounded | Total point-crossings this signature has ever qualified for, per Rule 13 |
| New points this evaluation | `new_points` | int | 0 – unbounded (almost always 0 or 1) | Crossings not yet granted; usually 1, larger only after a long gap between evaluations |
| Mastery time | `mastery_time` | float | 0 – unbounded | From Formula 1 |
| Mastery threshold | `mastery_threshold_seconds` | float | 20 – 90 | From the catalogue entry for `build_signature` if one exists, else the global `MASTERY_UNLOCK_THRESHOLD` tuning knob (Rule 7, clarified 2026-08-31 — this fallback was always the intended reading but never stated explicitly, leaving an ambiguity `/review-all-gdds` flagged as potentially gating point income to only the 8 catalogued loadouts) |
| Points granted count | `points_granted_count[build_signature]` | int | 0 – unbounded | Persistent counter (Rule 5); replaces the retired `unlocked_skills[skill_id]` boolean gate |
| Archetype | `archetype` | String | `physical`/`ranged`/`elemental`/`support` | Derived from the build signature's Foundation component (Rule 4/`tower.md` Rule 5) — **not** a catalogue lookup |

**Output range:** `skill_tree_point_earned` fires 0 or more times per evaluation (once per crossing), unbounded over a playthrough, **forever** — this formula never stops emitting for a mastered signature, regardless of any archetype's chain state. What a fired event actually credits (an archetype pool, or overflow) is entirely `hero-skill-tree.md`'s decision, made in its own event handler, not a condition checked here.

**Worked example (continuing Formula 1/2's example):**
```
mastery_time = 48, mastery_threshold_seconds = 45, points_granted_count["found_basic|weap_frost_bolt|focus_none|power_none"] was 0
points_earnable = floor(48/45) = 1, new_points = 1
archetype_of("found_basic|weap_frost_bolt|focus_none|power_none") resolves to, e.g., "elemental" (via the Foundation component)
→ skill_tree_point_earned("elemental", source_tower_id=2) fires (tower_id=2 is the representative live tower from Mission 2, per Rule 12) — Tower Mastery's own involvement ends here; whether this credits `skill_tree_points["elemental"]` or converts to overflow is decided entirely by `hero-skill-tree.md`'s own event handler (Rule 3a/3b there), not by this system
→ points_granted_count["found_basic|weap_frost_bolt|focus_none|power_none"] = 1
```

---

### Formula 4: Build Signature Derivation

```
build_signature = foundation_component_id + "|" + weapon_component_id + "|" + focus_component_id + "|" + power_component_id
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Foundation component ID | `foundation_component_id` | String | any valid component ID | From `TowerSystem.get_component_loadout(tower_id)["foundation"]` |
| Weapon component ID | `weapon_component_id` | String | any valid component ID | `["weapon"]` |
| Focus component ID | `focus_component_id` | String | any valid component ID | `["focus"]` |
| Power component ID | `power_component_id` | String | any valid component ID | `["power"]` |
| Build signature | `build_signature` | String | any well-formed 4-part `"|"`-delimited string | Stable cross-mission key; equal for two towers iff all 4 component IDs match exactly |

**Output range:** Unbounded string space; deterministic and collision-free by construction (component IDs cannot themselves contain the `"|"` delimiter — **assumption, flagged**: this GDD assumes component ID strings from `tower.md`'s content pipeline never contain a pipe character; if that assumption does not hold, switch the delimiter or use a struct/array key instead of string concatenation).

**Worked example:**
```
foundation_component_id = "found_basic", weapon_component_id = "weap_frost_bolt", focus_component_id = "focus_none", power_component_id = "power_none"
build_signature = "found_basic|weap_frost_bolt|focus_none|power_none"
```

## Edge Cases

**Cross-Mission Key Stability**

- **If a tower is destroyed while the hero is mid-accrual near it, and no other tower with the same `build_signature` exists on the field**: accrual for that `build_signature` **pauses**, it does not reset. `mastery_time[build_signature]` retains its value. Accrual resumes automatically the moment a tower with the same `build_signature` is placed within `TOWER_MASTERY_PROXIMITY_RADIUS` of the hero's current cell (whether later in the same mission or in a future mission). This exactly mirrors `hero.md`'s own precedent for its Tower-Synced Class accumulator ("Accumulation pauses while no qualifying tower exists within range; it resumes when another tower of the same type is placed within 3 cells").

- **If the hero is simultaneously within radius of two or more towers sharing the same `build_signature`**: `mastery_time` for that signature accrues **once** per tick, not once per qualifying tower. Redundant coverage does not multiply progress.

- **If the hero is simultaneously within radius of two or more towers with *different* `build_signature`s**: each signature accrues **independently** and in parallel — this is not mutually exclusive "nearest tower wins" logic. A hero standing in an overlap zone between a frost tower and a siege tower learns from both simultaneously. This is an explicit design call (no other GDD constrains it) made to reward deliberate multi-tower placement clustering rather than punish it.

- **If a tower's component loadout changes mid-mission via `tower_component_equipped`** (e.g. a weapon component swapped during INTERMISSION): the tower's `build_signature` in `_active_signature_by_tower` is recomputed immediately from the new loadout (Rule 4). Any `mastery_time` already accrued under the **old** signature is not retroactively transferred, merged, or reduced — it remains exactly as accumulated, permanently attached to the old signature's key. The tower now contributes proximity time to the **new** signature going forward. This can leave an old signature's `mastery_time` "orphaned" at a partial value with no live tower of that signature currently on the field — this is not an error state; it behaves identically to "tower destroyed, no replacement yet" above and will simply resume accruing if a matching tower is placed again later.

**Unlock Idempotency**

- **REVISED 2026-08-31, corrected again same day (second pass).** If a `build_signature`'s mastered archetype has its chain fully spent in `hero-skill-tree.md` and the hero continues accruing proximity to that signature: `mastery_time` keeps incrementing (Rule 14) and `mastery_progress_updated` keeps firing with `progress_percent` clamped at 100.0, and `skill_tree_point_earned` **keeps firing too** — Formula 3 has no `all_nodes_unlocked` check and never stops emitting, per Rule 14's own "forever" language. This bullet previously claimed the opposite (that Formula 3's grant loop stops crediting), which was stale text left over from before that guard was removed. What happens to a fired event once the archetype's chain is full — credited as overflow, or (once all 16 nodes across every archetype are unlocked) converted to a terminal gold bonus — is entirely `hero-skill-tree.md`'s own concern; see that document's Rule 3b/3c.

- **If two different `build_signature`s happen to map to the same `skill_id`** (a content-authoring possibility not prevented by the data model in Rule 7): this is a content authoring error, not a runtime-defensible case — mirroring `hero.md`'s own precedent for its Ultimate lookup table ("A combination that causes a lookup panic is a content authoring error, not a runtime-defensible case"). The catalogue validation step (not specified here — content tooling's responsibility) must reject this at load time.

**Cross-Mission Progress Persistence**

- **If a mission ends (any exit: `MISSION_COMPLETE`, `DEFEAT`, or manual abandon) while `mastery_time[build_signature]` is mid-accrual, below threshold**: the partial progress **persists** into the next mission and the next playthrough session, exactly like Hero's own cross-mission cumulative proximity model. It is never reset to 0 by a mission ending. Only a brand-new game (adventure reset) clears it (Rule 5).

- **If a save is loaded referencing a `skill_id` in `unlocked_skills` that no longer exists in current game data** (e.g. a catalogue entry was removed or renamed post-launch): restore the entry as **orphaned** (do not discard — supports future content re-addition). Mark it `UNKNOWN` internally. Do not surface it in the Hero Skill Build UI as an equippable skill while unknown. Log a warning. **Never block the load.** This exactly mirrors `hero.md`'s own precedent for an unknown `class_id` on load.

**Grid Boundary**

- **If the hero's world position converts to an out-of-bounds grid cell** (e.g. hero briefly at the map edge during a screen-edge camera pan or similar): per `grid-system.md` EC-1, `world_to_cell` does not clamp its return value, and the caller must check `is_in_bounds()` before calling `get_occupied_cells_in_radius`. Tower Mastery must guard this exactly as Grid's own GDD requires: if `is_in_bounds(hero_cell)` is false, skip the `signatures_in_range` recompute for that update (retain the previous cached set) rather than passing an invalid cell to the Grid API.

**Phase Boundary**

- **If `mission_phase_changed` fires to `SCOUT` while one or more signatures are `TRACKED_ACCRUING`**: all accrual pauses immediately (system-level state moves `LIVE` → will move to `ARMED` on the next mission's SCOUT, or simply ends). No partial-frame accrual leaks across the phase boundary; the gate check in Formula 1 is evaluated every physics frame, so the very next frame after the phase changes, accrual simply does not add to `mastery_time` — no separate "flush" logic is needed.

## Dependencies

### Upstream Dependencies (systems Tower Mastery depends on)

| System | Dependency Type | What Tower Mastery needs from it |
|---|---|---|
| **EventBus System** | Infrastructure | Subscribes to 6 events (`hero_position_changed`, `mission_phase_changed`, `tower_placed`, `tower_removed`, `tower_destroyed`, `tower_component_equipped`); publishes 2 events, **revised 2026-08-31**: `mastery_progress_updated` (unchanged) and `skill_tree_point_earned(archetype, source_tower_id)` (new, replaces `skill_unlocked` — this document no longer emits `skill_unlocked` at all, Rule 13). `skill_tree_point_earned` needs a catalogue entry in `event-bus.md`, per `hero-skill-tree.md`'s own Dependencies section, which requested this exact addition |
| **Grid System** | Infrastructure | `get_occupied_cells_in_radius(center, radius)` and cell-to-tower resolution, called only on cell-boundary crossing or tower lifecycle events, not per-frame (Rule 9) |
| **Tower System** | Infrastructure | `get_component_loadout(tower_id) -> Dictionary[String, String]` (Rule 4) — shipped in `tower.md` Revision 23, 2026-07-17. Also relies on `tower.md` Rule 5's guarantee that a tower's archetype is fully derived from its Foundation component (no separate archetype storage needed alongside the loadout) |
| **Hero System** | Data source (read-only) | `hero_position_changed` for live grid-cell position. Tower Mastery never calls into Hero directly and never reads Hero's own class-proximity accumulator (Rule 2) |
| **Save & Persistence System** | Infrastructure | Tower Mastery implements `get_save_data()`, `restore_save_data()`, `reset_to_defaults()` for `mastery_time` and `points_granted_count` *(revised 2026-08-31 — was `unlocked_skills`; see Rule 5)*; `restore_order = 34` (after Hero's 30) — **corrected 2026-08-27, found stale**: this doc's self-proposed `31` collided with Hero Skill Build's already-assigned 31; `save-persistence.md` resolved the collision to 34 on 2026-07-17, but this row was never updated to match. |

### Downstream Dependents (systems that depend on Tower Mastery)

| System | What it needs from Tower Mastery | Constraint on Tower Mastery |
|---|---|---|
| **Hero Skill Tree System** *(revised 2026-08-31, replaces the old Hero Skill Build row — see `hero-skill-tree.md`)* | `skill_tree_point_earned(archetype, source_tower_id)` is the sole trigger for that system's point income | Must fire exactly once per whole-multiple crossing, correctly attributed to the mastered signature's Foundation-derived archetype. **Corrected 2026-08-31, second pass**: this cell previously said Tower Mastery "must stop firing for an archetype once its chain is fully spent" — contradicting Rule 14's own explicit "never stops, forever" text. Tower Mastery has no chain-completion-based constraint of any kind; what a fired event credits (an archetype pool, overflow, or — once literally all 16 nodes are unlocked — a terminal gold conversion) is entirely `hero-skill-tree.md`'s own concern. |
| **Mission HUD** | `mastery_progress_updated` for live per-tower progress bars; `skill_tree_point_earned` for the live "you earned a point" mid-mission notification *(was `skill_unlocked` — that notification moved to Sanctuary, per `hero-skill-tree.md`)* | `progress_percent` must always be in [0.0, 100.0]; `tower_id` in the payload must reference a currently-live tower this mission |
| **Hero Skill Build System** | *(no longer a direct dependent, 2026-08-31)* — now consumes `skill_unlocked` from `hero-skill-tree.md` instead, unaffected in its own rules per that document's Downstream Dependents note | — |
| **Encyclopedia** | *(no longer a direct dependent, 2026-08-31)* — permanent unlock logging now sources from `hero-skill-tree.md`'s `skill_unlocked`/`skill_tree_node_unlocked` instead | — |

### Notes

- **This GDD closes three previously-open cross-document questions**: Hero `hero.md` OQ6 (proximity radius — Rule 1, matched at 3 cells Chebyshev), Hero `hero.md` OQ7 (accumulator separation — Rule 2, confirmed two independent accumulators), and Grid `grid-system.md` OQ-1 (Chebyshev vs. Euclidean — Rule 1, Chebyshev, no new Grid API needed).
- **Registry update requested** (not performed by this GDD directly — flagging per this project's cross-system-entity protocol): `design/registry/entities.yaml`'s existing `hero_class_proximity_radius_cells` entry should have this GDD (`design/gdd/tower-mastery.md`) added to its `referenced_by` list, with a note that Tower Mastery confirmed intentional reuse of the same value rather than registering a second constant. No new registry entry is needed since the value is identical and shared.
- **Tower System dependency, RESOLVED 2026-07-17, found stale here 2026-08-27**: the `get_component_loadout(tower_id)` read API (Rule 4) was added to `tower.md`'s Interactions/API surface in Revision 23.
- **Skill catalogue is an explicit Open Question**, deferred as a content deliverable — see Open Questions. This mirrors `hero.md`'s own deferred "class catalogue" (Rule 23) and keeps this GDD's mechanics independent of specific skill content.
- The `MASTERY_UNLOCK_THRESHOLD` default of 45 seconds (Tuning Knobs) is a **design placeholder, not a locked value** — it sits deliberately between Hero's 30s (first class) and 90s (second class) thresholds on the theory that a single build-signature-specific skill should feel more attainable than a broad second class identity but should still require more than the most casual proximity; it must be validated against the frustration risk flagged in `game-concept.md`'s High-Risk Systems table once a playable vertical slice exists. **This threshold is now also the unit of `hero-skill-tree.md`'s point income** (2026-08-31) — that document's own Tuning Knobs ratified a ~2x pacing increase to reach a given skill versus the pre-revision system, as an intentional consequence of interleaving Minor nodes into the same threshold currency; any future retuning of `MASTERY_UNLOCK_THRESHOLD` now affects both documents' pacing simultaneously.
- **This GDD's Rule 13/Formula 3, its `unlocked_skills`/`MASTERED` state, and 5 downstream/Acceptance-Criteria references were revised 2026-08-31** to land together with `hero-skill-tree.md`'s Approved GDD — see this document's header for the full list of what changed. `hero-skill-tree.md` is now the sole emitter of `skill_unlocked`; this document emits only `skill_tree_point_earned`.

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| `TOWER_MASTERY_PROXIMITY_RADIUS` | 3 cells (Chebyshev) | 2–5 (must track `hero_class_proximity_radius_cells` — see Rule 1; do not diverge without re-opening OQ6) | Hero barely needs to be near a tower; mastery feels unearned, and diverging from Hero's radius reopens a legibility problem (two invisible radii) | Hero must stand nearly on the tower's cell, in direct tension with active combat movement — the exact frustration risk `game-concept.md` flags |
| `MASTERY_UNLOCK_THRESHOLD` (default per-skill; catalogue may override) | 45 seconds | 20–90 | Skill acquisition requires many missions of deliberate dwelling — players may abandon the mechanic as "not worth it" per the flagged frustration risk | Skill unlocks from incidental proximity within a single wave, making the "apprenticeship" fantasy (Player Fantasy) feel unearned and cheapening the permanent unlock's payoff |
| Accrual gate (WAVE_ACTIVE + INTERMISSION only, no SCOUT) | Fixed (not a tunable range — a structural rule, Rule 8) | N/A | N/A | N/A — allowing SCOUT accrual would let players "AFK dwell" with zero combat risk, directly undermining the "learn under fire" fantasy and the risk the mechanic is meant to justify |
| Number of qualifying signatures that can accrue simultaneously | Unbounded (Rule 10) | N/A (structural, not numeric) | N/A | If this were artificially capped to "nearest tower only," it would silently punish deliberate multi-tower clustering — recommend leaving uncapped |
| Progress-past-100% behavior (`mastery_time` continues past threshold) | Enabled (Rule 14) | N/A (structural) | N/A | Disabling this (hard-stopping the timer at threshold) would block any future multi-tier skill on the same signature without a data migration — recommend keeping enabled even though no multi-tier content exists at MVP |
| `restore_order` (Save & Persistence) | 34 (shipped 2026-07-17, corrected from this doc's original 31 proposal after a Hero Skill Build collision) | Any unclaimed integer > Hero's 30 | N/A — ordering has no real dependency, only needs to avoid collision | N/A |

**Note on the frustration risk** (`game-concept.md` High-Risk Systems table — "the tension between 'fight enemies' and 'stand near a tower' may frustrate rather than engage"): three structural choices in this GDD are the primary mitigations, and should not be weakened without deliberately re-accepting the named risk: (1) accrual **pauses, never resets** on interruption (Edge Cases — Cross-Mission Key Stability), so a hero who steps away to fight never loses progress, only defers it; (2) **partial progress persists across missions** (Edge Cases — Cross-Mission Progress Persistence), so a single mission's positioning choices are never wasted even if the threshold isn't reached; (3) the 3-cell Chebyshev radius (matching Hero's own) is generous enough that a hero actively fighting near a well-placed tower will often accrue mastery time as a side effect of normal combat positioning, not as a dedicated "go stand still" action — dwell time is not the same as idle time. Playtesting should specifically validate whether `MASTERY_UNLOCK_THRESHOLD` needs to move within its 20–90s range once real mission pacing data exists.

## Visual/Audio Requirements

> **Scope note:** Tower Mastery is the first system whose primary feedback must render live during `WAVE_ACTIVE`, competing with monster telegraphs, tower attack VFX, and Hero HP for the player's eye. Every choice below is subordinate to Mission HUD's Combat Cluster rule ("peripheral awareness, not a second focal point competing with the wave" — `mission-hud.md` Rule 7) and the art bible's glow/bloom constraint (`VERSION.md` — no bloom-dependent "accruing" or "unlocked" treatment; sprite/particle/color only).

### a) In-combat proximity/progress indicator ("in range and accruing")

- **World-space, tower-anchored, not screen-anchored.** A thin radial arc renders at the tower's base on the ground plane (same cast-shadow ground layer used by the diorama's stacked-sprite convention), sweeping clockwise from 12 o'clock as `progress_percent` climbs toward 100%. It never appears in HUD screen-space — there is no Mission HUD progress bar (see UI Requirements 1a).
- **Palette: Sanctum Amber**, not Herald Gold. `defense-building.md`'s tech-unlock treatment already drew this exact distinction — Sanctum Amber for "achievement-via-investment," Herald Gold reserved for "achievement-via-surprise" (Constellation's rune ignition, Menagerie's breeding reveal). Mastery is earned by deliberately standing still under combat pressure — investment, not discovery — so it inherits the Amber register. This also keeps it visually distinct from the Hero System's own Herald Gold Tower Affinity outline-glow (`hero.md`), which is hero-anchored and passive; Tower Mastery's arc is tower-anchored and active. Two different hues, two different anchor points — no ambiguity about which system produced which glow.
- **Fixed screen-space diameter** (does not scale with zoom) small enough to read as a subordinate ground detail, never larger or brighter than the tower sprite it belongs to or any monster telegraph on screen.
- **Non-color identifier (required, art bible 4.5):** a small archetype glyph — the same iconography used in the Tower Info Panel — sits at the arc's center so the player can identify *which archetype* is progressing (clarified 2026-08-31 — always the archetype, never a specific skill, per Rule 12) without reading color or opening a menu, particularly relevant if multiple towers of different archetypes are within proximity range simultaneously.
- No particle bloom, no looping shader emission — flat sprite arc + a subtle static particle tick at the leading edge of the fill, matching the "no bloom-dependent progress VFX" constraint.

### b) Accrual-paused state (quiet, non-punishing)

Two distinct causes, two distinct treatments — deliberately underplayed, since the design brief explicitly rejects a failure-state read:

- **Hero steps out of range (tower still alive):** the arc freezes in place at its current fill and its opacity steps down (~100% → ~55%). No motion, no color shift, no sound (see 1d). It resumes instantly and silently the moment the hero re-enters range. This is the lowest-severity state — the tower is fine, the hero just moved — and should barely register as a change at all.
- **Source tower destroyed:** the arc plays the same Fieldstone Grey desaturate-and-fade `constellation.md` already uses for its rune-deactivation beat ("quicker and duller so it never competes with the positive activation beat," ~0.5s). Reusing this exact visual vocabulary is deliberate — the game already has a "the anchor is gone, not your fault" register, and Tower Mastery should speak it rather than invent a second one. Whether the underlying `progress_percent` value persists, transfers, or resets on tower destruction is a Detailed Rules decision outside this section's scope — visually, only the arc's disappearance is specified here.

### c) `skill_tree_point_earned` moment (mid-combat) — *revised 2026-08-31, was "`skill_unlocked` moment (permanent milestone)"*

**This beat's meaning changed with the 2026-08-31 companion revision.** Crossing a threshold mid-combat no longer permanently unlocks a specific named skill — it grants one spendable skill tree point in the mastered archetype (Rule 13). The mid-combat moment therefore reads as "you earned a point," not "you learned [Skill Name]" — the latter, bigger reveal now happens at Sanctuary when the player actually spends the point on a `hero-skill-tree.md` node, not here. Still a genuine, if smaller, moment — constrained to never pause or dominate the screen since it fires mid-wave. Two parts, both brief:

1. **In-world flourish at the tower:** the arc briefly intensifies to full-saturation Sanctum Amber and pulses once (~0.5–1s — matching Constellation's own pacing rule, "fast, satisfying, not prolonged, a Mastery-as-Vindication payoff beat, not a spectacle"), then clears entirely — its job is done, it does not persist as a "completed" badge on the tower.
2. **Non-blocking HUD corner callout:** reuses the corner-confirmation pattern Constellation already established (small, non-blocking) but **now names the archetype and pool count, not a skill** — e.g. "Physical Point Earned" plus the archetype glyph, not "Skill Learned: [Name]" (no specific skill name exists to show yet at this moment — which skill a point eventually buys is a Sanctuary-side decision the player hasn't made). Auto-dismissing after a few seconds. Exact corner/pixel placement is `design/ux/mission-hud.md`'s call, but it must sit in a corner clear of the Combat Cluster's HP/cooldown grouping, never top-center or screen-center (top-center is already reserved for path-update banners per `mission-hud.md` Rule 13).
3. **Explicitly deferred:** the actual "you learned [Skill Name]" reveal — full skill description, build implications, comparison to other learned skills — now belongs entirely to `hero-skill-tree.md`'s own Sanctuary-side spend screen, the moment a node is purchased, not to this mid-combat beat at all. Tower Mastery's mid-combat beat only ever confirms *that a point was earned and for which archetype*; it does not name or sell a specific skill, because at grant time no specific skill has been chosen yet.
4. **Stays in the Amber family**, not Herald Gold — even at its most intense moment, this system's signature never borrows the Constellation/Menagerie "surprise" register (consistent with 1a's rationale). This keeps the whole system's visual arc — accruing, paused, point-earned — coherent within one hue family from start to finish.

### d) Audio (category only)

> **Real content sourced 2026-08-28 (S9-03)**, per the project's Option A audio pipeline decision (`production/qa/audio-content-pipeline-decision.md` — licensed/CC0 packs, specifically Kenney's Interface Sounds pack): `tower_mastery_proximity_entered` (Kenney `tick_001.wav`) and `tower_mastery_proximity_exited` (Kenney `close_001.wav`) are both real, wired, and audible now via `AudioCueDispatcher`'s new playback path (`assets/data/audio/audio_cue_map.tres`). **Honest first-pass caveat on `skill_unlocked`** (Kenney `confirmation_001.wav`): this is a competent generic UI success chime, not the "bell/sparkle, magical timbre" this category spec calls for specifically — Option A's own documented quality ceiling (stock SFX, not pillar-bespoke). It satisfies the non-goal (never mistakable for combat SFX) and is real, audible content closing the mechanism-vs-content gap, but is a candidate for a Option C (custom) revisit later if the generic chime doesn't land in playtest.

- **No continuous loop during accrual.** `WAVE_ACTIVE`'s audio mix is already dense (tower attacks, hit confirms, hero damage per prior GDDs' own notes); progress is conveyed visually only. Two short, quiet, non-alarming stingers bookend a proximity session: a soft one-shot "enter range" tick when accrual begins, and an even softer descending tone when it pauses (either cause from 1b) — both low in the mix, easily ignored, never demanding attention.
- **`skill_tree_point_earned`/`skill_tree_overflow_point_earned` get a distinct one-shot chime** (corrected 2026-08-31 — was specified for `skill_unlocked`, which this system no longer emits; the chime described here always belonged to *this system's* mid-combat moment, only the event name was stale) — bell/sparkle timbre, magical rather than mechanical or percussive, at a noticeably higher frequency register than combat SFX (tower attacks and hit confirms read as mechanical/impact-driven per convention). This is the deliberate anti-confusion measure the brief calls for: nothing about this sound should be mistakable for a hit confirm, a tower firing, or hero damage. Brief (~1s), one-shot, appropriately ducked against the combat mix so it's audible but not intrusive. A bigger "you learned [Skill Name]" audio/visual beat for the Sanctuary-side node-purchase moment is a separate, later beat this system's audio spec does not own — `hero-skill-tree.md` defers its own Visual/UI treatment entirely (OQ-3), so no such spec exists yet to cross-reference; this system's chime only ever confirms a point was earned, mid-combat.
- **Non-goal, stated explicitly:** this system must never share a timbre family with crit-confirm, hit-confirm, or tower-attack SFX. If in doubt at implementation time, err toward a sound closer to Constellation's rune-ignition audio register than to any combat SFX.

### Coordination note

`hero.md` OQ-6/OQ-7 flag that the Hero System's Tower-Synced Class System shares the same hero-proximity-to-tower mechanic (3-cell Chebyshev radius, per `hero.md` Rule 14) for a different purpose (class identity, not skill acquisition), and explicitly asks this GDD to confirm the two are separate accumulators. That confirmation is a Detailed Rules matter, but the visual consequence is worth flagging here regardless of how it resolves: the Sanctum Amber arc specified in 1a is exclusively a Tower Mastery signal. If Tower-Synced Class proximity ever needs its own world-space feedback, it must not reuse this arc, this hue, or this anchor point — that would conflate two mechanically independent systems that happen to share an input signal (hero position). Any such request should route back through this Art Director for a distinct treatment, not be patched onto Tower Mastery's existing indicator.

## UI Requirements

### a) Mission HUD footprint

Minimal by design, and it stays that way even accounting for 1c: **no persistent Mission HUD element** for Tower Mastery. There is no per-tower progress bar, meter, or list in the Combat Cluster — the in-world tower-anchored arc (1a) is the *only* live progress display, full stop. This is the direct application of Combat Cluster's own rule that it "never grows to fill the space [the Planning Cluster] leaves" (`mission-hud.md` Rule 7): Tower Mastery earns zero permanent HUD real estate. The one HUD element this system does use is the transient corner callout at `skill_tree_point_earned` (1c-2, revised 2026-08-31 — was `skill_unlocked`), which exists only for a few seconds and then is gone.

### b) Sanctuary-side review screen

**Explicitly out of scope, deferred in full.** Tower Mastery owns no list, log, or history screen — reviewing banked points, spending them on a chain node, or managing a build is entirely `hero-skill-tree.md`'s and `hero-skill-build.md`'s responsibility (revised 2026-08-31 to name both, since spending now sits between them). This GDD's UI footprint begins and ends with the mid-combat feedback specified above.

### c) Gamepad/keyboard considerations

**None — noted explicitly rather than invented.** This system has no direct input surface: the hero earns mastery by standing in a location during normal movement, which is already fully specified by existing hero movement controls (K/M and gamepad parity is a movement-system concern, not a Tower Mastery one). No new bindings, no navigable menu, no focus states are introduced by this GDD.

### d) Accessibility

- **Non-color legibility is mandatory, not optional**, given this reads during frantic combat: the arc's *fill amount* (shape, not hue) is the primary progress signal; the archetype glyph at its center (1a) is the primary **archetype**-identity signal (clarified 2026-08-31 — this glyph always shows the mastered signature's archetype, never a specific skill_id, which is decorative/best-effort only per Rule 7/12 and never guaranteed to exist for an uncatalogued signature). Color (Sanctum Amber, at varying saturation/opacity per state) is reinforcement, never the sole channel.
- The three arc states — accruing (full-opacity Amber), paused-out-of-range (dimmed Amber, ~55% opacity, frozen), and paused-destroyed (Fieldstone Grey fade) — must remain distinguishable via **opacity and motion**, not hue alone, since all Amber-family states share a hue family by design (1a/1c-4) and some colorblind profiles may reduce contrast between adjacent warm hues.
- The HUD corner callout (1c-2) must pair the archetype glyph with a text label (revised 2026-08-31: "[Archetype] Point Earned," not "Skill Learned: [Name]" — see 1c) — never a color-only confirmation, consistent with the art bible's binding icon-before-color rule (Section 4.5).
- Both the arc and its center glyph must be legible at the game's default oblique camera distance without requiring zoom — the same "table read" standard the art bible applies to every other in-world unit (Section 5.4's Play-Angle Contract).

## Acceptance Criteria

**Cross-System Resolution: Proximity Radius (closes Hero OQ6, Grid OQ-1)**

- **AC-01** — **GIVEN** `hero.md`'s Tower-Synced Class accumulator is configured with `hero_class_proximity_radius_cells = 3` (Chebyshev), **WHEN** `TOWER_MASTERY_PROXIMITY_RADIUS` is read at Tower Mastery init, **THEN** its value is exactly `3` and its distance metric is Chebyshev — the identical numeric constant and identical metric, not merely an independently-tuned value that happens to also be 3. A test asserting `TOWER_MASTERY_PROXIMITY_RADIUS == hero_class_proximity_radius_cells` (same registry constant, single source of value) must pass; two constants with the same literal but no shared source fail this AC.

- **AC-02** — **GIVEN** a hero at `grid_position = (5,5)` and a tower placed at `(7,5)` (Chebyshev distance 2, Euclidean distance 2.0 — both metrics agree here), **WHEN** `Tower Mastery` and Hero's Tower-Synced Class system each independently evaluate range for this same hero/tower pair, **THEN** both report the tower as in-range. **AND GIVEN** the same hero and a second tower at `(5,8)` (Chebyshev distance 3 — in range; Euclidean distance 3.0 — also in range) versus a third tower at `(8,8)` (Chebyshev distance 3 — in range; Euclidean distance ≈4.24 — out of range under a Euclidean metric), **WHEN** both systems evaluate the third tower, **THEN** both report it in-range (Chebyshev, not Euclidean) — proving the metric actually used is Chebyshev and not merely a same-numbered but differently-shaped radius.

- **AC-03** — **GIVEN** Tower Mastery computes `signatures_in_range` for any `hero_position_changed` event, **WHEN** the call graph is inspected (static/dynamic trace of Grid API calls made), **THEN** the only Grid API invoked is `Grid.get_occupied_cells_in_radius(center, radius)` (Chebyshev) followed by `Grid.get_occupant(cell)`. `Grid.get_occupied_cells_in_euclidean_radius()` is never called — this method must not exist in the codebase as a dependency of Tower Mastery, confirming Grid OQ-1's "no new Grid API needed" resolution (Rule 1). A test that greps/mocks Grid's API surface and asserts zero invocations of any Euclidean-named method passes; any invocation fails this AC.

**Cross-System Resolution: Accumulator Independence (closes Hero OQ7)**

- **AC-04** — **GIVEN** a hero stands within 3 Chebyshev cells of a single tower for exactly 15 cumulative seconds during `WAVE_ACTIVE`, with Hero's Tower-Synced Class accumulator and Tower Mastery's accumulator both subscribed to the same `hero_position_changed` signal, **WHEN** the 15 seconds elapse, **THEN** Hero's `proximity_time[tower_type]` reads `15.0` **AND** Tower Mastery's `mastery_time[build_signature]` independently reads `15.0` — two separate dictionary entries in two separate structures, not one value read by both systems.

- **AC-05** — **GIVEN** the same setup as AC-04, **WHEN** Tower Mastery's internal `mastery_time[build_signature]` is forcibly mutated in a test (e.g. reset to `0.0` or advanced to `999.0`) without touching Hero's structures, **THEN** Hero's `proximity_time[tower_type]` is completely unaffected — still exactly what it independently accrued. **AND, inverted**, mutating Hero's `proximity_time[tower_type]` in isolation leaves Tower Mastery's `mastery_time[build_signature]` unaffected. This proves no shared reference, no shared backing dictionary, and no derivation of one from the other (Rule 2's "implementors must not attempt to derive one system's progress from the other's").

- **AC-06** *(revised 2026-08-31 — `skill_unlocked` replaced by `skill_tree_point_earned`, since Tower Mastery no longer emits `skill_unlocked` at all, Rule 13)* — **GIVEN** Hero's accumulator reaches its 30-second `hero_class_unlocked` threshold at the same physics frame Tower Mastery's accumulator is still short of its (different, default 45-second) `mastery_threshold_seconds`, **WHEN** that frame resolves, **THEN** `hero_class_unlocked` fires **and** `skill_tree_point_earned` does NOT fire — proving the two systems key off independently-tracked thresholds on independently-tracked timers, not a shared "proximity elapsed" gate.

**Cross-Mission `build_signature` Persistence**

- **AC-07** *(depends on `TowerSystem.get_component_loadout()` — shipped 2026-07-17, see Open Questions)* — **GIVEN** a tower is placed in Mission 1 with `tower_id = 0` and component loadout resolving to `build_signature = "found_basic|weap_frost_bolt|focus_none|power_none"`, and the hero accrues 18s of qualifying proximity to it, **WHEN** Mission 1 ends (any exit) and Mission 2 begins with a *different* tower placed at `tower_id = 0` (recycled) whose component loadout resolves to the *same* `build_signature`, **THEN** `mastery_time["found_basic|weap_frost_bolt|focus_none|power_none"]` still reads `18.0` at the start of Mission 2, and any further proximity in Mission 2 adds onto that 18s rather than starting a new entry keyed by the recycled `tower_id`.

- **AC-08** *(depends on `TowerSystem.get_component_loadout()` — shipped 2026-07-17)* — **GIVEN** a tower with `build_signature` `S1` is destroyed mid-mission with `mastery_time[S1] = 22.0`, **WHEN** a later mission places a physically new tower (`tower_id` different from the destroyed one, guaranteed by `tower_id`'s per-mission recycling) whose component loadout resolves to the identical `build_signature` `S1`, **THEN** the hero standing near the new tower resumes accruing from `22.0`, not `0.0` — a destroyed-and-replaced identical build resumes progress rather than restarting.

- **AC-09** *(depends on `TowerSystem.get_component_loadout()` — shipped 2026-07-17)* — **GIVEN** two towers are placed in the *same* mission with different `tower_id`s (e.g. `tower_id = 3` and `tower_id = 7`) but identical component loadouts in all 4 slots (same `build_signature` `S2`), **WHEN** the hero is simultaneously within radius of both, **THEN** `mastery_time[S2]` accrues exactly once per physics tick (not doubled), and when the hero is within range of only one of the two, the same single `mastery_time[S2]` entry continues accruing — confirming both towers contribute to one shared accumulator, never two separate per-`tower_id` accumulators, matching Rule 3 and the Edge Cases "redundant coverage does not multiply progress" note.

- **AC-10** — **GIVEN** `mastery_time["S1"] = 40.0` persisted from a prior mission, **WHEN** a new mission loads and Save & Persistence's `restore_save_data()` runs before any tower is placed, **THEN** `mastery_time["S1"]` reads `40.0` immediately after restore, with no dependency on any tower of signature `S1` existing yet on the field this mission (the value is a standalone persisted dictionary entry, not derived from a live tower lookup).

**New Tower System Dependency (`get_component_loadout`)**

- **AC-11** *(RESOLVED 2026-07-17, found stale here 2026-08-27 — was `[BLOCKED — depends on unimplemented API]`)* — **GIVEN** `tower_placed` fires for a `tower_id`, **WHEN** Tower Mastery's handler runs, **THEN** it calls `TowerSystem.get_component_loadout(tower_id) -> Dictionary[String, String]` exactly once, synchronously, and populates `_active_signature_by_tower[tower_id]` from the returned dictionary's 4 keys (`"foundation"`, `"weapon"`, `"focus"`, `"power"`) per Formula 4. `get_component_loadout()` shipped in `tower.md` Revision 23 — this AC is now automatable.

- **AC-12** *(RESOLVED 2026-07-17, found stale here 2026-08-27 — was `[BLOCKED — depends on unimplemented API]`)* — **GIVEN** `tower_component_equipped` fires for a live `tower_id` whose weapon component changes, **WHEN** Tower Mastery's handler runs, **THEN** `get_component_loadout(tower_id)` is called again and `_active_signature_by_tower[tower_id]` is recomputed to the new `build_signature`; `mastery_time` under the old signature is left untouched (Edge Cases — no retroactive transfer). Now automatable, same fix as AC-11.

**Frustration-Mitigation: Pause, Not Reset**

- **AC-13** — **GIVEN** `mastery_time["S1"] = 22.0` and the hero is standing within range of the only live tower with signature `S1`, **WHEN** the hero moves out of the 3-cell radius (still same mission, still `WAVE_ACTIVE`), **THEN** `mastery_time["S1"]` remains exactly `22.0` — it does not decrement, does not reset to `0.0`, and the signature's per-signature state moves from `TRACKED_ACCRUING` to `TRACKED_INACTIVE`. **WHEN** the hero later re-enters range of a tower with signature `S1` (same tower or a different one, same mission or a future one), **THEN** accrual resumes from `22.0`.

- **AC-14** — **GIVEN** `mastery_time["S1"] = 22.0` and the sole live tower with signature `S1` is destroyed (`tower_destroyed` fires) while the hero is in range, **WHEN** the destruction event is processed, **THEN** `mastery_time["S1"]` remains exactly `22.0` (pauses, does not reset), `_signatures_in_range["S1"]` becomes `false` the same frame (no waiting for the next `hero_position_changed`, per Rule 11), and the per-signature state moves to `TRACKED_INACTIVE`.

- **AC-15** — **GIVEN** the state from AC-14, **WHEN** any subsequent tower with `build_signature = "S1"` is placed within 3 cells of the hero's current position (this mission or a future one), **THEN** accrual resumes automatically from `22.0` with no manual re-trigger required — proving pause is genuinely recoverable, not a dead end requiring re-derivation.

**Cross-Mission Persistence Through Defeat**

- **AC-16** — **GIVEN** `mastery_time["S1"] = 30.0` (below its 45s threshold, no skill unlocked) accrued during a mission that ends in `DEFEAT`, **WHEN** the next mission (or Sanctuary session) loads and `restore_save_data()` runs, **THEN** `mastery_time["S1"]` still reads `30.0` — unchanged by the defeat. Mission outcome (`MISSION_COMPLETE`, `DEFEAT`, or manual abandon) has no bearing on whether progress persists; only a new-game adventure reset clears it (Rule 5).

- **AC-17** *(revised 2026-08-31 — `unlocked_skills` retired, replaced by `points_granted_count`; see Rule 5)* — **GIVEN** `points_granted_count["S1"] = 2` from a prior mission, **WHEN** the current mission subsequently ends in `DEFEAT`, **THEN** `points_granted_count["S1"]` still reads `2` after the defeat and after the next mission's restore — already-granted points are never revoked by a lost mission, mirroring the equivalent guarantee already written for `menagerie.md`, `tarot.md`, and `defense-building.md`.

**Orphaned Skill on Load**

- **AC-18** *(RETIRED 2026-08-31 — tested a dictionary this system no longer maintains)* — this AC tested orphan-handling for a legacy `skill_id` inside `unlocked_skills`, which Rule 5 retired in favor of `points_granted_count[build_signature]: int` — a dictionary with no `skill_id`s in it at all, so there is nothing for a legacy `skill_id` to orphan here anymore. The equivalent orphan-handling responsibility (an unrecognized `skill_id` surfacing in a persisted skill library) now belongs entirely to `hero-skill-build.md`'s own Edge Cases/ACs, which already cover it independently of this system.

**Core Rule / Formula Coverage**

- **AC-19** — **GIVEN** `mastery_time["S1"] = 18.0` at Mission 1 end and a different `tower_id` with the same `build_signature` accrues `30.0` more seconds in Mission 2 (Formula 1's worked example), **WHEN** Mission 2's accrual completes, **THEN** `mastery_time["S1"] = 48.0` exactly.

- **AC-20** — **GIVEN** `mastery_time["S1"] = 48.0` and `mastery_threshold_seconds = 45.0` (Formula 2), **WHEN** `mastery_progress_updated` is emitted, **THEN** `progress_percent = 100.0` (clamped) even though the underlying `mastery_time` value of `48.0` exceeds the threshold — the emitted display value never exceeds `100.0` while the stored accumulator is left unclamped at `48.0`.

- **AC-21** *(revised 2026-08-31 — restated around the point-grant model; see Formula 3)* — **GIVEN** `mastery_time["S1"]` crosses `45.0` for the first time and `points_granted_count["S1"]` is `0`, **WHEN** that frame resolves (Formula 3), **THEN** `points_granted_count["S1"]` is set to `1` before `skill_tree_point_earned(archetype_of("S1"), source_tower_id)` is emitted, and re-evaluating the same frame's condition afterward yields `new_points = 0` (idempotent, cannot double-grant the same crossing twice).

- **AC-22** *(revised 2026-08-31)* — **GIVEN** `points_granted_count["S1"] = 1` and the hero continues accruing proximity to signature `S1` past its threshold, **WHEN** further physics frames elapse without crossing another whole multiple of `mastery_threshold_seconds`, **THEN** `mastery_time["S1"]` keeps incrementing unbounded, `mastery_progress_updated` keeps firing with `progress_percent` clamped at `100.0`, and no further `skill_tree_point_earned` fires until the next whole-multiple crossing — matching Rule 14's continued-accrual, gated-grant behavior.

- **AC-22b** *(RETIRED same day it was added, 2026-08-31 — tested a guard this system no longer has)* — originally asserted that `points_granted_count`/`skill_tree_point_earned` stop advancing once an archetype's chain is fully spent. That guard (and the direct `hero_skill_tree.all_nodes_unlocked()` call it required) was removed from Formula 3 the same day for violating the EventBus-only architecture rule and causing a double-grant. Tower Mastery now emits unconditionally forever (AC-22 above already covers its actual gated-by-crossing, not gated-by-chain-state, behavior). The equivalent assertion — that a maxed archetype's further points convert to overflow rather than being lost — now belongs to `hero-skill-tree.md`'s own AC-14.

- **AC-22c** *(new, 2026-08-31 — the companion assertion `hero-skill-tree.md` AC-11 explicitly deferred to this document)* — **GIVEN** Tower Mastery's shipped implementation, **WHEN** its source is inspected (static grep or equivalent), **THEN** it contains **no** code path that emits `skill_unlocked` — the event is emitted exclusively by `hero-skill-tree.md`'s own node-purchase path (that document's Formula 2), and Tower Mastery's only outbound skill-tree-related emission is `skill_tree_point_earned`. This closes the "dead code fully removed, not merely unreachable" requirement `hero-skill-tree.md` AC-11 named but correctly declined to test from its own side of the boundary.

- **AC-23** — **GIVEN** the hero is simultaneously within radius of a tower with `build_signature = "S1"` (frost) and a different tower with `build_signature = "S2"` (siege), **WHEN** a physics frame elapses during `WAVE_ACTIVE`, **THEN** both `mastery_time["S1"]` and `mastery_time["S2"]` increment independently and in parallel by the same `delta_time` — neither is treated as "nearest tower wins," confirming Rule 10 / Edge Cases' multi-signature accrual behavior.

- **AC-24** — **GIVEN** `mission_phase_changed` fires to `SCOUT` while any signature is `TRACKED_ACCRUING`, **WHEN** the phase transitions, **THEN** all accrual halts that same frame — no partial-frame `mastery_time` increment leaks past the boundary — and `hero_position_changed` events received during `SCOUT` never cause any `mastery_time` entry to change, confirming Rule 8's SCOUT exclusion.

- **AC-25** — **GIVEN** the hero's world position converts to a cell for which `Grid.is_in_bounds(hero_cell)` returns `false` (e.g. transient edge-of-map position), **WHEN** `hero_position_changed` fires with that out-of-bounds cell, **THEN** Tower Mastery skips the `signatures_in_range` recompute entirely, retains its previously cached `_signatures_in_range`, and does not call `Grid.get_occupied_cells_in_radius` with the invalid cell — no crash, no exception, no stale-but-wrong state change.

- **AC-26** *(depends on `TowerSystem.get_component_loadout()` — shipped 2026-07-17)* — **GIVEN** two towers are placed with component loadouts differing only in the `power` slot (e.g. `power_none` vs. `power_amp`), **WHEN** `build_signature` is derived for each (Formula 4), **THEN** the two resulting strings differ, and each accrues to a distinct `mastery_time` entry — confirming the signature is derived from the full 4-slot loadout, not archetype alone (which would be identical for both, since archetype derives only from the Foundation slot per `tower.md` Rule 5).

**Test file targets:** AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-19, AC-20, AC-21, AC-22, AC-23 → `tests/unit/tower-mastery/` (Logic — BLOCKING). AC-07, AC-08, AC-09, AC-10, AC-16, AC-17 → `tests/integration/tower-mastery/` (Integration — BLOCKING; several also touch Save & Persistence). AC-13, AC-14, AC-15, AC-24, AC-25 → `tests/unit/tower-mastery/` (Logic — BLOCKING, state-machine transitions). AC-11, AC-12, AC-26 → now automatable — `TowerSystem.get_component_loadout()` shipped 2026-07-17 (found stale here 2026-08-27; was previously tracked as blocked). AC-22c → `tests/integration/tower-mastery/` (Integration — BLOCKING, land-together gate with `hero-skill-tree.md`; must be run together with that document's own emission-site AC once both ship). *(AC-18 and AC-22b retired 2026-08-31 — see their own entries.)*

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| `TowerSystem.get_component_loadout(tower_id) -> Dictionary[String, String]` | Tower System owner | **RESOLVED 2026-07-17** (found stale here 2026-08-27) — added to `tower.md`'s API surface, Revision 23. AC-07 through AC-12 and AC-26 are now automatable. |
| `MASTERY_UNLOCK_THRESHOLD` default of 45 seconds is a placeholder | Systems Designer / Producer | Explicitly flagged in this GDD's own Notes and Tuning Knobs sections as sitting between Hero's 30s/90s thresholds "on the theory that..." — not validated against real pacing data. Must be checked against the frustration risk flagged in `game-concept.md`'s High-Risk Systems table once a playable vertical slice exists. *Resolve at first balance-calibration pass, same milestone as `hero.md` OQ-2/OQ-9.* |
| `restore_order = 31` was a proposed placeholder | Save & Persistence System owner | **RESOLVED 2026-07-17** (found stale here 2026-08-27) — collided with Hero Skill Build's already-assigned 31; `save-persistence.md` corrected this doc's slot to 34. |
| Skill catalogue (the actual `skill_id` list, which `build_signature`s teach them, thresholds-per-entry, and `output` effects) is deferred as a content deliverable | Game Designer / content pipeline | Mirrors `hero.md`'s own deferred "class catalogue" (`hero.md` OQ-1). This GDD specifies only the data shape (Rule 7) — no skill exists to test against until the catalogue is authored, meaning AC-19 through AC-23's "frost_bolt_skill_a" example is illustrative, not a real catalogue entry. *Owner: Game Designer. Resolve before the full mastery→point→node→`skill_unlocked` chain (this system, then `hero-skill-tree.md`, then Hero Skill Build) can be exercised end to end with real content — corrected 2026-08-31, `skill_unlocked` itself no longer originates here.* |
| Registry update for `hero_class_proximity_radius_cells` (`referenced_by` addition) not yet performed | Registry owner (`design/registry/entities.yaml`) | This GDD's Notes section requests the addition but does not perform it — AC-01 depends on both systems reading from a genuinely single source constant; if the registry update is skipped and each system hardcodes its own literal `3`, AC-01 could pass today but silently drift later with no shared-source guarantee. *Resolve before implementation, not just before this GDD's own tests.* |
| Component ID strings are assumed never to contain the `\|` delimiter | Tower System / content pipeline owner | Formula 4's flagged assumption — if any component ID content is authored with a literal pipe character, `build_signature` collisions or malformed keys become possible. No current validation step catches this. *Owner: content tooling. Resolve before component ID content is authored at scale, or switch to a struct/array key.* |
| `get_component_loadout()`'s synchronous-call contract during rapid-fire placement (e.g. batch SCOUT placement of many towers in one frame) is unspecified | Tower System owner | Rule 4 states the call happens "once, synchronously, whenever `tower_placed` or `tower_component_equipped` fires" but neither this GDD nor `tower.md` specifies whether `tower_placed` can fire multiple times in a single frame during batch placement, and if so, whether `get_component_loadout` is guaranteed to return correct data for a tower whose components were assigned in the same frame as placement. *Owner: Tower System owner, at the same time `get_component_loadout()` itself is added.* |
