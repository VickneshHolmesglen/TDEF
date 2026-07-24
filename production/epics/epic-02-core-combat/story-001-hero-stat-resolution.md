# Story 001: Hero Stat Resolution

> **Epic**: Core Combat Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-16
> **Estimate**: 2–3 hours

## Context

**GDD**: `design/gdd/hero.md`
**Requirement**: `TR-hero-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Hero Tower-Synced Class + Tower Affinity
**ADR Decision Summary**: Formula 1 (effective stat) is defined in ADR-0010 as `max(0, max(0, base + flat) × clamp(1 + additive, 0.25, 4.0))`. Stat resolution is owned entirely by the Hero System — no other system writes hero stats directly.

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: `Dictionary[K, V]` typed-hint syntax (used for stat storage) requires Godot 4.4+ — verify syntax compiles cleanly before committing. `maxi()` builtin confirmed available in Godot 4.x. No post-cutoff risk on the math itself.

**Control Manifest Rules (Core layer)**:
- Required: No direct calls to TowerSystem, MonsterSystem, or DamageStatus from HeroSystem
- Required: All stat reads via `get_effective_stat(stat_name: StringName) → float` public API
- Forbidden: Storing effective (resolved) stat values as persistent fields — always compute from base + bonuses
- Guardrail: Stat resolution must complete in O(1) per stat call — no iteration, no EventBus

---

## Acceptance Criteria

*From `design/gdd/hero.md`, scoped to this story:*

- [ ] AC-01: GIVEN `base_stat = 50`, `flat_bonus = +12`, `additive_bonus_total = 0.45`, WHEN `get_effective_stat()` is called, THEN result = `(50 + 12) × (1 + 0.45) = 89.9` — implementation may round to convention (floor, ceil, or round) but must be consistent
- [ ] AC-02: GIVEN `additive_bonus_total > +3.00` from stacked bonuses, WHEN effective stat is calculated, THEN additive total is clamped to `3.00` — maximum multiplier applied is `4.0×` the flat-adjusted base
- [ ] EC-1: GIVEN `additive_bonus_total < −0.75` from stacked debuffs, WHEN effective stat is calculated, THEN additive total is clamped to `−0.75` — minimum multiplier is `0.25×`
- [ ] EC-2: GIVEN `(base_stat + flat_bonus)` is negative (large negative flat affix), WHEN effective stat is calculated, THEN the intermediate value is clamped to 0 before the multiplier is applied — stat never goes negative

---

## Implementation Notes

*Derived from ADR-0010 Implementation Guidelines:*

Implement `get_effective_stat(stat_name: StringName) → float` on the Hero node. The formula is:

```gdscript
func get_effective_stat(stat_name: StringName) -> float:
    var base: float = _base_stats.get(stat_name, 0.0)
    var flat: float = _flat_bonuses.get(stat_name, 0.0)
    var additive: float = _additive_bonuses.get(stat_name, 0.0)
    var intermediate: float = maxf(0.0, base + flat)
    var multiplier: float = 1.0 + clampf(additive, -0.75, 3.0)
    return intermediate * multiplier
```

Store stats as three separate Dictionaries: `_base_stats`, `_flat_bonuses`, `_additive_bonuses`. This separation makes the additive bucket model explicit and testable.

The 12 stat keys (snake_case StringNames): `&"max_hp"`, `&"damage"`, `&"move_speed"`, `&"cdr"`, `&"crit_chance"`, `&"armor"`, `&"skill_power"`, `&"attack_range"`, `&"elemental_resist_fire"`, `&"elemental_resist_frost"`, etc., `&"lifesteal"`, `&"tower_affinity"`, `&"crit_multiplier"`.

Per-stat caps (Tuning Knobs): `crit_chance` capped at 80%; `elemental_resist_*` capped at 75%; `lifesteal` capped at 40%; `cdr` capped at 75%. Apply caps inside `get_effective_stat()` after the formula.

This story covers Formula 1 only. Formula 2 (Tower Affinity) is Story 005.

---

## Out of Scope

- **Story 005**: Tower Affinity formula (Formula 2 — builds on top of Formula 1 output)
- **Story 003**: Auto-attack damage calculation (Formula 4 — uses effective stats as inputs)
- **Story 008**: Save/load persistence of stat bonuses

---

## QA Test Cases

- **AC-01**: Effective stat formula
  - Given: Hero with `_base_stats[&"damage"] = 50`, `_flat_bonuses[&"damage"] = 12`, `_additive_bonuses[&"damage"] = 0.45`
  - When: `get_effective_stat(&"damage")` is called
  - Then: Result is `89.9` (or equivalent rounded value per implementation convention — test must document the rounding)
  - Edge cases: `flat_bonus = 0` (verify base × (1 + additive) directly); `additive = 0` (verify base + flat with multiplier = 1)

- **AC-02**: Additive cap at +3.00
  - Given: `_additive_bonuses[&"damage"] = 5.0` (above cap)
  - When: `get_effective_stat(&"damage")` is called
  - Then: Additive is clamped to 3.00; multiplier = 4.0; result = `(base + flat) × 4.0`
  - Edge cases: Exactly 3.00 passes through unclamped; 3.001 is clamped

- **EC-1**: Additive floor at −0.75
  - Given: `_additive_bonuses[&"damage"] = -1.5` (below floor)
  - When: `get_effective_stat(&"damage")` is called
  - Then: Additive is clamped to -0.75; multiplier = 0.25; result = `(base + flat) × 0.25`

- **EC-2**: Negative intermediate value guard
  - Given: `_base_stats[&"damage"] = 10`, `_flat_bonuses[&"damage"] = -50` (result: negative intermediate)
  - When: `get_effective_stat(&"damage")` is called
  - Then: Result is `0.0` — stat never goes negative

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero/hero_stat_resolution_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None — this is the Hero system's foundational building block
- Unlocks: Story 002 (movement uses move_speed), Story 003 (auto-attack uses damage), Story 005 (Tower Affinity formula), Story 007 (skill CDR formula)

## Completion Notes
**Completed**: 2026-07-03
**Criteria**: 4/4 passing (AC-01, AC-02, EC-1, EC-2), plus 6 bonus tests for `_apply_stat_cap()`'s real branches (a gap the story never wrote an AC for, found and closed during code review). 15/15 automated tests passing, 0 errors, 0 failures.
**Deviations**: Advisory only — ADR-0010's Context section incorrectly states "Hero System is an Autoload," contradicting `control-manifest.md` and ADR-0002's scene-instanced classification; implemented per the correct, authoritative sources (`CharacterBody2D`, scene-instanced). Logged as tech debt (TD-adr-001) for an ADR erratum. Per-stat cap constants are hardcoded, matching ADR-0010's own design sketch — `TODO` added for future migration to `HeroResource`.
**Test Evidence**: Logic — `tests/unit/hero/hero_stat_resolution_test.gd` (15 tests, all passing)
**Code Review**: Complete — 2 Required Changes found and fixed (typed `Dictionary[StringName, float]` fields, missing cap-branch test coverage). Re-reviewed, verdict APPROVED.
