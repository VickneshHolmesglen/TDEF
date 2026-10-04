class_name UserDataPaths
extends RefCounted
## Single root for every file the game writes under user:// (saves, audio and
## display settings).
##
## Under a gdUnit4 run the root is user://test_sandbox/ instead of user://, so
## the test suite can never overwrite a developer's real save slots or
## settings. Found by the 2026-10-04 smoke check: a full suite run had
## rewritten save_slot_0.dat and audio_settings.cfg in the real profile.
##
## Detection is by command line: the local runner (tests/gdunit4_runner.gd),
## CI's gdUnit4-action (GdUnitCmdTool.gd) and the editor's GdUnit panel all
## launch Godot with a gdUnit4 script or scene path among the arguments.

const SANDBOX_DIR_NAME: String = "test_sandbox"

static var _root: String = ""


## "user://" in the shipped game, "user://test_sandbox/" under gdUnit4.
## Always ends with a slash; the sandbox directory is created on first use.
static func root() -> String:
	if _root.is_empty():
		_root = "user://"
		if is_test_run():
			_root = "user://%s/" % SANDBOX_DIR_NAME
			if not DirAccess.dir_exists_absolute(_root):
				DirAccess.make_dir_recursive_absolute(_root)
	return _root


static func is_test_run() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg.to_lower().contains("gdunit"):
			return true
	return false
