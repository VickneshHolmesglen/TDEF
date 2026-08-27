# Story 010: Cleanup and Production Gate

> **Epic**: Hybrid Creature Swarm Rendering
> **Status**: In Review
> **Layer**: Core + Presentation (dead-code removal, data cleanup)
> **Type**: Integration
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-25

## Context

**GDD**: None — infrastructure epic, no GDD linkage (see `EPIC.md`).
**Requirement**: None.

**ADR Governing Implementation**: ADR-0038 (Hybrid Creature Swarm Rendering) — Accepted 2026-08-24.
**ADR Decision Summary**: `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` §"Story 10 — Cleanup and production gate": "Remove migration switch, retire monster-only placeholder mesh data, update tests/docs, run full regression and final art-pipeline acceptance capture." Migration steps 9-10: "Prove no reference to the enemy UFO mesh mapping remains, then retire that monster-only placeholder mapping" / "Remove the temporary migration switch after all creature families and regression tests pass."

**Engine**: Godot 4.6.2 | **Risk**: LOW — pure deletion/cleanup of already-dead code and an already-unreferenced data file; no new engine API surface.
**Engine Notes**: None.

**Control Manifest Rules (this layer)**: N/A — this story removes code, it does not add any new pattern to check against the manifest.

---

## Acceptance Criteria

*Sourced from the blueprint's Story 10 scope line and Migration steps 9-10:*

- [ ] Proved (via repo-wide grep, not assumption) that no functional reference to `enemy_ufo_a`/`MONSTER_MESH_ENTITY_ID` remains anywhere in `src/` before deleting `assets/data/visual_meshes/enemy_ufo_a.tres`. The 2 remaining matches after cleanup (`src/scenes/projectile_visual.gd`, `src/core/hero/hero.gd`) are historical prose comments explaining those files' own unrelated mesh-selection precedent, not live code paths — confirmed by direct inspection, not left unchecked.
- [ ] `assets/data/visual_meshes/enemy_ufo_a.tres` deleted. The underlying shared third-party asset it pointed at (`enemy-ufo-a.glb`, part of the "Tower Defense Models" Kenney-style pack) is NOT deleted — it's pack content this project doesn't own/manage per-file, and nothing in this story's scope requires removing it.
- [ ] `MonsterInstance`'s legacy 3D-companion machinery is fully removed: `MONSTER_MESH_ENTITY_ID`, `_visual_companion`, `_build_visual_companion()`, `sync_visual_companion_position()`, and the `configure()` parameter that gated it (`build_legacy_3d_companion`) — all deleted, not just made permanently unreachable. `configure()` reverts to its original 3-arg signature (`monster_id`, `tier`, `display_name`).
- [ ] `MonsterManager`'s call site (`_spawn_entity()`) and its now-dead fallback branch in `_pass3c_visual_sync()` (the one that used to call `sync_visual_companion_position()` when neither `swarm_handle` nor `boss_presenter_handle` was set) are updated to match — no call to a method that no longer exists.
- [ ] `tests/integration/visual_presentation/monster_visual_companion_test.gd`'s own header/inline comments updated to stop describing a temporary migration switch that no longer exists (the parameter itself is gone, not just always-false).

---

## Implementation Notes

*What this story actually did, and what it deliberately left alone:*

- Grep-first, delete-second: ran `rg "enemy_ufo_a|MONSTER_MESH_ENTITY_ID"` across the whole repo before touching anything, confirmed the only functional (non-comment, non-doc) consumer was `monster_instance.gd`'s own now-dead `_build_visual_companion()`, then deleted both the code and the data file together in the same pass — matching the blueprint's own ordering ("prove no reference remains, THEN retire").
- `MonsterManager._pass3c_visual_sync()`'s trailing fallback (reached only when an entity has neither `swarm_handle` nor `boss_presenter_handle` — a registration-failure/no-renderer-injected case, e.g. a unit test with no scene context) is now a no-op with an explanatory comment, not a call into deleted code. This is intentionally NOT deleted entirely — the `if`/`continue` structure above it still needs a valid (even if empty) fallthrough path for entities that legitimately have no presentation handle.
- Did NOT touch `production/qa/evidence/monster-visual-companion-evidence.md` — that's Epic 15 Story 004's own point-in-time evidence record; this project's convention (matching every other review-log/evidence doc) is append-only historical record, not retroactively rewritten when the thing it documented is later superseded.
- Did NOT touch the historical precedent comments in `src/scenes/projectile_visual.gd`/`src/core/hero/hero.gd` that mention `enemy_ufo_a.tres` by name — they're explaining THOSE files' own past mesh-selection reasoning ("why we picked X, to avoid colliding with what monster/tower already used"), accurate as historical context even though the referenced file is now gone; not a functional dependency, out of this story's real scope.
- **Done 2026-08-27, a later session**: "run full regression" — the full gdUnit4 suite (2355 test cases across 235 suites, including all 6 new Epic 16 test files and every pre-existing suite this epic touched) was run against the pinned 4.6.2.stable binary. Result: 0 errors, 1 failure. That 1 failure (`monster_swarm_channel_test.gd`) was investigated, not just noted — live-verified via Godot MCP against the real Vulkan/Forward+ renderer that the actual Story 8 implementation it tests is mathematically correct; the failure itself was root-caused to gdUnit4's headless `RendererDummy` backend misbehaving with `MultiMesh` readback, a test-infrastructure gap (`TD-test-007`, `docs/tech-debt-register.md`), not a regression in this epic's code. See Completion Notes.
- **Partially done 2026-08-27**: "final art-pipeline acceptance capture" — a live Godot MCP session did spawn a real monster and exercise the swarm renderer's hit-flash channel end-to-end (see TD-test-007's investigation), confirming the pipeline renders correctly. A full visual screenshot comparison (mirroring the pilot's own screenshots) was not additionally captured — the live verification was targeted at resolving a specific test failure, not a general acceptance pass.

---

## Out of Scope

*Genuinely future work, not deferred-but-implied-done:*

- Real animated creature art (any tier) — flagged as a gap in Story 9, still a gap.
- Actually cutting `Camera3D` over to be the active/visible camera — no story in this epic does this; flagged as a deferred decision in Story 8's own judgment-call note, still deferred.
- macOS backend verification for the underlying pilot's D3D12/Vulkan work — flagged in the pilot's own README as out of reach (no macOS hardware), unrelated to this story specifically but still an open item for ADR-0038 as a whole if that ever changes.

---

## QA Test Cases

No new test file — this story is a deletion/cleanup pass. Verification is: (1) the repo-wide grep evidence cited above, (2) every existing Epic 16 test file (Stories 5-9) still references only symbols that exist after this cleanup (spot-checked by re-grepping for the deleted symbol names across `tests/` — zero functional hits), (3) `monster_manager.gd`/`monster_instance.gd` read back in full after editing to confirm no dangling call to a deleted method remains.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: None new — this story doesn't add a test file. The existing Epic 16 suites (`creature_atlas_mapping_resource_test.gd`, `monster_swarm_renderer_3d_test.gd`, `monster_swarm_migration_test.gd`, `monster_swarm_channel_test.gd`, `boss_creature_presenter_test.gd`, `monster_visual_companion_test.gd`) collectively serve as this story's regression evidence once run.

**Status**: [x] RUN 2026-08-27. Full suite: 2355 test cases, 0 errors, 1 failure (`monster_swarm_channel_test.gd`, root-caused to a headless-CI/`RendererDummy` test-infrastructure gap — `TD-test-007` — not a code regression; the implementation itself is live-verified correct under the real renderer). The gate has now actually been exercised, with an honest, non-zero result rather than a rubber stamp. See Completion Notes.

---

## Dependencies

- Depends on: Story 9 (retired the last live user of the legacy companion path, making this cleanup safe)
- Unlocks: nothing further planned in this epic — Story 10 is the last story in the blueprint's 10-story sequence.

## Completion Notes
**Completed**: Code-complete 2026-08-25. **Gated 2026-08-27** — the "run full regression" criterion this story's own name promises has now been performed: full gdUnit4 suite (2355 test cases, all 6 new Epic 16 test files plus every pre-existing suite this epic touched), 0 errors, 1 failure. That failure was investigated to a real root cause (headless `RendererDummy`/`MultiMesh` test-infrastructure issue, `TD-test-007`) rather than left as an unexplained red mark, and the underlying Story 8 implementation it was supposed to test was separately confirmed correct via live Godot MCP verification against the real renderer. "Final art-pipeline acceptance capture" (a full visual screenshot comparison) remains not formally captured — the live verification performed was scoped to resolving TD-test-007, not a general acceptance pass; this narrower gap is the one honest remainder, not the whole gate.
**Criteria**: 5/5 code-level items done; 1.5/2 gate-level items done (regression run: done, with 1 known-and-explained non-blocking test-infra failure; acceptance capture: partially covered by the targeted live verification, not a full formal pass).
**Deviations**: None from the blueprint's described cleanup scope. The original "NOT gated" deviation from the 2026-08-25 session is now resolved — see above.
**Test Evidence**: Full suite run 2026-08-27 — 2355 test cases, 0 errors, 1 failure (unrelated test-infra issue, `TD-test-007`, not a regression). Every pre-existing suite this epic touched passes clean.
**Code Review**: Not yet run.
