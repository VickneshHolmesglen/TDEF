# Codex Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Codex subagents.
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

@.Codex/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.Codex/docs/technical-preferences.md

## Coordination Rules

See `.Codex/docs/coordination-rules.md` — read when coordinating agents, assigning model tiers, or running parallel tasks.

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
**Codex Sonnet** handles design, architecture, planning, and coordination.

When a task involves writing actual game code, produce Qwen-ready specs and
implementation blueprints — do not author GDScript directly unless the user
explicitly asks Codex to do so.

## Coding Standards

See `.Codex/docs/coding-standards.md` — read when writing code, authoring GDDs, or setting up tests.

## Context Management

See `.Codex/docs/context-management.md` — read when managing long sessions, compacting, or recovering from a crash.

## Asset Generation
Local ComfyUI generation is not used for this project (removed — hard CUDA/ZLUDA
driver failure, never resolved). All asset generation is manual via ChatGPT:

1. Codex drafts the generation prompt(s) — log them in
   `design/art/asset-generation-prompts.md` with the reasoning/constraint mapping,
   matching the art bible.
2. User runs the prompt through ChatGPT and downloads the resulting image(s).
3. User drops the raw sheet into `assets/source/<category>/` (snake_case filename).
4. Codex slices/alpha-cuts/processes it into `assets/art/<category>/` and wires
   it into the project. See `design/art/asset-generation-prompts.md` for the
   established alpha-cut technique (color-distance threshold for high-contrast
   sheets, connected-component flood-fill from the canvas border for low-contrast/
   dark-material sheets).

`assets/source/` holds raw generated sheets only — nothing loads these directly.
`assets/art/` is the only engine-referenced asset tree.