extends Control

## TarotDeckUIScene — hosts the real Tarot Deck UI shell.
##
## Mirrors sanctuary_scene.gd's own precedent exactly: gives SceneManager's
## new transition_to_tarot_deck_ui() (2026-07-25, closing Sanctuary UI Epic
## 10 Story 010's/Tarot Deck UI Epic 11 Story 002's own flagged gap) a real,
## loadable top-level scene to land on, wrapping the already-built, already-
## tested TarotDeckUI.tscn shell (Epic 11, Stories 001-005) unmodified.
##
## No `class_name` declared — deliberately, matching sanctuary_scene.gd's/
## pause_menu.gd's own documented TD-workflow-001 precedent (a recurring
## Godot 4.6.2 global-script-class-cache staleness gotcha for headless test
## runs). This scene is only ever loaded via
## `ResourceLoader.load(path) as PackedScene`, never referenced by static
## type, so a `class_name` is not needed here.
