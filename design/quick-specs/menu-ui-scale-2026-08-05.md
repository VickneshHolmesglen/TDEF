# Quick Design Spec: Menu UI Scale Slider

**Type**: Addition
**System**: Main Menu — Settings panel (`design/quick-specs/main-menu-2026-08-01.md`, `design/quick-specs/display-resolution-setting-2026-08-05.md`)
**GDD Reference**: `design/accessibility-requirements.md` — Visual Accessibility, "UI scaling" row (Standard tier, "Not Started")
**Date**: 2026-08-05

## Change Summary

Add a UI Scale slider (75%-150%, default 100%) to the Settings panel,
scaling Main Menu's own interactive Controls (buttons, panels, text) —
**not** the background art, and **not** the in-game HUD. Closes the
Main-Menu portion of the accessibility doc's "UI scaling" commitment;
HUD scale is explicitly out of scope here (see below).

## Motivation

`design/accessibility-requirements.md` commits to UI scaling at Standard
tier — "Range 75%–150%. Default 100%. Test all screens at min and max.
HUD scale independent from menu scale." Flagged as deferred in both
prior Main Menu passes. This closes the Main Menu half of that
commitment now that the pattern (Settings panel row + persisted
`user://` config) is already established from the resolution setting.

## Design Delta

Current Settings panel (`display-resolution-setting-2026-08-05.md`): 4
volume sliders + Resolution dropdown + Fullscreen toggle. This spec adds
1 more row, independent of both.

**Scope note, not a silent partial claim**: the accessibility doc's item
covers "All UI elements" and explicitly calls out HUD scale as a
*separate* value from menu scale. No real HUD screen with production UI
elements exists yet to scale (`mission_hud.gd` exists but its own UI
build-out is separate, unrelated work) — HUD scale stays "Not Started"
after this pass. Only the Main Menu half is closed. Any other screen
(Inventory, Sanctuary UI, Defense Building, etc.) is likewise untouched.

## New Rules / Values

1. **UI Scale slider** (`HSlider`, matching the volume sliders' visual
   pattern): range 75-150, step 1, default 100, in the Settings panel.
2. **What gets scaled**: `Control.scale` applied to each of Main Menu's
   own top-level *content* groups — `TitleLabel`, `Buttons`,
   `SettingsPanel`'s inner content (`SettingsLabel`, `VolumeSliders`,
   `DisplaySettings`, `BackButton`), `LoadGamePanel`'s inner content,
   `OverwriteConfirmPanel`'s inner content. **Not** applied to the 3
   full-rect `ColorRect` panel backgrounds themselves (scaling a
   full-rect node by `Control.scale` grows it away from its own local
   origin, pushing far-right/bottom content off-screen at >100% — scale
   the content *inside* each panel instead, which is already
   top-left-anchored and grows predictably). **Not** applied to
   `Background` (decorative art, not "UI" — matches the accessibility
   doc's own framing of this as a legibility feature for interactive/
   text elements, not the illustrated scene).
3. **Persistence**: stored in the same `user://display_settings.cfg`
   ConfigFile the resolution setting already uses (1 more key,
   `ui_scale`, in the same `display` section) — not a new file, since
   both are Main-Menu-local display/presentation preferences with
   identical lifecycle (loaded once at the top of `_ready()`, written
   through immediately on change). Applied on load, before the rest of
   `_ready()` runs, alongside the existing resolution/fullscreen load
   step.
4. Reuses the existing `FocusRingFactory`/Tab-focus-containment pattern
   for the new slider — no new pattern introduced.
5. **Interaction with the Resolution setting**: independent — UI Scale
   affects Control-local rendering scale, Resolution affects the real
   window/viewport pixel size (already handled by `canvas_items` stretch
   mode). Both can be combined freely; no interaction rule needed
   between them (verified live before finalizing this spec's approach,
   not just assumed).

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| Main Menu (`main_menu.gd`/`.tscn`) | New Settings panel slider, new `_ready()` scale-application step | Update `main_menu.gd`/`.tscn` |
| `main_menu_test.gd` | New tests for scale application, range clamping, persistence | Add tests |
| `design/accessibility-requirements.md` | "UI scaling" row updated to reflect Main-Menu-only partial completion | Update row + note (pending approval) |

## Acceptance Criteria

- [ ] Dragging the slider scales Main Menu's buttons/panels/text live, without moving the Background art or breaking layout at 75% or 150%
- [ ] Value persists to `user://display_settings.cfg` (`ui_scale` key) and re-applies on next boot
- [ ] Focus ring and Tab-focus containment work correctly on the new slider, matching the other 6 Settings controls
- [ ] No regression in `main_menu_test.gd`'s existing 30 tests
- [ ] Live-verified via Godot MCP at both 75% and 150% (not just the default) — screenshots confirm no clipped/overlapping/off-screen content in Settings, Load Game, or Overwrite Confirm panels

## GDD Update Required?

Yes — `design/accessibility-requirements.md`, "UI scaling" row: change
status from "Not Started" to a note reflecting Main-Menu-only completion
(HUD and other screens remain "Not Started"). Exact wording proposed
separately, after this spec is approved.
