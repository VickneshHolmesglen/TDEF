---
name: Project: Sanctuary Defenders — Visual Identity Context
description: Core visual tone, current art bible status, and hero visual spec decisions made in the first AD session
type: project
---

Sanctuary Defenders is a hybrid RPG Tower Defense, top-down 2D, PC/Steam, Godot 4.6.2.

Visual tone from game-concept.md: "Mastery-as-vindication" — strategic and deliberate, not chaotic. The hero is a commander-general who leads from the front. Every visual effect must communicate information, not just look cool.

**Why:** The design pillar ("Architect-General") demands that VFX serve readability over spectacle. Any effect that adds noise without information value is wrong for the game.

**How to apply:** When reviewing or proposing VFX, always ask "what information does this communicate to the player?" before asking "does this look good?" Reject purely decorative effects.

## Art Bible Status
No art bible exists as of 2026-04-21. All color palette, silhouette language, and class accent color decisions are deferred until the art bible is authored. A consolidated list of art-bible-dependent decisions was documented in the Hero System visual/audio requirements.

## Hero Visual Identity Decisions (2026-04-21)
- Hero readability via: upright bipedal silhouette + constant rim highlight + dedicated z-sort tier (hero = monsters + 1)
- Class identity via: palette shift (shader) + persistent world-space class badge icon — NOT silhouette change
- Silhouette change deferred until class count known; revisit post-art-bible
- Hero sprite: 64×64 px canvas, 4-frame idle at 5 FPS, 3/4 top-down perspective
- Low HP state: red vignette pulse at 70 BPM + persistent 5–8% red tint on hero sprite
- Death: noise-dissolve on hero sprite + full-screen desaturate to grayscale

## Key Color Recommendations (pending art bible confirmation)
- Crit accent: warm yellow (not orange — orange is fire; not red — red is damage-taken)
- Elite hit: silver/cold-white (armor-piercing feel)
- Tower Affinity aura: warm gold
- Healing: green (universal genre convention, use consistently)
- Hero rim highlight: off-white or pale gold (distinct from enemy-type feedback colors)
