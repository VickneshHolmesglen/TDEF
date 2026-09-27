# Tower Element Tint Ring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a brand-new `WeaponComponent.element` value (one with no entry yet in `TowerInstance.ELEMENT_TEXTURES`) read as a visually distinct tower immediately — via a persistent, color-coded identity ring drawn procedurally around the tower's base — instead of requiring bespoke full-body art before it can ship.

**Architecture:** `TowerInstance.configure()` already falls back to the generic `ARCHETYPE_TEXTURES["elemental"]` (ice-themed) texture whenever `element` has no matching key in `ELEMENT_TEXTURES`. This plan adds a persistent ring drawn in `TowerInstance._draw()` — the same procedural-drawing mechanism this file already uses for its weapon-slot glow dot and perk badge — that activates only in that fallback case, colored from the project's single existing element-color source of truth (`ProjectileVisual.ELEMENT_COLORS`, already read by `mission_scene.gd`, `tower_destroy_vfx.gd`, and `aoe_ring_visual.gd`). No new art asset is created or required; this is pure `Node2D._draw()` primitive drawing, matching `design/art/animation-pipeline.md` §2's "Towers: procedural only" directive already cited elsewhere in this exact file.

**Tech Stack:** GDScript (Godot 4.6.2), GdUnit4 (`tests/unit/tower/tower_instance_test.gd`).

**Spec:** No standalone spec document — this plan implements the "small tint addition" scoped in conversation (2026-08-29): a low-risk way to reuse existing shared tower art across future elements without generating a new full-body sprite per element, avoiding indefinite growth of `ELEMENT_TEXTURES`.

## Global Constraints

- Reuse `ProjectileVisual.ELEMENT_COLORS` / `ProjectileVisual.ARCHETYPE_COLORS["elemental"]` as the only source of truth for element colors — do not define a second color table (this project's established single-source-of-truth convention for element colors; both classes already have global `class_name`, no import needed).
- No new art assets. This is drawn via `Node2D._draw()` primitives only (`draw_arc`), matching this file's own existing weapon-glow-dot/perk-badge pattern and `design/art/animation-pipeline.md` §2's "Towers: procedural only" rule.
- Must not change the visual behavior of any element already present in `ELEMENT_TEXTURES` (fire, frost, lightning, poison, earth, water, wind, shadow, holy) — the ring must only ever appear for an element that falls through to the generic texture.
- Must not interfere with `play_attack_punch()`'s existing use of `_sprite.modulate` — this feature must not touch `_sprite.modulate` at all, only add new `_draw()` output and new state fields.
- Test naming: `test_[system]_[scenario]_[expected_result]` (per `.claude/rules/test-standards.md`); every test needs a clear arrange/act/assert shape.
- Static typing throughout (`.claude/docs/coding-standards.md` / this project's established GDScript convention — every field and function signature in this file is already fully typed).

---

## File Structure

- **Modify:** `src/core/tower/tower_instance.gd` — add `ELEMENT_TINT_RING_RADIUS`/`ELEMENT_TINT_RING_ALPHA`/`ELEMENT_TINT_RING_WIDTH` consts, `_element_tint_active`/`_element_tint_color` fields, the fallback-detection branch in `configure()`, and the ring-drawing branch in `_draw()`.
- **Modify:** `tests/unit/tower/tower_instance_test.gd` — add 6 new test functions covering the tint-activation logic (no `.tscn`/scene changes needed — the ring is pure `_draw()` output on the existing node, not a new child node).

No new files are created.

---

### Task 1: Add element-tint state fields and constants

**Files:**
- Modify: `src/core/tower/tower_instance.gd:36-46` (just after the existing `ELEMENT_TEXTURES` dict and its doc comment)
- Modify: `src/core/tower/tower_instance.gd:193-203` (existing per-instance state fields, alongside `_weapon_glow_alpha` etc.)
- Test: `tests/unit/tower/tower_instance_test.gd`

**Interfaces:**
- Produces: `TowerInstance.ELEMENT_TINT_RING_RADIUS: float`, `TowerInstance.ELEMENT_TINT_RING_ALPHA: float`, `TowerInstance.ELEMENT_TINT_RING_WIDTH: float` (consts), `TowerInstance._element_tint_active: bool`, `TowerInstance._element_tint_color: Color` (instance fields) — consumed by Task 2 (`configure()`) and Task 3 (`_draw()`).

- [ ] **Step 1: Add the three new constants**

Insert immediately after the closing `}` of `ELEMENT_TEXTURES` (currently ending at line 46, right before the `TARGET_DISPLAY_HEIGHT` doc comment block):

```gdscript
## Persistent color-identity ring for an "elemental" archetype tower whose
## WeaponComponent.element has no bespoke art in ELEMENT_TEXTURES yet (see
## that dict's own fallback comment above configure()) -- lets a brand-new
## element ship with a real color identity immediately, reusing the shared
## generic "elemental" body texture instead of requiring new painted art
## before the element can visually read as distinct from every other
## not-yet-authored element. Reuses ProjectileVisual.ELEMENT_COLORS (the
## same source of truth mission_scene.gd's _resolve_tower_color(),
## tower_destroy_vfx.gd, and aoe_ring_visual.gd already read from) rather
## than a second color table -- this project's established single-source-
## of-truth convention for element colors. Falls back to
## ProjectileVisual.ARCHETYPE_COLORS["elemental"] (ice blue) for an element
## with no entry in either dict, the same fallback _resolve_tower_color()
## already uses. Pure Node2D._draw() output, no new art asset -- matches
## design/art/animation-pipeline.md §2's "Towers: procedural only" rule,
## already the basis for this file's existing weapon-glow dot and perk
## badge below.
const ELEMENT_TINT_RING_RADIUS: float = TARGET_DISPLAY_HEIGHT * 0.55  ## sits outside WEAPON_GLOW_ORBIT_RADIUS, around the tower's base
const ELEMENT_TINT_RING_ALPHA: float = 0.55  ## quiet identity signal, not a spotlight -- matches IDLE_AMBIENT_CONFIGS's "low-intensity" framing
const ELEMENT_TINT_RING_WIDTH: float = 2.5  ## world units
```

- [ ] **Step 2: Add the two new instance fields**

Insert alongside the other per-instance visual-state fields (immediately after `var _has_perk_badge: bool = false` at line 203):

```gdscript
## Set by configure() -- true only when the tower's archetype is
## "elemental" and its element has no entry in ELEMENT_TEXTURES (the
## generic-fallback-texture case). See ELEMENT_TINT_RING_RADIUS's own doc
## comment for why this exists instead of new art.
var _element_tint_active: bool = false
var _element_tint_color: Color = Color.WHITE
```

- [ ] **Step 3: Commit**

```bash
git add src/core/tower/tower_instance.gd
git commit -m "Add element-tint ring state fields to TowerInstance (no behavior yet)"
```

---

### Task 2: Activate the tint in `configure()`

**Files:**
- Modify: `src/core/tower/tower_instance.gd:242-261` (the existing `configure()` method)
- Test: `tests/unit/tower/tower_instance_test.gd`

**Interfaces:**
- Consumes: `ELEMENT_TINT_RING_RADIUS`/`_element_tint_active`/`_element_tint_color` (Task 1), `ProjectileVisual.ELEMENT_COLORS: Dictionary[String, Color]`, `ProjectileVisual.ARCHETYPE_COLORS: Dictionary[String, Color]` (already-shipped global classes, no import needed).
- Produces: `configure()` now sets `_element_tint_active`/`_element_tint_color` correctly for every call — consumed by Task 3 (`_draw()`).

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/tower/tower_instance_test.gd` (after the existing `test_configure_elemental_archetype_with_unknown_element_falls_back_to_archetype_texture` test):

```gdscript
## "arcane" has a real ProjectileVisual.ELEMENT_COLORS entry but no
## TowerInstance.ELEMENT_TEXTURES entry -- exactly the real gap this
## feature targets (a defined element with no bespoke tower art yet).
func test_configure_elemental_with_color_but_no_texture_activates_tint_with_its_color() -> void:
	_instance.configure("elemental", "arcane")
	assert_bool(_instance._element_tint_active).is_true()
	assert_object(_instance._element_tint_color).is_equal(ProjectileVisual.ELEMENT_COLORS["arcane"])


func test_configure_elemental_with_known_texture_element_does_not_activate_tint() -> void:
	_instance.configure("elemental", "fire")
	assert_bool(_instance._element_tint_active).is_false()


func test_configure_elemental_with_wholly_unknown_element_activates_tint_with_generic_fallback_color() -> void:
	_instance.configure("elemental", "totally_unknown_element")
	assert_bool(_instance._element_tint_active).is_true()
	assert_object(_instance._element_tint_color).is_equal(ProjectileVisual.ARCHETYPE_COLORS["elemental"])


func test_configure_elemental_with_empty_element_does_not_activate_tint() -> void:
	_instance.configure("elemental", "")
	assert_bool(_instance._element_tint_active).is_false()


func test_configure_non_elemental_archetype_does_not_activate_tint() -> void:
	_instance.configure("physical")
	assert_bool(_instance._element_tint_active).is_false()


## Regression guard: a tower reconfigured from a tint-active element to a
## known-texture element must not carry a stale ring over.
func test_configure_switching_from_tint_element_to_known_texture_element_clears_tint() -> void:
	_instance.configure("elemental", "arcane")
	assert_bool(_instance._element_tint_active).is_true()
	_instance.configure("elemental", "fire")
	assert_bool(_instance._element_tint_active).is_false()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `addons/gdUnit4/runtest.sh --godot_binary "<Godot 4.6.2.stable executable path from .mcp.json's GODOT_PATH>" -a res://tests/unit/tower/tower_instance_test.gd`
Expected: the 6 new tests FAIL (the 4 pre-existing tests in this file still PASS) — `_element_tint_active`/`_element_tint_color` don't exist as behavior yet (Task 1 only added the fields with static defaults, `configure()` never touches them).

- [ ] **Step 3: Implement `configure()`'s tint-activation branch**

Replace the body of `configure()` (`src/core/tower/tower_instance.gd:242-261`) with:

```gdscript
func configure(archetype: String, element: String = "") -> void:
	var texture: Texture2D = null
	_element_tint_active = false
	if archetype == "elemental":
		texture = ELEMENT_TEXTURES.get(element)
		if texture == null and element != "":
			_element_tint_active = true
			_element_tint_color = ProjectileVisual.ELEMENT_COLORS.get(element, ProjectileVisual.ARCHETYPE_COLORS["elemental"])
	if texture == null:
		texture = ARCHETYPE_TEXTURES.get(archetype, null)
	if texture == null:
		push_warning("[TowerInstance] no art authored for archetype '%s'" % archetype)
		_sprite.texture = null
		queue_redraw()
		return
	_sprite.texture = texture
	var uniform_scale: float = TARGET_DISPLAY_HEIGHT / float(texture.get_height())
	_sprite.scale = Vector2(uniform_scale, uniform_scale)
	_base_sprite_scale = _sprite.scale
	queue_redraw()
	# Epic 15 Story 003 (ADR-0037): the one line this story adds to
	# TowerInstance's existing update method — no new _process()/
	# _physics_process() callback. See _build_visual_companion()'s doc
	# comment for why configure() (not a new per-frame override) is correct
	# here.
	_build_visual_companion()
```

(This adds the `_element_tint_active = false` reset at the top, the new `if texture == null and element != ""` branch, and two `queue_redraw()` calls — one on the early-return no-art path, one on the success path — so a freshly-activated or freshly-cleared tint always repaints. Everything else in the method is unchanged from its current form.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `addons/gdUnit4/runtest.sh --godot_binary "<Godot 4.6.2.stable executable path>" -a res://tests/unit/tower/tower_instance_test.gd`
Expected: all tests in this file PASS (the 4 pre-existing ones plus the 6 new ones — 10 total).

- [ ] **Step 5: Commit**

```bash
git add src/core/tower/tower_instance.gd tests/unit/tower/tower_instance_test.gd
git commit -m "Activate TowerInstance element-tint state for elements with no bespoke art"
```

---

### Task 3: Draw the ring

**Files:**
- Modify: `src/core/tower/tower_instance.gd:408-416` (the existing `_draw()` method)
- Test: `tests/unit/tower/tower_instance_test.gd`

**Interfaces:**
- Consumes: `_element_tint_active`/`_element_tint_color`/`ELEMENT_TINT_RING_RADIUS`/`ELEMENT_TINT_RING_ALPHA`/`ELEMENT_TINT_RING_WIDTH` (Tasks 1-2).
- Produces: visible ring output — no further code consumes this (terminal task).

`_draw()`'s ring/glow/badge output can't be asserted directly by GdUnit4 (Godot doesn't expose "what did `_draw()` paint" as inspectable state) — this task's test instead asserts that `_draw()` runs without error when the tint is active, by exercising `queue_redraw()` synchronously via `notification(NOTIFICATION_DRAW)`, matching how this file's existing `_draw()` output (the weapon glow / perk badge) already has no dedicated pixel-level test either — only their *triggering state* (`_weapon_glow_alpha`, `_has_perk_badge`) is tested elsewhere. Live-visual confirmation is a manual/Godot-MCP-screenshot step (Task 4), not a unit test.

- [ ] **Step 1: Write the failing test**

Append to `tests/unit/tower/tower_instance_test.gd`:

```gdscript
## _draw() can't be pixel-inspected by GdUnit4 -- this only confirms the
## draw call path with an active tint doesn't error, mirroring this file's
## existing coverage style for _draw()-driven state (_weapon_glow_alpha,
## _has_perk_badge are tested as state, not as pixels).
func test_draw_with_active_tint_does_not_error() -> void:
	_instance.configure("elemental", "arcane")
	_instance.notification(TowerInstance.NOTIFICATION_DRAW)
	assert_bool(_instance._element_tint_active).is_true()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `addons/gdUnit4/runtest.sh --godot_binary "<Godot 4.6.2.stable executable path>" -a res://tests/unit/tower/tower_instance_test.gd`
Expected: this test currently PASSES already by accident (nothing in `_draw()` references the new fields yet, so there's nothing to error on) — this is expected; the real verification for this step is Step 4 below (no regression) plus the manual visual check in Task 4. Proceed to Step 3.

- [ ] **Step 3: Implement the ring in `_draw()`**

Replace the body of `_draw()` (`src/core/tower/tower_instance.gd:408-416`) with:

```gdscript
func _draw() -> void:
	if _element_tint_active:
		var ring_color: Color = _element_tint_color
		ring_color.a = ELEMENT_TINT_RING_ALPHA
		draw_arc(Vector2.ZERO, ELEMENT_TINT_RING_RADIUS, 0.0, TAU, 32, ring_color, ELEMENT_TINT_RING_WIDTH, true)
	if _weapon_glow_alpha > 0.0:
		var glow_color: Color = _weapon_glow_color
		glow_color.a = _weapon_glow_alpha
		draw_circle(_weapon_glow_offset, WEAPON_GLOW_RADIUS, glow_color)
	if _has_perk_badge:
		var badge_pos := Vector2(TARGET_DISPLAY_HEIGHT * 0.35, -TARGET_DISPLAY_HEIGHT * 0.45)
		draw_circle(badge_pos, PERK_BADGE_RADIUS, PERK_BADGE_COLOR)
		draw_arc(badge_pos, PERK_BADGE_RADIUS, 0.0, TAU, 24, Color(0.95, 0.95, 0.9), 1.5, true)
```

(Only the new `if _element_tint_active:` block at the top is added; the existing weapon-glow and perk-badge blocks are unchanged.)

- [ ] **Step 4: Run all TowerInstance tests to verify no regressions**

Run: `addons/gdUnit4/runtest.sh --godot_binary "<Godot 4.6.2.stable executable path>" -a res://tests/unit/tower/tower_instance_test.gd`
Expected: all 11 tests PASS (4 pre-existing + 6 from Task 2 + 1 from this task).

- [ ] **Step 5: Commit**

```bash
git add src/core/tower/tower_instance.gd tests/unit/tower/tower_instance_test.gd
git commit -m "Draw the element-tint identity ring in TowerInstance._draw()"
```

---

### Task 4: Live-verify via Godot MCP

**Files:** none (verification only, no code changes).

**Interfaces:** none — terminal task.

- [ ] **Step 1: Run the project and place an elemental tower with a tint-eligible element**

Use `mcp__godot__run_project` on the pinned Godot 4.6.2.stable binary, then `mcp__godot__run_script` to instantiate a `TowerInstance`, call `configure("elemental", "arcane")`, and add it to the scene tree — mirroring how `tests/unit/tower/tower_instance_test.gd`'s own `before_test()` builds one.

- [ ] **Step 2: Screenshot and confirm**

Call `mcp__godot__take_screenshot`. Confirm a visible violet-toned ring (`ProjectileVisual.ELEMENT_COLORS["arcane"]` = `Color(0.55, 0.25, 0.75)`) appears around the base of the generic ice-themed tower sprite, at roughly 55% alpha, not overpowering the sprite itself.

- [ ] **Step 3: Confirm no regression on an already-authored element**

Same process with `configure("elemental", "fire")`. Confirm no ring appears (fire already has bespoke art in `ELEMENT_TEXTURES`, per Task 2's guard).

- [ ] **Step 4: Stop the project**

Call `mcp__godot__stop_project`.

(No commit — this task produces no file changes, only confirms Tasks 1-3's work renders correctly in the real engine, per this project's own `docs/engine-reference/godot/VERSION.md` "always verify scale/visuals live" convention.)

---

## Self-Review

**Spec coverage:** The "small tint addition" scope (second visual layer + color table + modulate/tint wiring, no new art) is covered: Task 1 adds the state, Task 2 wires the color-resolution logic (reusing the existing `ProjectileVisual` tables instead of a new dict, an explicit Global Constraint), Task 3 draws it, Task 4 confirms it renders. No gaps against the scoped ask.

**Placeholder scan:** No TBD/TODO/"handle appropriately" language anywhere above; every step has literal code or an exact command. The one soft note (Task 3 Step 2) is an accurate statement about GdUnit4's real inspection limits, not a deferred implementation detail — the actual verification for that concern is fully specified in Task 4.

**Type consistency:** `_element_tint_active: bool` and `_element_tint_color: Color` are declared once in Task 1 and referenced with those exact names/types in Tasks 2 and 3. `ELEMENT_TINT_RING_RADIUS`/`_ALPHA`/`_WIDTH` are declared once in Task 1 and used with those exact names in Task 3. No renamed or drifted identifiers.
