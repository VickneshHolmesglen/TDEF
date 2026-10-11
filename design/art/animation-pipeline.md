# Animation Pipeline

Governs how and when animation/procedural motion is added to art assets in this
project. Companion doc to `design/art/art-bible.md` (visual identity/palette,
authoritative for anything this doc doesn't cover) and
`design/art/characters/hero-visual-profile.md` (Hero-specific technical budget).

Source: `production/Art Update.txt` (2026-08-17 direction) and the audit/plan
that followed it. See git history for the full audit if deeper rationale is
needed — this doc only carries the decisions, not the investigation.

## 1. Animation-Intent Decision Rule

**Animate only where it closes a currently-empty player-facing feedback loop
(hit, death, cast, arrival, state-change), or where the Art Bible already
mandates it (e.g. Hero idle). No decorative motion.**

Before adding any animation, ask: what feedback loop does this close that the
player currently gets no signal for? If the answer is "none, it would just
look nice," don't add it. This is the guardrail against "animate things merely
because they can be animated" (the directive's own words).

## 2. Per-Entity Technique Table

| Entity | Frame animation (SpriteFrames) | Cutout (Skeleton2D) | Procedural (Tween/shader) |
|---|---|---|---|
| Towers | Not needed — static geometric body reads correctly per Art Bible shape language | No — contradicts constructed/geometric shape language | Yes — primary technique. Extend `TowerInstance`'s existing `play_attack_punch()`/`play_targeting_orientation()`/`play_remove_animation()`/`set_idle_ambient()` methods, never replace them |
| Monsters | Selectively, per-monster, only where a walk/attack/death tell is worth the asset cost | Reconsider only for BOSS tier in a future pass (112px sprites justify richer motion; standard/elite at 64px do not) | Yes — primary technique for most monsters (hit-flash, death tell) |
| Hero | Deferred — long-term plan is a real-time 3D model (Art Bible's hybrid exception), a 2D rig now would be throwaway work | Deferred, same reason | Yes — idle-bob Tween satisfies the already-spec'd budget (hero-visual-profile.md: 3–4s cycle, ≤4px bounding-box drift, one micro-action per cycle) with zero new art |
| Companions | N/A — no in-world node exists yet (`CreatureInstance` is a pure-data `RefCounted`); creating one is an architecture task, not an animation one | N/A | N/A |
| Environment | Not needed for most static props | N/A | Yes, selectively — ambient shader pulse or `CPUParticles2D`, matching the tower idle-ambient precedent. Most environment art stays static per Art Bible P2 (Precious, not Epic) |
| UI | N/A | N/A | Yes — extend the existing `mission_hud.gd` Tween idiom (5 `create_tween()` sites) into files that lack it (e.g. `planning_cluster.gd`) rather than inventing a new pattern |

**Integration principle:** every addition is a new sibling method on an
existing script (e.g. `play_attack_punch()` → add `play_charge_up()`) — no
existing method signatures change, no scenes get restructured. No destructive
refactor.

## 3. Plugin Evaluation (evaluated 2026-08-17, do not re-litigate without new evidence)

| Plugin | Verdict | Why |
|---|---|---|
| Importality (Aseprite→SpriteFrames automation) | Don't install yet | No Aseprite-authored source exists anywhere in this project yet; revisit only if hand-building `SpriteFrames` becomes a repeated bottleneck |
| AnimSheet (grid sprite-sheet slicer) | Don't install | Godot 4.5+'s built-in SpriteFrames editor already does grid-slice-by-frame-size natively — redundant |
| Anima (declarative animation layer) | Don't install | Competes directly with this project's own proven Tween vocabulary; a second paradigm adds cost with no offsetting benefit |
| Pixels-Prof (pixel-art shader/post pack) | Don't install | Wrong tool for painterly (not pixel-authored) art; core features (outline shaders, palette quantization) contradict Art Bible P1/P3 |

Also see `.claude/docs/technical-preferences.md`'s Forbidden Patterns /
Allowed Libraries sections, which carry this outcome forward.

## 4. Import Presets

| Asset class | Compression | Mipmaps | Notes |
|---|---|---|---|
| 2D sprites read back as pixels (terrain, props, tower layers) | Lossless | OFF | Code reads these with `get_image()` (`grid_visual.gd` blends terrain/props; `TowerInstance.painted_rect()` needs exact alpha), which a VRAM-compressed texture can't serve directly. Mipmapping would blur intentional pixel-level brushwork at distance |
| Large painted 2D art (≥256 px: menu, Sanctuary/town, hero + worn gear, tarot, UI cards, big item/monster art) | VRAM Compressed, `high_quality=true` (BPTC/BC7) | OFF | Changed 2026-10-11 (VRAM pass): ~4× smaller in VRAM, no visible artifacts on painted art at full-res inspection. New art in these classes should import the same way |
| Small 2D art (<256 px) | Lossless | OFF | Not worth compressing; the saving is negligible |
| Sprite-sheet frames (new, e.g. a monster walk-cycle) | Same as the single-sprite row matching their size | OFF | Sheets don't get different treatment just because they're animated; keep frame sizes multiples of 4 so BPTC blocks never straddle two frames |
| Hero (if/when a 3D model lands) | N/A (3D texture) | ON | Already spec'd in hero-visual-profile.md — 3D VRAM budget item, not relevant to any 2D sprite in this pass |

No project-wide `[rendering]` section exists in `project.godot`, and none is
being added by this pass — texture filtering stays at engine default.

## 5. Shader Inventory

Two shaders exist under `src/shaders/`, both additive-blend, LDR-safe:

- **`hit_flash.gdshader`** — white-pulse via a shader uniform (`flash_amount:
  float [0.0, 1.0]`), applied to monster/tower `Sprite2D`s on hit. Driven by
  the same `Tween` idiom `TowerInstance.play_attack_punch()` already
  established for `modulate`/`scale`, just routed through a shader parameter
  instead for a cleaner flash-to-white than plain `modulate` gives.
- **`dissolve.gdshader`** — threshold/noise dissolve-out, used by
  `monster_death_vfx.gd`'s dissolve sprite.

**Known gotcha (carried over from `docs/engine-reference/godot/VERSION.md`):**
`Viewport.use_hdr_2d` (required for meaningful bloom/glow in Godot 4.6's 2D
pipeline) darkens the *entire* scene as a side effect — confirmed live-tested,
not theoretical. Neither shader in this pipeline uses engine Glow or
`use_hdr_2d`; any future glow/emissive work must design around this rather
than assume `WorldEnvironment.glow_enabled` is a simple toggle.

## 6. Preserved Constraints (do not violate)

- Existing art direction/palette (`design/art/art-bible.md`) is authoritative
  and unchanged — this pipeline adds motion, it does not touch color, shape
  language, or the established diorama aesthetic.
- The manual ChatGPT generation pipeline (`CLAUDE.md`'s Asset Generation
  section) is unchanged — animation-ready source art still originates the
  same way (Claude drafts prompt → user runs ChatGPT → drops into
  `assets/source/<category>/` → Claude alpha-cuts into `assets/art/<category>/`).
  This doc only governs what happens *after* that step.
- No project-wide conversion — every addition here is scoped to a named
  entity/asset, not a blanket rule applied to a whole category.
