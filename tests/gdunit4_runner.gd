# GdUnit4 test runner — invoked locally and by /smoke-check.
# NOT used by CI — .github/workflows/tests.yml uses the MikeSchulze/gdUnit4-action
# GitHub Action directly, which does not depend on this file.
#
# Usage (TD-test-003 fix — the previous version called a nonexistent run_tests()
# method; GdUnitTestCIRunner actually self-drives from OS.get_cmdline_args() once
# added to the scene tree, matching addons/gdUnit4/bin/GdUnitCmdTool.gd's own pattern):
#   godot --headless --script tests/gdunit4_runner.gd -- -a res://tests --ignoreHeadlessMode
#
# Any GdUnitTestCIRunner CLI option (-a, -i, -c, -conf, -rd, -rc, etc. — see
# addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd's _cmd_options) may be
# passed after the `--` separator. Omitting all options prints help and exits
# without running anything — always pass at least `-a res://tests`.
extends SceneTree

func _init() -> void:
	var runner_script := load("res://addons/gdUnit4/src/core/runners/GdUnitTestCIRunner.gd")
	if runner_script == null:
		push_error("GdUnit4 not found. Install via AssetLib or addons/.")
		quit(1)
		return
	var runner: Node = runner_script.new()
	root.add_child(runner)
