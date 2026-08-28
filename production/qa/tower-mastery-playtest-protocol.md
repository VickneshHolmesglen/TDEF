# Playtest Protocol — Tower Mastery (S9-01)

> **Purpose**: A single, self-contained session protocol for Vicknesh to run as playtester,
> answering the two open questions Story 012 and Story 013 each explicitly left blocked on
> a real human playtest. Not a facilitator script for a *third-party* tester — this project
> has one available playtester (Vicknesh), and Tower Mastery's own question ("does standing
> near a tower mid-combat feel fair?") is a designer-feel judgment, not a blind-discoverability
> test like Sprint 4's "The Gap" round. Read this whole document before starting — it's one
> continuous session, not three separate ones.
>
> **Stories this closes**: `production/epics/epic-06-mission-combat-extensions/story-012-live-performance-profiling-prototype.md` (playtest axis only — the performance axis is already Complete) and `story-013-mid-combat-visual-audio-feedback.md` (human verification axis only — every mechanism is already Complete).
> **GDD**: `design/gdd/tower-mastery.md` — read the Player Fantasy section (lines 13–23) before playing. The whole point of this session is judging whether the built mechanic actually delivers that fantasy, not just whether it functions.
> **Systems-index risk this closes**: `design/gdd/systems-index.md`'s own High-Risk Systems table, Tower Mastery row — "Proximity-based learning during live combat is untested in the tower-defense genre... Playtest specifically for 'does the mechanic feel fair?' before integrating into full missions."
> **Report template**: `production/playtests/tower-mastery-playtest-report.md` — fill it in live or immediately after. Do not batch this from memory later.

---

## What This Session Is and Isn't

This is **not** a blind-discoverability test (contrast Sprint 4's "The Gap" round, which specifically wanted a first-time player with no context). You already know exactly what Tower Mastery does and why. That's fine — the open question isn't "can a new player figure this out," it's "does the actual mechanical tension (stand near a tower and lose map coverage, vs. cover the gap and lose the lesson) read as a meaningful choice or as busywork/frustration once you're actually under wave pressure." A designer who knows the system inside out can still answer that honestly by paying attention to their own in-the-moment reactions — irritation, satisfaction, "I wish I hadn't done that," etc.

Two things stack in one session because they share the same setup (a real mission with real towers under real wave pressure) and the same root open item (ADR-0029's playtest axis):
- **Story 012's question**: does the proximity-learning trade-off feel fair, not punishing?
- **Story 013's question**: are the arc/HUD-callout/audio-stinger treatments legible without anyone explaining them to you, and do they support (not undercut) the feel-fairness verdict above?

---

## Before the Session — Setup Checklist

- [ ] Confirm current build is clean: `git status` shows no uncommitted changes you'd want reverted mid-session; note the current commit hash for the report
- [ ] Launch the game via Mission Select (not a debug shortcut) and start a real mission on `the_gap` — playing through Scout → Wave → Intermission normally, not skipping to a synthetic state
- [ ] Confirm `debug_controls_enabled` is **unchecked/false** on `the_gap.tscn`'s root node — this session should reflect what a real playthrough feels like, not a debug-assisted one
- [ ] Plan to place **at least 5 towers with distinct `build_signature`s** (i.e., 5 towers using genuinely different Foundation/Weapon/Focus/Power component combinations, not 5 copies of the same blueprint) within Chebyshev-3 range of where you intend to stand the hero mid-wave — this matches Story 012's own profiling setup and gives the accrual system enough simultaneous signatures to actually stress-test the choice
- [ ] Have a way to note timestamps or approximate elapsed time during play (a visible clock, phone timer, or just noting "roughly N seconds") — `MASTERY_UNLOCK_THRESHOLD` (45s default) is one of the things this session evaluates
- [ ] Have `production/playtests/tower-mastery-playtest-report.md` open side-by-side to fill in live

---

## During the Session — What to Do and Observe

### 1. Play at least one full wave normally first
Before deliberately testing Tower Mastery, play a wave the way you actually would if you weren't testing anything — this gives you a baseline read on how much "spare attention" combat pressure actually leaves for a positioning decision like standing near a tower. Note your baseline stress/attention level.

### 2. Deliberately stand the hero within accrual range of a tower mid-wave, and hold that position
Pick a moment with real combat happening elsewhere on the map — not a quiet wave. Stand still near one of your 5 diverse-signature towers and hold the position long enough to notice the in-world arc (Story 013's proximity-arc treatment) filling. While doing this:
- **Observe legibility** (Story 013's own QA checklist, now answerable for real): Is the arc visible without hunting for it? Is the archetype glyph at its center readable? Does it read as "progress," not as a bug or a stray VFX? Is it never more visually loud than the tower sprite or an active monster telegraph, per the GDD's own constraint?
- **Observe the trade-off** (Story 012's core question): While standing still, are you consciously aware of what you're giving up elsewhere on the map? Does that awareness feel like a real decision you made, or like an arbitrary tax the game is imposing? Write down your actual in-the-moment thought, not a post-hoc rationalization.

### 3. Deliberately break accrual twice — once by leaving, once by losing the tower
- **Step out of range mid-accrual.** Confirm the arc freezes (doesn't reset) and dims to ~55% opacity, per Rule "pause, not reset." Ask yourself: did that pause read as fair (you get to resume later) or did it feel like wasted effort in the moment it happened?
- **Let (or force, if you can trigger it safely) a tower you're accruing on get destroyed while you're in range.** Confirm the arc plays the Fieldstone Grey desaturate-fade rather than the same treatment as simply stepping away — the GDD requires these two causes to be visually distinguishable from each other. Note whether they actually read as different to you without already knowing the spec.

### 4. Hold a position long enough to actually trigger a `skill_unlocked` moment, if time allows
This validates the reward payoff, not just the mid-accrual tension. Note:
- Did the arc's intensify-and-pulse moment and the HUD corner callout register clearly, without pausing or dominating the screen mid-wave (per the GDD's explicit constraint)?
- Does the moment feel like a payoff proportionate to the ~45 seconds of deliberate risk you took to earn it, or does it feel anticlimactic / oddly-timed?
- **Note real elapsed time to unlock.** If 45 seconds felt clearly too long (you'd abandoned the mechanic as "not worth it" before reaching it) or clearly too short (it unlocked from what felt like incidental standing-around, not deliberate risk), say so explicitly — this is the concrete input Story 012's Acceptance Criteria asks for, within the GDD's already-defined 20–90s safe range. Don't guess a new number; just report the direction and magnitude of the mismatch, if any.

### 5. Listen for the audio stingers — but expect silence
**Known, already-tracked gap, not a new finding**: no real sound content has been authored yet for the enter-range tick, pause-descending-tone, or `skill_unlocked` chime — only the dispatch mechanism is wired (Story 013's Completion Notes, OQ-2). If you hear nothing, that's expected; don't log it as a bug. If you *do* hear placeholder engine beeps or an error, that's a real regression worth noting.

### 6. After the session, answer the two open questions directly and in writing
Fill the report template's verdict section with an explicit "yes, because..." or "no, because..." for each — per Story 012's own pass condition ("a written playtest note exists answering the question explicitly — not silence"). A hedge like "it's fine I guess" does not close this story; write down the actual reasoning.

---

## Known, Already-Tracked Gaps — Don't Log These as New Bugs

- **No real audio content** for any Tower Mastery cue (Story 013 OQ-2) — mechanism is real, sound assets are not.
- **`SkillDefinitionResource.display_name` fallback**: if you unlock a skill whose catalogue entry is missing `display_name`, the HUD callout shows the raw `skill_id` instead of a human name — this is a documented fallback behavior, not a crash.
- **Standard Mission HUD placeholder gaps** unrelated to Tower Mastery (if any are still outstanding) — only log something here if it's specifically about the arc, the callout, or the accrual trade-off itself.

If something *does* break session flow, freezes input, or produces an obviously-wrong state, log it as a real bug in the report's Bugs table and file it via `/bug-report` separately — the playtest report and the bug tracker aren't substitutes for each other.

---

## After the Session

1. Fill in `production/playtests/tower-mastery-playtest-report.md` completely, including the explicit yes/no verdicts.
2. If `MASTERY_UNLOCK_THRESHOLD` needs adjustment within its 20–90s safe range based on what you observed, note the recommended new value in the report — the actual GDD/code change is a separate follow-up, not part of this session.
3. Update `production/qa/evidence/tower-mastery-accrual-profiling-evidence.md` and `production/qa/evidence/tower-mastery-visual-audio-feedback-evidence.md` to point at the new report and record the verdict (both currently say the playtest axis is open — this closes that).
4. Flip Story 012 and Story 013 to Complete if both verdicts are clearly positive, or capture concrete follow-up items if not — either outcome closes the story, per its own Acceptance Criteria; a negative-but-documented verdict is not a failed session.
