# QA Evidence: Hero Visual Companion (Epic 15 Story 005)

**Story**: `production/epics/epic-15-3d-visual-presentation/story-005-hero-visual-companion.md`
**ADR**: `docs/architecture/adr-0037-visual-presentation-3d-companion-layer.md`
**Date**: 2026-08-20
**Status**: PARTIAL — AC-1, AC-2, AC-3 have real automated coverage (below). AC-4 (live visual
tracking) and AC-5 (live `CharacterBody2D`-specific observation) are **DEFERRED** pending a
human/live-rendered session — see "Deferred checks" below. No fabricated numbers or screenshot
evidence in this document.

---

## Automated coverage (this session)

`tests/integration/visual_presentation/hero_visual_companion_test.gd` exercises the real `Hero`
class headless, driving the actual `_ready()`/`_physics_process()` (not the sync method called in
isolation, except where explicitly noted):

| AC | Test(s) | What it proves |
|---|---|---|
| AC-1 (companion + real mesh resolution) | `test_ready_creates_visual_companion_with_a_real_node3d_mesh_child`, `test_ready_seeds_companion_at_correct_position_before_any_sync_call` | `Hero._ready()` builds a `VisualCompanion3D` `Node3D` holding one real `Node3D` mesh, resolved through the live `GGameDataRegistry` boot path against the shipped `assets/data/visual_meshes/hero.tres` mapping, correctly positioned from the very first visible frame (no one-frame lag). |
| AC-2 (`map_to_3d()` sync, no new callback) | `test_position_sync_tracks_map_to_3d_across_multiple_physics_process_frames`, `test_position_sync_tracks_correctly_through_a_direction_change`, `test_hero_script_declares_exactly_one_process_and_one_physics_process`, `test_physics_process_body_calls_the_visual_companion_sync` | Companion position exactly matches `VisualMath.map_to_3d(hero.global_position, 0.0)` across 10 real `Hero._physics_process()` frames of actual movement, including a mid-movement direction change, driven entirely through the real wiring (not the sync method called in isolation). A direct source-text scan of `hero.gd` confirms exactly ONE `_process()` and exactly ONE `_physics_process()` declaration (both pre-existing) — this story added a line to the existing `_physics_process()`, not a second competing callback — and a second scan confirms the sync call (`_sync_visual_companion_position()`) is textually inside that one `_physics_process()` body, not merely present elsewhere in the file. |
| AC-3 (no invariant regression) | Verified by re-running the project's existing Hero test suites (`tests/unit/hero/*`, `tests/integration/hero/*` — stat resolution, tower affinity, movement, lifecycle, class proximity, combat formula, auto-attack, lifesteal, skill system) after this story's change — see "Existing suite regression check" below. |

All 7 tests in this new suite are headless-executable and deterministic (no `await`/async needed —
`Hero._ready()`/`_physics_process()` are driven synchronously, matching this file's own fixture
pattern reused from `tests/integration/hero/hero_movement_test.gd`).

### Existing suite regression check

Ran `tests/unit/hero/*` and `tests/integration/hero/*` (9 suites: `hero_stat_resolution_test.gd`,
`hero_tower_affinity_test.gd`, `hero_auto_attack_test.gd`, `hero_lifesteal_test.gd`,
`hero_skill_system_test.gd`, `hero_movement_test.gd`, `hero_lifecycle_test.gd`,
`hero_class_proximity_test.gd`, `hero_combat_formula_test.gd`) after this story's change (adding
`_visual_companion`, `HERO_MESH_ENTITY_ID`, `HERO_LAYER_HEIGHT`, `_build_visual_companion()`,
`_sync_visual_companion_position()`, one call in `_ready()`, one call in `_physics_process()`) via
the project's real gdUnit4 CLI runner against the pinned `Godot_v4.6.2-stable_win64.exe` binary —
result: **119/119 test cases passed, 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans**. No
existing test was modified. `Hero`'s stat resolution, movement/collision (Rule 26/27), grid-cell
position tracking (Rule 28), Tower-Synced Class proximity, auto-attack, lifesteal, skill system, and
lifecycle/death/save behavior are all unaffected by this story's purely-additive change.

---

## Deferred checks (require a human with a live/rendered session)

**AC-4 (live visual tracking, gameplay observation)**
- Requires a human (or a live Godot MCP `run_project` + `take_screenshot` session) watching the
  Hero move across the mission area and visually confirming the 3D companion tracks it with no
  lag/jitter across several seconds of movement, including direction changes.
- **DEFERRED** — not producible without a live rendered session. The automated
  `test_position_sync_tracks_map_to_3d_across_multiple_physics_process_frames` and
  `test_position_sync_tracks_correctly_through_a_direction_change` tests above prove the underlying
  **math** is exact (companion position equals `map_to_3d()`'s output every single frame, including
  through a direction change, not just eventually-consistent) — what remains unverified is purely
  the *visual* experience (does it read as smooth movement, does the placeholder crystal mesh's
  scale/orientation look reasonable standing in for the Hero), which is exactly the kind of thing
  this project's own established practice (Stories 003/004's own evidence docs) treats as
  screenshot-only, not derivable from position math alone.

**AC-5 (`CharacterBody2D`-specific live observation — this story's own specifically-called-out
verification target)**
- Requires a human/live session watching the Hero walk into an obstacle and confirming no visual
  anomaly correlates with the collision-resolution event (e.g. a companion pop/jitter/desync at the
  moment `move_and_slide()` stops the hero).
- **PARTIALLY covered by automation, live-observation portion still DEFERRED**: the automated
  `test_position_sync_remains_correct_after_move_and_slide_collision_stop` test drives a real
  `StaticBody2D` obstacle (same fixture mechanism as `hero_movement_test.gd`'s own Rule 27 tests)
  through 120 real `_physics_process()` frames and confirms (a) the Hero is genuinely stopped by
  collision (not a fixture artifact — same assertion style as the existing Rule 27 tests) and (b)
  the companion's position exactly matches `map_to_3d()` of the Hero's *actual, collision-truncated*
  `global_position` after settling against the obstacle — i.e. the math does not desync at the
  moment of collision. What automation cannot confirm is the *visual* read of that moment (does the
  mesh appear to "snap" or "judder" on-screen during the collision frame itself, which position-only
  assertions cannot detect) — that requires the same live/rendered session as AC-4.
- **No `CharacterBody2D`-specific engine quirk was found** during implementation or automated
  testing. The mixed `CharacterBody2D`-root/`Node3D`-child pattern behaved identically to the
  `Node2D`/`Area2D` cases already proven by Stories 002-004: `move_and_slide()`'s internal collision
  resolution is entirely 2D (`Node2D`-family) and has no interaction with the sibling `Node3D`
  subtree — `_visual_companion` is just another child node under the `CharacterBody2D` root,
  unaffected by physics-body-specific processing. This closes the story's own stated open question
  ("confirm the mixed-root pattern holds for a `CharacterBody2D` root specifically") at the
  automated-testing level; the live-visual-read portion of that confirmation remains deferred per
  above.

---

## Deviations / judgment calls

- **Mesh choice**: `detail-crystal.glb` (one of the "Tower Defense Models" pack's standalone
  detail pieces) was used as the placeholder mesh for `&"hero"`. This asset pack ships no
  character/humanoid model at all — confirmed by a full directory survey during implementation (it
  contains terrain tiles, tower-kit pieces, UFO-enemy pieces, and siege-weapon pieces only). A
  distinct, non-tower/non-monster placeholder was deliberately chosen (not reusing
  `tower_round.tres`/`enemy_ufo_a.tres`) so the Hero's companion is visually distinguishable from
  towers and monsters during Phase 1 verification, consistent with Stories 003/004's own explicit
  "one shared placeholder proves the pipeline, not final art" framing (real hero art is Phase 6,
  a separate future content-authoring pass — this story's own Out of Scope section already excludes
  any equipment/gear visual representation, which reinforces that body art itself is similarly not
  this story's concern).
- **Build-time hook**: `_build_visual_companion()` is called once from `Hero._ready()`, not from a
  `configure()`-style method like `TowerInstance`/`MonsterInstance`. Hero has no such build-time
  entry point — `Hero.tscn` is a single scene-resident instance assembled directly (not spawned
  through a factory/configure call the way towers and monsters are) — so `_ready()` is the correct,
  and only, "existing" hook available. This is not a deviation from ADR-0037 (which only constrains
  the *per-frame position sync*, not the one-time build step — see Decision: "Position sync happens
  inside each system's already-centralized update pass"), just a different existing method than the
  ones Stories 003/004 used for their own build step.
- **No judgment call needed for the sync hook itself**: unlike Story 003 (`TowerInstance`, which had
  no per-frame method and required using `configure()` for the sync line too, a deliberate deviation
  from ADR-0037's literal "existing `_physics_process()`" wording, documented in that story's own
  evidence), **Hero already had a real, pre-existing `_physics_process()`** (movement, grid-position
  tracking, and Tower-Synced Class proximity accumulation, all pre-dating this story). The one-line
  sync call (`_sync_visual_companion_position()`) was added directly inside that existing method,
  exactly matching ADR-0037's literal claim ("`TowerInstance`/`Hero`... sync in their own existing
  `_process`/`_physics_process`") with no deviation required. This is confirmed by the automated
  source-scan tests above, not just asserted.
