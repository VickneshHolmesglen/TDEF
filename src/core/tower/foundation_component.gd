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
## Perk magnitude (tower.md Rule 12a). Ignored when pre_placement_perk == "".
## Per-type valid range: DAMAGE_BOOST/SPEED_BOOST [0.05, 0.25]; RANGE_BOOST
## [0.0625, 0.25]; AURA_EXTEND [0.10, 0.25] -- the two non-0.05 floors exist
## to guarantee at least 1 cell of benefit (round(perk_power * 8)/round(perk_power
## * 6) would otherwise silently yield 0 cells below that floor -- a "dead
## zone" this range exists to eliminate, not an arbitrary number).
@export var perk_power: float = 0.0
@export var archetype_cost_factor: float = 1.0       # [0.5, 2.0]
## Tower Stats System Phase 1 (player-requested 2026-08-16): StringName tag
## (matching MonsterResource.archetype_tag, e.g. &"armored") -> float damage
## multiplier, e.g. {&"armored": 1.3} for +30% damage vs armored monsters.
## Missing key = 1.0 (no bonus) — fully backward-compatible, no migration
## needed for existing content. Stacks multiplicatively alongside (does NOT
## replace) tier_boss_dps_multiplier above, which stays the dedicated T4-vs-
## BOSS mechanic with its own hard-validated {1.0, 2.0} gate — this field is
## an independent, additional, freely-authored bonus layer, generalizing the
## SAME shape of bonus to any tag without touching that tested formula.
## Deliberately a Dictionary, not a single scalar field, so a future tag-
## keyed mechanic (e.g. a not-yet-designed "Affinity" system) could
## contribute more entries later without a schema migration — this reserves
## the extension room without committing to or designing that mechanic here.
@export var bonus_damage_vs_tags: Dictionary = {}
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
	if pre_placement_perk != "":
		var floor_value: float = 0.05
		if pre_placement_perk == "RANGE_BOOST":
			floor_value = 0.0625
		elif pre_placement_perk == "AURA_EXTEND":
			floor_value = 0.10
		if perk_power < floor_value or perk_power > 0.25:
			push_error("[FoundationComponent] perk_power %.4f outside [%.4f, 0.25] for pre_placement_perk '%s'" % [perk_power, floor_value, pre_placement_perk])
			valid = false
	for tag: Variant in bonus_damage_vs_tags:
		var multiplier: float = bonus_damage_vs_tags[tag] as float
		if multiplier <= 0.0:
			push_error("[FoundationComponent] bonus_damage_vs_tags[%s] must be > 0.0, got %.2f" % [tag, multiplier])
			valid = false
	return valid
