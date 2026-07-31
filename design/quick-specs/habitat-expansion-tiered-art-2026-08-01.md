# Quick Design Spec: Habitat Expansion Tiered Diorama Art

**Type**: Addition
**System**: Sanctuary UI (Diorama)
**GDD Reference**: `design/gdd/sanctuary-ui.md`
**Date**: 2026-08-01

## Change Summary

`habitat_expansion` gains real, tier-specific art in the Sanctuary diorama. Its current `ColorRect` placeholder is replaced with a `TextureRect` that swaps texture when a higher tier is built, using a user-provided 4-building reference set cropped into 3 per-tier sprites (matching the 3 real `StructureResource` tiers that already exist: `habitat_expansion_tier_1/2/3`).

## Motivation

`watchtower` (2026-07-31) already moved from placeholder to real art but is single-tier (`tier_1` is the only `StructureResource` that exists for it), so its diorama rendering never needed to handle a texture change after first render. `habitat_expansion` is different: 3 real, distinct tiers already exist with increasing gold/material costs, but the diorama currently renders identically regardless of which tier is active — a real player-facing gap between "I paid to upgrade the habitat" and "nothing visibly changed." The source art (`assets/Art Assets/Habitat Building Set.png`) happens to already depict exactly this progression (kennel → stable → menagerie hall → grand menagerie, 4 buildings), making 3 of its 4 buildings a direct fit for the 3 tiers that exist today.

## Design Delta

Current behavior (`diorama.gd`'s own doc comment, `_render_structure()`):

> "already rendered -- a later tier of the same type upgrades in place (same visual, no new asset yet, honest scope)"

This spec changes that specifically for `habitat_expansion`:

When `sanctuary_structure_built` fires for a `habitat_expansion` tier at or above the currently-rendered tier, the diorama's `TextureRect` for `habitat_expansion` swaps its texture to the new tier's sprite, in place, without creating a new node. `watchtower`'s behavior (and any other future single-tier structure_type) is unchanged — this is additive only for structure types with real multi-tier art available.

## New Rules / Values

1. Add 3 new per-tier textures: `assets/art/sanctuary/habitat_tier_1.png`, `habitat_tier_2.png`, `habitat_tier_3.png` — cropped from `assets/Art Assets/Habitat Building Set.png` (the 1st/2nd/3rd buildings left-to-right), background color-keyed to transparency the same way `watchtower.png` was processed. The 4th (grandest) building is not used — no `tier_4` `StructureResource` exists.
2. `diorama.gd` gains a `HABITAT_TEXTURES: Dictionary[int, Texture2D]` constant mapping tier int (1/2/3) to its texture.
3. `_render_structure(structure_type)`'s habitat branch resolves the built structure's tier via `GGameDataRegistry.get_structure(structure_id).tier` (an existing, already-used API — see `defense_building.gd`), not by parsing `structure_id` string suffixes.
4. New state: the diorama tracks the currently-rendered tier for `habitat_expansion` (a new `_habitat_tier: int = 0` field, 0 = not built yet). On `sanctuary_structure_built`, if the incoming tier is greater than `_habitat_tier`, the `TextureRect.texture` is swapped and `_habitat_tier` is updated; if equal or lower (should not happen in real play — tiers only build forward — but must not error or downgrade the visual), no-op.
5. The habitat occupancy `Label` (`_ensure_habitat_label`) is unaffected — it's already parented to the structure's `Control` node, which persists across texture swaps since the node itself isn't recreated.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `src/presentation/sanctuary_ui/diorama.gd` | New texture-swap-on-upgrade path for `habitat_expansion` only | Implement per New Rules above |
| `tests/integration/sanctuary-ui/diorama_test.gd` | New tests needed for tier-swap behavior | Add tests |
| `assets/art/sanctuary/` | 3 new cropped/keyed PNGs | Generate from source reference image |

## Acceptance Criteria

- [ ] `habitat_expansion_tier_1` built → diorama renders `habitat_tier_1.png` as a `TextureRect`
- [ ] `habitat_expansion_tier_2` built after tier_1 → same node's texture swaps to `habitat_tier_2.png`, no duplicate node created
- [ ] `habitat_expansion_tier_3` built after tier_2 → swaps to `habitat_tier_3.png`
- [ ] Habitat occupancy label still renders and updates correctly after a texture swap (it's a child of the same persistent node)
- [ ] `watchtower`'s existing single-tier rendering is unchanged (no regression)
- [ ] No regression: `test_a_later_tier_of_the_same_structure_type_does_not_duplicate_the_visual` (generic dedup test, still applies — texture swap must not create a second node)

## GDD Update Required?

No. `sanctuary-ui.md` is silent on tier-specific art (Visual/Audio Requirements section explicitly defers "diorama stacked-sprite... treatment" to lead sign-off/screenshot evidence, not spec text) — this fills an implementation gap without contradicting or needing to restate any documented rule.
