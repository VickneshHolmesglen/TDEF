# Architecture Review Report

Date: 2026-07-17
Engine: Godot 4.6.2
GDDs Reviewed: 9 in full scope (the systems designed 2026-07-16/17 with zero ADR coverage), cross-referenced against 25 total in `systems-index.md`
ADRs Reviewed: 19 (existence/title-match check only — see Scope Note)
Mode: targeted gap-analysis pass, not a full re-derivation

---

## Scope Note

The last full `/architecture-review` ran 2026-07-13 (`architecture-review-2026-07-13d.md`, `tr-registry.yaml` v6) and fully re-validated all 19 existing ADRs against the GDDs they govern — that baseline is not re-derived here. This pass is scoped to what changed since: nine new GDDs were authored 2026-07-16/17 (Constellation, Crafting, Tarot, Menagerie, Defense Building, Tower Mastery, Mission Select, Hero Skill Build, Equipment Forge) and confirmed via grep to have **zero ADR coverage** — none of the 19 existing ADR titles or bodies reference any of these nine systems by name.

Full Phase 4 (cross-ADR conflict detection) and Phase 5 (engine compatibility audit) were **not re-run** this pass, since no ADR content changed since the 2026-07-13 baseline — only new, uncovered GDDs were added. Re-run those phases in full once the first ADR for any of these nine systems is drafted, since a new ADR is exactly the kind of change that phase exists to catch.

---

### Traceability Summary

Total requirements extracted this pass (9 new systems only, coarse granularity per registry convention): **27**
✅ Covered: 0
⚠️ Partial: 0
❌ Gaps: 27

(Pre-existing 90 TR-IDs from `tr-registry.yaml` v6, covering the other 16 systems, are unchanged and not re-counted here — see the 2026-07-13d report for that baseline.)

### Coverage Gaps (no ADR exists)

**Constellation System** (`design/gdd/constellation.md`)
- ❌ TR-const-001: Localized Chebyshev-radius (radius=3) pattern-detection algorithm, triggered per `tower_placed`/`tower_removed`/`tower_destroyed` — must stay O(local neighborhood), not O(total tower count), to keep per-event cost independent of board size.
  Suggested ADR: `/architecture-decision Constellation pattern-detection data structure` · Domain: Data structures/Performance · Engine Risk: LOW
- ❌ TR-const-002: Discovery Ledger persistence (`restore_order=24`, assigned 2026-07-17) — first-discovered timestamps per `pattern_id`, survives save/load.
  Suggested ADR: `/architecture-decision Constellation save-data schema` · Domain: State persistence · Engine Risk: LOW
- ❌ TR-const-003: `constellation_eligibility_tag` now flows through `tower_placed`/`tower_removed`/`tower_destroyed` (added to `event-bus.md` 2026-07-17) — Constellation's subscriber-side read path and eligibility-check flow needs an owning ADR, not just the payload field.
  Suggested ADR: covered by the pattern-detection ADR above · Domain: Cross-system communication · Engine Risk: LOW

**Crafting System** (`design/gdd/crafting.md`)
- ❌ TR-craft-001: `RecipeResource` data schema and `GameDataRegistry` lookup — should extend ADR-0009's existing Resource-subclass convention, not invent a new one.
  Suggested ADR: `/architecture-decision Crafting recipe data model` · Domain: Data structures · Engine Risk: LOW
- ❌ TR-craft-002: Dual-gate discovery trigger architecture (`tech_unlocked` AND `item_added`, both required, fires `recipe_discovered` once permanently) — needs a defined trigger/state-tracking mechanism (Rule 4 names two triggers; a third initialization-time sweep is still an open implementability gap per this session's earlier review).
  Suggested ADR: `/architecture-decision Crafting discovery state machine` · Domain: Cross-system communication · Engine Risk: LOW
- ❌ TR-craft-003: Inventory API-boundary additions this system requires (`has_room_for()`, `clear_damaged_flag()`, `has_items()` promoted from placeholder — all now specified in `inventory.md` as of 2026-07-17, but not yet backed by an ADR on either side of the boundary) plus the `component_repaired` event (now catalogued in `event-bus.md`, Crafting-owned, Inventory-subscribed).
  Suggested ADR: `/architecture-decision Inventory cross-system query/mutation API` (shared with Equipment Forge, see below — one ADR should cover all of Inventory's new API surface) · Domain: Integration contract · Engine Risk: LOW

**Tarot System** (`design/gdd/tarot.md`)
- ❌ TR-tarot-001: Modifier aggregation architecture — 4 registered `modifier_type`s, each MULTIPLICATIVE or REPLACE, aggregated per Formula F2/F3 before `mission_modifier_applied` emission at SCOUT entry.
  Suggested ADR: `/architecture-decision Tarot modifier aggregation pipeline` · Domain: Cross-system communication · Engine Risk: LOW
- ❌ TR-tarot-002: 5-tier mastery progression persistence (`restore_order=22`) and the `mastery_tier_scalar` lookup (Formula F6).
  Suggested ADR: `/architecture-decision Tarot save-data schema` · Domain: State persistence · Engine Risk: LOW
- ❌ TR-tarot-003: Rune discovery layer data model (`tarot_rune_discovered`, additive `rune_bonus_flat` stacking clamped `[0.00, 0.30]`).
  Suggested ADR: covered by the modifier aggregation ADR above · Domain: Data structures · Engine Risk: LOW

**Menagerie System** (`design/gdd/menagerie.md`)
- ❌ TR-menag-001: 3-state creature lifecycle (`RESERVE`/`HABITAT`/`BREEDING_PEN`, terminal `SACRIFICED`) — state-ownership and transition-validation architecture (Rule 13's sacrifice validation now has a confirmed cross-system signature, `request_sacrifice(creature_id, target_item_id)`, as of 2026-07-17).
  Suggested ADR: `/architecture-decision Menagerie creature lifecycle state machine` · Domain: Data structures/State management · Engine Risk: LOW
- ❌ TR-menag-002: Happiness decay/tend formulas ticking on `mission_launched` (not wall-clock) — timing architecture that must not drift into a `_process()`-based or wall-clock-based implementation by accident.
  Suggested ADR: covered by the lifecycle ADR above · Domain: Timing/Cross-system communication · Engine Risk: LOW
- ❌ TR-menag-003: Save persistence for creature instances + aggregate `menagerie_quality_bonus` (`restore_order=20`).
  Suggested ADR: `/architecture-decision Menagerie save-data schema` · Domain: State persistence · Engine Risk: LOW

**Defense Building System** (`design/gdd/defense-building.md`)
- ❌ TR-defbuild-001: 5-node tech tree data schema (2 categories, `production_tech`/`structural_tech`) and unlock-gating logic.
  Suggested ADR: `/architecture-decision Defense Building tech tree data model` · Domain: Data structures · Engine Risk: LOW
- ❌ TR-defbuild-002: `sanctuary_structure_built` contract for Habitat Expansion's 3-tier structure (independently verified 2026-07-17 to match `menagerie.md`'s expected contract exactly — the contract itself is solid, only the ADR backing it is missing).
  Suggested ADR: covered by the tech tree ADR above · Domain: Cross-system communication · Engine Risk: LOW
- ❌ TR-defbuild-003: Persistence for unlock-tree state (`restore_order=21`).
  Suggested ADR: `/architecture-decision Defense Building save-data schema` · Domain: State persistence · Engine Risk: LOW

**Tower Mastery System** (`design/gdd/tower-mastery.md`) — flagged HIGH RISK in `systems-index.md`'s own risk table
- ❌ TR-towermast-001: Live proximity-detection performance during WAVE_ACTIVE — a per-frame or per-tick Chebyshev-radius check against the hero's position while combat is running. This is the system's own named design risk ("untested in the tower-defense genre... may frustrate rather than engage") and also a genuine performance-architecture question (polling cost against N placed towers every frame).
  Suggested ADR: `/architecture-decision Tower Mastery proximity-detection strategy` · Domain: Performance/Timing · Engine Risk: MEDIUM (needs a prototype per systems-index's own mitigation plan before the ADR can commit to a specific polling strategy)
- ❌ TR-towermast-002: `TowerSystem.get_component_loadout(tower_id)` query API (added to `tower.md` 2026-07-17) — the ADR needs to fix this as a direct Autoload call, consistent with the project's existing narrow-exception precedent (Grid's Rule 8/9, Mission Select's `retry_current_mission()`).
  Suggested ADR: covered by the proximity-detection ADR above · Domain: Integration contract · Engine Risk: LOW
- ❌ TR-towermast-003: `build_signature` cross-mission persistence keying (`restore_order=34`, assigned 2026-07-17) — an accumulator keyed by loadout signature rather than `tower_id` (which resets every mission). **Open ordering question flagged in `save-persistence.md`**: whether Hero Skill Build's restore needs Tower Mastery's state already restored — this ADR should resolve that, not leave it open a second time.
  Suggested ADR: `/architecture-decision Tower Mastery save-data schema` · Domain: State persistence · Engine Risk: LOW

**Mission Select System** (`design/gdd/mission-select.md`)
- ❌ TR-missel-001: `retry_current_mission()` — a deliberate, narrow direct-Autoload-call exception to EventBus-only communication (same precedent class as Grid's Rule 8/9). Needs an ADR to formalize this exception pattern once, rather than each new exception (this is now the third documented instance — Grid, Mission Select, and Mission HUD's new DEFEAT Retry-button call added 2026-07-17) re-justifying itself independently in prose.
  Suggested ADR: `/architecture-decision Direct-Autoload-call exception pattern` (cross-cutting — consider this the first ADR to write from this whole batch, since it retroactively documents a pattern already used 3 times without one) · Domain: Architecture pattern · Engine Risk: LOW
- ❌ TR-missel-002: `GridConfig` same-instance guarantee across a DEFEAT→retry restart (Rule 10/EC-6) — Grid must hand back the *same* `GridConfig` Resource instance, not a re-fetched equivalent one, across `retry_current_mission()`.
  Suggested ADR: `/architecture-decision Mission Select runtime state & retry architecture` · Domain: State management · Engine Risk: LOW
- ❌ TR-missel-003: Save persistence for completion flags/best times (`restore_order=11`).
  Suggested ADR: covered by the runtime-state ADR above · Domain: State persistence · Engine Risk: LOW

**Hero Skill Build System** (`design/gdd/hero-skill-build.md`)
- ❌ TR-heroskill-001: Ultimate-derivation algorithm — 4-skill category-count profile → 19 fixed Ultimate IDs (independently re-derived and confirmed correct 2026-07-17: `C(7,4)=35` raw profiles, fan-in-collapsed to 19). This is a pure lookup-table architecture question, not a runtime-performance one — low engine risk, but worth an ADR since it's this system's entire risk-mitigation strategy per `systems-index.md`'s High-Risk table.
  Suggested ADR: `/architecture-decision Hero Skill Build Ultimate lookup-table architecture` · Domain: Data structures · Engine Risk: LOW
- ❌ TR-heroskill-002: Save persistence for unlocked skills/slot assignment (`restore_order=31`) — **shares the same open ordering question as TR-towermast-003 above**; both ADRs should be written together or cross-reference each other explicitly.
  Suggested ADR: `/architecture-decision Hero Skill Build save-data schema` · Domain: State persistence · Engine Risk: LOW

**Equipment Forge System** (`design/gdd/equipment-forge.md`) — the project's most convergent system (depends on 7 others)
- ❌ TR-equipforge-001: `Inventory.apply_rune_to_item()` in-place mutation API (added to `inventory.md` 2026-07-17) — same ADR as Crafting's Inventory API additions above; one ADR should own Inventory's entire new query/mutation surface rather than splitting it across two.
  Suggested ADR: `/architecture-decision Inventory cross-system query/mutation API` (same as TR-craft-003) · Domain: Integration contract · Engine Risk: LOW
- ❌ TR-equipforge-002: `Menagerie.request_sacrifice(creature_id, target_item_id)` cross-system call boundary (signature adopted into `menagerie.md` 2026-07-17).
  Suggested ADR: `/architecture-decision Equipment Forge cross-system aggregation` · Domain: Integration contract · Engine Risk: LOW
- ❌ TR-equipforge-003: Persistence for crafted/imbued gear (`restore_order=32`) plus the still-open Constellation `restore_order` dependency this system's own AC-26 is blocked on (Constellation's slot was assigned 2026-07-17 — this ADR should confirm AC-26 is now unblockable).
  Suggested ADR: covered by the aggregation ADR above · Domain: State persistence · Engine Risk: LOW

---

### Cross-ADR Conflicts

Not re-run this pass — see Scope Note. No new ADRs were added since the 2026-07-13 baseline, which found no unresolved conflicts among the 19 existing ADRs (`architecture-review-2026-07-13d.md`). Re-run Phase 4 in full once any of the 9 gap ADRs above are drafted.

### ADR Dependency Order

Unchanged from the 2026-07-13 baseline for the 19 existing ADRs. For the 9 new systems, a rough dependency order based on what each depends on (per `systems-index.md`'s own Feature/Advanced layer split):

**Write first (no new-system dependencies, unblocks the most):**
1. Direct-Autoload-call exception pattern (retroactively covers Grid, Mission Select, Mission HUD — should exist regardless of which system-specific ADR comes next)
2. Inventory cross-system query/mutation API (unblocks both Crafting and Equipment Forge)
3. Constellation pattern-detection data structure (Feature layer, only depends on already-Approved Tower/Grid/EventBus)

**Feature layer (depends on the above):**
4. Crafting recipe data model + discovery state machine
5. Tarot modifier aggregation pipeline
6. Menagerie creature lifecycle state machine
7. Defense Building tech tree data model
8. Mission Select runtime state & retry architecture

**Advanced layer (depends on Feature layer + Hero):**
9. Tower Mastery proximity-detection strategy (recommend prototyping before finalizing, per its own HIGH engine-risk flag)
10. Hero Skill Build Ultimate lookup-table architecture (depends on Tower Mastery's ADR resolving the shared restore-order question)
11. Equipment Forge cross-system aggregation (depends on all of the above — write last, matches `systems-index.md`'s own explicit "design last among Sanctuary systems" guidance)

### GDD Revision Flags

None found this pass. The 9 new GDDs were authored and fixed this session with the pinned Godot 4.6.2 engine reference already in context; no post-cutoff-API assumption conflicts were identified. (Not a substitute for a full Phase 5 engine audit once real ADRs exist and name specific APIs — see Scope Note.)

### Engine Compatibility Issues

Not re-audited this pass — unchanged since the 2026-07-13 baseline (no new ADRs to check).

### Architecture Document Coverage

`docs/architecture/architecture.md` (last updated 2026-07-13) already contains **pre-emptive Module Ownership entries** for all 9 of these systems, written before their GDDs existed — e.g. its Constellation row cites `constellation_broken` as the deactivation event, but `event-bus.md`'s actual, now-authored catalogue uses `constellation_deactivated`. These entries were reasonable forward guesses at the time but are now superseded by real GDD contracts and should be refreshed, not left as the last word — recommend a dedicated `architecture.md` revision pass once the ADRs above exist, rather than patching it incrementally per-ADR.

All 25 systems from `systems-index.md` do appear in `architecture.md`'s System Layer Map — no orphaned architecture (entries with no corresponding GDD) were found.

---

### Verdict: CONCERNS

Not FAIL: none of the 9 gaps are Foundation or Core layer — all 9 systems are Feature/Advanced tier per `systems-index.md`'s own priority classification, and the project's precedent (Epic 03) already shows Blocked-pending-ADR stories are a normal, expected intermediate state, not a broken one.

Not PASS: 27 requirements across 9 fully-designed systems have zero architectural coverage — real work remains before any of these systems can leave "Blocked" once epics/stories are created for them.

### Blocking Issues (must resolve before PASS)

None are blocking in the FAIL sense (no Foundation/Core gaps), but every one of the 27 gaps above blocks its own system's implementation stories from becoming `Ready` (matching the exact pattern Epic 03's Inventory/Resource Economy stories went through before ADR-0016/ADR-0017 unblocked them).

### Required ADRs

Prioritised list (most foundational / most unblocking first — see ADR Dependency Order above for the full reasoning):
1. Direct-Autoload-call exception pattern
2. Inventory cross-system query/mutation API
3. Constellation pattern-detection data structure
4–8. Crafting, Tarot, Menagerie, Defense Building, Mission Select (Feature layer, any order)
9–11. Tower Mastery, Hero Skill Build, Equipment Forge (Advanced layer, in this order — each depends on the previous)
