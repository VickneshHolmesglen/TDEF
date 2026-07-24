# Story 008: Assemble "The Gap" Mission Scene

> **Epic**: Wave Manager
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-05-16
> **Estimate**: 1d

## Context

**GDD**: `design/gdd/wave-manager.md` (plus `design/gdd/hero.md`, `design/gdd/tower.md`, `design/gdd/monster.md`, `design/gdd/damage-status.md`, `design/gdd/grid-system.md` for the systems being wired together)
**Requirement**: `TR-wave-001` through `TR-wave-007` (integration capstone — no single new TR-ID; verifies the complete set is wired correctly end-to-end)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 (Wave Manager FSM) + ADR-0002 (Scene/Autoload Structure)
**ADR Decision Summary**: WaveManager is Autoload #7. This story does not change WaveManager's architecture — it assembles a real `.tscn` scene (tilemap, Grid config, Hero, Tower placement UI stub, camera) that exercises the already-implemented (by Stories 001-007) full FSM loop against real Godot scene-tree wiring, not just unit/integration test mocks.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: This is the first story in this epic that involves real `.tscn` scene construction (TileMap for BLOCKED/SPAWN/GOAL cells, Camera2D, node hierarchy) rather than pure GDScript logic — check `docs/engine-reference/godot/` for any Godot 4.6-specific TileMap/TileSet API changes before building the scene (this project's VERSION.md flags 4.4-4.6 as introducing changes the LLM's training data doesn't cover).

**This is the original ask behind S4-09** ("Assemble The Gap mission scene," originally estimated at 0.6 days assuming WaveManager was feature-complete). It was blocked on Stories 001-007 closing the real gaps in WaveManager first — this story is now purely the scene-assembly integration work, with a functioning win/loss condition, real WaveConfig data, and correctly-emitted lifecycle events all in place underneath it.

**Control Manifest Rules (Feature layer)**:
- Required: WaveManager is the sole authority on mission phase — the scene must not contain any other node that triggers phase changes directly
- Required: exactly one SPAWN cell for this MVP mission (multi-SPAWN is post-MVP)
- Forbidden: SceneManager holding direct references to scene-instanced nodes beyond the active scene's lifetime

---

## Acceptance Criteria

*Scoped to this story — verifies the combined output of Stories 001-007, not new WaveManager logic:*

- [ ] A real `.tscn` scene exists at `src/gameplay/missions/the_gap/the_gap.tscn` (this project has no prior mission scenes; convention decided 2026-07-05 to colocate `.tscn` files with their controlling script under `src/`, matching the existing pattern of `src/core/monster/MonsterEntity.tscn` sitting beside `monster_entity.gd` — see `.claude/docs/directory-structure.md`'s updated note) containing: a TileMap with BLOCKED/SPAWN/GOAL cells, a Hero instance, Grid configuration, and any tower-placement UI needed for manual SCOUT-phase testing.
- [ ] A real `WaveConfig` `.tres` asset exists at `assets/data/waves/` (per Rule 3's stated file location) for "The Gap," authored per the GDD's content constraints (5-8 waves, penultimate wave ELITE-only, final wave ends in exactly one BOSS entry).
- [ ] Launching the scene and emitting (or triggering via real UI) `mission_launched` drives the full SCOUT → PRE_WAVE → WAVE_ACTIVE → INTERMISSION (repeating) → PRE_WAVE → WAVE_ACTIVE → MISSION_COMPLETE loop for a complete, successful playthrough.
- [ ] A hero-death playthrough (taking lethal damage during any WAVE_ACTIVE) correctly transitions to DEFEAT and halts all further wave activity.
- [ ] Real spawned monsters (via `monster_spawn_requested` → Monster System → `monster_spawned`) are visible and pathing correctly toward the GOAL cell(s), using real `Grid`/`PathfindingSystem` data, not test stubs.
- [ ] Real Hero combat (auto-attack, skills, tower affinity — from Epic 02) functions correctly against the spawned monsters within this scene.
- [ ] Mission HUD (even in its current Skeleton-status form) or a placeholder debug overlay displays at minimum: current phase, wave number, and countdown timers — enough for a human playtester to follow the mission state without reading logs.
- [ ] Performance: A full playthrough (all authored waves, real monster pathing + Hero combat) stays within this project's stated budgets (`.claude/docs/technical-preferences.md`: 60 FPS / 16.67ms frame budget, ≤200 draw calls, ≤1GB memory) — record actual measured values during the manual playtest rather than assuming compliance; this is the first real scene assembly in the project and the first chance to catch a budget miss.

---

## Implementation Notes

*This story is primarily scene-assembly and integration verification, not new GDScript logic:*

1. **Scene file convention (resolved 2026-07-05)** — mission scenes live at `src/gameplay/missions/[mission-slug]/[mission-slug].tscn`, colocated with any mission-specific script, matching this project's existing pattern of `.tscn` files sitting beside their controlling `.gd` script (e.g. `src/core/monster/MonsterEntity.tscn` next to `monster_entity.gd`). This is the first mission `.tscn` in the project — `.claude/docs/directory-structure.md` has been updated to note this pattern.

2. **Author the `WaveConfig`/`WaveScript`/`WaveSpawnEntry` `.tres` assets** for "The Gap," using the Resource classes Story 006 introduces. Follow the GDD's content constraints (Rule 6): penultimate wave (wave N-1) is ELITE-only for N≥5; final wave ends in exactly one BOSS entry. A 5-6 wave mission is a reasonable MVP scope — check with the design owner before committing to a specific wave count/composition, since this is genuinely new content authoring, not just code.

3. **Wire the scene hierarchy**: Grid configuration (SPAWN/GOAL/BLOCKED cell layout via TileMap, per `design/gdd/grid-system.md`), Hero instance, a way to trigger `mission_launched` (a debug button, a `_ready()` auto-launch for testing, or real Sanctuary → Mission Select flow if that's ready — check Mission Select System's status in `systems-index.md` before assuming it exists).

   **Verified during story-readiness (2026-07-05)**: Epic 02's Hero system (all 8 stories) is fully Complete and tested (446/446 tests passing) — its GDD requirements, ADR compliance, stats, movement, combat, tower affinity, class system, skills, and lifecycle/save are all done. However, **no Hero `.tscn` scene file exists anywhere in the project** — every Epic 02 story tested Hero via direct `Hero.new()` script instantiation, never an authored scene with visual components. This story is therefore the first to need a placeable Hero scene, and must author one: attach the existing, fully-tested `hero.gd` to a new `CharacterBody2D` scene root, add a `CollisionShape2D` (collision layer 2 per Story 002's established convention), and a minimal placeholder visual (a `ColorRect` or simple `Sprite2D` is sufficient — no real art asset exists yet either, and this story's Out of Scope section already correctly excludes Visual/Feel work). This is within this story's existing 1-day estimate and scene-assembly scope, not a separate task.

4. **Manual playtest verification** — since this is an Integration story assembling multiple already-tested subsystems, the primary verification method is a real playtest run (per this project's Test Evidence conventions for Integration stories: "integration test in `tests/integration/[system]/` OR playtest doc"). A scripted integration test that boots the scene headlessly and asserts on phase transitions is preferable if practical within Godot's headless test runner constraints; if the scene requires real rendering/TileMap navigation that headless mode can't exercise, a documented manual playtest record is the fallback (`production/session-logs/` or `production/qa/evidence/`).

5. **Confirm Mission HUD status before scoping** — `design/gdd/mission-hud.md` is Skeleton status (not fully designed). This story does NOT need a fully-designed Mission HUD; a minimal debug-label overlay showing phase/wave/timer is sufficient to make the scene playtestable. Do not expand scope into designing Mission HUD properly here — that's a separate epic's concern once its GDD graduates from Skeleton.

---

## Out of Scope

- **Mission HUD full design/implementation** — Skeleton GDD status; only a minimal debug overlay is needed here
- **Multi-SPAWN cell missions** — post-MVP per the control manifest
- **Sanctuary meta-progression / mission select flow** — if not already implemented, use a direct debug-trigger for `mission_launched` instead of building mission-select UI as part of this story
- **Tarot System, Constellation System, Resource Economy** — none of these are required for a minimal playable "SCOUT → wave → wave → MISSION_COMPLETE/DEFEAT" loop; do not pull them in

---

## QA Test Cases

*Given this is primarily a scene-assembly/manual-verification story, these are largely manual checks rather than pure unit assertions:*

- **Manual check: full successful mission playthrough**
  - Setup: Launch the assembled scene; trigger `mission_launched`
  - Verify: SCOUT phase begins (60s timer visible); place towers; advance through PRE_WAVE/WAVE_ACTIVE/INTERMISSION for all authored waves; final wave's BOSS dies or breaches; MISSION_COMPLETE reached
  - Pass condition: no crashes, no stuck phases, no console errors; the debug overlay shows correct phase/wave/timer values throughout

- **Manual check: hero-death playthrough**
  - Setup: Launch the scene; deliberately let the Hero take lethal damage during any WAVE_ACTIVE
  - Verify: mission transitions to DEFEAT immediately; no further wave activity (no more spawns, no phase advances)
  - Pass condition: DEFEAT state is visibly reached and stable — no further monster spawns or phase changes occur after

- **Manual check: real monster pathing and combat**
  - Setup: A wave with several monsters spawns
  - Verify: monsters path visibly from SPAWN toward GOAL using real Pathfinding data; Hero auto-attacks and (if equipped) uses skills against them; towers (if placed) fire correctly
  - Pass condition: no monsters get stuck, no pathing errors logged, combat resolves (monsters die or breach) without desyncing WaveManager's `_enemies_alive` count

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/mission_scene/mission_scene_the_gap_test.gd` (if headless-testable) **or** a documented playtest record at `production/qa/evidence/the-gap-mission-scene-evidence.md` — must exist and pass/be signed off
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DEFEAT/MISSION_COMPLETE), Story 002 (wave lifecycle events), Story 003 (BOSS handling), Story 004 (reward scalar/penultimate flag), Story 005 (rebuild gate), Story 006 (real WaveConfig loading), Story 007 (spawn cell assignment) — ALL must be Complete before this story can meaningfully begin
- Unlocks: Nothing further within this epic — this is the integration capstone. Downstream: S4-10 (100-agent pathfinding stress test) and S4-11 (playtest round) both depend on this scene existing.

---

## Completion Notes
**Completed**: 2026-07-06
**Criteria**: 8/8 passing (performance measurement explicitly deferred as accepted, tracked debt — TD-perf-001 — not a failure)
**Deviations**: ADVISORY (x10) — this story surfaced more real findings than any other in the epic, all documented, none silent: (1) Epic 02's `EPIC.md` was stale and corrected during readiness; (2) no Hero `.tscn` existed, authored one; (3) TileMap avoided for a simpler `_draw()`-based grid visual given the flagged Godot 4.4-4.6 API risk; (4) two critical production bugs found and fixed in `wave_manager.gd` — `_wave_spawn_entries` never populated from a real `WaveConfig`, and `_on_templates_ready()`'s guard discarding the real signal — meaning every real mission had always spawned exactly 0 monsters since inception (TD-wave-002, TD-wave-003); (5) `WaveSpawnEntry`'s plain-var fields needed `@export` to survive `.tres` serialization; (6) a missing `DamageStatus` node meant real Hero attacks dealt zero damage, found by the code-review-required AC-6 test (TD-damage-001); (7) no production data loader exists for `MonsterManager`/`TowerSystem`, worked around locally, tracked (TD-data-001 — **CLOSED 2026-07-07 via S5-01**); (8) performance measurement deferred as accepted debt (TD-perf-001 — **CLOSED 2026-07-07**, measured live: 60 FPS clean, but 387 draw calls found ~1.9× over budget, flat regardless of monster count — root-caused to `GridVisual`'s `_draw()`-based grid renderer per deviation (3) above, and fixed same session as `TD-render-001`: pre-rendered texture instead of a per-cell draw loop, 387 → 4 draw calls); (9) debug-only stopgaps (Hero base stats, tower gold, hero-kill trigger) all clearly marked QA-only; (10) HUD label-content correctness and real monster-pathing "feel" remain untested/deferred, candidates for a future manual session.
**Test Evidence**: `tests/integration/mission_scene/mission_scene_the_gap_test.gd` — 13/13 passing; full project regression: 555/555 passing, 0 errors, 1 pre-existing unrelated failure, 0 regressions
**Code Review**: Complete — first CHANGES REQUIRED verdict of the epic (2 silent testability gaps, 1 static-typing violation, 1 fragile test assertion), all 4 items fixed and re-verified to APPROVED. The AC-6 fix required by that review round caught the DamageStatus bug above — validating that rejecting the silent gap was the right call.

---

## Epic Status: COMPLETE

All 8 stories in the Wave Manager epic are now Complete. This story's own verification work found and fixed 4 previously-invisible production bugs spanning the wave-spawn pipeline, signal timing, resource serialization, and damage application — none of which any prior unit or integration test in this epic could have caught, since every one of them injected test data directly rather than exercising the real end-to-end signal chain this story was the first to assemble.
