class_name ConstellationInstance
extends RefCounted

## Mission-scoped runtime record for one active pattern instance (ADR-0022 Key
## Interfaces). Plain RefCounted, not a Resource — mirrors ADR-0016's
## InventorySlot precedent for mission-scoped runtime state: never saved
## directly (only Constellation's Discovery Ledger persists), never
## boot-loaded, no validate() needed.

var shape_id: String = ""
var anchor_cell: Vector2i = Vector2i.ZERO
var member_cells: Array[Vector2i] = []
var member_tower_ids: Array[int] = []
var bonus_type: String = ""
var bonus_value: float = 0.0
