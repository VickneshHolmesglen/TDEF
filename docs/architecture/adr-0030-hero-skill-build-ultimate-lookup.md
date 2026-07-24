# ADR-0030: Hero Skill Build Ultimate Lookup-Table Architecture

## Status
Accepted

## Acceptance Note
Accepted 2026-07-18 (Sprint 6, S6-04) by explicit user decision, outside the normal `/architecture-review` gate — same precedent as ADR-0022/0025/0027/0028/0029's Sprint 6 acceptances. Lightweight manual cross-check: all dependency ADRs (0009, 0020, 0021, 0029) confirmed `Accepted`; `restore_order=31` confirmed collision-free against the full authoritative table (10, 11, 20, 21, 22, 24, 30, 32, 34); the shared `SkillDefinitionResource` amendment to ADR-0029 (already Accepted) confirmed consistent. Unblocks Epic 08's Hero Skill Build stories (001–007) — flips them `Blocked` → `Ready`. An independent `/architecture-review` pass in a fresh session is still recommended before Epic 08's next milestone.

## Date
2026-07-17

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Data Structures |
| **Knowledge Risk** | LOW — the Ultimate derivation (Formulas 1–3) is pure arithmetic over a `Dictionary[String, int]`, mathematically proven exhaustive by the GDD itself. No new engine subsystem beyond patterns already verified this session. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; ADR-0029 (Tower Mastery — `SkillDefinitionResource`, the shared skill-definition Resource this ADR extends rather than duplicates); ADR-0028 (Mission Select — direct precedent for the scene-transition-survival reasoning behind this ADR's own Autoload reclassification) |
| **Post-Cutoff APIs Used** | Typed `Dictionary[String, int]`/`Dictionary[String, bool]` (4.4+, already verified working) |
| **Verification Required** | None — the derivation is closed-form and proven exhaustive in the GDD's own Formula 3 (35 raw profiles → 19 Ultimate IDs, `C(7,4)=35` confirmed). Nothing here depends on live profiling, unlike ADR-0029. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Resource Data Model), ADR-0029 (Tower Mastery — this ADR extends its `SkillDefinitionResource` rather than defining a second, overlapping one), ADR-0021 (Inventory API — skill-modifier items flow through Inventory's Equipment tab, Rule 13), ADR-0020 (Direct-Autoload-call exception pattern) |
| **Enables** | `design/gdd/hero-skill-build.md` implementation stories (currently blocked pending this ADR); closes the last ADR from the 2026-07-17 architecture review's original Required ADRs list |
| **Blocks** | None further downstream — Hero System and Mission HUD consume this system's output entirely via already-frozen EventBus events (`active_skill_equipped`, `ultimate_skill_changed`), neither of which this ADR changes |
| **Ordering Note** | **Reclassifies Hero Skill Build as Autoload #13** — the fifth such reclassification this session, but for a *new* reason distinct from all four prior cases: this system must remain alive and correctly-stated across the exact SANCTUARY→MISSION transition instant, not merely survive it. Per the GDD's own States and Transitions, the system is `LOCKED` (not dormant) throughout the entire mission and "still recomputes and holds the currently-resolved Ultimate for Hero System to read" — a freshly-instantiated Hero (a `MissionScene` child, recreated every mission) must receive `active_skill_equipped`/`ultimate_skill_changed` at `mission_launched`, which requires Hero Skill Build to already exist and hold correct state at that exact moment, not be mid-teardown from a just-unloaded `SanctuaryScene`. `restore_order = 32` (already proposed in `save-persistence.md`) is unaffected — independent axis from Autoload boot order, per ADR-0002/ADR-0003's established distinction. |

## Context

### Problem Statement

`design/gdd/hero-skill-build.md` is the most mathematically rigorous GDD in this batch — it proves, not merely asserts, that its 4-slot × 4-category Ultimate derivation collapses 35 raw combinations into exactly 19 fixed Ultimate IDs, directly resolving `game-concept.md`'s named combinatorial-explosion risk. It has no ADR covering the skill catalogue's actual Resource representation or, more importantly, an architectural gap the GDD's own prose points at without resolving: Rule 2's `mastery_source_build_signature` field description explicitly states its purpose is "so a single skill definition Resource can round-trip between both systems' content pipelines without duplication" — but ADR-0029 (Tower Mastery, written earlier this session) already defined `SkillDefinitionResource` with a *different*, non-overlapping field set (`skill_id`, `source_build_signature`, `mastery_threshold_seconds`, `output`) than this GDD's own catalogue table (`skill_id`, `category`, `passive_slot_count`, `mastery_source_build_signature`, `effect_data`). Left unreconciled, an implementer would create two divergent Resource definitions for what both GDDs explicitly intend to be one shared piece of content data.

### Constraints

- Per Rule 2's own stated intent, there must be exactly **one** `SkillDefinitionResource` shared between Tower Mastery and Hero Skill Build — not two Resource subclasses with overlapping-but-different field sets.
- Ultimate derivation (Formulas 1–3) must be implemented exactly as proven — no `NONE`-fallback branch reachable for any valid 4-slot, all-known-skills combination (the GDD's own Formula 3 proof establishes this is unreachable by construction, not merely unlikely).
- Ownership: Hero Skill Build computes the Ultimate; Hero System only applies the resolved `ultimate_id` — never re-derives it (Rule 9). This ADR must not introduce any code path where Hero performs its own derivation.
- Passive-slot changes remain internal to Hero Skill Build — no new EventBus event (Rule 12, resolving `event-bus.md`'s Open Note 4). This ADR must not introduce one.
- `restore_order = 31` (`save-persistence.md`'s authoritative table, not the GDD's own self-proposed 32) — this ADR adopts the corrected value and resolves that table's own flagged open ordering question (see Decision).
- Skill-modifier items flow through Inventory's Equipment tab as `item_type = "skill_modifier"` (Rule 13) — a flagged `inventory.md` gap this ADR does not resolve itself, consistent with how prior ADRs this session have flagged rather than silently assumed similar gaps.

### Requirements

- One shared `SkillDefinitionResource`: `skill_id`, `category` (matches `tower.md`'s Foundation archetype enum), `passive_slot_count` (1–3), `source_build_signature` (Tower Mastery's field, renamed from this GDD's `mastery_source_build_signature` for a single canonical name), `mastery_threshold_seconds` (Tower Mastery's field), `effect_data` (renamed from ADR-0029's `output` — the same concept, this GDD's name is more descriptive and is adopted as canonical).
- Ultimate derivation: pure function over a 4-entry `category_count: Dictionary[String, int]`, producing one of 19 fixed strings or `EMPTY`/`NONE` sentinels (the latter unreachable for valid catalogue data, retained only as a defensive guard per the GDD's own stated rationale).
- Persistence: equippable-skill library mirror (populated via `skill_unlocked` subscription, never independently derived), 4 active slot bindings, per-skill passive slot bindings, `restore_order = 31`.
- Autoload reclassification (see Ordering Note) so the resolved Ultimate and active slot bindings survive the SANCTUARY→MISSION transition intact and are available to a freshly-instantiated Hero at `mission_launched`.

## Decision

**Unify the skill definition Resource**: amend ADR-0029's `SkillDefinitionResource` (still `Proposed`, safe to extend in place) to carry the full field set both systems need: `skill_id: StringName`, `category: String`, `passive_slot_count: int`, `source_build_signature: StringName`, `mastery_threshold_seconds: float`, `effect_data: Resource` (renamed from ADR-0029's `output` — same field, clearer name, since "output" was ambiguous between "what Tower Mastery hands off" and "what the skill does"). Both Tower Mastery and Hero Skill Build read the *same* `GameDataRegistry`-loaded instance per `skill_id` — Tower Mastery reads `source_build_signature`/`mastery_threshold_seconds` for its own unlock logic; Hero Skill Build reads `category`/`passive_slot_count`/`effect_data` for its own slot/Ultimate logic. Neither system owns a second, competing copy.

**Ultimate derivation as a pure function**, implemented exactly per Formulas 1–3, with no persisted intermediate state — `category_count` is computed fresh from the 4 current active slot bindings on every recompute trigger (any active slot change), never cached or incrementally updated:

```
category_profile(active_slots) -> Dictionary[String, int]   # Formula 1
classify_shape(category_profile) -> Shape enum               # Formula 2, exhaustive by construction
derive_ultimate_id(shape, category_profile) -> String         # Formula 3, 19 fixed outputs + EMPTY
```

This three-function pipeline is the entirety of the "Ultimate matrix" — there is no lookup table data structure to author or maintain (contrary to what the ADR's own title might suggest); the 19-entry table in Formula 3 is a *derived, provable enumeration* of what the pure function produces, not data that must be kept in sync with the function. **This is the load-bearing architectural property that makes the risk-mitigation claim durable**: adding a 9th, 10th, or 20th skill to the catalogue never touches this function or requires updating a table, because the function only ever reads `category`, never `skill_id`.

**Persistence**: `_equippable_skills: Dictionary[String, bool]` (mirror of Tower Mastery's unlock state, populated exclusively via the `skill_unlocked` subscription — never independently derived or re-synced from Tower Mastery's own ledger, per Rule 16's explicit "not a second independent source of truth"), `_active_slots: Array[String]` (size 4, `skill_id` or empty per slot), `_passive_slots: Dictionary[String, Array]` (`skill_id -> Array[String]` of installed skill-modifier item IDs). One `SaveRestorer` implementation, `restore_order = 31` (`save-persistence.md`'s authoritative table — restores immediately after Hero's 30, before Equipment Forge's 32 and Tower Mastery's 34). The resolved Ultimate itself is **never persisted as a stored value** — Rule 16 is explicit it is "always recomputed from restored slot assignments," directly avoiding a class of bug where a content patch changes the derivation and a stale stored Ultimate silently drifts from what the current slots would actually produce.

**Resolves `save-persistence.md`'s own flagged open ordering question**: that document explicitly asks whether Hero Skill Build's restore needs Tower Mastery's state already restored, since `systems-index.md`'s dependency map lists Hero Skill Build as depending on Tower Mastery, which would seem to require Tower Mastery (34) to restore *before* Hero Skill Build (31) — the opposite of the assigned order. **Answer: no** — per the `_equippable_skills` mirror design above, Hero Skill Build never reads Tower Mastery's live restored dictionaries at load time; it only restores its *own* independently-persisted mirror, built incrementally over the playthrough via the `skill_unlocked` event subscription (Rule 17). The dependency `systems-index.md` names is a *design-time* dependency (Hero Skill Build's equippable skills originate from Tower Mastery's unlocks) but not a *restore-time* one — the two systems' `SaveRestorer` implementations are fully independent, and 31-before-34 is correct as assigned.

**Autoload reclassification (Autoload #13)**: resolves the scene-transition-survival gap identified in Context. `active_skill_equipped`/`ultimate_skill_changed` are re-emitted at `mission_launched` (subscribing to the same event Mission Select's retry flow re-fires, ADR-0028) so a freshly-instantiated Hero always receives the current build regardless of which scene most recently held Hero Skill Build's UI. This is architecturally identical to Mission Select's own reasoning (ADR-0028) — state that must exist continuously across a scene boundary, not merely be restorable from disk afterward.

### Architecture Diagram

```
GameDataRegistry (Autoload, boot position 5)
  └─ preloads SkillDefinitionResource[] from assets/data/skills/
       (canonical path — corrects ADR-0029's original assets/data/tower_mastery_skills/,
       reconciled by this ADR since both systems load the SAME shared Resource type)
       validate() called per resource at boot (ADR-0009 contract)
       SHARED between Tower Mastery (ADR-0029) and Hero Skill Build — one
       Resource, two consumers, reconciled by this ADR (see Decision)

HeroSkillBuild (Autoload #13 — required so active_skill_equipped/
                ultimate_skill_changed can be correctly emitted at
                mission_launched regardless of scene-transition timing,
                mirroring ADR-0028's MissionRuntimeState reasoning)
  ├─ owns: _equippable_skills: Dictionary[String, bool]      # persisted, mirror only
  ├─ owns: _active_slots: Array[String]                       # persisted, size 4
  ├─ owns: _passive_slots: Dictionary[String, Array]           # persisted, skill_id -> item_ids
  ├─ implements SaveRestorer:
  │    get_save_key() -> "hero_skill_build"
  │    get_save_data() -> Dictionary (primitives only — 3 structures above)
  │    restore_save_data(data) -> bool
  │    reset_to_defaults() -> void
  ├─ registers: SavePersistence.register(self, restore_order=31)
  ├─ reads: GameDataRegistry.get_skill_definition(skill_id) -> SkillDefinitionResource
  ├─ calls (direct, Criterion A/ADR-0020): Inventory (skill-modifier item read/return,
  │    Rule 13, pending inventory.md's own item_type revision)
  ├─ subscribes (EventBus): skill_unlocked, mission_phase_changed, mission_launched,
  │    sanctuary_state_restored
  └─ emits (EventBus): active_skill_equipped, ultimate_skill_changed
       (both re-emitted at mission_launched for the freshly-instantiated Hero)
```

### Key Interfaces

```gdscript
# SkillDefinitionResource (assets/data/skills/*.tres) — AMENDS ADR-0029's
# original definition; "output" renamed "effect_data", 2 fields added
class_name SkillDefinitionResource extends Resource
@export var skill_id: StringName = &""
@export var category: String = ""                 # physical|ranged|elemental|support
@export var passive_slot_count: int = 1            # 1-3
@export var source_build_signature: StringName = &""
@export var mastery_threshold_seconds: float = 45.0
@export var effect_data: Resource = null           # opaque; format owned by this GDD's future content pass
func validate() -> Array[String]: ...

enum Shape { PURE, TRIPLE, DOUBLE_DOUBLE, DOUBLE_SINGLE_SINGLE, ALL_DIFFERENT }

# HeroSkillBuild (Autoload #13, implements SaveRestorer per ADR-0003)
var _equippable_skills: Dictionary[String, bool] = {}
var _active_slots: Array[String] = ["", "", "", ""]
var _passive_slots: Dictionary[String, Array] = {}   # skill_id -> Array[String] item_ids

func _category_profile() -> Dictionary:   # Formula 1
    var counts := {"physical": 0, "ranged": 0, "elemental": 0, "support": 0}
    for skill_id in _active_slots:
        if skill_id.is_empty() or not _equippable_skills.get(skill_id, false):
            return {}   # precondition fails (Rule 7) — caller treats empty dict as EMPTY
        var def: SkillDefinitionResource = GameDataRegistry.get_skill_definition(skill_id)
        counts[def.category] += 1
    return counts

func _derive_ultimate_id() -> String:   # Formulas 1-3 pipeline
    var profile := _category_profile()
    if profile.is_empty():
        return "EMPTY"
    var shape := _classify_shape(profile)   # Formula 2
    return _ultimate_id_for_shape(shape, profile)   # Formula 3

func _on_active_slot_changed() -> void:
    var ultimate_id := _derive_ultimate_id()
    EventBus.ultimate_skill_changed.emit(ultimate_id)

func _on_mission_launched(_mission_id, _modifiers, _tier) -> void:
    # Deferred per ADR-0001 Core Rule 2: this handler is itself an EventBus
    # subscriber emitting further events (a Level-1 cascade) — must defer,
    # not emit synchronously within the mission_launched call stack.
    call_deferred("_push_current_build")

func _push_current_build() -> void:
    for i in 4:
        if not _active_slots[i].is_empty():
            EventBus.active_skill_equipped.emit(i, _active_slots[i])
    EventBus.ultimate_skill_changed.emit(_derive_ultimate_id())
```

## Alternatives Considered

### Alternative A: A separate `HeroSkillDefinitionResource`, distinct from Tower Mastery's `SkillDefinitionResource`

- **Description**: Accept the GDD's literal field table as its own Resource, leaving Tower Mastery's `SkillDefinitionResource` (ADR-0029) untouched.
- **Pros**: No amendment to a sibling ADR needed.
- **Cons**: Directly contradicts Rule 2's own explicit stated intent ("a single skill definition Resource can round-trip between both systems' content pipelines without duplication") — two Resources for the same 8 (at Alpha) skill entries would require content authors to keep two files in sync per skill, with no structural guarantee they don't drift (e.g., a `skill_id` present in one catalogue but not the other).
- **Rejection Reason**: The GDD itself names the unified-Resource requirement; splitting it would be inventing a requirement the source document explicitly argues against.

### Alternative B: Ultimate ID as a stored, persisted value rather than always-recomputed

- **Description**: Persist the currently-resolved `ultimate_id` directly in save data, restoring it as-is rather than recomputing from slot bindings on load.
- **Pros**: Marginally simpler restore logic (no recompute step needed at load time).
- **Cons**: Directly contradicts Rule 16's explicit reasoning — a stored Ultimate could silently drift from what the current slot assignments would actually produce if a content patch changes `category` values or the derivation logic between sessions, producing a HUD/Hero mismatch with no error surfaced.
- **Rejection Reason**: The GDD's own Rule 16 already rules this out with a specific, correct rationale — recomputing is cheap (pure function, no I/O) and eliminates an entire class of stale-cache bug for free.

## Consequences

### Positive
- Resolves the `SkillDefinitionResource` divergence between ADR-0029 and this ADR before it becomes two incompatible content pipelines — caught at the ADR-authoring stage, the same "reconcile sibling ADRs before implementation" discipline this session applied repeatedly (Crafting↔Defense Building's restore ordering, Equipment Forge↔Menagerie's type correction).
- The Ultimate derivation's pure-function architecture means the risk-mitigation property (catalogue growth never grows the Ultimate matrix) is enforced by the code shape itself, not by a discipline of "remember to update the lookup table" that could be violated by a future content pass.
- Closes the last ADR from the 2026-07-17 architecture review's original Required ADRs list — all 11 originally-identified ADRs are now written.

### Negative
- Hero Skill Build is the 13th global Autoload singleton — continues the pattern ADR-0002's Risks section has now flagged as recurring across five systems this session.
- Amending ADR-0029's `SkillDefinitionResource` in place (renaming `output` to `effect_data`, adding 2 fields) means anyone who read ADR-0029 before this revision saw a different field set — flagged here explicitly, same "Last Verified"-style correction pattern used for ADR-0016/ADR-0025.

### Risks
- **Risk** (discovered during `/create-epics` research, fixed in this revision): this ADR originally adopted `hero-skill-build.md`'s own self-proposed `restore_order = 32`, but `save-persistence.md`'s authoritative table assigns Hero Skill Build **31** — the GDD's self-proposed 32 collided with Equipment Forge's already-assigned slot. Sibling ADR-0029 had the identical class of error (Tower Mastery's self-proposed 31 colliding with this system's correct 31), also caught and fixed in the same research pass.
  - **Mitigation**: Fixed — `restore_order` corrected to 31 throughout this ADR, and `save-persistence.md`'s own flagged open ordering question (Hero Skill Build vs. Tower Mastery) is now explicitly resolved in the Decision section rather than left open. Reinforces the same process note ADR-0029 now carries: check `save-persistence.md`'s authoritative table directly, not a consuming GDD's self-proposed ordinal.
- **Risk**: A future implementer working from ADR-0029 alone (without reading this ADR) could implement `SkillDefinitionResource` with only Tower Mastery's original 4 fields, missing the 2 Hero-Skill-Build-specific fields this ADR adds.
  - **Mitigation**: ADR-0029 must be amended with a dated correction note (mirroring ADR-0016/ADR-0025's precedent) pointing to this ADR as the authoritative, complete field list — performed as part of this ADR's write (see below).
- **Risk**: Re-emitting `active_skill_equipped`/`ultimate_skill_changed` at every `mission_launched` (including retries via `retry_current_mission()`, ADR-0028) could be redundant if Hero's own state already reflects the correct build from a prior emission in the same session.
  - **Mitigation**: Re-emission is idempotent by construction (both events just set Hero's slot bindings to the same values they'd already be, if unchanged) — redundant delivery is harmless, and is the safer default against the alternative of Hero silently missing its build after a scene reload. Consistent with EventBus's own ghost-event-tolerant design philosophy (ADR-0001).
- **Risk** (godot-specialist validation, fixed in this revision): the original draft's `_on_mission_launched()` code sample emitted `active_skill_equipped`/`ultimate_skill_changed` synchronously within the `mission_launched` subscriber call stack — a Level-1 cascade per ADR-0001's own classification, which Core Rule 2 requires to be deferred, not emitted inline.
  - **Mitigation**: Fixed — the handler now calls `call_deferred("_push_current_build")`, matching ADR-0001's dispatch policy exactly.
- **Risk** (godot-specialist validation, fixed in this revision): this ADR's Architecture Diagram named `assets/data/skills/` as the `SkillDefinitionResource` source directory while ADR-0029's original diagram named `assets/data/tower_mastery_skills/` — a genuine content-pipeline ambiguity for a Resource type this ADR explicitly unifies across both systems, not just a documentation inconsistency.
  - **Mitigation**: Fixed — `assets/data/skills/` adopted as the single canonical path in both this ADR and a corresponding correction to ADR-0029 (see that ADR's Last Verified section).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| hero-skill-build.md | Rule 2: skill catalogue data model, shared Resource intent | Unified `SkillDefinitionResource`, amending ADR-0029 in place |
| hero-skill-build.md | Group 2/Formulas 1-3: Ultimate derivation, 19-ID proof | Implemented as a 3-function pure pipeline, no persisted lookup table |
| hero-skill-build.md | Rule 9: Hero Skill Build owns derivation, Hero only applies | No code path in this ADR performs derivation outside Hero Skill Build |
| hero-skill-build.md | Rule 16: Ultimate always recomputed, never stored | Confirmed in Decision — `get_save_data()` excludes the resolved Ultimate entirely |
| hero-skill-build.md | States and Transitions: `LOCKED` state holds resolved Ultimate for Hero to read throughout the mission | Resolved via Autoload #13 reclassification — state survives the SANCTUARY→MISSION transition, re-emitted at `mission_launched` |
| hero-skill-build.md | Dependencies: `restore_order = 31` | Corrected from the GDD's self-proposed 32 (collided with Equipment Forge) to `save-persistence.md`'s authoritative value; also resolves that document's flagged open ordering question against Tower Mastery (see Decision) |

## Performance Implications
- **CPU**: Negligible — Ultimate recompute is a pure function over 4 dictionary lookups, triggered only on active-slot changes (Sanctuary-only, gameplay-action-triggered). No per-frame cost.
- **Memory**: Three small persisted structures bounded by catalogue size (8 skills at Alpha) and 4 fixed slots. Negligible.
- **Load Time**: `SkillDefinitionResource` definitions load alongside existing `GameDataRegistry` boot-time preloading (ADR-0009) — no new load-time phase; shared with Tower Mastery's own loading, not duplicated.
- **Network**: N/A — single-player game.

## Migration Plan
N/A — Hero Skill Build has no existing implementation to migrate from. This is a greenfield decision, contingent on the ADR-0029 amendment landing in the same pass.

## Validation Criteria
- Unit test confirms `_derive_ultimate_id()` produces exactly the 19 fixed IDs enumerated in Formula 3's table across all 35 raw category-count profiles, with zero reachable `NONE`/`EMPTY` outcome for any combination of 4 known, valid-category skills — directly implements the GDD's own exhaustiveness proof as an automated test, not just a mathematical assertion.
- Unit test confirms duplicate `skill_id` across multiple active slots produces the same Ultimate as 4 distinct same-category skills would (Formula 3 Worked Example 2).
- Unit test confirms the resolved Ultimate is never present in `get_save_data()`'s returned Dictionary, and is correctly recomputed from restored slot bindings on `restore_save_data()`.
- Integration test confirms `active_skill_equipped`/`ultimate_skill_changed` are both re-emitted at `mission_launched` and received correctly by a freshly-instantiated Hero node, including on a `retry_current_mission()` cycle (ADR-0028).
- Content-validation smoke test confirms every `SkillDefinitionResource` in `assets/data/skills/` has a non-empty `source_build_signature` (per `tower-mastery.md`'s own content-authoring-error precedent for this exact field).

## Related Decisions
- ADR-0009 (Resource Data Model) — `GameDataRegistry` + `validate()` pattern `SkillDefinitionResource` extends
- ADR-0029 (Tower Mastery proximity-detection strategy) — original (now amended) definition of `SkillDefinitionResource`; this ADR reconciles the two systems' field needs into one shared Resource
- ADR-0028 (Mission Select runtime state) — direct precedent for the scene-transition-survival reasoning behind this ADR's own Autoload reclassification
- ADR-0021 (Inventory cross-system query/mutation API) — skill-modifier items flow through Inventory's Equipment tab (Rule 13), pending `inventory.md`'s own flagged revision
- ADR-0020 (Direct-Autoload-call exception pattern) — governs why Hero Skill Build's Inventory calls are direct, not EventBus
- `design/gdd/hero-skill-build.md` — source GDD for all requirements this ADR addresses
