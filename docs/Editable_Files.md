# Editable Files Guide

Files you need to edit, adjust, or add values to customize the game.

---

## Game Balance

### `src/core/config/game_config.gd`
Edit in Godot Inspector or create `data/config/game_config.tres`

| Category | What to Adjust |
|----------|----------------|
| Performance | FPS, pool sizes, update limits |
| Hero | Base stats, max level, respawn time |
| Monsters | Health/damage scaling, max active |
| Towers | Max towers, XP per kill, constellation radius |
| Waves | Build time, gold bonuses |
| Economy | Starting gold/gems, sell multiplier, interest rate |
| Inventory | Grid sizes, max affixes |
| Crafting | Queue size, speed multiplier |
| Menagerie | Max creatures/habitats, breeding cooldown |
| Tarot | Deck size/cost, cards per mission |
| Combat | Armor formula, crit multiplier, min damage |
| Progression | XP values, prestige settings |
| UI | Tooltip delay, notification duration |

---

## Data Templates

These `.tres` files define what exists in the game. Edit in Godot Inspector.

### Heroes (`data/heroes/`)
| File | What to Set |
|------|-------------|
| `*.tres` | `id`, `display_name`, `hero_class`, `base_stats`, `skills`, `description` |

### Monsters (`data/monsters/`)
| File | What to Set |
|------|-------------|
| `*.tres` | `id`, `display_name`, `category`, `base_health`, `base_damage`, `speed`, `loot_table` |

### Items (`data/items/`)
| File | What to Set |
|------|-------------|
| `*.tres` | `id`, `item_name`, `item_type`, `equipment_slot`, `rarity`, `base_stats`, `affixes` |

### Tower Components (`data/towers/`)
| File | What to Set |
|------|-------------|
| `*.tres` | `id`, `display_name`, `slot_type`, `stats`, `special_effects` |

### Creatures (`data/creatures/`)
| File | What to Set |
|------|-------------|
| `*.tres` | `id`, `display_name`, `habitat_type`, `production`, `rarity` |

### Cards (`data/cards/`)
| File | What to Set |
|------|-------------|
| `*.tres` | `id`, `card_name`, `suit`, `rank`, `cost`, `effects` |

### Recipes (`data/recipes/`)
| File | What to Set |
|------|-------------|
| `*.tres` | `id`, `result_item_id`, `ingredients`, `station_type`, `craft_time` |

### Waves (`data/waves/`)
| File | What to Set |
|------|-------------|
| `*.tres` | `wave_number`, `display_name`, `spawn_groups`, `difficulty_mult`, `rewards` |

---

## Input Bindings

### `project.godot` (Input Map section)
Or edit via **Project > Project Settings > Input Map**

| Action | Default | What It Does |
|--------|---------|--------------|
| `move_up` | W | Move hero up |
| `move_down` | S | Move hero down |
| `move_left` | A | Move hero left |
| `move_right` | D | Move hero right |
| `attack` | Left Mouse | Primary attack |
| `skill_1` - `skill_6` | 1-6 | Skill hotkeys |
| `toggle_inventory` | I | Open inventory |
| `toggle_build` | B | Toggle build mode |
| `pause` | ESC | Pause game |

---

## Audio

### `assets/audio/`
Add sound files here:

| Folder | Contents |
|--------|----------|
| `sfx/` | Sound effects (.wav, .ogg) |
| `music/` | Background music (.ogg) |
| `ui/` | UI sounds (clicks, hovers) |

Referenced by AudioManager - match filenames to IDs used in code.

---

## Visuals

### `assets/textures/`
| Folder | Contents |
|--------|----------|
| `icons/` | Item, skill, UI icons |
| `portraits/` | Hero/creature portraits |
| `effects/` | Particle textures |

### `assets/models/` or `assets/sprites/`
| Folder | Contents |
|--------|----------|
| `heroes/` | Hero models/sprites |
| `monsters/` | Monster models/sprites |
| `towers/` | Tower models/sprites |
| `projectiles/` | Projectile visuals |

### `scenes/entities/`
Scene files for spawnable entities (monsters, projectiles, etc.)

---

## Loot Tables

### `src/systems/loot/loot_table.gd`
Edit drop rates and loot pools:

```gdscript
# Example structure
var loot_tables = {
    "common_monster": {
        "gold": {"min": 5, "max": 15, "chance": 1.0},
        "item": {"pool": "common_items", "chance": 0.1}
    }
}
```

---

## Quick Reference

| I want to... | Edit this file |
|--------------|----------------|
| Change hero health | `game_config.gd` → `hero_base_health` |
| Add a new monster | Create `data/monsters/my_monster.tres` |
| Add a new item | Create `data/items/my_item.tres` |
| Change starting gold | `game_config.gd` → `starting_gold` |
| Add a new wave | Create `data/waves/wave_XX.tres` |
| Change XP curve | `game_config.gd` → `hero_exp_curve_exponent` |
| Add crafting recipe | Create `data/recipes/my_recipe.tres` |
| Change keybindings | Project Settings → Input Map |
| Add background music | `assets/audio/music/` |
| Change crit damage | `game_config.gd` → `base_crit_multiplier` |

---

## Notes

- All `.tres` files are edited in Godot's Inspector panel
- Changes to `game_config.gd` require creating a `.tres` instance to persist
- Data templates are loaded by `ResourceDatabase` at startup
- Use consistent IDs across files (e.g., item ID in recipe ingredients)
