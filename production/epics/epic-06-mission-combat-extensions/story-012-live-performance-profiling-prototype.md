# Story 012: Live Performance Profiling Prototype

> **Epic**: Epic 06 — Mission Combat Extensions
> **Status**: Complete (performance axis) / **Partial** (playtest axis — see Completion Notes)
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-07-13b

## Context

**GDD**: `design/gdd/tower-mastery.md`
**Requirement**: `TR-towermast-001`

**ADR Governing Implementation**: ADR-0029 (Tower Mastery Proximity-Detection Strategy)
**ADR Decision Summary**: Tower Mastery's MEDIUM engine-risk classification rests entirely on an unvalidated live-performance assumption — the per-physics-frame accrual loop has not been profiled against a real playable build. `systems-index.md` explicitly recommends prototyping proximity detection in isolation, and playtesting for "does the mechanic feel fair," before full mission integration. This is not closeable by ADR review alone.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM — the specific open item this story exists to close
**Engine Notes**: Live profiling required against a real mission with 5+ simultaneously-accruing `build_signature`s during a full 100-monster wave (ADR-0029 Verification Required). No amount of static analysis substitutes for this — the skill mandates live-verify over static-only analysis for exactly this class of claim.

**Control Manifest Rules (this layer)**:
- Required: N/A — this is a profiling/prototype story, not a shipping-code story; follow whatever scaffolding is fastest to get a measurable build.
- Forbidden: Do not treat this story's absence as a reason to defer profiling to polish — `EPIC.md`'s Known Blockers and Definition of Done both explicitly require this to happen early, not deferred.
- Guardrail: Recommend this happens as an isolated prototype (per `systems-index.md`'s own explicit mitigation instruction) before or alongside the other Tower Mastery stories in this epic, independent of full mission integration.

---

## Acceptance Criteria

*Derived from ADR-0029's Verification Required and Validation Criteria — this story has no GDD-numbered AC of its own; it exists to close an engine-risk open item, not implement a new mechanic:*

- [ ] Live-profiling test measures `_physics_process` cost for the accrual loop with 5+ simultaneously-accruing `build_signature`s during a 100-monster `WAVE_ACTIVE` wave
- [ ] Measured cost confirms or refutes the MEDIUM engine-risk classification (ADR-0029 Validation Criteria)
- [ ] A documented answer exists to `systems-index.md`'s playtesting question: "does the mechanic feel fair?" — not just a shipped mechanic with no playtest record
- [ ] `MASTERY_UNLOCK_THRESHOLD`'s 45s default is checked against real pacing data if the prototype surfaces evidence it needs adjustment within its 20–90s safe range

---

## Implementation Notes

*Derived from ADR-0029's Verification Required section and `systems-index.md`'s risk-mitigation instruction:*

- Build (or reuse, if one already exists from Hero's Tower-Synced Class system) a minimal test mission with 5+ towers of distinct `build_signature`s placed within accrual radius of a scripted or manually-controlled hero, and a 100-monster wave running concurrently.
- Measure `_physics_process` cost for the accrual loop (Story 010's `for sig in _signatures_in_range` pass) using `Time.get_ticks_usec()` around the call, averaged over N runs — the specific measurement methodology is flagged as unspecified in the constellation.md sibling case (OQ-7) and should not be re-invented ad hoc here; coordinate with Technical Director/QA Lead on a shared methodology if one is being defined for AC-30 (Story 005) at the same time.
- This story's playtesting component is distinct from its performance component: even if the accrual loop profiles as cheap, `systems-index.md`'s frustration-risk table requires an actual documented answer on whether standing near a tower mid-combat feels rewarding or punishing — not an assumption.
- If the 45s `MASTERY_UNLOCK_THRESHOLD` default proves too fast or too slow during this prototype's playtest, adjust within the 20–90s safe range and update `tower-mastery.md`'s Tuning Knobs — this is a design placeholder per the GDD's own Notes section, not a locked value.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 009/010: the actual production accrual/tracking logic this story profiles (this story validates it, does not re-implement it)
- Full mission integration — this is explicitly an isolated prototype per `systems-index.md`'s recommendation, not a polish-phase task

---

## QA Test Cases

*QL-STORY-READY gate skipped — Lean mode. This story is Integration/perf-validation rather than acceptance-criteria-driven; manual verification steps apply:*

- **Manual check**: Accrual loop cost under load
  - Setup: minimal mission scene, 5+ towers with distinct `build_signature`s within accrual radius of the hero, 100-monster wave active
  - Verify: `_physics_process` accrual-loop cost measured and recorded (e.g. via `Time.get_ticks_usec()`, N-run average)
  - Pass condition: cost is negligible relative to frame budget (16.67ms @ 60 FPS) and does not visibly degrade frame time versus the same scene with Tower Mastery disabled

- **Manual check**: Mechanic feel ("does standing near a tower mid-combat feel fair?")
  - Setup: same prototype mission, played by at least one tester under combat pressure
  - Verify: documented qualitative feedback on whether the positioning trade-off (per Player Fantasy) reads as a meaningful choice rather than frustrating busywork
  - Pass condition: a written playtest note exists in `production/qa/` (or equivalent) answering the question explicitly — "yes, because..." or "no, because..." — not silence

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Performance measurement recorded in `production/qa/evidence/tower-mastery-accrual-profiling-evidence.md` (or equivalent) — must exist
- Playtest note answering the frustration-risk question, per `systems-index.md`'s High-Risk Systems table

**Status**: [x] Created — `production/qa/evidence/tower-mastery-accrual-profiling-evidence.md`

---

## Completion Notes

**Completed (performance axis)**: 2026-07-18 (Sprint 6, S6-05)

Live-verified via Godot MCP `run_script` against the real Godot 4.6.2.stable binary, using a prototype accrual loop matching ADR-0029's own `_physics_process` pseudocode exactly (Tower Mastery itself is not yet implemented — Stories 007–010 are S6-10's scope), run concurrently with 100 lightweight monster stand-ins and 5 simultaneously-accruing signatures:

- **Result**: 0.899 µs per call — **0.0054% of the 16.67ms frame budget**. Negligible by a wide margin.
- **Verdict**: ADR-0029's MEDIUM engine-risk classification can be downgraded to LOW on the performance axis. Re-confirm once Stories 007–010's actual shipped class lands, but no architectural surprise is expected given the magnitude of headroom found.

**Not completed (playtest axis)**: the "does standing near a tower mid-combat feel fair?" question requires a real human playtest session. No playtester was available in this session — rather than fabricate a response, this is reported honestly as **still open**. The evidence file records the GDD's own three structural mitigations (pause-not-reset, cross-mission persistence, generous shared radius) as a design-reasoning assessment, explicitly flagged as not a substitute for observing a real player. **Recommend scheduling a real playtest session** (mirroring this project's own `S4-11` precedent) before treating Tower Mastery's HIGH-risk classification as fully closed.

**Deviations**: `MASTERY_UNLOCK_THRESHOLD`'s 45s default was not evaluated against real pacing data, since that requires the same human playtest session that couldn't be run — carried forward as an open item alongside the feel-verdict question.

**Re-confirmed against the real shipped class (2026-07-19, Sprint 7, follow-up on this story's "re-confirm once Stories 007–010 land" note)**: with Stories 007–011 now Complete, re-ran the profiling live via Godot MCP `run_script` against the real `TowerMastery.tick()` method (not the S6-05 prototype's hand-written stand-in loop). Result: **6.347 µs/call — 0.0381% of the 16.67ms frame budget** (up from the prototype's 0.899 µs/0.0054%, since the real `tick()` does strictly more per-signature work: representative-tower-id resolution, `progress_percent` computation, an EventBus emission every call). Still nearly 3 orders of magnitude below budget — **the LOW-on-performance-axis downgrade is confirmed against production code, not just the prototype.** No architectural surprise found. Full detail in the evidence file's new "Re-confirmation Against the Real Shipped Class" section.

**Playtest axis remains open** — no human playtester was available in this pass either. Not re-attempted; still requires a real session before Tower Mastery's HIGH-risk classification can be considered fully closed.

---

## Dependencies

- Depends on: Story 009, Story 010 (the accrual logic being profiled must exist, even in prototype form) — **note**: this story used a faithful standalone prototype rather than waiting on Stories 009/010's actual implementation, per its own "isolated prototype, before or alongside" guidance
- Unlocks: ADR-0029's MEDIUM engine-risk classification downgraded to LOW on the performance axis (re-confirmed 2026-07-19 against the real shipped class); playtest axis remains open

**Unblocked**: ADR-0029 accepted 2026-07-18 (Sprint 6, S6-02). This is Sprint 6's own S6-05 task, re-confirmed in Sprint 7.
