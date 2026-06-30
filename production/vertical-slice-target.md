# Vertical Slice — Experience Target

> **Status**: Defined 2026-05-25 · **Owner**: Creative Director · **Sprint task**: S1-09
> **Purpose**: The single scripted moment the Vertical Slice must deliver. This is the
> north star that scopes the Foundation and Core epics and the bar the
> Pre-Production → Production gate evaluates against.

## The Scripted Moment — "The Gap"

A single short mission on one handcrafted map. The slice proves the **core fantasy beat**
from the game concept — *"the hero covers the gap the towers couldn't, and the wave that
seemed overwhelming collapses"* — using only systems whose architecture is already Accepted.

**Beat-by-beat:**

1. **Scout Phase (60s)** — The player places **3 towers** along the main lane. As towers
   occupy cells, the displayed monster route visibly **bends around them** (Pathfinding
   reroute). The player believes the lane is covered.
2. **Wave 1** — A modest wave enters the main lane. The towers handle it. This teaches the
   player that towers + lane coverage works, and lulls them into confidence.
3. **Intermission (30s)** — Brief reposition window. (Player may or may not adjust.)
4. **Wave 2 — the twist** — A **second spawn opens a side lane the towers do not cover.**
   Monsters pour through the gap toward the sanctuary core. The towers alone cannot stop
   the breach in time.
5. **The Vindication Beat** — The player rushes the **hero** to the gap and holds the line
   in direct combat while the towers thin the main lane. If they read it right, the wave
   **collapses** and the core survives.

This moment is intentionally small. It does **not** require Constellation, Tarot, Crafting,
Menagerie, a boss, or the Sanctuary meta-loop. It exists to answer one question: **is the
moment-to-moment loop of "place towers, then pilot the hero to cover what they miss" fun?**

## Win / Fail Conditions

| Outcome | Condition |
|---------|-----------|
| **WIN** | The sanctuary core survives through the end of Wave 2 (breach counter below the loss threshold) **and** the hero is alive. |
| **FAIL — hero down** | Hero HP reaches 0 at any point → immediate DEFEAT (hero is mandatory, per Core Rule 1). |
| **FAIL — core breached** | The sanctuary core takes **5 breaches** (monsters reaching the goal) → mission lost. |
| **Restart** | On either fail, the player restarts from Scout. No meta-progression exists in the slice, so restart is a clean reset of the mission. |

## Systems Involved

**Foundation layer (≥2 required — this moment exercises all four):**

| System | Role in the moment |
|--------|--------------------|
| **EventBus** | All cross-system signals (tower_placed, monster_spawned, monster_died, breach, hero_damage_taken) route through it — the backbone the whole slice runs on. |
| **Grid** | Tower placement + occupancy; defines the lanes and the buildable cells. |
| **Pathfinding** | The visible route reroute during Scout; monster routing down both lanes in Wave 2. |
| **Save & Persistence** | Minimal — load the handcrafted map config. (No mid-mission save in the slice.) |

**Core layer (the gameplay surface the moment proves):**

| System | Role in the moment |
|--------|--------------------|
| **Wave Manager** | Drives Scout → Wave 1 → Intermission → Wave 2 phase FSM and the two spawn scripts. |
| **Monster** | Wave spawns, movement along templates, breach detection at the goal. |
| **Tower** | Scout-phase placement (WAVE_ACTIVE block), auto-fire on the main lane. |
| **Hero** | Direct player-controlled combat — the system that delivers the vindication beat. |
| **Damage & Status** | Resolves tower hits, hero hits, and hero-taken damage. |

> **Deferred (deliberately out of slice scope):** Constellation, Tarot, Crafting, Menagerie,
> Defense Building, Inventory meta, boss encounters, the Sanctuary scene. These are validated
> in later slices once the core loop is proven fun.

## Acceptance Criteria (slice is "done")

- [ ] A human plays the moment **without developer guidance** and understands, within the
      first 2 minutes, that they place towers in Scout and control the hero in combat.
- [ ] In Wave 2, the side-lane breach is **legible** — the player can see monsters getting
      through and understands *why* (towers don't cover that lane).
- [ ] The hero can reach the gap and meaningfully affect the outcome — piloting the hero is
      the difference between win and loss, not cosmetic.
- [ ] At least one independent playtester describes the win as *"I covered the gap myself"*
      (or equivalent) — confirming the **Architect-General fantasy** lands unprompted.
- [ ] WIN and both FAIL conditions each trigger correctly and end the mission cleanly.
- [ ] The full moment runs at **≥60 FPS** with the Wave 2 monster count on the field.

## Open Questions (for slice build)

- Exact map dimensions and the two lane layouts — to be set during prototype, constrained by
  the 16×12 default grid (Grid GDD).
- Wave 2 monster count — tuned so the breach is *threatening but recoverable* by a skilled
  hero. Start point: ~12–15 monsters split across the two lanes.
- Hero move/attack tuning sufficient to make "rush the gap" feel responsive (Hero GDD / ADR-0010).
