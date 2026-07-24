class_name InventorySlot
extends RefCounted

## Runtime item stack held by one Inventory slot (Epic 03, ADR-0016).
##
## ADR: docs/architecture/adr-0016-inventory-storage-model.md — "Two-tier data model"
## Story: production/epics/epic-03-core-economy/story-001-slot-stack-model.md
##
## Deliberately NOT a Resource (see ADR-0016 "Alternative C: Full Resource
## runtime" for the rejected alternative and why) — this keeps
## Inventory.get_save_data() trivially primitive-only by construction, since
## an InventorySlot never crosses the save boundary as an object, only as the
## flat Dictionary produced by Inventory's own serialization step.
##
## instance_id is the SOLE key for unique-instance identity: -1 means this
## slot holds a stackable item (Material/CraftedGood, cap 99); any value >= 0
## is a monotonic identity assigned once at creation by Inventory's
## _next_instance_id counter, and is the ONLY thing that may be used to decide
## whether two stat-rolled items are "the same instance" for merge/lock
## purposes — never item_id, never stat_overrides equality (control manifest,
## ADR-0016 Decision: "Unique-instance identity").

var item_id: StringName = &""
var quantity: int = 0
var instance_id: int = -1  ## -1 = stackable; >= 0 = unique-instance identity
var stat_overrides: Dictionary[StringName, float] = {}  ## empty for stackable items
var locked: bool = false  ## true while equipped/installed (Story 004 wires enforcement)
var damaged: bool = false  ## ADR-0021 (Crafting Story 005) — cleared via Inventory.clear_damaged_flag(), never checks `locked`
## Epic 08, Story 010 (ADR-0025): total rune slots this item was crafted with
## (EquipmentRecipeResource.rune_slot_count, per output_slot's fixed table) —
## 0 for any non-Equipment-Forge-crafted item. imbued_runes holds the
## currently-filled slots (size <= rune_slot_count); the remainder are free/
## empty. Filling is Story 013's own scope (Inventory.apply_rune_to_item()) —
## this story only establishes the item's total capacity at creation time.
var rune_slot_count: int = 0
var imbued_runes: Array[StringName] = []
