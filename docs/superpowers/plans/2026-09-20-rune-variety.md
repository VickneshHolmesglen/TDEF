# Rune Variety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the 22 runes themed, targeted flat stat bonuses (plus two all-stats wildcards) instead of one generic +5%, with all values in data.

**Architecture:** Values live in three data homes (a new `TarotCardResource.rune_stat_delta`, the existing `SacrificeRecipeResource.stat_delta`, a new `Constellation.SHAPE_RUNE_STAT_DELTA` table). `EquipmentForge.resolve_rune_stat_delta()` reads them, falling back to the old +5% all-stats when a value is missing. Hero, `EquipmentBonuses` and the info panel are unchanged.

**Tech Stack:** Godot 4.6.2, GDScript, gdUnit4, `.tres` resources.

**Spec:** `docs/superpowers/specs/2026-09-20-rune-variety-design.md`

## Global Constraints

- Values in spec §4 are authoritative; copy them exactly.
- `resolve_rune_stat_delta(rune_id: StringName) -> Dictionary` keeps its name, `static`-ness and unknown-rune behavior (`{}`).
- Wildcards (`rune_cross_plus`, `rune_menagerie_aurora_stag`) resolve to `additive_bonus_total` only; every other rune to flat keys only.
- `TarotCardResource.rune_bonus_flat` (Tarot's own F5 bonus) and the Forge ledger's vestigial `stat_delta` are NOT touched.
- No `#` comments inside `.tscn`/`.tres` blocks. Typed GDScript. New `class_name` files need a class-cache rebuild (none are added here).
- Editing `.tres` via shell: `sed` and bash `${var//&/..}` treat `&` as "the matched text" and corrupt `&"stat"` literals. Use `awk` with `ENVIRON` (as below). No python on this machine.
- Test runner: `"C:\Users\Shaukan\Desktop\Godot_v4.6.2-stable_win64.exe" --headless --path G:\TDef --script tests/gdunit4_runner.gd -- -a <res:// path> --ignoreHeadlessMode`. Run only the targeted suites named here.
- Commit and push after each task's tests pass (standing user rule); messages end with `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.

## File Structure

- Modify `src/core/tarot/tarot_card_resource.gd` — add `rune_stat_delta` export.
- Modify `src/core/constellation/constellation.gd` — add `SHAPE_RUNE_STAT_DELTA`.
- Modify `src/core/equipment_forge/equipment_forge.gd` — resolver + `_rune_delta_or_fallback()`.
- Modify `assets/data/tarot/card_*.tres` (13) and `assets/data/sacrifice_recipes/sacrifice_*.tres` (4 of 5 change; aurora_stag unchanged) — values.
- Modify existing tests that assume the old uniform bonus (Task 1).
- Create `tests/unit/equipment_forge/rune-variety-content_test.gd` (Task 2).
- Modify `design/gdd/equipment-forge.md` (one note), `production/session-state/active.md`.

---

### Task 1: Data plumbing, resolver, fallback

**Files:**
- Modify: `src/core/tarot/tarot_card_resource.gd` (after `linked_rune_id`, ~line 21)
- Modify: `src/core/constellation/constellation.gd` (after `SHAPE_COMPLEXITY_BONUS`, ~line 61)
- Modify: `src/core/equipment_forge/equipment_forge.gd` (`resolve_rune_stat_delta()`, ~lines 181-203)
- Modify tests: `tests/unit/equipment_forge/rune-stat-delta-resolution_test.gd`, `tests/unit/equipment/equipment_bonuses_test.gd`, `tests/unit/inventory/equipment_info_panel_test.gd`

**Interfaces:**
- Produces: `TarotCardResource.rune_stat_delta: Dictionary[StringName, float]`; `Constellation.SHAPE_RUNE_STAT_DELTA: Dictionary[String, Dictionary]`; `static EquipmentForge._rune_delta_or_fallback(delta: Dictionary) -> Dictionary` (returns a duplicate of `delta`, or `{"additive_bonus_total": RUNE_ADDITIVE_BONUS}` when `delta` is empty).

- [ ] **Step 1: Update/add failing tests**

In `tests/unit/equipment_forge/rune-stat-delta-resolution_test.gd`, replace `test_constellation_rune_resolves_to_fixed_additive_bonus` and `test_tarot_rune_resolves_to_fixed_additive_bonus` with:

```gdscript
func test_constellation_themed_rune_resolves_to_flat_stats() -> void:
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(&"rune_triad_line")
	assert_int(delta.size()).is_equal(1)
	assert_float(float(delta[&"physical_attack"])).is_equal_approx(5.0, 0.0001)
	assert_bool(delta.has("additive_bonus_total")).is_false()


func test_constellation_wildcard_rune_resolves_to_additive_only() -> void:
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(&"rune_cross_plus")
	assert_int(delta.size()).is_equal(1)
	assert_float(float(delta[&"additive_bonus_total"])).is_equal_approx(EquipmentForge.RUNE_ADDITIVE_BONUS, 0.0001)


func test_tarot_rune_resolves_to_card_rune_stat_delta_or_fallback() -> void:
	var cards: Dictionary = GGameDataRegistry.get_all_tarot_cards()
	if cards.is_empty():
		return
	var card: TarotCardResource = cards.values()[0]
	var expected: Dictionary = card.rune_stat_delta if not card.rune_stat_delta.is_empty() else {"additive_bonus_total": EquipmentForge.RUNE_ADDITIVE_BONUS}
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(card.linked_rune_id)
	assert_int(delta.size()).is_equal(expected.size())
	for key: Variant in expected:
		assert_float(float(delta[key])).is_equal_approx(float(expected[key]), 0.0001)


func test_fallback_helper_returns_generic_bonus_for_empty_delta() -> void:
	var delta: Dictionary = EquipmentForge._rune_delta_or_fallback({})
	assert_int(delta.size()).is_equal(1)
	assert_float(float(delta["additive_bonus_total"])).is_equal_approx(EquipmentForge.RUNE_ADDITIVE_BONUS, 0.0001)


func test_fallback_helper_passes_through_and_copies_nonempty_delta() -> void:
	var source: Dictionary = {&"armor": 10.0}
	var delta: Dictionary = EquipmentForge._rune_delta_or_fallback(source)
	assert_float(float(delta[&"armor"])).is_equal_approx(10.0, 0.0001)
	delta[&"armor"] = 99.0
	assert_float(float(source[&"armor"])).is_equal_approx(10.0, 0.0001)
```

In `tests/unit/equipment/equipment_bonuses_test.gd` (`test_compute_constellation_rune_fans_out_additive`) and `tests/unit/inventory/equipment_info_panel_test.gd` (`test_bonuses_state_shows_all_stats_row_for_fan_out_rune`), change the line `var shape_id: String = Constellation.SHAPE_N.keys()[0]` to `var shape_id: String = "cross_plus"` (the wildcard is the only Constellation rune that fans out now).

- [ ] **Step 2: Run to verify failure**

Run `res://tests/unit/equipment_forge/rune-stat-delta-resolution_test.gd`. Expected: FAIL — `_rune_delta_or_fallback` missing / triad_line still returns additive.

- [ ] **Step 3: Implement**

`tarot_card_resource.gd`, directly after `@export var linked_rune_id: StringName = &""`:

```gdscript

## Equipment-imbue bonus of this card's linked rune (rune-variety spec §3.1):
## a themed flat stat delta, e.g. {&"luck": 0.08}, or {&"additive_bonus_total": 0.05}
## for an all-stats wildcard. Only meaningful when linked_rune_id is non-empty.
## DISTINCT from rune_bonus_flat below (Tarot's own in-mission Formula F5
## bonus). Empty => EquipmentForge falls back to the generic +5% all-stats.
@export var rune_stat_delta: Dictionary[StringName, float] = {}
```

`constellation.gd`, after the `SHAPE_COMPLEXITY_BONUS` block:

```gdscript

## Equipment-Forge rune bonus per shape (rune-variety spec §3.1/§4), keyed by
## SHAPE_N's keys. Read by EquipmentForge.resolve_rune_stat_delta() for
## rune_id "rune_<shape_id>". Deliberately decoupled from BASE_UNIT_BONUS/
## complexity above (constellation.md Core Rule 12). cross_plus is the
## all-stats wildcard. A shape missing here falls back to the generic +5%.
const SHAPE_RUNE_STAT_DELTA: Dictionary[String, Dictionary] = {
	"triad_line": {&"physical_attack": 5.0},
	"quad_line": {&"attack_range": 24.0, &"physical_attack": 2.5},
	"l_corner": {&"magic_attack": 7.5},
	"cross_plus": {&"additive_bonus_total": 0.05},
}
```

`equipment_forge.gd`: replace `resolve_rune_stat_delta()` (keep its existing doc comment, appending one sentence: "Rune-variety spec: values now come from data (Constellation/Tarot/Menagerie), with a generic fallback.") with:

```gdscript
static func resolve_rune_stat_delta(rune_id: StringName) -> Dictionary:
	if rune_id == &"":
		return {}
	var id_str: String = String(rune_id)
	for shape_id: String in Constellation.SHAPE_N:
		if id_str == "rune_%s" % shape_id:
			return _rune_delta_or_fallback(Constellation.SHAPE_RUNE_STAT_DELTA.get(shape_id, {}))
	for card: TarotCardResource in GGameDataRegistry.get_all_tarot_cards().values():
		if String(card.linked_rune_id) == id_str:
			return _rune_delta_or_fallback(card.rune_stat_delta)
	for recipe: SacrificeRecipeResource in GGameDataRegistry.get_all_sacrifice_recipes().values():
		if String(recipe.rune_id) == id_str:
			return recipe.stat_delta.duplicate()
	return {}


## A missing/empty authored rune value falls back to the original generic
## +5% all-stats bonus rather than resolving to nothing (rune-variety spec §3.2).
static func _rune_delta_or_fallback(delta: Dictionary) -> Dictionary:
	if delta.is_empty():
		return {"additive_bonus_total": RUNE_ADDITIVE_BONUS}
	return delta.duplicate()
```

- [ ] **Step 4: Run tests**

Run `res://tests/unit/equipment_forge`, `res://tests/unit/equipment`, `res://tests/unit/inventory/equipment_info_panel_test.gd`, `res://tests/unit/equipment-forge`, `res://tests/integration/equipment-forge`, `res://tests/unit/hero`, and `res://tests/unit/tarot` (if the directory exists).
Expected: all PASS (every Tarot rune still resolves via the fallback until Task 2).

- [ ] **Step 5: Commit and push**

```bash
git add src/core/tarot/tarot_card_resource.gd src/core/constellation/constellation.gd src/core/equipment_forge/equipment_forge.gd tests/unit/equipment_forge/rune-stat-delta-resolution_test.gd tests/unit/equipment/equipment_bonuses_test.gd tests/unit/inventory/equipment_info_panel_test.gd
git commit -m "Add data-driven rune value plumbing (Tarot field, Constellation table, fallback)

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

### Task 2: Author the rune values + content test

**Files:**
- Modify: `assets/data/tarot/card_*.tres` (13 — insert `rune_stat_delta` after `linked_rune_id`)
- Modify: `assets/data/sacrifice_recipes/sacrifice_{duskfang_fox,emberwing_moth,glimmer_hare,mossback_toad}.tres` (replace `stat_delta`; `aurora_stag` is already the correct wildcard 0.08)
- Modify: `design/gdd/equipment-forge.md` (one note under Formula 3), `production/session-state/active.md`
- Test: `tests/unit/equipment_forge/rune-variety-content_test.gd`

**Interfaces:**
- Consumes: `EquipmentForge.resolve_rune_stat_delta`, `EquipmentForge.is_rune_id_known`, `EquipmentBonuses.compute`, `EquipmentBonuses.FAN_OUT_STATS`.

- [ ] **Step 1: Write the failing content test**

```gdscript
extends GdUnitTestSuite

## Content-integrity tests for the authored rune values (rune-variety spec
## §4, AC-1..AC-6). The EXPECTED table below is the spec's authoritative
## value list; editing a rune's value in data must be a deliberate edit here too.

const EXPECTED: Dictionary[StringName, Dictionary] = {
	&"rune_triad_line": {&"physical_attack": 5.0},
	&"rune_quad_line": {&"attack_range": 24.0, &"physical_attack": 2.5},
	&"rune_l_corner": {&"magic_attack": 7.5},
	&"rune_cross_plus": {&"additive_bonus_total": 0.05},
	&"rune_apex_predator": {&"crit_chance": 0.04, &"crit_multiplier": 0.10},
	&"rune_hunters_pace": {&"move_speed": 15.0, &"attack_range": 12.0},
	&"rune_swift_current": {&"move_speed": 20.0, &"cdr": 0.02},
	&"rune_reckless_onslaught": {&"physical_attack": 6.25, &"crit_chance": 0.03},
	&"rune_cautious_advance": {&"armor": 15.0, &"move_speed": 5.0},
	&"rune_golden_ticket": {&"luck": 0.08},
	&"rune_bountiful_harvest": {&"luck": 0.06, &"max_hp": 50.0},
	&"rune_lucky_charm": {&"luck": 0.04, &"crit_chance": 0.03},
	&"rune_grinding_gauntlet": {&"max_hp": 75.0, &"physical_attack": 3.75},
	&"rune_grim_resolve": {&"max_hp": 100.0, &"lifesteal": 0.01},
	&"rune_iron_resolve": {&"armor": 20.0, &"elemental_resist_fire": 0.045, &"elemental_resist_frost": 0.045},
	&"rune_measured_pace": {&"cdr": 0.03, &"armor": 10.0},
	&"rune_steady_hand": {&"crit_chance": 0.04, &"attack_range": 16.0},
	&"rune_menagerie_aurora_stag": {&"additive_bonus_total": 0.08},
	&"rune_menagerie_duskfang_fox": {&"crit_chance": 0.05, &"move_speed": 10.0},
	&"rune_menagerie_emberwing_moth": {&"magic_attack": 7.5, &"elemental_resist_fire": 0.06},
	&"rune_menagerie_glimmer_hare": {&"move_speed": 10.0, &"luck": 0.03},
	&"rune_menagerie_mossback_toad": {&"armor": 10.0, &"elemental_resist_frost": 0.045},
}

const WILDCARDS: Array[StringName] = [&"rune_cross_plus", &"rune_menagerie_aurora_stag"]

## Loose per-stat ceilings for a single rune (tripwire for a stray extra zero).
const MAX_FLAT: Dictionary[StringName, float] = {
	&"max_hp": 150.0, &"armor": 40.0, &"physical_attack": 15.0, &"magic_attack": 15.0,
	&"move_speed": 40.0, &"attack_range": 40.0, &"crit_chance": 0.10,
	&"crit_multiplier": 0.25, &"luck": 0.15, &"cdr": 0.08, &"lifesteal": 0.04,
	&"elemental_resist_fire": 0.12, &"elemental_resist_frost": 0.12,
}


func test_there_are_exactly_22_expected_runes() -> void:
	assert_int(EXPECTED.size()).is_equal(22)


func test_every_rune_resolves_to_exactly_its_spec_value() -> void:
	for rune_id: StringName in EXPECTED:
		var expected: Dictionary = EXPECTED[rune_id]
		var actual: Dictionary = EquipmentForge.resolve_rune_stat_delta(rune_id)
		assert_int(actual.size()).override_failure_message("%s: key count" % rune_id).is_equal(expected.size())
		for stat: StringName in expected:
			assert_bool(actual.has(stat)).override_failure_message("%s missing %s" % [rune_id, stat]).is_true()
			assert_float(float(actual[stat])).override_failure_message("%s.%s" % [rune_id, stat]).is_equal_approx(float(expected[stat]), 0.0001)


func test_only_the_two_wildcards_use_additive_bonus_total() -> void:
	for rune_id: StringName in EXPECTED:
		var actual: Dictionary = EquipmentForge.resolve_rune_stat_delta(rune_id)
		assert_bool(actual.has(&"additive_bonus_total")).override_failure_message(rune_id).is_equal(WILDCARDS.has(rune_id))


func test_all_stat_keys_are_real_and_values_within_ceilings() -> void:
	for rune_id: StringName in EXPECTED:
		var actual: Dictionary = EquipmentForge.resolve_rune_stat_delta(rune_id)
		for stat: Variant in actual:
			var key: StringName = StringName(stat)
			var value: float = float(actual[stat])
			assert_float(value).override_failure_message("%s.%s must be > 0" % [rune_id, key]).is_greater(0.0)
			if key == &"additive_bonus_total":
				assert_float(value).is_between(0.02, 0.08)
			else:
				assert_bool(EquipmentBonuses.FAN_OUT_STATS.has(key)).override_failure_message("%s: unknown stat '%s'" % [rune_id, key]).is_true()
				assert_float(value).override_failure_message("%s.%s=%s exceeds ceiling" % [rune_id, key, value]).is_less_equal(MAX_FLAT[key])


func test_every_rune_id_is_known_to_the_forge() -> void:
	var forge: EquipmentForge = EquipmentForge.new()
	for rune_id: StringName in EXPECTED:
		assert_bool(forge.is_rune_id_known(rune_id)).override_failure_message(rune_id).is_true()
	forge.free()


func test_no_registered_rune_is_missing_from_the_expected_table() -> void:
	var registered: Array[StringName] = []
	for shape_id: String in Constellation.SHAPE_N:
		registered.append(StringName("rune_%s" % shape_id))
	for card: TarotCardResource in GGameDataRegistry.get_all_tarot_cards().values():
		if card.linked_rune_id != &"":
			registered.append(card.linked_rune_id)
	for recipe: SacrificeRecipeResource in GGameDataRegistry.get_all_sacrifice_recipes().values():
		registered.append(recipe.rune_id)
	assert_int(registered.size()).is_equal(EXPECTED.size())
	for rune_id: StringName in registered:
		assert_bool(EXPECTED.has(rune_id)).override_failure_message("%s not in EXPECTED" % rune_id).is_true()


func test_themed_rune_raises_only_its_targeted_stats() -> void:
	var contents: Dictionary = {"item_id": "iron_helm", "stat_overrides": {&"armor": 0.0001}, "imbued_runes": ["rune_golden_ticket"], "rune_slot_count": 1}
	var r: Dictionary = EquipmentBonuses.compute([contents])
	assert_float(r["flat"][&"luck"]).is_equal_approx(0.08, 0.0001)
	assert_bool((r["additive"] as Dictionary).is_empty()).is_true()
	for stat: StringName in r["flat"]:
		assert_bool(stat == &"luck" or stat == &"armor" or stat == &"max_hp").override_failure_message("unexpected stat %s" % stat).is_true()
```

(`max_hp`/`armor` are allowed in the last test only because `iron_helm`'s own `base_stats`/override contribute them; the assertion is that the RUNE adds luck and nothing else beyond the item's own stats.)

- [ ] **Step 2: Run to verify it fails**

Run `res://tests/unit/equipment_forge/rune-variety-content_test.gd`. Expected: FAIL — Tarot runes still resolve to the generic fallback; four Menagerie runes still all-stats.

- [ ] **Step 3: Author the values**

Run this script from `G:\TDef` (Git Bash). It uses `awk` + `ENVIRON`, never `sed`, to avoid the `&` corruption. It inserts a `rune_stat_delta` line after `linked_rune_id` in each Tarot card, and replaces the `stat_delta` line in four Menagerie recipes:

```bash
cd /g/TDef
tarot() {  # $1=card file stem  $2=dict literal
  export NEWLINE="rune_stat_delta = $2"
  f="assets/data/tarot/card_$1.tres"
  awk '/^rune_stat_delta = /{next} {print} /^linked_rune_id = /{print ENVIRON["NEWLINE"]}' "$f" > "$f.new" && mv "$f.new" "$f"
}
tarot apex_predator       '{&"crit_chance": 0.04, &"crit_multiplier": 0.10}'
tarot hunters_pace        '{&"move_speed": 15.0, &"attack_range": 12.0}'
tarot swift_current       '{&"move_speed": 20.0, &"cdr": 0.02}'
tarot reckless_onslaught  '{&"physical_attack": 6.25, &"crit_chance": 0.03}'
tarot cautious_advance    '{&"armor": 15.0, &"move_speed": 5.0}'
tarot golden_ticket       '{&"luck": 0.08}'
tarot bountiful_harvest   '{&"luck": 0.06, &"max_hp": 50.0}'
tarot lucky_charm         '{&"luck": 0.04, &"crit_chance": 0.03}'
tarot grinding_gauntlet   '{&"max_hp": 75.0, &"physical_attack": 3.75}'
tarot grim_resolve        '{&"max_hp": 100.0, &"lifesteal": 0.01}'
tarot iron_resolve        '{&"armor": 20.0, &"elemental_resist_fire": 0.045, &"elemental_resist_frost": 0.045}'
tarot measured_pace       '{&"cdr": 0.03, &"armor": 10.0}'
tarot steady_hand         '{&"crit_chance": 0.04, &"attack_range": 16.0}'

menagerie() {  # $1=species  $2=dict literal
  export NEWLINE="stat_delta = $2"
  f="assets/data/sacrifice_recipes/sacrifice_$1.tres"
  awk '/^stat_delta = /{print ENVIRON["NEWLINE"]; next} {print}' "$f" > "$f.new" && mv "$f.new" "$f"
}
menagerie duskfang_fox   '{&"crit_chance": 0.05, &"move_speed": 10.0}'
menagerie emberwing_moth '{&"magic_attack": 7.5, &"elemental_resist_fire": 0.06}'
menagerie glimmer_hare   '{&"move_speed": 10.0, &"luck": 0.03}'
menagerie mossback_toad  '{&"armor": 10.0, &"elemental_resist_frost": 0.045}'

grep -c '^rune_stat_delta = {&"' assets/data/tarot/card_*.tres | grep -c ':1'   # expect 13
grep -h '^stat_delta' assets/data/sacrifice_recipes/*.tres                      # expect 5 lines, only aurora_stag has additive_bonus_total
git diff --stat assets/data | tail -1                                           # expect 17 files changed
```

Check one file's diff to confirm exactly one added line (Tarot) or one changed line (Menagerie) and that `&"` literals survived.

- [ ] **Step 4: Run tests**

Run `res://tests/unit/equipment_forge/rune-variety-content_test.gd`, then `res://tests/unit/equipment_forge`, `res://tests/unit/equipment`, `res://tests/unit/inventory`, `res://tests/unit/equipment-forge`, `res://tests/integration/equipment-forge`, `res://tests/integration/equipment-forge-screen`, `res://tests/unit/hero`, and every Tarot test directory (`tests/unit/tarot*`, `tests/integration/tarot*` — find with `ls tests/unit tests/integration | grep -i tarot`).
Expected: all PASS. If a Tarot or Forge test fails because it hardcodes the old uniform value, update ONLY that assertion to the new value (spec AC-7) and note it in the commit message.

- [ ] **Step 5: Docs, state, commit and push**

Add under the `### Formula 3 — Rune Stat Bonus Magnitude` heading in `design/gdd/equipment-forge.md` (via Edit, one blockquote line right after the heading):

```
> **Update 2026-09-20:** rune magnitudes are now authored per rune (themed flat stats, two all-stats wildcards) — see `docs/superpowers/specs/2026-09-20-rune-variety-design.md`. The flat-rune path defined below is in use.
```

Append a short "Rune Variety shipped" extract to `production/session-state/active.md` (what changed, the wildcard pair, that existing imbued runes re-resolve automatically, that live verification is still deferred by the user, and any AC-7 test edits made).

```bash
git add assets/data/tarot assets/data/sacrifice_recipes tests/unit/equipment_forge/rune-variety-content_test.gd design/gdd/equipment-forge.md production/session-state/active.md
git commit -m "Author themed rune stats for all 22 runes

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push
```

---

## Self-Review

- **Spec coverage:** §3.1 storage → Task 1 (Tarot field, Constellation table) + Task 2 (data); §3.2 resolution/fallback → Task 1; §3.3 scale + §4 values → Task 2 script and `EXPECTED`; no-save-migration → no task needed (documented in spec, verified by on-demand resolution); AC-1/2/4/6 → Task 2 tests; AC-3 → Task 1 fallback tests; AC-5 → `test_themed_rune_raises_only_its_targeted_stats`; AC-7 → Task 1 test updates + Task 2 Step 4 instruction.
- **Placeholders:** none. The one conditional ("update only a test that hardcodes the old value") is bounded by AC-7 and has a concrete rule.
- **Type consistency:** `rune_stat_delta` / `SHAPE_RUNE_STAT_DELTA` / `_rune_delta_or_fallback` named identically across tasks and the spec; wildcard ids match spec §4.
