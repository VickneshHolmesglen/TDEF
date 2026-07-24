---
name: project-mission-hud-gdd
description: Mission HUD GDD (Needs Revision) and UX spec (Approved) are both fleshed out through PC-5; PC-1/2/3/5 all have full asset/animation specs in the UX doc now
metadata:
  type: project
---

`design/ux/mission-hud.md` (Approved, last updated 2026-07-15) and `design/gdd/mission-hud.md` (Status: Needs Revision, last updated 2026-07-15) are both far more complete than an earlier snapshot of this memory suggested — that snapshot (describing the GDD as "still a skeleton" with PC-1/PC-3 undesigned) is stale as of 2026-07-14/15 and should not be trusted; always re-read both files before treating this system's status as current.

**Current state (2026-07-15)**: PC-1 (route-preview overlay), PC-2 (blocked-cell two-tier emphasis), PC-3 ("path update queued" banner), and PC-5 (boss-lane telegraph marker, closes Tower GDD OQ-11) all have complete visual/animation specs. PC-5 was the last open UX gap — closed this session: skull-glyph badge marker (reuses the `☠` icon already established for the Boss nameplate in this doc's own WAVE_ACTIVE wireframe), diamond-outline + cross-hatch shape-before-color treatment (deliberately distinct shapes from PC-2's square-outline/single-diagonal-hatch), a one-shot 0.5s scale-punch + expanding-ring confirmation pulse (vs. PC-2's continuous slow breathing) with a reduced-motion opacity-flash variant, and a once-per-mission Pattern 10 first-appearance callout banner. Full spec lives in the UX doc's "PC-5 — Boss-Lane Telegraph Marker: Asset & Animation Spec" subsection (Layout Specification) plus matching rows added to Component Inventory, States & Variants, Events Fired, Transitions & Animations, Accessibility, Localization, and Acceptance Criteria.

**Still genuinely open** (as of 2026-07-15, not resolved by the PC-5 pass):
- PC-2's Tier-2 breathing motion still has no reduced-motion fallback/exemption (UX doc Accessibility table, PC-2 row) — a real remaining gap, separate from PC-5.
- The GDD's own header notes the CanvasLayer→grid-cell camera-transform mechanism underlying PC-1/PC-2/PC-5 has only been *partially* live-verified via MCP (confirmed `HUD` CanvasLayer has an identity transform and `Camera2D` position/zoom are set once at mission configure, never updated) — full pixel-level verification is deferred until PC-1/PC-2/PC-5 are actually implemented (currently `HUD`'s only live child is a placeholder Panel).

**Why this matters**: this system has had several rounds of `/design-review`/`/review-all-gdds` catching real gaps (missing `wave_preview_available` handling entirely, a structurally-dead-code confirmation pulse from a reset-ordering bug, missing accessibility/localization table rows for new elements) — treat any claim about this GDD's completeness as needing a fresh read, not a memory recall, given how fast it's been moving.

**How to apply**: Before treating any part of Mission HUD as designed or gap-free, re-read both `design/gdd/mission-hud.md` and `design/ux/mission-hud.md` directly — don't rely on a remembered gap list, including this one, without checking the files' current `Last Updated` dates first.
