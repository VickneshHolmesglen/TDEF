# Prototype: Stacked Sprite + 3D/2D Seam Test

<!-- PROTOTYPE — NOT FOR PRODUCTION -->
<!-- Question: See §Core Questions below -->
<!-- Date: 2026-05-18 -->

**Status**: Qwen implementation brief — ready to build  
**Risk**: HIGH (Art Director flag — blocks all 2D asset commissioning)  
**Engine**: Godot 4.6.2 / GDScript  
**Timebox**: 1 session  

---

## Core Questions

**Q1 — Stacked-sprite volume**  
Do multiple Sprite2D/ColorRect layers (base slice → cast-shadow → mid slice → cast-shadow → top slice) with a flat contact shadow beneath them produce convincing pseudo-3D volume — reading as "a physical object sitting ON the ground plane" rather than a flat image?

**Q2 — 3D/2D seam**  
Can a Godot 4.6.2 `SubViewport` composite a 3D `MeshInstance3D` hero into a 2D stacked-sprite scene, reading as "a figurine placed on the board" rather than "a model pasted from a different game"?

Pass/fail criteria: `VALIDATION-CRITERIA.md`

---

## Prototype Scope

**In scope — only these things:**
- 1 world scene, y-sorted `Node2D` world container
- 2 tower stacks at different world-Y positions (Far + Near) — `ColorRect` geometry only, no art assets
- 1 hero composite via `SubViewport` + `CapsuleMesh` placeholder
- Contact shadow ellipse beneath every object
- Cast-shadow strips between stack layers
- Space key: fan layers apart to inspect each slice
- R key: reload scene to reset

**Out of scope — do not add:**
- Art assets of any kind (ColorRect + CapsuleMesh only)
- Grid, EventBus, save system, game logic
- Animation, particles, shaders
- Multiple scenes, menus, or UI beyond the debug label

---

## Build Instructions

**One scene file, one script. Everything built procedurally — no art assets required.**

1. Create `StackedSpriteTest.tscn` with a bare `Node2D` root
2. Attach `stacked_sprite_test.gd` to the root node
3. Play the scene — all geometry is generated at `_ready()`

---

## Scene File

`prototypes/stacked-sprite-test/StackedSpriteTest.tscn`

```
Node2D  "StackedSpriteTest"
  └─ Script: res://prototypes/stacked-sprite-test/stacked_sprite_test.gd
```

That is the entire .tscn. All child nodes are instantiated by the script.

**Project Settings note**: Add `res://prototypes/` to the project's autoload exclusion list to prevent prototype scripts from interfering with production autoloads.

---

## Script: stacked_sprite_test.gd

```gdscript
# PROTOTYPE — NOT FOR PRODUCTION
# Question: Stacked-sprite pseudo-3D volume + 3D/2D seam validation
# Date: 2026-05-18

extends Node2D

# ── Art bible palette (Section 4) ────────────────────────────────────────────
const C_FIELDSTONE  := Color(0.494, 0.522, 0.565)   # #7E8590 — tower Far
const C_AMBER       := Color(0.784, 0.502, 0.102)   # #C8801A — tower Near
const C_GROUND      := Color(0.380, 0.420, 0.340)   # earthy neutral base
const C_SHADOW_FLAT := Color(0.0,   0.0,   0.0, 0.40)  # contact shadow
const C_SHADOW_CAST := Color(0.0,   0.0,   0.0, 0.25)  # inter-layer cast shadow

# ── Stack geometry ────────────────────────────────────────────────────────────
const SLICE_H   := 16   # px — height of each layer slice
const SLICE_GAP := 4    # px — gap between slices (creates depth reading)
const TOWER_W   := 48   # px — tower base width

# ── Node refs ─────────────────────────────────────────────────────────────────
var _world: Node2D
var _hero_viewport: SubViewport


func _ready() -> void:
    # Ground plane
    var ground := ColorRect.new()
    ground.name = "Ground"
    ground.color = C_GROUND
    ground.size = Vector2(640, 400)
    ground.position = Vector2(-320, -100)
    add_child(ground)

    # World container — y_sort_enabled so towers order by screen-Y
    _world = Node2D.new()
    _world.name = "World"
    _world.y_sort_enabled = true
    add_child(_world)

    # Two towers at different world-Y positions to validate draw order
    _add_tower(Vector2(-90, -40), C_FIELDSTONE, "TowerFar")
    _add_tower(Vector2(10,   50), C_AMBER,      "TowerNear")

    # 3D hero composite at world position between the two towers
    _setup_hero(Vector2(80, 20))

    # Debug instructions overlay
    var lbl := Label.new()
    lbl.name = "DebugLabel"
    lbl.text = "[Space] fan layers   [R] reset scene"
    lbl.position = Vector2(-300, -220)
    add_child(lbl)


# ── Tower stack ───────────────────────────────────────────────────────────────
# Structure: ContactShadow (z=0) → L0 (z=1) → CastShadow (z=2) → L1 (z=3)
#            → CastShadow (z=4) → L2 (z=5)
#
# y_sort_enabled=false on the root keeps Godot from re-sorting layers by Y.
# Layers use z_index (relative to parent) for deterministic draw order.
# The root Node2D itself IS y-sorted relative to other world objects.
func _add_tower(world_pos: Vector2, base_color: Color, id: String) -> void:
    var root := Node2D.new()
    root.name = id
    root.position = world_pos
    root.y_sort_enabled = false
    _world.add_child(root)

    # Contact shadow — flat ellipse on the ground plane
    var contact := ColorRect.new()
    contact.color = C_SHADOW_FLAT
    contact.size = Vector2(TOWER_W, 10)
    contact.position = Vector2(-TOWER_W / 2.0, 2)
    contact.z_index = 0
    root.add_child(contact)

    # Layer 0 — base (sits directly on ground)
    var l0 := ColorRect.new()
    l0.color = base_color
    l0.size = Vector2(TOWER_W, SLICE_H)
    l0.position = Vector2(-TOWER_W / 2.0, -SLICE_H)
    l0.z_index = 1
    root.add_child(l0)

    # Cast shadow 1 — L1 casting shadow down onto the top edge of L0
    var cs1 := ColorRect.new()
    cs1.color = C_SHADOW_CAST
    cs1.size = Vector2(TOWER_W - 4, SLICE_GAP + 2)
    cs1.position = Vector2(-TOWER_W / 2.0 + 2, -SLICE_H - SLICE_GAP)
    cs1.z_index = 2
    root.add_child(cs1)

    # Layer 1 — mid (slightly narrower + lighter to read as elevated)
    var l1 := ColorRect.new()
    l1.color = base_color.lightened(0.10)
    l1.size = Vector2(TOWER_W - 6, SLICE_H)
    l1.position = Vector2(-TOWER_W / 2.0 + 3, -SLICE_H * 2 - SLICE_GAP)
    l1.z_index = 3
    root.add_child(l1)

    # Cast shadow 2 — L2 casting shadow onto L1
    var cs2 := ColorRect.new()
    cs2.color = C_SHADOW_CAST
    cs2.size = Vector2(TOWER_W - 10, SLICE_GAP + 2)
    cs2.position = Vector2(-TOWER_W / 2.0 + 5, -SLICE_H * 2 - SLICE_GAP * 2)
    cs2.z_index = 4
    root.add_child(cs2)

    # Layer 2 — top (narrowest + lightest — pyramid taper implies height)
    var l2 := ColorRect.new()
    l2.color = base_color.lightened(0.22)
    l2.size = Vector2(TOWER_W - 12, SLICE_H - 4)
    l2.position = Vector2(-TOWER_W / 2.0 + 6, -SLICE_H * 3 - SLICE_GAP * 2)
    l2.z_index = 5
    root.add_child(l2)


# ── 3D hero composite ─────────────────────────────────────────────────────────
# SubViewport renders a 3D CapsuleMesh at a fixed oblique Camera3D angle.
# get_texture() returns a ViewportTexture assigned live to a Sprite2D.
# That Sprite2D participates in y_sort alongside the 2D tower stacks.
func _setup_hero(world_pos: Vector2) -> void:
    # SubViewport — must be added to tree BEFORE get_texture() is called
    _hero_viewport = SubViewport.new()
    _hero_viewport.name = "HeroViewport"
    _hero_viewport.size = Vector2i(128, 256)
    _hero_viewport.transparent_bg = true
    _hero_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(_hero_viewport)

    _build_hero_3d_scene(_hero_viewport)

    # Container in the y-sorted world
    var hero_root := Node2D.new()
    hero_root.name = "HeroComposite"
    hero_root.position = world_pos
    hero_root.y_sort_enabled = false
    _world.add_child(hero_root)

    # Contact shadow — same ellipse pattern as towers
    var shadow := ColorRect.new()
    shadow.color = C_SHADOW_FLAT
    shadow.size = Vector2(34, 10)
    shadow.position = Vector2(-17, 2)
    shadow.z_index = 0
    hero_root.add_child(shadow)

    # Sprite2D displaying the viewport texture (live — updates every frame)
    var hero_sprite := Sprite2D.new()
    hero_sprite.name = "HeroSprite"
    hero_sprite.texture = _hero_viewport.get_texture()
    # Offset: SubViewport is 128×256 (anchor = center = 64,128).
    # Move up so capsule feet align with world_pos (ground level).
    hero_sprite.position = Vector2(0, -100)
    hero_sprite.z_index = 2
    hero_root.add_child(hero_sprite)


func _build_hero_3d_scene(viewport: SubViewport) -> void:
    # Directional light — top-left oblique to match art bible Section 2 lighting
    var light := DirectionalLight3D.new()
    light.name = "HeroLight"
    light.rotation_degrees = Vector3(-50, 30, 0)
    light.light_energy = 1.2
    viewport.add_child(light)

    # Hero placeholder — CapsuleMesh with warm-toned material
    var hero_mesh := MeshInstance3D.new()
    hero_mesh.name = "HeroPlaceholder"
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.35
    capsule.height = 1.8
    hero_mesh.mesh = capsule
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.80, 0.55, 0.25)   # warm neutral — visible against ground
    mat.roughness = 0.75
    hero_mesh.material_override = mat
    hero_mesh.position = Vector3(0, 0.9, 0)   # base at Y=0, center at Y=0.9
    viewport.add_child(hero_mesh)

    # Camera3D — ORTHOGONAL projection to match the non-perspective 2D art.
    # Perspective projection on the 3D hero would create a visual mismatch
    # with the flat 2D world (depth compression mismatch).
    # Elevated oblique angle: looking down ~45° from a raised position.
    var camera := Camera3D.new()
    camera.name = "HeroCamera"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 2.2          # world-units visible across the viewport height
    camera.position = Vector3(0.0, 2.5, 2.5)
    camera.look_at(Vector3(0.0, 0.9, 0.0), Vector3.UP)
    viewport.add_child(camera)
    camera.make_current()


# ── Debug controls ────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
    if not (event is InputEventKey and event.pressed):
        return
    match event.keycode:
        KEY_SPACE:
            _fan_tower_layers()
        KEY_R:
            get_tree().reload_current_scene()


# Fan all stack layers apart vertically so each slice is visible independently.
# Press R to reset (reloads scene — simplest prototype reset).
func _fan_tower_layers() -> void:
    for tower_name: String in ["TowerFar", "TowerNear"]:
        var tower: Node2D = _world.get_node_or_null(tower_name)
        if not tower:
            continue
        var layer_idx := 0
        for child: Node in tower.get_children():
            if child is ColorRect:
                child.position.y -= layer_idx * 22
                layer_idx += 1
```

---

## Godot 4.6.2 Notes

These are post-LLM-cutoff specifics to check before implementing:

| Item | Godot 4.6.2 Behaviour | Risk |
|------|----------------------|------|
| `SubViewport.transparent_bg` | Property exists in 4.x — sets clear colour to transparent | LOW |
| `SubViewport.get_texture()` | Returns a live `ViewportTexture` (updates each frame) | LOW |
| `Camera3D.PROJECTION_ORTHOGONAL` | Enum constant — use instead of integer `1` | LOW |
| `camera.make_current()` | Still required in Godot 4 to activate the camera | LOW |
| `StandardMaterial3D` | Replaces `SpatialMaterial` from Godot 3 | LOW |
| D3D12 default renderer (4.6, Windows) | SubViewport transparent compositing may differ from Vulkan | **MEDIUM — validate** |
| `y_sort_enabled` vs `z_index` interaction | y-sort changes draw order of children, does NOT write z_index values | LOW |

**Validate on target machine**: D3D12 (default on Windows in 4.6) may render the SubViewport transparent background differently from Vulkan. If the hero sprite shows a black background instead of transparency, add a `WorldEnvironment` node inside the SubViewport with `Environment.background_mode = Environment.BG_COLOR` and `Environment.background_color = Color(0,0,0,0)`.

---

## Camera Tuning Guide

The Camera3D angle is the seam-quality lever. After initial build, adjust these to find the best diorama match:

| Property | Starting Value | What it controls |
|----------|---------------|-----------------|
| `camera.position` | `Vector3(0, 2.5, 2.5)` | Camera height and distance — raise Y for more top-down, lower for more side-on |
| `camera.size` | `2.2` | Orthographic zoom — lower = hero fills frame more |
| `look_at` target | `Vector3(0, 0.9, 0)` | Look target — keep at ~mid-height of capsule |
| `light.rotation_degrees` | `Vector3(-50, 30, 0)` | Matches art bible Section 2 warm-left / cool-right lighting |

The target reading: "figurine placed on a game board" — not "screenshot from a different game pasted in."

---

## File Checklist

```
prototypes/stacked-sprite-test/
├── README.md                    ← this file (Qwen brief)
├── VALIDATION-CRITERIA.md       ← pass/fail checklist
├── StackedSpriteTest.tscn       ← Qwen creates: bare Node2D root
├── stacked_sprite_test.gd       ← Qwen creates: script above
└── REPORT.md                    ← written after testing
```
