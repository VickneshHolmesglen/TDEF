# Test Infrastructure

**Engine**: Godot 4.6.2
**Test Framework**: GdUnit4
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-05-16

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

**In-editor**: Godot Editor → GdUnit4 panel → Run All

**Headless (local/manual)**:
```
godot --headless --script tests/gdunit4_runner.gd -- -a res://tests --ignoreHeadlessMode
```
Note: CI does **not** use this script — `.github/workflows/tests.yml` runs tests via the
`MikeSchulze/gdUnit4-action` GitHub Action directly. This invocation is for local developer
use and for agent sessions (e.g. `/smoke-check`) that need a headless run without a full CI job.

## Known Gotcha: New `class_name` Files Need a Cache Update (TD-workflow-001)

A bare `godot --headless` **game-mode** boot (used by headless test runs and by AI-agent
sessions driving the game live) does **not** rescan the project for new `class_name`
declarations — only the editor does that automatically. If you just added a new
`class_name` file and immediately see `"Could not find type 'X' in the current scope"` or
(if the new class is referenced by an Autoload) `"Failed to instantiate an autoload... does
not inherit from 'Node'"`, this is why.

**Fix**: run `godot --headless --editor --quit` once from the project root. This performs a
full editor-mode rescan (including `update_scripts_classes`) and rewrites
`.godot/global_script_class_cache.cfg` correctly and durably — **no GUI window is opened**,
so this works in a fully headless agent session with no user-mediated editor launch required.
Verified 2026-07-08 (`TD-workflow-001`): confirmed it both adds a newly-created `class_name`
and prunes a deleted one. If for some reason this isn't available in your context, the cache
entry can also be added by hand — see `TD-workflow-001` in `docs/tech-debt-register.md` for
the exact format and a worked example.

## Known Gotcha: New/Edited `strings.csv` Rows Need the Same Reimport

Same root cause as the `class_name` cache gotcha above: `assets/localization/strings.csv`'s
compiled `Translation` resource (`strings.en.translation`, gitignored) is only rebuilt by an
editor-mode filesystem scan. A headless game-runtime session (test run or AI-agent `run_project`)
loads whichever `.translation` was last compiled, not the current `.csv` — so a newly-added or
-edited localization key renders as the literal key string in-game (e.g. `INVENTORY_FOO_HEADER`
instead of its real text), with no error. **Fix**: the same `godot --headless --editor --quit`
pass used for the `class_name` cache also reimports `strings.csv`. Run it after any `strings.csv`
edit, before trusting a headless/MCP UI verification pass. See
`docs/engine-reference/godot/VERSION.md`'s Project-Specific API Tracking table for the full
writeup (discovered 2026-09-16).

## Installing GdUnit4

1. Open Godot → AssetLib → search "GdUnit4" → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: `res://addons/gdunit4/` exists

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]()`
- **Example**: `hero_damage_formula_test.gd` → `test_base_attack_returns_expected_damage()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` | ADVISORY |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging. Never disable or skip failing tests to make
CI pass — fix the underlying issue.
