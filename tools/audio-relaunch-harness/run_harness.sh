#!/usr/bin/env bash
# Story 005 (epic-12-audio-system) AC-13 real process-relaunch harness.
#
# Runs 2 genuinely separate headless Godot processes against this project:
# "write" sets Music volume to 40% and saves it, then the process fully
# exits; "read" is a brand-new process whose AudioSystem._ready() runs its
# real disk-load path. If it reports 40.0, the value survived a real
# process boundary -- this is not an in-process simulation.
#
# Usage: tools/audio-relaunch-harness/run_harness.sh [path-to-godot-exe]
set -euo pipefail

GODOT_EXE="${1:-/c/Users/Shaukan/Desktop/Godot_v4.6.2-stable_win64.exe}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS_SCRIPT="res://tools/audio-relaunch-harness/relaunch_harness.gd"

cd "$PROJECT_DIR"

echo "=== Phase 1: write (process A) ==="
WRITE_OUTPUT=$("$GODOT_EXE" --headless --path . --script "$HARNESS_SCRIPT" -- write 2>&1)
echo "$WRITE_OUTPUT"
if ! echo "$WRITE_OUTPUT" | grep -q "HARNESS_WRITE_RESULT=0"; then
	echo "FAIL: write phase did not report a successful save (Error 0)."
	exit 1
fi

echo "=== Phase 2: read (process B, a genuinely separate process) ==="
READ_OUTPUT=$("$GODOT_EXE" --headless --path . --script "$HARNESS_SCRIPT" -- read 2>&1)
echo "$READ_OUTPUT"
if ! echo "$READ_OUTPUT" | grep -q "HARNESS_READ_MUSIC_VOLUME=40.000000"; then
	echo "FAIL: read phase (fresh process) did not see the persisted 40% Music volume."
	exit 1
fi

echo "PASS: AC-13 verified -- Music volume survived a real process kill/relaunch."
