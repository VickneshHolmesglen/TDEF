# Accessibility Requirements: Sanctuary Defenders

> **Status**: Draft (committed at Technical Setup gate)
> **Author**: solo dev (designer / producer / ux roles)
> **Last Updated**: 2026-05-16
> **Accessibility Tier Target**: **Standard**
> **Platform(s)**: PC (Windows, Linux, macOS) — Steam / Epic Games Store
> **Input Methods**: Keyboard/Mouse (primary), Gamepad (partial — all interactions completable with K/M per `.claude/docs/technical-preferences.md`)
> **External Standards Targeted**:
> - WCAG 2.1 Level **AA** (text contrast and resizability — applied to UI as a guideline; games are not legally required to meet WCAG, but it is the most-cited concrete contrast standard)
> - AbleGamers CVAA Guidelines (informational reference — no chat / voice features in scope, so CVAA is not legally triggered)
> - Xbox / PlayStation Accessibility Guidelines: **N/A** (PC-only)
> - Apple / Google Accessibility Guidelines: **N/A** (no mobile release)
> **Accessibility Consultant**: None engaged (solo project — internal review only at this tier)
> **Linked Documents**: `design/gdd/systems-index.md`, `design/gdd/game-concept.md`, `.claude/docs/technical-preferences.md`, `design/ux/interaction-patterns.md` (pending)

> **Why this document exists**: Per-screen accessibility annotations belong in
> UX specs. This document captures the project-wide accessibility commitments,
> the feature matrix across all systems, and the test plan. It is the single
> source of truth for what this game commits to and what it explicitly defers.
> If a feature conflicts with a commitment made here, this document wins —
> change the feature, not the commitment, unless this doc is formally revised.
>
> **When to update**: after each `/gate-check` pass, after any audit, and whenever
> a new system is added to `systems-index.md`.

---

## Accessibility Tier Definition

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical text readable; no color-only signals; independent volume controls; no photosensitivity risk. | Low — design constraints |
| **Standard** *(committed)* | Basic + full input remapping + subtitles with speaker ID + adjustable text size + ≥1 colorblind mode + no unextendable timed input. | Medium — dedicated implementation work |
| **Comprehensive** | Standard + screen reader for menus + mono audio + difficulty assist modes + HUD repositioning + reduced motion + visual cues for all critical audio. | High — platform API integration |
| **Exemplary** | Comprehensive + full subtitle customization + high contrast + cognitive load assist + haptic alternatives + external audit. | Very High — dedicated specialist |

### This Project's Commitment

**Target Tier**: **Standard**

**Rationale**: Sanctuary Defenders is a single-player hybrid RPG tower-defense on PC, built by a solo developer using Godot 4.6.2. The TD/RPG structure with discrete SCOUT → WAVE_ACTIVE → INTERMISSION phases eliminates the most severe motor barriers common in action games — players can pause at any phase boundary and most decision-making happens during turn-based-style scout phases. The largest accessibility risks are therefore (a) colorblind discrimination across tower archetypes (Damage / Control / Support / Utility need to be distinguishable without color), (b) text legibility for stat blocks and tooltips, and (c) input remapping for players using one-handed setups or adaptive controllers. The Standard tier addresses all three. Comprehensive tier is not achievable at solo-dev capacity without delaying the v1.0 release window. Exemplary is out of reach without a dedicated accessibility budget. Basic tier would exclude players relying on colorblind modes or remapping — an estimated 8–12% of the target audience per AbleGamers data — which is unacceptable.

**Features explicitly in scope (beyond Standard baseline)**:
- **Pause anywhere, including mid-wave.** Standard tier requires "no unextendable timed input"; we are stronger — the whole game must be pausable at any frame, with no penalty. This is also a usability win for parents and shared-household players.
- **Tower archetype shape-coding.** The 4 tower archetypes (Damage / Control / Support / Utility) get distinct silhouettes in addition to color, so they remain distinguishable in all 3 colorblind modes and at low-brightness display settings.

**Features explicitly out of scope** (see Known Intentional Limitations for details):
- Screen reader support for menus (defers to Comprehensive tier ADR-0011 work)
- Mono audio option (defers to Comprehensive)
- Full subtitle customization (defers to Comprehensive)
- HUD element repositioning (defers to Comprehensive)
- Haptic alternatives for audio cues (defers to Exemplary)

---

## Visual Accessibility

| Feature | Tier | Scope | Status | Implementation Notes |
|---------|------|-------|--------|---------------------|
| Minimum text size — menu UI | Standard | All menu screens | Not Started | 24px minimum at 1080p; scale proportionally at higher resolutions. Verify resizable to 150% without layout break (relaxed from WCAG's 200%). |
| Minimum text size — tooltips & stat blocks | Standard | Tower stats, monster info, hero stat sheet | Not Started | 22px minimum at 1080p. Stat blocks are the densest UI in the game (12 hero stats, 4 tower component slots × multiple stats each) — must remain legible at smaller settings without overflow. |
| Minimum text size — HUD | Standard | Wave counter, mission phase, currency | Not Started | 20px minimum for critical HUD (wave #, phase indicator, sanctuary HP). Non-critical can be smaller. |
| Text contrast — UI text on backgrounds | Standard | All UI text | Not Started | ≥ 4.5:1 ratio for body text (WCAG AA). ≥ 3:1 for large text (18px+ or 14px bold). Verify with contrast analyzer on final palette. |
| Text contrast — subtitles | Standard | Subtitle display | Not Started | ≥ 7:1 ratio (WCAG AAA). Default to drop shadow + opaque background box. |
| Colorblind mode — Protanopia | Standard | All color-coded gameplay | Not Started | Affects tower archetype colors, monster tier indicators, hero/monster HP bars, status effect icons. Shift reds to orange/yellow; shift greens to teal. |
| Colorblind mode — Deuteranopia | Standard | All color-coded gameplay | Not Started | Similar adjustments to Protanopia; usually covered by the same palette shift. Verify with Coblis. |
| Colorblind mode — Tritanopia | Standard | All color-coded gameplay | Not Started | Shift blues to purple; shift yellows to orange. Lower priority than Prot/Deut but cheap to add when palette work is done. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Not Started | See audit table below. Every entry must have a non-color backup before release. |
| UI scaling | Standard | All UI elements | **Partial — Main Menu done 2026-08-06** | Range 75%–150%. Default 100%. Test all screens at min and max. HUD scale independent from menu scale. Main Menu's own Settings/Load Game/Overwrite Confirm panels scale via a slider (`design/quick-specs/menu-ui-scale-2026-08-05.md`), live-verified at 75%/150% with no clipping/overlap. HUD scale and every other screen (Inventory, Sanctuary UI, Defense Building, etc.) remain Not Started — no shared scaling mechanism exists yet beyond this one screen. |
| High contrast mode | Comprehensive | — | **Deferred** | Not committed at Standard tier. See Known Intentional Limitations. |
| Brightness / gamma controls | Basic | Global | Not Started | Settings menu. Range -50% to +50% from default. Provide calibration reference image (gradient with a "barely visible" marker). |
| Screen flash / strobe warning | Basic | All cutscenes, VFX | Not Started | (1) Pre-launch warning screen on first run. (2) Audit boss attack VFX and ult animations against Harding FPA (no more than 3 flashes/sec above luminance threshold). (3) Optional flash-reduction toggle for boss VFX. |
| Motion / animation reduction mode | Standard | Camera shake, UI transitions, looping FX | Not Started | Toggle in accessibility settings. Affects: screen shake on tower-attack/monster-death, parallax in menu backgrounds, looping idle FX on UI. Does not affect monster movement or tower fire animation (would break readability). |
| Subtitles — on/off | Basic | All voiced/captioned content | Not Started | Default ON for narrative content if any is added; default OFF for ambient SFX captions. |
| Subtitles — speaker identification | Standard | All voiced content | Not Started | Speaker name displayed before line. If colors used to distinguish speakers, verify in all 3 colorblind modes. |
| Subtitles — style customization | Comprehensive | — | **Deferred** | Provide two presets ("default" and "high-readability — larger, opaque background, no transparency") as Standard-tier compromise. See Known Intentional Limitations. |
| Subtitles — sound effect captions | Comprehensive | — | **Deferred** | Visual indicators for critical audio cues are committed in the Cognitive Accessibility section instead — captions themselves are deferred. |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Hero HP bar | Red = low | Player is near death | Numeric value shown; bar flashes at <20%; vignette FX at <10% | Not Started |
| Monster HP bar | Red = low | Monster near death | Numeric value on focus; bar segments (5 segments at full) | Not Started |
| Tower archetype tint | Red/Blue/Green/Yellow | Damage / Control / Support / Utility | **Distinct silhouettes per archetype** (see "Features explicitly in scope") + archetype icon on tower base | Not Started |
| Monster tier indicator | Color border | Tier 1 / 2 / 3 (boss) | Icon: dot / diamond / crown overlay on monster | Not Started |
| Status effect icons | Color-coded auras | Burn / Freeze / Stun / Poison / Slow | Each effect has a distinct icon shape + animated overlay (flame, ice shard, swirl, drip, snail) | Not Started |
| Mission phase indicator | Blue=SCOUT, Red=WAVE_ACTIVE, Grey=INTERMISSION | Current phase | Phase name displayed as text; HUD layout changes visibly (placement UI hidden during WAVE_ACTIVE) | Not Started |
| Cell type overlay (during scout) | Green=PLACEABLE, Brown=PATH, etc. | Grid cell type | Diagonal hatching pattern overlay per cell type; icon at cell center on hover | Not Started |
| Tower target indicator | Coloured outline on tower's current target | Which monster the tower is shooting | Crosshair icon attached to targeted monster | Not Started |

---

## Motor Accessibility

| Feature | Tier | Scope | Status | Implementation Notes |
|---------|------|-------|--------|---------------------|
| Full input remapping | Standard | All gameplay inputs, K/M + gamepad independently | Not Started | Every default-bound input is rebindable. K/M and gamepad remap independently. Conflict warning on duplicate assignment. Persist to player profile. |
| Input method switching | Standard | PC only | Not Started | Player can switch K/M ↔ gamepad mid-session. UI prompts update dynamically (correct icons for active method). Detect last-used device per `Input.is_action_just_pressed` event source. |
| One-hand mode | Standard | All gameplay | Not Started | Game is mouse-driven for tower placement; keyboard inputs (hero skills 1–4 + Ultimate, pause, speed toggle) must all be rebindable to mouse buttons or to a single hand's keyboard region. Audit at first prototype: confirm no two-hand-required input remains. |
| Hold-to-press alternatives | Standard | All hold inputs | Not Started | Inventory of hold inputs in this game: (1) hold-to-confirm tower delete, (2) hold-to-skip narrative dialog, (3) hold-to-show-tower-range while placing. Each gets a toggle alternative in accessibility settings. |
| Rapid input alternatives | Standard | None expected | N/A by design | TD genre has no button-mashing inputs. Ultimate skill cast is a single press, not a charge. Re-audit if any system adds rapid-input requirements. |
| Input timing adjustments | Standard | None expected | N/A by design | No QTEs, no rhythm inputs, no timed prompts. Pause-anywhere covers any future timed inputs that might be introduced. Re-audit before each new system lands. |
| Aim assist | Standard | Tower placement (snap-to-cell) | Already in design | Tower placement already snaps to grid cells (per Grid GDD `world_to_cell` semantics). No free-aim required. Hero auto-attacks are EventBus-driven, not aim-based. |
| Pause anywhere | Basic+ | All gameplay states | Not Started | Pause works during SCOUT, WAVE_ACTIVE, INTERMISSION, MISSION_COMPLETE, DEFEAT. No "cannot pause during boss" exception. Cutscenes (if any) must be pause-able. |
| Movement assists | Standard | N/A — no player movement | N/A by design | Player does not directly move a character in the world (hero is autonomous). |
| HUD repositioning | Comprehensive | — | **Deferred** | See Known Intentional Limitations. |

---

## Cognitive Accessibility

| Feature | Tier | Scope | Status | Implementation Notes |
|---------|------|-------|--------|---------------------|
| Difficulty options | Standard | Mission difficulty | Not Started | Granular sliders preferred over single-label difficulty. At minimum: enemy HP multiplier, enemy speed multiplier, resource gain multiplier. Default = 1.0×. Per-mission override possible. |
| Pause anywhere | Basic | All gameplay states | Not Started | (Duplicate of Motor section — covered there.) |
| Tutorial persistence | Standard | All tutorials and tooltips | Not Started | Once dismissed, tutorial prompts retrievable from a Help section. Tower / monster / status-effect tooltips always available on hover. **Placement note (2026-07-07)**: `design/ux/pause-menu.md` originally assumed this Help section would live in the Pause Menu, but that requirement was descoped from the spec — no tutorial/help-prompt system exists yet to retrieve from, and building toward one for a single button was disproportionate. This commitment remains real and tracked; its eventual UI home (Pause Menu or elsewhere) is undecided until a tutorial system is actually designed. |
| Objective clarity | Standard | Mission objective display | Not Started | Current mission objective accessible within 2 button presses at all times (one to open pause menu, one to view objective). Full objective text on demand, not just an icon. |
| Visual indicators for audio-only information | Standard | All gameplay-critical SFX | Not Started | Required indicators: (1) off-screen monster spawn alert (screen-edge marker), (2) boss attack windup (visible animation telegraph + ring under boss), (3) low-HP heartbeat (vignette FX + numeric flash, already covered visually), (4) wave-stuck watchdog (HUD warning text — backs up the EventBus `wave_stalled` audio cue). |
| Reading time for UI | Standard | All auto-dismissing dialogs | Not Started | No auto-dismissing dialog with actionable info under 5 seconds. Preferred: require player confirmation. Audit during UI implementation. |
| Cognitive load documentation | Comprehensive | — | **Deferred** | Not committed at Standard tier, but the per-feature matrix below at least flags high-load systems for design review. |
| Navigation assists | Standard | Sanctuary ↔ Mission flow | Not Started | Sanctuary serves as a fast-travel hub. Mission selection clearly shows previously cleared missions vs. new content. |

---

## Auditory Accessibility

| Feature | Tier | Scope | Status | Implementation Notes |
|---------|------|-------|--------|---------------------|
| Subtitles for spoken dialogue | Basic | All voiced content (none currently in scope, but pre-committed if added) | Not Started | If voiced narrative is added later (currently game-concept has minimal narrative scope), 100% subtitle coverage is required from day one. |
| Closed captions for gameplay-critical SFX | Comprehensive | — | **Deferred** | Visual indicators (per Cognitive section) are the Standard-tier substitute. |
| Mono audio option | Comprehensive | — | **Deferred** | See Known Intentional Limitations. |
| Independent volume controls | Basic | Music / SFX / Voice / UI buses | Not Started | Four independent sliders. Range 0–100%. Default 80%. Exposed in main settings and pause menu. |
| Visual representations for directional audio | Comprehensive | — | **Deferred** | TD genre concentrates monsters on visible paths — directional off-screen audio is less critical than in 3D games. Re-evaluate if any system adds off-screen threats. |
| Hearing aid compatibility | Standard | All audio cues | Not Started | Audit audio cues for frequency range. Any critical cue above 4kHz needs a low-frequency or visual equivalent. The boss attack windup cue and the wave-stuck watchdog cue are the two critical-information audio events identified so far — both will have visual backups. |

### Gameplay-Critical SFX Audit

| Sound Effect | What It Communicates | Visual Backup | Status |
|-------------|---------------------|--------------|--------|
| Wave start chime | New wave beginning | HUD wave counter increments + phase indicator changes to WAVE_ACTIVE | Not Started |
| Wave clear chime | Wave defeated | INTERMISSION phase indicator + summary panel | Not Started |
| Monster breach (sanctuary HP loss) | Sanctuary HP lost | Sanctuary HP bar decrement + red flash on HP UI | Not Started |
| Boss spawn roar | Boss spawned | Boss enters with distinct large silhouette + tier-3 crown icon | Not Started |
| Boss attack windup | Boss is about to attack | Telegraph animation + ring under boss + targeting indicator | Not Started |
| Tower placement confirm | Tower placed | Tower sprite appears on grid + brief placement-confirmation animation | Not Started |
| Tower placement reject | Placement failed | Brief red flash on attempted cell + reason text ("Path would be blocked") | Not Started |
| Hero ultimate ready | Ultimate cooldown finished | Ultimate icon glow + small "READY" text overlay | Not Started |
| Low sanctuary HP warning | Sanctuary HP critical | HP bar flashing + vignette + numeric value flash | Not Started |
| Wave-stuck watchdog | Wave has stalled 30s | HUD warning text "Wave stalled — check spawn area" + camera nudge to spawn cell | Not Started |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Steam (PC) | Steam Input | Controller remapping via Steam Input (in addition to in-game remapping) | Not Started | Steam Input lets players define controller profiles independent of game. In-game remap still required for K/M. |
| PC — Screen Reader | Godot 4.5+ AccessKit | **Deferred** | — | Comprehensive-tier feature. Godot 4.6 AccessKit supports basic menu narration but requires per-Control accessible name setup. Not committed at Standard tier. |
| Xbox / PS5 / Mobile | XAG / Sony / iOS / Android | N/A | N/A | PC-only release per `.claude/docs/technical-preferences.md`. Add when porting is in scope. |

---

## Per-Feature Accessibility Matrix

> One row per MVP system in `design/gdd/systems-index.md`. Update when systems are added.

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| EventBus | None — invisible to player | None | None | None | N/A | Infrastructure system, no direct player surface |
| Grid System | Cell type overlay colors | None (mouse-driven) | High — 5 cell types to learn during scout | None | Partial | Hatching patterns + cell-icon overlay (see Color-as-Only-Indicator Audit) |
| Save & Persistence | Save slot UI legibility | None | Low — 3 slots, clear naming | None | Not Started | Slot info readable at 100% UI scale |
| Hero | HP bar color; skill icon colors | Hold-to-skip-dialog (covered), 4 skill keys + ultimate (rebindable) | High — 12 stats to track | Hero auto-attack SFX (low criticality — automated) | Partial | Skill icons need distinct shapes per skill, not just colors |
| Tower | Archetype color | Mouse-driven placement (snap-to-cell — already accessible) | Medium — 4 archetypes × 4 component slots × 4 tiers (state-space high) | Tower fire SFX (informational only) | Partial | Archetype silhouettes per "Features explicitly in scope" |
| Monster | Tier color, HP bar color, status-effect aura colors | None | Medium — 3 tiers, multiple monster types per tier | Boss spawn / attack SFX (critical — visual backups required) | Partial | Tier-icon overlays + status-effect distinct icons (Color audit) |
| Damage & Status | Damage number colors (crit, normal, DoT) | None | Medium — 5 status effects interacting | DoT tick SFX (informational) | Partial | Crit shown via larger font + position; DoT numbers prefixed with effect icon |
| Pathfinding | Path visualization overlay color | None | Low — visual only when toggled | None | Partial | Path overlay uses hatching pattern in addition to color |
| Wave Manager | Wave counter color; phase indicator color | Pause-anywhere (committed) | High — 7-state FSM (per TR-wave-001); player needs phase clarity | Wave-start / wave-clear / wave-stuck SFX (all have visual backups) | Partial | Phase indicator shows text name, not just color |

---

## Accessibility Test Plan

| Feature | Test Method | Test Cases | Pass Criteria | Status |
|---------|------------|------------|--------------|--------|
| Text contrast ratios | Automated — contrast analyzer on UI screenshots | All text/background combos at all game states | Body ≥ 4.5:1; large ≥ 3:1; subtitles ≥ 7:1 | Not Started |
| Colorblind modes | Manual — Coblis simulator on screenshots with modes enabled | Scout phase, wave-active mid-fight, intermission, mission-complete in each mode | No essential information lost in any mode; player can identify tower archetypes, status effects, and monster tiers | Not Started |
| Input remapping | Manual — rebind all inputs to non-default, complete first mission | Default bindings; remapped bindings; binding conflict warning | All actions accessible after remap; conflict prevention works; persists across restart | Not Started |
| Subtitle accuracy | Manual — verify against any voiced content | All voiced content (if any added) | 100% coverage; ≤3s lag after line ends; speaker identified in multi-character scenes | Not Started |
| Hold-input toggles | Manual — enable all toggle alternatives, complete one mission | Hold-to-confirm-delete, hold-to-skip-dialog, hold-to-show-range | All actions completable in toggle mode; no state requires sustained hold | Not Started |
| Reduced motion mode | Manual — enable, complete one mission and navigate all menus | All transitions; HUD animations; camera shake events | No looping FX in menus; no screen shake; transitions are cross-fade or cut | Not Started |
| Color-as-only-indicator audit | Manual — disable color (greyscale screenshot), verify info | Every row in the Color audit table | All info readable in greyscale | Not Started |
| Critical-SFX visual backup audit | Manual — mute audio, complete one mission | Every row in the SFX audit table | All gameplay-critical info conveyed visually with audio muted | Not Started |
| User testing — colorblind | User testing with ≥1 colorblind participant (informal, via community) | Full mission with each mode | No session-stopping confusion | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Screen reader support for menus | Comprehensive | Solo-dev capacity; Godot 4.6 AccessKit requires per-Control accessible-name setup across every UI element, plus integration testing on multiple screen readers (NVDA, JAWS, Narrator) | Affects blind and low-vision players who can't read menu text even at maximum UI scale | Visual indicators + text size scaling cover low-vision players; fully blind players cannot play at v1.0. Re-evaluate for post-launch update. |
| Mono audio option | Comprehensive | Godot's AudioServer mono mixdown requires custom AudioEffectMono bus or per-output configuration | Affects players with single-sided deafness; spatial audio cues may be lost on one channel | All gameplay-critical audio has visual backups per SFX audit. No spatial audio is required to play. Stereo balance slider in settings as partial mitigation. |
| Full subtitle customization (font/color/background) | Comprehensive | Custom font rendering pipeline + extended settings UI is out of v1.0 scope | Affects deaf players with dyslexia or specific legibility needs | Two presets ("default" and "high-readability — larger, fully opaque background") provided as Standard compromise |
| HUD element repositioning | Comprehensive | HUD anchor system + drag/drop reposition UI is significant scope | Affects players using head-tracking, eye-gaze, or with reduced peripheral vision | UI scale slider partially helps (smaller HUD = closer to center). HUD is concentrated on bottom edge by default — re-evaluate after first playtests |
| Closed captions for gameplay-critical SFX | Comprehensive | Caption-display layer + per-SFX caption strings + spatial directional captions are significant scope | Affects deaf players relying on captions | Visual indicators for every gameplay-critical SFX (per Cognitive Accessibility section) are the Standard-tier substitute |
| Haptic alternatives for audio cues | Exemplary | Per-controller rumble API integration for non-Xbox PC controllers is fragmented and unverified | Affects deaf players relying on haptic feedback | Visual indicators cover deaf players; haptic is additive, not required |
| High contrast mode | Comprehensive | Replacing all semi-transparent UI with opaque equivalents requires a separate art pass | Affects low-vision players | Contrast ratios at AA on default palette + UI scale slider as partial mitigation |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Contrast and text sizing references |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Genre-specific checklist; primary reference for Standard tier scope |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | Future user-testing service if budget allows |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Free tool for colorblind mode verification |
| Godot 4.6 AccessKit notes | `docs/engine-reference/godot/VERSION.md` | Engine-side accessibility surface — track for Comprehensive-tier upgrade path |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does Godot 4.6 AccessKit support dynamic HUD updates, or only static menu narration? | self (research) | Before any Comprehensive-tier reconsideration | Unresolved — check engine-reference/godot/modules/ |
| Are the 4 tower archetype silhouettes distinguishable at the default zoom level on a 1080p display? | self (art prototype) | Before art bible Section 4 (Iconography) | Unresolved — depends on archetype concept art |
| Should "pause anywhere" include cutscenes? (No cutscenes currently in scope but anticipating.) | self | When narrative scope is decided | Default answer: yes — see Cognitive Accessibility |
| Does the color-coded cell type overlay during Scout phase need to also work in colorblind modes, or is the hatching backup sufficient? | self | First playtest with colorblind participant | Unresolved — assume hatching is sufficient for v1.0 |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-05-16 | self (initial commit) | Internal — Technical Setup gate | Tier commitment | Standard tier committed; 7 explicit deferrals documented; per-feature matrix populated for 9 MVP systems | In Progress |
