# UX Spec: Main Menu

> **Status**: In Design
> **Author**: Vicknesh + ux-designer
> **Last Updated**: 2026-07-06
> **Journey Phase(s)**: Pre-game / Session Start (no formal `design/player-journey.md` exists yet — placeholder pending a journey mapping session)
> **Template**: UX Spec

---

## Purpose & Player Need

The player arrives at the Main Menu wanting to **get back into a mission as fast as possible** — this is the single most common intent for a returning player, so "Continue" (or its Mission Select equivalent) must be the most prominent, fastest-to-reach action on the screen, not buried behind decorative framing.

The screen fails if a player either (a) cannot immediately tell whether a save exists and where their progress is, or (b) faces the EC-3 crash-recovery choice ("Load last Sanctuary save" vs. "Restore from checkpoint") without enough information to make a confident, low-anxiety decision. Since Save & Persistence's own GDD explicitly delegates save-slot selection, save confirmation, and the EC-3 recovery dialog to this screen (`design/gdd/save-persistence.md`, UI Requirements), ambiguity here has a real data-loss consequence, not just an annoyance.

---

## Player Context on Arrival

The Main Menu has exactly one real entry path: **cold app launch**. Per `game-concept.md`'s state table, `SANCTUARY`'s entry condition is "Mission ends (win) or first launch" — meaning a completed or failed mission returns the player directly to Sanctuary, never back through Main Menu. Main Menu is a true top-level, pre-game screen, not a hub players cycle through repeatedly during a session.

The assumed emotional state is **calm and neutral-to-eager** — the player just opened the app and hasn't yet re-entered the game's fiction. They are not time-pressured, not mid-decision, and not recovering from a combat outcome. Arrival is always voluntary (launching the executable).

---

## Navigation Position

Main Menu is the **root of the navigation hierarchy** — nothing sits above it. It is reached at app launch, and can also be reached via a "Quit to Main Menu" action available from within Sanctuary. It is not reachable from an active mission — missions have no exit-to-menu path per `game-concept.md`'s state table (WAVE_ACTIVE/SCOUT/INTERMISSION only exit via wave-clear, defeat, or the mission's own terminal transitions).

`Main Menu (root)` → `Mission Select` / `Sanctuary` (via Continue) — both are one level below Main Menu, not siblings of it.

---

## Entry & Exit Points

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Cold app launch | Executable start | None — first screen the player sees |
| Sanctuary | "Quit to Main Menu" action | None — a full return to root; Sanctuary state is already persisted before this action is available |

| Exit Destination | Trigger | Notes |
|---|---|---|
| Sanctuary | "Continue" (existing save found) | Loads the most recent `save_slot_N.dat` directly — no slot picker if only one save exists |
| Sanctuary | "Load Game" → slot selection → confirm | Player explicitly picks a slot; multi-save support |
| Sanctuary | "New Game" → (confirm overwrite if slot occupied) → confirm | **Irreversible if a save exists in the target slot** — overwriting an occupied slot must require an explicit confirmation dialog naming what will be lost |
| Sanctuary or checkpoint-restored Mission state | EC-3 recovery choice: "Load last Sanctuary save" or "Restore from checkpoint" | Only appears when both `save_slot_N.dat` and `save_slot_N_checkpoint.dat` exist on load (post-crash) — per `save-persistence.md` EC-3, the checkpoint is deleted after either choice is made |
| — (no destination) | Settings | Non-exiting overlay — returns to Main Menu on close, does not navigate away |
| Application closed | Quit | Terminates the app — no save-on-quit expected here, saves are already event-driven (AC-3/AC-4 in `save-persistence.md`) |

---

## Layout Specification

### Information Hierarchy

1. **Primary**: Continue (or New Game, if no save exists) — the fastest path back into play
2. **Secondary** (equal weight): Load Game, Settings
3. **Tertiary/discoverable**: Quit, version/build info

### Layout Zones

A vertical stacked action-list, left-anchored to the lower-left third of the screen, with full-bleed background art (Sanctuary diorama or hero silhouette per Art Bible Section 1's centerpiece framing) filling the remaining space. Buttons use the chamfered-rectangle UI grammar from Art Bible Section 7.1, in UI Chrome/Parchment colors (never world-saturation colors, per 7.1's binding constraint). Gamepad d-pad navigation order is top-to-bottom matching the visual stack.

### Component Inventory

| Zone | Component | Type | Content | Interactive | Pattern |
|---|---|---|---|---|---|
| Action list | Continue button | Button | "Continue" label; label swaps to "New Game" if no save exists | Yes | New — not a formal pattern; a simple state-driven label swap (save exists ↔ no save), distinct from pattern #3's phase-gated active/inactive presentation of a single fixed label |
| Action list | Load Game button | Button | "Load Game" label | Yes | New — navigates to slot-selection sub-view |
| Action list | New Game button | Button | "New Game" label; only primary-positioned when no save exists, otherwise demoted below Continue | Yes | New |
| Action list | Settings button | Button | "Settings" label | Yes | New — opens non-exiting overlay |
| Action list | Quit button | Button | "Quit" label | Yes | New |
| Background | Diorama/hero art | Static art panel | Full-bleed background per Art Bible Section 1 | No | — |
| Footer | Version/build label | Text label | Build number, small, low-contrast | No | New |
| Overlay (conditional) | Slot selection panel | Modal panel | List of save slots with timestamp/summary per slot | Yes | New |
| Overlay (conditional) | New Game overwrite confirmation | Modal dialog | "This will overwrite [slot]. Continue?" Yes/Cancel | Yes | New |
| Overlay (conditional) | EC-3 recovery choice dialog | Modal dialog | "Load last Sanctuary save" / "Restore from checkpoint" | Yes | New |

Three new patterns are introduced here (Modal Panel/Dialog family) that aren't yet in `interaction-patterns.md` — flagged for the pattern-library gap check at the end of this spec.

### ASCII Wireframe

```
+--------------------------------------------------------------+
|                                                                |
|                                                                |
|                    [ full-bleed diorama /                     |
|                      hero background art ]                    |
|                                                                |
|                                                                |
|  +--------------------+                                       |
|  | > CONTINUE         |                                       |
|  +--------------------+                                       |
|  | LOAD GAME          |                                       |
|  +--------------------+                                       |
|  | NEW GAME           |                                       |
|  +--------------------+                                       |
|  | SETTINGS            |                                       |
|  +--------------------+                                       |
|  | QUIT                |                                       |
|  +--------------------+                                       |
|                                                                |
| v0.1.0                                                         |
+--------------------------------------------------------------+
```

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| Default (has save) | At least one valid save slot exists | Continue is primary and prominent; Load Game visible |
| Empty (no save) | No save file exists in any slot | Continue is replaced by New Game as the primary action; Load Game is hidden or disabled (nothing to load) |
| Loading | Brief check for save files on boot | Simple spinner or fade-in delay before the action list becomes interactive — should resolve well under 1 second on local disk I/O |
| Corrupt save (EC-5) | A slot's `.dat` file failed to load and was renamed `save_slot_N.corrupt` per `save-persistence.md` EC-5 | The affected slot shows a non-blocking warning badge in the Load Game slot-selection list ("Could not be loaded — reset to defaults"); does not block access to other slots |
| EC-3 recovery pending | Both `save_slot_N.dat` and `save_slot_N_checkpoint.dat` exist for the slot being loaded | Recovery choice dialog appears before entering Sanctuary — this is a modal interrupt on top of whichever entry action triggered the load |

---

## Interaction Map

| Component | Action | K/M Input | Gamepad Input | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| Continue button | Activate | Left click | A / South face | Button press-state flash (100ms) | Loads most recent save slot → transitions to Sanctuary |
| Load Game button | Activate | Left click | A / South face | Button press-state flash | Opens Slot Selection modal panel |
| New Game button | Activate | Left click | A / South face | Button press-state flash | If target slot occupied → opens Overwrite Confirmation modal; else → transitions directly to Sanctuary (fresh save) |
| Settings button | Activate | Left click | A / South face | Button press-state flash | Opens Settings overlay (non-exiting; returns to Main Menu on close) |
| Quit button | Activate | Left click | A / South face | Button press-state flash | Terminates application (no confirmation dialog — no unsaved state exists at Main Menu; saves are event-driven per `save-persistence.md` AC-3/AC-4) |
| Focus navigation (gamepad only) | Move focus between buttons | N/A | D-pad / left stick, top-to-bottom order matching visual stack | Focus outline ≥3px on focused button | Changes focused element; no state change |
| Slot Selection modal — slot card | Select a save slot | Left click on card | A on focused card | Card highlight | Loads chosen slot → transitions to Sanctuary (or shows corrupt-slot warning badge per EC-5 state, non-blocking) |
| Slot Selection modal — dismiss | Cancel/back | Esc or click outside modal | B / East face | Modal fades out | Returns to Main Menu, no slot loaded |
| Overwrite Confirmation — Confirm | Accept overwrite | Left click "Yes" | A on focused "Yes" | Button press-state flash | Overwrites target slot → transitions to Sanctuary (fresh save) |
| Overwrite Confirmation — Cancel | Reject overwrite | Left click "Cancel" or Esc | B / East face | Modal fades out | Returns to Main Menu, no data changed |
| EC-3 Recovery — "Load last Sanctuary save" | Choose recovery path | Left click | A on focused option | Button press-state flash | Loads `save_slot_N.dat`; checkpoint file deleted per `save-persistence.md` EC-3 |
| EC-3 Recovery — "Restore from checkpoint" | Choose recovery path | Left click | A on focused option | Button press-state flash | Loads `save_slot_N_checkpoint.dat`; checkpoint file deleted per EC-3 |

**No dismiss/cancel on EC-3 Recovery**: intentional — the dialog fires only when the game must resolve which save state to use before entering Sanctuary; there is no valid "do nothing" outcome.

**New patterns surfaced**: `Modal Dialog (decision required)` (Overwrite Confirmation, EC-3 Recovery) and `Save Slot Card` (Slot Selection) — both already flagged as gaps in `interaction-patterns.md`; this spec is the first consumer, so they'll be formalized in the pattern library during the cross-reference check.

---

## Events Fired

| Player Action | Event Fired | Payload / Data |
|---|---|---|
| Continue | Save & Persistence load-trigger (exact EventBus signal name owned by `save-persistence.md`, not this spec) | `slot_index` |
| Load Game → select slot | same load-trigger as above | `slot_index` |
| New Game (no overwrite) | Save & Persistence save-creation trigger | `slot_index` (new/empty) |
| New Game → Overwrite Confirm | save-creation trigger | `slot_index`, `overwrite: true` |
| EC-3 → "Load last Sanctuary save" | load-trigger | `slot_index`, `source: "save"` |
| EC-3 → "Restore from checkpoint" | load-trigger | `slot_index`, `source: "checkpoint"` |
| Settings open/close | none | — (no persistent state change; overlay only) |
| Quit | none | — (app termination, not a game event) |

**Ownership note**: per `save-persistence.md`'s UI Requirements ("Save & Persistence does not own any UI... UI systems present them"), the reverse is also true here — Main Menu triggers Save & Persistence's load/save flow but does not own or name its EventBus signals. This spec documents *that* a trigger point exists at each action above; the literal signal name is Save & Persistence's responsibility to define.

---

## Transitions & Animations

| Transition | Behavior |
|---|---|
| Screen enter (cold launch) | Instant pop with background art already visible; button stack fades in over 300ms, staggered top-to-bottom (50ms per button) |
| Screen enter (from Sanctuary "Quit to Main Menu") | Cross-fade over 400ms |
| Screen exit → Sanctuary | Fade to black over 300ms, then Sanctuary loads |
| Settings overlay open/close | Slide up from bottom over 250ms / slide down to dismiss |
| Slot Selection modal open/close | Scale-and-fade in from 95%→100% over 200ms / fade out over 150ms |
| Overwrite Confirmation modal open/close | Same modal pattern as Slot Selection (scale-and-fade) |
| EC-3 Recovery modal open | Scale-and-fade in — same modal pattern; no separate exit animation since it always resolves via a choice, never a dismiss |
| Loading state (boot save-check) | Simple fade-in of button stack once save-check resolves |

**Reduced-motion mode** (per `design/accessibility-requirements.md`'s Motion / animation reduction commitment): all slide/scale/stagger animations collapse to instant cut or simple cross-fade only — no staggering, no slide distance.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Save slot existence/count | Save & Persistence | Read | Determines Default vs Empty state (Continue vs New Game primary) |
| Save slot metadata (timestamp, summary) | Save & Persistence | Read | Populates Slot Selection cards |
| Save slot corrupt flag (EC-5) | Save & Persistence | Read | Drives the non-blocking warning badge |
| Checkpoint file existence | Save & Persistence | Read | Determines whether EC-3 Recovery dialog appears |
| Build/version number | Project config | Read | Footer label |
| Slot selection choice | Save & Persistence | Write (trigger) | Player's choice on Load Game / New Game / EC-3 |

No architectural concerns flagged — Main Menu is read-heavy; its only "writes" are trigger calls into Save & Persistence, which already owns all disk I/O per its own GDD (`save-persistence.md` AC-1).

---

## Accessibility

- **Keyboard/gamepad navigation**: all buttons reachable via D-pad/left-stick top-to-bottom order matching the visual stack (per Interaction Map); no mouse-only interactive elements.
- **Text contrast**: button labels and footer version text meet ≥4.5:1 (body) per the project's Standard-tier commitment. The version label is low-contrast by design intent but still must clear AA — achieved via a darker/lighter palette variant, not by dropping below the ratio.
- **Text size**: button labels ≥24px minimum per the Standard tier's "Minimum text size — menu UI" row. Footer version text may be smaller but remains legible — it's exempt from the "critical HUD" tier, not from readability.
- **Color-independent communication**: no state on this screen relies on color alone. The Continue↔New Game swap is driven by label text change, not color; the EC-5 corrupt-slot warning uses a badge + text, not a color shift alone.
- **Reduced motion**: covered in Transitions & Animations — collapses stagger/slide to cross-fade or cut.
- **Focus indicator**: ≥3px outline at high contrast on the focused button, matching the pattern library's `State-Gated Action Button` accessibility spec (applies here even though these buttons aren't phase-gated — the focus-indicator requirement is general).
- **Modal focus trapping**: while Slot Selection / Overwrite Confirmation / EC-3 Recovery is open, gamepad/keyboard focus is trapped within the modal — background Main Menu buttons are not reachable until the modal closes.
- **Known accepted limitation**: no screen-reader support (Comprehensive tier, deferred per `design/accessibility-requirements.md`) — not a gap in this spec, a project-wide deferral.

---

## Localization Considerations

- **Longest text elements**: button labels ("SETTINGS", "LOAD GAME") and the EC-3 recovery dialog's two option labels ("Load last Sanctuary save" / "Restore from checkpoint") — the latter are full sentences and the highest expansion risk on this screen.
- **Layout-critical elements**: button width sized to the longest expected translation, not the English baseline — German/French commonly expand 30–40%. Use a minimum width buffer or an auto-shrink font floor; never truncate a button label.
- **EC-3 dialog option text (HIGH PRIORITY)**: these two strings are the riskiest on the screen — full-sentence buttons wrap poorly if not planned for. Dialog buttons must support 2-line wrap rather than fixed single-line; truncating a data-recovery choice is unacceptable.
- **Numbers/dates**: save slot timestamps in the Slot Selection cards need locale-specific date/time formatting (not hardcoded MM/DD/YYYY).
- **Version label**: build number format is locale-independent (numeric/semver) — no concern.

---

## Acceptance Criteria

- [ ] Main Menu opens within 1 second of app launch, including the save-file existence check
- [ ] When at least one valid save exists, "Continue" is the primary (top, most prominent) action; when no save exists, "Continue" is replaced by "New Game" as the primary action
- [ ] Selecting "Continue" or a Slot Selection card correctly transitions to Sanctuary with the chosen save loaded
- [ ] Attempting "New Game" on an occupied slot shows the Overwrite Confirmation dialog naming the target slot before any data is overwritten
- [ ] A corrupt save slot (EC-5) shows a non-blocking warning badge in Slot Selection without preventing access to other slots
- [ ] When both a save and a checkpoint file exist on load, the EC-3 Recovery dialog appears before Sanctuary loads, and selecting either option correctly loads the corresponding data and deletes the checkpoint file
- [ ] All interactive elements (buttons, modal options) are reachable and activatable via gamepad D-pad/stick + A/B, with no mouse-only element
- [ ] Focus indicator is visible and ≥3px at high contrast on every focusable element

---

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Should Quit have a confirmation dialog? | user | Current spec has none (no unsaved-state risk at Main Menu). Flagged for explicit sign-off since it's a minor but real UX choice. |
| Is "no cancel/dismiss on EC-3 Recovery" correct, or should there be a safe fallback? | user | Current spec treats this as intentional (no valid "do nothing" state). Confirm before implementation. |
| Should a formal `design/player-journey.md` be authored before other screens are specced? | self | This spec proceeded with a placeholder Journey Phase. Recommend running a player journey session soon — future screens will hit the same gap. |
