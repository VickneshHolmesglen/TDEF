---
name: Hero System Acceptance Criteria
description: AC status and open issues for the Hero System GDD (AC-HERO-01 through AC-HERO-21)
type: project
---

21 acceptance criteria written for Hero System GDD (design/gdd/hero.md) on 2026-04-21.

All are Logic-type (BLOCKING) except AC-HERO-13, which is Integration-type (requires two simulated mission cycles for cross-mission proximity accumulation).

No performance or visual criteria — Visual/Audio section deferred to Polish phase per GDD.

**Why:** QA Lead authored criteria from the completed GDD sections (stats, formulas, edge cases). Criteria are self-contained Given-When-Then statements, tester-readable without the GDD.

**How to apply:** When the Hero System implementation begins, these criteria define the unit test targets in `tests/unit/hero/`. AC-HERO-13 belongs in `tests/integration/hero/`.

## Open Issues Flagged

1. `hero_class_unlocked` event is missing from `design/gdd/event-bus.md`. AC-HERO-13 is blocked until this event is added to the EventBus catalogue.
2. Auto-attack tie-break sub-case (AC-HERO-05: same path progress, same HP) depends on internal enemy list ordering — not yet specified in Monster System GDD (not authored). AC-HERO-05 is partially untestable until Monster System defines this.
3. Crit chance cap conflict: Rule 5 in GDD body says hard cap is 80%; tuning knob safe range extends to 90%. The cap should be a named constant (CRIT_CHANCE_CAP) and AC-HERO-08 should test against the constant, not a literal value.
