# Interaction Pattern Library

> **Status**: In Design (seed catalogue — v1, bootstrapped from GDD UI Requirements)
> **Author**: solo dev (ux-designer role)
> **Last Updated**: 2026-05-18
> **Template**: Interaction Pattern Library
> **Accessibility Tier**: Standard (per `design/accessibility-requirements.md`)
> **Input Methods**: Keyboard/Mouse (primary), Gamepad (partial — all interactions must be completable with K/M)
> **Linked Documents**: `design/gdd/tower.md`, `design/gdd/monster.md`, `design/gdd/damage-status.md`, `design/gdd/wave-manager.md`, `design/accessibility-requirements.md`

---

## Overview

This library catalogues the reusable interaction patterns used across Sanctuary Defenders' UI. Each pattern documents its behaviour, input bindings (K/M + gamepad), and Standard-tier accessibility commitments — so screen specs can reference patterns by name rather than re-specifying them. When a screen needs a behaviour not in this library, that behaviour either becomes a new pattern entry here or is documented as a single-use exception in the screen spec.

**Conventions:**
- "Cell" refers to a grid cell on the mission grid (see `design/gdd/grid-system.md`).
- "Phase" refers to mission FSM phase (`SCOUT`, `PRE_WAVE`, `WAVE_ACTIVE`, `INTERMISSION`, `MISSION_COMPLETE`, `DEFEAT`, `IDLE`).
- "Standard tier a11y" means the commitments enumerated in `design/accessibility-requirements.md` — every pattern entry restates the items that bind it.

---

## Pattern Catalog

| # | Pattern | Category | Used In |
|---|---------|----------|---------|
| 1 | Grid Placement Cursor | Input + Feedback | Tower (placement HUD), Mission HUD (Zone B — SCOUT/INTERMISSION) |
| 2 | Contextual Info Panel | Data Display | Tower (info panel), Mission HUD (Zone E — tower inspection, boss nameplate) |
| 3 | State-Gated Action Button | Input | Wave Manager (Ready), Tower (Sell), planned: pause menu actions |
| 4 | Cost-Labelled Button | Input + Data Display | Tower (Sell, Build entries), planned: shop-style screens |
| 5 | Resource Counter | Data Display | Mission HUD (build points, breach counter), Tower (build points), planned: Hero (XP) |
| 6 | Contextual HP Bar | Data Display | Mission HUD (Hero HP bar), Tower (boss attacks only), Monster (non-boss) |
| 7 | Persistent Boss Overlay | Data Display + Modal | Mission HUD (Zone C — boss HP bar + nameplate) |
| 8 | Floating Damage Number | Feedback | Mission HUD (Zone B — world-space), D&S (every damage event) |
| 9 | Phase Countdown Timer | Data Display | Mission HUD (Zone A — SCOUT, INTERMISSION, PRE_WAVE) |
| 10 | Phase Transition Banner | Feedback | Mission HUD (Zone B — phase transitions) |
| 11 | Phase Indicator Label | Feedback / Data Display | Mission HUD (Zone A — always visible) |
| 12 | Skill Cooldown Button | Input + Feedback | Mission HUD (Zone D — skills 1–4, Ultimate) |

---

## Patterns

### 1. Grid Placement Cursor

**Category**: Input + Feedback
**Used In**: Tower (`design/gdd/tower.md` — Placement HUD)

**Description**: The cursor mode active during SCOUT and INTERMISSION while the player has a tower selected for placement. The cursor snaps to grid cells (per `Grid.world_to_cell()`) and shows a footprint preview that updates in real time as the cursor moves. The preview communicates three things simultaneously: which cells will be occupied, whether the placement is valid, and (if invalid) why.

**Specification**:
- **Snap behaviour**: cursor world position is rounded to the nearest cell via `Grid.world_to_cell()`. Visual cursor sprite is drawn at the cell's centre (`Grid.cell_to_world()`) — not at the raw mouse position.
- **Footprint preview**: the cells the tower would occupy are highlighted with one of three states:
  - **Valid** (placement would succeed): cells highlighted with the valid-state fill + check-mark icon at the footprint's top-left.
  - **Invalid — would block path** (`would_block_all_paths()` returned true): cells highlighted with the blocked-state fill + barrier icon. Cursor briefly shakes on the first frame the state becomes Invalid.
  - **Invalid — insufficient resources**: cells highlighted with the insufficient-state fill + coin-shortfall icon. Build-cost number in the build panel is also dim-flashed in red.
- **State communication redundancy** (a11y): every state has (1) a colour, (2) a fill pattern (cross-hatch for invalid, solid for valid, dotted for insufficient), and (3) an icon. Colour alone is never the sole signal.
- **Confirm action**: places the tower, deducts cost, emits `tower_placed`, returns cursor to free-cursor mode.
- **Cancel action**: clears selection without placing, returns cursor to free-cursor mode.

**Input binding**:
| Action | K/M | Gamepad |
|--------|-----|---------|
| Move cursor | Mouse move (cell snap) | Left stick (cell-by-cell stepping; tap snaps one cell) |
| Confirm placement | Left click | A / South face button |
| Cancel placement | Right click or Esc | B / East face button |
| Show tower range overlay | Hold Shift (toggle alternative: press once to lock; press again to release — Standard-tier hold-input alternative) | Hold LB (same toggle alternative) |

**Accessibility (Standard tier)**:
- All three placement states use shape + icon backups, not colour alone (per Color-as-Only-Indicator audit row "Cell type overlay").
- Cursor sprite is ≥ 24×24 px at default UI scale, scaled with UI scale slider.
- Hold-to-show-range has a toggle alternative (per Motor Accessibility — "Hold-to-press alternatives" row).
- Gamepad cell-stepping: discrete one-cell-per-tap movement, not analog drift — prevents missed cells from low-precision input.

**When to Use**: Any cursor mode where the player is positioning something on the grid. (Currently: tower placement. Future: spell/ability target reticles if added.)

**When NOT to Use**: Cursors that target entities rather than cells (use a target reticle pattern instead — not yet in this library).

**Reference**: see `design/gdd/tower.md` Placement HUD section.

---

### 2. Contextual Info Panel

**Category**: Data Display
**Used In**: Tower (info panel on select/hover); planned: Mission HUD (boss nameplate, monster inspect — future)

**Description**: A side or anchored panel that displays detailed information about a single in-world entity (tower, monster, etc.) selected or hovered by the player. The panel is read-only during gameplay-locked phases and may expose action affordances (e.g., Sell button) in non-locked phases.

**Specification**:
- **Visibility trigger**: appears when a) the cursor hovers an inspect-eligible entity for ≥ 250 ms (hover) or b) the player explicitly selects an entity (click / A button).
- **Visibility dismissal**: cursor leaves the entity (hover case) or player clicks empty space / presses Cancel (select case). Phase change to `MISSION_COMPLETE` or `DEFEAT` also dismisses.
- **Anchor**: fixed screen position (right edge for K/M, bottom edge for gamepad — gamepad players' eyes track the centre more, so bottom anchor reduces eye travel).
- **Read-only phases** (`WAVE_ACTIVE`): the panel displays data but all action affordances (Sell, Upgrade, etc.) are **hidden** — not greyed. Per `design/gdd/tower.md`: "no interaction affordances are shown" during WAVE_ACTIVE.
- **Interactive phases** (`SCOUT`, `INTERMISSION`): action affordances are visible and operable.
- **Content sections**: header (entity name + archetype/tier icon), stats block (table of relevant stats), action row (zero or more `Cost-Labelled Buttons` — pattern #4).
- **Update behaviour**: data refreshes in real time via the entity-system's update events (e.g., subscribes to `tower_component_equipped`, `hero_stats_changed`). No manual refresh required.

**Input binding**:
| Action | K/M | Gamepad |
|--------|-----|---------|
| Open (hover) | Cursor over entity for ≥ 250 ms | N/A (gamepad uses select only) |
| Open (select) | Left click on entity | A on focused entity |
| Dismiss | Click empty space or Esc | B / East face button |
| Activate action affordance | Click button | A on focused button (panel becomes a focus container) |

**Accessibility (Standard tier)**:
- Text size ≥ 22 px (matches stat-block minimum from accessibility-requirements.md).
- Stat block is a `<table>`-equivalent semantic structure (when AccessKit is wired up later); rows are sequential focus targets via Tab / D-pad.
- Panel anchor position is fixed (not screen-edge variable) so players know where to look; this constraint is the Standard-tier substitute for HUD repositioning (deferred to Comprehensive).
- Hover open is also reachable by select — no information is hover-only.

**When to Use**: Single-entity inspection, especially when displaying ≥ 4 stats. Persistent panel design (not tooltip) when the player may want to compare against an action they're about to take.

**When NOT to Use**: Quick value display for a single number (use a tooltip instead — not yet in this library). Group inspection (would need a multi-entity panel — not yet a pattern).

**Reference**: see `design/gdd/tower.md` Tower Info Panel section.

---

### 3. State-Gated Action Button

**Category**: Input
**Used In**: Wave Manager (Ready button), Tower (Sell button — composes with `Cost-Labelled Button`), planned: pause menu actions

**Description**: A button whose interactivity is gated by mission phase. In invalid phases the button is either greyed (visible but unpressable) or hidden entirely. The choice between grey vs hidden is per-pattern-instance — both are acceptable Standard-tier presentations as long as the choice is consistent for that button.

**Specification**:
- **State enumeration**: every State-Gated button has exactly two presentational states — `active` (full opacity, pressable) and `inactive` (greyed at 30% opacity OR hidden entirely).
- **State driver**: the button's owning system subscribes to `mission_phase_changed` (EventBus) and recomputes state on every emission. State is never derived per-frame.
- **Hidden vs greyed**:
  - Use **hidden** when the action is logically nonexistent in the invalid phase (e.g., Tower Sell during WAVE_ACTIVE — selling during combat is design-forbidden, so the affordance is removed). Per `design/gdd/tower.md`: "The button is hidden (not grayed — fully absent) during `WAVE_ACTIVE`."
  - Use **greyed** when the action is conceptually valid but blocked by a temporary condition (e.g., Ready button during `PRE_WAVE` countdown — the player can see the button but can't skip the countdown). Per `design/gdd/wave-manager.md`: Ready button "must be inactive (not pressable) when … `PRE_WAVE` countdown cannot be skipped."
- **No silent ignore**: if a player input attempts to activate an inactive button (e.g., binding hit via remap), the button does nothing visible — but the system's input handler is responsible for not double-firing or queuing the action. (Wave Manager handles this: "ignores Ready signals received outside of SCOUT and INTERMISSION.")

**Input binding**:
| Action | K/M | Gamepad |
|--------|-----|---------|
| Activate | Left click | A / South face button when focused |
| Focus (gamepad only) | N/A | D-pad / left stick to navigate to button |

**Accessibility (Standard tier)**:
- Greyed state is at most 30% opacity AND has an additional non-colour cue (e.g., disabled-icon prefix, label suffix "(unavailable)") — opacity alone is not sufficient discrimination per WCAG.
- Hidden state must not cause neighbouring elements to reflow / shift (reserve the space) — eye-tracked players need a stable target location.
- Button must be reachable by keyboard / gamepad navigation in active state — no mouse-only buttons.
- Focus indicator (when navigated to) must be ≥ 3 px outline at high contrast against the panel background.

**When to Use**: Any action whose validity changes with mission phase (or any other binary game-state condition).

**When NOT to Use**: Actions valid in all phases (use a plain button). Actions with > 2 phase-driven states (would need a state-machine button pattern — not yet a pattern).

**Reference**: see `design/gdd/wave-manager.md` "Ready button contract" and `design/gdd/tower.md` "Sell button" rule.

---

### 4. Cost-Labelled Button

**Category**: Input + Data Display
**Used In**: Tower (Sell button — "Sell — get 40% back ([refund] pts)"), Tower (Build panel entries — each shows cost in label), planned: shop-style screens

**Description**: A button whose label embeds the resource cost or refund tied to its action. The cost is computed at render time (not hardcoded) so dynamic prices (refunds, scaling costs) update without a separate label component.

**Specification**:
- **Label format**: `[Action verb] — [cost direction] [amount] [resource name/icon]` — e.g., `Sell — get 40% back (12 pts)`, `Build — costs 30 pts`, `Upgrade — costs 50 pts`.
- **Affordability**: if the action requires resources the player lacks, the button enters a `cost-insufficient` substate:
  - Cost portion of the label rendered in the insufficient-state colour
  - Cost portion has a coin-shortfall icon suffix
  - Button is non-activatable (composes with `State-Gated Action Button` — pattern #3 — in greyed mode)
- **Composition**: this pattern stacks with `State-Gated Action Button` for buttons that have BOTH phase-gating AND cost-gating (e.g., Tower Sell — phase-gated to SCOUT/INTERMISSION AND cost is always a refund so cost-insufficient never triggers).
- **Update behaviour**: the cost value re-reads from the source system whenever the source emits a change event (e.g., on `tower_component_equipped`, the Sell refund updates if the component changed the base cost).

**Input binding**: identical to `State-Gated Action Button` (this pattern is a label convention, not a new input pattern).

**Accessibility (Standard tier)**:
- Label text must remain at ≥ 22 px even when long (e.g., German translation may double the verb length). Spec the button layout to flow vertically (action verb on top line, cost on bottom line) if horizontal space is tight — never truncate the cost.
- Cost portion's insufficient-state colour must be backed by the coin-shortfall icon, not colour alone.
- Screen-reader announcement (when AccessKit is wired up): "Sell tower. Get 40% back, 12 points. Currently available." or "Build tower. Costs 30 points. Insufficient — you have 18."

**When to Use**: Any action whose primary decision factor is a resource cost the player must consider.

**When NOT to Use**: Free actions (use a plain button — embedding "free" is more confusing than omitting). Actions with multi-resource costs (would need an extended pattern — flag if added).

**Reference**: see `design/gdd/tower.md` Sell button line: "Sell — get 40% back ([refund] pts)".

---

### 5. Resource Counter

**Category**: Data Display
**Used In**: Tower (in-mission build points), planned: Mission HUD (sanctuary HP), Hero (XP if exposed)

**Description**: A persistent numeric display of a single player-owned resource. Always visible during phases where the resource is relevant. Updates in real time via the resource-owning system's events. Includes contextual flash animations on increment/decrement for feedback.

**Specification**:
- **Visual form**: icon + numeric value (e.g., `🪙 124`). Numeric value uses fixed-width font to prevent layout jitter on digit-count changes.
- **Position**: anchored — typically top of screen for currencies, fixed across all phases where visible. Position persists even when the resource is at zero (don't hide).
- **Update trigger**: subscribes to the resource-owning system's change event (`build_points_changed`, `sanctuary_hp_changed`, etc.). On event:
  - Numeric value updates immediately
  - **Increment**: brief green flash on the icon + value, then fades over 400 ms (Standard tier "motion reduction" mode: omit the flash, update silently)
  - **Decrement**: brief red flash + a small floating "-N" particle that rises and fades over 800 ms (motion reduction: omit the particle, brief outline flash only)
- **Insufficient signalling**: when the player attempts an action requiring more than the current value (caught by `Cost-Labelled Button` pattern), the counter dim-flashes red for 600 ms.
- **Visibility**: hidden only when the resource is logically inaccessible (e.g., build points hidden in MISSION_COMPLETE summary screen — that screen owns its own resource display).

**Input binding**: none — display only.

**Accessibility (Standard tier)**:
- Numeric value at ≥ 24 px (HUD critical-information minimum).
- Icon must be a distinct silhouette (not relying on colour alone) so resource type is identifiable in all 3 colourblind modes.
- Increment/decrement flash must respect the motion-reduction toggle (per `design/accessibility-requirements.md` "Motion / animation reduction mode" row).
- Screen-reader announcement (future): only on insufficient-flash, not on every increment — "[Resource name] insufficient" — to avoid auditory spam.

**When to Use**: Persistent display of a single integer-valued player resource that the player needs to reference for decisions.

**When NOT to Use**: Floating point or computed values that change frequently (use a contextual readout instead). Resources the player references rarely (move to an info panel instead of permanent HUD real estate).

---

### 6. Contextual HP Bar

**Category**: Data Display
**Used In**: Tower (boss attacks only — appears on first hit, hides on wave end), Hero, Monster (non-boss tiers)

**Description**: An HP bar that appears only when the entity is in a state where the player benefits from seeing it. Hides when irrelevant to reduce HUD clutter and reserve attention for moments that matter.

**Specification**:
- **Visibility triggers**: the owning entity's system declares the appear/disappear conditions. Examples:
  - Tower HP bar: appears on first `monster_damage_taken` against a tower; disappears when the wave ends or the tower is destroyed.
  - Monster HP bar (non-boss): appears on first damage; persists until death or breach.
  - Hero HP bar: always visible during WAVE_ACTIVE; hidden during SCOUT/INTERMISSION (full HP, irrelevant).
- **Position**: anchored to the entity's world position via a screen-space follow projection. Bar is drawn above the entity sprite within the entity's grid cell footprint — does not overlap adjacent cells (per `design/gdd/tower.md` rule).
- **Visual form**: horizontal bar with fill colour transitioning at thresholds:
  - 100–60%: neutral fill (default UI colour)
  - 60–30%: caution fill (yellow-orange tone)
  - 30–0%: critical fill (red tone) + bar pulses at 2 Hz
- **Segmentation** (a11y backup for colour): bar is divided into 5 visible segments — each segment empties as 20% HP is lost. Provides numeric inference without depending on colour.
- **Numeric overlay** (on hover/focus): exact current/max HP appears as a text overlay when the entity is hovered or focused.

**Input binding**: none — display only. Hover/focus enables numeric overlay.

**Accessibility (Standard tier)**:
- 5-segment subdivision is the primary non-colour HP signal (per Color-as-Only-Indicator audit).
- Numeric value on hover/focus is the second non-colour signal.
- Bar pulse at < 30% must respect motion-reduction toggle — if reduced motion, switch to solid red without pulse.
- Bar height ≥ 4 px at default UI scale (smaller bars become unreadable for low-vision players); scaled with UI scale slider.

**When to Use**: Any entity whose HP changes during gameplay and whose HP value is decision-relevant for the player.

**When NOT to Use**: Bosses (use `Persistent Boss Overlay` — pattern #7 — for full-width persistent presentation). Permanent entities whose HP is irrelevant to decisions (e.g., decorative props).

---

### 7. Persistent Boss Overlay

**Category**: Data Display + Modal
**Used In**: Monster (boss HP bar + nameplate)

**Description**: A full-width or anchor-locked HUD overlay that displays an active boss's HP and identity. Persists for the entire boss lifetime (spawn → death or breach), even when the boss is off-screen. This is the boss combat's primary attention anchor.

**Specification**:
- **Visibility**: appears on `monster_spawned` if the spawned monster is tier-3 (BOSS); disappears on `monster_died` or `monster_breached` for the same `entity_id`.
- **Position**: anchored top-edge of screen, centred horizontally, full width minus 10% margins each side.
- **Content**:
  - **Nameplate** (top row): boss `display_name` (from `MonsterResource`) + tier-3 crown icon
  - **HP bar** (below nameplate): full-width bar driven by `boss_hp_changed` event (`current_hp` / `max_hp`)
  - **HP numeric** (overlaid on bar, centre-aligned): "[current_hp] / [max_hp]" — always visible (unlike non-boss HP bars where numeric is hover-only)
- **HP bar visual**: same colour-and-segment scheme as `Contextual HP Bar` (5 segments, threshold colour shifts), scaled to full width.
- **Off-screen indicator**: if the boss is off-screen, an arrow at the bottom of the overlay points in the direction of the boss's screen position. The overlay itself never moves with the camera; only the arrow does.
- **Multi-boss handling** (MVP: not in scope — single boss per wave per current design): if two bosses are active, stack overlays vertically — second boss anchored below first, half-height.

**Input binding**: none — display only.

**Accessibility (Standard tier)**:
- Nameplate text at ≥ 28 px (boss combat is the climactic UI — readable from across the room is the design intent).
- Numeric HP always visible (not hover-gated) for accessibility — players using screen magnification can read the value without precise hover.
- Off-screen arrow uses a distinct directional silhouette (chevron with tail), not just colour, per Standard-tier "visual representations for directional audio" commitment.
- Bar pulse at < 30% respects motion-reduction toggle (same as `Contextual HP Bar`).

**When to Use**: Tier-3 (BOSS) monsters only. Future analogous use: late-game raid bosses if added.

**When NOT to Use**: Non-boss enemies (use `Contextual HP Bar`). Player-controlled entities (use `Contextual HP Bar` anchored to entity, not screen).

**Reference**: `design/gdd/monster.md` — "BOSS HP Bar — RESOLVED" section + `boss_hp_changed` event.

---

### 8. Floating Damage Number

**Category**: Feedback
**Used In**: D&S (every `monster_damage_taken` event), planned: Hero damage indicators if added

**Description**: A short-lived numeric overlay that appears at the world position of a damaged entity. Communicates damage magnitude and source type at a glance. The single most-frequent UI element in the game during WAVE_ACTIVE — its readability and clutter management directly determine combat clarity.

**Specification**:
- **Trigger**: every `monster_damage_taken` event spawns one floating number at the target's world position.
- **Content**: integer damage value (floor of computed damage).
- **Variants** (per `design/gdd/damage-status.md` UI Requirements):
  - **Normal hit**: default font size + default colour.
  - **Crit hit** (`is_crit=true`): larger font size + distinct colour (final colour value owned by Art Direction, not specced here).
  - **Elite-tier damage** (`hero_bonus_tier=1`): MVP-required visual distinction — coloured border or distinct base colour. Required at MVP per GDD.
  - **Boss-tier damage** (`hero_bonus_tier=2`): MVP-required stronger visual variant than Elite — climactic combat moment, must read as distinct.
  - **Source type** (`source_type=0` tower vs `source_type=1` hero): optional at MVP — may use different base colours to distinguish source at a glance.
- **Animation**: rise + fade over 800 ms. Initial vertical velocity randomised within ±10% to reduce visual sameness when many spawn simultaneously.
- **Stacking** (per GDD EC-8): simultaneous hits on the same entity stagger horizontally by 16 px per number, so they don't overlap. After 4 stacked numbers, additional damage in the same frame collapses into a sum-display with a "+N" suffix (e.g., "150 +3" means base hit of 150 plus 3 additional hits collapsed).
- **Cleanup**: numbers are pooled and reused — never instantiated and freed per hit. Pool sized to 32 (peak budget).

**Input binding**: none — display only.

**Accessibility (Standard tier)**:
- All four variants (Normal / Crit / Elite / Boss) must be distinguishable without colour. Per `design/accessibility-requirements.md` Color-as-Only-Indicator audit row for "damage numbers": Crit uses larger font + position offset; Elite uses a border/badge; Boss uses an even stronger badge (e.g., crown prefix). Colour is additive, not primary.
- Default font size ≥ 24 px; Crit font size ≥ 32 px.
- Motion-reduction toggle: numbers spawn at peak position without rise animation; fade-only over 800 ms.
- Stacking collapse (≥ 4 hits → "+N") is also a readability win at low vision — caps visible density.

**When to Use**: Every damage event in normal combat. The single feedback channel that communicates "your damage landed."

**When NOT to Use**: Status-effect ticks (DoT damage) at the same tick rate as the parent effect — would spam. Use a single number per status tick instead, prefixed with the status icon.

**Reference**: `design/gdd/damage-status.md` UI Requirements section + EC-8.

---

### 9. Phase Countdown Timer

**Category**: Data Display
**Used In**: Wave Manager (SCOUT timer, INTERMISSION timer, PRE_WAVE countdown)

**Description**: A persistent timer display that communicates time-remaining in the current mission phase. Three variants matching three phase types; same visual base, different urgency cues at low thresholds.

**Specification**:
- **Trigger**: subscribes to `phase_timer_tick` (Wave Manager event — `phase: String`, `seconds_remaining: float`).
- **Visual form**: depleting horizontal bar + numeric `MM:SS` overlay (centred on the bar).
- **Variants**:
  - **SCOUT timer**: long-duration (default 60 s+). Bar in neutral fill. No urgency cues.
  - **INTERMISSION timer**: medium-duration (default 30 s). Bar in neutral fill. At ≤ 10 s remaining: numeric overlay pulses at 1 Hz.
  - **PRE_WAVE countdown**: short-duration (default 10 s). Bar in caution colour. At ≤ 3 s remaining: numeric overlay pulses at 2 Hz + numeric goes large (≥ 48 px).
- **Position**: anchored — same screen position across all three variants so the player knows where to look regardless of phase.
- **Skip affordance**: the Ready button (separate UI element — `State-Gated Action Button` pattern #3) is the skip mechanism for SCOUT and INTERMISSION. The timer itself has no interactive surface — it's display only.

**Input binding**: none — display only.

**Accessibility (Standard tier)**:
- Numeric overlay at ≥ 24 px (HUD critical-information minimum), scaling to ≥ 48 px in PRE_WAVE final 3 s.
- Bar segmentation (5 segments) provides non-colour time-remaining inference for SCOUT/INTERMISSION; PRE_WAVE is short enough that segments are less useful, so colour shift is the primary cue (with audio backup per SFX audit).
- Pulse animations at ≤ 10 s (INTERMISSION) and ≤ 3 s (PRE_WAVE) must respect motion-reduction toggle — if reduced, numeric remains static but colour stays at caution.
- Time format `MM:SS` is locale-independent (numeric only) — no localisation concerns.

**When to Use**: Any mission phase with a defined duration.

**When NOT to Use**: Cooldowns on individual abilities (use a per-ability cooldown radial — not yet a pattern). The mission-overall WAVE_ACTIVE phase has no timer (it ends on wave completion, not on time) — do not use this pattern there.

**Reference**: `design/gdd/wave-manager.md` "Phase display data contract" — `phase_timer_tick` event + Ready button contract.

---

### 10. Phase Transition Banner

**Category**: Feedback
**Used In**: Wave Manager (`mission_phase_changed` event)

**Description**: A brief full-width overlay that announces a mission phase change. Anchors the player's attention on the transition without blocking input or pausing gameplay. Distinct from the Persistent Boss Overlay (#7): the Banner is transient (auto-dismisses in ≤ 2 s); the Boss Overlay persists for the entire boss lifetime.

**Specification**:
- **Trigger**: subscribes to `mission_phase_changed` (Wave Manager event — `from_phase: String`, `to_phase: String`).
- **Content**: large text reading the destination phase name in player-friendly form ("Scout Phase", "Wave Incoming", "Wave 3 Cleared", "Intermission", "Mission Complete", "Defeated"). One supporting line below (smaller text) optional — e.g., "Place towers and prepare" under "Scout Phase".
- **Animation**:
  - Enter: full-width slide-in from off-screen (top edge), reaching final position in 200 ms.
  - Hold: stationary for 1500 ms.
  - Exit: fade-out over 300 ms.
  - Total lifetime: ~ 2000 ms.
- **Non-blocking**: input continues to register during the banner — placing a tower or pressing Ready works as normal even mid-banner. The banner is feedback, not a modal.
- **Cancellable**: if another `mission_phase_changed` fires while a banner is active, the current banner skips to fade-out immediately and the new banner enters. Never queue.
- **No banner for some transitions**: transitions to terminal phases that have their own dedicated screen (`MISSION_COMPLETE`, `DEFEAT`) do not get a banner — the screen takes over instead.

**Input binding**: none — display only and non-blocking.

**Accessibility (Standard tier)**:
- Text at ≥ 48 px (large enough to read at the brief 2 s lifetime).
- Motion-reduction toggle: skip slide-in and fade-out — banner instantly appears for 1500 ms, then instantly disappears. Total information delivery preserved.
- Auto-dismiss in ~ 2 s — borderline against the "no auto-dismissing dialog with actionable info under 5 seconds" Standard-tier rule. The banner is **not actionable** (purely feedback — no action required from player), so the 5 s minimum doesn't apply. Document this explicitly: the action is already conveyed by the phase change itself, the banner only confirms.
- Screen-reader announcement (future): announce the destination phase name once on transition; do not announce supporting line (reduces auditory load).

**When to Use**: Mission phase transitions that the player needs to be aware of but that don't require an action choice.

**When NOT to Use**: Transitions that require a player decision (use a modal dialog instead — not yet a pattern). Transitions that have dedicated full screens (`MISSION_COMPLETE`, `DEFEAT`).

**Reference**: `design/gdd/wave-manager.md` "Phase display data contract" — `mission_phase_changed` event.

---

### 11. Phase Indicator Label

**Category**: Feedback / Data Display
**Used In**: Mission HUD (Zone A — top strip)

**Description**: A state-driven label chip that displays the current mission phase as both text and a color-coded indicator. The chip updates on every `mission_phase_changed` event. It is the player's primary situational anchor — always visible regardless of HUD state.

**Specification**:
- **States**: one entry per mission FSM phase. Each state has: a display string, a chip color, and an optional icon glyph.
  - `SCOUT` — text: "SCOUT", color: calm blue, icon: ● (filled circle)
  - `PRE_WAVE` — text: "INCOMING", color: amber, icon: ▲ (warning)
  - `WAVE_ACTIVE` — text: "WAVE ACTIVE", color: red, icon: ● (pulsing)
  - `INTERMISSION` — text: "INTERMISSION", color: grey-green, icon: ◼ (pause)
  - `MISSION_COMPLETE` — text: "COMPLETE", color: gold, icon: ★
  - `DEFEAT` — text: "DEFEAT", color: dark red, icon: ✕
- **Non-color backup**: the text label is the primary signal. Color is redundant — no state conveys meaning through color alone.
- **Chip width**: fixed to the longest label ("INTERMISSION" at 12 chars at default scale). All states render in this fixed-width chip — no layout shift on phase change.
- **Localization constraint**: translated labels must not exceed 14 chars. If over, use approved abbreviation. The chip width is calibrated to 14 chars at max.
- **Update timing**: synchronous with `mission_phase_changed` — renders in the same frame the event fires.

**Input binding**: display only — no interaction.

**Accessibility (Standard tier)**:
- Text label is the primary signal; color is redundant — compliant with no-color-only rule.
- Chip background has ≥ 4.5:1 contrast ratio against the label text color.
- Phase change does not trigger a layout shift — fixed-width chip prevents reflow that could disorient.

**When to Use**: Any screen that needs to communicate a discrete system state where the player's mental model requires immediate orientation. Wrap in a fixed-width chip when the label length varies by state.

**When NOT to Use**: States with more than 6–8 variants (chip becomes a lookup exercise). Use a status dashboard pattern instead.

**Reference**: `design/ux/mission-hud.md` Zone A, Information Hierarchy Priority 1.

---

### 12. Skill Cooldown Button

**Category**: Input + Feedback
**Used In**: Mission HUD (Zone D — skill buttons 1–4, Ultimate button)

**Description**: An icon button that communicates skill availability through a fill-drain overlay. When a skill is on cooldown, a dark fill covers the icon from bottom-to-top, draining away as the cooldown expires. When the skill is ready, the fill is fully drained and the button is fully lit. The Ultimate variant adds a "READY" text overlay when off cooldown.

**Specification**:
- **Ready state**: icon at full opacity; no overlay; button is pressable.
- **Cooldown state**: icon at 50% opacity; dark fill overlay covers `cooldown_remaining / cooldown_max` fraction of the icon from top to bottom; a numeric countdown (`3s`, `11s`) displayed at the icon center. Button is not pressable.
- **Transitioning to ready**: fill drains to 0 in the final second; brief flash of full opacity on icon (1 frame at 100%, then settle) signals the skill is ready.
- **Ultimate variant**: "READY" text overlay appears when cooldown_remaining = 0; dismissed immediately when Ultimate is activated.
- **Simultaneous activation**: only one skill can activate per input event — no multi-skill queueing.
- **Cooldown data source**: `hero_skill_cooldown_updated` event (`skill_slot`, `cooldown_remaining`, `cooldown_max`). Fill fraction = `cooldown_remaining / cooldown_max`. Stops updating when `cooldown_remaining = 0`.

**Input binding**:
| Action | K/M | Gamepad |
|--------|-----|---------|
| Activate skill 1–4 | Keys 1 / 2 / 3 / 4 | TBD — defer to first gamepad playtest |
| Activate ultimate | Key 5 | TBD — defer to first gamepad playtest |

**Accessibility (Standard tier)**:
- Cooldown state communicated by fill-drain shape, not color alone — compliant with no-color-only rule.
- "Cooldown active" state also dims the label text (not just the color), so greyed-out state is readable in greyscale.
- Numeric countdown text at ≥ 20 px.
- Focus indicator visible when button has keyboard focus (both ready and cooldown states).
- Button is focusable but not activatable during cooldown (pressing it while on cooldown has no effect and produces no feedback — prevents accidental input confusion).

**When to Use**: Any button representing a resource that regenerates over time (skills, abilities, consumables). Use the Ultimate variant when the button represents the highest-stakes action available.

**When NOT to Use**: Buttons with binary lock/unlock states not tied to time (use State-Gated Action Button instead). Actions with no cooldown (use a standard icon button).

**Reference**: `design/ux/mission-hud.md` Zone D Component Inventory; `design/gdd/hero.md` skill system.

---

## Gaps & Patterns Needed

Patterns expected by GDDs or future screens but not yet specced. Add to the library as the first screen that needs them lands a UX spec.

| Gap | Expected User | Priority | Notes |
|-----|--------------|----------|-------|
| **Tooltip on hover** | Tower stat blocks, monster info, ability descriptions | High | Brief delay-triggered text overlay; smaller than `Contextual Info Panel`. Needs explicit hover-delay convention + gamepad-focus alternative. |
| **Target reticle** | Future hero abilities, spells, AoE indicators | Medium | Distinct from `Grid Placement Cursor` — targets entities, not cells. |
| **Status-effect icon stack** | Hero (incoming buffs/debuffs), Monster (DoT/CC stack) | High | 5 status types per D&S. Need stack-count + remaining-duration display per icon. |
| **Modal dialog (decision required)** | Save EC-3 recovery choice, "Are you sure?" prompts, settings reset | High | True modal — blocks input. Distinct from `Phase Transition Banner` (which is non-blocking). |
| **Floating notification toast** | Achievement unlock, sanctuary upgrade complete, save success | Medium | Brief slide-in from screen edge; auto-dismisses after read time. Distinct from `Phase Transition Banner` (smaller, screen corner, non-critical). |
| **Settings slider with live preview** | Volume sliders, UI scale, brightness | High | Standard tier requires these. Slider + numeric readout + live-preview behaviour. |
| **Tab navigation container** | Settings menu sections, sanctuary subscreens | Medium | Tab strip + page region. Gamepad needs shoulder-button cycling. |
| **Confirmation hold prompt** | Hold-to-confirm-tower-delete, hold-to-skip-dialog | High | Standard tier requires toggle alternatives — the pattern entry must spec both modes. |
| **Constellation overlay** | Tower constellation patterns | Low | System-specific; defer until Constellation System GDD is authored. |
| **Save slot card** | Mission Select / Main Menu save slot screen | Medium | Composes `Cost-Labelled Button`-style metadata with a select action. Needs delete affordance. |

---

## Open Questions

| Question | Owner | Deadline | Notes |
|----------|-------|----------|-------|
| Should the `Grid Placement Cursor` snap behaviour use linear cursor follow (cursor moves with mouse, sprite snaps) or stepped follow (cursor jumps cell-by-cell)? Affects gamepad parity. | self | Before Tower placement story | Current spec assumes linear for mouse, stepped for gamepad. Verify in first playtest. |
| Is the `Contextual Info Panel` anchor really platform-dependent (right edge K/M, bottom gamepad)? Or should it be user-configurable? | self | Before Mission HUD spec | User-configurable is Comprehensive tier (HUD repositioning — deferred). Fixed-per-input-method is the Standard-tier compromise. |
| Does the `Persistent Boss Overlay` need to fade or move when blocking critical view? E.g., boss flies into the same screen-edge region. | self | Before first boss encounter playtest | MVP assumes overlay stays put. If playtests show conflict, add an opacity reduction when boss is at screen-edge. |
| `Floating Damage Number` colour assignments (Normal / Crit / Elite / Boss) are deferred to Art Direction per GDD. When art bible lands, this library's spec needs an "Art-defined values" cross-link. | self | After `/art-bible` | Cross-link this pattern entry in the art bible's UI section. |
| Should the `Phase Countdown Timer` have an audio tick at the final 3 seconds of PRE_WAVE? | self | Audio design pass | Defer to Audio Director when that role activates. Standard-tier a11y requires visual = audio parity, so any tick needs the visual pulse it already has. |

---

## Maintenance Notes

- This library is the **single source of truth** for these patterns. If a screen spec re-specifies a pattern's behaviour, that re-specification is a bug — either the library is wrong (update it here) or the spec is non-standard (document why).
- Add a pattern entry only when the pattern is used in **two or more** screens. Single-use behaviours stay in their screen's spec until a second use justifies promotion.
- When a pattern's accessibility commitments change, also update the relevant row in `design/accessibility-requirements.md` so both documents agree.
- When Godot 4.6 AccessKit integration work begins, the per-pattern "Accessibility" subsections gain screen-reader announcement specs (currently noted as future per pattern).
