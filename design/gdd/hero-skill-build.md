# Hero Skill Build System

> **Status**: Needs Revision — `/review-all-gdds` 2026-08-31 found this document still described the pre-revision Tower Mastery contract in several load-bearing places (Rules 14-17, States/Transitions, restore_order); fixed same day (see amendment below). **Second pass, same day**: a re-verification found one remaining leftover (line 373's "roadmap of what Tower Mastery can still unlock," corrected to Hero Skill Tree); no other issues found in this document specifically. Not yet re-verified a third time. Prior verdict (`/design-review --depth lean` 2026-07-17 — solves `game-concept.md`'s combinatorial-explosion risk via the category-count Ultimate derivation, closes `hero.md` OQ-3 and `event-bus.md`'s passive-slot open note; math independently re-derived and confirmed correct. This header was never updated to reflect that verdict — corrected here; see `systems-index.md` row 20 for full review history, including the 2026-08-25 `skill_power_coefficient`/`hero_skill_attacked` follow-up below.)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-09-01
> **Amendment (2026-09-01)**: Catalogue expanded from the Alpha-scope 8 skills (2/category) to a PoE-scale roster of 32 (8/category: `opener`/`opener`/`core`/`core`/`core`/`capstone`/`capstone`/`capstone` per category), per the player's explicit direction to design hero skills "think Path of Exile in terms of hero skills and complexity" (Group 1, Rule 3). `effect_data`'s schema formalized (no longer deferred): `damage_type`, `delivery`, `skill_power_coefficient`, `secondary_effect`, `tags` (Rule 2). New Rule 14 adds a 13-entry support-modifier catalogue (`sup_mod_*`), and Rule 13's passive slots gained a `requires_tag: String` check against the socketed skill's `tags`, retiring the previous untyped flat-pool model. Which 3 of each category's 8 skills a given character can ever reach is now governed by `hero-skill-tree.md`'s companion Choice-node redesign (its Rules 6–10) — see that document. The 35-profile/19-Ultimate-ID derivation (Formulas 1–3) is unchanged and re-confirmed catalogue-size-independent (AC-10c).
> **Amendment (2026-08-31)**: `/review-all-gdds` found this document had never been updated when `tower-mastery.md`'s Rule 13 was revised (also 2026-08-31, earlier the same day) to route through the new Hero Skill Tree System instead of unlocking skills directly. Fixed: Rules 14-17 (Group 4), the States/Transitions LOCKED-state rationale, the Interactions/Upstream Dependencies tables, `restore_order` (corrected from a stale "32, proposed" to this system's actual assigned 31), and AC-16/AC-17 all corrected to attribute `skill_unlocked` to Hero Skill Tree, not Tower Mastery, and to describe the actual current persistence/trigger model. No changes to this system's own core mechanics (the Ultimate derivation, slot model, passive system) — this was purely a stale-reference cleanup.
> **Implements Pillar**: Everything Connects · Mastery-as-Vindication
> **Solves**: `game-concept.md`'s explicitly-named Ultimate-combination combinatorial-explosion risk (35 raw category profiles → 19 fixed, provably-exhaustive Ultimate IDs, catalogue-size-independent). Closes `hero.md` OQ-3 and `event-bus.md`'s passive-slot open note. **Known gaps**: new Inventory `item_type="skill_modifier"` doesn't exist yet; 2 registry additions pending. See Open Questions.
> **Amendment (2026-08-25)**: `damage-status.md` Rule IX/Formula D7 (Skill Damage Pipeline, closing `TD-hero-001`) names one real field within this doc's still-deferred `effect_data` Resource: `skill_power_coefficient: float`. Group 1's `effect_data` row and Group 3 Rule 12's third bullet updated accordingly — the latter also corrects a real, previously-undetected inaccuracy: this doc claimed D&S consumes the resolved skill effect via `hero_skill_activated`, but that event is Hero System's own cast-trigger signal (Audio/HUD only) — the actual damage consumer is the distinct, newer `hero_skill_attacked` event. `effect_data`'s remaining format (target pattern, buff data) is still fully deferred content-authoring work, unaffected by this addition.

## Overview

The Hero Skill Build System is where the player converts the raw output of Tower Mastery into a committed, combat-ready loadout. It consumes the permanent skill *library* that Tower Mastery fills — every active and passive skill the hero has ever unlocked by learning from towers mid-combat — and exposes exactly four active slots (A, B, C, D) into which the player seats four learned skills at the sanctuary, out of combat. Technically it is both a configuration store and a derivation engine: it persists the player's slotted loadout, and from the specific combination of the four occupied slots it derives a single **Ultimate** ability via a deterministic lookup table — the player never selects the Ultimate directly, only the four ingredients that produce it, and changing any one active skill immediately recomputes the Ultimate from the new combination. To keep this combination space tractable rather than combinatorially explosive, the lookup resolves on the *categories* of the four slotted skills rather than their raw identities (exact bucketing mechanism owned by the systems-designer), so that a large library still maps onto a bounded, learnable set of Ultimates. Each active skill additionally exposes one or more **passive sub-slots** that modify how that skill behaves without themselves feeding the Ultimate derivation, giving the loadout a second, finer layer of customization beneath the four headline choices. Player-facing, the system turns a growing pile of individually earned skills into a single expressive build decision: the four slots are the hero's whole identity for a mission, and the Ultimate is the emergent payoff the player learns to predict, test, and eventually command with confidence.

## Player Fantasy

> You never pick your strongest move. You pick the four things it is made of — and then you learn to read what they become.
>
> Everything you carry into a mission, you earned one lesson at a time. Out on the field, under fire, you stood your ground beside tower after tower until each one taught you something it knew, and every skill it taught you went into a library that is yours for good. Tower Mastery is where that learning happened; this is where it *means* something. Here, in the quiet of the sanctuary, you stand in front of everything you have ever been taught and you choose the four skills you will actually carry — four slots, A through D, and no more. This is not the apprenticeship anymore. The teaching is done. This is the colder, more deliberate act of deciding what all of it was *for*.
>
> And here the sanctuary does something it has never done for you before. Everywhere else, you have been the one giving instructions: you author a tower and it holds exactly the decision you made, you arrange a constellation and it stands exactly as you placed it, you originate a component and it leaves the forge exactly as you specified. In every one of those systems, the sanctuary is obedient — it carries your instruction forward without adding a word of its own. This is the first system that *answers back*. You set your four skills, and the game returns a fifth thing you did not directly choose: an Ultimate, drawn from the specific combination of those four, that is more than any one of them and belongs to none of them alone. You did not pick it off a list of your best abilities. You assembled the four ingredients, and the Ultimate is what they became.
>
> The first time you feel it is the first time you swap a single slot expecting a small adjustment — and the Ultimate transforms into something else entirely. That is the moment the system stops being a menu and becomes a space you have to learn. Because the whole is not the sum here, and you cannot simply add your way to the answer. At the start you are half-blind: you slot four skills you like and you find out what they make, and sometimes what they make is a revelation and sometimes it is a warning. So you change one thing and watch what moves. You keep the combinations that answered well and you remember the ones that didn't. Slowly the space stops being a mystery and starts being a map — and the four slots, which felt like a cage the first time you filled them, become the most expressive decision the hero has, because every skill you seat is three others left on the shelf, and the Ultimate they conjure is your whole theory of the fight compressed into a single button.
>
> Then one day you stop experimenting. You stand in front of your library, you seat four specific skills with intention, and you already know — before the game confirms it — exactly what Ultimate they will produce, because you have learned to read the combination the way you once learned to read a wave. That is the vindication this system gives you that no sibling can. A tower is proof that you were right about a *place*. A constellation is proof that you were right about an *arrangement*. This is proof that you understood what your own choices would *become* before the game showed you — that you looked at four separate things you earned under fire and saw, correctly, the single thing they were always going to add up to.

## Detailed Design

### Core Rules

#### Group 1: Slots & Data Model

1. The hero has **4 active skill slots** (A, B, C, D) and a dedicated **Ultimate slot** (U), per `hero.md` Rule 8. All 5 are independent bindings; Hero Skill Build System owns the binding logic and the Ultimate derivation described in Group 3, while the Hero System applies the resolved values at runtime (see Dependencies).

2. **Skill catalogue data model.** Every skill in the catalogue has exactly these fields:

   | Field | Type | Valid Values | Description |
   |---|---|---|---|
   | `skill_id` | String | unique across catalogue | Stable identifier, referenced by Hero Skill Tree's `skill_unlocked` (corrected 2026-08-31, was Tower Mastery's) and this system's slot bindings |
   | `category` | String | `physical` / `ranged` / `elemental` / `support` | **Matches `tower.md`'s Foundation `archetype` enum exactly** (same 4 values, same strings) — this is the categorical bucketing axis the Ultimate derivation (Group 3) depends on. Not a new taxonomy; deliberately reused from Tower's existing archetype vocabulary per the same "one invisible concept, one name" discipline `hero.md`/`tower-mastery.md` already apply to the shared 3-cell proximity radius. |
   | `passive_slot_count` | int | 1–3 | Number of passive slots this skill exposes (`hero.md` Rule 9) |
   | `mastery_source_build_signature` | String | any valid `build_signature` (`tower-mastery.md` Formula 4), or `""` | The build signature whose mastery track teaches this skill, per `tower-mastery.md` Rule 7's `source_build_signature` catalogue field. Hero Skill Build does not own or validate this mapping — it is authored once, in Tower Mastery's catalogue, and referenced here only so a single skill definition Resource can round-trip between both systems' content pipelines without duplication. Empty string is invalid for any skill actually reachable via mastery (content-authoring error, not a runtime-defensible case, mirroring `tower-mastery.md`'s own "two signatures mapping to one skill_id" precedent). **Vestigial at runtime after `hero-skill-tree.md`'s 2026-08-31 revision (flagged, not fixed here)**: a mastered build signature now feeds an archetype-wide skill tree point pool, not this specific `skill_id` directly — which skill a point ultimately buys is fixed by this catalogue's *order* within `hero-skill-tree.md`'s per-archetype node chain, not by which signature happened to earn the point. This field is retained as content-authoring/flavor reference (which signature a skill was thematically designed around) but no runtime system reads it to decide what a mastered signature unlocks anymore — same status as the analogous fields flagged in `tower-mastery.md` Rule 7. |
   | `effect_data` | `SkillEffectResource` (schema formalized 2026-09-01, PoE-scale content pass) | — | The actual gameplay effect. **No longer deferred** — every catalogued skill (Rule 3) now specifies real `effect_data`, not a flavor stub. Sub-fields: `damage_type: String` (`physical`/`fire`/`frost`/`poison`/`lightning`/`arcane` — reuses `tower.md`'s `WeaponComponent.element` vocabulary and `monster.md`'s `monster_elemental_resistances` verbatim, not a new taxonomy; `""` for non-damage support/buff skills), `delivery: String` (`melee_arc`/`projectile_pierce`/`projectile_spread`/`beam`/`aoe_zone`/`self_buff`/`totem`/`channel`), `skill_power_coefficient: float` (0.5–3.0, per-skill scalar applied against `effective_skill_power_final` before the shared crit/tier pipeline — mirrors Tower's `tier_dps_multiplier` role in Formula 1b; `damage-status.md` Rule IX/Formula D7's original field, unchanged in meaning), `secondary_effect: String` (`slow`/`knockback`/`armor_shred`/`dot_burn`/`dot_poison`/`chain`/`fork`/`stun`/`lifesteal_bonus`/`none`), `tags: Array[String]` (any of `Area`/`Projectile`/`Duration`/`Channeling`/`Totem`/`Melee`/`Ranged`/`Buff` — the axis Group 3's typed passive slots (revised, see below) check support-modifier compatibility against). Numeric tuning within these fields (exact coefficients, DoT tick rates, totem duration) remains a follow-on balance pass — this schema and Rule 3's catalogue fix *identity, delivery mechanism, and tags*, the same scope every other "structure, not final numbers" precedent in this project uses (Tower's component effect fields, Tower Mastery's `output`). |

3. **Expanded skill catalogue (2026-09-01, PoE-scale content pass — supersedes the original 8-skill Alpha catalogue).** 32 skills, 8 per category. Every skill also carries a `tier` field (`opener`/`core`/`capstone`) that `hero-skill-tree.md`'s revised choice-node chain (its own Rule 6/7) uses to group skills into that archetype's 3 mutually-exclusive Choice nodes — 2 openers, 3 core, 3 capstone per archetype, matching that document's own Choice_1/Choice_2/Choice_3 node structure exactly. This field is new to the schema (Rule 2) alongside `effect_data`'s formalized sub-fields.

   **Physical** (melee/bruiser identity):

   | `skill_id` | `tier` | `passive_slot_count` | `delivery` | `damage_type` | `secondary_effect` | `tags` | coeff. | Flavor |
   |---|---|---|---|---|---|---|---|---|
   | `phys_cleave` | opener | 1 | melee_arc | physical | none | Melee, Area | 1.2 | Wide arc swing in front |
   | `phys_rending_throw` | opener | 1 | projectile_pierce | physical | armor_shred | Projectile, Melee | 1.4 | Thrown weapon that bleeds armor |
   | `phys_shatter_slam` | core | 2 | melee_arc | physical | stun | Melee, Area | 2.0 | Heavy overhead slam |
   | `phys_whirling_assault` | core | 2 | channel | physical | none | Channeling, Melee, Area | 0.6/tick | Spin repeatedly while held |
   | `phys_juggernaut_charge` | core | 1 | melee_arc | physical | knockback | Melee, Duration | 1.1 | Gap-closer, brief knockback immunity on arrival |
   | `phys_bulwark` | capstone | 2 | self_buff | — | none | Buff, Duration | — | Armor spike + knockback resist |
   | `phys_iron_totem` | capstone | 2 | totem | physical | none | Totem, Area | 0.8/tick | Deploys a totem that melee-strikes nearby enemies |
   | `phys_last_stand` | capstone | 3 | self_buff | — | lifesteal_bonus | Buff, Duration | — | Huge armor/lifesteal, movement locked |

   **Ranged** (precision/projectile identity):

   | `skill_id` | `tier` | `passive_slot_count` | `delivery` | `damage_type` | `secondary_effect` | `tags` | coeff. | Flavor |
   |---|---|---|---|---|---|---|---|---|
   | `rng_piercing_shot` | opener | 1 | projectile_pierce | physical | none | Projectile | 1.3 | Pierces the first enemy hit |
   | `rng_hunters_mark_shot` | opener | 1 | projectile_pierce | physical | armor_shred | Projectile | 1.0 | Marks target, weakens armor |
   | `rng_volley` | core | 2 | projectile_spread | physical | none | Projectile, Area | 0.9 | Multi-projectile spread |
   | `rng_explosive_shot` | core | 2 | projectile_pierce | physical | knockback | Projectile, Area | 1.5 | Explodes on impact |
   | `rng_barrage` | core | 1 | channel | physical | none | Channeling, Projectile | 0.5/tick | Rapid-fire while held |
   | `rng_snipe` | capstone | 2 | projectile_pierce | physical | stun | Projectile | 2.5 | Charge-up single heavy shot |
   | `rng_ricochet_bolt` | capstone | 2 | projectile_pierce | physical | chain | Projectile | 1.1 | Bounces between enemies |
   | `rng_ranger_totem` | capstone | 2 | totem | physical | none | Totem, Projectile | 0.7/tick | Deploys an arrow-firing totem |

   **Elemental** (damage-type/status identity):

   | `skill_id` | `tier` | `passive_slot_count` | `delivery` | `damage_type` | `secondary_effect` | `tags` | coeff. | Flavor |
   |---|---|---|---|---|---|---|---|---|
   | `elem_frostbolt` | opener | 2 | projectile_pierce | frost | slow | Projectile | 1.2 | Single-target slow + damage |
   | `elem_poison_nova` | opener | 1 | aoe_zone | poison | dot_poison | Area | 0.9 | Self-centered poison burst |
   | `elem_firestorm` | core | 3 | aoe_zone | fire | dot_burn | Area, Duration | 1.0 | Delayed AoE burn zone |
   | `elem_arc_lightning` | core | 2 | beam | lightning | chain | Projectile | 1.1 | Chains between enemies |
   | `elem_channeled_inferno` | core | 2 | channel | fire | dot_burn | Channeling, Area | 0.6/tick | Continuous burn zone under hero |
   | `elem_glacial_totem` | capstone | 2 | totem | frost | slow | Totem, Area | 0.7/tick | Ice totem with frost bolts |
   | `elem_static_field` | capstone | 2 | aoe_zone | lightning | stun | Area, Duration, Buff | 0.5/tick | Periodic-stun damaging aura |
   | `elem_absolute_zero` | capstone | 3 | aoe_zone | frost | slow | Area | 1.8 | Big single nova, heavy slow |

   **Support** (utility/buff identity — can still hit hard, PoE Guardian-style):

   | `skill_id` | `tier` | `passive_slot_count` | `delivery` | `damage_type` | `secondary_effect` | `tags` | coeff. | Flavor |
   |---|---|---|---|---|---|---|---|---|
   | `sup_rally` | opener | 2 | aoe_zone | — | none | Buff, Area | — | Nearby towers gain attack speed |
   | `sup_arcane_conduit` | opener | 1 | self_buff | — | none | Buff | — | Temporarily boosts hero's own skill_power_coefficient |
   | `sup_barrier` | core | 3 | aoe_zone | — | none | Buff, Duration, Area | — | Damage-absorbing zone |
   | `sup_healing_ground` | core | 2 | aoe_zone | — | lifesteal_bonus | Area, Duration, Buff | — | Heal-over-time zone |
   | `sup_warlords_banner` | core | 2 | self_buff | — | none | Buff, Duration | — | Taunts, buffs nearby tower armor |
   | `sup_battle_totem` | capstone | 2 | totem | — | none | Totem, Buff | — | Totem buffs nearby towers' damage |
   | `sup_channeled_ward` | capstone | 2 | channel | — | none | Channeling, Buff | — | Channel to shield towers in radius |
   | `sup_meteor_call` | capstone | 2 | aoe_zone | fire | dot_burn | Area | 1.6 | Support skill that also nukes |

   **8 skills per category, 32 total** — up from the original 8-skill Alpha catalogue (2 per category). **The Ultimate matrix's tractability (Group 3) is unaffected by this growth**, exactly as originally designed: adding skills never grows the Ultimate lookup surface, because the derivation keys on `category` counts among the 4 equipped slots, never on `skill_id` identity. This is the direct mechanism by which this GDD satisfies `game-concept.md`'s mitigation instruction to "cap Ultimate combinations at a tractable number" — see Group 3 and Formulas for the full proof, unchanged by this catalogue expansion.

   **Numeric tuning is provisional** — `skill_power_coefficient` values above follow the established 0.5–3.0 range and rough archetype parity (single-target/high-stun skills sit higher, multi-hit/channel skills sit lower per-tick), but have not been through a dedicated balance pass. Treat as a structural placeholder, same precedent as every other "real values, not yet tuned" content pass in this project.

4. Skill slot changes (which `skill_id` occupies A/B/C/D, and which skill-modifier items occupy each skill's passive slots) are permitted **only while at Sanctuary**, between missions. **Assumption, flagged**: `hero.md` Rule 10 states the Ultimate "recomputes immediately" when a slot changes "mid-adventure" — read in context, this means *across missions within one playthrough* (consistent with Rule 3's per-adventure persistence, Group 5 below), not *mid-mission*. No other GDD explicitly states slot changes are SCOUT/WAVE_ACTIVE-locked; this GDD adopts the same lock precedent Tower System (`tower.md` Rule 3, component slots) and Hero System (`hero.md` Rule 18, class designation) already use — components/designations lock at Sanctuary and cannot change mid-mission. Applying the same rule here keeps the "commit before the wave, don't adjust mid-fight" authorship contract consistent across every player-configurable loadout system in the game.

5. **Duplicate skill_id across active slots is explicitly allowed.** The player may equip the same `skill_id` into 2, 3, or all 4 active slots simultaneously. This is not a bug or an oversight — it is a deliberate, valid build strategy (e.g., 4× the same elemental skill deterministically produces the `elemental_ascendant` Ultimate, Group 3) and is never blocked by validation. Because the Ultimate derivation keys only on `category`, not on `skill_id` identity, duplicate equips are naturally supported without any special-case logic — this is one of the concrete payoffs of the categorical model over an identity-keyed lookup table.

#### Group 2: Ultimate Derivation — resolves the game-concept.md High-Risk Systems combinatorial-explosion risk

> **This group is the GDD's primary risk-mitigation deliverable.** `game-concept.md`'s High-Risk Systems table names this system explicitly: "4 active skills × N possible combinations for the Ultimate mechanic creates a potentially explosive design space... enumerate all tower-learnable skills and define the full combination matrix before implementation. Cap Ultimate combinations at a tractable number." The design below is not a raw skill-identity lookup table (which, per that same risk entry, would produce hundreds-to-thousands of entries even at a modest 15–20 skill catalogue) — it is a **category-count derivation function** that collapses the combination space to a mathematically provable, fully enumerable, hand-authorable size. See Formulas for the full derivation and proof of exhaustive coverage.

6. The Ultimate is derived from the **category profile** of the 4 equipped active skills, not from their specific `skill_id`s. The category profile is the count of each of the 4 categories (`physical`, `ranged`, `elemental`, `support`) among the 4 currently-equipped active slots (Formula 1).

7. Ultimate derivation requires **all 4 active slots to be filled with a known skill**. If fewer than 4 slots are filled, or one or more filled slots reference an unrecognized `skill_id` (see Edge Cases), the Ultimate resolves to `EMPTY` — the same outcome `hero.md`'s own edge case already specifies for "all 4 slots empty," extended here to also cover "not all 4 slots are filled with a known skill." This precondition is deliberate: full commitment to a 4-skill build is the price of an Ultimate, matching the "commit before the wave" authorship fantasy already established for Tower and Hero class systems.

8. When all 4 slots are filled with known skills, the category profile is classified into exactly one of **5 profile shapes** — the 5 integer partitions of 4 (4; 3+1; 2+2; 2+1+1; 1+1+1+1) — and each shape maps to an Ultimate ID via a fixed, deterministic naming rule (Formula 2 and Formula 3):

   | Shape | Category count pattern | Ultimate ID template | Count of distinct Ultimates this shape produces |
   |---|---|---|---|
   | PURE | one category = 4, rest = 0 | `{category}_ascendant` | 4 |
   | TRIPLE | one category = 3, another = 1, rest = 0 | `{dominant_category}_overload` (the count-3 category; the count-1 category is not part of the Ultimate identity) | 4 |
   | DOUBLE_DOUBLE | two categories = 2 each, rest = 0 | `{catA}_{catB}_fusion` (alphabetical order) | 6 |
   | DOUBLE_SINGLE_SINGLE | one category = 2, two categories = 1 each, rest = 0 | `{dominant_category}_surge` (the count-2 category; the two count-1 categories are not part of the Ultimate identity) | 4 |
   | ALL_DIFFERENT | all 4 categories = 1 | `convergence` (fixed, no category in the name) | 1 |

   **Total: 19 distinct Ultimate IDs**, fully enumerated in Formula 3. This is comfortably under the task's recommended "under 35, ideally under 20" tractability target.

9. **Ownership**: Hero Skill Build System computes the category profile, classifies its shape, and derives the Ultimate ID entirely within its own system — it does not delegate this computation to the Hero System, and the Hero System does not independently re-derive the Ultimate from raw skill IDs. Hero Skill Build emits `ultimate_skill_changed(ultimate_id)` with the *final resolved result*; Hero System receives and applies it (sets the U slot, starts tracking its cooldown once activated). This avoids two systems needing to maintain the same derivation logic, and directly answers the ownership question `hero.md`'s own Dependencies table left implicit ("Hero must recompute Ultimate immediately when any slot changes" is read here as "Hero must *apply* the recomputed Ultimate immediately," not "Hero must perform the recomputation itself").

10. Any change to an active slot's `skill_id` (assignment, reassignment, or clearing) triggers an immediate recompute of the category profile and re-emission of `ultimate_skill_changed`, per `hero.md`'s existing Edge Cases ("the Ultimate recomputes immediately... any active Ultimate cooldown timer is discarded"). This GDD does not alter that behavior — it only specifies *what value* gets computed.

11. **Ultimate cooldown** is defined by the Ultimate's own data entry (`hero.md` Rule 10), not derived from the category profile. Each of the 19 Ultimate IDs has its own cooldown value in its data entry — this is deferred content-authoring work, same precedent as the skill catalogue's `effect_data`.

#### Group 3: Passive Slots & Skill-Modifier Items — resolves event-bus.md's Open Note 4

> **This group resolves `event-bus.md`'s own open item**: "Passive skills and secondary events — Passive slot modifications in Hero Skill Build may need their own EventBus events. Determine whether passive-slot changes are EventBus events or internal to Hero Skill Build. Owner: Hero Skill Build GDD." **Resolution: passive-slot changes are internal to Hero Skill Build System — no new EventBus event is introduced for them.**

12. **Passive slots are internal state, not EventBus-published state.** When a skill-modifier item is equipped into or removed from one of a skill's `passive_slot_count` passive slots, Hero Skill Build System updates its own internal data structure directly — it does not emit a new signal (e.g., no `skill_passive_equipped`). Rationale:
    - Passive slot changes, like active slot changes (Rule 4), only happen at Sanctuary — there is no live-combat consumer that needs a push notification the instant a passive slot changes, unlike Tower's `tower_component_equipped` (which Constellation needs live, mid-Sanctuary-session, to revalidate pattern eligibility).
    - The one system that *would* care about a skill's current effective parameters (Damage & Status) does not need per-passive-slot granularity — Hero Skill Build pre-folds all equipped passive modifiers into the skill's effective `effect_data` at the moment the skill activates, the same additive-bucket-then-emit pattern `hero.md` Formula 1 already uses for equipment-to-stat resolution. **Correction (2026-08-25, closing `TD-hero-001`)**: D&S does NOT consume the resolved effect via `hero_skill_activated` — that event remains Hero System's own "a skill was cast" signal (Audio, Mission HUD, cooldown UI; see `event-bus.md`'s catalogue), unconsumed by D&S. The actual damage-resolution consumer is a distinct, newer event, `hero_skill_attacked` (`damage-status.md` Rule IX/Formula D7), emitted once per target the cast actually struck — Hero System is responsible for translating its own effect resolution (which targets got hit, whether each hit crit) into one or more `hero_skill_attacked` emissions, reading the already-passive-folded `effect_data` (including its `skill_power_coefficient`) to populate each one. It never needs to know which specific modifier items produced that result — only the final folded value.
    - Any UI that needs to *display* a skill's current passive loadout (the Sanctuary skill-build screen) does so via a **synchronous read API** (`HeroSkillBuild.get_passive_loadout(skill_id) -> Array[String]`), pulled at UI-open time — the same pull-not-push precedent Save & Persistence's own EC-10 establishes for Sanctuary-only, non-live-combat state ("initial load is a pull-not-push operation").
    - This mirrors Tower Mastery's own precedent of choosing *not* to expose a mechanic as a new EventBus event when no downstream system has a genuine live-combat need for it (Rule 7's `hero_class_unlocked` soft-hook, not consumed at MVP) — the bar for adding to the EventBus catalogue is a real cross-system need, not "this state changed."

13. **Skill-modifier item interface with Inventory.** Skill-modifier items are individually-instanced, hero-affecting items — mechanically closer to Hero equipment (`hero.md` Rule 1's stat-affix items) than to stackable Materials. **Recommendation, flagged as a new cross-GDD dependency**: skill-modifier items are filed under Inventory's existing **Equipment** tab (`inventory.md` Core Rule 3), using `item_type = "skill_modifier"` as a new item_type value within that tab, rather than proposing a 5th tab. Reasoning:
    - `inventory.md`'s 4 fixed tabs (Equipment, Tower Components, Materials, Crafted Goods) don't have an existing category that fits precisely, but Equipment's existing rules already fit exactly: `stack_cap_unique = 1` (skill-modifier items are individually stat-rolled/typed, not generic stackables) and the **equipped-item lock** (`inventory.md` Rule 5 — an item currently installed in a passive slot cannot be removed or discarded from Inventory while installed, exactly mirroring how Hero equipment and Tower Components are locked while in use).
    - Equipping/unequipping a skill-modifier item into a passive slot follows the same interaction shape Inventory's own UI Requirements already define for Equipment ("a dedicated 'Equip' button... not drag-onto-hero"), applied here as "equip into passive slot" instead of "equip onto hero."
    - **This is a genuine gap, not yet resolved by Inventory's own GDD** — `inventory.md`'s tab-to-item_type mapping table does not currently list `skill_modifier` as a valid Equipment-tab item_type. Flagged here for Inventory's next revision, same pattern as `tower-mastery.md`'s own flagged `get_component_loadout()` API gap on `tower.md`.
    - **Revised 2026-09-01 (PoE-scale content pass) — passive slots are now typed, superseding the prior "untyped at MVP" assumption.** Each skill-modifier item declares a `requires_tag: String` field (one of the 8 tag values Rule 2's `effect_data.tags` uses, or `"any"`). A skill-modifier item may be equipped into a passive slot **if and only if** the socketed skill's own `effect_data.tags` array contains the item's `requires_tag` (or the item declares `"any"`). This is checked at equip time, not continuously — an already-equipped item is never retroactively invalidated by anything (no skill ever changes its own tags at runtime). This closes the gap the prior assumption explicitly flagged as future scope ("if content design later wants typed slots... a future revision to this GDD's data model") — now that Rule 3's catalogue is large enough and varied enough in mechanical identity for untyped slots to produce genuinely incoherent combinations (e.g. a "Multiple Projectiles" item socketed into a Totem-only skill).

14. **Support-modifier catalogue (new 2026-09-01).** 13 skill-modifier items, each with a `requires_tag` (Rule 13) and a mechanical effect applied to the socketed skill's folded `effect_data` at cast time (Rule 12's existing additive-bucket-then-emit pattern — no new resolution mechanism, just a larger input set to it):

   | `modifier_id` | `requires_tag` | Effect |
   |---|---|---|
   | `sup_mod_multiple_projectiles` | Projectile | +2 projectiles; −20% `skill_power_coefficient` per added projectile |
   | `sup_mod_chain` | Projectile | adds/extends `secondary_effect: chain`; −15% coefficient |
   | `sup_mod_increased_aoe` | Area | +30% radius (aoe_zone/melee_arc) or +30% duration (DoT effects) |
   | `sup_mod_elemental_focus` | any non-`physical` `damage_type` | +40% coefficient; strips any non-damage `secondary_effect` |
   | `sup_mod_faster_casting` | any | faster cast/tick interval; −10% coefficient |
   | `sup_mod_concentrated_effect` | Area | +50% coefficient; −30% radius |
   | `sup_mod_ruthless` | Melee | every 3rd cast +100% coefficient; other casts −10% |
   | `sup_mod_fortify` | Melee | grants a defensive stack on hit; no coefficient change |
   | `sup_mod_totem_life` | Totem | +80% totem duration/health |
   | `sup_mod_spell_echo` | Channeling | skill auto-repeats once; −20% coefficient per repeat |
   | `sup_mod_vile_toxins` | `secondary_effect` = `dot_poison` or `dot_burn` | DoT ticks +50% faster; −25% magnitude per tick |
   | `sup_mod_immolate` | `damage_type` = `fire` | adds `secondary_effect: dot_burn` if not already present; +10% coefficient |
   | `sup_mod_arcane_surge` | `damage_type` = `lightning`/`frost`/`fire`/`arcane` | stacking buff on cast; boosts next casts' coefficient |

   Filed under Inventory's `skill_modifier` item_type (Rule 13) exactly like every other skill-modifier item — these 13 are simply the first real catalogue content for that item_type, not a new interface. `requires_tag` is stored on the item's own `ItemDefinitionResource`, read by Hero Skill Build at equip-time per Rule 13's revised check, never duplicated into this GDD's own data.

#### Group 4: Persistence Model — resolves the hero.md Rule 11 / tower-mastery.md persistence question

> **This group resolves the apparent Hero Rule 11 vs. Tower Mastery cross-mission-persistence conflict flagged in the task brief.** Having read both GDDs directly: **there is no actual contradiction** — both documents already state the same reset boundary in their own words, and the confusion is purely a reading-order issue. This is stated explicitly below so it is never rediscovered as a false alarm in a future review pass.

14. **What resets only on a brand-new game (fresh save/playthrough), never on a per-mission or per-adventure-restart basis:**
    - **Hero Skill Tree's earned-skill pipeline** (`skill_tree_points`, `overflow_points`, and all 16 chain nodes' unlocked flags — **corrected 2026-08-31**: originally described as Tower Mastery's `unlocked_skills: Dictionary[String, bool]`, which `tower-mastery.md` Rule 5 retired that same day in favor of `points_granted_count[build_signature]: int`; the actual permanent, per-adventure "what have I earned toward a skill" state now lives in `hero-skill-tree.md`, not Tower Mastery). This is cross-mission **persistent** *within* a playthrough and only clears at a wholly new save.
    - **Hero Skill Build's own active/Ultimate/passive slot assignments** — `hero.md` Rule 11 states "Skills are per-adventure: they persist across all missions in a single playthrough and reset to empty on a new game." Read plainly, "reset to empty on a new game" describes the same reset boundary as every other per-adventure system in this chain.
    - **The resolution**: Hero Rule 11's "per-adventure" language and the rest of this chain's "new game" language are describing **the same event** from documents authored independently. Neither needs revision on this point.

15. **What is freely re-selectable at Sanctuary between missions, within one playthrough (not reset, but not locked either):**
    - Which of the player's currently-unlocked skills occupy active slots A/B/C/D (Rule 4).
    - Which skill-modifier items occupy each equipped skill's passive slots (Group 3).
    - The resulting Ultimate — recomputed automatically whenever the above changes (Group 2).
    - None of this reassignment freedom unlocks new skills or affects Hero Skill Tree's own pools/nodes (**corrected 2026-08-31**, was Tower Mastery's `unlocked_skills`/`mastery_time`) — it only changes which *already-unlocked* skills are currently equipped.

16. **What Hero Skill Build System itself persists via Save & Persistence** (matching `hero.md`'s own Dependencies table entry, `restore_order = 30`'s save data list "unlocked skills, slot assignment"):
    - The learned-skill library it maintains for its own equip-eligibility checks — **corrected 2026-08-31**: this is a local cache/mirror of `skill_unlocked` events **received from `hero-skill-tree.md`'s node-purchase path** (not Tower Mastery, which no longer emits this event at all — see Rule 17 below), not a second independent source of truth. Hero Skill Build does not re-derive or duplicate any upstream mastery/spend-economy logic; it only remembers *which skill_ids are currently equippable* as a result of having received `skill_unlocked` events, regardless of which system emitted them.
    - The current A/B/C/D active slot assignments and each skill's passive slot fills.
    - The currently-resolved Ultimate ID (recomputed on load, not restored as a raw value — Rule 9's "Hero Skill Build owns the derivation" applies identically on restore as it does live, so the Ultimate is always recomputed from restored slot assignments rather than trusted as a stored value that could drift out of sync with a content update).

17. **Corrected 2026-08-31** — Hero Skill Build System subscribes to `skill_unlocked(skill_id, source_tower_id)`, now emitted exclusively by `hero-skill-tree.md`'s own node-purchase path (`tower-mastery.md` no longer emits this event at all, per that document's own 2026-08-31 revision), and adds `skill_id` to its local equippable-skill library the instant it is received — this is the sole mechanism by which a skill becomes assignable to an active slot. Hero Skill Build never invents skill availability from any other source.

### States and Transitions

| State | Active During | Entry | Exit |
|---|---|---|---|
| `DORMANT` | No save loaded / pre-game | Application start | `sanctuary_state_restored` fires |
| `CONFIGURABLE` | `SANCTUARY` | `mission_phase_changed` → any Sanctuary-side state, or return from a completed/abandoned mission | `mission_launched` (player confirms mission launch) |
| `LOCKED` | `SCOUT`, `WAVE_ACTIVE`, `INTERMISSION`, `OUTCOME`, `DEFEAT` | `mission_launched` | Mission ends and control returns to `SANCTUARY` |

Only one state transition rule is load-bearing for gameplay: **slot writes (active-slot assignment, passive-slot assignment) are only accepted while `CONFIGURABLE`.** This mirrors Tower's `tower.md` Rule 3 and Hero's `hero.md` Rule 18 lock precedent exactly (Group 1, Rule 4). While `LOCKED`, the system is fully read-only from the player's perspective — it still recomputes and holds the currently-resolved Ultimate for Hero System to read, but no UI write path is available (the Sanctuary screen itself is inaccessible during `LOCKED`, per the same "screen inaccessible, ledger still live" precedent `inventory.md` establishes for its own `INVENTORY_HEADLESS` state). Unlike Inventory, however, there is no mid-mission write source analogous to `materials_earned` — nothing changes a skill's equipped state mid-mission, so `LOCKED` is a true full freeze, not a "screen closed but writes continue" state.

The `skill_unlocked` subscription (Group 4, Rule 17) is active in **every** state, including `LOCKED`, for architectural simplicity — but its original rationale is now stale and corrected here (2026-08-31): the claim was "Tower Mastery can unlock a skill mid-wave," which was true under the pre-revision model but is no longer possible under any circumstance. `skill_unlocked` now originates exclusively from `hero-skill-tree.md`'s own Sanctuary-gated node-purchase path (that document's Rule 11), which can only fire while Hero Skill Tree itself is at Sanctuary — i.e., only while this system is simultaneously `CONFIGURABLE`, never `LOCKED`. There is currently no real race this always-on subscription needs to defend against; it remains active in every state simply because there is no cost to leaving it on and no reason to add state-conditional subscription logic for a state combination that can no longer occur. This does not violate the write-lock above regardless: adding to the *equippable library* is not an active-slot or passive-slot assignment, and does not trigger an Ultimate recompute.

### Interactions with Other Systems

| System | Direction | Data | Mechanism |
|---|---|---|---|
| **EventBus** | → Hero Skill Build | `skill_unlocked(skill_id, source_tower_id)`, `mission_phase_changed`, `sanctuary_state_restored` | Signal subscriptions connected in `_ready()` |
| **EventBus** | Hero Skill Build → | `active_skill_equipped(slot_index, skill_id)`, `ultimate_skill_changed(ultimate_id)` | Direct signal emission — both events already frozen in `event-bus.md`'s catalogue, payloads unchanged by this GDD |
| **Hero Skill Tree System** | Hero Skill Tree → Hero Skill Build | `skill_unlocked` is the sole source of equippable-skill availability (corrected 2026-08-31 — was Tower Mastery; that system retired its direct `skill_unlocked` emission the same day, in favor of `skill_tree_point_earned` consumed by Hero Skill Tree) | EventBus subscription (Group 4, Rule 17) |
| **Hero System** | Hero Skill Build → Hero | `active_skill_equipped`, `ultimate_skill_changed` update Hero's 4 active slot bindings and the U slot | EventBus subscription (already documented in `hero.md`'s own Dependencies table); Hero applies, does not recompute (Group 2, Rule 9) |
| **Damage & Status System** | Hero Skill Build → D&S (indirect) | Fully-resolved skill effect parameters (passive modifiers pre-folded, including `skill_power_coefficient`), delivered via `hero_skill_attacked` (`damage-status.md` Rule IX/Formula D7, added 2026-08-25 — **corrected from the previously-stated `hero_skill_activated`**, which is Hero System's own cast-trigger signal, not a D&S input) — **Hero System emits this event, not Hero Skill Build**; Hero Skill Build's only contribution is that the effect parameters Hero reads for that `skill_id` already reflect equipped passives | Internal (no new EventBus event from Hero Skill Build itself — Group 3; `hero_skill_attacked` is Hero System's/Damage & Status's event, not this GDD's) |
| **Inventory System** | Bidirectional (proposed, flagged as a gap) | Skill-modifier items read from/returned to Inventory's Equipment tab; `item_type = "skill_modifier"` (new value, Group 3, Rule 13) | Direct API — pattern to be finalized against Inventory's own future revision; not yet implemented on Inventory's side |
| **Mission HUD** | Hero Skill Build → | `active_skill_equipped`, `ultimate_skill_changed` for HUD skill-slot and Ultimate-slot icon display | EventBus subscription (already documented in `event-bus.md`'s catalogue) |
| **Save & Persistence** | Bidirectional | `get_save_data()` / `restore_save_data()` / `reset_to_defaults()` for the equippable-skill library mirror, active/passive slot assignments; `restore_order = 31` (corrected 2026-08-31 — the prior text cited "after Tower Mastery's proposed 31," a stale cross-reference to Tower Mastery's own long-since-corrected number; 31 is this system's own actual, authoritative, already-assigned slot per `save-persistence.md`, with no ordering dependency on Tower Mastery at all) | Direct API call in `_ready()` |

## Formulas

### Formula 1: Category Profile Vector

Converts the 4 equipped active skills into a count of each of the 4 fixed categories. This is the sole input to Ultimate derivation — no other property of the equipped skills (their `skill_id`, their order in A/B/C/D, or which specific skill occupies which slot) affects the result.

```
category_count[c] = |{ slot ∈ {A, B, C, D} : catalogue[slot.skill_id].category == c }|   for each c ∈ {physical, ranged, elemental, support}
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Slot | `slot` | enum | {A, B, C, D} | One of the 4 active skill slots |
| Equipped skill | `slot.skill_id` | String | any catalogue `skill_id`, or empty | The skill currently bound to that slot |
| Category | `c` | String | `physical` / `ranged` / `elemental` / `support` | One of the 4 fixed categories, matching `tower.md`'s Foundation archetype enum |
| Category count | `category_count[c]` | int | 0–4 | Number of the 4 active slots whose equipped skill's category equals `c` |

**Output range:** Each of the 4 `category_count` values is an integer in [0, 4], and the 4 values always sum to exactly 4 (every filled slot contributes to exactly one category; Rule 7 requires all 4 slots filled with known skills before this formula is evaluated at all — if that precondition fails, this formula is not evaluated and the Ultimate resolves to `EMPTY` directly).

**Worked example:**
```
A = phys_cleave (physical), B = phys_bulwark (physical), C = rng_volley (ranged), D = rng_piercing_shot (ranged)
category_count = { physical: 2, ranged: 2, elemental: 0, support: 0 }   (sums to 4)
```

---

### Formula 2: Profile Shape Classification

Classifies a `category_count` vector into exactly one of the 5 possible **shapes** — the 5 integer partitions of 4. This step is what collapses the raw combination space: it discards *which* categories hold which counts and keeps only the *pattern* of counts, which Formula 3 then re-attaches to specific category names.

```
max_count = max(category_count[physical], category_count[ranged], category_count[elemental], category_count[support])
n_at_2     = |{ c : category_count[c] == 2 }|

shape = PURE                   if max_count == 4
shape = TRIPLE                 if max_count == 3
shape = DOUBLE_DOUBLE          if max_count == 2 and n_at_2 == 2
shape = DOUBLE_SINGLE_SINGLE   if max_count == 2 and n_at_2 == 1
shape = ALL_DIFFERENT          if max_count == 1
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Category count vector | `category_count` | Dictionary[String, int] | 4 entries, each 0–4, summing to 4 | From Formula 1 |
| Maximum count | `max_count` | int | 1–4 | The highest single-category count in the vector |
| Categories at count 2 | `n_at_2` | int | 0–2 | How many of the 4 categories have exactly count 2 (distinguishes DOUBLE_DOUBLE from DOUBLE_SINGLE_SINGLE, the only ambiguity at `max_count == 2`) |
| Shape | `shape` | enum | {PURE, TRIPLE, DOUBLE_DOUBLE, DOUBLE_SINGLE_SINGLE, ALL_DIFFERENT} | One of the 5 integer partitions of 4 |

**Output range:** Exactly one of 5 enum values — the classification is total and mutually exclusive by construction. **Proof of exhaustiveness:** any 4 non-negative integers summing to 4 form exactly one of the 5 partitions of the integer 4 (4; 3+1; 2+2; 2+1+1; 1+1+1+1 — this is a closed, complete enumeration in elementary number theory, not a design approximation). Since Formula 1 always produces 4 non-negative integers summing to 4, this classification can never fail to match a shape and can never match two shapes at once — there is no `NONE`/unclassified case to defend against here.

**Worked example (continuing Formula 1):**
```
category_count = { physical: 2, ranged: 2, elemental: 0, support: 0 }
max_count = 2, n_at_2 = 2 (physical and ranged both sit at count 2)
shape = DOUBLE_DOUBLE
```

---

### Formula 3: Ultimate ID Derivation

Maps a classified shape (plus, where needed, which specific category or category-pair achieved the relevant count) to one of the **19 fixed Ultimate IDs**. This is the complete, hand-authored, fully enumerable table this GDD's risk-mitigation mandate requires.

```
ultimate_id =
    "{category}_ascendant"              if shape == PURE           (category = the one with count 4)
    "{dominant}_overload"                if shape == TRIPLE          (dominant = the one with count 3)
    "{catA}_{catB}_fusion"               if shape == DOUBLE_DOUBLE   (catA, catB = the two categories at count 2, alphabetical order)
    "{dominant}_surge"                   if shape == DOUBLE_SINGLE_SINGLE (dominant = the one category at count 2)
    "convergence"                        if shape == ALL_DIFFERENT   (fixed, no category)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Shape | `shape` | enum | from Formula 2 | Determines which naming template applies |
| Dominant category | `dominant` / `category` | String | `physical` / `ranged` / `elemental` / `support` | The category achieving the shape's defining count (4 for PURE, 3 for TRIPLE, 2 for DOUBLE_SINGLE_SINGLE) |
| Category pair | `catA`, `catB` | String, String | any 2 of the 4 categories, alphabetically ordered | The two categories at count 2, for DOUBLE_DOUBLE only. Alphabetical order (`elemental` < `physical` < `ranged` < `support`) makes the ID deterministic regardless of slot order |
| Ultimate ID | `ultimate_id` | String | one of 19 fixed values (Table below), or `EMPTY` (precondition failure, Rule 7) | The value emitted in `ultimate_skill_changed` |

**Output range:** Exactly one of 19 fixed string values whenever the Rule 7 precondition (all 4 slots filled, all skills known) holds; `EMPTY` otherwise. **This is the complete, tractable Ultimate matrix — the full enumeration:**

| Shape | Ultimate IDs (all instances) | Count |
|---|---|---|
| PURE | `physical_ascendant`, `ranged_ascendant`, `elemental_ascendant`, `support_ascendant` | 4 |
| TRIPLE | `physical_overload`, `ranged_overload`, `elemental_overload`, `support_overload` | 4 |
| DOUBLE_DOUBLE | `elemental_physical_fusion`, `elemental_ranged_fusion`, `elemental_support_fusion`, `physical_ranged_fusion`, `physical_support_fusion`, `ranged_support_fusion` | 6 |
| DOUBLE_SINGLE_SINGLE | `physical_surge`, `ranged_surge`, `elemental_surge`, `support_surge` | 4 |
| ALL_DIFFERENT | `convergence` | 1 |
| **Total** | | **19** |

**Proof this covers every reachable combination (closes the `game-concept.md` risk without a `NONE` fallback):** Formula 2 is exhaustive over the 5 partitions of 4 (proven above). For each partition shape, the number of distinct ways to assign specific categories to that shape's counts is: PURE = C(4,1) = 4; TRIPLE = 4 × 3 = 12 (choose the count-3 category, then the count-1 category from the remaining 3 — but the count-1 category is deliberately *not* part of the Ultimate ID, per the template, so all 12 raw assignments collapse onto the same 4 `_overload` IDs); DOUBLE_DOUBLE = C(4,2) = 6; DOUBLE_SINGLE_SINGLE = 4 × C(3,2) = 12 (choose the count-2 category, then the unordered pair of count-1 categories — again collapsed onto the same 4 `_surge` IDs); ALL_DIFFERENT = 1. **Raw assignments sum to 4+12+6+12+1 = 35** — exactly `C(4+4-1, 4) = C(7,4) = 35`, the number of size-4 multisets over 4 categories, confirming no raw combination is missed. **These 35 raw assignments collapse onto only 19 distinct Ultimate IDs** because the TRIPLE and DOUBLE_SINGLE_SINGLE templates deliberately ignore the "minor" category/categories — a design choice, not a coverage gap, made specifically to keep the total Ultimate count well under the task's 20-entry target while still keeping the full 35-entry raw profile space provably, exhaustively covered.

Because coverage is proven mathematically rather than asserted per-entry, `hero.md`'s existing edge case ("if the 4-skill combination has no entry in the lookup table, the Ultimate resolves to NONE gracefully... every reachable combination must either have a table entry or explicitly map to NONE") is satisfied by construction for any 4-slot build using catalogue skills with a valid `category` field — the `NONE`/`EMPTY` branch is retained in code only as a defensive guard against a future data-integrity bug (e.g., a skill shipped with a missing or malformed `category` field), not because any legitimate combination is expected to reach it. This is the same "should never happen but cheap to check" defensive pattern already used elsewhere in this project (Hero's DEAD-state heal guard, EventBus's ghost-event handling).

**Worked example 1 (continuing Formulas 1–2):**
```
shape = DOUBLE_DOUBLE, catA = physical, catB = ranged (alphabetical: physical < ranged)
ultimate_id = "physical_ranged_fusion"
```

**Worked example 2 (duplicate skill_id, per Group 1 Rule 5):**
```
A = elem_frostbolt, B = elem_frostbolt (same skill_id in two slots), C = elem_firestorm, D = sup_rally
category_count = { elemental: 3, support: 1, physical: 0, ranged: 0 }
max_count = 3 → shape = TRIPLE, dominant = elemental
ultimate_id = "elemental_overload"
```

**Worked example 3 (all 4 categories represented once):**
```
A = phys_cleave, B = rng_volley, C = elem_frostbolt, D = sup_rally
category_count = { physical: 1, ranged: 1, elemental: 1, support: 1 }
max_count = 1 → shape = ALL_DIFFERENT
ultimate_id = "convergence"
```

## Edge Cases

> `hero.md`'s own Edge Cases already cover: all-4-slots-empty → `EMPTY`; no-lookup-entry → `NONE` (see Formula 3's proof that this is now unreachable for any valid catalogue skill); a slot's skill removed mid-adventure → immediate recompute, active Ultimate cooldown discarded. These are not repeated below — only edge cases specific to this GDD's own additions (the categorical model, passive slots, persistence, and catalogue content) are listed here.

**Slot Filling & Ultimate Precondition**

- **If 1, 2, or 3 (but not all 4) active slots are filled**: the Ultimate resolves to `EMPTY`, identical in outcome to "all 4 empty" (extends `hero.md`'s existing rule — see Group 2, Rule 7). A partially-built loadout never produces a partial or best-guess Ultimate.

- **If the same `skill_id` is equipped into 2 or more active slots**: explicitly allowed (Group 1, Rule 5). Each occupied slot contributes its skill's category to `category_count` independently — equipping the same skill 4 times produces a valid `PURE` shape and its corresponding `_ascendant` Ultimate, exactly as if 4 different same-category skills had been equipped. No deduplication or special-case handling applies.

**Unknown / Orphaned Skills**

- **If a save is loaded referencing a `skill_id` in an active slot binding that no longer exists in the current skill catalogue** (a catalogue entry removed or renamed post-launch): restore the slot binding as **orphaned** (do not discard — mirrors `hero.md`'s `class_id` orphan handling and `tower-mastery.md`'s `skill_id` orphan handling). Mark the skill `UNKNOWN` internally; do not auto-clear the slot. For Ultimate derivation purposes, a slot bound to an `UNKNOWN` skill is treated identically to an empty slot (Rule 7's "known skill" precondition is not met) — the Ultimate resolves to `EMPTY` until the player manually reassigns that slot at Sanctuary. Log a warning. Never block the load.

- **If the equippable-skill library (Group 4, Rule 16) contains a `skill_id` no longer in the catalogue** (distinct from the above — this is the library itself, not a slot binding): mark the entry `UNKNOWN`, do not surface it as assignable in the Sanctuary UI, and do not discard it from the persisted library data (supports future content re-addition, exact precedent as `tower-mastery.md`'s equivalent case). Log a warning. Never block the load.

**Passive Slots & Skill-Modifier Items**

- **If a skill-modifier item currently installed in a passive slot is removed from the game's content data** (post-launch removal, not a player action — a player-initiated removal is already prevented by the equipped-item lock, `inventory.md` Rule 5): mark the passive slot's occupant `UNKNOWN`, apply no effect from it (treat as if the passive slot were empty for `effect_data` folding purposes, Group 3), but do not auto-clear the binding — same orphan-preserve-don't-discard precedent as above. Log a warning. Never block the load.

- **If a skill's `passive_slot_count` is reduced by a content update** (e.g., a skill patched from 3 passive slots down to 2) **and a save has an item bound to the now-nonexistent 3rd slot**: the excess binding is treated as orphaned data, not silently deleted — restore it internally, do not surface it in the UI (only `passive_slot_count` sockets render), and return the bound item to the player's Inventory (unlocked, since it can no longer be "installed" anywhere) the first time the save is loaded post-patch. This is the one orphan case in this GDD that actively returns something to the player rather than merely marking `UNKNOWN`, because — unlike a renamed skill_id, which the player can simply re-target — an item stuck in a slot that structurally no longer exists has no in-game path back to usability otherwise.

- **If the player attempts to equip a skill-modifier item into a passive slot belonging to a skill that is not currently equipped in any active slot** (i.e., managing an off-build skill's passive loadout in advance): **allowed.** Passive slot configuration is per-`skill_id`, not per-currently-equipped-slot — a skill sitting unequipped in the library still has its own persistent passive loadout, exactly as Tower's component loadouts persist independent of whether that specific tower instance currently exists on a mission's field. This lets players pre-configure a skill's passives before deciding to slot it.

**Persistence Boundary**

- **If a new adventure/playthrough begins (new save, not a new mission)**: the equippable-skill library, all 4 active slot bindings, all passive slot bindings, and the resolved Ultimate all reset to empty/`EMPTY` simultaneously, in lockstep with Hero Skill Tree's own pool/node reset and Tower Mastery's own `points_granted_count`/`mastery_time` reset (corrected 2026-08-31 — Group 4, Rule 14). There is no scenario in which one resets and the others do not — they share the same "new game" trigger by design, even though they are separate persistent stores.

- **If a mission ends (any exit: `MISSION_COMPLETE`, `DEFEAT`, or manual abandon) while a build is slotted**: no reset occurs. Slot bindings, passive fills, and the resolved Ultimate persist unchanged into the next Sanctuary session, per Group 4, Rule 15 — mission outcome has no bearing on loadout state, only on Tower Mastery's ongoing mastery accrual and Hero Skill Tree's banked points (separate systems, per their own edge cases).

**Skill Catalogue Content**

- **If two skills in the catalogue share an identical `category` and are otherwise functionally near-duplicates** (a content-authoring quality concern, not a runtime error): this is permitted by the data model — nothing in this GDD requires category-mates to be mechanically distinct — but is flagged as a content-authoring guideline: with only 2 skills per category at Alpha scope (Group 1, Rule 3), category-mates should read as genuinely different playstyles (e.g., `rng_piercing_shot` single-target-pierce vs. `rng_volley` multi-target-spread) rather than reskins, since the player's *only* lever for shaping which of the 2 category-mates ends up contributing to a given Ultimate is choosing between them at equip time.

## Dependencies

### Upstream Dependencies (systems Hero Skill Build depends on)

| System | Dependency Type | What Hero Skill Build needs from it |
|---|---|---|
| **EventBus System** | Infrastructure | Subscribes to `skill_unlocked`, `mission_phase_changed`, `sanctuary_state_restored`; publishes `active_skill_equipped`, `ultimate_skill_changed` — all 5 already frozen in `event-bus.md`'s catalogue; no new events required by this GDD (Group 3's resolution) |
| **Hero Skill Tree System** | Data source (read-only) | `skill_unlocked(skill_id, source_tower_id)` is the sole source of equippable-skill availability (Group 4, Rule 17; corrected 2026-08-31 — was Tower Mastery). Hero Skill Build never calls into Hero Skill Tree directly and never reads its pool/node state — only the event |
| **Tower System** | Content-pipeline reference only, no runtime dependency | The `category` field (Group 1, Rule 2) reuses `tower.md`'s Foundation `archetype` enum values verbatim — a shared vocabulary, not a runtime call |
| **Save & Persistence System** | Infrastructure | Implements `get_save_data()` / `restore_save_data()` / `reset_to_defaults()` for the equippable-skill library mirror and slot bindings; `restore_order = 31` (corrected 2026-08-31 — this system's own actual assigned slot, per `save-persistence.md`'s authoritative table; the prior text's "32, after Tower Mastery's proposed 31" cited a stale, since-corrected Tower Mastery number and no ordering dependency on it ever actually existed) |
| **Inventory System** | Data source (proposed, flagged as a gap) | Skill-modifier items for passive slots — **not yet implemented on Inventory's side**; requires Inventory's next revision to accept `item_type = "skill_modifier"` under its Equipment tab (Group 3, Rule 13) |

### Downstream Dependents (systems that depend on Hero Skill Build)

| System | What it needs from Hero Skill Build | Constraint on Hero Skill Build |
|---|---|---|
| **Hero System** | `active_skill_equipped`, `ultimate_skill_changed` to bind its own 4 active slots and U slot | Must emit `ultimate_skill_changed` with the fully-resolved `ultimate_id` — Hero applies only, never re-derives (Group 2, Rule 9) |
| **Mission HUD** | Same two events, for live skill-slot and Ultimate-slot icon display | Payloads must always resolve to a valid catalogue entry or `EMPTY`/`UNKNOWN` sentinel — never a dangling reference the HUD can't render |
| **Damage & Status System** | Indirectly, via Hero's `hero_skill_attacked` (`damage-status.md` Rule IX/Formula D7, added 2026-08-25 — corrected from the previously-stated `hero_skill_activated`, see Group 3 Rule 12's own correction) — expects each hit's `skill_power_coefficient` to already reflect equipped passives | Hero Skill Build must fold passive modifiers into `effect_data` (including `skill_power_coefficient`) before Hero reads it at activation time (Group 3) — D&S has no direct dependency on this GDD |

### Notes

- **This GDD closes three previously-open cross-document questions**, per the task brief: (1) `game-concept.md`'s High-Risk Systems combinatorial-explosion risk — resolved via the categorical bucketing model (Group 2, Formulas 1–3), collapsing the space to 19 hand-authored Ultimate IDs across 35 provably-exhaustive raw category-count profiles. (2) `event-bus.md`'s Open Note 4 (passive-slot events) — resolved: internal to Hero Skill Build, no new EventBus event (Group 3). (3) The apparent `hero.md` Rule 11 / `tower-mastery.md` persistence conflict — resolved: no actual conflict exists; both already describe the same "resets only on a new game" boundary (Group 4).
- **New cross-GDD dependency flagged for `inventory.md`'s next revision**: a `skill_modifier` item_type value under the existing Equipment tab (Group 3, Rule 13) — mirrors the same "flagged gap, not fixed here" pattern `tower-mastery.md` already used for its own `get_component_loadout()` dependency on `tower.md`.
- **Registry update requested** (per this project's cross-system-entity protocol, not performed directly by this GDD): `design/registry/entities.yaml` should gain (a) the 4-value `category` enum (`physical`/`ranged`/`elemental`/`support`) cross-referenced as identical to `tower.md`'s Foundation `archetype` enum — not a new entry, a `referenced_by` addition, same pattern `tower-mastery.md` requested for the shared proximity radius; (b) the 19-entry `ultimate_id` enumeration (Formula 3's table) as a new registry entry, since Hero System, Mission HUD, and this GDD all need the identical fixed string set.
- **Skill catalogue's `effect_data` schema is fully specified, not deferred (revised 2026-09-01)** — this GDD specifies identity, category, tier, `passive_slot_count`, and the full `effect_data` schema (`damage_type`/`delivery`/`skill_power_coefficient`/`secondary_effect`/`tags`) for all 32 skills (Group 1, Rule 3). Only final numeric balance-tuning of those already-populated values remains open (Open Questions), not their structure — this supersedes the original Alpha-scope 8-skill deferred-effect precedent this Notes section used to describe.
- The `mastery_source_build_signature` field (Group 1, Rule 2) creates a soft content-authoring dependency in the other direction: `tower-mastery.md`'s own skill catalogue (its Rule 7 data model) must assign a `source_build_signature` to each relevant `skill_id` for mastery-based unlocking to actually reach them — this GDD does not perform that assignment itself, only reserves the field. **Vestigial at runtime (2026-08-31, flagged in Rule 2's own table row)**: `hero-skill-tree.md`'s revision means a mastered signature feeds an archetype pool, not a specific `skill_id`, so this field no longer drives which skill actually unlocks — it survives only as content-authoring/flavor metadata. **Further changed 2026-09-01**: which of a category's 8 skills is ever reachable by a given character is now determined by `hero-skill-tree.md`'s Choice-node selections (3 of 8 per archetype, one per tier), not by this field at all.

## Tuning Knobs

| Parameter | Default | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| Number of categories (`category` enum size) | 4 (locked to `tower.md`'s archetype count) | **Do not change without redesigning Formulas 1–3.** The raw profile count is `C(n+3, 4)` for `n` categories at 4 slots — at `n=4` this is 35 (this GDD's proven-tractable figure); at `n=5` it jumps to `C(8,4)=70`, roughly double, and the distinct-Ultimate count (currently 19) would also grow non-trivially across all 5 shape templates. Changing this number is a structural redesign, not a numeric retune. | N/A (higher `n` breaks tractability, see above) | N/A (fewer than 4 categories would desync from `tower.md`'s own 4-archetype taxonomy, reopening the "two invisible vocabularies" legibility problem this GDD deliberately avoided by reuse) |
| Skills per category (catalogue size) | 8 (32 total, expanded 2026-09-01 from the original Alpha-scope 2/8) | 2–8+ per category (8–32+ total) — current value is at the top of this GDD's originally-stated safe range; a further expansion is possible but should be revisited alongside `hero-skill-tree.md`'s Choice-node tier-option counts, which now consume 3 of each category's 8 skills per character | More skills per category increases individual skill balance-authoring workload (`effect_data` tuning) but — critically — **never grows the Ultimate matrix itself** (Group 1, Rule 3's core claim); this is the one knob in this system explicitly designed to scale independently of combinatorial risk (proven again post-expansion by AC-10c) | Fewer than 2 per category removes the "which of my category-mates do I equip" decision entirely — with exactly 1 skill per category, category and skill_id become equivalent and duplicate-equip (Edge Cases) becomes the only way to reach `PURE`/`TRIPLE`/`_surge` shapes at all |
| `passive_slot_count` per skill | 1–3 (varies per skill, Group 1 Rule 3's table) | 1–3 (schema-fixed range, `hero.md` Rule 9) | 3 slots on every skill dilutes the skill-modifier item economy (Inventory pressure) and makes every skill feel similarly "full," reducing the signal value of a skill that specifically has more passive depth | 1 slot on every skill makes passive customization feel token rather than meaningful — the intended reading is that higher `passive_slot_count` marks a skill as more build-defining (e.g. `elem_firestorm` and `sup_barrier` at 3 slots vs. `phys_cleave` and `rng_piercing_shot` at 1) |
| `restore_order` (Save & Persistence) | 31 (corrected 2026-08-31 — this system's own actual assigned slot; the prior "32, proposed" text was stale) | Fixed — already assigned in `save-persistence.md`'s authoritative table | N/A — no real ordering dependency, only needed to avoid collision, which is already resolved | N/A |
| Passive slot typing (untyped vs. typed) | Untyped (flat pool, Group 3's flagged assumption) | N/A — structural, not numeric | Introducing typed passive slots later adds a compatibility-check dimension (Edge Cases would need a new "incompatible modifier type" case) — acceptable future scope, not a regression | N/A |

**Note on the one non-negotiable tuning constraint**: unlike every other numeric knob in this GDD, the **category count (4) is load-bearing for the entire risk-mitigation argument** in Group 2 and Formulas 1–3. Every other system in this GDD (catalogue size, passive slot counts, restore order) can be retuned freely within its stated range without touching the Ultimate derivation math. Category count cannot — it is the one place where "just add more content" and "just add more categories" have fundamentally different cost profiles, and this distinction should be surfaced to any future content pass that considers adding a 5th tower archetype.

## Visual/Audio Requirements

**Screen visual language — not diorama content**

Per the art bible's own carve-out (Tarot, Mission Select precedent), this screen is abstract slot-assignment UI, not a hand-carved-object scene — it uses the UI shape grammar (art bible Sec 3.3, chamfered-rectangle sockets with consistent corner radius), not stacked-sprite diorama treatment. Tarot's tray/groove language is reused specifically for its *socket* metaphor (an empty slot reads as "a thing belongs here"), not for its literal card-tray/wood-carving skin.

- **4 active slots (A/B/C/D):** rendered as a horizontal row of socket frames, positioned and ordered to visually correspond to Mission HUD's existing "Hero skills (1–4) + Ultimate" HUD row (`mission-hud.md` row 9) — this screen is authoring what that HUD row will display in combat, so the spatial mapping must be immediately legible (Slot A = HUD icon 1, etc.), not an arbitrary new order.
- **Archetype identity per slot:** each occupied active slot shows the assigned skill's icon plus the existing archetype glyph (Physical/Ranged/Elemental/Support) as a small corner badge, and the slot frame's border takes the archetype's already-established accent (`tower.md`'s archetype color language: Physical grey/silver, Ranged brown/wood, Elemental per-sub-element or a neutral elemental accent when no sub-element applies here, Support warm gold). No new archetype iconography or color is invented — this screen is the fourth consumer (after Tower Info Panel, tower base, projectile trails) of the same visual vocabulary, which matters directly: since the Ultimate is derived from the category-count profile of the 4 slots, the player must be able to read "3 Elemental + 1 Support" at a glance from icons/borders alone, without opening tooltips.
- **Empty active slot:** a recessed empty-socket silhouette (Tarot's tray-groove metaphor, applied to an abstract frame rather than a card) showing the slot letter (A/B/C/D), never a blank rectangle.
- **Passive sub-slots (1–3 per active slot):** smaller nested sockets attached to their parent active slot's frame, visually subordinate (roughly 40% linear size of the active slot) so the eye reads "belongs to A" via Gestalt proximity/common-region, not via a label. Empty passive sub-slots use the same recessed-groove treatment at smaller scale.
- **Ultimate slot:** a single 5th slot, visually larger than the 4 active slots, positioned as the convergence point with thin connector lines drawn from each of the 4 active slots into it (Gestalt connectedness — makes the "4 inputs → 1 output" causality legible as a diagram, not just a layout). Border rendered in Sanctum Amber (the palette's established mastery/positive-progression hue) rather than any archetype color, since the Ultimate itself has no single archetype — it is never "empty" once all 4 active slots are filled, since it is always computed live.

**Ultimate preview/readout**

- A persistent, non-blocking readout is anchored beside the Ultimate slot at all times the screen is open: Ultimate icon, name, and a one-line effect description. It recomputes instantly on every slot change — there is no separate "preview vs. commit" state, consistent with this screen's fully reversible, no-destructive-cost nature (see UI Requirements 1d).
- Directly beneath the readout, a compact category-count pip tally (e.g., 3 small Elemental glyphs + 1 Support glyph, using the same reused archetype icons rather than colored dots) makes the pattern driving the Ultimate explicit. This is a deliberate pedagogical surface: the systems design intent is for players to learn to read "3 Elemental + 1 Support → Ultimate X" as a pattern, not memorize literal skill combinations, and the pip tally is the UI's most direct teaching tool for that.
- If any active slot is empty, the readout shows a clear "incomplete build" placeholder state (dimmed icon silhouette, "— Assign all 4 skills —" text) rather than a wrong or partial Ultimate guess.

**The `ultimate_skill_changed` moment — routine vs. first-time discovery**

Assessed against the project's existing reveal-beat precedent (Constellation's rune-discovery, Crafting's unlock-cascade, Tarot's rune-discovery, Defense Building's tech sparkle, Tower Mastery's amber pulse) and its equally-established counter-precedent (Mission Select's launch-confirm, Crafting's craft-confirm, Tower Mastery's routine mastery-tick — deliberately *not* over-celebrated because they're frequent): this screen needs both registers, split strictly by novelty, not by frequency of the underlying action.

- **Routine re-trigger (any recompute where the resulting Ultimate has been seen before this save, including swapping back to a previous combination):** a quick, light cross-fade/icon-swap on the Ultimate slot and readout (~0.15–0.2s), no screen-level effect, one soft UI tick sound. This must stay this light because Sanctuary experimentation (a player trying combinations to see what changes) can trigger this many times a minute — anything heavier becomes noise, exactly the failure mode the project has already flagged for Crafting's craft-confirm and Tower Mastery's mastery-progress-tick.
- **First-time-ever discovery of a new Ultimate (never before computed on this save):** a bigger, but still non-blocking, beat — the Ultimate slot plays a brief settle-pulse in Sanctum Amber (~0.5–1s, sprite/color-driven, no bloom dependency per the standing Godot 4.6 constraint), and a one-line toast reads "New Ultimate Discovered: [Name]" anchored near the readout, held ~1.5–2s or dismissed by the player's next action. This mirrors Constellation's and Tarot's "first-time-only" rune-discovery precedent, scaled down for a menu context (no card-flip reveal, no center-screen takeover — the player is mid-experimentation in a menu, not receiving a mid-combat or meta-progression payoff).
- A discovered-Ultimate set persists in save data so the discovery beat never re-fires for an Ultimate the player has already seen, even across sessions.

**Skill-learned library presentation**

- Reuses Crafting's recipe-list item template (icon + name + short effect blurb, vertically scrollable) rather than Tarot's fanned-card-pool language — these are discrete named abilities being assigned to functional slots, not a hand-drawn spread, so the list metaphor is the closer fit.
- **Not-yet-learned skills** (visible in the library as a roadmap of what Hero Skill Tree can still unlock — corrected 2026-08-31, second pass, was stale "Tower Mastery," which no longer unlocks skills at all — if the systems design intends this list to show locked entries) reuse the existing grey-out-plus-lock-icon convention (same lock glyph as Inventory/Crafting/Tarot) rather than inventing a new locked-state treatment.
- **Newly learned, not-yet-viewed skills:** the first time a skill learned via Tower Mastery appears in this library (i.e., the first time the player opens this screen after `skill_unlocked` fired), it carries a small "NEW" badge and a one-time gentle pulse (color/sprite-driven, non-bloom) that clears the first time the player either slots it or simply views this screen. This is the deferred "sell it" beat Tower Mastery's own GDD explicitly reserves for this screen (`tower-mastery.md`, Visual/Audio Requirements 1c, point 3) — Tower Mastery's mid-combat amber pulse only confirms *that* something was earned; this library entry is where the player actually reads what it does, without combat pressure.
- Each library entry shows its archetype glyph/accent identically to the slotted presentation, so category is legible before assignment, not just after.

**Audio direction (category only, no audio bible yet)**

- Slot assignment (skill placed/swapped into an active slot): a light, dry "socket click" — its own distinct asset, not reused from Crafting's craft-confirm or Tarot's card-flip, since this is a placement gesture, not a transformation or reveal.
- Passive sub-slot assignment: a softer, smaller variant of the same click family, one register quieter — signals "this is the minor action," matching Tarot's tier-up-vs-discovery scale differentiation.
- Routine `ultimate_skill_changed` recompute: a quick, light "recompute" chime, distinct from the slot-click, non-fatiguing on repeat.
- First-time Ultimate discovery: a fuller layered chime comparable in production weight to Constellation's/Tarot's discovery stings, built around a distinct "assembly-click plus resonant swell" signature so it is ear-identifiable as this system, not a copy of another system's fanfare.
- Not-yet-learned skill interaction attempt: soft negative-denial tone, same category as Crafting's/Tarot's locked-denial family (not an identical asset).

## UI Requirements

**a) Screen layout — one continuous screen, not sectioned**

All elements live on a single screen rather than separate tabs/sub-screens, because the whole system depends on an immediate, visible feedback loop between cause (active slots + library) and effect (Ultimate readout) — sectioning any of these into a separate tab would break that loop, which the live-recompute design explicitly relies on. Layout reuses Crafting's established two-panel "pool + assembly" spatial language:

- **Library panel** (skills, with a shoulder-button toggle to switch to the passive-modifier pool — see 1c) on one side, scrollable list.
- **Assembly area** on the other side: the 4 active slots in a row, each with its 1–3 nested passive sub-slots directly attached.
- **Ultimate slot + readout** positioned as the visual focal point (top-center, above the active-slot row), connected to all 4 active slots by the connector lines described above.

**b) Skill-to-active-slot interaction**

- **Mouse:** drag a skill icon from the library onto an active slot. Dropping onto an occupied slot swaps the new skill in and returns the previous occupant to the library — no confirmation dialog (see 1d). Dragging a slotted skill back onto the library area clears the slot, consistent with the project's existing equip/unequip drag gesture.
- **Gamepad (no drag-drop, per the established convention):** select-then-confirm. D-pad/left-stick moves focus within the library list; shoulder buttons cycle the library's archetype-category filter (reusing the established shoulder-button category-cycling convention). Confirm on a focused library entry enters "pick-up" mode; D-pad then moves focus among the 4 active slot targets; confirm again places the skill (swapping out any current occupant, which returns to the library). Cancel/back aborts an in-progress pick-up without changing the current build.

**c) Passive sub-slot assignment**

Mirrors (b) at a nested scale rather than introducing a new interaction pattern:

- **Mouse:** drag a modifier item from the passive-modifier pool (same library panel, toggled via the shoulder-button/tab switch noted in 1a, rather than a fifth panel) onto one of an active slot's 1–3 passive sub-slot sockets.
- **Gamepad:** D-pad focus reaches an active slot as in (b); a secondary confirm (or holding confirm) "enters" that slot's passive sub-slots, after which D-pad moves among the 1–3 sub-slot sockets and confirm places the focused pool item. Cancel/back exits back out to active-slot-level focus.

**d) Confirmation convention — single-confirm, no commit step**

Every slot and sub-slot change takes effect immediately; there is no "Save" or "Confirm Build" action and no destructive-consequence warning. This matches the Crafting/Defense Building precedent for routine, fully reversible Sanctuary actions — nothing here is permanently lost by rearranging (the previous occupant simply returns to the library), which is also why frequent, low-cost experimentation with different Ultimate combinations is an expected and supported play pattern rather than an edge case to guard against.

**e) Gamepad navigation model**

Single 2D D-pad/left-stick adjacency map spanning: library list ↔ active-slot row ↔ each active slot's passive sub-slots. Shoulder buttons cycle the library's archetype-category filter. Single confirm button drives pick-up and placement at every level; a single cancel/back button aborts an in-progress pick-up and also backs out of the screen (consistent with the established gamepad model — no separate "menu" button layer). The Ultimate slot itself is not an assignable target — focus can rest there only to let the readout be read via the same navigation flow (e.g., for a future AccessKit-style focus/announce pass), never to edit it directly.

**f) Accessibility notes**

- Archetype category iconography is the primary (shape/glyph) identifier for every category distinction on this screen (slot borders, library entries, the Ultimate pip tally); accent color is confirmatory only, consistent with Sec 4.5 colorblind-safety discipline and with `tower.md`'s own archetype color table (which already varies within "Elemental" by sub-element, so color alone was never sufficient there either).
- The category-count pip tally in the Ultimate readout uses icon repetition (e.g., 3 Elemental glyphs + 1 Support glyph), never colored dots alone.
- "NEW"-skill and "New Ultimate Discovered" badges use a text/glyph badge in addition to any color-pulse treatment, so novelty is legible without color.
- Gamepad focus indicator meets the project's existing ≥3px high-contrast outline standard (`design/ux/interaction-patterns.md`).
- Full K/M and gamepad parity per the standing project requirement — every interaction in (b) and (c) has a stated gamepad equivalent with no touch-only or hover-only step.

## Acceptance Criteria

### Slots & Data Model (Group 1)

**AC-1: Four active slots + one Ultimate slot, independently bound**
- **Given** a fresh `CONFIGURABLE` state with no skills equipped
- **When** the Sanctuary skill-build screen queries slot state
- **Then** exactly 5 bindings exist (A, B, C, D, U), each independently settable, matching `hero.md` Rule 8.

**AC-2: Catalogue schema completeness**
- **Given** the 32-skill catalogue (Group 1, Rule 3, expanded 2026-09-01 from the original Alpha-scope 8)
- **When** each catalogue entry is inspected
- **Then** every entry has a non-empty `skill_id` unique across the catalogue, a `category` in `{physical, ranged, elemental, support}` exactly matching `tower.md`'s archetype enum values (string-for-string), a `passive_slot_count` in [1,3], and either a valid `mastery_source_build_signature` or (only if unreachable via mastery) an empty string.

**AC-3: Sanctuary-only slot writes**
- **Given** the system is in `LOCKED` (any of `SCOUT`, `WAVE_ACTIVE`, `INTERMISSION`, `OUTCOME`, `DEFEAT`)
- **When** any attempt is made to change an active-slot or passive-slot binding
- **Then** the write is rejected and no state changes, no recompute fires, and no EventBus event is emitted; the same attempt made while `CONFIGURABLE` succeeds immediately.

**AC-4: Duplicate skill_id across active slots is allowed, not blocked**
- **Given** `CONFIGURABLE` state
- **When** the same `skill_id` (e.g. `elem_frostbolt`) is assigned to 2, 3, or all 4 active slots
- **Then** no validation error is raised, the assignment succeeds in every slot, and `category_count` reflects one increment per occupied slot regardless of `skill_id` repetition (verifies Group 1 Rule 5 and Formula 3's Worked Example 2).

**AC-5: Skill catalogue reused-vocabulary integrity**
- **Given** `tower.md`'s Foundation `archetype` enum
- **When** this GDD's `category` enum is diffed against it
- **Then** the two enums are identical in cardinality (4) and in exact string values — no new taxonomy exists.

### Ultimate Derivation Precondition & Classification (Group 2)

**AC-6: Ultimate requires all 4 slots filled with known skills**
- **Given** 1, 2, or 3 active slots filled with known `skill_id`s (0 to 3 filled)
- **When** the Ultimate is computed
- **Then** `ultimate_id` resolves to `EMPTY`, identically to the "all 4 empty" case, and Formula 1 is never evaluated.

**AC-7: Unrecognized skill_id in a filled slot also yields EMPTY**
- **Given** all 4 slots are filled but one or more reference a `skill_id` marked `UNKNOWN` (orphaned, see Edge Cases)
- **When** the Ultimate is computed
- **Then** `ultimate_id` resolves to `EMPTY` (the "known skill" precondition in Rule 7 is not met).

**AC-8: Category profile sums to exactly 4**
- **Given** all 4 active slots filled with known skills in any combination
- **When** Formula 1 is evaluated
- **Then** the four `category_count` values are each in [0,4] and sum to exactly 4, with no category ever exceeding 4 or falling below 0.

**AC-9: Shape classification is total and mutually exclusive**
- **Given** any valid `category_count` vector produced by Formula 1 (four non-negative integers summing to 4)
- **When** Formula 2 is evaluated
- **Then** exactly one of {PURE, TRIPLE, DOUBLE_DOUBLE, DOUBLE_SINGLE_SINGLE, ALL_DIFFERENT} is returned — never zero shapes, never more than one.

### Combinatorial Tractability Proof (Formula 3) — dedicated rigor block, resolves game-concept.md's named High-Risk Systems entry

**AC-10a: The 35-profile raw enumeration is mathematically exhaustive**
- **Given** the claim that C(7,4) = 35 raw category-count profiles exist for 4 slots over 4 categories
- **When** every one of the 35 raw profiles enumerated by shape-count (PURE: C(4,1)=4; TRIPLE: 4×3=12; DOUBLE_DOUBLE: C(4,2)=6; DOUBLE_SINGLE_SINGLE: 4×C(3,2)=12; ALL_DIFFERENT: 1; total 4+12+6+12+1=35) is cross-checked against the stars-and-bars identity C(n+k-1, k) for n=4 categories, k=4 slots → C(7,4)=35
- **Then** the two independent derivations (shape-by-shape enumeration and the closed-form combinatorial identity) agree exactly, and every possible 4-skill category assignment (i.e., every size-4 multiset drawn from 4 categories) maps to exactly one of the 35 raw profiles — no combination of 4 equipped skills' categories can fall outside this table. A unit test must construct all 35 raw profiles programmatically (nested loop or itertools-equivalent generating every non-negative 4-tuple summing to 4) and assert the resulting set has exactly 35 unique members with no duplicates and no gaps.

**AC-10b: The 35→19 collapse is correct and complete — every profile has an authored Ultimate ID**
- **Given** all 35 raw profiles from AC-10a
- **When** each is passed through Formula 2 (shape classification) and then Formula 3 (Ultimate ID derivation)
- **Then** every one of the 35 profiles resolves to a non-null, non-`EMPTY`, non-`NONE` Ultimate ID drawn from the fixed 19-entry table (Formula 3), with zero profiles falling through to an undefined/panic/default case. A unit test must iterate all 35 profiles and assert `ultimate_id` is always a member of the 19-entry set, never `null`/`EMPTY`/`NONE`/an unrecognized string. The test must additionally assert the *fan-in* count per Ultimate ID matches the design table exactly: each `_ascendant` reached by exactly 1 profile, each `_overload` reached by exactly 3 profiles (the 3 non-dominant-category choices collapsed), each `_fusion` reached by exactly 1 profile, each `_surge` reached by exactly 3 profiles, and `convergence` reached by exactly 1 profile (1×4 + 3×4 + 1×6 + 3×4 + 1×1 = 4+12+6+12+1 = 35, confirming the collapse accounts for all 35 with no leakage).

**AC-10c: Matrix size is catalogue-size-independent**
- **Given** the catalogue's actual 2026-09-01 expansion from 8 skills to 32 (8 per category, Group 1 Rule 3) — no longer a hypothetical, this expansion has already happened
- **When** the same 35-profile-enumeration and 19-Ultimate-ID-collapse test from AC-10a/10b is re-run against the 32-skill catalogue (substituting only the `skill_id`→`category` mapping, never touching Formulas 1–3)
- **Then** the raw profile count remains exactly 35 and the distinct Ultimate ID count remains exactly 19 — identical to the original 8-skill Alpha catalogue — confirming the derivation depends solely on category count (fixed at 4) and slot count (fixed at 4), never on catalogue size, exactly as this AC predicted before the expansion shipped. A parametrized unit test must run this proof against at least two catalogue sizes (the original 8-skill Alpha fixture, retained for regression, and the current 32-skill catalogue) and assert both produce identical 35/19 counts.

### Ultimate Recompute & Ownership (Group 2, Rules 9–11)

**AC-11: Same-frame recompute on any active-slot change, cooldown discarded**
- **Given** an Ultimate is currently resolved (e.g. `elemental_ascendant`) and its cooldown is mid-countdown
- **When** any one of the 4 active slots is reassigned, cleared, or swapped (a single slot write)
- **Then** the category profile, shape, and `ultimate_id` are recomputed within the same frame as the slot write, `ultimate_skill_changed(ultimate_id)` is re-emitted with the new value even if the new resolved Ultimate happens to be identical to the previous one, and the previous Ultimate's in-progress cooldown timer is discarded (consistent with `hero.md`'s own already-written edge case — this GDD's mechanism does not alter that behavior, only supplies the value being recomputed).

**AC-12: Hero System applies but never re-derives**
- **Given** `ultimate_skill_changed(ultimate_id)` is emitted by Hero Skill Build
- **When** Hero System receives it
- **Then** Hero System sets its U-slot binding to the received `ultimate_id` verbatim and does not independently recompute a category profile or shape from raw skill IDs — verified by confirming Hero System's own code path contains no category-counting or shape-classification logic of its own.

### Passive Slots — EventBus Open Note 4 Resolution (Group 3)

**AC-13: No EventBus event fires for a passive-slot-only change; active-slot changes still emit**
- **Given** `CONFIGURABLE` state with an active-slot skill already equipped
- **When** a skill-modifier item is equipped into or removed from one of that skill's passive slots (a passive-slot-only change, no active slot touched)
- **Then** no EventBus event fires (no `skill_passive_equipped` or equivalent is emitted — none exists in the catalogue), and Hero Skill Build's internal passive-loadout data structure updates directly.
- **Given** the same starting state
- **When** instead an active slot (A/B/C/D) is reassigned
- **Then** `active_skill_equipped(slot_index, skill_id)` and (if the profile changes) `ultimate_skill_changed(ultimate_id)` fire as normal — proving the "no event" resolution is scoped strictly to passive-slot changes, not to all changes in this system.

**AC-14: Passive loadout is queryable via synchronous pull, not push**
- **Given** the Sanctuary skill-build screen opens
- **When** it needs to display a skill's current passive loadout
- **Then** it calls `HeroSkillBuild.get_passive_loadout(skill_id) -> Array[String]` synchronously at open time; no subscription or event delivers this data.

### Persistence Boundary — hero.md Rule 11 / tower-mastery.md Conflict Resolution (Group 4)

**AC-15: Slot assignments persist across missions within a playthrough, reset only on a new save**
- **Given** an active playthrough with A/B/C/D bound and passive slots filled
- **When** a mission ends via `MISSION_COMPLETE`, `DEFEAT`, or manual abandon, and the player returns to `SANCTUARY`
- **Then** all 4 active slot bindings, all passive slot bindings, and the resolved Ultimate are unchanged from their pre-mission values — no reset occurs on any mission-exit path, including `DEFEAT`.

**AC-16: Only a brand-new save resets slot assignments and the skill library together**
- **Given** a brand-new game/playthrough is started (new save, not a mission restart or a mission exit)
- **When** the new save initializes
- **Then** the equippable-skill library, all 4 active slot bindings, all passive slot bindings, and the resolved Ultimate all reset to empty/`EMPTY` in the same operation as Hero Skill Tree's own pool/node reset and Tower Mastery's `points_granted_count`/`mastery_time` reset (corrected 2026-08-31) — verifying `hero.md` Rule 11's "per-adventure" language and the rest of this chain's "new game" language describe the identical reset boundary, with zero scenarios where one resets without the others.

**AC-17: skill_unlocked subscription remains live during LOCKED, without unlocking a write path**
- **Given** the system is `LOCKED` (mid-mission) — **corrected 2026-08-31**: this is now a defensive-robustness test, not a realistic scenario, since `skill_unlocked` can only fire from Hero Skill Tree's Sanctuary-gated purchase path, which cannot occur while this system is `LOCKED`. Retained to confirm the always-on subscription (kept for architectural simplicity, not to defend a real race — see States/Transitions) behaves correctly even in a state combination that should no longer occur.
- **When** Hero Skill Tree emits `skill_unlocked(skill_id, source_tower_id)` (corrected 2026-08-31, was attributed to Tower Mastery)
- **Then** Hero Skill Build adds `skill_id` to its equippable library immediately (available the instant `CONFIGURABLE` is re-entered), but this library addition does not trigger an Ultimate recompute and does not constitute an active-slot or passive-slot write (AC-3's write-lock is not violated).

### Interface-Dependency-Flagged ACs (unresolved cross-GDD gaps)

**AC-18 [BLOCKED on Inventory revision]: Skill-modifier item_type support**
- **Given** the proposal that skill-modifier items use `item_type = "skill_modifier"` under Inventory's existing Equipment tab
- **When** `inventory.md`'s current tab-to-item_type mapping table is checked
- **Then** `skill_modifier` is **not currently a valid item_type** anywhere in `inventory.md` — this AC cannot pass today. It becomes testable only once Inventory's next revision adds `skill_modifier` to its Equipment-tab mapping table; until then, any test attempting to equip/unequip a skill-modifier item via Inventory's real API must be marked **blocked, not failing**.

**AC-19 [BLOCKED on registry revision]: Shared category/archetype enum cross-reference**
- **Given** the request that `design/registry/entities.yaml` gain a `referenced_by` cross-reference linking this GDD's `category` enum to `tower.md`'s `archetype` enum
- **When** `design/registry/entities.yaml` is inspected
- **Then** this cross-reference does not yet exist — this AC cannot pass until the registry update is performed. Track as a pre-implementation blocker, not a runtime defect.

**AC-20 [BLOCKED on registry revision]: 19-value ultimate_id enum registration**
- **Given** the request that the 19-entry Ultimate ID set (Formula 3) become a registry entry consumable by Hero System, Mission HUD, and this GDD without duplication
- **When** `design/registry/entities.yaml` is inspected
- **Then** no such enum entry exists yet — this AC cannot pass until the registry update is performed. Any implementation that hardcodes the 19 strings independently in more than one system is a violation of this pending resolution once the registry entry lands.

### Edge Cases — Orphaned Data & Content Changes

**AC-21: Orphaned skill_id in an active slot binding is preserved, not discarded**
- **Given** a save references a `skill_id` in an active slot that no longer exists in the current catalogue (removed/renamed post-launch)
- **When** the save is restored
- **Then** the slot binding is preserved and marked `UNKNOWN` internally (not auto-cleared), a warning is logged, the load is never blocked, and Ultimate derivation treats that slot as unfilled (Ultimate resolves to `EMPTY` per AC-7) until the player manually reassigns it at Sanctuary.

**AC-22: Orphaned skill_id in the equippable library is preserved but hidden from UI**
- **Given** the persisted equippable-skill library contains a `skill_id` no longer in the catalogue
- **When** the save is restored
- **Then** the entry is marked `UNKNOWN`, is not surfaced as assignable in the Sanctuary UI, is not discarded from persisted data, a warning is logged, and the load is never blocked.

**AC-23: Removed skill-modifier item in a passive slot is treated as empty for effects, preserved as a binding**
- **Given** a skill-modifier item currently installed in a passive slot is removed from the game's content data (post-launch, not a player action)
- **When** the save is restored or the skill activates
- **Then** the passive slot's occupant is marked `UNKNOWN`, contributes no effect to `effect_data` folding, the binding itself is preserved (not discarded), a warning is logged, and the load is never blocked.

**AC-24: passive_slot_count reduction returns the orphaned item to Inventory**
- **Given** a skill's `passive_slot_count` is reduced by a content patch (e.g., 3 → 2) and a save has an item bound to the now-nonexistent 3rd slot
- **When** the save loads post-patch
- **Then** the excess binding is restored internally but not rendered (only the current `passive_slot_count` sockets show), and the bound item is returned to the player's Inventory unlocked — the one orphan case in this GDD that actively returns something to the player.

**AC-25: Off-build passive configuration is allowed for unequipped skills**
- **Given** a skill exists in the library but is not currently occupying any active slot
- **When** the player equips a skill-modifier item into one of that skill's passive slots
- **Then** the equip succeeds — passive slot configuration is per-`skill_id`, not per-currently-equipped-slot.

### State Model

**AC-26: DORMANT → CONFIGURABLE → LOCKED transitions match the state table**
- **Given** the state table (States and Transitions)
- **When** `sanctuary_state_restored` fires from `DORMANT`, then `mission_launched` fires from `CONFIGURABLE`, then a mission ends and control returns to `SANCTUARY`
- **Then** the system transitions `DORMANT → CONFIGURABLE → LOCKED → CONFIGURABLE` exactly as specified, with slot writes accepted only during `CONFIGURABLE` (AC-3) and the Ultimate remaining live-readable (not writable) throughout `LOCKED`.

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Should Inventory's `inventory.md` be revised to add `item_type = "skill_modifier"` under the existing Equipment tab, or does Inventory's design intend a different placement? | inventory.md owner / systems-designer | Flagged in Group 3 Rule 13 and Dependencies. Blocks AC-18. This GDD's recommendation (Equipment tab, not a 5th tab) should be validated against Inventory's own next revision before implementation. |
| Should `design/registry/entities.yaml` be updated to add the `referenced_by` cross-reference between this GDD's `category` enum and `tower.md`'s `archetype` enum? | registry owner / technical-director | Flagged in Notes. Blocks AC-19. Same pattern as `tower-mastery.md`'s proximity-radius cross-reference request. |
| Should `design/registry/entities.yaml` gain a new 19-value `ultimate_id` enum entry (Formula 3's table)? | registry owner / technical-director | Flagged in Notes. Blocks AC-20. Needed so Hero System, Mission HUD, and this GDD reference one canonical list rather than three independently hardcoded copies. |
| ~~Is `restore_order = 32`...~~ | — | **RESOLVED 2026-08-31** — this was a stale question resting on stale numbers. This system's actual, already-assigned `restore_order` is 31 (confirmed against `save-persistence.md`'s authoritative table), not 32; Tower Mastery's is 34, not 31. No collision, no ordering dependency, nothing left to confirm. |
| Does the Sanctuary skill-build screen's library panel intend to show not-yet-learned (locked) skills as a visible roadmap, or only currently-unlocked skills? | ux-designer / systems-designer | Visual/Audio Requirements conditionally describes a locked-entry treatment ("if the systems design intends this list to show locked entries") but does not commit either way — needs a decision before UI implementation. |
| ~~Should typed passive slots be considered for a post-Alpha revision...~~ | — | **RESOLVED 2026-09-01** — typed slots shipped now, not deferred: Rule 13 revised so passive-slot skill-modifier items carry `requires_tag: String`, checked against the socketed skill's `tags` at equip time. The untyped flat-pool model is retired, not permanent. |
| Who authors remaining tuning/balance numbers for the 32-skill catalogue (damage coefficients, secondary-effect magnitudes), and on what timeline relative to implementation? | content-design owner / producer | **Narrowed 2026-09-01** — `effect_data`'s *schema* is no longer deferred (Group 1 Rule 2: `damage_type`/`delivery`/`skill_power_coefficient`/`secondary_effect`/`tags`, all populated per-skill in Rule 3/Rule 14). What remains open is final balance-pass tuning of those populated values, not their structure. Not a blocker for the systems described in this GDD, but a blocker for playable content. |
