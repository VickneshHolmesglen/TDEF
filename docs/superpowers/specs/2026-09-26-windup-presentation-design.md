# Wind-up Presentation (Hero Damage Legibility) — Design

- **Date:** 2026-09-26
- **Status:** Draft, pending user review
- **Follows:** `2026-09-25-hero-damage-design.md` (§10 names this as REQUIRED before any playtest)
- **Pillar:** 1 — difficulty must be diagnosable. A player who takes damage must be able to see what hit them, and a player who dodges must be able to see that they dodged.
- **Scope rule:** presentation only. No change to attack timing, targeting, damage or the wind-up/fire rules. The single simulation-side addition is one new, gameplay-inert signal (§4.2).

## 1. Goal and non-goals

**Goal.** Make elite/boss attacks on the Hero legible: warn before the hit, confirm hit or whiff, give the Hero readable damage feedback, signal low HP without relying on audio, and give Hero death a short sequence before the mission exits.

**Non-goals.**
- No Retry/Outcome screen (separate later feature). After death the game still returns to the Sanctuary.
- No settings UI or persistence for reduced motion (§6).
- No 3D-mode implementation. The dormant 3D path gets only the one-line boss hint (§4.3); the rest is recorded as a parity note (§9).
- No new art assets. Everything is drawn procedurally or via existing Tween/shader idioms.
- No change to `hero_incoming_damage`, Damage & Status, or wind-up simulation.

## 2. Decisions already made (with the user)

| Topic | Decision |
|---|---|
| Scope | Telegraph + Hero damage feedback + low-HP vignette + death sequence |
| Telegraph look | Option A: attacker pulses red, outline of the full reach square, small progress bar filling over the wind-up; non-color backups mandatory |
| Reduced motion | Single `reduce_motion()` accessor, backed by a project-setting key defaulting `false`; no UI, no persistence |
| Death | Hold ~1.5 s after Hero death, then return to Sanctuary |
| Architecture | Approach A: pull-model telegraph (driven from the existing per-frame visual sync) + event-driven Hero feedback in one shared node |

## 3. Architecture

```
MonsterManager._pass3c_visual_sync (per frame, already walks every monster)
   └─ for each entity with hero_windup_remaining > 0:
        MonsterInstance.set_windup_telegraph(progress, range_cells)
      else: MonsterInstance.clear_windup_telegraph()

HeroFeedback (new Node, attached once per mission scene)
   ├─ hero_incoming_damage / hero_damage_taken → flash, particles, flinch, big-hit shake, hit cue
   ├─ hero_health_changed                      → low-HP vignette on/off, heartbeat cue
   ├─ hero_died                                → death sequence, tells SceneManager when to leave
   └─ monster_hero_attack_resolved             → outline resolves solid (hit) or fades (whiff)

SceneManager
   └─ hero_died → waits for the death hold, then transition_to_sanctuary()
```

**Why pull for the telegraph.** The visual sync pass already runs every frame for every monster. Reading `hero_windup_remaining` there keeps the warning exactly in step with the simulation and makes leaks impossible: if a monster dies, breaches, is freed or the wave ends mid-wind-up, its `MonsterInstance` is freed with it and the state is simply never read again. An event-spawned effect would need its own cleanup for each of those cases.

**Why one `HeroFeedback` node.** `mission_scene.gd` and `the_gap.gd` already duplicate their VFX wiring. A single node, added to each scene with one line, avoids a third copy and gives the death hold one owner.

### 3.1 Files

| File | Change |
|---|---|
| `src/core/monster/monster_instance.gd` | Add `set_windup_telegraph(progress: float, range_cells: int)` / `clear_windup_telegraph()`; draw pulse tint, dashed reach outline, progress bar in `_draw()` |
| `src/core/monster/monster_manager.gd` | `_pass3c_visual_sync` computes progress and calls the above; boss hint (§4.3); emit `monster_hero_attack_resolved` (§4.2) |
| `src/core/visual_presentation/hero_feedback.gd` (+ `.tscn` if it needs a child layer) | New. All Hero-side feedback and the death sequence |
| `src/core/presentation/reduce_motion.gd` | New tiny static helper, `ReduceMotion.enabled() -> bool`, reading project setting `accessibility/reduce_motion` (default `false`) |
| `src/core/scene_manager.gd` | Hold before leaving on `hero_died` (§5.4) |
| `src/core/audio/audio_cue_dispatcher.gd` + `assets/data/audio/cues/*.tres` | New cue entries (§7) |
| `src/scenes/mission_scene.gd`, `src/gameplay/missions/the_gap/the_gap.gd` | Add the `HeroFeedback` node (one line each) |
| `design/gdd/hero.md`, `monster.md`, `event-bus.md`, ADR-0001 | Doc updates (§10) |

## 4. Attacker telegraph

### 4.1 What is drawn

Progress `p = 1 − hero_windup_remaining / hero_attack_windup_seconds`, clamped 0..1. Reach is `boss_attack_range_cells` (the Hero-attack range field the simulation already uses; confirm the exact field name against `monster_manager.gd` when writing the plan). Reach is a **square** of `(2·range+1)` cells (grid/Chebyshev distance), not a circle.

1. **Attacker pulse.** The sprite tint lerps between its normal color and red. Pulse rate is fixed at **2 Hz** (at most 2 flashes per second, inside the ≤3/s flash-safety limit), independent of wind-up length.
2. **Reach outline.** A red **dashed** outline of the reach square, centered on the attacker and following it (the hit is judged from the attacker's position at fire time). The dash pattern is the non-color backup: it reads as "danger zone" without red.
3. **Progress bar.** A small bar under the attacker fills left to right with `p`. The bar plus its border is the second non-color backup and is the countdown.

### 4.2 Hit / whiff confirmation (the one simulation-side addition)

New signal `monster_hero_attack_resolved(entity_id: int, hit: bool)`, emitted **deferred** (ADR-0001 Rule 2, same reasoning as `monster_hero_attack_winding_up`) from the point in `_pass2b_hero_attacks` where the wind-up completes and range is checked. `hit == true` if `hero_incoming_damage` was emitted, `false` if the Hero had left range. It carries no gameplay effect and no simulation code branches on it; it is purely an announcement.

Presentation on resolve:
- **Hit:** the outline flashes solid for ~0.15 s then clears.
- **Whiff:** the outline fades to neutral grey over ~0.3 s with a soft cue. This is the player's "I dodged it" confirmation.

Because the wind-up state is cleared the same frame it resolves, the resolve visual is a short-lived leftover owned by `MonsterInstance` (a stored Tween, killed at the start of the next telegraph and on `_exit_tree`, matching the ADR-0032 host-owned-Tween pattern).

### 4.3 Boss and 3D parity

- Boss overlay: change the `update_boss(...)` argument at `monster_manager.gd:764` to `entity.boss_attack_prepare_remaining > 0 or entity.hero_windup_remaining > 0.0`. This is the cheap partial telegraph named in the Hero-damage spec §10; it makes the existing prepare/attack art play for Hero wind-ups. (Line 475 already ORs the two for its own purpose.)
- The dormant 3D swarm renderer's elite tint/outline is **not** built here; recorded in §9.
- Boss wind-ups also get the 2D telegraph (§4.1) because every monster carries a `MonsterInstance` regardless of presentation mode.

## 5. Hero feedback (`HeroFeedback`)

Values come from `design/gdd/hero.md` Event Feedback table (lines ~546-548) and are constants at the top of the script or a small data resource, not scattered literals.

### 5.1 Hero takes damage
- Hero sprite flashes red-white for 2 frames; 4 frames if the hit exceeds 25% of max HP.
- 4-6 directional particles burst toward the damage source, fade over 0.3 s. Direction uses the attacker's position from `source_entity_id`; if the entity is gone, particles burst without direction.
- 3-frame flinch recoil opposite the damage direction. Cosmetic overlay only — never interrupts movement or auto-attack.
- Big hit (>25% max HP): 2-pixel screen shake over 6 frames (decaying sine) using the existing `Camera2D.offset` precedent (`_shake_camera_for_boss_death`). **Skipped entirely when `ReduceMotion.enabled()`**; the longer flash still plays (it is not motion).

### 5.2 Low-HP vignette (< 20% max HP)
- Derived from `hero_health_changed` in `HeroFeedback` (per `hero.md` line ~592, the HUD/presentation computes `current / max < 0.20` itself; the Hero emits no threshold event).
- Screen-edge dark-red vignette, ~15% inset, opacity pulsing 40%-70% on a 1.5 s sine.
- Hero sprite desaturates 40% with a slight red hue shift (shader uniform).
- **Primary signal — must be fully readable with audio muted.**
- Fades out over 0.3 s when healed above the threshold (wave-clear heal or lifesteal).
- Under `ReduceMotion.enabled()` the pulse is replaced by a steady 55% opacity.

### 5.3 Death sequence
Trigger: `hero_died`.
- Hero flashes white 4 frames, then fades to 30% opacity over 12 frames.
- Shockwave ring expands to 2× `cell_size` over 16 frames.
- Screen desaturates to 60% over 0.5 s; the low-HP vignette freezes at maximum opacity.
- Input is already locked at HP 0 by the simulation; the sequence does not need to add locks.
- Reduced motion: the shockwave ring is skipped; flash, fade, desaturate remain (none loop or shake).

### 5.4 Death hold and exit
`SceneManager._on_hero_died()` currently transitions immediately. New behavior: wait `HERO_DEATH_HOLD_SECONDS = 1.5`, then `transition_to_sanctuary()`. Implementation is a scene-tree timer owned by `SceneManager`, stored so it can be cancelled.

Edge cases the plan must cover with tests:
1. **Retry/restart during the hold** (`retry_current_mission()` or any new `_do_transition`) cancels the pending exit, so the delayed transition can never fire into a fresh mission.
2. **`hero_died` fires twice** (or `MISSION_COMPLETE` arrives during the hold): only one transition results; the existing `_transition_in_progress` guard covers the second call, and the hold must not stack timers.
3. **Mission ends by `MISSION_COMPLETE` during the hold** (the wave-clear and death are near-simultaneous): the existing MISSION_COMPLETE path may transition immediately; the pending hold timer is cancelled by `_do_transition`.
4. **`SceneManager` tests without a scene tree timer**: the hold length is an injectable field defaulting to 1.5 so existing scene-manager tests can set it to 0.

## 6. Reduced motion

`ReduceMotion.enabled()` is the single accessor. It reads a project-setting key (`accessibility/reduce_motion`, default `false`) so it can be flipped by hand, by a test, or by a future settings screen without a code change. No UI, no persistence now. Honored by: big-hit shake (skipped), low-HP vignette pulse (steady), death shockwave ring (skipped), and the telegraph pulse (steady tint instead of 2 Hz pulsing; outline and bar are unchanged because they are not motion hazards).

## 7. Audio

Data-driven through the existing `AudioCueDispatcher` and cue `.tres` files; all sounds reuse the Kenney CC0 packs already in the project. New cues:

| Cue | Trigger | Notes |
|---|---|---|
| `monster_windup_warning` | `monster_hero_attack_winding_up` | Rate-limited (one per 0.25 s) so a pack of elites winding up together is not a wall of sound |
| `monster_attack_whiff` | `monster_hero_attack_resolved(hit=false)` | Soft "swish" confirmation |
| `hero_damage_taken` | (exists) | Unchanged; pitch ±5%, volume scales with damage proportion per `hero.md` |
| `hero_low_hp_heartbeat` | vignette on | Synced to the 1.5 s pulse, 60% of normal hit volume, fades at threshold crossings |
| `hero_death` | `hero_died` | Heavy impact plus 0.5 s descending tone; other combat SFX duck 40% for 1 s |

Audio is enhancement only; every signal above has a fully visual equivalent.

## 8. Accessibility checklist

- No color-only signal: dashed outline (shape), progress bar (shape/position), Hero flash plus particles plus flinch, low-HP vignette plus sprite desaturation.
- Flash limit: telegraph pulse ≤ 2 Hz; damage flashes are 2-4 frames and cannot overlap-stack above 3 per second because the Hero's incoming attacks are period-gated (≥ 3.4 s per attacker); multi-attacker overlap is bounded by a minimum 0.2 s gap between Hero flash restarts.
- Reduced motion per §6.
- Low-HP state is legible with sound off (§5.2).

## 9. Parity notes (not built here)

- **Dormant 3D swarm path.** `MonsterSwarmRenderer3D` uses a fixed 4-channel `INSTANCE_CUSTOM` contract (ADR-0038); an elite wind-up tint/outline would need a channel or a separate overlay pass. Recorded for the cutover decision, which is user-owned.
- `BossCreaturePresenter3D` gets only the boss hint from §4.3.
- Progress-bar and outline for 3D would be a billboard/decal, not the `_draw()` path.

## 10. Documentation to update with the implementation

- `design/gdd/hero.md`: mark the Event Feedback rows implemented, note `ReduceMotion`.
- `design/gdd/monster.md`: document `monster_hero_attack_resolved` and the telegraph presentation.
- `design/gdd/event-bus.md` and ADR-0001 Rule 2 amendment: add `monster_hero_attack_resolved` (deferred) beside `monster_hero_attack_winding_up`.
- Hero-damage spec §10: point to this spec as the follow-up now specified.
- `design/accessibility-requirements.md`: record `reduce_motion` accessor and what honors it.

## 11. Testing

Unit (gdUnit4, targeted suites only):
- Telegraph progress math and clamping; `MonsterInstance` clears when `hero_windup_remaining == 0`; the resolve Tween is killed on re-telegraph and on free (no null refs on a freed attacker).
- `monster_hero_attack_resolved` emits exactly once per wind-up, `hit` matches whether `hero_incoming_damage` fired, emitted deferred, and never emitted for a monster killed mid-wind-up.
- Boss hint: `update_boss` receives true when only `hero_windup_remaining > 0`.
- `HeroFeedback`: vignette on at 19.9%, off at 20%, fades on heal; big-hit threshold at exactly 25%; shake skipped under reduced motion; ≥0.2 s gap between flash restarts; disconnect in `_exit_tree` (ADR-0001 Rule 6).
- `SceneManager`: hold timer, and the three edge cases in §5.4.
- `ReduceMotion.enabled()` default false, honors the setting.

Live (only when the user asks): an elite winding up on the Hero shows pulse/outline/bar; walking out of the square before fire shows the whiff; being hit shows flash/particles; dropping under 20% shows the vignette; dying holds ~1.5 s then leaves.

## 12. Phasing

Each phase is shippable on its own:
1. **Telegraph + resolve + audio cues** (§4, `monster_windup_warning`, `monster_attack_whiff`) — this alone satisfies "required before playtest".
2. **Hero damage feedback + low-HP vignette + `ReduceMotion`** (§5.1, §5.2, §6).
3. **Death sequence + SceneManager hold** (§5.3, §5.4).

## 13. Open questions

None blocking. Values in §5 are first-pass from `hero.md` and unplaytested. The exact Hero-attack range field name and the `_pass2b_hero_attacks` emit point are confirmed during plan writing, not guessed here.
