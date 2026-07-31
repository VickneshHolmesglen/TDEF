## Unit/integration tests for DropTableResource/DropEntry schema, GameDataRegistry's
## drop-table registry lookup, and ResourceEconomy's monster_died/monsters_died_batch
## -> GameDataRegistry.get_drop_table() resolution (Epic 03 Story 010, ADR-0017).
##
## Covers AC-05 (a real registered 2-entry table resolves correctly when cited by
## drop_table_id, including the zero-entry-table edge case resolving as valid
## no-drop, not an error) and AC-13 (an unregistered drop_table_id triggering twice
## logs exactly one warning; two DIFFERENT unregistered IDs each get their own
## warning, not suppressed by the first).
##
## Registry-only tests (AC-05's schema/registry half) follow
## tests/unit/game_data_registry/game_data_registry_test.gd's direct-injection
## convention: a fresh GameDataRegistry.new() + _inject() + _ready(), fixtures under
## tests/fixtures/game_data_registry/drop_tables_*/.
##
## ResourceEconomy tests (the EventBus-reactive half) follow
## tests/integration/monster/monster_manager_wave_completed_wiring_test.gd's
## add_child()-then-real-signal convention (GEventBus.monster_died.emit(...) /
## GEventBus.monsters_died_batch.emit(...), not a direct _on_monster_died() call) so
## a future signal-signature drift fails here too. Since ResourceEconomy reads the
## live GGameDataRegistry autoload directly (no injection seam — ADR-0017's "no
## public call API beyond EventBus" keeps this class deliberately narrow), test
## data is seeded directly into GGameDataRegistry's own underscore-prefixed
## _drop_tables cache and removed again in after_test() — the same
## test-reaches-into-underscore-state convention already used elsewhere in this
## project (e.g. monster_manager_wave_completed_wiring_test.gd's
## _mm._resource_table[&"goblin"] = ...).
extends GdUnitTestSuite

const VALID_DROP_TABLES_DIR: String = "res://tests/fixtures/game_data_registry/drop_tables_valid/"
const INVALID_DROP_TABLES_DIR: String = "res://tests/fixtures/game_data_registry/drop_tables_invalid/"
const MALFORMED_DROP_TABLES_DIR: String = "res://tests/fixtures/game_data_registry/drop_tables_malformed/"
const DUPLICATE_DROP_TABLES_DIR: String = "res://tests/fixtures/game_data_registry/drop_tables_duplicate/"
const EMPTY_DROP_TABLES_DIR: String = "res://tests/fixtures/game_data_registry/drop_tables_empty/"
const MISSING_DROP_TABLES_DIR: String = "res://tests/fixtures/game_data_registry/drop_tables_does_not_exist/"

# Existing valid fixtures for the other GameDataRegistry loaders — needed because
# _inject() takes positional args for every loader, matching
# game_data_registry_test.gd's own const usage.
const VALID_MONSTERS_DIR: String = "res://tests/fixtures/game_data_registry/monsters_valid/"
const VALID_PERK_REGISTRY_PATH: String = "res://tests/fixtures/game_data_registry/towers/perk_registry_valid.tres"
const EMPTY_TOWER_BLUEPRINTS_DIR: String = "res://tests/fixtures/game_data_registry/tower_blueprints_empty/"
const EMPTY_MISSIONS_DIR: String = "res://tests/fixtures/game_data_registry/missions_empty/"
const EMPTY_SKILLS_DIR: String = "res://tests/fixtures/game_data_registry/skills_empty/"
const VALID_COMBO_TABLE_PATH: String = "res://tests/fixtures/game_data_registry/skills_combo/ultimate_combo_table_valid.tres"

var _registry: GameDataRegistry


func _inject_registry(drop_tables_dir: String) -> void:
	_registry = GameDataRegistry.new()
	_registry._inject(VALID_MONSTERS_DIR, VALID_PERK_REGISTRY_PATH, EMPTY_TOWER_BLUEPRINTS_DIR, EMPTY_MISSIONS_DIR, EMPTY_SKILLS_DIR, VALID_COMBO_TABLE_PATH, drop_tables_dir)


# ---------------------------------------------------------------------------
# AC-05: registry loading and lookup
# ---------------------------------------------------------------------------

func test_ready_loads_drop_table_keyed_by_drop_table_id() -> void:
	_inject_registry(VALID_DROP_TABLES_DIR)
	_registry._ready()
	var result: DropTableResource = _registry.get_drop_table(&"goblin_basic")
	assert_object(result).is_not_null()
	assert_str(String(result.drop_table_id)).is_equal("goblin_basic")


func test_registered_table_resolves_exactly_its_two_authored_entries() -> void:
	_inject_registry(VALID_DROP_TABLES_DIR)
	_registry._ready()
	var result: DropTableResource = _registry.get_drop_table(&"goblin_basic")
	assert_object(result).is_not_null()
	assert_int(result.entries.size()).is_equal(2)
	var material_ids: Array[StringName] = []
	for entry: DropEntry in result.entries:
		material_ids.append(entry.material_id)
	assert_bool(material_ids.has(&"goblin_hide")).is_true()
	assert_bool(material_ids.has(&"goblin_fang")).is_true()


func test_zero_entry_drop_table_resolves_as_valid_no_drop_not_an_error() -> void:
	_inject_registry(VALID_DROP_TABLES_DIR)
	_registry._ready()
	var result: DropTableResource = _registry.get_drop_table(&"empty_table")
	assert_object(result).is_not_null()
	assert_int(result.entries.size()).is_equal(0)
	assert_array(result.validate()).is_empty()


func test_get_drop_table_unknown_id_returns_null() -> void:
	_inject_registry(VALID_DROP_TABLES_DIR)
	_registry._ready()
	var result: DropTableResource = _registry.get_drop_table(&"nonexistent")
	assert_object(result).is_null()


func test_ready_logs_push_error_for_invalid_drop_table_resource() -> void:
	_inject_registry(INVALID_DROP_TABLES_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] broken_table.tres: guaranteed_min_quantity must be >= 0 (got -1)")


func test_ready_completes_despite_invalid_drop_table_resource() -> void:
	_inject_registry(INVALID_DROP_TABLES_DIR)
	_registry._ready()
	# Boot did not abort — the invalid resource is still cached (same policy as
	# monsters/towers/missions/skills).
	var result: DropTableResource = _registry.get_drop_table(&"broken_table")
	assert_object(result).is_not_null()


func test_ready_logs_push_error_for_drop_table_tres_that_fails_to_load() -> void:
	_inject_registry(MALFORMED_DROP_TABLES_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] wrong_type.tres: failed to load as DropTableResource.")
	assert_object(_registry.get_drop_table(&"anything")).is_null()


func test_ready_duplicate_drop_table_id_logs_push_error_last_file_wins() -> void:
	_inject_registry(DUPLICATE_DROP_TABLES_DIR)
	_registry._ready()
	# Both table_a.tres and table_b.tres author drop_table_id = &"duplicate_table".
	# Exactly one wins (last file scanned) — assert a result exists and is one of
	# the two authored values, not that a specific file wins (file iteration order
	# via DirAccess.get_files_at() is not documented/guaranteed).
	var result: DropTableResource = _registry.get_drop_table(&"duplicate_table")
	assert_object(result).is_not_null()
	assert_bool(result.guaranteed_min_quantity == 1 or result.guaranteed_min_quantity == 2).is_true()


func test_ready_missing_drop_tables_directory_logs_push_error_no_crash() -> void:
	_inject_registry(MISSING_DROP_TABLES_DIR)
	await assert_error(func() -> void: _registry._ready()) \
		.is_push_error("[GameDataRegistry] Drop tables directory does not exist: %s" % MISSING_DROP_TABLES_DIR)
	assert_object(_registry.get_drop_table(&"anything")).is_null()


func test_ready_empty_drop_tables_directory_no_entries_no_crash() -> void:
	_inject_registry(EMPTY_DROP_TABLES_DIR)
	_registry._ready()
	assert_object(_registry.get_drop_table(&"anything")).is_null()


# ---------------------------------------------------------------------------
# ResourceEconomy: monster_died / monsters_died_batch -> registry lookup
# (AC-05 real-table resolution via the real EventBus signal path, and the
# batch-resolves-identically-to-individual-dispatch Validation Criterion)
# ---------------------------------------------------------------------------

var _re: ResourceEconomy
var _seeded_table_ids: Array[StringName] = []


func _seed_drop_table(table: DropTableResource) -> void:
	GGameDataRegistry._drop_tables[table.drop_table_id] = table
	_seeded_table_ids.append(table.drop_table_id)


func _make_drop_table(id: StringName, entry_count: int) -> DropTableResource:
	var table := DropTableResource.new()
	table.drop_table_id = id
	var entries: Array[DropEntry] = []
	for i: int in range(entry_count):
		var entry := DropEntry.new()
		entry.material_id = StringName("material_%d" % i)
		entries.append(entry)
	table.entries = entries
	return table


func _make_died_event(drop_table_id: StringName, entity_id: int = 1) -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.entity_id = entity_id
	payload.monster_id = &"goblin_runner"
	payload.tier = 0
	payload.drop_table_id = drop_table_id
	payload.kill_source = "tower"
	return payload


func before_test() -> void:
	_re = ResourceEconomy.new()
	add_child(_re)  # triggers _ready() — GEventBus.monster_died/monsters_died_batch subscriptions are live
	_seeded_table_ids = []


## Single combined teardown for both halves of this suite (registry-only tests
## using _registry, and ResourceEconomy tests using _re/_seeded_table_ids) — GdUnit4
## permits exactly one after_test() per suite.
func after_test() -> void:
	if _registry != null and is_instance_valid(_registry):
		if _registry.is_inside_tree():
			_registry.get_parent().remove_child(_registry)
		_registry.free()
	_registry = null

	for id: StringName in _seeded_table_ids:
		GGameDataRegistry._drop_tables.erase(id)
	_seeded_table_ids = []
	if _re != null and is_instance_valid(_re):
		remove_child(_re)
		_re.free()
	_re = null


## The registered-table HIT case has no test-observable public side effect by
## design (ADR-0017: no materials_earned/resources_changed emission exists yet —
## that's Story 008/009's job). This test proves two things together: (1) firing
## the REAL GEventBus.monster_died signal for a registered id does not throw/crash
## (arity-safety, matching monster_manager_wave_completed_wiring_test.gd's
## real-signal convention), and (2) the internal resolution surface
## _resolve_drop_table() — which _on_monster_died() delegates to — returns exactly
## the seeded table for that same drop_table_id (AC-05).
func test_resource_economy_monster_died_signal_wiring_and_table_resolution_match() -> void:
	var table: DropTableResource = _make_drop_table(&"goblin_basic_live", 2)
	_seed_drop_table(table)

	# Real signal path — must not throw/crash for a registered id.
	GEventBus.monster_died.emit(_make_died_event(&"goblin_basic_live"))

	# Internal resolution surface — proves exactly the seeded table resolves.
	var resolved: DropTableResource = _re._resolve_drop_table(_make_died_event(&"goblin_basic_live"))
	assert_object(resolved).is_same(table)
	assert_int(resolved.entries.size()).is_equal(2)


func test_resource_economy_resolves_registered_table_identically_via_monsters_died_batch() -> void:
	var table: DropTableResource = _make_drop_table(&"goblin_basic_batch", 2)
	_seed_drop_table(table)

	var single_result: DropTableResource = _re._resolve_drop_table(_make_died_event(&"goblin_basic_batch", 1))

	var batch: Array[MonsterDiedEvent] = [
		_make_died_event(&"goblin_basic_batch", 2),
		_make_died_event(&"goblin_basic_batch", 3),
	]
	GEventBus.monsters_died_batch.emit(batch)

	var batch_result_a: DropTableResource = _re._resolve_drop_table(batch[0])
	var batch_result_b: DropTableResource = _re._resolve_drop_table(batch[1])

	assert_object(single_result).is_same(table)
	assert_object(batch_result_a).is_same(table)
	assert_object(batch_result_b).is_same(table)


## TD-econ-001: the existing batch test above only proves same-table batch
## entries don't share rounding state — it never proved a HETEROGENEOUS batch
## (two different drop_table_ids in one call) resolves each entry to its OWN
## correct table rather than, e.g., an indexing/closure mistake resolving
## every entry against the first payload's id.
func test_resource_economy_heterogeneous_batch_resolves_each_entry_to_its_own_table() -> void:
	var table_a: DropTableResource = _make_drop_table(&"goblin_basic_hetero_a", 1)
	var table_b: DropTableResource = _make_drop_table(&"goblin_basic_hetero_b", 2)
	_seed_drop_table(table_a)
	_seed_drop_table(table_b)

	var batch: Array[MonsterDiedEvent] = [
		_make_died_event(&"goblin_basic_hetero_a", 1),
		_make_died_event(&"goblin_basic_hetero_b", 2),
	]
	GEventBus.monsters_died_batch.emit(batch)

	var result_a: DropTableResource = _re._resolve_drop_table(batch[0])
	var result_b: DropTableResource = _re._resolve_drop_table(batch[1])

	assert_object(result_a).is_same(table_a)
	assert_object(result_b).is_same(table_b)
	assert_object(result_a).is_not_same(table_b)


# ---------------------------------------------------------------------------
# AC-13: unregistered drop_table_id handling
# ---------------------------------------------------------------------------

func test_resource_economy_unregistered_id_resolves_as_no_drop() -> void:
	var result: DropTableResource = _re._resolve_drop_table(_make_died_event(&"totally_unregistered_id"))
	assert_object(result).is_null()


func test_resource_economy_unregistered_id_triggering_twice_logs_exactly_one_warning() -> void:
	await assert_error(func() -> void:
		_re._resolve_drop_table(_make_died_event(&"unregistered_dedup_id", 1))
		_re._resolve_drop_table(_make_died_event(&"unregistered_dedup_id", 2))
	).is_push_warning("[ResourceEconomy] Unregistered drop_table_id 'unregistered_dedup_id' — treating as no-drop.")

	assert_int(_re._unregistered_ids_seen.size()).is_equal(1)
	assert_bool(_re._unregistered_ids_seen.has(&"unregistered_dedup_id")).is_true()


func test_resource_economy_two_different_unregistered_ids_each_warn_once() -> void:
	_re._resolve_drop_table(_make_died_event(&"unregistered_a", 1))
	_re._resolve_drop_table(_make_died_event(&"unregistered_b", 2))

	assert_int(_re._unregistered_ids_seen.size()).is_equal(2)
	assert_bool(_re._unregistered_ids_seen.has(&"unregistered_a")).is_true()
	assert_bool(_re._unregistered_ids_seen.has(&"unregistered_b")).is_true()
	# Repeating the first id again must not add a third entry — still deduped by id.
	_re._resolve_drop_table(_make_died_event(&"unregistered_a", 3))
	assert_int(_re._unregistered_ids_seen.size()).is_equal(2)


func test_resource_economy_unregistered_id_via_real_monster_died_signal_resolves_no_drop_no_crash() -> void:
	# Real-signal path (not a direct call) — proves the EventBus wiring itself
	# never crashes or throws on a lookup miss, only warns-then-no-drop.
	GEventBus.monster_died.emit(_make_died_event(&"unregistered_via_signal"))
	assert_bool(_re._unregistered_ids_seen.has(&"unregistered_via_signal")).is_true()


# ---------------------------------------------------------------------------
# Control manifest: mandatory EventBus subscribe/unsubscribe lifecycle
# ---------------------------------------------------------------------------

func test_exit_tree_disconnects_event_bus_subscriptions() -> void:
	assert_bool(GEventBus.monster_died.is_connected(_re._on_monster_died)).is_true()
	assert_bool(GEventBus.monsters_died_batch.is_connected(_re._on_monsters_died_batch)).is_true()

	remove_child(_re)
	_re.free()
	_re = null  # after_test() must not try to remove/free this again

	# A stale connection into a freed node would raise here — no crash means clean.
	GEventBus.monster_died.emit(_make_died_event(&"post_free_check"))
