---
name: Project — Sanctuary Defenders UX Context
description: UX-relevant facts about Sanctuary Defenders game design and platform constraints
type: project
---

Game: Sanctuary Defenders — Hybrid RPG Tower Defense, Godot 4.6.2, GDScript.
Platform: PC (Windows/Linux/macOS), Steam/Epic. Primary input: Keyboard/Mouse. Gamepad: partial/optional.
Grid: 16x12. Up to 40 active monsters per wave. 5-8 waves per mission, 15-25 min sessions.
Monster tiers: STANDARD, ELITE, BOSS. BOSS is unique named entity per wave.
No monster selection/inspection UI at MVP — all monster state communicated visually.
Mission HUD GDD not yet written as of 2026-04-23 (Monster GDD is a forward spec source for it).
BOSS HP bar design is an open unresolved flag (OQ-5) — three options pending decision.

**Why:** Informs every UX review and HUD forward-spec. Game pillars include "The Fight Must Be Worth It" and "Placement is the Puzzle."

**How to apply:** All UX recommendations must account for the 16x12 grid density, up to 40 on-screen entities, and K/M-first interaction. No hover-only interactions allowed.
