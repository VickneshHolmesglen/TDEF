# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.6.2
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

See `.claude/docs/coordination-rules.md` — read when coordinating agents, assigning model tiers, or running parallel tasks.

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **Returning session?** Read `production/session-state/active.md` first — it has
> the current task, completed work, key decisions, and next steps.

## Project State

- **Game**: Sanctuary Defenders — Hybrid RPG Tower Defense
- **Session state**: `production/session-state/active.md` ← authoritative source for current phase, completed work, and next steps
- **Systems index**: `design/gdd/systems-index.md` ← per-system design and review status

## LLM Usage Split

**Qwen** handles all coding tasks (GDScript implementation, scene setup, shaders).
**Claude Sonnet** handles design, architecture, planning, and coordination.

When a task involves writing actual game code, produce Qwen-ready specs and
implementation blueprints — do not author GDScript directly unless the user
explicitly asks Claude to do so.

## Codex Workload Balance

This project runs Claude Code and Codex side by side. Actively look for work
to route to Codex instead of defaulting everything to Claude Code — the goal
is both agents carrying a comparable share of the workload, not Claude Code
doing everything while Codex sits idle. Codex's proven strength is art
generation (drafting prompts, running image generation, dropping raw output
into `assets/source/<category>/` — see `design/art/codex-art-overhaul.md`);
when scoping a session, check whether any pending backlog/content work is
art-shaped and hand it to Codex rather than picking it up directly. This does
NOT loosen the existing role boundary in `design/art/codex-art-overhaul.md`
§3 — Codex drafts/generates, Claude Code processes/wires/writes engine code.
If Codex has written GDScript or engine/scene code directly, flag it to the
user rather than silently accepting or reverting it.

## Coding Standards

See `.claude/docs/coding-standards.md` — read when writing code, authoring GDDs, or setting up tests.

## Context Management

See `.claude/docs/context-management.md` — read when managing long sessions, compacting, or recovering from a crash.

## Asset Generation

**2026-10-11 update -- Codex no longer generates art; Claude Code authors
assets itself**, procedurally (`tools/asset-pipeline/hd2d/`). Target look is
HD-2D (`docs/images/graphics.PNG`): 2D painted ground with 3D grass, trees
and props, see ADR-0042. The Codex-generates / Claude-processes split below is
historical for new assets.

**Active art overhaul (2026-08-23 onward)**: read
`design/art/codex-art-overhaul.md` — it's written for Codex but Claude Code is
equally bound by it. Short version: Codex now generates art (drafts prompts,
runs image generation, drops raw output into `assets/source/<category>/`);
Claude Code processes it (alpha-cut/slice/import/wire into the engine, per the
existing technique below). Both agents read and update
`production/art-overhaul-status.md` before/after every item so work never
collides — check it before picking up any art task. **Visual direction is not
locked yet** (see that document's §1) — do not treat any generated art as
final/ship-ready until the user confirms a direction.

Local ComfyUI generation is not used for this project (removed — hard CUDA/ZLUDA
driver failure, never resolved). Alpha-cut technique: color-distance threshold
for high-contrast sheets, connected-component flood-fill from the canvas
border for low-contrast/dark-material sheets — full detail and hard-won
gotchas in `design/art/codex-art-overhaul.md` §5.2 and
`design/art/asset-generation-prompts.md`.

`assets/source/` holds raw generated sheets only — nothing loads these directly.
`assets/art/` is the only engine-referenced asset tree.

Animation-ready source art (SpriteFrames, procedural Tween/shader polish) is
planned per `design/art/animation-pipeline.md` — read that doc before adding
any `AnimatedSprite2D`, `Skeleton2D`, `AnimationPlayer`, or `.gdshader` file.