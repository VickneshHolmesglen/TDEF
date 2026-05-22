# Risk Register — Sanctuary Defenders

**Phase**: Pre-Production
**Created**: 2026-05-19
**Owner**: Producer
**Updated**: 2026-05-19

Risk IDs: D = Deferred (from gate check), T = Technical, A = Art, S = Schedule

---

## Summary Table

| ID | Category | Risk | Prob | Impact | Status | Owner | Sprint |
|----|----------|------|------|--------|--------|-------|--------|
| D1 | Art/Visual | Stacked-sprite seam non-viable — visual style pivot required | Medium | HIGH | ✅ Mitigated | Art Director | S1-01 |
| D2 | Technical | ADR-0008 unresolved — Tower placement blocked in Vertical Slice | Low | HIGH | ✅ Mitigated | Tech Director | S1-04 |
| D3 | Art/Design | Art bible Sec 5–6 incomplete — character art cannot begin | Medium | HIGH | ✅ Mitigated | Art Dir + CD | S1-05 |
| T1 | Technical | Draw call budget: 8-layer stacked entities exceed 200 DC without atlas batching | Medium | HIGH | 🟡 Watch | Tech Director | Sprint 2 |
| T2 | Technical | Godot 4.6 post-cutoff APIs unverified against 4.4–4.6 changes in 9 GDDs | Medium | Medium | 🟡 Watch | Tech Director | S1-10 |
| D4 | Design | Vertical Slice experience target undefined — VS sprint planning blocked | High | Medium | 🔴 Open | Creative Dir | S1-09 |
| D5 | Design | Pathfinding + Wave Manager GDDs revised but not re-reviewed — latent design debt | Low | Medium | 🟡 Watch | Creative Dir | S1-06/07 |

---

## Risk Entries

### D1 — Stacked-Sprite Seam Non-Viable ✅ Mitigated

**Category**: Art/Visual
**Probability**: Medium → **Resolved**
**Impact**: HIGH — entire visual style would require pivot
**Status**: ✅ Mitigated (2026-05-19)
**Owner**: Art Director
**Logged**: 2026-05-18 (gate check — AD concern)
**Resolved**: 2026-05-19 (S1-01 prototype — PROCEED verdict)

**Description**: The stacked-sprite rendering technique specified in the art bible
(Principle 1) had not been validated in Godot 4.6.2. If the seam between stacked
objects and 2D tile backgrounds proved non-viable, the entire visual identity would
require a pivot in Pre-Production.

**Mitigation applied**: S1-01 prototype built and run on 2026-05-19.
Verdict: PROCEED. Technique confirmed viable at 6–8 layers with mandatory ground
shadow. Seam is clean. No pivot required.

**Evidence**: `prototypes/stacked-sprite-seam/REPORT.md`
**Residual**: Draw call batching required in production (see T1).

---

### D2 — ADR-0008 Unresolved ✅ Mitigated

**Category**: Technical
**Probability**: Low
**Impact**: HIGH — Tower placement cannot be implemented in Vertical Slice without it
**Status**: 🔴 Open
**Owner**: Technical Director
**Sprint**: S1-04
**Logged**: 2026-05-18 (gate check — TD concern)

**Description**: ADR-0008 (Tower placement gate) defines the WAVE_ACTIVE block
behaviour and the `duplicate_deep()` usage policy for nested Resources. Without
it, Tower System stories cannot begin. The Vertical Slice requires at least one
tower placement interaction — this ADR is on the critical path.

**Open questions resolved by this ADR**:
- OQ-4: `duplicate_deep()` usage policy for composite Resources
- WAVE_ACTIVE block: `Tower.place_tower()` returns false during wave (no queueing)

**Mitigation**: `/architecture-decision` to be run in Sprint 1. ADR-0008 must
reach Accepted status before any Tower System stories are written.

**Trigger**: If ADR-0008 is not Accepted by end of Sprint 1, all Tower System
stories are blocked and VS scope must be reduced to Foundation-layer only.

---

### D3 — Art Bible Sections 5–6 Incomplete ✅ Mitigated

**Category**: Art/Design
**Probability**: Medium → **Resolved**
**Impact**: HIGH — no character art production can begin without character design direction
**Status**: ✅ Mitigated (2026-05-19)
**Owner**: Art Director + Creative Director
**Sprint**: S1-05
**Logged**: 2026-05-18 (gate check — AD concern)
**Resolved**: 2026-05-19 (S1-05 complete)

**Description**: Art bible Sections 1–4 (Visual Identity, Mood, Shape Language,
Color System) are complete. Sections 5 (Character Design Direction) and 6
(Environment Language) are placeholders. Section 5 is specifically blocking:
hero concept art, tower concept art, and enemy concept art cannot begin without
character silhouette vocabulary and archetype direction.

**Mitigation**: S1-05 time-boxed to 1.5 days in Sprint 1. If incomplete by sprint
close, partial content is committed and remainder deferred to Sprint 2 with
an explicit blocker logged against character art stories.

**Trigger**: If Section 5 is not complete before Sprint 2 character art stories
are written, those stories are auto-blocked.

---

### T1 — Draw Call Budget: Stacked-Sprite Batching Required 🟡 Watch

**Category**: Technical
**Probability**: Medium
**Impact**: HIGH — 20+ towers × 8 layers = 160+ draw calls from stacking alone;
exceeds 200 DC budget when combined with background and UI
**Status**: 🟡 Watch (no blocker yet — production concern)
**Owner**: Technical Director
**Sprint**: Sprint 2 (before Foundation Epic stories written)
**Logged**: 2026-05-19 (S1-01 prototype finding)

**Description**: The stacked-sprite technique confirmed by S1-01 uses one draw
call per layer per entity. At 8 layers, a scene with 20 towers and 30 enemies
produces 400 draw calls from entity stacking alone — double the 200 DC budget.
Sprite atlasing and Godot's CanvasItem batching must be verified as sufficient
mitigations before Foundation Epic implementation begins.

**Mitigation**: An ADR or architecture note covering sprite atlas strategy must
be written before the first stacked-sprite entity scene is built. Candidate
approaches: shared texture atlas per entity class, MultiMeshInstance2D for
same-type layers, CanvasItem material batching.

**Trigger**: If no batching strategy is confirmed before Sprint 2 entity
implementation stories are written, those stories are blocked pending the ADR.

---

### T2 — Godot 4.6 Post-Cutoff API Risks Unverified 🟡 Watch

**Category**: Technical
**Probability**: Medium
**Impact**: Medium — individual GDD rules may reference APIs changed in 4.4–4.6;
late discovery means rework during implementation
**Status**: 🟡 Watch
**Owner**: Technical Director
**Sprint**: S1-10 (Nice to Have)
**Logged**: 2026-05-18 (gate check carry-forward)

**Description**: The LLM knowledge cutoff predates Godot 4.4–4.6. Nine MVP GDDs
were authored without systematic cross-referencing against post-cutoff engine
changes. Known risk areas (documented in `docs/engine-reference/godot/VERSION.md`):
Jolt default physics (4.6), FileAccess return type changes (4.4), glow rework (4.6),
D3D12 default on Windows (4.6), variadic args / @abstract (4.5).

**Mitigation**: S1-10 API verification pass (Nice to Have — defers to Sprint 2 if
Sprint 1 runs long). Each GDD annotated with any post-cutoff risks found.
High-risk GDDs (Pathfinding, Save) are highest priority for verification.

**Trigger**: Becomes a blocker if an implementation story references a verified
broken API. The fix is to revise the GDD before writing the story.

---

### D4 — Vertical Slice Experience Target Undefined 🔴 Open

**Category**: Design
**Probability**: High (currently undefined)
**Impact**: Medium — sprint planning for the VS sprint cannot be done without a
defined scripted moment; team has no shared north star for Pre-Production
**Status**: 🔴 Open
**Owner**: Creative Director
**Sprint**: S1-09
**Logged**: 2026-05-18 (gate check — CD concern)

**Description**: Pre-Production's primary deliverable is a playable Vertical Slice.
Without a one-page scripted moment document defining the VS experience target
(what the player does, what systems fire, win/fail conditions), Foundation and
Core epics cannot be scoped correctly and the Pre-Production → Production gate
cannot be evaluated.

**Mitigation**: S1-09 — `production/vertical-slice-target.md` to be written by
Creative Director this sprint. Must include: one scripted moment, win condition,
fail condition, systems involved (≥2 Foundation-layer).

**Trigger**: If S1-09 is not completed by sprint close, Sprint 2 planning is
blocked until the VS target is defined.

---

### D5 — GDD Re-Reviews Pending 🔴 Open

**Category**: Design
**Probability**: Low
**Impact**: Medium — Pathfinding and Wave Manager GDDs were revised post-review
but have not been re-reviewed; latent design debt may surface during implementation
**Status**: 🔴 Open
**Owner**: Creative Director
**Sprint**: S1-06 / S1-07
**Logged**: 2026-05-18 (gate check — CD concern)

**Description**: Both Pathfinding and Wave Manager GDDs were revised during
Systems Design (12 and 8 blockers resolved respectively) but the re-reviews were
deferred to Pre-Production. If the re-reviews find new issues, implementation
stories written against the current GDD text may need revision.

**Mitigation**: S1-06 and S1-07 — `/design-review` re-runs scheduled this sprint.
If PASS: risk closed. If REVISED: new revision committed and implementation
stories blocked until re-review clears.

**Trigger**: If implementation stories for Pathfinding or Wave Manager are written
before re-review completes, they are written against potentially stale GDD text.
Stories must reference the re-reviewed GDD version.

---

## Risk Log (Updates)

| Date | ID | Update |
|------|----|--------|
| 2026-05-19 | D1 | Mitigated — S1-01 PROCEED verdict. Technique viable at 6–8 layers. |
| 2026-05-19 | T1 | Logged — surfaced by S1-01 prototype finding (draw call count). |
| 2026-05-19 | D2 | Mitigated — ADR-0008 Accepted. Tower placement gate defined. OQ-4 resolved. |
| 2026-05-19 | D3 | Mitigated — S1-05 complete. Art bible Sections 5–6 written. Character + environment direction defined. |
| 2026-05-19 | D5 | Partial — S1-06 (pathfinding re-review) complete. Verdict: NEEDS REVISION → REVISED (7 blockers, all resolved in-session). GDD now in "Revised" state pending clean re-review. S1-07 (wave-manager) still backlog. Risk status: 🟡 Watch. |
| 2026-05-19 | D5 | Update — S1-07 (wave-manager re-review) complete. Verdict: NEEDS REVISION (9 blockers; prior APPROVED revoked). Design decisions captured in session. Revision deferred to next session (/design-review wave-manager.md after /clear). Both GDDs now re-reviewed. Risk remains 🟡 Watch pending Wave Manager revision + re-review. |
