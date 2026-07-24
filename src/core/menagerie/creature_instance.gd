class_name CreatureInstance
extends RefCounted

## Runtime creature entity (Story 007, ADR-0026). Plain RefCounted, never a
## Resource — mirrors InventorySlot's precedent (ADR-0016) for flat-primitive
## playthrough-scoped runtime entities.

enum CreatureState { RESERVE, HABITAT, BREEDING_PEN, SACRIFICED }

var creature_id: int = -1
var species: StringName = &""
var state: CreatureState = CreatureState.RESERVE
var happiness: float = 70.0
var missions_since_tended: int = 0
