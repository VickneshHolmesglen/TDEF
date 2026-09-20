# Equipment & Rune Stats Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make equipped items and imbued runes actually change Hero's effective combat stats.

**Architecture:** Hero subscribes to `equipment_slot_changed` / `item_rune_imbued` and fully recomputes `_flat_bonuses` / `_additive_bonuses` from `GInventory`'s live equipped slots. Imbued rune bonuses are resolved on demand from `rune_id` via a new static `EquipmentForge.resolve_rune_stat_delta()` (nothing new persisted).

**Tech Stack:** Godot 4.6.2, GDScript, gdUnit4.

**Spec:** `docs/superpowers/specs/2026-09-20-equipment-stats-wiring-design.md`

## Global Constraints

- Wiring only; do NOT author real `base_stats` for the 36 equipment items.
- `get_effective_stat()`, `_apply_stat_cap()`, Formula 1 are NOT modified.
- Recompute is FULL REPLACE of `_flat_bonuses`/`_additive_bonuses`, never incremental.
- Literal key `&"additive_bonus_total"` fans out into `_additive_bonuses` for all 14 `_base_stats` keys; every other key goes into `_flat_bonuses[key]`.
- Unknown rune_id → `{}`; unknown stat key → silently inert; null item definition → skip.
- Typed GDScript, snake_case, no `#` comments in `.tscn`/`.tres`. Hero subscriptions connect in `_ready()`, disconnect in `_exit_tree()`.
- Only run the targeted tests named in this plan (project rule: no full-suite runs unasked).

## Deviations from the spec (found while reading the code)

1. **`GEquipmentForge` does not exist.** `EquipmentForge` is a `class_name` Node, not an autoload (tests do `EquipmentForge.new()`). So `resolve_rune_stat_delta()` is a **`static func`**, called as `EquipmentForge.resolve_rune_stat_delta(...)`. It only touches consts and the `GGameDataRegistry` autoload, so static is safe.
2. **Initial recompute.** A `Hero` is created per mission, after gear was already equipped in the Sanctuary, so no `equipment_slot_changed` fires for it. `_ready()` must call `_recompute_equipment_bonuses()` once after connecting.

## File Structure

- Modify `src/core/equipment_forge/equipment_forge.gd` — add static `resolve_rune_stat_delta()` next to `is_rune_id_known()` (~line 165).
- Modify `src/core/hero/hero.gd` — add `EQUIPMENT_FAN_OUT_STATS` const, `_recompute_equipment_bonuses()`, static `_fold_stat_entry()`, two handlers, subscribe/unsubscribe, initial call.
- Create `tests/unit/equipment_forge/rune-stat-delta-resolution_test.gd`
- Create `tests/unit/hero/hero_equipment_stats_test.gd`

---

### Task 1: `EquipmentForge.resolve_rune_stat_delta()`

**Files:**
- Modify: `src/core/equipment_forge/equipment_forge.gd` (insert after `is_rune_id_known()`, ends ~line 178)
- Test: `tests/unit/equipment_forge/rune-stat-delta-resolution_test.gd`

**Interfaces:**
- Produces: `static func resolve_rune_stat_delta(rune_id: StringName) -> Dictionary` (returns `{StringName/String: float}`; `{}` if unknown).

- [ ] **Step 1: Write the failing test**

```gdscript
extends GdUnitTestSuite

## Unit tests for EquipmentForge.resolve_rune_stat_delta() (equipment-stats-
## wiring spec §3.4, AC-4/AC-5/AC-7).

var _forge: EquipmentForge


func before_test() -> void:
	_forge = EquipmentForge.new()


func after_test() -> void:
	if _forge != null and is_instance_valid(_forge):
		_forge.free()
	_forge = null


func test_constellation_rune_resolves_to_fixed_additive_bonus() -> void:
	var shape_id: String = Constellation.SHAPE_N.keys()[0]
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(StringName("rune_%s" % shape_id))
	assert_dict(delta).contains_key_value("additive_bonus_total", EquipmentForge.RUNE_ADDITIVE_BONUS)
	assert_int(delta.size()).is_equal(1)


func test_tarot_rune_resolves_to_fixed_additive_bonus() -> void:
	var cards: Dictionary = GGameDataRegistry.get_all_tarot_cards()
	if cards.is_empty():
		return
	var card: TarotCardResource = cards.values()[0]
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(card.linked_rune_id)
	assert_dict(delta).contains_key_value("additive_bonus_total", EquipmentForge.RUNE_ADDITIVE_BONUS)


func test_menagerie_rune_resolves_to_recipe_stat_delta() -> void:
	var recipes: Dictionary = GGameDataRegistry.get_all_sacrifice_recipes()
	if recipes.is_empty():
		return
	var recipe: SacrificeRecipeResource = recipes.values()[0]
	var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(recipe.rune_id)
	assert_int(delta.size()).is_equal(recipe.stat_delta.size())
	for key: StringName in recipe.stat_delta:
		assert_float(float(delta[key])).is_equal_approx(recipe.stat_delta[key], 0.0001)


func test_unknown_rune_id_returns_empty_dict() -> void:
	assert_dict(EquipmentForge.resolve_rune_stat_delta(&"no_such_rune_xyz")).is_empty()


func test_empty_rune_id_returns_empty_dict() -> void:
	assert_dict(EquipmentForge.resolve_rune_stat_delta(&"")).is_empty()


func test_resolution_agrees_with_is_rune_id_known() -> void:
	var ids: Array[StringName] = [&"no_such_rune_xyz", &""]
	for shape_id: String in Constellation.SHAPE_N:
		ids.append(StringName("rune_%s" % shape_id))
	for card: TarotCardResource in GGameDataRegistry.get_all_tarot_cards().values():
		ids.append(card.linked_rune_id)
	for recipe: SacrificeRecipeResource in GGameDataRegistry.get_all_sacrifice_recipes().values():
		ids.append(recipe.rune_id)
	for id: StringName in ids:
		var known: bool = _forge.is_rune_id_known(id)
		var resolved: bool = not EquipmentForge.resolve_rune_stat_delta(id).is_empty()
		# A known Menagerie rune may legitimately have an empty authored
		# stat_delta, so only assert the one-directional guarantee: a
		# non-empty resolution implies known.
		if resolved:
			assert_bool(known).is_true()
		if not known:
			assert_bool(resolved).is_false()
```

- [ ] **Step 2: Run to verify it fails**

Run the file via the project's gdUnit4 runner (see `tests/README.md`), target `res://tests/unit/equipment_forge/rune-stat-delta-resolution_test.gd`.
Expected: FAIL — `resolve_rune_stat_delta` not found on `EquipmentForge`.

- [ ] **Step 3: Implement**

Insert after `is_rune_id_known()`:

```gdscript
## Equipment-stats-wiring spec §3.4: resolves rune_id to the stat_delta it
## contributes, on demand — nothing is persisted, since every rune source's
## delta is a pure function of rune_id alone. Mirrors is_rune_id_known()'s
## 3-way source matching (kept as a mirrored pair, not refactored, because
## the return shapes differ). Static because EquipmentForge is not an
## autoload — Hero has no instance to call. Returns {} for an unknown
## (orphaned) rune_id, never an error.
static func resolve_rune_stat_delta(rune_id: StringName) -> Dictionary:
	if rune_id == &"":
		return {}
	var id_str: String = String(rune_id)
	for shape_id: String in Constellation.SHAPE_N:
		if id_str == "rune_%s" % shape_id:
			return {"additive_bonus_total": RUNE_ADDITIVE_BONUS}
	for card: TarotCardResource in GGameDataRegistry.get_all_tarot_cards().values():
		if String(card.linked_rune_id) == id_str:
			return {"additive_bonus_total": RUNE_ADDITIVE_BONUS}
	for recipe: SacrificeRecipeResource in GGameDataRegistry.get_all_sacrifice_recipes().values():
		if String(recipe.rune_id) == id_str:
			return recipe.stat_delta.duplicate()
	return {}
```

- [ ] **Step 4: Run test to verify it passes**

Same command. Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add src/core/equipment_forge/equipment_forge.gd tests/unit/equipment_forge/rune-stat-delta-resolution_test.gd
git commit -m "Add EquipmentForge.resolve_rune_stat_delta()

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Hero recompute + subscriptions

**Files:**
- Modify: `src/core/hero/hero.gd` — const near `PLACEHOLDER_BASE_STATS` (~line 349-363); `_ready()` (~line 613-700); `_exit_tree()` (~line 708-726); new methods after `_exit_tree()`.
- Test: `tests/unit/hero/hero_equipment_stats_test.gd`

**Interfaces:**
- Consumes: `EquipmentForge.resolve_rune_stat_delta(StringName) -> Dictionary` (Task 1); `GInventory.get_equipped_item(String) -> Dictionary` (keys `item_id`, `stat_overrides`, `imbued_runes: Array[String]`); `Inventory.EQUIPMENT_SLOT_NAMES: Array[String]`; `GGameDataRegistry.get_item_definition(StringName) -> ItemDefinitionResource`.
- Produces: `Hero._recompute_equipment_bonuses() -> void`; `static Hero._fold_stat_entry(stat: StringName, value: float, new_flat: Dictionary[StringName, float], new_additive: Dictionary[StringName, float]) -> void`; `const Hero.EQUIPMENT_FAN_OUT_STATS: Array[StringName]`.

- [ ] **Step 1: Write the failing tests**

Tests use the real `iron_sword.tres` (main_hand weapon) and `GInventory`, and always unequip in `after_test`. Base-stat contribution is tested through the pure `_fold_stat_entry` helper plus a `stat_overrides` end-to-end path (all 36 real items have empty `base_stats`).

```gdscript
extends GdUnitTestSuite

## Unit tests for Hero's equipment/rune stat wiring (equipment-stats-wiring
## spec AC-1..AC-6). Uses real GInventory and the real iron_sword.tres
## (equipment_category "weapon"); every test unequips in after_test() so the
## autoload's state never leaks.

const SWORD_PATH: String = "res://assets/data/items/iron_sword.tres"

var _hero: Hero


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)


func after_test() -> void:
	GInventory.unequip_item("main_hand")
	GInventory.unequip_item("ring_1")
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


func _equip_sword(overrides: Dictionary[StringName, float] = {}) -> void:
	var sword: ItemDefinitionResource = load(SWORD_PATH)
	assert_bool(GInventory.equip_item("main_hand", sword, overrides)).is_true()


func test_fan_out_list_matches_every_base_stat_key_exactly_once() -> void:
	var keys: Array = Hero.PLACEHOLDER_BASE_STATS.keys()
	assert_int(Hero.EQUIPMENT_FAN_OUT_STATS.size()).is_equal(keys.size())
	for key: StringName in keys:
		assert_bool(Hero.EQUIPMENT_FAN_OUT_STATS.has(key)).is_true()


func test_fold_plain_stat_goes_to_flat_bucket() -> void:
	var flat: Dictionary[StringName, float] = {}
	var add: Dictionary[StringName, float] = {}
	Hero._fold_stat_entry(&"armor", 3.0, flat, add)
	Hero._fold_stat_entry(&"armor", 2.0, flat, add)
	assert_float(flat[&"armor"]).is_equal_approx(5.0, 0.0001)
	assert_bool(add.is_empty()).is_true()


func test_fold_additive_bonus_total_fans_out_to_every_stat() -> void:
	var flat: Dictionary[StringName, float] = {}
	var add: Dictionary[StringName, float] = {}
	Hero._fold_stat_entry(&"additive_bonus_total", 0.05, flat, add)
	assert_bool(flat.is_empty()).is_true()
	assert_int(add.size()).is_equal(Hero.EQUIPMENT_FAN_OUT_STATS.size())
	for stat: StringName in Hero.EQUIPMENT_FAN_OUT_STATS:
		assert_float(add[stat]).is_equal_approx(0.05, 0.0001)


func test_equipping_item_with_override_raises_effective_stat() -> void:
	var before: float = _hero.get_effective_stat(&"armor")
	_equip_sword({&"armor": 7.0})
	assert_float(_hero.get_effective_stat(&"armor")).is_equal_approx(before + 7.0, 0.0001)


func test_unequipping_removes_contribution() -> void:
	var before: float = _hero.get_effective_stat(&"armor")
	_equip_sword({&"armor": 7.0})
	GInventory.unequip_item("main_hand")
	assert_float(_hero.get_effective_stat(&"armor")).is_equal_approx(before, 0.0001)


func test_two_items_same_stat_sum() -> void:
	var before: float = _hero.get_effective_stat(&"armor")
	_equip_sword({&"armor": 7.0})
	var ring: ItemDefinitionResource = ItemDefinitionResource.new()
	ring.item_id = &"test_ring_for_stats"
	ring.equipment_category = "ring"
	# Not in the registry -> recompute must skip it safely (null-safe path).
	assert_bool(GInventory.equip_item("ring_1", ring, {&"armor": 5.0})).is_true()
	assert_float(_hero.get_effective_stat(&"armor")).is_equal_approx(before + 7.0, 0.0001)


func test_hero_created_after_equip_picks_up_bonus_on_ready() -> void:
	_equip_sword({&"armor": 4.0})
	var late: Hero = Hero.new()
	add_child(late)
	assert_float(late.get_effective_stat(&"armor")).is_greater_equal(4.0)
	remove_child(late)
	late.free()
```

Notes for the implementer: (a) `test_two_items_same_stat_sum` intentionally documents the null-definition skip — the unregistered ring contributes nothing, so the expected total is `before + 7.0`. Rename the test to `test_item_with_unregistered_definition_is_skipped` if preferred. (b) Rune-imbue coverage (AC-3/AC-4) is done at the resolver level in Task 1 plus the fan-out test above; add an integration case only if a real imbue fixture is trivial via `GInventory.add_unique_item(sword, {}, 1)` + `apply_rune_to_item(instance_id, "rune_<shape>", {})` — if you add it, assert two different stats both rise by 5% of base.

- [ ] **Step 2: Run to verify it fails**

Run `res://tests/unit/hero/hero_equipment_stats_test.gd`. Expected: FAIL — `EQUIPMENT_FAN_OUT_STATS` / `_fold_stat_entry` not found.

- [ ] **Step 3: Implement**

Add near `PLACEHOLDER_BASE_STATS` (after its closing brace):

```gdscript
## Every real _base_stats key, used for the `additive_bonus_total` fan-out
## (equipment-stats-wiring spec §3.3). MAINTENANCE POINT: add any new Hero
## stat here too — Hero has no dynamic stat-name introspection. Enforced by
## hero_equipment_stats_test.gd against PLACEHOLDER_BASE_STATS.
const EQUIPMENT_FAN_OUT_STATS: Array[StringName] = [
	&"max_hp", &"physical_attack", &"move_speed", &"cdr", &"crit_chance",
	&"armor", &"magic_attack", &"attack_range", &"elemental_resist_fire",
	&"elemental_resist_frost", &"lifesteal", &"tower_affinity",
	&"crit_multiplier", &"luck",
]
```

In `_ready()`, after the existing `GEventBus.hero_healed.connect(...)` block (before the end of the subscription section):

```gdscript
	GEventBus.equipment_slot_changed.connect(_on_equipment_slot_changed)
	GEventBus.item_rune_imbued.connect(_on_item_rune_imbued)
	_recompute_equipment_bonuses()
```

In `_exit_tree()`, after the `hero_healed.disconnect` line:

```gdscript
	GEventBus.equipment_slot_changed.disconnect(_on_equipment_slot_changed)
	GEventBus.item_rune_imbued.disconnect(_on_item_rune_imbued)
```

Add methods after `_exit_tree()`:

```gdscript
func _on_equipment_slot_changed(_slot: String, _new_item_id: String, _previous_item_id: String) -> void:
	_recompute_equipment_bonuses()


func _on_item_rune_imbued(_item_id: String, _rune_id: String, _rune_source: String) -> void:
	_recompute_equipment_bonuses()


## Equipment-stats-wiring spec §3.2: fully re-derives _flat_bonuses/
## _additive_bonuses from GInventory's currently-equipped slots. Full
## replace, never incremental, so an unequipped item's contribution simply
## disappears. stat_overrides (the item's real roll) wins per-stat over the
## definition's base_stats template.
func _recompute_equipment_bonuses() -> void:
	var new_flat: Dictionary[StringName, float] = {}
	var new_additive: Dictionary[StringName, float] = {}
	for slot_name: String in Inventory.EQUIPMENT_SLOT_NAMES:
		var contents: Dictionary = GInventory.get_equipped_item(slot_name)
		if contents.is_empty():
			continue
		var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(contents["item_id"] as String))
		if definition == null:
			continue
		var overrides: Dictionary = contents["stat_overrides"]
		var stats: Dictionary = definition.base_stats.duplicate()
		for stat: Variant in overrides:
			stats[stat] = overrides[stat]
		for stat: Variant in stats:
			_fold_stat_entry(StringName(stat), float(stats[stat]), new_flat, new_additive)
		for rune_id: String in contents["imbued_runes"]:
			var delta: Dictionary = EquipmentForge.resolve_rune_stat_delta(StringName(rune_id))
			for stat: Variant in delta:
				_fold_stat_entry(StringName(stat), float(delta[stat]), new_flat, new_additive)
	_flat_bonuses = new_flat
	_additive_bonuses = new_additive


## Spec §3.3 key-handling rule: `additive_bonus_total` fans out into the
## additive bucket of every real stat; any other key is a flat bonus to that
## named stat. Unknown stat names are stored but never read (inert).
static func _fold_stat_entry(stat: StringName, value: float, new_flat: Dictionary[StringName, float], new_additive: Dictionary[StringName, float]) -> void:
	if stat == &"additive_bonus_total":
		for real_stat: StringName in EQUIPMENT_FAN_OUT_STATS:
			new_additive[real_stat] = new_additive.get(real_stat, 0.0) + value
	else:
		new_flat[stat] = new_flat.get(stat, 0.0) + value
```

Caveat: this replaces `_flat_bonuses` wholesale. Before implementing, `grep -n "_flat_bonuses\[\|_additive_bonuses\[" src` — if any other system (skills, tower affinity, tarot) writes into these dicts, they would be wiped by a recompute; in that case give equipment its own pair of dicts and sum them in `get_effective_stat()` instead, and note it in the commit message. (At time of writing, only tests and `get_effective_stat()` touch them.)

- [ ] **Step 4: Run tests to verify they pass**

Run `res://tests/unit/hero/hero_equipment_stats_test.gd`, then the existing `hero_stat_resolution_test.gd` and `hero_leveling_test.gd` (Hero regression). Expected: all PASS. Note `hero_stat_resolution_test.gd` writes `_flat_bonuses` directly, which is unaffected unless a recompute fires afterward.

- [ ] **Step 5: Commit**

```bash
git add src/core/hero/hero.gd tests/unit/hero/hero_equipment_stats_test.gd
git commit -m "Wire equipped items and imbued runes into Hero stat bonuses

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** §3.1 subscriptions → Task 2; §3.2 recompute → Task 2; §3.3 key rule → `_fold_stat_entry` + fan-out const/test; §3.4 resolver → Task 1; AC-1/2/6 → Task 2 tests; AC-3 → fan-out test (+ optional imbue fixture); AC-4/5/7 → Task 1 tests.
- **Placeholders:** none; the one optional imbue integration case is explicitly marked optional with its exact fixture calls.
- **Type consistency:** `resolve_rune_stat_delta`, `_recompute_equipment_bonuses`, `_fold_stat_entry`, `EQUIPMENT_FAN_OUT_STATS` used identically across tasks.
- **Flagged:** the two spec deviations above (static resolver, initial recompute in `_ready()`); the `_flat_bonuses` ownership caveat in Task 2 step 3.
