# Story 013: Visual/Audio Pass — Drawer-Slide, DEPARTING Beat, Shell Chrome Language

> **Epic**: Sanctuary UI
> **Status**: Partial (2026-07-24 — chrome styling, room-hosting composition, badge/header scale-pop, and the DEPARTING chrome-fade implemented and live-verified via Godot MCP screenshots; diorama-dependent visuals blocked on content that doesn't exist — see `production/qa/evidence/story-013-visual-audio-pass-evidence.md`. **Updated 2026-07-25**: the diorama itself is now real — see note below. **Updated 2026-08-13 (two passes)**: found real illustrated art for both structures already authored and wired (`watchtower.png` 2026-07-31, `habitat_tier_1-4.png` 2026-08-01/03) — the "no actual art" framing was itself stale. Then closed the one remaining precise gap: added a `StructureCastShadow` component giving each structure a real cast-shadow layer, satisfying the GDD's "full stacked-sprite/cast-shadow treatment" AC. All Visual/Audio ACs are now Complete — only the DEPARTING camera pull-back's already-noted "60/40 fade-vs-hold split" precise timing and any human legibility/feel verification remain unassessed by an actual human tester.)
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
- [x] Diorama uses full stacked-sprite/cast-shadow treatment; chrome uses flat/low-relief drop shadows only (purely vertical offset) — never stacked-sprite shadows on chrome. **RESOLVED 2026-08-13**: real illustrated art exists for both structures (2026-07-31/08-03). A new `StructureCastShadow` component (`src/presentation/sanctuary_ui/structure_cast_shadow.gd`) adds a distinct, code-drawn ground-contact shadow layer beneath each structure sprite — a code-drawn ellipse rather than a generated texture, per the art bible's own design test ("if removing the shadow sprite makes the object look pasted onto the ground, the layering is insufficient"), which is about the presence of a distinct ground-contact layer, not a hand-painted shadow asset specifically. Added as an earlier sibling than the structure sprite (2D tree-order compositing draws it underneath). Live-verified via Godot MCP screenshot. Chrome's own flat/low-relief drop shadows were already correct (unaffected by this change).

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

**Real art landed 2026-07-31 through 2026-08-03 (found 2026-08-13, this story's own file was never updated at the time)**: `watchtower.png` (2026-07-31) and 4 tiered `habitat_tier_1-4.png` files (2026-08-01, tier 4 added 2026-08-03) were generated via the project's manual ChatGPT workflow (per `CLAUDE.md`'s Asset Generation protocol, since local ComfyUI generation remains removed) and wired into `diorama.gd`'s `_build_watchtower_sprite()`/`_build_habitat_sprite()` as real `TextureRect` nodes, replacing the `ColorRect` placeholders described above. Confirmed via `git log` and direct file inspection that this work happened in a later session than this story's own last edit, and its own header/status was simply never revisited. Live-verified 2026-08-13 via Godot MCP screenshot (real `sanctuary_structure_built` events for `watchtower_tier_1` and `habitat_expansion_tier_4` against the real running `SanctuaryUI.tscn`): both structures render as real illustrated art, not placeholder rects. **The stacked-sprite/cast-shadow AC remains the one genuinely open item** — both structures are a single flat `TextureRect` each; the GDD's letter calls for a multi-layer composition with a distinct cast-shadow element, which neither has. Closing that fully would need either (a) new layered art assets (a separate ChatGPT-prompt-and-slice pass, out of this documentation-accuracy pass's own scope) or (b) a design decision that the current flat-illustration treatment satisfies the AC's intent well enough to revise the GDD text itself — not decided unilaterally here.

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

**Code Review (2026-07-25)**: `diorama.gd` reviewed. Found and fixed a real bug: assumed Menagerie was scene-instanced (discovered via a `"menagerie"` group, mirroring Tarot/EquipmentForge) but it's actually a real Autoload (`GMenagerie`) — the habitat occupancy count would have silently stayed stuck at 0 forever in real gameplay, since nothing is ever added to that group. Also fixed: placeholder structure rects defaulted to `MOUSE_FILTER_STOP` with no click handler, silently swallowing clicks meant for anything else; and a stale doc comment in `sanctuary_ui.gd` still claiming the pull-back needed a `Camera2D` that doesn't exist, even though it had just been implemented in the same commit. Re-verified: 163/163 across all affected suites after fixes.

**Cast-shadow layer added (2026-08-13)**: `src/presentation/sanctuary_ui/structure_cast_shadow.gd` — a pure `_draw()`-based `Control` (matches `TowerMasteryArc`'s established pure-view-component convention), drawing a code-generated ground-contact ellipse beneath each structure sprite via Godot 4.6's native `CanvasItem.draw_ellipse()`. Real gap found live during implementation: an earlier draft defined its own same-named `draw_ellipse()` helper (assuming Godot had no built-in), which the engine rejected at compile time as an incompatible override of a real, post-LLM-cutoff native method — switched to calling the native method directly. Also found and fixed live: Godot renames a second same-named sibling `Control` to an anonymous `@Control@N` rather than the expected `Shadow2` — gave each shadow a structure-type-qualified name (`Shadow_watchtower`/`Shadow_habitat_expansion`) to avoid this entirely. 3 new unit tests (`tests/unit/sanctuary-ui/structure_cast_shadow_test.gd`) + 3 new integration tests (`diorama_test.gd`). Live-verified via Godot MCP screenshot: both structures show a visible shadow at their base. Full regression: 2098/2098 passing.

---

## Dependencies

- Depends on: Story 001 (chrome/RoomHost structure), Story 002 (tab strip), Story 007 (room switch triggers the drawer-slide), Story 009/010 (DEPARTING/DEPARTING_TO_LOADOUT beats)
- Unlocks: Story 014 (experiential playtest builds on a visually-complete implementation)
