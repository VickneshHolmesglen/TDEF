# 3D Towers — Design

Date: 2026-11-07
Status: Draft, awaiting user approval
Pilot: `tools/asset-pipeline/blender/tower_kit.py`, commit 807fdf92

## 1. Intent

The game is moving from the HD-2D look (2D sprite units in a 2D-painted world
with 3D grass and trees, ADR-0042) to a 3D game. The user decided the order on
2026-11-07:

1. **3D towers** — this document.
2. Real 3D terrain (cliffs, sunken paths, ramps) — separate design later.
3. 3D hero and monsters (rigged, animated) — separate design later.

Why towers first: Claude Code can now model in Blender (MCP, Blender 5.1), and
the 2026-11-06 pilot showed a live 3D tower in The Gap fits the world's light
and shadow better than painted sprites. Towers are hard-surface pieces, which
Claude models well; units come later because rigging and animation are the
big risk.

What the user wants a 3D tower to do that a sprite can't:

- **Turn to aim.** The crown swings to face its target and follows it.
- **Keep watch.** With no valid target, the crown keeps rotating slowly, "like
  it's keeping watch, like a sentry" (user's words, describing the pilot cannon).
- **Every top moves when idle, in its own way.** Weapon crowns sweep like a
  turret; something like a mage tower's crystal spins instead. "We can fine-tune
  the specifics later" — so motion must be per-piece data, not code.
- **3D in the menus too**, slowly rotating.

## 2. Decisions

### Made by the user

| Topic | Decision |
|---|---|
| Camera | Keep today's fixed, tilted, orthographic top-down view (Hd2dScenery camera, 50° pitch). No zoom/rotate changes. |
| End state for units | Hero and monsters become 3D models eventually (project 3). |
| Terrain | Real 3D terrain eventually (project 2). Not in this project. |
| Tower look | **Smooth stylized 3D**, live in the scenery world with real shadows (picked 2026-11-07 after a side-by-side with a pixelated render in The Gap). |
| Aim behaviour | Crown turns to the target; slow sentry sweep when there is no target. |
| Idle motion | Every top has one; style per piece, tuned later. |
| Menus | 3D models, slowly rotating. |
| Sprites over towers | Fine for now: 2D hero and monsters always draw on top of 3D towers (no depth sorting) until units go 3D in project 3. Don't pull unit billboards forward. |

### Builder's calls (Claude's, can be overruled)

- **Aiming is visual only.** Towers fire exactly as they do today, even while
  the crown is still turning. Making fire wait for aim changes combat balance
  and is a separate decision.
- **Keep the 2D path as a fallback** until every piece has a model. During the
  rollout, a tower whose pieces aren't modelled yet renders exactly as today.
- **Keep TowerInstance's public API.** Callers (mission_scene.gd, the_gap.gd)
  keep calling the same methods; only TowerInstance's internals change.
- **Overlays stay 2D** (rank badge, perk badge, HP bars, idle-ambient particles,
  damage numbers), positioned from the 3D model's height on screen.
- **Seat heights come from the models**, not from a table. Each Base and Shaft
  glb carries an empty node named `Seat`; the next piece stands on it. This
  replaces `LAYER_SEAT_FRACTIONS` for 3D, and adaptor caps aren't needed (a
  narrower shaft sitting on a wider base looks right in 3D).
- **Menu gallery icons are static renders** of the 3D pieces (cheap, 27+ of
  them on screen); only the assembled-tower preview is a live rotating model.
- **The build-panel icons and the placement ghost stay 2D for now** (they use
  `ARCHETYPE_TEXTURES`); they are small and get revisited with project 2/3.
- The 3D world renders underneath the 2D canvas (ADR-0042), so the 2D hero
  and monsters draw on top of 3D towers even when walking behind one. The user
  accepted this until units go 3D (see table above).

## 3. Goals, non-goals, anti-goals

**Goals**
- All 33 tower pieces as 3D models: 9 bases, 9 shafts, 9 tops (families
  hexplank, octagon, round, scalloped, square, stonemound, stump, tiered,
  triangle) and 6 weapon crowns (siege, railgun, arcane, storm, firestorm,
  frost). Plus the modular fallback set if still referenced.
- Placed towers in every mission render as live 3D models in the Hd2dScenery
  world, aiming and keeping watch.
- Inventory → Tower Component tab: gallery icons rendered from the 3D models;
  assembly preview shows the live 3D stack, slowly turning.
- An ADR recording the move to 3D (towers first), superseding the
  2026-11-05 HD-2D lock note in ADR-0042.

**Non-goals**
- Terrain, hero, monsters, camera changes.
- Changing targeting, fire rate, range or any combat number.
- Projectile art (projectiles may need a spawn-height offset; see §5.6).

**Anti-goals (would count as failure even if it technically works)**
- Towers turning in lockstep, or crowns snapping instantly between angles.
- A tower that visibly drifts off its grid cell, or HUD bars/badges that float
  away from their tower.
- Deleting the painted 2D art before every piece has a working 3D model.
- A lot of new per-tower GPU cost (one SubViewport per placed tower is out).

## 4. Constraints

- Godot 4.6.2, GDScript, typed. Project conventions in
  `.claude/docs/coding-standards.md` and `technical-preferences.md`.
- 3D under the 2D canvas via Hd2dScenery: every `VisualInstance3D` must be on
  `Hd2dScenery.RENDER_LAYER` or the scenery camera won't see it, and the
  scenery sun must stay on that layer (VERSION.md gotcha).
- `Hd2dScenery.to_world(p2d, height)` maps a 2D gameplay position to 3D.
  Objects themselves are not stretched; only ground positions are.
- 60 FPS budget; 200 draw calls. A tower is ~30–60 small meshes in the pilot;
  merge each piece into one mesh per material on export (§5.5).
- Never `#` comments inside `.tscn`/`.tres` blocks (VERSION.md).
- New `class_name` files need the editor-mode class-cache rebuild before
  headless runs (`Godot.exe --headless --editor --path . --quit`); same for
  new glb/PNG imports.
- Engine-referenced assets live in `assets/art/`; raw renders/sources in
  `assets/source/`.

## 5. How it works

### 5.1 Pieces and assembly

- Assets: `assets/art/towers3d/base_<family>.glb`, `shaft_<family>.glb`,
  `top_<family>.glb`, `weapon_<key>.glb`. Each piece stands on its own origin,
  front facing the camera, scaled so a base is about one grid cell wide.
- Bases and shafts export a `Seat` empty at their top face. The assembler
  stacks Base → Shaft (at the base's Seat) → crown (at the shaft's Seat).
- A crown is a weapon crown when the weapon component maps to one (same
  `_resolve_weapon_top_key()` rules as today), otherwise the family's top.

### 5.2 TowerModel3D (new)

A `Node3D` scene/class that owns one assembled tower:

- `build(foundation shape, crown key)` — loads and stacks the pieces, sets
  every `VisualInstance3D` to `Hd2dScenery.RENDER_LAYER`.
- `crown` pivot node — the only thing that turns.
- Aim state machine (§5.3), hit flash, attack punch, remove animation.
- Reports its on-screen height in 2D px so TowerInstance can place overlays.

### 5.3 Aim and idle motion

Per-crown motion data lives in a small Resource (`TowerCrownMotion`, one per
crown key, defaults for anything missing):

| Field | Meaning | Default |
|---|---|---|
| `idle_mode` | `SWEEP` (turn the crown), `SPIN` (spin a named child like a crystal), `NONE` | `SWEEP` |
| `idle_speed_deg` | degrees/second when idle | 60 (one turn per 6 s, like the pilot) |
| `aims` | turns toward targets | true |
| `track_speed_deg` | max turn rate while tracking | 270 |
| `spin_node` | child node name to spin for `SPIN` | "" |

Behaviour:

- **Idle:** rotate at `idle_speed_deg`. Each tower picks a random start angle
  and a ±20% speed variation at placement so neighbours never move in lockstep.
- **Tracking:** when `play_targeting_orientation()` arrives, the crown turns
  toward the target at most `track_speed_deg`, shortest way round, and keeps
  following that target between shots.
- **Lost target:** if no aim event arrives for a short hold (≈ one attack
  interval + 0.5 s), or the target is freed, go back to idle sweeping from the
  current angle — no jump.
- To follow a moving target between shots, `play_targeting_orientation()`
  gains an optional `target: Node2D` argument (callers pass the monster node);
  the position-only form keeps working.
- Yaw from 2D: the direction `target_pos - tower_pos` in the gameplay plane maps
  to a yaw about the 3D up axis (2D +y = 3D +z after `to_world`).

### 5.4 TowerInstance changes

- New `set_scenery(scenery: Hd2dScenery)` (called by mission_scene.gd and
  the_gap.gd before `configure()`).
- In `configure()`: if a scenery is set **and** all pieces for this tower have
  models, create a `TowerModel3D` under the scenery at
  `scenery.to_world(global_position)`, hide the 2D layer sprites, and route
  `play_targeting_orientation`, `play_attack_punch`, `play_hit_flash`,
  `play_remove_animation` to it. Otherwise behave exactly as today.
- The 3D model is freed with the TowerInstance (`_exit_tree`), and follows it
  if it moves.
- `get_layered_visual_bounds()` returns a rect built from the model's screen
  height, so badges/HP bars/particles stay anchored.

### 5.5 Asset pipeline

- Extend `tower_kit.py` from the pilot to all 9 families and 6 crowns. Bases
  and shafts share one parametric generator (footprint polygon + trims); tops
  and crowns are modelled individually.
- Export: one glb per piece, modifiers applied, sub-objects joined per
  material, the `Seat` empty included, image textures (no procedural nodes).
- Also render each piece to a static icon PNG for the menu galleries
  (`assets/art/towers3d/icons/`).
- Materials stay the shared palette (stone, light stone, dark stone, wood,
  brass, gold, iron) so all pieces match.

### 5.6 Effects mapping

| Today (2D) | 3D |
|---|---|
| Hit flash shader on sprites | Brief emission/white tint on the model's materials (one shared override, tweened) |
| Attack punch (scale pulse + modulate) | Short scale pulse on the crown |
| Targeting orientation glow | Kept as a 2D glow at the crown's screen position, plus the crown turning |
| Remove animation | Model sinks/shrinks then frees |
| Destroy VFX | Unchanged (2D particles), model freed |
| Idle ambient particles | Unchanged, positioned at the crown's screen height |
| Projectile spawn | From the tower position as today, raised to crown height on screen if it looks wrong |

### 5.7 Menus

- **Gallery icons** (Bases/Shafts/Tops grids) switch to the 3D icon renders.
- **Assembly preview**: a `SubViewportContainer` + `SubViewport` with its own
  small 3D world (camera at the mission pitch, one light), holding a
  `TowerModel3D` built from the picked pieces, turning slowly as a whole
  (turntable). It replaces `_draw_tower_stack_preview()`. One viewport only.

### 5.8 Intricacy grows with level (added 2026-11-07, user request)

"The towers design should get more and more intricate the higher its level
gets upgraded." The user chose **both levels, layered**:

- **Tier (Foundation tier 1–4, fixed for the mission) sets base grandeur.**
  Every piece is modelled once, with additive detail groups exported as child
  nodes named `Tier2`, `Tier3`, `Tier4`. A tower shows every group up to its
  tier. One glb per piece, not four.
  Intended progression (builder tunes the specifics per family):
  - T1: plain stone/wood, simple trims (the pilot pieces are T1).
  - T2: metal banding, studs, extra trim courses.
  - T3: carved panels, buttresses/crenellations, banners or spikes.
  - T4: gold filigree, ornate cornices, glowing runes or crystals.
  The bases/shafts generator adds these as parameters; tops/crowns get them
  modelled per piece.
- **Veterancy rank (0–3, earned in the mission) adds flourishes on top.**
  A shared kit that fits every tower, attached to anchor points the pieces
  already have (`Seat` nodes, crown pivot): rank 1 a pennant, rank 2 a crest
  on the shaft, rank 3 a laurel/glow ring at the crown. Each appears with a
  short pop when `set_rank()` raises the rank. The 2D chevrons stay as well,
  for readability on a busy field (builder's call).
- **Plumbing:** `configure()` gains the foundation tier (callers already hold
  `state.foundation.tier`). `TowerModel3D.set_tier(t)` / `set_rank(r)` toggle
  group visibility.
- **Menus:** the assembly preview shows the picked foundation's tier detail.
  Rank flourishes are mission-only.
- **Rollout:** tier groups are part of each piece's batch; the veterancy kit is
  its own small batch after the first pieces work.

## 6. Order of work

1. **Look comparison (throwaway spike).** In The Gap, the pilot tower drawn
   two ways side by side: smooth (as now) and pixelated (rendered at low
   resolution and scaled up with hard pixels). User picks. The pick sets the
   rendering approach for §5.2; nothing else depends on it.
2. ADR-0043 + doc updates (ADR-0042 lock note, `design/art/3d-art-pipeline.md`,
   art bible lock note, CLAUDE.md asset-generation note, memory).
3. `TowerModel3D` + `TowerCrownMotion` + TowerInstance wiring, using the pilot's
   octagon pieces and siege crown. Live-check in The Gap.
4. Generate the remaining pieces in batches (bases+shafts first, then tops,
   then crowns), checking each batch live.
5. Menus: icons + live preview.
6. Retire the 2D layered path once every piece has a model (separate approval;
   painted art stays in `assets/source/` either way).

## 7. Testing

- Unit: aim maths (2D direction → yaw; shortest-way turn with a rate cap;
  idle → track → idle without a jump), crown-motion defaults, seat stacking
  from `Seat` nodes, fallback chosen when a piece has no model.
- Existing `tower_instance_test.gd`, the two mission-scene tests and the
  tower-build-panel test must still pass (they cover the 2D fallback).
- Live (Godot MCP): place towers in The Gap, watch idle sweep, start a wave,
  confirm tracking, rank badge and HP bar alignment, remove/destroy, and the
  Inventory preview.

## 8. Left to the builder

- Exact track speed, hold time, pulse sizes, the px-per-unit scale (pilot used
  38–45), and the light/tint values for the menu viewport.
- How pieces are cached and instanced (e.g. load each glb once and duplicate).
- The pixelation technique if the user picks pixelated, within the "no
  SubViewport per tower" anti-goal.
