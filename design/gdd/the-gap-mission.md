# The Gap — Mission Content & Scene Assembly

---
**Status**: Reverse-Documented
**Source**: `src/gameplay/missions/the_gap/` (`the_gap.gd`, `grid_visual.gd`, `the_gap.tscn`), `assets/data/missions/the_gap.tres`, `assets/data/missions/entries/the_gap_entry.tres`, `assets/data/waves/the_gap_waves.tres`
**Date**: 2026-07-31
**Verified By**: User (design intent on single-lane scope confirmed 2026-07-31)
**Implementation Status**: Fully implemented (mechanism); art/audio content and full Mission HUD wiring partially deferred (see §6/§7)
---

> **⚠️ Reverse-Documentation Notice**
>
> This design document was created **after** the implementation already existed.
> It captures current behavior and clarified design intent based on code analysis
> and user consultation. Some sections may be incomplete where implementation is
> partial or design intent was unclear during reverse-engineering.

---

## 1. Overview

**Purpose**: "The Gap" is the project's first and (as of this writing) only assembled mission — the Vertical Slice content instance that exercises the full Foundation+Core stack (Grid, Pathfinding, EventBus, Save & Persistence, Wave Manager, Monster, Tower, Hero, Damage & Status) as one real, playable scene rather than isolated unit/integration tests.

**Scope**: This document covers the *content and scene-assembly* layer specifically — the actual map, the actual 6-wave composition, and the deliberate scope decisions/stopgaps made to get a playable mission running before several dependency systems (Mission Select, Resource Economy's non-debug gold, a real `HeroResource` pipeline, full Mission HUD) existed. It does **not** re-document the underlying systems themselves (Wave Manager's FSM, Grid's cell model, Hero's combat formulas) — those already have their own GDDs (`wave-manager.md`, `grid-system.md`, `hero.md`, etc.); this doc only covers what's specific to *this* mission's content and its scene.

**Current Implementation**: Fully wired and playable. `the_gap.tscn` assembles Grid, MonsterManager, TowerSystem, DamageStatus, Hero, Camera2D, MissionHUD, PauseMenu, and a debug overlay into one scene; `the_gap.gd` builds the map layout programmatically and auto-launches the mission after a 1s delay (no Mission Select System exists yet).

**Design Intent** (clarified):
- Prove the core fantasy beat from `production/vertical-slice-target.md`: *"the hero covers the gap the towers couldn't, and the wave that seemed overwhelming collapses."*
- Deliberately scoped down from that document's original two-lane "Wave 2 opens an uncovered side lane" twist to a **single winding lane** for MVP — confirmed intentional (2026-07-31): the single-lane version still tests "hero covers what towers miss" (via escalating wave composition/difficulty rather than a second geometric path) without the added pathfinding/spawn-assignment complexity of a second lane. The two-lane twist remains a candidate for a later slice, not abandoned.
- Every dependency gap this mission hit (no Mission Select, no `HeroResource` pipeline, no Resource Economy content gold, Mission HUD still Skeleton at authoring time) was worked around with an explicit, code-commented stopgap rather than blocking on those systems — consistent with this project's "mechanism real, content/dependency placeholder" convention used elsewhere (Diorama, Music/Ambient Story 002).

---

## 2. Detailed Design

### 2.1 Core Mechanics

**Map Layout** (`the_gap.gd::_build_grid_config()`):
- **Description**: A 16×12 grid (`GRID_COLS`/`GRID_ROWS`), one `SPAWN` cell at `(0,6)`, one `GOAL` cell at `(15,6)`, a single hand-authored orthogonal path connecting them via 7 line segments (a winding route: right, up, right, down, right, up, right), all border cells `BLOCKED`, everything else `PLACEABLE`.
- **Implementation**: Built programmatically in `_build_grid_config()` (not authored as a `.tres` — see §2.3) and passed to `GGrid.initialize()`. `cell_size = 64.0`, matching `grid-system.md`'s now-fixed project-wide constant (OQ-4 resolution, per `systems-index.md`).
- **Design Rationale**: The winding path (rather than a straight line) forces the player to consider tower placement/range coverage across multiple path segments during Scout, and creates natural "corner" chokepoints — closer to real tower-defense map design than a straight corridor, without needing the deferred second lane to create positioning tension.
- **Player-Facing**: The player sees the full path before Wave 1 (visible via `GridVisual`'s baked texture), places towers during a 60s Scout phase (per Wave Manager's FSM), then watches monsters path along it in real time.

**Wave Composition** (`the_gap_waves.tres`, `WaveConfig`/`WaveScript`/`WaveSpawnEntry` resources from Wave Manager Story 006):
- **Description**: 6 waves, entirely `goblin_runner` through wave 3, introducing one `forest_troll_elite` in wave 4, an **ELITE-only** wave 5 (4× `forest_troll_elite`), and a final wave 6 that mixes runners/elites and ends in exactly one `goblin_warlord_boss`.
- **Implementation**: A real authored `.tres` asset (not test-fixture data) — the actual instance of `wave-manager.md`'s Rule 6 content constraint ("penultimate wave N-1 is ELITE-only for N≥5; final wave ends in exactly one BOSS entry"). This is the first (and currently only) real content proving that formula in a shipped mission.
- **Design Rationale**: Ramps difficulty gradually (runner-only → mixed → elite gauntlet → boss finale) so the escalation itself — not a second uncovered lane — is what tests whether the player's tower coverage holds and where the hero needs to personally intervene.
- **Player-Facing**: Wave difficulty visibly escalates; the player learns early waves are towers-sufficient, then feels the elite/boss waves demand active hero engagement — this is the single-lane version's substitute for the originally-designed geometric "gap."

**Mission win/loss** (delegated entirely to Wave Manager / Hero — this scene does not implement its own win/loss logic):
- **Description**: `MISSION_COMPLETE` on defeating/surviving all 6 waves; `DEFEAT` on Hero HP reaching 0 (per `hero.md`'s lifecycle) or the breach threshold being hit (per `wave-manager.md`).
- **Implementation**: Purely emergent from the already-tested Wave Manager FSM and Hero lifecycle systems reacting to real gameplay in this scene — Story 008's own scope note is explicit that this story is "scene-assembly + integration verification, not new gameplay logic."
- **Player-Facing**: Standard win/fail flow; a `RetryButton` exists in the HUD (currently `visible=false` by default, wired to Mission Select's `retry_current_mission()` per `mission-select.md`).

### 2.2 Rules and Formulas

No new formulas are introduced by this mission — it is a pure content/assembly instance of formulas already owned by other GDDs.

| Formula | Expression | Purpose | Verified? |
|---------|-----------|---------|-----------|
| Wave Manager Rule 6 (penultimate-ELITE / final-BOSS) | wave N-1 = ELITE-only (N≥5); wave N ends in exactly 1 BOSS | Content-authoring constraint | ✅ — this mission's 6-wave data is the concrete proof instance |
| Grid `cell_size` constant | `64.0` | World-to-cell coordinate conversion | ✅ — matches `grid-system.md`'s OQ-4-resolved fixed constant |

**Clarifications**: None — no formula drift found between this content and its owning GDDs.

### 2.3 State and Data

**Data Structures** (from code/assets):
- `assets/data/missions/the_gap.tres` (`MissionResource`): `mission_id`, `objective_text` — minimal, used for display/identification.
- `assets/data/missions/entries/the_gap_entry.tres` (`MissionEntry`): `mission_id`, `display_name`, `grid_config` (a real serialized `GridConfig` — **note**: this duplicates the exact same layout `the_gap.gd::_build_grid_config()` builds programmatically at runtime; see §7 Open Question), `wave_config_path`, `base_wave_count = 6`. This is the Mission Select System's own data shape (per `mission-select.md`), authored for this mission even though Mission Select isn't wired into this scene yet.
- `assets/data/waves/the_gap_waves.tres` (`WaveConfig` → `WaveScript` → `WaveSpawnEntry`): the 6-wave composition described in §2.1.

**State Machines**: None owned by this mission — it consumes Wave Manager's `SCOUT → PRE_WAVE → WAVE_ACTIVE → INTERMISSION (repeat) → MISSION_COMPLETE/DEFEAT` FSM verbatim (see `wave-manager.md` for the authoritative state table).

**Persistence**: This mission's own map/wave data is static content, not saved player state. The Hero, Tower placements, and mission economy state that accrue *during* a playthrough are persisted via their owning systems' existing `SaveRestorer` registrations (see `save-persistence.md`) — this scene adds no persistence logic of its own.

### 2.4 Integration Points

**Dependencies** (systems this mission's scene wires together):
- **Grid**: cell layout, tower occupancy — configured via `GGrid.initialize(config)`.
- **Pathfinding**: implicitly, via Grid's SPAWN/GOAL/PATH cell types (Monster System consumes this).
- **Wave Manager**: drives the entire phase FSM from the real `the_gap_waves.tres` data.
- **Monster System / Tower System**: self-populate their blueprint lookups from `GGameDataRegistry` at `_ready()` (no scene-local data wiring needed, per TD-data-001's closure).
- **Hero**: placed at `(2,6)` world position; stats hardcoded as a documented stopgap (§2.1's Design Rationale, deviation #3 in `the_gap.gd`'s class doc comment) pending a real `HeroResource` pipeline.
- **Damage & Status**: instanced as a plain scene node (`DamageStatus`) — required per `ADR-0002`'s "every mission scene instances this" rule; its absence was a real bug found and fixed during Story 008 (`TD-damage-001`).
- **Mission HUD**: instanced as a real, self-wiring `CanvasLayer` node (see §7 Open Question — coexists with a now-likely-redundant debug overlay).
- **PauseMenu / InputModeTracker**: standard scene-level UI wiring, no mission-specific logic.

**Dependents**: None within the game itself — this is a leaf content asset. Downstream *tooling* dependents: `tests/integration/mission_scene/mission_scene_the_gap_test.gd` (13/13 passing, Story 008's own test evidence), `production/qa/evidence/the-gap-mission-scene-evidence.md`, S4-10's 100-agent pathfinding stress test, and every smoke-check/playtest session referenced in `production/session-state/active.md` all boot through this specific scene as the project's only real integration surface.

**API Surface**: This scene exposes no public API of its own — it's a leaf content assembly, not a reusable system.

---

## 3. Edge Cases

**Handled in Code**:
- ✅ Grid-visual `configure()` dispatch failure (typo'd/renamed method): guarded via `has_method()`, fails loudly with `push_error()` rather than silently no-oping.
- ✅ Monster reparenting into `MonstersContainer`: uses `reparent()` not `add_child()` since `MonsterManager` already parents entities at spawn time (post-`TD-monster-003` fix) — using `add_child()` here would error.
- ✅ Debug gold seed timing: `resources_changed.emit(500, ...)` fires *after* `mission_launched` specifically because `GMissionEconomy` resets balance to 0 on `mission_launched` — seeding before launch would be silently wiped.
- ✅ DEFEAT-only debug hero-kill: gated behind `debug_controls_enabled` (default `false`) so a real human playtester never triggers a false "instant death, no visible cause" bug report.

**Not Yet Handled** (discovered during analysis):
- ⚠️ The debug HUD overlay (`HUD/Panel/VBox`, driven directly by `the_gap.gd`'s `_on_mission_phase_changed()`/`_on_wave_started()`/`_on_wave_completed()` handlers) coexists with the real, fully self-wiring `MissionHUD` node also present in the scene. Mission HUD was Skeleton status when this scene was built (Story 008 explicitly scoped it out); it has since been substantially implemented (`systems-index.md` row 23, now Vertical Slice tier). The debug panel looks like dead leftover scaffolding rather than a still-needed fallback — not fixed as part of this doc since removing it is a code change, not a documentation task.

**Unclear** (need user clarification):
- ❓ None remaining — the single-lane vs. two-lane scope question was clarified during this session (see §1 Design Intent).

---

## 4. Dependencies

**Technical Dependencies**:
- Godot 4.6.2 — no post-cutoff API risk found in this scene's own code (deliberately avoids `TileMap`/`TileSet` per `grid_visual.gd`'s own doc comment, citing this project's tracked 4.4–4.6 API-change risk).

**Design Dependencies** (other design docs):
- `production/vertical-slice-target.md` — the original design pitch this mission was built to prove; this doc's §1 documents where the shipped scope diverges (single lane vs. the pitch's two-lane twist) and why.
- `wave-manager.md`, `grid-system.md`, `hero.md`, `tower.md`, `monster.md`, `damage-status.md` — this mission is a pure consumer of all six; no new rules introduced.
- `mission-select.md` — `the_gap_entry.tres` is authored in Mission Select's own data shape even though Mission Select isn't wired into this scene yet (auto-launch stopgap in its place).
- `mission-hud.md` — partially superseded in practice by the real `MissionHUD` node now present in the scene (see §7).

**Content Dependencies**:
- No real art/audio exists for this mission — monsters render as colored `ColorRect` placeholders (`_color_for_monster()`), the grid renders as a flat-color baked texture, Hero uses a placeholder visual. Consistent with the project-wide "no real content yet" convention (OQ-2 audio, Epic 10 Story 013's art gap, etc.) — not a defect specific to this mission.

---

## 5. Balance and Tuning

**Current Values** (as implemented):

| Parameter | Current Value | Rationale | Needs Tuning? |
|-----------|--------------|-----------|---------------|
| Grid size | 16×12 | Matches `grid-system.md`'s stated default | ✅ |
| Hero base stats (debug stopgap) | 500 HP / 25 dmg / 220 move speed / 220 range / 0.1 crit / etc. | Chosen only to avoid shipping the Hero at 0 HP — never balance-tuned against real wave difficulty | ⚠️ needs a real pass once `HeroResource` exists |
| Debug starting gold | 500 | Arbitrary debug value, not derived from Resource Economy's real faucet formula | ⚠️ superseded once Resource Economy content gold is wired here |
| Wave 2 monster count (vertical-slice-target.md's own open question) | N/A — no longer applicable | The original target doc's "~12–15 monsters split across two lanes" open question doesn't apply to the shipped single-lane design | N/A — resolved by the scope decision itself |

**Balance Concerns Identified**:
- ⚠️ Hero base stats and starting gold are explicitly acknowledged debug stopgaps, never validated against the real 6-wave difficulty curve by a balance pass — `production/vertical-slice-target.md`'s own AC ("hero can reach the gap and meaningfully affect the outcome") has never been confirmed with tuned, non-debug values.

**Recommended Balance Pass**:
- Run `/balance-check` once a real `HeroResource` pipeline and Resource Economy content-gold wiring both exist for this mission.
- The still-outstanding human playtest (Epic 10 Story 014 / the never-run `production/playtests/sprint-04-the-gap-playtest.md` sessions) is this mission's actual intended validation mechanism — not a balance-formula check.

---

## 6. Acceptance Criteria

*Cross-referenced against Story 008's own 8 ACs (all Complete per its Completion Notes) and `production/vertical-slice-target.md`'s ACs:*

**What Exists** (implemented):
- ✅ Real `.tscn` scene with TileMap-equivalent grid, Hero, Grid config, tower-placement input
- ✅ Real `WaveConfig` asset authored per Wave Manager's content constraints
- ✅ Full SCOUT → PRE_WAVE → WAVE_ACTIVE → INTERMISSION (×N) → MISSION_COMPLETE loop, live-verified
- ✅ Hero-death → DEFEAT transition, live-verified
- ✅ Real monster spawning/pathing via real Grid/Pathfinding data
- ✅ Real Hero combat (auto-attack, tower affinity) against real monsters
- ✅ Debug/HUD overlay showing phase/wave/timer (now duplicated by a real Mission HUD — see §3)
- ⚠️ Performance budget compliance — measured (60 FPS, draw calls fixed from 387→4 via `TD-render-001`), but only on this dev environment, not the physical reference-spec machine (`production/qa/reference-hardware.md`'s own tracked gap)

**What's Missing** (not yet implemented):
- ❌ The original two-lane "Wave 2 opens an uncovered side lane" twist from `vertical-slice-target.md` — deliberately deferred (§1), not a defect
- ❌ Real art/audio content — tracked project-wide, not mission-specific
- ❌ Human playtest validation (`vertical-slice-target.md`'s own ACs around "a human plays without guidance" and "describes the win as 'I covered the gap myself'") — genuinely never run; see `production/playtests/sprint-04-the-gap-playtest.md`
- ❌ Non-debug Hero stats / non-debug starting gold

**Definition of Done** (when is this mission's content "complete"?):
- [x] Playable end-to-end via debug auto-launch
- [x] Wave content matches Wave Manager's authoring constraints
- [ ] Wired through a real Mission Select flow instead of debug auto-launch
- [ ] Hero stats and starting gold sourced from real systems instead of hardcoded stopgaps
- [ ] At least one real human playtest session recorded and signed off

---

## 7. Open Questions and Follow-Up Work

### Questions Needing User Decision
1. **`the_gap_entry.tres`'s duplicated grid layout**: `assets/data/missions/entries/the_gap_entry.tres` serializes the exact same 16×12 cell layout that `the_gap.gd::_build_grid_config()` also builds programmatically at runtime. These are two independent sources of truth for the same map — a future edit to one (e.g. tuning the path) would silently desync from the other unless both are updated. Is the `.tres` version meant to eventually *replace* the programmatic version once Mission Select is wired in (i.e. the programmatic builder is a temporary stopgap), or should the programmatic builder be refactored now to read from the `.tres` instead of duplicating it?
   - Option A: Leave as-is until Mission Select wiring happens (then the programmatic builder gets deleted wholesale) — no near-term action needed.
   - Option B: Refactor `the_gap.gd` now to load `the_gap_entry.tres`'s `grid_config` instead of building it inline, closing the duplication risk immediately.

2. **Debug HUD overlay vs. real Mission HUD**: should `the_gap.tscn`'s leftover `HUD/Panel/VBox` debug overlay be removed now that a real, self-wiring `MissionHUD` covers the same information (and more)? (See §3.)

### Flagged Follow-Up Work
- [ ] Resolve Q1 (grid-layout duplication) per whichever option is chosen above
- [ ] Remove the redundant debug HUD overlay once confirmed the real Mission HUD fully covers phase/wave/timer/help-text display
- [ ] Wire this mission through a real Mission Select flow once that system is implemented, replacing the 1s auto-launch timer
- [ ] Replace hardcoded Hero stats with a real `HeroResource` once that pipeline exists
- [ ] Replace the 500-gold debug seed with real Resource Economy content-gold flow
- [ ] Run the still-outstanding human playtest sessions (`production/playtests/sprint-04-the-gap-playtest.md`) — this mission's actual intended validation, not yet performed
- [ ] Re-measure performance on the physical reference-spec machine per `production/qa/reference-hardware.md`
- [ ] If/when a later slice revisits the original two-lane twist, this doc's §1 should be updated to point at wherever that gets built

---

## 8. Version History

| Date | Author | Changes |
|------|--------|---------|
| 2026-07-31 | Claude (reverse-doc) | Initial reverse-documentation from `src/gameplay/missions/the_gap/` + related data assets |
| 2026-07-31 | User | Confirmed single-lane vs. two-lane scope reduction was deliberate, not an oversight |

---

**Next Steps**:
1. Decide Q1 (grid-layout duplication) and Q2 (redundant debug HUD) above
2. Run the human playtest sessions this mission has been waiting on since Sprint 4
3. Revisit hardcoded Hero-stats/gold stopgaps once their owning systems (`HeroResource` pipeline, Resource Economy content gold) exist

**Related Skills**:
- `/balance-check` — once real Hero stats/gold replace the debug stopgaps
- `/qa-plan` — the still-outstanding human playtest sessions
- `/code-review` — if Q1/Q2 above are acted on

---

*This document was generated by `/reverse-document design src/gameplay/missions`*
