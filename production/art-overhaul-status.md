# Art Overhaul — Shared Status

> Read `design/art/codex-art-overhaul.md` first — this file is the live
> tracker that document's §4 describes. Both Codex and Claude Code read this
> before starting work and update it immediately after finishing a step
> (claim → commit → work → update → commit), not batched at session end.
>
> **This file is git-tracked** (unlike `production/session-state/active.md`,
> which is gitignored and single-agent) specifically so a fresh session of
> either agent, in a different terminal, sees current state immediately.

---

## Status legend

| Status | Meaning |
|---|---|
| `backlog` | Identified, not started |
| `claimed by Codex` | Codex is drafting/running a generation prompt — don't touch |
| `claimed by Claude Code` | Claude Code is processing/wiring — don't touch |
| `generated, awaiting processing` | Codex dropped raw output in `assets/source/`, ready for alpha-cut/wiring |
| `blocked` | Something went wrong — see Notes before retrying |
| `done` | Processed, wired, committed — moved to Done section below |

---

## Direction lock-in (complete — see codex-art-overhaul.md §1)

| Item | Status | Notes |
|---|---|---|
| 3D-world / 2D-creatures visual foundation | `done` | Locked by user 2026-08-23. Diablo IV screenshots are Player Inventory UI references only. |

## Production architecture (blocking)

| Item | Status | Notes |
|---|---|---|
| Reconcile Art Bible Sections 2–9 with the new hybrid split | `done` | Completed 2026-08-24. Sections 1–9 now describe one coherent 3D-world/2D-creatures direction. |
| Rendering feasibility investigation (Sprite3D/MultiMeshInstance3D/atlas-frame/depth-sort/shadows/hit-feedback) | `done` | Completed 2026-08-24 by Claude Code, live-verified via Godot MCP against the pinned 4.6.2.stable binary. See `docs/architecture/investigation-2026-08-24-hybrid-swarm-rendering.md`. **Surfaces a blocking ADR conflict** (see next row) and one confirmed engine gotcha (`INSTANCE_CUSTOM` is vertex-stage-only, needs a varying passthrough to reach `fragment()`). |
| ADR-0037 conflict — monster/creature scope | `done` | Resolved at documentation level 2026-08-24: ADR-0037 amended to retain 3D player-domain presentation while ADR-0038 supersedes its monster/creature mesh-companion scope. ADR-0038 is now Accepted (see below). |
| Define Godot 3D/2D scene, camera, lighting, shadow, and compositing architecture | `done` | ADR-0038 and `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` define the recommended architecture. |
| Independent review of ADR-0038 + blueprint | `done` | Completed 2026-08-24 by Claude Code (independent of Codex's authoring context). See `docs/architecture/architecture-review-2026-08-24-adr-0038.md`. **Verdict: cannot Accept yet — correctly self-gated on the pilot, which hasn't run.** Approach itself judged sound and faithful to the prior investigation report. 2 non-blocking precision notes left as-is for Codex. |
| Review's 2 blocking corrections applied to blueprint | `done` | Codex was unavailable (hit its limit) — applied directly by Claude Code 2026-08-24 since both were already fully verified against live code during the review, no new judgment calls needed. `hybrid-swarm-rendering-implementation-blueprint.md`'s frame-ordering section now cites the real `_pending_deaths`/Pass 3 rebuild precedent instead of a hypothetical; the `.tscn` File Ownership rows now correctly state `PresentationRoot3D` doesn't exist yet in either scene and must be created (reparenting the existing `Camera3D`), with exact line citations. |
| Cross-medium pilot scene (Story 1-3 of 4) | `done` | Completed 2026-08-24 by Claude Code, live-verified via Godot MCP. `prototypes/hybrid-swarm-pilot/` — 60-instance `MultiMeshInstance3D` body+shadow batches over the reused `spike.tscn` 3D backdrop. Confirmed working: atlas-frame selection, independent per-instance flash/status-mask via direct data readback (not just visual), shadow batch transforms valid. Found 1 new gotcha: `render_mode alpha_scissor_threshold(0.5)` is invalid syntax on this engine build — correct form is `ALPHA_SCISSOR_THRESHOLD = 0.5;` in `fragment()`. See the prototype's own README.md Findings section for full detail. |
| Dense-handle register/update/remove lifecycle (ADR-0038's real Dense batch algorithm) | `done` | Completed 2026-08-24 by Claude Code, live-verified via Godot MCP against real `MultiMesh` batches (not a simulation). `swarm_batch.gd`/`lifecycle_test.gd` — all 8 test cases passed on first run: register-to-capacity, overflow rejection (no runtime resize), duplicate rejection, swap-remove correctness (including confirming the moved entity's next write lands at its real new slot), stale-handle rejection confirmed to NOT corrupt the replacement occupant (the exact ADR-0038-named failure mode), repeated swap-remove, full wave-clear, entity-ID-reuse-with-fresh-generation. **Flags one real design ambiguity for Codex/Story 7 to confirm**: resolved `slot_index` fresh from `entity_id` every call rather than trusting a caller-cached `slot_index` directly — a defensible, more-robust reading of the blueprint's `PresentationHandle` contract, but not confirmed to match original intent. See the prototype's own README.md for full detail. |
| Cross-medium pilot Story 4 (stress matrix, slope/occlusion cases) | `done` | Completed 2026-08-24 by Claude Code, live-verified via Godot MCP (real `Performance` singleton data, not estimated). **Confirmed**: draw calls and static memory are completely flat across 50/100/150/195 active instances (57 draw calls, 56.4MB, unchanged at every count) — the core `MultiMesh` scalability claim holds empirically. **Correction to Story 1-3's own claim**: the swarm's real draw-call cost is **6** (body+shadow batches together, isolated via node-visibility toggle), not the "2" originally assumed (1 draw call per `MultiMeshInstance3D`) — Forward+ likely issues multiple passes per opaque batch. **New gotcha**: `visible_instance_count=0` does NOT reduce draw calls, only `.visible=false` on the node does — relevant for a future family with zero live members mid-wave. Slope/occlusion cases visually checked and behave as expected (shadows don't raycast-conform to slopes, occlusion depth-tests correctly). Full detail in the prototype's own README.md. |
| D3D12 vs Vulkan backend comparison | `done` | Completed 2026-08-24 by Claude Code, live-verified via Godot MCP. Used the `[rendering] rendering_device/driver.windows="d3d12"` project setting (temporarily set, then reverted) instead of a CLI flag, so the proven `run_project` MCP path could be reused directly. **Result**: no shader compile errors under D3D12's HLSL cross-compilation path, screenshot matches the Vulkan baseline visually, draw calls flat at 57 across 50/100/150/195 active instances (same as Vulkan), and the node-visibility isolation delta is 6 on both backends — fully backend-independent. **Gotcha found**: `attach_project` (for driving a manually `--rendering-driver`-launched process) is unreliable — three ordering attempts all failed to connect the bridge even though the process ran fine; the project-setting route is the recommended path for future backend pilots. |
| ADR-0038 status: Proposed → Accepted | `done` | Decided by the user 2026-08-24: accept now, no macOS caveat (macOS support/testing is not currently planned for this project, so it was dropped from the ADR's tracked gates rather than deferred). All other Validation Criteria items (batching, dense-handle lifecycle, transparency/ordering, contact shadows on slopes, D3D12+Vulkan draw-call/frame budgets) have live-verified pilot evidence in `prototypes/hybrid-swarm-pilot/README.md`. Unblocks Migration Plan step 3 onward (creature-atlas mapping data, renderer contracts, eventual `monster_instance.gd`/`monster_manager.gd` swap). |
| Epic 16 Story 5 — Data registry integration | `claimed by Claude Code` | Started 2026-08-24. `CreatureAtlasMappingResource`/`CreatureAnimationClip` (`src/core/visual_presentation/`), `GameDataRegistry` loader/lookup wiring, 2 real fixture `.tres` under `assets/data/creature_atlases/` (standard + exceptional class), full unit test suite (`tests/unit/visual_presentation/creature_atlas_mapping_resource_test.gd`). Code written, **not yet live-verified against the pinned Godot binary this session** (no test run requested — see the story file's own Completion Notes). Not yet closed via `/story-done`. |
| Epic 16 Story 6 — Mission renderer scene integration | `claimed by Claude Code` | Completed 2026-08-24. `MonsterSwarmRenderer3D`/`MonsterSwarmBatch`/`MonsterPresentationHandle`/`MonsterPresentationSnapshot` (`src/core/visual_presentation/`), `creature_swarm_body.gdshader`/`creature_contact_shadow.gdshader` (`src/shaders/`, ports of the pilot's already-D3D12/Vulkan-verified shaders). `MissionScene.tscn` and `the_gap.tscn` each gained `PresentationRoot3D` with `Camera3D` reparented under it and one `MonsterSwarmRenderer3D` instance. **Real regression found and fixed**: the Camera3D reparent broke `mission_scene.gd`'s and `the_gap.gd`'s own `Camera3D` node references (2 production files) plus 6 `NodePath` lookups in `tower_camera_companion_test.gd` (a pre-existing Epic 15 regression suite) — caught by grepping for all `Camera3D` usages across `src/`/`tests/` before considering the reparent done. Full integration test suite written (`tests/integration/visual_presentation/monster_swarm_renderer_3d_test.gd`). **Not yet live-verified against the pinned Godot binary this session** (user explicitly said to skip running tests this turn). Not yet closed via `/story-done`. |
| Epic 16 Story 9 — Boss/elite exceptional path | `claimed by Claude Code` | Completed 2026-08-25. New `BossCreaturePresenter3D` (`src/core/visual_presentation/`) — a capped 2-slot free-list pool, instanced as a child of `MonsterSwarmRenderer3D`'s own `ExceptionalPresenters` root. Each slot has two `Sprite3D` layers (base + overlay) reproducing `design/gdd/monster.md`'s two-layer boss animation spec (walk continues, attack_prepare/attack plays on the overlay) via a visibility toggle — no distinct animated art exists for any monster yet, honestly flagged rather than faked. `MonsterSwarmRenderer3D` exposes `register_boss()`/`update_boss()`/`unregister_boss()`/`get_boss_live_count()` pass-throughs so `MonsterManager` only ever injects one renderer reference. **This story retires the legacy ADR-0037 3D mesh companion for the LAST tier still using it (BOSS)** — `MonsterInstance.configure()` is now always called with `build_legacy_3d_companion=false`, completing the migration Story 7 started for STANDARD/ELITE. `monster_visual_companion_test.gd` (kept alive through Story 7 as an interim BOSS-tier regression guard) rewritten to confirm the legacy path is dead for every tier now, matching the blueprint's own Migration step 8. `CAPACITY=2` flagged as an assumed default, not empirically pilot-verified (ADR-0038's "proven in the pilot" language doesn't literally hold here). Full test suite written (`tests/integration/visual_presentation/boss_creature_presenter_test.gd`). **Not yet live-verified against the pinned Godot binary this session** (user said to skip running tests this turn). Not yet closed via `/story-done`. |
| Epic 16 Story 8 — Hit/status/death presentation migration | `claimed by Claude Code` | Completed 2026-08-25. `MonsterEntity` gained `hit_flash_remaining_seconds` (manager-owned decay timer, set by `_pass1_damage()` on hit, decremented by `_pass3c_visual_sync()`) and `facing_left` (derived from movement direction in `_advance_entity()`) — both feed real `INSTANCE_CUSTOM.y`/`.w` values for swarm-registered entities, replacing Story 7's hardcoded `0.0`. Status mask (`.z`) is computed fresh each frame from the entity's existing `active_status_effects`/`active_slow_effects` arrays — no new state. **Real judgment call, documented not hidden**: the blueprint's migration step 5 literally says "replace the per-monster ShaderMaterial/Tween... do not retain duplicate flashes," but `Camera2D` remains the actually-visible camera (no story has cut over to `Camera3D` yet) — removing `MonsterInstance.play_hit_flash()`'s 2D Tween now would be a real player-visible regression for zero visible gain. Kept it fully untouched; added a separate swarm-only decay timer instead. Flagged for whichever future story actually flips the camera to decide whether to unify them. **Death presentation confirmed already satisfied**, not built new: `MonsterDeathVFX` is fully independent of the swarm renderer/MonsterManager presentation state and already covers all 3 tiers. Full test suite written (`tests/integration/visual_presentation/monster_swarm_channel_test.gd`), reads real `MultiMesh` custom-data back to prove the pipeline, not just the manager-side math. **Not yet live-verified against the pinned Godot binary this session** (user said to skip running tests this turn). Not yet closed via `/story-done`. |
| Epic 16 Story 7 — MonsterManager standard swarm migration | `claimed by Claude Code` | Completed 2026-08-24. `MonsterManager` now registers STANDARD/ELITE (tier 0/1) monsters with `MonsterSwarmRenderer3D` at spawn (via `set_swarm_renderer()` DI from `mission_scene.gd`/`the_gap.gd`), syncs them through the existing `_pass3c_visual_sync()` call site every frame, and unregisters on death/breach/forced wave-completion (a swarm batch slot has no automatic free-on-node-destruction the way the legacy 3D companion does — this had to be added at all 3 resolution points, not assumed). BOSS (tier 2) is completely untouched — still builds/syncs the legacy ADR-0037 companion, until Story 9. `MonsterInstance.configure()` gained a `build_legacy_3d_companion` param (default `true`, so every pre-existing call site is unaffected); `MonsterEntity` gained a `swarm_handle` field. **Real test-suite conflict found and resolved**: `monster_visual_companion_test.gd` (Epic 15's own regression suite) built its fixture at tier 0 and asserted the exact companion behavior this story removes for that tier — its fixture was changed to tier 2 (real boss fixture) to keep testing the path that's still actually live, rather than testing now-dead behavior. New suite `monster_swarm_migration_test.gd` covers the STANDARD/ELITE path directly. **Not yet live-verified against the pinned Godot binary this session** (user explicitly said to skip running tests this turn). Not yet closed via `/story-done`. |

---

## Backlog

*(Empty — populate once the direction lock-in above is resolved. One row per
asset or tightly-scoped batch, matching `asset-generation-prompts.md`'s
existing granularity — not one row per whole category.)*

| Item | Category | Status | Owner | Notes |
|---|---|---|---|---|

---

## Known layout gaps (from `production/Issues.PNG` / `UI Changes.PNG`)

| Gap | Status | Notes |
|---|---|---|
| Skill-ready row text overlaps/overflows (Skill 1–4 run together, clips) | `backlog` | May be a `mission_hud.gd` layout fix rather than new art — Claude Code to assess. |
| Dead gray space outside the game viewport (top-left, bottom-left) | `backlog` | Window/viewport composition, not art per se. |
| Dead stone-frame margin (right edge, top-right, bottom-left corners) | `backlog` | New frame/background art should be composed to fill this, per coordination doc §2. |
| Monster-composition label sits flush against frame edge, no padding | `backlog` | Layout fix. |

---

## Done

*(Empty so far.)*

| Item | Category | Completed | Commit | Notes |
|---|---|---|---|---|
