# Systems Index: Sanctuary Defenders

> **Status**: Draft
> **Created**: 2026-04-21
> **Last Updated**: 2026-05-22
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

Sanctuary Defenders is a hybrid RPG Tower Defense built on nine explicitly named gameplay systems
(Hero, Tower, Monster, Constellation, Tarot, Crafting, Menagerie, Defense Building, Inventory) plus
sixteen additional systems inferred from the design — infrastructure, cross-cutting logic, and
presentation. All gameplay systems communicate exclusively through a central EventBus; no system
has a direct reference to another. The game operates across two primary contexts: the Mission
(Scout → Wave → Intermission → Outcome) and the Sanctuary (meta-progression hub). Some systems
are active in both contexts. The design order follows the dependency graph: infrastructure first,
then core gameplay, then cross-system features, then presentation.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | EventBus System | Infrastructure | MVP | **Approved** (Pass 1 — 2026-05-14; 2 blockers resolved in-session: hero_bonus_tier field renames in HeroAutoAttackEvent and MonsterDamageTaken; catalogue count corrected to 70 events / 19 publishing systems) | design/gdd/event-bus.md | None |
| 2 | Grid System | Infrastructure | MVP | **Approved** (Pass 1 — 2026-05-15; B1 Rule 3 floor() fix, R1 EC-5 ID-uniqueness clarification, R2 GDError→Error type, R3 walkability map key semantics, R4 remove_tower scan spec) | design/gdd/grid-system.md | None |
| 3 | Save & Persistence System | Infrastructure | MVP | **Approved** (Pass 1 — 2026-05-15; B1 mission_launched payload: modifier_count→modifiers:PackedStringArray, S&P Interactions table updated with payload read spec) | design/gdd/save-persistence.md | None |
| 4 | Audio System | Presentation | Full Vision | Not Started | — | None |
| 5 | Hero System | Mission | MVP | **Approved** (Pass 1 — 2026-05-14; 2 blockers resolved in-session: hero_bonus_tier field rename, tower_removed subscription added) | design/gdd/hero.md | EventBus, Grid, Save & Persistence |
| 6 | Tower System | Mission | MVP | **Approved** (Revision 10 — 2026-05-11; accepted without re-review; re-confirmed 2026-05-14 lean pass — 0 blockers; R1 header fix applied) | design/gdd/tower.md | EventBus, Grid, Save & Persistence |
| 7 | Monster System | Mission | MVP | **Approved** (Pass 5 re-review — 2026-05-14; 0 blockers; Pass 6 clarifications applied — 2026-05-14: co-dependency threshold corrected, Rule 17a scan order clarified, Formula 2 Tarot note added) | design/gdd/monster.md | EventBus, Grid |
| 8 | Damage & Status System | Cross-Cutting | MVP | **Approved** (Pass 6 lean re-review — 2026-05-14; all 12 pass-4 blockers confirmed resolved; 0 blockers; 4 cross-GDD follow-ups tracked) | design/gdd/damage-status.md | EventBus, Tower (is_armored), Monster (monster_hp_absorbed) |
| 9 | Pathfinding System (inferred) | Infrastructure | MVP | **Approved** (review #11 — 2026-05-22; Rule 15d .slice() type-safety fix (B5 completion), Mission HUD dep ref updated, fallback cap check order binding note added. Prior reviews #1–#10: 16 blockers resolved across B1–B16 including get_path() two-value contract, CI tool extends SceneTree fix, would_block_all_paths() 6-step procedure, Level Design Guidelines, _spawn_assignment lifecycle, _compute_cost coordinate space, fallback cap default 1, WAVE_ACTIVE rebuild guard) | design/gdd/pathfinding.md | Grid |
| 10 | Inventory System | Cross-Cutting | Vertical Slice | Not Started | — | EventBus, Save & Persistence |
| 11 | Resource Economy System (inferred) | Cross-Cutting | Vertical Slice | Not Started | — | EventBus, Save & Persistence |
| 12 | Wave Manager (inferred) | Mission | MVP | **Approved** (review #10 — 2026-05-22; 0 blockers; R1 Rule 9 min-duration knob reference, R2 AC-41 wave_time_budget runtime AC, R3 templates_ready lifecycle note. Prior reviews #1–#9: 9 blockers resolved across rules, ACs, FSM guards, pathfinding gate, latch semantics, economy ceiling, and CI validator spec) | design/gdd/wave-manager.md | Monster, EventBus, Grid |
| 13 | Constellation System | Mission | Vertical Slice | Not Started | — | Tower, Grid, EventBus |
| 14 | Crafting System | Sanctuary | Vertical Slice | Not Started | — | Inventory, Resource Economy, EventBus |
| 15 | Tarot System | Cross-Cutting | Vertical Slice | Not Started | — | EventBus, Save & Persistence, Wave Manager |
| 16 | Menagerie System | Sanctuary | Alpha | Not Started | — | Inventory, Resource Economy, EventBus, Save & Persistence |
| 17 | Defense Building System | Sanctuary | Alpha | Not Started | — | Inventory, Resource Economy, EventBus, Save & Persistence |
| 18 | Tower Mastery System (inferred) | Mission | Alpha | Not Started | — | Hero, Tower, EventBus, Grid |
| 19 | Mission Select System (inferred) | Cross-Cutting | Alpha | Not Started | — | Save & Persistence, EventBus |
| 20 | Hero Skill Build System (inferred) | Cross-Cutting | Alpha | Not Started | — | Tower Mastery, Hero, EventBus, Save & Persistence |
| 21 | Equipment Forge System (inferred) | Sanctuary | Alpha | Not Started | — | Hero, Crafting, Menagerie, Constellation, Tarot, Inventory, Save & Persistence |
| 22 | Encyclopedia System (inferred) | Cross-Cutting | Full Vision | Not Started | — | Save & Persistence, EventBus |
| 23 | Mission HUD (inferred) | Presentation | Vertical Slice | **Skeleton** (2026-05-22 — stub created to close broken dependency reference from pathfinding.md; PC-1/PC-2/PC-3 signal contracts locked; full design deferred) | design/gdd/mission-hud.md | Hero, Wave Manager, Constellation, Resource Economy, EventBus, Pathfinding, Tower |
| 24 | Sanctuary UI (inferred) | Presentation | Alpha | Not Started | — | Crafting, Menagerie, Defense Building, Inventory, Equipment Forge, Save & Persistence |
| 25 | Tarot Deck UI (inferred) | Presentation | Alpha | Not Started | — | Tarot, Hero Skill Build, Save & Persistence |

---

## Categories

| Category | Description | Systems in This Game |
|----------|-------------|----------------------|
| **Infrastructure** | Foundation systems everything depends on; no gameplay knowledge | EventBus, Grid, Save & Persistence, Pathfinding |
| **Mission** | Active during SCOUT → WAVE_ACTIVE → INTERMISSION → OUTCOME | Hero, Tower, Monster, Wave Manager, Constellation, Damage & Status, Tower Mastery |
| **Sanctuary** | Active between missions in the meta-progression hub | Crafting, Menagerie, Defense Building, Equipment Forge |
| **Cross-Cutting** | Active in both Mission and Sanctuary contexts | Tarot, Inventory, Resource Economy, Mission Select, Hero Skill Build, Encyclopedia, Damage & Status |
| **Presentation** | Player-facing displays and audio | Mission HUD, Sanctuary UI, Tarot Deck UI, Audio |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you cannot test "is this fun?" | First playable prototype | Design FIRST |
| **Vertical Slice** | Required for one complete, polished experience of Scout → Wave → Sanctuary. Demonstrates the full loop. | Vertical slice / demo | Design SECOND |
| **Alpha** | All features present in rough form. Complete mechanical scope, placeholder content acceptable. | Alpha milestone | Design THIRD |
| **Full Vision** | Polish, meta, quality-of-life, and content-complete features. | Beta / Release | Design as needed |

---

## Dependency Map

Systems sorted by dependency order — design and build top to bottom.

### Foundation Layer (no dependencies)

1. **EventBus System** — Pure pub/sub backbone; all cross-system communication passes through here; no game knowledge required
2. **Grid System** — Spatial data structure for tower placement, spawn points, and constellation pattern detection
3. **Save & Persistence System** — Serialisation layer; required for Core Rule 11 (Sanctuary progress always survives defeat)
4. **Audio System** — Responds to EventBus events; requires no game-state knowledge

### Core Layer (depends on Foundation)

1. **Hero System** — depends on: EventBus, Grid, Save & Persistence
2. **Tower System** — depends on: EventBus, Grid, Save & Persistence
3. **Monster System** — depends on: EventBus, Grid
4. **Damage & Status System** — depends on: EventBus (consumes hit events, emits damage events)
5. **Pathfinding System** — depends on: Grid
6. **Inventory System** — depends on: EventBus, Save & Persistence
7. **Resource Economy System** — depends on: EventBus, Save & Persistence

### Feature Layer (depends on Core)

1. **Wave Manager** — depends on: Monster, EventBus, Grid
2. **Constellation System** — depends on: Tower, Grid, EventBus
3. **Crafting System** — depends on: Inventory, Resource Economy, EventBus
4. **Menagerie System** — depends on: Inventory, Resource Economy, EventBus, Save & Persistence
5. **Defense Building System** — depends on: Inventory, Resource Economy, EventBus, Save & Persistence
6. **Tarot System** — depends on: EventBus, Save & Persistence, Wave Manager
7. **Tower Mastery System** — depends on: Hero, Tower, EventBus, Grid
8. **Mission Select System** — depends on: Save & Persistence, EventBus

### Advanced Feature Layer (depends on Feature Layer)

1. **Hero Skill Build System** — depends on: Tower Mastery, Hero, EventBus, Save & Persistence
2. **Equipment Forge System** — depends on: Hero, Crafting, Menagerie, Constellation, Tarot, Inventory, Save & Persistence
3. **Encyclopedia System** — depends on: Save & Persistence, EventBus

### Presentation Layer (wraps all gameplay systems)

1. **Mission HUD** — depends on: Hero, Wave Manager, Constellation, Resource Economy, EventBus
2. **Sanctuary UI** — depends on: Crafting, Menagerie, Defense Building, Inventory, Equipment Forge, Save & Persistence
3. **Tarot Deck UI** — depends on: Tarot, Hero Skill Build, Save & Persistence

---

## Recommended Design Order

Systems in this order — independent systems at the same layer can be designed in parallel.

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 1 | EventBus System | MVP | Foundation | S |
| 2 | Grid System | MVP | Foundation | S |
| 3 | Save & Persistence System | MVP | Foundation | M |
| 4 | Hero System | MVP | Core | M |
| 5 | Tower System | MVP | Core | M |
| 6 | Monster System | MVP | Core | M |
| 7 | Damage & Status System | MVP | Core | S |
| 8 | Pathfinding System | MVP | Core | S |
| 9 | Inventory System | Vertical Slice | Core | M |
| 10 | Resource Economy System | Vertical Slice | Core | S |
| 11 | Wave Manager | MVP | Feature | M |
| 12 | Constellation System | Vertical Slice | Feature | M |
| 13 | Crafting System | Vertical Slice | Feature | M |
| 14 | Tarot System | Vertical Slice | Feature | L |
| 15 | Menagerie System | Alpha | Feature | M |
| 16 | Defense Building System | Alpha | Feature | M |
| 17 | Tower Mastery System | Alpha | Feature | L |
| 18 | Mission Select System | Alpha | Feature | S |
| 19 | Hero Skill Build System | Alpha | Advanced | L |
| 20 | Equipment Forge System | Alpha | Advanced | L |
| 21 | Encyclopedia System | Full Vision | Advanced | M |
| 22 | Mission HUD | Vertical Slice | Presentation | M |
| 23 | Sanctuary UI | Alpha | Presentation | L |
| 24 | Tarot Deck UI | Alpha | Presentation | M |
| 25 | Audio System | Full Vision | Presentation | M |

*Effort: S = 1 session · M = 2–3 sessions · L = 4+ sessions. A session = one focused design conversation producing a complete GDD.*

*Parallel opportunities: Systems 4–5 (Hero + Tower), 5–7 (Tower + Monster), 12–13 (Constellation + Crafting), 15–16 (Menagerie + Defense Building) can be designed simultaneously if bandwidth allows.*

---

## Circular Dependencies

No true circular dependencies detected.

**Near-cycle resolved:** Tarot System modifies wave parameters; Wave Manager reads those parameters. Resolution: Tarot outputs a static modifier data payload at mission start; Wave Manager reads it as configuration input. Tarot does not subscribe to Wave events during WAVE_ACTIVE. One-directional data flow — not a runtime cycle.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| **EventBus System** | Technical / Contract | Event schema must be fully designed before any other system is built. Retroactively changing event signatures breaks all subscribers. | Design and freeze event contracts in EventBus GDD before any other system GDD is authored. Treat event names + payloads as a public API. |
| **Pathfinding System** | Technical | Performance AC requires 100+ simultaneous pathfinding agents at 60 FPS. Godot 4's built-in NavigationServer may not satisfy this under all conditions. | Prototype pathfinding with 100+ agents early (before Alpha), independent of gameplay systems. Identify Jolt physics + NavMesh interaction issues at Godot 4.6 specifically. |
| **Tower Mastery System** | Design | Proximity-based learning during live combat is untested in the tower-defense genre. The tension between "fight enemies" and "stand near a tower" may frustrate rather than engage. | Prototype proximity detection + learning threshold in isolation. Playtest specifically for "does the mechanic feel fair?" before integrating into full missions. |
| **Hero Skill Build System** | Design / Scope | 4 active skills × N possible combinations for the Ultimate mechanic creates a potentially explosive design space. Without constraints, the balance surface becomes unmanageable. | During GDD authoring, enumerate all tower-learnable skills and define the full combination matrix before implementation. Cap Ultimate combinations at a tractable number. |
| **Equipment Forge System** | Scope | Depends on 7 other systems being fully defined first (Hero, Crafting, Menagerie, Constellation, Tarot, Inventory, Save & Persistence). Any upstream design change ripples into the Forge's balance assumptions. | Design last among Sanctuary systems. Include an explicit "upstream changes that invalidate this document" section in the GDD. |

---

## Bottleneck Systems

Systems with the highest number of downstream dependents — these carry the most architectural risk.

| System | Dependent Count | Risk Level | Note |
|--------|----------------|------------|------|
| EventBus System | 24 (all others) | CRITICAL | Contract changes break everything |
| Grid System | 6 | HIGH | Tower, Monster, Constellation, Pathfinding, Wave Manager, Tower Mastery |
| Save & Persistence System | 10 | HIGH | Hero, Tower, Inventory, Menagerie, Defense Building, Tarot, Mission Select, Hero Skill Build, Equipment Forge, Encyclopedia |
| Inventory System | 4 | MEDIUM | Crafting, Menagerie, Defense Building, Equipment Forge |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 25 |
| Design docs started | 9 |
| Design docs reviewed | 4 |
| Design docs approved | 11 |
| MVP systems designed | 9 / 9 |
| Vertical Slice systems designed | 0 / 6 |
| Alpha systems designed | 0 / 8 |
| Full Vision systems designed | 0 / 2 |

---

## Next Steps

- [ ] Run `/design-system event-bus` — design the EventBus event contract first (highest risk bottleneck)
- [ ] Run `/design-system grid` — spatial foundation for tower placement and constellations
- [x] Run `/design-system hero` — the player character is mandatory in every mission
- [ ] Run `/design-system tower` — tower placement is the primary gameplay verb
- [ ] After each GDD: run `/design-review design/gdd/[system].md` to validate quality
- [ ] Run `/map-systems next` to always pick the highest-priority undesigned system
- [ ] Run `/gate-check systems-design` when all MVP systems have approved GDDs
- [ ] Prototype the Pathfinding System early regardless of tier (100+ agent performance risk)
- [ ] Prototype the Tower Mastery System early (design hypothesis: is proximity learning fun?)
