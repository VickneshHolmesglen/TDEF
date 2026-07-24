# Story 007: Cross-GDD Interface & Registry Dependencies

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Config/Data
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/hero-skill-build.md`
**Requirement**: `TR-heroskill-001`

**ADR Governing Implementation**: ADR-0030 (Hero Skill Build Ultimate Lookup-Table Architecture)
**ADR Decision Summary**: Three cross-GDD gaps remain genuinely unresolved outside this ADR's own scope: `inventory.md` needs `item_type = "skill_modifier"` added to its Equipment-tab mapping; `design/registry/entities.yaml` needs a `referenced_by` cross-reference linking this GDD's `category` enum to `tower.md`'s `archetype` enum; and the registry needs a new 19-value `ultimate_id` enum entry. This story tracks these as explicit, testable blockers rather than silently assuming them resolved.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Pure content/registry-configuration gaps — no engine subsystem risk.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0030 directly.
- Forbidden: Do not hardcode the 19 Ultimate ID strings independently in more than one system once the registry entry lands — this would violate the pending resolution.
- Guardrail: These three ACs are pre-implementation blockers, not runtime defects — track and re-test only once each named revision lands.

---

## Acceptance Criteria

*From GDD `design/gdd/hero-skill-build.md`, scoped to this story:*

- [ ] AC-18 *(STILL BLOCKED on Inventory revision — re-verified 2026-07-19)* — `skill_modifier` is not currently a valid `item_type` anywhere in `inventory.md`; this AC cannot pass until Inventory's next revision adds it under the Equipment tab
- [x] AC-19 *(RESOLVED — found already fixed on re-verification 2026-07-19, not assumed)* — `entities.yaml` already has a `hero_skill_category` entry (`added: 2026-07-17`) cross-referencing `category` to `tower.md`'s `archetype`, authored between the GDD/ADR session and this story being written
- [x] AC-20 *(RESOLVED — found already fixed on re-verification 2026-07-19, not assumed)* — `entities.yaml` already has a `hero_ultimate_id_derivation` entry (`added: 2026-07-17`) documenting the 19-value Ultimate ID set

---

## Implementation Notes

*Derived from ADR-0030's Constraints and the GDD's own Open Questions:*

- **AC-18**: skill-modifier items are recommended to file under Inventory's existing Equipment tab (`stack_cap_unique=1`, equipped-item lock reuse) rather than a 5th tab — this is Hero Skill Build's own recommendation, not yet adopted by `inventory.md`. Track this as a required Inventory revision before any test attempting to equip/unequip a skill-modifier item via Inventory's real API can move from blocked to passing.
- **AC-19**: `category` (4 values: `physical`/`ranged`/`elemental`/`support`) is deliberately reused from `tower.md`'s Foundation `archetype` enum, not a new taxonomy — the registry should record this as a `referenced_by` addition to the existing `archetype` entry, not a new entry, mirroring `tower-mastery.md`'s own proximity-radius cross-reference request.
- **AC-20**: the 19-entry Ultimate ID set (Formula 3's table) should become a single registry entry consumable by Hero System, Mission HUD, and this GDD without duplication — avoiding three independently hardcoded copies.
- None of these three gaps block Stories 001–006's own core mechanics — they are tracked here specifically so they are not silently assumed resolved during implementation, following the same rigor `constellation.md` OQ-4 and `tower-mastery.md`'s `get_component_loadout()` gap were tracked with.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the `category` enum's own schema definition (this story only tracks its registry cross-reference)
- Story 002: the Ultimate ID derivation logic itself (this story only tracks the registry entry for the resulting 19-value set)
- Story 004: the passive-slot mechanics that would consume `skill_modifier` items once Inventory's revision lands

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-18**: Inventory item_type gap
  - Given: the proposal that skill-modifier items use `item_type = "skill_modifier"` under Inventory's Equipment tab
  - When: `inventory.md`'s current tab-to-item_type mapping table is checked
  - Then: `skill_modifier` is not currently valid anywhere — this AC cannot pass today; becomes testable only once Inventory's next revision adds it

- **AC-19**: Registry cross-reference gap
  - Given: the request that `entities.yaml` gain a `referenced_by` cross-reference linking `category` to `tower.md`'s `archetype`
  - When: `entities.yaml` is inspected
  - Then: this cross-reference does not yet exist — track as a pre-implementation blocker

- **AC-20**: Registry enum gap
  - Given: the request that the 19-entry Ultimate ID set become a registry entry
  - When: `entities.yaml` is inspected
  - Then: no such enum entry exists yet — any implementation hardcoding the 19 strings independently in more than one system violates this pending resolution once the registry entry lands

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `production/qa/smoke-heroskillbuild-registry-dependencies.md` — content-validation smoke check confirming current (blocked) status, re-run once each revision lands

**Status**: [x] Created — `production/qa/smoke-heroskillbuild-registry-dependencies.md`

---

## Dependencies

- Depends on: None (a tracking story, not a code-dependent one)
- Unlocks: None — this story documents pre-implementation blockers external to this epic's own scope

**ADR unblocked**: ADR-0030 accepted 2026-07-18 (Sprint 6, S6-04). **Still blocked independently**: AC-18 (Inventory `skill_modifier` item_type) remains open — track for follow-up, do not silently assume resolved.

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 2/3 passing, 1 genuinely still blocked — this story's original premise (all 3 blocked) was stale. Re-verifying against live repo state (not trusting the story text) found AC-19 and AC-20's registry entries (`hero_skill_category`, `hero_ultimate_id_derivation`) already existed in `entities.yaml`, dated `added: 2026-07-17` — authored during the GDD/ADR session, before this story was written, and never re-checked during `/create-stories`. AC-18 (Inventory `skill_modifier` item_type) confirmed still genuinely open.
**Deviations**: Marking this story Complete despite AC-18 remaining open — the story's own scope is *tracking* these 3 gaps accurately, not resolving them (explicitly "Depends on: None... a tracking story"); that job is done, with 2 of 3 gaps found closed and 1 correctly identified as still open.
**Test Evidence**: Config/Data — smoke check at `production/qa/smoke-heroskillbuild-registry-dependencies.md`.
**Code Review**: N/A — no code changes this story (pure documentation/verification).
