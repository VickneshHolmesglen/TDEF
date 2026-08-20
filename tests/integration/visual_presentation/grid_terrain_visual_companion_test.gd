extends GdUnitTestSuite

## Integration test for Epic 15 Story 002 (Grid/Terrain Visual Companion,
## ADR-0037).
## Story: production/epics/epic-15-3d-visual-presentation/story-002-grid-terrain-visual-companion.md
##
## Covers AC-1, AC-2, and AC-3 with real automated assertions:
##   - AC-1/AC-2: given a known small grid (5x3), GridVisual's configure()
##     builds a Node3D "VisualCompanion3D" subtree holding EXACTLY one
##     MeshInstance3D-instantiated node per grid cell, each positioned via
##     VisualMath.map_to_3d() against that cell's real 2D center position
##     (grid.gd's own cell_to_world() convention), at layer_height = 0.0.
##   - AC-3 (zero simulation changes): GridVisual's pre-existing 2D
##     configure()/queue_redraw() behavior is exercised unmodified by every
##     test in this suite (each test calls the real configure() and the 2D
##     texture build still runs) — a regression guard, not new behavior.
##
## AC-4 (live screenshot tile-layout correctness) and AC-5 (Remote Debugger
## draw-call count at MVP grid scale) are NOT automatable — both require a
## real rendered frame and a human comparing what's on screen, per the
## story's own QA Test Cases ("Manual check... Pass condition: Screenshot
## shows..."). See production/qa/evidence/grid-terrain-visual-companion-evidence.md
## for their deferred-to-manual-verification status.
##
## Uses the real GGameDataRegistry autoload (not an injected fixture) so this
## suite proves the actual shipped assets/data/visual_meshes/tile_straight.tres
## resolves through the real boot path — same "end-to-end via the live
## autoload" precedent as visual_mesh_mapping_resource_test.gd's AC-5 suite.

const GridVisualScript: Script = preload("res://src/gameplay/missions/the_gap/grid_visual.gd")

var _grid_visual: Node2D


func before_test() -> void:
	_grid_visual = Node2D.new()
	_grid_visual.set_script(GridVisualScript)
	add_child(_grid_visual)


func after_test() -> void:
	if is_instance_valid(_grid_visual):
		remove_child(_grid_visual)
		_grid_visual.free()
	_grid_visual = null


## Builds a trivial 5x3 all-PLACEABLE cell dict — this suite only cares about
## cell COUNT/POSITION for the visual-companion subtree, which is uniform
## across Grid.CellType (see grid_visual.gd's TILE_MESH_ENTITY_ID doc comment:
## one shared mesh id for every cell regardless of type).
func _build_test_cells(cols: int, rows: int) -> Dictionary:
	var cells: Dictionary = {}
	for row: int in range(rows):
		for col: int in range(cols):
			cells[Vector2i(col, row)] = 0  # PLACEABLE
	return cells


func test_configure_creates_exactly_one_mesh_instance_per_grid_cell() -> void:
	const COLS: int = 5
	const ROWS: int = 3
	const CELL_SIZE: float = 64.0
	var cells: Dictionary = _build_test_cells(COLS, ROWS)

	_grid_visual.call(&"configure", COLS, ROWS, CELL_SIZE, cells, "the_gap")

	var companion: Node3D = _grid_visual.get_node(NodePath("VisualCompanion3D")) as Node3D
	assert_object(companion).is_not_null()
	assert_int(companion.get_child_count()).is_equal(COLS * ROWS)


func test_configure_places_each_tile_at_its_map_to_3d_cell_center_position() -> void:
	const COLS: int = 5
	const ROWS: int = 3
	const CELL_SIZE: float = 64.0
	var cells: Dictionary = _build_test_cells(COLS, ROWS)

	_grid_visual.call(&"configure", COLS, ROWS, CELL_SIZE, cells, "the_gap")

	var companion: Node3D = _grid_visual.get_node(NodePath("VisualCompanion3D")) as Node3D
	var expected_positions: Dictionary = {}  # Vector3 -> true, for O(1) membership checks
	for row: int in range(ROWS):
		for col: int in range(COLS):
			var cell_center_2d := Vector2(col * CELL_SIZE + CELL_SIZE * 0.5, row * CELL_SIZE + CELL_SIZE * 0.5)
			var expected: Vector3 = VisualMath.map_to_3d(cell_center_2d, 0.0)
			expected_positions[expected] = true

	assert_int(companion.get_child_count()).is_equal(COLS * ROWS)
	for child: Node in companion.get_children():
		var tile: Node3D = child as Node3D
		assert_object(tile).is_not_null()
		assert_bool(expected_positions.has(tile.position)).is_true()
		# Every tile's Y is exactly the ground-plane layer height (ADR-0037:
		# "ground/tile = 0").
		assert_float(tile.position.y).is_equal(0.0)


## KNOWN GAP (qa-tester code-review finding, deliberately left untested):
## the explicit "fail loudly, don't silently render nothing" branch in
## _build_visual_companion() (ADR-0037's Risks section policy) has no
## dedicated test. TILE_MESH_ENTITY_ID is a `const`, not an injectable
## property, and this suite deliberately uses the real live
## GGameDataRegistry rather than a fixture registry (per this file's header
## comment) — so there is no seam to force a "missing mapping" condition for
## the real tile_straight id without either modifying source for
## testability (out of scope for this story) or corrupting real project
## data mid-test (rejected as unacceptably fragile). Flagged here rather
## than shipped as a broken test.


func test_configure_resolves_tile_mesh_via_real_visual_mesh_mapping_registry() -> void:
	const COLS: int = 2
	const ROWS: int = 1
	const CELL_SIZE: float = 64.0
	var cells: Dictionary = _build_test_cells(COLS, ROWS)

	# Guard: proves this test's positive assertions below are actually
	# exercising the real, shipped tile_straight.tres mapping — not silently
	# passing because the mapping is absent (which _build_visual_companion()
	# handles via push_error + early-return, not a crash).
	var mapping: VisualMeshMappingResource = GGameDataRegistry.get_visual_mesh_mapping(&"tile_straight")
	assert_object(mapping).is_not_null()
	assert_array(mapping.validate()).is_empty()

	_grid_visual.call(&"configure", COLS, ROWS, CELL_SIZE, cells, "the_gap")

	var companion: Node3D = _grid_visual.get_node(NodePath("VisualCompanion3D")) as Node3D
	assert_int(companion.get_child_count()).is_equal(COLS * ROWS)
	for child: Node in companion.get_children():
		assert_bool(child is Node3D).is_true()


## AC-3 regression guard: the existing 2D texture-build path (already covered
## by this project's pre-existing grid_visual coverage) still runs to
## completion — configure() does not early-return or otherwise skip its
## original 2D work now that it also builds the 3D companion subtree.
func test_configure_still_builds_the_2d_grid_texture_unchanged() -> void:
	const COLS: int = 5
	const ROWS: int = 3
	const CELL_SIZE: float = 64.0
	var cells: Dictionary = _build_test_cells(COLS, ROWS)

	_grid_visual.call(&"configure", COLS, ROWS, CELL_SIZE, cells, "the_gap")

	assert_int(_grid_visual.get(&"cols")).is_equal(COLS)
	assert_int(_grid_visual.get(&"rows")).is_equal(ROWS)
	assert_float(_grid_visual.get(&"cell_size")).is_equal(CELL_SIZE)
	assert_object(_grid_visual.get(&"_texture")).is_not_null()


func test_reconfigure_rebuilds_companion_subtree_without_duplicating_tiles() -> void:
	const CELL_SIZE: float = 64.0
	var first_cells: Dictionary = _build_test_cells(5, 3)
	var second_cells: Dictionary = _build_test_cells(2, 2)

	_grid_visual.call(&"configure", 5, 3, CELL_SIZE, first_cells, "the_gap")
	var first_companion: Node3D = _grid_visual.get_node(NodePath("VisualCompanion3D")) as Node3D
	assert_int(first_companion.get_child_count()).is_equal(15)

	_grid_visual.call(&"configure", 2, 2, CELL_SIZE, second_cells, "the_gap")
	# remove_child() detaches the previous companion synchronously (code-review
	# fix, matching mission_hud_planning_cluster_lifecycle's precedent), so the
	# child scan below would already find exactly one VisualCompanion3D without
	# this await — kept anyway as a harmless one-frame margin for the queue_free()
	# call that follows the synchronous detach to actually free the old instance.
	await get_tree().process_frame

	var companions: Array = []
	for child: Node in _grid_visual.get_children():
		if child.name == "VisualCompanion3D" and is_instance_valid(child):
			companions.append(child)
	assert_int(companions.size()).is_equal(1)
	assert_int((companions[0] as Node3D).get_child_count()).is_equal(4)
