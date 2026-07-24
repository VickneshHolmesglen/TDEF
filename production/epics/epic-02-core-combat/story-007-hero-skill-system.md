# Story 007: Hero Skill System

> **Epic**: Core Combat Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-05-16
> **Estimate**: 3–4 hours

## Context

**GDD**: `design/gdd/hero.md`
**Requirement**: `TR-hero-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010: Hero Tower-Synced Class + Tower Affinity (indirect — no dedicated ADR for skill system)
**ADR Decision Summary**: No dedicated ADR exists for the Hero Skill System. Implement directly from the GDD rules. The skill system is self-contained within the Hero System — no cross-system dependencies except CDR stat (Formula 1) and the Ultimate recompute trigger on slot change.

**Engine**: Godot 4.6.2 | **Risk**: MEDIUM
**Engine Notes**: Skill cooldown uses `Time.get_ticks_msec()` or a per-skill Timer node. Timer node approach (4 Timers for slots A/B/C/D + 1 for Ultimate) is cleaner for GUT testing. `Array[StringName]` typed arrays confirmed available in GDScript 4.x. Dictionary lookup for Ultimate combo resolution is straightforward. **Corrected during dev-story review**: the real EventBus signals for this story are `active_skill_equipped(slot_index: int, skill_id: String)` (Hero subscribes — not a public `assign_skill()` method), `ultimate_skill_changed(ultimate_id: String)` (not `hero_ultimate_changed`), and `hero_skill_activated(skill_id: String, target_position: Vector2)` (not `hero_skill_used`) — all already exist in `event_bus.gd`, no new signal needed this time. No `SkillDatabase` resource exists anywhere in the codebase; cooldowns and the Ultimate lookup use hardcoded const Dictionaries for MVP (see Implementation Notes).

**Control Manifest Rules (Core layer)**:
- Required: Skill slot assignments stored as `_skill_slots: Array[StringName]` (4 entries) — skills identified by StringName ID, not resource instances
- Required: CDR formula applied to each skill's cooldown independently at activation time — not cached
- Forbidden: Skill system calling D&S directly — skill effects are emitted via EventBus events (hero_skill_used or equivalent)
- Guardrail: Ultimate lookup table is a Dictionary (combo → ultimate_id) — O(1), no iteration

---

## Acceptance Criteria

*From `design/gdd/hero.md`, scoped to this story:*

- [ ] Rule 8: Hero has 4 active skill slots (A, B, C, D). Each slot holds a skill identified by a StringName ID. Passive skill pool is separate — not part of this story.
- [ ] Rule 9: An Ultimate slot (U) holds the hero's combined ultimate skill, derived from the combination of the 4 active slots via a lookup table.
- [ ] Rule 10: Swapping a skill into any slot A–D causes the Ultimate slot to immediately recompute.
- [ ] Rule 12: CDR reduces active skill cooldowns. `effective_cooldown = base_cooldown × (1 - cdr_fraction)`, minimum 0.5 seconds. CDR does NOT affect auto-attack rate (covered in Story 003).
- [ ] AC-12: GIVEN the hero has skills [FIREBALL, FROST_NOVA, CHAIN_LIGHTNING, EARTH_SLAM] in slots A–D, WHEN EARTH_SLAM is swapped for SHIELD_BASH, THEN the Ultimate recomputes to the ID matching the new [FIREBALL, FROST_NOVA, CHAIN_LIGHTNING, SHIELD_BASH] combination.

---

## Implementation Notes

*Derived from hero.md Rules 8–12 and AC-12:*

```gdscript
# 4 active skill slots
var _skill_slots: Array[StringName] = [&"", &"", &"", &""]

# Ultimate derived from slot combo
var _ultimate_id: StringName = &""

# Skill data: hardcoded MVP fields, not const (see note below for why), and not
# populated from any SkillDatabase — no such resource pipeline exists anywhere
# in the codebase yet; GameDataRegistry only handles MonsterResource +
# TowerPerkRegistry. Building a full data-driven skill resource pipeline is out
# of this story's scope, consistent with skill effect authoring and passive
# pools already being Out of Scope below. Ship empty for MVP; a future story
# may migrate these into a data-driven SkillResource (GameDataRegistry
# pattern, ADR-0009) once real skills are authored.
#
# Engine quirk (found via real test execution, Godot 4.6.2): declaring these
# as two back-to-back `const Dictionary[K, V] = {}` fields and then assigning
# (even via .duplicate()) into a differently-typed var reliably threw
# "Trying to assign a dictionary of type Dictionary[StringName, float] to a
# variable of type Dictionary[String, StringName]" — regardless of which
# field held which type. Declaring the fields directly as `var` with their own
# fresh empty literal (no const indirection) avoids it.
var _skill_cooldowns: Dictionary[StringName, float] = {}
var _ultimate_lookup: Dictionary[String, StringName] = {}

## Real signal (verified against src/foundation/event_bus/event_bus.gd):
##   active_skill_equipped(slot_index: int, skill_id: String)
## Doc comment: "Player assigns a skill to an active slot at Sanctuary. Key
## subscribers: Hero System, Mission HUD." — Hero SUBSCRIBES to this signal
## (emitted by a future Sanctuary/loadout screen); it does not expose a public
## assign_skill() method as this sketch originally showed. Corrected during
## dev-story review — the handler below is private, not a public API.
func _ready() -> void:
    GEventBus.active_skill_equipped.connect(_on_active_skill_equipped)

func _on_active_skill_equipped(slot_index: int, skill_id: String) -> void:
    assert(slot_index >= 0 and slot_index < 4, "Slot index must be 0-3")
    _skill_slots[slot_index] = StringName(skill_id)
    _recompute_ultimate()  # AC-12: immediate recompute

func _recompute_ultimate() -> void:
    # Engine quirk (found via real test execution, Godot 4.6.2): sorting
    # Array[StringName] directly via .sort() does NOT reliably produce lexical
    # (alphabetical) ordering — combos that happen to already be
    # near-alphabetical can pass while others silently produce the wrong key.
    # Fix: convert to String FIRST, sort the PackedStringArray (String's < is
    # lexicographic), THEN join — never sort the StringName array itself.
    var combo_strings: PackedStringArray = PackedStringArray()
    for slot_id: StringName in _skill_slots:
        combo_strings.append(String(slot_id))
    combo_strings.sort()
    var key: String = ",".join(combo_strings)
    _ultimate_id = _ultimate_lookup.get(key, &"")
    # Real signal: ultimate_skill_changed(ultimate_id: String) — not
    # "hero_ultimate_changed" (that signal does not exist). Not a physics
    # caller, so no call_deferred needed (ADR-0001 Rule 2 only requires
    # deferral from _physics_process).
    GEventBus.ultimate_skill_changed.emit(String(_ultimate_id))

func activate_skill(slot_index: int) -> void:
    # Check cooldown, apply CDR, emit hero_skill_activated event
    var skill_id: StringName = _skill_slots[slot_index]
    if skill_id == &"":
        return
    var base_cooldown: float = _skill_cooldowns.get(skill_id, 0.0)
    var cdr: float = get_effective_stat(&"cdr")  # capped at 0.75 by Formula 1
    var effective_cooldown: float = maxf(0.5, base_cooldown * (1.0 - cdr))
    _start_cooldown_timer(slot_index, effective_cooldown)
    # Real signal: hero_skill_activated(skill_id: String, target_position: Vector2)
    # — not "hero_skill_used" (that signal does not exist).
    GEventBus.hero_skill_activated.emit(String(skill_id), global_position)
```

**Ultimate lookup population (corrected)**: No `SkillDatabase` resource exists in this codebase. `_skill_cooldowns` and `_ultimate_lookup` are hardcoded fields shipping empty for MVP, matching this story's own stated fallback and the existing pattern of other hardcoded tuning knobs in `hero.gd`. A future story may migrate these into a data-driven `SkillResource` pipeline (extending `GameDataRegistry`, per ADR-0009's pattern) once real skills are authored — tracked as tech debt, not blocking this story. A test-only `_inject_skill_data()` seam (mirroring `GameDataRegistry._inject()`) overrides them for unit testing.

**CDR cap**: `cdr` is capped at 0.75 (75%) by `get_effective_stat` (Story 001 per-stat cap). At 75% CDR, a 2.0s cooldown becomes `2.0 × 0.25 = 0.5s` — exactly the minimum. The `maxf(0.5, ...)` floor guard is a safety redundant check.

**Slot indices**: A=0, B=1, C=2, D=3. Input actions `skill_a`, `skill_b`, `skill_c`, `skill_d` map to these indices. Ultimate is activated by `skill_ultimate`.

---

## Out of Scope

- **Story 001**: CDR stat resolution (Formula 1 — covered there)
- **Story 006**: Class designation that feeds Ultimate (advanced class → unlocks advanced ultimate pool)
- Skill effect implementation — skill effects are downstream, handled when individual skills are authored
- Passive skill pool management — deferred to a future Polish story

---

## QA Test Cases

- **Rule 10 / AC-12**: Ultimate recompute on slot change
  - Given: Slots set to `[&"FIREBALL", &"FROST_NOVA", &"CHAIN_LIGHTNING", &"EARTH_SLAM"]`; lookup table entry for this combo = `&"QUAD_ELEMENTAL"`
  - When: `GEventBus.active_skill_equipped.emit(3, "SHIELD_BASH")` fires (Hero subscribes; no public `assign_skill()` method)
  - Then: `_ultimate_id` recomputes immediately to the ID matching `[FIREBALL, FROST_NOVA, CHAIN_LIGHTNING, SHIELD_BASH]` (or `&""` if no entry — valid for MVP with sparse lookup)
  - Edge cases: Swap to empty skill (`&""`) → combo with empty entry likely returns `&""` ultimate; all 4 slots empty → `_ultimate_id = &""`

- **Rule 12**: CDR formula
  - Given: Skill with `base_cooldown = 2.0`; Hero `cdr = 0.40`
  - When: `activate_skill(0)` fires
  - Then: Timer starts at `2.0 × (1.0 - 0.40) = 1.2s`
  - Edge cases: `cdr = 0.75` (max) → timer = `maxf(0.5, 2.0 × 0.25) = 0.5s`; `cdr = 0.0` → timer = `2.0s`

- **Rule 8**: 4 slot independence
  - Given: All 4 slots assigned distinct skill IDs
  - When: Each slot's `activate_skill()` is called independently
  - Then: Each has its own independent cooldown — activating slot A does not affect slot B's cooldown timer
  - Edge cases: Activating an empty slot (`&""`) → no event emitted, no timer started

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/hero/hero_skill_system_test.gd` — must exist and pass
**Status**: [x] `tests/unit/hero/hero_skill_system_test.gd` — 15/15 passing (verified via headless gdUnit4 run)

---

## Dependencies

- Depends on: Story 001 (CDR stat must be computable before effective_cooldown can be tested)
- Unlocks: Story 008 (skill slot state is part of the save/load round-trip)

---

## Completion Notes
**Completed**: 2026-07-04
**Criteria**: 5/5 passing (Rule 8, Rule 9, Rule 10, Rule 12, AC-12)
**Deviations**: Advisory only — (1) signal-flow direction corrected to real EventBus contract (Hero subscribes to `active_skill_equipped`, no public `assign_skill()`); (2) no SkillDatabase pipeline exists — hardcoded MVP fields used, per the story's own stated fallback (TD-hero-002 logged below); (3) two Godot 4.6.2 engine quirks found via real test execution and fixed (Dictionary type cross-wiring on back-to-back empty typed consts; `Array[StringName].sort()` non-lexical ordering); (4) a BLOCKING cooldown-reactivation guard gap was found in code review and fixed + re-approved within this session; (5) `hero_skill_cooldown_updated`/`hero_ultimate_activated` signals remain unwired — reasonable deferral, not required by this story's ACs (TD-hero-003 logged below)
**Test Evidence**: Logic — `tests/unit/hero/hero_skill_system_test.gd`, 15/15 passing; full suite 421/421, 0 errors/failures
**Code Review**: Complete — APPROVED (godot-gdscript-specialist, godot-specialist, qa-tester all confirmed the cooldown-guard fix and its regression test; 2 non-blocking suggestions, no outstanding required changes)
