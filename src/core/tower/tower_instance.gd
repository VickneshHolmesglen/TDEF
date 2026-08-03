class_name TowerInstance
extends Node2D

## Minimal visual presentation for a placed tower. Displays a static texture
## keyed by the tower's Foundation archetype (`physical` | `ranged` |
## `elemental` | `support`, per design/gdd/tower.md Group 2).
##
## Scope note: this is presentation only — it has no link yet to
## TowerSystem/TowerMissionState (which remain RefCounted, headless
## simulation with no scene-tree presence). Placement-triggered
## instantiation, tier-based art swaps, and damaged-state visuals are not
## yet designed; call configure() manually until that wiring exists.

## Archetype -> art lookup. All 4 archetypes now have placeholder art.
const ARCHETYPE_TEXTURES: Dictionary[String, Texture2D] = {
	"ranged": preload("res://assets/art/towers/tower_ranged_base.png"),
	"physical": preload("res://assets/art/towers/tower_physical_base.png"),
	"elemental": preload("res://assets/art/towers/tower_elem_ice.png"),
	"support": preload("res://assets/art/towers/tower_support_base.png"),
}

## Target on-screen height (world units, matches MonsterManager.CELL_SIZE=64
## so a tower reads as roughly one grid cell). Source art is unscaled,
## native ChatGPT-generation resolution and varies wildly by archetype
## (267x471 to 1185x1173, per a project-wide art-asset sweep 2026-08-03) --
## found and fixed proactively here, mirroring the identical unscaled-sprite
## bug already found live (via Godot MCP) and fixed in MonsterInstance and
## diorama.gd's structure sprites. TowerInstance has no live placement
## call-site yet to have caught this by screenshot the same way -- fixed
## ahead of that wiring so it isn't rediscovered the hard way later.
const TARGET_DISPLAY_HEIGHT: float = 64.0

@onready var _sprite: Sprite2D = $Sprite2D


## Sets the displayed texture for the given Foundation archetype and scales
## it to TARGET_DISPLAY_HEIGHT. Logs a warning and leaves the sprite empty
## if no art exists for that archetype yet.
func configure(archetype: String) -> void:
	var texture: Texture2D = ARCHETYPE_TEXTURES.get(archetype, null)
	if texture == null:
		push_warning("[TowerInstance] no art authored for archetype '%s'" % archetype)
		_sprite.texture = null
		return
	_sprite.texture = texture
	var uniform_scale: float = TARGET_DISPLAY_HEIGHT / float(texture.get_height())
	_sprite.scale = Vector2(uniform_scale, uniform_scale)
