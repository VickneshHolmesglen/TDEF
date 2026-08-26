# Prototype: 3D Tower Defense Kit Spike

<!-- PROTOTYPE — NOT FOR PRODUCTION -->
<!-- Reverse-documented 2026-08-27 — original prototype predates a README, no
     author present to confirm intent; see "Reconstructed Intent" note below. -->

**Status**: Concluded (superseded) — findings absorbed into later, better-scoped work
**Engine**: Godot 4.6.2 / GDScript
**Risk at the time**: Low — pure exploratory spike, no production code touched

---

## Reconstructed Intent

This prototype has no commit message or design doc trail explaining its own
purpose, and predates this project's "every prototype needs a README" rule
(`.claude/rules/prototype-code.md`). This document reconstructs its likely
hypothesis from the two scene files it left behind, rather than inventing new
justification — flagged as inferred, not confirmed by the original author.

Two independent things appear to have been under test:

**1. `spike.tscn` — is a free, off-the-shelf "Tower Defense Kit" GLB asset
pack viable 3D backdrop material?**
Instances `assets/Tower Defense Models/GLB format/*.glb` — straight/crossing
path tiles, a 5-piece modular tower (base/bottom/middle/top/roof), decorative
props (tree/rocks/crystal), and a spawn marker — into one fixed-camera 3D
scene with a simple sky-blue `WorldEnvironment` and one shadow-casting
`DirectionalLight3D`. Reads as a first look at whether this kit's tile scale,
modular tower assembly, and prop dressing could plausibly serve as the
project's 3D-world backdrop.

**2. `mixed_root_check.tscn` — can a `Node2D`-rooted scene host a `Node3D`
subtree with its own `Camera3D` and have it render correctly?**
A minimal, deliberately isolated scene: `Node2D` root → `Node3D` child →
`Camera3D` + `DirectionalLight3D` + two GLB instances. This is a much
narrower, single-variable test than `spike.tscn` — it strips away everything
except the exact node-hierarchy question. That question is precisely the one
`docs/architecture/investigation-2026-08-24-hybrid-swarm-rendering.md` and
ADR-0037/ADR-0038 later formalized and answered in depth (2D/3D composite
independently in Godot's rendering model — the same fact ADR-0040 hit again
from the opposite direction: turning off `Camera2D` doesn't hide 2D content).
This spike looks like the first, informal probe of that same mechanism.

---

## Prototype Scope

**What exists:**
- `spike.tscn` — 5 ground tiles (straight/crossing), one fully-assembled
  modular tower, tree/rocks/crystal props, one spawn marker, fixed
  `Camera3D`, one `DirectionalLight3D`, sky-color `WorldEnvironment`.
- `mixed_root_check.tscn` — minimal `Node2D` root wrapping a `Node3D` subtree
  (camera, light, two GLB instances) — an isolated 2D/3D root-mixing check.

**What was never added:**
- No script — this is scene-composition only, no driver/logic code.
- No connection to any production scene, Autoload, or system.
- No documented pass/fail criteria or measurements captured at the time.

---

## How to Run

Open either `.tscn` file directly in the Godot editor and run it (F6), or via
Godot MCP: `run_project` with `scene: "prototypes/3d-tower-defense-kit-spike/spike.tscn"`
(or `mixed_root_check.tscn`), then `take_screenshot`.

No autoloads or production scene dependencies are required.

---

## Findings

**Kit viability (`spike.tscn`)**: Not carried forward. The project's actual
shipped 3D-world direction (ADR-0037/ADR-0038, Epic 15/16) reuses this exact
scene as a convenient pre-built 3D backdrop for the `hybrid-swarm-pilot`
prototype and its D3D12/Vulkan comparison pass (see
`prototypes/hybrid-swarm-pilot/README.md`) — so the kit was judged "good
enough to prototype against," but no ADR or art-bible entry ever formally
adopted these specific GLB models as final production art. Visual direction
overall remains unlocked per `design/art/codex-art-overhaul.md` §1.

**Mixed-root viability (`mixed_root_check.tscn`)**: This spike's implicit
question — can 2D and 3D content coexist under a shared root — was answered
far more rigorously later, and the answer has a real gotcha this spike would
not have surfaced on its own: 2D and 3D content composite **independently**
in Godot's rendering model. A `Node3D` subtree renders regardless of a
sibling `Camera2D`'s state, and disabling `Camera2D` does **not** hide 2D
content behind it (confirmed live via Godot MCP, ADR-0040). The project's
real mixed-2D/3D scenes (`MissionScene.tscn`, `the_gap.tscn`) now handle this
correctly via an explicit `_dynamic_visuals_root` container that
`_apply_presentation_mode()` shows/hides directly, rather than relying on
camera `current`/`enabled` state alone.

**Verdict**: Concluded — superseded, not migrated. Its one lasting
contribution is `spike.tscn` itself, reused as convenient off-the-shelf
backdrop set dressing for a later, better-scoped prototype. Per this
project's prototype conventions (`.claude/rules/prototype-code.md`), this
directory is preserved for reference and should not be extended — any new
mixed 2D/3D or asset-kit exploration belongs in a new prototype directory.
