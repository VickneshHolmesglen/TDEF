# Gate Check: Pre-Production → Production

**Date**: 2026-07-03
**Checked by**: gate-check skill
**Review mode**: lean
**Prior gate check**: `production/gate-checks/gate-check-pre-production-2026-07-01.md` (verdict FAIL)

## Required Artifacts: 7/15 present

- [x] Prototype(s) with README — 2 prototypes (`prototypes/stacked-sprite-seam/`, `prototypes/stacked-sprite-test/`), both documented
- [x] First sprint plan exists — 3 sprint plans (`production/sprints/sprint-01.md` through `sprint-03.md`)
- [ ] Art bible complete (9 sections) + sign-off recorded — **FAIL**: Sections 7–9 (UI/HUD Visual Direction, Asset Standards, Reference Direction) are still literal `[To be designed]` placeholders (verified by reading content, not just headers). Sign-off line reads "Skipped — Lean mode (director gate deferred to Full review)" — never actually recorded. Unchanged since the 2026-07-01 gate check.
- [ ] Character visual profiles for key characters — **FAIL**: none exist anywhere in `design/`
- [x] All MVP-tier GDDs complete — Hero GDD is Approved along with all other MVP systems (design docs, not implementation)
- [x] Master architecture document exists — `docs/architecture/architecture.md`
- [x] ≥3 ADRs covering Foundation layer — 12 ADRs exist
- [x] Control manifest exists — `docs/architecture/control-manifest.md`
- [x] Epics defined (Foundation + Core layer both present) — `production/epics/epic-01-foundation.md`, `production/epics/epic-02-core-combat/EPIC.md`
- [ ] VS build exists and is playable — **FAIL**: only `production/vertical-slice-target.md` (a scope/target doc); no assembled scenes exist beyond `src/core/monster/MonsterEntity.tscn` and 2 throwaway prototypes — no main menu, no mission scene
- [ ] VS playtested ≥3 sessions — **FAIL**: zero playtests; `production/playtests/` does not exist
- [ ] VS playtest report exists — **FAIL**: none
- [ ] UX specs for main menu / core HUD / pause menu — **FAIL**: only `design/ux/mission-hud.md` and `design/ux/interaction-patterns.md` exist; no main-menu or pause-menu specs
- [ ] HUD design doc at `design/ux/hud.md` — **FAIL**: doesn't exist at that exact path
- [ ] Key screen UX specs passed `/ux-review` — **FAIL**: no review verdicts found; `mission-hud.md` still pending review

## Additional Technical Blockers (from Technical Director's review)

- **No integration surface exists** — no scene has ever booted the full Autoload chain together in a live mission. `SceneManager` and `GameDataRegistry` (ADR-0002 boot positions 5–6) still don't exist at all. This is the root cause behind several already-logged "advisory" tech debt items (TD-monster-003, TD-wave-001), not two unrelated issues — systems that pass in isolation routinely surface wiring failures at first real assembly, and that risk remains entirely unretired.
- **HIGH perf risk unretired** — the 100-agent @ 60fps budget (TR-path-007) was slated for retirement in Sprint 1/2 per the risk register. The one profiling attempt this session (logged as TD-path-001) measured the wrong scenario — cold fallback A* (~34ms), not the warm template-lookup path AC-4 actually specifies. This risk remains genuinely open, not just administratively tracked.

## Quality Checks

- [ ] Core loop fun validated via playtest — **FAIL**, no playtest exists
- [ ] VS is COMPLETE, not just scoped — **FAIL**, not built
- [ ] Core fantasy independently described by a playtester — **FAIL**, no playtesters
- [x] Sprint plans reference real story paths with GDD/ADR linkage
- [x] All ADRs have Engine Compatibility + ADR Dependencies sections
- [~] Architecture has no unresolved Foundation/Core open questions — **CONCERNS**: SceneManager/GameDataRegistry gap, unretired TR-path-007 perf risk

## Vertical Slice Validation (FAIL if any item is NO)

- [ ] A human has played through the core loop without developer guidance — **NO**
- [ ] The game communicates what to do within the first 2 minutes of play — **NO** (no build exists)
- [ ] No critical "fun blocker" bugs exist in the Vertical Slice build — N/A, unknown (no build)
- [ ] The core mechanic feels good to interact with — N/A, unknown (no build)

Per gate rules, any NO here forces an automatic FAIL regardless of other checks. This condition is met — verdict is FAIL independent of the artifact/quality tallies above.

## Director Panel Assessment

```
Creative Director:  NOT READY
  The Vertical Slice target ("The Gap") exists to answer whether "place towers, then
  pilot the hero to cover what they miss" is fun — a direct test of Pillar 1
  (Mastery-as-Vindication), the game's central creative promise. It has never been
  played by a human. 299 passing tests validate engineering correctness, not fun.
  The vindication beat — the hero covering the gap — is the emotional core and is
  entirely unproven. Build the slice, playtest it, then re-gate.

Technical Director: CONCERNS
  The foundation is genuinely strong: 299/299 tests green, 12 ADRs, 91% TR coverage,
  thorough architecture doc, control manifest, traceability index. But no scene has
  ever booted the full autoload chain in a live mission — the orphan-spawn and
  autoload-position advisories are symptoms of this same root cause. The 100-agent
  @ 60 FPS HIGH perf risk (TR-path-007) also remains unverified — the one profiling
  attempt measured the wrong path. Hero being unbuilt is acceptable for
  Pre-Production; the integration and perf blind spots are not. Recommend an
  integration-first Sprint 4: assemble a minimal mission scene, boot the full chain,
  implement Hero, and run a real 100-agent stress test.

Producer:           CONCERNS
  The tracking machinery is genuinely Production-ready — Sprint 3 delivered its full
  Must-Have critical path plus Should-Have Wave Manager, 299 tests green, QA sign-off
  recorded, profiler obligations captured. Epics → sprints → QA cycle → sign-off is a
  functioning, repeatable loop. But this gate's own stated bar is the Vertical Slice,
  and that bar is unmet: zero playtests, no assembled scenes, art-bible sign-off
  skipped, zero character visual profiles. Recommend treating VS-built + first
  playtest as a hard Sprint 4 exit gate.

Art Director:       NOT READY
  Verified by reading art-bible.md directly: Sections 7-9 are still literal
  [To be designed] placeholders (lines 2304-2319), and the sign-off line is
  unchanged: "Skipped — Lean mode." Nothing has actually progressed since the
  2026-07-01 failure. Sections 1-6 are genuinely strong and production-ready.
  Character visual profiles remain fully absent — Hero cannot enter asset
  production without one. Do not advance until Sections 7-9 are drafted and a
  Hero character visual profile exists.
```

Two directors (Creative, Art) returned NOT READY, which per gate protocol forces a minimum FAIL verdict.

## Blockers

1. **No Vertical Slice exists** — no assembled scenes, no playable build of any kind.
2. **Zero playtests** — the VS's own defined success criterion is completely untested.
3. **Hero system unimplemented** — the system whose combat is the "vindication beat" of the core fantasy.
4. **Art bible Sections 7–9 are placeholders** and sign-off was never actually recorded, just skipped.
5. **No character visual profiles** — blocks Hero asset production even once code exists.
6. **No main-menu/pause-menu UX specs**; `mission-hud.md` still pending `/ux-review`.
7. **SceneManager and GameDataRegistry don't exist** — the full Autoload chain has never booted together in a live scene.
8. **100-agent performance budget (TR-path-007) still unverified** — the one profiling attempt measured the wrong scenario.

## Recommendations

- Make Sprint 4 an **integration-first slice**: implement Hero, assemble a minimal mission scene, boot the full Autoload chain (including SceneManager/GameDataRegistry), and run a real 100-agent stress test.
- Get that slice in front of at least 3 playtesters and write up findings.
- Close the art bible: fill Sections 7–9, get an actual AD-ART-BIBLE sign-off (not "Skipped"), and produce a Hero character visual profile.
- Author main-menu and pause-menu UX specs; run `/ux-review` on `mission-hud.md`.
- Close S3-09 (PLACEABLE cost) — still open from Sprint 2.

## Verdict: FAIL

**Chain-of-Verification**: 5 questions checked — verdict unchanged. The SceneManager/GameDataRegistry gap and unretired TR-path-007 perf risk were under-weighted in the initial artifact-only pass and have been called out explicitly as additional blockers per the Technical Director's independent review, strengthening rather than softening the FAIL verdict.
