class_name HeroAutoAttackEvent
extends Resource

## Event-payload Resource for the hero_auto_attacked EventBus signal.
##
## ADR-0001 Rule 3: 6 fields — requires Resource subclass payload.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
## GDD source: design/gdd/event-bus.md — Hero System event catalogue.
##
## Emitted by: Hero System (when the hero's auto-attack animation resolves).
##   Hero System rolls crit and reads target tier before emitting — all derived
##   values are pre-computed so Damage & Status needs no back-reference to Hero.
## Key subscribers: Damage & Status System (pipeline trigger).
##
## hero_bonus_tier values (GDD event-bus.md note after D&S section):
##   0 = STANDARD, 1 = ELITE, 2 = BOSS
##   Set by Hero System from the target's archetype tag at fire time.
##   Read by D&S to apply the hero damage bonus multiplier.

@export var base_damage: float = 0.0
@export var is_crit: bool = false
@export var target_id: int = -1
@export var crit_multiplier_effective: float = 1.0
@export var hero_lifesteal_fraction: float = 0.0
@export var hero_bonus_tier: int = 0  ## 0 = STANDARD, 1 = ELITE, 2 = BOSS
## Hero Combat & Stats Redesign (2026-09-18): auto-attack is always a
## physical-damage-type ability (never set to anything else at the emission
## site) -- present here (rather than hardcoded only in damage_status.gd) so
## D&S's mitigation branch reads identically for both this event and
## HeroSkillAttackEvent.
@export var damage_type: String = "physical"
## Target's MonsterResource.armor, resolved by Hero at emission time (mirrors
## TowerSystem's own is_armored-resolved-before-emit pattern). Only consulted
## when damage_type == "physical".
@export var target_armor: float = 0.0
## Target's MonsterResource.evasion [0,100], resolved by Hero at emission
## time. Rolled first, before any damage math (Section 3.5.1).
@export var target_evasion: float = 0.0
## Target's MonsterResource.elemental_resistances[damage_type], resolved by
## Hero at emission time. Always 0.0 here since auto-attack's damage_type is
## always "physical" (elemental resist never applies to physical damage) --
## present for structural symmetry with HeroSkillAttackEvent's own field.
@export var target_elemental_resist: float = 0.0
