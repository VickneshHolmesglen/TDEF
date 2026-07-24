extends Control

## SanctuaryScene — hosts the real Sanctuary UI shell.
##
## Real bug found and fixed 2026-07-20: `SceneManager.transition_to_sanctuary()`
## (Autoload #6, ADR-0002) is called automatically on every `hero_died`,
## `mission_phase_changed(new_phase="MISSION_COMPLETE")`, and the Pause Menu's
## "Quit to Sanctuary" button — 3 real, live-triggered paths, not a
## hypothetical — but `res://src/scenes/SanctuaryScene.tscn` never existed
## anywhere in this project, so every one of those 3 paths hard-errored in
## real play. Fixed same-day by adding a placeholder-label stub scene.
##
## **Updated 2026-07-25**: Sanctuary UI (Epic 10) is now implemented and
## `/story-done`-verified (12/14 stories Complete) — the placeholder label
## has been replaced with a real instance of
## `res://src/presentation/sanctuary_ui/SanctuaryUI.tscn`. `SceneManager.
## transition_to_sanctuary()`'s 3 real trigger paths now land on the actual
## shell (tab strip, chrome, Inventory & Crafting + Menagerie rooms) instead
## of a placeholder label, for the first time since this scene was created.
## Still open: there is no mission-select UI screen (Mission Select the
## *system* exists, but nothing renders it — `MissionScene.tscn` itself
## doesn't exist), so Sanctuary UI's own Launch/Depart hand-off
## (`GMissionSelect.back_out_to_browsing()`) still lands nowhere visible;
## and Tarot Deck UI has no top-level scene/`SceneManager` entry point at
## all yet, so the Loadout hand-off is also still unwired. Both remain real,
## separately-scoped gaps (OQ-2/OQ-9 in sanctuary-ui.md) — mirroring
## `the_gap.gd`'s own precedent of "assemble already-built subsystems into
## one real scene," this file's job is only to host what already exists.
##
## No `class_name` declared — deliberately, matching `pause_menu.gd`'s own
## documented TD-workflow-001 precedent (a recurring Godot 4.6.2
## global-script-class-cache staleness gotcha for headless test runs). This
## scene is only ever loaded via `ResourceLoader.load(path) as PackedScene`,
## never referenced by static type, so a `class_name` is not needed here.
