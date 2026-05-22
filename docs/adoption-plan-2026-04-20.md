# Adoption Plan

> **Generated**: 2026-04-20
> **Project phase**: Systems Design
> **Engine**: Godot 4.6.2 / GDScript
> **Template version**: v1.0+

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

---

## Step 1: Fix Blocking Gaps

These three items are all the same root cause: the GDD content from the prior
project lives in `docs/MTD GDD.md` but needs to be in `design/gdd/` in the
studio's 8-section format. Until this migration is done, the following skills
will produce incorrect or empty results: `/gate-check`, `/map-systems`,
`/review-all-gdds`, `/architecture-review`, `/create-stories`, `/create-epics`.

### 1a. Create the game concept document
**Problem**: `design/gdd/game-concept.md` does not exist. The high-level concept
for Sanctuary Defenders (RPG Tower Defense, 9 systems) is captured in
`docs/MTD GDD.md` but is not yet in the studio's standard location.

**Fix**: Run `/design-system game-concept` — or manually create
`design/gdd/game-concept.md` using the Introduction section from `docs/MTD GDD.md`
as source material. Required sections: Overview, Player Fantasy, Detailed Rules,
Formulas, Edge Cases, Dependencies, Tuning Knobs, Acceptance Criteria.

**Time**: 30 min
- [ ] `design/gdd/game-concept.md` created

---

### 1b. Create per-system GDDs (9 systems)
**Problem**: Zero system GDD files exist in `design/gdd/`. The 9 systems
from `docs/MTD GDD.md` (Hero, Inventory, Monster, Tower, Building,
Crafting, Menagerie, Tarot, Constellation/Integration) need individual
GDD files in the 8-section studio format.

**Fix**: Run `/design-system [system-name]` for each system, using
`docs/MTD GDD.md` as reference material. Suggested order (dependency-safe):

1. `/design-system hero-system` — (no system dependencies)
2. `/design-system inventory-system` — (no system dependencies)
3. `/design-system monster-system` — (no system dependencies)
4. `/design-system tower-system` — (depends on inventory, monster)
5. `/design-system building-system` — (depends on tower)
6. `/design-system crafting-system` — (depends on inventory)
7. `/design-system menagerie-system` — (depends on crafting)
8. `/design-system tarot-system` — (no system dependencies)
9. `/design-system combat-system` — (depends on hero, monster, tower)

**Time**: 1 session (~30–45 min per system, run iteratively)
- [ ] `design/gdd/hero-system.md` created
- [ ] `design/gdd/inventory-system.md` created
- [ ] `design/gdd/monster-system.md` created
- [ ] `design/gdd/tower-system.md` created
- [ ] `design/gdd/building-system.md` created
- [ ] `design/gdd/crafting-system.md` created
- [ ] `design/gdd/menagerie-system.md` created
- [ ] `design/gdd/tarot-system.md` created
- [ ] `design/gdd/combat-system.md` created

---

### 1c. Create the systems index
**Problem**: `design/gdd/systems-index.md` does not exist. Every phase-gate
check and cross-system skill reads this file to know what systems exist
and their status.

**Fix**: Run `/map-systems` after game-concept.md exists (Step 1a). This
skill generates the systems index from the game concept document.

**Time**: 15 min
- [ ] `design/gdd/systems-index.md` created

---

## Step 2: Fix High-Priority Gaps

### 2a. Record the first ADR — framework-first architecture
**Problem**: Zero ADRs exist in `docs/architecture/`. The event-driven,
data-driven, dependency-injection architecture described in `docs/MTD GDD.md`
is not captured as a formal decision. `/story-readiness` ADR checks are blind,
and `/architecture-review` has no decisions to validate against.

**Fix**: Run `/architecture-decision` and record the framework-first,
event-driven architecture as ADR-0001. Use the Integration Framework section
of `docs/MTD GDD.md` as source material (EventBus, Manager pattern,
SaveableSystem interface).

**Time**: 30 min
- [ ] `docs/architecture/adr-0001-framework-first-event-driven.md` created

### 2b. Create the control manifest
**Problem**: `docs/architecture/control-manifest.md` does not exist. Stories
reference a manifest version stamp for staleness checks — without the manifest,
stories can't detect when architecture rules have changed.

**Fix**: Run `/create-control-manifest` after at least one ADR exists (Step 2a).

**Time**: 30 min
- [ ] `docs/architecture/control-manifest.md` created

### 2c. Write the authoritative stage file
**Problem**: `production/stage.txt` does not exist. Phase auto-detection
is unreliable across all skills that gate on project phase.

**Fix**: Run `/gate-check systems-design` after completing Step 1. This
writes `production/stage.txt` with the authoritative phase verdict.

**Time**: 5 min (after Steps 1 and 2a–2b complete)
- [ ] `production/stage.txt` written

---

## Step 3: Bootstrap Infrastructure

### 3a. Register existing requirements (creates tr-registry.yaml entries)
`docs/architecture/tr-registry.yaml` exists but is empty. Run
`/architecture-review` after GDDs and at least one ADR exist — this run
bootstraps the registry from your GDD content.

**Time**: 1 session
- [ ] `tr-registry.yaml` populated with TR-IDs from GDDs

### 3b. Create sprint tracking file
Run `/sprint-plan new` to start the first sprint. This creates
`production/sprint-status.yaml`.

**Time**: 30 min
- [ ] `production/sprint-status.yaml` created

---

## Step 4: Medium-Priority Gaps

### 4a. Verify tr-registry.yaml after /architecture-review
After Step 3a, check that the registry has entries for all 9 systems.
Re-run `/architecture-review` if any systems were added after the first run.

**Time**: 5 min
- [ ] TR-IDs exist for all 9 systems in tr-registry.yaml

### 4b. Clarify or archive docs/MTD TAD.md
`docs/MTD TAD.md` appears to have identical content to `docs/MTD GDD.md`.
Once the GDD migration is complete, this file is redundant. Either:
- Archive it to `docs/archive/MTD TAD.md`, or
- Confirm it's intentionally different and document what it covers

**Time**: 5 min
- [ ] `docs/MTD TAD.md` status resolved (archived or documented)

---

## Step 5: Optional Improvements

### 5a. Review and curate docs/ reference files
`docs/Frameworks.md`, `docs/Editable_Files.md`, and `docs/implementation-plan.md`
are reference material from the prior project. They may contain useful
implementation detail for the restart, but are not in studio format.
Consider annotating each with a note: "Reference from prior project — see GDD
at design/gdd/[system].md for current design."

**Time**: 15 min
- [ ] Reference files in docs/ annotated or archived as appropriate

---

## What to Expect from Existing Stories

No stories exist yet — this step is not applicable. When stories are generated
after GDDs and ADRs exist, they will include full TR-ID references and manifest
version stamps from the start.

---

## Recommended Sequence

```
/design-system game-concept     ← creates game-concept.md (Step 1a)
/map-systems                    ← creates systems-index.md (Step 1c)
/design-system hero-system      ← first of 9 system GDDs (Step 1b, repeat ×9)
... (remaining 8 systems)
/architecture-decision          ← ADR-0001 framework-first (Step 2a)
/create-control-manifest        ← control manifest (Step 2b)
/gate-check systems-design      ← writes stage.txt (Step 2c)
/architecture-review            ← bootstraps tr-registry.yaml (Step 3a)
/sprint-plan new                ← sprint tracking (Step 3b)
```

---

## Re-run

Run `/adopt` again after completing Step 2 to verify all blocking and high gaps
are resolved. The new run will reflect the current state of the project.
