# Architecture Review Report — Pass 5 (Confirmation Re-Run)

**Date:** 2026-07-13
**Mode:** `/architecture-review full` — confirmation pass following Pass 4 follow-up fixes
**Engine:** Godot 4.6.2
**GDDs Reviewed:** 14 | **ADRs Reviewed:** 19

This pass verifies that the fixes applied after Pass 4
(`architecture-review-2026-07-13d.md`) landed correctly and consistently,
and re-runs a full Phase 4/5 sweep to check whether any of those fixes
introduced a new inconsistency. It does not re-derive requirements from
scratch — it re-verifies the current state against Pass 4's baseline.

## Fixes Being Confirmed

1. ADR-0019 (Projectile Pooling) Accepted (was Proposed)
2. ADR-0005's self-contradicting Engine Compatibility table corrected
3. `control-manifest.md` regenerated to integrate ADR-0019's rules
4. FileAccess semantics (ADR-0003/TR-save-002) live-verified via MCP smoke test
5. Godot 4.6 glow rework risk live-tested and characterized (not fully closed)

## Findings

| # | Check | Result |
|---|---|---|
| 1 | All 19 ADRs Accepted; ADR-0019/ADR-0005 status text clean | ✅ PASS |
| 2 | `control-manifest.md` — ADR-0019 rules present, header caveat removed, spot-checked against source ADR text | ✅ PASS |
| 3 | `architecture-traceability.md` internal consistency | 🟡 Found and fixed — Coverage Summary undercounted Partial (2 vs. actual 3) and overcounted Covered (79 vs. actual 78) because TR-tower-009, added within Pass 4 itself, was never folded into the summary table. **Corrected this pass.** |
| 4 | `architecture.md` — ADR count consistency | 🟡 Found and fixed — the "Required ADRs" section (a second, separate location from the already-corrected "ADR Audit" section) still read "18 ADRs." **Corrected this pass.** |
| 5 | `tr-registry.yaml` — TR-tower-007 note, ID sequence integrity | ✅ PASS — no gaps, duplicates, or renumbering; 90 total IDs match the traceability doc's total |
| 6 | `hero.md` / `tower.md` / `VERSION.md` — glow + FileAccess consistency | ✅ PASS — identical characterization across all three files |
| 7 | ADR-0003 — FileAccess verification note | ✅ PASS — consistent with `VERSION.md` |
| 8 | Fresh Phase 4/5 sweep for new issues | Found the two items above (both documentation bookkeeping, both non-blocking, both fixed this pass). No new cross-ADR conflicts, no new engine-compatibility contradictions. |
| 9 | Pre-existing open items still accurately flagged (not silently resolved) | ✅ PASS — TR-hero-007, TR-inv-004, TR-inv-005, TR-hud-001/002/003, TR-tower-009 all confirmed still open with unchanged descriptions |

## Still-Open Items (expected, unchanged from Pass 4)

These are real, tracked gaps — not defects introduced by this pass:

- **TR-hero-007** — `hero_skill_activated` payload conflicts with `mission-hud.md`'s `skill_slot:int` assumption. Blocks Mission HUD skill-button implementation until reconciled.
- **TR-inv-004** — `item_pickup_rejected` signal shipped but undocumented in `event-bus.md`'s catalogue.
- **TR-inv-005** — Tower System doesn't yet call `item_added` with `metadata.damaged` on tower destruction.
- **TR-hud-001/002/003** — `mission-hud.md` remains a skeleton GDD with no governing ADR.
- **TR-tower-009** — Wave Manager's `CONNECT_DEFERRED` timing constraint (`wave_completed` → next `wave_started`) not independently re-verified against shipped code.
- Godot 4.6 glow rework — characterized (root cause identified: `use_hdr_2d` required, darkens whole scene) but not fully closed — still needs a follow-up pass with the project's actual planned VFX assets before texture import presets are locked.

None of these are Foundation-layer or dependency-cycle blockers.

## Verdict: **CONCERNS** (unchanged from Pass 4, expected)

The two headline fixes (ADR-0019 Accepted, ADR-0005 corrected) landed
cleanly. This confirmation pass caught two small bookkeeping
inconsistencies in downstream summary text — both are now fixed. No new
architectural conflicts, no new engine-compatibility contradictions, and
no accidental resolution of genuinely open items were found. The
project's five remaining open items are all previously known, correctly
tracked, and none are blocking.

## Next Steps

- The five open TR items above are the right backlog for future ADR/design
  work — none require immediate action to keep building.
- Recommend the glow-rework follow-up (real VFX assets, not synthetic test
  content) before texture import presets are locked, per `VERSION.md`.
- Re-run `/architecture-review` after ADR-0019's rules are exercised by
  actual HOMING/BALLISTIC implementation, or after `mission-hud.md` is
  designed far enough to warrant its own ADR.
