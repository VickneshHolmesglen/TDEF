# Quick Design Spec: Drop Gold from Sanctuary's Resource Header

**Type**: Tweak
**System**: Sanctuary UI (`design/gdd/sanctuary-ui.md`)
**GDD Reference**: `design/gdd/sanctuary-ui.md` Core Rule 3 / AC Group 3, `design/gdd/resource-economy.md` Rule 1, `docs/architecture/adr-0018-mission-economy-gold-balance.md`
**Date**: 2026-08-06

## Change Summary

Sanctuary's persistent resource header stops displaying gold — materials
only. Closes a real cross-GDD inconsistency found while investigating the
header's own flagged "no balance owner" gap, not a simple technical fix.

## Motivation

Investigating `resource_header.gd`'s own documented architectural gap (no
system owns a queryable Sanctuary-context gold balance) surfaced a deeper
problem: **there was never supposed to be one**. `resource-economy.md` and
ADR-0018 are explicit and deliberate — gold is mission-scoped, ephemeral
budget for in-mission tower placement, structurally identical to other
non-persistent mission-runtime scalars (wave number, hero HP), reset to 0
on every `mission_launched`, with no save/restore obligation and no
carry-over mechanic to the Sanctuary anywhere in the codebase. `sanctuary-
ui.md` Core Rule 3 asking for a persistent Sanctuary gold display, and its
own Edge Case instructing the header to "poll Resource Economy directly for
the current balance," was never actually implementable as written — Resource
Economy is a stateless calculation service (Rule 1: "owns no persistent data
of its own"). The header's real, shipped behavior (a session-wide running
total of every `resources_changed` delta it's ever observed) papers over
this without ever matching either GDD's stated intent. Removing gold from
this header resolves the inconsistency at its actual source rather than
inventing a new balance-owning system to serve a display that was never
supposed to exist.

## Design Delta

Current `sanctuary-ui.md` says (Core Rule 3):

> A read-only gold/materials display renders at the top edge of the screen
> in every state, including `OVERVIEW`. It is a pure subscriber to
> `resources_changed`/`materials_earned`/`materials_spent`...

Edge Cases:

> If `resources_changed` hasn't fired yet by the time Sanctuary UI finishes
> mounting (boot-order race): Core Rule 3's header polls Resource Economy
> directly for the current balance as a mount-time fallback...

This spec changes both to:

> A read-only **materials** display renders at the top edge of the screen
> in every state, including `OVERVIEW`. It is a pure subscriber to
> `materials_earned`/`materials_spent`. Gold is explicitly **not** shown
> here — gold is mission-scoped ephemeral budget (`resource-economy.md`
> Rule 1, ADR-0018) with no Sanctuary-context meaning; it remains visible
> only in Mission HUD, where its lifecycle is actually correct.

Edge Cases entry updated to:

> If `materials_earned`/`materials_spent` haven't fired yet by the time
> Sanctuary UI finishes mounting (boot-order race): the header shows
> whatever materials total has accumulated locally so far (0 if none),
> matching this project's existing "mechanism real, content placeholder"
> tolerance for a cold-boot empty state — no poll-based fallback exists or
> is needed, since no external system owns a queryable materials balance
> either (Inventory is the ledger of record, but exposing a live poll API
> from it is a separate, larger scope not entered into here).

## New Rules / Values

1. `ResourceHeader` (`resource_header.gd`) drops its `_gold` field,
   `GoldIcon`/`GoldLabel` nodes, `get_gold()` accessor, and its
   `resources_changed` subscription entirely. `MaterialsLabel` (and its
   existing local-accumulation behavior) is unchanged.
2. `GOLD_ICON_TEXTURE`/`GOLD_ICON_SIZE` constants removed from this file —
   the icon asset itself (`assets/art/ui/gold_coin.png`) is untouched and
   stays in use by Mission HUD.
3. `ResourceRow`'s remaining children (just `MaterialsLabel` now) keep the
   same scale-pop animation on `materials_earned`/`materials_spent`.
4. No change to Mission HUD's gold display — that one is correct as-is
   (gold's real lifecycle is mission-scoped, matching where it's shown).

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `design/gdd/sanctuary-ui.md` | Core Rule 3 text, one Edge Case entry, AC Group 3's gold-referencing AC | Update GDD (separate approval) |
| `src/presentation/sanctuary_ui/resource_header.gd` | Remove gold field/nodes/accessor/subscription | Update script |
| `tests/integration/sanctuary-ui/resource-header_test.gd` | Remove gold-specific assertions/tests | Update tests |

## Acceptance Criteria

- [ ] Sanctuary's header shows materials only — no gold icon, no gold number, in any state (`OVERVIEW`/any `ROOM_*`)
- [ ] `get_gold()` and gold-related nodes no longer exist on `ResourceHeader`
- [ ] Materials display and its scale-pop animation are unaffected
- [ ] Mission HUD's gold display is completely unchanged
- [ ] No regression in Sanctuary UI's other test suites
- [ ] Live-verified via Godot MCP

## GDD Update Required?

Yes — `design/gdd/sanctuary-ui.md`, Core Rule 3 (drop "gold/" from the
display description), the mount-time-poll Edge Case (replace with the
no-poll-needed text above), and AC Group 3's first AC (currently asserts
`gold=120, materials={wood:5}` — drop the gold half). Exact wording shown
above; will ask separately before editing, per this skill's own protocol.
