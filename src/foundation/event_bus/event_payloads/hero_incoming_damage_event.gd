class_name HeroIncomingDamageEvent
extends Resource

## Event-payload Resource for the hero_incoming_damage EventBus signal
## (hero-damage spec §4.3). Deliberately a Resource even though it has four fields
## (ADR-0001 Rule 3 only requires it at 5+): new fields can be added later without
## changing the signal signature again.
## ADR-0009: Event-payload Resources are short-lived; never saved as .tres files.
##
## Emitted by: Monster System, when an ELITE/BOSS wind-up completes with the Hero
## still in range. Key subscribers: Damage & Status (mitigation, then hero_damage_taken).

## Raw damage BEFORE mitigation.
@export var amount: float = 0.0

## "physical" (armor), "fire" / "frost" (elemental resist), anything else is unmitigated.
@export var damage_type: String = "physical"

## 0 = monster attack. 1 = status effect and 2 = environmental are reserved.
@export var source_type: int = 0

## The attacking monster's entity id, or -1 when not applicable.
@export var source_entity_id: int = -1
