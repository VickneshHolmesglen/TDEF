# Monster System — Design Review Log

## Review — 2026-08-27 — Verdict: APPROVED (confirmed, 2 stale cross-references fixed)
Scope signal: S
Specialists: None (lean depth — single-session analysis, autonomous pass)
Blocking items: 0 | Recommended: 2 (both fixed in-session)
Summary: Re-review of an already-Approved doc (Approved since pass 7's 2026-07-17 re-review) looking for staleness, following the same pattern that found real drift in 4 sibling GDDs during S8-07. Found 2: (1) **OQ-8** still described the Menagerie attraction material as unresolved/placeholder ("Until the Resource Economy GDD defines this... do not produce actual items"), but `resource-economy.md` Rule 6 and `menagerie.md`/`src/core/menagerie/menagerie.gd` have fully specified and shipped this (`menagerie_lure` material, `Menagerie.attempt_lure()` consumption) for some time — marked RESOLVED with the real citation. (2) The Dependencies table's Resource Economy row still said "Until Resource Economy GDD is authored, all drop behavior... is untestable" and "hard prerequisite" — also long since resolved; reworded to point at the shipped Rule 5/Rule 6 contracts instead. While tracing (1), also found `resource-economy.md`'s own Rule 6 had the identical staleness in reverse ("Consumed only by the Menagerie System (not yet designed)") — fixed there too, cross-referencing the real shipped consumer. No blocking issues found; document's mechanical content (formulas, ACs, edge cases) remains sound with no regressions.
Prior verdict resolved: Yes — Approved (2026-07-17) confirmed, no regression; only cross-doc staleness found and fixed.

---

## Cross-Doc Correction — 2026-07-15 (post-pass-7) — Lifesteal-on-Kill Structurally Impossible
`/review-all-gdds`'s cross-system scenario walkthrough traced `damage-status.md`'s Rule VII (whose stated purpose is "preserve lifesteal heals on the killing blow of a wave") against this document's actual mechanics and found Rule 21f directly contradicted it: on any lethal `monster_damage_taken` hit, the entity's `_pending_absorbed` entry was erased and `monster_hp_absorbed` was explicitly never emitted for it (confirmed by this document's own AC-36, which asserted that exact suppression as correct behavior). Since D&S's lifesteal resolution (Rule VI) is entirely gated on receiving `monster_hp_absorbed`, this meant lifesteal could never heal the hero on a killing blow, deterministically — not a rare timing race, a 100%-of-the-time structural gap that had existed since Rule VII was authored in `damage-status.md`, undetected until a full cross-system trace was performed. Root cause: Rule 21f's erase-before-flush behavior, not any timing/ordering issue. Fixed: Rule 21f no longer erases the entry — it accumulates the killing blow's `absorbed` amount (`min(amount, pre_hit_hp)`, well-defined even on a lethal hit) into `_pending_absorbed` just like any non-lethal hit, and lets it flush normally in the same end-of-frame absorbed-flush pass (pass 4 of the documented 4-pass `_physics_process` structure). Traced the corrected timing explicitly: `monster_died`/`wave_completed` cascade happens during the movement pass (pass 3, per EC-3.1's centralized-pass ordering), which runs *before* the absorbed flush pass (pass 4) within the same `_physics_process` call — so a killing blow's `monster_hp_absorbed` now reliably resolves in D&S *after* `wave_completed` has already registered its deferred `_lifesteal_pending` clear (Rule VII.2) but *before* that deferred clear resumes on the next frame. No residual race. AC-36 corrected to assert the new (correct) behavior.
Prior verdict resolved: N/A — this predates pass 7 and every prior pass; it was a design-intent gap between this document and damage-status.md that no single-document review could have caught, only a cross-system trace.

---

## Review — 2026-07-15 (pass 7) — Verdict: NEEDS REVISION → REVISED (same session)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, creative-director (synthesis)
Blocking items: 6 | Recommended: 3
Summary: Triggered by `/review-all-gdds` finding a stale "Wave 4" Overview sentence and a suspected Formula 3 boundary gap. All three specialists confirmed both. systems-designer then found something far more significant, previously undetected across 6 prior approval passes: Formula 4's own worked example (5-wave mission, default values) computes a penultimate-wave ELITE at 587.25 HP, then its closing sentence claims "Final wave Normal remains peak (615 HP)" to argue monotonic escalation — but 615 HP is the wave-8 STANDARD figure from an unrelated 8-wave mission, not this 5-wave example's actual final wave (which is only 480 HP, already exceeded by the penultimate ELITE). systems-designer additionally found the existing Tuning Knobs co-dependency warning's specific figure (amplifier breaks monotonicity "at ≥1.354") was mathematically impossible at the stated growth rate — the real situation is worse: monotonicity against the next STANDARD wave breaks across the ENTIRE amplifier safe range (1.20-1.40) whenever `hp_wave_growth_rate=0.12`. creative-director independently re-verified this arithmetic before synthesizing and confirmed the review had moved from "scoped fix" to "design-decision territory." Two design decisions were made by the user (declined to be settled unilaterally): (1) the escalation invariant is reframed from "penultimate ELITE < next-wave STANDARD HP" (mathematically unenforceable within documented safe ranges) to "penultimate ELITE < final-wave BOSS HP" (holds by construction, matches the feature's own "sub-boss spike" intent); (2) Formula 3's final-wave `base_damage` floor is narrowed 40→55 rather than loosening the 8-15 hit target, since game-designer and creative-director agreed the low end read as the boss feeling passive/inert — a Player Fantasy problem, not a pure math error — and this closes a confirmed boundary failure (wave 5/base_damage=40 previously gave 18 hits against a Tier 4 tower, above target). Also fixed: stale "Wave 4" Overview text; Rule 18's Tier 1 "3-5 hits" target rescoped to early-wave bosses only (never achievable against a final-wave boss at any authored value); AC-44 (Formula 3 boundary) and AC-45 (Formula 4 wave-4-regression guard) added.
Prior verdict resolved: Partially — pass 6's re-confirmation stands for everything except Formula 3/4, where this pass found a genuine defect that had survived all 6 prior passes undetected.

---

## Review — 2026-05-14 (pass 6 re-confirmation) — Verdict: APPROVED (confirmed)
Scope signal: XL
Specialists: None (lean mode)
Blocking items: 0 | Recommended: 3 (all applied in-session)
Summary: Re-confirmation pass triggered because CLAUDE.md "Up Next" list predated the pass-5 approval. No regressions found. Two carry-over pass-5 recommended items (co-dependency threshold inaccuracy, Rule 17a scan order ambiguity) were addressed in-session: threshold corrected from ≥1.38 to ≥1.354 (exact formula: 1.84/1.36), Rule 17a rewritten to state explicit decrement-first / scan-check-second sequential order. One new recommended item also applied: Formula 2 Tarot application note added to disambiguate one-pass vs. two-step implementation equivalence. Document remains APPROVED.
Prior verdict resolved: Yes — pass 5 APPROVED confirmed; no regression

## Review — 2026-05-14 (pass 5) — Verdict: APPROVED

Scope signal: XL
Specialists: None (lean depth — single-session analysis)
Blocking items: 0 | Recommended: 2
Summary: Fifth review pass; first APPROVED verdict. Structural model is stable after four prior revision passes resolving 74 total blockers. Two recommended clarifications found: (1) Tuning Knobs co-dependency warning overstates the safe threshold for `elite_wave4_hp_amplifier` at low `hp_wave_growth_rate` (states ≥1.38 breaks monotonicity; actual breakpoint is ≈1.353); (2) Rule 5 phrasing implies mutually exclusive decrement/scan per frame, but EC-3.1 and AC-37 together require sequential evaluation (decrement then scan in same pass). Both are caught by existing ACs and do not block implementation. Dependency graph fully intact; all MVP dependency GDDs exist on disk.
Prior verdict resolved: Yes — 11 blockers from 2026-05-12 (pass 4) confirmed resolved.

---

## Review — 2026-05-12 (pass 4) — Verdict: MAJOR REVISION NEEDED → REVISED (same session)

**Scope signal:** XL
**Specialists:** game-designer, systems-designer, qa-lead, performance-analyst, ux-designer, godot-gdscript-specialist, creative-director (synthesis)
**Blocking items:** 11 | **Recommended:** 8
**Prior verdict resolved:** Yes — 12 blockers from 2026-05-12 (pass 3) confirmed resolved

**Summary:** Fourth review pass. Three categories of blockers. (1) Schema incompleteness (B1–B3): `boss_scan_frames_remaining` and `_locked_target_id` were referenced in rules but absent from Rule 5 schema; EC-3.1's three-pass `_physics_process` had no home for BOSS logic — resolved by adding both fields to Rule 5 and expanding EC-3.1 to a four-pass model (damage → BOSS Logic → movement → absorbed flush). (2) Contradictions (B4, B6): EC-5.2 and the Visual/Audio breach note both claimed `boss_died` is NOT emitted on BOSS breach, contradicting EC-3.2, AC-30, and OQ-6 — resolved by correcting both stale statements. Rule 17c's cooldown-reset-on-empty-scan was a design question (hold prime vs. reset): decided to hold prime (cooldown stays 0 when no towers in range); AC-14 and EC-5.1 updated accordingly. (3) Boundary enforcement (B5, B7, B9, B10, B11): `_pending_absorbed` clear semantics were ambiguous (frame-scoped vs. wave_completed only) — now explicitly frame-scoped with wave_completed as safety fallback. `monster_damage_taken` accumulation specified as internal buffer queue (`_pending_damage: Array[MonsterDamageTaken]`) to guarantee damage resolves in the damage pass, not asynchronously. AC-18 THEN corrected to match EC-3.1 (entity stays in `active_monsters` until movement pass filter). AC-31 narrowed to Monster System outputs only. AC-43 added for wave-end 150-entity force-removal performance. (4) Architecture (B8): AnimationTree additive blend replaced with two stacked AnimatedSprite2D nodes (base walk + overlay attack); BOSS scene structure spec added to Visual/Audio section; Rule 17d/d.1 and Rule 22 updated. Total ACs: 43 (42 sprint-blocking; AC-10 post-MVP).

---

## Review — 2026-05-12 — Verdict: NEEDS REVISION → REVISED (same session)

**Scope signal:** XL
**Specialists:** game-designer, systems-designer, qa-lead, performance-analyst, ux-designer, creative-director (synthesis)
**Blocking items:** 12 | **Recommended:** 8
**Prior verdict resolved:** Yes — 22 blockers from 2026-05-11 confirmed resolved

**Summary:** Third review pass. Key findings: (1) AC-12/AC-32/AC-21 contradiction — all three ACs tested immediate attack fire on cooldown=0, but Rule 17d requires prepare phase to complete first before `boss_tower_attack_attempted` emits; three specialists independently flagged this as the most critical blocker. Resolved by rewriting AC-12, AC-32, and AC-21 to test Phase 1 (prepare entry, no fire) and adding new AC-42 for the Phase 2 (prepare→fire) transition. (2) `hero_bonus_applied: bool` schema drift — MonsterResource, Rule 15, Rule 20, Interactions table, Dependencies, and OQ-4 all referenced the stale field name from before the D&S GDD revision (2026-05-12). Updated throughout to `hero_bonus_tier: int` with full 0/1/2 value mapping. (3) `hero_damage_bonus_eligible` in MonsterResource schema deprecated — `"attack_prepare"` animation added to sprite_frames requirements. (4) AC-11 had untestable "high enough speed" GIVEN; replaced with concrete values (scaled_speed=120.0, delta=1/60). (5) AC-37 lacked `boss_scan_frames_remaining=0` in GIVEN, making frame-1/frame-7 assertion non-reproducible. (6) OQ-7 closed — BOSS breach confirmed informational only; "highest stakes / mission-ending" language removed. (7) `elite_wave4_hp_amplifier` tuning knob gained co-dependency warning: monotonic escalation breaks at growth_rate=0.12 when amplifier ≥ 1.38. (8) BOSS targeting note "not exploitable" removed; replaced with honest accepted-consequence framing. Total ACs: 42 (41 sprint-blocking; AC-10 post-MVP).

---

## Review — 2026-05-11 — Verdict: MAJOR REVISION NEEDED → REVISED (same session)

**Scope signal:** XL
**Specialists:** game-designer, systems-designer, qa-lead, performance-analyst, ux-designer, creative-director (synthesis)
**Blocking items:** 22 | **Recommended:** 8
**Prior verdict resolved:** Yes — 29 blockers from 2026-04-26 confirmed resolved

**Summary:** The re-review identified 22 blockers across five areas. (1) Architecture/accumulator: the per-hit `await get_tree().process_frame` coroutine for `monster_hp_absorbed` was replaced with an end-of-frame `_pending_absorbed: Dictionary[int, float]` accumulator flushed once per `_physics_process`, eliminating GC pressure and the lifesteal multi-fire bug; Rule 21 rewritten; EC-3.1 updated to a three-pass `_physics_process`; `pre_hit_hp` type corrected from `int` to `float`. (2) BOSS attack design: EC-5.1 insta-hit bug fixed in Rule 17c (cooldown resets to `base_attack_interval` when no towers in range at cooldown=0); `attack_prepare` telegraph phase added (Rule 17d/d.1) with `boss_attack_prepare_remaining: int` field; `boss_attack_prepare_frames` added to Tuning Knobs; `"attack_prepare"` animation required in Visual/Audio. (3) `wave_reward_scalar` orphan: Monster System now caches at spawn and forwards as 8th field in `monster_died`; EventBus GDD updated to 8-field `MonsterDied` Resource; Resource Economy cross-system contract (`kill_source == "wave_end"` must suppress drops) formalized in Dependencies. (4) AC quality: 12+ ACs rewritten for independent testability (AC-8 frame math, AC-10 marked Post-MVP, AC-14 corrected to reflect cooldown reset, AC-23 idle-state observable, AC-27 uses valid tarot_speed_scalar=0.5, AC-28 updated to 150-entity cap, AC-33 unit-isolated); 7 new ACs added (AC-35–AC-41 covering absorbed normal/lethal, BOSS scan throttle, entity_id counter, Tarot non-retroactive, AoE burst performance, and telegraph phase). (5) Registry: `elite_penultimate_wave_hp_amplifier` (1.50) reverted to `elite_wave4_hp_amplifier` (1.35); Formula 3 corrected from "15–164" to "15–136"; `MAX_ACTIVE_MONSTERS = 150` hard cap added with spawn discard warning. Visual/Audio: ARMORED hit visual feedback mandated (tower hits only); `"attack_prepare"` audio event added. Total ACs: 41 (40 sprint-blocking; AC-10 post-MVP).

---

## Revision — 2026-04-26 — All 29 Blockers Resolved

**Prior verdict:** MAJOR REVISION NEEDED (2026-04-26)
**Revision outcome:** All 29 blocking items addressed in-session. Status updated to "Revised (post-review — pending re-review)".

**Key changes made:**
- B1: Deleted Rule 23 batching conflict; Monster System emits `monster_died` synchronously; Wave Manager owns batch accumulation
- B2/B3: `wave_difficulty_scalar` → `wave_reward_scalar`; OQ-1/2/3 closed (all three events already registered)
- B6/B9: EventBus `monster_died` expanded to 7-field `MonsterDied` Resource; field naming aligned (`entity_id: int` + `monster_id: StringName`) across `monster_spawned`, `monster_died`, `boss_died`
- B7: `boss_tower_attack_attempted` and `boss_hp_changed` added to EventBus catalogue (63 total events)
- B8/OQ-4: Rules 20–21 updated to `amount: int` + `source_type: int` from D&S `MonsterDamageTaken` Resource; `resolved_damage`/`hit_source`/`is_lethal` removed
- B10: BOSS targeting changed from lowest-HP to closest-by-Chebyshev; scan throttle added (`boss_scan_interval_frames`)
- B11: `elite_wave4_hp_amplifier` 1.50 → 1.35 (Wave 4 Normal = 1.9575× < Wave 8 Normal = 2.05×; monotonic escalation restored)
- B12: Force-removal drops → no drops for force-removed monsters (symmetric with breach)
- B13: `archetype_tag = &"armored"` defined: D&S applies 50% tower damage mitigation; MVP behavioral rule specified
- B14: AnimationTree with additive blend node specified (AnimationPlayer cannot layer animations)
- B15: Centralized `_physics_process` pattern specified (2-pass: damage then movement); per-entity `_physics_process` prohibited
- B16: `path_arrival_threshold` added to Tuning Knobs (default 4.0 world units)
- B17: `Grid.get_towers_in_range()` added to Grid GDD read API; Grid GDD Interactions updated
- B18: Area2D root node specified (CharacterBody2D prohibited)
- B19/OQ-6: `boss_died` now fires on breach (`cause="breached"`) and force-removal (`cause="force_removed"`); `cause: String` added to payload
- B20/OQ-5: `boss_hp_changed` added as MVP-required event (Rule 21c); EventBus updated; UI Requirements section resolved
- B21–B26: 6 new ACs added (AC-29 through AC-34); total 28 → 34 ACs
- B27: EC-1.2 marked as dead code at MVP (Grid locks writes during WAVE_ACTIVE)
- B28: AC count aligned (preamble, gate table, actual count all = 34)
- B29: `spawning_entities: Array[MonsterEntity]` added to Rule 8 (system list, not per-entity schema)

**Cross-file changes:** EventBus GDD (3 event payloads corrected, 2 events added), Grid GDD (`get_towers_in_range()` + Monster System interaction row added), systems-index.md (status updated).

---

## Review — 2026-04-26 — Verdict: MAJOR REVISION NEEDED

**Scope signal:** XL
**Specialists:** game-designer, systems-designer, qa-lead, performance-analyst, godot-gdscript-specialist, ux-designer, audio-director, level-designer, creative-director
**Blocking items:** 29 | **Recommended:** 11
**Prior verdict resolved:** N/A — first review

**Summary:** The Monster System GDD is technically detailed and largely coherent in isolation, but contains three categories of blocking issues. First, cross-GDD architectural conflicts: Monster GDD Rule 23 (Monster System batches `monster_died`) directly contradicts EventBus GDD AC-10 (Wave Manager fires `monsters_died_batch`; `monster_died` fires 0 times) — an unresolvable binary contradiction requiring deletion of Rule 23. Multiple payload field names and types differ between Monster GDD and EventBus/D&S GDDs (`amount: int` vs `resolved_damage: float`, `source_type: int` vs `hit_source: String`, `monster_id` naming inversion). `boss_tower_attack_attempted` is not registered in EventBus. Second, pillar failures: `archetype_tag` produces no behavioral difference at MVP, BOSS lowest-HP targeting enables a trivializing sacrificial-decoy exploit, force-removal asymmetry (Menagerie drop resolves on force-removal but not breach) inverts the reward structure and creates a degenerate non-kill strategy. Wave 4 HP amplification (2.175×) exceeds Wave 8 at every difficulty tier — a false-summit pacing problem rather than an escalating challenge. Third, implementation blockers: AnimationPlayer cannot layer animations (requires AnimationTree), EC-3.1 ordering guarantee is not implementable in per-entity _physics_process, `PATH_ARRIVAL_THRESHOLD` is undefined, `Grid.get_towers_in_range()` is undefined in Grid GDD, monster body type is unspecified (CharacterBody2D fights the multi-occupancy rule), and six AC coverage gaps exist. Creative director's priority order: (1) batching conflict — unblocks Wave Manager and EventBus re-reviews; (2) payload/naming inversions — silent-bug prevention; (3) BOSS targeting and Wave 4 formula — pillar correctness; (4) all implementation blockers.
