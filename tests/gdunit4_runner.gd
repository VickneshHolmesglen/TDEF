# GdUnit4 test runner — invoked locally and by /smoke-check.
# NOT used by CI — .github/workflows/tests.yml uses the MikeSchulze/gdUnit4-action
# GitHub Action directly, which does not depend on this file.
#
# Usage:
#   godot --headless --script tests/gdunit4_runner.gd -- -a res://tests --ignoreHeadlessMode
#
# Any GdUnitTestCIRunner CLI option (-a, -i, -c, -conf, -rd, -rc, etc. — see
# addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd's _cmd_options) may be
# passed after the `--` separator. Omitting all options prints help and exits
# without running anything — always pass at least `-a res://tests`.
#
# TD-test-005 fix (2026-07-31) — the previous version (post-TD-test-003) called
# runner.get_cmdline_args(), which returns OS.get_cmdline_args() unless
# _debug_cmd_args is set. As of Godot 4.6, OS.get_cmdline_args() no longer
# includes args passed after `--` (verified live: they only show up in
# OS.get_cmdline_user_args() now) — a post-cutoff engine behavior change, not
# documented anywhere this project had already tracked. The result was silent:
# no error, just GdUnitTestCIRunner printing its help text and exiting 0
# without running a single test. Fixed by reading OS.get_cmdline_user_args()
# directly and feeding it to the runner via its _debug_cmd_args override.
#
# CmdArgumentParser.parse() (addons/gdUnit4/src/cmd/CmdArgumentParser.gd) also
# pops args off the front of whatever list it's given until it finds one
# containing "GdUnitCmdTool.gd" (the tool name GdUnitTestCIRunner passes to it),
# then starts parsing from the next token — normally satisfied by "--script"'s
# own path when run via OS.get_cmdline_args(). Since we bypass that, a sentinel
# token is prepended so the parser has something to skip past.
extends SceneTree

func _init() -> void:
	var runner_script := load("res://addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd")
	if runner_script == null:
		push_error("GdUnit4 not found. Install via AssetLib or addons/.")
		quit(1)
		return
	var runner: Node = runner_script.new()
	var args := PackedStringArray(["GdUnitCmdTool.gd"])
	args.append_array(OS.get_cmdline_user_args())
	runner.set("_debug_cmd_args", args)
	root.add_child(runner)
