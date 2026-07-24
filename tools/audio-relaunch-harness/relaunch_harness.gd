extends SceneTree

## Story 005 (epic-12-audio-system), AC-13's real process-relaunch harness.
##
## This project's normal in-process gdUnit4 runner cannot exercise a genuine
## process kill/relaunch (per the story's own explicit flag) -- this script
## is run as a genuinely separate Godot process each phase, driven by
## `run_harness.sh`. `write` sets a non-default Music volume and saves it to
## `user://audio_settings.cfg` via the real `AudioSystem.save_settings_to_disk()`,
## then the process exits entirely. `read` launches a brand-new process,
## letting `AudioSystem._ready()`'s own real disk-load path run, and reports
## what it sees -- proving the value survived a genuine process boundary,
## not an in-process simulation.


var _mode: String = ""
var _frame_count: int = 0

## Autoloads' own `_ready()` runs during the tree's normal frame processing,
## not synchronously inside `_initialize()` -- a few real frames must pass
## before `GAudioSystem._ready()` (bus configuration + disk-load) has
## actually happened. Waiting here is not the same shortcut as an in-process
## "simulate relaunch": each phase is still its own genuinely separate OS
## process with its own fresh engine boot.
const READY_WAIT_FRAMES: int = 5


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_mode = args[0] if args.size() > 0 else ""


func _process(_delta: float) -> bool:
	_frame_count += 1
	if _frame_count < READY_WAIT_FRAMES:
		return false

	var audio: Node = get_root().get_node_or_null("GAudioSystem")
	if audio == null:
		printerr("HARNESS_ERROR=GAudioSystem autoload not found")
		quit(1)
		return true

	match _mode:
		"write":
			audio.call(&"set_bus_volume_percent", &"Music", 40.0)
			var err: int = audio.call(&"save_settings_to_disk")
			print("HARNESS_WRITE_RESULT=%d" % err)
		"read":
			var music_volume: float = audio.call(&"get_bus_volume_percent", &"Music")
			print("HARNESS_READ_MUSIC_VOLUME=%f" % music_volume)
		_:
			printerr("HARNESS_ERROR=Usage: --script relaunch_harness.gd -- write|read")
			quit(1)
			return true

	quit(0)
	return true
