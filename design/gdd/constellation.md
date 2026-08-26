# Constellation System

> **Status**: Approved (`/design-review --depth lean` re-review 2026-08-27 — no blocking items remain)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-08-27 (OQ-1 marked resolved — stale since 2026-07-17; OQ-4 marked resolved 2026-08-24 — stale since 2026-07-18; OQ-7 performance-measurement methodology resolved)
> **Implements Pillar**: Mastery-as-Vindication · Everything Connects · The Sanctuary Is Your Statement
> **Known blockers — both resolved, this header previously not updated to say so**: ~~OQ-4~~ **RESOLVED 2026-08-24** (stale — the blocker was actually closed 2026-07-18, Sprint 6 S6-08). `tower_placed`/`tower_removed`/`tower_destroyed` all carry `constellation_eligibility_tag: String` today — see OQ-4's own entry below for the full resolution note. ~~OQ-1~~ **RESOLVED, found stale 2026-08-27** — `save-persistence.md` assigned Constellation `restore_order = 24` on 2026-07-17 (Discovery Ledger, independent of Tower's own restore), but this doc's own OQ-1 was never marked resolved to match. See OQ-1's own entry below.

## Overview

The Constellation System is a pure pattern-detection layer that sits directly on top of the Tower System: it adds no towers, no attacks, and no combat of its own — it reads the arrangement of towers already on the field and rewards the ones that form the right shapes. Technically, it is both a data/detection engine and a player-facing effect. As an engine, it subscribes to the Tower System's placement and removal events, evaluates whether *constellation-eligible* towers — those whose `power` slot carries a `constellation_eligibility_tag` — occupy a recognized geometric arrangement on the 16×12 mission grid (adjacency measured by Chebyshev distance), and when a pattern matches, activates it: granting a typed bonus (buff type and value) to exactly the towers that contribute to the shape. When the shape breaks — a contributing tower destroyed, or moved out of position — the pattern deactivates immediately and its bonus is withdrawn from all contributors in the same frame. The system owns no tower state and no combat logic; it observes tower configuration through the EventBus and writes its buffs back through the same channel, so a constellation is never special-cased against any one tower — it is a structural reading of how the towers relate. Player-facing, it transforms the act of placement into an act of composition: the field stops being a set of independently optimized firing positions and becomes a layout whose *arrangement* carries meaning the individual towers cannot.

## Player Fantasy

> A tower is a decision. A constellation is the decision about how your decisions fit together.
>
> Placed alone, a tower asks you only one question: is this the right spot for what it does? Does it reach the chokepoint, does it face the lane, does it stand where the wave will break against it? The Constellation asks a second, harder question on top of that one — is this the right spot for what these towers do *together*? This is the layer of play that opens after placement and before the wave, when you look at the field you've built and stop seeing four separate machines. You start seeing the shape they almost make, and you realize the field is asking you to finish a thought you didn't know you'd started.
>
> Sometimes finishing it means putting a tower where it is slightly wrong on its own. A degree off its best angle. A cell short of its best range. You do it anyway, because the arrangement it completes gives back more than the tower gives up — and choosing the arrangement over the tower is a thing only you can see to do. This is the difference between placing good pieces and composing with them. A collector fills the board with strong towers. A composer subordinates the piece to the pattern, trades the local best for the greater whole, and trusts that the shape will be worth more than the sum of its corners. When the wave comes and the constellation fires, the feeling is not that your towers were well-placed. It is that you saw past the pieces to the pattern — and the pattern was right.
>
> But the pattern is never finished the way a placed tower is finished. A tower is a commitment that keeps itself; it does not move, it does not forget. A constellation is a commitment you have to *keep whole*. Break one corner and the entire shape goes dark in an instant, every bonus with it — so the arrangement is a standing claim the wave will spend itself trying to break. This is where the two halves of the fight meet: the towers hold the argument as long as their structure survives, and when an enemy slips the line and closes on the corner that holds everything together, the hero is the one who can go put themselves where the pattern cannot defend itself. Every cell of the shape you keep intact is a cell of your theory that survived contact.
>
> And when the last enemy falls and the constellation is still lit — whole, exactly as you assembled it — the feeling is not power, and it is not even that your towers held. It is that your *arrangement* held. You didn't just build machines that were right on their own. You saw how they were right *together*, you built that reading into the shape of the field, and the field proved you correct. That is the recognition the Constellation gives you that a single tower never can: not that a piece worked, but that the composition did.

## Detailed Design

### Core Rules

1. **Pattern Catalogue.** Four constellation patterns exist at Vertical Slice scope. Each is defined as a set of relative cell offsets from a canonical anchor cell (the lexicographically smallest `Vector2i` in the cell set — lowest row, then lowest column):

   | Pattern ID | Shape | Tower Count (N) | Orientations Allowed |
   |---|---|---|---|
   | `triad_line` | 3 cells in a straight run | 3 | 4 (0°, 45°, 90°, 135°) |
   | `quad_line` | 4 cells in a straight run | 4 | 4 (0°, 45°, 90°, 135°) |
   | `l_corner` | 3-in-a-line + 1 perpendicular cell at the end (L-tetromino) | 4 | 8 (4 rotations × 2 mirrors) |
   | `cross_plus` | 1 center cell + its 4 orthogonal (N/S/E/W) neighbors | 5 | 1 (rotationally symmetric — no distinct orientations) |

   All 4 axis directions (0°, 45°, 90°, 135°) are valid for line/corner shapes, consistent with Grid System's Chebyshev-distance convention (diagonal adjacency treated identically to orthogonal adjacency).

2. **Eligibility Matching (uniform tag).** A pattern instance is valid only if every cell in its shape is occupied by a tower whose Power component has a non-empty `constellation_eligibility_tag`, AND all N towers in that instance share the identical tag value. No pattern shape requires specific tags in specific positions — tag identity only needs to match uniformly across the whole instance.

3. **Detection Trigger.** A recheck is triggered synchronously, per-event, on `tower_placed`, `tower_removed`, and `tower_destroyed`. Rechecks are never batched, matching the non-batched recheck convention already established in tower.md's constellation edge case.

4. **Activation.** When a recheck newly satisfies all N required cells of a shape+anchor+tag combination, Constellation emits `constellation_activated(pattern_id, grid_origin, bonus_type, bonus_value)` exactly once for that instance. `pattern_id` is composed as `"{shape_id}@{anchor_cell}"` (e.g. `"quad_line@(3,5)"`), so overlapping instances of the same shape at different anchors are tracked and reported independently. `grid_origin` is the instance's canonical anchor cell.

5. **Deactivation.** When any tower belonging to a currently-`ACTIVE` instance is removed (`tower_removed`) or destroyed (`tower_destroyed`), Constellation immediately emits `constellation_deactivated(pattern_id, reason)`, where `reason` is `"tower_removed"` or `"tower_destroyed"`. If the removed/destroyed tower belongs to more than one active instance simultaneously, one `constellation_deactivated` fires per affected instance (see Edge Cases). No "repair" or grace window is attempted — a later placement event may independently re-trigger Rule 4 if a valid instance re-forms.

6. **Overlap and Stacking (inherited from game-concept.md Core Rule 9).** Multiple pattern instances may share member towers. Each instance activates and deactivates fully independently per Rules 4–5. Constellation does not compute additive stacking itself — it only emits one event per instance; Tower System sums all bonuses it has received via `constellation_activated`/`constellation_deactivated` per its own existing subscription model (tower.md: "Constellation does NOT modify Tower stats directly; it only emits the activation event and Tower applies it").

7. **Discovery (meta-progression).** Constellation maintains a persistent, save-backed discovery ledger keyed by `shape_id` only (not anchor — see States and Transitions). The first time any instance of a given `shape_id` transitions to `ACTIVE` in the current playthrough, Constellation fires `constellation_rune_discovered(rune_id, pattern_id)` in addition to `constellation_activated`. Re-forming the same shape at a different anchor, or re-forming it after it previously broke, never re-fires discovery.

8. **Detection Search Scope.** Every recheck is bounded to a localized neighborhood around the single changed cell — Constellation calls `Grid.get_occupied_cells_in_radius(grid_position, pattern_search_radius)`, never `Grid.get_all_occupied_cells()`. This is a hard rule, not an optimization suggestion: per-event detection cost must not scale with total tower count on the field (see Formula 2 and Edge Cases).

9. **Placement-Only Formation, Any-Phase Breaking.** New pattern instances can only ever form as a result of a `tower_placed` event (which tower.md restricts to SCOUT/INTERMISSION). Instances can break via `tower_removed` (SCOUT/INTERMISSION only, per tower.md) or `tower_destroyed` (any phase, including WAVE_ACTIVE). Constellation itself enforces no phase gating — it is a pure consequence of which events Tower emits when.

### States and Transitions

The Constellation System owns no mission-phase state of its own — it inherits SCOUT / WAVE_ACTIVE / INTERMISSION / OUTCOME entirely from `game-concept.md`'s phase model and never gates its own logic on phase directly (it reacts only to Tower's events, which are themselves already phase-gated: placement/removal events only fire during SCOUT/INTERMISSION per tower.md; destruction events can fire during WAVE_ACTIVE).

What Constellation *does* own is a per-instance lifecycle for each pattern instance (`pattern_id`), and a system-wide discovery ledger.

**Pattern Instance Lifecycle:**

| State | Entry Condition | Behavior | Exit Condition |
|-------|-----------------|----------|-----------------|
| `INACTIVE` (implicit — not tracked until formed) | Default state for any `shape_id`+anchor combination not currently satisfied | No event traffic; not present in Constellation's active-instance table | All N required cells become occupied by eligible, tag-matching towers (Core Rule 4 conditions met) → `ACTIVE` |
| `ACTIVE` | Core Rule 4 conditions met; `constellation_activated` emitted; instance added to active-instance table | Bonus is considered live at Tower System (Constellation itself applies no stat changes — it only emits the event once on entry; it does not re-emit on every frame) | Any member tower removed (`tower_removed`) or destroyed (`tower_destroyed`) → `INACTIVE`, `constellation_deactivated` emitted, instance removed from active-instance table |

**Discovery Ledger (playthrough-scoped, save-persisted):**

| State | Entry Condition | Behavior | Exit Condition |
|-------|-----------------|----------|-----------------|
| `UNDISCOVERED` | Default for every `shape_id` at playthrough start (or on a fresh save) | No special behavior | First `ACTIVE` transition of any instance of this `shape_id` → `DISCOVERED`, `constellation_rune_discovered` emitted |
| `DISCOVERED` | First-ever activation of this `shape_id` in the current playthrough | Persists for the remainder of the playthrough (survives save/load — see Dependencies) | Terminal — never reverts, even if all instances of the shape later break |

### Interactions with Other Systems

| System | Direction | Data Flow |
|---|---|---|
| **Tower System** | Bidirectional via EventBus | Constellation subscribes to `tower_placed`, `tower_removed`, `tower_destroyed` to trigger rechecks; Tower subscribes to `constellation_activated`/`constellation_deactivated` to apply/remove bonuses on its own components. Constellation never writes to Tower state directly. |
| **Grid System** | Constellation reads | Direct, read-only Autoload call: `get_occupied_cells_in_radius(center, radius)` for localized adjacency queries on every recheck. |
| **Mission HUD** | Downstream — HUD subscribes | `constellation_activated`/`constellation_deactivated` drive the pattern-active visual overlay (see Visual/Audio Requirements). |
| **Encyclopedia / Equipment Forge** | Downstream — both subscribe | `constellation_rune_discovered` unlocks encyclopedia entries and is a stated Equipment Forge dependency. |

## Formulas

### Formula 1 — `constellation_bonus_value`

```
constellation_bonus_value = min(bonus_cap, base_unit_bonus × (1 + size_growth_rate × (N - N_min)) + shape_complexity_bonus)
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `base_unit_bonus` | float | 0.05–0.15 | Base bonus fraction granted by the smallest catalogued pattern (`N_min`). Interpreted as a percentage stat bonus; concrete meaning depends on the instance's `bonus_type` (e.g. `"damage_pct"`), which Tower System applies. |
| `size_growth_rate` | float | 0.20–0.50 | Fractional bonus increase per additional tower beyond `N_min`. |
| `N` | int | 3–5 | Tower count required by the pattern shape (see Core Rule 1 table). |
| `N_min` | int | 3 (fixed) | Smallest catalogued pattern size — scaling baseline. |
| `shape_complexity_bonus` | float | 0.00–0.05 | Flat, hand-authored bonus per shape rewarding harder-to-form geometry at equal N (e.g. `l_corner`'s bend vs. `quad_line`'s straight run). |
| `bonus_cap` | float | 0.20–0.35 | Hard ceiling on any single instance's `bonus_value`, bounding additive overlap-stacking per Core Rule 6. |
| `constellation_bonus_value` (= `bonus_value` in the `constellation_activated` payload) | float | 0.10–`bonus_cap` | The value emitted in `constellation_activated`'s `bonus_value` field. |

**Output Range:** [0.10, 0.25] at proposed defaults. Clamped, never negative, never unbounded — deliberately bounded because Core Rule 6 allows unlimited additive stacking across overlapping instances; an unbounded per-instance value would let 2–3 overlapping patterns trivially break tower balance calibrated independently in tower.md.

**Worked Examples** (defaults: `base_unit_bonus=0.10`, `size_growth_rate=0.35`, `bonus_cap=0.25`; `shape_complexity_bonus`: `triad_line`=0.00, `quad_line`=0.00, `l_corner`=0.02, `cross_plus`=0.03):

| Pattern | N | Calculation | `bonus_value` |
|---|---|---|---|
| `triad_line` | 3 | 0.10 × (1 + 0.35×0) + 0.00 = 0.100 | **0.100** (+10%) |
| `quad_line` | 4 | 0.10 × (1 + 0.35×1) + 0.00 = 0.135 | **0.135** (+13.5%) |
| `l_corner` | 4 | 0.10 × (1 + 0.35×1) + 0.02 = 0.155 | **0.155** (+15.5%) |
| `cross_plus` | 5 | 0.10 × (1 + 0.35×2) + 0.03 = 0.200 | **0.200** (+20%) |

None reach `bonus_cap` (0.25) individually at these defaults. The cap only binds if a future pattern (post-VS, larger/rarer) is added, or if tuning knobs are pushed to their upper safe-range bounds (e.g. `base_unit_bonus=0.15` + `cross_plus`: 0.15×1.70+0.03=0.285 → clamped to 0.25).

### Formula 2 — `pattern_search_radius`

```
pattern_search_radius = max_offset_distance(all catalogued shapes)
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `max_offset_distance` | int | computed | The largest Chebyshev distance from any shape's canonical anchor to any of its own member cells, taken across the whole catalogue. |
| `pattern_search_radius` | int | 2–4 | Radius passed to `Grid.get_occupied_cells_in_radius(changed_cell, pattern_search_radius)` on every recheck (Core Rule 8). |

**Output Range:** With the current 4-shape catalogue, `quad_line`'s longest run spans offsets 0–3 from its anchor (max member-to-anchor Chebyshev distance = 3). **`pattern_search_radius = 3`** at current catalogue. This is a derived constant, not a hand-tuned value — it must be recomputed and the constant updated any time a larger pattern is added to the catalogue (see Tuning Knobs).

**Worked Example:** Catalogue = {`triad_line`(max offset 2), `quad_line`(max offset 3), `l_corner`(max offset 2), `cross_plus`(max offset 1)} → `pattern_search_radius = max(2,3,2,1) = 3`.

## Edge Cases

- **If the same tower cell simultaneously satisfies two different catalogued shapes** (e.g. it completes both a `triad_line` and an `l_corner`): both instances transition to `ACTIVE` independently, each with its own `pattern_id` and its own `constellation_activated` event. Bonuses stack additively at Tower System per Core Rule 6. No precedence or exclusivity is enforced between shapes.

- **If a tower belonging to two or more overlapping `ACTIVE` instances is destroyed**: Constellation fires `constellation_deactivated` once per affected `pattern_id` (not a single combined event), each with `reason: "tower_destroyed"`. This matches the non-batched, react-per-event convention already established in tower.md.

- **If N-1 of N required towers are placed, forming no valid instance, and one of the N-1 is then removed and re-placed elsewhere**: no partial-pattern state is retained. Because no instance was ever `ACTIVE`, the removal fires no `constellation_deactivated` (nothing to deactivate). The re-placement triggers a fresh, independent recheck from its new cell; it may or may not complete a different valid instance depending on what is now adjacent to it. No special-case logic exists for this scenario — it is a direct consequence of Core Rule 8's stateless, per-event, localized search.

- **If 40–60 towers are present on the field simultaneously and any single `tower_placed`/`tower_removed`/`tower_destroyed` event fires**: recheck cost is bounded to a `pattern_search_radius`-cell neighborhood around the single changed cell (Core Rule 8, Formula 2), not a full-board scan. Per-event cost scales with catalogue size (fixed at 4 shapes for Vertical Slice), not with total tower count on the field.

- **If an instance of an already-`DISCOVERED` shape (per the Discovery Ledger) is later broken and re-formed**, at the same or a different anchor: `constellation_activated` fires again (bonus reapplies), but `constellation_rune_discovered` does not fire again in the same playthrough. The Discovery Ledger is a one-way, per-`shape_id` terminal state (see States and Transitions).

- **If a shape could be detected as anchored from either of its two endpoints** (e.g. a 3-cell line read left-to-right vs. right-to-left): prevented structurally by the canonicalization rule in Core Rule 1 — the anchor is always the lexicographically smallest cell in the shape's cell set. Without this rule, one physical tower cluster could produce two distinct `pattern_id`s and double-fire the bonus; canonicalization guarantees exactly one `pattern_id` per physical cluster.

- **If a mission's grid is too small, too irregularly shaped, or too PATH/BLOCKED-dense to ever fit a catalogued shape** (e.g. `cross_plus` needs a full 3×3 PLACEABLE footprint): no runtime error or special handling occurs — that pattern simply never activates on that mission's board. This is flagged as a **Level Design / Mission Select consideration** (verify at least one PLACEABLE cluster large enough for at least one catalogued shape exists per mission), not a Constellation System defect.

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **Tower System** | Upstream — Constellation subscribes | Constellation subscribes to `tower_placed`, `tower_removed`, `tower_destroyed` to trigger rechecks (Core Rules 3, 8, 9); Tower subscribes to `constellation_activated`/`constellation_deactivated` to apply/remove bonuses on its own components — Constellation never writes to Tower state directly | EventBus signals only (`tower_placed(tower_id, archetype, footprint, placed_in_scout, grid_position)`, `tower_removed(tower_id, grid_position, archetype)`, `tower_destroyed(tower_id, grid_position, archetype, footprint)`); reads `constellation_eligibility_tag` from the placed tower's Power component via the payload/tower lookup, not a direct Constellation→Tower call |
| **Grid System** | Downstream — Constellation calls | Direct, read-only Autoload API call (not EventBus) for localized adjacency queries during every recheck (Core Rule 8, Formula 2) | `get_occupied_cells_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]`. Grid returns Array copies, safe to iterate without a defensive copy on Constellation's side. Constellation does not call `get_all_occupied_cells()` in the hot recheck path. |
| **EventBus System** | Bidirectional — pure pub/sub, no direct reference | Constellation emits `constellation_activated`, `constellation_deactivated`, `constellation_rune_discovered`; subscribes to Tower's 3 placement/removal/destruction events | Event contract frozen in `design/gdd/event-bus.md` — Constellation must not propose different event names or payloads, only design around the existing 3-event contract |
| **Mission HUD** | Downstream dependent | HUD subscribes to `constellation_activated`/`constellation_deactivated` for the pattern-active visual overlay — overlay ownership sits with Mission HUD/Tower System UI, not Constellation itself | No direct state read from Constellation; event payloads only. Any "pattern active" visual cue shares the Godot 4.6 glow/bloom risk already flagged in tower.md's Engine Risk Notes — not a Constellation System design concern, but relevant to whoever designs the overlay. |
| **Audio System** | Downstream dependent | Subscribes to `constellation_activated` for an activation stinger/cue | Event payload only |
| **Encyclopedia System** | Downstream dependent | Subscribes to `constellation_rune_discovered` to unlock encyclopedia entries | Event payload only (`rune_id`, `pattern_id`) |
| **Equipment Forge System** | Downstream dependent | Subscribes to `constellation_rune_discovered` — discovered runes are a stated dependency of Equipment Forge (per systems-index.md) | Event payload only |
| **Save & Persistence System** | Downstream dependent — Constellation calls | Constellation's Discovery Ledger (Core Rule 7, States and Transitions) must be persisted and restored across save/load — a genuine dependency not yet reflected in Save & Persistence's own save schema | Constellation must register its discovered-`shape_id` set with Save & Persistence's save/restore cycle; exact serialization key TBD |

## Tuning Knobs

| Knob | Default | Safe Range | Too Low | Too High |
|------|---------|------------|---------|----------|
| `base_unit_bonus` | 0.10 | 0.05–0.15 | Below 0.05: bonus is imperceptible; forming a pattern feels like busywork for no felt reward. | Above 0.15: a single 3-tower pattern rivals hand-tuned archetype stat differences from tower.md, undermining base tower balance. |
| `size_growth_rate` | 0.35 | 0.20–0.50 | Below 0.20: larger/harder patterns barely reward the extra placement difficulty over `triad_line`. | Above 0.50: `cross_plus` alone approaches `bonus_cap`, leaving little differentiation room for `shape_complexity_bonus`. |
| `shape_complexity_bonus` (per shape) | `triad_line`=0.00, `quad_line`=0.00, `l_corner`=0.02, `cross_plus`=0.03 | 0.00–0.05 | At 0.00 for all shapes: equal-N patterns (`quad_line` vs `l_corner`) feel interchangeable — no reward for harder geometry. | Above 0.05: a single shape can dominate the meta, making other same-N patterns strictly inferior and pruning build diversity. |
| `bonus_cap` | 0.25 | 0.20–0.35 | Below 0.20: even the largest single pattern is throttled below its natural Formula 1 output, wasting the size-scaling design intent. | Above 0.35: two overlapping instances can compound additively toward +50–70%, breaking tower balance calibrated without constellation bonuses in mind. |
| `pattern_search_radius` | 3 (derived — Formula 2) | Recompute on any catalogue change; not independently hand-tuned | N/A — this is derived, not a balance lever. | If left stale after adding a larger pattern: the new shape silently fails to detect at its true edges (cells outside the stale radius are never queried) — a correctness bug, not a balance issue. |
| Catalogue size | 4 patterns | 3–5 (Vertical Slice) | Below 3: insufficient build variety to justify the system's UI/VFX authoring cost. | Above 5 pre-Vertical-Slice: Formula 2's O(patterns × orientations × N) detection cost grows, and each added "pattern active" visual cue compounds the glow/bloom VFX risk already flagged in tower.md's Engine Risk Notes. |

## Visual/Audio Requirements

All constellation visuals are diegetic (rendered as physical, in-world objects on the grid) rather than screen-space UI, consistent with the diorama visual anchor (`design/art/art-bible.md` Section 1) and the Tower GDD's designation of this overlay as owned by the Constellation System. No treatment below depends on `Viewport.use_hdr_2d` / bloom glow, per the documented Godot 4.6 HDR-2D constraint (`docs/engine-reference/godot/VERSION.md`) — glow may be layered in later as an optional secondary accent only, never as the primary indicator.

**Active pattern (primary, persistent while active)**
A carved rune-plate is inlaid across the grid cells spanning the pattern's footprint. The plate's shape is pattern-specific (e.g., a triangle rune for a 3-tower triangular pattern, a line rune for a linear pattern) — the etched grooves connecting each contributing tower's base double as the "connecting lines," so one asset serves both the literal constellation read and the hand-carved miniature aesthetic. The plate is lit from within via sprite/particle inlay (warm Sanctum Amber tone), not a glow/bloom shader. Shape recognition is itself informational: players learn to identify pattern type by rune silhouette at a glance.

**Activation (one-shot, on `constellation_activated`)**
The rune ignites node-by-node from each contributing tower inward, converging in a brief pulse at the plate's center (fast, ~0.5-1s, satisfying but not prolonged — a Mastery-as-Vindication payoff beat, not a spectacle). Paired with a small non-blocking corner confirmation naming the pattern and its bonus type/value, so the player always knows *what* they earned, not just that something happened.

**Deactivation (one-shot, on `constellation_deactivated`)**
The rune plate visibly cracks and greys out, fading over a shorter duration than activation. Rendered in Fieldstone Grey rather than the activation's warm tone — deliberately quicker and duller so it never competes visually with the positive activation beat. Paired with the same corner-confirmation slot, showing the deactivation `reason` (tower destroyed vs. tower removed/moved) for diagnostic clarity.

**Rune discovery (`constellation_rune_discovered`, first-time-ever only)**
A dedicated carved-medallion reveal card flips into view — consistent with the diorama object language rather than a flat modal — non-blocking, held ~2-3s (dismissible early), showing the rune's name/icon and a one-line hook toward its Encyclopedia entry and Equipment Forge unlock. This is a permanent meta-progression milestone and must read as heavier than a routine activation, without fully blocking play.

**Audio (SFX category direction only — no audio bible exists yet; final sound design deferred)**
- *Activation*: short bright ascending chime, bell/glass timbre, warm register, quick (~0.5-1s) — confirmation, not a fanfare.
- *Deactivation*: single low dull thud/crack, no ring-out — deliberately anticlimactic and clearly distinct from activation.
- *Discovery*: fuller fanfare, longer tail, layered chime plus low resonance — audibly bigger than routine activation to signal milestone weight.

## UI Requirements

The Constellation System has no UI of its own — the pattern-active overlay is owned by Mission HUD/Tower System UI (see Visual/Audio Requirements and Interactions with Other Systems), driven entirely by the `constellation_activated`/`constellation_deactivated`/`constellation_rune_discovered` event payloads. No standalone Constellation screen, panel, or menu exists at Vertical Slice scope.

## Acceptance Criteria

> **Test type key** (per QA story-type gate): **Logic** = automated unit test, BLOCKING · **Integration** = integration test or documented playtest, BLOCKING · **Config/Data** = smoke check, ADVISORY. All ACs below are Logic or Integration unless noted otherwise.
>
> **Fixture convention**: All ACs assume a GUT test double for `Grid` exposing `get_occupied_cells_in_radius()` per `grid-system.md`'s signature, and direct `EventBus.emit_signal()` calls standing in for real Tower System events (no live Tower System instance required — Constellation's own logic is under test, not Tower's). Where an AC requires reading `constellation_eligibility_tag` off a placed tower, it assumes an as-yet-undocumented lookup interface — see **Open Question OQ-4** before assigning these ACs to implementation.

### Core Rule 1 — Pattern Catalogue

**AC-1 — `triad_line` recognized at 0° (horizontal) orientation**
> **Given** eligible towers with identical tag `"solar"` occupy cells `(2,4)`, `(3,4)`, `(4,4)` and no other pattern-catalogue shape is coincidentally satisfied, **when** the third tower's `tower_placed` event fires, **then** `constellation_activated("triad_line@(2,4)", (2,4), bonus_type, 0.100)` emits exactly once.

**AC-2 — `triad_line` recognized at 45° (diagonal) orientation**
> **Given** eligible towers with identical tag `"solar"` occupy cells `(2,4)`, `(3,5)`, `(4,6)`, **when** the third tower's `tower_placed` event fires, **then** `constellation_activated` emits with `pattern_id` = `"triad_line@(2,4)"`.

**AC-3 — `l_corner` recognized in a mirrored orientation (not just a base rotation)**
> **Given** eligible towers with identical tag `"solar"` occupy cells `(5,5)`, `(5,6)`, `(5,7)`, `(4,5)` (a mirrored L relative to the catalogue's canonical L), **when** the fourth tower's `tower_placed` event fires, **then** `constellation_activated` emits with `pattern_id` = `"l_corner@(4,5)"`. This confirms all 8 `l_corner` orientations (4 rotations × 2 mirrors) are matched, not only the 4 base rotations.

**AC-4 — `cross_plus` matches only its single valid orientation; a near-miss shape does not activate it**
> **Given** eligible towers with identical tag `"solar"` occupy the center cell `(6,6)` and its N/E/S neighbors `(6,5)`, `(7,6)`, `(6,7)` but the W neighbor `(5,6)` is empty, **when** any `tower_placed` event fires for the 4 placed towers, **then** no `constellation_activated` for `cross_plus` occurs. **When** a 5th eligible same-tag tower is subsequently placed at `(5,6)`, **then** `constellation_activated("cross_plus@(5,6)", ...)` emits exactly once.

### Core Rule 2 — Eligibility Matching (uniform tag)

**AC-5 — Mismatched tags prevent activation despite complete shape geometry**
> **Given** cells `(2,4)`, `(3,4)`, `(4,4)` are occupied by towers with `constellation_eligibility_tag` = `"solar"`, `"solar"`, `"lunar"` respectively (a complete `triad_line` footprint, tags not uniform), **when** the third tower's `tower_placed` event fires, **then** no `constellation_activated` event for that cell set is emitted.

**AC-6 — Empty eligibility tag excludes a tower from any pattern**
> **Given** cells `(2,4)`, `(3,4)` are occupied by towers tagged `"solar"` and cell `(4,4)` is occupied by a tower with `constellation_eligibility_tag = ""`, **when** the third tower's `tower_placed` event fires, **then** no `constellation_activated` event is emitted for the `triad_line` footprint at `(2,4)`.

### Core Rule 3 — Detection Trigger (synchronous, per-event, non-batched)

**AC-7 — Recheck resolves synchronously within the same dispatch, not deferred to next frame**
> **Given** cells `(2,4)`, `(3,4)` are already occupied by identically-tagged eligible towers and no `_physics_process` tick or `await` occurs between event and assertion, **when** the test emits `tower_placed` for a third eligible same-tag tower at `(4,4)` directly (no frame advance), **then** `constellation_activated` has already fired by the time `emit_signal()` returns control to the caller. Per `event-bus.md` Core Rule 3, `tower_placed`/`tower_removed`/`tower_destroyed` carry no "deferred" annotation (unlike e.g. `monster_damage_taken`), so this is the correct default expectation.

**AC-8 — Two independent placement events each trigger their own recheck (no batching across events)**
> **Given** an empty board, **when** two `tower_placed` events are emitted back-to-back in the same test — first completing no pattern, second completing `triad_line` — **then** exactly one `constellation_activated` emits (after the second event), and no accumulation/coalescing of the two events into a single deferred recheck occurs.

### Core Rule 4 — Activation

**AC-9 — Activation event fires exactly once with correctly-composed `pattern_id`**
> **Given** cells `(3,5)`, `(4,5)`, `(5,5)`, `(6,5)` are occupied by identically-tagged eligible towers forming a `quad_line`, **when** the 4th tower's `tower_placed` event fires, **then** `constellation_activated("quad_line@(3,5)", (3,5), bonus_type, 0.135)` emits exactly once (not once per cell, not zero times), and a duplicate recheck triggered by an unrelated later placement does not re-fire it while the instance remains `ACTIVE`.

### Core Rule 5 — Deactivation

**AC-10 — `tower_removed` on an active instance's member fires deactivation with correct reason**
> **Given** an `ACTIVE` `triad_line@(2,4)` instance (per AC-1's setup), **when** `tower_removed` fires for the tower at `(3,4)`, **then** `constellation_deactivated("triad_line@(2,4)", "tower_removed")` emits exactly once.

**AC-11 — `tower_destroyed` on an active instance's member fires deactivation with correct reason**
> **Given** an `ACTIVE` `triad_line@(2,4)` instance, **when** `tower_destroyed` fires for the tower at `(4,4)` (simulating a WAVE_ACTIVE mid-wave kill), **then** `constellation_deactivated("triad_line@(2,4)", "tower_destroyed")` emits exactly once.

### Core Rule 6 — Overlap and Stacking

**AC-12 — Two overlapping instances activate independently from a single placement event**
> **Given** a single `tower_placed` event simultaneously completes both a `triad_line` and an `l_corner` sharing one or more member towers, **when** the completing event resolves, **then** both `constellation_activated` events emit — two separate events in the same dispatch, not one combined event — and Constellation performs no summation between them (summation is Tower System's responsibility per Rule 6).

**AC-13 — Destroying a tower shared by two active instances fires one deactivation per instance**
> **Given** `triad_line@A` and `l_corner@B` are both `ACTIVE` and share one common member tower, **when** `tower_destroyed` fires for that shared tower, **then** exactly two `constellation_deactivated` events emit in the same dispatch — one per `pattern_id`, both `reason = "tower_destroyed"` — not a single combined or batched event.

### Core Rule 7 — Discovery (never re-fires)

**AC-14 — First-ever activation of a shape_id fires both `constellation_activated` and `constellation_rune_discovered`**
> **Given** a fresh playthrough state (Discovery Ledger has no entry for `triad_line`), **when** a `triad_line` instance first transitions to `ACTIVE` at anchor `(2,4)`, **then** both `constellation_activated("triad_line@(2,4)", ...)` and `constellation_rune_discovered(rune_id, "triad_line@(2,4)")` emit.

**AC-15 — Re-forming the same shape at a different anchor does not re-fire discovery**
> **Given** the Discovery Ledger already has `triad_line` = `DISCOVERED` (from a prior activation at a different anchor, now broken), **when** a new, distinct `triad_line` instance activates at anchor `(9,9)`, **then** `constellation_activated("triad_line@(9,9)", ...)` emits but `constellation_rune_discovered` does not emit.

**AC-16 — Breaking and reforming the identical instance does not re-fire discovery**
> **Given** the Discovery Ledger already has `triad_line` = `DISCOVERED`, and a `triad_line@(2,4)` instance is currently `INACTIVE` after having broken, **when** the same 3 cells are re-occupied by identically-tagged eligible towers and the instance re-activates at the same anchor `(2,4)`, **then** `constellation_activated("triad_line@(2,4)", ...)` emits again (bonus reapplies) but `constellation_rune_discovered` does not emit.

### Core Rule 8 — Detection Search Scope (localized radius, not full-board)

**AC-17 — Recheck queries only `get_occupied_cells_in_radius`, never `get_all_occupied_cells`, on the hot path**
> **Given** a Grid test double that records every call made to it and asserts a test failure if `get_all_occupied_cells()` is invoked during a recheck, **when** any of `tower_placed`/`tower_removed`/`tower_destroyed` fires, **then** the recheck completes using only `get_occupied_cells_in_radius(changed_cell, 3)` calls, and the test double's `get_all_occupied_cells()` call counter remains 0 throughout.

### Core Rule 9 — Placement-Only Formation, Any-Phase Breaking

**AC-18 — Removal alone can never simultaneously complete a shape**
> **Given** cells `(2,4)`, `(3,4)` are occupied by identically-tagged eligible towers and a third, differently-tagged tower currently occupies `(4,4)` (blocking `triad_line`), **when** the blocking tower at `(4,4)` is removed via `tower_removed`, **then** no `constellation_activated` fires from that removal event — vacating a cell can only break an instance, never complete one, since Rule 9 restricts formation to `tower_placed` only.

**AC-19 — `tower_destroyed` breaks an active instance during WAVE_ACTIVE**
> **Given** an `ACTIVE` `quad_line@(3,5)` instance formed during a prior SCOUT phase, and the current mission phase is `WAVE_ACTIVE`, **when** `tower_destroyed` fires for a member tower, **then** `constellation_deactivated("quad_line@(3,5)", "tower_destroyed")` emits regardless of the current phase — Constellation applies no phase gate of its own.

### Formula 1 — `constellation_bonus_value`

**AC-20 — `triad_line` (N=3) produces bonus_value 0.100 at default tuning**
> **Given** default tuning (`base_unit_bonus=0.10`, `size_growth_rate=0.35`, `shape_complexity_bonus[triad_line]=0.00`, `bonus_cap=0.25`), **when** a `triad_line` instance activates, **then** `constellation_activated`'s `bonus_value` field equals `0.100` (±0.001 float tolerance).

**AC-21 — `quad_line` (N=4) produces bonus_value 0.135 at default tuning**
> **Given** the same default tuning, **when** a `quad_line` instance activates, **then** `bonus_value` equals `0.135` (±0.001).

**AC-22 — `l_corner` (N=4, shape_complexity_bonus=0.02) produces bonus_value 0.155 at default tuning**
> **Given** the same default tuning, **when** an `l_corner` instance activates, **then** `bonus_value` equals `0.155` (±0.001).

**AC-23 — `cross_plus` (N=5, shape_complexity_bonus=0.03) produces bonus_value 0.200 at default tuning**
> **Given** the same default tuning, **when** a `cross_plus` instance activates, **then** `bonus_value` equals `0.200` (±0.001).

**AC-24 — `bonus_cap` clamps an out-of-range tuning combination**
> **Given** tuning overridden to `base_unit_bonus=0.15`, `size_growth_rate=0.35` (unchanged), `shape_complexity_bonus[cross_plus]=0.03`, `bonus_cap=0.25` (raw computation `0.15×1.70+0.03=0.285`), **when** a `cross_plus` instance activates under this tuning, **then** `bonus_value` equals `0.250` exactly (clamped to `bonus_cap`), not `0.285`.

### Formula 2 — `pattern_search_radius`

**AC-25 — Derived radius equals 3 for the current 4-shape catalogue, and cells at exactly that distance are included** *(Config/Data — ADVISORY)*
> **Given** the catalogue's `quad_line` shape has a max member-to-anchor Chebyshev offset of 3 (the catalogue's largest), **when** `pattern_search_radius` is read from wherever it is registered (see Open Question OQ-6), **then** its value is `3`. **And when** `Grid.get_occupied_cells_in_radius(changed_cell, 3)` is called with an eligible tower at exactly Chebyshev distance 3 from `changed_cell`, **then** that cell is included in the returned set (boundary-inclusive, consistent with `grid-system.md`'s `≤ radius` semantics).

### Edge Cases

**AC-26 — Simultaneous multi-shape satisfaction: no precedence, both bonuses independently correct**
> **Given** a single `tower_placed` event simultaneously completes both a `triad_line` and an `l_corner` sharing member towers, **when** the event resolves, **then** both `constellation_activated` events carry their own independently-correct `bonus_value` per Formula 1 (`0.100` and `0.155` respectively) — Constellation does not suppress, average, or pick one shape over the other.

**AC-27 — N-1-then-remove-and-replace-elsewhere fires no deactivation (nothing was ever active)**
> **Given** cells `(2,4)`, `(3,4)` are occupied by identically-tagged eligible towers (2 of 3 needed for `triad_line`; no instance has ever reached `ACTIVE`), **when** the tower at `(3,4)` is removed via `tower_removed` and then a same-tag eligible tower is placed at an unrelated cell `(10,10)` via `tower_placed`, **then** no `constellation_deactivated` event emits at any point in this sequence, and the `tower_placed` event at `(10,10)` triggers only its own independent, localized recheck.

**AC-28 — Canonicalization prevents duplicate `pattern_id` for one physical cluster regardless of read order**
> **Given** a 3-cell line at `(4,4)`, `(4,5)`, `(4,6)` where the line could structurally be read anchored from either endpoint, **when** the completing tower is placed at `(4,4)` (the lexicographically-smaller endpoint) in one test run, and separately, a symmetric fixture completes the same physical line by placing at `(4,6)` (the other endpoint) in a second test run, **then** both runs produce the identical canonical `pattern_id = "triad_line@(4,4)"`, never `"triad_line@(4,6)"`, and never two separate `constellation_activated` events for the same physical cluster.

**AC-29 — Grid-too-small-for-shape produces no error, only an absence of activation** *(Integration/robustness — ADVISORY)*
> **Given** a test grid where fewer than 3 PLACEABLE cells exist within Chebyshev distance 3 of any occupied cell, **when** `tower_placed` fires for a tower placed under these constraints, **then** the recheck completes without throwing an exception or logging an error, and no `constellation_activated` fires.

### Performance Bound (Core Rule 8 / Formula 2 — Integration, ADVISORY pending perf harness)

**AC-30 — Per-event recheck cost does not scale with total tower count**
> **Given** two otherwise-identical test scenes — one with 10 towers on the field, one with 55 towers on the field, both outside the `pattern_search_radius` of the cell under test — **when** a single `tower_placed` event fires in each scene and recheck execution time is measured, **then** the two measured times are within an agreed tolerance band of each other (e.g. ±20%), demonstrating cost is a function of catalogue size (fixed at 4 shapes) and local neighborhood occupancy, not total board population. See Open Question OQ-7 for the still-undefined measurement methodology.

## Open Questions

**OQ-1: RESOLVED** (found stale 2026-08-27 — the fix landed 2026-07-17 but this entry was never marked resolved) — `save-persistence.md` assigned Constellation `restore_order = 24` (Feature layer; independent of Tower's own restore — reads no live Tower state at restore time, only its own Discovery Ledger) on 2026-07-17, closing this GDD's own requirement to persist the discovered-`shape_id` set (Core Rule 7) across save/load.

**OQ-2: `bonus_type` taxonomy.**
> Formula 1 produces a `bonus_value` (a float percentage), but the specific `bonus_type` strings a pattern instance can grant (e.g. `"damage_pct"`, `"attack_speed_pct"`) are not enumerated in this GDD — that taxonomy is assumed to be authored and owned by Tower System (which already applies the bonus to its own stats). Owner: Tower System GDD, or a shared registry entry. Target resolution: before content authoring (per-pattern `bonus_type` assignment) begins.

**OQ-3: Per-pattern `bonus_type` assignment.**
> Related to OQ-2 — this GDD does not specify which `bonus_type` each of the 4 catalogued patterns grants (only the numeric `bonus_value`). This is a content-authoring decision, not a systems-design gap, but must be resolved before implementation stories can be written. Owner: Game Designer / content pass.

**OQ-4 (was BLOCKING — surfaced by qa-lead during Acceptance Criteria authoring): No documented interface for reading `constellation_eligibility_tag` off a placed tower. RESOLVED 2026-07-18 (Sprint 6, S6-08) — this entry was never marked resolved despite the fix landing over a month before this pass found it stale.**
> Core Rule 2 (Eligibility Matching) is the load-bearing rule behind every activation/deactivation AC, and it originally had no documented interface: `tower_placed`/`tower_removed`/`tower_destroyed` payloads (per `event-bus.md`) carried only `tower_id`, `grid_position`, `archetype`, `footprint`, `placed_in_scout` — no tag field — and no Tower System query API was documented in `tower.md`. **Resolved by adding `constellation_eligibility_tag: String` directly to all three lifecycle event payloads** (`src/foundation/event_bus/event_bus.gd`, confirmed shipped) rather than a separate query API — the tag rides along with the event a Constellation subscriber already receives, needing no second lookup call. Every AC that assumed this lookup (AC-1 through AC-6, AC-9, AC-12, etc.) can read the tag straight off the event payload it's already handling.

**OQ-5: Batched-vs-per-event detection is behaviorally underspecified for automated testing.**
> AC-8 tests "per-event, not batched" by observing two activations from two events, but a batched-at-end-of-frame implementation could still pass it if both events resolve within the same test's synchronous block. Recommend adding an explicit ordering assertion (signal fires before the second event's `emit_signal()` call returns) when this GDD reaches implementation. Owner: implementing engineer / test author.

**OQ-6: `pattern_search_radius` has no specified registration location.**
> Formula 2 states the constant "must be recomputed and updated any time a larger pattern is added" but does not say where it lives (a GDScript `const`? an `entities.yaml` entry?). Recommend registering it explicitly in `design/registry/entities.yaml` alongside other cross-system tuning constants so it has an unambiguous, single source of truth. Owner: this GDD's registry-update pass (Phase 5b of `/design-system`).

**OQ-7: Performance bound (AC-30) has no defined measurement methodology. RESOLVED 2026-08-24 (Technical Director decision).**
> **Methodology**: `Time.get_ticks_usec()` brackets the exact recheck call (the same call AC-30 itself times), never a wrapping frame or the event-dispatch machinery around it — this isolates the recheck algorithm's own cost from EventBus/signal overhead, which is a separate, already-budgeted concern (`event-bus.md`'s own per-frame EventBus cost ceiling). One **sample** = one recheck invocation's elapsed microseconds, not a frame count — the recheck is a synchronous method call triggered once per `tower_placed` event, not a multi-frame process, so "frame count" doesn't apply here the way it would to an animation or physics-timing claim.
>
> **Sample size and warm-up**: 30 invocations per scene (10-tower, 55-tower), discarding the first 5 as JIT/cache warm-up before either scene's measurement window begins — standard microbenchmark practice for a call this cheap (sub-millisecond, per Formula 2's own cost model), where the first few invocations after a cold scene load are not representative of steady-state cost. The remaining 25 samples per scene are averaged.
>
> **Tolerance band**: AC-30's stated ±20% is confirmed as the pass/fail gate, evaluated as: `mean(55_tower_samples)` must fall within `mean(10_tower_samples) × [0.8, 1.2]`. This directly tests the claim's own wording ("cost is a function of catalogue size and local neighborhood occupancy, not total board population") — if cost scaled with total tower count, 55 towers would measurably exceed this band; if it doesn't, both means should be close regardless of the 5.5x population difference.
>
> **Execution environment**: run via a dedicated headless Godot MCP `run_script` invocation against a real loaded scene (not the interactive editor, whose own profiler/inspector overhead would skew microsecond-scale timings) — matching this project's own established live-verification practice for exactly this class of numeric claim (see `docs/engine-reference/godot/VERSION.md`'s many "live-verified via Godot MCP" entries). This is a measurement protocol only; running it to actually gate a build is deferred to whichever story/QA pass first needs AC-30 as a real hard gate rather than an informal smoke check — this OQ closes the "how would we measure it" gap, not the act of measuring itself.
