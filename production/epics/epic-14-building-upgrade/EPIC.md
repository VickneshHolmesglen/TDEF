# Epic 14: Building Upgrade System

> **Layer**: Advanced
> **GDD**: `design/gdd/building-upgrade.md`
> **Architecture Module**: Building Upgrade System (no entry in `architecture.md`'s Module Ownership section — that document's last full pass predates this system, 2026-07-13; same pre-existing gap Epic 08 already documented for Hero Skill Build/Equipment Forge)
> **Status**: Ready — backend/UI implemented 2026-08-11, `/design-review` passed (with revisions) 2026-08-12, ADR-0034 written and Accepted same day, stories created same day.
> **Stories**: 5 created — 2 Complete (1 retroactive), 3 Ready

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Core Requirement Resolution & Purchase Ledger | Logic | Complete (retroactive) | ADR-0034 |
| 002 | Content Validation — Prerequisite Cycle Guard & Chain Cap | Logic | Complete | ADR-0034 |
| 003 | Per-Requirement Legibility (VISIBLE_LOCKED chips) | UI | Ready | N/A — reuses Crafting's checklist convention |
| 004 | PURCHASABLE Notification & Purchase Feedback | Integration | Ready | N/A — reuses Sanctuary UI Connection Badge + Defense Building chime |
| 005 | Edge-Case Regression Coverage | Logic | Ready | ADR-0034 |

## Overview

Building Upgrade is the Sanctuary's convergence layer: a purchasable, permanent upgrade to an already-built Defense Building structure, gated not on a single currency but on a combination of 1-4 things the player has independently accomplished elsewhere in the game — another structure built, a specific piece of crafted Equipment owned, a specific Tarot card unlocked, a specific Menagerie creature species tamed — plus a conventional gold+material cost. Unlike Crafting, none of the four requirement categories are consumed by purchasing; they are read, non-destructively, from the four systems that already own that state (Defense Building, Inventory, Tarot, Menagerie). This epic is unusual among this project's epics in that its backend (`BuildingUpgrade`, `BuildingUpgradeResource`) and UI (a tab inside Equipment Forge's own screen) were implemented and tested (2026-08-11) *before* this epic, its governing ADR, or a formal design review existed — this epic and ADR-0034 retroactively formalize what was already shipped, and the stories that follow will close the gap between that shipped baseline and the 2026-08-12 design-review revisions layered on top (see Known Blockers).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0034 (Building Upgrade Cross-System Requirements Model) | Recipe-style Resource + permanent `_purchased_upgrades` ledger (mirrors Defense Building's own ledger shape); 3 of 4 upstream requirement-category reads (Defense Building, Inventory, Menagerie) classified as ADR-0020 Criterion A direct-Autoload-call exceptions; the 4th (Tarot) explicitly flagged as a group-lookup read NOT covered by any existing ADR, since Tarot isn't an Autoload | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| TR-buildupgrade-001 | `BuildingUpgradeResource` recipe model — 1-4 requirement categories checked non-destructively, plus a spent gold+material cost | ✅ ADR-0034 |
| TR-buildupgrade-002 | Cross-system read architecture — 3 Criterion-A direct Autoload calls + 1 flagged non-ADR-0020 group-lookup read of Tarot | ✅ ADR-0034 |
| TR-buildupgrade-003 | Permanent `PURCHASED` ledger, `SaveRestorer` at `restore_order=33` | ✅ ADR-0034 |
| TR-buildupgrade-004 | Player-facing notification model — per-requirement `VISIBLE_LOCKED` legibility (Rule 2a), `PURCHASABLE`-transition Connection Badge + purchase confirmatory chime (Rule 6a) | ❌ No ADR — added by the 2026-08-12 design-review revision; not yet implemented in code (existing `equipment_forge_screen.gd` only renders a binary `READY`/`REQUIREMENTS_UNMET` tag today) |

**3 / 4 requirements have ADR coverage.** TR-buildupgrade-004's stories will need either a small ADR-0034 amendment (the notification model is arguably covered by citing ADR-0032's Connection Badge precedent + `defense-building.md`'s existing chime precedent directly, rather than needing wholly new architecture) or should be scoped as `Needs Design` at story-creation time — a judgment call for `/create-stories`, not resolved here.

## Known Blockers

- **`"tarot"`-keyed upgrade content cannot ship yet.** Tarot has no live, Sanctuary-reachable instance (ADR-0034 Risks; `building-upgrade.md` Open Questions) — any upgrade using a `"tarot"` requirement fails closed permanently. Not this epic's own defect to fix; needs Tarot's own architecture ADR (likely Autoload conversion).
- **BUG-0001 (S1-Critical, `production/qa/bugs/BUG-0001.md`)**: independent of this epic, but touches the same Tarot dependency — Tarot's entire save ledger silently drops from any save taken outside `TarotDeckUI.tscn`. Filed, not fixed, by this session.
- **TR-buildupgrade-004's stories are not yet implemented** — the 2026-08-12 design-review revision (per-requirement legibility, Connection Badge, purchase chime, `BuildingUpgradeResource.validate()`, prerequisite-chain cycle guard + tier cap) exists only in `design/gdd/building-upgrade.md` today, not in `src/core/building_upgrade/building_upgrade.gd` or `equipment_forge_screen.gd`. This is this epic's primary remaining implementation work — the backend/UI that already shipped 2026-08-11 predates and does not yet reflect these additions.
- **No Watchtower/Habitat Expansion mechanical effect exists yet** for `structure_upgraded` to drive (GDD Rule 7, deliberately scaffolded — matches `defense-building.md`'s own precedent for Watchtower's base effect). Not blocking this epic; purchasing an upgrade today has no downstream mechanical consequence beyond the ledger write + notification.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria (AC-1 through AC-13) from `design/gdd/building-upgrade.md` are verified — including the 6 new/renumbered ACs from the 2026-08-12 revision (AC-6, AC-8 through AC-13)
- `BuildingUpgradeResource.validate()` (Rule 1b) exists and is exercised by a test proving both the cycle-guard and the 3-tier chain cap reject malformed content
- The per-requirement legibility (Rule 2a), Connection Badge (Rule 6a), and purchase-confirmation chime (Rule 6a) are implemented in `equipment_forge_screen.gd`, not just specified in the GDD
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories epic-14-building-upgrade` to break this epic into implementable stories. Recommend sequencing: (1) `BuildingUpgradeResource.validate()` + cycle/tier-cap guard first (closes a real crash risk, no dependencies), (2) per-requirement legibility UI, (3) Connection Badge + purchase chime wiring, (4) content-authoring pass for any new upgrades — hold any `"tarot"`-keyed upgrade content until Tarot's own live-instance gap and BUG-0001 are resolved by a separate effort.
