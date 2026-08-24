# Prototype: Hybrid 3D-World / 2D-Creature Swarm Rendering Pilot

<!-- PROTOTYPE — NOT FOR PRODUCTION -->
<!-- Question: See §Core Questions below -->
<!-- Date: 2026-08-24 -->

**Status**: In progress
**Risk**: HIGH — gates ADR-0038's move from Proposed to Accepted, and gates all mass creature-art production for the art overhaul.
**Engine**: Godot 4.6.2 / GDScript
**Timebox**: 1 session (Story 1 scaffold + Story 2 batch core + Story 3 shaders; Story 4's full 50/100/150/200-instance multi-backend stress matrix is out of scope for this pass — see Findings)

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

**Not attempted this pass (explicitly out of scope, see README's own Scope section):** multi-backend comparison, the real dense-handle/swap-remove lifecycle, boss/elite `Sprite3D` path, real creature art, and the full 50/100/150/200-instance stress matrix. Recommend Story 4 as the next pilot increment before ADR-0038 can move past Proposed — this pass answers "does the mechanism work," not "does it hold at scale," which is ADR-0038's own actual Acceptance Criteria bar.
