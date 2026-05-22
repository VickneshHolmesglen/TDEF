---
name: Project — Sanctuary Defenders Audio Context
description: Core game facts that inform every audio design decision
type: project
---

Sanctuary Defenders is a hybrid RPG Tower Defense on a 16×12 grid (Godot 4.6.2 / GDScript).

**Why this matters for audio:** All audio specs must account for simultaneous tower fire (up to ~80 tower_attacked events/second at peak), real-time hero combat layered on top, and a grid-based spatial audio field where readability at a glance is a first-class requirement.

**Four tower archetypes:** Physical (metallic), Ranged (mechanical), Elemental (resonant/element-specific), Support (chime/warm).

**Audio design principle from Tower GDD:** "Every tower visual and audio cue must communicate a game-state fact. Effects that add visual noise without informational content are out of scope. The player is an Architect-General reading the battlefield at a glance."

**Current phase:** Systems Design — GDD authoring in progress. Audio System GDD is flagged as Full Vision tier (not yet authored). Audio specs currently live inside individual system GDDs (Tower, Monster, etc.).

**How to apply:** When reviewing system GDDs for audio specs, evaluate against the readability-first principle and the polyphony constraint of a ~20-tower field firing simultaneously alongside hero combat.
