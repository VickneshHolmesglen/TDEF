# Story 008: Hero Lifecycle, Death & Save

> **Epic**: Core Combat Engine
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-05-16
> **Estimate**: 4–5 hours

## Context

**GDD**: `design/gdd/hero.md`
**Requirements**: `TR-hero-001`, `TR-hero-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 (Hero), ADR-0002 (Scene/Autoload Structure), ADR-0003 (Save & Persistence)
**ADR Decision Summary**: Hero state machine transitions are driven by EventBus mission phase changes (ADR-0002). Hero death immediately emits `hero_died` which must trigger DEFEAT in the same frame (ADR-0002 mission phase transition). Hero is a SaveRestorer implementor with `restore_order = 30` — saves and restores: current HP, `_proximity_time`, `_primary_class`, `_class_locked`, and skill slot assignments (ADR-0003).

**Engine**: Godot 4.6.2 | **Risk**: HIGH
**Engine Notes**: Signal emission timing: `hero_died` and `mission_phase_changed(..., "DEFEAT", ...)` must both fire in the same frame — use synchronous emit (non-physics). ADR-0003 `restore_save_data()` is called in restore order sequence during boot — hero restores after Foundation (order 0–9) and before Feature layer systems (order 50+). `await get_tree().process_frame` with `is_instance_valid` guard required in integration tests. **Corrected during dev-story review**: `monster_attack_landed` and `hero_hp_changed` do not exist — the real signals are `hero_damage_taken(amount: int, source_type: int)` and `hero_health_changed(current_health: float, max_health: float)`, neither carries a hero/target ID. The SaveRestorer interface requires `get_save_key() -> String` (missing from this story's original sketch) and `restore_save_data(data: Dictionary) -> bool` (not `-> void`); `restore_order` is passed to `GSavePersistence.register(self, 30)` at call time, not read as a const field. The existing `_on_mission_phase_changed` handler (Story 006) must be extended, not duplicated. See Implementation Notes for the fully corrected sketch.

**Control Manifest Rules (Core layer)**:
- Required: Hero state machine transitions driven by `EventBus.mission_phase_changed` — Hero never reads `WaveManager` directly
- Required: Hero death: `EventBus.hero_died.emit()` → same-frame follow-up: `EventBus.mission_phase_changed.emit(&"DEFEAT")` (synchronous)
- Required: `restore_order = 30` — must be set in Hero's save data header
- Forbidden: Hero modifying WaveManager state directly to trigger DEFEAT
- Guardrail: `get_save_data()` and `restore_save_data()` must complete in < 1ms — serializing only primitive types and StringNames

---

## Acceptance Criteria

*From `design/gdd/hero.md`, scoped to this story:*

- [x] AC-13 (corrected — see Implementation Notes): GIVEN the hero's current HP reaches 0 (or below), WHEN the real `hero_damage_taken(amount, source_type)` event is processed (not `monster_attack_landed`, which does not exist), THEN `hero_died` is emitted and `mission_phase_changed(..., "DEFEAT", ...)` fires in the same frame — no 1-frame delay between death and defeat
- [x] Rule 19 (corrected): Hero state machine transitions: `IDLE_SANCTUARY → SCOUT → COMBAT → INTERMISSION → DEAD`. Each transition is triggered by the corresponding `mission_phase_changed` event. The real win-condition phase string is `"MISSION_COMPLETE"` (WaveManager.Phase) — no `"VICTORY"` phase string exists anywhere in this codebase; both `"DEFEAT"` and `"MISSION_COMPLETE"` transition Hero to DEAD.
- [x] Rule 20: Hero cannot be attacked in IDLE_SANCTUARY or SCOUT phases — damage events targeting the hero are ignored outside of COMBAT and INTERMISSION.
- [x] Save/Restore: `get_save_data()` serializes hero's current HP, `_proximity_time`, `_primary_class`, `_class_locked`, and `_skill_slots`. `restore_save_data()` restores all fields and returns `bool` (true on success, false on malformed data — corrected from the story's original `void` sketch). `reset_to_defaults()` clears all fields to starting values. `restore_order = 30` passed to `GSavePersistence.register(self, 30)` at registration time (not a readable const, as originally sketched).

---

## Implementation Notes

*Derived from ADR-0010, ADR-0002, ADR-0003 Implementation Guidelines:*

```gdscript
# State machine
enum HeroPhase { IDLE_SANCTUARY, SCOUT, COMBAT, INTERMISSION, DEAD }
var _phase: HeroPhase = HeroPhase.IDLE_SANCTUARY

var _current_hp: float = 0.0
var _max_hp: float = 0.0

# Save/Restore (ADR-0003) — restore_order is NOT a readable const on Hero; it is
# passed as a call-site argument to GSavePersistence.register(). See _ready().
const RESTORE_ORDER: int = 30
```

**Corrected during dev-story review — real signal names, args, and interfaces verified against the actual codebase (`src/foundation/event_bus/event_bus.gd`, `src/foundation/save_persistence/save_persistence.gd`):**

1. **No `monster_attack_landed` signal exists anywhere.** The real damage-to-hero signal is `hero_damage_taken(amount: int, source_type: int)` — doc-commented "Deferred one frame from hero_incoming_damage after D4 armor reduction applied... Key subscribers: Hero System, Mission HUD, Audio." It carries no `target_id` (Hero is the implicit sole target — there is exactly one Hero per mission), so the story's original `if target_id != _hero_id: return` guard is unnecessary and `_hero_id` does not need to exist. Subscribe to this signal instead:
   ```gdscript
   func _on_hero_damage_taken(amount: int, _source_type: int) -> void:
       if _phase not in [HeroPhase.COMBAT, HeroPhase.INTERMISSION]:
           return  # Rule 20: ignore damage outside combat phases
       _current_hp = maxf(0.0, _current_hp - float(amount))
       GEventBus.hero_health_changed.emit(_current_hp, _max_hp)
       if _current_hp <= 0.0:
           _phase = HeroPhase.DEAD
           GEventBus.hero_died.emit()                          # synchronous
           GEventBus.mission_phase_changed.emit("DEFEAT", "", 0.0)  # verify exact 3-arg call shape against real signal — see note below
   ```

2. **No `hero_hp_changed` signal exists.** The real HP-change signal is `hero_health_changed(current_health: float, max_health: float)` — no hero_id argument (matches the no-target_id pattern above), and both args are `float`, not `int`.

3. **`mission_phase_changed` handler already exists in `hero.gd`** (added by Story 006, at the method named `_on_mission_phase_changed(_previous_phase: String, new_phase: String, _timestamp: float)`), already connected in `_ready()` and disconnected in `_exit_tree()`, and already matches against plain `String` phase names (`"WAVE_ACTIVE"`, `"INTERMISSION"`, `"SCOUT"`) — NOT `StringName` as this story's original sketch assumed. **Do not declare a second method with the same name** — GDScript does not allow duplicate method names in one script, and Godot signals support only one connection per unique callable anyway. Instead, **extend the existing method's `match` block** to add the Rule 19 `HeroPhase` enum transitions alongside the existing `_proximity_active`/`_class_locked` logic Story 006 put there. Confirm the real signal's exact emission call shape (`mission_phase_changed(previous_phase, new_phase, timestamp)`) before wiring the DEFEAT emission in step 1 above — the story's placeholder `("DEFEAT", "", 0.0)` needs the real previous-phase value substituted, not a blank string.

4. **The SaveRestorer interface is different from this story's original sketch.** Per `save_persistence.gd`'s doc comment, registered systems must implement:
   ```gdscript
   func get_save_key() -> String:
       return "hero"

   func get_save_data() -> Dictionary:
       return {
           "hp": _current_hp,
           "proximity_time": _proximity_time,  # Dictionary[StringName, float] -> needs String-keyed conversion for serialization; verify Godot's store_var() handles StringName keys directly or requires an explicit str() conversion pass
           "primary_class": str(_primary_class),
           "class_locked": _class_locked,
           "skill_slots": _skill_slots.map(func(s: StringName) -> String: return str(s)),
       }

   ## Returns false (not void!) on any malformed/missing data so SavePersistence
   ## falls back to reset_to_defaults() — see save_persistence.gd's
   ## _restore_all_systems().
   func restore_save_data(data: Dictionary) -> bool:
       _current_hp = data.get("hp", _max_hp)
       _proximity_time = data.get("proximity_time", {})
       _primary_class = StringName(data.get("primary_class", ""))
       _class_locked = data.get("class_locked", false)
       var saved_slots: Array = data.get("skill_slots", ["", "", "", ""])
       if saved_slots.size() != 4:
           return false
       for i in range(4):
           _skill_slots[i] = StringName(saved_slots[i])
       return true

   func reset_to_defaults() -> void:
       _current_hp = get_effective_stat(&"max_hp")
       _max_hp = _current_hp
       _proximity_time.clear()
       _primary_class = &""
       _class_locked = false
       _skill_slots = [&"", &"", &"", &""]
   ```
   Registration is NOT a readable `const restore_order` field on Hero — `restore_order` is a call-site argument passed to `GSavePersistence.register(system_ref, restore_order)`. Add to `_ready()`: `GSavePersistence.register(self, RESTORE_ORDER)`, and to `_exit_tree()`: `GSavePersistence.unregister(self)`. See `tests/unit/save_persistence/save_persistence_write_test.gd` and `save_persistence_restore_test.gd` for the established stub-implementor pattern used in this codebase's own tests.

5. **HP initialization**: no HeroResource wiring exists yet (Story 001 left `_base_stats` populated only by tests) — `get_effective_stat(&"max_hp")` will return `0.0` in production until a future story wires a HeroResource. This is a pre-existing gap, not something this story needs to fix; `reset_to_defaults()` and any `_ready()`-time initialization should simply call `get_effective_stat(&"max_hp")` rather than hardcoding a value, so it picks up real data once that wiring lands.

**AC-13 same-frame requirement**: Both `hero_died` and `mission_phase_changed(..., "DEFEAT", ...)` must fire synchronously (no `call_deferred`) from `_on_hero_damage_taken`. This is a non-physics callback (Damage & Status emits `hero_damage_taken` deferred one frame from its own pipeline, but Hero's own reaction to receiving it is synchronous), so synchronous emission is safe per ADR-0001 Rule 2.

**Save data round-trip**: `_proximity_time` keys are StringNames — serialized as String in the Dictionary via `str()`, restored with `StringName(str)` cast. Verify at implementation time whether `Dictionary[StringName, float]`'s keys need an explicit conversion pass before `store_var()`, or whether Godot 4.6.2 serializes StringName keys natively — check `docs/engine-reference/godot/` before assuming either way (post-cutoff risk).

---

## Out of Scope

- **Story 006**: Proximity accumulation logic (the state being persisted — must exist before save is testable)
- **Story 007**: Skill slot assignment logic
- Hero respawn (not in MVP — DEFEAT is game-over in the VS)
- Hero portrait / death animation — Visual/Feel story, art bible dependency

---

## QA Test Cases

- **AC-13**: Death triggers DEFEAT same frame
  - Given: Hero in COMBAT phase with `_current_hp = 10.0`; `GEventBus.hero_damage_taken.emit(15, 0)` fires (real signal — no target_id, since Hero is the implicit sole target)
  - When: The event fires
  - Then: `hero_died` emitted; `mission_phase_changed(..., "DEFEAT", ...)` emitted; both happen before the frame yields — verified by signal spy connected before event fires
  - Edge cases: `amount = 10` exactly → HP = 0.0 → still triggers death (`<= 0.0` check); `amount = 9` → HP = 1.0 → no death

- **Rule 20**: Damage immunity outside COMBAT/INTERMISSION
  - Given: Hero in SCOUT phase; `GEventBus.hero_damage_taken.emit(...)` fires
  - When: The event fires
  - Then: `_current_hp` unchanged; no `hero_health_changed` emitted; no `hero_died` emitted

- **Save/Restore round-trip**:
  - Given: Hero with `_current_hp = 75.0`, `_proximity_time = {&"FROST": 22.5}`, `_primary_class = &""`, `_skill_slots = [&"FIREBALL", &"", &"", &""]`
  - When: `get_save_data()` is called, then `reset_to_defaults()` is called, then `restore_save_data(saved)` is called
  - Then: All fields match original values — `_current_hp = 75.0`, `_proximity_time[&"FROST"] = 22.5`, `_skill_slots[0] = &"FIREBALL"`
  - Edge cases: Empty `_proximity_time` → restores as empty Dictionary; `_class_locked = true` → restores correctly

- **State machine transitions** (Rule 19, corrected — real 3-arg String signature, not 1-arg StringName):
  - Given: Hero starts in IDLE_SANCTUARY
  - When: `GEventBus.mission_phase_changed.emit("SANCTUARY", "SCOUT", 0.0)` fires
  - Then: `_phase = HeroPhase.SCOUT`
  - Then: `mission_phase_changed("SCOUT", "WAVE_ACTIVE", ...)` fires → `_phase = HeroPhase.COMBAT`
  - Then: `mission_phase_changed("WAVE_ACTIVE", "INTERMISSION", ...)` fires → `_phase = HeroPhase.INTERMISSION`
  - Then: `mission_phase_changed(..., "DEFEAT", ...)` or `mission_phase_changed(..., "MISSION_COMPLETE", ...)` fires → `_phase = HeroPhase.DEAD`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/hero/hero_lifecycle_test.gd` — must exist and pass
**Status**: [x] `tests/integration/hero/hero_lifecycle_test.gd` — 25/25 passing (verified via headless gdUnit4 run)

---

## Dependencies

- Depends on: Story 001 (stat system), Story 003 (auto-attack event), Story 006 (proximity state being persisted), Story 007 (skill slot state)
- Unlocks: Nothing further — this is the integration capstone for the Hero system

---

## Completion Notes
**Completed**: 2026-07-04
**Criteria**: 4/4 passing (AC-13, Rule 19, Rule 20, Save/Restore)
**Deviations**: Advisory only — (1) 5 real gaps corrected before implementation (wrong signal names `monster_attack_landed`/`hero_hp_changed` — real signals are `hero_damage_taken`/`hero_health_changed`, neither carries a hero/target ID; the existing Story-006 `_on_mission_phase_changed` handler was extended rather than duplicated; the SaveRestorer interface required `get_save_key()` and `restore_save_data() -> bool`, both missing/wrong in the original sketch; the real win-condition phase string is `"MISSION_COMPLETE"`, not `"VICTORY"`); (2) a BLOCKING gap (missing type-check on `primary_class` in `restore_save_data()`, risking malformed-save-data corruption) was found in code review and fixed + re-approved within this session; (3) TD-hero-004 logged below (no registry yet preventing `restore_order` collisions as more SaveRestorer implementors are added — Hero is currently the only one); (4) the merged `_on_mission_phase_changed()` method now carries two concerns (Story 006 proximity gating + this story's phase FSM) — flagged as the natural next split point, not blocking today
**Test Evidence**: Integration — `tests/integration/hero/hero_lifecycle_test.gd`, 25/25 passing; full suite 446/446, 0 errors/failures
**Code Review**: Complete — APPROVED (godot-gdscript-specialist, godot-specialist, qa-tester all confirmed the `primary_class` type-check fix and its regression test; 2 non-blocking suggestions, no outstanding required changes)
