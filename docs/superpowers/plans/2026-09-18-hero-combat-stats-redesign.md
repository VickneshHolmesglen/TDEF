# Hero Combat & Stats Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Hero's outgoing-damage formula and stat set with the new Physical/Magic Attack split, diminishing-returns curves (Crit Chance/Crit Multiplier/Luck), numeric monster Armor/Evasion, and a combat-variance roll — closing the gap where Hero's own damage pipeline applies zero mitigation of any kind today.

**Architecture:** Hero resolves per-attack values (which attack stat, target's cached armor/evasion/elemental-resist) at emission time into flat event-payload fields, exactly mirroring TowerSystem's existing `is_armored`-resolved-before-emit pattern. `damage_status.gd` gains 3 new pure static helpers (evasion roll, mitigation resolution, variance roll) shared by both the auto-attack and skill handlers, then wires them into the existing D2/D7 pipeline. No new node types, no new EventBus signals — only new fields on 2 existing event payloads and 2 new fields on `MonsterResource`.

**Tech Stack:** Godot 4.6.2, GDScript, GdUnit4.

**Spec:** `docs/superpowers/specs/2026-09-18-hero-combat-stats-redesign-design.md`

## Global Constraints

- Every gameplay value must remain data-driven where it already is (per-monster Armor/Evasion are `@export` fields, not hardcoded) — per `.claude/rules/gameplay-code.md`.
- Zero new allocations in `_pass3c_visual_sync()`-style hot paths — N/A here (this plan touches per-attack-event resolution, not a per-frame loop), but `damage_status.gd`'s new static helpers must stay allocation-free (no new Arrays/Dictionaries per call).
- `HeroSkillAttackEvent.skill_power`/`skill_power_coefficient` field **names are kept unchanged** even though the value may now come from either Physical Attack or Magic Attack — renaming was considered and rejected to avoid unrelated churn across every existing consumer of those exact field names (per the spec's Section 3.6 correction).
- `Hero._monster_cache` entries stay a plain `Dictionary` (matching the existing established pattern) — new keys (`armor`, `evasion`, `elemental_resistances`) are read via `.get(key, default)`, never bracket access, so existing tests that construct partial cache entries by hand keep working unmodified.
- `_on_tower_attacked()` in `damage_status.gd` (the tower-damage pipeline) is **not touched** — `MonsterResource.archetype_tag`/`is_armored`'s existing 50% flat tower-mitigation role stays exactly as-is (spec AC-8).
- `hero_level` is hardcoded to `1` in the new Armor mitigation formula (a documented placeholder, per spec 3.3) — do not invent a Hero Level system as part of this plan.
- Test file conventions: `GdUnitTestSuite`, `assert_float(...).is_equal_approx(x, 0.0001)` for floats, `EventBusSpy` for signal-emission assertions, `add_child()`/`free()` lifecycle in `before_test()`/`after_test()` — follow each touched file's own existing convention exactly (see each task).

---

## Task 1: Rename Hero stats (Damage→Physical Attack, Skill Power→Magic Attack) + add Luck placeholder

**Files:**
- Modify: `src/core/hero/hero.gd` (`PLACEHOLDER_BASE_STATS` const, `_on_attack_timer_timeout()` line ~681, doc comment at `_base_stats` field ~line 153-158)
- Modify: `tests/unit/hero/hero_auto_attack_test.gd` (lines 154, 226, 242)
- Modify: `tests/unit/hero/hero_skill_system_test.gd` (lines 278, 291) — note: this changes to `physical_attack` not `magic_attack`, since `phys_cleave` (the skill under test) has `damage_type = "physical"`
- Modify: `tests/unit/hero/hero_stat_resolution_test.gd` (line 6, the `STAT` const)
- Test: same files (existing tests, updated in place — no new test file for a pure rename)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Hero._base_stats` keys `&"physical_attack"`, `&"magic_attack"`, `&"luck"` (Task 2+ will make `luck` meaningful via the diminishing curve; this task only ensures the key exists in the placeholder dict with a neutral `0.0` default — no fabricated balance number).

- [ ] **Step 1: Update `PLACEHOLDER_BASE_STATS` in `hero.gd`**

Find this block (added last session, `hero.gd` ~line 159):

```gdscript
const PLACEHOLDER_BASE_STATS: Dictionary[StringName, float] = {
	&"max_hp": 500.0,
	&"damage": 25.0,
	&"move_speed": 220.0,
	&"cdr": 0.0,
	&"crit_chance": 0.1,
	&"armor": 0.0,
	&"skill_power": 10.0,
	&"attack_range": 220.0,
	&"elemental_resist_fire": 0.0,
	&"elemental_resist_frost": 0.0,
	&"lifesteal": 0.0,
	&"tower_affinity": 1.0,
	&"crit_multiplier": 0.0,
}
```

Replace with:

```gdscript
const PLACEHOLDER_BASE_STATS: Dictionary[StringName, float] = {
	&"max_hp": 500.0,
	&"physical_attack": 25.0,
	&"move_speed": 220.0,
	&"cdr": 0.0,
	&"crit_chance": 0.1,
	&"armor": 0.0,
	&"magic_attack": 10.0,
	&"attack_range": 220.0,
	&"elemental_resist_fire": 0.0,
	&"elemental_resist_frost": 0.0,
	&"lifesteal": 0.0,
	&"tower_affinity": 1.0,
	&"crit_multiplier": 0.0,
	&"luck": 0.0,
}
```

- [ ] **Step 2: Update `_on_attack_timer_timeout()`'s stat read in `hero.gd`**

Find (~line 681):

```gdscript
	payload.base_damage = get_effective_stat(&"damage") * (1.0 + get_effective_stat(&"tower_affinity"))
```

Replace with:

```gdscript
	payload.base_damage = get_effective_stat(&"physical_attack") * (1.0 + get_effective_stat(&"tower_affinity"))
```

- [ ] **Step 3: Update the `_base_stats` field doc comment in `hero.gd`**

Find (~line 153-158):

```gdscript
## Base stat values, set from HeroResource at mission start (wired in a later story).
## Keys are the 12 stat StringNames from design/gdd/hero.md, e.g. &"max_hp", &"damage",
## &"move_speed", &"cdr", &"crit_chance", &"armor", &"skill_power", &"attack_range",
## &"elemental_resist_fire", &"elemental_resist_frost", &"lifesteal", &"tower_affinity",
## &"crit_multiplier".
var _base_stats: Dictionary[StringName, float] = {}
```

Replace with:

```gdscript
## Base stat values, set from HeroResource at mission start (wired in a later story).
## Keys are the 13 stat StringNames from design/gdd/hero.md, e.g. &"max_hp",
## &"physical_attack", &"move_speed", &"cdr", &"crit_chance", &"armor", &"magic_attack",
## &"attack_range", &"elemental_resist_fire", &"elemental_resist_frost", &"lifesteal",
## &"tower_affinity", &"crit_multiplier", &"luck".
var _base_stats: Dictionary[StringName, float] = {}
```

- [ ] **Step 4: Update `tests/unit/hero/hero_auto_attack_test.gd`**

Line 154: change `_hero._base_stats[&"damage"] = 90.0` to `_hero._base_stats[&"physical_attack"] = 90.0`.
Line 226: change `_hero._base_stats[&"damage"] = 100.0` to `_hero._base_stats[&"physical_attack"] = 100.0`.
Line 242: change `_hero._base_stats[&"damage"] = 100.0` to `_hero._base_stats[&"physical_attack"] = 100.0`.

- [ ] **Step 5: Update `tests/unit/hero/hero_skill_system_test.gd`**

Line 278: change `_hero._base_stats[&"skill_power"] = 100.0` to `_hero._base_stats[&"physical_attack"] = 100.0` (this test's skill under test, `phys_cleave`, has `damage_type = "physical"` — see `assets/data/skills/definitions/phys_cleave.tres` — so it must read Physical Attack, not Magic Attack, once Task 7 wires the branch).

Also add a code comment right above that line explaining why:

```gdscript
	# phys_cleave has damage_type == "physical" (assets/data/skills/definitions/
	# phys_cleave.tres), so it reads Physical Attack, not Magic Attack, once
	# Hero._resolve_skill_hit() branches by damage_type (Task 7).
	_hero._base_stats[&"physical_attack"] = 100.0
```

- [ ] **Step 6: Update `tests/unit/hero/hero_stat_resolution_test.gd`**

Line 6: change `const STAT: StringName = &"damage"` to `const STAT: StringName = &"physical_attack"` — this const is used purely as an arbitrary *uncapped* stat name to exercise Formula 1 in isolation (comment at line 84 confirms: "all tests above use &"damage" (uncapped, falls through the match's default branch)"); renaming preserves that role exactly, `physical_attack` also has no `_apply_stat_cap()` branch.

- [ ] **Step 7: Run the touched tests**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH from .mcp.json>" -a res://tests/unit/hero -a res://tests/unit/inventory`
Expected: all pass — this is a pure rename, no behavior change yet. (`tests/unit/inventory` included only to re-confirm the earlier-ruled-out `&"damage"` matches there are genuinely unrelated Inventory `stat_overrides` keys, unaffected by this rename.)

- [ ] **Step 8: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_auto_attack_test.gd tests/unit/hero/hero_skill_system_test.gd tests/unit/hero/hero_stat_resolution_test.gd
git commit -m "Rename Hero Damage/Skill Power stats to Physical/Magic Attack, add Luck placeholder"
```

---

## Task 2: Diminishing-returns curve mechanism for Crit Chance / Crit Multiplier / Luck

**Files:**
- Modify: `src/core/hero/hero.gd` (constants block ~line 54-58 and ~101, `_apply_stat_cap()` ~line 321-333)
- Modify: `tests/unit/hero/hero_stat_resolution_test.gd` (crit_chance cap tests, ~lines 96-109; add crit_multiplier/luck curve tests)
- Modify: `tests/unit/hero/hero_auto_attack_test.gd` (crit_multiplier_effective expectation line 169, `CRIT_CHANCE_CAP` doc-comment references lines 15-21/195-198)

**Interfaces:**
- Consumes: nothing new.
- Produces: `Hero._diminishing_curve(raw: float, hard_cap: float, scaling_constant: float) -> float` (static), used internally by `_apply_stat_cap()`. `get_effective_stat(&"crit_multiplier")` now returns the FULL multiplier (base + bonus, e.g. 1.5–3.5), not a bonus-only value — callers must no longer add `CRIT_MULTIPLIER_BASE` on top (Task 7 updates the 2 call sites).

- [ ] **Step 1: Update the stat-cap constants in `hero.gd`**

Find (~line 51-57):

```gdscript
const CRIT_CHANCE_CAP: float = 0.8
const ELEMENTAL_RESIST_CAP: float = 0.75
const LIFESTEAL_CAP: float = 0.4
const CDR_CAP: float = 0.75
```

Replace with:

```gdscript
## Diminishing-returns curve cap/scaling-constant pairs (design/combat_
## formula_and_stats.txt, reconciled in docs/superpowers/specs/2026-09-18-
## hero-combat-stats-redesign-design.md Section 3.2). Scaling constants are
## rescaled from the source doc's large-stat-point examples (100/200/150) to
## fit this game's existing 0.0-1.0 fractional stat convention — see that
## spec section's own correction note for the worked-example values these
## produce.
const CRIT_CHANCE_CAP: float = 0.85
const CRIT_CHANCE_SCALING_CONSTANT: float = 0.5
const CRIT_MULTIPLIER_BONUS_CAP: float = 2.0
const CRIT_MULTIPLIER_SCALING_CONSTANT: float = 1.0
const LUCK_CAP: float = 0.35
const LUCK_SCALING_CONSTANT: float = 0.5
const ELEMENTAL_RESIST_CAP: float = 0.75
const LIFESTEAL_CAP: float = 0.4
const CDR_CAP: float = 0.75
```

- [ ] **Step 2: Update `CRIT_MULTIPLIER_BASE`'s value and doc comment**

Find (~line 99-101):

```gdscript
## Story-003 (S4-05) crit multiplier base (GDD event-bus.md / ADR-0010). Constant, not
## a stat — get_effective_stat(&"crit_multiplier") supplies only the bonus on top.
const CRIT_MULTIPLIER_BASE: float = 1.75
```

Replace with:

```gdscript
## Story-003 (S4-05) crit multiplier base (GDD event-bus.md / ADR-0010).
## Hero Combat & Stats Redesign (2026-09-18): base changed 1.75 -> 1.5 per
## the reconciled source doc. Now folded INTO get_effective_stat(&"crit_
## multiplier")'s own return value by _apply_stat_cap() below — callers no
## longer add this constant on top (see that function).
const CRIT_MULTIPLIER_BASE: float = 1.5
```

- [ ] **Step 3: Add the diminishing-curve static helper and rewrite `_apply_stat_cap()`**

Find (~line 319-333):

```gdscript
## Applies the per-stat post-formula cap (story-001 Tuning Knobs), if any, to an
## already-resolved Formula 1 value. Stats with no defined cap pass through unchanged.
func _apply_stat_cap(stat_name: StringName, value: float) -> float:
	match stat_name:
		&"crit_chance":
			return minf(value, CRIT_CHANCE_CAP)
		&"elemental_resist_fire", &"elemental_resist_frost":
			return minf(value, ELEMENTAL_RESIST_CAP)
		&"lifesteal":
			return minf(value, LIFESTEAL_CAP)
		&"cdr":
			return minf(value, CDR_CAP)
		_:
			return value
```

Replace with:

```gdscript
## Diminishing-returns curve (Hero Combat & Stats Redesign, 2026-09-18):
## Actual = (Raw x HardCap) / (Raw + ScalingConstant). Raw <= 0 short-circuits
## to 0.0 (avoids a needless divide when there is nothing to diminish, and
## keeps a negative Formula-1 intermediate — already impossible per
## get_effective_stat()'s own maxf(0.0, ...) floor — from ever reaching this
## function in a way that could misbehave).
static func _diminishing_curve(raw: float, hard_cap: float, scaling_constant: float) -> float:
	if raw <= 0.0:
		return 0.0
	return (raw * hard_cap) / (raw + scaling_constant)


## Applies the per-stat post-formula cap (story-001 Tuning Knobs), if any, to an
## already-resolved Formula 1 value. Stats with no defined cap pass through
## unchanged. crit_chance/crit_multiplier/luck use the diminishing-returns
## curve above (Hero Combat & Stats Redesign, 2026-09-18) instead of a flat
## clamp; crit_multiplier's curve computes only the BONUS portion, with
## CRIT_MULTIPLIER_BASE added on top so this function's return value is
## always the full, ready-to-use multiplier (callers never add the base
## separately anymore).
func _apply_stat_cap(stat_name: StringName, value: float) -> float:
	match stat_name:
		&"crit_chance":
			return _diminishing_curve(value, CRIT_CHANCE_CAP, CRIT_CHANCE_SCALING_CONSTANT)
		&"crit_multiplier":
			return CRIT_MULTIPLIER_BASE + _diminishing_curve(value, CRIT_MULTIPLIER_BONUS_CAP, CRIT_MULTIPLIER_SCALING_CONSTANT)
		&"luck":
			return _diminishing_curve(value, LUCK_CAP, LUCK_SCALING_CONSTANT)
		&"elemental_resist_fire", &"elemental_resist_frost":
			return minf(value, ELEMENTAL_RESIST_CAP)
		&"lifesteal":
			return minf(value, LIFESTEAL_CAP)
		&"cdr":
			return minf(value, CDR_CAP)
		_:
			return value
```

- [ ] **Step 4: Rewrite the crit_chance cap tests in `hero_stat_resolution_test.gd`**

Find (~lines 96-104):

```gdscript
func test_effective_stat_crit_chance_above_cap_clamps_to_eighty_percent() -> void:
	# Formula 1 alone would resolve to 1.0 (base=1.0, no flat/additive) — cap clamps to 0.80.
	var hero := _make_hero_for_stat(&"crit_chance", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.8, 0.0001)


func test_effective_stat_crit_chance_exactly_at_cap_passes_through_unclamped() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.8, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.8, 0.0001)
```

Replace with:

```gdscript
## Diminishing curve (Hero Combat & Stats Redesign, 2026-09-18): raw=1.0 ->
## (1.0 x 0.85) / (1.0 + 0.5) = 0.85 / 1.5 = 0.56667.
func test_effective_stat_crit_chance_curve_at_raw_one_returns_worked_example() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.56667, 0.0001)


## raw=0.1 (this project's placeholder base value) -> (0.1 x 0.85) / (0.1 + 0.5)
## = 0.085 / 0.6 = 0.14167.
func test_effective_stat_crit_chance_curve_at_placeholder_base_value() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.1, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.14167, 0.0001)


## Asymptotic approach: a very large raw value must never reach or exceed 0.85.
func test_effective_stat_crit_chance_never_reaches_hard_cap_at_large_raw() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 1000.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_less(0.85)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_greater(0.84)


func test_effective_stat_crit_chance_zero_raw_returns_zero() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.0, 0.0001)
```

- [ ] **Step 5: Update the remaining crit_chance test in the same file**

Find (~line 107-109, the one test in this block not yet replaced):

```gdscript
func test_effective_stat_crit_chance_below_cap_is_unaffected() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.5, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.5, 0.0001)
```

Replace with:

```gdscript
## raw=0.5 -> (0.5 x 0.85) / (0.5 + 0.5) = 0.425 / 1.0 = 0.425 (the curve's own
## documented "half of hard cap at raw=scaling_constant" property).
func test_effective_stat_crit_chance_curve_half_cap_at_scaling_constant() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.5, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_chance")).is_equal_approx(0.425, 0.0001)
```

- [ ] **Step 6: Add new Crit Multiplier and Luck curve tests to the same file**

Append at the end of `hero_stat_resolution_test.gd`:

```gdscript
# ---------------------------------------------------------------------------
# Crit Multiplier diminishing curve (Hero Combat & Stats Redesign, 2026-09-18)
# get_effective_stat(&"crit_multiplier") now returns the FULL multiplier
# (base 1.5 + curved bonus), not a bonus-only value.
# ---------------------------------------------------------------------------

func test_effective_stat_crit_multiplier_zero_raw_returns_base_only() -> void:
	var hero := _make_hero_for_stat(&"crit_multiplier", 0.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_multiplier")).is_equal_approx(1.5, 0.0001)


## raw=1.0 -> 1.5 + (1.0 x 2.0) / (1.0 + 1.0) = 1.5 + 1.0 = 2.5
func test_effective_stat_crit_multiplier_curve_at_raw_one() -> void:
	var hero := _make_hero_for_stat(&"crit_multiplier", 1.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_multiplier")).is_equal_approx(2.5, 0.0001)


func test_effective_stat_crit_multiplier_never_reaches_hard_cap_at_large_raw() -> void:
	var hero := _make_hero_for_stat(&"crit_multiplier", 1000.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"crit_multiplier")).is_less(3.5)
	assert_float(hero.get_effective_stat(&"crit_multiplier")).is_greater(3.4)


# ---------------------------------------------------------------------------
# Luck diminishing curve (new stat, Hero Combat & Stats Redesign, 2026-09-18)
# ---------------------------------------------------------------------------

func test_effective_stat_luck_zero_raw_returns_zero() -> void:
	var hero := _make_hero_for_stat(&"luck", 0.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"luck")).is_equal_approx(0.0, 0.0001)


## raw=0.5 -> (0.5 x 0.35) / (0.5 + 0.5) = 0.175 / 1.0 = 0.175
func test_effective_stat_luck_curve_half_cap_at_scaling_constant() -> void:
	var hero := _make_hero_for_stat(&"luck", 0.5, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"luck")).is_equal_approx(0.175, 0.0001)


func test_effective_stat_luck_never_reaches_hard_cap_at_large_raw() -> void:
	var hero := _make_hero_for_stat(&"luck", 1000.0, 0.0, 0.0)
	assert_float(hero.get_effective_stat(&"luck")).is_less(0.35)
	assert_float(hero.get_effective_stat(&"luck")).is_greater(0.34)
```

- [ ] **Step 7: Update `hero_auto_attack_test.gd`'s crit_multiplier_effective expectation**

Find (~line 169, inside `test_attack_timeout_emits_payload_with_expected_fields_on_deterministic_no_crit`):

```gdscript
	assert_float(payload.crit_multiplier_effective).is_equal_approx(2.0, 0.001)  # 1.75 + 0.25
```

Replace with:

```gdscript
	# 1.5 base + diminishing_curve(0.25, 2.0, 1.0) = 1.5 + (0.25*2.0)/(0.25+1.0) = 1.5 + 0.4 = 1.9
	assert_float(payload.crit_multiplier_effective).is_equal_approx(1.9, 0.001)
```

(This test sets `_hero._base_stats[&"crit_multiplier"] = 0.25` at line 156 — unchanged; only the expected resolved value changes, since the resolution mechanism changed. `Task 7` updates the emission call site itself, which this test also depends on — run this test again after Task 7, not just after this task, if it fails here first.)

- [ ] **Step 8: Update the stale doc comment in `hero_auto_attack_test.gd`**

Find (~lines 15-21):

```gdscript
## Gap 5 (crit-chance cap): get_effective_stat(&"crit_chance") is capped at
## Hero.CRIT_CHANCE_CAP = 0.8 (story-001 Tuning Knobs), so crit_chance = 1.0
## does NOT deterministically guarantee is_crit = true. Rule 6 payload-shape
## coverage uses crit_chance = 0.0 for a deterministic no-crit case (randf() < 0.0
## is always false) and a separate statistical smoke test at the capped 0.8 to
## prove the crit path is reachable (p(0 crits in 50 trials) = 0.8^50 ≈ 1.4e-5,
## a negligible flake risk in practice).
```

Replace with:

```gdscript
## Gap 5 (crit-chance cap): get_effective_stat(&"crit_chance") is now resolved
## via a diminishing-returns curve (Hero Combat & Stats Redesign, 2026-09-18),
## asymptotically approaching Hero.CRIT_CHANCE_CAP = 0.85 but never reaching
## it, so crit_chance = 1.0 does NOT deterministically guarantee is_crit =
## true. Rule 6 payload-shape coverage uses crit_chance = 0.0 for a
## deterministic no-crit case (randf() < 0.0 is always false) and a separate
## statistical smoke test at raw=1.0 (curved to ~0.567) to prove the crit path
## is reachable (p(0 crits in 50 trials) = (1-0.567)^50, effectively 0, a
## negligible flake risk in practice).
```

- [ ] **Step 9: Update the statistical smoke test's comment for the new curved value**

Find (~lines 195-198):

```gdscript
func test_attack_timeout_crit_roll_can_occur_when_crit_chance_is_capped_high() -> void:
	# Statistical smoke test: crit_chance = 1.0 is clamped to CRIT_CHANCE_CAP = 0.8
	# (story-001 Tuning Knobs) — not a deterministic guarantee. Fire the timeout 50
	# times and assert at least one crit occurred. p(zero crits) = 0.8^50 ≈ 1.4e-5.
```

Replace with:

```gdscript
func test_attack_timeout_crit_roll_can_occur_when_crit_chance_is_capped_high() -> void:
	# Statistical smoke test: crit_chance = 1.0 curves to ~0.5667 (diminishing
	# curve, Hero Combat & Stats Redesign, 2026-09-18) — not a deterministic
	# guarantee. Fire the timeout 50 times and assert at least one crit
	# occurred. p(zero crits) = (1-0.5667)^50, effectively 0.
```

- [ ] **Step 10: Run the touched tests**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/unit/hero`
Expected: `hero_stat_resolution_test.gd` passes fully. `hero_auto_attack_test.gd`'s `test_attack_timeout_emits_payload_with_expected_fields_on_deterministic_no_crit` may still fail here — it also depends on Task 7's emission-site change (removing the old `CRIT_MULTIPLIER_BASE +` prefix at the call site). Note the failure and continue; Task 7's own test run will confirm it passes.

- [ ] **Step 11: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_stat_resolution_test.gd tests/unit/hero/hero_auto_attack_test.gd
git commit -m "Add diminishing-returns curves for Crit Chance/Crit Multiplier/Luck"
```

---

## Task 3: Combined Crit Chance (with Luck) helper

**Files:**
- Modify: `src/core/hero/hero.gd` (add `_effective_crit_chance()` near `get_effective_stat()`)
- Test: `tests/unit/hero/hero_stat_resolution_test.gd` (new tests for the combined helper)

**Interfaces:**
- Consumes: `get_effective_stat(&"crit_chance")`, `get_effective_stat(&"luck")`, `CRIT_CHANCE_CAP` (all from Task 2).
- Produces: `Hero._effective_crit_chance() -> float` — used by Task 7's auto-attack/skill emission sites in place of the bare `get_effective_stat(&"crit_chance")` roll.

- [ ] **Step 1: Add the helper in `hero.gd`, immediately after `get_effective_stat()`**

Find the end of `get_effective_stat()` (~line 316-317, right before `_apply_stat_cap()`'s own doc comment):

```gdscript
	if stat_name == &"tower_affinity":
		effective = _apply_tower_affinity_bonus(effective)
	return _apply_stat_cap(stat_name, effective)
```

Insert immediately after that function (before `_apply_stat_cap`'s doc comment):

```gdscript
## Hero Combat & Stats Redesign (2026-09-18), Section 3.4.2: Luck contributes
## a secondary Crit Chance source on top of the dedicated Crit Chance stat,
## each independently diminishing-curved (get_effective_stat handles that per
## stat), then summed and re-clamped to CRIT_CHANCE_CAP so a heavily-stacked
## build can never exceed the "never quite guaranteed" ceiling even with both
## sources maxed. Both auto-attack and skill-cast crit rolls use this instead
## of a bare get_effective_stat(&"crit_chance") read.
func _effective_crit_chance() -> float:
	var combined: float = get_effective_stat(&"crit_chance") + get_effective_stat(&"luck")
	return minf(combined, CRIT_CHANCE_CAP)
```

- [ ] **Step 2: Add tests to `hero_stat_resolution_test.gd`**

Append:

```gdscript
# ---------------------------------------------------------------------------
# _effective_crit_chance() — Crit Chance + Luck combined, re-clamped
# (Hero Combat & Stats Redesign, 2026-09-18, Section 3.4.2)
# ---------------------------------------------------------------------------

func test_effective_crit_chance_sums_crit_chance_and_luck_curves() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.5, 0.0, 0.0)
	hero._base_stats[&"luck"] = 0.5
	# crit_chance curve: 0.425 (Task 2's worked example). luck curve: 0.175
	# (Task 2's worked example). Sum = 0.6.
	assert_float(hero._effective_crit_chance()).is_equal_approx(0.6, 0.0001)


func test_effective_crit_chance_clamps_combined_sum_to_cap() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 1000.0, 0.0, 0.0)
	hero._base_stats[&"luck"] = 1000.0
	# Both curves individually approach their own caps (0.85 + 0.35 = 1.2 max
	# possible sum) — the combined result must still clamp to 0.85, not 1.2.
	assert_float(hero._effective_crit_chance()).is_equal_approx(0.85, 0.0001)


func test_effective_crit_chance_zero_luck_equals_bare_crit_chance() -> void:
	var hero := _make_hero_for_stat(&"crit_chance", 0.5, 0.0, 0.0)
	assert_float(hero._effective_crit_chance()).is_equal_approx(
		hero.get_effective_stat(&"crit_chance"), 0.0001)
```

- [ ] **Step 3: Run the touched tests**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/unit/hero`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_stat_resolution_test.gd
git commit -m "Add combined Crit Chance + Luck helper for combat rolls"
```

---

## Task 4: MonsterResource Armor/Evasion fields

**Files:**
- Modify: `src/core/monster/monster_resource.gd`
- Test: `tests/unit/monster/monster_resource_validate_test.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: `MonsterResource.armor: float` (default 0.0), `MonsterResource.evasion: float` (default 0.0, range [0,100]) — read by `Hero._on_monster_spawned()` in Task 7.

- [ ] **Step 1: Add the fields in `monster_resource.gd`**

Find (~line 19-31, the `@export_group("Combat Stats")` block):

```gdscript
@export_group("Combat Stats")
@export var base_hp: float = 100.0
@export var base_speed: float = 1.0  ## cells per second at wave 1
## Tower Stats System Phase 1 (player-requested 2026-08-16): StringName
## element (matching WeaponComponent.element -- "fire"/"frost"/"poison"/
## "lightning"/"arcane") -> float resist fraction [0.0, 0.9]. Missing key =
## 0.0 (no resistance) -- fully backward-compatible, no data migration
## needed for existing monster content. Read by TowerSystem's monster cache
## (see tower_system.gd::_on_monster_spawned()) and applied in
## _try_attack()'s damage formula; physical hits (WeaponComponent.element ==
## "") never consult this dictionary at all. Capped at 0.9, not 1.0, so no
## element can make a monster fully damage-immune.
@export var elemental_resistances: Dictionary = {}
```

Replace with:

```gdscript
@export_group("Combat Stats")
@export var base_hp: float = 100.0
@export var base_speed: float = 1.0  ## cells per second at wave 1
## Tower Stats System Phase 1 (player-requested 2026-08-16): StringName
## element (matching WeaponComponent.element -- "fire"/"ice"/"poison"/
## "lightning"/"arcane", per HeroSkillEffectResource.VALID_DAMAGE_TYPES'
## canonical "frost" -> "ice" rename, 2026-09-04 -- corrected here 2026-09-18,
## this doc comment was stale) -> float resist fraction [0.0, 0.9]. Missing
## key = 0.0 (no resistance) -- fully backward-compatible, no data migration
## needed for existing monster content. Read by TowerSystem's monster cache
## (see tower_system.gd::_on_monster_spawned()) and applied in
## _try_attack()'s damage formula; physical hits (WeaponComponent.element ==
## "") never consult this dictionary at all. Capped at 0.9, not 1.0, so no
## element can make a monster fully damage-immune. Hero Combat & Stats
## Redesign (2026-09-18): this same dict now also mitigates the Hero's own
## Magic Attack damage (Hero._on_monster_spawned() caches it for that
## purpose too) -- one shared resistance value per element, not a separate
## tower-vs-hero pair.
@export var elemental_resistances: Dictionary = {}
## Hero Combat & Stats Redesign (2026-09-18), Section 3.3: mitigates the
## Hero's own outgoing PHYSICAL Attack damage only (never tower damage --
## that stays on archetype_tag/is_armored, untouched by this field). Formula:
## Mitigation% = Armor / (Armor + 50 x hero_level), hero_level hardcoded to 1
## in damage_status.gd pending the not-yet-designed Hero Leveling system.
## Default 0.0 = no mitigation (fully backward-compatible with every existing
## monster .tres, none of which author this field yet).
@export var armor: float = 0.0
## Hero Combat & Stats Redesign (2026-09-18), Section 3.3: flat percentage
## [0, 100] chance the Hero's attack (any damage_type) misses this monster
## entirely -- rolled before any damage math in damage_status.gd. Default 0.0
## = never evades (fully backward-compatible).
@export_range(0.0, 100.0, 0.1) var evasion: float = 0.0
```

- [ ] **Step 2: Add validation for the new fields**

Find (~line 65-68, the end of `validate()`, right before `return errors`):

```gdscript
	for element: Variant in elemental_resistances:
		var resistance: float = elemental_resistances[element] as float
		if resistance < 0.0 or resistance > 0.9:
			errors.append("elemental_resistances[%s] must be in [0.0, 0.9] (got %.2f)" % [element, resistance])
	return errors
```

Replace with:

```gdscript
	for element: Variant in elemental_resistances:
		var resistance: float = elemental_resistances[element] as float
		if resistance < 0.0 or resistance > 0.9:
			errors.append("elemental_resistances[%s] must be in [0.0, 0.9] (got %.2f)" % [element, resistance])
	if armor < 0.0:
		errors.append("armor must not be negative (got %.2f)" % armor)
	if evasion < 0.0 or evasion > 100.0:
		errors.append("evasion must be in [0.0, 100.0] (got %.2f)" % evasion)
	return errors
```

- [ ] **Step 3: Write failing tests in `monster_resource_validate_test.gd`**

First, read the existing file's `before_test()`/helper pattern (it builds a valid `MonsterResource` and mutates one field per test — follow that exact convention) and append tests matching it:

```gdscript
func test_validate_negative_armor_is_invalid() -> void:
	var resource := _make_valid_resource()
	resource.armor = -5.0
	var errors: Array[String] = resource.validate()
	assert_bool(errors.is_empty()).is_false()


func test_validate_zero_armor_is_valid() -> void:
	var resource := _make_valid_resource()
	resource.armor = 0.0
	var errors: Array[String] = resource.validate()
	assert_bool(errors.is_empty()).is_true()


func test_validate_evasion_above_one_hundred_is_invalid() -> void:
	var resource := _make_valid_resource()
	resource.evasion = 100.1
	var errors: Array[String] = resource.validate()
	assert_bool(errors.is_empty()).is_false()


func test_validate_evasion_below_zero_is_invalid() -> void:
	var resource := _make_valid_resource()
	resource.evasion = -0.1
	var errors: Array[String] = resource.validate()
	assert_bool(errors.is_empty()).is_false()


func test_validate_evasion_within_range_is_valid() -> void:
	var resource := _make_valid_resource()
	resource.evasion = 50.0
	var errors: Array[String] = resource.validate()
	assert_bool(errors.is_empty()).is_true()
```

(If the existing file's valid-resource builder has a different name than `_make_valid_resource()`, use whatever it actually is — read the file first and match it exactly; do not introduce a second builder.)

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/unit/monster/monster_resource_validate_test.gd`
Expected: all pass, including the 5 new ones.

- [ ] **Step 5: Commit**

```bash
git add src/core/monster/monster_resource.gd tests/unit/monster/monster_resource_validate_test.gd
git commit -m "Add Armor/Evasion fields to MonsterResource"
```

---

## Task 5: Event payload fields (damage_type, target_armor, target_evasion, target_elemental_resist)

**Files:**
- Modify: `src/foundation/event_bus/event_payloads/hero_auto_attack_event.gd`
- Modify: `src/foundation/event_bus/event_payloads/hero_skill_attack_event.gd`

**Interfaces:**
- Consumes: nothing new.
- Produces: 4 new `@export` fields on each payload class, all with neutral defaults (`damage_type = "physical"`, `target_armor = 0.0`, `target_evasion = 0.0`, `target_elemental_resist = 0.0`) so every existing test that constructs these payloads without setting the new fields keeps behaving exactly as before (0 mitigation, 0% evasion) once Task 6 wires them in.

- [ ] **Step 1: Add fields to `HeroAutoAttackEvent`**

Find (end of `hero_auto_attack_event.gd`):

```gdscript
@export var base_damage: float = 0.0
@export var is_crit: bool = false
@export var target_id: int = -1
@export var crit_multiplier_effective: float = 1.0
@export var hero_lifesteal_fraction: float = 0.0
@export var hero_bonus_tier: int = 0  ## 0 = STANDARD, 1 = ELITE, 2 = BOSS
```

Replace with:

```gdscript
@export var base_damage: float = 0.0
@export var is_crit: bool = false
@export var target_id: int = -1
@export var crit_multiplier_effective: float = 1.0
@export var hero_lifesteal_fraction: float = 0.0
@export var hero_bonus_tier: int = 0  ## 0 = STANDARD, 1 = ELITE, 2 = BOSS
## Hero Combat & Stats Redesign (2026-09-18): auto-attack is always a
## physical-damage-type ability (never set to anything else at the emission
## site) -- present here (rather than hardcoded only in damage_status.gd) so
## D&S's mitigation branch reads identically for both this event and
## HeroSkillAttackEvent.
@export var damage_type: String = "physical"
## Target's MonsterResource.armor, resolved by Hero at emission time (mirrors
## TowerSystem's own is_armored-resolved-before-emit pattern). Only consulted
## when damage_type == "physical".
@export var target_armor: float = 0.0
## Target's MonsterResource.evasion [0,100], resolved by Hero at emission
## time. Rolled first, before any damage math (Section 3.5.1).
@export var target_evasion: float = 0.0
## Target's MonsterResource.elemental_resistances[damage_type], resolved by
## Hero at emission time. Always 0.0 here since auto-attack's damage_type is
## always "physical" (elemental resist never applies to physical damage) --
## present for structural symmetry with HeroSkillAttackEvent's own field.
@export var target_elemental_resist: float = 0.0
```

- [ ] **Step 2: Add the same 4 fields to `HeroSkillAttackEvent`**

Find (end of `hero_skill_attack_event.gd`):

```gdscript
@export var skill_id: StringName = &""
@export var target_id: int = -1
@export var skill_power: float = 0.0
@export var skill_power_coefficient: float = 0.0
@export var is_crit: bool = false
@export var crit_multiplier_effective: float = 1.0
@export var hero_bonus_tier: int = 0  ## 0 = STANDARD, 1 = ELITE, 2 = BOSS
```

Replace with:

```gdscript
@export var skill_id: StringName = &""
@export var target_id: int = -1
@export var skill_power: float = 0.0
@export var skill_power_coefficient: float = 0.0
@export var is_crit: bool = false
@export var crit_multiplier_effective: float = 1.0
@export var hero_bonus_tier: int = 0  ## 0 = STANDARD, 1 = ELITE, 2 = BOSS
## Hero Combat & Stats Redesign (2026-09-18): the cast skill's own damage_type
## (SkillDefinitionResource.effect_data.damage_type, "" normalized to
## "physical" by Hero at emission time -- see hero.gd's
## _resolve_skill_hit()). Drives D&S's mitigation branch: "physical" ->
## target_armor's curve, any other value -> target_elemental_resist, "true"
## -> no mitigation.
@export var damage_type: String = "physical"
## Target's MonsterResource.armor, resolved by Hero at emission time. Only
## consulted when damage_type == "physical".
@export var target_armor: float = 0.0
## Target's MonsterResource.evasion [0,100], resolved by Hero at emission
## time. Rolled first, before any damage math (Section 3.5.1).
@export var target_evasion: float = 0.0
## Target's MonsterResource.elemental_resistances[damage_type], resolved by
## Hero at emission time. Only consulted when damage_type is a magic element;
## irrelevant (stays 0.0) for "physical"/"true".
@export var target_elemental_resist: float = 0.0
```

- [ ] **Step 3: No test run needed yet**

These are pure data-class field additions with neutral defaults — nothing consumes them until Task 6, and nothing existing constructs these classes with positional args (all field access in the codebase is by name, confirmed by every usage read so far), so this step cannot break any existing test. Proceed directly to commit.

- [ ] **Step 4: Commit**

```bash
git add src/foundation/event_bus/event_payloads/hero_auto_attack_event.gd src/foundation/event_bus/event_payloads/hero_skill_attack_event.gd
git commit -m "Add damage_type/target_armor/target_evasion/target_elemental_resist fields to Hero attack event payloads"
```

---

## Task 6: DamageStatus mitigation/evasion/variance helpers + D2/D7 rewrite

**Files:**
- Modify: `src/core/damage_status/damage_status.gd`
- Modify: `tests/unit/damage_status/damage_status_test.gd`
- Modify: `tests/integration/hero/hero_combat_formula_test.gd` (doc comment only — AC-05 is no longer out of scope)

**Interfaces:**
- Consumes: `HeroAutoAttackEvent`/`HeroSkillAttackEvent`'s new fields (Task 5).
- Produces: `DamageStatus._roll_evasion(evasion_percent: float) -> bool` (static), `DamageStatus._resolve_target_mitigation(damage_type: String, target_armor: float, target_elemental_resist: float) -> float` (static, returns a 0.0-1.0 multiplier to apply to damage), `DamageStatus._apply_combat_variance(damage: float) -> float` (static) — all 3 used by both `_on_hero_auto_attacked()` and `_on_hero_skill_attacked()`.

- [ ] **Step 1: Add the 3 static helpers, right after the existing constants**

Find (top of `damage_status.gd`):

```gdscript
const ARMORED_MITIGATION_MULTIPLIER: float = 0.50
const HERO_DAMAGE_BONUS_MULTIPLIER: float = 1.50
```

Replace with:

```gdscript
const ARMORED_MITIGATION_MULTIPLIER: float = 0.50
const HERO_DAMAGE_BONUS_MULTIPLIER: float = 1.50

## Hero Combat & Stats Redesign (2026-09-18), Section 3.3: Hero Level is
## hardcoded to 1 pending the not-yet-designed Hero Leveling system -- swap
## this constant for Hero's real current level once that system exists (one-
## line change, no formula rework, per the governing spec's own explicit
## sequencing decision).
const HERO_LEVEL_PLACEHOLDER: int = 1
const HERO_ARMOR_MITIGATION_LEVEL_SCALAR: float = 50.0
const COMBAT_VARIANCE_MIN: float = 0.95
const COMBAT_VARIANCE_MAX: float = 1.05


## Evasion roll (Section 3.5.1): true if the attack misses entirely.
## evasion_percent is MonsterResource.evasion, already in [0,100] units (not
## a 0.0-1.0 fraction) -- matches that field's own @export_range.
static func _roll_evasion(evasion_percent: float) -> bool:
	return randf() * 100.0 < evasion_percent


## Target mitigation (Section 3.5.4): returns a 0.0-1.0 multiplier to apply
## to raw damage. "physical" uses the Armor diminishing-returns curve
## (Mitigation% = Armor / (Armor + 50 x hero_level), hero_level hardcoded
## per HERO_LEVEL_PLACEHOLDER above); any other damage_type (fire/ice/poison/
## lightning/arcane) uses the caller-resolved target_elemental_resist
## directly (Hero already looked this up from the target's
## MonsterResource.elemental_resistances dict by the ability's own
## damage_type before emitting -- this function never does that lookup
## itself, matching the project's existing "caller resolves, D&S only does
## math" division of labor already established by _on_tower_attacked()'s
## is_armored parameter); "true" bypasses both, returning 1.0 (no
## mitigation) per Section 3.3's dormant-capability note.
static func _resolve_target_mitigation(damage_type: String, target_armor: float, target_elemental_resist: float) -> float:
	if damage_type == "true":
		return 1.0
	if damage_type == "physical":
		var armor_mitigation: float = target_armor / (target_armor + HERO_ARMOR_MITIGATION_LEVEL_SCALAR * float(HERO_LEVEL_PLACEHOLDER))
		return 1.0 - armor_mitigation
	return 1.0 - target_elemental_resist


## Combat variance (Section 3.5.5): a fixed +/-5% multiplier per the source
## doc's own stated range -- not meant to be re-tuned casually (see the
## governing spec's Tuning Knobs table).
static func _apply_combat_variance(damage: float) -> float:
	return damage * randf_range(COMBAT_VARIANCE_MIN, COMBAT_VARIANCE_MAX)
```

- [ ] **Step 2: Rewrite `_on_hero_auto_attacked()`**

Find (~line 84-95):

```gdscript
func _on_hero_auto_attacked(event: HeroAutoAttackEvent) -> void:
	var tier_dmg: float = event.base_damage * (HERO_DAMAGE_BONUS_MULTIPLIER if event.hero_bonus_tier > 0 else 1.0)
	var crit_dmg: float = tier_dmg * (event.crit_multiplier_effective if event.is_crit else 1.0)
	var final_damage: int = floori(crit_dmg)
	if final_damage <= 0:
		return
	if event.hero_lifesteal_fraction > 0.0:
		_lifesteal_pending[event.target_id] = event.hero_lifesteal_fraction
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var ev: MonsterDamageTaken = MonsterDamageTaken.new()
```

Replace with:

```gdscript
func _on_hero_auto_attacked(event: HeroAutoAttackEvent) -> void:
	if _roll_evasion(event.target_evasion):
		return
	var tier_dmg: float = event.base_damage * (HERO_DAMAGE_BONUS_MULTIPLIER if event.hero_bonus_tier > 0 else 1.0)
	var crit_dmg: float = tier_dmg * (event.crit_multiplier_effective if event.is_crit else 1.0)
	var mitigated_dmg: float = crit_dmg * _resolve_target_mitigation(event.damage_type, event.target_armor, event.target_elemental_resist)
	var final_dmg: float = _apply_combat_variance(mitigated_dmg)
	var final_damage: int = floori(final_dmg)
	if final_damage <= 0:
		return
	if event.hero_lifesteal_fraction > 0.0:
		_lifesteal_pending[event.target_id] = event.hero_lifesteal_fraction
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var ev: MonsterDamageTaken = MonsterDamageTaken.new()
```

Also update this function's own doc comment. Find (~line 77-83):

```gdscript
## D2 formula: floor(base × tier_mult × crit_mult). One flat HERO_DAMAGE_BONUS_MULTIPLIER
## for any hero_bonus_tier > 0 (ELITE and BOSS resolve identically) — confirmed correct
## per design/gdd/hero.md Formula 4 (`elite_boss_multiplier` range is {1.0, 1.5}, no
## distinct BOSS value) and user decision (TD-story-002, resolved 2026-07-08). Story
## 004's own text originally claimed a distinct BOSS=2.0x, contradicting its own
## governing GDD; the story text was corrected to match this shipped behavior instead.
## Lifesteal fraction registered before await — must survive across the frame boundary.
```

Replace with:

```gdscript
## D2 formula, extended by Hero Combat & Stats Redesign (2026-09-18): evasion
## roll -> floor(base × tier_mult × crit_mult × target_mitigation ×
## combat_variance). One flat HERO_DAMAGE_BONUS_MULTIPLIER for any
## hero_bonus_tier > 0 (ELITE and BOSS resolve identically) — confirmed
## correct per design/gdd/hero.md Formula 4 (`elite_boss_multiplier` range is
## {1.0, 1.5}, no distinct BOSS value) and user decision (TD-story-002,
## resolved 2026-07-08). Story 004's own text originally claimed a distinct
## BOSS=2.0x, contradicting its own governing GDD; the story text was
## corrected to match this shipped behavior instead. Target mitigation (real
## armor/elemental-resist reduction of Hero's own outgoing damage) did not
## exist at all before this redesign -- closes that gap. Lifesteal fraction
## registered before await — must survive across the frame boundary.
```

- [ ] **Step 3: Rewrite `_on_hero_skill_attacked()`**

Find (~line 116-120):

```gdscript
func _on_hero_skill_attacked(event: HeroSkillAttackEvent) -> void:
	var base_skill_damage: float = event.skill_power * event.skill_power_coefficient
	var tier_dmg: float = base_skill_damage * (HERO_DAMAGE_BONUS_MULTIPLIER if event.hero_bonus_tier > 0 else 1.0)
	var crit_dmg: float = tier_dmg * (event.crit_multiplier_effective if event.is_crit else 1.0)
	var final_damage: int = floori(crit_dmg)
	if final_damage <= 0:
		return
	await get_tree().process_frame
```

Replace with:

```gdscript
func _on_hero_skill_attacked(event: HeroSkillAttackEvent) -> void:
	if _roll_evasion(event.target_evasion):
		return
	var base_skill_damage: float = event.skill_power * event.skill_power_coefficient
	var tier_dmg: float = base_skill_damage * (HERO_DAMAGE_BONUS_MULTIPLIER if event.hero_bonus_tier > 0 else 1.0)
	var crit_dmg: float = tier_dmg * (event.crit_multiplier_effective if event.is_crit else 1.0)
	var mitigated_dmg: float = crit_dmg * _resolve_target_mitigation(event.damage_type, event.target_armor, event.target_elemental_resist)
	var final_dmg: float = _apply_combat_variance(mitigated_dmg)
	var final_damage: int = floori(final_dmg)
	if final_damage <= 0:
		return
	await get_tree().process_frame
```

- [ ] **Step 4: Add unit tests for the 3 new static helpers to `damage_status_test.gd`**

Append:

```gdscript
# ---------------------------------------------------------------------------
# Hero Combat & Stats Redesign (2026-09-18): evasion / mitigation / variance
# static helpers, tested in isolation (pure functions, no node/tree needed).
# ---------------------------------------------------------------------------

func test_roll_evasion_zero_percent_never_evades() -> void:
	for i: int in range(100):
		assert_bool(DamageStatus._roll_evasion(0.0)).is_false()


func test_roll_evasion_one_hundred_percent_always_evades() -> void:
	for i: int in range(100):
		assert_bool(DamageStatus._roll_evasion(100.0)).is_true()


func test_roll_evasion_statistical_rate_within_tolerance() -> void:
	const SAMPLE_SIZE: int = 10000
	const EVASION_PERCENT: float = 30.0
	var evade_count: int = 0
	for i: int in range(SAMPLE_SIZE):
		if DamageStatus._roll_evasion(EVASION_PERCENT):
			evade_count += 1
	var observed_rate: float = float(evade_count) / float(SAMPLE_SIZE)
	assert_float(observed_rate).is_between(0.28, 0.32)


func test_resolve_target_mitigation_true_damage_type_bypasses_everything() -> void:
	var multiplier: float = DamageStatus._resolve_target_mitigation("true", 500.0, 0.9)
	assert_float(multiplier).is_equal_approx(1.0, 0.0001)


func test_resolve_target_mitigation_physical_zero_armor_applies_no_mitigation() -> void:
	var multiplier: float = DamageStatus._resolve_target_mitigation("physical", 0.0, 0.0)
	assert_float(multiplier).is_equal_approx(1.0, 0.0001)


func test_resolve_target_mitigation_physical_with_armor_worked_example() -> void:
	# Armor=50, hero_level=1 (hardcoded): mitigation% = 50/(50+50*1) = 0.5 -> multiplier = 0.5
	var multiplier: float = DamageStatus._resolve_target_mitigation("physical", 50.0, 0.0)
	assert_float(multiplier).is_equal_approx(0.5, 0.0001)


func test_resolve_target_mitigation_magic_uses_elemental_resist_directly() -> void:
	var multiplier: float = DamageStatus._resolve_target_mitigation("fire", 500.0, 0.4)
	# damage_type != "physical"/"true" -> ignores target_armor entirely, uses
	# 1.0 - target_elemental_resist = 0.6
	assert_float(multiplier).is_equal_approx(0.6, 0.0001)


func test_apply_combat_variance_stays_within_five_percent_band() -> void:
	for i: int in range(1000):
		var result: float = DamageStatus._apply_combat_variance(100.0)
		assert_float(result).is_between(94.9, 105.1)
```

- [ ] **Step 5: Add integration-level tests to `damage_status_test.gd` proving the new fields flow through `_on_hero_auto_attacked()`**

Append:

```gdscript
func test_d2_evasion_roll_suppresses_damage_entirely() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0
	ev.target_evasion = 100.0  # guaranteed miss

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	assert_bool(_spy.was_emitted("monster_damage_taken")).is_false()


func test_d2_physical_armor_reduces_damage() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0
	ev.damage_type = "physical"
	ev.target_armor = 50.0  # mitigation multiplier = 0.5 per the worked example above

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	# floor(100 * 0.5 * variance[0.95,1.05]) -> in [47, 52]
	assert_int(payload.amount).is_between(47, 52)


func test_d2_magic_damage_type_uses_elemental_resist_not_armor() -> void:
	var ev := HeroAutoAttackEvent.new()
	ev.base_damage = 100.0
	ev.is_crit = false
	ev.target_id = 5
	ev.crit_multiplier_effective = 1.0
	ev.hero_lifesteal_fraction = 0.0
	ev.hero_bonus_tier = 0
	ev.damage_type = "fire"
	ev.target_armor = 500.0  # must be ignored entirely for a non-physical damage_type
	ev.target_elemental_resist = 0.5

	_ds._on_hero_auto_attacked(ev)
	await get_tree().process_frame

	var emissions: Array = _spy.emissions.get("monster_damage_taken", []) as Array
	var payload: MonsterDamageTaken = emissions[0][0] as MonsterDamageTaken
	# floor(100 * 0.5 * variance[0.95,1.05]) -> in [47, 52] -- if target_armor
	# were wrongly consulted instead, this would be far lower.
	assert_int(payload.amount).is_between(47, 52)
```

- [ ] **Step 6: Update `hero_combat_formula_test.gd`'s stale doc comment**

Find (~lines 10-19):

```gdscript
## Scope: AC-03 (crit damage) and AC-04 (elite/boss tier multiplier) only.
## AC-05 (monster armor reduction) and AC-06 (lifesteal overheal clamp) are
## explicitly out of scope for this story — see dispatch brief:
##   - AC-05 describes a "monster armor" stat applied to hero-dealt damage
##     that does not exist anywhere in damage_status.gd or the GDDs. Real
##     armor reduction (Formula 5 / D1, ARMORED_MITIGATION_MULTIPLIER) only
##     applies to tower_attacked (incoming damage to monsters from towers),
##     and is unrelated to any "monster armor vs hero" concept.
##   - AC-06's overheal clamp is Hero System's responsibility per GDD, but
##     Hero has no current_hp field and no hero_healed subscriber yet.
## No changes were made to src/ — this file only exercises the existing,
## shipped D&S implementation.
```

Replace with:

```gdscript
## Scope: AC-03 (crit damage) and AC-04 (elite/boss tier multiplier) only.
## AC-05 (monster armor reduction) is CLOSED by the Hero Combat & Stats
## Redesign (2026-09-18, docs/superpowers/specs/2026-09-18-hero-combat-
## stats-redesign-design.md) — see damage_status_test.gd's own new
## test_d2_physical_armor_reduces_damage() for that coverage; this file's
## scope stays crit/tier-only, unchanged. AC-06 (lifesteal overheal clamp)
## remains out of scope for this file — Hero System's own responsibility per
## GDD, covered by tests/unit/hero/hero_lifesteal_test.gd instead.
```

- [ ] **Step 7: Run the touched tests**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/unit/damage_status -a res://tests/integration/hero`
Expected: all pass. (`hero_stat_resolution_test.gd`'s Task 2 tests and `hero_auto_attack_test.gd` are covered under `tests/unit/hero`, run separately in Task 7 once the emission-site changes land — some `damage_status_test.gd` existing tests construct payloads without setting the new fields at all, which default to `damage_type="physical"`/`target_armor=0.0`/`target_evasion=0.0` — mitigation multiplier resolves to 1.0 and evasion never triggers, so those existing tests' expected exact integer damage values would still need the variance roll accounted for. Since `_apply_combat_variance` is now unconditionally applied, EVERY existing exact-value assertion in this file (e.g. `assert_int(payload.amount).is_equal(47)`) will now sometimes fail due to the ±5% roll. This is a real behavior change this task must also reconcile — see Step 8.)

- [ ] **Step 8: Reconcile combat variance with existing exact-value tests**

The ±5% variance roll makes every pre-existing exact-integer assertion in `damage_status_test.gd` (D1 tower tests are unaffected — variance is only added to D2/D7, the Hero paths) and `hero_combat_formula_test.gd` flaky. Convert every existing exact `assert_int(...).is_equal(N)` assertion in `damage_status_test.gd`'s D2 tests (`test_d2_standard_no_crit_returns_base_damage`, `test_d2_elite_bonus_applies_1_5_multiplier`, `test_d2_elite_crit_returns_262`, `test_d2_standard_crit_returns_175`, `test_d2_elite_max_crit_returns_487`) and every test in `hero_combat_formula_test.gd` (all 5 tests) to a ±5%-tolerant range check instead. For each, compute `floor(N * 0.95)` and `floor(N * 1.05)` and use `.is_between(low, high)`.

Example for `test_d2_standard_no_crit_returns_base_damage` (find):

```gdscript
	assert_int(payload.amount).is_equal(100)
```

Replace with:

```gdscript
	# ±5% combat variance (Hero Combat & Stats Redesign, 2026-09-18): floor(100*0.95)=95, floor(100*1.05)=105
	assert_int(payload.amount).is_between(95, 105)
```

Apply the same pattern (compute the ±5% band, floor each bound, use `.is_between`) to every other exact-value assertion named above across both files. Do not touch `test_d1_*` tests (tower pipeline, `_on_tower_attacked()` — untouched by this redesign, still fully deterministic) or the zero-damage-guard/lifesteal/freed-node tests (unaffected by variance since they assert on absence of emission or on `_lifesteal_pending`, not on an exact damage integer).

- [ ] **Step 9: Run the touched tests again**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/unit/damage_status -a res://tests/integration/hero`
Expected: all pass, including the now-tolerant range assertions.

- [ ] **Step 10: Commit**

```bash
git add src/core/damage_status/damage_status.gd tests/unit/damage_status/damage_status_test.gd tests/integration/hero/hero_combat_formula_test.gd
git commit -m "Wire evasion/armor-and-resist mitigation/combat-variance into Hero's damage pipeline"
```

---

## Task 7: Hero.gd monster-cache extension + emission-site updates

**Files:**
- Modify: `src/core/hero/hero.gd` (`_on_monster_spawned()` ~line 724-732, `_on_attack_timer_timeout()` ~line 671-687, `_resolve_skill_hit()` ~line 873-902)
- Modify: `tests/unit/hero/hero_auto_attack_test.gd` (verify crit_multiplier_effective fix from Task 2 now passes; no new changes expected here beyond what Task 2 already made)
- Modify: `tests/unit/hero/hero_skill_system_test.gd` (verify Task 1's rename now passes end-to-end)

**Interfaces:**
- Consumes: `MonsterResource.armor`/`.evasion` (Task 4), `HeroAutoAttackEvent`/`HeroSkillAttackEvent`'s new fields (Task 5), `Hero._effective_crit_chance()` (Task 3), `SkillDefinitionResource.effect_data.damage_type` (already exists, confirmed live-read at `hero.gd:886-887`).
- Produces: `Hero._monster_cache[entity_id]` gains `"armor"`, `"evasion"`, `"elemental_resistances"` keys (in addition to existing `"cell"`, `"hp"`, `"monster_id"`, `"tier"`, `"path_step"`).

- [ ] **Step 1: Extend `_on_monster_spawned()`'s cache population**

Find (~line 724-732):

```gdscript
func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var resource: MonsterResource = GGameDataRegistry.get_monster_resource(payload.monster_id)
	_monster_cache[payload.entity_id] = {
		"cell": payload.grid_position,
		"hp": payload.hp_max,
		"monster_id": payload.monster_id,
		"tier": resource.tier if resource != null else 0,
		"path_step": 0,
	}
```

Replace with:

```gdscript
func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	var resource: MonsterResource = GGameDataRegistry.get_monster_resource(payload.monster_id)
	_monster_cache[payload.entity_id] = {
		"cell": payload.grid_position,
		"hp": payload.hp_max,
		"monster_id": payload.monster_id,
		"tier": resource.tier if resource != null else 0,
		"path_step": 0,
		# Hero Combat & Stats Redesign (2026-09-18): cached once at spawn
		# (immutable per monster type, same reasoning as "tier" above) so
		# _on_attack_timer_timeout()/_resolve_skill_hit() can resolve target
		# mitigation without a second GameDataRegistry lookup per attack.
		"armor": resource.armor if resource != null else 0.0,
		"evasion": resource.evasion if resource != null else 0.0,
		"elemental_resistances": resource.elemental_resistances if resource != null else {},
	}
```

- [ ] **Step 2: Update `_on_attack_timer_timeout()`**

Find (~line 671-687, already partially updated by Task 1's Step 2):

```gdscript
func _on_attack_timer_timeout() -> void:
	var target_id: int = _select_target()
	if target_id == -1:
		return
	var entry: Dictionary = _monster_cache[target_id] as Dictionary

	var payload := HeroAutoAttackEvent.new()
	# GDD Formula 2 (ADR-0010): damage x (1 + tower_affinity_bonus). Closes the
	# Damage half of TD-hero-001 — Skill Power still has no consumer to fold this
	# into (tracked separately, remains open).
	payload.base_damage = get_effective_stat(&"physical_attack") * (1.0 + get_effective_stat(&"tower_affinity"))
	payload.is_crit = randf() < get_effective_stat(&"crit_chance")
	payload.target_id = target_id
	payload.crit_multiplier_effective = CRIT_MULTIPLIER_BASE + get_effective_stat(&"crit_multiplier")
	payload.hero_lifesteal_fraction = get_effective_stat(&"lifesteal")
	payload.hero_bonus_tier = entry.get("tier", 0) as int
	GEventBus.hero_auto_attacked.emit(payload)
```

Replace with:

```gdscript
func _on_attack_timer_timeout() -> void:
	var target_id: int = _select_target()
	if target_id == -1:
		return
	var entry: Dictionary = _monster_cache[target_id] as Dictionary

	var payload := HeroAutoAttackEvent.new()
	# GDD Formula 2 (ADR-0010): damage x (1 + tower_affinity_bonus).
	payload.base_damage = get_effective_stat(&"physical_attack") * (1.0 + get_effective_stat(&"tower_affinity"))
	payload.is_crit = randf() < _effective_crit_chance()
	payload.target_id = target_id
	# CRIT_MULTIPLIER_BASE is now folded into get_effective_stat() itself
	# (Hero Combat & Stats Redesign, 2026-09-18, _apply_stat_cap()) — no
	# longer added here separately.
	payload.crit_multiplier_effective = get_effective_stat(&"crit_multiplier")
	payload.hero_lifesteal_fraction = get_effective_stat(&"lifesteal")
	payload.hero_bonus_tier = entry.get("tier", 0) as int
	# Auto-attack is always physical (Hero Combat & Stats Redesign,
	# 2026-09-18, Section 3.5) — damage_type left at its "physical" default,
	# target_elemental_resist left at its 0.0 default (never consulted for a
	# physical hit).
	payload.target_armor = entry.get("armor", 0.0) as float
	payload.target_evasion = entry.get("evasion", 0.0) as float
	GEventBus.hero_auto_attacked.emit(payload)
```

- [ ] **Step 3: Update `_resolve_skill_hit()`**

Find (~line 873-902):

```gdscript
func _resolve_skill_hit(skill_id: StringName) -> void:
	var target_id: int = _select_target()
	if target_id == -1:
		return
	# TD-hero-006 (fixed 2026-09-02): previously read GGameDataRegistry.
	# get_skill_resource() (the legacy, unrelated 4-skill catalogue) — every
	# real, player-equippable skill_id resolved to null here and this
	# function returned before ever emitting hero_skill_attacked, so no
	# equipped skill dealt any damage. Now reads the real catalogue
	# (SkillDefinitionResource.effect_data.skill_power_coefficient), matching
	# damage-status.md's own Formula D7 doc, which always said this value
	# comes from "the cast skill's effect_data" — the GDD was correct; only
	# the code was wrong. See docs/tech-debt-register.md TD-hero-006.
	var skill: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
	if skill == null or skill.effect_data == null:
		return
	var entry: Dictionary = _monster_cache[target_id] as Dictionary
	var payload := HeroSkillAttackEvent.new()
	payload.skill_id = skill_id
	payload.target_id = target_id
	# GDD Formula 2: effective_skill_power_final = effective_skill_power x
	# (1 + tower_affinity_bonus) — identical shape to
	# _on_attack_timer_timeout()'s base_damage line, closing the Skill Power
	# half of TD-hero-001 (the Damage half already applies this formula).
	payload.skill_power = get_effective_stat(&"skill_power") * (1.0 + get_effective_stat(&"tower_affinity"))
	payload.skill_power_coefficient = skill.effect_data.skill_power_coefficient
	payload.is_crit = randf() < get_effective_stat(&"crit_chance")
	payload.crit_multiplier_effective = CRIT_MULTIPLIER_BASE + get_effective_stat(&"crit_multiplier")
	payload.hero_bonus_tier = entry.get("tier", 0) as int
	GEventBus.hero_skill_attacked.emit(payload)
```

Replace with:

```gdscript
func _resolve_skill_hit(skill_id: StringName) -> void:
	var target_id: int = _select_target()
	if target_id == -1:
		return
	# TD-hero-006 (fixed 2026-09-02): reads the real catalogue
	# (SkillDefinitionResource.effect_data) — see docs/tech-debt-register.md
	# TD-hero-006. Hero Combat & Stats Redesign (2026-09-18): this same
	# effect_data.damage_type field (already authored for all 32 skills) now
	# also drives which attack stat scales this cast and which mitigation
	# branch D&S applies — no schema addition was needed for this (see the
	# governing spec's Section 3.6 correction).
	var skill: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(skill_id)
	if skill == null or skill.effect_data == null:
		return
	var entry: Dictionary = _monster_cache[target_id] as Dictionary
	# "" (non-damage support/buff skill) normalizes to "physical" here —
	# matches this codebase's existing behavior of always emitting a real
	# damage hit regardless of a skill's effect_data.damage_type (D&S has
	# never gated on it); Section 3.6 flags this as a separate, out-of-scope
	# question this redesign does not attempt to resolve.
	var damage_type: String = skill.effect_data.damage_type
	if damage_type == "":
		damage_type = "physical"
	var attack_stat: StringName = &"physical_attack" if damage_type == "physical" else &"magic_attack"
	var elemental_resistances: Dictionary = entry.get("elemental_resistances", {}) as Dictionary
	var payload := HeroSkillAttackEvent.new()
	payload.skill_id = skill_id
	payload.target_id = target_id
	# GDD Formula 2: effective_attack_final = effective_attack x
	# (1 + tower_affinity_bonus) — identical shape to
	# _on_attack_timer_timeout()'s base_damage line.
	payload.skill_power = get_effective_stat(attack_stat) * (1.0 + get_effective_stat(&"tower_affinity"))
	payload.skill_power_coefficient = skill.effect_data.skill_power_coefficient
	payload.is_crit = randf() < _effective_crit_chance()
	# CRIT_MULTIPLIER_BASE is now folded into get_effective_stat() itself
	# (Hero Combat & Stats Redesign, 2026-09-18, _apply_stat_cap()).
	payload.crit_multiplier_effective = get_effective_stat(&"crit_multiplier")
	payload.hero_bonus_tier = entry.get("tier", 0) as int
	payload.damage_type = damage_type
	payload.target_armor = entry.get("armor", 0.0) as float
	payload.target_evasion = entry.get("evasion", 0.0) as float
	payload.target_elemental_resist = elemental_resistances.get(damage_type, 0.0) as float
	GEventBus.hero_skill_attacked.emit(payload)
```

- [ ] **Step 4: Run every touched Hero/DamageStatus test together**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/unit/hero -a res://tests/integration/hero -a res://tests/unit/damage_status`
Expected: all pass now, including the `hero_auto_attack_test.gd` crit_multiplier assertion Task 2 flagged as pending this task, and `hero_skill_system_test.gd`'s renamed stat.

- [ ] **Step 5: Commit**

```bash
git add src/core/hero/hero.gd
git commit -m "Resolve target armor/evasion/elemental-resist and damage_type at Hero's attack-emission sites"
```

---

## Task 8: ResourceEconomy Luck drop-rate hook

**Files:**
- Modify: `src/core/resource_economy/resource_economy.gd`
- Test: `tests/unit/resource_economy/drop_occurrence_quantity_test.gd`

**Interfaces:**
- Consumes: nothing new (Luck's actual value arrives via a plain setter call from the mission scene, Task 9).
- Produces: `ResourceEconomy._hero_luck_drop_bonus: float` (field, default 0.0), `ResourceEconomy.set_hero_luck_drop_bonus(bonus: float) -> void` (public setter).

- [ ] **Step 1: Add the field and setter**

Find the existing `_menagerie_quality_bonus` field (grep it in `resource_economy.gd` to find its exact declaration line — it's referenced directly by tests as `_re._menagerie_quality_bonus = 1.3`, so it's a plain `var`, not behind a setter). Add immediately after that field's declaration:

```gdscript
## Hero Combat & Stats Redesign (2026-09-18), Section 3.4.1: the Hero's
## diminished Luck value (Hero._effective_stat(&"luck")'s own diminishing-
## curve result — this system never reads Hero directly, per this project's
## no-direct-cross-system-reference convention; the mission scene resolves
## it once at mission start and pushes it in via set_hero_luck_drop_bonus()
## below, mirroring _menagerie_quality_bonus's own plain-field test-seam
## pattern). Added directly to each DropEntry's base_drop_rate before
## _roll_drop_occurs()'s check — boosts occurrence chance, not quantity.
var _hero_luck_drop_bonus: float = 0.0


## Public setter for _hero_luck_drop_bonus above — called once by the
## mission scene after Hero's placeholder stats are applied (Task 9).
func set_hero_luck_drop_bonus(bonus: float) -> void:
	_hero_luck_drop_bonus = bonus
```

- [ ] **Step 2: Apply the bonus in `_process_drops()`**

Find (~line 301-303):

```gdscript
	for entry: DropEntry in table.entries:
		if not _roll_drop_occurs(table.base_drop_rate):
			continue
```

Replace with:

```gdscript
	for entry: DropEntry in table.entries:
		var boosted_drop_rate: float = clampf(table.base_drop_rate + _hero_luck_drop_bonus, 0.0, 1.0)
		if not _roll_drop_occurs(boosted_drop_rate):
			continue
```

- [ ] **Step 3: Add tests to `drop_occurrence_quantity_test.gd`**

Append:

```gdscript
# ---------------------------------------------------------------------------
# Hero Combat & Stats Redesign (2026-09-18), Section 3.4.1: Luck boosts
# DropEntry occurrence chance directly.
# ---------------------------------------------------------------------------

func test_hero_luck_drop_bonus_increases_effective_occurrence_rate() -> void:
	const SAMPLE_SIZE: int = 10000
	const BASE_DROP_RATE: float = 0.30
	const LUCK_BONUS: float = 0.20
	_re.set_hero_luck_drop_bonus(LUCK_BONUS)
	var success_count: int = 0
	for i: int in range(SAMPLE_SIZE):
		if ResourceEconomy._roll_drop_occurs(clampf(BASE_DROP_RATE + _re._hero_luck_drop_bonus, 0.0, 1.0)):
			success_count += 1
	# Expected effective rate: 0.30 + 0.20 = 0.50
	var observed_rate: float = float(success_count) / float(SAMPLE_SIZE)
	assert_float(observed_rate).is_between(0.48, 0.52)


func test_hero_luck_drop_bonus_clamps_effective_rate_to_one() -> void:
	_re.set_hero_luck_drop_bonus(0.90)
	var table: DropTableResource = _make_drop_table(&"luck_clamp_test", 0.50, 1)
	_seed_drop_table(table)

	# 0.50 + 0.90 = 1.40, must clamp to 1.0 (guaranteed occurrence), never error.
	GEventBus.monster_died.emit(_make_died_event(&"luck_clamp_test", 1.0))

	assert_int(_spy.count("materials_earned")).is_equal(1)


func test_zero_luck_bonus_leaves_base_drop_rate_unaffected() -> void:
	# Default _hero_luck_drop_bonus = 0.0 -- no set_hero_luck_drop_bonus() call.
	var table: DropTableResource = _make_drop_table(&"no_luck_test", 0.0, 1)
	_seed_drop_table(table)

	GEventBus.monster_died.emit(_make_died_event(&"no_luck_test", 1.0))

	assert_int(_spy.count("materials_earned")).is_equal(0)
```

- [ ] **Step 4: Run the touched tests**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/unit/resource_economy`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add src/core/resource_economy/resource_economy.gd tests/unit/resource_economy/drop_occurrence_quantity_test.gd
git commit -m "Add Luck-boosted drop-occurrence hook to ResourceEconomy"
```

---

## Task 9: Wire Hero's Luck into ResourceEconomy at mission start

**Files:**
- Modify: `src/gameplay/missions/the_gap/the_gap.gd`
- Modify: `src/scenes/mission_scene.gd`

**Interfaces:**
- Consumes: `Hero.apply_placeholder_base_stats()` (existing, from last session's dedupe), `Hero.get_effective_stat(&"luck")` (Task 2), `ResourceEconomy.set_hero_luck_drop_bonus()` (Task 8).
- Produces: nothing new — pure wiring.

- [ ] **Step 1: Update `the_gap.gd`**

Find:

```gdscript
func _set_hero_placeholder_stats() -> void:
	_hero.apply_placeholder_base_stats()
```

Replace with:

```gdscript
func _set_hero_placeholder_stats() -> void:
	_hero.apply_placeholder_base_stats()
	# Hero Combat & Stats Redesign (2026-09-18), Section 3.4.1: resolved once
	# here (Hero's stats are fixed for the whole mission once applied — no
	# mid-mission equipment/level changes exist yet) and pushed into
	# ResourceEconomy, which never reads Hero directly (no cross-system
	# reference exists between them otherwise).
	_resource_economy.set_hero_luck_drop_bonus(_hero.get_effective_stat(&"luck"))
```

(If the scene's `ResourceEconomy` node reference uses a different variable name than `_resource_economy`, use whatever it actually is — grep `the_gap.gd` for `ResourceEconomy` first and match the real name exactly.)

- [ ] **Step 2: Update `mission_scene.gd`**

Find:

```gdscript
func _set_hero_placeholder_stats() -> void:
	_hero.apply_placeholder_base_stats()
```

Replace with:

```gdscript
func _set_hero_placeholder_stats() -> void:
	_hero.apply_placeholder_base_stats()
	# Hero Combat & Stats Redesign (2026-09-18), Section 3.4.1 — see
	# the_gap.gd's identical wiring for the full rationale.
	_resource_economy.set_hero_luck_drop_bonus(_hero.get_effective_stat(&"luck"))
```

(Same caveat as Step 1 — match the scene's actual `ResourceEconomy` reference variable name.)

- [ ] **Step 3: Run the mission-scene integration tests**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/integration/mission_scene -a res://tests/integration/mission-scene`
Expected: all pass — Luck defaults to `0.0` in `PLACEHOLDER_BASE_STATS` (Task 1), so `get_effective_stat(&"luck")` resolves to `0.0` and `set_hero_luck_drop_bonus(0.0)` is a no-op relative to today's behavior; no existing assertion should change.

- [ ] **Step 4: Commit**

```bash
git add src/gameplay/missions/the_gap/the_gap.gd src/scenes/mission_scene.gd
git commit -m "Wire Hero's Luck stat into ResourceEconomy at mission start"
```

---

## Task 10: Update hero.md GDD

**Files:**
- Modify: `design/gdd/hero.md`

**Interfaces:** N/A — documentation only.

- [ ] **Step 1: Update the 12-stat table (Group 1, ~line 39-52)**

Find:

```markdown
| # | Stat | Governs |
|---|------|---------|
| 1 | Health (HP) | Total hit points. Hero dies at 0 → DEFEAT immediately. |
| 2 | Damage | Base value for auto-attack and physical skill calculations. |
| 3 | Movement Speed | World-units per second, all directions. |
| 4 | Cooldown Reduction (CDR) | % reduction to skill cooldown durations. Cap: 75%. Does NOT affect auto-attack rate. |
| 5 | Crit Chance | Probability (0–80%) a hit applies the Crit Multiplier. |
| 6 | Armor | Reduces incoming damage via a mitigation formula (see Formulas). |
| 7 | Skill Power | Multiplier for skills tagged `[SKILL_POWER_SCALING]`. Does not affect auto-attack. |
| 8 | Attack Range | World-unit radius within which auto-attack acquires a target. |
| 9 | Elemental Resistances | Per-element % damage reduction (fire, frost, poison, lightning, arcane). Cap: 75% per element. |
| 10 | Lifesteal | % of auto-attack damage returned as HP. Cap: 40%. Cannot overheal. |
| 11 | Tower Affinity | % bonus to Damage and Skill Power per tower placed, using a square-root scaling curve (see Formulas). |
| 12 | Crit Multiplier | Damage multiplier when a crit is triggered. Base: 1.75×. Equipment and perks add additively. Floor: 1.0×. |
```

Replace with:

```markdown
| # | Stat | Governs |
|---|------|---------|
| 1 | Health (HP) | Total hit points. Hero dies at 0 → DEFEAT immediately. |
| 2 | Physical Attack | Scales any ability whose damage_type is "physical", including auto-attack. Replaces the old "Damage" stat (Hero Combat & Stats Redesign, 2026-09-18). |
| 3 | Movement Speed | World-units per second, all directions. |
| 4 | Cooldown Reduction (CDR) | % reduction to skill cooldown durations. Cap: 75%. Does NOT affect auto-attack rate. |
| 5 | Crit Chance | Probability a hit applies the Crit Multiplier, via a diminishing-returns curve asymptotically approaching 85% (see Formulas) — no longer a flat 80% hard clamp. |
| 6 | Armor | Reduces incoming damage TO the Hero via a mitigation formula (see Formulas). Distinct from a monster's own Armor stat (design/gdd/monster.md), which reduces the Hero's outgoing Physical Attack damage instead. |
| 7 | Magic Attack | Scales any ability whose damage_type is fire/ice/poison/lightning/arcane. Replaces the old "Skill Power" stat (Hero Combat & Stats Redesign, 2026-09-18). |
| 8 | Attack Range | World-unit radius within which auto-attack acquires a target. |
| 9 | Elemental Resistances | Per-element % damage reduction TO the Hero (fire, frost, poison, lightning, arcane). Cap: 75% per element. Distinct from a monster's own elemental_resistances, which reduce the Hero's outgoing Magic Attack damage instead. |
| 10 | Lifesteal | % of auto-attack damage returned as HP. Cap: 40%. Cannot overheal. |
| 11 | Tower Affinity | % bonus to Physical Attack and Magic Attack per tower placed, using a square-root scaling curve (see Formulas). |
| 12 | Crit Multiplier | Damage multiplier when a crit is triggered, via a diminishing-returns curve. Base: 1.5× (was 1.75×). Cap: 3.5×. Equipment and perks add to the curve's raw input. |
| 13 | Luck | New stat (Hero Combat & Stats Redesign, 2026-09-18). Boosts monster drop-occurrence chance and contributes a secondary Crit Chance source, via its own diminishing-returns curve asymptotically approaching 35%. |
```

- [ ] **Step 2: Update the Formula 1 prose (line 172) to reflect the curve replacing hard clamps for 3 stats**

Find:

```markdown
Applies to all 12 stats. Flat bonuses resolve before percentage bonuses, which means flat affixes feel more impactful at low base values (early-game equipment matters). All percentage bonuses collapse into a single additive bucket to prevent multiplicative stacking spirals.
```

Replace with:

```markdown
Applies to all 13 stats. Flat bonuses resolve before percentage bonuses, which means flat affixes feel more impactful at low base values (early-game equipment matters). All percentage bonuses collapse into a single additive bucket to prevent multiplicative stacking spirals. For Crit Chance, Crit Multiplier, and Luck specifically, this formula's result becomes the "Raw" input to a further diminishing-returns curve (Formula 7) rather than a flat hard clamp — see that formula for the full mechanic.
```

- [ ] **Step 3: Add a new Formula 7 section documenting the diminishing-returns curve**

Find the end of the Formulas section — locate the last `### Formula N:` heading in `hero.md` (search for `### Formula` to find the highest-numbered one) and append immediately after its content, before the next top-level section:

```markdown
### Formula 7: Diminishing-Returns Curve (Crit Chance / Crit Multiplier / Luck)

Replaces a flat hard clamp for exactly these 3 stats — every other capped stat (Lifesteal, CDR, Elemental Resist) keeps a flat clamp.

```
Actual = (Raw × HardCap) / (Raw + ScalingConstant)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Raw stat | `Raw` | float | ≥ 0 | The stat's Formula 1 result, before this curve applies |
| Hard cap | `HardCap` | float | stat-specific | The value Actual asymptotically approaches but never reaches |
| Scaling constant | `ScalingConstant` | float | stat-specific | Raw value at which Actual reaches exactly half of HardCap |
| Actual | `Actual` | float | 0 – HardCap | The final, game-facing value |

| Stat | Hard Cap | Scaling Constant |
|------|----------|-------------------|
| Crit Chance | 85% | 0.5 |
| Crit Multiplier (bonus portion only — 1.5× base added on top) | 2.0× (so 3.5× total) | 1.0 |
| Luck | 35% | 0.5 |

**Example (Crit Chance, Raw = 0.5):** `Actual = (0.5 × 0.85) / (0.5 + 0.5) = 0.425 / 1.0 = 42.5%`

**Example (Crit Multiplier, Raw = 1.0):** `Actual = 1.5 + (1.0 × 2.0) / (1.0 + 1.0) = 1.5 + 1.0 = 2.5×`

Luck also contributes a secondary Crit Chance source: `effective_crit_chance = min(Actual(crit_chance) + Actual(luck), 0.85)` — both curved independently, then summed and re-clamped so a maxed build never exceeds the 85% ceiling from combining both sources.

---
```

- [ ] **Step 4: Update the "Player Fantasy" or nearby introductory line referencing "12 base stats" if any other section repeats that count**

Search `hero.md` for the literal string `12 base stats` or `12 stats` outside the table already updated in Step 1, and update each occurrence to `13`.

- [ ] **Step 5: Commit**

```bash
git add design/gdd/hero.md
git commit -m "Update hero.md GDD for Physical/Magic Attack split, Luck stat, diminishing-returns curves"
```

---

## Task 11: Update monster.md GDD

**Files:**
- Modify: `design/gdd/monster.md`

**Interfaces:** N/A — documentation only.

- [ ] **Step 1: Add Armor/Evasion to the Entity Data Schema (Group 1)**

Search `monster.md` for its per-monster data schema table/list (the section `monster_resource.gd`'s own doc comment cites as "GDD source: design/gdd/monster.md — Group 1 (Entity Data Schema)"). Add two new rows/fields matching the existing table's format:

```markdown
| Armor | float, default 0.0 | Mitigates the Hero's own outgoing Physical Attack damage only (never tower damage). Formula: Mitigation% = Armor / (Armor + 50 × Hero Level). See hero.md Formula 7's governing spec for the full mechanic. |
| Evasion | float [0, 100], default 0.0 | Flat percentage chance the Hero's attack (any damage type) misses this monster entirely. Rolled before any damage math. Never affects tower damage. |
```

- [ ] **Step 2: Commit**

```bash
git add design/gdd/monster.md
git commit -m "Document Armor/Evasion fields in monster.md GDD"
```

---

## Task 12: Full regression run across every touched area

**Files:** none (verification only).

- [ ] **Step 1: Force an editor-mode reimport first**

Run: `"<GODOT_PATH>" --headless --editor --path . --quit`
This refreshes the global `class_name` cache — required after adding new fields/consts to existing classes, per this project's own documented gotcha (`docs/engine-reference/godot/VERSION.md`).

- [ ] **Step 2: Run the full set of touched test directories together**

Run: `bash addons/gdUnit4/runtest.sh --godot_binary "<GODOT_PATH>" -a res://tests/unit/hero -a res://tests/integration/hero -a res://tests/unit/damage_status -a res://tests/unit/monster -a res://tests/unit/resource_economy -a res://tests/integration/resource_economy -a res://tests/integration/mission_scene -a res://tests/integration/mission-scene -a res://tests/unit/inventory`
Expected: 0 errors, 0 failures across all suites. If any test fails, return to the owning task above, fix it there (not ad-hoc here), and re-run this full command from scratch.

- [ ] **Step 3: No commit needed for this task** (verification-only) — if Step 2 required any fix, that fix's commit belongs to the task it corrects, per this plan's own task boundaries. Report the final clean run to the user.
