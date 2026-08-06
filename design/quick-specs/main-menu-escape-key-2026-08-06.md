# Quick Design Spec: Main Menu Escape/ui_cancel Handling

**Type**: Tweak
**System**: Main Menu (`design/quick-specs/main-menu-2026-08-01.md`)
**GDD Reference**: None (below tracking threshold, per the base Main Menu spec)
**Date**: 2026-08-06

## Change Summary

Wire Godot's built-in `ui_cancel` action (Escape key, gamepad East/B
button — already the project's established convention, see Sanctuary
UI/Tarot Deck UI) on Main Menu: opens Settings when no modal is open,
closes whichever modal (Settings/Load Game/Overwrite Confirm) is
currently open. User-reported gap: no Escape handling existed at all.

## Motivation

Every other real screen in the project (Sanctuary UI, Tarot Deck UI)
already responds to `ui_cancel`. Main Menu was the one screen where it
did nothing — a real, reported usability gap, not a cosmetic nice-to-have.

## Design Delta

No prior rule existed (Main Menu has no GDD). This is new behavior, not
a change to documented behavior.

## New Rules / Values

1. **No modal open** (bare main menu, only the 5 nav buttons visible):
   `ui_cancel` triggers the same path as clicking **Settings** —
   `_on_settings_pressed()`. Chosen over "do nothing" because it gives
   Escape a real purpose at the entry screen (the user's own reported
   expectation), and over "quit the game" because an accidental Escape
   press should never risk exiting unexpectedly.
2. **A modal is open**: `ui_cancel` triggers that modal's own existing
   Back/Cancel path exactly — `_on_settings_back_pressed()` for Settings,
   `_on_load_game_back_pressed()` for Load Game,
   `_on_overwrite_cancel_pressed()` for Overwrite Confirm. No new
   close logic — reuses the exact same functions each panel's own Back/
   Cancel button already calls.
3. Exactly one modal can be open at a time (existing invariant, unchanged)
   — `_input()` only needs to check which one, not handle overlap.
4. Implemented as a single `_input(event)` override checking
   `event.is_action_pressed(&"ui_cancel")`, matching Sanctuary UI/Tarot
   Deck UI's own established pattern exactly (same action name, same
   input method, same "no InputMap override needed" note).

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| Main Menu (`main_menu.gd`) | New `_input()` override | Update `main_menu.gd` |
| `main_menu_test.gd` | New tests for both branches | Add tests |

## Acceptance Criteria

- [ ] Pressing Escape with no modal open shows the Settings panel, identically to clicking Settings
- [ ] Pressing Escape while Settings is open closes it and returns focus to the Settings button, identically to its Back button
- [ ] Pressing Escape while Load Game is open closes it and returns focus to the Load Game button, identically to its Back button
- [ ] Pressing Escape while Overwrite Confirm is open closes it and returns focus to New Game, identically to its Cancel button
- [ ] No regression in existing 33 `main_menu_test.gd` tests

## GDD Update Required?

No — Main Menu has no GDD.
