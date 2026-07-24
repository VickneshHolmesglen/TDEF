# Story 013: Visual/Audio Pass — Drawer-Slide, DEPARTING Beat, Shell Chrome Language

> **Epic**: Sanctuary UI
> **Status**: Partial (2026-07-24 — chrome styling, room-hosting composition, badge/header scale-pop, and the DEPARTING chrome-fade implemented and live-verified via Godot MCP screenshots; diorama-dependent visuals blocked on content that doesn't exist — see `production/qa/evidence/story-013-visual-audio-pass-evidence.md`. **Updated 2026-07-25**: the diorama itself is now real — see note below. Still Partial: the real gap is now "no actual art," not "no diorama mechanism.")
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-07-13b
> **Estimate**: 3h

## Context

**GDD**: `design/gdd/sanctuary-ui.md`
**Requirement**: `TR-sanctuary-ui-???` (no TR-ID registered — scoped from the GDD's own Visual/Audio Requirements section, explicitly excluded from automated ACs per the GDD's own "Not Independently Testable as GDD-Level Runtime Criteria" section)

**ADR Governing Implementation**: ADR-0013 (Sprite Rendering/Batching, Presentation Layer conventions)
**ADR Decision Summary**: Shared per-class texture atlas, z-ordering via `z_index` only, no `CanvasLayer` per entity, ≤200 draw calls/frame project-wide, ≤60 DC target for a complete scene at MVP entity counts.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Verify actual draw-call count via Remote Debugger before closing this story.

**Control Manifest Rules (this layer)**:
- Required: single shared per-class texture atlas; z-ordering via `z_index` only — source: ADR-0013
- Forbidden: never use `CanvasLayer` per entity for z-ordering; never use `SubViewport`-per-entity compositing — source: ADR-0013
- Guardrail: total scene draw calls ≤ 200/frame; entity-scene draw calls at MVP counts target ≤ 60 DC — source: ADR-0013, technical-preferences.md

---

## Acceptance Criteria

*From GDD `design/gdd/sanctuary-ui.md`, Visual/Audio Requirements section (explicitly flagged by the GDD itself as not independently testable via runtime assertion — requires lead sign-off via screenshot/playtest evidence):*

- [ ] Room-switch transition is a literal drawer-slide (outgoing room slides toward the tab strip, incoming slides in from the same edge, overlapping briefly, full `RoomHost` frame size throughout), horizontal only, timing within Tuning Knobs range (150–250ms in / eased-out settle).
- [ ] `sanctuary_structure_built` flourish plays only when `OVERVIEW` is the active state at fire time; skipped in favor of the Defense Building Connection Badge when a `ROOM_*` state is active.
- [ ] `DEPARTING` beat: shell chrome fades out first and fastest; diorama camera performs a slow pull-back/settle (roughly 60% chrome-fade+pull-back / 40% hold-on-settled-frame within the ~0.5s budget).
- [ ] Shell chrome (tab strip, resource header) reuses Mission HUD's established screen-space language (chamfered-rectangle shape grammar, UI Chrome/Parchment/Accent palette, flat single-inset-shade iconography, snappy-in ≤120ms / eased-out settle 150–200ms motion contract, no overshoot) — deliberately does not match any individual room's own visual register.
- [ ] Connection Badges use the existing filled-vs-outline / non-color-first convention with the established ~1.0→1.15→1.0 scale-pop.
- [ ] Diorama uses full stacked-sprite/cast-shadow treatment; chrome uses flat/low-relief drop shadows only (purely vertical offset) — never stacked-sprite shadows on chrome.

---

## Implementation Notes

This story implements the Visual/Audio Requirements section wholesale. Since the GDD itself explicitly excludes these from automated black-box assertion (subjective visual/feel judgments), evidence is lead sign-off via screenshot/playtest, matching `mission-hud.md`'s own precedent.

Timing values (Tuning Knobs): room dock-transition 200ms in / 220ms eased-out settle (range 150–250ms); `DEPARTING` beat 0.5s (range 0.3–1.0s); Connection Badge scale-pop ~0.2s.

Audio: no `design/audio/` bible exists yet — directional only per the GDD's own note. Implement placeholder/deferred audio hooks (event names, no actual SFX selection) so Audio System's own future content-authoring pass (flagged in session state as still-open work) has clear attachment points.

---

## Out of Scope

- The actual SFX asset selection — deferred until Audio System's `AudioCueMap` content-authoring pass is complete
- Story 009/010: the state-machine mechanics the `DEPARTING`/`DEPARTING_TO_LOADOUT` beats visualize (this story only owns the visual pacing, not the terminal-latch logic)

**Real progress, 2026-07-25**: the Diorama went from Story 001's empty placeholder `Control` (0 children, confirmed by Story 012's own finding) to a real, functioning node: fixed-position structure rendering for both real `StructureResource` types (`watchtower`, `habitat_expansion`) driven by the genuine `sanctuary_structure_built` event, a live habitat-occupancy count reading real `Menagerie` state, and a "camera" pull-back beat for the `DEPARTING` transition (implemented as a scale+position tween on a `World` container, since the Diorama's own root is a `Control` — see `diorama.gd`'s own doc comment for why a literal `Camera2D` doesn't apply here). Real art generation was attempted first via this project's own ComfyUI pipeline (`tools/generate_asset.py`) and hard-failed on a CUDA/ZLUDA driver error at the model's own embedding-tensor allocation step — a local GPU/driver environment issue on this machine, not fixable from this codebase. Fell back to `ColorRect` placeholders, the same "no art exists" honest-scope convention used everywhere else in this project. 8 new tests, all passing (`tests/integration/sanctuary-ui/diorama_test.gd`). **The GDD's "full stacked-sprite/cast-shadow treatment" requirement remains a real, unclosed gap** — this is now a content/art gap, not a missing-mechanism gap.

---

## QA Test Cases

*(Visual/Feel story — manual verification steps, not automated test specs, per the GDD's own explicit exclusion of this section from runtime assertion)*

- **Manual check: drawer-slide feel**
  - Setup: switch between any two rooms
  - Verify: horizontal-only slide, both rooms visible mid-transition, full `RoomHost` size throughout, timing feels neither sluggish nor abrupt
  - Pass condition: lead sign-off via screenshot/recorded playtest, no vertical/diagonal motion observed

- **Manual check: DEPARTING beat pacing**
  - Setup: trigger Launch/Depart from `OVERVIEW`
  - Verify: chrome fades first/fastest, camera pull-back reads as deliberate not abrupt, roughly 60/40 fade-vs-hold split
  - Pass condition: lead sign-off; no hard zoom or loading-screen-style wipe observed

- **Manual check: shell chrome visual consistency**
  - Setup: view tab strip and header against Mission HUD's own screens side by side
  - Verify: chamfered-rectangle grammar, palette, iconography, motion contract match; chrome does not visually match any individual room's own register
  - Pass condition: lead sign-off

- **Manual check: draw-call budget**
  - Setup: Remote Debugger attached, a complete Sanctuary UI scene with a room hosted
  - Verify: draw calls ≤ 60 DC for the scene, ≤ 200/frame project-wide including everything else on screen
  - Pass condition: measured value recorded in evidence doc

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/story-013-visual-audio-pass-evidence.md` + sign-off, including a recorded draw-call measurement via Remote Debugger

**Status**: [x] Created — `production/qa/evidence/story-013-visual-audio-pass-evidence.md` (2026-07-24, partial — see evidence doc for exactly what's live-verified vs. blocked on missing diorama content). Diorama mechanism now real (2026-07-25): `tests/integration/sanctuary-ui/diorama_test.gd` (8/8 passing) covers fixed-position rendering, habitat occupancy, and pull-back triggering. Evidence doc itself not yet re-verified via a fresh screenshot pass — real art still doesn't exist (ComfyUI/ZLUDA driver failure), so a new screenshot would only show colored rects, not a meaningfully different visual verdict.

---

## Dependencies

- Depends on: Story 001 (chrome/RoomHost structure), Story 002 (tab strip), Story 007 (room switch triggers the drawer-slide), Story 009/010 (DEPARTING/DEPARTING_TO_LOADOUT beats)
- Unlocks: Story 014 (experiential playtest builds on a visually-complete implementation)
