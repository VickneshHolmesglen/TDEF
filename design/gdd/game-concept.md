# Sanctuary Defenders — Game Concept

> **Status**: In Design
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-07-15
> **Implements Pillar**: All pillars (root vision document)
> **Revision (2026-07-15)**: `/review-all-gdds` game-design-holism pass found the "Wave Difficulty Scaling" section mislabeled `wave_reward_scalar` (an economy-only formula owned by `wave-manager.md` Formula 1) as combat difficulty — actual combat threat uses a separate linear formula (`monster.md` Formula 1). Renamed to "Wave Reward Scalar" throughout (formula, variable names, Tuning Knobs row) and cross-referenced `monster.md` Formula 1 as the real difficulty reference. The registry renamed the underlying constant on 2026-04-26 for the same reason; this document had not caught up until now.

## Summary

[To be designed]

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None (root)`

## Overview

Sanctuary Defenders is a hybrid RPG Tower Defense in which the player simultaneously controls a direct-action hero and builds a strategic network of modular towers to defend a sanctified zone against escalating monster waves. Between missions, players invest earned resources into their hero's equipment, craft new tower components from materials dropped by monsters and harvested from a creature menagerie, and build a Tarot deck of cards that modifies each mission's run parameters. Towers are composed from four interchangeable component slots (foundation, weapon, focus, power) and can unlock constellation bonuses when placed in geometric patterns. The game is designed around a framework-first, event-driven architecture: all nine major systems communicate through a central event bus, enabling deep cross-system synergies — hero equipment affecting tower stats, creature happiness affecting crafting material quality, Tarot cards altering wave composition — without creating brittle direct dependencies between systems.

## Player Fantasy

**The Architect-General + Endless Theorist**

In each mission, the player is a commander who leads from the front — controlling their hero directly while a network of towers they designed and placed fights alongside them. The peak moment is the one where the plan works: the hero covers the gap the towers couldn't, the constellation bonus activates at exactly the right time, and the wave that seemed overwhelming collapses. This is mastery-as-vindication — not raw power, but the satisfaction of having read the battlefield correctly.

Between missions, the same player becomes a theorist and a builder. Nine interconnected systems create a combinatorial space where the next synergy is always waiting to be discovered: a Tarot card that doubles enemy speed also doubles their drops; a creature bred for its silk becomes a Focus component that changes how a tower fires; a hero affix that nobody paired with that constellation before. The meta-progression loop is not grinding — it is research. The question is always "what happens when these two things interact?" and the game always has an answer.

The sanctuary is the player's base, workshop, and statement — and it shows. It grows visually with every decision the player makes: new structures appear, creatures populate habitats, towers stand ready in configurations the player chose. More than atmosphere, the sanctuary is the nexus of all build decisions. Players return to it between missions to improve their hero's equipment, upgrade tower components, unlock new crafting stations, expand the menagerie, or deepen their Tarot deck. Every investment is a choice about what to prioritize — and the sanctuary reflects those choices, making each player's base a visible record of how they chose to play.

## Detailed Design

### Core Rules

1. The hero is mandatory in every mission. Hero attacks deal 150% damage to elite and boss enemies — tower-only strategies cannot clear high-value targets.
2. Missions are **short by default (15–25 minutes)**. Players may choose optional run modifiers before launching to extend mission length, add challenge, or alter wave composition.
3. Each mission consists of 5–8 waves. The **penultimate wave (N-1)** is always an elite-only encounter — no BOSS, only ELITE-tier monsters. The final wave always ends with the mission boss. (Wave Manager GDD Rule 6 is canonical; the ELITE HP amplifier in Monster System GDD F4 applies on the penultimate wave, not a fixed wave 4.)
4. A **Scout Phase of 60 seconds** opens each mission. Players place towers, set constellation layouts, and finalize Tarot card selection. No enemies are active during this phase.
5. Some towers have a **pre-placement perk** that only activates if the tower was placed during the **Scout Phase** (before Wave 1 begins). Towers placed during INTERMISSION do not receive the perk. **Mid-wave tower placement is blocked** — the Tower System rejects all placement and removal actions during WAVE_ACTIVE (see Tower System GDD Rule 8, which supersedes any earlier statement here). Repositioning requires waiting for the next Intermission.
6. A 10-second countdown warning fires before each wave launches.
7. Between waves, a **25–40-second intermission** allows the player to reposition or place additional towers. Crafting, Menagerie, and Defense Building remain locked during missions. (Canonical range per Tower System GDD Tuning Knobs; default for design calculations: 30 seconds.)
8. Towers are modular: each has four independently swappable component slots (foundation, weapon, focus, power). Component combinations define the tower's behavior.
9. Constellation bonuses activate when towers are placed in defined geometric patterns on the grid. The bonus is spatial — pattern location matters, not just composition.
10. All nine systems communicate through a central event bus. No system communicates directly with another.
11. **Sanctuary technology unlocks are always persistent.** Defeated missions do not strip base progress, crafted items, menagerie state, or tech tree advancement.

### States and Transitions

| State | Entry Condition | Player Actions | Exit Condition |
|---|---|---|---|
| **SANCTUARY** | Mission ends (win) or first launch | Hero equipment, Crafting, Menagerie, Tarot deck, Defense Building, Tech unlocks | Player selects and launches a mission |
| **SCOUT** | Mission launched or mission restarted after defeat | Place towers, adjust constellations, finalize Tarot selection (60 sec) | Timer expires or player confirms ready |
| **WAVE_ACTIVE** | Scout ends | Hero combat, real-time tower monitoring only; **tower placement and removal are blocked** (Tower System Rule 8) — no build actions available until Intermission | Wave cleared → INTERMISSION or MISSION_COMPLETE; Hero HP = 0 → DEFEAT |
| **INTERMISSION** | Wave cleared (more waves remain) | Place or reposition towers; no Crafting or Menagerie access (25–40 sec) | Timer expires or player confirms ready |
| **MISSION_COMPLETE** | Final wave cleared | Review rewards | Transition to SANCTUARY |
| **DEFEAT** | Hero HP reaches 0 | Review outcome | Restart mission from SCOUT — Sanctuary progress fully preserved |

### Interactions with Other Systems

| System | During Mission (Micro) | During Sanctuary (Macro) |
|---|---|---|
| **Hero** | Direct combat, elite/boss multiplier, positioning | Equipment upgrades, affix selection |
| **Tower** | Automated area denial, modular builds, pre-placement perks | Component sourcing, slot configuration |
| **Monster** | Waves, elites, bosses, material drops | No presence — enemies do not persist |
| **Constellation** | Spatial pattern bonuses (passive, location-driven) | Pattern planning during Sanctuary prep |
| **Tarot** | Per-mission parameter modifiers, optional length/challenge extensions | Deck building, card unlocks |
| **Crafting** | LOCKED | Component fabrication from materials |
| **Menagerie** | LOCKED | Creature husbandry; happiness affects material quality |
| **Defense Building** | LOCKED | Sanctuary structure upgrades, technology unlocks (persistent) |
| **Inventory** | Passive (equipped items active) | Equipment management, material storage |

## Formulas

### Session Length Target

```
default_mission_length = scout_phase + (wave_count × avg_wave_duration) + (wave_count - 1) × intermission_duration
```

| Variable | Symbol | Type | Target Value | Description |
|---|---|---|---|---|
| Scout phase | scout_phase | seconds | 60 | Pre-wave placement window |
| Wave count | wave_count | int | 5–8 | Waves per mission (default short) |
| Average wave duration | avg_wave_duration | seconds | 90–150 | Time to clear one wave |
| Intermission duration | intermission_duration | seconds | 25–40 | Between-wave pause; canonical range per Tower System GDD Tuning Knobs (see tower.md). Use 30s as the formula point estimate for session length calculations. |

**Output Range:** 12–25 minutes under default settings
**Extended mode:** Player-chosen modifiers may increase wave_count or avg_wave_duration. Target ceiling: 45 minutes.

---

### Wave Reward Scalar

*(Renamed from "Wave Difficulty Scaling" 2026-07-15 — `/review-all-gdds` game-design-holism pass. This is `wave_reward_scalar` (`wave-manager.md` Formula 1, `design/registry/entities.yaml`) — it drives Resource Economy's drop quantity/quality scaling, not combat difficulty. Actual monster combat threat uses a separate, deliberately linear formula (`monster.md` Formula 1, `monster_hp_scaling`, 1.0×–2.40× by wave 8) that explicitly rejects exponential scaling as a "damage-sponge" negative-feedback pattern. Labeling this exponential reward curve "difficulty" risked misleading anyone balancing combat off this document alone — see `monster.md` Formula 1 for the actual combat-difficulty reference. The registry already renamed the underlying constant from `wave_difficulty_scalar` to `wave_reward_scalar` on 2026-04-26 "after design-review mandated semantic clarity"; this section had not yet been updated to match.)*

```
wave_reward_scalar = base_reward × (1 + reward_growth_rate) ^ (wave_number - 1)
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base reward | base_reward | float | 1.0 | Reward multiplier at wave 1 |
| Reward growth rate | reward_growth_rate | float | 0.15–0.25 | Per-wave escalation rate |
| Wave number | wave_number | int | 1–8 | Current wave index |

**Output Range:** 1.0× at wave 1 → 1.95–4.77× at wave 8 (r=0.15–0.25 range). See Wave Manager GDD F1 for exact boundary table.
**Penultimate wave (N-1):** ELITE-tier monsters receive a 1.35× HP amplifier — Monster System GDD Formula 4 is canonical. No separate multiplier is defined here; this note is a cross-reference only.

---

### Resource Flow (Material Drop Rate)

```
materials_per_wave = base_drop_rate × monster_count × wave_reward_scalar × menagerie_quality_bonus
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base drop rate | base_drop_rate | float | 0.3–0.6 | Materials per monster killed |
| Monster count | monster_count | int | 10–40 | Monsters spawned per wave |
| Wave reward scalar | wave_reward_scalar | float | 1.0–3.0 | From the Wave Reward Scalar formula above |
| Menagerie quality bonus | menagerie_quality_bonus | float | 1.0–1.5 | Creature happiness multiplier on material quality tier |

**Output Range:** 3–36 materials per wave under default settings. Menagerie investment increases material quality tier, not raw quantity.

## Edge Cases

- **If the hero dies during the final wave's boss fight**: DEFEAT triggers immediately regardless of remaining towers. Boss fights are always hero-mandatory.
- **If the Scout Phase timer expires with no towers placed**: Mission begins with zero towers. No auto-placement occurs. The player fights with hero only until the first intermission.
- **If a tower is destroyed during a wave**: Its constellation contribution is removed instantly. Any active constellation bonus tied to that pattern deactivates until the pattern is restored. The tower's component slots are recovered and returned to inventory at wave end.
- **If a pre-placement perk tower is placed during intermission (not before wave start)**: The perk does not activate for the upcoming wave. The tower functions normally without the perk bonus.
- **If the player selects a run modifier that extends mission length beyond the 45-minute target ceiling**: The modifier is accepted but a warning is shown. The game does not hard-cap extended modes — the target ceiling is a design guideline, not a rule.
- **If two constellation patterns overlap on the grid**: Both patterns activate independently. Overlapping tower bonuses stack additively unless the bonus description states otherwise.
- **If the player defeats the mission boss before all other wave enemies are cleared**: Mission completes immediately. Remaining enemies despawn. Drops from uncleared enemies are forfeited.
- **If a Tarot card effect and a run modifier produce contradictory parameters** (e.g., one doubles wave count, one halves it): Modifiers resolve first, then Tarot effects apply on top of the modified value.

## Dependencies

| System | Direction | Nature |
|---|---|---|
| Godot 4.6.2 | Game depends on engine | Runtime, rendering, physics (Jolt), navigation, UI |
| GDScript | Game depends on language | All gameplay logic authored in GDScript |
| PC (Windows/Linux/macOS) | Game depends on platform | Steam/Epic distribution; keyboard/mouse primary input |
| All 9 internal systems | Mutually dependent via EventBus | No direct coupling — all cross-system communication through the event bus |

## Tuning Knobs

| Parameter | Default Value | Safe Range | Too High | Too Low |
|---|---|---|---|---|
| Default wave count | 6 | 5–8 | Mission feels endless | Mission ends before build pays off |
| Scout phase duration | 60 sec | 30–120 sec | Kills urgency | Not enough time to plan |
| Intermission duration | 30 sec | 25–40 sec | Breaks mission tension | Too rushed to make decisions |
| Wave reward growth rate (`wave_reward_scalar`'s `r`) | 0.20 | 0.10–0.35 | Late-wave rewards feel excessive relative to escalating cost | No reward escalation felt. *(Renamed 2026-07-15 from "Wave difficulty growth rate" — this knob controls reward scaling, not combat difficulty; see the Wave Reward Scalar section above. Combat difficulty escalation is `monster.md`'s separate `hp_wave_growth_rate`.)* |
| Extended mode ceiling | 45 min | 30–90 min | Session fatigue | Modifiers feel cosmetic |
| Base material drop rate | 0.45 | 0.3–0.6 | Crafting trivialised | Meta-progression grinds to a halt |
| Menagerie quality bonus ceiling | 1.5× | 1.0–2.0× | Replaces crafting skill | Menagerie investment feels pointless |

## Visual/Audio Requirements

**Visual Identity Anchor** (replaced 2026-08-23 for the full art overhaul): full
visual direction lives in `design/art/art-bible.md`, Section 1. The anchoring rule:

> "Sanctuary Defenders presents a tactile, dimensional world built and commanded by the
> player, while its invading creatures appear as expressive 2D illustrations brought to
> life within that world."

The approved hybrid split makes the player's persistent domain 3D: hero, towers,
buildings, terrain, paths, Sanctuary architecture, large props, lighting, and shadows.
Monsters and creatures remain expressive 2D assets built for readability in 100+ enemy
waves. Cards, icons, portraits, UI ornamentation, and selected VFX also remain 2D. The
Diablo IV screenshots in `production/` reference Player Inventory UI only and do not
define the world's art style.

Audio direction is not yet authored — no `design/audio/` bible exists at time of writing.

## UI Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

- [ ] **GIVEN** a default mission with 6 waves, **WHEN** a player of average skill completes it, **THEN** total time is 15–25 minutes.
- [ ] **GIVEN** the hero dies at any point in a mission, **WHEN** the player restarts, **THEN** all Sanctuary tech unlocks, crafted items, and menagerie state are exactly as they were before the mission launched.
- [ ] **GIVEN** a tower with a pre-placement perk placed during the Scout Phase, **WHEN** the first wave begins, **THEN** the perk is active and its effect is visually indicated.
- [ ] **GIVEN** the same tower placed during an intermission, **WHEN** the next wave begins, **THEN** the perk is NOT active.
- [ ] **GIVEN** towers forming a valid constellation pattern, **WHEN** all towers in the pattern are placed, **THEN** the constellation bonus activates within 1 frame and a visual indicator confirms it.
- [ ] **GIVEN** a constellation pattern where one tower is destroyed mid-wave, **WHEN** the tower is destroyed, **THEN** the constellation bonus deactivates immediately.
- [ ] **GIVEN** the mission boss is killed before all wave enemies are cleared, **WHEN** the boss dies, **THEN** the mission completes immediately and remaining enemies despawn.
- [ ] **GIVEN** a player selects a run modifier, **WHEN** the mission launches, **THEN** Tarot card effects resolve after modifier effects, not before.
- [ ] **GIVEN** 100+ active monsters on the field simultaneously, **WHEN** all are pathfinding, **THEN** the frame rate remains at or above 60 FPS.

## Open Questions

[To be designed]
