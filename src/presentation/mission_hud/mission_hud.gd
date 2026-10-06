class_name MissionHud
extends CanvasLayer

## Mission HUD scaffold & HUD-local derived state (Story 001, TR-hud-000, ADR-0031).
##
## GDD source: design/gdd/mission-hud.md — Core Rules Group 1 (Rules 1-4).
## ADR-0002: static CanvasLayer child of the mission scene (scene-instanced, not
## an Autoload). Owns zero gameplay state — every field below is a display-only
## mirror; the authoritative counts/state live in their owning systems (Wave
## Manager, Monster System, Tower System).
##
## "Mounts"/"unmounts" describe internal state, not scene-tree membership —
## _ready()/_exit_tree() fire exactly once per mission (node destroyed only
## when the mission scene unloads).
##
## Story 002+ extend this scaffold (Planning/Combat Cluster children, direct
## Autoload calls, outbound signals) — this story owns only the outer-root
## state fields, their mutation handlers, and the mount/unmount lifecycle.

const BOSS_TIER: int = 2  ## MonsterResource.tier: 0=STANDARD 1=ELITE 2=BOSS

## Player-reported 2026-08-16: the toast log kept growing/repositioning as
## more items were picked up -- ToastHost is anchored with anchor_top ==
## anchor_bottom (both pinned to the screen bottom), so Godot sizes it to fit
## all live children and grows it *upward* from that anchor point with no
## cap. A busy wave with several drops in quick succession made the whole
## log visibly climb up the screen. Fix: bound how many toasts can be alive
## at once -- the oldest is force-dismissed the instant a new one would
## exceed this, so the box never needs to grow past MissionScene.tscn's/
## the_gap.tscn's own fixed ToastHost rect (offset_top=-140, 132px tall,
## fits 5 single-line toasts at ~23px + separation with room to spare).
const MAX_VISIBLE_TOASTS: int = 5
const PlanningClusterScene: PackedScene = preload("res://src/presentation/mission_hud/planning_cluster.tscn")
const BANNER_DURATION_SECONDS: float = 3.0  ## Rule 13's fixed auto-dismiss duration

@onready var _planning_cluster_host: Node = $PlanningClusterHost
## Story 008 (ADR-0011): instanced exactly once at this root, shared by every
## focusable control across this epic's Ready/Ultimate/Sell/Retry buttons —
## outlives every Planning Cluster re-instantiation cycle, handed down to
## each fresh instance the same way _boss_telegraph_cell/_last_known_routes are.
@onready var _input_mode_tracker: InputModeTracker = $InputModeTracker
@onready var _combat_cluster: Control = $CombatCluster
@onready var _ultimate_button: Button = $CombatCluster/UltimateButton
var _ultimate_focus_ring: Panel = null

# Story 011 (Rule 4 visual half, PC-4, Interactions table): Combat Cluster
# live-data widgets — pure renderers, no mutation logic of their own beyond
# what's noted per-handler below.
@onready var _phase_label: Label = $CombatCluster/Chrome/PhaseLabel
@onready var _wave_label: Label = $CombatCluster/Chrome/WaveLabel
@onready var _phase_timer_label: Label = $CombatCluster/Chrome/PhaseTimerLabel
@onready var _hero_hp_label: Label = $CombatCluster/Chrome/HeroHpLabel
@onready var _breach_counter_label: Label = $CombatCluster/Chrome/BreachCounterLabel
@onready var _boss_bar_label: Label = $CombatCluster/Chrome/BossBarLabel
@onready var _gold_label: Label = $CombatCluster/Chrome/GoldRow/GoldLabel
## Player-reported 2026-08-16: replaced the "wood: 5 | stone: 3" text tally
## with "[icon] xN" chips, one per material type, mirroring inventory_
## screen.gd's established icon-with-text-fallback pattern (ItemDefinition
## Resource.icon == null falls back to plain text, same "content can lag
## code" tolerance -- see that file's _apply_slot_visual() doc comment).
##
## Player-requested 2026-08-16 ("UI Changes.PNG" yellow box): pulled out of
## the Chrome VBoxContainer's top-right vertical stack and repositioned as an
## independent CombatCluster child (matching PlanningCluster's own manual-
## position pattern for its Ready/Composition elements) so item drops render
## in their own dedicated screen zone instead of stacking under Gold.
@onready var _materials_row: HBoxContainer = $CombatCluster/MaterialsRow
@onready var _skill_cooldown_host: HBoxContainer = $CombatCluster/Chrome/SkillCooldownHost
## Player-reported 2026-08-16: replaced the original "Skill N: Ready" /
## "Skill N: 3.2s" text-Label placeholder with real icon buttons matching
## design/ux/interaction-patterns.md Pattern 12 (Skill Cooldown Button) --
## dim + top-to-bottom dark fill + numeric countdown while on cooldown, full
## opacity/no overlay when ready. Built procedurally in _ready() (mirrors
## planning_cluster.gd's _build_tower_list() precedent) rather than hand-
## authored 4x in the .tscn, since the 4 slots are structurally identical.
## No per-skill icon art exists yet (design/gdd/mission-hud.md's own Open
## Question #4 -- the Hero Skill Build GDD that would define real icons
## doesn't exist yet either) -- each tile shows its slot number as a
## placeholder face, the same "content can lag code" tolerance grid_
## visual.gd's own class doc comment documents elsewhere.
const SKILL_SLOT_COUNT: int = 4
const SKILL_TILE_SIZE: Vector2 = Vector2(40, 40)
const SKILL_READY_COLOR: Color = Color(0.24, 0.30, 0.42, 1.0)
const SKILL_COOLDOWN_FILL_COLOR: Color = Color(0.0, 0.0, 0.0, 0.7)
var _skill_slot_icons: Array[ColorRect] = []
var _skill_slot_fills: Array[ColorRect] = []
var _skill_slot_countdowns: Array[Label] = []
@onready var _tower_hp_bars_host: VBoxContainer = $CombatCluster/Chrome/TowerHpBarsHost
@onready var _damage_number_host: Control = $CombatCluster/DamageNumberHost
@onready var _toast_host: VBoxContainer = $CombatCluster/ToastHost

## AC-61: mirrors _active_tower_hp_bars 1:1 (tower_id -> its rendered Label) so
## a single tower's bar can be removed immediately without rebuilding the host.
var _tower_hp_bar_labels: Dictionary[int, Label] = {}
## AC-64: materials_earned is a per-event delta — this is the running total
## this story accumulates and renders.
var _materials_tally: Dictionary[String, int] = {}

@onready var _banner: Control = $Banner
@onready var _banner_label: Label = $Banner/Label
@onready var _banner_timer: Timer = $BannerTimer

## Story 012 (Rules 25-27, ADR-0028): the ONE deliberate direct-Autoload-call
## exception in this file's entire outbound surface (ADR-0020 Criterion B).
## Pragmatic placeholder location, flagged not silently assumed: the GDD's
## own DEFEAT row describes a separate "outcome/Defeat screen" taking over
## from Mission HUD entirely — that screen does not exist anywhere in this
## codebase yet (no story/epic has built it). Housed here instead, gated to
## visible only during DEFEAT via _combat_cluster/_planning_cluster_host
## hiding rather than the whole CanvasLayer, so this button (and nothing
## else Mission HUD owns) can actually be shown/pressed in DEFEAT. Replace
## with the real Outcome Screen once that scene exists.
@onready var _retry_button: Button = $RetryButton
var _retry_focus_ring: Panel = null

## monster.md "Breach — Visual Feedback": STANDARD/ELITE breach flashes only
## the goal-side screen edge red; BOSS breach (tier==2) flashes all four
## edges. "One flash per event, no stacking" — each edge gets its own tween
## so a rapid second breach on the same edge restarts the fade rather than
## layering.
const BREACH_FLASH_COLOR: Color = Color(1.0, 0.0, 0.0, 0.55)
const BREACH_FLASH_IN_DURATION: float = 0.25  ## within the GDD's 0.2-0.3s window
const BREACH_FLASH_FADE_DURATION: float = 0.5
const BREACH_COUNTER_PULSE_SCALE: float = 1.2
const BREACH_COUNTER_PULSE_DURATION: float = 0.3
@onready var _breach_flash_top: ColorRect = $BreachFlashOverlay/TopEdge
@onready var _breach_flash_bottom: ColorRect = $BreachFlashOverlay/BottomEdge
@onready var _breach_flash_left: ColorRect = $BreachFlashOverlay/LeftEdge
@onready var _breach_flash_right: ColorRect = $BreachFlashOverlay/RightEdge
var _breach_flash_tweens: Dictionary[StringName, Tween] = {}
var _breach_counter_pulse_tween: Tween = null
## Computed lazily from GGrid.get_goal_cells() on first breach — the goal
## cell's position doesn't change mid-mission, so this is cached rather than
## recomputed per breach.
var _goal_side_edge: StringName = &""

## Story 001's Rule 4 fields don't track current phase directly (each handler
## branches on the new_phase argument it receives) — Story 005 needs to know
## the CURRENT phase at the moment tower_destroyed fires (AC-23's own gate),
## not just at a transition, so this field is added here.
var _current_phase: String = ""

## Story 002 (Rules 5-8): current live Planning Cluster instance, or null
## during WAVE_ACTIVE (torn down) and before the first SCOUT mount.
var _planning_cluster: PlanningCluster = null

var _enemies_alive_display: int = 0
var _breach_count: int = 0
var _active_tower_hp_bars: Dictionary[int, Vector2] = {}
var _boss_state: Dictionary = {}  ## {} = null-equivalent; else {entity_id, display_name, current_hp, max_hp}
## Story 006 populates/consumes this — declared and reset here per Rule 4,
## since it must survive every Planning Cluster re-instantiation cycle.
var _boss_telegraph_cell: Vector2i = Vector2i(-1, -1)
## Edge Cases: combat events can still arrive the same frame a terminal
## mission_phase_changed fires, before _exit_tree() actually runs (queue_free()
## is end-of-frame, not instant). Latched on receipt, short-circuits every
## Rule-4 mutation handler for the rest of this instance's life.
var _terminal: bool = false

## Set-effect indicator (2026-10-06): a list under the Hero HP line showing
## active set-effect shields and buffs. Built in code so both mission scenes
## (the_gap.tscn, MissionScene.tscn) get it without editing either scene. It
## polls SetEffectController.get_hud_entries() a few times a second instead of
## listening for a signal, so the controller stays signal-free.
const EFFECT_POLL_SECONDS: float = 0.25
const EFFECT_COLOR_SHIELD: Color = Color(0.55, 0.82, 1.0)
const EFFECT_COLOR_BUFF: Color = Color(1.0, 0.85, 0.45)
var _effect_list: VBoxContainer = null
var _effect_poll: Timer = null
var _effect_signature: String = ""

## Story 003 (Rules 9-11, PC-1): outer-root-owned so it survives every
## Planning Cluster re-instantiation cycle — handed to whichever instance is
## currently live (or the next one spawned, if none is live yet) so
## INTERMISSION's "reappear showing the last-known route" (Rule 11) works
## across cluster boundaries, the same pattern Rule 4's other cached fields
## already use.
var _last_known_routes: Array = []


func _ready() -> void:
	GEventBus.mission_phase_changed.connect(_on_mission_phase_changed)
	GEventBus.monster_spawned.connect(_on_monster_spawned)
	GEventBus.monster_died.connect(_on_monster_died)
	GEventBus.monsters_died_batch.connect(_on_monsters_died_batch)
	GEventBus.monster_breached.connect(_on_monster_breached)
	GEventBus.tower_damaged.connect(_on_tower_damaged)
	GEventBus.boss_died.connect(_on_boss_died)
	GEventBus.templates_ready.connect(_on_templates_ready)
	# Boot-race fallback (GDD Edge Cases): if templates_ready already fired
	# before this _ready() finished connecting, the ghost-event window would
	# otherwise permanently miss Rule 9's one-shot initial route render.
	if GPathfindingSystem.is_templates_ready():
		_on_templates_ready(0, 0.0)
	GEventBus.tower_destroyed.connect(_on_tower_destroyed)
	GEventBus.hero_class_unlocked.connect(_on_hero_class_unlocked)
	_banner_timer.one_shot = true
	_banner_timer.timeout.connect(_dismiss_banner)
	_banner.visible = false
	GEventBus.wave_preview_available.connect(_on_wave_preview_available)
	GEventBus.wave_completed.connect(_on_wave_completed)
	GEventBus.hero_skill_cooldown_updated.connect(_on_hero_skill_cooldown_updated)
	_ultimate_button.pressed.connect(_on_ultimate_pressed)
	_build_ultimate_focus_ring()
	_ultimate_button.focus_entered.connect(_update_ultimate_focus_ring)
	_ultimate_button.focus_exited.connect(_update_ultimate_focus_ring)
	_input_mode_tracker.input_mode_changed.connect(_update_ultimate_focus_ring)
	GEventBus.hero_health_changed.connect(_on_hero_health_changed)
	GEventBus.hero_skill_cooldown_updated.connect(_on_skill_cooldown_display_updated)
	GEventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	GEventBus.monster_damage_number_requested.connect(_on_monster_damage_number_requested)
	GEventBus.wave_started.connect(_on_wave_started)
	GEventBus.phase_timer_tick.connect(_on_phase_timer_tick)
	GEventBus.wave_countdown_warning.connect(_on_wave_countdown_warning)
	GEventBus.materials_earned.connect(_on_materials_earned)
	GEventBus.resources_changed.connect(_on_resources_changed)
	GEventBus.item_added.connect(_on_item_added)
	GEventBus.item_removed.connect(_on_item_removed)
	GEventBus.item_pickup_rejected.connect(_on_item_pickup_rejected)
	GEventBus.skill_unlocked.connect(_on_skill_unlocked)
	_build_skill_slots()
	_retry_button.pressed.connect(_on_retry_pressed)
	_retry_button.set_meta(UiAudioBinder.META_KEY, UiAudioBinder.KIND_CONFIRM)
	_build_retry_focus_ring()
	_retry_button.focus_entered.connect(_update_retry_focus_ring)
	_retry_button.focus_exited.connect(_update_retry_focus_ring)
	_input_mode_tracker.input_mode_changed.connect(_update_retry_focus_ring)

	# Real bug found and fixed 2026-08-08: HUD is a CanvasLayer, which does
	# NOT inherit visibility from its Node2D parent (GameplayRoot) -- setting
	# GameplayRoot.visible = false (mission_scene.gd, before a mission is
	# launched) does nothing to CombatCluster, a full-rect Control with the
	# Control default mouse_filter (STOP). Left at its default `visible =
	# true`, CombatCluster silently intercepted every click across the whole
	# screen from the moment this scene mounted -- including clicks meant for
	# MissionSelectScreen's mission-list and Launch buttons underneath,
	# rendered earlier in the same tree but with no way to receive input
	# through this always-on full-rect blocker. A real player reaching
	# Mission Select could see the mission list but could never actually
	# select or launch anything. Hidden here (an invisible Control receives
	# no input at all, closing the click-block, not just the visual clutter)
	# and shown again on mission_launched -- the same visible-toggle
	# mechanism this class already uses for DEFEAT/retry (see _combat_
	# cluster.visible at line ~250/314), just applied to the pre-launch state
	# too.
	_combat_cluster.visible = false
	GEventBus.mission_launched.connect(_on_mission_launched_show_combat_cluster)
	_build_effect_list()


func _exit_tree() -> void:
	GEventBus.mission_phase_changed.disconnect(_on_mission_phase_changed)
	GEventBus.monster_spawned.disconnect(_on_monster_spawned)
	GEventBus.monster_died.disconnect(_on_monster_died)
	GEventBus.monsters_died_batch.disconnect(_on_monsters_died_batch)
	GEventBus.monster_breached.disconnect(_on_monster_breached)
	GEventBus.tower_damaged.disconnect(_on_tower_damaged)
	GEventBus.boss_died.disconnect(_on_boss_died)
	GEventBus.templates_ready.disconnect(_on_templates_ready)
	GEventBus.tower_destroyed.disconnect(_on_tower_destroyed)
	GEventBus.hero_class_unlocked.disconnect(_on_hero_class_unlocked)
	GEventBus.wave_preview_available.disconnect(_on_wave_preview_available)
	GEventBus.wave_completed.disconnect(_on_wave_completed)
	GEventBus.hero_skill_cooldown_updated.disconnect(_on_hero_skill_cooldown_updated)
	GEventBus.hero_health_changed.disconnect(_on_hero_health_changed)
	GEventBus.hero_skill_cooldown_updated.disconnect(_on_skill_cooldown_display_updated)
	GEventBus.boss_hp_changed.disconnect(_on_boss_hp_changed)
	GEventBus.monster_damage_number_requested.disconnect(_on_monster_damage_number_requested)
	GEventBus.wave_started.disconnect(_on_wave_started)
	GEventBus.phase_timer_tick.disconnect(_on_phase_timer_tick)
	GEventBus.wave_countdown_warning.disconnect(_on_wave_countdown_warning)
	GEventBus.materials_earned.disconnect(_on_materials_earned)
	GEventBus.resources_changed.disconnect(_on_resources_changed)
	GEventBus.item_added.disconnect(_on_item_added)
	GEventBus.item_removed.disconnect(_on_item_removed)
	GEventBus.item_pickup_rejected.disconnect(_on_item_pickup_rejected)
	GEventBus.skill_unlocked.disconnect(_on_skill_unlocked)
	GEventBus.mission_launched.disconnect(_on_mission_launched_show_combat_cluster)


## AC-13: once per spawn cell, before any tower is placed. Caches the result
## as the "last-known route" (Rule 11) and hands it to the currently-live
## Planning Cluster, if one already exists — see _spawn_planning_cluster()
## for the reverse case (route cached before any cluster exists yet).
func _on_templates_ready(_spawn_count: int, _build_duration_ms: float) -> void:
	_last_known_routes = []
	for spawn_cell: Vector2i in GGrid.get_spawn_cells():
		_last_known_routes.append(GPathfindingSystem.find_path(spawn_cell, 0))
	if _planning_cluster != null:
		_planning_cluster.render_route(_last_known_routes)


func _on_planning_cluster_route_updated(routes: Array) -> void:
	_last_known_routes = routes


## See _ready()'s own comment for the full gap this closes -- CombatCluster
## must become visible (and therefore able to receive input again) once a
## mission genuinely launches, not stay permanently hidden after blocking
## Mission Select's pre-launch clicks.
func _on_mission_launched_show_combat_cluster(_mission_id: String, _modifiers: PackedStringArray, _difficulty_tier: int) -> void:
	_combat_cluster.visible = true


## AC-2/AC-3: mount on IDLE->SCOUT (reset + become visible), unmount on entry
## to MISSION_COMPLETE/DEFEAT (become hidden, node persists). AC-6: tower HP
## bars cleared wholesale on every INTERMISSION entry (towers reset to
## max_hp between waves). AC-8/AC-9/AC-10 (Story 002): drives the Planning
## Cluster's re-instantiate/teardown/partial-interactivity lifecycle.
func _on_mission_phase_changed(previous_phase: String, new_phase: String, _timestamp: float) -> void:
	_current_phase = new_phase
	_phase_label.text = tr("HUD_PHASE") % phase_display_name(new_phase)  # AC-63 (PC-4)
	# Story 012 (AC-70) fix: originally gated on previous_phase == "IDLE"
	# specifically — but WaveManager never resets its own _phase back to IDLE
	# before re-emitting mission_launched on a DEFEAT retry (_reset_all_state()
	# resets _wave_index/counters, not _phase itself), so a retry's transition
	# arrives as (previous_phase="DEFEAT", new_phase="SCOUT"). WaveManager's
	# FSM only ever enters SCOUT as a mission-start transition (never
	# mid-mission), so gating on new_phase alone is safe and is what AC-70
	# actually requires ("reacts to it exactly like an initial mission launch").
	match new_phase:
		"SCOUT":
			_enter_scout()
		"MISSION_COMPLETE", "DEFEAT":
			_enter_terminal(new_phase)
		"PRE_WAVE":
			_enter_pre_wave()
		"WAVE_ACTIVE":
			_teardown_planning_cluster()  # AC-9
			_phase_timer_label.text = ""  # the PRE_WAVE countdown is over -- do not leave "0.0s" up
		"INTERMISSION":
			_enter_intermission()


## AC-2/AC-8: reset all Rule-4 state, become visible, (re)spawn Planning Cluster.
func _enter_scout() -> void:
	_reset_local_state()
	visible = true
	_spawn_planning_cluster()


## AC-3/AC-68: unmount. DEFEAT keeps the CanvasLayer itself visible (only
## _combat_cluster hides) so Retry can be shown/pressed — see _retry_button's
## own doc comment for why it's pragmatically housed here rather than on a
## real (not-yet-built) Outcome/Defeat screen. MISSION_COMPLETE has no Retry
## contract (Rule 25 is DEFEAT-only) — unmounts exactly as before.
func _enter_terminal(new_phase: String) -> void:
	_terminal = true
	if new_phase == "DEFEAT":
		_combat_cluster.visible = false
		# The MissionOutcomeScreen owns Retry when a mission scene hosts one.
		_retry_button.visible = get_tree().get_first_node_in_group(MissionOutcomeScreen.GROUP_NAME) == null
	else:
		visible = false


## AC-10: Ready remains active/interactable; Planning Cluster's own method
## handles the rest of the group-level disable.
func _enter_pre_wave() -> void:
	if _planning_cluster != null:
		_planning_cluster.set_pre_wave_interactivity(true)


## AC-6/AC-8/AC-25: tower HP bars cleared wholesale, banner force-dismissed,
## Planning Cluster re-instantiated fresh.
func _enter_intermission() -> void:
	_active_tower_hp_bars.clear()
	_clear_tower_hp_bar_labels()
	_dismiss_banner()
	_teardown_planning_cluster()  # defensive — should already be null after WAVE_ACTIVE
	_spawn_planning_cluster()


## AC-8: fresh instance from the PackedScene, added to PlanningClusterHost —
## re-instantiation (not a persisted-and-toggled node) is what guarantees
## _ready() re-fires and EventBus subscriptions genuinely reconnect every
## cycle (live-MCP-verified, GDD Rule 6).
func _spawn_planning_cluster() -> void:
	_planning_cluster = PlanningClusterScene.instantiate()
	_planning_cluster.route_updated.connect(_on_planning_cluster_route_updated)
	_planning_cluster_host.add_child(_planning_cluster)
	_planning_cluster.set_input_mode_tracker(_input_mode_tracker)  # AC-43
	if not _last_known_routes.is_empty():
		_planning_cluster.render_route(_last_known_routes)  # AC-16: reappear with last-known route
	if _boss_telegraph_cell != Vector2i(-1, -1):
		_planning_cluster.set_boss_telegraph_cell(_boss_telegraph_cell)  # AC-30: hand cached cell to the fresh instance


## AC-9: synchronous remove_child() FIRST (forces immediate _exit_tree(),
## disconnecting subscriptions right away), THEN queue_free() to actually
## free memory. queue_free() alone defers node removal to end-of-idle-frame,
## leaving the outgoing instance's subscriptions live simultaneously with a
## freshly-instantiated replacement's — a real double-connected-handler
## window caught during this ADR's own engine-specialist review.
func _teardown_planning_cluster() -> void:
	if _planning_cluster == null:
		return
	_planning_cluster_host.remove_child(_planning_cluster)
	_planning_cluster.queue_free()
	_planning_cluster = null


func _reset_local_state() -> void:
	_enemies_alive_display = 0
	_breach_count = 0
	_on_breach_count_changed_display()
	_active_tower_hp_bars.clear()
	_clear_tower_hp_bar_labels()
	_boss_state.clear()
	_boss_bar_label.visible = false
	_boss_telegraph_cell = Vector2i(-1, -1)
	_terminal = false
	_materials_tally.clear()
	_rebuild_materials_row()
	_combat_cluster.visible = true  # AC-68/70: undo DEFEAT's own hide, on this same or a retried mission
	_retry_button.visible = false
	# _last_known_routes is deliberately NOT cleared here: the boot-race
	# fallback (_ready()) can populate it before this mount handler ever
	# runs (both are one-time, at mission-scene-load), and clearing it here
	# would silently discard exactly the data that fallback exists to
	# preserve. It naturally gets fresh data from this mission's own
	# templates_ready regardless.


## AC-4: +1 per spawn. AC-7: BOSS-tier spawn sets _boss_state only if not
## already set — a second concurrent BOSS is a defense-in-depth guard (Wave
## Manager's own content constraints already guarantee at most one BOSS
## exists per mission); logs a warning and discards rather than overwriting.
func _on_monster_spawned(payload: MonsterSpawnedEvent) -> void:
	if _terminal:
		return
	_enemies_alive_display += 1

	var resource: MonsterResource = GGameDataRegistry.get_monster_resource(payload.monster_id)
	if resource == null or resource.tier != BOSS_TIER:
		return

	# AC-31 (Story 006): the WAVE_ACTIVE spawn-confirmation pulse — owned by
	# this outer root since the Planning Cluster (which housed the persistent
	# telegraph marker) no longer exists at this point. Fires only if a
	# telegraph cell is actually cached; clears it immediately after so a
	# second BOSS-tier spawn (defense-in-depth, should not occur) can't
	# re-fire the pulse.
	if _current_phase == "WAVE_ACTIVE" and _boss_telegraph_cell != Vector2i(-1, -1):
		_fire_boss_confirmation_pulse(_boss_telegraph_cell)
		_boss_telegraph_cell = Vector2i(-1, -1)

	if not _boss_state.is_empty():
		push_warning("[MissionHud] Second BOSS-tier monster_spawned (entity_id=%d) received while _boss_state already set (entity_id=%d) — discarded, not overwritten." % [payload.entity_id, _boss_state["entity_id"]])
		return
	_boss_state = {
		"entity_id": payload.entity_id,
		"display_name": resource.display_name,
		"current_hp": payload.hp_max,
		"max_hp": payload.hp_max,
	}
	_render_boss_bar()  # AC-60: mounts on the transition to non-empty


func _on_monster_died(_payload: MonsterDiedEvent) -> void:
	if _terminal:
		return
	_enemies_alive_display = maxi(_enemies_alive_display - 1, 0)


func _on_monsters_died_batch(payloads: Array[MonsterDiedEvent]) -> void:
	if _terminal:
		return
	_enemies_alive_display = maxi(_enemies_alive_display - payloads.size(), 0)


## AC-5: breach counter never resets mid-mission (only via _reset_local_state()
## at the SCOUT mount). Also decrements the display-only enemy count, tier-agnostic.
func _on_monster_breached(_entity_id: int, _monster_id: StringName, tier: int) -> void:
	if _terminal:
		return
	_enemies_alive_display = maxi(_enemies_alive_display - 1, 0)
	_breach_count += 1
	_on_breach_count_changed_display()  # AC-59
	_pulse_breach_counter()
	if tier == BOSS_TIER:
		for edge: StringName in [&"top", &"bottom", &"left", &"right"]:
			_flash_breach_edge(edge)
	else:
		_flash_breach_edge(_get_goal_side_edge())


## AC-61: renders/updates this tower_id's bar immediately, creating its Label
## on first sight. AC-67: an untracked tower_id is impossible to "discard"
## here specifically — every tower_damaged legitimately creates/updates its
## own entry — so this handler has nothing to guard against; AC-67's discard
## applies to a tower_id that's ALREADY been removed receiving a further
## damage tick, which _tower_hp_bar_labels.get() below already treats safely
## (creates a fresh bar rather than crashing on a missing key).
func _on_tower_damaged(tower_id: int, _damage_dealt: float, current_hp: float, max_hp: float) -> void:
	if _terminal:
		return
	_active_tower_hp_bars[tower_id] = Vector2(current_hp, max_hp)
	var label: Label = _tower_hp_bar_labels.get(tower_id)
	if label == null:
		label = Label.new()
		_tower_hp_bars_host.add_child(label)
		_tower_hp_bar_labels[tower_id] = label
	label.text = tr("HUD_TOWER_HP") % [tower_id, roundi(current_hp), roundi(max_hp)]


func _clear_tower_hp_bar_labels() -> void:
	for label: Label in _tower_hp_bar_labels.values():
		_tower_hp_bars_host.remove_child(label)
		label.queue_free()
	_tower_hp_bar_labels.clear()


## AC-7: cleared only if the received entity_id matches the currently-tracked
## boss — a boss_died for a non-matching (or already-null) entity_id is stray
## and discarded, same idempotent spirit as the null-state guard elsewhere.
func _on_boss_died(entity_id: int, _monster_id: StringName, _wave_index: int, _cause: String) -> void:
	if _terminal:
		return
	if _boss_state.is_empty() or _boss_state["entity_id"] != entity_id:
		return
	_boss_state.clear()
	_boss_bar_label.visible = false  # AC-60: dismounts


# ---------------------------------------------------------------------------
# Story 005 (Rules 13-15, PC-3): Deferred Routing Notification Banner, plus
# hero_class_unlocked reusing the same transient-banner mechanism (Rule 4's
# Interactions table).
# ---------------------------------------------------------------------------

## AC-23: gated on the CURRENT phase (not the transition that led here) —
## _current_phase is updated at the top of _on_mission_phase_changed(),
## independently of Story 002's own phase-branch logic.
##
## Story 011 (AC-61) fix: prior to this story, _active_tower_hp_bars had no
## per-tower removal path at all — only the wholesale .clear() on SCOUT mount
## and INTERMISSION entry (Story 001's own shipped code). AC-61 explicitly
## requires a destroyed tower's bar to disappear immediately, not linger
## until the next wholesale clear — this handler (already the one place that
## reacts to a single tower's destruction) is extended to do that, unguarded
## by the phase check above since a bar should disappear regardless of phase.
func _on_tower_destroyed(tower_id: int, _grid_position: Vector2i, _archetype: String, _footprint: Array, _constellation_eligibility_tag: String) -> void:
	_active_tower_hp_bars.erase(tower_id)
	var label: Label = _tower_hp_bar_labels.get(tower_id)
	if label != null:
		_tower_hp_bars_host.remove_child(label)
		label.queue_free()
		_tower_hp_bar_labels.erase(tower_id)
	if _current_phase != "WAVE_ACTIVE":
		return
	_show_transient_banner("Path update queued for next intermission.")


func _on_hero_class_unlocked(archetype: StringName, _is_deep: bool) -> void:
	_show_transient_banner("Hero class unlocked: %s" % String(archetype))


## AC-24: Timer.start() restarts the countdown from full duration on every
## call — a second call while the banner is already showing naturally resets
## the timer rather than stacking a second banner, with zero extra bookkeeping.
func _show_transient_banner(text: String) -> void:
	_banner_label.text = text
	_banner.visible = true
	_banner_timer.start(BANNER_DURATION_SECONDS)


func _dismiss_banner() -> void:
	_banner.visible = false
	_banner_timer.stop()


# ---------------------------------------------------------------------------
# Story 006 (Rules 11a-11e, PC-5 boss half): Boss-Lane Telegraph.
# ---------------------------------------------------------------------------

## AC-28: outer-root-owned (not Planning-Cluster-owned) — wave_preview_available
## fires synchronously in the same call stack as the phase transition that
## re-instantiates the Planning Cluster (Story 002), so a Planning-Cluster-
## owned subscription could not be guaranteed live before that emission on
## every cycle. Caches the cell, hands it to whichever instance is currently
## live (or the next one spawned, via _spawn_planning_cluster()).
## Story 007's composition display (AC-35/AC-36) shares this same outer-root
## subscription. _current_phase is read here as the mount phase (AC-37) —
## wave_preview_available always fires synchronously immediately after the
## SCOUT/INTERMISSION transition that (re)spawned _planning_cluster (see
## WaveManager._enter_intermission()/mission_launched's SCOUT emit), so
## _current_phase reflects that same mount, never the payload's own shape.
func _on_wave_preview_available(_next_wave_number: int, composition: Array, boss_spawn_cell: Vector2i) -> void:
	_boss_telegraph_cell = boss_spawn_cell  # AC-29/AC-34: sentinel or real cell, always overwrites
	if _planning_cluster != null:
		_planning_cluster.set_boss_telegraph_cell(_boss_telegraph_cell)
		_planning_cluster.render_composition_preview(composition, _current_phase)


## AC-32: unconditional reset regardless of whether AC-31's pulse fired —
## belt-and-suspenders against a missed/late BOSS spawn. Deliberately NOT
## bound to mission_phase_changed -> WAVE_ACTIVE (the GDD's own Rule 11e
## correction: Wave Manager guarantees the BOSS entry is always last in its
## wave, so its monster_spawned always arrives strictly after that phase
## transition — resetting there would always clear the cell before AC-31's
## guard could ever see a non-sentinel value).
func _on_wave_completed(_wave_number: int, _enemies_remaining: int, _was_boss_breached: bool) -> void:
	_boss_telegraph_cell = Vector2i(-1, -1)


func _fire_boss_confirmation_pulse(cell: Vector2i) -> void:
	var world_pos: Vector2 = GGrid.cell_to_world(cell)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var pulse := ColorRect.new()
	pulse.color = Color(0.494, 0.180, 0.722, 0.9)  # Boss Purple (#7E2EB8), art-bible reference
	pulse.size = Vector2(64.0, 64.0)
	pulse.position = screen_pos - pulse.size * 0.5
	_combat_cluster.add_child(pulse)
	var tween: Tween = create_tween()
	tween.tween_property(pulse, "modulate:a", 0.0, 0.6)
	tween.tween_callback(pulse.queue_free)


# ---------------------------------------------------------------------------
# Story 009 (Rules 19-20): Ultimate Button. Lives in CombatCluster — exists
# in all phases (unlike Ready/Sell's Planning-Cluster-gated existence), so
# it's owned by this outer root and its own InputModeTracker connections are
# made once in _ready() (not per-mount, unlike Story 008's hand-off pattern).
# ---------------------------------------------------------------------------

## AC-46/AC-50: filters to skill_slot 4 (Hero.ULTIMATE_SLOT_INDEX) only —
## slots 0-3 are discarded, not routed anywhere in this story. AC-47: setting
## Button.disabled fully blocks input (not just a visual dim).
func _on_hero_skill_cooldown_updated(skill_slot: int, cooldown_remaining: float, _cooldown_max: float) -> void:
	if skill_slot != Hero.ULTIMATE_SLOT_INDEX:
		return
	_ultimate_button.disabled = cooldown_remaining > 0.0


## AC-48: synchronous, no payload. AC-49: no local cooldown prediction/reset
## here — the button's own interactable state only ever changes from the next
## real hero_skill_cooldown_updated tick. AC-51: no HUD-side debounce — Hero
## System is solely responsible for rejecting a too-soon second activation.
func _on_ultimate_pressed() -> void:
	GEventBus.hero_ultimate_activated.emit()


func _build_ultimate_focus_ring() -> void:
	_ultimate_focus_ring = FocusRingFactory.build(_ultimate_button)


func _update_ultimate_focus_ring(_arg: Variant = null) -> void:
	_ultimate_focus_ring.visible = _ultimate_button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


# ---------------------------------------------------------------------------
# Story 011 (Rule 4 visual half, PC-4, Interactions table): Combat Cluster
# live-data widgets. Every handler here is a pure renderer — mutation logic
# for _breach_count/_active_tower_hp_bars/_boss_state is Story 001's own
# (this story only adds the immediate-removal fix for _active_tower_hp_bars
# documented at _on_tower_destroyed(), since that mutation gap was real and
# blocked AC-61 as written). Exact typography/layout is a UX Spec concern —
# these are placeholder Label renderers, matching this epic's established
# convention (ColorRect markers, Label banners) throughout Stories 003-010.
# ---------------------------------------------------------------------------

## AC-57. Code review fix: originally missing the _terminal guard every other
## Rule-4 mutation handler in this file has — without it, Hero HP kept
## updating after DEFEAT/MISSION_COMPLETE, inconsistent with the rest of this
## story's own design intent and the established pattern.
func _on_hero_health_changed(current_health: float, max_health: float) -> void:
	if _terminal:
		return
	_hero_hp_label.text = tr("HUD_HERO_HP") % [roundi(current_health), roundi(max_health)]


## Places the effect list directly under the Hero HP line and starts polling.
func _build_effect_list() -> void:
	_effect_list = VBoxContainer.new()
	_effect_list.name = "SetEffectList"
	_effect_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_list.add_theme_constant_override("separation", 0)
	_effect_list.visible = false
	var chrome: Node = _hero_hp_label.get_parent()
	chrome.add_child(_effect_list)
	chrome.move_child(_effect_list, _hero_hp_label.get_index() + 1)
	_effect_poll = Timer.new()
	_effect_poll.name = "SetEffectPoll"
	_effect_poll.wait_time = EFFECT_POLL_SECONDS
	_effect_poll.timeout.connect(_refresh_effect_list)
	add_child(_effect_poll)
	_effect_poll.start()


## One HUD line for a SetEffectController.get_hud_entries() entry.
## Example: {name "Iron Hide", kind "shield", amount 76, remaining 3.2} -> "Iron Hide: shield 76 (4s)"
static func format_effect_entry(entry: Dictionary) -> String:
	var seconds: int = ceili(float(entry.get(&"remaining", -1.0)))
	var effect_name: String = String(entry.get(&"name", ""))
	match String(entry.get(&"kind", "")):
		"shield":
			return TranslationServer.translate("HUD_EFFECT_SHIELD") % [effect_name, int(entry[&"amount"]), seconds]
		"stacks":
			return TranslationServer.translate("HUD_EFFECT_STACKS") % [effect_name, int(entry[&"stacks"]), seconds]
		"timed":
			return TranslationServer.translate("HUD_EFFECT_TIMED") % [effect_name, seconds]
	return TranslationServer.translate("HUD_EFFECT_STATE") % effect_name


## Rebuilds the list only when its text changes (most polls change nothing).
func _refresh_effect_list() -> void:
	var entries: Array[Dictionary] = []
	var controller: Node = get_tree().get_first_node_in_group(SetEffectController.GROUP_NAME)
	if controller != null and not _terminal:
		entries = (controller as SetEffectController).get_hud_entries()
	var lines: Array[String] = []
	for entry: Dictionary in entries:
		lines.append(format_effect_entry(entry))
	var signature: String = "
".join(lines)
	if signature == _effect_signature:
		return
	_effect_signature = signature
	for child: Node in _effect_list.get_children():
		_effect_list.remove_child(child)
		child.queue_free()
	for i: int in entries.size():
		var label := Label.new()
		label.text = lines[i]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color",
				EFFECT_COLOR_SHIELD if String(entries[i][&"kind"]) == "shield" else EFFECT_COLOR_BUFF)
		_effect_list.add_child(label)
	_effect_list.visible = not entries.is_empty()


## Builds the 4 skill-slot icon tiles (Pattern 12): a base ColorRect face
## (icon placeholder, see the field doc comment above for why), a numbered
## Label on top of it, a CooldownFill ColorRect anchored to grow top-to-
## bottom, and a CountdownLabel for the numeric seconds-remaining readout.
## Layer order (draw order = child order): Icon, SlotLabel, CooldownFill,
## CountdownLabel — the fill and countdown must render above the slot
## number so the cooldown state is always the top-most read.
func _build_skill_slots() -> void:
	for slot: int in range(SKILL_SLOT_COUNT):
		var tile := Panel.new()
		tile.name = "Slot%d" % slot
		tile.custom_minimum_size = SKILL_TILE_SIZE
		_skill_cooldown_host.add_child(tile)

		var icon := ColorRect.new()
		icon.name = "Icon"
		icon.color = SKILL_READY_COLOR
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(icon)
		_skill_slot_icons.append(icon)

		var slot_label := Label.new()
		slot_label.text = str(slot + 1)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(slot_label)

		# Grows from the top (anchor_top pinned at 0) down to anchor_bottom ==
		# cooldown_remaining / cooldown_max — Pattern 12's "top to bottom" fill.
		var fill := ColorRect.new()
		fill.name = "CooldownFill"
		fill.color = SKILL_COOLDOWN_FILL_COLOR
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.anchor_left = 0.0
		fill.anchor_right = 1.0
		fill.anchor_top = 0.0
		fill.anchor_bottom = 0.0
		fill.visible = false
		tile.add_child(fill)
		_skill_slot_fills.append(fill)

		var countdown := Label.new()
		countdown.name = "CountdownLabel"
		countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		countdown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(countdown)
		_skill_slot_countdowns.append(countdown)


## AC-58: slots 0-3 only — slot 4 (Ultimate) is Story 009's own handler,
## connected separately to the same signal (two independent connections to
## the same EventBus signal, matching this file's established multi-consumer
## pattern rather than merging unrelated concerns into one function).
##
## Player-reported 2026-08-16: replaced the "Skill N: Ready"/"Skill N: 3.2s"
## text readout with Pattern 12's real states — 50% icon opacity + a dark
## fill draining top-to-bottom + numeric countdown while on cooldown; full
## opacity, no fill, no countdown when ready.
func _on_skill_cooldown_display_updated(skill_slot: int, cooldown_remaining: float, cooldown_max: float) -> void:
	if skill_slot == Hero.ULTIMATE_SLOT_INDEX or skill_slot < 0 or skill_slot >= _skill_slot_icons.size():
		return
	var icon: ColorRect = _skill_slot_icons[skill_slot]
	var fill: ColorRect = _skill_slot_fills[skill_slot]
	var countdown: Label = _skill_slot_countdowns[skill_slot]
	var on_cooldown: bool = cooldown_remaining > 0.0
	icon.modulate.a = 0.5 if on_cooldown else 1.0
	fill.visible = on_cooldown
	if on_cooldown:
		var fraction: float = clampf(cooldown_remaining / cooldown_max, 0.0, 1.0) if cooldown_max > 0.0 else 0.0
		fill.anchor_bottom = fraction
		countdown.text = "%ds" % ceili(cooldown_remaining)
	else:
		fill.anchor_bottom = 0.0
		countdown.text = ""


func _render_boss_bar() -> void:
	if _boss_state.is_empty():
		_boss_bar_label.visible = false
		return
	_boss_bar_label.visible = true
	_boss_bar_label.text = tr("HUD_BOSS_BAR") % [_boss_state["display_name"], roundi(_boss_state["current_hp"] as float), roundi(_boss_state["max_hp"] as float)]


## AC-60 (update half)/AC-66: a boss_hp_changed for a non-matching or already-
## cleared _boss_state (entity_id mismatch, or empty) is discarded silently —
## same idempotent-guard spirit as _on_boss_died()'s own matching check.
## Code review fix: originally missing the _terminal guard (see
## _on_hero_health_changed()'s identical fix note).
func _on_boss_hp_changed(entity_id: int, current_hp: float, max_hp: float) -> void:
	if _terminal:
		return
	if _boss_state.is_empty() or _boss_state["entity_id"] != entity_id:
		return
	_boss_state["current_hp"] = current_hp
	_boss_state["max_hp"] = max_hp
	_render_boss_bar()


## AC-59.
func _on_breach_count_changed_display() -> void:
	_breach_counter_label.text = tr("HUD_BREACHES") % _breach_count


## monster.md "Breach counter pulses (scale pop 1.2x, 0.3s)". Restarts on
## every breach rather than stacking — matches the "no stacking" flash rule.
func _pulse_breach_counter() -> void:
	if _breach_counter_pulse_tween != null and _breach_counter_pulse_tween.is_valid():
		_breach_counter_pulse_tween.kill()
	_breach_counter_label.pivot_offset = _breach_counter_label.size * 0.5
	_breach_counter_label.scale = Vector2.ONE
	_breach_counter_pulse_tween = create_tween()
	_breach_counter_pulse_tween.tween_property(_breach_counter_label, "scale",
			Vector2.ONE * BREACH_COUNTER_PULSE_SCALE, BREACH_COUNTER_PULSE_DURATION * 0.5)
	_breach_counter_pulse_tween.tween_property(_breach_counter_label, "scale",
			Vector2.ONE, BREACH_COUNTER_PULSE_DURATION * 0.5)


## Determines which single screen edge is "goal-side" from GGrid's goal
## cell(s), relative to grid center — cached after first computation since
## the goal doesn't move mid-mission. Falls back to &"bottom" (this project's
## path generally runs top-to-bottom) if no goal cell is registered yet.
func _get_goal_side_edge() -> StringName:
	if _goal_side_edge != &"":
		return _goal_side_edge
	var goal_cells: Array[Vector2i] = GGrid.get_goal_cells()
	if goal_cells.is_empty():
		return &"bottom"
	var cols: int = GGrid.get_grid_cols()
	var rows: int = GGrid.get_grid_rows()
	var goal: Vector2i = goal_cells[0]
	var dx: float = goal.x - (cols - 1) * 0.5
	var dy: float = goal.y - (rows - 1) * 0.5
	# Normalize by axis extent so a wide-but-shallow grid doesn't always
	# resolve to a left/right edge (or vice versa for a tall-but-narrow one).
	var norm_x: float = dx / maxf(float(cols) * 0.5, 1.0)
	var norm_y: float = dy / maxf(float(rows) * 0.5, 1.0)
	if absf(norm_x) >= absf(norm_y):
		_goal_side_edge = &"right" if norm_x > 0.0 else &"left"
	else:
		_goal_side_edge = &"bottom" if norm_y > 0.0 else &"top"
	return _goal_side_edge


## Flashes a single screen edge red then fades it out. "One flash per event,
## no stacking" — killing any in-flight tween for this edge and resetting
## alpha to full before restarting satisfies that without a queue.
func _flash_breach_edge(edge: StringName) -> void:
	var rect: ColorRect = _breach_flash_rect_for(edge)
	if rect == null:
		return
	if _breach_flash_tweens.has(edge):
		var existing: Tween = _breach_flash_tweens[edge]
		if existing.is_valid():
			existing.kill()
	rect.color = BREACH_FLASH_COLOR
	var tween: Tween = create_tween()
	tween.tween_interval(BREACH_FLASH_IN_DURATION)
	tween.tween_property(rect, "color:a", 0.0, BREACH_FLASH_FADE_DURATION)
	_breach_flash_tweens[edge] = tween


func _breach_flash_rect_for(edge: StringName) -> ColorRect:
	match edge:
		&"top":
			return _breach_flash_top
		&"bottom":
			return _breach_flash_bottom
		&"left":
			return _breach_flash_left
		&"right":
			return _breach_flash_right
	return null


## AC-62: floating damage number, spawned as a transient fading Label —
## the same fire-and-forget ColorRect-pulse pattern _fire_boss_confirmation_pulse()
## already established for this cluster.
##
## RESOLVED 2026-08-16 (player-reported: numbers were popping up top-right
## near the boss bar instead of on the monster): the KNOWN GAP this handler
## used to document is closed by monster_damage_number_requested, a new
## EventBus signal emitted by Monster System's _pass1_damage() — the one
## place entity_id resolves to a live entity with a real global_position (see
## that signal's own doc comment for why DamageStatus, monster_damage_taken's
## emitter, could never have supplied one). world_position is converted to
## screen space via the same canvas-transform pattern PlanningCluster's
## _world_to_screen() already established for this HUD's other world-anchored
## overlays (route lines, blocked-cell markers, boss telegraph).
func _on_monster_damage_number_requested(_entity_id: int, world_position: Vector2, amount: int, is_crit: bool) -> void:
	if _terminal:
		return
	var number := Label.new()
	var text: String = str(amount)
	if is_crit:
		text += "!"
	number.text = text
	number.modulate = Color(1.0, 0.3, 0.3) if is_crit else Color(1.0, 1.0, 1.0)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_position
	number.position = screen_pos + Vector2(randf_range(-8.0, 8.0), -16.0)  # slight jitter so a burst doesn't fully overlap
	_damage_number_host.add_child(number)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(number, "position:y", number.position.y - 24.0, 0.6)
	tween.tween_property(number, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(number.queue_free)


## AC-63 (PC-4, wave half).
func _on_wave_started(wave_number: int, total_waves: int, _wave_difficulty: float) -> void:
	_wave_label.text = tr("HUD_WAVE_PROGRESS") % [wave_number, total_waves]


## AC-63 (PC-4, timer half).
func _on_phase_timer_tick(phase: String, seconds_remaining: float) -> void:
	_phase_timer_label.text = tr("HUD_PHASE_TIMER") % [phase_display_name(phase), seconds_remaining]


## Player-facing name for a WaveManager phase id (2026-10-04 smoke check: the
## HUD showed raw ids like "PRE_WAVE: 0.0s"). Unknown ids fall back to a
## capitalized form rather than a missing-key string.
static func phase_display_name(phase: String) -> String:
	var key: String = "HUD_PHASE_NAME_" + phase
	var translated: String = TranslationServer.translate(key)
	return phase.capitalize() if translated == key else translated


## AC-63 (PC-4, countdown-warning half) — distinct payload shape from
## phase_timer_tick (int seconds, no phase name), same display target.
func _on_wave_countdown_warning(seconds_remaining: int) -> void:
	_phase_timer_label.text = tr("HUD_WAVE_INCOMING") % seconds_remaining


## AC-64 (materials half): accumulates the running per-mission tally —
## materials_earned is a delta per its own EventBus doc comment. Code review
## fix: originally missing the _terminal guard (see _on_hero_health_changed()'s
## identical fix note).
func _on_materials_earned(material_type: String, quantity: int, _source: String) -> void:
	if _terminal:
		return
	_materials_tally[material_type] = _materials_tally.get(material_type, 0) + quantity
	_rebuild_materials_row()


## Rebuilds the whole chip row from _materials_tally on every change -- the
## tally is at most a handful of distinct material types per mission, so a
## full clear-and-rebuild (matching this file's own established
## render_composition_preview()-class precedent elsewhere) costs nothing
## real and keeps this immune to the same stale-child-state bug class
## PlanningCluster's render_route() doc comment documents for the
## equivalent partial-update alternative.
func _rebuild_materials_row() -> void:
	for child: Node in _materials_row.get_children():
		_materials_row.remove_child(child)
		child.queue_free()
	for mat_type: String in _materials_tally:
		_materials_row.add_child(_build_material_chip(mat_type, _materials_tally[mat_type]))


## "[icon] xN" per inventory_screen.gd's established icon-with-text-fallback
## convention: a real icon on the item's ItemDefinitionResource wins; a
## material with no icon authored yet (most of them, until Phase 3 art
## lands) falls back to "material_id xN" plain text -- zero regression from
## the prior text-only tally, just per-chip instead of one joined string.
func _build_material_chip(mat_type: String, quantity: int) -> HBoxContainer:
	var chip := HBoxContainer.new()
	chip.name = "Chip_%s" % mat_type
	chip.add_theme_constant_override("separation", 4)

	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(mat_type))
	var quantity_label := Label.new()

	if definition != null and definition.icon != null:
		var icon := TextureRect.new()
		icon.texture = definition.icon
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chip.add_child(icon)
		quantity_label.text = "x%d" % quantity
	else:
		quantity_label.text = "%s x%d" % [mat_type, quantity]

	chip.add_child(quantity_label)
	return chip


## Real bug found and fixed 2026-08-10 (player-reported: "the calculation
## for currency seems wrong" after buying a tower): this handler used to
## display `gold` directly, on the mistaken assumption that resources_
## changed's payload was already an absolute balance. Every real emitter
## (resource_economy.gd's Scout grant, tower_system.gd's placement cost/sell
## refund, defense_building.gd's tech/structure costs) actually sends a
## signed DELTA -- so buying a 10g tower made the label jump straight to
## "-10" instead of showing the new balance (e.g. 40). The very first grant
## from a zero baseline happened to look correct by coincidence (delta ==
## new total), masking the bug until a second gold-changing event occurred.
## Reads GMissionEconomy directly instead (its own public get_gold_balance()
## API, already the sole authoritative accumulator of these same deltas) —
## same "read the domain Autoload directly" precedent PlanningCluster's
## _refresh_affordability() already established for this exact discrepancy.
##
## Code review fix: originally missing the _terminal guard (see
## _on_hero_health_changed()'s identical fix note). 2026-08-06: text is now
## just the number — the GoldIcon sibling (GoldRow) carries the "this is
## gold" meaning the word "Gold" used to (design/quick-specs/gold-currency-
## icon-2026-08-06.md).
func _on_resources_changed(_gold: int, _source: StringName) -> void:
	if _terminal:
		return
	_gold_label.text = "%d" % GMissionEconomy.get_gold_balance()


## AC-65: toast-only (this story's own scope note calls out "live
## counters/toast notifications" — the toast feed IS the live counter here,
## since Inventory's own screen is inaccessible mid-mission per the AC's own
## text; a separate persistent numeric counter would just duplicate it).
func _on_item_added(item_id: String, _item_type: String, quantity: int) -> void:
	_show_toast("+%d %s" % [quantity, item_display_name(item_id)])


func _on_item_removed(item_id: String, _item_type: String, quantity: int) -> void:
	_show_toast("-%d %s" % [quantity, item_display_name(item_id)])


func _on_item_pickup_rejected(item_id: String, _item_type: String, quantity: int, reason: String) -> void:
	_show_toast(tr("HUD_TOAST_PICKUP_REJECTED") % [quantity, item_display_name(item_id), _reject_reason_text(reason)])
	# The drop was already tallied by _on_materials_earned(); a rejected pickup never
	# reached the inventory, so take it back out of the mission tally (2026-10-04
	# smoke check: a full inventory still showed every rejected drop as earned).
	if _materials_tally.has(item_id):
		_materials_tally[item_id] = maxi(0, _materials_tally[item_id] - quantity)
		if _materials_tally[item_id] == 0:
			_materials_tally.erase(item_id)
		_rebuild_materials_row()


## Registry display name for toasts (was the raw item_id, e.g. "goblin_hide");
## unknown ids fall back to a capitalized form.
static func item_display_name(item_id: String) -> String:
	var definition: ItemDefinitionResource = GGameDataRegistry.get_item_definition(StringName(item_id))
	if definition != null and definition.display_name != "":
		return definition.display_name
	return item_id.capitalize()


func _reject_reason_text(reason: String) -> String:
	var key: String = "HUD_REJECT_REASON_" + reason.to_upper()
	var translated: String = tr(key)
	return reason.capitalize() if translated == key else translated


# ---------------------------------------------------------------------------
# Story 012 (Rules 25-27): DEFEAT Retry Button.
# ---------------------------------------------------------------------------

## AC-69: direct Autoload call, NOT an EventBus emission — the one deliberate
## exception in this file's entire outbound surface (ADR-0020 Criterion B).
## AC-70: no local handling of the mission_launched this triggers — Story
## 001/012's own _on_mission_phase_changed(new_phase="SCOUT") mount path
## (fixed above to not require previous_phase=="IDLE") already reacts to it
## identically to an initial launch.
func _on_retry_pressed() -> void:
	GMissionSelect.retry_current_mission()


func _build_retry_focus_ring() -> void:
	_retry_focus_ring = FocusRingFactory.build(_retry_button)


func _update_retry_focus_ring(_arg: Variant = null) -> void:
	_retry_focus_ring.visible = _retry_button.has_focus() and _input_mode_tracker.is_focus_ring_visible()


# ---------------------------------------------------------------------------
# Epic 06 Story 013 (tower-mastery.md Visual/Audio Requirements (c)): the
# skill_unlocked HUD corner callout — the half of this story blocked until
# Mission HUD existed in code. Reuses the ToastHost mechanism (Story 011,
# bottom-left, non-blocking, auto-dismissing) rather than inventing a second
# transient-message channel: it already satisfies "non-blocking... corner...
# clear of the Combat Cluster... never top-center" (top-center is reserved
# for _show_transient_banner()'s path-update/hero-class messaging).
# ---------------------------------------------------------------------------

## RESOLVED 2026-08-13: SkillDefinitionResource gained a display_name field
## (8 real content files updated). Falls back to the raw skill_id for an
## unrecognized id — matches this project's established unknown-content-id
## fallback convention, never a crash.
func _on_skill_unlocked(skill_id: String, _source_tower_id: int) -> void:
	if _terminal:
		return
	var definition: SkillDefinitionResource = GGameDataRegistry.get_skill_definition(StringName(skill_id))
	var label: String = definition.display_name if definition != null else skill_id
	_show_toast(tr("HUD_TOAST_SKILL_LEARNED") % label)


func _show_toast(text: String) -> void:
	# Force-dismiss the oldest toast(s) first so the log never exceeds
	# MAX_VISIBLE_TOASTS -- see that constant's own doc comment.
	while _toast_host.get_child_count() >= MAX_VISIBLE_TOASTS:
		# remove_child() (not just queue_free()) so get_child_count() reflects
		# the removal immediately -- several toasts can fire within the same
		# frame (e.g. a multi-material drop), and queue_free() alone only
		# detaches at end-of-frame, which would undercount mid-loop here.
		var oldest: Label = _toast_host.get_child(0)
		_toast_host.remove_child(oldest)
		oldest.queue_free()

	var toast := Label.new()
	toast.text = text
	toast.clip_text = true
	_toast_host.add_child(toast)
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	tween.tween_callback(toast.queue_free)
