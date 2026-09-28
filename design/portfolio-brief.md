# Portfolio Brief — for Claude working in my games project

## Who I am and what I'm aiming for

I'm moving into junior AI / software engineering roles in Australia (Junior AI Engineer, AI Solutions
Engineer, Applied AI Engineer, GenAI Developer, AI Automation Developer). My formal qualification is a
Certificate IV in Game Design & Development, so I need **visible proof of skill** rather than a degree.

The skills the job ads ask for: Python, REST APIs, SQL/databases, LLM APIs, RAG, agents, MCP,
Claude Code / Codex, Git/GitHub, Docker, cloud, AI evaluation, structured AI-assisted development.

## My main portfolio project (already built): Project Intelligence RAG

An AI assistant for software projects, in a separate folder (`G:\AIJP`). You give it a project's
design docs and source code, and ask questions like "why is the Venom Tower good against Brutes?".
It:

- finds the relevant passages (RAG: retrieval-augmented generation);
- answers using only those passages, with citations to the exact file and line range;
- refuses when the evidence isn't there, instead of making something up;
- checks whether design docs and code agree (an agent workflow with human approval);
- connects to Claude through an MCP server.

Stack: Python, FastAPI, PostgreSQL + pgvector, local models via Ollama (plus an OpenAI-compatible
API client), Docker, 601 automated tests. Its test data is a small synthetic Godot tower-defence
game called *Shardfall*, which links my game-dev background to the AI work.

What has been done recently:

1. **Honest measurement.** Ideas to improve answers were tested on question sets written before the
   code. A few helped; most didn't, and the evidence is recorded.
2. **Filling job-ad gaps.** Added support for the standard OpenAI API format ("LLM APIs").
3. **Presentation.** A README a hiring manager can read in 2 minutes, with screenshots and results.

Still to do: push it to GitHub, and write an interview cheat sheet.

## What I want from you (Claude in this games folder)

The AI project shows the AI skills. **My game projects should show the rest:** that I build and
ship real software, use AI tools in a structured way, and bring domain experience. Please look
through this folder and fill in the sections below, **at the bottom of this file**.

Rules:

- Only write what you can see in the files or git history. Do not invent features, numbers or
  dates. If something is unclear, write it as a question for me.
- Point to evidence: file paths, scene or script names, commit counts, dates.
- No secrets, keys, personal emails or private data.
- Keep it short and plain: bullet points, not essays.

### Sections to fill in

1. **Projects found.** For each game or project: name, one-line description, engine/language,
   state (prototype / playable / released), and roughly how big it is (scripts, scenes, lines).
2. **Skills shown, mapped to the job-ad list above.** For example: GDScript/Python, architecture
   (signals, state machines, autoloads), data-driven design (JSON/resources), tools or editor
   plugins, testing, Git usage, builds/exports, anything using AI or LLMs, MCP (e.g. a Godot MCP
   server), multi-agent workflows.
3. **How AI tools were used.** Signs of Claude Code / Codex use: CLAUDE.md or AGENTS.md files,
   prompts, skills, hooks, agent setups, generated assets, and what they show about working
   *with* AI in a disciplined way.
4. **Best 2-3 things to show an employer.** What is most impressive or most finished, and why.
5. **Gaps and quick wins.** Small things that would make a project presentable (README,
   screenshots, a short gameplay GIF, a playable web export, a clean repo, a licence).
6. **Talking points for interviews.** 3-5 short stories: a hard bug I solved, a design decision, a
   system I'm proud of, something I'd do differently.
7. **Questions for me.** Anything you couldn't tell from the files.

---

## Findings (Claude: write below this line)

*Compiled 2026-09-28 by reading this repo's git history, `.claude/` setup, `docs/`, `design/`, `production/`, and running exact counts against the working tree. Scope: `G:\TDef` only — I did not open `G:\Zodiac`, `G:\Zodiac-backup-*`, `G:\Zodiac-pre-art-*`, or `G:\MTD`, which sit on the same drive but are outside this repo; see the questions at the end.*

### 1. Projects found

- **Sanctuary Defenders** (this repo) — a hybrid RPG Tower Defense. Godot 4.6.2, GDScript. Public GitHub remote: `github.com/VickneshHolmesglen/TDEF`.
- **State: pre-playtest**, not released or exported to a player. The project's own sprint tracker records the two remaining Sprint 9 items (S9-01, S9-02) as human playtests not yet run (`production/session-state/active.md:201`). Most SFX/music are CC0 placeholders pending a real audio pass, and the 2D-vs-hybrid-3D presentation direction is explicitly undecided (`production/art-overhaul-status.md`).
- **Size** (counted directly, 2026-09-28):
  - `src/`: 158 `.gd` scripts, ~37,900 lines.
  - `tests/`: 289 `.gd` test files, ~51,400 lines, 2,946 `test_` functions — the test code is larger than the game code.
  - 31 `.tscn` scenes; 360 `.tres` data resources under `assets/data/`.
  - `design/` + `docs/`: 260 Markdown files, including 41 numbered ADRs (`docs/architecture/adr-*.md`), a 78-entry tech-debt register (`docs/tech-debt-register.md`), and 175 epic/story files under `production/epics/`.
  - Git: 655 commits over 74 distinct calendar days, first commit `ad540fe` ("Game Studio Agent Architecture — complete setup") through 2026-02-13 to the current date.
- The repo started from an open-source template ("Claude Code Game Studios" — see `README.md`, `LICENSE` copyright "Donchitos") and the game itself was built on top of it. That template origin still shows in a few places (see Gaps, below).

### 2. Skills shown, mapped to the job-ad list

- **GDScript** — 158 statically-typed scripts (`.claude/rules/` enforces typing and no-hardcoded-values conventions project-wide).
- **Architecture (event-driven, no direct coupling)** — a single `EventBus` autoload (`src/foundation/event_bus/event_bus.gd`) that all 18 autoload singletons (`project.godot` `[autoload]` section) and every gameplay system communicate through exclusively; documented and enforced by ADR-0001 and cross-referenced by the other 40 ADRs.
- **State machines** — explicit phase enums with defined transitions, e.g. the mission phase machine (SCOUT → WAVE_ACTIVE → INTERMISSION → MISSION_COMPLETE/DEFEAT, `src/gameplay/wave_manager.gd`) and the Hero's own phase enum (`HeroPhase` in `src/core/hero/hero.gd`).
- **Data-driven design** — 360 `.tres` Resource files drive towers, monsters, missions, equipment, skills, and audio cues; no gameplay constant is hardcoded in script (rule enforced in `.claude/rules/gameplay-code.md`).
- **Testing** — gdUnit4 framework, 289 test files / 2,946 test functions, split into `tests/unit` and `tests/integration`.
- **CI/CD** — GitHub Actions (`.github/workflows/tests.yml`) runs the full gdUnit4 suite on every push and pull request to `main`, uploading a test-results artifact.
- **Git usage** — 655 commits, trunk-based (single `main` branch), dated and scoped commit messages; git worktrees used for isolated subagent work (`.claude/worktrees/`).
- **MCP** — three configured Godot MCP servers (per project memory: a headless/general one, a live-editor one, a lightweight-reads one) plus a third-party "Godot AI" MCP addon vendored into the project (`addons/godot_ai`, `plugin.cfg` reports v3.2.5, author "Godot AI") and kept up to date (`git log -- addons/godot_ai` shows a version-bump commit, `cf502df`). This is *integrating and operating* an MCP server for live engine control, not authoring one from scratch — worth being precise about in an interview.
- **Multi-agent / structured AI-assisted development** — 49 custom subagent definitions (`.claude/agents/`, one file per specialist role) and 73 skills (`.claude/skills/`), invoked through Claude Code's Agent tool and a documented spec → plan → per-task implementer/reviewer subagent loop (the "superpowers" `subagent-driven-development` workflow), with per-plan ledgers and review packages under `.superpowers/sdd/` (not committed — gitignored working state) and specs/plans that *are* committed (`docs/superpowers/specs/`, 13 files; `docs/superpowers/plans/`, 15 files).
- **Builds** — `export_presets.cfg` defines a Windows Desktop export preset.

### 3. How AI tools were used

- `CLAUDE.md` is a real, project-specific instruction file (not the template default): it names the pinned engine version, a documented split of labor ("Qwen handles all coding tasks... Claude Sonnet handles design, architecture, planning, and coordination"), a policy for balancing work between Claude Code and Codex, and project coding standards.
- `AGENTS.md` is Codex's equivalent instruction file, present alongside `CLAUDE.md` — evidence of running two different AI coding agents against the same repo under a shared, written contract.
- `design/art/codex-art-overhaul.md` is a collaboration brief written specifically to coordinate Codex (art generation) and Claude Code (engine integration) on one shared asset pipeline, with a live status ledger (`production/art-overhaul-status.md`) tracking who claimed which work item and its state.
- `.claude/agent-memory/` holds persisted memory for 10 of the 49 defined subagents (art-director, audio-director, economy-designer, game-designer, lead-programmer, level-designer, performance-analyst, qa-lead, systems-designer, ux-designer) — meaning these were actually invoked and retained context across sessions, not just defined and left unused.
- `.claude/hooks/` runs automated hooks at session start (`session-start.sh`, `detect-gaps.sh`) that surface project state and documentation gaps without being asked.
- 41 ADRs (`docs/architecture/adr-*.md`) record the context, decision, and consequences behind each significant architectural choice made while working with Claude — a written trail, not just a diff.

### 4. Best 2-3 things to show an employer

- **The EventBus-only architecture.** One rule — every system talks only through a central event bus, never to another system directly — enforced across 18 autoloads and held for 655 commits' worth of feature growth, with a live test (`tests/unit/event_bus/event_bus_signals_test.gd`) asserting the exact signal count on the bus. The 78-entry tech-debt register with resolved dates shows problems get logged and closed, not silently patched over or ignored.
- **The two-AI-agent coordination protocol.** `design/art/codex-art-overhaul.md` + `production/art-overhaul-status.md` is concrete, dated evidence of orchestrating Claude Code and Codex against one codebase under a written contract with a live status ledger — this maps directly onto "multi-agent workflows" and "structured AI-assisted development" language in the job ads, with a paper trail to point to rather than a claim.
- **The test suite's scale and CI enforcement.** 2,946 test functions across 289 files, run automatically on every push/PR via GitHub Actions — an unusually rigorous automated-testing habit for a solo project, and one that shows up as a real, inspectable `.github/workflows/tests.yml` file rather than a claim in a resume.

### 5. Gaps and quick wins

- **`README.md` is still the open-source template's generic README** ("Claude Code Game Studios," MIT-licensed by "Donchitos"), not a Sanctuary Defenders–specific one. It has no screenshots, no gameplay description, and nothing that tells a visitor what the actual game is. This is the single highest-value quick fix before pointing anyone at the repo.
- **`LICENSE` is the template's MIT license**, copyright the template author, not you — worth a deliberate decision (keep MIT and credit the template properly in the README, or replace it) since this is a public repo.
- **No packaged/playable build or web export found in the repo** — only the Windows Desktop preset exists in `export_presets.cfg`; there's no evidence of an actual exported build checked in or linked.
- **No screenshots or gameplay GIFs in the repo.** Live screenshots from an actual running session (several were taken this session via the Godot MCP server for verification, e.g. the main menu, the mission HUD, and the Victory/Defeat outcome screen) would go a long way for a README with almost no extra work.
- Some in-game content is genuinely first-pass/placeholder right now (SFX, music, some art, the presentation-mode decision) — worth deciding what to show versus what to caption as "in progress" before this goes in front of anyone.

### 6. Talking points for interviews

- **A shader bug headless tests structurally cannot catch.** This session, a new full-screen effect shader used an invalid Godot uniform hint (`filtering_linear` instead of `filter_linear`). Every automated test passed, and three separate code reviewers signed off on the code as "valid Godot 4 GLSL" — because gdUnit4's headless runner never compiles a shader. It only showed up by actually running the game and looking at the screen (it went solid white), which is now a standing rule I follow: any new shader gets a live check, not just a test run.
- **One feature, three unrelated bugs, found only by testing the whole path.** Building a Victory/Defeat screen surfaced three separate defects that no single-file review caught: the Retry button hid itself before the retry had actually succeeded (so a failed retry left the player stuck), a defeated Hero kept auto-attacking behind the results screen because its "is the mission over" check was never wired the way the equivalent tower check was, and a UI signal-disconnect helper wasn't idempotent so it errored on the second call. None of these were visible from any one file in isolation — they only appeared once the feature was exercised end-to-end, which is why a whole-branch review happens after every feature, not just a per-file one.
- **One architecture rule paying for itself.** The entire game runs on a single constraint: no system calls another system directly, everything goes through one event bus. When a cross-cutting feature (Hero taking damage from monsters) needed to touch a dozen previously-unrelated systems, it landed as additive changes to each one instead of requiring any of them to be rewritten to know about the others.
- **"Looks handled" isn't "is handled."** Towers already stopped fighting the moment a mission ended, and it was easy to assume the Hero did the same because the two code paths looked structurally similar at a glance. They didn't — only one had the actual phase check. The fix was two lines; finding it required not trusting the assumption and checking both code paths directly.
- **What I'd do differently.** The README and LICENSE never got updated away from the framework's own defaults, months into building actual game content on top of them — an easy thing to lose track of while heads-down in systems work, and exactly the kind of first-impression gap that costs the most when someone else actually looks at the repo.

### 7. Questions for me

- `G:\Zodiac` (plus `G:\Zodiac-backup-20260825-221705` and `G:\Zodiac-pre-art-20260828-025249`) is another game project on the same drive — should that be surveyed for the portfolio too, or is this repo the only one that matters right now?
- `G:\MTD\project.godot` actually names itself `"Godot MCP"`, not a game — is that folder a stray/misnamed leftover, or a real second project worth a separate look?
- Your Desktop has two folders named `Godot Mcp` / `Godot-Mcp`, separate from this repo's vendored `addons/godot_ai` plugin (which is a third-party addon, not something built here). Did you build a custom Godot MCP server in one of those? That would be a materially stronger portfolio point ("built an MCP server") than "configured and kept a third-party one updated," which is what this repo shows on its own.
- Is `github.com/VickneshHolmesglen/TDEF` public right now? If it's going in front of anyone, the README/LICENSE gap above should probably be fixed first.
- Do you want the README's screenshots pulled from a live Godot MCP session (several were already captured this session for verification purposes), or would you rather capture your own for consistency?
