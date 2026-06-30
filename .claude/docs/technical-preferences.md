# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.2
- **Language**: GDScript
- **Rendering**: Vulkan (desktop primary) / D3D12 (Windows default in Godot 4.6+)
- **Physics**: Jolt Physics (default in Godot 4.6+)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Windows, Linux, macOS) via Steam / Epic Games Store
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: Partial (optional, not primary — all interactions must be completable with K/M)
- **Touch Support**: None
- **Platform Notes**: UI must support both mouse-driven and d-pad/analog gamepad navigation. No hover-only or touch-only interactions.

## Naming Conventions

- **Classes**: PascalCase (e.g., `HeroManager`, `TowerComponent`)
- **Variables/Functions**: snake_case (e.g., `move_speed`, `take_damage()`)
- **Signals**: snake_case past tense (e.g., `health_changed`, `wave_completed`, `item_equipped`)
- **Files**: snake_case matching class (e.g., `hero_manager.gd`)
- **Scenes**: PascalCase matching root node (e.g., `HeroManager.tscn`, `TowerInstance.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_HEALTH`, `BASE_CRIT_MULTIPLIER`)

## Performance Budgets

- **Target Framerate**: 60 FPS
- **Frame Budget**: 16.67 ms (1 frame @ 60 FPS)
- **Draw Calls**: 200 per frame
- **Memory Ceiling**: 1 GB

## Testing

- **Framework**: GUT (Godot Unit Testing — gdUnit4)
- **Minimum Coverage**: 80% (applies to Logic and Integration stories; Visual/Feel and Config/Data stories exempt)
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here. Only add when actively integrating — not speculatively. -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and cross-cutting code review. Invoke GDScript specialist for code quality, signal architecture, static typing enforcement, and GDScript idioms. Invoke shader specialist for material design and shader code. Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
