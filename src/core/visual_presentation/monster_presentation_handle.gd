class_name MonsterPresentationHandle
extends RefCounted

## Value-like handle identifying one live standard creature's slot inside a
## MonsterSwarmBatch (ADR-0038 §"Dense handles and lifecycle"; blueprint
## Data contracts → PresentationHandle). No Node ownership — this is plain
## data a caller holds and passes back to
## MonsterSwarmRenderer3D.update_creature()/unregister_creature().
##
## slot_index is a HINT, not authoritative — MonsterSwarmBatch always
## re-resolves the real slot from entity_id via its own reverse map before
## trusting it (see monster_swarm_batch.gd's own header comment for why:
## slot_index can go stale from unrelated swap-remove churn elsewhere in the
## batch, and validating only against entity_id + generation is the more
## robust reading of this contract — the same design decision the pilot's
## PilotSwarmBatch made and flagged for confirmation, carried forward here
## unchanged since nothing has surfaced to contradict it).

## The monster entity this handle was issued for.
var entity_id: int = -1

## Identifies which MonsterSwarmBatch owns this handle's slot — the
## String form of a BatchKey tuple (see monster_swarm_renderer_3d.gd's
## make_batch_key()). A handle is only ever valid against the batch that
## issued it.
var batch_key: String = ""

## Hint only — see class doc comment above. Not trusted without a fresh
## entity_id → slot resolution.
var slot_index: int = -1

## Incremented by the owning batch whenever this entity_id's slot identity
## is invalidated (removed, or overwritten by re-registration after
## removal). A handle whose generation no longer matches the batch's
## current generation for entity_id is stale and must be rejected.
var generation: int = -1


func _init(p_entity_id: int, p_batch_key: String, p_slot_index: int, p_generation: int) -> void:
	entity_id = p_entity_id
	batch_key = p_batch_key
	slot_index = p_slot_index
	generation = p_generation
