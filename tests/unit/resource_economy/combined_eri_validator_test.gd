## Unit tests for CombinedEriValidator (Epic 03 Story 015 — Combined-ERI
## content-authoring validator), covering GDD Formula 4
## (design/gdd/resource-economy.md).
##
## IMPORTANT — this suite deliberately does NOT reproduce Story 015's AC-14 as
## literally written. AC-14 quotes Formula 4's ORIGINAL formula and worked example
## ("base_quantity=3, base_quality_probability=0.05 -> 343.3 > 22.73"), which the
## GDD itself records as corrected on 2026-07-14 (see design/gdd/resource-economy.md
## Formula 4's "Corrected during /design-review" note, and
## design/registry/entities.yaml's WAVE_ERI_CEILING_COMBINED entry) — the original
## formula multiplied a worst-case quantity value from one hypothetical entry
## against a worst-case quality-ratio value from a DIFFERENT hypothetical entry, a
## product no single kill ever actually produces. The corrected formula is a
## per-entry wave-1-to-max-wave yield-growth ratio, implemented in
## combined_eri_validator.gd. Under the corrected formula, AC-14's own literal input
## values (base_quantity=3, base_quality_probability=0.05) compute to ~22.25 and DO
## NOT fail. This suite tests the corrected, current formula and documents that
## divergence directly (test_check_combined_eri_ac14_literal_inputs... below) rather
## than silently forcing a match to the stale 343.3 figure.
##
## A second, load-bearing finding from implementing this suite: the corrected
## formula is mathematically bounded to a maximum of 23.84 for ANY schema-valid
## DropEntry (base_quantity >= 1 int, base_quality_probability in [0.05, 0.15] per
## Formula 3's authored range, guaranteed_min_quantity <= base_quantity) — see
## test_check_combined_eri_property_no_schema_valid_entry_in_formula_3_range_ever_fails
## below, and combined_eri_validator.gd's class doc comment. The one genuinely
## reachable failure case for real (if degenerate) authored content is
## base_quality_probability=0.0, which zeroes Formula 4's wave-1 denominator — that
## is this suite's actual AC-14-equivalent "flags a failure" case.
extends GdUnitTestSuite


func _make_table(base_quantity: int, base_quality_probability: float, guaranteed_min_quantity: int = 1, material_id: StringName = &"test_material") -> DropTableResource:
	var table := DropTableResource.new()
	table.drop_table_id = &"combined_eri_test_table"
	table.guaranteed_min_quantity = guaranteed_min_quantity
	var entry := DropEntry.new()
	entry.material_id = material_id
	entry.base_quantity = base_quantity
	entry.base_quality_probability = base_quality_probability
	table.entries = [entry]
	return table


# ---------------------------------------------------------------------------
# AC-14 divergence: story's literal input values, under the CORRECTED formula
# ---------------------------------------------------------------------------

func test_check_combined_eri_ac14_literal_inputs_pass_not_fail_under_corrected_formula() -> void:
	# base_quantity=3, base_quality_probability=0.05 — the exact values AC-14 (as
	# literally written) claims produce a 343.3 > 22.73 failure. Under the
	# corrected Formula 4 these pass cleanly (~22.25, comfortably under both the
	# raw 22.73 ceiling and the 25.0-ish tolerance-adjusted one).
	var table: DropTableResource = _make_table(3, 0.05)

	var errors: Array[String] = CombinedEriValidator.check_combined_eri(table)

	assert_array(errors).is_empty()


func test_combined_eri_for_entry_ac14_literal_inputs_computes_22_25_not_343_3() -> void:
	var table: DropTableResource = _make_table(3, 0.05)
	var entry: DropEntry = table.entries[0]

	var combined_eri: float = CombinedEriValidator._combined_eri_for_entry(entry, table.guaranteed_min_quantity)

	# quantity(wave_1) = max(1, round(3*1.00)) = 3
	# quantity(wave_max) = max(1, round(3*4.768)) = round(14.304) = 14
	# quality(wave_1) = clamp(0.05*1.00, 0, 0.80) = 0.05
	# quality(wave_max) = clamp(0.05*4.768, 0, 0.80) = 0.2384
	# combined_ERI = (14/3) * (0.2384/0.05) = 4.6667 * 4.768 = 22.2507
	assert_float(combined_eri).is_equal_approx(22.2507, 0.01)
	assert_float(combined_eri).is_less(343.3)


# ---------------------------------------------------------------------------
# GDD's own currently-cited worked example (the corrected formula's "previously-
# flagged failing case, now within tolerance")
# ---------------------------------------------------------------------------

func test_check_combined_eri_gdd_worked_example_base_quantity_one_passes_within_tolerance() -> void:
	# base_quantity=1, base_quality_probability=0.15 (top of Formula 3's range) —
	# GDD's own worked example, landing at 23.84: over the raw 22.73 ceiling but
	# within the 10% ROUNDING_TOLERANCE-adjusted ceiling (~25.0), so it must pass.
	var table: DropTableResource = _make_table(1, 0.15)

	var errors: Array[String] = CombinedEriValidator.check_combined_eri(table)
	var combined_eri: float = CombinedEriValidator._combined_eri_for_entry(table.entries[0], table.guaranteed_min_quantity)

	assert_float(combined_eri).is_equal_approx(23.84, 0.01)
	assert_array(errors).is_empty()


# ---------------------------------------------------------------------------
# QA Test Cases' explicit "passing case" edge — reasonable content under the ceiling
# ---------------------------------------------------------------------------

func test_check_combined_eri_passing_case_moderate_values_stays_under_ceiling() -> void:
	# base_quantity=5, base_quality_probability=0.10 — mid-range Formula 3 values,
	# not a worst-case rounding edge (base_quantity > 2). Combined_ERI ~22.89.
	var table: DropTableResource = _make_table(5, 0.10)

	var errors: Array[String] = CombinedEriValidator.check_combined_eri(table)

	assert_array(errors).is_empty()


func test_check_combined_eri_property_no_schema_valid_entry_in_formula_3_range_ever_fails() -> void:
	# Property check backing this suite's header note: across base_quantity 1..20
	# and Formula 3's full authored base_quality_probability range (0.05-0.15,
	# swept in 0.01 steps), the corrected Formula 4 never flags a failure — this is
	# what the GDD means by "the check therefore always passes for content
	# authored within Formula 3's stated ranges."
	var any_flagged: bool = false
	for base_quantity: int in range(1, 21):
		var bqp: float = 0.05
		while bqp <= 0.15 + 0.0001:
			var table: DropTableResource = _make_table(base_quantity, bqp)
			var errors: Array[String] = CombinedEriValidator.check_combined_eri(table)
			if not errors.is_empty():
				any_flagged = true
			bqp += 0.01

	assert_bool(any_flagged).is_false()


# ---------------------------------------------------------------------------
# AC-14's actual reachable "flags a failure" case under the corrected formula:
# a degenerate authored value (base_quality_probability=0.0) that zeroes Formula
# 4's wave-1 denominator, producing an undefined growth ratio.
# ---------------------------------------------------------------------------

func test_check_combined_eri_zero_base_quality_probability_flags_as_degenerate_failure() -> void:
	var table: DropTableResource = _make_table(3, 0.0, 1, &"broken_material")

	var errors: Array[String] = CombinedEriValidator.check_combined_eri(table)

	assert_array(errors).has_size(1)
	assert_str(errors[0]).contains("broken_material")
	assert_str(errors[0]).contains("combined_ERI=inf")


func test_combined_eri_for_entry_zero_base_quality_probability_returns_inf() -> void:
	var table: DropTableResource = _make_table(3, 0.0)

	var combined_eri: float = CombinedEriValidator._combined_eri_for_entry(table.entries[0], table.guaranteed_min_quantity)

	assert_bool(is_inf(combined_eri)).is_true()


# ---------------------------------------------------------------------------
# Direct comparator coverage — proves the flagging/threshold logic itself is
# correct, independent of whether real schema-valid content can ever reach it
# (see suite header note: it provably cannot, for values >23.84).
# ---------------------------------------------------------------------------

func test_exceeds_ceiling_flags_synthetic_overshoot_value() -> void:
	assert_bool(CombinedEriValidator._exceeds_ceiling(30.0)).is_true()


func test_exceeds_ceiling_does_not_flag_value_comfortably_under_ceiling() -> void:
	assert_bool(CombinedEriValidator._exceeds_ceiling(20.0)).is_false()


func test_exceeds_ceiling_boundary_at_tolerance_adjusted_ceiling() -> void:
	var tolerance_ceiling: float = CombinedEriValidator.WAVE_ERI_CEILING_COMBINED * CombinedEriValidator.ROUNDING_TOLERANCE
	assert_bool(CombinedEriValidator._exceeds_ceiling(tolerance_ceiling)).is_false()
	assert_bool(CombinedEriValidator._exceeds_ceiling(tolerance_ceiling + 0.01)).is_true()


func test_exceeds_ceiling_flags_nan() -> void:
	assert_bool(CombinedEriValidator._exceeds_ceiling(NAN)).is_true()


# ---------------------------------------------------------------------------
# Guardrail edge cases: null table / null entries should not crash the check.
# ---------------------------------------------------------------------------

func test_check_combined_eri_null_table_returns_empty_errors() -> void:
	var errors: Array[String] = CombinedEriValidator.check_combined_eri(null)

	assert_array(errors).is_empty()


func test_check_combined_eri_skips_null_entries_without_crashing() -> void:
	var table := DropTableResource.new()
	table.drop_table_id = &"has_null_entry"
	table.guaranteed_min_quantity = 1
	table.entries = [null]

	var errors: Array[String] = CombinedEriValidator.check_combined_eri(table)

	assert_array(errors).is_empty()


# ---------------------------------------------------------------------------
# Per-entry failure isolation: a multi-entry table where only ONE entry is
# degenerate must flag only that entry, at the correct array index, leaving
# the other entries unaffected — proves the check() loop doesn't leak state
# or misattribute a failure across entries.
# ---------------------------------------------------------------------------

func test_check_combined_eri_multi_entry_table_flags_only_the_degenerate_entry_at_correct_index() -> void:
	var table := DropTableResource.new()
	table.drop_table_id = &"multi_entry_table"
	table.guaranteed_min_quantity = 1

	var healthy_entry := DropEntry.new()
	healthy_entry.material_id = &"healthy_material"
	healthy_entry.base_quantity = 3
	healthy_entry.base_quality_probability = 0.05

	var degenerate_entry := DropEntry.new()
	degenerate_entry.material_id = &"degenerate_material"
	degenerate_entry.base_quantity = 3
	degenerate_entry.base_quality_probability = 0.0

	table.entries = [healthy_entry, degenerate_entry]

	var errors: Array[String] = CombinedEriValidator.check_combined_eri(table)

	assert_array(errors).has_size(1)
	assert_str(errors[0]).starts_with("entries[1]")
	assert_str(errors[0]).contains("degenerate_material")
	assert_str(errors[0]).not_contains("healthy_material")


# ---------------------------------------------------------------------------
# guaranteed_min_quantity distortion: the GDD's own Open Questions/comments
# name a "mis-set guaranteed_min_quantity that distorts the quantity ratio"
# as the realistic authoring mistake this check exists to catch. Verified
# here: setting guaranteed_min_quantity well above base_quantity forces
# quantity(wave_1) == quantity(wave_max) (both floored to the same value),
# collapsing the quantity ratio toward 1.0 — which only LOWERS combined_ERI
# further below the ceiling. This distortion cannot produce a failure under
# the corrected formula either; documents (does not silently hide) the same
# near-zero-practical-reach finding the property-sweep test establishes for
# ordinary content.
# ---------------------------------------------------------------------------

func test_check_combined_eri_distorted_guaranteed_min_quantity_does_not_fail_but_collapses_ratio() -> void:
	var table: DropTableResource = _make_table(1, 0.15, 5)  # guaranteed_min_quantity=5 >> base_quantity=1

	var errors: Array[String] = CombinedEriValidator.check_combined_eri(table)
	var combined_eri: float = CombinedEriValidator._combined_eri_for_entry(table.entries[0], table.guaranteed_min_quantity)

	# quantity(wave_1) = max(5, round(1*1.00)) = 5; quantity(wave_max) = max(5, round(1*4.768)) = max(5,5) = 5
	# quantity_ratio collapses to 5/5 = 1.0, well below the un-floored 4.768 — combined_ERI drops
	# to just the quality ratio (0.7152/0.15 = 4.768), far under the ceiling.
	assert_float(combined_eri).is_equal_approx(4.768, 0.01)
	assert_array(errors).is_empty()
