# UX Spec: Mission HUD

> **Status**: Approved — post-review revision applied 2026-05-18
> **Author**: Vicknesh + ux-designer
> **Last Updated**: 2026-05-18
> **Journey Phase(s)**: SCOUT → WAVE_ACTIVE → INTERMISSION → MISSION_COMPLETE / DEFEAT
> **Template**: UX Spec

---

## Purpose & Player Need

The Mission HUD serves the player's dual role as Architect-General and reactive combatant. During SCOUT and INTERMISSION phases, the HUD is a **build dashboard** — it surfaces the tools and information needed to place towers, allocate resources, and confirm readiness before the next wave. During WAVE_ACTIVE, it becomes a **combat awareness layer** — it communicates what is happening on the field (wave progress, enemy threats, hero status, damage feedback) without demanding the player's eyes leave the action.

The HUD fails if the player ever loses track of their current phase, misses a meaningful threat because it wasn't communicated, or has to hunt for a critical piece of information during combat. Success is a player who can describe what's happening in the mission at any moment without pausing the game.

---

## Player Context on Arrival

The Mission HUD has four distinct arrival moments across a mission's lifecycle:

| Arrival Moment | Prior Action | Emotional State | Primary Player Need |
|---|---|---|---|
| **SCOUT (mission launch)** | Selected mission from Sanctuary | Calm, deliberate — in planning mode | Place towers, allocate build points, confirm readiness |
| **WAVE_ACTIVE (first wave)** | Pressed Ready or timer expired | Shifting from planning to combat — potentially tense if under-prepared | Immediate signal that build phase is over; combat state is active |
| **INTERMISSION (mid-mission)** | Just cleared a wave | Brief relief, then re-engagement | Scan for what changed — resources earned, wave preview, towers to reposition |
| **DEFEAT / MISSION_COMPLETE** | Hero died or final wave cleared | Satisfaction or disappointment | HUD steps back; transition screen takes over — no hunting for information |

The HUD must visually signal the phase transition at each boundary. A player who misses that the game has shifted from SCOUT to WAVE_ACTIVE (and tries to place a tower) has failed a HUD readability goal, not a skill check.

---

## Navigation Position

The Mission HUD is not a discrete screen — it is a persistent overlay that mounts when a mission launches and unmounts when the mission ends (MISSION_COMPLETE or DEFEAT). It lives at:

`Sanctuary → Mission Select → [Mission Scene + HUD overlay]`

The HUD is always present during an active mission regardless of phase. It cannot be "navigated away from" mid-mission — the Pause Menu overlays on top of it, but the HUD remains mounted beneath. It dismisses only on mission termination.

---

## Entry & Exit Points

### Entry Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Mission Select screen | Player confirms mission launch | Selected mission config, current hero loadout, tower component inventory, Tarot deck selection |
| DEFEAT → Restart | Player confirms "Restart" on defeat screen | Same mission config, same Sanctuary state (fully preserved per game-concept Rule 11) |

### Exit Points

| Exit Destination | Trigger | Notes |
|---|---|---|
| Pause Menu overlay | Player presses Pause (any phase) | HUD remains mounted beneath; resumes on unpause |
| MISSION_COMPLETE screen | Final wave cleared (`mission_phase_changed → MISSION_COMPLETE`) | One-way — player cannot return to the HUD without relaunching |
| DEFEAT screen | Hero HP reaches 0 (`hero_died` → `mission_phase_changed → DEFEAT`) | One-way; Sanctuary state fully preserved |

---

## Layout Specification

### Information Hierarchy

| Priority | Element | Phase Visibility | Rationale |
|---|---|---|---|
| 1 | Phase indicator + wave counter (N/M) | Always | Situational anchor — player must always know where they are |
| 2 | Phase timer (countdown) | SCOUT, PRE_WAVE, INTERMISSION | Primary pressure signal during build phases |
| 3 | Hero HP bar | Always | Survival signal — must be readable at a glance |
| 4 | Active enemy count | WAVE_ACTIVE | Wave-clear progress; drives engagement decisions |
| 5 | Breach counter | Always | Permanent HP loss tracker; low number is fine, spikes demand attention |
| 6 | Build points (resource counter) | SCOUT, INTERMISSION | Gates all placement decisions during build phases |
| 7 | Ready button | SCOUT, INTERMISSION | Primary action in build phases; state-gated |
| 8 | Tower Info Panel | Always (read-only in WAVE_ACTIVE) | Tower inspection; no interaction affordances during combat |
| 9 | Hero skills (1–4) + Ultimate | Always | Cooldown tracking; ultimate-ready is a key decision signal |
| 10 | BOSS HP bar + nameplate | WAVE_ACTIVE (contextual — BOSS present) | Highest-stakes combat feedback; shown only when BOSS is alive |
| 11 | Tower HP bars | WAVE_ACTIVE (contextual — after first BOSS hit) | Per-tower survival; appears only when relevant |
| 12 | Floating damage numbers | WAVE_ACTIVE | Real-time feedback; layered on world-space, not HUD chrome |
| 13 | Tower Build Panel | SCOUT, INTERMISSION only | Hidden during WAVE_ACTIVE |
| 14 | Cell type overlay | SCOUT, INTERMISSION only | Placement context; belongs to the game world, not HUD chrome |
| 15 | Breach screen-edge flash | WAVE_ACTIVE (event-driven) | Attention interrupt; ephemeral |
| 16 | Wave-cleared / wave-incoming banners | Phase transitions only | Ephemeral; uses Pattern 10 (Phase Transition Banner) |

### Layout Zones

```
┌───────────────────────────────────────────────────────────────┐
│  ZONE A — TOP STRIP (always visible)                          │
│  [Phase indicator] [Wave N/M] [Timer / enemy count]           │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ZONE B — GAME WORLD (full bleed)                             │
│  Grid, towers, monsters, cell overlay, floating dmg numbers   │
│                                                               │
│  ZONE C — BOSS BAR (contextual, top-center of world zone)     │
│  [Boss nameplate] [Boss HP bar]    ← slides down when active  │
│                                                               │
├────────────────────────────────┬──────────────────────────────┤
│  ZONE D — BOTTOM BAR (always)  │  ZONE E — BUILD PANEL        │
│  [Hero HP bar]                 │  (SCOUT + INTERMISSION only) │
│  [Skill 1][2][3][4] [Ultimate] │  [Build points counter]      │
│  [Breach counter]              │  [Tower build list]          │
│                                │  [Ready button]              │
│                                │  [Tower Info Panel]          │
└────────────────────────────────┴──────────────────────────────┘
```

**Zone rules:**

| Zone | Visibility | Phase behaviour |
|------|-----------|----------------|
| A — Top strip | Always | Content swaps: timer shown in SCOUT/INTERMISSION/PRE_WAVE; enemy count replaces timer in WAVE_ACTIVE |
| B — Game world | Always | Cell overlay and placement cursor active only in SCOUT/INTERMISSION; floating damage numbers active only in WAVE_ACTIVE |
| C — Boss bar | Contextual | Mounts on `monster_spawned` (tier=BOSS); dismounts on `boss_died`; slides down from top-center of Zone B |
| D — Bottom bar | Always | No layout change across phases; interaction affordances on skills/ultimate always present |
| E — Build panel | SCOUT + INTERMISSION | Slides in from right on SCOUT entry; slides out on WAVE_ACTIVE entry; Tower Info Panel collapses to a thin read-only strip during WAVE_ACTIVE rather than fully hiding |

### Component Inventory

#### Zone A — Top Strip

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Phase indicator | Status label | Current phase name (SCOUT / WAVE ACTIVE / INTERMISSION) + color | No | New pattern candidate — Phase Indicator Label |
| Wave counter | Data display | "Wave N / M" | No | — |
| Phase timer | Countdown bar + number | Seconds remaining; active in SCOUT/PRE_WAVE/INTERMISSION | No | Pattern 9 (Phase Countdown Timer) |
| Enemy count | Data display | "Enemies: N" — replaces timer in WAVE_ACTIVE | No | — |

#### Zone B — Game World (world-space elements)

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Grid Placement Cursor | World-space cursor | Footprint preview on hovered cell; valid/invalid/insufficient states | Yes — confirm/cancel placement | Pattern 1 (Grid Placement Cursor) — active only in SCOUT/INTERMISSION |
| Floating Damage Number | World-space label | Damage amount at target world position; crit/tier/source variants | No | Pattern 8 (Floating Damage Number) — active only in WAVE_ACTIVE |
| Cell type overlay | World-space tint | PLACEABLE/PATH/SPAWN/GOAL/BLOCKED cell highlighting | No | — active only in SCOUT/INTERMISSION; part of Grid Placement Cursor context |

#### Zone C — Boss Bar

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Boss HP bar + nameplate | Persistent overlay | `display_name`, `current_hp` / `max_hp` | No | Pattern 7 (Persistent Boss Overlay) |

#### Zone D — Bottom Bar

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Hero HP bar | Resource bar | `current_hp` / `max_hp`; pulses at <20% | No | Pattern 6 (Contextual HP Bar) |
| Skill buttons (×4) | Cooldown icon buttons | Skill icon + cooldown fill; dims when on cooldown | Yes — activate skill | New pattern candidate — Skill Cooldown Button |
| Ultimate button | Cooldown icon button | Larger than skills; "READY" overlay when off cooldown | Yes — activate ultimate | New pattern candidate — Skill Cooldown Button (Ultimate variant) |
| Breach counter | Data display | Breach count; scale-pops on increment | No | Pattern 5 (Resource Counter) |

#### Zone E — Build Panel

| Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|
| Build points counter | Resource counter | Current build points; flashes on deduct/award | No | Pattern 5 (Resource Counter) |
| Tower build list | Scrollable list | Available tower configs; grayed if unaffordable, not hidden | Yes — select for placement | — |
| Ready button | State-gated action button | "Ready" label; disabled during PRE_WAVE and WAVE_ACTIVE | Yes | Pattern 3 (State-Gated Action Button) |
| Tower Info Panel | Contextual info panel | Tower name, archetype, stats, Sell button (SCOUT/INTERMISSION only) | Yes — Sell action | Pattern 2 (Contextual Info Panel) |

#### New Pattern Candidates

| Pattern Name | Description | Owner |
|---|---|---|
| Phase Indicator Label | State-driven label with phase-specific text + color + icon; non-color backup is the text label itself | Flag for `interaction-patterns.md` |
| Skill Cooldown Button | Icon button with cooldown fill-drain overlay; dims when on cooldown; "READY" overlay variant for Ultimate | Flag for `interaction-patterns.md` |

### ASCII Wireframe

#### SCOUT State (build panel open, cell overlay active, no boss)

```
┌──────────────────────────────────────────────────────────────────────┐
│ [● SCOUT]        Wave 1 / 6        [▓▓▓▓▓▓▓▓▓▓▓▓▓░░ 42s]  [READY▶] │
├──────────────────────────────────────────────────────────────────────┤
│  ░░░░│▒▒▒▒│░░░░│░░░░│░░░░│░░░░│░░░░│░░░░│  ┌──────────────────────┐│
│  ░░░░│▒▒▒▒│░░░░│░░░░│░░░░│░░░░│░░░░│░░░░│  │ Build Points: 120   ││
│  ────┼────┼────┼────┼────┼────┼────┼────│  ├──────────────────────┤│
│  ░░░░│[T1]│░░░░│░░░░│░░░░│[T2]│░░░░│░░░░│  │ ▣ Arrow Tower   40pt││
│  ░░░░│[T1]│░░░░│░░░░│░░░░│[T2]│░░░░│░░░░│  │ ▣ Frost Tower   60pt││
│  ────┼────┼────┼────┼────┼────┼────┼────│  │ ░ Arcane Tower  80pt││
│  PATH PATH PATH PATH PATH PATH PATH PATH│  │   (insufficient)    ││
│  ────┼────┼────┼────┼────┼────┼────┼────│  ├──────────────────────┤│
│  ░░░░│░░░░│░░░░│░░░░│░░░░│░░░░│░░░░│░░░░│  │ Selected: Arrow Twr ││
│  ░░░░│░░░░│░░░░│░░░░│░░░░│░░░░│░░░░│░░░░│  │ DPS: 45  Range: 3   ││
├──────────────────────────────────────────│  │ [Sell — get 16pt]   ││
│ [████████ HP 280/280]                    │  └──────────────────────┘│
│ [Sk1][Sk2][Sk3][Sk4]  [★ ULTIMATE]       │ Breaches: 0              │
└──────────────────────────────────────────────────────────────────────┘
```

Legend: `░░` = PLACEABLE cell · `▒▒` = cursor footprint (valid) · `PATH` = PATH cell · `[T1]` = placed tower

#### WAVE_ACTIVE State (boss bar active, build panel collapsed, enemy count visible)

```
┌──────────────────────────────────────────────────────────────────────┐
│ [● WAVE ACTIVE]  Wave 3 / 6        Enemies: 12                       │
│         ┌──────────────────────────────────────────┐                 │
│         │ ☠ STONE GOLEM   [██████████████░░░░] 71% │                 │
│         └──────────────────────────────────────────┘                 │
│                                                                       │
│      TOWERS      MONSTERS      FLOATING NUMBERS       GAME WORLD     │
│              +47  +82(CRIT!)  +150[ELITE]                            │
│                                                                       │
│                                      ┌──────────────────────────────┐│
│                                      │ ▣ Arrow Tower  ← (read-only)││
│                                      │ HP: ████████░░  DPS: 45     ││
│                                      └──────────────────────────────┘│
├───────────────────────────────────────────────────────────────────────┤
│ [████████████░░░ HP 210/280]                                          │
│ [Sk1▶][Sk2 3s][Sk3▶][Sk4 11s]  [★ ULT — READY]   Breaches: 2       │
└───────────────────────────────────────────────────────────────────────┘
```

Legend: `▶` = skill ready · `3s` = cooldown remaining · Boss bar slides down from top-center of Zone B · Tower Info Panel collapses to read-only strip at right edge

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **SCOUT** | `mission_phase_changed → SCOUT` | Zone E (build panel) slides in; cell overlay active; timer counts down from 60s; Ready button enabled |
| **PRE_WAVE** | `wave_countdown_warning` emitted | Timer switches to 10s PRE_WAVE countdown; Ready button disabled; build panel still visible but grayed; placement cursor deactivates |
| **WAVE_ACTIVE** | `wave_started` | Zone E slides out (Tower Info Panel collapses to read-only strip); enemy count replaces timer in Zone A; placement cursor gone |
| **WAVE_ACTIVE + BOSS** | `monster_spawned` (tier=BOSS) | Zone C (boss bar) slides down from top-center |
| **INTERMISSION** | `wave_completed` | Wave-cleared banner fires (Pattern 10); Zone E slides back in; timer resets to intermission duration; enemy count replaced by timer in Zone A |
| **MISSION_COMPLETE** | `mission_phase_changed → MISSION_COMPLETE` | HUD fades out; mission complete overlay mounts on top |
| **DEFEAT** | `mission_phase_changed → DEFEAT` | Hero death VFX fires; HUD fades out; defeat screen overlays |
| **Low HP variant** | Hero HP < 20% | Screen-edge vignette activates; HP bar pulses red; no layout change |
| **Breach event** | `monster_breached` | Screen-edge flash (goal-side for STANDARD/ELITE; all-edge ring for BOSS tier); breach counter scale-pops |
| **Paused** | Pause input (any phase) | Pause menu overlays; HUD dims to ~40% opacity beneath |
| **Empty state — no tower selected** | SCOUT/INTERMISSION with no tower selected or hovered | Tower Info Panel shows "No tower selected" placeholder; Sell button absent |

---

## Interaction Map

Interactions mapped for: **Keyboard/Mouse (primary), Gamepad (partial)**. All interactions must be completable with K/M. All binds below are defaults — remappable per `design/accessibility-requirements.md` Motor Accessibility.

| Component | Action | K/M Input | Gamepad Input | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| Ready button | Advance phase | Left click | A / South face button | Button depresses; brief flash | `player_ready` signal to Wave Manager; phase advances |
| Skill button 1–4 | Activate skill | Keys 1 / 2 / 3 / 4 | TBD — defer to first gamepad playtest | Skill icon flashes; cooldown fill begins | Hero activates skill; cooldown timer starts |
| Ultimate button | Activate ultimate | Key 5 | TBD — defer to first gamepad playtest | "READY" overlay clears; large icon flash | Hero activates ultimate; cooldown timer starts |
| Tower build list entry | Select tower for placement | Left click | D-pad navigate + A | Entry highlights; placement cursor activates | Grid Placement Cursor enters active mode (Pattern 1) |
| Placed tower (grid cell) | Inspect tower | Left click on tower / hover | D-pad navigate to cell + A | Tower Info Panel populates with stats | Info panel shows tower name, archetype, stats; Sell button appears in SCOUT/INTERMISSION |
| Sell button | Remove placed tower | Left click | A / South (while Info Panel focused) | Build points counter flashes +refund; tower plays dissolve animation | Tower removed from grid; `round(cost × 0.4)` build points returned |
| Any cell (SCOUT/INTERMISSION) | Deselect / cancel placement | Right click or Esc | B / East face button | Cursor returns to free mode; Info Panel clears | Placement cancelled; no state change |
| Pause | Pause game | Esc or P (remappable) | Start / Menu button | Pause menu overlays; HUD dims to ~40% opacity | Game paused; all timers frozen |

**Gamepad note:** Skill and Ultimate bindings are explicitly deferred to the first gamepad playtest session. The constraint: D-pad is needed for cursor navigation during SCOUT/INTERMISSION, so skills cannot default to D-pad. A modifier pattern (e.g. hold shoulder button + face buttons) is the likely solution — document here after playtest.

---

## Events Fired

### Outbound Events (HUD → EventBus)

| Player Action | Event Fired | Payload | Notes |
|---|---|---|---|
| Ready button pressed | `player_ready` | None | Wave Manager owns the phase gate; HUD only fires when button is enabled |
| Sell button pressed | `tower_sell_requested` | `tower_id: int` | Tower System processes removal and returns refund; HUD owns the display gate (button hidden during WAVE_ACTIVE) |
| Skill 1–4 activated | `hero_skill_activated` | `skill_slot: int` (0–3) | Hero System processes effect and cooldown |
| Ultimate activated | `hero_ultimate_activated` | None | Hero System owns cooldown and effect resolution |
| Pause pressed | No EventBus event | — | Handled via SceneTree pause mode directly; not an EventBus concern |

### Inbound Events Consumed (EventBus → HUD, display only)

| Event | HUD Response |
|---|---|
| `mission_phase_changed` | Phase indicator updates; Zone E slides in/out; banner fires (Pattern 10) |
| `wave_started` | Wave counter updates; enemy count initialises |
| `wave_completed` | Wave-cleared banner fires; Zone E slides in; timer resets |
| `wave_countdown_warning` | PRE_WAVE countdown displayed; Ready button disabled |
| `phase_timer_tick` | Phase timer bar and number update |
| `monster_spawned` (tier=BOSS) | Zone C mounts; boss nameplate populates from MonsterResource |
| `monster_died` | Enemy count decrements |
| `monster_breached` | Breach counter increments + scale-pop; screen-edge flash fires |
| `boss_hp_changed` | Boss HP bar updates |
| `monster_damage_taken` | Floating damage number spawned at target world position |
| `hero_died` | HUD fades out; defeat transition begins |
| `tower_placed` | Build points counter decrements |
| `tower_destroyed` | Tower HP bar (if shown) dismounts |
| `hero_health_changed` | Hero HP bar updates; low-HP vignette activates if `current_health / max_health < 0.20` |
| `tower_damaged` | Tower HP bar mounts (first event for that tower) or updates (subsequent events) |

### Architecture Flag

`tower_sell_requested` modifies persistent game state (tower removal, build point refund). The HUD owns the UI gate — Sell button is hidden during WAVE_ACTIVE — but the Tower System must also guard against this event arriving outside SCOUT/INTERMISSION phases, in case of edge cases (e.g. rapid phase transition while button is mid-press).

---

## Transitions & Animations

All timings are design targets pending art direction sign-off. All transitions must respect the reduced-motion toggle committed in `design/accessibility-requirements.md` — reduced-motion variants are noted per entry.

| Transition | Trigger | Animation | Duration | Reduced-Motion Variant |
|---|---|---|---|---|
| HUD mount | Mission launch | Fade in from 0% opacity | 0.3s | Instant show |
| SCOUT → PRE_WAVE | `wave_countdown_warning` | Ready button grays; build panel dims; placement cursor fades out | 0.2s | Instant state change |
| PRE_WAVE → WAVE_ACTIVE | `wave_started` | Build panel (Zone E) slides out to right | 0.25s | Instant hide |
| WAVE_ACTIVE → INTERMISSION | `wave_completed` | Build panel (Zone E) slides in from right; wave-cleared banner fires (Pattern 10) | 0.25s | Instant show + banner |
| Boss spawns | `monster_spawned` (tier=BOSS) | Boss bar (Zone C) slides down from above Zone B top edge | 0.3s ease-out | Instant show |
| Boss dies | `boss_died` | Boss bar slides back up and fades out | 0.4s | Instant hide |
| Breach — STANDARD/ELITE | `monster_breached` (tier < BOSS) | Goal-side screen-edge red flash: 0.2s on, 0.5s fade | 0.7s total | **Exempt from reduced motion** — gameplay-critical feedback |
| Breach — BOSS | `monster_breached` (tier=BOSS) | All-edge red ring flash: 0.2s on, 0.5s fade | 0.7s total | **Exempt from reduced motion** — gameplay-critical feedback |
| Hero HP < 20% | HP threshold crossing | Screen-edge vignette fades in over 0.5s; pulses on 1.5s sine cycle | Looping until HP recovers above threshold | Vignette shows at fixed opacity; no pulse |
| MISSION_COMPLETE / DEFEAT | `mission_phase_changed` (terminal) | HUD fades to 0% opacity; outcome screen fades in after HUD clears | 0.5s HUD out; outcome in after | Cut to outcome screen |
| Phase Transition Banner | Phase changes | Slides down from top-center, holds 1.5s, slides back up (Pattern 10) | ~2s total | Instant show, hold 1.5s, instant hide |

---

## Data Requirements

The HUD is read-heavy — it consumes EventBus events and reads Resources directly. It writes to game state only via `tower_sell_requested` and the hero skill/ultimate activation events (see Events Fired).

| Data | Source System | Read / Write | Update Mechanism | Notes |
|---|---|---|---|---|
| Current mission phase | Wave Manager | Read | `mission_phase_changed` event | |
| Wave index / total waves | Wave Manager | Read | `wave_started` event payload | |
| Phase timer (seconds remaining) | Wave Manager | Read | `phase_timer_tick` every 1s | |
| PRE_WAVE countdown | Wave Manager | Read | `wave_countdown_warning` payload | |
| Active enemy count | Monster System | Read | `monster_spawned` +1 / `monster_died` −1 / `monster_breached` −1 | HUD maintains local counter derived from events |
| Breach count | Monster System | Read | `monster_breached` event | HUD maintains local counter |
| BOSS display name | MonsterResource | Read | Direct resource read at `monster_spawned` (tier=BOSS) | Nameplate populated once; dismounted on `boss_died` |
| BOSS current / max HP | Monster System | Read | `boss_hp_changed` event | |
| Floating damage metadata | D&S System | Read | `monster_damage_taken` event | Fields used: `amount`, `is_crit`, `hero_bonus_tier`, `source_type` |
| Hero current / max HP | Hero System | Read | `hero_health_changed` event (`current_health: float`, `max_health: float`) | Event already in EventBus catalogue |
| Hero skill cooldowns | Hero System | Read | `hero_skill_cooldown_updated` event | ⚠ Not yet in EventBus catalogue — must be added before implementation |
| Hero ultimate ready state | Hero System | Read | Derived from skill cooldown state | |
| Build points (current) | Tower System | Read | `tower_placed` (deduct) / `wave_completed` (award) | |
| Tower configurations (build list) | Tower System / player inventory | Read | Loaded at mission start; static for mission duration | |
| Tower stats (Info Panel) | TowerResource | Read | Direct resource read on tower selection | |
| Tower current HP (boss-attack bar) | Tower System | Read | `tower_damaged` event (`tower_id`, `damage_dealt`, `current_hp`, `max_hp`) | Event already in EventBus catalogue |
| Build point refund | Tower System | Write | HUD fires `tower_sell_requested`; Tower System confirms and updates | HUD owns UI gate (button hidden during WAVE_ACTIVE); Tower System must also guard |

### Initial / Null State Specification

| Data | Initial Value at HUD Mount | Null Fallback |
|---|---|---|
| Hero HP bar | `max_health / max_health` (full bar) until first `hero_health_changed` fires | Show full bar — never show empty |
| Active enemy count | 0 — increments from first `monster_spawned` | 0 is a valid state (between waves) |
| Breach count | 0 — increments from `monster_breached` | 0 is a valid display |
| Phase timer | Scout duration (from mission config) — counting down | Never null; always has a configured value |
| BOSS display name | Not shown (Zone C unmounted) | If `display_name` is empty in MonsterResource, fall back to `monster_id` string |
| Tower Info Panel | "No tower selected" placeholder | Always shows placeholder when no selection; never blank |
| Build points | Loaded from mission config at mount | 0 if config missing; log warning |

### EventBus Gaps — Action Required

Four events are required by this spec but are not yet in `design/gdd/event-bus.md`. Two events the spec originally flagged (`hero_health_changed`, `tower_damaged`) already exist in the catalogue under those names — only the four below are genuinely missing:

| Event | Proposed Payload | Fired By | Consumed By |
|---|---|---|---|
| `player_ready` | (none) | Mission HUD (Ready button press) | Wave Manager (phase gate) |
| `hero_skill_cooldown_updated` | `skill_slot: int`, `cooldown_remaining: float`, `cooldown_max: float` | Hero System (each cooldown tick) | Mission HUD (skill button fill) |
| `hero_ultimate_activated` | (none) | Mission HUD (Ultimate button press) | Hero System (effect + cooldown) |
| `tower_sell_requested` | `tower_id: int` | Mission HUD (Sell button press) | Tower System (removal + refund) |

Also note: `hero_skill_activated` exists in the catalogue with payload `skill_id: String, target_position: Vector2`, but the spec fires it with `skill_slot: int`. Resolve the payload discrepancy with the Hero GDD before implementation — the HUD knows the slot, not the skill_id.

---

## Accessibility

Accessibility tier: **Standard** — per `design/accessibility-requirements.md`. All commitments below are binding.

| Element | Concern | Requirement | Implementation Note |
|---|---|---|---|
| All HUD text | Legibility | 20px minimum for critical HUD text (wave counter, phase indicator, HP values) | Per accessibility-requirements.md Visual section |
| Phase indicator | Color-as-only-indicator | Phase name displayed as text — color is redundant backup, not the sole signal | Text label always present alongside color |
| Hero HP bar | Color-as-only-indicator | Numeric HP value (`current / max`) shown alongside bar; bar segments at 20% thresholds | `210 / 280` format; never color-only |
| Breach counter | Color-as-only-indicator | Counter number displayed; screen-edge flash is a redundant backup, not the sole signal | Already in design |
| Boss HP bar | Color-as-only-indicator | Percentage or numeric value shown alongside bar (e.g. `71%`) | Text label always visible |
| Floating damage numbers | Color-as-only-indicator | Crit: larger font size in addition to color; ELITE bonus: icon or border in addition to color; BOSS bonus: stronger size/icon variant | Per D&S GDD MVP requirements — both channels required at MVP |
| Tower archetype in build list | Color-as-only-indicator | Archetype icon + distinct silhouette per archetype — no color-only identification | Per Tower GDD and accessibility-requirements.md "Features explicitly in scope" |
| Skill cooldown buttons | Color-as-only-indicator | Cooldown fill drain is shape-based (fill level); grayed-out state also dims the label text, not just the color | Not color-only |
| All interactive elements | Keyboard navigation | Logical tab order: Ready button → skill buttons (1–4) → ultimate → tower build list → Tower Info Panel → Sell button | Verified in first UI implementation pass |
| All interactive elements | Gamepad navigation | D-pad navigates build list and grid during SCOUT/INTERMISSION; face buttons confirm/cancel; skill gamepad bindings deferred to playtest | Document final bindings in this spec after playtest. **Note: gamepad skill/ultimate coverage is incomplete — this spec must be updated before gamepad implementation pass in `/team-ui`.** |
| Phase transitions | Reduced motion | All slide and fade transitions have instant show/hide reduced-motion variants (see Transitions section) | Screen-edge breach flashes exempt — gameplay-critical |
| Hero low-HP vignette | Reduced motion | Pulsing replaced with static vignette at fixed opacity when reduced motion is enabled | Per Transitions section |
| Pause | Motor accessibility | Pause input works in all phases including WAVE_ACTIVE and boss encounters — no exceptions | Per accessibility-requirements.md Motor section |
| HUD scale | Visual accessibility | HUD scale slider independent from menu scale; range 75%–150%; layout must not break at either extreme | Test all HUD zones at 75% and 150% before ship |

---

## Localization Considerations

A 40% text expansion (typical for English → German / French) must not break any HUD layout. Elements marked HIGH PRIORITY require explicit constraints in the localization pipeline.

| Element | Max English Length | Expansion Risk | Constraint |
|---|---|---|---|
| Phase indicator label | 12 chars ("WAVE ACTIVE") | **HIGH** | Cap translated label at 14 chars; use approved abbreviation if over (e.g. "ACTIVE" for "WAVE ACTIVE") |
| Wave counter | 14 chars ("Wave 6 / 6") | Low | Numeric — mostly language-agnostic; separator character may vary by locale |
| "Enemies: N" label | 12 chars | Medium | Separate label string from number in layout so the number remains fixed-width regardless of label length |
| "Ready" button label | 5 chars | **HIGH** | Max 8 chars in translated label; if over, widen button to fit or use icon-only variant with tooltip |
| "Sell — get 16pt" | 18 chars | **HIGH** | Split into two lines in layout: action label ("Sell") on line 1, refund amount ("16 pts back") on line 2; neither line is length-critical independently |
| BOSS nameplate | Variable (content-authored) | Medium | Max nameplate width = 50% of screen width; overflow truncates with ellipsis at 1 line |
| Floating damage numbers | Numbers only | None | Use locale number formatter; no translated text required |
| Skill / Ultimate labels | Icon-only (no text in default state) | None | Tooltip on hover shows localised text — tooltip width can flex freely |

**HIGH PRIORITY for localization engineer:** Phase indicator label, Ready button label, Sell button label. All three are layout-critical at default UI scale — flag for string-length audit before each locale ships.

---

## Acceptance Criteria

- [ ] GIVEN a mission scene becomes active, WHEN the scene tree enters, THEN the HUD is fully mounted and all Zone A elements are visible within 200ms — independent of any EventBus event.
- [ ] GIVEN a mission is launched, WHEN the HUD mounts, THEN the phase indicator reads "SCOUT", the wave counter reads "Wave 1 / N", and the phase timer shows the configured scout duration — all within 1 frame of the `mission_phase_changed → SCOUT` event.
- [ ] GIVEN the HUD is in SCOUT or INTERMISSION, WHEN the player presses the Ready button, THEN `player_ready` fires within 1 frame and the PRE_WAVE countdown appears within 1 frame of `wave_countdown_warning`.
- [ ] GIVEN WAVE_ACTIVE begins, WHEN `wave_started` fires, THEN the build panel (Zone E) is fully hidden within 0.25s; the enemy count is visible in Zone A; the Ready button is not present or interactable.
- [ ] GIVEN a BOSS spawns, WHEN `monster_spawned` (tier=BOSS) fires, THEN the boss bar (Zone C) is visible within 1 frame, showing the correct `display_name` and a full HP bar.
- [ ] GIVEN a breach event fires, WHEN `monster_breached` is received, THEN the breach counter increments and scale-pops within 1 frame; the screen-edge flash fires and completes within 0.7s.
- [ ] GIVEN the hero HP drops below 20%, WHEN the threshold is crossed, THEN the screen-edge vignette is visible within 1 frame and the HP bar is pulsing; GIVEN HP recovers above 20%, THEN both effects fade within 0.5s.
- [ ] GIVEN a `monster_damage_taken` event fires with `is_crit=true`, WHEN the floating number renders, THEN it is visibly larger than a non-crit number on the same target — confirmed by screenshot evidence filed in `production/qa/evidence/`.
- [ ] GIVEN a `monster_damage_taken` event with `hero_bonus_tier=1` (ELITE), WHEN the floating number renders, THEN it displays a visually distinct indicator (icon, border, or size variant) beyond color alone — confirmed by greyscale screenshot.
- [ ] GIVEN the HUD is displayed at 75% UI scale, WHEN all zones are visible simultaneously, THEN no text is clipped, no elements overlap, and all interactive targets remain reachable by mouse click.
- [ ] GIVEN the player uses keyboard only, WHEN tabbing through all interactive elements during SCOUT, THEN every interactive component (Ready button, skill buttons, ultimate, tower build list entries, Sell button) receives focus in logical order with a visible focus indicator.
- [ ] GIVEN reduced motion is enabled in accessibility settings, WHEN any phase transition occurs, THEN no slide animations play — elements appear or disappear instantly; breach screen-edge flashes still fire normally.
- [ ] GIVEN MISSION_COMPLETE fires, WHEN the HUD dismisses, THEN it is at 0% opacity within 0.5s and the outcome screen is the only visible UI layer.
- [ ] GIVEN no tower is selected or hovered during SCOUT, WHEN the Tower Info Panel is visible, THEN it shows a "No tower selected" placeholder and no Sell button is present.

---

## Open Questions

1. **EventBus gaps — RESOLVED 2026-05-18.** All four missing events added to `design/gdd/event-bus.md`: `player_ready` (Wave Manager section), `hero_skill_cooldown_updated` + `hero_ultimate_activated` (Hero System section), `tower_sell_requested` (Tower System section). Note: `hero_health_changed` and `tower_damaged` already existed in the catalogue — earlier draft of this spec named them incorrectly; the spec now uses the correct names.

2. **`hero_skill_activated` payload mismatch** — The existing EventBus event has payload `skill_id: String, target_position: Vector2`, but this spec fires it with `skill_slot: int`. Resolve with the Hero System GDD before implementation: either the HUD derives `skill_id` from the slot, or the payload is changed to `skill_slot: int` and the Hero System maps slot→skill_id internally.

3. **Gamepad skill bindings** — Explicitly deferred to the first gamepad playtest. D-pad is reserved for cursor navigation during SCOUT/INTERMISSION, so skills cannot default to D-pad. A modifier pattern (e.g. hold shoulder button + face buttons) is the likely solution. Update the Interaction Map in this spec after playtest.

4. **Hero Skill Build GDD** — Skill slots 1–4 and the Ultimate button are referenced here, but no Hero Skill Build GDD exists yet. Skill button content (icons, names, cooldown durations) cannot be fully specified until that GDD is authored. Skill Cooldown Button pattern implementation is blocked on this.

5. **Sanctuary HP display** — The breach counter tracks breach count, but the game-concept implies a Sanctuary HP total exists as the underlying resource. Resolve: does the Mission HUD display current Sanctuary HP (e.g. "HP: 3 / 5") alongside or instead of the breach count, or is the counter the canonical display? Decision deferred to Sanctuary System GDD.

6. **Kill feed (post-MVP)** — Monster GDD lists a kill feed (monster type + kill source, driven by `monster_died` payload: `monster_id`, `tier`, `kill_source`) as a Mission HUD forward requirement. Deferred to Alpha — breach counter + enemy count + floating damage numbers cover core kill feedback at MVP. Revisit when kill-source attribution becomes a player-facing design goal.

7. **Floating number stagger** — D&S GDD EC-8 requires simultaneous hits on the same target to stagger floating numbers to avoid overlap. This is an implementation constraint on the floating damage number spawner, not a layout concern. Must be documented in the Skill Cooldown Button / floating number pattern when added to `interaction-patterns.md`.
