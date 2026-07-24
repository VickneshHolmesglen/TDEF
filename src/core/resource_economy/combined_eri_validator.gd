class_name CombinedEriValidator
extends RefCounted

## Story 015 (Epic 03) — Combined-ERI content-authoring validator.
##
## GDD source: design/gdd/resource-economy.md — Formula 4 ("Combined ERI Validation
## Check (design-time content-authoring constraint, not a runtime calculation)").
## Checks a DropTableResource's authored entries against the max simultaneous
## quantity/quality growth the wave-scaling system is designed to ever produce.
##
## THIS IS A CONTENT-AUTHORING GUARDRAIL, NOT A RUNTIME ASSERTION. Nothing in
## ResourceEconomy's gameplay path (_process_drops() et al.) calls this — it is a
## standalone, callable check for content-authoring tooling or a human reviewer to
## run against a DropTableResource before/at import time (CI/pipeline wiring is
## explicitly out of scope for Story 015 — see the story's Test Evidence section).
##
## Placement: deliberately a separate file/class rather than a third method on
## DropTableResource.validate() (Story 010's schema-shape contract, ADR-0009). That
## method checks structural validity (does this Resource's data conform to its own
## field constraints?); this check is a cross-wave economic-tuning guardrail that
## needs registry-sourced tuning constants (WAVE_ERI_CEILING_COMBINED,
## WAVE_REWARD_SCALAR_MAX) that have nothing to do with DropTableResource's schema
## itself. Kept as a static utility (RefCounted, no instance state) so it can be
## called directly by tooling/tests without constructing a scene node.
##
## IMPORTANT — formula correction (2026-07-14, see design/gdd/resource-economy.md
## Formula 4's own "Corrected during /design-review" note and
## design/registry/entities.yaml's WAVE_ERI_CEILING_COMBINED entry, lines 649-662):
## Story 015's own AC-14 text quotes the ORIGINAL, since-superseded formula
## ("(max quantity multiplier) x (quality_probability_ceiling / min
## base_quality_probability)") and its worked example ("base_quantity=3,
## base_quality_probability=0.05 -> 343.3 > 22.73"). That formula was found to be
## mathematically broken (it multiplied a worst-case value from one hypothetical
## entry against a worst-case value from a DIFFERENT hypothetical entry — a product
## no single kill ever actually produces) and was replaced with a **per-entry
## wave-1-to-max-wave yield-growth ratio**, evaluated using that SAME entry's own
## base_quantity/base_quality_probability at both wave points. This file implements
## the corrected (current, authoritative) formula, not the story text's stale one —
## see this file's test suite and the implementing agent's report for the full
## discrepancy writeup, including why AC-14's literal input values (base_quantity=3,
## base_quality_probability=0.05) no longer reproduce 343.3 or even fail at all
## under the corrected formula.


## Wave-scaling constants (design/gdd/wave-manager.md lines 230-237, 428): wave 1 is
## always the 1.00x baseline; 4.768x is the frozen ceiling at wave 8, r=0.25 — the
## same wave_reward_scalar range Formula 2/3 use at runtime. Duplicated here (not
## imported from WaveManager) because this is a design-time constant, not a live
## runtime read — matches this project's existing const-as-tuning-knob precedent
## (ResourceEconomy.QUALITY_PROBABILITY_CEILING, below).
const WAVE_REWARD_SCALAR_WAVE_1: float = 1.00
const WAVE_REWARD_SCALAR_MAX: float = 4.768

## Formula 4 fixes menagerie_quality_bonus=1.0 at BOTH wave points being compared
## (design/gdd/resource-economy.md: "the Menagerie term cancels out of the ratio as
## long as it's held constant across both evaluations — this check isolates
## wave-driven growth, not Menagerie's separate multiplicative bonus"). Never the
## live ResourceEconomy._menagerie_quality_bonus value — this check is intentionally
## blind to runtime Menagerie state.
const MENAGERIE_QUALITY_BONUS_NEUTRAL: float = 1.0

## Registry-sourced ceiling (design/registry/entities.yaml, "WAVE_ERI_CEILING_COMBINED",
## value: 22.73) — the Control Manifest rule for this story requires reading this
## constant from the registry rather than hardcoding it a second time; entities.yaml
## is a design-registry document, not a runtime-loadable data asset, so per this
## codebase's existing precedent for such registry constants (ResourceEconomy.
## QUALITY_PROBABILITY_CEILING, sourced the same way from the GDD's Tuning Knobs
## table) it is declared as a single named const here, citing entities.yaml as the
## source of truth. Equals wave_reward_scalar_max^2 = 4.768^2 = 22.729 (entities.yaml's
## own derivation note).
const WAVE_ERI_CEILING_COMBINED: float = 22.73

## Formula 4's own 10% rounding-tolerance allowance (design/gdd/resource-economy.md,
## Formula 4 section): quantity(wave)'s round() introduces up to ~5% deviation from
## the idealized 4.768x ratio for small integer base_quantity values (worked example:
## base_quantity=1 lands at combined_ERI=23.84, "a rounding artifact, not a real
## overshoot"). A per-entry combined_ERI is only flagged once it exceeds
## WAVE_ERI_CEILING_COMBINED * ROUNDING_TOLERANCE (22.73 * 1.10 = 25.0), not the raw
## 22.73 ceiling directly.
const ROUNDING_TOLERANCE: float = 1.10


## Runs Formula 4's combined-ERI check against every entry in `table`. Returns []
## when every entry is within tolerance; one descriptive string per entry that
## exceeds WAVE_ERI_CEILING_COMBINED * ROUNDING_TOLERANCE otherwise. Mirrors
## DropTableResource.validate()/DropEntry.validate()'s "empty array = pass" idiom
## (ADR-0009's resource_validation contract) even though this lives in a separate
## file (see class doc comment above for why).
##
## A null table is treated as nothing-to-check (returns []) — this validator's job
## is Formula 4's arithmetic, not null-safety of the caller's table reference; a
## null/malformed table itself is DropTableResource.validate()'s concern, not this
## check's. A null entry inside table.entries is skipped for the same reason
## (DropTableResource.validate() already flags null entries independently).
##
## Usage:
##   var errors: Array[String] = CombinedEriValidator.check_combined_eri(my_table)
##   if not errors.is_empty():
##       for e: String in errors:
##           push_warning(e)  # or however the content-authoring tool surfaces it
static func check_combined_eri(table: DropTableResource) -> Array[String]:
	var errors: Array[String] = []
	if table == null:
		return errors
	for i: int in range(table.entries.size()):
		var entry: DropEntry = table.entries[i]
		if entry == null:
			continue
		var combined_eri: float = _combined_eri_for_entry(entry, table.guaranteed_min_quantity)
		if _exceeds_ceiling(combined_eri):
			errors.append(
				"entries[%d] (material_id=%s): combined_ERI=%s exceeds WAVE_ERI_CEILING_COMBINED*ROUNDING_TOLERANCE=%.2f (base_quantity=%d, base_quality_probability=%.2f, guaranteed_min_quantity=%d)"
				% [
					i,
					String(entry.material_id),
					("inf" if is_inf(combined_eri) else "%.2f" % combined_eri),
					WAVE_ERI_CEILING_COMBINED * ROUNDING_TOLERANCE,
					entry.base_quantity,
					entry.base_quality_probability,
					table.guaranteed_min_quantity,
				]
			)
	return errors


## Pure per-entry Formula 4 math (design/gdd/resource-economy.md):
##   quantity(wave)    = max(guaranteed_min_quantity, round(base_quantity * wave_reward_scalar(wave) * menagerie_quality_bonus))
##   quality_roll(wave) = clamp(base_quality_probability * wave_reward_scalar(wave), 0.0, quality_probability_ceiling)
##   combined_ERI(entry) = [quantity(wave_max)/quantity(wave_1)] * [quality_roll(wave_max)/quality_roll(wave_1)]
## quality_probability_ceiling is ResourceEconomy.QUALITY_PROBABILITY_CEILING —
## referenced directly rather than redeclared, matching this codebase's existing
## precedent for cross-file constant reuse (see
## tests/unit/resource_economy/quality_roll_menagerie_scope_test.gd, which reads
## ResourceEconomy.QUALITY_PROBABILITY_CEILING directly rather than duplicating it).
##
## Returns INF when the wave-1 denominator of either ratio is zero (a degenerate
## authored value — e.g. base_quality_probability=0.0 — for which no finite growth
## ratio exists). INF always compares as exceeding the ceiling: a table author who
## sets a wave-1 quantity/quality to exactly zero cannot silently pass this check.
static func _combined_eri_for_entry(entry: DropEntry, guaranteed_min_quantity: int) -> float:
	var quantity_wave_1: int = max(
		guaranteed_min_quantity,
		int(round(entry.base_quantity * WAVE_REWARD_SCALAR_WAVE_1 * MENAGERIE_QUALITY_BONUS_NEUTRAL))
	)
	var quantity_wave_max: int = max(
		guaranteed_min_quantity,
		int(round(entry.base_quantity * WAVE_REWARD_SCALAR_MAX * MENAGERIE_QUALITY_BONUS_NEUTRAL))
	)
	var quality_wave_1: float = clamp(
		entry.base_quality_probability * WAVE_REWARD_SCALAR_WAVE_1, 0.0, ResourceEconomy.QUALITY_PROBABILITY_CEILING
	)
	var quality_wave_max: float = clamp(
		entry.base_quality_probability * WAVE_REWARD_SCALAR_MAX, 0.0, ResourceEconomy.QUALITY_PROBABILITY_CEILING
	)

	if quantity_wave_1 <= 0 or quality_wave_1 <= 0.0:
		return INF

	var quantity_ratio: float = float(quantity_wave_max) / float(quantity_wave_1)
	var quality_ratio: float = quality_wave_max / quality_wave_1
	return quantity_ratio * quality_ratio


## Threshold comparison, isolated so tests can exercise the flagging logic directly
## with a synthetic combined_ERI value (see this file's test suite — Formula 4's
## corrected math is provably bounded to a maximum of 23.84 for ANY schema-valid
## DropEntry, so a numeric-overshoot failure can never actually be produced by real
## content; this comparator is what proves the flagging branch itself is correct).
static func _exceeds_ceiling(combined_eri: float) -> bool:
	if is_nan(combined_eri):
		return true
	return combined_eri > WAVE_ERI_CEILING_COMBINED * ROUNDING_TOLERANCE
