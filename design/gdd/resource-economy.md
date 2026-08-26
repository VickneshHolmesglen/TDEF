# Resource Economy System

> **Status**: Needs Revision (Reviewed 2026-07-14 — first pass, NEEDS REVISION → 3 blockers fixed same-session: Formula 4's combined-ERI check rebuilt after being found mathematically unsatisfiable, gold-balance-ownership Open Question resolved via ADR-0018 cross-reference, a double-award regression AC added. Gold faucet added same day (Rule 10, Formula 5). **Re-review #2 — 2026-07-15**: `/design-review` full pass [4 specialists + creative-director], triggered by `/review-all-gdds` finding Formula 5/AC-18/AC-19 silently calibrated against Wave Manager's `r=0.25` safe-range ceiling instead of its actual `r=0.20` default (real default-case 6-wave total is 349, not the claimed 375). Fixed same-session: Formula 5 and its downstream examples (Formula 2, Formula 3, the 8-wave overshoot figure) now show both r=0.20 and r=0.25 cases explicitly; AC-18/AC-19 split into r=0.20 (AC-18a/AC-19a) and r=0.25 (AC-18b/AC-19b) pairs; AC-19b's budget-range citation updated to the live registry range (350–550); both stale "NEW (2026-07-14)" Open Questions (Tower placement-cost debit, 8-wave budget re-scoping) struck as resolved in `tower.md`. **Design decision made**: `base_wave_gold` is not being raised to close the 1-gold r=0.20 shortfall against the 350 floor — the 350–400 target is itself provisional pending real tower content, so tuning gameplay balance to defend a placeholder number was judged premature; a `20→21` change is recorded as a deferred candidate for the future real-content calibration pass, not applied now.) **`/design-review --depth lean` re-review 2026-07-17**: r=0.20/0.25 fix confirmed intact, no arithmetic regressions. Documentation-currency-only findings: `menagerie_lure` Open Question not struck even though `menagerie.md` explicitly closes it; Menagerie/Crafting/Equipment Forge/Defense Building all still tagged "(undesigned)" despite being authored. Nothing blocks implementation. → **Approved** (`/design-review --depth lean` re-review 2026-08-27 — all 3 documentation-currency findings fixed: `menagerie_lure` OQ struck, 4 stale "(undesigned)" tags removed across 2 Dependencies tables, Rule 6's own stale "not yet designed" note also corrected. No blocking items found.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-15
> **Implements Pillar**: Everything Connects · The Sanctuary Is Your Statement

## Overview

The Resource Economy System is the accounting layer that converts monster kills and mission
performance into the two spendable currencies of the game: **materials** (earned in-mission,
spent at Crafting/Menagerie/Defense Building/Equipment Forge back in the Sanctuary) and **gold**
(a separate, always-available resource track used for the in-mission tower-placement budget and
other flexible spending). It does not store anything itself — Inventory is the ledger of record
for materials, and gold is tracked as a scalar balance. Resource Economy's job is purely
computational: given a monster's drop table, the current wave's `wave_reward_scalar`, and any
Menagerie quality bonus in effect, calculate exactly how much of what drops, and emit
`materials_earned`/`materials_spent`/`resources_changed` so the systems that actually hold the
resources (Inventory, and `MissionEconomy` for the gold balance) can react. Gold income during a
mission comes from exactly two sources — a flat Scout Phase starting grant and a per-wave completion
grant that scales with the same wave-reward curve (Rule 8, Rule 10) — this is the entire in-mission
gold faucet. Players never open
a "Resource Economy screen" — they feel this system every time a kill produces loot, every time a
tower placement is affordable or isn't, and every time a Crafting recipe lights up as available.

## Player Fantasy

**Fuel, Not Trophy.** Materials have no intrinsic worth in Sanctuary Defenders — their value is
entirely in the doors they open. The core emotional beat of this system is the *unlock cascade*:
one kill drops a material tier, and greyed-out recipes across Crafting, Equipment Forge, and
Defense Building suddenly light up as available all at once. The player should never feel like
they're farming a number. They should feel like they're farming *access* — this is the mechanical
expression of Everything Connects: a resource is only interesting because of what it feeds.

**The Yield You Predicted** is the secondary register, layered on top. Because drop quantity and
quality scale with `wave_reward_scalar` (compounding wave-over-wave) and with Menagerie investment,
a strong end-of-wave haul is never luck — it's confirmation that earlier decisions (which monsters
to prioritize, how much to invest in the Menagerie) are paying out exactly as planned. This is
Mastery-as-Vindication in miniature: the tally at wave-end either matches what a prepared player
expected, or exceeds it because they set something up correctly missions ago. **What this fantasy actually depends on (clarified during `/design-review` re-review #2, 2026-07-15) is predictability, not any particular target band** — a player is vindicated by *predicted matching actual*, whether the total lands at 349 gold or 375. This distinction matters because Formula 5's own worked examples were found to have silently assumed the top of Wave Manager's `difficulty_growth_rate` safe range rather than its documented default, producing a total that undershoots the (separately provisional) `mission_resource_budget` target by a small margin at true default settings — the fantasy survives that correction intact precisely because it was never about hitting a band, only about the tally matching what was foreseeable.

Together: the player should feel like every material that lands is doing one of two things —
unlocking something new to build, or proving a prior bet was right. Neither framing treats loot as
a trophy or a grind meter.

## Detailed Design

### Core Rules

1. **Statelessness.** Resource Economy owns no persistent data of its own — no save data, no runtime
   state beyond static tuning constants and data-driven drop tables. It is a pure calculation
   service that reacts to EventBus signals and emits results. Inventory is the ledger of record for
   materials; gold balance ownership is a separate, currently-unassigned concern (see Open Questions).

2. **Drop resolution on `monster_died`.** For each kill (excluding despawns — see Rule 5), Resource
   Economy looks up the monster's `drop_table_id` via `GameDataRegistry`, then for each matching
   `DropEntry`:
   - **Quantity** = `round(base_quantity × wave_reward_scalar × menagerie_quality_bonus)`, floored at
     `guaranteed_min_quantity` (never a zero-yield kill for a table that has at least one entry).
   - **Quality tier** = an independent probability roll:
     `roll_probability = clamp(base_quality_probability × wave_reward_scalar, 0.0, quality_probability_ceiling)`.
     Because this is a probability (not a raw multiplier), it cannot compound past 100% regardless of
     how large `wave_reward_scalar` grows — this satisfies Wave Manager's "both dimensions scale"
     contract while keeping the quality axis bounded independently of quantity.
   - Both terms use the *same* `wave_reward_scalar` input (per Wave Manager's frozen semantic
     contract), but resolve through structurally different math — one an unbounded-but-stack-capped
     quantity, one a hard-capped probability — so the two axes cannot multiply together into the raw
     22.73× the registry ceiling would suggest if read as a literal multiplier.
     `WAVE_ERI_CEILING_COMBINED` (22.73) is retained as a **validation check**, not a target: at max
     settings, `(quantity multiplier) × (quality probability ceiling / base quality probability)` must
     not exceed it.

3. **Menagerie quality bonus** (`menagerie_quality_bonus`, 1.0–1.5) is read at kill-resolution time
   from the current Menagerie state (via `creature_happiness_changed`/`creature_moved_to_breeding_pen`/
   `creature_returned_from_breeding_pen` — Resource Economy caches the latest aggregate value, does not
   recompute it). Applies only to the quantity term, not the quality-probability term (bonus
   represents *more* materials from a well-tended Menagerie, not better luck).

4. **Drop tables are data**, following the ADR-0009 Resource-subclass + `GameDataRegistry` convention
   already used by Inventory and Monster:
   ```
   DropTableResource: drop_table_id: StringName, entries: Array[DropEntry], guaranteed_min_quantity: int
   DropEntry: material_id: StringName, base_quantity: int, base_quality_probability: float, is_rare: bool
   ```
   `monster_died.drop_table_id` resolves through `GameDataRegistry.get_drop_table(id)`; a missing table
   is a load-time validation error (same pattern as a missing `MonsterResource`), never a silent no-op
   at runtime.

5. **No drops on despawn.** BOSS breach and force-cleared monsters (`kill_source == "wave_end"`) are
   **despawns, not kills** — no `monster_died` fires for either case (confirmed against Monster
   System's own despawn handling), so "no drop" is the structural default, not a special-cased ruling.
   This closes Wave Manager's OQ-6 explicitly: the behavior falls out of the event contract rather
   than requiring a bespoke check in Resource Economy.

6. **Menagerie attraction material** (`menagerie_lure`): rolled independently from
   `monster_died.menagerie_attraction_drop_chance` (a flat 0.0–1.0 chance, per-monster-type data),
   **not** scaled by `wave_reward_scalar` — this is a rare-find mechanic, not part of the
   wave-escalating economy. Consumed only by the Menagerie System (`menagerie.md`, shipped —
   `Menagerie.attempt_lure()` queries and consumes `menagerie_lure` via the standard
   `Inventory.has_item_quantity()`/`consume_stackable()` convention; found stale 2026-08-27,
   this doc's own Rule 6 had never been updated after Menagerie went from "not yet designed"
   to shipped).

7. **Gold is a separate track from materials.** Resource Economy emits gold deltas via the existing
   shipped signal `resources_changed(gold: int, source: StringName)` — never through
   `materials_earned`/`materials_spent`. Gold funds tower placement (Tower System) and any other
   flexible in-mission spending; materials fund Sanctuary crafting/forging/building.

8. **Scout Phase starting gold.** On `mission_phase_changed` transitioning to `new_phase == "SCOUT"`,
   Resource Economy grants a flat `scout_starting_gold` constant via
   `resources_changed(scout_starting_gold, "mission_start_grant")` — fired before the Scout Phase
   timer starts, so the player always has spendable gold for pre-Wave-1 tower placement. (Reuses the
   existing `mission_phase_changed` signal rather than introducing a new event.)

9. **Rounding is always `round()`, applied once per kill, per drop-table entry** — never accumulated
   as fractional and truncated later. This is a hard rule to prevent rounding-bias exploits at high
   kill volume (e.g., 40 simultaneous kills each individually rounding down).

10. **Per-wave gold grant (added during `/design-system` 2026-07-14 — closes the in-mission gold-faucet
    gap flagged by the same-day cross-GDD review and `tower.md`'s OQ-10).** On `wave_completed`,
    Resource Economy grants gold scaled to the completed wave's difficulty via
    `resources_changed(gold_grant, "wave_completion_grant")` — see Formula 5. Together with the Scout
    Phase starting grant (Rule 8), this is the sole source of gold income during a mission — the two
    together are the entire in-mission gold faucet; there is no other gold income path (no per-kill
    gold, per the earlier decision to keep gold's tuning independent of the material-drop ERI curve).
    No ordering dependency on Tower or Monster internal state is required — Resource Economy only
    needs the completed wave's index from the `wave_completed` payload.

### States and Transitions

None. Resource Economy has no internal state machine — it is a stateless reactive calculator,
structurally identical in this respect to the EventBus itself (Rule 1). It caches only the latest
`menagerie_quality_bonus` scalar (Rule 3), which is not state in the FSM sense — just a
most-recent-value read.

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| **Monster System** | Monster → Economy | `monster_died` (`drop_table_id`, `menagerie_attraction_drop_chance`, `kill_source`) triggers Rule 2/5/6 |
| **Wave Manager** | Wave Manager → Economy | `wave_reward_scalar` (via `monster_spawn_requested`/`wave_started`), `mission_phase_changed` (triggers Rule 8 on SCOUT entry), `wave_completed` (triggers Rule 10 gold grant — **added during `/design-system` 2026-07-14**) |
| **Tower System** | Economy → Tower | `resources_changed(gold, source)` deltas, sourced from `"mission_start_grant"` (Rule 8) and `"wave_completion_grant"` (Rule 10); Tower System owns affordability checks against its own tracked balance — Economy does not validate, only reports deltas. **Tower System does not yet emit the placement-cost debit itself — see Open Questions.** |
| **Inventory System** | Economy → Inventory | `materials_earned`/`materials_spent`; Inventory is sole storage owner, Economy has zero opinion on stack caps |
| **Menagerie System** | Menagerie → Economy | `creature_happiness_changed` et al. feed `menagerie_quality_bonus` (Rule 3); Economy → Menagerie handoff of `menagerie_lure` material via standard `materials_earned` |
| **Crafting / Equipment Forge / Defense Building** | Economy → these (indirect via Inventory) | No direct interface — these systems query Inventory for material availability, not Resource Economy |
| **Mission HUD** | Economy → HUD | `resources_changed` and `materials_earned` read-only, for live gold/material counters |

## Formulas

### Formula 1 — Drop Occurrence Roll

```
drop_occurs = random() < base_drop_rate
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base drop rate | `base_drop_rate` | float | 0.3–0.6 | Per-kill chance this monster's drop table resolves at all; data-defined per `DropTableResource`. Refines the provisional `game-concept.md` Resource Flow formula's same-named variable — this is now the authoritative definition. |

**Output Range:** boolean. **Example:** `base_drop_rate = 0.45` → 45% of kills from this table produce a drop; the rest yield nothing.

---

### Formula 2 — Drop Quantity (on a successful drop)

```
quantity = max(guaranteed_min_quantity, round(base_quantity × wave_reward_scalar × menagerie_quality_bonus))
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base quantity | `base_quantity` | int | 1–3 | Per-`DropEntry` data value |
| Wave reward scalar | `wave_reward_scalar` | float | 1.00–4.768 | From Wave Manager (owned formula, not redefined here) |
| Menagerie quality bonus | `menagerie_quality_bonus` | float | 1.0–1.5 | Cached from latest Menagerie happiness aggregate |
| Guaranteed minimum | `guaranteed_min_quantity` | int | 1 (fixed) | Table-level floor — a successful drop is never quantity 0 |

**Output Range:** 1 to `round(3 × 4.768 × 1.5) = 21` under extreme late-game/max-Menagerie conditions — **`4.768` is `wave_reward_scalar` at the `r=0.25` safe-range ceiling, wave 8; at the actual `r=0.20` default the wave 8 ceiling is `3.583`, giving `round(3 × 3.583 × 1.5) = 16`.** Typical mid-game (base_quantity=1, wave 4, menagerie 1.2) ≈ `round(1 × 2.13 × 1.2) = 3` (using the r=0.25 wave-4 scalar 1.953 rounded to 2.13×1.2's implied intermediate — at r=0.20's wave-4 scalar 1.728, the same inputs give `round(1 × 1.728 × 1.2) = round(2.074) = 2`).
**Example (r=0.25 ceiling):** `base_quantity=1`, wave 8 (`wave_reward_scalar=4.768`), `menagerie_quality_bonus=1.3` → `round(1 × 4.768 × 1.3) = round(6.198) = 6`. **At `r=0.20` default**, wave 8 (`wave_reward_scalar=3.583`): `round(1 × 3.583 × 1.3) = round(4.658) = 5`.

---

### Formula 3 — Quality Tier Roll

```
quality_roll_probability = clamp(base_quality_probability × wave_reward_scalar, 0.0, quality_probability_ceiling)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base quality probability | `base_quality_probability` | float | 0.05–0.15 | Per-quality-tier, per-`DropEntry` data value |
| Wave reward scalar | `wave_reward_scalar` | float | 1.00–4.768 | Same input as Formula 2 — same wave, two independent effects |
| Quality probability ceiling | `quality_probability_ceiling` | float | 0.80 (tuning knob) | Hard cap regardless of scalar growth |

**Output Range:** 0.05 to 0.80 (clamped). **Example (r=0.25 ceiling):** `base_quality_probability=0.10` (Uncommon tier), wave 8 (`wave_reward_scalar=4.768`, the `r=0.25` safe-range ceiling) → `0.10 × 4.768 = 0.477` (47.7% roll chance) — under the 0.80 ceiling, so uncapped at this data point. **At `r=0.20` default**, wave 8 (`wave_reward_scalar=3.583`): `0.10 × 3.583 = 0.358` (35.8% roll chance). A higher base probability or a future scalar extension beyond the documented range would clamp.

---

### Formula 4 — Combined ERI Validation Check (design-time content-authoring constraint, not a runtime calculation)

**Corrected during `/design-review` (2026-07-14)** — the original formula below was mathematically
broken: it multiplied a worst-case quantity maximum drawn from one hypothetical entry's authored
values against a worst-case quality-probability ratio drawn from a *different* hypothetical entry's
values, producing a number that no single kill ever actually generates. A live re-derivation against
`wave-manager.md`'s own frozen semantic contract (line 240) found the actual intended meaning:
`WAVE_ERI_CEILING_COMBINED = wave_reward_scalar_max² = 4.768² = 22.73` is simply what happens if
*both* the quantity axis and the quality-probability axis scale by the full `wave_reward_scalar`
with no clamping or rounding — i.e., the idealized growth ratio from wave 1 to max wave, for either
axis alone, is `wave_reward_scalar_max = 4.768`; multiplying two such ratios together (because both
axes share the same scalar) gives `4.768 × 4.768 = 22.73`. The check that actually matches this
intent is a **per-entry wave-1-to-max-wave yield-growth ratio**, not a cross-entry worst-case product:

```
quantity(wave)      = max(guaranteed_min_quantity, round(base_quantity × wave_reward_scalar(wave) × menagerie_quality_bonus))
quality_roll(wave)   = clamp(base_quality_probability × wave_reward_scalar(wave), 0.0, quality_probability_ceiling)

combined_ERI(entry) = [ quantity(wave_max) / quantity(wave_1) ] × [ quality_roll(wave_max) / quality_roll(wave_1) ]
```

Must satisfy `combined_ERI(entry) ≤ WAVE_ERI_CEILING_COMBINED × ROUNDING_TOLERANCE (22.73 × 1.10 =
25.0)`, evaluated **per `DropEntry`** using that entry's own authored
`base_quantity`/`base_quality_probability` at both wave 1 (`wave_reward_scalar=1.00`) and max wave
(`wave_reward_scalar=4.768`), with a fixed `menagerie_quality_bonus=1.0` at both wave points (the
Menagerie term cancels out of the *ratio* as long as it's held constant across both evaluations —
this check isolates wave-driven growth, not Menagerie's separate multiplicative bonus). The 10%
`ROUNDING_TOLERANCE` accounts for `round()`'s effect on small integer quantities (see worked example
below, which lands at 23.84 — a rounding artifact, not a real overshoot); a failure of more than 10%
over the idealized 22.73 indicates a genuine authoring error, not rounding noise.

**Why this now behaves correctly:** for any entry where `base_quality_probability × 4.768 ≤
quality_probability_ceiling` (true for the entire Formula 3 variable-table range, 0.05–0.15, since
`0.15 × 4.768 = 0.7152 < 0.80`), the quality-roll ratio is exactly `4.768` (unclamped), so
`combined_ERI = 4.768 × 4.768 = 22.73` — landing exactly on the ceiling, never exceeding it, matching
Wave Manager's literal definition. For higher `base_quality_probability` values that DO clamp before
max wave (e.g. `0.20`, from the wider Tuning Knob range), the quality-roll ratio shrinks below 4.768
(clamping caps the numerator), which only *lowers* `combined_ERI` further below 22.73. **The check
therefore always passes for content authored within Formula 3's stated ranges** — it exists to catch
a future authoring mistake (e.g. a mis-set `guaranteed_min_quantity` that distorts the quantity
ratio), not to reject ordinary content the way the broken version did.

**Example check** (previously-flagged failing case, base_quantity=1, no Menagerie bonus,
base_quality_probability=0.15 — the top of Formula 3's range): `quantity(wave_1) =
round(1×1.00×1.0)=1`; `quantity(wave_max)=round(1×4.768×1.0)=5`; `quality_roll(wave_1) =
clamp(0.15×1.00,0,0.80)=0.15`; `quality_roll(wave_max)=clamp(0.15×4.768,0,0.80)=0.7152`. `combined_ERI
= (5/1) × (0.7152/0.15) = 5 × 4.768 = 23.84`. **This is a rounding artifact** (quantity's `round()`
pushed the ratio slightly above the idealized 4.768) — still within a reasonable tolerance of 22.73,
not the previous 343.3-order-of-magnitude failure. Content authors should treat a small overshoot
from rounding as acceptable; large overshoots (multiple integer multiples of 22.73) indicate a real
authoring error.

---

### Formula 5 — Wave-Completion Gold Grant

*(Added during `/design-system` 2026-07-14 — this is the in-mission gold faucet, closing the gap
flagged by the same-day cross-GDD review and `tower.md`'s OQ-10: prior to this formula, the Scout
Phase starting grant (Rule 8) was the only gold income in the entire game.)*

```
gold_grant(w) = round(base_wave_gold × wave_reward_scalar(w))
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Wave index | `w` | int | 1–8 | The wave that just completed, from the `wave_completed` payload |
| Base wave gold | `base_wave_gold` | int | 15–25 | Tuning knob; default 20 |
| Wave reward scalar | `wave_reward_scalar(w)` | float | 1.00–4.768 | Same shared input as Formulas 2/3, owned by Wave Manager. `wave-manager.md`'s own Tuning Knobs table sets its **default** at `difficulty_growth_rate (r) = 0.20`, with a **safe range** of 0.15–0.25 authorable per-mission — **1.00–4.768 is the full safe-range span, not the default-case span** (see the r=0.20-vs-r=0.25 correction below). Reused deliberately rather than a new curve — matches the existing shared-scalar convention and avoids front-loading mid-game gold relative to a matched-endpoint linear curve. |
| Gold grant | `gold_grant` | int | 20–95 | Flat gold delta added to `MissionEconomy`'s balance (ADR-0018) via `resources_changed(gold_grant, "wave_completion_grant")`. **20–95 is the full safe-range span (r=0.15 to r=0.25); at the actual default r=0.20, the real per-wave range is 20–72 (see corrected examples below).** |

**Output Range:** 20 (wave 1, any `r`) to 95 (wave 8, only at the `r=0.25` safe-range ceiling — 72 at the actual `r=0.20` default).

**Corrected 2026-07-15 (`/design-review` re-review #2) — this formula's worked examples and calibration previously assumed `r=0.25` (Wave Manager's safe-range ceiling) silently, never stating so, when Wave Manager's actual documented default is `r=0.20`.** Both cases now shown explicitly:

**Example — r=0.20 (Wave Manager's actual default):** wave 4 completes with `wave_reward_scalar = 1.20³ = 1.728` → `gold_grant = round(20 × 1.728) = 35`.
**Example — r=0.25 (Wave Manager's safe-range ceiling, not the default):** wave 4 completes with `wave_reward_scalar = 1.25³ = 1.953` → `gold_grant = round(20 × 1.953) = 39`.

**Mission-total calibration (recalibrated 2026-08-11 — `scout_starting_gold` lowered 150 → 50; figures below are the current values, original 150-based totals struck through for traceability):**
- **At `r=0.20` (Wave Manager's actual default):** default 6-wave mission (`game-concept.md`'s default `wave_count`) — per-wave grants 20+24+29+35+41+50 = 199, plus `scout_starting_gold`(50) = **249 total** (was 349 at scout=150). This is now **101 gold below** the historical 350–400 sub-range noted in the registry (`tower_placement_budget_target`) for 6-wave missions — a real, larger gap than the prior 1-gold shortfall. Not treated as a blocking miscalibration here: the real Tower content that motivated this change (`tower.md`, 4 blueprints at 10–12g placement cost) means a 249-gold mission can still field ~20 towers across a full mission, well past Formula 4's own "10 towers at average cost 30 = 300 points" anchor — that anchor itself assumed a cost distribution real content didn't end up matching. **Reopened as an Open Question below** rather than resolved here — reconciling `tower_placement_budget_target`'s own number is `tower.md`'s call, not this GDD's.
- **At `r=0.25` (Wave Manager's safe-range ceiling, not the default):** per-wave grants 20+25+31+39+49+61 = 225, plus 50 = **275 total** (was 375 at scout=150).
- **Design decision (2026-07-15, predates the 2026-08-11 scout-gold change):** `base_wave_gold` was not raised to close the then-1-gold gap at r=0.20 — left unchanged by this pass; the gap this recalibration opens is materially different in size and is tracked as its own Open Question, not folded into that earlier (now superseded) 1-gold discussion.

**Flag — 8-wave missions, both r cases, figures corrected for the 2026-08-11 scout-gold change:**
- **At `r=0.20` (default):** waves 7–8 add `round(20×2.986)=60` and `round(20×3.583)=72`; 1–8 total = 199+60+72=331, plus 50 = **381 total** (was 481 at scout=150).
- **At `r=0.25` (ceiling):** waves 7–8 add 76 and 95; 1–8 total = 225+76+95=396, plus 50 = **446 total** (was 546 at scout=150).
- Both 8-wave figures now land inside the registry's `tower_placement_budget_target` range (350–550) rather than overshooting it — the reverse of the situation this section previously flagged. See the reopened Open Question below: the 6-wave case now undershoots the same registry range by more than the 8-wave case fits inside it, which is itself a sign `tower_placement_budget_target` needs a fresh look against real Tower content rather than either mission length being individually re-tuned.

**Degenerate-strategy check — stockpiling:** gold has no sink except tower placement, no yield or
interest, and `MissionEconomy` resets the balance every `grid_initialized` (ADR-0018, reset trigger
corrected 2026-08-11 — see that ADR's dated amendment), so nothing carries cross-mission. Within a mission, a wave must be survived to trigger its grant — a player who
never places towers takes full unmitigated damage from every monster and loses well before the grants
could compound into anything exploitable. No countermeasure is needed.

### Formula 6 — Mission-End Building Material Surplus Grant

*(Added 2026-08-17, player-requested — Tower Assembly's blueprint-copy component recipes
(`crafting.md` Rule 1a) need a funding source distinct from monster drops; this is that source.)*

```
surplus_quantity(t) = base_surplus_per_slot × foundation.tier(t)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Tower | `t` | — | — | One tower from the still-standing set at `mission_phase_changed(new_phase == MISSION_COMPLETE)` |
| Base surplus per slot | `base_surplus_per_slot` | int | fixed | Tuning knob; default 1 |
| Foundation tier | `foundation.tier(t)` | int | 1–4 | `t`'s own `FoundationComponent.tier` |
| Surplus quantity | `surplus_quantity` | int | 1–4 | Granted once per slot (Foundation/Weapon/Focus/Power — every tower has exactly one of each, so this is unconditional per standing tower) |

11. **Rule — still-standing tally basis.** The tally is taken from
    `TowerSystem.get_placed_tower_slot_tally()` at the moment
    `MISSION_COMPLETE` fires — towers **still placed at that instant**, not
    every tower ever placed during the mission. A tower that was sold or
    destroyed earlier in the mission already cost its placement gold and its
    4 source components; granting surplus for it too would double-reward.
    This is a **design decision**, not an inference from existing rules —
    flagged explicitly since Formula 5 (wave-completion gold) has no
    equivalent "which towers" ambiguity to resolve. **DEFEAT does not grant
    surplus** — only a completed mission does, matching Formula 5's own
    completion-framing (the Sanctuary's progress is protected on defeat per
    Core Rule 11 of `save-persistence.md`, but this specific bonus is not).

12. **Rule — grant composition.** For each standing tower: `surplus_quantity`
    of each of 4 new materials (`foundation_surplus`/`weapon_surplus`/
    `focus_surplus`/`power_surplus`, one per component slot — not one per
    basic tower type; the tower-specificity of what gets crafted from them
    lives on the *recipe*, not the material), plus a flat
    `archetype_bonus_quantity` (default 2) of one **existing** drop material
    keyed by the tower's own `FoundationComponent.archetype`
    (`physical`→`iron_plating`, `elemental`→`rift_shard`,
    `ranged`→`goblin_hide`, `support`→`spore_dust` — a tuning/flavor mapping,
    freely re-tunable without touching the mechanism). Both halves emit via
    the existing `materials_earned` signal — no new EventBus signal was
    introduced for this grant.

**Worked example**: 2 towers standing at MISSION_COMPLETE — a Tier 1 Archer
(`physical`) and a Tier 2 Frostbolt Turret (`elemental`). Grant: 1 each of
`foundation_surplus`/`weapon_surplus`/`focus_surplus`/`power_surplus` (Tier 1
tower) + 2 each of the same 4 (Tier 2 tower) = 3 of each surplus material,
plus 2 `iron_plating` + 2 `rift_shard`.

**Degenerate-strategy check — stockpiling:** identical shape to Formula 5's
own check (no yield/interest, no cross-mission carry beyond the materials
themselves sitting in Inventory, which has its own slot-cap pressure) —
placing towers costs gold and components up front, so there is no way to
farm this grant without first spending real resources per standing tower.

## Edge Cases

- **If `drop_table_id` is empty/null on a dying monster**: no drop resolution occurs at all — treated
  identically to the structural no-drop case (Rule 5), not as a failed roll.
- **If `drop_table_id` is non-empty but `GameDataRegistry` has no matching `DropTableResource`**: log a
  content-data warning once per unique bad ID per session (not per kill, to avoid log-spam during a
  wave of the same misconfigured monster type), then resolve as no-drop.
- **If a matching `DropTableResource` exists but has zero `DropEntry` children**: identical no-drop
  outcome, no warning — an empty table is valid authoring intent (e.g., a monster deliberately
  designed to never drop).
- **If `monsters_died_batch` fires with 20+ entries in one frame** (EventBus's high-frequency batching
  threshold): Resource Economy resolves each entry independently, in array order, applying
  Formulas 1–3 exactly as if dispatched individually. The batch is purely an EventBus transport
  optimization, not a resolution-semantics change — keeps drop math order-independent and
  deterministic regardless of batching.
- **If `menagerie_quality_bonus` changes mid-batch** (a breeding-pen event fires while a batch of kills
  is still being iterated in the same frame): every kill reads whatever bonus value is cached at the
  moment its own entry resolves, not a value snapshotted once at batch start. This system is stateless
  by design (Rule 1) — freezing a snapshot would require new owned state, which is out of scope;
  sub-frame ordering differences here are gameplay-invisible.
- **If a `DropTableResource` is authored with `quality_probability_ceiling` above 0.80**: Formula 3's
  `clamp(..., 0, 0.80)` still hard-clamps at runtime regardless of the authored value — the
  wave-1-to-max-wave combined-ERI check (Formula 4, corrected 2026-07-14) is design-time-only
  guidance, but the 0.80 clamp is a runtime code constant, not sourced from the Resource. A
  badly-authored entry cannot exceed it.
- **If mission ends while a `monster_died` drop resolution is mid-calculation in the same frame**:
  resolution completes and its `materials_earned`/`resources_changed` signals still fire — resolution
  is synchronous and stateless (no `await`), so "mid-resolution spanning a phase transition" cannot
  actually occur; there is no race to handle.
- **Exploit check — farming a low-difficulty wave repeatedly for outsized yield**: not possible.
  `wave_reward_scalar` is sourced from the actual current wave's live state, not cached across mission
  replays — no persistent multiplier carries between attempts.

## Dependencies

| System | Direction | Nature |
|---|---|---|
| **EventBus** | Hard dependency | All communication routes through it — no direct references |
| **Save & Persistence** | Hard dependency | Gold balance and any mission-scoped economy state must be included in save/restore ordering (see Open Questions — exact owner still unassigned) |
| **Monster System** | Hard dependency (upstream) | `monster_died` payload (`drop_table_id`, `menagerie_attraction_drop_chance`, `kill_source`) is the sole trigger for drop resolution |
| **Wave Manager** | Hard dependency (upstream) | `wave_reward_scalar` and `mission_phase_changed` are required inputs to Formulas 2/3 and Rule 8; `wave_completed` is a required input to Formula 5/Rule 10 (**added during `/design-system` 2026-07-14**) |
| **Tower System** | Hard dependency (downstream); also a **new read dependency (upstream)** added 2026-08-17 for Formula 6 | Tower reads gold via `resources_changed` to validate placement affordability; Resource Economy has no opinion on Tower's cost formulas. **New**: at `MISSION_COMPLETE`, Resource Economy queries `TowerSystem.get_placed_tower_slot_tally()` directly (a pull-based method call via `&"tower_system"` group discovery, not an EventBus signal — Resource Economy previously never read Tower System state at all) |
| **Inventory System** | Hard dependency (downstream) | Inventory is sole storage owner for all materials this system calculates; `materials_earned`/`materials_spent` is the interface |
| **Menagerie System** | Soft dependency (bidirectional) | Menagerie feeds `menagerie_quality_bonus` inputs; Resource Economy hands off `menagerie_lure` material via the standard material interface |
| **Crafting / Equipment Forge / Defense Building** | Soft dependency (indirect) | These systems consume materials via Inventory queries, not directly from Resource Economy — no direct interface exists or is needed |
| **Mission HUD** | Soft dependency (downstream) | Reads `resources_changed`/`materials_earned` for live display only; no functional dependency |

## Tuning Knobs

| Parameter | Default Value | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| `base_drop_rate` (per table) | 0.45 | 0.3–0.6 | Crafting trivialized, no scarcity felt | Meta-progression grinds to a halt (matches game-concept.md's existing knob for this value) |
| `base_quantity` (per DropEntry) | 1 | 1–3 | Combined with high wave scalar, floods Inventory stacks | Late-wave hauls feel flat despite escalating difficulty |
| `guaranteed_min_quantity` | 1 | 1 (fixed) | N/A — this is a floor, not a scaling lever | A zero-yield successful drop contradicts "Fuel Not Trophy" — never lower |
| `quality_probability_ceiling` | 0.80 | 0.60–0.90 | Near-guaranteed high-quality drops trivialize rarity | Rarity feels unreachable even at max wave escalation |
| `base_quality_probability` (per tier, per DropEntry) | 0.05–0.15 | 0.02–0.20 | Combined-ERI validation (Formula 4) fails content review | Rare tiers effectively never appear before quality_probability_ceiling matters |
| `base_surplus_per_slot` (Formula 6) | 1 | 1–2 | Blueprint-copy recipes become trivially affordable, undercutting the raw-material Crafting path | Surplus materials never accumulate fast enough to fund even one blueprint-copy recipe |
| `archetype_bonus_quantity` (Formula 6) | 2 | 1–4 | Existing drop materials become abundant purely from tower survival, bypassing monster-kill scarcity | Bonus feels negligible, tower survival reads as unrewarded |
| `scout_starting_gold` | 50 *(lowered from 150, 2026-08-11 — see below)* | 30–80 | Player can nearly max out the mission budget before Wave 1, undermining wave-to-wave earning tension | Player can't field a viable opening build during Scout Phase |
| `base_wave_gold` *(added during `/design-system` 2026-07-14)* | 20 | 15–25 | Combined with wave_reward_scalar, later-wave grants (up to 95) let players rebuild an entire lane in one Intermission, undermining the sunk-cost weight of earlier placements | Later-wave grants too small to afford even a Tier 1 replacement tower, making boss-lane rebuilds after tower loss effectively impossible |
| `menagerie_quality_bonus` ceiling | 1.5× | 1.0–2.0× | Replaces crafting skill (matches game-concept.md's existing knob) | Menagerie investment feels pointless |

**Cross-reference note**: `base_drop_rate` and `menagerie_quality_bonus` ceiling ranges are inherited
directly from `game-concept.md`'s Tuning Knobs (not duplicated as new knobs — this GDD is the
authoritative refinement of those provisional values, per Formula 1's cross-reference).

## Visual/Audio Requirements

Resource Economy itself has no dedicated visual presence — all feedback surfaces through Mission HUD
and Inventory. Per art-bible.md's stacked-sprite diorama direction:
- **Material drop feedback**: a small material-tier-colored pip animates from the kill location toward
  the HUD material counter (matches the "hand-carved diorama" reading — not a flat UI toast).
- **Gold delta feedback**: `resources_changed` triggers a brief gold-counter tick-up/down animation on
  Mission HUD, no world-space VFX (gold isn't a physical drop object, unlike materials).
- **Rare drop (`menagerie_lure`) feedback**: a distinct, higher-priority visual cue (per art-bible
  Section 4 rarity-tier conventions, same visual language as Inventory's rarity color coding) — meant
  to feel notable, consistent with "Fuel Not Trophy" treating rare finds as genuinely rare.
- Audio direction not yet authored (no `design/audio/` bible exists) — same gap already noted in
  `game-concept.md`.

> **📌 Asset Spec** — Visual/Audio requirements are defined above. After the art bible is approved
> (already is — Sections 1–4 exist), run `/asset-spec system:resource-economy` to produce per-asset
> visual descriptions for the material-pip and rare-drop VFX.

## UI Requirements

- Mission HUD must display: current gold balance (live-updating), and a running material tally per
  material type earned this mission (not full inventory contents — that's Inventory's screen).
- No dedicated Resource Economy screen exists or is needed — this system is purely computational and
  has no player-facing configuration surface.
- Sanctuary UI (undesigned) will need to show gold/material totals at the meta-progression level,
  sourced from Inventory (materials) and wherever gold balance ultimately lives (see Open Questions).

> **📌 UX Flag — Resource Economy**: This system has UI requirements (HUD gold/material counters). Stories
> referencing these counters should cite `design/ux/mission-hud.md`, not this GDD directly. **Resolved
> 2026-07-14**: `design/gdd/mission-hud.md` is now Designed (pending `/design-review`) and its
> Dependencies table confirms `materials_earned`/`resources_changed` for live gold balance and a
> running per-material-type tally — the gap flagged here is closed.

## Acceptance Criteria

- **AC-01** — **GIVEN** a kill with `base_quantity=1`, `wave_reward_scalar=4.768`, `menagerie_quality_bonus=1.3` and a successful drop roll, **WHEN** `monster_died` resolves, **THEN** `materials_earned` reports quantity `6` (`round(1×4.768×1.3) = round(6.198)`).
- **AC-02** — **GIVEN** inputs that round to less than 1, **WHEN** a successful drop resolves, **THEN** reported quantity is floored to `guaranteed_min_quantity=1`, never 0.
- **AC-03** — **GIVEN** `base_quality_probability=0.20`, `wave_reward_scalar=4.768` (raw product 0.954), **WHEN** the quality roll probability is computed, **THEN** the used probability is clamped to `0.80`.
- **AC-04** — **GIVEN** `menagerie_quality_bonus=1.5`, **WHEN** a kill resolves both terms, **THEN** quantity reflects the 1.5× factor but the quality-probability calculation does not include it.
- **AC-05** — **GIVEN** a `DropTableResource` registered under `"goblin_basic"` with two `DropEntry` children, **WHEN** `monster_died` cites that id, **THEN** exactly those two entries' materials resolve, sourced from `GameDataRegistry`, never a hardcoded table.
- **AC-06** — **GIVEN** a BOSS reaches breach, **WHEN** despawn occurs, **THEN** `monster_died` never fires and no material/gold signal emits.
- **AC-07** — **GIVEN** a monster force-cleared with `kill_source == "wave_end"`, **WHEN** this occurs, **THEN** no `monster_died` fires and no drop resolves.
- **AC-08** — **GIVEN** `menagerie_attraction_drop_chance=0.5` and `wave_reward_scalar=4.768`, **WHEN** the lure roll resolves, **THEN** it uses `0.5` unscaled.
- **AC-09** — **GIVEN** any gold delta, **WHEN** emitted, **THEN** it fires only as `resources_changed`, never `materials_earned`/`materials_spent`.
- **AC-10** — **GIVEN** `mission_phase_changed(new_phase="SCOUT")`, **WHEN** handled, **THEN** `resources_changed(150, "mission_start_grant")` fires exactly once, before the phase timer starts.
- **AC-11** — **GIVEN** `monsters_died_batch` with 20+ entries, **WHEN** each resolves, **THEN** each is rounded independently — no fractional carryover between entries.
- **AC-12 [Statistical]** — **GIVEN** `base_drop_rate=0.45` over a 10,000-kill sample, **WHEN** drops are tallied, **THEN** the observed rate falls within ±2% of 45%.
- **AC-13** — **GIVEN** an unregistered `drop_table_id` triggers twice in one session, **WHEN** both occur, **THEN** exactly one warning logs and both resolve as no-drop.
- **AC-15 [Statistical]** *(added during `/design-review` — closes a gap where only Formula 1's
  drop-occurrence roll had statistical coverage, not Formula 3's quality-tier roll)*: **GIVEN**
  `base_quality_probability=0.10`, `wave_reward_scalar=4.768` (computed probability 0.477) over a
  10,000-successful-drop sample, **WHEN** quality-tier hits are tallied, **THEN** the observed rate
  falls within ±2% of 47.7%.
- **AC-16** *(added during `/design-review` — AC-11 only tested rounding independence across kills in
  a batch, never across multiple `DropEntry` rows within one kill)*: **GIVEN** one kill against a
  `DropTableResource` with two `DropEntry` rows whose raw (pre-round) products are 1.4 and 2.6
  respectively, **WHEN** both entries resolve, **THEN** each rounds independently to its own nearest
  integer (1 and 3) — no shared fractional carry between entries from the same kill.
- **AC-17** *(added during `/design-review`, per ADR-0017's flagged risk)*: **GIVEN** a single
  `entity_id`'s death is dispatched via `monster_died` and also appears in a same-frame
  `monsters_died_batch` (a forced/injected test double-dispatch — this should not occur in normal
  operation per ADR-0017's confirmed exclusivity invariant), **WHEN** Resource Economy processes both,
  **THEN** materials/gold are awarded exactly once for that `entity_id`, never twice. *(Regression
  guard for the double-award risk ADR-0017 flagged as unmitigated and consequential.)*
- **AC-18a** *(split from AC-18 during `/design-review` re-review #2, 2026-07-15 — tests Wave Manager's actual default `r`)*: **GIVEN**
  `wave_completed` fires for wave 4 **at Wave Manager's documented default `difficulty_growth_rate = 0.20`** (`wave_reward_scalar = 1.20³ = 1.728`), **WHEN** the gold grant resolves,
  **THEN** `resources_changed(35, "wave_completion_grant")` fires exactly once, using
  `base_wave_gold=20` (default): `round(20 × 1.728) = 35`.
- **AC-18b** *(renamed from the original AC-18, added `/design-system` 2026-07-14 — Formula 5/Rule 10; relabeled 2026-07-15 to clarify it tests the safe-range ceiling, not the default)*: **GIVEN**
  `wave_completed` fires for wave 4 **at Wave Manager's safe-range ceiling `difficulty_growth_rate = 0.25`, not its default** (`wave_reward_scalar=1.953`), **WHEN** the gold grant resolves,
  **THEN** `resources_changed(39, "wave_completion_grant")` fires exactly once: `round(20 × 1.953) = 39`.
- **AC-19a** *(split from AC-19 during `/design-review` re-review #2, 2026-07-15 — tests Wave Manager's actual default `r`; totals updated 2026-08-11 for the `scout_starting_gold` 150→50 recalibration)*:
  **GIVEN** a default 6-wave mission at Wave Manager's documented default `difficulty_growth_rate = 0.20`, where every wave completes with default Tuning Knob values,
  **WHEN** all wave-completion grants and the Scout starting grant are summed, **THEN** the total gold
  granted across the mission is exactly **249** (50 scout + 199 across waves 1–6: 20+24+29+35+41+50) — this no longer lands inside the historical 350–400 sub-range of the `tower_placement_budget_target` registry entry for 6-wave missions; see the reopened Open Question below rather than Formula 5's now-superseded 1-gold-gap note.
- **AC-19b** *(renamed from the original AC-19, added `/design-system` 2026-07-14; relabeled 2026-07-15 to clarify it tests the safe-range ceiling, not the default; totals updated 2026-08-11)*:
  **GIVEN** a 6-wave mission at Wave Manager's safe-range ceiling `difficulty_growth_rate = 0.25`, where every wave completes with default Tuning Knob values,
  **WHEN** all wave-completion grants and the Scout starting grant are summed, **THEN** the total gold
  granted across the mission is exactly 275 (50 scout + 225 across waves 1–6) — also below the live
  `tower_placement_budget_target` registry range (350–550) and its 6-wave-specific historical sub-range (350–400).

**Content Validation Checklist** *(relocated out of Acceptance Criteria during `/design-review` —
qa-lead review found this is a design-time/build-time check, not a runtime-observable AC, since no
enforcement workflow exists yet; it does not belong numbered alongside genuinely runtime-testable
criteria)*:
- **CV-1** — **GIVEN** a `DropTableResource` entry's authored `base_quantity`/`base_quality_probability`,
  **WHEN** Formula 4's per-entry `combined_ERI` is computed at wave 1 and max wave, **THEN** it must
  not exceed `WAVE_ERI_CEILING_COMBINED × ROUNDING_TOLERANCE (25.0)`. Enforcement mechanism (build-time
  validator vs. manual design-review checklist item) remains undefined — see Open Questions.

**Known testability gaps** (per qa-lead review): Rule 1 (statelessness) has no black-box-testable AC —
internal implementation state isn't observable via signals. AC-09/AC-10 test emission only, not
end-to-end balance correctness — this is intentional, not a gap: Resource Economy is stateless by
design (Rule 1), and runtime gold-balance storage is **now owned by `MissionEconomy`
(ADR-0018, Accepted 2026-07-13)** — see that ADR's own Validation Criteria for the authoritative
balance-accumulation integration test; duplicating it here would risk drift between two specs for the
same behavior. CV-1's enforcement workflow (who runs the content check, at what point in the pipeline)
is undefined — only the arithmetic is specified.

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| ~~**Who owns the runtime gold balance?** Resource Economy only emits deltas via `resources_changed`; no system currently stores/tracks the actual balance.~~ | — | **RESOLVED** — re-confirmed stale during `/design-review` (2026-07-14): `ADR-0018` (Accepted 2026-07-13) created a new `MissionEconomy` Autoload (boot position 8) that subscribes to `resources_changed` and accumulates `_gold_balance`, resetting on `mission_launched`, with `get_gold_balance()`/`can_afford()` read APIs. This GDD's emission contract (Rule 7) is unchanged by that decision — Resource Economy still only emits deltas, as designed. |
| ~~`resources_changed(gold: int, source: StringName)` exists in shipped `event_bus.gd` code but is undocumented in `event-bus.md`'s catalogue.~~ | — | **RESOLVED** — stale as of `/design-review` (2026-07-14): `event-bus.md` catalogued this on 2026-07-13 (after this GDD's 2026-07-11 authoring date), closing ADR-0017/ADR-0018's documentation gap. |
| ~~`mission-hud.md` is still only a skeleton stub and does not cover Resource Economy display (gold/material counters) at all.~~ | — | **RESOLVED 2026-07-14** — `mission-hud.md` is now Designed and its Dependencies table covers this display requirement. |
| Combined-ERI content-authoring check (Formula 4/AC-14) has no defined enforcement workflow — is it a build-time validator, a design-review checklist item, or manual? | technical-director / qa-lead | Arithmetic is specified; the process that runs it is not. |
| ~~**Added 2026-07-16 (Story 015 implementation/QA review)**: now that Formula 4 is corrected (2026-07-14), the check is mathematically bounded to a maximum of 23.84 for ANY schema-valid `DropEntry` within Formula 3's authored range — confirmed by an exhaustive property-sweep test. It can currently only fail for a degenerate authored value (`base_quality_probability=0.0`) or an extreme `guaranteed_min_quantity` distortion (which, verified, only *lowers* the result further, never raises it past the ceiling). Does this check still serve a meaningful content-authoring guardrail purpose, or was its practical value already fully absorbed by the same 2026-07-14 correction that fixed its math?~~ **Resolved 2026-07-31**: accepted as **defense-in-depth only** — the check's documented purpose (this section's own text above, "it exists to catch a future authoring mistake... not to reject ordinary content the way the broken version did") already states this framing correctly; the only thing missing was closing this Open Question against it. No code or formula change made — `CombinedEriValidator` keeps guarding against degenerate/malformed content (a zeroed `base_quality_probability`, a distorted `guaranteed_min_quantity`), it just isn't expected to ever fire for ordinary, correctly-authored content, and that's now the accepted, documented scope rather than an open question. | game-designer / qa-lead | Closed — see TD-econ-007 (`docs/tech-debt-register.md`) for the full decision record. |
| ~~Does `menagerie_lure`'s naming and consumption model need to be co-designed with the Menagerie GDD once it's authored, or is this GDD's definition sufficient as a provisional contract?~~ **RESOLVED, found stale 2026-08-27** | game-designer (Menagerie GDD author) | `menagerie.md` (Approved) adopted this GDD's exact naming/mechanic — `Menagerie.attempt_lure()` consumes `menagerie_lure` via the standard `Inventory.has_item_quantity()`/`consume_stackable()` convention, no co-design changes needed. |
| **Reopened 2026-08-11** (was: "Is `scout_starting_gold=150` well-calibrated against Tower's *actual* archetype cost distribution, or only against the provisional 350–400 budget target?"): `scout_starting_gold` was lowered 150→50 against real Tower content (4 blueprints, 10–12g placement cost — 50 gold still fields 4–5 opening towers). This widens the mission-total shortfall against `tower_placement_budget_target`'s 350–400 (6-wave) / 350–550 (any length) registry range from 1 gold to ~100 gold (see Formula 5's Mission-total calibration note and AC-19a/AC-19b for the corrected arithmetic). Not resolved here: does `tower_placement_budget_target` itself need lowering to match real Tower costs, or was the scout-gold cut too aggressive? | economy-designer / tower.md owner | The prior version of this question is answered (Tower's catalogue now exists) but the number it revealed needs its own follow-up decision — the registry range and this GDD's gold economy no longer agree, and reconciling them is a balance call neither doc's author should make unilaterally mid-edit. |
| ~~**Tower System still doesn't emit the placement-cost debit.** Formula 5/Rule 10 defines the gold *income* side of the faucet, but no system anywhere emits `resources_changed(-placement_cost, "tower_placement")` when a tower is placed.~~ | — | **RESOLVED** — stale as of `/design-review` re-review #2 (2026-07-15): `tower.md` Rule 9 now emits `resources_changed(-placement_cost, "tower_placement")` before `tower_placed` on every confirmed placement, closing OQ-10 on the Tower GDD side (added 2026-07-14, same day this question was opened). |
| ~~**`mission_resource_budget` is implicitly 6-wave-scoped.** Formula 5's mission-total calibration only holds for the 6-wave default; 8-wave missions overshoot the existing 350–400 target.~~ | — | **RESOLVED** — stale as of `/design-review` re-review #2 (2026-07-15): `tower.md`'s Tuning Knobs `mission_resource_budget` row now states both figures explicitly ("6-wave missions (default): ~375 ... 7–8-wave missions: ~500–550"), and the `tower_placement_budget_target` registry entry was widened to `value_max: 550` to match (revised 2026-07-15). The 8-wave overshoot figures were also corrected in this pass — see Formula 5's Mission-total calibration note above (was 546 at the r=0.25 ceiling; the actual r=0.20 default case is 481). |
