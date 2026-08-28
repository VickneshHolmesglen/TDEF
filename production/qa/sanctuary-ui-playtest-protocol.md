# Playtest Protocol — Sanctuary UI Experiential Pass (S9-02)

> **Purpose**: A single, self-contained session protocol for Vicknesh to run as playtester,
> answering the three experiential questions Story 014 explicitly left blocked on a real
> human debrief. Like the Tower Mastery protocol, this is a designer self-playtest — not a
> blind-discoverability test — because these three questions are about whether an
> already-fully-built shell (Stories 001–013, all Done) *lands* emotionally and legibly, not
> whether a first-time player can figure it out. You already know exactly what the shell is
> supposed to do; the job here is to notice, honestly, whether it actually does that.
>
> **Story this closes**: `production/epics/epic-10-sanctuary-ui/story-014-experiential-playtest.md`
> **GDD**: `design/gdd/sanctuary-ui.md` — read the Player Fantasy section ("The Curator of Your Own Cabinet," lines 13–21) before playing. All three debrief questions below trace directly to specific claims in that section and in Core Rules 2, 5, 9, and 10.
> **Evidence doc required**: `production/qa/evidence/story-014-experiential-playtest-evidence.md` — the story explicitly requires the player's own words as evidence, not a bare pass/fail. This protocol's report template captures that.

---

## What This Session Is and Isn't

Story 014's own Acceptance Criteria are phrased as "GIVEN ... WHEN debriefed afterward, THEN the player can articulate/describe/correctly say..." — every one of them is a **debrief question**, not a mechanical checklist. The mechanics themselves (Connection Badges firing, room lifecycle, the Loadout hand-off) are already covered by Stories 001–013's own automated/manual tests — **do not re-verify those here**. This session tests whether the *experience* those mechanics produce actually reads the way the GDD intends, in your own honest reaction, not whether the code is correct.

Three separate debrief moments, each tied to one AC:

1. **Overview "step back and look"** (Core Rule 5, Player Fantasy's "peak moment") — after a mission return, can you name something specific your sanctuary reflects, unprompted?
2. **Loadout "one continuous motion"** (Core Rule 10, Player Fantasy's Loadout paragraph) — does reaching Tarot Deck UI from mid-room feel like a continuation, not an errand?
3. **Connection Badge legibility** (Core Rule 2/9) — can you correctly guess what a badge means without opening that room?

---

## Before the Session — Setup Checklist

- [ ] Confirm current build is clean: `git status` shows no uncommitted changes you'd want reverted mid-session; note the current commit hash for the evidence doc
- [ ] Have a save file with **some real accumulated sanctuary state** — at least one built Defense Building structure, some Menagerie creatures, and ideally a recently-discovered Crafting recipe or two. A brand-new/empty sanctuary can't produce an honest "step back and look" answer, since there's nothing yet to notice (the Overview AC specifically asks you to name a choice your sanctuary *reflects* — an empty diorama reflects nothing)
- [ ] Have `production/playtests/sanctuary-ui-playtest-report.md` open side-by-side to fill in live
- [ ] Decide in advance which of the four Connection-Badge-triggering events (a Defense Building structure completing, a Menagerie creature reaching `READY`, a Crafting recipe unlocking, or a new creature acquired) is realistically engineerable in one sitting from your current save state — breeding-pen completions in particular are gated on missions-remaining, not real time, so they're not a same-session option unless one is already close to done. Pick whichever is actually reachable; don't force a specific one if your save doesn't support it

---

## During the Session

### 1. Debrief moment 1 — Overview "step back and look"
Play a mission to completion (win or lose — either returns you to `OVERVIEW`) exactly as you normally would, without deliberately steering toward "notice things." The moment the Sanctuary-overview diorama appears:

- **Pause and actually look**, the way the Player Fantasy describes — "the player stops adjusting and simply looks."
- **Without re-reading the GDD or prompting yourself with a checklist**, say or write down the first specific thing you notice about your own sanctuary — a structure, a habitat, a build direction. It has to be *specific* ("I built the second forge upgrade there because I kept running out of runes") not generic ("looks nice").
- **Record whether this happened unprompted.** If nothing specific comes to mind within a few seconds of genuinely looking, that's a real negative finding — write that down too, don't wait it out until something eventually occurs to you.

### 2. Debrief moment 2 — Loadout "one continuous motion"

> **2026-08-28 mechanical pre-check found an anomaly worth your attention**: simulated
> clicks on the Loadout tab (via Godot MCP) consistently opened Forge instead — but a
> raw click on Menagerie also failed to register at all in the same session, so this may
> be a test-harness limitation rather than a real bug (the underlying hand-off logic
> itself was independently confirmed correct). **Please try selecting Loadout both by a
> real mouse click on the tab and by pressing `6`, and note below if they behave
> differently.** Full detail: `production/qa/evidence/story-014-mechanical-verification-2026-08-28.md`.

From **inside a room** (not `OVERVIEW`) — Inventory & Crafting, Menagerie, Defense Building, or Equipment Forge, whichever you happen to be in mid-session — select the Loadout tab.

- **Notice the transition itself**: the drawer-slide tween, the hand-off to Tarot Deck UI.
- **Immediately after arriving**, without consulting the GDD, describe in your own words what that felt like. The specific thing to listen for in your own reaction: did it feel like *continuing what you were already doing* (the GDD's own target), or did it feel like *leaving to go do something else* — a context switch, an errand, "now I have to go handle loadout stuff"? Write down your actual phrasing.
- Return from Tarot Deck UI and confirm you land back at `OVERVIEW` (Core Rule 10's documented re-entry behavior) — note if this surprised you or felt like the wrong place to land.

### 3. Debrief moment 3 — Connection Badge legibility

> **2026-08-28 mechanical pre-check note**: the badge fires correctly (confirmed via
> direct engine inspection), but its rendered indicator measured only ~10×23px at the
> extreme corner of its tab — genuinely easy to miss. Worth paying close attention to
> whether you notice it at all before it prompts you to look. Full detail in the same
> evidence file linked above.
Using the badge-triggering event you picked during setup:

- Engineer the event so it fires **while you are sitting in a room other than the one whose tab will show the badge** — e.g., confirm a Defense Building structure build, then before entering that room again, switch to Menagerie or Inventory & Crafting and stay there.
- With the badge now visible on a tab you are **not** currently in, **stop and say out loud or write down what you think the badge means** — which system, roughly what kind of change — **before opening that room to check.**
- Then open the room and confirm whether your guess was right. Record both the guess and whether it was correct — a right answer you couldn't have made without opening the room first doesn't count as a pass.
- If your save state doesn't support engineering this cleanly in one sitting, note that honestly in the report rather than forcing a low-confidence attempt — a real "couldn't test this cleanly, here's why" is more useful than a contaminated result.

---

## Known, Already-Tracked Gaps — Don't Log These as New Bugs

- **Loadout never carries a Connection Badge** — this is a deliberate, documented scoping decision (Core Rule 2/10, Open Question OQ-8), not a bug. If you notice its absence, that's expected.
- **No slot-level cross-room highlighting** (Core Rule 9) — selecting something in one room never jump-navigates or pre-highlights something in another room. Only tab-level badges deliver cross-system legibility. This is intentional, not a missing feature.
- **UI state never persists across sessions** (`save-persistence.md`'s "no UI state saved" rule) — every Sanctuary entry defaults to `OVERVIEW`, regardless of which room was open last time. Expected.

If something breaks session flow, freezes input, or produces an obviously-wrong state (not a feel/legibility judgment — an actual malfunction), log it in the report's Bugs table and file it via `/bug-report` separately.

---

## After the Session

1. Fill in `production/playtests/sanctuary-ui-playtest-report.md` completely — all three debrief answers need your actual words, not a pass/fail alone, per the story's own evidence requirement.
2. Write (or update) `production/qa/evidence/story-014-experiential-playtest-evidence.md` from the report — this is the file the story's Test Evidence section names as required.
3. Flip Story 014 to Complete if all three debrief moments land positively, or capture concrete follow-up items if not — either outcome closes the story; a documented negative finding is not a failed session, it's real design signal.
