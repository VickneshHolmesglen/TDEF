# Tower System GDD — Review Log

---

## Review — 2026-05-14 (lean re-confirmation) — Verdict: APPROVED (confirmed)
Scope signal: L
Specialists: None (lean mode)
Blocking items: 0 | Recommended: 3
Summary: Re-confirmation pass. Zero blocking items found. No regressions detected when cross-referenced against the now-approved Monster System GDD (pass 6) and D&S GDD (pass 6): `is_armored: bool` on `tower_attacked` is correctly specified (Rule 20a); Tower GDD does not reference `hero_bonus_tier` (Tower fires attacks; D&S owns the damage math); `boss_tower_attack_attempted` `wave_id` field confirmed in OQ-1. Three recommended items: R1 (stale status header — fixed in-session), R2 (5 EventBus GDD pre-implementation updates already tracked in Dependencies section), R3 (Hero GDD OQ-2 — `tower_removed` subscription — tracked for Hero GDD review). Document is implementation-ready for all MVP-tier content.
Prior verdict resolved: Yes — Review 9 / Revision 10 APPROVED confirmed; no regression

---

## Review — 2026-05-11 (Review 9) — Verdict: NEEDS REVISION → APPROVED (accepted without re-review)

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, ai-programmer, performance-analyst, qa-lead, creative-director
Blocking items: 6 | Recommended: 20
Summary: Review 9 confirmed all 18 Review 8 blockers were resolved in Revision 9. Six new blockers found: (1) `is_siege` placed on `boss_tower_attack_attempted` (boss→tower direction) — corrected to `tower_attacked` in Revision 10; (2) B-13 AC asserted CONNECT_DEFERRED for `monster_spawned` despite the subscription table specifying Synchronous — AC rewritten to assert mid-frame cache visibility; (3) RANGE_BOOST/AURA_EXTEND perk floor math wrong — GDD stated 0.125 floor with "eliminates dead zone" rationale but actual dead-zone boundary is 0.0625/0.10 — floors corrected to match math (Option A); (4) AoE fan-out uncapped — BALLISTIC AoE at max density could generate 400 `monster_damage_taken` per frame vs. ~20 baseline — `aoe_density_cap` Tuning Knob added (default 5); (5) no AC testing AURA_EXTEND min(6, ...) clamp at schema ceiling — AC added; (6) no AC testing `scatter_target_cycle` field population in TowerWaveSummary — AC added. Creative-director pillar challenge (D2-B/D3-A: partial-info Intermission preview and T1/T2 budget-gate identity) recorded as Pillar Watch items requiring playtest falsification; not revision blockers. User accepted all fixes as Revision 10 and approved without re-review.
Prior verdict resolved: Yes — all 18 Review 8 blockers resolved in Revision 9; 6 new blockers found and resolved in Revision 10.

---

## Review — 2026-05-10 (Review 8) — Verdict: MAJOR REVISION NEEDED

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, ai-programmer, performance-analyst, qa-lead, creative-director
Blocking items: 18 | Recommended: 18
Summary: Review 8 confirmed all 30 blockers from Review 7 were resolved in Revision 7. A new layer of 18 blockers was found across three tiers. Tier A (correctness): DEFEAT→SCOUT cache contamination (ai-programmer — highest severity; silent corruption on restart); HOMING one-frame ghost flight and SPAWN_ORDER cold-frame miss (DEFERRED subscription timing violations); projectile pool undersized at max_towers=20 anchor (grid allows 60+); HOMING re-acquisition unbounded at scale. Tier B (design/pillar): SCATTER targeting contradicts "tower does not improvise" authorship pillar with no player validation surface; mandatory full Intermission preview converts authorship to reactive optimization; T3 dominant strategy collapses T1/T2 build space. Tier C: three spec/formula issues (range dead zone, sell refund floor, SCATTER sigma label) and four AC test design failures. Three EventBus cross-doc payload mismatches. Creative-director verdict: structural work is done; this review reveals insufficient EventBus co-maintenance across revisions — EventBus must be updated in the same changeset as Tower GDD going forward. Three user decisions required before Rev 9 begins (SCATTER fix path, preview scope, T1/T2 differentiation). Work queue at `production/work-queue/tower-rev9.md`.
Prior verdict resolved: Yes — all 30 blockers from Review 7 addressed in Revision 7; 18 new blockers found in this pass.

---

## Review — 2026-05-02 (Review 7) — Verdict: MAJOR REVISION NEEDED

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, ai-programmer, performance-analyst, ux-designer (rate-limited — no findings), qa-lead (rate-limited — no findings), creative-director
Blocking items: 30 | Recommended: 12
Summary: Seventh-pass review confirmed that the GDD was not revised after Review 6 — all 23 prior blockers remain, and 7 new blockers were identified. The document header still reads "Revision 5 — 2026-05-02". Key new blockers: T4 tier_cost_factor=3.0 is economically incoherent (makes T4 strictly DPS/cost dominant at 1.33 vs T3 1.20 — the "glass cannon" framing is mathematically false); `tower_wave_summary` is absent from the EventBus catalogue entirely; `tower_aura_pulse` uses 5 typed params in EventBus violating Core Rule 4 (requires TowerAuraPulseEvent Resource subclass); `_rng.randomize()` in Rule 15 contradicts AC 36's determinism requirement; Formula 2 Example B references cell (8,12) which is out of bounds on a 16×12 grid. User design decision: T4 tier_cost_factor = **4.0×** (specialist tier — T4 DPS/cost=1.00, HP/cost=0.625; T4 is a boss-lane investment, not an efficiency apex). Creative-director finding: the root cause of 7 consecutive MAJOR REVISION NEEDED verdicts is that revision sessions are not being applied before re-review; the blocker list is growing, not shrinking.
Prior verdict resolved: No — GDD not revised after Review 6; all 23 prior blockers remain; 7 additional blockers found

---

## Review — 2026-05-02 (Review 6) — Verdict: MAJOR REVISION NEEDED

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, ai-programmer, performance-analyst, ux-designer, qa-lead, creative-director
Blocking items: 29 | Recommended: 13
Summary: Sixth-pass review found that Revision 5's headline mechanic (perk transfer) is unimplementable as written: a GDScript Dictionary-as-key bug silently fails every transfer at runtime, a missing HUD event makes the transferred badge invisible, and a collision rule discards the replacement tower's own perk without any player notification. These are compile-equivalent failures in the system's most complex new rule. Additionally, the T4 tier-balance narrative in the GDD ("glass cannon") is mathematically false — T4 is strictly economically dominant at equal budget (11% DPS advantage), contradicting the Endless Theorist pillar. Six AI/concurrency specification gaps (CONNECT_DEFERRED underspec, mission-start cache clear bug path, RNG seed collision, wave_completed same-frame fire, SPAWN_ORDER batch determinism, HOMING same-frame race) and 17 missing ACs from Revision 5's new rules complete the blocking picture. Creative-director recommendation: cut perk transfer from MVP — it is a net-positive repositioning exploit, has caused 3 consecutive MAJOR REVISION verdicts, and is not load-bearing for any design pillar. User accepted this recommendation.
Prior verdict resolved: Partially — Revision 5 resolved 20 blockers from Review 5; this review found 29 new blockers, of which 6 were in perk transfer (now cut from MVP by user decision)

---

## Review — 2026-05-02 (Review 5) — Verdict: MAJOR REVISION NEEDED

Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, ai-programmer, performance-analyst, ux-designer, creative-director (qa-lead: API rate limit — no findings)
Blocking items: 20 | Recommended: 16
Summary: Fifth-pass review surfaced 20 implementation-blocking issues across two tiers: five structural design decisions still unmade (B-group) and fifteen spec gaps resolvable as line-edits (A-group). The two most critical blockers are unresolved pillar-level gaps: (B2) the authorship fantasy is only guaranteed for Wave 1 — wave preview for INTERMISSION decisions is unconfirmed, making 7 of 8 placement waves effectively blind; and (B1) perk transfer is an entirely unspecified mechanic (no "same Intermission" tracking mechanism, no tier constraint, no player feedback, no collision rule when the replacement tower has its own perk). Additional significant blockers: perk dead zones (RANGE_BOOST/AURA_EXTEND yield 0 cells at minimum perk_power), INTERMISSION UX workflow with no interaction model, stagger formula divides-by-zero at N=0, HP reset inference breaks for zero-damage towers, HOMING queue_free intra-frame hazard, RANDOM RNG not isolated per tower, and projectile pooling entirely unspecified. Creative-director notes: resolving B1 (cut or fully specify perk transfer) and B2 (mandate wave preview at INTERMISSION start) could downgrade the verdict to NEEDS REVISION for the next pass.
Prior verdict resolved: Partially — Revision 4 resolved 11 blockers from Review 4; this review found 20 new/unresolved blockers

---

## Review — 2026-05-01 (Session 3) — Verdict: MAJOR REVISION NEEDED → REVISED (same session pair)

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, economy-designer, ai-programmer, performance-analyst, ux-designer, creative-director
Blocking items: 11 | Recommended: ~12
Summary: Fourth-pass review (re-review of revision 3) found 11 implementation-blocking issues introduced or uncovered by revision 3's architectural decisions. Key blockers: `_current_target_id` sentinel was `0` not `-1` (entity_id = 0 is a valid monster ID — first monster per mission would be silently misidentified as "already acquired"); OQ-8 `monster_breached` subscription confirmed as a cache hygiene bug and resolved; HOMING projectile had two crash paths (originating tower freed mid-flight; empty re-acquisition pool at wave end); stagger offset had no allocation guarantee — changed to stratified slot assignment; `monster_damage_taken` batch coherence window documented as accepted approximation; HP reset specified as silent internal with HUD inference from `wave_completed`; 2×2 range anchor changed to centroid (top-left anchor was visually asymmetric); pre-placement perk schema (type enum, power range, TowerPerkRegistry) was entirely unspecified; Support archetype missing from state table. Four design decisions resolved: post-wave `tower_wave_summary` event contract added (minimal event approach); T4 DPS multiplier raised to 4.0 (DPS/cost now 1.33 > T3's 1.20 — strictly monotone tier progression); no-refund rule made explicit with same-archetype perk transfer within same Intermission; perk schema (TowerPerkType enum, perk_power [0.05–0.25], TowerPerkRegistry) added as Rule 12a. Seven ACs added. Re-review in fresh context recommended.
Prior verdict resolved: Yes — Revision 3 had 12 blockers (all resolved 2026-05-01); this review found 11 new blockers in the same session

---

## Review — 2026-05-01 (Session 2) — Verdict: MAJOR REVISION NEEDED → REVISED (same session pair)

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, economy-designer (rate-limited — no report), ai-programmer, performance-analyst, ux-designer, creative-director
Blocking items: 12 | Recommended: ~2
Summary: Third-pass review found deep mechanical and spec consistency issues introduced by the second revision's architectural decisions. Key blockers: WAVE_ACTIVE placement allowed — directly contradicts "Placement is the Puzzle" authorship pillar and was reversed to a full block; FIRST_IN targeting mode replaced with SPAWN_ORDER (lowest entity_id in range) eliminating per-tower arrival-list architecture debt; Support archetype could never fire due to Rule 17 requiring a valid monster target — Rule 17 carve-out added for unconditional aura pulse; 360° cone carried no mechanical penalty — cone range bonus (+1/+2 cells for narrow cones) added to Formula 2; `_monster_cache` was missing `current_hp` field required by LOWEST_HP/HIGHEST_HP targeting modes; `attack_speed` validation range was stated as [0.3, 6.0] in two locations despite the schema specifying [0.5, 4.0] — all three reconciled; tier cross-field consistency validation added; `monster_breached` cache subscription identified as required for SPAWN_ORDER correctness (OQ-8). Economy-designer review incomplete due to API rate limit — recommend re-running before final Approval. Re-review in fresh context recommended.
Prior verdict resolved: Yes — Revision 2 had 28 blockers (all resolved 2026-05-01); this review found 12 new blockers in the same session

---

## Review — 2026-05-01 — Verdict: MAJOR REVISION NEEDED → REVISED (same session pair)

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, economy-designer, ai-programmer, performance-analyst, ux-designer, creative-director
Blocking items: 28 | Recommended: ~4
Summary: The revised Tower System GDD had solid architectural bones from the first revision but surfaced deeper systemic gaps once specialist agents reviewed the full document: EventBus contract drift (tower_placed/tower_destroyed/boss_tower_attack_attempted payloads were never updated in the EventBus GDD after OQ-1 resolution), a missing monster data access model (towers had no specified mechanism to acquire targeting data given the EventBus-only architecture), and a mathematically false DPS economy claim (Tier 1 remained dominant by 19–33% DPS/cost margin). Six design decisions were made before revision: Support archetype defined for MVP as an AURA model (no projectile, tower_aura_pulse event); tier_dps_multiplier rebalanced to {1.0, 1.6, 2.4, 3.5} giving DPS/cost ratios T1=1.00/T2=1.07/T3=1.20/T4=1.17; WAVE_ACTIVE placement allowed with perk forfeited (game-concept Rule 5 wins over Tower GDD Rule 8); intermission duration canonicalized to 25–40s (Tower GDD wins over game-concept); EventBus cache model adopted for monster targeting data; path-guard rejection uses visual-only feedback. All 28 blockers resolved; re-review recommended in a fresh context session.
Prior verdict resolved: Yes — Revision 1 had 25 blockers (all resolved 2026-04-27); this review found 28 new blockers in deeper architectural layers

---

## Review — 2026-04-27 — Verdict: NEEDS REVISION → REVISED (same session pair)

Scope signal: L  
Specialists: game-designer, systems-designer, qa-lead, economy-designer, gameplay-programmer, ai-programmer, performance-analyst, ux-designer, level-designer, creative-director  
Blocking items: 25 | Recommended: ~8  
Summary: The Tower System GDD had strong structural bones — 4-slot component model, archetype system, and placement workflow were coherent — but had critical spec gaps that would have blocked implementation: Formula 1 was missing `tier_dps_multiplier` (Tier 1 spam dominant strategy), `tower_facing_dir` was undefined in Formula 2, the "AI tick" terminology was unprogrammable, `pending_recovery` contradicted the save schema, and `pre_placement_perk_activated` timing had three contradictory specs. Four design decisions were made before revision: Scout Phase surfaces wave composition preview; destroyed tower components return as `damaged` (repair required at Sanctuary); `tier_dps_multiplier` added to Formula 1; facing direction is fixed compass enum in Focus component. All 25 blockers resolved across two sessions; re-review recommended in fresh context.  
Prior verdict resolved: First review  
