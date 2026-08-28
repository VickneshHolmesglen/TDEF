# Story 014 — Mechanical Pre-Verification (Godot MCP), 2026-08-28

> **This is NOT the human experiential playtest.** Story 014's own ACs require a real
> player's subjective debrief in their own words — this session cannot substitute for
> that, and doesn't try to. This document records what could be verified mechanically
> (does the plumbing work) via Godot MCP, run before the real human session per
> `production/qa/sanctuary-ui-playtest-protocol.md`, at the user's request to
> "mechanically verify it works."
>
> **Method**: `SanctuaryUI.tscn` run standalone via `mcp__godot__run_project`
> (background mode). Real simulated input, screenshots, and direct script
> introspection (`run_script`) against the live scene tree — not guesses.

## Summary

| Scenario | Mechanical result |
|---|---|
| OVERVIEW renders on entry | ✅ Confirmed — diorama, tab strip (6 entries), resource header chrome, Launch Mission button all present, no errors |
| Loadout hand-off (state machine) | ✅ Confirmed correct via direct method call |
| Loadout hand-off (real click) | ⚠️ Anomaly found — see below |
| Return from Tarot Deck UI to fresh OVERVIEW | ✅ Confirmed (via Cancel/Escape) |
| Connection Badge fires for a room other than the active one | ✅ Confirmed (state) |
| Connection Badge visual legibility | ⚠️ Could not confirm strong legibility — see below |

## 1. OVERVIEW state — confirmed working

Launched `SanctuaryUI.tscn` directly. Zero script errors on boot (`get_debug_output` clean). Screenshot confirmed: tab strip with all 6 entries (Overview/Inventory & Crafting/Menagerie/Defense Building/Forge/Loadout), Overview highlighted by default, diorama showing one built structure ("Castle" placeholder), Launch Mission button present.

## 2. Loadout hand-off — state machine confirmed correct, but real clicks land on the wrong tab

**State machine, verified via direct method call** (`tab_strip._on_button_pressed(5)`, bypassing UI hit-testing entirely): correctly set `_current_index = 5`, and `sanctuary_ui._active_state` became `DEPARTING_TO_LOADOUT`. The scene transitioned to `TarotDeckUIScene` (Hero Skill Build / Tarot Deck tabs, `Ultimate: EMPTY`, `Return to Sanctuary` button) — exactly as `tower-mastery.md`'s sibling GDD and `sanctuary-ui.md` Core Rule 10 specify. **This proves `TabStrip._select_index()` → `tab_target_selected` → `SanctuaryUI._on_tab_target_selected()` → `select_loadout()` is all correct when index 5 is genuinely delivered.**

**Real simulated clicks, however, consistently landed on the wrong tab.** Clicking the Loadout button — both via `click_element` (resolved by exact node path) and via a raw `mouse_button` event at the button's own reported screen coordinates (160, 392), well inside its (0,364)–(320,420) rect — opened the **Equipment Forge** room instead, with "Forge" (index 4) highlighted, not Loadout. **Reproduced identically 3 separate times**, across two different scene-mount contexts (direct `SanctuaryUI.tscn` launch, and the `SanctuaryScene`-wrapped instance after a real Cancel-triggered remount).

Engine-side inspection (`run_script`, reading `Button.get_global_rect()` directly from the live tree) confirmed the buttons' actual rects are correct and non-overlapping — index 4 (Forge) at y=304–360, index 5 (Loadout) at y=364–420, no z-index or `top_level` anomalies, `mouse_filter` normal on both. So the mismatch isn't an obvious rect/layout bug I could find by inspection.

**Important complicating factor, not glossed over**: a separate raw click on the *Menagerie* button (also at its own correct, verified coordinates) did **not register at all** — no state change, no error. This inconsistency (one button consistently "clicks the wrong thing," another button's click sometimes does nothing) is at least as consistent with **synthetic-input reliability limits in this specific MCP background-mode test harness** as with a genuine in-game click-routing defect — I do not have clean enough evidence to call this a confirmed shipping bug. Both explanations remain open:
- **If real**: a genuine click-hit-testing defect specific to (or most reproducible on) the Loadout tab, worth a code-level look at `TabStrip`'s button construction/event wiring under real pointer input.
- **If a harness artifact**: this MCP bridge's synthetic mouse events may not fully replicate Godot's real OS-level hover/click pipeline for this container.

**Flagged as a concrete thing for the real human playtest to specifically check**: per the playtest protocol, Debrief 2 already has the tester select Loadout — the protocol didn't previously specify click vs. hotkey. **Recommend the human session try both** (a real mouse click on the tab, and the `6` hotkey) and note if they diverge. Real physical input from an actual OS cursor is the only way to fully rule out the harness-artifact explanation.

## 3. Cancel/Escape from Tarot Deck UI — confirmed correct

Pressing `Escape` from Tarot Deck UI correctly returned to a **fresh** Sanctuary UI instance at `OVERVIEW` (new node instance IDs, confirmed via `get_ui_elements` — a genuinely new mount, not a cached return), matching Core Rule 5/10's documented re-entry behavior exactly. (Clicking the on-screen "Return to Sanctuary" button did not register in two attempts — same class of synthetic-input uncertainty as above, not investigated further since Escape's correctness was the thing that mattered mechanically.)

## 4. Connection Badge — mechanism confirmed, visual legibility unconfirmed

From `ROOM_MENAGERIE` (entered via direct method call, not click, to avoid the anomaly above), emitted `GEventBus.sanctuary_structure_built.emit("watchtower_02", "watchtower")` directly. Result, read back from the live tree:
- `tab_strip.is_badge_visible(3)` (Defense Building) → `true`
- `tab_strip.get_badge_count(3)` → `1`
- Menagerie's own badge count unaffected (`0`), active room unchanged (still Menagerie)

This is exactly Core Rule 2/9's specified behavior — a badge-triggering event for a room other than the active one lights up only that room's tab, with no cross-room content bleed. **Mechanically correct.**

**Visual legibility, however, could not be confirmed from the screenshot.** Direct inspection of the badge `Label` node found it real but very small: global rect `(319, 244)`, size `10×23px`, positioned at the extreme top-right corner of its 320×56px button (auto-sized to fit the digit "1" with `PRESET_TOP_RIGHT` anchoring and no explicit minimum size). It did not read as clearly visible in the full-resolution screenshot at a glance. This is not asserted as a bug — screenshot compression and this build's placeholder art could both be factors, and "is it actually noticeable" is a genuine human-perception question, not something I can determine from a static image. **This is precisely what the real playtest's Debrief 3 exists to answer** — flagging it here as a reason to look closely, not as a pre-judged verdict.

## What this changes for the real playtest

- Story 014 stays open — nothing here substitutes for the human debrief.
- Two things worth the tester's specific attention beyond the protocol's original wording: (1) try selecting Loadout by both mouse click and the `6` hotkey, note if they behave differently; (2) look closely at the Defense Building tab's corner after triggering a badge — it's real, but easy to miss.
