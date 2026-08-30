# Art Overhaul Completion Audit — 2026-08-31

## Scope and verdict

`design/art/codex-art-overhaul.md` is a collaboration/process brief whose
authoritative finite work queue is §0.5 plus the rows in
`production/art-overhaul-status.md`. The brief now states that the generation
backlog and every engine-integration follow-up are complete. This audit checks
that statement against the current repository rather than treating it as proof.

**Verdict: complete.** No active backlog, claim, processing wait, regeneration
blocker, or engine-wiring item remains.

## Requirement evidence

| Requirement | Current evidence | Result |
|---|---|---|
| Locked hybrid foundation and cross-medium pilot | ADR-0038 is Accepted; the pilot rows record live Vulkan and D3D12 evidence, stable 57-draw-call/56.4MB results through 195 instances, and dense-handle lifecycle verification. | Pass |
| Eight monster movement sets | Eight `CreatureAtlasMappingResource` files exist; all eight creature types have processed movement art and clip mappings. Corrective `_v2` generations and the Forest Troll idle cleanup are preserved in the tracker. | Pass |
| Boss prepare/release animation | Warlord and Rift Sentinel each use a 14-frame animset with `idle`, `walk`, `attack_prepare`, and `attack` clips. The two-layer state machine passed gdUnit4 and live Godot MCP cycle verification. | Pass |
| Monster animation budgets | Six standard/elite atlases are 97,191–206,578 bytes (all ≤256 KiB); two boss atlases are 1,068,501 and 1,252,614 bytes (both ≤2 MiB). All eight imports use BPTC/high quality with mipmaps disabled. See `art-overhaul-monster-atlas-budget-2026-08-30/report.md`. | Pass |
| Equipment and inventory art | Tracker records 36 original equipment icons, 9 alternate T3/T4 icons, 13 tower-component icons, 14 consumable/material icons, and 13 skill icons generated, alpha-checked, processed, and wired. | Pass |
| Tower modular art | Nine matched bases, nine shafts, nine named tops, six weapon crowns, and nine modular fallback pieces exist under `assets/art/towers/`. | Pass |
| Tower runtime integration and scale | `TowerInstance` selects all nine silhouette families and six weapon crowns from stable component identity. All 18 shipped blueprint foundations resolve to a named family. Composites are bottom-anchored at 64 world units with per-family mount profiles. Focused tests, capture sheets, and independent live Godot MCP placement verification passed. | Pass |
| Cannon/laser/emitter visibility | Siege cannon, railgun laser, arcane lance, storm, firestorm, and frost crowns are present, mapped, and visibly seated on representative bodies in `tower-layer-weapon-tops.png`. | Pass |
| UI/layout gaps from annotated screenshots | Skill-row overflow, gray margins, stone-frame dead space, and composition-label edge padding are all terminal `done` rows with implementation evidence. | Pass |
| Prompt reproducibility | Every prompt file cited by the tracker exists, including movement, boss attack, equipment, tower component, consumable/material, skill, and alternate-equipment batches. Prompts are also logged in `design/art/asset-generation-prompts.md`. | Pass |
| Source/processed separation | Repository search finds no `res://assets/source/` reference in `.gd`, `.tscn`, or `.tres` engine content. Runtime references remain under `assets/art/`. | Pass |
| Shared tracker currency | No real tracker row remains `backlog`, `claimed`, `generated, awaiting processing`, or `blocked`. Historical Epic 16 claim rows were reconciled to their later Complete/gated state on 2026-08-31. | Pass |

## Verification notes

- The animated-atlas optimization commit (`1795b59`) completed a pinned Godot
  4.6.2 editor reimport, headless boot, and explicit three-frame D3D12 launch
  without BPTC decode or texture errors.
- Tower integration passed 26/26 focused `TowerInstance` tests and 16/16 The
  Gap integration tests. Independent Godot MCP verification exercised real
  blueprint placement and the real `TowerInstance.configure()` path.
- Epic 16's production gate ran 2355 tests with zero errors and one known
  headless `RendererDummy` `MultiMesh` readback failure (`TD-test-007`). The
  underlying channel was independently reproduced as correct with the real
  Vulkan/Forward+ renderer.
- A fresh command-line boot attempt during this audit crashed before project
  load while Godot tried to open `user://logs`; this is an environment-level
  Windows launcher/log-path failure and does not contradict the successful
  import/D3D12 evidence from the same asset commit. No production file changed
  after that asset commit except documentation/status reconciliation.

## Completion boundary

The brief explicitly forbids inventing or mass-generating another batch when
the shared backlog is empty. Future art is new scope and must enter the tracker
as a new user-approved row; it is not an uncompleted deliverable of this audit.
