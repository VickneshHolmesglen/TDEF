# Review Log: Wave Manager GDD

---

## Review — 2026-05-22 (tenth review) — Verdict: APPROVED
Scope signal: L
Specialists: lean mode (no specialist agents)
Blocking items: 0 | Recommended: 3
Summary: Lean re-review of the fully-revised document (post review #9). All prior blockers confirmed resolved. No new blocking issues found. Three recommended revisions applied in-session: (R1) Rule 9 updated to reference `scout_phase_min_duration` tuning knob rather than hardcoding "≥ 0s elapsed" — corrects a latent inconsistency if the knob is ever raised above its 0s default; (R2) AC-41 added for runtime `wave_time_budget` validation behavior at `mission_launched` — the runtime check was specified in Rule 3 but had no corresponding acceptance criterion; (R3) `templates_ready` subscription lifecycle note added to Rule 22 — explicitly documents that this subscription requires no disconnect (re-receipt is harmless), distinguishing it from the `path_invalidated` subscription which must disconnect on gate release. Document promoted to APPROVED.
Prior verdict resolved: Yes — all 9 review-#9 blockers confirmed resolved; 0 new blockers surfaced.

---

## Review — 2026-05-21 (ninth review) — Verdict: NEEDS REVISION → REVISED (same session)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, level-designer, qa-lead, performance-analyst, creative-director (full mode)
Blocking items: 9 | Recommended: 9
Summary: Fresh full specialist re-review confirmed all 6 review-#8 blockers resolved and surfaced 9 new targeted blockers plus 9 recommended items across 6 domains. Key fixes: (1) Rule 2 updated to enumerate both direct Autoload calls — PathfindingSystem.is_rebuild_pending() was silently violating Rule 2's stated invariant; (2) path_invalidated subscription added to Interactions table — was specified in Rule 22 but absent from the programmer's subscription manifest; (3) Rule 22 wave-index gate selection specified — spawn coroutine must use _wave_index==1 to select templates_ready gate vs. _rebuild_pending_gate, previously undocumented; (4) templates_ready handler declared unconditional (no phase guard) — same-frame concurrent Ready + templates_ready could deadlock the spawn coroutine; (5) path_invalidated subscription disconnect lifecycle added — repeated INTERMISSION→PRE_WAVE transitions with rebuild pending accumulated handler connections; (6) AC-19b hardened with three new checks: wave_scripts.size()<=8 cap (a 9-wave config with r=0.25 breaks base_quality probability ceiling), BOSS-at-non-last negative check for all waves (EC-10's DEBUG-only assert is release-build gap), rolling-window anti-burst check replacing consecutive-zero heuristic (easily bypassed by 0.0/0.05 alternating pattern); (7) F2 type note added — wave_countdown_warning.seconds_remaining is int; F2 applies only to phase_timer_tick; (8) AC-20 expanded to all 8 reset fields and timer-cancellation sub-case; (9) AC-35–AC-40 added for EC-7 modulo wrap, EC-11 empty spawn cells, Rule 18 count<=0 and outside-WAVE_ACTIVE guards, run_modifier_selected phase guard, and SM-07 same-frame race. CD rulings applied: hero_died DEFEAT non-negotiable (design intent noted in Rule 14); WAVE_SCOUT_MIN_DURATION added to Tuning Knobs (default 0); INTERMISSION playtest validation criterion added; BOSS breach mandatory acknowledgment rejected (lives in HUD GDD); 5-wave vs 8-wave economy dominance escalated to Resource Economy GDD; WAVE_ACTIVE observability escalated to HUD GDD.
Prior verdict resolved: Yes — all 6 review-#8 blockers confirmed resolved; 9 new blockers surfaced; all resolved in-session.

---

## Review — 2026-05-21 (eighth review) — Verdict: NEEDS REVISION → REVISED (same session)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, level-designer, qa-lead, creative-director (full mode)
Blocking items: 6 | Recommended: 7
Summary: Full specialist re-review confirmed all 7 review-#7 blockers resolved and surfaced 6 new structural issues plus 7 recommended items. Key fixes: (1) Rule 18 `monster_spawned` phase guard — stray deferred Monster instantiations arriving in INTERMISSION could corrupt `_enemies_alive` for the next wave; gated to WAVE_ACTIVE only with discard-and-warn; (2) Rule 18 `monsters_died_batch` negative-count precondition — `count >= 1` added to prevent malformed batch events from incrementing `_enemies_alive`; (3) Rule 22 `_rebuild_pending_gate` lifecycle — explicit set/clear/early-fire documentation added (flag was referenced in three places but never specified when it was written); (4) Rule 22 coroutine phase-check guard — every await boundary (templates_ready, path_invalidated) must verify `phase == WAVE_ACTIVE` before proceeding to prevent post-phase-change spawn emission; (5) F1 `base_quality` global constant ambiguity — a value safe for r=0.20 (e.g., 25%) overflows to 119.2% probability at r=0.25; constraint rewritten as single global ceiling ≤20.97% (1/4.768) across all authored WaveConfigs; (6) entities.yaml YAML corruption — duplicate top-level `constants:` key introduced during review-#7 post-processing silently destroyed 10 existing constants; removed duplicate key. Bonus: wave 1 was entirely unpreviewed (CB-6) — `wave_preview_available` emitted on SCOUT entry per Rule 8.
Prior verdict resolved: Yes — all 7 review-#7 blockers confirmed resolved; 6 new blockers surfaced; all resolved in-session.

---

## Review — 2026-05-21 (seventh review) — Verdict: MAJOR REVISION NEEDED → REVISED (same session)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, level-designer, performance-analyst, creative-director (full mode; qa-lead session-limited, findings carried forward from main review)
Blocking items: 7 | Recommended: 0
Summary: Seventh full specialist pass confirmed all 5 review-#6 blockers resolved and surfaced 7 new structural issues. Key fixes: (1) EC-9 reset list was incomplete — `_templates_ready` and `_rebuild_pending_gate` were not reset on mission restart, creating a `templates_ready` re-fire race on second-mission loads; AC-20 updated with full field list; (2) AC-33 added for waves 2+ `is_rebuild_pending()` gate — no test existed for the INTERMISSION→PRE_WAVE hold-and-release path; (3) Rule 3 `wave_time_budget` rationale was wrong — described the two timers as competing, but they are sequential: max WAVE_ACTIVE = `wave_time_budget` + `wave_stuck_timeout` + traversal; (4) `_wave_clear_fired: bool` one-shot latch introduced across Rules 20/21c/23 and EC-5b to prevent `boss_died(cause:"force_removed")` from Monster System cleanup re-entering Rule 20 while phase transition is in-flight in the same frame; AC-34 added to test single-emit invariant; (5) `is_penultimate_wave` formula missing sub-5-wave guard — for 2-wave missions `wave_scripts.size()-1==1==_wave_index` on wave 1 triggers ELITE amplifier incorrectly; Rule 15c and AC-19b both updated; (6) Tuning Notes "2.2× total economy" was quantity-only sum; correct combined figure (quantity × quality both scale by `wave_reward_scalar`) is 3.37×; `WAVE_ERI_CEILING_COMBINED = 22.73` registered in `design/registry/entities.yaml`; (7) Player Fantasy "re-engage the threat / second chance" copy contradicted the BOSS-immediate-despawn mechanic — rewritten as consequence beat with `was_boss_breached: true` flag framing.
Prior verdict resolved: Yes — all 5 blockers from review #6 confirmed resolved; 7 new blockers surfaced; all resolved in-session.

---

## Review — 2026-05-20 (sixth review) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, level-designer, qa-lead, creative-director (full mode)
Blocking items: 5 | Recommended: 4
Summary: Document was revised post review #5 with all 8 blockers resolved. Full specialist review surfaced 5 new blockers across 4 distinct clusters: (1) Visual/Audio table had two BOSS breach signals with no spec for which drives which HUD feedback moment — split into immediate (monster_breached) and end-of-wave (wave_completed.was_boss_breached) rows; (2) stray boss_died in INTERMISSION had no guard equivalent to EC-5's monster_died guard — EC-5b added with AC-32; (3) spawn coroutine cancellation synchrony was unspecified — synchronous cancellation guarantee added to EC-3; (4) AC-19b validator missing non-BOSS precondition check (BOSS-only final wave passed CI) and CI exit code undefined — both tightened; (5) combined ERI ceiling (22.73×) unanchored — MAX_COMBINED_ERI forward contract added to F1. Recommended items: AC-8 ordering clause made code-review-only, base_quality wave-1 definition added, wave count ERI disparity documented, mocked timer and mock mechanism fixture notes added. All 5 blockers and 4 recommended items resolved in-session.
Prior verdict resolved: Yes — all 5 blockers resolved in-session.

## Revision — 2026-05-20 — 5 blockers resolved (post review #6)

| Blocker | Fix |
|---------|-----|
| B1 Visual/Audio BOSS breach signal ambiguity | Split table row: monster_breached drives immediate moment, wave_completed.was_boss_breached drives end-of-wave banner |
| B2 Stray boss_died no INTERMISSION guard | EC-5b added (state-equality check, no-op outside WAVE_ACTIVE) + AC-32 unit test |
| B3 EC-3 synchronous cancellation unspecified | Synchronous cancellation guarantee added to EC-3: cancellation is same-frame, before wave_completed emission |
| B4 AC-19b two gaps | Non-BOSS precondition added (entries.size >= 2, no BOSS at [0..N-2]); CI exit code specified (0=pass, non-zero=fail, step: wave-config-validator) |
| B5 Combined ERI ceiling unanchored | F1 forward contract added: MAX_COMBINED_ERI TBD constant, 22.73× ceiling at max settings documented |

---

## Review — 2026-05-20 (fifth review) — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, level-designer, qa-lead, creative-director (full mode)
Blocking items: 8 | Recommended: 7
Summary: Document was revised post review #4 with all 12 blockers resolved, but the B7 fix (is_penultimate_wave payload) was not propagated to three canonical downstream documents. Fresh full-specialist review surfaced 8 blockers across 4 distinct clusters: (1) stale "5-field payload" bidirectionality closure in wave-manager.md and stale references in entities.yaml, game-concept.md formula section, and monster.md AC-26; (2) Tuning Knobs `pre_wave_countdown` row directly contradicted Rule 10 ("cannot skip" vs. skippable via Ready); (3) PRE_WAVE Ready-skip has zero cost, making it a dominant strategy that eliminates the dread countdown — design decision required; (4) BOSS breach wave_completed payload identical to clean clear — "legible failure" fantasy beat has no mechanical expression; (5) is_penultimate_wave fires for <5-wave missions with no runtime guard; (6) Rule 22 (templates_ready gate) had zero AC coverage across all 5 reviews — AC-31 added. Design decisions resolved: DQ-3 — PRE_WAVE skip kept; Player Fantasy revised to reframe 10s countdown as skippable buffer (not mandatory dread clock); DQ-4 — was_boss_breached: bool added to wave_completed payload for all 3 clear paths. All 8 blockers resolved in-session.
Prior verdict resolved: Yes — all 8 blockers resolved in-session.

## Revision — 2026-05-20 — 8 blockers resolved (post review #5)

Design decisions applied: DQ-3 (PRE_WAVE skip retained; Player Fantasy rewritten to frame countdown as commander's choice, not mandatory enforced beat), DQ-4 (was_boss_breached: bool added to wave_completed payload).

| Blocker | Fix |
|---------|-----|
| B1 Stale "5-field" bidirectionality note | Updated to "6-field payload", all fields listed, EventBus GDD update flagged, was_boss_breached propagation noted |
| B2 B7 fix not propagated to 3 canonical docs | game-concept.md Formulas: "Sub-boss wave (wave 4) 1.5×" → penultimate note + correct output range; entities.yaml r range 0.10–0.30 → 0.10–0.25; entities.yaml renamed elite_wave4_hp_amplifier → elite_penultimate_wave_hp_amplifier with is_penultimate_wave semantics; monster.md AC-26 fixture updated |
| B3 Tuning Knobs contradiction | pre_wave_countdown row: removed "Always runs to zero (player cannot skip)", replaced with "Skippable via Ready button (Rule 10, EC-8)" |
| B4 PRE_WAVE skip is dominant strategy | Player Fantasy revised: PRE_WAVE window acknowledged as player's choice (commit early vs. take space); clock metaphor shifted to overall mission timeline |
| B5 BOSS breach lacks differentiated signal | was_boss_breached: bool added to wave_completed in Rules 11, 13, 20, 21, 23; Interactions table, UI data contract, and AC-6, AC-15, AC-16, AC-29 updated; AC-30 added (3 path verification) |
| B6 is_penultimate_wave fires for <5-wave missions | Rule 8: runtime warning added when wave_scripts.size() < 5 |
| B7 Rule 22 templates_ready zero AC coverage | AC-31 added: templates_ready gate — no monster_spawn_requested before templates_ready received |
| B8 5 ACs with deficient test specs | AC-5: assertion order added; AC-8: "same _process frame" → direct handler call spec; AC-14: negative-case test specs added; AC-15: bounded observation window + test spec; AC-16: negative assertion test spec |

---

## Review — 2026-05-20 (fourth review) — Verdict: MAJOR REVISION NEEDED
Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, level-designer, qa-lead, creative-director (full mode)
Blocking items: 12 | Recommended: 8
Summary: Document was not revised after the third review (2026-05-19). All 9 prior blockers survive unmodified, plus 3 new blockers surfaced by fresh specialist review. New findings: spawn_cells.size()==0 causes division-by-zero crash in Rule 15b (no guard equivalent to EC-6); three-document contradiction escalated — game-concept.md (wave 4 = sub-boss), Wave Manager Rule 6 (N-1 = ELITE-only), and monster.md F3 (HP amplifier at wave_index==4) now point at different waves for any mission ≠ 5 waves (balance bug, not doc cleanup); all-zero pre_delay waves are legal and produce 30 spawn requests in one frame; ELITE tier resolver not specified in AC-19b validator (cannot be implemented without it); BOSS breach and force-remove drop resolution both unspecified (competing economy incentives). Three design decisions captured: DQ-1 — Player Fantasy scoped to successful clears only, BOSS breach acknowledged as legible failure beat (rewrite Player Fantasy section); DQ-2 — PRE_WAVE made skippable via Ready button; DQ-3 — Scout phase starting economy deferred to Resource Economy GDD (TODO note). QA lead confirmed all 9 prior AC blockers still present plus added AC-29 (missing) and identified 12 advisory AC rewrites. Creative-director verdict: "No further review should be scheduled until the document has actually been revised." Revision blocked on this log entry — carry all 12 blockers and 3 design decisions into the next session.
Prior verdict resolved: No — document not revised; 3 new blockers added to prior 9.

`design/gdd/wave-manager.md`

---

## Revision — 2026-05-20 — 12 blockers resolved (post review #4)

Design decisions applied: DQ-1 (Player Fantasy rewritten — BOSS breach scoped as legible failure, "I read it correctly" scoped to successful clears), DQ-2 (PRE_WAVE now skippable via Ready button), DQ-3 (Scout economy deferred to Resource Economy GDD with TODO note).

| Blocker | Fix |
|---------|-----|
| B1 Header false approval status | Updated to "Revised (review #4)" |
| B2 r validation 0.10–0.30 → 0.10–0.25 | F1 runtime validation + Tuning Knobs hard cap corrected |
| B3 Four stale "20s" intermission refs | States table, EC-1, AC-21, Visual/Audio all → 30s |
| B4 Bidirectionality note contradicts Rule 22 | Note rewritten: phase ordering NOT sufficient, templates_ready required |
| B5 spawn_cells.size()==0 division-by-zero | EC-11 added with zero-spawn guard (mirror of EC-6 pattern) |
| B6 AC-19b ELITE tier resolver unspecified | Tier resolver spec added: read MonsterResource.tier by id field match |
| B7 Three-document contradiction (wave 4 vs N-1) | game-concept.md Rule 3 updated; monster.md F4 changed from wave_index==4 to is_penultimate_wave bool; wave-manager.md Rule 15c adds is_penultimate_wave to spawn payload |
| B8 All-zero pre_delay unguarded | Tuning Knobs anti-pattern warning + CI validator flag added to AC-19b |
| B9 BOSS breach drop resolution | OQ-6 added — recommends no drops on breach; defers to Monster System GDD |
| B10 Force-remove drops unspecified | OQ-6 covers — recommends no drops on force-clear; defers to Monster System GDD |
| B11 Base quality constraint in wrong doc | Constraint reframed as TODO for Resource Economy GDD; shared-constant approach noted |
| B12 9 untestable ACs + missing AC-29 | AC-4, 5, 6, 7, 8, 12, 18, 19b, 21, 22 rewritten with concrete fixtures, mocked timers, bounded observation windows. AC-29 added (boss_died fast-path → wave_preview_available). |

---

## Review — 2026-05-19 (third review) — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, level-designer, qa-lead, creative-director (full mode)
Blocking items: 9 (must-fix before implementation) | Recommended: ~10 (open, not blocking)
Summary: Prior APPROVED verdict (2026-05-14 lean) revoked. Full specialist review surfaced contract-level errors missed by lean review. Most critical: F1 output ceiling stated as 4.768× but runtime validates r up to 0.30 producing 6.275× — quality probability would overflow 100% if Resource Economy anchors to the stated ceiling; resolved by declaring r hard-clamped at 0.25. Dual-dimension compounding (scalar×both quantity and quality = ERI of 22.73× at max settings) confirmed intentional by user decision. Cross-document contradiction: game-concept Rule 3 ("wave 4 = sub-boss, absolute") vs Wave Manager Rule 6 ("wave N-1 = ELITE-only, relative") — resolved: Wave Manager wins, game-concept Rule 3 updated to wave N-1. Bidirectionality note in Dependencies still says phase-ordering is sufficient; Rule 22 says opposite — note must be corrected. Five stale "20s" references remain (States table, Visual/Audio table, EC-1, AC-21, AC-22) despite 2026-05-14 review claiming to fix them. QA lead found 9 untestable ACs (AC-5 wildcard fixture, AC-6 unbounded silence, AC-7 single-phase claim, AC-12 cross-system assert, AC-18 no mocked timer, AC-19b tooling story in wrong doc, AC-22 no mocked timer, AC-8 signal ordering nondeterministic, missing AC-29 for boss_died fast-path preview). BOSS breach = BOSS kill declared intentional MVP simplification. Design decisions resolved: r hard-capped at 0.25, dual-dimension scalar intentional, sub-boss at N-1 (Wave Manager wins). Revision to be done in a fresh session.
Prior verdict resolved: No — 9 new blockers surfaced; prior APPROVED (lean, 2026-05-14) revoked.

---

## Review — 2026-05-14 (re-review pass) — Verdict: NEEDS REVISION → APPROVED (in-session)
Scope signal: L
Specialists: None (lean mode)
Blocking items: 2 (both resolved in-session) | Recommended: 4 (all resolved in-session)
Summary: Re-review confirmed all 8 first-review blockers resolved in the 2026-04-26 revision. Two new blockers found and resolved in-session: B1 — Rule 22 and four dependent locations (Interactions table ×2, Dependencies, EC-2) incorrectly claimed Pathfinding templates build synchronously during the SCOUT transition; the Pathfinding GDD (approved 2026-05-14) requires Wave Manager to subscribe to `templates_ready` and gate first `monster_spawn_requested` on its receipt — all five locations updated. B2 — `intermission_duration` default/range was 20s/10–30s, conflicting with game-concept Rule 7 (25–40s) and Tower GDD tuning knobs (25–40s, canonicalized 2026-05-01); updated to 30s default / 25–40s range throughout (6 locations). Four recommended items applied: R1 — D&S added as `wave_completed` subscriber in downstream Dependencies table (closes D&S pass-6 cross-GDD follow-up); R2 — AC-7, AC-11, AC-13 rewritten as observable-output ACs; R3 — force-clear `wave_completed` payload clarified (`enemies_remaining` = stuck count, not 0); R4 — stale "EventBus update required" bidirectionality note updated to confirmed status.
Prior verdict resolved: Yes — all 8 blockers from first review confirmed resolved; 2 new blockers and 4 recommended items resolved in-session.

---

## Review — 2026-04-26 — Verdict: NEEDS REVISION → REVISED (same session)

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, economy-designer, level-designer, creative-director
Blocking items: 8 | Recommended: 6
Summary: The GDD had sound structural foundations (7-state lifecycle, WaveConfig schema) but carried 8 blocking issues: `wave_difficulty_scalar` semantic ambiguity (it multiplied both drop quantity and drop quality — renamed `wave_reward_scalar` with explicit dual-dimension contract); the Wave 4 ELITE pacing rule was position-absolute rather than position-relative (fixed to penultimate wave N−1); `_round_robin_counter` reset scope was unspecified (confirmed wave-scoped, Rule 10f added); the "forewarning, not surprise" Player Fantasy was undelivered (fixed by adding `wave_preview_available` event at INTERMISSION entry); no HUD hook existed for stuck-wave feedback (fixed by adding `wave_stalled` at 30s before the 60s force-clear watchdog); OQ-1 (`monsters_died_batch` subscription) was unresolved (Rule 18 and AC-28 added); no `wave_time_budget` field guarded against content-authoring overruns (added to WaveConfig schema); and no CI validator mandate existed for WaveConfig integrity (AC-19b added). All 8 blockers resolved in-session. Document revised: 22 rules expanded with 6 new/rewritten rules, ACs 1–28 (was 20), entities.yaml entries renamed, EventBus catalogue updated (+2 events: `wave_preview_available`, `wave_stalled`; +1 subscription: `monsters_died_batch`).
Prior verdict resolved: N/A — First review; all revisions applied same session.

### Blocking Items Resolved

| # | Item | Resolution |
|---|------|------------|
| B1 | `wave_difficulty_scalar` semantic ambiguity | Renamed `wave_reward_scalar`; explicit contract: multiplies drop quantity AND drop quality %; entities.yaml updated |
| B2 | Wave 4 ELITE pacing rule position-absolute | Changed to penultimate wave N−1 rule; entities.yaml entry renamed `elite_penultimate_wave_hp_amplifier` |
| B3 | `_round_robin_counter` reset scope unspecified | Wave-scoped reset confirmed; Rule 10f added; AC-10 rewritten with concrete 4-entry fixture |
| B4 | Player Fantasy "forewarning" undelivered | `wave_preview_available(next_wave_number, composition)` added; emitted at INTERMISSION entry; EventBus updated |
| B5 | Stuck-wave silent dead zone (no HUD hook before 60s watchdog) | `wave_stalled(wave_number, enemies_remaining)` added at 30s mark; AC-25 and AC-26 added |
| B6 | OQ-1: `monsters_died_batch` subscription unresolved | Rule 18 expanded: Wave Manager subscribes to both `monster_died` and `monsters_died_batch`; AC-28 added |
| B7 | No `wave_time_budget` field in WaveConfig schema | Field added to WaveConfig table (default 90s); guards against content-authoring pre_delay overruns |
| B8 | No CI validator mandate for WaveConfig integrity | AC-19b added: WaveConfig validator CI tool required |

### Deferred (RECOMMENDED — not blocking)

- ACs 2, 3, 4, 5, 6, 7, 11, 13, 18 reference internal state variables (`_phase_locked`, `_enemies_alive`, etc.) — logically correct but fail observable-output testability standard; flagged for a dedicated AC rewrite pass
- `design/gdd/monster.md` still references `wave_difficulty_scalar` in spawn payload description — to be updated during monster.md review session
