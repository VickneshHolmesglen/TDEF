# Epic 13: Encyclopedia System

> **Layer**: Advanced Feature
> **GDD**: design/gdd/encyclopedia.md
> **Architecture Module**: Encyclopedia (`docs/architecture/architecture.md` — "Discovery registry — subscribes to numerous events")
> **Status**: Complete (2026-07-25)
> **Stories**: 3/3 stories Complete (2026-07-25) — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Discovery Event Ingestion | Integration | Complete (2026-07-25) | N/A |
| 002 | Emission and Query Contract | Logic | Complete (2026-07-25) | N/A |
| 003 | Persistence and Restore-Order Safety | Integration | Complete (2026-07-25) | N/A |

**Note**: no story here is `Blocked`. None have a dedicated governing ADR (matches Sanctuary UI/Tarot Deck UI/Audio System's own precedent). Story 003's AC-15b is jointly-owned evidence with at least 2 upstream systems' own test suites — flagged explicitly in that story's own file, not silently assumed solely Encyclopedia's to prove.

## Overview

The Encyclopedia System is the game's passive, cross-cutting discovery log — a permanent, read-only ledger that converts 7 already-frozen discovery events from 7 upstream systems (Constellation, Tarot, Crafting, Equipment Forge, Menagerie, Defense Building, Tower Mastery/Hero Skill Build) into named, categorized entries the player can never lose. It owns no gameplay logic and gates nothing; it only receives, records, and (via one frozen outbound event, `encyclopedia_entry_added`) notifies Mission HUD. It is deliberately data-only: no browsing UI is designed or built by this epic (GDD's own UI Requirements section explicitly defers that — Open Question OQ-5 — to avoid repeating a recent project mistake of bolting a late UI entry point onto an already-reviewed shell). This epic implements the discovery-ledger data model, the 7-event ingestion pipeline, duplicate suppression, the 2-method read-only query contract (`get_entries()`/`is_discovered()`), and Save & Persistence integration at `restore_order = 35` (restored last, since Encyclopedia's own data only ever references what every other system already restored).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| None yet | No dedicated architecture ADR exists for this system. Matches Sanctuary UI/Tarot Deck UI/Audio System's own established precedent (all three shipped stories without one, scoping directly from the GDD's own Core Rules). | LOW (per `architecture.md`: "Save read + EventBus", no post-cutoff API risk) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|---------------|
| None registered | Zero TR-IDs exist for this system in `docs/architecture/tr-registry.yaml` — matches the identical gap Sanctuary UI, Tarot Deck UI, and Audio System all shipped through. Stories will scope directly from the GDD's 8 Core Rules and 16 Acceptance Criteria (5 AC Groups). | ❌ No ADR, no TR-ID |

**Untraced requirements**: all of them — this is the same pre-existing, project-wide TR-registry gap for presentation/advanced-feature-layer systems already noted on 3 prior epics.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/encyclopedia.md` are verified (5 AC Groups: Discovery Event → Entry Conversion, Duplicate Suppression, `encyclopedia_entry_added` Emission Contract, Persistence, Core Purpose/Cross-System Record)
- All Logic and Integration stories have passing test files in `tests/`
- AC-15b (upstream systems don't fire a live discovery event as a side effect of their own restore) is jointly-owned evidence with at least 2 upstream systems' own test suites, per the GDD's own text — this epic's test can assert Encyclopedia's own side of it directly, but the full claim needs at least one cross-system integration test exercising a real save/restore cycle
- Content-authoring (a browsing UI, entry display metadata/icon lookups) is explicitly **out of scope** — the GDD itself defers this to Open Question OQ-5, a decision this epic does not reopen
- Bestiary/monster codex (Core Rule 6) and completion-percentage tracking (Core Rule 7) are explicitly out of scope per the GDD's own deferrals (OQ-1, OQ-2) — no story in this epic should attempt either

## Next Step

Run `/create-stories epic-13-encyclopedia` to break this epic into implementable stories.
