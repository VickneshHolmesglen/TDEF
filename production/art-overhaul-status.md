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
| ADR-0037 conflict — monster/creature scope | `done` | Resolved at documentation level 2026-08-24: ADR-0037 amended to retain 3D player-domain presentation while ADR-0038 supersedes its monster/creature mesh-companion scope. ADR-0038 remains Proposed until accepted after review. |
| Define Godot 3D/2D scene, camera, lighting, shadow, and compositing architecture | `done` | ADR-0038 and `docs/architecture/hybrid-swarm-rendering-implementation-blueprint.md` define the recommended architecture. |
| Independent review of ADR-0038 + blueprint | `done` | Completed 2026-08-24 by Claude Code (independent of Codex's authoring context). See `docs/architecture/architecture-review-2026-08-24-adr-0038.md`. **Verdict: cannot Accept yet — correctly self-gated on the pilot, which hasn't run.** 2 blocking-before-implementation corrections found (a frame-ordering discrepancy already true in `monster_manager.gd` today, not just hypothetical; a `PresentationRoot3D` node the blueprint treats as existing but doesn't in either `.tscn`) plus 2 non-blocking precision notes. Approach itself judged sound and faithful to the prior investigation report. |
| Cross-medium pilot scene | `backlog` | Build only after the 2 blocking review corrections above land in the blueprint. Investigation report §9 / ADR-0038 Story 1 recommend `prototypes/hybrid-swarm-pilot/` (the existing `3d-tower-defense-kit-spike/` doesn't cover swarm/2D-in-3D questions). Validate representative 3D environment/towers with 100+ instanced 2D creatures, contact shadows, depth sorting, VFX, and state lighting. |

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
