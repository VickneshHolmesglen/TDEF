extends Control

## MainMenu — the game's real boot scene (2026-08-01).
##
## Real gap closed: no Main Menu existed anywhere in this project before now
## (project.godot's `run/main_scene` booted directly into `the_gap.tscn`).
## Background art and button art are user-provided (`assets/Art Assets/Main
## Menu Clean.png` / `Main Menu Buttons.png`), processed via flood-fill
## background-keying (same technique as the Sanctuary watchtower/habitat
## art) into `assets/art/main_menu/`.
##
## Only 3 of the source art's 6 buttons are wired — PLAY, SETTINGS, QUIT.
## UPGRADES and ACHIEVEMENTS are dropped entirely: neither corresponds to
## any system in this project's systems-index (25 systems, no Upgrades or
## Achievements). ENCYCLOPEDIA is also dropped, deliberately — the real
## Encyclopedia System exists and is Approved, but its own GDD explicitly
## leaves the entry-point/screen question open (OQ-5, `encyclopedia.md`),
## specifically because a past unplanned UI-shell addition in this project
## caused cascading review problems. Deciding OQ-5 is not this task's call.
##
## PLAY calls GSceneManager.transition_to_sanctuary() directly — the same
## real, already-working entry point Tarot Deck UI's own return path and
## every hero_died/mission_complete/pause-menu-quit trigger already use
## (see sanctuary_scene.gd's own doc comment). No new SceneManager API
## needed. SETTINGS opens a minimal placeholder Control (no real Settings
## system exists anywhere in this project yet) rather than fabricating
## options that don't exist.

@onready var _settings_panel: Control = $SettingsPanel


func _ready() -> void:
	$Buttons/PlayButton.pressed.connect(_on_play_pressed)
	$Buttons/SettingsButton.pressed.connect(_on_settings_pressed)
	$Buttons/QuitButton.pressed.connect(_on_quit_pressed)
	$SettingsPanel/BackButton.pressed.connect(_on_settings_back_pressed)
	_settings_panel.visible = false


func _on_play_pressed() -> void:
	GSceneManager.transition_to_sanctuary()


func _on_settings_pressed() -> void:
	_settings_panel.visible = true


func _on_settings_back_pressed() -> void:
	_settings_panel.visible = false


func _on_quit_pressed() -> void:
	get_tree().quit()
