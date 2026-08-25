class_name HeroSkillAttackEvent
extends Resource

## Event-payload Resource for the hero_skill_attacked EventBus signal.
##
## ADR-0001 Rule 3: 6+ fields — requires Resource subclass payload.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
## GDD source: design/gdd/damage-status.md Rule IX / Formula D7 (added
## 2026-08-25, closes TD-hero-001's Skill Power consumer gap) and
## design/gdd/event-bus.md's event catalogue.
##
## Emitted by: Hero System (Hero.activate_skill()), one per target a skill
## cast actually struck — never a shared/batched payload across multiple
## targets (Rule IX.8). Distinct from hero_skill_activated (Hero's own
## "a skill was cast" trigger, Audio/HUD only, unconsumed by D&S) — this
## event means "this specific cast hit this specific target."
## Key subscribers: Damage & Status System (Rule IX pipeline trigger).
##
## skill_power is Hero's effective_skill_power_final (hero.md Formula 1),
## already including tower_affinity_bonus — D&S never reads tower_affinity
## directly, only this pre-resolved value (Rule IX.1).
## hero_bonus_tier values (identical semantics to HeroAutoAttackEvent):
##   0 = STANDARD, 1 = ELITE, 2 = BOSS

@export var skill_id: StringName = &""
@export var target_id: int = -1
@export var skill_power: float = 0.0
@export var skill_power_coefficient: float = 0.0
@export var is_crit: bool = false
@export var crit_multiplier_effective: float = 1.0
@export var hero_bonus_tier: int = 0  ## 0 = STANDARD, 1 = ELITE, 2 = BOSS
