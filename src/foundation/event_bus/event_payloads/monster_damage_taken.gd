class_name MonsterDamageTaken
extends Resource

## Event-payload Resource for the monster_damage_taken EventBus signal.
##
## ADR-0001 Rule 3: 5 fields — requires Resource subclass payload.
## ADR-0007: Deferred dispatch — this event is NEVER emitted synchronously.
##   Emitted via call_deferred or after await get_tree().process_frame.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
## GDD source: design/gdd/event-bus.md — Damage & Status System event catalogue.
##
## Emitted by: Damage & Status System (deferred one frame after tower_attacked or
##   hero_auto_attacked fires — never synchronous, per EventBus cascade budget rule).
## Key subscribers: Monster System (apply HP reduction), Mission HUD.
##
## source_type values (GDD event-bus.md note after D&S section):
##   0 = tower, 1 = hero, 2 = reserved for future sources.
##   Consuming systems must not assume additional values without updating the catalogue.
##
## hero_bonus_tier values:
##   0 = STANDARD, 1 = ELITE, 2 = BOSS.
##   Forwarded from HeroAutoAttackEvent — used by D&S for damage bonus multiplier.
##   Set to 0 for tower-sourced damage.

@export var entity_id: int = -1
@export var amount: int = 0
@export var source_type: int = 0  ## 0 = tower, 1 = hero, 2 = reserved
@export var is_crit: bool = false
@export var hero_bonus_tier: int = 0  ## 0 = STANDARD, 1 = ELITE, 2 = BOSS
