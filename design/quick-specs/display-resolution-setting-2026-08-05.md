# Quick Design Spec: Display Resolution Setting

**Type**: Addition
**System**: Main Menu — Settings panel (`design/quick-specs/main-menu-2026-08-01.md`)
**GDD Reference**: None (below systems-index tracking threshold, matching the base Main Menu spec's own rationale)
**Date**: 2026-08-05

## Change Summary

Add a window Resolution dropdown and a Fullscreen toggle to the existing
Settings panel, alongside the 4 volume sliders. Persists across sessions.
Deliberately scoped to window/display mode only — does **not** touch the
separately-tracked "UI scaling" accessibility item (`design/accessibility-
requirements.md`, still "Not Started"), which is a different, independent
control (UI element scale vs. window pixel size).

## Motivation

No display/resolution control exists anywhere in the project today — the
window is hardcoded to 1280x720 windowed via `project.godot`, with no way
for a player to run at their native desktop resolution or fullscreen.
User-requested addition, not tied to a specific accessibility commitment.

## Design Delta

Current Settings panel (`main-menu-2026-08-01.md`, Core Rule 3): 4 volume
sliders only, explicitly noting "UI scaling... deliberately not built here."
This spec adds 2 new controls to that same panel, independent of that
still-open UI-scaling item.

## New Rules / Values

1. **Resolution dropdown** (`OptionButton`): a curated list of 16:9
   resolutions at or above the project's base design resolution —
   `1280x720` (default), `1600x900`, `1920x1080`, `2560x1440`. Not a
   dynamic probe of the display's supported modes — a fixed, curated list
   matching this project's existing "curated, not exhaustive" pattern
   (e.g. the 3-slot save system).
2. **Fullscreen toggle** (`CheckButton`): Windowed (default) / Fullscreen
   (`DisplayServer.WINDOW_MODE_FULLSCREEN` — borderless, native desktop
   resolution).
3. **Interaction rule**: the Resolution dropdown is disabled
   (`Control.FOCUS_NONE` + greyed) whenever Fullscreen is checked, since
   fullscreen always uses the native desktop resolution, not the dropdown
   value. Re-enabled when Fullscreen is unchecked, restoring the window to
   the last-selected dropdown resolution.
4. **`project.godot` gets a stretch-mode config it currently lacks**:
   `window/stretch/mode="canvas_items"`, `window/stretch/aspect="keep"`.
   Required for resolution switching to scale the UI proportionally
   instead of distorting/clipping it (today's `disabled` default is 1:1
   pixel mapping — every anchor-driven layout in the project would clip
   or leave dead space at any resolution other than the hardcoded
   1280x720). This is a project-wide change, not scoped to Main Menu only
   — it affects how every scene's UI scales, called out explicitly since
   it's a real, visible side effect beyond just this one panel.
5. **Persistence**: new `user://display_settings.cfg` (2 keys: resolution
   index, fullscreen bool), written through immediately on change — same
   write-through-on-drag convention the volume sliders already use, same
   rationale (a device preference shouldn't be lost on an ungraceful
   exit). Loaded and applied in `MainMenu._ready()`, before the rest of
   `_ready()` runs, so the window is already in the player's last-chosen
   state by the time the menu is visible. Self-contained in
   `main_menu.gd` (matching how the volume sliders call `GAudioSystem`
   directly rather than routing through a new Autoload) — no new
   Autoload/system is introduced for this.
6. Both new controls reuse the existing `FocusRingFactory`/Tab-focus-
   containment pattern already wired for the Settings panel's other 5
   controls — no new pattern introduced.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| Main Menu (`main_menu.gd`/`.tscn`) | New Settings panel controls, new `_ready()` load-and-apply step | Update `main_menu.gd`/`.tscn` |
| `project.godot` | New `window/stretch` config | Update `[display]` section |
| `main_menu_test.gd` | New tests for dropdown/toggle behavior, interaction rule, persistence | Add tests |

## Acceptance Criteria

- [ ] Selecting a resolution while Windowed applies it immediately via `DisplayServer.window_set_size()`
- [ ] Checking Fullscreen switches to `DisplayServer.WINDOW_MODE_FULLSCREEN` and disables the Resolution dropdown; unchecking restores Windowed at the last-selected dropdown resolution
- [ ] Both settings persist to `user://display_settings.cfg` and are re-applied on next boot
- [ ] `project.godot`'s new stretch-mode config does not break existing UI layouts at the default 1280x720 (regression-checked, not just assumed)
- [ ] Focus rings and Tab-focus containment work correctly on both new controls, matching the existing 5 Settings controls
- [ ] No regression in `main_menu_test.gd`'s existing 23 tests

## GDD Update Required?

No — Main Menu has no GDD (below tracking threshold, per the base spec).
