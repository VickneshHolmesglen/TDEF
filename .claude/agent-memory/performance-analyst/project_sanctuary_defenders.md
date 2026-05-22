---
name: Project — Sanctuary Defenders
description: RPG Tower Defense game on Godot 4.6.2/GDScript, PC target, 60 FPS, systems-design phase
type: project
---

Sanctuary Defenders is a Hybrid RPG Tower Defense game in systems-design phase. All 9 MVP systems are designed; reviews are in progress.

**Engine:** Godot 4.6.2 / GDScript / PC (Windows/Linux/macOS via Steam/Epic)
**Target FPS:** 60 FPS (physics at 60 Hz)
**Grid:** 16x12 = 192 cells. One SPAWN cell at MVP.
**Monster scale:** 10-40 monsters per wave, 5-8 waves per mission, 5-8 monster types
**Performance budget AC-28:** 150 ACTIVE STANDARD monsters (MAX_ACTIVE_MONSTERS cap), 60 physics frames, Monster System _physics_process <= 2.0 ms/frame total
**Performance budget AC-40:** 22-monster AoE kill in one frame, total Monster System CPU <= 4.0 ms

**Why:** Performance budgets not yet fully configured in technical-preferences.md (all [TO BE CONFIGURED]). AC-28 in monster.md is the only concrete perf criterion so far.

**How to apply:** When asked to profile or analyze, reference AC-28 as the baseline. Flag that minimum spec hardware is undefined — this is a blocking gap for any real profiler run.
