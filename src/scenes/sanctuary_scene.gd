extends Control

## SanctuaryScene — minimal connective-tissue stub, not the real Sanctuary UI.
##
## Real bug found and fixed 2026-07-20: `SceneManager.transition_to_sanctuary()`
## (Autoload #6, ADR-0002) is called automatically on every `hero_died`,
## `mission_phase_changed(new_phase="MISSION_COMPLETE")`, and the Pause Menu's
## "Quit to Sanctuary" button — 3 real, live-triggered paths, not a
## hypothetical — but `res://src/scenes/SanctuaryScene.tscn` never existed
## anywhere in this project, so every one of those 3 paths hard-errored in
## real play (`ResourceLoader.load()` failing, per `scene_manager.gd`'s own
## `push_error("... failed to load as PackedScene.")` guard).
##
## The Sanctuary UI system itself (`systems-index.md` #24) is still
## "Not Started" — no GDD exists for crafting/menagerie/defense-building/
## equipment-forge screens, tab layout, or navigation, and there is no
## mission-select UI screen either (Mission Select the *system* exists, but
## nothing renders it). Building either of those is out of scope here; this
## file's only job is to give SceneManager's already-built, already-tested
## `transition_to_sanctuary()` contract a real, loadable scene to land on —
## mirroring `the_gap.gd`'s own precedent of "assemble already-built
## subsystems into one real scene, not new design." Deliberately does NOT
## wire a "launch mission" round-trip: `SceneManager`'s own
## `_mission_scene_path` default (`res://src/scenes/MissionScene.tscn`) has
## the identical "never existed" gap, and deciding what that generic path
## should actually point to is a Mission-Select-UI design question, not this
## stub's to answer unilaterally.
##
## No `class_name` declared — deliberately, matching `pause_menu.gd`'s own
## documented TD-workflow-001 precedent (a recurring Godot 4.6.2
## global-script-class-cache staleness gotcha for headless test runs). This
## scene is only ever loaded via `ResourceLoader.load(path) as PackedScene`,
## never referenced by static type, so a `class_name` is not needed here.
