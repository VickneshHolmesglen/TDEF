extends GdUnitTestSuite

## Unit tests for Hero's Skill System (story-007, TR-hero-005).
##
## Story: production/epics/epic-02-core-combat/story-007-hero-skill-system.md
##
## Signal-flow direction under test (corrected during dev-story review — see
## story's Context/Implementation Notes): Hero SUBSCRIBES to the real EventBus
## signal active_skill_equipped(slot_index: int, skill_id: String); it does not
## expose a public assign_skill() API. Skill activation emits
## hero_skill_activated(skill_id: String, target_position: Vector2). Both are
## String, not StringName, at emit time.
##
## ADR-0030 correction (Epic 08, Story 003, 2026-07-19): Hero previously
## independently derived its Ultimate from active_skill_equipped via a
## combo-key lookup Dictionary (_ultimate_lookup/_recompute_ultimate(),
## TD-hero-002's original MVP mechanism) and emitted ultimate_skill_changed
## itself. ADR-0030 (Hero Skill Build) forbids this: Hero Skill Build now
## owns Ultimate derivation entirely and is the sole production emitter of
## both active_skill_equipped and ultimate_skill_changed; Hero only
## SUBSCRIBES to ultimate_skill_changed and applies the value verbatim
## (_on_ultimate_skill_changed()), never re-deriving it. Tests that exercised
## the old self-derivation directly (combo-lookup key building, "no lookup
## entry" fallback, self-population from UltimateComboTable.combos) are
## removed — that ownership boundary is now covered by
## tests/integration/hero-skill-build/ultimate-recompute-ownership_test.gd.
## Tests below that need a resolved _ultimate_id now emit
## ultimate_skill_changed directly, exactly as Hero Skill Build would.
##
## Testability of the MVP-empty hardcoded consts (_SKILL_COOLDOWNS):
## this codebase's established _inject() pattern (GameDataRegistry._inject(),
## PathfindingSystem._inject(), SceneManager._inject()) is mirrored here via
## Hero._inject_skill_data(), which overrides the mutable _skill_cooldowns
## field production code reads through — the consts themselves are never
## mutated.
##
## Following this project's established real-signal-emission convention (see
## tests/integration/hero/hero_class_proximity_test.gd) rather than calling the
## private _on_active_skill_equipped() handler directly.

const SKILL_FIREBALL: StringName = &"FIREBALL"
const SKILL_FROST_NOVA: StringName = &"FROST_NOVA"
const SKILL_CHAIN_LIGHTNING: StringName = &"CHAIN_LIGHTNING"
const SKILL_EARTH_SLAM: StringName = &"EARTH_SLAM"
const SKILL_SHIELD_BASH: StringName = &"SHIELD_BASH"

const ULTIMATE_QUAD_ELEMENTAL: StringName = &"QUAD_ELEMENTAL"

var _hero: Hero
var _spy: EventBusSpy


func before_test() -> void:
	_hero = Hero.new()
	add_child(_hero)  # triggers _ready(): collision shape, timers, EventBus subscriptions
	_hero.set_process(false)  # avoid the real Input singleton overwriting _input_direction


func after_test() -> void:
	if _spy != null:
		_spy.disconnect_all()
		_spy = null
	if _hero != null and is_instance_valid(_hero):
		if _hero.is_inside_tree():
			_hero.get_parent().remove_child(_hero)
		_hero.free()
	_hero = null


## Test-only fixture: per-skill base cooldowns, for activate_skill()/CDR tests.
func _seed_skill_cooldowns() -> void:
	var cooldowns: Dictionary[StringName, float] = {
		SKILL_FIREBALL: 2.0,
		SKILL_FROST_NOVA: 3.0,
		SKILL_CHAIN_LIGHTNING: 1.0,
		SKILL_EARTH_SLAM: 4.0,
		SKILL_SHIELD_BASH: 1.5,
	}
	_hero._inject_skill_data(cooldowns)


# ---------------------------------------------------------------------------
# Rule 8: 4 active skill slots, independent of each other
# ---------------------------------------------------------------------------

func test_skill_slots_default_to_empty() -> void:
	assert_array(_hero._skill_slots).is_equal([&"", &"", &"", &""])


func test_active_skill_equipped_assigns_only_the_targeted_slot() -> void:
	GEventBus.active_skill_equipped.emit(1, String(SKILL_FROST_NOVA))

	assert_that(_hero._skill_slots[0]).is_equal(&"")
	assert_that(_hero._skill_slots[1]).is_equal(SKILL_FROST_NOVA)
	assert_that(_hero._skill_slots[2]).is_equal(&"")
	assert_that(_hero._skill_slots[3]).is_equal(&"")


func test_activate_skill_on_empty_slot_emits_nothing_and_starts_no_timer() -> void:
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_skill_activated)

	_hero.activate_skill(0)

	assert_bool(_spy.was_emitted("hero_skill_activated")).is_false()
	assert_bool(_hero._skill_cooldown_timers[0].is_stopped()).is_true()


func test_activate_skill_starts_independent_cooldown_per_slot() -> void:
	_seed_skill_cooldowns()
	_hero._base_stats[&"cdr"] = 0.0
	GEventBus.active_skill_equipped.emit(0, String(SKILL_FIREBALL))       # base 2.0s
	GEventBus.active_skill_equipped.emit(1, String(SKILL_CHAIN_LIGHTNING)) # base 1.0s

	_hero.activate_skill(0)

	assert_bool(_hero._skill_cooldown_timers[0].is_stopped()).is_false()
	assert_float(_hero._skill_cooldown_timers[0].wait_time).is_equal_approx(2.0, 0.0001)
	# Slot 1 has its own skill assigned but was never activated — its timer
	# must remain untouched by slot 0's activation.
	assert_bool(_hero._skill_cooldown_timers[1].is_stopped()).is_true()


## Regression test (code review fix): activate_skill() must reject
## reactivation while the slot's cooldown Timer is still running — otherwise
## the Timer is cosmetic and a slot can be spammed with zero rate-limiting.
func test_activate_skill_rejects_reactivation_while_on_cooldown() -> void:
	_seed_skill_cooldowns()
	_hero._base_stats[&"cdr"] = 0.0
	GEventBus.active_skill_equipped.emit(0, String(SKILL_FIREBALL))  # base 2.0s

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_skill_activated)

	_hero.activate_skill(0)
	assert_bool(_spy.was_emitted("hero_skill_activated")).is_true()
	assert_float(_hero._skill_cooldown_timers[0].wait_time).is_equal_approx(2.0, 0.0001)

	# Second activation while still on cooldown: must be a no-op — no second
	# emission, and the timer's wait_time is untouched (not restarted).
	_hero._skill_cooldown_timers[0].wait_time = 2.0
	_hero.activate_skill(0)

	assert_int(_spy.count("hero_skill_activated")).is_equal(1)


func test_activate_skill_emits_hero_skill_activated_with_id_and_position() -> void:
	_seed_skill_cooldowns()
	_hero._base_stats[&"cdr"] = 0.0
	_hero.global_position = Vector2(123.0, 456.0)
	GEventBus.active_skill_equipped.emit(2, String(SKILL_CHAIN_LIGHTNING))

	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_skill_activated)

	_hero.activate_skill(2)

	assert_bool(_spy.was_emitted("hero_skill_activated")).is_true()
	var args: Array = (_spy.emissions["hero_skill_activated"] as Array)[0] as Array
	assert_str(args[0]).is_equal(String(SKILL_CHAIN_LIGHTNING))
	assert_that(args[1]).is_equal(Vector2(123.0, 456.0))


# ---------------------------------------------------------------------------
# Rule 9 / Rule 10 / AC-12 (ADR-0030): Hero applies the Ultimate verbatim
# ---------------------------------------------------------------------------

func test_ultimate_starts_empty_with_no_slots_assigned() -> void:
	assert_that(_hero._ultimate_id).is_equal(&"")


func test_ultimate_skill_changed_sets_ultimate_id_verbatim() -> void:
	GEventBus.ultimate_skill_changed.emit(String(ULTIMATE_QUAD_ELEMENTAL))

	assert_that(_hero._ultimate_id).is_equal(ULTIMATE_QUAD_ELEMENTAL)


func test_ultimate_skill_changed_discards_active_cooldown_timer() -> void:
	GEventBus.ultimate_skill_changed.emit(String(ULTIMATE_QUAD_ELEMENTAL))
	GEventBus.hero_ultimate_activated.emit()
	# No cooldown data injected for QUAD_ELEMENTAL — activation is a no-op
	# either way; this test only proves the discard-on-receipt path directly.
	GEventBus.ultimate_skill_changed.emit(String(ULTIMATE_QUAD_ELEMENTAL))

	assert_bool(_hero._ultimate_cooldown_timer.is_stopped()).is_true()


# ---------------------------------------------------------------------------
# Rule 12: CDR formula — effective_cooldown = base x (1 - cdr), floored at 0.5s
# ---------------------------------------------------------------------------

func test_cdr_zero_yields_full_base_cooldown() -> void:
	_seed_skill_cooldowns()
	_hero._base_stats[&"cdr"] = 0.0
	GEventBus.active_skill_equipped.emit(0, String(SKILL_FIREBALL))  # base 2.0s

	_hero.activate_skill(0)

	assert_float(_hero._skill_cooldown_timers[0].wait_time).is_equal_approx(2.0, 0.0001)


func test_cdr_040_reduces_cooldown_proportionally() -> void:
	_seed_skill_cooldowns()
	_hero._base_stats[&"cdr"] = 0.40
	GEventBus.active_skill_equipped.emit(0, String(SKILL_FIREBALL))  # base 2.0s

	_hero.activate_skill(0)

	# 2.0 x (1 - 0.40) = 1.2
	assert_float(_hero._skill_cooldown_timers[0].wait_time).is_equal_approx(1.2, 0.0001)


func test_cdr_075_floors_effective_cooldown_at_half_second() -> void:
	_seed_skill_cooldowns()
	_hero._base_stats[&"cdr"] = 0.75  # CDR_CAP — 2.0 x 0.25 = 0.5, exactly the floor
	GEventBus.active_skill_equipped.emit(0, String(SKILL_FIREBALL))  # base 2.0s

	_hero.activate_skill(0)

	assert_float(_hero._skill_cooldown_timers[0].wait_time).is_equal_approx(0.5, 0.0001)


## Above the CDR_CAP (0.75) the per-stat cap (story-001) already clamps
## get_effective_stat(&"cdr") to 0.75 before Rule 12's formula ever sees it —
## this asserts the maxf(0.5, ...) floor guard independently would still hold
## even if a stat above the cap were possible (defense in depth per the
## story's own "safety redundant check" note).
func test_cdr_above_cap_still_floors_at_half_second() -> void:
	_seed_skill_cooldowns()
	_hero._base_stats[&"cdr"] = 0.95
	GEventBus.active_skill_equipped.emit(0, String(SKILL_FIREBALL))  # base 2.0s

	_hero.activate_skill(0)

	assert_float(_hero._skill_cooldown_timers[0].wait_time).is_equal_approx(0.5, 0.0001)


# ---------------------------------------------------------------------------
# TD-hero-006 (fixed 2026-09-02): self-populate from GGameDataRegistry when
# _inject_skill_data() is NOT called — proves the real SkillDefinitionResource
# catalogue (res://assets/data/skills/definitions/) actually wires through to
# Hero, not just the test-only injection seam above. Previously asserted
# against "fireball" (the legacy, now-unreferenced SkillResource catalogue) —
# switched to phys_cleave, a real catalogue skill_id, once TD-hero-006 fixed
# Hero.gd to read the correct catalogue. phys_cleave's tier is "opener"
# (base_cooldown 4.0s), which happens to match the old fireball fixture's
# expected value exactly, so the assertion numbers are unchanged.
# ---------------------------------------------------------------------------

func test_skill_cooldowns_self_populate_from_registry_when_not_injected() -> void:
	# GGameDataRegistry is the real live Autoload — already loaded the real
	# res://assets/data/skills/definitions/ content at its own boot, before
	# this test ran.
	var real_cooldown: float = _hero._skill_cooldowns.get(&"phys_cleave", -1.0)
	assert_float(real_cooldown).is_equal_approx(4.0, 0.0001)


func test_activate_skill_uses_registry_sourced_cooldown_when_not_injected() -> void:
	_hero._base_stats[&"cdr"] = 0.0
	GEventBus.active_skill_equipped.emit(0, "phys_cleave")

	_hero.activate_skill(0)

	assert_float(_hero._skill_cooldown_timers[0].wait_time).is_equal_approx(4.0, 0.0001)


# ---------------------------------------------------------------------------
# TD-hero-006 (fixed 2026-09-02): _resolve_skill_hit() payload construction
# against a real catalogue skill_id — the exact path this bug hid in, since
# no test previously exercised it against real content (only fireball/etc.
# fixtures, or nothing at all). Confirms hero_skill_attacked actually fires
# with the real skill's skill_power_coefficient now, not a silent no-op.
# ---------------------------------------------------------------------------

func test_activate_skill_emits_hero_skill_attacked_with_real_catalogue_skill() -> void:
	_hero._base_stats[&"cdr"] = 0.0
	_hero._base_stats[&"attack_range"] = 1000.0
	_hero._base_stats[&"skill_power"] = 100.0
	_hero._base_stats[&"crit_chance"] = 0.0
	_hero._monster_cache[1] = {"cell": Vector2i(0, 0), "hp": 100.0, "tier": 0, "path_step": 0}
	GEventBus.active_skill_equipped.emit(0, "phys_cleave")
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_skill_attacked)

	_hero.activate_skill(0)

	assert_bool(_spy.was_emitted("hero_skill_attacked")).is_true()
	var payload: HeroSkillAttackEvent = (_spy.emissions["hero_skill_attacked"] as Array)[0][0] as HeroSkillAttackEvent
	assert_that(payload.skill_id).is_equal(&"phys_cleave")
	assert_int(payload.target_id).is_equal(1)
	assert_float(payload.skill_power).is_equal_approx(100.0, 0.0001)
	# phys_cleave's real, authored skill_power_coefficient (assets/data/skills/
	# definitions/phys_cleave.tres) — this is the exact value that silently
	# never reached a payload at all before this fix (the old code read a
	# different, unrelated resource and returned before emitting anything).
	assert_float(payload.skill_power_coefficient).is_equal_approx(1.2, 0.0001)


func test_activate_skill_with_no_target_in_range_does_not_emit_hero_skill_attacked() -> void:
	_hero._base_stats[&"cdr"] = 0.0
	_hero._base_stats[&"attack_range"] = 1.0  # no monster seeded -- no target regardless
	GEventBus.active_skill_equipped.emit(0, "phys_cleave")
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_skill_attacked)

	_hero.activate_skill(0)

	assert_bool(_spy.was_emitted("hero_skill_attacked")).is_false()
	# Cooldown still starts even on a whiff (Rule IX's own documented behavior).
	assert_bool(_hero._skill_cooldown_timers[0].is_stopped()).is_false()


# ---------------------------------------------------------------------------
# TD-hero-003 (fixed): Ultimate activation + per-second cooldown broadcast
# ---------------------------------------------------------------------------

## Sets Hero's Ultimate the way Hero Skill Build would in production (via
## ultimate_skill_changed) to the real content's resolved value
## (elemental_cataclysm, cooldown 45.0), rather than the old self-derivation
## path — proves this end-to-end against the real GGameDataRegistry-backed
## UltimateComboTable.ultimate_cooldowns, mirroring
## test_skill_cooldowns_self_populate_from_registry_when_not_injected() above.
func _equip_real_production_ultimate() -> void:
	GEventBus.ultimate_skill_changed.emit("elemental_cataclysm")


func test_ultimate_activated_with_no_resolved_ultimate_is_noop() -> void:
	# No slots equipped -> _ultimate_id == &""
	GEventBus.hero_ultimate_activated.emit()

	assert_bool(_hero._ultimate_cooldown_timer.is_stopped()).is_true()


## Code review fix (ADR-0030 migration): Hero Skill Build's "EMPTY" sentinel
## (fewer than 4 slots filled) must be treated as a no-resolved-Ultimate
## no-op, same as the pre-migration &"" default — not passed through to the
## cooldown-lookup path, which would otherwise log a spurious "no cooldown
## data" error for a state that isn't actually a content-authoring gap.
func test_ultimate_activated_with_empty_sentinel_is_noop_no_error() -> void:
	GEventBus.ultimate_skill_changed.emit("EMPTY")

	GEventBus.hero_ultimate_activated.emit()

	assert_bool(_hero._ultimate_cooldown_timer.is_stopped()).is_true()


func test_ultimate_activated_starts_cooldown_timer_with_registry_sourced_value() -> void:
	_equip_real_production_ultimate()
	assert_that(_hero._ultimate_id).is_equal(&"elemental_cataclysm")

	GEventBus.hero_ultimate_activated.emit()

	assert_bool(_hero._ultimate_cooldown_timer.is_stopped()).is_false()
	assert_float(_hero._ultimate_cooldown_timer.wait_time).is_equal_approx(45.0, 0.0001)


func test_ultimate_activated_rejects_reactivation_while_on_cooldown() -> void:
	_equip_real_production_ultimate()
	GEventBus.hero_ultimate_activated.emit()
	_hero._ultimate_cooldown_timer.wait_time = 45.0  # simulate: not yet expired

	GEventBus.hero_ultimate_activated.emit()

	# Still the original wait_time — second activation was rejected, not restarted.
	assert_float(_hero._ultimate_cooldown_timer.wait_time).is_equal_approx(45.0, 0.0001)


## GDD Rule 10 EC: "If a skill is removed from an active slot mid-adventure...
## Any active Ultimate cooldown timer is discarded." Now driven by Hero Skill
## Build re-emitting ultimate_skill_changed on every active-slot change
## (ADR-0030/AC-11), which Hero applies via _on_ultimate_skill_changed() —
## simulated here by directly re-emitting, matching how Hero Skill Build
## would behave in production.
func test_ultimate_skill_changed_discards_active_cooldown_timer_on_receipt() -> void:
	_equip_real_production_ultimate()
	GEventBus.hero_ultimate_activated.emit()
	assert_bool(_hero._ultimate_cooldown_timer.is_stopped()).is_false()

	GEventBus.ultimate_skill_changed.emit("elemental_cataclysm")  # combo changed, re-resolved

	assert_bool(_hero._ultimate_cooldown_timer.is_stopped()).is_true()


func test_cooldown_broadcast_emits_for_skill_slot_on_cooldown() -> void:
	_seed_skill_cooldowns()
	_hero._base_stats[&"cdr"] = 0.0
	GEventBus.active_skill_equipped.emit(0, String(SKILL_FIREBALL))  # base 2.0s
	_hero.activate_skill(0)
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_skill_cooldown_updated)

	_hero._on_cooldown_broadcast_timeout()

	assert_int(_spy.count("hero_skill_cooldown_updated")).is_equal(1)
	var args: Array = (_spy.emissions["hero_skill_cooldown_updated"] as Array)[0] as Array
	assert_int(args[0]).is_equal(0)
	assert_float(args[2]).is_equal_approx(2.0, 0.0001)


func test_cooldown_broadcast_does_not_emit_for_slots_not_on_cooldown() -> void:
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_skill_cooldown_updated)

	_hero._on_cooldown_broadcast_timeout()

	assert_int(_spy.count("hero_skill_cooldown_updated")).is_equal(0)


func test_cooldown_broadcast_emits_for_ultimate_slot_index_four_on_cooldown() -> void:
	_equip_real_production_ultimate()
	GEventBus.hero_ultimate_activated.emit()
	_spy = EventBusSpy.new()
	_spy.watch(GEventBus.hero_skill_cooldown_updated)

	_hero._on_cooldown_broadcast_timeout()

	assert_int(_spy.count("hero_skill_cooldown_updated")).is_equal(1)
	var args: Array = (_spy.emissions["hero_skill_cooldown_updated"] as Array)[0] as Array
	assert_int(args[0]).is_equal(Hero.ULTIMATE_SLOT_INDEX)
	assert_float(args[2]).is_equal_approx(45.0, 0.0001)
