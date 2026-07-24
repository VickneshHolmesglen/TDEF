# Main Menu UX Spec — Review Log

---

## Review — 2026-07-07 (pass 1) — Verdict: NEEDS REVISION → APPROVED (in-session)
Scope signal: M
Specialists: None (lean mode)
Blocking items: 1 (resolved in-session) | Advisory: 3 (accepted, no fix required)
Summary: First `/ux-review` pass on `design/ux/main-menu.md`. **Blocking (fixed in-session)**: Component Inventory's Continue button was tagged as reusing Pattern 3 (State-Gated Action Button), but its actual behavior — swapping its own label to "New Game" when no save exists — doesn't match that pattern's spec (phase-gated active/inactive presentation of a single fixed label). Corrected to "New — not a formal pattern; a simple state-driven label swap," distinct from Pattern 3. **Advisory (not fixed, low priority)**: (1) no explicit keyboard-only (no-mouse) navigation path documented separately from mouse clicks; (2) header has no explicit Platform Target field (inferable from `technical-preferences.md` but not restated locally); (3) Data Requirements doesn't specify update-trigger granularity for save-slot reads (read-once-at-load assumed but not stated). GDD Alignment: ALIGNED — `save-persistence.md`'s UI Requirements delegation (save slot selection, save confirmation, EC-3 recovery) fully covered. Accessibility: COMPLIANT, Standard tier. Pattern Library: 1 inconsistency found and fixed (see Blocking above); `Modal Dialog (decision required)` and `Save Slot Card` correctly formalized as new Patterns #13/#14 in `interaction-patterns.md` rather than re-specified inline.
Prior verdict resolved: N/A — first review
