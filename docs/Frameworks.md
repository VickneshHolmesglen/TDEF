# Sanctuary Defenders - Frameworks & Systems Checklist

A comprehensive checklist of all frameworks and systems in the MTD project.

---

## Core Framework

### ECS Core (`src/core/ecs/`)
- [x] Entity (`entity.gd`) - Base entity with components & tags
- [x] Component (`component.gd`) - Base component class
- [x] System (`system.gd`) - Base system with entity processing
- [x] World (`world.gd`) - ECS world manager

### Event System (`src/core/events/`)
- [x] EventBus (`event_bus.gd`) - Pub/sub event system
- [x] GameEvents (`game_events.gd`) - 60+ typed event definitions

### Save System (`src/core/save/`)
- [x] SaveManager (`save_manager.gd`) - Save/load orchestration
- [x] SaveData (`save_data.gd`) - Serialization structure
- [x] SaveableSystem (`saveable_system.gd`) - Interface for saveable systems

### Config System (`src/core/config/`)
- [x] ConfigManager (`config_manager.gd`) - Settings management
- [x] GameConfig (`game_config.gd`) - Runtime config values

### Debug System (`src/core/debug/`)
- [x] DebugManager (`debug_manager.gd`) - Debug controls
- [x] DebugConsole (`debug_console.gd`) - In-game console

### Game Manager
- [x] GameManager (`game_manager.gd`) - Main orchestrator (27 systems)

---

## Gameplay Systems

### Hero System (`src/systems/hero/`)
- [x] HeroSystem (`hero_system.gd`) - Hero management
- [x] HeroMovementSystem (`hero_movement_system.gd`) - WASD movement
- [x] HeroCombatSystem (`hero_combat_system.gd`) - Auto-attack & skills
- [x] EquipmentSystem (`equipment_system.gd`) - 11-slot equipment

### Monster System (`src/systems/monster/`)
- [x] MonsterSystem (`monster_system.gd`) - State machine AI
- [x] WaveSystem (`wave_system.gd`) - Wave spawning

### Tower System (`src/systems/tower/`)
- [x] TowerSystem (`tower_system.gd`) - 4-slot modular towers
- [x] ConstellationSystem (`constellation_system.gd`) - Pattern bonuses

### Combat System (`src/systems/combat/`)
- [x] DamageSystem (`damage_system.gd`) - Damage calculation
- [x] ProjectileSystem (`projectile_system.gd`) - Projectile management

### Building System (`src/systems/building/`)
- [x] BuildingSystem (`building_system.gd`) - Placement & construction
- [x] BarrierSystem (`barrier_system.gd`) - Barrier management

---

## Economy & Progression

- [x] EconomySystem (`economy_system.gd`) - Gold, gems, currencies
- [x] InventorySystem (`inventory_system.gd`) - Grid-based inventory
- [x] ProgressionSystem (`progression_system.gd`) - XP, levels, unlocks

### Crafting (`src/systems/crafting/`)
- [x] CraftingSystem (`crafting_system.gd`) - Auto-crafting queue
- [x] MaterialSystem (`material_system.gd`) - Material management

---

## Unique Systems

### Menagerie (`src/systems/menagerie/`)
- [x] MenagerieSystem (`menagerie_system.gd`) - Capture & breeding
- [x] HabitatSystem (`habitat_system.gd`) - Creature housing

### Tarot (`src/systems/tarot/`)
- [x] TarotSystem (`tarot_system.gd`) - Card collection & effects
- [x] DeckSystem (`deck_system.gd`) - Deck building

### Mission (`src/systems/mission/`)
- [x] MissionSystem (`mission_system.gd`) - Mission management
- [x] ModifierSystem (`modifier_system.gd`) - Difficulty modifiers

### Hub
- [x] HubManager (`hub_manager.gd`) - Between-mission hub

---

## Procedural Generation

- [x] MapGenerator (`map_generator.gd`) - Procedural maps
- [x] MapDecorator (`map_decorator.gd`) - Map decoration
- [x] WaveGenerator (`wave_generator.gd`) - Dynamic wave composition
- [x] LootTable (`loot_table.gd`) - Loot drops

---

## Polish Systems

- [x] AudioManager (`audio_manager.gd`) - Sound & music
- [x] VisualFeedbackManager (`visual_feedback_manager.gd`) - Damage numbers, effects
- [x] InputManager (`input_manager.gd`) - Controller/keyboard
- [x] EntityVisualManager (`entity_visual_manager.gd`) - 3D entity visuals
- [x] GameCamera (`game_camera.gd`) - Camera controls

---

## UI Framework

### UIManager
- [x] UIManager (`ui_manager.gd`) - UI orchestration

### Base UI (`src/ui/base/`)
- [x] UITheme (`ui_theme.gd`) - Styling
- [x] UIPanel (`ui_panel.gd`) - Base panel
- [x] UITooltip (`ui_tooltip.gd`) - Tooltips
- [x] UIDialog (`ui_dialog.gd`) - Dialogs

### HUD (`src/ui/hud/`)
- [x] GameHUD (`game_hud.gd`) - Main HUD container
- [x] HeroStatusPanel (`hero_status_panel.gd`) - Health/mana bars
- [x] ResourceDisplay (`resource_display.gd`) - Gold/gems
- [x] WaveDisplay (`wave_display.gd`) - Wave info
- [x] SkillBar (`skill_bar.gd`) - Skill slots
- [x] Minimap (`minimap.gd`) - Minimap
- [x] NotificationArea (`notification_area.gd`) - Toast notifications

### Game Panels (`src/ui/game/`)
- [x] InventoryPanel (`inventory_panel.gd`) - Inventory grid
- [x] CraftingPanel (`crafting_panel.gd`) - Crafting UI
- [x] DeckBuilderPanel (`deck_builder_panel.gd`) - Deck building

### Menus (`src/ui/menus/`)
- [x] MainMenu (`main_menu.gd`) - Title screen
- [x] PauseMenu (`pause_menu.gd`) - Pause screen
- [x] SettingsPanel (`settings_panel.gd`) - Options
- [x] SaveLoadPanel (`save_load_panel.gd`) - Save/load

---

## Components (14)

- [x] HeroComponent - Hero identity, skills, equipment slots
- [x] MonsterComponent - Monster AI state, aggro
- [x] TowerComponent - 4-slot modular tower data
- [x] HealthComponent - HP, mana, shields
- [x] StatsComponent - All stat values
- [x] TransformComponent - Position, rotation
- [x] MovementComponent - Speed, velocity
- [x] InventoryComponent - Grid inventory
- [x] ItemComponent - Item data, affixes
- [x] ProjectileComponent - Projectile data
- [x] BarrierComponent - Barrier data
- [x] CreatureComponent - Menagerie creature
- [x] CardComponent - Tarot card
- [x] StatusEffectComponent - Buffs/debuffs

---

## Resources (10)

- [x] HeroResource - Hero templates
- [x] MonsterResource - Monster templates
- [x] TowerComponentResource - Tower part templates
- [x] ItemResource - Item templates
- [x] RecipeResource - Crafting recipes
- [x] CreatureResource - Creature templates
- [x] CardResource - Tarot card templates
- [x] WaveResource - Wave definitions
- [x] StatModifierResource - Stat modifiers
- [x] ResourceDatabase - Central resource loader

---

## Summary

- **Total Files**: 90+ GDScript files
- **Core Systems**: ECS, Events, Save, Config, Debug
- **Gameplay Systems**: Hero, Monster, Tower, Combat, Building
- **Economy Systems**: Economy, Inventory, Crafting, Progression
- **Unique Systems**: Menagerie, Tarot, Mission, Hub
- **Procedural**: Map, Wave, Loot generation
- **Polish**: Audio, Visual Feedback, Input, Camera
- **UI**: Manager, HUD, Panels, Menus
- **Components**: 14 data components
- **Resources**: 10 resource types
