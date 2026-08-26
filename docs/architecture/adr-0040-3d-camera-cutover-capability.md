# ADR-0040: 3D Camera Cutover Capability

## Status

Accepted

## Date

2026-08-25

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Rendering / Input |
| **Knowledge Risk** | LOW — `Camera3D.current`, `Camera2D.enabled` are stable pre-4.x APIs. |
| **References Consulted** | ADR-0037 (3D Visual Presentation Companion Layer), ADR-0039 (3D Interaction and Picking Layer) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | **Not live-verified this session** (explicit "no testing" constraint). This ADR's entire purpose is to make the eventual cutover a single, obvious, reviewable flip once live verification does happen — not to perform that verification now. See `docs/engine-reference/godot/VERSION.md`'s existing "Glow rework" entry for a precedent finding on this exact scene (an `use_hdr_2d` live test that found a real, non-obvious global side effect) — the camera cutover carries a comparable class of risk (everything currently rendered via Camera2D's 2D pipeline would need to look correct from Camera3D's 3D pipeline instead) and must go through the same kind of live check before shipping. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0037 (3D companions must exist for everything a cutover scene needs to show), ADR-0039 (3D picking must exist for placement input to keep working post-cutover) |
| **Enables** | Epic 15 Phase 4 completion, once live-verified |
| **Blocks** | None |
| **Ordering Note** | `ENABLE_3D_PRESENTATION_MODE` (this ADR) supersedes and subsumes ADR-0039's separate `ENABLE_3D_PICKING` constant — see Decision. Both mission scenes' two previously-independent toggles are consolidated into this one, so a future flip can't accidentally activate the camera without picking (or vice versa) and land in a half-cutover state. |

## Context

Epic 15's Phase 4 ("rendering polish / live camera & performance verification," per this project's own roadmap listing) is the step where `Camera3D` actually becomes the primary camera instead of an inert companion sitting alongside `Camera2D`. This is the single highest-risk step in the whole Epic 15/16 arc so far: every other phase added new, additive, currently-invisible infrastructure (companions the player's Camera2D view never showed, picking code gated inert per ADR-0039). Flipping the active camera is different in kind — it is the first change in this entire arc that would alter what a real player actually sees and clicks, immediately, the moment it's flipped.

This work session's standing constraint is "absolutely no testing" (explicit, twice repeated, user instruction). Performing a real camera cutover with zero live verification would risk shipping a broken or degraded game the moment `ENABLE_3D_PRESENTATION_MODE` is true — with nobody available to catch it (the user was asleep during this session). This ADR documents the deliberate choice made here: build the complete, real mechanism for a clean cutover, but leave it off, so that when a future session does the live-verification pass (Godot MCP: `run_project`, `take_screenshot`, `simulate_input` — the exact tools this session was told not to use), flipping to 3D is a single boolean, not a multi-file scramble.

## Decision

### `ENABLE_3D_PRESENTATION_MODE: bool = false`

A single constant, declared identically in both `mission_scene.gd` and `the_gap.gd`, replacing ADR-0039's per-scene `ENABLE_3D_PICKING` (deleted as a separate symbol — folded into this one). When true, a scene should:

1. Set `Camera3D.current = true` and `Camera2D.enabled = false` (not just deprioritized — actually disabled, so no 2D content silently keeps rendering underneath/behind the 3D view).
2. Use `Picking3D` (ADR-0039) for click-to-place input instead of `Grid.world_to_cell(get_global_mouse_position())`.

Implemented as a single new method per scene, `_apply_presentation_mode() -> void`, called once from `_ready()`:

```gdscript
func _apply_presentation_mode() -> void:
    _camera_3d.current = ENABLE_3D_PRESENTATION_MODE
    _camera.enabled = not ENABLE_3D_PRESENTATION_MODE
```

`_unhandled_input()`'s existing `if ENABLE_3D_PICKING:` branch (ADR-0039) is repointed to `if ENABLE_3D_PRESENTATION_MODE:` — same gated structure, same dormancy guarantee, just one fewer independently-flippable symbol so the two can't drift out of sync.

### Why not build more than this (e.g. don't attempt a real "polish pass")

Epic 15's Phase 4 name bundles two different things: (a) the mechanical camera cutover (this ADR), and (b) live performance/visual verification and polish. (b) is explicitly **not attempted** here — polishing lighting, shadows, post-processing, or performance for a camera view that has literally never been seen rendering (Camera3D has been `current = false` since Epic 15 Story 003) would be tuning blind. Any visual parameter chosen now (light energy, shadow bias, fog, tonemap) would be a guess with no live feedback loop to correct it — directly the failure mode `docs/engine-reference/godot/VERSION.md`'s Glow rework entry already documents happening once this session with `use_hdr_2d` (a values-only change that turned out to have a large, non-obvious, only-discoverable-live side effect). Building speculative polish now would risk compounding that exact class of mistake with zero ability to catch it before the user wakes up.

## Alternatives Considered

### Alternative 1: Flip the camera now, ship it

- **Cons**: No live verification of any kind occurred this session. A camera positioned/angled wrong, missing lighting causing an all-black 3D view, incorrect FOV, or picking math with a sign error would all be plausible, undetected failure modes that would present as "the game is broken" the next time it's launched.
- **Rejection reason**: Same reasoning as ADR-0039's Alternative 2 — do not gamble the shipping game's core interaction loop and default rendering on unverified code, when the user explicitly asked for no testing this session.

### Alternative 2: Two independent toggles (keep ADR-0039's `ENABLE_3D_PICKING` separate from a new camera toggle)

- **Cons**: Two booleans that must always move together in practice (3D picking with a 2D camera still active is nonsensical; a 3D camera with 2D-only picking would let players see the 3D world but never interact with it) invites exactly the kind of drift bug this whole session's design principle (dormancy-by-construction) exists to prevent.
- **Rejection reason**: Consolidated into one symbol. Simpler is safer here — fewer independently-wrong states are reachable.

## Consequences

### Positive

- The actual cutover, whenever it's live-verified, is a one-line change (`false` → `true`) plus a `/code-review` pass — not a scramble across two scene files to remember every place that needs updating.
- `Camera2D.enabled = false` (not just losing `current`) is explicit — prevents a half-cutover state where 2D content keeps compositing invisibly underneath.

### Negative

- Phase 4 remains functionally incomplete from the roadmap's own framing — the live verification and rendering-polish half of "rendering polish / live camera & performance verification" is not done and cannot be honestly claimed as done. This is the same honest-scope-reporting pattern this session already applied to TD-hero-001 (design-complete, implementation-not-started, explicitly not conflated).
- ~~`_apply_presentation_mode()`'s `Camera2D.enabled = false` does not actually hide 2D world content~~ — **fixed 2026-08-26**, see Validation Criteria.

### Neutral

- `ENABLE_3D_PICKING` (ADR-0039) is removed as a standalone symbol in favor of `ENABLE_3D_PRESENTATION_MODE` (this ADR) — noted here so a reader of ADR-0039 isn't confused finding it gone from the live code.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| A future session flips `ENABLE_3D_PRESENTATION_MODE` without running a live verification pass first | Low — this ADR's own text, plus ADR-0039's Ordering Note, both name the requirement | High — could ship a broken or blank 3D view | Both ADRs' Ordering Notes; the constant's own doc comment |
| Rendering-polish work (lighting/shadows/post-processing) never gets scheduled because Phase 4 is marked "capability built" | Medium | Low-Medium — cosmetic risk, not correctness risk | Explicitly named as NOT done in Consequences/Negative, so it isn't silently dropped from tracking |

## Performance Implications

None while `ENABLE_3D_PRESENTATION_MODE` is false — `_apply_presentation_mode()` is two field assignments called once at `_ready()`, no per-frame cost either way.

## Migration Plan

1. This ADR + the consolidated toggle + `_apply_presentation_mode()` (this commit).
2. A future, separate, live-verified session: flip `ENABLE_3D_PRESENTATION_MODE = true` in a throwaway/dev context, run the actual scene via Godot MCP, screenshot it, verify picking resolves the same cells the 2D path would have, verify no black/broken rendering.
3. Only after step 2 passes on both `MissionScene.tscn` and `the_gap.tscn`: consider it safe to ship true as the default, and do the actual lighting/shadow/post-processing polish pass with real visual feedback.

## Validation Criteria

- [x] `ENABLE_3D_PRESENTATION_MODE` constant exists, defaults false, in both mission scene controllers.
- [x] `_apply_presentation_mode()` sets both `Camera3D.current` and `Camera2D.enabled` together, never independently.
- [x] ADR-0039's `ENABLE_3D_PICKING` branch repointed to the new consolidated constant.
- [x] **Partially live-verified (2026-08-26)** — a Godot MCP session (`ENABLE_3D_PRESENTATION_MODE` temporarily flipped `true` at runtime only, never committed as `true`) confirmed `_apply_presentation_mode()` itself works correctly (`Camera3D.current` / `Camera2D.enabled` flip together as designed) and found two real, now-fixed bugs this ADR's own Migration Plan anticipated finding:
  1. **`Camera3D`'s baked rotation pointed at the sky, not the grid.** `MissionScene.tscn`/`the_gap.tscn`'s `Camera3D.transform` encoded `rotation_degrees.x = +55°` — verified via raycast that this produces a ray with a *positive* Y normal (pointing up/away), missing the ground plane entirely. The correct value is `-55°` (ray normal Y goes negative, correctly hits the ground plane at the grid's center for a screen-center pick). Fixed in both `.tscn` files. This was a pure sign error, not a "needs art polish" judgment call — confirmed objectively via raycast hit-testing, not eyeballed.
  2. **Camera2D.enabled = false does NOT hide 2D world content.** Godot composites 2D (`CanvasItem`) and 3D content independently — disabling a `Camera2D` only changes which pan/zoom transform is *applied*, it does not stop `Sprite2D`/`TileMap`/other `CanvasItem` content from rendering and fully occluding the 3D layer underneath. Confirmed via screenshot: with the camera fixed and `ENABLE_3D_PRESENTATION_MODE=true`, the 3D scene was still completely hidden behind the still-fully-visible 2D grid/HUD. Manually hiding `GameplayRoot`'s 2D-only children (`GridVisual`, `MonstersContainer`, `Hero`, `TowerInstance`) confirmed the 3D content (tower meshes, monster billboards) renders correctly once the 2D layer is actually hidden. **Not fixed here** — see Consequences/Negative below, this is real remaining scope for whoever does the actual cutover.
- [x] **Item 2 above (2D-content hiding) fixed (2026-08-26).** `_apply_presentation_mode()` in both `mission_scene.gd` and `the_gap.gd` now also toggles `.visible` on `_grid_visual`, `_hero`, `_monsters_container`, and a new `_dynamic_visuals_root` node — NOT the whole `GameplayRoot` (which also owns the `HUD` CanvasLayer as a child, so hiding it wholesale would take the HUD down too). `_dynamic_visuals_root` is a new `Node2D` every dynamically-spawned 2D visual (`TowerInstance`, `ProjectileVisual`, placement/death VFX — 7 call sites in `mission_scene.gd`, 1 in `the_gap.gd`) now gets added to instead of directly under the scene root, so hiding it correctly covers present AND future dynamic content through one node, with zero per-call-site checks. Live-verified via Godot MCP in both scenes: with `ENABLE_3D_PRESENTATION_MODE=true`, all four nodes report `visible=false` and the 3D scene renders through cleanly (screenshot-confirmed) without any manual intervention — this closes the gap this ADR's own 2026-08-26 addendum found (previously required manually hiding these same nodes by hand to see the 3D content at all).

## GDD Requirements Addressed

Foundational — no direct GDD requirement, matches ADR-0037/ADR-0039's own framing.

## Related

- ADR-0037 (3D visual companions)
- ADR-0039 (3D picking — its `ENABLE_3D_PICKING` is superseded by this ADR's consolidated toggle)
- `docs/engine-reference/godot/VERSION.md` — Glow rework entry (precedent for "values-only 3D/HDR changes can have large non-obvious live side effects")
