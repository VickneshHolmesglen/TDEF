# Cross-GDD Review Report

**Date**: 2026-07-15 (third `/review-all-gdds` run this session — follow-up to `gdd-cross-review-2026-07-15.md` and `-15b.md`)
**GDDs Reviewed**: 15 (all system GDDs + game-concept.md + game-pillars.md + systems-index.md)
**Trigger**: user asked to re-verify all fixes made since the `-15b` re-run — a batch covering damage-status.md's Dependencies table, save-persistence.md's DEFEAT-save ordering, hero.md's Formula 4/5/6, and tower.md's `damaged_component_repair_cost` → OQ-12 conversion.

No `## Summary` header convention exists in any GDD (consistent with prior runs) — proceeded directly to full parallel reads of all in-scope documents via 3 parallel specialist passes: Consistency, Game Design Holism, Cross-System Scenario Walkthrough.

---

## Consistency Issues

### Blocking (found and fixed same-session)

🔴 **tower.md's Interactions table still described the removed T4 Siege mechanic**
The Monster System row claimed `tower_attacked` carries `is_siege: bool` "so the Monster/Boss System can resolve shield penetration" — directly contradicting the document's own OQ-1 and T4 Boss-Lane Identity section, both already correctly stating Siege was struck. **Fixed.**

🔴 **damage-status.md had 4 more leftover `is_siege` references**
Interactions table's Tower System row, plus AC-1/AC-2/AC-3's GIVEN clauses all still specified `is_siege=false` — testing a field event-bus.md's `tower_attacked` no longer carries. An earlier same-day pass caught one occurrence (Dependencies table) but missed these four. **Fixed.**

🔴 **hero.md's AC-06 wasn't updated when Formula 6 was rewritten**
AC-06 still used the exact stale pre-overkill-cap lifesteal basis (`hp_recovered = min(270 × 0.20, 50) = 50`) that Formula 6's own revision note calls out as the bug being fixed. The old numbers coincidentally landed at the overheal clamp ceiling, masking the error. **Fixed** — AC-06 now uses a worked overkill example matching Formula 6's corrected `absorbed` basis.

🔴 **hero.md's Tuning Knobs table and AC-05 had 2 more rename/guard leftovers**
Tuning Knobs still said `effective_lifesteal` instead of the renamed `hero_lifesteal_fraction`/`hero_lifesteal_cap`; AC-05 was missing the `max(1, floor(...))` guard added to Formula 5. **Both fixed.**

### Registry Corrections (found and fixed same-session)

- `hero_armor_coefficient`'s formula text was missing the `max(1, floor(...))` guard both hero.md Formula 5 and damage-status.md Rule V actually implement. **Fixed.**
- `hero_damage_bonus_multiplier`'s `referenced_by` list was missing `hero.md`, despite hero.md's Formula 4 now explicitly citing this exact constant by name (renamed from its own former `elite_boss_multiplier`). **Fixed.**

### Warnings

⚠️ None outstanding — all consistency findings from this pass were blocking-tier and fixed same-session.

---

## Game Design Issues

### Blocking (found and tracked, not unilaterally redesigned)

🔴 **hero.md's Tower Affinity bonus rewards raw tower count, undermining Tower System's own cost-efficiency curve**
Formula 2 scales Hero Damage/Skill Power off `sqrt(qualifying_towers / 16)` with no cost or DPS weighting. tower.md deliberately makes T1/T2 cost-inefficient "budget-gating" tiers with "no mechanical niche" versus T3. Because Tower Affinity only counts bodies, the mechanically rational strategy is T1-spam for Affinity — directly against Tower System's own efficiency design and against Pillar 2's stated anti-pattern. **Not redesigned this session** — a formula change is a balance decision needing real playtest data this project doesn't have yet. **Added as hero.md OQ-9**, deferred to the same first-balance-calibration milestone already used for hero base stats.

### Warnings (not acted on — genuine design judgment calls, flagged for the user)

⚠️ **T4 tower tier is coherent but narrow** — not dominant, not a trap (confirmed via the doc's own math), but its only real payoff window is the fully-forecastable final BOSS wave, and it's arguably just accelerating a kill the Hero is already structurally required to finish (game-concept.md Core Rule 1's 150% hero boss multiplier). No GDD frames T4 as "reduces boss-phase risk" rather than "solves what towers alone can't" — worth an explicit framing pass, not a mechanical change.

⚠️ **T1/T2's "no mechanical niche" is a self-aware but undocumented Pillar 2 anti-pattern instantiation** — tower.md states this outright as intentional budget-gating; game-pillars.md's anti-pattern list names exactly this shape of design ("options without meaningful decisions") without either doc reconciling the two.

⚠️ **Material economy has one sink (Inventory slot expansion) against 3 sources** — expected and non-blocking at current design maturity (Crafting/Menagerie/Defense Building/Equipment Forge are all Not Started, and are the systems that would consume materials), but the economy is structurally unvalidatable until at least one exists. Flag as a Vertical Slice gate item, not a current defect.

⚠️ **"Wave Difficulty Scaling" in game-concept.md mislabeled an economy-only formula as combat difficulty** — `wave_reward_scalar` (exponential, drives Resource Economy) was presented as "difficulty," while actual combat threat uses a separate, deliberately linear formula (monster.md Formula 1) that explicitly rejects exponential scaling. The registry renamed the underlying constant on 2026-04-26 for exactly this clarity reason; game-concept.md had never caught up. **Fixed this session** (cheap terminology/cross-reference correction, no formula behavior change) — renamed to "Wave Reward Scalar" throughout, cross-referenced to monster.md's real difficulty formula.

### Economic Loop Summary

| Resource | Sources | Sinks | Risk |
|---|---|---|---|
| Materials | Monster drops (scaled by `wave_reward_scalar` × Menagerie bonus), Menagerie-lure rare drop | Inventory slot expansion only | ⚠️ Source-heavy, sink-light — expected pre-Vertical-Slice |
| Gold | Scout starting grant (150) + per-wave completion grant (20–95) | Tower placement (partial 40% sell-refund recapture) | Low risk — resets every mission, self-bounded, verified against persistence exploits |

### Attention Budget Summary

During `WAVE_ACTIVE`: Hero movement/positioning, auto-attack targeting (implicit), 4 active skill slots + Ultimate, reactive monitoring (breach counter, boss HP bar, tower-destroyed banner). **Within the ≤4 budget** — the design deliberately narrows player attention to the Hero during combat, deferring composition decisions to SCOUT/INTERMISSION. A design strength worth preserving as Tarot/Tower Mastery are added.

---

## Cross-System Scenario Issues

Scenarios walked: 4 — Boss kills hero + destroys tower (same frame); Hero kill-blow lifesteal racing wave-clear; T4 boss-lane telegraph vs. tower destruction; Resource Economy gold grant racing tower placement debit.

### Blockers (found and fixed same-session)

🔴 **Lifesteal was structurally incapable of healing on a killing blow — not a race condition, a 100%-of-the-time gap**
Traced `damage-status.md`'s Rule VII (stated purpose: "preserve lifesteal heals on the killing blow of a wave") against `monster.md`'s actual mechanics. Root cause: Rule 21f explicitly erased the entity's `_pending_absorbed` entry and suppressed `monster_hp_absorbed` on any lethal hit (confirmed by monster.md's own AC-36 asserting this as correct behavior). Since D&S's lifesteal resolution is entirely gated on receiving `monster_hp_absorbed`, lifesteal could never heal the hero on a kill, deterministically — a design-intent contradiction between two GDDs that had existed since Rule VII was authored, undetected by any single-document review. **Fixed** in `monster.md`: Rule 21f no longer erases the entry; it flushes normally in the same end-of-frame absorbed-flush pass as any hit. Traced the corrected timing through Monster System's 4-pass `_physics_process` structure and confirmed no residual race: the killing blow's `monster_hp_absorbed` now reliably resolves within the same physics frame as `wave_completed`, before Rule VII's deferred clear resumes on the next frame. AC-36 corrected to match; damage-status.md's Rule VII annotated with the confirmation.

### Warnings

⚠️ **Scenario 1 (DEFEAT + tower destruction) — Rule 9's fix holds, but is fragile to future changes.** Confirmed both cascades (DEFEAT trigger, Tower→Inventory component-return) are fully synchronous today, so save-persistence.md's 1-frame defer correctly covers them. If a future revision adds a deferred hop to the Inventory cascade (e.g., batching `item_added`), the single-frame defer would under-cover it the same way monster.md's old Rule 21f under-covered lifesteal. Not a current defect — a fragility note for future changes to watch.

### Info

ℹ️ **T4 boss-lane telegraph vs. tower destruction** — no contradiction found; Mission HUD's confirming pulse clears well before a boss's first attack could destroy the tower.

ℹ️ **Resource Economy gold grant vs. tower placement debit** — no race found; Tower reads gold via a direct `MissionEconomy.can_afford()` call at placement time, not a cached snapshot.

---

## GDDs Flagged for Revision (this pass)

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| tower.md | Leftover Siege reference in Interactions table | Consistency | Blocking — fixed |
| damage-status.md | 4 leftover `is_siege` references; Rule VII's purpose was structurally unachievable | Consistency + Scenario | Blocking — fixed |
| hero.md | AC-06/Tuning Knobs/AC-05 not updated with Formula 4/5/6 fixes; Tower Affinity design tension | Consistency + Design Theory | Blocking — fixed / OQ-9 tracked |
| monster.md | Rule 21f suppressed `monster_hp_absorbed` on lethal hits, breaking lifesteal-on-kill | Scenario | Blocking — fixed |
| game-concept.md | "Wave Difficulty Scaling" mislabeled an economy formula as combat difficulty | Design Theory | Warning — fixed |
| entities.yaml | `hero_armor_coefficient` formula stale; `hero_damage_bonus_multiplier.referenced_by` incomplete | Registry | Non-blocking — fixed |

---

## Verdict: CONCERNS

No blocking issues remain unresolved as of this report — every 🔴 finding from this pass was fixed same-session. **CONCERNS** rather than **PASS** because:
1. Two genuine, unresolved design-judgment items remain deliberately un-acted-on: hero.md's new OQ-9 (Tower Affinity vs. Tower efficiency) and the T4/T1-T2 pillar-tension warnings — both need a human design call, not another documentation pass.
2. No GDD in this batch was flipped to Approved — all remain formally Needs Revision pending a fresh-session re-review, per this project's own established convention.
3. The material-economy sink gap (only 1 sink, 3 sources) is real but expected at current design maturity — flagged as a Vertical Slice gate item, not resolved.

This is the third consecutive `/review-all-gdds` pass this session to find genuine, previously-undetected defects (propagation debt → T4 Siege/repair-cost gaps → this pass's leftover-reference and lifesteal-on-kill bugs). The pattern suggests diminishing but non-zero returns from continued re-verification — a 4th pass is reasonable if more fixes land, but the remaining open items are now design decisions, not more hidden bugs to hunt.
