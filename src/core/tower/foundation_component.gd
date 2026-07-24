class_name FoundationComponent
extends Resource

## Foundation slot component (ADR-0008 Amendment 2026-07-19 — implementation
## catch-up). Schema per design/gdd/tower.md's Foundation table (lines ~50-63).
## Governs archetype/tier/HP/cost. Deep-copied per placed tower instance via
## Resource.duplicate_deep() (ADR-0008 Component Deep-Copy Policy) — mutations
## on the mission-instance copy (e.g. `damaged`) never write back to the
## inventory-owned original.

## Content-authored identifier for this specific named component asset
## (e.g. "found_basic") — distinct from the stat fields below. Added Sprint 7
## S7-implement-story-008 to satisfy build_signature's Formula 4, which
## derives from WHICH named component is equipped, not from stat values
## directly (two components with identical stats but different authored
## identities must still resolve to different signatures per that formula's
## intent).
@export var component_id: String = ""

@export var archetype: String = "physical"          # physical | ranged | elemental | support
@export var hp_base: float = 100.0                   # [80.0, 400.0]
@export var tier: int = 1                            # 1-4
@export var tier_multiplier: float = 1.0             # {1.0, 1.5, 2.0, 2.5}
@export var tier_dps_multiplier: float = 1.0         # {1.0, 1.6, 2.4, 4.0}
@export var tier_cost_factor: float = 1.0            # {1.0, 1.5, 2.0, 4.0}
@export var tier_boss_dps_multiplier: float = 1.0    # {1.0, 2.0} — T1-T3=1.0, T4=2.0
@export var footprint: Vector2i = Vector2i(1, 1)     # (1,1) or (2,2)
@export var pre_placement_perk: String = ""          # any perk id, or ""
@export var archetype_cost_factor: float = 1.0       # [0.5, 2.0]
@export var damaged: bool = false


## Validates all fields. Returns true if all fields are valid.
## Calls push_error() for each out-of-range value so the editor shows warnings.
func validate() -> bool:
	var valid: bool = true
	if hp_base < 80.0 or hp_base > 400.0:
		push_error("[FoundationComponent] hp_base %.1f outside [80.0, 400.0]" % hp_base)
		valid = false
	if tier < 1 or tier > 4:
		push_error("[FoundationComponent] tier %d outside [1, 4]" % tier)
		valid = false
	var tier_mult_ok: bool = (
		is_equal_approx(tier_multiplier, 1.0) or is_equal_approx(tier_multiplier, 1.5) or
		is_equal_approx(tier_multiplier, 2.0) or is_equal_approx(tier_multiplier, 2.5)
	)
	if not tier_mult_ok:
		push_error("[FoundationComponent] tier_multiplier %.2f not in {1.0, 1.5, 2.0, 2.5}" % tier_multiplier)
		valid = false
	var tier_dps_ok: bool = (
		is_equal_approx(tier_dps_multiplier, 1.0) or is_equal_approx(tier_dps_multiplier, 1.6) or
		is_equal_approx(tier_dps_multiplier, 2.4) or is_equal_approx(tier_dps_multiplier, 4.0)
	)
	if not tier_dps_ok:
		push_error("[FoundationComponent] tier_dps_multiplier %.2f not in {1.0, 1.6, 2.4, 4.0}" % tier_dps_multiplier)
		valid = false
	if tier == 4 and not is_equal_approx(tier_boss_dps_multiplier, 2.0):
		push_error("[FoundationComponent] T4 tier_boss_dps_multiplier must be 2.0, got %.2f" % tier_boss_dps_multiplier)
		valid = false
	elif tier != 4 and not is_equal_approx(tier_boss_dps_multiplier, 1.0):
		push_error("[FoundationComponent] T1/T2/T3 tier_boss_dps_multiplier must be 1.0, got %.2f" % tier_boss_dps_multiplier)
		valid = false
	if archetype_cost_factor < 0.5 or archetype_cost_factor > 2.0:
		push_error("[FoundationComponent] archetype_cost_factor %.2f outside [0.5, 2.0]" % archetype_cost_factor)
		valid = false
	return valid
