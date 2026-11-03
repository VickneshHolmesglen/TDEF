class_name HeroTuning
extends Resource
## Hero tuning knobs that used to be constants in hero.gd (2026-11-04): the
## per-stat caps and diminishing-curve constants applied after Formula 1
## (ADR-0010; Hero Combat & Stats Redesign 2026-09-18 Section 3.2), the
## collision radius and the auto-attack interval. Values live in
## res://assets/data/hero/hero_tuning.tres; the defaults below match it, so a
## Hero with no tuning resource still behaves the same.
##
## Usage:
##   var t := HeroTuning.load_default()
##   var capped := minf(raw_cdr, t.cdr_cap)

const DEFAULT_PATH: String = "res://assets/data/hero/hero_tuning.tres"

## Diminishing-curve hard cap for crit chance (also the cap after Luck is added).
@export_range(0.0, 1.0) var crit_chance_cap: float = 0.85
## Raw crit chance at which the curve reaches half the cap.
@export var crit_chance_scaling_constant: float = 0.5
## Hard cap on the crit multiplier BONUS (added to Hero.CRIT_MULTIPLIER_BASE).
@export var crit_multiplier_bonus_cap: float = 2.0
@export var crit_multiplier_scaling_constant: float = 1.0
@export_range(0.0, 1.0) var luck_cap: float = 0.35
@export var luck_scaling_constant: float = 0.5
## Flat caps.
@export_range(0.0, 1.0) var elemental_resist_cap: float = 0.75
@export_range(0.0, 1.0) var lifesteal_cap: float = 0.4
@export_range(0.0, 1.0) var cdr_cap: float = 0.75
## Hero hitbox radius in pixels (a quarter of a 64 px cell).
@export var collision_radius: float = 16.0
## Seconds between auto-attacks. CDR does not affect it (Rule 3).
@export var auto_attack_interval_s: float = 1.0

static var _default: HeroTuning = null


## The shared tuning from DEFAULT_PATH, loaded once. Falls back to the
## built-in defaults if the file is missing.
static func load_default() -> HeroTuning:
	if _default == null:
		_default = load(DEFAULT_PATH) as HeroTuning
		if _default == null:
			push_warning("HeroTuning: %s missing; using built-in defaults." % DEFAULT_PATH)
			_default = HeroTuning.new()
	return _default
