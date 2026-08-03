class_name MonsterInstance
extends Node2D

## Minimal visual presentation for a spawned monster. Displays a static
## texture keyed by the monster's `monster_id` (per design/gdd/monster.md
## Group 1 — one authored art asset per monster_id, not per-archetype/tier
## like TowerInstance's Foundation-archetype keying).
##
## Mirrors TowerInstance's pattern (src/core/tower/tower_instance.gd):
## presentation only, no simulation logic. Unlike TowerInstance, this IS
## wired into its owning system's spawn path — MonsterManager._spawn_entity()
## already parents every MonsterEntity into the real scene tree (TD-monster-003),
## so no separate placement-triggered-instantiation gap exists here.

## monster_id -> art lookup. All 7 monsters generated this session have art.
const MONSTER_TEXTURES: Dictionary[StringName, Texture2D] = {
	&"goblin_runner": preload("res://assets/art/monsters/goblin_runner.png"),
	&"spore_skitterling": preload("res://assets/art/monsters/spore_skitterling.png"),
	&"armored_brute": preload("res://assets/art/monsters/armored_brute.png"),
	&"forest_troll_elite": preload("res://assets/art/monsters/forest_troll_elite.png"),
	&"bog_lurker_elite": preload("res://assets/art/monsters/bog_lurker_elite.png"),
	&"goblin_warlord_boss": preload("res://assets/art/monsters/goblin_warlord_boss.png"),
	&"rift_sentinel_boss": preload("res://assets/art/monsters/rift_sentinel_boss.png"),
}

## Target on-screen size (world units, matches MonsterManager.CELL_SIZE=64) for
## a sprite's longest edge, by MonsterResource.tier (0=STANDARD/1=ELITE fit one
## cell; 2=BOSS reads deliberately larger). Source art is authored at native
## ChatGPT-generation resolution (~900-1200px) with no downscale baked in —
## found live via Godot MCP screenshot (an undersized boss filled the whole
## viewport) rather than assumed; TowerInstance shares this same unscaled
## pattern but was never live-verified against a real placement to catch it.
const TARGET_LONG_EDGE_BY_TIER: Dictionary[int, float] = {
	0: 64.0,
	1: 64.0,
	2: 112.0,
}

@onready var _sprite: Sprite2D = $Sprite2D


## Sets the displayed texture for the given monster_id and scales it to fit
## the grid (see TARGET_LONG_EDGE_BY_TIER). Logs a warning and leaves the
## sprite empty if no art exists for that id yet.
func configure(monster_id: StringName, tier: int = 0) -> void:
	var texture: Texture2D = MONSTER_TEXTURES.get(monster_id, null)
	if texture == null:
		push_warning("[MonsterInstance] no art authored for monster_id '%s'" % monster_id)
		_sprite.texture = null
		return
	_sprite.texture = texture
	var target_long_edge: float = TARGET_LONG_EDGE_BY_TIER.get(tier, 64.0)
	var longest_edge: float = maxf(texture.get_width(), texture.get_height())
	var uniform_scale: float = target_long_edge / longest_edge
	_sprite.scale = Vector2(uniform_scale, uniform_scale)
