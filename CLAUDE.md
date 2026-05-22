# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
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
ComfyUI runs locally at http://127.0.0.1:8188
- Start: run tools\start_comfyui.bat
- Stop: run tools\stop_comfyui.bat
- API endpoint: http://127.0.0.1:8188/api
- Models location: G:\ComfyUI\models\checkpoints
- Output location: G:\ComfyUI\output

### Generating Assets
Claude can generate assets by sending prompts to the ComfyUI API.
Always start ComfyUI before attempting asset generation.
Generated assets should be moved to assets\ folder in the project.

## Generating Assets with ComfyUI
Use tools\generate_asset.py to generate game assets.

Command: python tools\generate_asset.py "prompt" "asset_name" [width] [height] [steps]

Examples:
- python tools\generate_asset.py "top down tower, stone, medieval, game asset" "stone_tower" 512 512 20
- python tools\generate_asset.py "enemy goblin sprite, top down, fantasy" "enemy_goblin" 256 256 20

Generated assets are saved to assets\ folder automatically.
ComfyUI starts automatically if not already running.
Model used: DreamShaperXL_Turbo_v2_1