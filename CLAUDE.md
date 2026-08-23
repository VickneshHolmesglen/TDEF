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

## Coding Standards

See `.claude/docs/coding-standards.md` — read when writing code, authoring GDDs, or setting up tests.

## Context Management

See `.claude/docs/context-management.md` — read when managing long sessions, compacting, or recovering from a crash.

## Asset Generation

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