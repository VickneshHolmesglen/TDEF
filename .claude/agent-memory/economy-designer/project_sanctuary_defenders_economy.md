---
name: Sanctuary Defenders Economy Context
description: Tower economy design state — build-point budget, placement cost formula, resource flow, provisional values as of 2026-04-30
type: project
---

Tower System GDD defines Formula 4 (placement cost): `round(base_cost × archetype_cost_factor × tier_cost_factor)`.
Provisional budget: 350–400 build points per mission, targeting 10 towers at avg cost 30.
Tier cost factors: {1.0, 1.5, 2.0, 4.0} (T4 updated to 4.0 in Review 7 — previous value of 3.0 was economically incoherent).
Tier DPS multipliers: {1.0, 1.6, 2.4, 4.0}.
DPS/cost ratios: T1=1.00, T2=1.067, T3=1.20, T4=1.00. Non-monotone curve is intentional per GDD — T3 is the efficient mid-game tier; T4 is specialist ceiling for boss lanes.
HP/cost ratios: T1=1.00, T2=1.00, T3=1.00, T4=0.625. T4 is worst HP/cost.
No refund on removal. Support archetype cost parity at MVP (all archetypes = 1.0).
`damaged_component_repair_cost`: round(base_cost × tier_cost_factor × 0.5) per component. T1=10, T4=40. Full T4 tower destroy = 4 components × 40 = 160 repair cost.
Resource Economy GDD not yet written (Vertical Slice tier). No per-wave earning rate defined.
Max theoretical DPS: 120 × 4.0 × 4.0 = 1920 per tower (T4).
Post-MVP archetype_cost_factor ceiling rises formula max to round(60 × 2.0 × 4.0) = 480.

**Why:** Economy review commissioned 2026-04-30 to find balance issues before Tower GDD re-review.
**How to apply:** When the Resource Economy GDD is designed, cross-reference these provisional values and the DPS efficiency ratio problem before locking cost curves.
