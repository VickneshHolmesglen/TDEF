# Save & Persistence System

> **Status**: Designed (pending review)
> **Author**: Vicknesh + Claude Sonnet
> **Last Updated**: 2026-05-15
> **Implements Pillar**: The Sanctuary is Yours (persistent meta-progression)

## Overview

The Save & Persistence System is the serialization layer that converts the game's persistent state to and from durable storage. It is the only system permitted to read from and write to disk. All ten systems that carry state between sessions (Hero, Tower, Inventory, Menagerie, Defense Building, Tarot, Mission Select, Hero Skill Build, Equipment Forge, Encyclopedia) provide their serializable data to the Save & Persistence System on demand; none of them handle disk I/O directly. The system manages save slots, controls when saves occur (at Sanctuary entry, on mission launch as a pre-mission checkpoint, and on explicit player request), and reconstructs game state on load by distributing saved data back to the owning systems via the `sanctuary_state_restored` event. The core contract this system upholds is Core Rule 11: **Sanctuary progress is always persistent** — a mission defeat triggers a save of the Sanctuary's current state before restarting from Scout Phase, ensuring the player returns to an intact Sanctuary regardless of outcome. The system does not interpret or validate the data it stores; each owning system is responsible for providing correct data and consuming it correctly on restore.

## Player Fantasy

The Save & Persistence System has no player fantasy of its own — it is pure infrastructure. Players experience it as a promise: *the Sanctuary always survives*. The emotional weight of defeat is strictly about the mission; the Sanctuary, the player's choices, their crafted gear, and their unlocked technology are never at risk. This promise — implicit, never stated on-screen — is what allows players to experiment boldly during missions. They can attempt aggressive strategies knowing the cost of failure is only a mission restart, not the loss of their entire progression investment. The Save & Persistence System is the mechanism that keeps this promise. Players never see it; they trust it.

## Detailed Design

### Core Rules

1. Save & Persistence is the second Autoload after EventBus. It is the **exclusive disk I/O system** — no other system may read from or write to disk. All file access routes through this system.

2. Each of the 10 dependent systems must implement three interface functions:
   - `get_save_data() -> Dictionary` — returns the system's current serializable state
   - `restore_save_data(data: Dictionary) -> void` — applies saved state to the system
   - `reset_to_defaults() -> void` — returns the system to its initial new-game state (used on restore failure)

3. Each dependent system calls `SavePersistence.register(system_ref: Object, restore_order: int)` during its `_ready()`. Save & Persistence maintains the registered list sorted by `restore_order` (ascending). Systems with lower `restore_order` values are restored first. Foundation-layer dependencies must be restored before systems that depend on them. Any system that implements the interface but never calls `register()` will have its data silently absent from saves — this is detected at startup via an assertion check against the expected system count.

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

8. **Autosave behavior**: The autosave timer runs only during the SANCTUARY state. It does not fire during SCOUT, WAVE_ACTIVE, INTERMISSION, or OUTCOME. Timer interval: 5 minutes. Autosave uses the same atomic write path as manual saves, overwriting `save_slot_N.dat`.

9. **Load and restore sequence**: On game start or on DEFEAT returning to Sanctuary:
   1. Read `save_slot_N.dat` from disk
   2. Apply migration if `format_version` is outdated
   3. Iterate registered systems in `restore_order` (ascending)
   4. Call `restore_save_data(data)` on each system
   5. On any restore error: log with system name, call `reset_to_defaults()` on that system, continue to the next system
   6. After all systems processed: emit `sanctuary_state_restored` (save_slot: int) — **deferred by exactly 1 frame** so all `_ready()` signal connections are established before the event fires

10. **Save data scope — what is saved:**

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
| `LOADING` | Game startup and post-defeat restoration | Distributing saved data to registered systems; save triggers ignored until complete |

---

### Interactions with Other Systems

**Direct API (not through EventBus — same hybrid pattern as Grid):**

| Function | Called By | When | Description |
|---|---|---|---|
| `register(ref, restore_order)` | Each of 10 systems | Their `_ready()` | Adds system to the save/restore list |
| `get_save_data()` on each system | Save & Persistence | On any save trigger | Collects serializable state |
| `restore_save_data(data)` on each system | Save & Persistence | On load | Distributes restored state |
| `reset_to_defaults()` on one system | Save & Persistence | On that system's restore error | Fallback to safe default state |

**EventBus (notifications and triggers):**

| Event | Direction | When |
|---|---|---|
| `game_saved` (emit) | S&P → EventBus | After every successful write to `save_slot_N.dat` |
| `sanctuary_state_restored` (emit, deferred 1 frame) | S&P → EventBus | After all systems are restored |
| `mission_launched` (subscribe) | EventBus → S&P | Triggers pre-mission checkpoint write; S&P reads `mission_id` and `modifiers` from the payload to populate `last_launched_mission_id` and `last_launched_modifiers` in the checkpoint file |
| `mission_phase_changed` (subscribe) | EventBus → S&P | Detects OUTCOME for post-mission save; detects SANCTUARY to start autosave timer |

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
| 30 | Hero | Advanced; Hero Skill Build depends on Hero |
| 31 | Hero Skill Build | Advanced; depends on Hero |
| 32 | Equipment Forge | Advanced; depends on Hero + Menagerie + Tarot |
| 33 | Encyclopedia | Advanced; restored last — logs discoveries from all other systems |

## Edge Cases

**EC-1: Save file does not exist on startup (new game)**
> No `save_slot_N.dat` exists. Save & Persistence calls `reset_to_defaults()` on all registered systems. No error is thrown. The game starts clean. Data is not persisted until the first save trigger fires.

**EC-2: `.tmp` file exists on startup (previous crash during write)**
> All `.tmp` files are deleted at startup before any load attempt. The previous `.dat` file remains intact and is used for the load. If no `.dat` exists alongside a `.tmp`, the slot is treated as a new game (EC-1).

**EC-3: Checkpoint file exists on startup (game crashed mid-mission)**
> Both `save_slot_N_checkpoint.dat` and `save_slot_N.dat` exist. The player is offered a recovery choice: *"Load last Sanctuary save"* (loads `.dat`) or *"Restore from checkpoint"* (loads checkpoint). The checkpoint is deleted after either choice.

**EC-4: `restore_save_data` fails for one system**
> Log the error with system name and offending key. Call `reset_to_defaults()` on the affected system. Continue restoring remaining systems normally. Emit `sanctuary_state_restored` after all systems are processed. Display a non-blocking warning: *"Some save data could not be loaded for [system]. That system has been reset to defaults."*

**EC-5: All registered systems fail to restore (total save corruption)**
> All systems receive `reset_to_defaults()`. Emit `sanctuary_state_restored`. Rename the corrupted file to `save_slot_N.corrupt` and preserve it for debugging. Warn the player that their save could not be loaded and the game has started fresh.

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

## Dependencies

### Upstream Dependencies

| System | Dependency Type | What S&P needs |
|---|---|---|
| **EventBus System** | Infrastructure | S&P subscribes to `mission_launched` and `mission_phase_changed`. EventBus must be Autoload #1; S&P is Autoload #2. |

No other upstream dependencies — Save & Persistence is Foundation layer.

### Downstream Dependents

All 10 systems below must implement the three-function interface (`get_save_data`, `restore_save_data`, `reset_to_defaults`) and call `register()` in their `_ready()`.

| System | restore_order | What it gets from S&P | Critical constraint |
|---|---|---|---|
| Inventory | 10 | Full item state restored | Must be restored before Menagerie, Crafting, Equipment Forge |
| Mission Select | 11 | Completion flags, best times | Must be restored before mission launch is possible |
| Menagerie | 20 | Creature instances, habitat, breeding pen | Restored after Inventory (creature stats reference item types) |
| Defense Building | 21 | Unlock tree state | Independent within Feature layer |
| Tarot | 22 | Deck composition, mastery | Independent within Feature layer |
| Tower | 23 | Variant and upgrade unlocks | Independent within Feature layer |
| Hero | 30 | Equipment loadout, mastery XP | Must be restored before Hero Skill Build |
| Hero Skill Build | 31 | Unlocked skills, slot assignment | Depends on Hero being restored first |
| Equipment Forge | 32 | Crafted gear inventory | Depends on Hero, Menagerie, Tarot being restored |
| Encyclopedia | 33 | All discovered entries | Restored last — its data references all other systems |

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
> **Given** 10 systems are expected to register, **when** only 9 register during startup, **then** Save & Persistence logs a clear error naming the missing system in debug builds.

**AC-3 — Post-mission save fires on OUTCOME**
> **Given** the game reaches MISSION_COMPLETE or DEFEAT, **when** `mission_phase_changed` fires with phase=OUTCOME, **then** `save_slot_N.dat` is written within 2 seconds and `game_saved` is emitted.

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
> **Given** no save file exists for a slot, **when** the game loads that slot, **then** all 10 systems report their default new-game state (no items, no creatures, no deck, no encyclopedia entries).

**AC-11 — Downgrade blocked**
> **Given** a save file with `format_version = 2` and `CURRENT_FORMAT_VERSION = 1`, **when** the player tries to load that slot, **then** the load is aborted and the player sees a version mismatch message. The save file is not modified.

**AC-12 — Core Rule 11 upheld across defeat**
> **Given** the player crafted an item and the hero learned a tower skill before a mission, **when** they suffer a DEFEAT, **then** after returning to Sanctuary: the crafted item is still in inventory and the tower skill is still in the hero's learned set.

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
> Core Rule 3 asserts against an "expected system count" of 10. This constant must update when new systems register with Save & Persistence. Confirm: should it live in Save & Persistence's GDScript file or in a central project constants file?
