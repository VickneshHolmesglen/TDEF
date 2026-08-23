# UX Spec: Pause Menu

> **Status**: In Design
> **Author**: Vicknesh + ux-designer
> **Last Updated**: 2026-07-07
> **Implementation note (2026-08-23)**: `src/gameplay/ui/pause_menu/pause_menu.gd`/`.tscn` now implement the full button set this spec describes (Resume, Settings, Objective, Quit to Sanctuary, Quit to Main Menu) — the original 2026-07-08 reduced-scope build (Resume + Quit to Sanctuary only) deferred Settings/Objective/Quit to Main Menu specifically because Settings, Objective (`MissionResource.objective_text`, TD-mission-001), and a real Main Menu scene didn't exist as systems yet. All 3 now do. One intentional deviation from this spec, not silently applied: Quit to Sanctuary still has no confirmation dialog (its already-shipped 2026-07-08 behavior, left unchanged); Quit to Main Menu got the confirmation this spec's Interaction Map describes. This status line itself is unchanged (`In Design`) — this note records implementation state, not a formal `/design-review` sign-off.
> **Journey Phase(s)**: Mid-mission / any active gameplay phase (no formal `design/player-journey.md` exists yet — placeholder pending a journey mapping session)
> **Template**: UX Spec

---

## Purpose & Player Need

The player arrives at the Pause Menu wanting to **safely halt gameplay without losing progress or missing information** — this is a utility screen, not a destination players seek out for its own sake. Four distinct player intents converge here:

1. **"I need to step away"** — Resume is the single most common exit from this screen.
2. **"Something's wrong with sound/controls, let me fix it now"** — Settings access without abandoning the mission.
3. **"I want out of this mission attempt"** — Quit to Sanctuary/Main Menu, an intentionally-effortful path since it discards mission progress.
4. **"Wait, what am I supposed to be doing?"** — Objective reference, satisfying `design/accessibility-requirements.md`'s committed Objective Clarity requirement ("current mission objective accessible within 2 button presses"). **Descoped 2026-07-07**: the accessibility doc's separate Tutorial Persistence commitment ("dismissed tutorial prompts retrievable from a Help section in the pause menu") is intentionally NOT covered by this screen — see Open Questions.

The screen fails if:
- **(a)** the player cannot pause and un-pause instantly and reliably in every mission state, including mid-boss-fight — per `design/accessibility-requirements.md`'s "pause anywhere, including mid-wave, with no penalty." This is the single hardest requirement this screen must never violate.
- **(b)** Quit-to-Sanctuary is either too easy (accidental mission abandonment) or too hard to find (players trapped in a mission they want to leave).
- **(c)** the Objective path takes more than the committed 2 button presses to reach.

---

## Player Context on Arrival

Pause is reachable from every mission state — `SCOUT`, `WAVE_ACTIVE`, `INTERMISSION`, `MISSION_COMPLETE`, `DEFEAT` — per `design/accessibility-requirements.md`'s Motor Accessibility commitment ("No 'cannot pause during boss' exception"). This means the assumed emotional state is not singular:

- **Paused during `WAVE_ACTIVE`** (most consequential): high combat stress, possibly mid-boss-fight. The player needs to reorient instantly on resume — the screen must not disrupt their mental model of the fight.
- **Paused during `SCOUT`/`INTERMISSION`**: calm, planning mindset — pausing here is closer to Main Menu's neutral arrival.
- **Paused during `MISSION_COMPLETE`/`DEFEAT`**: reviewing an outcome — pausing here is unusual (the screen already shows a resolution) but not disallowed.

Arrival is always voluntary (player-initiated pause input) — the game never auto-pauses and forces this screen open.

**Design implication**: because `WAVE_ACTIVE` pausing is both the most common and highest-stress case, the screen's design defaults to the WAVE_ACTIVE assumption (fast resume, minimal reorientation cost) rather than the calmer SCOUT case.

---

## Navigation Position

Pause Menu is a **modal overlay reachable from within any active mission phase**, not a top-level navigation destination — it sits *above* the mission, not beside Main Menu or Sanctuary in the hierarchy. It has no "position" in the sense Main Menu does; it functions as an interrupt layer.

`Mission (any phase)` → `Pause Menu` (overlay) → back to `Mission (same phase, same state)` on Resume, or → `Sanctuary` / `Main Menu` on Quit (mission state discarded).

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Any mission phase (SCOUT, WAVE_ACTIVE, INTERMISSION, MISSION_COMPLETE, DEFEAT) | Pause input (Esc / gamepad Start/Options) | Full mission state — paused in place, not reset |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Same mission, same phase | Resume | Instant — no loading, no state change |
| Settings overlay | "Settings" button | Non-exiting sub-overlay, layered on top of Pause Menu; returns to Pause Menu on close |
| Objective panel | "Objective" button | Non-exiting sub-panel; returns to Pause Menu on close |
| Sanctuary | "Quit to Sanctuary" → confirmation dialog → confirm | **Irreversible for this mission attempt** — per `game-concept.md`'s DEFEAT semantics, Sanctuary tech/crafted items/menagerie state are unaffected, but current in-mission progress (wave reached, towers placed this attempt) is discarded. Confirmation dialog must say so explicitly. |
| Main Menu | "Quit to Main Menu" → confirmation dialog → confirm | Same discard-of-mission-progress consequence as above, plus leaves the play session entirely |

---

## Layout Specification

### Information Hierarchy

1. **Primary**: Resume — fastest path back into play, especially critical since WAVE_ACTIVE is the highest-stress arrival case
2. **Secondary** (equal weight): Settings, Objective
3. **Tertiary/de-emphasized**: Quit to Sanctuary, Quit to Main Menu — deliberately lower visual weight and requiring confirmation, per the "must not be too easy" failure mode from Purpose & Player Need

### Layout Zones

Same vertical stacked action-list convention as Main Menu (Art Bible Section 7.1 chamfered-rectangle grammar), centered over a dimmed/blurred freeze-frame of the mission scene (not a separate background image) — this reinforces "you're still in the mission, just paused" rather than feeling like a trip to a different screen.

### Component Inventory

| Zone | Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|---|
| Action list | Resume button | Button | "Resume" label | Yes | Existing — plain button |
| Action list | Settings button | Button | "Settings" label | Yes | Existing — opens overlay |
| Action list | Objective button | Button | "Objective" label | Yes | New — opens sub-panel |
| Action list | Quit to Sanctuary button | Button, de-emphasized styling | "Quit to Sanctuary" label | Yes | Composes with `Modal Dialog (decision required)` |
| Action list | Quit to Main Menu button | Button, de-emphasized styling | "Quit to Main Menu" label | Yes | Composes with `Modal Dialog (decision required)` |
| Background | Dimmed mission freeze-frame | Static frozen game view + dim/blur overlay | The paused mission scene itself | No | New |
| Overlay (conditional) | Quit confirmation dialog | Modal dialog | "You'll lose progress in this attempt. Continue?" Yes/Cancel | Yes | `Modal Dialog (decision required)` — reused from Main Menu |
| Overlay (conditional) | Objective panel | Modal panel | Current objective text | Yes | New |

### ASCII Wireframe

```
+--------------------------------------------------------------+
|     [ dimmed / blurred freeze-frame of the paused mission ]  |
|                                                                |
|                  +--------------------+                       |
|                  | > RESUME           |                       |
|                  +--------------------+                       |
|                  | SETTINGS           |                       |
|                  +--------------------+                       |
|                  | OBJECTIVE          |                       |
|                  +--------------------+                       |
|                  | quit to sanctuary  |   <- de-emphasized     |
|                  +--------------------+                       |
|                  | quit to main menu  |   <- de-emphasized     |
|                  +--------------------+                       |
|                                                                |
+--------------------------------------------------------------+
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Default | Paused during SCOUT/WAVE_ACTIVE/INTERMISSION | Full button set: Resume, Settings, Objective, Quit to Sanctuary, Quit to Main Menu |
| Paused during MISSION_COMPLETE/DEFEAT | Player pauses on an already-resolved outcome screen | Unresolved — see Open Questions. Unclear whether Quit options still make sense here since the mission is already transitioning to Sanctuary automatically. |
| Settings sub-overlay open | Player selects Settings | Pause Menu remains visible behind; Settings overlay layers on top |
| Objective sub-panel open | Player selects Objective | Pause Menu remains visible behind; panel layers on top |
| Quit confirmation pending | Player selects either Quit option | Confirmation modal blocks input until resolved |

---

## Interaction Map

| Component | Action | K/M Input | Gamepad Input | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| Pause trigger (opens this screen) | Toggle pause | Esc | Start/Options | Game freezes instantly; dim/blur applies over ~150ms | Opens Pause Menu |
| Resume button | Activate | Left click, or Esc again | A / South face, or Start/Options again | Button press-state flash | Closes Pause Menu, unfreezes game instantly |
| Settings button | Activate | Left click | A / South face | Button press-state flash | Opens Settings sub-overlay |
| Objective button | Activate | Left click | A / South face | Button press-state flash | Opens Objective sub-panel |
| Quit to Sanctuary button | Activate | Left click | A / South face | Button press-state flash | Opens Quit confirmation modal |
| Quit to Main Menu button | Activate | Left click | A / South face | Button press-state flash | Opens Quit confirmation modal |
| Quit confirmation — Confirm | Accept quit | Left click "Yes" | A on focused "Yes" | Button press-state flash | Discards in-mission progress → transitions to Sanctuary or Main Menu |
| Quit confirmation — Cancel | Reject quit | Left click "Cancel" or Esc | B / East face | Modal fades out | Returns to Pause Menu, mission still paused |
| Objective panel — dismiss | Close panel | Esc or click outside | B / East face | Panel fades out | Returns to Pause Menu |

**Toggle convention**: the same pause input (Esc / Start-Options) both opens AND closes the Pause Menu — pressing it again resumes without navigating to the Resume button. This mirrors how players expect pause to behave and reduces friction for the highest-frequency case (quick pause/unpause).

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Pause triggered | `game_paused` (EventBus — bus-wide, not just this screen's concern) | none |
| Resume | `game_unpaused` (EventBus) | none |
| Quit to Sanctuary | Mission-abandon trigger (exact signal name owned by Wave Manager / Save & Persistence, not this spec) | `outcome: "abandoned"` |
| Quit to Main Menu | Same mission-abandon trigger, plus a scene-transition trigger to Main Menu | `outcome: "abandoned"` |
| Settings/Objective open/close | none | — (no persistent or bus-wide state change) |

**Ownership note**: `game_paused`/`game_unpaused` are the one case where this screen genuinely triggers a bus-wide event, not just a screen-local one — every timer-driven system (Wave Manager phase timers, spawn coroutines, hero auto-attack) must subscribe and halt on this signal. This is an architecture dependency worth flagging explicitly, not assuming it already exists — confirm with Wave Manager/architecture before implementation.

---

## Transitions & Animations

| Transition | Behavior |
|---|---|
| Pause triggered (screen enter) | Dim/blur overlay fades in over 150ms; button stack fades in over 200ms (no stagger — speed matters more here than Main Menu's ceremonial feel) |
| Resume (screen exit) | Reverse — overlay fades out over 150ms, game unfreezes the instant the fade completes |
| Settings sub-overlay open/close | Same slide-up/slide-down convention as Main Menu (250ms) |
| Objective panel open/close | Scale-and-fade, matching `Modal Dialog` pattern conventions (200ms in / 150ms out) |
| Quit confirmation modal open/close | `Modal Dialog (decision required)` pattern — scale-and-fade |

**Reduced-motion mode**: all fades/scales collapse to instant show/hide, consistent with Main Menu's commitment. Given how frequently this screen opens/closes (far more than Main Menu), instant response under reduced motion is especially valuable here.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Current mission phase | Wave Manager | Read | Determines whether the MISSION_COMPLETE/DEFEAT variant applies (see Open Questions) |
| Frozen mission frame (for dim/blur background) | Rendering/current scene | Read | Not a data value — a captured frame; no system needs to "provide" this beyond existing render output |
| Current mission objective text | `MissionResource` (small follow-up story scoped 2026-07-07 — see Open Questions) | Read | Same missing-`MissionResource` gap already flagged in the Wave Manager epic (Story 006/EPIC.md); a small dedicated story to add a minimal `MissionResource` is being scoped rather than deferred indefinitely. |
| `game_paused` / `game_unpaused` trigger | This screen → EventBus (broadcast) | Write | See Events Fired ownership note |

---

## Accessibility

- **Pause-anywhere commitment**: this screen's very existence, reachable identically from every mission phase with the same input, IS the direct implementation of `design/accessibility-requirements.md`'s Motor Accessibility "Pause anywhere" row — this isn't a checklist item to satisfy, it's this screen's core reason for being.
- **Keyboard/gamepad navigation**: all buttons reachable via D-pad/stick, same top-to-bottom convention as Main Menu.
- **Text contrast/size**: button labels ≥24px, meeting ≥4.5:1 contrast against the dimmed mission background. Contrast must be verified against the *dimmed/blurred* backdrop specifically, not a flat color — this is a risk Main Menu didn't have, since the backdrop is dynamic per-mission content, not a fixed art panel.
- **Color-independent communication**: the de-emphasized styling on Quit buttons must not rely on color alone to read as "lower priority" — use reduced size/weight or secondary iconography alongside any color choice.
- **Focus indicator**: ≥3px, same convention as Main Menu.
- **Modal focus trapping**: Quit confirmation and Objective panel both trap focus while open, same as Main Menu's modals.
- **One-hand mode**: the pause input itself (Esc / Start) must be reachable one-handed per the Motor Accessibility "One-hand mode" commitment — already true by default for standard keyboards/gamepads.
- **Known accepted limitation**: no screen-reader support (Comprehensive tier, deferred per `design/accessibility-requirements.md`).

---

## Localization Considerations

- **Longest text elements**: "Quit to Sanctuary" / "Quit to Main Menu" button labels, and the Quit confirmation dialog's message text ("You'll lose progress in this attempt. Continue?") — the confirmation text is the highest-risk element since it's actionable and must never truncate.
- **Layout-critical elements**: same button-width buffer approach as Main Menu — size for expected translation expansion (30–40%), never truncate a button label.
- **Confirmation dialog text (HIGH PRIORITY)**: must support multi-line wrap, matching the same rule established for Main Menu's EC-3 dialog — this is a data-loss-adjacent decision, truncation is unacceptable.
- **Objective text**: length is content-dependent (mission-specific), not fixed — the Objective panel layout should accommodate variable-length text per mission/locale, not assume a fixed line count.
- **Numbers/dates**: none on this screen.

---

## Acceptance Criteria

- [ ] Pause input opens Pause Menu within 1 frame from any mission phase (SCOUT, WAVE_ACTIVE, INTERMISSION, MISSION_COMPLETE, DEFEAT), including mid-boss-fight
- [ ] Resume (button or repeated pause input) closes Pause Menu and unfreezes gameplay within 1 frame, with no state loss
- [ ] Quit to Sanctuary/Main Menu requires an explicit confirmation naming that mission progress will be lost before executing
- [ ] Canceling the Quit confirmation returns to Pause Menu with the mission still paused and no state changed
- [ ] All interactive elements are reachable and activatable via gamepad D-pad/stick + A/B, with no mouse-only element
- [ ] Focus indicator is visible and ≥3px at high contrast on every focusable element
- [ ] `game_paused`/`game_unpaused` correctly halts and resumes all timer-driven systems (Wave Manager phase timers, spawn coroutines, hero auto-attack) with no time drift across a pause/resume cycle

---

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Should Quit to Sanctuary/Main Menu even appear when paused during MISSION_COMPLETE/DEFEAT? | user | Mission is already auto-transitioning to Sanctuary in those phases — Quit may be redundant or confusing there. |
| Who owns mission objective text, and where does it come from? | technical-director / game-designer | **IN PROGRESS 2026-07-07**: no `MissionResource` currently exists — same gap already flagged in the Wave Manager epic (Story 006). User decision: scope a small, focused follow-up story for a minimal `MissionResource` (objective text field + load path) rather than defer indefinitely, since Mission Select and Mission HUD will eventually need the same data. Story not yet authored. |
| Does a tutorial/help-prompt system exist or need to be built? | technical-director | **DESCOPED 2026-07-07**: user decision — removing the Help/tutorial-prompt-retrieval requirement from this screen entirely rather than building toward a whole tutorial-persistence system for one button. `design/accessibility-requirements.md`'s Tutorial Persistence commitment ("dismissed tutorial prompts retrievable from a Help section in the pause menu") remains a real, tracked project commitment — just not satisfied by this screen. Re-add an Objective/Help button here once a real tutorial system is designed elsewhere (`systems-index.md` confirms none has started). |
| Does a bus-wide `game_paused`/`game_unpaused` EventBus signal already exist, or does this spec introduce a new architectural dependency? | godot-specialist / lead-programmer | **RESOLVED 2026-07-07 — confirmed absent.** A full codebase search (`src/`, `event-bus.md`, ADR-0002) found zero references to `game_paused`, `game_unpaused`, or `SceneTree.paused`/`get_tree().paused` anywhere. This is not just a missing signal — **no pause mechanism of any kind exists yet** in this codebase. Given `design/accessibility-requirements.md` commits to "pause anywhere, including mid-wave, with no penalty" as a Standard-tier feature already in scope, this is a real, unimplemented gap, not just an unconfirmed detail. Tracked as `TD-pause-001` in `docs/tech-debt-register.md`. |
| Should `Journey Phase(s)` stay unresolved? | self | Same gap as Main Menu — no `design/player-journey.md` exists yet. |
