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
