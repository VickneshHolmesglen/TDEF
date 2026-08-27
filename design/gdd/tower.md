# Tower System

> **Status**: Needs Revision (Revision 21 — 2026-07-15). **Revision 19:** `/review-all-gdds` re-run found the Interactions table's Monster System row still described the struck T4 Siege mechanic (`is_siege`/"shield penetration") despite Revision 17 removing it everywhere else — fixed, no remaining Siege references anywhere in this document. Revision 13's `/design-review` full pass #2 [6 specialists + creative-director] found **MAJOR REVISION NEEDED** against Revision 12: 5 correctness/test-quality blockers (mission-start cache clear silently skipped OUTCOME→SCOUT; SCATTER could repeat a target on consecutive cycles; projectile pool undersized against the doc's own 40–60+ tower grid ceiling; 3 ACs asserted private internal state; Sprint-0 EventBusSpy gating note miscounted) were fixed same-session, plus 3 new ACs added for previously-uncovered validation rules. **OQ-11 (T4 boss-lane viability / Intermission authorship weight) is now RESOLVED** via two user design decisions made in Revision 14: (1) Intermission wave preview telegraphs boss spawn-cell information on boss waves (Rule 8), giving players real information to validate a T4 placement before committing; (2) Tier 4 Foundations are now capped at `base_cost ≤ 30` (Formula 4), which fixes the bimodal-affordability gap and, as a side effect, unifies the cost ceiling across all tiers. **Revision 15 (2026-07-15):** `design/gdd/wave-manager.md`'s own scoped `/design-review` re-pass on the boss telegraph found the originally-specified `has_boss: bool`/`boss_entry_lane: StringName` fields were wrong — undefined "lane" vocabulary, and `has_boss` redundant with existing payload data — and replaced them with a single always-present `boss_spawn_cell: Vector2i` field. This GDD's Rule 8, Dependencies table, and OQ-11 were corrected to match; also fixed a stale cross-reference that pointed at Wave Manager's "Rule 22" (Pathfinding Synchronization, unrelated) instead of the correct Rule 11. **Revision 16 (2026-07-15):** propagation-debt fixes — `mission_resource_budget` and Formula 4's budget note now state both r=0.20 (349, default) and r=0.25 (375, ceiling); Formula 3's boss-damage note corrected 40–80→55–80 to match monster.md's Pass 7. **Revision 17 (2026-07-15):** the T4 Siege mechanic ("penetrate boss damage phase shields") is struck — no boss-shield-phase mechanic exists anywhere in monster.md, and none is currently needed; T4's boss-lane identity now stands on `tier_boss_dps_multiplier` alone (fully self-contained, no undesigned dependency). Removed: the `siege` component field, the `is_siege` field on `tower_attacked` (also removed from event-bus.md), 2 dependent ACs, and the stale `siege` column in the tier cross-field consistency table. **Revision 18 (2026-07-15):** the `damaged_component_repair_cost` gap is resolved by user decision — converted from a Tuning Knob row that misleadingly presented an unowned formula as resolved into a formal Open Question (OQ-12). No Sanctuary-side currency or repair-owning system exists anywhere in the project (Crafting/Menagerie/Defense Building/Equipment Forge all Not Started), so the repair mechanic itself remains genuinely undesigned — but the document no longer misrepresents it as answered. The dependent AC was narrowed to only what this GDD can guarantee (the `damaged` flag is set and enforced as non-equippable; clearing it is out of scope until OQ-12 resolves). **No blocking items remain that are resolvable within this document alone** — OQ-12 requires a Sanctuary economy system to exist first. **Revision 20 (2026-07-15) — worked through the Recommended-tier list**: Formula 1's DPS ceilings corrected to account for `DAMAGE_BOOST` (1920→2400, 3840→4800); `RANGE_BOOST` given a schema-ceiling clamp and load-time warning (previously had neither, unlike the other 3 perk types); `AURA_EXTEND` given the matching load-time warning (already had a clamp, was missing the warning); `aoe_density_cap` annotated as intentionally not runtime-enforced (a level-design constraint, not a code invariant); HOMING re-acquisition priority confirmed already fully specified in Rule 19 ("oldest in-flight projectiles get priority") — this list item was stale, already resolved in an earlier revision without being marked off; 1 of the 2 flagged redundant AC pairs found and merged (two near-identical zero-damage-tower `tower_wave_summary.max_hp` ACs) — the second candidate pair investigated (the N=0 stagger-guard ACs) turned out to be an intentional weak-then-strong test pair, not true redundancy, and was left as-is; `hp_base`'s Tuning Knobs row now cross-references Formula 3's Tier-1-should-be-≥120 recommendation, which previously existed only as unactioned prose. **Revision 21 (2026-07-15) — design-theory reconciliation notes added (documentation only, no mechanical change)**: D3-A's "no mechanical niche" for T1/T2 clarified against `game-pillars.md` Pillar 2's anti-pattern list — distinguishes combat-efficiency niche (absent, intentional) from cross-system synergy niche (fully present); T4's value proposition reframed as "shortens boss-phase duration / reduces hero exposure," not "solves what towers alone can't" — consistent with Hero's structurally mandatory boss engagement per `game-concept.md` Core Rule 1. **Revision 22 (2026-07-15d)** — `/review-all-gdds` 4th pass found Rule 8's INTERMISSION wave preview mandate specified bucketing monsters by "archetype" (Physical/Ranged/Elemental/Support), which is Tower's own Foundation-component vocabulary — no GDD defines any such field on a monster. Rescoped to bucket by `tier` (STANDARD/ELITE/BOSS), data monster.md already exposes via `GameDataRegistry.get_monster()`; no new payload field needed. Also fixed: OQ-2 (stale — Hero already subscribes to `tower_removed`) closed. See `design/gdd/reviews/tower-review-log.md` for full findings. **Revision 23 (2026-07-17, `/design-review --depth lean` re-review)** — closed the 3 confirmed cross-doc gaps this pass found: OQ-12 now points at `crafting.md` Rule 6 as the resolving system (Tuning Knob row and Dependencies table updated, new Crafting dependency row added — full closure still pending Inventory's `clear_damaged_flag()`); added the `constellation_eligibility_tag` EventBus-payload requirement to the Constellation dependency row (closes `constellation.md` OQ-4 from Tower's side — `event-bus.md` still needs the actual field added); added the new `TowerSystem.get_component_loadout(tower_id)` query API to the Tower Mastery dependency row (closes `tower-mastery.md`'s blocking dependency). **Revision 24 (2026-08-24, `/design-review --depth lean` re-review, S8-07)** — 2 more stale Open Questions found and fixed: OQ-3 (`power_component_id` on `tower_attacked`) was answered by a different mechanism than proposed — `damage-status.md` confirms `effect_type`/`effect_value`/`effect_duration` are forwarded directly on the payload, no registry lookup needed; OQ-5 (Resource Economy resource type) resolved since 2026-07-14 — the resource is **gold**, not "build points," but this document's own body text never got the terminology update. Fixed: all 8 remaining "build point(s)" references in Rules/Formulas/UI Requirements/Acceptance Criteria replaced with "gold" (OQ-5's own historical note excepted, which intentionally keeps the old term for context). OQ-4/OQ-6/OQ-7 remain genuinely open (content-catalogue completeness and level-design confirmations, not factual staleness).
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-08-24
> **Implements Pillar**: Placement is the Puzzle · Endless Theorist (cross-system synergies)

## Engine Risk Notes (Godot 4.6.2)

| API | Used for | Risk | Status |
|-----|---------|------|--------|
| Glow/pulse VFX (aura pulse, weapon-lock glow, beam glow, constellation glow border) | Multiple Visual Requirements throughout this GDD | HIGH (Godot 4.6 glow rework) | **Partially characterized 2026-07-13** — same live-engine test as `hero.md`. Confirmed on the pinned 4.6.2.stable binary: no visible bloom on overbright 2D content without `Viewport.use_hdr_2d` enabled, and enabling it darkens the entire scene, not just the glowing element. All glow-based VFX in this GDD (aura pulse, weapon-lock glow, beam glow, constellation border) share this same integration cost — plan for a whole-scene brightness/contrast pass alongside VFX implementation, not an isolated per-effect toggle. See `docs/engine-reference/godot/VERSION.md`. |
| `sqrt()` (Tower Affinity formula cross-reference) | Cross-reference to Hero Formula 2 | LOW | Already verified — see `hero.md` Engine Risk Notes |

## Overview

The Tower System is the primary strategic layer of Sanctuary Defenders: it governs every tower's placement, component configuration, targeting behavior, attack logic, and lifecycle from Scout Phase placement through mid-mission destruction. Technically, it owns tower entity state (component loadouts, HP, archetype, occupancy footprint), orchestrates the placement and removal workflow with the Grid System, emits the five registered tower events — `tower_placed`, `tower_destroyed`, `tower_component_equipped`, `tower_attacked`, `pre_placement_perk_activated` — that downstream systems (Constellation, Hero, Tower Mastery, Damage & Status, Mission HUD) subscribe to, and persists component loadouts across sessions through Save & Persistence. Each tower is composed from four independently swappable component slots — foundation, weapon, focus, power — which together define its attack archetype, targeting behavior, and constellation eligibility. The Tower System has no direct runtime references to other systems; all cross-system notifications flow through the EventBus. Player-facing, it transforms the 16×12 mission grid from an empty field into a precisely engineered killing ground: every tower placed is a commitment to a lane, a synergy with an adjacent constellation pattern, and a declaration of which hero class archetype is being reinforced. The fantasy of having designed the machine that wins the wave — and watching it execute — begins here.

## Player Fantasy

> The hero is the one piece of your strategy that thinks. Towers are the pieces that *remember*.
>
> Every tower you bring to a mission carries a signature: the foundation you chose in the Sanctuary, the weapon you paired with it after three missions of experimenting, the focus that changes how it targets, the power component you crafted from materials a creature you bred specifically for this purpose finally produced. Nobody told you to combine them this way. You figured it out — or stumbled into it — and wrote that discovery into a machine that will now execute it, faithfully, every time you place it on the field.
>
> The feeling is not control. It is *authorship*. A tower does not improvise. It does not panic. It does not forget. Wave after wave, it does exactly what you told it to do — and the measure of your skill is whether what you told it to do was right. When you round a corner mid-mission and see your east lane still holding, when the frost tower you placed before the first wave is still working the chokepoint you identified in the Scout Phase, the satisfaction is the particular satisfaction of being validated by something you made. You weren't there. You didn't need to be. You were right before the fight started.
>
> This is what towers give you that the hero cannot. The hero plays from inside the fight, reading and reacting in real time. Towers play from a commitment you made earlier — in the calm before the wave, maybe even in the Sanctuary the night before — when you looked at the map, looked at your component inventory, and decided how you thought this fight would go. When that decision holds, the feeling is not power. It is recognition. You made that. It worked. You understood something.
>
> And when it doesn't hold, the hero is there. That's the other half of the bargain: towers give you a standing army you authored, and the hero gives you the judgment to put yourself where that army couldn't reach.

## Detailed Design

### Core Rules

#### Group 1: Component Slots

1. Each tower has exactly **4 component slots** — `foundation`, `weapon`, `focus`, `power` — each independently filled with one component item. A tower with any empty slot is incomplete and cannot be placed.

2. **Slot responsibilities:**

   | Slot | Governs |
   |------|---------|
   | `foundation` | Tower archetype (Physical / Ranged / Elemental / Support), max HP, cell footprint (1×1 or 2×2), tier DPS multiplier |
   | `weapon` | Attack type, base damage, attack speed, projectile behavior (hitscan / projectile / AoE) |
   | `focus` | Targeting priority rule, attack range, attack cone/arc, **tower facing direction** (fixed compass direction: N, NE, E, SE, S, SW, W, NW — set in component data at content creation time; the attack cone is centered on this direction) |
   | `power` | Special effect applied on hit (elemental damage, slow, burn, etc.), constellation eligibility tag |

2a. **TowerComponent Resource Schema** — Each component slot stores a typed data Resource. The fields below are the authoritative schema per slot type. All component Resources include `damaged: bool` (false by default; set true when a tower is destroyed mid-mission). Any field outside the valid range listed here is a load-time error.

   **Foundation schema:**
   | Field | Type | Valid Values | Description |
   |-------|------|-------------|-------------|
   | `archetype` | String | physical / ranged / elemental / support | Tower class; governs Hero affinity |
   | `hp_base` | float | [80.0, 400.0] | Base HP at Tier 1 |
   | `tier` | int | 1–4 | Foundation upgrade tier |
   | `tier_multiplier` | float | {1.0, 1.5, 2.0, 2.5} | HP scale factor per tier |
   | `tier_dps_multiplier` | float | {1.0, 1.6, 2.4, 4.0} | DPS scale factor per tier |
   | `tier_cost_factor` | float | {1.0, 1.5, 2.0, 4.0} | Placement cost scale per tier |
   | `tier_boss_dps_multiplier` | float | {1.0, 2.0} | Boss-entity DPS multiplier. T1/T2/T3 = 1.0 (no bonus); T4 = 2.0. Load-time error if T1–T3 ≠ 1.0 or T4 ≠ 2.0. |
   | `footprint` | Vector2i | (1,1) or (2,2) | Grid cell footprint dimensions |
   | `pre_placement_perk` | String | any perk type id, or "" | Empty string = no perk |
   | `archetype_cost_factor` | float | [0.5, 2.0] | Per-archetype placement cost multiplier. All archetypes = 1.0 at MVP. Must be in range [0.5, 2.0] — values at or below 0.0 are load-time errors (zero-cost tower). |
   | `bonus_damage_vs_tags` | Dictionary | tag(StringName) → multiplier(float, >0.0) | **Tower Stats System Phase 1 (2026-08-16).** Bonus damage multiplier keyed by target `MonsterResource.archetype_tag` (e.g. `{&"armored": 1.3}`). Missing key = 1.0 (no bonus). Stacks multiplicatively alongside `tier_boss_dps_multiplier` below, does not replace it. |
   | `damaged` | bool | false / true | Non-equippable until Sanctuary repair |

   **Weapon schema:**
   | Field | Type | Valid Values | Description |
   |-------|------|-------------|-------------|
   | `weapon_damage` | float | [8.0, 120.0] | Base damage per hit |
   | `attack_speed` | float | [0.5, 4.0] | Attacks per second |
   | `projectile_type` | String | HOMING / BALLISTIC / BEAM / AURA | AURA is Support archetype only |
   | `element` | String | "" \| fire \| frost \| poison \| lightning \| arcane | **Made functional in Tower Stats System Phase 1 (2026-08-16)** — previously VFX-color-only. "" = physical (no resistance lookup). Non-"" values are checked against the target's `MonsterResource.elemental_resistances` at the matching key; see Damage Resolution Formula below. |
   | `crit_chance` | float | [0.0, 0.8] | **Phase 1.** Chance per attack to critically hit. |
   | `crit_multiplier` | float | [1.0, 3.0] | **Phase 1.** Flat damage multiplier applied on a critical hit. |
   | `armor_penetration` | float | [0.0, 1.0] | **Phase 1.** Fraction of armored-monster damage mitigation (D&S's `ARMORED_MITIGATION_MULTIPLIER`, 50% flat) this weapon negates. 0.0 = no change; 1.0 = mitigation fully countered. |
   | `status_proc_chance` | float | [0.0, 1.0] | **Phase 1.** Chance per attack the Power effect (below) actually applies. 1.0 preserves the pre-Phase-1 always-applies behavior. |
   | `aura_effect_type` | String | any effect id, or "" | Support only; identifies the buff or debuff type |
   | `aura_effect_value` | float | [0.0, …] | Support only; magnitude of the aura effect (e.g., buff strength, debuff intensity). Upper bound is effect-type–dependent; D&S System owns the valid range per effect_id. Required field in `tower_aura_pulse` payload. |
   | `aura_radius_cells` | int | [1, 6] | Support only; Chebyshev radius of aura pulse |
   | `aoe_radius_cells` | int | [0, 4] | BALLISTIC only; 0 = single target. **Consumed by gameplay damage resolution (Phase 2 — Splash, 2026-08-23).** On a hit, every other monster within `aoe_radius_cells` (Chebyshev) of the primary target's cell also takes damage, scaled by Formula 1c's falloff. Also drives `ProjectileVisual`'s cosmetic detonation-ring sizing (`mission_scene.gd`), unchanged. |
   | `damaged` | bool | false / true | Non-equippable until Sanctuary repair |

   **Focus schema:**
   | Field | Type | Valid Values | Description |
   |-------|------|-------------|-------------|
   | `targeting_mode` | String | CLOSEST_TO_GOAL / SPAWN_ORDER / LOWEST_HP / HIGHEST_HP / SCATTER | |
   | `attack_range_cells` | int | [1, 8] | Chebyshev range in grid cells |
   | `cone_half_angle` | float | [22.5, 180.0] | Half the arc width in degrees |
   | `facing_direction` | String | N / NE / E / SE / S / SW / W / NW | |
   | `damaged` | bool | false / true | Non-equippable until Sanctuary repair |

   **Power schema:**
   | Field | Type | Valid Values | Description |
   |-------|------|-------------|-------------|
   | `effect_type` | String | any effect id, or "" | On-hit effect; empty = no effect |
   | `effect_value` | float | [0.0, …] | Magnitude; system-dependent |
   | `effect_duration` | float | [0.0, …] | Seconds; 0 = instant |
   | `constellation_eligibility_tag` | String | any tag id, or "" | Empty = not constellation-eligible |
   | `damaged` | bool | false / true | Non-equippable until Sanctuary repair |

3. Component slots are configured in the **Sanctuary** between missions. Slots cannot be swapped during a mission. When a tower is placed, its component loadout is locked for the duration of that mission.

4. The combination of the four slots fully determines every aspect of the tower's behavior at runtime. No tower has implicit default behaviors that exist outside its component data.

#### Group 2: Archetypes

5. Foundation components belong to exactly one of four **archetypes**: `physical`, `ranged`, `elemental`, `support`. The archetype of a tower is the archetype of its Foundation slot. Changing the Foundation changes the archetype.

5a. **Support Archetype Aura Model:** Support towers do not fire projectiles. Their Weapon slot specifies `projectile_type: AURA`, `aura_effect_type`, and `aura_radius_cells`. When the attack timer expires (same delta-time countdown as all towers — see Rule 17), the Support tower emits a `tower_aura_pulse` event instead of a projectile event. **`tower_aura_pulse` uses a `TowerAuraPulseEvent` typed Resource subclass** (Core Rule 4 compliance — events with compound payloads use typed Resources, not raw typed parameters). Payload fields: `tower_id: int`, `aura_effect_type: String`, `aura_effect_value: float`, `aura_radius_cells: int`. The Damage & Status System subscribes to `tower_aura_pulse` and applies the named effect to all eligible entities (ally towers, monsters, or both — determined by `aura_effect_type`) within `aura_radius_cells` Chebyshev distance of the tower's anchor cell at the moment of pulse. Support towers transition through IDLE → TARGETING → ATTACKING state identically to other archetypes; "ATTACKING" for a Support tower means the aura pulse is emitting. `tower_aura_pulse` must be added to the EventBus catalogue (owned by Tower System; subscribers: Damage & Status System, Mission HUD). The minimum pulse interval (maximum attack_speed) for Support towers should be set by the content author to avoid saturating the Damage & Status System with aura processing.

**Support aura visibility requirements:**
- **Aura radius visualization in placement ghost:** When placing a Support tower, the ghost renders the `aura_radius_cells` boundary as a dashed ring at Chebyshev distance = `aura_radius_cells` from the tower anchor. This ring is always shown during placement, not just on hover — the player must see the aura radius to make placement decisions.
- **Per-pulse VFX (required):** On each `tower_aura_pulse` emission, the Mission HUD must trigger a brief visual pulse effect (expanding ring, burst, or glow) at the Support tower's grid position. This VFX is the player's only confirmation that the aura is firing during WAVE_ACTIVE. Without it, the player cannot know whether the Support tower is contributing. The specific VFX asset is owned by the Audio/Visual design phase; this GDD mandates the requirement.
- `tower_wave_summary.aura_applications_this_wave` (see Rule 23) provides the post-wave authorship summary for Support towers.

6. Archetype determines which hero class a tower contributes to for Tower Affinity and Tower-Synced Class proximity accumulation (see Hero System GDD, Rules 14–22).

7. Archetype is included in `tower_placed`, `tower_removed`, and `tower_destroyed` event payloads so subscribers (Hero System, Constellation System, Mission HUD) never need to cache a tower_id → archetype mapping internally.

#### Group 3: Placement

8. Tower placement is permitted **only during `SCOUT` and `INTERMISSION`** mission states. The Tower System rejects placement confirmation during `WAVE_ACTIVE` — the active-wave restriction enforces the authorship contract: placement decisions must be committed before the wave begins, not adjusted in response to what spawns. Removal follows the same rule: permitted during `SCOUT` and `INTERMISSION`, blocked during `WAVE_ACTIVE`. Repositioning (remove + re-place) therefore requires waiting for the next Intermission. During `OUTCOME` and `DEFEAT`, all placement and removal writes are rejected. The Tower System checks the current mission phase before calling any Grid write functions.

   > **Cross-doc conflict resolved:** `game-concept.md` Rule 5 stated "placing mid-wave is valid but forgoes that perk." **Tower System Rule 8 supersedes this.** Mid-wave placement is not permitted. `game-concept.md` Rule 5 and its WAVE_ACTIVE row in the States and Transitions table must be updated before the architecture phase to reflect this decision.

   **Scout Phase information layer:** When the mission enters `SCOUT` phase, the Wave Manager emits a `wave_preview_available` event delivering **Wave 1 composition** (monster types, counts, tier) to the Mission HUD. This data is the **intended information baseline for Scout Phase placement decisions** — the player builds against a known threat profile, not a blank slate. The Tower System does not own or produce this data; it is surfaced via Mission HUD and the `wave_preview_available` event (see Wave Manager GDD).

   **INTERMISSION wave preview mandate:** When the mission enters `INTERMISSION` (after any completed wave), the Wave Manager **must** emit `wave_preview_available` showing **partial threat information for the upcoming wave** — tier distribution and total monster count only (e.g., "12 monsters: 2 ELITE"). Individual monster type names, spawn order, and exact composition must **not** be surfaced during Intermission. **This partial-information model preserves the authorship contract for Intermission decisions:** the player commits to a meta-read of the threat profile ("this wave is elite-heavy, I need more single-target DPS") rather than reading an exact counter-pick list. The Mission HUD must aggregate `wave_preview_available.composition` into tier buckets (STANDARD/ELITE/BOSS) before display — individual `monster_id` values must not be shown during Intermission. Per-entry tier is resolved via `GameDataRegistry.get_monster(monster_id).tier` (the same static-lookup convention as every other `MonsterResource` read in this project, per ADR-0009) — `WaveCompositionEntry` itself carries no tier field and does not need one. **Contrast with Scout Phase:** Wave 1 preview during SCOUT delivers full composition (the player makes the initial commitment with complete information). Intermission previews for waves 2–8 deliver partial information (tier mix + count only). This asymmetry is intentional: Scout Phase authorship is informed; Intermission adjustment is meta-read. The Wave Manager GDD **Rule 11** must be updated to emit `wave_preview_available` on both `SCOUT` phase entry (full Wave 1 preview) and `INTERMISSION` phase entry (partial threat info). The `wave_index` field must indicate the upcoming wave number, not the just-completed wave number. *(Corrected 2026-07-15 — this previously cited "Rule 22," which is Wave Manager's Pathfinding Synchronization rule and unrelated to wave previews; the correct rule is Rule 11, "WAVE_ACTIVE → INTERMISSION.")* *(Corrected 2026-07-15d — `/review-all-gdds` 4th pass found this rule previously specified bucketing by "archetype" (Physical/Ranged/Elemental/Support), which is Tower's own Foundation-component vocabulary — no GDD defines any such field on a monster. Rescoped to bucket by `tier` (STANDARD/ELITE/BOSS), data monster.md already has; resolved via the existing `GameDataRegistry.get_monster()` lookup rather than a new payload field.)*

   **Boss-lane telegraph (added during `/design-review` 2026-07-14 re-review, resolves OQ-11; field names corrected 2026-07-15 per Wave Manager's own scoped review pass):** When the upcoming wave contains a `[BOSS]`-tagged monster, the Intermission `wave_preview_available` payload includes `boss_spawn_cell: Vector2i` (the boss's resolved spawn cell — spatial/structural information, not a stat readout). This is a narrow, deliberate exception to the partial-information model above: exact boss stats, HP, and attack damage remain hidden (preserving the meta-read/no-exact-counter-pick intent), but *where* the boss will spawn is now knowable before Intermission placement is committed. **Design rationale:** without this, a T4 Foundation's entire value proposition (`tier_boss_dps_multiplier`, Siege shield-penetration — see Formula 1) was unverifiable by the player before committing — the "you were right before the fight started" fantasy cannot hold for a threat the game never showed them. This exception narrows the asymmetry specifically for the one wave type where uninformed placement was previously punished disproportionately (see Rule 13's Sell refund and Formula 4's T4 cost cap). `boss_spawn_cell` is **always present** in the payload — sentinel `Vector2i(-1, -1)` on non-boss waves, never conditionally absent. **No separate `has_boss` field exists** — Wave Manager's own review found it redundant: boss presence for the previewed wave is already derivable from `next_wave_number == total_waves`, and is already present in the payload's existing `composition` array via the boss's `monster_id`; a second boolean would be a second, desync-prone source of truth for the same fact. **Cross-doc requirement:** this is a Wave Manager GDD change (`wave_preview_available` payload extension, Rule 11) and a Mission HUD display requirement, not something Tower System implements directly — Tower System does not consume `wave_preview_available` (the HUD does), same as the existing wave-preview mandate above. **This field is content-authoring-dependent**: Wave Manager's Rule 6 now requires the final wave's BOSS entry to use an explicit `spawn_cell_index` (round-robin forbidden) so `boss_spawn_cell` is resolvable at preview time — Tower System has no dependency on this constraint beyond consuming its result.

9. Before a placement is confirmed, the Tower System runs three checks in order:
   - **a. Resource check** (Rule 10): calls `MissionEconomy.can_afford(placement_cost)` (Autoload read API, per ADR-0018 — same direct-call pattern already used for `Grid`, not routed through EventBus). If `false`, reject immediately — no Grid or Pathfinding calls made.
   - **b. Grid footprint check**: call `Grid.is_footprint_placeable(top_left, size)`. If `false`, reject — no events emitted.
   - **c. Path guard check**: call `PathfindingSystem.would_block_all_paths(footprint_cells)`. If `true`, reject — no `path_invalidated` event is emitted. **Player feedback on path-guard rejection:** footprint cells flash red (same red-pulse visual as cell-type rejection; see Visual/Audio — Placement Rejected), the cursor displays a **distinct** "path-blocked" state indicator (visually differentiated from the standard cell-type rejection cursor — e.g. a different icon or cursor color), and a transient HUD callout **"Path would be blocked"** appears and auto-dismisses after 1.5 seconds. The HUD text is necessary because the footprint-flash color alone cannot distinguish path-guard rejection from cell-type rejection in all contexts, particularly on dense boards where both occur in close proximity. The path-guard audio cue (see Visual/Audio — Placement Rejected note below) must also be distinct from the cell-type rejection buzz. This call fires only on placement confirmation — not on hover.

   Only when all three checks pass does the Tower System call `Grid.place_tower(tower_id, top_left, size)`. On receiving `OK`, the Tower System emits `resources_changed(-placement_cost, "tower_placement")` **before** `tower_placed`, so `MissionEconomy`'s balance reflects the debit before any `tower_placed` subscriber (e.g. Mission HUD) reads it. *(Debit emission added during `/design-system` 2026-07-14 — closes OQ-10: `resource-economy.md`'s Rule 10/Formula 5 defines the income side of the gold faucet, but no system previously emitted the actual placement-cost debit. `resources_changed` is now an 11th event Tower System owns — see Dependencies.)* The Grid is always updated before any subscriber reacts.

10. Placement costs an **in-mission resource (gold)** — the amount is `placement_cost` from Formula 4. Gold income during a mission comes from `resource-economy.md`'s Rule 8 (Scout starting grant) and Rule 10 (per-wave completion grant) — Tower System has no opinion on how gold is earned, only on debiting it at placement. If the player lacks sufficient resources, placement is rejected before the Grid is queried (Rule 9a).

11. There is **no hard cap** on the number of towers per mission. The practical limit is the number of available `PLACEABLE` cells and the player's in-mission resource balance.

11a. **Tower ID assignment contract:** Each tower entity receives a `tower_id: int` assigned by the Tower System at the moment `Grid.place_tower()` returns `OK`. IDs are assigned from a **sequential counter that resets to 0 at the start of each mission**. IDs are not reused within a mission — a destroyed tower's ID is retired. The `tower_id` is the authoritative key for all event payloads, save data lookups, and cross-system references within a mission. It carries no meaning across mission boundaries.

12. **Pre-placement perk**: A tower placed during the `SCOUT` phase (before Wave 1 begins) receives a bonus perk defined in its component data. This perk is not available to towers placed during `INTERMISSION`.
    - The `placed_in_scout: bool` flag defaults to `false` on all new tower entities and is set to `true` at the moment of Scout Phase placement. It is never re-evaluated after initial placement.
    - **The perk activates immediately on placement.** `pre_placement_perk_activated` fires at that moment, before any wave begins. The perk enters an active/buffed state at placement and remains active for the tower's lifetime on that mission. This is the authoritative timing spec — the EventBus catalogue and all ACs must be consistent with this rule.
    - If a Scout-Phase tower is removed and re-placed **still within Scout Phase**, the perk reactivates on re-placement.
    - If a Scout-Phase tower is removed and re-placed **during any Intermission**, the perk is forfeited for that tower instance. `placed_in_scout` is set `false`.

12a. **Pre-placement perk schema** — The perk is a typed, bounded value defined on the Foundation component. All perk data is authored in a `TowerPerkRegistry` Resource and referenced by `perk_type` ID.

   **TowerPerkType enum** (authoritative set for MVP):
   | Perk type | Description | Applies to archetypes |
   |-----------|-------------|----------------------|
   | `DAMAGE_BOOST` | Weapon DPS multiplied by `(1.0 + perk_power)` for the tower's lifetime on that mission | Physical, Ranged, Elemental |
   | `RANGE_BOOST` | `attack_range_cells` increased by `round(perk_power × 8)` cells, **clamped to the schema ceiling**: `attack_range_cells = min(8, base_attack_range_cells + round(perk_power × 8))` — matches the `tower_attack_range_cells_max` registry constant. Without the clamp, a base `attack_range_cells = 8` with any `perk_power` would exceed the schema maximum. The clamp is applied at perk activation time, not Focus-component load time — the perk is valid; its output is bounded. (e.g., `perk_power=0.25` from base 7 → min(8, 7+2) = 8, wasting 1 cell of the perk's benefit) **Equip-time validation required** (same pattern as `SPEED_BOOST`, Rule 12a): if `base_attack_range_cells + round(perk_power × 8) > 8`, a load-time WARNING (not a hard error) must fire indicating partial perk benefit waste. *(Corrected 2026-07-15 — `/design-review` 2026-07-14 flagged this perk as the only one of the four with neither a clamp nor a wasted-benefit warning.)* | Physical, Ranged, Elemental |
   | `SPEED_BOOST` | `attack_speed` multiplied by `(1.0 + perk_power)`, hard-capped at 4.0 (the `attack_speed` load-time maximum). **Equip-time validation required** (not Foundation load time): validation fires when the full 4-slot component loadout is assembled — i.e., when the player equips the Foundation to a tower in the Sanctuary. A Foundation-plus-Weapon combination whose `weapon.attack_speed × (1.0 + perk_power)` exceeds 4.0 must raise a validation warning (not a hard error — the cap is safe, but the content author has authored a perk that partially wastes its benefit). Validating at Foundation load time alone is insufficient because `attack_speed` lives on the Weapon component, not the Foundation. | Physical, Ranged, Elemental |
   | `AURA_EXTEND` | `aura_radius_cells` increased by `round(perk_power × 6)` cells, **clamped to the schema ceiling**: `aura_radius_cells = min(6, base_aura_radius_cells + round(perk_power × 6))`. Without the clamp, a base `aura_radius_cells = 6` with `perk_power = 0.25` yields `6 + floor(1.5) = 7`, exceeding the schema maximum. The clamp is applied at perk activation time, not at load time — the perk is valid; its output is bounded. (e.g., `perk_power=0.25` from base 4 → min(6, 4+2) = 6) **Equip-time validation required** (same pattern as `SPEED_BOOST`, Rule 12a): if `base_aura_radius_cells + round(perk_power × 6) > 6`, a load-time WARNING (not a hard error) must fire indicating partial perk benefit waste. *(Corrected 2026-07-15 — `/design-review` 2026-07-14 flagged this perk as having a silent clamp but no wasted-benefit warning, unlike `SPEED_BOOST`.)* | Support only |

   **Perk power range (per type):**

   | Perk type | `perk_power` valid range | Minimum cell benefit | Reason for floor |
   |-----------|--------------------------|----------------------|-----------------|
   | `DAMAGE_BOOST` | [0.05, 0.25] | N/A (continuous %) | 5% floor is meaningful |
   | `SPEED_BOOST` | [0.05, 0.25] | N/A (continuous %) | 5% floor is meaningful |
   | `RANGE_BOOST` | [**0.0625**, 0.25] | `round(0.0625 × 8) = round(0.5) = 1` cell guaranteed | Eliminates dead zone: any value below 0.0625 yields `round(perk_power × 8) = 0` cells |
   | `AURA_EXTEND` | [**0.10**, 0.25] | `round(0.10 × 6) = round(0.6) = 1` cell guaranteed | Eliminates dead zone: any value below 0.10 yields `round(perk_power × 6) = 0` cells |

   Values outside the type's applicable range are load-time errors. Dead-zone boundaries: RANGE_BOOST rejects `perk_power < 0.0625` (at the floor, `round(0.0625 × 8) = round(0.5) = 1` cell — minimum non-zero benefit using GDScript's round-half-away-from-zero); AURA_EXTEND rejects `perk_power < 0.10` (at the floor, `round(0.10 × 6) = round(0.6) = 1` cell). Content authors must use ≥ 0.0625 for RANGE_BOOST and ≥ 0.10 for AURA_EXTEND. `0.25` = strong bonus for all types (25% DPS/speed bonus, +2 cells range/aura).

   **TowerPerkRegistry Resource:** A Godot Resource file (e.g., `res://data/towers/perk_registry.tres`) that maps `perk_type: String → {label: String, description: String, archetype_restrictions: Array[String]}`. Foundation components reference perks by `perk_type` ID only; the registry owns display strings and archetype validity. Load-time validation must confirm the `perk_type` ID on each Foundation component exists in the registry and that the archetype restriction is satisfied.

   **Save schema extension:** The TowerState save entry (per mission loadout) must include:
   | Field | Type | Notes |
   |-------|------|-------|
   | `placed_in_scout` | bool | `true` = Scout Phase placement (perk active); `false` = Intermission placement or perk forfeited. This is the sole indicator of active perk status — no separate `perk_active` field is required. Perk forfeiture is unconditional on Intermission re-placement (Rule 13). |
   | `perk_type` | String | Empty string `""` if no perk (Foundation `pre_placement_perk = ""`). Serialised as the perk type ID. |
   | `perk_power` | float | 0.0 if no perk. The active magnitude — for MVP equals the Foundation component's `perk_power` field directly. |

   A Foundation component with `pre_placement_perk = ""` has no perk; `perk_type` and `perk_power` fields in TowerState are ignored and should not affect tower stats.

13. **Removal rules:**
    - Towers may be removed during `SCOUT` and `INTERMISSION`. Removal is blocked during `WAVE_ACTIVE`. Repositioning (remove + re-place) must wait for the next Intermission.
    - **Sell interaction model:** The player selects a placed tower by clicking it during `SCOUT` or `INTERMISSION` to open the Tower Info Panel. The panel displays a **Sell** button. Pressing Sell removes the tower and returns `round(placement_cost × 0.4)` gold to the player's in-mission resource balance. This 40% refund reflects partial reclamation of the investment — placement is still a sunk-cost commitment (60% is lost), but the refund enables meaningful re-positioning decisions without total resource forfeiture. The Sell button is hidden during `WAVE_ACTIVE` — the info panel may still display, but the interaction affordance is not shown.
    - **Sell refund formula:** `sell_refund = round(placement_cost × 0.4)`. Uses GDScript `round()` (round-half-away-from-zero). Minimum refund at MVP (all archetypes `archetype_cost_factor=1.0`): `round(10 × 1.0 × 0.4) = 4` gold. Post-MVP minimum (if `archetype_cost_factor` reaches 0.5): `round(10 × 0.5 × 0.4) = round(2.0) = 2` gold. No floor clamp is applied — the formula output is the refund. Maximum refund: `round(240 × 0.4) = 96` gold.
    - Pre-placement perks are unconditionally forfeited on Intermission re-placement (see Rule 12) — no transfer buffer, no partial recovery. The refund applies only to the placement cost, not to any perk-activation value.
    - All four component items are returned to the player's component inventory **immediately** on removal. Tower System emits `tower_component_returned(tower_id: int, item_id: StringName, item_type: StringName, damaged: bool)` once per returned component (four emissions total), `damaged=false` since a voluntarily-sold tower's components are undamaged. **Tower System does not emit `item_added` itself** — per ADR-0016, Inventory is the sole emitter of `item_added`; Inventory subscribes to `tower_component_returned`, adds the item to its ledger, and emits `item_added(item_id, item_type, quantity=1, metadata={"damaged": damaged})` on Tower's behalf. *(Added during `/design-review` — resolves a cross-GDD gap: this GDD claimed components "return to inventory" without emitting anything Inventory could subscribe to.)*
    - The Grid cells occupied by the tower return to `PLACEABLE` immediately.
    - Voluntary removal emits `tower_removed` (not `tower_destroyed`). These are distinct events. Downstream systems (Constellation, Hero) subscribe to both to update their state identically, but the HUD may display different feedback per event.

#### Group 4: Targeting

14a. **Monster Data Access Model:** The Tower System holds no direct references to Monster entities. All targeting data is acquired from an **EventBus-driven local cache** maintained by the Tower System at the system level (not per-tower):

   **Cache entry schema** (Dictionary keyed by `entity_id: int`):
   | Field | Type | Source | Updated by |
   |-------|------|--------|------------|
   | `grid_cell` | Vector2i | `monster_spawned.grid_position` | `monster_cell_entered` |
   | `path_step_index` | int | `monster_spawned` | `monster_cell_entered` |
   | `current_hp` | float | `monster_spawned.hp_max` *(see note)* | `monster_damage_taken` |

   **Subscription events (Tower System → `_monster_cache`):**
   - `monster_spawned` → adds entry with `grid_cell`, `path_step_index`, and `current_hp` initialised to `hp_max` from the event payload. *(Requires `hp_max: float` field added to `monster_spawned` payload — EventBus GDD update required before implementation.)*
   - `monster_cell_entered` → updates `grid_cell` and `path_step_index` for the given `entity_id`
   - `monster_damage_taken` → updates `current_hp` for the given `entity_id` **on `CONNECT_DEFERRED` receipt**, per the subscription-mode table below — **not immediately**. *(Corrected during `/design-review` 2026-07-14 — this rule previously read "immediately on receipt (per-event, not batched)," directly contradicting the subscription-mode table's `CONNECT_DEFERRED` assignment for this same event. The two have never been consistent; this is the authoritative correction.)* Because `CONNECT_DEFERRED` handlers execute once at the end of the current frame (Godot 4.6 `call_deferred` semantics), a `monster_damage_taken` event fired early in a frame is not reflected in `_monster_cache.current_hp` until that frame ends — this is a **full-frame staleness window**, not a sub-frame one. Any tower evaluating LOWEST_HP/HIGHEST_HP targeting, or reading the universal tiebreaker's HP field, in the same frame as an earlier hit on the same wave sees the pre-damage HP value for the remainder of that frame. This approximation is accepted by design — targeting decisions made against a full frame of stale HP data produce no observable gameplay error (a tower fires at most once per attack cycle, and cycles are seconds apart relative to a single frame), and the staleness fully resolves by the start of the next frame. Do not switch this subscription to Synchronous in an attempt to eliminate the window — `CONNECT_DEFERRED` here exists specifically to prevent mid-resolution cache mutation while other towers' `tower_attacked` events are still resolving in the same frame (see subscription-mode table rationale); a Synchronous connection would reintroduce that hazard in exchange for a narrower staleness window that is not gameplay-observable.
   - `monster_died` → removes entry from `_monster_cache` (cache hygiene at system level only — individual towers do NOT subscribe to `monster_died` for targeting decisions; see Rule 18)
   - `monster_breached` → removes entry from `_monster_cache`, exactly as `monster_died` does. A breached monster has exited the grid; `monster_died` is NOT fired for breach events (see Monster System GDD). Without this subscription, SPAWN_ORDER and other targeting modes would reference entities no longer on the grid until `wave_completed` clears the cache. **EventBus GDD note:** `monster_breached` payload must include `entity_id: int` — verify this field is present in the EventBus catalogue.
   - `wave_completed` → `_monster_cache` is cleared entirely
   - **Mission-start cache clear:** `_monster_cache` must be fully cleared when `mission_phase_changed` fires with `new_phase = SCOUT` AND `previous_phase ∉ {SCOUT, WAVE_ACTIVE, INTERMISSION}`. Since a mission's only in-progress phases are SCOUT, WAVE_ACTIVE, and INTERMISSION, this single condition covers every case that must clear the cache: a DEFEAT→SCOUT retry, a **VICTORY (OUTCOME)→SCOUT** transition into the *next* mission, and a first-ever SCOUT entry from a non-mission state (e.g. main menu). **Corrected during `/design-review` 2026-07-14 re-review** — the prior formulation (`previous_phase ∉ {SCOUT, WAVE_ACTIVE, INTERMISSION, OUTCOME}` OR `previous_phase = DEFEAT`) explicitly excluded OUTCOME from the first branch and never re-included it in the second, so a victory-then-next-mission transition (OUTCOME→SCOUT) silently skipped the clear — stale `_monster_cache` entries (with re-numbered `entity_id`s from the finished mission) would persist into the new mission and could corrupt SPAWN_ORDER, range filtering, and the universal tiebreaker. The simplified condition above has no such gap. **Note:** The event `mission_started` does not exist — the correct trigger is `mission_phase_changed` (EventBus GDD). This clear is distinct from the per-wave `wave_completed` clear.

   **Signal subscription modes — authoritative (all 8 signal subscriptions — cache + phase/boss events):**

   | Event | Mode | Rationale |
   |-------|------|-----------|
   | `monster_spawned` | **Synchronous** | Cache write must be visible to targeting within the same frame as the spawn event — prevents SPAWN_ORDER blindspot on the first spawn of each wave |
   | `wave_started` | CONNECT_DEFERRED | Stagger offset assignment and state transition can safely trail one frame from wave-start; synchronous would add an N-tower update spike |
   | `monster_cell_entered` | Synchronous | Per-cell position update; no frame-ordering hazard; immediate read required for targeting |
   | `monster_damage_taken` | CONNECT_DEFERRED | May fire in the same frame as `tower_attacked` resolution; deferred prevents mid-resolution cache mutation |
   | `monster_died` | CONNECT_DEFERRED | Fired during damage resolution; cache eviction must trail the current attack cycle |
   | `monster_breached` | CONNECT_DEFERRED | Same frame hazard as `monster_died` |
   | `wave_completed` | CONNECT_DEFERRED | Cache clear must occur after all in-flight attack events for that wave are resolved |
   | `boss_tower_attack_attempted` | Synchronous | Must be processed immediately to apply damage in the current frame; no cache mutation |
   | `mission_phase_changed` | **Synchronous** | Cache clear on SCOUT entry must complete before the first `monster_spawned` of the new mission. CONNECT_DEFERRED would create a one-frame window where a stale cache entry exists while a new monster spawns — silent data corruption. This event must be subscribed synchronously. |

   CONNECT_DEFERRED handlers execute at the end of the current frame, after all synchronous handlers have run. **This table is authoritative — implementation must not change subscription modes without updating this spec and running AC B-13 (CONNECT_DEFERRED ordering integration test).**

   **`wave_completed` ordering dependency (cross-system mandate):** The Tower System's CONNECT_DEFERRED handler for `wave_completed` (cache clear + HP reset) assumes the next wave's `wave_started` does not fire in the same frame. The Wave Manager **must** yield at least one frame between emitting `wave_completed` and emitting `wave_started` for the next wave — this guarantees DEFERRED handlers for `wave_completed` execute before the next wave's monster spawning begins. **Wave Manager GDD mandate:** add an explicit frame-yield between `wave_completed` emission and `wave_started` emission. If Wave Manager emits both in the same frame via direct calls, `wave_completed`'s DEFERRED handlers will not execute before the next `monster_spawned` fires — breaking the cache clear guarantee. This constraint must be documented in the Wave Manager GDD (Rule 22 or equivalent). Assumes D&S System emits `monster_damage_taken` synchronously (not via `call_deferred`); if D&S switches to deferred emission, the one-frame staleness window described above expands to two frames — verify against D&S GDD Rule before implementation.

   At attack-timer expiry, a tower filters `_monster_cache` for entries whose `grid_cell` satisfies Formula 2 (within `effective_range` and cone), sorts by its targeting priority mode, and selects the top candidate. `path_step_index` from the cache is used for CLOSEST_TO_GOAL and SPAWN_ORDER comparisons; `current_hp` is used for LOWEST_HP and HIGHEST_HP modes and as the first tiebreaker in default targeting.

   > **EventBus updates required before implementation:** (a) `monster_spawned` payload must add `hp_max: float`; (b) `monster_cell_entered` must be confirmed in EventBus catalogue (already registered — see EventBus GDD).

14. **Default targeting priority** (when Focus component does not override): the tower targets the enemy that is **furthest along the active path** (highest `path_step_index` in `_monster_cache`, not Euclidean distance — monsters with higher path-step indices are closer to the GOAL). Tiebreaker 1: lowest current HP (not available from cache alone; Tower System must read current HP via a separate cache field updated from `monster_damage_taken` events). Tiebreaker 2: lowest `entity_id` (assigned sequentially at spawn — lower IDs spawned earlier within a wave; this ordering is stable across frames by construction).

   **Spatial sort for range filtering:** When building the range-filtered candidate list, spatial proximity (for cases where path distance alone is insufficient) is measured as Chebyshev distance, consistent with Formula 2.

15. The **Focus component overrides the targeting priority entirely** — it does not modify the default, it replaces it. Possible priority modes:

    | Mode | Behavior |
    |------|----------|
    | `CLOSEST_TO_GOAL` | Furthest along path (default if no Focus) |
    | `SPAWN_ORDER` | Targets the enemy with the **lowest `entity_id`** currently in range and cone that is alive. `entity_id` is assigned sequentially at spawn — lower IDs = earlier spawns in the mission. Among valid candidates, the earliest-spawned living monster in range is always selected. This is fully deterministic from `_monster_cache` with no additional per-tower state. If the current lowest-id target dies or exits range, the tower immediately selects the next-lowest-id alive target in range on the next attack cycle. Resets naturally via cache — no per-wave list management required. **SPAWN_ORDER determinism dependency:** Entity IDs are only deterministic if the Monster System processes `monster_spawn_requested` synchronously (not deferred). If monster spawning is batched or deferred, `entity_id` assignment order may diverge from emission order, breaking SPAWN_ORDER stability. The Monster System must process `monster_spawn_requested` synchronously and assign `entity_id` at the moment of `monster_spawned` emission — this is a cross-system contract. **Cross-doc verification required:** Monster GDD must explicitly state that `entity_id` is assigned synchronously at spawn. Add cross-reference note in Monster GDD before Tower System implementation. |
    | `LOWEST_HP` | Cleanup / finish-off |
    | `HIGHEST_HP` | Tank-busting |
    | `SCATTER` | **Spreads DoT stacks across multiple targets each attack cycle** — intentionally cycles to a different target each cycle rather than focusing one enemy down. Designed for Elemental archetype builds where the goal is wide-area poison/burn/frost stack accumulation rather than burst kill. The player choosing SCATTER is making a deliberate authorship decision: "this tower poisons everything in its lane in turn." **SCATTER is deterministic:** each tower maintains a per-tower `_scatter_index: int` counter (initialized to 0 at placement, reset to 0 on `wave_started`) and a per-tower `_last_scatter_target_id: int` (initialized to `-1` at placement, reset to `-1` on `wave_started`). On each attack cycle, the Tower System builds a candidate list of valid targets in range and cone, sorted ascending by `entity_id` (same ordering as SPAWN_ORDER), and computes `candidate = candidates[_scatter_index mod len(candidates)]`. **Repeat-guard:** if `candidate.entity_id == _last_scatter_target_id` AND `len(candidates) ≥ 2`, the tower instead targets `candidates[(_scatter_index + 1) mod len(candidates)]` — this is the only adjustment; `_scatter_index` still advances by exactly 1 after firing, same as the base case. If `len(candidates) == 1`, the repeat-guard does **not** apply — a single remaining candidate is always re-targeted, since there is no different target available to skip to; this is a deliberate exception, not a bug. After firing, `_scatter_index` increments by 1 and `_last_scatter_target_id` is set to the entity_id actually targeted this cycle. If the candidate list size changes between cycles (targets enter or leave range), the modulo ensures graceful wraparound — no out-of-bounds access, no missed targets. If the candidate list is empty, no shot is fired, `_scatter_index` is not incremented, and `_last_scatter_target_id` is unchanged. **No RNG is used.** The cycle is fully player-legible: a player can observe that the tower cycles through enemies in spawn order, one step per attack, and never repeats a target on consecutive cycles unless only one target remains. This aligns with the "tower does not improvise" authorship pillar — SCATTER's behavior is auditable in `tower_wave_summary.scatter_target_cycle` (added to Rule 23 payload) for post-wave review. *(Repeat-guard added during `/design-review` 2026-07-14 re-review — closes a confirmed bug where a shrinking candidate pool between cycles could select the same target on two consecutive cycles, contradicting this rule's own "cycles to a different target each cycle" claim. Confirmed reproducible: pool `[A,B]` → fires `A` → `B` leaves range → pool `[A]` → naive `1 mod 1 = 0` re-selects `A`, which is the size-1 exception above, not a guard failure; the guard exists for the size-≥2 collision case, e.g. a 4→2 candidate pool where the scatter index has advanced past the new pool's length.)* |

    Each Focus component data entry names exactly one mode.

    **Universal tiebreaker (all modes):** When the primary sort produces a tie (two targets equally valid under the mode's ranking), apply tiebreakers in this order: 1st = highest `path_step_index` (furthest along path — CLOSEST_TO_GOAL); 2nd = lowest `current_hp`; 3rd = lowest `entity_id` (deterministic final arbiter). Modes that use HP as their primary sort (LOWEST_HP / HIGHEST_HP) skip tiebreaker 2 and go directly to entity_id. SCATTER skips all tiebreakers — it cycles by index, not by ranking.

16. The Focus component also defines the tower's **attack cone** (the arc within which a target must fall to be acquired). Default cone: 360° (omnidirectional). Focused variants may specify a narrower arc. A target must be both within range AND within the attack cone to be acquired.

#### Group 5: Attack Execution

17. Towers operate on a **continuous fire-rate timer** implemented as a delta-time countdown, decremented by `delta` each `_process()` frame (framerate-independent). When the timer reaches ≤ 0, the tower evaluates its targeting priority and fires if a valid target exists in range and cone. If no valid target exists, the timer resets to `1.0 / attack_speed` and the tower remains in `TARGETING`. Towers do not accumulate a stored shot while idle.

   **Exception — Support archetype (AURA):** Support towers do not require a valid monster target to fire. When the attack timer reaches ≤ 0 for a Support tower, `tower_aura_pulse` is emitted **unconditionally** and the timer resets to `1.0 / attack_speed`. The Support tower transitions to `ATTACKING` on every timer expiry regardless of whether any enemy or ally is present within range. This allows ally-buffing auras to pulse continuously throughout a wave rather than only when enemies are in range. Support towers still follow the IDLE → TARGETING state transition on `wave_started`, but from TARGETING they fire unconditionally on timer expiry — they do not wait for a valid acquisition candidate. The state table entry for `TARGETING` for Support archetype should be read as: "timer expires → ATTACKING (unconditional for Support; valid-target-required for all other archetypes)."

   **`wave_completed` CONNECT_DEFERRED mandate:** The Tower System's subscription to `wave_completed` must use CONNECT_DEFERRED (see Rule 14a subscription mode table). This guarantees that any in-flight `tower_attacked` events from the final attack cycle of a wave are processed by all other subscribers before the Tower System resets HP and clears `_monster_cache`. Subscribing synchronously creates a race where the cache is cleared before a projectile's damage event is processed.

17a. Each tower's attack timer is initialized to `(1.0 / attack_speed) + stagger_offset` at the moment of placement, where `stagger_offset` is assigned using **stratified allocation** across the range [0.0, 0.2] seconds:
   - At the start of each wave, the Tower System counts N = number of active towers at `wave_started`. **If N = 0, stagger assignment is skipped entirely** — no division occurs. This is a valid game state (a player who placed no towers and starts a wave with an empty field). The guard must appear before the slot-width calculation: `if N == 0: return`.
   - Each tower is assigned the midpoint of its slot: slot index `i` (zero-based) receives `stagger_offset = (i + 0.5) × (0.2 / N)`.
   - Slot assignment order is determined by `tower_id` (ascending) — lower IDs receive earlier slots.
   - This guarantees that no two towers share the same stagger offset at wave start, regardless of tower count. Random assignment (naively drawn from [0.0, 0.2]) does not provide this guarantee — with 50+ towers, pigeonhole effects would cluster multiple towers at similar offsets, defeating the purpose of staggering.

   The stagger extends only the **first** attack interval; subsequent shots fire at the normal `1.0 / attack_speed` interval. The offset is recalculated via stratified allocation on every `wave_started` (not fixed at placement). The stagger distributes simultaneous fire across approximately 12 frames at 60 FPS, preventing mass-fire spikes that would exceed the EventBus `eventbus_batch_threshold` constant (20 `tower_attacked` events per frame) when many towers activate at wave start.

18. A tower **does not lock onto a target between attack cycles**. Each cycle independently re-evaluates the priority and selects the current best target. If the previous cycle's target has moved out of range or died, the tower naturally acquires a new one.

   **Target death detection method:** Individual towers do NOT subscribe to `monster_died`. Instead, target validity is verified at the top of each attack cycle by checking whether the previously selected `entity_id` still exists in `_monster_cache`. If `_monster_cache.has(previous_entity_id)` is false, the entity is dead (the system-level `monster_died` handler has removed it), and the tower runs a fresh targeting pass. If it returns true, the entry is used directly for range re-verification and targeting.

   **No Monster node references:** Towers store a transient `_current_target_id: int` for cycle-to-cycle continuity, not a Monster node reference. All target data is read from `_monster_cache`. This is consistent with Rule 14a ("Tower System holds no direct references to Monster entities"). The `_current_target_id` field is an internal tower entity field — not a public API and not exposed to other systems.

   **Sentinel value:** `_current_target_id` is initialized to **`-1`** (not `0`) at placement and reset to `-1` on each `wave_started`. Any value `< 0` means "no current target" — a fresh targeting pass is required. This sentinel is critical because `entity_id = 0` is a valid monster ID (the first monster spawned per mission carries id=0 per Rule 11a). Using `0` as the no-target sentinel would silently misidentify the first monster as "already acquired" at wave start.

19. **Projectile behavior when the in-flight target dies** (applies to Physical, Ranged, and Elemental archetypes only — Support towers use AURA and have no projectiles; see Rule 5a):
    - `HOMING` projectile: re-acquires the highest-priority target currently in range at the moment of target death. If no valid target exists in the re-acquisition pool, the projectile **self-destructs** (no damage, no detonation, no error).
      - **Re-acquisition architecture note:** The projectile entity does not run an independent targeting search. On detecting target death (target's `entity_id` absent from `_monster_cache` on the next polling frame — the Tower System does NOT subscribe to `monster_died`), the HOMING projectile calls the **Tower System's** `TowerSystem._get_best_target(tower_id, targeting_mode)` method (system-level, not per-tower). The Tower System evaluates the calling tower's targeting mode against the live `_monster_cache` and returns the best target's `entity_id` (or `-1` if no valid target exists). The projectile then steers toward the new target. Re-acquisition is always mediated by the Tower System singleton — the projectile never calls a per-tower method directly. This is architecturally necessary because `_monster_cache` is system-level state (Rule 14a); per-tower methods cannot own a cache they don't hold. The Tower System must expose `_get_best_target(tower_id: int, targeting_mode: String) → int` as an internal method (not a public API for other systems).
      - **Originating tower destroyed while projectile is in flight:** Before calling back, the projectile must check the originating tower's **`_is_destroyed: bool`** flag (an internal flag set to `true` synchronously when HP reaches 0, before `queue_free()` is called). The `_is_destroyed` flag provides a frame-synchronous signal that the tower has logically died, even if the node has not yet been freed from the scene tree. `is_instance_valid()` is not prohibited outright — it is superseded by `_is_destroyed` for this specific case: in Godot 4, `queue_free()` is deferred to the end of the frame, meaning `is_instance_valid()` still returns `true` on the same frame the tower is destroyed. Use `_is_destroyed` where frame-synchronous tower-death detection is required; `is_instance_valid()` remains valid for other null-safety uses. If `_is_destroyed` is `true`, re-acquisition is impossible — the projectile continues on its last trajectory toward the target's last-known position (no steering, no re-acquisition). If the original target is also dead (absent from `_monster_cache`), the projectile self-destructs immediately.
      - **Empty pool at wave end:** If `wave_completed` fires while a HOMING projectile is in flight and all monsters have despawned, the re-acquisition pool is empty. The projectile self-destructs immediately on the frame it polls an empty `_monster_cache`. No damage is dealt.
      - **One-frame ghost-flight (known approximation):** `monster_died` is CONNECT_DEFERRED (cache eviction trails one frame). A HOMING projectile polling mid-frame may see a dead target as still-alive for that frame, steering toward stale coordinates before the cache eviction runs. This is an accepted approximation — the projectile will self-destruct or re-acquire on the next polling frame. This edge case is not observable as a gameplay error (no damage is dealt to a dead monster; the projectile dissipates normally). Document as a known limitation; do not add a synchronous `_died_this_frame` set unless playtesting exposes visible artifact.
      - **Re-acquisition rate limit:** Re-acquisition is rate-limited to `max_reacquisitions_per_frame = 8` callbacks processed per frame. Projectiles that did not re-acquire this frame retry on the next frame. Priority: oldest in-flight projectiles get priority. This prevents a frame spike when many projectiles simultaneously lose the same target (e.g., 128 HOMING projectiles all re-acquiring on the frame a high-HP target dies). `max_reacquisitions_per_frame` is a Tuning Knob (see Tuning Knobs table).

   **Projectile pooling (implementation note):** Pool size must be calculated as `ceil(max_active_towers_homing × max_attack_speed × base_flight_time_sec × 3.0)`. `max_active_towers_homing` is a Tuning Knob (see Tuning Knobs table). **The `max_active_towers_homing = 20` anchor used in prior calculations is invalid — the grid allows 40–60+ towers, meaning peak HOMING concurrency can far exceed 20.** A subsequent `max_active_towers_homing = 32` default (yielding a 192-size pool) was also found undersized during the `/design-review` 2026-07-14 re-review: at a realistic 40-tower all-HOMING steady state the formula requires 240 (192 is 20% short), and at the knobs' own declared safe-range extremes (60 towers × 4.0 atk/sec × up to 2.0s flight time) it requires up to 1440. Because the spec requires exhaustion to fail silently (no error, no damage — see Rule 19's empty-pool case), an undersized pool causes **silent dropped shots**, a gameplay-visible correctness bug, not just a memory-tuning question. **Resolved: `max_active_towers_homing = 60`** — anchored to the grid's own stated upper bound rather than a provisional guess, so the pool cannot exhaust under any legal board state at the documented `base_flight_time_sec = 0.5s` default. This gives `ceil(60 × 4.0 × 0.5 × 3.0) = 360` — update `projectile_pool_size` default to **360** (see Tuning Knobs; still within its declared safe range of 64–512). If `base_flight_time_sec` is later tuned above 0.5s, `projectile_pool_size` must be recalculated from this same formula — it is not independently safe at its upper end against a 60-tower board. Projectiles **must be pooled** — instantiate a fixed-size pool at mission start and recycle on dissipation/impact. Spawning and freeing projectile nodes per-shot at this frequency causes per-frame allocation spikes that degrade frame timing on lower-end hardware. BALLISTIC and BEAM projectile types should follow the same pooling pattern. **The exact pooling architecture (fixed array vs. free list vs. Godot's built-in node pool) is deferred to the engine-level implementation spec (TAD). This GDD mandates pooling as a requirement; it does not specify the mechanism.**
    - `BALLISTIC` / `BEAM` projectile: continues to the target's last-known position. If the target is dead on arrival, no damage is dealt. AoE weapons with `BALLISTIC` tag still detonate at the target position and may damage nearby enemies.

20. Damage is resolved at the moment the projectile logically arrives (hitscan/beam: immediate; projectile: on contact). Visual attack animations are cosmetic and do not gate damage delivery.

20a. At attack-cycle fire time, the Tower System determines `is_armored: bool` for the selected target and includes it in the `tower_attacked` payload. `is_armored` is `true` when the target's `MonsterResource.archetype_tag == &"armored"`, and `false` for all other values (including empty StringName). **Implementation note:** the recommended approach is to cache `archetype_tag: StringName` in `_monster_cache` alongside `grid_cell`, `path_step_index`, and `current_hp`, populating it when handling `monster_spawned` (which provides `monster_id` for resource lookup). This avoids a per-shot direct MonsterResource read during the attack cycle while respecting EventBus Core Rule 1 (no direct system-to-system calls — resource file reads are data access, not system calls, but caching eliminates the per-frame cost either way). Hero attacks are not routed through `tower_attacked` and are not affected by `is_armored` — hero damage mitigation is never applied.

#### Group 6: Tower HP and Destruction

21. **Monsters follow their path and do not attack towers.** Only boss enemies (`[BOSS]` tagged) may deliberately target and attack towers. Non-boss enemies that collide with a tower cell during pathing do not deal damage to it.

22. Towers use **pure HP with no mitigation** for MVP. Boss attacks deal flat damage directly to tower HP. The damage pipeline is: Monster System emits `boss_tower_attack_attempted` (payload: `boss_entity_id`, `target_tower_id`, `base_damage`, `wave_id`) → Tower System subscribes and applies `base_damage` directly to the tower's current HP. After each damage application (if the tower survives), the Tower System emits `tower_damaged` (payload: `tower_id: int`, `damage_dealt: float`, `current_hp: float`, `max_hp: float`). This event is the observable HP proxy for the Mission HUD (which must not poll HP directly per Rule 25) and for test verification of ACs 14 and 16.

23. Tower HP **resets to its Foundation-defined maximum** at the end of each wave (`wave_completed` received). HP is not persistent between waves. A tower that survives a wave at 1 HP begins the next wave at full HP.

   **HP reset is a silent internal state change — no dedicated event is emitted.** The Mission HUD infers HP restoration from `wave_completed` combined with `tower_wave_summary`: on receipt of `wave_completed`, each tower emits `tower_wave_summary` (see below) with a `max_hp: float` field that the HUD uses to reconstruct full HP. This is the authoritative mechanism — the HUD must not attempt to read `max_hp` from Foundation component data directly (no direct system references) and must not poll Tower System state (Rule 25). For towers that took boss damage during the wave, the HUD may already know `max_hp` from the `tower_damaged` payload — `tower_wave_summary.max_hp` confirms the same value. For towers that took **no damage**, `tower_wave_summary.max_hp` is the only event-sourced path to this value. The Tower System does not expose a public HP polling API (Rule 25) and does not emit a `tower_hp_reset` event.

   **Post-wave authorship summary:** At each `wave_completed`, after HP resets, the Tower System emits `tower_wave_summary` once **per active tower** (towers in `IDLE` state after the reset). This event exposes per-tower engagement data for the Mission HUD's "Endless Theorist" feedback surface.

   **`tower_wave_summary` event contract** (Tower System owns this event): The payload uses a **`TowerWaveSummary` typed Resource subclass** (Core Rule 4 compliance). Fields:
   | Payload field | Type | Description |
   |---------------|------|-------------|
   | `tower_id` | int | Identifies the tower |
   | `max_hp` | float | Tower's full HP value (Foundation `hp_base × tier_multiplier`). Required so the Mission HUD can infer HP restoration for towers that took **no** boss damage this wave (for which no `tower_damaged` event fired — `max_hp` is otherwise inaccessible via events). |
   | `shots_fired` | int | Number of successful attacks this wave (timer expired + valid target → fired) |
   | `damage_dealt` | float | Total weapon damage delivered this wave (excludes Power component DoT) |
   | `idle_ticks` | int | Number of attack timer expirations where no valid target was found (tower was in range but no enemy in cone, or no enemies in range at all) |
   | `aura_applications_this_wave` | int | **Support archetype only.** Number of times `tower_aura_pulse` fired during this wave. 0 for all non-Support archetypes. Required so the Mission HUD can surface aura activity for Support towers — without this field, the Authorship feedback surface has no way to show that a Support tower contributed during the wave. |
   | `scatter_target_cycle` | Dictionary[int, int] | **SCATTER Focus only.** Maps `entity_id → hit_count` for all targets that received at least one shot from this tower this wave. Empty Dictionary for non-SCATTER towers. Provides the post-wave authorship record for SCATTER's cycle pattern — the player can see which targets were hit how many times. |

   The Mission HUD GDD owns the display logic for this data. The Tower System only fires the event — no HUD decisions live here. Counters (`shots_fired`, `damage_dealt`, `idle_ticks`, `aura_applications_this_wave`) are accumulated during `WAVE_ACTIVE` and reset at the start of each new wave on `wave_started`.

24. When tower HP reaches 0, the tower enters `DESTROYED`:
    - The Tower System calls `Grid.remove_tower(tower_id)`.
    - `tower_destroyed` is emitted (payload: `tower_id`, `grid_position`, `archetype`, `footprint: Vector2i`). *(`footprint` added during `/design-review` 2026-07-14 — closes a cross-GDD gap: `event-bus.md` and `mission-hud.md`'s PC-3 both already required this 4th field.)*
    - The tower entity is removed from the scene.
    - The four component items are flagged **`damaged`** and returned to the player's component inventory at mission end (VICTORY or DEFEAT). A `damaged` component **cannot be equipped to a tower** until it is repaired at the Sanctuary. Repair costs a Sanctuary resource defined by `damaged_component_repair_cost` (a tuning knob, per tier). This is the **lasting progression consequence of tower destruction** — the player recovers their components but must invest resources to restore them before the next mission. **At mission-end processing**, Tower System emits `tower_component_returned(tower_id, item_id, item_type, damaged=true)` once per returned component (four emissions per destroyed tower) — same event and division of responsibility as Rule 13's voluntary-removal path (Tower emits `tower_component_returned`; Inventory subscribes and emits `item_added(metadata={"damaged": true})` itself, per ADR-0016). *(Added during `/design-review` — same cross-GDD gap as Rule 13's voluntary-removal path: the event this GDD's own Edge Cases and Dependencies table assumed existed was never actually specified.)*

25. HP is an internal value. The Mission HUD may display an HP bar for towers under active boss attack, but this is a HUD concern driven by events — the Tower System does not expose a public HP polling API.

25a. **`current_wave_id` — testable wave tracking:** The Tower System maintains an internal `_current_wave_id: int` counter, initialized to 0 at mission start and incremented each time `wave_started` fires. Tower entities expose `current_wave_id: int` as a **read-only** property accessible to GUT test suites for verifying wave-id staleness logic (AC: "wave_id staleness test fixture"). This property is not part of the public cross-system API and must not be consumed by other game systems.

25b. ~~**Injectable RNG for SCATTER targeting**~~ — **RETIRED in Revision 8.** SCATTER targeting is now a deterministic round-robin cycle (Rule 15 — D1-A decision). No RNG is used. `TowerInstance` does not require an injectable RNG constructor argument. GUT tests verify SCATTER determinism via `_scatter_index` counter behaviour, not seed injection.

---

### States and Transitions

| State | Entry Condition | Behavior | Exit Condition |
|-------|-----------------|----------|----------------|
| `IDLE` | Placement confirmed (`tower_placed` emitted); or `wave_completed` received while alive | Entity exists on grid; HP at max; targeting inactive; awaits `wave_started` | `wave_started` → `TARGETING`; player removes tower → entity destroyed (emits `tower_removed`) |
| `TARGETING` | `wave_started` received; or current target dies / exits range while in `ATTACKING` | Evaluates targeting priority **on attack-timer expiry only**; loops if no valid target found; returns to waiting for next timer expiry | Valid target acquired → `ATTACKING`; HP reaches 0 → `DESTROYED`; `wave_completed` → `IDLE` |
| `ATTACKING` | Valid target acquired in `TARGETING` | Fires at target on attack-timer expiry; emits `tower_attacked`; re-evaluates target **each attack cycle** (timer expiry) | Target dies or exits range → `TARGETING`; HP reaches 0 → `DESTROYED`; `wave_completed` → `IDLE` |
| `DESTROYED` | HP reaches 0 | Grid occupancy cleared; `tower_destroyed` emitted; entity freed | Terminal |

**Support archetype state exceptions:**

| State | Support behavior | Difference from standard |
|-------|-----------------|--------------------------|
| `TARGETING` | On attack-timer expiry, transitions immediately to `ATTACKING` without requiring a valid monster target. | Standard archetypes wait in `TARGETING` until a valid target is found. Support bypasses this check entirely. |
| `ATTACKING` | Emits `tower_aura_pulse` unconditionally; no projectile fired; no `_current_target_id` set. | Standard archetypes set `_current_target_id` and require a live entity. Support emits the pulse event with no entity reference. |

All other state transitions (IDLE → TARGETING on `wave_started`, ATTACKING/TARGETING → IDLE on `wave_completed`, DESTROYED on HP = 0) apply identically to Support.

**Notes:**
- Before placement is confirmed, the tower preview is a UI cursor element — no game entity and no `tower_id` exist until `Grid.place_tower()` returns `OK`.
- HP resets to maximum on transition back to `IDLE` from `wave_completed`. It does not reset on entry from initial placement.
- A future `SUPPRESSED` state (boss disrupting attack rate) may be added for boss encounter design. Not in MVP scope.

---

### Interactions with Other Systems

| System | Direction | What flows | When |
|--------|-----------|------------|------|
| **Grid System** | Tower writes; Tower reads for validation | `is_footprint_placeable()` → validation; `place_tower()` → occupancy write; `remove_tower()` → occupancy clear; `world_to_cell()`, `cell_to_world()` → cursor snapping and node positioning | Placement, removal, placement preview |
| **EventBus** | Tower owns 11 events; subscribes to 9 | Owns: `tower_placed`, `tower_removed`, `tower_destroyed`, `tower_component_equipped`, `tower_attacked`, `pre_placement_perk_activated`, `tower_damaged`, `tower_aura_pulse`, `tower_wave_summary`, `tower_component_returned`, `resources_changed` (placement-cost debit — **added during `/design-system` 2026-07-14**, shared event also emitted by Resource Economy for income; Tower is the debit-side emitter). Subscribes: `mission_phase_changed`, `wave_started`, `wave_completed`, `boss_tower_attack_attempted`, `monster_spawned` (cache init), `monster_cell_entered` (cache position update), `monster_died` (cache hygiene), `monster_damage_taken` (cache HP update), `monster_breached` (cache hygiene) | Continuously during mission |
| **Hero System** | Downstream — Hero subscribes | `tower_placed` and `tower_removed` / `tower_destroyed` (with `archetype` payload) trigger Hero's Tower Affinity recalculation and Tower-Synced Class proximity tracking | Every placement and removal |
| **Resource Economy** | Upstream — Resource Economy reads directly, 2026-08-17 | `TowerSystem.get_placed_tower_slot_tally()` — a new pull-based read (method call via `&"tower_system"` group discovery, not an EventBus signal), used only at `MISSION_COMPLETE` to compute `resource-economy.md` Formula 6's Mission-End Building Material Surplus Grant. TowerSystem has no reciprocal awareness of this — a pure one-directional query, same shape as `tower_assembly.gd`'s own `get_assembled_blueprint()`/`get_all_assembled_tower_ids()` public query methods | Once, at `MISSION_COMPLETE` |
| **Constellation System** | Bidirectional via EventBus | Tower fires `tower_placed` / `tower_removed` / `tower_destroyed` → Constellation rechecks patterns. Tower subscribes to `constellation_activated` / `constellation_deactivated` to apply / remove pattern bonuses | Every placement, removal, and destruction |
| **Monster System** | Upstream — Monster owns boss attack event | `boss_tower_attack_attempted` (payload: `boss_entity_id: int`, `target_tower_id: int`, `base_damage: float`, `wave_id: int`) → Tower System applies `base_damage` directly. *(Corrected 2026-07-15: this row previously also described `tower_attacked` carrying `is_siege: bool` for "shield penetration" — the T4 Siege mechanic was struck this session; see the T4 Boss-Lane Identity section. `tower_attacked` no longer carries any siege-related field, and the Monster System has no shield-penetration concept to resolve.)* | During `WAVE_ACTIVE` when a boss targets a tower |
| **Mission HUD** | Downstream — HUD subscribes | `tower_placed`, `tower_removed`, `tower_destroyed`, `tower_damaged`, `pre_placement_perk_activated`, `tower_aura_pulse`, `tower_wave_summary` | Continuously during mission — **corrected 2026-07-14**: floating damage numbers are sourced from Damage & Status's `monster_damage_taken` (which carries `amount`/`is_crit`/`hero_bonus_tier`), not `tower_attacked` (the raw attack-fired event, no amount/crit data). See `design/gdd/mission-hud.md`'s Detailed Rules for the full event list this GDD's row here previously omitted. |
| **Save & Persistence** | Tower exposes save/restore API | Saves: `unlocked_variants`, `component_upgrade_levels`, `sanctuary_loadouts`. Does NOT save: in-mission placement, runtime IDs, HP. restore_order: 23 | Session start/end |
| **Tower Mastery** | Downstream — Tower Mastery reads Grid directly | Tower Mastery tracks hero proximity to occupied cells via Grid read API. Tower System does not call Tower Mastery | During `WAVE_ACTIVE` and `INTERMISSION` |

**Open Question — EventBus catalogue update required:**
The following changes must be reconciled in the EventBus GDD before implementation:
- `tower_placed` payload: add `archetype: String` and `footprint: Vector2i`
- `tower_removed`: register as a new event (currently absent)
- `boss_tower_attack_attempted`: register as a new event (owned by Monster System)

## Formulas

### Formula 1: Tower DPS (Damage Per Second)

The primary output metric for a tower's offensive contribution.

`tower_dps = weapon_damage × attack_speed × tier_dps_multiplier`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base weapon damage | `weapon_damage` | float | 8.0–120.0 | Raw damage stat on the Weapon component. Tier breakpoints: Early-game 8–25, Mid-game 25–60, Late-game 60–120. *(Provisional — calibrate against Monster HP once Monster System GDD is written.)* |
| Attack speed | `attack_speed` | float | 0.5–4.0 | Attacks per second. Low (0.5–1.0) = slow heavy-hitters; high (2.0–4.0) = rapid light-hitters. |
| Tier DPS multiplier | `tier_dps_multiplier` | float | 1.0–4.0 | Foundation upgrade tier bonus to DPS output. Tier 1 = 1.0×, Tier 2 = 1.6×, Tier 3 = 2.4×, Tier 4 = 4.0×. Defined on the Foundation component alongside `tier_multiplier` (HP). |
| Tower DPS | `tower_dps` | float | 4.0–1920.0 | Instantaneous damage per second under continuous fire. |

**Output Range:** 4.0–1920.0 theoretical base (standard targets), rising to **2400.0** with a maxed `DAMAGE_BOOST` pre-placement perk (`1920 × 1.25`). In normal play (T1–T3): 12–576. Realistic assembled mid-game range: 20–320. The 1920 base ceiling requires a Tier 4 Foundation with max-stat Weapon and narrow-cone Focus. **Boss DPS ceiling: 120.0 × 4.0 × 4.0 × 2.0 = 3840.0** (T4 + `tier_boss_dps_multiplier=2.0` at max Weapon — applies against `[BOSS]`-tagged targets only), rising to **4800.0** with a maxed `DAMAGE_BOOST` perk. *(Corrected 2026-07-15 — `/design-review` 2026-07-14 flagged these ceilings as stale, not accounting for `DAMAGE_BOOST`'s up-to-25% multiplier; confirmed non-load-bearing elsewhere in this document — no other formula assumed the old 1920/3840 figures as a hard cap — so this was purely a missing-case documentation gap.)*

**Design target** *(Provisional — calibrate against final Monster HP values and playtest data before locking.)*: At mid-mission (8–12 towers on field), aggregate tower DPS should account for ~65% of wave-clearing damage. At 10 Tier 2 towers averaging 112.0 DPS (70 × 1.6) = 1120 combined DPS. Against 25 monsters with ~175 HP each, that clears a wave in roughly 3–5 seconds of focused fire, requiring the hero to close gaps on remaining targets. Calibrate monster HP upward if faster clears undermine hero contribution.

**Archetype note:** Archetype applies no additional damage multiplier in this formula beyond what the tier multiplier provides. Archetype-specific power comes from Power component on-hit effects and constellation bonuses.

**Tier coupling intent:** `tier_dps_multiplier` is specifically separate from `tier_multiplier` (HP) to allow independent tuning of survivability vs. lethality scaling. The multipliers {1.0, 1.6, 2.4, 4.0} are calibrated against `tier_cost_factor` values {1.0, 1.5, 2.0, 4.0}, producing the following DPS/cost ratios: **T1=1.00, T2=1.07, T3=1.20, T4=1.00**. T4 is **not** an efficiency apex — it matches T1's DPS/cost ratio. T4 is a **specialist ceiling tier**: it delivers the highest raw DPS for boss-lane scenarios where output ceiling is the priority, but costs 4× as much as T1 for only 4× the DPS (no efficiency premium). T3 is the efficient mid-game choice. T1 and T4 share DPS/cost parity at opposite ends of the budget spectrum. This non-monotone curve is intentional: players invest in T4 for raw capability in boss lanes, not for economy.

**T1 and T2 are intentional budget-gating tiers (design decision — D3-A, Revision 8):** T1 (DPS/cost=1.00) and T2 (DPS/cost=1.07) have no strategic identity beyond cost. T1 is the cheapest option; T2 occupies a modest mid-point. Neither tier has a mechanical niche that T3 cannot fill more efficiently. Players use T1/T2 because they cannot yet afford T3, not because T1/T2 are strategically superior in any configuration. This is intentional budget-gating: early waves are served by affordable T1/T2 builds; T3 becomes accessible by mid-mission; T4 is a late-investment boss-lane commitment. The design accepts no strategic differentiation between T1 and T2. Content designers should not try to create T1/T2 "meta builds" — the economy deliberately funnels players toward T3 as soon as resources allow.

*(Reconciled against `game-pillars.md` Pillar 2, 2026-07-15 — `/review-all-gdds` game-design-holism pass flagged "no mechanical niche" as textually matching Pillar 2's anti-pattern, "features that add options without adding meaningful decisions." On inspection this is not the same axis: Pillar 2's anti-pattern targets features with no cross-system synergy hooks — T1/T2 towers fully participate in that web (identical 4-slot component structure, identical constellation/archetype interactions, identical EventBus contracts as T3/T4). What T1/T2 lack is a distinct **combat-efficiency** niche, not a synergy niche. The real decision D3-A preserves is economic and temporal — which tier can you afford right now, and when do you upgrade — which is itself a meaningful decision under Pillar 2's own design test ("does discovering it feel earned, not arbitrary?": yes, affording T3 is an earned economic milestone, not an arbitrary unlock). No change made to the design; this note exists so a future reader doesn't mistake D3-A for an unexamined anti-pattern violation.)*

**T4 Boss-Lane Identity — formula multiplier:**

*(Corrected 2026-07-15 — the T4 "Siege" property described in prior revisions of this document, which penetrated a Monster System "boss damage phase shield," is struck: no such shield mechanic exists anywhere in monster.md, and no design pressure currently requires one. T4's boss-lane identity stands on `tier_boss_dps_multiplier` alone, which is fully specified and self-contained. If a boss-phase-shield mechanic is designed in the future, a Siege-style penetration property can be reintroduced against it at that time.)*

**Framing note (added 2026-07-15 — `/review-all-gdds` game-design-holism pass):** T4's value proposition should be read as **"shortens boss-phase duration and reduces hero exposure risk,"** not as **"lets towers solo the boss without Hero involvement."** `game-concept.md` Core Rule 1 already establishes that tower-only strategies cannot clear high-value targets — the Hero's 150% boss damage bonus (`hero_damage_bonus_multiplier`, D&S-owned) makes Hero engagement structurally mandatory against any BOSS regardless of tower investment. T4's 3.3× boss-DPS ceiling over T3 doesn't change that requirement; it accelerates the fight the Hero must still finish, reducing the number of attack cycles the Hero is exposed to a boss's own counter-damage. This framing also explains T4's narrow payoff window (the boss telegraph makes the final wave fully forecastable — T4 is a scripted last-Intermission purchase, not an emergent mid-wave read) without treating that narrowness as a design flaw: a boss-lane investment that pays off exactly once, on cue, at the one wave built to test the whole build (`game-concept.md` Core Rule 3), is consistent with the "vindication" pillar this GDD is implementing — the payoff is supposed to be legible and earned, not a surprise.

**`tier_boss_dps_multiplier: float = 2.0`** — T4 Foundation components deal 2× DPS against boss entities (enemies with the `[BOSS]` tag). Standard DPS formula applies against non-boss enemies; the multiplier only activates when the current target is a `[BOSS]`-tagged entity. The effective boss DPS formula is:

`tower_boss_dps = weapon_damage × attack_speed × tier_dps_multiplier × tier_boss_dps_multiplier`

At T4 max Weapon: `tower_boss_dps = 120 × 4.0 × 4.0 × 2.0 = 3840`. At T3 max Weapon: `tower_boss_dps = 120 × 4.0 × 2.4 × 1.0 = 1152`. T4 boss DPS ceiling is 3.3× higher than T3 against bosses — this is the mechanical justification for the T4 cost.

| Tier | `tier_boss_dps_multiplier` | Notes |
|------|---------------------------|-------|
| T1 | 1.0× | No boss multiplier |
| T2 | 1.0× | No boss multiplier |
| T3 | 1.0× | No boss multiplier |
| T4 | **2.0×** | Boss-lane specialist |

`tier_boss_dps_multiplier` is defined on the Foundation component schema and must be validated at load time: T1/T2/T3 must have value `1.0`; T4 must have value `2.0`. Values outside {1.0, 2.0} are load-time errors.

**Load-time validation:** `weapon_damage` must be validated in range [8.0, 120.0]. `attack_speed` must be validated in range [0.5, 4.0] — the authoritative load-time constraint. The Tuning Knob safe range [0.3, 6.0] is for balance experimentation only and does not apply to shipped component data; only values within [0.5, 4.0] are permitted in content. `tier_dps_multiplier` must be one of the discrete set {1.0, 1.6, 2.4, 4.0} — any value outside this set must raise a load-time error. The minimum possible DPS output is 8.0 × 0.5 × 1.0 = 4.0; no valid component combination produces a DPS below 4.0.

**Implementation note (2026-08-16):** `tier_boss_dps_multiplier` was fully specified above and load-validated since this GDD's original authoring, but a real pre-existing bug meant it was never actually multiplied into any live damage computation — `TowerSystem._try_attack()` never checked whether its target was `[BOSS]`-tagged, so every T4 tower dealt standard (non-boss) DPS even against bosses in real gameplay. Fixed as part of Tower Stats System Phase 1 (see below) — this section's formula is now what the code actually computes, not aspirational.

### Formula 1b: Per-Hit Damage Resolution (Tower Stats System Phase 1, player-requested 2026-08-16)

Formula 1's `tower_dps` is a rate (damage per second under continuous fire). Phase 1 adds per-hit-instance stat rolls that modify each individual attack's damage on top of that rate — expected DPS over many hits still averages toward Formula 1's number scaled by these factors' expected values, but any single hit can vary.

**Resolution order, computed once per attack in `TowerSystem._try_attack()`:**

```
base_damage   = weapon_damage × tier_dps_multiplier
is_crit       = random_roll() < crit_chance
crit_mult     = crit_multiplier if is_crit else 1.0
vs_tag_mult   = bonus_damage_vs_tags[target.archetype_tag] if present else 1.0
boss_mult     = tier_boss_dps_multiplier if target is [BOSS]-tagged else 1.0
damage        = base_damage × crit_mult × vs_tag_mult × boss_mult
resistance    = target.elemental_resistances[element] if element != "" and present else 0.0
damage        = damage × (1.0 − resistance)
```

`armor_penetration` is applied downstream of this (Damage & Status's job, not Tower System's — see `design/gdd/damage-status.md`'s armored-mitigation formula), since armored-mitigation has always been D&S-owned.

**Status proc chance:** independently, `status_proc_chance` is rolled once per attack; on failure the Power effect (`effect_type`/`effect_value`/`effect_duration`) is withheld for that hit (forwarded as `effect_type = ""`, indistinguishable on the wire from "no Power component equipped" — see `design/gdd/event-bus.md`'s `tower_attacked` entry).

**Backward compatibility:** every new field defaults to a value that reproduces pre-Phase-1 behavior exactly (`crit_chance=0.0`, `armor_penetration=0.0`, `status_proc_chance=1.0`, `bonus_damage_vs_tags={}`) — no existing authored blueprint's effective damage changes unless a new stat is explicitly set on it. The documented DPS ceilings above (1920.0 standard / 3840.0 boss) are unaffected by default-valued Phase 1 fields; a tower with non-zero `crit_chance`/`bonus_damage_vs_tags` raises its *effective* (expected-value) ceiling further, which is intentional headroom for Phase 1 content, not a correction to the existing figures.

**Example:** Crossbow Weapon component (`weapon_damage = 35.0`, `attack_speed = 2.0`) on a Tier 2 Foundation (`tier_dps_multiplier = 1.6`):
`tower_dps = 35.0 × 2.0 × 1.6 = 112.0`
Against a 175 HP monster: time-to-kill ≈ 1.56 seconds under continuous fire.

---

### Formula 1c: Splash Damage Falloff (Phase 2 — Splash, 2026-08-23)

Applies only when `aoe_radius_cells > 0` (BALLISTIC weapons). The primary target (found by `_find_lowest_hp_target()`, distance 0) always takes full Formula 1b damage — this formula covers every *other* monster within `aoe_radius_cells` of the primary target's cell, found via Chebyshev distance (consistent with Formula 2's own range check and Grid's `get_occupied_cells_in_radius()` convention):

```
distance          = max(|monster.cell.x − primary.cell.x|, |monster.cell.y − primary.cell.y|)   # Chebyshev, 1..aoe_radius_cells
falloff_fraction  = distance / aoe_radius_cells
splash_multiplier = lerp(1.0, MIN_SPLASH_FALLOFF, falloff_fraction)
splash_damage     = damage (Formula 1b's result) × splash_multiplier
```

At `distance = 1` (adjacent to primary), a splash target takes close to full damage; at `distance = aoe_radius_cells` (the outer edge), it takes exactly `MIN_SPLASH_FALLOFF` of the primary's damage. `MIN_SPLASH_FALLOFF` is a Tuning Knob (below), default 0.40.

**Status effects do not splash.** `effect_type`/`effect_value`/`effect_duration` (and the `status_proc_chance` roll) apply only to the primary target — splash-hit monsters take damage only, forwarded with `effect_type = ""` regardless of what the primary target rolled. This is a deliberate scope boundary, not an oversight: unbounded status-effect application across N splash targets per shot would need its own balance pass (stacking, duration refresh across multiple simultaneously-afflicted monsters) that this pass does not attempt.

**Crit/vs-tag/boss/resistance multipliers are NOT re-rolled per splash target** — `damage` going into this formula is the primary target's already-fully-resolved Formula 1b result (one crit roll per attack, not per monster hit). A splash target's own `archetype_tag`/`elemental_resistances`/boss status are not separately consulted; every monster in the blast radius takes a fraction of the *same* resolved damage number.

**Zero splash targets** (no other monster within radius): the primary target's own hit resolves normally; no splash-related work occurs. This is the pre-existing zero-target-detonation edge case (Edge Cases → Attack Execution) — unaffected by this formula.

**Example:** a `aoe_radius_cells = 3` BALLISTIC tower resolves 80.0 damage against its primary target. A second monster at Chebyshev distance 1 takes `80.0 × lerp(1.0, 0.40, 1/3) = 80.0 × 0.80 = 64.0`. A third monster at distance 3 (the edge) takes `80.0 × 0.40 = 32.0`.

---

### Formula 2: Tower Effective Range

Range is a compound boolean check — both conditions must be true for a target to be valid. Range is measured in **grid cells using Chebyshev distance** (consistent with the hero's proximity radius system).

**Effective range (with cone bonus):**

`effective_range = attack_range_cells + cone_range_bonus`

where `cone_range_bonus` is determined by `cone_half_angle`:
- `cone_half_angle ≥ 90°`: `cone_range_bonus = 0`
- `45° ≤ cone_half_angle < 90°`: `cone_range_bonus = +1`
- `cone_half_angle < 45°`: `cone_range_bonus = +2`

This creates a meaningful tradeoff: a wider cone covers more directions; a narrower cone reaches further along a lane. A 22.5°-cone artillery tower can cover 2 cells beyond its `attack_range_cells` base, while an omnidirectional tower covers only its stated range. **This makes tower facing direction a genuine strategic choice, not a cosmetic one.**

`target_in_range = (cell_distance ≤ effective_range) AND (angle_to_enemy ≤ cone_half_angle)`

**Range sub-formula (Chebyshev distance):**

`cell_distance = max(|enemy_col − tower_col|, |enemy_row − tower_row|)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Attack range | `attack_range_cells` | int | 1–8 | Maximum Chebyshev cell distance for target acquisition. Defined by the Focus component. |
| Enemy column | `enemy_col` | int | 0–15 | Enemy's current grid cell column. |
| Enemy row | `enemy_row` | int | 0–11 | Enemy's current grid cell row. |
| Tower column | `tower_col` | float | 0–15.5 | Tower's range anchor column. **For 1×1 towers:** integer cell column. **For 2×2 towers:** centroid of the footprint = `top_left_col + 0.5` (half-cell offset from top-left). Computed once at placement and stored. |
| Tower row | `tower_row` | float | 0–11.5 | Tower's range anchor row. **For 1×1 towers:** integer cell row. **For 2×2 towers:** centroid = `top_left_row + 0.5`. |
| Cell distance | `cell_distance` | float | 0–15 | Chebyshev distance from tower centroid to enemy cell center. For 2×2 towers: `max(|enemy_col − (top_left_col + 0.5)|, |enemy_row − (top_left_row + 0.5)|)`. Round half-up when comparing to integer `effective_range`. Maximum on 16×12 grid: ~15. |
| Tower facing direction | `tower_facing_dir` | Vector2 (unit) | — | Fixed direction the tower faces, derived at load time from the Focus component's `facing_direction` compass enum (N/NE/E/SE/S/SW/W/NW). Converted to a normalized world-space vector once at placement. **Never updated during TARGETING or ATTACKING states.** For 360° cone towers (`cone_half_angle = 180°`), this value is ignored — the cone check always passes. |
| Angle to enemy | `angle_to_enemy` | float | 0.0°–180.0° | Angle between `tower_facing_dir` and the normalized vector from the tower's anchor point (centroid for 2×2; cell center for 1×1) to the enemy cell center. |
| Cone half-angle | `cone_half_angle` | float | 22.5°–180.0° | Half the attack arc width. 180° = omnidirectional (no cone check). Minimum 22.5° enforced at load time (values below this minimum are load-time errors). |

**Output Range:** Boolean. `attack_range_cells` is clamped to [1, 8] in component data. `effective_range = min(9, attack_range_cells + cone_range_bonus)`. **Range cap: effective_range is capped at 9 cells regardless of cone bonus.** At `attack_range_cells = 8` (maximum artillery) with a narrow cone, the cap applies: `min(9, 8 + 2) = 9`. This prevents a single corner-placed artillery tower from covering the majority of the 16×12 grid and preserves meaningful placement decisions even at maximum range. The cap is enforced in the targeting logic, not in component data — `attack_range_cells = 8` is still valid; the formula's output is capped.

**Cap interaction at maximum range (content designer warning):** A tower with `attack_range_cells=8` and `cone_half_angle < 45°` receives `cone_range_bonus=+2` for a theoretical `effective_range=10`, immediately capped to 9. This is **identical** to `attack_range_cells=7` with the same cone (`7 + 2 = 9`). The 8th range cell is effectively a wasted stat point in narrow-cone configurations. A RANGE_BOOST perk (+1 or +2 cells from `perk_power`) is similarly nullified at `attack_range_cells=8` — the perk benefit is partially or fully absorbed by the cap. **Do not pair `attack_range_cells=8` with `cone_half_angle < 45°` in component data — use `attack_range_cells=7` instead.** Wide-cone towers (≥ 90°) are unaffected because `cone_range_bonus=0`; the cap never triggers for them at any `attack_range_cells` value.

**Range tier reference for component authors:**

| Tier | `attack_range_cells` | Typical archetype |
|------|---------------------|-------------------|
| Short | 1–2 | Physical / melee |
| Medium | 3–4 | Standard ranged |
| Long | 5–6 | Elevated / ballistic |
| Artillery | 7–8 | Cross-lane; narrow cone recommended |

**Cone and range independence:** The two conditions are joined by AND with no formula interaction between them. There is no "cone-adjusted range" calculation.

**Example A — wide cone:** Frost tower at cell (8, 6), facing south, `attack_range_cells = 4`, `cone_half_angle = 90°`. Enemy at cell (10, 9):
- `cone_range_bonus = 0` (90° ≥ 90°) → `effective_range = 4`
- `cell_distance = max(|10−8|, |9−6|) = max(2, 3) = 3` → within range ✓
- Angle to enemy ≈ arctan(2/3) ≈ 34° → within 90° cone ✓
- `target_in_range = true`

**Example B — narrow cone gets range bonus:** Sniper tower at cell (8, 6), facing south, `attack_range_cells = 4`, `cone_half_angle = 30°`:
- `cone_range_bonus = +2` (30° < 45°) → `effective_range = 6`
- Enemy at cell (8, 11) (Chebyshev distance = max(0, |11−6|) = 5, directly south): `target_in_range = (5 ≤ 6) AND (0° ≤ 30°) = true`
- Same enemy against the wide-cone tower: `effective_range = 4`, distance = 5 → out of range ✗ (cell (8,12) was out-of-bounds; row 11 is the valid southern limit on a 16×12 grid)

---

### Formula 3: Tower HP

`tower_max_hp = hp_base × tier_multiplier`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base HP | `hp_base` | float | 80.0–400.0 | HP value on the Foundation component at Tier 1. |
| Tier multiplier | `tier_multiplier` | float | 1.0–2.5 | Foundation upgrade tier. Tier 1 = 1.0×, Tier 2 = 1.5×, Tier 3 = 2.0×, Tier 4 = 2.5×. |
| Tower max HP | `tower_max_hp` | float | 80.0–1000.0 | Full HP restored at the start of each wave. |

**Output Range:** 80–1000. Floor (80): Tier 1 Foundation with minimum base HP. Ceiling (1000): Tier 4 fully upgraded.

**Boss damage calibration** *(Provisional — validate against Monster System GDD boss damage formula before implementation. Do not treat these numbers as authoritative until cross-referenced.)*: The Monster GDD specifies two boss tiers: early-wave bosses (base_damage 15–25, wave-scaled) and final-wave bosses (base_damage **55–80**, wave-scaled — **corrected 2026-07-15, `/review-all-gdds`**: was still 40–80 here after Monster GDD's own `/design-review` narrowed the final-wave floor from 40 to 55 on 2026-07-15 to fix a boundary failure at wave 5). At Wave 8 max scale (×1.7): final boss deals ~136 HP/hit at maximum. At the earliest legal final-wave point (wave 5, base_damage=55, ×1.40): ~77 HP/hit. Against a Tier 1 minimum-HP tower (80 HP): expect 1 hit destruction at the high end. **A Tier 1 minimum-HP tower should expect 1–2 hits from a final-wave boss; a Tier 2 tower (min 120 HP) should expect 1 hit. Tier 3–4 towers are the viable boss-lane configurations.** Calibrate `hp_base` minimums with this in mind — the Tuning Knob target for Tier 1 `hp_base` should be raised to at minimum 120 in balance design. *The Monster System GDD owns the exact `boss_attack_damage` scaling formula; Tower System HP tiers must be calibrated against those numbers.*

**HP-efficiency counter-balance:** DPS/cost ratios (see Formula 1) are non-monotone — T4 matches T1's efficiency at 1.00. HP/cost ratios decline more steeply, with T4 taking a significant penalty. Using `base_cost=20`, normalized to T1=1.00:
- T1: `hp_scale=1.0`, `cost_scale=1.0` → HP-efficiency = **1.00**
- T2: `hp_scale=1.5`, `cost_scale=1.5` → HP-efficiency = **1.00** (neutral)
- T3: `hp_scale=2.0`, `cost_scale=2.0` → HP-efficiency = **1.00** (neutral)
- T4: `hp_scale=2.5`, `cost_scale=4.0` → HP-efficiency = **0.625** (37.5% worse per gold)

T4 towers provide the highest raw DPS ceiling but the worst HP/cost ratio of any tier. A Tier 4 foundation costs 4× as much as Tier 1 but only provides 2.5× the HP — spending on T4 for survivability alone is a poor trade. This asymmetry is intentional: T4 is a **specialist boss-lane investment**. Players commit T4 budget when they need raw DPS ceiling to threaten late-wave boss HP pools — not when they want durable defensive structures. Content designers should calibrate T4 builds around constellation and hero support for sustainability, since T4 towers are severely HP-inefficient on their own.

**Example:** Iron Foundation, `hp_base = 220.0`, Tier 2:
`tower_max_hp = 220.0 × 1.5 = 330.0`
Boss dealing 80 damage/hit: ⌈330 ÷ 80⌉ = 5 hits to destroy.

---

### Formula 4: Tower Placement Cost

*(Provisional — the Resource Economy GDD defines the total mission budget and earning rate. These costs are proportional to that budget, not absolute.)*

`placement_cost = round(base_cost × archetype_cost_factor × tier_cost_factor)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base cost | `base_cost` | int | 10–60 | Baseline cost for a Tier 1 tower of any archetype. Provisional default: 20. |
| Archetype cost factor | `archetype_cost_factor` | float | **[0.5–2.0]**, all archetypes = **1.0** at MVP | Per-archetype tuning multiplier. MVP default is 1.0 for all archetypes. Range [0.5, 2.0] available for post-MVP balance (see Tuning Knobs). Must be in range [0.5, 2.0] — values at or below 0.0 are load-time errors. |
| Tier cost factor | `tier_cost_factor` | float | 1.0–4.0 | Tier 1 = 1.0×, Tier 2 = 1.5×, Tier 3 = 2.0×, Tier 4 = 4.0×. |
| Placement cost | `placement_cost` | int | **5**–240 | Resource deducted on confirmed placement. Refund on removal: `round(placement_cost × 0.4)`. |

**Output Range:** Minimum 5 (`round(10 × 0.5 × 1.0) = 5` — minimum `base_cost` with minimum `archetype_cost_factor`). The previously stated floor of 10 was incorrect; the actual formula minimum at MVP is 5 because `archetype_cost_factor` can be as low as 0.5 (Tuning Knob range).

**T4 `base_cost` ceiling (added during `/design-review` 2026-07-14 re-review, resolves OQ-11):** Any Foundation component with `tier = 4` must have `base_cost ≤ 30` — a load-time error otherwise (see Edge Cases → Formula Boundary, tier cross-field consistency table). T1–T3 Foundations retain the full `base_cost` range [10, 60]. This was a deliberate design response to a confirmed economic problem: without this cap, T4's cost was bimodal and unpinned — a T4 archetype at `base_cost=20` cost 21% of a typical 375-gold mission budget (viable), while one at `base_cost=60` cost 64% (structurally prevented fielding a viable board) — and nothing determined which case any given T4-capable archetype would land in. Capping `base_cost` for T4 specifically removes that ambiguity and, as a side effect, **unifies the cost ceiling across tiers**: T4 max (`round(30 × 1.0 × 4.0) = 120` at MVP; `round(30 × 2.0 × 4.0) = 240` post-MVP) now exactly matches T3's own max (`round(60 × 1.0 × 2.0) = 120` at MVP; `round(60 × 2.0 × 2.0) = 240` post-MVP) — no tier can cost more than any other at either budget tier. Maximum: **120 at MVP**, **240 post-MVP** (`archetype_cost_factor = 1.0`/`2.0` respectively, achieved by either a maxed-`base_cost` T3 or a capped-`base_cost` T4). The prior stated ceilings (240 MVP / 480 post-MVP) no longer apply — those were T4-at-uncapped-`base_cost` figures. In normal play (Tier 1–2 towers at MVP): 20–60.

**Budget calibration target:** 10 towers at average cost 30 = 300 gold. Mission budget ~349–375 gold (6-wave, r=0.20 default to r=0.25 ceiling — see Tuning Knobs' `mission_resource_budget` row for the full breakdown, corrected 2026-07-15) to allow replacement towers. *The Resource Economy GDD owns the total budget number and per-wave earning rate.*

**Example:** Tier 2 Elemental tower: `base_cost = 20`, `archetype_cost_factor = 1.0`, `tier_cost_factor = 1.5`
`placement_cost = round(20 × 1.0 × 1.5) = 30`

## Edge Cases

### Placement and Removal

- **If a 2×2 tower footprint partially overlaps a SPAWN, PATH, GOAL, or BLOCKED cell**: `Grid.is_footprint_placeable()` evaluates all cells atomically. If any cell is not PLACEABLE, the entire placement is rejected. No partial placement exists.

- **If a tower is removed during INTERMISSION and the player immediately attempts to re-place in the same cells with insufficient resources**: The cells return to PLACEABLE on removal. The resource check fires before the Grid query. Placement is rejected at the resource gate; the cells remain PLACEABLE. No Grid write occurs, no events emitted.

- **If the player confirms a tower placement during `WAVE_ACTIVE`**: The Tower System rejects the placement before any Grid or resource call. No Grid write occurs, no events are emitted, the resource balance is unchanged. Visual feedback: placement is rejected with the standard "Placement Rejected" red flash. This is consistent with the authorship contract in Rule 8.

- **If the player attempts to remove a tower during `WAVE_ACTIVE`**: The Tower System rejects the action before any Grid call. No events are emitted, no components are returned. Standard "cannot modify towers during a wave" UI feedback applies.

- **If a placement UI confirmation animation is still playing when the SCOUT phase ends**: Placement is committed the moment `Grid.place_tower()` returns OK. If that call returned OK during SCOUT, the tower is valid and `placed_in_scout = true` regardless of when the visual animation completes.

- **If a 2×2 tower is destroyed by a boss and a new tower is placed in those cells in the same frame**: `Grid.remove_tower()` resolves synchronously during destruction. Those cells are PLACEABLE by the time any placement validation runs. The new placement proceeds normally, subject to resource and phase checks.

- **If the player fills every PLACEABLE cell on the grid**: All subsequent placement attempts fail at `is_footprint_placeable()`. The resource check still fires first; if the player also lacks resources, that rejection surfaces first. Either way, no events are emitted.

- **If the Intermission (or Scout Phase) timer expires while the player has an unconfirmed tower placement cursor active** (footprint preview displayed, placement not yet confirmed via button press): The placement is **cancelled** — no resource deduction, no Grid write, no `tower_placed` event fires. The footprint cursor is dismissed automatically. The player must re-select and re-confirm during the next available placement window. This also applies to Scout Phase timer expiry: the phase boundary is drawn at `Grid.place_tower()` returning `OK`, not at cursor activation.

### Targeting and Range

- **If a tower's attack cone is less than 360° and all enemies are within Chebyshev range but none fall within the cone**: The tower fires no shot that cycle. Timer resets. Tower stays in `TARGETING`. This is intended — a directed tower that covers one lane by design.

- **If two enemies tie on path-step distance to GOAL and on current HP**: The tower targets the entity that appears first in the internal enemy list. This ordering must be stable across frames; an unstable list under this condition would cause the tower to alternate targets cycle-to-cycle.

- **If a 2×2 tower calculates Chebyshev distance for range**: All range checks use the **centroid of the footprint** as the anchor. A 2×2 tower whose top-left is at `(t_col, t_row)` has anchor `(t_col + 0.5, t_row + 0.5)`. An enemy at cell `(c, r)` has Chebyshev distance `max(|c − (t_col + 0.5)|, |r − (t_row + 0.5)|)`. When comparing this float distance to integer `effective_range`, round half-up (consistent with GDScript `round()` behavior). This produces a symmetric range circle centered on the visual tower footprint rather than an asymmetric circle anchored to the top-left corner. Component data authors must use this centroid convention when specifying `attack_range_cells` for 2×2 towers.

- **If targeting priority is `SPAWN_ORDER` and all alive enemies in range have the same `entity_id` (impossible in practice — IDs are unique per mission)**: This cannot occur. `entity_id` is assigned sequentially at spawn and is never reused within a mission (Rule 11a). `SPAWN_ORDER` is always deterministic.

- **If targeting priority is `SPAWN_ORDER` and the current lowest-id alive target exits range mid-wave**: The tower selects the next-lowest-id alive target in range on its next attack cycle. Re-acquisition is immediate at timer expiry — no sticky tracking of an out-of-range target.

- **If targeting priority is `SPAWN_ORDER` and `_monster_cache` contains entries for monsters that have already breached the GOAL (exited the grid)**: `monster_died` is not fired for monsters that breach. The Tower System must also subscribe to `monster_breached` to remove those entries from `_monster_cache`, or the SPAWN_ORDER mode may target a monster no longer on the grid. **EventBus GDD update required: Tower System must subscribe to `monster_breached` for cache hygiene.** *(OQ-8 resolved — see Rule 14a.)*

- **If targeting priority is `SCATTER` and exactly one valid target exists**: The tower targets that enemy. No re-roll, no skip. The repeat-guard (Rule 15) does not apply in this case — see below.

- **If targeting priority is `SCATTER` and the candidate pool shrinks between attack cycles such that the naive `_scatter_index mod len(candidates)` computation would re-select `_last_scatter_target_id`**: The repeat-guard (Rule 15) selects the next candidate in the sorted list instead (`candidates[(_scatter_index + 1) mod len(candidates)]`), guaranteeing no consecutive repeat whenever 2 or more candidates remain. If only 1 candidate remains, the guard does not apply and that candidate is re-targeted (see above) — this is the only case where a consecutive repeat is expected behavior.

- **If targeting priority is `LOWEST_HP` and all valid enemies share identical current HP**: Falls through to the standard tiebreaker: furthest along path → first in internal entity list (ascending `entity_id`). **This is the same tiebreaker path as the default `CLOSEST_TO_GOAL` mode — all targeting modes share a single universal tiebreaker chain. This symmetry is intentional: a stable, deterministic final tiebreaker is required for test reproducibility. Content designers authoring Focus components should note that the tiebreaker behavior is not configurable per mode.**

- **If a tower with a narrow cone is placed in a corner cell facing outward from the grid**: No enemies will ever enter both range and cone. The tower fires nothing. No error state — expected behavior from a misplaced tower. The Tower System does not validate cone orientation at placement time.

### Attack Execution

- **If a HOMING projectile's target dies and no valid target exists within the tower's range and cone at the moment of re-acquisition**: The projectile dissipates. Re-acquisition is bounded by the originating tower's range and cone — the projectile does not extend its search area.

- **If a BALLISTIC AoE projectile arrives at the target's last-known position and no living enemies are within the AoE detonation radius**: The projectile detonates (visual and audio) with zero damage instances. The Damage & Status System must accept zero-target detonation events without error.

- **If `aoe_radius_cells > 0` and one or more other monsters occupy cells within that radius of the primary target**: each additional monster takes damage per Formula 1c (falloff by Chebyshev distance from the primary target's cell), emitted as its own `tower_attacked` event with `effect_type = ""` regardless of the primary target's own status roll (see Formula 1c — status effects do not splash). This is in addition to, not instead of, the primary target's own full-damage hit.

- **If a splash-eligible monster is at the exact same cell as the primary target** (e.g. two entities briefly overlapping mid-transition): distance resolves to 0, which the splash search explicitly excludes (0 is reserved for the primary target itself) — a same-cell secondary monster is not silently double-counted as a second primary hit. This is a defensive boundary case, not expected to occur under normal Grid occupancy rules (one tower/monster per cell), but the implementation must not assume it can't.

- **If a BALLISTIC projectile is in flight and the target moves out of its aimed position before the projectile arrives**: The projectile continues to the world position it was aimed at (target's position at fire time). If an enemy is present at that position on arrival, that enemy takes damage. If the position is empty, no damage is dealt.

- **If `wave_completed` fires on the same frame that an attack timer would fire**: The Tower System's attack timer evaluation begins with a state guard: `if current_state == IDLE: return`. The tower transitions to `IDLE` on receipt of `wave_completed`. Regardless of frame-level signal execution order, the state guard prevents a spurious firing cycle. **Implementation must use this guard — do not rely on Godot signal execution order to guarantee wave_completed processes first.** In-flight projectiles from prior frames resolve normally against whatever monsters remain before they are cleared.

- **If 20+ towers fire simultaneously at wave start, risking an EventBus `tower_attacked` spike above the batch threshold**: Stagger offsets applied at placement (see Core Rule 17a) distribute fire across frames, keeping per-frame emissions well below the threshold even at maximum tower counts.

- **If N = 0 at `wave_started` (no active towers on field)**: The stratified stagger calculation is skipped entirely (dividing [0.0, 0.2] by zero is undefined). No stagger assignment occurs, no error is raised. The `wave_started` event is processed normally; the Tower System simply has no towers to initialize.

### Tower HP and Destruction

- **If `boss_tower_attack_attempted` arrives with a `target_tower_id` that does not match any active tower entity**: The Tower System discards the event and logs a debug warning. No damage is applied.

- **If a single boss attack reduces tower HP from above 0 to exactly 0**: Tower enters `DESTROYED` immediately in the same frame. HP is not held at 0 as a transitional state; `if current_hp <= 0` fires synchronously during damage application.

- **If `wave_completed` fires before all `boss_tower_attack_attempted` events from that wave are flushed**: Boss attack events received after HP reset would apply damage to a freshly-restored pool. The Tower System must tag each boss attack event with a wave identifier and reject events whose `wave_id` does not match the current active wave.

- **If a `DESTROYED` tower had a Power component with an active DoT or status effect mid-application**: All effects sourced from this tower are severed on entry to `DESTROYED`. The Damage & Status System must handle orphaned effect instances (source tower no longer exists) without error.

- **If the mission ends in DEFEAT while towers have `damaged` components pending return**: All `damaged` components are returned to the player's inventory during end-of-mission processing, via the same `tower_component_returned(damaged=true)` emission specified in Rule 24 — DEFEAT does not skip or alter this emission. DEFEAT does not forfeit components — they are always recoverable. The `damaged` flag persists on returned components; they cannot be equipped until repaired at the Sanctuary. The Save & Persistence System must include the `damaged` component flag in its inventory save schema.

   **Pending component-return storage (added during `/design-review` 2026-07-14):** Between a tower's destruction (entity freed, per Rule 24) and mission-end `tower_component_returned` processing, the four component IDs owed to that tower's original owner must be retained by the **Tower System singleton**, not the (already-freed) tower entity — e.g. a `_pending_component_returns: Array[Dictionary]` accumulated at each `DESTROYED` transition and flushed once per entry at mission-end processing. This was previously unstated; the entity cannot hold this data itself since it no longer exists by the time mission-end processing runs.

   **DEFEAT-save ordering mandate (added during `/design-review` 2026-07-14 — resolves a cross-GDD scenario gap):** Both this rule's `tower_component_returned` emission and Save & Persistence's post-mission save subscribe to `mission_phase_changed(new_phase=DEFEAT)` with no specified relative ordering. If Save & Persistence's save handler runs first, it would serialize Inventory's state *before* destroyed towers' components are returned — silently violating this rule's own "DEFEAT does not forfeit components" guarantee, since the save would omit them. **The Tower System's `tower_component_returned` emissions (and Inventory's resulting `item_added` calls) must complete before Save & Persistence's post-mission save runs on `mission_phase_changed(DEFEAT)`.** This is a Save & Persistence GDD update requirement, not something Tower System can enforce unilaterally — see Dependencies table and Open Questions. The same ordering hazard applies to any Sell-triggered `tower_component_returned` immediately followed by an autosave, though Sell is not mission-ending and is lower risk in practice.

### Pre-Placement Perk

- **If a Scout-Phase tower is removed and re-placed in Scout Phase at a different cell**: `placed_in_scout = true` is set at re-placement. `pre_placement_perk_activated` fires again. Subscribing systems must treat re-activation as a replacement, not a stack — no cumulative perk benefit from repeated Scout-Phase re-placements.

- **If a mission type begins directly in WAVE_ACTIVE with no Scout Phase**: No tower can ever have `placed_in_scout = true`. The perk system does not error — it simply never fires. No special handling required.

- **If the player places and removes multiple different towers during Scout Phase**: Each remove-and-re-place cycle is independent. No perk state persists from a removed tower. Subscribing systems must clean up perk state on receipt of `tower_removed`. Resources are not refunded.

### Formula Boundary

- **Load-time validation — all component stat fields**: The following component data fields must be validated at load time and raise a load-time error if violated. This extends the existing `tier_cost_factor` validation pattern to all component stats:

  | Field | Valid Range / Set | Error if violated |
  |-------|-----------------|-------------------|
  | `weapon_damage` | [8.0, 120.0] float | Silent zero-DPS tower |
  | `attack_speed` | [0.5, 4.0] float | Values outside this range are load-time errors; [0.3, 6.0] is the balance experimentation range only, not a load constraint |
  | `hp_base` | [80.0, 400.0] float | Zero-HP tower insta-destroyed |
  | `base_cost` | [10, 60] int | Zero/negative cost = free or resource-generating tower |
  | `tier_cost_factor` | {1.0, 1.5, 2.0, 4.0} | Free/inverted placement cost |
  | `tier_multiplier` (HP) | {1.0, 1.5, 2.0, 2.5} | Zero-HP or runaway HP |
  | `tier_dps_multiplier` | {1.0, 1.6, 2.4, 4.0} | Zero-DPS or runaway DPS |
  | `attack_range_cells` | int [1, 8] | Out-of-bounds range |
  | `cone_half_angle` | float [22.5, 180.0] | Values below 22.5° are below the minimum arc width for a movable target to reliably enter |
  | `facing_direction` | enum {N, NE, E, SE, S, SW, W, NW} | Invalid direction = undefined cone orientation |

- **If tier cross-field consistency is violated** (e.g., a Foundation component has `tier = 2` but `tier_multiplier = 1.0` instead of `1.5`): Load-time validation must check that all five tier-indexed fields — `tier`, `tier_multiplier`, `tier_dps_multiplier`, `tier_cost_factor`, and `tier_boss_dps_multiplier` — are mutually consistent. The valid mapping is:

  | tier | tier_multiplier | tier_dps_multiplier | tier_cost_factor | tier_boss_dps_multiplier | base_cost ceiling |
  |------|----------------|---------------------|------------------|--------------------------|--------------------|
  | 1 | 1.0 | 1.0 | 1.0 | 1.0 | — (full [10, 60] range applies) |
  | 2 | 1.5 | 1.6 | 1.5 | 1.0 | — (full [10, 60] range applies) |
  | 3 | 2.0 | 2.4 | 2.0 | 1.0 | — (full [10, 60] range applies) |
  | 4 | 2.5 | 4.0 | 4.0 | 2.0 | **≤ 30** *(added during `/design-review` 2026-07-14 re-review, resolves OQ-11 — see Formula 4)* |

  Any Foundation component where any tier-indexed field does not match the expected value for the declared `tier` must raise a load-time error. This includes `tier_cost_factor` — a mismatched cost factor could create an underpriced-tower exploit. Partial-tier data (e.g., a "Tier 2.5 Foundation") is not defined and must be rejected. **A Tier 4 Foundation with `base_cost > 30` must also raise a load-time error** — this is a distinct check from the other tier-indexed fields (it constrains a *range*, not a fixed value) but is validated at the same point in the load pipeline.

- **If `placement_cost` exceeds the mission budget**: The formula `round(base_cost × archetype_cost_factor × tier_cost_factor)` has no hard ceiling. Post-MVP, with `archetype_cost_factor > 1.0`, costs could exceed `tower_placement_budget_target`. The formula's output range note is advisory; the Resource System must treat any placement attempt where `placement_cost > player_current_balance` as a rejection at the resource check gate (Rule 9a). No formula-level ceiling is applied — the affordability check is the gate.

- **If component data contains `tier_cost_factor` outside the defined set**: `placement_cost` would be 0 or negative. Load-time validation (see table above) must catch this.

- **If `round()` rounding direction matters for placement_cost**: GDScript's `round()` uses "round half away from zero" (not banker's rounding). With fractional intermediate products, this is the canonical rounding behavior. Do not substitute `floor()` or `ceil()` in the implementation.

- **If `tower_dps` is used to compute a tower "power score"**: This formula captures only direct weapon damage × attack speed × tier multiplier. Power component on-hit effects (DoT, AoE splash, slow-amplified exposure time) are excluded. The HUD "estimated DPS" display must label this as **Weapon DPS only** to avoid misleading players about Elemental and Support tower effectiveness.

- **If qualifying tower count in the Hero Tower Affinity formula exceeds `towers_affinity_reference_count` (16)**: The formula `sqrt(qualifying_towers / 16)` produces values above 1.0. This is correct — diminishing returns continue above 16, they do not cap. This is not an overflow or error condition.

### Multi-Tower / Field-State

- **If a constellation pattern loses three of its required four towers to voluntary removal during INTERMISSION**: Each `tower_removed` event triggers an immediate Constellation recheck — events are not batched. After the third removal, the pattern breaks and the bonus deactivates.

- **If a tower is destroyed mid-wave and Hero Tower Affinity must update**: The Hero System recalculates Tower Affinity immediately on `tower_destroyed` receipt. No deferred recalculation.

- **If two towers have overlapping attack ranges and select the same target simultaneously**: Both fire independently. The target receives damage from both. There is no target claim system or exclusivity. Overlapping fire zones are an intentional strategic tool.

- **If all towers on the field are destroyed by a boss during a single wave**: The wave continues with zero tower DPS. The hero is the sole damage source for remaining enemies. Pathfinding is unaffected. This is a valid, severe game state — not an error.

## Dependencies

| System | Direction | Nature | Interface |
|--------|-----------|--------|-----------|
| **EventBus System** | Hard dependency | Tower System emits all cross-system notifications through EventBus; subscribes to phase, wave, and monster lifecycle events | Owns **11** events (`tower_placed`, `tower_removed`, `tower_destroyed`, `tower_component_equipped`, `tower_attacked`, `pre_placement_perk_activated`, `tower_damaged`, `tower_aura_pulse`, `tower_wave_summary`, `tower_component_returned` — **added during `/design-review`, closes the Inventory return-path gap, see Rules 13/24**; `resources_changed` — **added during `/design-system` 2026-07-14, placement-cost debit, see Rule 9**); subscribes to **9** (`mission_phase_changed`, `wave_started`, `wave_completed`, `boss_tower_attack_attempted`, `monster_spawned`, `monster_cell_entered`, `monster_died`, `monster_damage_taken`, `monster_breached`) |
| **Grid System** | Hard dependency | Tower System calls Grid write and read APIs for placement validation, occupancy management, and coordinate conversion | `is_footprint_placeable()`, `place_tower()`, `remove_tower()`, `world_to_cell()`, `cell_to_world()` |
| **Save & Persistence System** | Hard dependency | Tower System persists Sanctuary-state data via the S&P save/restore API | restore_order: 23; saves `unlocked_variants`, `component_upgrade_levels`, `sanctuary_loadouts`. **S&P save schema for component inventory items must include `damaged: bool` (see Rule 24 and Edge Cases → DEFEAT) — the `damaged` flag must survive a save/load cycle so destroyed-tower components remain non-equippable until repaired.** Does NOT save: in-mission placement, runtime IDs, current HP. **Ordering requirement (added during `/design-review` 2026-07-14):** S&P's post-mission save on `mission_phase_changed(DEFEAT)` must run *after* Tower's `tower_component_returned` emissions (and Inventory's resulting `item_added`) for that same event — see Edge Cases → DEFEAT. S&P GDD must specify this ordering (e.g. deferring its DEFEAT-triggered save by one frame, mirroring its existing `sanctuary_state_restored` 1-frame-defer precedent). |
| **Resource Economy System** | Hard dependency (in-mission cost) | Defines total mission resource budget, per-wave earning rate; Tower System validates placement cost against player balance and emits the placement-cost debit | Tower System calls `MissionEconomy.can_afford()` before placement (Rule 9a) and emits `resources_changed(-placement_cost, "tower_placement")` on confirmed placement (Rule 9). **Gap resolved during `/design-system` 2026-07-14:** `resource-economy.md`'s Rule 8 (Scout grant) + new Rule 10/Formula 5 (per-wave completion grant) now define the full in-mission gold faucet — see OQ-10. **Remaining gap:** the 350–400 `mission_resource_budget` target is only calibrated for the 6-wave default mission; 8-wave missions require ~500–550 (see Formula 5's calibration note in resource-economy.md) — this Tuning Knob row still needs that explicit re-scoping. |
| **Hero System** | Downstream dependent | Hero subscribes to `tower_placed`, `tower_removed`, `tower_destroyed` to recalculate Tower Affinity and Tower-Synced Class proximity | Payloads must include `archetype: String`. *(Corrected 2026-07-15d — `/review-all-gdds` 6th pass: this cell still claimed Hero needed to add a `tower_removed` subscription, a stale duplicate of OQ-2's claim; OQ-2 itself was already resolved 2026-07-15d — hero.md already subscribes to all three events.)* |
| **Constellation System** | Bidirectional via EventBus | Constellation subscribes to Tower placement/removal/destruction events to recheck patterns; Tower subscribes to `constellation_activated`/`constellation_deactivated` to apply/remove bonuses | No direct calls in either direction. **Interface gap closed 2026-07-17 (`/design-review` re-review, closes `constellation.md` OQ-4):** `tower_placed`, `tower_removed`, and `tower_destroyed` must each add a `constellation_eligibility_tag: String` field (empty string = not eligible), mirroring the field already defined on the Power component (see Rule 2's schema table). This is an EventBus payload change, not a Tower-side behavior change — the tag is read-only data Tower already tracks per component. `event-bus.md`'s catalogue needs this field added to all three payloads before Constellation's `/design-review` blocker can close; not applied here to avoid scope creep into a separate GDD's docs without a dedicated pass. |
| **Monster System** | Upstream (boss behavior) | Monster System owns boss targeting logic and emits `boss_tower_attack_attempted` when a boss attacks a tower | Tower System applies flat damage directly; Monster System must design boss attack damage within the provisional range 40–200 HP per hit |
| **Pathfinding System** | Bidirectional — Tower calls; Pathfinding subscribes | Tower System calls `PathfindingSystem.would_block_all_paths(footprint_cells)` before every placement confirmation (Rule 9c); Pathfinding subscribes to `tower_placed` and `tower_removed` (via EventBus) to trigger deferred template rebuilds | `design/gdd/pathfinding.md` |
| **Damage & Status System** | Downstream dependent | Tower System fires `tower_attacked`; D&S resolves damage (including armored mitigation) and Power component on-hit effects. **At fire time, Tower System reads the target's `MonsterResource.archetype_tag` and includes `is_armored: bool` in the `tower_attacked` payload** — D&S applies 50% mitigation when `true`, reduced further by `armor_penetration: float` (Tower Stats System Phase 1, 2026-08-16 — also new on the payload, along with `is_crit: bool`). Tower System itself resolves crit/vs-tag/boss multipliers and elemental resistance upstream (in its own `_try_attack()`/`_monster_cache`), so `damage_amount` already reflects those by the time D&S receives it — `element` never crosses this signal. Must handle orphaned effects when tower enters `DESTROYED`. `tower_attacked` payload may need `power_component_id` field for on-hit effects (deferred to Power component design). |
| **Mission HUD** | Downstream dependent | HUD subscribes to Tower events for placement feedback, HP indicators, and perk activation visuals | No Tower System state read directly. **Corrected 2026-07-14**: floating damage numbers come from D&S's `monster_damage_taken`, not `tower_attacked` — see `design/gdd/mission-hud.md`. |
| **Inventory System** | Downstream dependent (added during `/design-review`, closes a real cross-GDD gap) | Tower System emits `tower_component_returned(tower_id, item_id, item_type, damaged)` once per component whenever a tower's components return to inventory (voluntary removal, Rule 13; destruction, Rule 24) — never `item_added` directly, since Inventory is the sole emitter of that signal per ADR-0016 | `design/gdd/inventory.md` must add a `tower_component_returned` subscription that adds the item to its ledger and emits `item_added(metadata={"damaged": damaged})` on Tower's behalf; `event-bus.md`'s catalogue needs this new event added — not done as part of this pass to avoid unplanned scope creep into a separate Approved GDD without a dedicated pass |
| **Crafting System** | Upstream dependent (hard, data-only — added 2026-07-17, closes OQ-12) | Crafting's repair mechanic (Rule 6) reads and mutates the `damaged: bool` field on Tower Component items already deposited in Inventory via `tower_component_returned`/`item_added` above; Tower System does not call into Crafting and has no other awareness of it | `crafting.md`'s Rule 6 owns the repair cost formula and the `damaged: true → false` mutation, gated on Inventory exposing a `clear_damaged_flag(item_id)` API (still an open Inventory-side gap — see `inventory.md`'s row above and `crafting.md`'s own Open Questions) |
| **Wave Manager** | Upstream dependency | Tower System subscribes to `wave_started`, `wave_completed`, `mission_phase_changed` (all Wave Manager–owned events). Additionally, the Wave Manager must emit `wave_preview_available` on **both** `SCOUT` phase entry (Wave 1 preview) and `INTERMISSION` phase entry (upcoming wave preview — showing the next wave, not the just-completed wave), always including a `boss_spawn_cell: Vector2i` field (sentinel `Vector2i(-1,-1)` on non-boss waves, resolved cell on the boss wave — see Rule 8's Boss-lane telegraph). Tower System does not directly consume `wave_preview_available` — the HUD does — but the authorship fantasy for Intermission decisions, and specifically the legibility of a T4 boss-lane investment (OQ-11), is gated on this mandate. | **Resolved 2026-07-15** — `design/gdd/wave-manager.md` Rule 11 now emits `boss_spawn_cell: Vector2i` on `wave_preview_available` (Rule 6 additionally requires boss entries to use an explicit `spawn_cell_index`, no round-robin, so the field is resolvable at preview time; AC-42 added). Mission HUD GDD still needs display logic for the boss telegraph — not yet closable end-to-end. |
| **Tower Mastery System** | Downstream dependent (soft, upgraded to hard for loadout reads) | Tower Mastery tracks hero proximity to tower cells via Grid read API; Tower System does not call Tower Mastery | Tower Mastery may subscribe to `tower_placed`/`tower_removed`/`tower_destroyed` to update proximity tracking. **New API added 2026-07-17 (`/design-review` re-review, closes `tower-mastery.md`'s blocking dependency):** `TowerSystem.get_component_loadout(tower_id: int) -> Dictionary[String, String]` — a direct Autoload call (same pattern as `Grid.get_spawn_cells()`) returning the 4 slot names mapped to their currently-equipped component IDs for a live, placed tower. Read-only, loadout-only — does not expose HP, target state, or any other runtime combat state, keeping it consistent with Rule 25's no-public-HP-polling precedent. Used by Tower Mastery's Formula 4 (`build_signature` derivation) at the moment a mastery threshold is crossed. |

**Bidirectional flags to resolve before implementation:**
- ~~`tower_removed` is a new event not yet in the EventBus GDD — must be registered~~ **RESOLVED** — already present in `event-bus.md`'s catalogue (verified 2026-07-14).
- ~~`tower_wave_summary` must be added to the EventBus GDD catalogue (owned by Tower System; subscribers: Mission HUD)~~ **RESOLVED** — already present in `event-bus.md`'s catalogue (verified 2026-07-14), along with `tower_aura_pulse`.
- ~~`monster_breached` payload must include `entity_id: int` — verify in EventBus GDD~~ **RESOLVED** — confirmed present in `event-bus.md`'s catalogue (`entity_id: int`, `monster_id: StringName`, `tier: int`; verified 2026-07-14). OQ-8's "Resolved" status is correct; this line was stale and understated it.
- ~~Hero GDD must add subscription to `tower_removed` (currently only `tower_placed`/`tower_destroyed`)~~ **RESOLVED** — same OQ-2 stale claim, closed 2026-07-15d. hero.md already subscribes to all three events.
- `tower_attacked` `is_armored: bool` field — **RESOLVED** in Rule 20a (2026-05-11). `_monster_cache` caches `archetype_tag: StringName` at `monster_spawned` time — **implemented 2026-08-16 (Tower Stats System Phase 1)**; until then `is_armored` was hardcoded `false` unconditionally (a real bug, the archetype_tag caching this row called for had never actually landed in `tower_system.gd`, only been proposed here). May additionally need `power_component_id` for on-hit Power effects (deferred to Power component design).
- `tower_placed` EventBus entry still says "or WAVE_ACTIVE" in when-fired description — update EventBus GDD before implementation to reflect Rule 8 (WAVE_ACTIVE fully blocked)
- **NEW (2026-07-14):** Save & Persistence GDD must specify that its DEFEAT-triggered post-mission save runs after Tower's `tower_component_returned`/Inventory's `item_added` for the same `mission_phase_changed(DEFEAT)` event — see Dependencies table and Edge Cases → DEFEAT.
- **NEW (2026-07-14):** `event-bus.md` must add `footprint: Vector2i` to the `tower_destroyed` payload — Rule 24 now specifies it; the catalogue did not previously match.

## Tuning Knobs

| Parameter | Current Value | Safe Range | Too High | Too Low |
|-----------|--------------|------------|----------|---------|
| `weapon_damage` (Weapon component stat) | 8–120 (by tier) | 5–150 | Tower one-shots monsters; wave cleared too fast, no hero contribution needed | Tower DPS negligible; hero carries all wave damage |
| `attack_speed` (Weapon component stat) | 0.5–4.0 atk/sec | 0.3–6.0 | Fire rate so high that audio becomes cacophony; `tower_attacked` event rate approaches batch threshold even with stagger | Tower feels unresponsive; slow hitters feel irrelevant against fast waves |
| `attack_range_cells` (Focus component stat) | 1–8 | 1–10 | Artillery towers cover the whole grid; spatial placement decisions become meaningless | Melee-only towers cannot reach any PATH cell from adjacent PLACEABLE cells on most maps |
| `cone_half_angle` (Focus component stat) | 22.5°–180° | 22.5°–180° | 180° always (omnidirectional only) removes strategic value of tower orientation | Cone so narrow that correctly-placed towers miss moving enemies between targeting cycles. **Floor is 22.5° (not lower) — this matches the load-time validation minimum. Values below 22.5° are rejected at load time; the Tuning Knob floor and load-time floor are aligned.** |
| `hp_base` (Foundation component stat) | 80–400 (schema validation range) | 60–600 | Towers unkillable by bosses; boss encounters lose tactical weight | Tier 1 towers die to a single hit; players avoid low-tier foundations entirely. **Content-authoring target for Tier 1 specifically: ≥120** *(added 2026-07-15 — Formula 3's "Boss damage calibration" note recommends this exact figure, based on final-wave boss damage of 55-80/hit; this row previously didn't cross-reference that recommendation, leaving it as an unactioned prose note. The 80–400 schema range is unchanged — 80 remains a technically valid load-time minimum for any content author's Foundation, but Tier 1 towers authored below 120 will die in a single final-wave boss hit at the high end of boss damage roll, per Formula 3's own math.)* |
| `tier_multiplier` (Foundation tier scaling) | 1.0, 1.5, 2.0, 2.5 | 1.0–3.0 | Tier 4 towers so durable that bosses cannot threaten them; upgrade curve feels mandatory | Upgrading Foundations provides negligible HP benefit; players skip upgrading |
| `base_cost` (placement cost default) | 20 | 10–60 for Tier 1–3 Foundations; **≤ 30 for Tier 4 Foundations** *(cap added during `/design-review` 2026-07-14 re-review, resolves OQ-11)* | Players can afford 2–3 towers maximum; build variety is impossible. For T4 specifically: an uncapped `base_cost` near 60 lets a single tower consume up to 64% of a typical mission's gold budget, structurally preventing a viable board — this is why the T4 sub-range is capped independently of T1–T3 | Players fill the grid easily; resource management is irrelevant |
| `tier_cost_factor` (cost per Foundation tier) | 1.0, 1.5, 2.0, **4.0** | 1.0–5.0 | Tier 4 towers priced beyond reach of all but final-wave boss lanes | High-tier towers cost same as Tier 1; no meaningful upgrade economy |
| `archetype_cost_factor` (per archetype, all 1.0 MVP) | **Physical=1.0, Ranged=1.0, Elemental=1.0, Support=1.0** | 0.5–2.0 per archetype | A taxed archetype is never used regardless of strategic value | Support towers free: every build max-stacks support with no cost tradeoff |
| `attack_timer_stagger_range` | [0.0, 0.2s] | [0.0, 0.5s] | Stagger so large that fast-attack towers miss targeting windows (enemies transit range during delay) | No stagger risks EventBus batch threshold spike when 20+ towers fire simultaneously |
| `tier_dps_multiplier` (Foundation tier DPS bonus) | 1.0, 1.6, 2.4, 4.0 | T1: 1.0 fixed; T2: 1.4–1.8; T3: 2.0–2.8; T4: 3.5–4.5 | Tier 4 towers trivialize early-wave content; Tier 4 DPS/cost advantage makes lower tiers obsolete in late game | Upgrade provides negligible DPS gain relative to cost; Tier 1 spam remains economically optimal |
| `boss_tower_attack_damage` *(provisional — owned by Monster System GDD)* | 40–136 per hit (wave-scaled max ~136 at Wave 8 per Monster GDD) | 20–200 | Boss destroys any tower in 1 hit; building feels pointless | Boss cannot destroy any Tier 2+ tower; boss encounters have no spatial threat |
| `crit_chance` (Weapon component stat, Tower Stats System Phase 1) | 0.0 default | 0.0–0.8 | Crit becomes the expected outcome rather than a bonus, flattening the "premium roll" feel; also risks blowing past documented DPS ceilings at scale | 0.0 makes the stat decorative — never worth authoring on a blueprint |
| `crit_multiplier` (Weapon component stat, Phase 1) | 1.5 default | 1.0–3.0 | A single crit one-shots low-HP monsters, making crit-focused towers swingy/unreliable-feeling in the opposite direction (too random) | 1.0 makes crit_chance pointless regardless of its own value |
| `armor_penetration` (Weapon component stat, Phase 1) | 0.0 default | 0.0–1.0 | 1.0 on a common/cheap tower makes the armored-monster mechanic meaningless project-wide | 0.0 means armor penetration never differentiates any tower from another |
| `bonus_damage_vs_tags` (Foundation component stat, Phase 1) | {} default | per-tag multiplier 1.0–2.0 | A tag bonus stacked with `tier_boss_dps_multiplier` and crit could compound past the documented boss-DPS ceiling unexpectedly — recalibrate that ceiling once real content authors non-trivial entries here | Values near 1.0 make the stat not worth a tower's identity/slot |
| `status_proc_chance` (Weapon component stat, Phase 1) | 1.0 default | 0.0–1.0 | N/A (1.0 is the ceiling, matches pre-Phase-1 behavior) | Very low values (e.g. <0.1) make a Power-equipped tower feel broken/non-functional rather than "chance-based" |
| `elemental_resistances` (MonsterResource stat, Phase 1) | {} default | per-element 0.0–0.9 | A monster resistant to most/all elements at once makes elemental tower investment feel wasted against it | Non-zero-but-trivial values (e.g. 0.05) are indistinguishable from 0.0 in practice — not worth authoring |
| `damaged_component_repair_cost` *(Open Question — CLOSED 2026-07-17, see OQ-12)* | **Owned by `crafting.md` Rule 6 / Formula 3** (Common-material-only cost, `quality_tier`-scaled, ~50% of fresh-craft cost). Crafting is authored (status: Designed, pending its own `/design-review`); full closure is still pending Inventory exposing `clear_damaged_flag(item_id)` (see Inventory dependency row above). | Per crafting.md Formula 3's safe range | Per crafting.md Formula 3's safe range | Per crafting.md Formula 3's safe range |
| `mission_resource_budget` *(owned by Resource Economy GDD; formula-backed as of 2026-07-14 — resource-economy.md Rule 8 + Rule 10/Formula 5)* | **Corrected 2026-07-15 (`/review-all-gdds`)** — the figures below previously stated 375 as the 6-wave "default"; resource-economy.md's own re-review proved 375 is only reached at Wave Manager's `r=0.25` safe-range ceiling. **6-wave missions at the actual default (`r=0.20`): ~349** (150 scout + 199 across waves 1–6). **6-wave missions at the `r=0.25` ceiling: ~375** (150 + 225). **7–8-wave missions: ~481 (r=0.20 default) to ~546 (r=0.25 ceiling)** (per-wave grant total scales with `wave_reward_scalar` up to wave 8) | — | Players fill every PLACEABLE cell; constellation planning loses depth | Players afford only 4–5 towers; build variety collapses to "use cheapest" |
| `base_flight_time_sec` *(HOMING/BALLISTIC projectile — implementation tuning)* | 0.5s | 0.2s–2.0s | Long flight time → large concurrent in-flight pool required (pool_size = max_towers × max_atk_speed × flight_time); above 2.0s the pool must exceed 128 instances | Very short flight time makes HOMING re-acquisition nearly impossible; targets die before projectile arrives |
| `projectile_pool_size` *(implementation default — sized for `base_flight_time_sec = 0.5s`, `max_active_towers_homing = 60`)* | **360** *(raised from 192 during `/design-review` 2026-07-14 re-review — 192 was confirmed undersized against realistic 40+-tower HOMING boards, causing silent dropped shots on exhaustion)* | 64–512 | Memory overhead from oversized pool | Pool exhaustion at peak load. Formula: `ceil(max_active_towers_homing × max_attack_speed × base_flight_time_sec × 3.0)`. At current values: `ceil(60 × 4.0 × 0.5 × 3.0) = 360`. Recalculate when `max_active_towers_homing` or `base_flight_time_sec` changes — the pool is not safe at its upper end if `base_flight_time_sec` is tuned above 0.5s with a 60-tower board. |
| `max_active_towers_homing` *(projectile pool sizing anchor)* | **60** *(resolved during `/design-review` 2026-07-14 re-review — anchored to the grid's own stated tower ceiling rather than left as a provisional guess)* | Matches the documented grid tower ceiling (40–60+) | N/A — set to the ceiling, not a conservative underestimate | Any value below the grid's actual max concurrent HOMING tower count risks pool exhaustion (silent dropped shots) |
| `max_reacquisitions_per_frame` *(HOMING re-acquisition rate limit)* | 8 | [4, 32] | Re-acquisition stalls; projectiles drift for multiple frames on a mass-kill event (e.g., AoE wipes 20+ targets simultaneously) | Insufficient throttle; 128+ re-acquisitions can spike per-frame work above frame budget when a high-HP focal target dies |
| `aoe_density_cap` *(maximum simultaneous AoE-capable towers firing per frame — content/level-design constraint, NOT runtime-enforced)* | **5** | [2, 8] | With `aoe_radius_cells = 4` a single BALLISTIC tower can hit ~16 targets per shot. At cap=8, a dense pack generates up to 128 `monster_damage_taken` per frame — well above the ~20 baseline assumed elsewhere. Above 8, AoE-heavy builds saturate the D&S processing budget unpredictably | Below 2, AoE archetype cannot form viable lanes; BALLISTIC component class becomes a trap pick |
| `MIN_SPLASH_FALLOFF` *(Formula 1c — splash damage at max `aoe_radius_cells` distance, added 2026-08-23 with Phase 2 Splash implementation)* | 0.40 | [0.20, 0.60] | Splash targets take near-full damage even at max radius — AoE towers trivialize dense packs with no single-target tradeoff, undermining the BALLISTIC/single-target archetype distinction | Splash becomes cosmetic-only at range; players stop valuing `aoe_radius_cells` above 1-2, defeating the point of authoring higher-tier AoE Foundations |
| `intermission_duration` *(owned by Wave Manager GDD — flagged here for Tower System impact)* | **25–40s (canonical)** | 20s–60s | Players have time to fully reorganize towers every wave; placement decisions lose weight | Players cannot evaluate available PLACEABLE cells, open component slots, and cost before the next wave begins — especially for 2×2 towers with rotated layouts and complex constellation patterns. 20s was flagged as insufficient; **25s is the minimum; 40s is the upper bound for typical late-game boards. Playtest within this range before locking.** |

**Knob interaction warnings:**
- `weapon_damage` × `attack_speed` must be calibrated together in combat scenarios, not on paper alone. Equal-DPS slow-heavy and fast-light towers feel completely different.
- `base_cost` and `mission_resource_budget` must be designed in concert — changing one without the other breaks the 8–12 towers-per-mission target.
- `hp_base` and `boss_tower_attack_damage` are paired: any change to boss damage in the Monster System GDD invalidates the HP tier calibration in Formula 3.

## Visual/Audio Requirements

**Design principle:** Every tower visual and audio cue must communicate a game-state fact. Effects that add visual noise without informational content are out of scope. The player is an Architect-General reading the battlefield at a glance; art must serve that read.

### Placement Preview (Cursor Hovering)

**Visual:** Tower ghost at 60% opacity with color-coded footprint highlight.
- Valid: footprint cells tinted pale green
- Invalid (wrong cell type): red tint, ghost at 30% opacity
- Invalid (insufficient resources): amber tint — distinct from cell-type rejection so the player reads the reason immediately

**Cone arc overlay (required):** The placement ghost always renders a **cone arc overlay** matching the equipped Focus component's `cone_half_angle` value, centered on the tower's `facing_direction`. The arc is rendered as a transparent wedge on the grid plane, with range boundary marked at `effective_range` cells (including cone range bonus and cap). This overlay is mandatory — without it, players cannot evaluate cone-range trade-offs before committing a placement. The overlay updates in real time as the ghost moves. For 360° towers (`cone_half_angle = 180°`), render a full-circle range ring instead of a wedge.

**Audio:** None during hover. Audio fires on confirmation or rejection only.

### Placement Confirmed

**Visual:** Ghost solidifies to full opacity with a brief outward scale ripple on footprint cells (~0.3s). Tower immediately enters IDLE appearance.

**Audio:** One confirmation sound per archetype — deliberate and weight-bearing, not a sparkle. Physical: metallic clunk. Ranged: mechanical click. Elemental: resonant tone. Support: soft chime.

### Placement Rejected

**Visual:** Footprint cells flash red (2–3 rapid pulses, ~0.4s), then return to normal grid state.

**Audio:** Single rejection buzz for cell-type, resource, and phase rejections. **Path-guard rejection uses a distinct audio cue** — a different sound or pitch variant that pairs with the "Path would be blocked" HUD callout (Rule 9c). This distinguishes path-guard rejection from all other rejection types in audio, reinforcing the visual and text differentiation. At MVP, one additional audio asset is required for path-guard rejection specifically.

### Tower IDLE State

**Visual:** Full-opacity render with a minimal passive animation (slow rotation, breathing pulse, or gentle glow cycle). Must read clearly as "at rest" — not targeting or attacking. Scout Phase towers with the pre-placement perk display a badge (see below). HP bar hidden.

**Audio:** Silence. No looping ambient sound during IDLE. The absence of sound reinforces the contrast when combat begins.

**Archetype variation:** Elemental towers may have a low-intensity particle ambient (embers for fire, frost haze for frost) provided it is visually distinct from TARGETING/ATTACKING particles. Physical/Ranged: mechanical idle only. Support: soft aura pulse.

### Tower TARGETING State

**Visual:** Orientation snap toward acquired target (barrel, aperture, or facing direction by archetype). A low-intensity glow on the weapon slot signals "locked and counting down." No live range ring overlay during combat — range rings are placement-phase tools only.

**Audio:** None on entry to TARGETING. Audio fires on attack, not acquisition.

### Tower ATTACKING State

**Visual:** Attack animation on fire (recoil, beam flash, energy discharge, or AoE effect by weapon type). Must be visually distinct from TARGETING and must not obscure the projectile. Attack fire is the loudest visual moment — readable at a glance from anywhere on the grid.

**Audio:** Attack sound fires per shot (high frequency — see polyphony note below). Archetype families must be aurally distinguishable when layered. Keep per-shot audio short (< 0.5s).

### Pre-Placement Perk Indicator

**Visual:** Persistent icon badge on the tower sprite (top-right corner of cell, 12–16px on-screen). Visible during IDLE and ATTACKING. Binary — present or absent; not a progress meter. Removed if the tower is voluntarily removed and re-placed during Intermission (perk forfeited, no transfer). The badge communicates "Scout Phase bonus active"; the specific perk is communicated via HUD tooltip, not the badge.

**Audio:** Short ascending tone on `pre_placement_perk_activated`. One universal sound across all archetypes. One badge asset required (original activation only — perk transfer mechanic is not in MVP scope).

### Tower Being Attacked by Boss

**Visual:** HP bar appears on first boss hit and remains until wave ends or tower is destroyed. Per-hit: brief red flash on tower sprite (~0.1s). At < 30% HP: HP bar pulses red (low frequency) — mirrors hero low-HP visual language.

**Audio:** Hit-received sound on each boss attack — heavier than standard tower fire (exceptional event). One sound at MVP.

### Tower DESTROYED (Terminal)

**Visual sequence:**
1. Red flash (1 frame)
2. Archetype-appropriate destruction VFX: debris burst (physical), scatter (ranged), extinguish/shatter (elemental), resonance fade (support)
3. Grid cells immediately read as PLACEABLE — no visual remnant on cells
4. Optional: brief camera micro-shake to punctuate the event

**Audio:** Dedicated terminal destruction sound per archetype — distinct from attack, hit, and placement sounds. Physical: heavy collapse. Ranged: structural crack and scatter. Elemental: extinguish/shatter (element-appropriate). Support: resonance fade.

### Tower Voluntarily Removed

**Visual:** Smooth dissolve or retract animation (~0.3–0.5s). No debris, no red flash — reads as "packed up, not killed." Grid cells return to PLACEABLE immediately (animation is cosmetic; game state updates on confirmation).

**Audio:** Short, soft removal sound. Quieter than destruction. One sound covers all archetypes.

### Projectile Types

All projectiles must communicate at a glance: **what archetype fired it** and **what behavior it has** (homing / ballistic / beam).

| Type | Visual signature | Audio |
|------|-----------------|-------|
| **HOMING** | Curved flight path with persistent trail showing the curve. Trail color follows archetype accent. Dissipation (no re-acquire): trail fades (~0.2s), no detonation. | Optional flight hum. Impact audio is load-bearing. |
| **BALLISTIC** | Straight flight path, short linear tail. AoE variant: ground-plane expansion ring on detonation communicates AoE radius. Ring plays even on zero-damage detonation. | Whoosh in-flight. Thud/crack on impact. AoE detonation: fuller, rounder explosion sound (distinct from single-target). |
| **BEAM** | Instant connection. Persistent beam core + soft glow for attack duration. Must NOT persist after attack resolves. Beam width communicates intensity. | Beam-on start transient + optional sustain loop (if duration > 0.3s). Cuts cleanly on beam drop. |

**Archetype projectile color language:**

| Archetype | Color family | Notes |
|-----------|-------------|-------|
| Physical | Grey / silver / stone | No particles; solid, physical feel |
| Ranged | Brown / wood / metal | Arrow, bolt, or solid projectile |
| Elemental | Per-element (see below) | Highest asset volume |
| Support | Warm gold / pale light | Buff pulse, chain arc |

**Elemental sub-type color language** (provisional — pending art bible):

| Element | Color | Visual signature | MVP scope |
|---------|-------|-----------------|-----------|
| Fire | Red-orange | Ember particles, heat shimmer | ✓ MVP |
| Frost | Ice blue / white | Crystalline trail, snowflake fragments | ✓ MVP |
| Poison | Acid green | Drip particles, cloud puff on impact | Vertical Slice |
| Lightning | Electric yellow / white | Jagged arc, no smooth trail | Vertical Slice |
| Arcane | Purple / violet | Geometric fragments, no physical material | Alpha |

### AoE Detonation

Ground-plane impact ring expanding to AoE radius then fading (~0.4s) — this ring communicates exact AoE size and is a readability requirement, not decoration. Per-element particle burst layered on top. Zero-damage detonations play full VFX and audio (Ballistic edge case requires this).

---

### Asset Volume Flags

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:tower` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

- **Elemental projectile and detonation VFX (HIGH VOLUME):** Fire + Frost at MVP (~2 elements × 3 behaviors × 3 states = ~18 VFX sets). Poison/Lightning at Vertical Slice; Arcane at Alpha.
- **Archetype destruction VFX (MODERATE):** 4 unique destruction sequences. Block out generic first; archetype polish in Alpha.
- **Audio polyphony (TECHNICAL FLAG):** Up to 80 `tower_attacked` events per second at peak load (20 towers × 4 atk/sec). Audio system must implement archetype-level polyphony caps and priority queuing. Flag for the Audio System GDD (Full Vision tier).

## UI Requirements

> **📌 UX Flag — Tower System:** This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create UX specs for the placement HUD and tower info panel before writing epics. Stories referencing UI should cite `design/ux/placement-hud.md` and `design/ux/tower-info-panel.md`, not this GDD directly.

### Placement HUD (Active During SCOUT and INTERMISSION)

- **Tower build panel:** Displays all tower configurations available to the player (by Foundation + component loadout combinations unlocked). Each entry shows: archetype icon, estimated DPS, placement cost, footprint size, pre-placement perk indicator (if any). Unavailable towers (missing components, insufficient resources) are grayed out, not hidden.
- **Resource counter:** Current in-mission gold displayed prominently. Updates immediately on placement confirmation and on wave-completion resource awards.
- **Footprint preview:** Grid cells highlight valid/invalid/insufficient-resource states in real time as the cursor moves. Color logic matches Visual/Audio requirements.
- **Phase timer:** Scout Phase and Intermission countdown visible. Placement HUD dismisses automatically when timer expires or player confirms "wave ready."

### Tower Info Panel (On Select / Hover in Placement or Between Waves)

- **Displays:** Tower name, archetype, component loadout (all 4 slots), attack range in cells, targeting mode, DPS estimate, max HP, placement cost, pre-placement perk description (if applicable).
- **Hover state (grid):** Shows info for the tower occupying the hovered cell during SCOUT and INTERMISSION.
- **Sell button (SCOUT and INTERMISSION only):** A **Sell** button is displayed in the Tower Info Panel when a placed tower is selected during `SCOUT` or `INTERMISSION`. The button shows the sell refund amount: "Sell — get 40% back ([refund] pts)". Pressing Sell triggers tower removal and returns `round(placement_cost × 0.4)` gold. The button is hidden (not grayed — fully absent) during `WAVE_ACTIVE`. No confirmation dialog is shown — the Sell action is immediate on button press.
- **Read-only during WAVE_ACTIVE:** Info panel may display, but no interaction affordances (including Sell) are shown.

### Tower HP Bar (During Boss Attacks Only)

- HP bar appears on first boss hit; remains until wave ends or tower destroyed.
- Positioned above the tower within its cell footprint — does not overlap adjacent cells.
- Hidden during IDLE between waves (HP resets; bar is irrelevant until the next boss attack).
- Color: neutral fill transitioning to red below 30% HP.

### Constellation State Overlay (Coordination with Constellation System)

- When a valid constellation pattern is formed, contributing towers display a shared visual indicator (e.g., connecting line, cell highlight, or glow border) to confirm the pattern is active.
- This overlay is owned by the Constellation System UI, not the Tower System — noted here for cross-system awareness. The Tower System emits events; Constellation System drives the overlay.

### Component Loadout UI (Sanctuary — Not Mission)

- Tower component configuration is managed in the Sanctuary UI, not during missions.
- The Sanctuary UI (Alpha tier, separate GDD) owns the slot-by-slot component swap interface.
- The Tower System emits `tower_component_equipped` (payload: `tower_id`, `slot`, `component_id`) to confirm successful swaps. The Sanctuary UI subscribes to this event for feedback.

## Acceptance Criteria

*(Format: **GIVEN** initial state, **WHEN** action or trigger, **THEN** measurable outcome. Story type gates in brackets.)*

> **Sprint-0 prerequisite — EventBusSpy:** **10** ACs in this section verify that specific EventBus events are NOT emitted under certain conditions (or, for one AC, that a positive emission occurs within a specific dispatch-cycle ordering). These ACs require **EventBusSpy** — an injectable EventBus observer that records all emissions by event name, timestamp, and payload. EventBusSpy does not exist at the time of this writing. **Do not assign any AC that verifies a negative event emission (or emission ordering) to a sprint until EventBusSpy is built.** Sprint-0 story: "Build EventBusSpy: injectable EventBus observer that records all emissions by event name, timestamp, and payload. Required by Tower, Monster, and Wave Manager test suites." **Recount corrected during `/design-review` 2026-07-14 re-review** — the prior "12" figure did not match the actual AC set; ACs affected, tallied: `tower_placed` does NOT fire (3 ACs: WAVE_ACTIVE rejection, path-guard rejection, zero-gold rejection), `pre_placement_perk_activated` does NOT fire (2 ACs: Intermission placement, unconditional forfeiture on Intermission re-placement), `tower_damaged` does NOT fire (2 ACs: wave_id staleness — race-condition framing and GUT-injection framing), `tower_removed`/`tower_destroyed` both do NOT fire (1 AC: WAVE_ACTIVE removal rejection, asserts both absences), `constellation_deactivated` emission-ordering (1 AC, DEFERRED pending Constellation GDD), `tower_attacked` does NOT fire after tower destruction (1 AC: HOMING/simultaneous-death case). Total: 10 distinct ACs. The placement-cost debit-ordering AC (`resources_changed` before `tower_placed`) separately requires an ordering-observable EventBusSpy variant, not just presence/absence — see that AC's note.

- **[Logic — BLOCKING]** **GIVEN** a tower with all 4 component slots filled, **WHEN** the player confirms placement during SCOUT Phase on a PLACEABLE cell with sufficient resources, **THEN** all footprint cells return `OCCUPIED` via `Grid.get_cell_type()` immediately after confirmation, and `tower_placed` fires with `archetype: String`, `footprint: Vector2i`, and `placed_in_scout: true` in the payload.

- **[Logic — BLOCKING]** **GIVEN** a tower with all 4 component slots filled and sufficient resources, **WHEN** the player confirms placement during `WAVE_ACTIVE`, **THEN** the placement is rejected before any Grid write, no `tower_placed` event fires, the resource balance is unchanged, and the placement footprint flashes red. *(Rule 8 revised 2026-05-01: WAVE_ACTIVE placement is blocked entirely.)*

- **[Logic — BLOCKING]** **GIVEN** a tower placed during SCOUT Phase, **WHEN** placement is confirmed, **THEN** `pre_placement_perk_activated` fires with the correct `tower_id` before the first wave begins.

- **[Visual — ADVISORY]** **GIVEN** `pre_placement_perk_activated` has fired for a tower, **WHEN** the Scout Phase is active, **THEN** the tower displays a visible perk indicator that distinguishes it from non-perk towers. *(Evidence: screenshot, lead sign-off.)*

- **[Logic — BLOCKING]** **GIVEN** the same tower type placed during INTERMISSION (after Wave 1), **WHEN** placement is confirmed, **THEN** `pre_placement_perk_activated` does NOT fire and `placed_in_scout` is `false`.

- **[Logic — BLOCKING]** **GIVEN** a tower with `placement_cost = 30` is voluntarily sold during INTERMISSION via the Tower Info Panel Sell button, **WHEN** Sell is confirmed, **THEN** `tower_removed` fires (not `tower_destroyed`), the player's inventory contains exactly the 4 component items that were equipped at placement (confirmed by before/after inventory comparison), and the player's resource balance increases by exactly `round(30 × 0.4) = 12` gold. *(Rule 13 — Sell button + 40% refund)*

- **[Logic — BLOCKING]** **GIVEN** a placed tower is selected during `WAVE_ACTIVE`, **WHEN** the Tower Info Panel opens, **THEN** no Sell button is present in the panel — the Sell affordance is entirely absent, not merely disabled. *(Rule 13 — Sell hidden during WAVE_ACTIVE)*

- **[Logic — BLOCKING]** **GIVEN** a Weapon component with `weapon_damage=35.0` and `attack_speed=2.0` on a Tier 1 Foundation (`tier_dps_multiplier=1.0`), **WHEN** the DPS formula is evaluated, **THEN** `tower_dps = 35.0 × 2.0 × 1.0 = 70.0`.

- **[Logic — BLOCKING]** **GIVEN** the same Weapon component on a Tier 2 Foundation (`tier_dps_multiplier=1.6`), **WHEN** the DPS formula is evaluated, **THEN** `tower_dps = 35.0 × 2.0 × 1.6 = 112.0`.

- **[Logic — BLOCKING]** **GIVEN** a Tier 1 tower firing continuously for 10 seconds against a target that does not die (weapon_damage=35.0, attack_speed=2.0, tier_dps_multiplier=1.0), **WHEN** cumulative damage is measured, **THEN** total damage dealt is 700 (±1 floating-point tolerance).

- **[Logic — BLOCKING]** **GIVEN** a Tier 2 tower firing continuously for 10 seconds (weapon_damage=35.0, attack_speed=2.0, tier_dps_multiplier=1.6), **WHEN** cumulative damage is measured, **THEN** total damage dealt is 1120 (±1 floating-point tolerance).

- **[Logic — BLOCKING]** **GIVEN** a tower at cell (8,6) with `attack_range_cells=4` and `cone_half_angle=180°`, **WHEN** an enemy is at cell (13,6), **THEN** `cell_distance = max(|13−8|, |6−6|) = 5`, which exceeds range 4, so `target_in_range = false` and the tower does not fire.

- **[Logic — BLOCKING]** **GIVEN** a tower at cell (8,6) facing east with `attack_range_cells=4` and `cone_half_angle=45°`, **WHEN** an enemy is at cell (10,9) (Chebyshev distance = 3, within range, but angle ≈ 56° > 45°), **THEN** `target_in_range = false` and the tower does not fire that cycle.

- **[Logic — BLOCKING]** **GIVEN** a narrow-cone tower at cell (8,6) facing south with `attack_range_cells=4` and `cone_half_angle=30°`, **WHEN** an enemy is at cell (8,11) (Chebyshev distance = max(0,|11−6|) = 5, directly south — row 11 is the valid southern limit on a 16×12 grid), **THEN** `cone_range_bonus = +2` (30° < 45°), `effective_range = 6`, `target_in_range = (5 ≤ 6) AND (0° ≤ 30°) = true` and the tower fires. **AND GIVEN** the same tower with `cone_half_angle=90°` instead, **THEN** `cone_range_bonus = 0`, `effective_range = 4`, `target_in_range = (5 ≤ 4) = false` and the tower does not fire — confirming the range bonus only applies to narrow cones. *(Formula 2 — cone range bonus)*

- **[Logic — BLOCKING]** **GIVEN** a Foundation component with `hp_base=220.0` at Tier 2 (`tier_multiplier=1.5`), **WHEN** the formula is evaluated, **THEN** `tower_max_hp = 330.0`.

- **[UI — ADVISORY]** **GIVEN** a tower with `tower_max_hp=330.0`, **WHEN** the wave begins and the tower enters `IDLE`, **THEN** the Mission HUD HP bar (if displayed) reflects the full 330.0 HP value. *(Evidence: manual walkthrough. Implementation note: the Tower System does not expose a public HP polling API — Rule 25. The HUD derives displayed HP from `tower_damaged` events (Rule 22) and infers the reset from `wave_completed`. The HUD must reconstruct: at `wave_completed`, infer current HP = `max_hp` field from the last `tower_damaged` payload for this tower. No polling required.)*

- **[Logic — BLOCKING]** **GIVEN** a tower at 120 HP takes 120 damage from a boss attack in a single hit, **WHEN** the damage resolves, **THEN** the tower enters `DESTROYED` in the same frame, `tower_destroyed` fires with `tower_id`, `grid_position`, `archetype`, and `footprint` in the payload, and the footprint cells return `PLACEABLE` via `Grid.get_cell_type()` immediately.

- **[Logic — BLOCKING]** **GIVEN** a tower survives a wave at 1 HP (verified by a preceding `tower_damaged` event showing `current_hp = 1.0`), **WHEN** `wave_completed` fires and `tower_wave_summary` emits for that tower, **THEN** `tower_wave_summary.max_hp` equals `hp_base × tier_multiplier`, AND the next `tower_damaged` event for that tower (if a boss attacks in the next wave) shows `current_hp` consistent with starting from full HP. HP reset is verified solely through EventBus observables — no internal state polling and no `_test_current_hp` field. *(Rule 23 — HP reset; Rule 25 — no public HP polling API)*

- **[Logic — BLOCKING]** **GIVEN** `base_cost=20`, `archetype_cost_factor=1.0`, `tier_cost_factor=1.5`, **WHEN** the placement cost formula is evaluated, **THEN** `placement_cost = round(20 × 1.0 × 1.5) = 30`.

- **[Integration — BLOCKING]** **GIVEN** `MissionEconomy.can_afford(30)` returns `true` for a tower with `placement_cost=30`, **WHEN** the player confirms placement and `Grid.place_tower()` returns `OK`, **THEN** `resources_changed(-30, "tower_placement")` fires before `tower_placed`, and `MissionEconomy.get_gold_balance()` reflects the debit by the time any `tower_placed` subscriber reads it. *(Rule 9 — placement-cost debit emission, added during `/design-system` 2026-07-14, closes OQ-10's debit-side gap. Requires EventBusSpy or equivalent ordering-observable test harness to verify emission order.)*

- **[Logic — BLOCKING]** **GIVEN** the same tower is placed with the above cost, **WHEN** placement is confirmed, **THEN** exactly 30 gold is deducted from `MissionEconomy`'s balance. *(Retagged BLOCKING→DEFERRED during `/design-review` 2026-07-14 pending Resource Economy's undesigned resource interface — see OQ-5 — then retagged back to BLOCKING during `/design-system` 2026-07-14 once `resource-economy.md` Rule 10 + ADR-0018's `MissionEconomy` defined that interface. Now runnable via the AC directly above this one.)*

- **[Logic — BLOCKING]** **GIVEN** a tower is destroyed by a boss mid-wave, **WHEN** the mission ends (VICTORY or DEFEAT), **THEN** all 4 component items from that tower are present in the player's inventory with the `damaged` flag set to `true`, and none of those components can be equipped to a tower **while `damaged == true`**. *(Corrected 2026-07-15: this AC's original "…until repaired at the Sanctuary" clause was untestable — no repair mechanic exists anywhere to clear the flag, see OQ-12. The AC now asserts only what this GDD can actually guarantee: the flag is set and enforced as non-equippable. Clearing the flag is out of scope until a repair-owning system is designed.)*

- **[Logic — BLOCKING]** **GIVEN** two enemies in range where Enemy A is furthest along path and Enemy B has the lowest HP, AND the tower's Focus component is set to `LOWEST_HP` mode, **WHEN** the tower evaluates targeting, **THEN** it selects Enemy B, confirming the Focus component replaces (not modifies) the default priority.

- **[Logic — BLOCKING]** **GIVEN** a HOMING projectile is in flight and its target dies, AND a second valid target exists within the tower's range and cone at that moment, **WHEN** target death is processed, **THEN** the projectile re-acquires the second target and continues toward it.

- **[Logic — BLOCKING]** **GIVEN** a BALLISTIC projectile is in flight and its target dies before impact, **WHEN** the projectile arrives at the last-known target position with no living enemy there, **THEN** no damage instance is created and the projectile terminates without error.

- **[Integration — BLOCKING]** **GIVEN** a tower placed during SCOUT Phase (`pre_placement_perk_activated` fires once), **WHEN** the player removes it and re-places it still within SCOUT Phase at a different cell, **THEN** `pre_placement_perk_activated` fires exactly once more (total: twice across both placements), the perk is not stacked or doubled, and `placed_in_scout=true` on the re-placement.

- **[Integration — BLOCKING]** **GIVEN** a tower is active during `WAVE_ACTIVE`, **WHEN** the player submits a removal action, **THEN** the tower remains on the grid with its current HP unchanged, no components are returned to inventory, and neither `tower_removed` nor `tower_destroyed` fires.

- **[Integration — BLOCKING — DEFERRED]** **GIVEN** a constellation pattern requires 4 towers and all 4 are placed, **WHEN** `tower_removed` fires for one of them during INTERMISSION, **THEN** `constellation_deactivated` fires within the same EventBus dispatch cycle as `tower_removed`. *(Not testable until the Constellation System GDD is authored and reviewed. Do not assign to a sprint until that gate is cleared.)*

- **[Integration/Performance — BLOCKING]** **GIVEN** 20 towers are placed with staggered attack timers, **WHEN** a wave starts and all towers resume TARGETING simultaneously, **THEN** the peak `tower_attacked` event count per frame does not exceed `eventbus_batch_threshold` (currently: 20 events/frame). **Prerequisite:** (a) `eventbus_batch_threshold` must be registered as a constant in `entities.yaml` before this AC is sprint-assignable. (b) GUT test must use injected fixed delta (`_process(1.0 / 60.0)`) to simulate one frame, and a GUT EventBusSpy must count emissions between `_process()` calls. Do not assign to a sprint until EventBusSpy and the constant are confirmed in the codebase.

- **[Logic — BLOCKING]** **GIVEN** a valid tower footprint where `PathfindingSystem.would_block_all_paths()` returns `true`, **WHEN** the player confirms placement, **THEN** no Grid write occurs, no `tower_placed` event fires, the resource balance is unchanged, the footprint cells flash red, and a distinct path-blocked cursor indicator appears. *(Rule 9c — game-state correctness; see separate UX AC above for HUD text verification)*

- **[UI — ADVISORY]** **GIVEN** a tower with a Focus component with `cone_half_angle = 45°` and `attack_range_cells = 4`, **WHEN** the placement ghost is active during SCOUT or INTERMISSION, **THEN** the ghost renders a cone arc overlay showing a 45° wedge centered on `facing_direction` with its boundary at `effective_range = min(9, 4 + 1) = 5` cells from the tower anchor. *(Visual/Audio — Cone arc overlay mandate. Evidence: screenshot, lead sign-off.)*

- **[Logic — BLOCKING]** **GIVEN** a mission session where 5 towers are placed in sequence, **WHEN** each tower is assigned a `tower_id`, **THEN** all 5 IDs are unique sequential integers (0, 1, 2, 3, 4), no two active towers share an ID, and a subsequently destroyed tower's ID is not reused for any new tower placement within the same mission. *(Rule 11a)*

- **[Logic — BLOCKING]** **GIVEN** two towers placed simultaneously — Tower A with Focus set to `LOWEST_HP` and Tower B with Focus set to `HIGHEST_HP` — and both having the same set of valid targets in range, **WHEN** both towers evaluate targeting on the same attack-timer expiry, **THEN** Tower A selects the enemy with the lowest current HP and Tower B selects the enemy with the highest current HP, confirming Focus component targeting mode is read and applied independently per tower. *(Rule 14 / Rule 15)*

- **[Logic — BLOCKING]** **GIVEN** two towers placed simultaneously (tower_id 0 and tower_id 1), **WHEN** `wave_started` fires with N = 2 active towers, **THEN** each tower's attack timer is initialized using stratified allocation: tower_id 0 receives `stagger_offset = (0 + 0.5) × (0.2 / 2) = 0.05s`; tower_id 1 receives `stagger_offset = (1 + 0.5) × (0.2 / 2) = 0.15s`. First-shot timestamps differ by exactly 0.10s (verified by recording timestamps). *(Rule 17a — stratified stagger)*

- **[Logic — BLOCKING]** **GIVEN** a Ranged archetype tower (HOMING projectile) and an Elemental archetype tower (BALLISTIC projectile) both fire at the same target simultaneously, and the target dies before either projectile arrives, **WHEN** target death is detected, **THEN** the HOMING projectile re-acquires the next highest-priority target in range (or dissipates if none) and the BALLISTIC projectile continues to the target's last-known position without re-acquiring. *(Rule 19)*

- **[Logic — BLOCKING]** **GIVEN** a Scout Phase with `MissionEconomy.get_gold_balance() == 0`, **WHEN** the player attempts to confirm any additional tower placement, **THEN** `MissionEconomy.can_afford(placement_cost)` returns `false`, the placement is rejected at the resource check gate (Rule 9a) before any Grid or Pathfinding call, no `tower_placed` event fires, and the balance remains at 0. *(Resource gate during Scout Phase. Retagged BLOCKING→DEFERRED during `/design-review` 2026-07-14 — see OQ-5 — then back to BLOCKING during `/design-system` 2026-07-14 once the Resource Economy interface was defined.)*

- **[Logic — BLOCKING]** **GIVEN** a tower survives wave N at less than full HP, **WHEN** `wave_completed` fires and then `wave_started` fires for wave N+1, **AND WHEN** a synthetic `boss_tower_attack_attempted` event is injected in wave N+1 with `target_tower_id` matching this tower and `base_damage = 1.0`, **THEN** the resulting `tower_damaged` event shows `current_hp = max_hp - 1.0`, confirming the HP reset occurred before the injected attack. *(Rule 24 — HP reset verified via synthetic boss attack injection rather than conditional observation)*

- **[Logic — BLOCKING]** **GIVEN** three monsters in range with `entity_id` values 0, 5, and 12, and a Focus component set to `SPAWN_ORDER` mode, **WHEN** the tower evaluates targeting, **THEN** it selects the monster with `entity_id = 0` (lowest `entity_id` in range), regardless of their relative path positions or HP values. **AND WHEN** the monster with `entity_id = 0` dies and monsters 5 and 12 remain in range, **THEN** the tower selects `entity_id = 5` on its next attack cycle. *(Rule 15 — SPAWN_ORDER targeting)*

- **[Logic — BLOCKING]** **GIVEN** a Focus component set to `SCATTER` mode, a `_scatter_index` initialized to 0, and exactly 3 valid targets with `entity_id` values [0, 5, 12] in range, **WHEN** the tower evaluates targeting 9 consecutive attack cycles, **THEN** the target selection sequence is exactly [0, 5, 12, 0, 5, 12, 0, 5, 12] — confirming the round-robin cycle and wraparound. **AND WHEN** target `entity_id=5` leaves range after cycle 4, reducing candidates to [0, 12], **THEN** cycles 5–7 produce [0, 12, 0] — confirming graceful reduction without error. *(Rule 15 — SCATTER deterministic cycle; no RNG involved)*

- **[Logic — BLOCKING]** **GIVEN** a Support archetype tower is active and `wave_started` fires, **WHEN** the attack timer expires with zero enemies within `aura_radius_cells`, **THEN** `tower_aura_pulse` fires with the correct `tower_id` and `aura_effect_type` in the payload. No valid monster target is required. *(Rule 17 Support exception)*

- **[Logic — BLOCKING]** **GIVEN** a monster reaches the GOAL and `monster_breached` fires for that `entity_id`, AND a second valid target remains in range and cone for a tower whose `_current_target_id` matched the breached entity, **WHEN** the next attack timer expiry occurs, **THEN** the tower's next `tower_attacked` event (if any fires) never names the breached `entity_id` as its target, and instead targets the remaining valid entity — confirmed via EventBusSpy asserting zero `tower_attacked` events reference the breached `entity_id` across the subsequent 3 attack cycles. **AND GIVEN** no other valid target exists after the breach, **THEN** no `tower_attacked` fires for that tower on the next attack-timer expiry. *(Rule 14a — monster_breached cache hygiene. Rewritten during `/design-review` 2026-07-14 re-review from a direct `_monster_cache.has()` assertion to an EventBus-observable assertion, consistent with this GDD's own no-internal-state-polling precedent — see the HP-reset AC's "no internal state polling and no `_test_current_hp` field" clause.)*

- **[Integration — BLOCKING]** **GIVEN** a mission ends (VICTORY or DEFEAT) where 2 towers were destroyed mid-wave and 1 tower survived, **WHEN** the player returns to the Sanctuary and opens component inventory, **THEN** all 8 component items from the 2 destroyed towers are present with `damaged = true`, and all 4 component items from the surviving tower have `damaged = false`. Loading a fresh mission session restores these `damaged` flags correctly from save data — the `damaged` state survives a save/load cycle. *(Rule 24 — damaged component round-trip)*

- **[Logic — BLOCKING]** **GIVEN** a boss attack event `boss_tower_attack_attempted` is in the EventBus queue at the moment `wave_completed` fires, **WHEN** the Tower System processes the stale boss attack event (whose `wave_id` does not match the now-completed wave), **THEN** the Tower System discards the event, no HP damage is applied, and `tower_damaged` does NOT fire for that tower. *(Rule 22 — wave_id staleness validation)*

- **[Logic — BLOCKING]** **GIVEN** `wave_started` fires with zero active towers on the field (N = 0), **WHEN** the Tower System processes the stagger allocation, **THEN** no division-by-zero error occurs, no stagger offset is assigned, and the system proceeds without error. *(Rule 17a — N=0 guard)*

- **[Logic — BLOCKING]** **GIVEN** a valid tower footprint where `PathfindingSystem.would_block_all_paths()` returns `true`, **WHEN** the player confirms placement, **THEN** a transient HUD text element displaying "Path would be blocked" appears and is no longer visible after 1.5 seconds, AND the cursor displays a visual state distinct from the standard cell-type rejection cursor state. *(Rule 9c — path-guard UX)*

- **[Logic — BLOCKING]** **GIVEN** a Scout Phase tower (`placed_in_scout=true`, perk active) is voluntarily removed during INTERMISSION and an identical-archetype tower is placed during the same INTERMISSION, **WHEN** placement is confirmed, **THEN** `placed_in_scout=false` on the replacement, `pre_placement_perk_activated` does NOT fire, and the perk badge does NOT appear. Perk forfeiture on Intermission re-placement is unconditional. *(Rule 13 — unconditional perk forfeiture)*

- **[Logic — BLOCKING]** **GIVEN** a RANGE_BOOST Foundation component with `perk_power = 0.05` (below the 0.0625 dead-zone floor — yields `round(0.05 × 8) = 0` cells), **WHEN** it is loaded, **THEN** a load-time error is raised and the component is not equippable. **AND GIVEN** `perk_power = 0.0625` (at the floor), **THEN** no load-time error, and `round(0.0625 × 8) = round(0.5) = 1` cell is added to `attack_range_cells`. **AND GIVEN** an AURA_EXTEND perk with `perk_power = 0.08` (below the 0.10 floor — yields `round(0.08 × 6) = 0` cells), **WHEN** loaded, **THEN** a load-time error is raised. **AND GIVEN** `perk_power = 0.10`, **THEN** no load-time error, and `round(0.10 × 6) = round(0.6) = 1` cell is added to `aura_radius_cells`. *(Rule 12a — perk dead-zone floors: RANGE_BOOST ≥ 0.0625, AURA_EXTEND ≥ 0.10)*

- **[Logic — BLOCKING]** **GIVEN** a HOMING projectile is in flight at the moment its originating tower's HP reaches 0 (same frame as destruction), **WHEN** the projectile attempts a re-acquisition callback, **THEN** it reads the originating tower's `_is_destroyed` flag as `true` and aborts the callback without calling any method on the (potentially deferred-freed) tower node. *(Rule 19 — _is_destroyed flag)*

- **[Logic — BLOCKING]** **GIVEN** `wave_started` fires with exactly N = 1 active tower, **WHEN** the Tower System assigns a stagger offset, **THEN** that tower receives `stagger_offset = (0 + 0.5) × (0.2 / 1) = 0.10s` with no division error or index-out-of-bounds. *(Rule 17a — N=1 stagger edge case)*

- **[Logic — BLOCKING]** **GIVEN** `wave_started` fires with N = 0 active towers, **WHEN** the stagger guard executes, **THEN** a test-observable flag (GUT spy or logged output) confirms the early-return path fired BEFORE any slot-width division — not merely that "no crash occurred." *(Rule 17a — N=0 guard path verification)*

- **[Logic — BLOCKING]** **GIVEN** a tower with `SCATTER` Focus and `_scatter_index = 7` (mid-cycle state), and a candidate pool of 5 targets with `entity_id` [0, 2, 4, 6, 8], **WHEN** the tower evaluates targeting, **THEN** it selects `entity_id = 4` (index 7 mod 5 = 2) and `_scatter_index` advances to 8. **AND GIVEN** the same tower at `_scatter_index = 7` with an empty candidate pool (all targets left range), **WHEN** targeting is evaluated, **THEN** no shot fires and `_scatter_index` remains at 7 (no increment on empty pool). *(Rule 15 — SCATTER _scatter_index counter behavior)*

- **[Logic — BLOCKING]** **GIVEN** a HOMING projectile is in flight and its originating tower's HP reaches 0 in the same frame, AND the projectile's original target is still alive, **WHEN** the projectile's next re-acquisition callback runs (same frame as the tower's destruction), **THEN** the callback aborts without steering toward a new target — confirmed by the projectile's flight-path heading being unchanged across the next 2 frames (no course correction toward any alternate live target) — and without raising a GUT null-access error, confirming the tower's destruction state is visible to the projectile without requiring a test-only read of an internal flag. *(Rule 19 — `_is_destroyed` set before `queue_free()`, verified via projectile behavior. Rewritten during `/design-review` 2026-07-14 re-review from a direct GUT-hook read of `_is_destroyed` to an EventBus/behavior-observable assertion, consistent with this GDD's own no-internal-state-polling precedent.)*

- **[Logic — BLOCKING]** **GIVEN** a HOMING projectile is in flight at the moment its originating tower's HP reaches 0, **AND** the target also dies simultaneously, **WHEN** both events resolve, **THEN** the projectile dissipates without dealing damage and without calling any method on the freed tower node — verified by confirming no `tower_attacked` event fires after destruction and no GUT null-access error is raised. *(Rule 19 — HOMING projectile dissipation on simultaneous tower + target death; `_is_destroyed` flag supersedes `is_instance_valid()` for this path)*

- **[Logic — BLOCKING]** **GIVEN** a tower takes no boss damage during a wave (no `tower_damaged` events fire for that tower_id), **WHEN** `wave_completed` fires and `tower_wave_summary` emits, **THEN** the Mission HUD can reconstruct the tower's full HP solely from `tower_wave_summary.max_hp` without reading any Tower System state or polling any API. Verified by asserting `tower_wave_summary.max_hp == hp_base × tier_multiplier`. *(Rule 23 — HP reset inference for zero-damage towers)*

- **[Logic — BLOCKING]** **GIVEN** a GUT test fixture that emits `boss_tower_attack_attempted` with `wave_id = 0` AFTER `wave_completed` has incremented `current_wave_id` to 1, **WHEN** the Tower System processes this injected event, **THEN** no `tower_damaged` event fires and no HP is deducted — confirming `wave_id` staleness detection is verifiable via explicit injection. *(Rule 22 — wave_id staleness test fixture)*

- **[Logic — BLOCKING]** **GIVEN** a Support tower emits `tower_aura_pulse`, **WHEN** the payload is inspected, **THEN** the event carries a `TowerAuraPulseEvent` Resource instance with all four fields present and valid: `tower_id: int`, `aura_effect_type: String` (non-empty), `aura_effect_value: float` (≥ 0.0), `aura_radius_cells: int` ([1, 6]). *(Rule 5a — TowerAuraPulseEvent payload completeness)*

- **[Logic — BLOCKING]** **GIVEN** a Foundation component with `attack_speed = 3.5` and a `SPEED_BOOST` perk with `perk_power = 0.25` (boosted speed = 4.375 > 4.0 cap), **WHEN** it is loaded, **THEN** a load-time WARNING (not hard error) is emitted indicating partial perk benefit waste. **AND GIVEN** `attack_speed = 3.0` with `perk_power = 0.25` (boosted speed = 3.75 ≤ 4.0), **THEN** no warning is emitted. *(Rule 12a — SPEED_BOOST load-time warning boundary)*

- **[Logic — BLOCKING]** **GIVEN** a Support tower with `base aura_radius_cells = 6` (the schema ceiling) and an `AURA_EXTEND` perk with `perk_power = 0.25`, **WHEN** the perk activates at placement, **THEN** `aura_radius_cells = min(6, 6 + round(0.25 × 6)) = min(6, 6 + 2) = min(6, 8) = 6` — the clamp prevents the value from exceeding 6. **AND GIVEN** `base aura_radius_cells = 4` with the same `perk_power = 0.25`, **THEN** `aura_radius_cells = min(6, 4 + 2) = 6` (no clamp triggered; result at ceiling, not above it). *(Rule 12a — AURA_EXTEND `min(6, ...)` clamp at schema ceiling)*

- **[Logic — BLOCKING]** **GIVEN** a Support tower with `base aura_radius_cells = 6` and an `AURA_EXTEND` perk with `perk_power = 0.25` (boosted radius = 8 > 6 cap), **WHEN** it is loaded, **THEN** a load-time WARNING (not hard error) is emitted indicating partial perk benefit waste. **AND GIVEN** `base aura_radius_cells = 3` with `perk_power = 0.25` (boosted radius = 5 ≤ 6), **THEN** no warning is emitted. *(Rule 12a — AURA_EXTEND load-time warning boundary, added 2026-07-15 during `/review-all-gdds` follow-up — mirrors the existing `SPEED_BOOST` warning pattern, previously missing for this perk)*

- **[Logic — BLOCKING]** **GIVEN** a Focus component with `base attack_range_cells = 7` and a `RANGE_BOOST` perk with `perk_power = 0.25` (boosted range = 9 > 8 cap), **WHEN** it is loaded, **THEN** `attack_range_cells = min(8, 7 + round(0.25 × 8)) = min(8, 9) = 8` and a load-time WARNING (not hard error) is emitted indicating partial perk benefit waste. **AND GIVEN** `base attack_range_cells = 5` with `perk_power = 0.25` (boosted range = 7 ≤ 8), **THEN** no clamp triggers and no warning is emitted. *(Rule 12a — RANGE_BOOST `min(8, ...)` clamp and load-time warning boundary, added 2026-07-15 during `/review-all-gdds` follow-up — this perk previously had neither a clamp nor a warning, unlike the other three perk types.)*

- **[Integration — BLOCKING]** **GIVEN** the Tower System subscribes to `monster_spawned` with **Synchronous** mode (as required by Rule 14a subscription table), **WHEN** a `monster_spawned` event fires in the same frame as `wave_started` processing, **THEN** the cache entry for that entity is present in `_monster_cache` immediately — mid-frame, within the same dispatch cycle as `monster_spawned` — so that any targeting evaluation on that same frame can see the newly-spawned entity. Verified by a GUT test that emits `monster_spawned` and immediately asserts `_monster_cache.has(entity_id) == true` before yielding to the next frame. *(Rule 14a — Synchronous `monster_spawned` subscription prevents SPAWN_ORDER cold-frame miss on the first spawn of each wave)*

- **[Integration — BLOCKING]** **GIVEN** a completed prior mission (Mission A) left a tower's `_monster_cache` populated with entries, AND `mission_phase_changed` fires with `new_phase = SCOUT` for a new mission (Mission B), **WHEN** the first `monster_spawned` event of Mission B fires (assigning `entity_id = 0` per Rule 11a's per-mission ID reset) and a tower with `SPAWN_ORDER` Focus evaluates targeting, **THEN** the tower's resulting `tower_attacked` event targets `entity_id = 0` (Mission B's monster) and never targets any `entity_id` carried over from Mission A — confirming no stale cache entries influence targeting after the mission-start clear. **AND GIVEN** the same setup but with `previous_phase = OUTCOME` (a victory, not a DEFEAT retry), **THEN** the clear and targeting behavior are identical — confirming the OUTCOME→SCOUT case is covered. *(Rule 14a — mission-start cache clear via `mission_phase_changed`. Rewritten during `/design-review` 2026-07-14 re-review from a direct `_monster_cache` entry-count assertion to an EventBus-observable assertion, and extended to explicitly cover the OUTCOME→SCOUT case that the prior rule wording had missed — see Rule 14a's corrected condition.)*

- **[Logic — BLOCKING]** **GIVEN** a tower with `hp_base = 200.0` and `tier_multiplier = 2.0` (max_hp = 400.0) takes 50 damage from a boss, **WHEN** `tower_damaged` fires, **THEN** the payload contains `max_hp = 400.0`, `current_hp = 350.0`, and `damage_dealt = 50.0`. *(Rule 22 — tower_damaged payload completeness)*

- **[Logic — BLOCKING]** **GIVEN** a tower fires 7 successful shots and has 3 attack-timer expirations with no valid target during a wave, **WHEN** `wave_completed` fires and `tower_wave_summary` emits, **THEN** `shots_fired = 7`, `idle_ticks = 3`, and `damage_dealt` equals the sum of all `damage_dealt` fields across those 7 `tower_attacked` events. *(Rule 23 — tower_wave_summary counter accuracy)*

- **[Logic — BLOCKING]** **GIVEN** a tower accumulates `shots_fired = 12`, `damage_dealt = 840.0`, and `idle_ticks = 5` during wave N, **WHEN** `wave_started` fires for wave N+1, **THEN** all three counters reset to 0 before any attack occurs — confirmed by reading `tower_wave_summary` at wave N+1 end and verifying it reflects only wave N+1 activity. *(Rule 23 — counter reset on wave_started)*

- **[Logic — BLOCKING]** **GIVEN** a Tier 4 Foundation (`tier_dps_multiplier = 4.0`, `tier_cost_factor = 4.0`) and a Tier 1 Foundation (`tier_dps_multiplier = 1.0`, `tier_cost_factor = 1.0`), both with identical Weapon components (`weapon_damage = W`, `attack_speed = S`), **WHEN** DPS/cost ratios are computed (`DPS = W × S × tier_dps_multiplier`, `cost = base_cost × tier_cost_factor`), **THEN** T4 ratio = T1 ratio = 1.00, confirming T4 is a specialist ceiling tier sharing DPS/cost parity with T1. *(Formula 1 — T4 economy with tier_cost_factor = 4.0)*

- **[Logic — BLOCKING]** **GIVEN** a T4 tower (`tier_boss_dps_multiplier = 2.0`, `weapon_damage = 50.0`, `attack_speed = 2.0`, `tier_dps_multiplier = 4.0`) fires at a `[BOSS]`-tagged enemy, **WHEN** boss DPS is computed, **THEN** `tower_boss_dps = 50 × 2.0 × 4.0 × 2.0 = 800.0`. **AND GIVEN** a T3 tower with identical Weapon (`tier_dps_multiplier = 2.4`, `tier_boss_dps_multiplier = 1.0`) fires at the same boss, **THEN** `tower_boss_dps = 50 × 2.0 × 2.4 × 1.0 = 240.0`. T4 boss DPS = 3.33× T3 boss DPS, confirming the boss-lane advantage. *(Formula 1 — T4 boss multiplier)*

- **[Logic — BLOCKING]** **GIVEN** a Tier 4 Foundation (`tier_multiplier = 2.5`, `tier_cost_factor = 4.0`) and Tier 1 (`tier_multiplier = 1.0`, `tier_cost_factor = 1.0`), **WHEN** HP/cost ratios are computed (normalized to T1 = 1.00), **THEN** T4 HP/cost = `2.5 / 4.0 = 0.625`, confirming the 37.5% HP-efficiency penalty. *(Formula 3 — T4 HP/cost penalty)*

- **[Logic — BLOCKING]** **GIVEN** two SCATTER-mode tower instances both placed on the same wave, each with `_scatter_index = 0`, and each facing the same 4-target pool [entity_id 0, 1, 2, 3], **WHEN** each evaluates targeting 8 consecutive attack cycles independently, **THEN** both produce the identical sequence [0, 1, 2, 3, 0, 1, 2, 3] — confirming that SCATTER is index-driven and identical state produces identical output across tower instances. *(Rule 15 — SCATTER determinism: same _scatter_index and same candidate pool produces identical sequence)*

- **[Logic — BLOCKING]** **GIVEN** a SCATTER-mode tower fires at 3 targets (entity_id 0, 5, 12) across 6 attack cycles — hitting entity 0 twice, entity 5 twice, and entity 12 twice — **WHEN** `wave_completed` fires and `tower_wave_summary` emits for that tower, **THEN** `tower_wave_summary.scatter_target_cycle` equals `{0: 2, 5: 2, 12: 2}` — a Dictionary mapping each targeted entity_id to its hit count for the wave. Entities never targeted must not appear as keys. **AND GIVEN** a non-SCATTER tower (any other targeting mode), **THEN** `scatter_target_cycle` is an empty Dictionary `{}`. *(Rule 23 — `scatter_target_cycle: Dictionary[int, int]` field population in TowerWaveSummary)*

- **[Logic — BLOCKING]** **GIVEN** a SCATTER-mode tower with `_scatter_index = 3` and `_last_scatter_target_id = 12` (having just fired at `entity_id=12`, its third target from an original 4-candidate pool `[0, 5, 12, 20]`), AND targets `entity_id=5` and `entity_id=20` both leave range before the next cycle, reducing the candidate pool to `[0, 12]`, **WHEN** the tower evaluates targeting, **THEN** the naive computation `_scatter_index mod len(candidates) = 3 mod 2 = 1` would select `candidates[1] = entity_id=12` — a repeat of `_last_scatter_target_id` — so the repeat-guard activates (pool size 2 ≥ 2) and the tower instead targets `candidates[(1+1) mod 2] = candidates[0] = entity_id=0`. `_scatter_index` advances to 4 and `_last_scatter_target_id` updates to `0`. **AND GIVEN** the pool instead shrinks to a single candidate `[12]` under the same `_last_scatter_target_id = 12`, **THEN** the repeat-guard does not apply (pool size 1), and the tower re-targets `entity_id=12` — confirming the single-candidate case is an intentional exception, not a bug. *(Rule 15 — SCATTER repeat-guard, added during `/design-review` 2026-07-14 re-review, closes a confirmed bug where a shrinking candidate pool could cause a same-target repeat contradicting Rule 15's own stated behavior)*

- **[Logic — BLOCKING]** **GIVEN** each of the following component fields loaded with a value one increment outside its documented valid range — `weapon_damage = 7.9` (below [8.0, 120.0]), `attack_speed = 4.01` (above [0.5, 4.0]), `hp_base = 79.9` (below [80.0, 400.0]), `base_cost = 9` (below [10, 60]), `tier_cost_factor = 1.2` (not in {1.0, 1.5, 2.0, 4.0}), `tier_multiplier = 1.75` (not in {1.0, 1.5, 2.0, 2.5}), `tier_dps_multiplier = 2.0` (not in {1.0, 1.6, 2.4, 4.0}), `attack_range_cells = 9` (above [1, 8]), `cone_half_angle = 22.4` (below [22.5, 180.0]), `facing_direction = "NNE"` (not in the compass enum) — **WHEN** each component is loaded, **THEN** a load-time error is raised for that field and the component is not equippable. Each field must be independently verified by a dedicated test case; a single passing case does not imply the others pass. *(Edge Cases → Formula Boundary, load-time validation table — closes a gap where only perk-power dead-zones and the SPEED_BOOST cap warning had AC coverage; the 10 base component-stat fields had none)*

- **[Logic — BLOCKING]** **GIVEN** a Foundation component with `tier = 2` but `tier_multiplier = 1.0` (the Tier 1 value, mismatched against Tier 2's expected 1.5 per the tier cross-field consistency table), **WHEN** the component is loaded, **THEN** a load-time error is raised — confirming the five tier-indexed fields (`tier`, `tier_multiplier`, `tier_dps_multiplier`, `tier_cost_factor`, `tier_boss_dps_multiplier`) are cross-validated as a set, not independently. *(Edge Cases → Formula Boundary, tier cross-field consistency table — this named underpriced-tower exploit guard previously had zero AC coverage)*

- **[Logic — BLOCKING]** **GIVEN** a Foundation component with `tier = 4` and `base_cost = 35` (above the T4-specific ceiling of 30), **WHEN** the component is loaded, **THEN** a load-time error is raised and the component is not equippable. **AND GIVEN** `tier = 4` with `base_cost = 30` (at the ceiling), **THEN** no load-time error is raised. **AND GIVEN** `tier = 3` with `base_cost = 55` (above 30 but within the general [10,60] range and T3 is not subject to the T4-specific cap), **THEN** no load-time error is raised — confirming the `base_cost` ceiling applies only to `tier = 4` Foundations. *(Formula 4 / Edge Cases → Formula Boundary — T4 `base_cost ≤ 30` cap, added during `/design-review` 2026-07-14 re-review, resolves OQ-11's bimodal-affordability finding)*

## Open Questions

| # | Question | Owner | Status |
|---|---------|-------|--------|
| OQ-1 | **EventBus catalogue update — RESOLVED (actions required in EventBus GDD before implementation):** (a) `tower_placed` payload: add `archetype: String`, `footprint: Vector2i`, `placed_in_scout: bool`. (b) `tower_removed`: register as a new event with payload `tower_id: int`, `grid_position: Vector2i`, `archetype: String`. (c) `tower_destroyed`: add `archetype: String` to existing payload. (d) `boss_tower_attack_attempted`: register as a new event (owned by Monster System) with canonical payload `boss_entity_id: int`, `target_tower_id: int`, `base_damage: float`, `wave_id: int` (`wave_id` required for staleness validation). These payload definitions are treated as resolved by the Acceptance Criteria in this GDD. **`is_siege` on `tower_attacked` struck 2026-07-15**: the T4 Siege/boss-shield-penetration mechanic was removed (no boss-shield mechanic exists in monster.md) — see T4 Boss-Lane Identity section. | EventBus GDD author | **Resolved** — EventBus GDD update required before implementation |
| OQ-2 | **RESOLVED (2026-07-15d)** — Hero GDD update: Hero System currently subscribes to `tower_placed` and `tower_destroyed` for Tower Affinity. Must also subscribe to `tower_removed`. Hero GDD Rule 20 needs amendment. | Hero GDD author | Confirmed via `hero.md`'s Interactions table — `tower_removed` is already listed as subscribed. Stale item, no Hero GDD change needed. |
| OQ-3 | **`tower_attacked` payload completeness — RESOLVED, differently than originally proposed.** *(Found stale 2026-08-24, `/design-review --depth lean` re-review, S8-07 — `damage-status.md` has existed and answered this for some time, but this row was never updated.)* No `power_component_id` field was needed: `tower_attacked` instead carries `effect_type`/`effect_value`/`effect_duration` directly (forwarded from the firing tower's `PowerComponent` at fire time), so D&S/Monster System read the effect data straight off the payload with no registry lookup required. Confirmed against `damage-status.md`'s own Interactions table and Formula D5. | Damage & Status GDD author (done) | **Resolved** |
| OQ-4 | **Tower archetype content catalogue — RESOLVED for coverage (2026-08-27).** This GDD specifies the 4 tower archetypes (physical, ranged, elemental, support) and the component slot system. **Partial resolution (2026-05-01):** Support Weapon-slot semantics resolved — see Rule 5a. **2026-08-27:** `design/gdd/tower-content-catalogue.md` documented all 13 real shipped tower blueprints and found 2 real coverage gaps (no T3 physical/ranged/support; no T4 ranged/support). **Same-day follow-up:** authored the 5 missing towers (`warbreaker` physical-T3, `piercing_ballista` ranged-T3, `sanctified_standard` support-T3, `railgun_emplacement` ranged-T4, `grand_rally_spire` support-T4) against this GDD's existing Formula 1/2/4 math — every archetype now has one tower at every tier (18 total). Load-verified via a headless script: all 18 pass `TowerBlueprintData.validate()`, and the 5 new towers are reachable through the existing Planning Cluster UI with no code change (it pulls dynamically from `GameDataRegistry`). | Game Designer | **Resolved** — full T1–T4 coverage exists for all 4 archetypes; remaining open item is OQ-6 (2×2 footprint), not a coverage gap |
| OQ-5 | **Resource Economy resource type — RESOLVED.** *(Found stale 2026-08-24, `/design-review --depth lean` re-review, S8-07 — `resource-economy.md` has existed and answered this since 2026-07-14, but this row was never updated.)* The resource is **gold** (a scalar in-mission balance, owned by `MissionEconomy` per ADR-0018), not "build points" — placement-cost formulas in this doc should be read as gold costs. Total mission budget and per-wave earning rate are both defined (`resource-economy.md` Rule 8/Rule 10/Formula 5). | Resource Economy GDD author (done) | **Resolved** |
| OQ-6 | **2×2 footprint towers — which archetypes use them? Still open, now with hard evidence (2026-08-27).** The Grid System and this GDD both establish that 2×2 footprints are valid. `tower-content-catalogue.md` confirms **all 13 currently shipped blueprints use `footprint = Vector2i(1, 1)`** — zero precedent for a 2×2 tower exists anywhere in the real catalogue. This GDD also has no footprint-based cost multiplier defined, so a 2×2 tower isn't a drop-in retrofit — it needs a deliberate design pass (placement-cost scaling, grid-occupancy balance), not just picking an existing blueprint to resize. | Game Designer | Deferred to content catalogue — genuinely open, evidence-backed |
| OQ-7 | **towers_affinity_reference_count validation:** Registry constant is 16. The theoretical max towers on a default 16×12 grid with standard path/blocked cell distributions is ~30–60 PLACEABLE cells. Confirm during first mission layout design that 16 qualifying towers is achievable in a strong build but not trivially exceeded. | Level Designer (first mission layout) | Deferred to Level Design phase |
| OQ-8 | **`monster_breached` cache subscription — RESOLVED (2026-05-01):** Tower System now subscribes to `monster_breached` and evicts the entity from `_monster_cache` immediately on receipt (see Rule 14a). EventBus GDD must confirm `monster_breached` payload includes `entity_id: int` — verify before implementation. AC added (see Acceptance Criteria — "monster_breached cache hygiene"). | Monster System GDD author / Tower System author | **Resolved** — EventBus `monster_breached` payload confirmation required |
| OQ-9 | **game-concept.md conflict — WAVE_ACTIVE placement:** Tower System Rule 8 (revised 2026-05-01) blocks placement during WAVE_ACTIVE. `game-concept.md` Rule 5 still states "placing mid-wave is valid but forgoes that perk." **Required action before architecture phase:** Update `game-concept.md` Rule 5 body text and its WAVE_ACTIVE row in the States and Transitions table to reflect that mid-wave placement is blocked. Tower System Rule 8 is the authoritative spec. | Game Concept document author | **Resolved (Revision 7, 2026-05-08)** — `game-concept.md` Rule 5 updated; WAVE_ACTIVE placement blocked. No further action required. |
| OQ-10 | ~~**In-mission gold faucet gap (blocking, cross-cutting — added 2026-07-14):** ...~~ **RESOLVED (2026-07-14, same day)** — `resource-economy.md` Rule 10/Formula 5 now defines a per-wave gold grant (`gold_grant(w) = round(base_wave_gold × wave_reward_scalar(w))`, 20–95 gold, wave_completed-triggered) alongside the existing Scout starting grant, totaling ~375 gold across a default 6-wave mission — landing inside the existing 350–400 `mission_resource_budget` target. Tower System's own Rule 9 now emits the matching placement-cost debit (`resources_changed(-placement_cost, "tower_placement")`), closing the other half of the gap — previously Tower only read the balance, never debited it. The mechanical gap is closed. | Resource Economy GDD author (done) / Tower GDD author (done) | **Resolved (mechanical gap only)** — see OQ-11 for the unresolved pillar-level follow-up |
| OQ-11 | **T4 boss-lane viability & Intermission authorship weight — pillar-level concern, re-opened by `/design-review` full pass #2 (2026-07-14, Revision 13).** OQ-10's fix made gold *exist*, but didn't establish that T4 investment is a legible, vindicated decision rather than a blind gamble. **RESOLVED (2026-07-14, Revision 14) — two coordinated design decisions made by the user:** (1) **Boss-lane telegraph** — the Intermission wave preview now discloses spawn-cell information when the upcoming wave contains a boss (see Rule 8's Boss-lane telegraph), giving the player real spatial information to validate a T4 placement against before committing — exact boss stats remain hidden, preserving the existing meta-read intent for everything else. (2) **T4 `base_cost` cap** — any Tier 4 Foundation must have `base_cost ≤ 30` (see Formula 4 and the tier cross-field consistency table), which resolves the bimodal-affordability gap directly and, as a side effect, unifies the cost ceiling across all tiers (T3 and T4 now share the same MVP/post-MVP maximum, 120/240, instead of T4 alone reaching 480). The Sell-refund-softening and purchase-window-gating options were considered and **not selected** — the boss telegraph plus cost cap were judged sufficient to address both the legibility gap and the affordability gap without adding a tier-dependent refund formula. **Wave Manager side CLOSED (2026-07-15)** — `wave-manager.md`'s own scoped `/design-review` re-pass caught that the originally-specified `has_boss: bool` + `boss_entry_lane: StringName` fields were wrong (undefined "lane" vocabulary; `has_boss` redundant with existing data) and replaced them with a single always-present `boss_spawn_cell: Vector2i` field (Rule 11), backed by a new content constraint (Rule 6: boss entries must use explicit `spawn_cell_index`, no round-robin) and a new AC-42. This GDD's own text above and the Dependencies table were corrected to match. **Mission HUD side CLOSED (2026-07-15)** — `mission-hud.md`'s own `/design-review` session #2 found the event was entirely unhandled and added a new Group 3b (Rules 11a–11e): an outer-HUD-root-owned subscription (avoiding a per-cycle Planning Cluster instantiation race), a `Vector2i(-1,-1)` sentinel guard, and — resolving a tension between the "recede" guardrail and this OQ's own in-combat validation need — a single confirming pulse VFX at the telegraphed cell when the boss actually spawns there during WAVE_ACTIVE, rather than a persistent marker. **OQ-11 is now closed end-to-end across all three GDDs.** Mission HUD's own remaining items (PC-5 color/hue needs an Art Director decision; a UX spec update; camera-transform live-MCP verification) are tracked in `mission-hud.md`'s own status header, not blocking here. | Game Designer / Creative Director (decision made) — Wave Manager GDD author (done, 2026-07-15) — Mission HUD GDD author (done, 2026-07-15) | **Resolved end-to-end** |
| OQ-12 | **Damaged-component repair mechanic — FULLY CLOSED (2026-08-23).** Rule 24/29 establish that a tower destroyed mid-mission returns its 4 components to Inventory with `damaged: true` (see `inventory.md`'s `tower_component_returned` handling). `crafting.md` Rule 6 owns the repair mechanic: a Common-material-only cost scaled by `quality_tier` (Formula 3), ~50% of the fresh-craft cost, mutating `damaged: true → false` in place. **Correction**: this row previously said `Inventory.clear_damaged_flag()` didn't exist yet as of the 2026-07-17 review — it was actually implemented and tested (`inventory.gd`, `has_room_for()` too) well before this correction was made; the doc simply was never revisited after. `Crafting.resolve_repair()` (crafting.gd) was likewise already fully implemented and tested. The one real remaining gap closed 2026-08-23: no UI anywhere ever called either — `inventory_screen.gd`'s new Repair sub-tab (Crafting panel) is now the first real consumer, listing every damaged component with its repair cost and a Repair button. | Crafting GDD author / Inventory GDD author / UI (done, all 3) | Fully Resolved |
