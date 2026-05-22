---
name: Project — Sanctuary Defenders
description: Core facts about the Sanctuary Defenders game concept, systems, and design decisions made so far
type: project
---

Sanctuary Defenders is a hybrid RPG Tower Defense for PC (Steam/Epic), built in Godot 4.6.2 / GDScript.

**Why:** Indie project by Vicknesh. Architecture is framework-first, event-driven (central event bus).

**How to apply:** All design recommendations must be implementable in GDScript, consistent with the 9-system architecture, and respect the event-bus constraint (no direct system-to-system coupling).

## Core Concept
- Player controls a direct-action hero AND places modular component-based towers
- Towers have 4 slots: foundation, weapon, focus, power
- Towers form constellation patterns for synergy bonuses
- 9 systems: Hero, Inventory, Monster, Tower, Defense Building, Crafting, Menagerie, Tarot, Constellation

## Player Fantasy
- Architect-General (mastery/command) + Endless Theorist (cross-system synergy discovery)
- Sanctuary is visual progress + build choice hub

## Design Decisions (as of 2026-04-19)
- Detailed Design section of game-concept.md being authored
- Scout phase: 60 seconds pre-wave placement window
- Intermissions: 20 seconds between waves, 1 free tower reposition allowed
- 5–8 waves per mission; wave 4 = sub-boss, final wave = mission boss
- 10-second warning countdown before each wave
- Hero deals 150% damage to elite/boss enemies (makes hero mandatory)
- Resource on defeat: 50% shard retention (soft difficulty — flagged for user decision)
- Micro-loop systems: Hero, Tower, Monster (all primary); Constellation, Tarot (secondary)
- Crafting, Menagerie, Defense Building: NONE during missions — deliberate design choice
- Monster drops feed the meta-loop economy (primary faucet)
