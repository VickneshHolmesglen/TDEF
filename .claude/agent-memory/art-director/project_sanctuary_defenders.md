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
`design/art/art-bible.md` is now complete (all 9 sections, last updated 2026-07-15) — no longer pending. It defines a named-hue palette system (Sanctum Amber, Fieldstone Grey, Parchment Cream, Scout Blue, Verdant Green, Threat Crimson, Herald Gold, Boss Purple) with HSL+hex anchors, a binding semantic color vocabulary (Section 4.2), and a separate UI-only palette (Section 4.4) that must never leak into world space. Consult this file directly for current values rather than the superseded recommendations below.

## Boss Purple (added 2026-07-15)
Formalized "Boss Purple" as a named color with hex anchors: full-saturation `#7E2EB8` (HSL 275,60%,45%) and a desaturated marker variant `#6B3B8F` (HSL 275,45%,40%). Purple was already reserved in the bible as "boss escalation only" but had no hex value — only a qualitative description and one placeholder value on Boss surface treatment. Exactly two sanctioned uses now exist: (1) WAVE_ACTIVE ambient purple push / Boss surface trace (full-saturation), (2) Mission HUD's PC-5 boss-lane telegraph marker shown during SCOUT/INTERMISSION (desaturated variant) — resolves `design/gdd/mission-hud.md`'s PC-5 open color decision, closing Tower GDD OQ-11.

**Why:** The bible's own WAVE_ACTIVE HUD addendum already anticipated a HUD element "rhyming" with the ambient push and required it to fire as the *primary* signal, not an echo — PC-5's marker (rendered well before WAVE_ACTIVE) satisfies that by construction. Reusing purple avoided inventing a fifth threat-adjacent hue and reinforced rather than diluted purple's "boss" scarcity, since both uses are boss-specific and differ only in intensity (information register vs. dread register).

**How to apply:** Any future boss-related visual (new UI element, VFX, tooltip, etc.) should default to checking whether it fits one of Boss Purple's two existing intensity tiers before proposing a new hue — a third purple use requires an explicit Art Director decision per the bible's own constraint.

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
