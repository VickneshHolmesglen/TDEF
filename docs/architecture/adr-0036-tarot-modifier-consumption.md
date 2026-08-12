# ADR-0036: Tarot Modifier Consumption (Wave Manager / Monster System)

## Status
Accepted

## Acceptance Note
Accepted 2026-08-12 by explicit user decision, same day as drafting — same precedent as ADR-0027/0034/0035's own same-day acceptances. `godot-specialist` validation pass (2026-08-12) found 3 real, load-bearing issues in the original draft (MonsterManager's "no reset needed" claim was factually wrong given the retry code path; the `tarot_difficulty_growth_rate` REPLACE branch was missing the GDD-mandated `[0.10, 0.25]` clamp; the reset-location pointer named nonexistent code) — all 3 fixed directly in this ADR before acceptance, plus 2 minor snippet-correctness notes incorporated. Review mode `lean` — TD-ADR strategic gate skipped per this session's resolved mode.

## Date
2026-08-12

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (gameplay formula composition, EventBus consumption) |
| **Knowledge Risk** | LOW — pure GDScript arithmetic and existing signal-subscription patterns, no new engine subsystem. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (no relevant tracked risk items); `design/gdd/tarot.md` Formulas F1-F5 and Rule 7/8 tables (Accepted content, ADR-0027); `design/gdd/wave-manager.md` (F1 reward formula, Rule 12); `design/registry/entities.yaml` (`monster_speed_scaling` formula, `tarot_speed_scalar` registered constant) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond standard test coverage |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0027 (Tarot Modifier Aggregation Pipeline — this ADR consumes, does not change, `mission_modifier_applied`'s emission side); ADR-0035 (Tarot Autoload Conversion — `GTarot.compute_rune_bonus()` is called directly as a real Autoload, not through a group lookup) |
| **Enables** | Epic 07 Tarot Story 006's AC-37/38 (currently blocked); Story 002's own previously-flagged AC-15/17 gap |
| **Blocks** | None further downstream |
| **Ordering Note** | None — Wave Manager and Monster System are both already-shipped, already-Autoload/scene-instanced systems; this ADR adds consumption logic to existing `_ready()`/EventBus-handler code, no new lifecycle ordering constraint. |

## Context

### Problem Statement

`design/gdd/tarot.md` (Accepted, ADR-0027) fully specifies 4 registered `modifier_type` values Tarot emits via `mission_modifier_applied` at SCOUT entry, each with a named consuming system and a fully-worked composition formula (F2-F5). Despite this, **the consuming side was never actually built**:

- **Wave Manager** (`src/gameplay/wave_manager.gd`) does not subscribe to `mission_modifier_applied` at all (confirmed by inspection — zero occurrences of the signal name in the file). `tarot_reward_scalar_mult`, `tarot_difficulty_growth_rate`, and `tarot_wave_config_override` all currently have no effect on gameplay.
- **Monster System** (`src/core/monster/monster_manager.gd`) *does* subscribe (`_on_mission_modifier_applied()`, lines 419-421) — but with two real, previously-undiscovered bugs: (1) it checks `modifier_type == &"monster_speed_scalar"`, a string that does not match any registered `modifier_type` — the actual value Tarot emits is `"tarot_speed_scalar_mult"` (`tarot.md` Rule 7's table), so this branch has silently never fired for a real Tarot event; (2) even if the string matched, the handler does a plain last-write-wins assignment (`_tarot_speed_scalar = modifier_value`), not F2's multiplicative aggregate-then-clamp — a second equipped card targeting the same type would silently overwrite the first's contribution instead of stacking.

This ADR specifies the concrete consumption-side implementation for both systems, closing Epic 07 Tarot Story 006's blocked AC-37/38 and fixing Monster System's existing bug as part of the same change.

### Constraints
- Must not modify Tarot's own emission logic (`_resolve_scout_modifiers()`, F1 mastery scaling) — Accepted, ADR-0027 scope.
- Must not modify `mission_modifier_applied`'s signal signature (`modifier_type: String, modifier_value: float, source_card_id: String`) — frozen per ADR-0001's Resource-subclass-or-typed-payload rule and already a Key Interface other systems depend on.
- `tarot_wave_config_override`'s payload has no field capable of encoding a target `WaveConfig` variant identifier — `modifier_value` is a `float`, and `TarotModifierEntry`'s own schema (Rule 2) is `{modifier_type: StringName, base_modifier_value: float}`, with no string/path field anywhere in the chain. This is a genuine, pre-existing data-model gap, not something this ADR is scoped to fix (`TarotModifierEntry`'s schema is Tarot's own, ADR-0027 territory). Per `tarot.md`'s own explicit flag ("Vertical Slice scope-flagged... should not ship until at least one mission has an authored alternate variant"), this ADR implements the mechanism such that **every** `tarot_wave_config_override` event is currently unresolvable by construction and always takes the documented graceful-degradation path (EC-6's exact log format, discard, proceed with original `WaveConfig`) — this is not a shortcut, it is the only behavior the current data model supports, and matches AC-38's own QA Test Case note ("only this negative/fallback path is currently testable").

### Requirements
- `tarot_speed_scalar_mult`: Monster System aggregates via F2 (multiplicative product across all equipped cards targeting this type, clamped `[0.50, 2.00]`), feeding the registered `tarot_speed_scalar` constant used unmodified in `monster_speed_scaling`.
- `tarot_reward_scalar_mult`: Wave Manager aggregates via F2 (multiplicative product, unclamped except a trivial `[0.0, +inf)` floor), then composes into `wave_reward_scalar_final` at F3 for every wave: `clamp(wave_reward_scalar_natural × tarot_reward_multiplier + rune_reward_bonus, 1.00, 4.768)`, where `rune_reward_bonus = GTarot.compute_rune_bonus(&"tarot_reward_scalar_mult")`.
- `tarot_difficulty_growth_rate`: Wave Manager REPLACE — a single equipped card overrides the mission's authored `difficulty_growth_rate` (`r`). Multiple equipped cards targeting this type (a data-error case the Tarot Deck UI should already prevent at equip-time) resolve first-event-wins (equivalent to lowest-deck-slot-index-wins, since `_resolve_scout_modifiers()` emits in `_active_mission_deck` array order, which is deck-slot order by construction), logging the exact format `tarot.md` Rule 8 specifies for the discarded entries.
- `tarot_wave_config_override`: Wave Manager REPLACE — always resolves as an invalid target per the data-model gap above, taking EC-6's documented graceful-degradation path.
- **F4's speed formula composes no rune-bonus term** (its Expression is `clamp(Π(v_i), 0.50, 2.00)` only) — unlike F3's reward formula, which explicitly adds `rune_reward_bonus`. F5's own variable table row loosely lists `rune_reward_bonus / rune_speed_bonus` together, implying symmetry, but no formula in this GDD ever composes a `rune_speed_bonus` term. This ADR implements F4's literal Expression (no rune addition to speed) and flags this as a GDD-level looseness worth a future correction pass — not resolved here, since inventing a rune-speed-bonus composition rule not specified anywhere would be fabricating design, not implementing it.

## Decision

Both consuming systems track a per-mission running aggregate, updated incrementally as `mission_modifier_applied` events arrive (Tarot emits one event per equipped card's modifier entry, synchronously, in a single loop at SCOUT entry — no "aggregation complete" signal exists or is needed, since multiplicative composition is associative and can be folded in per-event).

### Monster System (`monster_manager.gd`)

Replace the existing single-value overwrite with a raw running product, clamped at read/write time:

```gdscript
var _tarot_speed_scalar_raw: float = 1.0  # F2's unclamped Π(v_i)
var _tarot_speed_scalar: float = 1.0      # F4's clamped output, what monster_speed_scaling actually reads

func _on_mission_modifier_applied(modifier_type: String, modifier_value: float, _source: String) -> void:
	if modifier_type == "tarot_speed_scalar_mult":
		_tarot_speed_scalar_raw *= modifier_value
		_tarot_speed_scalar = clamp(_tarot_speed_scalar_raw, 0.50, 2.00)
```

**Reset is required and must be explicit — corrected during godot-specialist validation (2026-08-12), the original draft's "no reset needed" claim was wrong.** `MonsterManager` is a static child of `MissionScene.tscn`'s `GameplayRoot`, instantiated once when the scene loads — it is **not** destroyed and recreated per mission. Critically, `MissionSelect.retry_current_mission()` does not reload the scene at all; it re-emits `mission_launched` on the *same* `MonsterManager` instance. Without an explicit reset, a retried mission with any `tarot_speed_scalar_mult` card equipped would compound its raw product against the stale value from the failed attempt (e.g. `1.69 × 1.69 = 2.856`, clamped to 2.00 from the second attempt onward) instead of restarting from F4's documented "no card → 1.0" baseline. Fix: reset both fields to `1.0` inside `_on_wave_started()`'s existing `wave_number == 1` special case (`monster_manager.gd:377-378`), which already runs on every mission's/retry's first wave and is the correct, already-existing seam for exactly this class of per-mission reset.

### Wave Manager (`wave_manager.gd`)

Three new tracked fields (4 counting the discard-log helper field), reset inside the existing `_reset_all_state()` (called first thing inside `_on_mission_launched()`, confirmed to run on both a fresh launch and a retry via `MissionSelect.retry_current_mission()`'s re-emission of `mission_launched`) — **corrected during godot-specialist validation (2026-08-12)**: the original draft pointed at "wherever `_wave_reward_scalar` is reset," which does not exist as a reset — `_wave_reward_scalar` is freshly *computed* at every `WAVE_ACTIVE` entry, not reset once per mission, and following that pointer literally would send an implementer looking for nonexistent code. `_reset_all_state()` is Wave Manager's real, already-correct per-mission/per-retry reset seam; add the new fields to its existing field list.

Also requires adding `GEventBus.mission_modifier_applied.connect(_on_mission_modifier_applied)` to Wave Manager's existing `_ready()` (alongside its other EventBus subscriptions) and the matching `disconnect()` to `_exit_tree()` — Monster System already has this wiring for its own handler; Wave Manager currently has none and needs it added, not just the handler body itself.

```gdscript
var _tarot_reward_multiplier_raw: float = 1.0   # F2's unclamped Π(v_i) for tarot_reward_scalar_mult
var _tarot_growth_rate_override_applied: bool = false  # first-event-wins guard, REPLACE type
var _winning_growth_rate_source_card_id: String = ""    # for the discard-log message
var _tarot_wave_config_override_applied: bool = false   # same guard, REPLACE type

func _on_mission_modifier_applied(modifier_type: String, modifier_value: float, source_card_id: String) -> void:
	match modifier_type:
		"tarot_reward_scalar_mult":
			_tarot_reward_multiplier_raw *= modifier_value
		"tarot_difficulty_growth_rate":
			if _tarot_growth_rate_override_applied:
				push_warning("WaveManager: Multiple REPLACE-type Tarot modifiers targeting tarot_difficulty_growth_rate — using slot-index-first card '%s', discarding '%s'." % [_winning_growth_rate_source_card_id, source_card_id])
				return
			_tarot_growth_rate_override_applied = true
			_winning_growth_rate_source_card_id = source_card_id
			# tarot.md Rule 7's table requires this REPLACE value clamped to
			# Wave Manager's own validated [0.10, 0.25] range -- the original
			# draft omitted this and godot-specialist validation (2026-08-12)
			# confirmed it is load-bearing, not theoretical: authored cards at
			# high mastery tiers (e.g. Grim Resolve, base 0.25, Tier 4 scalar
			# 1.75 -> 0.4375) would otherwise silently exceed the ceiling with
			# no log and no correction. _validate_difficulty_growth_rate()
			# only push_errors, never clamps, and only runs once at mission
			# launch before this override applies -- clamp explicitly here.
			difficulty_growth_rate = clamp(modifier_value, 0.10, 0.25)
		"tarot_wave_config_override":
			if _tarot_wave_config_override_applied:
				return  # same multi-REPLACE guard
			_tarot_wave_config_override_applied = true
			# Data-model gap (see Constraints): modifier_value carries no
			# resolvable variant identifier. Always takes EC-6's fallback:
			push_warning("WaveManager: tarot_wave_config_override targeting %s has no valid alternate WaveConfig for mission %s — using mission's default WaveConfig." % [source_card_id, _current_mission_id])
		_:
			pass  # not a Wave-Manager-owned type (tarot_speed_scalar_mult is Monster System's)
```

At every `_transition_to(Phase.WAVE_ACTIVE)` (where `_wave_reward_scalar` is currently computed, `wave_manager.gd:281`), replace the existing `_wave_reward_scalar = pow(1.0 + difficulty_growth_rate, float(_wave_index))` with F3's full composition:

```gdscript
var wave_reward_scalar_natural: float = pow(1.0 + difficulty_growth_rate, float(_wave_index))
var rune_reward_bonus: float = GTarot.compute_rune_bonus(&"tarot_reward_scalar_mult")
_wave_reward_scalar = clamp(
	wave_reward_scalar_natural * _tarot_reward_multiplier_raw + rune_reward_bonus,
	1.00, 4.768)
```

`GTarot.compute_rune_bonus()` is read fresh at each wave's computation rather than cached at SCOUT entry — rune discovery only happens at mission-end (`_on_mission_terminal()`), so it structurally cannot change mid-mission; reading fresh avoids a stale-cache class of bug for zero real cost (called ~6-8 times per mission, not per-frame).

### Architecture Diagram

```
Tarot._resolve_scout_modifiers()  [SCOUT entry, one loop over _active_mission_deck]
         │
         │  mission_modifier_applied(modifier_type, modifier_value, source_card_id)
         │  (one event per equipped card's modifier entry — 1 or 2 events per card)
         │
    ┌────┴─────────────────────────────────────┐
    │                                           │
    ▼                                           ▼
MonsterManager                             WaveManager
  "tarot_speed_scalar_mult"                  "tarot_reward_scalar_mult"
    → F2 raw product, clamp [0.50,2.00]        → F2 raw product (unclamped)
    → feeds monster_speed_scaling               → composed into F3 at every
      (per-frame read, no per-frame                WAVE_ACTIVE entry, with
       recompute — clamped value cached)            GTarot.compute_rune_bonus()
                                              "tarot_difficulty_growth_rate"
                                                → REPLACE, first-event-wins
                                              "tarot_wave_config_override"
                                                → REPLACE, always-invalid
                                                  fallback (data-model gap)
```

### Key Interfaces

No new EventBus signals or public methods. `GTarot.compute_rune_bonus(modifier_type: StringName) -> float` (already exists, ADR-0027 Story 005) is called for the first time by an external system (Wave Manager) — a new caller of an existing interface, not a new interface.

## Alternatives Considered

### Alternative 1: A dedicated `TarotModifierAggregator` helper class shared by both systems
- **Description**: Extract the F2 multiplicative-aggregate-with-clamp logic into a small shared RefCounted/Resource helper both systems instantiate and feed events into.
- **Pros**: DRY — the aggregation math (`raw *= value; clamped = clamp(raw, min, max)`) is identical for both consumers.
- **Cons**: The two consumers' aggregates have different clamp ranges, different reset lifecycles (Monster System resets via scene destruction, Wave Manager needs an explicit reset call), and different downstream composition (Monster System's is a terminal value; Wave Manager's feeds into F3's further composition with a rune term) — the shared logic would be ~2 lines of arithmetic wrapped in enough divergent surrounding logic that the abstraction saves little and adds an indirection layer for a reader tracing either system's own formula.
- **Rejection Reason**: Not enough shared surface area to justify a new class; matches this project's own established preference (CLAUDE.md: "Three similar lines is better than a premature abstraction").

### Alternative 2: Cache `compute_rune_bonus()` once at SCOUT entry instead of reading fresh per wave
- **Description**: Wave Manager subscribes to `mission_phase_changed` SCOUT entry and caches `GTarot.compute_rune_bonus(&"tarot_reward_scalar_mult")` once, reusing the cached value for every wave's F3 computation.
- **Pros**: One fewer function call per wave (though `compute_rune_bonus()` is already O(all registered cards), not expensive).
- **Cons**: Introduces a cache-invalidation surface for no real benefit — rune discovery cannot happen mid-mission (confirmed: only `Tarot._on_mission_terminal()`, fired at MISSION_COMPLETE/DEFEAT, ever discovers a rune), so a fresh read is always correct and a cached read is never stale, making the cache pure overhead with zero behavioral upside.
- **Rejection Reason**: Reading fresh is simpler and strictly equivalent; caching would be optimizing a non-problem.

## Consequences

### Positive
- Closes Epic 07 Tarot Story 006's AC-37/38 (currently the only blocked item preventing that epic from being Complete).
- Fixes Monster System's existing `_on_mission_modifier_applied()` bug (wrong modifier_type string, no F2 aggregation) as a byproduct — this was silently broken before this ADR, not newly introduced by it.
- All 4 registered `modifier_type` values from `tarot.md` Rule 7's table become functionally real for the first time — Tarot cards' speed/reward/growth-rate effects actually reach gameplay.

### Negative
- None beyond the inherent complexity of implementing 4 distinct composition rules across 2 systems — this is prescribed entirely by already-Accepted GDD content (ADR-0027), not new design surface this ADR introduces.

### Risks
- **`tarot_wave_config_override` ships as permanently-non-functional-by-design.** Any card authored with this `modifier_type` today will always hit the fallback path, discarding the override every single time, with no way to author working content against it until `TarotModifierEntry`'s schema gains a variant-identifier field — a decision belonging to a future Tarot content/schema ADR, not this one. **Mitigation**: this matches `tarot.md`'s own explicit flag; no card should be authored with this `modifier_type` until that schema gap is separately resolved. If content authoring attempts to use it before then, this ADR's implementation will not silently pretend it works — every attempt logs the documented content-error message.
- **`tarot_difficulty_growth_rate`'s "first-event-wins" tie-break relies on `_resolve_scout_modifiers()`'s emission order matching deck-slot order.** This is currently true by construction (`_active_mission_deck` is populated in `equip_card()`'s append order, iterated in that same order at emission) but is an implicit coupling between Tarot's internal iteration order and Wave Manager's tie-break assumption, not an explicit contract either file states. **Mitigation**: documented here; a future change to Tarot's own iteration order would silently break this tie-break's "lowest slot index" semantics without either file's own tests catching it, since the Tarot Deck UI is expected to prevent the multi-equip case entirely — this only matters for save-data-corruption edge cases, matching the GDD's own framing ("If violated by a save-data error or a future UI bug").

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/tarot.md` | Rule 7's table (4 registered `modifier_type` values, each with a named consuming system); Formulas F2, F3, F4, F5 (aggregation, composition, clamping) | Implements the consuming-side logic for all 4 types across Monster System and Wave Manager, per each formula's literal Expression |
| `design/gdd/wave-manager.md` | Own F1 (`wave_reward_scalar_natural`), extended by `tarot.md`'s F3 | `_wave_reward_scalar`'s computation at every `WAVE_ACTIVE` entry now composes Tarot's reward layer on top of Wave Manager's own natural formula |
| `design/registry/entities.yaml` | `monster_speed_scaling` formula's `tarot_speed_scalar` term (registered constant, default 1.0, range 0.50-2.00) | Monster System now actually computes this constant from real Tarot events instead of leaving it permanently at its class default |

## Performance Implications
- **CPU**: Negligible — one multiplicative accumulate per `mission_modifier_applied` event (fires a handful of times per mission, at SCOUT entry only, never per-frame), one `clamp()` call per wave transition (6-8 times per mission), one `GTarot.compute_rune_bonus()` call per wave transition (O(all registered Tarot cards), single-digit count).
- **Memory**: 3 new float/bool fields on Wave Manager, 2 new float fields on Monster System — negligible.
- **Load Time**: No change.
- **Network**: N/A.

## Migration Plan
No data migration — this is new consumption logic added to existing `_ready()`/EventBus-handler code in both systems, plus a fix to Monster System's existing (already-shipped but non-functional) handler. No save-data shape changes.

## Validation Criteria
- `tests/unit/wave_manager/` gains tests for: `tarot_reward_scalar_mult` F2+F3 composition (single card, 2-card multiplicative stacking, rune bonus addition), `tarot_difficulty_growth_rate` REPLACE (single card overrides `r`; 2-card data-error case logs and discards the second), `tarot_wave_config_override` always-fallback behavior (EC-6's exact log format).
- `tests/unit/monster/` gains tests for: `tarot_speed_scalar_mult` F2+F4 composition (single card, 2-card multiplicative stacking, out-of-range clamp at both boundaries), confirming the corrected `modifier_type` string match, AND a retry-reset regression test proving `_tarot_speed_scalar_raw`/`_tarot_speed_scalar` return to `1.0` on wave 1 of a second attempt rather than compounding against the first attempt's stale value (the real bug found during this ADR's validation pass).
- `tests/unit/wave_manager/` gains a `tarot_difficulty_growth_rate` clamp test proving a mastery-scaled override value outside `[0.10, 0.25]` (e.g. a Tier-4-scaled card producing 0.4375) is clamped, not applied raw.
- Epic 07 Tarot Story 006's AC-37/AC-38 flip from blocked to passing in `tests/unit/tarot/edge-cases_test.gd` (or a cross-system integration test, if the boundary-clamp/invalid-override behavior is more naturally asserted from the consuming system's own test file — a call this ADR leaves to implementation, not prescribed here).
- Full project regression passes with 0 new failures.

## Related Decisions
- ADR-0027 (Tarot Modifier Aggregation Pipeline) — the emission side this ADR consumes.
- ADR-0035 (Tarot Autoload Conversion) — makes `GTarot.compute_rune_bonus()` callable directly from Wave Manager.
- ADR-0012 (Wave Manager FSM Architecture) — the phase-transition structure this ADR's Wave Manager changes hook into.
- `production/epics/epic-07-cross-cutting-flow/story-006-tarot-edge-cases.md` — the story this ADR unblocks.
