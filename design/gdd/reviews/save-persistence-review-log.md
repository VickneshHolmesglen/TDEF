# Save & Persistence System GDD — Review Log

`design/gdd/save-persistence.md`

---

## Cross-Doc Correction — 2026-07-15 — DEFEAT-Save Ordering + DEFEAT-Transition Model Conflict
`/review-all-gdds` (2026-07-15) flagged two blocking issues, both fixed same-day.

**(1) DEFEAT-save ordering hazard.** `mission_phase_changed(DEFEAT)` is emitted by Wave Manager purely on `hero_died` (`wave-manager.md` Rule 14) — entirely independent of Tower's `tower_destroyed`→`tower_component_returned`→Inventory's `item_added` cascade (`tower.md` Rule 24), which fires whenever a tower's HP separately reaches 0. Nothing prevents a boss attack from killing the hero and destroying a tower in the same physics frame, and Godot does not guarantee handler-execution order across Autoloads within a frame. The prior Rule 4 wrote the DEFEAT save immediately on receiving the event, with no guarantee the same-frame component-return cascade had finished — risking a save that silently omits a just-destroyed tower's damaged components. `tower.md` had already flagged this exact requirement (its own OQ history, "NEW (2026-07-14)" note) but the fix had never landed here. Fixed: new Rule 9 defers the DEFEAT save by exactly 1 frame (`call_deferred`) before any `get_save_data()` call, mirroring this GDD's own pre-existing `sanctuary_state_restored` 1-frame deferral pattern (Rule 10) and event-bus.md's established synchronous-cascade-then-defer convention (Core Rule 5). New EC-11 and AC-13 added.

**(2) DEFEAT-transition model conflict.** The former Rule 9 ("Load and restore sequence") triggered on "game start or on DEFEAT returning to Sanctuary" — but `game-concept.md`'s own States and Transitions table has DEFEAT transitioning directly to SCOUT (the mission restarts), never through SANCTUARY. This GDD's own Overview already correctly described the DEFEAT flow as "a save... before restarting from Scout Phase" — only Rule 9, the States/Transitions table's `LOADING` row, and AC-12 had drifted into the wrong model. Root cause once traced: DEFEAT only ever needs a *save* (durability, in case of a crash/quit before next reaching SANCTUARY) — nothing is unloaded from memory mid-session, so there is nothing to *restore*. Fixed: Rule 10 (renumbered) now triggers only on game start; `LOADING` state's active-during column and AC-12 corrected to match.

**Also fixed in the same pass:** a stale "OUTCOME" phase reference in Rule 8 (autosave exclusion list) and the Interactions table — no such phase exists in the mission FSM (canonical phases per `wave-manager.md`'s own emitted transitions are MISSION_COMPLETE and DEFEAT as distinct terminal states). Notably, `gdd-cross-review-2026-05-15.md` had already logged this exact "OUTCOME" issue as **fixed** (item W2) over two months prior — it was not; this correction is the first time it actually landed.
Prior verdict resolved: No — both issues were live, unresolved blockers as of this pass, despite one having a false "fixed" record in an earlier cross-review.

---

## Review — 2026-05-15 (pass 1) — Verdict: NEEDS REVISION → APPROVED (in-session)
Scope signal: M
Specialists: None (lean mode)
Blocking items: 1 (resolved in-session) | Recommended: 5 (not applied — B1-only revision pass)
Summary: First review pass. The document is structurally solid — atomic write strategy, restore ordering, autosave timer, and Core Rule 11 (sanctuary always survives defeat) are well-specified and internally consistent. One blocker resolved in-session: B1 — `mission_launched` event payload carried only `modifier_count: int`, providing no mechanism for Save & Persistence to populate `last_launched_modifiers` in the checkpoint file (EventBus Core Rule 1 prohibits direct system references); fix: `modifier_count: int` replaced with `modifiers: PackedStringArray` in EventBus GDD and S&P Interactions table updated with explicit read spec. Five recommended items noted for future pass (R1 section header rename, R2 Rule 9 file-not-found step, R3 Formula 4 layer naming note, R4 OQ-5 inline resolution, R5 Formula 2 checkpoint/timer ambiguity). Document is implementation-ready pending OQ-1 (serialization format ADR) before coding begins.
Prior verdict resolved: N/A — first review
