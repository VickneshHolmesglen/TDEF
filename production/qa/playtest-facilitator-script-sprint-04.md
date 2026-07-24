# Facilitator Script — Sprint 4 "The Gap" Playtest Round (S4-11)

> **Purpose**: Let the producer run all 3 sessions consistently, without needing to
> improvise what to say or what counts as evidence for each checklist item.
> **Source of the 5-item checklist**: `production/qa/qa-plan-sprint-04-2026-07-03.md`'s
> VS Validation checklist, itself sourced from the 2026-07-03 gate-check's Creative
> Director finding (`production/gate-checks/gate-check-pre-production-2026-07-03.md`).
> **Do not deviate from this checklist's wording** — it is the literal Acceptance
> Criteria of `production/stories/foundation/s4-11-playtest-round.md`.

---

## Session Roster Requirement

3 sessions total. At least one playtester must have **zero prior context** on the
project (never seen the game, never talked to the dev team about it). At least one
should be an "experienced" player (has played tower-defense or similar games before,
even if new to this one). This mix is required by the checklist's "without developer
guidance" condition — a playtester who already knows the plan cannot test whether the
game teaches it.

---

## Before the Session — Setup Checklist

- [ ] Launch `src/gameplay/missions/the_gap/the_gap.tscn` fresh (not mid-session state from a prior test)
- [ ] Confirm `debug_controls_enabled` is **unchecked/false** on the scene's root node in the Inspector (hides the K-key QA-only debug-kill control — a real playtester should never see or trigger it; see the_gap.gd's class doc comment, deviation #5)
- [ ] Have a stopwatch or visible clock ready — the "first 2 minutes" checklist item requires timing, not a guess after the fact
- [ ] Have this document and the report template (`production/playtests/sprint-04-the-gap-playtest.md`) open side-by-side, ready to fill in live or immediately after

---

## What to Say Before Starting (verbatim, do not add plan-revealing detail)

> "This is an early build of a tower-defense game. I'm going to ask you to just play
> it and think out loud if that's comfortable for you. I can't answer questions about
> how to play — figuring that out is exactly what I'm here to observe. Let me know
> when you feel like you understand what to do, and let me know how it feels to play.
> There's no way to 'lose' this session — any reaction you have is useful data."

## What NOT to Say (this would contaminate the "without developer guidance" requirement)

- Do not explain that towers cost gold, or where the gold total is shown
- Do not explain what SPACE or left-click do — if they don't discover it, that itself is the finding
- Do not explain the wave/phase cycle (Scout → Pre-Wave → Wave Active → Intermission)
- Do not react visibly (relief, disappointment) to their choices — note it silently instead
- Do not intervene if they seem "stuck" for under 2 minutes — let the confusion play out and note when/if they ask for help

---

## During the Session — What to Observe, Mapped to the 5 Checklist Items

### 1. "A human played through the core loop without developer guidance"
Observe: did they reach at least one full wave clear (or a DEFEAT) without you
explaining a mechanic to them? Note the exact moment (if any) you had to intervene,
and what specifically confused them at that point.

### 2. "The game communicated what to do within the first 2 minutes of play"
Start the stopwatch the moment the mission scene appears on screen (after the 1-second
auto-launch delay). Note the timestamp at which the player: (a) places their first
tower, and (b) presses SPACE to ready up. If either takes longer than 2 minutes, or
doesn't happen without a prompt, this item is a **NO** for that session — write down
exactly what they were doing/thinking during that time (their think-aloud commentary
is the evidence here).

### 3. "No critical 'fun blocker' bugs were found"
A "fun blocker" is a bug that stops or meaningfully derails play — not a visual
placeholder or a missing polish item (see the Known Rough Edges list below; those are
pre-triaged as NOT fun-blockers). Log anything else that breaks the session, freezes
input, or produces an obviously-wrong game state.

### 4. "The core mechanic (tower + hero covering the gap) felt good to interact with"
This is a subjective judgment call by the playtester — ask directly after their first
wave clear or DEFEAT: *"How did placing towers and watching the hero fight feel?"*
Write down their words, not your interpretation of their words.

### 5. "At least one playtester independently described the 'vindication beat'
experience (Pillar 1) without being prompted"
Per `design/gdd/game-pillars.md` Pillar 1 (Mastery-as-Vindication): the target feeling
is *"the moment when the plan works — when the hero covers the gap the towers
couldn't... the satisfaction of being right,"* not raw power or luck. **Do not ask
about this directly or explain the pillar to the playtester** — that would prompt
them, which invalidates the checklist's "independently" requirement. Instead, listen
for unprompted language in their think-aloud or post-session reaction that matches
this shape (e.g., "oh nice, I put the tower there because I figured the hero couldn't
cover that corner" or "I knew that gap was going to be a problem and I was right").
Only ONE of the 3 sessions needs to produce this for the checklist item to pass
overall — note it precisely if/when it happens, quoting their words.

---

## Known Rough Edges — Tell the Playtester Nothing, But Don't Log These as New Bugs

These are already-documented, tracked gaps in the current build. If a playtester
reacts to one of these, note their reaction (it may still be useful UX feedback) but
do **not** write it up as a newly-discovered bug — it's known and already tracked:

- **No real Mission HUD** — the on-screen HUD (phase/wave/timer labels) is scaffolding-only, not the real Skeleton-status design (tracked: Mission HUD is still Status: Skeleton in `design/gdd/systems-index.md`)
- **All Hero/monster visuals are placeholder `ColorRect`s** — no real art exists yet; monsters are colored squares, Hero has no sprite
- **Tower placement is a single hardcoded blueprint** (`archer`) with debug-seeded gold (500) — no real economy, tower shop, or multiple tower types yet
- **The mission auto-launches** after a 1-second delay — there is no Mission Select screen yet (tracked: Not Started in `design/gdd/systems-index.md`)

If a playtester's confusion or reaction is clearly *about* one of these documented gaps
specifically (e.g., "why does this monster look like a red square?"), note it under a
separate "expected, already-tracked" section in the report rather than the Bugs table
— it's signal for prioritization, not a new find.

---

## After the Session

1. Fill in that session's block in `production/playtests/sprint-04-the-gap-playtest.md` immediately — memory of a specific play session degrades fast; don't batch this across all 3 sessions from memory later
2. Reset `debug_controls_enabled` back to its default (false) if you toggled it for your own testing between sessions
3. If a genuine fun-blocker bug was found, also file it via `/bug-report` per the game-studio's normal process — the playtest report and the bug tracker are not substitutes for each other
