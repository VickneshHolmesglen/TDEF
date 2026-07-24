# Epic 02 — Core Combat Engine

> **Layer**: Core
> **GDDs**: `design/gdd/hero.md` · `design/gdd/tower.md` · `design/gdd/monster.md` · `design/gdd/damage-status.md`
> **Architecture Modules**: Hero · Tower · Monster · Damage & Status
> **Status**: Complete — all 4 systems (Tower, Monster, D&S, Hero) implemented, reviewed, and closed. Corrected 2026-07-05: this header previously read "In Progress — Hero not yet implemented," which was stale — all 8 Hero stories completed 2026-07-03/07-04 in a prior session but this file was never updated to reflect it.
> **Sprint home**: Sprint 3 (Tower/Monster/D&S) → Sprint 4 (Hero)
> **Stories**: See `production/stories/core/` for Sprint 3 stories; Hero stories are `story-001` through `story-008` in this directory, all Complete

## Overview

This epic implements the four MVP Core layer systems that together deliver the moment-to-moment combat of "The Gap" Vertical Slice. Tower (placement and auto-fire), Monster (wave movement and breach), and Damage & Status (hit resolution pipeline) were shipped in Sprint 3. Hero — the player-controlled character whose combat effectiveness is the vindication beat of the Vertical Slice — is the remaining unimplemented system in this epic.

All four systems communicate exclusively through EventBus. No system holds a direct reference to another. The combat loop is: `tower_attacked` → DamageStatus resolves → `monster_hp_changed` / `monster_died` → Hero fills the gap in direct combat → `hero_incoming_damage` → DamageStatus resolves → `hero_damage_taken`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0006: Monster Movement | Position-based movement (not physics-driven); centralized 4-pass MonsterManager; _pending_damage buffer flushed in _physics_process | LOW |
| ADR-0007: Damage Pipeline | Two pipelines (direct hit + DoT); all input via EventBus only; await + is_instance_valid guard after every process_frame | LOW |
| ADR-0008: Tower Placement Gate | Placement blocked during WAVE_ACTIVE; would_block_all_paths() speculative check before confirming placement | LOW |
| ADR-0010: Hero-Tower Synced Class | Chebyshev 3-cell proximity scan; Tower-Synced Class unlocks via WAVE_ACTIVE proximity accumulator; hero/world seam uses stacked sprite with fixed oblique angle | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage | Status |
|-------|-------------|--------------|--------|
| TR-hero-001 | CharacterBody2D scene root | ❌ No ADR | ✅ Complete (Story 002/008) |
| TR-hero-002 | 12 stats; Tower-Synced Class (Chebyshev 3-cell) | ✅ ADR-0010 | ✅ Complete (Story 005/006/008) |
| TR-hero-003 | Tower Affinity sqrt scaling | ❌ No ADR | ✅ Complete (Story 005) |
| TR-hero-004 | Event-driven targeting (no direct Monster refs) | ❌ No ADR | ✅ Complete (Story 003) |
| TR-hero-005 | 4 active skills + Ultimate | ❌ No ADR | ✅ Complete (Story 007) |
| TR-hero-006 | 6 stat formulas (crit, lifesteal, affinity, etc.) | ❌ No ADR | ✅ Complete (Story 001/004) |
| TR-tower-001 | 4 component slots; 4 archetypes; 4 tiers | ❌ No ADR | ✅ Sprint 3 |
| TR-tower-002 | Placement blocked during WAVE_ACTIVE | ✅ ADR-0008 | ✅ Sprint 3 |
| TR-tower-003 | Monster cache via EventBus; no direct Monster refs | ❌ No ADR | ✅ Sprint 3 |
| TR-tower-004 | would_block_all_paths() gate before placement | ✅ ADR-0008 | ✅ Sprint 3 |
| TR-tower-005 | Pre-placement perk (Scout phase only) | ❌ No ADR | ✅ Sprint 3 |
| TR-tower-006 | Support archetype aura pulse model | ❌ No ADR | ✅ Sprint 3 |
| TR-monster-001 | Area2D scene root | ❌ No ADR | ✅ Sprint 3 |
| TR-monster-002 | MonsterResource data-driven stats; 3 tiers | ❌ No ADR | ✅ Sprint 3 |
| TR-monster-003 | _pending_damage buffer flushed in _physics_process | ✅ ADR-0006 | ✅ Sprint 3 |
| TR-monster-004 | Position-based movement (not physics-driven) | ✅ ADR-0006 | ✅ Sprint 3 |
| TR-monster-005 | Dual-layer AnimatedSprite2D | ❌ No ADR | ✅ Sprint 3 |
| TR-monster-006 | Boss scan throttle + prepare-frames telegraph | ❌ No ADR | ✅ Sprint 3 |
| TR-ds-001 | Two pipelines: direct hit + DoT | ✅ ADR-0007 | ✅ Sprint 3 |
| TR-ds-002 | await + is_instance_valid guard pattern | ✅ ADR-0007 | ✅ Sprint 3 |
| TR-ds-003 | _lifesteal_pending Dictionary[int, float] | ✅ ADR-0007 | ✅ Sprint 3 |
| TR-ds-004 | 5 status effect types + stack/duration rules | ❌ No ADR | ✅ Sprint 3 |
| TR-ds-005 | No direct call API — EventBus only | ✅ ADR-0007 | ✅ Sprint 3 |

**Coverage summary**: 8/23 TRs have governing ADRs. 23/23 requirements implemented — all Sprint 3 systems plus all 6 Hero TRs (corrected 2026-07-05; previously read 17/23 with 6 Hero TRs remaining, which was stale by the time this was last checked).

> **Advisory**: 15 TRs lack an ADR. The implemented systems (Tower, Monster, D&S) shipped and passed QA without them — these requirements are covered by GDD acceptance criteria and unit tests. For the Hero system, TR-hero-001/003/004/005/006 represent GDD rules without a dedicated ADR; they must be implemented directly from the Hero GDD and are subject to code review against it.

## Definition of Done

This epic is complete — all criteria below are satisfied:
- ✅ All 8 Hero stories implemented, reviewed, and closed via `/story-done` (2026-07-03/07-04)
- ✅ Hero's acceptance criteria from `design/gdd/hero.md` pass across all 8 stories (AC-01 through AC-14, plus Rules 3-12, 19-20, EC-1/EC-2)
- ✅ Hero unit tests exist at `tests/unit/hero/` and integration tests at `tests/integration/hero/` — 446/446 passing per Story 008's Completion Notes (full suite, not just Hero's own tests)
- Hero-related Visual/Feel ACs have evidence docs in `production/qa/evidence/` — partially deferred (AC-14's manual debug-overlay evidence doc was logged ADVISORY in Story 002, not yet created — non-blocking per that story's own Test Evidence classification)
- ✅ Sprint 3 QA conditions cleared (carried forward from Sprint 3 close-out)
- ⏳ Full combat loop integration (Tower → D&S → Monster → Hero) demonstrated in Vertical Slice "The Gap" — pending actual scene assembly (Wave Manager epic's Story 008, not this epic's)

**Corrected 2026-07-05**: this section previously described the epic as incomplete pending Hero implementation. All 8 stories were actually finished 2026-07-03/07-04; this file just wasn't updated at the time.

## Vertical Slice Dependency

Hero's implementation is complete — the one remaining VS blocker is scene assembly itself (Wave Manager epic's Story 008), not any system in this epic. Note for that story: no Hero `.tscn` scene file exists yet anywhere in the project — every Hero story tested via direct `Hero.new()` script instantiation, never an authored scene with visual components. Story 008 will need to author a minimal Hero scene (attach the existing, fully-tested `hero.gd` to a new `CharacterBody2D` root + `CollisionShape2D` + placeholder visual) as part of its own scene-assembly scope.

**VS systems status**:
| System | Role in "The Gap" | Status |
|--------|------------------|--------|
| Monster | Wave spawning, route following, breach | ✅ Done |
| Tower | Scout-phase placement, auto-fire | ✅ Done |
| Damage & Status | Hit resolution, hero damage taken | ✅ Done |
| **Hero** | Direct combat, gap coverage, vindication beat | ✅ **Done** (logic/tests complete; no `.tscn` authored yet — Wave Manager Story 008's job) |

## Advisory: Untraced Requirements

Hero TRs without ADR coverage (TR-hero-001/003/004/005/006) are advisory — they must be implemented per the Hero GDD directly. For stories covering these, reference the Hero GDD acceptance criteria (AC-01 through AC-14) rather than an ADR. The stories will be authored as: `## ADR Governing Implementation: N/A — implemented per hero.md directly`.

If a Hero sub-system (e.g., the skill system, ultimate combo lookup) grows complex enough to warrant an ADR during Sprint 4 implementation, run `/architecture-decision` to create one before implementation begins.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Hero Stat Resolution](story-001-hero-stat-resolution.md) | Logic | Complete | ADR-0010 |
| 002 | [Hero Movement & Position Tracking](story-002-hero-movement.md) | Integration | Complete | ADR-0010 |
| 003 | [Hero Auto-Attack](story-003-hero-auto-attack.md) | Logic | Complete | ADR-0010 |
| 004 | [Hero Combat Formula Integration](story-004-hero-combat-integration.md) | Integration | Complete | ADR-0010 + ADR-0007 |
| 005 | [Hero Tower Affinity](story-005-hero-tower-affinity.md) | Logic | Complete | ADR-0010 |
| 006 | [Tower-Synced Class Proximity](story-006-hero-class-proximity.md) | Integration | Complete | ADR-0010 |
| 007 | [Hero Skill System](story-007-hero-skill-system.md) | Logic | Complete | N/A (hero.md direct) |
| 008 | [Hero Lifecycle, Death & Save](story-008-hero-lifecycle.md) | Integration | Complete | ADR-0010 + ADR-0002 + ADR-0003 |

**Story dependency order**: 001 → {002, 003, 005, 007} → 004 → {006} → 008
**VS critical path**: 001 → 002 → 003 → 004 → 008

> ⚠️ **Story 006 prerequisite**: `hero_class_unlocked(archetype: StringName)` signal must be added to `src/foundation/event_bus/event_bus.gd` before Story 006 implementation begins.

## Existing Sprint 3 Stories

| Story | System | Status |
|-------|--------|--------|
| [s3-02: Monster System](../../stories/core/s3-02-monster-system.md) | Monster | Complete |
| [s3-03: Tower System](../../stories/core/s3-03-tower-system.md) | Tower | Complete |
| [s3-04: Damage & Status System](../../stories/core/s3-04-damage-status-system.md) | D&S | Complete |
| [s3-05: Combat Loop Integration](../../stories/core/s3-05-combat-loop-integration.md) | All Core | Complete |
