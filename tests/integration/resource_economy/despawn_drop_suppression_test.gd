## Integration tests for despawn drop suppression, Epic 03 Story 011, ADR-0017.
##
## Covers AC-06 (BOSS breach — monster_breached is a structurally distinct signal
## from monster_died; ResourceEconomy is never subscribed to it, so this half needs
## only a confirming test, not new logic) and AC-07 (wave_end force-clear — a REAL
## gap fixed by this story, tracked as TD-econ-002: monster_died DOES fire for
## force-clears with kill_source == "wave_end", so ResourceEconomy._process_drops()
## now checks payload.kill_source == ResourceEconomy.KILL_SOURCE_WAVE_END as the very
## first thing, before _resolve_drop_table() is even called).
##
## Follows tests/unit/resource_economy/drop_occurrence_quantity_test.gd's established
## convention: ResourceEconomy tests use add_child()-then-real-signal dispatch, with
## drop-table test data seeded directly into GGameDataRegistry._drop_tables and
## removed again in after_test() (no injection seam on ResourceEconomy itself, per
## ADR-0017's "no public call API beyond EventBus"). materials_earned emissions are
## observed via tests/helpers/event_bus_spy.gd's EventBusSpy.
extends GdUnitTestSuite

var _re: ResourceEconomy
var _spy: EventBusSpy
var _seeded_table_ids: Array[StringName] = []


func _make_guaranteed_drop_table(id: StringName) -> DropTableResource:
	var table := DropTableResource.new()
	table.drop_table_id = id
	table.base_drop_rate = 1.0  # guaranteed occurrence — data-driven determinism, not seeded RNG
	table.guaranteed_min_quantity = 1
	var entry := DropEntry.new()
	entry.material_id = &"boss_core"
	entry.base_quantity = 1
	table.entries = [entry]
	return table


func _seed_drop_table(table: DropTableResource) -> void:
	GGameDataRegistry._drop_tables[table.drop_table_id] = table
	_seeded_table_ids.append(table.drop_table_id)


func _make_died_event(drop_table_id: StringName, kill_source: String, wave_reward_scalar: float = 1.0) -> MonsterDiedEvent:
	var payload := MonsterDiedEvent.new()
	payload.entity_id = 1
	payload.monster_id = &"boss_sentinel"
	payload.tier = 2  # BOSS
	payload.drop_table_id = drop_table_id
	payload.kill_source = kill_source
	payload.wave_reward_scalar = wave_reward_scalar
	return payload


func before_test() -> void:
	_re = ResourceEconomy.new()
	add_child(_re)  # triggers _ready() — GEventBus.monster_died/monsters_died_batch subscriptions are live
	_seeded_table_ids = []
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.materials_earned)


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null

	for id: StringName in _seeded_table_ids:
		GGameDataRegistry._drop_tables.erase(id)
	_seeded_table_ids = []

	if _re != null and is_instance_valid(_re):
		remove_child(_re)
		_re.free()
	_re = null


# ---------------------------------------------------------------------------
# AC-06: BOSS breach — monster_breached is structurally distinct from
# monster_died; ResourceEconomy never subscribes to it, so no materials_earned
# should ever result, even when the BOSS's drop_table_id resolves to a
# guaranteed non-zero drop (proves the suppression isn't a lucky zero-quantity
# coincidence — the signal never reaches ResourceEconomy at all).
# ---------------------------------------------------------------------------

func test_monster_breached_signal_never_triggers_materials_earned() -> void:
	var table: DropTableResource = _make_guaranteed_drop_table(&"ac06_boss_breach")
	_seed_drop_table(table)

	GEventBus.monster_breached.emit(1, &"boss_sentinel", 2)

	assert_int(_spy.count("materials_earned")).is_equal(0)


# ---------------------------------------------------------------------------
# AC-07 core: a monster_died payload with kill_source == "wave_end" must not
# resolve any drop, even against a valid, guaranteed-drop table.
# ---------------------------------------------------------------------------

func test_wave_end_kill_source_suppresses_materials_earned() -> void:
	var table: DropTableResource = _make_guaranteed_drop_table(&"ac07_wave_end")
	_seed_drop_table(table)

	GEventBus.monster_died.emit(_make_died_event(&"ac07_wave_end", ResourceEconomy.KILL_SOURCE_WAVE_END))

	assert_int(_spy.count("materials_earned")).is_equal(0)


# ---------------------------------------------------------------------------
# AC-07 edge case: the suppression must happen BEFORE any table lookup —
# proven by pairing kill_source == "wave_end" with an UNREGISTERED
# drop_table_id and confirming Story 010's warn-once behavior (tracked via
# _unregistered_ids_seen) never fires either. If the guard were implemented
# as "resolve normally, then zero out the result," this id would still show
# up in _unregistered_ids_seen — it must not.
# ---------------------------------------------------------------------------

func test_wave_end_kill_source_suppresses_before_table_lookup_no_unregistered_warning() -> void:
	var unregistered_id: StringName = &"ac07_never_registered"

	GEventBus.monster_died.emit(_make_died_event(unregistered_id, ResourceEconomy.KILL_SOURCE_WAVE_END))

	assert_int(_spy.count("materials_earned")).is_equal(0)
	assert_bool(_re._unregistered_ids_seen.has(unregistered_id)).is_false()


# ---------------------------------------------------------------------------
# AC-07 edge case: a normal kill processed in the same batch/frame as a
# wave_end force-clear must still resolve correctly — suppression is
# per-payload, not a global mission-state flag.
# ---------------------------------------------------------------------------

func test_batch_with_normal_kill_and_wave_end_payload_resolves_only_normal_kill() -> void:
	var table: DropTableResource = _make_guaranteed_drop_table(&"ac07_batch_mixed")
	_seed_drop_table(table)

	var batch: Array[MonsterDiedEvent] = [
		_make_died_event(&"ac07_batch_mixed", "tower"),
		_make_died_event(&"ac07_batch_mixed", ResourceEconomy.KILL_SOURCE_WAVE_END),
	]
	GEventBus.monsters_died_batch.emit(batch)

	assert_int(_spy.count("materials_earned")).is_equal(1)
	var args: Array = (_spy.emissions["materials_earned"] as Array)[0]
	assert_str(args[0]).is_equal("boss_core")
	assert_int(args[1]).is_equal(1)
	assert_str(args[2]).is_equal("tower")


## TD-econ-005 (defense-in-depth): the mixed-batch test above only proves
## suppression is per-payload for a batch with ONE wave_end entry. No test
## exercised a batch of 2+ ALL-wave_end payloads — this guards against an
## off-by-one/early-exit bug that only suppresses the FIRST wave_end entry
## in a batch rather than every one of them.
func test_batch_with_multiple_wave_end_payloads_suppresses_all_of_them() -> void:
	var table: DropTableResource = _make_guaranteed_drop_table(&"ac07_batch_all_wave_end")
	_seed_drop_table(table)

	var batch: Array[MonsterDiedEvent] = [
		_make_died_event(&"ac07_batch_all_wave_end", ResourceEconomy.KILL_SOURCE_WAVE_END),
		_make_died_event(&"ac07_batch_all_wave_end", ResourceEconomy.KILL_SOURCE_WAVE_END),
		_make_died_event(&"ac07_batch_all_wave_end", ResourceEconomy.KILL_SOURCE_WAVE_END),
	]
	GEventBus.monsters_died_batch.emit(batch)

	assert_int(_spy.count("materials_earned")).is_equal(0)
