# Story 001: Slots & Skill Catalogue Data Model

> **Epic**: Epic 08 — Meta-Progression Convergence
> **Status**: Complete
> **Layer**: Advanced
> **Type**: Logic
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/hero-skill-build.md`
**Requirement**: `TR-heroskill-001` (data model portion)

**ADR Governing Implementation**: ADR-0030 (Hero Skill Build Ultimate Lookup-Table Architecture)
**ADR Decision Summary**: One shared `SkillDefinitionResource` (amending ADR-0029's Tower Mastery definition in place) carries the full field set both systems need — `skill_id`, `category`, `passive_slot_count`, `source_build_signature`, `mastery_threshold_seconds`, `effect_data`. Both systems read the same `GameDataRegistry`-loaded instance per `skill_id`; neither owns a second, competing copy.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Pure arithmetic/Dictionary logic — no new engine subsystem.

**Control Manifest Rules (this layer)**:
- Required: N/A — manifest v2026-07-13b predates this ADR; follow ADR-0030/ADR-0009 directly.
- Forbidden: Never create a second, divergent `SkillDefinitionResource` field set — Tower Mastery (Epic 06) and Hero Skill Build must share exactly one Resource definition, loaded once via `GameDataRegistry`.
- Guardrail: `category` must match `tower.md`'s Foundation `archetype` enum exactly (same 4 values, same strings) — this is the categorical bucketing axis the Ultimate derivation depends on.

---

## Acceptance Criteria

*From GDD `design/gdd/hero-skill-build.md`, scoped to this story:*

- [x] AC-1 — exactly 5 independent bindings exist (A, B, C, D, U) in a fresh `CONFIGURABLE` state
- [x] AC-2 — every catalogue entry has a non-empty unique `skill_id`, valid `category`, `passive_slot_count` in [1,3], and either a valid `mastery_source_build_signature` or empty (if unreachable via mastery)
- [x] AC-3 — slot writes are rejected while `LOCKED`, succeed immediately while `CONFIGURABLE`
- [x] AC-4 — duplicate `skill_id` across active slots is allowed, not blocked; `category_count` reflects one increment per occupied slot regardless of repetition
- [x] AC-5 — this GDD's `category` enum is identical in cardinality and exact string values to `tower.md`'s Foundation `archetype` enum

---

## Implementation Notes

*Derived from ADR-0030 Implementation Guidelines:*

```gdscript
# SkillDefinitionResource (assets/data/skills/*.tres) — shared with Tower Mastery (ADR-0029, amended by this ADR)
class_name SkillDefinitionResource extends Resource
@export var skill_id: StringName = &""
@export var category: String = ""                 # physical|ranged|elemental|support
@export var passive_slot_count: int = 1            # 1-3
@export var source_build_signature: StringName = &""
@export var mastery_threshold_seconds: float = 45.0
@export var effect_data: Resource = null           # opaque; format owned by this GDD's future content pass
func validate() -> Array[String]: ...
```

- The hero has 4 active skill slots (A, B, C, D) and one Ultimate slot (U), per `hero.md` Rule 8 — all 5 independent bindings, Hero Skill Build owns the binding logic and Ultimate derivation.
- Alpha-scope catalogue is 8 skills, 2 per category (`phys_cleave`, `phys_bulwark`, `rng_piercing_shot`, `rng_volley`, `elem_frostbolt`, `elem_firestorm`, `sup_rally`, `sup_barrier`) — content-authoring reference only, not this story's own deliverable beyond the schema.
- Slot changes are permitted only while at Sanctuary (`CONFIGURABLE` state) — locked during `LOCKED` (SCOUT/WAVE_ACTIVE/INTERMISSION/OUTCOME/DEFEAT), mirroring `tower.md` Rule 3 and `hero.md` Rule 18's precedent.
- Duplicate `skill_id` across active slots is a deliberate, valid build strategy (e.g., 4× the same elemental skill deterministically produces `elemental_ascendant`) — never blocked by validation, since the Ultimate derivation keys only on `category`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the Ultimate derivation formulas themselves (this story only establishes the slot/catalogue data model they consume)
- Story 004: passive sub-slot assignment mechanics

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode.*

- **AC-1**: Five independent bindings
  - Given: a fresh `CONFIGURABLE` state with no skills equipped
  - When: the Sanctuary skill-build screen queries slot state
  - Then: exactly 5 bindings exist (A, B, C, D, U), each independently settable

- **AC-2**: Catalogue schema completeness
  - Given: the Alpha-scope 8-skill catalogue
  - When: each entry is inspected
  - Then: non-empty unique `skill_id`, `category` matching `tower.md`'s archetype enum string-for-string, `passive_slot_count` in [1,3], valid or empty `mastery_source_build_signature`

- **AC-3**: Sanctuary-only writes
  - Given: the system is `LOCKED` (any in-mission phase)
  - When: an attempt is made to change an active-slot or passive-slot binding
  - Then: rejected, no state change, no recompute, no event emitted; the same attempt while `CONFIGURABLE` succeeds immediately

- **AC-4**: Duplicate skill_id allowed
  - Given: `CONFIGURABLE` state
  - When: the same `skill_id` is assigned to 2, 3, or all 4 active slots
  - Then: no validation error, assignment succeeds in every slot, `category_count` reflects one increment per occupied slot regardless of repetition

- **AC-5**: Reused-vocabulary integrity
  - Given: `tower.md`'s Foundation `archetype` enum
  - When: this GDD's `category` enum is diffed against it
  - Then: identical cardinality (4) and exact string values — no new taxonomy

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/hero-skill-build/slots-catalogue-data-model_test.gd` — must exist and pass

**Status**: [x] Created — `tests/unit/hero-skill-build/slots-catalogue-data-model_test.gd` (10 tests, passing)

---

## Dependencies

- Depends on: None (foundational story for this system)
- Unlocks: Story 002, Story 003, Story 004, Story 005

**Unblocked**: ADR-0030 accepted 2026-07-18 (Sprint 6, S6-04).

---

## Completion Notes
**Completed**: 2026-07-19
**Criteria**: 5/5 passing (10 unit tests, all passing). New `src/core/skill_definition_resource.gd` (shared with Tower Mastery, ADR-0029 amendment) + `src/core/hero_skill_build/hero_skill_build.gd` (Autoload #13, `GHeroSkillBuild`).
**Deviations**: `SkillDefinitionResource` content authored at `assets/data/skills/definitions/`, not the ADR's literal `assets/data/skills/` — same directory-collision fix pattern as Story 008's MissionEntry/MissionResource split (avoids colliding with the pre-existing SkillResource cooldown-only loader). Alpha 8-skill catalogue's `source_build_signature` values are mostly synthetic placeholders (only 1 real tower blueprint exists in content) — flagged, not fabricated.
**Test Evidence**: Logic — `tests/unit/hero-skill-build/slots-catalogue-data-model_test.gd`.
**Code Review**: Complete (batch review across Stories 001-007) — APPROVED WITH SUGGESTIONS, required fixes applied.
