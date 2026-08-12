## Integration tests for Story 004 (TR-buildupgrade-004, Rule 6a):
## BuildingUpgrade's own PURCHASABLE-transition edge detection and
## GEventBus.building_upgrade_became_purchasable emission (AC-8), plus the
## structure_upgraded->Audio dispatch wiring (AC-9) and re-arm behavior
## (AC-9b).
##
## Uses the real GDefenseBuilding/GInventory/GMenagerie Autoloads (TD-test-004
## convention — reset directly in before_test()/after_test()) and a real
## BuildingUpgrade instance added to the test's own tree (get_tree() is
## needed by _requirement_satisfied()'s "tarot" branch, matching
## building_upgrade_test.gd's own established convention). Real content:
## upgrade_watchtower_reinforced (target_structure_id=watchtower_tier_1,
## requirements: building=habitat_expansion_tier_1, creature=glimmer_hare,
## tarot=iron_resolve).
extends GdUnitTestSuite

const UPGRADE_ID: StringName = &"upgrade_watchtower_reinforced"
const TARGET_STRUCTURE: StringName = &"watchtower_tier_1"
const REQUIRED_BUILDING: StringName = &"habitat_expansion_tier_1"
const REQUIRED_SPECIES: StringName = &"glimmer_hare"
const REQUIRED_TAROT_CARD: StringName = &"iron_resolve"

var _building_upgrade: BuildingUpgrade
var _tarot: Tarot
var _spy: EventBusSpy


func before_test() -> void:
	# Reset real Autoloads BEFORE BuildingUpgrade._ready() runs (TD-test-004
	# convention) -- _ready() seeds its own PURCHASABLE-edge baseline
	# (_seed_purchasable_state()) immediately, so any stale leftover state
	# from a prior test must be cleared first or the baseline could seed as
	# already-true, masking the very edge these tests assert on.
	GDefenseBuilding.reset_to_defaults()
	GInventory.reset_to_defaults()
	GMenagerie.reset_to_defaults()
	# Defensive: SceneTree (and its groups) is one global singleton for the
	# entire gdUnit4 process run, shared across every test suite -- an
	# unrelated test elsewhere that leaves a stray "building_upgrade" group
	# member alive (found empirically: reproduces only when combined with
	# tests/unit/save_persistence/save_persistence_restore_test.gd, an
	# unrelated file that creates no BuildingUpgrade itself -- root cause
	# not isolated further, flagged here rather than silently worked around)
	# would otherwise also react to this suite's own EventBus emissions and
	# double-count building_upgrade_became_purchasable. Free any such
	# stragglers before this suite's own instance is created, so these tests
	# are deterministic regardless of what ran before them in the same process.
	for stray: Node in get_tree().get_nodes_in_group(&"building_upgrade"):
		if is_instance_valid(stray):
			stray.get_parent().remove_child(stray)
			stray.free()
	_building_upgrade = BuildingUpgrade.new()
	add_child(_building_upgrade)  # _requirement_satisfied()'s "tarot" branch calls get_tree()
	_tarot = Tarot.new()
	add_child(_tarot)  # triggers _ready() -> add_to_group("tarot")
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.building_upgrade_became_purchasable)
	_spy.watch(GEventBus.structure_upgraded)
	_satisfy_building_requirement()  # target_structure_id itself -- visibility only


func after_test() -> void:
	_spy.disconnect_all()
	_spy = null
	if _building_upgrade != null and is_instance_valid(_building_upgrade):
		remove_child(_building_upgrade)
		_building_upgrade.free()
	_building_upgrade = null
	if _tarot != null and is_instance_valid(_tarot):
		remove_child(_tarot)
		_tarot.free()
	_tarot = null
	GDefenseBuilding.reset_to_defaults()
	GInventory.reset_to_defaults()
	GMenagerie.reset_to_defaults()


## Builds BOTH the upgrade's own target_structure_id (watchtower_tier_1 --
## visibility only, Rule 3) AND its "building" requirement's own target
## (habitat_expansion_tier_1 -- a DIFFERENT structure, confirmed against the
## real .tres content, same distinction Story 003's own tests had to get
## right). Called once in before_test() as this suite's shared baseline --
## every test in this file starts from "visible, building requirement
## already met" and layers creature/tarot on top.
func _satisfy_building_requirement() -> void:
	GDefenseBuilding._structure_ledger[TARGET_STRUCTURE] = true
	GDefenseBuilding._structure_ledger[REQUIRED_BUILDING] = true


func _satisfy_creature_requirement() -> void:
	var creature := CreatureInstance.new()
	creature.creature_id = 1
	creature.species = REQUIRED_SPECIES
	creature.state = CreatureInstance.CreatureState.HABITAT
	GMenagerie._creatures.append(creature)
	GEventBus.creature_acquired.emit(1, String(REQUIRED_SPECIES))


func _lose_creature_requirement() -> void:
	GMenagerie._creatures.clear()
	GEventBus.creature_sacrificed.emit(1, 999)


func _satisfy_tarot_requirement() -> void:
	_tarot._card_unlocked[REQUIRED_TAROT_CARD] = true


func _seed_material_cost() -> void:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(&"common_scrap")
	GInventory.add_stackable(definition, 12)


# ---------------------------------------------------------------------------
# AC-8: VISIBLE_LOCKED -> PURCHASABLE edge fires building_upgrade_became_purchasable
# ---------------------------------------------------------------------------

func test_last_requirement_becoming_satisfied_fires_the_event_exactly_once() -> void:
	# BuildingUpgrade._ready() (before_test above) already seeded the baseline
	# with only the "building" requirement satisfied -- still VISIBLE_LOCKED.
	# Real content note: upgrade_watchtower_reinforced's own "tarot"
	# requirement (iron_resolve) is unlocked-by-default (a Common card,
	# unlock_tech_id="" -- see tarot.md Rule 1 / the 2026-08-12 Tarot-unlock
	# wiring session), so it's already satisfied before this test even runs;
	# _satisfy_tarot_requirement() below is still called for documentation
	# completeness (proves the seam still works) but is not what triggers
	# the edge -- the creature requirement is genuinely the last unmet one.
	assert_bool(_building_upgrade.can_purchase(UPGRADE_ID)).is_false()
	_satisfy_tarot_requirement()  # redundant given the default-unlock above, but honest

	_satisfy_creature_requirement()

	assert_int(_spy.count("building_upgrade_became_purchasable")).is_equal(1)
	var args: Array = (_spy.emissions["building_upgrade_became_purchasable"] as Array)[0] as Array
	assert_str(args[0] as String).is_equal(String(UPGRADE_ID))
	assert_bool(_building_upgrade.can_purchase(UPGRADE_ID)).is_true()


func test_event_never_fires_while_already_purchasable_on_further_triggers() -> void:
	_satisfy_creature_requirement()
	assert_int(_spy.count("building_upgrade_became_purchasable")).is_equal(1)

	# An unrelated trigger fires again while already PURCHASABLE -- must not re-emit.
	GEventBus.sanctuary_structure_built.emit(String(REQUIRED_BUILDING), "habitat_expansion")

	assert_int(_spy.count("building_upgrade_became_purchasable")).is_equal(1)


func test_baseline_seed_does_not_emit_for_an_upgrade_already_purchasable_at_ready() -> void:
	# A second BuildingUpgrade instance is _ready() AFTER all 3 requirements
	# are already true -- its own boot-time seed pass must not treat that as
	# an edge (AC-8 is a transition, not "is currently true").
	_satisfy_creature_requirement()
	_satisfy_tarot_requirement()
	_spy.clear()

	var second: BuildingUpgrade = BuildingUpgrade.new()
	add_child(second)

	assert_int(_spy.count("building_upgrade_became_purchasable")).is_equal(0)
	assert_bool(second.can_purchase(UPGRADE_ID)).is_true()  # confirms it wasn't a false negative

	remove_child(second)
	second.free()


# ---------------------------------------------------------------------------
# AC-9: structure_upgraded (already the existing purchase-confirmation
# signal) is wired into Audio's generic dispatch -- verified here at the
# EventBus level (the dispatch mechanism itself), matching this story's own
# QA Test Cases framing; real audio output is evidence-doc territory.
# ---------------------------------------------------------------------------

func test_successful_purchase_fires_structure_upgraded_exactly_once() -> void:
	_satisfy_creature_requirement()
	_satisfy_tarot_requirement()
	GEventBus.creature_acquired.emit(1, String(REQUIRED_SPECIES))
	_seed_material_cost()

	var resolved: bool = _building_upgrade.resolve_upgrade(UPGRADE_ID)

	assert_bool(resolved).is_true()
	assert_int(_spy.count("structure_upgraded")).is_equal(1)


func test_rejected_second_resolve_call_does_not_double_fire_structure_upgraded() -> void:
	_satisfy_creature_requirement()
	_satisfy_tarot_requirement()
	GEventBus.creature_acquired.emit(1, String(REQUIRED_SPECIES))
	_seed_material_cost()

	assert_bool(_building_upgrade.resolve_upgrade(UPGRADE_ID)).is_true()
	assert_bool(_building_upgrade.resolve_upgrade(UPGRADE_ID)).is_false()  # already PURCHASED

	assert_int(_spy.count("structure_upgraded")).is_equal(1)


func test_audio_cue_dispatcher_is_wired_to_structure_upgraded() -> void:
	var dispatcher := AudioCueDispatcher.new()
	add_child(dispatcher)  # _ready() -> _connect_all_events(), including the new structure_upgraded wiring

	var entry := AudioCueEntry.new()
	entry.event_name = &"structure_upgraded"
	var map := AudioCueMap.new()
	map.entries = [entry]
	dispatcher.set_cue_map(map)

	GEventBus.structure_upgraded.emit(String(TARGET_STRUCTURE), String(UPGRADE_ID))

	assert_int(dispatcher.get_dispatch_count()).is_equal(1)
	assert_str(String(dispatcher.get_last_played_event())).is_equal("structure_upgraded")

	remove_child(dispatcher)
	dispatcher.free()


# ---------------------------------------------------------------------------
# AC-9b: re-armable -- fires again after reverting to VISIBLE_LOCKED and
# becoming PURCHASABLE a second time.
# ---------------------------------------------------------------------------

func test_re_locking_and_re_unlocking_fires_the_event_a_second_time() -> void:
	_satisfy_creature_requirement()
	_satisfy_tarot_requirement()
	GEventBus.creature_acquired.emit(1, String(REQUIRED_SPECIES))
	assert_int(_spy.count("building_upgrade_became_purchasable")).is_equal(1)

	# Creature requirement lost -- reverts to VISIBLE_LOCKED (Rule 4).
	_lose_creature_requirement()
	assert_bool(_building_upgrade.can_purchase(UPGRADE_ID)).is_false()

	# Creature requirement satisfied again -- PURCHASABLE a second time.
	_satisfy_creature_requirement()

	assert_int(_spy.count("building_upgrade_became_purchasable")).is_equal(2)
	var second_args: Array = (_spy.emissions["building_upgrade_became_purchasable"] as Array)[1] as Array
	assert_str(second_args[0] as String).is_equal(String(UPGRADE_ID))
