# Save & Persistence System

> **Status**: Needs Revision (pending re-review — 2 blocking items fixed 2026-07-15. **2026-07-17 (`/design-review --depth lean` re-review)**: those 2 fixes confirmed intact. New blockers found and fixed this pass: Constellation and Tower Mastery were undeclared dependents despite both declaring the relationship in their own GDDs — added to the `restore_order` table (24 and 34 respectively) and the Downstream Dependents table; Tower Mastery's self-proposed `restore_order=31` (which collided with Hero Skill Build's already-assigned 31) corrected to 34; Encyclopedia renumbered 33→35 to make room while preserving "restores last"; the "10 systems" figure corrected to 12 everywhere it's asserted (Rule 3, AC-2, the register() table, OQ). One ordering question flagged but not resolved: whether Hero Skill Build's restore needs Tower Mastery's state already restored — see the restore_order table's note.) **2026-08-24 (`/design-review --depth lean` re-review, part of S8-07)**: the "12 systems" figure itself had drifted stale again — Crafting (25), Building Upgrade (33), and Tower Assembly (36) had all been added to Formula 4's `restore_order` table on separate later dates (2026-07-18, 2026-08-11, 2026-08-11) but never added to the Downstream Dependents table or the count assertions in Rule 2/AC-2/AC-10/Overview, all corrected 12→15 this pass. Also found and documented 3 real, shipped interface surfaces this GDD had never mentioned at all: `get_save_key()` (called by `register()` internally), `unregister()` (for scene-instanced dependents like Tower Assembly), and late-registration's immediate individual-restore behavior. No new blockers found beyond the count/table drift and the undocumented interface surface — OQ-1 (serialization format ADR) remains the one real gate before implementation.
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-08-24
> **Implements Pillar**: The Sanctuary is Yours (persistent meta-progression)
> **Revision (2026-07-15)**: `/review-all-gdds` flagged two blocking cross-doc issues. (1) **DEFEAT-save ordering** — the DEFEAT-triggered post-mission save had no guaranteed ordering relative to Tower's `tower_destroyed`→`tower_component_returned`→Inventory's `item_added` cascade, which can resolve in the same physics frame (both are independently triggered — DEFEAT by `hero_died`, the cascade by a tower reaching 0 HP — and nothing prevents a boss from causing both in one frame). Fixed via new Rule 9: the DEFEAT save defers exactly 1 frame before reading any system's state, mirroring this GDD's own existing `sanctuary_state_restored` deferral pattern. New EC-11 and AC-13 added. (2) **DEFEAT-transition model conflict** — Rule 9 (now Rule 10), the States/Transitions table, AC-12, and two other spots all said DEFEAT triggers a full load/restore "returning to Sanctuary," contradicting `game-concept.md`'s own state table where DEFEAT transitions directly to SCOUT (mission restart), never through SANCTUARY. Fixed: the load/restore sequence (Rule 10) now correctly triggers on game start only — DEFEAT triggers a durability *save*, never a *load*, since nothing is ever unloaded from memory mid-session. Also fixed a stale "OUTCOME" phase reference (Rule 8, the Interactions table) — no such phase exists in the mission FSM; a 2026-05-15 cross-review had claimed this exact issue was already fixed, but it had not been.

## Engine Risk Notes (Godot 4.6.2)

| API | Used for | Risk | Status |
|-----|---------|------|--------|
| `FileAccess.open()` | Sole disk I/O owner (AC-1) | MEDIUM (FileAccess return-type/behavior changes flagged in Godot 4.4 per `docs/engine-reference/godot/VERSION.md`) | **Verification Required** — not yet re-tested against the real 4.6.2 engine's specific FileAccess semantics. Recommend a targeted smoke test before the next Save & Persistence code change. |

## Overview

The Save & Persistence System is the serialization layer that converts the game's persistent state to and from durable storage. It is the only system permitted to read from and write to disk. All 15 systems that carry state between sessions (Hero, Tower, Inventory, Menagerie, Defense Building, Tarot, Mission Select, Hero Skill Build, Equipment Forge, Encyclopedia, Constellation, Crafting, Tower Mastery, Building Upgrade, Tower Assembly) provide their serializable data to the Save & Persistence System on demand; none of them handle disk I/O directly. The system manages save slots, controls when saves occur (at Sanctuary entry, on mission launch as a pre-mission checkpoint, and on explicit player request), and reconstructs game state on load by distributing saved data back to the owning systems via the `sanctuary_state_restored` event. The core contract this system upholds is Core Rule 11: **Sanctuary progress is always persistent** — a mission defeat triggers a save of the Sanctuary's current state before restarting from Scout Phase, ensuring the player returns to an intact Sanctuary regardless of outcome. The system does not interpret or validate the data it stores; each owning system is responsible for providing correct data and consuming it correctly on restore.

## Player Fantasy

The Save & Persistence System has no player fantasy of its own — it is pure infrastructure. Players experience it as a promise: *the Sanctuary always survives*. The emotional weight of defeat is strictly about the mission; the Sanctuary, the player's choices, their crafted gear, and their unlocked technology are never at risk. This promise — implicit, never stated on-screen — is what allows players to experiment boldly during missions. They can attempt aggressive strategies knowing the cost of failure is only a mission restart, not the loss of their entire progression investment. The Save & Persistence System is the mechanism that keeps this promise. Players never see it; they trust it.

## Detailed Design

### Core Rules

1. Save & Persistence is the second Autoload after EventBus. It is the **exclusive disk I/O system** — no other system may read from or write to disk. All file access routes through this system.

2. Each of the 15 dependent systems must implement three interface functions:
   - `get_save_data() -> Dictionary` — returns the system's current serializable state
   - `restore_save_data(data: Dictionary) -> void` — applies saved state to the system
   - `reset_to_defaults() -> void` — returns the system to its initial new-game state (used on restore failure)
   - `get_save_key() -> String` — a stable identifier used internally by `register()` for bookkeeping. **Added 2026-08-24 (`/design-review` re-review)**: confirmed via the shipped implementation (`save_persistence.gd::register()` calls `system_ref.get_save_key()`) — this was real, load-bearing interface surface never documented in this GDD at all until now.

3. Each dependent system calls `SavePersistence.register(system_ref: Object, restore_order: int)` during its `_ready()`, and `SavePersistence.unregister(system_ref: Object)` during its `_exit_tree()` if the system is scene-instanced (mission-scoped systems — Tower Assembly, and any future scene-instanced dependent — must unregister on teardown so a freed instance is never retained in the registered list). Save & Persistence maintains the registered list sorted by `restore_order` (ascending). Systems with lower `restore_order` values are restored first. Foundation-layer dependencies must be restored before systems that depend on them. Any system that implements the interface but never calls `register()` will have its data silently absent from saves — this is detected at startup via an assertion check against the expected system count. **Late registration** (a system calling `register()` after the initial load sequence has already completed — confirmed in the shipped implementation, `if _has_loaded_data: _restore_one(system_ref)`) triggers an immediate individual restore for that one system, not a wait for the next full load — relevant for any scene-instanced dependent (e.g. Tower Assembly) that registers well after game start. **Added 2026-08-24 (`/design-review` re-review)**: `unregister()` and the late-registration restore behavior were both real, shipped, and completely undocumented in this GDD until now.

4. **Save triggers and file behavior:**

   | Trigger | Event / Action | Writes To | Emits `game_saved` |
   |---|---|---|---|
   | Post-mission (MISSION_COMPLETE or DEFEAT) | `mission_phase_changed` with `new_phase` ∈ {MISSION_COMPLETE, DEFEAT} | `save_slot_N.dat` | Yes — after write |
   | Pre-mission checkpoint | `mission_launched` subscribed event | `save_slot_N_checkpoint.dat` | No |
   | Manual save (Save & Quit) | Player UI action | `save_slot_N.dat` | Yes — after write |
   | Autosave | Internal 5-minute timer | `save_slot_N.dat` | Yes — after write |

5. **Checkpoint lifecycle**: The pre-mission checkpoint (`save_slot_N_checkpoint.dat`) captures full Sanctuary state + `last_launched_mission_id` + `last_launched_modifiers` before the mission starts. It is a crash-recovery artifact only — if the game crashes mid-mission, this file allows the player to restore to their last known good state on next startup. In the normal flow: when any post-mission save fires to `save_slot_N.dat`, the checkpoint file for that slot is deleted immediately after the write completes. The main slot is always the authoritative save; the checkpoint file is advisory.

6. **Atomic write strategy**: All writes use a write-then-rename approach:
   - Write to `save_slot_N.tmp` (or `save_slot_N_checkpoint.tmp`)
   - On successful write: rename to the final filename; previous file is atomically replaced
   - On write failure: discard `.tmp`, log the error, leave the previous file intact
   - On startup: any `.tmp` files that exist are detected and discarded (incomplete write from a previous crash)

7. **Save file versioning**: Every save file includes a `format_version: int` field at the root. On load, if the file's `format_version` is older than the current version, a migration function is applied before data is distributed to systems. If `format_version` is newer than the current version (downgrade scenario), the load is aborted and the player is shown an error indicating the save requires a newer game version.

8. **Autosave behavior**: The autosave timer runs only during the SANCTUARY state. It does not fire during SCOUT, WAVE_ACTIVE, INTERMISSION, MISSION_COMPLETE, or DEFEAT. *(Corrected 2026-07-15: this row previously named a phase called "OUTCOME," which does not exist in the mission FSM — the authoritative phase list, per `game-concept.md`'s States and Transitions table and `wave-manager.md`'s own emitted transitions, is MISSION_COMPLETE and DEFEAT as two distinct terminal phases. "Outcome" is informal shorthand used in some prose docs for "the mission-end phases collectively," never a real `mission_phase_changed` value — this rule was the only place in this GDD that had drifted into treating it as one.)* Timer interval: 5 minutes. Autosave uses the same atomic write path as manual saves, overwriting `save_slot_N.dat`.

9. **DEFEAT-save ordering guarantee**: The post-mission save triggered by `mission_phase_changed(new_phase == DEFEAT)` (Rule 4) does not write immediately on receiving the event. It defers exactly one frame (`call_deferred`, same pattern as Rule 10's `sanctuary_state_restored` deferral below) before calling `get_save_data()` on any registered system. **Reason**: `DEFEAT` is triggered by Wave Manager on `hero_died` (`wave-manager.md` Rule 14) and is completely independent of any tower destruction that may be resolving in the same physics frame — a boss can kill the hero and destroy a tower in the same frame's damage pass. Tower's `tower_destroyed` → `tower_component_returned` → Inventory's `item_added` (with `damaged: true`) cascade (`tower.md` Rule 24, `inventory.md`'s Tower System dependency row) has no guaranteed ordering relative to `mission_phase_changed(DEFEAT)` within the same frame — Godot does not guarantee cross-Autoload signal-handler execution order. Without this deferral, a same-frame tower destruction could lose its component-return write if the DEFEAT save's `Inventory.get_save_data()` call executes first. The one-frame defer guarantees any same-frame EventBus cascade has fully resolved (all synchronous handlers for that frame's events have run) before Save & Persistence reads state from any system. This mirrors the existing `sanctuary_state_restored` deferral pattern (Rule 10 below) and the EventBus GDD's own established synchronous-cascade-then-defer convention (event-bus.md Core Rule 5).

10. **Load and restore sequence**: On game start only:
    1. Read `save_slot_N.dat` from disk
    2. Apply migration if `format_version` is outdated
    3. Iterate registered systems in `restore_order` (ascending)
    4. Call `restore_save_data(data)` on each system
    5. On any restore error: log with system name, call `reset_to_defaults()` on that system, continue to the next system
    6. After all systems processed: emit `sanctuary_state_restored` (save_slot: int) — **deferred by exactly 1 frame** so all `_ready()` signal connections are established before the event fires

    *(Corrected 2026-07-15: this rule previously read "On game start or on DEFEAT returning to Sanctuary," implying DEFEAT triggers a full disk read/restore. That contradicted `game-concept.md`'s own States and Transitions table, where DEFEAT transitions directly to SCOUT — the mission restarts, it does not route through SANCTUARY. This GDD's own Overview already correctly describes the DEFEAT flow as "a save of the Sanctuary's current state before restarting from Scout Phase" — a durability write, not a load. Nothing is ever unloaded from memory on DEFEAT, so there is nothing to restore: Rule 9's save write exists purely so that if the game crashes or quits before the player next reaches SANCTUARY, the DEFEAT-time state isn't lost. The restore/load sequence only ever runs at actual game start.)*

11. **Save data scope — what is saved:**

    | System | Data persisted |
    |---|---|
    | Hero | Equipment loadout, tower mastery XP per tower type, learned skill build |
    | Tower | Unlocked tower variants, component upgrade levels |
    | Inventory | All items (materials, components, consumables) and quantities |
    | Menagerie | All creature instances, their stats, habitat state, breeding pen state |
    | Defense Building | All unlocked structures, tech tree advancement |
    | Tarot | Deck composition, card mastery levels |
    | Mission Select | Mission completion flags, best-time records |
    | Hero Skill Build | All unlocked active and passive skills, current slot assignment |
    | Equipment Forge | All crafted equipment in the hero's forge inventory |
    | Encyclopedia | All discovered entries (skills, gear, runes, creatures, recipes) |
    | Save & Persistence itself | `last_launched_mission_id`, `last_launched_modifiers` (checkpoint file only) |

    **What is NOT saved**: hero current HP, hero world position, tower grid placement, current wave number, monsters in-flight, damage in-flight, Scout Phase timer, Intermission timer.

---

### States and Transitions

| S&P State | Active During | Description |
|---|---|---|
| `IDLE` | All game states when no write is in progress | Accepts read queries and save trigger signals |
| `SAVING` | Brief window during write | Atomic write in progress; further triggers queued (not dropped) until IDLE resumes |
| `LOADING` | Game startup only | Distributing saved data to registered systems; save triggers ignored until complete. *(Corrected 2026-07-15: previously said "post-defeat restoration" — DEFEAT never triggers a load, see Rule 10.)* |

---

### Interactions with Other Systems

**Direct API (not through EventBus — same hybrid pattern as Grid):**

| Function | Called By | When | Description |
|---|---|---|---|
| `register(ref, restore_order)` | Each of 12 systems | Their `_ready()` | Adds system to the save/restore list |
| `get_save_data()` on each system | Save & Persistence | On any save trigger | Collects serializable state |
| `restore_save_data(data)` on each system | Save & Persistence | On load | Distributes restored state |
| `reset_to_defaults()` on one system | Save & Persistence | On that system's restore error | Fallback to safe default state |

**EventBus (notifications and triggers):**

| Event | Direction | When |
|---|---|---|
| `game_saved` (emit) | S&P → EventBus | After every successful write to `save_slot_N.dat` |
| `sanctuary_state_restored` (emit, deferred 1 frame) | S&P → EventBus | After all systems are restored |
| `mission_launched` (subscribe) | EventBus → S&P | Triggers pre-mission checkpoint write; S&P reads `mission_id` and `modifiers` from the payload to populate `last_launched_mission_id` and `last_launched_modifiers` in the checkpoint file |
| `mission_phase_changed` (subscribe) | EventBus → S&P | Detects `new_phase` ∈ {MISSION_COMPLETE, DEFEAT} for post-mission save (DEFEAT save deferred 1 frame — Rule 9); detects SANCTUARY to start autosave timer |

## Formulas

### Formula 1: Save File Path Resolution

```
main_save_path    = "user://saves/save_slot_{N}.dat"
checkpoint_path   = "user://saves/save_slot_{N}_checkpoint.dat"
temp_write_path   = "user://saves/save_slot_{N}.tmp"
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `N` | int | 0–2 | Save slot index (3 slots: 0, 1, 2) |

**Notes**: All paths are under `user://saves/`. The `saves/` subdirectory must be created if absent. Slot indices are 0-based internally; the UI displays them as Slot 1, Slot 2, Slot 3.

---

### Formula 2: Autosave Timer

```
autosave_fires_at = last_save_timestamp + autosave_interval_seconds
```

| Variable | Symbol | Type | Default | Description |
|---|---|---|---|---|
| Last save timestamp | `last_save_timestamp` | float | 0.0 | Seconds since SANCTUARY entry of the most recent save of any kind |
| Autosave interval | `autosave_interval_seconds` | float | 300.0 | Seconds between autosaves (5 minutes) |

**Behaviour**: Timer resets after any save (manual, post-mission, or autosave). If the player manually saves at T=280s, the next autosave fires at T=580s. Timer pauses when game state is not SANCTUARY.

---

### Formula 3: Format Version Compatibility Check

```
load_result = FAILED  if file.format_version > CURRENT_FORMAT_VERSION
load_result = MIGRATE if file.format_version < CURRENT_FORMAT_VERSION
load_result = OK      if file.format_version == CURRENT_FORMAT_VERSION
```

| Variable | Type | Description |
|---|---|---|
| `file.format_version` | int | Version integer stored in the save file |
| `CURRENT_FORMAT_VERSION` | int constant | Version defined in source; starts at 1, increments with each breaking save format change |
| `load_result` | enum | OK (load directly), MIGRATE (apply migration then load), FAILED (abort with error) |

**Notes**: `CURRENT_FORMAT_VERSION` starts at 1 for initial release. Every breaking save format change must increment it and ship a corresponding migration function.

---

### Formula 4: Restore Order Assignment

```
restore_order = dependency_layer_index * 10 + intra_layer_index
```

| Variable | Type | Range | Description |
|---|---|---|---|
| `dependency_layer_index` | int | 0–3 | 0=Foundation, 1=Core, 2=Feature, 3=Advanced |
| `intra_layer_index` | int | 0–9 | Ordering within a layer when intra-layer order matters |

**Assigned restore_order values:**

| restore_order | System | Rationale |
|---|---|---|
| 10 | Inventory | Core; Crafting, Menagerie, Equipment Forge all depend on Inventory state |
| 11 | Mission Select | Core; independent of Inventory |
| 20 | Menagerie | Feature; reads Inventory on init |
| 21 | Defense Building | Feature; independent of Menagerie |
| 22 | Tarot | Feature; independent |
| 23 | Tower | Feature; independent |
| 24 | Constellation | Feature; independent of Tower's own restore (reads no live Tower state at restore time — only Discovery Ledger, its own data). *(Added 2026-07-17 — closes `constellation.md` OQ-1; this system had no `restore_order` assignment at all prior to this pass.)* |
| 25 | Crafting | Feature; strictly after Inventory (10) and Defense Building (21) — boot/restore-time discovery sweep (ADR-0023) reads both systems' already-restored state (`Inventory.has_items()`, `DefenseBuilding.is_tech_unlocked()`). *(Added 2026-07-18 — closes an ADR-0023 gap: that ADR requires `Crafting.restore_order > 21` but no numeric value was ever assigned in this table. This entry was also missing from the Overview's "ten systems" list above — Crafting should be added there too on the next full pass of this doc.)* |
| 30 | Hero | Advanced; Hero Skill Build depends on Hero |
| 31 | Hero Skill Build | Advanced; depends on Hero |
| 32 | Equipment Forge | Advanced; depends on Hero + Menagerie + Tarot |
| 34 | Tower Mastery | Advanced; depends on Hero (must restore after 30). *(Added 2026-07-17 — this system had no `restore_order` assignment at all; `tower-mastery.md` had self-proposed `31`, which collides with Hero Skill Build's already-assigned slot above — 34 is the correct collision-free value.)* **Open ordering question, not resolved by this pass**: `systems-index.md`'s dependency map lists Hero Skill Build as depending on Tower Mastery, which would require Tower Mastery to restore *before* 31, not after — but Tower Mastery also depends on Hero (30), and neither GDD documents whether Hero Skill Build's restore actually reads Tower Mastery's restored state or only its own independently-saved unlock list. Flagged for the two GDD owners to confirm rather than guessed at here. |
| 33 | Building Upgrade | Advanced; depends on Defense Building (21), Tarot, Menagerie, Equipment Forge (32) — all already restored by this slot. *(Added 2026-08-11, player-requested — `building-upgrade.md`'s own doc claims this exact slot, the one gap between Equipment Forge (32) and Tower Mastery (34).)* |
| 35 | Encyclopedia | Advanced; restored last — logs discoveries from all other systems. *(Renumbered 33→35 on 2026-07-17 to make room for Tower Mastery at 34 while preserving "restores last.")* |
| 36 | Tower Assembly | Advanced; independent at restore time — an assembled `TowerBlueprintData`'s saved payload is fully self-contained (component stats copied at assembly time, not re-derived from Crafting/Inventory state). *(Added 2026-08-11, player-requested — see `design/quick-specs/tower-assembly-2026-08-11.md`.)* |

## Edge Cases

**EC-1: Save file does not exist on startup (new game)**
> No `save_slot_N.dat` exists. Save & Persistence calls `reset_to_defaults()` on all registered systems. No error is thrown. The game starts clean. Data is not persisted until the first save trigger fires.

**EC-2: `.tmp` file exists on startup (previous crash during write)**
> All `.tmp` files are deleted at startup before any load attempt. The previous `.dat` file remains intact and is used for the load. If no `.dat` exists alongside a `.tmp`, the slot is treated as a new game (EC-1).

**EC-3: Checkpoint file exists on startup (game crashed mid-mission)**
> Both `save_slot_N_checkpoint.dat` and `save_slot_N.dat` exist. The player is offered a recovery choice: *"Load last Sanctuary save"* (loads `.dat`) or *"Restore from checkpoint"* (loads checkpoint). The checkpoint is deleted after either choice.

**Backend implemented 2026-08-01** (was documented but never built until now): `has_pending_checkpoint(slot)` (the detection query) and `restore_from_checkpoint(slot) -> LoadResult` (the "Restore from checkpoint" choice) both exist and are tested. `load_slot(slot)` (the "Load last Sanctuary save" choice) also now deletes any pending checkpoint. A corrupt checkpoint does NOT trigger EC-5's reset-to-defaults — it's discarded and the caller falls back to `load_slot()`, since the checkpoint is explicitly advisory (Rule 5) and a good `.dat` likely still exists. **UI closed 2026-08-23** — `main_menu.gd`'s `RecoveryChoicePanel`, wired through `_load_or_offer_recovery()`/`_on_recovery_load_save_pressed()`/`_on_recovery_restore_checkpoint_pressed()`. See `TD-save-002` (fixed).

**EC-4: `restore_save_data` fails for one system**
> Log the error with system name and offending key. Call `reset_to_defaults()` on the affected system. Continue restoring remaining systems normally. Emit `sanctuary_state_restored` after all systems are processed. Display a non-blocking warning: *"Some save data could not be loaded for [system]. That system has been reset to defaults."*

**EC-5: All registered systems fail to restore (total save corruption)**
> All systems receive `reset_to_defaults()`. Emit `sanctuary_state_restored`. Rename the corrupted file to `save_slot_N.corrupt` and preserve it for debugging. Warn the player that their save could not be loaded and the game has started fresh.

**Backend implemented 2026-08-01** (was documented but never built until now — `load_slot()` previously just returned `false` for both "no file" and "corrupt file," with no distinction and no recovery behavior at all). `load_slot(slot) -> LoadResult` now returns `SUCCESS`/`NOT_FOUND`/`VERSION_TOO_NEW`/`CORRUPT_RECOVERED` so a caller can tell these apart. On `CORRUPT_RECOVERED`: the file is renamed to `save_slot_N.corrupt` (preserved, not deleted), every registered system gets `reset_to_defaults()`, and `sanctuary_state_restored` still fires. A version-too-new file (AC-11) is deliberately NOT treated as EC-5 corruption — left completely untouched. **UI closed 2026-08-23** — `main_menu.gd`'s `SaveWarningPanel`, shown via `_perform_load()`'s `LoadResult` routing (proceeds to Sanctuary on `CORRUPT_RECOVERED` since the load already succeeded with defaults; stays at the menu on `VERSION_TOO_NEW` since the load was aborted). See `TD-save-002` (fixed).

**EC-6: A dependent system is not registered on startup**
> Assertion check detects fewer systems than expected. Debug builds: assertion error naming the missing system. Release builds: that system's data is absent from saves — it receives `reset_to_defaults()` on every load. This is a programming error, not a player-facing scenario.

**EC-7: Save triggered while SAVING state is already active**
> The second trigger is queued — not dropped — and executes immediately when the first write completes and S&P returns to IDLE. Two back-to-back writes are redundant but harmless.

**EC-8: Player runs out of disk space during write**
> Write fails mid-operation. Rename step does not execute. `.tmp` is discarded. Previous `.dat` is intact. `game_saved` is not emitted. Display: *"Save failed — insufficient disk space."* Autosave timer resets to retry in 5 minutes.

**EC-9: `format_version` higher than `CURRENT_FORMAT_VERSION` (downgrade)**
> Load aborted. Player sees: *"This save was created with a newer version of the game. Please update to continue."* Save file is not modified or deleted.

**EC-10: Autosave fires during Save & Quit sequence**
> Autosave is queued (EC-7). Application exit is blocked until the write queue empties and S&P returns to IDLE. This prevents an interrupted write on quit.

**EC-11: Hero dies and a tower is destroyed in the same frame (added 2026-07-15)**
> A boss attack (or two simultaneous monster attacks) kills the hero and destroys a tower within the same physics frame. Wave Manager emits `mission_phase_changed(DEFEAT)` on `hero_died`; independently, Tower emits `tower_destroyed` → `tower_component_returned`, and Inventory emits `item_added(metadata={"damaged": true})` — all in the same frame, in an order Godot does not guarantee across Autoloads. Save & Persistence's DEFEAT-save handler does not call `get_save_data()` immediately; per Rule 9 it defers exactly 1 frame first, guaranteeing every synchronous handler for that frame's events (including Inventory's `item_added`) has already run. The destroyed tower's damaged components are correctly present in the resulting save. Without this deferral, the save could race ahead of the component-return write and silently omit the destroyed tower's components from the DEFEAT save.

## Dependencies

### Upstream Dependencies

| System | Dependency Type | What S&P needs |
|---|---|---|
| **EventBus System** | Infrastructure | S&P subscribes to `mission_launched` and `mission_phase_changed`. EventBus must be Autoload #1; S&P is Autoload #2. |

No other upstream dependencies — Save & Persistence is Foundation layer.

### Downstream Dependents

All 15 systems below must implement the three-function interface (`get_save_data`, `restore_save_data`, `reset_to_defaults`) and call `register()` in their `_ready()`. *(Count corrected 10→12→15 — 2026-07-17 added Constellation and Tower Mastery; 2026-08-24 `/design-review` re-review found Crafting (25), Building Upgrade (33), and Tower Assembly (36) had all been present in Formula 4's `restore_order` table since 2026-07-18/2026-08-11 but were never added to this table — confirmed via `grep` that all three genuinely call `GSavePersistence.register()` in shipped code, so this was a real drift, not a design ambiguity. Rule 2's assertion count and AC-2/AC-10's "N systems" language updated to match — see those rules' own 2026-08-24 notes.)*

| System | restore_order | What it gets from S&P | Critical constraint |
|---|---|---|---|
| Inventory | 10 | Full item state restored | Must be restored before Menagerie, Crafting, Equipment Forge |
| Mission Select | 11 | Completion flags, best times | Must be restored before mission launch is possible |
| Menagerie | 20 | Creature instances, habitat, breeding pen | Restored after Inventory (creature stats reference item types) |
| Defense Building | 21 | Unlock tree state | Independent within Feature layer |
| Tarot | 22 | Deck composition, mastery | Independent within Feature layer |
| Tower | 23 | Variant and upgrade unlocks | Independent within Feature layer |
| Constellation | 24 | Discovery Ledger (`pattern_id` → first-discovered timestamp) | Independent within Feature layer — reads no other system's restored state. *(Added 2026-07-17.)* |
| Crafting | 25 | Discovery Ledger (`recipe_id` → discovered) | Strictly after Inventory (10) and Defense Building (21) — boot/restore-time discovery sweep (ADR-0023) reads both. **Added 2026-08-24** — real registrant since 2026-07-18, missing from this table until now. |
| Hero | 30 | Equipment loadout, mastery XP | Must be restored before Hero Skill Build |
| Hero Skill Build | 31 | Unlocked skills, slot assignment | Depends on Hero being restored first |
| Equipment Forge | 32 | Crafted gear inventory | Depends on Hero, Menagerie, Tarot being restored |
| Building Upgrade | 33 | Purchased upgrade ledger | Depends on Defense Building (21), Tarot, Menagerie, Equipment Forge (32) all being restored first. **Added 2026-08-24** — real registrant since 2026-08-11, missing from this table until now. |
| Tower Mastery | 34 | Per-build proximity accumulators, keyed by `build_signature` | Depends on Hero being restored first. *(Added 2026-07-17 — see the Formula 4 table's note on the unresolved Hero Skill Build/Tower Mastery ordering question.)* |
| Encyclopedia | 35 | All discovered entries | Restored last among always-resident systems — its data references all other systems. *(Renumbered 33→35 on 2026-07-17.)* |
| Tower Assembly | 36 | Player-assembled `TowerBlueprintData` payloads (self-contained — stats copied at assembly time) | Independent at restore time — reads no other system's restored state. **Scene-instanced, not always-resident** — registers/unregisters on its own mission lifecycle, not just at game start (see Rule 3's late-registration note). **Added 2026-08-24** — real registrant since 2026-08-11, missing from this table until now. |

## Tuning Knobs

| Knob | Default | Safe Range | Effect |
|---|---|---|---|
| `autosave_interval_seconds` | 300.0 | 120–600 | Frequency of background autosave in Sanctuary. Lower = more frequent writes (safer, more disk activity). Higher = longer exposure between autosaves. |
| `save_slot_count` | 3 | 1–10 | Number of available save slots. Changing this requires updating save slot UI. |
| `CURRENT_FORMAT_VERSION` | 1 | N/A (increment only) | Save file schema version. Must increment with every breaking format change and ship with a migration function. Never decrement. |

## Visual/Audio Requirements

N/A — Save & Persistence has no visual or audio output. A brief save indicator (icon or text flash) is required when `game_saved` fires, but this is a Mission HUD responsibility — not a Save & Persistence requirement.

## UI Requirements

N/A — Save & Persistence does not own any UI. The save slot selection screen, save confirmation dialog, and recovery choice dialog (EC-3) are Mission Select / Main Menu UI responsibilities. Save & Persistence provides the data and emits the events; UI systems present them.

## Acceptance Criteria

**AC-1 — Exclusive disk I/O**
> **Given** a dependent system (e.g., Inventory), **when** it attempts to call `FileAccess.open()` directly, **then** this is caught at code review — no system other than Save & Persistence may call FileAccess. *(Process criterion, not a runtime test.)*

**AC-2 — Registration and startup assertion**
> **Given** 15 systems are expected to register, **when** only 14 register during startup, **then** Save & Persistence logs a clear error naming the missing system in debug builds.

**AC-3 — Post-mission save fires on MISSION_COMPLETE or DEFEAT**
> **Given** the game reaches MISSION_COMPLETE or DEFEAT, **when** `mission_phase_changed` fires with `new_phase` equal to either value, **then** `save_slot_N.dat` is written within 2 seconds and `game_saved` is emitted. For the DEFEAT case specifically, the write is deferred exactly 1 frame per Rule 9 before `get_save_data()` is called on any system. *(Corrected 2026-07-15: previously referenced a non-existent "phase=OUTCOME" — see Rule 8's correction.)*

**AC-13 — DEFEAT-save ordering vs. same-frame tower destruction**
> **Given** a boss attack kills the hero and destroys a tower in the same physics frame (both damage events resolving in the same frame's deferred-dispatch pass), **when** `hero_died` triggers Wave Manager's `mission_phase_changed(DEFEAT)` and, independently, Tower's `tower_destroyed` → `tower_component_returned` → Inventory's `item_added(metadata={"damaged": true})` cascade also resolves in that same frame, **then** Save & Persistence's DEFEAT-triggered save (deferred 1 frame per Rule 9) reads Inventory's state only after that cascade has completed, and the destroyed tower's damaged components are present in the resulting `save_slot_N.dat`. **Requires unit test** — inject `hero_died` and `tower_destroyed` in the same frame via EventBusSpy, assert `Inventory.get_save_data()` is not called by Save & Persistence until the frame after both cascades resolve.

**AC-4 — Pre-mission checkpoint written on `mission_launched`**
> **Given** the player launches a mission, **when** `mission_launched` fires, **then** `save_slot_N_checkpoint.dat` is written and `game_saved` is NOT emitted.

**AC-5 — Atomic write: previous file intact after a failed write**
> **Given** a write fails mid-operation (simulated by disk-full condition), **when** the write is attempted, **then** the previous `save_slot_N.dat` is intact and readable; no partial file replaces it.

**AC-6 — Restore order is respected**
> **Given** Inventory has restore_order=10 and Equipment Forge has restore_order=32, **when** a load is performed, **then** Inventory's `restore_save_data()` is called before Equipment Forge's.

**AC-7 — Restore error falls back to reset_to_defaults**
> **Given** one system's `restore_save_data()` throws, **when** the error is caught, **then** `reset_to_defaults()` is called on that system, remaining systems are still restored, and `sanctuary_state_restored` is emitted.

**AC-8 — `sanctuary_state_restored` is deferred by 1 frame**
> **Given** all systems are restored, **when** `sanctuary_state_restored` is emitted, **then** it fires on the frame AFTER all `restore_save_data()` calls complete — not in the same frame.

**AC-9 — Autosave does not fire during missions**
> **Given** the autosave timer is at 299s, **when** the game state is WAVE_ACTIVE, **then** the timer does not fire and no save is written.

**AC-10 — New game produces default state**
> **Given** no save file exists for a slot, **when** the game loads that slot, **then** all 15 systems report their default new-game state (no items, no creatures, no deck, no encyclopedia entries).

**AC-11 — Downgrade blocked**
> **Given** a save file with `format_version = 2` and `CURRENT_FORMAT_VERSION = 1`, **when** the player tries to load that slot, **then** the load is aborted and the player sees a version mismatch message. The save file is not modified.

**AC-12 — Core Rule 11 upheld across defeat**
> **Given** the player crafted an item and the hero learned a tower skill before a mission, **when** they suffer a DEFEAT, **then** the crafted item is still in inventory and the tower skill is still in the hero's learned set — both in the immediately-restarted SCOUT phase (nothing was ever unloaded from memory) and in any future session loaded from the DEFEAT-triggered save. *(Corrected 2026-07-15: "after returning to Sanctuary" was stale — DEFEAT restarts directly to SCOUT per `game-concept.md`, it does not route through SANCTUARY; see Rule 10's correction.)*

## Open Questions

**OQ-1: What serialization format — Resource, JSON, or binary?**
> The GDD specifies the interface contract and file naming but not the underlying format. Resource serialization is idiomatic Godot but produces large files and is harder to migrate. JSON is human-readable but slower and verbose. Binary is compact and fast but hardest to migrate. This is an ADR-level decision — run `/architecture-decision` before implementation begins.

**OQ-2: Is save encryption required?**
> For a single-player game sold on Steam, save encryption primarily prevents casual tampering. Defer to a security policy ADR. Does not block GDD completion.

**OQ-3: How does migration handle fields absent in older saves?**
> Each system's `restore_save_data()` must handle missing keys by falling back to that field's default value. This restore contract must be specified in each downstream system's GDD. Flag it when each dependent system is authored.

**OQ-4: Does the game support Steam Cloud saves?**
> If Steam Cloud is enabled, `user://saves/` would sync automatically. This introduces device conflict scenarios. Defer to the platform integration milestone — does not affect the GDD design.

**OQ-5: Where does the registered system count constant live?**
> Core Rule 3 asserts against an "expected system count," corrected 10→12 on 2026-07-17 (Constellation, Tower Mastery added). This constant must update when new systems register with Save & Persistence — this is now the second time it has drifted from the actual registrant count, reinforcing the need for a single source of truth rather than a hardcoded literal. Confirm: should it live in Save & Persistence's GDScript file or in a central project constants file?
