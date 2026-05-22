# Hero System GDD — Review Log

---

## Review — 2026-05-14 (pass 1) — Verdict: NEEDS REVISION → APPROVED (in-session)
Scope signal: L
Specialists: None (lean mode)
Blocking items: 2 (both resolved in-session) | Recommended: 3
Summary: First review pass. Two blockers resolved in-session: B1 — Rule 6 `HeroAutoAttackEvent` payload still referenced deprecated `hero_damage_bonus_eligible: bool` (replaced by `hero_bonus_tier: int` in D&S, Monster, and entities.yaml during earlier review sessions); Rule 6(b) and 6(d) updated to `hero_bonus_tier: int` (0=STANDARD, 1=ELITE, 2=BOSS). B2 — Rule 20 and Interactions table subscribed to `tower_placed` and `tower_destroyed` but not `tower_removed`, leaving Tower Affinity stale on voluntary player removals during Intermission; `tower_removed` added to Rule 20 trigger list and Interactions subscription row. R1 also applied in-session: Interactions table published events corrected — `hero_auto_attacked` added, `hero_damage_taken` removed (moved to D&S ownership per EventBus catalogue update). B1 resolution closes the D&S pass-6 cross-GDD follow-up: "Hero GDD HeroAutoAttackEvent payload field rename not confirmed in text." Recommended items outstanding: UI Requirements section ("[To be designed]") needs authoring before UX phase; `hero_class_unlocked` needs EventBus catalogue registration (tracked in Hero GDD OQ-4); `hero_health_changed` event ownership should be confirmed in EventBus GDD review.
Prior verdict resolved: N/A — first review
