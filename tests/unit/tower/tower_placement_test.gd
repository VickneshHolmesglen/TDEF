extends GdUnitTestSuite

## Tower placement gate tests.
## Covers: AC-1 through AC-8, AC-21.
## ADR-0008: 4-gate placement; get_placement_preview() never calls Gate 4.

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------

class _StubGrid extends RefCounted:
	var footprint_placeable: bool = true
	var place_result: int = OK
	var towers_placed: Array[int] = []
	var towers_removed: Array[int] = []

	func is_footprint_placeable(_top_left: Vector2i, _size: Vector2i) -> bool:
		return footprint_placeable

	func place_tower(tower_id: int, _top_left: Vector2i, _size: Vector2i) -> int:
		if place_result == OK:
			towers_placed.append(tower_id)
		return place_result

	func remove_tower(tower_id: int) -> void:
		towers_removed.append(tower_id)


class _StubPath extends RefCounted:
	var blocks_all: bool = false
	var was_called: bool = false

	func would_block_all_paths(_cells: Array) -> bool:
		was_called = true
		return blocks_all


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

var _ts: TowerSystem
var _grid: _StubGrid
var _path: _StubPath
var _spy: EventBusSpy

const BLUEPRINT_ID := &"test_archer"

func _make_data(cost: int = 10, footprint: Vector2i = Vector2i(1, 1)) -> TowerBlueprintData:
	var d := TowerBlueprintData.new()
	d.tower_id = BLUEPRINT_ID
	d.placement_cost = cost
	d.foundation = FoundationComponent.new()
	d.foundation.archetype = "physical"
	d.foundation.tier = 1
	d.foundation.footprint = footprint
	d.foundation.tier_dps_multiplier = 1.0
	d.foundation.tier_boss_dps_multiplier = 1.0
	d.foundation.hp_base = 100.0
	d.foundation.tier_multiplier = 1.0
	d.weapon = WeaponComponent.new()
	d.weapon.weapon_damage = 35.0
	d.weapon.attack_speed = 2.0
	d.focus = FocusComponent.new()
	d.focus.cone_half_angle = 180.0
	d.focus.attack_range_cells = 4
	d.power = PowerComponent.new()
	return d


func before_test() -> void:
	# Reset the real GMissionEconomy Autoload to a known 0 baseline before
	# seeding. TD-test-004: calls MissionEconomy's own reset handler directly
	# rather than broadcasting grid_initialized (its real reset trigger since
	# 2026-08-11 -- see mission_economy.gd) -- the broadcast cascades into
	# WaveManager/SavePersistence/Menagerie/HeroSkillBuild/Tarot's own
	# handlers too, and repeating that across many gdUnit4 test-case
	# boundaries is a confirmed orphan-leak mechanism (see
	# docs/tech-debt-register.md). This test doesn't care about the broadcast
	# mechanism itself, only MissionEconomy's own reset state.
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)
	_ts = TowerSystem.new()
	_grid = _StubGrid.new()
	_path = _StubPath.new()
	_ts._grid = _grid
	_ts._pathfinding = _path
	_ts._tower_table[BLUEPRINT_ID] = _make_data()
	_ts._current_phase = TowerSystem.Phase.INTERMISSION
	GEventBus.resources_changed.emit(100, &"test_setup")  # seeds GMissionEconomy to 100

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.tower_placed)
	_spy.watch(GEventBus.pre_placement_perk_activated)
	_spy.watch(GEventBus.resources_changed)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	_ts.free()  # TD-tower-002 fix: _ts is a Node, never added to the tree — .free() (not queue_free()) frees it immediately, closing the orphan-node gap
	_ts = null
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)  # reset GMissionEconomy for next suite (TD-test-004: direct call, not broadcast)

# ---------------------------------------------------------------------------
# AC-1: Successful placement
# ---------------------------------------------------------------------------

func test_place_tower_success_emits_tower_placed_and_marks_grid() -> void:
	var result: bool = _ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(result).is_true()
	assert_bool(_spy.was_emitted("tower_placed")).is_true()
	assert_int(_grid.towers_placed.size()).is_equal(1)
	assert_bool(_ts.placed_towers.size() > 0).is_true()


# ---------------------------------------------------------------------------
# AC-2: WAVE_ACTIVE blocks placement (Gate 1)
# ---------------------------------------------------------------------------

func test_place_tower_wave_active_returns_false_no_grid_write() -> void:
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE

	var result: bool = _ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("tower_placed")).is_false()
	assert_int(_grid.towers_placed.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-3: Insufficient resources blocks placement (Gate 2)
# ---------------------------------------------------------------------------

func test_place_tower_insufficient_gold_returns_false() -> void:
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)  # undo before_test's 100 seed, back to 0 (TD-test-004: direct call, not broadcast)
	var data: TowerBlueprintData = _make_data(30)
	_ts._tower_table[BLUEPRINT_ID] = data

	var result: bool = _ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("tower_placed")).is_false()
	assert_int(_grid.towers_placed.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-4: Cell not PLACEABLE blocks placement (Gate 3)
# ---------------------------------------------------------------------------

func test_place_tower_not_placeable_cell_returns_false() -> void:
	_grid.footprint_placeable = false

	var result: bool = _ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("tower_placed")).is_false()
	assert_int(_grid.towers_placed.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-5: Would block all paths (Gate 4)
# ---------------------------------------------------------------------------

func test_place_tower_blocks_all_paths_returns_false() -> void:
	_path.blocks_all = true

	var result: bool = _ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(result).is_false()
	assert_bool(_spy.was_emitted("tower_placed")).is_false()
	assert_int(_grid.towers_placed.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-6: SCOUT placement fires pre_placement_perk_activated (tower has a perk)
# ---------------------------------------------------------------------------

## Real bug fix regression (2026-08-13): the fixture previously never set
## pre_placement_perk, so this test was inadvertently exercising the BUG
## (unconditional emission using archetype as perk_type) rather than the
## real "has a perk" case the AC actually describes. Now sets a real perk
## and asserts the emitted perk_type matches it, not the archetype.
func test_place_tower_scout_fires_pre_placement_perk() -> void:
	_ts._current_phase = TowerSystem.Phase.SCOUT
	var data: TowerBlueprintData = _ts._tower_table[BLUEPRINT_ID] as TowerBlueprintData
	data.foundation.pre_placement_perk = "test_perk_id"

	_ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(_spy.was_emitted("pre_placement_perk_activated")).is_true()
	assert_bool(_spy.was_emitted("tower_placed")).is_true()
	var emissions: Array = _spy.emissions.get("pre_placement_perk_activated", []) as Array
	var perk_type: String = emissions[0][1] as String
	assert_str(perk_type).is_equal("test_perk_id")


## Real bug fix regression (2026-08-13): before the fix, this case was
## completely untested -- a Scout-Phase placement with NO perk configured
## incorrectly fired the event anyway (using the archetype string as a fake
## perk_type). design/gdd/tower.md Rule 12: "A Foundation component with
## pre_placement_perk = '' has no perk."
func test_place_tower_scout_with_no_perk_does_not_fire_pre_placement_perk() -> void:
	_ts._current_phase = TowerSystem.Phase.SCOUT
	# _make_data()'s default foundation.pre_placement_perk is already "" --
	# no perk configured, matching every real shipped blueprint today.

	_ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(_spy.was_emitted("tower_placed")).is_true()
	assert_bool(_spy.was_emitted("pre_placement_perk_activated")).is_false()


# ---------------------------------------------------------------------------
# AC-7: INTERMISSION placement does NOT fire pre_placement_perk_activated
# ---------------------------------------------------------------------------

func test_place_tower_intermission_does_not_fire_pre_placement_perk() -> void:
	_ts._current_phase = TowerSystem.Phase.INTERMISSION

	_ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(_spy.was_emitted("tower_placed")).is_true()
	assert_bool(_spy.was_emitted("pre_placement_perk_activated")).is_false()


# ---------------------------------------------------------------------------
# AC-8: get_placement_preview() never invokes Gate 4 (pathfinding)
# ---------------------------------------------------------------------------

func test_get_placement_preview_never_calls_gate4_pathfinding() -> void:
	_path.blocks_all = true  # If Gate 4 were called, it would return false

	var preview: PlacementPreview = _ts.get_placement_preview(BLUEPRINT_ID, Vector2i(5, 5))

	# Gate 4 must NOT have been called — preview is valid despite path blocking
	assert_bool(_path.was_called).is_false()
	assert_bool(preview.valid).is_true()


func test_get_placement_preview_wave_active_returns_wave_active_reason() -> void:
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE

	var preview: PlacementPreview = _ts.get_placement_preview(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(preview.valid).is_false()
	assert_int(preview.reason).is_equal(PlacementPreview.PlacementBlockReason.WAVE_ACTIVE)


func test_get_placement_preview_insufficient_gold_returns_resource_reason() -> void:
	GMissionEconomy._on_grid_initialized(0, 0, 0.0)  # undo before_test's 100 seed, back to 0 (TD-test-004: direct call, not broadcast)
	_ts._tower_table[BLUEPRINT_ID] = _make_data(30)

	var preview: PlacementPreview = _ts.get_placement_preview(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(preview.valid).is_false()
	assert_int(preview.reason).is_equal(
		PlacementPreview.PlacementBlockReason.INSUFFICIENT_RESOURCES
	)


func test_get_placement_preview_footprint_blocked_returns_footprint_reason() -> void:
	_grid.footprint_placeable = false

	var preview: PlacementPreview = _ts.get_placement_preview(BLUEPRINT_ID, Vector2i(5, 5))

	assert_bool(preview.valid).is_false()
	assert_int(preview.reason).is_equal(
		PlacementPreview.PlacementBlockReason.FOOTPRINT_BLOCKED
	)

# ---------------------------------------------------------------------------
# AC-21: Sell during WAVE_ACTIVE rejected
# ---------------------------------------------------------------------------

func test_sell_tower_wave_active_rejected() -> void:
	# First place a tower in INTERMISSION
	var placed: bool = _ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))
	assert_bool(placed).is_true()
	var tower_id: int = _ts.placed_towers.keys()[0] as int

	# Switch to WAVE_ACTIVE
	_ts._current_phase = TowerSystem.Phase.WAVE_ACTIVE
	var gold_before: int = GMissionEconomy.get_gold_balance()

	var result: bool = _ts.sell_tower(tower_id)

	assert_bool(result).is_false()
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(gold_before)
	assert_bool(_ts.placed_towers.has(tower_id)).is_true()


func test_sell_tower_intermission_succeeds_refunds_gold() -> void:
	# before_test() already seeded GMissionEconomy to 100.
	_ts._tower_table[BLUEPRINT_ID] = _make_data(30)
	_ts.place_tower(BLUEPRINT_ID, Vector2i(5, 5))
	var tower_id: int = _ts.placed_towers.keys()[0] as int
	var gold_after_place: int = GMissionEconomy.get_gold_balance()  # 70

	_spy.watch(GEventBus.tower_removed)
	var result: bool = _ts.sell_tower(tower_id)

	assert_bool(result).is_true()
	# Refund = round(30 * 0.4) = 12
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(gold_after_place + 12)
	assert_bool(_spy.was_emitted("tower_removed")).is_true()
	assert_bool(_ts.placed_towers.has(tower_id)).is_false()


# ---------------------------------------------------------------------------
# Error path: unknown blueprint_id — place_tower rejects, no grid write
# ---------------------------------------------------------------------------

func test_place_tower_unknown_blueprint_returns_false_no_grid_write() -> void:
	var result: bool = _ts.place_tower(&"nonexistent_blueprint", Vector2i(5, 5))

	assert_bool(result).is_false()
	assert_int(_grid.towers_placed.size()).is_equal(0)
	assert_bool(_spy.was_emitted("tower_placed")).is_false()


# ---------------------------------------------------------------------------
# Error path: unknown tower_id — sell_tower rejects
# ---------------------------------------------------------------------------

func test_sell_tower_unknown_tower_id_returns_false() -> void:
	var gold_before: int = GMissionEconomy.get_gold_balance()

	var result: bool = _ts.sell_tower(9999)

	assert_bool(result).is_false()
	assert_int(GMissionEconomy.get_gold_balance()).is_equal(gold_before)
	assert_int(_ts.placed_towers.size()).is_equal(0)


# ---------------------------------------------------------------------------
# S5-01: _ready() self-populates _tower_table from GGameDataRegistry when
# empty (closes TD-data-001). Uses its own dedicated TowerSystem instance
# (not the shared _ts fixture, which is deliberately never added to the tree
# so its manually-injected _tower_table isn't touched by _ready()) — this
# instance IS added to the tree specifically to exercise the production
# self-populate branch, matching monster_spawn_test.gd's equivalent test.
# ---------------------------------------------------------------------------

func test_ready_self_populates_tower_table_from_game_data_registry_when_empty() -> void:
	var ts := TowerSystem.new()
	add_child(ts)
	assert_bool(ts._tower_table.has(&"archer")).is_true()
	remove_child(ts)
	ts.free()
	assert_bool(_spy.was_emitted("tower_removed")).is_false()
