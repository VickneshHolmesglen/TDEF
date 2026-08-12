# ADR-0035: Tarot Autoload Conversion

## Status
Accepted

## Acceptance Note
Accepted 2026-08-12 by explicit user decision, same day as drafting — same precedent as ADR-0027/ADR-0034's own same-day acceptances. `godot-specialist` validation pass (2026-08-12) found zero blocking issues; the 5 non-blocking warnings raised (orphaned `ext_resource` cleanup, doc-comment scope, autoload-position rationale, headless class-cache verification note, Equipment Forge follow-up flag) were all incorporated directly into this ADR's Migration/Risks/Related-Decisions sections before acceptance. Review mode `lean` — TD-ADR strategic gate skipped per this session's resolved mode.

## Date
2026-08-12

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (Autoload / singleton lifecycle) |
| **Knowledge Risk** | LOW — Autoload registration (`project.godot`'s `[autoload]` section, `*res://...gd` singleton syntax) is a long-stable Godot 4.x mechanism, unrelated to any post-cutoff API change tracked in `docs/engine-reference/godot/VERSION.md`. Every other cross-scene-persistent system in this project (`GDefenseBuilding`, `GInventory`, `GMenagerie`, `GHeroSkillBuild`, `GEncyclopedia`, etc.) already uses this exact mechanism — this ADR applies an established, already-verified pattern, not a novel one. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (no Autoload-related entries — confirmed not a tracked risk item); `project.godot`'s existing `[autoload]` section (13 existing entries, all `Node`-derived scripts registered as `*res://path.gd`) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Live confirmation (Godot MCP) that `GTarot`'s EventBus subscriptions (`mission_launched`, `mission_phase_changed`, `run_modifier_selected`, `scene_transition_completed`), now permanent for the process lifetime instead of scoped to `TarotDeckUI.tscn`'s mount/unmount, do not change observable behavior for `_locked`, `_active_mission_deck`, or `_run_modifier_selected_types` (see Risks). Per `docs/engine-reference/godot/VERSION.md`'s "Global `class_name` resolution via headless `run_project`/MCP tools" gotcha, run `Godot.exe --headless --editor --path <project> --quit` once before MCP-driving the new `GTarot` autoload, to avoid a false "GTarot not found" failure from a stale `.godot/global_script_class_cache.cfg` masquerading as a real defect. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0027 (Tarot Modifier Aggregation Pipeline — this ADR does not change ADR-0027's F1/ledger-shape decisions, only Tarot's instantiation model); ADR-0003 (Save & Persistence — Tarot's `register()`/`unregister()` calls and `SaveRestorer` interface are unchanged by this ADR, only *when* they fire) |
| **Enables** | Building Upgrade's `"tarot"`-requirement type (currently fails closed — no live Tarot instance reachable from Sanctuary UI, per ADR-0034's own flagged Risk); a real fix for `production/qa/bugs/BUG-0001.md` |
| **Blocks** | None further downstream |
| **Ordering Note** | `restore_order = 22` (already assigned in `save-persistence.md`) is unchanged — Tarot reads no other system's state during its own `restore_save_data()`, so no reordering is required by this ADR. Epic 07 Tarot Story 006 remains separately blocked on Wave Manager/Monster System consumption logic that does not exist yet — this ADR does not resolve that gap, only the two Tarot-instance-reachability gaps named above. |

## Context

### Problem Statement

Tarot (`src/core/tarot/tarot.gd`) is deliberately scene-instanced, not an Autoload (ADR-0027's original decision) — its one real instance lives as a child node of `TarotDeckUI.tscn`, created when that screen mounts and destroyed when it unmounts. This has two independent, now-confirmed consequences:

1. **BUG-0001 (S1-Critical, filed 2026-08-12)**: Tarot's `_ready()`/`_exit_tree()` register/unregister with `GSavePersistence` exactly like every other `SaveRestorer` in the project — but because that lifecycle is tied to `TarotDeckUI.tscn`'s own mount state, any save taken while that one screen is not mounted (Sanctuary overview, any mission, any other Sanctuary room — effectively the vast majority of play time) silently omits Tarot's entire persisted state from the save, with no error or fallback.
2. **No live Tarot instance reachable from Sanctuary UI** (found during Building Upgrade's 2026-08-12 `/design-review`, documented in ADR-0034's Risks): Building Upgrade's `"tarot"`-requirement check (`building_upgrade.gd:98`) does `get_tree().get_first_node_in_group(&"tarot")`, which returns `null` whenever the player is anywhere in Sanctuary UI (Tarot Deck UI is a separate, mutually-exclusive top-level screen reached via a full `SceneManager` transition) — the requirement check fails closed permanently, not just when genuinely unmet.

Both gaps trace to the same root cause: Tarot's instantiation lifetime is scoped to one specific screen, but its state (and other systems' need to read that state) is not.

### Constraints
- Must not change ADR-0027's F1 mastery-scaling logic, the 3 persisted ledger shapes (`_mastery_missions_played`, `_rune_discovered`, `_card_unlocked`), or the `_current_deck` template field.
- Must not introduce a second, parallel Tarot instance (ADR-0034's Risks section already found and rejected this approach for the requirement-check gap alone — a second shell-owned instance inside `SanctuaryUI.tscn` would leave two never-simultaneously-alive instances with no state handoff between them, and would not fix BUG-0001 either, since neither instance is reachable while the *other* screen is mounted, and neither is reachable during a mission at all).
- `restore_order = 22` must remain collision-free against the authoritative table in `save-persistence.md`.

### Requirements
- Tarot's state (all 3 ledgers + deck template) must be present in every save, regardless of which scene is currently active.
- Tarot's public query/mutation API (`is_card_unlocked()`, `equip_card()`, `get_current_deck()`, etc.) must be reachable from any system, at any time, matching every other Autoload's calling convention (`GDefenseBuilding.is_tech_unlocked()`, `GInventory.has_specific_item()`, etc.).

## Decision

Convert Tarot to a true Autoload, registered as `GTarot="*res://src/core/tarot/tarot.gd"` in `project.godot`'s `[autoload]` section, alongside the project's 13 existing Autoloads. This makes Tarot a single, persistent `Node` instance created once at boot and living for the entire process lifetime — identical in kind to `GDefenseBuilding`, `GInventory`, `GMenagerie`, and every other cross-scene-persistent system.

**No change is required to Tarot's own `_ready()`/`_exit_tree()` register/unregister logic, its `SaveRestorer` interface (`get_save_key()`, `get_save_data()`, `restore_save_data()`, `reset_to_defaults()`), or any of its 3 ledgers.** This code already matches every other Autoload `SaveRestorer`'s exact convention (register in `_ready()`, unregister in `_exit_tree()`) — the only defect was *where* that `_ready()`/`_exit_tree()` pair actually fired. As an Autoload, `_ready()` fires once at boot (registering Tarot with `GSavePersistence` for the entire session) and `_exit_tree()` fires only at application shutdown — fixing BUG-0001 as a direct structural consequence, not a special-cased patch.

### Migration

1. Add `GTarot="*res://src/core/tarot/tarot.gd"` to `project.godot`'s `[autoload]` section. Position: anywhere after `GEventBus`/`GSavePersistence` (positions 1-2) — Tarot's `_ready()` only touches those two, both unconditionally earlier in the list, so no other autoload-ordering constraint applies (unlike, e.g., `GDefenseBuilding`'s own documented Inventory-ordering dependency).
2. Remove the `Tarot` child node (`type="Node"`, script `res://src/core/tarot/tarot.gd`) AND its now-orphaned `ext_resource` entry (`id="4_tarot"`, line 6) from `TarotDeckUI.tscn` — its one current instantiation site. No other scene instantiates Tarot (confirmed by search).
3. Migrate the 3 existing group-lookup call sites from `get_tree().get_first_node_in_group(&"tarot")` to a direct `GTarot` reference, matching every other Autoload's calling convention project-wide:
   - `src/presentation/tarot_deck_ui/snapshot_chip.gd:51`
   - `src/gameplay/ui/tarot_screen/tarot_screen.gd:106`
   - `src/core/building_upgrade/building_upgrade.gd:98` (this is the call ADR-0034 flagged as NOT an ADR-0020 Criterion A instance — it becomes one after this migration)
4. Remove `GROUP_NAME`/`add_to_group(GROUP_NAME)` from `tarot.gd` — with all 3 callers migrated to `GTarot`, group-based self-discovery becomes dead code specific to the old scene-instanced model. (Confirmed via search: no other file references the `"tarot"` group.)
5. Update `tarot.gd`'s class doc comment (lines 4-5) to remove the "Scene-instanced — NOT an Autoload" framing, and remove/rewrite the `GROUP_NAME` doc block (lines 108-115, "Group membership added 2026-07-25... mirrors `equipment_forge.gd`'s identical `'equipment_forge'` group precedent") alongside step 4's removal of `GROUP_NAME` itself.
6. Update `TarotScreen.tscn`/`tarot_screen.gd` and any test fixtures that currently instantiate a local `Tarot.new()` + `add_child()` to either use `GTarot` directly (integration tests exercising the real Autoload) or continue instantiating a local instance for pure-unit isolation where that remains the correct test seam (matching this project's existing convention of both approaches coexisting — e.g. `GDefenseBuilding` is an Autoload but `building_upgrade_test.gd` still builds local `BuildingUpgradeResource` fixtures where isolation is the goal). This ADR does not mandate rewriting every existing Tarot unit test — only that any test currently relying on group-based discovery (`get_tree().get_first_node_in_group(&"tarot")`) is updated to match the migrated call sites above.

### Key Interfaces

No new interfaces. `Tarot`'s existing public API (`is_card_unlocked()`, `equip_card()`, `unequip_card()`, `get_active_card_count()`, `get_current_deck()`, `is_rune_discovered()`, `compute_rune_bonus()`, `get_mastery_missions_played()`, `get_mastery_tier()`, `has_run_modifier_conflict()`) is unchanged — only reachable via `GTarot.<method>()` instead of a group-lookup-then-cast.

## Alternatives Considered

### Alternative 1: Add a second shell-owned Tarot instance inside SanctuaryUI.tscn
- **Description**: Mirror `BuildingUpgrade`'s/`EquipmentForge`'s pattern — a second `Tarot` node hosted inside `SanctuaryUI.tscn`, discovered via the same group lookup, alongside the existing `TarotDeckUI.tscn` instance.
- **Pros**: No Autoload registration change; minimal diff.
- **Cons**: Two never-simultaneously-alive instances with no state handoff between them (confirmed by a live `godot-specialist` review pass during Building Upgrade's design review); does not fix BUG-0001 at all (neither instance is reachable during a mission, and a save taken then still omits Tarot); doubles the register/unregister surface for no benefit.
- **Rejection Reason**: Already investigated and rejected for the requirement-check gap alone (see BUG-0001's Technical Context); does not address BUG-0001's save-persistence gap in any scene, including missions.

### Alternative 2: Special-case Tarot's persistence inside GSavePersistence
- **Description**: Have `GSavePersistence` hold a direct reference to Tarot's save data independent of the `register()`/`unregister()` lifecycle, bypassing the standard `SaveRestorer` interface for this one system.
- **Pros**: Avoids touching Tarot's instantiation model at all.
- **Cons**: Breaks the uniform `SaveRestorer` interface every other system relies on; special-cases one system with no structural justification; does not fix the second gap (no live Tarot instance reachable from Sanctuary UI for requirement checks).
- **Rejection Reason**: Treats a symptom (save omission) without addressing the shared root cause (instantiation lifetime scoped to one screen), leaving the requirement-check gap open.

### Alternative 3: Convert Tarot to an Autoload (chosen)
- **Description**: As described in Decision above.
- **Pros**: Fixes both gaps as a direct structural consequence of one change; zero changes to Tarot's own persistence logic (already Autoload-convention-compliant); matches every other cross-scene-persistent system already in the project; removes the group-lookup indirection at all 3 call sites.
- **Cons**: Tarot's 4 EventBus subscriptions become permanent for the process lifetime instead of scoped to `TarotDeckUI.tscn`'s mount window (see Risks).
- **Rejection Reason**: N/A — chosen.

## Consequences

### Positive
- Fixes BUG-0001 (S1-Critical, silent player-data loss) as a direct structural consequence, not a patch.
- Unblocks Building Upgrade's `"tarot"`-requirement type to evaluate correctly from any Sanctuary UI screen.
- Removes 3 call sites' group-lookup-then-cast indirection in favor of the project's standard direct-Autoload-call convention.
- `building_upgrade.gd`'s Tarot read becomes a genuine ADR-0020 Criterion A instance (previously explicitly flagged as NOT one, per ADR-0034's Risks) — closes that documented gap too.
- **Likely fixes a second, previously-latent bug**: in the current scene-instanced model, `_on_mission_launched()`/`_on_mission_phase_changed()` can only fire while `TarotDeckUI.tscn` happens to be mounted — but that screen is Sanctuary-only, structurally unmounted before any real mission launch transition. Rule 5's deck lock (`_locked` set `true` on `mission_launched`, cleared on mission end) is therefore very likely dead code in the current model, since the listening instance doesn't exist for the duration of a real mission. As an Autoload, the listener survives the whole mission, making the deck-lock lifecycle work for the first time — confirmed by godot-specialist review during this ADR's validation pass (2026-08-12).

### Negative
- Tarot's `_ready()`-time EventBus subscriptions (`mission_launched`, `mission_phase_changed`, `run_modifier_selected`, `scene_transition_completed`) now persist for the full application lifetime rather than being torn down and rebuilt every time `TarotDeckUI.tscn` mounts/unmounts. This is consistent with every other Autoload's subscription lifetime in the project, but is a real behavioral change specific to Tarot worth naming explicitly (see Risks).

### Risks
- **`_locked`, `_active_mission_deck`, `_run_modifier_selected_types` are session-scoped, unpersisted fields.** Previously, every `TarotDeckUI.tscn` mount created a brand-new `Tarot` node with these fields at their class defaults; ADR-0003's 2026-07-18 mid-session-restore revision then immediately rehydrated only the *persisted* ledgers via `restore_save_data()`, leaving these 3 fields freshly defaulted every visit. As an Autoload, these fields now persist for the whole session instead of resetting on each Tarot Deck UI visit.
  - **Mitigation / analysis**: `_locked` is driven entirely by `mission_launched`/`mission_phase_changed`/`scene_transition_completed` signals, independent of whether Tarot Deck UI happens to be open — since Tarot Deck UI is a Sanctuary-only screen (unreachable mid-mission), `_locked` should already be `false` any time the screen is genuinely visitable; the previous per-visit reset was masking, not exercising, any real state machine gap. `_active_mission_deck` is mission-scoped and, by the same Sanctuary-only-screen argument, is never meaningfully read while Tarot Deck UI is open. `_run_modifier_selected_types` (Rule 8's conflict-awareness cache) was previously reset only as a side effect of object destruction, not by any explicit "clear at the right moment" logic — this ADR does not fix or worsen that; it makes the existing lack-of-explicit-clearing persist correctly across visits within one session instead of being silently masked by recreation.
  - **Verification Required** (Engine Compatibility table): live-verify via Godot MCP that opening Tarot Deck UI, closing it, playing a mission, and reopening it produces identical observable behavior to the current scene-instanced model for all 3 fields — including the new mid-mission-lock-then-Sanctuary-return scenario named as a Positive consequence above, which should be tested as a newly-passing case, not just a no-regression check.
- **Test migration**: any existing test relying on `get_tree().get_first_node_in_group(&"tarot")` (integration tests exercising `tarot_screen.gd`/`snapshot_chip.gd`/`building_upgrade.gd`'s real call paths) must be updated to construct/reference `GTarot` instead, or will silently stop finding an instance once the group membership is removed (Migration step 4). Flagged explicitly so this is caught at implementation time, not discovered as a test regression.
- **Equipment Forge likely shares this exact defect class**: `tarot.gd`'s own (pre-this-ADR) doc comment cites `equipment_forge.gd`'s identical `"equipment_forge"` group-membership precedent, added the same day for the same reason. If Equipment Forge's `SaveRestorer` registration is similarly tied to its own screen's scene lifecycle, it likely has the same BUG-0001-shaped save-omission defect. Out of scope for this ADR to fix — flagged here as a real, not hypothetical, follow-up investigation (godot-specialist review, 2026-08-12), not asserted as confirmed.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/tarot.md` | No explicit Rule requires Tarot to be an Autoload — this ADR corrects an implementation-architecture gap (BUG-0001, ADR-0034's flagged requirement-check gap), not a GDD-level rule change. Tarot's own Rules 1-16/Formulas F1-F6 are entirely unaffected. | N/A — architecture correction only |
| `design/gdd/building-upgrade.md` | Open Questions table's Tarot-instance-reachability row (the `"tarot"`-requirement type currently fails closed with no live instance reachable from Sanctuary UI) | Resolved — `GTarot` is reachable from any Sanctuary UI context, including `building_upgrade.gd` |

## Performance Implications
- **CPU**: Negligible — Tarot's `_process`/`_physics_process` are not implemented (no per-frame cost either before or after); its 4 EventBus subscriptions and `SaveRestorer` registration are the same O(1) connect/register calls, just fired once at boot instead of once per Tarot Deck UI visit (net fewer connect/disconnect cycles across a session, if anything).
- **Memory**: One additional permanently-resident `Node` instance (already the case for 13 other Autoloads) instead of a create/destroy cycle per Tarot Deck UI visit — net memory impact is negligible and arguably reduces GC churn from repeated instantiation.
- **Load Time**: No measurable change — Autoloads are instantiated during the same boot sequence Tarot's scene-instanced node was already part of via `TarotDeckUI.tscn`'s own load, just earlier (project boot vs. first Tarot Deck UI visit).
- **Network**: N/A.

## Migration Plan
See Decision → Migration above (6 steps: autoload registration, scene node removal, 3 call-site migrations, `GROUP_NAME` removal, doc comment update, test fixture updates). No data migration is required — the save file's `"tarot"` key shape (`get_save_data()`'s Dictionary) is completely unchanged.

## Validation Criteria
- `tests/unit/tarot/` and `tests/integration/` suites touching Tarot pass with 0 failures after migration.
- A new regression test proves a save taken while `TarotDeckUI.tscn` is NOT mounted (e.g. from Sanctuary overview or mid-mission) still contains Tarot's full persisted state and restores correctly — this is BUG-0001's own reproduction case, inverted into a passing test.
- Live Godot MCP verification (per Engine Compatibility's Verification Required) confirms no behavioral change to `_locked`/`_active_mission_deck`/`_run_modifier_selected_types` across a Tarot Deck UI close → mission → Tarot Deck UI reopen sequence, AND confirms Rule 5's deck lock (`_locked`) genuinely activates on `mission_launched` and survives through a full mission — the newly-working scenario named in Consequences → Positive.
- Full project regression suite passes with 0 new failures.

## Related Decisions
- ADR-0027 (Tarot Modifier Aggregation Pipeline) — F1/ledger-shape decisions unchanged by this ADR.
- ADR-0003 (Save & Persistence) — `SaveRestorer` interface and mid-session-restore-on-register behavior unchanged; this ADR only changes *when* Tarot's `register()`/`unregister()` fire.
- ADR-0020 (Cross-System Direct-Call Criteria) — `building_upgrade.gd`'s Tarot read becomes a Criterion A instance after migration.
- ADR-0034 (Building Upgrade Cross-System Requirements Model) — originally flagged the Tarot-reachability gap this ADR resolves.
- `production/qa/bugs/BUG-0001.md` — the bug this ADR fixes.
