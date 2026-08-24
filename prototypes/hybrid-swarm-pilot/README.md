# Prototype: Hybrid 3D-World / 2D-Creature Swarm Rendering Pilot

<!-- PROTOTYPE — NOT FOR PRODUCTION -->
<!-- Question: See §Core Questions below -->
<!-- Date: 2026-08-24 -->

**Status**: Story 1-4 core complete (multi-backend comparison and the real dense-handle lifecycle remain — see Findings)
**Risk**: HIGH — gates ADR-0038's move from Proposed to Accepted, and gates all mass creature-art production for the art overhaul.
**Engine**: Godot 4.6.2 / GDScript
**Timebox**: 2 sessions (Story 1 scaffold + Story 2 batch core + Story 3 shaders, then Story 4 stress matrix + slope/occlusion cases)

---

## Core Questions

This is ADR-0038's own required cross-medium pilot (`docs/architecture/adr-0038-hybrid-creature-swarm-rendering.md`, `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` Story 1-4) and `art-bible.md` §8.7's pilot gate. It exists to answer, empirically, the questions
`docs/architecture/investigation-2026-08-24-hybrid-swarm-rendering.md` raised but did not fully close:

**Q1 — Does the dense `MultiMeshInstance3D` batch + custom-data atlas-shader approach actually render a swarm of illustrated 2D creatures inside a 3D world**, at the fixed camera angle `ADR-0037` already established, without per-instance nodes or materials?

**Q2 — Does per-instance state (atlas frame, hit-flash, a placeholder status/facing value) vary correctly and independently across adjacent instances**, proving the fixed 4-channel `INSTANCE_CUSTOM` contract (frame/flash/status-mask/facing) from ADR-0038 §"Per-instance channel budget"?

**Q3 — Does the flat shadow-decal stream (§5 of the investigation report) ground creatures believably without real shadow-casting from the billboard**, and does it stay visually attached across a range of positions?

**Q4 — What does whole-scene draw-call count actually look like** with the 3D backdrop (reused from `3d-tower-defense-kit-spike/spike.tscn`) plus one creature swarm batch plus one shadow batch, at a modest instance count — a first data point toward `art-bible.md` §8.5's `<=150` normal / `<=180` stress budget, not the full stress matrix.

Pass/fail criteria: see **Findings** below, updated as this prototype concludes each story.

---

## Prototype Scope

**In scope:**
- Reuse `3d-tower-defense-kit-spike/spike.tscn`'s tile/tower/prop GLB instances as the 3D-world backdrop (per the investigation report's own recommendation — no need to re-source).
- One fixed, non-rotating `Camera3D` + `DirectionalLight3D` (shadow-enabled), matching ADR-0037's established constraint.
- A synthetic 4-frame atlas texture (flat colored quadrants, procedurally generated — no real creature art exists yet, and none is needed to answer Q1-Q4).
- One `MultiMeshInstance3D` "body" batch: vertical billboard quads, alpha-scissor cutout, spatial shader reading `INSTANCE_CUSTOM` via the vertex-to-flat-varying pattern the investigation report confirmed is required on this engine build.
- One `MultiMeshInstance3D` "shadow" batch: flat horizontal blob quads, unlit, grounded, one per body instance.
- A small driver script that spawns N instances in a scatter pattern, cycles each instance's atlas frame over time, and periodically triggers a hit-flash on a few instances via the custom-data channel (no Tween needed for a prototype-quality flash — a direct per-frame lerp is sufficient).

**Out of scope (explicitly deferred, per the blueprint's own Story boundaries):**
- Any production integration — `MonsterManager`/`MonsterInstance` are untouched. This prototype never runs inside a real mission scene.
- The full dense-handle/swap-remove register/update/remove lifecycle algorithm (ADR-0038's `BatchKey`/`PresentationHandle` contracts) — this pilot spawns a fixed instance count once and never removes any, which is sufficient to answer Q1-Q4 but not a stand-in for the real lifecycle code Story 7 will need.
- Multi-backend (D3D12/Vulkan/macOS) comparison — this pass runs on whatever backend this machine's pinned Godot binary defaults to.
- Boss/elite `Sprite3D` exceptional-presenter path.
- Real creature art/atlases — the synthetic atlas is deliberately abstract (colored quadrants, not illustrated frames) so this pilot answers a rendering-mechanism question, not an art-quality one.

---

## How to Run

Open `prototypes/hybrid-swarm-pilot/pilot.tscn` in the Godot editor and run it (F6), or via Godot MCP:
`run_project` with `scene: "prototypes/hybrid-swarm-pilot/pilot.tscn"`, then `take_screenshot`.

No autoloads or production scene dependencies are required — this prototype is fully self-contained.

---

## Findings

**Status: Story 1-3 complete and live-verified via Godot MCP (2026-08-24). Story 4 (full stress matrix) not attempted this pass.**

**Q1 — YES, confirmed.** A `MultiMeshInstance3D` body batch (60 instances, camera-facing Y-axis billboard, alpha-scissor cutout atlas shader) renders correctly inside the reused `spike.tscn` 3D backdrop at the fixed camera angle, zero runtime errors, zero shader compile errors (after one fix — see Gotchas below).

**Q2 — YES, confirmed via direct data readback, not just visual inspection.** Queried the live `MultiMesh` instance custom data after ~3 seconds of runtime: all 60 instances shared the same current frame index (3/yellow — proves the lockstep frame-cycling write path works), 8 instances independently flashed (~13%, matching the ~15% random-pulse design), and exactly 9 instances (every 7th, `i % 7 == 0`) carried the status-mask tint — all three channels varying independently and correctly, exactly as the fixed 4-channel contract requires.

**Q3 — Structurally confirmed, visually inconclusive from a screenshot alone.** The shadow batch's 60 instance transforms are all valid, non-degenerate, correctly Y-up-oriented (queried live), `cast_shadow` correctly disabled. The shadow blobs are visually subtle in this pilot's screenshot (semi-transparent gray-on-gray against a blue-gray sky/ground) — this is a lighting/contrast tuning question for a later art pass, not a functional defect; the mechanism itself (flat, grounded, unlit, non-billboarded quad stream, independent of the body billboard's own orientation) works as designed.

**Q4 — Partial, structural answer only, not profiler-measured.** Two `MultiMeshInstance3D` nodes (body + shadow) is a *design-level* guarantee of exactly 2 draw calls for the entire 60-instance swarm, regardless of instance count (that is the whole point of `MultiMesh` — one draw call per batch) — not something that needed live profiling to establish. What this pilot does NOT establish: actual GPU/CPU frame time, memory, or behavior at the real target scale (100-200 instances) or under transparency/overlap stress — that is Story 4's explicit scope, not attempted this pass.

**Gotchas found (real, not assumed):**
- `render_mode alpha_scissor_threshold(0.5)` is **invalid syntax** on this Godot 4.6.2.stable build — fails shader compilation with `Invalid render mode: 'alpha_scissor_threshold'`. The correct form is a fragment-stage output assignment: `ALPHA_SCISSOR_THRESHOLD = 0.5;` inside `fragment()`, exactly like `ALBEDO`/`ALPHA`. Not previously documented anywhere in this project — worth folding into the production shader (`src/shaders/creature_swarm_body.gdshader` once Story 5+ lands) so this isn't rediscovered.
- The `INSTANCE_CUSTOM`-must-be-captured-via-vertex-then-varying pattern (already found in `investigation-2026-08-24-hybrid-swarm-rendering.md`) was re-confirmed working here with zero issues on the second attempt — no new findings on that front.

---

## Story 4 — Stress Matrix, Slope, and Occlusion (2026-08-24, second pass)

**Setup change from Story 1-3**: capacity is now fixed at 200 instances (`MAX_INSTANCE_COUNT`), matching ADR-0038's own "preallocate once, never resize `instance_count` at runtime" rule. `set_active_count(n)` varies `MultiMesh.visible_instance_count` instead — the exact "dense live prefix" mechanism ADR-0038 names — rather than reallocating. 195 of the 200 slots are the random-scatter stress population; the last 5 are hand-placed slope/occlusion test cases, always excluded from the stress count so they don't skew the numbers (toggle via `show_special_test_instances(true)`).

**Q4, corrected — real measured data, not a design-level assumption.** Ran `set_active_count()` at 50/100/150/200(clamped to 195) and sampled `Performance` monitors after a 10-frame settle window each time, via live Godot MCP `run_script` — not estimated:

| Active instances | Total scene draw calls | FPS | Static memory (MB) |
|---|---|---|---|
| 50 | 57 | 60 | 56.42 |
| 100 | 57 | 60 | 56.42 |
| 150 | 57 | 60 | 56.42 |
| 195 (200 clamped) | 57 | 60 | 56.42 |

**Draw calls and memory are both completely flat across the entire range** — confirms the core `MultiMesh` claim empirically: active instance count has zero effect on either, because capacity is preallocated once and the GPU handles per-instance work internally. This is the single most important number this pilot produces.

**Correction to the Story 1-3 Findings above**: that pass claimed "2 draw calls total for the swarm" as a design-level assumption (one `MultiMeshInstance3D` = one draw call). **This was wrong, found and corrected this pass.** Isolated the swarm's real contribution by toggling `BodyBatch`/`ShadowBatch` node visibility off entirely (not just `visible_instance_count = 0` — see the next finding for why that distinction matters) and re-measuring: scene draw calls dropped from 57 to 51, a real delta of **6**, not 2. Forward+ almost certainly issues more than one pass per opaque batch (depth pre-pass, shadow pass, color pass), so 2 batches × ~3 passes ≈ 6 is the plausible explanation — not confirmed via a renderer-internals trace, but the measured number itself is real and now the one to cite, not the earlier assumption.

**Gotcha: `visible_instance_count = 0` does NOT reduce draw calls.** Tested directly — setting both batches' `visible_instance_count` to 0 left `draw_calls` at 57, identical to any nonzero count. Only setting the `MultiMeshInstance3D` node's own `.visible = false` actually dropped the count (to 51). A batch with zero live members still costs its full per-pass draw-call overhead as long as the node itself is visible — worth knowing for a future family with zero live members mid-wave (e.g. no Elites currently spawned): the batch node would need to be hidden outright to actually save the cost, not just driven to zero visible instances.

**Q3, re-confirmed at higher density and with dedicated slope cases.** At 150 active + 5 special instances shown, shadow blobs are visibly present under the swarm in this pass's screenshot (denser scene, easier to see than Story 1-3's sparser 60-instance shot). 2 dedicated slope-test instances were hand-placed on a new `Ramp` backdrop object (a tilted `BoxMesh`, ~22°incline) at two different heights — visually confirmed sitting on/near the ramp surface in the screenshot. The shadow batch's flat, non-terrain-conforming Y-offset (each shadow's height derived from its own body's Y position, not a raycast to the actual ground/ramp surface underneath) is confirmed still simplistic exactly as expected — a real production implementation would need either a raycast-derived ground height per instance or acceptance that shadows only look correct on flat ground, not documented as solved here, just visually confirmed to behave as designed (not raycast-aware).

**Occlusion — visually consistent with correct depth-testing, not independently instrumented.** 3 instances were placed directly behind the `Tower` backdrop object from the fixed camera's viewpoint; none are visibly poking through the tower mesh in the screenshot, consistent with standard depth-test occlusion working correctly for a `MultiMesh` batch mixed with regular opaque `MeshInstance3D` content in the same scene — expected engine behavior, not something this specific pairing needed to prove, but worth having actually looked rather than assumed.

---

## Dense-Handle Lifecycle (2026-08-24, third pass)

Implements and live-tests ADR-0038/the blueprint's actual "Dense batch algorithm" — register/update/remove-via-swap, stale-handle rejection, overflow, duplicate rejection — the one piece Story 1-4 explicitly deferred ("this pilot only ever grows a fixed scatter, never removes an instance mid-run"). `swarm_batch.gd` (`PilotSwarmBatch`) + `lifecycle_test.gd` (a repeatable, `run_script`-executable test driver, not a throwaway check).

**Design decision, not fully unambiguous in the source documents — flagged for Codex/Story 7 to confirm, not silently assumed correct**: the blueprint's `PresentationHandle` lists `entity_id, batch_id, slot_index, generation` and says every mutating call "validates all four." Read literally, a caller-cached `slot_index` can go stale the instant an *unrelated* removal elsewhere in the batch swap-moves whichever entity currently occupies the batch's `last` slot — which could be an entity the caller isn't even touching this frame. This pilot instead resolves `slot_index` fresh from `entity_id` on every `update()`/`remove()` call (an internal `entity_id -> slot_index` map, updated silently on every swap-move) and tracks generation per-entity, not per-slot — a caller's handle for a still-live entity never spuriously goes stale from churn elsewhere in the batch. This is strictly more robust than trusting a caller-cached `slot_index` regardless of which reading the ADR intended, at the cost of one extra dictionary lookup per call (negligible next to a `MultiMesh` write) — but it is a real interpretation of ambiguous text, not a confirmed match to Codex's original intent.

**All 8 lifecycle test cases passed on the first real run** (`lifecycle_test.gd`, executed live via Godot MCP against real `MultiMesh` batches — an in-memory-only simulation would not have caught a slot/buffer desync the way this does):

1. Register to capacity (10/10 succeed).
2. Overflow rejected at capacity+1 — confirmed `instance_count` never changes (no runtime resize).
3. Duplicate `entity_id` registration rejected.
4. Remove from the middle — swap-remove correctness verified two ways: `assert_dense_integrity()` (entity↔slot maps agree, `visible_instance_count` matches `live_count`, no gaps inside the dense range) AND a direct write/read-back check confirming the moved entity's *next* `update()` call lands at its actual new slot, not its stale original one.
5. **Stale handle correctly rejected on both `update()` and `remove()`, and confirmed to NOT mutate the replacement occupant's data** — this is the specific failure mode ADR-0038's own `PresentationHandle` contract names as unacceptable ("a stale handle... must never mutate a replacement occupant"), verified by reading back the replacement occupant's slot after the stale-handle attack and confirming it wasn't overwritten.
6. Repeated swap-remove (down to 3 live entities) — dense integrity re-checked and held.
7. Full wave-clear (remove everything) — `live_count` and both `visible_instance_count`s correctly reach 0.
8. Re-registering a previously-removed `entity_id` gets a fresh generation; the caller's **old** handle for that same numeric ID (predating the wave clear) correctly fails to validate against the new registration — proves entity-ID reuse across a mission's monster pool (the exact scenario ADR-0038 exists to support) doesn't let a stale handle from wave N leak into wave N+1's differently-live entity of the same ID.

**Not tested here**: performance of the register/update/remove path at the 100+ scale Story 4 already stress-tested for static rendering (this lifecycle test uses a small capacity-10 batch specifically to keep the test cases easy to reason about and verify by hand) — a future pass could combine both (dynamic churn at 100+ concurrent live entities) for a fuller picture, not attempted this session.

**Not attempted this pass (explicitly out of scope, see README's own Scope section):** multi-backend comparison (this machine only has one target: Vulkan Forward+ on Windows/AMD — no D3D12 or macOS hardware available to this session, flagged honestly rather than guessed at), the real dense-handle/swap-remove register-update-remove lifecycle (`BatchKey`/`PresentationHandle` from ADR-0038 — this pilot only ever grows a fixed scatter, never removes/swaps an instance mid-run), boss/elite `Sprite3D` exceptional path, real creature art. `process_time_ms` hovered ~17.1-17.5ms across all runs in this headless/background MCP session — close to the 16.67ms/frame budget, but this number reflects the whole background-mode Godot process (MCP bridge polling included), not an isolated measurement of just this scene's cost, so it is reported here for completeness, not cited as a real production frame-budget data point.
