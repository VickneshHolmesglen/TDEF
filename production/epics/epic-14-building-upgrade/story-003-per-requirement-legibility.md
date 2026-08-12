# Story 003: Per-Requirement Legibility (VISIBLE_LOCKED chips)

> **Epic**: Building Upgrade System
> **Status**: Complete
> **Layer**: Advanced
> **Type**: UI
> **Estimate**: M (3-4 hours)
> **Manifest Version**: 2026-07-13b
> **Last Updated**: 2026-08-12

## Context

**GDD**: `design/gdd/building-upgrade.md`
**Requirement**: `TR-buildupgrade-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: N/A — pure UI rendering of already-available data (`_requirement_satisfied()` per-entry results, already computed by Story 001's shipped code); reuses Crafting's own established per-ingredient checklist convention (`crafting.md` Rule 4/Visual Requirements) rather than inventing a new pattern. No new architectural decision required.

**Engine**: Godot 4.6.2 | **Risk**: LOW
**Engine Notes**: Standard `Control`/`Button`/icon rendering — no post-cutoff API risk. Dual-focus (K/M + gamepad) applies per `technical-preferences.md`.

**Control Manifest Rules (this layer)**:
- Required: Non-color-first state cues (colorblind-safe icon/shape, not color alone) — project-wide convention, see `defense-building.md`'s built/unbuilt distinction, `crafting.md`'s "!" badge precedent
- Required: Full K/M support; gamepad navigation must reach every interactive element (no hover-only/touch-only interactions) — `technical-preferences.md`
- Forbidden: `$NodePath` lookups inside `_process()` — cache via `@onready`

---

## Acceptance Criteria

*From GDD `design/gdd/building-upgrade.md`, scoped to this story:*

- [ ] **AC-6**: GIVEN an upgrade with 2+ `requirements` entries where at least one is satisfied and at least one is not, WHEN `VISIBLE_LOCKED` is rendered, THEN each entry shows its own satisfied/unmet state and the specific target's resolved display name independently — not one collapsed pass/fail state for the whole upgrade.
- [ ] **AC-6b** (added during `/story-readiness`, closing a Definition-of-Done minimum-AC gap — UI stories require ≥2 testable criteria): GIVEN an upgrade with `requirements` entries spanning 2+ different categories (e.g. `"building"` and `"equipment"`), WHEN `VISIBLE_LOCKED` is rendered, THEN each category renders a distinct, non-color-only icon/shape — a colorblind player can distinguish which chip is which category without relying on color alone (Control Manifest's non-color-first rule).

---

## Implementation Notes

*Derived from GDD Rule 2a:*

- `equipment_forge_screen.gd`'s current `VISIBLE_LOCKED` rendering is a single binary `READY`/`REQUIREMENTS_UNMET` tag (confirmed during `/design-review`, 2026-08-12) — replace with one row/chip per `requirements` entry.
- Each chip shows: (a) category icon (building/equipment/tarot/creature — 4 distinct, colorblind-safe shapes, not color-only), (b) the specific target's resolved display name — read from that target's own content resource (`GGameDataRegistry.get_structure(structure_id).display_name` or equivalent for item/card/species — confirm each Resource type's actual display-name field before wiring; do not fall back to raw `StringName` ids, which are not player-facing text), (c) satisfied (checkmark, filled) vs. unmet (lock glyph, non-color-safe) state.
- Live-updates on the same EventBus re-evaluation Rule 4/`can_purchase()`'s existing live re-check already drives — no new polling loop.
- Reuse Crafting's existing ingredient-checklist Control/Theme setup if one already exists as a reusable component; do not fork a second implementation of the same visual pattern.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: the PURCHASABLE-transition Connection Badge and purchase chime (Rule 6a) — a different UI/audio surface
- Accessibility spec beyond colorblind-safe iconography and dual-focus reachability (full text-scale/gamepad-focus-order spec) — flagged in `building-upgrade.md`'s Open Questions as a follow-up, not required to close this story

---

## QA Test Cases

**Manual check: AC-6**
- Setup: In Sanctuary, open the Building Upgrade tab with an upgrade that has ≥2 requirements, at least one currently satisfied (e.g. a built structure) and at least one currently unmet (e.g. an uncrafted item).
- Verify: Each requirement renders as its own chip with its own category icon, resolved display name (not a raw id), and satisfied/unmet state — not a single collapsed lock icon for the whole row.
- Pass condition: A player looking at the screen can correctly state, for each of the upgrade's requirements, whether it's met and what it specifically is — verified via the same experiential-test approach `sanctuary-ui.md`'s AC-302 already uses for Connection Badge legibility (a moderated read-back, not just "the icon renders").

**Manual check: AC-6b**
- Setup: Same as AC-6, with an upgrade whose `requirements` span at least 2 different categories.
- Verify: Each category's icon is a distinct shape/glyph, not just a distinct color — a colorblind simulation filter (or grayscale screenshot) should still let a viewer tell the categories apart.
- Pass condition: No two categories are distinguishable by color alone.

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/building-upgrade-requirement-legibility-evidence.md` — manual verification + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE — reads its `_requirement_satisfied()` per-entry results)
- Unlocks: None

## Completion Notes
**Completed**: 2026-08-12
**Criteria**: 2/2 passing (AC-6, AC-6b)
**Deviations**: ADVISORY (self-corrected) — first implementation pass added an out-of-scope "Tower Assembly" tab and left the old binary READY/REQUIREMENTS_UNMET tag in place; both found during review and fixed before code-review/story-done.
**Test Evidence**: UI — `production/qa/evidence/building-upgrade-requirement-legibility-evidence.md` (2 live Godot MCP screenshots) + 6 automated integration tests in `tests/integration/equipment-forge-screen/equipment_forge_screen_test.gd`
**Code Review**: Complete — APPROVED (3 specialist passes, 2 minor coverage gaps found and closed)
